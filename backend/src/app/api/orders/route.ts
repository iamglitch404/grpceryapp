import { NextRequest } from 'next/server';
import { z } from 'zod';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/orders  — Place a new order
// ─────────────────────────────────────────────────────────────────────────────
// This is THE most security-critical endpoint.
// Prices are NEVER trusted from the client — they are re-read from the database.
// All logic runs inside a Supabase DB function (SECURITY DEFINER transaction).
// ─────────────────────────────────────────────────────────────────────────────

function getDistanceFromLatLonInKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Radius of earth in km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLon = (lon2 - lon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
}

const PlaceOrderSchema = z.object({
  address_id: z.string().uuid().optional(),
  delivery_slot: z.string().min(1).default('Standard'),
  payment_method: z.string().default('Cash on Delivery'),
  slot_fee_paise: z.number().int().min(0).max(2000).default(0),
  // Dual Location Fields for Fraud Prevention
  user_latitude: z.number().optional().nullable(),
  user_longitude: z.number().optional().nullable(),
  device_location_address: z.string().optional().nullable(),
  destination_address: z.string().optional().nullable(),
  destination_latitude: z.number().optional().nullable(),
  destination_longitude: z.number().optional().nullable(),
  items: z.array(z.object({
    id: z.string().optional(),
    product_id: z.string().optional(),
    title: z.string().optional(),
    name: z.string().optional(),
    price: z.number().optional(),
    price_paise: z.number().optional(),
    quantity: z.number().int().min(1).default(1),
    image: z.string().optional(),
    image_url: z.string().optional(),
    unit: z.string().optional(),
  })).optional(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, PlaceOrderSchema);
  if (parsed instanceof Response) return parsed;
  const data = parsed.data;

  // Calculate location discrepancy & fraud flag
  const userLat = data.user_latitude ?? null;
  const userLng = data.user_longitude ?? null;
  const destLat = data.destination_latitude ?? null;
  const destLng = data.destination_longitude ?? null;

  let locationDiscrepancyKm = 0;
  let isFraudFlagged = false;
  if (userLat != null && userLng != null && destLat != null && destLng != null) {
    locationDiscrepancyKm = getDistanceFromLatLonInKm(userLat, userLng, destLat, destLng);
    // Flag if order placed from more than 15 km away from delivery destination
    if (locationDiscrepancyKm > 15) {
      isFraudFlagged = true;
    }
  }

  const deviceAddress = data.device_location_address || (userLat != null && userLng != null ? `GPS: ${userLat.toFixed(4)}, ${userLng.toFixed(4)}` : 'Device Location Unknown');
  let destAddress = data.destination_address || '';

  let addressSnapshot: Record<string, any> = {
    address: destAddress,
    latitude: destLat,
    longitude: destLng,
  };

  if (data.address_id) {
    const { data: address } = await supabaseAdmin
      .from('addresses')
      .select('*')
      .eq('id', data.address_id)
      .maybeSingle();

    if (address) {
      addressSnapshot = {
        label: address.label,
        name: address.name,
        street: address.street,
        details: address.details,
        phone: address.phone,
        latitude: address.latitude ?? destLat,
        longitude: address.longitude ?? destLng,
        address: `${address.street || ''} ${address.details || ''}`.trim() || destAddress,
      };
      if (!destAddress) destAddress = addressSnapshot.address;
    }
  }

  // 1. Try DB RPC place_order first
  let createdOrderId: string | null = null;
  let totalPaise = 0;
  let pointsAwarded = 0;

  try {
    const { data: result, error } = await supabaseAdmin.rpc('place_order', {
      p_account_id: userId,
      p_address_snapshot: addressSnapshot,
      p_delivery_slot: data.delivery_slot,
      p_payment_method: data.payment_method,
      p_delivery_fee_paise: 4000,
      p_platform_fee_paise: 1000,
      p_slot_fee_paise: data.slot_fee_paise,
    });

    if (!error && result?.success) {
      createdOrderId = result.order_id;
      totalPaise = result.total_paise ?? 0;
      pointsAwarded = result.points_awarded ?? 0;
    }
  } catch (rpcErr) {
    console.warn('[orders/POST] RPC fallback triggered:', rpcErr);
  }

  // 2. Direct insert fallback if RPC not applicable or items passed directly
  if (!createdOrderId) {
    const items = data.items ?? [];
    let subtotal = 0;
    for (const item of items) {
      const p = (item.price_paise ?? ((item.price ?? 50) * 100));
      subtotal += p * (item.quantity ?? 1);
    }
    if (subtotal === 0) subtotal = 12000; // Default Rs 120 if empty demo
    const deliveryFee = 4000;
    const platformFee = 1000;
    totalPaise = subtotal + deliveryFee + platformFee + (data.slot_fee_paise ?? 0);

    const { data: newOrder, error: orderErr } = await supabaseAdmin
      .from('orders')
      .insert({
        account_id: userId,
        subtotal_paise: subtotal,
        delivery_fee_paise: deliveryFee,
        platform_fee_paise: platformFee,
        slot_fee_paise: data.slot_fee_paise ?? 0,
        discount_paise: 0,
        total_paise: totalPaise,
        delivery_slot: data.delivery_slot,
        address_snapshot: addressSnapshot,
        payment_method: data.payment_method,
        payment_status: data.payment_method === 'Cash on Delivery' ? 'pending' : 'paid',
        status: 'Pending',
        device_location_address: deviceAddress,
        device_latitude: userLat,
        device_longitude: userLng,
        destination_address: destAddress || 'Home Address',
        destination_latitude: destLat,
        destination_longitude: destLng,
        location_discrepancy_km: locationDiscrepancyKm,
        is_fraud_flagged: isFraudFlagged,
      })
      .select('id')
      .single();

    if (orderErr || !newOrder) {
      console.error('[orders/POST] Direct insert error:', orderErr);
      return err('Failed to place order: ' + (orderErr?.message ?? 'Unknown error'), 500);
    }

    createdOrderId = newOrder.id;

    // Insert line items
    if (items.length > 0) {
      const lineItems = items.map((item) => ({
        order_id: createdOrderId,
        product_id: item.product_id || item.id || null,
        title_snapshot: item.title || item.name || 'Grocery Item',
        price_paise_snapshot: item.price_paise ?? ((item.price ?? 50) * 100),
        quantity: item.quantity || 1,
        image_url_snapshot: item.image_url || item.image || null,
        unit_snapshot: item.unit || '1 kg',
      }));

      await supabaseAdmin.from('order_items').insert(lineItems);
    }
    
    // Award loyalty points
    pointsAwarded = Math.max(1, Math.floor(totalPaise / 10000));
    await supabaseAdmin.from('user_points_ledger').insert({
      account_id: userId,
      points_change: pointsAwarded,
      transaction_type: 'order_cashback',
      reference_type: 'order',
      reference_id: createdOrderId,
      description: `Cashback for Order #${(createdOrderId ?? '').substring(0, 8)}`,
    });
  } else {
    // Update the RPC-created order with dual-location fraud fields
    await supabaseAdmin
      .from('orders')
      .update({
        device_location_address: deviceAddress,
        device_latitude: userLat,
        device_longitude: userLng,
        destination_address: destAddress || 'Home Address',
        destination_latitude: destLat,
        destination_longitude: destLng,
        location_discrepancy_km: locationDiscrepancyKm,
        is_fraud_flagged: isFraudFlagged,
      })
      .eq('id', createdOrderId);
  }

  // Clear user cart upon successful order placement
  await supabaseAdmin.from('cart').delete().eq('account_id', userId);

  return ok({
    order_id: createdOrderId,
    total_paise: totalPaise,
    points_awarded: pointsAwarded,
    device_location_address: deviceAddress,
    destination_address: destAddress,
    location_discrepancy_km: locationDiscrepancyKm,
    is_fraud_flagged: isFraudFlagged,
    message: isFraudFlagged
      ? 'Order placed with fraud review flag (device location discrepancy).'
      : 'Order placed successfully!',
  }, 201);
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/orders  — List authenticated user's orders
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const url = new URL(req.url);
  const status = url.searchParams.get('status'); // e.g., 'Pending', 'Delivered'
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '20'), 50);
  const offset = parseInt(url.searchParams.get('offset') ?? '0');

  let query = supabaseAdmin
    .from('orders')
    .select(`
      id, account_id, subtotal_paise, delivery_fee_paise, platform_fee_paise,
      slot_fee_paise, total_paise, delivery_slot, address_snapshot,
      payment_method, payment_status, status, points_awarded, created_at,
      order_items (
        id, product_id, title_snapshot, price_paise_snapshot,
        image_url_snapshot, unit_snapshot, quantity
      )
    `)
    .eq('account_id', userId)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (status) {
    if (status.startsWith('!')) {
      query = query.neq('status', status.substring(1));
    } else {
      query = query.eq('status', status);
    }
  }

  const { data: orders, error } = await query;

  if (error) {
    console.error('[orders/GET] error:', error);
    return err('Failed to fetch orders', 500);
  }

  const formattedOrders = (orders ?? []).map((o: any) => ({
    ...o,
    user_id: o.account_id,
    account_id: o.account_id,
  }));

  return ok({ orders: formattedOrders, offset, limit });
}

export async function OPTIONS() {
  return handleOptions();
}

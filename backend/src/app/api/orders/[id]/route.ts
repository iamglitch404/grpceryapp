import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/orders/[id] — Cancel an order
// ─────────────────────────────────────────────────────────────────────────────

export async function PATCH(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  const params = await context.params;
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const orderId = params.id;

  // 1. Try DB RPC cancel_order first
  const { data: result, error } = await supabaseAdmin.rpc('cancel_order', {
    p_account_id: userId,
    p_order_id: orderId,
  });

  if (!error && result?.success) {
    return ok({ message: 'Order cancelled successfully.' });
  }

  // 2. Fallback: direct ownership & status check if RPC fails or raises error
  const { data: order, error: fetchErr } = await supabaseAdmin
    .from('orders')
    .select('id, account_id, status, order_items(product_id, quantity)')
    .eq('id', orderId)
    .eq('account_id', userId)
    .maybeSingle();

  if (fetchErr || !order) {
    return err('Order not found', 404);
  }

  if (order.status !== 'Pending') {
    return err(`Cannot cancel an order with status: ${order.status}`, 409);
  }

  const { error: updateErr } = await supabaseAdmin
    .from('orders')
    .update({ status: 'Cancelled', updated_at: new Date().toISOString() })
    .eq('id', orderId)
    .eq('account_id', userId);

  if (updateErr) {
    console.error('[cancel_order] Fallback update error:', updateErr);
    return err('Failed to cancel order', 500);
  }

  // Restore stock for each item (best-effort)
  const items = Array.isArray(order.order_items) ? order.order_items : [];
  for (const item of items) {
    if (item.product_id && item.quantity) {
      try {
        const { data: prod } = await supabaseAdmin
          .from('products')
          .select('stock_quantity')
          .eq('id', item.product_id)
          .maybeSingle();
        if (prod && typeof prod.stock_quantity === 'number') {
          await supabaseAdmin
            .from('products')
            .update({ stock_quantity: prod.stock_quantity + item.quantity })
            .eq('id', item.product_id);
        }
      } catch (_) {}
    }
  }

  return ok({ message: 'Order cancelled successfully.' });
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/orders/[id]  — Single order detail & live tracking info
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  const params = await context.params;
  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const { data: order, error } = await supabaseAdmin
    .from('orders')
    .select(`
      id, account_id, subtotal_paise, delivery_fee_paise, platform_fee_paise,
      slot_fee_paise, total_paise, delivery_slot, address_snapshot,
      payment_method, payment_status, status, points_awarded,
      device_location_address, device_latitude, device_longitude,
      destination_address, destination_latitude, destination_longitude,
      created_at, updated_at,
      order_items (
        id, product_id, title_snapshot, price_paise_snapshot,
        image_url_snapshot, unit_snapshot, quantity
      )
    `)
    .eq('id', params.id)
    .eq('account_id', userId)   // IDOR prevention: user can only see their own orders
    .maybeSingle();

  if (error) {
    console.error('[order/GET] error:', error);
    return err('Failed to fetch order', 500);
  }

  if (!order) return err('Order not found', 404);

  // Look up delivery assignment & partner live GPS if assigned
  let deliveryAssignment: Record<string, any> | null = null;
  let deliveryPartner: Record<string, any> | null = null;

  try {
    const { data: assignment } = await supabaseAdmin
      .from('delivery_assignments')
      .select('*')
      .eq('order_id', order.id)
      .maybeSingle();

    if (assignment) {
      deliveryAssignment = assignment;
      if (assignment.delivery_partner_id) {
        const { data: partner } = await supabaseAdmin
          .from('delivery_partners')
          .select('id, account_id, full_name, phone, vehicle_type, vehicle_number, avatar_url, rating, current_latitude, current_longitude, status')
          .or(`id.eq.${assignment.delivery_partner_id},account_id.eq.${assignment.delivery_partner_id}`)
          .maybeSingle();

        if (partner) {
          deliveryPartner = partner;
        }
      }
    }
  } catch (_) {}

  return ok({
    order: {
      ...order,
      user_id: order.account_id,
      account_id: order.account_id,
      delivery_assignment: deliveryAssignment,
      delivery_partner: deliveryPartner,
    },
  });
}

export async function OPTIONS() {
  return handleOptions();
}

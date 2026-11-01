import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAdmin } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/orders  — All orders (admin only)
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const url = new URL(req.url);
  const status = url.searchParams.get('status');
  const limit  = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);
  const offset = parseInt(url.searchParams.get('offset') ?? '0');

  let query = supabaseAdmin
    .from('orders')
    .select(`
      id, account_id, subtotal_paise, total_paise, delivery_slot,
      address_snapshot, payment_method, payment_status, status,
      device_location_address, device_latitude, device_longitude,
      destination_address, destination_latitude, destination_longitude,
      location_discrepancy_km, is_fraud_flagged,
      created_at, updated_at,
      accounts:accounts ( id, name, email, phone ),
      order_items ( id, title_snapshot, price_paise_snapshot, quantity, image_url_snapshot )
    `)
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (status && status !== 'All') query = query.eq('status', status);

  const { data: orders, error } = await query;

  if (error) {
    console.warn('[admin/orders/GET] direct join error, attempting fallback:', error);
    // Fallback query if relationships differ
    const fallback = await supabaseAdmin
      .from('orders')
      .select('*')
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (fallback.error) {
      console.error('[admin/orders/GET] fallback error:', fallback.error);
      return err('Failed to fetch orders', 500);
    }
    const mappedFallback = (fallback.data ?? []).map((o: any) => ({
      ...o,
      user_id: o.account_id,
      account_id: o.account_id,
    }));
    return ok({ orders: mappedFallback, offset, limit });
  }

  const mappedOrders = (orders ?? []).map((o: any) => ({
    ...o,
    user_id: o.account_id,
    account_id: o.account_id,
    users: o.accounts || o.users || null,
  }));

  return ok({ orders: mappedOrders, offset, limit });
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/orders  — Update order status (admin only)
// ─────────────────────────────────────────────────────────────────────────────

const UpdateStatusSchema = z.object({
  order_id: z.string().uuid().optional(),
  id: z.string().uuid().optional(),
  status: z.string().optional(),
  action: z.string().optional(),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, UpdateStatusSchema);
  if (parsed instanceof Response) return parsed;

  const targetId = parsed.data.order_id || parsed.data.id;
  if (!targetId) {
    return err('Missing order_id or id parameter', 400);
  }

  const rawStatus = parsed.data.status || 'Pending';
  // Normalize status casing
  let status = rawStatus;
  const lower = rawStatus.toLowerCase();
  if (lower === 'pending') status = 'Pending';
  else if (lower === 'processing') status = 'Processing';
  else if (lower === 'packed') status = 'Packed';
  else if (lower === 'out for delivery') status = 'Out for Delivery';
  else if (lower === 'on the way') status = 'On the way';
  else if (lower === 'delivered') status = 'Delivered';
  else if (lower === 'cancelled' || lower === 'canceled') status = 'Cancelled';

  // If admin marks order as Delivered, set payment_status to paid
  const updates: Record<string, string> = { status };
  if (status === 'Delivered') updates.payment_status = 'paid';

  let { error } = await supabaseAdmin
    .from('orders')
    .update(updates)
    .eq('id', targetId);

  // Fallback for databases using legacy status check constraint ('Processing' / 'Out for Delivery')
  if (error && (status === 'Packed' || status === 'On the way')) {
    const fallbackStatus = status === 'Packed' ? 'Processing' : 'Out for Delivery';
    const retry = await supabaseAdmin
      .from('orders')
      .update({ ...updates, status: fallbackStatus })
      .eq('id', targetId);
    error = retry.error;
  }

  if (error) {
    console.error('[admin/orders/PATCH] error:', error);
    return err('Failed to update order status', 500);
  }

  return ok({ message: 'Order status updated.' });
}

export async function POST(req: NextRequest) {
  return PATCH(req);
}

export async function PUT(req: NextRequest) {
  return PATCH(req);
}

export async function OPTIONS() {
  return handleOptions();
}

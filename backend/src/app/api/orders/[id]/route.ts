import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/orders/[id]/cancel
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

  const { data: result, error } = await supabaseAdmin.rpc('cancel_order', {
    p_account_id: userId,
    p_order_id: orderId,
  });

  if (error) {
    console.error('[cancel_order] RPC error:', error);
    return err('Failed to cancel order', 500);
  }

  if (!result?.success) {
    const code = result?.error;
    if (code === 'order_not_found') return err('Order not found', 404);
    if (code === 'cannot_cancel')
      return err(`Cannot cancel an order with status: ${result?.status}`, 409);
    return err(result?.error ?? 'Cancellation failed', 500);
  }

  return ok({ message: 'Order cancelled successfully.' });
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/orders/[id]  — Single order detail
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
      payment_method, payment_status, status, points_awarded, created_at,
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

  return ok({
    order: {
      ...order,
      user_id: order.account_id,
      account_id: order.account_id,
    },
  });
}

export async function OPTIONS() {
  return handleOptions();
}

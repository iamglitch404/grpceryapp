import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/orders/action — Update delivery lifecycle
// ─────────────────────────────────────────────────────────────────────────────
export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const body = await req.json();
    const { order_id, action, notes } = body;

    if (!order_id || !action) {
      return err('Missing order_id or action', 400);
    }

    const validActions = ['accept', 'decline', 'arrived_store', 'pick_up', 'deliver'];
    if (!validActions.includes(action)) {
      return err(`Invalid action. Allowed: ${validActions.join(', ')}`, 400);
    }

    // Resolve partner ID
    const { data: partner } = await supabaseAdmin
      .from('delivery_partners')
      .select('id, completed_deliveries_count, total_earned_paise')
      .eq('account_id', auth.accountId)
      .maybeSingle();

    const partnerId = partner?.id || auth.accountId;
    const now = new Date().toISOString();

    // Map action to order / assignment status
    let newOrderStatus = '';
    let newDeliveryStatus = '';

    if (action === 'accept') {
      newOrderStatus = 'Processing';
      newDeliveryStatus = 'accepted';
    } else if (action === 'decline') {
      newDeliveryStatus = 'declined';
    } else if (action === 'arrived_store') {
      newDeliveryStatus = 'arrived_store';
    } else if (action === 'pick_up') {
      newOrderStatus = 'Out for Delivery';
      newDeliveryStatus = 'in_transit';
    } else if (action === 'deliver') {
      newOrderStatus = 'Delivered';
      newDeliveryStatus = 'delivered';
    }

    // 1. Update orders table
    if (newOrderStatus) {
      await supabaseAdmin
        .from('orders')
        .update({
          status: newOrderStatus,
          updated_at: now,
        })
        .eq('id', order_id);
    }

    // 2. Upsert assignment record if table exists
    try {
      await supabaseAdmin
        .from('delivery_assignments')
        .upsert({
          order_id,
          delivery_partner_id: partnerId,
          status: newDeliveryStatus,
          accepted_at: action === 'accept' ? now : undefined,
          declined_at: action === 'decline' ? now : undefined,
          picked_up_at: action === 'pick_up' ? now : undefined,
          delivered_at: action === 'deliver' ? now : undefined,
          delivery_notes: notes,
          updated_at: now,
        }, { onConflict: 'order_id' });
    } catch (_) {}

    // 3. If delivered, credit partner stats and add earnings
    if (action === 'deliver' && partner) {
      const payoutPaise = 5000; // Rs. 50 default delivery payout
      await supabaseAdmin
        .from('delivery_partners')
        .update({
          completed_deliveries_count: (partner.completed_deliveries_count || 0) + 1,
          total_earned_paise: (partner.total_earned_paise || 0) + payoutPaise,
          updated_at: now,
        })
        .eq('id', partner.id);
    }

    return ok({
      success: true,
      order_id,
      action,
      new_order_status: newOrderStatus,
      new_delivery_status: newDeliveryStatus,
      updated_at: now,
    });
  } catch (e: any) {
    console.error('[delivery/orders/action/POST] error:', e);
    return err(e?.message || 'Failed to perform delivery action', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

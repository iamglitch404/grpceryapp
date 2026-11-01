import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/orders — List assigned and active orders for delivery partner
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    // 1. Resolve delivery partner ID
    const { data: partner } = await supabaseAdmin
      .from('delivery_partners')
      .select('id')
      .eq('account_id', auth.accountId)
      .maybeSingle();

    const partnerId = partner?.id || auth.accountId;

    // 2. Fetch orders assigned to this partner from delivery_assignments
    let assignments: any[] = [];
    try {
      const { data: directAssignments } = await supabaseAdmin
        .from('delivery_assignments')
        .select('*')
        .eq('delivery_partner_id', partnerId)
        .order('assigned_at', { ascending: false });

      if (directAssignments) assignments = directAssignments;
    } catch (_) {}

    const assignedOrderIds = assignments.map((a: any) => a.order_id).filter(Boolean);

    if (assignedOrderIds.length === 0) {
      return ok({
        pending_assignments: [],
        active_orders: [],
        completed_today: [],
        total_active: 0,
        total_pending: 0,
        total_completed: 0,
      });
    }

    const { data: ordersData, error: ordersErr } = await supabaseAdmin
      .from('orders')
      .select('*, order_items(*)')
      .in('id', assignedOrderIds)
      .order('created_at', { ascending: false });

    if (ordersErr) {
      console.error('[delivery/orders/GET] error:', ordersErr);
      return err('Failed to fetch orders', 500);
    }

    const allOrders = ordersData ?? [];

    // Map order with assignment metadata
    const enrichedOrders = allOrders.map((ord: any) => {
      const matchAssignment = assignments.find((a: any) => a.order_id === ord.id);
      const deliveryStatus = matchAssignment?.status ?? 
        (ord.status === 'Out for Delivery' || ord.status === 'On the way' ? 'in_transit' : 
         ord.status === 'Delivered' ? 'delivered' : 'assigned');

      // Resolve live destination / customer coordinates
      const destLat = ord.destination_latitude ?? ord.device_latitude ?? 27.7108;
      const destLng = ord.destination_longitude ?? ord.device_longitude ?? 85.3251;
      const customerAddress = ord.destination_address ?? ord.device_location_address ?? ord.address_snapshot?.address ?? 'Kathmandu, Nepal';
      const customerName = ord.address_snapshot?.name ?? ord.address_snapshot?.full_name ?? 'Customer';
      const customerPhone = ord.address_snapshot?.phone ?? ord.address_snapshot?.contact_number ?? '9800000000';

      return {
        ...ord,
        assignment_id: matchAssignment?.id,
        delivery_status: deliveryStatus,
        customer_name: customerName,
        customer_phone: customerPhone,
        customer_address: customerAddress,
        customer_latitude: destLat,
        customer_longitude: destLng,
        has_device_gps: !!(ord.device_latitude && ord.device_longitude),
        pickup_address: 'Dovan Hub & Fulfillment Center, Kathmandu',
        pickup_latitude: 27.7172,
        pickup_longitude: 85.3240,
        estimated_payout_paise: Math.max(ord.delivery_fee_paise || 5000, 4000),
      };
    });

    // Categorize orders
    const pendingAssignments = enrichedOrders.filter(
      (o: any) => o.delivery_status === 'assigned' && o.status !== 'Delivered' && o.status !== 'Cancelled'
    );
    const activeOrders = enrichedOrders.filter(
      (o: any) => ['accepted', 'arrived_store', 'picked_up', 'in_transit'].includes(o.delivery_status) &&
                  o.status !== 'Delivered' && o.status !== 'Cancelled'
    );
    const completedToday = enrichedOrders.filter(
      (o: any) => o.delivery_status === 'delivered' || o.status === 'Delivered'
    );

    return ok({
      pending_assignments: pendingAssignments,
      active_orders: activeOrders,
      completed_today: completedToday,
      total_active: activeOrders.length,
      total_pending: pendingAssignments.length,
      total_completed: completedToday.length,
    });
  } catch (e: any) {
    console.error('[delivery/orders/GET] error:', e);
    return err(e?.message || 'Failed to list orders', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

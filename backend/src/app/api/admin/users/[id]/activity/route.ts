import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAdmin } from '@/lib/api';

// GET /api/admin/users/[id]/activity  — fetch orders, reviews, favorites for a user
export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const { id: userId } = await params;
  if (!userId) return err('Missing user id', 400);

  const [ordersRes, reviewsRes, favoritesRes, addressesRes, notifsRes, pointsRes, cartRes, sessionsRes] = await Promise.all([
    supabaseAdmin
      .from('orders')
      .select('*, order_items(*, products(*))')
      .eq('account_id', userId)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('reviews')
      .select('*, products(*)')
      .eq('account_id', userId)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('favorites')
      .select('*, products(*)')
      .eq('account_id', userId)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('addresses')
      .select('*')
      .eq('account_id', userId)
      .order('is_default', { ascending: false })
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('notifications')
      .select('*')
      .eq('account_id', userId)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('user_points_ledger')
      .select('*')
      .eq('account_id', userId)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('cart')
      .select('*, products(*)')
      .eq('account_id', userId)
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('sessions')
      .select('*')
      .eq('account_id', userId)
      .order('created_at', { ascending: false }),
  ]);

  const orders = ordersRes.data ?? [];
  const pointsLedger = pointsRes.data ?? [];

  // Calculate points metrics
  let balance = 0;
  let earned = 0;
  let spent = 0;
  for (const p of pointsLedger) {
    const delta = Number(p.points_change ?? p.delta) || 0;
    balance += delta;
    if (delta > 0) earned += delta;
    else spent += Math.abs(delta);
  }

  // Calculate total spent money
  let totalSpentMoney = 0;
  for (const o of orders) {
    const amt = o.total_amount ?? (o.total_amount_paise ? o.total_amount_paise / 100 : 0);
    totalSpentMoney += Number(amt) || 0;
  }

  // Determine loyalty tier
  let tier = 'Bronze';
  if (earned >= 5000) tier = 'Platinum';
  else if (earned >= 2000) tier = 'Gold';
  else if (earned >= 500) tier = 'Silver';

  return ok({
    orders,
    reviews: reviewsRes.data ?? [],
    favorites: favoritesRes.data ?? [],
    addresses: addressesRes.data ?? [],
    notifications: notifsRes.data ?? [],
    points_ledger: pointsLedger,
    cart: cartRes.data ?? [],
    sessions: sessionsRes.data ?? [],
    stats: {
      points_balance: balance,
      points_earned: earned,
      points_spent: spent,
      tier,
      total_spent_money: totalSpentMoney,
      total_orders_count: orders.length,
    },
  });
}

export async function OPTIONS() {
  return handleOptions();
}

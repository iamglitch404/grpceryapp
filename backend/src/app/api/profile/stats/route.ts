import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';
import { requireAuth } from '@/lib/api';

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    // 1. Try atomic get_user_stats RPC
    const { data: statsData, error: statsError } = await supabaseAdmin.rpc('get_user_stats', {
      p_user_id: auth.userId,
    });

    if (!statsError && statsData) {
      return ok({
        points: statsData.points ?? 0,
        totalOrders: statsData.totalOrders ?? 0,
        globalRank: statsData.globalRank ?? 1,
        tier: statsData.tier ?? 'Bronze',
        pointsLastUpdatedAt: statsData.pointsLastUpdatedAt ?? new Date().toISOString(),
      });
    }

    // 2. Direct ledger query fallback
    const { data: ledgerEntries } = await supabaseAdmin
      .from('user_points_ledger')
      .select('points_change, created_at')
      .eq('account_id', auth.userId)
      .order('created_at', { ascending: false });

    const points = (ledgerEntries ?? []).reduce((acc, curr) => acc + (curr.points_change || 0), 0);
    const lastUpdatedAt = ledgerEntries?.[0]?.created_at ?? new Date().toISOString();

    // 3. Compute dynamic rank: count how many accounts have strictly more points + 1
    const { data: allLedger } = await supabaseAdmin
      .from('user_points_ledger')
      .select('account_id, points_change');

    const userPointsMap: Record<string, number> = {};
    for (const entry of allLedger ?? []) {
      const aid = (entry as any).account_id;
      userPointsMap[aid] = (userPointsMap[aid] || 0) + (entry.points_change || 0);
    }

    let higherRankedCount = 0;
    for (const [uId, totalPts] of Object.entries(userPointsMap)) {
      if (uId !== auth.userId && totalPts > points) {
        higherRankedCount++;
      }
    }
    const globalRank = higherRankedCount + 1;

    return ok({
      points,
      totalOrders: 0,
      globalRank,
      tier: points >= 2500 ? 'Diamond' : points >= 1000 ? 'Platinum' : points >= 500 ? 'Gold' : points >= 200 ? 'Silver' : 'Bronze',
      pointsLastUpdatedAt: lastUpdatedAt,
    });
  } catch (error) {
    console.error('[GET /api/profile/stats] exception:', error);
    return ok({
      points: 0,
      totalOrders: 0,
      globalRank: 1,
      tier: 'Bronze',
      pointsLastUpdatedAt: new Date().toISOString(),
    });
  }
}

export async function OPTIONS() {
  return handleOptions();
}

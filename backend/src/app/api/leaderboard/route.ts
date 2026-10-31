import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/leaderboard
// Returns server-computed leaderboard — never trusts client-side points
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const url = new URL(req.url);
  const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);
  const offset = Math.max(parseInt(url.searchParams.get('offset') ?? '0'), 0);
  const search = (url.searchParams.get('search') ?? '').trim();
  const tier = (url.searchParams.get('tier') ?? '').trim();

  // Attempt RPC call with extended parameters
  const { data: leaderboard, error } = await supabaseAdmin.rpc('get_leaderboard', {
    p_limit: limit,
    p_offset: offset,
    p_search: search || null,
    p_tier: tier || null,
  });

  if (error) {
    // Backwards-compatible fallback with single p_limit parameter
    const fallback = await supabaseAdmin.rpc('get_leaderboard', {
      p_limit: Math.min(limit + offset + 50, 5000),
    });

    if (fallback.data) {
      let list = fallback.data as any[];
      if (search) {
        const s = search.toLowerCase();
        list = list.filter((u) => (u.name && u.name.toLowerCase().includes(s)) || `#${u.rank}`.includes(s));
      }
      if (tier && tier !== 'All') {
        list = list.filter((u) => u.tier?.toLowerCase() === tier.toLowerCase());
      }
      const page = list.slice(offset, offset + limit);
      return ok({
        leaderboard: page,
        hasMore: list.length > offset + limit,
      });
    }

    console.error('[leaderboard/GET] error:', error);
    return err('Failed to fetch leaderboard', 500);
  }

  const formatted = (leaderboard ?? []).map((u: any) => ({
    ...u,
    username: u.username || (u.name ? u.name.toLowerCase().replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_') : 'user'),
  }));

  return ok({
    leaderboard: formatted,
    hasMore: (leaderboard?.length ?? 0) === limit,
  });
}

export async function OPTIONS() {
  return handleOptions();
}

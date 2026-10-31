import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/products/my-submissions — List current user's submitted products
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const url = new URL(req.url);
  const status = url.searchParams.get('status');

  let query = supabaseAdmin
    .from('products')
    .select('*, categories(id, name, image_url)')
    .eq('seller_id', userId)
    .order('created_at', { ascending: false });

  if (status && status !== 'all') {
    query = query.eq('approval_status', status);
  }

  const { data, error } = await query;

  if (error) {
    console.error('[products/my-submissions] error:', error);
    return err('Failed to fetch product submissions', 500);
  }

  const formatted = (data ?? []).map((p: any) => ({
    ...p,
    qr_payload: JSON.stringify({
      code: p.product_code || p.id,
      id: p.id,
      title: p.title,
      seller_id: p.seller_id,
      pickup_address: p.pickup_address,
      status: p.approval_status,
    }),
  }));

  return ok({
    products: formatted,
    total: formatted.length,
    counts: {
      pending: formatted.filter((p: any) => p.approval_status === 'pending').length,
      scheduled: formatted.filter((p: any) => p.approval_status === 'scheduled_for_pickup').length,
      listed: formatted.filter((p: any) => p.approval_status === 'listed').length,
      rejected: formatted.filter((p: any) => p.approval_status === 'rejected').length,
    },
  });
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextRequest } from 'next/server';
import { z } from 'zod';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reviews
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();
  const url = new URL(req.url);
  const productId = url.searchParams.get('product_id');
  const userId = url.searchParams.get('user_id') || url.searchParams.get('account_id');

  if (!productId && !userId) {
    return err('Missing product_id or user_id parameter', 400);
  }

  let query = supabaseAdmin
    .from('reviews')
    .select('*, accounts(id, name, profile_image), products(*)')
    .order('created_at', { ascending: false });

  if (productId) {
    query = query.eq('product_id', productId);
  } else if (userId) {
    query = query.eq('account_id', userId);
  }

  const { data: reviews, error } = await query;

  if (error) {
    return err('Failed to fetch reviews', 500);
  }

  const formatted = (reviews ?? []).map((r: any) => ({
    ...r,
    user_id: r.account_id,
    account_id: r.account_id,
    users: {
      name: r.accounts?.name || 'User',
      avatar_url: r.accounts?.profile_image || null,
    },
    accounts: r.accounts,
  }));

  return ok(formatted);
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/reviews
// ─────────────────────────────────────────────────────────────────────────────
const ReviewSchema = z.object({
  product_id: z.string().uuid(),
  rating: z.number().int().min(1).max(5),
  comment: z.string().max(1000).optional(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, ReviewSchema);
  if (parsed instanceof Response) return parsed;
  const { product_id, rating, comment } = parsed.data;

  // Verify product exists
  const { data: product, error: productError } = await supabaseAdmin
    .from('products')
    .select('id')
    .eq('id', product_id)
    .single();

  if (productError || !product) {
    return err('Product item not found', 404);
  }

  // Insert or update review (user can only have 1 review per product due to UNIQUE constraint)
  const { data, error } = await supabaseAdmin
    .from('reviews')
    .upsert(
      { account_id: userId, product_id, rating, comment },
      { onConflict: 'account_id,product_id' }
    )
    .select()
    .single();

  if (error) {
    console.error('[reviews/POST] error:', error);
    return err('Failed to submit review', 500);
  }

  return ok({ ...data, user_id: data.account_id, account_id: data.account_id }, 201);
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/reviews/[id] (Using query param id for simplicity here)
// ─────────────────────────────────────────────────────────────────────────────
const UpdateReviewSchema = z.object({
  review_id: z.string().uuid(),
  rating: z.number().int().min(1).max(5).optional(),
  comment: z.string().max(1000).optional(),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, UpdateReviewSchema);
  if (parsed instanceof Response) return parsed;
  const { review_id, rating, comment } = parsed.data;

  if (rating === undefined && comment === undefined) {
    return err('Nothing to update', 400);
  }

  // Update only if it belongs to the user
  const updates: any = {};
  if (rating !== undefined) updates.rating = rating;
  if (comment !== undefined) updates.comment = comment;

  const { data, error } = await supabaseAdmin
    .from('reviews')
    .update(updates)
    .eq('id', review_id)
    .eq('account_id', userId)
    .select()
    .single();

  if (error || !data) {
    return err('Review not found or permission denied', 404);
  }

  return ok({ ...data, user_id: data.account_id, account_id: data.account_id });
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/reviews
// ─────────────────────────────────────────────────────────────────────────────
export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const url = new URL(req.url);
  const review_id = url.searchParams.get('review_id');

  if (!review_id) {
    return err('Missing review_id parameter', 400);
  }

  const { error } = await supabaseAdmin
    .from('reviews')
    .delete()
    .eq('id', review_id)
    .eq('account_id', userId);

  if (error) {
    console.error('[reviews/DELETE] error:', error);
    return err('Failed to delete review', 500);
  }

  return ok({ message: 'Review deleted' });
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextRequest } from 'next/server';
import { z } from 'zod';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/favorites
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  // We want to return the product details as well
  const { data, error } = await supabaseAdmin
    .from('favorites')
    .select(`
      id,
      account_id,
      product_id,
      created_at,
      products (
        id, title, price_paise, original_price_paise, image_url, unit, is_active, avg_rating
      )
    `)
    .eq('account_id', userId)
    .order('created_at', { ascending: false });

  if (error || !data) {
    console.warn('[favorites/GET] notice:', error?.message);
    return ok({ favorites: [] });
  }

  // Flatten the response slightly for the frontend
  const formatted = data
    .filter(item => item.products != null)
    .map(item => ({
      favorite_id: item.id,
      account_id: item.account_id,
      user_id: item.account_id,
      product_id: item.product_id,
      created_at: item.created_at,
      product: item.products
    }));

  return ok({ favorites: formatted });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/favorites
// ─────────────────────────────────────────────────────────────────────────────
const AddFavoriteSchema = z.object({
  product_id: z.string().uuid(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, AddFavoriteSchema);
  if (parsed instanceof Response) return parsed;
  const { product_id } = parsed.data;

  // Check if product exists and is active
  const { data: product, error: productError } = await supabaseAdmin
    .from('products')
    .select('id, is_active')
    .eq('id', product_id)
    .single();

  if (productError || !product || !product.is_active) {
    return err('Product item not found or unavailable', 404);
  }

  // Insert favorite (UPSERT to avoid unique constraint violations)
  const { data, error } = await supabaseAdmin
    .from('favorites')
    .upsert({ account_id: userId, product_id }, { onConflict: 'account_id,product_id' })
    .select()
    .single();

  if (error) {
    console.error('[favorites/POST] error:', error);
    return err('Failed to add favorite', 500);
  }

  return ok({ ...data, user_id: data.account_id, account_id: data.account_id }, 201);
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/favorites
// ─────────────────────────────────────────────────────────────────────────────
const DeleteFavoriteSchema = z.object({
  product_id: z.string().uuid(),
});

export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  // Use URL search params instead of body for DELETE
  const url = new URL(req.url);
  const product_id = url.searchParams.get('product_id');

  if (!product_id) {
    // Fallback to body parsing if product_id is not in query params (for compatibility)
    const parsed = await parseBody(req, DeleteFavoriteSchema);
    if (parsed instanceof Response) return parsed;
    var parsedProductId = parsed.data.product_id;
  } else {
    var parsedProductId = product_id;
  }

  const { error } = await supabaseAdmin
    .from('favorites')
    .delete()
    .eq('account_id', userId)
    .eq('product_id', parsedProductId);

  if (error) {
    console.error('[favorites/DELETE] error:', error);
    return err('Failed to remove favorite', 500);
  }

  return ok({ message: 'Favorite removed' });
}

export async function OPTIONS() {
  return handleOptions();
}

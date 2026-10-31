import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/cart  — Fetch authenticated user's cart
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const { data: cartRows, error } = await supabaseAdmin
    .from('cart')
    .select(`
      id,
      product_id,
      quantity,
      products (
        id,
        title,
        price_paise,
        original_price_paise,
        unit,
        image_url,
        stock_quantity,
        is_active
      )
    `)
    .eq('account_id', userId);

  if (error) {
    console.error('[cart/GET] error:', error);
    return err('Failed to fetch cart', 500);
  }

  const items = (cartRows ?? []).map((row: any) => {
    const p = row.products;
    return {
      id: row.id,
      product_id: row.product_id,
      quantity: row.quantity,
      price_paise: p?.price_paise ?? 0,
      title: p?.title ?? '',
      image_url: p?.image_url ?? '',
      unit: p?.unit ?? '1 kg',
      stock_quantity: p?.stock_quantity ?? 0,
      foods: p,
    };
  });

  // Calculate totals server-side (authoritative)
  const subtotalPaise = items.reduce(
    (sum: number, item: any) => sum + item.price_paise * item.quantity,
    0
  );

  return ok({ items, subtotal_paise: subtotalPaise });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/cart  — Add item to cart
// ─────────────────────────────────────────────────────────────────────────────

const AddToCartSchema = z.object({
  product_id: z.string().uuid(),
  quantity: z.number().int().min(1).max(99),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, AddToCartSchema);
  if (parsed instanceof Response) return parsed;
  const { product_id, quantity } = parsed.data;

  // Validate product exists, is active, and has sufficient stock
  const { data: product } = await supabaseAdmin
    .from('products')
    .select('id, title, stock_quantity, is_active')
    .eq('id', product_id)
    .maybeSingle();

  if (!product || !product.is_active) {
    return err('Product not found or unavailable', 404);
  }

  // Check if already in cart
  const { data: existing } = await supabaseAdmin
    .from('cart')
    .select('id, quantity')
    .eq('account_id', userId)
    .eq('product_id', product_id)
    .maybeSingle();

  const newQuantity = existing ? existing.quantity + quantity : quantity;

  if (newQuantity > product.stock_quantity) {
    return err(
      `Only ${product.stock_quantity} unit(s) of "${product.title}" available`,
      409
    );
  }

  if (existing) {
    await supabaseAdmin
      .from('cart')
      .update({ quantity: newQuantity })
      .eq('id', existing.id);
  } else {
    await supabaseAdmin
      .from('cart')
      .insert({ account_id: userId, product_id, quantity });
  }

  return ok({ message: 'Cart updated.', new_quantity: newQuantity });
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/cart  — Clear entire cart
// ─────────────────────────────────────────────────────────────────────────────

export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  await supabaseAdmin.from('cart').delete().eq('account_id', userId);
  return ok({ message: 'Cart cleared.' });
}

export async function OPTIONS() {
  return handleOptions();
}

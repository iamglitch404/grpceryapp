import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/cart/[id]  — Update cart item quantity
// ─────────────────────────────────────────────────────────────────────────────

const UpdateCartSchema = z.object({
  quantity: z.number().int().min(1).max(99),
});

export async function PATCH(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  const params = await context.params;
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, UpdateCartSchema);
  if (parsed instanceof Response) return parsed;
  const { quantity } = parsed.data;

  // Verify ownership of the cart item and check stock
  const { data: cartItem } = await supabaseAdmin
    .from('cart')
    .select('id, product_id, products(stock_quantity)')
    .eq('id', params.id)
    .eq('account_id', userId)
    .maybeSingle();

  if (!cartItem) {
    return err('Cart item not found', 404);
  }

  const stock = (cartItem.products as unknown as { stock_quantity: number })?.stock_quantity ?? 0;
  if (quantity > stock) {
    return err(`Only ${stock} unit(s) available`, 409);
  }

  const { error } = await supabaseAdmin
    .from('cart')
    .update({ quantity })
    .eq('id', params.id);

  if (error) {
    console.error('[cart/PATCH] error:', error);
    return err('Failed to update cart quantity', 500);
  }

  return ok({ message: 'Quantity updated' });
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/cart/[id]  — Remove item from cart
// ─────────────────────────────────────────────────────────────────────────────

export async function DELETE(
  req: NextRequest,
  context: { params: Promise<{ id: string }> }
) {
  const params = await context.params;
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  // We only delete if it belongs to the user
  const { error } = await supabaseAdmin
    .from('cart')
    .delete()
    .eq('id', params.id)
    .eq('account_id', userId);

  if (error) {
    console.error('[cart/DELETE] error:', error);
    return err('Failed to remove item', 500);
  }

  return ok({ message: 'Item removed' });
}

export async function OPTIONS() {
  return handleOptions();
}

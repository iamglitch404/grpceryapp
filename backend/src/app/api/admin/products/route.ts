import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAdmin, requireAuth } from '@/lib/api';

const ProductSchema = z.object({
  id: z.string().uuid().optional(),
  title: z.string().min(1),
  description: z.string().optional().nullable(),
  price_paise: z.number().int().min(0),
  original_price_paise: z.number().int().min(0).optional().nullable(),
  unit: z.string().optional().nullable(),
  image_url: z.string().optional().nullable(),
  category_id: z.string().uuid().optional().nullable(),
  subcategory_id: z.string().uuid().optional().nullable(),
  stock_quantity: z.number().int().min(0).optional(),
  is_todays_choice: z.boolean().optional(),
  is_special_deal: z.boolean().optional(),
  is_popular: z.boolean().optional(),
  is_active: z.boolean().optional(),
  calories: z.string().optional().nullable(),
  delivery_time_minutes: z.number().int().optional().nullable(),
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/products — Admin: list all products (including inactive)
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    let { data, error } = await supabaseAdmin
      .from('products')
      .select('*, categories(id, name, color_hex), subcategories(id, name, slug)')
      .order('created_at', { ascending: false });

    if (error) {
      console.warn('[admin/products/GET] Join error, attempting direct select:', error);
      const fallback = await supabaseAdmin
        .from('products')
        .select('*')
        .order('created_at', { ascending: false });

      if (fallback.error) {
        console.error('[admin/products/GET] Direct query error:', fallback.error);
        return err('Failed to fetch products', 500);
      }
      data = fallback.data;
    }

    const formatted = (data ?? []).map((p: any) => {
      const cat = p.categories;
      const sub = p.subcategories;
      return {
        ...p,
        name: p.title,
        image: p.image_url,
        category_name: cat?.name ?? p.category_name ?? null,
        subcategory_name: sub?.name ?? p.subcategory_name ?? null,
        categories: cat
          ? {
              ...cat,
              label: cat.name,
              color: cat.color_hex,
            }
          : null,
        subcategories: sub ?? null,
      };
    });

    return ok({ products: formatted, data: formatted });
  } catch (errCatch) {
    console.error('[admin/products/GET] catch error:', errCatch);
    return err('Internal Server Error', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/products — Admin: create product
// ─────────────────────────────────────────────────────────────────────────────
export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, ProductSchema);
  if (parsed instanceof Response) return parsed;

  const { id: _id, ...fields } = parsed.data;

  // Enforce DB constraint: original_price_paise >= price_paise
  if (fields.original_price_paise !== undefined && fields.original_price_paise !== null) {
    if (fields.original_price_paise < fields.price_paise) {
      fields.original_price_paise = fields.price_paise;
    }
  }

  const { data, error } = await supabaseAdmin
    .from('products')
    .insert(fields)
    .select()
    .single();

  if (error) {
    console.error('[admin/products/POST] error:', error);
    return err('Failed to create product', 500);
  }

  return ok({ product: data, data }, 201);
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/products — Admin: update product
// ─────────────────────────────────────────────────────────────────────────────
export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, ProductSchema);
  if (parsed instanceof Response) return parsed;

  const { id, ...updates } = parsed.data;
  if (!id) return err('Missing product id', 400);

  // Enforce DB constraint: original_price_paise >= price_paise
  if (updates.original_price_paise !== undefined && updates.original_price_paise !== null) {
    if (updates.price_paise !== undefined && updates.original_price_paise < updates.price_paise) {
      updates.original_price_paise = updates.price_paise;
    }
  }

  const { data, error } = await supabaseAdmin
    .from('products')
    .update(updates)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    console.error('[admin/products/PATCH] error:', error);
    return err('Failed to update product', 500);
  }

  return ok({ product: data, data });
}

// Also support PUT
export async function PUT(req: NextRequest) {
  return PATCH(req);
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/admin/products?id=<uuid> — Admin: delete product
// ─────────────────────────────────────────────────────────────────────────────
export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const url = new URL(req.url);
  const id = url.searchParams.get('id');
  if (!id) return err('Missing product id', 400);

  // Safe soft-deactivation (preserves historical orders and reviews integrity)
  const { error } = await supabaseAdmin
    .from('products')
    .update({ 
      is_active: false,
      approval_status: 'rejected',
      updated_at: new Date().toISOString(),
    })
    .eq('id', id);

  if (error) {
    console.error('[admin/products/DELETE] error:', error);
    return err('Failed to deactivate product', 500);
  }

  return ok({ message: 'Product deactivated successfully' });
}

export async function OPTIONS() {
  return handleOptions();
}


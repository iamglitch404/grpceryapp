import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAdmin, requireAuth } from '@/lib/api';

const CategorySchema = z.object({
  id: z.string().uuid().optional(),
  name: z.string().min(1).optional(),
  label: z.string().min(1).optional(),
  image_url: z.string().optional().nullable(),
  image: z.string().optional().nullable(),
  color_hex: z.string().optional().nullable(),
  color: z.string().optional().nullable(),
  slug: z.string().optional(),
  sort_order: z.number().int().optional(),
  is_active: z.boolean().optional(),
});

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();
  
  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  const { data, error } = await supabaseAdmin
    .from('categories')
    .select('*, subcategories(*)')
    .order('sort_order', { ascending: true });

  if (error) {
    console.error('[admin/categories/GET] error:', error);
    return err('Failed to fetch categories', 500);
  }

  const formatted = (data ?? []).map((c: any) => ({
    ...c,
    label: c.name,
    image: c.image_url,
    color: c.color_hex,
  }));

  return ok(formatted);
}

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();
  
  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, CategorySchema);
  if (parsed instanceof Response) return parsed;
  const name = parsed.data.name || parsed.data.label;
  if (!name) return err('Category name is required', 400);

  const image_url = parsed.data.image_url ?? parsed.data.image ?? null;
  const color_hex = parsed.data.color_hex !== undefined 
    ? (parsed.data.color_hex || null) 
    : (parsed.data.color !== undefined ? (parsed.data.color || null) : null);
  const slug = parsed.data.slug || name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
  const sort_order = parsed.data.sort_order ?? 0;
  const is_active = parsed.data.is_active ?? true;

  const { data, error } = await supabaseAdmin
    .from('categories')
    .insert({ name, slug, image_url, color_hex, sort_order, is_active })
    .select()
    .single();

  if (error) {
    console.error('[admin/categories/POST] error:', error);
    if (error.code === '23505' || error.message?.includes('duplicate key') || error.message?.includes('categories_slug_key')) {
      return err(`Category "${name}" already exists`, 409);
    }
    return err(error.message || 'Failed to create category', 500);
  }

  return ok(data, 201);
}

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();
  
  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, CategorySchema);
  if (parsed instanceof Response) return parsed;
  const id = parsed.data.id;
  if (!id) return err('Missing category id', 400);

  const updates: Record<string, any> = {};
  const name = parsed.data.name || parsed.data.label;
  if (name) {
    updates.name = name;
    if (!parsed.data.slug) {
      updates.slug = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    }
  }
  if (parsed.data.image_url !== undefined || parsed.data.image !== undefined) {
    updates.image_url = parsed.data.image_url ?? parsed.data.image;
  }
  if (parsed.data.color_hex !== undefined || parsed.data.color !== undefined) {
    updates.color_hex = parsed.data.color_hex ?? parsed.data.color;
  }
  if (parsed.data.slug !== undefined) updates.slug = parsed.data.slug;
  if (parsed.data.sort_order !== undefined) updates.sort_order = parsed.data.sort_order;
  if (parsed.data.is_active !== undefined) updates.is_active = parsed.data.is_active;

  const { data, error } = await supabaseAdmin
    .from('categories')
    .update(updates)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    console.error('[admin/categories/PATCH] error:', error);
    if (error.code === '23505' || error.message?.includes('duplicate key') || error.message?.includes('categories_slug_key')) {
      return err(`Category "${name || 'with this name'}" already exists`, 409);
    }
    return err(error.message || 'Failed to update category', 500);
  }

  return ok(data);
}

export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();
  
  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const url = new URL(req.url);
  const id = url.searchParams.get('id');

  if (!id) return err('Missing category id', 400);

  const { error } = await supabaseAdmin
    .from('categories')
    .delete()
    .eq('id', id);

  if (error) {
    console.error('[admin/categories/DELETE] error:', error);
    return err('Failed to delete category', 500);
  }

  return ok({ message: 'Category deleted' });
}

export async function OPTIONS() {
  return handleOptions();
}

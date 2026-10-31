import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAuth, requireAdmin } from '@/lib/api';

const SubcategorySchema = z.object({
  id: z.string().uuid().optional(),
  category_id: z.string().uuid({ message: 'Valid category_id is required' }),
  name: z.string().min(1, { message: 'Subcategory name is required' }),
  slug: z.string().optional(),
  image_url: z.string().optional().nullable(),
  description: z.string().optional().nullable(),
  sort_order: z.number().int().optional(),
  is_active: z.boolean().optional(),
});

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  const url = new URL(req.url);
  const categoryId = url.searchParams.get('category_id');

  let query = supabaseAdmin
    .from('subcategories')
    .select('*, categories(id, name, color_hex)')
    .order('sort_order', { ascending: true });

  if (categoryId) {
    query = query.eq('category_id', categoryId);
  }

  const { data, error } = await query;
  if (error) {
    console.error('[admin/subcategories/GET] error:', error);
    return err('Failed to fetch subcategories', 500);
  }

  return ok(data ?? []);
}

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, SubcategorySchema);
  if (parsed instanceof Response) return parsed;

  const { category_id, name, description, image_url, sort_order, is_active } = parsed.data;
  const slug = parsed.data.slug || name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

  const { data, error } = await supabaseAdmin
    .from('subcategories')
    .insert({
      category_id,
      name,
      slug,
      description: description ?? null,
      image_url: image_url ?? null,
      sort_order: sort_order ?? 0,
      is_active: is_active ?? true,
    })
    .select()
    .single();

  if (error) {
    console.error('[admin/subcategories/POST] error:', error);
    return err(error.message || 'Failed to create subcategory', 500);
  }

  return ok(data, 201);
}

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, SubcategorySchema);
  if (parsed instanceof Response) return parsed;

  const { id, ...updates } = parsed.data;
  if (!id) return err('Missing subcategory id', 400);

  const { data, error } = await supabaseAdmin
    .from('subcategories')
    .update(updates)
    .eq('id', id)
    .select()
    .single();

  if (error) {
    console.error('[admin/subcategories/PATCH] error:', error);
    return err(error.message || 'Failed to update subcategory', 500);
  }

  return ok(data);
}

export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const url = new URL(req.url);
  const id = url.searchParams.get('id');
  if (!id) return err('Missing subcategory id', 400);

  const { error } = await supabaseAdmin
    .from('subcategories')
    .delete()
    .eq('id', id);

  if (error) {
    console.error('[admin/subcategories/DELETE] error:', error);
    return err(error.message || 'Failed to delete subcategory', 500);
  }

  return ok({ message: 'Subcategory deleted' });
}

export async function OPTIONS() {
  return handleOptions();
}

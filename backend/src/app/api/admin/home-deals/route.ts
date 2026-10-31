import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/home-deals — List all home deals (including inactive)
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const { data, error } = await supabaseAdmin
      .from('home_deals')
      .select('*')
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false });

    if (error) return err(error.message, 500);
    return ok({ home_deals: data ?? [] });
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/home-deals — Create a new home deal
// ─────────────────────────────────────────────────────────────────────────────
export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const body = await req.json();
    const {
      title,
      subtitle,
      badge_text,
      button_text,
      image_url,
      discount_percent,
      target_type,
      target_id,
      product_ids,
      bg_color,
      button_color,
      is_active,
      sort_order,
      valid_until,
    } = body;

    if (!title) {
      return err('Deal title is required', 400);
    }

    const { data, error } = await supabaseAdmin
      .from('home_deals')
      .insert({
        title,
        subtitle: subtitle || null,
        badge_text: badge_text || '⚡ FLASH SALE',
        button_text: button_text || 'Shop Now',
        image_url: image_url || null,
        discount_percent: discount_percent ?? 20.00,
        target_type: target_type || 'products',
        target_id: target_id || null,
        product_ids: Array.isArray(product_ids) ? product_ids : null,
        bg_color: bg_color || '#E8F5EE',
        button_color: button_color || '#185B3A',
        is_active: is_active ?? true,
        sort_order: sort_order ?? 0,
        valid_until: valid_until || null,
      })
      .select()
      .single();

    if (error) {
      console.error('[POST /api/admin/home-deals] insert error:', error);
      return err(error.message, 500);
    }

    return ok({ message: 'Home deal created successfully', deal: data }, 201);
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/admin/home-deals — Update a home deal
// ─────────────────────────────────────────────────────────────────────────────
export async function PUT(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const body = await req.json();
    const { id, ...updates } = body;

    if (!id) return err('Home deal ID is required', 400);

    const { data, error } = await supabaseAdmin
      .from('home_deals')
      .update({
        ...updates,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .single();

    if (error) return err(error.message, 500);

    return ok({ message: 'Home deal updated successfully', deal: data });
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/admin/home-deals — Delete a home deal
// ─────────────────────────────────────────────────────────────────────────────
export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) return err('Home deal ID is required', 400);

    const { error } = await supabaseAdmin
      .from('home_deals')
      .delete()
      .eq('id', id);

    if (error) return err(error.message, 500);

    return ok({ message: 'Home deal deleted successfully' });
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

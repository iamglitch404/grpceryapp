import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/promotions — List all promotions (including inactive)
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const { data, error } = await supabaseAdmin
      .from('promotions')
      .select('*')
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false });

    if (error) return err(error.message, 500);
    return ok({ promotions: data ?? [] });
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/promotions — Create a new promotion
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
      bg_color,
      button_color,
      is_active,
      sort_order,
      valid_until,
    } = body;

    if (!title) {
      return err('Promotion title is required', 400);
    }

    const { data, error } = await supabaseAdmin
      .from('promotions')
      .insert({
        title,
        subtitle: subtitle || null,
        badge_text: badge_text || 'SPECIAL OFFER',
        button_text: button_text || 'Shop Now',
        image_url: image_url || null,
        discount_percent: discount_percent ?? 20.00,
        target_type: target_type || 'category',
        target_id: target_id || null,
        bg_color: bg_color || '#E8F5EE',
        button_color: button_color || '#185B3A',
        is_active: is_active ?? true,
        sort_order: sort_order ?? 0,
        valid_until: valid_until || null,
      })
      .select()
      .single();

    if (error) {
      console.error('[POST /api/admin/promotions] insert error:', error);
      return err(error.message, 500);
    }

    return ok({ message: 'Promotion created successfully', promotion: data }, 201);
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/admin/promotions — Update a promotion
// ─────────────────────────────────────────────────────────────────────────────
export async function PUT(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const body = await req.json();
    const { id, ...updates } = body;

    if (!id) return err('Promotion ID is required', 400);

    const { data, error } = await supabaseAdmin
      .from('promotions')
      .update({
        ...updates,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .single();

    if (error) return err(error.message, 500);

    return ok({ message: 'Promotion updated successfully', promotion: data });
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/admin/promotions — Delete a promotion
// ─────────────────────────────────────────────────────────────────────────────
export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) return err('Promotion ID is required', 400);

    const { error } = await supabaseAdmin
      .from('promotions')
      .delete()
      .eq('id', id);

    if (error) return err(error.message, 500);

    return ok({ message: 'Promotion deleted successfully' });
  } catch (e: any) {
    return err(e.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/promotions — Public Dynamic Campaigns & Hero Banners
// Reads directly from public.promotions in schema.sql
// ─────────────────────────────────────────────────────────────────────────────

export async function GET() {
  try {
    const { data, error } = await supabaseAdmin
      .from('promotions')
      .select('*')
      .eq('is_active', true)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('[GET /api/promotions] error:', error);
      return err('Failed to fetch promotions', 500);
    }

    // Map database fields gracefully to match schema.sql
    const formatted = (data ?? []).map((p: any) => ({
      id: p.id,
      code: p.code || '',
      title: p.title || '',
      subtitle: p.subtitle || p.description || '',
      description: p.description || p.subtitle || '',
      badge_text: p.badge_text || (p.discount_value ? `${p.discount_value}% OFF` : 'SPECIAL OFFER'),
      button_text: p.button_text || 'Shop Now',
      image_url: p.image_url || '',
      discount_percent: p.discount_percent ?? p.discount_value ?? 20.0,
      discount_value: p.discount_value ?? p.discount_percent ?? 20.0,
      target_type: p.target_type || 'category',
      target_id: p.target_id || null,
      bg_color: p.bg_color || '#E8F5EE',
      button_color: p.button_color || '#185B3A',
      is_active: p.is_active ?? true,
      sort_order: p.sort_order ?? 0,
    }));

    return ok({ promotions: formatted });
  } catch (e: any) {
    console.error('[GET /api/promotions] catch error:', e);
    return err(e.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

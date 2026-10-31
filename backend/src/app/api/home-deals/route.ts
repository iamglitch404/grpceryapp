import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/home-deals — Public Dynamic Home Campaign Cards & Banners
// Reads directly from public.home_deals in schema.sql
// ─────────────────────────────────────────────────────────────────────────────

export async function GET() {
  try {
    const { data, error } = await supabaseAdmin
      .from('home_deals')
      .select('*')
      .eq('is_active', true)
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false });

    if (error) {
      // If table home_deals is not yet migrated, fall back to promotions table
      const { data: fallbackData } = await supabaseAdmin
        .from('promotions')
        .select('*')
        .eq('is_active', true);

      return ok({ home_deals: fallbackData ?? [] });
    }

    return ok({ home_deals: data ?? [] });
  } catch (e: any) {
    return err(e?.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';

export async function GET() {
  try {
    const { data, error } = await supabaseAdmin
      .from('categories')
      .select('*, subcategories(*)')
      .eq('is_active', true)
      .order('sort_order', { ascending: true });

    if (error) {
      console.error('[GET /api/categories] error:', error);
      // Fallback query if subcategories table is not created yet
      const { data: fallbackData } = await supabaseAdmin
        .from('categories')
        .select('*')
        .eq('is_active', true)
        .order('sort_order', { ascending: true });

      return ok({
        categories: (fallbackData ?? []).map((c: any) => ({
          ...c,
          image: c.image_url,
          label: c.name,
          subcategories: [],
        })),
      });
    }

    const formattedCategories = data?.map((c: any) => {
      const activeSubs = (c.subcategories ?? [])
        .filter((s: any) => s.is_active !== false)
        .sort((a: any, b: any) => (a.sort_order ?? 0) - (b.sort_order ?? 0));

      return {
        ...c,
        image: c.image_url,
        label: c.name,
        subcategories: activeSubs,
      };
    });

    return ok({ categories: formattedCategories ?? [] });
  } catch (e) {
    console.error('[GET /api/categories] catch error:', e);
    return err('Failed to fetch categories', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

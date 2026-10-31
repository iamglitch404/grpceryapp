import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';

export async function GET() {
  try {
    const { data } = await supabaseAdmin
      .from('home_deals')
      .select('*')
      .eq('is_active', true)
      .order('sort_order', { ascending: true })
      .order('created_at', { ascending: false });

    return ok({ banners: data ?? [] });
  } catch {
    return ok({ banners: [] });
  }
}

export async function OPTIONS() {
  return handleOptions();
}

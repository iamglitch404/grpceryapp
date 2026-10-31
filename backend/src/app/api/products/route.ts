import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/products  — Public product listing with Category & Subcategory
// ─────────────────────────────────────────────────────────────────────────────

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const url = new URL(req.url);
  const categoryId    = url.searchParams.get('category_id');
  const subcategoryId = url.searchParams.get('subcategory_id');
  const todaysChoice  = url.searchParams.get('is_todays_choice');
  const specialDeal   = url.searchParams.get('is_special_deal');
  const popular       = url.searchParams.get('is_popular');
  const search        = url.searchParams.get('search');
  const limit         = Math.min(parseInt(url.searchParams.get('limit') ?? '30'), 100);
  const offset        = parseInt(url.searchParams.get('offset') ?? '0');
  const ids           = url.searchParams.get('ids');
  const isRandom      = url.searchParams.get('random') === 'true';

  let query = supabaseAdmin
    .from('products')
    .select(`
      id, title, description, price_paise, original_price_paise,
      unit, image_url, category_id, subcategory_id, stock_quantity,
      is_todays_choice, is_special_deal, is_popular,
      avg_rating, review_count, purchase_count,
      calories, delivery_time_minutes, tags,
      categories ( id, name, color_hex ),
      subcategories ( id, name, slug )
    `)
    .eq('is_active', true)
    .or('approval_status.eq.listed,approval_status.is.null');

  if (ids) {
    const idList = ids.split(',').map((s) => s.trim()).filter(Boolean);
    if (idList.length > 0) {
      query = query.in('id', idList);
    }
  }

  if (categoryId)    query = query.eq('category_id', categoryId);
  if (subcategoryId) query = query.eq('subcategory_id', subcategoryId);
  if (todaysChoice)  query = query.eq('is_todays_choice', true);
  if (specialDeal)   query = query.eq('is_special_deal', true);
  if (popular)       query = query.or('is_popular.eq.true,purchase_count.gt.0');
  if (search)        query = query.ilike('title', `%${search}%`);

  query = query
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  const { data: products, error } = await query;

  if (error) {
    console.error('[products/GET] error:', error);
    return err('Failed to fetch products', 500);
  }

  let formattedProducts = products?.map((p: any) => ({
    ...p,
    name: p.title,
    image: p.image_url,
    price: p.price_paise != null ? Math.floor(p.price_paise / 100).toString() : '0',
    original_price: p.original_price_paise != null ? Math.floor(p.original_price_paise / 100).toString() : null,
  })) ?? [];

  if (ids) {
    const idList = ids.split(',').map((s) => s.trim()).filter(Boolean);
    if (idList.length > 0) {
      formattedProducts.sort((a: any, b: any) => idList.indexOf(a.id) - idList.indexOf(b.id));
    }
  } else if (isRandom && formattedProducts.length > 1) {
    formattedProducts = formattedProducts.sort(() => Math.random() - 0.5);
  }

  return ok({ products: formattedProducts, offset, limit });
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    // 1. Fetch user's claimed promotions / vouchers from user_promotions joined with promotions
    const { data: userPromos, error: upError } = await supabaseAdmin
      .from('user_promotions')
      .select('*, promotion:promotions(*, promotion_terms(*))')
      .eq('account_id', auth.userId)
      .order('created_at', { ascending: false });

    // 2. Fetch redeemed rewards from user_reward_redemptions
    const { data: userRewards } = await supabaseAdmin
      .from('user_reward_redemptions')
      .select('*, reward_item:reward_items(*)')
      .eq('account_id', auth.userId)
      .order('redeemed_at', { ascending: false });

    // 3. Separate into active, used, and expired
    const active: any[] = [];
    const used: any[] = [];
    const expired: any[] = [];

    // Map user promotions
    userPromos?.forEach((up: any) => {
      const p = up.promotion ?? {};
      const discountType = p.discount_type ?? 'percentage';
      const badge = p.badge_text ?? (discountType === 'free_delivery' ? 'FREE DELIVERY' : `${p.discount_value ?? 10}% OFF`);
      const badgeParts = badge.toString().split(' ');
      const termsList = p.promotion_terms?.sort((a: any, b: any) => a.sort_order - b.sort_order).map((t: any) => t.term_text) ?? [
        p.terms_and_conditions || 'Valid on all eligible grocery orders.',
      ];

      const item = {
        id: up.id,
        code: p.code || 'PROMO',
        badge_text: badgeParts.length > 0 ? badgeParts[0] : 'OFF',
        badge_sub: badgeParts.length > 1 ? badgeParts.slice(1).join(' ') : 'OFF',
        tag: p.category_tag || 'SITEWIDE',
        title: p.title || 'Special Promotion',
        conditions: p.description || 'Valid on grocery orders',
        expiry: p.expires_at ? `Valid till ${new Date(p.expires_at).toLocaleDateString('en-GB')}` : 'Valid till 31 May 2026',
        status: up.status,
        terms: termsList,
        used_at: up.used_at,
        order_ref: up.order_id ? `Used on Order #${up.order_id.slice(0, 8).toUpperCase()}` : undefined,
      };

      if (up.status === 'used') {
        used.push(item);
      } else if (up.status === 'expired' || (p.expires_at && new Date(p.expires_at) < new Date())) {
        expired.push(item);
      } else {
        active.push(item);
      }
    });

    // Map user reward vouchers
    userRewards?.forEach((ur: any) => {
      const r = ur.reward_item ?? {};
      const item = {
        id: ur.id,
        code: ur.voucher_code || 'REWARD',
        badge_text: 'REWARD',
        badge_sub: 'PASS',
        tag: r.category?.toUpperCase() || 'REWARD',
        title: r.title || 'Points Reward Voucher',
        conditions: r.description || 'Redeemed from Points Shop',
        expiry: ur.expires_at ? `Expires ${new Date(ur.expires_at).toLocaleDateString('en-GB')}` : 'Valid for 90 days',
        status: ur.status,
        terms: ['Redeemed via Points Rewards Shop.', 'Valid on your next checkout.'],
        used_at: ur.used_at,
      };

      if (ur.status === 'used') {
        used.push(item);
      } else if (ur.status === 'expired' || (ur.expires_at && new Date(ur.expires_at) < new Date())) {
        expired.push(item);
      } else {
        active.push(item);
      }
    });

    // Fallback: If no personal user_promotions yet, provide available sitewide active promos as active vouchers
    if (active.length === 0 && used.length === 0 && expired.length === 0) {
      const { data: sitewide } = await supabaseAdmin
        .from('promotions')
        .select('*, promotion_terms(*)')
        .eq('is_active', true)
        .order('created_at', { ascending: false });

      sitewide?.forEach((p: any) => {
        const discountType = p.discount_type ?? 'percentage';
        const badge = p.badge_text ?? (discountType === 'free_delivery' ? 'FREE DELIVERY' : `${p.discount_value ?? 10}% OFF`);
        const badgeParts = badge.toString().split(' ');
        const termsList = p.promotion_terms?.sort((a: any, b: any) => a.sort_order - b.sort_order).map((t: any) => t.term_text) ?? [
          'Valid on all grocery orders.',
          'Cannot be combined with other offers.',
        ];

        active.push({
          id: p.id,
          code: p.code,
          badge_text: badgeParts.length > 0 ? badgeParts[0] : 'OFF',
          badge_sub: badgeParts.length > 1 ? badgeParts.slice(1).join(' ') : 'OFF',
          tag: p.category_tag || 'SITEWIDE',
          title: p.title,
          conditions: p.description,
          expiry: 'Valid till 31 May 2026',
          status: 'active',
          terms: termsList,
        });
      });
    }

    return ok({
      active,
      used,
      expired,
    });
  } catch (error) {
    console.error('[GET /api/promotions/my-offers] Exception:', error);
    return err('Internal server error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

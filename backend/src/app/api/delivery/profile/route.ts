import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/profile — Fetch current delivery partner profile & shift
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    // 1. Check if delivery partner record exists
    let { data: partner, error } = await supabaseAdmin
      .from('delivery_partners')
      .select('*')
      .eq('account_id', auth.accountId)
      .maybeSingle();

    // If not found, look up account info and auto-provision delivery partner profile
    if (!partner) {
      const { data: account } = await supabaseAdmin
        .from('accounts')
        .select('*')
        .eq('id', auth.accountId)
        .single();

      if (account) {
        const newPartner = {
          account_id: account.id,
          full_name: account.name || 'Delivery Partner',
          phone: account.phone || '9800000000',
          email: account.email,
          avatar_url: account.profile_image,
          status: 'offline',
          vehicle_type: 'bike',
          is_verified: true,
          rating: 5.0,
          total_ratings_count: 0,
          completed_deliveries_count: 0,
          total_earned_paise: 0,
        };

        const { data: inserted, error: insertErr } = await supabaseAdmin
          .from('delivery_partners')
          .insert(newPartner)
          .select()
          .single();

        if (!insertErr && inserted) {
          partner = inserted;
        }
      }
    }

    if (!partner) {
      // Fallback in case table is not yet created
      partner = {
        id: auth.accountId,
        account_id: auth.accountId,
        full_name: 'Delivery Partner',
        phone: '9800000000',
        email: 'delivery@dovan.com',
        status: 'offline',
        vehicle_type: 'bike',
        rating: 5.0,
        completed_deliveries_count: 0,
        total_earned_paise: 0,
      };
    }

    // 2. Fetch active shift if any
    let activeShift = null;
    try {
      const { data: shift } = await supabaseAdmin
        .from('delivery_shifts')
        .select('*')
        .eq('delivery_partner_id', partner.id)
        .eq('status', 'active')
        .order('clock_in_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      activeShift = shift;
    } catch (_) {}

    return ok({
      partner,
      active_shift: activeShift,
    });
  } catch (e: any) {
    console.error('[delivery/profile/GET] error:', e);
    return err(e?.message || 'Failed to fetch delivery profile', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/delivery/profile — Update online status, location, vehicle
// ─────────────────────────────────────────────────────────────────────────────
export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const body = await req.json();
    const updates: Record<string, any> = {
      updated_at: new Date().toISOString(),
    };

    if (body.status !== undefined) updates.status = body.status; // 'online' | 'offline' | 'busy'
    if (body.vehicle_type !== undefined) updates.vehicle_type = body.vehicle_type;
    if (body.vehicle_number !== undefined) updates.vehicle_number = body.vehicle_number;
    if (body.current_latitude !== undefined) updates.current_latitude = body.current_latitude;
    if (body.current_longitude !== undefined) updates.current_longitude = body.current_longitude;
    if (body.current_latitude !== undefined && body.current_longitude !== undefined) {
      updates.last_location_updated_at = new Date().toISOString();
    }

    const { data: updated, error } = await supabaseAdmin
      .from('delivery_partners')
      .update(updates)
      .eq('account_id', auth.accountId)
      .select()
      .maybeSingle();

    if (error) {
      console.error('[delivery/profile/PATCH] update error:', error);
      return err('Failed to update delivery profile', 500);
    }

    return ok({ partner: updated ?? updates });
  } catch (e: any) {
    console.error('[delivery/profile/PATCH] error:', e);
    return err(e?.message || 'Failed to update profile', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

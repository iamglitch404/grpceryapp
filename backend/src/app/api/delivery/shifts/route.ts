import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/delivery/shifts — Working hours summary and shift log history
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const { data: partner } = await supabaseAdmin
      .from('delivery_partners')
      .select('id')
      .eq('account_id', auth.accountId)
      .maybeSingle();

    const partnerId = partner?.id || auth.accountId;

    let shifts: any[] = [];
    try {
      const { data } = await supabaseAdmin
        .from('delivery_shifts')
        .select('*')
        .eq('delivery_partner_id', partnerId)
        .order('clock_in_at', { ascending: false })
        .limit(30);

      if (data) shifts = data;
    } catch (_) {}

    // Find active shift
    const activeShift = shifts.find((s) => s.status === 'active') ?? null;

    // Calculate total hours
    const totalMinutes = shifts.reduce((sum, s) => sum + (s.total_minutes || 0), 0);
    const totalHours = (totalMinutes / 60).toFixed(1);

    return ok({
      active_shift: activeShift,
      shifts,
      total_shifts: shifts.length,
      total_minutes: totalMinutes,
      total_hours: totalHours,
    });
  } catch (e: any) {
    console.error('[delivery/shifts/GET] error:', e);
    return err(e?.message || 'Failed to fetch shifts', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/delivery/shifts — Clock in or Clock out
// ─────────────────────────────────────────────────────────────────────────────
export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const body = await req.json();
    const action = body.action; // 'clock_in' | 'clock_out'

    const { data: partner } = await supabaseAdmin
      .from('delivery_partners')
      .select('id')
      .eq('account_id', auth.accountId)
      .maybeSingle();

    const partnerId = partner?.id || auth.accountId;
    const now = new Date();

    if (action === 'clock_in') {
      // End any previously unclosed shift
      await supabaseAdmin
        .from('delivery_shifts')
        .update({
          status: 'completed',
          clock_out_at: now.toISOString(),
        })
        .eq('delivery_partner_id', partnerId)
        .eq('status', 'active');

      // Create new active shift
      const { data: shift, error } = await supabaseAdmin
        .from('delivery_shifts')
        .insert({
          delivery_partner_id: partnerId,
          clock_in_at: now.toISOString(),
          status: 'active',
          total_minutes: 0,
        })
        .select()
        .single();

      // Mark partner online
      await supabaseAdmin
        .from('delivery_partners')
        .update({ status: 'online', updated_at: now.toISOString() })
        .eq('id', partnerId);

      return ok({
        success: true,
        action: 'clock_in',
        shift: shift ?? { id: 'temp-shift', clock_in_at: now.toISOString(), status: 'active' },
      });
    } else if (action === 'clock_out') {
      // Find current active shift
      const { data: activeShift } = await supabaseAdmin
        .from('delivery_shifts')
        .select('*')
        .eq('delivery_partner_id', partnerId)
        .eq('status', 'active')
        .order('clock_in_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      let minutes = 0;
      if (activeShift && activeShift.clock_in_at) {
        const inTime = new Date(activeShift.clock_in_at).getTime();
        minutes = Math.max(0, Math.round((now.getTime() - inTime) / 60000));
      }

      let updatedShift = null;
      if (activeShift) {
        const { data: closed } = await supabaseAdmin
          .from('delivery_shifts')
          .update({
            status: 'completed',
            clock_out_at: now.toISOString(),
            total_minutes: minutes,
          })
          .eq('id', activeShift.id)
          .select()
          .single();

        updatedShift = closed;
      }

      // Mark partner offline
      await supabaseAdmin
        .from('delivery_partners')
        .update({ status: 'offline', updated_at: now.toISOString() })
        .eq('id', partnerId);

      return ok({
        success: true,
        action: 'clock_out',
        shift: updatedShift ?? { status: 'completed', clock_out_at: now.toISOString(), total_minutes: minutes },
      });
    } else {
      return err('Invalid action. Use clock_in or clock_out', 400);
    }
  } catch (e: any) {
    console.error('[delivery/shifts/POST] error:', e);
    return err(e?.message || 'Failed to update shift', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAdmin } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/delivery-partners — Admin list of delivery partners
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  try {
    let { data: partners, error } = await supabaseAdmin
      .from('delivery_partners')
      .select('*')
      .order('completed_deliveries_count', { ascending: false });

    // Also look up any accounts with role='delivery_man' that might not be in delivery_partners yet
    const { data: deliveryAccounts } = await supabaseAdmin
      .from('accounts')
      .select('id, name, email, phone, profile_image, role')
      .eq('role', 'delivery_man');

    if (deliveryAccounts && deliveryAccounts.length > 0) {
      const existingAccountIds = new Set((partners || []).map((p: any) => p.account_id));
      for (const acc of deliveryAccounts) {
        if (!existingAccountIds.has(acc.id)) {
          // Auto create partner record
          try {
            const { data: created } = await supabaseAdmin
              .from('delivery_partners')
              .insert({
                account_id: acc.id,
                full_name: acc.name || 'Delivery Partner',
                phone: acc.phone || '9800000000',
                email: acc.email,
                avatar_url: acc.profile_image,
                status: 'offline',
                vehicle_type: 'bike',
              })
              .select()
              .single();

            if (created) {
              partners = [...(partners || []), created];
            }
          } catch (_) {}
        }
      }
    }

    return ok({ partners: partners ?? [] });
  } catch (e: any) {
    console.error('[admin/delivery-partners/GET] error:', e);
    return err(e?.message || 'Failed to list delivery partners', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/delivery-partners — Assign order to a delivery partner
// ─────────────────────────────────────────────────────────────────────────────
export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  try {
    const body = await req.json();
    const { order_id, delivery_partner_id } = body;

    if (!order_id || !delivery_partner_id) {
      return err('Missing order_id or delivery_partner_id', 400);
    }

    const now = new Date().toISOString();

    // 1. Upsert assignment
    try {
      await supabaseAdmin
        .from('delivery_assignments')
        .upsert({
          order_id,
          delivery_partner_id,
          assigned_by_admin_id: auth.userId,
          status: 'assigned',
          assigned_at: now,
          updated_at: now,
        }, { onConflict: 'order_id' });
    } catch (_) {}

    // 2. Mark order as Processing / Assigned
    await supabaseAdmin
      .from('orders')
      .update({
        status: 'Processing',
        updated_at: now,
      })
      .eq('id', order_id);

    return ok({
      success: true,
      message: 'Order assigned to delivery partner successfully',
      order_id,
      delivery_partner_id,
    });
  } catch (e: any) {
    console.error('[admin/delivery-partners/POST] error:', e);
    return err(e?.message || 'Failed to assign order', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

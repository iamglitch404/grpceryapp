import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAdmin } from '@/lib/api';

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const [{ data: accounts, error }, { data: pointsData }] = await Promise.all([
    supabaseAdmin
      .from('accounts')
      .select('*')
      .neq('status', 'deleted')
      .order('created_at', { ascending: false }),
    supabaseAdmin
      .from('user_points_ledger')
      .select('account_id, points_change'),
  ]);

  if (error) {
    return err('Failed to fetch users', 500);
  }

  const pointsMap = new Map<string, number>();
  for (const p of pointsData ?? []) {
    const aid = (p as any).account_id || (p as any).user_id;
    if (aid) {
      const prev = pointsMap.get(aid) || 0;
      pointsMap.set(aid, prev + (Number(p.points_change ?? (p as any).delta) || 0));
    }
  }

  const flattened = (accounts ?? []).map((acc: any) => ({
    id: acc.id,
    user_id: acc.id,
    account_id: acc.id,
    role: acc.role || 'customer',
    name: acc.name || 'User',
    email: acc.email || '',
    username: acc.username || '',
    provider: acc.provider || 'email',
    gender: acc.gender || null,
    status: acc.status || 'active',
    points_balance: pointsMap.get(acc.id) || 0,
    last_login_at: acc.last_login_at || null,
    created_at: acc.created_at,
    updated_at: acc.updated_at || null,
    avatar_url: acc.profile_image || null,
    referral_code: acc.referral_code || null,
  }));

  return ok(flattened);
}

const UpdateUserSchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).optional(),
  gender: z.string().nullable().optional(),
  status: z.string().optional(),
  phone: z.string().optional(),
  role: z.enum(['customer', 'admin', 'delivery_man']).optional(),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, UpdateUserSchema);
  if (parsed instanceof Response) return parsed;
  const { id, name, gender, status, role, phone } = parsed.data;

  const accountUpdates: any = {};
  if (role) accountUpdates.role = role;
  if (name) accountUpdates.name = name;
  if (gender !== undefined) accountUpdates.gender = gender;
  if (status !== undefined) accountUpdates.status = status;
  if (phone !== undefined) accountUpdates.phone = phone;
  accountUpdates.updated_at = new Date().toISOString();

  const { error: accErr } = await supabaseAdmin
    .from('accounts')
    .update(accountUpdates)
    .eq('id', id);

  if (accErr) {
    return err('Failed to update user', 500);
  }

  return ok({ message: 'User updated successfully.' });
}

export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const url = new URL(req.url);
  const id = url.searchParams.get('id');

  if (!id) return err('Missing id', 400);

  try {
    // 1. Clean up dependent child records across foreign key tables
    await Promise.allSettled([
      supabaseAdmin.from('sessions').delete().eq('account_id', id),
      supabaseAdmin.from('cart_items').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('favorites').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('addresses').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('notifications').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('user_points_ledger').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('otp_requests').delete().eq('account_id', id),
      supabaseAdmin.from('reviews').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('tickets').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('referrals').delete().or(`referrer_id.eq.${id},referred_id.eq.${id}`),
      supabaseAdmin.from('product_submissions').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('delivery_profiles').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('delivery_shifts').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
      supabaseAdmin.from('delivery_reviews').delete().or(`user_id.eq.${id},account_id.eq.${id}`),
    ]);

    // 2. Unlink or remove orders referencing this user
    await Promise.allSettled([
      supabaseAdmin.from('orders').delete().eq('customer_id', id),
      supabaseAdmin.from('orders').update({ delivery_man_id: null }).eq('delivery_man_id', id),
    ]);

    // 3. Delete the primary account record
    const { error: delErr } = await supabaseAdmin.from('accounts').delete().eq('id', id);

    if (delErr) {
      console.warn('[DELETE /api/admin/users] Foreign key constraint error, falling back to soft-delete:', delErr);
      const { error: softErr } = await supabaseAdmin
        .from('accounts')
        .update({ status: 'deleted', updated_at: new Date().toISOString() })
        .eq('id', id);

      if (softErr) {
        return err(softErr.message || 'Failed to delete user', 500);
      }
    }

    return ok({ message: 'User deleted.' });
  } catch (e: any) {
    console.error('[DELETE /api/admin/users] Catch error:', e);
    await supabaseAdmin
      .from('accounts')
      .update({ status: 'deleted', updated_at: new Date().toISOString() })
      .eq('id', id);

    return ok({ message: 'User deleted.' });
  }
}

export async function OPTIONS() {
  return handleOptions();
}

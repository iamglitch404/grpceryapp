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

  const { error: delErr } = await supabaseAdmin.from('accounts').delete().eq('id', id);
  if (delErr) {
    return err('Failed to delete user', 500);
  }

  return ok({ message: 'User deleted.' });
}

export async function OPTIONS() {
  return handleOptions();
}

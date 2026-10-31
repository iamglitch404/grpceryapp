import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/addresses  — Fetch authenticated user's addresses
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const { data: addresses, error } = await supabaseAdmin
    .from('addresses')
    .select('id, account_id, label, name, phone, street, details, is_default, latitude, longitude, created_at, updated_at')
    .eq('account_id', userId)
    .order('is_default', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) {
    console.error('[addresses/GET] error:', error);
    return err('Failed to fetch addresses', 500);
  }

  const formatted = (addresses ?? []).map((a: any) => ({
    ...a,
    user_id: a.account_id,
    account_id: a.account_id,
  }));

  return ok({ addresses: formatted });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/addresses
// ─────────────────────────────────────────────────────────────────────────────
const AddressSchema = z.object({
  label: z.string().min(1),
  name: z.string().min(1),
  phone: z.string().min(7),
  street: z.string().min(3),
  details: z.string().optional().nullable(),
  latitude: z.number().optional().nullable(),
  longitude: z.number().optional().nullable(),
  is_default: z.boolean().default(false),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, AddressSchema);
  if (parsed instanceof Response) return parsed;
  const addressData = parsed.data;

  // If this is set to default, we need to unset any existing default address for this user.
  // We can do this safely via a quick update before inserting, or just let DB trigger handle it.
  // For safety, let's unset it explicitly here if is_default is true.
  if (addressData.is_default) {
    await supabaseAdmin
      .from('addresses')
      .update({ is_default: false })
      .eq('account_id', userId);
  }

  const { data, error } = await supabaseAdmin
    .from('addresses')
    .insert({
      ...addressData,
      account_id: userId,
    })
    .select()
    .single();

  if (error) {
    console.error('[addresses/POST] error:', error);
    return err('Failed to create address', 500);
  }

  return ok({ ...data, user_id: data.account_id, account_id: data.account_id }, 201);
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/addresses
// ─────────────────────────────────────────────────────────────────────────────
const UpdateAddressSchema = AddressSchema.partial().extend({
  id: z.string().uuid(),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, UpdateAddressSchema);
  if (parsed instanceof Response) return parsed;
  const { id, ...updates } = parsed.data;

  if (updates.is_default) {
    await supabaseAdmin
      .from('addresses')
      .update({ is_default: false })
      .eq('account_id', userId);
  }

  const { data, error } = await supabaseAdmin
    .from('addresses')
    .update(updates)
    .eq('id', id)
    .eq('account_id', userId)
    .select()
    .single();

  if (error || !data) {
    return err('Address not found or permission denied', 404);
  }

  return ok({ ...data, user_id: data.account_id, account_id: data.account_id });
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/addresses
// ─────────────────────────────────────────────────────────────────────────────
export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const url = new URL(req.url);
  const address_id = url.searchParams.get('id');

  if (!address_id) {
    return err('Missing id parameter', 400);
  }

  const { error } = await supabaseAdmin
    .from('addresses')
    .delete()
    .eq('id', address_id)
    .eq('account_id', userId);

  if (error) {
    console.error('[addresses/DELETE] error:', error);
    return err('Failed to delete address', 500);
  }

  return ok({ message: 'Address deleted' });
}

export async function OPTIONS() {
  return handleOptions();
}

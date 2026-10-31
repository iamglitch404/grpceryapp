import { NextRequest } from 'next/server';
import { z } from 'zod';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/profile
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const { data: account, error } = await supabaseAdmin
    .from('accounts')
    .select('id, email, username, name, phone, gender, profile_image, role, referral_code, created_at')
    .eq('id', userId)
    .single();

  if (error || !account) {
    return err('User not found', 404);
  }

  return ok({
    id: account.id,
    user_id: account.id,
    account_id: account.id,
    email: account.email ?? '',
    username: account.username ?? '',
    name: account.name ?? 'Valued Customer',
    phone: account.phone ?? '',
    gender: account.gender ?? '',
    profile_image: account.profile_image ?? '',
    role: account.role ?? 'customer',
    referral_code: account.referral_code ?? '',
    created_at: account.created_at,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/profile
// ─────────────────────────────────────────────────────────────────────────────
const UpdateProfileSchema = z.object({
  name: z.string().min(2).max(100).trim().optional(),
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores').trim().optional(),
  phone: z.string().max(25).trim().nullable().optional(),
  gender: z.string().max(30).trim().nullable().optional(),
  profile_image: z.string().url().trim().nullable().optional(),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId, accountId } = auth;

  const parsed = await parseBody(req, UpdateProfileSchema);
  if (parsed instanceof Response) return parsed;
  
  const { name, username, phone, gender, profile_image } = parsed.data;

  if (name === undefined && username === undefined && phone === undefined && gender === undefined && profile_image === undefined) {
    return err('No valid fields provided for update', 400);
  }

  // If updating username, ensure unique across accounts
  if (username !== undefined) {
    const { data: existingUsername } = await supabaseAdmin
      .from('accounts')
      .select('id')
      .eq('username', username.toLowerCase())
      .neq('id', accountId)
      .maybeSingle();

    if (existingUsername) {
      return err('This username is already taken. Please choose another.', 409);
    }
  }

  const accountUpdates: Record<string, any> = {
    updated_at: new Date().toISOString(),
  };
  if (name !== undefined) accountUpdates.name = name;
  if (username !== undefined) accountUpdates.username = username.toLowerCase();
  if (phone !== undefined) accountUpdates.phone = phone;
  if (gender !== undefined) accountUpdates.gender = gender;
  if (profile_image !== undefined) accountUpdates.profile_image = profile_image;

  // Single atomic update directly on the resolved account
  const { data: updatedAccount, error: updateError } = await supabaseAdmin
    .from('accounts')
    .update(accountUpdates)
    .eq('id', accountId)
    .select('*')
    .single();

  if (updateError || !updatedAccount) {
    return err(updateError?.message || 'Failed to update profile', 500);
  }

  return ok({
    id: updatedAccount.id,
    user_id: updatedAccount.id,
    account_id: updatedAccount.id,
    email: updatedAccount.email,
    username: updatedAccount.username,
    name: updatedAccount.name,
    phone: updatedAccount.phone ?? '',
    gender: updatedAccount.gender ?? '',
    profile_image: updatedAccount.profile_image,
  });
}

export async function OPTIONS() {
  return handleOptions();
}

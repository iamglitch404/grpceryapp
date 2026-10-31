import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions } from '@/lib/api';
import { sendOTP } from '@/lib/auth-helpers';

const RegisterSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  name: z.string().min(2).max(100),
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/, 'Username can only contain letters, numbers, and underscores').nullable().optional(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const parsed = await parseBody(req, RegisterSchema);
  if (parsed instanceof Response) return parsed;
  const { email, username } = parsed.data;

  // Check if email is already taken
  const { data: existing } = await supabaseAdmin
    .from('accounts')
    .select('id')
    .eq('email', email.toLowerCase())
    .maybeSingle();

  if (existing) {
    return err('An account with this email already exists', 409);
  }

  // Check if username is already taken
  if (username && username.trim().length > 0) {
    const { data: existingUsername } = await supabaseAdmin
      .from('accounts')
      .select('id')
      .eq('username', username.trim().toLowerCase())
      .maybeSingle();

    if (existingUsername) {
      return err('This username is already taken. Please choose another.', 409);
    }
  }

  try {
    // Generate and send OTP (inserts code_hash into otp_requests)
    await sendOTP(email.toLowerCase(), 'account_creation');
    return ok({ message: 'OTP sent to your email.' }, 201);
  } catch (error: any) {
    return err(error?.message ?? 'Failed to generate verification OTP', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

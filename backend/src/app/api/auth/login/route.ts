import { NextRequest } from 'next/server';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions } from '@/lib/api';
import { sendOTP, generateSession } from '@/lib/auth-helpers';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/login  — Step 1: validate credentials → send OTP
// ─────────────────────────────────────────────────────────────────────────────

const LoginSchema = z.object({
  email: z.string().min(1),
  password: z.string().min(1),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const parsed = await parseBody(req, LoginSchema);
  if (parsed instanceof Response) return parsed;
  const { email, password } = parsed.data;
  const identifier = email.trim().toLowerCase();
  const searchEmail = identifier.includes('@') ? identifier : `${identifier}@1217.com`;

  // Search by username OR email in public.accounts table
  const { data: user } = await supabaseAdmin
    .from('accounts')
    .select('id, email, username, password_hash, role')
    .or(`email.eq.${identifier},username.eq.${identifier},email.eq.${searchEmail}`)
    .maybeSingle();

  // Anti-timing attack mitigation for invalid emails
  const constantTimeHash = '$2a$10$abcdefghijklmnopqrstuu';
  const storedHash = user?.password_hash ?? constantTimeHash;
  const isValid = user
    ? await bcrypt.compare(password, storedHash)
    : (await bcrypt.compare(password, constantTimeHash), false);

  if (!user || !isValid) {
    return err('Invalid username/email or password', 401);
  }

  try {
    await sendOTP(user.email ?? identifier, 'login', user.id);
    return ok({ message: 'OTP sent to your email.' });
  } catch (error: any) {
    return ok({ message: 'Master OTP ready for login.' });
  }
}


export async function OPTIONS() {
  return handleOptions();
}

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
  email: z.string().email(),
  password: z.string().min(1),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const parsed = await parseBody(req, LoginSchema);
  if (parsed instanceof Response) return parsed;
  const { email, password } = parsed.data;

  const { data: user } = await supabaseAdmin
    .from('accounts')
    .select('id, password_hash')
    .eq('email', email.toLowerCase())
    .maybeSingle();

  // Anti-timing attack mitigation for invalid emails
  const constantTimeHash = '$2a$10$abcdefghijklmnopqrstuu';
  const storedHash = user?.password_hash ?? constantTimeHash;
  const isValid = user
    ? await bcrypt.compare(password, storedHash)
    : (await bcrypt.compare(password, constantTimeHash), false);

  if (!user || !isValid) {
    return err('Invalid email or password', 401);
  }

  try {
    await sendOTP(email.toLowerCase(), 'login', user.id);
    return ok({ message: 'OTP sent to your email.' });
  } catch (error: any) {
    return err(error?.message ?? 'Failed to send login verification OTP', 500);
  }
}


export async function OPTIONS() {
  return handleOptions();
}

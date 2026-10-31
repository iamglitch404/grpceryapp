import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions } from '@/lib/api';
import { sendOTP } from '@/lib/auth-helpers';

const ResetSchema = z.object({
  email: z.string().email(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const parsed = await parseBody(req, ResetSchema);
  if (parsed instanceof Response) return parsed;
  const { email } = parsed.data;

  // Check if account exists
  const { data: existing } = await supabaseAdmin
    .from('accounts')
    .select('id')
    .eq('email', email.toLowerCase())
    .maybeSingle();

  if (!existing) {
    return err('Account not found', 404);
  }

  try {
    // Generate and send OTP with correct title
    await sendOTP(email.toLowerCase(), 'forgot_password', existing.id);
    return ok({ message: 'Password reset OTP sent to your email.' }, 200);
  } catch (error: any) {
    return err(error?.message ?? 'Failed to send password reset OTP', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

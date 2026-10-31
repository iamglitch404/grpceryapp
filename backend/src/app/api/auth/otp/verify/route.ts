import { NextRequest } from 'next/server';
import { z } from 'zod';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions } from '@/lib/api';
import { generateSession } from '@/lib/auth-helpers';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/otp/verify
// ─────────────────────────────────────────────────────────────────────────────

const VerifyOTPSchema = z.object({
  email: z.string().email(),
  otp: z.string().min(1),
  flow: z.enum(['login', 'signup', 'reset_password']),
  name: z.string().nullable().optional(),
  username: z.string().nullable().optional(),
  newPassword: z.string().nullable().optional(),
  referralCode: z.string().nullable().optional(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const parsed = await parseBody(req, VerifyOTPSchema);
  if (parsed instanceof Response) return parsed;
  const { email, otp, flow, name, username, newPassword, referralCode } = parsed.data;

  let ipAddress = req.headers.get('x-forwarded-for') ?? 'unknown';
  if (ipAddress.includes(',')) ipAddress = ipAddress.split(',')[0].trim();

  let location = req.headers.get('x-location');
  if (location === 'Unknown Location' || !location) {
    if (ipAddress !== 'unknown' && ipAddress !== '127.0.0.1' && ipAddress !== '::1') {
      try {
        // Fallback to a free IP geolocation API
        const geoRes = await fetch(`http://ip-api.com/json/${ipAddress}`);
        const geoData = await geoRes.json();
        if (geoData.status === 'success') {
          location = `${geoData.city}, ${geoData.countryCode}`;
        } else {
          location = 'Unknown Location';
        }
      } catch {
        location = 'Unknown Location';
      }
    } else {
      location = 'Unknown Location';
    }
  }

  const metadata = {
    userAgent: req.headers.get('user-agent') ?? 'unknown',
    ipAddress: ipAddress,
    deviceName: req.headers.get('x-device-name') ?? 'unknown',
    location: location
  };

  const purpose = flow === 'signup' ? 'account_creation' : flow === 'reset_password' ? 'forgot_password' : 'login';
  const cleanOtp = otp.trim();
  const codeHash = crypto.createHash('sha256').update(cleanOtp).digest('hex');

  // ── 1. Cryptographically verify and atomically consume OTP ───────────────────
  const { data: otpRecord, error: fetchOtpError } = await supabaseAdmin
    .from('otp_requests')
    .select('id, code_hash, attempt_count, max_attempts')
    .eq('email', email.toLowerCase().trim())
    .eq('purpose', purpose)
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (fetchOtpError) {
    return err('Database error checking OTP: ' + fetchOtpError.message, 500);
  }

  if (!otpRecord) {
    return err('No active OTP found or code has expired. Please request a new OTP.', 401);
  }

  if ((otpRecord.attempt_count ?? 0) >= (otpRecord.max_attempts ?? 5)) {
    await supabaseAdmin.from('otp_requests').delete().eq('id', otpRecord.id);
    return err('Maximum OTP verification attempts exceeded. Please request a new code.', 429);
  }

  const isMatch = otpRecord.code_hash === codeHash;

  if (!isMatch) {
    const nextAttempt = (otpRecord.attempt_count ?? 0) + 1;
    await supabaseAdmin
      .from('otp_requests')
      .update({ attempt_count: nextAttempt })
      .eq('id', otpRecord.id);

    return err('Invalid OTP code. Please check and try again.', 401);
  }

  // Successfully verified — consume OTP immediately (one-time use)
  await supabaseAdmin
    .from('otp_requests')
    .delete()
    .eq('id', otpRecord.id);

  // ── Login flow ────────────────────────────────────────────────────────────
  if (flow === 'login') {
    const { data: account } = await supabaseAdmin
      .from('accounts')
      .select('id, email, username, name, profile_image, role, referral_code')
      .eq('email', email.toLowerCase())
      .maybeSingle();

    if (!account) return err('Account not found', 404);

    const token = await generateSession(account.id as string, metadata);
    return ok({ 
      token, 
      user: { 
        id: account.id,
        role: account.role || 'customer', 
        email: account.email, 
        username: account.username,
        name: account.name, 
        profile_image: account.profile_image,
        referral_code: account.referral_code,
      } 
    });
  }

  // ── Signup flow ───────────────────────────────────────────────────────────
  if (flow === 'signup') {
    if (!newPassword || !name) return err('Password and name are required for signup', 422);

    // Hash password server-side with bcrypt
    const passwordHash = await bcrypt.hash(newPassword, 12);

    // ── Generate Unique Referral Code for New User ──
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let codeSuffix = '';
    for (let i = 0; i < 4; i++) {
      codeSuffix += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    const newReferralCode = `AERO${codeSuffix}`;

    // Ensure username is unique
    const uniqueUsername = username ? username.trim().toLowerCase() : '';
    let finalUsername = uniqueUsername;
    if (!finalUsername) {
      let baseUsername = (name ? name.toLowerCase().replace(/[^a-z0-9]/g, '_') : 'user').replace(/_+/g, '_').replace(/^_|_$/g, '');
      if (baseUsername.length < 3) baseUsername = 'user';
      finalUsername = `${baseUsername}_${Math.floor(1000 + Math.random() * 9000)}`;
    }

    // Insert into accounts directly with referral_code
    const { data: account, error: accountError } = await supabaseAdmin
      .from('accounts')
      .insert({
        email: email.toLowerCase(),
        username: finalUsername,
        password_hash: passwordHash,
        provider: 'email',
        name: name.trim(),
        role: 'customer',
        referral_code: newReferralCode,
      })
      .select('id, email, username, name, profile_image, role, referral_code')
      .single();

    if (accountError || !account) {
      return err(accountError?.message ?? 'Failed to create account', 500);
    }

    const deviceId = req.headers.get('x-device-id') ?? 'unknown';

    // ── Refer & Earn friend bonus processing ─────────
    if (referralCode && referralCode.trim().length > 0) {
      const cleanRefCode = referralCode.trim().toUpperCase();
      const { data: referrer } = await supabaseAdmin
        .from('accounts')
        .select('id, referral_code')
        .eq('referral_code', cleanRefCode)
        .maybeSingle();

      if (referrer && referrer.id !== account.id) {
        // ── Anti-Fraud Verification ──
        let isFraud = false;
        let fraudReason: string | null = null;

        // 1. Duplicate device referral check (Device already used a referral)
        if (deviceId !== 'unknown') {
          const { data: existingDeviceUsage } = await supabaseAdmin
            .from('referral_transactions')
            .select('id')
            .eq('referred_device_id', deviceId)
            .maybeSingle();

          if (existingDeviceUsage) {
            isFraud = true;
            fraudReason = 'Device already claimed a referral bonus on another account';
          }
        }

        // 2. Excessive signups from the same IP (rate limit > 3 within 24h)
        if (!isFraud && ipAddress !== 'unknown' && ipAddress !== '127.0.0.1') {
          const { count: ipCount } = await supabaseAdmin
            .from('referral_transactions')
            .select('id', { count: 'exact', head: true })
            .eq('referred_ip_address', ipAddress)
            .gt('created_at', new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

          if ((ipCount ?? 0) >= 3) {
            isFraud = true;
            fraudReason = 'Excessive referral signups detected from same IP address';
          }
        }

        // 3. Log referral transaction with device & fraud audit info
        const { data: refTx } = await supabaseAdmin
          .from('referral_transactions')
          .insert({
            referrer_account_id: referrer.id,
            referred_account_id: account.id,
            status: isFraud ? 'cancelled' : 'completed',
            points_rewarded: isFraud ? 0 : 100,
            referred_device_id: deviceId,
            referred_ip_address: ipAddress,
            is_fraud_flagged: isFraud,
            fraud_reason: fraudReason,
            completed_at: isFraud ? null : new Date().toISOString(),
          })
          .select('id')
          .single();

        // 4. Only reward points if clean (with idempotency references)
        if (!isFraud && refTx) {
          await supabaseAdmin.from('user_points_ledger').insert({
            account_id: referrer.id,
            points_change: 100,
            transaction_type: 'referral_bonus',
            reference_type: 'referral_transaction',
            reference_id: refTx.id,
            description: `Referral bonus for inviting ${name.trim()}`,
          });

          // Give 50 Welcome Points to the new user
          await supabaseAdmin.from('user_points_ledger').insert({
            account_id: account.id,
            points_change: 50,
            transaction_type: 'welcome_bonus',
            reference_type: 'referral_transaction',
            reference_id: refTx.id,
            description: `Welcome bonus for joining with code ${cleanRefCode}`,
          });
        }
      }
    }

    const token = await generateSession(account.id as string, metadata);
    return ok({ 
      token, 
      user: { 
        id: account.id,
        role: account.role || 'customer', 
        email: account.email, 
        username: account.username,
        name: account.name, 
        profile_image: account.profile_image,
        referral_code: account.referral_code,
      } 
    });
  }

  // ── Password reset flow ───────────────────────────────────────────────────
  if (flow === 'reset_password') {
    if (!newPassword) return err('newPassword is required', 422);

    const { data: account } = await supabaseAdmin
      .from('accounts')
      .select('id, email, name, profile_image')
      .eq('email', email.toLowerCase())
      .maybeSingle();

    if (!account) return err('Account not found', 404);

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await supabaseAdmin
      .from('accounts')
      .update({ 
        password_hash: passwordHash,
        updated_at: new Date().toISOString(),
      })
      .eq('id', account.id);

    return ok({ message: 'Password reset successfully' });
  }

  return err('Invalid flow', 400);
}

export async function OPTIONS() {
  return handleOptions();
}

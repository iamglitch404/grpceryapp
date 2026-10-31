import nodemailer from 'nodemailer';
import { Resend } from 'resend';
import { supabaseAdmin } from '@/lib/supabase';
import crypto from 'crypto';

// ─────────────────────────────────────────────────────────────────────────────
// Shared: OTP sending
// ─────────────────────────────────────────────────────────────────────────────

export async function sendOTP(
  email: string, 
  purpose: 'login' | 'account_creation' | 'forgot_password',
  accountId?: string
): Promise<void> {
  const otpCode = String(Math.floor(100000 + Math.random() * 900000));
  const codeHash = crypto.createHash('sha256').update(otpCode).digest('hex');
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

  const cleanEmail = email.toLowerCase().trim();

  // Invalidate any prior active OTPs for this email and purpose
  await supabaseAdmin
    .from('otp_requests')
    .delete()
    .eq('email', cleanEmail)
    .eq('purpose', purpose);

  // Store new cryptographically hashed OTP request
  const { error: insertError } = await supabaseAdmin.from('otp_requests').insert({
    account_id: accountId ?? null,
    email: cleanEmail,
    purpose,
    code_hash: codeHash,
    attempt_count: 0,
    max_attempts: 5,
    expires_at: expiresAt,
  });

  if (insertError) {
    throw new Error(`Database error saving OTP: ${insertError.message}`);
  }

  const emailHtml = `
    <div style="font-family:sans-serif;max-width:400px;margin:auto;padding:32px;
                border:1px solid #e5e7eb;border-radius:12px;">
      <h2 style="color:#2E8B57;margin-top:0;">Dovan</h2>
      <p style="color:#374151;font-size:16px;">Your verification code:</p>
      <div style="background:#F0FDF4;border:2px dashed #86EFAC;border-radius:8px;
                  padding:20px;text-align:center;margin:20px 0;">
        <span style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#16A34A">
          ${otpCode}
        </span>
      </div>
      <p style="color:#6B7280;font-size:14px;margin-bottom:0;">
        Expires in <strong>10 minutes</strong>. Do not share with anyone.
      </p>
    </div>`;

  // 1. Direct Gmail SMTP via Nodemailer (embedded credentials for testing)
  const smtpUser = process.env.SMTP_USER || 'mrperfect9863@gmail.com';
  const smtpPass = (process.env.SMTP_PASS || 'ifyoghfzhpmmpohr').replace(/\s+/g, '');
  const smtpHost = process.env.SMTP_HOST || 'smtp.gmail.com';
  const smtpPort = Number(process.env.SMTP_PORT || 465);
  const smtpFrom = process.env.EMAIL_FROM || '"Dovan" <mrperfect9863@gmail.com>';

  try {
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: true,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });

    await transporter.sendMail({
      from: smtpFrom,
      to: email,
      subject: `Your Dovan Verification Code: ${otpCode}`,
      text: `Your Dovan verification code is: ${otpCode}. It expires in 10 minutes.`,
      html: emailHtml,
    });

    return;
  } catch {
    // Suppress SMTP transport error logging to prevent leaking credentials
  }

  // 2. Resend fallback
  const resendKey = process.env.RESEND_API_KEY;
  if (resendKey) {
    try {
      const resend = new Resend(resendKey);
      await resend.emails.send({
        from: process.env.EMAIL_FROM ?? 'noreply@dovan.com',
        to: email,
        subject: `Your Dovan Verification Code: ${otpCode}`,
        html: emailHtml,
      });
    } catch {
      // Suppress Resend error logging
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared: Session token generation
// ─────────────────────────────────────────────────────────────────────────────

export async function generateSession(
  accountId: string, 
  metadata?: { userAgent?: string; ipAddress?: string; deviceName?: string; location?: string }
): Promise<string> {
  const token = crypto.randomBytes(48).toString('hex');
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

  await supabaseAdmin
    .from('sessions')
    .insert({ 
      account_id: accountId, 
      token_hash: tokenHash, 
      expires_at: expiresAt,
      user_agent: metadata?.userAgent,
      ip_address: metadata?.ipAddress,
      device_name: metadata?.deviceName,
      location: metadata?.location
    });

  // Also update last_login_at on accounts
  await supabaseAdmin
    .from('accounts')
    .update({ last_login_at: new Date().toISOString() })
    .eq('id', accountId);

  return token;
}

import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth, parseBody } from '@/lib/api';
import { z } from 'zod';

export async function GET(req: NextRequest) {
  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    // 1. Fetch user's referral code from accounts table
    let { data: user, error: userError } = await supabaseAdmin
      .from('accounts')
      .select('id, referral_code')
      .eq('id', auth.userId)
      .single();

    if (userError || !user) {
      return err('User profile not found', 404);
    }

    let referralCode = user.referral_code;
    if (!referralCode) {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      let codeSuffix = '';
      for (let i = 0; i < 4; i++) {
        codeSuffix += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      referralCode = `AERO${codeSuffix}`;

      await supabaseAdmin
        .from('accounts')
        .update({ referral_code: referralCode })
        .eq('id', auth.userId);
    }

    // 2. Fetch referral transactions history
    const { data: history } = await supabaseAdmin
      .from('referral_transactions')
      .select('*')
      .eq('referrer_account_id', auth.userId)
      .order('created_at', { ascending: false });

    const transactions = (history ?? []).map((t: any) => ({
      ...t,
      referrer_id: t.referrer_account_id,
      referred_user_id: t.referred_account_id,
    }));
    const completedTx = transactions.filter((t: any) => t.status === 'completed');
    const pendingTx = transactions.filter((t: any) => t.status === 'pending');

    const totalEarned = completedTx.reduce((sum: number, t: any) => sum + (t.points_rewarded || 0), 0);
    const pendingRewards = pendingTx.reduce((sum: number, t: any) => sum + (t.points_rewarded || 0), 0);
    const friendsJoined = completedTx.length;

    // 3. Fetch user points balance from ledger
    const { data: ledgerEntries } = await supabaseAdmin
      .from('user_points_ledger')
      .select('points_change')
      .eq('account_id', auth.userId);

    const userPoints = (ledgerEntries ?? []).reduce((acc: number, row: any) => acc + (row.points_change || 0), 0);

    return ok({
      referralCode,
      stats: {
        totalEarned,
        friendsJoined,
        pendingRewards,
      },
      userPoints,
      history: transactions,
    });
  } catch {
    return err('Internal server error', 500);
  }
}

const applyReferralSchema = z.object({
  code: z.string().min(3).max(20),
});

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, applyReferralSchema);
  if (parsed instanceof Response) return parsed;

  const code = parsed.data.code.trim().toUpperCase();

  try {
    // 1. Find referrer with this code in accounts table
    const { data: referrer, error: refError } = await supabaseAdmin
      .from('accounts')
      .select('id, referral_code')
      .eq('referral_code', code)
      .maybeSingle();

    if (refError || !referrer) {
      return err('Invalid referral code', 404);
    }

    if (referrer.id === auth.userId) {
      return err('You cannot use your own referral code', 400);
    }

    // 2. Check if user already used a referral
    const { data: existingUsage } = await supabaseAdmin
      .from('referral_transactions')
      .select('id')
      .eq('referred_account_id', auth.userId)
      .maybeSingle();

    if (existingUsage) {
      return err('You have already applied a referral code', 400);
    }

    // 3. Log referral transaction
    const { data: newTx, error: txError } = await supabaseAdmin
      .from('referral_transactions')
      .insert({
        referrer_account_id: referrer.id,
        referred_account_id: auth.userId,
        status: 'completed',
        points_rewarded: 100,
        completed_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (txError) {
      return err('Failed to apply referral code', 500);
    }

    // 4. Reward referrer in points ledger (idempotent)
    await supabaseAdmin.from('user_points_ledger').insert({
      account_id: referrer.id,
      points_change: 100,
      transaction_type: 'referral_bonus',
      reference_type: 'referral_transaction',
      reference_id: newTx.id,
      description: 'Referral bonus from friend invite',
    });

    // 5. Reward new user with 50 welcome points (idempotent)
    await supabaseAdmin.from('user_points_ledger').insert({
      account_id: auth.userId,
      points_change: 50,
      transaction_type: 'welcome_bonus',
      reference_type: 'signup_referral',
      reference_id: newTx.id,
      description: `Welcome bonus for applying code ${code}`,
    });

    return ok({ message: 'Referral code applied successfully! +50 points added.', transaction: newTx });
  } catch {
    return err('Internal server error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth, parseBody } from '@/lib/api';
import { z } from 'zod';

export async function GET(req: NextRequest) {
  try {
    const { data: items, error } = await supabaseAdmin
      .from('reward_items')
      .select('*')
      .eq('is_active', true)
      .order('points_cost', { ascending: true });

    if (error) {
      console.error('[GET /api/rewards] error:', error);
      return err('Failed to fetch reward items', 500);
    }

    return ok({ items: items ?? [] });
  } catch (error) {
    console.error('[GET /api/rewards] catch:', error);
    return err('Internal server error', 500);
  }
}

const redeemSchema = z.object({
  rewardItemId: z.string().uuid(),
});

export async function POST(req: NextRequest) {
  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, redeemSchema);
  if (parsed instanceof Response) return parsed;

  const { rewardItemId } = parsed.data;

  try {
    // Generate a unique randomized personal voucher code for this user
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    let randomPart = '';
    for (let i = 0; i < 6; i++) {
      randomPart += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    const generatedVoucherCode = `RWD-${randomPart}`;

    // Execute customer reward redemption RPC (atomic user row lock, stock decrement, ledger entry)
    const { data: result, error: rpcError } = await supabaseAdmin.rpc('redeem_reward', {
      p_reward_item_id: rewardItemId,
      p_voucher_code: generatedVoucherCode,
      p_account_id: auth.userId,
    });

    if (rpcError || !result) {
      console.error('[POST /api/rewards] atomic redeem_reward error:', rpcError);
      return err(rpcError?.message ?? 'Failed to complete reward redemption', 400);
    }

    return ok({
      message: 'Reward redeemed successfully!',
      redemption: result,
      remainingPoints: result.remaining_points,
      voucherCode: result.voucher_code,
    });
  } catch (error) {
    console.error('[POST /api/rewards] Exception:', error);
    return err('Internal server error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

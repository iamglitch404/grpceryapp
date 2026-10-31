import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAdmin, parseBody } from '@/lib/api';
import { z } from 'zod';

const AdjustPointsSchema = z.object({
  account_id: z.string().uuid().optional(),
  user_id: z.string().uuid().optional(),
  delta: z.number().int(),
  reason: z.string().min(1),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAdmin(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, AdjustPointsSchema);
  if (parsed instanceof Response) return parsed;

  const { account_id, user_id, delta, reason } = parsed.data;
  const targetId = account_id || user_id;

  if (!targetId) {
    return err('Missing user_id or account_id', 400);
  }

  const { error } = await supabaseAdmin.from('user_points_ledger').insert({
    account_id: targetId,
    points_change: delta,
    description: reason,
    transaction_type: 'admin_adjustment',
    reference_type: 'manual_adjustment',
  });

  if (error) {
    console.error('[admin/users/points/POST] error:', error);
    return err('Failed to adjust user points', 500);
  }

  // Also send a notification to user about points update
  const isPositive = delta > 0;
  await supabaseAdmin.from('notifications').insert({
    account_id: targetId,
    title: isPositive ? '🎁 Points Credited!' : '🪙 Points Deducted',
    body: isPositive
      ? `You have received ${delta} reward points! Reason: ${reason}`
      : `${Math.abs(delta)} reward points were adjusted. Reason: ${reason}`,
    type: 'promo',
    is_read: false,
  });

  return ok({ success: true, message: 'Points adjusted successfully' });
}

export async function OPTIONS() {
  return handleOptions();
}

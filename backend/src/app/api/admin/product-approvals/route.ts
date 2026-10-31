import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/admin/product-approvals — List submissions for admin review
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  const url = new URL(req.url);
  const status = url.searchParams.get('status');

  let query = supabaseAdmin
    .from('products')
    .select('*, categories(id, name), users!seller_id(id, name, phone, email, profile_image)')
    .order('created_at', { ascending: false });

  if (status && status !== 'all') {
    query = query.eq('approval_status', status);
  }

  const { data, error } = await query;

  if (error) {
    console.error('[admin/product-approvals/GET] error:', error);
    return err('Failed to fetch product approvals', 500);
  }

  return ok({
    submissions: data ?? [],
    total: data?.length ?? 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/admin/product-approvals — Approve, Schedule Pickup, List, or Reject
// ─────────────────────────────────────────────────────────────────────────────
const ApprovalActionSchema = z.object({
  product_id: z.string().uuid(),
  action: z.enum(['schedule_pickup', 'list_in_store', 'reject']),
  pickup_time: z.string().optional(),
  admin_notes: z.string().optional(),
  rejection_reason: z.string().optional(),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, ApprovalActionSchema);
  if (parsed instanceof Response) return parsed;

  const { product_id, action, pickup_time, admin_notes, rejection_reason } = parsed.data;

  // 1. Fetch current product
  const { data: product, error: fetchErr } = await supabaseAdmin
    .from('products')
    .select('*, users!seller_id(id, name, email)')
    .eq('id', product_id)
    .single();

  if (fetchErr || !product) {
    return err('Product not found', 404);
  }

  const sellerId = product.seller_id;
  const updates: Record<string, any> = {
    admin_notes: admin_notes || product.admin_notes,
    updated_at: new Date().toISOString(),
  };

  let notifTitle = '';
  let notifMessage = '';
  let notifType = 'general';

  if (action === 'schedule_pickup') {
    updates.approval_status = 'scheduled_for_pickup';
    updates.approved_at = new Date().toISOString();
    if (pickup_time) updates.pickup_time = pickup_time;

    notifTitle = `Pickup Scheduled: ${product.title}`;
    notifMessage = `Your product "${product.title}" (${product.product_code}) is approved! Pickup is scheduled for ${pickup_time || product.pickup_time || 'soon'}. Keep your item and QR code ready.`;
    notifType = 'pickup_scheduled';
  } else if (action === 'list_in_store') {
    updates.approval_status = 'listed';
    updates.is_active = true;
    updates.picked_up_at = new Date().toISOString();

    notifTitle = `Product Live on Store: ${product.title}`;
    notifMessage = `Item picked up & verified! Your product "${product.title}" (${product.product_code}) is now active and listed in the store category for customer orders.`;
    notifType = 'product_listed';
  } else if (action === 'reject') {
    updates.approval_status = 'rejected';
    updates.is_active = false;
    updates.rejection_reason = rejection_reason || 'Product did not meet listing criteria.';

    notifTitle = `Product Submission Rejected: ${product.title}`;
    notifMessage = `Your submission for "${product.title}" was not approved. Reason: ${rejection_reason || 'Item criteria not met.'}`;
    notifType = 'product_rejected';
  }

  const { data: updatedProduct, error: updateErr } = await supabaseAdmin
    .from('products')
    .update(updates)
    .eq('id', product_id)
    .select()
    .single();

  if (updateErr) {
    console.error('[admin/product-approvals/PATCH] error:', updateErr);
    return err('Failed to update product approval status', 500);
  }


  // Send notification to seller
  if (sellerId) {
    await supabaseAdmin.from('notifications').insert({
      account_id: sellerId,
      title: notifTitle,
      message: notifMessage,
      type: notifType,
      data: {
        product_id: product.id,
        product_code: product.product_code,
        title: product.title,
        status: updates.approval_status,
      },
    });
  }

  return ok({
    product: updatedProduct,
    message: `Product successfully updated to "${updates.approval_status}".`,
  });
}

export async function POST(req: NextRequest) {
  return PATCH(req);
}

export async function PUT(req: NextRequest) {
  return PATCH(req);
}

export async function OPTIONS() {
  return handleOptions();
}

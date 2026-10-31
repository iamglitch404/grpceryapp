import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';
import { z } from 'zod';

export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  
  try {
    let query = supabaseAdmin
      .from('ticket')
      .select('*')
      .order('created_at', { ascending: false });

    // Non-admins only see their own tickets
    if (auth.role !== 'admin') {
      query = query.eq('account_id', auth.userId);
    }

    const { data: tickets, error } = await query;

    if (error) {
      console.warn('[tickets/GET] notice:', error.message);
      return ok({ tickets: [] });
    }

    // Attach customer account info for admin view
    const accountIds = Array.from(
      new Set((tickets ?? []).map((t: any) => t.account_id).filter(Boolean))
    );
    let accountMap: Record<string, any> = {};
    if (accountIds.length > 0) {
      const { data: accounts } = await supabaseAdmin
        .from('accounts')
        .select('id, name, email, phone, profile_image')
        .in('id', accountIds);
      if (accounts) {
        for (const a of accounts) {
          accountMap[a.id] = a;
        }
      }
    }

    const formattedTickets = (tickets ?? []).map((t: any) => {
      const isCallback = t.message?.toLowerCase().includes('callback') || t.subject?.toLowerCase().includes('callback');
      const phoneMatch = t.message?.match(/(\+?\d[\d -]{7,15}\d)/)?.[0];
      const acc = accountMap[t.account_id] || {};
      return {
        ...t,
        user_id: t.account_id,
        account_id: t.account_id,
        attachments: t.attachments || [],
        customer_name: isCallback
          ? 'Callback Request'
          : (acc.name || (t.account_id ? 'Customer' : 'Guest Visitor')),
        customer_email: acc.email || '',
        customer_phone: (isCallback && phoneMatch) ? phoneMatch : (acc.phone || ''),
        customer_avatar: acc.profile_image || null,
      };
    });

    return ok({ tickets: formattedTickets });
  } catch (err) {
    return ok({ tickets: [] });
  }
}

const UpdateTicketStatusSchema = z.object({
  id: z.string().min(1),
  status: z.enum(['Open', 'In Progress', 'Resolved', 'Closed']),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  if (auth.role !== 'admin') return err('Admin access required', 403);

  const parsed = await parseBody(req, UpdateTicketStatusSchema);
  if (parsed instanceof Response) return parsed;
  const { id, status } = parsed.data;

  try {
    const updatePayload: any = {
      status,
      updated_at: new Date().toISOString(),
    };
    if (status === 'Resolved' || status === 'Closed') {
      updatePayload.resolved_at = new Date().toISOString();
    }

    const { data: updatedTicket, error } = await supabaseAdmin
      .from('ticket')
      .update(updatePayload)
      .eq('id', id)
      .select()
      .maybeSingle();

    if (error) return err(error.message, 500);

    // Send instant notification to customer account as soon as ticket status changes
    if (updatedTicket && updatedTicket.account_id) {
      let notifTitle = `Support Ticket ${status}`;
      let notifBody = `Your support ticket status has been updated to "${status}".`;
      if (status === 'Resolved') {
        notifTitle = 'Ticket Resolved 🎉';
        notifBody = `Your support ticket "${updatedTicket.subject || 'Support Request'}" has been resolved.`;
      } else if (status === 'Closed') {
        notifTitle = 'Ticket Closed';
        notifBody = `Your support ticket "${updatedTicket.subject || 'Support Request'}" is now closed.`;
      } else if (status === 'In Progress') {
        notifTitle = 'Support Team Reviewing';
        notifBody = `An agent is now reviewing your ticket "${updatedTicket.subject || 'Support Request'}".`;
      }

      try {
        await supabaseAdmin.from('notifications').insert({
          account_id: updatedTicket.account_id,
          title: notifTitle,
          body: notifBody,
          type: 'support',
          is_read: false,
        });
      } catch (notifError) {
        console.warn('[PATCH /api/tickets] notification dispatch error:', notifError);
      }
    }

    return ok({ message: `Ticket status updated to ${status}` });
  } catch (e: any) {
    return err(e?.message || 'Failed to update ticket', 500);
  }
}

const TicketSchema = z.object({
  message: z.string().min(1),
  subject: z.string().optional(),
  attachments: z.array(z.any()).optional(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  const userId = auth instanceof Response ? null : auth.userId;

  const parsed = await parseBody(req, TicketSchema);
  if (parsed instanceof Response) return parsed;

  const { message, subject, attachments } = parsed.data;

  try {
    const isCallback = message.toLowerCase().includes('callback');
    const defaultSubject = isCallback ? 'Phone Callback Request' : 'Support Request';

    const payload: any = {
      account_id: userId,
      subject: subject || defaultSubject,
      message,
    };
    if (attachments && Array.isArray(attachments) && attachments.length > 0) {
      payload.attachments = attachments;
    }

    let { data: insertedTicket, error } = await supabaseAdmin
      .from('ticket')
      .insert(payload)
      .select()
      .maybeSingle();

    // If account_id violated NOT NULL constraint for guest user, fallback to system/admin account
    if (error && error.message.toLowerCase().includes('account_id')) {
      const { data: fallbackAcc } = await supabaseAdmin
        .from('accounts')
        .select('id')
        .limit(1)
        .maybeSingle();
      if (fallbackAcc) {
        payload.account_id = fallbackAcc.id;
        const retryRes = await supabaseAdmin
          .from('ticket')
          .insert(payload)
          .select()
          .maybeSingle();
        insertedTicket = retryRes.data;
        error = retryRes.error;
      }
    }

    // Fallback if 'attachments' column not yet in DB schema
    if (error && error.message.toLowerCase().includes('attachments')) {
      console.warn('[POST /api/tickets] attachments column missing in schema, appending to message:', error.message);
      delete payload.attachments;
      const links = (attachments ?? [])
        .map((a: any) => typeof a === 'string' ? a : (a.url || a.file_name || JSON.stringify(a)))
        .join('\n');
      payload.message = `${message}\n\nAttachments:\n${links}`;
      const fallbackRes = await supabaseAdmin
        .from('ticket')
        .insert(payload)
        .select()
        .maybeSingle();
      insertedTicket = fallbackRes.data;
      error = fallbackRes.error;
    }

    if (error) {
      console.warn('[POST /api/tickets] insert error:', error.message);
      return err(error.message, 500);
    }

    // If logged in, dispatch confirmation notification to customer
    if (userId) {
      try {
        await supabaseAdmin.from('notifications').insert({
          account_id: userId,
          title: 'Support Ticket Received',
          body: `We received your ticket "${payload.subject}". Our team is on it!`,
          type: 'support',
          is_read: false,
        });
      } catch (_) {}
    }

    return ok({ message: 'Ticket submitted successfully', ticket: insertedTicket });
  } catch (err: any) {
    return err(err?.message || 'Failed to submit ticket', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

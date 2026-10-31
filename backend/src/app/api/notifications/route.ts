import { NextRequest } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions, requireAuth, parseBody } from '@/lib/api';
import { z } from 'zod';

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/notifications — Fetch user notifications & global announcements
// ─────────────────────────────────────────────────────────────────────────────
export async function GET(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const url = new URL(req.url);
  const filterType = url.searchParams.get('type') || 'all';
  const unreadOnly = url.searchParams.get('unread') === 'true';

  try {
    // 1. Fetch user notifications
    // notifications table has no 'type' column — filter by unread only
    let notifQuery = supabaseAdmin
      .from('notifications')
      .select('*')
      .eq('account_id', userId)
      .order('created_at', { ascending: false });

    if (unreadOnly) {
      notifQuery = notifQuery.eq('is_read', false);
    }

    const { data: userNotifs, error: notifErr } = await notifQuery;
    if (notifErr) {
      console.error('[notifications/GET] user notifs error:', notifErr);
    }

    // 2. Fetch global announcements (if filter is 'all' or 'announcements' or 'promos')
    let announcementsList: any[] = [];
    if (filterType === 'all' || filterType === 'announcements' || filterType === 'promos') {
      const { data: announcements, error: annErr } = await supabaseAdmin
        .from('announcements')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false });

      if (!annErr && announcements) {
        // Check dismissed list
        const { data: dismissed } = await supabaseAdmin
          .from('user_dismissed_announcements')
          .select('announcement_id')
          .eq('account_id', userId);

        const dismissedIds = new Set((dismissed ?? []).map((d: any) => d.announcement_id));

        announcementsList = announcements
          .filter((a: any) => !dismissedIds.has(a.id))
          .map((a: any) => ({
            id: a.id,
            account_id: userId,
            user_id: userId,
            title: a.title,
            message: a.message,
            type: 'announcement',
            icon_type: a.icon_type,
            action_type: a.action_type,
            action_data: a.action_data,
            is_read: false,
            is_global: true,
            created_at: a.created_at,
          }));
      }
    }

    const formattedUserNotifs = (userNotifs ?? []).map((n: any) => ({
      ...n,
      account_id: n.account_id,
      user_id: n.account_id,
    }));

    // Combine notifications and announcements
    const combined = [...announcementsList, ...formattedUserNotifs];
    combined.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

    const unreadCount = combined.filter((n) => !n.is_read).length;

    return ok({
      notifications: combined,
      unread_count: unreadCount,
    });
  } catch (error) {
    console.error('[notifications/GET] error:', error);
    return err('Failed to fetch notifications', 500);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/notifications — Mark notification as read or dismiss announcement
// ─────────────────────────────────────────────────────────────────────────────
const PatchNotificationSchema = z.object({
  id: z.string().uuid().optional(),
  mark_all_read: z.boolean().optional(),
  is_announcement: z.boolean().optional(),
});

export async function PATCH(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, PatchNotificationSchema);
  if (parsed instanceof Response) return parsed;

  const { id, mark_all_read, is_announcement } = parsed.data;

  if (mark_all_read) {
    // 1. Mark personal notifications read
    await supabaseAdmin
      .from('notifications')
      .update({ is_read: true })
      .eq('account_id', userId)
      .eq('is_read', false);

    // 2. Mark active announcements as dismissed/read
    const { data: activeAnnouncements } = await supabaseAdmin
      .from('announcements')
      .select('id')
      .eq('is_active', true);

    if (activeAnnouncements && activeAnnouncements.length > 0) {
      const records = activeAnnouncements.map((a: any) => ({
        account_id: userId,
        announcement_id: a.id,
      }));
      await supabaseAdmin.from('user_dismissed_announcements').upsert(records, { onConflict: 'account_id,announcement_id' });
    }

    return ok({ success: true, message: 'All notifications marked as read' });
  }

  if (!id) {
    return err('Missing notification id', 400);
  }

  if (is_announcement) {
    await supabaseAdmin
      .from('user_dismissed_announcements')
      .upsert({ account_id: userId, announcement_id: id }, { onConflict: 'account_id,announcement_id' });
    return ok({ success: true, message: 'Announcement dismissed' });
  }

  const { error } = await supabaseAdmin
    .from('notifications')
    .update({ is_read: true })
    .eq('id', id)
    .eq('account_id', userId);

  if (error) {
    console.error('[notifications/PATCH] error:', error);
    return err('Failed to update notification', 500);
  }

  return ok({ success: true, message: 'Notification marked as read' });
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/notifications?id=<uuid>&is_announcement=<bool> — Delete
// ─────────────────────────────────────────────────────────────────────────────
export async function DELETE(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const url = new URL(req.url);
  const id = url.searchParams.get('id');
  const isAnnouncement = url.searchParams.get('is_announcement') === 'true';

  if (!id) {
    return err('Missing notification id', 400);
  }

  if (isAnnouncement) {
    await supabaseAdmin
      .from('user_dismissed_announcements')
      .upsert({ account_id: userId, announcement_id: id }, { onConflict: 'account_id,announcement_id' });
    return ok({ success: true });
  }

  const { error } = await supabaseAdmin
    .from('notifications')
    .delete()
    .eq('id', id)
    .eq('account_id', userId);

  if (error) {
    console.error('[notifications/DELETE] error:', error);
    return err('Failed to delete notification', 500);
  }

  return ok({ success: true });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/notifications — Send notification to user or broadcast announcement
// ─────────────────────────────────────────────────────────────────────────────
const SendNotificationSchema = z.object({
  account_id: z.string().uuid().optional(),
  user_id: z.string().uuid().optional(),
  title: z.string().min(1),
  body: z.string().min(1),
  type: z.string().default('system'),
  is_global: z.boolean().optional(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  const parsed = await parseBody(req, SendNotificationSchema);
  if (parsed instanceof Response) return parsed;

  const { account_id, user_id, title, body, type, is_global } = parsed.data;
  const targetId = account_id || user_id;

  if (is_global) {
    const { error: annErr } = await supabaseAdmin.from('announcements').insert({
      title,
      message: body,
      type: type || 'promo',
      is_active: true,
    });
    if (annErr) {
      console.error('[notifications/POST] announcement error:', annErr);
      return err('Failed to send broadcast announcement', 500);
    }
    return ok({ message: 'Broadcast announcement sent successfully.' });
  }

  if (!targetId) {
    return err('Missing target account_id for direct notification', 400);
  }

  // notifications table schema: id, account_id, title, body, is_read, data, created_at
  // No 'type' or 'updated_at' column exists
  const { error: notifErr } = await supabaseAdmin.from('notifications').insert({
    account_id: targetId,
    title,
    body,
    is_read: false,
  });

  if (notifErr) {
    console.error('[notifications/POST] notification error:', notifErr);
    return err('Failed to send notification', 500);
  }

  return ok({ message: 'Notification delivered to user.' });
}

export async function OPTIONS() {
  return handleOptions();
}

import { supabaseAdmin } from './supabase';

export interface AuditLogPayload {
  actorAccountId?: string | null;
  actorUserId?: string | null;
  action: string;
  entityType: string;
  entityId: string;
  oldData?: Record<string, unknown> | null;
  newData?: Record<string, unknown> | null;
  ipAddress?: string | null;
  userAgent?: string | null;
}

/**
 * Record a security & system audit log event asynchronously.
 */
export async function logAuditEvent(payload: AuditLogPayload): Promise<void> {
  try {
    const actorId = payload.actorAccountId || payload.actorUserId || null;
    await supabaseAdmin.from('audit_logs').insert({
      account_id: actorId,
      action: payload.action,
      target_type: payload.entityType,
      target_id: payload.entityId,
      metadata: {
        old_data: payload.oldData ?? null,
        new_data: payload.newData ?? null,
        ip_address: payload.ipAddress ?? null,
        user_agent: payload.userAgent ?? null,
      },
    });
  } catch (error) {
    console.error('[AuditLog Error] Failed to write audit event:', error);
  }
}

import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';
import { compressImage } from '@/lib/image-compress';
import { uploadToStorage } from '@/lib/storage-helper';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/profile/avatar
// ─────────────────────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId, accountId } = auth;

  try {
    const formData = await req.formData();
    const file = formData.get('file') as File | null;

    if (!file) {
      return err('No file provided', 400);
    }

    const MAX_SIZE = 20 * 1024 * 1024;
    if (file.size > MAX_SIZE) {
      return err('File is too large. Maximum size is 20MB', 400);
    }

    const arrayBuffer = await file.arrayBuffer();
    const rawBuffer = Buffer.from(arrayBuffer);

    let compressed;
    try {
      compressed = await compressImage(rawBuffer, 'avatar', file.name, file.type);
    } catch (e: any) {
      return err(e?.message || 'Invalid image file. Only image formats are allowed', 400);
    }

    const { data: accountData } = await supabaseAdmin
      .from('accounts')
      .select('email')
      .eq('id', accountId)
      .maybeSingle();

    const rawEmail = accountData?.email || userId;
    const cleanEmail = rawEmail.toLowerCase().trim().replace(/[^a-zA-Z0-9@._-]/g, '_');

    const bucketName = 'dovan';
    const fileName = `profile_pictures/${cleanEmail}.${compressed.extension}`;

    const finalUrl = await uploadToStorage(
      bucketName,
      fileName,
      compressed.buffer,
      compressed.contentType
    );

    await supabaseAdmin
      .from('accounts')
      .update({
        profile_image: finalUrl,
        updated_at: new Date().toISOString(),
      })
      .eq('id', accountId);

    return ok({
      url: finalUrl,
      image_url: finalUrl,
      data: { url: finalUrl, image_url: finalUrl },
      path: `${bucketName}/${fileName}`,
      bytes: compressed.compressedSize,
    });

  } catch (e) {
    console.error('[profile/avatar] Error processing image upload:', e);
    return err('Failed to process upload request', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

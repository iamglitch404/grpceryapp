import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';
import { compressImage } from '@/lib/image-compress';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/profile/avatar
// ─────────────────────────────────────────────────────────────────────────────
// Bucket: `dovan`
// Storage Path: `profile_pictures/<email_id>.webp`
// Compresses image to blazing-fast WebP format with stripped metadata (Meta standard).
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

    // Validate raw size (max 20MB raw input, compressed will be ~50-100KB)
    const MAX_SIZE = 20 * 1024 * 1024;
    if (file.size > MAX_SIZE) {
      return err('File is too large. Maximum size is 20MB', 400);
    }

    const arrayBuffer = await file.arrayBuffer();
    const rawBuffer = Buffer.from(arrayBuffer);

    // 1. Meta-Standard Image Compression
    let compressed;
    try {
      compressed = await compressImage(rawBuffer, 'avatar', file.name, file.type);
    } catch (e: any) {
      return err(e?.message || 'Invalid image file. Only image formats (JPG, PNG, WEBP, HEIC, GIF, AVIF) are allowed', 400);
    }

    // 2. Fetch user's email for clean canonical naming
    const { data: accountData } = await supabaseAdmin
      .from('accounts')
      .select('email')
      .eq('id', accountId)
      .maybeSingle();

    const rawEmail = accountData?.email || userId;
    const cleanEmail = rawEmail.toLowerCase().trim().replace(/[^a-zA-Z0-9@._-]/g, '_');

    // 3. Exact Storage Path: profile_pictures/<email_id>.webp inside `dovan` bucket
    const bucketName = 'dovan';
    const fileName = `profile_pictures/${cleanEmail}.${compressed.extension}`;

    const { error: uploadError } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(fileName, compressed.buffer, {
        contentType: compressed.contentType,
        upsert: true, // Overwrites with latest avatar
        cacheControl: '31536000', // 1-year CDN edge caching
      });

    if (uploadError) {
      console.error(`[profile/avatar] upload error into bucket '${bucketName}':`, uploadError);
      return err(`Failed to upload image into bucket '${bucketName}'. Please ensure bucket '${bucketName}' exists.`, 500);
    }

    // 4. Get Public CDN URL
    const { data: { publicUrl } } = supabaseAdmin.storage
      .from(bucketName)
      .getPublicUrl(fileName);

    const timestamp = Date.now();
    const finalUrl = `${publicUrl}?t=${timestamp}`;

    // 5. Update account profile with the new WebP Avatar URL
    await supabaseAdmin
      .from('accounts')
      .update({
        profile_image: finalUrl,
        updated_at: new Date().toISOString(),
      })
      .eq('id', accountId);

    return ok({
      url: finalUrl,
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

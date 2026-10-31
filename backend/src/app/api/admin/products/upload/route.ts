import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';
import { compressImage } from '@/lib/image-compress';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/products/upload — Upload & WebP Compress Product Image
// ─────────────────────────────────────────────────────────────────────────────
// Bucket: `dovan`
// Storage Path: `products/<filename>.webp`
// ─────────────────────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const formData = await req.formData();
    const file = formData.get('file') as File | null;

    if (!file) {
      return err('No file provided', 400);
    }

    const MAX_SIZE = 25 * 1024 * 1024;
    if (file.size > MAX_SIZE) {
      return err('File is too large. Maximum size is 25MB', 400);
    }

    const arrayBuffer = await file.arrayBuffer();
    const rawBuffer = Buffer.from(arrayBuffer);

    let compressed;
    try {
      compressed = await compressImage(rawBuffer, 'product', file.name, file.type);
    } catch (e: any) {
      return err(e?.message || 'Invalid image file. Only image formats (JPG, PNG, WEBP, HEIC, GIF, AVIF) are allowed', 400);
    }

    const bucketName = 'dovan';
    const uniqueId = `${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const fileName = `products/${uniqueId}.${compressed.extension}`;

    const { error: uploadError } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(fileName, compressed.buffer, {
        contentType: compressed.contentType,
        upsert: true,
        cacheControl: '31536000',
      });

    if (uploadError) {
      console.error(`[products/upload] error in bucket '${bucketName}':`, uploadError);
      return err(`Failed to upload product image into bucket '${bucketName}'`, 500);
    }

    const { data: { publicUrl } } = supabaseAdmin.storage
      .from(bucketName)
      .getPublicUrl(fileName);

    return ok({
      url: `${publicUrl}?t=${Date.now()}`,
      image_url: `${publicUrl}?t=${Date.now()}`,
      path: `${bucketName}/${fileName}`,
      bytes: compressed.compressedSize,
    });
  } catch (error) {
    console.error('[products/upload] catch error:', error);
    return err('Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

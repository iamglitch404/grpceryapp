import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';
import { compressImage } from '@/lib/image-compress';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/promotions/upload
// ─────────────────────────────────────────────────────────────────────────────
// Bucket: `dovan`
// Storage Path: `promotions/<slug_or_id>.webp`
// ─────────────────────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const formData = await req.formData();
    const file = formData.get('file') as File | null;
    const name = (formData.get('name') as string | null) || (formData.get('slug') as string | null) || `promo_${Date.now()}`;

    if (!file) {
      return err('No file provided', 400);
    }

    const MAX_SIZE = 25 * 1024 * 1024;
    if (file.size > MAX_SIZE) {
      return err('File is too large. Maximum size is 25MB', 400);
    }

    const cleanSlug = name.toLowerCase().trim().replace(/[^a-zA-Z0-9_-]/g, '_');
    const arrayBuffer = await file.arrayBuffer();
    const rawBuffer = Buffer.from(arrayBuffer);

    let compressed;
    try {
      compressed = await compressImage(rawBuffer, 'promotion', file.name, file.type);
    } catch (e: any) {
      return err(e?.message || 'Invalid image file. Only image formats (JPG, PNG, WEBP, HEIC, GIF, AVIF) are allowed', 400);
    }

    const storagePath = `promotions/${cleanSlug}.${compressed.extension}`;

    // Upload to Supabase Storage bucket 'dovan'
    const { error: uploadError } = await supabaseAdmin.storage
      .from('dovan')
      .upload(storagePath, compressed.buffer, {
        contentType: compressed.contentType,
        cacheControl: '31536000',
        upsert: true,
      });

    if (uploadError) {
      console.error('[promotions/upload] Supabase upload error:', uploadError);
      return err(`Failed to upload image: ${uploadError.message}`, 500);
    }

    // Get public URL
    const { data: publicUrlData } = supabaseAdmin.storage
      .from('dovan')
      .getPublicUrl(storagePath);

    return ok({
      message: 'Promotion image uploaded successfully',
      image_url: publicUrlData.publicUrl,
      storage_path: storagePath,
      bucket: 'dovan',
    });
  } catch (error: any) {
    console.error('[promotions/upload] Unexpected error:', error);
    return err(error.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

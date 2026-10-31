import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { supabaseAdmin } from '@/lib/supabase';
import { compressImage } from '@/lib/image-compress';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/categories/upload
// ─────────────────────────────────────────────────────────────────────────────
// Bucket: `dovan`
// Storage Paths:
//   Category:    `categories/<slug_or_name>.webp`
//   Subcategory: `subcategories/<slug_or_name>.webp`
// ─────────────────────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const formData = await req.formData();
    const file = formData.get('file') as File | null;
    const type = (formData.get('type') as string | null) || 'category'; // 'category' | 'subcategory'
    const name = (formData.get('name') as string | null) || (formData.get('slug') as string | null) || 'item';

    if (!file) {
      return err('No file provided', 400);
    }

    const MAX_SIZE = 20 * 1024 * 1024;
    if (file.size > MAX_SIZE) {
      return err('File is too large. Maximum size is 20MB', 400);
    }

    const cleanSlug = name.toLowerCase().trim().replace(/[^a-zA-Z0-9_-]/g, '_');
    const arrayBuffer = await file.arrayBuffer();
    const rawBuffer = Buffer.from(arrayBuffer);

    let compressed;
    try {
      compressed = await compressImage(rawBuffer, 'category', file.name, file.type);
    } catch (e: any) {
      return err(e?.message || 'Invalid image file. Only image formats (JPG, PNG, WEBP, SVG, HEIC, GIF) are allowed', 400);
    }

    // Determine target folder: 'categories' or 'subcategories' inside 'dovan' bucket
    const bucketName = 'dovan';
    const folder = type.toLowerCase().startsWith('sub') ? 'subcategories' : 'categories';
    const fileName = `${folder}/${cleanSlug}.${compressed.extension}`;

    const { error: uploadError } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(fileName, compressed.buffer, {
        contentType: compressed.contentType,
        upsert: true,
        cacheControl: '31536000',
      });

    if (uploadError) {
      console.error(`[categories/upload] upload error into bucket '${bucketName}':`, uploadError);
      return err(`Failed to upload image into bucket '${bucketName}'`, 500);
    }

    const { data: { publicUrl } } = supabaseAdmin.storage
      .from(bucketName)
      .getPublicUrl(fileName);

    const timestamp = Date.now();
    const finalUrl = `${publicUrl}?t=${timestamp}`;

    return ok({
      url: finalUrl,
      image_url: finalUrl,
      path: `${bucketName}/${fileName}`,
      type: folder,
      bytes: compressed.compressedSize,
    });
  } catch (error) {
    console.error('[categories/upload] catch error:', error);
    return err('Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

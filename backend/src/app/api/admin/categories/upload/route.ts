import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { compressImage } from '@/lib/image-compress';
import { uploadToStorage } from '@/lib/storage-helper';

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

    const bucketName = 'dovan';
    const folder = type.toLowerCase().startsWith('sub') ? 'subcategories' : 'categories';
    const fileName = `${folder}/${cleanSlug}.${compressed.extension}`;

    const finalUrl = await uploadToStorage(
      bucketName,
      fileName,
      compressed.buffer,
      compressed.contentType
    );

    return ok({
      url: finalUrl,
      image_url: finalUrl,
      data: { url: finalUrl, image_url: finalUrl },
      path: `${bucketName}/${fileName}`,
      type: folder,
      bytes: compressed.compressedSize,
    });
  } catch (error: any) {
    console.error('[categories/upload] catch error:', error);
    return err(error?.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

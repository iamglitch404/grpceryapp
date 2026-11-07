import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { compressImage } from '@/lib/image-compress';
import { uploadToStorage } from '@/lib/storage-helper';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/admin/home-deals/upload
// ─────────────────────────────────────────────────────────────────────────────

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;

  try {
    const formData = await req.formData();
    const file = formData.get('file') as File | null;
    const name = (formData.get('name') as string | null) || (formData.get('slug') as string | null) || `deal_${Date.now()}`;

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
      compressed = await compressImage(rawBuffer, 'deal', file.name, file.type);
    } catch (e: any) {
      return err(e?.message || 'Invalid image file. Only image formats are allowed', 400);
    }

    const bucketName = 'dovan';
    const storagePath = `home_deals/${cleanSlug}.${compressed.extension}`;

    const imageUrl = await uploadToStorage(
      bucketName,
      storagePath,
      compressed.buffer,
      compressed.contentType
    );

    return ok({
      message: 'Home deal image uploaded successfully',
      url: imageUrl,
      image_url: imageUrl,
      data: { url: imageUrl, image_url: imageUrl },
      storage_path: storagePath,
      bucket: bucketName,
    });
  } catch (error: any) {
    console.error('[home-deals/upload] Unexpected error:', error);
    return err(error.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextRequest } from 'next/server';
import { ok, err, handleOptions, requireAuth } from '@/lib/api';
import { compressImage, isImageMagicBytes, hasImageExtension } from '@/lib/image-compress';
import { uploadToStorage } from '@/lib/storage-helper';

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/tickets/upload — Upload Support Ticket Attachments (Images & Files)
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
    const originalName = file.name || 'attachment';

    const isImage =
      isImageMagicBytes(rawBuffer) ||
      hasImageExtension(originalName) ||
      (file.type && file.type.startsWith('image/'));

    let uploadBuffer: Buffer = rawBuffer;
    let contentType = file.type || 'application/octet-stream';
    let fileExtension = originalName.includes('.')
      ? originalName.split('.').pop()!.toLowerCase()
      : 'bin';

    if (isImage) {
      try {
        const compressed = await compressImage(rawBuffer, 'general', originalName, file.type);
        uploadBuffer = compressed.buffer;
        contentType = compressed.contentType;
        fileExtension = compressed.extension;
      } catch (e: any) {
        console.warn('[tickets/upload] compression notice, uploading raw image:', e?.message);
      }
    }

    const bucketName = 'dovan';
    const uniqueId = `${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const sanitizedBase = originalName
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .substring(0, 40);
    const fileName = isImage
      ? `tickets/${uniqueId}.${fileExtension}`
      : `tickets/${uniqueId}_${sanitizedBase}`;

    const publicUrl = await uploadToStorage(
      bucketName,
      fileName,
      uploadBuffer,
      contentType
    );

    return ok({
      url: publicUrl,
      image_url: publicUrl,
      file_name: originalName,
      file_size: uploadBuffer.length,
      file_type: isImage ? 'image' : 'file',
      mime_type: contentType,
      path: `${bucketName}/${fileName}`,
    });
  } catch (error: any) {
    console.error('[tickets/upload] catch error:', error);
    return err(error?.message || 'Internal Server Error', 500);
  }
}

export async function OPTIONS() {
  return handleOptions();
}

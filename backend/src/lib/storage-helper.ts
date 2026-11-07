import { supabaseAdmin } from './supabase';

export async function uploadToStorage(
  bucketName: string,
  fileName: string,
  buffer: Buffer,
  contentType: string
): Promise<string> {
  // 1. Try direct upload first
  let { error: uploadError } = await supabaseAdmin.storage
    .from(bucketName)
    .upload(fileName, buffer, {
      contentType,
      upsert: true,
      cacheControl: '31536000',
    });

  // 2. If bucket doesn't exist, create public bucket and retry upload
  if (uploadError && (uploadError as any).code === 'NoSuchBucket') {
    console.log(`[Storage] Creating missing public bucket '${bucketName}'...`);
    try {
      await supabaseAdmin.storage.createBucket(bucketName, { public: true });
      const retry = await supabaseAdmin.storage
        .from(bucketName)
        .upload(fileName, buffer, {
          contentType,
          upsert: true,
          cacheControl: '31536000',
        });
      uploadError = retry.error;
    } catch (createErr) {
      console.warn(`[Storage] Failed to auto-create bucket '${bucketName}':`, createErr);
    }
  }

  // 3. If storage succeeded, return public URL
  if (!uploadError) {
    const { data: { publicUrl } } = supabaseAdmin.storage
      .from(bucketName)
      .getPublicUrl(fileName);
    return `${publicUrl}?t=${Date.now()}`;
  }

  // 4. Fallback: Base64 Data URL guarantees images always work without breaking the build
  console.warn(`[Storage] Fallback to base64 Data URL for '${fileName}':`, uploadError);
  return `data:${contentType};base64,${buffer.toString('base64')}`;
}

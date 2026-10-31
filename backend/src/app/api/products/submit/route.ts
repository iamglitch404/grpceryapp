import { NextRequest } from 'next/server';
import { z } from 'zod';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, parseBody, handleOptions, requireAuth } from '@/lib/api';

const SubmitProductSchema = z.object({
  title: z.string().min(1, 'Product title is required'),
  description: z.string().optional(),
  price_paise: z.number().int().min(0, 'Price must be non-negative'),
  original_price_paise: z.number().int().min(0).optional(),
  unit: z.string().min(1, 'Unit is required (e.g. 1 kg, 500 g)'),
  image_url: z.string().optional(),
  category_id: z.string().uuid().optional().nullable(),
  subcategory_id: z.string().uuid().optional().nullable(),
  stock_quantity: z.number().int().min(0).default(10),
  pickup_address: z.string().min(1, 'Pickup address is required'),
  pickup_phone: z.string().min(1, 'Pickup contact phone is required'),
  pickup_time: z.string().optional(),
  calories: z.string().optional(),
  is_popular: z.boolean().optional(),
  is_todays_choice: z.boolean().optional(),
  is_special_deal: z.boolean().optional(),
});

export async function POST(req: NextRequest) {
  if (req.method === 'OPTIONS') return handleOptions();

  const auth = await requireAuth(req);
  if (auth instanceof Response) return auth;
  const { userId } = auth;

  const parsed = await parseBody(req, SubmitProductSchema);
  if (parsed instanceof Response) return parsed;

  const data = parsed.data;

  // Generate unique human-readable product tracking code (e.g. AERO-PRD-8A92B1)
  const randomSuffix = Math.random().toString(36).substring(2, 8).toUpperCase();
  const productCode = `AERO-PRD-${randomSuffix}`;

  const productPayload = {
    title: data.title,
    description: data.description || null,
    price_paise: data.price_paise,
    original_price_paise: data.original_price_paise || null,
    unit: data.unit,
    image_url: data.image_url || null,
    category_id: data.category_id || null,
    subcategory_id: data.subcategory_id || null,
    stock_quantity: data.stock_quantity,
    seller_id: userId,
    product_code: productCode,
    approval_status: 'pending',
    is_active: false, // Inactive until admin reviews & lists
    pickup_address: data.pickup_address,
    pickup_phone: data.pickup_phone,
    pickup_time: data.pickup_time || 'Standard Business Hours',
    calories: data.calories || null,
    is_popular: data.is_popular || false,
    is_todays_choice: data.is_todays_choice || false,
    is_special_deal: data.is_special_deal || false,
  };

  const { data: newProduct, error } = await supabaseAdmin
    .from('products')
    .insert(productPayload)
    .select('*, categories(id, name, image_url)')
    .single();

  if (error) {
    console.error('[products/submit] error:', error);
    return err('Failed to submit product for approval: ' + error.message, 500);
  }


  // Create an automated notification for the seller
  await supabaseAdmin.from('notifications').insert({
    account_id: userId,
    title: 'Product Submitted: ' + data.title,
    message: `Your product "${data.title}" (Code: ${productCode}) has been submitted for review. Admin will schedule pickup shortly.`,
    type: 'product_submission',
    data: {
      product_id: newProduct.id,
      product_code: productCode,
      title: data.title,
      pickup_address: data.pickup_address,
      pickup_time: data.pickup_time,
    },
  });

  return ok({
    product: newProduct,
    product_id: newProduct.id,
    product_code: productCode,
    qr_payload: JSON.stringify({
      code: productCode,
      id: newProduct.id,
      title: data.title,
      seller_id: userId,
      pickup_phone: data.pickup_phone,
    }),
    message: 'Product submitted successfully! Pending admin approval and pickup scheduling.',
  }, 201);
}

export async function OPTIONS() {
  return handleOptions();
}

import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase';
import { ok, err, handleOptions } from '@/lib/api';

export async function GET() {
  try {
    const [slotsRes, paymentsRes] = await Promise.all([
      supabaseAdmin.from('delivery_slots').select('*').eq('is_active', true).order('sort_order', { ascending: true }),
      supabaseAdmin.from('payment_methods').select('*').eq('is_active', true).order('sort_order', { ascending: true })
    ]);

    const defaultSlots = [
      { id: '1', slot_time: '08:00 AM - 10:00 AM', sort_order: 1 },
      { id: '2', slot_time: '10:00 AM - 12:00 PM', sort_order: 2 },
      { id: '3', slot_time: '12:00 PM - 02:00 PM', sort_order: 3 },
      { id: '4', slot_time: '02:00 PM - 04:00 PM', sort_order: 4 },
      { id: '5', slot_time: '04:00 PM - 06:00 PM', sort_order: 5 },
      { id: '6', slot_time: '06:00 PM - 08:00 PM', sort_order: 6 },
    ];

    const defaultPayments = [
      { id: '1', name: 'Cash on Delivery', icon_name: 'payments', sort_order: 1 },
      { id: '2', name: 'Debit/Credit Card', icon_name: 'credit_card', sort_order: 2 },
      { id: '3', name: 'eSewa / Khalti / Mobile Wallet', icon_name: 'account_balance_wallet', sort_order: 3 },
    ];

    const deliverySlots = (slotsRes.data && slotsRes.data.length > 0) ? slotsRes.data : defaultSlots;
    const paymentMethods = (paymentsRes.data && paymentsRes.data.length > 0) ? paymentsRes.data : defaultPayments;

    return ok({ deliverySlots, paymentMethods });
  } catch (error) {
    console.error('[GET /api/checkout-config] error:', error);
    return ok({
      deliverySlots: [
        { id: '1', slot_time: 'Standard (2-4 Hours)', sort_order: 1 },
        { id: '2', slot_time: 'Express (30 Mins)', sort_order: 2 },
      ],
      paymentMethods: [
        { id: '1', name: 'Cash on Delivery', icon_name: 'payments', sort_order: 1 },
      ],
    });
  }
}

export async function OPTIONS() {
  return handleOptions();
}

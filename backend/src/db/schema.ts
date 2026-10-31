import { pgTable, uuid, text, integer, boolean, real, doublePrecision, timestamp } from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

// =============================================================================
// 1. DELIVERY PARTNERS
// =============================================================================
export const deliveryPartners = pgTable('delivery_partners', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  accountId: uuid('account_id').notNull(),
  fullName: text('full_name').notNull(),
  phone: text('phone').notNull(),
  email: text('email'),
  avatarUrl: text('avatar_url'),
  status: text('status').notNull().default('offline'), // 'online' | 'offline' | 'busy' | 'on_delivery'
  vehicleType: text('vehicle_type').notNull().default('bike'), // 'bike' | 'scooter' | 'bicycle' | 'van'
  vehicleNumber: text('vehicle_number'),
  drivingLicenseNo: text('driving_license_no'),
  isVerified: boolean('is_verified').notNull().default(true),
  rating: real('rating').notNull().default(5.0),
  totalRatingsCount: integer('total_ratings_count').notNull().default(0),
  completedDeliveriesCount: integer('completed_deliveries_count').notNull().default(0),
  cancelledDeliveriesCount: integer('cancelled_deliveries_count').notNull().default(0),
  totalEarnedPaise: integer('total_earned_paise').notNull().default(0),
  currentLatitude: doublePrecision('current_latitude'),
  currentLongitude: doublePrecision('current_longitude'),
  lastLocationUpdatedAt: timestamp('last_location_updated_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

// =============================================================================
// 2. DELIVERY SHIFTS (Working Hours & Logs)
// =============================================================================
export const deliveryShifts = pgTable('delivery_shifts', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  deliveryPartnerId: uuid('delivery_partner_id').notNull().references(() => deliveryPartners.id, { onDelete: 'cascade' }),
  clockInAt: timestamp('clock_in_at', { withTimezone: true }).notNull().defaultNow(),
  clockOutAt: timestamp('clock_out_at', { withTimezone: true }),
  totalMinutes: integer('total_minutes').notNull().default(0),
  status: text('status').notNull().default('active'), // 'active' | 'completed'
  deliveriesCompleted: integer('deliveries_completed').notNull().default(0),
  earningsPaise: integer('earnings_paise').notNull().default(0),
  notes: text('notes'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

// =============================================================================
// 3. DELIVERY REVIEWS & RATINGS (User Feedback for Delivery Partners)
// =============================================================================
export const deliveryReviews = pgTable('delivery_reviews', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  orderId: uuid('order_id').notNull(),
  customerId: uuid('customer_id').notNull(),
  deliveryPartnerId: uuid('delivery_partner_id').notNull().references(() => deliveryPartners.id, { onDelete: 'cascade' }),
  rating: integer('rating').notNull(), // 1 to 5
  reviewText: text('review_text'),
  deliverySpeedRating: integer('delivery_speed_rating'), // 1 to 5
  communicationRating: integer('communication_rating'), // 1 to 5
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

// =============================================================================
// 4. DELIVERY ASSIGNMENTS (Admin Order Assignment & Status Lifecycle)
// =============================================================================
export const deliveryAssignments = pgTable('delivery_assignments', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  orderId: uuid('order_id').notNull(),
  deliveryPartnerId: uuid('delivery_partner_id').notNull().references(() => deliveryPartners.id, { onDelete: 'cascade' }),
  assignedByAdminId: uuid('assigned_by_admin_id'),
  status: text('status').notNull().default('assigned'), // 'assigned' | 'accepted' | 'declined' | 'arrived_store' | 'picked_up' | 'in_transit' | 'delivered'
  assignedAt: timestamp('assigned_at', { withTimezone: true }).notNull().defaultNow(),
  acceptedAt: timestamp('accepted_at', { withTimezone: true }),
  declinedAt: timestamp('declined_at', { withTimezone: true }),
  pickedUpAt: timestamp('picked_up_at', { withTimezone: true }),
  deliveredAt: timestamp('delivered_at', { withTimezone: true }),
  deliveryNotes: text('delivery_notes'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

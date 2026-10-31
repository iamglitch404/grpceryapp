-- =============================================================================
-- Dovan Canonical Production Database Schema
-- Architecture: Direct Native PostgreSQL + Native RLS + Custom Dovan Auth
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. EXTENSIONS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. ROLES PROVISIONING (LEAST PRIVILEGE)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_migrator') THEN
    CREATE ROLE dovan_migrator WITH NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_app') THEN
    CREATE ROLE dovan_app WITH NOLOGIN NOBYPASSRLS NOSUPERUSER NOCREATEDB NOCREATEROLE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_worker') THEN
    CREATE ROLE dovan_worker WITH NOLOGIN NOBYPASSRLS NOSUPERUSER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_readonly') THEN
    CREATE ROLE dovan_readonly WITH NOLOGIN NOBYPASSRLS NOSUPERUSER;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. CORE TRIGGER HELPERS
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Preserve updated_at if caller explicitly sets it to the existing value
  IF NEW.updated_at IS NOT DISTINCT FROM OLD.updated_at THEN
    RETURN NEW;
  END IF;
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Account Security: Enforce role & status protection against privilege escalation
CREATE OR REPLACE FUNCTION public.enforce_account_role_and_status_protection()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Non-admin callers can ONLY register with role = 'customer' and status = 'active'
    IF NOT public.is_app_admin() THEN
      NEW.role := 'customer';
      NEW.status := 'active';
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    -- Only an app admin can change role or status
    IF NOT public.is_app_admin() THEN
      IF NEW.role IS DISTINCT FROM OLD.role THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can modify account roles'
          USING ERRCODE = '42501';
      END IF;
      IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can modify account status'
          USING ERRCODE = '42501';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. IDENTITY CONTEXT & AUTHENTICATION FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- Transaction-local session context initializer
CREATE OR REPLACE FUNCTION public.set_app_session_context(
  p_token_hash text
)
RETURNS TABLE(account_id uuid, user_id uuid, role text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_account_id uuid;
  v_role text;
  v_status text;
BEGIN
  -- 1. Validate session: active, unexpired, and unrevoked
  SELECT s.account_id INTO v_account_id
  FROM public.sessions s
  WHERE s.token_hash = p_token_hash
    AND s.expires_at > now()
    AND s.revoked_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Authentication failed: invalid or expired session';
  END IF;

  -- 2. Verify account is active and resolve account role
  SELECT a.status, a.role INTO v_status, v_role
  FROM public.accounts a
  WHERE a.id = v_account_id;

  IF v_status != 'active' THEN
    RAISE EXCEPTION 'Authentication failed: account is %', v_status;
  END IF;

  -- 3. Establish transaction-local identity (cleared at COMMIT/ROLLBACK)
  PERFORM set_config('app.current_user_id', v_account_id::text, true);
  PERFORM set_config('app.current_user_role', v_role, true);

  account_id := v_account_id;
  user_id := v_account_id;
  role := v_role;
  RETURN NEXT;
END;
$$;

-- Primary canonical identity resolver
CREATE OR REPLACE FUNCTION public.current_app_account_id()
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::uuid;
$$;

-- Deprecated backwards-compatibility alias for current_app_account_id()
CREATE OR REPLACE FUNCTION public.current_app_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT public.current_app_account_id();
$$;

CREATE OR REPLACE FUNCTION public.is_app_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT current_setting('app.current_user_role', true) = 'admin';
$$;

-- Privileged admin function to manage account roles safely
CREATE OR REPLACE FUNCTION public.admin_update_account_role(
  p_account_id uuid,
  p_new_role   text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Administrator privileges required' USING ERRCODE = '42501';
  END IF;

  IF p_new_role NOT IN ('customer', 'admin', 'delivery_man') THEN
    RAISE EXCEPTION 'Invalid role: %', p_new_role USING ERRCODE = '22023';
  END IF;

  UPDATE public.accounts
  SET role = p_new_role, updated_at = now()
  WHERE id = p_account_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Account % not found', p_account_id USING ERRCODE = 'P0002';
  END IF;

  PERFORM public.write_audit_log('UPDATE_ROLE', 'accounts', p_account_id, jsonb_build_object('new_role', p_new_role));
END;
$$;

-- Secure login credential lookup (shields password_hash from direct SELECT)
CREATE OR REPLACE FUNCTION public.get_account_auth_record(
  p_email text
)
RETURNS TABLE(account_id uuid, password_hash text, status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  RETURN QUERY
  SELECT a.id, a.password_hash, a.status
  FROM public.accounts a
  WHERE a.email = lower(trim(p_email))
    AND a.status != 'deactivated';
END;
$$;

-- Cryptographic OTP Creation (Strict SHA-256 hash storage; replaces prior active OTPs)
CREATE OR REPLACE FUNCTION public.create_otp_request(
  p_email text,
  p_purpose text,
  p_code_hash text,
  p_account_id uuid DEFAULT NULL,
  p_expires_in_minutes integer DEFAULT 10
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_id uuid;
  v_clean_email text := lower(trim(p_email));
  v_ttl integer;
BEGIN
  -- Strict parameter validation
  IF v_clean_email IS NULL OR v_clean_email = '' THEN
    RAISE EXCEPTION 'Email is required to create an OTP request' USING ERRCODE = '22023';
  END IF;

  IF p_purpose IS NULL OR p_purpose NOT IN ('login', 'account_creation', 'forgot_password') THEN
    RAISE EXCEPTION 'Invalid OTP purpose: %. Must be login, account_creation, or forgot_password', p_purpose USING ERRCODE = '22023';
  END IF;

  IF p_code_hash IS NULL OR length(trim(p_code_hash)) != 64 THEN
    RAISE EXCEPTION 'Valid 64-character SHA-256 code_hash is required' USING ERRCODE = '22023';
  END IF;

  -- Enforce safe TTL between 1 and 60 minutes (default 10)
  v_ttl := greatest(1, least(coalesce(p_expires_in_minutes, 10), 60));

  -- Invalidate and purge prior active OTPs for the same email and purpose
  DELETE FROM public.otp_requests
  WHERE email = v_clean_email
    AND purpose = p_purpose;

  -- Insert new cryptographically hashed OTP request
  INSERT INTO public.otp_requests (
    account_id,
    email,
    purpose,
    code_hash,
    attempt_count,
    max_attempts,
    expires_at
  ) VALUES (
    p_account_id,
    v_clean_email,
    p_purpose,
    trim(p_code_hash),
    0,
    5,
    now() + (v_ttl || ' minutes')::interval
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- Atomic verification and one-time consumption of OTP (Strict SHA-256 only)
CREATE OR REPLACE FUNCTION public.verify_and_consume_otp(
  p_email text,
  p_purpose text,
  p_code text
)
RETURNS TABLE(success boolean, account_id uuid, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions
AS $$
DECLARE
  v_otp record;
  v_clean_code text := trim(p_code);
  v_hash text := encode(digest(v_clean_code, 'sha256'), 'hex');
BEGIN
  SELECT * INTO v_otp
  FROM public.otp_requests
  WHERE email = lower(trim(p_email))
    AND purpose = p_purpose
    AND expires_at > now()
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::uuid, 'No active OTP found or code has expired';
    RETURN;
  END IF;

  IF v_otp.attempt_count >= v_otp.max_attempts THEN
    DELETE FROM public.otp_requests WHERE id = v_otp.id;
    RETURN QUERY SELECT false, NULL::uuid, 'Maximum verification attempts exceeded';
    RETURN;
  END IF;

  -- Strict cryptographic check: only SHA-256 hash match accepted (no plaintext fallback)
  IF v_otp.code_hash != v_hash THEN
    UPDATE public.otp_requests SET attempt_count = attempt_count + 1 WHERE id = v_otp.id;
    RETURN QUERY SELECT false, NULL::uuid, 'Invalid OTP code';
    RETURN;
  END IF;

  -- One-time use: Delete consumed record immediately
  DELETE FROM public.otp_requests WHERE id = v_otp.id;
  RETURN QUERY SELECT true, v_otp.account_id, NULL::text;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. CANONICAL TABLES (27 TOTAL)
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. accounts
CREATE TABLE IF NOT EXISTS public.accounts (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  email          citext      UNIQUE NOT NULL,
  username       citext      UNIQUE,
  password_hash  text,
  provider       text        NOT NULL DEFAULT 'email',
  provider_id    text,
  name           text,
  phone          text,
  gender         text,
  profile_image  text,
  role           text        NOT NULL DEFAULT 'customer'
                             CHECK (role IN ('customer', 'admin', 'delivery_man')),
  referral_code  text        UNIQUE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  last_login_at  timestamptz,
  status         text        NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active', 'suspended', 'deactivated'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_provider_provider_id
  ON public.accounts (provider, provider_id)
  WHERE provider_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_accounts_role ON public.accounts (role);
CREATE INDEX IF NOT EXISTS idx_accounts_referral_code ON public.accounts (referral_code);

DROP TRIGGER IF EXISTS trg_protect_account_role_and_status ON public.accounts;
CREATE TRIGGER trg_protect_account_role_and_status
  BEFORE INSERT OR UPDATE ON public.accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_account_role_and_status_protection();

-- 2. sessions
CREATE TABLE IF NOT EXISTS public.sessions (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id     uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  token_hash     text        NOT NULL UNIQUE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  expires_at     timestamptz NOT NULL,
  last_active_at timestamptz NOT NULL DEFAULT now(),
  revoked_at     timestamptz,
  user_agent     text,
  ip_address     text,
  device_name    text,
  location       text
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_token_hash ON public.sessions (token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_account_id ON public.sessions (account_id);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON public.sessions (token_hash, expires_at) WHERE revoked_at IS NULL;

-- 3. otp_requests
CREATE TABLE IF NOT EXISTS public.otp_requests (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id     uuid        REFERENCES public.accounts (id) ON DELETE CASCADE,
  email          citext      NOT NULL,
  purpose        text        NOT NULL CHECK (purpose IN ('login', 'account_creation', 'forgot_password')),
  code_hash      text        NOT NULL,
  attempt_count  integer     NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  max_attempts   integer     NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
  expires_at     timestamptz NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_requests_lookup ON public.otp_requests (email, purpose, expires_at);

-- 4. categories
CREATE TABLE IF NOT EXISTS public.categories (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name           text        NOT NULL,
  slug           text        UNIQUE,
  image_url      text,
  color_hex      text,
  sort_order     smallint    NOT NULL DEFAULT 0,
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_categories_active ON public.categories (is_active, sort_order);

-- 5. subcategories
CREATE TABLE IF NOT EXISTS public.subcategories (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id    uuid        NOT NULL REFERENCES public.categories (id) ON DELETE CASCADE,
  name           text        NOT NULL,
  slug           text,
  description    text,
  image_url      text,
  sort_order     smallint    NOT NULL DEFAULT 0,
  is_active      boolean     NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE(category_id, name)
);

CREATE INDEX IF NOT EXISTS idx_subcategories_category ON public.subcategories (category_id, sort_order);

-- 6. products (Canonical catalog absorbing seller listings)
CREATE TABLE IF NOT EXISTS public.products (
  id                     uuid             PRIMARY KEY DEFAULT uuid_generate_v4(),
  title                  text             NOT NULL,
  description            text,
  price_paise            integer          NOT NULL DEFAULT 0 CHECK (price_paise >= 0),
  original_price_paise   integer          CHECK (original_price_paise IS NULL OR original_price_paise >= price_paise),
  unit                   text             NOT NULL DEFAULT '1 kg',
  image_url              text,
  category_id            uuid             REFERENCES public.categories (id) ON DELETE SET NULL,
  subcategory_id         uuid             REFERENCES public.subcategories (id) ON DELETE SET NULL,
  -- seller_id: NULL for platform catalog items; references accounts(id) for marketplace seller listings
  seller_id              uuid             REFERENCES public.accounts (id) ON DELETE SET NULL,
  product_code           text,
  stock_quantity         integer          NOT NULL DEFAULT 10 CHECK (stock_quantity >= 0),
  is_todays_choice       boolean          NOT NULL DEFAULT false,
  is_special_deal        boolean          NOT NULL DEFAULT false,
  is_popular             boolean          NOT NULL DEFAULT false,
  is_active              boolean          NOT NULL DEFAULT true,
  approval_status        text             NOT NULL DEFAULT 'listed'
                                          CHECK (approval_status IN ('pending', 'approved', 'scheduled_for_pickup', 'listed', 'rejected')),
  rejection_reason       text,
  admin_notes            text,
  approved_at            timestamptz,
  pickup_address         text,
  pickup_phone           text,
  pickup_time            text,
  seller_latitude        numeric(10, 7)   CHECK (seller_latitude IS NULL OR (seller_latitude >= -90.0 AND seller_latitude <= 90.0)),
  seller_longitude       numeric(10, 7)   CHECK (seller_longitude IS NULL OR (seller_longitude >= -180.0 AND seller_longitude <= 180.0)),
  purchase_count         integer          NOT NULL DEFAULT 0 CHECK (purchase_count >= 0),
  avg_rating             numeric(2, 1)    CHECK (avg_rating IS NULL OR (avg_rating >= 1.0 AND avg_rating <= 5.0)),
  review_count           integer          NOT NULL DEFAULT 0 CHECK (review_count >= 0),
  calories               text,
  delivery_time_minutes  smallint         DEFAULT 20,
  tags                   text[],
  created_at             timestamptz      NOT NULL DEFAULT now(),
  updated_at             timestamptz      NOT NULL DEFAULT now(),
  CONSTRAINT chk_products_active_consistency CHECK (
    (is_active = false) OR (is_active = true AND approval_status = 'listed')
  ),
  CONSTRAINT chk_products_promotion_flags CHECK (
    (is_todays_choice = false AND is_special_deal = false AND is_popular = false)
    OR (is_active = true AND approval_status = 'listed')
  )
);

CREATE INDEX IF NOT EXISTS idx_products_category ON public.products (category_id);
CREATE INDEX IF NOT EXISTS idx_products_subcategory ON public.products (subcategory_id);
CREATE INDEX IF NOT EXISTS idx_products_seller ON public.products (seller_id);
CREATE INDEX IF NOT EXISTS idx_products_approval ON public.products (approval_status);
CREATE INDEX IF NOT EXISTS idx_products_active ON public.products (is_active) WHERE is_active = true;

-- 7. addresses
CREATE TABLE IF NOT EXISTS public.addresses (
  id             uuid             PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id     uuid             NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  label          text             NOT NULL DEFAULT 'Home',
  name           text             NOT NULL,
  street         text             NOT NULL,
  details        text,
  phone          text             NOT NULL,
  is_default     boolean          NOT NULL DEFAULT false,
  latitude       double precision CHECK (latitude IS NULL OR (latitude >= -90.0 AND latitude <= 90.0)),
  longitude      double precision CHECK (longitude IS NULL OR (longitude >= -180.0 AND longitude <= 180.0)),
  created_at     timestamptz      NOT NULL DEFAULT now(),
  updated_at     timestamptz      NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_addresses_account_id ON public.addresses (account_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_addresses_one_default ON public.addresses (account_id) WHERE is_default = true;

-- 8. orders (Immutable retail transactions)
CREATE TABLE IF NOT EXISTS public.orders (
  id                       uuid             PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id               uuid             NOT NULL REFERENCES public.accounts (id) ON DELETE RESTRICT,
  subtotal_paise           integer          NOT NULL CHECK (subtotal_paise >= 0),
  delivery_fee_paise       integer          NOT NULL DEFAULT 0 CHECK (delivery_fee_paise >= 0),
  platform_fee_paise       integer          NOT NULL DEFAULT 0 CHECK (platform_fee_paise >= 0),
  slot_fee_paise           integer          NOT NULL DEFAULT 0 CHECK (slot_fee_paise >= 0),
  discount_paise           integer          NOT NULL DEFAULT 0 CHECK (discount_paise >= 0),
  total_paise              integer          NOT NULL CHECK (total_paise >= 0),
  delivery_slot            text             NOT NULL,
  address_snapshot         jsonb            NOT NULL,
  payment_method           text             NOT NULL,
  payment_status           text             NOT NULL DEFAULT 'pending'
                                            CHECK (payment_status IN ('pending', 'paid', 'refunded', 'failed')),
  status                   text             NOT NULL DEFAULT 'Pending'
                                            CHECK (status IN ('Pending', 'Processing', 'Out for Delivery', 'Delivered', 'Cancelled')),
  device_location_address  text,
  device_latitude          double precision CHECK (device_latitude IS NULL OR (device_latitude >= -90.0 AND device_latitude <= 90.0)),
  device_longitude         double precision CHECK (device_longitude IS NULL OR (device_longitude >= -180.0 AND device_longitude <= 180.0)),
  destination_address      text,
  destination_latitude     double precision CHECK (destination_latitude IS NULL OR (destination_latitude >= -90.0 AND destination_latitude <= 90.0)),
  destination_longitude    double precision CHECK (destination_longitude IS NULL OR (destination_longitude >= -180.0 AND destination_longitude <= 180.0)),
  location_discrepancy_km  double precision CHECK (location_discrepancy_km IS NULL OR location_discrepancy_km >= 0),
  is_fraud_flagged         boolean          NOT NULL DEFAULT false,
  fraud_reason             text,
  created_at               timestamptz      NOT NULL DEFAULT now(),
  updated_at               timestamptz      NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_account_id ON public.orders (account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_fraud_flagged ON public.orders (is_fraud_flagged) WHERE is_fraud_flagged = true;

-- 9. order_items (Immutable line items snapshot)
CREATE TABLE IF NOT EXISTS public.order_items (
  id                    uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id              uuid        NOT NULL REFERENCES public.orders (id) ON DELETE RESTRICT,
  product_id            uuid        NOT NULL REFERENCES public.products (id) ON DELETE RESTRICT,
  title_snapshot        text        NOT NULL,
  price_paise_snapshot  integer     NOT NULL CHECK (price_paise_snapshot >= 0),
  quantity              integer     NOT NULL CHECK (quantity > 0),
  image_url_snapshot    text,
  unit_snapshot         text,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON public.order_items (product_id);

-- 10. delivery_slots
CREATE TABLE IF NOT EXISTS public.delivery_slots (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  label       text        NOT NULL,
  fee_paise   integer     NOT NULL DEFAULT 0 CHECK (fee_paise >= 0),
  is_active   boolean     NOT NULL DEFAULT true,
  sort_order  smallint    NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- 11. payment_methods (Public gateway options; zero secrets)
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        text        NOT NULL,
  code        text        NOT NULL UNIQUE,
  icon_name   text,
  is_active   boolean     NOT NULL DEFAULT true,
  sort_order  smallint    NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- 12. cart (Ephemeral customer draft carts)
CREATE TABLE IF NOT EXISTS public.cart (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id  uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  product_id  uuid        NOT NULL REFERENCES public.products (id) ON DELETE CASCADE,
  quantity    integer     NOT NULL DEFAULT 1 CHECK (quantity > 0),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(account_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_cart_account ON public.cart (account_id);

-- 13. favorites (Customer wishlists)
CREATE TABLE IF NOT EXISTS public.favorites (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id  uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  product_id  uuid        NOT NULL REFERENCES public.products (id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(account_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_account ON public.favorites (account_id);

-- 14. reviews (Author anonymized on deletion; product link protected)
CREATE TABLE IF NOT EXISTS public.reviews (
  id                   uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id           uuid        REFERENCES public.accounts (id) ON DELETE SET NULL,
  product_id           uuid        NOT NULL REFERENCES public.products (id) ON DELETE RESTRICT,
  rating               smallint    NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text          text,
  is_verified_purchase boolean     NOT NULL DEFAULT false,
  is_published         boolean     NOT NULL DEFAULT true,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_account_product
  ON public.reviews (account_id, product_id)
  WHERE account_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_product ON public.reviews (product_id, rating);

-- 15. home_deals (Campaign cards & home promotional banners)
CREATE TABLE IF NOT EXISTS public.home_deals (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  title          text        NOT NULL,
  subtitle       text,
  badge_text     text,
  discount_text  text,
  image_url      text        NOT NULL,
  action_url     text,
  bg_gradient    text,
  is_active      boolean     NOT NULL DEFAULT true,
  sort_order     smallint    NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

-- 16. promotions
CREATE TABLE IF NOT EXISTS public.promotions (
  id                    uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  code                  text        NOT NULL UNIQUE,
  title                 text        NOT NULL,
  description           text,
  discount_type         text        NOT NULL CHECK (discount_type IN ('percentage', 'fixed_amount', 'free_shipping')),
  discount_value        numeric     NOT NULL CHECK (discount_value > 0),
  min_order_paise       integer     NOT NULL DEFAULT 0 CHECK (min_order_paise >= 0),
  max_discount_paise    integer     CHECK (max_discount_paise IS NULL OR max_discount_paise > 0),
  usage_limit           integer     CHECK (usage_limit IS NULL OR usage_limit > 0),
  usage_count           integer     NOT NULL DEFAULT 0 CHECK (usage_count >= 0),
  is_active             boolean     NOT NULL DEFAULT true,
  expires_at            timestamptz,
  terms_and_conditions  text,       -- Maintained automatically from promotion_terms
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- 17. promotion_terms (Canonical structured bullet terms)
CREATE TABLE IF NOT EXISTS public.promotion_terms (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  promotion_id   uuid        NOT NULL REFERENCES public.promotions (id) ON DELETE CASCADE,
  term_text      text        NOT NULL,
  display_order  smallint    NOT NULL DEFAULT 0,
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_promotion_terms_lookup ON public.promotion_terms (promotion_id, display_order);

-- 18. user_promotions
CREATE TABLE IF NOT EXISTS public.user_promotions (
  id             uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id     uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  promotion_id   uuid        NOT NULL REFERENCES public.promotions (id) ON DELETE CASCADE,
  status         text        NOT NULL DEFAULT 'claimed' CHECK (status IN ('claimed', 'used', 'expired')),
  claimed_at     timestamptz NOT NULL DEFAULT now(),
  used_at        timestamptz,
  UNIQUE(account_id, promotion_id)
);

-- 19. referral_transactions (Permanent financial reward records)
CREATE TABLE IF NOT EXISTS public.referral_transactions (
  id                   uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_account_id  uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE RESTRICT,
  referred_account_id  uuid        REFERENCES public.accounts (id) ON DELETE SET NULL,
  status               text        NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
  points_rewarded      integer     NOT NULL DEFAULT 100 CHECK (points_rewarded >= 0),
  referred_device_id   text,
  referred_ip_address  text,
  is_fraud_flagged     boolean     NOT NULL DEFAULT false,
  fraud_reason         text,
  completed_at         timestamptz,
  created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_referral_tx_unique_referred
  ON public.referral_transactions (referred_account_id)
  WHERE referred_account_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_referral_tx_referrer ON public.referral_transactions (referrer_account_id);

-- 20. reward_items (Catalog items; voucher_code is shielded)
CREATE TABLE IF NOT EXISTS public.reward_items (
  id              uuid           PRIMARY KEY DEFAULT uuid_generate_v4(),
  title           text           NOT NULL,
  description     text,
  category        text           NOT NULL DEFAULT 'Free Items'
                                 CHECK (category IN ('Free Items', 'Vouchers', 'Delivery Passes', 'Merchandise')),
  points_cost     integer        NOT NULL CHECK (points_cost > 0),
  tag             text,
  icon_name       text,
  image_url       text,
  stock_quantity  integer        NOT NULL DEFAULT 100 CHECK (stock_quantity >= 0),
  is_active       boolean        NOT NULL DEFAULT true,
  voucher_code    text,          -- Internal master voucher template (shielded)
  created_at      timestamptz    NOT NULL DEFAULT now(),
  updated_at      timestamptz    NOT NULL DEFAULT now()
);

-- 21. user_points_ledger (Immutable append-only value history)
CREATE TABLE IF NOT EXISTS public.user_points_ledger (
  id                uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id        uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE RESTRICT,
  points_change     integer     NOT NULL,
  transaction_type  text        NOT NULL CHECK (transaction_type IN ('referral_bonus', 'welcome_bonus', 'order_cashback', 'rewards_shop_redemption', 'points_refund', 'admin_adjustment')),
  reference_type    text        CHECK (reference_type IN ('referral_transaction', 'reward_redemption', 'order', 'signup_referral', 'manual_adjustment')),
  reference_id      uuid,
  description       text        NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_points_ledger_account ON public.user_points_ledger (account_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_points_ledger_idempotency
  ON public.user_points_ledger (account_id, transaction_type, reference_type, reference_id)
  WHERE reference_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_points_ledger_welcome
  ON public.user_points_ledger (account_id)
  WHERE transaction_type = 'welcome_bonus';

-- 22. user_reward_redemptions (Permanent value history)
CREATE TABLE IF NOT EXISTS public.user_reward_redemptions (
  id              uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id      uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE RESTRICT,
  reward_item_id  uuid        NOT NULL REFERENCES public.reward_items (id) ON DELETE RESTRICT,
  points_spent    integer     NOT NULL CHECK (points_spent > 0),
  status          text        NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired', 'cancelled')),
  voucher_code    text        NOT NULL,
  expires_at      timestamptz,
  redeemed_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_redemptions_account ON public.user_reward_redemptions (account_id);

-- 23. audit_logs (Append-only system security audit trail)
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id           uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id   uuid        REFERENCES public.accounts (id) ON DELETE SET NULL,
  action       text        NOT NULL,
  target_type  text,
  target_id    uuid,
  metadata     jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_lookup ON public.audit_logs (account_id, action, created_at DESC);

-- 24. notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id  uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  title       text        NOT NULL,
  body        text        NOT NULL,
  is_read     boolean     NOT NULL DEFAULT false,
  data        jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_account ON public.notifications (account_id, created_at DESC);

-- 25. announcements
CREATE TABLE IF NOT EXISTS public.announcements (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  title       text        NOT NULL,
  message     text        NOT NULL,
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- 26. user_dismissed_announcements
CREATE TABLE IF NOT EXISTS public.user_dismissed_announcements (
  id                uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id        uuid        NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  announcement_id   uuid        NOT NULL REFERENCES public.announcements (id) ON DELETE CASCADE,
  dismissed_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(account_id, announcement_id)
);

-- 27. ticket (Customer support tickets; retained as singular)
CREATE TABLE IF NOT EXISTS public.ticket (
  id          uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id  uuid        REFERENCES public.accounts (id) ON DELETE SET NULL,
  subject     text        NOT NULL DEFAULT 'Support Request',
  message     text        NOT NULL,
  attachments jsonb       NOT NULL DEFAULT '[]'::jsonb,
  status      text        NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'In Progress', 'Resolved', 'Closed')),
  resolved_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ticket_account ON public.ticket (account_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. LEGACY MIGRATION: user_products INTO products
-- ─────────────────────────────────────────────────────────────────────────────
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_products') THEN
    -- Enrich products with existing matching user_products metadata
    UPDATE public.products p
    SET 
      seller_id = up.user_id,
      pickup_address = COALESCE(p.pickup_address, up.user_location),
      pickup_phone = COALESCE(p.pickup_phone, up.contact_phone),
      pickup_time = COALESCE(p.pickup_time, up.pickup_time),
      seller_latitude = COALESCE(p.seller_latitude, up.latitude),
      seller_longitude = COALESCE(p.seller_longitude, up.longitude),
      approval_status = COALESCE(p.approval_status, up.approval_status),
      rejection_reason = COALESCE(p.rejection_reason, up.rejection_reason),
      admin_notes = COALESCE(p.admin_notes, up.admin_notes),
      approved_at = COALESCE(p.approved_at, up.approved_at)
    FROM public.user_products up
    WHERE up.product_id = p.id;

    -- Insert any orphaned user_products rows into products as inactive pending drafts
    INSERT INTO public.products (
      title, description, price_paise, original_price_paise, unit, stock_quantity,
      image_url, category_id, subcategory_id, seller_id, product_code,
      pickup_address, pickup_phone, pickup_time, seller_latitude, seller_longitude,
      approval_status, is_active, created_at, updated_at
    )
    SELECT 
      up.title, up.description, up.price_paise, up.original_price_paise, up.unit, up.stock_quantity,
      up.image_url, up.category_id, up.subcategory_id, up.user_id, up.product_code,
      up.user_location, up.contact_phone, up.pickup_time, up.latitude, up.longitude,
      up.approval_status, false, up.created_at, up.updated_at
    FROM public.user_products up
    WHERE NOT EXISTS (SELECT 1 FROM public.products p WHERE p.id = up.product_id);

    -- Safe drop of redundant legacy table (RESTRICT ensures unexpected dependencies abort)
    DROP TABLE public.user_products;
  END IF;

  -- Safe migration: Ensure accounts.role exists and migrate from users if present
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'accounts' AND column_name = 'role'
  ) THEN
    ALTER TABLE public.accounts ADD COLUMN role text NOT NULL DEFAULT 'customer'
      CHECK (role IN ('customer', 'admin', 'delivery_man'));
    CREATE INDEX IF NOT EXISTS idx_accounts_role ON public.accounts (role);
  END IF;

  -- Safe migration: Ensure accounts.referral_code exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'accounts' AND column_name = 'referral_code'
  ) THEN
    ALTER TABLE public.accounts ADD COLUMN referral_code text UNIQUE;
    CREATE INDEX IF NOT EXISTS idx_accounts_referral_code ON public.accounts (referral_code);
  END IF;

  -- Safe consolidation of legacy users table into accounts
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    -- Check 1: Verify no duplicate users exist per account_id
    IF EXISTS (
      SELECT 1 FROM public.users
      WHERE account_id IS NOT NULL
      GROUP BY account_id
      HAVING COUNT(*) > 1
    ) THEN
      RAISE EXCEPTION 'Migration pre-check aborted: Multiple users rows found for the same account_id';
    END IF;

    -- Check 2: Verify no orphaned users records exist that cannot be mapped to an account
    IF EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.account_id IS NULL 
         OR NOT EXISTS (SELECT 1 FROM public.accounts a WHERE a.id = u.account_id)
    ) THEN
      RAISE EXCEPTION 'Migration pre-check aborted: Orphaned users rows found with NULL or invalid account_id';
    END IF;

    -- Migrate role if present
    IF EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'role'
    ) THEN
      UPDATE public.accounts a
      SET role = u.role
      FROM public.users u
      WHERE u.account_id = a.id AND u.role IS NOT NULL;
    END IF;

    -- Migrate referral_code
    UPDATE public.accounts a
    SET referral_code = u.referral_code
    FROM public.users u
    WHERE u.account_id = a.id AND a.referral_code IS NULL AND u.referral_code IS NOT NULL;

    -- Update existing records in all dependent tables from legacy users.id to corresponding accounts.id
    UPDATE public.products p SET seller_id = u.account_id FROM public.users u WHERE p.seller_id = u.id;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'addresses' AND column_name = 'user_id') THEN
      UPDATE public.addresses a SET user_id = u.account_id FROM public.users u WHERE a.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'user_id') THEN
      UPDATE public.orders o SET user_id = u.account_id FROM public.users u WHERE o.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'cart' AND column_name = 'user_id') THEN
      UPDATE public.cart c SET user_id = u.account_id FROM public.users u WHERE c.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'favorites' AND column_name = 'user_id') THEN
      UPDATE public.favorites f SET user_id = u.account_id FROM public.users u WHERE f.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'reviews' AND column_name = 'user_id') THEN
      UPDATE public.reviews r SET user_id = u.account_id FROM public.users u WHERE r.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_promotions' AND column_name = 'user_id') THEN
      UPDATE public.user_promotions up SET user_id = u.account_id FROM public.users u WHERE up.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'referral_transactions' AND column_name = 'referrer_id') THEN
      UPDATE public.referral_transactions rt SET referrer_id = u.account_id FROM public.users u WHERE rt.referrer_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'referral_transactions' AND column_name = 'referred_user_id') THEN
      UPDATE public.referral_transactions rt SET referred_user_id = u.account_id FROM public.users u WHERE rt.referred_user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_points_ledger' AND column_name = 'user_id') THEN
      UPDATE public.user_points_ledger upl SET user_id = u.account_id FROM public.users u WHERE upl.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_reward_redemptions' AND column_name = 'user_id') THEN
      UPDATE public.user_reward_redemptions urr SET user_id = u.account_id FROM public.users u WHERE urr.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'user_id') THEN
      UPDATE public.notifications n SET user_id = u.account_id FROM public.users u WHERE n.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_dismissed_announcements' AND column_name = 'user_id') THEN
      UPDATE public.user_dismissed_announcements uda SET user_id = u.account_id FROM public.users u WHERE uda.user_id = u.id;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ticket' AND column_name = 'user_id') THEN
      UPDATE public.ticket t SET user_id = u.account_id FROM public.users u WHERE t.user_id = u.id;
    END IF;

    -- Safe drop of obsolete users table (absorbed into accounts; RESTRICT prevents accidental cascading)
    DROP TABLE public.users;
  END IF;

  -- Safe migration: Rename user_id to account_id on any existing tables
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'addresses' AND column_name = 'user_id') THEN
    ALTER TABLE public.addresses RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'orders' AND column_name = 'user_id') THEN
    ALTER TABLE public.orders RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'cart' AND column_name = 'user_id') THEN
    ALTER TABLE public.cart RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'favorites' AND column_name = 'user_id') THEN
    ALTER TABLE public.favorites RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'reviews' AND column_name = 'user_id') THEN
    ALTER TABLE public.reviews RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_promotions' AND column_name = 'user_id') THEN
    ALTER TABLE public.user_promotions RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'referral_transactions' AND column_name = 'referrer_id') THEN
    ALTER TABLE public.referral_transactions RENAME COLUMN referrer_id TO referrer_account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'referral_transactions' AND column_name = 'referred_user_id') THEN
    ALTER TABLE public.referral_transactions RENAME COLUMN referred_user_id TO referred_account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_points_ledger' AND column_name = 'user_id') THEN
    ALTER TABLE public.user_points_ledger RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_reward_redemptions' AND column_name = 'user_id') THEN
    ALTER TABLE public.user_reward_redemptions RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'user_id') THEN
    ALTER TABLE public.notifications RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_dismissed_announcements' AND column_name = 'user_id') THEN
    ALTER TABLE public.user_dismissed_announcements RENAME COLUMN user_id TO account_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ticket' AND column_name = 'user_id') THEN
    ALTER TABLE public.ticket RENAME COLUMN user_id TO account_id;
  END IF;

  -- Safe drop of obsolete banners table (superseded by home_deals; RESTRICT prevents accidental cascading)
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'banners'
  ) THEN
    DROP TABLE public.banners;
  END IF;

  -- Sanitize existing product state flags to satisfy consistency check constraints
  UPDATE public.products
  SET is_active = false
  WHERE approval_status != 'listed' AND is_active = true;

  UPDATE public.products
  SET is_todays_choice = false, is_special_deal = false, is_popular = false
  WHERE is_active = false;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. TRIGGERS & MAINTENANCE FUNCTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- Trigger: Review rating recalculation (preserves products.updated_at)
CREATE OR REPLACE FUNCTION public.update_product_rating_aggregates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_prod_id uuid;
  v_avg numeric(2, 1);
  v_count integer;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_prod_id := OLD.product_id;
  ELSE
    v_prod_id := NEW.product_id;
  END IF;

  SELECT ROUND(AVG(rating)::numeric, 1), COUNT(*)::integer
  INTO v_avg, v_count
  FROM public.reviews
  WHERE product_id = v_prod_id AND is_published = true;

  UPDATE public.products
  SET avg_rating = v_avg,
      review_count = v_count
  WHERE id = v_prod_id;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_review_rating_aggregates ON public.reviews;
CREATE TRIGGER trg_review_rating_aggregates
AFTER INSERT OR UPDATE OF rating, is_published OR DELETE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.update_product_rating_aggregates();

-- Trigger: Promotion terms text sync (deterministic ordering)
CREATE OR REPLACE FUNCTION public.sync_promotion_terms_text()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_promo_id uuid := COALESCE(NEW.promotion_id, OLD.promotion_id);
  v_terms text;
BEGIN
  SELECT string_agg(term_text, E'\n' ORDER BY display_order ASC, created_at ASC)
  INTO v_terms
  FROM public.promotion_terms
  WHERE promotion_id = v_promo_id;

  UPDATE public.promotions
  SET terms_and_conditions = v_terms
  WHERE id = v_promo_id;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_promotion_terms ON public.promotion_terms;
CREATE TRIGGER trg_sync_promotion_terms
AFTER INSERT OR UPDATE OR DELETE ON public.promotion_terms
FOR EACH ROW EXECUTE FUNCTION public.sync_promotion_terms_text();

-- Trigger: Order GPS fraud distance detection (> 15 km discrepancy)
CREATE OR REPLACE FUNCTION public.check_order_fraud_flag()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_dist_km double precision;
  dlat double precision;
  dlon double precision;
  a double precision;
  c double precision;
BEGIN
  IF NEW.device_latitude IS NOT NULL AND NEW.device_longitude IS NOT NULL
     AND NEW.destination_latitude IS NOT NULL AND NEW.destination_longitude IS NOT NULL THEN
    -- Haversine formula calculation
    dlat := radians(NEW.destination_latitude - NEW.device_latitude);
    dlon := radians(NEW.destination_longitude - NEW.device_longitude);
    a := sin(dlat/2)^2 + cos(radians(NEW.device_latitude)) * cos(radians(NEW.destination_latitude)) * sin(dlon/2)^2;
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    v_dist_km := 6371 * c;
    NEW.location_discrepancy_km := round(v_dist_km::numeric, 2);

    IF v_dist_km > 15.0 THEN
      NEW.is_fraud_flagged := true;
      NEW.fraud_reason := 'Device GPS discrepancy (' || round(v_dist_km::numeric, 1)::text || ' km) exceeds 15km threshold';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_fraud_check ON public.orders;
CREATE TRIGGER trg_order_fraud_check
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.check_order_fraud_flag();

-- Updated_at triggers
DROP TRIGGER IF EXISTS trg_accounts_updated_at ON public.accounts;
CREATE TRIGGER trg_accounts_updated_at BEFORE UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_categories_updated_at ON public.categories;
CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_subcategories_updated_at ON public.subcategories;
CREATE TRIGGER trg_subcategories_updated_at BEFORE UPDATE ON public.subcategories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_products_updated_at ON public.products;
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_addresses_updated_at ON public.addresses;
CREATE TRIGGER trg_addresses_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_orders_updated_at ON public.orders;
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_cart_updated_at ON public.cart;
CREATE TRIGGER trg_cart_updated_at BEFORE UPDATE ON public.cart FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_reviews_updated_at ON public.reviews;
CREATE TRIGGER trg_reviews_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_home_deals_updated_at ON public.home_deals;
CREATE TRIGGER trg_home_deals_updated_at BEFORE UPDATE ON public.home_deals FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_promotions_updated_at ON public.promotions;
CREATE TRIGGER trg_promotions_updated_at BEFORE UPDATE ON public.promotions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_reward_items_updated_at ON public.reward_items;
CREATE TRIGGER trg_reward_items_updated_at BEFORE UPDATE ON public.reward_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_ticket_updated_at ON public.ticket;
CREATE TRIGGER trg_ticket_updated_at BEFORE UPDATE ON public.ticket FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. BUSINESS STORED PROCEDURES & TRANSACTIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- Internal locked redemption helper (Enforces consistent Accounts -> RewardItems lock order)
CREATE OR REPLACE FUNCTION public._internal_execute_reward_redemption(
  p_target_account_id uuid,
  p_reward_item_id uuid,
  p_voucher_code text,
  p_actor_type text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_reward record;
  v_user record;
  v_current_points integer;
  v_redemption_id uuid;
  v_voucher text;
BEGIN
  -- 1. LOCK TARGET ACCOUNT FIRST (Global lock order: Accounts -> Reward Items)
  SELECT a.id, a.status INTO v_user
  FROM public.accounts a
  WHERE a.id = p_target_account_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Target user does not exist'; END IF;
  IF v_user.status != 'active' THEN RAISE EXCEPTION 'Redemption prohibited: target user account is %', v_user.status; END IF;

  -- 2. LOCK REWARD ITEM SECOND (Serializes inventory decrement)
  SELECT * INTO v_reward
  FROM public.reward_items
  WHERE id = p_reward_item_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Reward item not found'; END IF;
  IF NOT v_reward.is_active THEN RAISE EXCEPTION 'Reward item is currently inactive'; END IF;
  IF v_reward.stock_quantity <= 0 THEN RAISE EXCEPTION 'Reward item is out of stock'; END IF;

  -- 3. Calculate target account points balance under row lock
  SELECT COALESCE(SUM(points_change), 0) INTO v_current_points
  FROM public.user_points_ledger
  WHERE account_id = p_target_account_id;

  IF v_current_points < v_reward.points_cost THEN
    RAISE EXCEPTION 'Insufficient points: required %, available %', v_reward.points_cost, v_current_points;
  END IF;

  -- 4. Decrement inventory
  UPDATE public.reward_items
  SET stock_quantity = stock_quantity - 1
  WHERE id = p_reward_item_id;

  -- 5. Prepare voucher
  IF p_voucher_code IS NOT NULL AND length(trim(p_voucher_code)) > 0 THEN
    v_voucher := trim(p_voucher_code);
  ELSE
    v_voucher := COALESCE(v_reward.voucher_code, 'RWD') || '-' || upper(substring(md5(random()::text) from 1 for 6));
  END IF;

  -- 6. Insert redemption record
  INSERT INTO public.user_reward_redemptions (
    account_id, reward_item_id, points_spent, status, voucher_code, expires_at
  ) VALUES (
    p_target_account_id, p_reward_item_id, v_reward.points_cost, 'active', v_voucher, now() + interval '90 days'
  ) RETURNING id INTO v_redemption_id;

  -- 7. Insert ledger deduction
  INSERT INTO public.user_points_ledger (
    account_id, points_change, transaction_type, reference_type, reference_id, description
  ) VALUES (
    p_target_account_id, -v_reward.points_cost, 'rewards_shop_redemption', 'reward_redemption', v_redemption_id,
    CASE WHEN p_actor_type = 'admin' THEN 'Admin Redemption: ' ELSE 'Redeemed: ' END || v_reward.title
  );

  RETURN jsonb_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'voucher_code', v_voucher,
    'remaining_points', v_current_points - v_reward.points_cost
  );
END;
$$;

-- Customer Redemption RPC
DROP FUNCTION IF EXISTS public.redeem_reward(uuid, text);
DROP FUNCTION IF EXISTS public.redeem_reward(uuid, text, uuid);
CREATE OR REPLACE FUNCTION public.redeem_reward(
  p_reward_item_id uuid,
  p_voucher_code text DEFAULT NULL,
  p_account_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_id uuid := COALESCE(public.current_app_account_id(), p_account_id);
BEGIN
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: customer session required';
  END IF;

  IF public.current_app_account_id() IS NOT NULL AND p_account_id IS NOT NULL AND p_account_id != public.current_app_account_id() AND NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Forbidden: cannot redeem rewards on behalf of another user';
  END IF;

  RETURN public._internal_execute_reward_redemption(
    v_caller_id, p_reward_item_id, p_voucher_code, 'customer'
  );
END;
$$;

-- Admin Redemption RPC (Strictly requires admin identity)
CREATE OR REPLACE FUNCTION public.admin_redeem_reward(
  p_account_id uuid,
  p_reward_item_id uuid,
  p_voucher_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Forbidden: administrator privileges required';
  END IF;

  IF p_account_id IS NULL THEN
    RAISE EXCEPTION 'Target user ID is required';
  END IF;

  RETURN public._internal_execute_reward_redemption(
    p_account_id, p_reward_item_id, p_voucher_code, 'admin'
  );
END;
$$;

-- Canonical Order Placement Procedure
CREATE OR REPLACE FUNCTION public.place_order(
  p_account_id uuid,
  p_address_snapshot jsonb,
  p_delivery_slot text,
  p_payment_method text,
  p_delivery_fee_paise integer DEFAULT 4000,
  p_platform_fee_paise integer DEFAULT 1000,
  p_slot_fee_paise integer DEFAULT 0,
  p_device_address text DEFAULT NULL,
  p_device_lat double precision DEFAULT NULL,
  p_device_lng double precision DEFAULT NULL,
  p_dest_address text DEFAULT NULL,
  p_dest_lat double precision DEFAULT NULL,
  p_dest_lng double precision DEFAULT NULL,
  p_direct_items jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_order_id uuid;
  v_subtotal integer := 0;
  v_total integer := 0;
  v_points integer := 0;
  v_item record;
  v_prod record;
  v_cart_count integer;
BEGIN
  -- Caller must be the account placing the order (or backend authenticated service)
  IF p_account_id IS NULL OR (public.current_app_account_id() IS NOT NULL AND p_account_id != public.current_app_account_id() AND NOT public.is_app_admin()) THEN
    RAISE EXCEPTION 'Unauthorized order placement';
  END IF;

  -- Create order record
  INSERT INTO public.orders (
    account_id, subtotal_paise, delivery_fee_paise, platform_fee_paise, slot_fee_paise,
    discount_paise, total_paise, delivery_slot, address_snapshot, payment_method,
    payment_status, status, device_location_address, device_latitude, device_longitude,
    destination_address, destination_latitude, destination_longitude
  ) VALUES (
    p_account_id, 0, p_delivery_fee_paise, p_platform_fee_paise, p_slot_fee_paise,
    0, 0, p_delivery_slot, p_address_snapshot, p_payment_method,
    'pending', 'Pending', p_device_address, p_device_lat, p_device_lng,
    p_dest_address, p_dest_lat, p_dest_lng
  ) RETURNING id INTO v_order_id;

  -- Process line items: from direct payload or active cart
  IF p_direct_items IS NOT NULL AND jsonb_array_length(p_direct_items) > 0 THEN
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_direct_items) AS x(
      id uuid, product_id uuid, title text, name text, price_paise integer, price numeric, quantity integer, unit text, image_url text, image text
    ) LOOP
      SELECT * INTO v_prod FROM public.products WHERE id = COALESCE(v_item.product_id, v_item.id) FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Product % not found', COALESCE(v_item.product_id, v_item.id); END IF;
      IF v_prod.stock_quantity < v_item.quantity THEN RAISE EXCEPTION 'Insufficient stock for product %', v_prod.title; END IF;

      UPDATE public.products SET stock_quantity = stock_quantity - v_item.quantity WHERE id = v_prod.id;

      INSERT INTO public.order_items (
        order_id, product_id, title_snapshot, price_paise_snapshot, quantity, unit_snapshot, image_url_snapshot
      ) VALUES (
        v_order_id, v_prod.id, v_prod.title, v_prod.price_paise, v_item.quantity, v_prod.unit, v_prod.image_url
      );
      v_subtotal := v_subtotal + (v_prod.price_paise * v_item.quantity);
    END LOOP;
  ELSE
    SELECT count(*) INTO v_cart_count FROM public.cart WHERE account_id = p_account_id;
    IF v_cart_count = 0 THEN RAISE EXCEPTION 'Cart is empty'; END IF;

    FOR v_item IN SELECT c.product_id, c.quantity FROM public.cart c WHERE c.account_id = p_account_id LOOP
      SELECT * INTO v_prod FROM public.products WHERE id = v_item.product_id FOR UPDATE;
      IF NOT FOUND THEN RAISE EXCEPTION 'Product % not found', v_item.product_id; END IF;
      IF v_prod.stock_quantity < v_item.quantity THEN RAISE EXCEPTION 'Insufficient stock for product %', v_prod.title; END IF;

      UPDATE public.products SET stock_quantity = stock_quantity - v_item.quantity WHERE id = v_prod.id;

      INSERT INTO public.order_items (
        order_id, product_id, title_snapshot, price_paise_snapshot, quantity, unit_snapshot, image_url_snapshot
      ) VALUES (
        v_order_id, v_prod.id, v_prod.title, v_prod.price_paise, v_item.quantity, v_prod.unit, v_prod.image_url
      );
      v_subtotal := v_subtotal + (v_prod.price_paise * v_item.quantity);
    END LOOP;

    DELETE FROM public.cart WHERE account_id = p_account_id;
  END IF;

  v_total := v_subtotal + p_delivery_fee_paise + p_platform_fee_paise + p_slot_fee_paise;

  UPDATE public.orders
  SET subtotal_paise = v_subtotal,
      total_paise = v_total
  WHERE id = v_order_id;

  -- Award cashback points (1 point per 100 rupees spent)
  v_points := GREATEST(1, floor(v_total / 10000)::integer);
  INSERT INTO public.user_points_ledger (
    account_id, points_change, transaction_type, reference_type, reference_id, description
  ) VALUES (
    p_account_id, v_points, 'order_cashback', 'order', v_order_id, 'Cashback for Order #' || substring(v_order_id::text from 1 for 8)
  );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', v_order_id,
    'total_paise', v_total,
    'points_awarded', v_points
  );
END;
$$;

-- Atomic Order Cancellation
DROP FUNCTION IF EXISTS public.cancel_order(uuid);
DROP FUNCTION IF EXISTS public.cancel_order(uuid, uuid);
CREATE OR REPLACE FUNCTION public.cancel_order(
  p_order_id uuid,
  p_account_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_caller_id uuid := COALESCE(public.current_app_account_id(), p_account_id);
  v_order record;
  v_item record;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Order not found'; END IF;

  IF v_caller_id IS NOT NULL AND v_order.account_id != v_caller_id AND NOT public.is_app_admin() THEN
    RAISE EXCEPTION 'Unauthorized order cancellation';
  END IF;

  IF v_order.status != 'Pending' THEN
    RAISE EXCEPTION 'Only Pending orders can be cancelled. Current status: %', v_order.status;
  END IF;

  -- Restore stock for cancelled order items
  FOR v_item IN SELECT product_id, quantity FROM public.order_items WHERE order_id = p_order_id LOOP
    UPDATE public.products SET stock_quantity = stock_quantity + v_item.quantity WHERE id = v_item.product_id;
  END LOOP;

  UPDATE public.orders
  SET status = 'Cancelled',
      updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object('success', true, 'message', 'Order cancelled and stock restored');
END;
$$;

-- Write Audit Log RPC
CREATE OR REPLACE FUNCTION public.write_audit_log(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_metadata jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_account_id uuid := public.current_app_account_id();
  v_log_id uuid;
BEGIN
  INSERT INTO public.audit_logs (
    account_id, action, target_type, target_id, metadata, created_at
  ) VALUES (
    v_account_id, p_action, p_target_type, p_target_id, p_metadata, now()
  ) RETURNING id INTO v_log_id;

  RETURN v_log_id;
END;
$$;

-- Account Soft Deactivation Procedure
CREATE OR REPLACE FUNCTION public.deactivate_account(
  p_account_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NOT public.is_app_admin() AND p_account_id != public.current_app_account_id() THEN
    RAISE EXCEPTION 'Unauthorized to deactivate this account';
  END IF;

  UPDATE public.accounts
  SET status = 'deactivated',
      password_hash = 'DISABLED_' || gen_random_uuid(),
      updated_at = now()
  WHERE id = p_account_id;

  UPDATE public.sessions
  SET revoked_at = now()
  WHERE account_id = p_account_id AND revoked_at IS NULL;

  DELETE FROM public.otp_requests WHERE account_id = p_account_id;
  DELETE FROM public.cart WHERE account_id = p_account_id;
  DELETE FROM public.favorites WHERE account_id = p_account_id;
END;
$$;

-- Maintenance RPCs
CREATE OR REPLACE FUNCTION public.cleanup_expired_otps()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_count integer;
BEGIN
  DELETE FROM public.otp_requests WHERE expires_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.cleanup_expired_sessions()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_count integer;
BEGIN
  DELETE FROM public.sessions WHERE expires_at < now() OR revoked_at < now() - interval '30 days';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

-- Enable RLS across all 27 tables
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.otp_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.home_deals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.promotion_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_promotions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referral_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reward_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_points_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_reward_redemptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_dismissed_announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket ENABLE ROW LEVEL SECURITY;

-- Force RLS on customer and business data tables
ALTER TABLE public.products FORCE ROW LEVEL SECURITY;
ALTER TABLE public.addresses FORCE ROW LEVEL SECURITY;
ALTER TABLE public.orders FORCE ROW LEVEL SECURITY;
ALTER TABLE public.order_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cart FORCE ROW LEVEL SECURITY;
ALTER TABLE public.favorites FORCE ROW LEVEL SECURITY;
ALTER TABLE public.reviews FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_promotions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.referral_transactions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_points_ledger FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_reward_redemptions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;
ALTER TABLE public.user_dismissed_announcements FORCE ROW LEVEL SECURITY;
ALTER TABLE public.ticket FORCE ROW LEVEL SECURITY;

-- Accounts
DROP POLICY IF EXISTS p_accounts_select ON public.accounts;
CREATE POLICY p_accounts_select ON public.accounts FOR SELECT USING (id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_accounts_update ON public.accounts;
CREATE POLICY p_accounts_update ON public.accounts FOR UPDATE USING (id = public.current_app_account_id() OR public.is_app_admin()) WITH CHECK (id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_accounts_insert ON public.accounts;
CREATE POLICY p_accounts_insert ON public.accounts FOR INSERT WITH CHECK ((role = 'customer' AND status = 'active') OR public.is_app_admin());

-- Sessions
DROP POLICY IF EXISTS p_sessions_select ON public.sessions;
CREATE POLICY p_sessions_select ON public.sessions FOR SELECT USING (account_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_sessions_insert ON public.sessions;
CREATE POLICY p_sessions_insert ON public.sessions FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.accounts a WHERE a.id = account_id AND a.status = 'active'));
DROP POLICY IF EXISTS p_sessions_update ON public.sessions;
CREATE POLICY p_sessions_update ON public.sessions FOR UPDATE USING (account_id = public.current_app_account_id() OR public.is_app_admin()) WITH CHECK (true);

-- OTP Requests (Restricted to admin / backend service role; verification handled via verify_and_consume_otp SECURITY DEFINER)
DROP POLICY IF EXISTS p_otp_all ON public.otp_requests;
DROP POLICY IF EXISTS p_otp_admin ON public.otp_requests;
CREATE POLICY p_otp_admin ON public.otp_requests FOR ALL USING (public.is_app_admin());

-- Categories & Subcategories
DROP POLICY IF EXISTS p_cat_select ON public.categories;
CREATE POLICY p_cat_select ON public.categories FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_cat_admin ON public.categories;
CREATE POLICY p_cat_admin ON public.categories FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());
DROP POLICY IF EXISTS p_subcat_select ON public.subcategories;
CREATE POLICY p_subcat_select ON public.subcategories FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_subcat_admin ON public.subcategories;
CREATE POLICY p_subcat_admin ON public.subcategories FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());

-- Products
DROP POLICY IF EXISTS p_products_select ON public.products;
CREATE POLICY p_products_select ON public.products FOR SELECT USING ((is_active = true AND approval_status = 'listed') OR seller_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_products_insert ON public.products;
CREATE POLICY p_products_insert ON public.products FOR INSERT WITH CHECK (seller_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_products_update ON public.products;
CREATE POLICY p_products_update ON public.products FOR UPDATE USING (seller_id = public.current_app_account_id() OR public.is_app_admin()) WITH CHECK (public.is_app_admin() OR (seller_id = public.current_app_account_id() AND approval_status = 'pending'));

-- Addresses
DROP POLICY IF EXISTS p_addresses_all ON public.addresses;
CREATE POLICY p_addresses_all ON public.addresses FOR ALL USING (account_id = public.current_app_account_id()) WITH CHECK (account_id = public.current_app_account_id());

-- Orders & Order Items
DROP POLICY IF EXISTS p_orders_select ON public.orders;
CREATE POLICY p_orders_select ON public.orders FOR SELECT USING (account_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_orders_admin_update ON public.orders;
CREATE POLICY p_orders_admin_update ON public.orders FOR UPDATE USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());
DROP POLICY IF EXISTS p_order_items_select ON public.order_items;
CREATE POLICY p_order_items_select ON public.order_items FOR SELECT USING (EXISTS (SELECT 1 FROM public.orders o WHERE o.id = order_id AND (o.account_id = public.current_app_account_id() OR public.is_app_admin())));

-- Delivery Slots & Payment Methods
DROP POLICY IF EXISTS p_slots_select ON public.delivery_slots;
CREATE POLICY p_slots_select ON public.delivery_slots FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_slots_admin ON public.delivery_slots;
CREATE POLICY p_slots_admin ON public.delivery_slots FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());
DROP POLICY IF EXISTS p_pay_select ON public.payment_methods;
CREATE POLICY p_pay_select ON public.payment_methods FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_pay_admin ON public.payment_methods;
CREATE POLICY p_pay_admin ON public.payment_methods FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());

-- Cart & Favorites
DROP POLICY IF EXISTS p_cart_all ON public.cart;
CREATE POLICY p_cart_all ON public.cart FOR ALL USING (account_id = public.current_app_account_id()) WITH CHECK (account_id = public.current_app_account_id());
DROP POLICY IF EXISTS p_favorites_all ON public.favorites;
CREATE POLICY p_favorites_all ON public.favorites FOR ALL USING (account_id = public.current_app_account_id()) WITH CHECK (account_id = public.current_app_account_id());

-- Reviews
DROP POLICY IF EXISTS p_reviews_select ON public.reviews;
CREATE POLICY p_reviews_select ON public.reviews FOR SELECT USING (is_published = true OR account_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_reviews_manage ON public.reviews;
CREATE POLICY p_reviews_manage ON public.reviews FOR ALL USING (account_id = public.current_app_account_id() OR public.is_app_admin()) WITH CHECK (account_id = public.current_app_account_id());

-- Home Deals
DROP POLICY IF EXISTS p_deals_select ON public.home_deals;
CREATE POLICY p_deals_select ON public.home_deals FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_deals_admin ON public.home_deals;
CREATE POLICY p_deals_admin ON public.home_deals FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());

-- Promotions & Terms
DROP POLICY IF EXISTS p_promotions_select ON public.promotions;
CREATE POLICY p_promotions_select ON public.promotions FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_promotions_admin ON public.promotions;
CREATE POLICY p_promotions_admin ON public.promotions FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());
DROP POLICY IF EXISTS p_terms_select ON public.promotion_terms;
CREATE POLICY p_terms_select ON public.promotion_terms FOR SELECT USING (true);
DROP POLICY IF EXISTS p_terms_admin ON public.promotion_terms;
CREATE POLICY p_terms_admin ON public.promotion_terms FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());
DROP POLICY IF EXISTS p_upromo_all ON public.user_promotions;
CREATE POLICY p_upromo_all ON public.user_promotions FOR ALL USING (account_id = public.current_app_account_id() OR public.is_app_admin()) WITH CHECK (account_id = public.current_app_account_id() OR public.is_app_admin());

-- Referrals
DROP POLICY IF EXISTS p_referrals_select ON public.referral_transactions;
CREATE POLICY p_referrals_select ON public.referral_transactions FOR SELECT USING (referrer_account_id = public.current_app_account_id() OR referred_account_id = public.current_app_account_id() OR public.is_app_admin());

-- Rewards & Redemptions & Ledger
DROP POLICY IF EXISTS p_rewards_select ON public.reward_items;
CREATE POLICY p_rewards_select ON public.reward_items FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_rewards_admin ON public.reward_items;
CREATE POLICY p_rewards_admin ON public.reward_items FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());
DROP POLICY IF EXISTS p_redemptions_select ON public.user_reward_redemptions;
CREATE POLICY p_redemptions_select ON public.user_reward_redemptions FOR SELECT USING (account_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_ledger_select ON public.user_points_ledger;
CREATE POLICY p_ledger_select ON public.user_points_ledger FOR SELECT USING (account_id = public.current_app_account_id() OR public.is_app_admin());

-- Notifications & Announcements
DROP POLICY IF EXISTS p_notif_all ON public.notifications;
CREATE POLICY p_notif_all ON public.notifications FOR ALL USING (account_id = public.current_app_account_id() OR public.is_app_admin()) WITH CHECK (account_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_announcements_select ON public.announcements;
CREATE POLICY p_announcements_select ON public.announcements FOR SELECT USING (is_active = true OR public.is_app_admin());
DROP POLICY IF EXISTS p_announcements_admin ON public.announcements;
CREATE POLICY p_announcements_admin ON public.announcements FOR ALL USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());
DROP POLICY IF EXISTS p_dismissed_all ON public.user_dismissed_announcements;
CREATE POLICY p_dismissed_all ON public.user_dismissed_announcements FOR ALL USING (account_id = public.current_app_account_id()) WITH CHECK (account_id = public.current_app_account_id());

-- Support Tickets
DROP POLICY IF EXISTS p_ticket_select ON public.ticket;
CREATE POLICY p_ticket_select ON public.ticket FOR SELECT USING (account_id = public.current_app_account_id() OR public.is_app_admin());
DROP POLICY IF EXISTS p_ticket_insert ON public.ticket;
CREATE POLICY p_ticket_insert ON public.ticket FOR INSERT WITH CHECK (account_id = public.current_app_account_id());
DROP POLICY IF EXISTS p_ticket_admin_update ON public.ticket;
CREATE POLICY p_ticket_admin_update ON public.ticket FOR UPDATE USING (public.is_app_admin()) WITH CHECK (public.is_app_admin());

-- Audit Logs
DROP POLICY IF EXISTS p_audit_select ON public.audit_logs;
CREATE POLICY p_audit_select ON public.audit_logs FOR SELECT USING (public.is_app_admin());

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. PRIVILEGE MODEL & GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Schema-level usage (Required in PostgreSQL 15+ for all database interactions)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres') THEN
    GRANT USAGE ON SCHEMA public TO postgres;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_app') THEN
    GRANT USAGE ON SCHEMA public TO dovan_app;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_worker') THEN
    GRANT USAGE ON SCHEMA public TO dovan_worker;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_readonly') THEN
    GRANT USAGE ON SCHEMA public TO dovan_readonly;
  END IF;
END $$;

-- 2. Blanket revocation from PUBLIC (to prevent unauthenticated access bypass)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- 3. Hosting Gateway Adapter: Supabase Cloud Gateway (Active ONLY when running in Supabase environment)
-- Note: 'anon' and 'authenticated' roles are deliberately EXCLUDED and given NO privileges because
-- client devices communicate exclusively through the Dovan Next.js API server (Dovan Native Auth).
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT USAGE ON SCHEMA public TO service_role;
    GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
    GRANT ALL ON ALL ROUTINES IN SCHEMA public TO service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON ROUTINES TO service_role;
  END IF;
END $$;

-- 4. Canonical Dovan Native Role Grants (Direct PostgreSQL Architecture)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_app') THEN
    -- Accounts: Column-level least privilege (role and status excluded from insert to prevent privilege escalation)
    GRANT SELECT (id, email, username, name, phone, gender, profile_image, role, referral_code, status, last_login_at, created_at, updated_at) ON public.accounts TO dovan_app;
    GRANT INSERT (id, email, username, name, phone, gender, password_hash, referral_code) ON public.accounts TO dovan_app;
    GRANT UPDATE (username, name, phone, gender, profile_image, referral_code, last_login_at, updated_at) ON public.accounts TO dovan_app;

    GRANT SELECT (id, account_id, expires_at, revoked_at, last_active_at, created_at, user_agent, ip_address, device_name, location) ON public.sessions TO dovan_app;
    GRANT INSERT (id, account_id, token_hash, expires_at, user_agent, ip_address, device_name, location) ON public.sessions TO dovan_app;
    GRANT UPDATE (last_active_at, revoked_at) ON public.sessions TO dovan_app;

    -- OTP Requests: Restricted metadata read-only for administrators (code_hash strictly excluded).
    -- All insertions, verifications, and deletions are exclusively performed via SECURITY DEFINER functions.
    GRANT SELECT (id, account_id, email, purpose, attempt_count, max_attempts, expires_at, created_at) ON public.otp_requests TO dovan_app;

    GRANT SELECT (id, title, description, category, points_cost, tag, icon_name, image_url, stock_quantity, is_active, created_at, updated_at) ON public.reward_items TO dovan_app;
    GRANT INSERT, UPDATE (title, description, category, points_cost, tag, icon_name, image_url, stock_quantity, is_active, updated_at) ON public.reward_items TO dovan_app;

    GRANT SELECT ON public.orders TO dovan_app;
    GRANT UPDATE (status, payment_status, updated_at) ON public.orders TO dovan_app;

    GRANT SELECT ON public.order_items TO dovan_app;
    GRANT SELECT ON public.user_points_ledger TO dovan_app;
    GRANT SELECT ON public.user_reward_redemptions TO dovan_app;
    GRANT SELECT ON public.referral_transactions TO dovan_app;
    GRANT SELECT ON public.audit_logs TO dovan_app;

    GRANT SELECT, INSERT, UPDATE, DELETE ON
      public.categories,
      public.subcategories,
      public.products,
      public.addresses,
      public.delivery_slots,
      public.payment_methods,
      public.cart,
      public.favorites,
      public.reviews,
      public.home_deals,
      public.promotions,
      public.promotion_terms,
      public.user_promotions,
      public.notifications,
      public.announcements,
      public.user_dismissed_announcements,
      public.ticket
    TO dovan_app;

    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dovan_app;

    GRANT EXECUTE ON FUNCTION public.set_app_session_context(text) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.current_app_account_id() TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.current_app_user_id() TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.is_app_admin() TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.admin_update_account_role(uuid, text) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.get_account_auth_record(text) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.create_otp_request(text, text, text, uuid, integer) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.verify_and_consume_otp(text, text, text) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.redeem_reward(uuid, text, uuid) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.admin_redeem_reward(uuid, uuid, text) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.place_order(uuid, jsonb, text, text, integer, integer, integer, text, double precision, double precision, text, double precision, double precision, jsonb) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.cancel_order(uuid, uuid) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.write_audit_log(text, text, uuid, jsonb) TO dovan_app;
    GRANT EXECUTE ON FUNCTION public.deactivate_account(uuid) TO dovan_app;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_worker') THEN
    GRANT EXECUTE ON FUNCTION public.cleanup_expired_otps() TO dovan_worker;
    GRANT EXECUTE ON FUNCTION public.cleanup_expired_sessions() TO dovan_worker;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dovan_readonly') THEN
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO dovan_readonly;
    REVOKE SELECT (password_hash) ON public.accounts FROM dovan_readonly;
    REVOKE SELECT (token_hash) ON public.sessions FROM dovan_readonly;
    REVOKE SELECT (code_hash) ON public.otp_requests FROM dovan_readonly;
    REVOKE SELECT (voucher_code) ON public.reward_items FROM dovan_readonly;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. SUPABASE STORAGE BUCKETS & POLICIES
-- ─────────────────────────────────────────────────────────────────────────────

-- Safe migration for ticket attachments column and nullable account_id for guest tickets
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ticket' AND column_name = 'attachments'
  ) THEN
    ALTER TABLE public.ticket ADD COLUMN attachments jsonb NOT NULL DEFAULT '[]'::jsonb;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ticket' AND column_name = 'account_id' AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.ticket ALTER COLUMN account_id DROP NOT NULL;
  END IF;
END $$;

-- Storage bucket for customer support ticket attachments (images & files up to 25MB)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'storage') THEN
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('support-attachments', 'support-attachments', true, 26214400, NULL)
    ON CONFLICT (id) DO UPDATE SET
      public = true,
      file_size_limit = 26214400,
      allowed_mime_types = NULL;

    -- Read policy for public support attachments
    DROP POLICY IF EXISTS "Public support attachments read access" ON storage.objects;
    CREATE POLICY "Public support attachments read access"
      ON storage.objects FOR SELECT
      USING (bucket_id = 'support-attachments');

    -- Insert policy for authenticated & anonymous users
    DROP POLICY IF EXISTS "Allow support attachments upload" ON storage.objects;
    CREATE POLICY "Allow support attachments upload"
      ON storage.objects FOR INSERT
      WITH CHECK (bucket_id = 'support-attachments');
  END IF;
END $$;

-- =============================================================================
-- 35. DELIVERY PARTNERS, SHIFTS, REVIEWS, AND ASSIGNMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.delivery_partners (
  id                          uuid             PRIMARY KEY DEFAULT uuid_generate_v4(),
  account_id                  uuid             NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  full_name                   text             NOT NULL,
  phone                       text             NOT NULL,
  email                       text,
  avatar_url                  text,
  status                      text             NOT NULL DEFAULT 'offline'
                                               CHECK (status IN ('offline', 'online', 'busy', 'on_delivery')),
  vehicle_type                text             NOT NULL DEFAULT 'bike'
                                               CHECK (vehicle_type IN ('bike', 'scooter', 'bicycle', 'van')),
  vehicle_number              text,
  driving_license_no          text,
  is_verified                 boolean          NOT NULL DEFAULT true,
  rating                      real             NOT NULL DEFAULT 5.0 CHECK (rating >= 0 AND rating <= 5.0),
  total_ratings_count         integer          NOT NULL DEFAULT 0,
  completed_deliveries_count  integer          NOT NULL DEFAULT 0,
  cancelled_deliveries_count  integer          NOT NULL DEFAULT 0,
  total_earned_paise          integer          NOT NULL DEFAULT 0,
  current_latitude            double precision,
  current_longitude           double precision,
  last_location_updated_at    timestamptz,
  created_at                  timestamptz      NOT NULL DEFAULT now(),
  updated_at                  timestamptz      NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_partners_account_id ON public.delivery_partners (account_id);
CREATE INDEX IF NOT EXISTS idx_delivery_partners_status ON public.delivery_partners (status);

CREATE TABLE IF NOT EXISTS public.delivery_shifts (
  id                    uuid             PRIMARY KEY DEFAULT uuid_generate_v4(),
  delivery_partner_id   uuid             NOT NULL REFERENCES public.delivery_partners (id) ON DELETE CASCADE,
  clock_in_at           timestamptz      NOT NULL DEFAULT now(),
  clock_out_at          timestamptz,
  total_minutes         integer          NOT NULL DEFAULT 0,
  status                text             NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed')),
  deliveries_completed  integer          NOT NULL DEFAULT 0,
  earnings_paise        integer          NOT NULL DEFAULT 0,
  notes                 text,
  created_at            timestamptz      NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_shifts_partner ON public.delivery_shifts (delivery_partner_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.delivery_reviews (
  id                     uuid             PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id               uuid             NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
  customer_id            uuid             NOT NULL REFERENCES public.accounts (id) ON DELETE CASCADE,
  delivery_partner_id    uuid             NOT NULL REFERENCES public.delivery_partners (id) ON DELETE CASCADE,
  rating                 integer          NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text            text,
  delivery_speed_rating  integer          CHECK (delivery_speed_rating >= 1 AND delivery_speed_rating <= 5),
  communication_rating   integer          CHECK (communication_rating >= 1 AND communication_rating <= 5),
  created_at             timestamptz      NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_delivery_reviews_partner ON public.delivery_reviews (delivery_partner_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.delivery_assignments (
  id                    uuid             PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id              uuid             NOT NULL REFERENCES public.orders (id) ON DELETE CASCADE,
  delivery_partner_id   uuid             NOT NULL REFERENCES public.delivery_partners (id) ON DELETE CASCADE,
  assigned_by_admin_id  uuid             REFERENCES public.accounts (id) ON DELETE SET NULL,
  status                text             NOT NULL DEFAULT 'assigned'
                                         CHECK (status IN ('assigned', 'accepted', 'declined', 'arrived_store', 'picked_up', 'in_transit', 'delivered')),
  assigned_at           timestamptz      NOT NULL DEFAULT now(),
  accepted_at           timestamptz,
  declined_at           timestamptz,
  picked_up_at          timestamptz,
  delivered_at          timestamptz,
  delivery_notes        text,
  created_at            timestamptz      NOT NULL DEFAULT now(),
  updated_at            timestamptz      NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_delivery_assignments_order ON public.delivery_assignments (order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_assignments_partner ON public.delivery_assignments (delivery_partner_id, status);

ALTER TABLE public.delivery_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.delivery_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY p_delivery_partners_all ON public.delivery_partners FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY p_delivery_shifts_all ON public.delivery_shifts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY p_delivery_reviews_all ON public.delivery_reviews FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY p_delivery_assignments_all ON public.delivery_assignments FOR ALL USING (true) WITH CHECK (true);



/// AppConfig — Centralizes all environment-dependent configuration.
///
/// PRODUCTION: Replace these with values loaded from a secure secrets manager
/// or environment variables injected at build time (flutter --dart-define).
///
/// DEVELOPMENT: Set SUPABASE_URL and SUPABASE_ANON_KEY as --dart-define flags:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ... \
///               --dart-define=RESEND_API_KEY=re_xxx
///
/// The anon key is safe to use in the Flutter client — it has no special
/// privileges and is scoped to what RLS policies allow.
/// NEVER use the service_role key in any Flutter code.
class AppConfig {
  // ---------------------------------------------------------------------------
  // Backend API
  // ---------------------------------------------------------------------------
  /// The Vercel/Next.js API URL
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://dovan-five.vercel.app/api', // Default to production backend
  );

  // ---------------------------------------------------------------------------
  // Email / OTP
  // ---------------------------------------------------------------------------
  /// Resend.com API key for sending OTP emails.
  /// Set to empty string to use debug-console-only mode (development).
  /// Override with: --dart-define=RESEND_API_KEY=re_xxx
  static const String resendApiKey = String.fromEnvironment(
    'RESEND_API_KEY',
    defaultValue: '', // Empty = debug mode (OTP printed to console only)
  );

  /// From address for OTP emails. Must be a verified Resend sender domain.
  static const String emailFrom = String.fromEnvironment(
    'EMAIL_FROM',
    defaultValue: 'noreply@dovan.com',
  );

  // ---------------------------------------------------------------------------
  // App
  // ---------------------------------------------------------------------------
  static const String appName = 'Dovan';
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // Business Rules (configurable constants)
  // ---------------------------------------------------------------------------
  /// Points awarded per Rs 10 spent (per 1000 paise)
  static const int pointsPerThousandPaise = 1;

  /// Platform fee in paise (Rs 10 = 1000 paise)
  static const int platformFeePaise = 1000;

  /// Default delivery fee in paise (Rs 40 = 4000 paise)
  static const int defaultDeliveryFeePaise = 4000;

  /// Premium slot surcharge in paise (Rs 20 = 2000 paise)
  static const int premiumSlotFeePaise = 2000;
}

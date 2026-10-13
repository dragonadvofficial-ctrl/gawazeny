/// Supabase database, storage, and project constants.
abstract final class SupabaseConstants {
  // Project Credentials
  // Can be overridden at build time via:
  // flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://npcqnrucmwzompwmvztw.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_c-wIMq0t09mTU4Uhp4lafg_zI-ZjgwL',
  );

  // Table Names
  static const String profilesTable = 'profiles';
  static const String partnerPreferencesTable = 'partner_preferences';
  static const String profilePhotosTable = 'profile_photos';
  static const String likesTable = 'likes';
  static const String matchesTable = 'matches';
  static const String blockedUsersTable = 'blocked_users';
  static const String identityVerificationsTable = 'identity_verifications';
  static const String conversationsTable = 'conversations';
  static const String messagesTable = 'messages';
  static const String subscriptionsTable = 'subscriptions';
  static const String voucherCodesTable = 'voucher_codes';
  static const String userReportsTable = 'user_reports';

  // Storage Buckets
  static const String profilePhotosBucket = 'profile-photos';
  static const String identityDocumentsBucket = 'identity-documents';

  // Database Functions / RPCs
  static const String handleNewLikeFunction = 'handle_new_like';
  static const String redeemVoucherFunction = 'redeem_voucher_code';
  static const String submitUserReportFunction = 'submit_user_report';
}

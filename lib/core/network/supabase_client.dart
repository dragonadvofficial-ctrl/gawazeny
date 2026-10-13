import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';

/// Provides the [SupabaseClient] instance across the application, with fallback for unit/widget tests.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return SupabaseClient(
      SupabaseConstants.supabaseUrl,
      SupabaseConstants.supabaseAnonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }
});

/// Stream provider for listening to authentication state changes.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  try {
    return supabase.auth.onAuthStateChange;
  } catch (_) {
    return const Stream.empty();
  }
});

/// Provider for the currently signed-in Supabase [User].
final currentUserProvider = Provider<User?>((ref) {
  // Watch auth state to trigger re-evaluations on login/logout
  try {
    ref.watch(authStateChangesProvider);
    final supabase = ref.watch(supabaseClientProvider);
    return supabase.auth.currentUser;
  } catch (_) {
    return null;
  }
});

/// Convenience provider indicating whether a user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

/// Production-ready network wrapper service for interacting with Supabase tables and storage.
class SupabaseService {
  final SupabaseClient _client;

  const SupabaseService(this._client);

  SupabaseClient get client => _client;

  // Profiles Table Reference
  SupabaseQueryBuilder get profiles =>
      _client.from(SupabaseConstants.profilesTable);

  // Partner Preferences Table Reference
  SupabaseQueryBuilder get partnerPreferences =>
      _client.from(SupabaseConstants.partnerPreferencesTable);

  // Profile Photos Table Reference
  SupabaseQueryBuilder get profilePhotos =>
      _client.from(SupabaseConstants.profilePhotosTable);

  // Likes Table Reference
  SupabaseQueryBuilder get likes => _client.from(SupabaseConstants.likesTable);

  // Matches Table Reference
  SupabaseQueryBuilder get matches =>
      _client.from(SupabaseConstants.matchesTable);

  // Blocked Users Table Reference
  SupabaseQueryBuilder get blockedUsers =>
      _client.from(SupabaseConstants.blockedUsersTable);

  // Identity Verifications Table Reference
  SupabaseQueryBuilder get identityVerifications =>
      _client.from(SupabaseConstants.identityVerificationsTable);

  // Subscriptions Table Reference
  SupabaseQueryBuilder get subscriptions =>
      _client.from(SupabaseConstants.subscriptionsTable);

  // Voucher Codes Table Reference
  SupabaseQueryBuilder get voucherCodes =>
      _client.from(SupabaseConstants.voucherCodesTable);

  // User Reports Table Reference
  SupabaseQueryBuilder get userReports =>
      _client.from(SupabaseConstants.userReportsTable);

  // Storage Buckets
  StorageFileApi get photosStorage =>
      _client.storage.from(SupabaseConstants.profilePhotosBucket);

  StorageFileApi get idDocumentsStorage =>
      _client.storage.from(SupabaseConstants.identityDocumentsBucket);

  /// Helper to get current authenticated user ID, throws if unauthenticated.
  String get requireCurrentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('يجب تسجيل الدخول لمتابعة هذا الإجراء');
    }
    return user.id;
  }
}

/// Riverpod provider for accessing [SupabaseService].
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseService(client);
});

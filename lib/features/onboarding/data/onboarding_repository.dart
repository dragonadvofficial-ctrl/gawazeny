import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../../matching/domain/partner_preferences.dart';
import '../../profile/domain/user_profile.dart';

/// Repository managing onboarding persistence: profiles, preferences, and avatar storage.
class OnboardingRepository {
  final SupabaseClient _client;

  const OnboardingRepository(this._client);

  /// Upserts user profile record into the `profiles` table.
  Future<void> saveProfile(UserProfile profile) async {
    try {
      final map = profile.toMap();
      await _client.from(SupabaseConstants.profilesTable).upsert(
            map,
            onConflict: 'id',
          );
    } catch (e) {
      debugPrint('saveProfile error: $e');
      throw 'فشل في حفظ البيانات الشخصية: $e';
    }
  }

  /// Upserts partner preferences into the `partner_preferences` table.
  Future<void> savePreferences(PartnerPreferences preferences) async {
    try {
      await _client.from(SupabaseConstants.partnerPreferencesTable).upsert(
            preferences.toMap(),
            onConflict: 'user_id',
          );
    } catch (e) {
      debugPrint('savePreferences error: $e');
      throw 'فشل في حفظ مواصفات شريك الحياة: $e';
    }
  }

  /// Fetches existing partner preferences for [userId], if any.
  Future<PartnerPreferences?> getPreferences(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.partnerPreferencesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return PartnerPreferences.fromMap(response);
    } catch (e) {
      debugPrint('getPreferences error: $e');
      return null;
    }
  }

  /// Fetches existing user profile for [userId], if any.
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromMap(response);
    } catch (e) {
      debugPrint('getProfile error: $e');
      return null;
    }
  }

  /// Fetches existing primary photo URL for [userId], if any.
  Future<String?> getPrimaryPhotoUrl(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.profilePhotosTable)
          .select('photo_url')
          .eq('user_id', userId)
          .eq('is_primary', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['photo_url'] as String?;
    } catch (e) {
      debugPrint('getPrimaryPhotoUrl error: $e');
      return null;
    }
  }

  /// Uploads avatar binary to Supabase Storage `profile-photos` and returns the public URL.
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String userId,
    required String fileExtension,
  }) async {
    try {
      // 1. Verify and refresh session if expired
      final currentSession = _client.auth.currentSession;
      if (currentSession == null || currentSession.isExpired) {
        try {
          await _client.auth.refreshSession();
        } catch (_) {}
      }

      final activeUser = _client.auth.currentUser;
      if (activeUser == null) {
        throw 'انتهت صلاحية جلسة تسجيل الدخول، يرجى إعادة تسجيل الدخول لمتابعة رفع الصورة.';
      }

      // 2. Resolve proper MIME type
      final ext = fileExtension.replaceAll('.', '').trim().toLowerCase();
      String mimeType;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      final sanitizedExtension = ext.isEmpty ? 'jpg' : ext;
      final storagePath = '$userId/primary.$sanitizedExtension';

      // 3. Upload binary to Supabase storage bucket
      await _client.storage.from(SupabaseConstants.profilePhotosBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType,
            ),
          );

      // 4. Retrieve public URL for the uploaded photo
      final publicUrl = _client.storage
          .from(SupabaseConstants.profilePhotosBucket)
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('uploadProfilePhoto error: $e');
      throw 'فشل في رفع الصورة الشخصية: $e';
    }
  }

  /// Inserts or updates the photo record in the `profile_photos` table and `profiles` table.
  Future<void> saveProfilePhotoRecord({
    required String userId,
    required String photoUrl,
  }) async {
    try {
      // 1. Remove any previous primary photo records to maintain one primary photo
      try {
        await _client
            .from(SupabaseConstants.profilePhotosTable)
            .delete()
            .eq('user_id', userId)
            .eq('is_primary', true);
      } catch (_) {}

      // 2. Insert new primary photo record
      await _client.from(SupabaseConstants.profilePhotosTable).insert({
        'user_id': userId,
        'photo_url': photoUrl,
        'is_primary': true,
      });

      // 3. Keep profiles.photo_url in sync if column exists
      try {
        await _client.from(SupabaseConstants.profilesTable).update({
          'photo_url': photoUrl,
        }).eq('id', userId);
      } catch (_) {}
    } catch (e) {
      debugPrint('saveProfilePhotoRecord error: $e');
      throw 'فشل في حفظ سجل الصورة: $e';
    }
  }

  /// Checks whether the user has completed their matrimonial profile.
  Future<bool> checkProfileCompletion(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.profilesTable)
          .select('full_name, gender, birth_date, residence_city, marital_status')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return false;
      }

      final fullName = response['full_name'] as String?;
      final gender = response['gender'] as String?;
      final birthDate = response['birth_date'] as String?;
      final city = response['residence_city'] as String?;

      return fullName != null &&
          fullName.trim().isNotEmpty &&
          gender != null &&
          birthDate != null &&
          city != null &&
          city.trim().isNotEmpty;
    } catch (_) {
      // In case of network/fetch issue, return false to enforce onboarding check
      return false;
    }
  }
}

/// Riverpod provider for [OnboardingRepository].
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return OnboardingRepository(client);
});

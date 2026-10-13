import 'dart:typed_data';
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
      await _client.from(SupabaseConstants.profilesTable).upsert(
            profile.toMap(),
            onConflict: 'id',
          );
    } catch (e) {
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
      throw 'فشل في حفظ مواصفات شريك الحياة: $e';
    }
  }

  /// Uploads avatar binary to Supabase Storage `profile-photos` and records it in `profile_photos`.
  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String userId,
    required String fileExtension,
  }) async {
    try {
      final sanitizedExtension = fileExtension.replaceAll('.', '');
      final storagePath = '$userId/primary.$sanitizedExtension';

      // Upload binary to Supabase storage bucket
      await _client.storage.from(SupabaseConstants.profilePhotosBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$sanitizedExtension',
            ),
          );

      // Retrieve public URL for the uploaded photo
      final publicUrl = _client.storage
          .from(SupabaseConstants.profilePhotosBucket)
          .getPublicUrl(storagePath);

      // Insert or update record in profile_photos table
      await _client.from(SupabaseConstants.profilePhotosTable).insert({
        'user_id': userId,
        'photo_url': publicUrl,
        'is_primary': true,
      });

      return publicUrl;
    } catch (e) {
      throw 'فشل في رفع الصورة الشخصية: $e';
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

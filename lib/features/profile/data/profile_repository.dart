import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/blocked_user_model.dart';
import '../domain/user_profile.dart';

/// Repository managing user profile data, blocked users, unblocking, and account deletion.
class ProfileRepository {
  final SupabaseService _supabase;

  const ProfileRepository(this._supabase);

  /// Fetches a user's full profile by user ID.
  Future<UserProfile?> getProfile(String userId) async {
    try {
      final data = await _supabase.client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data != null) {
        var profile = UserProfile.fromMap(Map<String, dynamic>.from(data));
        if (profile.photoUrl == null || profile.photoUrl!.isEmpty) {
          try {
            final ph = await _supabase.client
                .from(SupabaseConstants.profilePhotosTable)
                .select('photo_url')
                .eq('user_id', userId)
                .order('is_primary', ascending: false)
                .limit(1)
                .maybeSingle();
            if (ph != null && ph['photo_url'] != null) {
              profile = profile.copyWith(photoUrl: ph['photo_url'] as String);
            }
          } catch (_) {}
        }
        return profile;
      }
      return null;
    } catch (e, stack) {
      developer.log(
        'ProfileRepository.getProfile notice: $e',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Uploads profile avatar photo and associates it with user account.
  Future<String> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final sanitizedExtension = fileExtension.replaceAll('.', '').toLowerCase();
      final storagePath = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$sanitizedExtension';

      await _supabase.client.storage
          .from(SupabaseConstants.profilePhotosBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$sanitizedExtension',
            ),
          );

      final publicUrl = _supabase.client.storage
          .from(SupabaseConstants.profilePhotosBucket)
          .getPublicUrl(storagePath);

      // Update in profiles table
      try {
        await _supabase.client.from(SupabaseConstants.profilesTable).update({
          'photo_url': publicUrl,
        }).eq('id', userId);
      } catch (_) {}

      // Upsert in profile_photos table
      try {
        await _supabase.client.from(SupabaseConstants.profilePhotosTable).insert({
          'user_id': userId,
          'photo_url': publicUrl,
          'is_primary': true,
        });
      } catch (_) {}

      return publicUrl;
    } catch (e, stack) {
      developer.log('uploadProfilePhoto error: $e', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Removes current profile avatar photo and restores default avatar.
  Future<void> deleteProfilePhoto(String userId) async {
    try {
      await _supabase.client.from(SupabaseConstants.profilesTable).update({
        'photo_url': null,
      }).eq('id', userId);

      await _supabase.client
          .from(SupabaseConstants.profilePhotosTable)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      developer.log('deleteProfilePhoto notice: $e');
    }
  }

  /// Updates personal details, job, lifestyle, and bio in the `profiles` table.
  Future<void> updateProfile(UserProfile profile) async {
    try {
      await _supabase.client
          .from(SupabaseConstants.profilesTable)
          .update(profile.toMap())
          .eq('id', profile.id);
    } catch (e, stack) {
      developer.log(
        'ProfileRepository.updateProfile notice: $e',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Retrieves list of blocked users via RPC or table lookup.
  Future<List<BlockedUserModel>> getBlockedUsers(String currentUserId) async {
    try {
      // 1. Attempt RPC call
      final rpcResult = await _supabase.client.rpc('get_blocked_users');
      if (rpcResult is List) {
        return rpcResult
            .map((item) => BlockedUserModel.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e, stack) {
      developer.log(
        'get_blocked_users RPC notice (falling back to table query): $e',
        error: e,
        stackTrace: stack,
      );
    }

    // 2. Fallback query directly on blocked_users table
    try {
      final records = await _supabase.client
          .from(SupabaseConstants.blockedUsersTable)
          .select('id, blocked_id, created_at')
          .eq('blocker_id', currentUserId);

      if (records.isNotEmpty) {
        final List<BlockedUserModel> list = [];
        for (final item in records) {
          final blockedId = item['blocked_id'] as String;
          // Attempt profile query for name
          String name = 'مستخدم محظور';
          String city = 'القاهرة';
          String? photoUrl;

          try {
            final p = await _supabase.client
                .from(SupabaseConstants.profilesTable)
                .select('full_name, residence_city')
                .eq('id', blockedId)
                .maybeSingle();
            if (p != null) {
              name = p['full_name'] as String? ?? name;
              city = p['residence_city'] as String? ?? city;
            }

            final ph = await _supabase.client
                .from(SupabaseConstants.profilePhotosTable)
                .select('photo_url')
                .eq('user_id', blockedId)
                .order('is_primary', ascending: false)
                .limit(1)
                .maybeSingle();
            if (ph != null) {
              photoUrl = ph['photo_url'] as String?;
            }
          } catch (_) {}

          list.add(
            BlockedUserModel(
              id: item['id'] as String,
              blockedUserId: blockedId,
              fullName: name,
              residenceCity: city,
              photoUrl: photoUrl,
              blockedAt: DateTime.parse(item['created_at'] as String),
            ),
          );
        }
        return list;
      }
    } catch (tableError) {
      developer.log('Fallback query on blocked_users error: $tableError');
    }

    return const [];
  }

  /// Blocks a user via RPC `block_user` or fallback insert.
  Future<bool> blockUser(String targetUserId) async {
    try {
      await _supabase.client.rpc('block_user', params: {'p_target_id': targetUserId});
      return true;
    } catch (e, stack) {
      developer.log(
        'block_user RPC notice (fallback to direct table query): $e',
        error: e,
        stackTrace: stack,
      );
      try {
        final myId = _supabase.requireCurrentUserId;
        await _supabase.client.from(SupabaseConstants.blockedUsersTable).insert({
          'blocker_id': myId,
          'blocked_id': targetUserId,
        });
        return true;
      } catch (insertError) {
        developer.log('Direct block insert error: $insertError');
        return false;
      }
    }
  }

  /// Unblocks a user via RPC `unblock_user` or table deletion.
  Future<bool> unblockUser(String targetUserId) async {
    try {
      await _supabase.client.rpc('unblock_user', params: {'p_target_id': targetUserId});
      return true;
    } catch (e, stack) {
      developer.log(
        'unblock_user RPC notice (fallback to direct table delete): $e',
        error: e,
        stackTrace: stack,
      );
      try {
        final myId = _supabase.requireCurrentUserId;
        await _supabase.client
            .from(SupabaseConstants.blockedUsersTable)
            .delete()
            .eq('blocker_id', myId)
            .eq('blocked_id', targetUserId);
        return true;
      } catch (delError) {
        developer.log('Direct unblock delete error: $delError');
        return false;
      }
    }
  }

  /// Reports a user via RPC `submit_user_report` or direct insert into `user_reports`.
  Future<bool> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
    bool block = false,
  }) async {
    try {
      final res = await _supabase.client.rpc(
        SupabaseConstants.submitUserReportFunction,
        params: {
          'p_reported_user_id': reportedUserId,
          'p_reason': reason,
          'p_details': details,
          'p_block_user': block,
        },
      );
      if (res is Map && res['success'] == true) {
        return true;
      }
    } catch (e, stack) {
      developer.log(
        'submit_user_report RPC notice (fallback to direct insert): $e',
        error: e,
        stackTrace: stack,
      );
      try {
        final myId = _supabase.requireCurrentUserId;
        await _supabase.client.from(SupabaseConstants.userReportsTable).insert({
          'reporter_id': myId,
          'reported_user_id': reportedUserId,
          'reason': reason,
          'details': details,
          'status': 'PENDING',
        });
        if (block) {
          await blockUser(reportedUserId);
        }
        return true;
      } catch (insertError) {
        developer.log('Direct report insert error: $insertError');
        return false;
      }
    }
    return false;
  }

  /// Permanently deletes user account and all cascading matrimonial records.
  Future<bool> deleteAccount() async {
    try {
      await _supabase.client.rpc('delete_user_account');
    } catch (e, stack) {
      developer.log(
        'delete_user_account RPC notice: $e',
        error: e,
        stackTrace: stack,
      );
      // Fallback: delete from profiles table
      try {
        final myId = _supabase.requireCurrentUserId;
        await _supabase.client
            .from(SupabaseConstants.profilesTable)
            .delete()
            .eq('id', myId);
      } catch (deleteError) {
        developer.log('Fallback delete error: $deleteError');
      }
    }

    // Terminate auth session
    try {
      await _supabase.client.auth.signOut();
      return true;
    } catch (signOutError) {
      developer.log('signOut notice: $signOutError');
      return true;
    }
  }
}

/// Riverpod provider for accessing [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return ProfileRepository(supabase);
});

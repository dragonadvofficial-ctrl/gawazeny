import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/match_model.dart';

/// Data repository for managing likes, mutual matches, and unmatching.
class LikesMatchesRepository {
  final SupabaseClient _client;

  LikesMatchesRepository(this._client);

  /// Current authenticated user ID.
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Sends a serious like to [toUserId].
  /// Returns [LikeResult] indicating whether this triggered a mutual matrimonial match.
  Future<LikeResult> sendLike(
    String toUserId, {
    UserProfile? candidateProfile,
    String? candidatePhotoUrl,
  }) async {
    final fromUserId = _currentUserId;
    if (fromUserId == null) {
      throw 'يجب تسجيل الدخول لإرسال الإعجاب';
    }

    try {
      // 1. Attempt executing atomic RPC
      final response = await _client.rpc(
        'send_like_and_check_match',
        params: {'p_to_user_id': toUserId},
      );

      if (response != null) {
        final map = Map<String, dynamic>.from(response as Map);
        return LikeResult.fromRpcJson(
          map,
          fallbackProfile: candidateProfile,
        );
      }
    } catch (e, stack) {
      developer.log(
        'Notice: RPC send_like_and_check_match failed. Using fallback client logic: $e',
        error: e,
        stackTrace: stack,
      );
    }

    // 2. Client-side fallback implementation
    try {
      // Record like
      await _client.from(SupabaseConstants.likesTable).upsert(
        {
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
        },
        onConflict: 'from_user_id,to_user_id',
      );

      // Check if reciprocal like existed
      final reciprocalCheck = await _client
          .from(SupabaseConstants.likesTable)
          .select('id')
          .eq('from_user_id', toUserId)
          .eq('to_user_id', fromUserId)
          .maybeSingle();

      if (reciprocalCheck != null) {
        // Mutual like confirmed! Query or upsert match
        final userOne = fromUserId.compareTo(toUserId) < 0 ? fromUserId : toUserId;
        final userTwo = fromUserId.compareTo(toUserId) < 0 ? toUserId : fromUserId;

        final matchRecord = await _client
            .from(SupabaseConstants.matchesTable)
            .upsert(
              {
                'user_one': userOne,
                'user_two': userTwo,
                'is_active': true,
              },
              onConflict: 'user_one,user_two',
            )
            .select('id')
            .maybeSingle();

        final matchId = matchRecord != null ? matchRecord['id'] as String? : null;

        return LikeResult(
          isMatch: true,
          matchId: matchId,
          partnerName: candidateProfile?.fullName ?? 'شريك متوافق',
          partnerPhotoUrl: candidatePhotoUrl,
          partnerProfile: candidateProfile,
        );
      }

      return LikeResult(
        isMatch: false,
        partnerProfile: candidateProfile,
      );
    } catch (e) {
      developer.log('Error in fallback sendLike: $e');
      throw 'تعذر إرسال الإعجاب، يرجى التحقق من اتصالك بالإنترنت';
    }
  }

  /// Fetches confirmed mutual matches for the user.
  Future<List<MutualMatch>> fetchMutualMatches({String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return [];

    try {
      // 1. Try RPC get_user_mutual_matches
      final response = await _client.rpc(
        'get_user_mutual_matches',
        params: {'p_user_id': uid},
      );

      if (response is List) {
        return response
            .map((item) => MutualMatch.fromRpcMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e, stack) {
      developer.log(
        'Notice: RPC get_user_mutual_matches error. Fallback to direct query: $e',
        error: e,
        stackTrace: stack,
      );
    }

    // 2. Direct query fallback
    try {
      final matchesData = await _client
          .from(SupabaseConstants.matchesTable)
          .select()
          .or('user_one.eq.$uid,user_two.eq.$uid')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final List<MutualMatch> results = [];

      for (final matchMap in matchesData as List) {
        final match = MatchRecord.fromMap(Map<String, dynamic>.from(matchMap as Map));
        final partnerId = match.getPartnerId(uid);

        // Fetch partner profile
        final profileData = await _client
            .from(SupabaseConstants.profilesTable)
            .select()
            .eq('id', partnerId)
            .maybeSingle();

        if (profileData != null) {
          final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileData));

          // Fetch partner primary photo
          final photoData = await _client
              .from(SupabaseConstants.profilePhotosTable)
              .select('photo_url')
              .eq('user_id', partnerId)
              .order('is_primary', ascending: false)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          final photoUrl = photoData != null ? photoData['photo_url'] as String? : null;

          results.add(
            MutualMatch(
              matchId: match.id,
              partnerProfile: profile,
              primaryPhotoUrl: photoUrl,
              matchedAt: match.createdAt,
              isActive: match.isActive,
            ),
          );
        }
      }

      return results;
    } catch (e) {
      developer.log('Error in direct fetchMutualMatches: $e');
      return [];
    }
  }

  /// Fetches candidates who liked the user (pending response).
  Future<List<ReceivedLike>> fetchReceivedLikes({String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return [];

    try {
      // 1. Try RPC get_received_likes
      final response = await _client.rpc(
        'get_received_likes',
        params: {'p_user_id': uid},
      );

      if (response is List) {
        return response
            .map((item) => ReceivedLike.fromRpcMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e, stack) {
      developer.log(
        'Notice: RPC get_received_likes error. Fallback to direct query: $e',
        error: e,
        stackTrace: stack,
      );
    }

    // 2. Direct query fallback
    try {
      final likesData = await _client
          .from(SupabaseConstants.likesTable)
          .select()
          .eq('to_user_id', uid)
          .order('created_at', ascending: false);

      final List<ReceivedLike> results = [];

      for (final likeMap in likesData as List) {
        final like = LikeRecord.fromMap(Map<String, dynamic>.from(likeMap as Map));

        // Ensure this user is not already matched
        final userOne = uid.compareTo(like.fromUserId) < 0 ? uid : like.fromUserId;
        final userTwo = uid.compareTo(like.fromUserId) < 0 ? like.fromUserId : uid;

        final existingMatch = await _client
            .from(SupabaseConstants.matchesTable)
            .select('id')
            .eq('user_one', userOne)
            .eq('user_two', userTwo)
            .eq('is_active', true)
            .maybeSingle();

        if (existingMatch == null) {
          final profileData = await _client
              .from(SupabaseConstants.profilesTable)
              .select()
              .eq('id', like.fromUserId)
              .maybeSingle();

          if (profileData != null) {
            final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileData));

            final photoData = await _client
                .from(SupabaseConstants.profilePhotosTable)
                .select('photo_url')
                .eq('user_id', like.fromUserId)
                .order('is_primary', ascending: false)
                .limit(1)
                .maybeSingle();

            final photoUrl = photoData != null ? photoData['photo_url'] as String? : null;

            results.add(
              ReceivedLike(
                likeId: like.id,
                senderProfile: profile,
                primaryPhotoUrl: photoUrl,
                likedAt: like.createdAt,
              ),
            );
          }
        }
      }

      return results;
    } catch (e) {
      developer.log('Error in direct fetchReceivedLikes: $e');
      return [];
    }
  }

  /// Fetches candidates the user sent a like to (awaiting response).
  Future<List<SentLike>> fetchSentLikes({String? userId}) async {
    final uid = userId ?? _currentUserId;
    if (uid == null) return [];

    try {
      // 1. Try RPC get_sent_likes
      final response = await _client.rpc(
        'get_sent_likes',
        params: {'p_user_id': uid},
      );

      if (response is List) {
        return response
            .map((item) => SentLike.fromRpcMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }
    } catch (e, stack) {
      developer.log(
        'Notice: RPC get_sent_likes error. Fallback to direct query: $e',
        error: e,
        stackTrace: stack,
      );
    }

    // 2. Direct query fallback
    try {
      final likesData = await _client
          .from(SupabaseConstants.likesTable)
          .select()
          .eq('from_user_id', uid)
          .order('created_at', ascending: false);

      final List<SentLike> results = [];

      for (final likeMap in likesData as List) {
        final like = LikeRecord.fromMap(Map<String, dynamic>.from(likeMap as Map));

        final userOne = uid.compareTo(like.toUserId) < 0 ? uid : like.toUserId;
        final userTwo = uid.compareTo(like.toUserId) < 0 ? like.toUserId : uid;

        final existingMatch = await _client
            .from(SupabaseConstants.matchesTable)
            .select('id')
            .eq('user_one', userOne)
            .eq('user_two', userTwo)
            .eq('is_active', true)
            .maybeSingle();

        if (existingMatch == null) {
          final profileData = await _client
              .from(SupabaseConstants.profilesTable)
              .select()
              .eq('id', like.toUserId)
              .maybeSingle();

          if (profileData != null) {
            final profile = UserProfile.fromMap(Map<String, dynamic>.from(profileData));

            final photoData = await _client
                .from(SupabaseConstants.profilePhotosTable)
                .select('photo_url')
                .eq('user_id', like.toUserId)
                .order('is_primary', ascending: false)
                .limit(1)
                .maybeSingle();

            final photoUrl = photoData != null ? photoData['photo_url'] as String? : null;

            results.add(
              SentLike(
                likeId: like.id,
                targetProfile: profile,
                primaryPhotoUrl: photoUrl,
                likedAt: like.createdAt,
              ),
            );
          }
        }
      }

      return results;
    } catch (e) {
      developer.log('Error in direct fetchSentLikes: $e');
      return [];
    }
  }

  /// Cancels / Revokes a sent like.
  Future<void> cancelLike(String toUserId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _client
          .from(SupabaseConstants.likesTable)
          .delete()
          .eq('from_user_id', uid)
          .eq('to_user_id', toUserId);
    } catch (e) {
      developer.log('Error cancelling like: $e');
      throw 'تعذر إلغاء الإعجاب، يرجى المحاولة لاحقاً';
    }
  }

  /// Deactivates a mutual match (Unmatch).
  Future<void> unmatch(String matchId) async {
    try {
      await _client
          .from(SupabaseConstants.matchesTable)
          .update({'is_active': false})
          .eq('id', matchId);
    } catch (e) {
      developer.log('Error unmatching: $e');
      throw 'تعذر إنهاء التوافق، يرجى المحاولة لاحقاً';
    }
  }
}

/// Riverpod provider for [LikesMatchesRepository].
final likesMatchesRepositoryProvider = Provider<LikesMatchesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return LikesMatchesRepository(client);
});

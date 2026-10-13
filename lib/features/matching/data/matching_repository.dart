import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/matching_filters.dart';
import '../domain/partner_preferences.dart';
import '../domain/scored_profile.dart';

/// Repository responsible for executing smart recommendations, search filters, likes, and session passes.
class MatchingRepository {
  final SupabaseClient _client;

  // In-memory set of profiles passed during the current app session
  final Set<String> _sessionPassedUserIds = {};

  MatchingRepository(this._client);

  /// Records a skip/dislike in the current session so the profile is not shown again.
  void recordPass(String targetUserId) {
    _sessionPassedUserIds.add(targetUserId);
  }

  /// Inserts a like record in Supabase (which triggers automatic mutual match creation).
  Future<void> recordLike({
    required String fromUserId,
    required String toUserId,
  }) async {
    try {
      await _client.from(SupabaseConstants.likesTable).insert({
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
      });
    } catch (e) {
      developer.log('Error recording like: $e');
      throw 'فشل في إرسال الإعجاب، يرجى المحاولة لاحقاً';
    }
  }

  /// Fetches candidate profiles prioritized by the 3-Tier Recommendation Engine.
  Future<List<ScoredProfile>> getRecommendedProfiles({
    required String currentUserId,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      // 1. Attempt executing the optimized PostgreSQL RPC
      final rpcResponse = await _client.rpc(
        'get_smart_matches',
        params: {
          'current_user_id': currentUserId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (rpcResponse is List) {
        final results = rpcResponse
            .map((item) =>
                ScoredProfile.fromMap(Map<String, dynamic>.from(item as Map)))
            .where((p) => !_sessionPassedUserIds.contains(p.id))
            .toList();

        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (error, stack) {
      developer.log(
        'Notice: RPC get_smart_matches unavailable or error. Engaging Dart engine fallback: $error',
        error: error,
        stackTrace: stack,
      );
    }

    // 2. Resilient Client-Side Fallback Engine
    return _fetchFallbackCandidates(
      currentUserId: currentUserId,
      limit: limit,
      offset: offset,
    );
  }

  /// Searches and filters candidate profiles according to matrimonial criteria.
  Future<List<ScoredProfile>> searchProfiles({
    required String currentUserId,
    required MatchingFilters filters,
  }) async {
    final allRecommendations = await getRecommendedProfiles(
      currentUserId: currentUserId,
      limit: 100,
    );

    return allRecommendations
        .where((scored) => filters.matchesProfile(scored.profile))
        .toList();
  }

  /// Resilient pure client fallback algorithm executing Tier-1 filtering and Tier-2 scoring.
  Future<List<ScoredProfile>> _fetchFallbackCandidates({
    required String currentUserId,
    required int limit,
    required int offset,
  }) async {
    try {
      // Fetch caller's profile
      final myProfileData = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', currentUserId)
          .maybeSingle();

      if (myProfileData == null) {
        return [];
      }
      final myProfile = UserProfile.fromMap(myProfileData);
      final targetGender = myProfile.gender == GenderType.male
          ? GenderType.female
          : GenderType.male;

      // Fetch partner preferences
      PartnerPreferences? preferences;
      try {
        final prefData = await _client
            .from(SupabaseConstants.partnerPreferencesTable)
            .select()
            .eq('user_id', currentUserId)
            .maybeSingle();
        if (prefData != null) {
          preferences = PartnerPreferences.fromMap(prefData);
        }
      } catch (_) {}

      // Fetch existing likes sent by current user
      final likesResponse = await _client
          .from(SupabaseConstants.likesTable)
          .select('to_user_id')
          .eq('from_user_id', currentUserId);
      final likedUserIds = (likesResponse as List)
          .map((e) => e['to_user_id'] as String)
          .toSet();

      // Fetch candidate profiles of opposite gender
      final profilesResponse = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('gender', targetGender.toDbValue())
          .neq('id', currentUserId)
          .limit(limit)
          .range(offset, offset + limit - 1);

      final List<ScoredProfile> scoredList = [];

      for (final raw in profilesResponse as List) {
        final profile = UserProfile.fromMap(Map<String, dynamic>.from(raw));

        // Tier 1: Exclude already liked or passed in session
        if (likedUserIds.contains(profile.id) ||
            _sessionPassedUserIds.contains(profile.id)) {
          continue;
        }

        // Fetch primary photo
        String? photoUrl;
        try {
          final photoData = await _client
              .from(SupabaseConstants.profilePhotosTable)
              .select('photo_url')
              .eq('user_id', profile.id)
              .order('is_primary', ascending: false)
              .limit(1)
              .maybeSingle();
          photoUrl = photoData?['photo_url'] as String?;
        } catch (_) {}

        // Tier 2: Compatibility Scoring (50% to 99%)
        final score = _calculateCompatibility(
          user: myProfile,
          target: profile,
          preferences: preferences,
        );

        scoredList.add(
          ScoredProfile(
            profile: profile,
            compatibilityScore: score,
            primaryPhotoUrl: photoUrl,
          ),
        );
      }

      // Tier 3: Ranking
      scoredList.sort((a, b) {
        final scoreCompare =
            b.compatibilityScore.compareTo(a.compatibilityScore);
        if (scoreCompare != 0) return scoreCompare;
        return (b.isVerified ? 1 : 0).compareTo(a.isVerified ? 1 : 0);
      });

      return scoredList;
    } catch (e) {
      developer.log('Error executing fallback matching query: $e');
      return [];
    }
  }

  /// Calculates dynamic compatibility score between two profiles according to platform rules.
  int _calculateCompatibility({
    required UserProfile user,
    required UserProfile target,
    PartnerPreferences? preferences,
  }) {
    int score = 50; // Baseline 50%

    final minAge = preferences?.minAge ?? 18;
    final maxAge = preferences?.maxAge ?? 60;
    final acceptableStatuses = preferences?.acceptableMaritalStatuses ?? [];
    final acceptableCities = preferences?.acceptableCities ?? [];
    final mustPray = preferences?.mustPray ?? false;
    final acceptsSmokers = preferences?.acceptsSmokers ?? false;

    // Age Fit (+20%)
    final targetAge = target.age ?? (DateTime.now().year - target.birthDate.year);
    if (targetAge >= minAge && targetAge <= maxAge) {
      score += 20;
    }

    // City Match (+20%)
    if (target.residenceCity == user.residenceCity ||
        acceptableCities.contains(target.residenceCity)) {
      score += 20;
    }

    // Marital Status Fit (+20%)
    if (acceptableStatuses.isEmpty ||
        acceptableStatuses.contains(target.maritalStatus)) {
      score += 20;
    }

    // Prayer Commitment Alignment (+15%)
    if (!mustPray || (target.prays ?? '').contains('محافظ')) {
      score += 15;
    }

    // Smoking Tolerance Alignment (+15%)
    if (acceptsSmokers || !target.smoker) {
      score += 15;
    }

    // Verified Account Bonus (+10%)
    if (target.verificationStatus == VerificationStatusType.verified) {
      score += 10;
    }

    return score.clamp(50, 99);
  }
}

/// Riverpod provider for [MatchingRepository].
final matchingRepositoryProvider = Provider<MatchingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MatchingRepository(client);
});

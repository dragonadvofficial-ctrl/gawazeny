import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/matching_filters.dart';
import '../domain/partner_preferences.dart';
import '../domain/scored_profile.dart';

/// Repository responsible for executing smart recommendations, member discovery, search filters, likes, and session passes.
class MatchingRepository {
  final SupabaseClient _client;

  // In-memory set of profiles passed during the current app session (for swipe feed)
  final Set<String> _sessionPassedUserIds = {};

  MatchingRepository(this._client);

  /// Records a skip/dislike in the current session so the profile is not shown again in the swipe feed.
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

  /// Fetches candidate profiles prioritized by the 3-Tier Recommendation Engine (Swipe Feed).
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

  /// Discovers all eligible registered members according to matrimonial rules,
  /// supporting custom filters, optional same-gender browsing (with marriage compatibility suppressed),
  /// and without any compulsory minimum compatibility threshold.
  Future<List<ScoredProfile>> discoverMembers({
    required String currentUserId,
    required MatchingFilters filters,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      String? genderFilter;
      if (filters.showAllGenders) {
        genderFilter = 'ALL';
      } else if (filters.targetGender != null) {
        genderFilter = filters.targetGender!.toDbValue();
      }

      final rpcResponse = await _client.rpc(
        'discover_members',
        params: {
          'p_current_user_id': currentUserId,
          'p_gender_filter': genderFilter,
          'p_search_query': filters.searchQuery.trim().isEmpty
              ? null
              : filters.searchQuery.trim(),
          'p_min_age': (filters.minAge > 18 || filters.maxAge < 60)
              ? filters.minAge
              : null,
          'p_max_age': (filters.minAge > 18 || filters.maxAge < 60)
              ? filters.maxAge
              : null,
          'p_cities': filters.selectedCities.isEmpty
              ? null
              : filters.selectedCities,
          'p_marital_statuses': filters.selectedMaritalStatuses.isEmpty
              ? null
              : filters.selectedMaritalStatuses
                  .map((s) => s.toDbValue())
                  .toList(),
          'p_education_level': (filters.educationLevel != null &&
                  filters.educationLevel!.isNotEmpty)
              ? filters.educationLevel
              : null,
          'p_must_pray': filters.mustPray ? true : null,
          'p_non_smoker_only': filters.nonSmokerOnly ? true : null,
          'p_verified_only': filters.verifiedOnly ? true : null,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (rpcResponse is List) {
        final results = rpcResponse
            .map((item) =>
                ScoredProfile.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
        return results;
      }
    } catch (error, stack) {
      developer.log(
        'Notice: discover_members RPC unavailable. Engaging robust Dart query fallback: $error',
        error: error,
        stackTrace: stack,
      );
    }

    // 2. Resilient Pure Dart Fallback with direct Supabase PostgREST queries
    return _fetchDiscoverFallback(
      currentUserId: currentUserId,
      filters: filters,
      limit: limit,
      offset: offset,
    );
  }

  /// Searches and filters candidate profiles.
  Future<List<ScoredProfile>> searchProfiles({
    required String currentUserId,
    required MatchingFilters filters,
  }) async {
    return discoverMembers(
      currentUserId: currentUserId,
      filters: filters,
    );
  }

  /// Fallback engine for member discovery querying `profiles` table directly.
  Future<List<ScoredProfile>> _fetchDiscoverFallback({
    required String currentUserId,
    required MatchingFilters filters,
    required int limit,
    required int offset,
  }) async {
    try {
      // 1. Fetch caller's profile
      final myProfileData = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', currentUserId)
          .maybeSingle();

      if (myProfileData == null) {
        return [];
      }
      final myProfile = UserProfile.fromMap(myProfileData);

      // 2. Determine target gender
      final GenderType? requestedGender = filters.showAllGenders
          ? null
          : (filters.targetGender ??
              (myProfile.gender == GenderType.male
                  ? GenderType.female
                  : GenderType.male));

      // 3. Fetch partner preferences if configured
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

      // 4. Fetch blocked users (mutual exclusion)
      final Set<String> blockedUserIds = {};
      try {
        final blockedData = await _client
            .from(SupabaseConstants.blockedUsersTable)
            .select('blocker_id, blocked_id')
            .or('blocker_id.eq.$currentUserId,blocked_id.eq.$currentUserId');
        for (final item in blockedData as List) {
          final blocker = item['blocker_id'] as String;
          final blocked = item['blocked_id'] as String;
          blockedUserIds.add(blocker == currentUserId ? blocked : blocker);
        }
      } catch (_) {}

      // 5. Fetch likes sent by current user
      final Set<String> likedUserIds = {};
      try {
        final likesData = await _client
            .from(SupabaseConstants.likesTable)
            .select('to_user_id')
            .eq('from_user_id', currentUserId);
        for (final item in likesData as List) {
          likedUserIds.add(item['to_user_id'] as String);
        }
      } catch (_) {}

      // 6. Fetch active matches involving current user
      final Set<String> matchedPartnerIds = {};
      try {
        final matchesData = await _client
            .from(SupabaseConstants.matchesTable)
            .select('user_one, user_two')
            .eq('is_active', true)
            .or('user_one.eq.$currentUserId,user_two.eq.$currentUserId');
        for (final item in matchesData as List) {
          final u1 = item['user_one'] as String;
          final u2 = item['user_two'] as String;
          matchedPartnerIds.add(u1 == currentUserId ? u2 : u1);
        }
      } catch (_) {}

      // 7. Query candidate profiles
      var query = _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .neq('id', currentUserId);

      if (requestedGender != null) {
        query = query.eq('gender', requestedGender.toDbValue());
      }

      final profilesResponse = await query
          .range(offset, offset + limit - 1);

      final List<ScoredProfile> candidates = [];

      for (final raw in profilesResponse as List) {
        final profile = UserProfile.fromMap(Map<String, dynamic>.from(raw));

        // Exclude blocked accounts
        if (blockedUserIds.contains(profile.id)) {
          continue;
        }

        // Apply filter criteria
        if (!filters.matchesProfile(profile, currentUserGender: myProfile.gender)) {
          continue;
        }

        // Fetch primary photo
        String? photoUrl = profile.photoUrl;
        if (photoUrl == null || photoUrl.isEmpty) {
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
        }

        // Calculate compatibility score
        final score = calculateCompatibility(
          user: myProfile,
          target: profile,
          preferences: preferences,
        );

        candidates.add(
          ScoredProfile(
            profile: profile,
            compatibilityScore: score,
            primaryPhotoUrl: photoUrl,
            isLiked: likedUserIds.contains(profile.id),
            isMatched: matchedPartnerIds.contains(profile.id),
          ),
        );
      }

      // Sort results
      _sortCandidates(candidates, filters.sortBy);

      return candidates;
    } catch (e) {
      developer.log('Error executing fallback discover query: $e');
      return [];
    }
  }

  /// Resilient fallback for swipe feed recommendations.
  Future<List<ScoredProfile>> _fetchFallbackCandidates({
    required String currentUserId,
    required int limit,
    required int offset,
  }) async {
    try {
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

      final likesResponse = await _client
          .from(SupabaseConstants.likesTable)
          .select('to_user_id')
          .eq('from_user_id', currentUserId);
      final likedUserIds = (likesResponse as List)
          .map((e) => e['to_user_id'] as String)
          .toSet();

      final profilesResponse = await _client
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('gender', targetGender.toDbValue())
          .neq('id', currentUserId)
          .range(offset, offset + limit - 1);

      final List<ScoredProfile> scoredList = [];

      for (final raw in profilesResponse as List) {
        final profile = UserProfile.fromMap(Map<String, dynamic>.from(raw));

        if (likedUserIds.contains(profile.id) ||
            _sessionPassedUserIds.contains(profile.id)) {
          continue;
        }

        String? photoUrl = profile.photoUrl;
        if (photoUrl == null || photoUrl.isEmpty) {
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
        }

        final score = calculateCompatibility(
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

      scoredList.sort((a, b) {
        final scoreA = a.compatibilityScore ?? -1;
        final scoreB = b.compatibilityScore ?? -1;
        final scoreCompare = scoreB.compareTo(scoreA);
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
  /// Returns `null` if both profiles are of the same gender (browsing only, no marriage compatibility score).
  int? calculateCompatibility({
    required UserProfile user,
    required UserProfile target,
    PartnerPreferences? preferences,
  }) {
    // Suppress marriage compatibility score when accounts are same gender
    if (user.gender == target.gender) {
      return null;
    }

    int score = 0; // Natural base points without artificial 50% floor

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
    final targetPray = (target.prays ?? '').toLowerCase();
    final praysRegularly = targetPray.contains('محافظ') ||
        targetPray.contains('دائماً') ||
        targetPray.contains('وقتها') ||
        targetPray.contains('مسجد') ||
        targetPray.contains('معظم');
    if (!mustPray || praysRegularly) {
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

    // Return realistic score clamped between 10% and 99%
    return score.clamp(10, 99);
  }

  void _sortCandidates(List<ScoredProfile> list, String sortBy) {
    switch (sortBy) {
      case 'newest':
        list.sort((a, b) => b.profile.createdAt.compareTo(a.profile.createdAt));
        break;
      case 'verified':
        list.sort((a, b) {
          final vCompare = (b.isVerified ? 1 : 0).compareTo(a.isVerified ? 1 : 0);
          if (vCompare != 0) return vCompare;
          final scoreA = a.compatibilityScore ?? -1;
          final scoreB = b.compatibilityScore ?? -1;
          return scoreB.compareTo(scoreA);
        });
        break;
      case 'compatibility':
      default:
        list.sort((a, b) {
          final scoreA = a.compatibilityScore ?? -1;
          final scoreB = b.compatibilityScore ?? -1;
          final scoreCompare = scoreB.compareTo(scoreA);
          if (scoreCompare != 0) return scoreCompare;
          final vCompare = (b.isVerified ? 1 : 0).compareTo(a.isVerified ? 1 : 0);
          if (vCompare != 0) return vCompare;
          return b.profile.createdAt.compareTo(a.profile.createdAt);
        });
        break;
    }
  }
}

/// Riverpod provider for [MatchingRepository].
final matchingRepositoryProvider = Provider<MatchingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MatchingRepository(client);
});

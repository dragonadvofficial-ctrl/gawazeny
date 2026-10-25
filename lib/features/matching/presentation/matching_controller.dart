import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../../likes_matches/data/likes_matches_repository.dart';
import '../../likes_matches/domain/match_model.dart';
import '../../profile/domain/user_profile.dart';
import '../data/matching_repository.dart';
import '../domain/matching_filters.dart';
import '../domain/scored_profile.dart';

/// State object representing the discovery directory, swipe feed, and active search filters.
class MatchingState {
  final List<ScoredProfile> profiles; // Swipe stack candidates
  final List<ScoredProfile> discoverMembers; // All registered members for discovery directory
  final int currentIndex;
  final bool isLoading;
  final bool isDiscoverLoading;
  final MatchingFilters filters;
  final String? errorMessage;
  final int selectedTab; // 0: Discover Members, 1: Smart Match (Cards)

  const MatchingState({
    this.profiles = const [],
    this.discoverMembers = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isDiscoverLoading = false,
    this.filters = const MatchingFilters(),
    this.errorMessage,
    this.selectedTab = 0, // Default to Discover Members so registered users are immediately visible
  });

  /// The active profile displayed on the top card in Swipe view.
  ScoredProfile? get currentCandidate =>
      (currentIndex < profiles.length) ? profiles[currentIndex] : null;

  /// Whether there are more candidates remaining in the swipe feed.
  bool get hasMoreCandidates => currentIndex < profiles.length;

  /// Number of candidates remaining in the swipe stack.
  int get remainingCount => (profiles.length - currentIndex).clamp(0, 999);

  MatchingState copyWith({
    List<ScoredProfile>? profiles,
    List<ScoredProfile>? discoverMembers,
    int? currentIndex,
    bool? isLoading,
    bool? isDiscoverLoading,
    MatchingFilters? filters,
    String? errorMessage,
    int? selectedTab,
  }) {
    return MatchingState(
      profiles: profiles ?? this.profiles,
      discoverMembers: discoverMembers ?? this.discoverMembers,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isDiscoverLoading: isDiscoverLoading ?? this.isDiscoverLoading,
      filters: filters ?? this.filters,
      errorMessage: errorMessage,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

/// StateNotifier controlling discovery feed interactions, swipes, directory searches, and member filters.
class MatchingController extends StateNotifier<MatchingState> {
  final MatchingRepository _repository;
  final Ref _ref;

  MatchingController(this._repository, this._ref)
      : super(const MatchingState()) {
    init();
  }

  String? get _currentUserId => _ref.read(currentUserProvider)?.id;

  /// Initializes both member discovery and smart recommendations.
  Future<void> init() async {
    await Future.wait([
      loadDiscoverMembers(),
      loadRecommendations(),
    ]);
  }

  /// Switches active tab: 0 = Discover Members, 1 = Smart Match cards.
  void switchTab(int index) {
    if (state.selectedTab != index) {
      state = state.copyWith(selectedTab: index);
    }
  }

  /// Loads all eligible registered members for the Discover Members section.
  Future<void> loadDiscoverMembers() async {
    if (kPreviewMode) {
      final filtered = _filterPreviewCandidates(state.filters);
      state = state.copyWith(
        discoverMembers: filtered,
        isDiscoverLoading: false,
        errorMessage: null,
      );
      return;
    }

    final userId = _currentUserId;
    if (userId == null) {
      state = state.copyWith(isDiscoverLoading: false, discoverMembers: []);
      return;
    }

    state = state.copyWith(isDiscoverLoading: true, errorMessage: null);

    try {
      final members = await _repository.discoverMembers(
        currentUserId: userId,
        filters: state.filters,
      );

      state = state.copyWith(
        discoverMembers: members,
        isDiscoverLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isDiscoverLoading: false,
        errorMessage: 'تعذر تحميل قائمة الأعضاء المسجلين: $e',
      );
    }
  }

  /// Loads recommended profiles based on the 3-Tier Recommendation Engine (Swipe Feed).
  Future<void> loadRecommendations() async {
    if (kPreviewMode) {
      final filtered = _filterPreviewCandidates(state.filters)
          .where((p) => p.profile.gender == GenderType.female)
          .toList();
      state = state.copyWith(
        profiles: filtered,
        currentIndex: 0,
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    final userId = _currentUserId;
    if (userId == null) {
      state = state.copyWith(isLoading: false, profiles: []);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final profiles = await _repository.getRecommendedProfiles(
        currentUserId: userId,
      );

      state = state.copyWith(
        profiles: profiles,
        currentIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل الترشيحات: $e',
      );
    }
  }

  /// Refreshes both sections.
  Future<void> refreshAll() async {
    await init();
  }

  /// Handles Skip / Dislike action (Swipe Left).
  void swipeLeft() {
    final candidate = state.currentCandidate;
    if (candidate != null) {
      if (!kPreviewMode) {
        _repository.recordPass(candidate.id);
      }
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// Handles Serious Like action (Swipe Right or direct Like button).
  Future<LikeResult?> swipeRight() async {
    final candidate = state.currentCandidate;
    if (candidate == null) return null;
    return sendLikeForCandidate(candidate, advanceSwipeStack: true);
  }

  /// Sends a like for a specific candidate card (usable from both Discover list and swipe card).
  Future<LikeResult?> sendLikeForCandidate(
    ScoredProfile candidate, {
    bool advanceSwipeStack = false,
  }) async {
    final userId = _currentUserId;

    if (advanceSwipeStack) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }

    // Optimistically mark as liked in discoverMembers list
    final updatedList = state.discoverMembers.map((p) {
      if (p.id == candidate.id) {
        return p.copyWith(isLiked: true);
      }
      return p;
    }).toList();
    state = state.copyWith(discoverMembers: updatedList);

    if (kPreviewMode) {
      final isMutual = candidate.fullName.contains('سارة') || candidate.fullName.contains('مريم');
      return LikeResult(
        isMatch: isMutual,
        matchId: 'match-preview-01',
        partnerName: candidate.fullName,
        partnerPhotoUrl: candidate.primaryPhotoUrl,
        partnerProfile: candidate.profile,
      );
    }

    if (userId == null) return null;

    try {
      final likesMatchesRepo = _ref.read(likesMatchesRepositoryProvider);
      final result = await likesMatchesRepo.sendLike(
        candidate.id,
        candidateProfile: candidate.profile,
        candidatePhotoUrl: candidate.primaryPhotoUrl,
      );

      if (result.isMatch) {
        final matchedList = state.discoverMembers.map((p) {
          if (p.id == candidate.id) {
            return p.copyWith(isLiked: true, isMatched: true);
          }
          return p;
        }).toList();
        state = state.copyWith(discoverMembers: matchedList);
      }

      return result;
    } catch (e) {
      // Fallback to recording like via matching repo
      try {
        await _repository.recordLike(
          fromUserId: userId,
          toUserId: candidate.id,
        );
      } catch (_) {}
    }
    return null;
  }

  /// Applies custom matrimonial search filters to both discover list and swipe recommendations.
  Future<void> applyFilters(MatchingFilters newFilters) async {
    state = state.copyWith(filters: newFilters);

    if (kPreviewMode) {
      final filtered = _filterPreviewCandidates(newFilters);
      state = state.copyWith(
        discoverMembers: filtered,
        profiles: filtered.where((p) => p.profile.gender == GenderType.female).toList(),
        currentIndex: 0,
        isLoading: false,
        isDiscoverLoading: false,
      );
      return;
    }

    final userId = _currentUserId;
    if (userId == null) return;

    state = state.copyWith(
      isLoading: true,
      isDiscoverLoading: true,
      errorMessage: null,
    );

    try {
      final results = await _repository.discoverMembers(
        currentUserId: userId,
        filters: newFilters,
      );

      state = state.copyWith(
        discoverMembers: results,
        profiles: results,
        currentIndex: 0,
        isLoading: false,
        isDiscoverLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isDiscoverLoading: false,
        errorMessage: 'تعذر تصفية النتائج: $e',
      );
    }
  }

  /// Updates keyword search query and applies immediately.
  Future<void> search(String query) async {
    final updatedFilters = state.filters.copyWith(searchQuery: query);
    await applyFilters(updatedFilters);
  }

  /// Quick target gender selection.
  Future<void> setTargetGender(GenderType? gender, {bool showAll = false}) async {
    final updatedFilters = state.filters.copyWith(
      targetGender: gender,
      clearTargetGender: gender == null && !showAll,
      showAllGenders: showAll,
    );
    await applyFilters(updatedFilters);
  }

  /// Resets search filters back to default.
  Future<void> resetFilters() async {
    await applyFilters(const MatchingFilters());
  }

  /// Helper to filter preview candidates accurately honoring all criteria and gender logic.
  List<ScoredProfile> _filterPreviewCandidates(MatchingFilters filters) {
    const userGender = GenderType.male; // Preview default active user is Ahmed (male)

    var list = PreviewMockData.recommendedProfiles.where((candidate) {
      return filters.matchesProfile(candidate.profile, currentUserGender: userGender);
    }).map((candidate) {
      // If candidate is same gender as user, marriage compatibility is null
      if (candidate.profile.gender == userGender) {
        return candidate.copyWith(clearCompatibilityScore: true);
      }
      return candidate;
    }).toList();

    // Sort preview results
    switch (filters.sortBy) {
      case 'newest':
        list.sort((a, b) => b.profile.createdAt.compareTo(a.profile.createdAt));
        break;
      case 'verified':
        list.sort((a, b) {
          final v = (b.isVerified ? 1 : 0).compareTo(a.isVerified ? 1 : 0);
          if (v != 0) return v;
          return (b.compatibilityScore ?? -1).compareTo(a.compatibilityScore ?? -1);
        });
        break;
      case 'compatibility':
      default:
        list.sort((a, b) {
          final scoreA = a.compatibilityScore ?? -1;
          final scoreB = b.compatibilityScore ?? -1;
          final compare = scoreB.compareTo(scoreA);
          if (compare != 0) return compare;
          return (b.isVerified ? 1 : 0).compareTo(a.isVerified ? 1 : 0);
        });
        break;
    }

    return list;
  }
}

/// Riverpod provider for [MatchingController].
final matchingControllerProvider =
    StateNotifierProvider<MatchingController, MatchingState>((ref) {
  final repository = ref.watch(matchingRepositoryProvider);
  return MatchingController(repository, ref);
});

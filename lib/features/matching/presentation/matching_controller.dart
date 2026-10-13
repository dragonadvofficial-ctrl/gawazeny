import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../../likes_matches/data/likes_matches_repository.dart';
import '../../likes_matches/domain/match_model.dart';
import '../data/matching_repository.dart';
import '../domain/matching_filters.dart';
import '../domain/scored_profile.dart';

/// State object representing the discovery feed and active search filters.
class MatchingState {
  final List<ScoredProfile> profiles;
  final int currentIndex;
  final bool isLoading;
  final MatchingFilters filters;
  final String? errorMessage;

  const MatchingState({
    this.profiles = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.filters = const MatchingFilters(),
    this.errorMessage,
  });

  /// The active profile displayed on the top card.
  ScoredProfile? get currentCandidate =>
      (currentIndex < profiles.length) ? profiles[currentIndex] : null;

  /// Whether there are more candidates remaining in the feed.
  bool get hasMoreCandidates => currentIndex < profiles.length;

  /// Number of candidates remaining in the stack.
  int get remainingCount => (profiles.length - currentIndex).clamp(0, 999);

  MatchingState copyWith({
    List<ScoredProfile>? profiles,
    int? currentIndex,
    bool? isLoading,
    MatchingFilters? filters,
    String? errorMessage,
  }) {
    return MatchingState(
      profiles: profiles ?? this.profiles,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      filters: filters ?? this.filters,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier controlling discovery feed interactions, swipes, and searches.
class MatchingController extends StateNotifier<MatchingState> {
  final MatchingRepository _repository;
  final Ref _ref;

  MatchingController(this._repository, this._ref)
      : super(const MatchingState()) {
    loadRecommendations();
  }

  String? get _currentUserId => _ref.read(currentUserProvider)?.id;

  /// Loads recommended profiles based on the 3-Tier Recommendation Engine.
  Future<void> loadRecommendations() async {
    if (kPreviewMode) {
      state = state.copyWith(
        profiles: PreviewMockData.recommendedProfiles,
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

  /// Handles Serious Like action (Swipe Right).
  Future<LikeResult?> swipeRight() async {
    final candidate = state.currentCandidate;
    final userId = _currentUserId;

    if (candidate != null && userId != null) {
      // Advance card immediately for responsive UI
      state = state.copyWith(currentIndex: state.currentIndex + 1);

      if (kPreviewMode) {
        // Return celebratory mutual match for Sarah to showcase MatchSuccessDialog
        final isMutual = candidate.fullName.contains('سارة');
        return LikeResult(
          isMatch: isMutual,
          matchId: 'match-preview-01',
          partnerName: candidate.fullName,
          partnerPhotoUrl: candidate.primaryPhotoUrl,
          partnerProfile: candidate.profile,
        );
      }

      try {
        final likesMatchesRepo = _ref.read(likesMatchesRepositoryProvider);
        final result = await likesMatchesRepo.sendLike(
          candidate.id,
          candidateProfile: candidate.profile,
          candidatePhotoUrl: candidate.primaryPhotoUrl,
        );
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
    }
    return null;
  }

  /// Applies custom matrimonial search filters.
  Future<void> applyFilters(MatchingFilters newFilters) async {
    state = state.copyWith(filters: newFilters);

    if (kPreviewMode) {
      final filtered = PreviewMockData.recommendedProfiles
          .where((p) => newFilters.matchesProfile(p.profile))
          .toList();
      state = state.copyWith(
        profiles: filtered.isNotEmpty
            ? filtered
            : PreviewMockData.recommendedProfiles,
        currentIndex: 0,
        isLoading: false,
      );
      return;
    }

    final userId = _currentUserId;
    if (userId == null) return;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final results = await _repository.searchProfiles(
        currentUserId: userId,
        filters: newFilters,
      );

      state = state.copyWith(
        profiles: results,
        currentIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تصفية النتائج: $e',
      );
    }
  }

  /// Resets search filters back to default.
  Future<void> resetFilters() async {
    await applyFilters(const MatchingFilters());
  }

  /// Updates keyword search query and applies immediately.
  Future<void> search(String query) async {
    final updatedFilters = state.filters.copyWith(searchQuery: query);
    await applyFilters(updatedFilters);
  }
}

/// Riverpod provider for [MatchingController].
final matchingControllerProvider =
    StateNotifierProvider<MatchingController, MatchingState>((ref) {
  final repository = ref.watch(matchingRepositoryProvider);
  return MatchingController(repository, ref);
});

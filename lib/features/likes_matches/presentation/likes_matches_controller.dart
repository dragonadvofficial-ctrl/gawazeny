import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../data/likes_matches_repository.dart';
import '../domain/match_model.dart';

/// State representing the Likes & Mutual Matches dashboard.
class LikesMatchesState {
  final List<MutualMatch> mutualMatches;
  final List<ReceivedLike> receivedLikes;
  final List<SentLike> sentLikes;
  final bool isLoading;
  final String? errorMessage;
  final int activeTabIndex;

  const LikesMatchesState({
    this.mutualMatches = const [],
    this.receivedLikes = const [],
    this.sentLikes = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeTabIndex = 0,
  });

  LikesMatchesState copyWith({
    List<MutualMatch>? mutualMatches,
    List<ReceivedLike>? receivedLikes,
    List<SentLike>? sentLikes,
    bool? isLoading,
    String? errorMessage,
    int? activeTabIndex,
  }) {
    return LikesMatchesState(
      mutualMatches: mutualMatches ?? this.mutualMatches,
      receivedLikes: receivedLikes ?? this.receivedLikes,
      sentLikes: sentLikes ?? this.sentLikes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
    );
  }
}

/// State notifier orchestrating Likes and Mutual Matches.
class LikesMatchesController extends StateNotifier<LikesMatchesState> {
  final LikesMatchesRepository _repository;
  final String? _currentUserId;

  LikesMatchesController(this._repository, this._currentUserId)
      : super(const LikesMatchesState()) {
    if (_currentUserId != null || kPreviewMode) {
      loadAll();
    }
  }

  /// Sets the active sub-tab (0: Mutual Matches, 1: Received Likes, 2: Sent Likes).
  void setTab(int index) {
    state = state.copyWith(activeTabIndex: index);
  }

  /// Concurrently loads mutual matches, received likes, and sent likes.
  Future<void> loadAll() async {
    if (kPreviewMode) {
      state = state.copyWith(
        mutualMatches: PreviewMockData.mutualMatches,
        receivedLikes: PreviewMockData.receivedLikes,
        sentLikes: PreviewMockData.sentLikes,
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    final userId = _currentUserId;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final results = await Future.wait([
        _repository.fetchMutualMatches(userId: userId),
        _repository.fetchReceivedLikes(userId: userId),
        _repository.fetchSentLikes(userId: userId),
      ]);

      state = state.copyWith(
        mutualMatches: results[0] as List<MutualMatch>,
        receivedLikes: results[1] as List<ReceivedLike>,
        sentLikes: results[2] as List<SentLike>,
        isLoading: false,
      );
    } catch (e, stack) {
      developer.log('Error loading likes & matches: $e', error: e, stackTrace: stack);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'تعذر تحميل بيانات التوافقات، يرجى المحاولة لاحقاً',
      );
    }
  }

  /// Accepts an incoming like (likes back), instantly forming a mutual match.
  Future<LikeResult?> likeBack(ReceivedLike receivedLike) async {
    if (kPreviewMode) {
      final updatedReceived = state.receivedLikes
          .where((l) => l.likeId != receivedLike.likeId)
          .toList();

      final newMutualMatch = MutualMatch(
        matchId: 'match-preview-${DateTime.now().millisecondsSinceEpoch}',
        partnerProfile: receivedLike.senderProfile,
        primaryPhotoUrl: receivedLike.primaryPhotoUrl,
        matchedAt: DateTime.now(),
        isActive: true,
      );

      state = state.copyWith(
        receivedLikes: updatedReceived,
        mutualMatches: [newMutualMatch, ...state.mutualMatches],
      );

      return LikeResult(
        isMatch: true,
        matchId: newMutualMatch.matchId,
        partnerName: receivedLike.senderProfile.fullName,
        partnerPhotoUrl: receivedLike.primaryPhotoUrl,
        partnerProfile: receivedLike.senderProfile,
      );
    }

    try {
      final result = await _repository.sendLike(
        receivedLike.senderProfile.id,
        candidateProfile: receivedLike.senderProfile,
        candidatePhotoUrl: receivedLike.primaryPhotoUrl,
      );

      // Optimistically update lists
      final updatedReceived = state.receivedLikes
          .where((l) => l.likeId != receivedLike.likeId)
          .toList();

      final newMutualMatch = MutualMatch(
        matchId: result.matchId ?? 'pending_match_${DateTime.now().millisecondsSinceEpoch}',
        partnerProfile: receivedLike.senderProfile,
        primaryPhotoUrl: receivedLike.primaryPhotoUrl,
        matchedAt: DateTime.now(),
        isActive: true,
      );

      final updatedMutual = [newMutualMatch, ...state.mutualMatches];

      state = state.copyWith(
        receivedLikes: updatedReceived,
        mutualMatches: updatedMutual,
      );

      return result;
    } catch (e) {
      developer.log('Error liking back: $e');
      state = state.copyWith(errorMessage: 'تعذر قبول الإعجاب حالياً');
      return null;
    }
  }

  /// Cancels an outgoing like.
  Future<void> cancelSentLike(SentLike sentLike) async {
    if (kPreviewMode) {
      final updatedSent = state.sentLikes
          .where((l) => l.likeId != sentLike.likeId)
          .toList();
      state = state.copyWith(sentLikes: updatedSent);
      return;
    }

    try {
      await _repository.cancelLike(sentLike.targetProfile.id);

      final updatedSent = state.sentLikes
          .where((l) => l.likeId != sentLike.likeId)
          .toList();

      state = state.copyWith(sentLikes: updatedSent);
    } catch (e) {
      developer.log('Error cancelling sent like: $e');
      state = state.copyWith(errorMessage: 'تعذر إلغاء الإعجاب');
    }
  }

  /// Deactivates a mutual match (Unmatch).
  Future<void> unmatch(MutualMatch match) async {
    try {
      await _repository.unmatch(match.matchId);

      final updatedMatches = state.mutualMatches
          .where((m) => m.matchId != match.matchId)
          .toList();

      state = state.copyWith(mutualMatches: updatedMatches);
    } catch (e) {
      developer.log('Error unmatching: $e');
      state = state.copyWith(errorMessage: 'تعذر إنهاء التوافق');
    }
  }
}

/// Riverpod provider for [LikesMatchesController].
final likesMatchesControllerProvider =
    StateNotifierProvider<LikesMatchesController, LikesMatchesState>((ref) {
  final repository = ref.watch(likesMatchesRepositoryProvider);
  final currentUser = ref.watch(currentUserProvider);
  return LikesMatchesController(repository, currentUser?.id);
});

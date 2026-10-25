import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/verification_repository.dart';
import '../domain/identity_verification.dart';

/// Verification wizard step indices.
enum VerificationStep {
  idCard,
  selfie,
  submitting,
  result,
}

/// Full state for the manual verification workflow.
class VerificationState {
  final VerificationStep step;

  // Captured image bytes
  final Uint8List? idCardBytes;
  final Uint8List? selfieBytes;

  // Uploaded URLs
  final String? idCardUrl;
  final String? selfieUrl;

  // Verification record from database or submission
  final IdentityVerification? currentRecord;

  // UI state
  final bool isSubmitting;
  final String? errorMessage;
  final String? noticeMessage;

  const VerificationState({
    this.step = VerificationStep.idCard,
    this.idCardBytes,
    this.selfieBytes,
    this.idCardUrl,
    this.selfieUrl,
    this.currentRecord,
    this.isSubmitting = false,
    this.errorMessage,
    this.noticeMessage,
  });

  VerificationState copyWith({
    VerificationStep? step,
    Uint8List? idCardBytes,
    Uint8List? selfieBytes,
    String? idCardUrl,
    String? selfieUrl,
    IdentityVerification? currentRecord,
    bool? isSubmitting,
    String? errorMessage,
    String? noticeMessage,
  }) {
    return VerificationState(
      step: step ?? this.step,
      idCardBytes: idCardBytes ?? this.idCardBytes,
      selfieBytes: selfieBytes ?? this.selfieBytes,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      currentRecord: currentRecord ?? this.currentRecord,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      noticeMessage: noticeMessage ?? this.noticeMessage,
    );
  }

  /// Final status of verification
  VerificationStatusType? get finalStatus => currentRecord?.status;

  /// True if ID card image has been captured
  bool get hasIdCard => idCardBytes != null;

  /// True if selfie has been captured
  bool get hasSelfie => selfieBytes != null;

  /// True if both images are ready for submission
  bool get readyToSubmit => hasIdCard && hasSelfie;
}

/// State notifier managing identity document submission and admin review tracking.
class VerificationController extends StateNotifier<VerificationState> {
  final VerificationRepository _repository;
  final Ref _ref;

  VerificationController(this._repository, this._ref)
      : super(const VerificationState()) {
    _loadExistingStatus();
  }

  /// Load any existing verification record on startup
  Future<void> _loadExistingStatus() async {
    if (kPreviewMode) return;
    try {
      final existing = await _repository.fetchUserVerificationStatus();
      if (existing != null && existing.status != VerificationStatusType.unverified) {
        state = state.copyWith(
          currentRecord: existing,
          step: VerificationStep.result,
        );
      }
    } catch (e) {
      developer.log('Could not load existing verification status: $e');
    }
  }

  /// Sets wizard step for visual QA and preview.
  void setStepForPreview(VerificationStep step) {
    state = state.copyWith(
      step: step,
      idCardBytes: PreviewMockData.samplePngBytes,
      selfieBytes: step == VerificationStep.selfie || step == VerificationStep.result
          ? PreviewMockData.samplePngBytes
          : null,
      errorMessage: null,
    );
  }

  /// Sets verification result for visual QA and preview.
  void setResultForPreview({
    required VerificationStatusType status,
    String? rejectionReason,
    String? registeredName,
  }) {
    final profile = _ref.read(currentUserProfileProvider);
    final effectiveName = registeredName ?? profile?.fullName ?? 'أحمد مصطفى كامل';

    state = state.copyWith(
      step: VerificationStep.result,
      idCardBytes: PreviewMockData.samplePngBytes,
      selfieBytes: PreviewMockData.samplePngBytes,
      noticeMessage: status == VerificationStatusType.pending
          ? 'تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.'
          : null,
      currentRecord: IdentityVerification(
        id: 'mock-verif-1',
        userId: profile?.id ?? 'mock-user-1',
        userFullName: effectiveName,
        idCardImageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=600',
        selfieImageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600',
        status: status,
        rejectionReason: rejectionReason,
        createdAt: DateTime.now(),
      ),
      errorMessage: rejectionReason,
    );
  }

  /// Sets the captured ID card image bytes.
  void setIdCardImage(Uint8List bytes) {
    state = state.copyWith(
      idCardBytes: bytes,
      errorMessage: null,
    );
  }

  /// Sets the captured selfie image bytes.
  void setSelfieImage(Uint8List bytes) {
    state = state.copyWith(
      selfieBytes: bytes,
      errorMessage: null,
    );
  }

  /// Advance to the selfie step after ID card is captured.
  void proceedToSelfie() {
    if (!state.hasIdCard) {
      state = state.copyWith(
        errorMessage: 'يرجى رفع صورة بطاقة الرقم القومي أولاً',
      );
      return;
    }
    state = state.copyWith(step: VerificationStep.selfie, errorMessage: null);
  }

  /// Submits the documents for manual admin approval.
  /// Sets state to PENDING and displays the required 15-minute review notice.
  Future<void> submitVerificationRequest() async {
    if (!state.readyToSubmit) {
      state = state.copyWith(
        errorMessage: 'يرجى رفع صورة بطاقة الرقم القومي والصورة الشخصية قبل الإرسال',
      );
      return;
    }

    state = state.copyWith(
      step: VerificationStep.submitting,
      isSubmitting: true,
      errorMessage: null,
    );

    const pendingNotice =
        'تم استلام طلب توثيق حسابك بنجاح. برجاء الانتظار، سيتم مراجعة طلبك خلال 15 دقيقة.';

    // In preview mode or mock testing
    if (kPreviewMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      final profile = _ref.read(currentUserProfileProvider);
      final verif = IdentityVerification(
        id: 'mock-verif-pending',
        userId: profile?.id ?? 'mock-user-1',
        userFullName: profile?.fullName ?? 'أحمد محمود القاضي',
        idCardImageUrl: 'https://images.unsplash.com/photo-1578328819058-b69f3a3b0f6b?w=600',
        selfieImageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600',
        status: VerificationStatusType.pending,
        rejectionReason: null,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        step: VerificationStep.result,
        currentRecord: verif,
        isSubmitting: false,
        noticeMessage: pendingNotice,
      );

      // Update local profile verification status to PENDING
      _ref.read(profileControllerProvider.notifier).setVerificationStatus(VerificationStatusType.pending);
      return;
    }

    try {
      final uid = _ref.read(currentUserProvider)?.id ?? 'unknown';
      final ts = DateTime.now().millisecondsSinceEpoch;

      // 1. Upload ID card
      final idCardUrl = await _repository.uploadDocument(
        state.idCardBytes!,
        'id_card_${uid}_$ts.jpg',
      );

      // 2. Upload selfie
      final selfieUrl = await _repository.uploadDocument(
        state.selfieBytes!,
        'selfie_${uid}_$ts.jpg',
      );

      // 3. Submit request to backend for admin review
      final result = await _repository.submitVerificationRequest(
        idCardUrl: idCardUrl,
        selfieUrl: selfieUrl,
      );

      // 4. Update local profile state to PENDING
      _ref.read(profileControllerProvider.notifier).setVerificationStatus(VerificationStatusType.pending);

      state = state.copyWith(
        step: VerificationStep.result,
        idCardUrl: idCardUrl,
        selfieUrl: selfieUrl,
        currentRecord: result.verification,
        isSubmitting: false,
        noticeMessage: result.message,
      );
    } catch (e) {
      developer.log('submitVerificationRequest error: $e');
      state = state.copyWith(
        step: VerificationStep.result,
        isSubmitting: false,
        errorMessage: e.toString(),
        currentRecord: IdentityVerification(
          id: 'error-verif',
          userId: _ref.read(currentUserProvider)?.id ?? '',
          userFullName: _ref.read(currentUserProfileProvider)?.fullName,
          idCardImageUrl: '',
          selfieImageUrl: '',
          status: VerificationStatusType.failed,
          rejectionReason: 'حدث خطأ أثناء إرسال طلب التوثيق. يرجى التحقق من اتصالك بالإنترنت وإعادة المحاولة.',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Retry with new images — resets to Step 1 (ID card).
  void retryWithNewImages() {
    state = const VerificationState(step: VerificationStep.idCard);
  }
}

/// Riverpod provider for [VerificationController].
final verificationControllerProvider =
    StateNotifierProvider<VerificationController, VerificationState>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return VerificationController(repo, ref);
});

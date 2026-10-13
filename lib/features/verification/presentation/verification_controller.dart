import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/preview/preview_config.dart';
import '../../../core/preview/preview_mock_data.dart';
import '../../profile/domain/user_profile.dart';
import '../data/verification_repository.dart';
import '../domain/identity_verification.dart';

/// Verification wizard step indices.
enum VerificationStep {
  idCard,
  selfie,
  processing,
  result,
}

/// Full state for the verification wizard.
class VerificationState {
  final VerificationStep step;

  // Captured image bytes
  final Uint8List? idCardBytes;
  final Uint8List? selfieBytes;

  // Uploaded URLs
  final String? idCardUrl;
  final String? selfieUrl;

  // AI result
  final AiVerificationResult? aiResult;

  // Existing verification record (pre-loaded on init)
  final IdentityVerification? existingRecord;

  // UI state
  final bool isProcessing;
  final String? errorMessage;

  const VerificationState({
    this.step = VerificationStep.idCard,
    this.idCardBytes,
    this.selfieBytes,
    this.idCardUrl,
    this.selfieUrl,
    this.aiResult,
    this.existingRecord,
    this.isProcessing = false,
    this.errorMessage,
  });

  VerificationState copyWith({
    VerificationStep? step,
    Uint8List? idCardBytes,
    Uint8List? selfieBytes,
    String? idCardUrl,
    String? selfieUrl,
    AiVerificationResult? aiResult,
    IdentityVerification? existingRecord,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return VerificationState(
      step: step ?? this.step,
      idCardBytes: idCardBytes ?? this.idCardBytes,
      selfieBytes: selfieBytes ?? this.selfieBytes,
      idCardUrl: idCardUrl ?? this.idCardUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      aiResult: aiResult ?? this.aiResult,
      existingRecord: existingRecord ?? this.existingRecord,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
    );
  }

  /// Shorthand for final status
  VerificationStatusType? get finalStatus => aiResult?.status ?? existingRecord?.status;

  /// True if ID card image has been captured
  bool get hasIdCard => idCardBytes != null;

  /// True if selfie has been captured
  bool get hasSelfie => selfieBytes != null;

  /// True if both images are ready for submission
  bool get readyToSubmit => hasIdCard && hasSelfie;
}

/// State notifier managing the 2-step ID verification wizard.
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
      if (existing != null) {
        state = state.copyWith(
          existingRecord: existing,
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
    double score = 95.0,
    String? name,
    String? errorMessage,
  }) {
    state = state.copyWith(
      step: VerificationStep.result,
      idCardBytes: PreviewMockData.samplePngBytes,
      selfieBytes: PreviewMockData.samplePngBytes,
      aiResult: AiVerificationResult(
        status: status,
        faceMatchScore: score,
        livenessPassed: status == VerificationStatusType.verified,
        extractedName: name ?? 'أحمد مصطفى كامل',
        rejectionReason: errorMessage,
      ),
      errorMessage: errorMessage,
    );
  }

  /// Sets the captured ID card image bytes (from picker).
  void setIdCardImage(Uint8List bytes) {
    state = state.copyWith(
      idCardBytes: bytes,
      errorMessage: null,
    );
  }

  /// Sets the captured selfie image bytes (from camera).
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

  /// Full pipeline: Upload images → AI verification → Submit result → Update state.
  Future<void> submitForAiVerification() async {
    if (!state.readyToSubmit) {
      state = state.copyWith(
        errorMessage: 'يرجى رفع صورة البطاقة والسيلفي قبل الإرسال',
      );
      return;
    }

    state = state.copyWith(
      step: VerificationStep.processing,
      isProcessing: true,
      errorMessage: null,
    );

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

      // 3. Run AI verification engine
      final aiResult = await _repository.processAiVerification(
        idBytes: state.idCardBytes!,
        selfieBytes: state.selfieBytes!,
      );

      // 4. Persist result via RPC
      await _repository.submitVerification(
        idCardUrl: idCardUrl,
        selfieUrl: selfieUrl,
        aiResult: aiResult,
      );

      state = state.copyWith(
        step: VerificationStep.result,
        idCardUrl: idCardUrl,
        selfieUrl: selfieUrl,
        aiResult: aiResult,
        isProcessing: false,
      );
    } catch (e) {
      developer.log('submitForAiVerification error: $e');
      state = state.copyWith(
        step: VerificationStep.result,
        isProcessing: false,
        errorMessage: e.toString(),
        aiResult: AiVerificationResult(
          faceMatchScore: 0,
          livenessPassed: false,
          status: VerificationStatusType.failed,
          rejectionReason: 'حدث خطأ أثناء عملية التوثيق. يرجى التحقق من الصور وإعادة المحاولة',
        ),
      );
    }
  }

  /// Retry with new images — resets to Step 1 (ID card).
  void retryWithNewImages() {
    state = const VerificationState(step: VerificationStep.idCard);
  }

  /// Resubmit with the same images (retry same bytes).
  Future<void> resubmitSameImages() async {
    if (state.idCardBytes == null || state.selfieBytes == null) {
      retryWithNewImages();
      return;
    }
    state = state.copyWith(
      step: VerificationStep.processing,
      isProcessing: true,
      errorMessage: null,
      aiResult: null,
    );
    await submitForAiVerification();
  }
}

/// Riverpod provider for [VerificationController].
final verificationControllerProvider =
    StateNotifierProvider<VerificationController, VerificationState>((ref) {
  final repo = ref.watch(verificationRepositoryProvider);
  return VerificationController(repo, ref);
});

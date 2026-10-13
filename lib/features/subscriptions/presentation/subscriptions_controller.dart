import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../data/subscriptions_repository.dart';
import '../domain/subscription_tier.dart';

/// State representation for subscriptions flow, checkout, and voucher redemption.
class SubscriptionsState {
  final SubscriptionPlanTier selectedTier;
  final SubscriptionModel? activeSubscription;
  final bool isProcessing;
  final String? errorMessage;
  final bool isPaymentSuccess;
  final String selectedPaymentMethod;
  final String? lastPaymentReference;

  // Voucher redemption state
  final bool isRedeemingVoucher;
  final String? voucherError;
  final bool voucherSuccess;
  final String? voucherSuccessMessage;

  const SubscriptionsState({
    this.selectedTier = SubscriptionPlanTier.semiAnnual900,
    this.activeSubscription,
    this.isProcessing = false,
    this.errorMessage,
    this.isPaymentSuccess = false,
    this.selectedPaymentMethod = 'INSTAPAY',
    this.lastPaymentReference,
    this.isRedeemingVoucher = false,
    this.voucherError,
    this.voucherSuccess = false,
    this.voucherSuccessMessage,
  });

  SubscriptionsState copyWith({
    SubscriptionPlanTier? selectedTier,
    SubscriptionModel? activeSubscription,
    bool? isProcessing,
    String? errorMessage,
    bool? isPaymentSuccess,
    String? selectedPaymentMethod,
    String? lastPaymentReference,
    bool? isRedeemingVoucher,
    String? voucherError,
    bool? voucherSuccess,
    String? voucherSuccessMessage,
  }) {
    return SubscriptionsState(
      selectedTier: selectedTier ?? this.selectedTier,
      activeSubscription: activeSubscription ?? this.activeSubscription,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
      isPaymentSuccess: isPaymentSuccess ?? this.isPaymentSuccess,
      selectedPaymentMethod: selectedPaymentMethod ?? this.selectedPaymentMethod,
      lastPaymentReference: lastPaymentReference ?? this.lastPaymentReference,
      isRedeemingVoucher: isRedeemingVoucher ?? this.isRedeemingVoucher,
      voucherError: voucherError,
      voucherSuccess: voucherSuccess ?? this.voucherSuccess,
      voucherSuccessMessage: voucherSuccessMessage,
    );
  }
}

/// Controller managing plan selection, voucher redemption, and checkout execution.
class SubscriptionsController extends StateNotifier<SubscriptionsState> {
  final SubscriptionsRepository _repository;
  final Ref _ref;

  SubscriptionsController(this._repository, this._ref)
      : super(const SubscriptionsState()) {
    _init();
  }

  void _init() {
    final user = _ref.read(currentUserProvider);
    if (user != null) {
      loadActiveSubscription(user.id);
    }
  }

  /// Sets the currently highlighted plan.
  void selectTier(SubscriptionPlanTier tier) {
    state = state.copyWith(
      selectedTier: tier,
      isPaymentSuccess: false,
      errorMessage: null,
      voucherError: null,
      voucherSuccess: false,
    );
  }

  /// Sets the chosen Egyptian payment method ('INSTAPAY', 'FAWRY', 'CARD', 'WALLET').
  void selectPaymentMethod(String method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  /// Loads current active subscription from repository.
  Future<void> loadActiveSubscription(String userId) async {
    final active = await _repository.getActiveSubscription(userId);
    state = state.copyWith(activeSubscription: active);
  }

  /// Redeems an offline voucher code atomically.
  Future<bool> redeemVoucher(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        isRedeemingVoucher: false,
        voucherError: 'يرجى إدخال كود القسيمة',
        voucherSuccess: false,
      );
      return false;
    }

    state = state.copyWith(
      isRedeemingVoucher: true,
      voucherError: null,
      voucherSuccess: false,
      voucherSuccessMessage: null,
    );

    final result = await _repository.redeemVoucherCode(trimmed);
    final isSuccess = result['success'] == true;

    if (isSuccess) {
      final user = _ref.read(currentUserProvider);
      if (user != null) {
        await loadActiveSubscription(user.id);
        _ref.invalidate(activeSubscriptionProvider);
      }
      state = state.copyWith(
        isRedeemingVoucher: false,
        voucherSuccess: true,
        voucherSuccessMessage: result['message'] as String? ?? 'تم تفعيل الاشتراك بنجاح!',
        voucherError: null,
      );
      return true;
    } else {
      state = state.copyWith(
        isRedeemingVoucher: false,
        voucherSuccess: false,
        voucherError: result['error'] as String? ?? 'كود القسيمة غير صالح أو مستخدم',
      );
      return false;
    }
  }

  /// Resets voucher form status.
  void resetVoucherStatus() {
    state = state.copyWith(
      isRedeemingVoucher: false,
      voucherError: null,
      voucherSuccess: false,
      voucherSuccessMessage: null,
    );
  }

  /// Processes checkout payment via secure server-side RPC.
  Future<bool> processPayment({
    required String userId,
    required SubscriptionPlanTier tier,
  }) async {
    state = state.copyWith(
      isProcessing: true,
      errorMessage: null,
      isPaymentSuccess: false,
    );

    try {
      final randomSuffix = 1000 + Random().nextInt(9000);
      final paymentRef = 'EGP-${state.selectedPaymentMethod}-$randomSuffix';

      final subscription = await _repository.processSubscriptionPayment(
        userId: userId,
        tier: tier,
        paymentRef: paymentRef,
      );

      state = state.copyWith(
        isProcessing: false,
        activeSubscription: subscription,
        isPaymentSuccess: true,
        lastPaymentReference: paymentRef,
      );
      _ref.invalidate(activeSubscriptionProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        errorMessage: 'تعذر إتمام عملية الدفع: $e',
        isPaymentSuccess: false,
      );
      return false;
    }
  }

  /// Resets transaction status flags after modal dismissal.
  void resetPaymentStatus() {
    state = state.copyWith(isPaymentSuccess: false, errorMessage: null);
  }
}

/// Riverpod provider for [SubscriptionsController].
final subscriptionsControllerProvider =
    StateNotifierProvider<SubscriptionsController, SubscriptionsState>((ref) {
  final repository = ref.watch(subscriptionsRepositoryProvider);
  return SubscriptionsController(repository, ref);
});

/// Convenience provider for active user subscription.
final activeSubscriptionProvider = FutureProvider<SubscriptionModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repository = ref.watch(subscriptionsRepositoryProvider);
  return repository.getActiveSubscription(user.id);
});

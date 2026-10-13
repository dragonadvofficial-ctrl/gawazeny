import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/subscription_tier.dart';
import 'subscriptions_controller.dart';

/// Screen listing the 5 official subscription packages, active plan status,
/// and interactive checkout bottom sheet.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subState = ref.watch(subscriptionsControllerProvider);
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text(context.isArabic ? 'الخطط والاشتراكات' : 'Plans & Subscriptions'),
        centerTitle: true,
      ),
      body: SafeArea(
        // Use SingleChildScrollView + Column so all 5 cards are built eagerly
        // (ListView lazily skips off-screen items which breaks widget tests).
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Current Subscription Status Card
              _buildCurrentPlanBanner(context, subState.activeSubscription),
              SizedBox(height: 12.h),

              // Quick Voucher Redemption Banner
              _buildQuickVoucherBanner(context, user?.id ?? 'default-user-id'),
              SizedBox(height: 20.h),

              // 2. Section Header
              Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 20.h,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryPink,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      context.tr('choosePlan'),
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                context.tr('privacyGuaranteed'),
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 16.h),

              // 3. Subscription Plan Cards — all 5 built eagerly
              ...SubscriptionPlanTier.values.map((tier) {
                final isSelected = subState.selectedTier == tier;
                return Padding(
                  padding: EdgeInsets.only(bottom: 16.h),
                  child: _SubscriptionCard(
                    tier: tier,
                    isSelected: isSelected,
                    onSelect: () => controller.selectTier(tier),
                    onSubscribe: () => _openCheckoutBottomSheet(
                      context,
                      ref,
                      tier,
                      user?.id ?? 'default-user-id',
                    ),
                  ),
                );
              }),

              // Guarantee & Trust Card
              _buildTrustFooter(context),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner displaying current plan status or upgrade prompt.
  Widget _buildCurrentPlanBanner(
    BuildContext context,
    SubscriptionModel? activeSub,
  ) {
    final isActive = activeSub != null && activeSub.isActive;

    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: isActive ? AppColors.primaryGradient : null,
        color: isActive ? null : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive ? Colors.transparent : AppColors.borderSubtle,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadowColor,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.surfaceWhite.withValues(alpha: 0.15)
                  : AppColors.lightPink,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.stars_rounded : Icons.lock_open_rounded,
              color: isActive ? AppColors.surfaceWhite : AppColors.secondaryPink,
              size: 28.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isActive
                            ? (context.isArabic
                                ? 'خطتك الحالية: ${activeSub.tier.localizedTitle(true)}'
                                : 'Current Plan: ${activeSub.tier.localizedTitle(false)}')
                            : context.tr('currentPlanFree'),
                        style: AppTextStyles.titleSmall.copyWith(
                          color: isActive
                              ? AppColors.surfaceWhite
                              : AppColors.primaryNavy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.successGreen
                            : AppColors.warningOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        isActive
                            ? context.tr('activeBadge')
                            : context.tr('limitedBadge'),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isActive
                              ? AppColors.surfaceWhite
                              : AppColors.warningOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  isActive
                      ? (context.isArabic
                          ? 'متبقي ${activeSub.daysRemaining} يوماً على نهاية فترة الاشتراك'
                          : '${activeSub.daysRemaining} days remaining in subscription')
                      : context.tr('subscribeToStartMessaging'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isActive
                        ? AppColors.surfaceWhite.withValues(alpha: 0.85)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Quick voucher redemption banner for users who already obtained a code offline.
  Widget _buildQuickVoucherBanner(BuildContext context, String userId) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.lightPink.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.secondaryPink.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.confirmation_number_outlined,
              color: AppColors.secondaryPink,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('haveVoucherCode'),
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  context.tr('enterVoucherSubtitle'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryPink,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            onPressed: () => openCheckoutSheet(context, userId: userId),
            child: Text(
              context.tr('activateBtn'),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.surfaceWhite,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trust and safety footer note.
  Widget _buildTrustFooter(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            color: AppColors.primaryNavy,
            size: 26.sp,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('instantSecureActivation'),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  context.tr('paymentSupportSub'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the Order Summary & Checkout Bottom Sheet.
  void _openCheckoutBottomSheet(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlanTier tier,
    String userId,
  ) {
    openCheckoutSheet(context, tier: tier, userId: userId);
  }

  /// Static helper to display the Voucher Activation Bottom Sheet from any screen.
  static void openCheckoutSheet(
    BuildContext context, {
    SubscriptionPlanTier tier = SubscriptionPlanTier.annual1500,
    String userId = '00000000-0000-0000-0000-000000000001',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => _VoucherActivationBottomSheet(
        tier: tier,
        userId: userId,
      ),
    );
  }
}

/// Rich card representing a single subscription plan.
class _SubscriptionCard extends StatelessWidget {
  final SubscriptionPlanTier tier;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onSubscribe;

  const _SubscriptionCard({
    required this.tier,
    required this.isSelected,
    required this.onSelect,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount = tier.discountPercentage != null;

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: tier.isPopular
                ? AppColors.secondaryPink
                : tier.isBestValue
                    ? AppColors.primaryNavy
                    : (isSelected ? AppColors.secondaryPink : AppColors.borderSubtle),
            width: (tier.isPopular || tier.isBestValue || isSelected) ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: tier.isPopular
                  ? AppColors.secondaryPink.withValues(alpha: 0.08)
                  : AppColors.cardShadowColor,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge (Popular, Best Value, Special)
            if (tier.isPopular)
              _buildTopBadge(
                title: context.isArabic
                    ? 'الأكثر اختياراً للزواج الجاد 💍'
                    : 'Most Popular for Marriage 💍',
                backgroundColor: AppColors.secondaryPink,
              )
            else if (tier.isBestValue)
              _buildTopBadge(
                title: context.isArabic
                    ? 'أفضل قيمة وأعلى توفير 🌟'
                    : 'Best Value & Highest Savings 🌟',
                backgroundColor: AppColors.primaryNavy,
              )
            else if (tier.isSpecial)
              _buildTopBadge(
                title: context.isArabic
                    ? 'عرض فيسبوك الحصري 🚀'
                    : 'Exclusive Facebook Offer 🚀',
                backgroundColor: const Color(0xFF1877F2),
              ),

            Padding(
              padding: EdgeInsets.all(20.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier.localizedTitle(context.isArabic),
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              tier.localizedSubtitle(context.isArabic),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.secondaryPink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${tier.priceEgp}',
                                style: AppTextStyles.headlineLarge.copyWith(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                context.isArabic ? 'ج.م' : 'EGP',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: AppColors.primaryNavy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (hasDiscount) ...[
                            Text(
                              context.isArabic
                                  ? 'بدلاً من ${tier.originalPriceEgp} ج.م'
                                  : 'Was ${tier.originalPriceEgp} EGP',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Description
                  Text(
                    tier.localizedDescription(context.isArabic),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  const Divider(color: AppColors.dividerColor, height: 1),
                  SizedBox(height: 14.h),

                  // Perks List
                  ...tier.localizedPerks(context.isArabic).map(
                    (perk) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: tier.isPopular
                                ? AppColors.secondaryPink
                                : AppColors.successGreen,
                            size: 18.sp,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              perk,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 18.h),

                  // Subscribe Button
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tier.isPopular
                            ? AppColors.secondaryPink
                            : AppColors.primaryNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      onPressed: onSubscribe,
                      child: Text(
                        context.isArabic
                            ? 'اشترك الآن (${tier.priceEgp} ج.م)'
                            : 'Subscribe Now (${tier.priceEgp} EGP)',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.surfaceWhite,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBadge({
    required String title,
    required Color backgroundColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22.r),
          topRight: Radius.circular(22.r),
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.surfaceWhite,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Voucher Activation & Payment Information Bottom Sheet.
class _VoucherActivationBottomSheet extends ConsumerStatefulWidget {
  final SubscriptionPlanTier tier;
  final String userId;

  const _VoucherActivationBottomSheet({
    required this.tier,
    required this.userId,
  });

  @override
  ConsumerState<_VoucherActivationBottomSheet> createState() =>
      _VoucherActivationBottomSheetState();
}

class _VoucherActivationBottomSheetState
    extends ConsumerState<_VoucherActivationBottomSheet> {
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionsControllerProvider.notifier).resetVoucherStatus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.isArabic
              ? 'تم نسخ $label ($text) إلى الحافظة'
              : 'Copied $label ($text) to clipboard',
        ),
        backgroundColor: AppColors.primaryNavy,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionsControllerProvider);
    final controller = ref.read(subscriptionsControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44.w,
                height: 5.h,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('planDetailsAndActivation'),
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 12.h),

            // Selected Plan Card
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: AppColors.lightPink,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      color: AppColors.secondaryPink,
                      size: 26.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tier.localizedTitle(context.isArabic),
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          context.isArabic
                              ? 'المدة: ${widget.tier.localizedDuration(true)}'
                              : 'Duration: ${widget.tier.localizedDuration(false)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    context.isArabic
                        ? '${widget.tier.priceEgp} ج.م'
                        : '${widget.tier.priceEgp} EGP',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryNavy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),

            // Offline Payment Instructions
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.secondaryPink,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        context.tr('paymentStepsTitle'),
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    context.isArabic
                        ? '1. قم بتحويل مبلغ ${widget.tier.priceEgp} ج.م عبر إحدى وسائل الدفع الآتية:'
                        : '1. Transfer ${widget.tier.priceEgp} EGP via one of the following methods:',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // InstaPay row
                  _buildPaymentTargetRow(
                    label: context.isArabic ? 'إنستاباي (InstaPay):' : 'InstaPay:',
                    value: 'gawezeny@instapay',
                    onCopy: () => _copyToClipboard(
                      'gawezeny@instapay',
                      context.isArabic ? 'حساب إنستاباي' : 'InstaPay Account',
                    ),
                  ),
                  SizedBox(height: 6.h),

                  // Vodafone Cash row
                  _buildPaymentTargetRow(
                    label: context.isArabic ? 'فودافون كاش / محفظة:' : 'Vodafone Cash / Wallet:',
                    value: '01099887766',
                    onCopy: () => _copyToClipboard(
                      '01099887766',
                      context.isArabic ? 'رقم المحفظة' : 'Wallet Number',
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    context.tr('paymentStep2'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  _buildPaymentTargetRow(
                    label: context.isArabic ? 'واتساب خدمة العملاء:' : 'Support WhatsApp:',
                    value: '01099887766',
                    onCopy: () => _copyToClipboard(
                      '01099887766',
                      context.isArabic ? 'رقم الواتساب' : 'WhatsApp Number',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),

            // Voucher Code Input
            Text(
              context.tr('enterVoucherInputLabel'),
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: AppColors.primaryNavy,
              ),
              decoration: InputDecoration(
                hintText: context.tr('voucherHint'),
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  letterSpacing: 1.0,
                ),
                prefixIcon: const Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.secondaryPink,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => _codeController.clear(),
                ),
                filled: true,
                fillColor: AppColors.offWhite,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: const BorderSide(color: AppColors.secondaryPink, width: 2),
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Error Feedback
            if (subState.voucherError != null)
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppColors.errorRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.errorRed,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        subState.voucherError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Success Feedback
            if (subState.voucherSuccess && subState.voucherSuccessMessage != null)
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.successGreen,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        subState.voucherSuccessMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Submit Activation Button
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                onPressed: subState.isRedeemingVoucher
                    ? null
                    : () async {
                        final code = _codeController.text;
                        final success = await controller.redeemVoucher(code);
                        if (context.mounted && success) {
                          Navigator.pop(context);
                          _showSuccessDialog(context, widget.tier);
                        }
                      },
                child: subState.isRedeemingVoucher
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.surfaceWhite,
                        ),
                      )
                    : Text(
                        context.tr('activateWithCodeBtn'),
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.surfaceWhite,
                          fontWeight: FontWeight.w700,
                          fontSize: 16.sp,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTargetRow({
    required String label,
    required String value,
    required VoidCallback onCopy,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.all(4.r),
              child: Row(
                children: [
                  Icon(
                    Icons.copy_rounded,
                    size: 16.sp,
                    color: AppColors.secondaryPink,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    context.tr('copyAction'),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.secondaryPink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, SubscriptionPlanTier tier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: const BoxDecoration(
                  color: AppColors.lightPink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: AppColors.secondaryPink,
                  size: 48.sp,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                context.tr('subscriptionSuccessTitle'),
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryNavy,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
              Text(
                context.isArabic
                    ? 'أهلاً بك في ${tier.localizedTitle(true)}. يمكنك الآن إرسال إعجابات غير محدودة '
                        'والتواصل مع التوافقات الجادة بكل خصوصية وأمان.'
                    : 'Welcome to ${tier.localizedTitle(false)}. You can now send unlimited likes '
                        'and connect with serious matches in complete privacy and security.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                  ),
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.tr('continuePartnerSearch')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

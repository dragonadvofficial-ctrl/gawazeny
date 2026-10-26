import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/theme/text_styles.dart';
import '../../profile/presentation/widgets/support_sheet.dart';
import '../data/payment_settings_repository.dart';
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

  Future<void> _launchVodafoneCash(String phone, double amount) async {
    _copyToClipboard(phone, context.isArabic ? 'رقم فودافون كاش' : 'Vodafone Cash Number');
    final amountInt = amount.toInt();
    final ussdUri = Uri.parse('tel:*9*7*$phone*$amountInt%23');

    bool launched = false;
    try {
      if (await canLaunchUrl(ussdUri)) {
        await launchUrl(ussdUri);
        launched = true;
      }
    } catch (_) {}

    if (mounted) {
      _showPaymentNoticeDialog(
        title: context.isArabic ? 'الدفع عبر فودافون كاش' : 'Vodafone Cash Payment',
        message: launched
            ? (context.isArabic
                ? 'تم فتح شاشة الاتصال بكود التحويل المباشر (*9*7*رقم*المبلغ#).\n\nكما تم نسخ رقم المحفظة ($phone) والمبلغ ($amountInt ج.م) للحافظة.\nبعد إتمام التحويل، أدخل كود القسيمة أدناه أو تواصل مع الدعم الفني لتأكيد التفعيل.'
                : 'Direct transfer USSD dialed. Number ($phone) and amount ($amountInt EGP) copied to clipboard. Enter voucher or contact support to confirm.')
            : (context.isArabic
                ? 'تم نسخ رقم فودافون كاش ($phone) والمبلغ ($amountInt ج.م) للحافظة.\nيمكنك فتح محفظتك أو طلب *9# لإتمام التحويل، ثم تأكيد الدفع عبر القسيمة أو الدعم.'
                : 'Vodafone Cash number ($phone) and amount ($amountInt EGP) copied to clipboard. Dial *9# or use wallet app, then confirm activation.'),
      );
    }
  }

  Future<void> _launchInstaPay(String account, double amount) async {
    _copyToClipboard(account, context.isArabic ? 'حساب إنستاباي' : 'InstaPay Account');
    final amountInt = amount.toInt();
    final instapaySchemeUri = Uri.parse('instapay://');
    final instapayWebUri = Uri.parse('https://ipn.eg/');

    bool launched = false;
    try {
      if (await canLaunchUrl(instapaySchemeUri)) {
        await launchUrl(instapaySchemeUri, mode: LaunchMode.externalApplication);
        launched = true;
      } else if (await canLaunchUrl(instapayWebUri)) {
        await launchUrl(instapayWebUri, mode: LaunchMode.externalApplication);
        launched = true;
      }
    } catch (_) {}

    if (mounted) {
      _showPaymentNoticeDialog(
        title: context.isArabic ? 'الدفع عبر إنستا باي (InstaPay)' : 'InstaPay Payment',
        message: launched
            ? (context.isArabic
                ? 'تم فتح تطبيق إنستاباي.\nتم نسخ عنوان الحساب ($account) والمبلغ ($amountInt ج.م) إلى الحافظة لسهولة إدخالهما في شاشة التحويل.\nبعد التحويل، أدخل كود القسيمة لتأكيد تفعيل الاشتراك.'
                : 'InstaPay opened. Account ($account) and amount ($amountInt EGP) copied to clipboard. Enter voucher after payment to activate.')
            : (context.isArabic
                ? 'تطبيق إنستاباي غير مثبت على جهازك أو تعذر فتحه مباشرة.\nتم نسخ حساب إنستاباي ($account) والمبلغ ($amountInt ج.م) إلى الحافظة.\nيمكنك التحويل عبر تطبيق بنكك أو تطبيق إنستاباي، ثم إدخال كود التفعيل.'
                : 'InstaPay app not installed or unavailable.\nAccount ($account) and amount ($amountInt EGP) copied to clipboard.'),
      );
    }
  }

  Future<void> _launchWhatsApp(String phone, String planName, int amount) async {
    final text = context.isArabic
        ? 'مرحباً، أود تفعيل باقة ($planName) بقيمة $amount ج.م عبر منصة جوزيني يا ماما. مرفق إشعار التحويل.'
        : 'Hello, I want to activate the ($planName) plan for $amount EGP. Here is my payment receipt.';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final fullPhone = cleanPhone.startsWith('0') ? '2$cleanPhone' : cleanPhone;
    final uri = Uri.parse('https://wa.me/$fullPhone?text=${Uri.encodeComponent(text)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    _copyToClipboard(phone, context.isArabic ? 'رقم واتساب الدعم' : 'WhatsApp Support');
  }

  void _showPaymentNoticeDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.secondaryPink, size: 24.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.isArabic ? 'حسناً، فهمت' : 'Understood',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.secondaryPink, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subState = ref.watch(subscriptionsControllerProvider);
    final controller = ref.read(subscriptionsControllerProvider.notifier);
    final paymentSettingsAsync = ref.watch(paymentSettingsProvider);
    final paymentSettings = paymentSettingsAsync.value ?? const PaymentSettings();

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

            // Payment Instructions Title
            Text(
              context.isArabic ? 'اختر وسيلة الدفع للتحويل:' : 'Choose Payment Method:',
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryNavy,
              ),
            ),
            SizedBox(height: 10.h),

            // 1. Vodafone Cash Payment Card
            if (paymentSettings.vodafoneCashEnabled)
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFFE60000).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE60000).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE60000).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.phone_android_rounded,
                            color: const Color(0xFFE60000),
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.isArabic ? 'فودافون كاش (Vodafone Cash)' : 'Vodafone Cash',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Text(
                                '${context.isArabic ? "المستلم:" : "Name:"} ${paymentSettings.vodafoneCashName}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),

                    // Number and Copy row
                    _buildPaymentTargetRow(
                      label: context.isArabic ? 'رقم المحفظة:' : 'Wallet Number:',
                      value: paymentSettings.vodafoneCashNumber,
                      onCopy: () => _copyToClipboard(
                        paymentSettings.vodafoneCashNumber,
                        context.isArabic ? 'رقم فودافون كاش' : 'Vodafone Cash Number',
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Deep Link Direct Button
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE60000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _launchVodafoneCash(
                          paymentSettings.vodafoneCashNumber,
                          widget.tier.priceEgp.toDouble(),
                        ),
                        icon: const Icon(Icons.touch_app_rounded, size: 18),
                        label: Text(
                          context.isArabic
                              ? 'الدفع عبر فودافون كاش (${widget.tier.priceEgp} ج.م)'
                              : 'Pay via Vodafone Cash (${widget.tier.priceEgp} EGP)',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // 2. InstaPay Payment Card
            if (paymentSettings.instapayEnabled)
              Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF5A189A).withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5A189A).withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A189A).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.send_to_mobile_rounded,
                            color: const Color(0xFF5A189A),
                            size: 18.sp,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.isArabic ? 'إنستا باي (InstaPay IPN)' : 'InstaPay (IPN)',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryNavy,
                                ),
                              ),
                              Text(
                                '${context.isArabic ? "المستلم:" : "Name:"} ${paymentSettings.instapayName}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),

                    // IPA and Copy row
                    _buildPaymentTargetRow(
                      label: context.isArabic ? 'عنوان الحساب (IPA):' : 'Account (IPA):',
                      value: paymentSettings.instapayAccount,
                      onCopy: () => _copyToClipboard(
                        paymentSettings.instapayAccount,
                        context.isArabic ? 'حساب إنستاباي' : 'InstaPay Account',
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Deep Link Direct Button
                    SizedBox(
                      width: double.infinity,
                      height: 44.h,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A189A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _launchInstaPay(
                          paymentSettings.instapayAccount,
                          widget.tier.priceEgp.toDouble(),
                        ),
                        icon: const Icon(Icons.flash_on_rounded, size: 18),
                        label: Text(
                          context.isArabic
                              ? 'الدفع عبر إنستا باي (${widget.tier.priceEgp} ج.م)'
                              : 'Pay via InstaPay (${widget.tier.priceEgp} EGP)',
                          style: AppTextStyles.labelMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Support WhatsApp confirmation
            Container(
              margin: EdgeInsets.only(bottom: 16.h),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.support_agent_rounded, color: AppColors.primaryNavy, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      context.isArabic
                          ? 'لإرسال صورة التحويل مباشرة عبر واتساب:'
                          : 'Send payment receipt via WhatsApp:',
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    ),
                    onPressed: () => _launchWhatsApp(
                      paymentSettings.supportWhatsapp,
                      widget.tier.localizedTitle(context.isArabic),
                      widget.tier.priceEgp,
                    ),
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 16.sp, color: AppColors.successGreen),
                    label: Text(
                      context.isArabic ? 'واتساب' : 'WhatsApp',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
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
            SizedBox(height: 10.h),

            // Send Transfer Confirmation Notice to Admin Support
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  side: const BorderSide(color: AppColors.borderSubtle),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SupportSheet(
                      initialSubject: context.isArabic
                          ? 'تأكيد تحويل اشتراك: ${widget.tier.localizedTitle(true)}'
                          : 'Payment Confirmation: ${widget.tier.localizedTitle(false)}',
                      initialContent: context.isArabic
                          ? 'مرحباً، قمت بتحويل مبلغ ${widget.tier.priceEgp} ج.م عبر (فودافون كاش / إنستاباي) لتفعيل باقة "${widget.tier.localizedTitle(true)}". رقم هاتفي أو حسابي هو: '
                          : 'Hello, I have transferred ${widget.tier.priceEgp} EGP to activate "${widget.tier.localizedTitle(false)}". My account/phone is: ',
                    ),
                  );
                },
                icon: const Icon(Icons.support_agent_rounded, size: 20),
                label: Text(
                  context.isArabic
                      ? 'إرسال إشعار تحويل للدعم الفني'
                      : 'Send Payment Notice to Support',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/text_styles.dart';
import 'intro_onboarding_controller.dart';

/// Introductory 6-screen visual onboarding flow for "جوزيني يا ماما".
///
/// Complies with all core constraints:
/// - Displays the 6 original images sequentially in full fidelity with BoxFit.contain.
/// - Never overlays UI text, titles, or descriptions on top of the images.
/// - Houses software navigation buttons strictly outside image bounds in a dedicated bottom bar.
/// - Screens 1-5: "التالي" and "تخطي" according to RTL directionality.
/// - Screen 6: Only "ابدأ رحلتك الآن" taking full width; no "التالي" or "تخطي".
/// - Responsive across all phone form factors with SafeArea protection.
class IntroOnboardingScreen extends ConsumerStatefulWidget {
  const IntroOnboardingScreen({super.key});

  @override
  ConsumerState<IntroOnboardingScreen> createState() =>
      _IntroOnboardingScreenState();
}

class _IntroOnboardingScreenState extends ConsumerState<IntroOnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isNavigating = false;

  /// Ordered list of the 6 onboarding asset images representing screens 1 through 6.
  static const List<String> _onboardingImages = [
    'assets/images/onboarding_1.png', // 1/6: جوزيني يا ماما .. بداية حكاية ممكن تكمل بالعمر كله
    'assets/images/onboarding_2.png', // 2/6: بياناتك بأمان .. احتضان عائلي
    'assets/images/onboarding_3.png', // 3/6: نقترح لك الأشخاص المناسبين .. متوافق 95%
    'assets/images/onboarding_4.png', // 4/6: عرّفهم بنفسك .. أحمد 28
    'assets/images/onboarding_5.png', // 5/6: تعارف باحترام .. تواصل آمن وودود
    'assets/images/onboarding_6.png', // 6/6: خطوتك الأولى تبدأ هنا
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache all onboarding images into image cache for instantaneous and smooth swiping
    for (final imagePath in _onboardingImages) {
      precacheImage(AssetImage(imagePath), context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Advances to the next onboarding slide.
  void _goToNextPage() {
    if (_currentPage < _onboardingImages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Terminates onboarding and routes user to login / registration flow.
  Future<void> _finishOnboarding() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });

    await ref.read(introOnboardingProvider.notifier).completeIntro();
  }

  @override
  Widget build(BuildContext context) {
    final isLastScreen = _currentPage == _onboardingImages.length - 1;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ivoryBackground,
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              // 1. Image area: Dedicated container, contain-fit, preserving 100% of graphics & text
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _onboardingImages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(22.r),
                          border: Border.all(
                            color: AppColors.borderSubtle,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryNavy.withValues(alpha: 0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14.r),
                          child: Image.asset(
                            _onboardingImages[index],
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.high,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 2. Software Navigation Button Container: Located strictly outside image bounds
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryNavy.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isLastScreen
                        ? _buildFinalScreenButton(context)
                        : _buildIntermediateButtons(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Button layout for intermediate screens (1 through 5):
  /// - "تخطي" on the right (start in RTL)
  /// - "التالي" on the left (end in RTL, leading forward)
  Widget _buildIntermediateButtons(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('intermediate_buttons'),
      child: SizedBox(
        height: 52.h,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Skip button («تخطي»): Ends onboarding and goes directly to auth
            TextButton(
              onPressed: _finishOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                minimumSize: Size(80.w, 48.h),
              ),
              child: Text(
                AppStrings.skip,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primaryNavy.withValues(alpha: 0.85),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Next button («التالي»): Advances to the next onboarding screen
            ElevatedButton(
              onPressed: _goToNextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryPink,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.secondaryPink.withValues(alpha: 0.35),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.r),
                ),
                minimumSize: Size(120.w, 48.h),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.next,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.arrow_back_rounded, // Left arrow points forward in RTL
                    size: 18.sp,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Button layout for the 6th and final screen:
  /// - A single prominent button titled "ابدأ رحلتك الآن"
  /// - Neither "التالي" nor "تخطي" is shown
  Widget _buildFinalScreenButton(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('final_screen_button'),
      child: SizedBox(
        width: double.infinity,
        height: 52.h,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.pinkGradient,
            borderRadius: BorderRadius.circular(26.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryPink.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _finishOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26.r),
              ),
            ),
            child: Text(
              AppStrings.startYourJourneyNow,
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

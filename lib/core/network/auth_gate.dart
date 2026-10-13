import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../theme/text_styles.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../main.dart';
import 'supabase_client.dart';

/// FutureProvider that inspects profile completeness for a given user ID.
final profileCompletionProvider =
    FutureProvider.family<bool, String>((ref, userId) async {
  final repository = ref.watch(onboardingRepositoryProvider);
  return repository.checkProfileCompletion(userId);
});

/// Gateway widget determining the correct entry screen based on authentication and profile state.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final user = ref.watch(currentUserProvider);

    // 1. Unauthenticated -> Login & Register Screen
    if (user == null) {
      return const LoginScreen();
    }

    // 2. Authenticated -> Inspect Profile Completion Status
    final completionAsync = ref.watch(profileCompletionProvider(user.id));

    return completionAsync.when(
      data: (isComplete) {
        if (isComplete) {
          // Profile is complete -> Access main matrimonial dashboard
          return const MainNavigationShell();
        } else {
          // Profile is incomplete -> Multi-step onboarding wizard
          return const OnboardingScreen();
        }
      },
      loading: () => const _AuthSplashLoading(),
      error: (error, stack) {
        // Fallback to onboarding if profile check experiences issues
        return const OnboardingScreen();
      },
    );
  }
}

class _AuthSplashLoading extends StatelessWidget {
  const _AuthSplashLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.r,
              height: 80.r,
              decoration: const BoxDecoration(
                color: AppColors.lightPink,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.favorite_rounded,
                  color: AppColors.secondaryPink,
                  size: 44.sp,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              AppStrings.appName,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primaryNavy,
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: 28.r,
              height: 28.r,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.secondaryPink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

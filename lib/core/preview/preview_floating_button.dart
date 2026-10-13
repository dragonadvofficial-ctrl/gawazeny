import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_colors.dart';
import '../theme/text_styles.dart';
import 'preview_config.dart';
import 'preview_navigator_sheet.dart';

/// Wraps any screen or the main shell with a floating quick-navigator button
/// when [kPreviewMode] is enabled. When disabled, passes child directly with zero overhead.
class PreviewAppWrapper extends StatelessWidget {
  final Widget child;

  const PreviewAppWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kPreviewMode) {
      return child;
    }

    return Stack(
      children: [
        child,

        // Floating Quick Navigator Button
        Positioned(
          bottom: 74.h,
          left: 16.w,
          child: Material(
            elevation: 8,
            shadowColor: AppColors.primaryBurgundy.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(30.r),
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final targetCtx = appNavigatorKey.currentContext ?? context;
                PreviewNavigatorSheet.show(targetCtx);
              },
              borderRadius: BorderRadius.circular(30.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryBurgundy,
                      AppColors.primaryNavy,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30.r),
                  border: Border.all(
                    color: AppColors.goldAccent.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.dashboard_customize_rounded,
                        color: AppColors.goldAccent,
                        size: 16.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'معاينة الشاشات 📱',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.surfaceWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

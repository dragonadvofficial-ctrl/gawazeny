import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/theme/text_styles.dart';
import '../auth_controller.dart';

/// Modal dialog presented upon successful sign-up informing the user about the verification email,
/// preventing repeated requests with a live cooldown timer, and allowing one-click resend.
class EmailConfirmationDialog extends ConsumerStatefulWidget {
  final String email;
  final VoidCallback onGoToSignIn;

  const EmailConfirmationDialog({
    super.key,
    required this.email,
    required this.onGoToSignIn,
  });

  /// Displays the confirmation dialog with smooth transition.
  static Future<void> show(
    BuildContext context, {
    required String email,
    required VoidCallback onGoToSignIn,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmailConfirmationDialog(
        email: email,
        onGoToSignIn: onGoToSignIn,
      ),
    );
  }

  @override
  ConsumerState<EmailConfirmationDialog> createState() =>
      _EmailConfirmationDialogState();
}

class _EmailConfirmationDialogState
    extends ConsumerState<EmailConfirmationDialog> {
  Timer? _countdownTimer;
  int _secondsRemaining = 60;
  bool _isResending = false;
  String? _feedbackMessage;
  bool _isFeedbackError = false;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer(60);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = seconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _handleResend() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _feedbackMessage = null;
    });

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.resendConfirmationEmail(email: widget.email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
    });

    if (success) {
      setState(() {
        _isFeedbackError = false;
        _feedbackMessage = context.tr('resendSuccess');
      });
      _startCooldownTimer(60);
    } else {
      final authState = ref.read(authControllerProvider);
      final rawError = authState.error?.toString();
      setState(() {
        _isFeedbackError = true;
        _feedbackMessage = rawError ?? context.tr('resendError');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Decorative Header Badge
            Center(
              child: Container(
                width: 76.r,
                height: 76.r,
                decoration: BoxDecoration(
                  color: AppColors.lightPink,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  size: 40.r,
                  color: AppColors.primaryBurgundy,
                ),
              ),
            ),
            SizedBox(height: 18.h),

            // Dialog Title
            Text(
              context.tr('accountCreatedSuccessTitle'),
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.primaryNavy,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
            SizedBox(height: 12.h),

            // Registered Email Address Container
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.ivoryBackground,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 18.sp,
                    color: AppColors.primaryNavy,
                  ),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      widget.email,
                      textDirection: TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // Clear Explanation & Spam Notice
            Text(
              context.tr('accountCreatedSuccessDesc'),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 16.h),

            // Optional Feedback Message
            if (_feedbackMessage != null) ...[
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _isFeedbackError
                      ? AppColors.errorRed.withValues(alpha: 0.1)
                      : AppColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: _isFeedbackError
                        ? AppColors.errorRed.withValues(alpha: 0.4)
                        : AppColors.successGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _feedbackMessage!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _isFeedbackError
                        ? AppColors.errorRed
                        : AppColors.successGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
            ],

            // Resend Email Button with Cooldown Timer
            OutlinedButton(
              onPressed: (_secondsRemaining > 0 || _isResending)
                  ? null
                  : _handleResend,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side: BorderSide(
                  color: _secondsRemaining > 0
                      ? AppColors.borderSubtle
                      : AppColors.primaryBurgundy,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: _isResending
                  ? SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primaryBurgundy,
                      ),
                    )
                  : Text(
                      _secondsRemaining > 0
                          ? context
                              .tr('resendCooldown')
                              .replaceAll('{seconds}', '$_secondsRemaining')
                          : context.tr('resendConfirmationEmail'),
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _secondsRemaining > 0
                            ? AppColors.textSecondary
                            : AppColors.primaryBurgundy,
                      ),
                    ),
            ),
            SizedBox(height: 12.h),

            // Go To Sign In Button
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onGoToSignIn();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: Text(
                context.tr('goToSignIn'),
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.surfaceWhite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

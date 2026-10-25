import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import '../domain/sign_up_result.dart';
import 'auth_controller.dart';
import 'widgets/email_confirmation_dialog.dart';

/// Screen allowing users to sign in or create an account with email and password,
/// supporting secure remember-me option, OS credential manager autofill, and email confirmation flow.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Populate saved email safely if previously remembered
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final savedEmail =
            await ref.read(authControllerProvider.notifier).getSavedEmail();
        if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
          setState(() {
            _emailController.text = savedEmail;
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isRegisterTab => _tabController.index == 1;

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final controller = ref.read(authControllerProvider.notifier);

    if (_isRegisterTab) {
      final result = await controller.signUp(email: email, password: password);

      if (!mounted) return;

      if (result != null) {
        // Trigger OS password manager prompt to safely save credentials
        TextInput.finishAutofillContext(shouldSave: true);

        if (result.status == SignUpResultStatus.successNeedsEmailConfirmation) {
          await EmailConfirmationDialog.show(
            context,
            email: email,
            onGoToSignIn: () {
              if (mounted) {
                _tabController.animateTo(0);
                _passwordController.clear();
                _confirmPasswordController.clear();
              }
            },
          );
        } else if (result.status == SignUpResultStatus.emailAlreadyInUse) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.message ?? context.tr('emailAlreadyRegistered'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.surfaceWhite,
                ),
              ),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: context.tr('signIn'),
                textColor: AppColors.surfaceWhite,
                onPressed: () {
                  _tabController.animateTo(0);
                  _passwordController.clear();
                  _confirmPasswordController.clear();
                },
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          );
        } else if (result.status == SignUpResultStatus.emailSendFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.message ?? context.tr('emailSendFailedNotice'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.surfaceWhite,
                ),
              ),
              backgroundColor: AppColors.warningOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          );
          await EmailConfirmationDialog.show(
            context,
            email: email,
            onGoToSignIn: () {
              if (mounted) {
                _tabController.animateTo(0);
                _passwordController.clear();
                _confirmPasswordController.clear();
              }
            },
          );
        }
      } else {
        final authState = ref.read(authControllerProvider);
        final errorMsg =
            authState.error?.toString() ?? context.tr('errorGeneric');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.surfaceWhite,
              ),
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } else {
      // Sign In flow
      final success = await controller.signIn(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );

      if (!mounted) return;

      if (success) {
        TextInput.finishAutofillContext(shouldSave: true);
      } else {
        final authState = ref.read(authControllerProvider);
        final errorMsg =
            authState.error?.toString() ?? context.tr('errorGeneric');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.surfaceWhite,
              ),
            ),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.ivoryBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Brand Main Hero Illustration
                    Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: 290.w,
                          maxHeight: 250.h,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 280.w,
                          height: 240.h,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      context.tr('appName'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displaySmall.copyWith(
                        color: AppColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 26.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      context.tr('appTagline'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                    SizedBox(height: 28.h),

                    // Tab selector Card (Sign in vs Register)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.borderSubtle,
                          width: 1.0,
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: AppColors.primaryNavy,
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                        labelColor: AppColors.surfaceWhite,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.sp,
                        ),
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: context.tr('signIn')),
                          Tab(text: context.tr('newAccount')),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textDirection: TextDirection.ltr,
                      textAlign:
                          context.isArabic ? TextAlign.right : TextAlign.left,
                      decoration: InputDecoration(
                        labelText: context.tr('email'),
                        hintText: context.tr('emailHint'),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('emailRequired');
                        }
                        final emailRegExp = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );
                        if (!emailRegExp.hasMatch(value.trim())) {
                          return context.tr('emailInvalid');
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: _isRegisterTab
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: context.tr('password'),
                        hintText: context.tr('passwordHint'),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primaryNavy,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.tr('passwordRequired');
                        }
                        if (value.trim().length < 6) {
                          return context.tr('passwordMinLength');
                        }
                        return null;
                      },
                    ),

                    // Confirm Password Field (Register Tab Only)
                    if (_isRegisterTab) ...[
                      SizedBox(height: 16.h),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: context.tr('confirmPassword'),
                          hintText: context.tr('passwordHint'),
                          prefixIcon: const Icon(
                            Icons.lock_reset_rounded,
                            color: AppColors.primaryNavy,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (!_isRegisterTab) return null;
                          if (value == null || value.trim().isEmpty) {
                            return context.tr('confirmPasswordRequired');
                          }
                          if (value.trim() != _passwordController.text.trim()) {
                            return context.tr('passwordMismatch');
                          }
                          return null;
                        },
                      ),
                    ],

                    // "☑ تذكّرني على هذا الجهاز" (Sign In Tab Only)
                    if (!_isRegisterTab) ...[
                      SizedBox(height: 12.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 24.r,
                            width: 24.r,
                            child: Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primaryNavy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.r),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? false;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _rememberMe = !_rememberMe;
                                });
                              },
                              child: Text(
                                context.tr('rememberMeOnThisDevice'),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    SizedBox(height: 24.h),

                    // Submit Button with responsive loading state & prevention of duplicate requests
                    ElevatedButton(
                      onPressed: isLoading ? null : _handleSubmit,
                      child: isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 18.r,
                                  width: 18.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: AppColors.surfaceWhite,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Flexible(
                                  child: Text(
                                    _isRegisterTab
                                        ? context.tr('creatingAccount')
                                        : context.tr('signingIn'),
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.titleSmall.copyWith(
                                      color: AppColors.surfaceWhite,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _isRegisterTab
                                  ? context.tr('createAccountAndProceed')
                                  : context.tr('signIn'),
                            ),
                    ),
                    SizedBox(height: 16.h),

                    // Privacy and family values note
                    Text(
                      context.tr('privacyDisclaimer'),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

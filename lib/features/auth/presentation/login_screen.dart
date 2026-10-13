import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/theme/text_styles.dart';
import 'auth_controller.dart';

/// Screen allowing users to sign in or create an account with email and password.
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
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

    bool success;
    if (_isRegisterTab) {
      success = await controller.signUp(email: email, password: password);
    } else {
      success = await controller.signIn(email: email, password: password);
    }

    if (!success && mounted) {
      final authState = ref.read(authControllerProvider);
      final errorMsg = authState.error?.toString() ?? context.tr('errorGeneric');
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Brand Main Hero Illustration (7x to 8x enlargement with transparent PNG)
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
                    textDirection: TextDirection.ltr,
                    textAlign: context.isArabic ? TextAlign.right : TextAlign.left,
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
                  SizedBox(height: 28.h),

                  // Submit Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleSubmit,
                    child: isLoading
                        ? SizedBox(
                            height: 24.r,
                            width: 24.r,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.surfaceWhite,
                            ),
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
    );
  }
}

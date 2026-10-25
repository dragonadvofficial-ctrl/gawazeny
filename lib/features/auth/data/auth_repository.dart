import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/sign_up_result.dart';

/// Repository handling authentication with Supabase, safe session retention, and error mappings.
class AuthRepository {
  final SupabaseClient _client;

  static const String _keyRememberMe = 'auth_remember_me_on_this_device';
  static const String _keySavedEmail = 'auth_saved_login_email';

  const AuthRepository(this._client);

  /// Current authenticated user or null.
  User? getCurrentUser() => _client.auth.currentUser;

  /// Current active session or null.
  Session? getCurrentSession() => _client.auth.currentSession;

  /// Stream of authentication state changes.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Checks whether "Remember me on this device" preference is active.
  Future<bool> getRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyRememberMe) ?? false;
    } catch (e) {
      debugPrint('Error reading rememberMe preference: $e');
      return false;
    }
  }

  /// Sets the "Remember me on this device" preference.
  Future<void> setRememberMe(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyRememberMe, value);
    } catch (e) {
      debugPrint('Error setting rememberMe preference: $e');
    }
  }

  /// Retrieves the saved email for convenience, if the user requested remembering.
  Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keySavedEmail);
    } catch (e) {
      return null;
    }
  }

  /// Stores or clears the saved email preference.
  Future<void> setSavedEmail(String? email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (email != null && email.trim().isNotEmpty) {
        await prefs.setString(_keySavedEmail, email.trim());
      } else {
        await prefs.remove(_keySavedEmail);
      }
    } catch (e) {
      debugPrint('Error setting saved email: $e');
    }
  }

  /// Handles app startup session verification according to the "Remember me" policy.
  Future<void> handleAppStartupSession() async {
    try {
      final remember = await getRememberMe();
      if (!remember) {
        // If the user did not opt into "Remember me on this device",
        // clear the local session on cold startup so they are prompted to login.
        await _client.auth.signOut(scope: SignOutScope.local);
      }
    } catch (e) {
      debugPrint('Startup session check error: $e');
    }
  }

  /// Sign up a new user using email and password with explicit redirect target.
  Future<SignUpResult> signUpWithEmail({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();
    final redirect = (emailRedirectTo != null && emailRedirectTo.isNotEmpty)
        ? emailRedirectTo
        : SupabaseConstants.authRedirectUrl;

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: cleanPassword,
        emailRedirectTo: redirect.isNotEmpty ? redirect : null,
      );

      // Handle user enumeration / existing user
      if (response.user != null &&
          response.user!.identities != null &&
          response.user!.identities!.isEmpty) {
        return SignUpResult(
          status: SignUpResultStatus.emailAlreadyInUse,
          email: cleanEmail,
          message: 'هذا البريد الإلكتروني مسجل مسبقاً، يرجى الانتقال إلى تسجيل الدخول',
          user: response.user,
        );
      }

      if (response.session != null) {
        return SignUpResult(
          status: SignUpResultStatus.successSessionCreated,
          email: cleanEmail,
          user: response.user,
        );
      }

      return SignUpResult(
        status: SignUpResultStatus.successNeedsEmailConfirmation,
        email: cleanEmail,
        user: response.user,
      );
    } on AuthException catch (e) {
      debugPrint('SignUp AuthException: ${e.message}, status: ${e.statusCode}');
      final lower = e.message.toLowerCase();

      if (lower.contains('user already registered') ||
          lower.contains('already exists') ||
          lower.contains('user_already_exists')) {
        return SignUpResult(
          status: SignUpResultStatus.emailAlreadyInUse,
          email: cleanEmail,
          message: 'هذا البريد الإلكتروني مسجل مسبقاً، يرجى الانتقال إلى تسجيل الدخول',
        );
      }

      if (lower.contains('error sending confirmation mail') ||
          lower.contains('email provider disabled') ||
          lower.contains('smtp')) {
        return SignUpResult(
          status: SignUpResultStatus.emailSendFailed,
          email: cleanEmail,
          message: 'تم إنشاء حسابك ولكن تعذر إرسال رسالة التأكيد في الوقت الحالي. يمكنك محاولة إعادة إرسالها.',
        );
      }

      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('SignUp unexpected error: $e');
      throw 'حدث خطأ غير متوقع أثناء إنشاء الحساب، يرجى المحاولة لاحقاً';
    }
  }

  /// Resends the confirmation/activation email to the specified address.
  Future<void> resendVerificationEmail({
    required String email,
    String? emailRedirectTo,
  }) async {
    final cleanEmail = email.trim();
    final redirect = (emailRedirectTo != null && emailRedirectTo.isNotEmpty)
        ? emailRedirectTo
        : SupabaseConstants.authRedirectUrl;

    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: cleanEmail,
        emailRedirectTo: redirect.isNotEmpty ? redirect : null,
      );
    } on AuthException catch (e) {
      debugPrint('Resend AuthException: ${e.message}, status: ${e.statusCode}');
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('Resend unexpected error: $e');
      throw 'تعذر إعادة إرسال رسالة التأكيد، يرجى المحاولة لاحقاً';
    }
  }

  /// Sign in an existing user using email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    try {
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      // Persist the user's explicit "Remember me" choice safely
      await setRememberMe(rememberMe);
      if (rememberMe) {
        await setSavedEmail(cleanEmail);
      } else {
        await setSavedEmail(null);
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('SignIn AuthException: ${e.message}, status: ${e.statusCode}');
      throw _mapAuthException(e);
    } catch (e) {
      throw 'حدث خطأ غير متوقع أثناء تسجيل الدخول، يرجى المحاولة لاحقاً';
    }
  }

  /// Sign out the current user session completely from server and device.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut(scope: SignOutScope.global);
    } on AuthException catch (e) {
      debugPrint('SignOut AuthException: ${e.message}');
    } catch (e) {
      debugPrint('SignOut unexpected error: $e');
    } finally {
      // Always reset rememberMe to false upon explicit logout
      await setRememberMe(false);
    }
  }

  /// Maps Supabase [AuthException] to user-friendly Arabic text.
  String _mapAuthException(AuthException e) => mapAuthException(e);

  /// Public static mapper for Supabase [AuthException] to user-friendly Arabic text.
  static String mapAuthException(AuthException e) {
    debugPrint('AuthException: ${e.message}, status: ${e.statusCode}');
    final message = e.message.toLowerCase();

    // 1. Rate limiting & security delays
    final rateLimitMatch = RegExp(r'after\s+(\d+)\s+seconds', caseSensitive: false).firstMatch(e.message);
    if (rateLimitMatch != null) {
      final seconds = rateLimitMatch.group(1);
      return 'لأسباب أمنية، يرجى الانتظار $seconds ثانية قبل إعادة إرسال الطلب';
    }

    if (message.contains('over_email_send_rate_limit') ||
        message.contains('rate limit') ||
        message.contains('for security purposes') ||
        message.contains('too many requests') ||
        e.statusCode == '429') {
      return 'تم تجاوز الحد المسموح من الطلبات، يرجى الانتظار دقيقة ثم إعادة المحاولة';
    }

    // 2. User already registered
    if (message.contains('user already registered') ||
        message.contains('already exists') ||
        message.contains('user_already_exists')) {
      return 'هذا البريد الإلكتروني مسجل مسبقاً، يرجى الانتقال إلى تسجيل الدخول';
    }

    // 3. Password constraints
    if (message.contains('password should be at least') ||
        message.contains('weak_password')) {
      return 'يجب أن تتكون كلمة المرور من 6 خانات على الأقل';
    }
    if (message.contains('signup requires a valid password') ||
        message.contains('password is too weak')) {
      return 'يرجى إدخال كلمة مرور صالحة وقوية';
    }

    // 4. Invalid credentials
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_grant') ||
        message.contains('invalid credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }

    // 5. Email not confirmed
    if (message.contains('email not confirmed')) {
      return 'لم يتم تأكيد البريد الإلكتروني بعد. يرجى مراجعة بريدك والضغط على رابط التفعيل';
    }

    // 6. Invalid email format
    if (message.contains('email address is invalid') ||
        message.contains('invalid email')) {
      return 'صيغة البريد الإلكتروني غير صالحة';
    }

    // 7. Network & connection timeouts
    if (message.contains('connection timeout') ||
        message.contains('connecttimeout') ||
        message.contains('connection timed out') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('clientexception') ||
        message.contains('socketexception') ||
        e.statusCode == '504' ||
        e.statusCode == '408') {
      return 'تعذر الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً';
    }

    return e.message.isNotEmpty
        ? e.message
        : 'فشلت عملية المصادقة، يرجى إعادة المحاولة لاحقاً';
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

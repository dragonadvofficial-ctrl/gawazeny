import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';

/// Repository handling authentication with Supabase and mapping errors to friendly Arabic messages.
class AuthRepository {
  final SupabaseClient _client;

  const AuthRepository(this._client);

  /// Current authenticated user or null.
  User? getCurrentUser() => _client.auth.currentUser;

  /// Stream of authentication state changes.
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Sign up a new user using email and password.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );
      return response;
    } on AuthException catch (e) {
      debugPrint('SignUp AuthException: ${e.message}, status: ${e.statusCode}');
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('SignUp unexpected error: $e');
      throw 'حدث خطأ غير متوقع أثناء إنشاء الحساب، يرجى المحاولة لاحقاً';
    }
  }

  /// Sign in an existing user using email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return response;
    } on AuthException catch (e) {
      debugPrint('SignIn AuthException: ${e.message}, status: ${e.statusCode}');
      throw _mapAuthException(e);
    } catch (e) {
      throw 'حدث خطأ غير متوقع أثناء تسجيل الدخول، يرجى المحاولة لاحقاً';
    }
  }

  /// Sign out the current user session.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'حدث خطأ أثناء تسجيل الخروج';
    }
  }

  /// Maps Supabase [AuthException] to user-friendly Arabic text.
  String _mapAuthException(AuthException e) {
    debugPrint('SignUp AuthException: ${e.message}, status: ${e.statusCode}');
    final message = e.message.toLowerCase();

    if (message.contains('user already registered') ||
        message.contains('already exists') ||
        message.contains('user_already_exists') ||
        message.contains('already registered')) {
      return 'هذا البريد الإلكتروني مسجل مسبقاً، يرجى تسجيل الدخول';
    }

    if (message.contains('password should be at least') ||
        message.contains('weak_password')) {
      return 'يجب أن تتكون كلمة المرور من 6 خانات على الأقل';
    }

    if (message.contains('invalid login credentials') ||
        message.contains('invalid_grant') ||
        message.contains('invalid credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }

    if (message.contains('email not confirmed')) {
      return 'يرجى تأكيد بريدك الإلكتروني عبر الرابط المرسل إليك للمتابعة';
    }

    // Real connection timeouts
    if (message.contains('connection timeout') ||
        message.contains('connecttimeout') ||
        message.contains('connection timed out') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        e.statusCode == '504' ||
        e.statusCode == '408') {
      return 'تعذر الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت والمحاولة ثانية';
    }

    return e.message.isNotEmpty
        ? e.message
        : 'فشلت عملية المصادقة، يرجى إعادة المحاولة';
  }
}

/// Riverpod provider for [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

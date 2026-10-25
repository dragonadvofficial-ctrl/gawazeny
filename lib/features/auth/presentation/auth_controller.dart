import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../domain/sign_up_result.dart';

/// StateNotifier managing asynchronous authentication state and actions.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AsyncValue.data(null));

  /// Checks if remember-me is active.
  Future<bool> getRememberMe() => _repository.getRememberMe();

  /// Gets saved email if any.
  Future<String?> getSavedEmail() => _repository.getSavedEmail();

  /// Attempts to sign in with email and password and optional remember-me.
  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signInWithEmail(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Attempts to sign up with email and password, returning structured [SignUpResult].
  Future<SignUpResult?> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.signUpWithEmail(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
      );
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Resends the signup confirmation email to the user.
  Future<bool> resendConfirmationEmail({
    required String email,
    String? emailRedirectTo,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.resendVerificationEmail(
        email: email,
        emailRedirectTo: emailRedirectTo,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Signs out the current user session and cleans up local auth tokens.
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _repository.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Riverpod provider for [AuthController].
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});

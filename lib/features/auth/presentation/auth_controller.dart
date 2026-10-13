import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

/// StateNotifier managing asynchronous authentication state and actions.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(const AsyncValue.data(null));

  /// Attempts to sign in with email and password.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Attempts to sign up with email and password.
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.signUpWithEmail(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Signs out the current user session.
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

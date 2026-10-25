import 'package:supabase_flutter/supabase_flutter.dart';

/// Status of the user registration attempt.
enum SignUpResultStatus {
  /// Account created and email confirmation is required before logging in.
  successNeedsEmailConfirmation,

  /// Account created with an active session immediately (e.g., auto-confirm enabled).
  successSessionCreated,

  /// The provided email address is already registered in the system.
  emailAlreadyInUse,

  /// Account created, but the confirmation email could not be delivered.
  emailSendFailed,
}

/// Encapsulates the structured outcome of a sign-up action.
class SignUpResult {
  final SignUpResultStatus status;
  final String email;
  final String? message;
  final User? user;

  const SignUpResult({
    required this.status,
    required this.email,
    this.message,
    this.user,
  });

  bool get isSuccess =>
      status == SignUpResultStatus.successNeedsEmailConfirmation ||
      status == SignUpResultStatus.successSessionCreated;
}

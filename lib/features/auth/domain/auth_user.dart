/// Authentication user representation combining Supabase auth session and profile status.
class AuthUser {
  final String id;
  final String? email;
  final String? phone;
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    this.email,
    this.phone,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    required this.createdAt,
  });

  factory AuthUser.fromSupabaseUser(dynamic user) {
    return AuthUser(
      id: user.id as String,
      email: user.email as String?,
      phone: user.phone as String?,
      isEmailVerified: user.emailConfirmedAt != null,
      isPhoneVerified: user.phoneConfirmedAt != null,
      createdAt: DateTime.parse(user.createdAt as String),
    );
  }
}

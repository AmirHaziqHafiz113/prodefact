/// A signed-in user, stripped down to what the app actually needs.
/// Deliberately doesn't expose any Firebase SDK type.
class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;

  @override
  String toString() => 'AuthUser($uid, $email)';
}

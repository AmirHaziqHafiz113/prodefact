/// The signed-in inspector's on-device profile: not synced to Firebase,
/// not part of any [InspectionSession] — purely local prefill data for
/// the Property Details step (inspector name) and report metadata
/// (company name). Name/email for display come live from
/// `AuthService.currentUser`, never duplicated here.
class UserProfile {
  const UserProfile({this.companyName, this.inspectorName});

  static const empty = UserProfile();

  final String? companyName;
  final String? inspectorName;

  UserProfile copyWith({String? companyName, String? inspectorName}) {
    return UserProfile(
      companyName: companyName ?? this.companyName,
      inspectorName: inspectorName ?? this.inspectorName,
    );
  }
}

import 'ai_level.dart';

/// The signed-in inspector's on-device profile: not synced to Firebase,
/// not part of any [InspectionSession] — purely local prefill data for
/// the Property Details step (inspector name) and report metadata
/// (company name). Name/email for display come live from
/// `AuthService.currentUser`, never duplicated here.
class UserProfile {
  const UserProfile({
    this.companyName,
    this.inspectorName,
    this.defaultAiLevel,
  });

  static const empty = UserProfile();

  final String? companyName;
  final String? inspectorName;

  /// The inspector's preferred default AI quality tier for new
  /// inspections — null falls back to the app-wide default (`smart`).
  /// Never an API key, provider name, or raw model id — see
  /// docs/commercial_model.md.
  final AiLevel? defaultAiLevel;

  UserProfile copyWith({
    String? companyName,
    String? inspectorName,
    AiLevel? defaultAiLevel,
  }) {
    return UserProfile(
      companyName: companyName ?? this.companyName,
      inspectorName: inspectorName ?? this.inspectorName,
      defaultAiLevel: defaultAiLevel ?? this.defaultAiLevel,
    );
  }
}

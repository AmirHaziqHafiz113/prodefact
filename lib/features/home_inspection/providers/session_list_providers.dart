import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/remote/remote_providers.dart';

/// Lightweight summaries of locally-stored inspection sessions the
/// *current* auth state is allowed to see, for the resume/list screen.
///
/// Ownership policy (see `docs/firebase.md`): signed out, only sessions
/// with no owner ("guest" sessions) are visible. Signed in, the
/// inspector sees their own sessions *plus* any still-unclaimed guest
/// sessions on this device (so pre-account-creation work is never
/// silently hidden) — but never another user's already-claimed data.
///
/// Manually invalidated (see `ActiveInspectionSession`) whenever a
/// session is created or changed, since Drift's underlying rows aren't
/// watched reactively here. Reads the auth state synchronously via
/// `ref.watch(authStateProvider)` rather than `.future` — this rebuilds
/// reactively as sign-in/out happens without depending on the
/// stream-provider `.future` accessor.
final sessionSummariesProvider =
    FutureProvider.autoDispose<List<InspectionSessionSummary>>((ref) {
      final repository = ref.watch(inspectionRepositoryProvider);
      final uid = ref.watch(authStateProvider).value?.uid;
      return repository.listSessions(ownerUid: uid);
    });

/// The real, non-fabricated subset of [sessionSummariesProvider] the
/// inspector should look at — a pending AI review or a failed
/// classification (see `InspectionSessionSummary.needsAttention`).
/// Shared by every "needs attention"/notification-bell surface (Home,
/// the top-bar bell) so they always agree with each other and with the
/// Inspections list's own "Needs attention" section.
final attentionSessionsProvider =
    Provider.autoDispose<List<InspectionSessionSummary>>((ref) {
      final summaries = ref.watch(sessionSummariesProvider).value ?? const [];
      return summaries.where((s) => s.needsAttention).toList();
    });

/// The real, non-fabricated count of evidence photos across every
/// session still waiting to reach the cloud (`pendingSyncCount` — see
/// its doc for what "waiting" means). Shared by Home's "Needs
/// attention" section so it agrees with the per-session sync strip
/// the Inspections queue already shows.
final totalPendingSyncCountProvider = Provider.autoDispose<int>((ref) {
  final summaries = ref.watch(sessionSummariesProvider).value ?? const [];
  return summaries.fold<int>(0, (sum, s) => sum + s.pendingSyncCount);
});

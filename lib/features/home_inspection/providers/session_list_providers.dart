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

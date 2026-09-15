import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/local/database_providers.dart';

/// Lightweight summaries of every locally-stored inspection session,
/// for the resume/list screen. Manually invalidated (see
/// `ActiveInspectionSession`) whenever a session is created or changed,
/// since Drift's underlying rows aren't watched reactively here.
final sessionSummariesProvider =
    FutureProvider.autoDispose<List<InspectionSessionSummary>>((ref) {
      final repository = ref.watch(inspectionRepositoryProvider);
      return repository.listSessions();
    });

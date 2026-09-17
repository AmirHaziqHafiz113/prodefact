import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/local/database_providers.dart';

/// A single, full [InspectionSession] loaded read-only by id — for
/// display surfaces (Home's active-inspection hero) that need real
/// area-based physical/AI/review progress (`PhysicalProgress.of`,
/// `AiProcessingProgress.of`, `AiReviewProgress.of`) beyond what the
/// cheap [InspectionSessionSummary] carries. Deliberately separate
/// from `activeSessionProvider`, which represents the one session
/// currently being *edited*; this provider never becomes that session
/// and has no side effects on it.
final sessionDetailProvider = FutureProvider.autoDispose
    .family<InspectionSession?, String>((ref, id) {
      final repository = ref.watch(inspectionRepositoryProvider);
      return repository.loadSession(id);
    });

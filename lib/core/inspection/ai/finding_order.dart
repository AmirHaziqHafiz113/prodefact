import '../entities/ai_finding_status.dart';
import '../entities/finding.dart';

/// How a list of findings is ordered for display. Ordering never
/// changes the findings themselves.
enum FindingSort {
  /// AI progress first: finished, then analysing, then waiting, then
  /// failed; newest first within each. The default.
  status,
  newest,
  oldest,
}

/// The display bucket for [status] under [FindingSort.status]: finished
/// (completed or needs review) 0, analysing (uploading/analysing) 1,
/// waiting (queued, or waiting to be queued) 2, failed 3.
int aiProgressRank(AiFindingStatus status) => switch (status) {
  AiFindingStatus.completed || AiFindingStatus.needsReview => 0,
  AiFindingStatus.uploading || AiFindingStatus.analyzing => 1,
  AiFindingStatus.queued ||
  AiFindingStatus.notQueued ||
  AiFindingStatus.awaitingApproval => 2,
  AiFindingStatus.failed => 3,
};

/// One display unit: a single finding, or the findings saved together
/// from one multi-photo gallery pick (shown in one bordered group —
/// each is still its own finding).
class FindingDisplayUnit {
  const FindingDisplayUnit(this.findings, {this.captureBatchId});

  final List<Finding> findings;
  final String? captureBatchId;

  bool get isGroup => findings.length > 1;
}

/// [findings] ordered by [sort] and grouped into display units. A
/// gallery batch stays together as one unit, placed by its
/// best-progressed (status) or newest/oldest member; its members are
/// ordered the same way inside it. The input list is not modified.
List<FindingDisplayUnit> orderFindings(
  List<Finding> findings, {
  FindingSort sort = FindingSort.status,
}) {
  int compare(Finding a, Finding b) => switch (sort) {
    FindingSort.status =>
      aiProgressRank(a.aiStatus) != aiProgressRank(b.aiStatus)
          ? aiProgressRank(a.aiStatus).compareTo(aiProgressRank(b.aiStatus))
          : b.createdAt.compareTo(a.createdAt),
    FindingSort.newest => b.createdAt.compareTo(a.createdAt),
    FindingSort.oldest => a.createdAt.compareTo(b.createdAt),
  };

  final byBatch = <String, List<Finding>>{};
  final units = <FindingDisplayUnit>[];
  for (final f in findings) {
    final batch = f.captureBatchId;
    if (batch == null) {
      units.add(FindingDisplayUnit([f]));
    } else {
      (byBatch[batch] ??= []).add(f);
    }
  }
  for (final entry in byBatch.entries) {
    final members = [...entry.value]..sort(compare);
    units.add(FindingDisplayUnit(members, captureBatchId: entry.key));
  }
  // Each unit is placed by its first (best-placed) member.
  units.sort((a, b) => compare(a.findings.first, b.findings.first));
  return units;
}

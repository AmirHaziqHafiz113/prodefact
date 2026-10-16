import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

/// The Report screen's "Physical inspection X/Y complete" comes from
/// [PhysicalProgress]; the PDF's Inspection Summary comes from the
/// [ReportModel]. They must never drift for the same inspection.

Section _area(int i, {bool included = true}) => Section(
  id: 'area_$i',
  name: 'Area $i',
  isPlumbing: false,
  isIncluded: included,
  elements: const [],
);

InspectionSession _session(
  List<Section> sections,
  Map<String, SectionStatus> statuses,
) {
  final now = DateTime(2026, 1, 1);
  return InspectionSession(
    id: 'session_1',
    industry: Industry.homeInspection,
    assetTypeId: 'highRise',
    sections: sections,
    sectionStatuses: statuses,
    findings: const [],
    createdAt: now,
    updatedAt: now,
  );
}

ReportModel _build(InspectionSession s, {int version = 1}) => buildReportModel(
  session: s,
  propertyTypeLabel: 'High Rise',
  generatedAt: DateTime(2026, 1, 2),
  version: version,
);

void main() {
  final nine = [for (var i = 0; i < 9; i++) _area(i)];

  Map<String, SectionStatus> done(int n) => {
    for (var i = 0; i < n; i++) 'area_$i': SectionStatus.completed,
    for (var i = n; i < 9; i++) 'area_$i': SectionStatus.inProgress,
  };

  void expectSame(InspectionSession s, int completed, int total) {
    final app = PhysicalProgress.of(s);
    final report = _build(s);
    expect('${app.completed}/${app.totalAreas}', '$completed/$total');
    expect(
      '${report.completedAreas}/${report.totalAreas}',
      '$completed/$total',
    );
  }

  test('9 applicable, all 9 complete -> 9/9 in app and report', () {
    expectSame(_session(nine, done(9)), 9, 9);
  });

  test('9 applicable, 4 complete -> 4/9 in app and report', () {
    expectSame(_session(nine, done(4)), 4, 9);
  });

  test('0 applicable areas -> 0/0, no crash', () {
    final s = _session([_area(0, included: false)], const {});
    expectSame(s, 0, 0);
    expect(_build(s).areas, isEmpty);
  });

  test('regenerating after completion changes reflects the new counts', () {
    final before = _session(nine, done(4));
    expect(_build(before).completedAreas, 4);
    final after = before.copyWith(sectionStatuses: done(9));
    final regenerated = _build(after, version: 2);
    expect(regenerated.completedAreas, 9);
    expect(regenerated.version, 2);
  });
}

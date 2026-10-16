import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';

/// Regression: rewriting the area list (`saveSections` deletes and
/// re-inserts every section row) used to reset each area's status to
/// not-started in the database. The Report screen reads the in-memory
/// session (9/9 complete) but report generation reloads from the
/// database, so the PDF printed "Completed areas 0".
Section _area(String id) => Section(
  id: id,
  name: id,
  isPlumbing: false,
  elements: const [
    InspectionElement(
      id: 'floor',
      name: 'Floor',
      components: [Component(id: 'tile', name: 'Tile')],
    ),
  ],
);

void main() {
  late DriftInspectionRepository repository;

  setUp(() {
    repository = DriftInspectionRepository(
      AppDatabase(NativeDatabase.memory()),
    );
  });

  tearDown(() => repository.close());

  test('saveSections keeps each area\'s status', () async {
    final areas = [for (var i = 0; i < 9; i++) _area('area_$i')];
    final session = await repository.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: areas,
    );
    for (final a in areas) {
      await repository.saveSectionStatus(
        session.id,
        a.id,
        SectionStatus.completed,
      );
    }

    // An unrelated area edit (e.g. an area note) rewrites the list.
    await repository.saveSections(session.id, [
      for (final a in areas) a.copyWith(note: 'edited'),
    ]);

    final reloaded = (await repository.loadSession(session.id))!;
    expect(
      reloaded.sectionStatuses.values,
      everyElement(SectionStatus.completed),
    );
    final progress = PhysicalProgress.of(reloaded);
    expect('${progress.completed}/${progress.totalAreas}', '9/9');
  });

  test(
    'a newly added area starts not-started; others keep their status',
    () async {
      final session = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_area('a')],
      );
      await repository.saveSectionStatus(
        session.id,
        'a',
        SectionStatus.completed,
      );

      await repository.saveSections(session.id, [_area('a'), _area('b')]);

      final reloaded = (await repository.loadSession(session.id))!;
      expect(reloaded.sectionStatuses['a'], SectionStatus.completed);
      expect(reloaded.sectionStatuses['b'], SectionStatus.notStarted);
    },
  );
}

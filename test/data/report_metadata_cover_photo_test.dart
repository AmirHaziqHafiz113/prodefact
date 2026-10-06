import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';

void main() {
  test('the Residence / Unit Photo path persists with the report metadata '
      'and reaches the report model; clearing it removes it', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final repo = DriftInspectionRepository(
      AppDatabase(NativeDatabase.memory()),
    );
    addTearDown(repo.close);
    final session = await repo.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: const [
        Section(id: 'kitchen', name: 'Kitchen', isPlumbing: true, elements: []),
      ],
    );

    await repo.saveReportMetadata(
      session.id,
      const ReportMetadata(
        title: 'Unit A-1',
        contactNumber: '0123456789',
        coverPhotoPath: '/photos/unit.jpg',
      ),
    );
    final loaded = (await repo.loadSession(session.id))!;
    expect(loaded.reportMetadata!.coverPhotoPath, '/photos/unit.jpg');
    final model = buildReportModel(
      session: loaded,
      propertyTypeLabel: 'High Rise',
      generatedAt: DateTime(2026, 10, 6),
    );
    expect(model.coverPhotoPath, '/photos/unit.jpg');

    await repo.saveReportMetadata(
      session.id,
      loaded.reportMetadata!.copyWith(clearCoverPhoto: true),
    );
    final cleared = (await repo.loadSession(session.id))!;
    expect(cleared.reportMetadata!.coverPhotoPath, isNull);
    expect(
      buildReportModel(
        session: cleared,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 10, 6),
      ).coverPhotoPath,
      isNull,
    );
  });
}

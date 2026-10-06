import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';

CustomDefect _defect(String id, String owner, {bool archived = false}) =>
    CustomDefect(
      id: id,
      ownerUid: owner,
      elementId: 'custom_element.floor',
      elementName: 'Floor',
      componentId: 'custom_component.floor.floor_trap',
      componentName: 'Floor Trap',
      defectDescription: 'Floor trap cover is loose',
      correctiveAction: 'Re-fix the cover.',
      note: 'seen in master bath',
      createdAt: DateTime(2026, 10, 6, 9),
      archived: archived,
    );

void main() {
  test('custom defects persist across an app restart, with their '
      'corrective action, note and archive flag', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final dir = await Directory.systemTemp.createTemp('prodefact_custom');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'db.sqlite'));

    final first = DriftInspectionRepository(AppDatabase(NativeDatabase(file)));
    await first.saveCustomDefect(_defect('custom.1', 'company-a'));
    await first.saveCustomDefect(
      _defect('custom.2', 'company-a', archived: true),
    );
    await first.close();

    final second = DriftInspectionRepository(AppDatabase(NativeDatabase(file)));
    addTearDown(second.close);
    final loaded = await second.loadCustomDefects('company-a');
    expect(loaded.map((d) => d.id), unorderedEquals(['custom.1', 'custom.2']));
    final one = loaded.firstWhere((d) => d.id == 'custom.1');
    expect(one.correctiveAction, 'Re-fix the cover.');
    expect(one.note, 'seen in master bath');
    expect(one.componentId, 'custom_component.floor.floor_trap');
    expect(loaded.firstWhere((d) => d.id == 'custom.2').archived, isTrue);
  });

  test('custom defects are scoped by owner: another account never loads '
      'them, and saving again updates rather than duplicates', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final repo = DriftInspectionRepository(
      AppDatabase(NativeDatabase.memory()),
    );
    addTearDown(repo.close);
    await repo.saveCustomDefect(_defect('custom.1', 'company-a'));
    await repo.saveCustomDefect(_defect('custom.1', 'company-a'));
    await repo.saveCustomDefect(_defect('custom.9', 'company-b'));

    expect((await repo.loadCustomDefects('company-a')).map((d) => d.id), [
      'custom.1',
    ]);
    expect((await repo.loadCustomDefects('company-b')).map((d) => d.id), [
      'custom.9',
    ]);
    expect(await repo.loadCustomDefects('company-c'), isEmpty);
  });
}

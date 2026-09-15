import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

/// ProDefact's local database. This is the first schema — schema
/// version 1 establishes the baseline via [MigrationStrategy.onCreate].
/// Future schema changes bump [schemaVersion] and add explicit
/// `onUpgrade` steps here rather than dropping/recreating the database.
@DriftDatabase(
  tables: [InspectionSessionRows, SectionRows, FindingRows, EvidenceRows],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens (creating if necessary) the on-device database file under
  /// the app's documents directory.
  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration =>
      MigrationStrategy(onCreate: (migrator) => migrator.createAll());
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'prodefact.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

/// The on-device note reading must equal the backend's, note for note —
/// the failed-AI fallback is driven by THIS reading, so any drift would
/// let the app and the Function disagree about what a note locks.
/// `functions/src/ai/note_pipeline.test.ts` pins the backend to the same
/// fixture.
void main() {
  test('readNoteIntent matches the backend fixture for every note', () {
    final fixture = jsonDecode(
      File('functions/src/ai/note_intent.fixture.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(fixture, isNotEmpty);
    for (final entry in fixture.entries) {
      final expected = entry.value as Map<String, dynamic>;
      final intent = readNoteIntent(entry.key);
      expect(
        intent.level.name.toUpperCase(),
        expected['level'],
        reason: 'level for "${entry.key}"',
      );
      expect(
        [...intent.lockComponentNames]..sort(),
        (expected['lockComponentNames'] as List).cast<String>(),
        reason: 'lock for "${entry.key}"',
      );
      expect(
        intent.entryIds.isEmpty ? null : intent.entryIds.first,
        expected['leadEntryId'],
        reason: 'lead entry for "${entry.key}"',
      );
      expect(
        intent.unlistedTerms,
        (expected['unlisted'] as List).cast<String>(),
        reason: 'uncatalogued part for "${entry.key}"',
      );
    }
  });

  test('after a failed AI call the fallback is the note\'s component only', () {
    for (final note in ['wall poor skim', 'Wal por skim', 'door frame']) {
      final top = recommendedDefects(
        RelatedDefectContext(note: note),
        limit: 50,
      );
      final lock = readNoteIntent(note).lockComponentIds;
      expect(top, isNotEmpty);
      expect(
        top.every((e) => lock.contains(e.componentId)),
        isTrue,
        reason: '"$note" must never recommend another component',
      );
    }
    expect(
      recommendedDefects(const RelatedDefectContext(note: 'crack')),
      isNotEmpty,
      reason: 'no lock: the broader search stays available',
    );
  });
}

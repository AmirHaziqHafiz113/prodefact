import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

/// Inspector-note AUTHORITY (2026-10-12), on-device twin of the backend's
/// component lock: "Wal por skim" must resolve to Wall / Concrete Wall /
/// poor skim-paint finishing, and look-alike wording on doors/windows must
/// never reach the top recommendations.
void main() {
  const skimId = 'wall.concrete_wall.03';
  Set<String> elementsOf(Iterable<DefectCatalogueEntry> entries) => {
    for (final e in entries) e.mainElementName,
  };

  group('"wal por skim" in every spelling', () {
    for (final note in [
      'Wal por skim',
      'wal poor skim',
      'wall por skim',
      'wall poor skim',
      'dinding por skim',
    ]) {
      test('"$note" → level A, Concrete Wall, skim entry first', () {
        final intent = readNoteIntent(note);
        expect(intent.level, NoteConfidenceLevel.a);
        expect(intent.lockComponentNames, ['Concrete Wall']);
        expect(intent.entryIds.first, skimId);

        final top = recommendedDefects(RelatedDefectContext(note: note));
        expect(top.first.id, skimId);
        expect(elementsOf(top), {'Wall'}, reason: 'no Door/Window in top-4');
        expect(
          top.every((e) => e.componentName == 'Concrete Wall'),
          isTrue,
          reason: 'component lock: nothing from another component',
        );
      });
    }
  });

  test('the full ranking also leads with the locked component, so the '
      'searchable list is note-first too', () {
    final ranked = rankRelatedDefects(
      const RelatedDefectContext(note: 'Wal por skim'),
    );
    expect(ranked.first.id, skimId);
    expect(ranked.length, DefectCatalogue.instance.entries.length);
    final concrete = DefectCatalogue.instance
        .forComponent('wall.concrete_wall')
        .length;
    expect(
      ranked.take(concrete).every((e) => e.componentName == 'Concrete Wall'),
      isTrue,
    );
  });

  test('level B: a component-only note locks the component(s)', () {
    expect(readNoteIntent('wall').level, NoteConfidenceLevel.b);
    expect(
      elementsOf(recommendedDefects(const RelatedDefectContext(note: 'wall'))),
      {'Wall'},
    );
    final frame = readNoteIntent('door frame');
    expect(frame.level, NoteConfidenceLevel.b);
    expect(frame.lockComponentNames, ['Door Frame']);
    final sliding = readNoteIntent('sliding door');
    expect(sliding.level, NoteConfidenceLevel.b);
    expect(
      sliding.lockComponentNames.every((n) => n.contains('Sliding')),
      isTrue,
    );
  });

  test('component + defect: door frame dent, sliding door scratch, floor '
      'tile hollow', () {
    expect(readNoteIntent('door frame dent').lockComponentNames, [
      'Door Frame',
    ]);
    final scratch = readNoteIntent('sliding door scratch');
    expect(scratch.isLocked, isTrue);
    expect(
      scratch.lockComponentNames.every((n) => n.contains('Sliding')),
      isTrue,
    );
    final hollow = readNoteIntent('floor tile hollow');
    expect(hollow.lockComponentNames, ['Floor Tiles']);
    final entry = DefectCatalogue.instance.byId(hollow.entryIds.first)!;
    expect(entry.defectDescription.toLowerCase(), contains('hollow'));
  });

  test('level C: no reliable component stays unlocked (the photo decides)', () {
    for (final note in ['crack', 'stain', 'damage', 'frem dent', 'holo tile']) {
      final intent = readNoteIntent(note);
      expect(intent.level, NoteConfidenceLevel.c, reason: note);
      expect(intent.isLocked, isFalse, reason: note);
    }
    // Still ranks sensibly without a lock.
    final holo = recommendedDefects(
      const RelatedDefectContext(note: 'holo tile'),
    );
    expect(holo, isNotEmpty);
    expect(
      holo.any((e) => e.defectDescription.toLowerCase().contains('hollow')),
      isTrue,
    );
    final frem = recommendedDefects(
      const RelatedDefectContext(note: 'frem dent'),
    );
    expect(frem.any((e) => e.componentName.contains('Frame')), isTrue);
  });

  test('an uncatalogued part is never locked onto a look-alike', () {
    final intent = readNoteIntent('floor trap crack');
    expect(intent.isLocked, isFalse);
    expect(intent.unlistedTerms, contains('floor trap'));
  });

  test('a blank or missing note reads as nothing (never throws)', () {
    expect(readNoteIntent(null).level, NoteConfidenceLevel.c);
    expect(readNoteIntent('   ').isLocked, isFalse);
  });

  test('a locked note outranks an AI candidate from another component', () {
    final top = recommendedDefects(
      const RelatedDefectContext(
        note: 'wall poor skim',
        candidateEntryIds: ['door.door_hinge.01'],
      ),
    );
    expect(top.first.id, skimId);
    expect(top.any((e) => e.id == 'door.door_hinge.01'), isFalse);
  });

  test('likelyNoteEntry is only offered for level A', () {
    expect(
      likelyNoteEntry(const RelatedDefectContext(note: 'Wal por skim'))!.id,
      skimId,
    );
    expect(likelyNoteEntry(const RelatedDefectContext(note: 'wall')), isNull);
    expect(likelyNoteEntry(const RelatedDefectContext(note: 'crack')), isNull);
  });

  test('contradiction wording is the plain-language message', () {
    expect(
      needsReviewReasonText('note_image_contradiction'),
      'Quick note and image may refer to different components.',
    );
  });
}

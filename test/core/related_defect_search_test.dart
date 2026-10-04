import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

/// Searchable related-defect selector — ranking/search logic
/// (2026-10-06): the controlled catalogue, most-related-to-this-finding
/// first, with alias-aware search across the full 222 entries.

void main() {
  final catalogue = DefectCatalogue.instance;

  group('rankRelatedDefects', () {
    test('a component named in the note ranks first, and never excludes '
        'the rest of the catalogue', () {
      final ranked = rankRelatedDefects(
        const RelatedDefectContext(note: 'holo wall tile'),
      );
      expect(ranked.length, catalogue.entries.length);
      expect(
        ranked.take(6).every((e) => e.componentName == 'Wall Tile'),
        isTrue,
      );
    });

    test('the AI candidates (top-4) rank ahead of everything else, in '
        'their own order', () {
      const ids = ['door.sliding_door_panel.07', 'door.sliding_door_frame.01'];
      final ranked = rankRelatedDefects(
        const RelatedDefectContext(candidateEntryIds: ids),
      );
      expect(ranked[0].id, ids[0]);
      expect(ranked[1].id, ids[1]);
    });

    test('detectedComponent boosts its own entries to the top even '
        'without a note', () {
      final ranked = rankRelatedDefects(
        const RelatedDefectContext(detectedComponent: 'Sliding Door Glass'),
      );
      expect(
        ranked.take(2).every((e) => e.componentName == 'Sliding Door Glass'),
        isTrue,
      );
    });

    test('excludeEntryId removes exactly that one entry and nothing else', () {
      final target = catalogue.entries.first.id;
      final ranked = rankRelatedDefects(
        RelatedDefectContext(excludeEntryId: target),
      );
      expect(ranked.length, catalogue.entries.length - 1);
      expect(ranked.any((e) => e.id == target), isFalse);
    });

    test('with no context at all, every entry is still present (a plain, '
        'scrollable full list)', () {
      final ranked = rankRelatedDefects(const RelatedDefectContext());
      expect(ranked.length, catalogue.entries.length);
      expect(
        ranked.map((e) => e.id).toSet(),
        catalogue.entries.map((e) => e.id).toSet(),
      );
    });
  });

  group('searchRelatedDefects', () {
    test('an empty query returns the ranked list unchanged', () {
      final ranked = rankRelatedDefects(
        const RelatedDefectContext(note: 'holo wall tile'),
      );
      expect(searchRelatedDefects(ranked: ranked, query: ''), ranked);
      expect(searchRelatedDefects(ranked: ranked, query: '   '), ranked);
    });

    test('searches the FULL catalogue across element, component and '
        'defect description', () {
      final ranked = catalogue.entries;
      final sliding = searchRelatedDefects(
        ranked: ranked,
        query: 'sliding door',
      );
      expect(sliding, isNotEmpty);
      expect(
        sliding.every((e) => e.componentName.startsWith('Sliding Door')),
        isTrue,
      );
      // 20 real sliding-door entries in the controlled catalogue.
      expect(sliding.length, 20);

      final gap = searchRelatedDefects(ranked: ranked, query: 'gap');
      expect(gap, isNotEmpty);
      expect(
        gap.every((e) => e.defectDescription.toLowerCase().contains('gap')),
        isTrue,
      );

      final rubber = searchRelatedDefects(ranked: ranked, query: 'rubber');
      expect(rubber, isNotEmpty);
      expect(
        rubber.every(
          (e) => e.defectDescription.toLowerCase().contains('rubber'),
        ),
        isTrue,
      );

      final rusty = searchRelatedDefects(ranked: ranked, query: 'rusty');
      expect(rusty, isNotEmpty);
      expect(
        rusty.every((e) => e.defectDescription.toLowerCase().contains('rusty')),
        isTrue,
      );
    });

    test('Malay/alias terms find the same entries as their English '
        'equivalents', () {
      final ranked = catalogue.entries;
      for (final pair in [
        ('retak', 'crack'),
        ('pintu sliding', 'sliding door'),
        ('karat', 'rusty'),
        ('kosong', 'hollow'),
        ('bocor', 'leak'),
      ]) {
        final aliasResults = searchRelatedDefects(
          ranked: ranked,
          query: pair.$1,
        ).map((e) => e.id).toSet();
        final englishResults = searchRelatedDefects(
          ranked: ranked,
          query: pair.$2,
        ).map((e) => e.id).toSet();
        expect(aliasResults, isNotEmpty, reason: pair.$1);
        expect(
          aliasResults,
          englishResults,
          reason: '${pair.$1} vs ${pair.$2}',
        );
      }
    });

    test('an unmatched query returns no results, never the whole list', () {
      final results = searchRelatedDefects(
        ranked: catalogue.entries,
        query: 'zzznonexistentzzz',
      );
      expect(results, isEmpty);
    });

    test('search narrows a context-ranked list while preserving its '
        'relative order', () {
      final ranked = rankRelatedDefects(
        const RelatedDefectContext(note: 'sliding dr senget'),
      );
      final results = searchRelatedDefects(ranked: ranked, query: 'frame');
      expect(results, isNotEmpty);
      // Still in the same relative order as the unfiltered ranking.
      final expectedOrder = ranked.where((e) => results.contains(e)).toList();
      expect(results, expectedOrder);
    });
  });
}

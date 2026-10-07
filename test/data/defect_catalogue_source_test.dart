import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/entities/defect_catalogue.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';

/// The active master catalogue must equal the DEFECT LIST sheet of
/// DEFECT_REPORT_LIST.xlsx, snapshotted in tool/defect_list_source.json
/// (see tool/extract_defect_list_source.py), and must be identical to the
/// Functions copy (functions/src/ai/defect_catalogue_data.ts).

String _norm(String? s) => (s ?? '')
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'\s*/\s*'), '/')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

/// Positions where the workbook itself carries a typo/artefact that the
/// catalogue deliberately does not copy. Everything else must match.
const _sourceTypoDefects = {39}; // missing full stop: "door leaf Top/ bottom"
const _sourceTypoActions = {113, 125}; // stray " c"; "selant"
const _sourceTypoComponents = {
  183,
  184,
  185,
  186,
  187,
  188,
  189,
}; // "Distributio n Board"

void main() {
  final source = jsonDecode(
    File('tool/defect_list_source.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final rows = (source['entries'] as List).cast<Map<String, dynamic>>();
  final catalogue = DefectCatalogue.instance;
  final master = catalogue.masterEntries;

  test('structure: 11 main elements, 34 components, 222 active defects', () {
    expect(source['elements'], hasLength(11));
    expect(rows, hasLength(222));
    expect(
      rows.map((r) => '${r['element']}|${r['component']}').toSet(),
      hasLength(34),
    );
    expect(catalogue.mainElements, hasLength(11));
    expect(catalogue.components, hasLength(34));
    expect(master, hasLength(222));
    expect(
      catalogue.mainElements.map((m) => _norm(m.name)).toList(),
      (source['elements'] as List).map((e) => _norm(e as String)).toList(),
    );
  });

  test('every catalogue entry equals its source row (same order), '
      'blank hierarchy cells forward-filled', () {
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i], e = master[i];
      expect(
        _norm(e.mainElementName),
        _norm(r['element']),
        reason: 'row $i element',
      );
      if (!_sourceTypoComponents.contains(i)) {
        expect(
          _norm(e.componentName),
          _norm(r['component']),
          reason: 'row $i component',
        );
      }
      if (!_sourceTypoDefects.contains(i)) {
        expect(
          _norm(e.defectDescription),
          _norm(r['defect']),
          reason: 'row $i defect',
        );
      }
      if (!_sourceTypoActions.contains(i)) {
        expect(
          _norm(e.correctiveAction),
          _norm(r['action']),
          reason: 'row $i action',
        );
      }
    }
  });

  test('no normalized duplicate Element + Component + Defect; ids unique', () {
    final keys = master.map(
      (e) =>
          '${_norm(e.mainElementName)}|${_norm(e.componentName)}|${_norm(e.defectDescription)}',
    );
    expect(keys.toSet(), hasLength(master.length));
    expect(master.map((e) => e.id).toSet(), hasLength(master.length));
  });

  test('Door Frame, Sliding Door, Wall and Floor entries match the sheet', () {
    for (final component in [
      'Door Frame',
      'Sliding Door Frame',
      'Sliding Door Panel',
      'Concrete wall',
      'Wall tile',
      'Floor tiles',
    ]) {
      final expected = [
        for (final r in rows)
          if (_norm(r['component']) == _norm(component)) _norm(r['defect']),
      ];
      final actual = [
        for (final e in master)
          if (_norm(e.componentName) == _norm(component))
            _norm(e.defectDescription),
      ];
      expect(expected, isNotEmpty, reason: component);
      expect(actual.length, expected.length, reason: component);
    }
  });

  test(
    'search is over the active catalogue only and returns no duplicates',
    () {
      for (final q in [
        'door frame',
        'sliding',
        'wall',
        'floor',
        'crack',
        'leak',
      ]) {
        final hits = catalogue.search(q);
        expect(hits, isNotEmpty, reason: q);
        expect(
          hits.map((e) => e.id).toSet(),
          hasLength(hits.length),
          reason: q,
        );
        expect(hits.every((e) => catalogue.masterEntries.contains(e)), isTrue);
      }
    },
  );

  test('report lookup resolves every active entry to its description and '
      'corrective action', () {
    for (var i = 0; i < master.length; i++) {
      final e = catalogue.byId(master[i].id)!;
      expect(identical(e, master[i]), isTrue);
      expect(e.defectDescription, isNotEmpty);
    }
  });

  test('Flutter and Functions catalogues are identical (no drift)', () {
    final ts = File('functions/src/ai/defect_catalogue_data.ts')
        .readAsStringSync();
    String? field(String block, String name) {
      final m = RegExp('$name: (null|"((?:[^"\\\\]|\\\\.)*)"),')
          .firstMatch(block);
      return m == null || m.group(1) == 'null'
          ? null
          : m.group(2)!.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }

    final blocks = RegExp(
      r'\{\n(.*?)\n  \},',
      dotAll: true,
    ).allMatches(ts).map((m) => m.group(1)!).toList();
    expect(blocks, hasLength(master.length));
    for (var i = 0; i < blocks.length; i++) {
      final e = master[i];
      expect(field(blocks[i], 'id'), e.id);
      expect(field(blocks[i], 'mainElementName'), e.mainElementName);
      expect(field(blocks[i], 'componentName'), e.componentName);
      expect(field(blocks[i], 'defectDescription'), e.defectDescription);
      expect(field(blocks[i], 'correctiveAction'), e.correctiveAction);
    }
  });
}

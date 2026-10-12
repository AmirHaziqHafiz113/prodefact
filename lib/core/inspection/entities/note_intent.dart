/// What an inspector's quick note settles BY ITSELF, before any photo is
/// considered (2026-10-12) — the on-device twin of
/// `detectStrongNote` in `functions/src/ai/catalogue_shortlist.ts`.
///
/// The note is primary field evidence. When it clearly names a building
/// component ("wal por skim" → wall, Concrete Wall, poor skim/paint
/// finishing) the finding is LOCKED to that component: unrelated
/// components that merely share wording ("poor paint finishing on grill
/// door") must not outrank it, and a failed AI request must not erase
/// what the note already says.
///
/// Deterministic and on-device, never an AI call, and never a source of
/// new defect wording: it only selects among existing catalogue entries.
/// Deliberately a SAFETY NET — the semantic reading of typos/rojak is the
/// AI request's job; this only covers the common field terms in
/// `note_aliases.dart`.
library;

import 'defect_catalogue.dart';
import 'defect_terms.dart';
import 'note_aliases.dart';

/// How much the note settles on its own.
enum NoteConfidenceLevel {
  /// Component AND defect family ("wall poor skim").
  a,

  /// Component only ("wall", "door frame", "sliding door").
  b,

  /// No reliable component ("crack", "stain"): the photo decides.
  c,
}

class NoteIntent {
  const NoteIntent({
    this.level = NoteConfidenceLevel.c,
    this.lockComponentIds = const [],
    this.lockComponentNames = const [],
    this.elementNames = const [],
    this.entryIds = const [],
    this.unlistedTerms = const [],
  });

  static const none = NoteIntent();

  final NoteConfidenceLevel level;

  /// The components the note locks the finding to (empty at level C).
  final List<String> lockComponentIds;
  final List<String> lockComponentNames;

  /// Catalogue element(s) the note names ("Wall"), if any.
  final List<String> elementNames;

  /// Entries whose wording the note fully covers, best first — the
  /// "Likely from your note" candidates.
  final List<String> entryIds;

  /// Parts the note names that the catalogue has no component for
  /// (e.g. "railing"): never forced onto a look-alike.
  final List<String> unlistedTerms;

  bool get isLocked => lockComponentIds.isNotEmpty;
}

const _stopwords = {
  'the', 'a', 'an', 'is', 'are', 'of', 'and', 'or', 'at', 'on', 'in', //
  'with', 'near', 'to', 'not', 'properly', 'very', 'some', 'this', 'that',
  'there', 'have', 'has', 'for', 'from', 'area', 'check', 'see', 'photo',
  'defect', 'issue', 'problem', 'rosak', 'ada', 'yang', 'dan', 'di',
};

/// Parts inspectors name that the controlled catalogue has no component
/// for. Stemmed words; every word of a phrase must appear.
const _unlistedParts = <List<String>>[
  ['railing'],
  ['handrail'],
  ['balustrade'],
  ['staircase'],
  ['stair'],
  ['floor', 'trap'],
  ['cabinet'],
  ['wardrobe'],
  ['countertop'],
  ['fence'],
];

String _stem(String word) {
  if (word.length > 5 && word.endsWith('ing')) {
    return word.substring(0, word.length - 3);
  }
  if (word.length > 4 && word.endsWith('ed')) {
    return word.substring(0, word.length - 2);
  }
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

List<String> _words(String text) => [
  for (final w in text.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
    if (w.length >= 2 && !_stopwords.contains(w)) _stem(w),
];

bool _same(String a, String b) {
  if (a == b) return true;
  final short = a.length <= b.length ? a : b;
  final long = a.length <= b.length ? b : a;
  return short.length >= 4 && long.startsWith(short);
}

/// Reads [note] (aliases/Malay expanded first) against the catalogue.
NoteIntent readNoteIntent(String? note) {
  final trimmed = note?.trim() ?? '';
  if (trimmed.isEmpty) return NoteIntent.none;
  final noteWords = _words(expandNoteAliases(trimmed)).toSet().toList();
  if (noteWords.isEmpty) return NoteIntent.none;

  final all = DefectCatalogue.instance.entries;
  bool mentions(String w) => noteWords.any((n) => _same(n, w));

  final unlisted = [
    for (final phrase in _unlistedParts)
      if (phrase.every(mentions)) phrase,
  ];
  final unlistedWords = {for (final p in unlisted) ...p};

  // Components whose FULL name the note spells out; the most specific
  // first so "sliding door frame" is taken whole.
  final componentNames = <String, String>{};
  for (final e in all) {
    componentNames[e.componentId] = e.componentName;
  }
  final named =
      [
          for (final entry in componentNames.entries)
            (id: entry.key, name: entry.value, ws: _words(entry.value)),
        ].where((c) => c.ws.isNotEmpty && c.ws.every(mentions)).toList()
        ..sort((a, b) => b.ws.length.compareTo(a.ws.length));
  final claimed = <String>{};
  final chosen = <({String id, String name, List<String> ws})>[];
  for (final c in named) {
    if (c.ws.every(claimed.contains) && chosen.isNotEmpty) continue;
    chosen.add(c);
    claimed.addAll(c.ws);
  }
  final finalNamed = [
    for (final c in chosen)
      if (!chosen.any(
        (o) => o != c && o.ws.length > c.ws.length && c.ws.every(o.ws.contains),
      ))
        c,
  ];

  // An element-only note ("wall poor skim") still pins the element's
  // components — but never an uncatalogued part ("floor trap").
  final elementNames = <String, String>{};
  for (final e in all) {
    elementNames[e.mainElementId] = e.mainElementName;
  }
  final namedElements = finalNamed.isEmpty && unlisted.isEmpty
      ? [
          for (final entry in elementNames.entries)
            (id: entry.key, name: entry.value, ws: _words(entry.value)),
        ].where((el) => el.ws.isNotEmpty && el.ws.every(mentions)).toList()
      : const <({String id, String name, List<String> ws})>[];

  final componentWords = {
    for (final c in finalNamed) ...c.ws,
    for (final el in namedElements) ...el.ws,
  };

  final slidingNote = mentions('slid');
  var lockPool = <DefectCatalogueEntry>[];
  if (finalNamed.isNotEmpty) {
    lockPool = [
      for (final e in all)
        if (finalNamed.any((c) => c.id == e.componentId)) e,
    ];
  } else if (namedElements.isNotEmpty) {
    lockPool = [
      for (final e in all)
        if (namedElements.any((el) => el.id == e.mainElementId)) e,
    ];
    if (slidingNote) {
      final sliding = [
        for (final e in lockPool)
          if (e.componentName.toLowerCase().contains('sliding')) e,
      ];
      if (sliding.isNotEmpty) lockPool = sliding;
    }
  }
  // "sliding" qualifies the component just locked; it is not a defect word.
  final qualifierLocked =
      slidingNote &&
      lockPool.isNotEmpty &&
      lockPool.every((e) => e.componentName.toLowerCase().contains('sliding'));
  final defectWords = [
    for (final w in noteWords)
      if (!componentWords.any((c) => _same(c, w)) &&
          !unlistedWords.any((u) => _same(u, w)) &&
          !(qualifierLocked && _same(w, 'slid')))
        w,
  ];
  final pool = lockPool.isNotEmpty ? lockPool : all;
  // With a locked component one more word is enough ("railing paint");
  // without one the note must spell out a defect ("poor paint").
  final needed = lockPool.isNotEmpty ? 1 : 2;
  final entryIds = defectWords.length >= needed
      ? [
          for (final e in pool)
            if (_covers(e, defectWords)) e.id,
        ].take(12).toList()
      : <String>[];

  final lockEntries = lockPool.isNotEmpty && entryIds.isNotEmpty
      ? [
          for (final e in all)
            if (entryIds.contains(e.id)) e,
        ]
      : lockPool;
  final lockIds = <String>[];
  for (final e in lockEntries) {
    if (!lockIds.contains(e.componentId)) lockIds.add(e.componentId);
  }
  return NoteIntent(
    level: lockIds.isEmpty
        ? NoteConfidenceLevel.c
        : entryIds.isNotEmpty
        ? NoteConfidenceLevel.a
        : NoteConfidenceLevel.b,
    lockComponentIds: lockIds,
    lockComponentNames: [for (final id in lockIds) componentNames[id] ?? id],
    elementNames: [for (final el in namedElements) el.name],
    entryIds: entryIds,
    unlistedTerms: [for (final p in unlisted) p.join(' ')],
  );
}

bool _covers(DefectCatalogueEntry e, List<String> defectWords) {
  final dw = [
    ..._words(e.defectDescription),
    for (final t in defectTermsFor(e.defectDescription)) ..._words(t),
  ];
  return defectWords.every((w) => dw.any((d) => _same(d, w)));
}

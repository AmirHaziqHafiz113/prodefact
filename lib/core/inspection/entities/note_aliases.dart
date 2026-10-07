/// Inspector shorthand aliases, for on-device search only (2026-10-06).
///
/// Mirrors the alias dictionary in `functions/src/ai/inspector_note.ts`
/// (`EXPANSIONS`) so a search term like "pintu sliding", "retak" or
/// "rusty" reaches the same catalogue entries that classification does.
/// Kept as its own, smaller copy on purpose: this is a client-side,
/// deterministic text aid for the searchable defect picker — it never
/// touches a saved inspector note, and never calls an AI provider.
library;

const Map<String, String> kInspectorNoteAliases = {
  // English shorthand / phonetic spellings
  'holo': 'hollow',
  'hallow': 'hollow',
  'holoww': 'hollow',
  'lekang': 'hollow',
  'hollo': 'hollow',
  'holow': 'hollow',
  'hollw': 'hollow',
  'frem': 'frame',
  'fram': 'frame',
  'frm': 'frame',
  'win': 'window',
  'wdw': 'window',
  'wndw': 'window',
  'windw': 'window',
  'dr': 'door',
  'dore': 'door',
  'dor': 'door',
  'slidng': 'sliding',
  'sliiding': 'sliding',
  'flr': 'floor',
  'clg': 'ceiling',
  'ceil': 'ceiling',
  'celing': 'ceiling',
  'wl': 'wall',
  'crk': 'crack',
  'crak': 'crack',
  'krak': 'crack',
  'cracj': 'crack',
  'tl': 'tile',
  'tyle': 'tile',
  'skm': 'skim',
  'pnt': 'paint',
  'unevn': 'uneven',
  'uneve': 'uneven',
  'lkg': 'leaking',
  'leek': 'leak',
  'dmg': 'damage',
  'dmgd': 'damaged',
  'misalign': 'misaligned',
  'stn': 'stain',
  'scrtch': 'scratch',
  'scrach': 'scratch',
  'sealnt': 'sealant',
  'silicon': 'silicone',
  'grt': 'grout',
  'cab': 'cabinet',
  'cabnet': 'cabinet',
  'sktg': 'skirting',
  'skirt': 'skirting',
  'wc': 'toilet',
  'bth': 'bathroom',
  'mbr': 'master bedroom',
  'mbth': 'master bathroom',
  // Sliding doors — never collapse into generic doors.
  'pintu gelongsor': 'sliding door',
  'pintu sliding': 'sliding door',
  'sliding pintu': 'sliding door',
  'glass door': 'sliding door glass',
  'pintu kaca': 'sliding door glass',
  'gelongsor': 'sliding',
  // Malay (BM)
  'retak': 'crack',
  'keretakan': 'crack',
  'bocor': 'leak',
  'rosak': 'damaged',
  'pecah': 'broken',
  'kemek': 'dent',
  'calar': 'scratch',
  'kotor': 'dirty',
  'tompok': 'stain',
  'kesan air': 'water stain',
  'air bertakung': 'water ponding',
  'bertakung': 'ponding',
  'takung': 'ponding',
  'berlubang': 'hole',
  'lubang': 'hole',
  'tak rata': 'uneven',
  'tidak rata': 'uneven',
  'senget': 'not aligned slanted',
  'tak align': 'not aligned',
  'x align': 'not aligned',
  'tidak align': 'not aligned',
  'tak lurus': 'not straight',
  'tombol': 'knob handle',
  'pemegang': 'handle',
  'engsel': 'hinge',
  'kunci': 'lock',
  'kaca': 'glass',
  'bingkai tingkap': 'window frame',
  'kepala paip': 'water tap',
  'pili': 'tap',
  'mangkuk tandas': 'toilet bowl',
  'karat': 'rusty',
  'berkarat': 'rusty',
  'sompek': 'chipped',
  'sumbing': 'chipped',
  'kesan': 'stain',
  'silikon': 'sealant',
  'getah': 'rubber seal',
  'skru': 'screw',
  'hilang': 'missing',
  'tiada': 'missing',
  'takde': 'missing',
  'berbunyi': 'creaking sound',
  'bunyi': 'sound',
  'tersumbat': 'clogged',
  'sumbat': 'clogged',
  'tak jalan': 'not functioning',
  'tak berfungsi': 'not functioning',
  'rekahan': 'crack',
  'longgar': 'loose',
  'kosong': 'hollow',
  'jubin': 'tile',
  'dinding': 'wall',
  'lantai': 'floor',
  'siling': 'ceiling',
  'tingkap': 'window',
  'pintu': 'door',
  'bingkai': 'frame',
  'paip': 'pipe',
  'sinki': 'sink',
  'tandas': 'toilet',
  'bilik air': 'bathroom',
  'dapur': 'kitchen',
  'cat': 'paint',
  'celah': 'gap',
  'renggang': 'gap',
  'perangkap lantai': 'floor trap',
  'perangkap': 'trap',
  'flo': 'floor',
  'por': 'poor',
  'pur': 'poor',
  'peint': 'paint',
  'railng': 'railing',
  'railin': 'railing',
  'raling': 'railing',
  'railings': 'railing',
};

/// Multi-word alias keys, longest first, so "pintu sliding" is matched
/// as one phrase before "pintu" and "sliding" are expanded separately.
final List<String> kInspectorNotePhrases =
    kInspectorNoteAliases.keys.where((key) => key.contains(' ')).toList()
      ..sort((a, b) => b.length.compareTo(a.length));

/// Expands known shorthand/Malay/English aliases in [text] (lower-cased
/// first); anything not recognised is left as-is. Deterministic, no AI
/// call — used only to widen on-device search, never to alter what the
/// inspector actually typed anywhere else.
///
/// Note: unlike JavaScript, `String.split` in Dart discards whatever a
/// capturing-group pattern matched rather than keeping it in the
/// result, so the naive "split on separators, map each token, rejoin"
/// trick (fine in the backend's TypeScript twin) silently eats every
/// space here. `replaceAllMapped` over word characters only, leaving
/// everything else untouched, sidesteps that entirely.
String expandNoteAliases(String text) {
  var working = text.toLowerCase();
  for (final phrase in kInspectorNotePhrases) {
    final pattern = RegExp('\\b${RegExp.escape(phrase)}\\b');
    working = working.replaceAll(pattern, kInspectorNoteAliases[phrase]!);
  }
  return working.replaceAllMapped(
    RegExp(r'[a-z0-9]+'),
    (match) => kInspectorNoteAliases[match.group(0)] ?? match.group(0)!,
  );
}

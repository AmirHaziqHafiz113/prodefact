/// Makes [input] printable with the PDF's built-in Helvetica.
///
/// Why this exists: `package:pdf`'s built-in (Type 1) fonts encode text
/// as Latin-1. Any character outside it — an em dash "—" the report
/// itself used as a separator, a curly quote or ellipsis that a phone
/// keyboard auto-inserts into a note — has no glyph and printed as a
/// "▯" box. Every string the report renders goes through here.
///
/// Common typography maps to its plain equivalent; any other character
/// outside Latin-1 (e.g. an emoji) becomes "?", visibly, rather than a
/// box or a silently dropped character.
String pdfSafeText(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    final mapped = _replacements[rune];
    if (mapped != null) {
      out.write(mapped);
    } else if (rune == 0x0A || rune == 0x09) {
      out.writeCharCode(rune);
    } else if (rune < 0x20 || (rune >= 0x7F && rune < 0xA0)) {
      // Control characters have no glyph either.
      out.write(' ');
    } else if (rune <= 0xFF) {
      out.writeCharCode(rune);
    } else {
      out.write('?');
    }
  }
  return out.toString();
}

const Map<int, String> _replacements = {
  0x2010: '-', // hyphen
  0x2011: '-', // non-breaking hyphen
  0x2012: '-', // figure dash
  0x2013: '-', // en dash
  0x2014: '-', // em dash
  0x2015: '-', // horizontal bar
  0x2212: '-', // minus sign
  0x2018: "'", // left single quote
  0x2019: "'", // right single quote / apostrophe
  0x201A: "'",
  0x201B: "'",
  0x2032: "'", // prime
  0x201C: '"', // left double quote
  0x201D: '"', // right double quote
  0x201E: '"',
  0x201F: '"',
  0x2033: '"', // double prime
  0x2026: '...', // ellipsis
  0x2022: '-', // bullet
  0x2023: '-',
  0x2043: '-',
  0x25AA: '-',
  0x25CF: '-',
  0x2002: ' ', // en space
  0x2003: ' ', // em space
  0x2007: ' ',
  0x2009: ' ', // thin space
  0x200A: ' ',
  0x202F: ' ',
  0x200B: '', // zero-width space
  0x200C: '',
  0x200D: '',
  0x2060: '',
  0xFEFF: '', // byte order mark
  0x20AC: 'EUR',
  0x2122: '(TM)',
  0x2192: '->',
  0x2190: '<-',
  0x2264: '<=',
  0x2265: '>=',
  0x2248: '~',
};

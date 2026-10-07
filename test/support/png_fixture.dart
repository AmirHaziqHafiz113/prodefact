import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// A real, decodable [width] x [height] solid-colour PNG — no image
/// library needed.
Uint8List pngBytes(int width, int height) {
  final out = BytesBuilder();
  void chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    out
      ..add(Uint8List(4)..buffer.asByteData().setUint32(0, data.length))
      ..add(body)
      ..add(Uint8List(4)..buffer.asByteData().setUint32(0, _crc(body)));
  }

  out.add([137, 80, 78, 71, 13, 10, 26, 10]);
  chunk(
    'IHDR',
    Uint8List(13)
      ..buffer.asByteData().setUint32(0, width)
      ..buffer.asByteData().setUint32(4, height)
      ..[8] = 8
      ..[9] = 2,
  );
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    for (var x = 0; x < width; x++) {
      raw.add([30, 120, 200]);
    }
  }
  chunk('IDAT', ZLibEncoder().convert(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

/// Writes a PNG into [dir] and returns its path.
String writePng(Directory dir, String name, int width, int height) {
  final file = File('${dir.path}/$name.png')
    ..writeAsBytesSync(pngBytes(width, height));
  return file.path;
}

/// Minimal ZIP handling for Guitar Pro `.gp` (GP7/GP8) files, which are ZIP
/// archives holding `Content/score.gpif`. Uses `dart:io`'s DEFLATE codec, so
/// it stays out of the web-safe core. (GP6 `.gpx` uses a different, non-ZIP
/// container and is not supported.)
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Extracts the `score.gpif` XML from a `.gp` archive's [bytes].
String readGpifFromGp(Uint8List bytes) {
  // Locate the End Of Central Directory record.
  var eocd = bytes.length - 22;
  while (eocd >= 0 && _u32(bytes, eocd) != 0x06054b50) {
    eocd--;
  }
  if (eocd < 0) throw const FormatException('not a .gp (zip) file');
  final count = _u16(bytes, eocd + 10);
  var p = _u32(bytes, eocd + 16); // central directory offset

  for (var e = 0; e < count; e++) {
    if (_u32(bytes, p) != 0x02014b50) break;
    final method = _u16(bytes, p + 10);
    final compSize = _u32(bytes, p + 20);
    final nameLen = _u16(bytes, p + 28);
    final extraLen = _u16(bytes, p + 30);
    final commentLen = _u16(bytes, p + 32);
    final localOffset = _u32(bytes, p + 42);
    final name = utf8.decode(bytes.sublist(p + 46, p + 46 + nameLen));
    if (name.endsWith('score.gpif')) {
      final lNameLen = _u16(bytes, localOffset + 26);
      final lExtraLen = _u16(bytes, localOffset + 28);
      final dataStart = localOffset + 30 + lNameLen + lExtraLen;
      final comp = bytes.sublist(dataStart, dataStart + compSize);
      final raw = method == 0
          ? comp
          : Uint8List.fromList(ZLibDecoder(raw: true).convert(comp));
      return utf8.decode(raw);
    }
    p += 46 + nameLen + extraLen + commentLen;
  }
  throw const FormatException('Content/score.gpif not found in .gp');
}

/// Packs [gpif] into a minimal `.gp` archive (a ZIP with a single stored
/// `Content/score.gpif` entry).
Uint8List writeGpFromGpif(String gpif) {
  final name = ascii.encode('Content/score.gpif');
  final data = utf8.encode(gpif);
  final crc = _crc32(data);
  final out = BytesBuilder();

  // Local file header (method 0 = stored).
  out.add(_le32(0x04034b50));
  out.add(_le16(20)); // version needed
  out.add(_le16(0)); // flags
  out.add(_le16(0)); // method: stored
  out.add(_le16(0)); // mod time
  out.add(_le16(0x21)); // mod date (valid non-zero)
  out.add(_le32(crc));
  out.add(_le32(data.length)); // compressed size
  out.add(_le32(data.length)); // uncompressed size
  out.add(_le16(name.length));
  out.add(_le16(0)); // extra length
  out.add(name);
  out.add(data);

  final cdOffset = out.length;
  // Central directory record.
  out.add(_le32(0x02014b50));
  out.add(_le16(20)); // version made by
  out.add(_le16(20)); // version needed
  out.add(_le16(0)); // flags
  out.add(_le16(0)); // method
  out.add(_le16(0)); // mod time
  out.add(_le16(0x21)); // mod date
  out.add(_le32(crc));
  out.add(_le32(data.length));
  out.add(_le32(data.length));
  out.add(_le16(name.length));
  out.add(_le16(0)); // extra
  out.add(_le16(0)); // comment
  out.add(_le16(0)); // disk number
  out.add(_le16(0)); // internal attrs
  out.add(_le32(0)); // external attrs
  out.add(_le32(0)); // local header offset
  out.add(name);
  final cdSize = out.length - cdOffset;

  // End of central directory.
  out.add(_le32(0x06054b50));
  out.add(_le16(0)); // disk number
  out.add(_le16(0)); // cd start disk
  out.add(_le16(1)); // entries on this disk
  out.add(_le16(1)); // total entries
  out.add(_le32(cdSize));
  out.add(_le32(cdOffset));
  out.add(_le16(0)); // comment length
  return out.toBytes();
}

int _u16(Uint8List b, int at) => b[at] | (b[at + 1] << 8);
int _u32(Uint8List b, int at) =>
    b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);
List<int> _le16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
List<int> _le32(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

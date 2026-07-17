/// Container handling for the MuseScore `.mscz` file — a ZIP holding the
/// `.mscx` score XML alongside `META-INF/container.xml` (and, in real files,
/// thumbnails / metadata we ignore). Reading inflates whichever entry ends in
/// `.mscx`; writing packs a minimal two-entry archive MuseScore can open. Pure
/// Dart (web-safe): deflated entries inflate through the in-repo [inflate], so
/// no `dart:io` — reads work in the browser / WASM too.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'deflate.dart';
import 'zip.dart';

/// Extracts the `.mscx` XML from a `.mscz` archive's [bytes]. Handles both
/// stored (method 0) and deflated (method 8) entries via the shared,
/// bounds-checked [readZipEntry] (a corrupt archive rejects with a
/// FormatException rather than crashing).
String readMscxFromMscz(Uint8List bytes) {
  final entry =
      readZipEntry(bytes, (name) => name.toLowerCase().endsWith('.mscx'));
  if (entry == null) {
    throw const FormatException('no .mscx entry found in .mscz');
  }
  return utf8.decode(entry);
}

/// Points MuseScore at the score entry inside the archive.
const _containerXml = '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<container><rootfiles>'
    '<rootfile full-path="score.mscx"/>'
    '</rootfiles></container>\n';

/// Packs [mscx] into a minimal `.mscz` archive: `META-INF/container.xml`
/// pointing at a deflated `score.mscx`.
Uint8List writeMsczFromMscx(String mscx) => _zip([
      ('META-INF/container.xml', utf8.encode(_containerXml)),
      ('score.mscx', utf8.encode(mscx)),
    ]);

/// Builds a ZIP archive of [entries] (name, bytes) with deflated records —
/// readable by MuseScore and any ZIP tool, and dependency-free.
Uint8List _zip(List<(String, List<int>)> entries) {
  final out = BytesBuilder();
  final directory = BytesBuilder();
  var count = 0;
  for (final (path, data) in entries) {
    final name = utf8.encode(path);
    final comp = deflate(Uint8List.fromList(data));
    final crc = _crc32(data);
    final localOffset = out.length;

    // Local file header (method 8 = deflate).
    out.add(_le32(0x04034b50));
    out.add(_le16(20)); // version needed
    out.add(_le16(0)); // flags
    out.add(_le16(8)); // method: deflate
    out.add(_le16(0)); // mod time
    out.add(_le16(0x21)); // mod date (valid non-zero)
    out.add(_le32(crc));
    out.add(_le32(comp.length)); // compressed size
    out.add(_le32(data.length)); // uncompressed size
    out.add(_le16(name.length));
    out.add(_le16(0)); // extra length
    out.add(name);
    out.add(comp);

    // Central directory record.
    directory.add(_le32(0x02014b50));
    directory.add(_le16(20)); // version made by
    directory.add(_le16(20)); // version needed
    directory.add(_le16(0)); // flags
    directory.add(_le16(8)); // method: deflate
    directory.add(_le16(0)); // mod time
    directory.add(_le16(0x21)); // mod date
    directory.add(_le32(crc));
    directory.add(_le32(comp.length));
    directory.add(_le32(data.length));
    directory.add(_le16(name.length));
    directory.add(_le16(0)); // extra
    directory.add(_le16(0)); // comment
    directory.add(_le16(0)); // disk number
    directory.add(_le16(0)); // internal attrs
    directory.add(_le32(0)); // external attrs
    directory.add(_le32(localOffset));
    directory.add(name);
    count++;
  }

  final cdOffset = out.length;
  final cd = directory.toBytes();
  out.add(cd);

  // End of central directory.
  out.add(_le32(0x06054b50));
  out.add(_le16(0)); // disk number
  out.add(_le16(0)); // cd start disk
  out.add(_le16(count)); // entries on this disk
  out.add(_le16(count)); // total entries
  out.add(_le32(cd.length));
  out.add(_le32(cdOffset));
  out.add(_le16(0)); // comment length
  return out.toBytes();
}

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

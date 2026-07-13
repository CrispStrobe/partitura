import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:partitura_cli/src/crispembed_omr.dart';
import 'package:test/test.dart';

void main() {
  group('decodeOmrImage', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('omr_test'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('decodes a PNG into an RGBA OmrImage of the right size', () {
      final png = img.Image(width: 8, height: 5);
      img.fill(png, color: img.ColorRgb8(255, 255, 255));
      final path = '${tmp.path}/staff.png';
      File(path).writeAsBytesSync(img.encodePng(png));

      final image = decodeOmrImage(path);
      expect(image.width, 8);
      expect(image.height, 5);
      expect(image.channels, 4);
      expect(image.pixels.length, 8 * 5 * 4);
    });

    test('throws a clear error on an undecodable file', () {
      final path = '${tmp.path}/not-an-image.png';
      File(path).writeAsStringSync('this is not a PNG');
      expect(() => decodeOmrImage(path), throwsA(isA<OmrEngineException>()));
    });
  });

  group('CrispEmbedOmrEngine.load', () {
    test('reports a missing model without touching the native library', () {
      expect(
        () => CrispEmbedOmrEngine.load('/no/such/model.gguf'),
        throwsA(isA<OmrEngineException>().having(
            (e) => e.message, 'message', contains('model not found'))),
      );
    });

    test('reports a missing native library', () {
      final tmp = Directory.systemTemp.createTempSync('omr_lib');
      final model = '${tmp.path}/fake.gguf';
      File(model).writeAsBytesSync([0, 1, 2, 3]);
      addTearDown(() => tmp.deleteSync(recursive: true));
      expect(
        () => CrispEmbedOmrEngine.load(model,
            libraryPath: '/no/such/libcrispembed.dylib'),
        throwsA(isA<OmrEngineException>()),
      );
    });
  });
}

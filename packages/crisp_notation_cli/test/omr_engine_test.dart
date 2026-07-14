import 'dart:io';

import 'package:crisp_notation_cli/src/crispembed_omr.dart';
import 'package:image/image.dart' as img;
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
        throwsA(isA<OmrEngineException>()
            .having((e) => e.message, 'message', contains('model not found'))),
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

  group('resolveOmrModel', () {
    test('registry lists the three OMR engines', () {
      expect(omrModelRegistry.keys,
          containsAll(['smt-grandstaff', 'tromr', 'flova']));
    });

    test('returns an existing file path unchanged', () async {
      final dir = Directory.systemTemp.createTempSync('omr_model');
      addTearDown(() => dir.deleteSync(recursive: true));
      final f = File('${dir.path}/mine.gguf')..writeAsBytesSync([1, 2, 3]);
      expect(await resolveOmrModel(f.path), f.path);
    });

    test('throws for an unknown name (no download attempted)', () {
      expect(resolveOmrModel('definitely-not-a-model'),
          throwsA(isA<OmrEngineException>()));
    });

    test('returns a cached model without downloading', () async {
      final dir = Directory.systemTemp.createTempSync('omr_cache');
      addTearDown(() => dir.deleteSync(recursive: true));
      // Pre-populate the cache so no network is touched.
      File('${dir.path}/smt-grandstaff-q8_0.gguf').writeAsBytesSync([0, 1]);
      expect(await resolveOmrModel('smt-grandstaff', cacheDir: dir.path),
          '${dir.path}/smt-grandstaff-q8_0.gguf');
    });
  });

  group('segmentStaffSystems', () {
    img.Image twoBands() {
      final image = img.Image(width: 120, height: 120);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      // Two dark bands separated by a wide white gap.
      img.fillRect(image,
          x1: 0, y1: 12, x2: 119, y2: 40, color: img.ColorRgb8(0, 0, 0));
      img.fillRect(image,
          x1: 0, y1: 75, x2: 119, y2: 105, color: img.ColorRgb8(0, 0, 0));
      return image;
    }

    test('splits a two-system page into two crops', () {
      final crops = segmentStaffSystems(twoBands());
      expect(crops.length, 2);
      // Each crop is a horizontal slice (full width, part height).
      expect(crops.every((c) => c.width == 120), isTrue);
      expect(crops.every((c) => c.height < 120), isTrue);
    });

    test('a single-band image is returned whole (one element)', () {
      final image = img.Image(width: 120, height: 120);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      img.fillRect(image,
          x1: 0, y1: 40, x2: 119, y2: 80, color: img.ColorRgb8(0, 0, 0));
      final crops = segmentStaffSystems(image);
      expect(crops.length, 1);
      expect(crops.single.height, 120);
    });

    test('a blank image yields no split', () {
      final image = img.Image(width: 60, height: 60);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      expect(segmentStaffSystems(image).length, 1);
    });

    test('splits three systems, including bands at the image edges', () {
      final image = img.Image(width: 100, height: 200);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      for (final (y1, y2) in [(0, 30), (70, 110), (160, 199)]) {
        img.fillRect(image,
            x1: 0, y1: y1, x2: 99, y2: y2, color: img.ColorRgb8(0, 0, 0));
      }
      final crops = segmentStaffSystems(image);
      expect(crops.length, 3);
      // The union of crop heights (minus overlap from padding) covers the page.
      expect(
          crops.map((c) => c.height).reduce((a, b) => a + b), greaterThan(100));
    });

    test('a small gap keeps bands in one system (minGapRows)', () {
      final image = img.Image(width: 100, height: 120);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      // Two dark strips 5 rows apart — within one staff, not two systems.
      img.fillRect(image,
          x1: 0, y1: 20, x2: 99, y2: 40, color: img.ColorRgb8(0, 0, 0));
      img.fillRect(image,
          x1: 0, y1: 46, x2: 99, y2: 70, color: img.ColorRgb8(0, 0, 0));
      expect(segmentStaffSystems(image, minGapRows: 12).length, 1);
    });
  });

  group('resolveOmrModel names', () {
    test('the smt alias resolves to the grand-staff q8_0 file', () async {
      final dir = Directory.systemTemp.createTempSync('omr_alias');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/smt-grandstaff-q8_0.gguf').writeAsBytesSync([1]);
      expect(await resolveOmrModel('smt', cacheDir: dir.path),
          endsWith('smt-grandstaff-q8_0.gguf'));
    });

    test('flova and tromr map to their own files', () async {
      final dir = Directory.systemTemp.createTempSync('omr_names');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/flova-q8_0.gguf').writeAsBytesSync([1]);
      File('${dir.path}/tromr-q8_0.gguf').writeAsBytesSync([1]);
      expect(await resolveOmrModel('flova', cacheDir: dir.path),
          endsWith('flova-q8_0.gguf'));
      expect(await resolveOmrModel('tromr', cacheDir: dir.path),
          endsWith('tromr-q8_0.gguf'));
    });
  });
}

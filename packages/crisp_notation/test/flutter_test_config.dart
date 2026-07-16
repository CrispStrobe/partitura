import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// `flutter_test` auto-loads this before any test in the suite.
///
/// Golden (pixel) baselines are host-specific: Skia rasterises text with
/// slightly different anti-aliasing across machines and OS point-releases, so a
/// baseline authored on one Mac shows a 2–5% per-pixel diff on a GitHub macOS
/// runner even with no code change. The baselines here are authored locally and
/// are a **local** engraving-regression gate — regenerate with
/// `flutter test --update-goldens` and eyeball the diff.
///
/// So under CI (GitHub Actions sets `CI=true`) we swap in a comparator that
/// skips the pixel compare. Everything else in the suite — the ~300
/// widget-behaviour tests: hit-testing, gestures, relayout policy, semantics,
/// paint-happened assertions — is portable and still runs and gates merges.
/// The image bytes are still produced (the widget must build and paint), only
/// the final pixel diff is waived.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.environment['CI'] == 'true') {
    goldenFileComparator = _SkipGoldenComparator();
    // ignore: avoid_print
    print('CI: golden pixel comparison skipped (host-specific rasterisation); '
        'widget-behaviour tests still run. Goldens are gated locally.');
  }
  await testMain();
}

/// Accepts any golden: the render still has to build and paint to reach here.
class _SkipGoldenComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}

// Blind reader-robustness fuzz for the legacy binary GP readers (covfuzz).
// Seeds from real files so mutations reach deep parse paths; a clean parse or a
// FormatException is the contract — any other throw is an escape.
//   dart run tool/fuzz_gp.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:covfuzz/covfuzz.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';

void main() {
  const dir = 'test/data/gp';
  Uint8List seed(String f) => File('$dir/$f').readAsBytesSync();
  final targets = <String, (Uint8List, void Function(Uint8List))>{
    'gp3ToScore': (seed('effects.gp3'), gp3ToScore),
    'gp4ToScore': (seed('effects.gp4'), gp4ToScore),
    'gp5ToScore': (seed('effects.gp5'), gp5ToScore),
    'gpToMultiPart': (seed('effects.gp5'), (b) => gpToMultiPart(b)),
  };
  var code = 0;
  targets.forEach((name, t) {
    stdout.writeln('── fuzz $name ──');
    final r = fuzz<Uint8List>(
      seeds: [t.$1],
      entry: t.$2,
      mutate: mutateBytes,
      isClean: (e) => e is FormatException,
      iterations: 400000,
      budgetMs: 18000,
      stressors: [Uint8List(0), Uint8List(4), Uint8List(200000)],
    );
    code |= r.report();
  });
  exit(code);
}

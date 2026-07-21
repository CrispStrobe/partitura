// Coverage-guided fuzz for the binary GP reader (covfuzz tier 2). Reaches paths
// behind the version-magic + precondition checks that blind mutation can't.
// Run with the VM service on:
//   dart run --enable-vm-service=0 --no-pause-isolates-on-exit tool/covfuzz_gp.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:covfuzz/covfuzz.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';

Future<void> main() async {
  const dir = 'test/data/gp';
  Uint8List seed(String f) => File('$dir/$f').readAsBytesSync();
  final r = await covFuzz<Uint8List>(
    seeds: [seed('effects.gp5'), seed('effects.gp4'), seed('effects.gp3')],
    entry: (b) => gpToMultiPart(b),
    mutate: mutateBytes,
    targetLib: 'package:crisp_notation_core/src/gp/gp_binary_reader.dart',
    isClean: (e) => e is FormatException,
    iterations: 20000,
    budgetMs: 35000,
    corpusDir: '.corpus/gp',
    crashDir: '.crashes/gp',
    log: true,
  );
  exit(r.report());
}

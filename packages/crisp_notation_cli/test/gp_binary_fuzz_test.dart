import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Crash-safety fuzz for the legacy binary GP readers: mutate real files every
/// which way and require a clean parse or a FormatException — never a raw
/// RangeError / StateError / other crash. Seeds from the vendored fixtures
/// (no binary writer exists to synthesise from).
void main() {
  const dir = 'test/data/gp';
  const seeds = 400;

  final targets = <String, void Function(Uint8List)>{
    'gp3ToScore': gp3ToScore,
    'gp4ToScore': gp4ToScore,
    'gp5ToScore': gp5ToScore,
    'gpToMultiPart': (b) => gpToMultiPart(b),
  };
  final samples = <String, Uint8List>{
    'gp3': File('$dir/effects.gp3').readAsBytesSync(),
    'gp4': File('$dir/effects.gp4').readAsBytesSync(),
    'gp5': File('$dir/effects.gp5').readAsBytesSync(),
  };

  Uint8List mutate(Uint8List b, Random r) {
    final l = b.toList();
    switch (r.nextInt(6)) {
      case 0: // truncate tail
        l.removeRange(r.nextInt(l.length), l.length);
      case 1: // delete a run
        final at = r.nextInt(l.length);
        l.removeRange(at, min(l.length, at + 1 + r.nextInt(32)));
      case 2: // corrupt bytes
        for (var k = 0; k < 1 + r.nextInt(16); k++) {
          l[r.nextInt(l.length)] = r.nextInt(256);
        }
      case 3: // insert bytes
        for (var k = 0; k < 1 + r.nextInt(8); k++) {
          l.insert(r.nextInt(l.length), r.nextInt(256));
        }
      case 4: // drop head
        l.removeRange(0, r.nextInt(l.length));
      default: // flip high bits (large counts/frets)
        for (var k = 0; k < 1 + r.nextInt(16); k++) {
          l[r.nextInt(l.length)] |= 0x80;
        }
    }
    return Uint8List.fromList(l);
  }

  test('binary GP readers reject malformed bytes cleanly ($seeds mutations)',
      () {
    final r = Random(1234);
    for (var i = 0; i < seeds; i++) {
      for (final s in samples.values) {
        final m = mutate(s, r);
        targets.forEach((name, read) {
          try {
            read(m);
          } on FormatException {
            // clean rejection — the contract.
          } catch (e) {
            fail('$name crashed on malformed bytes with ${e.runtimeType}: $e');
          }
        });
      }
    }
  });
}

import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  test('C6 and Am7 are both readings of {0,4,7,9}', () {
    final byRoot = {
      for (final r in chordReadings({0, 4, 7, 9}))
        (r.root.midiNumber % 12): r.type,
    };
    expect(byRoot[0], ChordType.majorSixth); // C6
    expect(byRoot[9], ChordType.minorSeventh); // Am7
    // Root position (no bass given) → plain symbols.
    final symbols = chordReadings({0, 4, 7, 9}).map((r) => r.symbol).toSet();
    expect(symbols, containsAll(['C6', 'Am7']));
  });

  test('the bass drives which reading comes first', () {
    expect(chordReadings({0, 4, 7, 9}, bassPc: 0).first.type,
        ChordType.majorSixth);
    expect(chordReadings({0, 4, 7, 9}, bassPc: 9).first.type,
        ChordType.minorSeventh);
  });

  test('a diminished seventh reads four equivalent ways', () {
    final r = chordReadings({0, 3, 6, 9});
    expect(r, hasLength(4)); // C°7 = E♭°7 = G♭°7 = A°7
    expect(r.every((c) => c.type == ChordType.diminishedSeventh), isTrue);
    expect(r.map((c) => c.root.midiNumber % 12).toSet(), {0, 3, 6, 9});
  });

  test('an augmented triad reads three ways', () {
    final r = chordReadings({0, 4, 8});
    expect(r, hasLength(3));
    expect(r.every((c) => c.type == ChordType.augmented), isTrue);
  });

  test('a plain major triad has a single reading', () {
    expect(chordReadings({0, 4, 7}).map((r) => r.symbol), ['C']);
  });

  test('the bass produces an inversion', () {
    final r = chordReadings({0, 4, 7}, bassPc: 4); // E in the bass
    expect(r.first.symbol, 'C/E');
    expect(r.first.inversion, 1);
  });

  test('fewer than three pitch classes → no readings', () {
    expect(chordReadings({0, 7}), isEmpty);
  });
}

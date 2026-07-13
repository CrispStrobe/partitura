import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  // Strength of the n/d position (fraction of a whole note from the downbeat).
  double at(TimeSignature t, int n, int d) => t.beatStrength(Fraction(n, d));

  group('beatStrength — simple meters', () {
    test('4/4: downbeat 1, mid-measure ½, beats ¼, eighths ⅛', () {
      const t = TimeSignature.fourFour;
      expect(at(t, 0, 1), 1.0); // downbeat
      expect(at(t, 1, 4), 0.25); // beat 2
      expect(at(t, 1, 2), 0.5); // beat 3 (mid-measure)
      expect(at(t, 3, 4), 0.25); // beat 4
      expect(at(t, 1, 8), 0.125); // eighth offbeat
      expect(at(t, 3, 8), 0.125);
    });

    test('2/4: downbeat 1, beat 2 ½, eighths ¼', () {
      const t = TimeSignature.twoFour;
      expect(at(t, 0, 1), 1.0);
      expect(at(t, 1, 4), 0.5);
      expect(at(t, 1, 8), 0.25);
    });

    test('3/4: both weak beats are ½ (no mid-measure bisection)', () {
      const t = TimeSignature.threeFour;
      expect(at(t, 0, 1), 1.0);
      expect(at(t, 1, 4), 0.5); // beat 2
      expect(at(t, 1, 2), 0.5); // beat 3
      expect(at(t, 1, 8), 0.25); // eighth offbeat
    });

    test('cut time (2/2): beat 2 at the half note is ½', () {
      const t = TimeSignature.cutTime;
      expect(at(t, 0, 1), 1.0);
      expect(at(t, 1, 2), 0.5); // beat 2 (half note)
      expect(at(t, 1, 4), 0.25); // quarter subdivision
      expect(at(t, 3, 4), 0.25);
      expect(at(t, 1, 8), 0.125);
    });
  });

  group('beatStrength — compound & additive meters', () {
    test('6/8: the second dotted beat (3/8) is ½, eighths ¼', () {
      const t = TimeSignature.sixEight;
      expect(at(t, 0, 1), 1.0);
      expect(at(t, 3, 8), 0.5); // second dotted-quarter beat
      expect(at(t, 1, 8), 0.25);
      expect(at(t, 1, 4), 0.25); // == 2/8
      expect(at(t, 1, 2), 0.25); // == 4/8
      expect(at(t, 5, 8), 0.25);
    });

    test('9/8: three dotted beats, each group start ½', () {
      const t = TimeSignature(9, 8);
      expect(at(t, 0, 1), 1.0);
      expect(at(t, 3, 8), 0.5); // beat 2
      expect(at(t, 3, 4), 0.5); // beat 3 (== 6/8)
      expect(at(t, 1, 8), 0.25);
    });

    test('additive 3+2+2/8 accents each group start', () {
      final t = TimeSignature.additive([3, 2, 2], 8);
      expect(at(t, 0, 1), 1.0);
      expect(at(t, 3, 8), 0.5); // second group
      expect(at(t, 5, 8), 0.5); // third group
      expect(at(t, 1, 8), 0.25); // inside the first group
      expect(at(t, 1, 2), 0.25); // == 4/8, inside the second group
    });
  });

  group('beatStrength — hierarchy invariants', () {
    test('the downbeat is the unique maximum, all strengths in (0, 1]', () {
      for (final t in [
        TimeSignature.fourFour,
        TimeSignature.threeFour,
        TimeSignature.sixEight,
        TimeSignature.cutTime,
      ]) {
        final grid = t.metricGrid();
        final downbeat = t.beatStrength(Fraction.zero);
        expect(downbeat, 1.0);
        for (final entry in grid.entries) {
          final s = t.beatStrength(entry.key);
          expect(s, greaterThan(0.0));
          expect(s, lessThanOrEqualTo(1.0));
          if (entry.key != Fraction.zero) expect(s, lessThan(downbeat));
        }
      }
    });

    test('a stronger beat outranks the offbeats it contains (4/4)', () {
      const t = TimeSignature.fourFour;
      expect(at(t, 1, 2), greaterThan(at(t, 1, 4))); // beat 3 > beat 2
      expect(at(t, 1, 4), greaterThan(at(t, 1, 8))); // beat > eighth
    });

    test('off-grid positions (triplet subdivision) have no accent', () {
      const t = TimeSignature.fourFour;
      expect(at(t, 1, 3), 0.0); // a quarter-note triplet position
      expect(at(t, 1, 6), 0.0);
    });
  });
}

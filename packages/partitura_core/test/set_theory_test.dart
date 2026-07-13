import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  group('normal order', () {
    test('a rotated major triad normalizes to [0,4,7]', () {
      expect(normalForm({4, 7, 0}), [0, 4, 7]);
      expect(normalForm({7, 0, 4}), [0, 4, 7]);
    });

    test('keeps the actual pitch classes (D major triad)', () {
      expect(normalForm({9, 2, 6}), [2, 6, 9]);
    });

    test('picks the most compact rotation (largest gap goes to the outside)',
        () {
      // {0,2,10}: the big gap is 2→10, so normal order starts on 10 → [10,0,2].
      expect(normalForm({0, 2, 10}), [10, 0, 2]);
    });
  });

  group('prime form', () {
    test('major and minor triads share the 3-11 prime form [0,3,7]', () {
      expect(primeForm({0, 4, 7}), [0, 3, 7]);
      expect(primeForm({0, 3, 7}), [0, 3, 7]);
      expect(primeForm({2, 6, 9}), [0, 3, 7]); // any transposition
    });

    test('chromatic and diminished sets', () {
      expect(primeForm({0, 1, 2}), [0, 1, 2]); // 3-1
      expect(primeForm({0, 3, 6, 9}), [0, 3, 6, 9]); // 4-28 (dim 7th)
    });
  });

  group('interval-class vector', () {
    test('major triad is <001110>', () {
      expect(intervalClassVector({0, 4, 7}), [0, 0, 1, 1, 1, 0]);
    });

    test('diminished 7th is <004002>', () {
      expect(intervalClassVector({0, 3, 6, 9}), [0, 0, 4, 0, 0, 2]);
    });

    test('the chromatic trichord is <210000>', () {
      expect(intervalClassVector({0, 1, 2}), [2, 1, 0, 0, 0, 0]);
    });
  });

  group('Z-relation', () {
    test('the all-interval tetrachords 4-Z15 and 4-Z29 are Z-related', () {
      const a = {0, 1, 4, 6};
      const b = {0, 1, 3, 7};
      // Same (all-interval) vector, different prime forms.
      expect(intervalClassVector(a), [1, 1, 1, 1, 1, 1]);
      expect(intervalClassVector(b), [1, 1, 1, 1, 1, 1]);
      expect(primeForm(a), isNot(primeForm(b)));
      expect(zRelated(a, b), isTrue);
    });

    test('a set is not Z-related to its own inversion (same set class)', () {
      expect(zRelated({0, 4, 7}, {0, 3, 7}), isFalse);
    });
  });

  group('helpers', () {
    test('transpose and invert', () {
      expect(transposeSet({0, 4, 7}, 2), {2, 6, 9});
      expect(invertSet({0, 4, 7}), {0, 8, 5});
    });

    test('pitchClassSet de-duplicates octaves', () {
      expect(
          pitchClassSet([
            Pitch.parse('c4'),
            Pitch.parse('e4'),
            Pitch.parse('g4'),
            Pitch.parse('c5')
          ]),
          {0, 4, 7});
    });
  });
}

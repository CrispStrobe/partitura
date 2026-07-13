import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  group('construction', () {
    test('reduces mod 12 and removes duplicates, keeping ascending order', () {
      expect(PitchClassSet([0, 4, 7, 12, 16]).pitchClasses, [0, 4, 7]);
      expect(PitchClassSet([7, 0, 4]).pitchClasses, [0, 4, 7]);
      expect(PitchClassSet([-1, 13]).pitchClasses, [1, 11]);
      expect(PitchClassSet(const []).isEmpty, isTrue);
    });

    test('from pitches collapses octaves and enharmonics', () {
      final set = PitchClassSet.of([
        Pitch.parse('c4'),
        Pitch.parse('e5'),
        Pitch.parse('g3'),
        Pitch.parse('c6'), // duplicate pc 0
        Pitch.parse('b#3'), // enharmonic C -> pc 0
      ]);
      expect(set.pitchClasses, [0, 4, 7]);
    });

    test('cardinality', () {
      expect(PitchClassSet([0, 1, 4, 6]).cardinality, 4);
    });
  });

  group('normal order', () {
    test('a compact set is already in normal order', () {
      expect(PitchClassSet([0, 1, 2]).normalOrder, [0, 1, 2]);
    });

    test('rotates to the most compact span', () {
      // {0,4,7} major triad: [0,4,7] (span 7) beats the other rotations.
      expect(PitchClassSet([0, 4, 7]).normalOrder, [0, 4, 7]);
      // {2,6,9,0} -> normal order packs to [9,0,2,6] (span 9)... the tightest.
      expect(PitchClassSet([0, 2, 6, 9]).normalOrder, [6, 9, 0, 2]);
    });

    test('single and empty sets', () {
      expect(PitchClassSet([5]).normalOrder, [5]);
      expect(PitchClassSet(const []).normalOrder, isEmpty);
    });
  });

  group('prime form', () {
    test('major and minor triads share the set class 3-11 [0,3,7]', () {
      expect(PitchClassSet([0, 4, 7]).primeForm, [0, 3, 7]); // C major
      expect(PitchClassSet([0, 3, 7]).primeForm, [0, 3, 7]); // C minor
      expect(PitchClassSet([0, 4, 7]).isSameSetClass(PitchClassSet([0, 3, 7])),
          isTrue);
    });

    test('symmetric trichords', () {
      expect(PitchClassSet([0, 1, 2]).primeForm, [0, 1, 2]); // 3-1
      expect(PitchClassSet([0, 3, 6]).primeForm, [0, 3, 6]); // 3-10 diminished
      expect(PitchClassSet([0, 4, 8]).primeForm, [0, 4, 8]); // 3-12 augmented
    });

    test('common tetrachords', () {
      expect(PitchClassSet([0, 4, 7, 10]).primeForm, [0, 2, 5, 8]); // 4-27 dom7
      expect(PitchClassSet([0, 1, 4, 6]).primeForm, [0, 1, 4, 6]); // 4-Z15
      expect(PitchClassSet([0, 1, 3, 7]).primeForm, [0, 1, 3, 7]); // 4-Z29
    });

    test('prime form is invariant under transposition and inversion', () {
      final base = PitchClassSet([0, 2, 5, 8]);
      for (var n = 0; n < 12; n++) {
        expect(base.transpose(n).primeForm, base.primeForm);
        expect(base.invert(n).primeForm, base.primeForm);
      }
    });
  });

  group('interval-class vector', () {
    test('major triad is [0,0,1,1,1,0]', () {
      expect(PitchClassSet([0, 4, 7]).intervalClassVector, [0, 0, 1, 1, 1, 0]);
    });

    test('chromatic trichord is [2,1,0,0,0,0]', () {
      expect(PitchClassSet([0, 1, 2]).intervalClassVector, [2, 1, 0, 0, 0, 0]);
    });

    test('the diminished seventh is [0,0,4,0,0,2]', () {
      expect(
          PitchClassSet([0, 3, 6, 9]).intervalClassVector, [0, 0, 4, 0, 0, 2]);
    });

    test('the whole-tone scale is [0,6,0,6,0,3]', () {
      expect(PitchClassSet([0, 2, 4, 6, 8, 10]).intervalClassVector,
          [0, 6, 0, 6, 0, 3]);
    });

    test('the vector counts every unordered pair', () {
      final v = PitchClassSet([0, 1, 4, 6]).intervalClassVector;
      expect(v.reduce((a, b) => a + b), 6); // C(4,2) = 6 pairs
    });
  });

  group('transforms', () {
    test('transpose adds mod 12', () {
      expect(PitchClassSet([0, 4, 7]).transpose(3).pitchClasses, [3, 7, 10]);
      expect(PitchClassSet([0, 4, 7]).transpose(-1).pitchClasses, [3, 6, 11]);
    });

    test('inversion about 0 maps p -> -p', () {
      expect(PitchClassSet([0, 1, 4, 6]).invert().pitchClasses, [0, 6, 8, 11]);
    });

    test('T_nI composes transposition with inversion', () {
      // T5I about axis 5: p -> 5 - p.
      expect(PitchClassSet([0, 4, 7]).invert(5).pitchClasses, [1, 5, 10]);
    });
  });

  group('complement', () {
    test('is the pitch classes not present', () {
      expect(PitchClassSet([0, 4, 7]).complement.pitchClasses,
          [1, 2, 3, 5, 6, 8, 9, 10, 11]);
    });

    test('the whole-tone complement is the other whole-tone scale', () {
      expect(PitchClassSet([0, 2, 4, 6, 8, 10]).complement.pitchClasses,
          [1, 3, 5, 7, 9, 11]);
    });

    test('complement of the empty set is the aggregate', () {
      expect(PitchClassSet(const []).complement.cardinality, 12);
    });
  });

  group('Z-relation', () {
    test('the all-interval tetrachords 4-Z15 and 4-Z29 are Z-related', () {
      final z15 = PitchClassSet([0, 1, 4, 6]);
      final z29 = PitchClassSet([0, 1, 3, 7]);
      expect(z15.intervalClassVector, z29.intervalClassVector); // same ICV
      expect(z15.primeForm, isNot(z29.primeForm)); // different set class
      expect(z15.isZRelatedTo(z29), isTrue);
      expect(z29.isZRelatedTo(z15), isTrue);
    });

    test('a set is not Z-related to its own set class', () {
      final major = PitchClassSet([0, 4, 7]);
      expect(major.isZRelatedTo(PitchClassSet([2, 6, 9])), isFalse);
    });

    test('sets with different ICVs are not Z-related', () {
      expect(PitchClassSet([0, 1, 2]).isZRelatedTo(PitchClassSet([0, 4, 8])),
          isFalse);
    });
  });

  group('value semantics', () {
    test('equality is by member set', () {
      expect(PitchClassSet([0, 4, 7]), PitchClassSet([7, 0, 4, 12]));
      expect(
          PitchClassSet([0, 4, 7]).hashCode, PitchClassSet([7, 0, 4]).hashCode);
      expect(PitchClassSet([0, 4, 7]), isNot(PitchClassSet([0, 3, 7])));
    });

    test('toString lists the members', () {
      expect(PitchClassSet([0, 4, 7]).toString(), contains('0, 4, 7'));
    });
  });
}

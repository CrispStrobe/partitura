import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  final cMajor = Triad(Pitch.parse('c4'), ChordQuality.major);
  final cMinor = Triad(Pitch.parse('c4'), ChordQuality.minor);

  group('P (parallel)', () {
    test('swaps major and minor on the same root', () {
      expect(cMajor.parallel(), cMinor);
      expect(cMinor.parallel(), cMajor);
    });

    test('is an involution', () {
      expect(cMajor.parallel().parallel(), cMajor);
    });
  });

  group('L (leading-tone exchange)', () {
    test('C major -> E minor and back', () {
      final eMinor = Triad(Pitch.parse('e4'), ChordQuality.minor);
      expect(cMajor.leadingToneExchange(), eMinor);
      expect(eMinor.leadingToneExchange(), cMajor);
    });

    test('is an involution', () {
      expect(cMinor.leadingToneExchange().leadingToneExchange(), cMinor);
    });
  });

  group('R (relative)', () {
    test('C major -> A minor and back', () {
      final aMinor = Triad(Pitch.parse('a3'), ChordQuality.minor);
      expect(cMajor.relative(), aMinor);
      expect(aMinor.relative(), cMajor);
    });

    test('is an involution', () {
      expect(cMinor.relative().relative(), cMinor);
    });
  });

  group('shared behaviour', () {
    test('the three transforms share pitch classes with two common tones', () {
      // Each of L, P, R keeps two of the three notes and moves one.
      Set<int> pcs(Triad t) => {for (final p in t.pitches) p.midiNumber % 12};
      for (final t in [
        cMajor.leadingToneExchange(),
        cMajor.parallel(),
        cMajor.relative()
      ]) {
        expect(pcs(cMajor).intersection(pcs(t)), hasLength(2));
      }
    });

    test('results are in root position regardless of input inversion', () {
      final firstInv =
          Triad(Pitch.parse('c4'), ChordQuality.major, inversion: 1);
      expect(firstInv.relative().inversion, 0);
      expect(firstInv.parallel().inversion, 0);
    });

    test('reject non-consonant triads', () {
      final dim = Triad(Pitch.parse('b3'), ChordQuality.diminished);
      final aug = Triad(Pitch.parse('c4'), ChordQuality.augmented);
      expect(dim.isConsonant, isFalse);
      expect(cMajor.isConsonant, isTrue);
      expect(() => dim.parallel(), throwsStateError);
      expect(() => aug.leadingToneExchange(), throwsStateError);
      expect(() => dim.relative(), throwsStateError);
    });

    test('the PL cycle walks a hexatonic system', () {
      // Alternating P and L from C major visits six distinct triads and
      // returns to C major's pitch classes. Compared by pitch class, since
      // repeated diatonic transposition may respell enharmonically.
      List<int> pcs(Triad t) =>
          [for (final p in t.pitches) p.midiNumber % 12]..sort();
      var t = cMajor;
      final seen = <String>{pcs(t).join(',')};
      for (var i = 0; i < 6; i++) {
        t = i.isEven ? t.parallel() : t.leadingToneExchange();
        seen.add(pcs(t).join(','));
      }
      expect(pcs(t), pcs(cMajor)); // home again after six moves
      expect(seen, hasLength(6)); // six distinct triads en route
    });
  });
}

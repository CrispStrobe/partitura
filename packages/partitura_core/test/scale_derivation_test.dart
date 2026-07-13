import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  group('Scale.pitchClasses', () {
    test('C major', () {
      expect(Scale(Pitch.parse('c4'), ScaleType.major).pitchClasses,
          {0, 2, 4, 5, 7, 9, 11});
    });

    test('A natural minor equals the C major collection', () {
      expect(Scale(Pitch.parse('a3'), ScaleType.naturalMinor).pitchClasses,
          {0, 2, 4, 5, 7, 9, 11});
    });

    test('never throws for extreme tonics', () {
      expect(
          Scale(Pitch(Step.g, alter: 1), ScaleType.harmonicMinor).pitchClasses,
          hasLength(7));
    });
  });

  group('matchingScales', () {
    test('the diatonic collection fits C major and A natural minor exactly',
        () {
      final exact = matchingScales(PitchClassSet([0, 2, 4, 5, 7, 9, 11]),
          exactOnly: true);
      final scales = [for (final m in exact) m.scale];
      expect(scales, contains(Scale(Pitch.parse('c4'), ScaleType.major)));
      expect(scales, contains(Scale(Pitch(Step.a), ScaleType.naturalMinor)));
      for (final m in exact) {
        expect(m.missing, 0);
      }
    });

    test('best fit first, ranked by fewest missing then most matched', () {
      final ranked = matchingScales(PitchClassSet([0, 2, 4, 5, 7, 9, 11]));
      expect(ranked, hasLength(12 * ScaleType.values.length));
      expect(ranked.first.isExact, isTrue);
      for (var i = 1; i < ranked.length; i++) {
        final a = ranked[i - 1], b = ranked[i];
        expect(a.missing <= b.missing, isTrue);
        if (a.missing == b.missing) {
          expect(a.matched >= b.matched, isTrue);
        }
      }
    });

    test('a triad fits many scales; each contains all three notes', () {
      final exact = matchingScales(PitchClassSet([0, 4, 7]), exactOnly: true);
      expect(exact, isNotEmpty);
      for (final m in exact) {
        expect(m.matched, 3);
        expect(m.missing, 0);
      }
      // C major is one of them.
      expect([for (final m in exact) m.scale],
          contains(Scale(Pitch.parse('c4'), ScaleType.major)));
    });

    test('a chromatic cluster fits no scale exactly', () {
      final exact =
          matchingScales(PitchClassSet([0, 1, 2, 3]), exactOnly: true);
      expect(exact, isEmpty);
      // But the best partial fit still matches three of the four notes.
      final best = matchingScales(PitchClassSet([0, 1, 2, 3])).first;
      expect(best.matched, greaterThanOrEqualTo(3));
    });

    test('an empty query is rejected', () {
      expect(
          () => matchingScales(PitchClassSet(const [])), throwsArgumentError);
    });
  });

  group('deriveScale', () {
    test('a C major melody derives a C major (or A minor) scale', () {
      final scale = deriveScale([
        for (final n in ['c4', 'd4', 'e4', 'f4', 'g4', 'a4', 'b4', 'c5'])
          Pitch.parse(n),
      ]);
      expect(scale.pitchClasses, {0, 2, 4, 5, 7, 9, 11});
    });

    test('rejects an empty melody', () {
      expect(() => deriveScale(const []), throwsArgumentError);
    });
  });
}

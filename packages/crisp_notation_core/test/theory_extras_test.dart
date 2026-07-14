import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

Triad triad(String root, ChordQuality q) => Triad(Pitch.parse(root), q);
int pc(Pitch p) => p.midiNumber % 12;

void main() {
  group('neo-Riemannian transforms', () {
    final cMajor = triad('c4', ChordQuality.major);
    final cMinor = triad('c4', ChordQuality.minor);
    final aMinor = triad('a3', ChordQuality.minor);

    test('P swaps mode on the same root', () {
      final p = cMajor.parallel;
      expect(pc(p.root), pc(cMajor.root));
      expect(p.quality, ChordQuality.minor);
      expect(cMinor.parallel.quality, ChordQuality.major);
    });

    test('R maps a major triad to its relative minor and back', () {
      final r = cMajor.relative;
      expect(pc(r.root), 9); // A
      expect(r.quality, ChordQuality.minor);
      final back = aMinor.relative;
      expect(pc(back.root), 0); // C
      expect(back.quality, ChordQuality.major);
    });

    test('L: C major → E minor, C minor → Ab major', () {
      expect(pc(cMajor.leittonwechsel.root), 4); // E
      expect(cMajor.leittonwechsel.quality, ChordQuality.minor);
      expect(pc(cMinor.leittonwechsel.root), 8); // Ab
      expect(cMinor.leittonwechsel.quality, ChordQuality.major);
    });

    test('each transform is an involution (applying it twice returns)', () {
      for (final f in [
        (Triad t) => t.parallel,
        (Triad t) => t.relative,
        (Triad t) => t.leittonwechsel,
      ]) {
        final round = f(f(cMajor));
        expect(pc(round.root), pc(cMajor.root));
        expect(round.quality, cMajor.quality);
      }
    });

    test('a diminished triad has no neo-Riemannian transform', () {
      expect(() => triad('b3', ChordQuality.diminished).parallel,
          throwsStateError);
    });
  });

  group('twelve-tone rows', () {
    final chromatic = [for (var i = 0; i < 12; i++) i];

    test('row-form operations', () {
      expect(transposeRow([0, 4, 7], 5), [5, 9, 0]);
      expect(retrograde([0, 1, 2]), [2, 1, 0]);
      expect(invertRow([0, 2, 4, 5, 7, 9, 11]), [0, 10, 8, 7, 5, 3, 1]);
      expect(retrogradeInversion([0, 2, 4]), [8, 10, 0]);
    });

    test('the matrix is 12×12 with P0 on top and I0 down the left', () {
      final m = twelveToneMatrix(chromatic);
      expect(m, hasLength(12));
      expect(m.every((row) => row.length == 12), isTrue);
      expect(m[0], chromatic); // P0
      expect([for (final row in m) row[0]],
          [0, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]); // I0
      // Every row is a permutation of 0..11.
      expect(m.every((row) => row.toSet().length == 12), isTrue);
    });

    test('a non-permutation row is rejected', () {
      expect(() => twelveToneMatrix([0, 0, 1]), throwsArgumentError);
    });
  });

  group('scale derivation', () {
    test('a C major triad points at C major first', () {
      final scales = matchingScales({0, 4, 7});
      expect(scales, isNotEmpty);
      expect(pc(scales.first.tonic), 0);
      expect(scales.first.type, ScaleType.major);
    });

    test('the full C major scale matches C major (and its relative A minor)',
        () {
      final scales = matchingScales({0, 2, 4, 5, 7, 9, 11});
      // C major and A natural minor share these seven pitch classes.
      expect(scales, hasLength(2));
      expect(pc(scales.first.tonic), 0); // C major ranks first
      expect(scales.first.type, ScaleType.major);
      expect(
          scales
              .any((s) => pc(s.tonic) == 9 && s.type == ScaleType.naturalMinor),
          isTrue);
    });

    test('three chromatic neighbours match no scale', () {
      expect(matchingScales({0, 1, 2}), isEmpty);
    });
  });
}

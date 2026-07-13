import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

Pitch _p(Step s, int octave, [int alter = 0]) =>
    Pitch(s, alter: alter, octave: octave);

void main() {
  group('identifyChord', () {
    test('triad qualities', () {
      expect(
          chordSymbolFor([_p(Step.c, 4), _p(Step.e, 4), _p(Step.g, 4)]), 'C');
      expect(chordSymbolFor([_p(Step.c, 4), _p(Step.e, 4, -1), _p(Step.g, 4)]),
          'Cm');
      expect(
          chordSymbolFor([_p(Step.c, 4), _p(Step.e, 4, -1), _p(Step.g, 4, -1)]),
          'Cdim');
      expect(chordSymbolFor([_p(Step.c, 4), _p(Step.e, 4), _p(Step.g, 4, 1)]),
          'Caug');
    });

    test('sevenths', () {
      expect(
          chordSymbolFor(
              [_p(Step.g, 3), _p(Step.b, 3), _p(Step.d, 4), _p(Step.f, 4)]),
          'G7');
      expect(
          chordSymbolFor(
              [_p(Step.c, 4), _p(Step.e, 4), _p(Step.g, 4), _p(Step.b, 4)]),
          'Cmaj7');
      expect(
          chordSymbolFor(
              [_p(Step.a, 3), _p(Step.c, 4), _p(Step.e, 4), _p(Step.g, 4)]),
          'Am7');
      expect(
          chordSymbolFor(
              [_p(Step.b, 3), _p(Step.d, 4), _p(Step.f, 4), _p(Step.a, 4)]),
          'Bm7b5');
    });

    test('sus chords', () {
      expect(chordSymbolFor([_p(Step.c, 4), _p(Step.f, 4), _p(Step.g, 4)]),
          'Csus4');
      expect(chordSymbolFor([_p(Step.c, 4), _p(Step.d, 4), _p(Step.g, 4)]),
          'Csus2');
    });

    test('inversions become slash chords', () {
      // C major, third in the bass.
      final firstInv =
          identifyChord([_p(Step.e, 4), _p(Step.g, 4), _p(Step.c, 5)])!;
      expect(firstInv.symbol, 'C/E');
      expect(firstInv.inversion, 1);
      expect(firstInv.root, _p(Step.c, 5));
      // C major, fifth in the bass.
      expect(
          identifyChord([_p(Step.g, 3), _p(Step.c, 4), _p(Step.e, 4)])!.symbol,
          'C/G');
    });

    test('the bass disambiguates C6 vs Am7', () {
      expect(
          chordSymbolFor(
              [_p(Step.c, 4), _p(Step.e, 4), _p(Step.g, 4), _p(Step.a, 4)]),
          'C6');
      expect(
          chordSymbolFor(
              [_p(Step.a, 3), _p(Step.c, 4), _p(Step.e, 4), _p(Step.g, 4)]),
          'Am7');
    });

    test('spelling follows the input pitches', () {
      expect(
          chordSymbolFor(
              [_p(Step.f, 4, 1), _p(Step.a, 4, 1), _p(Step.c, 5, 1)]),
          'F#'); // F# A# C#
      expect(chordSymbolFor([_p(Step.b, 3, -1), _p(Step.d, 4), _p(Step.f, 4)]),
          'Bb'); // Bb major
    });

    test('octave doubling and note order do not matter', () {
      expect(
          chordSymbolFor([
            _p(Step.g, 5),
            _p(Step.c, 4),
            _p(Step.e, 4),
            _p(Step.c, 3),
          ]),
          'C'); // still a C major triad
    });

    test('non-chords return null', () {
      expect(chordSymbolFor([_p(Step.c, 4), _p(Step.g, 4)]), isNull); // dyad
      expect(chordSymbolFor([_p(Step.c, 4)]), isNull); // single note
      expect(chordSymbolFor([_p(Step.c, 4), _p(Step.d, 4, 1), _p(Step.d, 4)]),
          isNull); // C C# D — a chromatic cluster, no template
    });
  });

  group('extended chords', () {
    test('added ninths and six-nine (no seventh)', () {
      expect(
          chordSymbolFor(
              [_p(Step.c, 4), _p(Step.e, 4), _p(Step.g, 4), _p(Step.d, 5)]),
          'Cadd9');
      expect(
          chordSymbolFor(
              [_p(Step.c, 4), _p(Step.e, 4, -1), _p(Step.g, 4), _p(Step.d, 5)]),
          'Cm(add9)');
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4),
            _p(Step.g, 4),
            _p(Step.a, 4),
            _p(Step.d, 5),
          ]),
          'C6/9');
    });

    test('ninth chords', () {
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4),
            _p(Step.g, 4),
            _p(Step.b, 4, -1),
            _p(Step.d, 5),
          ]),
          'C9');
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4),
            _p(Step.g, 4),
            _p(Step.b, 4),
            _p(Step.d, 5),
          ]),
          'Cmaj9');
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4, -1),
            _p(Step.g, 4),
            _p(Step.b, 4, -1),
            _p(Step.d, 5),
          ]),
          'Cm9');
    });

    test('eleventh chords (dominant drops the 3rd)', () {
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.g, 4),
            _p(Step.b, 4, -1),
            _p(Step.d, 5),
            _p(Step.f, 5),
          ]),
          'C11');
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4, -1),
            _p(Step.g, 4),
            _p(Step.b, 4, -1),
            _p(Step.d, 5),
            _p(Step.f, 5),
          ]),
          'Cm11');
    });

    test('thirteenth chords (standard voicing: no 5th, no 11th)', () {
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4),
            _p(Step.b, 4, -1),
            _p(Step.d, 5),
            _p(Step.a, 5),
          ]),
          'C13');
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4),
            _p(Step.b, 4),
            _p(Step.d, 5),
            _p(Step.a, 5),
          ]),
          'Cmaj13');
      expect(
          chordSymbolFor([
            _p(Step.c, 4),
            _p(Step.e, 4, -1),
            _p(Step.b, 4, -1),
            _p(Step.d, 5),
            _p(Step.a, 5),
          ]),
          'Cm13');
    });
  });

  group('augmented sixths (spelling-aware)', () {
    // In C: ♭6 = A♭, 1 = C, ♯4 = F♯; French adds 2 = D, German adds ♭3 = E♭.
    test('Italian, French and German sixths', () {
      expect(
          chordSymbolFor(
              [_p(Step.a, 3, -1), _p(Step.c, 4), _p(Step.f, 4, 1)]),
          'It+6');
      expect(
          chordSymbolFor([
            _p(Step.a, 3, -1),
            _p(Step.c, 4),
            _p(Step.d, 4),
            _p(Step.f, 4, 1),
          ]),
          'Fr+6');
      expect(
          chordSymbolFor([
            _p(Step.a, 3, -1),
            _p(Step.c, 4),
            _p(Step.e, 4, -1),
            _p(Step.f, 4, 1),
          ]),
          'Ger+6');
    });

    test('a German sixth is distinguished from its enharmonic dominant 7th', () {
      // A♭–C–E♭–F♯ is spelled with an augmented sixth: German 6th.
      expect(
          chordSymbolFor([
            _p(Step.a, 3, -1),
            _p(Step.c, 4),
            _p(Step.e, 4, -1),
            _p(Step.f, 4, 1),
          ]),
          'Ger+6');
      // A♭–C–E♭–G♭ is spelled with a minor seventh: an ordinary A♭7.
      expect(
          chordSymbolFor([
            _p(Step.a, 3, -1),
            _p(Step.c, 4),
            _p(Step.e, 4, -1),
            _p(Step.g, 4, -1),
          ]),
          'Ab7');
    });

    test('the aug-6th recognition survives octave displacement', () {
      // Same German sixth with ♯4 dropped an octave below the ♭6 in pitch.
      expect(
          chordSymbolFor([
            _p(Step.f, 3, 1),
            _p(Step.a, 3, -1),
            _p(Step.c, 4),
            _p(Step.e, 4, -1),
          ]),
          'Ger+6');
    });
  });
}

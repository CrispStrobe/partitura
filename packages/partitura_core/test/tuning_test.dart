import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// v0.8: string tunings + fret assignment.
void main() {
  final guitar = Tuning.standardGuitar;

  group('standard guitar', () {
    test('has six strings, high E on top', () {
      expect(guitar.stringCount, 6);
      expect(guitar.strings.first, Pitch.parse('e4'));
      expect(guitar.strings.last, Pitch.parse('e2'));
    });

    test('open strings map to fret 0 on their own line', () {
      expect(guitar.fretFor(Pitch.parse('e4')), (0, 0)); // string 1
      expect(guitar.fretFor(Pitch.parse('b3')), (1, 0)); // string 2
      expect(guitar.fretFor(Pitch.parse('g3')), (2, 0)); // string 3
      expect(guitar.fretFor(Pitch.parse('d3')), (3, 0)); // string 4
      expect(guitar.fretFor(Pitch.parse('a2')), (4, 0)); // string 5
      expect(guitar.fretFor(Pitch.parse('e2')), (5, 0)); // string 6
    });

    test('picks the lowest available fret', () {
      // F4 = 1st fret of the high E string.
      expect(guitar.fretFor(Pitch.parse('f4')), (0, 1));
      // C4 = 1st fret of the B string (lower than 5th fret of G).
      expect(guitar.fretFor(Pitch.parse('c4')), (1, 1));
      // G4 = 3rd fret of the high E string.
      expect(guitar.fretFor(Pitch.parse('g4')), (0, 3));
    });

    test('unreachable pitches return null', () {
      expect(guitar.fretFor(Pitch.parse('c1')), isNull); // below low E
      expect(guitar.fretFor(Pitch.parse('c8'), maxFret: 12), isNull);
    });
  });

  group('other tunings', () {
    test('drop D lowers the sixth string', () {
      expect(Tuning.dropDGuitar.strings.last, Pitch.parse('d2'));
      expect(Tuning.dropDGuitar.fretFor(Pitch.parse('d2')), (5, 0));
    });

    test('bass has four strings', () {
      expect(Tuning.standardBass.stringCount, 4);
      expect(Tuning.standardBass.fretFor(Pitch.parse('e1')), (3, 0));
    });

    test('value semantics', () {
      expect(Tuning.standardGuitar, Tuning.standardGuitar);
      expect(Tuning.standardGuitar, isNot(Tuning.dropDGuitar));
    });
  });

  group('fretted-instrument presets (Phase 6.5)', () {
    test('string counts and labels', () {
      expect(Tuning.dadgadGuitar.stringCount, 6);
      expect(Tuning.openGGuitar.stringCount, 6);
      expect(Tuning.sevenStringGuitar.stringCount, 7);
      expect(Tuning.eightStringGuitar.stringCount, 8);
      expect(Tuning.fiveStringBass.stringCount, 5);
      expect(Tuning.banjoOpenG.stringCount, 5);
      expect(Tuning.ukulele.stringCount, 4);
      expect(Tuning.mandolin.stringCount, 4);
      expect(Tuning.mandolin.name, 'Mandolin');
    });

    test('DADGAD drops the 3rd, 2nd and 1st strings vs standard', () {
      expect(Tuning.dadgadGuitar.strings.first, Pitch.parse('d4')); // string 1
      expect(Tuning.dadgadGuitar.strings.last, Pitch.parse('d2')); // string 6
      // Open low D plays fret 0 on the bottom string.
      expect(Tuning.dadgadGuitar.fretFor(Pitch.parse('d2')), (5, 0));
    });

    test('7- and 8-string guitars extend below low E', () {
      expect(Tuning.sevenStringGuitar.strings.last, Pitch.parse('b1'));
      expect(Tuning.sevenStringGuitar.fretFor(Pitch.parse('b1')), (6, 0));
      expect(Tuning.eightStringGuitar.strings.last, Pitch.parse('f#1'));
      expect(Tuning.eightStringGuitar.fretFor(Pitch.parse('f#1')), (7, 0));
    });

    test('five-string bass adds a low B0', () {
      expect(Tuning.fiveStringBass.strings.last, Pitch.parse('b0'));
      expect(Tuning.fiveStringBass.fretFor(Pitch.parse('b0')), (4, 0));
    });

    test('ukulele high-G is reentrant (string 4 sounds above string 1)', () {
      // A4 (string 1) is lower than G4 (string 4, reentrant high G).
      expect(Tuning.ukulele.strings.first, Pitch.parse('a4'));
      expect(Tuning.ukulele.strings.last, Pitch.parse('g4'));
      expect(Tuning.ukulele.strings.last.midiNumber,
          lessThan(Tuning.ukulele.strings.first.midiNumber));
    });

    test('mandolin is tuned in fifths, high E5 on top', () {
      expect(Tuning.mandolin.strings.first, Pitch.parse('e5'));
      expect(Tuning.mandolin.strings.last, Pitch.parse('g3'));
    });
  });
}

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Parses a note like `c4`, `f#4`, `eb5`, `g##3`.
Pitch note(String s) {
  final m = RegExp(r'^([a-g])([#b]*)(-?\d+)$').firstMatch(s)!;
  final step = Step.values.firstWhere((st) => st.name == m[1]);
  final acc = m[2]!;
  final alter = acc.isEmpty
      ? 0
      : acc.startsWith('#')
          ? acc.length
          : -acc.length;
  return Pitch(step, alter: alter, octave: int.parse(m[3]!));
}

List<Pitch> chord(String names) => names.split(' ').map(note).toList();

void main() {
  final cMajor = Key.major(note('c4'));
  final aMinor = Key.minor(note('a4'));

  String rn(String notes, Key key) => romanNumeralOf(chord(notes), key)!.symbol;

  group('diatonic triads', () {
    test('the seven of C major', () {
      expect(rn('c4 e4 g4', cMajor), 'I');
      expect(rn('d4 f4 a4', cMajor), 'ii');
      expect(rn('e4 g4 b4', cMajor), 'iii');
      expect(rn('f4 a4 c5', cMajor), 'IV');
      expect(rn('g4 b4 d5', cMajor), 'V');
      expect(rn('a4 c5 e5', cMajor), 'vi');
      expect(rn('b4 d5 f5', cMajor), 'vii°');
    });

    test('the seven of A minor (harmonic: V major, vii° on the raised 7th)',
        () {
      expect(rn('a4 c5 e5', aMinor), 'i');
      expect(rn('b4 d5 f5', aMinor), 'ii°');
      expect(rn('c5 e5 g5', aMinor), 'III');
      expect(rn('d4 f4 a4', aMinor), 'iv');
      expect(rn('e4 g#4 b4', aMinor), 'V'); // raised leading tone
      expect(rn('f4 a4 c5', aMinor), 'VI');
      expect(rn('g#4 b4 d5', aMinor), 'vii°');
      expect(rn('g4 b4 d5', aMinor), 'VII'); // natural 7th, no prefix
    });
  });

  group('inversions → figured bass', () {
    test('triad inversions of the tonic and dominant', () {
      expect(rn('e4 g4 c5', cMajor), 'I6'); // first inversion
      expect(rn('g4 c5 e5', cMajor), 'I6/4'); // second inversion
      expect(rn('b4 d5 g5', cMajor), 'V6');
    });

    test('seventh-chord figures', () {
      expect(rn('g4 b4 d5 f5', cMajor), 'V7');
      expect(rn('b4 d5 f5 g5', cMajor), 'V6/5'); // first inversion
      expect(rn('d4 f4 g4 b4', cMajor), 'V4/3'); // second inversion
      expect(rn('f4 g4 b4 d5', cMajor), 'V4/2'); // third inversion
    });

    test('quality marks: leading-tone sevenths', () {
      expect(rn('b4 d5 f5 a5', cMajor), 'viiø7'); // half-diminished
      expect(rn('g#4 b4 d5 f5', aMinor), 'vii°7'); // fully diminished
      expect(rn('c4 e4 g4 b4', cMajor), 'IM7'); // major seventh
    });
  });

  group('chromatic roots', () {
    test('Neapolitan and borrowed chords take accidental prefixes', () {
      expect(rn('db4 f4 ab4', cMajor), 'bII'); // Neapolitan
      expect(rn('ab4 c5 eb5', cMajor), 'bVI'); // borrowed from minor
      expect(rn('eb4 g4 bb4', cMajor), 'bIII');
    });
  });

  group('secondary chords', () {
    test('secondary dominants tonicize their target with proper case', () {
      expect(rn('d4 f#4 a4', cMajor), 'V/V');
      expect(rn('d4 f#4 a4 c5', cMajor), 'V7/V');
      expect(rn('a4 c#5 e5 g5', cMajor), 'V7/ii');
      expect(rn('e4 g#4 b4 d5', cMajor), 'V7/vi'); // vi is minor → lowercase
    });

    test('secondary leading-tone chord', () {
      expect(rn('f#4 a4 c5 eb5', cMajor), 'vii°7/V');
    });
  });

  group('realize (bidirectional)', () {
    test('pitch classes round-trip through the numeral', () {
      for (final (notes, key) in [
        ('c4 e4 g4', cMajor),
        ('g4 b4 d5 f5', cMajor),
        ('d4 f#4 a4', cMajor), // V/V
        ('db4 f4 ab4', cMajor), // bII
        ('e4 g#4 b4', aMinor), // V in minor
      ]) {
        final pitches = chord(notes);
        final numeral = romanNumeralOf(pitches, key)!;
        final original = {for (final p in pitches) p.midiNumber % 12};
        expect(pitchClassesOf(numeral, key), original,
            reason: '$notes → ${numeral.symbol}');
      }
    });

    test('minor raised 6/7 and their secondary chords round-trip', () {
      // Regression: a chord rooted on the raised 6/7 of a minor key is written
      // without an accidental (vii°, not #vii°), but pitchClassesOf used to
      // reconstruct it on the natural degree — a semitone off. It now carries
      // the real alteration internally while the symbol stays bare.
      final cMinor = Key.minor(note('c4'));
      for (final (notes, key) in [
        ('g#4 b4 d5', aMinor), // vii° on the raised 7 (leading tone)
        ('f#4 a4 c5', aMinor), // vi° on the raised 6
        ('f4 a4 c5', aMinor), // VI on the natural 6 (unchanged)
        ('g4 b4 d5', aMinor), // VII on the natural 7 (unchanged)
        ('e4 g#4 b4', cMinor), // V/VI — E major, dominant of the raised 6 (A)
      ]) {
        final numeral = romanNumeralOf(chord(notes), key)!;
        final original = {for (final p in chord(notes)) p.midiNumber % 12};
        expect(pitchClassesOf(numeral, key), original,
            reason: '$notes → ${numeral.symbol}');
      }
      // The leading-tone chord still prints without an accidental.
      expect(romanNumeralOf(chord('g#4 b4 d5'), aMinor)!.symbol, 'vii°');
    });
  });
}

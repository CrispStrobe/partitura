import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Phase 7.5: Braille music export. Expected cells are written as dot-number
/// lists (1–6) so they read against a braille chart.
String cell(List<int> dots) {
  var bits = 0;
  for (final d in dots) {
    bits |= 1 << (d - 1);
  }
  return String.fromCharCode(0x2800 + bits);
}

String cells(List<List<int>> each) => each.map(cell).join();

void main() {
  group('scoreToBraille', () {
    test('a single quarter middle-C = octave-4 mark + C-quarter sign', () {
      // Octave 4 = dots 5; quarter C = name C (1,4,5) + value dot 6.
      expect(
          scoreToBraille(Score.simple(notes: 'c4:q')),
          cells([
            [5],
            [1, 4, 5, 6]
          ]));
    });

    test('the four note values on middle C', () {
      String only(String notes) =>
          scoreToBraille(Score.simple(notes: notes)).substring(1); // drop 8ve
      expect(only('c4:w'), cell([1, 3, 4, 5, 6])); // whole   ⠽
      expect(only('c4:h'), cell([1, 3, 4, 5])); //     half    ⠝
      expect(only('c4:q'), cell([1, 4, 5, 6])); //     quarter ⠹
      expect(only('c4:e'), cell([1, 4, 5])); //        eighth  ⠙
    });

    test('the seven note names (eighth signs = letters d–j)', () {
      String note(String n) =>
          scoreToBraille(Score.simple(notes: '$n:e')).substring(1);
      expect(note('c4'), cell([1, 4, 5])); // d
      expect(note('d4'), cell([1, 5])); // e
      expect(note('e4'), cell([1, 2, 4])); // f
      expect(note('f4'), cell([1, 2, 4, 5])); // g
      expect(note('g4'), cell([1, 2, 5])); // h
      expect(note('a4'), cell([2, 4])); // i
      expect(note('b4'), cell([2, 4, 5])); // j
    });

    test('a C-major scale marks only the first octave', () {
      final braille =
          scoreToBraille(Score.simple(notes: 'c4:q d4 e4 f4 g4 a4 b4 c5'));
      // Octave marks are the seven cells {4},{45},{456},{5},{46},{56},{6}.
      const marks = [
        [4], [4, 5], [4, 5, 6], [5], [4, 6], [5, 6], [6] //
      ];
      final markChars = {for (final m in marks) cell(m)};
      final count =
          braille.split('').where((c) => markChars.contains(c)).length;
      expect(count, 1, reason: 'stepwise motion needs no further octave marks');
    });

    test('octave marks follow the interval rule', () {
      String brl(String notes) => scoreToBraille(Score.simple(notes: notes));
      final o4 = cell([5]);
      final o5 = cell([4, 6]);
      // A 4th within the same octave: no mark on the second note.
      expect(brl('c4:q f4').contains(o4 + cell([5])), isFalse);
      expect(brl('c4:q f4'), startsWith(o4)); // only the first
      // A 4th that changes octave (g4 → c5): the second note IS marked.
      expect(brl('g4:q c5').endsWith(o5 + cell([1, 4, 5, 6])), isTrue);
      // A 6th or more (c4 → c5, an octave): marked.
      expect(brl('c4:q c5').endsWith(o5 + cell([1, 4, 5, 6])), isTrue);
    });

    test('accidentals show only when not implied by the key', () {
      final sharp = cell([1, 4, 6]);
      // The music sits after any signature header (split off the leading space).
      String music(String b) => b.split(' ').last;
      // F# in C major prints a sharp (no header).
      expect(
          music(scoreToBraille(Score.simple(notes: 'f#4:q'))).contains(sharp),
          isTrue);
      // F# in G major (F already sharp) prints none on the note.
      expect(
          music(scoreToBraille(Score.simple(
                  notes: 'f#4:q', keySignature: const KeySignature(1))))
              .contains(sharp),
          isFalse);
      // A natural cancelling the key prints a natural sign.
      expect(
          music(scoreToBraille(Score.simple(
                  notes: 'f4:q', keySignature: const KeySignature(1))))
              .contains(cell([1, 6])),
          isTrue);
    });

    test('dotted notes add an augmentation-dot cell', () {
      // c4:q. → octave + quarter C (value dot 6) + one aug dot (dot 3).
      expect(
          scoreToBraille(Score.simple(notes: 'c4:q.')),
          cells([
            [5],
            [1, 4, 5, 6],
            [3]
          ]));
    });

    test('rests use the value rest signs', () {
      expect(scoreToBraille(Score.simple(notes: 'r:q')), cell([1, 2, 3, 6]));
      expect(scoreToBraille(Score.simple(notes: 'r:h')), cell([1, 3, 6]));
      expect(scoreToBraille(Score.simple(notes: 'r:w')), cell([1, 3, 4]));
      expect(scoreToBraille(Score.simple(notes: 'r:e')), cell([1, 3, 4, 6]));
    });

    test('a key signature prints as a leading header', () {
      // G major = one sharp, then a space, then the music.
      final b = scoreToBraille(
          Score.simple(notes: 'c4:q', keySignature: const KeySignature(1)));
      expect(b, startsWith('${cell([1, 4, 6])} ')); // ♯ + space
      // Two flats repeat the flat sign.
      final bf = scoreToBraille(
          Score.simple(notes: 'c4:q', keySignature: const KeySignature(-2)));
      expect(
          bf,
          startsWith(cells([
            [1, 2, 6],
            [1, 2, 6]
          ])));
    });

    test('a time signature prints as number sign + upper/lower digits', () {
      final b = scoreToBraille(
          Score.simple(notes: 'c4:w', timeSignature: TimeSignature.fourFour));
      // ⠼ (number) + upper-4 + lower-4, then a space.
      expect(
          b,
          startsWith(cells([
            [3, 4, 5, 6],
            [1, 4, 5],
            [2, 5, 6]
          ])));
    });

    test('a chord is the top note plus downward interval signs', () {
      // C-E-G → reference G (top), a 3rd and a 5th below it.
      expect(
          scoreToBraille(Score.simple(notes: 'c4+e4+g4:q')),
          cells([
            [5], // octave-4 mark on the reference
            [1, 2, 5, 6], // G quarter (reference)
            [3, 4, 6], // 3rd (down to E)
            [3, 5], // 5th (down to C)
          ]));
    });

    test('an octave chord uses the octave interval sign', () {
      // C4 + C5 → reference C5, one octave below it.
      expect(
          scoreToBraille(Score.simple(notes: 'c4+c5:q')),
          cells([
            [4, 6], // octave-5 mark on the reference
            [1, 4, 5, 6], // C5 quarter (reference)
            [1, 2, 3, 4, 5, 6], // octave interval down to C4
          ]));
    });

    test('a mid-score key change prints its new signature (7.5)', () {
      final score = Score(
        clef: Clef.treble,
        measures: [
          Measure([
            NoteElement.note(
                const Pitch(Step.c, octave: 4), NoteDuration.quarter),
          ]),
          Measure([
            NoteElement.note(
                const Pitch(Step.c, octave: 4), NoteDuration.quarter),
          ], keyChange: const KeySignature(1)), // → G major, one sharp
        ],
      );
      final parts = scoreToBraille(score).split(' ');
      expect(parts, hasLength(2));
      expect(parts[1], startsWith(cell([1, 4, 6]))); // ♯ leads measure 2
    });

    test('a mid-score time change prints its new signature (7.5)', () {
      final score = Score(
        clef: Clef.treble,
        timeSignature: TimeSignature.fourFour,
        measures: [
          Measure([
            NoteElement.note(const Pitch(Step.c, octave: 4), NoteDuration.half),
          ]),
          Measure([
            NoteElement.note(const Pitch(Step.c, octave: 4), NoteDuration.half),
          ], timeChange: const TimeSignature(3, 4)),
        ],
      );
      // Measure 2 (after the leading 4/4 header + m1) opens with 3/4.
      final parts = scoreToBraille(score).split(' ');
      expect(
          parts.last,
          startsWith(cells([
            [3, 4, 5, 6],
            [1, 4],
            [2, 5, 6]
          ]))); // ⠼ 3 4
    });

    test('measures are separated by a braille space', () {
      final braille = scoreToBraille(Score.simple(notes: 'c4:q d4 | e4:q f4'));
      final parts = braille.split(' ');
      expect(parts, hasLength(2));
      // The first note of measure 2 (E, after D) is a 2nd → no octave mark;
      // both are quarters (name dots + value dot 6).
      expect(
          parts[1],
          cells([
            [1, 2, 4, 6],
            [1, 2, 4, 5, 6]
          ]));
    });
  });

  group('edge cases', () {
    String only(Pitch p, NoteDuration d) => scoreToBraille(Score(
          clef: Clef.treble,
          measures: [
            Measure([NoteElement.note(p, d)])
          ],
        )); // no header (C major, unmetered)

    test('double sharp / double flat print the sign twice', () {
      expect(
          only(const Pitch(Step.c, alter: 2, octave: 4), NoteDuration.quarter),
          startsWith(cells([
            [1, 4, 6],
            [1, 4, 6]
          ]))); // ♯♯
      expect(
          only(const Pitch(Step.b, alter: -2, octave: 3), NoteDuration.quarter),
          startsWith(cells([
            [1, 2, 6],
            [1, 2, 6]
          ]))); // ♭♭
    });

    test('octaves outside 1–7 clamp to the end marks', () {
      // C0 clamps to the octave-1 mark; C8 to the octave-7 mark.
      expect(only(const Pitch(Step.c, octave: 0), NoteDuration.quarter),
          startsWith(cell([4]))); // octave 1
      expect(only(const Pitch(Step.c, octave: 8), NoteDuration.quarter),
          startsWith(cell([6]))); // octave 7
    });

    test('16th/32nd reuse the whole/half value cells', () {
      // A 16th shares the whole-note pattern (dots 3+6); a 32nd shares the half.
      expect(
          only(const Pitch(Step.c, octave: 4),
              const NoteDuration(DurationBase.sixteenth)),
          cells([
            [5],
            [1, 3, 4, 5, 6]
          ])); // octave-4 + C "whole" cell
      expect(
          only(const Pitch(Step.c, octave: 4),
              const NoteDuration(DurationBase.thirtySecond)),
          cells([
            [5],
            [1, 3, 4, 5]
          ])); // octave-4 + C "half" cell
    });
  });

  group('multiPartToBraille', () {
    test('renders every part (labelled), not just the first', () {
      final mp = MultiPartScore([
        Score.simple(notes: 'c4:q'),
        Score.simple(notes: 'g4:q'),
      ]);
      final out = multiPartToBraille(mp, partNames: const ['Soprano', 'Bass']);
      expect(out, contains('Soprano'));
      expect(out, contains('Bass'));
      // Both parts' braille is present — the old first-part-only path dropped
      // the second.
      expect(out, contains(scoreToBraille(Score.simple(notes: 'c4:q'))));
      expect(out, contains(scoreToBraille(Score.simple(notes: 'g4:q'))));
    });

    test('a single-part score matches scoreToBraille exactly', () {
      final s = Score.simple(notes: 'c4:q d4 e4');
      expect(multiPartToBraille(MultiPartScore([s])), scoreToBraille(s));
    });
  });
}

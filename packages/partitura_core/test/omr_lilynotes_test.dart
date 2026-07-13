import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  group('scoreFromLilyNotes', () {
    test('parses pitches, octave marks, rests and durations', () {
      // The real Flova output on sample1.png.
      final score =
          scoreFromLilyNotes("c'2 a''8 c''8 r4 c'1 e'8 c'8 c'8 a''8 f'4");
      expect(score.clef, Clef.treble);
      expect(score.timeSignature, isNull); // unmetered
      final els = score.measures.single.elements;
      // c'2 → C4 half note.
      final n0 = els[0] as NoteElement;
      expect(n0.pitches.single.step, Step.c);
      expect(n0.pitches.single.octave, 4);
      expect(n0.duration.base, DurationBase.half);
      // a''8 → A5 eighth.
      final n1 = els[1] as NoteElement;
      expect(n1.pitches.single.step, Step.a);
      expect(n1.pitches.single.octave, 5);
      expect(n1.duration.base, DurationBase.eighth);
      // r4 → quarter rest.
      expect(els[3], isA<RestElement>());
      expect((els[3] as RestElement).duration.base, DurationBase.quarter);
    });

    test('accidentals and downward octaves', () {
      final els = scoreFromLilyNotes("cis'4 bes,8 ees8")
          .measures
          .single
          .elements
          .cast<NoteElement>();
      expect(els[0].pitches.single.alter, 1); // cis = C♯
      expect(els[0].pitches.single.octave, 4);
      expect(els[1].pitches.single.alter, -1); // bes = B♭
      expect(els[1].pitches.single.octave, 2); // b, = one below default
      expect(els[2].pitches.single.alter, -1); // ees = E♭
    });

    test('bare notes inherit the previous duration', () {
      final els = scoreFromLilyNotes("c'4 d' e'")
          .measures
          .single
          .elements
          .cast<NoteElement>();
      expect(els.every((n) => n.duration.base == DurationBase.quarter), isTrue);
    });

    test('dotted durations', () {
      final n = scoreFromLilyNotes("c'4.").measures.single.elements.single
          as NoteElement;
      expect(n.duration.dots, 1);
    });

    test('empty / unrecognised input throws', () {
      expect(() => scoreFromLilyNotes('   '), throwsFormatException);
    });
  });

  test('omrDialectOf detects LilyPond notes (Flova)', () {
    expect(omrDialectOf("c'2 a''8 r4 c'1"), OmrDialect.lilyNotes);
    expect(omrDialectOf('clef-G2 note-C5_eighth'), OmrDialect.semantic);
    expect(omrDialectOf('**kern <t> **kern <b> 4 c'), OmrDialect.bekern);
  });

  group('lilynotes edge cases', () {
    test('double sharp / double flat', () {
      final els = scoreFromLilyNotes("cisis'4 deses'4")
          .measures
          .single
          .elements
          .cast<NoteElement>();
      expect(els[0].pitches.single.alter, 2); // cisis = C𝄪
      expect(els[1].pitches.single.alter, -2); // deses = D𝄫
    });

    test('multiple octave marks up and down', () {
      final els = scoreFromLilyNotes("c'''4 c,,4")
          .measures
          .single
          .elements
          .cast<NoteElement>();
      expect(els[0].pitches.single.octave, 6); // c''' = C6
      expect(els[1].pitches.single.octave, 1); // c,, = C1
    });

    test('unrecognised tokens are skipped, not fatal', () {
      final els = scoreFromLilyNotes(r"c'4 \time garbage d'4")
          .measures
          .single
          .elements;
      expect(els.length, 2); // only the two notes survive
    });

    test('a rest with no duration inherits the previous one', () {
      final els =
          scoreFromLilyNotes("c'8 r").measures.single.elements;
      expect(els[1], isA<RestElement>());
      expect((els[1] as RestElement).duration.base, DurationBase.eighth);
    });
  });
}

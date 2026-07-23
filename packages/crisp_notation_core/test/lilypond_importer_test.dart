import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

void main() {
  group('LilyPond Importer', () {
    test('parses simple absolute notes and durations', () {
      final score = scoreFromLilyPond(r"{ c'4 d'8 e'8 f'2 }");
      expect(score.measures.length, 1);
      final m = score.measures.first;
      expect(m.elements.length, 4);
      
      final c = m.elements[0] as NoteElement;
      expect(c.pitches.single.step, Step.c);
      expect(c.pitches.single.octave, 4);
      expect(c.duration, NoteDuration.quarter);
      
      final f = m.elements[3] as NoteElement;
      expect(f.pitches.single.step, Step.f);
      expect(f.pitches.single.octave, 4);
      expect(f.duration, NoteDuration.half);
    });

    test('parses relative mode and handles octave shifts', () {
      final score = scoreFromLilyPond(r"\relative c' { c4 d e f g a b c }");
      // c' is C4. C->D->E->F->G->A->B->C (C5)
      expect(score.measures.length, 2); // 4/4 time signature means 8 quarters is 2 measures
      final m1 = score.measures[0];
      final m2 = score.measures[1];
      expect(m1.elements.length, 4);
      expect(m2.elements.length, 4);
      
      final c4 = m1.elements[0] as NoteElement;
      expect(c4.pitches.single.octave, 4);
      
      final c5 = m2.elements[3] as NoteElement;
      expect(c5.pitches.single.octave, 5);
      expect(c5.pitches.single.step, Step.c);
    });

    test('parses chords and rests', () {
      final score = scoreFromLilyPond(r"{ <c' e' g'>4. r8 }");
      expect(score.measures.length, 1);
      final m = score.measures.first;
      
      final chord = m.elements[0] as NoteElement;
      expect(chord.pitches.length, 3);
      expect(chord.duration.base, DurationBase.quarter);
      expect(chord.duration.dots, 1);
      
      final rest = m.elements[1] as RestElement;
      expect(rest.duration.base, DurationBase.eighth);
    });
    
    test('parses time signature and clef commands', () {
      final score = scoreFromLilyPond(r"\clef bass \time 3/4 c4 d e");
      expect(score.clef, Clef.bass);
      expect(score.timeSignature?.beats, 3);
      expect(score.timeSignature?.beatUnit, 4);
    });
  });
}

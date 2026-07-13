import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  group('scoreFromSemantic', () {
    test('reads clef, key, meter, notes and rests into measures', () {
      const s = 'clef-G2+keySignature-GM+timeSignature-2/4+'
          'note-C5_quarter+rest-eighth+note-D5_eighth+barline+'
          'note-E5_half+barline';
      final score = scoreFromSemantic(s);
      expect(score.clef, Clef.treble);
      expect(score.keySignature.fifths, 1); // G major = 1 sharp
      expect(score.timeSignature, const TimeSignature(2, 4));
      expect(score.measures.length, 2);
      final m0 = score.measures.first.elements;
      expect(m0[0], isA<NoteElement>());
      expect((m0[0] as NoteElement).pitches.single.step, Step.c);
      expect((m0[0] as NoteElement).pitches.single.octave, 5);
      expect(m0[1], isA<RestElement>());
      expect((m0[2] as NoteElement).duration.base, DurationBase.eighth);
    });

    test('parses accidentals and dotted durations', () {
      const s = 'clef-G2+note-C#5_quarter.+note-Bb4_eighth+barline';
      final notes = scoreFromSemantic(s)
          .measures
          .expand((Measure m) => m.elements)
          .whereType<NoteElement>()
          .toList();
      expect(notes[0].pitches.single.alter, 1); // C#
      expect(notes[0].duration.dots, 1); // dotted quarter
      expect(notes[1].pitches.single.alter, -1); // Bb
    });

    test('parses a chord written with | into one NoteElement', () {
      const s = 'clef-G2+note-C4_quarter|note-E4_quarter|note-G4_quarter+barline';
      final note = scoreFromSemantic(s)
          .measures
          .first
          .elements
          .whereType<NoteElement>()
          .single;
      expect(note.pitches.map((p) => p.step),
          containsAll([Step.c, Step.e, Step.g]));
      expect(note.duration.base, DurationBase.quarter);
    });

    test('nonote_<dur> becomes a rest', () {
      const s = 'clef-G2+nonote_eighth+note-C5_eighth+barline';
      final els = scoreFromSemantic(s).measures.first.elements;
      expect(els.first, isA<RestElement>());
      expect((els.first as RestElement).duration.base, DurationBase.eighth);
    });

    test('minor key maps to the right signature', () {
      final score = scoreFromSemantic('clef-G2+keySignature-Am+note-A4_quarter');
      expect(score.keySignature.fifths, 0); // A minor
    });

    test('common/cut meter symbols', () {
      expect(scoreFromSemantic('clef-G2+timeSignature-C+note-C4_whole')
          .timeSignature
          ?.symbol,
          TimeSymbol.common);
    });
  });

  group('real TrOMR output', () {
    // First bars from the engine on tromr_ex1_input.png (q8_0).
    const real = 'clef-G2+keySignature-CM+nonote_eighth+nonote_eighth+'
        'note-E5_eighth+note-F5_eighth+note-G5_eighth+note-A5_eighth+'
        'note-B5_eighth+note-C6_eighth+nonote_eighth+note-E5_eighth+'
        'note-F5_eighth+note-G5_eighth+barline+note-G5_eighth+note-G5_eighth+'
        'barline';

    test('parses into a treble Score without throwing', () {
      final score = scoreFromSemantic(real);
      expect(score.clef, Clef.treble);
      expect(score.keySignature.fifths, 0);
      expect(score.measures.length, greaterThanOrEqualTo(2));
      final first = score.measures.first.elements.whereType<NoteElement>().first;
      expect(first.pitches.single.step, Step.e);
      expect(first.pitches.single.octave, 5);
    });

    test('round-trips through MusicXML', () {
      final xml = scoreToMusicXml(scoreFromSemantic(real));
      expect(xml, contains('<score-partwise'));
      expect(xml, contains('<note>'));
    });
  });

  test('omrDialectOf distinguishes semantic from bekern', () {
    expect(omrDialectOf('clef-G2+note-C5_eighth'), OmrDialect.semantic);
    expect(omrDialectOf('**kern <t> **kern <b> 4 c'), OmrDialect.bekern);
  });

  group('semantic clefs/keys/meters', () {
    test('bass and C-clefs map correctly', () {
      expect(scoreFromSemantic('clef-F4+4 C').clef, Clef.bass);
      expect(scoreFromSemantic('clef-C3+4c').clef, Clef.alto);
      expect(scoreFromSemantic('clef-C4+4c').clef, Clef.tenor);
    });

    test('sharp and flat key signatures', () {
      expect(scoreFromSemantic('clef-G2+keySignature-DM+4c').keySignature.fifths,
          2); // D major = 2 sharps
      expect(scoreFromSemantic('clef-G2+keySignature-BbM+4c').keySignature.fifths,
          -2); // B♭ major = 2 flats
      expect(scoreFromSemantic('clef-G2+keySignature-F#m+4c').keySignature.fifths,
          3); // F♯ minor = 3 sharps
    });

    test('cut time maps to a 2/2 cut symbol', () {
      final t = scoreFromSemantic('clef-G2+timeSignature-C/+4c').timeSignature;
      expect(t, const TimeSignature(2, 2, symbol: TimeSymbol.cut));
    });

    test('mid-score clef change lands on a later measure', () {
      final score = scoreFromSemantic(
          'clef-G2+note-C5_quarter+barline+clef-F4+note-C3_quarter+barline');
      expect(score.clef, Clef.treble); // leading
      expect(
          score.measures.any((m) => m.clefChange == Clef.bass), isTrue);
    });

    test('barlines split measures', () {
      final score = scoreFromSemantic('clef-G2+note-C5_quarter+barline+'
          'note-D5_quarter+barline+note-E5_quarter');
      expect(score.measures.length, 3);
    });
  });
}

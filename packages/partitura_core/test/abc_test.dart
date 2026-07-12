import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

List<String> _pitches(Score s) => [
      for (final m in s.measures)
        for (final e in m.elements)
          if (e is NoteElement)
            e.pitches
                .map((p) => '${p.step.name}${p.alter}/${p.octave}')
                .join('+')
          else
            'rest',
    ];

List<String> _durs(Score s) => [
      for (final m in s.measures)
        for (final e in m.elements)
          '${e.duration.base.name}.${e.duration.dots}',
    ];

void main() {
  group('ABC import', () {
    test('header: meter, unit length, key, clef', () {
      final s = scoreFromAbc('X:1\nM:3/4\nL:1/4\nK:Bb\nB c d|\n');
      expect(s.timeSignature, const TimeSignature(3, 4));
      expect(s.keySignature.fifths, -2); // Bb major
      expect(s.measures.single.elements, hasLength(3));
    });

    test('modes map to the right key signature', () {
      expect(scoreFromAbc('X:1\nK:Edor\nE|\n').keySignature.fifths, 2);
      expect(scoreFromAbc('X:1\nK:Am\nA|\n').keySignature.fifths, 0);
      expect(scoreFromAbc('X:1\nK:Dm\nD|\n').keySignature.fifths, -1);
      expect(scoreFromAbc('X:1\nK:Gmix\nG|\n').keySignature.fifths, 0);
    });

    test('pitches: octave marks and default note length', () {
      final s = scoreFromAbc('X:1\nL:1/8\nK:C\nC, C c c2 c\'|\n');
      final notes = s.measures.single.elements.cast<NoteElement>();
      expect(notes.map((n) => n.pitches.single.octave), [3, 4, 5, 5, 6]);
      expect(notes[3].duration, NoteDuration.quarter); // c2 at L=1/8
    });

    test('key signature applies to unmarked notes; naturals persist', () {
      // In G major, F is sharp; =F is natural and holds for the measure.
      final s = scoreFromAbc('X:1\nL:1/4\nK:G\nF =F F | F|\n');
      final m0 = s.measures[0].elements.cast<NoteElement>();
      expect(m0[0].pitches.single.alter, 1); // key sharp
      expect(m0[1].pitches.single.alter, 0); // explicit natural
      expect(m0[2].pitches.single.alter, 0); // natural persists in the bar
      expect(s.measures[1].elements.cast<NoteElement>()[0].pitches.single.alter,
          1); // sharp again next bar
    });

    test('broken rhythm, ties, tuplets, slurs, grace, staccato', () {
      final s = scoreFromAbc(
          'X:1\nM:4/4\nL:1/4\nK:C\nA>B c<d|(3EFG A-A|{gg}B .c d e|\n');
      final m0 = s.measures[0].elements.cast<NoteElement>();
      expect(m0.map((n) => '${n.duration.base.name}.${n.duration.dots}'),
          ['quarter.1', 'eighth.0', 'eighth.0', 'quarter.1']);
      expect(s.measures[1].tuplets.single.actual, 3);
      expect(s.measures[1].elements.cast<NoteElement>()[3].tieToNext, isTrue);
      expect(s.slurs, isEmpty); // none here
      final m2 = s.measures[2].elements.cast<NoteElement>();
      expect(m2[0].graceNotes, hasLength(2));
      expect(m2[1].articulations, {Articulation.staccato});
    });

    test('slurs and quoted chord symbols', () {
      final s = scoreFromAbc('X:1\nL:1/4\nK:C\n"C"(CE) "G"G z|\n');
      expect(s.slurs, hasLength(1));
      expect(s.annotations.map((a) => a.text), ['C', 'G']);
    });

    test('bar lines: repeats and double/final', () {
      final s = scoreFromAbc('X:1\nL:1/4\nK:C\n|:C D:| E F|| G4|]\n');
      expect(s.measures[0].startRepeat, isTrue);
      expect(s.measures[0].endRepeat, isTrue);
      expect(s.measures[1].barline, BarlineStyle.doubleBar);
      expect(s.measures[2].barline, BarlineStyle.finalBar);
    });

    test('w: lyrics align to notes with hyphens', () {
      final s = scoreFromAbc('X:1\nL:1/4\nK:G\nB A G A|\n'
          'w:Ma- ry had a\n');
      expect(s.lyrics.map((l) => l.text), ['Ma', 'ry', 'had', 'a']);
      expect(s.lyrics.first.hyphenToNext, isTrue);
    });

    test('multi-voice imports the first voice', () {
      final s = scoreFromAbc('X:1\nM:4/4\nL:1/4\nV:1\nV:2\nK:C\n'
          '[V:1] C D E F|\n[V:2] c d e f|\n');
      final octaves = s.measures.single.elements
          .cast<NoteElement>()
          .map((n) => n.pitches.single.octave);
      expect(octaves, everyElement(4)); // voice 1 (uppercase), not voice 2
    });

    test('a missing K: field is a FormatException', () {
      expect(
          () => scoreFromAbc('X:1\nT:No key\nCDEF\n'), throwsFormatException);
    });
  });

  group('ABC round-trip (score → abc → score)', () {
    void roundTrips(String abc) {
      final src = scoreFromAbc(abc);
      final back = scoreFromAbc(scoreToAbc(src));
      expect(_pitches(back), _pitches(src), reason: 'pitches');
      expect(_durs(back), _durs(src), reason: 'durations');
      expect(back.keySignature.fifths, src.keySignature.fifths);
      expect(back.timeSignature, src.timeSignature);
      expect(back.measures.length, src.measures.length);
      expect(back.annotations.map((a) => a.text),
          src.annotations.map((a) => a.text));
    }

    test('melody with accidentals, rhythm, rests', () {
      roundTrips('X:1\nM:4/4\nL:1/8\nK:G\n'
          'GABc d2e2|f2 ^f2 g4|_B2 =B2 c2 z2|A3/2 B/2 c d|\n');
    });

    test('chords, ties, tuplets, repeats', () {
      roundTrips('X:1\nM:4/4\nL:1/4\nK:D\n'
          '|:[CEG] A-A z|(3ABc d:|E F G A|]\n');
    });

    test('a scale in a flat key', () {
      roundTrips('X:1\nM:4/4\nL:1/4\nK:Eb\nE F G A|B c d e|\n');
    });
  });
}

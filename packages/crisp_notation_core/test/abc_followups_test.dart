// ABC codec follow-up fixes: octave-specific accidental carry, sparse-lyric
// alignment (`*` for unsung notes), and a mid-piece final barline style.

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

List<NoteElement> _notesOf(Score s) => [
      for (final m in s.measures)
        for (final e in m.elements)
          if (e is NoteElement) e,
    ];

NoteElement _n(Step s, NoteDuration d, {int octave = 4, String? id}) =>
    NoteElement(
      pitches: [Pitch(s, octave: octave)],
      duration: d,
      id: id,
    );

const _q = NoteDuration(DurationBase.quarter);

void main() {
  test('an accidental carries only within the same octave', () {
    // Bar: ^c (C#5) then c, (C4). ABC 2.1: the sharp does NOT carry to the
    // lower-octave c — it reads natural.
    final score = scoreFromAbc('X:1\nT:t\nM:4/4\nL:1/4\nK:C\n^c c, z2 |\n');
    final notes = _notesOf(score);
    expect(notes, hasLength(greaterThanOrEqualTo(2)));
    final high = notes[0].pitches.single;
    final low = notes[1].pitches.single;
    expect(high.step, Step.c);
    expect(high.alter, 1, reason: '^c is C#');
    expect(low.step, Step.c);
    expect(low.octave, lessThan(high.octave), reason: 'c, is an octave lower');
    expect(
      low.alter,
      0,
      reason: 'the sharp must NOT carry to the lower-octave c',
    );
  });

  test('a sparse lyric line round-trips onto its own notes', () {
    // Three notes; a syllable on note 1 and note 3 only (note 2 unsung).
    final score = Score(
      clef: Clef.treble,
      measures: [
        Measure([
          _n(Step.c, _q, id: 'a'),
          _n(Step.d, _q, id: 'b'),
          _n(Step.e, _q, id: 'c'),
          _n(Step.f, _q, id: 'd'),
        ]),
      ],
      lyrics: const [Lyric('a', 'do'), Lyric('c', 'mi')],
    );
    final back = scoreFromAbc(scoreToAbc(score));
    // The reader binds lyrics by the note ids it assigns; check text→pitch.
    final notes = _notesOf(back);
    String? lyricAt(String id) {
      for (final l in back.lyrics) {
        if (l.elementId == id) return l.text;
      }
      return null;
    }

    // Map the re-read note ids by their step so we can locate note 1 and 3.
    String idOfStep(Step s) =>
        notes.firstWhere((n) => n.pitches.single.step == s).id!;
    expect(
      lyricAt(idOfStep(Step.c)),
      'do',
      reason: 'note 1 keeps its syllable',
    );
    expect(lyricAt(idOfStep(Step.d)), isNull, reason: 'note 2 stays unsung');
    expect(
      lyricAt(idOfStep(Step.e)),
      'mi',
      reason: 'note 3 keeps its syllable (not shifted to note 2)',
    );
  });

  test('a mid-piece final barline keeps its style', () {
    final score = Score(
      clef: Clef.treble,
      measures: [
        Measure([
          _n(Step.c, _q),
          _n(Step.d, _q),
          _n(Step.e, _q),
          _n(Step.f, _q),
        ], barline: BarlineStyle.finalBar),
        Measure([
          _n(Step.g, _q),
          _n(Step.a, _q),
          _n(Step.b, _q),
          _n(Step.c, _q, octave: 5),
        ]),
      ],
    );
    final back = scoreFromAbc(scoreToAbc(score));
    expect(
      back.measures.first.barline,
      BarlineStyle.finalBar,
      reason: 'the mid-piece final barline was written as plain |',
    );
  });
}

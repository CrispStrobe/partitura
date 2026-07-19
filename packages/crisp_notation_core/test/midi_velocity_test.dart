// MIDI note velocity survives the model: scoreFromMidi captures each note-on's
// velocity into NoteElement.velocity, and scoreToMidi writes it back — so a
// MIDI's per-note dynamics round-trip (and a player can voice them).

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

List<int?> _velocities(Score s) => [
      for (final m in s.measures)
        for (final e in m.elements)
          if (e is NoteElement) e.velocity,
    ];

void main() {
  test('velocity round-trips through MIDI', () {
    final score = Score(
      clef: Clef.treble,
      measures: [
        Measure([
          NoteElement(
            id: 'e0',
            pitches: const [Pitch(Step.c)],
            duration: NoteDuration.quarter,
            velocity: 40,
          ),
          NoteElement(
            id: 'e1',
            pitches: const [Pitch(Step.e)],
            duration: NoteDuration.quarter,
            velocity: 120,
          ),
        ]),
      ],
    );

    final back = scoreFromMidi(scoreToMidi(score));
    final vels = _velocities(back).whereType<int>().toList();
    expect(vels, containsAll([40, 120]),
        reason: 'each note-on velocity is preserved');
  });

  test('a score without velocity exports at the default (unchanged)', () {
    final score = Score(
      clef: Clef.treble,
      measures: [
        Measure([
          NoteElement(
            id: 'e0',
            pitches: const [Pitch(Step.c)],
            duration: NoteDuration.quarter,
          ),
        ]),
      ],
    );
    // No explicit velocity → the default 80 is written, then read back as 80.
    final back = scoreFromMidi(scoreToMidi(score));
    expect(_velocities(back), [80]);
  });
}

// Blind reader-robustness fuzz for the GPIF XML reader (covfuzz). The seed is a
// rich score.gpif (voice 2, tuplet, key, dynamics, grace notes, lyrics,
// techniques) so string mutations exercise every parse path.
//   dart run tool/fuzz_gpif.dart
import 'dart:io';

import 'package:covfuzz/covfuzz.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart';

void main() {
  final rich = Score(
    clef: Clef.treble,
    keySignature: const KeySignature(2),
    timeSignature: TimeSignature.fourFour,
    measures: [
      Measure(
        [
          NoteElement(
              pitches: [Pitch.parse('c5')],
              duration: NoteDuration.quarter,
              id: 'e0',
              graceNotes: [Pitch.parse('a4')],
              articulations: {Articulation.staccato}),
          NoteElement(
              pitches: [Pitch.parse('d5')],
              duration: NoteDuration.eighth,
              id: 'e1'),
          NoteElement(
              pitches: [Pitch.parse('e5')],
              duration: NoteDuration.eighth,
              id: 'e2'),
          NoteElement(
              pitches: [Pitch.parse('f5')],
              duration: NoteDuration.eighth,
              id: 'e3'),
        ],
        voice2: [
          NoteElement(
              pitches: [Pitch.parse('g3')],
              duration: NoteDuration.half,
              id: 'v0')
        ],
        tuplets: const [TupletSpan(1, 3, actual: 3, normal: 2)],
        keyChange: const KeySignature(-1),
      ),
    ],
    dynamics: const [DynamicMarking('e0', DynamicLevel.pp)],
    bends: const [Bend('e2', steps: 1.0)],
    tabNoteMarks: const [TabNoteMark('e3', TabNoteStyle.harmonic)],
    lyrics: const [Lyric('e0', 'Do', hyphenToNext: true), Lyric('e1', 're')],
  );
  final seed = scoreToGpif(rich);

  final r = fuzz<String>(
    seeds: [seed],
    entry: scoreFromGpif,
    mutate: mutateString,
    isClean: (e) => e is FormatException,
    iterations: 400000,
    budgetMs: 30000,
    stressors: ['', '<GPIF>', '<GPIF></GPIF>', '<GPIF>' * 1000],
  );
  exit(r.report());
}

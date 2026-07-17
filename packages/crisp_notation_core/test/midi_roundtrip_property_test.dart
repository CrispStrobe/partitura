import 'dart:math';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Property-based MIDI round-trip.
///
/// MIDI is a documented lossy target: it drops spelling, clef, key, voices,
/// ties and articulations, and quantizes onsets/durations to a sixteenth-note
/// grid. What it *must* preserve is the **sustain grid** — which sounding MIDI
/// pitches are active in each sixteenth-note slot. For a single-voice score
/// built on that grid, `scoreFromMidi(scoreToMidi(s))` must reproduce the grid
/// exactly, however the reader chooses to renotate (tie-splitting across
/// barlines, sharps-only spelling, chord merging).
void main() {
  // Note/rest values that are a whole number of sixteenth-notes.
  const durs = <(NoteDuration, int)>[
    (NoteDuration(DurationBase.sixteenth), 1),
    (NoteDuration(DurationBase.eighth), 2),
    (NoteDuration(DurationBase.eighth, dots: 1), 3),
    (NoteDuration(DurationBase.quarter), 4),
    (NoteDuration(DurationBase.quarter, dots: 1), 6),
    (NoteDuration(DurationBase.half), 8),
    (NoteDuration(DurationBase.half, dots: 1), 12),
    (NoteDuration(DurationBase.whole), 16),
  ];
  const meters = <(int, int)>[
    (4, 4), (3, 4), (2, 4), (6, 8), (3, 8), (5, 4), (7, 8), (5, 8), (12, 8),
    (2, 2), //
  ];

  Pitch pitch(Random rng) => Pitch(Step.values[rng.nextInt(7)],
      alter: rng.nextInt(3) - 1, octave: 2 + rng.nextInt(5));

  Score generate(int seed) {
    final rng = Random(seed);
    var id = 0;
    final meter = meters[rng.nextInt(meters.length)];
    final ts = TimeSignature(meter.$1, meter.$2);
    final cap = ts.measureCapacity;
    final capUnits = 16 * cap.$1 ~/ cap.$2; // sixteenths per bar
    final measures = <Measure>[];
    for (var b = 0; b < 1 + rng.nextInt(4); b++) {
      final els = <MusicElement>[];
      var remaining = capUnits;
      while (remaining > 0) {
        final choices = durs.where((d) => d.$2 <= remaining).toList();
        final pick = choices[rng.nextInt(choices.length)];
        remaining -= pick.$2;
        if (rng.nextInt(6) == 0) {
          els.add(RestElement(pick.$1, id: 'e${id++}'));
        } else {
          final n = rng.nextInt(3) == 0 ? 1 + rng.nextInt(4) : 1;
          final pitches = <Pitch>{};
          var guard = 0;
          while (pitches.length < n && guard++ < 20) {
            pitches.add(pitch(rng));
          }
          els.add(NoteElement(
              pitches: pitches.toList(), duration: pick.$1, id: 'e${id++}'));
        }
      }
      measures.add(Measure(els));
    }
    return Score(clef: Clef.treble, timeSignature: ts, measures: measures);
  }

  // Sustain grid: slot (sixteenths from the start) -> sounding MIDI numbers.
  // Trailing empty slots are trimmed so a padded final measure doesn't matter.
  List<Set<int>> gridOf(Score s) {
    final grid = <Set<int>>[];
    var cursor = 0;
    for (final m in s.measures) {
      for (final e in m.elements) {
        final (num, den) = e.duration.fraction;
        final units = num * 16 ~/ den;
        if (e is NoteElement) {
          for (var k = 0; k < units; k++) {
            while (grid.length <= cursor + k) {
              grid.add(<int>{});
            }
            grid[cursor + k].addAll(e.pitches.map((p) => p.midiNumber));
          }
        }
        cursor += units;
      }
    }
    while (grid.isNotEmpty && grid.last.isEmpty) {
      grid.removeLast();
    }
    return grid;
  }

  test('the sustain grid survives the MIDI round-trip over 300 scores', () {
    for (var seed = 1; seed <= 300; seed++) {
      final source = generate(seed);
      final back = scoreFromMidi(scoreToMidi(source));
      expect(gridOf(back), gridOf(source),
          reason: 'sustain grid changed for seed $seed');
    }
  });
}

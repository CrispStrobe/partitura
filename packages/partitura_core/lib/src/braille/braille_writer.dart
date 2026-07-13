/// Braille music export (Phase 7.5): render a [Score] as Unicode braille-music
/// notation — an accessibility differentiator few notation libraries offer.
///
/// This first increment covers the melodic note/rest stream of a single-staff
/// [Score]: note signs (name + value), rests, accidentals, octave marks (by the
/// standard interval rule) and measure separation. Chords, in-accord voices,
/// signatures, dynamics, slurs and formatting are follow-ups (see PLAN 7.5).
library;

import '../model/element.dart';
import '../model/score.dart';
import '../theory/duration.dart';
import '../theory/key_signature.dart';
import '../theory/pitch.dart';

/// Renders [score] as a string of Unicode braille-music cells (U+2800…), one
/// run of notes/rests per measure with measures separated by a braille space.
///
/// Only the first staff/voice is exported; a chord is rendered as its first
/// (written) note. Pitches outside braille octaves 1–7 are clamped.
String scoreToBraille(Score score) {
  final buffer = StringBuffer();
  Pitch? previous; // last note, for the octave-mark interval rule
  for (var m = 0; m < score.measures.length; m++) {
    if (m > 0) buffer.write(' '); // measure separator (blank cell)
    final measure = score.measures[m];
    for (final element in measure.elements) {
      switch (element) {
        case NoteElement():
          final pitch = element.pitches.first;
          final accidental = _accidentalFor(pitch, score.keySignature);
          if (accidental != null) buffer.write(accidental);
          if (_needsOctaveMark(previous, pitch)) {
            buffer.write(_octaveMark(pitch.octave));
          }
          buffer.write(_noteCell(pitch.step, element.duration.base));
          buffer.write(_augmentationDots(element.duration.dots));
          previous = pitch;
        case RestElement():
          buffer.write(_restCell(element.duration.base));
          buffer.write(_augmentationDots(element.duration.dots));
      }
    }
  }
  return buffer.toString();
}

/// A braille cell from its raised dot numbers (1–6). `_cell([1,4,5])` → ⠙.
String _cell(List<int> dots) {
  var bits = 0;
  for (final d in dots) {
    bits |= 1 << (d - 1);
  }
  return String.fromCharCode(0x2800 + bits);
}

/// The base note-name dots (a subset of {1,2,4,5}) — the eighth-note signs,
/// which share the dot patterns of the literary letters d–j.
const _noteNameDots = <Step, List<int>>{
  Step.c: [1, 4, 5], // d
  Step.d: [1, 5], // e
  Step.e: [1, 2, 4], // f
  Step.f: [1, 2, 4, 5], // g
  Step.g: [1, 2, 5], // h
  Step.a: [2, 4], // i
  Step.b: [2, 4, 5], // j
};

/// The value dots added to the note-name pattern: eighth adds nothing, quarter
/// adds dot 3, half adds dot 6, whole adds dots 3 and 6. (16th/32nd/64th/128th
/// reuse the same four cells — disambiguated by context, a follow-up.)
List<int> _valueDots(DurationBase base) => switch (base) {
      DurationBase.whole || DurationBase.breve || DurationBase.sixteenth => [
          3,
          6
        ],
      DurationBase.half || DurationBase.thirtySecond => [6],
      DurationBase.quarter || DurationBase.sixtyFourth => [3],
      DurationBase.eighth => [],
    };

String _noteCell(Step step, DurationBase base) =>
    _cell([..._noteNameDots[step]!, ..._valueDots(base)]);

/// The rest sign for a value category: whole ⠍, half ⠥, quarter ⠧, eighth ⠭.
String _restCell(DurationBase base) => switch (base) {
      DurationBase.whole || DurationBase.breve || DurationBase.sixteenth =>
        _cell([1, 3, 4]),
      DurationBase.half || DurationBase.thirtySecond => _cell([1, 3, 6]),
      DurationBase.quarter || DurationBase.sixtyFourth => _cell([1, 2, 3, 6]),
      DurationBase.eighth => _cell([1, 3, 4, 6]),
    };

/// One augmentation-dot cell (dot 3) per notated dot.
String _augmentationDots(int dots) => _cell([3]) * dots;

/// The accidental cell to print before [pitch], or null when the key signature
/// already implies its alteration. Sharp ⠩, flat ⠣, natural ⠡.
String? _accidentalFor(Pitch pitch, KeySignature key) {
  if (pitch.alter == key.alterFor(pitch.step)) return null;
  return switch (pitch.alter) {
    2 => _cell([1, 4, 6]) * 2, // double sharp = two sharp signs
    1 => _cell([1, 4, 6]), // sharp
    0 => _cell([1, 6]), // natural
    -1 => _cell([1, 2, 6]), // flat
    -2 => _cell([1, 2, 6]) * 2, // double flat
    _ => null,
  };
}

/// The octave sign for a (scientific) [octave], which braille numbers the same
/// way (octave 4 holds middle C). Octaves outside 1–7 clamp to the ends.
String _octaveMark(int octave) {
  const marks = <List<int>>[
    [4], // 1
    [4, 5], // 2
    [4, 5, 6], // 3
    [5], // 4
    [4, 6], // 5
    [5, 6], // 6
    [6], // 7
  ];
  final index = (octave - 1).clamp(0, marks.length - 1);
  return _cell(marks[index]);
}

/// Whether [pitch] needs an octave mark given the [previous] note, by the
/// standard rule: always on the first note; never for a 2nd/3rd; for a 4th/5th
/// only when the octave changes; always for a 6th or larger.
bool _needsOctaveMark(Pitch? previous, Pitch pitch) {
  if (previous == null) return true;
  final distance = (_diatonic(pitch) - _diatonic(previous)).abs();
  if (distance <= 2) return false; // unison, 2nd, 3rd
  if (distance <= 4) return previous.octave != pitch.octave; // 4th, 5th
  return true; // 6th or more
}

/// A note's absolute diatonic position (octave × 7 + letter index), for
/// measuring letter-name intervals.
int _diatonic(Pitch pitch) => pitch.octave * 7 + pitch.step.index;

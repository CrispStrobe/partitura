/// LilyPond "simple notes" → [Score].
///
/// The Flova / omr_transformer optical-music-recognition engine (handwritten /
/// whiteboard staff images) emits a **monophonic** melody as a space-separated
/// LilyPond note string, e.g. `c'2 a''8 c''8 r4 c'1 e'8`:
///
///   * a note is `<step><accidental?><octave-marks?><duration?>` — step `a`–`g`,
///     accidental `is`(♯)/`isis`(𝄪)/`es`(♭)/`eses`(𝄫), octave `'` (up) / `,`
///     (down) from the `c`=C3 default, and a duration `1`/`2`/`4`/… with dots;
///   * a rest is `r<duration?>`;
///   * a bare note keeps the previous duration (LilyPond's rule).
///
/// Flova emits no clef, meter or barlines, so the result is a single unmetered
/// treble-clef [Score] (one measure, `timeSignature: null`). Pure Dart — the
/// inverse of `lilypond_writer`'s pitch/duration encoding.
library;

import '../model/element.dart';
import '../model/measure.dart';
import '../model/score.dart';
import '../theory/clef.dart';
import '../theory/duration.dart';
import '../theory/pitch.dart';

const _durBases = {
  '1': DurationBase.whole,
  '2': DurationBase.half,
  '4': DurationBase.quarter,
  '8': DurationBase.eighth,
  '16': DurationBase.sixteenth,
  '32': DurationBase.thirtySecond,
  '64': DurationBase.sixtyFourth,
};

const _accidentals = {'isis': 2, 'is': 1, 'eses': -2, 'es': -1, '': 0};

final _noteRe = RegExp(r"^([a-g])(isis|eses|is|es)?([',]*)(\d+)?(\.*)$");
final _restRe = RegExp(r'^r(\d+)?(\.*)$');

/// Parses a LilyPond simple-notes string (Flova OMR output) into a single-staff
/// [Score]. Throws [FormatException] if no notes/rests are found.
Score scoreFromLilyNotes(String notes) {
  final elements = <MusicElement>[];
  var duration = NoteDuration.quarter; // carried between bare-duration notes
  var id = 0;

  for (final token in notes.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    final rest = _restRe.firstMatch(token);
    if (rest != null) {
      duration = _durationOf(rest[1], rest[2]!, duration);
      elements.add(RestElement(duration, id: 'e${id++}'));
      continue;
    }
    final note = _noteRe.firstMatch(token);
    if (note == null) continue; // skip anything we don't recognise
    duration = _durationOf(note[4], note[5]!, duration);
    elements.add(NoteElement(
      pitches: [_pitchOf(note[1]!, note[2] ?? '', note[3]!)],
      duration: duration,
      id: 'e${id++}',
    ));
  }

  if (elements.isEmpty) {
    throw const FormatException('no LilyPond notes in the input');
  }
  return Score(
    clef: Clef.treble,
    timeSignature: null,
    measures: [Measure(elements)],
  );
}

/// The duration for a token: [recip] (`1`/`2`/`4`/…) with [dots], or [previous]
/// when the token carried none (LilyPond duration inheritance).
NoteDuration _durationOf(String? recip, String dots, NoteDuration previous) {
  if (recip == null) return previous;
  final base = _durBases[recip];
  if (base == null) return previous;
  return NoteDuration(base, dots: dots.length.clamp(0, 2));
}

/// A [Pitch] from a step letter, an `is`/`es` accidental and `'`/`,` octave
/// marks: no marks = octave 3 (`c` = C3), each `'` up one, each `,` down one.
Pitch _pitchOf(String letter, String accidental, String marks) {
  final step = Step.values.byName(letter);
  final ups = "'".allMatches(marks).length;
  final downs = ','.allMatches(marks).length;
  return Pitch(
    step,
    alter: _accidentals[accidental] ?? 0,
    octave: 3 + ups - downs,
  );
}

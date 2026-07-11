/// Playback-cursor API: a deterministic timeline of element onsets so
/// apps can drive `highlightedIds` in sync with their own audio.
///
/// partitura never produces sound (HANDOVER contract) — this module only
/// answers "which element ids sound when", in exact musical time.
library;

import '../model/element.dart';
import '../model/score.dart';
import '../theory/fraction.dart';

/// One entry of a [playbackTimeline]: an element and its exact time span.
class PlaybackNote {
  /// The element's id (`e0`, `e1`, …).
  final String elementId;

  /// Onset in whole-note units from the start of playback.
  final Fraction start;

  /// Sounding duration in whole-note units (tuplet-scaled where the
  /// measure defines a tuplet).
  final Fraction duration;

  /// Whether the element is a rest (apps usually skip highlighting).
  final bool isRest;

  /// Voice the element belongs to: 0 (voice 1) or 1 (voice 2).
  final int voice;

  /// Index of the measure in `Score.measures` this element came from
  /// (repeated passes reference the same original measure).
  final int measureIndex;

  /// Creates a timeline entry.
  const PlaybackNote({
    required this.elementId,
    required this.start,
    required this.duration,
    required this.isRest,
    required this.voice,
    required this.measureIndex,
  });

  /// Time when the element stops sounding.
  Fraction get end => start + duration;

  @override
  bool operator ==(Object other) =>
      other is PlaybackNote &&
      other.elementId == elementId &&
      other.start == start &&
      other.duration == duration &&
      other.isRest == isRest &&
      other.voice == voice &&
      other.measureIndex == measureIndex;

  @override
  int get hashCode =>
      Object.hash(elementId, start, duration, isRest, voice, measureIndex);

  @override
  String toString() =>
      'PlaybackNote($elementId @ $start + $duration, m$measureIndex'
      '${isRest ? ', rest' : ''}${voice == 1 ? ', v2' : ''})';
}

/// Converts a whole-note time to seconds at [quarterBpm] beats (quarter
/// notes) per minute — the usual tempo convention.
double secondsFor(Fraction wholeNotes, {required double quarterBpm}) =>
    wholeNotes.numerator / wholeNotes.denominator * 4 * 60 / quarterBpm;

/// Flattens [score] into a timeline of element onsets sorted by start
/// (ties broken by voice), in exact whole-note [Fraction] time.
///
/// With [expandRepeats] (default), repeat barlines play their segment
/// twice and voltas select their pass: a `volta: 1` measure plays only
/// on the first pass, `volta: 2` only on the second (deeper repeat
/// structures are out of scope). Ties stay separate entries — highlight
/// both noteheads while the sound sustains. Grace notes carry no time of
/// their own. An element id appears once per pass, so ids can repeat in
/// the returned list when repeats are expanded.
List<PlaybackNote> playbackTimeline(Score score, {bool expandRepeats = true}) {
  final order = <int>[];
  final measures = score.measures;
  if (expandRepeats) {
    var repeatStart = 0;
    var pass = 1;
    var i = 0;
    while (i < measures.length) {
      final measure = measures[i];
      if (measure.startRepeat && pass == 1) repeatStart = i;
      final volta = measure.volta;
      if (volta != null && volta != pass) {
        i++;
        continue;
      }
      order.add(i);
      if (measure.endRepeat) {
        if (pass == 1) {
          pass = 2;
          i = repeatStart;
          continue;
        }
        pass = 1;
        repeatStart = i + 1;
      }
      i++;
    }
  } else {
    for (var i = 0; i < measures.length; i++) {
      order.add(i);
    }
  }

  final result = <PlaybackNote>[];
  var measureStart = Fraction(0, 1);
  var meter = score.timeSignature;
  for (final index in order) {
    final measure = measures[index];
    meter = measure.timeChange ?? meter;

    var voice1End = measureStart;
    var clock = measureStart;
    for (var i = 0; i < measure.elements.length; i++) {
      final element = measure.elements[i];
      final duration = measure.effectiveDurationAt(i);
      if (element.id != null) {
        result.add(PlaybackNote(
          elementId: element.id!,
          start: clock,
          duration: duration,
          isRest: element is RestElement,
          voice: 0,
          measureIndex: index,
        ));
      }
      clock = clock + duration;
    }
    voice1End = clock;

    clock = measureStart;
    for (final element in measure.voice2) {
      final (numerator, denominator) = element.duration.fraction;
      final duration = Fraction(numerator, denominator);
      if (element.id != null) {
        result.add(PlaybackNote(
          elementId: element.id!,
          start: clock,
          duration: duration,
          isRest: element is RestElement,
          voice: 1,
          measureIndex: index,
        ));
      }
      clock = clock + duration;
    }
    final voice2End = clock;

    var measureEnd =
        voice1End.compareTo(voice2End) >= 0 ? voice1End : voice2End;
    if (measureEnd == measureStart && meter != null) {
      // Empty measure: advance by the current meter.
      measureEnd = measureStart + Fraction(meter.beats, meter.beatUnit);
    }
    measureStart = measureEnd;
  }

  result.sort((a, b) {
    final byStart = a.start.compareTo(b.start);
    if (byStart != 0) return byStart;
    return a.voice.compareTo(b.voice);
  });
  return result;
}

/// The element ids sounding at [time] (rests excluded) — a convenience
/// for driving `highlightedIds` from a position in seconds mapped back
/// to whole notes.
Set<String> soundingAt(List<PlaybackNote> timeline, Fraction time) => {
      for (final note in timeline)
        if (!note.isRest &&
            note.start.compareTo(time) <= 0 &&
            time.compareTo(note.end) < 0)
          note.elementId,
    };

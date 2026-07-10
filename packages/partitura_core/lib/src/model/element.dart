/// Score elements: notes, chords and rests.
library;

import '../internal/util.dart';
import '../theory/duration.dart';
import '../theory/pitch.dart';

/// Articulation marks attachable to a [NoteElement].
enum Articulation {
  /// Short, detached (dot).
  staccato,

  /// Held for full value (dash).
  tenuto,

  /// Emphasized (horizontal wedge).
  accent,

  /// Strongly emphasized (vertical wedge).
  marcato,

  /// Held beyond its value (fermata; always drawn above the element).
  fermata,
}

/// A single rhythmic event in a measure: a note/chord or a rest.
///
/// Elements are value types; treat their lists as immutable. The optional
/// [id] tags the element for the interaction layer (hit testing,
/// highlighting) — ids should be unique within a score.
sealed class MusicElement {
  /// Identifier for hit testing and highlighting; null = not addressable.
  final String? id;

  /// The element's rhythmic duration.
  final NoteDuration duration;

  /// Creates an element with [duration] and an optional interaction [id].
  const MusicElement({required this.duration, this.id});
}

/// A note (one pitch) or chord (several pitches) sharing one duration and,
/// when rendered, one stem.
class NoteElement extends MusicElement {
  /// The sounding pitches; length 1 = single note, more = chord.
  final List<Pitch> pitches;

  /// Accidental override: `true` forces an accidental (courtesy accidental),
  /// `false` hides it, `null` (default) shows one exactly when the pitch
  /// deviates from what the key signature and earlier accidentals in the
  /// measure imply.
  final bool? showAccidental;

  /// Ties this note/chord to the **next** note element (also across a
  /// barline). Only pitches present identically in both elements are
  /// tied; a tie into a rest or nothing draws no curve.
  final bool tieToNext;

  /// Articulation marks: drawn on the notehead side (opposite the stem),
  /// stacked outward in enum order; a fermata always goes above.
  final Set<Articulation> articulations;

  /// Creates a note or chord from [pitches] and a [duration].
  ///
  /// [pitches] must be non-empty. (Not asserted: list lengths cannot be
  /// checked in a const constructor.)
  const NoteElement({
    required this.pitches,
    required super.duration,
    this.showAccidental,
    this.tieToNext = false,
    this.articulations = const {},
    super.id,
  });

  /// Convenience for a single-pitch note.
  NoteElement.note(
    Pitch pitch,
    NoteDuration duration, {
    bool? showAccidental,
    bool tieToNext = false,
    Set<Articulation> articulations = const {},
    String? id,
  }) : this(
          pitches: [pitch],
          duration: duration,
          showAccidental: showAccidental,
          tieToNext: tieToNext,
          articulations: articulations,
          id: id,
        );

  @override
  bool operator ==(Object other) =>
      other is NoteElement &&
      other.duration == duration &&
      other.showAccidental == showAccidental &&
      other.tieToNext == tieToNext &&
      other.id == id &&
      listEquals(other.pitches, pitches) &&
      setEquals(other.articulations, articulations);

  @override
  int get hashCode => Object.hash(duration, showAccidental, tieToNext, id,
      Object.hashAll(pitches), Object.hashAllUnordered(articulations));

  @override
  String toString() =>
      'NoteElement(${pitches.join('+')}, $duration${tieToNext ? ', tied' : ''}'
      '${articulations.isEmpty ? '' : ', ${articulations.map((a) => a.name).join('+')}'}'
      '${id == null ? '' : ', id: $id'})';
}

/// A slur between two note elements, referenced by their ids.
///
/// The start element must come before the end element in reading order;
/// both ids must exist in the score (the layout engine throws an
/// [ArgumentError] otherwise). Use ties ([NoteElement.tieToNext]) for
/// same-pitch connections; slurs are phrasing marks over any pitches.
class Slur {
  /// Id of the note element the slur starts on.
  final String startId;

  /// Id of the note element the slur ends on.
  final String endId;

  /// Creates a slur from [startId] to [endId].
  const Slur(this.startId, this.endId);

  @override
  bool operator ==(Object other) =>
      other is Slur && other.startId == startId && other.endId == endId;

  @override
  int get hashCode => Object.hash(startId, endId);

  @override
  String toString() => 'Slur($startId -> $endId)';
}

/// A rest.
class RestElement extends MusicElement {
  /// Creates a rest of [duration].
  const RestElement(NoteDuration duration, {super.id})
      : super(duration: duration);

  @override
  bool operator ==(Object other) =>
      other is RestElement && other.duration == duration && other.id == id;

  @override
  int get hashCode => Object.hash(duration, id);

  @override
  String toString() => 'RestElement($duration${id == null ? '' : ', id: $id'})';
}

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

/// Arpeggio (rolled chord) direction, drawn as a vertical wavy line to the
/// left of the chord (v0.7.2). The arrow points the way the roll travels.
enum Arpeggio {
  /// Rolled low → high; arrowhead at the top.
  up,

  /// Rolled high → low; arrowhead at the bottom.
  down,
}

/// Ornaments drawn above a note (v0.6.2).
enum Ornament {
  /// Trill (tr).
  trill,

  /// Short trill / upper mordent (squiggle without a line).
  shortTrill,

  /// Mordent / lower mordent (squiggle with a vertical line).
  mordent,

  /// Turn (Doppelschlag).
  turn,
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

  /// Grace notes (acciaccatura group) played before this element, drawn
  /// as small slashed eighths to its left.
  final List<Pitch> graceNotes;

  /// Ornament drawn above the element (above a fermata when both exist).
  final Ornament? ornament;

  /// Fingering digits (0–9) stacked above the note, in list order from the
  /// notehead upward. Usually one per pitch of a chord, but the length is
  /// not tied to [pitches]; an empty list draws nothing.
  final List<int> fingerings;

  /// Arpeggio (rolled chord) sign drawn as a vertical wavy line to the left
  /// of the chord, or null. Model-only (no DSL shorthand).
  final Arpeggio? arpeggio;

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
    this.graceNotes = const [],
    this.ornament,
    this.fingerings = const [],
    this.arpeggio,
    super.id,
  });

  /// Convenience for a single-pitch note.
  NoteElement.note(
    Pitch pitch,
    NoteDuration duration, {
    bool? showAccidental,
    bool tieToNext = false,
    Set<Articulation> articulations = const {},
    List<Pitch> graceNotes = const [],
    Ornament? ornament,
    List<int> fingerings = const [],
    Arpeggio? arpeggio,
    String? id,
  }) : this(
          pitches: [pitch],
          duration: duration,
          showAccidental: showAccidental,
          tieToNext: tieToNext,
          articulations: articulations,
          graceNotes: graceNotes,
          ornament: ornament,
          fingerings: fingerings,
          arpeggio: arpeggio,
          id: id,
        );

  @override
  bool operator ==(Object other) =>
      other is NoteElement &&
      other.duration == duration &&
      other.showAccidental == showAccidental &&
      other.tieToNext == tieToNext &&
      other.ornament == ornament &&
      other.id == id &&
      other.arpeggio == arpeggio &&
      listEquals(other.pitches, pitches) &&
      setEquals(other.articulations, articulations) &&
      listEquals(other.graceNotes, graceNotes) &&
      listEquals(other.fingerings, fingerings);

  @override
  int get hashCode => Object.hash(
      duration,
      showAccidental,
      tieToNext,
      ornament,
      arpeggio,
      id,
      Object.hashAll(pitches),
      Object.hashAllUnordered(articulations),
      Object.hashAll(graceNotes),
      Object.hashAll(fingerings));

  @override
  String toString() =>
      'NoteElement(${pitches.join('+')}, $duration${tieToNext ? ', tied' : ''}'
      '${articulations.isEmpty ? '' : ', ${articulations.map((a) => a.name).join('+')}'}'
      '${graceNotes.isEmpty ? '' : ', grace: ${graceNotes.join('+')}'}'
      '${fingerings.isEmpty ? '' : ', fingers: ${fingerings.join(',')}'}'
      '${arpeggio == null ? '' : ', ${arpeggio!.name} arpeggio'}'
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

/// A glissando/slide: a straight line drawn from one note to a later one,
/// referenced by their ids (like [Slur]). The start must precede the end in
/// reading order and both ids must exist, or layout throws an
/// [ArgumentError]. Model-only (no DSL shorthand).
class Glissando {
  /// Id of the note the line starts on.
  final String startId;

  /// Id of the note the line ends on.
  final String endId;

  /// Creates a glissando from [startId] to [endId].
  const Glissando(this.startId, this.endId);

  @override
  bool operator ==(Object other) =>
      other is Glissando && other.startId == startId && other.endId == endId;

  @override
  int get hashCode => Object.hash(startId, endId);

  @override
  String toString() => 'Glissando($startId -> $endId)';
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

/// Dynamic levels supported in v0.3.
enum DynamicLevel {
  /// Pianissimo.
  pp,

  /// Piano.
  p,

  /// Mezzo-piano.
  mp,

  /// Mezzo-forte.
  mf,

  /// Forte.
  f,

  /// Fortissimo.
  ff,
}

/// A dynamic marking attached to a note element (drawn centered below it,
/// under the staff).
class DynamicMarking {
  /// Id of the note element the marking belongs to.
  final String elementId;

  /// The dynamic level.
  final DynamicLevel level;

  /// Creates a dynamic marking.
  const DynamicMarking(this.elementId, this.level);

  @override
  bool operator ==(Object other) =>
      other is DynamicMarking &&
      other.elementId == elementId &&
      other.level == level;

  @override
  int get hashCode => Object.hash(elementId, level);

  @override
  String toString() => 'DynamicMarking($elementId: ${level.name})';
}

/// Direction of a [Hairpin].
enum HairpinType {
  /// Opening wedge (getting louder).
  crescendo,

  /// Closing wedge (getting softer).
  diminuendo,
}

/// A crescendo/diminuendo wedge between two note elements, drawn below
/// the staff on the dynamics line.
class Hairpin {
  /// Id of the note element the wedge starts on.
  final String startId;

  /// Id of the note element the wedge ends on.
  final String endId;

  /// Whether the wedge opens (crescendo) or closes (diminuendo).
  final HairpinType type;

  /// Creates a hairpin.
  const Hairpin(this.startId, this.endId, this.type);

  @override
  bool operator ==(Object other) =>
      other is Hairpin &&
      other.startId == startId &&
      other.endId == endId &&
      other.type == type;

  @override
  int get hashCode => Object.hash(startId, endId, type);

  @override
  String toString() => 'Hairpin($startId -> $endId, ${type.name})';
}

/// One lyric syllable attached to a note element, drawn below the staff.
class Lyric {
  /// Id of the note element the syllable sits under.
  final String elementId;

  /// The syllable text (without hyphen/extender markers).
  final String text;

  /// Whether a hyphen connects this syllable to the next one (the word
  /// continues on a later note).
  final bool hyphenToNext;

  /// Whether an extender (melisma) line follows this word-final syllable
  /// while subsequent notes carry no lyric of their own.
  final bool extender;

  /// Creates a lyric syllable.
  const Lyric(
    this.elementId,
    this.text, {
    this.hyphenToNext = false,
    this.extender = false,
  });

  @override
  bool operator ==(Object other) =>
      other is Lyric &&
      other.elementId == elementId &&
      other.text == text &&
      other.hyphenToNext == hyphenToNext &&
      other.extender == extender;

  @override
  int get hashCode => Object.hash(elementId, text, hyphenToNext, extender);

  @override
  String toString() => 'Lyric($elementId: "$text"'
      '${hyphenToNext ? ' -' : ''}${extender ? ' _' : ''})';
}

/// A text annotation anchored above the staff at a note element: chord
/// symbols, rehearsal marks, tempo text.
class Annotation {
  /// Id of the note element the text sits above.
  final String elementId;

  /// The text to display (e.g. `C`, `G7/B`, `Andante`).
  final String text;

  /// Creates an annotation.
  const Annotation(this.elementId, this.text);

  @override
  bool operator ==(Object other) =>
      other is Annotation && other.elementId == elementId && other.text == text;

  @override
  int get hashCode => Object.hash(elementId, text);

  @override
  String toString() => 'Annotation($elementId: "$text")';
}

/// An ottava bracket: the spanned elements are written an octave off
/// their sounding pitch, with a dashed bracket marking the range.
class Ottava {
  /// Id of the first spanned note element.
  final String startId;

  /// Id of the last spanned note element (inclusive).
  final String endId;

  /// False = 8va (bracket above; written an octave lower than sounding),
  /// true = 8vb (bracket below; written an octave higher).
  final bool down;

  /// Creates an ottava span.
  const Ottava(this.startId, this.endId, {this.down = false});

  @override
  bool operator ==(Object other) =>
      other is Ottava &&
      other.startId == startId &&
      other.endId == endId &&
      other.down == down;

  @override
  int get hashCode => Object.hash(startId, endId, down);

  @override
  String toString() => 'Ottava($startId -> $endId, ${down ? '8vb' : '8va'})';
}

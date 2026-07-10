/// Music theory model, score document model and deterministic layout engine
/// for the partitura music notation libraries. Pure Dart — no Flutter
/// dependency.
///
/// The theory layer provides the pedagogical vocabulary ([Pitch],
/// [NoteDuration], [KeySignature], [TimeSignature], [Interval], [Scale],
/// [Triad], [Key] with [HarmonicFunction]); the model layer the score
/// document tree ([Score], [Measure], [MusicElement]). The layout engine
/// (in progress, HANDOVER.md §4.2) turns a [Score] into a flat display list
/// in staff-space coordinates.
library;

export 'src/model/element.dart';
export 'src/model/measure.dart';
export 'src/model/score.dart';
export 'src/theory/clef.dart';
export 'src/theory/duration.dart';
export 'src/theory/fraction.dart';
export 'src/theory/interval.dart';
export 'src/theory/key.dart';
export 'src/theory/key_signature.dart';
export 'src/theory/pitch.dart';
export 'src/theory/scale.dart';
export 'src/theory/time_signature.dart';
export 'src/theory/triad.dart';

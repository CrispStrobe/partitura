/// Scales (Tonleitern).
library;

import 'pitch.dart';

/// The scale types supported in v0.1.
enum ScaleType {
  /// Major (Dur): W W H W W W H.
  major,

  /// Natural minor (reines Moll): W H W W H W W.
  naturalMinor,

  /// Harmonic minor (harmonisches Moll): natural minor with a raised 7th.
  harmonicMinor,

  /// Melodic minor, ascending form (melodisches Moll): natural minor with
  /// raised 6th and 7th.
  melodicMinor,
}

/// A one-octave scale built on a [tonic].
class Scale {
  /// The scale's tonic (its octave anchors the returned pitches).
  final Pitch tonic;

  /// The scale type.
  final ScaleType type;

  /// Creates a scale of [type] on [tonic].
  const Scale(this.tonic, this.type);

  /// Semitone offsets 0–11 of the seven scale degrees of [type] from the tonic
  /// (the octave repeat is implicit). The one source of truth for scale
  /// content: [pitches] and `matchingScales` both derive from it. Exhaustive
  /// over [ScaleType] — a new scale type is a **compile error** here until its
  /// intervals are defined, so the two callers can never silently disagree.
  static List<int> semitoneOffsetsFor(ScaleType type) => switch (type) {
        ScaleType.major => const [0, 2, 4, 5, 7, 9, 11],
        ScaleType.naturalMinor => const [0, 2, 3, 5, 7, 8, 10],
        ScaleType.harmonicMinor => const [0, 2, 3, 5, 7, 8, 11],
        ScaleType.melodicMinor => const [0, 2, 3, 5, 7, 9, 11],
      };

  /// One octave ascending, eight pitches from the tonic to the tonic an
  /// octave up, spelled diatonically (each letter name used exactly once
  /// before the octave).
  ///
  /// Throws an [ArgumentError] if a degree cannot be spelled within double
  /// sharps/flats (only possible from extreme tonics like G♯ in
  /// harmonic minor contexts beyond the supported alteration range).
  List<Pitch> get pitches {
    final offsets = [...semitoneOffsetsFor(type), 12];
    final tonicSemitones = tonic.octave * 12 + tonic.step.semitonesFromC;
    return List.generate(8, (degree) {
      final d = tonic.diatonicIndex + degree;
      final step = Step.values[d % 7];
      final octave = (d - d % 7) ~/ 7;
      final natural = octave * 12 + step.semitonesFromC;
      final alter = tonicSemitones + tonic.alter + offsets[degree] - natural;
      if (alter < -2 || alter > 2) {
        throw ArgumentError(
          'Degree ${degree + 1} of $this needs an alteration of $alter '
          'semitones, beyond double sharp/flat',
        );
      }
      return Pitch(step, alter: alter, octave: octave);
    });
  }

  @override
  bool operator ==(Object other) =>
      other is Scale && other.tonic == tonic && other.type == type;

  @override
  int get hashCode => Object.hash(tonic, type);

  @override
  String toString() => 'Scale($tonic ${type.name})';
}

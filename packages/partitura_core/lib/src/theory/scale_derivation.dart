/// Scale derivation: given a pitch-class set (e.g. the notes of a melody or
/// passage), rank the scales whose collections best contain it — the inverse
/// of "spell a scale," useful for guessing a passage's mode or the scales a
/// soloist could play over it.
library;

import 'pitch.dart';
import 'scale.dart';
import 'set_theory.dart';

// Conventional tonic spellings per pitch class (a plain, readable set); the
// derivation is by pitch class, so the tonic's spelling is only cosmetic.
const List<(Step, int)> _tonicSpelling = [
  (Step.c, 0), (Step.d, -1), (Step.d, 0), (Step.e, -1), (Step.e, 0), //
  (Step.f, 0), (Step.f, 1), (Step.g, 0), (Step.a, -1), (Step.a, 0), //
  (Step.b, -1), (Step.b, 0),
];

/// How well a [scale] fits a queried pitch-class set: how many of the query's
/// pitch classes it contains ([matched]) and how many it lacks ([missing]).
class ScaleMatch {
  /// The candidate scale.
  final Scale scale;

  /// Query pitch classes that are degrees of [scale].
  final int matched;

  /// Query pitch classes that are **not** in [scale] (0 = a perfect fit).
  final int missing;

  /// Creates a scale match.
  const ScaleMatch(this.scale, {required this.matched, required this.missing});

  /// Whether the whole query lies inside the scale.
  bool get isExact => missing == 0;

  @override
  String toString() => 'ScaleMatch($scale, matched $matched, missing $missing)';
}

/// Ranks every supported scale (each [ScaleType] on each of the twelve tonics)
/// by how well it contains [query], best fit first: fewest [ScaleMatch.missing]
/// pitch classes, then most [ScaleMatch.matched], then by tonic and type for a
/// stable order. With [exactOnly], only scales that contain the whole query are
/// returned (possibly none).
///
/// Throws [ArgumentError] if [query] is empty.
List<ScaleMatch> matchingScales(PitchClassSet query, {bool exactOnly = false}) {
  if (query.isEmpty) {
    throw ArgumentError.value(query, 'query', 'must not be empty');
  }
  final wanted = query.pitchClasses.toSet();

  final matches = <ScaleMatch>[];
  for (var tonicPc = 0; tonicPc < 12; tonicPc++) {
    final (step, alter) = _tonicSpelling[tonicPc];
    final tonic = Pitch(step, alter: alter);
    for (final type in ScaleType.values) {
      final pcs = Scale(tonic, type).pitchClasses;
      final matched = wanted.where(pcs.contains).length;
      final missing = wanted.length - matched;
      if (exactOnly && missing != 0) continue;
      matches.add(
          ScaleMatch(Scale(tonic, type), matched: matched, missing: missing));
    }
  }

  matches.sort((a, b) {
    if (a.missing != b.missing) return a.missing - b.missing;
    if (a.matched != b.matched) return b.matched - a.matched;
    final tonicCmp =
        (a.scale.tonic.midiNumber % 12) - (b.scale.tonic.midiNumber % 12);
    if (tonicCmp != 0) return tonicCmp;
    return a.scale.type.index - b.scale.type.index;
  });
  return matches;
}

/// The scale that best fits [pitches] (the top of [matchingScales]); octave and
/// spelling are ignored. Throws [ArgumentError] on an empty iterable.
Scale deriveScale(Iterable<Pitch> pitches) {
  final set = PitchClassSet.of(pitches);
  if (set.isEmpty) {
    throw ArgumentError.value(pitches, 'pitches', 'must not be empty');
  }
  return matchingScales(set).first.scale;
}

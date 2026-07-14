/// Metrical accent hierarchy (Phase 4.7).
///
/// Every metric position in a measure carries an *accent strength* set by where
/// it sits in the meter's hierarchy of subdivisions. The measure downbeat is
/// the strongest; each level down the hierarchy halves the strength. This is
/// the exact-duration basis for accent-aware rendering, MIDI velocity shaping,
/// analysis, and automatic beaming.
library;

import 'fraction.dart';
import 'time_signature.dart';

/// The metric hierarchy is not resolved finer than a 64th note.
final Fraction _minUnit = Fraction(1, 64);

/// Metrical-accent queries on a [TimeSignature].
extension MetricHierarchy on TimeSignature {
  /// The metrical-accent strength of [position] (measured from the measure's
  /// downbeat, as a fraction of a whole note), normalized so the downbeat is
  /// `1.0`. Each level down the metric hierarchy halves the strength.
  ///
  /// In 4/4 the downbeat is `1.0`, beat 3 is `0.5`, beats 2 and 4 are `0.25`,
  /// the eighth-note offbeats `0.125`, and so on. In 3/4 beats 2 and 3 are
  /// `0.5`; in 6/8 the second dotted beat (at 3/8) is `0.5` and the eighths
  /// `0.25`; additive meters accent each group's start. A [position] that is
  /// not a point of the metric grid (e.g. a triplet subdivision, or one finer
  /// than a 64th) returns `0.0`.
  ///
  /// [position] is taken within one measure; pass a measure-relative offset in
  /// `[0, measureCapacity)`.
  double beatStrength(Fraction position) {
    final depth = metricGrid()[position];
    return depth == null ? 0.0 : 1.0 / (1 << depth);
  }

  /// The metric grid of this meter: every accented position in one measure
  /// mapped to its hierarchy depth (0 = downbeat, 1 = the meter's beat groups,
  /// deeper = finer subdivisions). Resolved down to the 64th-note level.
  Map<Fraction, int> metricGrid() {
    final grid = <Fraction, int>{};
    void mark(Fraction pos, int depth) {
      final existing = grid[pos];
      if (existing == null || depth < existing) grid[pos] = depth;
    }

    // Subdivide a segment starting at [start] spanning [count] units of length
    // [unit], recording each boundary's depth. A duple/quadruple count splits
    // in two, a triple in three (so 6/8 reads as 2 groups of 3), an odd prime
    // peels off a leading pair; a single unit bisects for the sub-beat grid.
    void divide(Fraction start, int count, Fraction unit, int depth) {
      mark(start, depth);
      if (count == 1) {
        if (!(unit > _minUnit)) return;
        final half = unit * Fraction(1, 2);
        divide(start, 1, half, depth + 1);
        divide(start + half, 1, half, depth + 1);
        return;
      }
      final int k;
      if (count % 2 == 0) {
        k = 2;
      } else if (count % 3 == 0) {
        k = 3;
      } else {
        divide(start, 2, unit, depth + 1);
        divide(start + unit * Fraction(2, 1), count - 2, unit, depth + 1);
        return;
      }
      final sub = count ~/ k;
      for (var i = 0; i < k; i++) {
        divide(start + unit * Fraction(i * sub, 1), sub, unit, depth + 1);
      }
    }

    final unit = Fraction(1, beatUnit);
    final groups = components;
    if (groups != null) {
      var start = Fraction.zero;
      for (final g in groups) {
        divide(start, g, unit, 1);
        start += unit * Fraction(g, 1);
      }
      mark(Fraction.zero, 0); // the downbeat outranks its group start
    } else {
      divide(Fraction.zero, beats, unit, 0);
    }
    return grid;
  }
}

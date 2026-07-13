/// Warped-time cursor support (Phase 3.5): convert between musical time
/// (whole-note [Fraction]s from the start of playback) and wall-clock seconds
/// under a **variable tempo** ([TempoMap]), or under app-supplied **sync
/// points** that follow a live / slowed-down performance ([SyncPoints]).
///
/// partitura still makes no sound — these only answer "where is the cursor at
/// wall-clock time t" (and its inverse) so the app can drive `highlightedIds`.
library;

import '../theory/fraction.dart';

/// A tempo taking effect at a musical time, in a [TempoMap].
class TempoSpan {
  /// Musical time (whole notes from the start) this tempo begins at.
  final Fraction at;

  /// Quarter notes per minute from [at] until the next span (or forever).
  final double quarterBpm;

  /// Creates a tempo span.
  const TempoSpan(this.at, this.quarterBpm)
      : assert(quarterBpm > 0, 'quarterBpm must be positive');
}

/// A piecewise-constant tempo map: converts musical time ↔ wall-clock seconds
/// under one or more tempo spans — extending the fixed-clock `secondsFor` to a
/// score with tempo changes. The last span extends to the end of playback.
class TempoMap {
  /// The tempo spans, sorted by [TempoSpan.at]; the first starts at time 0.
  final List<TempoSpan> spans;

  /// Builds a tempo map from [spans] (need not be pre-sorted). Requires a span
  /// at time 0. Use [TempoMap.constant] for a single tempo.
  TempoMap(Iterable<TempoSpan> spans)
      : spans = List.unmodifiable(
          <TempoSpan>[...spans]..sort((a, b) => a.at.compareTo(b.at)),
        ) {
    if (this.spans.isEmpty || this.spans.first.at != Fraction(0, 1)) {
      throw ArgumentError('TempoMap needs a span starting at time 0');
    }
  }

  /// A constant tempo of [quarterBpm] throughout — the `secondsFor` case.
  factory TempoMap.constant(double quarterBpm) =>
      TempoMap([TempoSpan(Fraction(0, 1), quarterBpm)]);

  static double _wholeD(Fraction f) => f.numerator / f.denominator;
  static double _secondsPerWhole(double quarterBpm) => 4 * 60 / quarterBpm;

  /// Wall-clock seconds elapsed at musical [time].
  double secondsAt(Fraction time) {
    var seconds = 0.0;
    for (var i = 0; i < spans.length; i++) {
      if (time <= spans[i].at) break;
      final hasNext = i + 1 < spans.length;
      final end = hasNext && spans[i + 1].at < time ? spans[i + 1].at : time;
      seconds +=
          _wholeD(end - spans[i].at) * _secondsPerWhole(spans[i].quarterBpm);
      if (end == time) break;
    }
    return seconds;
  }

  /// The musical time (whole notes, as a double — cursor positions are
  /// continuous) reached at [seconds] of wall-clock playback.
  double timeAt(double seconds) {
    var acc = 0.0; // seconds to the start of the current span
    var wholeAt = 0.0; // whole notes at the start of the current span
    for (var i = 0; i < spans.length; i++) {
      final spw = _secondsPerWhole(spans[i].quarterBpm);
      if (i + 1 < spans.length) {
        final spanWhole = _wholeD(spans[i + 1].at - spans[i].at);
        final spanSeconds = spanWhole * spw;
        if (seconds < acc + spanSeconds) {
          return wholeAt + (seconds - acc) / spw;
        }
        acc += spanSeconds;
        wholeAt += spanWhole;
      } else {
        return wholeAt + (seconds - acc) / spw; // last span runs forever
      }
    }
    return wholeAt;
  }
}

/// App-supplied anchors mapping musical time to observed wall-clock seconds —
/// "sync points" for following a live or slowed-down performance. Seconds are
/// linearly interpolated between adjacent anchors and extrapolated past the
/// ends using the nearest pair. Needs ≥ 2 anchors at distinct times.
class SyncPoints {
  /// The anchors, sorted by musical time.
  final List<({Fraction time, double seconds})> anchors;

  /// Builds sync points from [anchors] (need not be pre-sorted).
  SyncPoints(Iterable<({Fraction time, double seconds})> anchors)
      : anchors = List.unmodifiable(
          <({Fraction time, double seconds})>[...anchors]
            ..sort((a, b) => a.time.compareTo(b.time)),
        ) {
    if (this.anchors.length < 2) {
      throw ArgumentError('SyncPoints needs at least 2 anchors');
    }
    if (this.anchors.first.time == this.anchors.last.time) {
      throw ArgumentError('SyncPoints anchors must span distinct times');
    }
  }

  static double _wholeD(Fraction f) => f.numerator / f.denominator;

  // The index of the lower anchor of the pair bracketing musical time [t].
  int _pairForTime(double t) {
    var i = 0;
    while (i < anchors.length - 2 && _wholeD(anchors[i + 1].time) <= t) {
      i++;
    }
    return i;
  }

  // The index of the lower anchor of the pair bracketing [seconds].
  int _pairForSeconds(double seconds) {
    var i = 0;
    while (i < anchors.length - 2 && anchors[i + 1].seconds <= seconds) {
      i++;
    }
    return i;
  }

  /// Interpolated wall-clock seconds at musical [time].
  double secondsAt(Fraction time) {
    final t = _wholeD(time);
    final a = anchors[_pairForTime(t)];
    final b = anchors[_pairForTime(t) + 1];
    final ta = _wholeD(a.time), tb = _wholeD(b.time);
    return a.seconds + (t - ta) / (tb - ta) * (b.seconds - a.seconds);
  }

  /// Interpolated musical time (whole notes, as a double) at [seconds].
  double timeAt(double seconds) {
    final i = _pairForSeconds(seconds);
    final a = anchors[i], b = anchors[i + 1];
    final ta = _wholeD(a.time), tb = _wholeD(b.time);
    return ta + (seconds - a.seconds) / (b.seconds - a.seconds) * (tb - ta);
  }
}

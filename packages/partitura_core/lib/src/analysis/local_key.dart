/// Local (windowed) key analysis: track how a score's key shifts over time by
/// running Krumhansl–Schmuckler key finding over a sliding window of measures,
/// then merging equal-key windows into modulation regions.
///
/// This sits above the theory layer because it reads the [Score] model
/// (durations weight the pitch-class histogram — a long tonic counts for more
/// than a passing tone).
library;

import '../model/element.dart';
import '../model/measure.dart';
import '../model/score.dart';
import '../theory/key.dart';
import '../theory/key_finding.dart';

/// A duration-weighted pitch-class histogram (length 12, C…B) of [elements]:
/// each note contributes its duration (as a fraction of a whole note) to every
/// pitch class it sounds; rests contribute nothing.
List<num> pitchClassHistogram(Iterable<MusicElement> elements) {
  final weights = List<num>.filled(12, 0);
  for (final element in elements) {
    if (element is NoteElement) {
      final weight = element.duration.toFraction().toDouble();
      for (final pitch in element.pitches) {
        weights[pitch.midiNumber % 12] += weight;
      }
    }
  }
  return weights;
}

List<num> _measureHistogram(Measure measure) =>
    pitchClassHistogram([...measure.elements, ...measure.voice2]);

List<num> _sum(Iterable<List<num>> histograms) {
  final total = List<num>.filled(12, 0);
  for (final h in histograms) {
    for (var i = 0; i < 12; i++) {
      total[i] += h[i];
    }
  }
  return total;
}

/// The estimated key of a contiguous run of measures.
class LocalKey {
  /// First measure of the span (0-based).
  final int firstMeasure;

  /// Last measure of the span (inclusive).
  final int lastMeasure;

  /// The Krumhansl–Schmuckler estimate for the span.
  final KeyEstimate estimate;

  /// Creates a local-key span.
  const LocalKey({
    required this.firstMeasure,
    required this.lastMeasure,
    required this.estimate,
  });

  /// The estimated key.
  Key get key => estimate.key;

  @override
  String toString() => 'LocalKey(measures $firstMeasure..$lastMeasure, $key)';
}

/// The estimated key of every window of [windowMeasures] consecutive measures,
/// stepping by [step] measures. Each entry covers `[start … start+window-1]`.
/// Measures whose window is entirely silent are skipped.
///
/// Throws [ArgumentError] if [windowMeasures] or [step] is not positive.
List<LocalKey> localKeys(
  Score score, {
  int windowMeasures = 4,
  int step = 1,
}) {
  if (windowMeasures < 1) {
    throw ArgumentError.value(windowMeasures, 'windowMeasures', 'must be >= 1');
  }
  if (step < 1) {
    throw ArgumentError.value(step, 'step', 'must be >= 1');
  }
  final histograms = [for (final m in score.measures) _measureHistogram(m)];
  final n = histograms.length;

  final result = <LocalKey>[];
  for (var start = 0; start < n; start += step) {
    final end = (start + windowMeasures - 1).clamp(0, n - 1);
    final window = _sum(histograms.sublist(start, end + 1));
    if (window.every((w) => w == 0)) continue; // no pitched content
    result.add(LocalKey(
      firstMeasure: start,
      lastMeasure: end,
      estimate: estimateKey(window),
    ));
    if (end == n - 1) break; // the window has reached the end
  }
  return result;
}

/// The score's key **regions**: each measure is keyed by the window of
/// [windowMeasures] starting on it (shrinking at the end), silent windows
/// inherit their neighbour's key, and adjacent measures with the same key are
/// merged into one [LocalKey] span. Consecutive spans with different keys mark
/// modulations; a score that never changes key returns a single region.
///
/// Returns an empty list for a score with no pitched content.
List<LocalKey> keyRegions(Score score, {int windowMeasures = 4}) {
  final n = score.measures.length;
  if (n == 0) return const [];
  final histograms = [for (final m in score.measures) _measureHistogram(m)];

  // The window estimate attributed to each measure (null if its window is
  // entirely silent).
  final estimates = <KeyEstimate?>[];
  for (var start = 0; start < n; start++) {
    final end = (start + windowMeasures - 1).clamp(0, n - 1);
    final window = _sum(histograms.sublist(start, end + 1));
    estimates.add(window.every((w) => w == 0) ? null : estimateKey(window));
  }
  if (estimates.every((e) => e == null)) return const []; // wholly silent

  // Silent windows inherit a neighbour's key: forward-fill, then back-fill any
  // leading nulls.
  for (var i = 1; i < n; i++) {
    estimates[i] ??= estimates[i - 1];
  }
  for (var i = n - 2; i >= 0; i--) {
    estimates[i] ??= estimates[i + 1];
  }

  final regions = <LocalKey>[];
  var runStart = 0;
  for (var i = 1; i <= n; i++) {
    if (i == n || estimates[i]!.key != estimates[runStart]!.key) {
      regions.add(LocalKey(
        firstMeasure: runStart,
        lastMeasure: i - 1,
        estimate: estimates[runStart]!,
      ));
      runStart = i;
    }
  }
  return regions;
}

/// Measures (Takte) and tuplet spans.
library;

import '../internal/util.dart';
import '../theory/fraction.dart';
import 'element.dart';

/// A tuplet: [actual] notes played in the time of [normal], covering the
/// contiguous element range [startIndex]..[endIndex] of one measure.
///
/// A triplet of eighths is `TupletSpan(i, i+2, actual: 3, normal: 2)`:
/// each spanned element sounds `normal/actual` of its notated duration.
/// Spans must not overlap and cannot cross barlines.
class TupletSpan {
  /// Index of the first spanned element in the measure (inclusive).
  final int startIndex;

  /// Index of the last spanned element in the measure (inclusive).
  final int endIndex;

  /// Number of notated notes in the group (the printed digit).
  final int actual;

  /// The number of notes of the same value the group squeezes into.
  final int normal;

  /// Creates a tuplet span.
  const TupletSpan(
    this.startIndex,
    this.endIndex, {
    required this.actual,
    required this.normal,
  })  : assert(startIndex >= 0, 'startIndex must be >= 0'),
        assert(endIndex >= startIndex, 'endIndex must be >= startIndex'),
        assert(actual >= 2, 'actual must be >= 2'),
        assert(normal >= 1, 'normal must be >= 1');

  /// Whether [index] lies inside this span.
  bool contains(int index) => index >= startIndex && index <= endIndex;

  @override
  bool operator ==(Object other) =>
      other is TupletSpan &&
      other.startIndex == startIndex &&
      other.endIndex == endIndex &&
      other.actual == actual &&
      other.normal == normal;

  @override
  int get hashCode => Object.hash(startIndex, endIndex, actual, normal);

  @override
  String toString() => 'TupletSpan($startIndex..$endIndex, $actual:$normal)';
}

/// One measure: an ordered list of notes, chords and rests, with optional
/// tuplet spans over contiguous element ranges.
class Measure {
  /// The measure's elements in temporal order.
  final List<MusicElement> elements;

  /// Tuplet spans over [elements] (treat as immutable, non-overlapping).
  final List<TupletSpan> tuplets;

  /// Creates a measure from [elements] (treat the lists as immutable).
  const Measure(this.elements, {this.tuplets = const []});

  /// The sounding duration of the element at [index] as an exact fraction
  /// of a whole note, scaled by its tuplet span if any: a triplet eighth
  /// sounds 1/12.
  Fraction effectiveDurationAt(int index) {
    var fraction = elements[index].duration.toFraction();
    for (final span in tuplets) {
      if (span.contains(index)) {
        fraction = fraction * Fraction(span.normal, span.actual);
        break;
      }
    }
    return fraction;
  }

  /// The exact sum of the (tuplet-adjusted) element durations as a
  /// fraction of a whole note. Games compare this against
  /// `TimeSignature.measureCapacity` ("fill the measure" exercises); the
  /// layout engine does not enforce it.
  Fraction get totalDuration => [
        for (var i = 0; i < elements.length; i++) effectiveDurationAt(i),
      ].fold(Fraction.zero, (sum, f) => sum + f);

  @override
  bool operator ==(Object other) =>
      other is Measure &&
      listEquals(other.elements, elements) &&
      listEquals(other.tuplets, tuplets);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(elements), Object.hashAll(tuplets));

  @override
  String toString() => 'Measure(${elements.length} elements'
      '${tuplets.isEmpty ? '' : ', ${tuplets.length} tuplets'})';
}

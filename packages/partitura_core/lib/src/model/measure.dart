/// Measures (Takte).
library;

import '../internal/util.dart';
import '../theory/fraction.dart';
import 'element.dart';

/// One measure: an ordered list of notes, chords and rests.
class Measure {
  /// The measure's elements in temporal order.
  final List<MusicElement> elements;

  /// Creates a measure from [elements] (treat the list as immutable).
  const Measure(this.elements);

  /// The exact sum of the element durations as a fraction of a whole note.
  /// Games compare this against `TimeSignature.measureCapacity` ("fill the
  /// measure" exercises); the layout engine does not enforce it.
  Fraction get totalDuration => elements.fold(
        Fraction.zero,
        (sum, element) => sum + element.duration.toFraction(),
      );

  @override
  bool operator ==(Object other) =>
      other is Measure && listEquals(other.elements, elements);

  @override
  int get hashCode => Object.hashAll(elements);

  @override
  String toString() => 'Measure(${elements.length} elements)';
}

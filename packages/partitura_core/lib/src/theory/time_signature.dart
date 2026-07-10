/// Time signatures.
library;

import 'fraction.dart';

/// A simple-meter time signature such as 4/4 or 3/4.
class TimeSignature {
  /// Beats per measure (the upper number).
  final int beats;

  /// The note value of one beat as a denominator (the lower number):
  /// 4 = quarter note. Must be a power of two between 1 and 16.
  final int beatUnit;

  /// Creates a time signature of [beats] over [beatUnit].
  const TimeSignature(this.beats, this.beatUnit)
      : assert(beats >= 1, 'beats must be >= 1'),
        assert(
          beatUnit >= 1 && beatUnit <= 16 && (beatUnit & (beatUnit - 1)) == 0,
          'beatUnit must be a power of two between 1 and 16',
        );

  /// Common time, 4/4.
  static const TimeSignature fourFour = TimeSignature(4, 4);

  /// Waltz time, 3/4.
  static const TimeSignature threeFour = TimeSignature(3, 4);

  /// March time, 2/4.
  static const TimeSignature twoFour = TimeSignature(2, 4);

  /// Compound duple time, 6/8.
  static const TimeSignature sixEight = TimeSignature(6, 8);

  /// The total duration a full measure holds, as a reduced fraction of a
  /// whole note: 4/4 == (1, 1), 3/4 == (3, 4), 6/8 == (3, 4).
  (int, int) get measureCapacity {
    final f = toFraction();
    return (f.numerator, f.denominator);
  }

  /// The measure capacity as a [Fraction] of a whole note.
  Fraction toFraction() => Fraction(beats, beatUnit);

  @override
  bool operator ==(Object other) =>
      other is TimeSignature &&
      other.beats == beats &&
      other.beatUnit == beatUnit;

  @override
  int get hashCode => Object.hash(beats, beatUnit);

  @override
  String toString() => '$beats/$beatUnit';
}

/// Twelve-tone (serial) rows: an ordered permutation of the twelve pitch
/// classes and its four row forms — prime (P), inversion (I), retrograde (R)
/// and retrograde-inversion (RI) — plus the 12×12 row matrix used to read
/// every transposition of every form at a glance.
///
/// Pitch classes are integers 0–11 (C = 0 … B = 11), as in [PitchClassSet].
library;

import '../internal/util.dart';
import 'pitch.dart';

/// An ordered twelve-tone row: the twelve pitch classes each exactly once, in
/// the composer's chosen order. Order is significant (unlike a `PitchClassSet`,
/// which is unordered).
class ToneRow {
  /// The row's pitch classes in order (a permutation of 0–11).
  final List<int> pitchClasses;

  const ToneRow._(this.pitchClasses);

  /// Builds a row from twelve pitch classes (reduced mod 12). Throws
  /// [ArgumentError] unless all twelve pitch classes appear exactly once.
  factory ToneRow(Iterable<int> row) {
    final pcs = [for (final p in row) p % 12];
    if (pcs.length != 12 || pcs.toSet().length != 12) {
      throw ArgumentError.value(
          row, 'row', 'a tone row must list all twelve pitch classes once');
    }
    return ToneRow._(pcs);
  }

  /// Builds a row from twelve [pitches] in order (mod-12 of each MIDI number).
  factory ToneRow.of(Iterable<Pitch> pitches) =>
      ToneRow([for (final p in pitches) p.midiNumber % 12]);

  /// The prime transposed by [n] semitones — the row form **P_n** relative to
  /// this row (`transpose(0)` is the row itself).
  ToneRow transpose(int n) =>
      ToneRow._([for (final p in pitchClasses) (p + n) % 12]);

  /// The retrograde **R**: the row read back to front.
  ToneRow get retrograde => ToneRow._(pitchClasses.reversed.toList());

  /// The inversion: every interval turned upside down about [axis]
  /// (`p ↦ axis − p`). With the default axis (twice the first pitch class) the
  /// inverted row begins on the same note — the **I** row form of analysis.
  ToneRow invert([int? axis]) {
    final a = axis ?? 2 * pitchClasses.first;
    return ToneRow._([for (final p in pitchClasses) (a - p) % 12]);
  }

  /// The retrograde-inversion **RI**: the inversion read back to front.
  ToneRow get retrogradeInversion => invert().retrograde;

  /// This row transposed so it begins on pitch class 0 — the prime form
  /// **P0** that heads the row [matrix].
  List<int> get primeZero =>
      [for (final p in pitchClasses) (p - pitchClasses.first) % 12];

  /// The 12×12 row matrix. Row `r` read left→right is a prime form (its
  /// transposition level is the leftmost entry, `matrix[r][0]`); column `c`
  /// read top→bottom is an inversion form (level `matrix[0][c]`); rows read
  /// right→left are retrogrades and columns bottom→top retrograde-inversions.
  /// The top row is [primeZero] and the main diagonal is all zeros.
  List<List<int>> get matrix {
    final p0 = primeZero;
    final i0 = [for (final p in p0) (12 - p) % 12]; // inversion starting on 0
    return [
      for (final rowOffset in i0) [for (final p in p0) (p + rowOffset) % 12],
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is ToneRow && listEquals(other.pitchClasses, pitchClasses);

  @override
  int get hashCode => Object.hashAll(pitchClasses);

  @override
  String toString() => 'ToneRow(${pitchClasses.join(', ')})';
}

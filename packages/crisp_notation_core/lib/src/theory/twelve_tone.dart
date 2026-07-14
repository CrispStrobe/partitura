/// Twelve-tone (serial) row operations (Phase 4.8).
///
/// The four row forms — prime, inversion, retrograde, retrograde-inversion —
/// their transpositions, and the 12×12 row matrix. Pure theory.
library;

/// [row] transposed by [n] semitones (mod 12).
List<int> transposeRow(List<int> row, int n) =>
    [for (final p in row) (p + n) % 12];

/// The retrograde (reversal) of [row].
List<int> retrograde(List<int> row) => row.reversed.toList();

/// The inversion of [row] about its first note: `I[k] = 2·row[0] − row[k]`.
List<int> invertRow(List<int> row) {
  if (row.isEmpty) return [];
  final axis = row.first;
  return [for (final p in row) ((2 * axis - p) % 12 + 12) % 12];
}

/// The retrograde-inversion of [row] (the retrograde of its inversion).
List<int> retrogradeInversion(List<int> row) => retrograde(invertRow(row));

/// The twelve-tone matrix of [row] (a permutation of the pitch classes 0–11).
///
/// Row 0 is the prime form transposed to begin on 0 (P0); the first column is
/// its inversion (I0). Cell `[i][j] = (P0[j] + I0[i]) mod 12`. Reading a row
/// left→right is a prime (P) form, right→left its retrograde (R); a column
/// top→bottom is an inversion (I), bottom→top a retrograde-inversion (RI).
///
/// Throws an [ArgumentError] if [row] is not a permutation of 0–11.
List<List<int>> twelveToneMatrix(List<int> row) {
  if (row.length != 12 ||
      row.toSet().length != 12 ||
      row.any((p) => p < 0 || p > 11)) {
    throw ArgumentError('row must be a permutation of the 12 pitch classes');
  }
  final p0 = [for (final n in row) (n - row.first + 12) % 12];
  final i0 = [for (final n in p0) (12 - n) % 12];
  return [
    for (final base in i0) [for (final n in p0) (n + base) % 12],
  ];
}

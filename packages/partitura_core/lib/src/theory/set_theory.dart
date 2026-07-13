/// Post-tonal (pitch-class set) theory (Phase 4.5).
///
/// Normal order, Forte prime form, the interval-class vector and the Z-relation
/// for a pitch-class set (integers 0–11). Pure theory (no rendering); the
/// analysis toolkit for atonal music. The set-class *number* (Forte's `3-11`…)
/// is a naming table over prime forms and is out of scope here — the prime form
/// itself is the canonical set-class identifier.
library;

import 'pitch.dart';

/// The pitch classes (0–11) sounding in [pitches], de-duplicated.
Set<int> pitchClassSet(Iterable<Pitch> pitches) =>
    {for (final p in pitches) p.midiNumber % 12};

/// [pcs] transposed by [n] semitones (mod 12).
Set<int> transposeSet(Set<int> pcs, int n) =>
    {for (final p in pcs) (p + n) % 12};

/// [pcs] inverted about pitch class 0 (`p → −p mod 12`).
Set<int> invertSet(Set<int> pcs) => {for (final p in pcs) (12 - p) % 12};

/// The **normal order** of [pcs]: the rotation packed most tightly (smallest
/// span, ties broken from the outside in, then by the lowest starting pitch
/// class). Returns the actual pitch classes in that order.
List<int> normalForm(Set<int> pcs) {
  final s = pcs.toList()..sort();
  final n = s.length;
  if (n <= 1) return s;
  var bestStart = 0;
  List<int>? bestShape;
  for (var i = 0; i < n; i++) {
    // Ascending intervals above this rotation's starting note.
    final shape = [
      for (var k = 0; k < n; k++) (s[(i + k) % n] - s[i] + 12) % 12
    ];
    if (bestShape == null || _moreCompact(shape, bestShape)) {
      bestShape = shape;
      bestStart = i;
    }
  }
  return [for (var k = 0; k < n; k++) s[(bestStart + k) % n]];
}

/// The **Forte prime form** of [pcs]: the more left-packed of the set's and its
/// inversion's normal orders, transposed to start on 0.
List<int> primeForm(Set<int> pcs) {
  if (pcs.isEmpty) return [];
  final zeroed = _zeroed(normalForm(pcs));
  final invZeroed = _zeroed(normalForm(invertSet(pcs)));
  return _lexLess(invZeroed, zeroed) ? invZeroed : zeroed;
}

/// The **interval-class vector** of [pcs]: counts of interval classes 1–6
/// (`[ic1, ic2, ic3, ic4, ic5, ic6]`) across every unordered pair.
List<int> intervalClassVector(Set<int> pcs) {
  final v = List<int>.filled(6, 0);
  final s = pcs.toList();
  for (var i = 0; i < s.length; i++) {
    for (var j = i + 1; j < s.length; j++) {
      final d = ((s[i] - s[j]).abs()) % 12;
      final ic = d > 6 ? 12 - d : d;
      if (ic >= 1) v[ic - 1]++;
    }
  }
  return v;
}

/// Whether [a] and [b] are **Z-related**: the same interval-class vector but
/// different prime forms (not transpositions/inversions of each other).
bool zRelated(Set<int> a, Set<int> b) =>
    _listEq(intervalClassVector(a), intervalClassVector(b)) &&
    !_listEq(primeForm(a), primeForm(b));

// The interval shape of [order] shifted to begin on 0.
List<int> _zeroed(List<int> order) =>
    [for (final p in order) (p - order.first + 12) % 12];

// Compactness for normal order: smaller span (last interval) wins, ties broken
// by the next interval inward, and so on.
bool _moreCompact(List<int> a, List<int> b) {
  for (var k = a.length - 1; k >= 1; k--) {
    if (a[k] != b[k]) return a[k] < b[k];
  }
  return false;
}

// Lexicographic "more packed to the left" (both start on 0).
bool _lexLess(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

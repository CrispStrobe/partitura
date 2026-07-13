/// Post-tonal (atonal) set theory: pitch-class sets and the standard
/// analytical operations — normal order, prime form, the interval-class
/// vector, the T_n / T_nI transforms, complementation and the Z-relation.
///
/// A *pitch class* is an integer 0–11 (C = 0 … B = 11); octave and spelling
/// are discarded (mod 12). Operations follow the conventions in Straus,
/// *Introduction to Post-Tonal Theory*.
library;

import '../internal/util.dart';
import 'pitch.dart';

/// An unordered set of distinct pitch classes (integers 0–11), the object of
/// post-tonal analysis. Stored as its ascending, duplicate-free member list.
class PitchClassSet {
  /// The members in ascending order (each 0–11, distinct).
  final List<int> pitchClasses;

  const PitchClassSet._(this.pitchClasses);

  /// Builds a set from any integers, reducing each mod 12 and removing
  /// duplicates (so `[0, 4, 7, 12]` → `{0, 4, 7}`).
  factory PitchClassSet(Iterable<int> members) {
    final set = <int>{for (final m in members) m % 12};
    final sorted = set.toList()..sort();
    return PitchClassSet._(sorted);
  }

  /// Builds a pitch-class set from sounding [pitches] (mod-12 of each MIDI
  /// number; enharmonics and octaves collapse together).
  factory PitchClassSet.of(Iterable<Pitch> pitches) =>
      PitchClassSet([for (final p in pitches) p.midiNumber % 12]);

  /// The number of pitch classes (the set's *cardinality*).
  int get cardinality => pitchClasses.length;

  /// Whether the set has no members.
  bool get isEmpty => pitchClasses.isEmpty;

  /// The **normal order**: the set rotation that is most tightly packed to the
  /// left — smallest span, ties broken by the smaller inner spans, then by the
  /// lowest starting pitch class. Returned as an ascending run of members.
  List<int> get normalOrder {
    final n = pitchClasses.length;
    if (n <= 1) return List.of(pitchClasses);

    // Each rotation, unwrapped to a strictly ascending run (wrapped members
    // get + 12) so spans are simple subtractions.
    final rotations = <List<int>>[
      for (var i = 0; i < n; i++)
        [
          for (var k = 0; k < n; k++)
            pitchClasses[(i + k) % n] + (i + k >= n ? 12 : 0),
        ],
    ];

    var best = rotations.first;
    for (final rot in rotations.skip(1)) {
      if (_moreCompact(rot, best)) best = rot;
    }
    return [for (final v in best) v % 12];
  }

  /// True if rotation [a] is more tightly left-packed than [b]: compare the
  /// outer span, then successively smaller inner spans; a genuine tie (a
  /// symmetric set) is broken by the lower starting pitch class.
  static bool _moreCompact(List<int> a, List<int> b) {
    final n = a.length;
    for (var j = n - 1; j >= 1; j--) {
      final spanA = a[j] - a[0];
      final spanB = b[j] - b[0];
      if (spanA != spanB) return spanA < spanB;
    }
    return a[0] % 12 < b[0] % 12;
  }

  /// The **prime form**: the more left-packed of the set's and its inversion's
  /// normal orders, transposed to begin on 0. The canonical representative of
  /// the set class (all T_n / T_nI transforms share it).
  List<int> get primeForm {
    if (pitchClasses.isEmpty) return const [];
    List<int> zeroed(List<int> order) {
      final base = order.first;
      return [for (final p in order) (p - base) % 12];
    }

    final fromSet = zeroed(normalOrder);
    final fromInversion = zeroed(invert().normalOrder);
    return _lessPacked(fromSet, fromInversion) ? fromSet : fromInversion;
  }

  /// Whether zero-based form [a] is more packed to the left than [b]
  /// (lexicographically smaller across their members).
  static bool _lessPacked(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i] < b[i];
    }
    return false;
  }

  /// The **interval-class vector**: six counts, index `i` being the number of
  /// unordered pitch-class pairs an interval class `i + 1` apart (1–6). The
  /// fingerprint of a set class's harmonic content.
  List<int> get intervalClassVector {
    final vector = List<int>.filled(6, 0);
    for (var i = 0; i < pitchClasses.length; i++) {
      for (var j = i + 1; j < pitchClasses.length; j++) {
        final diff = (pitchClasses[j] - pitchClasses[i]) % 12;
        final ic = diff <= 6 ? diff : 12 - diff;
        vector[ic - 1]++;
      }
    }
    return vector;
  }

  /// Transposition T_n: every member raised by [n] semitones (mod 12).
  PitchClassSet transpose(int n) =>
      PitchClassSet([for (final p in pitchClasses) p + n]);

  /// Inversion T_nI about [axis] (default 0): each member `p` maps to
  /// `axis − p` (mod 12). `invert()` is plain inversion I; `invert(n)` is the
  /// composite T_nI.
  PitchClassSet invert([int axis = 0]) =>
      PitchClassSet([for (final p in pitchClasses) axis - p]);

  /// The complement: the pitch classes 0–11 **not** in this set.
  PitchClassSet get complement {
    final present = pitchClasses.toSet();
    return PitchClassSet([
      for (var pc = 0; pc < 12; pc++)
        if (!present.contains(pc)) pc,
    ]);
  }

  /// Whether [other] belongs to the same set class — i.e. is a transposition
  /// or inversion of this set (identical prime form).
  bool isSameSetClass(PitchClassSet other) =>
      listEquals(primeForm, other.primeForm);

  /// Whether this set and [other] are **Z-related**: distinct set classes that
  /// nonetheless share an interval-class vector (e.g. the all-interval
  /// tetrachords 4-Z15 `{0,1,4,6}` and 4-Z29 `{0,1,3,7}`).
  bool isZRelatedTo(PitchClassSet other) =>
      !isSameSetClass(other) &&
      listEquals(intervalClassVector, other.intervalClassVector);

  @override
  bool operator ==(Object other) =>
      other is PitchClassSet && listEquals(other.pitchClasses, pitchClasses);

  @override
  int get hashCode => Object.hashAll(pitchClasses);

  @override
  String toString() => 'PitchClassSet(${pitchClasses.join(', ')})';
}

/// Neo-Riemannian triad transforms (Phase 4.8).
///
/// The three contextual inversions P, L and R that map a consonant (major or
/// minor) triad to another sharing two common tones — the moves of
/// neo-Riemannian / transformational theory. Pure theory.
library;

import 'interval.dart';
import 'triad.dart';

/// The P / L / R transforms on a major or minor [Triad].
extension NeoRiemannian on Triad {
  bool get _isConsonant =>
      quality == ChordQuality.major || quality == ChordQuality.minor;

  /// **P** (Parallel): swaps mode on the same root — C major ↔ C minor.
  Triad get parallel {
    _require();
    return Triad(
        root,
        quality == ChordQuality.major
            ? ChordQuality.minor
            : ChordQuality.major);
  }

  /// **R** (Relative): a major triad → its relative minor (C → A minor); a minor
  /// triad → its relative major (A minor → C).
  Triad get relative {
    _require();
    return quality == ChordQuality.major
        ? Triad(root.transposeBy(Interval.minorThird, descending: true),
            ChordQuality.minor)
        : Triad(root.transposeBy(Interval.minorThird), ChordQuality.major);
  }

  /// **L** (Leittonwechsel): a major triad → the minor triad a major third above
  /// (C → E minor); a minor triad → the major triad a major third below
  /// (C minor → A♭ major).
  Triad get leittonwechsel {
    _require();
    return quality == ChordQuality.major
        ? Triad(root.transposeBy(Interval.majorThird), ChordQuality.minor)
        : Triad(root.transposeBy(Interval.majorThird, descending: true),
            ChordQuality.major);
  }

  void _require() {
    if (!_isConsonant) {
      throw StateError(
          'neo-Riemannian transforms apply only to major/minor triads');
    }
  }
}

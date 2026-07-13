/// Triads (Dreiklänge).
library;

import 'interval.dart';
import 'pitch.dart';

/// Triad qualities supported in v0.1.
enum ChordQuality {
  /// Major third + perfect fifth (Dur).
  major,

  /// Minor third + perfect fifth (Moll).
  minor,

  /// Minor third + diminished fifth (vermindert).
  diminished,

  /// Major third + augmented fifth (übermäßig).
  augmented,
}

/// A three-note chord built in thirds on a [root], optionally inverted.
class Triad {
  /// The chord's root (its octave anchors the returned pitches).
  final Pitch root;

  /// The chord quality.
  final ChordQuality quality;

  /// Inversion: 0 = root position, 1 = first inversion (third in the bass),
  /// 2 = second inversion (fifth in the bass).
  final int inversion;

  /// Creates a triad of [quality] on [root].
  const Triad(this.root, this.quality, {this.inversion = 0})
      : assert(inversion >= 0 && inversion <= 2, 'inversion must be 0..2');

  /// The chord tones from the bass upward. Root position returns
  /// root–third–fifth; inversions move the lowest notes up an octave, e.g.
  /// first inversion of C major is E4–G4–C5.
  List<Pitch> get pitches {
    final third = root.transposeBy(
      quality == ChordQuality.major || quality == ChordQuality.augmented
          ? Interval.majorThird
          : Interval.minorThird,
    );
    final fifth = root.transposeBy(switch (quality) {
      ChordQuality.major || ChordQuality.minor => Interval.perfectFifth,
      ChordQuality.diminished => Interval.diminishedFifth,
      ChordQuality.augmented => Interval.augmentedFifth,
    });
    final rootPosition = [root, third, fifth];
    return [
      ...rootPosition.sublist(inversion),
      ...rootPosition
          .sublist(0, inversion)
          .map((p) => p.transposeBy(Interval.perfectOctave)),
    ];
  }

  /// Whether this is a consonant (major or minor) triad — the domain of the
  /// neo-Riemannian [parallel] / [leadingToneExchange] / [relative] transforms.
  bool get isConsonant =>
      quality == ChordQuality.major || quality == ChordQuality.minor;

  /// The **P** (Parallel) transform: swaps major ↔ minor on the same root
  /// (C major ↔ C minor). Returns a root-position triad.
  ///
  /// Throws [StateError] on a diminished or augmented triad.
  Triad parallel() => Triad(
        root,
        _flipped('parallel (P)'),
      );

  /// The **L** (Leittonwechsel / leading-tone exchange) transform: a major
  /// triad becomes the minor triad on its third (C major → E minor); a minor
  /// triad becomes the major triad a major third below its root (E minor →
  /// C major). An involution. Returns a root-position triad.
  ///
  /// Throws [StateError] on a diminished or augmented triad.
  Triad leadingToneExchange() {
    _requireConsonant('leading-tone exchange (L)');
    return quality == ChordQuality.major
        ? Triad(root.transposeBy(Interval.majorThird), ChordQuality.minor)
        : Triad(root.transposeBy(Interval.majorThird, descending: true),
            ChordQuality.major);
  }

  /// The **R** (Relative) transform: a major triad becomes its relative minor
  /// (C major → A minor); a minor triad becomes its relative major (A minor →
  /// C major). An involution. Returns a root-position triad.
  ///
  /// Throws [StateError] on a diminished or augmented triad.
  Triad relative() {
    _requireConsonant('relative (R)');
    return quality == ChordQuality.major
        ? Triad(root.transposeBy(Interval.minorThird, descending: true),
            ChordQuality.minor)
        : Triad(root.transposeBy(Interval.minorThird), ChordQuality.major);
  }

  ChordQuality _flipped(String op) {
    _requireConsonant(op);
    return quality == ChordQuality.major
        ? ChordQuality.minor
        : ChordQuality.major;
  }

  void _requireConsonant(String op) {
    if (!isConsonant) {
      throw StateError('the $op transform needs a major or minor triad, '
          'not ${quality.name}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Triad &&
      other.root == root &&
      other.quality == quality &&
      other.inversion == inversion;

  @override
  int get hashCode => Object.hash(root, quality, inversion);

  @override
  String toString() =>
      'Triad($root ${quality.name}${inversion == 0 ? '' : ', inv $inversion'})';
}

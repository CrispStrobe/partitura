/// Roman-numeral harmonic analysis (Phase 4.1).
///
/// Bidirectional: [romanNumeralOf] reads a chord in a key as a Roman numeral
/// (scale degree, quality case, figured-bass inversion figures, secondary
/// dominants); [pitchClassesOf] realizes a [RomanNumeral] back to its pitch
/// classes in a key. Pure theory (no rendering) — the numeral's rendered form
/// is [RomanNumeral.symbol].
library;

import 'chord_analysis.dart';
import 'key.dart';
import 'pitch.dart';

/// Semitone above the tonic for each diatonic degree (1-based index − 1).
const _majorScale = [0, 2, 4, 5, 7, 9, 11];
const _minorScale = [0, 2, 3, 5, 7, 8, 10];

/// The degrees the minor mode also accepts without a chromatic prefix: the
/// raised submediant (melodic 6 = 9 semitones) and raised leading tone
/// (harmonic 7 = 11 semitones).
const _minorAlso = {6: 9, 7: 11};

const _upperRoman = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

/// A functional Roman-numeral reading of a chord within a key.
class RomanNumeral {
  /// Diatonic scale degree of the (applied) root, 1–7.
  final int degree;

  /// Chromatic prefix on the degree: −1 = flat, +1 = sharp, 0 = none
  /// (e.g. `-1` renders `bII`, `+1` renders `#iv`).
  final int alteration;

  /// The chord quality (drives the numeral's case and its °/ø/+ mark).
  final ChordType type;

  /// Inversion: 0 root position, 1 first, 2 second, 3 third.
  final int inversion;

  /// For a secondary (applied) chord, the diatonic degree it tonicizes — e.g.
  /// `5` for `V7/V`; null for a chord of the home key.
  final int? appliedTo;

  /// The rendered numeral of the tonicized target, with its own diatonic case
  /// (e.g. `V` for `V7/V`, `vi` for `V7/vi`); null when [appliedTo] is null.
  final String? applied;

  /// Creates a Roman-numeral reading.
  const RomanNumeral(this.degree, this.type, this.inversion,
      {this.alteration = 0, this.appliedTo, this.applied});

  static const _sevenths = {
    ChordType.dominantSeventh,
    ChordType.majorSeventh,
    ChordType.minorSeventh,
    ChordType.diminishedSeventh,
    ChordType.halfDiminishedSeventh,
    ChordType.minorMajorSeventh,
    ChordType.augmentedSeventh,
  };

  static const _upperQualities = {
    ChordType.major,
    ChordType.augmented,
    ChordType.dominantSeventh,
    ChordType.majorSeventh,
    ChordType.augmentedSeventh,
    ChordType.sus2,
    ChordType.sus4,
  };

  /// Whether this reads a seventh chord (four-note figures) rather than a triad.
  bool get isSeventh => _sevenths.contains(type);

  /// The figured-bass figure for the inversion (`6`, `6/4`, `6/5`, `4/3`, …).
  String get figure => isSeventh
      ? switch (inversion) {
          0 => '7',
          1 => '6/5',
          2 => '4/3',
          _ => '4/2',
        }
      : switch (inversion) {
          0 => '',
          1 => '6',
          _ => '6/4',
        };

  String get _mark => switch (type) {
        ChordType.diminished || ChordType.diminishedSeventh => '°', // °
        ChordType.halfDiminishedSeventh => 'ø', // ø
        ChordType.augmented || ChordType.augmentedSeventh => '+',
        _ => '',
      };

  String _numeralText(int degree, ChordType type) {
    final roman = _upperRoman[degree - 1];
    return _upperQualities.contains(type) ? roman : roman.toLowerCase();
  }

  String _prefix(int alteration) => alteration == 0
      ? ''
      : (alteration > 0 ? '#' * alteration : 'b' * -alteration);

  /// The rendered numeral, e.g. `I`, `ii`, `V7`, `V6/5`, `vii°7`, `bVI`,
  /// `V7/V`. A major seventh chord adds `M` (`IM7`); a suspended chord keeps
  /// its `sus` suffix.
  String get symbol {
    final buf = StringBuffer()
      ..write(_prefix(alteration))
      ..write(_numeralText(degree, type))
      ..write(_mark);
    if (type == ChordType.majorSeventh || type == ChordType.minorMajorSeventh) {
      buf.write('M'); // major-seventh quality: IM7, i(M7)…
    }
    if (type == ChordType.sus2) buf.write('sus2');
    if (type == ChordType.sus4) buf.write('sus4');
    if (type == ChordType.majorSixth || type == ChordType.minorSixth) {
      buf.write('add6');
    }
    buf.write(figure);
    if (applied != null) buf.write('/$applied');
    return buf.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is RomanNumeral &&
      other.degree == degree &&
      other.alteration == alteration &&
      other.type == type &&
      other.inversion == inversion &&
      other.appliedTo == appliedTo;

  @override
  int get hashCode =>
      Object.hash(degree, alteration, type, inversion, appliedTo);

  @override
  String toString() => 'RomanNumeral($symbol)';
}

/// The scale degree (1–7) and chromatic alteration of pitch class [pc] relative
/// to [key]'s tonic, using the root's letter [step] for the degree.
(int degree, int alteration) _degreeOf(int pc, Step step, Key key) {
  final tonicPc = key.tonic.midiNumber % 12;
  final degree = ((step.index - key.tonic.step.index) % 7 + 7) % 7 + 1;
  final actual = (pc - tonicPc + 12) % 12;
  final scale = key.isMajor ? _majorScale : _minorScale;
  // A minor key also treats the raised 6/7 as diatonic (harmonic/melodic).
  if (actual == scale[degree - 1] ||
      (!key.isMajor && _minorAlso[degree] == actual)) {
    return (degree, 0);
  }
  var alteration = actual - scale[degree - 1];
  if (alteration > 6) alteration -= 12;
  if (alteration < -6) alteration += 12;
  return (degree, alteration);
}

/// The diatonic degree (1–7) of pitch class [pc] in [key], or null if [pc] is
/// chromatic (not in the key's scale, counting the minor raised 6/7).
int? _diatonicDegree(int pc, Key key) {
  final tonicPc = key.tonic.midiNumber % 12;
  final semis = (pc - tonicPc + 12) % 12;
  final scale = key.isMajor ? _majorScale : _minorScale;
  for (var d = 1; d <= 7; d++) {
    if (scale[d - 1] == semis) return d;
    if (!key.isMajor && _minorAlso[d] == semis) return d;
  }
  return null;
}

/// Whether the diatonic triad on [degree] in [key] is major (a major third
/// above its root).
bool _diatonicIsMajor(int degree, Key key) {
  final scale = key.isMajor ? _majorScale : _minorScale;
  int semi(int d) => scale[(d - 1) % 7];
  return (semi(degree + 2) - semi(degree) + 12) % 12 == 4;
}

/// The diatonic triad's numeral text at [degree] in [key], carrying its own
/// case and a ° on a diminished degree — e.g. `V`, `vi`, `vii°`. Used to render
/// the target of an applied chord (`V7/vi`).
String _diatonicNumeralText(int degree, Key key) {
  final scale = key.isMajor ? _majorScale : _minorScale;
  int semi(int d) => scale[(d - 1) % 7];
  final root = semi(degree);
  final third = (semi(degree + 2) - root + 12) % 12;
  final fifth = (semi(degree + 4) - root + 12) % 12;
  final roman = _upperRoman[degree - 1];
  if (third == 4 && fifth == 8) return '$roman+'; // augmented
  if (third == 3 && fifth == 6) return '${roman.toLowerCase()}°'; // diminished
  if (third == 3) return roman.toLowerCase(); // minor
  return roman; // major (or fallback)
}

/// Reads [chord] as a [RomanNumeral] in [key], detecting secondary dominants
/// (`V7/V`) and secondary leading-tone chords (`vii°7/ii`).
RomanNumeral romanNumeralFor(ChordAnalysis chord, Key key) {
  final rootPc = chord.root.midiNumber % 12;

  // Secondary dominant: a major triad or dominant seventh whose root is a
  // perfect fifth above another (non-tonic) diatonic degree.
  if (chord.type == ChordType.major ||
      chord.type == ChordType.dominantSeventh) {
    final targetPc = (rootPc + 5) % 12; // the degree this chord dominates
    final target = _diatonicDegree(targetPc, key);
    final ownDegree = _degreeOf(rootPc, chord.root.step, key);
    // A major triad / dominant 7th that is the diatonic chord of its own degree
    // (its degree's diatonic triad is already major) is not a secondary chord.
    final isDiatonicHere =
        ownDegree.$2 == 0 && _diatonicIsMajor(ownDegree.$1, key);
    if (target != null && target != 1 && !isDiatonicHere) {
      // Degree 5 relative to the target.
      return RomanNumeral(5, chord.type, chord.inversion,
          appliedTo: target, applied: _diatonicNumeralText(target, key));
    }
  }

  // Secondary leading-tone chord: a diminished / half-diminished chord a
  // semitone below a (non-tonic) diatonic degree.
  if (chord.type == ChordType.diminished ||
      chord.type == ChordType.diminishedSeventh ||
      chord.type == ChordType.halfDiminishedSeventh) {
    final targetPc = (rootPc + 1) % 12;
    final target = _diatonicDegree(targetPc, key);
    final own = _degreeOf(rootPc, chord.root.step, key);
    if (target != null && target != 1 && own.$2 != 0) {
      return RomanNumeral(7, chord.type, chord.inversion,
          appliedTo: target, applied: _diatonicNumeralText(target, key));
    }
  }

  final (degree, alteration) = _degreeOf(rootPc, chord.root.step, key);
  return RomanNumeral(degree, chord.type, chord.inversion,
      alteration: alteration);
}

/// Identifies the chord [pitches] and reads it as a [RomanNumeral] in [key], or
/// null if the pitches form no recognized chord.
RomanNumeral? romanNumeralOf(List<Pitch> pitches, Key key) {
  final chord = identifyChord(pitches);
  return chord == null ? null : romanNumeralFor(chord, key);
}

/// Realizes [rn] back to the set of pitch classes it denotes in [key] — the
/// inverse of [romanNumeralFor] (voicing/inversion is not reconstructed).
Set<int> pitchClassesOf(RomanNumeral rn, Key key) {
  final tonicPc = key.tonic.midiNumber % 12;
  final scale = key.isMajor ? _majorScale : _minorScale;

  int degreeRoot(int degree) => (tonicPc + scale[degree - 1]) % 12;

  final int rootPc;
  if (rn.appliedTo != null) {
    // Applied chord: degree `rn.degree` of the tonicized target's scale.
    final targetRoot = degreeRoot(rn.appliedTo!);
    rootPc = (targetRoot + _majorScale[rn.degree - 1]) % 12;
  } else {
    rootPc = (degreeRoot(rn.degree) + rn.alteration + 12) % 12;
  }
  return {for (final semis in rn.type.intervals) (rootPc + semis) % 12};
}

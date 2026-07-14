/// Chord identification — the inverse of [Triad]: name a set of pitches.
///
/// Given the notes of a chord, [identifyChord] finds the root, quality and
/// inversion by matching the pitch-class set against the common triad, seventh
/// and sixth templates, and spells the result from the input pitches. Pure
/// theory (no rendering); pairs with the pedagogy core.
library;

import 'pitch.dart';

/// The chord qualities [identifyChord] recognizes.
enum ChordType {
  /// Major triad.
  major('', {0, 4, 7}),

  /// Minor triad.
  minor('m', {0, 3, 7}),

  /// Diminished triad.
  diminished('dim', {0, 3, 6}),

  /// Augmented triad.
  augmented('aug', {0, 4, 8}),

  /// Suspended second.
  sus2('sus2', {0, 2, 7}),

  /// Suspended fourth.
  sus4('sus4', {0, 5, 7}),

  /// Dominant seventh.
  dominantSeventh('7', {0, 4, 7, 10}),

  /// Major seventh.
  majorSeventh('maj7', {0, 4, 7, 11}),

  /// Minor seventh.
  minorSeventh('m7', {0, 3, 7, 10}),

  /// Diminished seventh.
  diminishedSeventh('dim7', {0, 3, 6, 9}),

  /// Half-diminished seventh (m7♭5).
  halfDiminishedSeventh('m7b5', {0, 3, 6, 10}),

  /// Minor–major seventh.
  minorMajorSeventh('m(maj7)', {0, 3, 7, 11}),

  /// Augmented seventh (7♯5).
  augmentedSeventh('7#5', {0, 4, 8, 10}),

  /// Major sixth.
  majorSixth('6', {0, 4, 7, 9}),

  /// Minor sixth.
  minorSixth('m6', {0, 3, 7, 9}),

  // --- Added ninths / sixth-ninth (no seventh) ---------------------------

  /// Added ninth (major triad + 9, no seventh).
  addNinth('add9', {0, 4, 7, 2}),

  /// Minor added ninth.
  minorAddNinth('m(add9)', {0, 3, 7, 2}),

  /// Six-nine (major triad + 6 + 9).
  sixNine('6/9', {0, 4, 7, 9, 2}),

  // --- Ninth chords ------------------------------------------------------

  /// Dominant ninth.
  dominantNinth('9', {0, 4, 7, 10, 2}),

  /// Major ninth.
  majorNinth('maj9', {0, 4, 7, 11, 2}),

  /// Minor ninth.
  minorNinth('m9', {0, 3, 7, 10, 2}),

  // --- Eleventh chords (dominant omits the clashing 3rd) -----------------

  /// Dominant eleventh (3rd omitted, the standard voicing).
  dominantEleventh('11', {0, 7, 10, 2, 5}),

  /// Minor eleventh.
  minorEleventh('m11', {0, 3, 7, 10, 2, 5}),

  // --- Thirteenth chords (5th and 11th omitted, the standard voicing) ----

  /// Dominant thirteenth.
  dominantThirteenth('13', {0, 4, 10, 2, 9}),

  /// Major thirteenth.
  majorThirteenth('maj13', {0, 4, 11, 2, 9}),

  /// Minor thirteenth.
  minorThirteenth('m13', {0, 3, 10, 2, 9}),

  // --- Augmented sixths (recognized by spelling; see [identifyChord]) -----
  // Intervals are relative to the flat-6 (the lower note of the aug-6th).

  /// Italian augmented sixth (♭6 – 1 – ♯4).
  italianSixth('It+6', {0, 4, 10}),

  /// French augmented sixth (♭6 – 1 – 2 – ♯4).
  frenchSixth('Fr+6', {0, 4, 6, 10}),

  /// German augmented sixth (♭6 – 1 – ♭3 – ♯4); enharmonic to a dominant 7th,
  /// so distinguished only by the spelled augmented-sixth interval.
  germanSixth('Ger+6', {0, 4, 7, 10});

  const ChordType(this.suffix, this.intervals);

  /// The chord-symbol suffix after the root (e.g. `m7`, `maj7`, `sus4`).
  final String suffix;

  /// Semitone intervals above the root, in stacked-thirds order.
  final Set<int> intervals;

  /// Whether this is an augmented-sixth sonority (It / Fr / Ger), which
  /// [identifyChord] recognizes by spelling rather than by pitch-class set.
  bool get isAugmentedSixth =>
      this == italianSixth || this == frenchSixth || this == germanSixth;
}

/// A named chord: [root]/[type]/[inversion], spelled from the input, with the
/// lowest note as [bass].
class ChordAnalysis {
  /// The chord root (spelled from an input pitch of the root's pitch class).
  final Pitch root;

  /// The recognized quality.
  final ChordType type;

  /// Inversion: 0 root position, 1 = third in the bass, 2 = fifth, …
  final int inversion;

  /// The lowest sounding pitch.
  final Pitch bass;

  /// Creates a chord analysis result.
  const ChordAnalysis(this.root, this.type, this.inversion, this.bass);

  /// The chord symbol, e.g. `C`, `Am7`, `G7`, `F#dim`, or a slash chord for an
  /// inversion, `C/E`. Augmented sixths use their functional label (`Ger+6`),
  /// which is key-relative and carries no root letter.
  String get symbol {
    if (type.isAugmentedSixth) return type.suffix;
    final base = '${_name(root)}${type.suffix}';
    return inversion == 0 ? base : '$base/${_name(bass)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ChordAnalysis &&
      other.root == root &&
      other.type == type &&
      other.inversion == inversion &&
      other.bass == bass;

  @override
  int get hashCode => Object.hash(root, type, inversion, bass);

  @override
  String toString() => 'ChordAnalysis($symbol)';
}

/// Identifies the chord formed by [pitches], or null if no template matches
/// (fewer than three distinct pitch classes, or an unrecognized sonority).
///
/// When two roots both fit (e.g. C6 vs Am7 for C–E–G–A), the reading with the
/// **bass** as the root wins, so voicing drives the spelling.
ChordAnalysis? identifyChord(List<Pitch> pitches) {
  if (pitches.length < 3) return null;
  final bass = pitches.reduce((a, b) => a.midiNumber <= b.midiNumber ? a : b);
  final pcs = {for (final p in pitches) p.midiNumber % 12};
  if (pcs.length < 3) return null;
  final bassPc = bass.midiNumber % 12;

  // Augmented sixths are recognized by their spelled aug-6th interval, before
  // pitch-class matching — a German 6th is enharmonic to a dominant 7th, so
  // only the spelling tells them apart.
  final aug6 = _augmentedSixth(pitches, pcs, bass);
  if (aug6 != null) return aug6;

  ChordAnalysis? match(int rootPc) {
    final intervals = {for (final pc in pcs) (pc - rootPc + 12) % 12};
    for (final type in ChordType.values) {
      if (type.isAugmentedSixth) continue; // spelling-only (handled above)
      if (_setEquals(intervals, type.intervals)) {
        final root = _spell(pitches, rootPc);
        final bassInterval = (bassPc - rootPc + 12) % 12;
        final order = type.intervals.toList()..sort();
        final inversion =
            order.indexOf(bassInterval).clamp(0, order.length - 1);
        return ChordAnalysis(root, type, inversion, bass);
      }
    }
    return null;
  }

  // Prefer the interpretation rooted on the bass (root position).
  final rooted = match(bassPc);
  if (rooted != null) return rooted;
  for (final pc in pcs) {
    if (pc == bassPc) continue;
    final found = match(pc);
    if (found != null) return found;
  }
  return null;
}

/// The chord symbol for [pitches] (shorthand for `identifyChord(...)?.symbol`).
String? chordSymbolFor(List<Pitch> pitches) => identifyChord(pitches)?.symbol;

/// Every tonal reading of a **pitch-class set** [pcs] (integers 0–11) — one per
/// root whose chord template matches, roots spelled canonically. This surfaces
/// the enharmonic re-reads of the same notes that a single spelled reading
/// hides: `{0,4,7,9}` reads as both **C6** and **Am7**; a fully-diminished
/// seventh `{0,3,6,9}` reads as four equivalent chords (C°7 = E♭°7 = G♭°7 =
/// A°7); an augmented triad `{0,4,8}` as three (C+ = E+ = A♭+).
///
/// [bassPc], if given and present in [pcs], puts the reading rooted on the bass
/// first and drives the inversion; otherwise every reading is root position.
/// Augmented sixths are spelling-dependent and are **not** enumerated here (use
/// [identifyChord] with real pitches for those). Returns `[]` if nothing fits.
List<ChordAnalysis> chordReadings(Set<int> pcs, {int? bassPc}) {
  if (pcs.length < 3) return const [];
  final roots = <int>[
    if (bassPc != null && pcs.contains(bassPc)) bassPc,
    for (final pc in pcs)
      if (pc != bassPc) pc,
  ];
  final readings = <ChordAnalysis>[];
  final seen = <String>{};
  for (final rootPc in roots) {
    final intervals = {for (final pc in pcs) (pc - rootPc + 12) % 12};
    for (final type in ChordType.values) {
      if (type.isAugmentedSixth) continue; // spelling-only
      if (!_setEquals(intervals, type.intervals)) continue;
      final root = _canonicalPitch(rootPc);
      final order = type.intervals.toList()..sort();
      final bassInterval = ((bassPc ?? rootPc) - rootPc + 12) % 12;
      final inversion = order.indexOf(bassInterval).clamp(0, order.length - 1);
      final bass = bassPc != null ? _canonicalPitch(bassPc) : root;
      if (seen.add('$rootPc:${type.name}')) {
        readings.add(ChordAnalysis(root, type, inversion, bass));
      }
    }
  }
  return readings;
}

// A default single-accidental spelling of a pitch class (flats for the black
// keys, except pc 6 as F#), for naming a reading that carries no spelling.
Pitch _canonicalPitch(int pc) {
  const table = <int, (Step, int)>{
    0: (Step.c, 0),
    1: (Step.d, -1),
    2: (Step.d, 0),
    3: (Step.e, -1),
    4: (Step.e, 0),
    5: (Step.f, 0),
    6: (Step.f, 1),
    7: (Step.g, 0),
    8: (Step.a, -1),
    9: (Step.a, 0),
    10: (Step.b, -1),
    11: (Step.b, 0),
  };
  final (step, alter) = table[pc % 12]!;
  return Pitch(step, alter: alter, octave: 4);
}

/// Detects an Italian / French / German augmented sixth in [pitches] by its
/// spelled augmented-sixth interval (a diatonic sixth spanning 10 semitones),
/// between the lowered submediant (♭6, the lower note) and the raised
/// subdominant (♯4). Returns null if no such interval + matching sonority is
/// present. The [pcs] set and [bass] are supplied by [identifyChord].
ChordAnalysis? _augmentedSixth(List<Pitch> pitches, Set<int> pcs, Pitch bass) {
  // One spelled representative per pitch class.
  final byPc = <int, Pitch>{};
  for (final p in pitches) {
    byPc.putIfAbsent(p.midiNumber % 12, () => p);
  }
  const shapes = {
    ChordType.italianSixth: {0, 4, 10},
    ChordType.frenchSixth: {0, 4, 6, 10},
    ChordType.germanSixth: {0, 4, 7, 10},
  };
  for (final flat6 in byPc.values) {
    for (final sharp4 in byPc.values) {
      if (identical(flat6, sharp4)) continue;
      // Ascending letter-sixth (5 diatonic steps) spanning 10 semitones.
      final generic = (sharp4.step.index - flat6.step.index + 7) % 7;
      final chroma = (sharp4.midiNumber - flat6.midiNumber) % 12;
      if (generic != 5 || chroma != 10) continue;
      final flat6Pc = flat6.midiNumber % 12;
      final rel = {for (final pc in pcs) (pc - flat6Pc + 12) % 12};
      for (final entry in shapes.entries) {
        if (_setEquals(rel, entry.value)) {
          return ChordAnalysis(flat6, entry.key, 0, bass);
        }
      }
    }
  }
  return null;
}

bool _setEquals(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

/// A pitch of pitch class [pc] taken from [pitches] (to keep its spelling), or
/// a default sharp spelling if none is present.
Pitch _spell(List<Pitch> pitches, int pc) {
  for (final p in pitches) {
    if (p.midiNumber % 12 == pc) return p;
  }
  const table = [
    (Step.c, 0), (Step.c, 1), (Step.d, 0), (Step.d, 1), //
    (Step.e, 0), (Step.f, 0), (Step.f, 1), (Step.g, 0),
    (Step.g, 1), (Step.a, 0), (Step.a, 1), (Step.b, 0),
  ];
  final (step, alter) = table[pc % 12];
  return Pitch(step, alter: alter, octave: 4);
}

String _name(Pitch pitch) {
  final letter = pitch.step.name.toUpperCase();
  final accidental = switch (pitch.alter) {
    0 => '',
    2 => '##',
    -2 => 'bb',
    _ => pitch.alter > 0 ? '#' * pitch.alter : 'b' * -pitch.alter,
  };
  return '$letter$accidental';
}

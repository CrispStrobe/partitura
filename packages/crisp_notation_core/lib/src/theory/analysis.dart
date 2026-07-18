// Automatic harmonic analysis of a [Score].
//
// This ties the theory toolkit together into a single pass over a score:
// it slices the music into vertical sonorities, identifies each as a chord
// ([identifyChord]), spells it as a roman numeral in the detected key
// ([keyOf] + [romanNumeralFor]), classifies its harmonic function
// (tonic/subdominant/dominant), flags the non-chord tones, and spots the
// cadences. It is the engine behind an "analysis view" — colour a score by
// function, print roman numerals under it, mark the cadences.
//
// Segmentation is a sweep across all four voices: at every distinct onset the
// sounding pitches form a sonority, consecutive equal chords are merged, and a
// measure whose notes are purely melodic (an arpeggio, say) falls back to a
// single implied chord for the bar. Non-chord tones are found by removing one
// pitch and re-identifying (so a suspension or passing tone over a clean triad
// is recovered). Phrase/form detection is deliberately out of scope here.

import '../model/element.dart';
import '../model/measure.dart';
import '../model/score.dart';
import 'chord_analysis.dart';
import 'key.dart';
import 'key_finding.dart';
import 'pitch.dart';
import 'roman_numeral.dart';

/// The harmonic function a roman numeral plays, derived from its scale degree.
/// Secondary dominants/leading-tone chords count as [HarmonicFunction.dominant].
/// Returns null for a numeral with no clear degree.
HarmonicFunction? functionOf(RomanNumeral rn) {
  if (rn.applied != null) return HarmonicFunction.dominant;
  switch (rn.degree) {
    case 1:
    case 3:
    case 6:
      return HarmonicFunction.tonic;
    case 2:
    case 4:
      return HarmonicFunction.subdominant;
    case 5:
    case 7:
      return HarmonicFunction.dominant;
    default:
      return null;
  }
}

/// One analysed harmonic region: the sounding [pitches] and, when they form a
/// recognisable chord, its [chord]/[roman]/[function] and the [nonChordTones]
/// left over. A region with a null [chord] is a passage no chord could be read
/// from (a scale run, a bare interval).
class HarmonicSegment {
  /// Creates a harmonic segment.
  const HarmonicSegment({
    required this.measureIndex,
    required this.pitches,
    this.chord,
    this.roman,
    this.function,
    this.nonChordTones = const [],
  });

  /// Index into [Score.measures] where this region begins.
  final int measureIndex;

  /// The sounding sonority (chord tones and any non-chord tones).
  final List<Pitch> pitches;

  /// The chord read from these [pitches], or null if none was recognisable.
  final ChordAnalysis? chord;

  /// The roman numeral of [chord] in the analysis key, or null.
  final RomanNumeral? roman;

  /// The harmonic function of [chord] (tonic/subdominant/dominant), or null.
  final HarmonicFunction? function;

  /// Sounding pitches that are not members of [chord].
  final List<Pitch> nonChordTones;

  /// Whether a chord was identified for this segment.
  bool get hasChord => chord != null;
}

/// The kind of cadence closing a phrase.
enum CadenceType {
  /// Dominant → tonic (V–I / vii°–I): a full stop.
  authentic,

  /// …ending on the dominant (–V): a question left open.
  half,

  /// Subdominant → tonic (IV–I): the "amen" ending.
  plagal,

  /// Dominant → submediant (V–vi): the surprise ending.
  deceptive,
}

/// A cadence: which [CadenceType] and where its resolving chord sits.
class Cadence {
  /// Creates a cadence of [type] resolving at [segmentIndex] / [measureIndex].
  const Cadence(this.type, this.segmentIndex, this.measureIndex);

  /// The kind of cadence.
  final CadenceType type;

  /// Index into [ScoreAnalysis.segments] of the resolving (second) chord.
  final int segmentIndex;

  /// Measure where the resolving chord sits.
  final int measureIndex;
}

/// The result of [analyze]: the detected [key], the harmonic [segments] in
/// order, and the [cadences] found between them.
class ScoreAnalysis {
  /// Creates a score analysis.
  const ScoreAnalysis({
    required this.key,
    required this.segments,
    required this.cadences,
  });

  /// The detected (or supplied) key.
  final Key key;

  /// The harmonic regions, in order.
  final List<HarmonicSegment> segments;

  /// The cadences found between segments.
  final List<Cadence> cadences;
}

/// Analyse [score]'s harmony. Pass [key] to fix the key (otherwise it's inferred
/// from the notes, duration-weighted, via Krumhansl–Schmuckler).
ScoreAnalysis analyze(Score score, {Key? key}) {
  // Gather every pitch (duration-weighted) for key finding.
  final allPitches = <Pitch>[];
  final weights = <double>[];
  for (final m in score.measures) {
    for (final voice in _voicesOf(m)) {
      for (final e in voice) {
        if (e is NoteElement) {
          final w = e.duration.toFraction().toDouble();
          for (final p in e.pitches) {
            allPitches.add(p);
            weights.add(w);
          }
        }
      }
    }
  }
  final k = key ??
      keyOf(allPitches, durations: weights) ??
      Key.major(const Pitch(Step.c));

  // Sweep each measure into sonorities → segments.
  final raw = <HarmonicSegment>[];
  for (var mi = 0; mi < score.measures.length; mi++) {
    final slices = _slicesOf(score.measures[mi]);
    final segs = <HarmonicSegment>[];
    var anyChord = false;
    for (final s in slices) {
      final seg = _segmentFor(mi, s, k);
      if (seg.chord != null) anyChord = true;
      segs.add(seg);
    }
    // Melodic bar (an arpeggio, a broken chord): read one implied chord for it.
    if (!anyChord && slices.isNotEmpty) {
      final distinct = _dedupe(slices.expand((s) => s).toList());
      final implied = _identify(distinct);
      if (implied != null) {
        final rn = romanNumeralFor(implied.chord, k);
        segs
          ..clear()
          ..add(HarmonicSegment(
            measureIndex: mi,
            pitches: distinct,
            chord: implied.chord,
            roman: rn,
            function: functionOf(rn),
            nonChordTones: implied.ncts,
          ));
      }
    }
    raw.addAll(segs);
  }

  final segments = _merge(raw);
  return ScoreAnalysis(
      key: k, segments: segments, cadences: _cadences(segments));
}

// ---- segmentation -----------------------------------------------------------

List<List<MusicElement>> _voicesOf(Measure m) =>
    [m.elements, m.voice2, m.voice3, m.voice4];

class _Event {
  _Event(this.start, this.end, this.pitches);
  final double start;
  final double end;
  final List<Pitch> pitches;
}

/// The vertical sonorities of one measure: each entry is the pitches sounding
/// over one onset-to-onset slice (in whole-note time), across all voices.
List<List<Pitch>> _slicesOf(Measure m) {
  final events = <_Event>[];
  var maxEnd = 0.0;
  for (final voice in _voicesOf(m)) {
    var t = 0.0;
    for (final e in voice) {
      final len = e.duration.toFraction().toDouble();
      if (e is NoteElement) events.add(_Event(t, t + len, e.pitches));
      t += len;
    }
    if (t > maxEnd) maxEnd = t;
  }
  if (events.isEmpty) return const [];
  const eps = 1e-6;
  final bounds = <double>{for (final e in events) e.start, maxEnd}.toList()
    ..sort();
  final slices = <List<Pitch>>[];
  for (var i = 0; i < bounds.length - 1; i++) {
    final b = bounds[i];
    final pitches = <Pitch>[];
    for (final e in events) {
      if (e.start <= b + eps && e.end > b + eps) pitches.addAll(e.pitches);
    }
    if (pitches.isNotEmpty) slices.add(pitches);
  }
  return slices;
}

HarmonicSegment _segmentFor(int mi, List<Pitch> pitches, Key key) {
  final res = _identify(pitches);
  if (res == null) return HarmonicSegment(measureIndex: mi, pitches: pitches);
  final rn = romanNumeralFor(res.chord, key);
  return HarmonicSegment(
    measureIndex: mi,
    pitches: pitches,
    chord: res.chord,
    roman: rn,
    function: functionOf(rn),
    nonChordTones: res.ncts,
  );
}

class _ChordResult {
  _ChordResult(this.chord, this.ncts);
  final ChordAnalysis chord;
  final List<Pitch> ncts;
}

/// Identify a chord in [pitches], recovering one non-chord tone if a direct
/// read fails (a suspension/passing tone over an otherwise clean chord).
_ChordResult? _identify(List<Pitch> pitches) {
  final direct = identifyChord(pitches);
  if (direct != null) return _ChordResult(direct, _nctsOf(pitches, direct));
  final distinct = _dedupe(pitches);
  if (distinct.length >= 4) {
    for (var i = 0; i < distinct.length; i++) {
      final sub = [
        for (var j = 0; j < distinct.length; j++)
          if (j != i) distinct[j],
      ];
      final c = identifyChord(sub);
      if (c != null) return _ChordResult(c, _nctsOf(pitches, c));
    }
  }
  return null;
}

List<Pitch> _nctsOf(List<Pitch> pitches, ChordAnalysis chord) {
  final rootPc = chord.root.midiNumber % 12;
  final chordPcs = {for (final i in chord.type.intervals) (rootPc + i) % 12};
  final out = <Pitch>[];
  final seen = <int>{};
  for (final p in pitches) {
    final pc = p.midiNumber % 12;
    if (!chordPcs.contains(pc) && seen.add(pc)) out.add(p);
  }
  return out;
}

List<Pitch> _dedupe(List<Pitch> pitches) {
  final seen = <int>{};
  final out = <Pitch>[];
  for (final p in pitches) {
    if (seen.add(p.midiNumber % 12)) out.add(p);
  }
  return out;
}

// ---- merging + cadences -----------------------------------------------------

bool _sameChord(ChordAnalysis? a, ChordAnalysis? b) =>
    a != null &&
    b != null &&
    a.root.midiNumber % 12 == b.root.midiNumber % 12 &&
    a.type == b.type;

List<HarmonicSegment> _merge(List<HarmonicSegment> raw) {
  final out = <HarmonicSegment>[];
  for (final seg in raw) {
    if (out.isNotEmpty &&
        ((seg.chord == null && out.last.chord == null) ||
            _sameChord(seg.chord, out.last.chord))) {
      final prev = out.removeLast();
      out.add(HarmonicSegment(
        measureIndex: prev.measureIndex,
        pitches: [...prev.pitches, ...seg.pitches],
        chord: prev.chord,
        roman: prev.roman,
        function: prev.function,
        nonChordTones: [...prev.nonChordTones, ...seg.nonChordTones],
      ));
    } else {
      out.add(seg);
    }
  }
  return out;
}

List<Cadence> _cadences(List<HarmonicSegment> segments) {
  final out = <Cadence>[];
  HarmonicSegment? prev;
  var prevIndex = -1;
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    if (!s.hasChord) continue;
    if (prev != null) {
      final pf = prev.function;
      final degree = s.roman?.degree;
      if (pf == HarmonicFunction.dominant && degree == 1) {
        out.add(Cadence(CadenceType.authentic, i, s.measureIndex));
      } else if (pf == HarmonicFunction.dominant && degree == 6) {
        out.add(Cadence(CadenceType.deceptive, i, s.measureIndex));
      } else if (pf == HarmonicFunction.subdominant && degree == 1) {
        out.add(Cadence(CadenceType.plagal, i, s.measureIndex));
      }
    }
    prev = s;
    prevIndex = i;
  }
  // A piece that ends on the dominant closes with a half cadence.
  if (prev != null && prev.function == HarmonicFunction.dominant) {
    final alreadyAuthentic = out
        .any((c) => c.segmentIndex == prevIndex && c.type != CadenceType.half);
    if (!alreadyAuthentic) {
      out.add(Cadence(CadenceType.half, prevIndex, prev.measureIndex));
    }
  }
  return out;
}

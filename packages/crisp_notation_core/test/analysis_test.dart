import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Parses a note like `c4`, `f#4`, `eb5`.
Pitch note(String s) {
  final m = RegExp(r'^([a-g])([#b]*)(-?\d+)$').firstMatch(s)!;
  final step = Step.values.firstWhere((st) => st.name == m[1]);
  final acc = m[2]!;
  final alter =
      acc.isEmpty ? 0 : (acc.startsWith('#') ? acc.length : -acc.length);
  return Pitch(step, alter: alter, octave: int.parse(m[3]!));
}

const _whole = NoteDuration(DurationBase.whole);
const _quarter = NoteDuration(DurationBase.quarter);

/// A score of one block chord per measure.
Score chords(List<List<String>> perMeasure) => Score(
      clef: Clef.treble,
      measures: [
        for (final ch in perMeasure)
          Measure([
            NoteElement(
                pitches: [for (final n in ch) note(n)], duration: _whole)
          ]),
      ],
    );

void main() {
  group('functionOf', () {
    Key cMajor() => const Key.major(Pitch(Step.c));
    RomanNumeral rn(List<String> pitches) =>
        romanNumeralOf([for (final p in pitches) note(p)], cMajor())!;

    test('classifies tonic / subdominant / dominant', () {
      expect(functionOf(rn(['c4', 'e4', 'g4'])), HarmonicFunction.tonic); // I
      expect(functionOf(rn(['f4', 'a4', 'c5'])),
          HarmonicFunction.subdominant); // IV
      expect(
          functionOf(rn(['g4', 'b4', 'd5'])), HarmonicFunction.dominant); // V
      expect(functionOf(rn(['a4', 'c5', 'e5'])), HarmonicFunction.tonic); // vi
      expect(functionOf(rn(['d4', 'f4', 'a4'])),
          HarmonicFunction.subdominant); // ii
    });
  });

  group('analyze', () {
    // Short chord-only fixtures are key-ambiguous (G–B–D reads as G major on its
    // own), so pin the key — the app passes the score's key signature likewise.
    const cMaj = Key.major(Pitch(Step.c));

    test('reads I–IV–V–I with functions and an authentic cadence', () {
      final a = analyze(chords([
        ['c4', 'e4', 'g4'],
        ['f4', 'a4', 'c5'],
        ['g4', 'b4', 'd5'],
        ['c4', 'e4', 'g4'],
      ]));

      expect(a.key.tonic.step, Step.c);
      expect(a.key.isMajor, isTrue);
      expect(a.segments.length, 4);
      expect(
          [for (final s in a.segments) s.roman!.symbol], ['I', 'IV', 'V', 'I']);
      expect([
        for (final s in a.segments) s.function
      ], [
        HarmonicFunction.tonic,
        HarmonicFunction.subdominant,
        HarmonicFunction.dominant,
        HarmonicFunction.tonic,
      ]);
      // V (segment 2) → I (segment 3) is an authentic cadence.
      expect(a.cadences.length, 1);
      expect(a.cadences.single.type, CadenceType.authentic);
      expect(a.cadences.single.segmentIndex, 3);
    });

    test('spots a plagal cadence (IV–I)', () {
      final a = analyze(
          chords([
            ['c4', 'e4', 'g4'],
            ['f4', 'a4', 'c5'],
            ['c4', 'e4', 'g4'],
          ]),
          key: cMaj);
      expect(a.cadences.map((c) => c.type), contains(CadenceType.plagal));
    });

    test('spots a deceptive cadence (V–vi)', () {
      final a = analyze(
          chords([
            ['g4', 'b4', 'd5'], // V
            ['a4', 'c5', 'e5'], // vi
          ]),
          key: cMaj);
      expect(a.cadences.map((c) => c.type), contains(CadenceType.deceptive));
    });

    test('spots a half cadence (ends on V)', () {
      final a = analyze(
          chords([
            ['c4', 'e4', 'g4'],
            ['g4', 'b4', 'd5'], // V — the phrase hangs open
          ]),
          key: cMaj);
      expect(a.cadences.map((c) => c.type), contains(CadenceType.half));
    });

    test('flags a non-chord tone over a clean triad', () {
      // C major triad with an F# that belongs to no C chord.
      final a = analyze(Score(clef: Clef.treble, measures: [
        Measure([
          NoteElement(
            pitches: [note('c4'), note('e4'), note('g4'), note('f#4')],
            duration: _whole,
          ),
        ]),
      ]));
      expect(a.segments.single.chord, isNotNull);
      expect(a.segments.single.chord!.root.step, Step.c);
      expect(
        a.segments.single.nonChordTones.map((p) => p.step),
        contains(Step.f),
      );
    });

    test('reads an implied chord from an arpeggiated (melodic) bar', () {
      final a = analyze(Score(clef: Clef.treble, measures: [
        Measure([
          for (final n in ['c4', 'e4', 'g4', 'c5'])
            NoteElement(pitches: [note(n)], duration: _quarter),
        ]),
      ]));
      expect(a.segments, isNotEmpty);
      expect(a.segments.first.chord, isNotNull);
      expect(a.segments.first.roman!.symbol, 'I');
    });

    test('carries the note element ids of each segment', () {
      final a = analyze(Score(clef: Clef.treble, measures: [
        Measure([
          NoteElement(
            pitches: [note('c4'), note('e4'), note('g4')],
            duration: _whole,
            id: 'chord1',
          ),
        ]),
      ]));
      expect(a.segments.single.elementIds, contains('chord1'));
    });

    test('merges a repeated chord into one segment', () {
      final a = analyze(
          chords([
            ['c4', 'e4', 'g4'],
            ['c4', 'e4', 'g4'],
            ['g4', 'b4', 'd5'],
          ]),
          key: cMaj);
      // The two identical tonic bars collapse to a single I segment.
      expect(a.segments.length, 2);
      expect(a.segments[0].roman!.symbol, 'I');
      expect(a.segments[1].roman!.symbol, 'V');
    });
  });
}

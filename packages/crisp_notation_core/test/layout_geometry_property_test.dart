import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// The layout engine and SVG writer must survive every valid score with finite
/// geometry — no crash, no NaN/Infinity coordinate — however extreme the input.
/// This fuzzes the layout stressors (very high/low octaves and their ledger
/// lines, dense chords and their accidental stacks, grace notes, tuplets, every
/// clef, wide key signatures, two voices) that example-based layout tests can't
/// enumerate.
void main() {
  final meta = SmuflMetadata.fromJson(jsonDecode(
      File('../crisp_notation/assets/smufl/bravura_metadata.json')
          .readAsStringSync()) as Map<String, Object?>);
  final settings = LayoutSettings(metadata: meta);
  const engine = LayoutEngine();

  final clefs = [
    Clef.treble,
    Clef.bass,
    Clef.alto,
    Clef.tenor,
    Clef.percussion
  ];
  final meters = <TimeSignature>[
    TimeSignature.fourFour,
    const TimeSignature(3, 4),
    const TimeSignature(7, 8),
    const TimeSignature(2, 2),
    const TimeSignature(12, 8),
  ];
  const durs = [
    (NoteDuration.whole, 64),
    (NoteDuration.half, 32),
    (NoteDuration.quarter, 16),
    (NoteDuration.eighth, 8),
    (NoteDuration(DurationBase.sixteenth), 4),
    (NoteDuration(DurationBase.thirtySecond), 2),
  ];

  Score generate(Random rng) {
    var id = 0;
    final ts = meters[rng.nextInt(meters.length)];
    final cap = ts.measureCapacity;
    final capUnits = 64 * cap.$1 ~/ cap.$2;
    Pitch anyPitch() => Pitch(Step.values[rng.nextInt(7)],
        alter: rng.nextInt(3) - 1, octave: rng.nextInt(10));

    List<MusicElement> voice() {
      final els = <MusicElement>[];
      var remaining = capUnits;
      while (remaining > 0) {
        final choices = durs.where((d) => d.$2 <= remaining).toList();
        final pick = choices[rng.nextInt(choices.length)];
        remaining -= pick.$2;
        if (rng.nextInt(7) == 0) {
          els.add(RestElement(pick.$1, id: 'e${id++}'));
        } else {
          final n = rng.nextInt(4) == 0 ? 1 + rng.nextInt(6) : 1;
          final pitches = <Pitch>{};
          var guard = 0;
          while (pitches.length < n && guard++ < 30) {
            pitches.add(anyPitch());
          }
          els.add(NoteElement(
            pitches: pitches.toList(),
            duration: pick.$1,
            id: 'e${id++}',
            tieToNext: rng.nextInt(5) == 0,
            graceNotes: rng.nextInt(4) == 0
                ? [for (var g = 0; g < 1 + rng.nextInt(3); g++) anyPitch()]
                : const [],
          ));
        }
      }
      return els;
    }

    final measures = <Measure>[];
    for (var b = 0; b < 1 + rng.nextInt(3); b++) {
      // A triplet bar — the tuplet-bracket stressor.
      if (rng.nextInt(4) == 0) {
        measures.add(Measure([
          for (var i = 0; i < 3; i++)
            NoteElement(pitches: [
              Pitch(Step.values[rng.nextInt(7)], octave: rng.nextInt(10))
            ], duration: NoteDuration.eighth, id: 'e${id++}'),
        ], tuplets: const [
          TupletSpan(0, 2, actual: 3, normal: 2)
        ]));
        continue;
      }
      final v1 = voice();
      measures.add(
          rng.nextInt(3) == 0 ? Measure(v1, voice2: voice()) : Measure(v1));
    }
    return Score(
      clef: clefs[rng.nextInt(clefs.length)],
      keySignature: KeySignature(rng.nextInt(15) - 7),
      timeSignature: ts,
      measures: measures,
    );
  }

  Iterable<double> coordsOf(LayoutPrimitive p) sync* {
    switch (p) {
      case GlyphPrimitive():
        yield* [p.position.x, p.position.y, p.scale];
      case LinePrimitive():
        yield* [p.from.x, p.from.y, p.to.x, p.to.y, p.thickness];
      case TextPrimitive():
        yield* [p.position.x, p.position.y, p.size];
      case BeamPrimitive():
        yield* [p.start.x, p.start.y, p.end.x, p.end.y, p.thickness];
      case CurvePrimitive():
        yield* [
          p.start.x, p.start.y, p.control1.x, p.control1.y, //
          p.control2.x, p.control2.y, p.end.x, p.end.y, p.thickness,
        ];
    }
  }

  test('layout + SVG stay finite and crash-free over 250 stressed scores', () {
    final rng = Random(20260717);
    for (var seed = 0; seed < 250; seed++) {
      final score = generate(rng);
      final layout = engine.layout(score, settings);

      expect(layout.width, predicate<double>((w) => w.isFinite && w > 0),
          reason: 'width for seed $seed');
      expect(layout.height, predicate<double>((h) => h.isFinite && h > 0),
          reason: 'height for seed $seed');
      for (final p in layout.primitives) {
        expect(coordsOf(p).every((c) => c.isFinite), isTrue,
            reason: 'non-finite coordinate in $p (seed $seed)');
      }

      final svg = scoreToSvg(layout);
      expect(svg, isNot(anyOf(contains('NaN'), contains('Infinity'))),
          reason: 'SVG for seed $seed');
    }
  });
}

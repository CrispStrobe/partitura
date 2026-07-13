import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  group('pitchClassHistogram', () {
    test('weights each pitch class by sounding duration', () {
      // A whole-note C, then a quarter E: C gets 4x the weight of E.
      final score = Score.simple(notes: 'c4:w | e4:q r:q r:q r:q');
      final h = pitchClassHistogram([
        for (final m in score.measures) ...[...m.elements, ...m.voice2],
      ]);
      expect(h[0], greaterThan(0)); // C present
      expect(h[4], greaterThan(0)); // E present
      expect(h[0], closeTo(h[4] * 4, 1e-9)); // whole vs quarter
      expect(h[1], 0); // C# absent
    });

    test('rests contribute nothing', () {
      expect(
          pitchClassHistogram(
                  Score.simple(notes: 'r:w').measures.first.elements)
              .every((w) => w == 0),
          isTrue);
    });
  });

  group('localKeys', () {
    test('a C major passage reads as C major throughout', () {
      // C-major scale runs (the octave doubles the tonic), unambiguously C.
      final score = Score.simple(
        timeSignature: TimeSignature.fourFour,
        notes:
            'c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5',
      );
      final windows = localKeys(score, windowMeasures: 2);
      expect(windows, isNotEmpty);
      for (final w in windows) {
        expect(w.key.isMajor, isTrue);
        expect(w.key.tonic.step, Step.c);
      }
    });

    test('rejects a non-positive window or step', () {
      final score = Score.simple(notes: 'c4:q d4 e4 f4');
      expect(() => localKeys(score, windowMeasures: 0), throwsArgumentError);
      expect(() => localKeys(score, step: 0), throwsArgumentError);
    });

    test('skips windows with no pitched content', () {
      final score = Score.simple(notes: 'r:w | r:w');
      expect(localKeys(score), isEmpty);
    });
  });

  group('keyRegions', () {
    test('a single-key piece is one region', () {
      final score = Score.simple(
        timeSignature: TimeSignature.fourFour,
        notes:
            'c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5',
      );
      final regions = keyRegions(score, windowMeasures: 2);
      expect(regions, hasLength(1));
      expect(regions.single.firstMeasure, 0);
      expect(regions.single.lastMeasure, 3);
      expect(regions.single.key.tonic.step, Step.c);
    });

    test('detects a modulation from C major to G major', () {
      // Four bars of C-major scale runs, then four of G-major (with F#).
      final score = Score.simple(
        timeSignature: TimeSignature.fourFour,
        notes:
            'c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5 | c4:e d4 e4 f4 g4 a4 b4 c5 | g4:e a4 b4 c5 d5 e5 f#5 g5 | g4:e a4 b4 c5 d5 e5 f#5 g5 | g4:e a4 b4 c5 d5 e5 f#5 g5 | g4:e a4 b4 c5 d5 e5 f#5 g5',
      );
      final regions = keyRegions(score, windowMeasures: 2);
      expect(regions.length, greaterThanOrEqualTo(2));
      expect(regions.first.key.tonic.step, Step.c);
      expect(regions.last.key.tonic.step, Step.g);
      // Regions are contiguous and cover the whole score in order.
      expect(regions.first.firstMeasure, 0);
      expect(regions.last.lastMeasure, 7);
      for (var i = 1; i < regions.length; i++) {
        expect(regions[i].firstMeasure, regions[i - 1].lastMeasure + 1);
      }
    });

    test('an empty or silent score has no regions', () {
      expect(keyRegions(Score.simple(notes: 'r:w | r:w')), isEmpty);
      expect(keyRegions(Score(clef: Clef.treble, measures: const [])), isEmpty);
    });
  });
}

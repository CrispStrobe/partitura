import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

Fraction f(int n, int d) => Fraction(n, d);

void main() {
  group('Tempo.quarterBpm', () {
    test('normalizes the beat unit and dots', () {
      expect(const Tempo(120).quarterBpm, 120); // quarter = 120
      expect(const Tempo(60, beatUnit: DurationBase.half).quarterBpm, 120);
      expect(
        const Tempo(80, beatUnit: DurationBase.quarter, dots: 1).quarterBpm,
        closeTo(120, 1e-9), // dotted quarter at 80 → quarter at 120
      );
      expect(const Tempo(240, beatUnit: DurationBase.eighth).quarterBpm, 120);
    });
  });

  group('TempoMap', () {
    test('constant tempo matches secondsFor', () {
      final map = TempoMap.constant(120);
      expect(map.secondsAt(f(0, 1)), 0);
      expect(map.secondsAt(f(1, 4)),
          closeTo(secondsFor(f(1, 4), quarterBpm: 120), 1e-9));
      expect(map.secondsAt(f(1, 1)), closeTo(2.0, 1e-9)); // whole @120 = 2s
      expect(map.timeAt(0.5), closeTo(0.25, 1e-9)); // a quarter
      expect(map.timeAt(2.0), closeTo(1.0, 1e-9));
    });

    test('piecewise tempo accumulates per span', () {
      // Bar 1 at ♩=120 (2 s/whole), then ♩=60 (4 s/whole) from time 1/1.
      final map = TempoMap([
        TempoSpan(f(0, 1), 120),
        TempoSpan(f(1, 1), 60),
      ]);
      expect(map.secondsAt(f(1, 1)), closeTo(2.0, 1e-9)); // end of span 1
      expect(map.secondsAt(f(3, 2)), closeTo(4.0, 1e-9)); // + half whole @60
      expect(map.secondsAt(f(2, 1)), closeTo(6.0, 1e-9)); // + whole @60
      // Inverse.
      expect(map.timeAt(2.0), closeTo(1.0, 1e-9));
      expect(map.timeAt(4.0), closeTo(1.5, 1e-9));
      expect(map.timeAt(6.0), closeTo(2.0, 1e-9));
      // Unsorted input is accepted.
      final same = TempoMap([TempoSpan(f(1, 1), 60), TempoSpan(f(0, 1), 120)]);
      expect(same.secondsAt(f(2, 1)), closeTo(6.0, 1e-9));
    });

    test('needs a span at time 0', () {
      expect(() => TempoMap([TempoSpan(f(1, 1), 120)]), throwsArgumentError);
      expect(() => TempoMap(const []), throwsArgumentError);
    });
  });

  group('SyncPoints', () {
    // 0..1 whole → 0..3 s (slow), 1..2 whole → 3..5 s (faster).
    final sync = SyncPoints([
      (time: f(0, 1), seconds: 0.0),
      (time: f(1, 1), seconds: 3.0),
      (time: f(2, 1), seconds: 5.0),
    ]);

    test('interpolates seconds between anchors', () {
      expect(sync.secondsAt(f(0, 1)), closeTo(0.0, 1e-9));
      expect(sync.secondsAt(f(1, 2)), closeTo(1.5, 1e-9)); // mid first segment
      expect(sync.secondsAt(f(1, 1)), closeTo(3.0, 1e-9));
      expect(sync.secondsAt(f(3, 2)), closeTo(4.0, 1e-9)); // mid second segment
      expect(sync.secondsAt(f(2, 1)), closeTo(5.0, 1e-9));
    });

    test('inverts seconds → musical time', () {
      expect(sync.timeAt(0.0), closeTo(0.0, 1e-9));
      expect(sync.timeAt(1.5), closeTo(0.5, 1e-9));
      expect(sync.timeAt(3.0), closeTo(1.0, 1e-9));
      expect(sync.timeAt(4.0), closeTo(1.5, 1e-9));
    });

    test('extrapolates past the last anchor using the nearest pair', () {
      // Slope of the last segment is 2 s/whole; at t=3 → 3 + (3-1)*2 = 7.
      expect(sync.secondsAt(f(3, 1)), closeTo(7.0, 1e-9));
      expect(sync.timeAt(7.0), closeTo(3.0, 1e-9));
    });

    test('needs at least two distinct anchors', () {
      expect(() => SyncPoints([(time: f(0, 1), seconds: 0.0)]),
          throwsArgumentError);
      expect(
        () => SyncPoints([
          (time: f(1, 1), seconds: 0.0),
          (time: f(1, 1), seconds: 2.0),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('tempoMapOf (mid-score tempo changes)', () {
    test('collects the initial tempo + each Measure.tempoChange at its onset',
        () {
      final score = Score(
        clef: Clef.treble,
        timeSignature: TimeSignature.fourFour,
        tempo: const Tempo(120),
        measures: [
          Measure([
            NoteElement(
                pitches: [const Pitch(Step.c, octave: 5)],
                duration: NoteDuration.whole,
                id: 'a'),
          ]),
          Measure([
            NoteElement(
                pitches: [const Pitch(Step.d, octave: 5)],
                duration: NoteDuration.whole,
                id: 'b'),
          ], tempoChange: const Tempo(60)),
        ],
      );
      final map = tempoMapOf(score);
      expect(map.spans, hasLength(2));
      expect(map.spans[0].at, Fraction(0, 1));
      expect(map.spans[0].quarterBpm, 120);
      // Second bar starts one whole note in, at half speed.
      expect(map.spans[1].at, Fraction(1, 1));
      expect(map.spans[1].quarterBpm, 60);
    });

    test('mid-score tempo round-trips through MusicXML', () {
      final source = Score(
        clef: Clef.treble,
        timeSignature: TimeSignature.fourFour,
        tempo: const Tempo(120),
        measures: [
          Measure([
            NoteElement(
                pitches: [const Pitch(Step.c, octave: 5)],
                duration: NoteDuration.whole,
                id: 'a'),
          ]),
          Measure([
            NoteElement(
                pitches: [const Pitch(Step.d, octave: 5)],
                duration: NoteDuration.whole,
                id: 'b'),
          ], tempoChange: const Tempo(60)),
        ],
      );
      final back = scoreFromMusicXml(scoreToMusicXml(source));
      expect(back.tempo, const Tempo(120));
      expect(back.measures[0].tempoChange, isNull);
      expect(back.measures[1].tempoChange, const Tempo(60));
    });
  });
}

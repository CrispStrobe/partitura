import 'dart:math';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Every exporter must survive every *valid* score without throwing, and the
/// playback timeline must stay well-formed (sorted, non-negative onsets, in-
/// range measure indices) regardless of a score's repeat / volta / navigation
/// structure. This is the dual of `reader_robustness_test.dart` (readers reject
/// bad input) for the write side: writers must never crash on good input.
void main() {
  // Score → String/bytes exporters that take a plain [Score].
  final exporters = <String, void Function(Score)>{
    'MusicXML': (s) => scoreToMusicXml(s),
    'MEI': (s) => scoreToMei(s),
    'kern': (s) => scoreToKern(s),
    'ABC': (s) => scoreToAbc(s),
    'MuseScore': (s) => scoreToMscx(s),
    'LilyPond': (s) => scoreToLilyPond(s),
    'Braille': (s) => scoreToBraille(s),
    'GPIF': (s) => scoreToGpif(s),
    'MIDI': (s) => scoreToMidi(s),
  };

  void expectSurvives(Score score, String label) {
    exporters.forEach((name, write) {
      expect(() => write(score), returnsNormally,
          reason: '$name threw on $label');
    });
    for (final expand in [true, false]) {
      final tl = playbackTimeline(score, expandRepeats: expand);
      Fraction? prev;
      for (final n in tl) {
        expect(n.start.numerator, greaterThanOrEqualTo(0),
            reason: 'negative onset on $label');
        expect(n.measureIndex,
            allOf(greaterThanOrEqualTo(0), lessThan(score.measures.length)),
            reason: 'bad measureIndex on $label');
        if (prev != null) {
          expect(
              n.start.toDouble(), greaterThanOrEqualTo(prev.toDouble() - 1e-9),
              reason: 'timeline not sorted on $label');
        }
        prev = n.start;
      }
    }
  }

  test('exporters survive random repeat/volta structures (200 scores)', () {
    final rng = Random(20260717);
    for (var seed = 0; seed < 200; seed++) {
      final measures = <Measure>[];
      var id = 0;
      for (var b = 0; b < 1 + rng.nextInt(6); b++) {
        measures.add(Measure(
          [
            for (var i = 0; i < 4; i++)
              NoteElement(
                  pitches: [Pitch(Step.values[rng.nextInt(7)], octave: 4)],
                  duration: NoteDuration.quarter,
                  id: 'e${id++}'),
          ],
          startRepeat: rng.nextInt(4) == 0,
          endRepeat: rng.nextInt(4) == 0,
          volta: rng.nextInt(3) == 0 ? 1 + rng.nextInt(2) : null,
          barline: BarlineStyle.values[rng.nextInt(BarlineStyle.values.length)],
        ));
      }
      expectSurvives(
          Score(
              clef: Clef.treble,
              timeSignature: TimeSignature.fourFour,
              measures: measures),
          'repeat/volta seed $seed');
    }
  });

  group('exporters survive every well-formed navigation structure', () {
    Measure bar(String id, {NavigationMark? nav}) => Measure([
          NoteElement(
              pitches: [const Pitch(Step.c, octave: 4)],
              duration: NoteDuration.whole,
              id: id)
        ], navigation: nav);
    Score sc(List<Measure> m) => Score(
        clef: Clef.treble, timeSignature: TimeSignature.fourFour, measures: m);

    // (structure, expected unfolded id order) for the eight canonical jumps.
    final cases = <String, (Score, String)>{
      'D.C.': (sc([bar('a'), bar('b', nav: NavigationMark.daCapo)]), 'a b a b'),
      'D.C. al Fine': (
        sc([
          bar('a', nav: NavigationMark.fine),
          bar('b', nav: NavigationMark.daCapoAlFine)
        ]),
        'a b a'
      ),
      'D.C. al Coda': (
        sc([
          bar('a', nav: NavigationMark.toCoda),
          bar('b', nav: NavigationMark.daCapoAlCoda),
          bar('c', nav: NavigationMark.coda)
        ]),
        'a b a c'
      ),
      'D.S.': (
        sc([
          bar('a', nav: NavigationMark.segno),
          bar('b', nav: NavigationMark.dalSegno)
        ]),
        'a b a b'
      ),
      'D.S. al Fine': (
        sc([
          bar('a', nav: NavigationMark.segno),
          bar('b', nav: NavigationMark.fine),
          bar('c', nav: NavigationMark.dalSegnoAlFine)
        ]),
        'a b c a b'
      ),
      'D.S. al Coda': (
        sc([
          bar('a', nav: NavigationMark.segno),
          bar('b', nav: NavigationMark.toCoda),
          bar('c', nav: NavigationMark.dalSegnoAlCoda),
          bar('d', nav: NavigationMark.coda)
        ]),
        'a b c a b d'
      ),
    };

    cases.forEach((name, data) {
      test(name, () {
        final (score, expected) = data;
        // The unfolding is exactly the documented performance order.
        expect(playbackTimeline(score).map((n) => n.elementId).join(' '),
            expected);
        expectSurvives(score, name);
      });
    });
  });
}

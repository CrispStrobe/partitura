import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Score-model lacuna, increment 1 (representability): a `Measure` can now hold
/// up to four voices (`voice3`/`voice4`), round-tripping through MusicXML and
/// covered by playback/transposition. The layout engine still engraves voices
/// 1–2 today; drawing 3–4 is the follow-up layout increment.
void main() {
  NoteElement n(Step step, int oct, String id) =>
      NoteElement.note(Pitch(step, octave: oct), NoteDuration.half, id: id);

  final source = Score(
    clef: Clef.treble,
    timeSignature: TimeSignature.fourFour,
    measures: [
      Measure(
        [n(Step.c, 5, 'e0'), n(Step.d, 5, 'e1')], // voice 1
        voice2: [n(Step.g, 4, 'e2'), n(Step.a, 4, 'e3')],
        voice3: [n(Step.e, 4, 'e4'), n(Step.f, 4, 'e5')],
        voice4: [n(Step.c, 3, 'e6'), n(Step.d, 3, 'e7')],
      ),
    ],
  );

  test('a measure holds four voices', () {
    expect(source.measures.single.voices.length, 4);
  });

  test('MusicXML round-trips all four voices', () {
    final back = scoreFromMusicXml(scoreToMusicXml(source));
    expect(back.measures.single.voices.length, 4);
    expect(back, source);
  });

  test('MEI and MuseScore round-trip all four voices', () {
    expect(scoreFromMei(scoreToMei(source)), source);
    expect(scoreFromMscx(scoreToMscx(source)), source);
  });

  test('playback covers every voice', () {
    final timeline = playbackTimeline(source);
    expect(timeline.length, 8);
    expect(timeline.map((note) => note.voice).toSet(), {0, 1, 2, 3});
  });

  test('transposition moves voices 3 and 4', () {
    final up = source.transposedBy(const Interval(IntervalQuality.major, 2));
    final measure = up.measures.single;
    expect((measure.voice3.first as NoteElement).pitches.single,
        const Pitch(Step.f, alter: 1, octave: 4)); // E4 -> F#4
    expect((measure.voice4.first as NoteElement).pitches.single,
        const Pitch(Step.d, octave: 3)); // C3 -> D3
  });

  test('a single-voice measure is unchanged (empty voices 2–4)', () {
    final m = Measure([n(Step.c, 4, 'e0')]);
    expect(m.voice3, isEmpty);
    expect(m.voice4, isEmpty);
    expect(m.voices.length, 1);
  });
}

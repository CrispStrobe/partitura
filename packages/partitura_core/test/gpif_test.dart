import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

List<String> pitchNames(Score s) => s.measures
    .expand((m) => m.elements)
    .whereType<NoteElement>()
    .expand((n) => n.pitches)
    .map((p) => p.toString())
    .toList();

void main() {
  test('writes a GPIF document with the expected structure', () {
    final gpif = scoreToGpif(Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'g4:q b4',
    ));
    expect(gpif, contains('<GPIF>'));
    expect(gpif, contains('name="Tuning"'));
    expect(gpif, contains('<Pitches>'));
    expect(gpif, contains('<NoteValue>Quarter</NoteValue>'));
    expect(gpif, contains('<Property name="Fret">'));
  });

  test('round-trips pitches and durations', () {
    final source = Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'e2:q g2 c3 e3 | g4:h a4',
    );
    final back = scoreFromGpif(scoreToGpif(source));
    expect(back.measures, hasLength(2));
    expect(pitchNames(back), pitchNames(source));
    final durations = back.measures
        .expand((m) => m.elements)
        .whereType<NoteElement>()
        .map((n) => n.duration)
        .toList();
    expect(durations.last, NoteDuration.half); // a4 was a half note
  });

  test('round-trips a chord', () {
    final back = scoreFromGpif(scoreToGpif(Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'e2+b2+e4:w',
    )));
    final chord = back.measures.single.elements.whereType<NoteElement>().single;
    expect(chord.pitches, hasLength(3));
  });

  test('round-trips rests and dotted durations', () {
    final back = scoreFromGpif(scoreToGpif(Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'e2:q. r:e g3:h',
    )));
    final els = back.measures.single.elements;
    expect(els[0], isA<NoteElement>());
    expect((els[0] as NoteElement).duration,
        const NoteDuration(DurationBase.quarter, dots: 1));
    expect(els[1], isA<RestElement>());
  });

  test('recovers the time signature', () {
    final back = scoreFromGpif(scoreToGpif(Score.simple(
      timeSignature: const TimeSignature(3, 4),
      notes: 'e2:q g2 c3',
    )));
    expect(back.timeSignature, const TimeSignature(3, 4));
  });

  test('a drop-D tuning round-trips its low note', () {
    // Low D2 is only reachable on the dropped 6th string.
    final source = Score.simple(notes: 'd2:q');
    final back = scoreFromGpif(scoreToGpif(source, tuning: Tuning.dropDGuitar));
    expect(pitchNames(back), ['D2']);
  });

  test('rejects non-GPIF input', () {
    expect(() => scoreFromGpif('<Other></Other>'), throwsFormatException);
  });
}

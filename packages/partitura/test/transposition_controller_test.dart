import 'package:flutter_test/flutter_test.dart';
import 'package:partitura/partitura.dart';

int firstMidi(Score s) =>
    (s.measures.first.elements.first as NoteElement).pitches.first.midiNumber;

void main() {
  test('transposeBy composes; reset restores the base', () {
    final base = Score.simple(notes: 'c4:q e4 g4');
    final c = TranspositionController(base);
    expect(firstMidi(c.score), 60); // c4
    expect(c.isTransposed, isFalse);

    var n = 0;
    c.addListener(() => n++);

    c.transposeBy(Interval.majorSecond); // up a whole tone
    expect(firstMidi(c.score), 62); // d4
    expect(c.isTransposed, isTrue);

    c.octaveUp(); // composes on the current score
    expect(firstMidi(c.score), 74); // d5

    c.reset();
    expect(firstMidi(c.score), 60);
    expect(c.isTransposed, isFalse);

    expect(n, 3); // majorSecond, octaveUp, reset
    c.dispose();
  });

  test('octaveDown descends a perfect octave', () {
    final c = TranspositionController(Score.simple(notes: 'c4:q'));
    c.octaveDown();
    expect(firstMidi(c.score), 48); // c3
    c.dispose();
  });

  test('showConcertPitch returns to the base sounding pitch', () {
    // Plain (non-transposing) score: concert pitch == written pitch.
    final base = Score.simple(notes: 'c4:q e4');
    final c = TranspositionController(base);
    c.transposeBy(Interval.perfectFifth);
    expect(c.isTransposed, isTrue);
    c.showConcertPitch();
    expect(firstMidi(c.score), 60); // back to c4
    expect(c.isTransposed, isFalse);
    c.dispose();
  });
}

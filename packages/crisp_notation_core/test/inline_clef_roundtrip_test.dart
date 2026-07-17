import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Mid-measure clef changes (`Measure.inlineClefs`) round-trip through MusicXML.
/// The reader already parsed a mid-measure `<clef>` into an [InlineClefChange] at
/// the position it appears; the writer now emits `<attributes><clef>` at each
/// change's onset, so export → import preserves them.
void main() {
  NoteElement q(Step step, {int octave = 4, String? id}) =>
      NoteElement.note(Pitch(step, octave: octave), NoteDuration.quarter,
          id: id);

  test('a mid-measure clef change survives export → import', () {
    // 4/4 bar of four quarters; the clef flips to bass at onset 1/2 (after two
    // quarters — right before the third note).
    final score = Score(
      clef: Clef.treble,
      timeSignature: TimeSignature.fourFour,
      measures: [
        Measure(
          [
            q(Step.c, id: 'a'),
            q(Step.d, id: 'b'),
            q(Step.e, id: 'c'),
            q(Step.f, id: 'd')
          ],
          inlineClefs: [InlineClefChange(Fraction(1, 2), Clef.bass)],
        ),
      ],
    );

    final xml = scoreToMusicXml(score);
    // The mid-measure clef is emitted as its own attributes block.
    expect(xml, contains('<attributes><clef><sign>F</sign><line>4</line>'));

    final parsed = scoreFromMusicXml(xml);
    expect(parsed.measures, hasLength(1));
    expect(
      parsed.measures[0].inlineClefs,
      [InlineClefChange(Fraction(1, 2), Clef.bass)],
      reason: 'onset and clef both survive the round-trip',
    );
  });

  test(
      'a bar with no inline clef emits none (byte-identity for the common case)',
      () {
    final score = Score(
      clef: Clef.treble,
      measures: [
        Measure([q(Step.c, id: 'a'), q(Step.d, id: 'b')]),
      ],
    );
    final xml = scoreToMusicXml(score);
    // Only the leading attributes clef, never a mid-measure one.
    expect('<attributes>'.allMatches(xml).length, 1);
    expect(scoreFromMusicXml(xml).measures[0].inlineClefs, isEmpty);
  });
}

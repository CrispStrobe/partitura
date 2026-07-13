import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// Score-model lacuna implemented: structured chord symbols (`ChordSymbol` —
/// root pitch + quality + optional slash bass) replace opaque text for lead-
/// sheet harmony. Unlike text annotations, the roots are real pitches, so the
/// symbol **transposes**. Round-trips through MusicXML `<harmony>`.
void main() {
  final source = Score(
    clef: Clef.treble,
    timeSignature: TimeSignature.fourFour,
    measures: [
      Measure([
        NoteElement.note(const Pitch(Step.c), NoteDuration.quarter, id: 'e0'),
        NoteElement.note(const Pitch(Step.d), NoteDuration.quarter, id: 'e1'),
        NoteElement.note(const Pitch(Step.e), NoteDuration.quarter, id: 'e2'),
        NoteElement.note(const Pitch(Step.f), NoteDuration.quarter, id: 'e3'),
      ]),
    ],
    chordSymbols: const [
      ChordSymbol('e0', Pitch(Step.c), ChordSymbolKind.majorSeventh),
      ChordSymbol('e1', Pitch(Step.g), ChordSymbolKind.dominantSeventh,
          bass: Pitch(Step.b)),
      ChordSymbol(
          'e2', Pitch(Step.f, alter: 1), ChordSymbolKind.halfDiminishedSeventh),
      ChordSymbol('e3', Pitch(Step.b, alter: -1), ChordSymbolKind.minor),
    ],
  );

  test('symbols format to lead-sheet text', () {
    expect(source.chordSymbols.map((c) => c.text).toList(),
        ['Cmaj7', 'G7/B', 'F#m7b5', 'Bbm']);
  });

  test('MusicXML round-trips structured chord symbols', () {
    final back = scoreFromMusicXml(scoreToMusicXml(source));
    expect(back.chordSymbols, source.chordSymbols);
    expect(back, source);
  });

  test('transposing up a fifth moves roots and basses (text unchanged type)',
      () {
    final up = source.transposedBy(const Interval(IntervalQuality.perfect, 5));
    expect(up.chordSymbols.map((c) => c.text).toList(),
        ['Gmaj7', 'D7/F#', 'C#m7b5', 'Fm']);
  });

  test('the root/bass octave is irrelevant to equality (pitch class)', () {
    expect(
        const ChordSymbol('e0', Pitch(Step.c), ChordSymbolKind.major),
        const ChordSymbol(
            'e0', Pitch(Step.c, octave: 2), ChordSymbolKind.major));
  });

  test('text annotations still round-trip (now via <words>)', () {
    final withText = Score.simple(notes: 'c4:q d4', annotations: 'Andante *');
    final back = scoreFromMusicXml(scoreToMusicXml(withText));
    expect(back.annotations, const [Annotation('e0', 'Andante')]);
    expect(back.chordSymbols, isEmpty);
  });
}

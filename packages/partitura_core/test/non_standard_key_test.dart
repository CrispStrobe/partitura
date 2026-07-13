import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// Score-model lacuna: non-standard (modal/atonal) key signatures — an
/// explicit list of accidentals the circle of fifths cannot express (here a
/// mixed B♭ + F♯), plus senza-misura (unmetered) scores.
void main() {
  const bFlatFSharp = KeySignature.custom([
    KeyAccidental(Step.b, -1),
    KeyAccidental(Step.f, 1),
  ]);

  test('a custom signature alters only its listed steps', () {
    expect(bFlatFSharp.isStandard, isFalse);
    expect(bFlatFSharp.alterFor(Step.b), -1);
    expect(bFlatFSharp.alterFor(Step.f), 1);
    expect(bFlatFSharp.alterFor(Step.c), 0);
    expect(bFlatFSharp.alteredSteps, [Step.b, Step.f]);
  });

  test('value semantics distinguish order and content', () {
    expect(
      bFlatFSharp,
      const KeySignature.custom([
        KeyAccidental(Step.b, -1),
        KeyAccidental(Step.f, 1),
      ]),
    );
    expect(
        bFlatFSharp.hashCode,
        const KeySignature.custom(
            [KeyAccidental(Step.b, -1), KeyAccidental(Step.f, 1)]).hashCode);
    // A standard signature is never equal to a custom one, even at fifths 0.
    expect(bFlatFSharp == const KeySignature(0), isFalse);
    // Order matters.
    expect(
      bFlatFSharp ==
          const KeySignature.custom(
              [KeyAccidental(Step.f, 1), KeyAccidental(Step.b, -1)]),
      isFalse,
    );
  });

  test('a custom signature round-trips through MusicXML', () {
    final score = Score.simple(
      keySignature: bFlatFSharp,
      notes: 'c4:q d4 e4 f4',
    );
    expect(scoreFromMusicXml(scoreToMusicXml(score)), score);
  });

  test('a custom signature is left as written under transposition', () {
    final score = Score.simple(keySignature: bFlatFSharp, notes: 'c4:q d4');
    final up = score.transposedBy(const Interval(IntervalQuality.major, 2));
    // The notes move, the non-standard signature does not.
    expect(up.keySignature, bFlatFSharp);
    expect((up.measures.single.elements.first as NoteElement).pitches.single,
        const Pitch(Step.d, octave: 4));
  });

  test('senza misura (null time signature) round-trips through MusicXML', () {
    final score = Score.simple(timeSignature: null, notes: 'c4:q d4 e4 f4');
    expect(score.timeSignature, isNull);
    expect(scoreFromMusicXml(scoreToMusicXml(score)), score);
  });
}

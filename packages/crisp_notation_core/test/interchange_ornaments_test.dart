import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Enrichment parity: ornaments (trill / short-trill / mordent / turn) now
/// survive MEI, MuseScore and kern round-trips and emit in LilyPond. MEI uses
/// `<trill>`/`<mordent>`/`<turn>` control events anchored to a note `xml:id`;
/// MuseScore and kern attach them per-note like articulations.
void main() {
  // DSL: % trill, $ short trill, & mordent, ? turn (raw string keeps `$`).
  final source = Score.simple(
    timeSignature: TimeSignature.fourFour,
    notes: r'c4:q% d4$ e4& f4? | g4:q% a4 b4 c5',
  );

  test('MusicXML round-trips ornaments (reference)', () {
    expect(scoreFromMusicXml(scoreToMusicXml(source)), source);
  });

  test('MEI round-trips ornaments (control events by xml:id)', () {
    expect(scoreFromMei(scoreToMei(source)), source);
  });

  test('MuseScore round-trips ornaments', () {
    expect(scoreFromMscx(scoreToMscx(source)), source);
  });

  test('Humdrum kern round-trips ornaments', () {
    expect(scoreFromKern(scoreToKern(source)), source);
  });

  test('LilyPond emits the ornament scripts', () {
    final ly = scoreToLilyPond(source);
    expect(ly, contains('\\trill'));
    expect(ly, contains('\\prall')); // short trill
    expect(ly, contains('\\mordent'));
    expect(ly, contains('\\turn'));
  });

  test('an ornament and an articulation coexist on one note', () {
    final both = Score.simple(notes: r'c4:q%> d4');
    expect(scoreFromMei(scoreToMei(both)), both);
    expect(scoreFromMscx(scoreToMscx(both)), both);
    expect(scoreFromKern(scoreToKern(both)), both);
  });

  test('the inverted turn round-trips (writer encoded it, reader dropped it)',
      () {
    // Regression: kern wrote `$` and MEI wrote <turn form="lower">, but the kern
    // reader ignored `$` and the MEI reader read any <turn> back as a plain
    // turn — so an inverted turn silently degraded on both round-trips.
    final source = Score(
      clef: Clef.treble,
      timeSignature: TimeSignature.fourFour,
      measures: [
        Measure([
          NoteElement(
            pitches: [const Pitch(Step.c, octave: 5)],
            duration: NoteDuration.whole,
            id: 'e0',
            ornament: Ornament.invertedTurn,
          ),
        ]),
      ],
    );
    for (final codec
        in <(String, String Function(Score), Score Function(String))>[
      ('MusicXML', scoreToMusicXml, scoreFromMusicXml),
      ('MEI', scoreToMei, scoreFromMei),
      ('kern', scoreToKern, scoreFromKern),
      ('ABC', scoreToAbc, scoreFromAbc),
      ('MuseScore', scoreToMscx, scoreFromMscx),
    ]) {
      final back = codec.$3(codec.$2(source));
      final ornament = back.measures
          .expand((m) => m.elements)
          .whereType<NoteElement>()
          .single
          .ornament;
      expect(ornament, Ornament.invertedTurn, reason: '${codec.$1} dropped it');
    }
  });
}

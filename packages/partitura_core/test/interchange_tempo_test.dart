import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// Score-model lacuna implemented: a structured metronome mark (`Tempo` — bpm +
/// beat unit + dots) is now a first-class `Score` field. A quarter-note tempo
/// round-trips through every reader; the beat unit/dots survive where the
/// format encodes them (MusicXML/MEI/LilyPond). kern (`*MM`) and MuseScore
/// (`<tempo>`) store a quarter-note-per-minute equivalent, so only quarter-beat
/// tempi round-trip through them exactly (documented).
void main() {
  final plain = Score.simple(notes: 'c4:q d4', tempo: const Tempo(120));
  final dotted =
      Score.simple(notes: 'c4:q d4', tempo: const Tempo(80, dots: 1));

  test('quarter-note tempo round-trips through every reader', () {
    const t = Tempo(120);
    expect(scoreFromMusicXml(scoreToMusicXml(plain)).tempo, t);
    expect(scoreFromMei(scoreToMei(plain)).tempo, t);
    expect(scoreFromMscx(scoreToMscx(plain)).tempo, t);
    expect(scoreFromKern(scoreToKern(plain)).tempo, t);
  });

  test('MusicXML and MEI keep a dotted-quarter beat unit', () {
    const t = Tempo(80, dots: 1);
    expect(scoreFromMusicXml(scoreToMusicXml(dotted)).tempo, t);
    expect(scoreFromMei(scoreToMei(dotted)).tempo, t);
  });

  test('LilyPond emits a tempo mark', () {
    expect(scoreToLilyPond(plain), contains('\\tempo 4 = 120'));
    expect(scoreToLilyPond(dotted), contains('\\tempo 4. = 80'));
  });

  test('no tempo round-trips as null through every reader', () {
    final none = Score.simple(notes: 'c4:q');
    for (final back in [
      scoreFromMusicXml(scoreToMusicXml(none)),
      scoreFromMei(scoreToMei(none)),
      scoreFromMscx(scoreToMscx(none)),
      scoreFromKern(scoreToKern(none)),
    ]) {
      expect(back.tempo, isNull);
    }
  });
}

import 'package:partitura_core/partitura_core.dart';
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
}

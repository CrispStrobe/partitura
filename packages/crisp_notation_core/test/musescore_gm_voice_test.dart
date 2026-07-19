// The MuseScore reader captures each part's General-MIDI voice from its native
// encoding — `<Instrument><Channel><program value="N"/>` (0-based GM) and a
// drum part (`<useDrumset>1` or a `<Drum>` map) — into ScoreMetadata, so a
// renderer can voice a raw .mscx per part.

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

const _mscx = '''
<?xml version="1.0" encoding="UTF-8"?>
<museScore version="4.20">
  <Score>
    <Part id="1"><Staff id="1"/><trackName>Bass</trackName>
      <Instrument><Channel><program value="32"/></Channel></Instrument></Part>
    <Part id="2"><Staff id="2"/><trackName>Drums</trackName>
      <Instrument><useDrumset>1</useDrumset>
        <Drum pitch="36"><head>normal</head><line>6</line><name>Kick</name></Drum>
      </Instrument></Part>
    <Staff id="1"><Measure><voice>
      <Clef><concertClefType>F</concertClefType></Clef>
      <TimeSig><sigN>4</sigN><sigD>4</sigD></TimeSig>
      <Chord><durationType>whole</durationType>
        <Note><pitch>36</pitch></Note></Chord>
    </voice></Measure></Staff>
    <Staff id="2"><Measure><voice>
      <Clef><concertClefType>PERC</concertClefType></Clef>
      <TimeSig><sigN>4</sigN><sigD>4</sigD></TimeSig>
      <Chord><durationType>whole</durationType>
        <Note><pitch>36</pitch></Note></Chord>
    </voice></Measure></Staff>
  </Score>
</museScore>''';

void main() {
  test('reads Channel program (0-based) + drumset percussion per part', () {
    final mp = multiPartScoreFromMscx(_mscx);
    expect(mp.parts.length, 2);

    expect(mp.parts[0].metadata.instrument, 'Bass');
    expect(mp.parts[0].metadata.midiProgram, 32);
    expect(mp.parts[0].metadata.isPercussion, isFalse);

    expect(mp.parts[1].metadata.isPercussion, isTrue,
        reason: 'a drum part → percussion');
  });
}

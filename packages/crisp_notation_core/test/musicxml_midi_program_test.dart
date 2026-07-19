// The MusicXML reader captures each score-part's General-MIDI voice —
// `<midi-instrument><midi-program>` (1-based → 0-based) and `<midi-channel>10`
// (percussion) — into ScoreMetadata, so a renderer can voice each part with its
// own GM instrument.

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

String _part(String id, String name, String midiInstrument, String notes) => '''
    <score-part id="$id">
      <part-name>$name</part-name>
      $midiInstrument
    </score-part>''';

String _measure(String notes) => '''
    <measure number="1">
      <attributes><divisions>1</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      $notes
    </measure>''';

const _note = '''
      <note><pitch><step>C</step><octave>4</octave></pitch>
        <duration>4</duration><type>whole</type></note>''';

String _doc(List<String> scoreParts, List<String> parts) => '''
<?xml version="1.0"?>
<score-partwise version="4.0">
  <part-list>
${scoreParts.join('\n')}
  </part-list>
${parts.join('\n')}
</score-partwise>''';

void main() {
  test('reads midi-program (1-based) + percussion channel per part', () {
    final xml = _doc(
      [
        _part(
            'P1',
            'Bass',
            '''
      <midi-instrument id="P1-I1">
        <midi-channel>1</midi-channel>
        <midi-program>33</midi-program>
      </midi-instrument>''',
            ''),
        _part(
            'P2',
            'Drums',
            '''
      <midi-instrument id="P2-I1">
        <midi-channel>10</midi-channel>
        <midi-program>1</midi-program>
      </midi-instrument>''',
            ''),
      ],
      [
        '  <part id="P1">${_measure(_note)}</part>',
        '  <part id="P2">${_measure(_note)}</part>',
      ],
    );

    final mp = multiPartScoreFromMusicXml(xml);
    expect(mp.parts.length, 2);

    // Program 33 in MusicXML (1-based) → 32 (0-based GM Acoustic Bass).
    expect(mp.parts[0].metadata.midiProgram, 32);
    expect(mp.parts[0].metadata.isPercussion, isFalse);

    // Channel 10 → percussion, regardless of program.
    expect(mp.parts[1].metadata.isPercussion, isTrue);
  });

  test('a part with no midi-instrument leaves the GM voice unset', () {
    final xml = _doc(
      [_part('P1', 'Piano', '', '')],
      ['  <part id="P1">${_measure(_note)}</part>'],
    );
    final mp = multiPartScoreFromMusicXml(xml);
    expect(mp.parts.single.metadata.midiProgram, isNull);
    expect(mp.parts.single.metadata.isPercussion, isFalse);
  });
}

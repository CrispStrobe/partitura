import 'dart:typed_data';

import 'package:partitura_cli/src/gp_container.dart';
import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  test('writeGpFromGpif produces a ZIP with score.gpif that reads back', () {
    final gpif = scoreToGpif(Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'e3:q g3 b3 e4',
    ));
    final gp = writeGpFromGpif(gpif);
    // ZIP local-file-header signature "PK\x03\x04".
    expect(gp.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
    expect(readGpifFromGp(gp), gpif);
  });

  test('a full .gp round-trips the score through the container', () {
    final source = Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'e3:q g3 b3 e4 | c4:h g4',
    );
    final back =
        scoreFromGpif(readGpifFromGp(writeGpFromGpif(scoreToGpif(source))));
    final names = back.measures
        .expand((m) => m.elements)
        .whereType<NoteElement>()
        .expand((n) => n.pitches)
        .map((p) => p.toString());
    expect(names, ['E3', 'G3', 'B3', 'E4', 'C4', 'G4']);
  });

  test('rejects non-zip bytes', () {
    expect(() => readGpifFromGp(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException);
  });
}

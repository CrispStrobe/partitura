import 'dart:io';

import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// Live tests: they invoke the real `bin/partitura.dart` as a subprocess and
/// assert on the files and output it produces.
void main() {
  late Directory tmp;
  late String samplePath;
  late String metadataPath;

  // Resolve the SMuFL metadata (a sibling package asset) once, absolutely.
  metadataPath =
      File('../partitura/assets/smufl/bravura_metadata.json').absolute.path;

  Future<ProcessResult> run(List<String> args) => Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/partitura.dart', ...args],
        workingDirectory: Directory.current.path,
      );

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('partitura_cli_test');
    samplePath = '${tmp.path}/sample.musicxml';
    File(samplePath).writeAsStringSync(scoreToMusicXml(Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'c4:q d4 e4 f4 | g4:h a4',
    )));
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('info summarizes the score', () async {
    final r = await run(['info', samplePath]);
    expect(r.exitCode, 0);
    expect(r.stdout, contains('meter:      4/4'));
    expect(r.stdout, contains('measures:   2'));
    expect(r.stdout, contains('elements:   6'));
  });

  test('timeline prints element onsets', () async {
    final r = await run(['timeline', samplePath]);
    expect(r.exitCode, 0);
    expect(r.stdout, contains('e0\t0/1\t1/4'));
    expect((r.stdout as String).trim().split('\n'), hasLength(7)); // header + 6
  });

  test('convert MusicXML → MIDI writes an SMF', () async {
    final out = '${tmp.path}/out.mid';
    final r = await run(['convert', samplePath, out]);
    expect(r.exitCode, 0);
    final bytes = File(out).readAsBytesSync();
    expect(bytes.sublist(0, 4), [0x4D, 0x54, 0x68, 0x64]); // "MThd"
  });

  test('MIDI round-trips back to a parseable MusicXML', () async {
    final mid = '${tmp.path}/rt.mid';
    final xml = '${tmp.path}/rt.musicxml';
    expect((await run(['convert', samplePath, mid])).exitCode, 0);
    expect((await run(['convert', mid, xml])).exitCode, 0);
    final score = scoreFromMusicXml(File(xml).readAsStringSync());
    final pitches = score.measures
        .expand((m) => m.elements)
        .whereType<NoteElement>()
        .expand((n) => n.pitches)
        .map((p) => p.toString());
    expect(pitches, containsAll(['C4', 'D4', 'E4', 'F4']));
  });

  test('render writes an SVG with the clef glyph', () async {
    final out = '${tmp.path}/out.svg';
    final r =
        await run(['render', samplePath, out, '--metadata', metadataPath]);
    expect(r.exitCode, 0);
    final svg = File(out).readAsStringSync();
    expect(svg, contains('<svg'));
    expect(svg, contains(smuflCodepoints['gClef']!));
    expect(svg, contains('@font-face')); // font embedded by default
  });

  test('render --tab writes a tab SVG', () async {
    final out = '${tmp.path}/tab.svg';
    final r = await run(
        ['render', samplePath, out, '--tab', '--metadata', metadataPath]);
    expect(r.exitCode, 0);
    final svg = File(out).readAsStringSync();
    expect(svg, contains(smuflCodepoints['6stringTabClef']!));
  });

  test('render --no-embed-font omits the font data', () async {
    final out = '${tmp.path}/light.svg';
    final r = await run([
      'render', samplePath, out, //
      '--no-embed-font', '--metadata', metadataPath,
    ]);
    expect(r.exitCode, 0);
    expect(File(out).readAsStringSync(), isNot(contains('@font-face')));
  });

  test('a missing input file fails with a clear error', () async {
    final r = await run(['info', '${tmp.path}/nope.musicxml']);
    expect(r.exitCode, 1);
    expect(r.stderr, contains('no such file'));
  });

  test('an unknown command shows usage and exits 64', () async {
    final r = await run(['frobnicate']);
    expect(r.exitCode, 64);
    expect(r.stderr, contains('Usage:'));
  });

  test('no arguments prints usage', () async {
    final r = await run([]);
    expect(r.exitCode, 64);
    expect(r.stdout, contains('music notation CLI'));
  });
}

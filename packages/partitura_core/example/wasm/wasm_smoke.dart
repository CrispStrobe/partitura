/// A WebAssembly compatibility smoke test for `partitura_core`.
///
/// It exercises the model, theory and every asset-free interchange codec, then
/// prints `WASM SMOKE OK`. It uses **no** `dart:io` / `dart:html` / `dart:ffi`
/// — only the web-safe core — so the same file both runs on the Dart VM
/// (`dart run`) and compiles + runs under `dart compile wasm` (dart2wasm /
/// WasmGC). See `build.sh` and `README.md`.
///
/// (Layout/SVG also work in WASM, but need a SMuFL metadata JSON passed in, so
/// they are left out of this asset-free smoke.)
library;

import 'package:partitura_core/partitura_core.dart';

void main() {
  final source = Score.simple(
    clef: Clef.treble,
    keySignature: const KeySignature(2),
    timeSignature: TimeSignature.fourFour,
    notes: 'c4:q d4 e4 f4 | g4:h a4:h ; c4:w',
    lyrics: 'do re mi fa sol la',
  );

  // Every codec funnels through the one Score, so each round-trips its subset.
  final musicXml = scoreFromMusicXml(scoreToMusicXml(source));
  final musescore = scoreFromMscx(scoreToMscx(source));
  final abc = scoreFromAbc(scoreToAbc(source));
  final midi = scoreFromMidi(scoreToMidi(source));
  final gpif = scoreFromGpif(scoreToGpif(source));

  // Theory: transposition preserves pitch count and spelling arithmetic.
  final up = source.transposedBy(const Interval(IntervalQuality.major, 3));

  // The (audio-free) playback timeline linearizes the score.
  final timeline = playbackTimeline(source);

  int noteCount(Score s) => s.measures
      .expand((m) => [...m.elements, ...m.voice2])
      .whereType<NoteElement>()
      .length;

  final checks = <String, bool>{
    'MusicXML round-trip': noteCount(musicXml) == noteCount(source),
    'MuseScore round-trip': noteCount(musescore) == noteCount(source),
    'ABC round-trip': noteCount(abc) >= 5,
    'MIDI round-trip': noteCount(midi) >= 5,
    'GPIF round-trip': noteCount(gpif) >= 1,
    'transpose keeps notes': noteCount(up) == noteCount(source),
    'timeline non-empty': timeline.isNotEmpty,
  };

  for (final entry in checks.entries) {
    print('${entry.value ? 'ok  ' : 'FAIL'} ${entry.key}');
  }

  if (checks.values.every((v) => v)) {
    print('WASM SMOKE OK (${checks.length} checks, '
        '${timeline.length} timeline events)');
  } else {
    print('WASM SMOKE FAILED');
    throw StateError('smoke checks failed');
  }
}

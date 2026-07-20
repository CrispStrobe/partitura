/// crisp_notation_cli — the `crisp_notation` command-line tool for the
/// crisp_notation music-notation libraries: inspect scores; convert between
/// MusicXML, MEI, Humdrum **kern, MIDI, MuseScore, GPIF and ABC (with
/// LilyPond and braille export); render to SVG/PNG; and run optical music
/// recognition (OMR).
///
/// Install the command with `dart pub global activate crisp_notation_cli`; the
/// entrypoint is `bin/crisp_notation.dart`. This library re-exports the
/// reusable OMR API (see `omr.dart`) so any Dart program can drive the pipeline.
library;

export 'omr.dart';

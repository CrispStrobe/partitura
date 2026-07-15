# Changelog

## 0.4.3 (2026-07-15)

- **First pub.dev release.** Install with
  `dart pub global activate crisp_notation_cli` to get the `crisp_notation`
  command (inspect, convert between MusicXML/MEI/kern/MIDI/MuseScore/GP/ABC with
  LilyPond & braille export, render to SVG/PNG, and OMR). Added a usage example.
  `render ... .png` needs the Flutter SDK; `omr` needs the native
  `libcrispembed` — SVG/convert/info are pure Dart.

## 0.4.1 (2026-07-14)

- **Sheet title rendering**: multi-staff `render` outputs include imported
  title/composer page text by default; pass `--no-title` to suppress it.

- **Offline `render` for the standalone binary** (hardening G1): the Bravura
  SMuFL metadata is now embedded in the CLI (DEFLATE-compressed + base64,
  ~136 KB, inflated at runtime via the existing pure-Dart `inflate`), so a
  released `crisp_notation` binary renders SVG without the repo checkout or a
  `--metadata` path. Resolution order is unchanged (`--metadata` → repo →
  embedded); when it falls back to the embedded copy there is no font file, so
  the SVG references the engraving font by name instead of inlining it.
  Regenerate the embed with `tool/embed_metadata.dart`.

- **Braille music output**: `convert --to brl` (or a `.brl` output path) writes
  Unicode braille-music notation via the new core `scoreToBraille`.

## 0.4.0 (2026-07-13)

First tagged release. The `crisp_notation` CLI: inspect scores; convert between
MusicXML / `.mxl` / MEI / `**kern` / MIDI / MuseScore / the `.gp` tablature
family / ABC (plus LilyPond export); render to SVG or PNG (notation or tab); and
optical music recognition (`omr`) routing three CrispEmbed engines
(Sheet Music Transformer, Polyphonic-TrOMR, Flova) through one command, with
full-page segmentation (`--page`) and model auto-download by name. The OMR
pipeline is also exposed as a reusable library (`package:crisp_notation_cli/omr.dart`).

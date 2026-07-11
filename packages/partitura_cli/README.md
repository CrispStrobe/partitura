# partitura_cli

Command-line tool for the [partitura](https://github.com/CrispStrobe/partitura)
music notation libraries: inspect, convert (MusicXML ↔ MIDI) and render scores
to SVG — all pure Dart.

## Usage

```
dart run partitura_cli:partitura <command> [arguments]
```

| Command | Purpose |
|---|---|
| `info <in>` | Summarize a score (clef, meter, sizes, timeline length) |
| `timeline <in> [--bpm N] [--no-expand]` | Print the playback timeline (repeats/jumps unfolded unless `--no-expand`) |
| `convert <in> <out>` | Convert between MusicXML and MIDI (formats inferred from the extensions) |
| `render <in> <out.svg> [options]` | Render to SVG (notation, or `--tab` for tablature) |

Input formats are inferred from file extensions — `.xml`/`.musicxml`,
`.mid`/`.midi`, and plain-text tab `.tab`/`.crd`/`.txt` — and can be overridden
with `--from` (`musicxml` / `midi` / `asciitab`). Output formats use `--to` or
the output extension (`.svg`, `.png`, `.mid`, `.musicxml`). Plain-text tab is a
lossy import; use `--tuning` to set its tuning, and `--infer-rhythm` to guess
note durations from the tab's horizontal spacing (otherwise all notes are
eighths).

### `render` options

| Option | Meaning |
|---|---|
| `--tab` | Render as guitar/bass tablature |
| `--tuning <std\|dropD\|bass>` | Tab tuning (default `std`) |
| `--staff-space <px>` | Pixels per staff space (default 12) |
| `--metadata <path>` | SMuFL font metadata JSON (auto-located in the repo otherwise) |
| `--no-embed-font` | Do not embed the engraving font in the SVG |

By default the engraving font is embedded via `@font-face`, so the SVG renders
anywhere.

**PNG**: give the output a `.png` extension. Rasterizing needs a font
rasterizer, so the tool delegates to the Flutter SDK (it runs
`flutter test tool/render_png.dart` in the `partitura` package, located
automatically). The Flutter SDK must be on `PATH`; SVG needs only the Dart SDK.

## Examples

```
dart run partitura_cli:partitura info song.musicxml
dart run partitura_cli:partitura convert song.musicxml song.mid
dart run partitura_cli:partitura render song.musicxml song.svg
dart run partitura_cli:partitura render song.musicxml song.png       # needs Flutter
dart run partitura_cli:partitura render riff.musicxml riff.svg --tab --tuning dropD
dart run partitura_cli:partitura render riff.tab riff.svg --tab      # import ASCII tab
```

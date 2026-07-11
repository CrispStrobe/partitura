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

Formats are inferred from file extensions (`.xml`/`.musicxml`, `.mid`/`.midi`,
`.svg`) and can be overridden with `--from` / `--to`.

### `render` options

| Option | Meaning |
|---|---|
| `--tab` | Render as guitar/bass tablature |
| `--tuning <std\|dropD\|bass>` | Tab tuning (default `std`) |
| `--staff-space <px>` | Pixels per staff space (default 12) |
| `--metadata <path>` | SMuFL font metadata JSON (auto-located in the repo otherwise) |
| `--no-embed-font` | Do not embed the engraving font in the SVG |

By default the engraving font is embedded via `@font-face`, so the SVG renders
anywhere. **PNG** output rides the Flutter renderer in the `partitura` package
and is not part of this pure-Dart tool.

## Examples

```
dart run partitura_cli:partitura info song.musicxml
dart run partitura_cli:partitura convert song.musicxml song.mid
dart run partitura_cli:partitura render song.musicxml song.svg
dart run partitura_cli:partitura render riff.musicxml riff.svg --tab --tuning dropD
```

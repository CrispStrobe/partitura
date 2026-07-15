# crisp_notation_cli examples

Install the `crisp_notation` command globally:

```sh
dart pub global activate crisp_notation_cli
```

Then (or with `dart run crisp_notation_cli:crisp_notation <command>` from a
checkout):

## Inspect a score

```sh
crisp_notation info song.musicxml
```

## Convert between formats

```sh
crisp_notation convert song.musicxml song.mid    # MusicXML -> MIDI
crisp_notation convert song.gp   song.musicxml    # Guitar Pro (.gp3/4/5/gp) -> MusicXML
crisp_notation convert song.mscz song.musicxml    # MuseScore -> MusicXML
crisp_notation convert song.mei  song.musicxml    # MEI -> MusicXML
crisp_notation convert song.krn  song.musicxml    # Humdrum **kern -> MusicXML
crisp_notation convert song.musicxml song.mxl     # -> zipped MusicXML
crisp_notation convert song.musicxml song.ly      # -> LilyPond
crisp_notation convert song.musicxml song.brl     # -> braille music
```

## Render to SVG or PNG

```sh
crisp_notation render song.musicxml song.svg
crisp_notation render song.musicxml song.png                 # PNG needs the Flutter SDK on PATH
crisp_notation render riff.musicxml riff.svg --tab --tuning dropD
crisp_notation render riff.tab riff.svg --tab                # import ASCII tab
```

## Optical music recognition (OMR)

```sh
crisp_notation omr scan.png score.musicxml --model smt-grandstaff.gguf
```

`omr` needs the native `libcrispembed` (the Sheet Music Transformer engine) at
runtime; `render ... .png` needs the Flutter SDK. SVG rendering and all
`convert`/`info` commands are pure Dart and need neither.

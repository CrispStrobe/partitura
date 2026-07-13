# partitura example

A small Flutter app demonstrating the [`partitura`](https://pub.dev/packages/partitura)
notation renderer. Two screens:

- **Gallery** (`lib/gallery.dart`) — a scrollable catalogue of rendered scores
  covering the feature set (clefs, accidentals, chords, beams, tuplets, ties,
  slurs, articulations, ornaments, dynamics, grace notes, key/time signatures,
  repeats, grand staff, tablature, …). Handy as a visual reference.
- **Interactive** (`lib/interactive.dart`) — a place-a-note demo built on
  `InteractiveStaff`: tap the staff to add a note (quantized to the nearest
  line/space), tap a note to select/remove it.

## Run

```sh
flutter run            # pick a device; works on macOS, web and iOS
```

The music font loads once at startup (`await Bravura.load()` in `main.dart`)
before the first frame.

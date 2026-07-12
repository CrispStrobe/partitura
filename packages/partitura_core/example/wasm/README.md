# partitura_core → WebAssembly

`partitura_core` is pure Dart with **no** `dart:io` / `dart:html` / `dart:ffi` /
`dart:isolate` (only `dart:typed_data`), so the whole music-theory, layout and
interchange core compiles to and runs as a [WasmGC](https://webassembly.org/)
module via `dart compile wasm` (dart2wasm) — in the browser or any WASM host.

## Build

```sh
./build.sh                 # dart compile wasm → build/*.wasm + *.mjs loaders
```

## Run

**Under Node** (proves the codecs execute as WASM, not just compile):

```sh
node run_node.mjs
# ok   MusicXML round-trip
# ok   MuseScore round-trip
# …
# WASM SMOKE OK (7 checks, 7 timeline events)
```

**In the browser** — serve this directory over http (module + wasm fetch need
it) and open `index.html`:

```sh
python3 -m http.server 8000   # then open http://localhost:8000/
```

The page calls the Dart functions exposed on `globalThis` by `main.dart`:

```js
partituraConvert(notes, "musicxml" | "mscx" | "abc")  // -> String
partituraInfo(notes)                                   // -> String summary
```

where `notes` is a `Score.simple` DSL string (e.g. `"c4:q d4 e4 f4 | g4:h a4"`).

## Files

| File | Purpose |
|---|---|
| `wasm_smoke.dart` | Asset-free `main()` exercising every codec; runs on the VM *and* as WASM |
| `main.dart` | Browser entry: `dart:js_interop` exports to JavaScript |
| `run_node.mjs` | Node runner for the smoke module |
| `index.html` | In-browser conversion demo |
| `build.sh` | Compiles both entry points |

## Scope notes

- **Text codecs** (MusicXML, MuseScore `.mscx`, ABC, MIDI, GPIF) and the theory
  + layout engine are asset-free and web-safe. Layout/SVG additionally need a
  SMuFL metadata JSON passed in at runtime, so they are omitted from this
  self-contained demo.
- **Container formats that need `dart:io`** — the `.gp`/`.gpx`/`.mscz` ZIP and
  BCFS wrappers — live in `partitura_cli`, not the core, so they are the one
  part of the interchange surface not reachable from WASM as-is. The `.mscx`
  and `.gpif` *XML* codecs (the payloads inside those containers) are web-safe;
  only the archive unwrapping is host-side.
- For the **Flutter renderer** (`package:partitura`), use Flutter web's WasmGC /
  `skwasm` renderer — no code changes needed.

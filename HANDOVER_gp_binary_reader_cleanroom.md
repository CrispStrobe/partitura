# Clean-room task: reimplement the Guitar Pro `.gp3`/`.gp4`/`.gp5` binary reader

You are working in the Dart/Flutter monorepo at `/Users/christianstrobele/code/partitura` (MIT-licensed). Do a **clean-room reimplementation** of one file for legal reasons. Read this whole brief first. This is a large, precise task — budget for it and work incrementally.

## Why (legal)

`packages/partitura_core/lib/src/gp/gp_binary_reader.dart` (~1040 lines) documents itself as *"a from-scratch byte/bit-exact reader — ported from the reference layout in PyGuitarPro."* **PyGuitarPro is LGPL-3.0.** A literal port makes this file a derivative work, incompatible with MIT. Produce a **new, independently-authored** implementation of the same public formats so provenance is clean. Read `packages/partitura_core/lib/src/gp/CLEANROOM.md` for the overall context.

## HARD RULES (non-negotiable)

1. **Do NOT read, open, or search for PyGuitarPro's source** (the Python `guitarpro` package) — not on disk, not on the web, not from memory.
2. **Do NOT read the existing `gp_binary_reader.dart` body** — treat it as tainted. You may look ONLY at its public function *signatures* to keep the API: `Score gp5ToScore(Uint8List bytes, {int trackIndex = 0})`, `Score gp4ToScore(...)`, `Score gp3ToScore(...)`. Do not copy its structure, naming, comments, or decomposition. Write original code.
3. You MAY and SHOULD use: the acceptance tests (they state exactly what each fixture must decode to), hexdump/byte analysis of the fixture files, and **independent public documentation** of the `.gp3/.gp4/.gp5` format via web search (the format is community-documented — e.g. TuxGuitar's Java reader notes, DGuitar, the "Guitar Pro format" reverse-engineering write-ups, kguitar). A binary file format's byte layout is factual, not copyrightable — implement it; do not copy anyone's code.

## What to build

Reimplement `packages/partitura_core/lib/src/gp/gp_binary_reader.dart`, pure Dart (web-safe: only `dart:typed_data`, and the repo's own model/theory imports — NOT `dart:io`). Public API (used by the tests):
- `Score gp5ToScore(Uint8List bytes, {int trackIndex = 0})` — parse a `.gp5` (version string contains `v5.`).
- `Score gp4ToScore(...)`, `Score gp3ToScore(...)` — the `.gp4`/`.gp3` deltas.

Read the repo's model first: `packages/partitura_core/lib/src/model/element.dart`, `measure.dart`, `score.dart`, and theory (`pitch.dart`, `duration.dart`, `time_signature.dart`, `clef.dart`). Notes decode **string+fret → pitch** via each track's tuning. Populate techniques as they already exist in the model, keyed by note id: `Score.bends` (`Bend`), slides → `Score.glissandos`, hammer-on/pull-off → `Score.slurs`, vibrato → `Score.vibratos`, palm-mute → `Score.palmMutes`, let-ring → `Score.letRings`, dead / harmonic notes → `Score.tabNoteMarks` (with `TabNoteStyle`: `dead`, `harmonic`, `artificialHarmonic`, `pinchHarmonic`). Non-musical blocks (score info, notices, lyrics, page setup, RSE, mix table, effects you don't model) must be parsed only far enough to **stay byte-aligned**, then discarded.

Format shape (verify all specifics against docs + the fixtures): a 30-byte version string; length-prefixed strings for score info; lyrics; (5.10+) an RSE master block; page setup; tempo/key; per-track data incl. tuning; a master-bar table (time signatures — only where they change — repeats); then, per track/measure/beat: beats with a duration code (whole=−2 … 64th, plus dot/tuplet flags), a rest flag, a notes-present bitmask over 7 strings, and per-note flags/effects. `.gp3` is one voice per measure with fewer effect flags and no RSE/page-setup; `.gp4` adds per-note effects incl. artificial/pinch harmonics; `.gp5` adds a second voice, RSE, and extra beat/note structures. Derive the exact byte offsets from the docs and confirm with hexdumps.

## CRITICAL correctness requirements

- **Header/measure-count parsing must be exact.** A previous attempt misread the header and computed a wrong measure count (e.g. `mc=32` for `effects.gp3`) — get the string/notice/lyric/mixtable skips byte-exact so the master-bar count is right.
- **Verify against EVERY fixture, not a happy path** — see the acceptance tests below; they cover notes/durations/tuning, chords, bends, slides, hammer-ons, harmonics (natural/artificial/pinch), dead notes, vibrato, palm-mute/let-ring, across `.gp3`/`.gp4`/`.gp5`.
- **No hangs / no silent truncation.** Reading past the buffer must throw a `FormatException`, not spin or return zeros.

## Acceptance criteria (ground truth — iterate until GREEN)

Every one must pass:
- `cd packages/partitura_core && dart test test/gp5_test.dart` — header rejection + a hand-built minimal `.gp5`.
- `cd packages/partitura_cli && dart test test/gp_contract_test.dart` — **exact** decoded content (string+fret→pitch, durations, chord voicings, measures, time signatures) for `notes.gp3`/`.gp4`, `chords.gp5`, `bends.gp5` (and the `.gpx`/`.gp` paths, which you do NOT change).
- `cd packages/partitura_cli && dart test test/gp_fixtures_test.dart` — technique/element counts across `.gp3`/`.gp4`/`.gp5` (notes, bends×3, slides, hammer×6 slurs, harmonics split, dead×4, vibrato×4, palm-mute/let-ring spans).
- `cd packages/partitura_core && dart test` — full core suite, nothing regresses.
- `cd packages/partitura_cli && dart test` — full CLI suite.
- `dart analyze packages/partitura_core` — zero issues; `dart format` clean.

Fixtures live in `packages/partitura_cli/test/data/gp/` (e.g. `notes.gp3`, `chords.gp5`, `bends.gp5`, `hammer.gp4`, `harmonics.gp4`, `harmonic-types.gp4`, `dead.gp3`, `vibrato.gp5`, `effects.gp5`, …). Note the tests that consume the binary readers import them via `partitura_cli/src/gp_container.dart`'s `gp3ToScore`/`gp4ToScore`/`gp5ToScore` (re-exported from core). Hexdump fixtures to resolve anything the docs leave ambiguous.

## Method

1. Read the acceptance tests to learn the exact expected output for each fixture.
2. Web-search independent `.gp3/.gp4/.gp5` format docs; write yourself a byte-layout cheat sheet.
3. Implement `.gp5` first; get `gp5_test.dart` + the `.gp5` parts of the contract/fixtures tests green.
4. Derive `.gp4` then `.gp3` as documented deltas; green their fixtures.
5. Run the full core + CLI suites; fix regressions.
6. When all green + analyze/format clean: write an original file-header doc comment citing the **public format documentation** and the fixtures/corpus as validation, and DELETE the "ported from PyGuitarPro" language. Commit on a branch.

Report at the end: the passing test summaries (paste them — never claim success without running the suites), the independent sources you used (for auditability), and any format quirk you reverse-engineered from bytes. If something is still failing, say exactly what.

# Clean-room task: reimplement the Guitar Pro `.gpx` container decompressor

You are working in the Dart/Flutter monorepo at `/Users/christianstrobele/code/partitura` (MIT-licensed). Do a **clean-room reimplementation** of one file for legal reasons. Read this whole brief first.

## Why (legal)

`packages/partitura_cli/lib/src/gp_container.dart` contains code that documents itself as *"Ported from the algorithm in alphaTab's `GpxFileSystem`"* and a bit reader that *"matches alphaTab's `BitReader`"*. **alphaTab is MPL-2.0** (file-level copyleft). A literal port makes those parts a derivative work, inconsistent with distributing this file as MIT. Produce a **new, independently-authored** implementation of the same public format so provenance is clean. Also read `packages/partitura_core/lib/src/gp/CLEANROOM.md` for the overall context.

## HARD RULES (non-negotiable)

1. **Do NOT read, open, or search for alphaTab's source** (`CoderLine/alphaTab` — its `GpxFileSystem`, `BitReader`, `BitInput`, etc.) — not on disk, not on the web, not from memory.
2. **Do NOT read the existing `gp_container.dart` implementation bodies** — treat them as tainted. You may look ONLY at the top-level *function signatures* to keep the API: `String readGpifFromGpx(Uint8List)`, `String readGpifFromGp(Uint8List)`, `Uint8List writeGpFromGpif(String)`. Do not read the `_bcfzDecompress` / `_readBcfs` / `_BitReader` bodies. Write your own structure, names, comments.
3. You MAY and SHOULD use: the acceptance tests, hexdump/byte analysis of the fixture files, and **independent public documentation** of the GPX / BCFZ / BCFS format found via web search (the format was community-reverse-engineered; e.g. the standalone Rust "rust-gpx-reader", TuxGuitar, DGuitar). A file format's byte/bit layout is factual, not copyrightable — implement it; do not copy anyone's code.

## What to build

Rewrite `packages/partitura_cli/lib/src/gp_container.dart`, keeping the same public API the tests use:
- `String readGpifFromGpx(Uint8List bytes)` — the tainted part. A `.gpx` (Guitar Pro 6) starts with a 4-byte magic `BCFZ` (bit-compressed) or `BCFS` (raw sector filesystem). For `BCFZ`, bit-decompress to a `BCFS` image; then read the `BCFS` filesystem's entries and return the one whose name ends in `.gpif` as a UTF-8 string. Throw `FormatException` otherwise.
- `String readGpifFromGp(Uint8List bytes)` — a `.gp` (v7/8) is a **standard ZIP**; return the `.gpif` member. (Not tainted — standard ZIP — but you're rewriting the whole file, so implement standard ZIP reading yourself: end-of-central-directory + central directory, stored=method 0, deflate=method 8 via `dart:io` `ZLibCodec(raw: true)`.)
- `Uint8List writeGpFromGpif(String gpif)` — pack a minimal ZIP holding `Content/score.gpif` that reads back.

Dependencies: only `dart:io`, `dart:convert`, `dart:typed_data`.

## CRITICAL correctness requirements (a previous attempt FAILED here)

A prior rewrite passed `chords.gpx` but **hung forever** on `slides.gpx` — its BCFZ decoder under-produced bytes, exhausted the bitstream, then spun because reading past end-of-data silently returned `0` and the loop made no progress.

- Your BCFZ decompressor **must never infinite-loop**. Reading past the end of the bit source must *fail loudly* (throw), or the outer loop must detect no-progress-with-exhausted-input and stop. Add an explicit guard.
- You **must verify against ALL `.gpx` fixtures, not just one** (`chords.gpx` AND `slides.gpx`), and confirm each finishes fast.
- Get the bit order right: BCFZ reads a control bit, then either a raw run (a small bit-count then that many bytes) or a back-reference (a 4-bit word width `w`, then a `w`-bit distance and a `w`-bit length, copying `min(length, distance)` bytes from `distance` behind the tail). The exact bit endianness for each field must match the format docs and the fixtures — derive it and prove it with the tests.

## Acceptance criteria (ground truth — iterate until GREEN, no hangs)

Run these from the repo root; every one must pass and terminate quickly:
- `cd packages/partitura_cli && dart test test/gp_container_test.dart` — direct `.gpx` contracts: `chords.gpx` and `slides.gpx` each extract a well-formed GPIF (`<?xml…><GPIF><GPRevision>11686…`; `slides.gpx` → 5 glissandos through the parser), plus the `.gp` ZIP round-trips.
- `cd packages/partitura_cli && dart test test/gp_contract_test.dart` — `chords.gpx` exact decoded content.
- `cd packages/partitura_cli && dart test test/gp_fixtures_test.dart` — the `.gpx` fixtures.
- `cd packages/partitura_cli && dart test` — full CLI suite, nothing regresses.
- `dart analyze packages/partitura_cli` — zero issues; `dart format` clean.

Fixtures: `packages/partitura_cli/test/data/gp/chords.gpx`, `slides.gpx` (and `.gp` files). Hexdump them to nail the bit order and sector layout (0x1000-byte sectors; a file-header sector's first 32-bit word is `2`, name at +0x04, size at +0x8C, a NUL-terminated list of 32-bit sector indices from +0x94).

## Finish

When all green + analyze/format clean: rewrite the file's doc comments to cite the **public GPX format documentation** and the fixtures as validation, and DELETE the "ported from alphaTab" / "matches alphaTab's BitReader" language. Then commit on a branch and report: the passing test summaries (paste them — never claim success without running the suites and confirming no hang), the independent sources you used (for auditability), and any bit-order/sector quirk you reverse-engineered.

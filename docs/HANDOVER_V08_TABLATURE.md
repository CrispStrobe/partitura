# Handover — v0.8 guitar tablature

A self-contained brief for the next session to implement **guitar tablature**
in partitura. Read this top to bottom before touching code.

## Mission

The repo owner asked for guitar tab (2026-07-11). Scope decision already
made with them: **full techniques** (bends, slides, hammer-on/pull-off,
vibrato, palm mute, custom tunings) — **not** a fret-numbers-only MVP. It is
its own milestone **v0.8**, sequenced *after* v0.7.2 (which is now complete).
The plan lives in `docs/ROADMAP.md` (v0.8 section) and `PLAN.md`.

Tablature was on the HANDOVER "out until a consumer asks" list. The consumer
asked, so **v0.8 must amend the contract**: lift the "tablature out" clause
in `docs/CONTRACT.md` (the *Permanently out* / scope wording) and note it in
`HANDOVER_PARTITURA.md`. Do this in the 0.8.0 slice.

## Why tab is a milestone, not a decoration

Tab is a **parallel notation mode**, not a mark on the existing staff. Two
core assumptions in the engine are 5-line-staff-specific and must be
generalized first:

1. **Coordinate system.** `docs/CONTRACT.md` §2 and
   `packages/partitura_core/lib/src/layout/score_layout.dart` fix
   `y = (8 − staffPosition) / 2` over **exactly 5 lines** (y = 0..4). Tab
   needs an **N-line staff** (6 for guitar, 4 for bass) where each line is a
   *string*, spacing is wider, and the mark on a line is a **fret number**,
   not a notehead. Grep the engine for the literal `4` / `8` in y math and
   staff-line loops (`for (line = 0; line < 5; ...)` in `layout_engine.dart`
   `build()`), and the `_yOf(position)` helper.
2. **Pitch → position is diatonic/clef-based.** `Pitch.staffPosition(clef)`
   assumes a clef. Tab positions a note by **(string, fret)**, derived from a
   `Tuning` (the open-string pitches). You need a new model axis + a
   pitch→(string,fret) assignment (choose the string whose open pitch ≤ the
   note and yields the lowest playable fret, with per-note override).

This overlaps roadmap item **0.7.3 (generalize GrandStaff from 2 → N
staves)** — real tab is usually shown *paired with* a notation staff, so do
0.7.3's N-staff work as part of / before 0.8.2.

## Current state (what you inherit)

- **v0.6 complete**, **v0.7.1 + v0.7.2 complete** (this session). Package
  version is deliberately `0.4.0-dev.1` (the `0.x.y` labels are internal
  feature-parity milestones, NOT the pub version — do not "fix" this).
- Tests: **partitura_core 559**, **partitura 123** (golden scenes through
  49). All green. Gates: `dart format`, `dart analyze` (zero issues),
  `flutter analyze`, `flutter test`.
- Recent commits `9097730`..`bf21b58` on `main` show the exact per-feature
  pattern to copy (navigation marks, fingerings, arpeggio, glissando,
  tremolo, pedal). **Read one of those diffs before starting** — e.g.
  `git show bf21b58` (pedal) is the cleanest Score-level-span example;
  `git show c68edd5` (tremolo) is the cleanest note-attached example.

## The established per-feature pipeline (copy this exactly)

Every partitura feature ships the full pipeline. The touch points:

1. **Model** — `packages/partitura_core/lib/src/model/element.dart` (note-
   attached: enum/field on `NoteElement`, update ctor + `NoteElement.note` +
   `==` + `hashCode` + `toString`) OR a new span class + a `Score.<list>`
   field in `model/score.dart` (field, ctor, `==`, `hashCode`).
2. **Score plumbing** — if you added a `Score` field: also add it to the
   `transposedBy` return (`model/score.dart` ~L560) and the `multi_system.dart`
   per-line rebuild (filter spans whose ids are in the system). If note-
   attached: preserve it in the MusicXML reader's **chord-merge** rebuild
   (`musicxml_reader.dart`, the `<chord/>` branch) and in `transposedBy`'s
   `moveElement`.
3. **SMuFL glyphs** — names + helper in
   `partitura_core/lib/src/smufl/glyph_names.dart`; codepoints in
   `partitura/lib/src/rendering/smufl_glyphs.dart`. **Verify the glyph exists
   in Bravura first** (see gotcha below).
4. **Layout** — a `_layoutXxx()` pass in `layout_engine.dart` (or draw inside
   `_layoutNote` if it needs stem geometry, like tremolo). Call it from the
   measure loop / the post-loop span section. Use `_addGlyph` / `_addLine`
   (they update `_ink` bounds and optionally an element hit region).
5. **DSL** (optional) — `Score.simple` in `model/score.dart`. Note the
   trailing-marker chars are nearly exhausted; most v0.7.2 features are
   **model-only** (no DSL), which is an accepted convention (dynamics,
   hairpins, ottavas, arpeggio, glissando, tremolo, pedal are all model-only).
   Tab will likely need its own DSL or a builder API — design it.
6. **MusicXML** — reader (`musicxml_reader.dart`) + writer
   (`musicxml_writer.dart`), round-trip tested. Spans mirror the slur/wedge
   number-pairing pattern; note-attached marks go in `<notations>`.
7. **Tests** — a `*_test.dart` in `partitura_core/test/` (model value
   semantics, layout assertions on emitted primitives, MusicXML round-trip,
   transpose). ~8–13 tests per feature.
8. **Golden + gallery** — a numbered scene in
   `partitura/test/golden_test.dart` (regenerate with
   `flutter test --update-goldens --plain-name '<scene name>'`) and an entry
   in `partitura/example/lib/gallery.dart`. **Always Read the generated PNG
   to visually verify** — several real bugs this session were caught only by
   looking at the image.
9. **Docs** — `docs/CONTRACT.md` (model bullet + the layout-capabilities
   paragraph), both `CHANGELOG.md` files, and check the item off in `PLAN.md`
   + `docs/ROADMAP.md`.
10. **Commit + push** per feature with the repo's message style
    (`0.8.x: <feature>` + the `Co-Authored-By` trailer). Trunk-based on
    `main` — no PR branch (matches repo history).

## Gotchas that will bite you

- **Editing SMuFL codepoints:** `smufl_glyphs.dart` stores codepoints as
  literal escape text (`''`, 6 ASCII chars). They render **invisibly**
  in tool echoes, so `Edit` string-matching on those lines is flaky. After
  any edit, verify with a python one-liner:
  `python3 -c "import re; [print(m.group(1),repr(m.group(2))) for l in open('.../smufl_glyphs.dart') for m in [re.search(r\"'(\w+)':\s*'([^']*)'\",l)] if m]"`.
- **Verify a glyph is in Bravura before using it** — `bBoxOf` **throws** on a
  missing name. Check `packages/partitura/assets/smufl/bravura_metadata.json`
  `glyphBBoxes` (python). Tab glyphs you'll want: `6stringTabClef` (E06D),
  `4stringTabClef` (E06E), `stringsDownBow`/`stringsUpBow`, `guitarString0`…,
  `wiggleVIbratoWide`… (confirm exact names against the metadata).
- **SMuFL bbox is y-up; layout y is down.** `_addGlyph` already flips. When
  hand-placing, remember bottom-align vs top-align (this caused a real
  segno/coda bug this session — big glyphs top-aligned dip into the staff).
- **Beamed vs unbeamed stems:** beamed notes defer stem geometry
  (`_BeamedNote`), so per-note stem drawing (like tremolo) only has the tip
  for unbeamed notes. Tab has no stems by default (or optional rhythm stems
  below), so plan its own stem model.
- **`multi_system.dart` currently does NOT carry `ottavas`** into per-line
  scores (pre-existing gap). If tab rides on multi-system, thread every span
  through.

## Sub-slices (do in order, one commit each)

- **0.8.0 Design + contract amendment.** Write `docs/DESIGN.md` notes for:
  N-line staff generalization (parameterize the line count + spacing in
  `LayoutSettings` and the `build()` staff-line loop and `_yOf`), a `Tuning`
  value type (list of open-string `Pitch`es; presets), pitch→(string,fret)
  assignment with per-note override, the tab-clef glyphs, and the DSL/builder
  shape. Amend the contract. No rendering yet — just the model + the
  generalized coordinate system + unit tests that a 6-line staff lays its
  lines out correctly.
- **0.8.1 Core tab staff.** 6-line (configurable) staff, tab clef, fret
  numbers instead of noteheads (reuse the fingering-digit glyph approach but
  positioned ON the string line), optional rhythm stems below. Golden.
- **0.8.2 Tab paired with notation.** A notation staff + its tab in one
  system. Requires 0.7.3 (N-staff systems) — do that first if not yet done.
- **0.8.3 Techniques.** Bends (with release, multi-point), slides,
  hammer-on/pull-off, vibrato, palm mute. MusicXML `<bend>` / `<slide>` /
  `<technical>` round-trip. Reuse the span infra (glissando/pedal) for the
  two-note ones.
- **0.8.4 Tunings.** Presets (standard, drop-D, DADGAD, bass 4-string) +
  custom.

## Key file map

- Model: `partitura_core/lib/src/model/{element,measure,score}.dart`
- Layout: `partitura_core/lib/src/layout/{layout_engine,score_layout,layout_settings,multi_system,grand_staff}.dart`
- Theory: `partitura_core/lib/src/theory/{pitch,clef,interval}.dart` (add `Tuning` here)
- SMuFL: `partitura_core/lib/src/smufl/glyph_names.dart`, `partitura/lib/src/rendering/smufl_glyphs.dart`, `partitura/assets/smufl/bravura_metadata.json`
- Paint: `partitura/lib/src/rendering/{layout_painter,staff_view}.dart`
- Interchange: `partitura_core/lib/src/musicxml/{musicxml_reader,musicxml_writer}.dart`
- Tests/goldens: `partitura_core/test/`, `partitura/test/golden_test.dart`, `partitura/test/goldens/`
- Gallery: `partitura/example/lib/gallery.dart`
- Trackers: `PLAN.md`, `docs/ROADMAP.md`, `docs/CONTRACT.md`, `docs/DESIGN.md`

## Gates (must be green before every commit)

```
cd packages/partitura_core && dart analyze && dart test
cd packages/partitura && flutter analyze && flutter test
dart format <changed dirs>
```
And **Read each new golden PNG** to confirm it looks right.

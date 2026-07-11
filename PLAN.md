# partitura — implementation plan (living tracker)

**Status (2026-07-11):** v0.1–v0.6 complete (the original v0.2 parity
plan — see [docs/ROADMAP.md](docs/ROADMAP.md) Part II — shipped in full).
501 core + 117 widget + 5 example tests, 43 golden scenes + hero,
on-device integration test — all green. **Now in progress: v0.7
"long-tail parity"** — the features the three incumbents carry that the
v0.2 table never enumerated, re-derived 2026-07-11 against VexFlow ~5.0 /
OSMD ~1.9 / abcjs ~6.6 (analysis + tiers in
[docs/ROADMAP.md](docs/ROADMAP.md) Part I). "Feature-complete" against the
old table is *not* parity with the incumbents; v0.7 closes the tail.

Working checklist for the feature-parity plan. Analysis and per-item
design notes live in [docs/ROADMAP.md](docs/ROADMAP.md); check items off
here as they land. Every item ships the full pipeline: model + layout +
unit tests in `partitura_core`, painting + goldens + interaction tests in
`partitura`, gallery entry where visual, CONTRACT/CHANGELOG updates,
gates green (`dart format`, analyze zero issues, all tests), push.

## Done

- [x] v0.1 — M1..M5 per HANDOVER.md (theory, layout rules 1–14,
      StaffView, InteractiveStaff, release polish)
- [x] v0.2 — alto + tenor clefs

## v0.3 — notation depth (single staff, single voice)

- [x] 0.3.1 Ties (`tieToNext`, `CurvePrimitive` foundation, DSL `~`)
- [x] 0.3.2 Slurs (`Slur(startId, endId)` spans, curve clearance)
- [x] 0.3.3 Tuplets (measure-level spans, ratio bracket + digits,
      exact `Fraction` math, beaming inside)
- [x] 0.3.4 Articulations (staccato, tenuto, accent, marcato, fermata)
- [x] 0.3.5 Dynamics (pp…ff glyphs) + hairpins (cresc/dim wedges)
- [x] 0.3.6 Grace notes (scaled glyphs, acciaccatura slash)
- [x] 0.3.7 32nd/64th notes + breve (flags, multi-level beams, DSL
      letters `t`, `x`, `b`)
- [x] 0.3.8 Mid-score clef/key/time changes (courtesy naturals),
      repeat barlines, voltas

## v0.4 — structure

- [x] 0.4.1 Two voices per staff (forced stems, rest displacement,
      cross-voice seconds)
- [x] 0.4.2 Grand staff / systems (brace, connected barlines)
- [x] 0.4.3 Line breaking + justification (`layoutSystems` +
      `MultiSystemView`)
- [x] 0.4.4 Lyrics (syllables, hyphens, extenders; `TextPrimitive`)
- [x] 0.4.5 Chord symbols / text annotations (covers rehearsal + tempo
      marks; `Annotation` above the staff)

## v0.5 — interchange & time

- [x] 0.5.1 MusicXML import (subset covering v0.3/0.4;
      dependency-free XML reader)
- [x] 0.5.2 MusicXML export (round-trip tested)
- [x] 0.5.3 Playback-cursor API (`playbackTimeline`/`soundingAt`/
      `secondsFor`; **no audio, ever** — apps bring their own synth)
- [x] 0.5.4 `Score.transposedBy(interval)` (pitches, key
      signatures incl. mid-score changes, enharmonic wrapping)

## v0.6 — engraving polish

- [x] 0.6.1 Accidental stacking rules for dense chords (zigzag
      column packing)
- [x] 0.6.2 Ornaments (trill, short trill, mordent, turn; DSL
      `% \$ & ?`, MusicXML round trip)
- [x] 0.6.3 Multi-measure rests (`!mrest=N`, H-bar + count,
      playback advances N bars, MusicXML measure-style)
- [x] 0.6.4 Octave clefs (treble8va/treble8vb/bass8vb) + ottava
      brackets (`Ottava` spans, dashed bracket, octave-shifted layout)

## v0.7 — long-tail parity (in progress)

Closes the incumbents' long tail (full analysis + tiers:
[docs/ROADMAP.md](docs/ROADMAP.md) Part I). Breadth, not depth — each item
reuses the existing model → layout → paint pipeline.

- [x] 0.7.1 Navigation marks (Coda, Segno, D.C., D.S. + al Coda/al Fine,
      Fine; measure-level `NavigationMark`, shared-baseline glyphs/words
      above staff, DSL `!nav=`, MusicXML round trip; golden 44 + gallery.
      Playback jump execution deferred)
- [ ] 0.7.2 Piano / technical layer (pedal marks, fingering numbers,
      tremolo, arpeggio, glissando)
- [ ] 0.7.3 N-staff systems (generalize `GrandStaff` 2 → N, brackets +
      nested part groups; unblocks SATB/organ/orchestral)
- [ ] 0.7.4 Pedagogy breadth (model note-coloring incl. Boomwhacker, cue
      notes, notehead shapes, more articulations + dynamics, multiple
      lyric verses, rendered measure numbers, cautionary accidentals)
- [ ] 0.7.5 MIDI export off the playback timeline (no audio; contract-safe)
- [ ] 0.7.6 Output & ingest, demand-driven (PNG/SVG export, ABC import,
      alternate SMuFL fonts)

## Permanently out (per HANDOVER contract / until explicitly requested)

- Audio synthesis or playback of any kind
- Tablature, percussion notation, guitar bends, microtonal accidentals

# partitura — design log

Running log of non-obvious decisions and their rationale. Append as you go;
terse is fine. See HANDOVER.md §6.

## Pre-seeded decisions (scaffold, 2026-07-10)

- **Naming**: the project was scaffolded as "neume" and renamed to
  "partitura" the same day (maintainer decision). HANDOVER.md still says
  neume; HANDOVER_PARTITURA.md is the binding amendment.
- **Coordinate system**: layout works in *staff spaces* (1 space = gap between
  adjacent staff lines), origin at the intersection of the staff's top line
  and left edge, y grows downward. Rendering converts to px with one scale
  factor. SMuFL convention: font size = 4 × staff space.
- **Staff position convention**: `Pitch.staffPosition(clef)` returns 0 for the
  bottom line, +1 per line/space upward (treble: E4 = 0; bass: G2 = 0).
- **Two packages, not three**: layout stays in `partitura_core` (pure Dart,
  logic testable without Flutter); a separate layout package added friction
  without a consumer that wants layout-but-not-theory.
- **No dependencies**: theory core is small at our scope; owning it keeps the
  MIT story clean and lets the model be shaped for pedagogy
  (`Key.triadFor(HarmonicFunction)` etc.).

## M1 — theory core (2026-07-10)

- **`showAccidental` is `bool?`, not `bool`**: HANDOVER.md §4.1 declares
  `final bool showAccidental` but describes tri-state semantics
  ("force/hide courtesy accidental" *overriding* an automatic rule). A plain
  bool cannot express "automatic". Resolution: `bool?` — `null` = automatic
  (key signature + earlier accidentals in the measure decide), `true` =
  force, `false` = hide.
- **Minor-key dominant is a major triad** (`Key.triadFor`): follows the
  harmonic-minor convention of functional harmony (A minor: t=Am, s=Dm,
  D=E major), which is what cadence pedagogy (T–S–D–T) teaches. Documented
  on the method.
- **`Fraction` is public**: games need exact duration sums ("fill the
  measure"); hiding it would force consumers to reimplement rational math.
  `NoteDuration.fraction` keeps the contract's `(int, int)` record shape;
  `toFraction()` bridges to arithmetic.
- **DSL grammar** (`Score.simple`): whitespace-separated tokens, `|` splits
  measures, `pitch[+pitch…][:dur]`, `r[:dur]` for rests, durations `w h q e
  s` with up to two dots, sticky duration (LilyPond-style; initial default
  quarter). Chords use `+` instead of parentheses so tokenizing stays a
  whitespace split. `n` = explicit natural, which also forces
  `showAccidental: true`. Elements auto-get ids `e0, e1, …` in reading
  order so games can address them without building the tree by hand.
- **`Interval.between` is order-insensitive** and caps at one octave;
  quality is recovered from spelling (C–F♯ = A4, C–G♭ = d5), so
  ear-training games can distinguish enharmonic intervals.
- **`Clef.pitchAt(staffPosition)`** added as the inverse of
  `Pitch.staffPosition` — the interaction layer's `StaffTarget.pitchFor`
  and "tap to place a note" need position→pitch, and round-trip tests pin
  the two conventions together.
- **Transposition beyond double accidentals throws `ArgumentError`** (e.g.
  F𝄫 down a major third). Alternatives (silent enharmonic respell) would
  make theory answers wrong; games stay in sane ranges anyway.

## M2 — layout engine (2026-07-10)

- **Geometry types**: HANDOVER.md's pseudo-code uses `Offset`, but
  `partitura_core` cannot depend on Flutter. We use `dart:math`'s
  `Point<double>` / `Rectangle<double>` (SDK-only). Deliberately NOT a
  custom class named `Offset`/`Rect` — that would collide with `dart:ui`
  in every consumer that imports both Flutter and partitura.
- **y of a staff position**: `y = (8 - p) / 2` (origin top line, y down).
- **Metadata flow**: core cannot load assets; the consumer decodes
  `bravura_metadata.json` and passes it via
  `SmuflMetadata.fromJson` → `LayoutSettings(metadata: …)`. Core tests read
  the file from `../partitura/assets/` directly. Glyph metrics (bboxes,
  stem anchors) come from the font metadata, not hardcoded values; SMuFL
  bbox/anchor y-up coordinates are flipped at the single point of entry.
- **Spacing formula** (rule 13): a note/rest advances
  `spacingBase + spacingPerLog2 · (4 + log2(duration))` staff spaces from
  its notehead column (sixteenth = `spacingBase` = 1.8, each doubling adds
  0.75), but never closer than `minNoteGap` after the element's ink.
  `log2` of the dot factors is a 3-entry constant table, keeping layout
  bit-for-bit deterministic (rule 14) without transcendental calls.
- **Beam grouping** (rule 7): groups form per `1/beatUnit` window, never
  across rests or windows. In even-numerator x/4 meters, adjacent
  all-eighth groups in the same half-measure merge — this yields the
  contract's "8 eighths in 4/4 = 2 beams" while 3/4 stays per-beat.
  Compound 6/8 grouping (3+3) is out of scope v0.1 ("simple-meter grouping
  only"): in x/8 meters each eighth is its own window, so eighths get
  flags. Unmetered scores group per quarter window.
- **Beam geometry**: slant = `clamp((refY_last − refY_first)/2, ±1)`,
  intercept chosen so every stem keeps ≥ default length (min/max over the
  group), then shifted so the beam never crosses the middle line from the
  stem side. `BeamPrimitive.start/end` are the midpoints of the beam's end
  edges; stems run to the beam's center line. Secondary (16th) beams are
  offset `beamThickness + beamSpacing` toward the noteheads; a lone
  sixteenth between eighths gets a 1-space beamlet stub pointing into the
  group.
- **Stem extension** (rule 5): default 3.5 spaces; if the default tip
  falls short of the middle line for notes far outside the staff, the stem
  extends to y = 2 (both directions).
- **Accidental state** (rule 9): per measure, keyed by (step, octave) —
  F♯4 does not imply F♯5. A hidden accidental (`showAccidental: false`)
  does NOT update the written state (state tracks what the reader sees);
  a forced one does.
- **Chord seconds** (rule 11): walking from the stem's anchor end, a note
  a second above/below an unflipped neighbor flips to the stem's other
  side. Flipped x = one notehead width minus stem thickness.
- **Key signature octaves** (rule 2): treble sharp positions
  [8,5,9,6,3,7,4], flats [4,7,3,6,2,5,1] (staff positions); bass = same
  pattern 2 positions lower (matches VexFlow/Behind Bars, incl. F♭ on the
  ledger position −1 for 7-flat bass signatures).
- **`ScoreLayout.top` added** beyond the contract's width/height: ink
  extends above y = 0 (clef overshoot, high notes), so the renderer needs
  the bounding-box top to translate correctly. Also added
  `measureRegions` (x-extents per measure) for the interaction layer's
  tap→measure mapping.

## Blockers

(none)

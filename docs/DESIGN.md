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

## Blockers

(none)

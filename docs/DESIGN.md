# neume — design log

Running log of non-obvious decisions and their rationale. Append as you go;
terse is fine. See HANDOVER.md §6.

## Pre-seeded decisions (scaffold, 2026-07-10)

- **Coordinate system**: layout works in *staff spaces* (1 space = gap between
  adjacent staff lines), origin at the intersection of the staff's top line
  and left edge, y grows downward. Rendering converts to px with one scale
  factor. SMuFL convention: font size = 4 × staff space.
- **Staff position convention**: `Pitch.staffPosition(clef)` returns 0 for the
  bottom line, +1 per line/space upward (treble: E4 = 0; bass: G2 = 0).
- **Two packages, not three**: layout stays in `neume_core` (pure Dart, golden
  logic testable without Flutter); a separate `neume_layout` package added
  friction without a consumer that wants layout-but-not-theory.
- **No dependencies**: theory core is small at our scope; owning it keeps the
  MIT story clean and lets the model be shaped for pedagogy
  (`Key.triadFor(HarmonicFunction)` etc.).

## Blockers

(none)

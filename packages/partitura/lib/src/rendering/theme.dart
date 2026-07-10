import 'package:flutter/widgets.dart';

/// Visual styling for staff rendering.
///
/// Scaffold seed — the full theme contract (per-element colors, kid mode,
/// hit slop) is specified in HANDOVER.md §4.3.
class PartituraTheme {
  /// Color of staff lines, barlines and clefs.
  final Color staffColor;

  /// Color of noteheads, stems, flags and beams.
  final Color noteColor;

  /// Creates a theme; defaults are ink-on-paper black.
  const PartituraTheme({
    this.staffColor = const Color(0xFF1A1A1A),
    this.noteColor = const Color(0xFF1A1A1A),
  });

  /// The default theme.
  static const PartituraTheme standard = PartituraTheme();
}

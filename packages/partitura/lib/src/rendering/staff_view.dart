import 'package:flutter/widgets.dart';
import 'package:partitura_core/partitura_core.dart';

import 'theme.dart';

/// Renders a five-line staff with a clef.
///
/// Scaffold seed proving the Bravura font pipeline (SMuFL glyphs drawn via
/// [TextPainter] with font size = 4 × staff space). The real implementation
/// per HANDOVER.md §4.3 replaces this widget's internals: it takes a `Score`,
/// runs the `partitura_core` layout engine and paints the resulting
/// primitives. The clef baseline-anchoring approach below is the intended
/// technique and worth keeping.
class StaffView extends StatelessWidget {
  /// Which clef to draw at the left edge of the staff.
  final Clef clef;

  /// Pixels per staff space (the gap between two adjacent staff lines).
  final double staffSpace;

  /// Colors for staff and glyphs.
  final PartituraTheme theme;

  /// Creates a staff with a [clef].
  const StaffView({
    super.key,
    this.clef = Clef.treble,
    this.staffSpace = 12,
    this.theme = PartituraTheme.standard,
  });

  @override
  Widget build(BuildContext context) {
    // 3 spaces of headroom above and below the staff for clef overshoot.
    return CustomPaint(
      size: Size(double.infinity, staffSpace * 10),
      painter: _StaffPainter(clef: clef, staffSpace: staffSpace, theme: theme),
    );
  }
}

class _StaffPainter extends CustomPainter {
  final Clef clef;
  final double staffSpace;
  final PartituraTheme theme;

  _StaffPainter({
    required this.clef,
    required this.staffSpace,
    required this.theme,
  });

  // SMuFL codepoints (stable across compliant fonts).
  static const _gClef = '\uE050';
  static const _fClef = '\uE062';

  @override
  void paint(Canvas canvas, Size size) {
    final top = 3 * staffSpace;
    final linePaint = Paint()
      ..color = theme.staffColor
      // Placeholder thickness; the real engine reads engravingDefaults from
      // bravura_metadata.json.
      ..strokeWidth = staffSpace * 0.13;

    for (var i = 0; i < 5; i++) {
      final y = top + i * staffSpace;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // SMuFL clefs have their origin (baseline) on their anchor line:
    // G clef on line 2 from the bottom (G4), F clef on line 4 (F3).
    final anchorY = switch (clef) {
      Clef.treble => top + 3 * staffSpace,
      Clef.bass => top + 1 * staffSpace,
    };

    final textPainter = TextPainter(
      text: TextSpan(
        text: clef == Clef.treble ? _gClef : _fClef,
        style: TextStyle(
          fontFamily: 'Bravura',
          package: 'partitura',
          // SMuFL convention: font size = 4 staff spaces.
          fontSize: staffSpace * 4,
          color: theme.staffColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final baseline =
        textPainter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    textPainter.paint(canvas, Offset(staffSpace, anchorY - baseline));
  }

  @override
  bool shouldRepaint(_StaffPainter oldDelegate) =>
      clef != oldDelegate.clef ||
      staffSpace != oldDelegate.staffSpace ||
      theme != oldDelegate.theme;
}

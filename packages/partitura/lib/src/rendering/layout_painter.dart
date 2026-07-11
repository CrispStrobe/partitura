import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:partitura_core/partitura_core.dart';

import 'smufl_glyphs.dart';
import 'theme.dart';

/// Paints a [ScoreLayout]'s primitives onto a canvas — the shared engine
/// behind [StaffView] and [GrandStaffView].
///
/// The painter owns a glyph-painter cache keyed by (glyph, color, scale);
/// call [clearCache] on relayout/theme changes and [dispose] when done.
class LayoutPainter {
  /// Colors and ergonomics.
  PartituraTheme theme;

  /// Pixels per staff space.
  double scale;

  /// Ids painted in the theme's highlight color.
  Set<String> highlightedIds;

  final Map<String, TextPainter> _glyphCache = {};

  /// Creates a painter.
  LayoutPainter({
    required this.theme,
    required this.scale,
    this.highlightedIds = const {},
  });

  /// The effective color of an element's ink.
  Color colorFor(String? elementId) {
    if (elementId == null) return theme.staffColor;
    if (highlightedIds.contains(elementId)) return theme.highlightColor;
    return theme.elementColors[elementId] ?? theme.noteColor;
  }

  /// A laid-out text painter for [smuflName] (cached).
  TextPainter glyphPainter(String smuflName, Color color, double glyphScale) {
    final key = '$smuflName|${color.toARGB32()}|$glyphScale';
    return _glyphCache.putIfAbsent(key, () {
      final character = smuflCodepoints[smuflName];
      assert(character != null, 'No codepoint for SMuFL glyph $smuflName');
      return TextPainter(
        text: TextSpan(
          text: character ?? '',
          style: TextStyle(
            fontFamily: 'Bravura',
            package: 'partitura',
            // SMuFL convention: font size = 4 x staff space.
            fontSize: 4 * scale * glyphScale,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Paints one glyph with its origin at the staff-space [position],
  /// where [origin] is the pixel position of staff-space (0, 0).
  void paintGlyph(
    Canvas canvas,
    Offset origin,
    String smuflName,
    math.Point<double> position,
    Color color, {
    double glyphScale = 1.0,
  }) {
    final painter = glyphPainter(smuflName, color, glyphScale);
    final baseline =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    canvas.drawText(painter, origin, position, baseline, scale);
  }

  /// Paints every primitive of [layout]. [origin] is the pixel position
  /// of the layout's staff-space (0, 0) — the top staff line's left end.
  void paintLayout(Canvas canvas, Offset origin, ScoreLayout layout) {
    Offset at(math.Point<double> p) =>
        origin + Offset(p.x * scale, p.y * scale);
    for (final primitive in layout.primitives) {
      switch (primitive) {
        case GlyphPrimitive():
          paintGlyph(
            canvas,
            origin,
            primitive.smuflName,
            primitive.position,
            colorFor(primitive.elementId),
            glyphScale: primitive.scale,
          );
        case LinePrimitive():
          final paint = Paint()
            ..color = colorFor(primitive.elementId)
            ..strokeWidth = primitive.thickness * scale;
          canvas.drawLine(at(primitive.from), at(primitive.to), paint);
        case BeamPrimitive():
          // Beams are note ink even though they are shared across elements.
          final paint = Paint()..color = theme.noteColor;
          final start = at(primitive.start);
          final end = at(primitive.end);
          final half = primitive.thickness / 2 * scale;
          canvas.drawPath(
            Path()
              ..moveTo(start.dx, start.dy - half)
              ..lineTo(end.dx, end.dy - half)
              ..lineTo(end.dx, end.dy + half)
              ..lineTo(start.dx, start.dy + half)
              ..close(),
            paint,
          );
        case CurvePrimitive():
          // Ties/slurs are shared note ink, like beams.
          final paint = Paint()
            ..color = theme.noteColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = primitive.thickness * scale
            ..strokeCap = StrokeCap.round;
          final p0 = at(primitive.start);
          final c1 = at(primitive.control1);
          final c2 = at(primitive.control2);
          final p1 = at(primitive.end);
          canvas.drawPath(
            Path()
              ..moveTo(p0.dx, p0.dy)
              ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy),
            paint,
          );
      }
    }
  }

  /// Clears the glyph-painter cache (call on relayout or theme change).
  void clearCache() {
    for (final painter in _glyphCache.values) {
      painter.dispose();
    }
    _glyphCache.clear();
  }

  /// Releases resources.
  void dispose() => clearCache();
}

extension on Canvas {
  /// Draws [painter] so the glyph origin lands at [position].
  void drawText(
    TextPainter painter,
    Offset origin,
    math.Point<double> position,
    double baseline,
    double scale,
  ) {
    painter.paint(
      this,
      origin + Offset(position.x * scale, position.y * scale - baseline),
    );
  }
}

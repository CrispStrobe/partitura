part of 'tab_layout.dart';

// Tab technique markings drawn beside the fret numbers: bend/whammy contours,
// arpeggio arrows, vibrato, tremolo-bar dips and the technique text bracket.
// Extracted from tab_layout.dart; behaviour unchanged.

/// The conventional label for a tremolo-bar dip of [steps] whole tones.
String _tremoloBarLabel(double steps) {
  final mag = steps.abs();
  final magLabel = switch (mag) {
    0.25 => '¼',
    0.5 => '½',
    0.75 => '¾',
    1.5 => '1½',
    _ => mag == mag.roundToDouble() ? '${mag.toInt()}' : '$mag',
  };
  return '${steps < 0 ? '-' : ''}$magLabel';
}

extension _TabTechniques on TabLayoutEngine {
  /// Draws a vertical wavy arpeggio line at [ax] spanning [topY]..[botY], with
  /// an arrowhead giving the roll [direction] (up = arrow at the top).
  void _layoutArpeggio(List<LayoutPrimitive> primitives, double ax, double topY,
      double botY, Arpeggio direction) {
    const half = 0.42; // vertical length of each half-wave
    const amp = 0.22;
    var py = topY;
    var k = 0;
    while (py < botY - 1e-9) {
      final dir = k.isEven ? 1.0 : -1.0;
      final nextY = min(py + half, botY);
      primitives.add(CurvePrimitive(
        Point(ax, py),
        Point(ax + dir * amp, py + half * 0.4),
        Point(ax + dir * amp, py + half * 0.6),
        Point(ax, nextY),
        thickness: 0.13,
      ));
      py = nextY;
      k++;
    }
    if (direction == Arpeggio.up) {
      primitives.add(LinePrimitive(
          Point(ax, topY), Point(ax - 0.22, topY + 0.45),
          thickness: 0.13));
      primitives.add(LinePrimitive(
          Point(ax, topY), Point(ax + 0.22, topY + 0.45),
          thickness: 0.13));
    } else {
      primitives.add(LinePrimitive(
          Point(ax, botY), Point(ax - 0.22, botY - 0.45),
          thickness: 0.13));
      primitives.add(LinePrimitive(
          Point(ax, botY), Point(ax + 0.22, botY - 0.45),
          thickness: 0.13));
    }
  }

  /// Draws a horizontal wavy vibrato line above the fret at ([bx], [by]).
  void _layoutVibrato(
      List<LayoutPrimitive> primitives, double bx, double by, bool wide) {
    final amp = wide ? 0.5 : 0.28;
    const half = 0.5; // horizontal length of each half-wave
    const count = 4; // number of half-waves
    final baseY = by - 1.0;
    var px = bx - 0.4;
    for (var k = 0; k < count; k++) {
      final dir = k.isEven ? -1.0 : 1.0;
      final peakY = baseY + dir * amp;
      primitives.add(CurvePrimitive(
        Point(px, baseY),
        Point(px + half * 0.4, peakY),
        Point(px + half * 0.6, peakY),
        Point(px + half, baseY),
        thickness: wide ? 0.16 : 0.13,
      ));
      px += half;
    }
  }

  /// Draws a tremolo-bar V above the fret at ([bx], [by]) with the [steps]
  /// dip amount labelled at the bottom of the V.
  void _layoutTremoloBar(
      List<LayoutPrimitive> primitives, double bx, double by, double steps) {
    final topY = by - 1.4;
    final lowY = topY + 0.65;
    primitives.add(LinePrimitive(Point(bx - 0.1, topY), Point(bx + 0.35, lowY),
        thickness: 0.13));
    primitives.add(LinePrimitive(Point(bx + 0.35, lowY), Point(bx + 0.8, topY),
        thickness: 0.13));
    primitives.add(TextPrimitive(
      _tremoloBarLabel(steps),
      Point(bx + 0.35, lowY + 0.55),
      size: 1.0,
    ));
  }

  /// Draws a bend/whammy contour above the fret at ([bx], [by]) as a
  /// pitch-vs-time line graph through [points] (each `(offset 0..1, steps)`),
  /// with an arrowhead + amount label at every turning point: an up-arrow at a
  /// rise target, a down-arrow at a dive trough. A prebend (first point at
  /// offset 0 with a non-zero pitch) shows as a vertical rise from the fret.
  void _layoutContour(List<LayoutPrimitive> primitives, double bx, double by,
      List<BendPoint> points) {
    if (points.isEmpty) return;
    const span = 2.6; // horizontal length of the whole contour
    const unit = 0.7; // staff spaces per whole tone
    final x0 = bx + 0.45;
    final baseY = by - 0.5;
    double px(double o) => x0 + o.clamp(0.0, 1.0) * span;
    double py(double stp) => baseY - stp * unit;
    // Vertices: prepend a pitch-0 anchor at the fret unless the contour already
    // starts there, so a rise (or prebend) has something to climb from.
    final first = points.first;
    final verts = <Point<double>>[
      if (first.offset > 0 || first.steps != 0) Point(x0, baseY),
      for (final p in points) Point(px(p.offset), py(p.steps)),
    ];
    for (var i = 0; i + 1 < verts.length; i++) {
      primitives.add(LinePrimitive(verts[i], verts[i + 1], thickness: 0.13));
    }
    // Arrowheads + labels at turning points.
    final base = verts.length - points.length; // 0 or 1 (the prepended anchor)
    for (var i = 0; i < points.length; i++) {
      final stp = points[i].steps;
      final prev = i == 0 ? 0.0 : points[i - 1].steps;
      final next = i + 1 < points.length ? points[i + 1].steps : stp;
      final v = verts[base + i];
      if (stp > prev + 1e-9 && stp >= next - 1e-9 && stp > 0) {
        // Rise target: up-arrow.
        primitives.add(
            LinePrimitive(v, Point(v.x - 0.24, v.y + 0.42), thickness: 0.13));
        primitives.add(
            LinePrimitive(v, Point(v.x + 0.24, v.y + 0.42), thickness: 0.13));
        primitives.add(TextPrimitive(
            TabLayoutEngine._bendLabel(stp), Point(v.x, v.y - 0.25),
            size: 1.0));
      } else if (stp < prev - 1e-9 && stp <= next + 1e-9 && stp < 0) {
        // Dive trough: down-arrow.
        primitives.add(
            LinePrimitive(v, Point(v.x - 0.24, v.y - 0.42), thickness: 0.13));
        primitives.add(
            LinePrimitive(v, Point(v.x + 0.24, v.y - 0.42), thickness: 0.13));
        primitives.add(TextPrimitive(
            _tremoloBarLabel(stp), Point(v.x, v.y + 0.9),
            size: 1.0));
      }
    }
  }

  /// Draws a [label] followed by a dashed bracket line above the staff, from
  /// [startX] to [endX], with a downward end tick. Used for palm mute and let
  /// ring. A single-note span (start ≈ end) draws just the label and the tick.
  void _layoutTextBracket(List<LayoutPrimitive> primitives, String label,
      double startX, double endX, LayoutSettings s) {
    const size = 1.1;
    const y = -1.4; // above the top string line (y = 0)
    // Center-baseline text: shift right so the label's left edge sits at startX.
    final labelHalf = 0.25 * size * label.length;
    primitives.add(TextPrimitive(
      label,
      Point(startX + labelHalf, y + 0.35),
      size: size,
    ));
    final lineStart = startX + 2 * labelHalf + 0.3;
    if (endX > lineStart + 0.3) {
      // Dashed line from after the label to the end.
      const dash = 0.4;
      const gap = 0.28;
      var px = lineStart;
      while (px < endX) {
        primitives.add(LinePrimitive(
          Point(px, y),
          Point(min(px + dash, endX), y),
          thickness: s.staffLineThickness,
        ));
        px += dash + gap;
      }
    }
    // Downward end tick.
    primitives.add(LinePrimitive(
      Point(endX, y),
      Point(endX, y + 0.5),
      thickness: s.staffLineThickness,
    ));
  }
}

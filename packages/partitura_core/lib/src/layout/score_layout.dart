/// The layout engine's output: a flat display list plus hit information.
///
/// **Coordinate system** (binding, see docs/DESIGN.md): distances in staff
/// spaces; origin at the intersection of the staff's **top line** with its
/// left edge; y grows **downward**. The five staff lines lie at y = 0, 1,
/// 2, 3, 4; a staff position `p` (0 = bottom line) maps to
/// `y = (8 - p) / 2`. Ink above the staff has negative y.
library;

import 'dart:math';

/// One drawable item of a laid-out score.
///
/// Primitives tagged with an [elementId] belong to that score element
/// (notehead, stem, its accidentals, …); untagged primitives are staff
/// furniture (staff lines, clef, signatures, barlines).
sealed class LayoutPrimitive {
  /// The id of the score element this primitive belongs to, if any.
  final String? elementId;

  /// Creates a primitive, optionally owned by element [elementId].
  const LayoutPrimitive({this.elementId});
}

/// A SMuFL glyph drawn with its origin (text baseline) at [position].
final class GlyphPrimitive extends LayoutPrimitive {
  /// SMuFL glyph name (see [SmuflGlyph]).
  final String smuflName;

  /// Glyph origin in staff spaces.
  final Point<double> position;

  /// Creates a glyph primitive.
  const GlyphPrimitive(this.smuflName, this.position, {super.elementId});

  @override
  String toString() => 'Glyph($smuflName @ ${position.x},${position.y}'
      '${elementId == null ? '' : ', $elementId'})';
}

/// A straight line: staff lines, stems, ledger lines, barlines.
///
/// The line's [thickness] is centered on the segment from [from] to [to].
final class LinePrimitive extends LayoutPrimitive {
  /// Start point in staff spaces.
  final Point<double> from;

  /// End point in staff spaces.
  final Point<double> to;

  /// Line thickness in staff spaces.
  final double thickness;

  /// Creates a line primitive.
  const LinePrimitive(
    this.from,
    this.to, {
    required this.thickness,
    super.elementId,
  });

  @override
  String toString() => 'Line(${from.x},${from.y} -> ${to.x},${to.y} x$thickness'
      '${elementId == null ? '' : ', $elementId'})';
}

/// A beam: a filled parallelogram with vertical end edges.
///
/// [start] and [end] are the **midpoints** of the beam's left and right
/// edges; the beam extends [thickness] / 2 above and below the line
/// through them.
final class BeamPrimitive extends LayoutPrimitive {
  /// Midpoint of the left edge, in staff spaces.
  final Point<double> start;

  /// Midpoint of the right edge, in staff spaces.
  final Point<double> end;

  /// Vertical thickness of the beam in staff spaces.
  final double thickness;

  /// Creates a beam primitive.
  const BeamPrimitive(
    this.start,
    this.end, {
    required this.thickness,
    super.elementId,
  });

  @override
  String toString() =>
      'Beam(${start.x},${start.y} -> ${end.x},${end.y} x$thickness'
      '${elementId == null ? '' : ', $elementId'})';
}

/// The hit box of one score element, tagged with its id.
class ElementRegion {
  /// The element's id (elements without an id get no region).
  final String elementId;

  /// Bounding box of the element's ink in staff spaces (noteheads,
  /// accidentals, stem, flag, dots — beams are shared and excluded).
  final Rectangle<double> bounds;

  /// Creates a region.
  const ElementRegion(this.elementId, this.bounds);

  @override
  String toString() => 'ElementRegion($elementId, $bounds)';
}

/// The horizontal extent of one measure (for mapping taps to measures).
class MeasureRegion {
  /// Index of the measure in `Score.measures`.
  final int index;

  /// Left edge in staff spaces (after the preceding barline/signatures).
  final double startX;

  /// Right edge in staff spaces (before the following barline).
  final double endX;

  /// Creates a measure region.
  const MeasureRegion(this.index, {required this.startX, required this.endX});

  @override
  String toString() => 'MeasureRegion($index, $startX..$endX)';
}

/// A laid-out score: flat display list plus hit information.
///
/// Produced by `LayoutEngine.layout`; deterministic for identical inputs.
class ScoreLayout {
  /// Total width in staff spaces, from x = 0 to the end of the final
  /// barline plus padding.
  final double width;

  /// Total height of the bounding box in staff spaces.
  final double height;

  /// y of the bounding box's top edge. Usually negative: ink (clef
  /// overshoot, notes above the staff) extends above the top staff line,
  /// which is y = 0.
  final double top;

  /// Drawables in painting order (staff furniture first, then elements).
  final List<LayoutPrimitive> primitives;

  /// Hit boxes for all elements that carry an id.
  final List<ElementRegion> regions;

  /// Horizontal extents of the measures, in order.
  final List<MeasureRegion> measureRegions;

  /// Creates a layout (treat the lists as immutable).
  const ScoreLayout({
    required this.width,
    required this.height,
    required this.top,
    required this.primitives,
    required this.regions,
    required this.measureRegions,
  });

  /// The bounding box: x from 0 to [width], y from [top] to
  /// [top] + [height].
  Rectangle<double> get bounds => Rectangle(0, top, width, height);

  @override
  String toString() =>
      'ScoreLayout(${width}x$height, ${primitives.length} primitives, '
      '${regions.length} regions)';
}

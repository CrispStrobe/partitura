import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:partitura_core/partitura_core.dart';

import 'bravura.dart';
import 'smufl_glyphs.dart';
import 'theme.dart';

/// Renders a [Score] as a single staff.
///
/// Layout comes from `partitura_core`'s [LayoutEngine]; this widget only
/// converts staff spaces to pixels (one scale factor) and paints. Elements
/// whose id is in [highlightedIds] are painted in the theme's highlight
/// color — changing highlights repaints but never relayouts.
///
/// The bundled Bravura font's metadata loads asynchronously on first use;
/// until it arrives the widget paints nothing. Await [Bravura.load] up
/// front (e.g. in `main()`) to avoid the one-frame gap.
class StaffView extends LeafRenderObjectWidget {
  /// The score to render.
  final Score score;

  /// Colors and ergonomics.
  final PartituraTheme theme;

  /// Pixels per staff space; null fits the score to the available width.
  final double? staffSpace;

  /// Ids of elements to paint in [PartituraTheme.highlightColor].
  final Set<String> highlightedIds;

  /// Called with the element id when the user taps an element.
  final void Function(String elementId)? onElementTap;

  /// Creates a staff view.
  const StaffView({
    super.key,
    required this.score,
    this.theme = PartituraTheme.standard,
    this.staffSpace,
    this.highlightedIds = const {},
    this.onElementTap,
  });

  @override
  RenderStaffView createRenderObject(BuildContext context) => RenderStaffView(
        score: score,
        theme: theme,
        staffSpace: staffSpace,
        highlightedIds: highlightedIds,
      )..onElementTap = onElementTap;

  @override
  void updateRenderObject(BuildContext context, RenderStaffView renderObject) {
    renderObject
      ..score = score
      ..theme = theme
      ..staffSpace = staffSpace
      ..highlightedIds = highlightedIds
      ..onElementTap = onElementTap;
  }
}

/// A ghost-note preview: a semi-transparent notehead following a drag,
/// quantized to a staff position. Set on [RenderStaffView] by
/// `InteractiveStaff`.
class GhostNote {
  /// Horizontal center of the ghost notehead, in staff spaces.
  final double xSpaces;

  /// Quantized staff position (0 = bottom line).
  final int staffPosition;

  /// Duration deciding the notehead glyph.
  final NoteDuration duration;

  /// Creates a ghost-note preview spec.
  const GhostNote({
    required this.xSpaces,
    required this.staffPosition,
    required this.duration,
  });

  @override
  bool operator ==(Object other) =>
      other is GhostNote &&
      other.xSpaces == xSpaces &&
      other.staffPosition == staffPosition &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(xSpaces, staffPosition, duration);
}

/// Render object behind [StaffView]; also the geometry service used by
/// `InteractiveStaff` (element hit testing, staff-position quantization,
/// ghost-note painting).
class RenderStaffView extends RenderBox {
  /// Creates the render object.
  RenderStaffView({
    required Score score,
    required PartituraTheme theme,
    double? staffSpace,
    required Set<String> highlightedIds,
  })  : _score = score,
        _theme = theme,
        _staffSpace = staffSpace,
        _highlightedIds = highlightedIds {
    _tap = TapGestureRecognizer(debugOwner: this)..onTapUp = _handleTapUp;
  }

  static const LayoutEngine _engine = LayoutEngine();
  static const double _fallbackStaffSpace = 12;

  late final TapGestureRecognizer _tap;

  ScoreLayout? _layout;
  double _scale = _fallbackStaffSpace;
  final Map<String, TextPainter> _glyphCache = {};

  /// Called with the element id when the user taps an element.
  void Function(String elementId)? onElementTap;

  /// Called when a tap lands on no element: quantized staff position and
  /// measure index (used by `InteractiveStaff`).
  void Function(int staffPosition, int measureIndex)? onStaffTap;

  Score _score;

  /// The score to render.
  Score get score => _score;
  set score(Score value) {
    if (value == _score) return;
    _score = value;
    markNeedsLayout();
  }

  PartituraTheme _theme;

  /// Colors and ergonomics.
  PartituraTheme get theme => _theme;
  set theme(PartituraTheme value) {
    if (value == _theme) return;
    final needsLayout = value.lineBoost != _theme.lineBoost;
    _theme = value;
    if (needsLayout) {
      markNeedsLayout();
    } else {
      _glyphCache.clear();
      markNeedsPaint();
    }
  }

  double? _staffSpace;

  /// Pixels per staff space; null fits to width.
  double? get staffSpace => _staffSpace;
  set staffSpace(double? value) {
    if (value == _staffSpace) return;
    _staffSpace = value;
    markNeedsLayout();
  }

  Set<String> _highlightedIds;

  /// Ids painted in the highlight color. Repaint only — no relayout.
  Set<String> get highlightedIds => _highlightedIds;
  set highlightedIds(Set<String> value) {
    if (value == _highlightedIds ||
        (value.length == _highlightedIds.length &&
            value.containsAll(_highlightedIds))) {
      return;
    }
    _highlightedIds = value;
    markNeedsPaint();
  }

  GhostNote? _ghostNote;

  /// Ghost-note preview; repaint only.
  GhostNote? get ghostNote => _ghostNote;
  set ghostNote(GhostNote? value) {
    if (value == _ghostNote) return;
    _ghostNote = value;
    markNeedsPaint();
  }

  // -------------------------------------------------------------- geometry

  /// The current layout in staff spaces, or null while the font metadata
  /// is still loading.
  ScoreLayout? get scoreLayout => _layout;

  /// Pixels per staff space in the current layout.
  double get scale => _scale;

  LayoutSettings _settingsFor(SmuflMetadata metadata) {
    final boost = _theme.lineBoost;
    final base = LayoutSettings(metadata: metadata);
    if (boost == 1.0) return base;
    return LayoutSettings(
      metadata: metadata,
      staffLineThickness: base.staffLineThickness * boost,
      stemThickness: base.stemThickness * boost,
      legerLineThickness: base.legerLineThickness * boost,
      thinBarlineThickness: base.thinBarlineThickness * boost,
    );
  }

  Size _measure(BoxConstraints constraints) {
    final metadata = Bravura.metadataOrNull;
    if (metadata == null) {
      _layout = null;
      final space = _staffSpace ?? _fallbackStaffSpace;
      return constraints.constrain(Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 40 * space,
        12 * space,
      ));
    }
    final layout = _engine.layout(_score, _settingsFor(metadata));
    _layout = layout;
    _scale = _staffSpace ??
        (constraints.hasBoundedWidth
            ? constraints.maxWidth / layout.width
            : _fallbackStaffSpace);
    return constraints
        .constrain(Size(layout.width * _scale, layout.height * _scale));
  }

  @override
  void performLayout() {
    if (Bravura.metadataOrNull == null) {
      Bravura.load().then((_) {
        if (attached) markNeedsLayout();
      });
    }
    _glyphCache.clear();
    size = _measure(constraints);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints);

  /// Converts a local pixel offset to staff-space coordinates.
  math.Point<double> localToStaff(Offset local) {
    final top = _layout?.top ?? 0;
    return math.Point(local.dx / _scale, local.dy / _scale + top);
  }

  /// Converts staff-space coordinates to a local pixel offset.
  Offset staffToLocal(math.Point<double> point) {
    final top = _layout?.top ?? 0;
    return Offset(point.x * _scale, (point.y - top) * _scale);
  }

  /// The id of the element whose (hit-slop-inflated) region contains
  /// [local], or null. Overlapping regions resolve to the smallest one.
  String? elementIdAt(Offset local) {
    final layout = _layout;
    if (layout == null) return null;
    final point = localToStaff(local);
    final slop = _theme.hitSlop;
    String? bestId;
    var bestArea = double.infinity;
    for (final region in layout.regions) {
      final b = region.bounds;
      final inflated = math.Rectangle(
        b.left - slop,
        b.top - slop,
        b.width + 2 * slop,
        b.height + 2 * slop,
      );
      if (inflated.containsPoint(point)) {
        final area = inflated.width * inflated.height;
        if (area < bestArea) {
          bestArea = area;
          bestId = region.elementId;
        }
      }
    }
    return bestId;
  }

  /// Quantizes [local] to the nearest staff position (line or space,
  /// including the ledger range) and the measure index under the tap.
  (int staffPosition, int measureIndex) quantizeStaffPosition(Offset local) {
    final layout = _layout;
    final point = localToStaff(local);
    final position = (8 - 2 * point.y).round().clamp(-6, 14);
    var measureIndex = 0;
    if (layout != null) {
      for (final region in layout.measureRegions) {
        if (point.x >= region.startX) measureIndex = region.index;
      }
    }
    return (position, measureIndex);
  }

  // ------------------------------------------------------------------ input

  @override
  bool hitTestSelf(Offset position) =>
      onElementTap != null || onStaffTap != null;

  @override
  void handleEvent(PointerEvent event, covariant BoxHitTestEntry entry) {
    if (event is PointerDownEvent &&
        (onElementTap != null || onStaffTap != null)) {
      _tap.addPointer(event);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    final id = elementIdAt(details.localPosition);
    if (id != null) {
      onElementTap?.call(id);
      return;
    }
    final handler = onStaffTap;
    if (handler != null) {
      final (position, measureIndex) =
          quantizeStaffPosition(details.localPosition);
      handler(position, measureIndex);
    }
  }

  @override
  void dispose() {
    _tap.dispose();
    for (final painter in _glyphCache.values) {
      painter.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ paint

  Color _colorFor(String? elementId) {
    if (elementId == null) return _theme.staffColor;
    if (_highlightedIds.contains(elementId)) return _theme.highlightColor;
    return _theme.elementColors[elementId] ?? _theme.noteColor;
  }

  TextPainter _glyphPainter(String smuflName, Color color) {
    final key = '$smuflName|${color.toARGB32()}';
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
            fontSize: 4 * _scale,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final layout = _layout;
    if (layout == null) return;
    final canvas = context.canvas;

    for (final primitive in layout.primitives) {
      switch (primitive) {
        case GlyphPrimitive():
          _paintGlyph(
            canvas,
            offset,
            primitive.smuflName,
            primitive.position,
            _colorFor(primitive.elementId),
          );
        case LinePrimitive():
          final paint = Paint()
            ..color = _colorFor(primitive.elementId)
            ..strokeWidth = primitive.thickness * _scale;
          canvas.drawLine(
            offset + staffToLocal(primitive.from),
            offset + staffToLocal(primitive.to),
            paint,
          );
        case BeamPrimitive():
          // Beams are note ink even though they are shared across elements.
          final paint = Paint()..color = _theme.noteColor;
          final start = offset + staffToLocal(primitive.start);
          final end = offset + staffToLocal(primitive.end);
          final half = primitive.thickness / 2 * _scale;
          canvas.drawPath(
            Path()
              ..moveTo(start.dx, start.dy - half)
              ..lineTo(end.dx, end.dy - half)
              ..lineTo(end.dx, end.dy + half)
              ..lineTo(start.dx, start.dy + half)
              ..close(),
            paint,
          );
      }
    }

    _paintGhostNote(canvas, offset);
  }

  void _paintGhostNote(Canvas canvas, Offset offset) {
    final ghost = _ghostNote;
    if (ghost == null) return;
    final glyph = switch (ghost.duration.base) {
      DurationBase.whole => SmuflGlyph.noteheadWhole,
      DurationBase.half => SmuflGlyph.noteheadHalf,
      _ => SmuflGlyph.noteheadBlack,
    };
    final color = _theme.highlightColor.withValues(alpha: 0.45);
    final y = (8 - ghost.staffPosition) / 2;
    final metadata = Bravura.metadataOrNull;
    final width = metadata?.bBoxOf(glyph).width ?? 1.18;
    _paintGlyph(
      canvas,
      offset,
      glyph,
      math.Point(ghost.xSpaces - width / 2, y),
      color,
    );
    // Preview ledger lines so out-of-staff targets read correctly.
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.16 * _scale;
    for (var p = -2; p >= ghost.staffPosition; p -= 2) {
      _paintGhostLedger(canvas, offset, ghost.xSpaces, p, width, paint);
    }
    for (var p = 10; p <= ghost.staffPosition; p += 2) {
      _paintGhostLedger(canvas, offset, ghost.xSpaces, p, width, paint);
    }
  }

  void _paintGhostLedger(
    Canvas canvas,
    Offset offset,
    double xSpaces,
    int position,
    double headWidth,
    Paint paint,
  ) {
    final y = (8 - position) / 2;
    canvas.drawLine(
      offset + staffToLocal(math.Point(xSpaces - headWidth / 2 - 0.4, y)),
      offset + staffToLocal(math.Point(xSpaces + headWidth / 2 + 0.4, y)),
      paint,
    );
  }

  void _paintGlyph(
    Canvas canvas,
    Offset offset,
    String smuflName,
    math.Point<double> position,
    Color color,
  ) {
    final painter = _glyphPainter(smuflName, color);
    final baseline =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final local = staffToLocal(position);
    painter.paint(canvas, offset + Offset(local.dx, local.dy - baseline));
  }
}

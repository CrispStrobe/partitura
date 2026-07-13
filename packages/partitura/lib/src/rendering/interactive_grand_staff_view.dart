import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:partitura_core/partitura_core.dart';

import '../interaction/staff_target.dart';
import 'layout_painter.dart';
import 'music_font.dart';
import 'theme.dart';

/// A grand staff (two clefs, e.g. piano) wrapped into multiple systems that
/// fit the available width, with tap interaction on both staves — the editor
/// counterpart of [MultiSystemView] for a keyboard system.
///
/// Line breaking (`layoutGrandStaffSystems`) packs measures by the wider of the
/// two staves so barlines stay aligned; the time signature is drawn only on the
/// first system. Tapping an element fires [onElementTap]; tapping empty staff
/// fires [onStaffTap] with a [StaffTarget] carrying the `systemIndex` and the
/// `staffIndex` (0 = upper, 1 = lower).
class InteractiveGrandStaffView extends LeafRenderObjectWidget {
  /// The two-staff grand staff to render.
  final GrandStaff grandStaff;

  /// Colors and ergonomics.
  final PartituraTheme theme;

  /// Pixels per staff space (fixed — the width drives line breaking).
  final double staffSpace;

  /// Staff spaces between the upper staff's bottom line and the lower staff's
  /// top line within each system.
  final double staffGap;

  /// Staff spaces between the bounding boxes of consecutive systems.
  final double systemGap;

  /// Ids painted in the highlight color.
  final Set<String> highlightedIds;

  /// Per-element ink colors.
  final Map<String, Color> elementColors;

  /// Called with the element id when the user taps an element on any staff.
  final void Function(String elementId)? onElementTap;

  /// Called with a quantized [StaffTarget] (with `systemIndex` and
  /// `staffIndex`) when the user taps empty staff.
  final void Function(StaffTarget target)? onStaffTap;

  /// Creates a wrapped, interactive grand staff.
  const InteractiveGrandStaffView({
    super.key,
    required this.grandStaff,
    this.theme = PartituraTheme.standard,
    this.staffSpace = 12,
    this.staffGap = 4.0,
    this.systemGap = 6.0,
    this.highlightedIds = const {},
    this.elementColors = const {},
    this.onElementTap,
    this.onStaffTap,
  });

  @override
  RenderInteractiveGrandStaffView createRenderObject(BuildContext context) =>
      RenderInteractiveGrandStaffView(
        grandStaff: grandStaff,
        theme: theme,
        staffSpace: staffSpace,
        staffGap: staffGap,
        systemGap: systemGap,
        highlightedIds: highlightedIds,
        elementColors: elementColors,
      )
        ..onElementTap = onElementTap
        ..onStaffTap = onStaffTap;

  @override
  void updateRenderObject(
    BuildContext context,
    RenderInteractiveGrandStaffView renderObject,
  ) {
    renderObject
      ..grandStaff = grandStaff
      ..theme = theme
      ..staffSpace = staffSpace
      ..staffGap = staffGap
      ..systemGap = systemGap
      ..highlightedIds = highlightedIds
      ..elementColors = elementColors
      ..onElementTap = onElementTap
      ..onStaffTap = onStaffTap;
  }
}

/// Render object behind [InteractiveGrandStaffView].
class RenderInteractiveGrandStaffView extends RenderBox {
  /// Creates the render object.
  RenderInteractiveGrandStaffView({
    required GrandStaff grandStaff,
    required PartituraTheme theme,
    required double staffSpace,
    required double staffGap,
    required double systemGap,
    required Set<String> highlightedIds,
    Map<String, Color> elementColors = const {},
  })  : _grandStaff = grandStaff,
        _theme = theme,
        _staffSpace = staffSpace,
        _staffGap = staffGap,
        _systemGap = systemGap,
        _highlightedIds = highlightedIds,
        _elementColors = elementColors {
    _tap = TapGestureRecognizer(debugOwner: this)..onTapUp = _handleTapUp;
  }

  /// Left inset (staff spaces) reserved for the brace.
  static const double braceInset = 1.4;

  late final TapGestureRecognizer _tap;
  GrandStaffSystems? _systems;
  late final LayoutPainter _painter = LayoutPainter(
    theme: _theme,
    scale: _staffSpace,
    highlightedIds: _highlightedIds,
    elementColors: _elementColors,
  );

  /// Called with the element id when the user taps an element.
  void Function(String elementId)? onElementTap;

  /// Called with a quantized [StaffTarget] when the user taps empty staff.
  void Function(StaffTarget target)? onStaffTap;

  GrandStaff _grandStaff;

  /// The grand staff to render.
  GrandStaff get grandStaff => _grandStaff;
  set grandStaff(GrandStaff value) {
    if (value == _grandStaff) return;
    _grandStaff = value;
    markNeedsLayout();
  }

  PartituraTheme _theme;

  /// Colors and ergonomics.
  PartituraTheme get theme => _theme;
  set theme(PartituraTheme value) {
    if (value == _theme) return;
    final needsLayout = value.lineBoost != _theme.lineBoost ||
        value.musicFont != _theme.musicFont;
    _theme = value;
    _painter.theme = value;
    if (needsLayout) {
      markNeedsLayout();
    } else {
      _painter.clearCache();
      markNeedsPaint();
    }
  }

  double _staffSpace;

  /// Pixels per staff space.
  double get staffSpace => _staffSpace;
  set staffSpace(double value) {
    if (value == _staffSpace) return;
    _staffSpace = value;
    markNeedsLayout();
  }

  double _staffGap;

  /// Staff spaces between the two staves of a system.
  double get staffGap => _staffGap;
  set staffGap(double value) {
    if (value == _staffGap) return;
    _staffGap = value;
    markNeedsLayout();
  }

  double _systemGap;

  /// Staff spaces between systems.
  double get systemGap => _systemGap;
  set systemGap(double value) {
    if (value == _systemGap) return;
    _systemGap = value;
    markNeedsLayout();
  }

  Set<String> _highlightedIds;

  /// Ids painted in the highlight color. Repaint only.
  Set<String> get highlightedIds => _highlightedIds;
  set highlightedIds(Set<String> value) {
    if (value == _highlightedIds ||
        (value.length == _highlightedIds.length &&
            value.containsAll(_highlightedIds))) {
      return;
    }
    _highlightedIds = value;
    _painter.highlightedIds = value;
    markNeedsPaint();
  }

  Map<String, Color> _elementColors;

  /// Per-element ink colors. Repaint only.
  Map<String, Color> get elementColors => _elementColors;
  set elementColors(Map<String, Color> value) {
    if (mapEquals(value, _elementColors)) return;
    _elementColors = value;
    _painter.elementColors = value;
    markNeedsPaint();
  }

  // -------------------------------------------------------------- geometry

  /// The current wrapped-grand-staff layout, or null while loading.
  GrandStaffSystems? get grandStaffSystems => _systems;

  /// Pixels per staff space.
  double get scale => _staffSpace;

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

  /// Pixel y of system [i]'s bounding-box top.
  double _bandTop(int i) {
    final systems = _systems!.systems;
    var y = 0.0;
    for (var j = 0; j < i; j++) {
      y += (systems[j].layout.height + _systemGap) * _staffSpace;
    }
    return y;
  }

  /// Pixel origin of the upper staff's staff-space (0, 0) on system [i].
  Offset upperOrigin(int i) {
    final layout = _systems!.systems[i].layout;
    return Offset(
        braceInset * _staffSpace, _bandTop(i) - layout.upper.top * _staffSpace);
  }

  /// Pixel origin of the lower staff's staff-space (0, 0) on system [i].
  Offset lowerOrigin(int i) {
    final layout = _systems!.systems[i].layout;
    return Offset(
      braceInset * _staffSpace,
      _bandTop(i) + (-layout.upper.top + 4 + layout.staffGap) * _staffSpace,
    );
  }

  Size _measure(BoxConstraints constraints) {
    final metadata = MusicFonts.metadataOrNull(_theme.musicFont);
    if (metadata == null) {
      _systems = null;
      return constraints.constrain(Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 40 * _staffSpace,
        24 * _staffSpace,
      ));
    }
    final maxWidthSpaces = (constraints.hasBoundedWidth
                ? constraints.maxWidth
                : 40 * _staffSpace) /
            _staffSpace -
        braceInset;
    final systems = layoutGrandStaffSystems(
      _grandStaff,
      _settingsFor(metadata),
      maxWidth: math.max(8.0, maxWidthSpaces),
      staffGap: _staffGap,
    );
    _systems = systems;
    final width =
        systems.systems.fold<double>(0, (m, s) => math.max(m, s.layout.width)) +
            braceInset;
    return constraints.constrain(Size(
      width * _staffSpace,
      systems.heightWith(_systemGap) * _staffSpace,
    ));
  }

  @override
  void performLayout() {
    if (MusicFonts.metadataOrNull(_theme.musicFont) == null) {
      MusicFonts.load(_theme.musicFont).then((_) {
        if (attached) markNeedsLayout();
      });
    }
    _painter.clearCache();
    size = _measure(constraints);
    _painter.scale = _staffSpace;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints);

  String? _findIn(ScoreLayout staff, Offset origin, Offset local) {
    final point = math.Point(
      (local.dx - origin.dx) / _staffSpace,
      (local.dy - origin.dy) / _staffSpace,
    );
    final slop = _theme.hitSlop;
    String? bestId;
    var bestArea = double.infinity;
    for (final region in staff.regions) {
      final b = region.bounds;
      final inflated = math.Rectangle(
          b.left - slop, b.top - slop, b.width + 2 * slop, b.height + 2 * slop);
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

  /// The id of the element under [local] on any staff of any system, or null.
  String? elementIdAt(Offset local) {
    final systems = _systems;
    if (systems == null) return null;
    for (var i = 0; i < systems.systems.length; i++) {
      final layout = systems.systems[i].layout;
      final id = _findIn(layout.upper, upperOrigin(i), local) ??
          _findIn(layout.lower, lowerOrigin(i), local);
      if (id != null) return id;
    }
    return null;
  }

  /// The empty-staff location under [local]: the nearest system, then the
  /// nearer of its two staves, quantized to the nearest line/space.
  StaffTarget? resolveStaffTarget(Offset local) {
    final systems = _systems;
    if (systems == null || systems.systems.isEmpty) return null;

    // Nearest system band.
    var systemIndex = 0;
    var bestDist = double.infinity;
    var y = 0.0;
    for (var i = 0; i < systems.systems.length; i++) {
      final h = systems.systems[i].layout.height * _staffSpace;
      final dist = local.dy < y
          ? y - local.dy
          : (local.dy > y + h ? local.dy - (y + h) : 0.0);
      if (dist < bestDist) {
        bestDist = dist;
        systemIndex = i;
      }
      y += h + _systemGap * _staffSpace;
    }

    final system = systems.systems[systemIndex];
    // Nearer staff: upper band top..+4, lower band top..+4.
    final upperTop = upperOrigin(systemIndex).dy;
    final lowerTop = lowerOrigin(systemIndex).dy;
    final boundary = (upperTop + 4 * _staffSpace + lowerTop) / 2;
    final staffIndex = local.dy < boundary ? 0 : 1;
    final staffLayout =
        staffIndex == 0 ? system.layout.upper : system.layout.lower;
    final origin =
        staffIndex == 0 ? upperOrigin(systemIndex) : lowerOrigin(systemIndex);

    final point = math.Point(
      (local.dx - origin.dx) / _staffSpace,
      (local.dy - origin.dy) / _staffSpace,
    );
    final staffPosition = (8 - 2 * point.y).round().clamp(-6, 14);
    var localMeasure = 0;
    for (final region in staffLayout.measureRegions) {
      if (region.startX <= point.x) {
        localMeasure = region.index;
      } else {
        break;
      }
    }
    return StaffTarget(
      staffPosition: staffPosition,
      measureIndex: system.firstMeasure + localMeasure,
      systemIndex: systemIndex,
      staffIndex: staffIndex,
    );
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
    } else if (onStaffTap != null) {
      final target = resolveStaffTarget(details.localPosition);
      if (target != null) onStaffTap!.call(target);
    }
  }

  @override
  void dispose() {
    _tap.dispose();
    _painter.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ paint

  @override
  void paint(PaintingContext context, Offset offset) {
    final systems = _systems;
    if (systems == null) return;
    final canvas = context.canvas;
    final braceBox =
        MusicFonts.metadataOrNull(_theme.musicFont)?.bBoxOf('brace');

    for (var i = 0; i < systems.systems.length; i++) {
      final layout = systems.systems[i].layout;
      final upper = offset + upperOrigin(i);
      final lower = offset + lowerOrigin(i);
      _painter.paintLayout(canvas, upper, layout.upper);
      _painter.paintLayout(canvas, lower, layout.lower);

      // Barline connectors between the staves.
      final barPaint = Paint()..color = _theme.staffColor;
      void connect(double xSpaces, double thickness) {
        canvas.drawLine(
          upper + Offset(xSpaces * _staffSpace, 4 * _staffSpace),
          lower + Offset(xSpaces * _staffSpace, 0),
          barPaint..strokeWidth = thickness * _staffSpace,
        );
      }

      final lines = layout.upper.primitives.whereType<LinePrimitive>();
      if (lines.isNotEmpty) connect(0, lines.first.thickness);
      for (final line in lines) {
        final vertical = line.from.x == line.to.x;
        final fullStaff = line.from.y == 0 && line.to.y == 4 ||
            line.from.y == 4 && line.to.y == 0;
        if (vertical && fullStaff) connect(line.from.x, line.thickness);
      }

      // Brace.
      if (braceBox != null) {
        final spanSpaces = 4 + layout.staffGap + 4;
        _painter.paintGlyph(
          canvas,
          lower,
          'brace',
          math.Point(-braceInset + 0.15, 4.0),
          _theme.staffColor,
          glyphScale: spanSpaces / braceBox.height,
        );
      }
    }
  }
}

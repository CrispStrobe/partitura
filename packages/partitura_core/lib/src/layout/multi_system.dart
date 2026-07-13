/// Line breaking: wrap a score into systems of a target width.
library;

import '../model/score.dart';
import 'layout_engine.dart';
import 'layout_settings.dart';
import 'score_layout.dart';
import 'system_break.dart';

/// One system (line) of a broken score.
class SystemLayout {
  /// The laid-out line.
  final ScoreLayout layout;

  /// Index of the first original measure on this system.
  final int firstMeasure;

  /// Index of the last original measure on this system (inclusive).
  final int lastMeasure;

  /// Creates a system layout.
  const SystemLayout({
    required this.layout,
    required this.firstMeasure,
    required this.lastMeasure,
  });

  @override
  String toString() => 'SystemLayout(measures $firstMeasure..$lastMeasure, '
      'width ${layout.width})';
}

/// A score broken into systems.
class MultiSystemLayout {
  /// The systems, top to bottom.
  final List<SystemLayout> systems;

  /// The width every non-final system was justified to.
  final double maxWidth;

  /// Creates a multi-system layout.
  const MultiSystemLayout({required this.systems, required this.maxWidth});

  /// Total height in staff spaces when systems are stacked [systemGap]
  /// spaces apart (bounding box to bounding box).
  double heightWith(double systemGap) {
    var height = 0.0;
    for (final system in systems) {
      height += system.layout.height;
    }
    return height + systemGap * (systems.length - 1);
  }

  @override
  String toString() => 'MultiSystemLayout(${systems.length} systems)';
}

/// Breaks [score] into systems no wider than [maxWidth] staff spaces and
/// justifies every system except the last to exactly that width
/// (via uniform spacing stretch; disable with [justify]).
///
/// Every system restates the clef and key signature current at its first
/// measure; the time signature appears only on the first system and at
/// explicit changes. Non-final systems close with a plain thin barline;
/// only the last carries the end-of-score barline. Slurs, dynamics and hairpins whose endpoints fall on
/// different systems are dropped (ties degrade gracefully on their own).
/// A measure wider than [maxWidth] gets its own (overwide) system rather
/// than failing.
MultiSystemLayout layoutSystems(
  Score score,
  LayoutSettings settings, {
  required double maxWidth,
  bool justify = true,
}) {
  const engine = LayoutEngine();
  if (maxWidth <= 0) {
    throw ArgumentError.value(maxWidth, 'maxWidth', 'must be positive');
  }

  // Natural widths of every measure, plus the running clef/key/time state
  // at each measure start.
  final natural = engine.layout(score, settings);
  final measureCount = score.measures.length;
  final state = SystemBreakState.of(score);

  // The time signature is drawn on the first system and where a system
  // starts on an explicit change (the change glyph moves into the leading
  // segment).
  bool drawTimeFor(int firstMeasure) => drawsTimeAt(score, firstMeasure);

  // The system's leading segment (clef/key/time restatement) is re-laid
  // per system; measure a one-measure probe for its exact width.
  double leadingWidthFor(int firstMeasure) {
    final probe = engine.layout(
      sliceScore(score, firstMeasure, firstMeasure, state),
      settings,
      drawTimeSignature: drawTimeFor(firstMeasure),
    );
    return probe.measureRegions.first.startX;
  }

  // Cumulative positions from the natural layout are exact for everything
  // between measure starts (barlines, repeat signs, inline changes).
  final finalBarAllowance = natural.width - natural.measureRegions.last.endX;

  final systems = <SystemLayout>[];
  var start = 0;
  while (start < measureCount) {
    // Greedy packing: extend while the estimated width still fits. The
    // first measure always goes on the line, even overwide.
    final leading = leadingWidthFor(start);
    var end = start;
    while (end + 1 < measureCount &&
        leading +
                (natural.measureRegions[end + 1].endX -
                    natural.measureRegions[start].startX) +
                finalBarAllowance <=
            maxWidth) {
      end++;
    }
    final drawTime = drawTimeFor(start);
    var slice = sliceScore(score, start, end, state);
    var layout = engine.layout(slice, settings,
        drawTimeSignature: drawTime, finalBarline: end == measureCount - 1);
    // Safety trim: if the estimate was ever optimistic, push measures to
    // the next system rather than overflow.
    while (layout.width > maxWidth && end > start) {
      end--;
      slice = sliceScore(score, start, end, state);
      layout = engine.layout(slice, settings,
          drawTimeSignature: drawTime, finalBarline: end == measureCount - 1);
    }
    final isLastSystem = end == measureCount - 1;
    if (justify && !isLastSystem && layout.width < maxWidth) {
      // Binary-search the uniform spacing stretch to hit maxWidth.
      var low = 1.0, high = 4.0;
      for (var iteration = 0; iteration < 24; iteration++) {
        final mid = (low + high) / 2;
        final candidate = engine.layout(slice, settings,
            spacingStretch: mid,
            drawTimeSignature: drawTime,
            finalBarline: false);
        if (candidate.width > maxWidth) {
          high = mid;
        } else {
          low = mid;
          layout = candidate;
          if (maxWidth - candidate.width < 0.05) break;
        }
      }
    }
    systems.add(
      SystemLayout(layout: layout, firstMeasure: start, lastMeasure: end),
    );
    start = end + 1;
  }
  return MultiSystemLayout(systems: systems, maxWidth: maxWidth);
}

/// Multi-part document model: a whole piece as N parts that line-break
/// together into multi-staff systems and paginate, with barlines spanning
/// chosen groups of parts. Generalizes the single-system [StaffSystem] to a
/// full document, and the all-or-nothing `connectBarlines` to per-group
/// [BarlineGroup] spans.
library;

import '../internal/util.dart';
import '../model/score.dart';
import 'layout_engine.dart';
import 'layout_settings.dart';
import 'score_layout.dart';
import 'staff_system.dart';

/// A contiguous run of parts [first]..[last] (inclusive, 0-based) whose
/// barlines are drawn through the inter-staff gaps within the group — the
/// "custom-span barline". Parts outside every group get their own per-staff
/// barlines (no connection to their neighbours).
///
/// A single group spanning all parts reproduces the old
/// `StaffSystem.connectBarlines: true` (one continuous systemic barline); a
/// document with two groups (e.g. strings connected, winds connected, but the
/// barline broken between the sections) is the feature single-part layout
/// could not express.
class BarlineGroup {
  /// First part index in the group (0-based).
  final int first;

  /// Last part index in the group (inclusive).
  final int last;

  /// Creates a barline group over parts [first]..[last].
  const BarlineGroup(this.first, this.last)
      : assert(last >= first, 'last must be >= first'),
        assert(first >= 0, 'first must be >= 0');

  /// Whether part [index] falls inside this group.
  bool contains(int index) => index >= first && index <= last;

  @override
  bool operator ==(Object other) =>
      other is BarlineGroup && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'BarlineGroup($first..$last)';
}

/// A whole piece as N [parts] (each part a [Score] with the same measure count
/// and meter). Line-breaks into multi-staff systems and paginates as one
/// document, drawing [brackets] at the left edge and barlines per
/// [barlineGroups].
///
/// Element ids should be unique across parts so interaction stays unambiguous.
class MultiPartScore {
  /// The parts, top to bottom.
  final List<Score> parts;

  /// Bracket/brace groups drawn at the left edge (may be empty or nested).
  final List<StaffBracket> brackets;

  /// Contiguous part-index runs whose barlines connect through the group. An
  /// empty list means the barlines connect through the whole system (one
  /// implicit group over every part) — see [effectiveBarlineGroups].
  final List<BarlineGroup> barlineGroups;

  /// Creates a multi-part score from [parts] (at least one).
  const MultiPartScore(
    this.parts, {
    this.brackets = const [],
    this.barlineGroups = const [],
  }) : assert(parts.length > 0, 'a document needs at least one part');

  /// The measure count shared by every part (taken from the first part).
  int get measureCount => parts.first.measures.length;

  /// The barline groups to draw: [barlineGroups] as given, or — when that is
  /// empty — a single group spanning every part (fully connected barlines,
  /// like `StaffSystem.connectBarlines: true`).
  List<BarlineGroup> get effectiveBarlineGroups => barlineGroups.isNotEmpty
      ? barlineGroups
      : [BarlineGroup(0, parts.length - 1)];

  /// This document with every transposing part shown at concert (sounding)
  /// pitch — the concert-pitch toggle. Non-transposing parts are unchanged.
  MultiPartScore atConcertPitch() => MultiPartScore(
        [for (final part in parts) part.atConcertPitch()],
        brackets: brackets,
        barlineGroups: barlineGroups,
      );

  @override
  bool operator ==(Object other) =>
      other is MultiPartScore &&
      listEquals(other.parts, parts) &&
      listEquals(other.brackets, brackets) &&
      listEquals(other.barlineGroups, barlineGroups);

  @override
  int get hashCode => Object.hash(Object.hashAll(parts),
      Object.hashAll(brackets), Object.hashAll(barlineGroups));

  @override
  String toString() => 'MultiPartScore(${parts.length} parts)';
}

/// The vertical extent of one [BarlineGroup]'s connected barlines within a
/// system, in system-space y (staff spaces from the system's coordinate
/// origin): from the top line of the group's first part to the bottom line
/// (y = 4) of its last part. The gap between one span's [bottom] and the next
/// span's [top] is exactly where the systemic barline breaks between groups.
class BarlineSpan {
  /// The group this span connects.
  final BarlineGroup group;

  /// System y of the top staff line of [BarlineGroup.first].
  final double top;

  /// System y of the bottom staff line (y = 4) of [BarlineGroup.last].
  final double bottom;

  /// Creates a barline span.
  const BarlineSpan({
    required this.group,
    required this.top,
    required this.bottom,
  });

  @override
  String toString() => 'BarlineSpan($group, $top..$bottom)';
}

/// One laid-out multi-part system: one [ScoreLayout] per part (all sharing
/// leading width, per-measure widths and total width, so barlines align),
/// stacked [staffGap] staff-spaces apart. Generalizes [StaffSystemLayout] to
/// carry the [source] document's bracket and barline-group structure, plus the
/// [firstMeasure]..[lastMeasure] range this system covers (for pagination).
class MultiPartSystemLayout {
  /// The per-part layouts, top to bottom.
  final List<ScoreLayout> parts;

  /// Line-to-line vertical distance between adjacent parts, in staff spaces.
  final double staffGap;

  /// The source document (for its brackets and barline groups).
  final MultiPartScore source;

  /// Index of the first original measure on this system.
  final int firstMeasure;

  /// Index of the last original measure on this system (inclusive).
  final int lastMeasure;

  /// Creates a multi-part system layout.
  const MultiPartSystemLayout({
    required this.parts,
    required this.staffGap,
    required this.source,
    required this.firstMeasure,
    required this.lastMeasure,
  });

  /// Shared total width in staff spaces.
  double get width => parts.first.width;

  /// The system-space y of part [i]'s top line (y = 0 in its own coords).
  double staffTop(int i) => i * (4 + staffGap);

  /// The topmost inked y (may be negative — ink above the first part).
  double get top {
    var t = double.infinity;
    for (var i = 0; i < parts.length; i++) {
      final s = staffTop(i) + parts[i].top;
      if (s < t) t = s;
    }
    return t;
  }

  /// Total inked height in staff spaces.
  double get height {
    var bottom = double.negativeInfinity;
    for (var i = 0; i < parts.length; i++) {
      final b = staffTop(i) + parts[i].top + parts[i].height;
      if (b > bottom) bottom = b;
    }
    return bottom - top;
  }

  /// The vertical extents of the systemic barlines, one [BarlineSpan] per
  /// effective barline group. A barline drawn at any x in [barlineXs] runs
  /// continuously over each span and breaks in the gap between spans.
  List<BarlineSpan> get barlineSpans => [
        for (final group in source.effectiveBarlineGroups)
          BarlineSpan(
            group: group,
            top: staffTop(group.first),
            bottom: staffTop(group.last) + 4,
          ),
      ];

  /// The shared x positions (staff spaces, ascending) at which systemic
  /// barlines are drawn: the left system line at x = 0 plus every full-staff
  /// vertical barline. Because the parts share their measure widths these are
  /// identical across parts, so they are read once from the first part.
  List<double> get barlineXs {
    final xs = <double>{0.0};
    for (final line in parts.first.primitives.whereType<LinePrimitive>()) {
      final vertical = line.from.x == line.to.x;
      final fullStaff = (line.from.y == 0 && line.to.y == 4) ||
          (line.from.y == 4 && line.to.y == 0);
      if (vertical && fullStaff) xs.add(line.from.x);
    }
    return xs.toList()..sort();
  }

  @override
  String toString() => 'MultiPartSystemLayout(${parts.length} parts, measures '
      '$firstMeasure..$lastMeasure, ${width}x$height)';
}

/// Lays out one system of a [document]: each part is laid out once to find its
/// natural leading and per-measure widths, then all parts are laid out again
/// with the column-wise maxima so barlines align across every part.
///
/// [drawTimeSignature] and [finalBarline] are forwarded to the engine (the
/// line breaker in [layoutMultiPartSystems] uses them for interior systems).
/// [firstMeasure]/[lastMeasure] record which original measures this system
/// covers; they default to the whole document.
///
/// Throws an [ArgumentError] if the parts disagree on measure count.
MultiPartSystemLayout layoutMultiPartSystem(
  MultiPartScore document,
  LayoutSettings settings, {
  double staffGap = 4.0,
  bool drawTimeSignature = true,
  bool finalBarline = true,
  int? firstMeasure,
  int? lastMeasure,
}) {
  const engine = LayoutEngine();
  final natural = [
    for (final part in document.parts)
      engine.layout(part, settings, drawTimeSignature: drawTimeSignature),
  ];

  final measureCount = natural.first.measureRegions.length;
  for (final layout in natural) {
    if (layout.measureRegions.length != measureCount) {
      throw ArgumentError('document parts must have the same measure count');
    }
  }

  double leadingOf(ScoreLayout l) =>
      l.measureRegions.isEmpty ? l.width : l.measureRegions.first.startX;
  var leading = 0.0;
  for (final l in natural) {
    leading = _max(leading, leadingOf(l));
  }

  final measureWidths = <double>[
    for (var i = 0; i < measureCount; i++)
      natural
          .map((l) => l.measureRegions[i].endX - l.measureRegions[i].startX)
          .reduce(_max),
  ];

  return MultiPartSystemLayout(
    parts: [
      for (final part in document.parts)
        engine.layout(
          part,
          settings,
          leadingWidth: leading,
          measureWidths: measureWidths,
          drawTimeSignature: drawTimeSignature,
          finalBarline: finalBarline,
        ),
    ],
    staffGap: staffGap,
    source: document,
    firstMeasure: firstMeasure ?? 0,
    lastMeasure: lastMeasure ?? measureCount - 1,
  );
}

double _max(double a, double b) => a > b ? a : b;

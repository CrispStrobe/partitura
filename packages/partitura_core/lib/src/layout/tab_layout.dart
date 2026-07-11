/// Tablature layout: renders a [Score]'s pitches as fret numbers on an
/// N-line string staff, using a [Tuning]. Produces the same [ScoreLayout]
/// primitives as the notation engine, so the Flutter renderer and the
/// interaction layer work unchanged.
///
/// This is a parallel notation mode: each note's pitch is assigned to the
/// lowest-fret (string, fret) on the tuning, drawn as a digit centered on its
/// string line (the line is broken behind the digit). Rhythm stems/beams are
/// a later slice.
library;

import 'dart:math';

import '../model/element.dart';
import '../model/score.dart';
import '../smufl/glyph_names.dart';
import '../theory/duration.dart';
import '../theory/tuning.dart';
import 'layout_settings.dart';
import 'score_layout.dart';

/// Lays out a [Score] as tablature for a [Tuning].
class TabLayoutEngine {
  /// Creates a tab layout engine.
  const TabLayoutEngine();

  /// Vertical distance between adjacent string lines, in staff spaces.
  static const double lineGap = 1.5;

  /// Em size of a fret digit, in staff spaces.
  static const double fretSize = 1.4;

  /// Lays [score] out as tablature for [tuning].
  ScoreLayout layout(Score score, Tuning tuning, LayoutSettings settings) {
    final n = tuning.stringCount;
    final s = settings;
    final meta = s.metadata;
    final primitives = <LayoutPrimitive>[];
    final regions = <ElementRegion>[];
    final measureRegions = <MeasureRegion>[];
    // Per string line: occupied x-ranges (so lines break behind digits).
    final breaks = List.generate(n, (_) => <(double, double)>[]);

    double yOfString(int i) => i * lineGap;
    final bottomY = (n - 1) * lineGap;

    // Leading: the TAB clef, vertically centered on the staff.
    final clefGlyph =
        n <= 4 ? SmuflGlyph.fourStringTabClef : SmuflGlyph.sixStringTabClef;
    final clefBox = meta.bBoxOf(clefGlyph);
    var x = 0.5;
    // Clef origin so its bbox centers on the staff mid-line.
    final clefBaseline = bottomY / 2 + (clefBox.neY + clefBox.swY) / 2;
    primitives.add(GlyphPrimitive(clefGlyph, Point(x, clefBaseline)));
    x += clefBox.width + 1.2;

    for (var m = 0; m < score.measures.length; m++) {
      final measure = score.measures[m];
      final startX = x;
      for (final element in measure.elements) {
        if (element is! NoteElement) {
          // Rests advance the column but draw nothing on the strings.
          x += _advance(element.duration, s);
          continue;
        }
        var left = double.infinity;
        var right = -double.infinity;
        for (final pitch in element.pitches) {
          final place = tuning.fretFor(pitch);
          if (place == null) continue;
          final (stringIndex, fret) = place;
          final text = '$fret';
          final halfW = 0.28 * fretSize * text.length;
          final y = yOfString(stringIndex);
          primitives.add(TextPrimitive(
            text,
            Point(x, y + 0.32 * fretSize), // baseline → centered on the line
            size: fretSize,
            elementId: element.id,
          ));
          breaks[stringIndex].add((x - halfW - 0.1, x + halfW + 0.1));
          left = min(left, x - halfW);
          right = max(right, x + halfW);
        }
        if (element.id != null && left.isFinite) {
          regions.add(ElementRegion(
            element.id!,
            Rectangle(left, -0.3, right - left, bottomY + 0.6),
          ));
        }
        x += _advance(element.duration, s);
      }
      // Barline after the measure.
      x = max(x, startX + 2.0);
      measureRegions.add(MeasureRegion(m, startX: startX, endX: x));
      final barX = x;
      primitives.add(LinePrimitive(
        Point(barX, 0),
        Point(barX, bottomY),
        thickness: s.thinBarlineThickness,
      ));
      x = barX + s.barlineGap;
    }

    final width = x;

    // String lines, broken behind any digits.
    for (var i = 0; i < n; i++) {
      final y = yOfString(i);
      final ranges = [...breaks[i]]..sort((a, b) => a.$1.compareTo(b.$1));
      var cursor = 0.0;
      for (final (bl, br) in ranges) {
        if (bl > cursor) {
          primitives.insert(
            0,
            LinePrimitive(Point(cursor, y), Point(bl, y),
                thickness: s.staffLineThickness),
          );
        }
        cursor = max(cursor, br);
      }
      if (cursor < width) {
        primitives.insert(
          0,
          LinePrimitive(Point(cursor, y), Point(width, y),
              thickness: s.staffLineThickness),
        );
      }
    }

    const top = -0.3;
    return ScoreLayout(
      width: width,
      height: bottomY + 0.6,
      top: top,
      primitives: List.unmodifiable(primitives),
      regions: List.unmodifiable(regions),
      measureRegions: List.unmodifiable(measureRegions),
    );
  }

  double _advance(NoteDuration duration, LayoutSettings s) {
    final baseLog2 = duration.base == DurationBase.breve
        ? 1.0
        : -duration.base.index.toDouble();
    final dotLog2 = [0.0, log(1.5) / ln2, log(1.75) / ln2][duration.dots];
    return max(
        2.0, s.spacingBase + s.spacingPerLog2 * (4 + baseLog2 + dotLog2));
  }
}

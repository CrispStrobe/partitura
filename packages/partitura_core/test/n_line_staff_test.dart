import 'dart:convert';
import 'dart:io';

import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  late final LayoutSettings settings;
  const engine = LayoutEngine();
  setUpAll(() {
    final meta = SmuflMetadata.fromJson(jsonDecode(
        File('../partitura/assets/smufl/bravura_metadata.json')
            .readAsStringSync()) as Map<String, Object?>);
    settings = LayoutSettings(metadata: meta);
  });

  // The full-width horizontal lines starting at x = 0 are the staff lines
  // (ledger lines are short and do not start at the left edge).
  List<LinePrimitive> staffLinesOf(ScoreLayout layout) => layout.primitives
      .whereType<LinePrimitive>()
      .where((l) => l.from.x == 0 && l.from.y == l.to.y)
      .toList()
    ..sort((a, b) => a.from.y.compareTo(b.from.y));

  Score notes() => Score.simple(
      clef: Clef.percussion,
      timeSignature: TimeSignature.fourFour,
      notes: 'c5:q d5 e5 f5');

  test('a 5-line staff draws five lines at y = 0..4 (the default)', () {
    final lines = staffLinesOf(engine.layout(notes(), settings));
    expect(lines, hasLength(5));
    expect([for (final l in lines) l.from.y], [0, 1, 2, 3, 4]);
  });

  test('a 1-line staff draws a single line at y = 0', () {
    final lines =
        staffLinesOf(engine.layout(notes(), settings, staffLineCount: 1));
    expect(lines, hasLength(1));
    expect(lines.single.from.y, 0);
  });

  test('a 3-line staff draws three lines at y = 0..2', () {
    final lines =
        staffLinesOf(engine.layout(notes(), settings, staffLineCount: 3));
    expect(lines, hasLength(3));
    expect([for (final l in lines) l.from.y], [0, 1, 2]);
  });

  test('a 6-line staff draws six lines at y = 0..5', () {
    final lines =
        staffLinesOf(engine.layout(notes(), settings, staffLineCount: 6));
    expect(lines, hasLength(6));
    expect([for (final l in lines) l.from.y], [0, 1, 2, 3, 4, 5]);
  });

  test('the explicit 5-line count is byte-for-byte the default', () {
    final defaulted = engine.layout(notes(), settings);
    final explicit = engine.layout(notes(), settings, staffLineCount: 5);
    expect(explicit.width, defaulted.width);
    expect(explicit.height, defaulted.height);
    expect(explicit.top, defaulted.top);
    expect(explicit.primitives.length, defaulted.primitives.length);
  });

  test('the staff-line count only adds/removes lines, not measure geometry',
      () {
    // Horizontal spacing is independent of the line count.
    final five = engine.layout(notes(), settings);
    final three = engine.layout(notes(), settings, staffLineCount: 3);
    expect(three.width, five.width);
    expect(three.measureRegions.first.endX,
        closeTo(five.measureRegions.first.endX, 1e-9));
  });
}

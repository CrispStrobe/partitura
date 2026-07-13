import 'dart:convert';
import 'dart:io';

import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// v0.4.2: grand staff layout.
late final SmuflMetadata metadata;
late final LayoutSettings settings;

GrandStaff demo({String upper = 'c5:q d5 e5 f5 | g5:w', String? lower}) =>
    GrandStaff(
      upper: Score.simple(
        timeSignature: TimeSignature.fourFour,
        notes: upper,
      ),
      lower: Score.simple(
        clef: Clef.bass,
        timeSignature: TimeSignature.fourFour,
        notes: lower ?? 'c3:h e3:h | c3:w',
      ),
    );

void main() {
  setUpAll(() {
    final source = File('../partitura/assets/smufl/bravura_metadata.json')
        .readAsStringSync();
    metadata =
        SmuflMetadata.fromJson(jsonDecode(source) as Map<String, Object?>);
    settings = LayoutSettings(metadata: metadata);
  });

  group('model', () {
    test('value semantics', () {
      expect(demo(), demo());
      expect(demo(), isNot(demo(upper: 'c5:w | g5:w')));
      expect(demo().hashCode, demo().hashCode);
    });

    test('measure-count mismatch fails loudly', () {
      expect(
        () => layoutGrandStaff(
          GrandStaff(
            upper: Score.simple(notes: 'c5:q | d5:q'),
            lower: Score.simple(clef: Clef.bass, notes: 'c3:q'),
          ),
          settings,
        ),
        throwsArgumentError,
      );
    });
  });

  group('alignment', () {
    test('leading widths, measure boundaries and totals align', () {
      final layout = layoutGrandStaff(demo(), settings);
      expect(layout.upper.width, closeTo(layout.lower.width, 1e-9));
      for (var i = 0; i < layout.upper.measureRegions.length; i++) {
        expect(
          layout.upper.measureRegions[i].startX,
          closeTo(layout.lower.measureRegions[i].startX, 1e-9),
          reason: 'measure $i start',
        );
        expect(
          layout.upper.measureRegions[i].endX,
          closeTo(layout.lower.measureRegions[i].endX, 1e-9),
          reason: 'measure $i end',
        );
      }
    });

    test('cross-staff onset gridding aligns simultaneous notes (§2.9)', () {
      // Upper: four quarters (onsets 0, 1/4, 1/2, 3/4). Lower: a half then two
      // quarters (onsets 0, 1/2, 3/4). The beats they share must line up.
      final layout = layoutGrandStaff(
        demo(upper: 'c5:q d5 e5 f5', lower: 'c3:h e3:q g3:q'),
        settings,
      );
      double left(ScoreLayout staff, String id) =>
          staff.regions.firstWhere((r) => r.elementId == id).bounds.left;

      // Barlines align (shared measure width).
      expect(layout.upper.measureRegions[0].endX,
          closeTo(layout.lower.measureRegions[0].endX, 1e-6));
      // Beat 1 (onset 0): upper e0 over lower e0.
      expect(left(layout.upper, 'e0'), closeTo(left(layout.lower, 'e0'), 0.01));
      // Beat 3 (onset 1/2): upper e2 (third quarter) over lower e1 (first
      // quarter after the half note).
      expect(left(layout.upper, 'e2'), closeTo(left(layout.lower, 'e1'), 0.01));
      // Beat 4 (onset 3/4): upper e3 over lower e2.
      expect(left(layout.upper, 'e3'), closeTo(left(layout.lower, 'e2'), 0.01));
    });

    test('gridAlign: false restores independent (barline-only) spacing', () {
      // The lower half note is NOT under the upper's beat 1 the same way; the
      // point here is just that turning gridding off still aligns barlines.
      final layout = layoutGrandStaff(
        demo(upper: 'c5:q d5 e5 f5', lower: 'c3:h e3:q g3:q'),
        settings,
        gridAlign: false,
      );
      expect(layout.upper.measureRegions[0].endX,
          closeTo(layout.lower.measureRegions[0].endX, 1e-6));
    });

    test('geometry helpers', () {
      final layout = layoutGrandStaff(demo(), settings, staffGap: 5);
      expect(layout.staffGap, 5);
      expect(layout.width, layout.upper.width);
      expect(layout.height, greaterThan(8 + 5));
    });

    test('deterministic', () {
      String render() {
        final layout = layoutGrandStaff(demo(), settings);
        return [
          ...layout.upper.primitives.map((p) => p.toString()),
          '---',
          ...layout.lower.primitives.map((p) => p.toString()),
        ].join('\n');
      }

      expect(render(), render());
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// Editor contract C5 (core): a grand staff wrapped into multiple systems.
late final LayoutSettings settings;

GrandStaff eightBarPiano() => GrandStaff(
      upper: Score.simple(
        timeSignature: TimeSignature.fourFour,
        notes:
            'c5:q d5 e5 f5 | g5:q a5 b5 c6 | c6:q b5 a5 g5 | f5:q e5 d5 c5 | '
            'e5:q f5 g5 a5 | b5:q a5 g5 f5 | e5:q d5 c5 d5 | c5:w',
      ),
      lower: Score.simple(
        clef: Clef.bass,
        timeSignature: TimeSignature.fourFour,
        notes: 'c3:h e3 | g3:h c4 | e3:h c3 | g2:h c3 | '
            'c3:h g3 | e3:h c3 | g3:h g2 | c3:w',
      ),
    );

void main() {
  setUpAll(() {
    final source = File('../partitura/assets/smufl/bravura_metadata.json')
        .readAsStringSync();
    settings = LayoutSettings(
      metadata:
          SmuflMetadata.fromJson(jsonDecode(source) as Map<String, Object?>),
    );
  });

  test('breaks a grand staff into aligned systems', () {
    final wrapped =
        layoutGrandStaffSystems(eightBarPiano(), settings, maxWidth: 40);
    expect(wrapped.systems.length, greaterThan(1));

    // Measures are covered contiguously across systems, and both staves of
    // each system share the same measure range.
    var expectedFirst = 0;
    for (final system in wrapped.systems) {
      expect(system.firstMeasure, expectedFirst);
      expect(system.layout.upper.measureRegions.length,
          system.lastMeasure - system.firstMeasure + 1);
      expect(system.layout.lower.measureRegions.length,
          system.layout.upper.measureRegions.length);
      expect(system.layout.width, lessThanOrEqualTo(40 + 0.01));
      expectedFirst = system.lastMeasure + 1;
    }
    expect(expectedFirst, 8); // all eight measures placed
  });

  test('the time signature is drawn only on the first system', () {
    final wrapped =
        layoutGrandStaffSystems(eightBarPiano(), settings, maxWidth: 40);
    expect(wrapped.systems.length, greaterThan(1));

    bool hasTimeSig(ScoreLayout layout) => layout.primitives
        .whereType<GlyphPrimitive>()
        .any((g) => g.smuflName == SmuflGlyph.timeSigDigits[4]);

    expect(hasTimeSig(wrapped.systems.first.layout.upper), isTrue);
    for (final system in wrapped.systems.skip(1)) {
      expect(hasTimeSig(system.layout.upper), isFalse);
      expect(hasTimeSig(system.layout.lower), isFalse);
    }
    // But every system restates the clef (both staves).
    for (final system in wrapped.systems) {
      expect(
        system.layout.upper.primitives
            .whereType<GlyphPrimitive>()
            .any((g) => g.smuflName == SmuflGlyph.gClef),
        isTrue,
      );
    }
  });

  test('measure-count mismatch and non-positive width fail loudly', () {
    expect(
      () => layoutGrandStaffSystems(
        GrandStaff(
          upper: Score.simple(notes: 'c5:q | d5:q'),
          lower: Score.simple(clef: Clef.bass, notes: 'c3:q'),
        ),
        settings,
        maxWidth: 40,
      ),
      throwsArgumentError,
    );
    expect(
      () => layoutGrandStaffSystems(eightBarPiano(), settings, maxWidth: 0),
      throwsArgumentError,
    );
  });
}

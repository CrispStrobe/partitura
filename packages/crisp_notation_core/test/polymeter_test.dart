import 'dart:convert';
import 'dart:io';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Phase 5.7 — local per-staff meters (polymeter): each staff of a
/// [StaffSystem] carries, draws and beams its own time signature, while barlines
/// stay aligned when the measures share their total duration.
void main() {
  late final LayoutSettings settings;
  setUpAll(() {
    final meta = SmuflMetadata.fromJson(jsonDecode(
        File('../crisp_notation/assets/smufl/bravura_metadata.json')
            .readAsStringSync()) as Map<String, Object?>);
    settings = LayoutSettings(metadata: meta);
  });

  List<String> timeSigGlyphs(ScoreLayout l) => l.primitives
      .whereType<GlyphPrimitive>()
      .where((g) => g.smuflName.startsWith('timeSig'))
      .map((g) => g.smuflName)
      .toList();

  // Two staves, 3/4 against 6/8 — both six eighth-notes, so the bars align.
  StaffSystem polymetricSystem() => StaffSystem([
        Score.simple(
            clef: Clef.treble,
            timeSignature: TimeSignature.threeFour,
            notes: 'c5:e d5 e5 f5 g5 a5 | c5:e d5 e5 f5 g5 a5'),
        Score.simple(
            clef: Clef.bass,
            timeSignature: const TimeSignature(6, 8),
            notes: 'c3:e d3 e3 f3 g3 a3 | c3:e d3 e3 f3 g3 a3'),
      ]);

  group('single polymetric system', () {
    test('each staff draws its own time signature', () {
      final layout = layoutStaffSystem(polymetricSystem(), settings);
      expect(timeSigGlyphs(layout.staves[0]), ['timeSig3', 'timeSig4']);
      expect(timeSigGlyphs(layout.staves[1]), ['timeSig6', 'timeSig8']);
    });

    test('barlines still align (equal total durations)', () {
      final layout = layoutStaffSystem(polymetricSystem(), settings);
      final ref = layout.staves.first.measureRegions;
      for (final part in layout.staves) {
        for (var i = 0; i < ref.length; i++) {
          expect(part.measureRegions[i].endX, closeTo(ref[i].endX, 1e-6));
        }
      }
    });

    test('each staff beams by its own meter', () {
      final layout = layoutStaffSystem(polymetricSystem(), settings);
      // 3/4 beams the eighths per beat (three pairs per bar); 6/8 beams them in
      // two groups of three — so the beam counts differ per staff.
      final b0 = layout.staves[0].primitives.whereType<BeamPrimitive>().length;
      final b1 = layout.staves[1].primitives.whereType<BeamPrimitive>().length;
      expect(b0, isNot(b1));
      expect(b0, greaterThan(0));
      expect(b1, greaterThan(0));
    });
  });

  group('wrapped polymetric document', () {
    // Eight bars per staff so it line-breaks; constant different meters.
    StaffSystem longPolymeter() {
      final top = List.generate(8, (_) => 'c5:e d5 e5 f5 g5 a5').join(' | ');
      final bot = List.generate(8, (_) => 'c3:e d3 e3 f3 g3 a3').join(' | ');
      return StaffSystem([
        Score.simple(
            clef: Clef.treble,
            timeSignature: TimeSignature.threeFour,
            notes: top),
        Score.simple(
            clef: Clef.bass,
            timeSignature: const TimeSignature(6, 8),
            notes: bot),
      ]);
    }

    test('the first system shows each staff its own meter', () {
      final wrapped =
          layoutStaffSystemSystems(longPolymeter(), settings, maxWidth: 45);
      expect(wrapped.systems.length, greaterThan(1));
      final first = wrapped.systems.first.layout;
      expect(timeSigGlyphs(first.staves[0]), ['timeSig3', 'timeSig4']);
      expect(timeSigGlyphs(first.staves[1]), ['timeSig6', 'timeSig8']);
    });

    test('constant meters are not restated on later systems', () {
      final wrapped =
          layoutStaffSystemSystems(longPolymeter(), settings, maxWidth: 45);
      for (final system in wrapped.systems.skip(1)) {
        expect(timeSigGlyphs(system.layout.staves[0]), isEmpty);
        expect(timeSigGlyphs(system.layout.staves[1]), isEmpty);
      }
    });

    test('a per-staff meter change at a system start is restated', () {
      // Staff 0 stays 3/4 throughout; staff 1 switches 6/8 -> 3/4 at bar 2.
      // Force bar 2 to begin a system (narrow width), and verify the change is
      // drawn rather than dropped because only staff 1 changed.
      final top = List.generate(4, (_) => 'c5:e d5 e5 f5 g5 a5').join(' | ');
      final doc = StaffSystem([
        Score.simple(
            clef: Clef.treble,
            timeSignature: TimeSignature.threeFour,
            notes: top),
        Score(
          clef: Clef.bass,
          timeSignature: const TimeSignature(6, 8),
          measures: [
            ...Score.simple(notes: 'c3:e d3 e3 f3 g3 a3 | c3:e d3 e3 f3 g3 a3')
                .measures
                .take(2),
            // Bars 2..3 change to 3/4 on the lower staff only.
            Measure(
              Score.simple(notes: 'c3:q d3 e3').measures.first.elements,
              timeChange: TimeSignature.threeFour,
            ),
            Score.simple(notes: 'c3:q d3 e3').measures.first,
          ],
        ),
      ]);
      final wrapped =
          layoutStaffSystemSystems(doc, settings, maxWidth: 24, justify: false);
      // Find the system that begins at bar 2 (where the lower staff changed).
      final atChange = wrapped.systems.firstWhere((s) => s.firstMeasure == 2);
      // The lower staff restates its new 3/4 at the boundary...
      expect(
          timeSigGlyphs(atChange.layout.staves[1]), ['timeSig3', 'timeSig4']);
      // ...and the (unchanged) upper staff also restates, keeping them aligned.
      expect(
          timeSigGlyphs(atChange.layout.staves[0]), ['timeSig3', 'timeSig4']);
    });
  });
}

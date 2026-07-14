import 'package:crisp_notation/crisp_notation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrispNotationTheme', () {
    test('value equality covers every field', () {
      const base = CrispNotationTheme();
      expect(base, const CrispNotationTheme());
      expect(base.hashCode, const CrispNotationTheme().hashCode);
      expect(
          base, isNot(const CrispNotationTheme(staffColor: Color(0xFF000001))));
      expect(
          base, isNot(const CrispNotationTheme(noteColor: Color(0xFF000001))));
      expect(
        base,
        isNot(const CrispNotationTheme(highlightColor: Color(0xFF000001))),
      );
      expect(base, isNot(const CrispNotationTheme(kidMode: true)));
      expect(base, isNot(const CrispNotationTheme(hitSlop: 2)));
      expect(base, isNot(const CrispNotationTheme(lineBoost: 2)));
      expect(
        base,
        isNot(
            const CrispNotationTheme(elementColors: {'x': Color(0xFF000001)})),
      );
      expect(
        const CrispNotationTheme(elementColors: {'x': Color(0xFF000001)}),
        const CrispNotationTheme(elementColors: {'x': Color(0xFF000001)}),
      );
    });

    test('copyWith replaces exactly the given fields', () {
      const original = CrispNotationTheme.kids;
      final recolored = original.copyWith(noteColor: const Color(0xFF112233));
      expect(recolored.noteColor, const Color(0xFF112233));
      expect(recolored.kidMode, original.kidMode);
      expect(recolored.hitSlop, original.hitSlop);
      expect(recolored.lineBoost, original.lineBoost);
      expect(recolored.highlightColor, original.highlightColor);

      final full = original.copyWith(
        staffColor: const Color(0xFF000001),
        noteColor: const Color(0xFF000002),
        highlightColor: const Color(0xFF000003),
        elementColors: const {'a': Color(0xFF000004)},
        kidMode: false,
        hitSlop: 0.25,
        lineBoost: 2.0,
      );
      expect(full.staffColor, const Color(0xFF000001));
      expect(full.noteColor, const Color(0xFF000002));
      expect(full.highlightColor, const Color(0xFF000003));
      expect(full.elementColors, const {'a': Color(0xFF000004)});
      expect(full.kidMode, isFalse);
      expect(full.hitSlop, 0.25);
      expect(full.lineBoost, 2.0);
      // copyWith with no arguments is identity by value.
      expect(original.copyWith(), original);
    });

    test('presets encode the kid-mode ergonomics contract', () {
      expect(CrispNotationTheme.standard.kidMode, isFalse);
      expect(CrispNotationTheme.kids.kidMode, isTrue);
      expect(
        CrispNotationTheme.kids.hitSlop,
        greaterThan(CrispNotationTheme.standard.hitSlop),
      );
      expect(
        CrispNotationTheme.kids.lineBoost,
        greaterThan(CrispNotationTheme.standard.lineBoost),
      );
    });
  });

  group('GhostNote', () {
    test('value equality', () {
      const a = GhostNote(
        xSpaces: 5,
        staffPosition: 2,
        duration: NoteDuration.quarter,
      );
      expect(
        a,
        const GhostNote(
          xSpaces: 5,
          staffPosition: 2,
          duration: NoteDuration.quarter,
        ),
      );
      expect(
        a.hashCode,
        const GhostNote(
          xSpaces: 5,
          staffPosition: 2,
          duration: NoteDuration.quarter,
        ).hashCode,
      );
      expect(
        a,
        isNot(const GhostNote(
          xSpaces: 6,
          staffPosition: 2,
          duration: NoteDuration.quarter,
        )),
      );
      expect(
        a,
        isNot(const GhostNote(
          xSpaces: 5,
          staffPosition: 3,
          duration: NoteDuration.quarter,
        )),
      );
      expect(
        a,
        isNot(const GhostNote(
          xSpaces: 5,
          staffPosition: 2,
          duration: NoteDuration.half,
        )),
      );
    });
  });

  group('StaffTarget', () {
    test('value equality and toString', () {
      const target = StaffTarget(staffPosition: 4, measureIndex: 1);
      expect(target, const StaffTarget(staffPosition: 4, measureIndex: 1));
      expect(
        target,
        isNot(const StaffTarget(staffPosition: 5, measureIndex: 1)),
      );
      expect(
        target,
        isNot(const StaffTarget(staffPosition: 4, measureIndex: 0)),
      );
      expect(target.toString(), contains('position 4'));
      expect(target.toString(), contains('measure 1'));
    });

    test('pitchFor covers the full quantization range in both clefs', () {
      for (final clef in Clef.values) {
        for (var position = -6; position <= 14; position++) {
          final target = StaffTarget(staffPosition: position, measureIndex: 0);
          final pitch = target.pitchFor(clef);
          expect(pitch.staffPosition(clef), position,
              reason: '$clef position $position');
          expect(pitch.alter, 0);
          expect(
            target.pitchFor(clef, preferredAlter: 1).alter,
            1,
            reason: '$clef position $position sharp',
          );
        }
      }
    });
  });
}

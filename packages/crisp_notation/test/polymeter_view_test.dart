import 'package:crisp_notation/crisp_notation.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';

import 'test_setup.dart';

/// Phase 5.7 — polymeter: two staves in different meters (3/4 over 6/8) drawn as
/// one system, each with its own time signature and beaming, barlines aligned.
void main() {
  setUpAll(setUpCrispNotationForTests);

  testWidgets('127 polymeter: 3/4 over 6/8', (tester) async {
    final system = StaffSystem([
      Score.simple(
          clef: Clef.treble,
          timeSignature: TimeSignature.threeFour,
          notes: 'c5:e d5 e5 f5 g5 a5 | b5:e a5 g5 f5 e5 d5'),
      Score.simple(
          clef: Clef.bass,
          timeSignature: const TimeSignature(6, 8),
          notes: 'c3:e d3 e3 f3 g3 a3 | b2:e c3 d3 e3 f3 g3'),
    ], brackets: const [
      StaffBracket(0, 1, kind: StaffBracketKind.brace)
    ]);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: StaffSystemView(system: system, staffSpace: 12),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/127_polymeter.png'),
    );
  });
}

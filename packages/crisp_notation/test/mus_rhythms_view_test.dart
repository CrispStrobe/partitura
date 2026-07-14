import 'package:crisp_notation/crisp_notation.dart';
import 'package:flutter/material.dart' hide Step;
import 'package:flutter_test/flutter_test.dart';

import 'test_setup.dart';

/// A regression canary for the *consumer's* (KlangUniversum / `../mus`) real
/// rhythmic vocabulary: its content bottoms out at the sixteenth, in simple and
/// compound meters (4/4, 2/4, 3/4, 6/8, cut/common). This golden locks in that
/// the beam engine keeps rendering those patterns the textbook way as it
/// evolves — four 16ths beam solid within a beat (continuous secondary), eighth
/// pairs beam per beat, a dotted-8th + 16th shows a beamlet stub, and a 6/8 bar
/// groups its eighths in threes.
void main() {
  setUpAll(setUpCrispNotationForTests);

  testWidgets('128 learning-app rhythms (16ths, dotted, 6/8)', (tester) async {
    final score = Score(
      clef: Clef.treble,
      timeSignature: TimeSignature.fourFour,
      measures: [
        // 4/4: four 16ths | two 8ths | dotted-8th + 16th | quarter.
        Score.simple(
          timeSignature: TimeSignature.fourFour,
          notes: 'c5:s d5 e5 f5 g5:e a5 b5:e. c6:s a5:q',
        ).measures.first,
        // 6/8: two beamed groups of three eighths.
        Measure(
          Score.simple(notes: 'g5:e a5 b5 c6:e b5 a5').measures.first.elements,
          timeChange: TimeSignature.sixEight,
        ),
      ],
    );
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
                child: StaffView(score: score, staffSpace: 12),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/128_learning_rhythms.png'),
    );
  });
}

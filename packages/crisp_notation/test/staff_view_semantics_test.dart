import 'package:crisp_notation/crisp_notation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_setup.dart';

// Collects every non-empty semantics label under [node].
List<String> _labels(SemanticsNode node) {
  final out = <String>[];
  void walk(SemanticsNode n) {
    final label = n.getSemanticsData().label;
    if (label.isNotEmpty) out.add(label);
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(node);
  return out;
}

void main() {
  setUpAll(setUpCrispNotationForTests);

  testWidgets('StaffView exposes a spoken label per note (3.9)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: StaffView(
            score: Score.simple(notes: 'c4:q e4 g4'),
            staffSpace: 12,
          ),
        ),
      ),
    );

    final labels = _labels(tester.getSemantics(find.byType(StaffView)));
    expect(labels, contains('C 4 quarter note'));
    expect(labels, contains('E 4 quarter note'));
    expect(labels, contains('G 4 quarter note'));
    handle.dispose();
  });

  testWidgets('the labels update when the score changes', (tester) async {
    final handle = tester.ensureSemantics();
    Widget build(String notes) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: StaffView(score: Score.simple(notes: notes), staffSpace: 12),
          ),
        );
    await tester.pumpWidget(build('c4:q'));
    expect(_labels(tester.getSemantics(find.byType(StaffView))),
        contains('C 4 quarter note'));

    await tester.pumpWidget(build('d4:h'));
    final labels = _labels(tester.getSemantics(find.byType(StaffView)));
    expect(labels, contains('D 4 half note'));
    expect(labels, isNot(contains('C 4 quarter note')));
    handle.dispose();
  });
}

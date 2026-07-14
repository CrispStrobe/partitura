import 'package:crisp_notation/crisp_notation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_setup.dart';

void main() {
  setUpAll(setUpCrispNotationForTests);

  Widget wrap(Widget child) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      );

  testWidgets('sizes to tuning × frets', (tester) async {
    await tester.pumpWidget(wrap(
      const FretboardView(frets: 12, fretWidth: 26, stringSpacing: 14),
    ));
    final size = tester.getSize(find.byType(FretboardView));
    // width = openWidth(=fretWidth) + frets*fretWidth; 6 strings tall.
    expect(size.width, 26 + 12 * 26);
    expect(size.height, (6 - 1) * 14 + 2 * (14 * 0.75));
  });

  testWidgets('bass tuning changes the string count', (tester) async {
    await tester.pumpWidget(wrap(
      const FretboardView(
          tuning: FretboardView.standardBass, stringSpacing: 14),
    ));
    // 4 strings.
    expect(tester.getSize(find.byType(FretboardView)).height,
        (4 - 1) * 14 + 2 * (14 * 0.75));
  });

  testWidgets('repaints on highlight change without error', (tester) async {
    Widget build(Set<int> lit) => wrap(FretboardView(highlightedPitches: lit));
    // Open E major, then a moved shape (fretted + open positions).
    await tester.pumpWidget(build({40, 47, 52, 56, 59, 64}));
    await tester.pumpWidget(build({43, 50, 55}));
    expect(tester.takeException(), isNull);
  });
}

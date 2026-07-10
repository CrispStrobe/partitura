import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partitura/partitura.dart';

void main() {
  testWidgets('StaffView renders both clefs without errors', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            StaffView(),
            StaffView(clef: Clef.bass, staffSpace: 16),
          ],
        ),
      ),
    );

    expect(find.byType(StaffView), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

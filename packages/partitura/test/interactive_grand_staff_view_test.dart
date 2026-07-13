import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partitura/partitura.dart';

import 'test_setup.dart';

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

Widget wrap(Widget child, {double width = 400}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: width, child: child)),
    );

RenderInteractiveGrandStaffView renderOf(WidgetTester tester) =>
    tester.renderObject<RenderInteractiveGrandStaffView>(
        find.bySubtype<InteractiveGrandStaffView>());

void main() {
  setUpAll(setUpPartituraForTests);

  testWidgets('wraps a grand staff into multiple systems', (tester) async {
    await tester.pumpWidget(
      wrap(InteractiveGrandStaffView(
          grandStaff: eightBarPiano(), staffSpace: 10)),
    );
    expect(tester.takeException(), isNull);
    final systems = renderOf(tester).grandStaffSystems!;
    expect(systems.systems.length, greaterThan(1));
  });

  testWidgets('element tap on either staff reports the id', (tester) async {
    final ids = <String>[];
    await tester.pumpWidget(
      wrap(InteractiveGrandStaffView(
        grandStaff: eightBarPiano(),
        staffSpace: 10,
        onElementTap: ids.add,
      )),
    );
    final render = renderOf(tester);
    final systems = render.grandStaffSystems!;
    final topLeft =
        tester.getTopLeft(find.bySubtype<InteractiveGrandStaffView>());

    // First upper-staff note of system 0.
    final upperBounds = systems.systems[0].layout.upper.regions
        .firstWhere((r) => r.elementId == 'e0')
        .bounds;
    final upperCenter = (upperBounds.topLeft + upperBounds.bottomRight) * 0.5;
    await tester.tapAt(topLeft +
        render.upperOrigin(0) +
        Offset(upperCenter.x * render.scale, upperCenter.y * render.scale));
    await tester.pump(const Duration(milliseconds: 400));

    // First lower-staff note of system 0.
    final lowerBounds = systems.systems[0].layout.lower.regions
        .firstWhere((r) => r.elementId == 'e0')
        .bounds;
    final lowerCenter = (lowerBounds.topLeft + lowerBounds.bottomRight) * 0.5;
    await tester.tapAt(topLeft +
        render.lowerOrigin(0) +
        Offset(lowerCenter.x * render.scale, lowerCenter.y * render.scale));
    await tester.pump(const Duration(milliseconds: 400));

    // Both staves start their ids at e0 (unique-id contract is the caller's).
    expect(ids, ['e0', 'e0']);
  });

  testWidgets('staff tap resolves system, staff and quantized position',
      (tester) async {
    final targets = <StaffTarget>[];
    await tester.pumpWidget(
      wrap(InteractiveGrandStaffView(
        grandStaff: eightBarPiano(),
        staffSpace: 10,
        onStaffTap: targets.add,
      )),
    );
    final render = renderOf(tester);
    final systems = render.grandStaffSystems!;

    Offset upperProbe(int system, double xSpaces, double ySpaces) =>
        render.upperOrigin(system) +
        Offset(xSpaces * render.scale, ySpaces * render.scale);
    Offset lowerProbe(int system, double xSpaces, double ySpaces) =>
        render.lowerOrigin(system) +
        Offset(xSpaces * render.scale, ySpaces * render.scale);

    // Top line of the upper staff, system 0, first measure -> staff 0, pos 8.
    final um0 = systems.systems[0].layout.upper.measureRegions.first;
    final up = render.resolveStaffTarget(upperProbe(0, um0.startX + 2, 0))!;
    expect(up.systemIndex, 0);
    expect(up.staffIndex, 0);
    expect(up.staffPosition, 8);
    expect(up.measureIndex, 0);

    // Middle line of the lower staff, last system -> staff 1, pos 4.
    final last = systems.systems.length - 1;
    final lm = systems.systems[last].layout.lower.measureRegions.first;
    final low = render.resolveStaffTarget(lowerProbe(last, lm.startX + 2, 2))!;
    expect(low.systemIndex, last);
    expect(low.staffIndex, 1);
    expect(low.staffPosition, 4);
    expect(low.measureIndex, systems.systems[last].firstMeasure);
  });
}

// Verifies MultiSystemView.dragPreviewOpacity (C10b): while an element is
// dragged the view suppresses it from the normal layout and re-paints the *real*
// glyph translated to follow the pointer — so dragging a note up moves its ink
// up on screen. No app-side ghost involved.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partitura/partitura.dart';

import 'test_setup.dart';

void main() {
  setUpAll(setUpPartituraForTests);

  const green = Color(0xFF43A047);
  const staffSpace = 14.0;

  // (green pixel count, mean y) of the last RepaintBoundary.
  Future<(int, double)> greenCentroid(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).last,
    );
    var count = 0;
    var sumY = 0.0;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final w = image.width;
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      for (var i = 0; i < data.lengthInBytes; i += 4) {
        final r = data.getUint8(i), g = data.getUint8(i + 1);
        final b = data.getUint8(i + 2);
        if ((r - 0x43).abs() < 45 &&
            (g - 0xA0).abs() < 45 &&
            (b - 0x47).abs() < 45) {
          count++;
          sumY += ((i ~/ 4) ~/ w).toDouble();
        }
      }
    });
    return (count, count == 0 ? 0.0 : sumY / count);
  }

  testWidgets('dragPreviewOpacity moves the real glyph up as you drag up', (
    tester,
  ) async {
    final controller = ElementRegionController();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              child: ColoredBox(
                color: Colors.white,
                child: SizedBox(
                  width: 400,
                  child: MultiSystemView(
                    score: Score.simple(notes: 'c4:q d4 e4 f4'),
                    staffSpace: staffSpace,
                    elementColors: const {'e0': green},
                    dragPreviewOpacity: 1.0,
                    controller: controller,
                    onElementDragEnd: (_, __) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final rest = await greenCentroid(tester);
    expect(
      rest.$1,
      greaterThan(20),
      reason: 'the green note should be visible',
    );

    // Drag the green note (e0) up by ~3 staff spaces.
    final viewTopLeft = tester.getTopLeft(find.byType(MultiSystemView));
    final region = controller.elementRegions.firstWhere((r) => r.id == 'e0');
    final gesture = await tester.startGesture(
      viewTopLeft + region.bounds.center,
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -3 * staffSpace));
    await tester.pump();

    final dragged = await greenCentroid(tester);
    expect(
      dragged.$1,
      greaterThan(20),
      reason: 'the dragged glyph is still painted (following the pointer)',
    );
    expect(
      dragged.$2,
      lessThan(rest.$2 - staffSpace),
      reason: 'dragging up should move the real green glyph upward on screen',
    );

    await gesture.up();
  });
}

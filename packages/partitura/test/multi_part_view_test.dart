import 'package:flutter/material.dart' hide Step, PageMetrics;
import 'package:flutter_test/flutter_test.dart';
import 'package:partitura/partitura.dart';

import 'test_setup.dart';

void main() {
  setUpAll(setUpPartituraForTests);

  // A small string-quartet document: two connected barline groups (upper pair
  // and lower pair) under one section bracket, over several bars so it breaks.
  MultiPartScore quartet() {
    Score part(Clef clef, String bars) => Score.simple(
          clef: clef,
          keySignature: const KeySignature(1),
          timeSignature: TimeSignature.fourFour,
          notes: bars,
        );
    return MultiPartScore([
      part(
          Clef.treble,
          'd5:q b4 g4 b4 | c5:q e5 g5 e5 | '
          'd5:h g5:h | a5:q g5 f#5 e5'),
      part(
          Clef.treble,
          'g4:q g4 d4 g4 | e4:q g4 c5 g4 | '
          'b4:h b4:h | c5:q b4 a4 g4'),
      part(
          Clef.alto,
          'b3:q d4 b3 d4 | g3:q c4 e4 c4 | '
          'g3:h d4:h | e4:q d4 c4 b3'),
      part(
          Clef.bass,
          'g2:q g2 g2 g2 | c3:q c3 c3 c3 | '
          'g2:h g2:h | a2:q b2 c3 c2'),
    ], brackets: const [
      StaffBracket(0, 3)
    ], barlineGroups: const [
      BarlineGroup(0, 1),
      BarlineGroup(2, 3),
    ]);
  }

  testWidgets('sizes to the page box and paginates the parts', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: MultiPartView(
            document: quartet(),
            metrics: const PageMetrics(width: 70, height: 80),
            staffSpace: 6,
          ),
        ),
      ),
    ));
    final render =
        tester.renderObject<RenderMultiPartView>(find.byType(MultiPartView));
    expect(render.size.width, 70 * 6);
    expect(render.size.height, 80 * 6);
    expect(render.pageCount, greaterThanOrEqualTo(1));
    // Every system carries all four parts and both barline groups.
    final page = render.pagedLayout!.pages.first;
    expect(page.systems, isNotEmpty);
    for (final placed in page.systems) {
      expect(placed.system.layout.staves, hasLength(4));
      expect(placed.system.layout.barlineSpans, hasLength(2));
    }
  });

  testWidgets('changing the page index only repaints', (tester) async {
    // A short page forces multiple pages.
    Widget build(int page) => MaterialApp(
          home: Scaffold(
            body: MultiPartView(
              document: quartet(),
              metrics: const PageMetrics(width: 60, height: 40),
              staffSpace: 6,
              pageIndex: page,
            ),
          ),
        );
    await tester.pumpWidget(build(0));
    final render =
        tester.renderObject<RenderMultiPartView>(find.byType(MultiPartView));
    final pages = render.pageCount;
    expect(pages, greaterThan(1));
    await tester.pumpWidget(build(1));
    expect(render.pageIndex, 1);
    expect(render.pageCount, pages); // no relayout
  });

  testWidgets('hideEmptyStaves drops a silent part on a later system',
      (tester) async {
    // Three parts; the middle rests in the second half. With hide-empty the
    // first system shows all three, a later system shows only the outer two.
    Score voice(String notes, Clef clef) => Score.simple(
        clef: clef, timeSignature: TimeSignature.fourFour, notes: notes);
    final doc = MultiPartScore([
      voice(List.filled(4, 'c5:q d5 e5 f5').join(' | '), Clef.treble),
      voice(['g4:q g4 g4 g4', 'a4:q a4 a4 a4', 'r:w', 'r:w'].join(' | '),
          Clef.treble),
      voice(List.filled(4, 'c3:q d3 e3 f3').join(' | '), Clef.bass),
    ], brackets: const [
      StaffBracket(0, 2)
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MultiPartView(
          document: doc,
          metrics: const PageMetrics(width: 42, height: 90),
          staffSpace: 6,
          staffGap: 4,
          hideEmptyStaves: true,
        ),
      ),
    ));
    final render =
        tester.renderObject<RenderMultiPartView>(find.byType(MultiPartView));
    final systems = [
      for (final page in render.pagedLayout!.pages)
        for (final s in page.systems) s.system,
    ];
    expect(systems.first.layout.staves, hasLength(3)); // first system: all
    // A later system drops the silent middle part down to the outer two.
    expect(systems.any((s) => s.layout.staves.length == 2), isTrue);
  });

  testWidgets('elementRegions cover every part with global measure indices',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MultiPartView(
          document: quartet(),
          metrics: const PageMetrics(width: 130, height: 90),
          staffSpace: 6,
        ),
      ),
    ));
    final render =
        tester.renderObject<RenderMultiPartView>(find.byType(MultiPartView));
    final regions = render.elementRegions;
    expect(regions, isNotEmpty);
    // Every region has a positive-size box and an in-range measure index.
    for (final r in regions) {
      expect(r.bounds.width, greaterThan(0));
      expect(r.measureIndex, inInclusiveRange(0, quartet().measureCount - 1));
    }
    // rectOfElement round-trips the first region's id to its bounds.
    final first = regions.first;
    expect(render.rectOfElement(first.id), first.bounds);
    // A marquee over the whole page selects that id.
    final page = Offset.zero & render.size;
    expect(render.elementIdsIn(page), contains(first.id));
    // A far-away id is absent.
    expect(render.rectOfElement('no-such-id'), isNull);
  });

  testWidgets('tapping an element reports its id (cross-part)', (tester) async {
    String? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MultiPartView(
          document: quartet(),
          metrics: const PageMetrics(width: 130, height: 90),
          staffSpace: 6,
          onElementTap: (id) => tapped = id,
        ),
      ),
    ));
    final render =
        tester.renderObject<RenderMultiPartView>(find.byType(MultiPartView));
    // Pick an element on a lower part (staff 2 or 3) to prove cross-part hit
    // testing, and tap its center.
    final regions = render.elementRegions;
    final target = regions.last;
    final localCenter = target.bounds.center;
    expect(render.elementIdAt(localCenter), target.id);
    final topLeft = tester.getTopLeft(find.byType(MultiPartView));
    await tester.tapAt(topLeft + localCenter);
    await tester.pump();
    expect(tapped, target.id);
    // Tapping empty space (far bottom-right corner) reports nothing.
    expect(render.elementIdAt(render.size.bottomRight(Offset.zero)), isNull);
  });

  testWidgets('124 orchestral system: bracket + two barline groups',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: RepaintBoundary(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: MultiPartView(
                  document: quartet(),
                  metrics: const PageMetrics(width: 64, height: 60),
                  staffSpace: 8,
                  staffGap: 5,
                  systemGap: 10,
                  drawPageBorder: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/124_multi_part_document.png'),
    );
  });

  testWidgets('125 hide-empty: middle staff drops out mid-piece',
      (tester) async {
    Score voice(String notes, Clef clef) => Score.simple(
        clef: clef,
        keySignature: const KeySignature(-1),
        notes: notes,
        timeSignature: TimeSignature.fourFour);
    // Flute, (tacet) clarinet, bassoon: the clarinet rests after bar 2.
    final doc = MultiPartScore([
      voice('c5:q d5 e5 f5 | g5:q f5 e5 d5 | e5:h g5:h | f5:q e5 d5 c5',
          Clef.treble),
      voice('e4:q f4 g4 a4 | b4:q a4 g4 f4 | r:w | r:w', Clef.treble),
      voice('c3:q c3 g3 g3 | c3:q c3 g3 g3 | c3:h e3:h | f3:q g3 c3 c3',
          Clef.bass),
    ], brackets: const [
      StaffBracket(0, 2)
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
                padding: const EdgeInsets.all(8),
                child: MultiPartView(
                  document: doc,
                  metrics: const PageMetrics(width: 56, height: 66),
                  staffSpace: 8,
                  staffGap: 4,
                  systemGap: 9,
                  hideEmptyStaves: true,
                  drawPageBorder: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(RepaintBoundary).last,
      matchesGoldenFile('goldens/125_multi_part_hide_empty.png'),
    );
  });
}

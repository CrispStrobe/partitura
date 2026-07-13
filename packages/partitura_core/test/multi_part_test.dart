import 'dart:convert';
import 'dart:io';

import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

late final LayoutSettings settings;

void main() {
  setUpAll(() {
    final meta = SmuflMetadata.fromJson(jsonDecode(
        File('../partitura/assets/smufl/bravura_metadata.json')
            .readAsStringSync()) as Map<String, Object?>);
    settings = LayoutSettings(metadata: meta);
  });

  MultiPartScore quartet() => MultiPartScore([
        Score.simple(clef: Clef.treble, notes: 'c5:q d5 e5 f5 | g5:h a5:h'),
        Score.simple(clef: Clef.treble, notes: 'g4:q g4 g4 g4 | b4:h c5:h'),
        Score.simple(clef: Clef.alto, notes: 'e4:q f4 g4 a4 | d4:h e4:h'),
        Score.simple(clef: Clef.bass, notes: 'c3:q b2 a2 g2 | g2:h c3:h'),
      ], brackets: const [
        StaffBracket(0, 3)
      ], barlineGroups: const [
        BarlineGroup(0, 1),
        BarlineGroup(2, 3),
      ]);

  group('BarlineGroup', () {
    test('contains is inclusive of both ends', () {
      const g = BarlineGroup(1, 3);
      expect(g.contains(0), isFalse);
      expect(g.contains(1), isTrue);
      expect(g.contains(2), isTrue);
      expect(g.contains(3), isTrue);
      expect(g.contains(4), isFalse);
    });

    test('value semantics', () {
      expect(const BarlineGroup(0, 2), const BarlineGroup(0, 2));
      expect(
          const BarlineGroup(0, 2).hashCode, const BarlineGroup(0, 2).hashCode);
      expect(const BarlineGroup(0, 2), isNot(const BarlineGroup(0, 3)));
    });

    test('a single-part group is valid', () {
      expect(const BarlineGroup(2, 2).contains(2), isTrue);
    });
  });

  group('MultiPartScore', () {
    test('exposes its parts and shared measure count', () {
      final doc = quartet();
      expect(doc.parts, hasLength(4));
      expect(doc.measureCount, 2);
    });

    test('effectiveBarlineGroups returns the explicit groups when given', () {
      expect(quartet().effectiveBarlineGroups,
          const [BarlineGroup(0, 1), BarlineGroup(2, 3)]);
    });

    test('effectiveBarlineGroups defaults to one group over all parts', () {
      final doc = MultiPartScore([
        Score.simple(notes: 'c4:w'),
        Score.simple(clef: Clef.bass, notes: 'c3:w'),
        Score.simple(clef: Clef.bass, notes: 'c2:w'),
      ]);
      expect(doc.barlineGroups, isEmpty);
      expect(doc.effectiveBarlineGroups, const [BarlineGroup(0, 2)]);
    });

    test('atConcertPitch transposes each part and preserves grouping', () {
      final clarinet = Score.simple(notes: 'd5:w');
      final written = MultiPartScore([
        // A B-flat clarinet: written a major second above sounding.
        Score(
          clef: clarinet.clef,
          measures: clarinet.measures,
          transposition: Transposition.bFlat,
        ),
        Score.simple(clef: Clef.bass, notes: 'c3:w'),
      ], brackets: const [
        StaffBracket(0, 1)
      ], barlineGroups: const [
        BarlineGroup(0, 1)
      ]);
      final concert = written.atConcertPitch();
      // The transposing part sounds a major second lower (d5 -> c5).
      expect(concert.parts.first, written.parts.first.atConcertPitch());
      expect(concert.parts.first.transposition, isNull);
      // The non-transposing part is unchanged.
      expect(concert.parts[1], written.parts[1]);
      // Grouping metadata is carried through.
      expect(concert.brackets, written.brackets);
      expect(concert.barlineGroups, written.barlineGroups);
    });

    test('value semantics', () {
      MultiPartScore make() => MultiPartScore([
            Score.simple(notes: 'c4:w'),
            Score.simple(clef: Clef.bass, notes: 'c3:w'),
          ], brackets: const [
            StaffBracket(0, 1, kind: StaffBracketKind.brace)
          ], barlineGroups: const [
            BarlineGroup(0, 1)
          ]);
      expect(make(), make());
      expect(make().hashCode, make().hashCode);
      // Differing barline grouping breaks equality.
      final other = MultiPartScore([
        Score.simple(notes: 'c4:w'),
        Score.simple(clef: Clef.bass, notes: 'c3:w'),
      ], brackets: const [
        StaffBracket(0, 1, kind: StaffBracketKind.brace)
      ]);
      expect(make(), isNot(other));
    });

    test('toString names the part count', () {
      expect(quartet().toString(), contains('4 parts'));
    });
  });

  group('layoutMultiPartSystem', () {
    test('lays out one layout per part', () {
      final layout = layoutMultiPartSystem(quartet(), settings);
      expect(layout.parts, hasLength(4));
      expect(layout.firstMeasure, 0);
      expect(layout.lastMeasure, 1); // two measures
    });

    test('all parts share the total width (aligned)', () {
      final layout = layoutMultiPartSystem(quartet(), settings);
      final w = layout.parts.first.width;
      for (final p in layout.parts) {
        expect(p.width, closeTo(w, 1e-9));
      }
    });

    test('barlines align: every measure column matches across parts', () {
      final layout = layoutMultiPartSystem(quartet(), settings);
      final ref = layout.parts.first.measureRegions;
      for (final p in layout.parts) {
        for (var i = 0; i < ref.length; i++) {
          expect(p.measureRegions[i].startX, closeTo(ref[i].startX, 1e-6));
          expect(p.measureRegions[i].endX, closeTo(ref[i].endX, 1e-6));
        }
      }
    });

    test('barline x positions are identical across parts', () {
      final layout = layoutMultiPartSystem(quartet(), settings);
      final xs = layout.barlineXs;
      // At least the left system line, an interior barline and the closing one.
      expect(xs.length, greaterThanOrEqualTo(3));
      expect(xs.first, 0.0);
      // Reading the full-staff vertical lines off any other part gives the
      // same set (the parts share their measure widths).
      List<double> partXs(int i) {
        final s = <double>{0.0};
        for (final line
            in layout.parts[i].primitives.whereType<LinePrimitive>()) {
          final vertical = line.from.x == line.to.x;
          final full = (line.from.y == 0 && line.to.y == 4) ||
              (line.from.y == 4 && line.to.y == 0);
          if (vertical && full) s.add(line.from.x);
        }
        return s.toList()..sort();
      }

      for (var i = 1; i < layout.parts.length; i++) {
        expect(partXs(i), orderedEquals(xs));
      }
    });

    test('two barline groups: the barline breaks between the groups', () {
      final layout = layoutMultiPartSystem(quartet(), settings, staffGap: 4);
      final spans = layout.barlineSpans;
      expect(spans, hasLength(2));
      // Group 0 spans parts 0..1; group 1 spans parts 2..3.
      expect(spans[0].group, const BarlineGroup(0, 1));
      expect(spans[1].group, const BarlineGroup(2, 3));
      // Group 0 bottom is the y=4 line of part 1; group 1 top is part 2's top.
      expect(spans[0].top, layout.staffTop(0));
      expect(spans[0].bottom, layout.staffTop(1) + 4);
      expect(spans[1].top, layout.staffTop(2));
      expect(spans[1].bottom, layout.staffTop(3) + 4);
      // There is a real gap (of staffGap) — the barline is broken, not
      // continuous through the whole system.
      expect(spans[0].bottom, lessThan(spans[1].top));
      expect(spans[1].top - spans[0].bottom, closeTo(4, 1e-9)); // staffGap
    });

    test('no groups: one continuous barline over all parts', () {
      final doc = MultiPartScore([
        Score.simple(clef: Clef.treble, notes: 'c5:q d5 e5 f5'),
        Score.simple(clef: Clef.bass, notes: 'c3:q d3 e3 f3'),
        Score.simple(clef: Clef.bass, notes: 'c2:q d2 e2 f2'),
      ]);
      final layout = layoutMultiPartSystem(doc, settings);
      final spans = layout.barlineSpans;
      expect(spans, hasLength(1));
      expect(spans.first.group, const BarlineGroup(0, 2));
      expect(spans.first.top, layout.staffTop(0));
      expect(spans.first.bottom, layout.staffTop(2) + 4);
    });

    test('parts must agree on measure count', () {
      final bad = MultiPartScore([
        Score.simple(notes: 'c4:q d4 e4 f4'),
        Score.simple(notes: 'c4:w | d4:w'), // 2 measures vs 1
      ]);
      expect(() => layoutMultiPartSystem(bad, settings), throwsArgumentError);
    });

    test('parts stack by 4 + staffGap and the system has positive height', () {
      final layout = layoutMultiPartSystem(quartet(), settings, staffGap: 5);
      expect(layout.staffTop(0), 0);
      expect(layout.staffTop(1), 9); // 4 + 5
      expect(layout.staffTop(3), 27);
      expect(layout.top, lessThan(0));
      expect(layout.height, greaterThan(27));
    });
  });
}

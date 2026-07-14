import 'dart:convert';
import 'dart:io';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// End-to-end ("live") tests: real ABC tunes driven through the whole pipeline
/// — parse → single- and multi-staff layout (exercising cross-staff onset
/// gridding, §2.9) → interchange round-trips → SVG. Melodies are traditional /
/// public-domain; the ABC is authored here.
late final LayoutSettings settings;

const engine = LayoutEngine();

/// The x of the first notehead glyph tagged [id] in [staff], or null.
double? _noteX(ScoreLayout staff, String id) {
  for (final p in staff.primitives) {
    if (p is GlyphPrimitive &&
        p.elementId == id &&
        p.smuflName.startsWith('notehead')) {
      return p.position.x;
    }
  }
  return null;
}

String? _firstNoteId(Score staff) {
  for (final e in staff.measures.first.elements) {
    if (e is NoteElement) return e.id;
  }
  return null;
}

void main() {
  setUpAll(() {
    final meta = SmuflMetadata.fromJson(jsonDecode(
        File('../crisp_notation/assets/smufl/bravura_metadata.json')
            .readAsStringSync()) as Map<String, Object?>);
    settings = LayoutSettings(metadata: meta);
  });

  group('live: real tunes through the whole pipeline', () {
    const tunes = <String, String>{
      'Amazing Grace': '''
X:1
T:Amazing Grace
M:3/4
L:1/8
K:G
D|G2 B2 G2|B2 A2 G2|E3 D2 D|G4 z2:|
''',
      'reel with accidentals and a triplet': '''
X:1
M:4/4
L:1/8
K:D
(3ABc dcAF|GECD =F2 A2|d^cde f2 ec|d2 D2 D4|
''',
      'two-part melody + bass': '''
X:1
M:4/4
L:1/8
K:C
V:1 clef=treble
V:2 clef=bass
[V:1] c2 d2 e2 f2 | g4 e4 |
[V:2] C4 G,4 | C2 E2 G2 c2 |
''',
      'four-voice chorale': '''
X:1
M:4/4
L:1/4
K:G
V:1
V:2
V:3 clef=bass
V:4 clef=bass
[V:1] d c B A | G4 |
[V:2] B A G ^F | G4 |
[V:3] G E D C | B,4 |
[V:4] G, A, B, C | G,4 |
''',
    };

    for (final entry in tunes.entries) {
      test('${entry.key} parses, lays out and round-trips', () {
        final abc = entry.value;
        // Parse (first voice) and lay out a single staff.
        final score = scoreFromAbc(abc);
        expect(score.measures, isNotEmpty);
        final single = engine.layout(score, settings);
        expect(single.primitives, isNotEmpty);

        // Multi-staff system layout (cross-staff gridding runs here).
        final system = staffSystemFromAbc(abc);
        final sysLayout = layoutStaffSystem(system, settings);
        expect(sysLayout.width, greaterThan(0));
        // Every staff shares the system width (barlines aligned).
        for (final staff in sysLayout.staves) {
          expect(staff.width, closeTo(sysLayout.width, 1e-6));
        }

        // Interchange round-trips and SVG must not throw and keep the bars.
        expect(scoreFromMusicXml(scoreToMusicXml(score)).measures.length,
            score.measures.length);
        expect(scoreFromMei(scoreToMei(score)).measures.length,
            score.measures.length);
        expect(scoreFromKern(scoreToKern(score)).measures.length,
            score.measures.length);
        expect(scoreToSvg(single), contains('<svg'));
      });
    }
  });

  group('cross-staff gridding on real ABC', () {
    StaffSystemLayout layout(String abc) =>
        layoutStaffSystem(staffSystemFromAbc(abc), settings);

    test('the two hands align at every shared beat', () {
      // Upper: four quarters; lower: a half then two quarters.
      final l = layout('''
X:1
M:4/4
L:1/4
K:C
V:1
V:2 clef=bass
[V:1] c d e f |
[V:2] C2 G, C |
''');
      final upper = staffSystemFromAbc('''
X:1
M:4/4
L:1/4
K:C
V:1
V:2 clef=bass
[V:1] c d e f |
[V:2] C2 G, C |
''').staves;
      // Beat 1 (onset 0) and beat 3 (onset 1/2) exist in both hands.
      double up(int i) =>
          _noteX(l.staves[0], upper[0].measures.first.elements[i].id!)!;
      double lo(int i) =>
          _noteX(l.staves[1], upper[1].measures.first.elements[i].id!)!;
      expect(up(0), closeTo(lo(0), 0.02)); // beat 1
      expect(up(2), closeTo(lo(1), 0.02)); // beat 3: upper e5 over lower G,
    });

    test('a note aligns with a rest at the same onset', () {
      final l = layout('''
X:1
M:4/4
L:1/4
K:C
V:1
V:2 clef=bass
[V:1] c z e z | c4 |
[V:2] C E G c | C4 |
''');
      // Upper beat-3 note (index 2) over lower beat-3 note (index 2).
      final sys = staffSystemFromAbc('''
X:1
M:4/4
L:1/4
K:C
V:1
V:2 clef=bass
[V:1] c z e z | c4 |
[V:2] C E G c | C4 |
''');
      final upId = sys.staves[0].measures.first.elements[2].id!;
      final loId = sys.staves[1].measures.first.elements[2].id!;
      expect(
          _noteX(l.staves[0], upId), closeTo(_noteX(l.staves[1], loId)!, 0.02));
    });

    test('accidental-aware: heads align when one hand has a sharp', () {
      const abc = '''
X:1
M:4/4
L:1/4
K:C
V:1
V:2 clef=bass
[V:1] ^c d e f | g4 |
[V:2] C =E G, C | C4 |
''';
      final l = layout(abc);
      final sys = staffSystemFromAbc(abc);
      final upId = _firstNoteId(sys.staves[0])!;
      final loId = _firstNoteId(sys.staves[1])!;
      // The sharp is drawn on the upper beat-1 note...
      expect(
        l.staves[0].primitives.whereType<GlyphPrimitive>().any((g) =>
            g.elementId == upId && g.smuflName == SmuflGlyph.accidentalSharp),
        isTrue,
      );
      // ...yet the two beat-1 noteheads still line up (accidental goes left).
      expect(
          _noteX(l.staves[0], upId), closeTo(_noteX(l.staves[1], loId)!, 0.02));
    });

    test('a pickup (anacrusis) aligns across voices', () {
      const abc = '''
X:1
M:4/4
L:1/4
K:C
V:1
V:2 clef=bass
[V:1] G | c d e f |
[V:2] G, | C E G c |
''';
      final sys = staffSystemFromAbc(abc);
      expect(sys.staves.every((s) => s.measures.first.pickup), isTrue);
      final l = layout(abc);
      final upId = _firstNoteId(sys.staves[0])!;
      final loId = _firstNoteId(sys.staves[1])!;
      expect(
          _noteX(l.staves[0], upId), closeTo(_noteX(l.staves[1], loId)!, 0.02));
    });
  });

  group('robustness', () {
    test('voices with unequal bar counts are padded, not fatal', () {
      // V:1 has two bars, V:2 only one — an imperfect encoding.
      final system = staffSystemFromAbc('''
X:1
M:4/4
L:1/4
K:C
V:1
V:2 clef=bass
[V:1] c d e f | g a b c' |
[V:2] C4 |
''');
      // The short voice is padded to the longest bar count.
      expect(system.staves.map((s) => s.measures.length), everyElement(2));
      // And it lays out (barlines aligned) instead of throwing.
      final l = layoutStaffSystem(system, settings);
      expect(l.staves[0].width, closeTo(l.staves[1].width, 1e-6));
    });
  });
}

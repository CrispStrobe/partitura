import 'dart:typed_data';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

void main() {
  group('bekernToKern', () {
    test('expands structural markers and rejoins sub-tokens', () {
      const bekern = '**kern <t> **kern <b> 4 C <t> 4 c <b> *- <t> *-';
      expect(
        bekernToKern(bekern),
        '**kern\t**kern\n4C\t4c\n*-\t*-',
      );
    });

    test('<s> becomes a chord-separating space', () {
      // One spine, a two-note chord: "4c 4e".
      const bekern = '**kern <b> 4 c <s> 4 e <b> *-';
      expect(bekernToKern(bekern), '**kern\n4c 4e\n*-');
    });

    test('drops decoder special tokens', () {
      const bekern = '<bos> **kern <b> 4 c <b> *- <eos>';
      expect(bekernToKern(bekern), '**kern\n4c\n*-');
    });
  });

  group('bekernToGrandStaff', () {
    // A minimal grand staff: bass clef (left column) + treble clef (right).
    const bekern = '**kern <t> **kern <b> '
        '*clefF4 <t> *clefG2 <b> '
        '*k[] <t> *k[] <b> '
        '*M4/4 <t> *M4/4 <b> '
        '4 C <t> 4 c <b> '
        '4 D <t> 4 d <b> '
        '= <t> = <b> '
        '4 E <t> 4 e <b> '
        '4 F <t> 4 f <b> '
        '*- <t> *-';

    test('assigns treble spine to upper, bass to lower by clef', () {
      final gs = bekernToGrandStaff(bekern);
      expect(gs.upper.clef, Clef.treble);
      expect(gs.lower.clef, Clef.bass);
    });

    test('parses notes into both staves', () {
      final gs = bekernToGrandStaff(bekern);
      // Upper staff, first measure, first note = c4 (middle C).
      final first = gs.upper.measures.first.elements.first as NoteElement;
      expect(first.pitches.single.step, Step.c);
      expect(first.pitches.single.octave, 4);
      // Lower staff first note = C3.
      final low = gs.lower.measures.first.elements.first as NoteElement;
      expect(low.pitches.single.step, Step.c);
      expect(low.pitches.single.octave, 3);
    });

    test('element ids are unique across the two staves', () {
      final gs = bekernToGrandStaff(bekern);
      final ids = <String>[
        for (final m in gs.upper.measures)
          for (final e in m.elements)
            if (e.id != null) e.id!,
        for (final m in gs.lower.measures)
          for (final e in m.elements)
            if (e.id != null) e.id!,
      ];
      expect(ids.toSet().length, ids.length, reason: 'ids should be unique');
    });

    test('round-trips to MusicXML without throwing', () {
      final gs = bekernToGrandStaff(bekern);
      final xml = grandStaffToMusicXml(gs);
      expect(xml, contains('<part-list>'));
      expect(xml, contains('<part '));
    });
  });

  test('bekernToScore reads the first spine as a single-staff Score', () {
    const bekern = '**kern <b> *clefG2 <b> 4 c <b> 4 d <b> *-';
    final score = bekernToScore(bekern);
    expect(score.clef, Clef.treble);
    expect(score.measures.expand((Measure m) => m.elements).length, 2);
  });

  group('extended kern (**ekern) spines', () {
    // The SMT GrandStaff model emits `**ekern_1.0`, not plain `**kern`.
    const ekern = '**ekern_1.0\t**ekern_1.0\n'
        '*clefF4\t*clefG2\n'
        '*k[b-]\t*k[b-]\n'
        '*M2/4\t*M2/4\n'
        '4C\t4c\n'
        '=\t=\n'
        '*-\t*-';

    test('grandStaffFromKern reads **ekern headers natively', () {
      final gs = grandStaffFromKern(ekern);
      expect(gs.upper.clef, Clef.treble);
      expect(gs.lower.clef, Clef.bass);
    });

    test('tuplet reciprocals are approximated, not rejected', () {
      // Real GrandStaff output contains triplets (recip 6/12); the model has
      // no tuplet ratio, so they map to the written note value.
      const kern = '**kern\n*clefG2\n6f\n6g\n6a\n12c\n*-';
      final score = scoreFromKern(kern);
      final notes = score.measures
          .expand((Measure m) => m.elements)
          .whereType<NoteElement>()
          .toList();
      expect(notes, hasLength(4));
      expect(notes[0].duration.base, DurationBase.quarter); // 6 -> quarter
      expect(notes[3].duration.base, DurationBase.eighth); // 12 -> eighth
    });

    test('bekernToGrandStaff round-trips **ekern output to MusicXML', () {
      // Reconstruct the same document from bekern tokens.
      const bekern = '**ekern_1.0 <t> **ekern_1.0 <b> '
          '*clefF4 <t> *clefG2 <b> '
          '*k[b-] <t> *k[b-] <b> '
          '*M2/4 <t> *M2/4 <b> '
          '4 C <t> 4 c <b> = <t> = <b> *- <t> *-';
      final gs = bekernToGrandStaff(bekern);
      expect(gs.upper.clef, Clef.treble);
      expect(gs.lower.clef, Clef.bass);
      expect(grandStaffToMusicXml(gs), contains('<part '));
    });
  });

  group('bekern extras', () {
    test('bekernToStaffSystem yields one staff per spine', () {
      const bekern = '**kern <t> **kern <b> '
          '*clefF4 <t> *clefG2 <b> 4 C <t> 4 c <b> *- <t> *-';
      final sys = bekernToStaffSystem(bekern);
      expect(sys.staves.length, 2);
      // Ordered top-to-bottom: the treble (rightmost spine) is on top.
      expect(sys.staves.first.clef, Clef.treble);
      expect(sys.staves.last.clef, Clef.bass);
    });

    test('header synthesis: bare records with no exclusive interpretation', () {
      // No **kern / **ekern header — the reader must synthesise one.
      const bekern = '4 c <b> 4 d <b> 4 e';
      final score = bekernToScore(bekern);
      expect(score.measures.expand((Measure m) => m.elements).length, 3);
    });

    test('omrDialectOf falls back to bekern for ambiguous input', () {
      expect(omrDialectOf('4c 4d 4e'), OmrDialect.bekern); // digit-first
      expect(omrDialectOf(''), OmrDialect.bekern); // empty
    });

    test('omrDialectOf recognizes semantic via any -prefixed sign', () {
      expect(omrDialectOf('timeSignature-4/4'), OmrDialect.semantic);
      expect(omrDialectOf('keySignature-GM'), OmrDialect.semantic);
      expect(omrDialectOf('clef-G2'), OmrDialect.semantic);
    });

    test('omrDialectOf recognizes bekern via any structural marker', () {
      expect(omrDialectOf('a <s> b'), OmrDialect.bekern); // chord separator
      expect(omrDialectOf('a <b> b'), OmrDialect.bekern); // line break
      expect(omrDialectOf('**ekern_1.0'), OmrDialect.bekern);
    });

    test('omrDialectOf recognizes Flova LilyPond notes and rests', () {
      expect(omrDialectOf("c'4 d'4"), OmrDialect.lilyNotes);
      expect(omrDialectOf('r4 g8'), OmrDialect.lilyNotes); // leading rest
    });
  });

  group('OmrImage', () {
    test('accepts a correctly-sized buffer and exposes its shape', () {
      final img =
          OmrImage(Uint8List(8 * 5 * 4), width: 8, height: 5, channels: 4);
      expect(img.width, 8);
      expect(img.height, 5);
      expect(img.channels, 4);
    });

    test('rejects a buffer too small for width×height×channels', () {
      expect(() => OmrImage(Uint8List(10), width: 8, height: 5, channels: 4),
          throwsA(isA<AssertionError>()));
    });
  });
}

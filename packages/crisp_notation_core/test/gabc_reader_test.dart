import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

List<int> _midi(Score s) => [
      for (final m in s.measures)
        for (final e in m.elements)
          if (e is NoteElement) e.pitches.first.midiNumber,
    ];

List<NoteElement> _notes(Score s) => [
      for (final m in s.measures)
        for (final e in m.elements)
          if (e is NoteElement) e,
    ];

void main() {
  group('GABC pitch mapping (gabctk reference: la=A3=57)', () {
    test('c4 clef: a..m walk the diatonic scale from A3', () {
      // one note per letter, no divisions
      final s = scoreFromGabc(
          'name:x;\n%%\n(c4) t(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)(k)(l)(m)');
      expect(_midi(s), [57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77]);
    });

    test('c3 clef shifts the mapping (a = C4)', () {
      final s = scoreFromGabc('%%\n(c3) t(a)(c)(e)');
      expect(_midi(s), [60, 64, 67]); // do, mi, sol
    });

    test('f3 clef: letter a lands on fa (F)', () {
      final s = scoreFromGabc('%%\n(f3) t(a)');
      // f3: start = 5 -> letter a is fa (F), octave-anchored -> F4 = 65
      expect(_midi(s), [65]);
    });
  });

  group('accidentals', () {
    test('x flats the following same-letter notes (si bemol)', () {
      final s = scoreFromGabc('%%\n(c4) t(b)(bxb)');
      // b = B3 (59); bx sets flat, next b = Bb3 (58)
      expect(_midi(s), [59, 58]);
      final n = _notes(s);
      expect(n[1].pitches.first.step, Step.b);
      expect(n[1].pitches.first.alter, -1); // spelled as B-flat, not A-sharp
    });

    test('a division resets accidentals', () {
      final s = scoreFromGabc('%%\n(c4) t(bxb) (::) u(b)');
      expect(_midi(s), [58, 59]); // Bb then natural B after the bar
    });

    test('clef flat signature (cb4) flats b by default', () {
      final s = scoreFromGabc('%%\n(cb4) t(b)');
      expect(_midi(s), [58]);
    });
  });

  group('structure', () {
    test('divisions split measures; mora lengthens', () {
      final s = scoreFromGabc('%%\n(c4) a(g.) (;) b(h)');
      expect(s.measures.length, 2);
      final n = _notes(s);
      expect(n[0].duration.base, DurationBase.quarter); // mora doubled eighth
      expect(n[1].duration.base, DurationBase.eighth);
    });

    test('free meter (no time signature)', () {
      final s = scoreFromGabc('%%\n(c4) a(f)');
      expect(s.timeSignature, isNull);
    });

    test('lyrics attach to the first note of a neume, hyphenated in words', () {
      // "Al-le" is one word (adjacent syllables), "Dó" a new word (space).
      final s = scoreFromGabc('%%\n(c4) Al(f)le(g) Dó(h)');
      expect(s.lyrics.map((l) => l.text).toList(), ['Al', 'le', 'Dó']);
      expect(s.lyrics[0].hyphenToNext, isTrue); // Al-le
      expect(s.lyrics[1].hyphenToNext, isFalse); // le  Dó
      // each syllable sits on its neume's first note id
      expect(s.lyrics[0].elementId, _notes(s)[0].id);
    });

    test('markup + choir marks are stripped from lyrics', () {
      final s = scoreFromGabc('%%\n(c4) <i>test</i>*(f)');
      expect(s.lyrics.first.text, 'test');
    });

    test('header is parsed', () {
      final h = gabcHeader(
          'name:Laudem Domini;\noffice-part:Alleluia;\nmode:1;\n%%\n(c4)');
      expect(h.name, 'Laudem Domini');
      expect(h.officePart, 'Alleluia');
      expect(h.mode, '1');
    });

    test('missing %% throws', () {
      expect(() => scoreFromGabc('name:x; no body'), throwsFormatException);
    });
  });

  group('real GregoBase chant', () {
    test('Laudem Domini incipit parses to sane pitches + lyrics', () {
      const gabc = 'name:Laudem Domini;\noffice-part:Alleluia;\nmode:1;\n%%\n'
          '(c4) AL(dc~)le(c/e\'gF\'EC\'d)lu(dc/fg!hvGF\'g)(g.) (;)';
      final s = scoreFromGabc(gabc);
      final midi = _midi(s);
      expect(midi.first, 62); // AL starts on d = D4
      expect(midi, everyElement(inInclusiveRange(48, 84))); // singable range
      expect(s.lyrics.map((l) => l.text).toList(), ['AL', 'le', 'lu']);
      // scoreToMidi must not drop notes (all ids assigned)
      expect(_notes(s).every((n) => n.id != null), isTrue);
    });
  });
}

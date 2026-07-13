import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

MusicElement el(String notes) =>
    Score.simple(notes: notes).measures.first.elements.first;

void main() {
  group('semanticLabel', () {
    test('a single note spells pitch + duration', () {
      expect(semanticLabel(el('c4:q')), 'C 4 quarter note');
      expect(semanticLabel(el('c5:w')), 'C 5 whole note');
      expect(semanticLabel(el('g3:e')), 'G 3 eighth note');
    });

    test('accidentals are spoken', () {
      expect(semanticLabel(el('f#4:q')), 'F sharp 4 quarter note');
      expect(semanticLabel(el('bb3:h')), 'B flat 3 half note');
    });

    test('dots are spoken', () {
      expect(semanticLabel(el('c4:q.')), 'C 4 dotted quarter note');
      expect(semanticLabel(el('c4:h..')), 'C 4 double-dotted half note');
    });

    test('a chord lists its pitches', () {
      expect(semanticLabel(el('c4+e4+g4:h')), 'C 4, E 4, G 4 chord, half note');
    });

    test('a rest names its duration', () {
      expect(semanticLabel(el('r:e')), 'eighth rest');
      expect(semanticLabel(el('r:q')), 'quarter rest');
    });
  });

  test('semanticLabels maps every identified element', () {
    final m = semanticLabels(Score.simple(notes: 'c4:q d4 | e4:h'));
    expect(m['e0'], 'C 4 quarter note');
    expect(m['e1'], 'D 4 quarter note');
    expect(m['e2'], 'E 4 half note');
  });
}

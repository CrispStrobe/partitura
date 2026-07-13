import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

void main() {
  // Schoenberg, Suite for Piano Op. 25 — a real twelve-tone row.
  final op25 = ToneRow([4, 5, 7, 1, 6, 3, 8, 2, 11, 0, 9, 10]);
  final chromatic = ToneRow([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);

  group('construction', () {
    test('accepts a permutation of the twelve pitch classes', () {
      expect(op25.pitchClasses, hasLength(12));
      expect(op25.pitchClasses.toSet(), hasLength(12));
    });

    test('reduces mod 12', () {
      expect(ToneRow([12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 23]).pitchClasses,
          [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    });

    test('rejects rows that are not a full permutation', () {
      expect(() => ToneRow([0, 1, 2]), throwsArgumentError); // too short
      expect(() => ToneRow([0, 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
          throwsArgumentError); // duplicate
    });

    test('from pitches, in order (a chromatic scale)', () {
      final row = ToneRow.of([
        for (final name in [
          'c4', 'c#4', 'd4', 'd#4', 'e4', 'f4', //
          'f#4', 'g4', 'g#4', 'a4', 'a#4', 'b4'
        ])
          Pitch.parse(name),
      ]);
      expect(row, chromatic);
    });
  });

  group('row forms', () {
    test('transpose adds mod 12 and is invertible', () {
      expect(op25.transpose(3).pitchClasses,
          [for (final p in op25.pitchClasses) (p + 3) % 12]);
      expect(op25.transpose(5).transpose(7), op25); // 5 + 7 = 12
    });

    test('retrograde reverses and is an involution', () {
      expect(op25.retrograde.pitchClasses, op25.pitchClasses.reversed.toList());
      expect(op25.retrograde.retrograde, op25);
    });

    test('inversion keeps the first note and is an involution', () {
      final i = op25.invert();
      expect(i.pitchClasses.first, op25.pitchClasses.first);
      expect(i.invert(), op25);
    });

    test('retrograde-inversion is the inversion read backwards', () {
      expect(op25.retrogradeInversion, op25.invert().retrograde);
    });

    test('the chromatic row inverts to a descending chromatic', () {
      expect(chromatic.invert().pitchClasses,
          [0, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
    });
  });

  group('matrix', () {
    test('is 12×12', () {
      expect(op25.matrix, hasLength(12));
      for (final row in op25.matrix) {
        expect(row, hasLength(12));
      }
    });

    test('the top row is P0 (the row transposed to start on 0)', () {
      expect(op25.matrix.first, op25.primeZero);
      expect(op25.primeZero.first, 0);
    });

    test('every row and every column is a permutation of 0–11', () {
      final m = op25.matrix;
      for (var r = 0; r < 12; r++) {
        expect(m[r].toSet(), hasLength(12), reason: 'row $r');
      }
      for (var c = 0; c < 12; c++) {
        expect({for (var r = 0; r < 12; r++) m[r][c]}, hasLength(12),
            reason: 'column $c');
      }
    });

    test('the main diagonal is all zeros', () {
      final m = op25.matrix;
      for (var k = 0; k < 12; k++) {
        expect(m[k][k], 0);
      }
    });

    test('rows read left→right are prime forms; columns top→bottom inversions',
        () {
      final m = op25.matrix;
      // Row r is P0 transposed by its leftmost entry.
      for (var r = 0; r < 12; r++) {
        final level = m[r][0];
        expect(m[r], [for (final p in op25.primeZero) (p + level) % 12]);
      }
      // Column c is I0 transposed by its topmost entry (= P0[c]).
      final i0 = [for (final p in op25.primeZero) (12 - p) % 12];
      for (var c = 0; c < 12; c++) {
        final level = m[0][c];
        expect([for (var r = 0; r < 12; r++) m[r][c]],
            [for (final p in i0) (p + level) % 12]);
      }
    });

    test('the chromatic matrix has a known first two rows', () {
      final m = chromatic.matrix;
      expect(m[0], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
      expect(m[1], [11, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });
  });

  group('value semantics', () {
    test('equality is by ordered members', () {
      expect(ToneRow([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]), chromatic);
      expect(chromatic.hashCode,
          ToneRow([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]).hashCode);
      expect(op25, isNot(chromatic));
      // Order matters: a reordering is a different row.
      expect(op25.retrograde, isNot(op25));
    });
  });
}

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Property-based algebraic invariants of the theory transforms. The
/// example-based tests in `theory_extras_test.dart` and `set_theory_test.dart`
/// pin specific results; these assert the group-theoretic laws that must hold
/// for *every* input, which is where enharmonic-spelling or mod-12 arithmetic
/// bugs tend to hide.
void main() {
  Set<int> pcsOf(Triad t) => {for (final p in t.pitches) p.midiNumber % 12};

  group('neo-Riemannian P/L/R are involutions on every consonant triad', () {
    // The three contextual inversions each return the original sounding chord
    // when applied twice — across all 12 roots, both modes, and sharp/flat
    // spellings (spelling may drift; pitch classes may not).
    final triads = <Triad>[
      for (final step in Step.values)
        for (final alter in const [-1, 0, 1])
          for (final q in const [ChordQuality.major, ChordQuality.minor])
            Triad(Pitch(step, alter: alter, octave: 4), q),
    ];

    for (final transform in <(String, Triad Function(Triad))>[
      ('P', (t) => t.parallel),
      ('L', (t) => t.leittonwechsel),
      ('R', (t) => t.relative),
    ]) {
      test('${transform.$1} applied twice restores the pitch classes', () {
        for (final t in triads) {
          final twice = transform.$2(transform.$2(t));
          expect(pcsOf(twice), pcsOf(t), reason: '${transform.$1}² changed $t');
        }
      });
    }
  });

  group('twelve-tone row-form algebra', () {
    final rows = <List<int>>[
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
      [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
      [0, 11, 3, 4, 8, 7, 9, 5, 6, 1, 2, 10],
      [2, 8, 1, 11, 6, 4, 0, 9, 5, 7, 3, 10],
    ];

    test('retrograde and inversion (about the first note) are involutions', () {
      for (final row in rows) {
        expect(retrograde(retrograde(row)), row);
        expect(invertRow(invertRow(row)), row);
      }
    });

    test('Tn followed by T(12-n) is the identity for every n', () {
      for (final row in rows) {
        for (var n = 0; n < 12; n++) {
          expect(transposeRow(transposeRow(row, n), (12 - n) % 12), row,
              reason: 'Tn∘T-n failed at n=$n');
        }
      }
    });

    test('RI² is a transposition of the row (first-note-axis inversion)', () {
      // invertRow inverts about the row's own first note, so RI = R∘I moves the
      // axis; applying RI twice returns the row transposed, not the row itself.
      for (final row in rows) {
        final ri2 = retrogradeInversion(retrogradeInversion(row));
        final delta = (ri2.first - row.first + 12) % 12;
        expect(ri2, transposeRow(row, delta),
            reason: 'RI² is not a clean transposition of $row');
      }
    });

    test('every matrix row and column is a full twelve-tone permutation', () {
      for (final row in rows) {
        final m = twelveToneMatrix(row);
        expect(m, hasLength(12));
        for (var i = 0; i < 12; i++) {
          expect(m[i].toSet(), hasLength(12),
              reason: 'row $i not a permutation');
          expect({for (var j = 0; j < 12; j++) m[j][i]}, hasLength(12),
              reason: 'column $i not a permutation');
        }
      }
    });
  });

  group('set-theory prime form and ICV are Tn/TnI invariant', () {
    final sets = <Set<int>>[
      {0, 4, 7}, // major triad
      {0, 3, 7}, // minor triad
      {0, 1, 6}, // 3-5
      {0, 1, 4, 6}, // 4-Z15
      {0, 3, 6, 9}, // fully diminished 7th
      {0, 2, 4, 6, 8, 10}, // whole-tone
      {0, 1, 2, 3, 4, 5, 6, 7}, // 8-note cluster
    ];

    test('prime form is unchanged by all 24 T/I operations', () {
      for (final s in sets) {
        final pf = primeForm(s);
        for (var n = 0; n < 12; n++) {
          expect(primeForm(transposeSet(s, n)), pf, reason: 'Tn n=$n');
          expect(primeForm(invertSet(transposeSet(s, n))), pf,
              reason: 'TnI n=$n');
        }
      }
    });

    test('interval-class vector is unchanged by all 24 T/I operations', () {
      for (final s in sets) {
        final icv = intervalClassVector(s);
        for (var n = 0; n < 12; n++) {
          expect(intervalClassVector(transposeSet(s, n)), icv,
              reason: 'Tn n=$n');
          expect(intervalClassVector(invertSet(transposeSet(s, n))), icv,
              reason: 'TnI n=$n');
        }
      }
    });
  });
}

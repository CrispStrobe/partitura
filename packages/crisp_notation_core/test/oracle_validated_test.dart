import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Behaviours the cross-oracle hardening campaign (`docs/HARDENING.md`)
/// **proved crisp_notation reads correctly**, often against buggy external parsers —
/// pinned here as self-contained, CI-runnable regressions (no external deps).
///
/// The differential harness (`tool/oracle_diff.dart`, `--quorum`) compares
/// crisp_notation against music21, Verovio and abc2midi. Where it flagged a
/// divergence, the culprit was repeatedly the *oracle*, not crisp_notation:
///  - music21 ignores ABC broken rhythm and mis-applies the key to bare notes;
///  - music21 + Verovio share a non-spec "no-carry" accidental convention;
///  - abc2midi (the reference ABC engine) confirms crisp_notation's spec behaviour.
/// These tests lock in the spec-correct behaviour so a future change can't
/// silently regress it to match a buggy tool.
void main() {
  List<int> midis(String abc) => scoreFromAbc(abc)
      .measures
      .expand((m) => m.elements)
      .whereType<NoteElement>()
      .map((n) => n.pitches.single.midiNumber)
      .toList();

  group('ABC — oracle-validated spec behaviour', () {
    test('an accidental carries to the bar end, then resets at the barline',
        () {
      // ABC 2.1: an accidental applies to all same-pitch notes to the end of the
      // bar. `=f` (natural) carries to the next `f`; the new bar reverts to the
      // key (F♯). music21 AND Verovio both get this wrong (no carry); abc2midi
      // — the reference engine — agrees with crisp_notation.
      expect(midis('X:1\nM:4/4\nL:1/4\nK:G\n=f f | f f |\n'),
          [77, 77, 78, 78]); // F♮ F♮ | F♯ F♯
    });

    test('a flat carries within the bar too', () {
      // `_B` (B♭) carries to a later bare `B` in the same bar (essentune11).
      expect(midis('X:1\nM:4/4\nL:1/4\nK:C\n_B B | B B |\n'),
          [70, 70, 71, 71]); // B♭ B♭ | B♮ B♮
    });

    test('bare notes take the key signature (K:D sharpens f and c)', () {
      // tune07: K:D with no explicit accidentals — bare `f`/`c` are F♯/C♯, bare
      // `b` is B♮. music21 wrongly gave naturals + B♭ here. (Lowercase letters
      // are the octave-5 register in ABC.)
      expect(midis('X:1\nM:4/4\nL:1/4\nK:D\nf c b e |\n'),
          [78, 73, 83, 76]); // F♯5 C♯5 B5 E5
    });

    test('broken rhythm `a>b` dots the first and halves the second', () {
      // A hornpipe figure. music21 ignores `>` and gives uniform durations;
      // crisp_notation (and Verovio, and abc2midi) apply it.
      final m =
          scoreFromAbc('X:1\nM:4/4\nL:1/4\nK:C\nc>d e>f |\n').measures.single;
      final durs = [
        for (var i = 0; i < 4; i++) m.effectiveDurationAt(i).toString()
      ];
      expect(durs, ['3/8', '1/8', '3/8', '1/8']); // dotted-8th, 16th, …
    });

    test('a mid-tune [K:…] change re-bases subsequent bare-note accidentals',
        () {
      // After `[K:D]`, bare `f` becomes F♯ (the new key), not F♮.
      expect(midis('X:1\nM:4/4\nL:1/4\nK:C\nf f |[K:D] f f |\n'),
          [77, 77, 78, 78]); // F♮ F♮ (C major) | F♯ F♯ (D major)
    });
  });
}

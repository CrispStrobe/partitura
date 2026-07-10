/// Clefs and clef-relative staff arithmetic.
library;

import 'pitch.dart';

/// The clefs supported in v0.1 (alto/tenor are v0.2 candidates).
enum Clef {
  /// G clef anchored on the second staff line from the bottom, G4
  /// (Violinschlüssel).
  treble,

  /// F clef anchored on the fourth staff line from the bottom, F3
  /// (Bassschlüssel).
  bass;

  /// Absolute diatonic index ([Pitch.diatonicIndex]) of the natural pitch
  /// sitting on the bottom staff line: E4 (30) for treble, G2 (18) for bass.
  int get bottomLineDiatonicIndex => switch (this) {
        Clef.treble => 30,
        Clef.bass => 18,
      };

  /// The natural (unaltered) pitch at [staffPosition], where 0 is the bottom
  /// staff line and each line/space upward adds 1 (the [Pitch.staffPosition]
  /// convention). Positions outside 0–8 lie in the ledger-line range.
  Pitch pitchAt(int staffPosition) {
    final d = bottomLineDiatonicIndex + staffPosition;
    return Pitch(Step.values[d % 7], octave: (d - d % 7) ~/ 7);
  }
}

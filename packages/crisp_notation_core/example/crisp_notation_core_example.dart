// A tour of crisp_notation_core: the music-theory model and the terse score
// DSL — pure Dart, no renderer or assets required. Run with:
//
//   dart run example/crisp_notation_core_example.dart
//
// (Rendering a score to visual primitives is done by the deterministic
// LayoutEngine, which needs SMuFL font metrics — see the `crisp_notation`
// Flutter package for the metadata-loaded rendering pipeline.)
import 'package:crisp_notation_core/crisp_notation_core.dart';

void main() {
  // Theory: pitches, keys, scales, triads, functional harmony.
  const key = Key.major(Pitch(Step.d));
  print(key.signature.alteredSteps); // [Step.f, Step.c]
  print(key.triadFor(HarmonicFunction.dominant)); // Triad(A4 major)
  print(const Scale(Pitch(Step.a), ScaleType.harmonicMinor).pitches);

  // A score from the terse DSL (measures split on '|', chords with '+').
  final score = Score.simple(
    timeSignature: TimeSignature.fourFour,
    notes: 'c4:q e4 g4 c5 | c4+e4+g4:h r:h',
  );
  print(score.measures.first.totalDuration); // 1/1 — fills the 4/4 measure
  print(score.measures.length); // 2
}

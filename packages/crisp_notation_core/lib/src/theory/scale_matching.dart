/// Scale derivation (Phase 4.8).
///
/// Ranks the scales whose pitch-class content fits a set of pitch classes — the
/// "what scale(s) do these notes come from?" query. Pure theory.
library;

import 'pitch.dart';
import 'scale.dart';

/// Every [Scale] (over all 12 tonics and every [ScaleType]) whose pitch classes
/// contain all of [pcs], best fit first. A scale "rooted" in the set (its tonic
/// is one of [pcs]) ranks ahead of one that merely contains them; then major
/// before the minor modes; then by tonic. Empty if no scale contains the set
/// (e.g. three chromatically adjacent notes).
List<Scale> matchingScales(Set<int> pcs) {
  final matches = <Scale>[];
  final rooted = <bool>[];
  for (var t = 0; t < 12; t++) {
    for (final type in ScaleType.values) {
      final scalePcs = {
        for (final o in Scale.semitoneOffsetsFor(type)) (t + o) % 12
      };
      if (pcs.every(scalePcs.contains)) {
        matches.add(Scale(_spellTonic(t), type));
        rooted.add(pcs.contains(t));
      }
    }
  }
  final order = [for (var i = 0; i < matches.length; i++) i]..sort((a, b) {
      if (rooted[a] != rooted[b]) return rooted[a] ? -1 : 1;
      final byType = matches[a].type.index.compareTo(matches[b].type.index);
      if (byType != 0) return byType;
      return matches[a].tonic.midiNumber.compareTo(matches[b].tonic.midiNumber);
    });
  return [for (final i in order) matches[i]];
}

/// A conventional spelling for tonic pitch class [pc] (flats for the usual flat
/// keys; F♯ for the one sharp key).
Pitch _spellTonic(int pc) {
  const table = [
    (Step.c, 0), (Step.d, -1), (Step.d, 0), (Step.e, -1), //
    (Step.e, 0), (Step.f, 0), (Step.f, 1), (Step.g, 0),
    (Step.a, -1), (Step.a, 0), (Step.b, -1), (Step.b, 0),
  ];
  final (step, alter) = table[pc];
  return Pitch(step, alter: alter, octave: 4);
}

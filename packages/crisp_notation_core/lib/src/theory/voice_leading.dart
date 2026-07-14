/// Part-writing / voice-leading analysis (Phase 4.2).
///
/// [checkVoiceLeading] flags the classic four-part-writing errors — parallel
/// and hidden (direct) perfect fifths/octaves, voice crossing and overlap, and
/// upper-voice spacing — over a sequence of chords. Pure theory (no rendering);
/// the pedagogy target for harmony exercises.
library;

import 'dart:math';

import 'pitch.dart';

/// A part-writing rule [checkVoiceLeading] can flag.
enum VoiceLeadingRule {
  /// Two voices move in the same direction from one perfect fifth to another.
  parallelFifths,

  /// Two voices move in the same direction from one octave/unison to another.
  parallelOctaves,

  /// The outer voices reach a perfect fifth by similar motion with a leap in
  /// the top voice (a "direct" fifth).
  hiddenFifths,

  /// The outer voices reach an octave by similar motion with a leap on top.
  hiddenOctaves,

  /// A lower voice sounds above a higher one within a chord.
  voiceCrossing,

  /// A voice moves past where an adjacent voice was in the previous chord.
  voiceOverlap,

  /// Adjacent upper voices are more than an octave apart (the bass–tenor gap
  /// is exempt).
  spacing,
}

/// One flagged part-writing problem, between voices [upperVoice] and
/// [lowerVoice] (voice indices; 0 = top). [chordIndex] is where it occurs — for
/// the motion rules (parallels, hidden, overlap) it is the *second* chord of
/// the pair.
class VoiceLeadingIssue {
  /// The rule that was broken.
  final VoiceLeadingRule rule;

  /// The chord the issue is reported at.
  final int chordIndex;

  /// The higher of the two voices (smaller index).
  final int upperVoice;

  /// The lower of the two voices (larger index).
  final int lowerVoice;

  /// Creates a voice-leading issue.
  const VoiceLeadingIssue(
      this.rule, this.chordIndex, this.upperVoice, this.lowerVoice);

  @override
  bool operator ==(Object other) =>
      other is VoiceLeadingIssue &&
      other.rule == rule &&
      other.chordIndex == chordIndex &&
      other.upperVoice == upperVoice &&
      other.lowerVoice == lowerVoice;

  @override
  int get hashCode => Object.hash(rule, chordIndex, upperVoice, lowerVoice);

  @override
  String toString() => 'VoiceLeadingIssue(${rule.name} @ chord $chordIndex, '
      'voices $upperVoice-$lowerVoice)';
}

/// Analyses the part-writing of [chords] — each a list of pitches ordered from
/// the top voice (index 0) down to the bass — and returns every issue found, in
/// chord order. Chords may have different voice counts; a rule between two
/// voices is only checked where both are present.
List<VoiceLeadingIssue> checkVoiceLeading(List<List<Pitch>> chords) {
  final issues = <VoiceLeadingIssue>[];

  // Within-chord checks: crossing and spacing.
  for (var c = 0; c < chords.length; c++) {
    final ch = chords[c];
    for (var j = 0; j + 1 < ch.length; j++) {
      if (ch[j + 1].midiNumber > ch[j].midiNumber) {
        issues.add(
            VoiceLeadingIssue(VoiceLeadingRule.voiceCrossing, c, j, j + 1));
      }
      // Spacing applies to adjacent upper voices only (the bottom pair — the
      // bass and the voice above it — may be wider than an octave).
      if (j + 1 < ch.length - 1 &&
          ch[j].midiNumber - ch[j + 1].midiNumber > 12) {
        issues.add(VoiceLeadingIssue(VoiceLeadingRule.spacing, c, j, j + 1));
      }
    }
  }

  // Between-chord motion checks.
  for (var c = 0; c + 1 < chords.length; c++) {
    final a = chords[c];
    final b = chords[c + 1];
    final n = min(a.length, b.length);
    for (var u = 0; u < n; u++) {
      for (var l = u + 1; l < n; l++) {
        final before = a[u].midiNumber - a[l].midiNumber; // > 0 (u above l)
        final after = b[u].midiNumber - b[l].midiNumber;
        final upMove = b[u].midiNumber - a[u].midiNumber;
        final lowMove = b[l].midiNumber - a[l].midiNumber;
        final sameDir =
            upMove != 0 && lowMove != 0 && upMove.sign == lowMove.sign;

        // Parallel perfect fifths / octaves: same direction, interval preserved.
        if (sameDir && before % 12 == after % 12) {
          if (after % 12 == 7) {
            issues.add(VoiceLeadingIssue(
                VoiceLeadingRule.parallelFifths, c + 1, u, l));
          } else if (after % 12 == 0) {
            issues.add(VoiceLeadingIssue(
                VoiceLeadingRule.parallelOctaves, c + 1, u, l));
          }
        }

        // Hidden (direct) fifths/octaves: outer voices only, reaching the
        // interval by similar motion (not already there) with a leap on top.
        if (u == 0 &&
            l == n - 1 &&
            sameDir &&
            before % 12 != after % 12 &&
            upMove.abs() > 2) {
          if (after % 12 == 7) {
            issues.add(
                VoiceLeadingIssue(VoiceLeadingRule.hiddenFifths, c + 1, u, l));
          } else if (after % 12 == 0) {
            issues.add(
                VoiceLeadingIssue(VoiceLeadingRule.hiddenOctaves, c + 1, u, l));
          }
        }

        // Overlap: adjacent voices only — a voice crosses past where its
        // neighbour was in the previous chord.
        if (l == u + 1 &&
            (b[l].midiNumber > a[u].midiNumber ||
                b[u].midiNumber < a[l].midiNumber)) {
          issues.add(
              VoiceLeadingIssue(VoiceLeadingRule.voiceOverlap, c + 1, u, l));
        }
      }
    }
  }

  return issues;
}

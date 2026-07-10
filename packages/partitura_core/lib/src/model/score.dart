/// The score document model and the `Score.simple` string DSL.
library;

import '../internal/util.dart';
import '../theory/clef.dart';
import '../theory/duration.dart';
import '../theory/key_signature.dart';
import '../theory/pitch.dart';
import '../theory/time_signature.dart';
import 'element.dart';
import 'measure.dart';

/// A single-staff score: clef, signatures and measures.
class Score {
  /// The staff's clef.
  final Clef clef;

  /// The key signature (default: no sharps or flats).
  final KeySignature keySignature;

  /// The time signature; null renders an unmetered snippet (no time
  /// signature drawn, measure lengths unchecked).
  final TimeSignature? timeSignature;

  /// The measures in order.
  final List<Measure> measures;

  /// Creates a score (treat [measures] as immutable).
  const Score({
    required this.clef,
    this.keySignature = const KeySignature(0),
    this.timeSignature,
    required this.measures,
  });

  /// Builds a score from a terse note string, for tests and games.
  ///
  /// Grammar (whitespace-separated tokens, measures separated by `|`):
  ///
  /// ```text
  /// notes    := measure ('|' measure)*
  /// token    := rest | chord
  /// rest     := 'r' (':' duration)?
  /// chord    := pitch ('+' pitch)* (':' duration)?
  /// pitch    := stepLetter accidental? octaveDigit(s)     // see Pitch.parse
  /// duration := ('w'|'h'|'q'|'e'|'s') ('.' | '..')?
  /// ```
  ///
  /// - Durations are sticky: a token without `:duration` reuses the previous
  ///   token's duration (initially quarter). `w h q e s` are whole to
  ///   sixteenth; dots follow the letter (`q.` = dotted quarter).
  /// - A trailing `~` ties the note/chord to the next note element
  ///   (`c4:q~ c4:q`), also across a barline.
  /// - The accidental `n` parses as an explicit natural and forces the
  ///   accidental to be drawn (`showAccidental: true`).
  /// - Every element is auto-assigned the id `e0`, `e1`, … in reading order,
  ///   so games can address them immediately.
  ///
  /// Examples: `Score.simple(notes: 'c4:q d4 e4:h')`,
  /// `Score.simple(notes: 'c4+e4+g4:h r:h | g4:w')`.
  ///
  /// Throws a [FormatException] on malformed input.
  factory Score.simple({
    Clef clef = Clef.treble,
    KeySignature keySignature = const KeySignature(0),
    TimeSignature? timeSignature,
    required String notes,
  }) {
    var duration = NoteDuration.quarter;
    var nextId = 0;
    final measures = <Measure>[];
    for (final measureSource in notes.split('|')) {
      final elements = <MusicElement>[];
      for (var token in measureSource.trim().split(RegExp(r'\s+'))) {
        if (token.isEmpty) continue;
        var tied = false;
        if (token.endsWith('~')) {
          tied = true;
          token = token.substring(0, token.length - 1);
        }
        final parts = token.split(':');
        if (parts.length > 2) {
          throw FormatException('Invalid token: "$token"');
        }
        if (parts.length == 2) {
          duration = _parseDuration(parts[1], token);
        }
        final id = 'e${nextId++}';
        if (parts[0] == 'r') {
          if (tied) {
            throw FormatException('A rest cannot be tied: "$token~"');
          }
          elements.add(RestElement(duration, id: id));
        } else {
          final sources = parts[0].split('+');
          final pitches = sources.map(Pitch.parse).toList();
          final forced = sources.any(_hasExplicitNatural);
          elements.add(NoteElement(
            pitches: pitches,
            duration: duration,
            showAccidental: forced ? true : null,
            tieToNext: tied,
            id: id,
          ));
        }
      }
      measures.add(Measure(elements));
    }
    return Score(
      clef: clef,
      keySignature: keySignature,
      timeSignature: timeSignature,
      measures: measures,
    );
  }

  static bool _hasExplicitNatural(String pitchSource) =>
      RegExp(r'^[a-gA-G]n').hasMatch(pitchSource.trim());

  static const Map<String, DurationBase> _durationLetters = {
    'w': DurationBase.whole,
    'h': DurationBase.half,
    'q': DurationBase.quarter,
    'e': DurationBase.eighth,
    's': DurationBase.sixteenth,
  };

  static NoteDuration _parseDuration(String source, String token) {
    final match = RegExp(r'^([whqes])(\.{0,2})$').firstMatch(source);
    if (match == null) {
      throw FormatException('Invalid duration in token: "$token"');
    }
    return NoteDuration(
      _durationLetters[match[1]]!,
      dots: match[2]!.length,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Score &&
      other.clef == clef &&
      other.keySignature == keySignature &&
      other.timeSignature == timeSignature &&
      listEquals(other.measures, measures);

  @override
  int get hashCode => Object.hash(
        clef,
        keySignature,
        timeSignature,
        Object.hashAll(measures),
      );

  @override
  String toString() =>
      'Score(${clef.name}, $keySignature, ${timeSignature ?? 'unmetered'}, '
      '${measures.length} measures)';
}

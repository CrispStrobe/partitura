/// PrIMuS-style *semantic* music notation → [Score].
///
/// CrispEmbed's Polyphonic-TrOMR optical-music-recognition engine emits a
/// single staff as a `+`-joined stream of semantic tokens:
///
///   * `clef-G2`, `clef-F4`, … — clef (letter + line, as in Humdrum);
///   * `keySignature-EbM` / `keySignature-F#m` — tonic + `M`/`m` mode;
///   * `timeSignature-3/4`, `timeSignature-C`, `timeSignature-C/` — meter;
///   * `note-C#5_eighth`, `note-Bb3_quarter.` — pitch (+ accidental) `_` duration
///     (dotted with a trailing `.`); a chord joins its notes with `|`
///     (`note-C4_quarter|note-E4_quarter`);
///   * `rest-quarter` / `nonote_eighth` — a rest of that duration;
///   * `barline` — a measure boundary.
///
/// Unlike the Sheet Music Transformer (grand staff → [GrandStaff]), TrOMR is a
/// single polyphonic staff, so this yields one [Score]. Pure Dart.
library;

import '../model/element.dart';
import '../model/measure.dart';
import '../model/score.dart';
import '../theory/clef.dart';
import '../theory/duration.dart';
import '../theory/key_signature.dart';
import '../theory/pitch.dart';
import '../theory/time_signature.dart';

const _specials = {'<bos>', '<eos>', '<pad>', '<unk>', ''};

const _semanticDur = {
  'double_whole': DurationBase.breve,
  'whole': DurationBase.whole,
  'half': DurationBase.half,
  'quarter': DurationBase.quarter,
  'eighth': DurationBase.eighth,
  'sixteenth': DurationBase.sixteenth,
  'thirty_second': DurationBase.thirtySecond,
  'sixty_fourth': DurationBase.sixtyFourth,
};

/// Parses a TrOMR *semantic* token stream into a single-staff [Score].
///
/// Throws [FormatException] if no music tokens are present.
Score scoreFromSemantic(String semantic) {
  final tokens = semantic
      .split('+')
      .map((t) => t.trim())
      .where((t) => !_specials.contains(t))
      .toList();
  if (tokens.isEmpty) throw const FormatException('empty semantic stream');
  return _SemanticReader(tokens).read();
}

class _SemanticReader {
  final List<String> tokens;
  _SemanticReader(this.tokens);

  int _nextId = 0;
  bool _started = false;
  Clef _clef = Clef.treble;
  KeySignature _key = const KeySignature(0);
  TimeSignature? _time;

  Clef _leadingClef = Clef.treble;
  KeySignature _leadingKey = const KeySignature(0);
  TimeSignature? _leadingTime;

  final _measures = <Measure>[];
  var _current = <MusicElement>[];
  Clef? _pendingClef;
  KeySignature? _pendingKey;
  TimeSignature? _pendingTime;

  String _newId() => 'e${_nextId++}';

  Score read() {
    for (final token in tokens) {
      if (token == 'barline' || token.startsWith('barline-')) {
        _finishMeasure();
      } else if (token.startsWith('clef-')) {
        _applyClef(_clefOf(token.substring(5)));
      } else if (token.startsWith('keySignature-')) {
        _applyKey(_keyOf(token.substring(13)));
      } else if (token.startsWith('timeSignature-')) {
        _applyTime(_meterOf(token.substring(14)));
      } else if (token.startsWith('rest-') || token.startsWith('nonote')) {
        _started = true;
        _current.add(RestElement(_restDuration(token), id: _newId()));
      } else if (token.contains('note-') || token.contains('|')) {
        final el = _noteOrChord(token);
        if (el != null) {
          _started = true;
          _current.add(el);
        }
      }
      // Unknown tokens (multirest, gracenote, tie markers, …) are ignored.
    }
    if (_current.isNotEmpty) _finishMeasure();
    return Score(
      clef: _leadingClef,
      keySignature: _leadingKey,
      timeSignature: _leadingTime,
      measures: withDetectedPickup(_measures, _leadingTime),
    );
  }

  void _finishMeasure() {
    if (_current.isEmpty && _measures.isEmpty) return; // leading barline
    _measures.add(Measure(
      _current,
      clefChange: _pendingClef,
      keyChange: _pendingKey,
      timeChange: _pendingTime,
    ));
    _current = <MusicElement>[];
    _pendingClef = null;
    _pendingKey = null;
    _pendingTime = null;
  }

  bool get _atStart => !_started && _measures.isEmpty && _current.isEmpty;

  void _applyClef(Clef clef) {
    if (_atStart) {
      _leadingClef = _clef = clef;
    } else if (clef != _clef) {
      _pendingClef = clef;
      _clef = clef;
    }
  }

  void _applyKey(KeySignature key) {
    if (_atStart) {
      _leadingKey = _key = key;
    } else if (key != _key) {
      _pendingKey = key;
      _key = key;
    }
  }

  void _applyTime(TimeSignature? time) {
    if (time == null) return;
    if (_atStart) {
      _leadingTime = _time = time;
    } else if (time != _time) {
      _pendingTime = time;
      _time = time;
    }
  }

  MusicElement? _noteOrChord(String token) {
    // A chord is `|`-separated; every part carries its own `_duration`, all
    // equal, so the first drives the note's value.
    final parts = token.split('|');
    final pitches = <Pitch>[];
    NoteDuration? duration;
    for (final part in parts) {
      final body = part.startsWith('note-') ? part.substring(5) : part;
      final us = body.indexOf('_');
      if (us < 0) continue;
      final pitch = _pitchOf(body.substring(0, us));
      duration ??= _durationOf(body.substring(us + 1));
      if (pitch != null) pitches.add(pitch);
    }
    if (pitches.isEmpty || duration == null) return null;
    return NoteElement(pitches: pitches, duration: duration, id: _newId());
  }

  NoteDuration _restDuration(String token) {
    final us = token.indexOf('_');
    final dur = us >= 0 ? token.substring(us + 1) : 'quarter';
    return _durationOf(dur);
  }

  static NoteDuration _durationOf(String raw) {
    var dur = raw;
    var dots = 0;
    while (dur.endsWith('.')) {
      dots++;
      dur = dur.substring(0, dur.length - 1);
    }
    var base = _semanticDur[dur];
    // Tolerate trailing decorations (`quarter_fermata`) by trimming segments.
    while (base == null && dur.contains('_')) {
      dur = dur.substring(0, dur.lastIndexOf('_'));
      base = _semanticDur[dur];
    }
    if (base == null) throw FormatException('bad semantic duration: "$raw"');
    return NoteDuration(base, dots: dots.clamp(0, 2));
  }

  static Pitch? _pitchOf(String raw) {
    // Step + accidentals (either side of the octave) + octave, e.g. `C#5`,
    // `Bb3`, or the engine's `C5#` / `EN4`.
    final m = RegExp(r'^([A-Ga-g])([#bN]*)(-?\d+)([#bN]*)$').firstMatch(raw);
    if (m == null) return null;
    final step = Step.values.asNameMap()[m[1]!.toLowerCase()];
    if (step == null) return null;
    var alter = 0;
    for (final c in (m[2]! + m[4]!).split('')) {
      if (c == '#') alter++;
      if (c == 'b') alter--;
    }
    return Pitch(step, alter: alter, octave: int.parse(m[3]!));
  }

  static Clef _clefOf(String code) {
    final m = RegExp(r'([GFC])(\d)').firstMatch(code);
    if (m == null) return Clef.treble;
    final line = int.parse(m[2]!);
    return switch (m[1]) {
      'G' when line == 1 => Clef.frenchViolin,
      'G' => Clef.treble,
      'F' when line == 3 => Clef.baritone,
      'F' when line == 5 => Clef.subbass,
      'F' => Clef.bass,
      'C' when line == 1 => Clef.soprano,
      'C' when line == 2 => Clef.mezzoSoprano,
      'C' when line == 4 => Clef.tenor,
      'C' => Clef.alto,
      _ => Clef.treble,
    };
  }

  static const _fifthsMajor = {
    'C': 0,
    'G': 1,
    'D': 2,
    'A': 3,
    'E': 4,
    'B': 5,
    'F#': 6,
    'C#': 7,
    'F': -1,
    'Bb': -2,
    'Eb': -3,
    'Ab': -4,
    'Db': -5,
    'Gb': -6,
    'Cb': -7,
  };
  // Minor keys share a signature with the major a minor-third up.
  static const _fifthsMinor = {
    'A': 0,
    'E': 1,
    'B': 2,
    'F#': 3,
    'C#': 4,
    'G#': 5,
    'D#': 6,
    'A#': 7,
    'D': -1,
    'G': -2,
    'C': -3,
    'F': -4,
    'Bb': -5,
    'Eb': -6,
    'Ab': -7,
  };

  static KeySignature _keyOf(String spec) {
    // `EbM`, `F#m`, `Cm`, `AM` …
    final minor = spec.endsWith('m');
    final tonic = spec.substring(0, spec.length - 1);
    final fifths = (minor ? _fifthsMinor : _fifthsMajor)[tonic];
    return KeySignature((fifths ?? 0).clamp(-7, 7));
  }

  static TimeSignature? _meterOf(String spec) {
    if (spec == 'C') {
      return const TimeSignature(4, 4, symbol: TimeSymbol.common);
    }
    if (spec == 'C/') return const TimeSignature(2, 2, symbol: TimeSymbol.cut);
    final m = RegExp(r'^(\d+)/(\d+)$').firstMatch(spec);
    if (m == null) return null;
    return TimeSignature(int.parse(m[1]!), int.parse(m[2]!));
  }
}

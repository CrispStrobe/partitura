/// Guitar Pro 5 (`.gp5`) binary import.
///
/// GP5 is a version-tagged **binary** format (unlike the GP6/7/8 gpif XML), so
/// this is a from-scratch byte/bit-exact reader — ported from the reference
/// layout in PyGuitarPro. It parses the essential musical data (measures, time
/// signatures, per-track tunings, and notes as string+fret → pitch, with the
/// common note techniques) into a partitura [Score]; the many effect/RSE/mix
/// structures are parsed only far enough to stay byte-aligned, then discarded.
/// Pure Dart (web-safe). Validated against the alphaTab GP5 test corpus.
library;

import 'dart:typed_data';

import '../model/element.dart';
import '../model/measure.dart';
import '../model/score.dart';
import '../theory/clef.dart';
import '../theory/duration.dart';
import '../theory/pitch.dart';
import '../theory/time_signature.dart';

/// Parses Guitar Pro 5 [bytes] into a [Score] (the [trackIndex]-th track).
///
/// Throws [FormatException] if the file is not a recognizable GP5 document.
Score gp5ToScore(Uint8List bytes, {int trackIndex = 0}) {
  final r = _Reader(bytes);
  final version = r.byteSizeString(30);
  if (!version.contains('v5.')) {
    throw FormatException('not a Guitar Pro 5 file ("$version")');
  }
  final v510 = version.contains('5.10');

  // Score info: title..instructions (9 strings) + notices.
  for (var i = 0; i < 9; i++) {
    r.intByteSizeString();
  }
  final noticeCount = r.i32();
  for (var i = 0; i < noticeCount; i++) {
    r.intByteSizeString();
  }

  // Lyrics: track choice + 5 lines (measure int + int-size string).
  r.i32();
  for (var i = 0; i < 5; i++) {
    r.i32();
    r.skip(r.i32());
  }

  // RSE master effect (5.10+ only): volume, reserved, equalizer(11).
  if (v510) {
    r.i32();
    r.i32();
    r.skip(11);
  }

  _readPageSetup(r);
  r.intByteSizeString(); // tempo name
  r.i32(); // tempo
  if (v510) r.u8(); // hide tempo
  r.i8(); // key
  r.i32(); // octave
  _readMidiChannels(r);
  r.skip(19 * 2); // directions (19 shorts)
  r.i32(); // master reverb
  final measureCount = r.i32();
  final trackCount = r.i32();

  // Measure headers → time signatures per measure.
  final timeSigs = <TimeSignature>[];
  var num = 4, den = 4;
  for (var m = 0; m < measureCount; m++) {
    if (m > 0) r.skip(1);
    final flags = r.u8();
    if (flags & 0x01 != 0) num = r.i8();
    if (flags & 0x02 != 0) den = r.i8();
    if (flags & 0x04 != 0) {} // repeat open
    if (flags & 0x08 != 0) r.i8(); // repeat close
    if (flags & 0x20 != 0) {
      r.intByteSizeString(); // marker title
      r.skip(4); // marker color
    }
    if (flags & 0x40 != 0) r.skip(2); // key sig root+type
    if (flags & 0x10 != 0) r.u8(); // repeat alternative
    if (flags & 0x03 != 0) r.skip(4); // beams
    if (flags & 0x10 == 0) r.skip(1);
    r.u8(); // triplet feel
    timeSigs.add(TimeSignature(num, den));
  }

  // Tracks → tunings (MIDI number per string, string 1 first).
  final tunings = <List<int>>[];
  for (var t = 0; t < trackCount; t++) {
    if (t == 0 || !v510) r.skip(1);
    r.u8(); // flags1
    r.byteSizeString(40); // name
    final stringCount = r.i32();
    final strings = <int>[];
    for (var i = 0; i < 7; i++) {
      final tuning = r.i32();
      if (i < stringCount) strings.add(tuning);
    }
    tunings.add(strings);
    r.i32(); // port
    r.i32(); // channel index
    r.i32(); // effect channel
    r.i32(); // fret count
    r.i32(); // capo
    r.skip(4); // color
    r.i16(); // flags2
    r.u8(); // auto accentuation
    r.u8(); // bank
    r.u8(); // humanize
    r.i32(); // clef transpose
    r.i32(); // clef transpose secondary
    r.i32(); // ???
    r.skip(12); // ???
    _readRseInstrument(r, v510);
    if (v510) {
      r.skip(4); // equalizer(4)
      r.intByteSizeString(); // rse effect
      r.intByteSizeString(); // rse effect category
    }
  }
  r.skip(v510 ? 1 : 2); // after tracks

  // Measures: for each header, for each track, read the (two-voice) measure.
  // We keep only the requested track's first voice.
  final builder = _ScoreBuilder();
  final track = tunings.isEmpty ? 0 : trackIndex.clamp(0, tunings.length - 1);
  final tuning = tunings.isEmpty ? _standard : tunings[track];
  for (var m = 0; m < measureCount; m++) {
    for (var t = 0; t < trackCount; t++) {
      final keep = t == track;
      builder.startMeasure(keep);
      for (var voice = 0; voice < 2; voice++) {
        final beats = r.i32();
        for (var b = 0; b < beats; b++) {
          _readBeat(r, tuning, keep && voice == 0, builder, v510);
        }
      }
      r.u8(); // line break
    }
  }

  return builder.build(timeSigs);
}

const _standard = [64, 59, 55, 50, 45, 40];

void _readPageSetup(_Reader r) {
  r.skip(4 * 2); // page size
  r.skip(4 * 4); // margins
  r.i32(); // score size proportion
  r.i16(); // header/footer
  for (var i = 0; i < 6; i++) {
    r.intByteSizeString(); // title..music
  }
  r.intByteSizeString(); // words and music
  r.intByteSizeString(); // copyright line 1
  r.intByteSizeString(); // copyright line 2
  r.intByteSizeString(); // page number
}

void _readMidiChannels(_Reader r) {
  for (var i = 0; i < 64; i++) {
    r.i32(); // instrument
    r.skip(6); // volume,balance,chorus,reverb,phaser,tremolo
    r.skip(2); // blank
  }
}

void _readRseInstrument(_Reader r, bool v510) {
  r.i32(); // instrument
  r.i32(); // unknown
  r.i32(); // sound bank
  if (v510) {
    r.i32(); // effect number
  } else {
    r.i16();
    r.skip(1);
  }
}

void _readBeat(
    _Reader r, List<int> tuning, bool keep, _ScoreBuilder builder, bool v510) {
  final flags = r.u8();
  var status = 1; // normal
  if (flags & 0x40 != 0) status = r.u8(); // 0 empty, 1 normal, 2 rest
  // Duration.
  final durByte = r.i8();
  final dotted = flags & 0x01 != 0;
  if (flags & 0x20 != 0) r.i32(); // tuplet
  if (flags & 0x02 != 0) _readChord(r); // chord diagram
  if (flags & 0x04 != 0) r.intByteSizeString(); // text
  var beatBend = false;
  if (flags & 0x08 != 0) beatBend = _readBeatEffects(r);
  if (flags & 0x10 != 0) _readMixTableChange(r, v510); // mix table
  // Notes: one bit per string (string 1 = bit 6 … string 6 = bit 1).
  final stringFlags = r.u8();
  final pitches = <Pitch>[];
  var dead = false, harmonic = false, hammer = false, slide = false;
  var bend = false;
  double bendSteps = 0;
  for (var s = 1; s <= tuning.length; s++) {
    if (stringFlags & (1 << (7 - s)) == 0) continue;
    final note = _readNote(r, s, tuning);
    if (note == null) continue;
    if (note.dead) {
      dead = true;
    } else {
      pitches.add(note.pitch);
    }
    harmonic = harmonic || note.harmonic;
    hammer = hammer || note.hammer;
    slide = slide || note.slide;
    if (note.bendSteps > 0) {
      bend = true;
      bendSteps = note.bendSteps > bendSteps ? note.bendSteps : bendSteps;
    }
  }
  // GP5 beat trailer.
  final flags2 = r.i16();
  if (flags2 & 0x0800 != 0) r.u8();

  if (beatBend) bend = true; // whammy/tremolo-bar → a bend mark
  final duration = _durationOf(durByte, dotted);
  if (!keep) return;
  builder.addBeat(
    status: status,
    duration: duration,
    pitches: pitches,
    dead: dead,
    harmonic: harmonic,
    hammer: hammer,
    slide: slide,
    bend: bend,
    bendSteps: bendSteps > 0 ? bendSteps : (bend ? 1.0 : 0),
  );
}

bool _readBeatEffects(_Reader r) {
  final f1 = r.i8();
  final f2 = r.i8();
  if (f1 & 0x20 != 0) r.i8(); // slap
  var bar = false;
  if (f2 & 0x04 != 0) {
    _readBend(r); // tremolo bar
    bar = true;
  }
  if (f1 & 0x40 != 0) r.skip(2); // beat stroke
  if (f2 & 0x02 != 0) r.i8(); // pick stroke
  return bar;
}

void _readMixTableChange(_Reader r, bool v510) {
  r.i8(); // instrument
  _readRseInstrument(r, v510);
  if (!v510) r.skip(1);
  final vals = <bool>[];
  for (var i = 0; i < 6; i++) {
    vals.add(r.i8() >= 0); // volume,balance,chorus,reverb,phaser,tremolo
  }
  r.intByteSizeString(); // tempo name
  final tempo = r.i32();
  // Durations only for the items that were set (>= 0).
  for (final set in vals) {
    if (set) r.i8();
  }
  if (tempo >= 0) {
    r.i8();
    if (v510) r.u8(); // hide tempo
  }
  r.i8(); // mix table flags
  r.i8(); // wah
  if (v510) {
    r.intByteSizeString(); // rse effect
    r.intByteSizeString(); // rse effect category
  }
}

class _NoteData {
  final Pitch pitch;
  final bool dead;
  final bool harmonic;
  final bool hammer;
  final bool slide;
  final double bendSteps;
  _NoteData(this.pitch,
      {this.dead = false,
      this.harmonic = false,
      this.hammer = false,
      this.slide = false,
      this.bendSteps = 0});
}

_NoteData? _readNote(_Reader r, int stringNumber, List<int> tuning) {
  final flags = r.u8();
  var type = 1;
  if (flags & 0x20 != 0) type = r.u8(); // 1 normal, 2 tie, 3 dead
  if (flags & 0x10 != 0) r.i8(); // velocity
  var fret = 0;
  if (flags & 0x20 != 0) fret = r.i8();
  if (flags & 0x80 != 0) r.skip(2); // fingering
  if (flags & 0x01 != 0) r.skip(8); // duration percent (f64)
  r.u8(); // flags2
  var harmonic = false, hammer = false, slide = false;
  double bendSteps = 0;
  if (flags & 0x08 != 0) {
    final e = _readNoteEffects(r);
    harmonic = e.harmonic;
    hammer = e.hammer;
    slide = e.slide;
    bendSteps = e.bendSteps;
  }
  final dead = type == 3;
  final open = stringNumber - 1 < tuning.length
      ? tuning[stringNumber - 1]
      : _standard[(stringNumber - 1).clamp(0, 5)];
  final midi = (open + (fret >= 0 && fret < 100 ? fret : 0)).clamp(0, 127);
  return _NoteData(_pitchFromMidi(midi),
      dead: dead,
      harmonic: harmonic,
      hammer: hammer,
      slide: slide,
      bendSteps: bendSteps);
}

class _NoteEffects {
  final bool harmonic;
  final bool hammer;
  final bool slide;
  final double bendSteps;
  _NoteEffects(this.harmonic, this.hammer, this.slide, this.bendSteps);
}

_NoteEffects _readNoteEffects(_Reader r) {
  final f1 = r.i8();
  final f2 = r.i8();
  final hammer = f1 & 0x02 != 0;
  double bendSteps = 0;
  if (f1 & 0x01 != 0) bendSteps = _readBend(r);
  if (f1 & 0x10 != 0) r.skip(5); // grace (GP5: 5 bytes)
  if (f2 & 0x04 != 0) r.i8(); // tremolo picking
  final slide = f2 & 0x08 != 0;
  if (slide) r.u8(); // slide type
  var harmonic = false;
  if (f2 & 0x10 != 0) {
    harmonic = true;
    _readHarmonic(r);
  }
  if (f2 & 0x20 != 0) r.skip(2); // trill
  return _NoteEffects(harmonic, hammer, slide, bendSteps);
}

double _readBend(_Reader r) {
  r.i8(); // type
  final value = r.i32();
  final points = r.i32();
  for (var i = 0; i < points; i++) {
    r.skip(4 + 4 + 1); // position, value, vibrato
  }
  return value / 100.0;
}

void _readHarmonic(_Reader r) {
  final type = r.i8();
  if (type == 2) {
    r.u8();
    r.i8();
    r.u8();
  } else if (type == 3) {
    r.u8();
  }
}

void _readChord(_Reader r) {
  final newFormat = r.u8() != 0;
  if (!newFormat) {
    throw const FormatException('GP5 old-format chords unsupported');
  }
  r.u8(); // sharp
  r.skip(3);
  r.u8(); // root
  r.u8(); // type
  r.u8(); // extension
  r.i32(); // bass
  r.i32(); // tonality
  r.u8(); // add
  r.byteSizeString(22); // name
  r.u8(); // fifth
  r.u8(); // ninth
  r.u8(); // eleventh
  r.i32(); // first fret
  r.skip(7 * 4); // frets
  r.u8(); // barre count
  r.skip(5 * 3); // barre frets/starts/ends
  r.skip(7); // omissions
  r.skip(1);
  r.skip(7); // fingerings
  r.u8(); // show
}

NoteDuration _durationOf(int byte, bool dotted) {
  final base = switch (byte) {
    -2 => DurationBase.whole,
    -1 => DurationBase.half,
    0 => DurationBase.quarter,
    1 => DurationBase.eighth,
    2 => DurationBase.sixteenth,
    3 => DurationBase.thirtySecond,
    _ => DurationBase.sixtyFourth,
  };
  return NoteDuration(base, dots: dotted ? 1 : 0);
}

Pitch _pitchFromMidi(int key) {
  const table = [
    (Step.c, 0), (Step.c, 1), (Step.d, 0), (Step.d, 1), //
    (Step.e, 0), (Step.f, 0), (Step.f, 1), (Step.g, 0),
    (Step.g, 1), (Step.a, 0), (Step.a, 1), (Step.b, 0),
  ];
  final (step, alter) = table[key % 12];
  return Pitch(step, alter: alter, octave: key ~/ 12 - 1);
}

/// Accumulates the kept track's beats into measures + technique lists.
class _ScoreBuilder {
  final List<Measure> measures = [];
  final List<Slur> slurs = [];
  final List<Glissando> glissandos = [];
  final List<Bend> bends = [];
  final List<TabNoteMark> marks = [];
  List<MusicElement> _current = [];
  int _id = 0;
  String? _pendingHammer;
  String? _pendingSlide;

  void startMeasure(bool keep) {
    if (!keep) return;
    if (_current.isNotEmpty || measures.isNotEmpty) {
      measures.add(Measure(_current));
      _current = [];
    }
  }

  void addBeat({
    required int status,
    required NoteDuration duration,
    required List<Pitch> pitches,
    required bool dead,
    required bool harmonic,
    required bool hammer,
    required bool slide,
    required bool bend,
    required double bendSteps,
  }) {
    if (status == 0 && pitches.isEmpty && !dead) return; // empty beat
    final id = 'e${_id++}';
    if (pitches.isEmpty && !dead) {
      _current.add(RestElement(duration, id: id));
      return;
    }
    final ps = dead && pitches.isEmpty ? [_pitchFromMidi(40)] : pitches
      ..sort((a, b) => a.midiNumber.compareTo(b.midiNumber));
    _current.add(NoteElement(pitches: ps, duration: duration, id: id));

    final hf = _pendingHammer;
    if (hf != null) {
      slurs.add(Slur(hf, id));
      _pendingHammer = null;
    }
    final sf = _pendingSlide;
    if (sf != null) {
      glissandos.add(Glissando(sf, id));
      _pendingSlide = null;
    }
    if (harmonic) {
      marks.add(TabNoteMark(id, TabNoteStyle.harmonic));
    } else if (dead) {
      marks.add(TabNoteMark(id, TabNoteStyle.dead));
    }
    if (bend && bendSteps > 0) bends.add(Bend(id, steps: bendSteps));
    if (hammer) _pendingHammer = id;
    if (slide) _pendingSlide = id;
  }

  Score build(List<TimeSignature> timeSigs) {
    if (_current.isNotEmpty) measures.add(Measure(_current));
    if (measures.isEmpty) {
      measures.add(Measure([RestElement(NoteDuration.whole, id: 'e0')]));
    }
    return Score(
      clef: Clef.treble,
      timeSignature: timeSigs.isNotEmpty ? timeSigs.first : null,
      measures: measures,
      slurs: slurs,
      glissandos: glissandos,
      bends: bends,
      tabNoteMarks: marks,
    );
  }
}

/// Little-endian binary cursor with GP string helpers.
class _Reader {
  final Uint8List b;
  final ByteData _view;
  int pos = 0;
  _Reader(this.b) : _view = ByteData.sublistView(b);

  // Reads past the end return 0 (GP5 files carry a trailing byte the layout
  // doesn't describe; tolerating EOF keeps the last measure intact).
  int u8() {
    if (pos < b.length) return b[pos++];
    pos++;
    return 0;
  }

  int i8() {
    if (pos < b.length) return _view.getInt8(pos++);
    pos++;
    return 0;
  }

  int i16() {
    if (pos + 2 > b.length) {
      pos += 2;
      return 0;
    }
    final v = _view.getInt16(pos, Endian.little);
    pos += 2;
    return v;
  }

  int i32() {
    if (pos + 4 > b.length) {
      pos += 4;
      return 0;
    }
    final v = _view.getInt32(pos, Endian.little);
    pos += 4;
    return v;
  }

  void skip(int n) => pos += n;

  /// A `size`-byte string in a fixed [count]-byte field.
  String byteSizeString(int count) {
    final size = u8();
    final end = (pos + size <= b.length) ? pos + size : b.length;
    final s = String.fromCharCodes(b.sublist(pos.clamp(0, b.length), end));
    pos += count;
    return s;
  }

  String intByteSizeString() {
    final count = i32();
    return byteSizeString(count - 1);
  }
}

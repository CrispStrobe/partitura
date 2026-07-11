/// Guitar Pro 3/4/5 (`.gp3`/`.gp4`/`.gp5`) binary import.
///
/// These are version-tagged **binary** formats (unlike the GP6/7/8 gpif XML),
/// so this is a from-scratch byte/bit-exact reader — ported from the reference
/// layout in PyGuitarPro. It parses the essential musical data (measures, time
/// signatures, per-track tunings, and notes as string+fret → pitch, with the
/// common note techniques) into a partitura [Score]; the many effect/RSE/mix
/// structures are parsed only far enough to stay byte-aligned, then discarded.
/// The three versions share most of their layout; GP3/GP4 are handled by
/// [gp3ToScore]/[gp4ToScore] (a version-delta on the GP5 path — one voice per
/// measure, no RSE/page-setup/lyrics-in-GP3, different beat/note effect flags).
/// Pure Dart (web-safe). Validated against the alphaTab / PyGuitarPro corpora.
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

/// Parses Guitar Pro 3 [bytes] into a [Score] (the [trackIndex]-th track).
///
/// Throws [FormatException] if the file is not a recognizable GP3 document.
Score gp3ToScore(Uint8List bytes, {int trackIndex = 0}) =>
    _gp3or4ToScore(bytes, trackIndex, gp4: false);

/// Parses Guitar Pro 4 [bytes] into a [Score] (the [trackIndex]-th track).
///
/// Throws [FormatException] if the file is not a recognizable GP4 document.
Score gp4ToScore(Uint8List bytes, {int trackIndex = 0}) =>
    _gp3or4ToScore(bytes, trackIndex, gp4: true);

/// GP3 and GP4 share a layout; [gp4] selects the (small) v4 additions: lyrics
/// and an octave byte in the header, two-byte beat/note effect flags, and the
/// richer chord diagram. GP3 has a single voice per measure and stores
/// harmonics at the beat rather than the note level.
Score _gp3or4ToScore(Uint8List bytes, int trackIndex, {required bool gp4}) {
  final r = _Reader(bytes);
  final version = r.byteSizeString(30);
  final tag = gp4 ? 'v4.' : 'v3.';
  if (!version.contains(tag)) {
    throw FormatException('not a Guitar Pro ${gp4 ? 4 : 3} file ("$version")');
  }

  // Score info: title..instructions (8 strings) + notices.
  for (var i = 0; i < 8; i++) {
    r.intByteSizeString();
  }
  final noticeCount = r.i32();
  for (var i = 0; i < noticeCount; i++) {
    r.intByteSizeString();
  }
  r.u8(); // triplet feel (bool)
  if (gp4) {
    // Lyrics: track choice + 5 lines (measure int + int-size string).
    r.i32();
    for (var i = 0; i < 5; i++) {
      r.i32();
      r.skip(r.i32()); // int-size string body (no leading byte count)
    }
  }
  r.i32(); // tempo
  r.i32(); // key
  if (gp4) r.i8(); // octave (reserved)
  _readMidiChannels(r);
  final measureCount = r.i32();
  final trackCount = r.i32();

  // Measure headers → time signatures per measure.
  final timeSigs = <TimeSignature>[];
  var num = 4, den = 4;
  for (var m = 0; m < measureCount; m++) {
    final flags = r.u8();
    if (flags & 0x01 != 0) num = r.i8();
    if (flags & 0x02 != 0) den = r.i8();
    // 0x04 repeat open — presence only.
    if (flags & 0x08 != 0) r.i8(); // repeat close
    if (flags & 0x10 != 0) r.u8(); // repeat alternative
    if (flags & 0x20 != 0) {
      r.intByteSizeString(); // marker title
      r.skip(4); // marker color
    }
    if (flags & 0x40 != 0) r.skip(2); // key sig root+type
    // 0x80 double bar — presence only.
    timeSigs.add(TimeSignature(num, den));
  }

  // Tracks → tunings (MIDI number per string, string 1 first).
  final tunings = <List<int>>[];
  for (var t = 0; t < trackCount; t++) {
    r.u8(); // flags
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
  }

  // Measures: for each header, for each track, one voice of beats.
  final builder = _ScoreBuilder();
  final track = tunings.isEmpty ? 0 : trackIndex.clamp(0, tunings.length - 1);
  final tuning = tunings.isEmpty ? _standard : tunings[track];
  for (var m = 0; m < measureCount; m++) {
    for (var t = 0; t < trackCount; t++) {
      final keep = t == track;
      builder.startMeasure(keep);
      final beats = r.i32();
      for (var b = 0; b < beats; b++) {
        _readBeatGp34(r, tuning, keep, builder, gp4: gp4);
      }
    }
  }

  return builder.build(timeSigs);
}

void _readBeatGp34(
    _Reader r, List<int> tuning, bool keep, _ScoreBuilder builder,
    {required bool gp4}) {
  final flags = r.u8();
  var status = 1; // normal
  if (flags & 0x40 != 0) status = r.u8(); // 0 empty, 1 normal, 2 rest
  final durByte = r.i8();
  final dotted = flags & 0x01 != 0;
  if (flags & 0x20 != 0) r.i32(); // tuplet
  if (flags & 0x02 != 0) _readChordGp34(r, gp4: gp4);
  if (flags & 0x04 != 0) r.intByteSizeString(); // text
  var beatHarmonic = false, beatBar = false, beatVibrato = false;
  if (flags & 0x08 != 0) {
    final e = _readBeatEffectsGp34(r, gp4: gp4);
    beatHarmonic = e.harmonic;
    beatBar = e.bar;
    beatVibrato = e.vibrato;
  }
  if (flags & 0x10 != 0) _readMixTableChangeGp34(r, gp4: gp4);
  // Notes: one bit per string (string 1 = bit 6 … string 7 = bit 0).
  final stringFlags = r.u8();
  final pitches = <Pitch>[];
  var dead = false, harmonic = beatHarmonic, hammer = false, slide = false;
  var bend = false, vibrato = beatVibrato, palmMute = false, letRing = false;
  var harmonicStyle = TabNoteStyle.harmonic;
  double bendSteps = 0;
  for (var s = 1; s <= tuning.length; s++) {
    if (stringFlags & (1 << (7 - s)) == 0) continue;
    final note = _readNoteGp34(r, s, tuning, gp4: gp4);
    if (note == null) continue;
    if (note.dead) {
      dead = true;
    } else {
      pitches.add(note.pitch);
    }
    if (note.harmonic) {
      harmonic = true;
      harmonicStyle = note.harmonicStyle;
    }
    hammer = hammer || note.hammer;
    slide = slide || note.slide;
    vibrato = vibrato || note.vibrato;
    palmMute = palmMute || note.palmMute;
    letRing = letRing || note.letRing;
    if (note.bendSteps > 0) {
      bend = true;
      bendSteps = note.bendSteps > bendSteps ? note.bendSteps : bendSteps;
    }
  }

  if (beatBar) bend = true; // whammy/tremolo-bar → a bend mark
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
    vibrato: vibrato,
    palmMute: palmMute,
    letRing: letRing,
    harmonicStyle: harmonicStyle,
  );
}

class _BeatEffectsGp34 {
  final bool harmonic; // GP3 stores natural/artificial harmonic on the beat
  final bool bar; // tremolo/whammy bar
  final bool vibrato; // GP3 stores note vibrato on the beat
  _BeatEffectsGp34(this.harmonic, this.bar, {this.vibrato = false});
}

_BeatEffectsGp34 _readBeatEffectsGp34(_Reader r, {required bool gp4}) {
  if (!gp4) {
    final f1 = r.u8();
    var bar = false;
    if (f1 & 0x20 != 0) {
      final slap = r.u8();
      r.i32(); // tremolo-bar dip value, or slap/tap/pop payload
      if (slap == 0) bar = true;
    }
    if (f1 & 0x40 != 0) r.skip(2); // beat stroke (down/up)
    final harmonic = f1 & 0x04 != 0 || f1 & 0x08 != 0; // natural/artificial
    final vibrato = f1 & 0x01 != 0 || f1 & 0x02 != 0; // note/wide vibrato
    return _BeatEffectsGp34(harmonic, bar, vibrato: vibrato);
  }
  final f1 = r.i8();
  final f2 = r.i8();
  var bar = false;
  final vibrato = f1 & 0x02 != 0; // wide vibrato (beat-level in GP4)
  if (f1 & 0x20 != 0) r.i8(); // slap effect
  if (f2 & 0x04 != 0) {
    _readBend(r); // tremolo bar (full bend envelope in GP4)
    bar = true;
  }
  if (f1 & 0x40 != 0) r.skip(2); // beat stroke
  if (f2 & 0x02 != 0) r.i8(); // pick stroke
  // GP4 harmonics are per-note; wide vibrato is beat-level.
  return _BeatEffectsGp34(false, bar, vibrato: vibrato);
}

void _readMixTableChangeGp34(_Reader r, {required bool gp4}) {
  r.i8(); // instrument
  final vals = <int>[]; // volume,balance,chorus,reverb,phaser,tremolo
  for (var i = 0; i < 6; i++) {
    vals.add(r.i8());
  }
  final tempo = r.i32();
  for (final v in vals) {
    if (v >= 0) r.i8(); // duration for each changed item
  }
  if (tempo >= 0) r.i8();
  if (gp4) r.i8(); // "apply to all tracks" flags
}

_NoteData? _readNoteGp34(_Reader r, int stringNumber, List<int> tuning,
    {required bool gp4}) {
  final flags = r.u8();
  var type = 1;
  if (flags & 0x20 != 0) type = r.u8(); // 1 normal, 2 tie, 3 dead
  if (flags & 0x01 != 0) {
    r.i8(); // duration
    r.i8(); // tuplet
  }
  if (flags & 0x10 != 0) r.i8(); // dynamics
  var fret = 0;
  if (flags & 0x20 != 0) fret = r.i8();
  if (flags & 0x80 != 0) {
    r.i8(); // left-hand fingering
    r.i8(); // right-hand fingering
  }
  var harmonic = false, hammer = false, slide = false;
  var vibrato = false, palmMute = false, letRing = false;
  var harmonicStyle = TabNoteStyle.harmonic;
  double bendSteps = 0;
  if (flags & 0x08 != 0) {
    final e = gp4 ? _readNoteEffectsGp4(r) : _readNoteEffectsGp3(r);
    harmonic = e.harmonic;
    hammer = e.hammer;
    slide = e.slide;
    bendSteps = e.bendSteps;
    vibrato = e.vibrato;
    palmMute = e.palmMute;
    letRing = e.letRing;
    harmonicStyle = e.harmonicStyle;
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
      bendSteps: bendSteps,
      vibrato: vibrato,
      palmMute: palmMute,
      letRing: letRing,
      harmonicStyle: harmonicStyle);
}

_NoteEffects _readNoteEffectsGp3(_Reader r) {
  final f = r.u8();
  final hammer = f & 0x02 != 0;
  final letRing = f & 0x08 != 0;
  double bendSteps = 0;
  if (f & 0x01 != 0) bendSteps = _readBend(r);
  if (f & 0x10 != 0) r.skip(4); // grace (fret, velocity, duration, transition)
  final slide = f & 0x04 != 0; // GP3 slide carries no extra bytes
  return _NoteEffects(false, hammer, slide, bendSteps, letRing: letRing);
}

_NoteEffects _readNoteEffectsGp4(_Reader r) {
  final f1 = r.i8();
  final f2 = r.i8();
  final hammer = f1 & 0x02 != 0;
  final letRing = f1 & 0x08 != 0;
  double bendSteps = 0;
  if (f1 & 0x01 != 0) bendSteps = _readBend(r);
  if (f1 & 0x10 != 0) r.skip(4); // grace
  if (f2 & 0x04 != 0) r.i8(); // tremolo picking
  final slide = f2 & 0x08 != 0;
  if (slide) r.i8(); // slide type
  var harmonic = false;
  var harmonicStyle = TabNoteStyle.harmonic;
  if (f2 & 0x10 != 0) {
    harmonic = true;
    // 1 natural, 3 tapped, 4 pinch, 5 semi, 15/17/22 artificial (fret offset).
    harmonicStyle = switch (r.i8()) {
      4 => TabNoteStyle.pinchHarmonic,
      15 || 17 || 22 => TabNoteStyle.artificialHarmonic,
      _ => TabNoteStyle.harmonic,
    };
  }
  if (f2 & 0x20 != 0) r.skip(2); // trill (fret + period)
  final palmMute = f2 & 0x02 != 0;
  final vibrato = f2 & 0x40 != 0;
  return _NoteEffects(harmonic, hammer, slide, bendSteps,
      vibrato: vibrato,
      palmMute: palmMute,
      letRing: letRing,
      harmonicStyle: harmonicStyle);
}

void _readChordGp34(_Reader r, {required bool gp4}) {
  final newFormat = r.u8() != 0;
  if (!newFormat) {
    // GP3 legacy chord: name + first fret + (if set) 6 fret positions.
    r.intByteSizeString();
    final firstFret = r.i32();
    if (firstFret != 0) {
      for (var i = 0; i < 6; i++) {
        r.i32();
      }
    }
    return;
  }
  r.u8(); // sharp
  r.skip(3);
  if (!gp4) {
    r.i32(); // root
    r.i32(); // type
    r.i32(); // extension
  } else {
    r.u8(); // root
    r.u8(); // type
    r.u8(); // extension
  }
  r.i32(); // bass
  r.i32(); // tonality
  r.u8(); // add
  r.byteSizeString(22); // name
  if (!gp4) {
    r.i32(); // fifth
    r.i32(); // ninth
    r.i32(); // eleventh
  } else {
    r.u8(); // fifth
    r.u8(); // ninth
    r.u8(); // eleventh
  }
  r.i32(); // first fret
  final fretCount = gp4 ? 7 : 6;
  for (var i = 0; i < fretCount; i++) {
    r.i32(); // frets
  }
  if (!gp4) {
    r.i32(); // barre count
    r.skip(2 * 4 * 3); // barre frets/starts/ends (2 ints each)
    r.skip(7); // omissions
    r.skip(1);
  } else {
    r.u8(); // barre count
    r.skip(5 * 3); // barre frets/starts/ends (5 bytes each)
    r.skip(7); // omissions
    r.skip(1);
    r.skip(7); // fingerings
    r.u8(); // show
  }
}

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
  var beatBend = false, beatVibrato = false;
  if (flags & 0x08 != 0) {
    final e = _readBeatEffects(r);
    beatBend = e.bar;
    beatVibrato = e.vibrato;
  }
  if (flags & 0x10 != 0) _readMixTableChange(r, v510); // mix table
  // Notes: one bit per string (string 1 = bit 6 … string 6 = bit 1).
  final stringFlags = r.u8();
  final pitches = <Pitch>[];
  var dead = false, harmonic = false, hammer = false, slide = false;
  var bend = false, vibrato = beatVibrato, palmMute = false, letRing = false;
  var harmonicStyle = TabNoteStyle.harmonic;
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
    if (note.harmonic) {
      harmonic = true;
      harmonicStyle = note.harmonicStyle;
    }
    hammer = hammer || note.hammer;
    slide = slide || note.slide;
    vibrato = vibrato || note.vibrato;
    palmMute = palmMute || note.palmMute;
    letRing = letRing || note.letRing;
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
    vibrato: vibrato,
    palmMute: palmMute,
    letRing: letRing,
    harmonicStyle: harmonicStyle,
  );
}

({bool bar, bool vibrato}) _readBeatEffects(_Reader r) {
  final f1 = r.i8();
  final f2 = r.i8();
  final vibrato = f1 & 0x02 != 0; // wide vibrato (beat-level in GP5)
  if (f1 & 0x20 != 0) r.i8(); // slap
  var bar = false;
  if (f2 & 0x04 != 0) {
    _readBend(r); // tremolo bar
    bar = true;
  }
  if (f1 & 0x40 != 0) r.skip(2); // beat stroke
  if (f2 & 0x02 != 0) r.i8(); // pick stroke
  return (bar: bar, vibrato: vibrato);
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
  final bool vibrato;
  final bool palmMute;
  final bool letRing;
  final TabNoteStyle harmonicStyle;
  _NoteData(this.pitch,
      {this.dead = false,
      this.harmonic = false,
      this.hammer = false,
      this.slide = false,
      this.bendSteps = 0,
      this.vibrato = false,
      this.palmMute = false,
      this.letRing = false,
      this.harmonicStyle = TabNoteStyle.harmonic});
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
  var vibrato = false, palmMute = false, letRing = false;
  var harmonicStyle = TabNoteStyle.harmonic;
  double bendSteps = 0;
  if (flags & 0x08 != 0) {
    final e = _readNoteEffects(r);
    harmonic = e.harmonic;
    hammer = e.hammer;
    slide = e.slide;
    bendSteps = e.bendSteps;
    vibrato = e.vibrato;
    palmMute = e.palmMute;
    letRing = e.letRing;
    harmonicStyle = e.harmonicStyle;
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
      bendSteps: bendSteps,
      vibrato: vibrato,
      palmMute: palmMute,
      letRing: letRing,
      harmonicStyle: harmonicStyle);
}

class _NoteEffects {
  final bool harmonic;
  final bool hammer;
  final bool slide;
  final double bendSteps;
  final bool vibrato;
  final bool palmMute;
  final bool letRing;

  /// Which harmonic variant, when [harmonic] — natural / artificial / pinch.
  final TabNoteStyle harmonicStyle;
  _NoteEffects(this.harmonic, this.hammer, this.slide, this.bendSteps,
      {this.vibrato = false,
      this.palmMute = false,
      this.letRing = false,
      this.harmonicStyle = TabNoteStyle.harmonic});
}

_NoteEffects _readNoteEffects(_Reader r) {
  final f1 = r.i8();
  final f2 = r.i8();
  final hammer = f1 & 0x02 != 0;
  final letRing = f1 & 0x08 != 0;
  double bendSteps = 0;
  if (f1 & 0x01 != 0) bendSteps = _readBend(r);
  if (f1 & 0x10 != 0) r.skip(5); // grace (GP5: 5 bytes)
  if (f2 & 0x04 != 0) r.i8(); // tremolo picking
  final slide = f2 & 0x08 != 0;
  if (slide) r.u8(); // slide type
  var harmonic = false;
  var harmonicStyle = TabNoteStyle.harmonic;
  if (f2 & 0x10 != 0) {
    harmonic = true;
    harmonicStyle = _readHarmonic(r);
  }
  if (f2 & 0x20 != 0) r.skip(2); // trill
  final palmMute = f2 & 0x02 != 0;
  final vibrato = f2 & 0x40 != 0;
  return _NoteEffects(harmonic, hammer, slide, bendSteps,
      vibrato: vibrato,
      palmMute: palmMute,
      letRing: letRing,
      harmonicStyle: harmonicStyle);
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

TabNoteStyle _readHarmonic(_Reader r) {
  final type = r.i8(); // 1 natural, 2 artificial, 3 tapped, 4 pinch, 5 semi
  if (type == 2) {
    r.u8();
    r.i8();
    r.u8();
  } else if (type == 3) {
    r.u8();
  }
  return switch (type) {
    2 => TabNoteStyle.artificialHarmonic,
    4 => TabNoteStyle.pinchHarmonic,
    _ => TabNoteStyle.harmonic,
  };
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
  final List<Vibrato> vibratos = [];
  final List<PalmMute> palmMutes = [];
  final List<LetRing> letRings = [];
  List<MusicElement> _current = [];
  int _id = 0;
  String? _pendingHammer;
  String? _pendingSlide;
  // Palm-mute / let-ring are per-note flags in the binary formats; consecutive
  // flagged notes coalesce into a single labelled bracket span.
  String? _palmStart, _palmLast;
  String? _letStart, _letLast;

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
    bool vibrato = false,
    bool palmMute = false,
    bool letRing = false,
    TabNoteStyle harmonicStyle = TabNoteStyle.harmonic,
  }) {
    if (status == 0 && pitches.isEmpty && !dead) return; // empty beat
    final id = 'e${_id++}';
    if (pitches.isEmpty && !dead) {
      // A rest breaks any open palm-mute / let-ring bracket.
      _flushSpans();
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
      marks.add(TabNoteMark(id, harmonicStyle));
    } else if (dead) {
      marks.add(TabNoteMark(id, TabNoteStyle.dead));
    }
    if (bend && bendSteps > 0) bends.add(Bend(id, steps: bendSteps));
    if (vibrato) vibratos.add(Vibrato(id));
    // Extend or (re)open the palm-mute span.
    if (palmMute) {
      _palmStart ??= id;
      _palmLast = id;
    } else if (_palmStart != null) {
      palmMutes.add(PalmMute(_palmStart!, _palmLast!));
      _palmStart = _palmLast = null;
    }
    if (letRing) {
      _letStart ??= id;
      _letLast = id;
    } else if (_letStart != null) {
      letRings.add(LetRing(_letStart!, _letLast!));
      _letStart = _letLast = null;
    }
    if (hammer) _pendingHammer = id;
    if (slide) _pendingSlide = id;
  }

  /// Closes any open palm-mute / let-ring bracket at a rest or end of score.
  void _flushSpans() {
    if (_palmStart != null) {
      palmMutes.add(PalmMute(_palmStart!, _palmLast!));
      _palmStart = _palmLast = null;
    }
    if (_letStart != null) {
      letRings.add(LetRing(_letStart!, _letLast!));
      _letStart = _letLast = null;
    }
  }

  Score build(List<TimeSignature> timeSigs) {
    _flushSpans();
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
      vibratos: vibratos,
      palmMutes: palmMutes,
      letRings: letRings,
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

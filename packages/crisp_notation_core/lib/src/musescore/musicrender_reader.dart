/// muspy / PDMX "MusicRender" JSON import → [Score] / [MultiPartScore].
///
/// [MusicRender](https://github.com/pnlong/PDMX) is MuseScore's own JSON export
/// (a subclass of the muspy `Music` object): the format the **PDMX** corpus
/// (`openmusic/pdmx`, ~254k public-domain scores) ships in. A file is a single
/// JSON object:
///
/// ```jsonc
/// {
///   "resolution": 480,                    // ticks per quarter note (MIDI PPQ)
///   "tempos": [{"time": 0, "qpm": 120}],  // qpm = quarter-notes/min (BPM)
///   "time_signatures": [{"time": 0, "numerator": 4, "denominator": 4}],
///   "tracks": [{
///     "name": "Piano", "program": 0, "is_drum": false,
///     "notes": [{"time": 0, "pitch": 70, "duration": 1920, "velocity": 64,
///                "is_grace": false}, ...]   // time/duration in ticks, pitch = MIDI
///   }, ...]
/// }
/// ```
///
/// MusicRender is a **performance** representation (tick onsets/durations,
/// no beaming/spelling/voices), while [Score] is a **notation** model, so the
/// import quantizes onto a sixteenth-note grid and packs into measures — exactly
/// what [scoreFromMidi] does. We reuse it: the reader transcodes the JSON to a
/// Standard MIDI File (faithful — see [musicRenderToMidi]) and feeds that to the
/// MIDI reader, one part per track. This mirrors the JAMS importer's
/// `jamsToMidi` → `scoreFromMidi` path and keeps every notation edge case
/// (ties across barlines, chord merging, rest packing) in one place.
///
/// [musicRenderToMidi] is also a standalone, note-exact JSON→MIDI transcoder
/// (no notation quantization) — the pure-Dart equivalent of `muspy`'s own
/// `write_midi`, used to build MIDI for the PDMX CC0 corpus.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../layout/multi_part.dart';
import '../midi/midi_reader.dart';
import '../model/element.dart';
import '../model/score.dart';
import '../theory/clef.dart';
import '../theory/tempo.dart';

// ─────────────────────────── public entry points ────────────────────────────

/// Parses a MusicRender / muspy [json] string into a [MultiPartScore] — one
/// part per JSON track that carries notes. Note-less tracks are skipped; a
/// single-track file yields a 1-part score.
///
/// Throws [FormatException] on non-JSON or a non-object root.
MultiPartScore multiPartScoreFromMusicRender(String json) {
  final doc = _decode(json);
  final res = _int(doc['resolution'], 480, min: 1);
  final meta = _metaEvents(doc);
  final tempo = _firstTempo(doc);
  final tracksJson = (doc['tracks'] as List?) ?? const [];

  final parts = <Score>[];
  for (final t in tracksJson) {
    if (t is! Map) continue;
    final smf = _smf(
      format: 0,
      division: res,
      tracks: [
        _encodeTrack([...meta, ..._noteEvents(t, 0)]),
      ],
    );
    try {
      final score = scoreFromMidi(smf);
      final hasNotes =
          score.measures.any((m) => m.elements.any((e) => e is NoteElement));
      if (hasNotes) parts.add(_withPartMetadata(score, t, tempo));
    } catch (_) {
      // A note-less / unparseable track — skip it (mirrors the MIDI importer).
    }
  }
  // No track had notes (or the file was single-track meta): fall back to the
  // merged whole-file parse so callers always get a valid score.
  if (parts.isEmpty) {
    final merged = scoreFromMidi(musicRenderToMidi(json));
    parts.add(merged);
  }
  return MultiPartScore(parts);
}

/// Parses a MusicRender / muspy [json] string into a single [Score] — the
/// [partIndex]-th part (default the first). Multi-track files keep every part
/// via [multiPartScoreFromMusicRender]; use that to preserve them all.
Score scoreFromMusicRender(String json, {int partIndex = 0}) {
  final parts = multiPartScoreFromMusicRender(json).parts;
  final i = partIndex < 0
      ? 0
      : partIndex >= parts.length
          ? parts.length - 1
          : partIndex;
  return parts[i];
}

/// Transcodes a MusicRender / muspy [json] string directly to a Standard MIDI
/// File (format 1, one MTrk per JSON track plus a leading tempo/time-signature
/// meta track). This is **note-exact** — no notation quantization — and is the
/// pure-Dart equivalent of muspy's `write_midi`: it preserves every note,
/// including same-pitch temporal overlaps that some writers drop.
///
/// Edge handling: `resolution` → PPQ (default 480); empty `tempos` → 120 qpm;
/// pitch/velocity clamped to 0..127; a 0 velocity is bumped to 1 (a note-on of
/// velocity 0 is a note-off); grace / zero-length notes clamped to ≥1 tick;
/// `is_drum` tracks → MIDI channel 10 (index 9), other tracks skip it.
Uint8List musicRenderToMidi(String json) {
  final doc = _decode(json);
  final res = _int(doc['resolution'], 480, min: 1);
  final tracksJson = (doc['tracks'] as List?) ?? const [];

  final chunks = <Uint8List>[_encodeTrack(_metaEvents(doc))];
  var ci = 0;
  for (final t in tracksJson) {
    if (t is! Map) continue;
    final isDrum = t['is_drum'] == true;
    int ch;
    if (isDrum) {
      ch = 9;
    } else {
      ch = ci < 9 ? ci : ci + 1; // skip channel 10 (index 9) for pitched tracks
      if (ch > 15) ch = 15; // >15 pitched tracks reuse the last channel
      ci++;
    }
    chunks.add(_encodeTrack(_noteEvents(t, ch)));
  }
  return _smf(format: 1, division: res, tracks: chunks);
}

// ─────────────────────────── decoding + coercion ────────────────────────────

Map<String, dynamic> _decode(String json) {
  Object? root;
  try {
    root = jsonDecode(json);
  } catch (_) {
    // muspy `save_json` is Python's json.dump, which emits bare NaN/Infinity by
    // default (non-standard JSON that Dart rightly rejects). Retry once with
    // those literals nulled out rather than failing the whole file.
    try {
      root = jsonDecode(_nullifyNonFinite(json));
    } catch (_) {
      root = null;
    }
  }
  if (root is! Map<String, dynamic>) {
    throw const FormatException(
      'Not a MusicRender/muspy JSON object (expected a top-level object).',
    );
  }
  return root;
}

/// Replaces bare `NaN`, `Infinity`, `-Infinity` tokens (Python json output)
/// with `null`, matching only whole tokens so real strings are untouched.
String _nullifyNonFinite(String s) => s.replaceAllMapped(
      RegExp(r'(?<![\w"])-?(?:NaN|Infinity)(?![\w"])'),
      (_) => 'null',
    );

int _int(Object? v, int fallback, {int? min}) {
  int out;
  if (v is int) {
    out = v;
  } else if (v is num) {
    out = v.round();
  } else if (v is String) {
    out = int.tryParse(v) ?? double.tryParse(v)?.round() ?? fallback;
  } else {
    out = fallback;
  }
  if (min != null && out < min) out = min;
  return out;
}

double _num(Object? v, double fallback) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

// ─────────────────────────── SMF event assembly ─────────────────────────────
//
// An event is (absoluteTick, order, bytes). `order` breaks ties at one tick:
// program change (-1) first, then note-offs (0) before note-ons (1) so a note
// ending where another of the same pitch begins doesn't cut the new one.

typedef _Event = (int tick, int order, List<int> data);

List<_Event> _metaEvents(Map<Object?, Object?> doc) {
  final events = <_Event>[];
  final tempos = doc['tempos'];
  final tempoList = (tempos is List && tempos.isNotEmpty)
      ? tempos
      : const [
          {'time': 0, 'qpm': 120}
        ];
  for (final t in tempoList) {
    if (t is! Map) continue;
    var qpm = _num(t['qpm'], 120);
    if (qpm <= 0) qpm = 120;
    var us = (60000000 / qpm).round();
    if (us < 1) us = 1;
    if (us > 0xFFFFFF) us = 0xFFFFFF;
    events.add((
      _int(t['time'], 0),
      0,
      [0xFF, 0x51, 0x03, (us >> 16) & 0xFF, (us >> 8) & 0xFF, us & 0xFF],
    ));
  }
  final timeSigs = doc['time_signatures'];
  if (timeSigs is List) {
    for (final ts in timeSigs) {
      if (ts is! Map) continue;
      var num = _int(ts['numerator'], 4);
      if (num < 1) num = 1;
      if (num > 255) num = 255;
      final den = _int(ts['denominator'], 4);
      var dd = den > 0 ? (math.log(den) / math.ln2).round() : 2;
      if (dd < 0) dd = 0;
      if (dd > 255) dd = 255;
      events.add((_int(ts['time'], 0), 0, [0xFF, 0x58, 0x04, num, dd, 24, 8]));
    }
  }
  return events;
}

List<_Event> _noteEvents(Map<Object?, Object?> track, int channel) {
  final events = <_Event>[];
  final prog = _int(track['program'], 0).clamp(0, 127);
  events.add((0, -1, [0xC0 | channel, prog]));
  final notes = track['notes'];
  if (notes is List) {
    for (final n in notes) {
      if (n is! Map) continue;
      final on = _int(n['time'], 0);
      final pitch = _int(n['pitch'], 0).clamp(0, 127);
      var vel = _int(n['velocity'], 64).clamp(0, 127);
      if (vel == 0) vel = 1;
      var dur = _int(n['duration'], 1);
      if (dur < 1) dur = 1;
      events.add((on, 1, [0x90 | channel, pitch, vel]));
      events.add((on + dur, 0, [0x80 | channel, pitch, 0]));
    }
  }
  return events;
}

/// Delta-encodes [events] into a complete `MTrk` chunk (header + body + end).
Uint8List _encodeTrack(List<_Event> events) {
  events.sort((a, b) {
    final c = a.$1.compareTo(b.$1);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final body = <int>[];
  var prev = 0;
  for (final e in events) {
    body.addAll(_vlq(e.$1 - prev));
    body.addAll(e.$3);
    prev = e.$1;
  }
  body.addAll(_vlq(0));
  body.addAll([0xFF, 0x2F, 0x00]); // end of track
  return _chunk('MTrk', body);
}

/// MIDI variable-length quantity.
List<int> _vlq(int n) {
  if (n < 0) n = 0;
  final out = [n & 0x7F];
  n >>= 7;
  while (n > 0) {
    out.add((n & 0x7F) | 0x80);
    n >>= 7;
  }
  return out.reversed.toList();
}

Uint8List _chunk(String tag, List<int> body) {
  final out = BytesBuilder();
  out.add(ascii.encode(tag));
  out.add(_u32(body.length));
  out.add(body);
  return out.toBytes();
}

Uint8List _smf({
  required int format,
  required int division,
  required List<Uint8List> tracks,
}) {
  final out = BytesBuilder();
  out.add(ascii.encode('MThd'));
  out.add(_u32(6));
  out.add(_u16(format));
  out.add(_u16(tracks.length));
  out.add(_u16(division));
  for (final t in tracks) {
    out.add(t);
  }
  return out.toBytes();
}

List<int> _u32(int v) =>
    [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
List<int> _u16(int v) => [(v >> 8) & 0xFF, v & 0xFF];

// ─────────────────────────── metadata re-attachment ─────────────────────────

Tempo? _firstTempo(Map<Object?, Object?> doc) {
  final tempos = doc['tempos'];
  if (tempos is List) {
    for (final t in tempos) {
      if (t is Map) {
        final qpm = _num(t['qpm'], 0);
        if (qpm > 0) return Tempo(qpm);
      }
    }
  }
  return null;
}

/// [scoreFromMidi] returns a bare treble/no-tempo/no-instrument [Score]; this
/// rebuilds it with the JSON track's instrument, program, drum flag and the
/// score tempo. (Score has no copyWith and the MIDI reader only sets clef /
/// time signature / measures, so the other fields are safe to leave default.)
Score _withPartMetadata(
  Score score,
  Map<Object?, Object?> track,
  Tempo? tempo,
) {
  final isDrum = track['is_drum'] == true;
  final rawName = track['name'];
  final name = rawName is String ? rawName.trim() : '';
  return Score(
    clef: isDrum ? Clef.percussion : score.clef,
    keySignature: score.keySignature,
    timeSignature: score.timeSignature,
    measures: score.measures,
    metadata: ScoreMetadata(
      instrument: name.isEmpty ? null : name,
      midiProgram: isDrum ? null : _int(track['program'], 0).clamp(0, 127),
      isPercussion: isDrum,
    ),
    tempo: tempo,
  );
}

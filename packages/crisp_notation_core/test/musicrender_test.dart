import 'dart:convert';
import 'dart:typed_data';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// A minimal MusicRender/muspy note.
Map<String, Object?> _note(int time, int pitch, int duration,
        {int velocity = 64, bool isGrace = false}) =>
    {
      'name': 'Note',
      'time': time,
      'pitch': pitch,
      'duration': duration,
      'velocity': velocity,
      'is_grace': isGrace,
    };

String _doc({
  int resolution = 480,
  List<Map<String, Object?>>? tempos,
  List<Map<String, Object?>>? timeSignatures,
  required List<Map<String, Object?>> tracks,
}) =>
    jsonEncode({
      'resolution': resolution,
      'tempos': tempos ??
          [
            {'time': 0, 'qpm': 120}
          ],
      'time_signatures': timeSignatures ??
          [
            {'time': 0, 'numerator': 4, 'denominator': 4}
          ],
      'tracks': tracks,
    });

// ─── stdlib SMF note-on reader (independent of our writer) ───
int _readVlq(Uint8List b, int i, void Function(int) setI) {
  var n = 0;
  while (true) {
    final x = b[i++];
    n = (n << 7) | (x & 0x7F);
    if (x & 0x80 == 0) break;
  }
  setI(i);
  return n;
}

/// Every (pitch, absoluteTick) note-on across all tracks of an SMF.
List<(int, int)> _noteOns(Uint8List b) {
  final out = <(int, int)>[];
  final ntrks = (b[10] << 8) | b[11];
  var i = 14;
  for (var t = 0; t < ntrks; t++) {
    i += 4; // 'MTrk'
    final len = (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
    i += 4;
    final end = i + len;
    var tick = 0;
    int? status;
    while (i < end) {
      var idx = i;
      final dt = _readVlq(b, i, (v) => idx = v);
      i = idx;
      tick += dt;
      var s = b[i];
      if (s & 0x80 != 0) {
        i++;
        status = s;
      } else {
        s = status!;
      }
      final hi = s & 0xF0;
      if (s == 0xFF) {
        i++; // meta type
        var mi = i;
        final ml = _readVlq(b, i, (v) => mi = v);
        i = mi + ml;
      } else if (s == 0xF0 || s == 0xF7) {
        var si = i;
        final sl = _readVlq(b, i, (v) => si = v);
        i = si + sl;
      } else if (hi == 0xC0 || hi == 0xD0) {
        i++;
      } else {
        final p = b[i];
        final v = b[i + 1];
        i += 2;
        if (hi == 0x90 && v > 0) out.add((p, tick));
      }
    }
    i = end;
  }
  return out;
}

void main() {
  group('musicRenderToMidi (note-exact transcode)', () {
    test('well-formed SMF header, format 1, meta + N note tracks', () {
      final smf = musicRenderToMidi(_doc(tracks: [
        {
          'program': 0,
          'is_drum': false,
          'notes': [_note(0, 60, 480)]
        },
      ]));
      expect(ascii.decode(smf.sublist(0, 4)), 'MThd');
      expect((smf[8] << 8) | smf[9], 1); // format 1
      expect((smf[10] << 8) | smf[11], 2); // meta track + 1 note track
      expect((smf[12] << 8) | smf[13], 480); // division = resolution
    });

    test('preserves every note-on (pitch, onset) — the roundtrip', () {
      final notes = [
        _note(0, 60, 480),
        _note(480, 64, 480),
        _note(480, 67, 480), // chord with the above
        _note(960, 72, 1920),
      ];
      final smf = musicRenderToMidi(_doc(tracks: [
        {'program': 0, 'notes': notes},
      ]));
      final got = _noteOns(smf)..sort(_cmp);
      final want = [(60, 0), (64, 480), (67, 480), (72, 960)]..sort(_cmp);
      expect(got, want);
    });

    test('same-pitch overlapping notes are both kept (muspy drops these)', () {
      final smf = musicRenderToMidi(_doc(tracks: [
        {
          'notes': [_note(0, 60, 1000), _note(240, 60, 240)]
        },
      ]));
      // Two note-ons of pitch 60, at ticks 0 and 240 — neither collapsed.
      final ons = _noteOns(smf).where((e) => e.$1 == 60).toList()..sort(_cmp);
      expect(ons, [(60, 0), (60, 240)]);
    });

    test('is_drum → channel 10 (index 9); pitched tracks skip it', () {
      final smf = musicRenderToMidi(_doc(tracks: [
        {
          'is_drum': false,
          'notes': [_note(0, 60, 240)]
        },
        {
          'is_drum': true,
          'notes': [_note(0, 36, 240)]
        },
      ]));
      // find note-on status bytes present
      // pitched track uses channel 0 (0x90), drum uses channel 9 (0x99)
      expect(smf.contains(0x90), isTrue);
      expect(smf.contains(0x99), isTrue);
    });

    test('clamps out-of-range pitch/velocity and zero-length notes', () {
      final smf = musicRenderToMidi(_doc(tracks: [
        {
          'notes': [
            _note(0, 200, 0, velocity: 0), // pitch>127, dur 0, vel 0
          ]
        },
      ]));
      final ons = _noteOns(smf);
      expect(ons.length, 1);
      expect(ons.first.$1, 127); // pitch clamped to 127
    });

    test('empty tempos default to 120 qpm (500000 µs) meta event', () {
      final smf = musicRenderToMidi(jsonEncode({
        'resolution': 480,
        'tempos': <Object?>[],
        'tracks': [
          {
            'notes': [_note(0, 60, 480)]
          }
        ],
      }));
      // FF 51 03 07 A1 20  == 500000 µs/quarter == 120 bpm
      expect(_containsSeq(smf, [0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]), isTrue);
    });
  });

  group('multiPartScoreFromMusicRender (→ notation model)', () {
    test('one part per note-bearing track, note-less tracks dropped', () {
      final mp = multiPartScoreFromMusicRender(_doc(tracks: [
        {
          'name': 'Lead',
          'program': 40,
          'notes': [_note(0, 60, 480), _note(480, 62, 480)]
        },
        {'name': 'Empty', 'notes': const <Object?>[]},
        {
          'name': 'Drums',
          'is_drum': true,
          'notes': [_note(0, 36, 240)]
        },
      ]));
      expect(mp.parts.length, 2); // empty track skipped
    });

    test('re-attaches instrument, program and drum metadata + tempo', () {
      final mp = multiPartScoreFromMusicRender(_doc(
        tempos: [
          {'time': 0, 'qpm': 90}
        ],
        tracks: [
          {
            'name': 'Violin',
            'program': 40,
            'is_drum': false,
            'notes': [_note(0, 67, 480)]
          },
          {
            'name': 'Kit',
            'is_drum': true,
            'notes': [_note(0, 38, 240)]
          },
        ],
      ));
      final violin = mp.parts[0];
      expect(violin.metadata.instrument, 'Violin');
      expect(violin.metadata.midiProgram, 40);
      expect(violin.metadata.isPercussion, isFalse);
      expect(violin.tempo?.quarterBpm, closeTo(90, 0.01));

      final drums = mp.parts[1];
      expect(drums.metadata.isPercussion, isTrue);
      expect(drums.clef, Clef.percussion);
    });

    test('imported score plays back via scoreToMidi (notes have ids)', () {
      final mp = multiPartScoreFromMusicRender(_doc(tracks: [
        {
          'notes': [_note(0, 60, 480), _note(480, 64, 480), _note(960, 67, 480)]
        },
      ]));
      final smf = scoreToMidi(mp.parts.first);
      // scoreToMidi drops notes with a null id; a non-empty note-on stream
      // proves the importer assigned ids (via the MIDI reader).
      expect(_noteOns(smf).isNotEmpty, isTrue);
    });

    test('scoreFromMusicRender returns the requested part', () {
      final json = _doc(tracks: [
        {
          'name': 'A',
          'notes': [_note(0, 60, 480)]
        },
        {
          'name': 'B',
          'notes': [_note(0, 72, 480)]
        },
      ]);
      expect(scoreFromMusicRender(json, partIndex: 0).metadata.instrument, 'A');
      expect(scoreFromMusicRender(json, partIndex: 1).metadata.instrument, 'B');
    });
  });

  group('robustness', () {
    test('rejects non-JSON', () {
      expect(() => multiPartScoreFromMusicRender('not json'),
          throwsFormatException);
    });

    test('tolerates Python NaN/Infinity literals', () {
      final json = '{"resolution":480,"tempos":[{"time":0,"qpm":NaN}],'
          '"time_signatures":[],"tracks":[{"notes":['
          '{"time":0,"pitch":60,"duration":480,"velocity":64}]}]}';
      // qpm NaN → nulled → defaults to 120; must not throw.
      final smf = musicRenderToMidi(json);
      expect(_noteOns(smf), [(60, 0)]);
    });
  });
}

int _cmp((int, int) a, (int, int) b) {
  final c = a.$1.compareTo(b.$1);
  return c != 0 ? c : a.$2.compareTo(b.$2);
}

bool _containsSeq(Uint8List hay, List<int> needle) {
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return true;
  }
  return false;
}

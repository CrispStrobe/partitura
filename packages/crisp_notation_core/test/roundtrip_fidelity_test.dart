import 'dart:typed_data';
import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// Round-trip fidelity harness — answers "to which degree do we actually parse
/// (and write) correctly?" by pushing a score **out** through each writer and
/// **back** through the matching reader, then comparing a semantic fingerprint.
///
/// A round-trip proves the importer and exporter of a format are *mutually
/// consistent*; it can't by itself prove they are *correct* (a bug symmetric in
/// reader + writer survives a round-trip). The external-oracle differential
/// (`tool/oracle_diff.dart`) covers that gap. Together they bracket fidelity.
///
/// Two fingerprints, matched to what each format can carry:
///  * [midiFingerprint] — MIDI note numbers + rhythm. The strong invariant that
///    *every* round-trippable format must preserve (pitch height + duration),
///    even lossy ones (MIDI drops enharmonic spelling, clef, key spelling).
///  * [spelledFingerprint] — enharmonic spelling (C♯ vs D♭), clef, key, meter.
///    Only the lossless notation formats are held to this.
void main() {
  // ----- fingerprints -------------------------------------------------------

  /// Pitch-height + rhythm: `N:<midi,…>@<dur>` per note, `R@<dur>` per rest,
  /// in reading order. Survives even a MIDI round-trip.
  String midiFingerprint(Score s) {
    final parts = <String>[];
    for (final m in s.measures) {
      for (final e in m.elements) {
        final dur = e.duration.toFraction().toString();
        switch (e) {
          case NoteElement(:final pitches):
            final midis = pitches.map((p) => p.midiNumber).toList()..sort();
            parts.add('N:${midis.join(',')}@$dur');
          case RestElement():
            parts.add('R@$dur');
        }
      }
    }
    return parts.join(' ');
  }

  /// Sounding content sampled over time — the invariant a *performance* format
  /// (MIDI) must preserve. Immune to re-notation (a dotted quarter vs a tied
  /// quarter+eighth sound identically), to tie-splitting, and to a dropped
  /// trailing rest. Walks the single voice cumulatively (the probes are
  /// monophonic-in-time) and samples the sorted sounding MIDI set every 1/64.
  String sampleFingerprint(Score s) {
    final spans = <(Fraction, Fraction, int)>[]; // (start, end, midi)
    var t = Fraction(0, 1);
    for (final m in s.measures) {
      for (final e in m.elements) {
        final d = e.duration.toFraction();
        if (e is NoteElement) {
          for (final p in e.pitches) {
            spans.add((t, t + d, p.midiNumber));
          }
        }
        t = t + d;
      }
    }
    final end = t;
    final step = Fraction(1, 64);
    final samples = <String>[];
    for (var x = Fraction(0, 1); x < end; x = x + step) {
      final sounding = <int>[
        for (final (a, b, midi) in spans)
          if (a <= x && x < b) midi,
      ]..sort();
      samples.add(sounding.join(','));
    }
    // Trailing silence (e.g. a final rest, which MIDI has no way to encode) is
    // not sounding content — trim it so it doesn't count against fidelity.
    while (samples.isNotEmpty && samples.last.isEmpty) {
      samples.removeLast();
    }
    return samples.join('|');
  }

  /// Enharmonic spelling + rhythm + clef/key/meter — the full notated content.
  String spelledFingerprint(Score s) {
    final parts = <String>[
      'clef=${s.clef.name}',
      'key=${s.keySignature.fifths}',
      'time=${s.timeSignature ?? '-'}',
    ];
    for (final m in s.measures) {
      for (final e in m.elements) {
        final dur = e.duration.toFraction().toString();
        switch (e) {
          case NoteElement(:final pitches):
            final names = pitches.map((p) => p.toString()).toList()..sort();
            parts.add('N:${names.join(',')}@$dur');
          case RestElement():
            parts.add('R@$dur');
        }
      }
    }
    return parts.join(' ');
  }

  // ----- probe scores (feature coverage) ------------------------------------

  final probes = <String, Score>{
    'stepwise quarters': Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'c4:q d4 e4 f4 | g4:q a4 b4 c5',
    ),
    'chords + rests': Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'c4+e4+g4:q r:q e4+g4+c5:h | g3+d4:h r:h',
    ),
    'dotted + ties': Score.simple(
      timeSignature: TimeSignature.threeFour,
      notes: 'c4:q. d4:e e4:h | f4:h. ',
    ),
    'accidentals (sharps/flats)': Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'c#4:q db4 f#4 gb4 | a#4:q bb4 eb5 d#5',
    ),
    'wide range': Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes: 'c2:q c3 c4 c5 | c6:q g5 e4 c3',
    ),
  };

  // ----- round-trip drivers -------------------------------------------------

  /// (name, out-writer, back-reader, lossless?) — lossless formats must also
  /// preserve enharmonic spelling; the rest only pitch height + rhythm.
  final formats = <({
    String name,
    String Function(Score) write,
    Score Function(String) read,
    bool spelled,
  })>[
    (
      name: 'MusicXML',
      write: scoreToMusicXml,
      read: scoreFromMusicXml,
      spelled: true
    ),
    (name: 'MEI', write: scoreToMei, read: scoreFromMei, spelled: true),
    (name: 'kern', write: scoreToKern, read: scoreFromKern, spelled: true),
    (name: 'ABC', write: scoreToAbc, read: scoreFromAbc, spelled: true),
    (name: 'MuseScore', write: scoreToMscx, read: scoreFromMscx, spelled: true),
    // MIDI is inherently lossy (no enharmonic spelling / clef): height + rhythm.
    (
      name: 'MIDI',
      write: (s) => String.fromCharCodes(scoreToMidi(s)),
      read: (s) => scoreFromMidi(Uint8List.fromList(s.codeUnits)),
      spelled: false,
    ),
  ];

  for (final fmt in formats) {
    group('round-trip through ${fmt.name}', () {
      for (final entry in probes.entries) {
        test(entry.key, () {
          final original = entry.value;
          final Score back;
          try {
            back = fmt.read(fmt.write(original));
          } catch (e, st) {
            fail('${fmt.name} round-trip threw on "${entry.key}": $e\n$st');
          }
          if (fmt.spelled) {
            // Lossless notation formats: the full notated content must survive
            // — pitch height, rhythm, enharmonic spelling, clef, key, meter.
            expect(spelledFingerprint(back), spelledFingerprint(original),
                reason: '${fmt.name} lost notated content');
            expect(midiFingerprint(back), midiFingerprint(original),
                reason: '${fmt.name} lost pitch height / rhythm');
          } else {
            // Performance format (MIDI): the sounding content must survive, but
            // notated rhythm / spelling / trailing rests legitimately may not.
            expect(sampleFingerprint(back), sampleFingerprint(original),
                reason: '${fmt.name} lost sounding content');
          }
        });
      }
    });
  }
}

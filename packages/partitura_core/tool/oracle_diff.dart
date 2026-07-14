// Differential test against an independent parser (music21) — the "oracle".
//
//   dart run tool/oracle_diff.dart <file> [<file> …]
//
// A round-trip only proves partitura's reader and writer agree with *each
// other*; it can't catch a bug that is symmetric across both. This tool breaks
// that symmetry: it parses each score with partitura AND with music21
// (`tool/oracle_dump.py`), reduces each to the multiset of `(midi, quarterLength)`
// notes across all parts, and reports how much they agree. A divergence is far
// more likely a partitura import bug than a music21 one — and names the exact
// (pitch, duration) that differs, so it can be chased down.
//
// music21 runs via the interpreter in $ORACLE_PYTHON (default: the miniconda
// python that has it installed). Formats music21 also parses: MusicXML/.mxl,
// **kern, ABC, MEI, MIDI.
import 'dart:convert';
import 'dart:io';

import 'package:partitura_core/partitura_core.dart';

const _defaultPython = '/Users/christianstrobele/miniconda3/bin/python3';

/// partitura's note multiset for a file: `(midi, quarterLength)` across every
/// part/staff. Uses the *multi-part* importer so it lines up with music21's
/// all-parts flatten (the single-`Score` path would read only the first part).
Map<String, int>? _partituraNotes(String path) {
  final file = File(path);
  final lower = path.toLowerCase();
  List<Score> staves;
  try {
    if (lower.endsWith('.xml') || lower.endsWith('.musicxml')) {
      staves = staffSystemFromMusicXml(file.readAsStringSync()).staves;
    } else if (lower.endsWith('.mxl')) {
      staves =
          staffSystemFromMusicXml(readMusicXmlFromMxl(file.readAsBytesSync()))
              .staves;
    } else if (lower.endsWith('.mei')) {
      staves = staffSystemFromMei(file.readAsStringSync()).staves;
    } else if (lower.endsWith('.krn') || lower.endsWith('.kern')) {
      staves = staffSystemFromKern(file.readAsStringSync()).staves;
    } else if (lower.endsWith('.abc')) {
      staves = staffSystemFromAbc(file.readAsStringSync()).staves;
    } else if (lower.endsWith('.mid') || lower.endsWith('.midi')) {
      staves = [scoreFromMidi(file.readAsBytesSync())];
    } else {
      return null;
    }
  } catch (_) {
    return null;
  }
  final bag = <String, int>{};
  void addNote(NoteElement e, double ql) {
    for (final p in e.pitches) {
      final key = '${p.midiNumber}@${ql.toStringAsFixed(6)}';
      bag[key] = (bag[key] ?? 0) + 1;
    }
  }

  for (final s in staves) {
    for (final m in s.measures) {
      // Every voice's tuplet-scaled duration (effectiveDurationAt is voice-aware
      // now) — a triplet eighth is 1/3 quarter, matching music21's quarterLength.
      // The oracle compares against music21's all-voices flatten.
      for (var v = 0; v < 4; v++) {
        final list = m.voiceAt(v);
        for (var i = 0; i < list.length; i++) {
          final e = list[i];
          if (e is NoteElement) {
            addNote(e, m.effectiveDurationAt(i, voice: v).toDouble() * 4);
          }
        }
      }
    }
  }
  return bag;
}

/// music21's note multiset via the python dumper, or null if it couldn't parse.
Map<String, int>? _oracleNotes(String python, String path) {
  final dumper = '${File(Platform.script.toFilePath()).parent.path}'
      '/oracle_dump.py';
  final r = Process.runSync(python, [dumper, path]);
  if (r.exitCode != 0) return null;
  final Map<String, dynamic> parsed;
  try {
    parsed = jsonDecode(r.stdout as String) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final bag = <String, int>{};
  for (final entry in parsed['notes'] as List) {
    final midi = (entry[0] as num).toInt();
    final ql = (entry[1] as num).toDouble();
    final key = '$midi@${ql.toStringAsFixed(6)}';
    bag[key] = (bag[key] ?? 0) + 1;
  }
  return bag;
}

/// Notes present in [a] but missing (or short) in [b], as a flat multiset count.
int _missing(Map<String, int> a, Map<String, int> b) {
  var n = 0;
  for (final e in a.entries) {
    final have = b[e.key] ?? 0;
    if (have < e.value) n += e.value - have;
  }
  return n;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/oracle_diff.dart <file> …');
    exit(64);
  }
  final python = Platform.environment['ORACLE_PYTHON'] ?? _defaultPython;

  var compared = 0, agreed = 0, skipped = 0;
  stdout.writeln('\nOracle differential vs music21\n');
  for (final path in args) {
    final mine = _partituraNotes(path);
    final theirs = _oracleNotes(python, path);
    final name = path.split('/').last;
    if (mine == null || theirs == null) {
      skipped++;
      stdout.writeln('  SKIP  $name '
          '(${mine == null ? 'partitura' : 'music21'} could not parse)');
      continue;
    }
    compared++;
    final total = theirs.values.fold<int>(0, (a, b) => a + b);
    final onlyOracle = _missing(theirs, mine); // notes music21 saw, we didn't
    final onlyMine = _missing(mine, theirs); // notes we invented / mis-sized
    final agree = total == 0 ? 1.0 : (total - onlyOracle) / total;
    if (onlyOracle == 0 && onlyMine == 0) {
      agreed++;
      stdout.writeln('  OK    $name  ($total notes)');
    } else {
      stdout.writeln('  DIFF  $name  '
          '${(100 * agree).toStringAsFixed(1)}% agree — '
          'music21-only: $onlyOracle, partitura-only: $onlyMine  (of $total)');
    }
  }
  stdout.writeln('\n$agreed/$compared exact agreement, $skipped skipped');
}

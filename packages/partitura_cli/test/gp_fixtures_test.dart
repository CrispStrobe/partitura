import 'dart:io';

import 'package:partitura_cli/src/gp_container.dart';
import 'package:partitura_core/partitura_core.dart';
import 'package:test/test.dart';

/// Regression tests against real Guitar Pro binaries (vendored from alphaTab,
/// MPL-2.0 — see test/data/gp/README.md). These lock the whole read path for
/// every container format: GP3/GP4/GP5 binary, GP6 `.gpx` (BCFZ/BCFS),
/// GP7/8 `.gp`.
void main() {
  const dir = 'test/data/gp';

  int noteCount(Score s) {
    var notes = 0;
    for (final m in s.measures) {
      for (final e in m.elements) {
        if (e is NoteElement) notes++;
      }
    }
    return notes;
  }

  int markCount(Score s, TabNoteStyle style) =>
      s.tabNoteMarks.where((m) => m.style == style).length;

  Score gp3(String name) =>
      gp3ToScore(File('$dir/$name').readAsBytesSync());
  Score gp4(String name) =>
      gp4ToScore(File('$dir/$name').readAsBytesSync());
  Score gp5(String name) =>
      gp5ToScore(File('$dir/$name').readAsBytesSync());
  Score gpx(String name) =>
      scoreFromGpif(readGpifFromGpx(File('$dir/$name').readAsBytesSync()));
  Score gp(String name) =>
      scoreFromGpif(readGpifFromGp(File('$dir/$name').readAsBytesSync()));

  group('GP3 (binary)', () {
    test('notes: 28 notes and 7 rests in one bar', () {
      final s = gp3('notes.gp3');
      expect(s.measures, hasLength(1));
      expect(noteCount(s), 28);
    });

    test('bends: three notes each carry a bend', () {
      final s = gp3('bends.gp3');
      expect(noteCount(s), 3);
      expect(s.bends, hasLength(3));
    });

    test('slides: glissandos', () {
      final s = gp3('slides.gp3');
      expect(noteCount(s), 8);
      expect(s.glissandos, hasLength(3));
    });

    test('hammer: six hammer-on/pull-off slurs', () {
      final s = gp3('hammer.gp3');
      expect(noteCount(s), 9);
      expect(s.slurs, hasLength(6));
    });

    test('harmonics: five harmonic marks (beat-level in GP3)', () {
      final s = gp3('harmonics.gp3');
      expect(noteCount(s), 5);
      expect(markCount(s, TabNoteStyle.harmonic), 5);
    });

    test('dead: four dead notes', () {
      final s = gp3('dead.gp3');
      expect(markCount(s, TabNoteStyle.dead), 4);
    });
  });

  group('GP4 (binary)', () {
    test('notes: 28 notes and 7 rests in one bar', () {
      final s = gp4('notes.gp4');
      expect(s.measures, hasLength(1));
      expect(noteCount(s), 28);
    });

    test('bends: three notes each carry a bend', () {
      final s = gp4('bends.gp4');
      expect(noteCount(s), 3);
      expect(s.bends, hasLength(3));
    });

    test('slides: glissandos', () {
      final s = gp4('slides.gp4');
      expect(noteCount(s), 8);
      expect(s.glissandos, hasLength(5));
    });

    test('hammer: six hammer-on/pull-off slurs', () {
      final s = gp4('hammer.gp4');
      expect(noteCount(s), 9);
      expect(s.slurs, hasLength(6));
    });

    test('harmonics: five harmonic marks (per-note in GP4)', () {
      final s = gp4('harmonics.gp4');
      expect(noteCount(s), 5);
      expect(markCount(s, TabNoteStyle.harmonic), 5);
    });

    test('dead: four dead notes', () {
      final s = gp4('dead.gp4');
      expect(markCount(s, TabNoteStyle.dead), 4);
    });
  });

  group('GP5 (binary)', () {
    test('chords: two measures, eight notes', () {
      final s = gp5('chords.gp5');
      expect(s.measures, hasLength(2));
      expect(noteCount(s), 8);
    });

    test('bends: three notes each carry a bend', () {
      final s = gp5('bends.gp5');
      expect(s.measures, hasLength(2));
      expect(noteCount(s), 3);
      expect(s.bends, hasLength(3));
    });
  });

  group('GP6 (.gpx)', () {
    test('chords: five measures, eight notes', () {
      final s = gpx('chords.gpx');
      expect(s.measures, hasLength(5));
      expect(noteCount(s), 8);
    });

    test('slides: five glissandos', () {
      final s = gpx('slides.gpx');
      expect(s.measures, hasLength(2));
      expect(noteCount(s), 8);
      expect(s.glissandos, hasLength(5));
    });
  });

  group('GP7/8 (.gp)', () {
    test('chords: five measures, eight notes', () {
      final s = gp('chords.gp');
      expect(s.measures, hasLength(5));
      expect(noteCount(s), 8);
    });

    test('bends: three notes each carry a bend', () {
      final s = gp('bends.gp');
      expect(s.measures, hasLength(2));
      expect(noteCount(s), 3);
      expect(s.bends, hasLength(3));
    });
  });
}

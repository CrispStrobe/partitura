// Property test for musical MARKINGS (not just note content). Complements
// roundtrip_features_test.dart, which pins ONE hand-authored example per
// marking: this fuzzes random COMBINATIONS of markings — a note that carries a
// grace group AND a tremolo AND a dynamic AND lyrics, several dynamics in one
// measure, repeats stacked with voltas, etc. — over many seeded scores, and
// asserts every marking survives a write→read cycle.
//
// Runs only through the three codecs that carry every marking (MusicXML, MEI,
// MuseScore); kern/ABC are excluded because tremolo is a genuine format gap
// there (see roundtrip_features_test.dart's matrix). Seeds are fixed so any
// failure reproduces exactly.

import 'dart:math';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

const _arts = Articulation.values;
const _orns = [Ornament.trill, Ornament.mordent, Ornament.turn];
const _levels = [
  DynamicLevel.pp,
  DynamicLevel.p,
  DynamicLevel.mf,
  DynamicLevel.f,
  DynamicLevel.ff,
];
const _navs = NavigationMark.values;

Pitch _pitch(Random rng) =>
    Pitch(Step.values[rng.nextInt(7)], octave: 3 + rng.nextInt(3));

/// A random score of 4/4 bars filled with quarter notes, each note (and some
/// measures) decorated with a random assortment of markings. Every note gets an
/// id so id-keyed markings (dynamics, lyrics, slurs) can reference it.
Score _generate(int seed) {
  final rng = Random(seed);
  var idc = 0;
  String nextId() => 'n${idc++}';

  final measures = <Measure>[];
  final dynamics = <DynamicMarking>[];
  final lyrics = <Lyric>[];
  final noteIds = <String>[];

  final nBars = 2 + rng.nextInt(4);
  for (var b = 0; b < nBars; b++) {
    final els = <MusicElement>[];
    for (var i = 0; i < 4; i++) {
      final id = nextId();
      noteIds.add(id);
      els.add(NoteElement(
        pitches: [_pitch(rng)],
        duration: const NoteDuration(DurationBase.quarter),
        id: id,
        articulations:
            rng.nextInt(3) == 0 ? {_arts[rng.nextInt(_arts.length)]} : const {},
        ornament: rng.nextInt(4) == 0 ? _orns[rng.nextInt(_orns.length)] : null,
        graceNotes: rng.nextInt(4) == 0 ? [_pitch(rng)] : const [],
        graceStyle:
            rng.nextBool() ? GraceStyle.acciaccatura : GraceStyle.appoggiatura,
        tremolo: rng.nextInt(5) == 0 ? 1 + rng.nextInt(3) : null,
      ));
      if (rng.nextInt(3) == 0) {
        dynamics.add(DynamicMarking(id, _levels[rng.nextInt(_levels.length)]));
      }
      if (rng.nextInt(3) == 0) {
        lyrics.add(Lyric(id, 'sy$idc',
            verse: 1 + rng.nextInt(2), hyphenToNext: rng.nextBool()));
      }
    }
    measures.add(Measure(
      els,
      startRepeat: rng.nextInt(4) == 0,
      endRepeat: rng.nextInt(4) == 0,
      volta: rng.nextInt(5) == 0 ? 1 + rng.nextInt(2) : null,
      navigation: rng.nextInt(6) == 0 ? _navs[rng.nextInt(_navs.length)] : null,
    ));
  }

  // A few non-overlapping slurs between random note pairs (ascending ids).
  final slurs = <Slur>[];
  for (var k = 0; k + 1 < noteIds.length; k += 2 + rng.nextInt(3)) {
    if (rng.nextInt(3) == 0) slurs.add(Slur(noteIds[k], noteIds[k + 1]));
  }

  return Score(
    clef: Clef.treble,
    timeSignature: TimeSignature.fourFour,
    measures: measures,
    dynamics: dynamics,
    lyrics: lyrics,
    slurs: slurs,
  );
}

// --- marking tallies, order-independent -------------------------------------

List<NoteElement> _notes(Score s) =>
    s.measures.expand((m) => m.elements.whereType<NoteElement>()).toList();

int _artCount(Score s) =>
    _notes(s).fold(0, (n, e) => n + e.articulations.length);
int _ornCount(Score s) => _notes(s).where((e) => e.ornament != null).length;
int _graceCount(Score s) =>
    _notes(s).fold(0, (n, e) => n + e.graceNotes.length);
int _tremCount(Score s) => _notes(s).where((e) => e.tremolo != null).length;
int _repeats(Score s) =>
    s.measures.where((m) => m.startRepeat).length * 2 +
    s.measures.where((m) => m.endRepeat).length;
int _voltas(Score s) => s.measures.where((m) => m.volta != null).length;
int _navs2(Score s) => s.measures.where((m) => m.navigation != null).length;

void main() {
  const seeds = 120;
  final codecs = <String, Score Function(Score)>{
    'MusicXML': (s) => scoreFromMusicXml(scoreToMusicXml(s)),
    'MEI': (s) => scoreFromMei(scoreToMei(s)),
    'MuseScore': (s) => scoreFromMscx(scoreToMscx(s)),
  };

  // Guard against a vacuous pass: the corpus must actually exercise every
  // marking in quantity, or the equality checks above prove nothing.
  test('the generated corpus exercises every marking', () {
    var art = 0, orn = 0, grace = 0, trem = 0, dyn = 0, lyr = 0, slur = 0;
    var rep = 0, volta = 0, nav = 0;
    for (var seed = 1; seed <= seeds; seed++) {
      final s = _generate(seed);
      art += _artCount(s);
      orn += _ornCount(s);
      grace += _graceCount(s);
      trem += _tremCount(s);
      dyn += s.dynamics.length;
      lyr += s.lyrics.length;
      slur += s.slurs.length;
      rep += _repeats(s);
      volta += _voltas(s);
      nav += _navs2(s);
    }
    for (final (label, n) in [
      ('articulation', art),
      ('ornament', orn),
      ('grace', grace),
      ('tremolo', trem),
      ('dynamic', dyn),
      ('lyric', lyr),
      ('slur', slur),
      ('repeat', rep),
      ('volta', volta),
      ('navigation', nav),
    ]) {
      expect(n, greaterThan(20), reason: 'corpus is thin on $label ($n)');
    }
  });

  codecs.forEach((name, roundTrip) {
    test('$name preserves every marking over $seeds generated scores', () {
      for (var seed = 1; seed <= seeds; seed++) {
        final a = _generate(seed);
        Score b;
        try {
          b = roundTrip(a);
        } catch (e) {
          fail('$name seed $seed: round-trip threw: $e');
        }
        String why(String what) => '$name seed $seed: $what count changed';
        expect(_artCount(b), _artCount(a), reason: why('articulation'));
        expect(_ornCount(b), _ornCount(a), reason: why('ornament'));
        expect(_graceCount(b), _graceCount(a), reason: why('grace'));
        expect(_tremCount(b), _tremCount(a), reason: why('tremolo'));
        expect(b.dynamics.length, a.dynamics.length, reason: why('dynamic'));
        expect(b.lyrics.length, a.lyrics.length, reason: why('lyric'));
        expect(b.slurs.length, a.slurs.length, reason: why('slur'));
        expect(_repeats(b), _repeats(a), reason: why('repeat'));
        expect(_voltas(b), _voltas(a), reason: why('volta'));
        expect(_navs2(b), _navs2(a), reason: why('navigation'));
      }
    });
  });
}

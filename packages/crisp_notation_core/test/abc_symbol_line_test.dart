import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:test/test.dart';

/// ABC `s:` symbol lines: decorations / chord symbols aligned to the notes of
/// the preceding music line (like `w:` lyric alignment — `*` skips, `|` syncs).
void main() {
  Score parse(String body) => scoreFromAbc('X:1\nM:4/4\nL:1/4\nK:C\n$body');

  List<NoteElement> notesOf(Score s) =>
      s.measures.single.elements.whereType<NoteElement>().toList();

  String? annText(Score s, String id) {
    final m = s.annotations.where((a) => a.elementId == id);
    return m.isEmpty ? null : m.first.text;
  }

  DynamicLevel? dynLevel(Score s, String id) {
    final m = s.dynamics.where((d) => d.elementId == id);
    return m.isEmpty ? null : m.first.level;
  }

  test('chord symbols align to notes as annotations (with * skip)', () {
    final score = parse('C D E F |\n'
        's: "Cm" "F7" * "G" |\n');
    final notes = notesOf(score);
    expect(notes, hasLength(4));
    expect(annText(score, notes[0].id!), 'Cm');
    expect(annText(score, notes[1].id!), 'F7');
    expect(annText(score, notes[2].id!), isNull); // skipped
    expect(annText(score, notes[3].id!), 'G');
  });

  test('dynamics align to notes', () {
    final score = parse('C D E F |\n'
        's: !f! * * !p! |\n');
    final notes = notesOf(score);
    expect(dynLevel(score, notes[0].id!), DynamicLevel.f);
    expect(dynLevel(score, notes[3].id!), DynamicLevel.p);
    expect(score.dynamics, hasLength(2));
  });

  test('decorations merge onto their note (articulation + ornament)', () {
    final score = parse('C D E F |\n'
        's: !trill! !staccato! !fermata! !downbow! |\n');
    final notes = notesOf(score);
    expect(notes[0].ornament, Ornament.trill);
    expect(notes[1].articulations, contains(Articulation.staccato));
    expect(notes[2].articulations, contains(Articulation.fermata));
    expect(notes[3].articulations, contains(Articulation.downBow));
  });

  test('bare shorthand tokens (H T ~ .) work too', () {
    final score = parse('C D E F |\n'
        's: H T ~ . |\n');
    final notes = notesOf(score);
    expect(notes[0].articulations, contains(Articulation.fermata)); // H
    expect(notes[1].ornament, Ornament.trill); // T
    expect(notes[2].ornament, Ornament.turn); // ~
    expect(notes[3].articulations, contains(Articulation.staccato)); // .
  });

  test('a decoration in s: preserves the note pitch and duration', () {
    final score = parse('C2 D2 |\n'
        's: !fermata! * |\n');
    final notes = notesOf(score);
    expect(notes[0].pitches.single.step, Step.c);
    expect(notes[0].duration, NoteDuration.half);
    expect(notes[0].articulations, contains(Articulation.fermata));
  });

  test('no s: line leaves the score unchanged', () {
    final score = parse('C D E F |\n');
    expect(score.annotations, isEmpty);
    expect(score.dynamics, isEmpty);
    expect(notesOf(score).every((n) => n.articulations.isEmpty), isTrue);
  });

  test('an unknown token is ignored, not fatal', () {
    final score = parse('C D |\n'
        's: !nonsense! !p! |\n');
    final notes = notesOf(score);
    expect(annText(score, notes[0].id!), isNull);
    expect(dynLevel(score, notes[1].id!), DynamicLevel.p);
  });
}

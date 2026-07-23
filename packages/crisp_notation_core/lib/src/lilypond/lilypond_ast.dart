library;

abstract class LyNode {
  const LyNode();
}

class LyBlock extends LyNode {
  final List<LyNode> children;
  const LyBlock(this.children);
}

class LySimultaneous extends LyNode {
  final List<LyNode> children;
  const LySimultaneous(this.children);
}

class LyCommand extends LyNode {
  final String name;
  final List<LyNode> args;
  const LyCommand(this.name, this.args);
}

class LyAssignment extends LyNode {
  final String key;
  final LyNode value;
  const LyAssignment(this.key, this.value);
}

class LyNote extends LyNode {
  final String pitch; // e.g. c'
  final String? duration; // e.g. 4.
  final List<String> scripts; // e.g. -., ->, (, ), ~
  const LyNote(this.pitch, this.duration, this.scripts);
}

class LyRest extends LyNode {
  final String? duration;
  const LyRest(this.duration);
}

class LyChord extends LyNode {
  final List<String> pitches;
  final String? duration;
  final List<String> scripts;
  const LyChord(this.pitches, this.duration, this.scripts);
}

class LyString extends LyNode {
  final String value;
  const LyString(this.value);
}

class LyWord extends LyNode {
  final String value;
  const LyWord(this.value);
}

class LyScore extends LyNode {
  final List<LyNode> contents;
  const LyScore(this.contents);
}

library;

import '../model/element.dart';
import '../model/measure.dart';
import '../model/score.dart';
import '../theory/clef.dart';
import '../theory/duration.dart';
import '../theory/fraction.dart';
import '../theory/key_signature.dart';
import '../theory/pitch.dart';
import '../theory/time_signature.dart';
import 'lilypond_ast.dart';
import 'lilypond_lexer.dart';
import 'lilypond_parser.dart';

/// Parses a LilyPond string into a [Score].
Score scoreFromLilyPond(String ly) {
  final lexer = LilyPondLexer(ly);
  final tokens = lexer.tokenize();
  final parser = LilyPondParser(tokens);
  final ast = parser.parse();
  
  final reader = _LilyPondReader();
  return reader.buildScore(ast);
}

class _LilyPondReader {
  Clef _clef = Clef.treble;
  KeySignature _key = const KeySignature(0);
  TimeSignature _time = TimeSignature.commonTime;
  
  NoteDuration _currentDur = NoteDuration.quarter;
  Pitch _relativeBase = const Pitch(Step.c, octave: 3); // c
  bool _isRelative = false;
  
  final List<Measure> _measures = [];
  List<MusicElement> _currentElements = [];
  Fraction _measureTime = Fraction.zero;
  int _elementId = 0;
  
  Score buildScore(List<LyNode> nodes) {
    _processNodes(nodes);
    _closeMeasure(); // close any pending
    
    if (_measures.isEmpty) {
      _measures.add(Measure([RestElement(NoteDuration.whole, id: 'e0')]));
    }
    
    return Score(
      clef: _clef,
      keySignature: _key,
      timeSignature: _time,
      measures: _measures,
    );
  }

  void _processNodes(List<LyNode> nodes) {
    for (final node in nodes) {
      if (node is LyScore) {
        _processNodes(node.contents);
      } else if (node is LyBlock) {
        _processNodes(node.children);
      } else if (node is LyCommand) {
        _processCommand(node);
      } else if (node is LyNote) {
        _processNote(node);
      } else if (node is LyRest) {
        _processRest(node);
      } else if (node is LyChord) {
        _processChord(node);
      } else if (node is LyWord) {
        if (node.value == '|') {
          _closeMeasure();
        }
      } else if (node is LySimultaneous) {
        // Simplified polyphony: just process sequentially for now or 
        // handle voice2. A full implementation would merge parallel streams.
        // For now, process first block.
        if (node.children.isNotEmpty) {
           _processNodes([node.children.first]);
        }
      }
    }
  }

  void _processCommand(LyCommand cmd) {
    switch (cmd.name) {
      case 'relative':
        final oldRelative = _isRelative;
        final oldBase = _relativeBase;
        _isRelative = true;
        
        LyNode? block;
        if (cmd.args.isNotEmpty) {
          final first = cmd.args.first;
          if (first is LyWord) {
             _relativeBase = _parsePitch(first.value);
             if (cmd.args.length > 1) block = cmd.args[1];
          } else if (first is LyNote) {
             _relativeBase = _parsePitch(first.pitch);
             if (cmd.args.length > 1) block = cmd.args[1];
          } else if (first is LyBlock) {
             block = first;
          }
        }
        
        if (block != null) {
           _processNodes([block]);
           _isRelative = oldRelative;
           _relativeBase = oldBase;
        }
        break;
      case 'clef':
        if (cmd.args.isNotEmpty && cmd.args.first is LyString) {
          final c = (cmd.args.first as LyString).value;
          if (c == 'bass') _clef = Clef.bass;
          else if (c == 'alto') _clef = Clef.alto;
          else if (c == 'tenor') _clef = Clef.tenor;
          else _clef = Clef.treble;
        } else if (cmd.args.isNotEmpty && cmd.args.first is LyWord) {
          final c = (cmd.args.first as LyWord).value;
          if (c == 'bass') _clef = Clef.bass;
          else if (c == 'alto') _clef = Clef.alto;
          else if (c == 'tenor') _clef = Clef.tenor;
          else _clef = Clef.treble;
        }
        break;
      case 'time':
        if (cmd.args.isNotEmpty && cmd.args.first is LyWord) {
           final parts = (cmd.args.first as LyWord).value.split('/');
           if (parts.length == 2) {
              final n = int.tryParse(parts[0]);
              final d = int.tryParse(parts[1]);
              if (n != null && d != null) {
                 _time = TimeSignature.tryParse(n, d) ?? TimeSignature.commonTime;
              }
           }
        }
        break;
      case 'new':
      case 'with':
        // pass through inner blocks
        for (final arg in cmd.args) {
          if (arg is LyBlock) _processNodes([arg]);
        }
        break;
    }
  }

  void _processNote(LyNote note) {
    if (note.duration != null) {
       _currentDur = _parseDuration(note.duration!);
    }
    final pitch = _parsePitch(note.pitch);
    final p = _applyRelative(pitch);
    
    _checkMeasureBoundary(_currentDur.toFraction());
    _currentElements.add(NoteElement(
      pitches: [p],
      duration: _currentDur,
      id: 'e${_elementId++}',
    ));
    _measureTime = _measureTime + _currentDur.toFraction();
  }

  void _processChord(LyChord chord) {
    if (chord.duration != null) {
       _currentDur = _parseDuration(chord.duration!);
    }
    final pitches = chord.pitches.map((pStr) => _applyRelative(_parsePitch(pStr))).toList();
    if (pitches.isNotEmpty) {
       _checkMeasureBoundary(_currentDur.toFraction());
       _currentElements.add(NoteElement(
         pitches: pitches,
         duration: _currentDur,
         id: 'e${_elementId++}',
       ));
       _measureTime = _measureTime + _currentDur.toFraction();
    }
  }

  void _processRest(LyRest rest) {
    if (rest.duration != null) {
       _currentDur = _parseDuration(rest.duration!);
    }
    _checkMeasureBoundary(_currentDur.toFraction());
    _currentElements.add(RestElement(_currentDur, id: 'e${_elementId++}'));
    _measureTime = _measureTime + _currentDur.toFraction();
  }

  void _checkMeasureBoundary(Fraction nextDur) {
     final capacity = Fraction(_time.beats, _time.beatUnit);
     if (_measureTime + nextDur > capacity && _currentElements.isNotEmpty) {
        _closeMeasure();
     }
  }

  void _closeMeasure() {
    if (_currentElements.isEmpty) return;
    _measures.add(Measure(List.from(_currentElements)));
    _currentElements.clear();
    _measureTime = Fraction.zero;
  }

  Pitch _applyRelative(Pitch p) {
    if (!_isRelative) return p;
    // LilyPond relative pitch rules:
    // Distance from _relativeBase ignoring octaves
    final stepsBase = _relativeBase.step.index;
    final stepsP = p.step.index;
    
    // Find shortest distance
    int diff = stepsP - stepsBase;
    if (diff > 3) diff -= 7;
    if (diff < -3) diff += 7;
    
    // Apply octave shift based on shortest distance + explicit marks
    int octave = _relativeBase.octave;
    if (stepsP - stepsBase > 3) octave -= 1;
    if (stepsP - stepsBase < -3) octave += 1;
    
    // Add explicit octave marks from p (where p is initially parsed as if absolute around C3)
    // Actually, _parsePitch returns octave = 3 + ups - downs.
    // So p.octave - 3 is the explicit shift.
    octave += (p.octave - 3);
    
    final result = Pitch(p.step, alter: p.alter, octave: octave);
    _relativeBase = result; // update for next note
    return result;
  }

  Pitch _parsePitch(String pStr) {
    final noteRe = RegExp(r"^([a-g])(isis|eses|is|es)?([',]*)$");
    final m = noteRe.firstMatch(pStr);
    if (m == null) return const Pitch(Step.c);
    
    final stepStr = m[1]!.toLowerCase();
    final accStr = m[2] ?? '';
    final marks = m[3] ?? '';
    
    final step = Step.values.byName(stepStr);
    int alter = 0;
    if (accStr == 'is') alter = 1;
    if (accStr == 'isis') alter = 2;
    if (accStr == 'es') alter = -1;
    if (accStr == 'eses') alter = -2;
    
    final ups = "'".allMatches(marks).length;
    final downs = ",".allMatches(marks).length;
    
    return Pitch(step, alter: alter, octave: 3 + ups - downs);
  }

  NoteDuration _parseDuration(String durStr) {
    final baseRe = RegExp(r'^(\d+)(\.*)$');
    final m = baseRe.firstMatch(durStr);
    if (m == null) return NoteDuration.quarter;
    
    final val = m[1]!;
    final dots = (m[2] ?? '').length.clamp(0, 2);
    
    DurationBase base = DurationBase.quarter;
    switch (val) {
      case '1': base = DurationBase.whole; break;
      case '2': base = DurationBase.half; break;
      case '4': base = DurationBase.quarter; break;
      case '8': base = DurationBase.eighth; break;
      case '16': base = DurationBase.sixteenth; break;
      case '32': base = DurationBase.thirtySecond; break;
      case '64': base = DurationBase.sixtyFourth; break;
    }
    
    return NoteDuration(base, dots: dots);
  }
}

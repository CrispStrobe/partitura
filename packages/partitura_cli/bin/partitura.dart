/// `partitura` command-line tool.
///
/// ```
/// info      <in>                     parse and summarize a score
/// timeline  <in> [--bpm N] [--no-expand]
/// convert   <in> <out>               MusicXML <-> MIDI (by extension)
/// render    <in> <out.svg> [--tab] [--tuning std|dropD|bass]
///                                    [--staff-space N] [--metadata P]
///                                    [--no-embed-font]
/// ```
///
/// Formats are inferred from file extensions (`.xml`/`.musicxml`, `.mid`/
/// `.midi`, `.svg`) and can be overridden with `--from` / `--to`. Rendering to
/// PNG rides the Flutter renderer in the `partitura` package and is not part
/// of this pure-Dart tool.
library;

import 'dart:convert';
import 'dart:io';

import 'package:partitura_core/partitura_core.dart';

const _usage = '''
partitura — music notation CLI

Usage: partitura <command> [arguments]

Commands:
  info      <in>                       Summarize a score (clef, meter, sizes)
  timeline  <in> [--bpm N] [--no-expand]
                                       Print the playback timeline
  convert   <in> <out>                 Convert between MusicXML and MIDI
  render    <in> <out.svg> [options]   Render a score to SVG

Common:
  --from <musicxml|midi>               Force the input format
  --to   <musicxml|midi>               Force the convert output format

render options:
  --tab                                Render as guitar/bass tablature
  --tuning <std|dropD|bass>            Tab tuning (default std)
  --staff-space <px>                   Pixels per staff space (default 12)
  --metadata <path>                    SMuFL font metadata JSON
  --no-embed-font                      Do not embed the engraving font

timeline options:
  --bpm <n>                            Quarter-note tempo for seconds (default 120)
  --no-expand                          Keep document order (no repeats/jumps)
''';

void main(List<String> argv) {
  exitCode = _run(argv);
}

int _run(List<String> argv) {
  if (argv.isEmpty || argv.first == '-h' || argv.first == '--help') {
    stdout.writeln(_usage);
    return argv.isEmpty ? 64 : 0;
  }
  final command = argv.first;
  final rest = argv.sublist(1);
  try {
    switch (command) {
      case 'info':
        return _info(rest);
      case 'timeline':
        return _timeline(rest);
      case 'convert':
        return _convert(rest);
      case 'render':
        return _render(rest);
      default:
        stderr.writeln('Unknown command: $command\n');
        stderr.writeln(_usage);
        return 64;
    }
  } on _CliError catch (e) {
    stderr.writeln('error: ${e.message}');
    return 1;
  } on FormatException catch (e) {
    stderr.writeln('error: ${e.message}');
    return 1;
  }
}

/// Flags that never take a value (so they don't swallow a following argument).
const _booleanFlags = {'tab', 'no-embed-font', 'no-expand'};

int _info(List<String> args) {
  final (positional, options) = _parse(args);
  if (positional.isEmpty) throw _CliError('info needs an input file');
  final score = _loadScore(positional.first, options['from']);
  final timeline = playbackTimeline(score);
  final elements = score.measures.fold<int>(0, (n, m) => n + m.elements.length);
  stdout.writeln('file:       ${positional.first}');
  stdout.writeln('clef:       ${score.clef.name}');
  stdout.writeln('key:        ${score.keySignature.fifths} fifths');
  stdout.writeln('meter:      ${score.timeSignature ?? 'unmetered'}');
  stdout.writeln('measures:   ${score.measures.length}');
  stdout.writeln('elements:   $elements');
  stdout.writeln('timeline:   ${timeline.length} events (repeats expanded)');
  return 0;
}

int _timeline(List<String> args) {
  final (positional, options) = _parse(args);
  if (positional.isEmpty) throw _CliError('timeline needs an input file');
  final score = _loadScore(positional.first, options['from']);
  final bpm = double.tryParse(options['bpm'] ?? '120') ?? 120;
  final expand = !options.containsKey('no-expand');
  final timeline = playbackTimeline(score, expandRepeats: expand);
  stdout.writeln('# id\tstart\tdur\tseconds\tmeasure${' rest'}');
  for (final n in timeline) {
    final secs = secondsFor(n.start, quarterBpm: bpm).toStringAsFixed(3);
    stdout.writeln('${n.elementId}\t${n.start}\t${n.duration}\t$secs\t'
        'm${n.measureIndex}${n.isRest ? '\trest' : ''}');
  }
  return 0;
}

int _convert(List<String> args) {
  final (positional, options) = _parse(args);
  if (positional.length < 2) {
    throw _CliError('convert needs <in> <out>');
  }
  final inPath = positional[0];
  final outPath = positional[1];
  final score = _loadScore(inPath, options['from']);
  final outFormat = options['to'] ?? _formatOf(outPath);
  switch (outFormat) {
    case 'musicxml':
      File(outPath).writeAsStringSync(scoreToMusicXml(score));
    case 'midi':
      File(outPath).writeAsBytesSync(scoreToMidi(score));
    default:
      throw _CliError('cannot write format "$outFormat"');
  }
  stdout.writeln('wrote $outPath ($outFormat)');
  return 0;
}

int _render(List<String> args) {
  final (positional, options) = _parse(args);
  if (positional.length < 2) {
    throw _CliError('render needs <in> <out.svg>');
  }
  final score = _loadScore(positional[0], options['from']);
  final outPath = positional[1];
  final staffSpace = double.tryParse(options['staff-space'] ?? '12') ?? 12;

  final metadataFile = _findMetadata(options['metadata']);
  if (metadataFile == null) {
    throw _CliError('SMuFL metadata not found; pass --metadata <path>');
  }
  final metadata = SmuflMetadata.fromJson(
      jsonDecode(metadataFile.readAsStringSync()) as Map<String, Object?>);
  final settings = LayoutSettings(metadata: metadata);

  final ScoreLayout layout;
  if (options.containsKey('tab')) {
    final tuning = switch (options['tuning']) {
      'dropD' => Tuning.dropDGuitar,
      'bass' => Tuning.standardBass,
      _ => Tuning.standardGuitar,
    };
    layout = const TabLayoutEngine().layout(score, tuning, settings);
  } else {
    layout = const LayoutEngine().layout(score, settings);
  }

  String? fontUri;
  if (!options.containsKey('no-embed-font')) {
    final font = _siblingFont(metadataFile);
    if (font != null) {
      fontUri = 'data:font/otf;base64,${base64Encode(font.readAsBytesSync())}';
    }
  }

  final svg =
      scoreToSvg(layout, staffSpace: staffSpace, fontFaceDataUri: fontUri);
  File(outPath).writeAsStringSync(svg);
  stdout.writeln('wrote $outPath (${svg.length} bytes'
      '${fontUri == null ? '' : ', font embedded'})');
  return 0;
}

/// Loads a [Score] from [path], detecting the format from the extension or
/// the explicit [format] override (`musicxml` / `midi`).
Score _loadScore(String path, String? format) {
  final file = File(path);
  if (!file.existsSync()) throw _CliError('no such file: $path');
  switch (format ?? _formatOf(path)) {
    case 'musicxml':
      return scoreFromMusicXml(file.readAsStringSync());
    case 'midi':
      return scoreFromMidi(file.readAsBytesSync());
    default:
      throw _CliError('unknown input format for $path (use --from)');
  }
}

String _formatOf(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mid') || lower.endsWith('.midi')) return 'midi';
  if (lower.endsWith('.xml') || lower.endsWith('.musicxml')) return 'musicxml';
  if (lower.endsWith('.svg')) return 'svg';
  return 'unknown';
}

/// Finds the SMuFL metadata JSON: the explicit [override], else by walking up
/// from the running script to the repo's `packages/partitura/assets`.
File? _findMetadata(String? override) {
  if (override != null) {
    final f = File(override);
    return f.existsSync() ? f : throw _CliError('no metadata at $override');
  }
  var dir = File.fromUri(Platform.script).parent;
  for (var i = 0; i < 8; i++) {
    final candidate = File(
        '${dir.path}/packages/partitura/assets/smufl/bravura_metadata.json');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  return null;
}

/// The Bravura font next to a metadata file, if present (for embedding).
File? _siblingFont(File metadata) {
  final root = metadata.parent.parent.parent; // assets/smufl -> package root
  final font = File('${root.path}/assets/fonts/Bravura.otf');
  return font.existsSync() ? font : null;
}

/// Splits [args] into positional values and `--key[ value]` options.
(List<String>, Map<String, String>) _parse(List<String> args) {
  final positional = <String>[];
  final options = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--')) {
      final key = arg.substring(2);
      if (!_booleanFlags.contains(key) &&
          i + 1 < args.length &&
          !args[i + 1].startsWith('--')) {
        options[key] = args[++i];
      } else {
        options[key] = '';
      }
    } else {
      positional.add(arg);
    }
  }
  return (positional, options);
}

/// A user-facing CLI error (printed without a stack trace).
class _CliError implements Exception {
  final String message;
  _CliError(this.message);
}

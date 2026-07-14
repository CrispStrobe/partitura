/// Optical music recognition (OMR): staff-notation image → [Score] model.
///
/// The recognition itself is done by an external engine (the Sheet Music
/// Transformer, wired through CrispEmbed's FFI bridge in `crisp_notation_cli`),
/// which returns a `bekern` token sequence. This library is the pure-Dart back
/// half of the pipeline: `bekern` → Humdrum `**kern` ([bekernToKern]) → the
/// score model. A grand-staff (two-spine) recognition becomes a [GrandStaff];
/// a single spine a [Score]; any number of spines a [StaffSystem].
///
/// Keeping the model coupling here (rather than in the engine) means the whole
/// image-to-model chain is testable without a native library: feed a known
/// `bekern` string and assert on the resulting [Score].
library;

import 'dart:typed_data';

import '../humdrum/kern_reader.dart';
import '../layout/grand_staff.dart';
import '../layout/staff_system.dart';
import '../model/score.dart';
import 'bekern.dart';

/// Which OMR token dialect an engine returned.
enum OmrDialect {
  /// SMT `bekern` (a linearised grand-staff Humdrum) — parse with
  /// [bekernToGrandStaff] / [bekernToScore].
  bekern,

  /// TrOMR PrIMuS-style *semantic* notation (`clef-G2 note-C4_quarter …`) —
  /// parse with `scoreFromSemantic`.
  semantic,

  /// Flova LilyPond "simple notes" (`c'2 a''8 r4 …`) — parse with
  /// `scoreFromLilyNotes`.
  lilyNotes,
}

/// A LilyPond simple-note token: a pitch letter (or `r`) first, then octave
/// marks / accidental letters, then a duration digit — the shape Flova emits
/// and neither `bekern` (digit-first, `<t>`/`**kern`) nor semantic (`note-`/
/// `clef-`) produces.
final _lilyNoteRe = RegExp(r"(^|\s)(r\d|[a-g][a-z]*[',]*\d)");

/// Sniffs which dialect [tokens] are, so a caller can pick the right parser
/// without knowing which engine (SMT / TrOMR / Flova) produced them: semantic
/// uses `note-`/`clef-`/`…-` prefixes; `bekern` uses `<t>`/`<s>`/`<b>`/`**kern`;
/// Flova is bare LilyPond notes.
OmrDialect omrDialectOf(String tokens) {
  if (tokens.contains('note-') ||
      tokens.contains('clef-') ||
      tokens.contains('timeSignature-') ||
      tokens.contains('keySignature-')) {
    return OmrDialect.semantic;
  }
  if (tokens.contains('<t>') ||
      tokens.contains('<s>') ||
      tokens.contains('<b>') ||
      tokens.contains('**kern') ||
      tokens.contains('**ekern')) {
    return OmrDialect.bekern;
  }
  if (_lilyNoteRe.hasMatch(tokens)) return OmrDialect.lilyNotes;
  return OmrDialect.bekern;
}

/// A pixel buffer for [OmrEngine.recognize]: row-major `width`×`height`, with
/// `channels` bytes per pixel (1 = gray, 3 = RGB, 4 = RGBA). The engine applies
/// its own grayscale/invert/resize preprocessing.
class OmrImage {
  /// Raw pixel bytes, row-major, `channels` per pixel.
  final Uint8List pixels;

  /// Image width in pixels.
  final int width;

  /// Image height in pixels.
  final int height;

  /// Bytes per pixel: 1 (gray), 3 (RGB) or 4 (RGBA).
  final int channels;

  /// Wraps a raw pixel buffer. [pixels] must hold `width*height*channels` bytes.
  OmrImage(this.pixels,
      {required this.width, required this.height, this.channels = 1})
      : assert(pixels.length >= width * height * channels,
            'pixel buffer too small for $width×$height×$channels');
}

/// An optical-music-recognition engine: a staff image → `bekern` tokens.
///
/// Implemented outside `crisp_notation_core` (the CrispEmbed FFI bridge lives in
/// `crisp_notation_cli`), so this package stays pure Dart. Combine an engine with
/// [bekernToGrandStaff] & co. to reach the score model, or use the
/// [recognizeGrandStaff]/[recognizeScore] helpers.
abstract class OmrEngine {
  /// Recognises [image], returning a space-joined `bekern` token sequence.
  Future<String> recognize(OmrImage image);
}

/// Recognises [image] with [engine] and parses the result as a [GrandStaff]
/// (the usual shape for piano/grand-staff scores).
Future<GrandStaff> recognizeGrandStaff(
        OmrEngine engine, OmrImage image) async =>
    bekernToGrandStaff(await engine.recognize(image));

/// Recognises [image] with [engine] and parses the first spine as a [Score].
Future<Score> recognizeScore(OmrEngine engine, OmrImage image) async =>
    bekernToScore(await engine.recognize(image));

/// `bekern` tokens → single-staff [Score] (first spine).
Score bekernToScore(String bekern) =>
    scoreFromKern(_ensureKernHeaders(bekernToKern(bekern)));

/// `bekern` tokens → two-staff [GrandStaff].
GrandStaff bekernToGrandStaff(String bekern) =>
    grandStaffFromKern(_ensureKernHeaders(bekernToKern(bekern)));

/// `bekern` tokens → [StaffSystem] (one staff per spine).
StaffSystem bekernToStaffSystem(String bekern) =>
    staffSystemFromKern(_ensureKernHeaders(bekernToKern(bekern)));

/// Guarantees a `**kern` document is well formed even when the recogniser
/// emitted only the data records: if no exclusive-interpretation record is
/// present, prepends `**kern`×N and appends `*-`×N, where N is the widest row's
/// spine count. A document that already declares its spines is returned as-is.
String _ensureKernHeaders(String kern) {
  final lines = kern.split('\n');
  final hasExclusive = lines.any((l) => l
      .trimRight()
      .split('\t')
      .any((c) => c == '**kern' || c.startsWith('**ekern')));
  if (hasExclusive) return kern;
  var spines = 1;
  for (final l in lines) {
    final n = l.trimRight().split('\t').length;
    if (l.trim().isNotEmpty && n > spines) spines = n;
  }
  final header = List.filled(spines, '**kern').join('\t');
  final footer = List.filled(spines, '*-').join('\t');
  return '$header\n${kern.trimRight()}\n$footer\n';
}

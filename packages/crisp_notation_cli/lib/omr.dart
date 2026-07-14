/// Reusable optical-music-recognition API — the CrispEmbed FFI engine plus the
/// pure-Dart parsers, in one import.
///
/// This is the OMR pipeline factored out of the `crisp_notation omr` command so any
/// Dart program can drive it: **the CLI and Flutter desktop** (macOS / Windows /
/// Linux), i.e. anywhere `dart:ffi` is available. It does **not** work on the
/// web (Dart/Flutter web has no `dart:ffi`, and CrispEmbed's WASM build does not
/// expose the OMR engines — that would be an upstream change).
///
/// Typical use:
/// ```dart
/// import 'package:crisp_notation_cli/omr.dart';
///
/// final modelPath = await resolveOmrModel('smt-grandstaff'); // download+cache
/// final engine = CrispEmbedOmrEngine.load(modelPath);       // needs libcrispembed
/// try {
///   final tokens = engine.recognizeSync(decodeOmrImage('scan.png'));
///   final score = switch (omrDialectOf(tokens)) {
///     OmrDialect.bekern => bekernToGrandStaff(tokens), // → GrandStaff
///     OmrDialect.semantic => scoreFromSemantic(tokens), // → Score
///     OmrDialect.lilyNotes => scoreFromLilyNotes(tokens), // → Score
///   };
///   // … render / export `score` with crisp_notation_core.
/// } finally {
///   engine.dispose();
/// }
/// ```
/// For a full-page scan, split it first with [segmentStaffSystems] and recognise
/// each crop. Requires `libcrispembed` at runtime (see `CrispEmbedOmrEngine.load`).
library;

// The pure-Dart parsers + dialect detection that turn engine output into the
// score model (re-exported from crisp_notation_core so one import is enough).
export 'package:crisp_notation_core/crisp_notation_core.dart'
    show
        OmrEngine,
        OmrImage,
        OmrDialect,
        omrDialectOf,
        bekernToGrandStaff,
        bekernToScore,
        bekernToStaffSystem,
        bekernToKern,
        scoreFromSemantic,
        scoreFromLilyNotes;

// The native engine, image decode/segmentation, and model auto-download.
export 'src/crispembed_omr.dart';

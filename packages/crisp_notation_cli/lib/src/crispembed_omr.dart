/// CrispEmbed optical-music-recognition engine, via `dart:ffi`.
///
/// Binds CrispEmbed's arch-dispatching OCR entry points
/// (`crispembed_ocr_model_*`) in `libcrispembed`. Handed a Sheet Music
/// Transformer GGUF, the dispatcher runs the SMT engine and returns a `bekern`
/// token sequence — which `crisp_notation_core`'s [OmrEngine] contract turns into a
/// [GrandStaff]/[Score].
///
/// The native library and model are located at runtime; nothing here is needed
/// to compile or test the rest of the CLI. Image decoding is pure Dart
/// (`package:image`), so no native image codecs are required.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:crisp_notation_core/crisp_notation_core.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;

// Native signatures (crispembed_ocr_model_* in libcrispembed).
typedef _InitC = Pointer<Void> Function(Pointer<Utf8>, Int32);
typedef _InitD = Pointer<Void> Function(Pointer<Utf8>, int);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeD = void Function(Pointer<Void>);
typedef _RecognizeC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Uint8>, Int32, Int32, Int32, Pointer<Int32>);
typedef _RecognizeD = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Uint8>, int, int, int, Pointer<Int32>);

/// An [OmrEngine] backed by CrispEmbed's SMT model through FFI.
///
/// Load once with [CrispEmbedOmrEngine.load], reuse across images, then
/// [dispose]. Not thread-safe; use one engine per isolate.
class CrispEmbedOmrEngine implements OmrEngine {
  final Pointer<Void> _ctx;
  final _RecognizeD _recognize;
  final _FreeD _free;
  bool _disposed = false;

  CrispEmbedOmrEngine._(this._ctx, this._recognize, this._free);

  /// Loads [modelPath] (an SMT GrandStaff GGUF) with the native library found
  /// at [libraryPath] (or, when null, the platform default / `CRISPEMBED_LIB`).
  ///
  /// Throws [OmrEngineException] if the library or its symbols can't be loaded
  /// or the model fails to initialise.
  factory CrispEmbedOmrEngine.load(
    String modelPath, {
    String? libraryPath,
    int threads = 0,
  }) {
    if (!File(modelPath).existsSync()) {
      throw OmrEngineException('model not found: $modelPath');
    }
    final DynamicLibrary lib;
    try {
      lib = DynamicLibrary.open(libraryPath ?? _defaultLibraryName());
    } on Object catch (e) {
      throw OmrEngineException(
          'could not load libcrispembed (${libraryPath ?? _defaultLibraryName()}): $e\n'
          'Build it in CrispEmbed, then pass --lib <path> or set CRISPEMBED_LIB.');
    }
    final _InitD init;
    final _RecognizeD recognize;
    final _FreeD free;
    try {
      init = lib.lookupFunction<_InitC, _InitD>('crispembed_ocr_model_init');
      recognize = lib.lookupFunction<_RecognizeC, _RecognizeD>(
          'crispembed_ocr_model_recognize');
      free = lib.lookupFunction<_FreeC, _FreeD>('crispembed_ocr_model_free');
    } on Object catch (e) {
      throw OmrEngineException('libcrispembed is missing OCR symbols: $e');
    }
    final pathPtr = modelPath.toNativeUtf8();
    final Pointer<Void> ctx;
    try {
      ctx = init(pathPtr, threads);
    } finally {
      malloc.free(pathPtr);
    }
    if (ctx == nullptr) {
      throw OmrEngineException('failed to initialise OMR model: $modelPath');
    }
    return CrispEmbedOmrEngine._(ctx, recognize, free);
  }

  @override
  Future<String> recognize(OmrImage image) async => recognizeSync(image);

  /// Synchronous recognition — the native call blocks anyway. Returns the
  /// `bekern` token sequence.
  String recognizeSync(OmrImage image) {
    if (_disposed) throw StateError('engine disposed');
    final n = image.pixels.length;
    final buf = malloc<Uint8>(n);
    final outLen = malloc<Int32>();
    try {
      buf.asTypedList(n).setAll(0, image.pixels);
      final res = _recognize(
          _ctx, buf, image.width, image.height, image.channels, outLen);
      if (res == nullptr) throw OmrEngineException('recognition returned null');
      return res.toDartString();
    } finally {
      malloc.free(buf);
      malloc.free(outLen);
    }
  }

  /// Frees the native model. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _free(_ctx);
  }

  static String _defaultLibraryName() {
    final env = Platform.environment['CRISPEMBED_LIB'];
    if (env != null && env.isNotEmpty) return env;
    if (Platform.isMacOS) return 'libcrispembed.dylib';
    if (Platform.isWindows) return 'crispembed.dll';
    return 'libcrispembed.so';
  }
}

/// Decodes a PNG/JPEG/BMP image file into an [OmrImage] (RGBA) for recognition.
///
/// Throws [OmrEngineException] if the file cannot be decoded.
OmrImage decodeOmrImage(String path) => omrImageOf(decodeImageFile(path));

/// Decodes a PNG/JPEG/BMP image file to an `img.Image`. Throws
/// [OmrEngineException] if it cannot be decoded.
img.Image decodeImageFile(String path) {
  final decoded = img.decodeImage(File(path).readAsBytesSync());
  if (decoded == null) throw OmrEngineException('cannot decode image: $path');
  return decoded;
}

/// Converts a decoded [image] to an RGBA [OmrImage] for recognition.
OmrImage omrImageOf(img.Image image) {
  final rgba = image.convert(numChannels: 4);
  return OmrImage(
    Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)),
    width: image.width,
    height: image.height,
    channels: 4,
  );
}

/// Splits a full-page staff [image] into individual staff-system crops by
/// horizontal-projection band detection: a row is "ink" if at least
/// [inkFraction] of its pixels are dark; maximal ink bands separated by
/// ≥ [minGapRows] blank rows become separate systems (bands shorter than
/// [minBandRows] are dropped as noise), each padded by [padRows]. Returns the
/// whole image (a single element) when it can't find a clean multi-system split
/// — so single-system input is unchanged.
List<img.Image> segmentStaffSystems(
  img.Image image, {
  double inkFraction = 0.04,
  int minGapRows = 12,
  int minBandRows = 16,
  int padRows = 10,
}) {
  final gray = img.grayscale(image);
  final w = gray.width;
  final h = gray.height;
  final threshold = (inkFraction * w).ceil();

  // Which rows carry ink.
  final ink = List<bool>.filled(h, false);
  for (var y = 0; y < h; y++) {
    var dark = 0;
    for (var x = 0; x < w; x++) {
      if (gray.getPixel(x, y).luminance < 128) dark++;
    }
    ink[y] = dark >= threshold;
  }

  // Group ink rows into bands, tolerating gaps < minGapRows (within a system).
  final bands = <(int, int)>[]; // (start, end) inclusive
  int? start;
  var gap = 0;
  for (var y = 0; y < h; y++) {
    if (ink[y]) {
      start ??= y;
      gap = 0;
    } else if (start != null) {
      gap++;
      if (gap >= minGapRows) {
        bands.add((start, y - gap));
        start = null;
        gap = 0;
      }
    }
  }
  if (start != null) bands.add((start, h - 1));

  final systems = bands.where((b) => b.$2 - b.$1 + 1 >= minBandRows).toList();
  if (systems.length <= 1) return [image];

  return [
    for (final (s, e) in systems)
      img.copyCrop(
        image,
        x: 0,
        y: (s - padRows).clamp(0, h - 1),
        width: w,
        height: ((e + padRows).clamp(0, h - 1)) -
            ((s - padRows).clamp(0, h - 1)) +
            1,
      ),
  ];
}

/// Raised when the OMR engine cannot load, initialise, or recognise.
class OmrEngineException implements Exception {
  /// Human-readable reason.
  final String message;

  /// Creates an exception with [message].
  OmrEngineException(this.message);

  @override
  String toString() => 'OmrEngineException: $message';
}

/// Known OMR models by short name → (Hugging Face repo, GGUF file). Used by
/// [resolveOmrModel] to auto-download a model when a name (not a path) is given.
const omrModelRegistry = <String, (String, String)>{
  'smt-grandstaff': ('cstr/smt-grandstaff-GGUF', 'smt-grandstaff-q8_0.gguf'),
  'smt': ('cstr/smt-grandstaff-GGUF', 'smt-grandstaff-q8_0.gguf'),
  'tromr': ('cstr/tromr-GGUF', 'tromr-q8_0.gguf'),
  'flova': ('cstr/flova-omr-GGUF', 'flova-q8_0.gguf'),
};

/// Resolves [model] to a local GGUF path: an existing file path is returned
/// as-is; a registered name (see [omrModelRegistry]) is downloaded from Hugging
/// Face to [cacheDir] (default `$XDG_CACHE_HOME/crisp_notation/omr`) if not already
/// cached, and the cached path returned. [onStatus] receives progress lines.
///
/// Throws [OmrEngineException] if the name is unknown or the download fails.
Future<String> resolveOmrModel(String model,
    {String? cacheDir, void Function(String)? onStatus}) async {
  if (File(model).existsSync()) return model;
  final entry = omrModelRegistry[model];
  if (entry == null) {
    throw OmrEngineException('model "$model" is not a file and not a known '
        'name (${omrModelRegistry.keys.toSet().join(', ')})');
  }
  final (repo, file) = entry;
  final dir = Directory(cacheDir ?? _omrCacheDir())
    ..createSync(recursive: true);
  final dest = File('${dir.path}/$file');
  if (dest.existsSync() && dest.lengthSync() > 0) return dest.path;

  final url = 'https://huggingface.co/$repo/resolve/main/$file';
  onStatus?.call('omr: downloading model "$model" from $url');
  final tmp = File('${dest.path}.part');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url)); // follows redirects
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      throw OmrEngineException(
          'download failed: HTTP ${response.statusCode} for $url');
    }
    final sink = tmp.openWrite();
    await response.pipe(sink);
  } on OmrEngineException {
    rethrow;
  } on Object catch (e) {
    throw OmrEngineException('download failed for $url: $e');
  } finally {
    client.close();
  }
  tmp.renameSync(dest.path);
  onStatus?.call('omr: cached model at ${dest.path}');
  return dest.path;
}

String _omrCacheDir() {
  final env = Platform.environment;
  final base = env['XDG_CACHE_HOME'] ??
      '${env['HOME'] ?? env['USERPROFILE'] ?? '.'}/.cache';
  return '$base/crisp_notation/omr';
}

/// CrispEmbed optical-music-recognition engine, via `dart:ffi`.
///
/// Binds CrispEmbed's arch-dispatching OCR entry points
/// (`crispembed_ocr_model_*`) in `libcrispembed`. Handed a Sheet Music
/// Transformer GGUF, the dispatcher runs the SMT engine and returns a `bekern`
/// token sequence — which `partitura_core`'s [OmrEngine] contract turns into a
/// [GrandStaff]/[Score].
///
/// The native library and model are located at runtime; nothing here is needed
/// to compile or test the rest of the CLI. Image decoding is pure Dart
/// (`package:image`), so no native image codecs are required.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:partitura_core/partitura_core.dart';

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
OmrImage decodeOmrImage(String path) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw OmrEngineException('cannot decode image: $path');
  final rgba = decoded.convert(numChannels: 4);
  return OmrImage(
    Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)),
    width: decoded.width,
    height: decoded.height,
    channels: 4,
  );
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

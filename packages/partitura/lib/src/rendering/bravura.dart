/// Access to the bundled Bravura font's SMuFL metadata.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:partitura_core/partitura_core.dart';

/// Loads and caches the metadata of the bundled Bravura font
/// (`assets/smufl/bravura_metadata.json`).
///
/// The first [StaffView] build triggers the load automatically and paints
/// once it completes. Call [load] up front (e.g. in `main()` or a test
/// `setUpAll`) to guarantee synchronous availability.
abstract final class Bravura {
  static SmuflMetadata? _metadata;
  static Future<SmuflMetadata>? _pending;

  /// The metadata, if already loaded.
  static SmuflMetadata? get metadataOrNull => _metadata;

  /// Loads the metadata from the asset bundle (once; later calls return
  /// the cached instance).
  static Future<SmuflMetadata> load() {
    if (_metadata != null) return Future.value(_metadata);
    return _pending ??= rootBundle
        .loadString('packages/partitura/assets/smufl/bravura_metadata.json')
        .then((source) {
      final metadata =
          SmuflMetadata.fromJson(jsonDecode(source) as Map<String, Object?>);
      _metadata = metadata;
      return metadata;
    });
  }

  /// Injects already-parsed [metadata] (for tests that load the JSON from
  /// the file system instead of an asset bundle).
  static void debugOverrideMetadata(SmuflMetadata metadata) {
    _metadata = metadata;
  }
}

/// Pluggable SMuFL music fonts.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:partitura_core/partitura_core.dart';

/// A SMuFL music font the renderer can draw with: the glyph [family] (the
/// font's internal family name, used for `TextStyle.fontFamily`), the asset
/// [package] the font lives in (null for the consuming app's own assets), and
/// the [metadataAsset] key of its `*_metadata.json` (glyph boxes, stem anchors
/// and engraving defaults).
///
/// SMuFL fixes the codepoint for every glyph name, so any SMuFL font drops in
/// without touching the glyph tables — only the outlines and metrics change.
/// Bundle the `.otf` + metadata as assets, declare the font in your
/// `pubspec.yaml`, and pass a [MusicFont] through `PartituraTheme.musicFont`.
class MusicFont {
  /// The font's internal family name (matches its `pubspec` font `family`).
  final String family;

  /// The asset package the font and metadata live in; null for the app's own.
  final String? package;

  /// Asset key of the font's SMuFL metadata JSON.
  final String metadataAsset;

  /// Describes a music font.
  const MusicFont({
    required this.family,
    required this.metadataAsset,
    this.package,
  });

  /// The bundled Bravura font (the default).
  static const MusicFont bravura = MusicFont(
    family: 'Bravura',
    package: 'partitura',
    metadataAsset: 'packages/partitura/assets/smufl/bravura_metadata.json',
  );

  @override
  bool operator ==(Object other) =>
      other is MusicFont &&
      other.family == family &&
      other.package == package &&
      other.metadataAsset == metadataAsset;

  @override
  int get hashCode => Object.hash(family, package, metadataAsset);

  @override
  String toString() => 'MusicFont($family)';
}

/// Loads and caches the [SmuflMetadata] of [MusicFont]s from the asset bundle,
/// keyed by family. A view triggers the load on first build and repaints once
/// it resolves; call [load] up front (e.g. in `main()` / a test `setUpAll`) for
/// synchronous availability.
abstract final class MusicFonts {
  static final Map<String, SmuflMetadata> _cache = {};
  static final Map<String, Future<SmuflMetadata>> _pending = {};

  /// The metadata for [font] if already loaded, else null.
  static SmuflMetadata? metadataOrNull(MusicFont font) => _cache[font.family];

  /// Loads (once) and caches [font]'s metadata. A failed load is not cached.
  static Future<SmuflMetadata> load(MusicFont font) {
    final cached = _cache[font.family];
    if (cached != null) return Future.value(cached);
    return _pending.putIfAbsent(font.family, () => _loadFresh(font));
  }

  static Future<SmuflMetadata> _loadFresh(MusicFont font) async {
    try {
      final source = await rootBundle.loadString(font.metadataAsset);
      final metadata =
          SmuflMetadata.fromJson(jsonDecode(source) as Map<String, Object?>);
      _cache[font.family] = metadata;
      return metadata;
    } catch (_) {
      _pending.remove(font.family); // allow a retry
      rethrow;
    }
  }

  /// Injects already-parsed [metadata] for [font] (tests that load the JSON
  /// from the file system instead of an asset bundle).
  static void debugRegister(MusicFont font, SmuflMetadata metadata) =>
      _cache[font.family] = metadata;

  /// Clears the caches so the next [load] hits the asset bundle again (tests).
  static void debugReset() {
    _cache.clear();
    _pending.clear();
  }
}

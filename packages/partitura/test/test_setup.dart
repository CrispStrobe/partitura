import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partitura/partitura.dart';

/// Loads the Bravura font and its metadata from the package assets so
/// rendering works in widget/golden tests (which have no async asset
/// loading and no fonts by default).
Future<void> setUpPartituraForTests() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  final metadataSource =
      File('assets/smufl/bravura_metadata.json').readAsStringSync();
  Bravura.debugOverrideMetadata(
    SmuflMetadata.fromJson(
      jsonDecode(metadataSource) as Map<String, Object?>,
    ),
  );

  final fontBytes = File('assets/fonts/Bravura.otf').readAsBytesSync();
  // Package fonts resolve to the family 'packages/<package>/<family>'.
  final loader = FontLoader('packages/partitura/Bravura')
    ..addFont(Future.value(ByteData.view(fontBytes.buffer)));
  await loader.load();
}

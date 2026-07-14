/// Flutter-backed PNG render harness, driven by `crisp_notation_cli`.
///
/// Not a real test — it is run via `flutter test tool/render_png.dart` (the
/// only way to reach `dart:ui` from a command line) with the job described by
/// environment variables, and writes a PNG file as its side effect:
///
///   CRISP_NOTATION_IN           input path (.musicxml / .mid)
///   CRISP_NOTATION_OUT          output .png path
///   CRISP_NOTATION_TAB          "1" to render tablature
///   CRISP_NOTATION_GRAND        "1" to render a two-staff grand staff (MusicXML)
///   CRISP_NOTATION_MULTIPART    "1" to render a multi-part document (all parts)
///   CRISP_NOTATION_WIDTH        multi-part line-break width in staff spaces
///   CRISP_NOTATION_HIDE_EMPTY   "1" to drop empty staves per system (multi-part)
///   CRISP_NOTATION_TUNING       std | dropD | bass
///   CRISP_NOTATION_STAFF_SPACE  pixels per staff space
///
/// It fails (non-zero exit) on a bad job so the CLI can report the error.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crisp_notation/crisp_notation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final env = Platform.environment;
  final inPath = env['CRISP_NOTATION_IN'];
  final outPath = env['CRISP_NOTATION_OUT'];
  final tab = env['CRISP_NOTATION_TAB'] == '1';
  final tuning = switch (env['CRISP_NOTATION_TUNING']) {
    'dropD' => Tuning.dropDGuitar,
    'bass' => Tuning.standardBass,
    _ => Tuning.standardGuitar,
  };
  final staffSpace =
      double.tryParse(env['CRISP_NOTATION_STAFF_SPACE'] ?? '12') ?? 12;

  testWidgets('render png', (tester) async {
    if (inPath == null || outPath == null) {
      fail('CRISP_NOTATION_IN and CRISP_NOTATION_OUT must be set');
    }
    TestWidgetsFlutterBinding.ensureInitialized();

    final metadata = SmuflMetadata.fromJson(jsonDecode(
            File('assets/smufl/bravura_metadata.json').readAsStringSync())
        as Map<String, Object?>);
    Bravura.debugOverrideMetadata(metadata);
    final fontBytes = File('assets/fonts/Bravura.otf').readAsBytesSync();
    await (FontLoader('packages/crisp_notation/Bravura')
          ..addFont(Future.value(ByteData.view(fontBytes.buffer))))
        .load();
    final textFont = _textFontCandidate();
    final theme = textFont == null
        ? CrispNotationTheme.standard
        : CrispNotationTheme.standard.copyWith(textFontFamily: textFont.family);
    if (textFont != null) {
      final bytes = textFont.file.readAsBytesSync();
      await (FontLoader(textFont.family)
            ..addFont(Future.value(ByteData.view(bytes.buffer))))
          .load();
    }

    final settings = LayoutSettings(metadata: metadata);
    late final List<int> png;

    if (env['CRISP_NOTATION_GRAND'] == '1') {
      // A two-staff grand staff (e.g. optical music recognition output).
      final grand = grandStaffFromMusicXml(File(inPath).readAsStringSync());
      final layout = layoutGrandStaff(grand, settings);
      await tester.runAsync(() async {
        png = await renderGrandStaffLayoutToPng(layout,
            staffSpace: staffSpace, theme: theme);
      });
    } else if (env['CRISP_NOTATION_MULTIPART'] == '1') {
      // A multi-part document: every part, line-broken into stacked systems.
      final maxWidth =
          double.tryParse(env['CRISP_NOTATION_WIDTH'] ?? '') ?? 120.0;
      final wrapped = layoutStaffSystemSystems(
          _loadStaffSystem(inPath), settings,
          maxWidth: maxWidth,
          hideEmptyStaves: env['CRISP_NOTATION_HIDE_EMPTY'] == '1');
      final systemContext = env['CRISP_NOTATION_SYSTEM_CONTEXT'] == '1';
      await tester.runAsync(() async {
        png = await renderStaffSystemSystemsToPng(wrapped,
            staffSpace: staffSpace,
            theme: theme,
            leftMargin: systemContext ? 10 : 0,
            showInstrumentLabels: systemContext,
            showSystemMeasureNumbers: systemContext,
            showTitle: env['CRISP_NOTATION_TITLE'] == '1');
      });
    } else {
      final lower = inPath.toLowerCase();
      final score = lower.endsWith('.mid') || lower.endsWith('.midi')
          ? scoreFromMidi(File(inPath).readAsBytesSync())
          : scoreFromMusicXml(File(inPath).readAsStringSync());
      final layout = tab
          ? const TabLayoutEngine().layout(score, tuning, settings)
          : const LayoutEngine().layout(score, settings);
      await tester.runAsync(() async {
        png = await renderLayoutToPng(layout,
            staffSpace: staffSpace, theme: theme);
      });
    }
    File(outPath).writeAsBytesSync(png);
  });
}

({String family, File file})? _textFontCandidate() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <({String family, String path})>[
    (family: 'CrispNotationText', path: '/System/Library/Fonts/NewYork.ttf'),
    (family: 'CrispNotationText', path: '/System/Library/Fonts/Times.ttc'),
    (family: 'CrispNotationText', path: '/Library/Fonts/Times New Roman.ttf'),
    (family: 'CrispNotationText', path: '/Library/Fonts/Georgia.ttf'),
    if (flutterRoot != null)
      (
        family: 'Roboto',
        path:
            '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf'
      ),
  ];
  for (final candidate in candidates) {
    final file = File(candidate.path);
    if (file.existsSync()) return (family: candidate.family, file: file);
  }
  return null;
}

/// Loads a multi-part [StaffSystem] from [path], picking the importer by
/// extension (MusicXML/MXL, MEI, kern, ABC) — mirrors the CLI's dispatch.
StaffSystem _loadStaffSystem(String path) {
  final file = File(path);
  final lower = path.toLowerCase();
  if (lower.endsWith('.mxl')) {
    return staffSystemFromMusicXml(readMusicXmlFromMxl(file.readAsBytesSync()));
  }
  if (lower.endsWith('.mei')) {
    return staffSystemFromMei(file.readAsStringSync());
  }
  if (lower.endsWith('.krn') || lower.endsWith('.kern')) {
    return staffSystemFromKern(file.readAsStringSync());
  }
  if (lower.endsWith('.abc')) {
    return staffSystemFromAbc(file.readAsStringSync());
  }
  return staffSystemFromMusicXml(file.readAsStringSync());
}

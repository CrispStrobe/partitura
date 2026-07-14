import 'package:flutter/widgets.dart';

import 'theme.dart';

/// A guitar/bass-fretboard visualizer (Phase 3.1) — draws a fretboard and lights
/// up every position where a currently-sounding pitch can be played. Pair it
/// with the playback cursor: feed `highlightedPitches` the MIDI numbers of the
/// sounding notes (e.g. `pitchesForElements(score, cursorIds)`).
///
/// crisp_notation never makes sound — this only *shows* the fretted positions. A
/// pitch that lies on several strings lights every one. The widget sizes itself;
/// wrap it in a `FittedBox` to scale to a box.
class FretboardView extends StatelessWidget {
  /// Open-string MIDI numbers, low string first. Default standard guitar
  /// (E2 A2 D3 G3 B3 E4). The low string is drawn at the bottom.
  final List<int> tuning;

  /// Number of frets to draw (default 12).
  final int frets;

  /// MIDI numbers of the sounding pitches to light up.
  final Set<int> highlightedPitches;

  /// Per-pitch highlight color override; falls back to [highlightColor] (then
  /// `theme.highlightColor`).
  final Map<int, Color>? pitchColors;

  /// Highlight color for lit positions; null uses `theme.highlightColor`.
  final Color? highlightColor;

  /// Colors (fret/string ink) and defaults.
  final CrispNotationTheme theme;

  /// Pixel width of one fret.
  final double fretWidth;

  /// Pixel spacing between adjacent strings.
  final double stringSpacing;

  /// Standard 6-string guitar tuning, low → high (E2 A2 D3 G3 B3 E4).
  static const List<int> standardGuitar = [40, 45, 50, 55, 59, 64];

  /// Standard 4-string bass tuning, low → high (E1 A1 D2 G2).
  static const List<int> standardBass = [28, 33, 38, 43];

  /// Frets that carry an inlay dot (single), plus the octave (double at 12).
  static const _inlays = {3, 5, 7, 9, 12};

  /// Creates a fretboard visualizer.
  const FretboardView({
    super.key,
    this.tuning = standardGuitar,
    this.frets = 12,
    this.highlightedPitches = const {},
    this.pitchColors,
    this.highlightColor,
    this.theme = CrispNotationTheme.standard,
    this.fretWidth = 26,
    this.stringSpacing = 14,
  });

  double get _openWidth => fretWidth; // room left of the nut for open notes
  double get _vMargin => stringSpacing * 0.75;

  @override
  Widget build(BuildContext context) {
    final width = _openWidth + frets * fretWidth;
    final height = (tuning.length - 1) * stringSpacing + 2 * _vMargin;
    return CustomPaint(
      size: Size(width, height),
      painter: _FretboardPainter(
        tuning: tuning,
        frets: frets,
        highlightedPitches: highlightedPitches,
        pitchColors: pitchColors,
        highlightColor: highlightColor ?? theme.highlightColor,
        inkColor: theme.staffColor,
        fretWidth: fretWidth,
        stringSpacing: stringSpacing,
        openWidth: _openWidth,
        vMargin: _vMargin,
      ),
    );
  }
}

class _FretboardPainter extends CustomPainter {
  _FretboardPainter({
    required this.tuning,
    required this.frets,
    required this.highlightedPitches,
    required this.pitchColors,
    required this.highlightColor,
    required this.inkColor,
    required this.fretWidth,
    required this.stringSpacing,
    required this.openWidth,
    required this.vMargin,
  });

  final List<int> tuning;
  final int frets;
  final Set<int> highlightedPitches;
  final Map<int, Color>? pitchColors;
  final Color highlightColor;
  final Color inkColor;
  final double fretWidth;
  final double stringSpacing;
  final double openWidth;
  final double vMargin;

  double _stringY(int s) =>
      vMargin + (tuning.length - 1 - s) * stringSpacing; // low at bottom

  @override
  void paint(Canvas canvas, Size size) {
    final boardLeft = openWidth;
    final boardRight = openWidth + frets * fretWidth;
    final topY = _stringY(tuning.length - 1);
    final botY = _stringY(0);

    final thin = Paint()
      ..color = inkColor
      ..strokeWidth = 1;
    final nut = Paint()
      ..color = inkColor
      ..strokeWidth = 3;

    // Inlay dots (faint), centered in the fret space.
    final inlay = Paint()..color = inkColor.withValues(alpha: 0.18);
    final midY = (topY + botY) / 2;
    for (final f in FretboardView._inlays) {
      if (f > frets) continue;
      final x = boardLeft + (f - 0.5) * fretWidth;
      if (f == 12) {
        canvas.drawCircle(
            Offset(x, midY - stringSpacing * 0.8), stringSpacing * 0.2, inlay);
        canvas.drawCircle(
            Offset(x, midY + stringSpacing * 0.8), stringSpacing * 0.2, inlay);
      } else {
        canvas.drawCircle(Offset(x, midY), stringSpacing * 0.22, inlay);
      }
    }

    // Frets (vertical); fret 0 = the nut, thicker.
    for (var f = 0; f <= frets; f++) {
      final x = boardLeft + f * fretWidth;
      canvas.drawLine(Offset(x, topY), Offset(x, botY), f == 0 ? nut : thin);
    }

    // Strings (horizontal), thicker for the lower (heavier) strings.
    for (var s = 0; s < tuning.length; s++) {
      final y = _stringY(s);
      canvas.drawLine(
        Offset(boardLeft, y),
        Offset(boardRight, y),
        Paint()
          ..color = inkColor
          ..strokeWidth = 0.7 + 0.5 * (1 - s / tuning.length),
      );
    }

    // Lit positions: every (string, fret) that sounds a highlighted pitch.
    final r = stringSpacing * 0.42;
    for (var s = 0; s < tuning.length; s++) {
      final open = tuning[s];
      for (var f = 0; f <= frets; f++) {
        final midi = open + f;
        if (!highlightedPitches.contains(midi)) continue;
        final color = pitchColors?[midi] ?? highlightColor;
        final x = f == 0 ? openWidth / 2 : boardLeft + (f - 0.5) * fretWidth;
        final y = _stringY(s);
        canvas.drawCircle(Offset(x, y), r, Paint()..color = color);
        if (f == 0) {
          // Draw open notes as a ring so they read as "open".
          canvas.drawCircle(
            Offset(x, y),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = inkColor,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FretboardPainter old) =>
      old.frets != frets ||
      old.fretWidth != fretWidth ||
      old.stringSpacing != stringSpacing ||
      old.highlightColor != highlightColor ||
      old.inkColor != inkColor ||
      !_listEq(old.tuning, tuning) ||
      !_setEq(old.highlightedPitches, highlightedPitches) ||
      !_mapEq(old.pitchColors, pitchColors);

  static bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _setEq(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  static bool _mapEq(Map<int, Color>? a, Map<int, Color>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}

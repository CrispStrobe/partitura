import 'package:flutter/widgets.dart';
import 'package:partitura_core/partitura_core.dart';

import 'bravura.dart';
import 'layout_painter.dart';
import 'theme.dart';

/// Renders a [Score] as guitar/bass **tablature** for a [tuning].
///
/// A parallel notation mode: pitches become fret numbers on an N-line string
/// staff (see [TabLayoutEngine]). The bundled Bravura metadata loads
/// asynchronously; call [Bravura.load] up front to guarantee a first paint.
class TabStaffView extends StatelessWidget {
  /// The music to render as tab.
  final Score score;

  /// The instrument tuning (string count + open pitches).
  final Tuning tuning;

  /// Pixels per staff space.
  final double staffSpace;

  /// Colors and fonts. Fret digits use [PartituraTheme.textFontFamily].
  final PartituraTheme theme;

  /// Ids painted in the highlight color.
  final Set<String> highlightedIds;

  /// Creates a tablature view.
  const TabStaffView({
    super.key,
    required this.score,
    required this.tuning,
    this.staffSpace = 12,
    this.theme = PartituraTheme.standard,
    this.highlightedIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final metadata = Bravura.metadataOrNull;
    if (metadata == null) return const SizedBox.shrink();
    final settings = LayoutSettings(metadata: metadata);
    final layout = const TabLayoutEngine().layout(score, tuning, settings);
    return CustomPaint(
      size: Size(layout.width * staffSpace, layout.height * staffSpace),
      painter: _TabPainter(
        layout: layout,
        theme: theme,
        scale: staffSpace,
        highlightedIds: highlightedIds,
      ),
    );
  }
}

class _TabPainter extends CustomPainter {
  final ScoreLayout layout;
  final PartituraTheme theme;
  final double scale;
  final Set<String> highlightedIds;

  _TabPainter({
    required this.layout,
    required this.theme,
    required this.scale,
    required this.highlightedIds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final painter = LayoutPainter(
      theme: theme,
      scale: scale,
      highlightedIds: highlightedIds,
    );
    painter.paintLayout(canvas, Offset(0, -layout.top * scale), layout);
    painter.dispose();
  }

  @override
  bool shouldRepaint(_TabPainter old) =>
      old.layout != layout ||
      old.theme != theme ||
      old.scale != scale ||
      old.highlightedIds != highlightedIds;
}

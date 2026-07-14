import 'dart:ui' show Color;

/// An overlay flag on one score element — for assessment / ear-training /
/// proofreading editors that compute their own analysis and ask crisp_notation to
/// show it. The element is drawn in [color] and gets a small wedge marker above
/// it; [message] is the app's own reason string (crisp_notation carries it so the
/// app can show a tooltip from an `onElementTap` / `onHover` hit, but does not
/// render it).
class EditorMark {
  /// Ink color for the flagged element (e.g. red = wrong, green = correct).
  final Color color;

  /// Optional human-readable reason, surfaced by the app (not drawn).
  final String? message;

  /// Creates an editor mark.
  const EditorMark(this.color, {this.message});

  @override
  bool operator ==(Object other) =>
      other is EditorMark && other.color == color && other.message == message;

  @override
  int get hashCode => Object.hash(color, message);

  @override
  String toString() =>
      'EditorMark($color${message == null ? '' : ', "$message"'})';
}

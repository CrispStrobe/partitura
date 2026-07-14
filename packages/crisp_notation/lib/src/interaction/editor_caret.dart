/// A visible insertion caret for score editors — either **before an element**
/// (`beforeElementId`) or at a **model position** (`measureIndex` +
/// `staffPosition`). A view draws a vertical caret at the resolved location and
/// hides it when the caret is null.
///
/// `beforeElementId` takes precedence when set; otherwise the caret sits at the
/// start of `measureIndex` (at `staffPosition`'s height, or the staff centre if
/// omitted).
class EditorCaret {
  /// Draw the caret just left of this element, wherever it lays out.
  final String? beforeElementId;

  /// Measure the caret sits in (`Score.measures` index), when not anchored to
  /// an element.
  final int? measureIndex;

  /// Optional staff position (0 = bottom line) for the caret's vertical centre;
  /// the staff centre when null.
  final int? staffPosition;

  /// Creates a caret. Give either [beforeElementId], or [measureIndex]
  /// (optionally with [staffPosition]).
  const EditorCaret({
    this.beforeElementId,
    this.measureIndex,
    this.staffPosition,
  });

  @override
  bool operator ==(Object other) =>
      other is EditorCaret &&
      other.beforeElementId == beforeElementId &&
      other.measureIndex == measureIndex &&
      other.staffPosition == staffPosition;

  @override
  int get hashCode => Object.hash(beforeElementId, measureIndex, staffPosition);

  @override
  String toString() => 'EditorCaret(before $beforeElementId, '
      'measure $measureIndex, position $staffPosition)';
}

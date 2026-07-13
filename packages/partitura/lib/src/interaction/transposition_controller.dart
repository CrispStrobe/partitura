import 'package:flutter/foundation.dart';
import 'package:partitura_core/partitura_core.dart';

/// A live transposition / concert-pitch control surface (Phase 3.6) — a thin
/// `ChangeNotifier` wrapper over the model's `Score.transposedBy` /
/// `atConcertPitch`. The app renders `controller.score` (rebuilding when the
/// controller notifies) and calls the mutators from its UI:
///
/// ```dart
/// final t = TranspositionController(score);
/// AnimatedBuilder(
///   animation: t,
///   builder: (_, __) => StaffView(score: t.score),
/// );
/// // ...from buttons:
/// t.transposeBy(Interval.majorSecond);   // up a whole tone
/// t.octaveDown();
/// t.showConcertPitch();                   // sounding pitch of a transposing part
/// t.reset();
/// ```
///
/// Transpositions **compose** (each call transposes the current score); concert
/// pitch and [reset] both start again from the original [base].
class TranspositionController extends ChangeNotifier {
  /// Wraps [base] — the original, untransposed score.
  TranspositionController(Score base)
      : _base = base,
        _score = base;

  final Score _base;
  Score _score;

  /// The original score, before any transposition.
  Score get base => _base;

  /// The score to render now (possibly transposed / at concert pitch).
  Score get score => _score;

  /// Whether [score] currently differs from [base].
  bool get isTransposed => !identical(_score, _base);

  /// Transposes the current [score] by [interval] (ascending unless
  /// [descending]); composes with earlier calls.
  void transposeBy(Interval interval, {bool descending = false}) {
    _setScore(_score.transposedBy(interval, descending: descending));
  }

  /// Transposes up by a perfect octave.
  void octaveUp() => transposeBy(Interval.perfectOctave);

  /// Transposes down by a perfect octave.
  void octaveDown() => transposeBy(Interval.perfectOctave, descending: true);

  /// Shows the concert-pitch (sounding) rendering of the [base] score — for a
  /// transposing instrument. A no-op-shaped score (no `transposition`) is
  /// unchanged.
  void showConcertPitch() => _setScore(_base.atConcertPitch());

  /// Returns to the original written [base] score.
  void reset() => _setScore(_base);

  void _setScore(Score next) {
    if (next == _score) return;
    _score = next;
    notifyListeners();
  }
}

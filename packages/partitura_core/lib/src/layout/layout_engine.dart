/// The layout engine: turns a [Score] into a [ScoreLayout]
/// (HANDOVER.md §4.2, rules 1–14).
library;

import 'dart:math';

import '../model/element.dart';
import '../model/measure.dart';
import '../model/score.dart';
import '../smufl/glyph_names.dart';
import '../smufl/smufl_metadata.dart';
import '../theory/clef.dart';
import '../theory/duration.dart';
import '../theory/fraction.dart';
import '../theory/pitch.dart';
import 'layout_settings.dart';
import 'score_layout.dart';

/// Pure, deterministic single-staff layout.
///
/// The same [Score] and [LayoutSettings] always produce an identical
/// [ScoreLayout]: no randomness, no clock, no platform dependence. All
/// output coordinates are in staff spaces (see [ScoreLayout]).
class LayoutEngine {
  /// Creates a layout engine.
  const LayoutEngine();

  /// Lays out [score] according to [settings].
  ScoreLayout layout(Score score, LayoutSettings settings) =>
      _LayoutBuilder(score, settings).build();
}

/// y-coordinate of a staff position (0 = bottom line → y = 4; y grows down).
double _yOf(num staffPosition) => (8 - staffPosition) / 2;

/// Mutable bounding-box accumulator.
class _Bounds {
  double minX = double.infinity;
  double minY = double.infinity;
  double maxX = double.negativeInfinity;
  double maxY = double.negativeInfinity;

  void expand(double left, double top, double right, double bottom) {
    if (left < minX) minX = left;
    if (top < minY) minY = top;
    if (right > maxX) maxX = right;
    if (bottom > maxY) maxY = bottom;
  }

  bool get isEmpty => minX > maxX;

  Rectangle<double> toRectangle() =>
      Rectangle(minX, minY, maxX - minX, maxY - minY);
}

/// A beamed group: indices into a measure's element list, plus direction.
class _BeamGroup {
  final List<int> indices;
  final bool stemsDown;
  _BeamGroup(this.indices, {required this.stemsDown});
}

/// Deferred stem/flag data for one beamed note, collected while walking the
/// measure and consumed when the group's beam geometry is computed.
class _BeamedNote {
  final String? elementId;
  final double stemX;

  /// y where the stem meets the notehead (anchor of the outermost notehead
  /// on the stem's far side).
  final double attachY;

  /// y of the outermost notehead on the beam side.
  final double refY;
  final bool isSixteenth;

  _BeamedNote({
    required this.elementId,
    required this.stemX,
    required this.attachY,
    required this.refY,
    required this.isSixteenth,
  });
}

/// Rendered notehead geometry of one element, kept for the tie pass.
/// Rests participate with an empty head list (a tie cannot cross a rest).
class _TieInfo {
  final NoteElement? note;
  final bool stemsDown;

  /// Per pitch: the notehead column's left/right x and its center y.
  final List<(Pitch, double, double, double)> heads;

  _TieInfo({required this.note, required this.stemsDown, required this.heads});
}

class _LayoutBuilder {
  final Score score;
  final LayoutSettings s;
  SmuflMetadata get meta => s.metadata;

  final List<LayoutPrimitive> _primitives = [];
  final Map<String, _Bounds> _elementBounds = {};
  final List<MeasureRegion> _measureRegions = [];
  final List<_TieInfo> _tieInfos = [];
  final _Bounds _ink = _Bounds();

  double _x = 0;

  _LayoutBuilder(this.score, this.s);

  // Key signature accidental staff positions per clef, in writing order.
  // Bass/alto shift the treble pattern down 2/1 positions; the tenor sharp
  // pattern is its own shape (F# starts low to stay inside the staff).
  static const Map<Clef, List<int>> _sharpPositions = {
    Clef.treble: [8, 5, 9, 6, 3, 7, 4],
    Clef.bass: [6, 3, 7, 4, 1, 5, 2],
    Clef.alto: [7, 4, 8, 5, 2, 6, 3],
    Clef.tenor: [2, 6, 3, 7, 4, 8, 5],
  };
  static const Map<Clef, List<int>> _flatPositions = {
    Clef.treble: [4, 7, 3, 6, 2, 5, 1],
    Clef.bass: [2, 5, 1, 4, 0, 3, -1],
    Clef.alto: [3, 6, 2, 5, 1, 4, 0],
    Clef.tenor: [5, 8, 4, 7, 3, 6, 2],
  };

  // log2(dot factor) for 0..2 dots: 1, 3/2, 7/4.
  static const List<double> _dotLog2 = [
    0.0,
    0.5849625007211562,
    0.8073549220576042
  ];

  ScoreLayout build() {
    _x = s.leadingPadding;
    _layoutClef();
    _layoutKeySignature();
    _layoutTimeSignature();

    for (var i = 0; i < score.measures.length; i++) {
      final startX = _x;
      _layoutMeasure(score.measures[i]);
      _measureRegions.add(MeasureRegion(i, startX: startX, endX: _x));
      if (i < score.measures.length - 1) {
        _addBarline();
      }
    }
    _layoutTies();
    final width = _addFinalBarline();

    // Staff lines span the full width; paint them first.
    final staffLines = [
      for (var line = 0; line < 5; line++)
        LinePrimitive(
          Point(0, line.toDouble()),
          Point(width, line.toDouble()),
          thickness: s.staffLineThickness,
        ),
    ];
    _primitives.insertAll(0, staffLines);
    _ink.expand(
      0,
      -s.staffLineThickness / 2,
      width,
      4 + s.staffLineThickness / 2,
    );

    final top = _ink.minY - s.verticalPadding;
    final bottom = _ink.maxY + s.verticalPadding;
    return ScoreLayout(
      width: width,
      height: bottom - top,
      top: top,
      primitives: List.unmodifiable(_primitives),
      regions: List.unmodifiable([
        for (final entry in _elementBounds.entries)
          ElementRegion(entry.key, entry.value.toRectangle()),
      ]),
      measureRegions: List.unmodifiable(_measureRegions),
    );
  }

  // ---------------------------------------------------------------- helpers

  void _addGlyph(String name, double x, double y, {String? elementId}) {
    _primitives.add(GlyphPrimitive(name, Point(x, y), elementId: elementId));
    final box = meta.bBoxOf(name);
    // SMuFL bounding boxes are y-up relative to the origin; flip.
    _expand(elementId, x + box.swX, y - box.neY, x + box.neX, y - box.swY);
  }

  void _addLine(
    Point<double> from,
    Point<double> to,
    double thickness, {
    String? elementId,
  }) {
    _primitives.add(
      LinePrimitive(from, to, thickness: thickness, elementId: elementId),
    );
    final h = thickness / 2;
    _expand(
      elementId,
      min(from.x, to.x) - h,
      min(from.y, to.y) - h,
      max(from.x, to.x) + h,
      max(from.y, to.y) + h,
    );
  }

  void _addCurve(
    Point<double> start,
    Point<double> control1,
    Point<double> control2,
    Point<double> end,
    double thickness,
  ) {
    _primitives.add(
      CurvePrimitive(start, control1, control2, end, thickness: thickness),
    );
    // The control polygon bounds the Bézier.
    final xs = [start.x, control1.x, control2.x, end.x];
    final ys = [start.y, control1.y, control2.y, end.y];
    final h = thickness / 2;
    _expand(
      null,
      xs.reduce(min) - h,
      ys.reduce(min) - h,
      xs.reduce(max) + h,
      ys.reduce(max) + h,
    );
  }

  void _addBeam(
    Point<double> start,
    Point<double> end,
    double thickness,
  ) {
    _primitives.add(BeamPrimitive(start, end, thickness: thickness));
    final h = thickness / 2;
    _expand(
      null,
      min(start.x, end.x),
      min(start.y, end.y) - h,
      max(start.x, end.x),
      max(start.y, end.y) + h,
    );
  }

  void _expand(
    String? elementId,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    _ink.expand(left, top, right, bottom);
    if (elementId != null) {
      _elementBounds
          .putIfAbsent(elementId, _Bounds.new)
          .expand(left, top, right, bottom);
    }
  }

  double _glyphWidth(String name) => meta.bBoxOf(name).width;

  // ------------------------------------------------------- leading elements

  /// Rule 1: clef anchored on its reference line (gClef on G4's line,
  /// fClef on F3's, cClef on C4's).
  void _layoutClef() {
    final (glyph, position) = switch (score.clef) {
      Clef.treble => (SmuflGlyph.gClef, 2), // G4
      Clef.bass => (SmuflGlyph.fClef, 6), // F3
      Clef.alto => (SmuflGlyph.cClef, 4), // C4 on the middle line
      Clef.tenor => (SmuflGlyph.cClef, 6), // C4 on the fourth line
    };
    _addGlyph(glyph, _x, _yOf(position));
    _x += _glyphWidth(glyph) + s.clefGap;
  }

  /// Rule 2: key signature in standard order at conventional octaves.
  void _layoutKeySignature() {
    final fifths = score.keySignature.fifths;
    if (fifths == 0) return;
    final count = fifths.abs();
    final table =
        fifths > 0 ? _sharpPositions[score.clef]! : _flatPositions[score.clef]!;
    final glyph =
        fifths > 0 ? SmuflGlyph.accidentalSharp : SmuflGlyph.accidentalFlat;
    final width = _glyphWidth(glyph);
    for (var i = 0; i < count; i++) {
      _addGlyph(glyph, _x, _yOf(table[i]));
      _x += width + s.keyAccidentalGap;
    }
    _x += s.signatureGap - s.keyAccidentalGap;
  }

  /// Rule 3: stacked timeSig digits centered on the staff.
  void _layoutTimeSignature() {
    final time = score.timeSignature;
    if (time == null) return;
    final numerator = _timeSigGlyphs(time.beats);
    final denominator = _timeSigGlyphs(time.beatUnit);
    final numWidth = _rowWidth(numerator);
    final denWidth = _rowWidth(denominator);
    final groupWidth = max(numWidth, denWidth);
    // SMuFL timeSig digits are vertically centered on their origin; the
    // numerator centers on the space-above-middle line (y=1), the
    // denominator on the space-below-middle line (y=3).
    _addTimeSigRow(numerator, _x + (groupWidth - numWidth) / 2, 1);
    _addTimeSigRow(denominator, _x + (groupWidth - denWidth) / 2, 3);
    _x += groupWidth + s.signatureGap;
  }

  List<String> _timeSigGlyphs(int value) => [
        for (final ch in value.toString().split(''))
          SmuflGlyph.timeSigDigit(int.parse(ch)),
      ];

  double _rowWidth(List<String> glyphs) =>
      glyphs.fold(0.0, (sum, g) => sum + _glyphWidth(g));

  void _addTimeSigRow(List<String> glyphs, double startX, double y) {
    var x = startX;
    for (final glyph in glyphs) {
      // Align the glyph's left ink edge with the cursor.
      _addGlyph(glyph, x - meta.bBoxOf(glyph).swX, y);
      x += _glyphWidth(glyph);
    }
  }

  // ---------------------------------------------------------------- measure

  void _layoutMeasure(Measure measure) {
    final groups = _computeBeamGroups(measure);
    final beamedIndex = <int, _BeamGroup>{
      for (final group in groups)
        for (final index in group.indices) index: group,
    };
    final deferred = <_BeamGroup, List<_BeamedNote>>{};

    // Accidental state: (step, octave) -> alteration written earlier in
    // this measure. Resets every measure (rule 9).
    final written = <(Step, int), int>{};

    for (var i = 0; i < measure.elements.length; i++) {
      final element = measure.elements[i];
      switch (element) {
        case NoteElement():
          final group = beamedIndex[i];
          final beamed = _layoutNote(
            element,
            written,
            stemsDownOverride: group?.stemsDown,
            deferStem: group != null,
          );
          if (group != null && beamed != null) {
            deferred.putIfAbsent(group, () => []).add(beamed);
          }
        case RestElement():
          _layoutRest(element);
      }
    }

    for (final group in groups) {
      final notes = deferred[group];
      if (notes != null && notes.length >= 2) {
        _layoutBeamGroup(notes, stemsDown: group.stemsDown);
      }
    }
  }

  // ------------------------------------------------------------------ notes

  /// Rules 4–6, 8–11: noteheads, stem, flag, ledger lines, accidentals,
  /// dots, chord clustering. Returns deferred stem data when [deferStem].
  _BeamedNote? _layoutNote(
    NoteElement element,
    Map<(Step, int), int> written, {
    bool? stemsDownOverride,
    bool deferStem = false,
  }) {
    if (element.pitches.isEmpty) {
      throw ArgumentError('NoteElement.pitches must not be empty');
    }
    final id = element.id;
    final pitches = [...element.pitches]..sort(
        (a, b) => a.staffPosition(score.clef) - b.staffPosition(score.clef),
      );
    final positions = [
      for (final pitch in pitches) pitch.staffPosition(score.clef),
    ];
    final bottom = positions.first;
    final top = positions.last;

    final base = element.duration.base;
    final headGlyph = switch (base) {
      DurationBase.whole => SmuflGlyph.noteheadWhole,
      DurationBase.half => SmuflGlyph.noteheadHalf,
      _ => SmuflGlyph.noteheadBlack,
    };
    final headWidth = _glyphWidth(headGlyph);
    final hasStem = base != DurationBase.whole;

    // Rule 5: stem down when the notehead farthest from the middle line is
    // on or above it (chords: decided by the farther extreme; ties → down).
    final stemsDown = stemsDownOverride ?? ((top - 4) >= (4 - bottom));

    // Rule 9: accidentals — shown when the pitch deviates from what the key
    // signature and earlier accidentals in this measure imply;
    // `showAccidental` overrides. Hidden accidentals do not update state.
    final shown = <(Pitch, int)>[]; // pitch + its staff position
    for (var i = 0; i < pitches.length; i++) {
      final pitch = pitches[i];
      final key = (pitch.step, pitch.octave);
      final implied = written[key] ?? score.keySignature.alterFor(pitch.step);
      final show = element.showAccidental ?? (pitch.alter != implied);
      if (show) {
        shown.add((pitch, positions[i]));
        written[key] = pitch.alter;
      }
    }
    // Naive vertical stacking: topmost accidental closest to the note,
    // each further one in its own column to the left.
    shown.sort((a, b) => b.$2 - a.$2);
    var preWidth = 0.0;
    for (final (pitch, _) in shown) {
      preWidth +=
          _glyphWidth(SmuflGlyph.accidentalFor(pitch.alter)) + s.accidentalGap;
    }

    final noteX = _x + preWidth;

    var accRight = noteX - s.accidentalGap;
    for (final (pitch, position) in shown) {
      final glyph = SmuflGlyph.accidentalFor(pitch.alter);
      final accX = accRight - _glyphWidth(glyph);
      _addGlyph(glyph, accX - meta.bBoxOf(glyph).swX, _yOf(position),
          elementId: id);
      accRight = accX - s.accidentalGap;
    }

    // Rule 11: seconds are resolved by offsetting the interfering notehead
    // to the other side of the stem. Walk from the stem's anchor end.
    final columnX = List<double>.filled(positions.length, noteX);
    final flippedX = stemsDown
        ? noteX - headWidth + s.stemThickness
        : noteX + headWidth - s.stemThickness;
    final order = stemsDown
        ? [for (var i = positions.length - 1; i >= 0; i--) i]
        : [for (var i = 0; i < positions.length; i++) i];
    for (var k = 1; k < order.length; k++) {
      final current = order[k];
      final previous = order[k - 1];
      if ((positions[current] - positions[previous]).abs() == 1 &&
          columnX[previous] == noteX) {
        columnX[current] = hasStem ? flippedX : noteX + headWidth;
      }
    }

    for (var i = 0; i < positions.length; i++) {
      _addGlyph(headGlyph, columnX[i], _yOf(positions[i]), elementId: id);
    }
    _tieInfos.add(_TieInfo(
      note: element,
      stemsDown: stemsDown,
      heads: [
        for (var i = 0; i < positions.length; i++)
          (
            pitches[i],
            columnX[i],
            columnX[i] + headWidth,
            _yOf(positions[i]),
          ),
      ],
    ));

    // Rule 8: ledger lines.
    final minColX = columnX.reduce(min);
    final maxColX = columnX.reduce(max);
    _addLedgerLines(
      bottom,
      top,
      minColX - s.legerLineExtension,
      maxColX + headWidth + s.legerLineExtension,
      id,
    );

    // Rules 5–6: stem and flag (or defer to the beam pass).
    _BeamedNote? beamed;
    double? stemTipY;
    double stemX = noteX;
    if (hasStem) {
      final anchors = meta.anchorsOf(headGlyph);
      if (stemsDown) {
        final anchor = anchors.stemDownNW ?? const Point(0.0, 0.0);
        stemX = noteX + anchor.x + s.stemThickness / 2;
        final attachY = _yOf(top) - anchor.y; // SMuFL y-up -> flip sign
        if (deferStem) {
          beamed = _BeamedNote(
            elementId: id,
            stemX: stemX,
            attachY: attachY,
            refY: _yOf(bottom),
            isSixteenth: base == DurationBase.sixteenth,
          );
        } else {
          var tipY = _yOf(bottom) + s.stemLength;
          if (tipY < 2) tipY = 2; // extend toward the middle line
          _addLine(
            Point(stemX, attachY),
            Point(stemX, tipY),
            s.stemThickness,
            elementId: id,
          );
          stemTipY = tipY;
        }
      } else {
        final anchor = anchors.stemUpSE ?? Point(headWidth, 0.0);
        stemX = noteX + anchor.x - s.stemThickness / 2;
        final attachY = _yOf(bottom) - anchor.y;
        if (deferStem) {
          beamed = _BeamedNote(
            elementId: id,
            stemX: stemX,
            attachY: attachY,
            refY: _yOf(top),
            isSixteenth: base == DurationBase.sixteenth,
          );
        } else {
          var tipY = _yOf(top) - s.stemLength;
          if (tipY > 2) tipY = 2; // extend toward the middle line
          _addLine(
            Point(stemX, attachY),
            Point(stemX, tipY),
            s.stemThickness,
            elementId: id,
          );
          stemTipY = tipY;
        }
      }
    }

    if (!deferStem && stemTipY != null) {
      final flagGlyph = switch (base) {
        DurationBase.eighth =>
          stemsDown ? SmuflGlyph.flag8thDown : SmuflGlyph.flag8thUp,
        DurationBase.sixteenth =>
          stemsDown ? SmuflGlyph.flag16thDown : SmuflGlyph.flag16thUp,
        _ => null,
      };
      if (flagGlyph != null) {
        _addGlyph(flagGlyph, stemX - s.stemThickness / 2, stemTipY,
            elementId: id);
      }
    }

    // Rule 10: augmentation dots right of the notehead; a dot for a
    // notehead on a line sits in the space above.
    var inkRight = maxColX + headWidth;
    if (element.duration.dots > 0) {
      final dotWidth = _glyphWidth(SmuflGlyph.augmentationDot);
      final dotStart = maxColX + headWidth + s.dotGap;
      for (final position in positions.toSet()) {
        final dotY = position.isEven ? _yOf(position) - 0.5 : _yOf(position);
        for (var d = 0; d < element.duration.dots; d++) {
          _addGlyph(
            SmuflGlyph.augmentationDot,
            dotStart + d * (dotWidth + s.dotSpacing),
            dotY,
            elementId: id,
          );
        }
      }
      inkRight = dotStart +
          element.duration.dots * (dotWidth + s.dotSpacing) -
          s.dotSpacing;
    }

    _advance(noteX, inkRight, element.duration);
    return beamed;
  }

  /// Rule 8 helper: ledger lines at even positions outside the staff.
  void _addLedgerLines(
    int bottomPosition,
    int topPosition,
    double left,
    double right,
    String? elementId,
  ) {
    for (var p = -2; p >= bottomPosition; p -= 2) {
      _addLine(
        Point(left, _yOf(p)),
        Point(right, _yOf(p)),
        s.legerLineThickness,
        elementId: elementId,
      );
    }
    for (var p = 10; p <= topPosition; p += 2) {
      _addLine(
        Point(left, _yOf(p)),
        Point(right, _yOf(p)),
        s.legerLineThickness,
        elementId: elementId,
      );
    }
  }

  // ------------------------------------------------------------------ rests

  /// Rule 12: rest glyphs at their conventional vertical homes.
  void _layoutRest(RestElement element) {
    final (glyph, y) = switch (element.duration.base) {
      // The whole rest hangs from the fourth staff line (y = 1).
      DurationBase.whole => (SmuflGlyph.restWhole, 1.0),
      // The half rest sits on the middle line (y = 2).
      DurationBase.half => (SmuflGlyph.restHalf, 2.0),
      DurationBase.quarter => (SmuflGlyph.restQuarter, 2.0),
      DurationBase.eighth => (SmuflGlyph.rest8th, 2.0),
      DurationBase.sixteenth => (SmuflGlyph.rest16th, 2.0),
    };
    final id = element.id;
    _addGlyph(glyph, _x, y, elementId: id);
    // Rests break tie chains.
    _tieInfos.add(_TieInfo(note: null, stemsDown: false, heads: const []));

    var inkRight = _x + _glyphWidth(glyph);
    if (element.duration.dots > 0) {
      final dotWidth = _glyphWidth(SmuflGlyph.augmentationDot);
      final dotStart = inkRight + s.dotGap;
      for (var d = 0; d < element.duration.dots; d++) {
        // Rest dots sit in the third space (y = 1.5).
        _addGlyph(
          SmuflGlyph.augmentationDot,
          dotStart + d * (dotWidth + s.dotSpacing),
          1.5,
          elementId: id,
        );
      }
      inkRight = dotStart +
          element.duration.dots * (dotWidth + s.dotSpacing) -
          s.dotSpacing;
    }
    _advance(_x, inkRight, element.duration);
  }

  // -------------------------------------------------------------- spacing

  /// Rule 13: notes/rests advance proportionally to duration with a minimum
  /// gap: `advance = spacingBase + spacingPerLog2 * (4 + log2(duration))`
  /// staff spaces, measured from the notehead column ([fromX]); a sixteenth
  /// gets `spacingBase`. The next element never starts closer than
  /// [minNoteGap] after this element's ink ([inkRight]).
  void _advance(double fromX, double inkRight, NoteDuration duration) {
    final log2Duration =
        -duration.base.index.toDouble() + _dotLog2[duration.dots];
    final ideal = s.spacingBase + s.spacingPerLog2 * (4 + log2Duration);
    _x = max(fromX + ideal, inkRight + s.minNoteGap);
  }

  // ------------------------------------------------------------------ ties

  /// v0.3.1: for every note with `tieToNext`, draw a tie curve to each
  /// identically-pitched notehead of the immediately following note
  /// element (also across barlines). The curve sits on the notehead side,
  /// away from the stem: above for stems-down notes, below for stems-up.
  /// Ties into rests or the end of the score draw nothing.
  void _layoutTies() {
    for (var i = 0; i < _tieInfos.length - 1; i++) {
      final start = _tieInfos[i];
      final note = start.note;
      if (note == null || !note.tieToNext) continue;
      final next = _tieInfos[i + 1];
      if (next.note == null) continue;
      final dir = start.stemsDown ? -1.0 : 1.0;
      for (final (pitch, _, xRight, y) in start.heads) {
        final matches = next.heads.where((h) => h.$1 == pitch);
        if (matches.isEmpty) continue;
        final x1 = xRight + 0.15;
        final x2 = matches.first.$2 - 0.15;
        if (x2 <= x1) continue;
        final baseY = y + dir * 0.6;
        final controlY = baseY + dir * (0.35 + min(0.6, (x2 - x1) * 0.06));
        _addCurve(
          Point(x1, baseY),
          Point(x1 + (x2 - x1) * 0.3, controlY),
          Point(x1 + (x2 - x1) * 0.7, controlY),
          Point(x2, baseY),
          0.18,
        );
      }
    }
  }

  // -------------------------------------------------------------- barlines

  void _addBarline() {
    _addLine(
      Point(_x, 0),
      Point(_x, 4),
      s.thinBarlineThickness,
    );
    _x += s.thinBarlineThickness + s.barlineGap;
  }

  /// Rule 13: `barlineFinal` (thin + thick) at the end; returns the width.
  double _addFinalBarline() {
    final thinX = _x;
    _addLine(Point(thinX, 0), Point(thinX, 4), s.thinBarlineThickness);
    final thickX = thinX +
        s.thinBarlineThickness / 2 +
        s.barlineSeparation +
        s.thickBarlineThickness / 2;
    _addLine(Point(thickX, 0), Point(thickX, 4), s.thickBarlineThickness);
    return thickX + s.thickBarlineThickness / 2;
  }

  // ---------------------------------------------------------------- beaming

  /// Rule 7: group eighths/sixteenths within a beat (simple meter). In
  /// even x/4 meters, adjacent all-eighth beat groups within the same half
  /// measure merge (so 8 eighths in 4/4 yield 2 beams). No beaming across
  /// rests or beat boundaries.
  List<_BeamGroup> _computeBeamGroups(Measure measure) {
    final time = score.timeSignature;
    // Unmetered scores group per quarter-note window.
    final span = time == null ? Fraction(1, 4) : Fraction(1, time.beatUnit);
    final halfSpan = Fraction(1, 2);

    var onset = Fraction.zero;
    final runs = <List<int>>[];
    final onsets = <Fraction>[];
    List<int>? current;
    int? currentWindow;

    for (var i = 0; i < measure.elements.length; i++) {
      final element = measure.elements[i];
      onsets.add(onset);
      final beamable = element is NoteElement &&
          (element.duration.base == DurationBase.eighth ||
              element.duration.base == DurationBase.sixteenth);
      if (beamable) {
        final window = _windowIndex(onset, span);
        if (current != null && window == currentWindow) {
          current.add(i);
        } else {
          current = [i];
          currentWindow = window;
          runs.add(current);
        }
      } else {
        current = null;
        currentWindow = null;
      }
      onset += element.duration.toFraction();
    }

    // Merge adjacent all-eighth beat groups within the same half measure.
    if (time != null && time.beatUnit == 4 && time.beats.isEven) {
      bool allEighths(List<int> run) => run.every((i) =>
          (measure.elements[i] as NoteElement).duration.base ==
          DurationBase.eighth);
      for (var i = 0; i < runs.length - 1;) {
        final a = runs[i];
        final b = runs[i + 1];
        if (b.first == a.last + 1 &&
            allEighths(a) &&
            allEighths(b) &&
            _windowIndex(onsets[a.first], halfSpan) ==
                _windowIndex(onsets[b.first], halfSpan)) {
          a.addAll(b);
          runs.removeAt(i + 1);
        } else {
          i++;
        }
      }
    }

    final groups = <_BeamGroup>[];
    for (final run in runs.where((r) => r.length >= 2)) {
      var maxAbove = -100;
      var maxBelow = -100;
      for (final i in run) {
        final note = measure.elements[i] as NoteElement;
        for (final pitch in note.pitches) {
          final p = pitch.staffPosition(score.clef);
          if (p - 4 > maxAbove) maxAbove = p - 4;
          if (4 - p > maxBelow) maxBelow = 4 - p;
        }
      }
      groups.add(_BeamGroup(run, stemsDown: maxAbove >= maxBelow));
    }
    return groups;
  }

  static int _windowIndex(Fraction onset, Fraction span) =>
      (onset.numerator * span.denominator) ~/
      (onset.denominator * span.numerator);

  /// Beam geometry: a straight beam through the stem tips, slant clamped to
  /// ±1 staff space over the group, intercept chosen so every stem keeps at
  /// least the default length. [BeamPrimitive] points are the midpoints of
  /// the beam's end edges; stems run to the beam's center line.
  void _layoutBeamGroup(List<_BeamedNote> notes, {required bool stemsDown}) {
    final first = notes.first;
    final last = notes.last;
    final dx = last.stemX - first.stemX;
    final slant = ((last.refY - first.refY) / 2).clamp(-1.0, 1.0);
    final slope = dx == 0 ? 0.0 : slant / dx;

    double intercept;
    if (stemsDown) {
      intercept =
          notes.map((n) => n.refY + s.stemLength - slope * n.stemX).reduce(max);
      // Never let a downward beam sit above the middle line.
      for (final n in notes) {
        final y = slope * n.stemX + intercept;
        if (y < 2) intercept += 2 - y;
      }
    } else {
      intercept =
          notes.map((n) => n.refY - s.stemLength - slope * n.stemX).reduce(min);
      for (final n in notes) {
        final y = slope * n.stemX + intercept;
        if (y > 2) intercept -= y - 2;
      }
    }

    double beamY(double x) => slope * x + intercept;

    for (final note in notes) {
      _addLine(
        Point(note.stemX, note.attachY),
        Point(note.stemX, beamY(note.stemX)),
        s.stemThickness,
        elementId: note.elementId,
      );
    }

    _addBeam(
      Point(first.stemX, beamY(first.stemX)),
      Point(last.stemX, beamY(last.stemX)),
      s.beamThickness,
    );

    // Secondary (sixteenth) beams, offset toward the noteheads.
    final offset = (s.beamThickness + s.beamSpacing) * (stemsDown ? -1 : 1);
    var i = 0;
    while (i < notes.length) {
      if (!notes[i].isSixteenth) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < notes.length && notes[j + 1].isSixteenth) {
        j++;
      }
      if (j > i) {
        _addBeam(
          Point(notes[i].stemX, beamY(notes[i].stemX) + offset),
          Point(notes[j].stemX, beamY(notes[j].stemX) + offset),
          s.beamThickness,
        );
      } else {
        // Lone sixteenth between eighths: a beamlet stub pointing into the
        // group (leftward unless it is the group's first note).
        final x = notes[i].stemX;
        final stubX = i == 0 ? x + 1.0 : x - 1.0;
        _addBeam(
          Point(min(x, stubX), beamY(min(x, stubX)) + offset),
          Point(max(x, stubX), beamY(max(x, stubX)) + offset),
          s.beamThickness,
        );
      }
      i = j + 1;
    }
  }
}

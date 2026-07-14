/// SMuFL glyph name → codepoint table.
///
/// The table now lives in `crisp_notation_core` (pure reference data shared by the
/// Flutter painter and the SVG emitter). This library re-exports it so the
/// historical import path `package:crisp_notation/src/rendering/smufl_glyphs.dart`
/// and the `smuflCodepoints` symbol keep working.
library;

export 'package:crisp_notation_core/crisp_notation_core.dart'
    show smuflCodepoints;

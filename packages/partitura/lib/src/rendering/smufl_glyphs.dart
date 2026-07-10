/// SMuFL glyph name → codepoint table for the glyphs partitura draws.
///
/// Codepoints follow the SMuFL specification
/// (https://w3c.github.io/smufl/latest/) and are identical in every
/// compliant font, including the bundled Bravura.
library;

/// Maps the SMuFL glyph names emitted by the layout engine (see
/// `SmuflGlyph` in `partitura_core`) to the character to draw.
const Map<String, String> smuflCodepoints = {
  'gClef': '\uE050',
  'fClef': '\uE062',
  'cClef': '\uE05C',
  'noteheadWhole': '\uE0A2',
  'noteheadHalf': '\uE0A3',
  'noteheadBlack': '\uE0A4',
  'flag8thUp': '\uE240',
  'flag8thDown': '\uE241',
  'flag16thUp': '\uE242',
  'flag16thDown': '\uE243',
  'restWhole': '\uE4E3',
  'restHalf': '\uE4E4',
  'restQuarter': '\uE4E5',
  'rest8th': '\uE4E6',
  'rest16th': '\uE4E7',
  'accidentalFlat': '\uE260',
  'accidentalNatural': '\uE261',
  'accidentalSharp': '\uE262',
  'accidentalDoubleSharp': '\uE263',
  'accidentalDoubleFlat': '\uE264',
  'augmentationDot': '\uE1E7',
  'timeSig0': '\uE080',
  'timeSig1': '\uE081',
  'timeSig2': '\uE082',
  'timeSig3': '\uE083',
  'timeSig4': '\uE084',
  'timeSig5': '\uE085',
  'timeSig6': '\uE086',
  'timeSig7': '\uE087',
  'timeSig8': '\uE088',
  'timeSig9': '\uE089',
};

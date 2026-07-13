/// `bekern` → Humdrum `**kern` reconstruction.
///
/// The Sheet Music Transformer (SMT) optical-music-recognition model emits a
/// staff image as a flat sequence of **bekern** ("basic extended kern") tokens:
/// each `**kern` token is split into its sub-tokens (duration, dot, pitch,
/// accidental…), and the two-dimensional Humdrum layout is linearised with
/// three structural markers:
///
///   * `<s>` — a space: separates the notes of a chord within one spine cell;
///   * `<t>` — a tab: separates the spine columns (the staves of a system);
///   * `<b>` — a newline: separates Humdrum rows (records).
///
/// Reconstruction is the inverse of the model's tokeniser (SMT `parse_kern`):
/// concatenate the tokens with no separator, then expand the three markers.
/// This is exactly the decode the reference implementation performs when it
/// writes a predicted `.krn` file, so it reproduces the model's target format
/// byte-for-byte. Pure Dart.
library;

/// Special tokens the decoder emits but that carry no Humdrum content.
const _specials = {'<bos>', '<eos>', '<pad>', '<unk>'};

/// Converts a space-joined `bekern` token sequence (as returned by the SMT OMR
/// engine) into a Humdrum `**kern` document.
///
/// The engine hands back its vocabulary tokens joined by single spaces. The
/// sub-tokens of one `**kern` token are re-joined with nothing, and the
/// structural markers `<t>`/`<b>`/`<s>` become tab/newline/space, yielding the
/// original multi-spine `**kern` text.
String bekernToKern(String bekern) {
  final tokens = bekern
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !_specials.contains(t));
  final joined = tokens.join();
  return joined
      .replaceAll('<t>', '\t')
      .replaceAll('<b>', '\n')
      .replaceAll('<s>', ' ');
}

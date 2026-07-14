import 'package:crisp_notation_cli/omr.dart';
import 'package:test/test.dart';

void main() {
  test('the omr barrel exposes engine, parsers and helpers from one import',
      () {
    // Dialect detection + parsers (pure Dart — no native library needed).
    expect(omrDialectOf("c'2 a''8 r4"), OmrDialect.lilyNotes);
    final score = scoreFromLilyNotes("c'4 d'4 e'4");
    expect(score.measures.single.elements.length, 3);

    // Model registry + segmentation helpers are reachable.
    expect(omrModelRegistry.keys, contains('smt-grandstaff'));

    // The native engine and its exception type resolve through the barrel.
    expect(
      () => CrispEmbedOmrEngine.load('/no/such/model.gguf'),
      throwsA(isA<OmrEngineException>()),
    );
  });
}

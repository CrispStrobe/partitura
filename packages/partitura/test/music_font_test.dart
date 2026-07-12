import 'package:flutter_test/flutter_test.dart';
import 'package:partitura/partitura.dart';

import 'test_setup.dart';

void main() {
  setUpAll(setUpPartituraForTests);

  test('MusicFont.bravura is the default and carries its asset info', () {
    expect(MusicFont.bravura.family, 'Bravura');
    expect(MusicFont.bravura.package, 'partitura');
    expect(MusicFont.bravura.metadataAsset, contains('bravura_metadata.json'));
    expect(const PartituraTheme().musicFont, MusicFont.bravura);
  });

  test('MusicFont value equality', () {
    const same = MusicFont(
      family: 'Bravura',
      package: 'partitura',
      metadataAsset:
          'packages/partitura/assets/smufl/bravura_metadata.json',
    );
    expect(same, MusicFont.bravura);
    expect(
        const MusicFont(family: 'Petaluma', metadataAsset: 'p.json'),
        isNot(MusicFont.bravura));
  });

  test('MusicFonts caches metadata per font (Bravura preloaded for tests)', () {
    // setUpPartituraForTests registers Bravura's metadata.
    expect(MusicFonts.metadataOrNull(MusicFont.bravura), isNotNull);
    // Bravura is a thin wrapper over the same cache.
    expect(Bravura.metadataOrNull,
        same(MusicFonts.metadataOrNull(MusicFont.bravura)));
  });

  test('the theme carries a swappable music font', () {
    const jazz = MusicFont(
      family: 'Petaluma',
      package: 'my_app',
      metadataAsset: 'assets/petaluma_metadata.json',
    );
    final theme = const PartituraTheme().copyWith(musicFont: jazz);
    expect(theme.musicFont, jazz);
    expect(theme, isNot(const PartituraTheme()));
  });
}

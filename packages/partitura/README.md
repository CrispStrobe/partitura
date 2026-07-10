# partitura

Music notation rendering for Flutter with first-class interactivity —
staves, notes, chords, hit-testing, selection and drag. Builds on
[`partitura_core`](../partitura_core) and bundles the Bravura SMuFL font.

**Status: pre-release scaffold** — see the repository root for the
implementation contract (`HANDOVER.md` + `HANDOVER_PARTITURA.md`).

```dart
import 'package:partitura/partitura.dart';

// Scaffold seed API — renders an empty staff with a clef:
const StaffView(clef: Clef.bass, staffSpace: 14)
```

## License

Code: MIT. Bundled Bravura font: SIL OFL 1.1 (© Steinberg Media Technologies
GmbH), see `assets/fonts/OFL.txt`.

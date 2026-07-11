/// Music notation rendering for Flutter with first-class interactivity.
///
/// [StaffView] renders a `Score` (from `partitura_core`, re-exported here)
/// using the bundled Bravura SMuFL font; `InteractiveStaff` adds hit
/// testing, selection and drag. See HANDOVER.md at the repository root for
/// the full contract.
library;

export 'package:partitura_core/partitura_core.dart';

export 'src/interaction/interactive_staff.dart';
export 'src/interaction/staff_target.dart';
export 'src/rendering/bravura.dart';
export 'src/rendering/grand_staff_view.dart';
export 'src/rendering/smufl_glyphs.dart';
export 'src/rendering/staff_view.dart';
export 'src/rendering/theme.dart';

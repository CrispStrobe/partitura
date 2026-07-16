// Layout-engine benchmark and regression gate.
//
// **Run AOT** for production-representative numbers — a Flutter release build is
// AOT-compiled, and `dart run` (JIT) reports warmup cost that is 10–40x wrong
// (metadata parse reads 480ms under JIT, 11ms AOT):
//
//   dart compile exe benchmark/layout_benchmark.dart -o /tmp/lb && /tmp/lb
//
// It prints a table and then checks two things, exiting non-zero on failure:
//
//  1. **Scaling stays linear.** The *per-bar* cost at 800 bars vs 200 bars must
//     stay near 1.0 (an O(n^2) pass reads ~4.0). Per-bar is machine-independent,
//     both sizes are large enough to avoid small-size cache skew, and each point
//     is a min-of-reps, so the metric is stable even on a loaded machine.
//  2. **A generous absolute ceiling**, as a coarse backstop for a gross slowdown.
//
// Baseline (Apple silicon, AOT, 2026-07): ~130 us/bar, 800 bars ~= 93 ms,
// SmuflMetadata.fromJson ~= 11 ms. See docs/PERF.md.
import 'dart:convert';
import 'dart:io';

import 'package:crisp_notation_core/crisp_notation_core.dart';

/// Returns the **minimum** ms/call over [reps] measured passes. Min (not mean)
/// is the standard choice for microbenchmarks: noise only ever adds time, so the
/// fastest pass is the least-disturbed estimate of true cost. Taking the min
/// keeps the scaling ratio stable even when the machine is loaded — without it a
/// single pass that stalls during the 800-bar timing can spuriously trip the
/// gate (observed a 34x spike right after a heavy test run; clean it is ~8-11x).
double _bench(void Function() f,
    {int warmup = 20, required int iters, int reps = 5}) {
  for (var i = 0; i < warmup; i++) {
    f();
  }
  var best = double.infinity;
  for (var r = 0; r < reps; r++) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iters; i++) {
      f();
    }
    sw.stop();
    final ms = sw.elapsedMicroseconds / iters / 1000;
    if (ms < best) best = ms;
  }
  return best;
}

Score _score(int bars) => Score.simple(
      timeSignature: TimeSignature.fourFour,
      notes:
          List.generate(bars, (_) => 'c4:e d4:e e4:e f4:e g4:e a4:e b4:e c5:e')
              .join(' | '),
    );

void main() {
  final metaJson = File('../crisp_notation/assets/smufl/bravura_metadata.json')
      .readAsStringSync();
  final decoded = jsonDecode(metaJson) as Map<String, Object?>;

  final parseMs =
      _bench(() => SmuflMetadata.fromJson(decoded), warmup: 5, iters: 50);
  stdout.writeln(
      'SmuflMetadata.fromJson          ${parseMs.toStringAsFixed(2)} ms');

  final settings = LayoutSettings(metadata: SmuflMetadata.fromJson(decoded));
  const engine = LayoutEngine();

  final timings = <int, double>{};
  for (final bars in [1, 25, 100, 200, 400, 800]) {
    final score = _score(bars);
    final iters = bars >= 400 ? 30 : 100;
    final ms = _bench(() => engine.layout(score, settings), iters: iters);
    timings[bars] = ms;
    final notes = bars * 8;
    stdout.writeln('layout ${bars.toString().padLeft(3)} bars / '
        '${notes.toString().padLeft(4)} notes    '
        '${ms.toStringAsFixed(2).padLeft(7)} ms    '
        '${(notes / (ms / 1000) / 1000).toStringAsFixed(0).padLeft(4)}k notes/s');
  }

  // Gate 1 — linearity, as the ratio of *per-bar* cost at two large sizes.
  // per-bar = time / bars; for a linear engine it is constant, so the ratio is
  // ~1.0 regardless of machine speed. An O(n^2) pass makes per-bar grow with n,
  // so 800-vs-200 (4x the work) reads ~4x. Using 200 and 800 — both large —
  // avoids the small-size cache skew that made an 800/100 ratio swing 8-20x;
  // combined with min-of-reps timing the metric is stable under load.
  final perBar200 = timings[200]! / 200;
  final perBar800 = timings[800]! / 800;
  final ratio = perBar800 / perBar200;
  const maxRatio = 2.5; // linear ~1.0; an O(n^2) pass reads ~4.0.
  stdout.writeln('\nscaling: per-bar 800 / per-bar 200 = '
      '${ratio.toStringAsFixed(2)}x (linear ~= 1.0, ceiling $maxRatio)');

  // Gate 2 — coarse absolute backstop. Local AOT ~= 93 ms at 800 bars; a CI
  // runner is a few times slower, so 1500 ms leaves >10x headroom.
  const maxAbsMs = 1500.0;
  final abs800 = timings[800]!;

  var failed = false;
  if (ratio > maxRatio) {
    stderr.writeln('REGRESSION: layout scaling is superlinear '
        '(per-bar ratio ${ratio.toStringAsFixed(2)}x > $maxRatio) '
        '— likely an O(n^2) pass.');
    failed = true;
  }
  if (abs800 > maxAbsMs) {
    stderr.writeln('REGRESSION: 800-bar layout ${abs800.toStringAsFixed(0)} ms '
        '> ${maxAbsMs.toStringAsFixed(0)} ms ceiling.');
    failed = true;
  }
  if (failed) exit(1);
  stdout.writeln('OK — layout is linear and within budget.');
}

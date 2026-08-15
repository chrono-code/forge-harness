#!/usr/bin/env node
'use strict';
// postinstall_notice.js — one-line, stderr-only, CI-silent install notice.
//
// WHY: 16k+ npm downloads (measured live, 2026-08-15) vs 7 GitHub stars on the same day —
// people are using fh-gate and have no reason to ever see the GitHub repo, since `npx
// @chrono-meta/fh-gate` never surfaces it. This closes that gap at the one moment every
// installer passes through, without touching fh-gate.js's own stdout (that IS the CI
// contract per its own header comment — this notice must never risk polluting it).
//
// WHY stderr, not stdout: npm's own install-time output already goes to stderr by
// convention (npm's progress/warnings), and more importantly this keeps it structurally
// impossible for the notice to ever be mistaken for gate output — a script piping
// `npx @chrono-meta/fh-gate`'s stdout for FH_GATE_VERDICT: parsing never sees this line,
// even if this file were somehow invoked in the same process (it isn't — separate
// lifecycle script, separate process).
//
// WHY CI-silent: postinstall banners are a known source of npm-ecosystem noise complaints,
// and this package explicitly markets itself for CI use (CHEATSHEET.md §9.5). A line that
// reprints on every CI run install is exactly the annoyance that gets a package reported,
// not starred. Skip whenever a CI environment is plausible OR the operator opts out.
if (process.env.CI || process.env.FH_NO_BANNER || process.env.CONTINUOUS_INTEGRATION) {
  process.exit(0);
}
try {
  process.stderr.write(
    '\n⭐ forge-harness (fh-gate) — if this is useful, a star helps others find it:\n' +
    '   https://github.com/chrono-meta/forge-harness\n' +
    '   (set FH_NO_BANNER=1 to silence this message)\n\n'
  );
} catch (_) {
  // Never fail an install over a courtesy message.
}
process.exit(0);

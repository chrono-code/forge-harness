#!/usr/bin/env bash
# gate-block-setup.sh — builds the disposable repo the README demo records against.
# Everything the GIF shows is this script's real output; nothing is staged or faked.
# Usage: eval "$(bash docs/demo/gate-block-setup.sh)"   # prints `cd <tmpdir>`
set -euo pipefail
FH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
D=$(mktemp -d) || { echo "echo 'mktemp failed'; exit 1"; exit 1; }
cd "$D"
git init -q .
git config user.email demo@example.com
git config user.name dev
cp "$FH/templates/regression_guard.sh" .
mkdir -p plugins/acme/skills/deploy
cat > plugins/acme/skills/deploy/SKILL.md <<'MD'
---
name: deploy
description: Ships a build to production once the release checks pass.
---
# deploy

Runs the release pipeline and reports what shipped.

## Done When

| Condition | Check class |
|---|---|
| build artifact exists on the registry | mandatory-pass |
| smoke test green against staging | measured |
| rollback path named in the release note | judged |
MD
git add plugins regression_guard.sh
git commit -qm "add deploy skill"
# the "tidy-up": everything from `## Done When` onward is dropped
python3 - <<'PY'
import io
p='plugins/acme/skills/deploy/SKILL.md'
s=io.open(p).read()
io.open(p,'w').write(s.split('## Done When')[0].rstrip()+'\n')
PY
git add plugins/acme/skills/deploy/SKILL.md
echo "cd $D"

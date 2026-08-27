#!/usr/bin/env bash
# door2-menu-setup.sh — builds the fresh clone the ② door demo records against.
# Everything the GIF shows is a real Claude Code run in that clone; nothing is staged.
# Usage: eval "$(bash docs/demo/door2-menu-setup.sh)"   # prints `cd <dir>`
#
# Why a clone and not your working copy: the ② demo is about what a NEW install
# does, and a working copy has session files under tracks/ that flip the greeting
# to the returning-user menu.
set -euo pipefail
D=${1:-/tmp/fh-demo}
rm -rf "$D" && mkdir -p "$D"
git clone -q --depth 1 https://github.com/chrono-meta/forge-harness.git "$D/forge-harness"
# Pin a neutral statusline so a recording does not publish the recorder's hostname.
# This changes nothing about FH's behaviour — it only replaces the terminal's own status row.
cat > "$D/demo-settings.json" <<'JSON'
{ "statusLine": { "type": "command", "command": "echo forge-harness" } }
JSON
# The wizard sentinel is keyed by directory BASENAME, so a machine that has ever
# run /install-wizard in any folder named `forge-harness` will make this fresh
# clone report "setup is in place". Move it aside for the take, and put it back.
if [ -f "$HOME/.cc_sentinels/forge-harness_wizard_done" ]; then
  mv "$HOME/.cc_sentinels/forge-harness_wizard_done" "$D/_sentinel.bak"
  echo "# sentinel parked at $D/_sentinel.bak — restore it after recording" >&2
fi
echo "cd $D"

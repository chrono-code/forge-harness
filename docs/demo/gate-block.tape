# gate-block.tape — regenerate the README demo GIF:
#     brew install vhs && vhs docs/demo/gate-block.tape
#
# Every line below RUNS. The verdicts are the real output of
# templates/regression_guard.sh against a real git index — nothing is faked,
# and docs/demo/gate-block-setup.sh builds the repo it runs against.
Output docs/demo/gate-block.gif
Set Shell bash
Set FontSize 16
Set Width 1200
Set Height 700
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 18ms

Hide
Type 'eval "$(bash ~/projects/forge-harness/docs/demo/gate-block-setup.sh)" && clear' Enter
Sleep 3s
Show

Sleep 800ms
Type "# An agent tidied up a skill spec. The diff looks harmless:" Enter
Sleep 900ms
Type "git diff --cached --stat" Enter
Sleep 1600ms

Type "bash regression_guard.sh --staged" Enter
Sleep 3200ms

Type "# It didn't lose a typo. It lost the section that defines 'done'." Enter
Sleep 1800ms
Type "# Put that section back. Keep the rest of the cleanup:" Enter
Sleep 900ms
Type "git restore --source=HEAD --staged --worktree -- plugins/acme/skills/deploy/SKILL.md" Enter
Sleep 700ms
Type "sed -i '' 's/ and reports what shipped//' plugins/acme/skills/deploy/SKILL.md" Enter
Sleep 700ms
Type "git add plugins && bash regression_guard.sh --staged" Enter
Sleep 4s

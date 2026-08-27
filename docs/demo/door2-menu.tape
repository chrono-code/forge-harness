# door2-menu.tape — the ② door's first ten seconds, against a fresh clone.
#   brew install vhs && vhs docs/demo/door2-menu.tape
# Nothing is faked. This is `claude` in a clone made minutes earlier: no session
# files, no local overrides, no wizard sentinel. Hidden below are only the launch
# and the waiting — every character on screen is that run's real output.
# The statusline is pinned to a neutral one so the recording does not publish the
# maintainer's hostname; it changes nothing else.
Output door2-menu.gif
Set Shell bash
Set FontSize 16
Set Width 1200
Set Height 620
Set Padding 20
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms

Hide
Type 'cd /tmp/fh-demo/forge-harness && export PS1="$ " && export LANG=en_US.UTF-8 && clear' Enter
Sleep 2s
Type 'claude --settings /tmp/fh-demo/demo-settings.json' Enter
Sleep 38s
Show

Sleep 1200ms
Type 'hi'
Sleep 900ms
Enter
Sleep 3s

Hide
Sleep 22s
Show

Sleep 5s

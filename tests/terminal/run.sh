#!/bin/sh
# Programs on a terminal (docs/plans/repl.md, M1 and D23): each SCRIPT.script
# of tests/terminal is run by tests/terminal/term.py, which starts a program
# in a tmux pane, types at it and waits for the screen to show what it must.
#   tests/terminal/run.sh [--windows] [FILTER]
# A script names the program it starts with @REPL@ (bin/rune-repl's world
# on bin/runevm) or @KEYS@ (tests/terminal/keys.sml, a probe of
# RuneTerminal), and its expected screens with @DIR@ (tests/terminal).
# With --windows, the scripts whose first line is `# windows` run again on
# bin/runevm.exe, staged with the REPL's image and the probe in the directory of Windows
# that tests/windows-dir.sh names: WSL interop gives a program started in a
# pane a console of the pane's size, so the same script drives it.
# Without tmux the scripts are skipped, and say so (make doctor --scope
# terminal).
set -u
# The screens compared must not depend on colour chosen from outside
# (docs/diagnostics.md).
unset FORCE_COLOR CLICOLOR_FORCE NO_COLOR CLICOLOR RUNE_COLORS
cd "$(dirname "$0")/../.."
windows=0
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --windows) windows=1; shift ;;
    *) filter=$1; shift ;;
  esac
done
if ! command -v tmux > /dev/null 2>&1; then
  echo "terminal: skipped, no tmux (make doctor --scope terminal)"
  exit 0
fi
out=tests/out/terminal
mkdir -p "$out"
heap="--heap-size 67108864"
# the probe of RuneTerminal; a small stack, so that its fatal error comes soon
if ! bin/rune tests/terminal/keys.sml -o "$out/keys.rbc"; then
  echo "FAIL terminal: tests/terminal/keys.sml does not compile"
  exit 1
fi
probe="--stack-size 1048576"
if [ $windows = 1 ]; then
  if ! windir=$(sh tests/windows-dir.sh); then
    echo "terminal: no Windows to run on (tests/windows-dir.sh)" >&2
    exit 1
  fi
  stage=$windir/terminal
  mkdir -p "$stage"
  cp bin/runevm.exe bin/rune-repl.img "$out/keys.rbc" "$stage/"
  for dll in bin/*.dll; do [ -f "$dll" ] && cp "$dll" "$stage/"; done
  repl="sh -c 'cd $stage && ./runevm.exe $heap --restore rune-repl.img --'"
  keys="sh -c 'cd $stage && ./runevm.exe $probe keys.rbc'"
  out=$out/windows
  mkdir -p "$out"
else
  repl="bin/runevm $heap --restore bin/rune-repl.img --"
  keys="bin/runevm $probe $out/keys.rbc"
fi
pass=0
fail=0
for s in tests/terminal/*.script; do
  name=$(basename "$s" .script)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  if [ $windows = 1 ] && [ "$(head -1 "$s")" != "# windows" ]; then continue; fi
  if python3 tests/terminal/term.py "$s" "REPL=$repl" "KEYS=$keys" DIR=tests/terminal > "$out/$name.log" 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL terminal.$name (see $out/$name.log)"
    fail=$((fail + 1))
  fi
done
echo "terminal$([ $windows = 1 ] && echo ' (Windows)'): passed $pass, failed $fail"
[ $fail = 0 ]

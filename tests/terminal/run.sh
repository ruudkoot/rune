#!/bin/sh
# Programs on a terminal (docs/plans/repl.md, M1 and D23): each SCRIPT.script
# of tests/terminal is run by tests/terminal/term.py, which starts a program
# in a tmux pane, types at it and waits for the screen to show what it must.
#   tests/terminal/run.sh [--windows] [FILTER]
# A script names the program it starts with @REPL@ (bin/rune-repl's world
# on bin/runevm), @KEYS@ (tests/terminal/keys.sml, a probe of
# Terminal) or @READLINE@ (examples/readline.sml, lib/terminal's
# editor), and its expected screens with @DIR@ (tests/terminal).
# With --windows, the scripts whose first line is `# windows` run again on
# bin/runevm.exe, staged with the REPL's image and the probe in the directory of Windows
# that tests/windows-dir.sh names: WSL interop gives a program started in a
# pane a console of the pane's size, so the same script drives it.
# Without tmux the scripts are skipped, and say so (make doctor --scope
# terminal).
set -u
# The screens compared must not depend on colour chosen from outside
# (docs/diagnostics.md): the theme is auto's 16 colours wherever the scripts
# run -- a terminal of 256 colours would make it wide, which a script asks
# for itself (repl-colours) -- on Windows too (WSLENV, below).
unset FORCE_COLOR CLICOLOR_FORCE NO_COLOR CLICOLOR
RUNE_COLORS=auto
export RUNE_COLORS
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
# the probe of Terminal; a small stack, so that its fatal error comes soon
if ! bin/rune tests/terminal/keys.sml -o "$out/keys.rbc"; then
  echo "FAIL terminal: tests/terminal/keys.sml does not compile"
  exit 1
fi
# lib/terminal's editor, as a program uses it
if ! bin/rune --library terminal examples/readline.sml -o "$out/readline.rbc"; then
  echo "FAIL terminal: examples/readline.sml does not compile"
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
  cp bin/runevm.exe bin/rune-repl.img bin/rune-repl.cmd "$out/keys.rbc" "$out/readline.rbc" "$stage/"
  for dll in bin/*.dll; do [ -f "$dll" ] && cp "$dll" "$stage/"; done
  repl="sh -c 'cd $stage && ./runevm.exe $heap --restore rune-repl.img --'"
  keys="sh -c 'cd $stage && ./runevm.exe $probe keys.rbc'"
  readline="sh -c 'cd $stage && ./runevm.exe readline.rbc'"
  out=$out/windows
  mkdir -p "$out"
else
  repl="bin/runevm $heap --restore bin/rune-repl.img --"
  keys="bin/runevm $probe $out/keys.rbc"
  readline="bin/runevm $out/readline.rbc"
fi
# Each script's programs keep their history and find their init file in a
# directory of the script's own, empty when it starts, and never the user's;
# a program of Windows sees the variables through WSLENV, its paths
# translated (/p).
XDG_STATE_HOME=$PWD/$out/state
XDG_CONFIG_HOME=$PWD/$out/config
export XDG_STATE_HOME XDG_CONFIG_HOME
case ":${WSLENV:-}:" in *:XDG_STATE_HOME/p:*) ;; *) WSLENV="XDG_STATE_HOME/p:XDG_CONFIG_HOME/p:RUNE_COLORS${WSLENV:+:$WSLENV}"; export WSLENV ;; esac
# the version the REPL's banner says (scripts/gen-version.sh: a tag or a
# hash), which the screens write @VERSION@
version=$(sed -n 's/^ *val version = "\(.*\)"$/\1/p' build/config.sml)
pass=0
fail=0
for s in tests/terminal/*.script; do
  name=$(basename "$s" .script)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  if [ $windows = 1 ] && [ "$(head -1 "$s")" != "# windows" ]; then continue; fi
  rm -rf "${XDG_STATE_HOME:?}" "${XDG_CONFIG_HOME:?}"
  mkdir -p "$XDG_STATE_HOME" "$XDG_CONFIG_HOME"
  if python3 tests/terminal/term.py "$s" "REPL=$repl" "KEYS=$keys" "READLINE=$readline" "VERSION=$version" DIR=tests/terminal > "$out/$name.log" 2>&1; then
    pass=$((pass + 1))
  else
    echo "FAIL terminal.$name (see $out/$name.log)"
    fail=$((fail + 1))
  fi
done
# rune-repl.cmd, the REPL started from Windows' command prompt
if [ $windows = 1 ] && [ -z "$filter" ]; then
  got=$(cd "$stage" && cmd.exe /c rune-repl.cmd --no-init -e "1 + 1;" 2>&1 | tr -d '\r')
  if [ "$got" = "val it = 2 : int" ]; then
    pass=$((pass + 1))
  else
    echo "FAIL terminal.rune-repl.cmd: $got"
    fail=$((fail + 1))
  fi
fi
# the bytes a terminal is given that tmux does not show: each SCRIPT.pty is
# read by tests/terminal/ptyraw.py, the REPL on a pty that says it is VS
# Code's terminal (Linux only)
if [ $windows = 0 ]; then
  for p in tests/terminal/*.pty; do
    name=$(basename "$p" .pty)
    case "$name" in *"$filter"*) ;; *) continue ;; esac
    rm -rf "${XDG_STATE_HOME:?}" "${XDG_CONFIG_HOME:?}"
    mkdir -p "$XDG_STATE_HOME" "$XDG_CONFIG_HOME"
    # shellcheck disable=SC2086
    if python3 tests/terminal/ptyraw.py 80 24 "$p" -- env TERM=xterm-256color TERM_PROGRAM=vscode $repl > "$out/$name.log" 2>&1; then
      pass=$((pass + 1))
    else
      echo "FAIL terminal.$name (see $out/$name.log)"
      fail=$((fail + 1))
    fi
  done
fi
echo "terminal$([ $windows = 1 ] && echo ' (Windows)'): passed $pass, failed $fail"
[ $fail = 0 ]

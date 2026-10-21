#!/bin/sh
# MLton's sources, made ready for Rune to compile (docs/performance.md,
# *Measuring*; docs/plans/performance.md, E5):
#   scripts/setup-mlton.sh DIR [REPOSITORY]
# DIR becomes a checkout of MLton at 5fe943391, the merge of its pull request
# #660, with which `make rune-mlton` builds MLton with Rune: cloned from
# REPOSITORY (https://github.com/MLton/mlton.git unless given) where DIR does
# not exist yet, and checked to be at that commit where it does. Then MLton's
# own `make -C mlton rune-mlton RUNE=true` -- RUNE=true compiles nothing --
# writes DIR/mlton/mlton-rune.txt, the 606 files of MLton's compiler in the
# order Rune compiles them, and the sources the build generates (the front
# end's lexers and grammars, control/version.sml, pre-mlton.sml). It needs
# MLton itself, from the hosts (`make hosts`; MLTON= overrides). Then
#   bin/rune-measure perf-units --mlton DIR          (or MLTON_SOURCES=DIR)
#   bin/rune-measure gc-eval --mlton-compile ...      (MLTON_SOURCES=DIR)
# compile it: from DIR/mlton, `rune --type-work=1000000000 $(cat
# mlton-rune.txt)`, some 198,000 lines.
set -eu
[ $# -ge 1 ] && [ $# -le 2 ] || { echo "usage: scripts/setup-mlton.sh DIR [REPOSITORY]" >&2; exit 2; }
dir=$1
repo=${2:-https://github.com/MLton/mlton.git}
commit=5fe943391e539a502699327a6266b6e8e97939e1
mlton=${MLTON:-${RUNE_HOSTS:-$HOME/.local/rune-hosts}/mlton/bin/mlton}
[ -x "$mlton" ] || { echo "setup-mlton: no MLton at $mlton (make hosts, or MLTON=)" >&2; exit 2; }
if [ ! -e "$dir" ]; then
  git -c advice.detachedHead=false clone --quiet "$repo" "$dir"
  git -c advice.detachedHead=false -C "$dir" checkout --quiet "$commit"
fi
at=$(git -C "$dir" rev-parse HEAD 2> /dev/null) || { echo "setup-mlton: $dir is not a git checkout" >&2; exit 2; }
[ "$at" = "$commit" ] || { echo "setup-mlton: $dir is at $at, not at $commit (git -C $dir checkout $commit)" >&2; exit 2; }
PATH=$(dirname "$mlton"):$PATH make -C "$dir/mlton" rune-mlton RUNE=true > "$dir/mlton/setup-mlton.log" 2>&1 ||
  { tail -20 "$dir/mlton/setup-mlton.log" >&2; exit 1; }
n=$(wc -l < "$dir/mlton/mlton-rune.txt")
[ "$n" = 606 ] || { echo "setup-mlton: $dir/mlton/mlton-rune.txt has $n files, not 606" >&2; exit 1; }
echo "setup-mlton: $dir/mlton/mlton-rune.txt lists MLton's 606 files; MLTON_SOURCES=$(cd "$dir" && pwd)"

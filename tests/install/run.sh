#!/bin/sh
# make install (scripts/install.sh, docs/building.md, Installing) staged
# with --destdir under another prefix and checked: every file the MANIFEST
# of each library names, a subdirectory's too, and the man pages with the
# version; the installed programs run from where they landed -- rune with
# the register and the stack VM, through the frozen Basis and with a
# library, runeopt, runedoc, the REPL, its debug adapter and the Jupyter
# kernel's spec -- none of them pointing back into the tree; and an
# uninstall with the same options leaves no file behind. Once for the
# bytecode compiler and once for each --host NAME.
#   tests/install/run.sh [--host NAME]...
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
hosts=""
while [ $# -gt 0 ]; do
  case "$1" in
    --host) hosts="$hosts $2"; shift ;;
    *) echo "usage: tests/install/run.sh [--host NAME]..." >&2; exit 2 ;;
  esac
  shift
done
out=$root/tests/out/install
[ -d "$out" ] && chmod -R u+w "$out"   # an installed Basis cache is read-only
rm -rf "$out"
mkdir -p "$out"
pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { echo "FAIL install.$name: $*"; fail=$((fail + 1)); }
version=$(sed -n 's/^#define RUNE_VERSION "\(.*\)"$/\1/p' runtime/version.h)

printf 'val () = print "hello\\n"\n' > "$out/hello.sml"
# Int8Arb is in sized/int8.sml of lib/test/property/basis
printf 'val _ = Int8Arb.arb\nval () = print "property\\n"\n' > "$out/property.sml"
dapinit='{"seq":1,"type":"request","command":"initialize","arguments":{"adapterID":"rune"}}'

# prints NAME WANT CMD...: CMD, run in the work directory, prints WANT
prints() {
  check=$1 want=$2; shift 2
  got=$(cd "$work" && "$@" 2> "$work/$check.err")
  if [ "$got" = "$want" ]; then ok
  else bad "$check printed [$got], wanted [$want]: $(head -1 "$work/$check.err")"; fi
}

# installed NAME [--host H]: install into a stage of its own and check it
installed() {
  name=$1; shift
  stage=$out/$name
  prefix=/opt/rune
  bin=$stage$prefix/bin
  lib=$stage$prefix/lib/rune
  work=$out/$name.work
  mkdir -p "$work"
  cp "$out/hello.sml" "$out/property.sml" "$work/"
  if ! sh scripts/install.sh --destdir "$stage" --prefix "$prefix" "$@" > "$out/$name.log" 2>&1; then
    bad "install.sh failed: $(tail -1 "$out/$name.log")"; return
  fi
  ok

  # every library: its MANIFEST, the files it names and the overview
  for manifest in $(cd lib && find . -name MANIFEST | sort); do
    l=$(dirname "$manifest" | sed 's|^\./||')
    missing=""
    # the first column of a line is the file, as install.sh reads it
    files=$(while IFS='|' read -r f _; do
              f=$(echo $f)
              case "$f" in ""|\#*) ;; *) echo "$f" ;; esac
            done < "lib/$l/MANIFEST")
    for f in MANIFEST $files README.md; do
      [ "$f" = README.md ] && [ ! -e "lib/$l/$f" ] && continue
      cmp -s "lib/$l/$f" "$lib/$l/$f" || missing="$missing $f"
    done
    if [ -z "$missing" ]; then ok; else bad "lib/$l not installed as it is:$missing"; fi
  done

  # the manual pages, each with the version bin/ was built as
  for p in rune runevm runedoc runeopt; do
    if head -1 "$stage$prefix/share/man/man1/$p.1" 2> /dev/null | grep -qF "\"$p $version\""; then ok
    else bad "share/man/man1/$p.1 does not name version $version"; fi
  done

  # the wrappers find what they run beside themselves, not in the tree
  for w in "$bin"/*; do
    [ "$(head -c 2 "$w")" = '#!' ] || continue
    if grep -qF "$root" "$w"; then bad "${w##*/} names the tree $root"; else ok; fi
  done

  prints rune hello sh -c "'$bin/rune' hello.sml -o hello.rbc && '$bin/runevm' hello.rbc"
  prints units hello sh -c "'$bin/rune' --units hello.sml -o units.rbc && '$bin/runevm' units.rbc"
  prints stack hello sh -c "'$bin/rune' --target=stack hello.sml -o stack.rbc && '$bin/runevm-stack' stack.rbc"
  prints library property sh -c "'$bin/rune' --library test/property/basis property.sml && '$bin/runevm' property.rbc"
  prints runeopt hello sh -c "'$bin/runeopt' stack.rbc -o hello-native && ./hello-native"
  prints runedoc ok sh -c "'$bin/runedoc' --library json --out doc > /dev/null && test -s doc/README.md && echo ok"
  prints repl '- val x = 42 : int' sh -c "echo 'val x = 1 + 41;' | '$bin/rune-repl' | grep 'val x'"
  prints rune-i '- val x = 42 : int' sh -c "echo 'val x = 1 + 41;' | '$bin/rune' -i | grep 'val x'"
  prints dap '"success":true' sh -c "printf 'Content-Length: %d\r\n\r\n%s' ${#dapinit} '$dapinit' | '$bin/rune-repl' --dap | grep -o '\"success\":true'"
  # the kernel's spec names the installed VM, program and image
  if "$bin/rune-kernel" --install --prefix "$work/jupyter" > "$work/kernel.out" 2>&1; then
    spec=$work/jupyter/share/jupyter/kernels/rune/kernel.json
    paths=$(sed -n 's/^ *"\(\/[^"]*\)",*$/\1/p' "$spec")
    # the VM twice, the program and the image
    [ $(echo "$paths" | wc -l) = 4 ] || bad "kernel.json names [$(echo $paths)], not the VM, program and image"
    for f in $paths; do
      case "$f" in
        "$stage"/*) if [ -e "$f" ]; then ok; else bad "kernel.json names $f, which is not there"; fi ;;
        *) bad "kernel.json names $f, outside the install" ;;
      esac
    done
  else bad "rune-kernel --install: $(head -1 "$work/kernel.out")"; fi

  # an uninstall with the same options takes every file away
  if sh scripts/install.sh --destdir "$stage" --prefix "$prefix" "$@" --uninstall > "$out/$name.uninstall.log" 2>&1; then
    left=$(find "$stage" ! -type d | sed "s|^$stage||")
    if [ -z "$left" ]; then ok; else bad "uninstall left$(echo $left | head -c 300)"; fi
  else bad "install.sh --uninstall failed: $(tail -1 "$out/$name.uninstall.log")"; fi
}

for f in bin/rune-dap bin/rune-kernel; do
  [ -e "$f" ] || { echo "FAIL install: $f is not built (make dap kernel)"; exit 1; }
done
installed rbc
for h in $hosts; do installed "$h" --host "$h"; done

echo "install: passed $pass, failed $fail"
[ $fail = 0 ]

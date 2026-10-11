#!/bin/sh
# Build files (docs/build.md; the incremental roadmap's M10): a build file's
# units compiled in the bases it says -- a list, local, a library's exports,
# a group put in order, a build file used twice and elaborated once, an
# annotation, a path variable, a virtual module -- and --build-list; what
# each build prints, or the error it is refused with.
#   tests/buildfile/run.sh [--rune BIN]
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
rune=bin/rune
[ "${1:-}" = --rune ] && rune=$2
case $rune in /*) ;; *) rune=$root/$rune ;; esac
vm=$(dirname "$rune")/runevm
out=$root/tests/out/build
rm -rf "$out"
mkdir -p "$out"
cd "$out" || exit 1
pass=0
fail=0
put() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" > "$1"; }
# builds NAME WANT: the build file NAME.build built and run prints WANT
builds() {
  if "$rune" --build "$1.build" --no-cache -o "$1.rbc" > "$1.cout" 2> "$1.cerr"; then
    got=$("$vm" "$1.rbc" 2>&1)
    if [ "$got" = "$2" ]; then pass=$((pass + 1)); else echo "FAIL build.$1: printed [$got], wanted [$2]"; fail=$((fail + 1)); fi
  else echo "FAIL build.$1: refused: $(head -1 "$1.cerr")"; fail=$((fail + 1)); fi
}
# refused NAME TEXT: the build file NAME.build refused, with TEXT in the error
refused() {
  if "$rune" --build "$1.build" --no-cache -o "$1.rbc" > "$1.cout" 2> "$1.cerr"; then
    echo "FAIL build.$1: accepted"; fail=$((fail + 1))
  elif grep -q "$2" "$1.cerr"; then pass=$((pass + 1))
  else echo "FAIL build.$1: refused for another reason: $(head -1 "$1.cerr")"; fail=$((fail + 1)); fi
}

put a.sml 'structure A = struct val x = 40 end'
put b.sml 'structure B = struct val y = A.x + 2 end'
put main.sml 'val () = print (Int.toString B.y ^ "\n")'
put uses-a.sml 'val () = print (Int.toString A.x ^ "\n")'

# a list: what --units makes of the same files
put list.build 'a.sml b.sml main.sml'
builds list 42

# local: what follows sees the second part, not the first
put local.build 'local a.sml in b.sml end main.sml'
builds local 42
put local-hidden.build 'local a.sml in b.sml end uses-a.sml'
refused local-hidden 'unbound variable or constructor: A.x'

# a library: what follows sees its exports only
put library.build 'library (structure B) = a.sml b.sml end main.sml'
builds library 42
put library-hidden.build 'library (structure B) = a.sml b.sml end uses-a.sml'
refused library-hidden 'unbound variable or constructor: A.x'

# a group: its files in the order their modules give
put group.build 'group main-mod.sml b.sml a.sml end main.sml'
put main-mod.sml 'structure M = struct val z = B.y end'
builds group 42

# a build file used twice: elaborated once, its top level run once
put counted.sml 'structure C = struct val () = print "once\n" val c = 1 end'
put lib/counted.build 'counted.sml'
put use-twice.build 'use lib/counted.build use lib/counted.build use-c.sml'
cp counted.sml lib/counted.sml
put use-c.sml 'val () = print (Int.toString C.c ^ "\n")'
builds use-twice "once
1"

# an annotation: _prim only where allowPrim says
put prim.sml 'val ok = _prim "rt_version" : unit -> string'
put prim.build 'prim.sml main.sml'
refused prim '_prim'
put prim-allowed.build 'annotate "allowPrim" in prim.sml end a.sml b.sml main.sml'
builds prim-allowed 42

# a path variable
mkdir -p vendor && cp a.sml b.sml vendor/
put vars.build '$(VENDOR)/a.sml $(VENDOR)/b.sml main.sml'
if "$rune" --build vars.build --path VENDOR=vendor --no-cache -o vars.rbc 2> vars.cerr && [ "$("$vm" vars.rbc)" = 42 ]
then pass=$((pass + 1)); else echo "FAIL build.vars: $(head -1 vars.cerr)"; fail=$((fail + 1)); fi
refused vars 'no path variable VENDOR'

# --build-list: the files, in the order compiled
got=$("$rune" --build-list group.build | tr '\n' ' ')
[ "$got" = "a.sml b.sml main-mod.sml main.sml " ] && pass=$((pass + 1)) || { echo "FAIL build.list: [$got]"; fail=$((fail + 1)); }

# a virtual module (examples/virtual/bigint): either implementation, the
# units compiled against it served from the cache when the other is
# chosen, a whole program, none and two implementations
mkdir -p bigint && cp "$root"/examples/virtual/bigint/* bigint/
fact30='265252859812191058636308480000000
~2
16158687986375067893760000
equal'
builds bigint/intinf "$fact30"
builds bigint/digits "$fact30"
"$rune" --build bigint/intinf.build --cache-dir vcache -o vcache1.rbc 2> /dev/null
"$rune" --build bigint/digits.build --cache-dir vcache --explain-rebuild -o vcache2.rbc 2> vcache2.err
got=$(sed -n 's|^rune: compiled bigint/\([^:]*\):.*|\1|p' vcache2.err | tr '\n' ' ')
[ "$got" = "digits.sml " ] && [ "$("$vm" vcache2.rbc)" = "$fact30" ] && pass=$((pass + 1)) ||
  { echo "FAIL build.virtual-cache: compiled [$got], wanted [digits.sml ]"; fail=$((fail + 1)); }
if "$rune" --build bigint/digits.build --whole -o vwhole.rbc 2> vwhole.err && [ "$("$vm" vwhole.rbc)" = "$fact30" ]
then pass=$((pass + 1)); else echo "FAIL build.virtual-whole: $(head -1 vwhole.err)"; fail=$((fail + 1)); fi
put bigint/none.build 'bigint_sig.sml bigint.sml main.sml'
"$rune" --build bigint/none.build --no-cache -o vnone.rbc 2> vnone.err
"$vm" vnone.rbc > vnone.out 2>&1 && { echo "FAIL build.virtual-none: ran"; fail=$((fail + 1)); } ||
  { grep -q 'virtual module BigInt has no implementation' vnone.out && pass=$((pass + 1)) ||
    { echo "FAIL build.virtual-none: $(head -1 vnone.out)"; fail=$((fail + 1)); }; }
put bigint/two.build 'bigint_sig.sml implements BigInt = intinf.sml end implements BigInt = digits.sml end bigint.sml main.sml'
refused bigint/two 'two implementations'

# errors: a word that is not a declaration, a build file that uses itself
put bad.build 'local a.sml'
refused bad 'unexpected end of the file'
put self.build 'use self.build'
refused self 'uses itself'

echo "build: passed $pass, failed $fail"
[ $fail = 0 ]

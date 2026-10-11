#!/bin/sh
# The dependency graph (docs/units.md, The graph; the incremental roadmap's
# M8): rune --deps orders files by the modules they declare and use, refuses
# a cycle, a name declared twice and a file that breaks the discipline --
# naming it, with the line -- and gives the graph as DOT; rune -I DIR compiles
# an entry point and before it the files it needs, and only those.
#   tests/deps/run.sh [--rune BIN]
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
rune=bin/rune
[ "${1:-}" = --rune ] && rune=$2
case $rune in /*) ;; *) rune=$root/$rune ;; esac
vm=$(dirname "$rune")/runevm
out=$root/tests/out/deps
rm -rf "$out"
mkdir -p "$out"
pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { echo "FAIL deps.$1"; fail=$((fail + 1)); }
put() { mkdir -p "$(dirname "$out/$1")"; printf '%s\n' "$2" > "$out/$1"; }

# an order, from files given in the reverse of it
put order/a.sml 'structure A = struct val x = 1 end'
put order/b.sml 'structure B = struct val y = A.x + 1 end'
put order/c.sml 'signature C = sig val z : int end  functor F (X : C) = struct val w = B.y + X.z end'
got=$(cd "$out/order" && "$rune" --deps c.sml b.sml a.sml 2>&1 | tr '\n' ' ')
[ "$got" = "a.sml b.sml c.sml " ] && ok || bad "order: [$got]"
# the graph as DOT: c.sml needs b.sml, which needs a.sml
dot=$(cd "$out/order" && "$rune" --deps-dot c.sml b.sml a.sml)
echo "$dot" | grep -q '"c.sml" -> "b.sml"' && echo "$dot" | grep -q '"b.sml" -> "a.sml"' && ok || bad "dot"

# a cycle
put cycle/x.sml 'structure X = struct val a = Y.b end'
put cycle/y.sml 'structure Y = struct val b = 1 val c = X.a end'
(cd "$out/cycle" && "$rune" --deps x.sml y.sml) > "$out/cycle.err" 2>&1 && bad "cycle: accepted" ||
  { grep -q 'a cycle: x.sml -> y.sml -> x.sml' "$out/cycle.err" && ok || bad "cycle: $(cat "$out/cycle.err")"; }

# a name declared twice
put twice/p.sml 'structure P = struct end'
put twice/q.sml 'structure P = struct val again = 1 end'
(cd "$out/twice" && "$rune" --deps p.sml q.sml) > "$out/twice.err" 2>&1 && bad "twice: accepted" ||
  { grep -q 'structure P is declared by p.sml and by q.sml' "$out/twice.err" && ok || bad "twice: $(cat "$out/twice.err")"; }

# the discipline: a top-level value, named with its line
put broken/m.sml 'structure M = struct end
val top = 1'
(cd "$out/broken" && "$rune" --deps m.sml) > "$out/broken.err" 2>&1 && bad "discipline: accepted" ||
  { grep -q 'm.sml:2:1: error: a file of a group declares modules and type abbreviations only, and this is a value' "$out/broken.err" && ok ||
    bad "discipline: $(cat "$out/broken.err")"; }

# an entry point: main.sml names B; lib/ has A and B, which it needs, U,
# which it does not, and z.sml, which breaks the discipline
put entry/main.sml 'val () = print (Int.toString B.y ^ "\n")'
put entry/lib/a.sml 'structure A = struct val x = 40 end'
put entry/lib/b.sml 'structure B = struct val y = A.x + 2 end'
put entry/lib/u.sml 'structure U = struct val nothing = () end'
put entry/lib/z.sml 'structure Z = struct end
val zero = 0'
(cd "$out/entry" && "$rune" --units --no-cache --explain-rebuild -I lib main.sml -o p.rbc) > "$out/entry.out" 2> "$out/entry.err"
compiled=$(grep '^rune: compiled [^/]*lib/\|^rune: compiled main' "$out/entry.err" | sed 's|^rune: compiled \([^:]*\):.*|\1|' | tr '\n' ' ')
[ "$compiled" = "lib/a.sml lib/b.sml main.sml " ] && ok || bad "entry: compiled [$compiled] ($out/entry.err)"
[ "$("$vm" "$out/entry/p.rbc")" = 42 ] && ok || bad "entry: the program"
# a module only a file that breaks the discipline declares: said
put entry/needs-z.sml 'structure Use = Z'
(cd "$out/entry" && "$rune" -I lib needs-z.sml -o z.rbc) > "$out/needs-z.out" 2> "$out/needs-z.err"
grep -q 'lib/z.sml declares a module needs-z.sml names, and breaks the discipline' "$out/needs-z.err" && ok ||
  bad "entry: the file that breaks the discipline ($out/needs-z.err)"

echo "deps: passed $pass, failed $fail"
[ $fail = 0 ]

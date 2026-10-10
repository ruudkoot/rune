#!/bin/sh
# The cache's scenarios (tests/incremental/SCENARIOS.md; docs/units.md, The
# cache): each starts from a copy of tests/incremental/project and an empty
# cache, does something to them, builds in units through the cache, and
# wants two things: that exactly the files of the project it names were
# compiled (--explain-rebuild; the Basis Library's units are not counted),
# and that the program is the same bytes as one built with --no-cache. A
# unit's usages are the names it looked up and the units that bound them
# (docs/units.md, The cache); where fingerprints per entry would want fewer
# units compiled, the scenario says so.
#   tests/incremental/run.sh [--rune BIN] [FILTER]
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
rune=bin/rune
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    -*) echo "usage: tests/incremental/run.sh [--rune BIN] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
case $rune in /*) ;; *) rune=$root/$rune ;; esac
# the REPL beside the compiler (S40)
repl=$(dirname "$rune")/rune-repl
out=$root/tests/out/incremental
mkdir -p "$out"
pass=0
fail=0

# fresh S: the project copied into $out/S, its cache empty
fresh() {
  s=$1
  dir=$out/$s
  rm -rf "$dir"
  mkdir -p "$dir"
  cp "$root"/tests/incremental/project/*.sml "$root"/tests/incremental/project/files "$dir"/
}
# build [FLAGS]: the project built through the cache into p.rbc; $compiled
# the project's files compiled, in order, and $status the compile's
build() {
  flags="$*"
  # shellcheck disable=SC2046,SC2086
  (cd "$dir" && "$rune" --units --cache-dir cache --explain-rebuild $flags $(cat files) -o p.rbc) > "$dir/build.out" 2> "$dir/build.err"
  status=$?
  compiled=$(sed -n 's|^rune: compiled \([^/:]*\.sml\):.*|\1|p' "$dir/build.err" | tr '\n' ' ' | sed 's/ $//')
}
# want WHAT: the last build compiled exactly WHAT (files, in order) and, where
# it compiled, is the bytes of a build without the cache
want() {
  if [ "$compiled" != "$1" ]; then
    echo "FAIL incremental.$s: compiled [$compiled], wanted [$1] ($dir/build.err)"; fail=$((fail + 1)); return
  fi
  if [ "$status" = 0 ]; then
    # shellcheck disable=SC2046,SC2086
    (cd "$dir" && "$rune" --units --no-cache $flags $(cat files) -o nocache.rbc) > /dev/null 2>&1
    if ! cmp -s "$dir/p.rbc" "$dir/nocache.rbc"; then
      echo "FAIL incremental.$s: the program differs from one built without the cache (cmp $dir/p.rbc $dir/nocache.rbc)"
      fail=$((fail + 1)); return
    fi
  fi
  pass=$((pass + 1))
}
# fails: the last build failed, and wrote no entry for what failed
fails() {
  if [ "$status" = 0 ]; then echo "FAIL incremental.$s: the build did not fail"; fail=$((fail + 1)); return; fi
  pass=$((pass + 1))
}
edit() { f=$dir/$1; shift; sed "$@" "$f" > "$f.new" && mv "$f.new" "$f"; }
all="a.sml b.sml c.sml d.sml main.sml"
run() { case "$1" in *"$filter"*) return 0 ;; esac; return 1; }

# S1, cold then warm: the second compiles nothing, and is the same bytes
if run S1; then
  fresh S1; build; want "$all"
  cp "$dir/p.rbc" "$dir/cold.rbc"
  build; want ""
  cmp -s "$dir/cold.rbc" "$dir/p.rbc" || { echo "FAIL incremental.S1: warm differs from cold"; fail=$((fail + 1)); }
fi

# S2, a body: a.sml's function changed, not its type; only a.sml (the cut-off)
if run S2; then
  fresh S2; build
  edit a.sml 's/fun area (Square n) = n \* n/fun area (Square n) = n * n * 1/'
  build; want "a.sml"
fi

# S3, a used type: a constructor added to a.sml's datatype; a.sml and every
# unit that used a name a.sml binds -- c.sml too, for SHAPE, which did not
# change (fingerprints per entry would leave it) -- and those that used
# theirs
if run S3; then
  fresh S3; build
  edit a.sml -e 's/datatype shape = Square of int | Rect of int \* int/datatype shape = Square of int | Rect of int * int | Line of int/' \
    -e 's/    | area (Rect (w, h)) = w \* h/    | area (Rect (w, h)) = w * h\n    | area (Line _) = 0/'
  build; want "$all"
fi

# S5, revert: S3's change undone finds the first entries
if run S5; then
  fresh S5; build
  cp "$dir/a.sml" "$dir/a.sml.orig"
  edit a.sml 's/val unused = 0/val unused = 0 val more = 1/'
  build; want "$all"
  mv "$dir/a.sml.orig" "$dir/a.sml"
  build; want ""
fi

# S6, touch: a file's time changed and nothing else
if run S6; then
  fresh S6; build
  touch "$dir/a.sml"
  build; want ""
fi

# S8, a functor body: c.sml's functor's body changed, not its signature;
# c.sml and d.sml, which applies it; main.sml uses d.sml's structure, whose
# basis is as it was
if run S8; then
  fresh S8; build
  edit c.sml 's/fun area2 x = 2 \* S.area x/fun area2 x = 3 * S.area x/'
  build; want "c.sml d.sml"
fi

# S17, reorder: b.sml and c.sml, which use nothing of each other, swapped;
# nothing compiled, and the program runs in the new order
if run S17; then
  fresh S17; build
  printf 'a.sml\nc.sml\nb.sml\nd.sml\nmain.sml\n' > "$dir/files"
  build; want ""
fi

# S18, insert: a file between b.sml and c.sml that declares what no later
# unit uses; only it
if run S18; then
  fresh S18; build
  printf 'val unrelated = 1\n' > "$dir/e.sml"
  printf 'a.sml\nb.sml\ne.sml\nc.sml\nd.sml\nmain.sml\n' > "$dir/files"
  build; want "e.sml"
fi

# S19, shadow: a file before d.sml declaring B again; it and d.sml, which
# uses B; main.sml uses d.sml's structure, whose basis is as it was
if run S19; then
  fresh S19; build
  printf 'structure B : SHAPE = struct type t = A.shape fun area _ = 0 end\n' > "$dir/s.sml"
  printf 'a.sml\nb.sml\nc.sml\ns.sml\nd.sml\nmain.sml\n' > "$dir/files"
  build; want "s.sml d.sml"
fi

# S29, relocation: the project and its cache moved to another directory;
# nothing compiled, and the program names its files where they are now
if run S29; then
  fresh S29; build
  rm -rf "$out/S29-moved"
  mv "$dir" "$out/S29-moved"
  dir=$out/S29-moved
  build; want ""
fi

# S13, fixity: an infix directive in a.sml for a name b.sml uses as an
# ordinary identifier: b.sml compiled again, and failing
if run S13; then
  fresh S13
  edit b.sml 's/fun area s = A.area s + 1/fun ++ x = x + 1  fun area s = ++ (A.area s)/'
  build; want "$all"
  edit a.sml 's/^structure A =/infix 5 ++\nstructure A =/'
  build; fails
fi

# S24, flags: -O1, then -O0, then -O1: the second compiles everything,
# the third nothing, the two configurations side by side
if run S24; then
  fresh S24; build -O1; want "$all"
  build -O0; want "$all"
  build -O1; want ""
fi

# S31, a compile error: b.sml broken fails and writes no entry for it; mended
# (not as it was), b.sml alone, its basis being as it was
if run S31; then
  fresh S31; build
  cp "$dir/b.sml" "$dir/b.sml.orig"
  edit b.sml 's/A.area s + 1/A.area s + "1"/'
  build; fails
  sed 's/^(\* uses a.sml \*)/(* uses a.sml, mended *)/' "$dir/b.sml.orig" > "$dir/b.sml"
  build; want "b.sml"
fi

# S33, corruption: every entry cut short, one with a byte changed: each is
# no entry, and is compiled and written again
if run S33; then
  fresh S33; build
  for e in "$dir"/cache/*/*/*; do head -c 40 "$e" > "$e.cut" && mv "$e.cut" "$e"; done
  build; want "$all"
  e=$(ls "$dir"/cache/*/*/* | head -1)
  # a byte of its basis, whatever it was, made another
  b=$(od -An -tu1 -j60 -N1 "$e" | tr -d ' ')
  printf "\\$(printf '%03o' $(( (b + 1) % 256 )))" | dd of="$e" bs=1 seek=60 conv=notrunc 2> /dev/null
  build
  if grep -q '^rune: compiled' "$dir/build.err"; then pass=$((pass + 1))
  else echo "FAIL incremental.S33: an entry with a byte changed was taken ($e)"; fail=$((fail + 1)); fi
  build; want ""
fi

# S34, two compilers: two builds of the project at once on one cache; both
# right, and the cache whole after them
if run S34; then
  fresh S34
  # shellcheck disable=SC2046
  (cd "$dir" && "$rune" --units --cache-dir cache $(cat files) -o one.rbc) 2> "$dir/one.err" &
  first=$!
  # shellcheck disable=SC2046
  (cd "$dir" && "$rune" --units --cache-dir cache $(cat files) -o two.rbc) 2> "$dir/two.err"
  wait $first
  # shellcheck disable=SC2046
  (cd "$dir" && "$rune" --units --no-cache $(cat files) -o nocache.rbc) > /dev/null 2>&1
  if cmp -s "$dir/one.rbc" "$dir/nocache.rbc" && cmp -s "$dir/two.rbc" "$dir/nocache.rbc"; then pass=$((pass + 1))
  else echo "FAIL incremental.S34: a build at the same time as another differs"; fail=$((fail + 1)); fi
  build; want ""
fi

# S36, a read-only cache: a build that cannot write it succeeds, and the next
# one compiles again what it could not keep
if run S36; then
  fresh S36; build
  edit a.sml 's/fun area (Square n) = n \* n/fun area (Square n) = n * n * 1/'
  chmod -R a-w "$dir/cache"
  if touch "$dir/cache/probe" 2> /dev/null; then rm -f "$dir/cache/probe"; chmod -R u+w "$dir/cache"   # as root: no test
  else
    build; want "a.sml"
    chmod -R u+w "$dir/cache"
    build; want "a.sml"
  fi
fi

# S28, the Basis Library: built on a copy of the library, which has no
# frozen one, so that its units are in the project's cache. A value added
# to List that LIST does not have changes list.sml's basis and not what
# the sealed List shows: no unit of the project is compiled again. A
# top-level value added to pervasive.sml, which binds print, changes what
# main.sml used (print and ^, by the unit that bound them): main.sml alone
# (per-entry fingerprints would compile none of them)
if run S28; then
  fresh S28
  lib=$dir/lib
  mkdir -p "$lib"
  cp -r "$root/lib/basis" "$lib/basis"
  build --lib "$lib"; want "$all"
  sed 's/^  datatype list = datatype list$/  val runeScenarioS28 = 0\n&/' "$lib/basis/list.sml" > "$lib/basis/list.sml.new" && mv "$lib/basis/list.sml.new" "$lib/basis/list.sml"
  build --lib "$lib"; want ""
  printf '\nval runeScenarioS28 = 0\n' >> "$lib/basis/pervasive.sml"
  build --lib "$lib"; want "main.sml"
fi

# S28, overloading: w.sml writes a wide string at WideCharVector.vector and
# never names WideString, but the overloading of its literal is the one
# widestring.sml registers for that type, which widechar.sml declares; a
# value added to widestring.sml compiles w.sml again as well as x.sml,
# which names WideString (the usage "o" of the type's name)
if run S28; then
  s=S28o
  dir=$out/S28o
  rm -rf "$dir"
  mkdir -p "$dir/lib"
  cp -r "$root/lib/basis" "$dir/lib/basis"
  printf 'val n = WideString.size\n' > "$dir/x.sml"
  printf 'val v : WideCharVector.vector = "ab"\nval () = print (Int.toString (WideCharVector.length v) ^ "\\n")\n' > "$dir/w.sml"
  printf 'x.sml\nw.sml\n' > "$dir/files"
  build --lib "$dir/lib"; want "x.sml w.sml"
  sed 's/^  fun fromLit s = /  val runeScenarioS28 = 0\n&/' "$dir/lib/basis/widestring.sml" > "$dir/w.new" && mv "$dir/w.new" "$dir/lib/basis/widestring.sml"
  build --lib "$dir/lib"; want "x.sml w.sml"
fi

# S40, a session's basis: a file used in REPL sessions whose earlier
# declarations differ in type is an entry for each, and a session like the
# first finds the first's entry and writes nothing (the entries' inodes
# are as they were)
if run S40; then
  s=S40
  dir=$out/S40
  rm -rf "$dir"
  mkdir -p "$dir"
  printf 'val twice = (base, base)\n' > "$dir/uses.sml"
  session() { (cd "$dir" && printf '%s\nuse "uses.sml";\n' "$1" | RUNE_CACHE="$dir/cache" "$repl" > "$dir/session.out" 2>&1); }
  entries() { find "$dir/cache" -type f | sort | xargs ls -i | awk '{print $1, $2}'; }
  session 'val base = "ab";'
  one=$(entries | wc -l)
  session 'val base = 3;'
  two=$(entries | wc -l)
  before=$(entries)
  session 'val base = "cd";'
  after=$(entries)
  if [ "$one" = 1 ] && [ "$two" = 2 ] && [ "$before" = "$after" ] && grep -q 'twice = ("cd", "cd")' "$dir/session.out"; then
    pass=$((pass + 1))
  else
    echo "FAIL incremental.S40: entries $one then $two, the third session $( [ "$before" = "$after" ] && echo 'wrote nothing' || echo 'wrote some') ($dir)"
    fail=$((fail + 1))
  fi
fi

# own S FILE...: S's project of its own, the files in that order, written by put
own() {
  s=$1
  dir=$out/$1
  rm -rf "$dir"
  mkdir -p "$dir"
  shift
  printf '%s\n' "$@" > "$dir/files"
}
put() { printf '%s\n' "$2" > "$dir/$1"; }
# prints WHAT: the last build's program prints WHAT
prints() {
  got=$("$(dirname "$rune")/runevm" "$dir/p.rbc" 2>&1)
  if [ "$got" = "$1" ]; then pass=$((pass + 1))
  else echo "FAIL incremental.$s: the program printed [$got], wanted [$1]"; fail=$((fail + 1)); fi
}

# S56, the frozen Basis by another path: the frozen library's units were
# compiled where their sources were bin/../lib/basis (make basis-cache), and
# this compiler is run by a path of its own. word8vector.sml applies
# mono_vector_fn.sml's functor, and its code names that file where it is
# now -- the bytes of a build without the cache, and a trace through the
# functor's body that names the library where it is
if run S56; then
  own S56 t.sml
  put t.sml 'val v = Word8Vector.fromList [0w1, 0w2]  val () = print (Word8.toString (Word8Vector.sub (v, 5)) ^ "\n")'
  build; want "t.sml"
  if "$(dirname "$rune")/runevm" "$dir/p.rbc" 2>&1 | grep -q ' at /.*lib/basis/mono_vector_fn\.sml:'; then pass=$((pass + 1))
  else echo "FAIL incremental.S56: the trace names the library elsewhere"; fail=$((fail + 1)); fi
fi

# S49, a functor's fixity: c.sml's functor's body is parsed with the
# fixity a.sml gives ++, and a.sml changes it; main.sml, which applies the
# functor and names nothing of a.sml, is compiled again with c.sml (what a
# functor's body found where it was declared is in its unit's identity;
# docs/plans/build-cache-issues.md, issue 1)
if run S49; then
  own S49 y.sml a.sml c.sml main.sml
  put y.sml 'fun op++ (a, b) = a - b'
  put a.sml 'infix 6 ++'
  put c.sml 'functor F () = struct val v = 10 ++ 3 * 2 end'
  put main.sml 'structure D = F ()  val () = print (Int.toString D.v ^ "\n")'
  build; want "y.sml a.sml c.sml main.sml"; prints 4
  put a.sml 'infix 8 ++'
  build; want "a.sml c.sml main.sml"; prints 14
fi

# S50, a functor's type, shadowed: the body uses a.sml's A.t, which a.sml
# changes from int to IntInf.int, and z.sml declares another A between the
# functor and main.sml, which applies it: main.sml finds z.sml's A, not the
# body's, and is compiled again all the same
if run S50; then
  own S50 a.sml c.sml z.sml main.sml
  put a.sml 'structure A = struct type t = int end'
  put c.sml 'functor F () = struct val big = (ignore (1000000000 * 1000000000 * 1000000000 * 1000000000 : A.t); true) handle Overflow => false end'
  put z.sml 'structure A = struct val unrelated = 1 end'
  put main.sml 'structure D = F ()  val () = print (Bool.toString D.big ^ "\n")'
  build; want "a.sml c.sml z.sml main.sml"; prints false
  put a.sml 'structure A = struct type t = IntInf.int end'
  build; want "a.sml c.sml main.sml"; prints true
fi

# S51, a functor's call, shadowed: as S50, the body calling a.sml's A.mk
# and matching what it gives, whose constructors a.sml reorders: main.sml
# is compiled again rather than its code naming an a.sml that is gone
# (issue 4)
if run S51; then
  own S51 a.sml c.sml z.sml main.sml
  put a.sml 'structure A = struct datatype t = P of int | Q of int  fun mk n = if n > 0 then Q n else P n end'
  put c.sml 'functor F () = struct fun g n = case A.mk n of A.Q m => m | _ => 0 end'
  put z.sml 'structure A = struct val unrelated = 1 end'
  put main.sml 'structure D = F ()  val () = print (Int.toString (D.g 7) ^ "\n")'
  build; want "a.sml c.sml z.sml main.sml"; prints 7
  put a.sml 'structure A = struct datatype t = Q of int | P of int  fun mk n = if n > 0 then Q n else P n end'
  build; want "a.sml c.sml main.sml"; prints 7
fi

# S52, hidden code renumbered: a body changed with functions, a reference
# and a datatype added in a local before what a.sml exports, which shifts
# the numbers of its hidden names; main.sml calls what follows and is not
# compiled again (the cut-off, S2)
if run S52; then
  own S52 a.sml main.sml
  put a.sml 'structure A = struct fun f () = 1  fun g () = 2  val k = 30 end'
  put main.sml 'val () = print (Int.toString (A.g ()) ^ " " ^ Int.toString A.k ^ "\n")'
  build; want "a.sml main.sml"; prints "2 30"
  put a.sml 'structure A = struct local datatype h = X of int | Y of int  fun h0 () = case Y 7 of Y m => m | X _ => 0  val z0 = ref 0  fun h1 () = h0 () + !z0 in fun f () = 1 + h1 () - 7 end  fun g () = 2  val k = 30 end'
  build; want "a.sml"; prints "2 30"
fi

# S53 and S54, what the REPL echoes of a file used: its echo is compiled
# with it and kept with it, and is what the session asks for -- a printer
# installed for a type of it since the entry was written (S53), and an echo
# at all after an entry written at print depth 0 (S54) (issue 3)
if run S53; then
  s=S53
  dir=$out/S53
  rm -rf "$dir"
  mkdir -p "$dir"
  put t.sml 'datatype t = T of int'
  put v.sml 'val v = T 3'
  session() { (cd "$dir" && printf '%s\n' "$@" | RUNE_CACHE="$dir/cache" "$repl" > "$dir/session.out" 2>&1); }
  session 'use "t.sml";' 'use "v.sml";'
  session 'use "t.sml";' \
    'Compiler.addPrettyPrinter (fn _ => fn _ => fn (T n) => Compiler.PrettyString ("<t " ^ Int.toString n ^ ">"));' \
    'use "v.sml";'
  if grep -q 'val v = <t 3> : t' "$dir/session.out"; then pass=$((pass + 1))
  else echo "FAIL incremental.S53: the printer installed is not the one shown ($dir/session.out)"; fail=$((fail + 1)); fi
fi
if run S54; then
  s=S54
  dir=$out/S54
  rm -rf "$dir"
  mkdir -p "$dir"
  put t.sml 'datatype t = T of int'
  put v.sml 'val v = T 3'
  session() { (cd "$dir" && printf '%s\n' "$@" | RUNE_CACHE="$dir/cache" "$repl" > "$dir/session.out" 2>&1); }
  session 'RuneCompiler.printDepth := 0;' 'use "t.sml";' 'use "v.sml";'
  session 'use "t.sml";' 'use "v.sml";'
  if grep -q 'val v = T 3 : t' "$dir/session.out"; then pass=$((pass + 1))
  else echo "FAIL incremental.S54: the session at the default depth echoed nothing ($dir/session.out)"; fail=$((fail + 1)); fi
fi

# S55, --verify-cache: S49's project, warm after the edit, verifies; then
# main.sml's entry from before the edit is planted under the usages of the
# one after (tests/incremental/plant.py), so that they hold: a build takes
# it and prints what the program printed before, and --verify-cache finds
# it and fails
if run S55; then
  own S55 y.sml a.sml c.sml main.sml
  put y.sml 'fun op++ (a, b) = a - b'
  put a.sml 'infix 6 ++'
  put c.sml 'functor F () = struct val v = 10 ++ 3 * 2 end'
  put main.sml 'structure D = F ()  val () = print (Int.toString D.v ^ "\n")'
  build; want "y.sml a.sml c.sml main.sml"
  entry() { for f in $(find "$dir/cache" -type f); do if grep -q 'main\.sml' "$f"; then echo "$f"; fi; done; }
  old=$(entry)
  cp "$old" "$dir/old-entry"
  put a.sml 'infix 8 ++'
  build; want "a.sml c.sml main.sml"
  build --verify-cache
  if [ "$status" = 0 ]; then pass=$((pass + 1))
  else echo "FAIL incremental.S55: a warm build did not verify ($dir/build.err)"; fail=$((fail + 1)); fi
  new=$(entry | grep -v "^$old\$")
  python3 "$root/tests/incremental/plant.py" "$dir/old-entry" "$new"
  build
  if [ "$compiled" = "" ]; then pass=$((pass + 1))
  else echo "FAIL incremental.S55: the planted entry was not taken ($dir/build.err)"; fail=$((fail + 1)); fi
  prints 4
  build --verify-cache
  if [ "$status" != 0 ] && grep -q "main.sml: the cache's entry is not what compiling it gives" "$dir/build.err"; then
    pass=$((pass + 1))
  else echo "FAIL incremental.S55: --verify-cache did not find the planted entry ($dir/build.err)"; fail=$((fail + 1)); fi
fi

echo "incremental: passed $pass, failed $fail"
[ $fail = 0 ]

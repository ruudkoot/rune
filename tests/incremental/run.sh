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

echo "incremental: passed $pass, failed $fail"
[ $fail = 0 ]

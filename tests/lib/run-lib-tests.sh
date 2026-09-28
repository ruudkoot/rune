#!/bin/sh
# The tests of the libraries beside the basis library and of the compiler's
# --library (docs/plans/quickcheck.md, D1 and M2).
#   tests/lib/run-lib-tests.sh
# The toy libraries of tests/lib are given the basis library's company in a
# directory of their own, tests/out/lib/root (basis, toy, toy2, prim,
# cycle1 and cycle2, as links), which is the --lib of every compile here.
# Checked:
#   - a program that names a library's structure runs with --library, and
#     prints its .expected;
#   - the same program compiled with the library's files listed after it is
#     the same bytecode, so --library is the files in order and nothing else;
#   - a library written on another (# library: in its MANIFEST) loads the
#     other first;
#   - --basis-deps lists what a program loads: the files of the libraries it
#     names, and no file of a library it does not name;
#   - --basis-check checks the libraries' MANIFESTs against their sources;
#   - a library may not use _prim, and a library written on itself is an
#     error;
#   - runedoc documents a library written on another;
#   - lib/random gives the known answers of tests/lib/random/reference.c and
#     keeps its promises (tests/lib/random/props.sml);
#   - lib/test/property's core holds (tests/lib/property/core.sml) and draws
#     what fingerprint.expected says, and its shrinker reaches the known
#     minima of the shrinking challenge and of planted bugs
#     (tests/lib/property/shrink.sml), its arbitraries cover every type of
#     the census of the Basis Library's laws and draw what frozen.expected
#     says (instances.sml), and its properties kill every mutant of
#     mutants.sml;
#   - the examples of both libraries' documentation hold.
# Override the tools with RUNE=, RUNEVM= and RUNEDOC=.
set -u
cd "$(dirname "$0")/../.."
top=$(pwd)
rune=${RUNE:-bin/rune}
runevm=${RUNEVM:-bin/runevm}
runedoc=${RUNEDOC:-bin/runedoc}
out=tests/out/lib
root=$out/root
rm -rf "$out"
mkdir -p "$root"
ln -s "$top/lib/basis" "$root/basis"
for l in toy toy2 prim cycle1 cycle2; do ln -s "$top/tests/lib/$l" "$root/$l"; done

passed=0
failed=0
ok() { passed=$((passed + 1)); }
bad() { failed=$((failed + 1)); echo "failed: $1"; }

# run NAME LIBRARIES...: compile tests/lib/NAME.sml with the libraries, run
# it, and compare its output with NAME.expected
run() {
  name=$1; shift
  libs=""
  for l in "$@"; do libs="$libs --library $l"; done
  # shellcheck disable=SC2086
  if "$rune" --lib "$root" $libs "tests/lib/$name.sml" -o "$out/$name.rbc" > "$out/$name.cerr" 2>&1 &&
     "$runevm" "$out/$name.rbc" > "$out/$name.out" 2>&1 &&
     cmp -s "$out/$name.out" "tests/lib/$name.expected"; then
    ok
  else
    bad "$name with$libs (see $out/$name.cerr, $out/$name.out)"
  fi
}

run use-toy toy
run use-toy2 toy2

# the same program with the library's files listed (by the path --library
# reads them at, which the bytecode records): the same bytecode
if "$rune" --lib "$root" "$root/toy/toy.sml" tests/lib/use-toy.sml -o "$out/use-toy-listed.rbc" > "$out/use-toy-listed.cerr" 2>&1 &&
   cmp -s "$out/use-toy.rbc" "$out/use-toy-listed.rbc"; then
  ok
else
  bad "use-toy with --library toy and with its files listed differ"
fi

# what a program loads: toy's file before toy2's, never extra.sml
"$rune" --lib "$root" --library toy2 --basis-deps tests/lib/use-toy2.sml > "$out/deps.txt" 2>&1
toy=$(grep -n "toy/toy.sml$" "$out/deps.txt" | cut -d: -f1)
toy2=$(grep -n "toy2/toy2.sml$" "$out/deps.txt" | cut -d: -f1)
if [ -n "$toy" ] && [ -n "$toy2" ] && [ "$toy" -lt "$toy2" ] && ! grep -q "extra.sml" "$out/deps.txt"; then
  ok
else
  bad "--basis-deps with --library toy2 (see $out/deps.txt)"
fi

# the MANIFESTs of the libraries against their sources
if "$rune" --lib "$root" --library toy --library toy2 --basis-check > "$out/check.txt" 2>&1; then
  ok
else
  bad "--basis-check with --library toy --library toy2 (see $out/check.txt)"
fi

# _prim is the basis library's alone
if "$rune" --lib "$root" --library prim tests/lib/use-prim.sml -o "$out/use-prim.rbc" > "$out/use-prim.cerr" 2>&1; then
  bad "a library that uses _prim was compiled"
elif grep -q "_prim is only allowed" "$out/use-prim.cerr"; then
  ok
else
  bad "a library that uses _prim: another error (see $out/use-prim.cerr)"
fi

# a library written on itself
if "$rune" --lib "$root" --library cycle1 tests/lib/use-toy.sml -o "$out/cycle.rbc" > "$out/cycle.cerr" 2>&1; then
  bad "a library written on itself was compiled"
elif grep -q "is written on itself" "$out/cycle.cerr"; then
  ok
else
  bad "a library written on itself: another error (see $out/cycle.cerr)"
fi

# runedoc: a library written on another, on top of the basis library
if "$runedoc" --lib "$root" --library toy2 --out "$out/toy2.site" --title toy2 > "$out/runedoc.txt" 2>&1; then
  ok
else
  bad "runedoc --library toy2 (see $out/runedoc.txt)"
fi

# lib/random (docs/plans/quickcheck.md, M3), as a program uses it: --library
# random under the --lib of bin/rune. Its known answers are those of
# tests/lib/random/reference.c, a C transcription of splitmix64.c and of the
# split of Java's SplittableRandom; tests/lib/run-hosts.sh runs the same on
# the other compilers.
cc=${CC:-cc}
if "$cc" -O2 -o "$out/random-reference" tests/lib/random/reference.c > "$out/random-reference.cerr" 2>&1 &&
   "$out/random-reference" > "$out/random-kat.expected" &&
   "$rune" --library random tests/lib/random/kat.sml -o "$out/random-kat.rbc" > "$out/random-kat.cerr" 2>&1 &&
   "$runevm" "$out/random-kat.rbc" > "$out/random-kat.out" 2>&1 &&
   cmp -s "$out/random-kat.out" "$out/random-kat.expected"; then
  ok
else
  bad "random: the known answers (diff $out/random-kat.expected $out/random-kat.out)"
fi
if "$rune" --library random tests/lib/random/props.sml -o "$out/random-props.rbc" > "$out/random-props.cerr" 2>&1 &&
   "$runevm" "$out/random-props.rbc" > "$out/random-props.out" 2>&1 &&
   ! grep -q "^FAIL" "$out/random-props.out"; then
  ok
else
  bad "random: the properties (see $out/random-props.cerr, $out/random-props.out)"
fi
if "$rune" --library random --basis-check > "$out/random-check.txt" 2>&1; then
  ok
else
  bad "random: --basis-check (see $out/random-check.txt)"
fi

# the examples of lib/random's documentation, which must hold as the Basis
# Library's do (tests/basis/run-examples.sh): one program for its signature
ex=$out/random-examples
mkdir -p "$ex"
if "$runedoc" --lib lib --library random --examples "$ex" > "$ex/runedoc.log" 2>&1; then
  for f in "$ex"/*.sml; do
    p=${f%.sml}
    if "$rune" --library random "$f" -o "$p.rbc" > "$p.cerr" 2>&1 && "$runevm" "$p.rbc" > "$p.out" 2>&1 &&
       grep -q "^PASS" "$p.out" && ! grep -q "^FAIL" "$p.out"; then
      ok
    else
      bad "random: the examples of $(basename "$f" .sml) (see $p.cerr, $p.out)"
    fi
  done
else
  bad "random: runedoc --examples (see $ex/runedoc.log)"
fi

# lib/test/property (docs/plans/quickcheck.md, M4 on): its core, the
# fingerprint of what a seed draws (the same on every compiler), its
# shrinker, its MANIFEST and the examples of its documentation
if "$rune" --library test/property tests/lib/property/core.sml -o "$out/property-core.rbc" > "$out/property-core.cerr" 2>&1 &&
   "$runevm" "$out/property-core.rbc" > "$out/property-core.out" 2>&1 &&
   ! grep -q "^FAIL" "$out/property-core.out" &&
   [ "$(grep '^fingerprint' "$out/property-core.out" | cut -d' ' -f2)" = "$(cat tests/lib/property/fingerprint.expected)" ]; then
  ok
else
  bad "property: the core (see $out/property-core.cerr, $out/property-core.out)"
fi
if "$rune" --library test/property tests/lib/property/shrink.sml -o "$out/property-shrink.rbc" > "$out/property-shrink.cerr" 2>&1 &&
   "$runevm" "$out/property-shrink.rbc" > "$out/property-shrink.out" 2>&1 &&
   grep -q "^PASS" "$out/property-shrink.out" && ! grep -q "^FAIL" "$out/property-shrink.out"; then
  ok
else
  bad "property: shrinking (see $out/property-shrink.cerr, $out/property-shrink.out)"
fi
if "$rune" --library test/property tests/lib/property/instances.sml -o "$out/property-instances.rbc" > "$out/property-instances.cerr" 2>&1 &&
   "$runevm" "$out/property-instances.rbc" > "$out/property-instances.out" 2>&1 &&
   ! grep -q "^FAIL" "$out/property-instances.out" &&
   [ "$(grep '^frozen' "$out/property-instances.out" | cut -d' ' -f2)" = "$(cat tests/lib/property/frozen.expected)" ]; then
  ok
else
  bad "property: the instances, or what they draw (see $out/property-instances.cerr, $out/property-instances.out)"
fi
if "$rune" --library test/property tests/lib/property/mutants.sml -o "$out/property-mutants.rbc" > "$out/property-mutants.cerr" 2>&1 &&
   "$runevm" "$out/property-mutants.rbc" > "$out/property-mutants.out" 2>&1 &&
   ! grep -q "^FAIL\|^SURVIVED" "$out/property-mutants.out"; then
  ok
else
  bad "property: the mutants (see $out/property-mutants.cerr, $out/property-mutants.out)"
fi
# Check.laws: every law, then one alone
if "$rune" --library test/property tests/lib/property/laws.sml -o "$out/property-laws.rbc" > "$out/property-laws.cerr" 2>&1 &&
   "$runevm" "$out/property-laws.rbc" > "$out/property-laws.out" 2>&1 &&
   [ "$(grep -c '^LAW ' "$out/property-laws.out")" = 2 ] && grep -q "^laws: 2 pass, 0 fail" "$out/property-laws.out" &&
   RUNE_PROPERTY_ONLY=TEST.nth/law-1@List "$runevm" "$out/property-laws.rbc" > "$out/property-laws-only.out" 2>&1 &&
   grep -q "^laws: 1 pass, 0 fail" "$out/property-laws-only.out" && grep -q "^PASS TEST.nth" "$out/property-laws-only.out"; then
  ok
else
  bad "property: Check.laws (see $out/property-laws.out, $out/property-laws-only.out)"
fi
if "$rune" --library test/property --basis-check > "$out/property-check.txt" 2>&1; then
  ok
else
  bad "property: --basis-check (see $out/property-check.txt)"
fi
ex=$out/property-examples
mkdir -p "$ex"
if "$runedoc" --lib lib --library test/property --examples "$ex" > "$ex/runedoc.log" 2>&1; then
  for f in "$ex"/*.sml; do
    p=${f%.sml}
    if "$rune" --library test/property "$f" -o "$p.rbc" > "$p.cerr" 2>&1 && "$runevm" "$p.rbc" > "$p.out" 2>&1 &&
       grep -q "^PASS" "$p.out" && ! grep -q "^FAIL" "$p.out"; then
      ok
    else
      bad "property: the examples of $(basename "$f" .sml) (see $p.cerr, $p.out)"
    fi
  done
else
  bad "property: runedoc --examples (see $ex/runedoc.log)"
fi

echo "test-lib: passed $passed, failed $failed"
[ "$failed" -eq 0 ]

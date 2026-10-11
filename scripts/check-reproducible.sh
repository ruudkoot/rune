#!/bin/sh
# Reproducible builds (the incremental roadmap's M11; docs/units.md,
# Parallel builds): the compiler built from its build file is the same bytes
# every way it can be built -- in units and whole, without the cache,
# through a cold cache and then warm, by one process and by eight, and from
# a copy of its sources in another directory, as a fresh checkout has them
# -- and the whole builds are the bytes of bin/rune.rbc, which the Makefile
# compiles from the same files without a build file. The compiler is
# bin/rune, named so in each directory (the copy has a link to this bin):
# a program names the Basis's files by the path the compiler was run by.
#   scripts/check-reproducible.sh [-j N]
set -u
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
rune=bin/rune
jobs=8
while [ $# -gt 0 ]; do
  case $1 in
    -j) jobs=$2; shift 2 ;;
    *) echo "usage: scripts/check-reproducible.sh [-j N]"; exit 2 ;;
  esac
done
out=$root/tests/out/reproducible
rm -rf "$out"
mkdir -p "$out"
status=0
made=""

# build NAME DIR FLAGS...: rune.build of DIR compiled to $out/NAME.rbc
build() {
  name=$1 dir=$2
  shift 2
  if (cd "$dir" && "$rune" --build rune.build "$@" -o "$out/$name.rbc") > "$out/$name.out" 2>&1; then
    made="$made $name"
  else
    echo "check-reproducible: $name failed: $(head -1 "$out/$name.out") ($out/$name.out)"; status=1
  fi
}
# same KIND FIRST OTHER...: every one the bytes of the first
same() {
  kind=$1 first=$2
  shift 2
  for n in "$@"; do
    case " $made " in *" $n "*) ;; *) continue ;; esac
    cmp -s "$out/$first.rbc" "$out/$n.rbc" || { echo "check-reproducible: the $kind build $n differs from $first"; status=1; }
  done
}

# the copy: what the build file lists, and the build file
copy=$out/copy
mkdir -p "$copy"
ln -s "$root/bin" "$copy/bin"
cp rune.build "$copy/"
for f in $("$rune" --build-list rune.build); do
  mkdir -p "$copy/$(dirname "$f")"
  cp "$f" "$copy/$f"
done

build units-nocache "$root" --no-cache
build units-cold "$root" --cache-dir "$out/c1"
build units-warm "$root" --cache-dir "$out/c1"
build units-cold-j "$root" --cache-dir "$out/c2" -j "$jobs"
build units-warm-j "$root" --cache-dir "$out/c2" -j "$jobs"
build units-copy "$copy" --cache-dir "$out/c3" -j "$jobs"
build whole-nocache "$root" --no-cache --whole
build whole-cold "$root" --cache-dir "$out/c4" --whole
build whole-warm "$root" --cache-dir "$out/c4" --whole
build whole-warm-j "$root" --cache-dir "$out/c2" --whole -j "$jobs"
build whole-copy "$copy" --cache-dir "$out/c3" --whole
same units units-nocache units-cold units-warm units-cold-j units-warm-j units-copy
same whole whole-nocache whole-cold whole-warm whole-warm-j whole-copy
if [ -f bin/rune.rbc ] && ! cmp -s "$out/whole-nocache.rbc" bin/rune.rbc; then
  echo "check-reproducible: the whole build differs from bin/rune.rbc"; status=1
fi
[ $status = 0 ] && echo "check-reproducible: OK (the compiler the same bytes in 6 builds in units and 5 whole, -j $jobs among them, and bin/rune.rbc)"
exit $status

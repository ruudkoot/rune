#!/bin/sh
# Install (or remove) Rune: the rune wrapper, runevm, the compiler it runs, the
# basis library, the man pages and the shell completions.
#
# Usage: scripts/install.sh [--prefix DIR] [--destdir DIR] [--host NAME] [--uninstall]
#
#   --prefix DIR   install under DIR (default: /usr/local as root, ~/.local otherwise)
#   --destdir DIR  prepend DIR to every destination, for staged installs
#   --host NAME    install the host build bin/rune-NAME (mlton, smlnj or polyml)
#                  instead of the bytecode compiler; rune then points at it
#   --uninstall    remove what an install with the same options put there
#
# This script never builds anything; `make install` builds first when it is not
# run as root. RUNE_HEAP sets the semispace the installed wrapper asks for.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
prefix=${PREFIX:-}
destdir=${DESTDIR:-}
host=${HOST:-}
heap=${RUNE_HEAP:-67108864}
uninstall=0

usage="usage: install.sh [--prefix DIR] [--destdir DIR] [--host NAME] [--uninstall]"

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) prefix=$2; shift ;;
    --destdir) destdir=$2; shift ;;
    --host) host=$2; shift ;;
    --uninstall) uninstall=1 ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) echo "install.sh: unknown argument: $1" >&2; echo "$usage" >&2; exit 2 ;;
  esac
  shift
done

case "$host" in
  ""|mlton|smlnj|polyml) ;;
  *) echo "install.sh: unknown host: $host (mlton, smlnj or polyml)" >&2; exit 2 ;;
esac

if [ -z "$prefix" ]; then
  if [ "$(id -u)" -eq 0 ]; then prefix=/usr/local; else prefix=$HOME/.local; fi
fi

bindir=$destdir$prefix/bin
libdir=$destdir$prefix/lib/rune
mandir=$destdir$prefix/share/man/man1
bashdir=$destdir$prefix/share/bash-completion/completions
zshdir=$destdir$prefix/share/zsh/site-functions

# ------------------------------------------------------------------ uninstall
if [ "$uninstall" = 1 ]; then
  rm -f "$bindir/rune" "$bindir/runevm" \
        "$bindir/rune-mlton" "$bindir/rune-smlnj" "$bindir/rune-polyml"
  rm -rf "$libdir"
  rm -f "$mandir/rune.1" "$mandir/runevm.1"
  rm -f "$bashdir/rune"
  rm -f "$zshdir/_rune" "$zshdir/_runevm"
  echo "uninstalled rune from $prefix"
  exit 0
fi

# ------------------------------------------------------------------- checks
missing=""
need() { [ -e "$1" ] || missing="$missing $1"; }

need "$root/bin/runevm"
if [ -z "$host" ]; then
  need "$root/bin/rune.rbc"
elif [ "$host" = smlnj ]; then
  # ml-build suffixes the heap with the architecture, so match whatever is there.
  found=0
  for h in "$root"/bin/rune-smlnj.heap.*; do
    if [ -e "$h" ]; then found=1; fi
  done
  if [ "$found" = 0 ]; then missing="$missing $root/bin/rune-smlnj.heap.<arch>"; fi
else
  need "$root/bin/rune-$host.bin"
fi

if [ -n "$missing" ]; then
  echo "install.sh: nothing to install, missing:$missing" >&2
  echo "install.sh: build it first with 'make${host:+ $host}' as a normal user" >&2
  exit 1
fi

# ------------------------------------------------------------------- install
copy() { # args SRC DST MODE
  cp "$1" "$2"
  chmod "$3" "$2"
}

mkdir -p "$bindir" "$libdir/basis" "$mandir" "$bashdir" "$zshdir"

copy "$root/bin/runevm" "$bindir/runevm" 755

# The wrapper finds the library beside itself, so the tree can be moved.
if [ -z "$host" ]; then
  copy "$root/bin/rune.rbc" "$libdir/rune.rbc" 644
  printf '#!/bin/sh\nd=$(dirname "$0")\nexec "$d/runevm" --heap-size %s "$d/../lib/rune/rune.rbc" --lib "$d/../lib/rune" "$@"\n' \
    "$heap" > "$bindir/rune"
  chmod 755 "$bindir/rune"
  installed=rune
else
  case "$host" in
    smlnj)
      for h in "$root"/bin/rune-smlnj.heap.*; do
        copy "$h" "$libdir/${h##*/}" 644
      done
      printf '#!/bin/sh\nd=$(dirname "$0")\nexec sml @SMLload="$d/../lib/rune/rune-smlnj.heap" --lib "$d/../lib/rune" "$@"\n' \
        > "$bindir/rune-smlnj"
      ;;
    *)
      copy "$root/bin/rune-$host.bin" "$libdir/rune-$host.bin" 755
      printf '#!/bin/sh\nd=$(dirname "$0")\nexec "$d/../lib/rune/rune-%s.bin" --lib "$d/../lib/rune" "$@"\n' \
        "$host" > "$bindir/rune-$host"
      ;;
  esac
  chmod 755 "$bindir/rune-$host"
  ln -sfn "rune-$host" "$bindir/rune"
  installed="rune-$host"
fi

copy "$root/lib/basis/MANIFEST" "$libdir/basis/MANIFEST" 644
while read -r f; do
  case "$f" in ""|\#*) continue ;; esac
  copy "$root/lib/basis/$f" "$libdir/basis/$f" 644
done < "$root/lib/basis/MANIFEST"

copy "$root/man/rune.1" "$mandir/rune.1" 644
copy "$root/man/runevm.1" "$mandir/runevm.1" 644
copy "$root/completions/rune.bash" "$bashdir/rune" 644
copy "$root/completions/_rune" "$zshdir/_rune" 644
copy "$root/completions/_runevm" "$zshdir/_runevm" 644

echo "installed $installed and runevm in $prefix/bin, the basis library in $prefix/lib/rune"
if [ "$host" = smlnj ]; then
  echo "note: rune-smlnj needs 'sml' on the PATH to run"
fi

case ":${PATH:-}:" in
  *":$prefix/bin:"*) ;;
  *) [ -n "$destdir" ] || echo "note: $prefix/bin is not on your PATH" ;;
esac

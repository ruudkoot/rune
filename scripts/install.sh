#!/bin/sh
# Install (or remove) Rune: the rune wrapper, runevm and runevm-new (the VM of
# the register bytecode, with its JIT), the compiler it runs, the
# basis library, the man pages and the shell completions; and runedoc, the
# documentation generator, and runeopt, the native code generator, when they
# are built (bin/runedoc.rbc, or bin/runedoc-NAME with --host, and the same of
# runeopt), runeopt with the runtime it links a program with (lib/rune/runtime).
#
# Usage: scripts/install.sh [--prefix DIR] [--destdir DIR] [--host NAME] [--uninstall]
#
#   --prefix DIR   install under DIR (default: /usr/local as root, ~/.local otherwise)
#   --destdir DIR  prepend DIR to every destination, for staged installs
#   --host NAME    install the host build bin/rune-NAME (mlton, smlnj-legacy,
#                  smlnj-dev, polyml or mlkit) instead of the bytecode
#                  compiler; rune then points at it
#   --uninstall    remove what an install with the same options put there
#
# This script never builds anything; `make install` builds first when it is not
# run as root. RUNE_HEAP sets the semispace the installed wrapper asks for.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
prefix=${PREFIX:-}
destdir=${DESTDIR:-}
host=${HOST:-}
# the SML/NJ that runs an installed heap image (that of `make hosts`)
smlnj_legacy=${SMLNJ:-${RUNE_HOSTS:-$HOME/.local/rune-hosts}/smlnj-legacy/bin/sml}
smlnj_dev=${SMLNJ_DEV:-${RUNE_HOSTS:-$HOME/.local/rune-hosts}/smlnj-dev/bin/sml}
# sml_for_host HOST: the sml of a heap-image build, or failure for the others.
sml_for_host() {
  case "$1" in
    smlnj-legacy) printf '%s\n' "$smlnj_legacy" ;;
    smlnj-dev) printf '%s\n' "$smlnj_dev" ;;
    *) return 1 ;;
  esac
}
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
  ""|mlton|smlnj-legacy|smlnj-dev|polyml|mlkit) ;;
  *) echo "install.sh: unknown host: $host (mlton, smlnj-legacy, smlnj-dev, polyml or mlkit)" >&2; exit 2 ;;
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
  rm -f "$bindir/rune" "$bindir/runevm" "$bindir/runevm-new" \
        "$bindir/rune-mlton" "$bindir/rune-smlnj-legacy" "$bindir/rune-smlnj-dev" \
        "$bindir/rune-polyml" "$bindir/rune-mlkit" \
        "$bindir/runedoc" "$bindir/runedoc-mlton" "$bindir/runedoc-smlnj-legacy" \
        "$bindir/runedoc-smlnj-dev" "$bindir/runedoc-polyml" "$bindir/runedoc-mlkit" \
        "$bindir/runeopt" "$bindir/runeopt-mlton" "$bindir/runeopt-smlnj-legacy" \
        "$bindir/runeopt-smlnj-dev" "$bindir/runeopt-polyml" "$bindir/runeopt-mlkit"
  rm -rf "$libdir"
  rm -f "$mandir/rune.1" "$mandir/runevm.1" "$mandir/runedoc.1" "$mandir/runeopt.1"
  rm -f "$bashdir/rune" "$bashdir/runedoc" "$bashdir/runeopt"
  rm -f "$zshdir/_rune" "$zshdir/_runevm" "$zshdir/_runedoc" "$zshdir/_runeopt"
  echo "uninstalled rune from $prefix"
  exit 0
fi

# ------------------------------------------------------------------- checks
missing=""
need() { [ -e "$1" ] || missing="$missing $1"; }

need "$root/bin/runevm"
need "$root/bin/runevm-new"
if [ -z "$host" ]; then
  need "$root/bin/rune.rbc"
elif sml_for_host "$host" > /dev/null; then
  # ml-build suffixes the heap with the architecture, so match whatever is there.
  found=0
  for h in "$root"/bin/rune-"$host".heap.*; do
    if [ -e "$h" ]; then found=1; fi
  done
  if [ "$found" = 0 ]; then missing="$missing $root/bin/rune-$host.heap.<arch>"; fi
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
copy "$root/bin/runevm-new" "$bindir/runevm-new" 755

# The wrapper finds the library beside itself, so the tree can be moved.
if [ -z "$host" ]; then
  copy "$root/bin/rune.rbc" "$libdir/rune.rbc" 644
  printf '#!/bin/sh\nd=$(dirname "$0")\nexec "$d/runevm" --heap-size %s "$d/../lib/rune/rune.rbc" --lib "$d/../lib/rune" "$@"\n' \
    "$heap" > "$bindir/rune"
  chmod 755 "$bindir/rune"
  installed=rune
else
  case "$host" in
    smlnj-legacy|smlnj-dev)
      for h in "$root"/bin/rune-"$host".heap.*; do
        copy "$h" "$libdir/${h##*/}" 644
      done
      printf '#!/bin/sh\nd=$(dirname "$0")\nexec "%s" @SMLload="$d/../lib/rune/rune-%s.heap" --lib "$d/../lib/rune" "$@"\n' \
        "$(sml_for_host "$host")" "$host" > "$bindir/rune-$host"
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

# runedoc, when it is built: the same kind of build as rune.
doc=""
if [ -z "$host" ]; then
  if [ -e "$root/bin/runedoc.rbc" ]; then
    copy "$root/bin/runedoc.rbc" "$libdir/runedoc.rbc" 644
    printf '#!/bin/sh\nd=$(dirname "$0")\nexec "$d/runevm" --heap-size %s "$d/../lib/rune/runedoc.rbc" --lib "$d/../lib/rune" "$@"\n' \
      "$heap" > "$bindir/runedoc"
    chmod 755 "$bindir/runedoc"
    doc=runedoc
  fi
elif sml_for_host "$host" > /dev/null; then
  found=0
  for h in "$root"/bin/runedoc-"$host".heap.*; do
    if [ -e "$h" ]; then copy "$h" "$libdir/${h##*/}" 644; found=1; fi
  done
  if [ "$found" = 1 ]; then
    printf '#!/bin/sh\nd=$(dirname "$0")\nexec "%s" @SMLload="$d/../lib/rune/runedoc-%s.heap" --lib "$d/../lib/rune" "$@"\n' \
      "$(sml_for_host "$host")" "$host" > "$bindir/runedoc-$host"
    doc=runedoc-$host
  fi
elif [ -e "$root/bin/runedoc-$host.bin" ]; then
  copy "$root/bin/runedoc-$host.bin" "$libdir/runedoc-$host.bin" 755
  printf '#!/bin/sh\nd=$(dirname "$0")\nexec "$d/../lib/rune/runedoc-%s.bin" --lib "$d/../lib/rune" "$@"\n' \
    "$host" > "$bindir/runedoc-$host"
  doc=runedoc-$host
fi
if [ -n "$host" ] && [ -n "$doc" ]; then
  chmod 755 "$bindir/$doc"
  ln -sfn "$doc" "$bindir/runedoc"
fi

# runeopt, when it is built and so is its runtime: the same kind of build as
# rune, told where the runtime is installed.
opt=""
if [ -e "$root/build/librune.a" ] && [ -e "$root/build/rune-offsets.s" ]; then
  if [ -z "$host" ]; then
    if [ -e "$root/bin/runeopt.rbc" ]; then
      copy "$root/bin/runeopt.rbc" "$libdir/runeopt.rbc" 644
      printf '#!/bin/sh\nd=$(dirname "$0")\nexec "$d/runevm" --heap-size %s "$d/../lib/rune/runeopt.rbc" --runtime "$d/../lib/rune/runtime" "$@"\n' \
        "$heap" > "$bindir/runeopt"
      chmod 755 "$bindir/runeopt"
      opt=runeopt
    fi
  elif sml_for_host "$host" > /dev/null; then
    found=0
    for h in "$root"/bin/runeopt-"$host".heap.*; do
      if [ -e "$h" ]; then copy "$h" "$libdir/${h##*/}" 644; found=1; fi
    done
    if [ "$found" = 1 ]; then
      printf '#!/bin/sh\nd=$(dirname "$0")\nexec "%s" @SMLload="$d/../lib/rune/runeopt-%s.heap" --runtime "$d/../lib/rune/runtime" "$@"\n' \
        "$(sml_for_host "$host")" "$host" > "$bindir/runeopt-$host"
      opt=runeopt-$host
    fi
  elif [ -e "$root/bin/runeopt-$host.bin" ]; then
    copy "$root/bin/runeopt-$host.bin" "$libdir/runeopt-$host.bin" 755
    printf '#!/bin/sh\nd=$(dirname "$0")\nexec "$d/../lib/rune/runeopt-%s.bin" --runtime "$d/../lib/rune/runtime" "$@"\n' \
      "$host" > "$bindir/runeopt-$host"
    opt=runeopt-$host
  fi
  if [ -n "$host" ] && [ -n "$opt" ]; then
    chmod 755 "$bindir/$opt"
    ln -sfn "$opt" "$bindir/runeopt"
  fi
  if [ -n "$opt" ]; then
    mkdir -p "$libdir/runtime"
    copy "$root/build/librune.a" "$libdir/runtime/librune.a" 644
    copy "$root/build/rune-offsets.s" "$libdir/runtime/rune-offsets.s" 644
  fi
fi

# every library: lib/basis and each directory of lib with a MANIFEST, such as
# lib/test/property (docs/plans/quickcheck.md, D1), under the same name
for manifest in $(cd "$root/lib" && find . -name MANIFEST | sort); do
  l=$(dirname "$manifest" | sed 's|^\./||')
  mkdir -p "$libdir/$l"
  copy "$root/lib/$l/MANIFEST" "$libdir/$l/MANIFEST" 644
  # the first column of a line is the file
  while IFS='|' read -r f _; do
    f=$(echo $f)
    case "$f" in ""|\#*) continue ;; esac
    copy "$root/lib/$l/$f" "$libdir/$l/$f" 644
  done < "$root/lib/$l/MANIFEST"
  # what runedoc reads besides: the overview and the list of what is documented in full
  for f in overview.doc DOCUMENTED; do
    if [ -e "$root/lib/$l/$f" ]; then copy "$root/lib/$l/$f" "$libdir/$l/$f" 644; fi
  done
done

copy "$root/man/rune.1" "$mandir/rune.1" 644
copy "$root/man/runevm.1" "$mandir/runevm.1" 644
copy "$root/completions/rune.bash" "$bashdir/rune" 644
copy "$root/completions/_rune" "$zshdir/_rune" 644
copy "$root/completions/_runevm" "$zshdir/_runevm" 644
if [ -n "$doc" ]; then
  copy "$root/man/runedoc.1" "$mandir/runedoc.1" 644
  copy "$root/completions/runedoc.bash" "$bashdir/runedoc" 644
  copy "$root/completions/_runedoc" "$zshdir/_runedoc" 644
fi
if [ -n "$opt" ]; then
  copy "$root/man/runeopt.1" "$mandir/runeopt.1" 644
  copy "$root/completions/runeopt.bash" "$bashdir/runeopt" 644
  copy "$root/completions/_runeopt" "$zshdir/_runeopt" 644
fi

echo "installed $installed${doc:+, runedoc}${opt:+, runeopt}, runevm and runevm-new in $prefix/bin, the basis library in $prefix/lib/rune"
if sml=$(sml_for_host "$host"); then
  echo "note: rune-$host runs with $sml"
fi

case ":${PATH:-}:" in
  *":$prefix/bin:"*) ;;
  *) [ -n "$destdir" ] || echo "note: $prefix/bin is not on your PATH" ;;
esac

#!/bin/sh
# Install a Rune distribution archive, or remove one this script installed.
# The archive holds every machine's register VM under runtime/<arch>/ and
# the libraries under lib/rune. This copies the VM for the machine it is
# running on and writes the same wrappers as scripts/install.sh.
#
#   install.sh [--prefix DIR] [--arch NAME] [--uninstall] [--dry-run]
#
# With no --prefix, root installs in /usr/local and anyone else in ~/.local.
# RUNE_DIST_EUID, when set, is the effective uid the prefix rule sees
# (bin/rune-scenarios dist).
set -eu

root=$(cd "$(dirname "$0")" && pwd)
prefix=
arch=
uninstall=0
dry=0
heap=67108864

usage="usage: install.sh [--prefix DIR] [--arch NAME] [--uninstall] [--dry-run]"
die() { echo "install.sh: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)
      [ $# -ge 2 ] || { echo "install.sh: missing value after $1" >&2; exit 2; }
      prefix=$2
      shift ;;
    --arch)
      [ $# -ge 2 ] || { echo "install.sh: missing value after $1" >&2; exit 2; }
      arch=$2
      shift ;;
    --uninstall) uninstall=1 ;;
    --dry-run) dry=1 ;;
    -h|--help) echo "$usage"; exit 0 ;;
    *) echo "install.sh: unknown argument: $1" >&2; echo "$usage" >&2; exit 2 ;;
  esac
  shift
done

if [ "$uninstall" = 1 ] && [ "$dry" = 1 ]; then
  echo "install.sh: --uninstall and --dry-run together are not supported" >&2
  exit 2
fi

if [ -z "$arch" ]; then
  machine=$(uname -m)
  bits=$(getconf LONG_BIT 2> /dev/null || echo 64)
  case "$machine" in
    x86_64|amd64)
      if [ "$bits" = 32 ]; then arch=i686; else arch=x86_64; fi ;;
    i386|i686) arch=i686 ;;
    aarch64|arm64) arch=aarch64 ;;
    ppc64) arch=ppc64 ;;
    *) die "$machine is not a supported machine. Rune installs x86_64, i686, aarch64 and ppc64." ;;
  esac
fi
case "$arch" in
  x86_64|i686|aarch64|ppc64) ;;
  *) die "$arch is not a supported machine. Rune installs x86_64, i686, aarch64 and ppc64." ;;
esac

if [ -n "${RUNE_DIST_EUID-}" ]; then euid=$RUNE_DIST_EUID; else euid=$(id -u); fi
if [ -z "$prefix" ]; then
  if [ "$euid" -eq 0 ]; then prefix=/usr/local; else
    [ -n "${HOME-}" ] || die "HOME is not set"
    prefix=$HOME/.local
  fi
fi

if [ "$dry" = 1 ]; then
  printf 'prefix=%s\narch=%s\n' "$prefix" "$arch"
  exit 0
fi

if [ "$uninstall" = 1 ]; then
  manifest=$prefix/lib/rune/DISTMANIFEST
  if [ ! -f "$manifest" ]; then
    echo "install.sh: nothing installed at $prefix"
    exit 0
  fi
  tmp=$(mktemp)
  cp "$manifest" "$tmp"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    rm -f "$prefix/$rel"
  done < "$tmp"
  rm -f "$tmp"
  find "$prefix" -depth -type d | while IFS= read -r dir; do
    case "$dir" in
      "$prefix"|"$prefix"/*) rmdir "$dir" 2> /dev/null || true ;;
    esac
  done
  echo "uninstalled rune from $prefix"
  exit 0
fi

src=$root/runtime/$arch/runevm
[ -f "$src" ] || die "no runtime for $arch"
[ -d "$root/lib/rune" ] || die "the archive has no lib/rune"

bindir=$prefix/bin
libdir=$prefix/lib/rune
rm -rf "$libdir"
mkdir -p "$bindir" "$libdir"
cp -R "$root/lib/rune/." "$libdir/"
cp "$src" "$bindir/runevm"
chmod 755 "$bindir/runevm"

# The same wrappers scripts/install.sh writes for the bytecode compiler.
printf '%s\n' '#!/bin/sh' \
  'd=$(dirname "$0")' \
  '[ "$1" = -i ] && shift && exec "$d/rune-repl" "$@"' \
  "exec \"\$d/runevm\" --heap-size $heap \"\$d/../lib/rune/rune.rbc\" --lib \"\$d/../lib/rune\" \"\$@\"" \
  > "$bindir/rune"
printf '%s\n' '#!/bin/sh' \
  'd=$(dirname "$0")' \
  "exec \"\$d/runevm\" --heap-size $heap --restore \"\$d/../lib/rune/rune-repl.img\" -- \"\$@\"" \
  > "$bindir/rune-repl"
chmod 755 "$bindir/rune" "$bindir/rune-repl"
if [ -f "$libdir/runeffi.rbc" ]; then
  printf '%s\n' '#!/bin/sh' 'd=$(dirname "$0")' \
    'exec "$d/runevm" "$d/../lib/rune/runeffi.rbc" "$@"' > "$bindir/runeffi"
  chmod 755 "$bindir/runeffi"
fi

tmp=$(mktemp)
find "$bindir" "$libdir" -type f ! -name DISTMANIFEST | while IFS= read -r file; do
  case "$file" in
    "$prefix"/*) printf '%s\n' "${file#"$prefix"/}" ;;
  esac
done | sort > "$tmp"
echo "lib/rune/DISTMANIFEST" >> "$tmp"
mv "$tmp" "$libdir/DISTMANIFEST"

echo "installed rune in $prefix"
case ":${PATH:-}:" in
  *":$prefix/bin:"*) ;;
  *) echo "note: $prefix/bin is not on your PATH" ;;
esac

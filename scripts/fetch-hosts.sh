#!/bin/sh
# Install current releases of the host SML systems under a user-local prefix,
# for the "@cur" configurations of tests/basis/run-matrix.sh. Nothing is
# installed system-wide and no root access is needed.
#   scripts/fetch-hosts.sh [--force] [mlton] [smlnj] [polyml]     (default: all three)
# Prefix: ${RUNE_HOSTS:-$HOME/.local/rune-hosts}. Each system goes to
# <prefix>/<host>-<version>, and <prefix>/<host> is a symlink to it, so
# <prefix>/mlton/bin/mlton, <prefix>/smlnj/bin/sml and <prefix>/polyml/bin/poly
# are the commands. MLTON_VERSION, SMLNJ_VERSION and POLYML_VERSION select
# other releases. `make doctor` checks the tools this script needs.
#  * MLton: the binary release from github.com/MLton/mlton (MLton is written
#    in SML and needs an MLton to build; links against the system's GMP).
#  * SML/NJ: config/install.sh of the 110.99 series, 64-bit (not the
#    LLVM-based 2025 series, which does not build without cmake).
#  * Poly/ML: built from the source release with ./configure && make.
set -eu

MLTON_VERSION=${MLTON_VERSION:-20241230}
SMLNJ_VERSION=${SMLNJ_VERSION:-110.99.9}
POLYML_VERSION=${POLYML_VERSION:-5.9.2}

force=0
hosts=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    mlton|smlnj|polyml) hosts="$hosts $1" ;;
    *) echo "usage: scripts/fetch-hosts.sh [--force] [mlton] [smlnj] [polyml]" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$hosts" ] || hosts="mlton smlnj polyml"

cd "$(dirname "$0")/.."
jobs=$(sh scripts/ncpus.sh)
prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
mkdir -p "$prefix/src"

fetch() {   # fetch URL FILE
  echo "fetching $1"
  if command -v curl > /dev/null 2>&1; then curl -fL --retry 3 -o "$2" "$1"
  else wget -O "$2" "$1"
  fi
}

# installed HOST VERSION: that version is already there (and --force is off).
installed() {
  [ $force = 0 ] && [ -d "$prefix/$1-$2" ] && [ "$(readlink "$prefix/$1")" = "$1-$2" ]
}

activate() {   # activate HOST VERSION
  ln -sfn "$1-$2" "$prefix/$1"
}

install_mlton() {
  v=$MLTON_VERSION
  if installed mlton "$v"; then echo "mlton $v is already installed"; return; fi
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) arch=amd64-linux; suffix="" ;;
    Linux-aarch64) arch=arm64-linux; suffix=-arm ;;
    *) echo "fetch-hosts: no MLton binary release for $(uname -s) $(uname -m); install it from http://mlton.org" >&2; return 1 ;;
  esac
  # The newest build whose C library is not newer than this system's.
  glibc=$(getconf GNU_LIBC_VERSION 2> /dev/null | awk '{ print $2 }')
  minor=${glibc#*.}
  if [ -n "$glibc" ] && [ "${minor:-0}" -ge 39 ]; then flavour="ubuntu-24.04${suffix}_glibc2.39"
  elif [ -n "$glibc" ] && [ "${minor:-0}" -ge 35 ]; then flavour="ubuntu-22.04${suffix}_glibc2.35"
  elif [ -n "$glibc" ] && [ "${minor:-0}" -ge 31 ] && [ -z "$suffix" ]; then flavour="ubuntu-20.04_glibc2.31"
  else flavour="ubuntu-22.04${suffix}_static"
  fi
  name=mlton-$v-1.$arch.$flavour
  fetch "https://github.com/MLton/mlton/releases/download/on-$v-release/$name.tgz" "$prefix/src/$name.tgz"
  rm -rf "$prefix/mlton-$v" "$prefix/src/$name"
  tar -xzf "$prefix/src/$name.tgz" -C "$prefix/src"
  mv "$prefix/src/$name" "$prefix/mlton-$v"
  activate mlton "$v"
}

install_smlnj() {
  v=$SMLNJ_VERSION
  if installed smlnj "$v"; then echo "smlnj $v is already installed"; return; fi
  rm -rf "$prefix/smlnj-$v"
  mkdir -p "$prefix/smlnj-$v"
  fetch "https://smlnj.cs.uchicago.edu/dist/working/$v/config.tgz" "$prefix/src/smlnj-$v-config.tgz"
  tar -xzf "$prefix/src/smlnj-$v-config.tgz" -C "$prefix/smlnj-$v"
  # install.sh downloads the remaining parts of the release and builds the
  # runtime system and the heap images in place.
  (cd "$prefix/smlnj-$v" && sh config/install.sh -default 64) > "$prefix/src/smlnj-$v.log" 2>&1 ||
    { echo "fetch-hosts: building SML/NJ failed; see $prefix/src/smlnj-$v.log" >&2; return 1; }
  activate smlnj "$v"
}

install_polyml() {
  v=$POLYML_VERSION
  if installed polyml "$v"; then echo "polyml $v is already installed"; return; fi
  fetch "https://github.com/polyml/polyml/archive/refs/tags/v$v.tar.gz" "$prefix/src/polyml-$v.tar.gz"
  rm -rf "$prefix/polyml-$v" "$prefix/src/polyml-$v"
  tar -xzf "$prefix/src/polyml-$v.tar.gz" -C "$prefix/src"
  (cd "$prefix/src/polyml-$v" &&
     ./configure --prefix="$prefix/polyml-$v" &&
     make -j "$jobs" && make compiler && make install) > "$prefix/src/polyml-$v.log" 2>&1 ||
    { echo "fetch-hosts: building Poly/ML failed; see $prefix/src/polyml-$v.log" >&2; return 1; }
  rm -rf "$prefix/src/polyml-$v"
  activate polyml "$v"
}

status=0
for h in $hosts; do
  echo "== $h"
  "install_$h" || status=1
done

echo "== installed under $prefix"
[ -x "$prefix/mlton/bin/mlton" ] && "$prefix/mlton/bin/mlton" | head -1
[ -x "$prefix/smlnj/bin/sml" ] && "$prefix/smlnj/bin/sml" @SMLversion
[ -x "$prefix/polyml/bin/poly" ] && "$prefix/polyml/bin/poly" -v
exit $status

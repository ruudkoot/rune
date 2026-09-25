#!/bin/sh
# Install the host SML systems that build Rune and that the Basis Library
# suite compares it with, under a user-local prefix (`make hosts`). Nothing is
# installed system-wide, no root access is needed, and an SML system that the
# machine itself has is never used.
#   scripts/fetch-hosts.sh [--force] [mlton] [smlnj] [smlnj32] [polyml]     (default: all four)
# Prefix: ${RUNE_HOSTS:-$HOME/.local/rune-hosts}. Each system goes to
# <prefix>/<host>-<version>, and <prefix>/<host> is a symlink to it, so
# <prefix>/mlton/bin/mlton, <prefix>/smlnj/bin/sml, <prefix>/smlnj32/bin/sml
# and <prefix>/polyml/bin/poly are the commands. MLTON_VERSION, SMLNJ_VERSION
# and POLYML_VERSION select other releases. `make doctor` checks the tools
# this script needs.
#  * MLton: the binary release from github.com/MLton/mlton (MLton is written
#    in SML and needs an MLton to build; links against the system's GMP).
#  * SML/NJ: config/install.sh of the 110.99 series, 64-bit (smlnj) and 32-bit
#    (smlnj32: 31-bit int and word, which has found many portability bugs;
#    needs gcc -m32). Not the LLVM-based 2025 series, which does not build
#    without cmake.
#  * Poly/ML: built from the source release with ./configure && make (from a
#    clone of the release's tag where the archive cannot be downloaded).
# No build here starts from an SML compiler of the machine, so none needs a
# second stage to shed one: MLton comes as a binary; SML/NJ compiles its C
# runtime and loads the compiler from the boot files of the same release;
# Poly/ML's make bootstraps from the release's own portable image, and `make
# compiler` then rebuilds the compiler with the result. To make sure of it,
# the builds run with a PATH on which mlton, sml, poly and polyc fail.
set -eu

MLTON_VERSION=${MLTON_VERSION:-20241230}
SMLNJ_VERSION=${SMLNJ_VERSION:-110.99.9}
POLYML_VERSION=${POLYML_VERSION:-5.9.2}

force=0
hosts=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    mlton|smlnj|smlnj32|polyml) hosts="$hosts $1" ;;
    *) echo "usage: scripts/fetch-hosts.sh [--force] [mlton] [smlnj] [smlnj32] [polyml]" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$hosts" ] || hosts="mlton smlnj smlnj32 polyml"

cd "$(dirname "$0")/.."
jobs=$(sh scripts/ncpus.sh)
prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
mkdir -p "$prefix/src"

# The guard: commands that stand for the machine's own SML systems and fail.
guard=$prefix/src/guard-bin
mkdir -p "$guard"
for c in mlton sml poly polyc; do
  printf '#!/bin/sh\necho "fetch-hosts: a build ran the machine'"'"'s %s ($0 $*)" >&2\nexit 1\n' "$c" > "$guard/$c"
  chmod +x "$guard/$c"
done
PATH=$guard:$PATH
export PATH

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

# install_smlnj_bits NAME BITS: SML/NJ as <prefix>/NAME-<version>.
install_smlnj_bits() {
  name=$1
  bits=$2
  v=$SMLNJ_VERSION
  if installed "$name" "$v"; then echo "$name $v is already installed"; return; fi
  rm -rf "$prefix/$name-$v"
  mkdir -p "$prefix/$name-$v"
  [ -f "$prefix/src/smlnj-$v-config.tgz" ] ||
    fetch "https://smlnj.cs.uchicago.edu/dist/working/$v/config.tgz" "$prefix/src/smlnj-$v-config.tgz"
  tar -xzf "$prefix/src/smlnj-$v-config.tgz" -C "$prefix/$name-$v"
  # install.sh downloads the remaining parts of the release and builds the
  # runtime system and the heap images in place.
  (cd "$prefix/$name-$v" && sh config/install.sh -default "$bits") > "$prefix/src/$name-$v.log" 2>&1 ||
    { echo "fetch-hosts: building SML/NJ ($bits-bit) failed; see $prefix/src/$name-$v.log" >&2; return 1; }
  activate "$name" "$v"
}
install_smlnj() { install_smlnj_bits smlnj 64; }
install_smlnj32() { install_smlnj_bits smlnj32 32; }

install_polyml() {
  v=$POLYML_VERSION
  if installed polyml "$v"; then echo "polyml $v is already installed"; return; fi
  rm -rf "$prefix/polyml-$v" "$prefix/src/polyml-$v"
  # The release's archive, or, where it cannot be downloaded, a clone of the
  # release's tag, which has the same sources: a cloud session whose GitHub
  # access covers only its own repositories is refused the archive (403)
  # but may clone a public repository (cloud/SETUP.md).
  if fetch "https://github.com/polyml/polyml/archive/refs/tags/v$v.tar.gz" "$prefix/src/polyml-$v.tar.gz"; then
    tar -xzf "$prefix/src/polyml-$v.tar.gz" -C "$prefix/src"
  else
    rm -f "$prefix/src/polyml-$v.tar.gz"
    echo "fetch-hosts: the archive of Poly/ML $v could not be downloaded; cloning its tag v$v instead"
    git clone -q --depth 1 --branch "v$v" https://github.com/polyml/polyml "$prefix/src/polyml-$v" ||
      { echo "fetch-hosts: neither the archive nor a clone of Poly/ML $v could be fetched" >&2; return 1; }
  fi
  (cd "$prefix/src/polyml-$v" &&
     ./configure --prefix="$prefix/polyml-$v" &&
     make -j "$jobs" && make compiler && make install) > "$prefix/src/polyml-$v.log" 2>&1 ||
    { echo "fetch-hosts: building Poly/ML failed; see $prefix/src/polyml-$v.log" >&2; return 1; }
  rm -rf "$prefix/src/polyml-$v"
  activate polyml "$v"
}

status=0
# The hosts are installed all at once, each in the background with its
# output kept apart and shown when all are done: a fresh machine then waits
# for the slowest (Poly/ML) rather than for the four in turn. The two
# SML/NJ builds share one download, which is fetched first.
case " $hosts " in
  *" smlnj "*|*" smlnj32 "*)
    if [ ! -f "$prefix/src/smlnj-$SMLNJ_VERSION-config.tgz" ]; then
      fetch "https://smlnj.cs.uchicago.edu/dist/working/$SMLNJ_VERSION/config.tgz" \
        "$prefix/src/smlnj-$SMLNJ_VERSION-config.tgz" || status=1
    fi ;;
esac
for h in $hosts; do
  ( if "install_$h" > "$prefix/src/fetch-$h.out" 2>&1; then echo 0; else echo 1; fi > "$prefix/src/fetch-$h.status" ) &
done
wait
for h in $hosts; do
  echo "== $h"
  cat "$prefix/src/fetch-$h.out"
  [ "$(cat "$prefix/src/fetch-$h.status" 2> /dev/null)" = 0 ] || status=1
  rm -f "$prefix/src/fetch-$h.out" "$prefix/src/fetch-$h.status"
done

echo "== installed under $prefix"
[ -x "$prefix/mlton/bin/mlton" ] && "$prefix/mlton/bin/mlton" | head -1
[ -x "$prefix/smlnj/bin/sml" ] && "$prefix/smlnj/bin/sml" @SMLversion
[ -x "$prefix/smlnj32/bin/sml" ] && "$prefix/smlnj32/bin/sml" @SMLversion
[ -x "$prefix/polyml/bin/poly" ] && "$prefix/polyml/bin/poly" -v
exit $status

#!/bin/sh
# Install the host SML systems that build Rune and that the Basis Library
# suite compares it with, under a user-local prefix (`make hosts`). Nothing is
# installed system-wide, no root access is needed, and an SML system that the
# machine itself has is never used.
#   scripts/fetch-hosts.sh [--force] [mlton] [smlnj-legacy] [smlnj32] [smlnj-dev] [polyml] [mlkit]     (default: all six)
# Prefix: ${RUNE_HOSTS:-$HOME/.local/rune-hosts}. Each system goes to
# <prefix>/<host>-<version>, and <prefix>/<host> is a symlink to it, so
# <prefix>/mlton/bin/mlton, <prefix>/smlnj-legacy/bin/sml, <prefix>/smlnj32/bin/sml,
# <prefix>/smlnj-dev/bin/sml, <prefix>/polyml/bin/poly and <prefix>/mlkit/bin/mlkit
# are the commands. MLTON_VERSION, SMLNJ_VERSION, SMLNJ_DEV_VERSION,
# POLYML_VERSION and MLKIT_VERSION (with MLKIT_SHA256) select other releases.
# `make doctor` checks the tools this script needs.
#  * MLton: the binary release from github.com/MLton/mlton (MLton is written
#    in SML and needs an MLton to build; links against the system's GMP).
#  * SML/NJ 110.99.9: config/install.sh, 64-bit (smlnj-legacy) and 32-bit
#    (smlnj32: 31-bit int and word, which has found many portability bugs;
#    needs gcc -m32), and beside the 64-bit one the sources of its library.
#    A checkout that still looks up <prefix>/smlnj keeps working: that name
#    stays a symlink to the same 64-bit install.
#  * SML/NJ 2026.2 (smlnj-dev): the development line, 64-bit only (amd64 and
#    arm64). The arch tarball from smlnj.org carries the sources and the boot
#    files; build.sh compiles the bundled LLVM and needs CMake 3.23, a C++17
#    compiler and python3. Its CM directory is .cm, the same name as
#    110.99.9, and the value is fixed when the heap is made, so the Rune
#    build of this host compiles through a tree of symlinks
#    (scripts/smlnj-dev-root.sh) and does not share those directories.
#  * Poly/ML: built from the source release with ./configure && make (from a
#    clone of the release's tag where the archive cannot be downloaded).
#  * MLKit: the binary release from github.com/melsman/mlkit on Linux x86-64
#    (built by MLKit itself, needing no GMP), checked against its SHA-256;
#    elsewhere, or with MLKIT_FROM_SOURCE=1, built from a clone of the
#    release's tag with the MLton above. That takes more memory than a
#    machine of 16 GB has: there MLton was killed at 14 GB, and ran out with
#    its heap held to 11 GB (2026-09-27), so this way is untested. Its
#    library is found through SML_LIB, which the Makefile and the Basis
#    matrix set: nothing is written to ~/.mlkit.
# No build here starts from an SML compiler of the machine, so none needs a
# second stage to shed one: MLton and MLKit come as binaries (MLKit from
# source is compiled by the MLton of the prefix); SML/NJ compiles its C
# runtime and loads the compiler from the boot files of the same release;
# Poly/ML's make bootstraps from the release's own portable image, and `make
# compiler` then rebuilds the compiler with the result. To make sure of it,
# the builds run with a PATH on which mlton, sml, poly, polyc and mlkit fail.
set -eu

MLTON_VERSION=${MLTON_VERSION:-20241230}
SMLNJ_VERSION=${SMLNJ_VERSION:-110.99.9}
SMLNJ_DEV_VERSION=${SMLNJ_DEV_VERSION:-2026.2}
POLYML_VERSION=${POLYML_VERSION:-5.9.2}
MLKIT_VERSION=${MLKIT_VERSION:-4.7.23}
# the SHA-256 of mlkit-bin-dist-linux.tgz of that release: set both to change
MLKIT_SHA256=${MLKIT_SHA256:-dca20115d8f3ff0a30ac7c5a7c3abc520b7cc7f3204f91f9895a1bfec3bc6c43}

force=0
hosts=""
while [ $# -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    mlton|smlnj-legacy|smlnj32|smlnj-dev|polyml|mlkit) hosts="$hosts $1" ;;
    *) echo "usage: scripts/fetch-hosts.sh [--force] [mlton] [smlnj-legacy] [smlnj32] [smlnj-dev] [polyml] [mlkit]" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$hosts" ] || hosts="mlton smlnj-legacy smlnj32 smlnj-dev polyml mlkit"

cd "$(dirname "$0")/.."
jobs=$(sh scripts/ncpus.sh)
prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
mkdir -p "$prefix/src"

# The guard: commands that stand for the machine's own SML systems and fail.
guard=$prefix/src/guard-bin
mkdir -p "$guard"
for c in mlton sml poly polyc mlkit; do
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
install_smlnj_legacy() {
  v=$SMLNJ_VERSION
  # bin/sml records the directory it was built in. A tree built as
  # smlnj-$v (the old host id) keeps that name; the host symlink is
  # smlnj-legacy either way. Moving the directory would make sml fail.
  if [ -x "$prefix/smlnj-$v/bin/sml" ] && "$prefix/smlnj-$v/bin/sml" @SMLversion > /dev/null 2>&1; then
    ln -sfn "smlnj-$v" "$prefix/smlnj-legacy"
    ln -sfn "smlnj-$v" "$prefix/smlnj"
    echo "smlnj-legacy $v is already installed"
  else
    install_smlnj_bits smlnj-legacy 64 || return 1
    # Other checkouts still resolve <prefix>/smlnj.
    if [ -d "$prefix/smlnj-legacy-$v" ]; then
      ln -sfn "smlnj-legacy-$v" "$prefix/smlnj"
    fi
  fi
  smlnj_system
}
# smlnj_system: the sources of SML/NJ's library (system.tgz of the release,
# which install.sh does not fetch) in the system directory of the
# smlnj-legacy installation, for the xc2:smlnj-legacy configuration of the
# Basis matrix (tests/basis/xc2).
smlnj_system() {
  v=$SMLNJ_VERSION
  d=$(cd "$prefix/smlnj-legacy" && pwd -P) || return 1
  [ -f "$d/system/Basis/basis.cm" ] && return 0
  [ -f "$d/system.tgz" ] ||
    fetch "https://smlnj.cs.uchicago.edu/dist/working/$v/system.tgz" "$d/system.tgz" || return 1
  tar -xzf "$d/system.tgz" -C "$d"
}
install_smlnj32() { install_smlnj_bits smlnj32 32; }

# install_smlnj_dev: SML/NJ SMLNJ_DEV_VERSION, the development line.
install_smlnj_dev() {
  v=$SMLNJ_DEV_VERSION
  if installed smlnj-dev "$v"; then echo "smlnj-dev $v is already installed"; return; fi
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "fetch-hosts: SML/NJ $v has no Unix build for $(uname -m) (amd64 and arm64 only)" >&2; return 1 ;;
  esac
  name=smlnj-$arch-unix-$v
  fetch "https://smlnj.org/dist/working/$v/$name.tgz" "$prefix/src/$name.tgz" || return 1
  rm -rf "$prefix/smlnj-dev-$v" "$prefix/src/smlnj-dev-$v"
  mkdir -p "$prefix/src/smlnj-dev-$v" "$prefix/smlnj-dev-$v"
  tar -xzf "$prefix/src/$name.tgz" -C "$prefix/src/smlnj-dev-$v" || return 1
  src=$(find "$prefix/src/smlnj-dev-$v" -mindepth 1 -maxdepth 3 -name build.sh -type f | head -1)
  [ -n "$src" ] || { echo "fetch-hosts: $name.tgz has no build.sh" >&2; return 1; }
  # build.sh uses bash ([[ ]]). It compiles LLVM, which is most of the time.
  (cd "$(dirname "$src")" && bash ./build.sh -install "$prefix/smlnj-dev-$v") > "$prefix/src/smlnj-dev-$v.log" 2>&1 ||
    { echo "fetch-hosts: building SML/NJ $v failed; see $prefix/src/smlnj-dev-$v.log" >&2; return 1; }
  rm -rf "$prefix/src/smlnj-dev-$v"
  activate smlnj-dev "$v"
}

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

# MLKit: the binary release where there is one, else (or with
# MLKIT_FROM_SOURCE=1) its tag built with the MLton of the prefix, which then
# has to be there first (below).
mlkit_binary() { [ "${MLKIT_FROM_SOURCE:-0}" != 1 ] && [ "$(uname -s)-$(uname -m)" = Linux-x86_64 ]; }
install_mlkit() {
  v=$MLKIT_VERSION
  if installed mlkit "$v"; then echo "mlkit $v is already installed"; return; fi
  rm -rf "$prefix/mlkit-$v" "$prefix/src/mlkit-bin-dist-linux" "$prefix/src/mlkit-$v"
  if mlkit_binary; then
    fetch "https://github.com/melsman/mlkit/releases/download/v$v/mlkit-bin-dist-linux.tgz" "$prefix/src/mlkit-$v.tgz"
    echo "$MLKIT_SHA256  $prefix/src/mlkit-$v.tgz" | sha256sum -c --quiet - ||
      { echo "fetch-hosts: mlkit-bin-dist-linux.tgz of MLKit $v is not the one of MLKIT_SHA256" >&2; return 1; }
    tar -xzf "$prefix/src/mlkit-$v.tgz" -C "$prefix/src"
    (cd "$prefix/src/mlkit-bin-dist-linux" && make install PREFIX="$prefix/mlkit-$v") > "$prefix/src/mlkit-$v.log" 2>&1 ||
      { echo "fetch-hosts: installing MLKit failed; see $prefix/src/mlkit-$v.log" >&2; return 1; }
    rm -rf "$prefix/src/mlkit-bin-dist-linux"
  else
    [ -x "$prefix/mlton/bin/mlton" ] ||
      { echo "fetch-hosts: MLKit has no binary release for $(uname -s) $(uname -m), and building it needs the MLton of $prefix" >&2; return 1; }
    git clone -q --depth 1 --branch "v$v" https://github.com/melsman/mlkit "$prefix/src/mlkit-$v" ||
      { echo "fetch-hosts: the tag v$v of MLKit could not be cloned" >&2; return 1; }
    (cd "$prefix/src/mlkit-$v" && PATH=$prefix/mlton/bin:$PATH &&
       ./autobuild && ./configure --with-compiler="$prefix/mlton/bin/mlton" --prefix="$prefix/mlkit-$v" &&
       make mlkit && make mlkit_libs && make install) > "$prefix/src/mlkit-$v.log" 2>&1 ||
      { echo "fetch-hosts: building MLKit failed; see $prefix/src/mlkit-$v.log" >&2; return 1; }
    rm -rf "$prefix/src/mlkit-$v"
  fi
  activate mlkit "$v"
}

status=0
# The hosts are installed all at once, each in the background with its
# output kept apart and shown when all are done: a fresh machine then waits
# for the slowest (SML/NJ 2026.2, which builds LLVM) rather than for them in turn. The two
# SML/NJ builds share one download, which is fetched first.
case " $hosts " in
  *" smlnj-legacy "*|*" smlnj32 "*)
    if [ ! -f "$prefix/src/smlnj-$SMLNJ_VERSION-config.tgz" ]; then
      fetch "https://smlnj.cs.uchicago.edu/dist/working/$SMLNJ_VERSION/config.tgz" \
        "$prefix/src/smlnj-$SMLNJ_VERSION-config.tgz" || status=1
    fi ;;
esac
install_one() {   # install_one HOST: in the background, its output kept apart
  # A host id may contain a hyphen; a function name may not.
  fn=$(printf 'install_%s' "$1" | tr - _)
  ( if "$fn" > "$prefix/src/fetch-$1.out" 2>&1; then echo 0; else echo 1; fi > "$prefix/src/fetch-$1.status" ) &
}
later=""
for h in $hosts; do
  # MLKit from source is compiled by the MLton being installed
  if [ "$h" = mlkit ] && ! mlkit_binary; then later=mlkit; continue; fi
  install_one "$h"
done
wait
[ -z "$later" ] || { install_one mlkit; wait; }
for h in $hosts; do
  echo "== $h"
  cat "$prefix/src/fetch-$h.out"
  [ "$(cat "$prefix/src/fetch-$h.status" 2> /dev/null)" = 0 ] || status=1
  rm -f "$prefix/src/fetch-$h.out" "$prefix/src/fetch-$h.status"
done

echo "== installed under $prefix"
[ -x "$prefix/mlton/bin/mlton" ] && "$prefix/mlton/bin/mlton" | head -1
[ -x "$prefix/smlnj-legacy/bin/sml" ] && "$prefix/smlnj-legacy/bin/sml" @SMLversion
[ -x "$prefix/smlnj32/bin/sml" ] && "$prefix/smlnj32/bin/sml" @SMLversion
[ -x "$prefix/smlnj-dev/bin/sml" ] && "$prefix/smlnj-dev/bin/sml" @SMLversion
[ -x "$prefix/polyml/bin/poly" ] && "$prefix/polyml/bin/poly" -v
[ -x "$prefix/mlkit/bin/mlkit" ] && "$prefix/mlkit/bin/mlkit" --version | head -1
exit $status

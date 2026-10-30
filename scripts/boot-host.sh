#!/bin/sh
# Choose the compiler that builds stage 0 (build/bootstrap/rune.rbc).
#   scripts/boot-host.sh --select
# Prints one name on stdout: rune, polyml or mlton, or the name in BOOTHOST.
# The order is the Rune release scripts/fetch-hosts.sh installs, then
# Poly/ML, then MLton. The release compiles the current sources against the
# Basis it ships, as Poly/ML and MLton do against theirs. BOOTHOST names one
# compiler and skips the rest (mlton, polyml, smlnj-legacy, smlnj32,
# smlnj-dev, mlkit or rune).
set -eu
cd "$(dirname "$0")/.."

prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
ver=${RUNE_BOOT_VERSION:-0.1}
polyc=${POLYC:-$prefix/polyml/bin/polyc}
mltonc=${MLTON:-$prefix/mlton/bin/mlton}
rune=$prefix/rune/bin/rune
vm=$prefix/rune/bin/runevm

if [ "${1:-}" != --select ]; then
  echo "usage: scripts/boot-host.sh --select" >&2
  exit 2
fi

mkdir -p build/bootstrap

fetch_rune() {
  if sh scripts/fetch-hosts.sh rune > build/bootstrap/fetch-rune.log 2>&1; then
    echo "boot-host: installed Rune $ver" >&2
    return 0
  fi
  echo "boot-host: the Rune $ver release is not available" >&2
  tail -n 20 build/bootstrap/fetch-rune.log >&2 || true
  return 1
}

if [ -n "${BOOTHOST:-}" ]; then
  if [ "$BOOTHOST" = rune ] && [ ! -x "$rune" ]; then
    fetch_rune || exit 1
  fi
  printf '%s\n' "$BOOTHOST"
  exit 0
fi

if [ ! -x "$rune" ]; then
  fetch_rune || true
fi
if [ -x "$rune" ] && [ -x "$vm" ]; then
  printf '%s\n' rune
  exit 0
fi
if [ -x "$polyc" ]; then
  printf '%s\n' polyml
  exit 0
fi
if [ -x "$mltonc" ]; then
  printf '%s\n' mlton
  exit 0
fi
echo "boot-host: no bootstrap compiler left. Install Poly/ML or MLton with make hosts, or set BOOTHOST." >&2
exit 1

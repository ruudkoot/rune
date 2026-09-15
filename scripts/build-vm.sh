#!/bin/sh
set -efu
mkdir -p build/vm
{
    printf '%s\n' "${CC:-cc}" "${CFLAGS:--O2}"
    cksum vm/vm.c vm/opcode.h scripts/build-vm.sh
} > build/vm/fingerprint.new
if [ -x build/vm/rune-vm ] && [ -f build/vm/fingerprint ] && cmp -s build/vm/fingerprint.new build/vm/fingerprint; then
    rm build/vm/fingerprint.new
    exit 0
fi
# CFLAGS is a whitespace-separated flag list. Disable pathname expansion above.
"${CC:-cc}" -std=c11 -Wall -Wextra -Wpedantic -Werror ${CFLAGS:--O2} vm/vm.c -o build/vm/rune-vm.new
mv build/vm/rune-vm.new build/vm/rune-vm
mv build/vm/fingerprint.new build/vm/fingerprint

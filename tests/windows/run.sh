#!/bin/sh
# Native W-API oracle and SML integration for the Windows text boundary.
# Each worktree has its own NTFS staging root (tests/windows-dir.sh).
set -eu
cd "$(dirname "$0")/../.."
root=$PWD
rune=${RUNE:-bin/rune}
win64=${WINCC:-x86_64-w64-mingw32-gcc}
win32=${WINCC32:-i686-w64-mingw32-gcc}
stage=$(sh tests/windows-dir.sh)/text
out=$root/tests/out/windows-text
mkdir -p "$stage" "$out"
for bits in 64 32; do
  if [ "$bits" = 64 ]; then cc=$win64; else cc=$win32; fi
  "$cc" -std=c17 -O2 -Wall -Wextra -Werror -D__USE_MINGW_ANSI_STDIO=1 -municode -Iruntime \
    -o "$out/interop$bits.exe" tests/windows/interop.c -lws2_32 -ladvapi32 -lshell32 -luser32 -lpsapi
  dir=$stage/oracle$bits
  rm -rf "$dir"
  mkdir -p "$dir"
  cp "$out/interop$bits.exe" "$dir/interop.exe"
  (cd "$dir" && ./interop.exe) > "$out/oracle$bits.log" 2>&1 || { cat "$out/oracle$bits.log"; exit 1; }
  echo "PASS windows.text/native-oracle-$bits ($(grep -c '^PASS ' "$out/oracle$bits.log") checks)"
done
for target in stack registers; do
  "$rune" --target="$target" tests/windows/probe.sml -o "$out/probe-$target.rbc"
  if [ "$target" = stack ]; then compiler=rune.stack.rbc; vms='runevm-stack.exe runevm-stack32.exe'
  else compiler=rune.rbc; vms='runevm.exe runevm32.exe'; fi
  for vm in $vms; do
    case $vm in *32.exe) bits=32 ;; *) bits=64 ;; esac
    dir=$stage/$vm
    rm -rf "$dir"
    mkdir -p "$dir"
    cp "$out/interop$bits.exe" "$dir/interop.exe"
    # The VM itself has a Unicode name, so fork must find and launch it too.
    cp "bin/$vm" "$dir/vm-λ.exe"
    cp "$out/probe-$target.rbc" "$dir/probe.rbc"
    cp "bin/$compiler" "$dir/compiler.rbc"
    if command -v wslpath > /dev/null 2>&1; then native_lib=$(wslpath -w "$root/lib")
    elif command -v cygpath > /dev/null 2>&1; then native_lib=$(cygpath -w "$root/lib")
    else native_lib=$root/lib; fi
    (cd "$dir" && ./interop.exe --vm ./vm-λ.exe probe.rbc && \
      ./interop.exe --compile ./vm-λ.exe compiler.rbc "$native_lib" "$target") \
      > "$out/$vm.log" 2>&1 || { cat "$out/$vm.log"; exit 1; }
    echo "PASS windows.text/$vm ($(grep -c '^PASS ' "$out/$vm.log") checks)"
  done
done

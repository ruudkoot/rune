#!/bin/sh
# A program as runeopt translates it, run as runevm would run its bytecode
# (docs/native.md, Tests): every runner of the suites takes it as --vm,
# as it takes bin/runevm-ppc64, and needs to know nothing of native code.
#   scripts/runevm-opt.sh [runevm options] FILE.rbc [args ...]
# The options a native program takes go to it in RUNEVM_OPTIONS (docs/native.md), and
# FILE.rbc, which is its name under runevm, in RUNEVM_NAME; the program
# takes both out of its environment, so that it sees the one it sees under
# runevm. (This is sh, not bash, which changes the variable _.) --restore
# IMAGE makes a program of the program in the image (runeopt --from-image)
# and carries the image on with it. What only runevm does -- --disasm,
# --trace, --resume -- goes to runevm.
# A translation is kept, by the checksum of the bytecode, in RUNEOPT_CACHE
# (tests/out/opt-cache), which the Makefile empties whenever it builds runeopt
# or the runtime again; RUNEOPT chooses the build of runeopt (by default
# the MLton one where it is built, which is the fastest, and every build
# writes the same program: scripts/check-opt-cross.sh), and RUNEOPT_RUNTIME
# and RUNEOPT_CC what it is given as --runtime and --cc (make test-native-asan).
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
vm=${RUNEVM:-$root/bin/runevm}
runeopt=${RUNEOPT:-}
if [ -z "$runeopt" ]; then
  if [ -x "$root/bin/runeopt-mlton" ]; then runeopt=$root/bin/runeopt-mlton; else runeopt=$root/bin/runeopt; fi
fi
cache=${RUNEOPT_CACHE:-$root/tests/out/opt-cache}

options=""
while [ $# -gt 0 ]; do
  case $1 in
    --count|--stats|--emulate-fork|--checked) options="$options $1"; shift ;;
    --heap-size|--heap-fill|--gc-stress) options="$options $1 ${2:-}"; shift 2 ;;
    --restore)
      image=${2:-}
      [ -f "$image" ] || exec "$vm" "$@"
      mkdir -p "$cache"
      exe=$cache/image.$$
      if ! "$runeopt" ${RUNEOPT_RUNTIME:+--runtime "$RUNEOPT_RUNTIME"} ${RUNEOPT_CC:+--cc "$RUNEOPT_CC"} \
           --from-image "$image" -o "$exe" > "$exe.log" 2>&1; then
        sed 's/^runeopt: /runevm: /' "$exe.log" >&2
        rm -f "$exe" "$exe.log" "$exe.rbc" "$exe.s"
        exit 2
      fi
      rm -f "$exe.log"
      RUNEVM_OPTIONS="${RUNEVM_OPTIONS:-}$options --restore $image" exec "$exe" ;;
    --disasm|--trace|--resume|--version|--help) exec "$vm" "$@" ;;
    -*) exec "$vm" "$@" ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || exec "$vm"
rbc=$1
shift
[ -f "$rbc" ] || exec "$vm" $options "$rbc" "$@"

mkdir -p "$cache"
sum=$(sha256sum < "$rbc" | cut -c1-32)
exe=$cache/$sum
if [ ! -x "$exe" ]; then
  # into a name of its own, then into place: runners run programs in parallel
  tmp=$cache/$sum.$$
  if ! "$runeopt" ${RUNEOPT_RUNTIME:+--runtime "$RUNEOPT_RUNTIME"} ${RUNEOPT_CC:+--cc "$RUNEOPT_CC"} \
       "$rbc" -o "$tmp" > "$tmp.log" 2>&1; then
    sed 's/^runeopt: /runevm: /' "$tmp.log" >&2
    rm -f "$tmp" "$tmp.log" "$tmp.s"
    exit 2
  fi
  rm -f "$tmp.log"
  mv -f "$tmp" "$exe"
fi
RUNEVM_OPTIONS="${RUNEVM_OPTIONS:-}$options" RUNEVM_NAME=$rbc exec "$exe" "$@"

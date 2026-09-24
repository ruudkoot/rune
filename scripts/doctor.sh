#!/bin/sh
# Check that the tools Rune's build and test targets need are installed and
# work, and say how to install the ones that are not.
#   scripts/doctor.sh [--quiet] [--scope SCOPE]...
# Scopes (default: all):
#   vm      C99 compiler for bin/runevm
#   mlton smlnj smlnj32 polyml   the SML system behind bin/rune-<scope>: the
#           release that scripts/fetch-hosts.sh installed (`make hosts`)
#   check   the test runners (tests/run-tests.sh, scripts/check-*.sh)
#   asan    make vm-asan
#   sys     POSIX headers of the VM's system layer (vm/sys_posix.c)
#   matrix  fetching and building the host compilers (scripts/fetch-hosts.sh)
#   perf    optional profiling tools
#   native  what a program of runeopt needs (make test-native): cc that
#           assembles and links x86-64 code with its line table; the
#           debuggers and DWARF readers are optional.
#           Only on Linux for x86-64: elsewhere there is nothing to check
#   windows mingw-w64 for both Windows VMs (make windows), and whether an
#           .exe runs here (make test-windows); not part of all, since
#           nothing else needs it
#   portability  a 32-bit x86 compiler and a big-endian 64-bit PowerPC one,
#           with qemu to run the latter (make portability,
#           make test-portability); not part of all either
#   build = vm mlton      hosts = mlton smlnj smlnj32 polyml
#   all = everything but windows
# Tools every target needs (sh, make, awk, ...) are checked with any scope.
# Exit status: 0 when everything required by the scopes is present, else 1.
# Optional tools only produce warnings. With --quiet only problems are printed.
set -u
quiet=0
scopes=""
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) quiet=1; shift ;;
    --scope) scopes="$scopes $2"; shift 2 ;;
    *) echo "usage: scripts/doctor.sh [--quiet] [--scope SCOPE]..." >&2; exit 2 ;;
  esac
done
[ -n "$scopes" ] || scopes=all
expanded=""
for s in $scopes; do
  case "$s" in
    all) expanded="$expanded vm mlton smlnj smlnj32 polyml check asan sys matrix perf native" ;;
    build) expanded="$expanded vm mlton" ;;
    hosts) expanded="$expanded mlton smlnj smlnj32 polyml" ;;
    vm|mlton|smlnj|smlnj32|polyml|check|asan|sys|matrix|perf|native|windows|portability) expanded="$expanded $s" ;;
    *) echo "doctor: unknown scope '$s'" >&2; exit 2 ;;
  esac
done
scopes=$expanded
in_scope() { case " $scopes " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

cd "$(dirname "$0")/.."
tmp=$(mktemp -d "${TMPDIR:-/tmp}/rune-doctor.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

CC=${CC:-cc}
MAKE_CMD=${MAKE:-make}
# The host SML systems: those of scripts/fetch-hosts.sh, never the machine's.
hosts=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
MLTON=${MLTON:-$hosts/mlton/bin/mlton}
SMLNJ=${SMLNJ:-$hosts/smlnj/bin/sml}
SMLNJ32=${SMLNJ32:-$hosts/smlnj32/bin/sml}
POLYC=${POLYC:-$hosts/polyml/bin/polyc}
POLY=${POLY:-$(dirname "$POLYC")/poly}
WINCC=${WINCC:-x86_64-w64-mingw32-gcc}
WINCC32=${WINCC32:-i686-w64-mingw32-gcc}

# ---------------------------------------------------------------- packages
if command -v apt-get > /dev/null 2>&1; then pm=apt
elif command -v dnf > /dev/null 2>&1; then pm=dnf
elif command -v pacman > /dev/null 2>&1; then pm=pacman
elif command -v brew > /dev/null 2>&1; then pm=brew
else pm=none
fi

# pkg THING: the package that provides THING with the detected package
# manager ("-" when there is none; the hint then names the upstream site).
pkg() {
  case "$pm:$1" in
    apt:cc) echo build-essential ;;       dnf:cc) echo gcc ;;
    pacman:cc) echo base-devel ;;         brew:cc) echo gcc ;;
    apt:cxx) echo g++ ;;                  dnf:cxx) echo gcc-c++ ;;
    pacman:cxx) echo base-devel ;;        brew:cxx) echo gcc ;;
    apt:asan) echo libasan8 libubsan1 ;;  dnf:asan) echo libasan libubsan ;;
    apt:gmp) echo libgmp-dev ;;           dnf:gmp) echo gmp-devel ;;
    pacman:gmp) echo gmp ;;               brew:gmp) echo gmp ;;
    apt:m32) echo gcc-multilib ;;         dnf:m32) echo glibc-devel.i686 libgcc.i686 ;;
    apt:mingw64) echo gcc-mingw-w64-x86-64 ;;  dnf:mingw64) echo mingw64-gcc ;;
    apt:mingw32) echo gcc-mingw-w64-i686 ;;    dnf:mingw32) echo mingw32-gcc ;;
    pacman:mingw*) echo mingw-w64-gcc ;;       brew:mingw*) echo mingw-w64 ;;
    apt:coreutils) echo coreutils ;;      dnf:coreutils) echo coreutils ;;
    pacman:coreutils) echo coreutils ;;   brew:coreutils) echo coreutils ;;
    apt:findutils) echo findutils ;;      dnf:findutils) echo findutils ;;
    pacman:findutils) echo findutils ;;   brew:findutils) echo findutils ;;
    apt:xz) echo xz-utils ;;              *:xz) echo xz ;;
    apt:gprof) echo binutils ;;           *:gprof) echo binutils ;;
    *:readelf|*:addr2line) echo binutils ;;
    apt:dwarfdump) echo dwarfdump ;;      *:dwarfdump) echo libdwarf-tools ;;
    apt:llvm-dwarfdump) echo llvm ;;      *:llvm-dwarfdump) echo llvm ;;
    *:gdb|*:lldb|*:bash) echo "$1" ;;
    none:*) echo - ;;
    *:make|*:gawk|*:sed|*:grep|*:diffutils|*:curl|*:tar|*:valgrind) echo "$1" ;;
    *) echo - ;;
  esac
}

upstream() {
  case "$1" in
    hosts) echo "run: make hosts" ;;
    *) echo "" ;;
  esac
}

# ---------------------------------------------------------------- reporting
missing=0
install=""
manual=""

ok() { [ $quiet = 1 ] || printf '  ok       %-10s %s\n' "$1" "$2"; }
warn() { printf '  warn     %-10s %s\n' "$1" "$2"; }
note() { [ $quiet = 1 ] || printf '  note     %-10s %s\n' "$1" "$2"; }
# bad WHAT MESSAGE THING: a required tool is missing or broken.
bad() {
  printf '  MISSING  %-10s %s\n' "$1" "$2"
  missing=$((missing + 1))
  p=$(pkg "$3")
  if [ "$p" = - ]; then
    u=$(upstream "$3")
    case "$u" in
      "run: "*) manual="$manual\n    $1: ${u#run: }" ;;
      ?*) manual="$manual\n    $1: install from $u" ;;
    esac
  else
    for q in $p; do
      case " $install " in *" $q "*) ;; *) install="$install $q" ;; esac
    done
  fi
}
section() { [ $quiet = 1 ] || echo "$1"; }

# have TOOL THING: TOOL is on the PATH, else report it missing.
have() {
  if path=$(command -v "$1" 2> /dev/null); then ok "$1" "$path"
  else bad "$1" "not found on PATH" "$2"
  fi
}

# ---------------------------------------------------------------- common
section "common tools"
for t in awk sed grep; do have $t "$(case $t in awk) echo gawk ;; *) echo $t ;; esac)"; done
for t in cmp diff; do have $t diffutils; done
for t in mktemp head sort uniq; do have $t coreutils; done
if v=$("$MAKE_CMD" --version 2> /dev/null | head -1); then
  case "$v" in
    "GNU Make "*)
      n=${v#GNU Make }
      major=${n%%.*}
      rest=${n#*.}
      minor=${rest%%[!0-9]*}
      # Grouped targets (`&:`) need GNU Make 4.3.
      if [ "$major" -gt 4 ] || { [ "$major" -eq 4 ] && [ "${minor:-0}" -ge 3 ]; }; then ok make "$v"
      else bad make "$v is too old; GNU Make 4.3 or later is required" make
      fi ;;
    *) bad make "not GNU Make ($v)" make ;;
  esac
else
  bad make "not found on PATH" make
fi

# cc_probe NAME FLAGS...: compile (and run) $tmp/NAME.c with $CC.
cc_probe() {
  name=$1
  shift
  "$CC" "$@" -o "$tmp/$name" "$tmp/$name.c" -lm > "$tmp/$name.log" 2>&1 && "$tmp/$name" > /dev/null 2>> "$tmp/$name.log"
}

# ---------------------------------------------------------------- vm
if in_scope vm || in_scope asan || in_scope sys; then
  section "C compiler (bin/runevm)"
  cat > "$tmp/c99.c" << 'EOF'
#include <math.h>
#include <stdint.h>
#include <stdio.h>
int main(void) { for (int64_t i = 0; i < 1; i++) { if (lround(sqrt(4.0)) != 2) return 1; } return 0; }
EOF
  if ! command -v "$CC" > /dev/null 2>&1; then bad "$CC" "not found on PATH (set CC=...)" cc
  elif cc_probe c99 -std=c99 -O2; then ok "$CC" "$("$CC" --version 2> /dev/null | head -1)"
  else bad "$CC" "cannot compile and link a C99 program with -lm: $(head -1 "$tmp/c99.log")" cc
  fi
fi

if in_scope asan; then
  cp "$tmp/c99.c" "$tmp/asan.c"
  if cc_probe asan -std=c99 -fsanitize=address,undefined; then ok asan "-fsanitize=address,undefined works"
  else bad asan "$CC -fsanitize=address,undefined fails: $(head -1 "$tmp/asan.log")" asan
  fi
fi

if in_scope sys; then
  cat > "$tmp/sys.c" << 'EOF'
#define _POSIX_C_SOURCE 200809L
#include <dirent.h>
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/times.h>
#include <sys/un.h>
#include <sys/utsname.h>
#include <sys/wait.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>
int main(void) { struct pollfd p; p.fd = 0; (void)p; return 0; }
EOF
  if cc_probe sys -std=c99; then ok posix "POSIX.1-2008 headers present"
  else bad posix "POSIX headers missing: $(head -1 "$tmp/sys.log")" cc
  fi
fi

# ---------------------------------------------------------------- SML systems
cat > "$tmp/hello.sml" << 'EOF'
val () = print "ok\n"
EOF

if in_scope mlton; then
  section "MLton (bin/rune-mlton)"
  if [ ! -x "$MLTON" ]; then bad mlton "not installed: $MLTON" hosts
  elif (cd "$tmp" && "$MLTON" -output hello-mlton hello.sml > mlton.log 2>&1 && ./hello-mlton > /dev/null); then
    ok mlton "$("$MLTON" 2>&1 | head -1) ($MLTON)"
  else
    # The usual cause is a missing GMP development package.
    bad mlton "cannot compile a program: $(head -1 "$tmp/mlton.log")" gmp
  fi
fi

# smlnj_scope NAME SML WHAT: SML/NJ at SML and its ml-build.
smlnj_scope() {
  section "SML/NJ, $3 (bin/rune-$1)"
  if [ ! -x "$2" ]; then bad "$1" "not installed: $2" hosts
  elif v=$("$2" @SMLversion 2> /dev/null); then ok "$1" "$v ($2)"
  else bad "$1" "does not run: $2" hosts
  fi
  if [ -x "$(dirname "$2")/ml-build" ]; then ok ml-build "$(dirname "$2")/ml-build"
  else bad ml-build "not installed: $(dirname "$2")/ml-build" hosts
  fi
}
in_scope smlnj && smlnj_scope smlnj "$SMLNJ" 64-bit
in_scope smlnj32 && smlnj_scope smlnj32 "$SMLNJ32" 32-bit

if in_scope polyml; then
  section "Poly/ML (bin/rune-polyml)"
  if [ ! -x "$POLY" ]; then bad poly "not installed: $POLY" hosts
  else ok poly "$("$POLY" -v 2> /dev/null | head -1) ($POLY)"
  fi
  if [ ! -x "$POLYC" ]; then bad polyc "not installed: $POLYC" hosts
  elif (cd "$tmp" && echo 'fun main () = ()' > hello-main.sml &&
        "$POLYC" -o hello-poly hello-main.sml > polyc.log 2>&1 && ./hello-poly > /dev/null); then
    ok polyc "links programs"
  else bad polyc "cannot compile a program: $(head -1 "$tmp/polyc.log")" hosts
  fi
fi

# ---------------------------------------------------------------- check
if in_scope check; then
  section "test runners"
  if [ "$(printf 'a\nb\n' | xargs -n 1 -P 2 echo 2> /dev/null | sort | tr -d '\n')" = ab ]; then ok xargs "supports -P"
  else bad xargs "xargs -n 1 -P N does not work" findutils
  fi
  if timeout 5 true 2> /dev/null; then ok timeout "$(command -v timeout)"
  else bad timeout "not found on PATH" coreutils
  fi
  ok cpus "$(sh scripts/ncpus.sh) (parallel jobs)"
fi

# ---------------------------------------------------------------- matrix
if in_scope matrix; then
  section "host matrix (scripts/fetch-hosts.sh)"
  if path=$(command -v curl 2> /dev/null || command -v wget 2> /dev/null); then ok download "$path"
  else bad download "neither curl nor wget found" curl
  fi
  have tar tar
  have xz xz
  have gzip gzip
  have g++ cxx
  printf '#include <gmp.h>\nint main(void) { mpz_t x; mpz_init(x); mpz_clear(x); return 0; }\n' > "$tmp/gmp.c"
  if "$CC" -o "$tmp/gmp" "$tmp/gmp.c" -lgmp > "$tmp/gmp.log" 2>&1; then ok gmp "headers and library present"
  else bad gmp "cannot compile against GMP: $(head -1 "$tmp/gmp.log")" gmp
  fi
  # the 32-bit SML/NJ compiles its runtime with -m32
  cp "$tmp/c99.c" "$tmp/m32.c" 2> /dev/null || printf 'int main(void) { return 0; }\n' > "$tmp/m32.c"
  if cc_probe m32 -m32; then ok m32 "$CC -m32 builds and runs 32-bit programs"
  else bad m32 "$CC -m32 fails (the 32-bit SML/NJ needs it): $(head -1 "$tmp/m32.log")" m32
  fi
  prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
  # Free space on the file system that will hold the prefix (the nearest
  # existing ancestor; doctor creates nothing).
  where=$prefix
  while [ ! -d "$where" ] && [ "$where" != / ] && [ "$where" != . ]; do where=$(dirname "$where"); done
  free=$(df -Pk "$where" 2> /dev/null | awk 'NR == 2 { print int($4 / 1048576) }')
  if [ -n "$free" ] && [ "$free" -ge 3 ]; then ok disk "$free GB free under $prefix"
  else warn disk "less than 3 GB free under $prefix (${free:-?} GB)"
  fi
  for h in mlton smlnj smlnj32 polyml; do
    if [ -d "$prefix/$h" ]; then ok "$h" "installed under $prefix/$h"
    else note "$h" "not installed under $prefix/$h (run: make hosts)"
    fi
  done
fi

# ---------------------------------------------------------------- perf
if in_scope perf; then
  section "profiling (optional)"
  for t in gprof valgrind; do
    if path=$(command -v $t 2> /dev/null); then ok $t "$path"
    else warn $t "not found (optional; package: $(pkg $t))"
    fi
  done
fi

# ---------------------------------------------------------------- native
if in_scope native; then
  section "native code (runeopt, make test-native)"
  if [ "$(uname -s) $(uname -m)" != "Linux x86_64" ]; then
    note native "runeopt makes programs for Linux on x86-64, and this is $(uname -s) $(uname -m): make test-native skips them"
  else
    # what the code of runeopt is: x86-64, with a line table, assembled and
    # linked by cc into a position-independent executable
    printf '\t.file 1 "native.sml"\n\t.text\n\t.globl main\n\t.type main, @function\nmain:\n\t.loc 1 1 1\n\txor %%eax, %%eax\n\tret\n\t.section .note.GNU-stack,"",@progbits\n' > "$tmp/native.s"
    if "$CC" -o "$tmp/native" "$tmp/native.s" > "$tmp/native.log" 2>&1 && "$tmp/native"; then
      ok native "$CC assembles and links x86-64 code"
    else bad native "$CC cannot assemble and link x86-64 code: $(head -1 "$tmp/native.log")" cc
    fi
    for t in gdb lldb readelf addr2line dwarfdump perf; do
      if path=$(command -v $t 2> /dev/null); then ok $t "$path"
      else warn $t "not found (optional: the checks of debug information; package: $(pkg $t))"
      fi
    done
    # llvm-dwarfdump is often installed under the name of its version only
    dump=""
    for d in llvm-dwarfdump $(cd /usr/bin 2> /dev/null && ls llvm-dwarfdump-* 2> /dev/null | sort -t- -k3 -n -r); do
      command -v "$d" > /dev/null 2>&1 && { dump=$d; break; }
    done
    if [ -n "$dump" ]; then ok llvm-dwarfdump "$(command -v "$dump")"
    else warn llvm-dwarfdump "not found (optional; package: $(pkg llvm-dwarfdump))"
    fi
  fi
fi

# ---------------------------------------------------------------- windows
if in_scope windows; then
  section "mingw-w64 (make windows, make test-windows)"
  cat > "$tmp/win.c" << 'EOF'
#include <stdint.h>
#include <stdio.h>
#include <windows.h>
int main(void) { int64_t t = (int64_t)GetTickCount64(); printf("%d\n", t >= 0); return 0; }
EOF
  runs=""
  for w in "64:$WINCC:mingw64" "32:$WINCC32:mingw32"; do
    bits=${w%%:*}; rest=${w#*:}; cc=${rest%:*}; thing=${rest#*:}
    if ! command -v "$cc" > /dev/null 2>&1; then bad "$cc" "not found on PATH (the $bits-bit VM)" "$thing"
    elif "$cc" -std=c99 -O2 -o "$tmp/win$bits.exe" "$tmp/win.c" > "$tmp/win$bits.log" 2>&1; then
      ok "$cc" "$("$cc" --version 2> /dev/null | head -1)"
      runs="$runs $tmp/win$bits.exe"
    else bad "$cc" "cannot compile a C99 program for Windows: $(head -1 "$tmp/win$bits.log")" "$thing"
    fi
  done
  # Running one is only for make test-windows, and only Windows or WSL can.
  for exe in $runs; do
    if [ "$("$exe" 2> /dev/null | tr -d '\r')" = 1 ]; then ok run "$(basename "$exe") runs here"
    else warn run "$(basename "$exe") does not run here: make test-windows needs Windows or WSL"
    fi
  done
fi

if in_scope portability; then
  section "another machine's VM (make portability, make test-portability)"
  cat > "$tmp/port.c" << 'EOF'
#include <stdint.h>
#include <stdio.h>
int main(void) {
    uint32_t one = 1;
    /* what the VM depends on: eight bytes of payload beside a tag, and the
       order of the bytes, which it must not care about */
    printf("%d %d\n", (int)sizeof(int64_t), *(char *)&one ? 1 : 0);
    return 0;
}
EOF
  if ${PORTCC32:-cc} -std=c99 -m32 -o "$tmp/port32" "$tmp/port.c" > "$tmp/port32.log" 2>&1; then
    ok "${PORTCC32:-cc} -m32" "compiles for a 32-bit x86"
  else
    bad "${PORTCC32:-cc} -m32" "cannot compile for a 32-bit x86: $(head -1 "$tmp/port32.log")" gcc-multilib
  fi
  ppcroot=${PPCROOT:-/usr/powerpc64-linux-gnu}
  if ! command -v "${PPCCC:-clang}" > /dev/null 2>&1; then
    bad "${PPCCC:-clang}" "not found on PATH (the PowerPC VM)" clang
  elif [ ! -f "$ppcroot/lib/libc.so.6" ]; then
    bad "$ppcroot" "no libc for powerpc64 there (PPCROOT names it)" libc6-dev-ppc64-cross
  elif "${PPCCC:-clang}" -std=c99 --target=powerpc64-linux-gnu -B"$ppcroot/bin" -L"$ppcroot/lib" \
        -I"$ppcroot/include" -Wl,-dynamic-linker,"$ppcroot/lib/ld64.so.1" \
        -o "$tmp/portppc" "$tmp/port.c" > "$tmp/portppc.log" 2>&1; then
    ok "${PPCCC:-clang}" "compiles for a big-endian powerpc64"
  else
    bad "${PPCCC:-clang}" "cannot compile for powerpc64: $(head -1 "$tmp/portppc.log")" binutils-powerpc64-linux-gnu
  fi
  qemu=${QEMUPPC:-qemu-ppc64}
  if ! command -v "${qemu%% *}" > /dev/null 2>&1; then
    bad "${qemu%% *}" "not found on PATH: make test-portability runs the PowerPC VM with it" qemu-user
  elif [ -x "$tmp/portppc" ] && [ "$("${qemu%% *}" -L "$ppcroot" "$tmp/portppc" 2> /dev/null)" = "8 0" ]; then
    ok "${qemu%% *}" "runs a big-endian powerpc64 program"
  else
    bad "${qemu%% *}" "cannot run a powerpc64 program here" qemu-user
  fi
fi

# ---------------------------------------------------------------- summary
if [ "$missing" -eq 0 ]; then
  [ $quiet = 1 ] || echo "doctor: environment is ready ($(echo $scopes | tr ' ' ','))"
  exit 0
fi
echo "doctor: $missing required item(s) missing"
if [ -n "$install" ]; then
  case "$pm" in
    apt) echo "  install with: sudo apt install$install" ;;
    dnf) echo "  install with: sudo dnf install$install" ;;
    pacman) echo "  install with: sudo pacman -S$install" ;;
    brew) echo "  install with: brew install$install" ;;
  esac
fi
# shellcheck disable=SC2059
[ -z "$manual" ] || printf "  not packaged for this system:$manual\n"
echo "  (make DOCTOR=no ... skips this check)"
exit 1

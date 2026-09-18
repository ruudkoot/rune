#!/bin/sh
# Check that the tools Rune's build and test targets need are installed and
# work, and say how to install the ones that are not.
#   scripts/doctor.sh [--quiet] [--scope SCOPE]...
# Scopes (default: all):
#   vm      C99 compiler for bin/runevm
#   mlton smlnj polyml   the SML system behind bin/rune-<scope>
#   check   the test runners (tests/run-tests.sh, scripts/check-*.sh)
#   asan    make vm-asan
#   sys     POSIX headers of the VM's system layer (vm/sys_posix.c)
#   matrix  fetching and building current host compilers (scripts/fetch-hosts.sh)
#   perf    optional profiling tools
#   build = vm mlton      all3 = mlton smlnj polyml      all = everything
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
    all) expanded="$expanded vm mlton smlnj polyml check asan sys matrix perf" ;;
    build) expanded="$expanded vm mlton" ;;
    all3) expanded="$expanded mlton smlnj polyml" ;;
    vm|mlton|smlnj|polyml|check|asan|sys|matrix|perf) expanded="$expanded $s" ;;
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
MLTON=${MLTON:-mlton}
SMLNJ=${SMLNJ:-sml}
POLY=${POLY:-poly}
POLYC=${POLYC:-polyc}

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
    apt:mlton) echo mlton ;;              dnf:mlton) echo mlton ;;
    brew:mlton) echo mlton ;;
    apt:smlnj) echo smlnj ;;              brew:smlnj) echo smlnj ;;
    apt:polyml) echo polyml libpolyml-dev ;;  dnf:polyml) echo polyml polyml-devel ;;
    pacman:polyml) echo polyml ;;         brew:polyml) echo polyml ;;
    apt:coreutils) echo coreutils ;;      dnf:coreutils) echo coreutils ;;
    pacman:coreutils) echo coreutils ;;   brew:coreutils) echo coreutils ;;
    apt:findutils) echo findutils ;;      dnf:findutils) echo findutils ;;
    pacman:findutils) echo findutils ;;   brew:findutils) echo findutils ;;
    apt:xz) echo xz-utils ;;              *:xz) echo xz ;;
    apt:gprof) echo binutils ;;           *:gprof) echo binutils ;;
    none:*) echo - ;;
    *:make|*:gawk|*:sed|*:grep|*:diffutils|*:curl|*:tar|*:valgrind) echo "$1" ;;
    *) echo - ;;
  esac
}

upstream() {
  case "$1" in
    mlton) echo "http://mlton.org" ;;
    smlnj) echo "https://www.smlnj.org" ;;
    polyml) echo "https://polyml.org" ;;
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
    [ -n "$u" ] && manual="$manual\n    $1: install from $u"
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
  if ! command -v "$MLTON" > /dev/null 2>&1; then bad mlton "not found on PATH" mlton
  elif (cd "$tmp" && "$MLTON" -output hello-mlton hello.sml > mlton.log 2>&1 && ./hello-mlton > /dev/null); then
    ok mlton "$("$MLTON" 2>&1 | head -1) ($(command -v "$MLTON"))"
  else
    # The usual cause is a missing GMP development package.
    bad mlton "cannot compile a program: $(head -1 "$tmp/mlton.log")" gmp
  fi
fi

if in_scope smlnj; then
  section "SML/NJ (bin/rune-smlnj)"
  if ! command -v "$SMLNJ" > /dev/null 2>&1; then bad sml "not found on PATH" smlnj
  elif v=$("$SMLNJ" @SMLversion 2> /dev/null); then ok sml "$v ($(command -v "$SMLNJ"))"
  else bad sml "does not run (a 32-bit SML/NJ needs 32-bit runtime libraries)" smlnj
  fi
  have ml-build smlnj
fi

if in_scope polyml; then
  section "Poly/ML (bin/rune-polyml)"
  if ! command -v "$POLY" > /dev/null 2>&1; then bad poly "not found on PATH" polyml
  else ok poly "$("$POLY" -v 2> /dev/null | head -1) ($(command -v "$POLY"))"
  fi
  if ! command -v "$POLYC" > /dev/null 2>&1; then bad polyc "not found on PATH" polyml
  elif (cd "$tmp" && echo 'fun main () = ()' > hello-main.sml &&
        "$POLYC" -o hello-poly hello-main.sml > polyc.log 2>&1 && ./hello-poly > /dev/null); then
    ok polyc "links programs"
  else bad polyc "cannot compile a program: $(head -1 "$tmp/polyc.log")" polyml
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
  prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
  # Free space on the file system that will hold the prefix (the nearest
  # existing ancestor; doctor creates nothing).
  where=$prefix
  while [ ! -d "$where" ] && [ "$where" != / ] && [ "$where" != . ]; do where=$(dirname "$where"); done
  free=$(df -Pk "$where" 2> /dev/null | awk 'NR == 2 { print int($4 / 1048576) }')
  if [ -n "$free" ] && [ "$free" -ge 3 ]; then ok disk "$free GB free under $prefix"
  else warn disk "less than 3 GB free under $prefix (${free:-?} GB)"
  fi
  for h in mlton smlnj polyml; do
    if [ -d "$prefix/$h" ]; then ok "$h@cur" "installed under $prefix/$h"
    else note "$h@cur" "no current release under $prefix/$h (run: make hosts)"
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

#!/bin/bash
# SessionStart hook of Claude Code on the web: make a fresh cloud machine
# ready to build and test Rune, as cloud/SETUP.md describes, before the
# session begins. Elsewhere (a local session) it does nothing.
#
# Every step checks first and does only what is missing, so a resumed
# session, or a container whose state was kept, costs a few seconds:
#  1. the commit identities of AGENTS.md, which the container resets;
#  2. the packages of cloud/SETUP.md (the ones make doctor asks for, the
#     optional debug, Windows and portability tools), and a perf that runs
#     under the VM's kernel;
#  3. make hosts: MLton, SML/NJ (64 and 32 bits) and Poly/ML, from the
#     cache of the branch cloud-cache where it fits this machine;
#  4. make doctor, and make envcheck, all of it at the start of a session
#     and on a resume only what the machine is, whose outcome it
#     summarises, with a warning when the machine changed.
# It runs synchronously: the session begins once it is done (about 30 s
# with the cache of the hosts, some minutes without). Where Claude Code
# does not run it (an environment of several repositories), the
# environment's setup script can (cloud/SETUP.md). Either way it keeps its
# state in /tmp/rune-session-start.status: "running" while it works, then
# "ready" or "problems", followed by the lines it reports. The full output
# is in /tmp/rune-session-start.log.
set -uo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = true ] || exit 0
input=$(cat 2>/dev/null || true)
source=$(printf '%s' "$input" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p')
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
log=/tmp/rune-session-start.log
status=/tmp/rune-session-start.status
report=/tmp/rune-session-start.report
: > "$log"
: > "$report"
echo "running (since $(date -u '+%H:%M:%S UTC'); see $log)" > "$status"
say() { echo "session-start: $*" | tee -a "$report"; }
problems=0

# 1. The commit identity (AGENTS.md): Ruud Koot the author, Claude the
#    committer, whose commits the session can sign (GitHub shows them
#    verified). The environment's GIT_AUTHOR_* and GIT_COMMITTER_* take
#    precedence when they are set.
if [ "$(git config --global author.email 2>/dev/null)" != inbox@ruudkoot.nl ] ||
   [ "$(git config --global committer.email 2>/dev/null)" != noreply@anthropic.com ]; then
  git config --global author.name "Ruud Koot"
  git config --global author.email inbox@ruudkoot.nl
  git config --global committer.name Claude
  git config --global committer.email noreply@anthropic.com
  say "git identity set: author Ruud Koot <inbox@ruudkoot.nl>, committer Claude <noreply@anthropic.com>"
fi

# 2. Packages (cloud/SETUP.md). libgcc-N-dev-ppc64-cross rather than
#    gcc-powerpc64-linux-gnu, which conflicts with gcc-multilib.
if command -v apt-get > /dev/null 2>&1; then
  v=$(gcc -dumpversion 2> /dev/null | cut -d . -f 1)
  pkgs="libgmp-dev gcc-multilib dwarfdump linux-tools-generic \
        gcc-mingw-w64-x86-64 gcc-mingw-w64-i686 libc6-dev-ppc64-cross \
        binutils-powerpc64-linux-gnu libgcc-${v:-13}-dev-ppc64-cross qemu-user"
  missing=""
  for p in $pkgs; do dpkg -s "$p" > /dev/null 2>&1 || missing="$missing $p"; done
  if [ -n "$missing" ]; then
    say "installing:$missing"
    sudo=""
    [ "$(id -u)" = 0 ] || sudo="sudo -n"
    if ! { $sudo apt-get update -q && DEBIAN_FRONTEND=noninteractive $sudo apt-get install -y -q $missing; } >> "$log" 2>&1; then
      say "apt-get install failed (see $log)"
      problems=1
    fi
  fi
fi
# Ubuntu's /usr/bin/perf refuses a kernel it has no linux-tools package for,
# as the VM's is; the generic binary works (cloud/SETUP.md).
if ! perf --version > /dev/null 2>&1; then
  tools=$(ls -d /usr/lib/linux-tools/*/perf 2> /dev/null | head -1)
  if [ -n "$tools" ] && [ -w /usr/local/bin ]; then
    ln -sf "$tools" /usr/local/bin/perf && say "perf linked to $tools"
  fi
fi

# 3. The host SML systems: from the cache of the branch cloud-cache where
#    one is missing and the cache was made for this kind of machine
#    (scripts/cloud-cache.sh), then make hosts, which builds what is still
#    missing and is a no-op when nothing is.
if sh scripts/cloud-cache.sh restore >> "$log" 2>&1; then
  say "$(grep '^cloud-cache: restored' "$log" | tail -1 | sed 's/^cloud-cache: //')"
fi
if ! make hosts >> "$log" 2>&1; then
  say "make hosts failed (see $log)"
  problems=1
fi

# 4. What is still missing, and what the machine is.
doctor=$(make doctor 2>&1)
[ $? = 0 ] || problems=1
echo "$doctor" >> "$log"
echo "$doctor" | grep -E '^doctor:|MISSING' | sed 's/^/session-start: /' | tee -a "$report"
# At the start of a session all of make envcheck; on a resume only what the
# machine is (under a second), as a restart of the container can move the
# session to another kind of machine behind the same cpuid.
if [ "$source" = startup ] || [ -z "$source" ]; then
  out=/tmp/rune-envcheck.txt
  make envcheck > "$out" 2>&1
else
  out=/tmp/rune-envcheck-identity.txt
  sh scripts/envcheck.sh --identity > "$out" 2>&1
fi
st=$?
grep -E '^  (envcheck\.(known|fingerprint)|cpu\.uarch(_by_instructions)?|mem\.cgroup_limit) ' "$out" |
  sed 's/^  /session-start: /; s/  */ /g' | tee -a "$report"
if [ $st != 0 ]; then
  say "make envcheck could not do everything: see the end of $out, and fix it (docs/envcheck.md)"
  problems=1
fi
grep -q 'envcheck.known  *no' "$out" &&
  say "a new kind of machine: add an entry to cloud/ENVIRONMENT.md (make envcheck ENVCHECK=--markdown)"
cls=$(sed -n 's/^  envcheck\.cpu_class  *//p' "$out")
case "$cls" in
  server*|"") ;;
  *) say "WARNING: NOT KNOWN TO BE A XEON OR AN EPYC: $cls" ;;
esac
was=$(sed -n 's/^  envcheck\.machine_changed  *YES: the last run was on //p' "$out")
if [ -n "$was" ]; then
  say "WARNING: THE MACHINE HAS CHANGED: the last make envcheck ran on $was; timings from it do not hold here: run make envcheck (docs/envcheck.md)"
fi

if [ $problems = 0 ]; then say "ready (full output: $log, $out)"; fi
{ if [ $problems = 0 ]; then echo "ready ($(date -u '+%H:%M:%S UTC'))"; else echo "problems ($(date -u '+%H:%M:%S UTC'))"; fi
  cat "$report"; } > "$status.new" && mv "$status.new" "$status"
rm -f "$report"
exit 0

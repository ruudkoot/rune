#!/bin/sh
# Write the version into build/config.sml, for the compiler, and
# runtime/version.h, for the VM; and the compiler's identity, a hash of its
# sources, into build/config.sml.
# Usage: scripts/gen-version.sh [ROOT_DIR]
#        scripts/gen-version.sh --config PLAN FILE
#        scripts/gen-version.sh --stamp
# The second, run from the top of the checkout, writes FILE, the Config of
# another compiler, whose identity is over its own plan (below). The third
# prints the version alone, as the others would write it, and writes
# nothing: it is the stamp of rune.build's first step, what that step reads
# that is in no file a build can name, git's state (docs/build.md, Generated
# sources), so that a build asks it and not the whole of this.
#
# git decides the version. A tag that points at HEAD and starts with v is a
# release: v1.2.3 is version 1.2.3, and any other tag is ignored. Otherwise
# the version is HEAD's abbreviated hash. -dirty follows either when a
# tracked file differs from HEAD (untracked files do not count, as with
# `git describe --dirty`; git leaves the index alone, which a copy of the
# tree may share).
# Without git or a repository (a tarball, a copy without .git) the files keep
# the version they have, or say "unknown" when there are none; the identity
# is worked out all the same.
#
# The Makefile runs this on every make, so a file is written only when what
# it says changes: its time stays put and nothing is rebuilt for nothing.
# `Runtime.version` is what the VM was built with, so the compiler, the VM and
# the library cannot drift apart. scripts/install.sh writes it into the
# manual pages.
set -eu

config=
stamp=
if [ "${1:-}" = --config ]; then
  [ $# -eq 3 ] || { echo "usage: scripts/gen-version.sh --config PLAN FILE" >&2; exit 2; }
  config=$3
elif [ "${1:-}" = --stamp ]; then
  [ $# -eq 1 ] || { echo "usage: scripts/gen-version.sh --stamp" >&2; exit 2; }
  stamp=1
else
  root=${1:-$(pwd)}
  cd "$root"
  mkdir -p build lib/compiler
fi

if tag=$(git describe --tags --exact-match --match 'v*' HEAD 2> /dev/null) &&
   [ -n "${tag#v}" ]; then
  version=${tag#v}
elif version=$(git rev-parse --short HEAD 2> /dev/null); then
  :
else
  version=
fi
if [ -n "$version" ]; then
  status=0
  git --no-optional-locks diff --quiet HEAD -- 2> /dev/null || status=$?
  [ "$status" -ne 1 ] || version=$version-dirty
elif [ -f build/config.sml ] && [ -f runtime/version.h ]; then
  version=$(sed -n 's/^  val version = "\(.*\)"$/\1/p' build/config.sml)
else
  version=unknown
fi
if [ -n "$stamp" ]; then
  printf '%s\n' "$version"
  exit 0
fi

# The compiler's identity: a hash of what it is compiled from, the same for
# every host that builds it, which the cache of compiled units keys its
# entries by (docs/units.md, The cache): a compiler built from other sources
# finds none of them. It is over the compiler's plan, rune.plan, which `rune
# --plan rune.build` prints and the hosts read their list from
# (docs/building.md, How a host gets its list): the plan, less how it was
# made, and every file of its closure, the libraries' included, less the two
# that hold the identity, build/config.sml and lib/compiler/config.sml. So
# an edit anywhere in what the compiler is made of gives another identity,
# and two makes with none give the same. Another compiler has its own, over
# its own plan, and less its own Config (--config). Worked out on every make,
# as the version is, and written only when it changes.
if command -v sha256sum > /dev/null 2>&1; then sha256=sha256sum
elif command -v shasum > /dev/null 2>&1; then sha256='shasum -a 256'
else sha256=
fi
fail() { echo "gen-version.sh: $*" >&2; exit 3; }
# fresh PLAN: refuse a plan that a build file it was made from has changed
# since, since a host would build what it had listed (with no SHA-256 at
# hand, a plan is trusted)
fresh() {
  [ -n "$sha256" ] || return 0
  inputs=$(awk '$1 == "input" { print $2 }' "$1")
  stale=
  for f in $inputs; do [ -f "$f" ] || stale="$stale $f"; done
  # shellcheck disable=SC2086
  [ -n "$stale" ] || [ -z "$inputs" ] ||
    stale=$($sha256 $inputs | awk 'NR == FNR { if ($1 == "input") want[$2] = $3; next } want[$2] != $1 { print $2 }' "$1" -)
  [ -z "$stale" ] || fail "$1 is stale:$(echo "" $stale) changed since it was printed; \`make plans\` prints it again"
}
# identity PLAN [FILE]: the identity of what PLAN compiles, less FILE
identity() {
  fresh "$1"
  files=$(sh scripts/plan-files.sh "$1") || fail "cannot read $1"
  srcs=
  for f in $files; do
    case $f in build/config.sml | lib/compiler/config.sml | "${2:-build/config.sml}") ;;
      *) [ -f "$f" ] || fail "$1 names $f, which is not there"; srcs="$srcs $f" ;;
    esac
  done
  # shellcheck disable=SC2086
  if [ -n "$sha256" ]; then id=$({ sed '/^provenance$/,$d' "$1"; cat $srcs; } | $sha256 | cut -c1-32)
  else id=$({ sed '/^provenance$/,$d' "$1"; cat $srcs; } | cksum | tr ' ' '-')
  fi
}

# update FILE: FILE.tmp.PID becomes FILE, unless the two are the same (the
# PID, since the steps of make check that run at once each run this)
update() {
  if cmp -s "$1.tmp.$$" "$1"; then rm -f "$1.tmp.$$"; else mv -f "$1.tmp.$$" "$1"; fi
}
# configure FILE IDENTITY: a compiler's Config
configure() {
  cat > "$1.tmp.$$" <<EOC
(* Generated by scripts/gen-version.sh -- do not edit. *)
structure Config =
struct
  val version = "$version"
  val identity = "$2"
end
EOC
  update "$1"
}

if [ -n "$config" ]; then
  identity "$2" "$config"
  configure "$config" "$id"
  exit 0
fi
# every plan a host reads is checked here, since every make runs this
for plan in *.plan; do
  [ ! -f "$plan" ] || fresh "$plan"
done
identity rune.plan
configure build/config.sml "$id"

# Library consumers and installed source trees need the same generated
# identity inside lib; the identity is not over this file either.
cp build/config.sml lib/compiler/config.sml.tmp.$$
update lib/compiler/config.sml

cat > runtime/version.h.tmp.$$ <<EOC
/* Generated by scripts/gen-version.sh -- do not edit. */
#ifndef RUNE_VERSION_H
#define RUNE_VERSION_H
#define RUNE_VERSION "$version"
#endif
EOC
update runtime/version.h

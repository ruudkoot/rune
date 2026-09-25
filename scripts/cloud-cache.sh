#!/bin/sh
# A cache of the host SML systems (`make hosts`) for fresh cloud machines
# (cloud/SETUP.md), kept on the branch cloud-cache of the repository, in
# cloud/cache/, as one commit that each save replaces.
#   scripts/cloud-cache.sh save      pack the installed hosts and push them
#   scripts/cloud-cache.sh restore   unpack them where none is installed
# The hosts are built for one machine and one place: SML/NJ and Poly/ML
# keep the directory they were installed in, and MLton's binary and every
# runtime link against the system's C library. So a cache carries a key --
# the versions, the architecture, the release of the system, the C library
# and the directory -- and is restored only where the key is the same;
# elsewhere `make hosts` builds, as without a cache. What restore unpacks
# is checked against the SHA-256 that save recorded, and make doctor checks
# that each host runs.
# Exit status of restore: 0 when it restored something, 1 when it did not
# (nothing missing, no cache, another key, a bad checksum), which is never
# a failure of the caller: `make hosts` then does the work.
set -eu
cd "$(dirname "$0")/.."
prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
branch=${CLOUD_CACHE_BRANCH:-cloud-cache}
# the versions scripts/fetch-hosts.sh installs
eval "$(grep -E '^(MLTON|SMLNJ|POLYML)_VERSION=' scripts/fetch-hosts.sh)"
hosts="mlton:$MLTON_VERSION smlnj:$SMLNJ_VERSION smlnj32:$SMLNJ_VERSION polyml:$POLYML_VERSION"

key() {
  . /etc/os-release 2> /dev/null || true
  printf 'mlton-%s smlnj-%s polyml-%s %s %s-%s glibc-%s %s\n' "$MLTON_VERSION" "$SMLNJ_VERSION" \
    "$POLYML_VERSION" "$(uname -m)" "${ID:-unknown}" "${VERSION_ID:-unknown}" \
    "$(getconf GNU_LIBC_VERSION 2> /dev/null | awk '{ print $2 }')" "$prefix"
}
say() { echo "cloud-cache: $*"; }
url=$(git remote get-url origin)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/cloud-cache.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

case "${1:-}" in
save)
  for h in $hosts; do
    n=${h%%:*}; v=${h#*:}
    [ -d "$prefix/$n-$v" ] && [ "$(readlink "$prefix/$n")" = "$n-$v" ] ||
      { say "$n $v is not installed under $prefix: run make hosts first"; exit 1; }
  done
  dirs=""
  for h in $hosts; do dirs="$dirs ${h%%:*}-${h#*:} ${h%%:*}"; done
  mkdir -p "$tmp/tree/cloud/cache"
  c=$tmp/tree/cloud/cache
  # shellcheck disable=SC2086
  tar -C "$prefix" -cf - $dirs | xz -T0 -6 > "$tmp/hosts.tar.xz"
  sum=$(sha256sum "$tmp/hosts.tar.xz" | cut -d ' ' -f 1)
  # parts under GitHub's 50 MB warning (100 MB is refused)
  (cd "$c" && split -b 45m -d -a 2 "$tmp/hosts.tar.xz" hosts.tar.xz.)
  {
    echo "key $(key)"
    echo "sha256 $sum"
    echo "parts $(cd "$c" && ls hosts.tar.xz.* | tr '\n' ' ' | sed 's/ $//')"
    echo "built $(date -u '+%Y-%m-%d %H:%M UTC') on $(uname -r), by scripts/fetch-hosts.sh from the releases it names"
  } > "$c/MANIFEST"
  cat > "$c/README.md" << 'EOF'
# The cloud cache

The host SML systems of `make hosts`, packed by `scripts/cloud-cache.sh
save` and unpacked on a fresh cloud machine by `scripts/cloud-cache.sh
restore` (the session-start hook, `cloud/SETUP.md`) where the key of
`MANIFEST` is that machine's. This branch has one commit, which each save
replaces; nothing else belongs on it.
EOF
  git -C "$tmp/tree" init -q
  git -C "$tmp/tree" checkout -q --orphan "$branch"
  git -C "$tmp/tree" add -A
  git -C "$tmp/tree" commit -q -F - << EOF
Cache the host SML systems for fresh cloud machines

$(cat "$c/MANIFEST")

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
  git -C "$tmp/tree" push -q --force "$url" "$branch:$branch"
  say "pushed $(du -h "$tmp/hosts.tar.xz" | cut -f 1) to $branch: $(key)"
  ;;
restore)
  missing=""
  for h in $hosts; do
    n=${h%%:*}; v=${h#*:}
    [ -d "$prefix/$n-$v" ] && [ "$(readlink "$prefix/$n" 2> /dev/null)" = "$n-$v" ] || missing="$missing $n"
  done
  [ -n "$missing" ] || { say "every host is installed"; exit 1; }
  git init -q --bare "$tmp/repo"
  if ! git -C "$tmp/repo" fetch -q --depth 1 "$url" "$branch" 2> "$tmp/fetch.err"; then
    say "no cache: the branch $branch cannot be fetched ($(head -1 "$tmp/fetch.err"))"; exit 1
  fi
  git -C "$tmp/repo" show FETCH_HEAD:cloud/cache/MANIFEST > "$tmp/MANIFEST"
  want=$(key)
  have=$(sed -n 's/^key //p' "$tmp/MANIFEST")
  [ "$have" = "$want" ] || { say "the cache is for another machine: $have, not $want"; exit 1; }
  for p in $(sed -n 's/^parts //p' "$tmp/MANIFEST"); do
    git -C "$tmp/repo" show "FETCH_HEAD:cloud/cache/$p"
  done > "$tmp/hosts.tar.xz"
  [ "$(sha256sum "$tmp/hosts.tar.xz" | cut -d ' ' -f 1)" = "$(sed -n 's/^sha256 //p' "$tmp/MANIFEST")" ] ||
    { say "the cache does not match its checksum: not used"; exit 1; }
  mkdir -p "$prefix" "$tmp/out"
  xz -dc "$tmp/hosts.tar.xz" | tar -xf - -C "$tmp/out"
  # only what is missing, so that nothing installed is replaced
  for n in $missing; do
    for h in $hosts; do [ "${h%%:*}" = "$n" ] && v=${h#*:}; done
    rm -rf "${prefix:?}/$n-$v"
    mv "$tmp/out/$n-$v" "$prefix/$n-$v"
    ln -sfn "$n-$v" "$prefix/$n"
  done
  say "restored$missing from $branch"
  ;;
*)
  echo "usage: scripts/cloud-cache.sh save|restore" >&2; exit 2 ;;
esac

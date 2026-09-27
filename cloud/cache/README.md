# The cloud cache

The host SML systems of `make hosts`, packed by `scripts/cloud-cache.sh
save` and unpacked on a fresh cloud machine by `scripts/cloud-cache.sh
restore` (the session-start hook, `cloud/SETUP.md`) where the key of
`MANIFEST` is that machine's. This branch has one commit, which each save
replaces; nothing else belongs on it.

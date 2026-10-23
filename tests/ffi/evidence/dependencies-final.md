# Final dependency recipe admission — 2026-10-23

The frozen provisioning recipe `d6d147bed` builds seven fresh, separately
owned prefixes: native/Windows32/Windows64 libffi 3.4.6 and native/headless/
Windows32/Windows64 SDL 3.4.18. Cached release archives match the committed
source hashes; no system packages or existing acceptance prefixes change.
Unset compiler flags retain optimized defaults; explicitly empty flags are
distinct cache inputs. Original-source and prefix ownership guards remain
active.

Native libffi admission executes width/endian, scalar, aggregate, closure
and function-pointer checks. Both native SDL profiles execute software
rendering probes; the headless result is separate from real GUI acceptance.
The four cross-built Windows probes are then executed on actual Windows:
all four exit **0**, including the full libffi admission at both widths.
Each SDL probe loads its matching freshly built DLL, copied beside its
private probe executable; the installed prefix remains unmodified.

[Machine-readable receipts](dependencies-final.json) retain exact versions,
effective flags, toolchain identities, recipe/source/manifest hashes, prefix
output counts and Windows executable hashes/status/streams. Full manifests
and build/probe logs remain in the isolated `runeffi-variadic` worktree's
`build/deps`; top-level command logs are `/tmp/runeffi-final-{libffi,sdl}-*.log`.
These are dependency admission results, not upstream project test-suite or
application GUI claims.

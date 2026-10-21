# Standard ML build and packaging tools

The bootstrap executable is compiled by the installed native MLton from
`native.mlb`. It links the ordinary Basis Library, UTF-8/JSON/SHA256 utilities,
the shared build models and a small POSIX process adapter. It requires no Rune
VM, compiler bytecode, REPL image or target GMP configuration. MLton and its
build-host runtime are external host requirements; they are independent of
whether the resulting Rune VM enables GMP.

The dependency order is:

1. The retained host provisioning adapter makes the pinned native MLton available.
2. MLton builds the native SML executable and its generated launcher.
3. That executable configures GMP, discovers runtime inputs and builds the VMs.
4. A VM and compiler can then build the portable Rune entrypoint from the same
   models. This post-bootstrap bytecode is used in retained relinking material.
5. Documentation, installation and distribution consume these verified artifacts.

The native and Rune entrypoints have separate process adapters. Standard ML owns
options, hashes, cache identity, dependency discovery, ABI admission, archive
records, comparisons and publication. The native adapter uses POSIX process
control and MLton's signal handler boundary; the Rune adapter uses Subprocess.
Both use finite waits, owned child cleanup and argument vectors. External C
compilers, pkg-config, make, tar/xz, curl, gzip and Git provide their respective
host observations, builds, transport and compression.

| Mode | Purpose |
|---|---|
| `configure-gmp` | auto/yes/no, checked prefix or system installation, version/ABI metadata, config.h/config.mk |
| `build-gmp [download]` | Pinned source transport, verified cache, configure/build/upstream checks/install and provisioning record |
| `build-gmp-vm` | Cross configuration, transitive source/header identity, verified reuse, staged link and Windows import admission |
| `check-windows-imports` | Shared system-DLL admission for the stack and register VMs |
| `record-vm-build` | Selected VM, source/flags/dependency identities needed for relinking |
| `package-runtime` | Verified runtime material, dependency notices/source archive and SML relinking entrypoints |
| `make-dist` | Linux/Windows archives, bounded ELF/PE admission, canonical icon and standalone format self-test |
| `setup-mlton` | Pinned MLton source preparation and its checked 606-file compiler source list |
| `relink` | Reconfigure and rebuild the retained runtime material in a writable location |

The option names of the former individual producers remain available after the
mode. `make-dist --self-test` replays the original handwritten format cases from
frozen literal fixtures. Archive entries use fixed clocks, owners and modes;
USTAR records match the previous producer. ZIP records retain their metadata and
Deflate method. Compression bytes may depend on the compressor implementation;
member bytes and repeat determinism are verified separately.

`share/rune.ico` is the canonical four-size branding asset, reproduced exactly
from the former producer. Its source PNG and ICO digests are paired in
`data/branding.json`; a changed or poisoned pair is refused before publication.
Distribution creation therefore needs no Python or Pillow image conversion.

GMP downloads retain private partial files and bounded mirror attempts. A
transport error can fall back; a checksum mismatch is fatal. Existing corrupt
archives and altered extracted source members are refused. Build reuse checks
both source/configuration identity and the produced binary. Runtime material
checks the VM, selected dependency and every retained source hash before it
publishes a replacement directory.

When portable rebuild bytecode is available, material includes that bytecode,
a matching VM and generated thin launchers. The independent native bootstrap
path remains available from the copied SML sources with MLton. Neither path
contains generated Python build policy. System GMP has explicitly unknown
source/build provenance and remains an external relinking requirement.

Pre-host `make hosts`, doctor, and explicit dependency provisioning bypass target
GMP configuration; `make bin/rune-build GMP=yes` also works before that prefix
exists. A cold Make bootstrap was verified with empty build/bin directories.

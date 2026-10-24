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
| `package-lsp` | Private VS Code server/Basis staging, Git-derived manifest version and VSIX publication to disk |
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

`package-lsp --version VERSION --out STAGE --lib LIB --server SERVER.rbc
--linux VM --windows VM.exe` stages a private extension. `--client` selects
the bundled JavaScript and notices (default `build/vscode/client`),
`--extension` the manifest/README sources (default `editors/vscode`), and
`--publisher` can override their publisher. `--vsix DIRECTORY` additionally
invokes the locked local vsce through `--node` (default `NODE` or `node`).
Only Basis manifest members are included. `--self-test` checks numeric
release and snapshot version mapping and refusal of unavailable/shallow
Git history. `make test-vscode` also runs independent staging/fault cases
and the adapter's dependency-free Node tests; it is part of `make check`.
`--gmp-notices DIRECTORY` supplies the selected distribution runtime's GMP
notices, including when its provisioning prefix has been overridden; an
explicit missing directory is refused.

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

`build-ffi libffi|sdl` provisions the optional dynamic-call dependency or SDL3
from `ffi/PROJECT/source.json`. It supports `--target native|windows32|windows64`,
`--archive FILE`, `--prefix DIR`, `--offline`, `--download-only`, `--verify-only`,
`--jobs N`, `--timeout SECONDS`, and explicit `--cc`, `--cxx`, `--rc` tools.
Native SDL also accepts `--headless`, recording a distinct dummy/offscreen
software profile under `build/deps/sdl/headless/install`. It excludes desktop
window systems and optional device integrations for CI with no display server.
The normal path verifies the pinned archive before extraction, admits only
contained regular files/directories/links, compiles in an isolated directory,
probes the installed ABI/rendering calls and atomically replaces the prefix.
Cross targets compile the probe and record execution as outstanding. It does
not run upstream test suites: Rune's ABI/behavior suites are separate gates.
`rune-ffi-dependency.json` records every command, compiler identity, original
source digest, recipe identity, installed output hashes and validation status.
Reuse checks those identities and all installed files/links. Offline mode never
launches a downloader. A failed build/probe preserves the previous prefix.
Before reuse or compilation, a nonempty prefix must have a matching ownership
record and contain only recorded files/links/directories. Modified owned outputs
can rebuild; unrelated entries cause refusal and are preserved. Publication
rechecks ownership after moving the old prefix aside, before replacing it.
Allowlisted effective compiler/linker/tool flags enter cache identity, including
the distinction between unset and empty. Inherited Make jobserver flags are
cleared because the tool supplies its own bounded parallelism.

`FFI_PREFIX` selects the static libffi archive for native Make builds; cross
builds retain the existing `FFI_WIN32_PREFIX`/`FFI_WIN64_PREFIX` selection.
Packaged relinking material retains a selected libffi prefix's two public
headers, static archive, notices, provenance and pinned source archive. Its
relinker validates those inputs and rewrites the old include/archive paths
when the material moves. System libffi retains explicitly external provenance
and requires the corresponding development library when relinking.

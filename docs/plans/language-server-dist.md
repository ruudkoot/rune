# Language server distribution

Package the standalone language server as one VS Code extension, generated
by `make dist` alongside the existing Linux and Windows archives. The
extension supports Linux/glibc x86-64 and Windows x86-64, including a Linux
workspace extension host in Remote WSL. Publishing remains a user action.

## Implementation

| Milestone | Result |
|---|---|
| M1: editor adapter | Thin stdio client, SML/build-file registration, scoped configuration, output channel and restart/shutdown lifecycle. Implemented in `6bf234a47`. |
| M2: private package | Standard ML staging, Git-derived versions, minimal Basis payload, locked client bundling and VSIX creation; integrated into `make dist`. Implemented in `e8a26f601`. |
| M3: acceptance and handoff | Archive, native protocol, library-change and editor-host checks; full-suite and distribution receipts retained. Validation recorded below. |

`editors/vscode` owns the editor adapter and locked npm tooling. SML in
`tools/builder/vscode.sml` owns payload selection, versions, permissions,
private copies and staging publication. esbuild bundles the client and
its dependency notices; the pinned local `vsce` encodes the VSIX.

`make vscode` stages `build/vscode/extension`; `make dist-vscode` additionally
writes `dist/rune-language-server-<rune-version>.vsix`. Staging includes one
`server/bin/runelsp.rbc` beside private `runevm` and `runevm.exe` copies.
This preserves the server's existing worker-launch convention. It uses no
Rune executable from PATH, the development build or an installed prefix.
The compiler executable, REPL, other libraries, npm dependencies, build
tools and caches are excluded from the package.

The bundled Basis sources and manifest are a fallback. For Rune development,
set `runelsp.libraryRoot` to the checkout's `lib` directory as a file URI.
Saved Basis edits and manifest changes then update analysis without
repackaging. Run `make manifests` after adding files or changing the names
they provide. Language or primitive changes can require a new server build.

The extension declares `extensionKind: ["workspace"]`; its host's OS and
architecture select the VM. Unsupported hosts receive an explicit error.

## Version policy

There is no independent extension release number. The artifact filename,
`runeVersion` metadata and startup log retain Rune's exact generated Git
version, including `-dirty` where applicable.

Marketplace manifest versions must be numeric `MAJOR.MINOR.PATCH`. A Rune
version in that form is used unchanged. Other builds use `0.0.N`, with `N`
the result of `git rev-list --count HEAD`. Snapshot packaging requires
complete Git history and refuses missing or shallow history. Dirty builds
retain the same commit-derived numeric version. Commit counts can coincide
across branches; Marketplace versions can only be published once.

Publisher defaults to `ruudkoot`; `VSIX_PUBLISHER` can override it.

## Validation receipts, 2026-10-23

Acceptance output is retained under `build/vscode/acceptance`. The functional
checks initially used the implementation worktree at `6bf234a47-dirty`;
the final package is regenerated after the milestone commits.

* `make dist` generated all three artifacts together. The initial VSIX is
  about 2.9 MiB. Its independent SML archive check validates the exact member
  set, runtime/bytecode bytes, executable modes and version/name agreement.
* The independent portable protocol client passes nine checks on both the
  packaged Linux and native Windows VMs: Basis/worker startup, hover,
  navigation, diagnostics, completion, checkout library selection, saved
  Basis changes, changed manifests and shutdown. Windows extraction and
  source changes use a private NTFS directory with spaces and Unicode paths.
* Extracted-package editor tests pass on VS Code 1.106.0 and 1.142.0. They
  exercise activation, hover, diagnostics and restart. The strengthened
  minimum-version check also requires a fresh hover response after restart.
* Staging/version/client checks initially pass all eight runner cases,
  including its five canaries. Planted invalid executable, unsafe manifest
  and missing-notice inputs retain the prior stage. Native and Rune builds
  of the packaging model are checked separately.
  The final direct model checks, three client cases and staging/failure
  cases also pass after the final notice-selection changes.
* With the packaged server and analysis worker running, forcing
  `make -W runtime/main.c bin/runevm` succeeds and subsequent protocol
  requests still pass. This ten-check run confirms development rebuilds
  do not replace or lock the extension's private executable files.
* Initial editor launches exposed inherited Electron/VS Code environment
  settings and the Unix socket path limit. The test driver clears those
  settings and uses a short private profile under `/tmp`; corrected editor
  runs pass. The installed Windows editor could not start while its updater
  held the `vscode-updating` mutex; native Windows protocol checks pass.
* Full `make check`: **19,858 PASS, 3 SKIP, 5 FAIL**, 1,791.1 seconds wall
  time. The failures are `runner/host-adapter`, `native/launcher/faults`,
  `benchmark-controller/budget-faults`, `documentation/faults` and
  `platform/faults`, all in existing crash/output-limit checks. The skips
  are the two documented native interrupt cases and the missing separate
  pinned GMP `native` prefix. The six distribution GMP builds pass their
  own upstream suites. This is a failed full run, not a clean acceptance.
  The later packaging-model/staging deltas are checked separately.

The host routes core dumps through `|/wsl-capture-crash %t %E %p %s`. An
independent shell probe, with core size limited to zero, remains in
`CoreDumping: 1`, waiting on `anon_pipe_write`, until killed. Existing crash
and output-limit fault checks therefore time out. Their failed receipts
are preserved; host core settings are not changed and the full run is not
reported as clean.

## Installation and publishing

See [the extension guide](../../editors/vscode/README.md) for installation,
Remote WSL, settings and development/test commands. Packaging and publishing
need Node.js 22 or later. Follow the upstream
[publishing guide](https://code.visualstudio.com/api/working-with-extensions/publishing-extension)
to authenticate the publisher, then publish the prepared file:

```sh
vsce publish --packagePath dist/rune-language-server-<rune-version>.vsix
```

The locally locked command is `editors/vscode/node_modules/.bin/vsce`.

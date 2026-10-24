# Rune Language Server

Compiler-backed Standard ML diagnostics, hover, navigation, completion and
semantic presentation, provided by Rune over the Language Server Protocol.
The extension includes private Linux and Windows x86-64 runtimes and runs on
the workspace side of VS Code, including Remote WSL. No Rune installation is
needed. Other architectures, macOS, Alpine Linux and browser-only workspaces
are not supported by this package.

Open an `.sml`, `.sig` or Rune `.build` file to start the server. Use the
**Rune Language Server** output channel for logs and **Rune: Restart Language
Server** to restart it. Project discovery and context selection use Rune's
build files; sources are checked statically, never executed.

## Developing Rune and its libraries

The bundled Basis is a fallback. To analyze against a checkout's current
Basis and other libraries, set `runelsp.libraryRoot` to that checkout's `lib`
directory as a file URI in workspace settings:

```json
{
  "runelsp.libraryRoot": "file:///home/me/rune/lib"
}
```

On Windows use a URI such as `file:///C:/src/rune/lib`. In Remote WSL use
the Linux path. Each workspace folder can select its own library root.
Saved source changes are rechecked; after adding library files or changing
the names they provide, run `make manifests` in the checkout. Compiler
language and primitive changes may require an updated extension as well.
The Basis's own sources are checked through `basis/library.build` in their
bootstrap environment, including their permitted primitive declarations.
The extension's executable files remain separate from that checkout's
builds and from installed Rune binaries.

Settings under `runelsp` also support `target`, `sourceMode`, `libraries`,
`pathVariables`, `targets` and `activeContext`. Their formats are documented
in the [language server manual](https://github.com/ruudkoot/rune/blob/master/docs/language-server.md).
The Settings editor groups these options under **Rune**; their existing
`runelsp.*` JSON keys remain supported.

## Building and installing

From a Rune source checkout, `make vscode` stages a development extension;
`make dist-vscode` creates `dist/rune-language-server-<rune-version>.vsix`.
Both require Node.js 22 or later and npm, in addition to Rune's build tools
and the Windows x86-64 cross toolchain. Dependencies are locked and installed
locally; no global npm packages are required. `make dist` also creates this
VSIX alongside the Linux and Windows Rune archives.

`make test-vscode` runs the dependency-free client, staging and version
checks, also included in `make check`. `make test-vscode-packaged` builds
the VSIX and checks its archive and live Linux protocol behavior.
`make test-vscode-editor` runs the extracted package in an isolated VS Code
test host; it needs a display (or Xvfb). `VSCODE_TEST_VERSION` selects the
test host version, defaulting to the minimum supported version, 1.106.0.
The portable `bin/rune-lsp-distribution-tests.rbc` can also run on the
packaged Windows VM with the native extracted-extension path as its argument.
Set `RUNE_VSCODE_CHECKOUT` to a native checkout path for an additional check
that regenerates the temporary library's manifest with that checkout's
compiler. All edits remain in the test's private library copy.

Editor tests use dedicated profiles. For operating-system isolation, run
Windows tests in Windows Sandbox or a disposable VM, and Linux tests in
namespaces with a private headless display. The
[test isolation guide](https://github.com/ruudkoot/rune/blob/master/editors/vscode/test/README.md)
describes the minimized Windows Sandbox launcher and its scoped cleanup.

Linux needs glibc and the shared libraries used by its distribution VM;
with the default FFI-enabled Linux build this includes `libffi.so.8`.
GMP is linked statically. The package carries its license notices.

Install with **Extensions: Install from VSIX...**, or:

```sh
code --install-extension dist/rune-language-server-<rune-version>.vsix
```

For Remote WSL, install into the WSL workspace's extension host. The same
VSIX works on native Windows and Linux x86-64.

The package filename, metadata and startup log retain Rune's exact Git
version. Numeric `MAJOR.MINOR.PATCH` releases use that manifest version;
other builds use `0.0.N`, with `N` the Git commit count. Dirty builds retain
`-dirty` in their Rune version. The source manifest's `0.0.0` is a staging
placeholder, not an independently maintained extension version.

Publish an already built VSIX after authenticating as publisher `ruudkoot`:

```sh
vsce publish --packagePath dist/rune-language-server-<rune-version>.vsix
```

Use the locally installed `editors/vscode/node_modules/.bin/vsce` if `vsce`
is not on PATH. Snapshot commit counts can coincide across branches; the
Marketplace accepts each numeric version only once. Release tags should
use a higher version than any version already published.

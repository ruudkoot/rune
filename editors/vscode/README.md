# Rune language server

Compiler-backed Standard ML diagnostics, hover, navigation, completion and
semantic presentation, provided by Rune over the Language Server Protocol.
The extension includes private Linux and Windows x86-64 runtimes and runs on
the workspace side of VS Code, including Remote WSL. No Rune installation is
needed. Other architectures, macOS, Alpine Linux and browser-only workspaces
are not supported by this package.

Open an `.sml`, `.sig` or Rune `.build` file to start the server. Use the
**Rune language server** output channel for logs and **Rune: Restart language
server** to restart it. Project discovery and context selection use Rune's
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
The extension's executable files remain separate from that checkout's
builds and from installed Rune binaries.

Settings under `runelsp` also support `target`, `sourceMode`, `libraries`,
`pathVariables`, `targets` and `activeContext`. Their formats are documented
in the [language server manual](https://github.com/ruudkoot/rune/blob/master/docs/language-server.md).

## Building and installing

From a Rune source checkout, `make vscode` stages a development extension;
`make dist-vscode` creates `dist/rune-language-server-<rune-version>.vsix`.
Both require Node.js 22 or later and npm, in addition to Rune's build tools
and the Windows x86-64 cross toolchain. Dependencies are locked and installed
locally; no global npm packages are required. `make dist` also creates this
VSIX alongside the Linux and Windows Rune archives.

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

# Building and testing Rune

## Requirements

Use GNU Make, a POSIX shell and common utilities (`cp`, `cmp`, `cksum`, `dirname`),
one supported host compiler, and an ISO C11 compiler. Python 3 is needed for tests
and documentation generation only. Generated SML/C opcode definitions are checked
in, so normal builds do not need Python or a parser generator.

Current host installations used for development are SML/NJ 110.79, Poly/ML 5.7.1,
and MLton 20210117. The VM targets systems with 8-bit bytes, `uint32_t`, and
`int64_t`. Validation in this workspace is on x86-64 Linux with GCC 13.3.0
and Clang 18.1.3. Other operating systems, 32-bit targets, and big-endian targets
are not yet verified. Building the C VM for another target is supported through `CC`/`CFLAGS`;
running that target's binary requires the appropriate system or emulator.

## Commands

```sh
make                            # MLton compiler and C VM
make HOST=smlnj build
make HOST=polyml build
make HOST=mlton build
make all-hosts                   # Fails if any required host is unavailable
make doctor                     # Report installed tools and SML/NJ startup

build/mlton/rune --help
build/mlton/rune --version
build/mlton/rune --check examples/hello.sml
build/mlton/rune -o build/hello.rbc examples/hello.sml
build/mlton/rune --disassemble build/hello.rbc
build/vm/rune-vm build/hello.rbc
```

Without `-o`, Rune replaces the input's extension with `.rbc`. Both executables
accept `--` before a filename beginning with `-`. Launchers resolve their own
artifacts independently of the caller's working directory. Source/output paths
remain relative to the caller. Output is written beside its destination in a
temporary file and renamed after successful compilation. Compiler failures
preserve an existing output. Identical input/output paths are rejected.

The compiler returns 0 on success and 1 on usage, source, or I/O failure. The VM
returns 0 on success, 1 for usage/file errors, 2 for invalid bytecode, and 3 for
runtime failures. Diagnostics go to stderr and include source locations when
available. `print` adds no automatic newline.

## Host adapters

- **SML/NJ:** `ml-build` reads a generated CM group and exports a heap image.
  A shell launcher loads it using the matching SML/NJ installation. The outer
  launcher supplied by some distributions loses argument quoting; discovery
  prefers `$SMLNJ_HOME/bin/sml` (the local default is `/usr/lib/smlnj/bin/sml`).
  Set `SML` explicitly for other installations.
  Rune arguments are also prefixed and decoded so filenames beginning with
  `@SML` cannot be consumed as runtime options. This environment's execution
  sandbox blocks SML/NJ with `Bad system call`; development checks here must run
  outside that sandbox.
- **Poly/ML:** compile the shared sources once and save `rune.state`; each launch
  loads the state. Arguments are prefixed by the wrapper and decoded by the
  adapter because this version consumes runtime switches even after `--script`.
  The adapter closes/flushes Rune's I/O and calls `OS.Process.terminate` to avoid
  intermittent failed exit statuses observed with `OS.Process.exit` on the local
  5.7.1 installation. Failed compilation still propagates as a build failure.
  The native `polyc` linker path is not required or implemented as a build mode.
- **MLton:** a generated MLB file and a small entry point produce a native
  executable. No MLton runtime installation is needed to launch this artifact.

One `sources.list` controls compilation order for every host. Source copies and
host-specific intermediates remain under `build/<host>/`; SML/NJ does not create
CM files in the working sources. Checksums avoid unnecessary rebuilding and
detect source/configuration changes. Run `make clean` after upgrading/replacing a
host installation or moving a built checkout; saved states and images are tied
to their host runtime.

Tool overrides are executable names or paths, not shell fragments:

```sh
make HOST=smlnj SML=/path/to/sml ML_BUILD=/path/to/ml-build
make HOST=polyml POLY=/path/to/poly
make HOST=mlton MLTON=/path/to/mlton
make vm CC=cc CFLAGS='-O0 -g'
```

`CFLAGS` is a whitespace-separated list of flags. The VM rebuilds when its C
sources, selected compiler, or flags change. Avoid concurrent builds of the same
host output directory. `make clean` removes only `build/`.

## Editor setup

Open the repository root in your editor when using Millet. Its default project
discovery requires exactly one `.mlb` or `.cm` file directly in that directory
(see [diagnostic 1004](https://github.com/azdavis/millet/blob/main/docs/diagnostics/1004.md)).
The checked-in [rune.mlb](../rune.mlb) provides this project without a
`millet.toml` configuration or an initial build. It imports the Standard ML Basis
Library and lists the working compiler sources in `src/`, in the order specified
by [sources.list](../sources.list). It remains available after `make clean`.

The editor project covers the portable compiler core. Host entry points,
examples, and test fixtures are outside its scope; fixtures include deliberately
invalid programs and programs whose behavior follows Rune's language contract.

Edit `sources.list` when adding or reordering compiler sources, then run
`make generate`. This regenerates `rune.mlb`, and `make check-docs` detects a
missing or stale project file. MLton can also type-check the project directly:

```sh
mlton -stop tc rune.mlb
```

## Tests and documentation

```sh
make HOST=polyml test
make test-all
make test-builds
make test-sanitize
make check-docs
make generate
```

`test-all` builds all hosts, runs the fixture corpus, compares bytecode and
diagnostics, checks malformed bytecode, and runs selected programs directly under
the reference SML compilers. Rune-specific 32-bit boundaries use explicit expected
values because SML/NJ's default integers are narrower. VM output checks are byte
comparisons, including embedded NUL and escaped bytes. M2 fixtures exercise
closures, polymorphism, tuples, one million tail calls, and resource failures.
Selected type/pattern rejection cases are also checked against all three reference
compilers. Bytecode v2 fixtures cover function metadata, captures, returns, tail
calls, tuple operations, and explicit rejection of v1 files.

`test-builds` uses a temporary checkout whose path contains spaces. It checks
incremental rebuilds and that invalid SML causes each build to fail.
`test-sanitize` runs the corpus and malformed-bytecode checks with an instrumented
C VM. It requires GCC or compatible Clang sanitizer flags; it is a separate
development check from portable C builds. In this execution sandbox,
LeakSanitizer reports that it cannot run under ptrace; the same suite passes
outside the sandbox with leak detection enabled. This is an execution-environment
restriction, not a missing dependency.

`make generate` updates the checked-in editor project, opcode definitions, the
opcode table, the language support table, and example inclusions. Edit
`sources.list`, `spec/opcodes.tsv`, `docs/features.tsv`, or `examples/` first.
For language features, add feature IDs to `tests/cases.json` and include a
relevant boundary/rejection case. `make check-docs` rejects stale
generated material, missing fixtures, missing coverage, and broken local links.
Prose still needs review whenever semantics change. CI requires the three-host
suite, build checks, and sanitizer suite.

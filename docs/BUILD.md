# Building and testing Rune

## Requirements

Use GNU Make, a POSIX shell and common utilities (`cp`, `cmp`, `cksum`, `dirname`),
one supported host compiler, and an ISO C11 compiler. Moscow ML also needs `curl`,
`sha256sum`, `tar`, Perl, and a C preprocessor for its source bootstrap. Python 3 is needed for tests
and documentation generation only. Generated SML/C opcode definitions are checked
in, so normal builds do not need Python or a parser generator.

Current host installations used for development are SML/NJ 110.79, Poly/ML 5.7.1,
and MLton 20210117. The VM targets systems with 8-bit bytes, `uint32_t`, and
`int64_t`. Rune 0.2.0 is validated on native x86-64 Linux with GCC 13.3.0 and
Clang 18.1.3, and on QEMU 8.2.2 user-emulated i386 Linux (32-bit little-endian,
GCC) and PowerPC64 Linux (64-bit big-endian, Clang). Other operating systems,
native PowerPC hardware, ARM64, and 32-bit big-endian targets remain unverified.
Building the C VM for another target is supported through `CC`/`CFLAGS`; running
that target's binary requires the appropriate system or emulator. See the
[portability checks](#portability-checks) for the repeatable development matrix.

## Commands

```sh
make                            # MLton compiler and C VM
make HOST=smlnj build
make HOST=polyml build
make HOST=mlton build
make HOST=mosml build
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

The VM collects unused strings, tuples, and closures automatically. Its default
managed heap ceiling is 64 MiB, including object headers. For reproducible memory
tests, lower the ceiling and optionally collect before every allocation:

```sh
build/mlton/rune -o build/collection.rbc examples/collection.sml
build/vm/rune-vm --heap-limit 16384 build/collection.rbc
build/vm/rune-vm --heap-limit 16384 --gc-stress build/collection.rbc
# Both print 1 followed by a newline.
```

`--heap-limit` accepts decimal byte counts from 1 through 67,108,864. Invalid
options exit with status 1; a valid but insufficient heap exits with status 3.
These options precede the filename, with `--` available for option-like filenames.
The ceiling covers managed objects; bytecode storage, VM stacks, and C allocator
overhead are separate. See [BYTECODE.md](BYTECODE.md) for root and retention rules.

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
- **Moscow ML:** `scripts/build_mosml.sh` downloads and verifies the pinned 2.10.1
  source archive, then runs upstream `make world` and `make install` under
  `build/tools/mosml-ver-2.10.1`. Moscow ML bootstraps from its C runtime and
  checked-in `mosmlcmp`/`mosmllnk` bytecode; another SML compiler is not required.
  Rune uses the private `IntInf` Basis library and a `camlrunm`-backed launcher.

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
make HOST=mosml MOSMLC=/path/to/mosmlc build
make HOST=mosml MOSML_VERSION=2.10.1 MOSML_SHA256=<sha256> build
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
make test-gc
make test-portability
make check-docs
make generate
```

`test-all` builds all hosts, runs the fixture corpus, compares bytecode and
diagnostics, checks malformed bytecode, and runs selected programs directly under
the reference SML compilers. Rune-specific 32-bit boundaries use explicit expected
values because SML/NJ's default integers are narrower. VM output checks are byte
comparisons, including embedded NUL and escaped bytes. M2 fixtures exercise
closures, polymorphism, tuples, one million tail calls, and resource failures.
Every runnable fixture is executed normally and with `--gc-stress`, including
the runtime-failure fixtures. M3 tests run allocation-heavy programs in a 16 KiB
heap, preserve live captures/tuples/temporary strings, and diagnose retained-heap
exhaustion. All three host-built compilers run these tests. The standalone VM
fixtures also run in both modes and test every truncation boundary of empty and
closure-containing bytecode files.
Selected type/pattern rejection cases are also checked against all three reference
compilers. Three cases use only Poly/ML and MLton as rejection references because
SML/NJ 110.79 accepts escaping local datatypes and ignores datatype parameter
equality constraints. The manifest lists these exceptions explicitly; all three
host-built Rune compilers must reject them. Bytecode v3 fixtures cover function
metadata, captures, returns, tail calls, tuples, constructor calls/tests/payloads,
match-failure terminators, and explicit rejection of v1/v2 files. M5a also covers
ordered/nested matching, diagnostic warnings, nominal type identity, constructor
polymorphism/equality, partial-application timing, and datatype collection in a
16 KiB heap. Warnings and emitted bytes are compared across host builds.

`test-builds` uses a temporary checkout whose path contains spaces. It checks
incremental rebuilds and that invalid SML causes each build to fail.
`test-gc` builds a C collector harness covering root categories, stale capacity
slots, shared/cyclic graphs, 100,000-object closure/constructor chains, and exact heap accounting.
It is included in `test` and `test-all`, and needs only the existing C compiler.
`test-sanitize` runs this harness, the corpus, and malformed-bytecode checks with
address/undefined-behavior instrumentation. It requires GCC or compatible Clang
sanitizer flags; it is a separate development check from portable C builds. In this execution sandbox,
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
suite, build checks, GCC/Clang sanitizer suites, and the portability matrix.

## Portability checks

`make test-portability` builds all three host compilers and the native VM, then
builds and executes the following additional VMs and collector harnesses:

| Target | Pointers | Byte order | Compiler | Execution |
| --- | --- | --- | --- | --- |
| x86-64 Linux | 64-bit | Little-endian | `CC` (default `cc`) | Native |
| i386 Linux | 32-bit | Little-endian | GCC with `-m32` | `qemu-i386` |
| PowerPC64 Linux | 64-bit | Big-endian | Clang targeting `powerpc64-linux-gnu` | `qemu-ppc64` |

This development target requires an x86-64 Linux host and the Ubuntu-style
PowerPC64 toolchain layout. It is separate from the portable C VM's requirements.
Missing tools or a wrong target fail the check. Each cross-built executable's ELF
header must match its target architecture, width, and byte order. A C probe
confirms the executing target's pointer width and byte order before its collector
harness runs. QEMU is used explicitly, with no binfmt registration or system
emulator configuration required. Native i386 execution in this workspace's
sandbox fails with `Bad system call`; QEMU user emulation works.

Install the extra development packages on Ubuntu 24.04 with:

```sh
sudo apt-get update
sudo apt-get install clang qemu-user gcc-multilib libc6-dev-i386 \
  binutils-powerpc64-linux-gnu libc6-dev-ppc64-cross libgcc-13-dev-ppc64-cross
make test-portability
```

Clang uses `--target=powerpc64-linux-gnu --gcc-toolchain=/usr` with the PowerPC64
binutils, headers, and runtime libraries. Installing a GCC cross compiler instead
conflicts with Ubuntu's `gcc-multilib` metapackage. The listed support packages
coexist with multilib. No additional tools are needed for this matrix in the
current development environment; these commands are also used by its CI job.

Artifacts and argument-preserving VM launchers go under
`build/portability/i386/` and `build/portability/powerpc64/`. Native artifacts
remain in `build/vm/`. The target uses fixed strict C11 warnings and `-O2` for
cross builds. Optional executable-path overrides are `I386_CC` (default `gcc`),
`PPC64_CC` (a Clang-compatible driver, default `clang`), `QEMU_I386`, and
`QEMU_PPC64`. `PPC64_SYSROOT` overrides QEMU's runtime library prefix, defaulting
to `/usr/powerpc64-linux-gnu`; compilation uses the toolchain layout under `/usr`.

The test runner compiles each fixture once per SML host and runs that exact
bytecode file on all three VMs before replacing it. It compares stdout, exit
status, and full runtime diagnostics in both normal and GC-stress modes,
including small-heap cases and source locations. Every VM also runs the complete
malformed-bytecode and CLI checks. The three-host bytecode and reference-SML
comparisons run in the same invocation. The runner's repeatable `--vm` option
is available for other already-built VMs or executable launchers:

```sh
python3 scripts/test.py --hosts smlnj polyml mlton \
  --vm build/vm/rune-vm \
  --vm build/portability/i386/run-vm \
  --vm build/portability/powerpc64/run-vm
```

This validates the selected emulated Linux configurations. Native PowerPC
hardware, 32-bit big-endian targets, ARM64, and other OSes remain unverified.

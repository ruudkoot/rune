# Generating foreign bindings

`make runeffi` builds the self-hosted generator. It preprocesses and parses
original C headers in SML, applies a version-one `.ffi` sidecar, resolves an
explicit target profile, and emits ordinary documented SML sources. It does
not run a C compiler, acquire dependencies, or open native libraries.

```sh
bin/runeffi generate --config tests/ffi/generator/scalars.ffi \
  --target ffi/targets/linux-x86_64.json --out build/ffi-generated/scalars \
  --layout gen_record --constant GEN_HIGH --constant GEN_NEGATIVE
bin/runeffi check --config tests/ffi/generator/scalars.ffi \
  --target ffi/targets/linux-x86_64.json --out build/ffi-generated/scalars \
  --layout gen_record --constant GEN_HIGH --constant GEN_NEGATIVE
```

`inspect` takes the same input options and prints declaration mappings,
native descriptors, public adapter provenance, target layouts, constants
and artifact paths. `--out` is unnecessary for inspection. Repeated
`--include ROOT` options search original header trees in order after the
sidecar directory. Standard compiler include paths must be supplied
explicitly. The target profile supplies preprocessing macros; the host
running the generator does not choose the target ABI.

`--layout TYPE` emits selected `sizeof`, alignment and named field offsets.
`--constant NAME` evaluates the original initializer expression with target
integer widths, including unsigned constants above `INT_MAX`.
`--field-get TYPE:field.path` emits a typed native getter;
`--field-set TYPE:field.path` also emits its setter. The generated C includes
original headers. Compile it separately using those headers and the target
compiler flags, then add its library path to the explicit binding session.
Pointer-valued getters return opaque native resources through the normal
dynamic interface. No address is reconstructed from SML bytes.

Every generation contains `raw_sig.sml`, `raw.sml`, `layout_sig.sml`,
`layout.sml`, `public_sig.sml`, `public.sml`, `library.build`, documented
provenance and dependency manifests, and optional `shims.c`. Raw members take
a session and checked `RuneForeign.argument` values and return raw status
bytes, pointer identity and captured errors. Their native signatures are
fixed generated descriptors; callers cannot add arbitrary symbols by name.
`prepare` exposes a session-owned descriptor for transactional destructors.
Defining a structure opens no native libraries. The first call verifies the
VM target and resolves its native symbol. Close dependent resources before
closing the session. Failed unload remains retryable.

Automatic public scalar projections support fixed signed/unsigned widths,
booleans, floating values and structured input/output grouping. Other
selected public projections require an explicit adapter, recorded by name
in `ffi-manifest.json`. A selection without an implemented lowering or an
explicit public adapter fails with a source diagnostic. Dynamic variadic
calls and unprototyped C functions require fixed typed adapters. This
component alone does not complete the generic pointer, buffer, ownership,
aggregate, callback or error-projection delivery gate.

The output directory stores immutable `sets/<content-hash>` generations and
stable public interfaces in `api/<signature-hash>`. Publication writes and
checks a complete generation before atomically replacing `current.build`.
Readers following that one file see a complete old or new generation.
Interrupted staging directories never become build inputs. Concurrent
generators use separate staging directories and validate an already
published identical generation. Different complete generations may publish
in either order; the final pointer selects one complete set.

`check` recomputes expected artifacts and dependency hashes without writing.
It detects transitive header edits, changed policy/target/options, altered
generated sources and missing outputs. Original include source names are
logical paths; output contains no acquisition directory or timestamp.
An altered immutable set is reported, including by `generate`; remove the
damaged generated output directory and regenerate to recover it.

Use `use build/ffi-generated/scalars/current.build` in a native application's
`.build` file. Generation remains a separate prerequisite: `.build` never
runs a command. The current file selects a normal virtual module
implementation and exposes explicit raw/layout modules. An alternate
implementation entrypoint reads the same stable public signature, supplies
`implements GeneratedScalars = ... end`, then reads the stable virtual
declaration and client source. Native-to-mock fixture builds verify that
switching implementations retains the client unit in the warm cache. A
mock implementation loads no native descriptors or libraries.

`make ffi` and `make check-ffi-generated` wrap these commands. Override
`FFI_CONFIG`, `FFI_TARGET`, `FFI_OUT` and `FFI_OPTIONS` for other inputs.
`make test-ffi-generator` runs the focused publication/execution regression;
`make test-ffi-generator-hosts` compares generator inspection on the native
SML hosts. Installed bytecode and available MLton/Poly/ML generators use
paths beside their wrappers and accept the same explicit input paths.

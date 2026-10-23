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
VM target, compiler architecture, plain-char representation and every C
scalar size/alignment before resolving a native symbol. This distinguishes
LP64 and LLP64 even when pointers have the same width. Close dependent
resources before closing the session. Failed unload remains retryable.

Automatic public projections support fixed signed/unsigned widths, booleans,
floating values, structured input/output grouping, strings, byte arrays,
scalar output/inout pointers and abstract resources. Input integer ranges
and native buffer element counts are checked. String extents count native
code units, including any accessible terminator; a fixed input capacity is
padded with zeroes and must fit the encoded input and required terminator.
Terminated output without an extent has a 16 MiB scan limit. It remains the
foreign declaration's responsibility to supply accessible native storage.
Byte arrays preserve aliases and copy native updates back on exceptional
returning paths. Raw resources stay opaque; no pointer is reconstructed from
an integer or a byte sequence.

Owned results are adopted before deferred callback exceptions can propagate.
Owned strings are freed after copying, including conversion failures.
Borrowed results annotated `parameter:name` retain their parent until the
borrowed handle is released. Generated resource release functions reject
active borrows. Closing a session rejects active calls and live owned
resources before changing native state. An owned resource currently requires
a void destructor taking one pointer; other ownership protocols need an
explicit adapter. Native error text is copied before other conversion or
cleanup, and `ForeignFailure` retains the raw status and captured errors.

Call-scoped callbacks support scalar and borrowed pointer arguments, scalar
results, nested foreign calls and annotated failure values. A callback
exception remains inside the native boundary until safe cleanup finishes.
Registered callbacks whose native owner is not an owned returned handle,
retained text/array inputs and more complex destructor protocols require
explicit public adapters, recorded
by name in `ffi-manifest.json`. A selection without an implemented lowering
or an explicit public adapter fails with a source diagnostic. Dynamic
variadic calls and unprototyped C functions require fixed typed adapters.
These remaining automatic projections and their tests keep M6 planned.

Registered callbacks can instead name an owned result resource in `owner`.
That resource's single-pointer void destructor must synchronously unregister
all callbacks before returning. The generated handle retains callback roots
and any input resource annotated `borrowed: OWNER` until the destructor has
returned. Such input resources cannot close while registration is live.
Registration is established only by a nonnull returned owner; a null result
releases the pending roots and leases. A callback exception while registering
still destroys a newly returned owner before releasing its callback. A last
callback during unregistration remains valid, and an exception from it is
propagated after disposal and root cleanup. Registration APIs with another
protocol need an explicit adapter rather than an inferred unregister call.

Native struct arguments/results use generated typed C shims: arguments are
passed to the shim by pointer, and an aggregate result adds an output pointer
as its first argument and makes the raw result void. The original C compiler
performs the by-value call and copy. Public structs become complete named
SML records; nested structs and fixed array fields become nested records and
vectors. Output and inout struct pointers use the same target layout codec.
Every vector length and integer field range is checked before native entry.
Unions require an explicit active-member policy; pointer fields, anonymous
fields and representations for which layout requires a native adapter fail
automatic public projection. Explicit raw adapters remain available.

Static/inline functions and functions with nonstandard calling conventions
also receive exported C shims. The original header supplies their semantics
and calling convention; the shim uses the target default ABI. The manifest
identifies the original declaration, exported shim symbol and `typed-c-shim`
mechanism, and coverage marks these declarations `shimmed`. Compile emitted
`shims.c` with the same pinned original headers and target compiler options.
No build command is embedded in `.build` or executed by the generator.

Selected macros and fixed variadic call sites use the sidecar's optional
`shim` prototype. A macro remains a macro identity in provenance; its ABI
comes from that explicit prototype. Variadic shims check the original return
and fixed-prefix C types, then let C promote the explicitly typed tail.
Integer and float promotion fixtures compare these calls with native C.
Only one fixed declaration is accepted, with no bodies or initializer code.
Original headers stay unmodified and shim compilation stays a separate
build prerequisite. An untyped selected macro, mismatched declaration or
open-ended variadic selection fails before executable binding emission.


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

# Target C layout and expressions

`lib/language/c` computes physical layouts from explicit C target facts.
The SML generator host's `Int`, `Word` and pointer widths are irrelevant.
`CInteger` implements ranks, promotions, usual arithmetic conversions,
checked signed arithmetic and unsigned wrap. `CType` normalizes equivalent
builtin spellings, including Microsoft fixed-width names; its abstract
name parser uses the same declaration parser as original headers.

`CExpression` evaluates integer casts, lazy logical/conditional operators,
`sizeof` and alignment operators. It typechecks both conditional branches
without evaluating unused arithmetic. `sizeof(1 / 0)` therefore succeeds,
and `0 && missing` reports the unresolved identifier. Alias resolution,
object bindings, target measurements and the unsigned `size_t` type are
explicit consumer inputs. Prefixed character constants, floating constants,
pointer-valued constants and unsupported expressions fail visibly; callers
must select verified native adapters where these are required.

`CLayout` computes nested structs, unions, arrays, anonymous member paths,
flexible final tails and pragma packing. It retains source positions and
uses `IntInf` for sizes and offsets, enforcing a target object-size limit.
Pointers do not demand the layout of their pointees. Incomplete objects,
recursive values, invalid packing and ambiguous members fail. Bitfields,
empty aggregate extensions, nonstandard pointer representations and explicit
alignment/packing attributes request verified native C adapters. The
consumer supplies the enum representation promised by its target profile;
this layer does not silently infer a different enum ABI from the SML host.

The owned fixture `tests/ffi/layout.h` is parsed without modification.
`tests/ffi/layout_oracle.c` independently reports native scalar facts and
23 expression/layout results; `bin/rune-c-layout-check TARGET` compares
them with SML analysis. Targets are `native`, `linux32`, `windows32`,
`windows64`, `aarch64` and `ppc64`. Cross compilers, Windows execution and
QEMU are development oracles, not generator dependencies.

This is the target-analysis part of M4. Runtime marshalling, generated
adapter integration and the complete selected-header layout inventory must
also pass before the milestone is complete.

`ForeignShim` emits fixed typed wrappers and member accessors. The C
compiler checks the original declarations and performs aggregate copies,
bitfield access and default argument promotions. Outbound variadic support
in generated wrappers uses an explicitly typed fixed adapter. The raw
`RuneForeign.prepareVariadic` interface additionally prepares complete dynamic
variadic signatures with already promoted tail types. Both callers still
satisfy foreign value/count contracts. Anonymous aggregate/enum types require an original named alias;
unsupported layouts and declarations remain visible diagnostics.

`ForeignMemory.withArrays` copies borrowed arrays into native backing
storage. Ranges of one array share backing storage, preserving overlaps.
Views close first, then output ranges copy back on normal and exceptional
returns before backing allocations are freed. Input-only ranges are snapshots. Retained buffers
have explicit allocation/release; native-owned pointers need a separate
owner/deallocator contract. Native strings are read by complete code unit
through their terminator, never by copying an entire maximum extent past
an earlier NUL. The [marshalling library](../lib/ffi/marshal/README.md) and
[runtime support](../lib/ffi/runtime/README.md) document these interfaces.

The selected-header acceptance consumer (`tests/ffi/header-layout.sml`)
uses `CAnalysis` with validated `ForeignTarget` profiles. Native probes
verify all required SDL/Win32 types, selected nested event/surface fields,
constants and the eight Win32 macro helpers against original headers.
Unknown representation attributes require an adapter; diagnostic/linkage
metadata does not change object layout. Full-int enum representation is
explicit per compiler ABI, rather than inferred from enum constants alone.

Binary32 byte encoding uses nearest rounding with ties to even regardless
of native floating-point environment changes. It canonicalizes NaNs and
widens finite binary32 values exactly on decoding. Native C conversions
on six targets provide an independent oracle; binary64 uses the checked
Basis packing interface.

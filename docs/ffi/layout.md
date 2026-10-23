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

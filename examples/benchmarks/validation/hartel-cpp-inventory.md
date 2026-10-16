# Quoted CPP dependencies in benchmark provenance

The pinned nofib source is b7391df4540ac8b11b35e1b2e2c15819b5171798.
Fourteen `spectral/hartel` programs include `../Fast2haskell.hs`; that file
contains executable compatibility definitions. It belongs in each program's
source members and SHA-256 identity. It is not a runtime input. The original
inventory recorded the quoted path as input and omitted its source bytes.

Discovery now follows local quoted CPP includes transitively for directory and
individual-file entrypoints, terminates cycles, and rejects paths outside the
pinned tree and generated build directories. Include lines are removed only
from runtime filename discovery; literal profile input files remain inputs,
including source files used as data. Source bytes and all other classification
rules remain available to their existing checks.

The complete Fast shim has SHA-256
`b94c6d53bd465be5b940bcbfec12c66c2ba971039072f91c0edb04558bea7596`.
Its `GHC.Prim` import supports scalar integer/word conversions, bitwise
operations, and shifts. Standard ML provides portable counterparts with
explicit word widths. Its arrays are persistent `Data.Array` values;
`destr_update`, despite its name, uses the same persistent update as `update`.
`delay` and `write` are abort stubs in this upstream shim. `force` is identity;
`miraseq x y = seq_const y x` also returns y without demanding x. These
observations come from the source, not measurements or the spelling of the
helper names. Each port must still review its reachable operations, sharing,
and numeric widths; importing this header does not implement unused facilities.

The capability classifier therefore exempts only this exact header path and
byte identity from the generic GHC.Prim-import blocker. Other capability checks
still inspect its code. A changed shim, the same bytes at another path, or a
GHC.Prim import in a program receives the ordinary review requirement. The
exception adds no Rune compiler/runtime feature.

The [literal regression fixture](../../../tests/benchmarks/data/inventory-hartel/Fast2haskell.hs)
preserves every source byte. The file has no separate authorship or licensing
notice; no grant is inferred or copied from an unrelated program. The nofib
pin and original include path are the provenance of this audit fixture.

Rebuilding all five clean pinned source trees changes 19 of 861 inventory
entries: 14 Hartel member/hash/input records, the blackscholes data include,
three input-only classifications (callback001, callback002, nucleic2),
and the extensionless C header real/fem/inC/database. The latter declares shared external state
and input record layouts and is included by seven C reference members.
No names, dispositions, milestones or reasons change. New tests cover
transitive members and digests, per-entrypoint closure, cycles, containment,
CLI source-file inputs, and the exact scope of the reviewed shim exception.

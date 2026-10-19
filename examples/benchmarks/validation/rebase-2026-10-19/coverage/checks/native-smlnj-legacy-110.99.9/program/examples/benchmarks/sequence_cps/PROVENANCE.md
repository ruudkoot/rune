# sequence_cps provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/sequence/sequence_cps.ml`.

The individual author is unspecified. Original source, dune declarations,
SHA256 identities and the aggregate public-domain notice are retained. Kernels
and translation support are SML97. Compiler/runtime explanations below come
from source inspection and remain performance hypotheses until measured.

## Algorithm, history and variants

Preserve the Sequence state/unfolder record, continuation-based map/filter,
three callback cases, and original mutable fold_2. The pipeline maps x+3,
filters even values with bitwise and 1, squares, and folds addition. The outer
loop includes 0..n. No fused direct sum or pull iterator replaces the CPS layers.
The used state is int and payload integer; unfold's continuation result is bool
because fold_2 is the selected implementation. Specialize those concrete types
for SML97 rather than requiring unused existential/GADT/rank-polymorphic cases.
Unused fold_1 remains in the original source.

## Translation, inputs and validation

Original OCaml 63-bit sums exceed31 bits. Portable IntInf retains every selected
value, including bitwise filtering, without overflow through n=10000; its
representation/allocation differs from OCaml machine integers and is explicit.
Profiles n=10/1000/10000 preserve the size argument; large uses the original
run_config.json and bytecode setting 10000. All results agree with unchanged
OCaml and independent sum over odd x<n of (n-x)*(x+3)^2, retaining both inclusive
outer bounds and pipeline order. Semantic checks cover empty/skip/yield/done,
state advancement, exact wide sums and inclusive bounds. The optional
OCAML_GC_STATS file observer is replaced by the suite's separate statistics
mode; no GC facility is added to the kernel. References: original source and
Sandmark configuration/literature. Closure layers, callback specialization,
mutable state and wide arithmetic are source-derived hypotheses until measured.
Large SML execution is not universally claimed.

# zarith_tak-natint provenance

Sandmark revision `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/zarith/`. Each original credits the Zarith test code; its individual
Sandmark adapter author is unstated. The matching factorial, Fibonacci and
Takeuchi definitions are retained from Zarith 1.14 `tests/timings.ml`.
The original Num mode uses Num 1.6. Release archive pins, package authors,
individual source headers and full library notices are retained in
[`shared/zarith-upstream`](../shared/zarith-upstream/). Zarith uses GNU Library
GPL version 2 with its linking exception; Num uses LGPL version 2.1 with its
linking exception. Sandmark's aggregate Unlicense is retained separately and
does not supersede those origins. No external input dataset is required.

## Numeric modes and translation

The unsuffixed Fibonacci/Takeuchi names identify the published `Z` mode.
`-int`, `-natint` and `-num` identify the original CLI modes (including the
upstream spelling `natint`). They share one numeric functor implementation,
but retain materially different representations and operations. SML default
`int` replaces OCaml's 63-bit immediate integers only in a selected domain
where every value fits signed 31 bits. It does not emulate OCaml overflow
outside that domain. `natint` uses signed 64-bit modular arithmetic represented
with `Word64`, including signed comparisons and decimal conversion; this
preserves the reference machine's Nativeint width without optional `Int64`. Negative diagnostic strings use the SML tilde
convention; every selected benchmark result is nonnegative and prints
identically to OCaml.
`Z` uses `IntInf`, whose allocation/small-integer representation and arithmetic
algorithms can differ from Zarith/GMP.

The Num port retains the used Small/Big tagged integer paths: checked addition
and predecessor promote on overflow; Big results normalize back to Small when
representable. Comparison dispatch remains explicit. SML overflow detection
replaces Num's machine-bit overflow test. The threshold follows the SML host's
default int width, but all selected Fibonacci and Takeuchi values fit 31 bits
and stay Small, as in the original. Num's unreachable Ratio cases are omitted;
this is an integer-only specialization, not a general rational library port.

Explicit right-before-left recursive calls preserve the tested OCaml native
application schedule. Takeuchi evaluates its three inner calls right to left.
This differs from the nested calls in classic `tak`; the arithmetic recurrence
is related, but its evaluation schedule and numeric modes are retained here.
Fibonacci's bases are both one, unlike classic `fib`'s zero/one bases.
No memoization, tail-recursion replacement or closed form replaces a kernel.

## Validation and performance questions

Drivers consume every result. The source repetition helper executes count+1
times even when count is zero; the SML helper preserves that convention and
checks every discarded result, adding a documented comparison/retention cost.
The final exact decimal is checked again by the common suite driver. Pi uses
a separate complete streaming checker. Original bounded OCaml runs and
independent Python integer/Decimal algorithms establish the fixtures. Semantic
checks cover modes, bases, signed wrap/order, repetition counts and negative
result checks. Large SML runs are claimed only where explicitly recorded.

Numeric dispatch, functor specialization, boxing, integer width, recursive
calls and object lifetimes are source-based diagnostic hypotheses until
measured or confirmed by compiler inspection. Original OCaml provides
correctness references; normal performance reports compare identical SML.
See the retained Zarith/Num sources and the shared literature survey.

## This workload

Takeuchi retains the fixed tuple (18,12,6), three nested right-first calls
and final result 7. Smoke 0 and normal 100 use the original repetition convention;
large 2500 preserves the published Sandmark count, meaning 2501 kernel calls.
The port checks every call before retaining the final decimal. This variant selects original mode `natint`.

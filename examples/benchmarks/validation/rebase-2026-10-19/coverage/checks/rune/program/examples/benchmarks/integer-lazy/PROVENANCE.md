# integer provenance

## Algorithm and workload

nofib's integer workload traverses a Cartesian grid separately for machine Int
and arbitrary-precision Integer. It repeats this pair of passes for addition,
subtraction, multiplication, floor division/modulus, truncating quotient/remainder,
gcd, lcm and all five comparisons. Preserve operation order, ascending outer and
inner enumerations and forcing every result. Source seqlist observes WHNF but
prints nothing. The suite additionally consumes each value into a checked digest;
that validation cost is measured work.

## History, authorship, revision and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/integer/Main.hs and
Makefile. The individual files state no author or separate redistribution notice;
preserve their exact bytes/history without inventing attribution or a grant.
The established integer name is qualified as integer-lazy and integer-strict for
the two evaluation variants. This is arithmetic enumeration rather than the
separately imported pi or primality workloads.

## Variant differences and numeric semantics

The lazy variant uses explicitly memoized list spines and heads. Each arithmetic
result is forced by the consumer before advancing. Enumeration arithmetic remains
inside the delayed tail, and repeated demand shares that tail. The strict variant
uses the same finite sequence operations with eager suspensions, constructing the
current operation's result list before consuming it. Their values and digests
must agree; their retention and allocation can differ materially.

Original GHC 9.4.7 uses 64-bit signed Int. Word64-based helpers retain that machine
arithmetic on SML hosts whose default Int may be 31 bits. Addition/subtraction/
multiplication wrap modulo 2^64. Signed ordering, magnitudes, sign-adjusted quotient
and floor-division rules are explicit. Zero divisors raise Div; signed minimum
quotient -1 raises Overflow. Gcd/lcm use magnitude/remainder iteration. IntInf
separately implements arbitrary-precision operations, including distinct div/mod
and quot/rem. Every selected grid operand is bounded by 2100000000, and products
and lcm fit signed 64 bits. The machine/extreme-value tests supplement these
selected grids; arbitrary-precision computation is not replaced by Word64.

## Translation and result consumption

The portable SML97 functor uses the shared suspension and cell-sequence support.
The source's machine primitives become explicit Word64 operations and sign rules;
this changes primitive/library implementation costs, which must not be presented
as original Haskell runtime performance. The IntInf gcd/lcm helpers are separate.
Per-run enumeration/result state is recreated; no output is cached across calls.

The source receives one start/step/limit triplet and uses it for both axes and
both numeric representations. Some internal formal b parameters are ignored or
refer back to astart; the public driver preserves the selected CLI behavior,
rather than inventing a different rectangular-grid benchmark. Negative argument
spelling becomes canonical SML ~ for the checked portable driver. The
driver accepts positive strides, operands within +/-2100000000 and at most
2100 values per axis, making the fixed profile domain and resource guard
explicit; it does not claim the original CLI's zero/negative-stride behaviors.

After each pass, consume every value into h=h*1664525+value modulo 2^64 from
1013904223. Booleans become 0/1; integer values convert modulo 2^64 only after
performing their original operation. Compare all 28 exact pair-count/digest
lines and EOF with a reviewed fixture. This prevents an unused-result benchmark
while adding hashing/reference I/O costs to all SML hosts consistently.

## Compiler/runtime questions

Calls through arithmetic functions, explicit delays, tail consumption, eager
retention, machine-word boxing, IntInf representation and division/gcd allocation
are source-based performance questions until backed by compiler inspection or
measurement. Treat digest cost separately when interpreting the workload.
Standard reports compare identical SML; GHC supplies correctness references.
No FFI, compiler feature or runtime extension is required.

## Inputs, independent references and checks

All profiles keep range -2100000000 through 2100000000. Smoke step700000001
has six operands per axis. Normal step14000001 preserves the upstream FAST
300-operand grid for a bounded comparative run. Large step2000001 preserves the
upstream SLOW 2100-operand grid. The original NORM step4500001/934-operand grid
is also retained as a correctness reference and calibration point, rather than
being silently relabeled as the selected normal profile. No dataset is required.

Unmodified GHC originals terminate successfully with empty output on all three
upstream/reduced reference inputs. A reference-only observer adds Show constraints
and a strict digest consumer while retaining original operation selection and
machine/Integer passes. Complete digests agree with an independent exact Python
model for all selected grids and upstream NORM. Observing values changes reference
costs; these are not original-runtime timing results.

A separate GHC/native64 observer and independent model agree on 98 arithmetic
results covering sign combinations, negative division and values beyond signed
31 bits. Tests additionally check machine wrap, exceptional division, gcd/lcm zero,
complete lazy/strict smoke, exact agreement, memoized tail demand, eager strict
enumeration, and wrong count/digest/truncated/extra references. Large SML execution
is claimed only where recorded. See the suite's nofib and measurement literature
for context; no historical speed claim is transferred.

## Recorded native32 diagnostic findings

Managed 32-bit SML/NJ fails two of 114 semantic checks at both levels: constant
signed64 subtraction/multiplication wrap. The other 112 pass there; all 114
pass every other configuration. A separate runtime-input probe passes both
wrap checks on all ten configurations. Native32 prints constant subtraction
7FFFFFFF3FFFFFFF versus runtime 7FFFFFFFFFFFFFFF, and constant multiplication
FFFFFFFF3FFFFFFE versus runtime FFFFFFFFFFFFFFFE. These constant-path findings
are consistent with the existing [Word64 low-half reports](../../../docs/bugreport/smlnj/README.md).
Keep the original expressions and reviewed expected values; no arithmetic
workaround or altered reference is introduced. Full selected-profile outcomes
are recorded separately from these diagnostic failures.

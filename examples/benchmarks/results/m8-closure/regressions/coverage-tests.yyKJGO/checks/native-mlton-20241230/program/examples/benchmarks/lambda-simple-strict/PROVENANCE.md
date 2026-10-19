# lambda-simple-strict provenance

Interpreter: simple. Numeric/syntax policy: strict.

### Algorithm and workload

Evaluate a lambda-calculus program that sums zero through n using an explicit
fixed-point combinator, closures, variable lookup, integer addition and a
zero conditional. Compare a directly recursive interpreter with a state-monadic
interpreter. Preserve both implementations and their original environments,
call-by-name argument closures, association-list lookup and pretty printers.

### History, authorship and variants

The source says From Mark: marku@cs.waikato.ac.nz, November 2001; no surname
is inferred from the address. Pinned nofib revision
b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/lambda. Individual source
and generated fixture files state no separate redistribution notice. Retain
their complete attribution and historical observations under
lambda-simple-lazy/upstream; do not infer a grant from another benchmark.

Original main runs direct and monadic evaluation, each 100 times, interleaving
their output. The suite splits the styles into separately named simple and monad
workloads so each comparison measures one implementation. Each retains its
individual source repetition count. Explicit lazy/strict variants retain
materially different finite syntax/result evaluation and allocation behavior.
No external datasets are required; all selected syntax is source-generated.

The source's historical timing comments concern old Hugs/GHC implementations.
They explain the comparison's motivation and are not measurements of Rune.

### Translation and runtime behavior

Kernel, generators, consumers and checks use SML97. The lazy policy memoizes
term fields, numeric payloads, closure environments and delayed results.
The strict policy evaluates finite payloads eagerly. Both retain the interpreted
language's explicit call-by-name closures: a strict host policy does not turn the
interpreted program into call-by-value or memoize interpreted variable results.

Translate erased Identity directly and keep the direct interpreter's recursive
calls. The other interpreter retains explicit state computations, return/bind,
lookup, current environment, push and withEnv. withEnv evaluates a computation
in a supplied environment while returning the caller's environment; its result
can remain delayed. The source Incr is intentionally a no-op returning zero.

Preserve the fixed-point and partial-sum syntax as shared global source terms.
Construct each selected application anew per repetition. No result cache,
algebraic replacement of evaluation or source transformation eliminates the
interpreted recursion. Indices and source Int arithmetic fit even 31-bit signed
ints for selected sizes; the driver bounds n at 20000 to keep the independent
triangular-number checker portable.

Retain the source direct Con output and monadic pretty-printed value plus final
environment, including its two spaces and trailing newline. Selected source
terms always return Con; the direct derived-Show adapter documents that bounded
domain instead of pretending to implement every unused Read/Show operation.
Full text equality consumes and validates every selected result. Stable
repetitions:checked-characters output replaces repetitive stdout.

### Inputs and correctness

| Profile | Repetitions of each selected style | Summation bound |
|---|---:|---:|
| Smoke | 1 | 80 |
| Normal | 100 | 260 |
| Large | 100 | 550 |

Smoke reduces source FAST's 100 repetitions to one; normal/large retain their
upstream bounds and counts. Independent n*(n+1)/2 arithmetic checks every result,
while the original GHC program reproduces all three complete 200-line fixtures.

An export-only original observer checks 33 term/environment cases: arithmetic,
zero branches, nonnumeric tests, unused arguments, shadowing, captured lexical
environments, explicit Thunk environments, fixed-point recursion and caller
state restoration. The 241-check target additionally covers independent sums,
formatting/brackets, invalid applications, modified output, zero repetitions,
syntax-field demand and sharing.

All six native hosts and Rune pass the private semantic target. Final canonical
matrices/counts are recorded with the import wave. Full normal calibration
covers both styles and both policies; large fixtures are checked independently,
while full SML large repetition runs remain unrecorded. No failing correctness
case can supply accepted measurements.

### Literature and diagnostic questions

The retained source gives the direct-versus-state-monadic experiment and
historical observations. [Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
supplies suite context. Investigate closure allocation, environment traversal,
higher-order state composition, restored lexical scope, evaluation/sharing and
pretty-print consumers. These questions follow source inspection; host-specific
performance conclusions require measurements of the selected implementation.

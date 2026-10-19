# cryptarithm1-lazy provenance

nofib revision `b7391df4540ac8b11b35e1b2e2c15819b5171798`,
`spectral/cryptarithm1/Main.hs`, Makefile and all three stdout fixtures.
The October 1999 correspondence in the source credits Sergey Mechveliani,
Mark Engelberg's September 1999 question, and Fergus Henderson's suggestions.
Preserve the complete history and commented C++ comparison; an individual
license grant is unstated. Input digits and the equation are embedded program
data, with no external dataset. Historical compiler/platform timings in that
correspondence are not measurements of these ports.

## Algorithm and variants

Generate permutations recursively by inserting the current first element at
all positions in each permutation of the tail. Preserve the original addj
list-comprehension order, row sharing and full enumeration: every one of the
10! candidates is tested against THIRTY + 5*TWELVE = NINETY. Do not stop after
the unique answer. The commented C++ next_permutation order is not substituted.
The column-pruned StateT search in cryptarithm2 is a distinct algorithm and
remains separately named.

One SML97 functor supplies memoized sequences/heads in Need and eager finite
sequences in Strict. Both list representations and the original insertion
recurrence remain explicit. Strict materializes the full intermediate permutation
lists; Need streams through the filter. Sharing and allocation therefore differ
materially, while complete output agrees. No mutable in-place permutation
algorithm, pruning rule, memoized search result or new runtime feature is added.

## Translation and demand

Portable list/string operations replace comprehensions and Show. The filter
uses a private cursor inside each memoized output-cell thunk. Advancing that
cursor before its tail call releases the reference to skipped input nodes;
the produced output cell and its tail still share the normal memoized result.
Predicate order, first-output demand and exception memoization remain intact.
The initial closure-based filter retained its original input pointer while
seeking the first match and exceeded the tested 1 GiB cap. The cursor version
passes that bounded -O2 probe. This is a documented representation/liveness
adaptation; it does not establish a general compiler or GC diagnosis.

The original p0 = take 10 [0..9+i] is preserved at each iteration. Every selected
iteration uses digits 0..9, while eager range construction may evaluate its small
unused suffix. Source arithmetic uses GHC Int; digit values, loop controls,
six-place numbers and the largest six-term sum fit signed 31 bits. SML default int
therefore preserves the selected arithmetic. The byte checker consumes the
complete bracket/comma/newline output and checks every iteration before returning
repetition/byte counts. This replaces repeated stdout IO and adds an exact
string comparison; both costs are documented measurement adaptations.

## Profiles and resource evidence

Smoke 1, normal 3 and large 15 preserve FAST/NORM/SLOW parameters. One is the
smallest nonempty source workload: even smoke searches all ten-digit assignments.
Both variants use a recorded 16 GiB memory cap in all profiles. Need smoke
uses 120 seconds and normal 600; Strict smoke uses 600 seconds and normal 1,200.
Lower bounds exposed allocation limits in the register interpreter/JIT at -O2
and time limits in SML/NJ. The original bounded attempts remain in the archive.
These are maximum budgets: successful checks at tighter bounds remain identified
in their transcripts, and fresh retries record every incomplete configuration.
The source, inputs and expected results are unchanged by these resource choices.
Memory-limit and timeout attempts remain separate from successful validation.
Both variants are outside the bounded routine set. Large SML execution
is claimed only where explicitly recorded.

## Correctness, references and diagnostic questions

Original GHC, an independent exhaustive assignment search and all three pinned
stdout fixtures agree on the unique solution. A GHC observer checks the exact
four-element permutation order. Its Kernel module changes only the implicit
Main export boundary so permutations can be observed; the original executable
is built from unchanged Main.hs. A separate SML predicate counter verifies all
3,628,800 candidates on Rune and MLton. Eight semantic checks cover the original
order, all 720 unique six-element permutations, base cases, equation checking,
perturbed assignments, unused digit heads and shared filter-prefix demand.

The retained correspondence and pinned source provide benchmark-specific history;
see also the shared nofib and measurement literature. Backtracking allocation,
list materialization, closure specialization, memoization, stack depth and object
retention are source-based questions until investigated with measurements or IR.
Standard compiler comparisons use identical SML; Haskell supplies correctness
references. Per-engine observed limits do not certify all hosts or large inputs.

The complete coverage ledger records one remaining full-size check: legacy64
SML/NJ 110.99.9 strict normal reaches 1,200 seconds without a result. Modern
SML/NJ and native32 complete it; all small semantic checks pass. Resource
termination is recorded separately from an incorrect result.

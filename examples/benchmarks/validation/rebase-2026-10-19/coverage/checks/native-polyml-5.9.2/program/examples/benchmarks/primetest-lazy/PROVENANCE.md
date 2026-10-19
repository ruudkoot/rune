# primetest-lazy provenance

Finite evaluation: lazy.

## Algorithm and workload

Process decimal integer candidates with the source 100-round strong probable-prime
test. Even/nonpositive guards consume no random values. For each odd candidate,
factor n-1 as 2^k*q, select the source base, compute the nested modular-power
algorithm and inspect up to k repeated squares for its witness. Composite
witnesses stop the remaining trials early.

## History, authorship, variants and notices

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/primetest,
the four literate Haskell modules, Makefile, Readme, mersenne607 and all three
stdin/stdout pairs. Main's author macro explicitly names David Lester; its RCS
last-committer tag is history, not that declaration. The log dates the program
to 1992 and records the 2004 Random-to-MyRandom rename. IntLib credits Joe Fasel
for this modular-power coding; MyRandom credits Lennart Augustsson's generator.
No separate redistribution notice or dataset author is stated in these files.
Retain all original bytes and history. The established primetest name gets
lazy/strict suffixes for material evaluation variants.

The input files provide decimal constants; Readme identifies 2^607-1 as its
principal Mersenne candidate. Smaller and composite candidates remain part of
the collection rather than treating probable-prime output as a general proof.

## Arithmetic, demand and translation

Keep arbitrary-precision candidates, exponents, powers, residues and base-65536
digits in IntInf. Preserve the source nested modular-power loop, including its
exponent-zero shortcut returning 1 without reduction, and the findKQ call at each
trial as written. Selected square counts fit signed 31-bit when converted to the
finite take counter. No fixed-width replacement is used for large arithmetic.

Reuse only the raw two-state generator engine shared with SCS. Initialize the
source states directly to 111/47; do not call SCS's seed mapping or interval
mapper. Explicit Word32 expresses the signed-32-bit Schrage transitions on every
host. Their corrected values stay in the source ranges. Raw result heads and
state transitions remain separately memoized, avoiding unused-head forcing.
Raw numbers become IntInf when used by the digit mapping, covering values that
do not fit a 31-bit SML int.

Retain chop, the source conditional uniform digit mapper and left-associated
makeNumber fold. Lazy accumulation is delayed; strict finite accumulation is
eager. The mapper is not replaced by System.Random, modulo n or a rejection
algorithm. Its zero-low-digit partiality is retained and tested; actual random
bounds n-2 are odd, so that partial case is outside the valid program path.
Fixed seeded witnesses do not establish independent-uniform sampling or transfer
a general statistical confidence claim to the benchmark.

The lazy variant memoizes finite digit/witness spines and heads. Its initial
1/-1 and secondary 1/-1 decisions stop before unused square tails. The strict
variant evaluates the selected finite square list and digit values eagerly,
including source-unused repeated squares. Infinite raw and square streams stay
lazy in both. splitAt retains shared prefix/tail projections; taking the tail
does not force discarded raw heads in lazy mode.

SML reads the selected input file as a finite string and decimal line list.
A final LF is removed as a line terminator while internal empty lines remain
invalid candidates. The selected parser accepts signed decimal integers and
surrounding whitespace, not the full Haskell Read grammar. The complete output
is assembled before returning, whereas the original prints labels incrementally.
Source labels have no separating newlines; preserve that exact result. Only the
suite's controlled report adds its normal line framing.

Each run resets the two seed states and constructs fresh stream cells instead
of retaining a top-level input-stream CAF across repeated suite invocations.
Within-run sharing and state advancement remain. File reading, result validation
and these initialization decisions are measured costs. Unused IntLib cube-root,
logarithm and display helpers are not translated; complete originals remain.

## Inputs, calibration and correctness

| Profile | Candidates | Trials |
|---|---|---:|
| smoke | second original FAST candidate, 74 bits | 100 |
| normal | original FAST candidates 2–4, including the composite | 100 |
| large | complete original five-candidate FAST input, including 607 bits | 100 |

The selected normal input contains 74/112/63-bit candidates. These source subsets
keep bounded routine/comparative work. Removing earlier candidates changes which
deterministic witnesses the remaining candidates see; original and independent
references are regenerated for the exact new sequence with unchanged seeds.
Large preserves the complete FAST sequence. Original NORM=60 and SLOW=300
candidate inputs remain documented and referenced but are not selected profiles.

Both policies' 607-bit single-candidate pilots hit the initial 600-second limit;
these are timeouts, not incorrect results. Smoke and the three-candidate normal
input validate at all 100 rounds under their recorded guards. Large retains the
default 3600-second/8-GiB allowance. Both policies validate the complete
original FAST input on Rune native code at O2, under profile limits and a
2-GiB RSS guard. All profiles keep 100 rounds and the original arithmetic.

GHC originals match every complete upstream fixture. A separate Python integer/
modular-power/generator model agrees on 380 original/small candidates, raw
prefixes and successor-state observations for the small and FAST sequences.
It also confirms the newly selected profiles. Eight exact power cases agree
between GHC and Python, including two nontrivial 607-bit moduli. Those finite
checks are separate from a proof of primality.

Auxiliary SML checks compare candidate outcomes and successor streams, scalar
powers, exact complete normal output, state reset, decimal parsing, factoring,
digit roundtrips and source partiality. Demand probes check unused square tails,
strict selected powers, unused split heads, prefix sharing and zero-length take.
The driver preserves empty-line semantics. All validation is exact, with no
floating tolerance.

## Compiler/runtime behavior and references

Investigate arbitrary-precision multiply/division, exponent loops, finite eager
squares, closure/list allocation, memoized raw state, data width and early exits.
Investigate Rune's portable IntInf limb/division implementation when explaining
large-case timeouts. A different arithmetic library is a different configuration,
not a port fix.
These are source-based diagnostic questions, not measured causal claims.
Comparisons use identical SML; original Haskell supplies correctness references.

[Rabin, Probabilistic algorithm for testing primality](https://doi.org/10.1016/0022-314X(80)90084-0)
provides algorithmic context; the preserved source specifies this particular
witness selection and control flow. [L'Ecuyer's combined-generator paper](https://doi.org/10.1145/62959.62969)
provides generator context, while the source credits its Haskell coding above.
[Partain](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies suite context.
The paper references are not correctness proofs of this SML translation.

# secretary provenance

## Algorithm and workload

Simulate the secretary selection rule on a random ordering of 100 distinct
values. Generate random Integer values in 1..100, remove repeats with linear
list membership, and take the first 100 distinct values. Inspect the first k
values to obtain their maximum; select the first later value at least that
large, and succeed only when it is 100. Evaluate k=35..39 using seeds 1..n,
filter successful trials, count them and divide by n in binary64.

## History, revision, authorship and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798,
spectral/secretary/Main.lhs, Makefile and secretary.stdout. The literate source
retains Koen Claessen's 27 January 1999 bug report, Simon Marlow's Haskell98
adaptation credit, and michalt's March 2017 build/global-RNG change. The mail
quotes historical incorrect results; they are not current expected values or
performance evidence. Individual workload headers state no separate license;
retain them without inferring a grant from the RNG dependency.

Pin System.Random 1.1 at cfdfe6f09ad414fde5b855cc5f90207533413241. Its complete
Random.hs, package metadata and LICENSE retain University of Glasgow credits,
BSD-style terms and the accompanying Haskell98 Report notice. The unmodified
workload and exact library source compile with GHC 9.4.7 and reproduce the pinned
stdout exactly. No replacement RNG, OS seed or unrecorded package version is
used. Name the meaningful evaluation variants secretary-lazy and secretary-strict.

## Variant differences, demand and sharing

The lazy variant keeps explicit memoized raw random-stream heads/spines, nub's
reversed seen list and the finite take100 spine. The same finite sequence is
shared by the prefix maximum and later search. Stop at the first qualifying
candidate, or after all 100 distinct values when the prefix already contains
100. Taking one candidate must not demand its tail or seek a 101st distinct
value in an exhausted 100-value domain.

The strict variant materializes all 100 distinct values before applying the
same rule. A bounded producer combines the infinite raw stream/nub/take boundary,
so strict evaluation terminates while preserving repeated-draw rejection and
linear seen-list membership. This is an explicit evaluation/allocation
adaptation: it consumes the complete coupon-collection prefix, while lazy trials
may stop earlier. The source's finite trial map/filter/length remains explicit
in both styles. Their success counts/probabilities agree; their draw counts,
retention and allocation can differ.

## Portable translation and arithmetic

SML97 Word32 retains StdGen's two strict Int32 state fields. Schrage quotient/
remainder decomposition keeps each mathematical intermediate within signed32;
Word32 sign-bit checks implement its negative corrections without relying on
default Int width. Convert the positive output to IntInf for the source Random
Integer range accumulator, base expansion, q=1000 target magnitude and modulus.
Seed masking and every state/draw transition remain explicit. All selected seeds
fit even a 31-bit host Int. No Float or alternative bounded-integer sampler replaces
this library's algorithm.

Each call recreates seeds/trial state. Mutable references occur in memoized
delays and test-only draw observers, rather than a shared global RNG. The source's
unneeded global RNG, time/FFI initialization, splitting and unrelated Random
instances are not ported; the complete original library remains available as
reference/provenance. Word32 boxing, arbitrary-precision range calculations and
portable stream/list construction have different layout/library costs from GHC.
These are documented translation costs, not original-runtime comparisons.

## Inputs, result checks and diagnostic questions

The population remains 100 and k remains 35..39. Smoke uses 50 trials, normal
uses 500, and selected large preserves the original 5000 through the simulate API.
A 50000-trial reference is retained separately. The bounded normal selection
follows resource calibration; a final-state lazy 5000 preflight takes about
305 seconds under the recorded load and is not a headline timing comparison.
Seeds are exactly 1..n for each k, without cross-k caching. No dataset is needed.
Validate all five exact success counts and the original binary64 ratios against
reviewed count/probability fixtures, then require EOF. The absolute probability
budget is 1e-15: selected integer conversions are exact, with one binary64
division and decimal-reference parsing; it is not a Monte Carlo confidence
interval. Wrong counts/probabilities, nonfinite values, truncation and extra
reference data must fail. Checking/reference I/O is measured work. The suite prints n:checked after
validating every count/probability, replacing the original probability-list
output. The driver exposes the simulate trial-count parameter with a positive
1..50000 bound; it does not add a universal size argument to unrelated kernels.

Source inspection suggests questions about membership scans, repeated random
draws, memoized prefix sharing, early stopping, boxed words/integers and retained
lists. These remain hypotheses until supported by compiler analysis or
measurements. Standard reports compare identical SML; Haskell supplies correctness
references. No compiler/runtime feature is introduced.

## Independent references and literature

The original default prints [0.356,0.356,0.358,0.3596,0.3594]. A count-only observer
retains the original processing expression and exposes its numerator at fixed
trial counts. An independent model uses multiplicative modular recurrences,
set-based full permutations and direct threshold evaluation. All five counts
agree through 50000. Separate original observers agree with every selected RNG
state, full permutation and minimum lazy/complete strict draw count. Wide Integer
ranges through signed 10^50 also agree with independent base expansion.

Tests cover 60 full RNG transitions, five general ranges, six complete permutations
in both variants, 30 lazy demand/sharing and strict consumption cases, complete
smoke results and numerical/negative checks. Large SML execution is claimed only
when recorded. Earlier IntInf-state resource calibration is intermediate work;
the final helper retains the source's fixed-width state representation.

[Ferguson, Who Solved the Secretary Problem?](https://doi.org/10.1214/ss/1177012493)
provides mathematical and historical context. System.Random credits L'Ecuyer's
[Efficient and Portable Combined Random Number Generators](https://doi.org/10.1145/62959.62969)
and Lennart Augustsson's transliteration. The pinned source determines this
workload's exact seeding/range rules; those papers do not establish its SML
performance or validate a changed RNG stream.

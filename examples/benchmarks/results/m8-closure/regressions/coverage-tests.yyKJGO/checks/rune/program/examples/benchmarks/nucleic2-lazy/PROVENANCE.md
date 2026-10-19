# nucleic2 provenance

## Algorithm and workload

Search the complete Pseudoknot molecular conformation problem by sequential
backtracking. Place nucleotides through homogeneous three-dimensional
transformations, prune with two distance constraints, and compute the most
distant atom over all solutions. Preserve all 23 domain stages, candidate
order, 46 conformation records, four conformation lists, 25 common atoms
and base-specific atoms. Keep the p_o3 generator's reversed conformation
groups and 60/180/275 ordering.

## History, authorship, upstream revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798,
spectral/hartel/nucleic2. Main.hs credits Marc Feeley and June 6, 1994.
README credits Lennart Augustsson for the HBC Haskell version. MAIL records
Pieter H. Hartel's June 13, 1994 benchmarking invitation and coordination;
that role is not original program authorship. The README's 2017 update
explains removal of historical non-Haskell files. Its old archive listing
does not establish that those files remain in this pin.

Pseudoknot is the literature name; nucleic and nucleic2 are collection names.
The existing classic nucleic uses a binary64 SML maximum-distance program
with different atan2 and candidate-order code. The separate nucleic-smlnj
counts anticodon solutions. Neither is an exact duplicate of this binary32
Haskell problem. Retain all names and provenances.

Original program/data notices and correspondence remain under upstream/.
No separate redistribution licence for the program or conformation tables
was found in that directory. Record the historical porting invitation
without inventing a broader licence. GHC support licensing is separate
and retained in full. The embedded source database supplies the input.

## Known variants and selected build

The default header defines FLOAT_TY as Float: preserve binary32 semantics.
Default placement stores relative coordinates and recomputes an absolute
point when queried. USE_HARTEL_LAZINESS instead stores lazily transformed
coordinates at placement, sharing them across queries and descendants.
Import both strategies.

nucleic2-lazy and nucleic2-strict use on-demand transformation.
nucleic2-shared-lazy and nucleic2-shared-strict use shared placed coordinates.
Suffixes select memoized or eager finite-data policies. They do not claim
to reproduce the legacy STR pragma, ignored by current GHC. Historical
unboxed/PrimIO/printf branches need old primitives or FFI and remain outside
the portable build, with supplementary dispositions and original source.
No prerequisite compiler/runtime facility is added.

## Translation, numeric semantics and demand

Geometry, data, drivers and checks use SML97. Represent selected finite
normal binary32 values exactly in binary64 storage and round after each
source arithmetic operation, using the reviewed portable helper.
Zero and normal values are checked; general Float subnormal, overflow and
NaN behavior is outside this helper's selected domain. Completed searches,
including eager shared coordinates, stay inside it. Software rounding is
measured SML code; this is not a native-binary32 comparison with Haskell.

Preserve operation grouping and shared alignment intermediates.
GHC 9.4.7 base 4.17.2.0 leaves Float.atan2 at the RealFloat default: keep
rounded division, atan, pi, branches and signed zeros. Use SML Math and
round transcendental results to binary32. This library replacement can
differ from GHC primitives, so compare coordinates with explicit bounds.
Keep GHC.List.maximum's strict left fold and separate map producers.

Memoized node/scalar cells preserve sharing and ignored fields. The strict
policy materializes finite data and can evaluate points the lazy policy
skips. Shared nucleotide records retain unchanged transform tables.
SML constructor/closure/reference layout and literal conversion introduce
documented representation/support costs.
The SML/NJ measurement adapter loads declarations before exporting its heap
image. Top-level eager input initialization can therefore fall in its build
phase, while an executable or Rune bytecode initializes on process start.
Read compilation and runtime reports together; a fresh image process does
not imply identical initialization placement across hosts. Prime-suffixed internal names
become Prime. Selected integers fit signed 31 bits; bit fixtures use
unsigned Word32 values. Every source constant is independently checked.

The original rereads getArgs inside the repetition loop. The portable
driver passes its fixed runtime argument text on each call and checks
every maximum. This adaptation can affect invariant-code opportunities;
identical original-language optimization behavior is not claimed.
The measured consumer computes the maximum directly without retaining the
solution root for an extra traversal. Full coordinate checks are separate.
Add a verified-iteration summary to the source's empty stdout.

## Profiles, validation and recorded observations

| Profile | Complete searches |
|---|---:|
| Smoke | 3 |
| Normal | 25 |
| Large | 125 |

These preserve FAST/NORM/SLOW counts. The driver has a bounded argument
domain; nonpositive counts perform no searches within that domain. Normalize a leading Haskell minus sign to the common
SML argument helper spelling; selected positive counts are unchanged.
Resource defaults remain 30 seconds/1 GiB, 600 seconds/4 GiB and
3600 seconds/8 GiB unless a later override is explicitly recorded.

The measured checker requires a finite maximum within relative 1e-6 of
GHC's binary32 33.7975921630859375 and returns verified iterations.
The independent oracle additionally requires 50 solutions, exact
conformation/variable/atom order, base kinds and original transform tables.
Every coordinate must satisfy 1e-4 + 1e-6*abs(reference). This budget was
recorded before comparison: one unit of the four-decimal input resolution
plus the existing Pseudoknot relative budget. It is an engineering
validation budget, not a proved accumulated-roundoff or physical-model bound.

All 6624 input Float32 patterns agree with GHC and independent Python
decoding. All four SML variants agree bit-for-bit, match 1150 conformation
choices and validate all 109800 coordinates. The largest observed absolute
difference is 6.866455078125e-5. Source pruning work agrees exactly:
38496 candidates, 5596 accepted steps, 27000 first-constraint tests with
50 successes and 6000 second-constraint tests with 50 successes.

All 109800 coordinates accept originals and reject positive/negative
four-budget perturbations after binary32 rounding. Additional controls
cover round-to-even, arithmetic precision, signed zero, nonfinite results,
unused coordinates and actual sharing. The unmodified GHC main succeeds
for all three source counts and nonpositive controls.
The [complete validation record](../results/m3-nucleic2/README.md) retains
all passing, failing and incomplete host/engine groups. All 64 Rune profile
combinations pass, along with all sixteen normal count samples. This closes
the final M3 import; host exceptions remain explicit and contribute no accepted
timings. The large profile preserves the upstream 125 searches; its parameters
and original-language execution are recorded, without claiming a full large
SML host matrix.

## Performance questions and literature

The [Pseudoknot paper](https://doi.org/10.1017/S0956796800001891) studies
compilation, evaluation and representation choices. The
[author preprint](https://ris.utwente.nl/ws/files/6988019/JFP_pseudoknotI.pdf),
section 5.7, discusses precision. Its historical results are not Rune
measurements. The source README identifies the original
Feeley/Turcotte/Lapalme molecular-structure application.

Numeric representation, software rounding, calls, pruning, delayed
coordinate sharing and lifetimes are source-based diagnostic hypotheses.
Standard comparisons use identical SML on Rune and SML hosts; Haskell is
the correctness oracle. Inspected GHC base support is pinned to commit
00920f176b0235d5bb52a8e054d89a664f8938fe with identities and full licence.
No benchmark-speed conclusion follows from these correctness probes.


### Recorded smoke resource override

The three-search eager shared-coordinate smoke workload reaches the default
30-second runtime limit on all four Rune engines at O0. Preserve the input
and record 120 seconds/1 GiB for this one profile. Earlier timed-out attempts
remain evidence. Other smoke profiles retain 30 seconds/1 GiB; normal and
large parameters/limits are unchanged unless separately recorded.

### Completed host and profile gates

The canonical profile matrix has 98 of 112 passes, with 116 raw attempts
retained. Legacy SML/NJ contributes eight domain-error failures. Development
SML/NJ contributes three smoke loading timeouts and one explicit 1-GiB
allocation failure with unclassified phase. ML Kit contributes two empty-log
smoke compile failures. Both development SML/NJ and ML Kit pass all four
normal profiles. No kernel or numerical bound is adjusted for a host failure.
The complete semantic target has twelve passing groups of 5081 assertions,
a partial failing legacy group and an unclassified ML Kit compilation failure.
See the linked record for counts, independent oracles and repository acceptance.

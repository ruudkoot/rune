# Benchmark literature and diagnostic map

This survey connects the initial inventory to established benchmark names
and evaluation methods. Algorithm papers explain the computation; source
history identifies a particular implementation. Performance sensitivity
statements below are hypotheses to test on Rune, not measured results.

## Small recursive and symbolic programs

Richard P. Gabriel's [*Performance and Evaluation of Lisp Systems*](https://dreamsongs.com/Files/Timrep.pdf)
(1985) is an important ancestry reference for classic recursive and symbolic
benchmarks. Programs such as Takeuchi/tak and symbolic rewriting should be
used as diagnostic kernels alongside applications. Calls, branches, closure
representations and allocation can all influence results; fast execution of
one such program does not establish overall compiler performance.

Will Partain's [*The nofib Benchmark Suite of Haskell Programs*](https://doi.org/10.1007/978-1-4471-3215-8_17)
(Glasgow 1992) explains the motivation for separating toy programs, kernels
and applications. The pinned suite preserves these as `imaginary`,
`spectral` and `real`, with later GC, shootout and concurrent collections.
Ports should preserve this breadth. Demand-sensitive streams, exact real
arithmetic, search and higher-order code require explicit decisions about
sharing; strict rewrites are separate implementations.

The [pinned clausify source](clausify-lazy/upstream/Main.hs) credits Colin
Runciman's 1990 propositional rewriting program, David Wakeling's 1992 batch
adaptation and the 1994 ordered-insertion correction. This is source history,
separate from Gabriel ancestry. Formula expansion, lazy subtree sharing,
ordered literal/clause lists and short-circuit tautology checks are useful
diagnostic questions; an independent truth-table check establishes logical
results without establishing a performance cause.

For the list-sorting pilot, Larry C. Paulson's [*ML for the Working Programmer*,
Lists chapter](https://doi.org/10.1017/CBO9780511811326.005) (second edition,
1996) supplies the algorithmic background. ML Kit's `kittmergesort` source
states its additional copying policy for region allocation. Measure the
actual source's lifetimes, rather than inferring them from the algorithm's
name. Plain merge, top-down mergesort and region-friendly variants remain
distinct entries until their workloads are compared.

## Numerical workloads

McIlroy's [*Power series, power serious*](https://doi.org/10.1017/S0956796899003299)
(JFP 9(3), 325-337, 1999) motivates exact compositional streams for generating
functions and differential equations. nofib's GC and spectral versions retain
recursive series knots but differ in coefficient types and forcing/output.
Their explicit SML delays preserve the demand needed for integration to emit
a leading zero before inspecting its operand. These are source-supported
translation decisions; closure costs and retained prefixes require measurements.

Hartel et al.'s [*Benchmarking Implementations of Functional Languages with
Pseudoknot, a Float-Intensive Benchmark*](https://doi.org/10.1017/S0956796800001891)
(JFP 1996) identifies a cross-language workload also named `nucleic` and
`nucleic2`. The pinned nofib README describes coordinate transformations
computed on demand, at placement, or lazily with sharing. These are
material differences: pruning can avoid transformations, while repeated
on-demand evaluation can duplicate them. The portfolio should preserve the
specific variant and numerical result, not only the Pseudoknot name.

Cooley and Tukey's [*An Algorithm for the Machine Calculation of Complex
Fourier Series*](https://www.cs.jhu.edu/~misha/ReadingSeminar/Papers/Cooley65.pdf)
(1965) is the algorithm reference for FFT families. The inventory includes
multiple implementations; complex-number representations, lists versus
arrays, intermediate allocation, traversal order and numerical validation
need separate inspection.

Barnes and Hut's [*A hierarchical O(N log N) force-calculation
algorithm*](https://www.nature.com/articles/324446a0) (1986) distinguishes
hierarchical force approximation from direct all-pairs `nbody` calculations.
Both exercise floating-point work, but their tree traversal, locality,
allocation and asymptotic scaling differ. Keep them distinct and record
physical inputs and approximation parameters.

## Structured numerical workloads

Levinson's [prediction/filter-design paper](https://doi.org/10.1002/sapm1946251261)
(1946) provides context for autoregressive coefficient workloads. Sandmark's
[Levinson-Durbin port](levinson-durbin/PROVENANCE.md) preserves unnormalized
correlations, fresh coefficient arrays and its order-plus-one wrapper. Exact
PCM conversion and independent high-precision dense solves establish the
selected results; array lifetimes and scalar-ref optimization remain diagnostic
questions.

Householder's [unitary triangularization paper](https://web.stanford.edu/class/cme324/classics/householder.pdf)
(1958) explains the reflection family. The [QR workload](qr-decomposition/PROVENANCE.md)
constructs full Householder matrices and copies row suffixes. Its rank-deficient
input makes reconstruction/orthogonality checks preferable to requiring one
particular Q basis. These implementation details come from source inspection.

[Crout's 1941 paper](https://doi.org/10.1109/T-AIEE.1941.5058258) anchors a method
family; it does not certify this benchmark's pivot selector. The
[retained Sandmark variant](crout-decomposition/PROVENANCE.md) selects raw-column
pivots and has a reproducible full-size reconstruction limitation. Original
execution and exact rational replay establish its actual result. Keep source
behavior, mathematical reconstruction accuracy and performance hypotheses distinct.

Aberth's [simultaneous-root-method paper](https://www.ams.org/mcom/1973-27-122/S0025-5718-1973-0329236-7/S0025-5718-1973-0329236-7.pdf)
(1973) supplies context and references Durand and Kerner. The
[source workload](durand-kerner-aberth/PROVENANCE.md) uses Durand-Kerner updates
with a circle initializer and squared-displacement stopping. Complete
high-precision refinement/coefficient reconstruction and one-to-one root matching
validate selected outputs. Convergence variation, boxing and allocation require
separate investigation before assigning performance causes.

The [sequential multilayer workload](naive-multilayer/PROVENANCE.md) adds
mutable model parameters, higher-order activation fields and dense Jacobian
allocation. Rumelhart, Hinton and Williams's
[backpropagation paper](https://doi.org/10.1038/323533a0) (1986) supplies method
context. The [Ionosphere dataset record](https://doi.org/10.24432/C5W01B)
provides provenance, citation and licensing. Gradient finite differences and
independent structured-derivative training check the selected model results;
training-set predictions are correctness observations. They do not establish
generalization performance. Compiler specialization, temporary arrays and
input/model initialization need separate investigation.

## Decision diagrams and closure lifetimes

Welch's [*A Technique for High-Performance Data Compression*](https://doi.org/10.1109/MC.1984.1659158)
(Computer 17(6), 8-19, 1984) anchors LZW ancestry. Sanders's nofib implementation
retains a persistent prefix tree, fixed 12-bit codes and a specific odd-code
packing rule. Those details come from the program, not a claim that every
LZW implementation shares its representation. Inspect lookup depth, path copying,
dictionary saturation and lazy versus eager updates before assigning costs.

Randal E. Bryant's [*Graph-Based Algorithms for Boolean Function
Manipulation*](https://www.cs.cmu.edu/~bryant/pubdir/ieeetc86.pdf) (1986)
explains ordered reduced decision diagrams and operations on them. Sandmark's
BDD workload constructs a hidden-weighted-bit function using unique-node
hashing and operation caches. Investigate node allocation, cache behavior,
array access and recursive traversal, and validate the represented Boolean
function independently. This paper is an algorithm reference, not evidence
that Bryant wrote the particular benchmark port: its header credits Xavier
Leroy's Caml translation and leaves the original SML author unspecified.

SML/NJ's `safe-for-space` README points to Shao and Appel's [*Efficient and
Safe-for-Space Closure Conversion*](https://doi.org/10.1145/345099.345125)
(TOPLAS 2000). Also consult Paraskevopoulou and Appel's [*Closure Conversion
Is Safe for Space*](https://www.cs.princeton.edu/~appel/papers/safe-closure.pdf)
(2019) for the distinction between allocation and simultaneous liveness.
Such workloads can reveal retained environments that a total allocation
counter alone does not characterize. Keep live-space evidence separate from
instruction and allocated-byte counts.

## Compiler transformations and collectors

[MLton's whole-program optimization documentation](https://www.mlton.org/guide/20241230/WholeProgramOptimization)
provides a transformation vocabulary: specialization, inlining, unboxing,
argument flattening and representation selection. Generator/compiler
applications such as `lexgen`, `mlyacc`, `hamlet` and `vliw` combine many of
these concerns and need profiling before assigning a regression to one pass.

Elsman and Hallenberg's [*Integrating region memory management and tag-free
generational garbage collection*](https://elsman.com/mlkit/pdf/jfp2021.pdf)
(JFP 2021) evaluates classic SML workloads with different memory-management
configurations. It motivates keeping execution time, memory use, object
lifetimes and heap policy visible together. Its experimental results are
about those implementations, not measured predictions for Rune.

The [Ellis-Kovac-Boehm GCBench description](https://www.hboehm.info/gc/gc_bench.html)
explains an artificial allocation workload with retained structures and
trees of varying sizes, along with its limitations. Investigate its ancestry
in nofib's `gc/gc_bench` before adding another copy. A regular artificial
lifetime pattern is useful for collector diagnostics but does not replace
application allocation behavior.

Sivaramakrishnan et al.'s [*Retrofitting Parallelism onto OCaml*](https://arxiv.org/abs/2004.11663)
(ICFP 2020) and [*Retrofitting Effect Handlers onto OCaml*](https://arxiv.org/abs/2104.00250)
(PLDI 2021) provide context for Sandmark's sequential controls and
runtime-specific workloads. Preserve that distinction: porting the sequential
computation does not measure effect dispatch, scheduler behavior or parallel
collector scaling.

## Measurement and additional coverage

Kalibera and Jones's [*Rigorous Benchmarking in Reasonable Time*](https://kar.kent.ac.uk/33611/)
(ISMM 2013) motivates explicit samples and attention to variation. Barrett
et al.'s [*Virtual Machine Warmup Blows Hot and Cold*](https://arxiv.org/abs/1602.00602)
(OOPSLA 2017) shows why a fixed number of discarded runs is not proof of
steady-state performance. Keep fresh-process execution, repeated execution,
compilation and instrumentation separate, as the roadmap specifies.

Further candidates include Gabriel/Larceny Scheme workloads, the
[Computer Language Benchmarks Game](https://benchmarksgame-team.pages.debian.net/benchmarksgame/index.html)
and [PBBS](https://www.cs.cmu.edu/~pbbs/). ML Kit `test/weeks4.sml` explicitly
credits a TIL-suite adaptation of Thomas Yan's Grobner-basis program by
Allyn Dimock, modified for MLton by Stephen Weeks; that workload is now
scheduled rather than excluded as a regression. This is source-history
evidence, not a claim that all TIL programs are already included. nofib's shootout and Sandmark's
related programs already overlap the Benchmarks Game; compare actual
implementations before treating these as new algorithms. Keep parallel PBBS
candidates deferred under the roadmap's feature policy.

Per-import README sections must add the program's own provenance and useful
specific references. A shared family reference is not a substitute for that
history, and uncertain attribution must stay explicitly uncertain.

## References added with M2 imports

* [Gibbons, Unbounded Spigot Algorithms for the Digits of Pi](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf):
  linear-fractional streaming algorithm used by pidigits. Its SML driver
  selects zero occurrences instead of a digit-count bound.
* [Yan, The Geobucket Data Structure for Polynomials](https://doi.org/10.1006/jsco.1997.0176),
  Journal of Symbolic Computation 25(3), 285-293 (1998): the source citation
  misspells the title and reports volume 23. This corrects the bibliography;
  the pinned source header remains unchanged. Diagnostic claims about the
  specific Tyan source still require inspection and measurements.
* [Rivest, RFC 1321](https://www.rfc-editor.org/rfc/rfc1321): MD5 algorithm
  and standard result vectors; seven vectors are included in the independent
  correctness target.

## SCC historical reference

The pinned nofib SCC main identifies its graph as Figure 6.4 of
[Peyton Jones, *The Implementation of Functional Programming Languages*](https://simon.peytonjones.org/slpj-book-1987/),
Prentice Hall, 1987. The author provides a searchable edition. The port's lazy
tuple-field explanation is established by its source and GHC demand observer;
its performance implications remain hypotheses for measurements.

## Heap consolidation and sequential array imports

Okasaki's retained July 1995 correspondence identifies nofib's Fibonacci-heap
example and its mutable-array versus functional consolidation comparison.
[Fredman and Tarjan (1987)](https://www.cs.princeton.edu/courses/archive/fall03/cs528/handouts/fibonacci%20heaps.pdf)
provide the algorithmic reference; the port implements the source's smaller
persistent interface and retains its amortization caveats. GC's single large
run and spectral's 200 smaller sorts remain separately named profile variants.

Sandmark's sequential quicksort uses last-pivot Lomuto partitioning, while its
mergesort uses alternating buffers and the original threshold-32 small-array
routine. Aumüller and Hass's [*Simple and Fast BlockQuicksort using Lomuto's
Partitioning Scheme*](https://arxiv.org/abs/1810.12047) (2018 preprint, accepted
ALENEX 2019) supplies related partitioning literature. Its block algorithms
are different from this direct port; the paper's performance findings are
not measurements of this benchmark.

Floyd's [*Algorithm 97: Shortest path*](https://doi.org/10.1145/367766.368168)
(1962) anchors the all-pairs graph workload. The pinned Sandmark source, rather
than the algorithm name alone, establishes Infinity/Value representation,
update cases and the k/i/j loop order. Matrix multiplication preserves its
integer row arrays and i/j/k loop nest.

The [pinned OCaml Random source](https://github.com/ocaml/ocaml/blob/99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93/stdlib/random.ml)
defines the input generator. Its modified lagged-Fibonacci transition,
rejection sampling and selected initial states are reproduced in SML97.
Reference streams establish input identity; they do not establish performance
sensitivity to a compiler transformation. Setup precomputation, validation
work and the isolated 32-bit SML/NJ arithmetic failure are recorded separately.

## Sorting source attribution

The nofib sorting modules cite only a “Meira thesis.” Richard Jones's
[University of Kent bibliography](https://www.cs.kent.ac.uk/people/staff/rej/gcbib/gcbibM.html)
records Silvio R. de L. Meira, *On the Efficiency of Applicative Algorithms*,
PhD thesis, March 1985 (entry meir85). This is a bibliographic candidate for the
abbreviated attribution; exact code ancestry remains an inference. No technical
or timing finding is taken from the unread thesis. The retained source and tagged
GHC observers establish the port's algorithms, ties and composition order.

## Functional geometry

Henderson's [*Functional Geometry* (1982)](https://worrydream.com/refs/Henderson_1982_-_Functional_Geometry.pdf)
uses compositional line pictures. Its pseudocorner/pseudolimit definitions match
the nofib fish hierarchy. The benchmark's particular integer rounding and
length-only formatter observation come from its pinned Haskell source; they are
preserved separately from the paper's abstract geometric account. Source comments
about scale inlining and formatter arity identify hypotheses for current compiler
analysis, rather than measurements of Rune.

## Sequential norm and bounded-grid Life

The [Benchmarks Game spectral-norm specification](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/spectralnorm.html)
identifies the task and requires the contributed algorithm, including separate
matrix procedures; it recommends 5,500 for performance runs. The retained OCaml
source establishes forty passes and per-call temporary allocation. Per-N scalar
references validate the finite truncation, rather than claiming a fixed error
to the infinite operator's norm.

Gardner's [*Mathematical Games*, October 1970](https://www.scientificamerican.com/article/mathematical-games-1970-10/)
is a historical reference for Conway's Life. Program-specific dense row arrays,
zero boundaries, exception handling and buffer swaps come from the pinned
Sandmark implementation, independently of that historical attribution. The
shared generator and complete original/reference boards establish input and
result identity; performance effects remain hypotheses until measured.

## Benchmark Game references added with sequential ports

* The [binary-tree task](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/binarytrees.html)
  records GCBench ancestry and its allocation/lifetime model. Tree layout and
  traversal observations in individual ports remain explicit source variants.
* The [fannkuch task](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/fannkuchredux.html)
  documents permutation/checksum ordering and cites Anderson and Rettig,
  [*Performing Lisp Analysis of the FANNKUCH Benchmark*](https://doi.org/10.1145/382109.382124).
  That paper is a historical reference here. The imported sequential variant's
  bounds repair and correctness evidence come from the retained source,
  checked OCaml reference and independent SML implementation.

## Probability selection and fractal workloads

Ferguson's [*Who Solved the Secretary Problem?*](https://doi.org/10.1214/ss/1177012493)
provides historical/mathematical context for threshold selection. The nofib
secretary workload's exact nub/demand pattern, seeded trials and expected
probabilities come from its pinned program and random-1.1 dependency, rather
than an asymptotic optimal-stopping claim. That dependency credits L'Ecuyer's
[*Efficient and Portable Combined Random Number Generators*](https://doi.org/10.1145/62959.62969)
and Augustsson's transliteration. Full source/independent state, permutation
and trial checks establish the selected inputs; the paper does not measure
this SML port.

The literate Mandel sources cite Falconer. The publisher's later edition of
[*Fractal Geometry*](https://doi.org/10.1002/0470013850) provides background;
it is not identified as the historical edition cited by the source. Exact
current/historical thresholds, scaled magnitude, cyclic lists and boundary
behavior come from the retained modules and GHC Data.Complex. They are not
interchangeable implementations of an abstract Mandelbrot task.

Mandel2 cites Peitgen and Richter's [*The Beauty of Fractals*](https://doi.org/10.1007/978-3-642-61717-1),
page121. The page attribution is retained from the source; no independent audit
of that page is claimed. The source defines this workload's particular binary32
steps, perimeter heuristic and direction conditions. Complete tree references
preserve those conditions, including outward scans. Neither book establishes
performance causes for the SML variants. Boxing, laziness, strict retention,
normalization and validation costs remain source-based diagnostic questions
until supported by measurements or compiler inspection.


## Constructive exact real arithmetic

See the [exact-real arithmetic literature review](validation/exact-reals-literature.md)
for the imported source, precision argument and validation scopes.

## Primality testing and generator state

Rabin's [Probabilistic algorithm for testing primality](https://doi.org/10.1016/0022-314X(80)90084-0)
(1980) supplies probabilistic-test context. L'Ecuyer's
[Efficient and Portable Combined Random Number Generators](https://doi.org/10.1145/62959.62969)
(1988), section 5 and figure 3, supplies the combined-generator context and
32-bit implementation parameters. The retained nofib source credits Lester,
Fasel and Augustsson for the program and its particular codings.

The port-specific evidence comes from pinned source, exact original outputs,
independent integer/state calculations and SML checks. Fixed seeded witnesses
do not transfer an independent-uniform confidence bound to this benchmark.
The recorded review scope uses publisher bibliographic/abstract information and
the author paper's indexed generator section; direct full-text fetches failed.

## Particle/grid simulation

Hockney and Eastwood's [Computer Simulation Using Particles](https://www.routledge.com/Computer-Simulation-Using-Particles/Eastwood-Hockney/p/book/9780852743928)
(1988) gives particle/grid and field-solver context, based on the publisher's
description and contents. The nofib PIC source, rather than a generic physical
model, defines its active interpolation constants, parameter order and demand.
Exact reference traces and empirical SML checks establish the port-specific
evidence separately.

## Binary space partitioning modeller

[Fuchs, Kedem and Naylor, On visible surface generation by a priori tree structures](https://doi.org/10.1145/800250.807481)
(1980) supplies partition-tree rendering context. Publisher-indexed bibliographic
information was checked; direct publisher retrieval failed. Do not infer this
paper authorship for nofib's two-dimensional modeller or claim its algorithms
are identical. The pinned program and GHC interface establish the specific
wrapped rational semantics, local par stub, seq demand and global batch sharing.
Compiler performance explanations remain hypotheses until separately measured.

## Knight tours and mating search

The pinned knights KnightHeuristic commentary credits Bornat's Programming from
First Principles, Positively the last flourish. Its functional.bib gives a 1986
Prentice-Hall reference; this records the program's attribution without claiming
a separate review of the book. The source's Eq/Ord board conventions, quicksort,
degree recomputation and list/array variants define the measured algorithms.

The mate README describes AND–OR search of depth 2*N-1. Puzzle headers separately
credit composers and publications, including Heathcote (Reading Observer, 1904),
Kohtz and Kockelkorn (Schachaufgaben, 1875) and von Holzhausen (Deutsches
Wochenschach, 1913). These are input origins, not program authorship or proof of
full modern chess rules. Source-specific move ordering, pruning and printed
subtree compaction are established by source and original output observations.
Performance explanations remain diagnostic hypotheses.

## Expert-system feedback and functional circuits

The expert README credits Ian Holyer's Functional programming with Miranda
(Pitman, 1991) and dates its adaptation March 1993. That is recorded ancestry,
not a separate review of the textbook. Pinned Search.hs explains its November
1999 shared-question-string change. Source and original dialogs establish the
specific unification, lazy table and request/response behavior.

[O'Donnell's research bibliography](https://www.dcs.gla.ac.uk/~jtod/research/)
lists Hardware description with recursion equations (1987). It supplies
functional circuit-simulation context; the 1992 multiplier source defines this
benchmark's actual gates and strictness. Trace and ready-only consumers demand
different portions of that circuit, demonstrated by original/model agreement and
an explicit pending-product check.

## Regex-redux and library boundaries

[The Benchmarks Game description](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/regexredux.html)
defines one-pattern-at-a-time searches and ordered substitutions, and distinguishes
regex library algorithms. [The OCaml 4.14 Str manual](https://ocaml.org/manual/4.14/api/Str.html)
supports the adapter's anchors, searching and replacement interface. Original
library observations establish selected edge cases; the portable implementation
covers only the fragment used by this program. The library replacement, buffered
input and smaller generated profile sizes are explicit, separate from correctness
and performance findings. All diagnostic performance explanations remain hypotheses.

## Hartel circuit events and functional substitutions

[Hartel and Langendoen's collection paper](https://doi.org/10.1145/165180.165230)
(1993) provides translated-benchmark context, based on institution metadata and
the abstract. It is not individual authorship evidence for the generated event
or typecheck modules. Their pinned source and compatibility shim establish the
particular evaluation details, including the no-op miraseq stub.

[Milner's A theory of type polymorphism in programming](https://doi.org/10.1016/0022-0000(78)90014-4)
(1978) provides polymorphic-inference context. The benchmark preserves its own
functional substitution, environment, name-supply and unification ordering.
Original inferred rows and explicit demand/collision controls support the port;
the paper's soundness results are not transferred to source-specific arity or
shadowing behavior. Performance questions remain hypotheses until separately
supported by measurements or compiler analysis.

## Dominator implementation evidence, 2026-10-18

dom-lt cites Lengauer and Tarjan (1979), Muchnick (1997), and Brisk and
Sarrafzadeh (2007); these are declared source references, not newly claimed
paper reviews. The pinned code, minimal counterexample, exact threshold patch
and independent fixed-point model establish the correctness finding recorded
in validation/dom-lt-source-issue.md. Patricia/bitmap operations, DFS, path
compression, persistent environment records, CPS specialization and array
initialization are diagnostic questions inferred from source. Counts and
timings do not establish their individual performance effects.

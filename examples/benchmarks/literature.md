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

For the list-sorting pilot, Larry C. Paulson's [*ML for the Working Programmer*,
Lists chapter](https://doi.org/10.1017/CBO9780511811326.005) (second edition,
1996) supplies the algorithmic background. ML Kit's `kittmergesort` source
states its additional copying policy for region allocation. Measure the
actual source's lifetimes, rather than inferring them from the algorithm's
name. Plain merge, top-down mergesort and region-friendly variants remain
distinct entries until their workloads are compared.

## Numerical workloads

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

## Decision diagrams and closure lifetimes

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

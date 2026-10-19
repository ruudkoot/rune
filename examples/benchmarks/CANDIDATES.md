# Additional benchmark candidates

Reviewed 2026-10-19. These ranks propose later audits, not new imports in the
initial suite. Pin and inspect individual programs, variants, inputs and
notices before proposing implementation. Existing overlap below is inferred
from Rune's catalogue and the linked collection descriptions.

| Rank | Candidate | Existing overlap | Possible contribution and condition |
|---|---|---|---|
| 1 | Larceny mperm and gcold | GCBench, tree allocation and nofib GC workloads | More explicit retained-age patterns. Review original mutation, retention and input semantics before selecting a portable representation. |
| 2 | PBBS sequential suffix-array and geometry references | Sorting, graph500, Barnes-Hut and graph processing | Defined input distributions and output/quality testers may add useful cases. Audit a specific sequential algorithm; parallel implementations remain deferred. |
| 3 | Gabriel deriv/dderiv and property-table variants | Tak, Boyer, recursive kernels and symbolic algebra | Compare complete source before adding aliases. Preserve materially different lookup/mutation behavior rather than count a renamed duplicate. |
| 4 | Benchmarks Game regex-redux and sequence-processing variants | nofib shootout plus binary trees, n-body, spectral norm, Mandelbrot, fasta and pidigits | Select only genuinely different algorithm/input behavior. Library-dependent regex variants need a reviewed portable engine; parallel entries stay deferred. |
| 5 | Further Larceny numerical/interpreter/application programs | Nucleic/Pseudoknot, ray tracing, interpreters, sorting and parsing | Prefer a demonstrated coverage gap over another familiar name. Scheme continuation/Unicode/runtime-specific workloads need explicit facility review. |

The [CMU Gabriel archive](https://www.cs.cmu.edu/afs/cs/project/ai-repository/ai/lang/scheme/code/bench/gabriel/0.html)
identifies Will Clinger's 1987/88 Scheme ports. Its package description does
not replace individual program/data notice inspection.

[Larceny's maintained benchmark descriptions](https://www.larcenists.org/benchmarksAboutR6.html)
provide source links and distinguish synthetic features, applications and GC
tests. They describe mperm's retained-storage pattern and explicitly separate
several numerical and library variants. The older Northeastern URL returned
403 during this review; the project site supplied the descriptions.

The [Benchmarks Game index](https://benchmarksgame-team.pages.debian.net/benchmarksgame/index.html)
lists the current small workloads and warns about differing approaches and
libraries. Reusing a label does not establish an identical algorithm.

The [PBBS project page](https://www.cs.cmu.edu/~pbbs/) describes problem
specifications, distributions and testers, and points to the
[current repository](https://github.com/cmuparlay/pbbsbench). Its older web
page is deprecated. A sequential run of parallel code is not automatically a
portable sequential algorithm. No parallel prerequisite feature is added
through this suite roadmap.

Before importing any candidate, record overlap, expected diagnostic value,
the selected algorithm, faithful numeric/evaluation semantics and a
reproducible independent result check. Benchmarks relying on unavailable
parallelism, effect handlers, FFI or runtime facilities remain deferred
until those capabilities exist under their own roadmaps.

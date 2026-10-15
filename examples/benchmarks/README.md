# Rune benchmarks

Portable SML97 benchmark programs, being implemented from the
[roadmap](../../docs/plans/benchmarks.md). The runnable catalogue includes the five M1 pilots and the growing M2 classic
SML collection, with fixed profiles and result checks. The larger source
[inventory](inventory.tsv) schedules future imports; it is not a list of
passing programs. See the [source audit](audit.md) and [literature map](literature.md).
Three programs are Rune's own, the latency workloads of the collector's
evaluation set ([latency-ring](#latency-ring), [latency-map](#latency-map),
[latency-static-map](#latency-static-map)): their manifest rows name `rune`
as the upstream and the program's own file as its source, and they have no
inventory entry.

| Name | Source | Description |
|---|---|---|
| [tak](#tak) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/tak.sml) | Evaluate the strict Takeuchi recurrence and sum repeated results. |
| [kittmergesort](#kittmergesort) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kittmergesort.sml) | Sort deterministic integer lists with the region-friendly copying merge. |
| [primes-lazy](#primes-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/primes) | Demand only the required prefix of the finite iterative sieve using memoized tails. |
| [primes-strict](#primes-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/primes) | Evaluate each finite sieve list strictly to produce the same prime. |
| [bdd](#bdd) | [Sandmark](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/bdd/bdd.exe) | Construct and check a hidden-weighted-bit binary decision diagram. |
| [fib](#fib) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/fib.sml) | Evaluate naive binary-recursive Fibonacci. |
| [tailfib](#tailfib) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/tailfib.sml) | Evaluate tail-recursive Fibonacci with two accumulators. |
| [even-odd](#even-odd) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/even-odd.sml) | Call mutually recursive parity predicates. |
| [merge](#merge) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/merge.sml) | Merge interleaved sorted lists using non-tail recursion. |
| [tailmerge](#tailmerge) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/tailmerge.sml) | Merge sorted lists using a reversed tail-recursive accumulator. |
| [imp-for](#imp-for) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/imp-for.sml) | Traverse seven nested mutable-counter loops. |
| [vector-rev](#vector-rev) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/vector-rev.sml) | Reverse a vector twice and consume every element. |
| [vector32-concat](#vector32-concat) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/vector32-concat.sml) | Concatenate Int32 vectors and validate their contents. |
| [vector64-concat](#vector64-concat) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/vector64-concat.sml) | Concatenate Int64 vectors and validate their contents. |
| [string-concat](#string-concat) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/string-concat.sml) | Concatenate cyclic alphabet strings and consume every character. |
| [wc-input1](#wc-input1) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/wc-input1.sml) | Count newline characters by reading a generated file one character at a time. |
| [wc-scanStream](#wc-scanstream) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/wc-scanStream.sml) | Count newline characters through a stream scanner. |
| [checksum](#checksum) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/checksum.sml) | Fold packed 32-bit words into a modular network checksum. |
| [boyer](#boyer) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/boyer.sml) | Prove a substituted theorem with the classic symbolic rewriting checker. |
| [nucleic](#nucleic) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/nucleic.sml) | Search Pseudoknot nucleotide conformations and check the maximum atom distance. |
| [life](#life) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/life.sml) | Advance a list-based Game of Life glider gun and summarize its live cells. |
| [matrix-multiply](#matrix-multiply) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/matrix-multiply.sml) | Multiply dense matrices and validate every product entry against a closed form. |
| [md5](#md5) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/md5.sml) | Compress deterministic byte blocks using the MD5 rounds and padding. |
| [fft](#fft) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/fft.sml) | Transform analytical Fourier data and check the resulting ramp. |
| [binary-trees](#binary-trees) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/binary-trees) | Build, traverse and retain binary trees of varying depths. |
| [flat-array](#flat-array) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/flat-array.sml) | Fold a vector of pairs using explicit checked 32-bit arithmetic. |
| [peek](#peek) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/peek.sml) | Retrieve mixed-width values from generative-exception property lists. |
| [psdes-random](#psdes-random) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/psdes-random.sml) | Generate Word32 values with the four-round pseudo-DES generator. |
| [mandelbrot](#mandelbrot) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/mandelbrot.sml) | Evaluate the original escape-iteration loop with its unusual coordinate formula. |
| [pidigits](#pidigits) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/pidigits.sml) | Produce pi digits until a selected zero occurrence using an IntInf spigot. |
| [logic](#logic) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/logic.sml) | Find the first peg-solitaire solution by continuation-based unification. |
| [zebra](#zebra) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/zebra.sml) | Solve the zebra puzzle using constraint propagation and fluid state. |
| [count-graphs](#count-graphs) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/count-graphs.sml) | Enumerate graph isomorphism classes with pruning and higher-order folds. |
| [many_refs](#many_refs) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/many_refs.sml) | Retain three tables of real references and repeatedly update every element. |
| [tensor](#tensor) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/tensor.sml) | Apply real and paired-complex elementwise and contraction operators, checking every result. |
| [zern](#zern) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/zern.sml) | Accumulate phase screens and validate every complex E-field value. |
| [smith-normal-form](#smith-normal-form) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/smith-normal-form.sml) | Reduce an IntInf matrix to Smith normal form and consume its diagonal. |
| [ratio-regions](#ratio-regions) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/ratio-regions.sml) | Segment a fixed grid by preflow-push max flow and validate its min-cut mask. |
| [mpuz](#mpuz) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/mpuz.sml) | Enumerate distinct digit assignments to a fixed multiplication puzzle. |
| [DLXSimulator](#dlxsimulator) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/DLXSimulator.sml) | Interpret five embedded DLX programs and consume every simulated output. |
| [knuth-bendix](#knuth-bendix) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/knuth-bendix.sml) | Complete geometric group equations and validate the resulting rewrite rules. |
| [tyan](#tyan) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/tyan.sml) | Compute the cyclic polynomial Groebner basis over F17 and consume its term summaries. |
| [lexgen](#lexgen) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/lexgen.sml) | Generate a lexer from the original SML specification and compare every output byte. |
| [mlyacc](#mlyacc) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/mlyacc.sml) | Generate an LALR parser from the original SML grammar and compare its source and signature. |
| [hamlet](#hamlet) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/hamlet.sml) | Parse, elaborate and evaluate a unary arithmetic program with the HaMLet interpreter. |
| [kitfib35](#kitfib35) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitfib35.sml) | Evaluate the ML Kit Fibonacci recurrence with its single n<1 base case. |
| [fib0](#fib0) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/fib0.sml) | Evaluate the two-base-case development Fibonacci recurrence. |
| [kitreynolds2](#kitreynolds2) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitreynolds2.sml) | Search a shared tree with a chain of ancestor predicates. |
| [kitreynolds3](#kitreynolds3) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitreynolds3.sml) | Search the same shared tree using explicit ancestor lists. |
| [kitloop2](#kitloop2) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitloop2.sml) | Count down a lexicographic pair using a tail-recursive loop. |
| [kitdangle](#kitdangle) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitdangle.sml) | Build and consume one closure chain retaining list payloads. |
| [kitdangle3](#kitdangle3) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitdangle3.sml) | Build and release three closure chains sequentially. |
| [msort](#msort) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/msort.mlb) | Sort the original ascending sequence with alternating-split copying mergesort. |
| [kittmergesort_tp](#kittmergesort_tp) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kittmergesort_tp.sml) | Regenerate and sort ten lists in process using the shared copying kernel. |
| [barnes-hut](#barnes-hut) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/barnes-hut.sml) | Advance a seeded three-dimensional N-body model with octree force approximation. |
| [tsp](#tsp) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/tsp.sml) | Build and validate a divide-and-conquer travelling-salesman tour. |
| [fannkuch](#fannkuch) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/fannkuch) | Enumerate permutations, flip their prefixes and consume the alternating checksum. |
| [f-arith](#f-arith) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/f-arith) | Accumulate paired Leibniz-series terms and check the approximation of pi. |
| [stream-sieve](#stream-sieve) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/stream-sieve) | Demand a prime from the original nonmemoized infinite-stream sieve. |
| [twenty-four](#twenty-four) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/twenty-four) | Enumerate arithmetic-expression solutions using continuation callbacks. |
| [simple](#simple) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/simple.sml) | Compute a hydrodynamic time step and check all final state arrays. |
| [nbody](#nbody) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/nbody) | Advance five immutable solar-system records and validate their total energy. |
| [output1](#output1) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/output1.sml) | Write individual characters to a regular file and validate every output byte. |
| [ray](#ray) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/ray.sml) | Interpret the original sphere scene and validate its rendered dump image. |
| [raytrace](#raytrace) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/raytrace.sml) | Render the original chess scene and check every quantized RGB pixel. |
| [vliw](#vliw) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/vliw.sml) | Schedule and compress instructions, then validate both assembly streams. |
| [fxp](#fxp) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/fxp.sml) | Parse deterministic generated XML and validate its complete tag and attribute counts. |
| [model-elimination](#model-elimination) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/model-elimination.sml) | Search the original first-order problem sets with deterministic inference budgets. |
| [sat](#sat) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/sat) | Solve a fixed Boolean formula with nested higher-order choices. |
| [boyer-smlnj](#boyer-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/boyer) | Prove the original theorem using the modern modular SML/NJ rewriting checker. |
| [logic-smlnj](#logic-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/logic) | Find a peg-solitaire solution through the modern modular unifier and trail. |
| [life-smlnj](#life-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/life) | Repeat fifty-generation glider-gun evolutions with complete coordinate checks. |
| [minimax](#minimax) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/minimax) | Build and score complete tic-tac-toe trees with and without a transposition table. |
| [iter-pidigits](#iter-pidigits) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/iter-pidigits) | Generate a fixed number of pi digits with the iterative IntInf spigot. |
| [mazefun](#mazefun) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/mazefun) | Generate and validate complete deterministic mazes using persistent list matrices. |
| [queens-lazy](#queens-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/queens) | Count queen placements using memoized level-generation streams. |
| [queens-strict](#queens-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/queens) | Count queen placements using eagerly generated list levels. |
| [nqueens](#nqueens) | [Sandmark](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/multicore-numerical/nqueens.exe) | Count queen placements by depth-first search with mutable sibling totals. |
| [rec_seq_ack](#rec_seq_ack) | [Sandmark](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/multicore-effects/rec_seq_ack.exe) | Evaluate strict Ackermann calls and consume every repeated result. |
| [klife_eq](#klife_eq) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/klife_eq.sml) | Evolve a glider gun with explicit double generation and intermediate-list copying. |
| [kitlife35u_smlnj](#kitlife35u_smlnj) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitlife35u_smlnj.sml) | Evolve the same glider gun with typed equality, copying and upstream no-op region calls. |
| [kitqsort_no_basislib](#kitqsort_no_basislib) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/kitqsort_no_basislib.sml) | Sort seeded lists with copied partitions and transformed tail-recursive tuple arguments. |
| [tailfib-mlkit](#tailfib-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/tailfib.sml) | Repeat the original 38-step tail Fibonacci recurrence. |
| [tak-mlkit](#tak-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/tak.sml) | Repeat strict Takeuchi calls at the original ML Kit coordinates. |
| [matrix-multiply-mlkit](#matrix-multiply-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/matrix-multiply.sml) | Multiply freshly allocated all-ones Array2 matrices and validate every product. |
| [vector-rev-mlkit](#vector-rev-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/vector-rev.sml) | Regenerate pair vectors and reverse each twice. |
| [vector-rev_smlnj](#vector-rev_smlnj) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/vector-rev_smlnj.sml) | Retain one integer vector while repeatedly reversing it twice. |
| [vector-concat](#vector-concat) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/vector-concat.sml) | Regenerate pair vectors and concatenate two copies. |
| [vector-concat_smlnj](#vector-concat_smlnj) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/vector-concat_smlnj.sml) | Retain one integer vector while repeatedly concatenating two copies. |
| [peek-mlkit](#peek-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/peek.sml) | Retrieve an integer from a generative-exception property list. |
| [wc-input1-mlkit](#wc-input1-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/wc-input1.sml) | Count generated newlines by reading one character at a time. |
| [wc-scanStream-mlkit](#wc-scanstream-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/wc-scanStream.sml) | Count generated newlines with the original EOF-returning stream scanner. |
| [psdes-random-mlkit](#psdes-random-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/psdes-random.sml) | Generate alternating Word32 outputs with stateful four-round pseudo-DES. |
| [safe-for-space](#safe-for-space) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/safe-for-space) | Retain nested closures while testing whether large captured lists can become unreachable. |
| [pidigits-smlnj](#pidigits-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/pidigits) | Generate pi digits with the original nonmemoized linear-fractional stream spigot. |
| [fft-smlnj](#fft-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/fft) | Transform analytical Fourier data over the original doubling size sweep. |
| [nucleic-smlnj](#nucleic-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/nucleic) | Count anticodon conformations with the modern Pseudoknot geometry search. |
| [count-graphs-smlnj](#count-graphs-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/count-graphs) | Sweep cumulative sparse graph-isomorphism counts with higher-order folds. |
| [matrix-multiply-ramp](#matrix-multiply-ramp) | [MLton](https://github.com/MLton/mlton/blob/b15e2d289c3d701131733665a74e2dd8438410b6/benchmark/tests/matrix-multiply.sml) | Multiply ramp-valued matrices and check their analytical products. |
| [kitreynolds2_no_basislib](#kitreynolds2_no_basislib) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/kitreynolds2_no_basislib.sml) | Search a shared tree through captured ancestor predicates from the no-Basis variant. |
| [kitreynolds3_no_basislib](#kitreynolds3_no_basislib) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/kitreynolds3_no_basislib.sml) | Search shared subtrees with explicit ancestor lists from the no-Basis variant. |
| [kittmergesort_no_basislib](#kittmergesort_no_basislib) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/kittmergesort_no_basislib.sml) | Sort the original 25000-element integer-generator profile with the shared copying kernel. |
| [hanoi](#hanoi) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/hanoi.sml) | Generate, observe and validate every recursive Hanoi move. |
| [fib-mlkit](#fib-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/fib.sml) | Evaluate the one-based Fibonacci recurrence while retaining its complete call trace. |
| [mandelbrot-smlnj](#mandelbrot-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/mandelbrot) | Evaluate corrected binary64 Mandelbrot coordinates and consume every escape count. |
| [mandelbrot-rat](#mandelbrot-rat) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/mandelbrot-rat) | Evaluate the original truncated-rational Mandelbrot arithmetic with checked signed-63-bit emulation. |
| [kitmandelbrot](#kitmandelbrot) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitmandelbrot.sml) | Retain the legacy multiplicative coordinate and pixel counter while observing actual escape work. |
| [FuhMishra](#fuhmishra) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/FuhMishra.mlb) | Infer subtype constraints for six expressions and validate complete TYPE/MATCH reports. |
| [black-scholes](#black-scholes) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/black-scholes) | Compute and validate DerivaGem residuals for the original option datasets. |
| [professor2](#professor2) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/professor2.sml) | Search the original professor tile puzzle and validate every returned board. |
| [professor2_tp](#professor2_tp) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/professor2_tp.sml) | Search the original professor tile puzzle and validate every returned board. |
| [professor_game](#professor_game) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/professor_game.sml) | Search the original professor tile puzzle and validate every returned board. |
| [professor_game-mlkit](#professor_game-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/professor_game.sml) | Search the original professor tile puzzle and validate every returned board. |
| [professor_game_debug](#professor_game_debug) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/professor_game_debug.sml) | Search the original professor tile puzzle and validate every returned board. |
| [kkb_eq](#kkb_eq) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kkb_eq.sml) | Complete geometric rewrite rules with the retained copying and argument transformations. |
| [kitkbjul9_smlnj](#kitkbjul9_smlnj) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitkbjul9_smlnj.sml) | Complete geometric rewrite rules with the retained copying and argument transformations. |
| [kkb36c_smlnj](#kkb36c_smlnj) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kkb36c_smlnj.sml) | Complete geometric rewrite rules with the retained copying and argument transformations. |
| [ratio-regions-mlkit](#ratio-regions-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/ratio-regions.sml) | Segment the original central-square grid with preflow-push and validate the complete cut. |
| [ratio-regions_tp](#ratio-regions_tp) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/ratio-regions_tp.sml) | Segment the original central-square grid with preflow-push and validate the complete cut. |
| [ratio-regions-smlnj](#ratio-regions-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/ratio-regions) | Segment the original central-square grid with preflow-push and validate the complete cut. |
| [count-graphs-mlkit](#count-graphs-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/count-graphs.sml) | Sweep cumulative sparse graph classes with the original higher-order folds. |
| [mpuz-mlkit](#mpuz-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/mpuz.sml) | Enumerate fixed multiplication-puzzle assignments through the original tuple-based adapters. |
| [knuth-bendix-smlnj](#knuth-bendix-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/knuth-bendix) | Complete geometric rewrite equations with direct term ordering. |
| [tyan-smlnj](#tyan-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/tyan) | Compute cyclic-u6 Groebner bases over F17 and consume every term summary. |
| [tyan-mlkit](#tyan-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/tyan.sml) | Compute cyclic-u6 Groebner bases over F17 and consume every term summary. |
| [smith-normal-form-mlkit](#smith-normal-form-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/smith-normal-form.sml) | Reduce the original dimension-32 IntInf matrix to Smith normal form. |
| [smith-nf](#smith-nf) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/smith-nf) | Reduce the modern SML/NJ dimension-33 IntInf matrix to Smith normal form. |
| [lexgen-smlnj](#lexgen-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/lexgen) | Generate a lexer from the modern SML/NJ ML-Lex specification and validate every byte. |
| [mlyacc-smlnj](#mlyacc-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/mlyacc) | Generate an LALR parser from the modern SML/NJ ML-Yacc grammar and validate both files. |
| [kitsimple](#kitsimple) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitsimple.sml) | Compute a hydrodynamic time step using lists of references as arrays. |
| [kitsimple_tp](#kitsimple_tp) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitsimple_tp.sml) | Repeat three one-step hydrodynamic runs using the original list-reference array representation. |
| [kitsimple_no_basislib](#kitsimple_no_basislib) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test_dev/kitsimple_no_basislib.sml) | Compute a hydrodynamic time step with the miniature Basis and list-reference arrays. |
| [simple-smlnj](#simple-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/simple) | Compute a hydrodynamic time step with modern SML/NJ flat arrays and validate all state. |
| [tsp-smlnj](#tsp-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/tsp) | Build a MINSTD-seeded spatial tree and validate every vertex and link of its tour. |
| [DLXSimulator-mlkit](#dlxsimulator-mlkit) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/DLXSimulator.sml) | Interpret the older DLX Simple program with direct I/O traps and immutable arrays. |
| [aobench](#aobench) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/aobench) | Render ambient occlusion by seeded hemisphere sampling against spheres and a plane. |
| [id-ray](#id-ray) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/id-ray) | Trace the Id/Manticore sphere scene with the original overlapping image writes. |
| [plclub-ray](#plclub-ray) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/plclub-ray) | Interpret and render the ICFP chess scene using the modern modular SML/NJ port. |
| [mc-ray](#mc-ray) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/mc-ray) | Trace a seeded random sphere scene with sampled camera rays and material scattering. |
| [ray-smlnj](#ray-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/ray) | Interpret sphere scenes and validate every channel of the modern SML/NJ P6 image. |
| [kitmolgard](#kitmolgard) | [ML Kit](https://github.com/melsman/mlkit/blob/6dab5582db22a5f5672ca1fc5244171687d83ce5/test/kitmolgard.sml) | Run a deterministic coloured Petri-net counting simulation and validate complete reports. |
| [vliw-smlnj](#vliw-smlnj) | [SML/NJ](https://github.com/smlnj/benchmarks/tree/75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0/programs/vliw) | Schedule and compress abstract assembly using the modern modular SML/NJ implementation. |
| [rfib](#rfib) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/rfib) | Evaluate the Double nfib recurrence and validate it with an independent integer recurrence. |
| [tak-nofib-lazy](#tak-nofib-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/tak) | Demand Takeuchi arguments through explicit memoized delays. |
| [tak-nofib-strict](#tak-nofib-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/tak) | Evaluate all three Takeuchi arguments strictly while preserving the function result. |
| [exp3_8-lazy](#exp3_8-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/exp3_8) | Compute 3^n by lazy Peano addition and multiplication, then force the complete unary result. |
| [exp3_8-strict](#exp3_8-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/exp3_8) | Compute 3^n by strict Peano addition and multiplication, then force the complete unary result. |
| [digits-of-e1-lazy](#digits-of-e1-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/digits-of-e1) | Produce e digits with memoized continued-fraction transformations. |
| [digits-of-e2-lazy](#digits-of-e2-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/digits-of-e2) | Produce e digits with memoized factorial-base carry propagation. |
| [latency-ring](#latency-ring) | [Rune](latency-ring/PROVENANCE.md) | Keep a window of 1 KiB messages in a ring array, storing a young message into the old array at every step. |
| [latency-map](#latency-map) | [Rune](latency-map/PROVENANCE.md) | Keep the same window of messages in a persistent AVL tree, copying a path at every step. |
| [latency-static-map](#latency-static-map) | [Rune](latency-static-map/PROVENANCE.md) | Serve requests that allocate from a large map built once and never changed. |
| [kahan](#kahan) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/kahan) | Perform compensated summation over 100 seeded unsigned-word coordinates. |
| [x2n1-lazy](#x2n1-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/x2n1) | Sum memoized complex roots raised to their integer orders. |
| [x2n1-strict](#x2n1-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/x2n1) | Materialize complex root powers before summing both components. |
| [integrate-lazy](#integrate-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/integrate) | Integrate bilinear terms through shared memoized running-total streams. |
| [integrate-strict](#integrate-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/integrate) | Build finite numerical integration and running-total lists eagerly. |
| [bernouilli-lazy](#bernouilli-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/bernouilli) | Compute exact Bernoulli rationals with shared power and Pascal streams. |
| [bernouilli-strict](#bernouilli-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/bernouilli) | Compute exact Bernoulli rationals from eagerly generated finite rows. |
| [wheel-sieve1-lazy](#wheel-sieve1-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/wheel-sieve1) | Enumerate primes with circular memoized Mark I wheel streams. |
| [wheel-sieve2-lazy](#wheel-sieve2-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/wheel-sieve2) | Enumerate primes with the original Mark II spiral and shared lazy spans. |
| [gen_regexps-lazy](#gen_regexps-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/gen_regexps) | Expand numeric and alphabetic ranges through memoized character streams. |
| [gen_regexps-strict](#gen_regexps-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/gen_regexps) | Materialize range-expansion character lists before the 64-bit hash fold. |
| [paraffins-lazy](#paraffins-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/paraffins) | Count shared alkyl radicals and paraffin centres without forcing unused tree heads. |
| [paraffins-strict](#paraffins-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/imaginary/paraffins) | Construct finite radical and paraffin object lists before counting them. |
| [mutstore1](#mutstore1) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/mutstore1) | Retain immutable vectors of mutable list buckets across repeated insertions. |
| [mutstore2](#mutstore2) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/mutstore2) | Retain mutable arrays of list buckets across repeated insertions. |
| [gc_bench](#gc_bench) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/gc_bench) | Build mutable and immutable trees while retaining trees and a numerical array. |
| [pidigits-nofib-lazy](#pidigits-nofib-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/shootout/pidigits) | Generate and verify formatted pi digit blocks with memoized coefficients. |
| [pidigits-nofib-strict](#pidigits-nofib-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/shootout/pidigits) | Generate and verify pi digit blocks with strict arbitrary-precision state. |
| [hash](#hash) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/hash) | Grow a mutable bucket table with the original high-word hash and stable redistribution. |
| [lcss-lazy](#lcss-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/lcss) | Compute Hirschberg LCSS through delayed row values and a lazy result suffix. |
| [lcss-strict](#lcss-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/lcss) | Compute Hirschberg LCSS with eagerly evaluated dynamic-programming rows. |
| [gcd-lazy](#gcd-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/gcd) | Evaluate extended Euclid over a shared lazy grid with deferred coefficients. |
| [gcd-strict](#gcd-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/gcd) | Evaluate extended Euclid over eagerly materialized pair and result lists. |
| [treejoin-lazy](#treejoin-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/treejoin) | Join persistent relation trees with delayed keys, fields and branches. |
| [treejoin-strict](#treejoin-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/treejoin) | Join the same persistent relation trees with eager fields and insertion. |
| [spellcheck-lazy](#spellcheck-lazy) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/spellcheck) | Check Latin-1 words against the original weight-balanced set with streamed tokens. |
| [spellcheck-strict](#spellcheck-strict) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/spellcheck) | Check eagerly materialized Latin-1 tokens against the same weight-balanced set. |
| [cse](#cse) | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/cse) | Label expression trees with pure state computations and share equal subtrees. |
| [power](#power) | [nofib gc/power](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/power) | Compute exact rational identities and integer generating functions with memoized series. |
| [power-nofib](#power-nofib) | [nofib spectral/power](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/power) | Force rational power-series identities and generating functions repeatedly. |
| [n-body](#n-body) | [nofib shootout/n-body](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/shootout/n-body) | Advance five bodies in a contiguous mutable array and validate energies and final state. |
| [fasta](#fasta) | [nofib shootout/fasta](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/shootout/fasta) | Generate deterministic FASTA DNA with binary32 distribution tables and mutable line buffers. |
| [reverse-complement](#reverse-complement) | [nofib shootout/reverse-complement](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/shootout/reverse-complement) | Reverse-complement FASTA records using a growing mutable buffer and in-place swaps. |
| [rec_seq_evenodd](#rec_seq_evenodd) | [Sandmark rec_seq_evenodd](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/multicore-effects/rec_seq_evenodd.ml) | Alternate mutual tail calls and preserve short-circuit parity evaluation. |
| [rec_seq_motzkin](#rec_seq_motzkin) | [Sandmark rec_seq_motzkin](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/multicore-effects/rec_seq_motzkin.ml) | Compute Motzkin numbers with unmemoized recursive products and sums. |
| [rec_seq_sudan](#rec_seq_sudan) | [Sandmark rec_seq_sudan](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/multicore-effects/rec_seq_sudan.ml) | Evaluate the nested Sudan recurrence with explicit wide integer values. |
| [rec_seq_fib](#rec_seq_fib) | [Sandmark rec_seq_fib](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/multicore-effects/rec_seq_fib.ml) | Compute strict Fibonacci with Sandmark's retained repetition profiles. |
| [rec_seq_tak](#rec_seq_tak) | [Sandmark rec_seq_tak](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/multicore-effects/rec_seq_tak.ml) | Run the shared strict Takeuchi kernel with Sandmark's curried-source input profiles. |
| [lazy_primes](#lazy_primes) | [Sandmark lazy_primes](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/simple-tests/lazy_primes.ml) | Sieve primes through streams with strict heads and memoized lazy tails. |
| [lazylist](#lazylist) | [Sandmark lazylist](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/simple-tests/lazylist.ml) | Allocate a strict list of independent lazy heads sharing one zero cell. |
| [sequence_cps](#sequence_cps) | [Sandmark sequence_cps](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/sequence/sequence_cps.ml) | Compose CPS map/filter layers and consume them with a mutable callback fold. |
| [compress-lazy](#compress-lazy) | [nofib compress](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/compress) | Compress bytes with memoized persistent prefix-tree LZW. |
| [compress-strict](#compress-strict) | [nofib compress](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/compress) | Compress bytes with eager persistent prefix-tree LZW. |
| [lcss-nofib-lazy](#lcss-nofib-lazy) | [nofib spectral/lcss](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/lcss) | Repeat Hirschberg longest-common-subsequence with the spectral input profiles. |
| [treejoin-nofib-lazy](#treejoin-nofib-lazy) | [nofib spectral/treejoin](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/treejoin) | Repeat persistent relation-tree joins over the shuffled spectral datasets. |
| [lcss-nofib-strict](#lcss-nofib-strict) | [nofib spectral/lcss](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/lcss) | Repeat Hirschberg longest-common-subsequence with the spectral input profiles. |
| [treejoin-nofib-strict](#treejoin-nofib-strict) | [nofib spectral/treejoin](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/treejoin) | Repeat persistent relation-tree joins over the shuffled spectral datasets. |
| [rsa-lazy](#rsa-lazy) | [nofib real/rsa](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/rsa) | Encrypt fixed ASCII blocks with exact modular exponentiation and memoized encodings. |
| [rsa-strict](#rsa-strict) | [nofib real/rsa](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/rsa) | Encrypt fixed ASCII blocks with exact modular exponentiation and eager encodings. |
| [life-nofib-lazy](#life-nofib-lazy) | [nofib life](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/life) | Evolve a memoized list-grid to the first adjacent Life fixpoint. |
| [life-nofib-strict](#life-nofib-strict) | [nofib life](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/life) | Evolve an eager list-grid to the same adjacent Life fixpoint. |
| [maillist](#maillist) | [nofib maillist](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/maillist) | Parse address paragraphs and create exact LaTeX mailing-label pages. |
| [hamming](#hamming) | [sandmark hamming](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/hamming) | Generate shared lazy Hamming streams with the original signed 64-bit component arithmetic. |
| [scc-lazy](#scc-lazy) | [nofib scc](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/scc) | Find strongly connected components with memoized finish lists and two list-based DFS passes. |
| [scc-strict](#scc-strict) | [nofib scc](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/scc) | Run the same two DFS passes with eagerly materialized finish and component lists. |
| [awards-lazy](#awards-lazy) | [nofib awards](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/awards) | Select awards using shared candidate sums and demand-sensitive stable quicksort. |
| [awards-strict](#awards-strict) | [nofib awards](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/awards) | Select the same awards while eagerly sorting the finite candidate lists. |
| [stack_fold](#stack_fold) | [Sandmark Stack](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/stdlib) | Repeatedly fold addition over a mutable stack of integers 1 through 100. |
| [stack_push_pop](#stack_push_pop) | [Sandmark Stack](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/stdlib) | Repeatedly push and pop units while retaining a one-element mutable stack. |
| [S](#s) | [nofib eff/S](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/eff/S) | Sequence strict State tuples while keeping the counter field unforced. |
| [CS](#cs) | [nofib eff/CS](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/eff/CS) | Thread state through Church-encoded pure/get/put callbacks. |
| [CSD](#csd) | [nofib eff/CSD](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/eff/CSD) | Thread state with a specialized three-operation Church dictionary. |
| [FS](#fs) | [nofib eff/FS](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/eff/FS) | Interpret free-state constructors with suspended bind continuations. |
| [VS](#vs) | [nofib eff/VS](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/eff/VS) | Thread state through van Laarhoven callbacks and a strict tuple interpreter. |
| [VSD](#vsd) | [nofib eff/VSD](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/eff/VSD) | Use a get/put class dictionary over the shared State monad. |
| [VSM](#vsm) | [nofib eff/VSM](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/eff/VSM) | Retain a van Laarhoven get/put abstraction and shared monadic bind layers. |
| [constraints-lazy](#constraints-lazy) | [nofib GC/spectral constraints](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/constraints) | Solve five CSP methods with memoized labels, tables and search-tree children. |
| [constraints-strict](#constraints-strict) | [nofib GC/spectral constraints](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/constraints) | Solve the same five CSP methods with eagerly materialized finite trees and tables. |
| [fibheaps-lazy](#fibheaps-lazy) | [nofib fibheaps](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/fibheaps) | Compare both Fibonacci-heap consolidations with memoized fields and interleaved outputs. |
| [fibheaps-strict](#fibheaps-strict) | [nofib fibheaps](https://github.com/ghc/nofib/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/gc/fibheaps) | Compare the same two consolidations with eagerly evaluated finite heaps and outputs. |

## Running and interpreting checks

`make check` includes metadata validation and the ten-program
[bounded routine smoke set](routine.tsv) through `make bench-smoke`.
`make bench-check-all` covers smoke and normal for every imported program.
See [recorded validation](validation.md) for passing configurations and gaps.

From the repository root:

```sh
make bench-check
make bench-check BENCH_PROFILE=normal
make bench-check BENCH_PROFILE=large
```

Configuration names are the existing Basis matrix names. For example:

```sh
make bench-check BENCH_CONFIGS=rune,rune:new,rune:jit,rune:opt
make bench-check BENCH_CONFIGS=native:mlton,native:smlnj-legacy,native:polyml
make bench-check BENCH_FILTER=primes
```

The default `rune,hosts` selects Rune and the six hosts installed by
`make hosts`. Standalone `xc1` exports remain unavailable; see the measurement
document for the adapter limitation. Missing requested
configurations fail visibly; they do not count as passing comparisons.
These commands check correctness. `make bench`, `make bench-count` and
`make bench-stats` provide separate serial timing, count and runtime-statistics
runs. See [measurement commands and limitations](measurement.md).

The [manifest](manifest.tsv) records ordered sources, source identity,
profile arguments, expected-result files, limits, diagnostic tags, input files, result-check mode and implementation
status. XML and other generated inputs have a fixed SML recipe and profile
arguments instead of an upstream file identity. Implementation status records a port; recorded runs in validation.md
provide the evidence for correctness on specific hosts and profiles.
The shared SML catalogue validates it before the thin shell runner executes
jobs through the existing matrix. Source inventory metadata is separate
from this runnable catalogue.

Smoke and normal profiles are required for imported programs. Large profiles
are explicitly selected; an application need not invent a large profile.
The manifest records overrides to the standard limits.

Every program reads its benchmark name, space-separated arguments and
expected result as three input lines. The runner supplies a fixed regular
input file and records output in an isolated `tests/out/benchmarks/PROFILE/run.XXXXXX/NAME`
directory, printed at launch. Concurrent correctness invocations have separate
job lists, source lists, input files and result directories; they cannot
overwrite each other. The stable program names and relative data filenames
are the same within each configuration's fresh working directory.
The SML driver compares the complete one-line result and reports PASS/FAIL.
It also rejects mismatched names and exceptions. Interactive hosts see the
same input as compiled programs, without leaking launcher arguments.

Limits apply to compilation and execution phases. On Linux, the ordinary
configurations use a virtual-address-space quota. Compact Poly/ML reserves
18 GiB of uncommitted address space; it instead uses a data-memory quota,
a managed heap capped at half that quota, and a 64 MiB stack-space reservation.
Actual limit settings appear in each result log. These accounting methods
are recorded explicitly and are not RSS measurements or equal-heap claims.

For validating other Rune changes, the bounded routine set is `make bench-smoke`.
Use the complete imported smoke and normal coverage explicitly:

```sh
make bench-check-all BENCH_CONFIGS=rune,rune:new,rune:jit,rune:opt RUNE_BENCH_COMPILE_OPTIONS=-O0
make bench-check-all BENCH_CONFIGS=rune,rune:new,rune:jit,rune:opt RUNE_BENCH_COMPILE_OPTIONS=-O2
```

`BENCH_FILTER` selects benchmark names by substring. Prefix `=` for an exact
name, for example `BENCH_FILTER='=S'`. For example,
`make bench-check BENCH_PROFILE=normal BENCH_CONFIGS=rune,rune:new,rune:jit,rune:opt BENCH_FILTER=aobench`
checks the captured-record workload on all four engines. The default reference
host set has recorded failures; see [reference-host caveats](validation/reference-hosts.md)
before using host agreement as an acceptance condition. The roadmap remains
in progress while these imported programs and tools are available for use.

The independent and negative tests are:

```sh
sh tests/benchmarks/check-pilots.sh
sh tests/benchmarks/check-classic.sh
sh tests/benchmarks/check-streams.sh
sh tests/benchmarks/check-numeric-ports.sh
sh tests/benchmarks/check-symbolic-ports.sh
sh tests/benchmarks/check-gc-ports.sh
sh tests/benchmarks/check-extended-gcd.sh
sh tests/benchmarks/check-treejoin.sh
sh tests/benchmarks/check-word-set.sh
sh tests/benchmarks/check-power-series.sh
sh tests/benchmarks/check-shootout.sh
sh tests/benchmarks/check-ocaml-lazy.sh
sh tests/benchmarks/check-sequence-cps.sh
sh tests/benchmarks/check-compress.sh
sh tests/benchmarks/check-rsa.sh
sh tests/benchmarks/check-nofib-life.sh
python3 tests/benchmarks/test-inventory.py
python3 scripts/benchmark-inventory.py --check
python3 tests/benchmarks/latency-oracle.py --check
```

The source audit can additionally be reproduced with all five pinned trees:

```sh
python3 scripts/benchmark-inventory.py --check \
  --source mlton=/path/to/mlton \
  --source smlnj=/path/to/smlnj-benchmarks \
  --source mlkit=/path/to/mlkit \
  --source nofib=/path/to/nofib \
  --source sandmark=/path/to/sandmark
```

The Python tool reads source metadata; it never executes upstream scripts.
Benchmark kernels, input generation, result checks and catalogue logic are
SML. Review changes before regenerating the source inventory with `--write`.

## tak

The MLton version of the strict Takeuchi function returns `z` when `y >= x`
and otherwise recursively evaluates three smaller calls. Preserve this
particular recurrence: similarly named tarai variants may return a different
value or use a different evaluation strategy.

[Provenance](tak/PROVENANCE.md) pins MLton's source; its individual author is
not stated. [Gabriel's benchmark book](https://dreamsongs.com/Files/Timrep.pdf)
provides the classic recursive-benchmark context.

The port moves the unchanged recurrence into a structure, accepts sizes
and repetitions at runtime, and accumulates every result in an IntInf
checksum. The original hardcoded `(33,22,11)` is the large profile;
smoke uses `(18,12,6)` once and normal `(24,16,8)` ten times. Checksums are
`7`, `90`, and `22`, independently calculated by a memoized recurrence.
The kernel itself remains unmemoized. Calls, branching, primitive arithmetic
and recursion are diagnostic hypotheses; allocation is principally driver
and checksum overhead, so this is not a collector workload.

## kittmergesort

[The ML Kit source](kittmergesort/PROVENANCE.md) attributes top-down mergesort
to Paulson's book. Its merge copies the remainder even when one argument
is empty, permitting local regions. That copying policy, custom recursive
length, take/drop operations and generator are preserved. Consult
[Paulson's Lists chapter](https://doi.org/10.1017/CBO9780511811326.005) and
[the ML Kit region/GC study](https://elsman.com/mlkit/pdf/jfp2021.pdf).

Inputs use seed 1 and `next = 167 * seed mod 2147`, with 100, 50,000 and
100,000 elements. The large size is the original input. The port removes
progress printing, parameterizes the size and consumes the whole sorted
list, checking order and returning length, IntInf sum and a Word32 rolling
hash. Expected summaries were independently calculated with Python's sort
and reviewed; exact values are in the three `.expected` files.

The list operations and copying policy make allocation, lifetimes,
recursion and representation selection plausible sensitivities. GPL and
project notices are included beside the source. The checksum is additional
validation, not a replacement for the sorting workload.

## primes-lazy

[nofib provenance](primes-lazy/PROVENANCE.md) identifies the finite sieve
`map head (iterate the_filter [2..n*n]) !! n`. The index is zero-based, so
size 10 yields the eleventh prime, 31. The SML implementation creates finite
streams with memoized tails and filters out multiples after each selected
head; values outside the demanded prefix remain delayed.

This is a newly written SML implementation, with the source algorithm as
its reference. It is not a general laziness library. Memoization is tested
by forcing one delayed computation twice and observing one evaluation.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies
suite context; the pinned source supplies the exact algorithm and bounds.

Profiles use `(size,repetitions)` of `(10,1)`, `(100,100)` and `(400,100)`.
The large size is nofib's fast input; normal is deliberately smaller than
its own normal input, and smoke reduces repetition. Results are summed
instead of printing 100 equal lines. Expected sums `31`, `54700`, and
`274900` agree with the original compiled by GHC and an independent
trial-division prime generator. Each repetition constructs a fresh sieve.
Investigate closures, demand, sharing, allocation and collector behavior;
these are hypotheses, not measured performance conclusions.

## primes-strict

[Provenance](primes-strict/PROVENANCE.md), input bounds, result convention
and expected sums are shared with [primes-lazy](#primes-lazy). The strict
version builds `[2..n*n]` as a list and eagerly filters each remainder.
It therefore computes list elements the lazy variant does not demand.
This is an explicit evaluation-style variant, not an identical Haskell
workload. Independent tests compare both implementations to trial division
for sizes 3 through 80. Sizes below 3 are rejected because the finite interval
need not contain the requested zero-based prime.

Compare list traversal, allocation and the effectiveness of list-operation
optimization against the lazy version, keeping their times and counts
separate. Neither version uses a cached prime result across invocations.

## bdd

[Provenance](bdd/PROVENANCE.md) credits Xavier Leroy's Caml translation;
the original SML author is unspecified. The upstream copyright and QPL 1.0
notice are retained. Unmodified upstream files and a separate translation
patch accompany the SML port. [Bryant's BDD paper](https://www.cs.cmu.edu/~bryant/pubdir/ieeetc86.pdf)
explains the algorithm family; it does not identify the benchmark's original
SML author.

The benchmark builds a hidden-weighted-bit function with unique-node
hashing, table growth, negation and operation caches. The port preserves the
upstream shared AND/XOR cache, insertion policy and right-before-left
allocation schedule explicitly. It retains separate operation functions.
State is reset between invocations. Hash indexing and the random low bit
use Word32 to avoid host-width overflow; tested indices fit every host int.
The source's optional GC-statistics output is removed.

Profiles use 8, 18 and 22 variables, each checked on 100 generated assignments.
The large variable count is the upstream default. Results include variables,
last node ID and test count: `8 382 100`, `18 14289 100`, and `22 47088 100`.
These agree with the original OCaml program, instrumented only to expose
its final node ID.

The upstream random low bit alternates and covers few distinct assignments.
Separate tests therefore check every truth assignment for sizes 1 through
10 against the mathematical hidden-weighted-bit definition. This validates
the benchmark's construction, not a general-purpose BDD API. Investigate
allocation, hash/caching behavior, arrays, recursion and locality before
attributing a performance change to a particular compiler pass.

## fib

Evaluate naive binary-recursive Fibonacci. See [provenance](fib/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/fib.sml`.

Naive binary-recursive Fibonacci. Upstream checks fib 41 = 165580141.
Smoke/normal are smaller; large retains 41. An iterative recurrence supplies
the independent expected values. Calls, branching and recursion are the
diagnostic targets; there is no memoization in the benchmark.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `6765` |
| normal | `30 1` | `832040` |
| large | `41 1` | `165580141` |

Source inspection suggests sensitivity to calls-recursion. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## tailfib

Evaluate tail-recursive Fibonacci with two accumulators. See [provenance](tailfib/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/tailfib.sml`.

Tail-recursive Fibonacci. The original 44-step recurrence and accumulator
order are unchanged. Large preserves the original million repetitions. The
IntInf result sum is additional validation and avoids narrow-host overflow.
Tail calls and accumulator arithmetic are the diagnostic targets.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `6765` |
| normal | `44 1000` | `701408733000` |
| large | `44 1000000` | `701408733000000` |

Source inspection suggests sensitivity to calls-recursion. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## even-odd

Call mutually recursive parity predicates. See [provenance](even-odd/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/even-odd.sml`.

Mutually tail-recursive parity predicates. Large retains the upstream input
of 500000000; smaller profiles permit quick correctness checks. Both
predicates are checked against arithmetic parity as well as each other.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `1` |
| normal | `1000000 1` | `1` |
| large | `500000000 1` | `1` |

Source inspection suggests sensitivity to calls-recursion. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## merge

Merge interleaved sorted lists using non-tail recursion. See [provenance](merge/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/merge.sml`.

Stephen Weeks is credited upstream. The non-tail-recursive merge is retained.
Large preserves the original 100000-element input lists. The checker now
consumes every output element and verifies the complete sequence 0..2n-1,
instead of merely testing its head. Sum = n(2n-1) per repetition.
Allocation, list traversal, recursion and tail calls are relevant.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `19900` |
| normal | `10000 10` | `1999900000` |
| large | `100000 25` | `499997500000` |

Source inspection suggests sensitivity to lists-streams, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## tailmerge

Merge sorted lists using a reversed tail-recursive accumulator. See [provenance](tailmerge/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/tailmerge.sml`.

Stephen Weeks is credited upstream. The tail-recursive reversed-accumulator merge is retained.
Large preserves the original 100000-element input lists. The checker now
consumes every output element and verifies the complete sequence 0..2n-1,
instead of merely testing its head. Sum = n(2n-1) per repetition.
Allocation, list traversal, recursion and tail calls are relevant.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `19900` |
| normal | `10000 10` | `1999900000` |
| large | `100000 25` | `499997500000` |

Source inspection suggests sensitivity to lists-streams, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## imp-for

Traverse seven nested mutable-counter loops. See [provenance](imp-for/PROVENANCE.md), the retained notices, and the source adaptation.

Collection: MLton, revision `b15e2d289c3d701131733665a74e2dd8438410b6`.
Source: `benchmark/tests/imp-for.sml`.

Seven nested imperative loops over references, preserving the upstream
loop implementation and nesting. Large retains width 10. Expected counts
are width^7 times repetitions, independently calculated. Mutable refs,
closures, loop lowering and allocation are diagnostic targets.

The source algorithm is retained and sizes are runtime arguments. Expected
results are derived independently; profiles and checks are in the manifest.
The project copyright/permission notice is retained in LICENSE.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `2 1` | `128` |
| normal | `5 1` | `78125` |
| large | `10 1` | `10000000` |

Source inspection suggests sensitivity to closures, mutation. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## vector-rev

Reverse a vector twice and consume every element. See [provenance](vector-rev/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector-rev.sml`.

Stephen Weeks. Retains tabulate-based vector reversal. Every element of
the double reversal is checked, strengthening the original head-only test.
Large preserves 200000 elements and the original inclusive 1001 iterations.
The independent sum is n(n-1)/2 per repetition.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `4950` |
| normal | `10000 10` | `499950000` |
| large | `200000 1001` | `20019899900000` |

Source inspection suggests sensitivity to arrays, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## vector32-concat

Concatenate Int32 vectors and validate their contents. See [provenance](vector32-concat/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector32-concat.sml`.

Stephen Weeks. Retains Int32 element arithmetic and vector concatenation.
Large preserves 20000 elements and the original inclusive 10001 iterations.
Per-run expected sum n(n-1) stays representable in a 31-bit host int;
the cross-iteration validation sum uses IntInf.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `9900` |
| normal | `5000 10` | `249950000` |
| large | `20000 10001` | `4000199980000` |

Source inspection suggests sensitivity to arrays, integer-arithmetic, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## vector64-concat

Concatenate Int64 vectors and validate their contents. See [provenance](vector64-concat/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/vector64-concat.sml`.

Stephen Weeks. Retains Int64 element arithmetic and vector concatenation.
Large preserves 20000 elements and the original inclusive 10001 iterations.
Per-run expected sum n(n-1) stays representable in a 31-bit host int;
the cross-iteration validation sum uses IntInf.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `9900` |
| normal | `5000 10` | `249950000` |
| large | `20000 10001` | `4000199980000` |

Source inspection suggests sensitivity to arrays, integer-arithmetic, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## string-concat

Concatenate cyclic alphabet strings and consume every character. See [provenance](string-concat/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/string-concat.sml`.

Retains the cyclic A-Z input, triple String.concat and complete character
fold. Large preserves length 2017 and 10001 inclusive iterations. Expected
sums come from the independently generated character sequence; the original
per-iteration 468705 is retained as the large result component.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `26 1` | `6045` |
| normal | `1000 100` | `23224800` |
| large | `2017 10001` | `4687518705` |

Source inspection suggests sensitivity to strings, allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## wc-input1

Count newline characters by reading a generated file one character at a time. See [provenance](wc-input1/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/wc-input1.sml`.

Stephen Weeks. Retains file generation, TextIO.input1 reading and
newline counting. Source newlines occur at positions divisible by ten,
including zero: ceil(n/10) is the independent oracle. Files are closed and
removed on success and failure. The scanner variant returns its observed
count rather than discarding the result after its internal assertion.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 10` | `100000` |
| large | `1000000 3` | `300000` |

Source inspection suggests sensitivity to io, strings. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## wc-scanStream

Count newline characters through a stream scanner. See [provenance](wc-scanStream/PROVENANCE.md), the retained notices, and the source adaptation.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/wc-scanStream.sml`.

Stephen Weeks. Retains file generation, TextIO.scanStream reading and
newline counting. Source newlines occur at positions divisible by ten,
including zero: ceil(n/10) is the independent oracle. Files are closed and
removed on success and failure. The scanner variant returns its observed
count rather than discarding the result after its internal assertion.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 10` | `100000` |
| large | `1000000 3` | `300000` |

Source inspection suggests sensitivity to io, strings. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## checksum

ML Kit's checksum/checksum_smlnj forms share this exact kernel and all-zero
workload; their additional provenance is retained in this directory.

MLton revision `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/checksum.sml`.

Stephen Weeks; based on Derby, The Performance of FoxNet 2.0 (1999).
Preserves packed little-endian word access and the original zero-filled
buffer. Large preserves 10000000 bytes. All zero words contribute zero,
which supplies the reviewed mathematical result. A nonzero-buffer correctness
test is required separately, since a zero-input benchmark alone is weak.

Runtime input sizes are fixed by the three manifest profiles. Each result
is checked against an independent mathematical or data-generation oracle.
The checksum consumes the complete result. LICENSE preserves the source notice.

ML Kit test/checksum.sml and checksum_smlnj.sml at
6dab5582db22a5f5672ca1fc5244171687d83ce5 share the same packed-fold kernel,
all-zero ten-million-byte input and fifty scans. Only the legacy Pack32Little
name/conversion, email spelling and invocation adapter differ. Both pristine
forms are retained here. The input distribution is all-zero in both
collections; it is not patterned byte data.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1024 1` | `0` |
| normal | `1000000 10` | `0` |
| large | `10000000 1` | `0` |

Source inspection suggests sensitivity to arrays, integer-arithmetic. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## boyer

Prove a substituted theorem with the classic symbolic rewriting checker. See [provenance](boyer/PROVENANCE.md), the retained notices, and the source adaptation.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/boyer.sml`. Project notice: LICENSE.

Classic SML/NJ tautology checker. Terms, rewrite rules, property lists,
substitution and theorem are retained. Unlike the original unit driver, every
returned theorem result must be true. The same theorem appears in upstream
Main.testit as Proved. This observes the actual computation without adding
a second theorem invocation. The repetition count is runtime input.

The unmodified source and separate adaptation patch accompany the port.

ML Kit test/boyer.sml at 6dab5582db22a5f5672ca1fc5244171687d83ce5
shares the complete same kernel, theorem, substitution and rules. Its
original wrapper repeats fifty times and prints a progress dot; the canonical
parameterized driver accepts that count and records suppression of progress
output. The additional pristine source is retained here.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `10` | `10` |
| large | `24` | `24` |

Source inspection suggests sensitivity to application. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## nucleic

Search Pseudoknot nucleotide conformations and check the maximum atom distance. See [provenance](nucleic/PROVENANCE.md), the retained notices, and the source adaptation.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/nucleic.sml`. Project notice: LICENSE.

Pseudoknot (nucleic) molecular search. The biological data, coordinate
transforms, geometry and search are unchanged. The numeric result is
checked against the upstream 33.797594890762724 reference with the same
relative 1e-6 tolerance. The returned sum counts verified computations,
not mere successful termination. Hartel et al., JFP 1996, is the literature
reference. Upstream explicitly notes earlier assembler versions of the
coordinate transform; this port retains its SML implementation.

The unmodified source and separate adaptation patch accompany the port.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `4` | `4` |
| large | `12` | `12` |

Source inspection suggests sensitivity to application. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## life

Advance a list-based Game of Life glider gun and summarize its live cells. See [provenance](life/PROVENANCE.md), the retained notices, and the source adaptation.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/life.sml`. Project notice: LICENSE.

Classic SML/NJ list-based Life and its gun seed. Coordinate lists, neighbor
collection, lexicographic normalization and the next-generation algorithm
are unchanged. Profile generations are reduced from the original 25000
for practical portable runs; that value remains accepted by the driver.
All living coordinates are consumed into a count and Word32 checksum,
including cells that the original drawing helper would hide outside its
nonnegative plotting window. An independent set/neighbor-counter simulator
supplies the reviewed expected generations.

The unmodified source and separate adaptation patch accompany the port.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10` | `61 3AA2F3FF` |
| normal | `100` | `74 F4838721` |
| large | `1000` | `28 60A560FF` |

Source inspection suggests sensitivity to application. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## matrix-multiply

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/matrix-multiply.sml`, Stephen Weeks. Original notice and
source identity are retained; the kernel is shared in `shared/matrix-multiply.sml`.

Preserve Array2 multiplication, dot-product traversal and the original
all-ones input. Large keeps dimension 500; smoke and normal scale to 4/50.
Every output entry must equal n exactly, and the full matrix sum n^3 is
independently derived in IntInf for narrow hosts. Integral doubles are exact
for these selected operations, so no floating tolerance is needed.

The first adaptation changed the input to a ramp, which affects numerical
values and boxed-input allocation. That adaptation is retained separately
as matrix-multiply-ramp with explicit provenance. The ML Kit version selects
200 and regenerates input on two calls; it shares the reviewed kernel but
retains its own profiles. Array specialization/unboxing, traversal and
allocation are hypotheses from source analysis, not measured explanations.

Additional source review is recorded in [provenance](matrix-multiply/PROVENANCE.md).

## md5

Compress deterministic byte blocks using the MD5 rounds and padding. See [provenance](md5/PROVENANCE.md), the retained notices, and the source adaptation.

MLton b15e2d289c3d701131733665a74e2dd8438410b6, `benchmark/tests/md5.sml`.
Source notice in LICENSE; original and adaptation patch are retained.

Retains the original MD5 state, compression rounds, padding and hex encoding.
Input bytes are i mod 256. Large preserves the original 10000-byte block
repeated 100000 times. Python hashlib supplies an independent digest; the
large digest additionally matches the upstream literal reference.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `64 1` | `b2d3f56bc197fd985d5965079b5e7148` |
| normal | `1000 100` | `333cc4cfc0deca30c684f147b4a800a1` |
| large | `10000 100000` | `766a2bb5d24bddae466c572bcabca3ee` |

Source inspection suggests sensitivity to integer-arithmetic, arrays. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## fft

Transform analytical Fourier data and check the resulting ramp. See [provenance](fft/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/fft.sml`.

Retains the in-place FFT, bit reversal, complex arrays and analytical
input whose transform should be the real ramp 0..n-1 with zero imaginary
component. The original error computation is now returned instead of
discarded. Every run checks maximum residual <= n*1e-8; the nonnegative
check also rejects NaN. Large is the largest original transform. Numeric
validation is separate from exact result formatting.
Original source, notice and separate adaptation patch are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `256 1` | `1` |
| normal | `4096 10` | `10` |
| large | `8388608 1` | `1` |

Source inspection suggests sensitivity to allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## binary-trees

Build, traverse and retain binary trees of varying depths. See [provenance](binary-trees/PROVENANCE.md), the retained notices, and the source adaptation.

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/binary-trees`.

Copyright 2026 Fellowship of SML/NJ. Tree datatype, top-down construction,
checksums, stretch/retained trees and depth-dependent repetition are retained.
Logging is replaced by one consumed summary; nIters and full-tree node counts
supply the independent formula. Large preserves upstream depth 21.
Allocation, liveness and traversal are the diagnostic targets.
Original source, notice and separate adaptation patch are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `6` | `255 4016 127` |
| normal | `12` | `16383 649904 8191` |
| large | `21` | `8388607 601183584 4194303` |

Source inspection suggests sensitivity to allocation-lifetimes. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## flat-array

Fold a vector of pairs using explicit checked 32-bit arithmetic. See [provenance](flat-array/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/flat-array.sml`. Original, patch and notice retained.

Vector of pairs and repeated fold, retaining the original overflow-reset policy.
Int32 makes the upstream 32-bit arithmetic assumption explicit on all hosts.
The original million entries are normal and large; the actual fold sums are
consumed in IntInf. Independent bounded Python arithmetic supplies fixtures.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `1000000` |
| normal | `1000000 10` | `11056941910` |
| large | `1000000 100` | `110569419100` |

Source inspection suggests sensitivity to vectors, integer-width. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## peek

Retrieve mixed-width values from generative-exception property lists. See [provenance](peek/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/peek.sml`. Original, patch and notice retained.

Stephen Weeks. Generative exceptions implement heterogeneous property lists
with Int32 and Int64 values. Parameterizes only the inner loop and repetitions.
Both observed accumulators are checked by the original arithmetic invariants
and returned. Large preserves ten million inner iterations. Poly/ML lacks
Int64; this configuration is unavailable, not a different-width emulation.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `64000 58000` |
| normal | `1000000 10` | `640000000 580000000` |
| large | `10000000 10` | `6400000000 5800000000` |

Source inspection suggests sensitivity to exceptions. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## psdes-random

Generate Word32 values with the four-round pseudo-DES generator. See [provenance](psdes-random/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/psdes-random.sml`. Original, patch and notice retained.

Stephen Weeks, Numerical Recipes pseudo-DES generator. Four Word32 rounds
and alternating generated words are retained. Removed top-level executions;
the actual modular sum is returned. Python bit arithmetic supplies smaller
fixtures; the original literal supplies the 150 million-word fixture.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000` | `CA36C720` |
| normal | `1000000` | `43E080E` |
| large | `150000000` | `132B1B67` |

Source inspection suggests sensitivity to modular-arithmetic. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## mandelbrot

Evaluate the original escape-iteration loop with its unusual coordinate formula. See [provenance](mandelbrot/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mandelbrot.sml`. Original, patch and notice retained.

SML/NJ-derived numerical loop. Preserves the unusual upstream coordinate
formula x_base * (delta + j), initial z=c and escape threshold, rather than
substituting a conventional Mandelbrot image. Side and iteration limit are
parameters. Python reproduces the exact iteration convention. For j >= 2 the initial squared real coordinate exceeds four, so the
independent large calculation skips those mathematically zero contributions.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `32 128` | `2788` |
| normal | `1024 2048` | `1073042` |
| large | `32768 2048` | `34365041` |

Source inspection suggests sensitivity to numerical. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## pidigits

Produce pi digits until a selected zero occurrence using an IntInf spigot. See [provenance](pidigits/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/pidigits.sml`. Original, patch and notice retained.

Jeremy Gibbons linear fractional transformation spigot, in the MLton source.
Keeps IntInf arithmetic and the original function-stream implementation.
The benchmark stops on a zero occurrence, not at a fixed digit count; its
zero index and returned digit position are zero based. Chudnovsky expansion
provides an independent oracle. Stream functions are nonmemoized as in this
SML source; no Haskell demand equivalence is claimed.

The initial normal zero index 100 timed out on Rune under the 600-second
limit. The subsequent zero index 30 also timed out at -O0 in the stack interpreter.
Normal is now fixed at zero index 10 (digit position 121),
with an independently computed Chudnovsky fixture. This input revision
changes the workload identity; the unsuccessful larger run is recorded.

See [Gibbons, Unbounded Spigot Algorithms for the Digits of Pi](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf)
for the linear-fractional streaming formulation. The zero-occurrence driver
is specific to this upstream SML workload, rather than the paper's usual
fixed digit-count presentation.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `3` | `65` |
| normal | `10` | `121` |
| large | `1000` | `10376` |

Source inspection suggests sensitivity to big-integers, streams. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## logic

Find the first peg-solitaire solution by continuation-based unification. See [provenance](logic/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/logic.sml`. Original, patch and notice retained.

SML/NJ continuation-based unification and backtracking for peg solitaire.
Retains the original board and first-solution stopping condition. Returning
normally without reaching the success continuation fails validation, unlike
the original driver. Upstream testit independently reports yes for this board.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `10` | `10` |
| large | `100` | `100` |

Source inspection suggests sensitivity to symbolic, exceptions, search. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## zebra

Solve the zebra puzzle using constraint propagation and fluid state. See [provenance](zebra/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/zebra.sml`. Original, patch and notice retained.

Stephen Weeks, 1999 zebra puzzle constraint solver. Retains generative
exceptions, fluid state and consistency propagation. The observed count of
3342 attempted assignments is asserted by upstream and returned per search.
Large preserves one original driver batch (its inclusive loop ran 1001).
This fixture checks control flow; additional solution constraints are required
before using it to claim a general constraint solver correctness result.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `3342` |
| normal | `100` | `334200` |
| large | `1001` | `3345342` |

Source inspection suggests sensitivity to search, exceptions. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## count-graphs

Enumerate graph isomorphism classes with pruning and higher-order folds. See [provenance](count-graphs/PROVENANCE.md), the retained notices, and the source adaptation.

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/count-graphs.sml`. Original, patch and notice retained.

Henry Cejtin graph isomorphism-class enumeration using permutation, subset
and graph folds. Retains pruning and graph criterion, replaces progress
printing with the actual class count. Reference counts 2, 20 and 250 come from the pinned unmodified source
compiled by MLton; the added driver only exposes f(n). Smoke counts two cumulative qualifying classes up to four vertices:
the two-vertex edge and four-cycle. A triangle violates the induced-subgraph
sparsity condition. The count is cumulative, not restricted to four vertices.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4` | `2` |
| normal | `8` | `20` |
| large | `11` | `250` |

Source inspection suggests sensitivity to graphs, search. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## many_refs

Retain three tables of real references and repeatedly update every element. See [provenance](many_refs/PROVENANCE.md), the retained notices, and the source adaptation.

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/many_refs.sml`. Original, patch and notice retained.

ML Kit development allocation/retention workload. Three tables of boxed
real refs and sequential updates are retained. Original table length 100 and
100000 increments are normal; large scales retained refs. Every table is
checked against the exact number of increments, including the two tables
that upstream did not print. Their exact IntInf sum is returned.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 10` | `3000` |
| normal | `100 100000` | `30000000` |
| large | `10000 100000` | `3000000000` |

Source inspection suggests sensitivity to retained-data, refs, gc. These are diagnostic hypotheses; no performance finding is claimed. Related sources remain separate inventory entries until their algorithms, representations and inputs have been compared. The [literature survey](literature.md) provides family references; benchmark-specific references are added where the pinned source identifies them.

## tensor

Apply real and paired-complex elementwise and contraction operators, checking every result. See [provenance](tensor/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tensor.sml`. Original, adaptation patch and notices retained.

Juan Jose Garcia Ripoll tensor library, imported through MLton. The individual copyright and redistribution conditions are embedded in the
source (lines 31-68), including the acknowledgement requirement and author
name restrictions. Retained verbatim in TENSOR-LICENSE and upstream source.
Real and paired-complex representations, elementwise
operators and both contraction orders are retained. Checked Real64Array
accesses replace Unsafe access. The clock/timing printer is removed; every
result element is checked against 2, 1 or the contraction dimension.
Runs 20 repetitions of each elementwise operator and four of each contraction
as upstream, on one selected dimension rather than the five-size outer sweep.

Uses the standard default RealArray name, requiring binary radix and
53-bit precision explicitly. Poly/ML does not expose the optional Real64Array
name; its RealArray has the required representation. No change of floating
precision is permitted by this adapter.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4 1` | `1` |
| normal | `100 1` | `1` |
| large | `500 1` | `1` |

Source inspection suggests sensitivity to numerical, arrays, tensors. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## zern

Accumulate phase screens and validate every complex E-field value. See [provenance](zern/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/zern.sml`. Original, adaptation patch and notices retained.

David McClain phase-screen E-field study; source also credits Stephen Weeks
and retains AT&T notices. Fifteen coefficient screens and the flat real
array operations are unchanged. collect uses indices 1 through 15, so the
coefficients are 2 through 16 and their sum is 135. The independent field
is cos(1.35*i)+i*sin(1.35*i). Check both components at every cell with
absolute error <=1e-8. Removes clock reporting and selects one side length.

Uses the standard default RealArray name, requiring binary radix and
53-bit precision explicitly. Poly/ML does not expose the optional Real64Array
name; its RealArray has the required representation. No change of floating
precision is permitted by this adapter.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/zern.sml`,
is an additional source for this implementation. The complete kernel/input
agree; its launcher uses 1000 repetitions rather than a parameter. This
count remains accepted by the portable driver and is recorded as an
upstream invocation, rather than duplicating the implementation.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8 1` | `1` |
| normal | `128 1` | `1` |
| large | `128 100` | `100` |

Source inspection suggests sensitivity to numerical, arrays, phase-screens. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## smith-normal-form

Reduce an IntInf matrix to Smith normal form and consume its diagonal. See [provenance](smith-normal-form/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/smith-normal-form.sml`. Original, adaptation patch and notices retained.

Henry Cejtin integer Smith normal form. Retains the embedded matrix and
IntInf elimination, and consumes every diagonal entry while rejecting
nonzero off-diagonal entries. Profiles use leading 4, 12 and 26 squares;
upstream dimension 35 is still accepted by the driver but not selected.
The previous external runner used 26 to bound intermediate growth.
Review diagonal divisibility and compare the absolute diagonal product with
an independent Bareiss determinant before accepting fixtures.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4` | `1 ~1 1 ~7506` |
| normal | `12` | `1 1 ~1 1 ~1 ~1 ~1 ~1 1 1 1 ~6096777698704` |
| large | `26` | `1 ~1 ~1 1 1 1 ~1 ~1 1 ~1 1 ~1 1 1 1 1 ~1 ~1 1 1 1 ~1 ~1 ~1 ~1 ~60208115211646196979849372947415` |

Source inspection suggests sensitivity to big-integers, matrices. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## ratio-regions

Segment a fixed grid by preflow-push max flow and validate its min-cut mask. See [provenance](ratio-regions/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/ratio-regions.sml`. Original, adaptation patch and notices retained.

Jeff Siskind Scheme algorithm translated by Stephen Weeks. The Cox/Rao/Zhong
ratio-region reduction and preflow-push wave scheduling are retained.
The original generated capacities and weights remain fixed; expose and
consume the returned min-cut mask by counting true cells. No clock limit
is introduced. Reference fixtures must check the retained mask as well as
the count, before performance interpretations about flow behavior.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4` | `4` |
| normal | `32` | `256` |
| large | `128` | `4096` |

Source inspection suggests sensitivity to graphs, arrays, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## mpuz

Enumerate distinct digit assignments to a fixed multiplication puzzle. See [provenance](mpuz/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mpuz.sml`. Original, adaptation patch and notices retained.

Stephen Weeks, based loosely on Laurent Vaucher OCaml solution. Enumerates
distinct decimal assignments to the fixed multiplication puzzle. The
previously discarded solution text is observed, not replaced with a constant
success marker. Text length and Word32 rolling hash consume all assignments;
full reviewed reference text is retained beside the fixtures. Added output
observation allocates and is included in these workloads.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `61 40183CD7` |
| normal | `10` | `610 FF39A16D` |

Source inspection suggests sensitivity to search, integer-arithmetic. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## DLXSimulator

Interpret five embedded DLX programs and consume every simulated output. See [provenance](DLXSimulator/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/DLXSimulator.sml`. Original, adaptation patch and notices retained.

DLX instruction simulator with the five original programs (Simple, Twos,
Abs, factorial 12, GCD). Retains instruction decoding, memory and pipeline
model. Every simulated program output is returned for every invocation;
statistics printing is removed. The arithmetic outputs have independent
mathematical checks. Full instruction fixtures remain embedded upstream.

Smoke execution exceeded its initial 30-second quota on Rune. Its explicit
limit is now 120 seconds; normal repeats the full five-program set twice.
The timeout is retained in validation records, not counted as a passing run.

The source credits Matthew Thomas Fluet (Harvey Mudd College) and updates by
Stephen Weeks and Matthew Fluet; all header notices are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `47 ~10 10 479001600 1` |
| normal | `2` | `47 ~10 10 479001600 1 47 ~10 10 479001600 1` |

Source inspection suggests sensitivity to interpreter, words, arrays. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## knuth-bendix

Complete geometric group equations and validate the resulting rewrite rules. See [provenance](knuth-bendix/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/knuth-bendix.sml`. Original, adaptation patch and notices retained.

Knuth-Bendix term-rewriting completion (individual author not stated in this source), from the SML/NJ collection
through MLton. The geometric group equations and recursive path order are
unchanged. Return completed rules instead of discarding them, normalize both
sides of every input equation, and consume the exact completed rule text.
Retains rule ordering and numbering; correctness references cover this
problem, not arbitrary completion termination.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `672 AAE94F6A` |
| normal | `10` | `6720 4714BCB7` |

Source inspection suggests sensitivity to symbolic, rewriting, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## tyan

Compute the cyclic polynomial Groebner basis over F17 and consume its term summaries. See [provenance](tyan/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tyan.sml`. Original, adaptation patch and notices retained.

Thomas Yan multivariate polynomial/Groebner-basis workload. Preserves
the six cyclic equations, monomial trie, F17 modular/polynomial representations
and algorithm. Progress printing stays suppressed; consume only leading monomials and
term counts from the actual basis; complete reviewed upstream output accompanies the digest fixtures.
The additional textual observation and its allocation are recorded workload
changes. No claims about arbitrary polynomial correctness follow from this
fixed system.

Allyn Dimock adapted the TIL version to SML97; Stephen Weeks fixed the u6
input in 2001. The source explicitly records Thomas Yan's benchmark-use
permission and cites his 1998 Journal of Symbolic Computation article,
[The Geobucket Data Structure for Polynomials](https://doi.org/10.1006/jsco.1997.0176),
volume 25(3), pages 285-293. The source header misspells the title and gives
volume 23; bibliographic metadata is corrected here, with the original
header retained unchanged.

Historical ML Kit test/weeks4.sml at 6dab5582db22a5f5672ca1fc5244171687d83ce5
is the same cyclic-u6 kernel and twenty-call input as this MLton form.
Its name is an alias, not an additional polynomial algorithm; only email
spelling and the fixed outer driver differ. The pristine alias source is
retained here. Older test/tyan.sml remains a separately reviewed variant.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1608 BFA61E48` |
| normal | `2` | `3216 F8AFEF2B` |

Source inspection suggests sensitivity to symbolic, polynomials, modular-arithmetic. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## lexgen

Generate a lexer from the original SML specification and compare every output byte. See [provenance](lexgen/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/lexgen.sml`. Original, adaptation patch and notices retained.

Classic SML lexgen application from the SML/NJ tools, through MLton.
Preserves the full generator and original SML grammar/lexer input. Uses fixed
relative filenames to remove host working-directory identities from output.
Every generated source/signature/report is byte-exact checked against the
pinned source compiled by MLton. The fixture comparison and file reads are
included in the workload; compilation of the generated source is separate
validation. Original input notices are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `111408 D050F60A` |
| normal | `3` | `111408 D050F60A` |

Source inspection suggests sensitivity to compiler-application, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## mlyacc

Generate an LALR parser from the original SML grammar and compare its source and signature. See [provenance](mlyacc/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mlyacc.sml`. Original, adaptation patch and notices retained.

Classic SML mlyacc application from the SML/NJ tools, through MLton.
Preserves the full generator and original SML grammar/lexer input. Uses fixed
relative filenames to remove host working-directory identities from output.
Every generated source/signature/report is byte-exact checked against the
pinned source compiled by MLton. The fixture comparison and file reads are
included in the workload; compilation of the generated source is separate
validation. Original input notices are retained.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `117863 CDA6CD68;3150 27A50FF4` |
| normal | `3` | `117863 CDA6CD68;3150 27A50FF4` |

Source inspection suggests sensitivity to compiler-application, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## hamlet

Parse, elaborate and evaluate a unary arithmetic program with the HaMLet interpreter. See [provenance](hamlet/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/hamlet.sml`. Original, adaptation patch and notices retained.

Andreas Rossberg HaMLet Standard ML interpreter, as embedded by MLton.
Retains parsing, static elaboration and dynamic evaluation. Removes the
interactive session printer/loop and exposes Sml.exec only for observing the
result binding in the returned dynamic basis. The unary arithmetic program
is retained; smoke evaluates four squared (16), normal sixteen squared
(256), and large preserves the original nested power (65536). A host SML traversal consumes the returned unary value; an observer flag
rejects any swallowed fatal interpreter error or interpreted exception. These input changes and added traversal are
explicit workload adaptations, and there is no new Rune language feature.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `DATA/smoke.sml 1` | `16` |
| normal | `DATA/normal.sml 1` | `256` |
| large | `DATA/large.sml 1` | `65536` |

Source inspection suggests sensitivity to compiler-application, interpreter. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitfib35

Evaluate the ML Kit Fibonacci recurrence with its single n<1 base case. See [provenance](kitfib35/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitfib35.sml`. Original, patch and notices retained.

Recursive Fibonacci with the original n<1 base case, returning F(n+2).
This differs from the MLton fib recurrence. Normal preserves argument 35.
The original wildcard discards the number; the driver consumes every result
in an IntInf sum. An iterative recurrence gives independent fixtures.
The mlton and smlnj source variants have the identical kernel and input,
with only entrypoint wrapping differences; their provenance is retained.

Additional source provenance at the same ML Kit revision:

* `test/kitfib35_mlton.sml`: identical kernel and fixed input; entrypoint wrapping only.
* `test/kitfib35_smlnj.sml`: identical kernel and fixed input; entrypoint wrapping only.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `17711` |
| normal | `35 1` | `24157817` |
| large | `40 1` | `267914296` |

Source inspection suggests sensitivity to calls-recursion. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## fib0

Evaluate the two-base-case development Fibonacci recurrence. See [provenance](fib0/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/fib0.sml`. Original, patch and notices retained.

Naive Fibonacci with two unit base values, returning F(n+1). Different
base-case structure and values from kitfib35 and MLton fib. Normal retains
the original input 30 and upstream reference 1346269. The runtime-specific
printNum output adapter is replaced with a consumed IntInf result sum;
the recursive arithmetic kernel remains unchanged.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `10946` |
| normal | `30 1` | `1346269` |
| large | `40 1` | `165580141` |

Source inspection suggests sensitivity to calls-recursion. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitreynolds2

Search a shared tree with a chain of ancestor predicates. See [provenance](kitreynolds2/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitreynolds2.sml`. Original, patch and notices retained.

Shared binary tree with labels descending by depth. The exhaustive
ancestor search remains exponential although mk_tree allocates only n nodes.
Uses a chain of predicate closures for ancestor membership.
No ancestor label can repeat on a path, giving an independent false result
for every positive depth. Normal retains depth 20; output becomes a checked
count of searches. The two representation variants remain separately named.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `6 1` | `1` |
| normal | `20 1` | `1` |
| large | `22 1` | `1` |

Source inspection suggests sensitivity to higher-order, shared-data, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitreynolds3

Search the same shared tree using explicit ancestor lists. See [provenance](kitreynolds3/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitreynolds3.sml`. Original, patch and notices retained.

Shared binary tree with labels descending by depth. The exhaustive
ancestor search remains exponential although mk_tree allocates only n nodes.
Uses an explicit ancestor list and membership traversal.
No ancestor label can repeat on a path, giving an independent false result
for every positive depth. Normal retains depth 20; output becomes a checked
count of searches. The two representation variants remain separately named.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `6 1` | `1` |
| normal | `20 1` | `1` |
| large | `22 1` | `1` |

Source inspection suggests sensitivity to higher-order, shared-data, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitloop2

Count down a lexicographic pair using a tail-recursive loop. See [provenance](kitloop2/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitloop2.sml`. Original, patch and notices retained.

Tail-recursive lexicographic pair countdown. Retains the original
borrow/reset transition and pair argument. Normal preserves the corrected
upstream maximum 375; large uses the older stated value 2000. Stop only at
(0,0), and return the observed pair instead of printing a done marker.
Tail calls, tuple representation and allocation are diagnostic hypotheses.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `50` | `0 0` |
| normal | `375` | `0 0` |
| large | `2000` | `0 0` |

Source inspection suggests sensitivity to tail-calls, tuples. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitdangle

Build and consume one closure chain retaining list payloads. See [provenance](kitdangle/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitdangle.sml`. Original, patch and notices retained.

One retained closure chain.
Preserves each strict 2000-element payload list and the captured (m,list)
pair inside the singleton. Primitive polymorphic equality is replaced by
SML97 equality. The driver forces each completed chain once to consume its
result; the original dropped the function without evaluating it. This
additional forcing is explicit, and the triangular-number sum independently
validates construction. Normal preserves depth 1000 and payload 2000.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10 10` | `55` |
| normal | `1000 2000` | `500500` |
| large | `2000 2000` | `2001000` |

Source inspection suggests sensitivity to closures, allocation, lifetimes. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kitdangle3

Build and release three closure chains sequentially. See [provenance](kitdangle3/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitdangle3.sml`. Original, patch and notices retained.

Three closure constructions, released sequentially rather than retained together.
Preserves each strict 2000-element payload list and the captured (m,list)
pair inside the singleton. Primitive polymorphic equality is replaced by
SML97 equality. The driver forces each completed chain once to consume its
result; the original dropped the function without evaluating it. This
additional forcing is explicit, and the triangular-number sum independently
validates construction. Normal preserves depth 1000 and payload 2000.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10 10` | `165` |
| normal | `1000 2000` | `1501500` |
| large | `2000 2000` | `6003000` |

Source inspection suggests sensitivity to closures, allocation, lifetimes. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## msort

Sort the original ascending sequence with alternating-split copying mergesort. See [provenance](msort/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/msort.mlb`. Original, adaptation patch and notices retained.

Alternating split mergesort (individual author not stated) with explicit copying of the
remaining merge argument. Ordered project members msort.sml, upto.sml and
msortrun.sml are preserved in upstream/. Normal keeps the original sorted
1..50000 input, not the pseudo-random input of kittmergesort. The driver
validates every element against its expected ordinal and returns length,
IntInf sum and Word32 hash. These fixtures are calculated independently.
The standalone library and invocation entries retain provenance in the
inventory without creating duplicate benchmark implementations.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100` | `100 5050 C1C3524A` |
| normal | `50000` | `50000 1250025000 986A5B08` |
| large | `100000` | `100000 5000050000 CFA6A210` |

Source inspection suggests sensitivity to sorting, lists, allocation. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## kittmergesort_tp

Regenerate and sort ten lists in process using the shared copying kernel. See [provenance](kittmergesort_tp/PROVENANCE.md), retained upstream sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kittmergesort_tp.sml`. Original, adaptation patch and notices retained.

Same sorting kernel and input generator as kittmergesort, with a materially
different ten-repetition in-process driver. The implementation is shared,
while this workload remains separately named and measured. Each invocation
regenerates its list from seed 1 and validates its entire sorted result.
Normal preserves the ten 100000-element calls; large scales the list length.
Every invocation summary is retained in the expected result, rather than
observing only the last call.

The copying kernel and validation live in shared/kittmergesort.sml, with
separate thin named drivers. Each compilation contains one Benchmark
structure; there is no alias/rebinding of another benchmark driver.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `100 98940 43BE5438` |
| normal | `100000 10` | `100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55;100000 105840457 7531BE55` |
| large | `1000000 10` | `1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A;1000000 1058589168 4A4B293A` |

Source inspection suggests sensitivity to sorting, lists, allocation. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## Recorded host coverage

Poly/ML 5.9.2 lacks the optional Int64 structure used by peek and
vector64-concat. These are recorded unavailable comparisons; the suite does
not substitute a different integer width. Real-array kernels instead use
RealArray with an explicit binary64 precision requirement.

ML Kit 4.7.23 crashes compiling the current Boyer, Knuth-Bendix Tyan and FXP
ports. Their logs remain failures and cannot supply measurements. The four
primary systems (Rune, MLton, SML/NJ and Poly/ML) pass applicable smoke
checks. The broader acceptance run and normal-profile results are recorded
in validation.md as they complete.

## barnes-hut

Advance a seeded three-dimensional N-body model with octree force approximation. See [provenance](barnes-hut/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/barnes-hut.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories three-dimensional Barnes-Hut simulation from the
SML/NJ collection. Retains the Plummer distribution, seed 123, octree,
force approximation, leapfrog integration, dtime=.025, eps=.05 and tol=1.
Normal and selected large preserve the original stop time 2.0; smoke uses .05.
Observe every final position and velocity component rather than discarding
the simulation. Reference state comes from the pinned source compiled by
MLton, with a read-only observer, and uses 17 significant decimal digits.
Compare each component with absolute tolerance 1e-8 plus relative 1e-6.
Returns the actual body and step counts after validation.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0.05 expected/smoke.tsv` | `16 3` |
| normal | `256 2.0 expected/normal.tsv` | `256 81` |
| large | `8192 2.0 expected/large.tsv` | `8192 81` |

Source inspection suggests sensitivity to numerical, spatial, mutable-data. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## tsp

Build and validate a divide-and-conquer travelling-salesman tour. See [provenance](tsp/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tsp.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories divide-and-conquer travelling-salesman heuristic.
Retains the generated point distribution, tree, nearest-neighbor conquer
and merging/orientation logic. The generator uses the source-commented
32-bit Park-Miller modulus 2147483647 explicitly, with IntInf intermediate
arithmetic, rather than each host's Int.maxInt. This changes generator
representation but keeps MLton's input distribution. Observe the complete
cycle, reject broken backlinks/cardinality, and compare its sorted point
multiset with the input tree. Check length against the pinned upstream
MLton result with absolute and relative tolerance 1e-8. Large uses the
initial 32767-point setting; the later MLton 2097151 override is not selected.
Additional cycle validation/sorting is included in the workload.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tsp.sml`,
is an additional source for this implementation. Tree/TSP/Rand/BuildTree agree.
ML Kit selects 32767 vertices and four tours; `test/tsp_tp.sml` changes
only the call count to eight. MLton selects 2097151 vertices with a
parameterized repeat count. Selected profiles bound the work; these
original invocations remain documented. Repetitions do not change the
algorithm, representation or deterministic tree distribution.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `31 10 5.0285603627720601` | `31` |
| normal | `1023 150 34.594758416849281` | `1023` |
| large | `32767 150 190.67246516366754` | `32767` |

Source inspection suggests sensitivity to numerical, spatial, mutable-data. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## fannkuch

Enumerate permutations, flip their prefixes and consume the alternating checksum. See [provenance](fannkuch/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/fannkuch`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ fannkuch-redux implementation. Keeps mutable
permutation arrays, rotation order, flip counting and alternating checksum.
Normal retains upstream testit size 7; large retains three size-11 calls.
Return the observed maximum and IntInf sum of checksums. Benchmark Game
reference values are max/checksum (7,11), (16,228), and (51,556355) before
repetition; independent small permutation checks are required.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `5 1` | `7 11` |
| normal | `7 1` | `16 228` |
| large | `11 3` | `51 1669065` |

Source inspection suggests sensitivity to permutations, mutable-arrays. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## f-arith

Accumulate paired Leibniz-series terms and check the approximation of pi. See [provenance](f-arith/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/f-arith`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ floating arithmetic loop: two alternating
Leibniz terms per iteration. Preserve acc+1/n-1/(n+2) and denominator
increment 4, including their operation order. Check against mathematical
pi with the next-term bound 4/(4*steps+1), plus 8*steps*2^-53 for rounding
accumulation. Large retains the original five billion steps and requires
a default int precision of at least 34; narrower configurations are
unavailable for that profile. Removes logging, consumes the computed value.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000` | `1` |
| normal | `1000000` | `1` |
| large | `5000000000` | `1` |

Source inspection suggests sensitivity to numerical, float-arithmetic. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## stream-sieve

Demand a prime from the original nonmemoized infinite-stream sieve. See [provenance](stream-sieve/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/stream-sieve`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ infinite stream sieve. The stream constructor
holds a strict head and a nonmemoized tail function. This differs from
the memoized nofib finite sieve and is intentionally retained. get uses
a zero-based index; large preserves 20000. Every requested prime is
consumed and checked against an independent finite Eratosthenes sieve.
The Streams and Sieve sources are compiled in dependency order, rather
than the textual order of the CM project.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10` | `31` |
| normal | `1000` | `7927` |
| large | `20000` | `224743` |

Source inspection suggests sensitivity to streams, higher-order, nonmemoized. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## twenty-four

Enumerate arithmetic-expression solutions using continuation callbacks. See [provenance](twenty-four/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/twenty-four`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ arithmetic-expression solver. Retains its
expression tree and continuation/resume enumeration, including repeated
solutions. Smoke retains the [4,7,8,8] fixture with count 44. Normal
enumerates four distinct cards selected from 1..10, and large retains
250 full deck enumerations. Actual callback counts are accumulated in
IntInf rather than dropped. Reference counts come from the unchanged
upstream solver on MLton; no claim of unique expression deduplication.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `sample 8 1` | `44` |
| normal | `deck 10 1` | `9603` |
| large | `deck 10 250` | `2400750` |

Source inspection suggests sensitivity to symbolic, search, continuations. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## simple

Compute a hydrodynamic time step and check all final state arrays. See [provenance](simple/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/simple.sml`. Original, adaptation patch and notices retained.

SML/NJ hydrodynamics simulation. Every arithmetic routine and the custom
Array2 representation are preserved. Replaces the value-parameter functor
wrapper with a function so grid size is runtime input in SML97; its original
body remains a local declaration block with freshly initialized state.
Smoke uses grid maximum 8, normal preserves 100 and one time step, large
selects 128. Consume all eleven final arrays and both scalar results.
Reference state is the pinned MLton program with a read-only observer;
per-element error bounds are 1e-8 absolute plus 1e-7 relative. The original
100-grid scalar checks (truncated c*10000=6787 and delta=-33093) provide
additional upstream evidence. Validation reads are included in the workload.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8 1 expected/smoke.txt` | `710` |
| normal | `100 1 expected/normal.txt` | `110006` |
| large | `128 1 expected/large.txt` | `180230` |

Source inspection suggests sensitivity to numerical, arrays, simulation. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## nbody

Advance five immutable solar-system records and validate their total energy. See [provenance](nbody/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/nbody`.
Copyright/notice and original ordered sources retained.

2025 Fellowship of SML/NJ solar-system benchmark. Keeps five planets,
immutable planet records/lists, pairwise velocity updates, momentum offset,
dt=.01 and the original numerical operation order. The original driver
offsets momentum before calling run, which offsets it again; this is
preserved. Normal uses one million steps; large preserves fifty million.
Energy references come from the original C implementation in other/main.c
with an explicit second momentum offset to match the SML driver, and
17-digit output; reference.patch records these reference-only changes. Bounds are absolute 1e-9 plus
relative 1e-9; they are not an energy-conservation claim.

The reference offset uses subtraction from the sun velocity before its
second call, matching the immutable SML operation. The original C operation
assigns a velocity assuming an initially resting sun; calling that assignment
twice would reset the sun velocity and produce the wrong reference problem.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 ~0.1690507623824094` | `100` |
| normal | `1000000 ~0.16908618459855648` | `1000000` |
| large | `50000000 ~0.16905990681396785` | `50000000` |

Source inspection suggests sensitivity to numerical, immutable-data, nbody. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## output1

Write individual characters to a regular file and validate every output byte. See [provenance](output1/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/output1.sml`. Original and adaptation patch retained.

The output1 loop still writes one a character per iteration through TextIO.
The Unix /dev/null sink is replaced by a fixed regular file so the SML97
program can consume and validate its actual output. This materially adds
filesystem writes and validation reads; comparisons measure this documented
file-output variant, not the original discard-device timings. Every byte
must be 97 and the observed file length must equal the requested count.
Large preserves one billion writes; it is explicitly selected and creates
a one-GB artifact within the isolated run directory.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1024` | `1024` |
| normal | `1000000` | `1000000` |
| large | `1000000000` | `1000000000` |

Source inspection suggests sensitivity to io, file-output. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## ray

Interpret the original sphere scene and validate its rendered dump image. See [provenance](ray/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/ray.sml`. Original, adaptation patch and notices retained.

AT&T Bell Laboratories stack-language ray tracer from the SML/NJ collection.
Retains the original sphere scene, interpreter, camera and shading routines.
The image side is a runtime parameter; normal preserves 512x512, and the
same unit-square sampling convention is retained. Consume the entire dump
image and compare its encoded pixels/header byte-exactly against the pinned
upstream MLton output. This is a zero-error bound in quantized output units,
not a tolerance on unencoded floating-point intermediates. File writes and
validation reads are part of the workload.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 DATA/ray expected/smoke.dump` | `813 4F7643A5` |
| normal | `512 DATA/ray expected/normal.dump` | `786479 5580B075` |
| large | `1024 DATA/ray expected/large.dump` | `3145777 399DC82D` |

Source inspection suggests sensitivity to numerical, rendering, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## raytrace

Render the original chess scene and check every quantized RGB pixel. See [provenance](raytrace/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/raytrace.sml`. Original, adaptation patch and notices retained.

PL Club winning OCaml entry to the 2000 ICFP programming contest, translated
by Stephen Weeks on 2000-10-11. Retains the language evaluator, CSG objects,
lighting, camera, intersections and shader. Keeps the original chess scene;
only its final render dimensions vary: 16x12 smoke, original 400x300 normal,
800x600 large. The original driver swallowed all exceptions; this driver
propagates them and consumes the full PPM image. Output is checked at every RGB pixel after 8-bit quantization against
reviewed upstream images (MLton and both monolithic and suite-driver SML/NJ builds), with at most two intensity
levels of error per channel. Headers and image dimensions remain exact. File I/O is included.

The smoke pixel (12,6) exposes a measured numerical discontinuity: on
MLton its reflected ray has no intersection, while SML/NJ reports an interval
with both endpoints 0.04810688415066595. The original filter tests only
its starting distance, so this zero-width interval changes the reflected
color. The initial hit endpoints differ by less than 1e-15. The original
kernel remains unchanged; each pixel must match one of the recorded original-kernel
program outputs within two 8-bit levels per channel. This is a specified
reference-set bound, not a claim that arbitrary large color errors are
acceptable. Other large reference differences are recorded as hypotheses
of the same discontinuity until individually traced.

The chess input credits Leif Kornstaedt, copyright 2000, revision 1.6.
Its notice is retained in the pristine input. Reference images are generated
from that input by the pinned SML translation on the recorded host versions.

The normal SML/NJ suite-driver build differs at five further pixels from
its monolithic entrypoint. Instrumenting the render can also change these
boundary results. A separate suite-driver reference is retained; this is
recorded source/compilation sensitivity, not a claim that the kernel isolates
a single compiler optimization. Outside the reviewed reference sets, errors
above two intensity levels remain failures.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/raytrace.sml`,
is an additional source for this implementation. The source differences
are legacy Byte.unpackString(array,offset,length), unchecked lexer
Vector/CharVector reads and a one-call launcher. SML97 checked reads and
Word8ArraySlice conversion produce the existing port exactly. Removing
unchecked reads can affect cost and is recorded as a library adaptation;
this does not establish equal upstream performance.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `DATA/smoke.gml expected/smoke.ppm expected/smoke-smlnj.ppm` | `192` |
| normal | `DATA/normal.gml expected/normal.ppm expected/normal-smlnj.ppm` | `120000` |
| large | `DATA/large.gml expected/large.ppm expected/large-smlnj.ppm` | `480000` |

Source inspection suggests sensitivity to numerical, rendering, interpreter, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## vliw

Schedule and compress instructions, then validate both assembly streams. See [provenance](vliw/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/vliw.sml`. Original, adaptation patch and notices retained.

SML/NJ VLIW instruction scheduling/compression workload. Retains ndotprod.s,
instruction parsing, dependency graph, delay handling, compression and output
formats. Reset name allocation and idempotency as the original driver does.
Normal preserves window size 9; smoke selects 3; large repeats window 9 ten times. Consume and
check every instruction token in both assembly outputs. Fixed relative
filenames remove directory identities from output; generated artifacts are
reference fixtures from the pinned original program on MLton.

The initial window-20 large trial raises FILTERSUCC in the upstream code.
That trial is recorded as a failure; it does not define a golden result.
The selected large profile repeats the validated original window-9 workload,
regenerating and validating both outputs on every call.

Real.toString formats integral real literals as 3 on MLton and 3.0 on
Poly/ML. The checker preserves the output and compares GETREAL values by
finite binary64 value and sign, normalizing their mantissa/exponent only for
the digest. Every other instruction token and line remains exact.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `3 1 expected/smoke.tmp.s expected/smoke.cmp.s` | `458 5C980444;405 9DAD17EC` |
| normal | `9 1 expected/normal.tmp.s expected/normal.cmp.s` | `458 5C980444;398 EA74477B` |
| large | `9 10 expected/large.tmp.s expected/large.cmp.s` | `458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B|458 5C980444;398 EA74477B` |

Source inspection suggests sensitivity to compiler-application, graphs, files. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## fxp

Parse deterministic generated XML and validate its complete tag and attribute counts. See [provenance](fxp/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/fxp.sml`. Original, adaptation patch and notices retained.

Andreas Neumann fxp 1.4.4, in MLton's generated 2001 monolith. The source
version constant is retained; the source identity is the pinned MLton file.
[The archived project documentation](https://www.informatik.uni-bremen.de/cofi/CASL-CD/Tools/Cats/src/fxp/doc/)
identifies authorship. Its separate copyright/download links return 404;
the monolith carries no individual notice. The MLton project notice is
retained; recovering the original individual notice remains a provenance
check, not a claim that the aggregate notice describes every component.

Retains the null XML parser, symbol tables, Unicode handling and resolver.
Legacy Timer, vector/array iteration and Substring.all are adapted to the
current SML97 Basis. Iterators preserve absolute indices. No remote URI or
DTD retrieval is used. Explicitly disable validation for the generated
DTD-free document, fail on parser errors and consume start/end/attribute
event counts. Input generation and these additional hooks are part of the
measured workload.

A new portable SML recipe uses the old external helper's word/tag vocabulary
and depth/length distributions, with seed 12345 and exact Word32 ANSI-LCG
arithmetic modulo 2^31. It ensures unique attributes and correctly nested
children. The old awk helper used rounded floating arithmetic, could emit
duplicate attributes, and printed nested calls separately; these bytes and
old count baselines are not reused. Profiles select target payload byte
limits 8192, 1200000 and 4800000, permitting a final-element overshoot.

The URI retrieval helper checks OS.Process.isSuccess instead of comparing
opaque status values for equality, matching the current Basis contract.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/fxp.sml`,
is an additional source for this implementation. The complete source agrees
with the MLton source after whitespace normalization, including its driver.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8192` | `79 79 131` |
| normal | `1200000` | `11362 11362 17000` |
| large | `4800000` | `45290 45290 67933` |

Source inspection suggests sensitivity to parser-application, unicode, generated-input. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## model-elimination

Search the original first-order problem sets with deterministic inference budgets. See [provenance](model-elimination/PROVENANCE.md), retained upstream sources and adaptation patch.

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/model-elimination.sml`. Original, adaptation patch and notices retained.

Joe Hurd's September 2002 model-elimination benchmark, using the embedded
Metis code and original first-order problem sets. Preserves meson settings,
problem pruning, CNF normalization choices, clause machinery and scheduling.
Select a prefix of the original problem order and impose the existing
inference meter instead of a CPU-time limit. The count-reference Timer
adapter advances by 100 microseconds per observation and is reset per run;
scheduler readings are deterministic. Slice and overall limits are inference
counts. This stopping/scheduling adaptation is explicit, not a clock claim.
Consume each actual prover result as name/proved-or-unknown; a returned proof
must have an empty clause. Runtime exceptions propagate. Unknown under a
work limit is distinguished from a proved theorem in the result trace.
Reference traces come from the pinned SML program with these documented
work limits on MLton, and are reviewed problem by problem.

Suppress diagnostic printing while retaining the result trace. Smoke stops
P26 as unknown under 1000 inferences. Normal proves nine of the fourteen
selected problems under 50000; large proves all fourteen under 200000.
The three reviewed name/status traces accompany the expected digests.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1 1000` | `12 A7A12B55` |
| normal | `14 50000` | `211 10CC61C0` |
| large | `14 200000` | `206 D43957EC` |

Source inspection suggests sensitivity to symbolic, proof-search, work-limit. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## sat

Solve a fixed Boolean formula with nested higher-order choices. See [provenance](sat/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/sat/main.sml.
Copyright 2025 Fellowship of SML/NJ; notice and original retained.

Preserves the nine-clause formula, ten nested higher-order Boolean choices,
true-before-false search order and first-satisfying-assignment stopping.
Removes candidate logging and consumes every returned Boolean. An independent
1024-assignment truth table finds 80 satisfying assignments,
including the three unused variables. Normal repeats 10000 solves; large
retains the original million. Allocation, closures and short-circuiting are
diagnostic hypotheses, not measured findings.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `10000` | `10000` |
| large | `1000000` | `1000000` |

Source inspection suggests sensitivity to symbolic, search, higher-order. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## boyer-smlnj

Prove the original theorem using the modern modular SML/NJ rewriting checker. See [provenance](boyer-smlnj/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/boyer.
Ordered original sources, notice and adaptation patch retained.

Modern modular SML/NJ tautology checker. Keeps the four-module property
list, rewrite rules, substitution and original theorem. Every actual result
must be true, as upstream testit requires. Large preserves 1300 repetitions.
Only the String.concatWithMap presentation extension is replaced by the
SML97 map/concatWith composition. This source organization and newer rules
remain distinct from the old MLton monolith until a full equivalence audit.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `100` | `100` |
| large | `1300` | `1300` |

Source inspection suggests sensitivity to symbolic, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## logic-smlnj

Find a peg-solitaire solution through the modern modular unifier and trail. See [provenance](logic-smlnj/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/logic.
Ordered original sources, notice and adaptation patch retained.

Modern modular peg-solitaire unification/backtracking workload. Retains
Term, Trail, Unify and Data source order, first-success continuation and
original board. Normal preserves sixty solves. A normal return without
reaching the success continuation fails; the actual success count is
consumed. Separate from MLton's concatenated earlier variant.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1` |
| normal | `60` | `60` |
| large | `600` | `600` |

Source inspection suggests sensitivity to symbolic, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## life-smlnj

Repeat fifty-generation glider-gun evolutions with complete coordinate checks. See [provenance](life-smlnj/PROVENANCE.md), retained upstream sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/life.
Ordered original sources, notice and adaptation patch retained.

Modern list-based Game of Life variant. Retains the sorted generations,
neighborhood merge and glider-gun seed. Observe every live coordinate and
return count/hash for every invocation. Normal performs 100 fifty-generation
calls; large preserves the original 1000 calls. Independent Python set-based
neighbor counting supplies the exact generation summaries. The repetition
policy differs materially from the long single evolution in MLton life.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10 1` | `61 3AA2F3FF` |
| normal | `50 100` | `54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3` |
| large | `50 1000` | `54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3;54 4E6F7BB3` |

Source inspection suggests sensitivity to symbolic, search. These are hypotheses; no measured attribution to a compiler feature is claimed. Related source variants remain in the inventory until their code, inputs and representations have been compared. See the [literature survey](literature.md) for family references.

## minimax

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/minimax.
Copyright 2025 Fellowship of SML/NJ; source and notice retained.

Retains the complete tic-tac-toe rose tree and the separate transposition-table
version with 59049 slots. Each call builds both as upstream. Traverse every
returned node, consuming node count, maximum depth and root score. An
independent exhaustive Python search in `oracle.py` gives a draw (score zero)
and confirms both tree-size/depth fixtures from upstream testit. Normal uses
two calls; large preserves ten. Smoke has recorded 120-second and 2-GiB overrides
because even one call constructs the complete game tree. The 1-GiB
smoke run passed the three reference hosts but Rune reported out of memory;
the larger quota preserves the complete allocation workload.
No cache is reused between separate transposition-table constructions.

Replace the SML/NJ extension `Option.isNone` with `not o Option.isSome`.
The ordinary option list representation, move order and scoring are unchanged.
The read-only traversal is additional measured work; both root scores must
be zero before the six-integer summary reaches the suite's exact checker.
The full tree versus cache-pruned tree distinguishes allocation and lookup
costs. These are source-based hypotheses, not measured explanations.

Profiles repeat both constructions 1, 2 and 10 times for smoke, normal and large.

## iter-pidigits

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`,
`programs/iter-pidigits/pi-digits.sml` and `main.sml`.
Copyright 2026 The Fellowship of SML/NJ; notice and pristine sources retained.
The upstream README identifies the Benchmarks Game C version (retained in
the pinned tree at `other/pidigits.c`) and Jeremy Gibbons's
[Unbounded Spigot Algorithms for the Digits of Pi](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf), section 5.

This is an iterative IntInf spigot, distinct from the lazy stream and
zero-count stopping condition of `pidigits`. Keep its arithmetic, column
counter and termination. Capture each emitted digit, omit the human-readable
column labels, then validate every digit against an independently calculated
Chudnovsky fixture (`oracle.py`). Smoke retains upstream's 30-digit check;
normal selects 100 digits; large preserves upstream's 2000. The original
2000- and 500-digit normal runs passed the reference hosts but timed out after 600
seconds on Rune. Moving that input to the 3600-second large profile preserves
the algorithm and stopping condition without changing its arithmetic. There are no external
datasets or random seeds. Arbitrary-precision division and multiplication
and iterative control flow are source-based diagnostic hypotheses.

## mazefun

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mazefun/main.sml`.
Copyright 2024 The Fellowship of SML/NJ; notice and pristine source retained.
Marc Feeley's Larceny Scheme maze generator was ported by Kavon Farvardin
for Manticore. Upstream calls the benchmark `mazefn`; the directory and
established Scheme name are `mazefun`. Record `mazefn` as an alias.

Preserve persistent list matrices, recursive cavity relabeling, hole order,
and the integer generator `(seed*3581+12751) mod 131072`, seeded at zero for
each shuffle. Rename the module to expose `makeMaze` to a portable driver.
Flatten the complete rendered matrix into one line with slash row separators
and compare every character; suppress direct logging. Repetitions check
each regenerated maze against the first. Smoke is the 11-by-11 maze printed
in the upstream comment; normal uses 100 repetitions of its 15-by-15 maze;
large retains the original 10000 repetitions. Each consumes its result.

Independent fixtures come from the union-find Python oracle, whose different
representation also verifies a connected, acyclic maze. The 11-by-11 fixture
was reviewed against the source comment. No external dataset is required.
Persistent updates, flood-fill recursion and intermediate lists are
diagnostic hypotheses from source inspection. No performance finding is
claimed. The Larceny/R6RS family remains a coverage candidate in the
[literature review](../literature.md); this port records that overlap.

See [retained source and patch](mazefun/) and the
[executable independent oracle](mazefun/oracle.py).

## queens-lazy

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/queens/Main.hs`.
The source says it was taken from the LML distribution. Individual author
and notice are not stated in this file; `NOTICE` records that outstanding
lookup rather than assigning another collection's license. Original source,
Makefile and fast/normal/slow fixtures are retained.

Enumerate placements by levels: each prior board precedes columns 1 through
n, with the original short-circuit row/diagonal safety test. The Haskell
list comprehension is translated into memoized stream tails in
`shared/queens.sml`; pending functions are released after forcing. Exceptions
are memoized and recursive forcing is detected by `shared/lazy.sml`. The
outer count forces the complete solution stream; board suffixes remain
shared. No complete solution list is retained by the counter. Integer values
and counts fit a signed 31-bit integer for selected profiles; repetition
totals use IntInf. There are no external inputs or random choices.

Smoke counts size 4 (2); normal counts size 10 (724); large counts size 12
(14200), preserving upstream's fast input. Upstream normal/slow sizes 13/14
and their 73712/365596 fixtures remain recorded rather than being silently
replaced. The unchanged Haskell original compiled with GHC agrees on all
selected sizes. The strict variant uses the same board/safety/order logic
but eagerly constructs levels; different forcing, retention and allocation
justify separate names. Sandmark `nqueens` instead counts depth-first with
mutable sibling counters. These differences are source-based hypotheses;
no measured performance cause is claimed. See
[Partain and the nofib survey](../literature.md).

See [provenance and original files](queens-lazy/PROVENANCE.md).

## queens-strict

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/queens/Main.hs`.
The source attributes its origin to the LML distribution; individual author
and license are unstated. Original source/build parameters/fixtures and the
unresolved individual-notice lookup are retained in this directory.

Preserve the board-first list-comprehension order, columns 1 through n,
short-circuit safety test and shared board suffixes. Evaluate the generated
levels eagerly using map, mapPartial and concatenation before taking length.
This deliberately changes Haskell's demand and allocation behavior; the
faithful memoized `queens-lazy` variant remains separately available.
No mutation, randomness, numeric-width substitution or external data is
introduced. Selected counts fit signed 31-bit integers; the outer repetition
total uses IntInf. Newly written SML97 translation lives in
`shared/queens.sml`; the thin named driver consumes its count.

Profiles select sizes 4/10/12 once, yielding 2/724/14200. Size 12 is the
original fast input; upstream's normal 13 (73712) and slow 14 (365596)
are preserved in the retained Makefile/fixtures. GHC's unchanged Haskell
program agrees for selected sizes; semantic tests independently check
both SML variants for every size 1 through 10. Sandmark `nqueens` uses a
different depth-first mutable counter and stays separate. Level retention,
intermediate lists and allocation are hypotheses from source inspection,
not measured causal findings. See [the nofib literature](../literature.md).

See [provenance and original files](queens-strict/PROVENANCE.md).

## nqueens

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-numerical/nqueens.ml`, executable `nqueens.exe`.
No individual author or notice is stated in the file. Sandmark's root
public-domain notice is retained in `LICENSE`; the original file is retained.
This is the sequential executable in a directory also containing a separate
parallel implementation; no Domainslib or multicore facility is needed.

Translate depth-first row search directly, preserving the zero-based column
loop, shared immutable board suffixes, short-circuit conflicts, and mutable
sibling count. Explicit SML tail recursion replaces OCaml's for loop. The
count is consumed rather than formatted as a human-readable sentence.
There are no external inputs or seeds. Selected counters fit signed 31-bit
integers; no OCaml wrapping arithmetic is exercised by these profiles.

Smoke size 4 gives 2, normal size 10 gives 724, and large preserves the
upstream default size 13 giving 73712. All three are in the original source
comment and agree with the unchanged OCaml program. nofib queens counts
the same mathematical solutions through level generation, with distinct
lazy and strict retention; those are different algorithms/workloads, not
duplicates. Search, recursion, board sharing and local mutable counters are
source-based hypotheses. See [the Sandmark literature](../literature.md).

See [provenance and original files](nqueens/PROVENANCE.md).

## rec_seq_ack

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/multicore-effects/rec_seq_ack.ml`, executable `rec_seq_ack.exe`.
The file references the Larceny/R6RS benchmarks (spelled Larcenry upstream)
but does not identify an individual author/notice. Sandmark's root
public-domain notice and pristine program are retained. This sequential
member uses no effect handlers; the effect-based executable remains deferred.

Preserve the three-case Ackermann recurrence and nested strict call. Move
launcher defaults into fixed runtime profiles: smoke `(reps,m,n)=(1,3,6)`,
normal `(2,3,8)`, large the original `(2,3,11)`. Consume every repetition
in an IntInf sum rather than discard the upstream accumulator and print only
the final value. This is documented additional checking/allocation work.
The kernel retains ordinary signed integer arithmetic; selected results fit
31 bits. No filesystem data or random input is used.

The formula A(3,n)=2^(n+3)-3 independently gives 509, 2045 and 16381;
summed fixtures are 509, 4090 and 32762. The unchanged OCaml program agrees
with each individual result. Recursive calls and deep stack activity are
source-based diagnostic hypotheses, not measured conclusions. See
[Larceny overlap and the Sandmark literature](../literature.md).

See [provenance and original files](rec_seq_ack/PROVENANCE.md).

## klife_eq

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/klife_eq.sml`.
Individual author/notice is not identified in this file; the three aggregate
ML Kit/GPL/SML-NJ notices and pristine source are retained without claiming
that every aggregate notice applies to this individual program.

Retain double copying of generation arguments, survivor lists, dead-neighbor
lists, newborn lists and explicit boolean copying. The neighbor function is
passed explicitly and equality uses ordinary polymorphic equality. Normal
preserves the original three 50-generation calls; large selects 250.

Wrap the original outer let/local declarations in LifeKernel to expose iter
and alive. Suppress per-generation progress and ASCII rendering; consume
every final sorted coordinate in the same fixed Word32 summary used by the
other Life variants. Retain algorithms, custom list functions, generator,
copying and ordinary integer arithmetic. Selected coordinates fit 31 bits;
the checksum is explicitly modulo 2^32. Smoke selects ten generations once.

Fixtures come from an independent set-based eight-neighbor simulation of
the exact 44-cell glider-gun seed, with sorted-coordinate checksum review.
They agree mathematically with life-smlnj; these implementations differ in
copying, equality specialization and argument shape and remain separately
named. Those differences are source-based diagnostic hypotheses, not
measured causal findings. See [the ML Kit region/lifetime literature](../literature.md).

See [source and adaptation provenance](klife_eq/PROVENANCE.md).

## kitlife35u_smlnj

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitlife35u_smlnj.sml`.
Individual author/notice is not identified in this file; the three aggregate
ML Kit/GPL/SML-NJ notices and pristine source are retained without claiming
that every aggregate notice applies to this individual program.

Retain typed integer/pair equality functions and explicit integer, boolean
and generation copying. The upstream resetRegions function already returns
unit without any effect; keep its calls and double generation copies. No
region facility is required or added. Large preserves three 250-generation
calls; normal selects three 50-generation calls. The MLton-host sibling has
the same body and count but a different launcher, recorded separately in
the inventory as an exact entrypoint duplicate sharing this implementation.
Its pristine source is retained at `upstream/host-mlton.sml`.

Wrap the original outer let/local declarations in LifeKernel to expose iter
and alive. Suppress per-generation progress and ASCII rendering; consume
every final sorted coordinate in the same fixed Word32 summary used by the
other Life variants. Retain algorithms, custom list functions, generator,
copying and ordinary integer arithmetic. Selected coordinates fit 31 bits;
the checksum is explicitly modulo 2^32. Smoke selects ten generations once.

Fixtures come from an independent set-based eight-neighbor simulation of
the exact 44-cell glider-gun seed, with sorted-coordinate checksum review.
They agree mathematically with life-smlnj; these implementations differ in
copying, equality specialization and argument shape and remain separately
named. Those differences are source-based diagnostic hypotheses, not
measured causal findings. See [the ML Kit region/lifetime literature](../literature.md).

See [source and adaptation provenance](kitlife35u_smlnj/PROVENANCE.md).

## kitqsort_no_basislib

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`,
`test_dev/kitqsort_no_basislib.sml`. Source attributes the copying/argument
transformation to Sestoft and Bertelsen, December 1995, and references
Paulson pages 96/98 and exercise 3.29 for generation/quicksort. Original
source and the aggregate ML Kit/GPL/SML-NJ notices are retained; no individual
license is asserted beyond what those notices establish.

Retain the pivot/partition order, copies of left partitions, right-first
recursive sort, tuple arguments, aliases and tail recursion. This differs
from copying mergesort and from later variants with active forceResetting.
The forceResetting mention here is inside a comment and stays inert.

Replace the old primitive-based mini-Basis by equivalent SML97 operations:
real division, Real.floor, Real.fromInt, string operations, print and
polymorphic equality. The foreign context pointer was only an implementation
argument to floorFloat; the algorithm requires no foreign call or runtime
facility. Keep all custom list and sorting functions from the kernel, and
wrap its outer let in SortKernel. Suppress old Ok/Oops output; validate order,
length, IntInf sum and every sorted element in a fixed Word32 checksum.

Keep the original floating Park-Miller generator, seed 117, multiplier
16807, modulus 2147483647 and value range 1..100000. Require binary64 Real;
all generator intermediate integer products fit its exact 53-bit range,
allowing an independent integer-modular Python oracle. Smoke sorts 100,
normal preserves 25000 and large selects 100000. No filesystem input or
random operating-system state is used. The added complete result scan is
measured work. Copying, tuple lifetimes and specialization are source-based
hypotheses, not measured explanations; see [ML Kit/Paulson references](../literature.md).

See [the original source and adaptation patch](kitqsort_no_basislib/PROVENANCE.md).

## tailfib-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tailfib.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/tailfib_smlnj.sml`. Their pristine sources are retained.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tailfib.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/tailfib_smlnj.sml`. Their pristine sources are retained.

Keep the original 38-step accumulator recurrence; large retains fifty million
repetitions. MLton tailfib instead selects 44 steps and one million repetitions.
Runtime parameterization and an IntInf checksum are driver adaptations.
Independent iterative Fibonacci supplies fixtures; the kernel is unmemoized.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags calls,recursion
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `6765` |
| normal | `38 1000` | `39088169000` |
| large | `38 50000000` | `1954408450000000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `20 1` | `6765` |
| normal | `38 1000` | `39088169000` |
| large | `38 50000000` | `1954408450000000` |


## tak-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tak.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/tak_smlnj.sml`. Their pristine sources are retained.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tak.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/tak_smlnj.sml`. Their pristine sources are retained.

Keep the strict Takeuchi recurrence and original (18,12,6) input. Large
retains 5000 calls; normal selects 100. The MLton profile uses different
coordinates, so this remains a named parameter variant. The independent
memoized oracle changes only fixture generation; the kernel remains unmemoized.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags calls,recursion
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `18 12 6 1` | `7` |
| normal | `18 12 6 100` | `700` |
| large | `18 12 6 5000` | `35000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `18 12 6 1` | `7` |
| normal | `18 12 6 100` | `700` |
| large | `18 12 6 5000` | `35000` |


## matrix-multiply-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/matrix-multiply.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/matrix-multiply_smlnj.sml`. Their pristine sources are retained.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/matrix-multiply.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/matrix-multiply_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks. Preserve Array2 dot-product multiplication and the original
all-ones distribution, regenerated for each call. Large preserves dimension
200 twice. This differs from MLton ramp data/dimension 500. Check every
result element equals n exactly (selected integral doubles are exact); sum
n^3 per call is independently derived. No floating tolerance is needed.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags arrays,numerical
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4 1` | `64` |
| normal | `100 2` | `2000000` |
| large | `200 2` | `16000000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4 1` | `64` |
| normal | `100 2` | `2000000` |
| large | `200 2` | `16000000` |


## vector-rev-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-rev.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-rev.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

Stephen Weeks. Preserve pair elements, regeneration inside every iteration
and two reversal allocations. The original counter condition k<0 means
initial trials+1 executions, retained explicitly. Large preserves upstream
length/counter. Complete indexed validation and IntInf result accumulation
replace the head-only or aggregate-only observation. Fixtures follow the
independent ordered-sequence sum. These representation/lifetime variants
remain distinct from each other and MLton fixed-width vectors.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags vectors,allocation,representation
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `240` |
| normal | `10000 10` | `1099890000` |
| large | `10000 10000` | `999999990000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `240` |
| normal | `10000 10` | `1099890000` |
| large | `10000 10000` | `999999990000` |


## vector-rev_smlnj

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-rev_smlnj.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-rev_smlnj.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

Stephen Weeks. Preserve integer elements, one retained input outside the loop
and two reversal allocations. The original counter condition k<0 means
initial trials+1 executions, retained explicitly. Large preserves upstream
length/counter. Complete indexed validation and IntInf result accumulation
replace the head-only or aggregate-only observation. Fixtures follow the
independent ordered-sequence sum. These representation/lifetime variants
remain distinct from each other and MLton fixed-width vectors.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags vectors,allocation,representation
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `120` |
| normal | `10000 10` | `549945000` |
| large | `10000 10000` | `499999995000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `120` |
| normal | `10000 10` | `549945000` |
| large | `10000 10000` | `499999995000` |


## vector-concat

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-concat.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-concat.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

Stephen Weeks. Preserve pair elements, regeneration inside every iteration
and concatenation of two copies. The original counter condition k<0 means
initial trials+1 executions, retained explicitly. Large preserves upstream
length/counter. Complete indexed validation and IntInf result accumulation
replace the head-only or aggregate-only observation. Fixtures follow the
independent ordered-sequence sum. These representation/lifetime variants
remain distinct from each other and MLton fixed-width vectors.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags vectors,allocation,representation
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `480` |
| normal | `100 100` | `1999800` |
| large | `100 10000` | `198019800` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `480` |
| normal | `100 100` | `1999800` |
| large | `100 10000` | `198019800` |


## vector-concat_smlnj

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-concat_smlnj.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/vector-concat_smlnj.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.

Stephen Weeks. Preserve integer elements, one retained input outside the loop
and concatenation of two copies. The original counter condition k<0 means
initial trials+1 executions, retained explicitly. Large preserves upstream
length/counter. Complete indexed validation and IntInf result accumulation
replace the head-only or aggregate-only observation. Fixtures follow the
independent ordered-sequence sum. These representation/lifetime variants
remain distinct from each other and MLton fixed-width vectors.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags vectors,allocation,representation
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `240` |
| normal | `1000 100` | `100899000` |
| large | `1000 100000` | `99900999000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `16 0` | `240` |
| normal | `1000 100` | `100899000` |
| large | `1000 100000` | `99900999000` |


## peek-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/peek.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/peek_smlnj.sml`. Their pristine sources are retained.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/peek.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/peek_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks. Keep the generative-exception property list with one integer
entry, regenerated for each outer iteration. Large preserves ten million
lookups five times. MLton tests mixed widths and deeper lists; this variant
requires no Int64 and is portable on Poly/ML. Inner sums fit 31 bits; outer
checksums use IntInf. Independent arithmetic gives 13*lookups*repetitions.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags exceptions,closures,lookup
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `1300` |
| normal | `100000 5` | `6500000` |
| large | `10000000 5` | `650000000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 1` | `1300` |
| normal | `100000 5` | `6500000` |
| large | `10000000 5` | `650000000` |


## wc-input1-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/wc-input1.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/wc-input1_smlnj.sml`. Their pristine sources are retained.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/wc-input1.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/wc-input1_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks. Keep the million-byte newline-every-ten distribution and
twenty scans in large. Generate once per call, scan the same file repeatedly,
then delete it. Replace the random temporary name by fixed input.txt in
the fresh working directory. Retain input1 traversal and explicit close.
Suppress console reporting and consume every actual count; ceil(bytes/10)
is the independent fixture formula. No upstream input file is needed.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags io,bytes,streams
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 5` | `50000` |
| large | `1000000 20` | `2000000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 5` | `50000` |
| large | `1000000 20` | `2000000` |


## wc-scanStream-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/wc-scanStream.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/wc-scanStream_smlnj.sml`. Their pristine sources are retained.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/wc-scanStream.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/wc-scanStream_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks. Keep the million-byte newline-every-ten distribution and
twenty scans in large. Generate once per call, scan the same file repeatedly,
then delete it. Replace the random temporary name by fixed input.txt in
the fresh working directory. Retain scanStream returning NONE and closing at EOF; a driver ref observes its count.
Suppress console reporting and consume every actual count; ceil(bytes/10)
is the independent fixture formula. No upstream input file is needed.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags io,bytes,streams
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 5` | `50000` |
| large | `1000000 20` | `2000000` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 1` | `100` |
| normal | `100000 5` | `50000` |
| large | `1000000 20` | `2000000` |


## psdes-random-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/psdes-random.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/psdes-random_smlnj.sml`. Their pristine sources are retained.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/psdes-random.sml`.
Pristine source, adaptation patch and aggregate ML Kit/GPL/SML-NJ notices
are retained; inspect individual headers for attribution rather than assigning
all aggregate licenses to every component.
Exact entrypoint aliases sharing this implementation: `test/psdes-random_smlnj.sml`. Their pristine sources are retained.

Stephen Weeks, following Numerical Recipes in C page 302. Preserve four
Word32 rounds, lookup arrays, seeds 13/14 and alternating half outputs. Add
an explicit reset at each driver call so repeated execution agrees with a
fresh process; do not recreate the constant lookup arrays each repetition.
Large keeps ten million outputs and its upstream EAD56832 fixture. Smaller
fixtures use an independent integer-modular Python implementation.

Selected profiles and exact expected results are recorded below. All results
are consumed and validated by the portable driver. Diagnostic tags word32,arithmetic,mutation
are source-based hypotheses, not measured causal findings. See the
[ML Kit and classic SML literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100` | `1E220B3` |
| normal | `100000` | `96543236` |
| large | `10000000` | `EAD56832` |

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100` | `1E220B3` |
| normal | `100000` | `96543236` |
| large | `10000000` | `EAD56832` |

## safe-for-space

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/safe-for-space`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

John Reppy 2020; based on Zhong Shao and Andrew Appel,
[Efficient and Safe-for-Space Closure Conversion](https://doi.org/10.1145/345099.345125),
TOPLAS 22(1), 2000. Keep strict big-list creation and all nested g/h/i
functions, retaining every h before observing it. Parameterize the big-list
length and outer count; large preserves 10000/100000. Invoke each h/i to
validate (3,list-size), whose sum is independently derived. Additional
observation work is measured. Closure capture/lifetime is a diagnostic
question; successful output alone does not prove space safety.

All selected profiles retain meaningful source parameters; diagnostics closures,retention,allocation
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).


Additional source review is recorded in [provenance](safe-for-space/PROVENANCE.md).

## pidigits-smlnj

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/pidigits`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Copyright 2026 Fellowship of SML/NJ. Preserve the linear-fractional
IntInf spigot and original nonmemoized Stream.unfold/map combinators. The
consumer forces exactly the requested digits; no sharing/memoization is
introduced. Unlike old MLton pidigits, stopping counts digits rather than
zero occurrences. Normal 100 digits fits Rune; large retains original 2000.
Capture all digits and omit human column formatting. Independent Chudnovsky
fixtures are shared with the separately named iterative version.

All selected profiles retain meaningful source parameters; diagnostics intinf,streams,arithmetic
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).


Additional source review is recorded in [provenance](pidigits-smlnj/PROVENANCE.md).

## fft-smlnj

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/fft`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Copyright 2024 Fellowship of SML/NJ, alias fft64. Preserve the
analytical input, radix-two transform, and doubling sweep beginning at 16.
Large retains 21 levels, ending at 16777216 points. Replace optional
Real64Array/Real64 names by RealArray/Real guarded at radix 2/precision 53.
Return and validate the measured maximum residual against the analytical
ramp; absolute bound 1e-8*n follows the reviewed classic FFT checker.
Suppress progress printing. This bound is benchmark-specific and failed
residuals cannot become timings.

All selected profiles retain meaningful source parameters; diagnostics numerical,arrays,fft
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).


Additional source review is recorded in [provenance](fft-smlnj/PROVENANCE.md).

## nucleic-smlnj

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/nucleic`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Marc Feeley's Scheme-origin Pseudoknot, ported by the May 1994 Dagstuhl
workshop group. Retain the modern SML/NJ anticodon search, molecular
coordinates, constraints, queue and Math.atan2. This variant counts
anticodon solutions; old MLton nucleic reports a maximum atom distance.
Every returned count is consumed. Large preserves 5000 searches. Golden
count comes from the unmodified upstream Nucleic implementation on MLton
and SML/NJ, reviewed before committing. See the Hartel et al. Pseudoknot
paper in the literature survey.

All selected profiles retain meaningful source parameters; diagnostics numerical,search,geometry
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).


Additional source review is recorded in [provenance](nucleic-smlnj/PROVENANCE.md).

## count-graphs-smlnj

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/count-graphs`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Henry Cejtin, modernized by John Reppy. Preserve higher-order
permutation/subset/graph folds, class pruning and mutable vertex caches.
Each f(maximum) counts classes at every size <=maximum satisfying
3*V-4-2*E=0 and its induced-subgraph sparsity condition; it is not a count
of all graphs of exactly the requested size. Preserve the original
0..11 sweep repeated three times in large; selected normal sweep ends at 6.
Return every sweep value instead of discard/progress output. Golden
values come from the unchanged upstream f on two native hosts.

All selected profiles retain meaningful source parameters; diagnostics graphs,higher-order,search
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).

Additional source review is recorded in [provenance](count-graphs-smlnj/PROVENANCE.md).

## matrix-multiply-ramp

MLton b15e2d289c3d701131733665a74e2dd8438410b6, `benchmark/tests/matrix-multiply.sml`.
Source notice in LICENSE; original and adaptation patch are retained.

Stephen Weeks. Retains Array2 multiplication and dot-product traversal.
Large preserves dimension 500. Every entry is checked against the independent
closed form n*i*j+(i+j)*sum(k)+sum(k*k). The total uses IntInf for narrow
hosts. These inputs produce exactly representable integral doubles.

This is a supplemental ramp-input diagnostic, not the source-faithful
all-ones workload. It was the original suite adaptation; the unsuffixed
benchmark now restores the original distribution. Both use BenchMatrix.

Additional source review is recorded in [provenance](matrix-multiply-ramp/PROVENANCE.md).

## kitreynolds2_no_basislib

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/kitreynolds2_no_basislib.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Preserve the custom list helpers and shared subtree construction. The search carries a chain of ancestor predicates.
Replace primitive mini-Basis string/equality/printing helpers with equivalent
SML97 operations, removing only unused primitive declarations. The original
depth is 20. Unlike the standard-Basis variant, its original main
selects this depth once. All path labels strictly decrease, independently
proving that the observed result is false. No memoization is introduced.

Diagnostic tags closures,sharing,allocation are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](kitreynolds2_no_basislib/PROVENANCE.md).

## kitreynolds3_no_basislib

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/kitreynolds3_no_basislib.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Preserve the custom list helpers and shared subtree construction. The search carries explicit ancestor lists.
Replace primitive mini-Basis string/equality/printing helpers with equivalent
SML97 operations, removing only unused primitive declarations. The original
depth is 10. Unlike the standard-Basis variant, its original main
selects this depth once. All path labels strictly decrease, independently
proving that the observed result is false. No memoization is introduced.

Diagnostic tags closures,sharing,allocation are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](kitreynolds3_no_basislib/PROVENANCE.md).

## kittmergesort_no_basislib

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/kittmergesort_no_basislib.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Preserve copying mergesort and the integer 167/mod2147 seed-1 generator.
The no-Basis source selects 25000 elements, while the canonical file selects
100000; the algorithm/generator are byte-equivalent after mini-Basis
replacement and are shared in BenchKittSort. Full sorted-element validation
and independently generated fixtures replace console progress output.
Normal retains 25000; large selects 100000.

Diagnostic tags sorting,copying,lists are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](kittmergesort_no_basislib/PROVENANCE.md).

## hanoi

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/hanoi.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Keep the original recursive calls and move ordering, and normal ten-disk
input. Replace primitive printing by a deterministic captured trace. Validate
every move against three explicit towers and the final target tower; this
additional checking work is measured. Independent iterative Gray-code disk
selection supplies count and complete-trace checksum fixtures. No disk
representation or stopping condition changes; source printing becomes
in-memory capture and fixed result output.

Diagnostic tags recursion,trace,mutation are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](hanoi/PROVENANCE.md).

## fib-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/fib.sml`.
Individual source headers, original bytes, adaptation patch and aggregate
ML Kit/GPL/SML-NJ notices are retained.

Retain both base cases returning one, x-2 before x-1 evaluation, and the
per-call numeric trace. Normal preserves original n=10. Replace primitive
printing by in-memory capture, including Before/After lines; this is a
trace-producing variant, not the pure MLton Fibonacci kernel. Independent
recursive trace generation and iterative Fibonacci values supply fixtures.

Diagnostic tags recursion,trace,allocation are source-based hypotheses. No causal performance
finding is asserted. See [the classic/ML Kit literature](../literature.md).

Additional source review is recorded in [provenance](fib-mlkit/PROVENANCE.md).

## mandelbrot-smlnj

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mandelbrot`.
Source/individual headers, notice and adaptation patch are retained.

Retain corrected x_base+delta*j coordinates, initial z=c, ordinary
binary64 iteration, 1024 escape limit, actual iteration sum and default
2048-square grid. This is materially different from the old MLton/ML Kit
multiplication coordinate. Parameterize only dimension and recompute delta
for that dimension. Smoke/normal select 16/128; large preserves 2048.
Independent native upstream execution supplies fixtures; selected sums fit
32-bit signed arithmetic. Floating equality at escape boundaries is checked
against both MLton and SML/NJ before accepting the exact iteration count.

Diagnostic questions concern numerical representation, branching and loop
allocation. These are source-based hypotheses; see [the literature](../literature.md).


Additional source review is recorded in [provenance](mandelbrot-smlnj/PROVENANCE.md).

## mandelbrot-rat

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mandelbrot-rat`.
Source/individual headers, notice and adaptation patch are retained.

Retain the original rational numerator/denominator arithmetic, gcd, signed
shift-by-four truncation at 0x7FFFFFFF, corrected coordinates, 512 escape
limit and default 256-square image. Original intermediates require signed
63-bit arithmetic. Int63 emulates that range and Overflow in portable
IntInf, including counters, without depending on optional Int64. This
carrier changes allocation and is explicitly a translation decision.
Arithmetic right shift is IntInf.~>>, equivalent within the original range.
Fixtures are obtained from the original signed-63-bit SML/NJ computation.
Normal selects 32 square; large preserves 256. No exact-rational substitute
removes the original lossy truncation.

Diagnostic questions concern numerical representation, branching and loop
allocation. These are source-based hypotheses; see [the literature](../literature.md).


Additional source review is recorded in [provenance](mandelbrot-rat/PROVENANCE.md).

## kitmandelbrot

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitmandelbrot.sml`.
Source/individual headers, notice and adaptation patch are retained.

Preserve the legacy multiplication coordinate x_base*(delta+j), initial
z=c, 1024 escape cap and pixel-count observation. The source increments
its sum by one rather than escape count; its old comment claiming 1084512
is stale for size 2048. Record both actual pixels and actual escape-step
sum so unused count computation cannot vanish from the validated workload.
This additional observation is documented measured work. Large preserves
three original 2048-square calls. Independent binary64 iteration supplies
fixtures for the old coordinate rule; modern SML/NJ uses addition instead.

Diagnostic questions concern numerical representation, branching and loop
allocation. These are source-based hypotheses; see [the literature](../literature.md).

Additional source review is recorded in [provenance](kitmandelbrot/PROVENANCE.md).

## FuhMishra

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/FuhMishra.mlb`.
Pristine sources, observed source notices and adaptation patch are retained.

Mads's 1997 ML Kit port of the MATCH/TYPE subtyping checker from Fuh and
Mishra. Retain list-based sets, constraint generation/matching, type-variable
counter reset and all six original expressions/environment. Load lib.sml
before the application as the original project does. Move top-level six
invocations to a repeated portable driver and suppress progress printing.
Every byte of each generated TYPE/MATCH report is checked against the
unmodified upstream program's reviewed native output. File generation and
validation are measured work. No new type-inference/runtime feature is
introduced to Rune by this benchmark.

Diagnostic questions are hypotheses until measured. See the
[classic SML literature](../literature.md).


Additional source review is recorded in [provenance](FuhMishra/PROVENANCE.md).

## black-scholes

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/black-scholes`.
Pristine sources, observed source notices and adaptation patch are retained.

Damon Wang's Manticore-origin SML port; Fellowship of SML/NJ 2025.
Preserve the original normal-CDF polynomial, option record/list distribution,
pricing operations and residual-returning price function. Large preserves
65536 records replicated 32 times with ten passes. Normal uses all 4096
upstream small records; smoke selects its first sixteen. Data loading and
replication move inside the measured driver and are explicit additional
work relative to upstream preload. Every result is checked against the
embedded DerivaGem reference using 1e-6 + 7.5e-8*(spot+discounted strike),
derived from the source's Abramowitz-Stegun CDF approximation bound.
The original dataset bytes and embedded reference values are retained.
No separate dataset license/origin is stated in its headers; this remains
an explicit provenance lookup, not an assertion that the program notice
covers the dataset.

Diagnostic questions are hypotheses until measured. See the
[classic SML literature](../literature.md).

Additional source review is recorded in [provenance](black-scholes/PROVENANCE.md).

## professor2

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/professor2.sml`.
Niels Hallenberg, 27 December 1995. Original source/header, aggregate notice
and adaptation patch are retained.

Keep the original sixteen fixed jacket/trouser cards, order, list copying,
row-major placement and matching search. Replace primitive mini-Basis
operations by SML97 where present, and suppress console/debug logging.
Enumerate every returned board, including duplicate-valued tile instances.
Validate each board's tile multiset and every horizontal/vertical pair using
an independent colour/parity coding, then consume an order-independent
Word32 checksum of every complete board. This is additional checking work.
Normal preserves one complete search; large repeats four for scaling.
Source variants retain their custom list/helper organization rather than
assuming equivalence from names. Legacy optional profiling primitive names
are adapters, not added runtime facilities. The debug source's stray final
comment closer is outside the retained kernel. Search, copying and lifetime
are hypotheses; see [the ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](professor2/PROVENANCE.md).

## professor2_tp

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/professor2_tp.sml`.
Niels Hallenberg, 27 December 1995. Original source/header, aggregate notice
and adaptation patch are retained.

Keep the original sixteen fixed jacket/trouser cards, order, list copying,
row-major placement and matching search. Replace primitive mini-Basis
operations by SML97 where present, and suppress console/debug logging.
Enumerate every returned board, including duplicate-valued tile instances.
Validate each board's tile multiset and every horizontal/vertical pair using
an independent colour/parity coding, then consume an order-independent
Word32 checksum of every complete board. This is additional checking work.
Large preserves eight complete searches.
Source variants retain their custom list/helper organization rather than
assuming equivalence from names. Legacy optional profiling primitive names
are adapters, not added runtime facilities. The debug source's stray final
comment closer is outside the retained kernel. Search, copying and lifetime
are hypotheses; see [the ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](professor2_tp/PROVENANCE.md).

## professor_game

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/professor_game.sml`.
Niels Hallenberg, 27 December 1995. Original source/header, aggregate notice
and adaptation patch are retained.

Keep the original sixteen fixed jacket/trouser cards, order, list copying,
row-major placement and matching search. Replace primitive mini-Basis
operations by SML97 where present, and suppress console/debug logging.
Enumerate every returned board, including duplicate-valued tile instances.
Validate each board's tile multiset and every horizontal/vertical pair using
an independent colour/parity coding, then consume an order-independent
Word32 checksum of every complete board. This is additional checking work.
Normal preserves one complete search; large repeats four for scaling.
Source variants retain their custom list/helper organization rather than
assuming equivalence from names. Legacy optional profiling primitive names
are adapters, not added runtime facilities. The debug source's stray final
comment closer is outside the retained kernel. Search, copying and lifetime
are hypotheses; see [the ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](professor_game/PROVENANCE.md).

## professor_game-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/professor_game.sml`.
Niels Hallenberg, 27 December 1995. Original source/header, aggregate notice
and adaptation patch are retained.

Keep the original sixteen fixed jacket/trouser cards, order, list copying,
row-major placement and matching search. Replace primitive mini-Basis
operations by SML97 where present, and suppress console/debug logging.
Enumerate every returned board, including duplicate-valued tile instances.
Validate each board's tile multiset and every horizontal/vertical pair using
an independent colour/parity coding, then consume an order-independent
Word32 checksum of every complete board. This is additional checking work.
Normal preserves one complete search; large repeats four for scaling.
Source variants retain their custom list/helper organization rather than
assuming equivalence from names. Legacy optional profiling primitive names
are adapters, not added runtime facilities. The debug source's stray final
comment closer is outside the retained kernel. Search, copying and lifetime
are hypotheses; see [the ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](professor_game-mlkit/PROVENANCE.md).

## professor_game_debug

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/professor_game_debug.sml`.
Niels Hallenberg, 27 December 1995. Original source/header, aggregate notice
and adaptation patch are retained.

Keep the original sixteen fixed jacket/trouser cards, order, list copying,
row-major placement and matching search. Replace primitive mini-Basis
operations by SML97 where present, and suppress console/debug logging.
Retain first-success exception DONE, observing that exact first board.
Validate each board's tile multiset and every horizontal/vertical pair using
an independent colour/parity coding, then consume an order-independent
Word32 checksum of every complete board. This is additional checking work.
Normal preserves one complete search; large repeats four for scaling.
Source variants retain their custom list/helper organization rather than
assuming equivalence from names. Legacy optional profiling primitive names
are adapters, not added runtime facilities. The debug source's stray final
comment closer is outside the retained kernel. Search, copying and lifetime
are hypotheses; see [the ML Kit literature](../literature.md).


Additional source review is recorded in [provenance](professor_game_debug/PROVENANCE.md).

## kkb_eq

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kkb_eq.sml`.
Individual headers and aggregate notice are retained with the pristine
source and patch.

Keep geometric Knuth-Bendix equations, ordering, typed equality where
present, recursive tuple argument shape, copied terms/rules and the
source's one-step tail-recursion batching. This equality variant contains no active region-control call.
Wrap the outer let/local declarations to expose one completion. Capture
the complete actual diagnostic/canonical-rule trace instead of console
printing; every byte influences the fixed Word32 summary. Normal preserves
three completions; smoke selects one, large ten. Golden traces are
reviewed native executions of this unchanged algorithm on MLton/SML/NJ,
with separate independent equation/rule checks in the classic KB tests.
No prerequisite compiler/runtime feature is added. Copying, lifetime and
argument shape are hypotheses; see [ML Kit/rewriting literature](../literature.md).


Additional source review is recorded in [provenance](kkb_eq/PROVENANCE.md).

## kitkbjul9_smlnj

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitkbjul9_smlnj.sml`.
Individual headers and aggregate notice are retained with the pristine
source and patch.

Keep geometric Knuth-Bendix equations, ordering, typed equality where
present, recursive tuple argument shape, copied terms/rules and the
source's one-step tail-recursion batching. The upstream region functions are already no-ops and are retained.
Wrap the outer let/local declarations to expose one completion. Capture
the complete actual diagnostic/canonical-rule trace instead of console
printing; every byte influences the fixed Word32 summary. Normal preserves
three completions; smoke selects one, large ten. Golden traces are
reviewed native executions of this unchanged algorithm on MLton/SML/NJ,
with separate independent equation/rule checks in the classic KB tests.
No prerequisite compiler/runtime feature is added. Copying, lifetime and
argument shape are hypotheses; see [ML Kit/rewriting literature](../literature.md).


Additional source review is recorded in [provenance](kitkbjul9_smlnj/PROVENANCE.md).

## kkb36c_smlnj

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kkb36c_smlnj.sml`.
Individual headers and aggregate notice are retained with the pristine
source and patch.

Keep geometric Knuth-Bendix equations, ordering, typed equality where
present, recursive tuple argument shape, copied terms/rules and the
source's one-step tail-recursion batching. The upstream region functions are already no-ops and are retained.
Wrap the outer let/local declarations to expose one completion. Capture
the complete actual diagnostic/canonical-rule trace instead of console
printing; every byte influences the fixed Word32 summary. Normal preserves
three completions; smoke selects one, large ten. Golden traces are
reviewed native executions of this unchanged algorithm on MLton/SML/NJ,
with separate independent equation/rule checks in the classic KB tests.
No prerequisite compiler/runtime feature is added. Copying, lifetime and
argument shape are hypotheses; see [ML Kit/rewriting literature](../literature.md).

Additional source review is recorded in [provenance](kkb36c_smlnj/PROVENANCE.md).

## ratio-regions-mlkit

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/ratio-regions.sml`.
Original/headers, aggregate notice and adaptation patch are retained.

Jeff Siskind's ratio-region reduction, tracing Cox/Rao/Zhong, Blicher,
Goldberg and Roy. Preserve the preflow-push algorithm, relabel/scheduling
heuristics, fixed synthetic central-square capacities and complete min-cut
array. Parameterize only grid side/repetitions, suppress diagnostics and
check every mask cell against the independently known central square.
Large keeps upstream side 64 and 1 calls; the four-call _tp
variant remains separately named. Ordinary integer operations stay in
range for selected dimensions; no flow/capacity representation changes.

Diagnostic explanations remain source-based hypotheses, not measured
causes. See [the source-family literature](../literature.md).


Additional source review is recorded in [provenance](ratio-regions-mlkit/PROVENANCE.md).

## ratio-regions_tp

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/ratio-regions_tp.sml`.
Original/headers, aggregate notice and adaptation patch are retained.

Jeff Siskind's ratio-region reduction, tracing Cox/Rao/Zhong, Blicher,
Goldberg and Roy. Preserve the preflow-push algorithm, relabel/scheduling
heuristics, fixed synthetic central-square capacities and complete min-cut
array. Parameterize only grid side/repetitions, suppress diagnostics and
check every mask cell against the independently known central square.
Large keeps upstream side 64 and 4 calls; the four-call _tp
variant remains separately named. Ordinary integer operations stay in
range for selected dimensions; no flow/capacity representation changes.

Diagnostic explanations remain source-based hypotheses, not measured
causes. See [the source-family literature](../literature.md).


Additional source review is recorded in [provenance](ratio-regions_tp/PROVENANCE.md).

## ratio-regions-smlnj

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/ratio-regions`.
Original/headers, aggregate notice and adaptation patch are retained.

Jeff Siskind's ratio-region reduction, tracing Cox/Rao/Zhong, Blicher,
Goldberg and Roy. Preserve the preflow-push algorithm, relabel/scheduling
heuristics, fixed synthetic central-square capacities and complete min-cut
array. Parameterize only grid side/repetitions, suppress diagnostics and
check every mask cell against the independently known central square.
Large keeps upstream side 500 and 1 calls; the four-call _tp
variant remains separately named. Ordinary integer operations stay in
range for selected dimensions; no flow/capacity representation changes.

Diagnostic explanations remain source-based hypotheses, not measured
causes. See [the source-family literature](../literature.md).


Additional source review is recorded in [provenance](ratio-regions-smlnj/PROVENANCE.md).

## count-graphs-mlkit

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/count-graphs.sml`.
Original/headers, aggregate notice and adaptation patch are retained.

Henry Cejtin's original higher-order sparse graph folds. Preserve the
subset/permutation iteration, graph criterion, class pruning and mutable
cache implementation. Large retains 0..9 repeated ten times rather than
modern SML/NJ's 0..11 three times. f is cumulative up to its argument:
3*V-4-2*E=0 with induced-subgraph sparsity, not all graphs at exactly n.
Consume the complete count sequence; unmodified native SML/NJ/MLton
references and the two-vertex edge/four-cycle proof supply fixtures.

Diagnostic explanations remain source-based hypotheses, not measured
causes. See [the source-family literature](../literature.md).

Additional source review is recorded in [provenance](count-graphs-mlkit/PROVENANCE.md).

## mpuz-mlkit

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/mpuz.sml`.
Stephen Weeks, 1999-08-31, loosely based on Laurent Vaucher's OCaml solution.
Source/header, notice and adaptation patch are retained.

Keep the fixed AGH/FB/CBEE/GHFD/FGIJE multiplication puzzle, all distinct-digit
assignments including zero, mutable usage flags and tuple-based List/String
adapters. These differ from the modern MLton helper interfaces. Replace the
silent print override by complete deterministic capture of actual solution
assignments; no invented success marker is accepted. One original solve is
normal; large selects ten repeats. The captured assignment stream is checked
against the original native solver and the source's known assignment.
Search, tuple calls and allocation are hypotheses; see the classic literature.

Additional source review is recorded in [provenance](mpuz-mlkit/PROVENANCE.md).

## knuth-bendix-smlnj

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/knuth-bendix`.
All source modules/notices and adaptation patch are retained.

Modern SML/NJ direct Knuth-Bendix completion. Preserve the geometric
equations, recursive path ordering, term structures, rule queues and
exception-driven rewrites. Retain 300 completions in large; normal selects
three. Capture actual computed rule/diagnostic output instead of console
logging. Unlike the ML Kit copying variants, this retains the direct
completion argument/exception organization.

Complete computed traces influence a Word32 checksum; empty output fails.
No measured causal attribution is claimed. See the rewriting/Geobucket
references in [the literature](../literature.md).


Additional source review is recorded in [provenance](knuth-bendix-smlnj/PROVENANCE.md).

## tyan-smlnj

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/tyan`.
All source modules/notices and adaptation patch are retained.

Thomas Yan's F17 Geobucket polynomial calculation, modern SML/NJ
modular version. Preserve field arithmetic, monomial/trie representations,
heap-polynomial operations, auto-reduction and cyclic-u6 input. Source
headers credit the modern Fellowship version; historical authorship is
shared with the classic TIL-derived variants. Keep maxDeg=1000000 and
192 calls in large. Suppress progress; consume every computed leading
monomial and term count. Do not replace F17 by rational arithmetic.

Complete computed traces influence a Word32 checksum; empty output fails.
No measured causal attribution is claimed. See the rewriting/Geobucket
references in [the literature](../literature.md).


Additional source review is recorded in [provenance](tyan-smlnj/PROVENANCE.md).

## tyan-mlkit

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/tyan.sml`.
All source modules/notices and adaptation patch are retained.

Thomas Yan; TIL adaptation by Allyn Dimock, hardwired input/driver
by Stephen Weeks in 2001. Retain this older array/polynomial helper
organization and original two-call normal profile, distinct from weeks4
and the modern modular SML/NJ variant. Keep F17, cyclic-u6 strings and
actual leading-term/term-count output. Suppress only progress prints;
large selects twenty calls. Source explicitly records benchmark permission
from Thomas Yan; the original notice is retained.

Complete computed traces influence a Word32 checksum; empty output fails.
No measured causal attribution is claimed. See the rewriting/Geobucket
references in [the literature](../literature.md).

Additional source review is recorded in [provenance](tyan-mlkit/PROVENANCE.md).

## smith-normal-form-mlkit

Reduce the original dimension-32 IntInf matrix to Smith normal form. See [provenance](smith-normal-form-mlkit/PROVENANCE.md) and retained originals/patch.

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/smith-normal-form.sml`.
Henry Cejtin. Original modules/individual headers, aggregate notice and patch
are retained.

Keep the source matrix abstraction, arbitrary-precision Euclidean row/column
operations and the complete original integer table. Parameterize its selected
leading dimension, check every off-diagonal zero and consume every actual
signed diagonal entry. Large preserves dimension 32 and 1 calls.
Fixtures are reviewed native original reductions. Their absolute diagonal
product agrees with independent fraction-free Bareiss determinants; gcd-one
cofactor witnesses and diagonal divisibility verify the invariant factors.
Signed factors preserve the original reduction output.
The MLton source instead selects dimension 35. IntInf is never replaced
by machine arithmetic. Allocation/representation are source hypotheses,
not measured causes; see [arithmetic literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4 1` | `1,~1,1,~7506` |
| normal | `12 1` | `1,1,~1,1,~1,~1,~1,~1,1,1,1,~6096777698704` |
| large | `32 1` | `1,~1,~1,1,1,1,~1,~1,1,~1,1,~1,~1,~1,~1,1,1,~1,1,~1,1,~1,~1,~1,~1,~1,1,1,1,~1,~1,~8074709755269798283190497453463562613129` |

## smith-nf

Reduce the modern SML/NJ dimension-33 IntInf matrix to Smith normal form. See [provenance](smith-nf/PROVENANCE.md) and retained originals/patch.

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/smith-nf`.
Henry Cejtin. Original modules/individual headers, aggregate notice and patch
are retained.

Keep the source matrix abstraction, arbitrary-precision Euclidean row/column
operations and the complete original integer table. Parameterize its selected
leading dimension, check every off-diagonal zero and consume every actual
signed diagonal entry. Large preserves dimension 33 and 5 calls.
Fixtures are reviewed native original reductions. Their absolute diagonal
product agrees with independent fraction-free Bareiss determinants; gcd-one
cofactor witnesses and diagonal divisibility verify the invariant factors.
Signed factors preserve the original reduction output.
The MLton source instead selects dimension 35. IntInf is never replaced
by machine arithmetic. Allocation/representation are source hypotheses,
not measured causes; see [arithmetic literature](../literature.md).

The upstream dimension-33 Main expected literal is stale: it gives
`~1027954043102083189860753402541358641712697245`, while its actual
table/reduction gives `~174455975010120216862039859605035043439271`.
The independent determinant and cofactor check support the latter. The
full signed diagonal is retained rather than copying the stale literal.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `4 1` | `1,~1,1,~7506` |
| normal | `12 1` | `1,1,~1,1,~1,~1,~1,~1,1,1,1,~6096777698704` |
| large | `33 5` | `1,~1,~1,1,1,1,~1,~1,1,~1,1,~1,~1,~1,~1,1,1,~1,1,~1,1,~1,~1,~1,~1,~1,1,1,1,~1,~1,~1,~174455975010120216862039859605035043439271;1,~1,~1,1,1,1,~1,~1,1,~1,1,~1,~1,~1,~1,1,1,~1,1,~1,1,~1,~1,~1,~1,~1,1,1,1,~1,~1,~1,~174455975010120216862039859605035043439271;1,~1,~1,1,1,1,~1,~1,1,~1,1,~1,~1,~1,~1,1,1,~1,1,~1,1,~1,~1,~1,~1,~1,1,1,1,~1,~1,~1,~174455975010120216862039859605035043439271;1,~1,~1,1,1,1,~1,~1,1,~1,1,~1,~1,~1,~1,1,1,~1,1,~1,1,~1,~1,~1,~1,~1,1,1,1,~1,~1,~1,~174455975010120216862039859605035043439271;1,~1,~1,1,1,1,~1,~1,1,~1,1,~1,~1,~1,~1,1,1,~1,1,~1,1,~1,~1,~1,~1,~1,1,1,1,~1,~1,~1,~174455975010120216862039859605035043439271` |

## lexgen-smlnj

Generate a lexer from the modern SML/NJ ML-Lex specification and validate every byte. See [provenance](lexgen-smlnj/PROVENANCE.md) and retained originals/patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/lexgen`.
Original module order, individual headers/notices and adaptation patch are
retained.

James Mattson and David Tarditi's lexical generator. Retain its RedBlack
functor, DFA construction, rule processing and original Standard ML lexer
input. Modern module organization differs from the old MLton monolith.
Suppress console diagnostics; errors propagate. Move the original generator
invocation into the driver. Every generated source/signature byte is checked
against the reviewed native original output. Large preserves 500 calls;
normal selects two. Input origins and individual notices are retained in
the source headers/dataset. File generation/validation are measured work.
No compiler/runtime feature is added through this port. Diagnostic questions
are source-based; see [compiler literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `110723 B8C8AF8D` |
| normal | `2` | `110723 B8C8AF8D` |
| large | `500` | `110723 B8C8AF8D` |

## mlyacc-smlnj

Generate an LALR parser from the modern SML/NJ ML-Yacc grammar and validate both files. See [provenance](mlyacc-smlnj/PROVENANCE.md) and retained originals/patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mlyacc`.
Original module order, individual headers/notices and adaptation patch are
retained.

David Tarditi and Andrew Appel's parser-generator collection. Preserve
ordered parser/lexer, grammar, core, LALR lookahead, table construction,
compression and code generation modules, with the original Standard ML
grammar.
Suppress console diagnostics; errors propagate. Move the original generator
invocation into the driver. Every generated source/signature byte is checked
against the reviewed native original output. Large preserves 250 calls;
normal selects two. Input origins and individual notices are retained in
the source headers/dataset. File generation/validation are measured work.
No compiler/runtime feature is added through this port. Diagnostic questions
are source-based; see [compiler literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `3150 27A50FF4;111569 D6E21727` |
| normal | `2` | `3150 27A50FF4;111569 D6E21727` |
| large | `250` | `3150 27A50FF4;111569 D6E21727` |

## kitsimple

Compute a hydrodynamic time step using lists of references as arrays. See [provenance](kitsimple/PROVENANCE.md) and retained originals/patch.

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitsimple.sml`.
Original modules/headers, aggregate notice and adaptation patch are retained.

Preserve one hydrodynamic step, initial-state distribution, boundary handling
and every final velocity/position/pressure/density/energy array. This ML Kit variant uses lists of references as arrays; replacing them by
flat arrays would change its lifetime/traversal workload and is not done.
Move the simulation declarations into a parameterized compute scope; retain
original array representations. Suppress progress and validate every actual
state element against native reference output, abs 1e-8 plus rel 1e-7.
Normal selects a practical grid; large preserves the original dimension
and 1 calls. Input generation and full observation are measured work.
Representation/lifetimes/numerical cost are source hypotheses, not measured
causes; see [the classic/ML Kit literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `5 1 expected/smoke.txt` | `281` |
| normal | `10 1 expected/normal.txt` | `1106` |
| large | `30 1 expected/large.txt` | `9906` |

## kitsimple_tp

Repeat three hydrodynamic steps using the original list-reference array representation. See [provenance](kitsimple_tp/PROVENANCE.md) and retained originals/patch.

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitsimple_tp.sml`.
Original modules/headers, aggregate notice and adaptation patch are retained.

Preserve one hydrodynamic step, initial-state distribution, boundary handling
and every final velocity/position/pressure/density/energy array. This ML Kit variant uses lists of references as arrays; replacing them by
flat arrays would change its lifetime/traversal workload and is not done.
Move the simulation declarations into a parameterized compute scope; retain
original array representations. Suppress progress and validate every actual
state element against native reference output, abs 1e-8 plus rel 1e-7.
Normal selects a practical grid; large preserves the original dimension
and 3 calls. Input generation and full observation are measured work.
Representation/lifetimes/numerical cost are source hypotheses, not measured
causes; see [the classic/ML Kit literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `5 3 expected/smoke.txt` | `843` |
| normal | `10 3 expected/normal.txt` | `3318` |
| large | `30 3 expected/large.txt` | `29718` |

## kitsimple_no_basislib

Compute a hydrodynamic time step with the miniature Basis and list-reference arrays. See [provenance](kitsimple_no_basislib/PROVENANCE.md) and retained originals/patch.

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/kitsimple_no_basislib.sml`.
Original modules/headers, aggregate notice and adaptation patch are retained.

Preserve one hydrodynamic step, initial-state distribution, boundary handling
and every final velocity/position/pressure/density/energy array. This ML Kit variant uses lists of references as arrays; replacing them by
flat arrays would change its lifetime/traversal workload and is not done.
The miniature primitive Basis is mapped to equivalent SML97 Math/string/ref
operations, while retaining custom list/array operations and tan=sin/cos.
Move the simulation declarations into a parameterized compute scope; retain
original array representations. Suppress progress and validate every actual
state element against native reference output, abs 1e-8 plus rel 1e-7.
Normal selects a practical grid; large preserves the original dimension
and 1 calls. Input generation and full observation are measured work.
Representation/lifetimes/numerical cost are source hypotheses, not measured
causes; see [the classic/ML Kit literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `5 1 expected/smoke.txt` | `281` |
| normal | `10 1 expected/normal.txt` | `1106` |
| large | `30 1 expected/large.txt` | `9906` |

## simple-smlnj

Compute a hydrodynamic time step with modern SML/NJ flat arrays and validate all state. See [provenance](simple-smlnj/PROVENANCE.md) and retained originals/patch.

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/simple`.
Original modules/headers, aggregate notice and adaptation patch are retained.

Preserve one hydrodynamic step, initial-state distribution, boundary handling
and every final velocity/position/pressure/density/energy array. This modern SML/NJ variant uses its original flat custom Array2 and default
560 grid. The expectedDelta/C functor constants are output checks, not
inputs to the simulation; the full-state checker replaces them.
Move the simulation declarations into a parameterized compute scope; retain
original array representations. Suppress progress and validate every actual
state element against native reference output, abs 1e-8 plus rel 1e-7.
Normal selects a practical grid; large preserves the original dimension
and 1 calls. Input generation and full observation are measured work.
Representation/lifetimes/numerical cost are source hypotheses, not measured
causes; see [the classic/ML Kit literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `5 1 expected/smoke.txt` | `281` |
| normal | `30 1 expected/normal.txt` | `9906` |
| large | `560 1 expected/large.txt` | `3449606` |

## tsp-smlnj

Build a MINSTD-seeded spatial tree and validate every vertex and link of its tour. See [provenance](tsp-smlnj/PROVENANCE.md), original sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/tsp`.
AT&T Bell Laboratories, SML/NJ Fellowship. Preserve individual notices,
all ordered modules and original launcher.

Build a seeded two-dimensional spatial tree and construct a tour by
recursive division and conquest. Seed 314 restarts for each tree; threshold
150 is preserved for normal and large. The modern MINSTD generator uses
two word folds instead of the older Int32 quotient/remainder recurrence.
Use explicit Word64 to preserve its intermediate product on default-32-bit
hosts; Real64 becomes SML97 Real, requiring at least 53-bit precision.
Tree layout, construction order and tour linking are preserved. Suppress
progress, require cardinality and backlinks, compare complete coordinate
multisets before/after, and check tour length at abs 1e-8 plus rel 1e-8.
The standard SML left-to-right evaluation order is retained. Full observation
is included in measured execution. Large selects original 262143 vertices
and 25 calls; normal is the bounded 1023-vertex profile. Modern RNG, closure
and linking costs are source hypotheses, not measured causes. See the
[classic and numerical literature](../literature.md); upstream Rand cites
Park and Miller, CACM 31 (1988), 1192-1201, updated multiplier 48271.

SML/NJ 110.99.9 for 32 bits fails the recorded result checks. The seeded
Word64 generators are affected by its existing [64-bit literal/low-half
report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md) and
[shift report](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md).
A direct RNG comparison against compiled expected literals diverges from
the third draw. Agreement on earlier draws is weak evidence because this
host also miscompiles those literals; conversion/formatting loses bit 30. These
are host correctness failures, not additional valid numerical fixtures.
The portable source is preserved; those failed runs cannot supply timings.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `31 10 1 5.0285603627720601` | `31` |
| normal | `1023 150 1 34.594758416849281` | `1023` |
| large | `262143 150 25 540.82472201646453` | `6553575` |

## DLXSimulator-mlkit

Interpret the older DLX Simple program with direct I/O traps and immutable arrays. See [provenance](DLXSimulator-mlkit/PROVENANCE.md), original sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/DLXSimulator.sml`.
Matthew Thomas Fluet, Harvey Mudd College; Stephen Weeks benchmark driver,
Martin Elsman 2001 repetition adjustment. Individual source notices and
aggregate ML Kit notice are retained.

Simulate the DLX RISC instruction set with immutable register/memory arrays,
cache bookkeeping and decoding. This older version uses a three-component
PC/register/memory state and direct I/O instructions. The newer MLton version
carries a fourth trap state with general input/output callbacks and selects
five programs. Preserve the old simulator kernel and its Simple-only workload.
Smoke/normal/large run Simple 1/10/100 times; 100 is the original count.
The program loads hexadecimal 0x2F (decimal 47) into register 14, traps to output it and halts: review
its instructions and require every output line to equal `Output: 47`.
Legacy Word.fromLargeWord calls become Word.fromLarge(Word32.toLarge ...);
pre-SML97 string inputLine is explicitly unwrapped. Quiet statistics/progress
and capture actual trap output; unsupported input is not used by selected
programs. Preserve Word32 modular arithmetic and signed register interpretation.
Immutable-array/caching costs are source hypotheses, not measurements.
The individual header references Patterson and Hennessy, Computer Architecture:
A Quantitative Approach, second edition (1996); see [literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1` | `1 47` |
| normal | `10` | `10 47` |
| large | `100` | `100 47` |

## aobench

Render ambient occlusion by seeded hemisphere sampling against spheres and a plane. See [provenance](aobench/PROVENANCE.md), original sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/aobench`.
SML/NJ Fellowship; original headers, modules and aggregate notice retained.

Render ambient occlusion by sphere/plane ray intersections and 8x8 hemisphere
samples. The original C/SML algorithm is preserved, with one/one/three
subsamples in smoke/normal/large. Large preserves the upstream 512-square
three-subsample workload. Rand48 seed 0x1234abcd330e is reset per run to its
upstream initial state; otherwise repeated calls advance RNG demand. Replace
Unsafe.Real64.castFromWord by exact conversion of a 48-bit integer divided
by 2^48, the same binary64 value as the original bit construction. Explicit
Word64 preserves modular 48-bit state. Real64Array becomes SML97 RealArray.
The source draws randomness only on hits: preserve demand and draw order.
Every header, dimension, data length and actual quantized RGB channel is
validated against reviewed original MLton and separately loaded original SML/NJ
renders. Original separate-unit and concatenated SML/NJ normal frames differ at
one RGB pixel by 32 levels; the interactive frame agrees with MLton. An
earlier portable SML/NJ build differed at two pixels by 12/8 levels. Ten
thousand RNG draws using original bit construction versus portable numeric
conversion agreed exactly; this does not establish a cause for the image
sensitivity. Discrete hit-test boundaries are a source hypothesis. Every
whole RGB pixel must match one original reference pixel, with at most one level
per 8-bit channel for floating-point rounding at quantization boundaries;
this is a benchmark-specific output tolerance, not permission to change
geometry. Allocation/traversal/real-operation concerns are source hypotheses;
no measured attribution is claimed. See [rendering literature](../literature.md).

SML/NJ 110.99.9 for 32 bits fails the recorded result checks. The seeded
Word64 generators are affected by its existing [64-bit literal/low-half
report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md) and
[shift report](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md).
A direct RNG comparison against compiled expected literals diverges from
the third draw. Agreement on earlier draws is weak evidence because this
host also miscompiles those literals; conversion/formatting loses bit 30. These
are host correctness failures, not additional valid numerical fixtures.
The portable source is preserved; those failed runs cannot supply timings.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8 1 expected/smoke.ppm` | `64` |
| normal | `64 1 expected/normal.ppm` | `4096` |
| large | `512 3 expected/large.ppm` | `262144` |

## id-ray

Trace the Id/Manticore sphere scene with the original overlapping image writes. See [provenance](id-ray/PROVENANCE.md), original sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/id-ray`.
SML/NJ Fellowship; original headers, modules and aggregate notice retained.

Render the original fixed Id/Manticore scene with reflections, transparency,
shadows, lighting and recursive ray intersections. Preserve the original
custom image representation, including its source indexing `width*row+col`
for RGB writes (rather than `3*(width*row+col)`). This overlaps channel writes
and leaves the trailing two-thirds zero; it is a known upstream defect,
kept visible in the fixture rather than silently changing the workload.
The source also ignores its output filename and uses out.ppm. Large preserves
1024 square; smoke/normal are bounded 8/128-square renders. Sampling is not
used by this deterministic renderer; the adapter passes a documented 1.
Source comments identify a negative-vector limitation retained in the kernel.
Every header, dimension, data length and actual quantized RGB channel is
validated against reviewed native source renders. Permit at most one level
per 8-bit channel for floating-point rounding at quantization boundaries;
this is a benchmark-specific output tolerance, not permission to change
geometry. Allocation/traversal/real-operation concerns are source hypotheses;
no measured attribution is claimed. See [rendering literature](../literature.md).

The full original `DATA/spheres.txt` supplements the embedded test spheres;
no per-dataset notice or origin is given in the data, so its notice/origin
remains an explicit provenance gap. Scene loading at structure initialization
is included in fresh-process runs; repeated in-process calls reuse it.

SML/NJ 110.99.9 for 32 bits fails the normal image check; the cause has not
been isolated. Its documented [numeric host defects](../../../docs/bugreport/smlnj/README.md)
are relevant diagnostic candidates. Do not count this as a pass or widen
tolerances to accept an unreviewed output.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8 1 expected/smoke.ppm` | `64` |
| normal | `128 1 expected/normal.ppm` | `16384` |
| large | `1024 1 expected/large.ppm` | `1048576` |

## ray-smlnj

Interpret sphere scenes and validate every channel of the modern SML/NJ P6 image. See [provenance](ray-smlnj/PROVENANCE.md), original sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/ray`.
Individual module/data notices and aggregate notice are retained with the
ordered originals and patch.

Interpret the original fixed sphere scenes and shade every pixel. This
modern modular SML/NJ variant emits P6 RGB rather than the old Dump format.
Preserve scene parsing, sphere order, ray/camera distributions, lighting and
quantization. Add a dimension ref to the picture adapter and replace 512
coordinate/loop/header constants uniformly; smoke is the upstream three-
sphere test at 16 square, normal the nine-sphere benchmark at 128 square,
large the original 512-square scene and 500 repetitions. Only output paths
are changed in DATA copies; original data notices are retained.
Validate P6 headers, dimensions and every RGB channel against reviewed
native original renders, with at most one 8-bit level of rounding tolerance.
Result consumption and file output/validation are measured work. Algorithm,
real-operation, closure and allocation sensitivity are source hypotheses,
not established performance causes. See [literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `DATA/smoke.txt 16 1 expected/smoke.ppm` | `256` |
| normal | `DATA/normal.txt 128 1 expected/normal.ppm` | `16384` |
| large | `DATA/large.txt 512 500 expected/large.ppm` | `131072000` |

## plclub-ray

Interpret and render the ICFP chess scene using the modern modular SML/NJ port. See [provenance](plclub-ray/PROVENANCE.md), original sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/plclub-ray`.
Individual module/data notices and aggregate notice are retained with the
ordered originals and patch.

Modern modular SML port of the PLClub 2000 ICFP contest renderer, Stephen
Weeks original translation. Chess data by Leif Kornstaedt, 2000, with its
individual copyright header preserved. Same scene, recursive depth three,
60-degree view and 4:3 aspect; only image dimensions change for smoke/normal.
Large preserves 1024x768 and ten renders. Unsafe.Array calls become checked
SML97 Array calls. Preserve interpreter, geometric objects, CSG interval
ordering, matrix operations and mutable inline-closure/render callbacks.
Close scene input streams explicitly and propagate failures, unlike the
upstream catch-all launcher. Its missing DATA path separator is a launcher
error; fixed deterministic suite scene paths replace it. Numerical CSG
zero-width intervals can select different surfaces with host math rounding:
check every actual pixel against independently rendered MLton, Poly/ML and independent native SML/NJ
reference pixels, permitting at most two levels in all three channels of a
single reference pixel, as documented for the classic raytrace port.
Result consumption and file output/validation are measured work. Algorithm,
real-operation, closure and allocation sensitivity are source hypotheses,
not established performance causes. See [literature](../literature.md).

The SML/NJ fixture is generated by a separate render-only driver loading
shared support and the portable kernel as separate source units. At smoke
pixel 86, it produces RGB (136,136,97), while the concatenated native
reference produces (176,176,126). At pixel 108, original SML/NJ can produce
(100,100,70), while MLton/Poly produce (255,255,231). Both coherent outcomes
are retained from independent native reference contexts; no global tolerance
is widened. Earlier original-context frames are archived separately as
`expected/*-upstream-smlnj.ppm`. The compilation-context difference is
observed evidence; attribution to CSG zero-width intervals remains a
source-based explanation, not a measured compiler-cause claim.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `DATA/smoke.txt 16 1 expected/smoke.ppm expected/smoke-poly.ppm` | `192` |
| normal | `DATA/normal.txt 64 1 expected/normal.ppm expected/normal-poly.ppm` | `3072` |
| large | `DATA/large.txt 1024 10 expected/large.ppm expected/large-poly.ppm` | `7864320` |

## mc-ray

Trace a seeded random sphere scene with sampled camera rays and material scattering. See [provenance](mc-ray/PROVENANCE.md), original sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mc-ray`.
Individual module/data notices and aggregate notice are retained with the
ordered originals and patch.

Monte Carlo recursive ray tracing from John Reppy and the SML3d project.
Keep sphere/material generation, camera sampling, dielectric/metal/diffuse
paths and demand-dependent RNG draws. Reset MINSTD seed 1234567 each run;
explicit Word64 preserves the 64-bit multiplier/folding implementation on
32-bit default hosts. Real64 aliases become SML97 Real; binary64 precision
is required. Smoke/normal reduce dimensions and samples; large preserves
150x100 with 50 samples. Keep original list-pixel and object data structures.
Validate P6 headers, dimensions and every RGB channel against reviewed
native original renders, with at most one 8-bit level of rounding tolerance.
Result consumption and file output/validation are measured work. Algorithm,
real-operation, closure and allocation sensitivity are source hypotheses,
not established performance causes. See [literature](../literature.md).

SML/NJ 110.99.9 for 32 bits fails the recorded result checks. The seeded
Word64 generators are affected by its existing [64-bit literal/low-half
report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md) and
[shift report](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md).
A direct RNG comparison against compiled expected literals diverges from
the third draw. Agreement on earlier draws is weak evidence because this
host also miscompiles those literals; conversion/formatting loses bit 30. These
are host correctness failures, not additional valid numerical fixtures.
The portable source is preserved; those failed runs cannot supply timings.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `8 6 1 expected/smoke.ppm` | `48` |
| normal | `48 32 4 expected/normal.ppm` | `1536` |
| large | `150 100 50 expected/large.ppm` | `15000` |

## kitmolgard

Run a deterministic coloured Petri-net counting simulation and validate complete reports. See [provenance](kitmolgard/PROVENANCE.md), original sources and adaptation patch.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitmolgard.sml`.
Generated CPN/Design simulator, Niels 2001-02-17 benchmark adaptation.
Individual source history and aggregate notice are retained. No model-author
name is supplied beyond the source history; do not infer authorship from
this filename. The _smlnj source differs only in launcher/legacy Basis/time
adapters, all recorded and retained with the same simulation implementation.

Simulate the four-transition counting/logging coloured Petri net with the
original markings, bindings, random transition selection and mutable tables.
Seed 87 is explicit upstream state and is preserved per invocation. Select
100/10000/100000 counting transitions per batch and five completed batches;
large preserves actual upstream maxcnt=100000 and report indices 0..5.
The header's "25 lines" description is stale; the code stops at index 5.
Replace process exit with a loop-stop flag so results can be consumed and
repeated. Replace wall-clock elapsed seconds in diagnostic clock tokens by
zero for the initial full marking, then one logical second per completed batch; this clock does not decide which
transition is enabled. Batch counter/marking logic and RNG draw order stay
unchanged. Parameterized deterministic work permits count correctness.
Read and compare every complete counter/clock report and verify the number
of fired transitions independently: one set, six get/out pairs (the initial count marking is already full),
and five batches of n count firings, totaling 1+12+5*n.
Legacy Byte array tuple unpacking becomes Word8ArraySlice, TextIO.input
becomes inputAll in inactive interactive helpers, and its erroneous unused
closeIn alias is corrected. Existing upstream unavailable interactive/export
stubs remain unavailable and are not reached by this simulation. Close the
fixed log file at completion. Original data and all initialization are inside
the parameterized run. Event selection/mutable marking costs are source
hypotheses, not measured causes; see [simulation/ML Kit literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `100 expected/smoke.txt` | `513` |
| normal | `10000 expected/normal.txt` | `50013` |
| large | `100000 expected/large.txt` | `500013` |

## vliw-smlnj

Schedule and compress abstract assembly using the modern modular SML/NJ implementation. See [provenance](vliw-smlnj/PROVENANCE.md), original sources and adaptation patch.

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/vliw`.
All ordered modules, notices and original assembly data are retained.

Read ndotprod abstract assembly, build dependency nodes, schedule/compress
instructions with window nine and emit uncompressed/compressed assembly.
Preserve the modern modular implementation, custom sets/maps, sorting,
delay/idempotency logic and source input. Smoke/normal/large repeat the full
workload 1/3/250 times; 250 is the original modern count. The older monolith
uses a different launcher and contains historical runtime adapters.
Hide the BMARK launcher ascription to call the existing parameterized run;
suppress debug progress, close input/output files and validate every emitted
instruction from independent original fixture streams. Normalize GETREAL
literal spelling to an exact binary64 mantissa/exponent so numeric formatting
differences are accepted without accepting a changed value or instruction.
No simulator feature is added: upstream disables SimStuff.cmprog itself
because it raises Subscript. Scheduling/allocation/window effects are source
hypotheses, not measured performance causes. See [literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `9 1 expected/tmp.s expected/cmp.s` | `458 CDC06C0F;398 ADC5A56C` |
| normal | `9 3 expected/tmp.s expected/cmp.s` | `458 CDC06C0F;398 ADC5A56C|458 CDC06C0F;398 ADC5A56C|458 CDC06C0F;398 ADC5A56C` |
| large | `9 250 expected/tmp.s expected/cmp.s` | [complete result](vliw-smlnj/large.expected) |

## rfib

Evaluate the Double nfib recurrence and validate it with an independent integer recurrence. See [provenance](rfib/PROVENANCE.md) and retained Haskell source/Makefile.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/rfib/Main.hs`.
No author or individual licence notice is supplied by this source; retain this gap explicitly.
Retain the complete upstream source, Makefile and available output fixtures.

Evaluate the Double nfib recurrence and consume both recursive subresults.

Both recursive Double results are demanded exactly once; no sharing or unused argument changes the workload. The SML port evaluates n-1 before n-2 and preserves the two additions and floating comparisons. Integral profile arguments produce exact binary64 results at these sizes. An independent integer Fibonacci recurrence validates the complete result. A lazy variant is not added because all recursive subresults are consumed and no shared result is recomputed.
Smoke and normal bound work without changing the algorithm. Large is explicitly
selected from upstream parameters, and is not claimed as executed on every
engine. Process/argument plumbing is a thin SML driver; return and validate
the actual result. Calls, thunk forcing and allocation are source hypotheses
until measured. See [Partain and the nofib literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `12` | `465` |
| normal | `28` | `1028457` |
| large | `40` | `331160281` |

## tak-nofib-lazy

Demand Takeuchi arguments through explicit memoized delays. See [provenance](tak-nofib-lazy/PROVENANCE.md) and retained Haskell source/Makefile.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/tak/Main.hs`.
Authorship is unknown: the source explicitly records unknown provenance (Partain, 1995-01-25).
Retain the complete upstream source, Makefile and available output fixtures.

Demand Takeuchi arguments through memoized delays, preserving sharing.

The Haskell source can leave the third recursive argument unevaluated when the outer comparison returns another result. The lazy port memoizes each argument computation and passes the same delay cells into recursive calls, preserving demand and sharing. The strict port fully evaluates all three calls, changing work/allocation while retaining the same function value. Both variants are separately named and checked. Selected inputs fit every supported machine integer width; large preserves nofib normal parameters 35/17/8.
Smoke and normal bound work without changing the algorithm. Large is explicitly
selected from upstream parameters, and is not claimed as executed on every
engine. Process/argument plumbing is a thin SML driver; return and validate
the actual result. Calls, thunk forcing and allocation are source hypotheses
until measured. See [Partain and the nofib literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `9 6 3` | `6` |
| normal | `18 12 6` | `7` |
| large | `35 17 8` | `9` |

## tak-nofib-strict

The strict recurrence is the shared classic `tak` implementation in
`shared/tak.sml`; nofib retains its own driver and fixed input profiles.

Evaluate all three Takeuchi arguments strictly while preserving the function result. See [provenance](tak-nofib-strict/PROVENANCE.md) and retained Haskell source/Makefile.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/tak/Main.hs`.
Authorship is unknown: the source explicitly records unknown provenance (Partain, 1995-01-25).
Retain the complete upstream source, Makefile and available output fixtures.

Evaluate all three recursive Takeuchi arguments strictly.

The Haskell source can leave the third recursive argument unevaluated when the outer comparison returns another result. The lazy port memoizes each argument computation and passes the same delay cells into recursive calls, preserving demand and sharing. The strict port fully evaluates all three calls, changing work/allocation while retaining the same function value. Both variants are separately named and checked. Selected inputs fit every supported machine integer width; large preserves nofib normal parameters 35/17/8.
Smoke and normal bound work without changing the algorithm. Large is explicitly
selected from upstream parameters, and is not claimed as executed on every
engine. Process/argument plumbing is a thin SML driver; return and validate
the actual result. Calls, thunk forcing and allocation are source hypotheses
until measured. See [Partain and the nofib literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `9 6 3` | `6` |
| normal | `18 12 6` | `7` |
| large | `35 17 8` | `9` |

## exp3_8-lazy

Compute 3^n by lazy Peano addition and multiplication, then force the complete unary result. See [provenance](exp3_8-lazy/PROVENANCE.md).

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/exp3_8/Main.hs`.
Lennart Augustsson's 1992 Haskell translation; the source retains Joern von
Holten's discussion of the original ASpecT 3^8 benchmark. Preserve the full
mail history, source and Makefile. No individual licence statement is given;
record that gap rather than assigning an inferred licence.

Compute 3^n by lazy Peano addition and multiplication, then force the complete unary result.
Keep Z/S unary naturals, recursive addition, multiplication x*(S y)=x*y+x,
and exponentiation by recursive unary multiplication. Do not replace the
workload by machine exponentiation. The independent integer 3^n calculation
is used only after forcing/counting every constructor of the actual result.
Lazy successor fields and operations are explicit memoized delays, including
sharing of the same x operand on every multiplication branch. Z/S pattern
matching forces exactly the source operand; addition defers its second
operand until the first ends. Final integer conversion forces the complete
result.
Smoke uses exponent 3; normal 8 is the upstream fast parameter and large 9
is the upstream normal/slow parameter. All selected counts fit machine ints
on every host; the unary representation stays unchanged. Process arguments
are thin driver input. Forcing, thunk allocation, recursion and retained
constructors are source hypotheses; see [nofib literature](../literature.md).

| Profile | Exponent | Expected result |
|---|---|---|
| smoke | `3` | `27` |
| normal | `8` | `6561` |
| large | `9` | `19683` |

## exp3_8-strict

Compute 3^n by strict Peano addition and multiplication, then force the complete unary result. See [provenance](exp3_8-strict/PROVENANCE.md).

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/exp3_8/Main.hs`.
Lennart Augustsson's 1992 Haskell translation; the source retains Joern von
Holten's discussion of the original ASpecT 3^8 benchmark. Preserve the full
mail history, source and Makefile. No individual licence statement is given;
record that gap rather than assigning an inferred licence.

Compute 3^n by strict Peano addition and multiplication, then force the complete unary result.
Keep Z/S unary naturals, recursive addition, multiplication x*(S y)=x*y+x,
and exponentiation by recursive unary multiplication. Do not replace the
workload by machine exponentiation. The independent integer 3^n calculation
is used only after forcing/counting every constructor of the actual result.
The strict variant fully evaluates recursive products/additions before
constructing successors, materially changing evaluation/allocation and sharing
relative to the lazy source. It is separately named and measured.
Smoke uses exponent 3; normal 8 is the upstream fast parameter and large 9
is the upstream normal/slow parameter. All selected counts fit machine ints
on every host; the unary representation stays unchanged. Process arguments
are thin driver input. Forcing, thunk allocation, recursion and retained
constructors are source hypotheses; see [nofib literature](../literature.md).

| Profile | Exponent | Expected result |
|---|---|---|
| smoke | `3` | `27` |
| normal | `8` | `6561` |
| large | `9` | `19683` |

## digits-of-e1-lazy

Produce e digits with memoized continued-fraction transformations. See [provenance](digits-of-e1-lazy/PROVENANCE.md).

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/digits-of-e1/Main.lhs`.
Dale Thurston, August 2001. Preserve complete literate source/algorithm
explanation, Makefile and upstream hash fixtures. No individual licence notice
is present; its absence remains an explicit provenance gap.

Compute e digits by lazy continued-fraction linear transformations.
Keep the infinite e continued fraction [2,1,2,1,1,4,1,1,6,...], the
source pole/interval guards and exact IntInf.div floor arithmetic. The quotient
is calculated only after the pole guard permits it, preserving short-circuit
demand. Memoize continued-fraction tails and transformation tails; the global
continued fraction remains shared across repetitions as the Haskell CAF.
Count includes the initial 2 but no decimal point.
Every actual output character is consumed and compared with an independent
reviewed high-precision exp(1) fixture; output changes from a hash of Haskell
Show to a complete digit checker and repetition count. Normal uses upstream
fast size; large upstream normal size. Smoke/normal/large repeats 1/100/100
computations; 100 is the original replicateM count. No strict approximation
is added: forcing an infinite continued fraction or the unreachable finite
carry tail would change termination/input semantics. Big-integer arithmetic,
sharing and demand are source hypotheses; see [nofib literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `10 1 expected/smoke.txt` | `10` |
| normal | `50 100 expected/normal.txt` | `5000` |
| large | `150 100 expected/large.txt` | `15000` |

## digits-of-e2-lazy

Produce e digits with memoized factorial-base carry propagation. See [provenance](digits-of-e2-lazy/PROVENANCE.md).

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/digits-of-e2/Main.lhs`.
John Hughes, August 2001. Preserve complete literate source/algorithm
explanation, Makefile and upstream hash fixtures. No individual licence notice
is present; its absence remains an explicit provenance gap.

Compute e digits by lazy factorial-base carry propagation.
Keep the original finite 2*n factorial-series bound, integer-valued digits,
multiplication by ten, carry guesses and corrections. Both list spines and
head arithmetic are memoized delays: a successful carry guess emits its head
without forcing the next carry. The second digit and fractional tail retain
shared next-carry state. Exhausting the finite source is an error, not zero
padding. Count includes the initial 2 and decimal point, like source take n.
Every actual output character is consumed and compared with an independent
reviewed high-precision exp(1) fixture; output changes from a hash of Haskell
Show to a complete digit checker and repetition count. Smoke/normal use upstream
fast size 90; large upstream normal size 300. The attempted 10-character
smoke input exhausts the original Haskell finite carry bound and is rejected;
retain that original failure rather than adding zero padding. Smoke/normal/large repeats 1/100/100
computations; 100 is the original replicateM count. No strict approximation
is added: forcing an infinite continued fraction or the unreachable finite
carry tail would change termination/input semantics. Big-integer arithmetic,
sharing and demand are source hypotheses; see [nofib literature](../literature.md).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `90 1 expected/smoke.txt` | `90` |
| normal | `90 100 expected/normal.txt` | `9000` |
| large | `300 100 expected/large.txt` | `30000` |

## latency-ring

Keep a window of 1 KiB messages in a ring array, storing a young message into the old array at every step. See [provenance](latency-ring/PROVENANCE.md).

Rune, written for the second-generation collector's evaluation set
([garbage-collector-v2.md](../../docs/plans/garbage-collector-v2.md), *The
workloads*), after Fisher's Pusher benchmark and Scherer's
gc-latency-experiment. The window is what makes a copier's pauses grow with
the live data and what a generational collector's barrier sees at every
step. Shared code is [shared/latency.sml](shared/latency.sml).

Arguments `N STEPS SIZE TIME`: N + STEPS messages of SIZE bytes are made,
message i at step i into slot i mod N, where it replaces message i - N. So
about N times SIZE bytes are live, every message lives N steps, and every
step stores a young object into an old array. TIME 1 times every step with
`Time.now` (read through `Time.toReal`, which allocates nothing on Rune) and
writes to standard error the histograms of every step and of the steady
state once the window is full: samples, mean, p50 to p99.99 and maximum in
milliseconds (exact below 2 ms, buckets of 100 us below 2 s, recorded
without allocating), the steps over 1, 10 and 100 ms, and the loop's time.
TIME 0 reads no clock, so `--count` is exact; the profiles use it. With
TIME 1 the bytes and objects allocated are still those of every other run,
since the report writes its numbers in fixed widths; only the instructions
follow the clock. The
result is N, STEPS, SIZE and a digest of every message in the order made,
modulo the prime 16777213 so that a 31-bit int never overflows. It depends
on N + STEPS and SIZE alone, and [latency-map](#latency-map) gives the same.
`tests/benchmarks/latency-oracle.py` works the expected results out from the
messages' definition without running the program (`--check` compares them).

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 20000 1024 0` | `1000 20000 1024 1025487` |
| normal | `10000 1000000 1024 0` | `10000 1000000 1024 14533307` |
| large | `100000 3000000 1024 0` | `100000 3000000 1024 9991721` |

The evaluation set (`scripts/gc-eval.sh`, [docs/testing.md](../../docs/testing.md))
runs N = 10,000, 100,000 and 900,000 (about 10 MB, 100 MB and 0.93 GB live)
for 3,000,000 steps with TIME 1, and `scripts/gc-probe32.sh` runs N = 50,000
for 1,000,000 steps on the 32-bit VM. Today's copier pauses about 1.5 ms for
every MB live here, and holds five to ten times the live data.

## latency-map

Keep the same window of messages in a persistent AVL tree, copying a path at every step. See [provenance](latency-map/PROVENANCE.md).

Rune, the companion of [latency-ring](#latency-ring) with no mutation at
all: the window is an AVL tree keyed by message number, and a step inserts
the newest message and removes the oldest, copying the paths it changes. So
every step allocates O(log N) nodes, and old paths die in the middle of
what is old: copied by a copier, left as holes by a collector that does not
move. Arguments, timing, digest and expected results are latency-ring's,
and so are the evaluation set's sizes.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 20000 1024 0` | `1000 20000 1024 1025487` |
| normal | `10000 1000000 1024 0` | `10000 1000000 1024 14533307` |
| large | `100000 3000000 1024 0` | `100000 3000000 1024 9991721` |

## latency-static-map

Serve requests that allocate from a large map built once and never changed. See [provenance](latency-static-map/PROVENANCE.md).

Rune, the pause against the live data when nothing that is old changes. A
balanced tree of ENTRIES keys, each with a string of VLEN bytes, is built
once without garbage (about 155 bytes an entry at VLEN 100). Each of
REQUESTS requests draws LOOKUPS keys from Park and Miller's multiplier by
Schrage's method (modulo the prime 1073741789, so that every intermediate
fits in a 31-bit int), concatenates their strings and folds a list of
GARBAGE triples made from the response: about 2.4 KB of garbage at 8
lookups and 25 triples, none of which outlives its request. A copier copies
the whole map at every collection; a nursery need not touch it.

Arguments `ENTRIES VLEN REQUESTS LOOKUPS GARBAGE TIME`. TIME 1 writes the
requests' histogram (as latency-ring's) and the build's time to standard
error. The result is the size of the map, counted after the last request so
that the map stays live, REQUESTS, and the digest of every response;
`tests/benchmarks/latency-oracle.py` works it out independently.

| Profile | Arguments | Expected result |
|---|---|---|
| smoke | `1000 100 2000 8 25 0` | `1000 2000 4471862` |
| normal | `130000 100 100000 8 25 0` | `130000 100000 6754234` |
| large | `1300000 100 1000000 8 25 0` | `1300000 1000000 13178327` |

The evaluation set runs 1,300,000 entries (about 200 MB live) and 1,000,000
requests with TIME 1, and as extras 130,000 and 5,200,000 entries (about 20
and 800 MB) for the pause against the live data.
## kahan

Perform compensated summation over 100 seeded unsigned-word coordinates.

Algorithm: retain the 100-element sum/correction arrays, outer seeds 1..n,
xorshift steps 13/7/17, and exact (t-s)-y correction order. GHC Word is fixed
explicitly to unsigned 64 bits. The unused final RNG value is not evaluated.
History: individual authorship/licensing is unspecified by this source;
retain its comments (including the SG initials) and this notice gap.
Adaptation: STUArray Double becomes portable mutable real arrays; representation
and unboxing therefore depend on the SML compiler. Word64.toLargeInt followed
by Real.fromLargeInt preserves unsigned input conversion. The driver observes
all sums and checks correction bounds instead of merely forcing the array.
Profiles: 4/15000/150000 vectors. Large preserves upstream FAST; upstream
normal 1500000 and slow 7500000 remain recorded, not certified profiles.
Validation: independent Python unbounded-integer xorshift sums supply all 100
exact totals; an unchanged GHC kernel with a read-only sum/correction observer
agrees. Coordinate zero is exact with zero compensation at these sizes.
For other coordinates use |s-round(exact)| <= 1024*n + 4*u*abs(exact), u=2^-52.
The first term bounds conversion rounding of n unsigned 64-bit inputs; the
second covers compensated accumulation and target conversion. Corrections
must be finite and bounded by 2*u*(abs(s)+2^64). These are conservative selected
profile checks, not a proof for arbitrary inputs or a licence to reassociate
(t-s)-y. Deliberately perturbed sum/correction states must be rejected.
Performance: array updates, real representation, word operations, conversion
and GC are source-derived diagnostic hypotheses until separately measured.
Reference: Kahan, Further Remarks on Reducing Truncation Errors (1965),
https://doi.org/10.1145/363707.363723; the pinned nofib source and suite survey.

[Complete provenance and adaptations](kahan/PROVENANCE.md).

## x2n1-lazy

Sum memoized complex roots raised to their integer orders.

Algorithm: for n=1..range evaluate mkPolar 1 (2*pi/n)^n, then left-sum.
Complex components are strict, as in Data.Complex; list heads/spines are
memoized and consumed incrementally. The common helper preserves multiplication
and exponentiation order from GHC 9.4.7 base-4.17.2.0, including the f/g positive
power loop. Retain those library sources and their BSD licence.
History: Lennart Augustsson, December 1992; the source preserves his letter
to Will Partain explaining the benchmark's complex-number motivation.
Variants: strict computes the same values/order into an eager finite list
before summation. This changes evaluation and retention, so names remain
separate; both share one arithmetic kernel. No GC/compiler causal claim is made.
Adaptation: rectangular pairs replace strict Complex Double, explicit memoized
nodes replace lazy lists, and the driver observes both real and imaginary
components rather than only rounding the final real component.
Profiles: 64/10000/1000000 roots; large preserves upstream FAST, while original
normal 8000000 and slow 30000000 remain recorded but unexecuted.
Validation: each term is finite and within 16*u*n of (1,0); each final component
is within 32*u*range^2 of (range,0), u=2^-52. The final rounded real count must
also equal range. These conservative budgets cover input/trigonometric and
repeated multiplication/addition rounding on the selected positive ranges;
negative tests reject perturbations and nonfinite values. Original GHC output
agrees on all selected profiles. Reference: Augustsson's original letter,
GHC base sources and the nofib survey; unboxing, calls and retention are
source-derived hypotheses until measured.

[Complete provenance and adaptations](x2n1-lazy/PROVENANCE.md).

## x2n1-strict

Materialize complex root powers before summing both components.

See ../x2n1-lazy/PROVENANCE.md for authorship, history, numerical checks,
profiles and references. This separately named strict variant preserves the
same complex arithmetic and power order via ../shared/x2n1.sml. All root
powers are computed into an ordinary finite list before summation. This
changes allocation/retention and evaluation order relative to demanded list
nodes, while retaining the same element and accumulation order. Both components
are consumed and checked. Strict/lazy results agree on smoke and normal.
The original letter, source, Makefile and fixtures are retained here too.

[Complete provenance and adaptations](x2n1-strict/PROVENANCE.md).

## integrate-lazy

Integrate bilinear terms through shared memoized running-total streams.

Algorithm: preserve two nested nine-point trapezoidal sums for x*y on
[0,u] x [0,2u], the analytical fourth powers, shared infinite integer inputs,
self-referential running totals, and sum of squared differences. The nine
finite samples use ordinary SML lists: every sample is demanded and used
once, in unchanged left-sum order. Laziness and sharing of the infinite
inputs and feedback totals use explicit memoized heads/spines and tied roots.
History: no individual author/licence notice is supplied; retain that gap.
Variants: strict projects the selected finite range, eagerly builds its lists
and cumulative totals, and omits infinite CAF memoization. It preserves
term/arithmetic order but changes evaluation, allocation and retained data.
Adaptation: explicit delays make call-by-need portable in SML97. Numerical
functions have explicit real types across hosts. Replace the True/False
output switch with an always-active checker, fixed range and reference path.
Profiles: 32/10000/100000 terms; large preserves original FAST. Original
normal 1000000 and slow 5000000 are retained but not selected/certified.
Validation: original GHC gives accumulated squared error exactly 0 on these
profiles, so their scalar error bound is 0. Also check both final cumulative
streams against the independent exact sum of fourth powers,
n(n+1)(2n+1)(3n^2+3n-1)/30. Their bound is 2*gamma*abs(exact), where
gamma=(n+200)*u/(1-(n+200)*u), u=2^-52; 200 covers the fixed numerical kernel
and target conversion. All states must be finite. Perturbed scalar and total
states must be rejected. This is selected-profile evidence, not an assertion
that arbitrary ranges/platforms have zero accumulated numerical error.
Performance: feedback sharing, higher-order calls, scalar representation and
retained prefixes are source hypotheses until measured. References: pinned
nofib source, its analytical bilinear integral, and the suite literature survey.

[Complete provenance and adaptations](integrate-lazy/PROVENANCE.md).

## integrate-strict

Build finite numerical integration and running-total lists eagerly.

See ../integrate-lazy/PROVENANCE.md for the algorithm, authorship gap,
profiles, exact polynomial oracle, numerical bounds and references.
This strict finite projection uses the same ../shared/integrate.sml kernel,
then builds ordinary input, integral, fourth-power, cumulative-total and
squared-error lists before summation. It omits infinite memoized CAFs and
changes retention/evaluation; the selected values and arithmetic order are
unchanged. Both final cumulative streams and scalar error are consumed and
validated. Preserve the original source, Makefile and fixture here too.

[Complete provenance and adaptations](integrate-strict/PROVENANCE.md).

## bernouilli-lazy

Compute exact Bernoulli rationals with shared power and Pascal streams.

Algorithm: preserve the alternating power-sum formula, globally shared
infinite power rows and Pascal rows, signed powers, normalized arbitrary
precision ratios, and 64-bit nofib Show hashing. Numerators/denominators are
IntInf; ratio construction/addition follow GHC 9.4.7's reduce/gcd/cross-product
order. The spelling bernouilli is the established nofib name; Bernoulli is
the mathematical alias. No individual author/licence is supplied; the source
records a March 2003 Haskell-cafe discussion and its own GMP-performance caveat.
Variants: strict builds needed finite power/Pascal rows eagerly per repetition
and drops the global memoized cache. The recurrence and exact arithmetic are
preserved; forcing, caching, recomputation and retention differ materially.
Adaptation: memoized list heads/spines and explicitly tied roots preserve
feedback sharing; SML IntInf replaces Integer/Ratio. Haskell Show syntax,
including parentheses around negative numerators, and wrapping 64-bit hashes
are retained. SML strings materialize the shown characters; record this
representation change. Replace 500 printed hashes with checked computations
and one consumed repetition sum. Every rational and hash is validated.
Profiles: (8,1)/(60,5)/(180,500). Normal uses original FAST size; large uses
original NORM and 500 repetitions. Original SLOW size 320 remains recorded.
Validation: independent Akiyama-Tanigawa rational recurrence agrees with
unchanged GHC numerator/denominator observers at 8/60/180. The 60-index hash
also agrees with the pinned original fast fixture; other hashes use an
independent 64-bit polynomial fold over reviewed Show strings. Performance
questions about sharing, gcd, big integers and allocation remain hypotheses
until measured. References: original source/discussion note, pinned GHC Ratio
operations, nofib survey. Large SML execution is not universally claimed.

[Complete provenance and adaptations](bernouilli-lazy/PROVENANCE.md).

## bernouilli-strict

Compute exact Bernoulli rationals from eagerly generated finite rows.

See ../bernouilli-lazy/PROVENANCE.md for history, alias, source notice gap,
profiles, exact references, ratio arithmetic and Show/hash semantics.
The strict variant uses ordinary finite power and Pascal lists and recomputes
them per repetition, omitting the lazy port's shared global caches. It keeps
the same multiply-by-base recurrence and signed power-sum formula, with
identical normalized IntInf ratio operations in ../shared/rational.sml.
Demand, recomputation, allocation and retained data therefore differ; this
is a separately named strict workload, not a claim about GHC's optimized
execution. Full rational values and original 64-bit hashes are checked.

[Complete provenance and adaptations](bernouilli-strict/PROVENANCE.md).

## wheel-sieve1-lazy

Enumerate primes with circular memoized Mark I wheel streams.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/wheel-sieve1/Main.hs`.

Colin Runciman, March 1996. The source cites his 1997 functional pearl
[Lazy wheel sieves and spirals of primes](https://doi.org/10.1017/S0956796897002670).
Keep the established Mark I/Mark II variant distinction. Complete source,
Makefile and available fixtures are retained with individual SHA256 identities;
the program supplies no explicit individual licence notice, recorded as a gap.

Both ports preserve circular prime dependencies, delayed list heads and spines,
wheel residues and periods, prime squares, bounds, and indexed result selection.
The helper retains lazy folds whose branch may ignore the remainder and a
shared lazy span whose prefix can be consumed without forcing the full split.
There is no strict approximation: prematurely forcing these infinite/circular
structures changes termination and the algorithm. IntInf replaces machine Int
for wheel arithmetic and n^2/n^4 bounds, preventing host-width overflow.
Selected guard values fit the original GHC 64-bit range; this representation
change adds arbitrary-precision arithmetic costs, explicitly part of the port.

The original 100 printed results become separately selected repetition counts
and one consumed sum. Each invocation builds its own prime knot, while sharing
within that knot is preserved. Smoke/normal use one invocation; large preserves
100. Zero-based prime indices are unchanged. Independent finite Eratosthenes
fixtures agree with the original GHC kernel on all selected inputs. All actual
prime values are checked. Incorrect values, loss of sharing or excessive forcing
are rejected by result and stream-semantic checks.

The paper supports the algorithm distinction and the need to avoid black holes.
Effects of memoization, bigint representation, retention and compiler
specialization are source-derived hypotheses until measured on these ports.
See [the literature survey](../literature.md).

Mark I retains the wheel rotations and divisibility filters. The leading
offset is available before the upper-bound expression reads the prime stream,
so the initial prime can be produced without recursive forcing. The original
self-reference in the wheel stream is retained. Profiles are (128,1), (3000,1)
and (12000,100); normal/large preserve original FAST/NORM indices. Original SLOW
40000 is recorded in the retained Makefile, not claimed as executed.

[Complete provenance](wheel-sieve1-lazy/PROVENANCE.md).

## wheel-sieve2-lazy

Enumerate primes with the original Mark II spiral and shared lazy spans.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/wheel-sieve2/Main.hs`.

Colin Runciman, March 1996. The source cites his 1997 functional pearl
[Lazy wheel sieves and spirals of primes](https://doi.org/10.1017/S0956796897002670).
Keep the established Mark I/Mark II variant distinction. Complete source,
Makefile and available fixtures are retained with individual SHA256 identities;
the program supplies no explicit individual licence notice, recorded as a gap.

Both ports preserve circular prime dependencies, delayed list heads and spines,
wheel residues and periods, prime squares, bounds, and indexed result selection.
The helper retains lazy folds whose branch may ignore the remainder and a
shared lazy span whose prefix can be consumed without forcing the full split.
There is no strict approximation: prematurely forcing these infinite/circular
structures changes termination and the algorithm. IntInf replaces machine Int
for wheel arithmetic and n^2/n^4 bounds, preventing host-width overflow.
Selected guard values fit the original GHC 64-bit range; this representation
change adds arbitrary-precision arithmetic costs, explicitly part of the port.

The original 100 printed results become separately selected repetition counts
and one consumed sum. Each invocation builds its own prime knot, while sharing
within that knot is preserved. Smoke/normal use one invocation; large preserves
100. Zero-based prime indices are unchanged. Independent finite Eratosthenes
fixtures agree with the original GHC kernel on all selected inputs. All actual
prime values are checked. Incorrect values, loss of sharing or excessive forcing
are rejected by result and stream-semantic checks.

The paper supports the algorithm distinction and the need to avoid black holes.
Effects of memoization, bigint representation, retention and compiler
specialization are source-derived hypotheses until measured on these ports.
See [the literature survey](../literature.md).

Mark II retains the spiral's turn0/turn/roll functions, branch replacement
by the next spiral, dropWhile alignment, and span-based residue split. In
particular the initial candidate 2 is emitted before forcing its square bound.
The source's recursively re-created wheel stream is retained rather than
replacing it with Mark I's single self-referential wheel root. Profiles are
(32,1), (700,1), (2000,100); normal/large preserve original FAST/NORM indices.
Original SLOW 4000 and its Haskell 300 MiB runtime heap setting are recorded;
our manifest's standard per-profile limits are separately explicit.

[Complete provenance](wheel-sieve2-lazy/PROVENANCE.md).

## gen_regexps-lazy

Expand numeric and alphabetic ranges through memoized character streams.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/gen_regexps/Main.hs` and its NofibUtils hash.
The source identifies Wentworth's version and an RJE output adaptation; fuller
authorship and an individual licence are unspecified, recorded as gaps. Preserve
source, Makefile and fixtures with their notices and SHA256 identities.

This is an expansion workload for literals, [a-b] alphabetic ranges and <u-v>
zero-padded numeric ranges, not a general regexp matcher. Ascending/descending
ranges, inclusive endpoints, padding width and expansion order are unchanged.
Selected inputs are ASCII and well-formed; SML parsing explicitly rejects other
literal characters and malformed numeric ranges. Numeric endpoint parsing and
shared representation are ordinary SML97. Both variants recompute expand(rest)
inside each outer range choice, as in the source comprehension. A compiler may
hoist common suffixes; that is a performance hypothesis, not assumed sharing.

Preserve the nofib polynomial hash with explicit wrapping 64-bit arithmetic,
matching the reference GHC Int width. The driver also observes character count;
both hash and count must agree. Python Cartesian-product enumeration and an
original GHC observer agree on all selected profiles. Output is a consumed
character-count sum instead of 500 printed hashes. Normal retains the original
NORM expression with one repetition; large retains SLOW with 500. Smoke uses
[a-b]<09-10> to cover padding; original FAST remains in the retained Makefile.

The lazy port memoizes both expansion-list and character-list heads/spines;
concatenation and hashing consume prefixes without materializing all output.
The strict variant creates finite character lists and their concatenation
before hashing. Both share parsing, ranges and modular semantics. Allocation,
fusion, suffix recomputation and retention are source hypotheses until measured.
Large SML execution is not universally claimed. References: pinned original
source/history comments and the nofib literature survey.

Legacy SML/NJ 110.99.9 rejects the lazy normal profile: repeated read-only
observers return different hashes for the same 622080 characters. Modern 2026.2,
MLton, Poly/ML and Rune agree with the reference. Keep the failed result rejected;
no alternate fixture or host workaround is introduced. Its precise cause is
not isolated; the known legacy GC-root bug is a candidate explanation.

[Complete provenance](gen_regexps-lazy/PROVENANCE.md).

## gen_regexps-strict

Materialize range-expansion character lists before the 64-bit hash fold.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/gen_regexps/Main.hs` and its NofibUtils hash.
The source identifies Wentworth's version and an RJE output adaptation; fuller
authorship and an individual licence are unspecified, recorded as gaps. Preserve
source, Makefile and fixtures with their notices and SHA256 identities.

This is an expansion workload for literals, [a-b] alphabetic ranges and <u-v>
zero-padded numeric ranges, not a general regexp matcher. Ascending/descending
ranges, inclusive endpoints, padding width and expansion order are unchanged.
Selected inputs are ASCII and well-formed; SML parsing explicitly rejects other
literal characters and malformed numeric ranges. Numeric endpoint parsing and
shared representation are ordinary SML97. Both variants recompute expand(rest)
inside each outer range choice, as in the source comprehension. A compiler may
hoist common suffixes; that is a performance hypothesis, not assumed sharing.

Preserve the nofib polynomial hash with explicit wrapping 64-bit arithmetic,
matching the reference GHC Int width. The driver also observes character count;
both hash and count must agree. Python Cartesian-product enumeration and an
original GHC observer agree on all selected profiles. Output is a consumed
character-count sum instead of 500 printed hashes. Normal retains the original
NORM expression with one repetition; large retains SLOW with 500. Smoke uses
[a-b]<09-10> to cover padding; original FAST remains in the retained Makefile.

The lazy port memoizes both expansion-list and character-list heads/spines;
concatenation and hashing consume prefixes without materializing all output.
The strict variant creates finite character lists and their concatenation
before hashing. Both share parsing, ranges and modular semantics. Allocation,
fusion, suffix recomputation and retention are source hypotheses until measured.
Large SML execution is not universally claimed. References: pinned original
source/history comments and the nofib literature survey.

Legacy SML/NJ 110.99.9 rejects the lazy normal profile: repeated read-only
observers return different hashes for the same 622080 characters. Modern 2026.2,
MLton, Poly/ML and Rune agree with the reference. Keep the failed result rejected;
no alternate fixture or host workaround is introduced. Its precise cause is
not isolated; the known legacy GC-root bug is a candidate explanation.

[Complete provenance](gen_regexps-strict/PROVENANCE.md).

## paraffins-lazy

Count shared alkyl radicals and paraffin centres without forcing unused tree heads.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/paraffins/Main.hs`.
Steve Heller's Id example, forwarded from MIT by RPaul and acquired by SLPJ
in August 1993 according to the retained source. No individual licence notice is
supplied; record the gap. Retain the source, optional C implementation, build
manifest and upstream fixtures with SHA256 identities.

Preserve three/four-part partitions, suffix-based selection of repeated-size
radicals, immutable shared subtrees, the lazy array of radical rows, and bridge/
vertex-centred paraffin generation. Each invocation produces all four original
count vectors: radical rows, bridge centres, vertex centres and their combined
counts. Separate generators for those observations remain separate, while the
combined function shares one generator for both centre forms.

The lazy port has memoized row/spine/head cells and delayed constructor fields.
Its length observer forces list spines but leaves radical/paraffin values
unforced, as the original count-only workload does. The strict variant builds
ordinary lists and constructor objects eagerly. Representation, demand, retained
subtrees and possible constructor elimination differ materially. The shared
partition arithmetic retains the original ceiling operation on small, exact
half-integer arguments. No closed-form counting algorithm replaces the kernel.

Independent combinatorial fixtures count combinations with replacement for
equal-sized branches and independently enumerate centre partitions. They agree
with the original Haskell observer and all four selected count vectors; the
combined counts include 159 at 11 carbons and 1858 at 14. Every vector is rendered
and compared in full, then the actual count sum is consumed. Profiles are
(4,1), (11,1), (14,1000); normal/large preserve original FAST/NORM sizes, and
large retains 1000 source repetitions. SLOW size 15 remains recorded.

References: the original Id/source provenance, the nofib survey, and the
[alkyl-radical](https://oeis.org/A000598) and [alkane](https://oeis.org/A000602)
count sequences for additional mathematical context. Performance effects of
sharing, demand, object lifetimes and compiler elimination are hypotheses until
measured on these ports. Large execution is not universally claimed.

[Complete provenance](paraffins-lazy/PROVENANCE.md).

## paraffins-strict

Construct finite radical and paraffin object lists before counting them.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/paraffins/Main.hs`.
Steve Heller's Id example, forwarded from MIT by RPaul and acquired by SLPJ
in August 1993 according to the retained source. No individual licence notice is
supplied; record the gap. Retain the source, optional C implementation, build
manifest and upstream fixtures with SHA256 identities.

Preserve three/four-part partitions, suffix-based selection of repeated-size
radicals, immutable shared subtrees, the lazy array of radical rows, and bridge/
vertex-centred paraffin generation. Each invocation produces all four original
count vectors: radical rows, bridge centres, vertex centres and their combined
counts. Separate generators for those observations remain separate, while the
combined function shares one generator for both centre forms.

The lazy port has memoized row/spine/head cells and delayed constructor fields.
Its length observer forces list spines but leaves radical/paraffin values
unforced, as the original count-only workload does. The strict variant builds
ordinary lists and constructor objects eagerly. Representation, demand, retained
subtrees and possible constructor elimination differ materially. The shared
partition arithmetic retains the original ceiling operation on small, exact
half-integer arguments. No closed-form counting algorithm replaces the kernel.

Independent combinatorial fixtures count combinations with replacement for
equal-sized branches and independently enumerate centre partitions. They agree
with the original Haskell observer and all four selected count vectors; the
combined counts include 159 at 11 carbons and 1858 at 14. Every vector is rendered
and compared in full, then the actual count sum is consumed. Profiles are
(4,1), (11,1), (14,1000); normal/large preserve original FAST/NORM sizes, and
large retains 1000 source repetitions. SLOW size 15 remains recorded.

References: the original Id/source provenance, the nofib survey, and the
[alkyl-radical](https://oeis.org/A000598) and [alkane](https://oeis.org/A000602)
count sequences for additional mathematical context. Performance effects of
sharing, demand, object lifetimes and compiler elimination are hypotheses until
measured on these ports. Large execution is not universally claimed.

[Complete provenance](paraffins-strict/PROVENANCE.md).

## mutstore1

Retain immutable vectors of mutable list buckets across repeated insertions.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/mutstore1/Main.hs` and Store1.hs.
No individual author or licence notice is supplied; keep that gap explicit.
Original source/build manifests and their SHA256 identities are retained.

Preserve ten buckets per store, bucket index 3, inserted value 17, five insertions
per testSequence and five full passes over the retained store list. Variant 1
uses an immutable vector of references to lists; variant 2 a mutable array of
lists. These are distinct layout/update workloads, not duplicate implementations.
IORef/IOArray operations become ordinary SML refs/arrays with the same state and
traversal order. All stores remain live through all passes and the final checker.
SML integer widths differ from GHC's 64-bit Int, but every selected value/count
fits supported widths; no wrapping arithmetic is required.

The originally discarded state is now observed: every bucket has its expected
length and all values are 17, then actual store/entry/value totals are consumed.
Original GHC observers agree with the independent 25*n and 425*n arithmetic
checks. This added scan is included in the port's work and extends retention
through validation. Selected store counts are 4/1000/100000; large preserves
original FAST. Original NORMAL/SLOW and heap settings remain in the Makefiles.
Large SML execution is not universally claimed. Allocation, write costs and
retained lists are source-derived hypotheses until separately measured.
References: pinned nofib source and suite survey; compare the two source layouts.

[Complete provenance](mutstore1/PROVENANCE.md).

## mutstore2

Retain mutable arrays of list buckets across repeated insertions.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/mutstore2/Main.hs` and Store2.hs.
No individual author or licence notice is supplied; keep that gap explicit.
Original source/build manifests and their SHA256 identities are retained.

Preserve ten buckets per store, bucket index 3, inserted value 17, five insertions
per testSequence and five full passes over the retained store list. Variant 1
uses an immutable vector of references to lists; variant 2 a mutable array of
lists. These are distinct layout/update workloads, not duplicate implementations.
IORef/IOArray operations become ordinary SML refs/arrays with the same state and
traversal order. All stores remain live through all passes and the final checker.
SML integer widths differ from GHC's 64-bit Int, but every selected value/count
fits supported widths; no wrapping arithmetic is required.

The originally discarded state is now observed: every bucket has its expected
length and all values are 17, then actual store/entry/value totals are consumed.
Original GHC observers agree with the independent 25*n and 425*n arithmetic
checks. This added scan is included in the port's work and extends retention
through validation. Selected store counts are 4/1000/100000; large preserves
original FAST. Original NORMAL/SLOW and heap settings remain in the Makefiles.
Large SML execution is not universally claimed. Allocation, write costs and
retained lists are source-derived hypotheses until separately measured.
References: pinned nofib source and suite survey; compare the two source layouts.

[Complete provenance](mutstore2/PROVENANCE.md).

## gc_bench

Build mutable and immutable trees while retaining trees and a numerical array.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/gc_bench/Main.hs`.
The retained source includes the Ellis-Kovac/Boehm benchmark's history and
limitations. John Ellis and Pete Kovac designed the original; Hans Boehm
modified it. The individual Haskell translator/licence is unspecified, recorded
as a gap. Retain the complete source notice, including its historical Java
listing, plus build manifests and source identities.

Port the Haskell variant: deeply forced immutable trees, top-down mutable trees
with two child references, two retained trees and a half-filled real array.
There is no extra stretch-tree phase in this Haskell main, despite the historical
Java example. Tree-size, integer iteration counts, depth stepping/parity and
mutable node labels are unchanged. Retain the original left-depth walk's zero
return value rather than silently fixing it. SML's strict immutable construction
replaces Haskell deepSeq; refs replace IORefs, and arrays replace IOArray Double.

Driver CPU-time reads and the unused old-time import are removed from the SML
program; external tools measure execution. A GHC read-only observer removes only
the unused System.Time import to build on the reference host. It agrees on both
retained tree sizes/labels and array fill counts. Full temporary/retained tree
observers count actual nodes, validate immutable zero labels and mutable label
sum 2^(depth+2)-depth-4, and scan every array value with a documented reciprocal
relative bound 2^-51. These observers consume results and add traversal work,
including on mutable temporary trees; this is explicitly part of the port.
Independent tree-size/iteration formulas validate the consumed temporary total.

Profiles (retained-depth,array-size,min-depth,max-depth) are (4,32,2,6),
(12,16000,4,12), (17,400000,4,17); large preserves original FAST. The original
normal/slow dimensions and Haskell heap settings remain recorded. Profile limits
are operating-system quotas, not a claim of equal GC heap sizes or the original
32 MiB recommendation. The literature supports allocation/lifetime diagnostics
and explains limitations; this artificial workload is not a prediction of
application performance. Potential hoisting/sharing/elimination of pure immutable
construction is a compiler hypothesis until measured.
Reference: [Boehm's GCBench overview](https://www.hboehm.info/gc/gc_bench.html),
original source comments and the nofib survey. Large execution is not universally
claimed; no pause-time claim is made.

[Complete provenance](gc_bench/PROVENANCE.md).

## pidigits-nofib-lazy

Generate and verify formatted pi digit blocks with memoized coefficients.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/pidigits/Main.hs`.
Bryan O'Sullivan contributed the Benchmarks Game program; Eugene Kirpichov changed
its output construction according to the retained header. No individual licence
is supplied; retain the notice gap, complete source, fixtures and build manifest.
This is a distinct variant of the classic pidigits programs, preserving its
step-before-extraction recurrence and formatting; collision names use -nofib.

Preserve all exact Integer arithmetic as IntInf, quotient/remainder conditions,
index advancement and digit extraction. In particular n>a short-circuits before
expensive division. The lazy port memoizes each coefficient and digit/spine;
the strict variant evaluates coefficient triples eagerly. It avoids computing
an unused final scaled state. Arithmetic values and output agree, while delayed
work, retained coefficients and allocation differ materially. The bounded term
index fits all supported machine Int widths. No arbitrary-precision operations
are replaced with floating point or host-width wrapping arithmetic.

The shared formatter preserves ten-character blocks, final space padding,
TAB-colon indices and newlines, using linear block splitting. Every output byte
is checked against original GHC output and independently computed high-precision
Chudnovsky digits, including the partial 27-digit smoke block. SML materializes
the selected prefix and final string instead of printing the Haskell lazy String;
record this representation/retention change. The actual byte count is consumed.
Profiles select 27/200/3500 digits; large preserves original FAST, while original
normal 11000 and slow 22000 remain recorded and unexecuted on all SML engines.
References: original author/header, exact upstream fixtures and the nofib/Benchmarks
Game literature. Arithmetic, demand, sharing and formatting costs are source
hypotheses until separately measured. Large SML execution is not universally claimed.

[Complete provenance](pidigits-nofib-lazy/PROVENANCE.md).

## pidigits-nofib-strict

Generate and verify pi digit blocks with strict arbitrary-precision state.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/pidigits/Main.hs`.
Bryan O'Sullivan contributed the Benchmarks Game program; Eugene Kirpichov changed
its output construction according to the retained header. No individual licence
is supplied; retain the notice gap, complete source, fixtures and build manifest.
This is a distinct variant of the classic pidigits programs, preserving its
step-before-extraction recurrence and formatting; collision names use -nofib.

Preserve all exact Integer arithmetic as IntInf, quotient/remainder conditions,
index advancement and digit extraction. In particular n>a short-circuits before
expensive division. The lazy port memoizes each coefficient and digit/spine;
the strict variant evaluates coefficient triples eagerly. It avoids computing
an unused final scaled state. Arithmetic values and output agree, while delayed
work, retained coefficients and allocation differ materially. The bounded term
index fits all supported machine Int widths. No arbitrary-precision operations
are replaced with floating point or host-width wrapping arithmetic.

The shared formatter preserves ten-character blocks, final space padding,
TAB-colon indices and newlines, using linear block splitting. Every output byte
is checked against original GHC output and independently computed high-precision
Chudnovsky digits, including the partial 27-digit smoke block. SML materializes
the selected prefix and final string instead of printing the Haskell lazy String;
record this representation/retention change. The actual byte count is consumed.
Profiles select 27/200/3500 digits; large preserves original FAST, while original
normal 11000 and slow 22000 remain recorded and unexecuted on all SML engines.
References: original author/header, exact upstream fixtures and the nofib/Benchmarks
Game literature. Arithmetic, demand, sharing and formatting costs are source
hypotheses until separately measured. Large SML execution is not universally claimed.

[Complete provenance](pidigits-nofib-strict/PROVENANCE.md).

## hash

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/hash/hash.hs` and `HashTable.hs`.
The retained table source credits the University of Glasgow (2003), gives a
BSD-style notice and identifies the earlier Data.HashTable module. The base
BSD licence is retained. It cites Per-Ake Larson, Dynamic Hash Tables, CACM
31(4), April 1988, pages 446-457. The driver author is unspecified.

Preserve mutable bucket arrays, a reference to strict table state, association
lists, initial eight buckets/mask seven, load factor seven, hysteresis 64,
stable doubling partitions and maximum mask 33554431. The exact growth condition
is count-64 > 7*mask, not bucket-count times seven. Each insertion retains earlier
entries. The benchmark needs new/insert/lookup; unused library APIs and disabled
instrumentation are not added to the SML kernel, while the complete original
module is retained for provenance.

The hash multiplies by 1013904242 and extracts the high 32 bits before adding
the key. Selected nonnegative inputs/products fit the original signed ranges;
Word64 implements the wide product/shift and SML machine integers hold the final
hash and counters. SML31-bit hosts can represent every selected counter/hash;
no arbitrary-precision replacement is used in the kernel. The independent
checker uses IntInf to verify placement mathematically, so a host word bug cannot
validate itself merely by repeating its faulty hash function.

Original GHC lookup returns Just 100 at all selected sizes. The port additionally
consumes every stored key/value, detects missing/duplicate/out-of-range entries,
validates placement against the exact formula and checks n(n+1)/2. The checker
and its temporary seen array add work/allocations and are included. Selected
sizes are 128/10000/1000000; large preserves original FAST. Original NORM5000000,
SLOW100000000 and heap settings remain recorded, not universally executed.

Growth, bucket chains, stable redistribution, integer representation and retained
entries are source hypotheses until measured. Reference: retained HashTable
module and its Larson citation, plus the nofib survey. No compiler/runtime
features or alternative hash-table algorithm are introduced.

[Complete provenance](hash/PROVENANCE.md).

## lcss-lazy

Compute Hirschberg LCSS through delayed row values and a lazy result suffix.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/lcss/Main.hs`. Andrew J. Bromage contributed this
Hirschberg longest-common-subsequence example in November 2002; the original
mail/header is retained. It explicitly discusses quadratic time and linear
space assuming eager evaluation. An individual licence is unspecified, recorded
as a gap. Source, Makefile and fixtures retain their SHA256 identities.

Preserve row-pair updates, forward/reversed score rows, integer middle split,
last-maximum tie selection (>=), and difference-list result composition. The
lazy variant memoizes row values/spines, reverses cells without forcing their
values and delays the recursive result suffix so left output does not force the
right subtree early. The strict variant computes finite row lists and eager
recursive results. This changes evaluation/retention while preserving the
algorithm, arithmetic and selected sequence. No array-based or alternative LCS
kernel substitutes for the original list-pair algorithm.

The driver preserves six arithmetic-sequence parameters. Nonzero step and a
nonempty first sequence are required: the original missing empty-first case is
not silently repaired. Selected inputs fit machine integer widths. Profiles
are (1,2,16;8,9,24), (1,2,200;100,101,400), (1,2,2000;1000,1001,2000); large
preserves original FAST. Original NORM/SLOW and heap flags remain recorded.
The complete returned list is consumed and checked, not just its length. Original
GHC output agrees with an independent dynamic-programming oracle and the unique
ascending intersection for these profiles. SML materializes the result prefix
for full validation; output becomes its actual length. Large SML execution is
not universally claimed.

Row sharing, retained deferred values, repeated prefix traversal, higher-order
composition and compiler specialization are source-derived performance questions
until measured. The strict/lazy distinction is material to the source's space
claim. References: original Bromage explanation, its Hirschberg attribution and
the nofib survey; no broader mathematical or timing claim is inferred from one
input family.

[Complete provenance](lcss-lazy/PROVENANCE.md).

## lcss-strict

Compute Hirschberg LCSS with eagerly evaluated dynamic-programming rows.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/lcss/Main.hs`. Andrew J. Bromage contributed this
Hirschberg longest-common-subsequence example in November 2002; the original
mail/header is retained. It explicitly discusses quadratic time and linear
space assuming eager evaluation. An individual licence is unspecified, recorded
as a gap. Source, Makefile and fixtures retain their SHA256 identities.

Preserve row-pair updates, forward/reversed score rows, integer middle split,
last-maximum tie selection (>=), and difference-list result composition. The
lazy variant memoizes row values/spines, reverses cells without forcing their
values and delays the recursive result suffix so left output does not force the
right subtree early. The strict variant computes finite row lists and eager
recursive results. This changes evaluation/retention while preserving the
algorithm, arithmetic and selected sequence. No array-based or alternative LCS
kernel substitutes for the original list-pair algorithm.

The driver preserves six arithmetic-sequence parameters. Nonzero step and a
nonempty first sequence are required: the original missing empty-first case is
not silently repaired. Selected inputs fit machine integer widths. Profiles
are (1,2,16;8,9,24), (1,2,200;100,101,400), (1,2,2000;1000,1001,2000); large
preserves original FAST. Original NORM/SLOW and heap flags remain recorded.
The complete returned list is consumed and checked, not just its length. Original
GHC output agrees with an independent dynamic-programming oracle and the unique
ascending intersection for these profiles. SML materializes the result prefix
for full validation; output becomes its actual length. Large SML execution is
not universally claimed.

Row sharing, retained deferred values, repeated prefix traversal, higher-order
composition and compiler specialization are source-derived performance questions
until measured. The strict/lazy distinction is material to the source's space
claim. References: original Bromage explanation, its Hirschberg attribution and
the nofib survey; no broader mathematical or timing claim is inferred from one
input family.

[Complete provenance](lcss-strict/PROVENANCE.md).

## gcd-lazy

Evaluate extended Euclid over a shared lazy grid with deferred coefficients.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/gcd/Main.hs`. Sergey Mechveliani contributed
this Integer-performance test. The retained header explains replacing a sum
with a maximum to avoid distorted large numbers. The individual licence is
unspecified; source, Makefile and fixtures retain their notices and SHA256 IDs.

Preserve the inclusive grid 5000..5000+d by 10000..10000+d, extended-Euclidean
quotRem recurrence, arbitrary-precision Integer arithmetic, coefficient update
order and maximum abs(g+u+v). IntInf is used throughout; this is not a machine
integer benchmark. The lazy variant shares finite input streams, memoizes
coefficient expressions and demands pairs/triples/results through explicit
streams. The strict variant uses eager coefficient triples and materializes
ordinary pair/triple/result lists. The selected mathematical work and maximum
agree; evaluation, intermediate retention and allocation differ materially.

Every computed result is consumed and checked: g is positive, divides both
inputs, and equals u*x+v*y. Together these identities independently establish
the greatest common divisor. The additional checks are part of the SML workload.
Original GHC maxima agree with a separate Python reference also checked by
math.gcd. Profiles select d=2/100/400; large preserves original FAST, while
original normal1200 and slow2700 remain recorded. Large SML execution is not
universally claimed. Output is the actual reviewed maximum; no success constant
or floating-point approximation replaces the kernel.

References: original Mechveliani explanation and nofib survey. Big-integer
costs, coefficient demand/sharing, lazy traversal and retained intermediate
lists are source-derived diagnostic questions until measured. No compiler or
runtime features are prerequisites of this port.

[Complete provenance](gcd-lazy/PROVENANCE.md).

## gcd-strict

Evaluate extended Euclid over eagerly materialized pair and result lists.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/gcd/Main.hs`. Sergey Mechveliani contributed
this Integer-performance test. The retained header explains replacing a sum
with a maximum to avoid distorted large numbers. The individual licence is
unspecified; source, Makefile and fixtures retain their notices and SHA256 IDs.

Preserve the inclusive grid 5000..5000+d by 10000..10000+d, extended-Euclidean
quotRem recurrence, arbitrary-precision Integer arithmetic, coefficient update
order and maximum abs(g+u+v). IntInf is used throughout; this is not a machine
integer benchmark. The lazy variant shares finite input streams, memoizes
coefficient expressions and demands pairs/triples/results through explicit
streams. The strict variant uses eager coefficient triples and materializes
ordinary pair/triple/result lists. The selected mathematical work and maximum
agree; evaluation, intermediate retention and allocation differ materially.

Every computed result is consumed and checked: g is positive, divides both
inputs, and equals u*x+v*y. Together these identities independently establish
the greatest common divisor. The additional checks are part of the SML workload.
Original GHC maxima agree with a separate Python reference also checked by
math.gcd. Profiles select d=2/100/400; large preserves original FAST, while
original normal1200 and slow2700 remain recorded. Large SML execution is not
universally claimed. Output is the actual reviewed maximum; no success constant
or floating-point approximation replaces the kernel.

References: original Mechveliani explanation and nofib survey. Big-integer
costs, coefficient demand/sharing, lazy traversal and retained intermediate
lists are source-derived diagnostic questions until measured. No compiler or
runtime features are prerequisites of this port.

[Complete provenance](gcd-strict/PROVENANCE.md).

## treejoin-lazy

Join persistent relation trees with delayed keys, fields and branches.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/treejoin/Main.hs`, relation files 27000.1/27000.2
and the retained MAIL. The 1993 submission is from kh@dcs.gla.ac.uk; the full
individual author/licence and dataset notice are not specified, recorded as gaps.
Original source, data, build settings and mail are retained with SHA256 identities.

Keep the unbalanced persistent binary-tree representation, boundary keys,
insertion/duplicate-key rules, key lookup and right-before-left join accumulation.
The left relation is keyed by its first field; its third field looks up the first
field of the right relation. Joined values have the original five fields. Both
variants instantiate one algorithm with eager or memoized suspension adapters.
The lazy adapter delays numeric accumulation, tree roots/branches and stored
fields: unmatched records leave unused fields unforced. The strict adapter
forces these operations eagerly; allocation, work order and retention differ.
No balanced tree, hash join or alternative relational algorithm is substituted.

SML reads complete file byte strings instead of Haskell lazy file characters;
numeric/tree demand is preserved after that input representation change. Inputs
are positive ASCII integers fitting supported widths. Profiles take the original
first 125/2000/all27000 records from both files without reordering or regeneration.
Subsets retain their origin but change size/selectivity; they contain 0/28/2700
matches. Large preserves the original complete workload and build heap settings
remain recorded separately. No universal large SML execution is claimed.

The full sorted five-field join is checked against original GHC with a read-only
observer and independent dictionary-based relational joins. Every result field
is consumed rather than merely printing forceTree's unit result. The added
rendering/validation is included. Demand tests verify unmatched fields remain
unforced, lookup boundaries and duplicate rejection. Dynamic insertion, search,
structural sharing and forcing are source hypotheses until measured. References:
original submission/mail and the nofib survey; historical timing tables are
provenance, not current comparative measurements.

[Complete provenance](treejoin-lazy/PROVENANCE.md).

## treejoin-strict

Join the same persistent relation trees with eager fields and insertion.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/treejoin/Main.hs`, relation files 27000.1/27000.2
and the retained MAIL. The 1993 submission is from kh@dcs.gla.ac.uk; the full
individual author/licence and dataset notice are not specified, recorded as gaps.
Original source, data, build settings and mail are retained with SHA256 identities.

Keep the unbalanced persistent binary-tree representation, boundary keys,
insertion/duplicate-key rules, key lookup and right-before-left join accumulation.
The left relation is keyed by its first field; its third field looks up the first
field of the right relation. Joined values have the original five fields. Both
variants instantiate one algorithm with eager or memoized suspension adapters.
The lazy adapter delays numeric accumulation, tree roots/branches and stored
fields: unmatched records leave unused fields unforced. The strict adapter
forces these operations eagerly; allocation, work order and retention differ.
No balanced tree, hash join or alternative relational algorithm is substituted.

SML reads complete file byte strings instead of Haskell lazy file characters;
numeric/tree demand is preserved after that input representation change. Inputs
are positive ASCII integers fitting supported widths. Profiles take the original
first 125/2000/all27000 records from both files without reordering or regeneration.
Subsets retain their origin but change size/selectivity; they contain 0/28/2700
matches. Large preserves the original complete workload and build heap settings
remain recorded separately. No universal large SML execution is claimed.

The full sorted five-field join is checked against original GHC with a read-only
observer and independent dictionary-based relational joins. Every result field
is consumed rather than merely printing forceTree's unit result. The added
rendering/validation is included. Demand tests verify unmatched fields remain
unforced, lookup boundaries and duplicate rejection. Dynamic insertion, search,
structural sharing and forcing are source hypotheses until measured. References:
original submission/mail and the nofib survey; historical timing tables are
provenance, not current comparative measurements.

[Complete provenance](treejoin-strict/PROVENANCE.md).

## spellcheck-lazy

Check Latin-1 words against the original weight-balanced set with streamed tokens.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/spellcheck/spellcheck.hs`, words dictionary and the
input generated by concatenating it ten times. Individual driver/dictionary
licences and authors are unspecified, recorded as provenance gaps. The copied
Data.Set used by reference GHC is containers 0.6.7 at
9f4a93604c66a5e605ce46fc30003b71802b3cfd, with its BSD notice/licence retained.

Preserve Data.Set's cached subtree sizes, weight balancing (delta3, ratio2),
special rotations, ascending-run construction path and fallback insertion. This
is not an AVL-tree substitution. Only operations used by fromList/member are
ported; the full library source is retained. Portable SML has no immutable
pointer-equality primitive, so its duplicate-value optimization is omitted while
key replacement semantics remain unchanged. Byte strings replace Haskell lists
of Unicode characters; byte order matches Latin-1 code-point order for these data.
Latin-1 whitespace includes NEL/NBSP explicitly. Original non-ASCII bytes are
preserved rather than misread as UTF-8; the dictionary has 241 such bytes.

Both variants build the same set. Lazy token heads/spines are memoized and
consumed while checking; strict creates the complete token list before filtering.
SML materializes each complete input file earlier than Haskell lazy hGetContents;
this representation/retention change is explicit. All dictionary members and
set balance/size are additionally validated. The returned missing-word sequence
is checked completely, with actual dictionary/input/missing counts consumed.

Profiles use the first125/5000/all98569 dictionary lines and ten concatenated
copies as input, preserving source order/bytes and the original input-generation
rule. Upstream input is retained verbatim for large. Prefixes contain124/4999
actual words because blank lines are retained. Original GHC and an independent
set check agree. Tree shape matches the pinned GHC set on the smoke dictionary;
other tests cover duplicates, reversed/mixed order and missing words. Large SML
execution is not universally claimed. Balancing, token retention, string
representation and pointer-identity optimization are source hypotheses until
measured. References: retained Data.Set/source notices and nofib survey.

[Complete provenance](spellcheck-lazy/PROVENANCE.md).

## spellcheck-strict

Check eagerly materialized Latin-1 tokens against the same weight-balanced set.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/spellcheck/spellcheck.hs`, words dictionary and the
input generated by concatenating it ten times. Individual driver/dictionary
licences and authors are unspecified, recorded as provenance gaps. The copied
Data.Set used by reference GHC is containers 0.6.7 at
9f4a93604c66a5e605ce46fc30003b71802b3cfd, with its BSD notice/licence retained.

Preserve Data.Set's cached subtree sizes, weight balancing (delta3, ratio2),
special rotations, ascending-run construction path and fallback insertion. This
is not an AVL-tree substitution. Only operations used by fromList/member are
ported; the full library source is retained. Portable SML has no immutable
pointer-equality primitive, so its duplicate-value optimization is omitted while
key replacement semantics remain unchanged. Byte strings replace Haskell lists
of Unicode characters; byte order matches Latin-1 code-point order for these data.
Latin-1 whitespace includes NEL/NBSP explicitly. Original non-ASCII bytes are
preserved rather than misread as UTF-8; the dictionary has 241 such bytes.

Both variants build the same set. Lazy token heads/spines are memoized and
consumed while checking; strict creates the complete token list before filtering.
SML materializes each complete input file earlier than Haskell lazy hGetContents;
this representation/retention change is explicit. All dictionary members and
set balance/size are additionally validated. The returned missing-word sequence
is checked completely, with actual dictionary/input/missing counts consumed.

Profiles use the first125/5000/all98569 dictionary lines and ten concatenated
copies as input, preserving source order/bytes and the original input-generation
rule. Upstream input is retained verbatim for large. Prefixes contain124/4999
actual words because blank lines are retained. Original GHC and an independent
set check agree. Tree shape matches the pinned GHC set on the smoke dictionary;
other tests cover duplicates, reversed/mixed order and missing words. Large SML
execution is not universally claimed. Balancing, token retention, string
representation and pointer-identity optimization are source hypotheses until
measured. References: retained Data.Set/source notices and nofib survey.

[Complete provenance](spellcheck-strict/PROVENANCE.md).

## cse

Label expression trees with pure state computations and share equal subtrees.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/cse/Main.hs` and StateMonad.hs. Mark P. Jones,
1992. The source's history/explanations and example diagrams are retained; an
individual licence notice is unspecified. Source/build identities are recorded.

Preserve the pure state-function representation s -> (s,value), bind/map-list,
left-to-right preorder labels, tree-to-graph conversion, right fold over the graph,
closure-based label renaming and first matching equivalent subtree selection.
No mutable label counter or hash-consing algorithm replaces the source's state
and association-list operations. Complete graph labels, symbols and child-label
lists agree with original GHC and independent bottom-up subtree interning.
The SML state tuple is explicitly closed for portability across the hosts.

The original six expression examples are retained. Main selects take(i mod6)
for i=1..n, so the sixth example is never selected by the timed loop; this
stopping behavior is preserved, while all six golden graphs are independently
reviewed. SML eagerly represents the small input trees/lists; all selected output
graphs are fully forced as original rnf requires. Added full-graph rendering and
validation replaces discarded unit outputs, and actual node totals are consumed.
Unused pretty-printers/unGraph helpers are retained in the original but not added
to the runnable kernel. The added check work is included.

Profiles use6/120/30000 iterations; large preserves original FAST, and original
normal300000/slow1500000 remain in Makefile. Large execution is not universally
claimed. Closure specialization, state tuple representation, label renaming and
shared graph objects are source-derived hypotheses until measured. References:
original Jones explanation/example graphs and nofib survey.

[Complete provenance](cse/PROVENANCE.md).

## power

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/power/Main.hs`.

### Algorithm, history and variants

Compute exact rational identities and integer generating functions with memoized series.

The GC variant prints rational coefficients for two identities and Integer
coefficients for Catalan/tree series. Smoke/normal/large select 5/12/50
coefficients once; large preserves original FAST 50, while NORM 80/SLOW 90 remain
recorded. IntInf preserves arbitrary precision. The spectral variant differs
in coefficient types, repetition, forcing and output, and is named power-nofib.

Douglas McIlroy's *Power series, power serious*, JFP 9(3), May 1999, is
identified in the original header. The individual program licence is unspecified;
this provenance gap remains explicit. Original source/builds/fixtures are retained
with SHA256 identities. Exact rational normalization follows the pinned GHC
9.4.7 base Integer Ratio operations; the library source, revision and notice are
retained separately and do not license the nofib program.

### Translation and runtime questions

Preserve finite Pz, memoized coefficient/spine demand and sharing, scalar
multiplication, the original product recurrence (including x*fs*gs), leading-zero
division, composition, reversion, differentiation, integration and square roots.
Integration emits zero before inspecting its operand, as required by the source's
differential-equation construction. Sine/cosine, geometric, Catalan and tree
series remain shared recursive knots. SML97 references implement delays; no
finite-array algebra or eager infinite-series variant replaces the algorithm.
Only operations used by the workload and finite boundary checks are ported; the
full original module remains available. Fractional operations are not applied
to the integer instantiation. Negative numerators retain GHC Show parentheses.

### Inputs, validation and references

Every requested coefficient is rendered and checked exactly. Original GHC
and read-only observers agree with all fixtures. Independent analytic identities
supply the two zero series; binomial Catalan counts supply the two combinatorial
series. Semantic checks cover finite-product length, derivative/integral values,
leading-zero division, demand before operand inspection and coefficient sharing.
Added rendering/validation work is included. Rational normalization, delay
closures, prefix retention and recursive sharing are source-derived diagnostic
hypotheses until measured. Large SML execution is not universally claimed.

[McIlroy, Power series, power serious](https://doi.org/10.1017/S0956796899003299)
motivates exact compositional streams. The concrete recurrence/forcing decisions
above come from the retained source; they are not measured performance findings.

[Complete provenance](power/PROVENANCE.md).

## power-nofib

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/power/Main.hs`.

### Algorithm, history and variants

Force rational power-series identities and generating functions repeatedly.

The spectral variant uses Rational for all four lists due to rnfListOfRational
and repeats 200 times. Positive counts preserve salt=min0 p and exponent2.
Smoke5x1 bounds routine work; normal14x200 preserves original FAST, and
large26x200 preserves original NORM. Original SLOW 36 remains recorded.
Rendering/validation additionally consumes results discarded by original rnf.
The GC variant power retains integer generating functions and one printed run.

Douglas McIlroy's *Power series, power serious*, JFP 9(3), May 1999, is
identified in the original header. The individual program licence is unspecified;
this provenance gap remains explicit. Original source/builds/fixtures are retained
with SHA256 identities. Exact rational normalization follows the pinned GHC
9.4.7 base Integer Ratio operations; the library source, revision and notice are
retained separately and do not license the nofib program.

### Translation and runtime questions

Preserve finite Pz, memoized coefficient/spine demand and sharing, scalar
multiplication, the original product recurrence (including x*fs*gs), leading-zero
division, composition, reversion, differentiation, integration and square roots.
Integration emits zero before inspecting its operand, as required by the source's
differential-equation construction. Sine/cosine, geometric, Catalan and tree
series remain shared recursive knots. SML97 references implement delays; no
finite-array algebra or eager infinite-series variant replaces the algorithm.
Only operations used by the workload and finite boundary checks are ported; the
full original module remains available. Fractional operations are not applied
to the integer instantiation. Negative numerators retain GHC Show parentheses.

### Inputs, validation and references

Every requested coefficient is rendered and checked exactly. Original GHC
and read-only observers agree with all fixtures. Independent analytic identities
supply the two zero series; binomial Catalan counts supply the two combinatorial
series. Semantic checks cover finite-product length, derivative/integral values,
leading-zero division, demand before operand inspection and coefficient sharing.
Added rendering/validation work is included. Rational normalization, delay
closures, prefix retention and recursive sharing are source-derived diagnostic
hypotheses until measured. Large SML execution is not universally claimed.

[McIlroy, Power series, power serious](https://doi.org/10.1017/S0956796899003299)
motivates exact compositional streams. The concrete recurrence/forcing decisions
above come from the retained source; they are not measured performance findings.

[Complete provenance](power-nofib/PROVENANCE.md).

## n-body

Advance five bodies in a contiguous mutable array and validate energies and final state.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/n-body`.

### Algorithm and history

The Computer Language Benchmarks Game implementation is contributed by Olof
Kraigher and Don Stewart. The pinned source retains its compiler pragmas and
historical GCC note. It supplies no individual licence; this gap remains explicit.
The full source and build settings are retained with SHA256 identities.

### Variants and translation

Preserve all 35 Double slots (three position values, three velocity values, one mass for each body),
right-fold momentum initialization, pair visitation, and immediate velocity
updates. Each body's position is updated after its pairs, as in the original.
Energy subtracts pair potentials before adding that body's kinetic energy.
Portable SML arrays replace pointer/malloc storage; checked indexing and tuple
vectors replace unsafe pointer arithmetic and Haskell Vector3 values. The FFI
only supplies storage access here; no foreign computation or runtime facility
is required. All numerical constants, timestep 0.01, and solar-mass formula remain.
The classic nbody uses immutable body records and different update/reduction
structure, so it remains a separate established-name workload.

### Inputs, validation and references

Profiles select 10/10000/500000 steps. Large preserves original FAST 500000;
original NORM 5000000/SLOW 25000000 and optional50000000 remain recorded.
Read-only GHC observers give both energies and all 35 state values at17 digits.
An independent Newtonian pair-force integrator updates all positions after the
pair sweep and checks the complete fixtures. SML accepts only finite values
within absolute 2e-10 plus relative 2e-10 error per value for smoke/normal.
Large uses absolute 2e-8 plus relative 2e-10: the independent integrator differs
from GHC by up to 1.86e-9 after 500000 steps, versus 3.26e-12 after 10000.
Bounds are explicit profile arguments and both reject deliberate perturbations. This bounds differences
in binary64 evaluation while detecting perturbations in energy or individual
state fields; targeted checks reject truncation, nonfinite values and deviations
outside the bound. The chosen bound is tighter than the original nine-decimal
energy output's quantization near zero. Complete-state validation is added work.
Large SML execution is not universally claimed.

Mutable storage, boxing of real tuples, checked access, reduction order and
numerical operations are source-derived diagnostic hypotheses until measured.
References: retained Kraigher/Stewart source and the suite's
[Benchmarks Game literature entry](../literature.md).

[Complete provenance](n-body/PROVENANCE.md).

## fasta

Generate deterministic FASTA DNA with binary32 distribution tables and mutable line buffers.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/fasta`.

### Algorithm and history

Bryan O'Sullivan contributed the Haskell Benchmarks Game implementation. Mr
Ledrug contributed the independent C generator used by nofib's boot.sh. Both
sources, build scripts, parameters and notices are retained with SHA256 identities.
Their individual licence terms are unspecified in the pinned files; this remains
an explicit provenance gap rather than a GHC compiler-licence assignment.

### Variants and translation

Preserve the cyclic ALU sequence, lengths2n/3n/5n,60-column lines, seed 42,
modulus 139968, multiplier 3877, increment 29573, and seed carried between the two
random sequences. Preserve cumulative Float probabilities, inclusive lookup
cutoffs floor(modulus*p+1), and table clamping. Every literal/add/multiply/add
is explicitly rounded to binary32 using24 significand bits and ties to even.
Only positive normal finite values in the original table builder occur; the
helper is not a general substitute for all IEEE special/subnormal behavior.
All table cutoffs match an independent binary32 reference. The generator's
integer product fits31-bit signed Int for every permitted seed.

Portable SML strings replace strict/lazy ByteStrings and the cyclic byte chunks;
a checked60-character mutable array replaces the CString line buffer. Table
construction and array mutation remain; no direct probabilistic scan replaces
lookup. The complete generated output is collected in SML strings instead of
streamed through stdout, changing retention and copy costs. No foreign runtime
or computation is needed. These representation/evaluation changes are explicit.

### Inputs, validation and references

Profiles select n=13/75000/750000; large preserves original FAST 750000.
Original NORM 7500000/SLOW 25000000 remain recorded. The partial smoke lines
exercise remainder handling. Complete outputs agree with unchanged GHC and
nofib's independent C reference for every selected profile. Every header, base,
newline and seed-dependent character is checked. Semantic tests cover the
reviewed distribution cutoffs and halfway rounding. Added collection/validation
is included; large SML execution is not universally claimed.

Binary32 table construction, byte representation, buffer mutation, slicing/copying
and input/output retention are source-derived hypotheses until measured.
References: the retained O'Sullivan/Ledrug implementations and
[the literature survey](../literature.md).

[Complete provenance](fasta/PROVENANCE.md).

## reverse-complement

Reverse-complement FASTA records using a growing mutable buffer and in-place swaps.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/reverse-complement`.

### Algorithm and history

Louis Wasserman contributed the Haskell Benchmarks Game implementation.
The retained boot.sh generates input with Mr Ledrug's fasta-c.c and expected
output with the separately retained revcomp-c.c. Original sources/build scripts
and notices have SHA256 identities. Individual licence terms are unspecified
in these pinned program files; this gap remains explicit.

### Variants and translation

Preserve the82-byte reader, first-header search,1024-byte initial buffer,
doubling capacity, reset/reuse on record boundaries,200-entry identity/complement
table, and in-place inward swap loop. Keep lowercase/uppercase ambiguity mappings,
headers and newline positions. SML checked character arrays replace malloc,
realloc, pointer access and memchr; the input file is materialized earlier as
one byte string. Rendering collects completed records instead of hPutBuf output,
changing retention/copying costs. No alternative record parser or sequence list
replaces the buffering and swap algorithm; no foreign runtime feature is needed.

The original reader handles only the first '>' in each82-byte chunk. Tiny input
n=13 packs multiple headers into a chunk and original GHC output disagrees with
independent FASTA reversal. That unsuitable smoke candidate was rejected;
selected n=100 has sufficiently spaced headers. This source limitation is
preserved and documented rather than silently repairing the benchmark.

### Inputs, validation and references

Profiles are generated with original fasta-c.c at n=100/75000/750000. The same
size parameter/input distribution is retained; source FAST 5000000 and
NORM/SLOW 50000000 remain recorded, including the C parser-overflow warning in
Makefile. Inputs/expected outputs are fixed files rather than generated during
measurement. All selected fixtures agree with unchanged GHC, original C, and an
independent per-record complement/reversal oracle that preserves line positions.
Every output byte is checked. Boundary tests cover all mappings, odd centers,
line positions, growth beyond1024 and headers crossing reader chunks. Added full
output collection/validation is included; large SML execution is not universally
claimed. Buffer growth, copying, mutation and byte representation are hypotheses
until measured. References: retained source/boot scripts and
[the literature survey](../literature.md).

[Complete provenance](reverse-complement/PROVENANCE.md).

## rec_seq_evenodd

Alternate mutual tail calls and preserve short-circuit parity evaluation.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_evenodd.ml`,
executable `rec_seq_evenodd.exe`. Original source, executable-group dune manifest and
SHA256 identities are retained. No individual author is stated in the source;
the aggregate public-domain notice is retained in LICENSE. The sequential
program uses no effects; its effect-based sibling remains separately inventoried
with the required effect-handler runtime capability as its blocker.

## Algorithm and variants

Mutual tail recursion for parity, with a short-circuit even/odd expression.

Preserve even(0)=true, odd(0)=false, alternating tail calls, and
`even n andalso not(odd n)`. An odd input skips the odd call, as OCaml && does.
The classic MLton even-odd driver evaluates both parity functions to check
agreement, so this evaluation difference remains a separately named workload.
Smoke uses one iteration at 33 (false), normal two at 100000 (true), and large
preserves the original two at 500000000. All inputs/intermediates fit 31 bits.
The result counts true repetitions rather than discarding the upstream OR
accumulator and printing only its last value. Every repetition remains consumed.
Parity modulo 2 independently supplies results0/2/2, and unchanged OCaml agrees
with the individual smoke/normal booleans. No universal large execution is claimed.
Tail-call handling, mutual recursion and short-circuit work are source-derived
performance questions until measured.

## Translation, inputs and validation

The kernels are strict SML97. Recursive arithmetic operands follow SML's
left-to-right evaluation instead of OCaml's usual right-to-left order; these
pure kernels have no operand side effects, but call order/stack behavior can
differ. Fixed checked runtime arguments replace launcher defaults/fallbacks.
The original Sys.opaque_identity barrier is replaced by consumed, validated
results rather than a new compiler primitive. Drivers record the additional
checking/accumulation work. Literature anchors are the retained source links,
Sandmark's suite sources, and the shared literature survey.

[Complete provenance](rec_seq_evenodd/PROVENANCE.md).

## rec_seq_motzkin

Compute Motzkin numbers with unmemoized recursive products and sums.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_motzkin.ml`,
executable `rec_seq_motzkin.exe`. Original source, executable-group dune manifest and
SHA256 identities are retained. No individual author is stated in the source;
the aggregate public-domain notice is retained in LICENSE. The sequential
program uses no effects; its effect-based sibling remains separately inventoried
with the required effect-handler runtime capability as its blocker.

## Algorithm and variants

Compute Motzkin numbers through repeated unmemoized recursive products.

Preserve the n<=1 base case, recursive motz(n-1), ascending convolution
sum, and repeated recursive products. No memoization or dynamic programming
replaces this intentionally recursive kernel. Smoke/normal select one at 6 and
two at 15; large preserves the original four at 21. All kernel results and original
accumulators fit 31 bits. The SML driver consumes every repetition in an IntInf
sum rather than discarding the original accumulator and printing only the last
value. The combinatorial formula sum_k binomial(n,2k)*Catalan(k) independently
gives 51/310572/142547559, and unchanged OCaml agrees. Summed fixtures are
51/621144/570190236. The source links [OEIS A001006](https://oeis.org/A001006) and describes nonintersecting
chords; those links/wording remain in the pristine source. Repeated calls,
branching and intermediate integer lifetimes are hypotheses until measured.
No universal large SML execution is claimed.

## Translation, inputs and validation

The kernels are strict SML97. Recursive arithmetic operands follow SML's
left-to-right evaluation instead of OCaml's usual right-to-left order; these
pure kernels have no operand side effects, but call order/stack behavior can
differ. Fixed checked runtime arguments replace launcher defaults/fallbacks.
The original Sys.opaque_identity barrier is replaced by consumed, validated
results rather than a new compiler primitive. Drivers record the additional
checking/accumulation work. Literature anchors are the retained source links,
Sandmark's suite sources, and the shared literature survey.

[Complete provenance](rec_seq_motzkin/PROVENANCE.md).

## rec_seq_sudan

Evaluate the nested Sudan recurrence with explicit wide integer values.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_sudan.ml`,
executable `rec_seq_sudan.exe`. Original source, executable-group dune manifest and
SHA256 identities are retained. No individual author is stated in the source;
the aggregate public-domain notice is retained in LICENSE. The sequential
program uses no effects; its effect-based sibling remains separately inventoried
with the required effect-handler runtime capability as its blocker.

## Algorithm and variants

Evaluate the Sudan recurrence with explicit wide integer values.

Preserve the order-zero sum, y=0 base case, shared inner result and
nested recursive call. The original OCaml 63 -bit integer result 15569256417
exceeds31 bits. Portable IntInf preserves the selected exact values on every
SML host. This changes representation/allocation relative to OCaml's machine
integers and is explicitly included; it is not an OCaml machine-integer timing
comparison. All supported inputs (order/x/y from 0 to2) and repetition counts
up to10000000 remain within the original 63 -bit result/accumulator range, so
no modular overflow is lost. No broader unbounded OCaml equivalence is claimed.
Smoke selects(1,1,2,2), normal(1000,2,2,2), and large preserves original
(10000000,2,2,2). Every repetition is summed instead of discarding the original
accumulator. The independently derived order-one identity
F(1,x,y)=2^y*(x+2)-y-2 and iterative order-two substitution give12 and 15569256417;
unchanged OCaml agrees with those individual values. Full fixtures are 12,
15569256417000 and 155692564170000000. The source's Sudan-function link is retained.
Wide arithmetic costs, nested calls, shared inner values and repeated execution
are source-derived hypotheses until measured. No universal large execution is claimed.

## Translation, inputs and validation

The kernels are strict SML97. Recursive arithmetic operands follow SML's
left-to-right evaluation instead of OCaml's usual right-to-left order; these
pure kernels have no operand side effects, but call order/stack behavior can
differ. Fixed checked runtime arguments replace launcher defaults/fallbacks.
The original Sys.opaque_identity barrier is replaced by consumed, validated
results rather than a new compiler primitive. Drivers record the additional
checking/accumulation work. Literature anchors are the retained source links,
Sandmark's suite sources, and the shared literature survey.

[Complete provenance](rec_seq_sudan/PROVENANCE.md).

## rec_seq_fib

Compute strict Fibonacci with Sandmark's retained repetition profiles.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_fib.ml`,
executable `rec_seq_fib.exe`.

## Algorithm, history and variants

Compute strict Fibonacci with Sandmark's retained repetition profiles.

The individual author is not stated. The source, dune executable manifest,
and SHA256 identities are retained alongside the aggregate public-domain notice.
This is the sequential member; its effect-based sibling remains inventoried
with effect-handler support as its blocker. SML97 follows left-to-right operand
evaluation instead of OCaml's usual right-to-left evaluation. These kernels are
pure, so values agree while call order/stack behavior can differ. Consumed
runtime arguments/results replace Sys.opaque_identity without adding compiler
features. Every repetition contributes to a checked IntInf sum rather than
discarding the upstream accumulator and printing only its last value.

## Translation, inputs and validation

The 0/1 base cases and binary recurrence match classic MLton fib exactly.
Both named drivers share one implementation in shared/fib.sml. This kernel is
extracted unchanged from the existing classic port; the two upstream sources
and launchers remain available. Smoke/normal use one call at 20 and two at 30;
large preserves original four at 40, versus MLton's original 41. Kernel values
and original accumulators fit 31 bits. Iterative Fibonacci independently gives
6765/832040/102334155; unchanged OCaml agrees with the individual values.
Summed fixtures are 6765/1664080/409336620. Exponential calls, strict operand
order and stack behavior are source-derived questions until measured. See the
classic Fibonacci provenance and the shared literature survey. Large SML
execution is not universally claimed.

[Complete provenance](rec_seq_fib/PROVENANCE.md).

## rec_seq_tak

Run the shared strict Takeuchi kernel with Sandmark's curried-source input profiles.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/multicore-effects/rec_seq_tak.ml`,
executable `rec_seq_tak.exe`.

## Algorithm, history and variants

Run the shared strict Takeuchi kernel with Sandmark's curried-source input profiles.

The individual author is not stated. The source, dune executable manifest,
and SHA256 identities are retained alongside the aggregate public-domain notice.
This is the sequential member; its effect-based sibling remains inventoried
with effect-handler support as its blocker. SML97 follows left-to-right operand
evaluation instead of OCaml's usual right-to-left evaluation. These kernels are
pure, so values agree while call order/stack behavior can differ. Consumed
runtime arguments/results replace Sys.opaque_identity without adding compiler
features. Every repetition contributes to a checked IntInf sum rather than
discarding the upstream accumulator and printing only its last value.

## Translation, inputs and validation

The strict Takeuchi recurrence matches the classic kernel. The curried
OCaml calls become tuple calls to shared/tak.sml, already used by classic
and strict nofib ports. No duplicate algorithm implementation is added.
Both source histories and their profiles remain. Smoke/normal use one call
at(18,12,6) and(24,16,8); large preserves original(40,20,11), which differs
from MLton's original(33,22,11). Inputs, intermediate values and accumulators
fit 31 bits. An independent memoized recurrence supplies 7/9/12 while the
benchmark remains unmemoized; unchanged OCaml supplies the same values.
Calls, branching, evaluation order and input-shaped recursion are hypotheses
until measured. Gabriel's recursive-benchmark survey is a family reference,
not attribution of this particular source. Large SML execution is not
universally claimed.

[Complete provenance](rec_seq_tak/PROVENANCE.md).

## lazy_primes

Sieve primes through streams with strict heads and memoized lazy tails.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/simple-tests/lazy_primes.ml`.

The individual author is unspecified. Original source, dune declarations,
SHA256 identities and the aggregate public-domain notice are retained. Kernels
and translation support are SML97. Compiler/runtime explanations below come
from source inspection and remain performance hypotheses until measured.

## Algorithm, history and variants

Keep Cons(strict head, memoized tail), the infinite integer stream from 2,
removing filter, and successive sieve layers. The ordinal is one-based.
`take 1 (drop (nth-1) primes)` forces the next tail even though take 0 returns
empty: preserve this extra demand from strict OCaml arguments. This differs
from the nofib lazy-head/lazy-spine ports, which retain their own names and
forcing decisions. No array sieve, trial division or eager infinite list
replaces the algorithm. Unused take/drop/zip helpers remain in pristine source.

## Translation, inputs and validation

BenchLazy preserves memoized tails and exceptions. Source heads remain strict;
no separate head delay is added. All selected values fit 31 bits. Fixed profiles
use ordinals 10/1000/5000; normal/large preserve entries in micro_multicore.json,
and the other original ordinals 2000..10000 are retained in reviewed config
extracts with complete file identities. Results29/7919/48611 agree with unchanged
OCaml and independent trial division. Semantic checks verify the additional
tail demand, memoization, predicate-removing filter and prime prefixes. Stream
retention, sieve closures and demand are hypotheses until measured. Large SML
execution is not universally claimed. References: retained source/configuration
and the shared nofib/Sandmark literature survey.

[Complete provenance](lazy_primes/PROVENANCE.md).

## lazylist

Allocate a strict list of independent lazy heads sharing one zero cell.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/simple-tests/lazylist.ml`.

The individual author is unspecified. Original source, dune declarations,
SHA256 identities and the aggregate public-domain notice are retained. Kernels
and translation support are SML97. Compiler/runtime explanations below come
from source inspection and remain performance hypotheses until measured.

## Algorithm, history and variants

Preserve add_lazy's unchanged original list parameter: every new delay computes
1 plus the same original zero, not the preceding new head. The strict spine has
length n+1, and only its first delay is forced by each original iteration.
There is no incrementing lazy chain. Preserve inclusive iterations 0..iterations
and create a fresh base/list for each repetition. Unused delays remain unforced.

## Translation, inputs and validation

BenchLazy supplies SML97 memoization. The program additionally walks the
allocated spine before forcing its head, preventing elimination of the workload
when replacing Sys.opaque_identity with consumption. This adds traversal work
and can affect liveness; it does not force the other head delays. Actual lengths
and head values are summed separately. Smoke(length 10,iterations 0), normal
(1000,10000), and large(100000,100) give11:1,10011001:10001 and 10100101:101.
Normal/large preserve original run_config.json configurations; the other
10000/1000 configuration and bytecode settings remain in reviewed extracts.
Original read-only OCaml observers and independent length/head identities agree.
Semantic tests verify pending heads, their independent shared-zero references,
and zero-length extension. Closure capture, memoization, strict spine allocation,
list depth and retention are hypotheses until measured. Large SML execution is
not universally claimed. References: retained source/configs and literature survey.

[Complete provenance](lazylist/PROVENANCE.md).

## sequence_cps

Compose CPS map/filter layers and consume them with a mutable callback fold.

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/sequence/sequence_cps.ml`.

The individual author is unspecified. Original source, dune declarations,
SHA256 identities and the aggregate public-domain notice are retained. Kernels
and translation support are SML97. Compiler/runtime explanations below come
from source inspection and remain performance hypotheses until measured.

## Algorithm, history and variants

Preserve the Sequence state/unfolder record, continuation-based map/filter,
three callback cases, and original mutable fold_2. The pipeline maps x+3,
filters even values with bitwise and 1, squares, and folds addition. The outer
loop includes 0..n. No fused direct sum or pull iterator replaces the CPS layers.
The used state is int and payload integer; unfold's continuation result is bool
because fold_2 is the selected implementation. Specialize those concrete types
for SML97 rather than requiring unused existential/GADT/rank-polymorphic cases.
Unused fold_1 remains in the original source.

## Translation, inputs and validation

Original OCaml 63-bit sums exceed31 bits. Portable IntInf retains every selected
value, including bitwise filtering, without overflow through n=10000; its
representation/allocation differs from OCaml machine integers and is explicit.
Profiles n=10/1000/10000 preserve the size argument; large uses the original
run_config.json and bytecode setting 10000. All results agree with unchanged
OCaml and independent sum over odd x<n of (n-x)*(x+3)^2, retaining both inclusive
outer bounds and pipeline order. Semantic checks cover empty/skip/yield/done,
state advancement, exact wide sums and inclusive bounds. The optional
OCAML_GC_STATS file observer is replaced by the suite's separate statistics
mode; no GC facility is added to the kernel. References: original source and
Sandmark configuration/literature. Closure layers, callback specialization,
mutable state and wide arithmetic are source-derived hypotheses until measured.
Large SML execution is not universally claimed.

[Complete provenance](sequence_cps/PROVENANCE.md).

## compress-lazy

Compress bytes with memoized persistent prefix-tree LZW.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/compress/Main.hs` and its required modules.

## History and notices

Paul Sanders, Systems Research Division, British Telecom Laboratories,1992,
is named in Main/Encode/BinConv and the retained correspondence. The program
cites Terry A. Welch's1984 compression paper. Original modules, build settings,
input/output files, README and MAIL have retained notices and SHA256 identities.
No individual program/dataset redistribution notice is supplied in the pinned
files; this remains an explicit provenance gap. README identifies John van
Groningen's separate Lzw/C/Clean alternatives, which the default driver does
not run; they remain separately inventoried rather than treated as duplicates.

## Algorithm and known variants

Preserve fixed 12-bit LZW with the persistent prefix tree,256 initial byte codes,
next code 256, dictionary freeze at 4096, and code_string's exact recursive update
and EOF rules. The initial alphabet uses the original foldr insertion order over
all 256 listed keys: despite the source's balanced-list description, the resulting
root is 255. This source-derived shape is checked against original GHC.
Packing pairs emits x div16, (x rem16)*16+y div256, y rem256. A final single code
emits n div16,n rem16: its trailing nibble is unshifted. Keep this source format;
no standard-header/variable-width compressor or mutable dictionary replaces it.

## SML translation and runtime questions

Both variants instantiate one SML97 algorithm with suspension adapters. The
lazy adapter memoizes code heads/spines, key/value/extension fields, shared
code_string results, path updates and next-code arithmetic. EOF can leave the
unused updated table/counter unforced. The strict adapter materializes these
updates and finite code/output streams eagerly, changing allocation and retention.
All encoder/counter/packing values fit 31 bits for the selected files. Source
hashing retains wrapping signed 64-bit GHC Int semantics through Word64; the
added repetition sum is IntInf. No host-specific arithmetic workaround is used.

BinIO reads exact bytes and fixtures. Full SML byte strings plus cursor indices
replace Haskell's lazy input character lists; compressed output is materialized
before hash/checking. This changes representation, demand of file contents,
copying and retention. Initial prefix tables remain shared across repetitions.
All31 expected cut outputs are preloaded once per run; every compressed byte is
checked before hashing. Added fixture I/O, full-byte comparison and accumulated
hashes replace 200 printed hashes and are explicitly included in measurements.
Prefix sharing, delayed copies, branch/search depth, dictionary saturation and
forcing remain source-derived performance questions until measured.

## Inputs, validation and references

Smoke takes the first 64 bytes of the original FAST input and one repetition.
Normal retains FAST 1944 bytes with 200 repetitions; large retains NORM 10755 bytes
with 200 repetitions. Original SLOW 39864 bytes and fixtures remain available in
upstream provenance. Every iteration preserves truncation by i mod31. The
Makefile identifies enwik8 as input origin; original byte identities are pinned,
not reconstructed from a newer Wikipedia dump. UTF-8 dataset bytes are compressed
as bytes, matching the original binary input mode, rather than decoded/reencoded.
[Mahoney's corpus description](https://mattmahoney.net/dc/textdata.html) identifies
enwik8's parent as a 2006 Wikipedia dump; it does not resolve the individual notice
gap in these copied subsets.

Original GHC and an independent dictionary-map LZW plus the exact packing rule
agree on all 31 cut byte fixtures per profile. Normal/large all 200 hash samples
also agree with unchanged GHC. Boundary tests cover empty/odd/full-byte inputs,
initial table order, unneeded EOF counter demand and dictionary freeze using
fixed Word32 counter-generator data. Primary hosts/Rune validate selected smoke
and normal profiles. The combined two-functor semantic test crashes ML Kit 4.7.23
with StatObject.instance_with_types.wrong number of types; standalone benchmark
smoke programs compile/pass there. That test compile failure is recorded, not
worked around or accepted as a result. Large SML execution is not universally
claimed.

References: [Welch, A Technique for High-Performance Data Compression](https://doi.org/10.1109/MC.1984.1659158),
Computer 17(6),8-19(1984); retained Sanders correspondence/implementation and
[nofib literature survey](../literature.md). Paper ancestry, inspected source
behavior, and measured count findings remain distinct.

[Complete provenance](compress-lazy/PROVENANCE.md).

## compress-strict

Compress bytes with eager persistent prefix-tree LZW.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/compress/Main.hs` and its required modules.

## History and notices

Paul Sanders, Systems Research Division, British Telecom Laboratories,1992,
is named in Main/Encode/BinConv and the retained correspondence. The program
cites Terry A. Welch's1984 compression paper. Original modules, build settings,
input/output files, README and MAIL have retained notices and SHA256 identities.
No individual program/dataset redistribution notice is supplied in the pinned
files; this remains an explicit provenance gap. README identifies John van
Groningen's separate Lzw/C/Clean alternatives, which the default driver does
not run; they remain separately inventoried rather than treated as duplicates.

## Algorithm and known variants

Preserve fixed 12-bit LZW with the persistent prefix tree,256 initial byte codes,
next code 256, dictionary freeze at 4096, and code_string's exact recursive update
and EOF rules. The initial alphabet uses the original foldr insertion order over
all 256 listed keys: despite the source's balanced-list description, the resulting
root is 255. This source-derived shape is checked against original GHC.
Packing pairs emits x div16, (x rem16)*16+y div256, y rem256. A final single code
emits n div16,n rem16: its trailing nibble is unshifted. Keep this source format;
no standard-header/variable-width compressor or mutable dictionary replaces it.

## SML translation and runtime questions

Both variants instantiate one SML97 algorithm with suspension adapters. The
lazy adapter memoizes code heads/spines, key/value/extension fields, shared
code_string results, path updates and next-code arithmetic. EOF can leave the
unused updated table/counter unforced. The strict adapter materializes these
updates and finite code/output streams eagerly, changing allocation and retention.
All encoder/counter/packing values fit 31 bits for the selected files. Source
hashing retains wrapping signed 64-bit GHC Int semantics through Word64; the
added repetition sum is IntInf. No host-specific arithmetic workaround is used.

BinIO reads exact bytes and fixtures. Full SML byte strings plus cursor indices
replace Haskell's lazy input character lists; compressed output is materialized
before hash/checking. This changes representation, demand of file contents,
copying and retention. Initial prefix tables remain shared across repetitions.
All31 expected cut outputs are preloaded once per run; every compressed byte is
checked before hashing. Added fixture I/O, full-byte comparison and accumulated
hashes replace 200 printed hashes and are explicitly included in measurements.
Prefix sharing, delayed copies, branch/search depth, dictionary saturation and
forcing remain source-derived performance questions until measured.

## Inputs, validation and references

Smoke takes the first 64 bytes of the original FAST input and one repetition.
Normal retains FAST 1944 bytes with 200 repetitions; large retains NORM 10755 bytes
with 200 repetitions. Original SLOW 39864 bytes and fixtures remain available in
upstream provenance. Every iteration preserves truncation by i mod31. The
Makefile identifies enwik8 as input origin; original byte identities are pinned,
not reconstructed from a newer Wikipedia dump. UTF-8 dataset bytes are compressed
as bytes, matching the original binary input mode, rather than decoded/reencoded.
[Mahoney's corpus description](https://mattmahoney.net/dc/textdata.html) identifies
enwik8's parent as a 2006 Wikipedia dump; it does not resolve the individual notice
gap in these copied subsets.

Original GHC and an independent dictionary-map LZW plus the exact packing rule
agree on all 31 cut byte fixtures per profile. Normal/large all 200 hash samples
also agree with unchanged GHC. Boundary tests cover empty/odd/full-byte inputs,
initial table order, unneeded EOF counter demand and dictionary freeze using
fixed Word32 counter-generator data. Primary hosts/Rune validate selected smoke
and normal profiles. The combined two-functor semantic test crashes ML Kit 4.7.23
with StatObject.instance_with_types.wrong number of types; standalone benchmark
smoke programs compile/pass there. That test compile failure is recorded, not
worked around or accepted as a result. Large SML execution is not universally
claimed.

References: [Welch, A Technique for High-Performance Data Compression](https://doi.org/10.1109/MC.1984.1659158),
Computer 17(6),8-19(1984); retained Sanders correspondence/implementation and
[nofib literature survey](../literature.md). Paper ancestry, inspected source
behavior, and measured count findings remain distinct.

[Complete provenance](compress-strict/PROVENANCE.md).

## lcss-nofib-lazy

Repeat Hirschberg longest-common-subsequence with the spectral input profiles.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/lcss`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

Andrew J. Bromage's November 2002 submission describes Hirschberg's algorithm
and its eager O(N) space behavior. The spectral and GC bodies agree exactly;
this driver reuses the reviewed lazy GC kernel rather than adding an algorithm
copy. The spectral program repeats 500 times and prints full sequences, while
the GC driver computes once with larger input ranges. Both sources and names
remain. Preserve last-tie split selection, row-pair layout, difference-list
composition and sequence generation.

## Translation, input and validation

The lazy variant memoizes row values and result tails; strict materializes them.
The spectral driver invokes the same full-sequence validator per repetition and
returns the consumed sum of actual lengths. Smoke uses 1..20 and 10..30 once;
normal preserves FAST 1..60 and 30..90 with 500 repetitions; large preserves
NORM 1..200 and 100..300 with 500. SLOW 300/150..450 remains recorded. All values
fit 31 bits. Original GHC's500 outputs agree with independent ordered intersections
for these monotone unique sequences; previously reviewed general LCSS tests cover
ties/duplicates and lazy suffix demand. Row allocation, sharing, retention and
repetition costs are hypotheses until measured. References: retained Bromage
submission and the shared LCSS provenance/literature survey.

[Complete provenance](lcss-nofib-lazy/PROVENANCE.md).

## treejoin-nofib-lazy

Repeat persistent relation-tree joins over the shuffled spectral datasets.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/treejoin`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

The complete tree algorithm agrees with the GC treejoin source; the spectral
variant repeats 100 times and uses shuffled relation files 1500/8000/27000.
These are materially different input shapes from the monotone GC datasets.
Share the reviewed lazy boundary-tree implementation, while retaining
all original files, stopping conditions, notices and naming. The individual
spectral author is not stated; the related GC 1993 mail remains separate evidence.

## Translation, inputs and validation

Preserve unbalanced persistent insertion, key boundaries, third-left/first-right
join lookup, duplicate rules and right-before-left accumulation. Lazy fields and
branches remain memoized; strict fields/updates remain eager. Every repetition
reads the fixed relation files and validates all five result fields, adding
rendering/reference-check work to the original forceTree unit output. The reported
record/match counts are consumed. Smoke uses the first 125 records of both 1500
files once; normal preserves complete 1500 files 100 times; large preserves 8000
files 100 times. Original27000/SLOW remains available. Numeric fields fit 31 bits.
Original GHC full-state observers and independent relational dictionary joins
agree with complete sorted fixtures. Input byte strings replace lazy file lists,
with that materialization/retention change documented. Shared-versus-eager tree
paths, shuffled insertion depth and join selectivity are hypotheses until measured.
References: retained source, related submission history and nofib survey.

[Complete provenance](treejoin-nofib-lazy/PROVENANCE.md).

## lcss-nofib-strict

Repeat Hirschberg longest-common-subsequence with the spectral input profiles.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/lcss`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

Andrew J. Bromage's November 2002 submission describes Hirschberg's algorithm
and its eager O(N) space behavior. The spectral and GC bodies agree exactly;
this driver reuses the reviewed strict GC kernel rather than adding an algorithm
copy. The spectral program repeats 500 times and prints full sequences, while
the GC driver computes once with larger input ranges. Both sources and names
remain. Preserve last-tie split selection, row-pair layout, difference-list
composition and sequence generation.

## Translation, input and validation

The lazy variant memoizes row values and result tails; strict materializes them.
The spectral driver invokes the same full-sequence validator per repetition and
returns the consumed sum of actual lengths. Smoke uses 1..20 and 10..30 once;
normal preserves FAST 1..60 and 30..90 with 500 repetitions; large preserves
NORM 1..200 and 100..300 with 500. SLOW 300/150..450 remains recorded. All values
fit 31 bits. Original GHC's500 outputs agree with independent ordered intersections
for these monotone unique sequences; previously reviewed general LCSS tests cover
ties/duplicates and lazy suffix demand. Row allocation, sharing, retention and
repetition costs are hypotheses until measured. References: retained Bromage
submission and the shared LCSS provenance/literature survey.

[Complete provenance](lcss-nofib-strict/PROVENANCE.md).

## treejoin-nofib-strict

Repeat persistent relation-tree joins over the shuffled spectral datasets.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/treejoin`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

The complete tree algorithm agrees with the GC treejoin source; the spectral
variant repeats 100 times and uses shuffled relation files 1500/8000/27000.
These are materially different input shapes from the monotone GC datasets.
Share the reviewed strict boundary-tree implementation, while retaining
all original files, stopping conditions, notices and naming. The individual
spectral author is not stated; the related GC 1993 mail remains separate evidence.

## Translation, inputs and validation

Preserve unbalanced persistent insertion, key boundaries, third-left/first-right
join lookup, duplicate rules and right-before-left accumulation. Lazy fields and
branches remain memoized; strict fields/updates remain eager. Every repetition
reads the fixed relation files and validates all five result fields, adding
rendering/reference-check work to the original forceTree unit output. The reported
record/match counts are consumed. Smoke uses the first 125 records of both 1500
files once; normal preserves complete 1500 files 100 times; large preserves 8000
files 100 times. Original27000/SLOW remains available. Numeric fields fit 31 bits.
Original GHC full-state observers and independent relational dictionary joins
agree with complete sorted fixtures. Input byte strings replace lazy file lists,
with that materialization/retention change documented. Shared-versus-eager tree
paths, shuffled insertion depth and join selectivity are hypotheses until measured.
References: retained source, related submission history and nofib survey.

[Complete provenance](treejoin-nofib-strict/PROVENANCE.md).

## rsa-lazy

Encrypt fixed ASCII blocks with exact modular exponentiation and memoized encodings.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/rsa`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

The source's individual author/licence is unspecified. Fixed large modulus and
exponent from Main.hs remain exact IntInf values. Preserve base 128 block coding,
block size(decimal digit length*47 div100), recursive exponent halving for even
powers and decrement/product for odd powers, modulus placement, decimal lines
and trailing newlines. Unused decrypt/key-generation helpers remain in the
original source. No built-in modular-power routine replaces this recurrence.

## Translation and runtime questions

Both variants share one algorithm. Lazy base-code arithmetic and ciphertext
chunk heads/spines are memoized; strict evaluates those finite encodings eagerly.
The selected entire ciphertext is needed, but intermediate retention/allocation
and input-encoding demand differ. Exponent0 returns1 without forcing the lazy
base, including modulus 1, matching the source's exact stopping rule. All RSA
arithmetic is arbitrary precision; block indices/counts fit 31 bits. Fixed inputs
are ASCII, so SML byte/character values agree with original Haskell input.
SML materializes input/block/output strings instead of character lists.

Repeated BinIO input acquisition is the portable observable substitute for
nofib's NOINLINE IO salt. This adds file I/O and copying per repetition; it is
explicitly included rather than adding a compiler opacity feature. A preloaded
ciphertext fixture validates every line before the wrapping64-bit source hash;
an IntInf sum consumes all repetitions. Standard timing comparisons use these
identical SML sources; Haskell originals are correctness references.

## Inputs, validation and references

Smoke takes the first 64 bytes of original FAST 411 and one repetition. The full
411-byte smoke input timed out after 30seconds on the unoptimized stack engine;
that rejected attempt remains recorded. Normal uses full FAST 411 with 10
repetitions; large uses original NORM 3169 bytes with 150 repetitions. Original
FAST 100/SLOW 250 and SLOW 10052-byte input remain retained. Every ciphertext block
agrees with GHC and independent Python modular pow, including the exact source
block-width rule. Semantic tests cover base 128 encoding, exponent parity,
empty input, block width and unneeded-base demand. The combined paired test
shares the recorded ML Kit StatObject compiler-crash limitation; passing
configurations and standalone runs remain distinguished. Big-integer division,
encoding thunks, decimal conversion and retention are source hypotheses until
measured. References: retained implementation and nofib literature survey.

[Complete provenance](rsa-lazy/PROVENANCE.md).

## rsa-strict

Encrypt fixed ASCII blocks with exact modular exponentiation and eager encodings.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/rsa`.

Complete pinned sources, build parameters, input/output fixtures and SHA256
identities are retained. Individual licence notices remain unspecified where
not present in source. Kernels and shared translation support are SML97.
Source inspection explains the following behavior; performance sensitivities
remain hypotheses until measured. Large SML execution is not universally claimed.

## Algorithm, history and variants

The source's individual author/licence is unspecified. Fixed large modulus and
exponent from Main.hs remain exact IntInf values. Preserve base 128 block coding,
block size(decimal digit length*47 div100), recursive exponent halving for even
powers and decrement/product for odd powers, modulus placement, decimal lines
and trailing newlines. Unused decrypt/key-generation helpers remain in the
original source. No built-in modular-power routine replaces this recurrence.

## Translation and runtime questions

Both variants share one algorithm. Lazy base-code arithmetic and ciphertext
chunk heads/spines are memoized; strict evaluates those finite encodings eagerly.
The selected entire ciphertext is needed, but intermediate retention/allocation
and input-encoding demand differ. Exponent0 returns1 without forcing the lazy
base, including modulus 1, matching the source's exact stopping rule. All RSA
arithmetic is arbitrary precision; block indices/counts fit 31 bits. Fixed inputs
are ASCII, so SML byte/character values agree with original Haskell input.
SML materializes input/block/output strings instead of character lists.

Repeated BinIO input acquisition is the portable observable substitute for
nofib's NOINLINE IO salt. This adds file I/O and copying per repetition; it is
explicitly included rather than adding a compiler opacity feature. A preloaded
ciphertext fixture validates every line before the wrapping64-bit source hash;
an IntInf sum consumes all repetitions. Standard timing comparisons use these
identical SML sources; Haskell originals are correctness references.

## Inputs, validation and references

Smoke takes the first 64 bytes of original FAST 411 and one repetition. The full
411-byte smoke input timed out after 30seconds on the unoptimized stack engine;
that rejected attempt remains recorded. Normal uses full FAST 411 with 10
repetitions; large uses original NORM 3169 bytes with 150 repetitions. Original
FAST 100/SLOW 250 and SLOW 10052-byte input remain retained. Every ciphertext block
agrees with GHC and independent Python modular pow, including the exact source
block-width rule. Semantic tests cover base 128 encoding, exponent parity,
empty input, block width and unneeded-base demand. The combined paired test
shares the recorded ML Kit StatObject compiler-crash limitation; passing
configurations and standalone runs remain distinguished. Big-integer division,
encoding thunks, decimal conversion and retention are source hypotheses until
measured. References: retained implementation and nofib literature survey.

[Complete provenance](rsa-strict/PROVENANCE.md).

## life-nofib-lazy

Evolve a memoized list-grid to the first adjacent Life fixpoint.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/life/Main.hs`.

John Launchbury is credited in the Game of Life header. The individual
licence notice is unspecified; original source, Makefile and SHA256 identities
are retained. This is the finite list-grid and adjacent-generation equality
variant, separate from the classic array/list Life programs and their inputs.

## Algorithm and variants

Preserve the original initial pattern on row 14, square clipping/padding,
zero border, shift triples, eight-neighbor sum and Conway update rules.
The adjacent-fixpoint test stops at the first equal pair and returns the older
board. Its generation index and exact display formatting are preserved.
No cycle detection or different stopping condition is substituted.
Both variants share one algorithm and sequence abstraction. Lazy heads/spines,
row values and neighbor cells are memoized; strict materializes them eagerly.
The old center cell remains unforced for birth/death and is read only for
survival with exactly two neighbors, as in the source.

## Translation and runtime questions

SML97 suspension adapters represent the original lazy list grid. Nested row
indirections and explicit memo cells affect representation/allocation. Input
generation remains in SML; integer cell values and selected indices fit 31 bits.
The program additionally checks the complete final display, consuming every
repetition in a sum of actual display lengths. The original prints only length
of that final display; intermediate generations remain undisplayed. Primitive
source/shift order, shared neighbor work, early equality exits and grid retention
are source-derived diagnostic questions until measured.

## Inputs, validation and references

Smoke uses original FAST size 15 once, with a nonempty initial pattern. Normal
retains FAST 15 with 250 repetitions; large retains NORM 27 with 250. SLOW 29 remains
recorded. Source fixpoint indices are 0/5/49/181 for sizes 5/15/27/29, with display
lengths 58/468/1489/1716. Original GHC observers and an independent synchronous
array-grid oracle agree with the complete final displays. All selected final
boards are empty, but the nonempty inputs undergo the recorded generations.
Semantic tests cover a two-step blinker, exact stop indices and center demand.
Primary smoke/normal cases pass; large SML execution is not universally claimed.
The paired semantic test triggers ML Kit's CompileDec.TypeFcn not simple crash;
that compile failure is recorded separately, without a source workaround.
References: retained Launchbury implementation and the nofib literature survey.

[Complete provenance](life-nofib-lazy/PROVENANCE.md).

## life-nofib-strict

Evolve an eager list-grid to the same adjacent Life fixpoint.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/life/Main.hs`.

John Launchbury is credited in the Game of Life header. The individual
licence notice is unspecified; original source, Makefile and SHA256 identities
are retained. This is the finite list-grid and adjacent-generation equality
variant, separate from the classic array/list Life programs and their inputs.

## Algorithm and variants

Preserve the original initial pattern on row 14, square clipping/padding,
zero border, shift triples, eight-neighbor sum and Conway update rules.
The adjacent-fixpoint test stops at the first equal pair and returns the older
board. Its generation index and exact display formatting are preserved.
No cycle detection or different stopping condition is substituted.
Both variants share one algorithm and sequence abstraction. Lazy heads/spines,
row values and neighbor cells are memoized; strict materializes them eagerly.
The old center cell remains unforced for birth/death and is read only for
survival with exactly two neighbors, as in the source.

## Translation and runtime questions

SML97 suspension adapters represent the original lazy list grid. Nested row
indirections and explicit memo cells affect representation/allocation. Input
generation remains in SML; integer cell values and selected indices fit 31 bits.
The program additionally checks the complete final display, consuming every
repetition in a sum of actual display lengths. The original prints only length
of that final display; intermediate generations remain undisplayed. Primitive
source/shift order, shared neighbor work, early equality exits and grid retention
are source-derived diagnostic questions until measured.

## Inputs, validation and references

Smoke uses original FAST size 15 once, with a nonempty initial pattern. Normal
retains FAST 15 with 250 repetitions; large retains NORM 27 with 250. SLOW 29 remains
recorded. Source fixpoint indices are 0/5/49/181 for sizes 5/15/27/29, with display
lengths 58/468/1489/1716. Original GHC observers and an independent synchronous
array-grid oracle agree with the complete final displays. All selected final
boards are empty, but the nonempty inputs undergo the recorded generations.
Semantic tests cover a two-step blinker, exact stop indices and center demand.
Primary smoke/normal cases pass; large SML execution is not universally claimed.
The paired semantic test triggers ML Kit's CompileDec.TypeFcn not simple crash;
that compile failure is recorded separately, without a source workaround.
References: retained Launchbury implementation and the nofib literature survey.

[Complete provenance](life-nofib-strict/PROVENANCE.md).

## maillist

Parse address paragraphs and create exact LaTeX mailing-label pages.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/maillist/Main.hs`.

## Algorithm and history

Paul Hudak, January1992, is credited in the header. The original source,
LaTeX style explanation, Makefile, runtime files and stdout fixtures are
retained with SHA256 identities. Individual program/dataset licence terms
are unspecified. The pinned inputs contain synthetic Name/Address/City/Country
labels, rather than a newly acquired mailing list.

Preserve blank-line paragraph splitting, a leading blank paragraph, four-line
entry padding/truncation,35-character warning threshold,30-label pages, three
nine-label long blocks and one three-label short block. Preserve exact braces,
spacing, backslashes, line endings and final document footer. This is the original
mailing-label layout, not a replacement templating or table algorithm.

## Translation and runtime behavior

Portable SML97 TextIO supplies openOut/openAppend/output/close operations.
Every original appendFile operation still opens/appends/closes separately;
no buffered whole-document substitution removes the file-I/O workload. Each
iteration rereads the input and overwrites a fixed output.tex in the fresh
program directory. This replaces the original input-name.tex path while
preserving output identity and repeated creation/appending work.

Command prompts, conversion notices and exceptional interactive filename
retry are replaced by fixed checked arguments and controlled result streams.
Long-line/truncated-entry messages are counted and consumed instead of printing
their contents. Every complete output file is read back and compared with a
reviewed fixture, adding one read/validation per repetition. Actual byte counts
and diagnostic counts contribute to the reported result. These adapter/check
costs are included. Paragraph allocation, append-call overhead, process/runtime
I/O and output copying are source-derived hypotheses until measured.

## Inputs and validation

Profiles retain original FAST/NORM/SLOW files:30/3626/10043 bytes.
Smoke runs once; normal/large preserve the original100 iterations. The inputs
use ASCII and lines of maximum length8. Complete GHC output and an independent
30-label page formatter agree for all three fixtures:630/5227/14298 output bytes.
No warnings occur in these original profiles. Boundary checks additionally
cover leading blanks, entry truncation, padding and long lines. Large SML
execution is not universally claimed. References: original Hudak description,
retained LaTeX style and nofib application survey.

[Complete provenance](maillist/PROVENANCE.md).

## hamming

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/hamming/hamming.ml` and its dune executable. The individual author
is unspecified. Preserve the original source, build declarations, aggregate
public-domain notice and SHA256 identities. Reviewed run-configuration extracts
include complete source-file identities. There are no upstream datasets.

### Algorithm, history and variants

Keep the mutually recursive shared Hamming stream, its 2/3/5 mapped streams,
nested two-way merge and duplicate elimination. OCaml heads are strict and
list cells/tails use memoized Lazy values. The SML97 BenchLazy adapter keeps
those boundaries and the three root map indirections. A separate fully eager
infinite list would not terminate; it is not a meaningful runnable variant.
This differs from a heap generator or an unbounded mathematical Hamming list.

The original two-component number uses a base of 10^18 and signed Int64
multiplication/addition with wraparound. Preserve both components and every
arithmetic step, using portable IntInf carriers with explicit signed 64-bit
wrapping. Preserve truncating division/remainder, signed component comparison
and the original decimal low-component padding. No reliance on host Int width
or optional Int64 support is introduced. Carrier allocation is an adaptation
and a source-derived performance hypothesis.

### Translation, inputs and validation

The original skips 88,000 values and defaults to 200 outputs. Normal retains
that exact window. Smoke explicitly selects a smaller prefix, skip 100/count 10.
Large retains the bytecode configuration's count 10,000 after skip 88,000;
the native configuration's count 1,000,000 remains recorded as an unselected
upstream parameter. A checked skip argument and full-result fixture replace
stdout-only observation. Results consume every selected value, compare the
complete newline-delimited output and report its actual last value. Checking,
string construction and reference-file acquisition costs are explicit.

Original OCaml agrees with an independent fixed-width cursor implementation
on every value of all three profiles. A separate arbitrary-precision heap
reference agrees with normal, then establishes that the original first diverges
from mathematical Hamming numbers at zero-based index 88,967. Large deliberately
preserves those wrapped source results. The complete large fixture also passes
Rune's stack VM at -O0; broader large SML validation is not claimed.

Eight semantic checks cover carries, overflow, formatting, shared merge prefixes,
memoization, strict mapped heads and unused-tail demand. A direct experiment
with the managed OCaml compiler observes left-to-right scrutinee forcing; the
port follows that observed order. Earlier test attempts had an incorrect order
expectation and are retained separately. Stream retention, map closures and
wide-number representation are hypotheses until measured. References: retained
source, configurations and the Sandmark runtime literature survey.

[Complete provenance](hamming/PROVENANCE.md).


## scc-lazy

Memoized variant; its strict companion retains the same algorithm.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/scc/Main.hs`
and `Digraph.hs`. The main header credits John Launchbury and identifies the
fixed graph as Figure 6.4 of SLPJ 1987. Original Haskell, historical Miranda
support source, Makefile, stdout fixture and SHA256 identities are retained.
The individual licence notice is unspecified. The graph is defined in source;
no external dataset is acquired.

### Algorithm and variants

Preserve the two DFS passes, list-based visited membership, edge-list scanning
for each adjacency range, reverse edges, finish-list concatenation and exact
component/member order. No array adjacency table, hash set or different SCC
algorithm substitutes for this implementation. Haskell's first traversal
produces a visited list and a lazy accumulated finish list; the second builds
components in reverse discovery order. SML memoizes both tuple fields and each shared recursive result, so finish
heads can be consumed before the last visited subtree is demanded. Finish-list
spines/heads remain memoized in the lazy variant. The strict variant eagerly builds those finite lists. Both share
one functor and retain separately named implementations.

### Translation, inputs and validation

SML97 int is sufficient for the seven original vertices. BenchCellSequence
represents finish/component list demand; known input edges and visited nodes
remain ordinary lists. Preserve the original graph in smoke and normal, each
with one kernel invocation. This is a small fixed diagnostic whose fresh-process
measurements include substantial startup cost. Large explicitly adds 10,000
repeated invocations of the same graph. Pure repeated work may be optimized or
hoisted by a compiler; this is a source-derived hypothesis, not an assertion of
steady state or enlarged-graph scaling.

The driver validates the complete component order against the original fixture
on every invocation and consumes actual rendered byte counts. Formatting,
fixture acquisition and checks are added costs. Original GHC matches the pinned
stdout fixture; independent mutual reachability validates the complete partition.
Nine checks cover the original order, disconnected vertices, cycles, duplicate
edges, unused finish-list demand, lazy tuple projections, recursive field sharing
and lazy/strict agreement. An initial test used
an incorrect expected partition/order; the reviewed correction and rejected
attempt are retained. Primary smoke/normal validation is recorded separately;
large SML execution is not universally claimed. References: [Peyton Jones, *The Implementation of Functional Programming Languages*](https://simon.peytonjones.org/slpj-book-1987/), Prentice Hall, 1987
(the source identifies Figure 6.4) and the nofib survey. Adjacency scans, finish concatenation,
visited membership and retained lists are hypotheses until measured. The initial
prototype produced correct complete results but demanded visited recursion too
early. Source inspection and the GHC demand observer led to the memoized tuple
projection correction before suite registration. Intermediate results are
distinguished from final source validation.

[Complete provenance](scc-lazy/PROVENANCE.md).


## scc-strict

Strict variant; its memoized companion retains the same algorithm.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/scc/Main.hs`
and `Digraph.hs`. The main header credits John Launchbury and identifies the
fixed graph as Figure 6.4 of SLPJ 1987. Original Haskell, historical Miranda
support source, Makefile, stdout fixture and SHA256 identities are retained.
The individual licence notice is unspecified. The graph is defined in source;
no external dataset is acquired.

### Algorithm and variants

Preserve the two DFS passes, list-based visited membership, edge-list scanning
for each adjacency range, reverse edges, finish-list concatenation and exact
component/member order. No array adjacency table, hash set or different SCC
algorithm substitutes for this implementation. Haskell's first traversal
produces a visited list and a lazy accumulated finish list; the second builds
components in reverse discovery order. SML memoizes both tuple fields and each shared recursive result, so finish
heads can be consumed before the last visited subtree is demanded. Finish-list
spines/heads remain memoized in the lazy variant. The strict variant eagerly builds those finite lists. Both share
one functor and retain separately named implementations.

### Translation, inputs and validation

SML97 int is sufficient for the seven original vertices. BenchCellSequence
represents finish/component list demand; known input edges and visited nodes
remain ordinary lists. Preserve the original graph in smoke and normal, each
with one kernel invocation. This is a small fixed diagnostic whose fresh-process
measurements include substantial startup cost. Large explicitly adds 10,000
repeated invocations of the same graph. Pure repeated work may be optimized or
hoisted by a compiler; this is a source-derived hypothesis, not an assertion of
steady state or enlarged-graph scaling.

The driver validates the complete component order against the original fixture
on every invocation and consumes actual rendered byte counts. Formatting,
fixture acquisition and checks are added costs. Original GHC matches the pinned
stdout fixture; independent mutual reachability validates the complete partition.
Nine checks cover the original order, disconnected vertices, cycles, duplicate
edges, unused finish-list demand, lazy tuple projections, recursive field sharing
and lazy/strict agreement. An initial test used
an incorrect expected partition/order; the reviewed correction and rejected
attempt are retained. Primary smoke/normal validation is recorded separately;
large SML execution is not universally claimed. References: [Peyton Jones, *The Implementation of Functional Programming Languages*](https://simon.peytonjones.org/slpj-book-1987/), Prentice Hall, 1987
(the source identifies Figure 6.4) and the nofib survey. Adjacency scans, finish concatenation,
visited membership and retained lists are hypotheses until measured. The initial
prototype produced correct complete results but demanded visited recursion too
early. Source inspection and the GHC demand observer led to the memoized tuple
projection correction before suite registration. Intermediate results are
distinguished from final source validation.

[Complete provenance](scc-strict/PROVENANCE.md).


## awards-lazy

Memoized variant; its strict companion retains the same algorithm.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/awards/Main.hs`
and `QSort.hs`. Kevin's June 1995 submission is retained with its
`kh@dcs.gla.ac.uk` attribution; QSort credits Lennart Augustsson. Preserve both
sources, Makefile, boot script, original output template and SHA256 identities.
Individual licence notices are unspecified. The source explicitly identifies
its four competitors' data as fake.

### Algorithm and variants

Preserve ordered three-element combinations (despite the source function name
perms), shared total/triple pairs, Gold/Silver/Bronze thresholds 70/60/50,
inclusive threshold tests and lexicographic sorting by (total,triple).
Select the first available tier and its smallest sorted qualifying total,
then remove each used score's first occurrence and recurse. Do not substitute
maximum-score awards or a search for the globally optimal award combination.

Keep Augustsson's six-function stable/anti-stable quicksort structure with
reversed partition lists, accumulated suffixes and no concatenation in sorting.
The lazy variant memoizes list cells, candidate heads, totals and sorted suffixes;
all three award tiers share the same sums. The strict variant eagerly evaluates
these finite lists. Both share one SML97 functor. Score triples are finite
ordinary integer lists; all selected scores/totals fit 31 bits.

### Translation, inputs and validation

Keep the original i mod 100 input distribution and competitor lists. Smoke uses
one source iteration; normal uses FAST 2,000 and large uses NORM 20,000.
SLOW 100,000 remains recorded and supported by the checked argument. Replace
printing each result by complete per-iteration validation against a reviewed
100-input cycle and accumulated actual byte counts. Formatting, cycle-file
loading and checks are included costs.

Both variants' complete 100-input output agrees with original GHC and an
independent combinations/sort/greedy-removal oracle. The pinned FAST output
template equals the cycle repeated 20 times. Nine semantic checks verify
combination order, stable sorting, deferred versus eager suffix demand,
threshold inclusion, duplicate score removal, tier/minimum-total priority and
all input-cycle variant results. Large SML execution is not universally claimed.
References: retained Kevin submission, Augustsson QSort explanation and nofib
survey. Candidate generation, shared totals, discarded award tiers and unused
sorted suffixes are source-derived hypotheses until measured.

[Complete provenance](awards-lazy/PROVENANCE.md).


## awards-strict

Strict variant; its memoized companion retains the same algorithm.

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/awards/Main.hs`
and `QSort.hs`. Kevin's June 1995 submission is retained with its
`kh@dcs.gla.ac.uk` attribution; QSort credits Lennart Augustsson. Preserve both
sources, Makefile, boot script, original output template and SHA256 identities.
Individual licence notices are unspecified. The source explicitly identifies
its four competitors' data as fake.

### Algorithm and variants

Preserve ordered three-element combinations (despite the source function name
perms), shared total/triple pairs, Gold/Silver/Bronze thresholds 70/60/50,
inclusive threshold tests and lexicographic sorting by (total,triple).
Select the first available tier and its smallest sorted qualifying total,
then remove each used score's first occurrence and recurse. Do not substitute
maximum-score awards or a search for the globally optimal award combination.

Keep Augustsson's six-function stable/anti-stable quicksort structure with
reversed partition lists, accumulated suffixes and no concatenation in sorting.
The lazy variant memoizes list cells, candidate heads, totals and sorted suffixes;
all three award tiers share the same sums. The strict variant eagerly evaluates
these finite lists. Both share one SML97 functor. Score triples are finite
ordinary integer lists; all selected scores/totals fit 31 bits.

### Translation, inputs and validation

Keep the original i mod 100 input distribution and competitor lists. Smoke uses
one source iteration; normal uses FAST 2,000 and large uses NORM 20,000.
SLOW 100,000 remains recorded and supported by the checked argument. Replace
printing each result by complete per-iteration validation against a reviewed
100-input cycle and accumulated actual byte counts. Formatting, cycle-file
loading and checks are included costs.

Both variants' complete 100-input output agrees with original GHC and an
independent combinations/sort/greedy-removal oracle. The pinned FAST output
template equals the cycle repeated 20 times. Nine semantic checks verify
combination order, stable sorting, deferred versus eager suffix demand,
threshold inclusion, duplicate score removal, tier/minimum-total priority and
all input-cycle variant results. Large SML execution is not universally claimed.
References: retained Kevin submission, Augustsson QSort explanation and nofib
survey. Candidate generation, shared totals, discarded award tiers and unused
sorted suffixes are source-derived hypotheses until measured.

[Complete provenance](awards-strict/PROVENANCE.md).

## stack_fold

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/stdlib/stack_bench.ml`. Two modes have different workloads and retain
separate names: stack_fold and stack_push_pop, matching the upstream mode arguments. Preserve the original
source, dune declarations, aggregate notice, configuration extracts and hashes.
The individual benchmark author is unspecified.

The library replacement follows Xavier Leroy's OCaml Stack implementation at
OCaml 4.14.1 commit `99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93`,
`stdlib/stack.ml`. The installed reference source matches that pinned file
byte for byte. Preserve its copyright header and LGPL 2.1 notice with the
OCaml linking exception, including the complete original LICENSE text.

### Algorithms and translation

Keep the linked list and cached mutable length. Stack push, pop and fold use
the original order; fold visits the top first. The fold mode pushes integers
1..100 once and repeatedly folds integer addition from zero. The push/pop mode
starts with one unit and repeatedly pushes then pops a unit, retaining length
one. Each mode retains its original positive iteration range and setup.

Portable SML97 uses a datatype record containing two mutable references;
OCaml stores both mutable fields in one record. This changes representation
and setup allocation, while preserving operations and lifetimes. Source
Sys.opaque_identity wraps the consumed fold value; the port consumes/validates
that value directly and accumulates it with IntInf. Push/pop validates the
cached length and consumes the completed operation count. These extra checks
and accumulators are included costs. Fold values and counters fit 31 bits;
IntInf preserves the wide aggregate on every SML host.

### Inputs, results and runtime questions

Smoke selects 100 iterations. Normal preserves the configured 2,500,000 folds
or 100,000,000 push/pop pairs. Large explicitly doubles those counts for scaling.
The modes keep their original list sizes and values. There are no datasets.
Original OCaml observers agree with independent arithmetic: fold totals are
5050 times iterations, with length/top 100; push/pop completes each requested
pair with final length one. Expected results are reviewed from these invariants.

Nine semantic checks cover empty stacks, exceptions, LIFO order, fold order,
unchanged folded stacks, workload results zero iterations and module-specific exception identity. List allocation,
mutable field updates, specialization, loop hoisting and short object lifetimes
are source-derived performance hypotheses until measured. Original and adapted
result consumption and instrumentation are distinguished. Broader large SML
validation is not universally claimed. References: pinned benchmark and OCaml
Stack sources, and the shared Sandmark runtime/measurement bibliography.

[Complete provenance](stack_fold/PROVENANCE.md).


## stack_push_pop

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
`benchmarks/stdlib/stack_bench.ml`. Two modes have different workloads and retain
separate names: stack_fold and stack_push_pop, matching the upstream mode arguments. Preserve the original
source, dune declarations, aggregate notice, configuration extracts and hashes.
The individual benchmark author is unspecified.

The library replacement follows Xavier Leroy's OCaml Stack implementation at
OCaml 4.14.1 commit `99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93`,
`stdlib/stack.ml`. The installed reference source matches that pinned file
byte for byte. Preserve its copyright header and LGPL 2.1 notice with the
OCaml linking exception, including the complete original LICENSE text.

### Algorithms and translation

Keep the linked list and cached mutable length. Stack push, pop and fold use
the original order; fold visits the top first. The fold mode pushes integers
1..100 once and repeatedly folds integer addition from zero. The push/pop mode
starts with one unit and repeatedly pushes then pops a unit, retaining length
one. Each mode retains its original positive iteration range and setup.

Portable SML97 uses a datatype record containing two mutable references;
OCaml stores both mutable fields in one record. This changes representation
and setup allocation, while preserving operations and lifetimes. Source
Sys.opaque_identity wraps the consumed fold value; the port consumes/validates
that value directly and accumulates it with IntInf. Push/pop validates the
cached length and consumes the completed operation count. These extra checks
and accumulators are included costs. Fold values and counters fit 31 bits;
IntInf preserves the wide aggregate on every SML host.

### Inputs, results and runtime questions

Smoke selects 100 iterations. Normal preserves the configured 2,500,000 folds
or 100,000,000 push/pop pairs. Large explicitly doubles those counts for scaling.
The modes keep their original list sizes and values. There are no datasets.
Original OCaml observers agree with independent arithmetic: fold totals are
5050 times iterations, with length/top 100; push/pop completes each requested
pair with final length one. Expected results are reviewed from these invariants.

Nine semantic checks cover empty stacks, exceptions, LIFO order, fold order,
unchanged folded stacks, workload results zero iterations and module-specific exception identity. List allocation,
mutable field updates, specialization, loop hoisting and short object lifetimes
are source-derived performance hypotheses until measured. Original and adapted
result consumption and instrumentation are distinguished. Broader large SML
validation is not universally claimed. References: pinned benchmark and OCaml
Stack sources, and the shared Sandmark runtime/measurement bibliography.

[Complete provenance](stack_push_pop/PROVENANCE.md).

## S

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/S`.

### History, source and notices

The August 2017 [import commit](https://github.com/ghc/nofib/commit/c7e6c9074511f74f73eaa3b41051afc94aeb653a)
credits Andras Kovacs and was authored by Matthew Pickering. It identifies
[the original collection](https://github.com/AndrasKovacs/misc-stuff/blob/master/haskell/Eff/EffBench.hs)
and associates the benchmarks with [GHC issue 13892](https://gitlab.haskell.org/ghc/ghc/-/issues/13892).
Original Main, required EffBench module, Makefile, stdout fixture, import history
and SHA256 identities are retained. Individual program licensing is unspecified
in these source headers. The encoding names S/CS/CSD/FS/VS/VSD/VSM remain distinct.

The shared State support is translated from the used operations of mtl 2.2.2
(commit c7d396732bd45e409478bd4df1d0ca95d6f39356) and transformers 0.5.6.2
(commit 0fe761c9287111373ae64ab39b67fbcde212b3f7), with Identity from GHC base
4.17.2.0 (GHC 9.4.7 commit 00920f176b0235d5bb52a8e054d89a664f8938fe).
Original source copyright headers and all three BSD-style notices are retained.
There are no external datasets.

### Algorithm and variant differences

Strict State binds demand intermediate tuples while modify leaves the new
state field lazy. The complete program observes tuple WHNF, leaving the
accumulated increment chain unforced. Shared tuple/state references preserve
this behavior; the counter is deliberately omitted from benchmark validation.

Retain the increment action, repeated monadic sequencing, relevant handler/bind
layers and the interpreter where present. The workload uses ordinary pure
function/constructor encodings of state. Translation specializes the used state
type to int and results to unit; VS retains two used bind callback instances,
for int-to-unit and unit-to-unit actions. Newtype wrappers become function types;
SML records hold the used callback/class operations. Unused general fmap,
applicative and higher-rank interface cases remain in pristine source. Compiler
and runtime features are unchanged by these library translations.

### Inputs, demand and validation

The original constant work count is 10,000,000. Smoke selects 100, normal selects
1,000,000 and large retains the original 10,000,000. The checked work-count
argument changes this stopping parameter explicitly; increment data, initial
state zero and action sequence are preserved. All selected numeric values fit
31 bits, agreeing with the original GHC machine Int values in this range.

Preserve evaluate's demand for the result tuple. S's counter remains unforced;
the driver consumes its unit result. The six other encodings already force each
incremented state, so validation additionally reads/checks the final counter
without evaluating delayed arithmetic. Result formatting and fixed stdout labels
are replaced by controlled checked results. S's unit result gives limited direct
output discrimination; its demand/sharing tests, source review and deterministic
counts document the workload. Compiler elimination/specialization of unused work
is a diagnostic question. Numeric counter checks add constant post-run work to
the six strict encodings. Explicit memo cells, callback records and closure
representation affect allocation and are recorded adaptations.

Original GHC observers agree with the selected unit/strict-counter results.
A separate S observer confirms throwing counter arithmetic remains deferred at
tuple/unit observation and fails when the counter is forced. Fourteen tests on
the shared encodings cover tuple demand, memoization, strict increment fields,
exact counters, action counts and unforced free-state continuations. Broader
large SML validation is not universally claimed. References: retained source,
import history, GHC issue association and the shared nofib/measurement survey.
Source comments discuss call arity, static-argument transformation and constructor
specialization; their effects on Rune or other SML hosts remain hypotheses until
source/IR analysis and measurements establish them.

[Complete provenance](S/PROVENANCE.md).


## CS

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/CS`.

### History, source and notices

The August 2017 [import commit](https://github.com/ghc/nofib/commit/c7e6c9074511f74f73eaa3b41051afc94aeb653a)
credits Andras Kovacs and was authored by Matthew Pickering. It identifies
[the original collection](https://github.com/AndrasKovacs/misc-stuff/blob/master/haskell/Eff/EffBench.hs)
and associates the benchmarks with [GHC issue 13892](https://gitlab.haskell.org/ghc/ghc/-/issues/13892).
Original Main, required EffBench module, Makefile, stdout fixture, import history
and SHA256 identities are retained. Individual program licensing is unspecified
in these source headers. The encoding names S/CS/CSD/FS/VS/VSD/VSM remain distinct.

The shared State support is translated from the used operations of mtl 2.2.2
(commit c7d396732bd45e409478bd4df1d0ca95d6f39356) and transformers 0.5.6.2
(commit 0fe761c9287111373ae64ab39b67fbcde212b3f7), with Identity from GHC base
4.17.2.0 (GHC 9.4.7 commit 00920f176b0235d5bb52a8e054d89a664f8938fe).
Original source copyright headers and all three BSD-style notices are retained.
There are no external datasets.

### Algorithm and variant differences

Church-encoded free state retains its pure/get/put callbacks, bind and
continuation closures. cmodify's bang forces each new state. The used Church
result is specialized to the State runner returning (unit,int).

Retain the increment action, repeated monadic sequencing, relevant handler/bind
layers and the interpreter where present. The workload uses ordinary pure
function/constructor encodings of state. Translation specializes the used state
type to int and results to unit; VS retains two used bind callback instances,
for int-to-unit and unit-to-unit actions. Newtype wrappers become function types;
SML records hold the used callback/class operations. Unused general fmap,
applicative and higher-rank interface cases remain in pristine source. Compiler
and runtime features are unchanged by these library translations.

### Inputs, demand and validation

The original constant work count is 10,000,000. Smoke selects 100, normal selects
1,000,000 and large retains the original 10,000,000. The checked work-count
argument changes this stopping parameter explicitly; increment data, initial
state zero and action sequence are preserved. All selected numeric values fit
31 bits, agreeing with the original GHC machine Int values in this range.

Preserve evaluate's demand for the result tuple. S's counter remains unforced;
the driver consumes its unit result. The six other encodings already force each
incremented state, so validation additionally reads/checks the final counter
without evaluating delayed arithmetic. Result formatting and fixed stdout labels
are replaced by controlled checked results. S's unit result gives limited direct
output discrimination; its demand/sharing tests, source review and deterministic
counts document the workload. Compiler elimination/specialization of unused work
is a diagnostic question. Numeric counter checks add constant post-run work to
the six strict encodings. Explicit memo cells, callback records and closure
representation affect allocation and are recorded adaptations.

Original GHC observers agree with the selected unit/strict-counter results.
A separate S observer confirms throwing counter arithmetic remains deferred at
tuple/unit observation and fails when the counter is forced. Fourteen tests on
the shared encodings cover tuple demand, memoization, strict increment fields,
exact counters, action counts and unforced free-state continuations. Broader
large SML validation is not universally claimed. References: retained source,
import history, GHC issue association and the shared nofib/measurement survey.
Source comments discuss call arity, static-argument transformation and constructor
specialization; their effects on Rune or other SML hosts remain hypotheses until
source/IR analysis and measurements establish them.

[Complete provenance](CS/PROVENANCE.md).


## CSD

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/CSD`.

### History, source and notices

The August 2017 [import commit](https://github.com/ghc/nofib/commit/c7e6c9074511f74f73eaa3b41051afc94aeb653a)
credits Andras Kovacs and was authored by Matthew Pickering. It identifies
[the original collection](https://github.com/AndrasKovacs/misc-stuff/blob/master/haskell/Eff/EffBench.hs)
and associates the benchmarks with [GHC issue 13892](https://gitlab.haskell.org/ghc/ghc/-/issues/13892).
Original Main, required EffBench module, Makefile, stdout fixture, import history
and SHA256 identities are retained. Individual program licensing is unspecified
in these source headers. The encoding names S/CS/CSD/FS/VS/VSD/VSM remain distinct.

The shared State support is translated from the used operations of mtl 2.2.2
(commit c7d396732bd45e409478bd4df1d0ca95d6f39356) and transformers 0.5.6.2
(commit 0fe761c9287111373ae64ab39b67fbcde212b3f7), with Identity from GHC base
4.17.2.0 (GHC 9.4.7 commit 00920f176b0235d5bb52a8e054d89a664f8938fe).
Original source copyright headers and all three BSD-style notices are retained.
There are no external datasets.

### Algorithm and variant differences

Classy Church state retains the three PureD/GetD/PutD operations in a
ground State dictionary and the directly recursive cstimes definition. Each
new counter is forced before the put continuation. This differs from CS's
explicit encoded action and generic bind layer.

Retain the increment action, repeated monadic sequencing, relevant handler/bind
layers and the interpreter where present. The workload uses ordinary pure
function/constructor encodings of state. Translation specializes the used state
type to int and results to unit; VS retains two used bind callback instances,
for int-to-unit and unit-to-unit actions. Newtype wrappers become function types;
SML records hold the used callback/class operations. Unused general fmap,
applicative and higher-rank interface cases remain in pristine source. Compiler
and runtime features are unchanged by these library translations.

### Inputs, demand and validation

The original constant work count is 10,000,000. Smoke selects 100, normal selects
1,000,000 and large retains the original 10,000,000. The checked work-count
argument changes this stopping parameter explicitly; increment data, initial
state zero and action sequence are preserved. All selected numeric values fit
31 bits, agreeing with the original GHC machine Int values in this range.

Preserve evaluate's demand for the result tuple. S's counter remains unforced;
the driver consumes its unit result. The six other encodings already force each
incremented state, so validation additionally reads/checks the final counter
without evaluating delayed arithmetic. Result formatting and fixed stdout labels
are replaced by controlled checked results. S's unit result gives limited direct
output discrimination; its demand/sharing tests, source review and deterministic
counts document the workload. Compiler elimination/specialization of unused work
is a diagnostic question. Numeric counter checks add constant post-run work to
the six strict encodings. Explicit memo cells, callback records and closure
representation affect allocation and are recorded adaptations.

Original GHC observers agree with the selected unit/strict-counter results.
A separate S observer confirms throwing counter arithmetic remains deferred at
tuple/unit observation and fails when the counter is forced. Fourteen tests on
the shared encodings cover tuple demand, memoization, strict increment fields,
exact counters, action counts and unforced free-state continuations. Broader
large SML validation is not universally claimed. References: retained source,
import history, GHC issue association and the shared nofib/measurement survey.
Source comments discuss call arity, static-argument transformation and constructor
specialization; their effects on Rune or other SML hosts remain hypotheses until
source/IR analysis and measurements establish them.

[Complete provenance](CSD/PROVENANCE.md).


## FS

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/FS`.

### History, source and notices

The August 2017 [import commit](https://github.com/ghc/nofib/commit/c7e6c9074511f74f73eaa3b41051afc94aeb653a)
credits Andras Kovacs and was authored by Matthew Pickering. It identifies
[the original collection](https://github.com/AndrasKovacs/misc-stuff/blob/master/haskell/Eff/EffBench.hs)
and associates the benchmarks with [GHC issue 13892](https://gitlab.haskell.org/ghc/ghc/-/issues/13892).
Original Main, required EffBench module, Makefile, stdout fixture, import history
and SHA256 identities are retained. Individual program licensing is unspecified
in these source headers. The encoding names S/CS/CSD/FS/VS/VSD/VSM remain distinct.

The shared State support is translated from the used operations of mtl 2.2.2
(commit c7d396732bd45e409478bd4df1d0ca95d6f39356) and transformers 0.5.6.2
(commit 0fe761c9287111373ae64ab39b67fbcde212b3f7), with Identity from GHC base
4.17.2.0 (GHC 9.4.7 commit 00920f176b0235d5bb52a8e054d89a664f8938fe).
Original source copyright headers and all three BSD-style notices are retained.
There are no external datasets.

### Algorithm and variant differences

Free state retains Pure/Get/Put constructors, monadic bind and its
recursive state interpreter. Put's numeric field is strict, while the next
action/continuation remains memoized. Binding preserves these suspended
continuations and the original constructor traversal.

Retain the increment action, repeated monadic sequencing, relevant handler/bind
layers and the interpreter where present. The workload uses ordinary pure
function/constructor encodings of state. Translation specializes the used state
type to int and results to unit; VS retains two used bind callback instances,
for int-to-unit and unit-to-unit actions. Newtype wrappers become function types;
SML records hold the used callback/class operations. Unused general fmap,
applicative and higher-rank interface cases remain in pristine source. Compiler
and runtime features are unchanged by these library translations.

### Inputs, demand and validation

The original constant work count is 10,000,000. Smoke selects 100, normal selects
1,000,000 and large retains the original 10,000,000. The checked work-count
argument changes this stopping parameter explicitly; increment data, initial
state zero and action sequence are preserved. All selected numeric values fit
31 bits, agreeing with the original GHC machine Int values in this range.

Preserve evaluate's demand for the result tuple. S's counter remains unforced;
the driver consumes its unit result. The six other encodings already force each
incremented state, so validation additionally reads/checks the final counter
without evaluating delayed arithmetic. Result formatting and fixed stdout labels
are replaced by controlled checked results. S's unit result gives limited direct
output discrimination; its demand/sharing tests, source review and deterministic
counts document the workload. Compiler elimination/specialization of unused work
is a diagnostic question. Numeric counter checks add constant post-run work to
the six strict encodings. Explicit memo cells, callback records and closure
representation affect allocation and are recorded adaptations.

Original GHC observers agree with the selected unit/strict-counter results.
A separate S observer confirms throwing counter arithmetic remains deferred at
tuple/unit observation and fails when the counter is forced. Fourteen tests on
the shared encodings cover tuple demand, memoization, strict increment fields,
exact counters, action counts and unforced free-state continuations. Broader
large SML validation is not universally claimed. References: retained source,
import history, GHC issue association and the shared nofib/measurement survey.
Source comments discuss call arity, static-argument transformation and constructor
specialization; their effects on Rune or other SML hosts remain hypotheses until
source/IR analysis and measurements establish them.

[Complete provenance](FS/PROVENANCE.md).


## VS

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/VS`.

### History, source and notices

The August 2017 [import commit](https://github.com/ghc/nofib/commit/c7e6c9074511f74f73eaa3b41051afc94aeb653a)
credits Andras Kovacs and was authored by Matthew Pickering. It identifies
[the original collection](https://github.com/AndrasKovacs/misc-stuff/blob/master/haskell/Eff/EffBench.hs)
and associates the benchmarks with [GHC issue 13892](https://gitlab.haskell.org/ghc/ghc/-/issues/13892).
Original Main, required EffBench module, Makefile, stdout fixture, import history
and SHA256 identities are retained. Individual program licensing is unspecified
in these source headers. The encoding names S/CS/CSD/FS/VS/VSD/VSM remain distinct.

The shared State support is translated from the used operations of mtl 2.2.2
(commit c7d396732bd45e409478bd4df1d0ca95d6f39356) and transformers 0.5.6.2
(commit 0fe761c9287111373ae64ab39b67fbcde212b3f7), with Identity from GHC base
4.17.2.0 (GHC 9.4.7 commit 00920f176b0235d5bb52a8e054d89a664f8938fe).
Original source copyright headers and all three BSD-style notices are retained.
There are no external datasets.

### Algorithm and variant differences

The van Laarhoven encoding retains pure/bind/get/put callback layers. Its
custom S interpreter bangs both value/state fields at each bind. SML's strict
unit/int tuples preserve the used field demands; the two used bind types get
separate typed callback fields.

Retain the increment action, repeated monadic sequencing, relevant handler/bind
layers and the interpreter where present. The workload uses ordinary pure
function/constructor encodings of state. Translation specializes the used state
type to int and results to unit; VS retains two used bind callback instances,
for int-to-unit and unit-to-unit actions. Newtype wrappers become function types;
SML records hold the used callback/class operations. Unused general fmap,
applicative and higher-rank interface cases remain in pristine source. Compiler
and runtime features are unchanged by these library translations.

### Inputs, demand and validation

The original constant work count is 10,000,000. Smoke selects 100, normal selects
1,000,000 and large retains the original 10,000,000. The checked work-count
argument changes this stopping parameter explicitly; increment data, initial
state zero and action sequence are preserved. All selected numeric values fit
31 bits, agreeing with the original GHC machine Int values in this range.

Preserve evaluate's demand for the result tuple. S's counter remains unforced;
the driver consumes its unit result. The six other encodings already force each
incremented state, so validation additionally reads/checks the final counter
without evaluating delayed arithmetic. Result formatting and fixed stdout labels
are replaced by controlled checked results. S's unit result gives limited direct
output discrimination; its demand/sharing tests, source review and deterministic
counts document the workload. Compiler elimination/specialization of unused work
is a diagnostic question. Numeric counter checks add constant post-run work to
the six strict encodings. Explicit memo cells, callback records and closure
representation affect allocation and are recorded adaptations.

Original GHC observers agree with the selected unit/strict-counter results.
A separate S observer confirms throwing counter arithmetic remains deferred at
tuple/unit observation and fails when the counter is forced. Fourteen tests on
the shared encodings cover tuple demand, memoization, strict increment fields,
exact counters, action counts and unforced free-state continuations. Broader
large SML validation is not universally claimed. References: retained source,
import history, GHC issue association and the shared nofib/measurement survey.
Source comments discuss call arity, static-argument transformation and constructor
specialization; their effects on Rune or other SML hosts remain hypotheses until
source/IR analysis and measurements establish them.

[Complete provenance](VS/PROVENANCE.md).


## VSD

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/VSD`.

### History, source and notices

The August 2017 [import commit](https://github.com/ghc/nofib/commit/c7e6c9074511f74f73eaa3b41051afc94aeb653a)
credits Andras Kovacs and was authored by Matthew Pickering. It identifies
[the original collection](https://github.com/AndrasKovacs/misc-stuff/blob/master/haskell/Eff/EffBench.hs)
and associates the benchmarks with [GHC issue 13892](https://gitlab.haskell.org/ghc/ghc/-/issues/13892).
Original Main, required EffBench module, Makefile, stdout fixture, import history
and SHA256 identities are retained. Individual program licensing is unspecified
in these source headers. The encoding names S/CS/CSD/FS/VS/VSD/VSM remain distinct.

The shared State support is translated from the used operations of mtl 2.2.2
(commit c7d396732bd45e409478bd4df1d0ca95d6f39356) and transformers 0.5.6.2
(commit 0fe761c9287111373ae64ab39b67fbcde212b3f7), with Identity from GHC base
4.17.2.0 (GHC 9.4.7 commit 00920f176b0235d5bb52a8e054d89a664f8938fe).
Original source copyright headers and all three BSD-style notices are retained.
There are no external datasets.

### Algorithm and variant differences

Classy van Laarhoven state retains the get/put class dictionary over
mtl's strict-tuple State and its bind. vmdmodify explicitly forces the new
state. Shared State support preserves tuple-versus-field demand, with the
modified counter already evaluated at every step.

Retain the increment action, repeated monadic sequencing, relevant handler/bind
layers and the interpreter where present. The workload uses ordinary pure
function/constructor encodings of state. Translation specializes the used state
type to int and results to unit; VS retains two used bind callback instances,
for int-to-unit and unit-to-unit actions. Newtype wrappers become function types;
SML records hold the used callback/class operations. Unused general fmap,
applicative and higher-rank interface cases remain in pristine source. Compiler
and runtime features are unchanged by these library translations.

### Inputs, demand and validation

The original constant work count is 10,000,000. Smoke selects 100, normal selects
1,000,000 and large retains the original 10,000,000. The checked work-count
argument changes this stopping parameter explicitly; increment data, initial
state zero and action sequence are preserved. All selected numeric values fit
31 bits, agreeing with the original GHC machine Int values in this range.

Preserve evaluate's demand for the result tuple. S's counter remains unforced;
the driver consumes its unit result. The six other encodings already force each
incremented state, so validation additionally reads/checks the final counter
without evaluating delayed arithmetic. Result formatting and fixed stdout labels
are replaced by controlled checked results. S's unit result gives limited direct
output discrimination; its demand/sharing tests, source review and deterministic
counts document the workload. Compiler elimination/specialization of unused work
is a diagnostic question. Numeric counter checks add constant post-run work to
the six strict encodings. Explicit memo cells, callback records and closure
representation affect allocation and are recorded adaptations.

Original GHC observers agree with the selected unit/strict-counter results.
A separate S observer confirms throwing counter arithmetic remains deferred at
tuple/unit observation and fails when the counter is forced. Fourteen tests on
the shared encodings cover tuple demand, memoization, strict increment fields,
exact counters, action counts and unforced free-state continuations. Broader
large SML validation is not universally claimed. References: retained source,
import history, GHC issue association and the shared nofib/measurement survey.
Source comments discuss call arity, static-argument transformation and constructor
specialization; their effects on Rune or other SML hosts remain hypotheses until
source/IR analysis and measurements establish them.

[Complete provenance](VSD/PROVENANCE.md).


## VSM

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/VSM`.

### History, source and notices

The August 2017 [import commit](https://github.com/ghc/nofib/commit/c7e6c9074511f74f73eaa3b41051afc94aeb653a)
credits Andras Kovacs and was authored by Matthew Pickering. It identifies
[the original collection](https://github.com/AndrasKovacs/misc-stuff/blob/master/haskell/Eff/EffBench.hs)
and associates the benchmarks with [GHC issue 13892](https://gitlab.haskell.org/ghc/ghc/-/issues/13892).
Original Main, required EffBench module, Makefile, stdout fixture, import history
and SHA256 identities are retained. Individual program licensing is unspecified
in these source headers. The encoding names S/CS/CSD/FS/VS/VSD/VSM remain distinct.

The shared State support is translated from the used operations of mtl 2.2.2
(commit c7d396732bd45e409478bd4df1d0ca95d6f39356) and transformers 0.5.6.2
(commit 0fe761c9287111373ae64ab39b67fbcde212b3f7), with Identity from GHC base
4.17.2.0 (GHC 9.4.7 commit 00920f176b0235d5bb52a8e054d89a664f8938fe).
Original source copyright headers and all three BSD-style notices are retained.
There are no external datasets.

### Algorithm and variant differences

The van Laarhoven-to-mtl encoding retains its get/put abstraction,
encoded bind and the shared State bind. vmmodify bangs the new state before
put. This retains the additional encoded function layers beyond VSD's class
operations and uses the original current-state threading.

Retain the increment action, repeated monadic sequencing, relevant handler/bind
layers and the interpreter where present. The workload uses ordinary pure
function/constructor encodings of state. Translation specializes the used state
type to int and results to unit; VS retains two used bind callback instances,
for int-to-unit and unit-to-unit actions. Newtype wrappers become function types;
SML records hold the used callback/class operations. Unused general fmap,
applicative and higher-rank interface cases remain in pristine source. Compiler
and runtime features are unchanged by these library translations.

### Inputs, demand and validation

The original constant work count is 10,000,000. Smoke selects 100, normal selects
1,000,000 and large retains the original 10,000,000. The checked work-count
argument changes this stopping parameter explicitly; increment data, initial
state zero and action sequence are preserved. All selected numeric values fit
31 bits, agreeing with the original GHC machine Int values in this range.

Preserve evaluate's demand for the result tuple. S's counter remains unforced;
the driver consumes its unit result. The six other encodings already force each
incremented state, so validation additionally reads/checks the final counter
without evaluating delayed arithmetic. Result formatting and fixed stdout labels
are replaced by controlled checked results. S's unit result gives limited direct
output discrimination; its demand/sharing tests, source review and deterministic
counts document the workload. Compiler elimination/specialization of unused work
is a diagnostic question. Numeric counter checks add constant post-run work to
the six strict encodings. Explicit memo cells, callback records and closure
representation affect allocation and are recorded adaptations.

Original GHC observers agree with the selected unit/strict-counter results.
A separate S observer confirms throwing counter arithmetic remains deferred at
tuple/unit observation and fails when the counter is forced. Fourteen tests on
the shared encodings cover tuple demand, memoization, strict increment fields,
exact counters, action counts and unforced free-state continuations. Broader
large SML validation is not universally claimed. References: retained source,
import history, GHC issue association and the shared nofib/measurement survey.
Source comments discuss call arity, static-argument transformation and constructor
specialization; their effects on Rune or other SML hosts remain hypotheses until
source/IR analysis and measurements establish them.

[Complete provenance](VSM/PROVENANCE.md).

## constraints-lazy

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/constraints/Main.hs`
and `spectral/constraints/Main.hs`. The full programs, all five solvers, 240
repetitions and FAST/NORM/SLOW sizes 6/7/8 are identical. Preserve both sources,
fixtures, Makefiles and hashes. GC-specific heap flags are reference runtime
configurations; the copies share one implementation. Andrew Tolmach and Thomas
Nordin are credited in the header, which cites WAAAPL 1999. Individual notices
are unspecified; inputs are deterministic queens CSPs generated in source.

### Algorithms and variants

Keep the CSP record (variable/value counts and relation callback), descending
assignment lists, generated search tree, label/child transformations, pruning,
leaf traversal and five methods: backtracking, backmarking, two conflict-directed
backjumping forms and forward checking. Retain cached future-domain rows,
oldest inconsistency selection, conflict sets, ordered union and nonlocal-conflict
sibling cutoff. The solvers run in their original order and each yields every
solution. The source's zero-variable backmarking result differs from the other
four methods; preserve it as an unselected edge case.

Memoized labels, children, table rows, conflict fields and conflict-list spines
represent source demand/sharing. The strict variant eagerly builds the same
finite structures through one shared functor. Assignment constructors become
integer pairs; generic list calls use portable sequence/map/filter/zip and set
helpers. Union preserves source list order and duplicate treatment. The SML
fold passes label cells so pruning can retain an unused root label without
forcing it. Representation and library-call adaptations are explicit.

### Inputs, validation and runtime questions

Smoke selects size 4 once. Normal retains FAST size 6 and all 240 original
repetitions; a bounded stack-VM -O0 preflight validates the strict normal profile
within 600 seconds/4 GiB. Large retains NORM size 7 with 240 repetitions. SLOW
size 8 is preserved in source metadata. Selected assignments, indices and count
sums fit 31 bits. The strict normal profile records a 1,200-second override after a canonical
-O0 stack run timed out at 600 seconds; memory remains 4 GiB. An earlier
bounded preflight passed at 600 seconds. Other limits retain suite defaults.

The driver consumes each complete solution vector and validates exact solution
order for every method/repetition, adding payload forcing and comparisons to the
original length-only observation. It accumulates actual solution counts per
method. GHC observers and independent permutation/diagonal checks agree on all
five full ordered solution sets for sizes 0..8, including the source's zero-case
exception. Numerical integer results are exact. Broad large SML execution is
not universally claimed.

Nine semantic checks cover five-solver agreement, source edge behavior, earliest
conflicts, strict/lazy agreement, union order, delayed pruning labels, nonlocal
backjump cutoff, cache updates and mapped-label memoization. Tree materialization,
pruning, repeated table sharing, short conflict lists and allocation/lifetimes
are source-derived hypotheses until measured. References: retained Tolmach/Nordin
implementation and WAAAPL citation, [their related 2001 publication](https://web.cecs.pdx.edu/~apt/),
Modular Lazy Search for Constraint Satisfaction Problems, and the shared nofib/GC survey.

[Complete provenance](constraints-lazy/PROVENANCE.md).


## constraints-strict

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/constraints/Main.hs`
and `spectral/constraints/Main.hs`. The full programs, all five solvers, 240
repetitions and FAST/NORM/SLOW sizes 6/7/8 are identical. Preserve both sources,
fixtures, Makefiles and hashes. GC-specific heap flags are reference runtime
configurations; the copies share one implementation. Andrew Tolmach and Thomas
Nordin are credited in the header, which cites WAAAPL 1999. Individual notices
are unspecified; inputs are deterministic queens CSPs generated in source.

### Algorithms and variants

Keep the CSP record (variable/value counts and relation callback), descending
assignment lists, generated search tree, label/child transformations, pruning,
leaf traversal and five methods: backtracking, backmarking, two conflict-directed
backjumping forms and forward checking. Retain cached future-domain rows,
oldest inconsistency selection, conflict sets, ordered union and nonlocal-conflict
sibling cutoff. The solvers run in their original order and each yields every
solution. The source's zero-variable backmarking result differs from the other
four methods; preserve it as an unselected edge case.

Memoized labels, children, table rows, conflict fields and conflict-list spines
represent source demand/sharing. The strict variant eagerly builds the same
finite structures through one shared functor. Assignment constructors become
integer pairs; generic list calls use portable sequence/map/filter/zip and set
helpers. Union preserves source list order and duplicate treatment. The SML
fold passes label cells so pruning can retain an unused root label without
forcing it. Representation and library-call adaptations are explicit.

### Inputs, validation and runtime questions

Smoke selects size 4 once. Normal retains FAST size 6 and all 240 original
repetitions; a bounded stack-VM -O0 preflight validates the strict normal profile
within 600 seconds/4 GiB. Large retains NORM size 7 with 240 repetitions. SLOW
size 8 is preserved in source metadata. Selected assignments, indices and count
sums fit 31 bits. The strict normal profile records a 1,200-second override after a canonical
-O0 stack run timed out at 600 seconds; memory remains 4 GiB. An earlier
bounded preflight passed at 600 seconds. Other limits retain suite defaults.

The driver consumes each complete solution vector and validates exact solution
order for every method/repetition, adding payload forcing and comparisons to the
original length-only observation. It accumulates actual solution counts per
method. GHC observers and independent permutation/diagonal checks agree on all
five full ordered solution sets for sizes 0..8, including the source's zero-case
exception. Numerical integer results are exact. Broad large SML execution is
not universally claimed.

Nine semantic checks cover five-solver agreement, source edge behavior, earliest
conflicts, strict/lazy agreement, union order, delayed pruning labels, nonlocal
backjump cutoff, cache updates and mapped-label memoization. Tree materialization,
pruning, repeated table sharing, short conflict lists and allocation/lifetimes
are source-derived hypotheses until measured. References: retained Tolmach/Nordin
implementation and WAAAPL citation, [their related 2001 publication](https://web.cecs.pdx.edu/~apt/),
Modular Lazy Search for Constraint Satisfaction Problems, and the shared nofib/GC survey.

[Complete provenance](constraints-strict/PROVENANCE.md).

## fibheaps-lazy

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/fibheaps/Main.lhs`.
Chris Okasaki's July 1995 correspondence says he translated the example from
SML and tested it in Gofer. Original correspondence, literate implementation,
Makefile, other retained source fragments, stdout fixture and SHA256 identities
are preserved. Individual licensing is unspecified. Inputs are generated in
source; no external dataset is acquired.

### Algorithms and variants

Keep heap-ordered binomial trees, degree tags, size and cached minimum tree,
Empty/Cons/Union bag forests and foldr insertion/meld. Link ties use <= and keep
the left root; children carry descending degree tags. Forest apply traverses
Cons in forward order, while bag flattening reverses Cons order. Keep both
consolidation algorithms in their original comparison: a mutable degree array
with carry links, and accumArray-style degree grouping followed by functional
links and minimum selection. The port uses existing SML97 Array for the
encapsulated mutable operations and degree grouping.

The memoized variant retains delayed tree/heap fields and output spines. The
strict variant eagerly evaluates the same finite structures. Functional
consolidation is delayed behind shared minimum/forest projections; demanding
its heap header does not build the array. Mutable consolidation performs its
array scope before yielding the header. Both variants share one functor and
still compare the two deletion algorithms. Constructors, explicit memo cells,
portable array operations and sequence traversal are representation/library
adaptations. Used keys and indices are specialized to int.

### Inputs, result checks and runtime questions

The original normal count is 300,000. Smoke uses 100, paired normal uses 30,000
and large retains 300,000. The strict -O0 original-size pilot exhausted its
4 GiB limit; the memoized pilot passed. The smaller shared normal profile passes
its bounded strict preflight and keeps comparative inputs identical. This
stopping-parameter change and memory failure are recorded. Large SML execution
is not universally claimed.

Preserve the first seed 1967, then (77*seed+1) rem 1024. Keys after the first
lie in 0..1023; selected arithmetic, counts and sums fit 31 bits. The driver
interleaves both sorted outputs as the original equality does, additionally
checking ordering, a reviewed independent histogram, consumed length and sum.
Checking/reference acquisition costs are explicit. Original GHC observers
agree with independent histograms for all selected profiles. A separate GHC
observer verifies the distinct consolidation demand boundaries.

Nine semantic checks cover RNG prefixes, both algorithms, memoized/strict
agreement, empty/singleton heaps, forest orders, ties and delayed versus demanded
consolidation. The source discusses amortized use and retained expensive versions.
Current tree/bag sharing, array lifetimes, degree carries and strict output
retention are diagnostic hypotheses until source/IR analysis and measurements
establish them. References: retained Okasaki correspondence and
[Fredman and Tarjan (1987)](https://www.cs.princeton.edu/courses/archive/fall03/cs528/handouts/fibonacci%20heaps.pdf),
plus the shared nofib/GC/measurement survey. The source's functional heap subset
and consolidation comparison remain distinct from the paper's broader heap API.

[Complete provenance](fibheaps-lazy/PROVENANCE.md).


## fibheaps-strict

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/fibheaps/Main.lhs`.
Chris Okasaki's July 1995 correspondence says he translated the example from
SML and tested it in Gofer. Original correspondence, literate implementation,
Makefile, other retained source fragments, stdout fixture and SHA256 identities
are preserved. Individual licensing is unspecified. Inputs are generated in
source; no external dataset is acquired.

### Algorithms and variants

Keep heap-ordered binomial trees, degree tags, size and cached minimum tree,
Empty/Cons/Union bag forests and foldr insertion/meld. Link ties use <= and keep
the left root; children carry descending degree tags. Forest apply traverses
Cons in forward order, while bag flattening reverses Cons order. Keep both
consolidation algorithms in their original comparison: a mutable degree array
with carry links, and accumArray-style degree grouping followed by functional
links and minimum selection. The port uses existing SML97 Array for the
encapsulated mutable operations and degree grouping.

The memoized variant retains delayed tree/heap fields and output spines. The
strict variant eagerly evaluates the same finite structures. Functional
consolidation is delayed behind shared minimum/forest projections; demanding
its heap header does not build the array. Mutable consolidation performs its
array scope before yielding the header. Both variants share one functor and
still compare the two deletion algorithms. Constructors, explicit memo cells,
portable array operations and sequence traversal are representation/library
adaptations. Used keys and indices are specialized to int.

### Inputs, result checks and runtime questions

The original normal count is 300,000. Smoke uses 100, paired normal uses 30,000
and large retains 300,000. The strict -O0 original-size pilot exhausted its
4 GiB limit; the memoized pilot passed. The smaller shared normal profile passes
its bounded strict preflight and keeps comparative inputs identical. This
stopping-parameter change and memory failure are recorded. Large SML execution
is not universally claimed.

Preserve the first seed 1967, then (77*seed+1) rem 1024. Keys after the first
lie in 0..1023; selected arithmetic, counts and sums fit 31 bits. The driver
interleaves both sorted outputs as the original equality does, additionally
checking ordering, a reviewed independent histogram, consumed length and sum.
Checking/reference acquisition costs are explicit. Original GHC observers
agree with independent histograms for all selected profiles. A separate GHC
observer verifies the distinct consolidation demand boundaries.

Nine semantic checks cover RNG prefixes, both algorithms, memoized/strict
agreement, empty/singleton heaps, forest orders, ties and delayed versus demanded
consolidation. The source discusses amortized use and retained expensive versions.
Current tree/bag sharing, array lifetimes, degree carries and strict output
retention are diagnostic hypotheses until source/IR analysis and measurements
establish them. References: retained Okasaki correspondence and
[Fredman and Tarjan (1987)](https://www.cs.princeton.edu/courses/archive/fall03/cs528/handouts/fibonacci%20heaps.pdf),
plus the shared nofib/GC/measurement survey. The source's functional heap subset
and consolidation comparison remain distinct from the paper's broader heap API.

[Complete provenance](fibheaps-strict/PROVENANCE.md).

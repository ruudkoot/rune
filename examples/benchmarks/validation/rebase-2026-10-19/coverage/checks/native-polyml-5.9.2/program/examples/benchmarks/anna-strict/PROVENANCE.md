# nofib Anna provenance

## Algorithm and workload

Anna 0.400 parses a typed functional Core language, lambda-lifts definitions,
infers types, eta-abstracts and computes strictness abstractions over finite
domains. It builds constructor inverses, uses Hunt-style frontier search,
finds recursive fixed points and generalizes polymorphic functions through
embedding/closure compositions. Render the complete original analysis report,
including input, inferred types, search evaluations, domains and results.
Preserve 100 complete analyses per invocation and reopen the lattice table
on every repetition, as the original driver does.

## History, authorship, revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/anna.
The original banner identifies Julian Seward and Copyright (c) 1992.
README calls this release 0.400. Individual files, source input programs,
original output fixtures, lattice database and build documentation are
retained exactly, with source identities. No separate general redistribution
permission is stated in those notices. Canonical common/NofibUtils.hs has its
own source identity; the per-directory symlink target is recorded separately.

Monster.hs is a separately built auxiliary lattice enumerator, explicitly
described as outside the analyser in its heading and the original README.
Its source and Monstermakefile remain in upstream/. It is not a second
measured Anna implementation or a required runtime generator. Its explicit
inventory disposition is part of the remaining closure audit.

## Known variants

anna-lazy memoizes finite data, syntax trees, domains, routes, frontiers and
report characters. anna-strict evaluates those finite attributes eagerly.
Both retain memoized control, finite singleton lexer EOF, recursive parser builders,
demand-sensitive branches, bounded producers and unused source arguments.
Both match the complete original report on all three source inputs.
Their evaluation and allocation behavior are separately named.

## Translation and adaptations

Keep the source algorithms and orders: insertion sort, source Cartesian
product order, dependency grouping, substitution composition, type-name
supply splitting, frontier minimum/maximum insertion, randomized edge choice,
Dijkstra tie selection, successive lattice sizing, live-before-safe fixed
points, inverse construction and original report formatting. Keep the
source's special empty lifted domains and constructor/CAF conventions.

Source Int arithmetic uses explicit modular 64-bit words with signed
division, order and rendering. This includes type-name supplies and the
Schrage two-seed random stream whose constants exceed signed 31-bit Int.
Native Int is restricted to bounded byte/tag/list-adapter operations.
Integer result formatting uses IntInf only to express signed output; the
analysis does not widen arithmetic to arbitrary precision. There is no
floating-point approximation or numerical tolerance.

Translate source algebraic data and lists to explicit portable delays.
Keep unused inherited-frontier arguments as functions, including the original
unforced panic branch; eager finite data must not evaluate that control.
Keep the source's min1 reconstruction from the original max0 in Baraki
normalization. Preserve first-success parser behavior, let-bound substitutions
and source counter/ordering conventions. Source pair/tuple patterns become
closed SML97 types. Portable indentation uses the original Iseq/Oseq
continuation algorithm; small literal block lists compose append functions.

The fixed profiles use the original no-flag settings: polymorphic and
monomorphic limits 10000, lower lattice limit 0, upper 1000000, scale 20.
The driver maps repetitions and input filenames explicitly and validates each
complete-report hash before printing its signed value. It shares raw input
characters across repetitions and reads a fresh table each time. It exposes
the selected benchmark profiles rather than the analyser's entire optional
command-line interface. Unused AVL-tree utilities, the standalone Monster
main and unused command-line parsing are retained as original source, not
claimed as executed analysis work.

The Core operator parallel-or is an abstract truth-table value. It does not
execute threads and does not require a parallel Rune runtime. No compiler or
runtime feature is introduced to support the port.

## Compiler and runtime questions

Higher-order parser calls, recursive type substitution, finite-domain
representation, retained sharing, frontier search, polymorphic
specialization and report construction are diagnostic questions supported by
source inspection. Their performance effects remain hypotheses until
measured. Semantic agreement does not establish a speedup.

SML/NJ exported images execute declarations during compilation. Global
finite-data initialization and memoized streams can enter that phase.
Report compilation and fresh-process execution separately. Repeated
in-process execution retains global sharing and does not imply steady state.

## Inputs, validation and references

Smoke/normal/large use anna.faststdin, anna.stdin and anna.slowstdin, with
631/3246/9060 bytes. Preserve 100 repetitions for each profile and the complete
nine-entry runtime_files/anna_table. The resulting reports have
2810/28800/86941 bytes. Independent original report hashes agree with all
100 lines of each pinned stdout fixture: -887277049712337739,
2911885587254673792 and 1779591958989696265.

Original GHC functions independently establish complete parsing, dependency,
lambda-lifting, type-inference, eta and analysis observations. The complete
11/184/601 analysis records agree in both policies. Further observations
cover abstract routes/order/lattice operations/successors/predecessors,
lattice normalization and sizing, RNG, shortest-path ties, complete frontier
representations and memo order. All six complete formatted reports match
byte for byte. Both 100-repeat smoke drivers pass privately. Public profile, count and acceptance checks are [recorded](../results/m4-anna/README.md), including all host exceptions.

The original source establishes implementation ancestry. Baraki's
[Abstract Interpretation of Polymorphic Higher-Order Functions (1993)](https://theses.gla.ac.uk/74619/)
provides primary background on the embedding/closure approach. Source files
BarakiConc3 and BarakiMeet explicitly identify that technique. Claims about
the port's actual computation are checked against the pinned program.

### Recorded public validation

[Recorded results](../results/m4-anna/README.md) cover all 32 Rune
smoke/normal engine/level combinations, 12 complete semantic groups of 1963
checks, normal allocation agreement and full repository acceptance. Host
timeouts and the confirmed SML/NJ32 literal defect remain explicit. This
does not claim a complete large host matrix.

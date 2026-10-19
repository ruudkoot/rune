# listcopy-lazy provenance

Selected AST evaluation: lazy. Consumer: copy character spine, then count it.

## Algorithm and workload

Compile the fixed five-definition program containing list comprehensions into
applications and local recursive helper definitions, then render the result.
Each input repetition translates the original definitions again. The consumer
counts the rendered character list's spine without demanding character heads.
It computes the actual output length; 626*n is only the reviewed result check.
Full rendered texts are checked separately on small inputs.

## History, authorship and aliases

The source is nofib b7391df4540ac8b11b35e1b2e2c15819b5171798,
`spectral/hartel/listcompr/Main.hs` and `listcopy/Main.hs`, their Makefiles,
stdout fixtures and `spectral/hartel/Fast2haskell.hs`. Both complete sources and
the shared shim are preserved below upstream/. The collection name associates
these programs with Hartel; these files state no full individual authorship or
separate redistribution notice. No grant is inferred from another benchmark.
The original program labels remain in the suite names, with explicit evaluation
suffixes. The source core agrees byte for byte after removing the reviewed
benchmark label, copy wrapper and unused line-counter wrapper; the archive
records the normalization and source identities. They share the SML compiler
kernel while retaining their materially different consumer pipelines.

## Known variants and source semantics

listcompr counts the rendered stream directly. listcopy first recursively copies
its spine, retaining the same character cells. It does not reuse the original
spine, duplicate the input program, or force each character. Source `f_tp` maps
`f_td`; the nearby lambda-lifting helpers are unreachable from this workload.
Comprehension generators introduce parent-name-derived local functions; inner
let definitions retain the enclosing top-level name during transformation.
The renderer drops only the first semicolon from its `;\n` prefix, retaining
the newline. Nonalphabetic application names print the first two arguments and
ignore further arguments. The translation preserves these source quirks.

The lazy variant memoizes expression payloads and AST/list spines. The strict
variant materializes those finite AST values and spines eagerly. Both keep names,
rendered character heads/spines and the copy consumer memoized, because the source
length consumer must not demand unused characters. Fixed constructor argument
lists and the five-definition input setup use finite SML lists; their payloads
follow the selected evaluation policy. This setup translation does not attempt
to reproduce every Haskell list-library thunk. The selected program demands its
constructor argument spines; additional malformed/demand-sensitive examples are
separate semantic probes. Fast2haskell's miraseq is a no-op, despite the STRICT
comment; it is not translated as an evaluation barrier.

## Portable SML97 translation and adaptations

SML datatypes represent the original syntax; the fixed input is transcribed
through a constructor functor. Explicit memoized delays preserve sharing and
unused character heads. The length consumer is a tupled tail-recursive cursor
with a strict integer accumulator. Concatenation retains the source nesting for
rendered definitions and prefixed lists. In particular, it does not append the
entire recursive output suffix to empty at each definition: that would introduce
quadratic copying absent from the source. Only the reachable compiler/renderer
and required list operations are imported, with the full source retained for
audit. No alternative desugaring algorithm or cached transformed program is used.

The fixed constructor input, output alphabet, name/qualifier numbers and all
selected results fit signed 31-bit Int. Even the retained upstream slow fixture
has 62,600,000 characters. No floating-point or arbitrary-precision arithmetic is
in the reachable kernel. The final decimal length uses Int.toString.

## Compiler/runtime diagnostic questions

Investigate memoization, AST construction, constructor allocation, recursive
rendering, append costs, collector retention, and allocation due to the explicit
copy spine. These are source-derived hypotheses until recorded measurements
support a particular performance explanation. Allocation/count instrumentation
runs separately from timings. Finite eager AST construction and lazy character
consumption make the strict variant a distinct allocation/evaluation workload.
A private original-normal Rune O2 preflight exhausted a 4 GiB address-space limit;
this is an observed resource outcome, not a diagnosis of its cause or a host-bug
workaround. The selected normal input therefore preserves upstream FAST_OPTS.

## Inputs, validation and references

| Suite profile | Repetitions | Expected length | Upstream origin |
|---|---:|---:|---|
| smoke | 20 | 12520 | reduced correctness input of the same fixed program |
| normal | 2000 | 1252000 | unchanged FAST_OPTS |
| large | 20000 | 12520000 | unchanged NORM_OPTS; explicit scaling selection |

The original SLOW_OPTS=100000 and its 62600000 fixture remain in provenance;
that larger input is not a selected suite profile. Default time/memory limits
apply. The input shape, repetition algorithm and original input program are
unchanged. Source-profile selection is explicit, rather than silently relabeling
a reduced input as the original normal workload.

Unmodified GHC executions agree with all six original profile fixtures. A separate
Python AST desugarer/renderer agrees with the complete original transformed AST
and every byte of the 626-character program. Tests compare the complete input and
transformed output for 0/1/2 repetitions in both evaluation and copy modes; they
also check unused character heads, fresh copy spines, shared head cells, repeated
translation, renderer partiality and rejection of wrong/truncated/extra fixtures.
Profile checks count and validate every output spine. Complete evidence and
resource outcomes belong in [results/m3-hartel-compr](../../../../rune-benchmark-results/m3-hartel-compr) and validation.md.

[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) provides suite
context, rather than measurements of this SML port. The pinned suite sources
provide the algorithm/translation evidence described here. No performance claim
is inferred from the historical benchmark name.

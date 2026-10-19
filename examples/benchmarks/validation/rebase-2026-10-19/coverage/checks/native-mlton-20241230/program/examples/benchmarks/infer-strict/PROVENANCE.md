# infer-strict provenance

Selected value evaluation: strict; parser/result spines remain memoized.

## Algorithm and workload

Parse lambda/let expressions using the source's nondeterministic parser
combinators and greedy cuts. Infer polymorphic types with association-list
environments/substitutions, occurs checks, fresh variables and generalisation/
specialisation. Render the original environment, terms, types, failures and
prompts, and consume every character with the source polynomial hash.

Each of the source's 200 repetitions parses and infers all 16 input lines again.
The fresh-variable counter and substitution reset for every expression. The
initial environment/header are immutable shared setup. Source inputs include
successful inference, malformed syntax, unbound variables and occurs-check
failures; those rejected terms are part of a correct benchmark result.

## History, revision, authorship and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/infer/Main.hs and its
portable Parse, Shows, Term, Type, Environment, FiniteMap, Substitution, Infer,
InferMonad, StateX, MaybeM and MyList support. Preserve local NofibUtils, other
source members, build metadata and all FAST/NORM/SLOW input/output fixtures.
Makefile excludes TestType/TestTerm as separate support tests; the runnable
application is Main.hs. The selected program/data headers state no individual
author or separate redistribution notice. Record that absence without assigning
a grant or attribution from an unrelated component.

Names infer-lazy/strict identify evaluation variants of this application.
They are distinct from the smaller classic/nofib type-inference kernels and
retain the full parsing, polymorphism, state and rendering workload.

## Source details and evaluation variants

Parser alternatives concatenate in source order. starP/plusP retain cutP's first
result and greedy non-backtracking behavior. Its irrefutable result head and
separately delayed value/rest fields share one producer result. Both variants
memoize parser/result-list spines so cut pruning remains effective. The lazy
variant memoizes value fields and term/type constructors as well; the strict
variant evaluates those values eagerly along demanded spines. Input identifiers
use SML strings, and finite input loading/line splitting are strict in both.

Finite-map extension prepends without removing shadowed bindings. Environment
free-variable collection still sees those entries; substitution composition
retains duplicate domain entries and maps old values through one shared new
binding. Preserve first-match lookup, fresh-variable order, syntactic occurs
checks, constructor-name short circuiting and one-occurrence list subtraction.
Unequal constructor arities retain the source's partial-operation behavior.
Rejected inference returns the original failure text; unused error fallbacks
remain deferred in both variants.

## Portable SML97 translation

SML functors express the parser and kernel; explicit memoized delays preserve
sharing. The source's nested StateX/Sub/Counter/Maybe machinery becomes curried
state functions returning an option with the same value/substitution/counter
order. Administrative wrappers are fused, while association lists, substitution
composition, fresh names and update order remain. It is a translation of these
modules, rather than a replacement by mutable union-find inference.

Recursive display functions emit delayed characters with the original precedence,
spaces, parentheses and prompts. ASCII profiles retain exact character behavior;
Unicode outside the retained input domain is not claimed equivalent to Haskell.
Source counters and list sizes fit signed 31-bit Int. The source GHC 64-bit hash
uses explicit Word64 multiply/add wrapping, with its signed result checked via
the equivalent unsigned bit pattern on every SML host width.

Reading the fixed input file anew for each repetition replaces NOINLINE salt
with a portable opaque I/O dependency. This adds input loading costs and prevents
reusing previous inference results as repeated-run answers. The reference file
is also consumed anew. Every rendered byte/EOF and the independent expected
hash are checked before aggregating repetitions:bytes:checked instead of
printing 200 signed hash lines. Checking and I/O are included measured work.
No compiler/runtime extension, FFI or parallel feature is required.

## Profiles and diagnostic questions

Smoke, normal and selected large retain the exact FAST/NORM/SLOW files and all
200 repetitions. Each has 16 lines, with 348/693/1108 bytes; they vary the final
polymorphic-identity application chain. Complete rendered outputs contain
643/990/1404 bytes. Source parse/type failures remain in each input profile.
Default time/memory limits apply. Repetitions are bounded to 1..200 in the driver;
normal profiles do not reuse parsed terms or inferred types across repetitions.

Diagnostic questions concern parser closures/cuts, value demand, association-list
search, shadowed entries, substitution sharing/composition, generalisation,
intermediate type lifetimes, character streams, Word64 hashing and checking.
These are source-based hypotheses until supported by measurements. Standard
reports compare identical SML; Haskell supplies correctness references.

## References and validation

The unmodified original reproduces all three 200-line upstream stdout fixtures.
Export-only observers retain complete rendered texts; an independent polynomial
hash reproduces every original signed result. A separate parser/Algorithm W
model agrees on all 48 profile expressions, comparing types modulo variable
renaming and checking parse/type rejection. It supplements exact source-output
comparisons without specifying every source-parser quirk.

Twenty-four additional original full expression sessions cover parsing, shadowing,
polymorphic let, repeated application, occurs checks and literal let-prefix
behavior. Original boundary observations pin greedy cuts, substitution domain
order/duplicates and shadowed environment variables. Tests compare both full
outputs and check cut demand/sharing, constructor short circuiting, occurs checks,
source partial arity behavior, line splitting and changed/truncated/extra output
or hash rejection. Current bounded Rune preflights reproduce all three complete
texts and both full 200-iteration normal computations. Other validation is claimed
only where recorded.

Luis Damas and Robin Milner, [Principal type-schemes for functional programs](https://doi.org/10.1145/582153.582176),
POPL 1982, pp. 207–212, supplies context for polymorphic let inference. The retained
modules specify this particular implementation and its parser/data behavior;
the paper does not establish current compiler rankings. The suite's nofib and
measurement survey supplies experimental context.

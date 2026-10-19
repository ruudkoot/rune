# CS provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/eff/CS`.

## History, source and notices

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

## Algorithm and variant differences

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

## Inputs, demand and validation

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

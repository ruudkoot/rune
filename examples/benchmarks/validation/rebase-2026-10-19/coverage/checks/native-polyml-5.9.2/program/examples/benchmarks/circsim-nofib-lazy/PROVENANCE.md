# circsim-nofib-lazy provenance

Evaluation: lazy. Consumer: printed heads/newline.

## Algorithm and workload

Simulate register circuits through the original immutable processor-state
records, port latches, packet lists and balanced-tree bidirectional scans.
Each clock stores inputs, sends depth-zero messages, evaluates/sends each path
depth, then restores request flags. Routing repeats until requests are acknowledged.
Preserve the register generator and padded processor count. Selected inputs are T.

## History, authorship, revision and aliases

The literate program credits David J. King and John O'Donnell, January 1998.
Its introductory email is dated 2 October 1998 and explicitly calls this sequential
code written with data-parallel combinators. The pin is nofib
b7391df4540ac8b11b35e1b2e2c15819b5171798, gc/circsim/Main.lhs and
spectral/circsim/Main.lhs, their Makefiles and spectral stdout fixtures.
Complete source bytes are preserved. The files state no separate redistribution
notice; attribution does not infer a grant. The inventory recognizes the exact
literate authorship heading.

Full source comparison finds only the main consumer/comment different: GC forces
length(show(run ...)) then returns unit; spectral prints the shown trace.
Share the simulator implementation while retaining the inventory names circsim
(GC) and circsim-nofib (spectral), each with lazy/strict evaluation suffixes.
Their head demand and output work differ materially.

## Evaluation variants and source quirks

Signals use a separate F/T datatype, distinct from routing flags. The method
named xor implements equality (XNOR); retain it even though the register example
uses other gates. Empty packet extent is one, routing windows use strict >, and
the sto distance stays 8*(bits-1)+5. Input updates preserve the right fold and
left-after-right overwrite order. The unused debug packet printer misnames its
arguments; actual tuple positions follow algorithm use.

The lazy variant memoizes signals, states, port/packet lists, tree nodes and
summary directions. The ignored scan-root reduction stays undemanded. The strict
variant constructs these finite values/spines eagerly. Both retain constructor/
depth guards and synchronous snapshots. Dff reads the previous clock's latch.
Signal and/or short circuit; identity gates retain cells. Input rows, padding
states, F/T values and packet values are shared. Unused label names stay deferred
in the lazy variant. Finite generators replace consumed prefixes of infinite
enumerations without changing selected values or order.

Output character streams remain memoized in both modes. Derived Show chooses F/T
by inspecting the Boolean, so GC's show-spine consumer still demands simulated
Boolean values, while leaving character heads unused. The printed consumer
forces those heads and its newline. Per-Boolean/punctuation checks run at the
same render-spine demand points. No later forced trace pass changes retention.

## Portable SML97 translation and adaptations

Retain state/port products, component/Boolean datatypes, packet tuples, scan trees,
maps, folds, transpose and immutable updates. A separate hold/load model is only
an oracle. The Signal class specializes to its sole active Boolean instance.
Standard SML records/products and memoized cells model source structures. Static
port descriptions use finite SML lists before suspended-list wrapping; this setup
translation is recorded. The measured simulator keeps functional state history.

Depth checks precede gate evaluation. Input gates can return Nothing without
demanding signals. Shared directional summaries and unused labels preserve
selective demand. Debug printers and unused input-enumeration helpers remain in
original source outside the runnable kernel. Sequential scans need no added
parallel runtime or compiler feature.

The shared driver reads profile arguments and a reviewed trace once, then
constructs/consumes a fresh circuit for every original iteration. Every Boolean,
structural character and EOF is validated without forcing unused character heads.
Printed mode additionally computes sum(ord output)+length over the original
newline-terminated characters. Controlled summary output replaces individual
writes; GC's original output remains empty. Report
repetitions:consumed-characters:head-checksum:source-output-bytes, with GC checksum
and byte fields zero. Decimal summary formatting happens after the work loop.
All added validation work is included in the identical SML compiler comparisons.

Selected identifiers, extents, distances, lengths, checksums and totals fit signed
31-bit Int. There is no reachable floating-point or arbitrary-precision arithmetic.
Normal/large retain width, clocks and all 97 source repetitions; smoke reduces
only repetitions to one. Default suite limits apply.

## Compiler/runtime diagnostic questions

Investigate prefix specialization, tree/record allocation, shared values,
short circuiting, selective forcing, retained clock state, eager/lazy metadata,
unused names, character-head demand and GC behavior. These are source hypotheses
until measurements establish effects. Comparisons use identical SML; Haskell
supplies correctness references. Counts/profiling, serial diagnostics and
headline timings retain separate scopes.

## Inputs, validation and references

Unmodified spectral executions match all three complete 97-line fixtures. GC
has no stored stdout fixtures and returns unit without output; its empty output
is checked as source behavior. Export-only observers from both copies agree on
full traces and shown lengths. Source versions and runtime flags are recorded.
An independent register model predicts previous stored bits with sto-selected
load/hold and agrees with five varied original traces at widths 1/2/3/8/16.

SML tests cover profiles/consumers, repeat formatting, varied data, wrong/truncated/
extra/checksum-colliding references, unused heads/labels, empty-input demand,
ignored root summaries, XNOR, inactive guards, routing boundaries, packet payload
demand and ragged transpose. Whole normal Rune O2 pilots retain 97 iterations
in all four combinations. Other host coverage belongs in validation.md.

[The pinned literate program](https://gitlab.haskell.org/ghc/nofib/-/blob/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/circsim/Main.lhs)
establishes authorship, algorithm and sequential execution.
[Blelloch's prefix-sum survey](https://www.cs.cmu.edu/afs/cs.cmu.edu/project/scandal/public/papers/CMU-CS-90-190.html)
provides scan background; [Partain](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides suite context. Parallel algorithm literature supplies background for
these sequential combinators.

| Profile | Width | Clocks | Repetitions | Suite result |
|---|---:|---:|---:|---|
| smoke | 8 | 4 | 1 | 1:74:4944:74 |
| normal | 8 | 40 | 97 | 97:722:49080:70034 |
| large | 8 | 200 | 97 | 97:3602:245240:349394 |

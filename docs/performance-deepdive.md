# Where Rune spends time

This investigation follows [the November 23 performance report](performance.md).
Its Rune compiler and VM are from `9c0999f9c713736d3ca1c7bd300a10383e54deee`.
The native hosts are MLton 20241230 and Poly/ML 5.9.2. The benchmark source
revisions, normal inputs, HOL4 images, and compatibility settings follow
that report. The primary parity target is a Rune/host ratio at or below
1.00 on the original metric for the same work and configuration.

[Small programs](#what-the-small-programs-show) · [Shared mechanisms](#mechanisms-shared-by-larger-workloads) · [Compiler and HOL4](#compiler-and-hol4) · [Optimization order](#optimization-order) · [Workload tables](#workload-coverage)

## Reading the evidence

The ratios in the performance report are the baseline. Its nominal
parity counts against MLton and Poly/ML respectively are 1 of 9 and
2 of 9 in the small cycle set, 1 of 38 and 11 of 36 in the 38-case
cycle set, and 11 of 113 and 59 of 122 in the catalogue at the report's
aggregate timing cutoffs. A Rune/host ratio of `r` above 1.00 needs
a reduction of `1 - 1/r` in Rune time at the same host time. The replay uses
the retained bytecode and host executables. It copies the benchmark's
original input files into each run's private directory and checks the
answer before accepting counters. The catalogue replay verified 5,711
artifact and input files against retained SHA-256 fingerprints.
Diagnostic rebuilds record their commands and verify the original answer. The x86-64 PMU profiles and
Callgrind counts support different claims. A weighted cycle sample
locates time. The Callgrind instruction count locates executed code.
Startup-heavy programs use longer, checked diagnostic runs to expose the
body. Their original fresh-process ratio still includes load and JIT
startup. For a sufficiently sampled single-run pair, each estimated
cycle difference applies its sampled category share to its independent
cycle count. Repeated-body profiles and tiny samples give qualitative
locations. The signed estimates describe the replay and can differ
from the original timing order. When at least a third of either
profile is unresolved or stripped, the table gives the unnamed
shares in place of an estimated category difference. Each sample receipt records core and
load. Some diagnostic runs overlapped validation or other replays.

MLton's native executable often has labels such as `L_617` for generated
blocks. Poly/ML's exported executables often map generated samples onto
`area1`. That symbol locates the generated-code region. Source and
diagnostic compiler listings provide more detail for representative
cases. An unresolved symbol or a small sample leaves some of the gap
unaccounted for.

The receipts live in `tests/out/deepdive/` in the sibling
`performance-deepdive-measure` worktree. The original `performance.md`
run and its receipts remain in the report worktree. Each replay writes
its command, answer, counters, and sample locations beside its result. The receipt index is `profiles.tsv`.
A resource and validation note follows the tables.

## What the small programs show

The startup controls use the same executable at zero, one, and two
batches. The number of repetitions comes from the environment so the
compiler retains the benchmark in each configuration. For example,
the `fib` zero-batch medians were 3.31 ms on Rune, 1.44 ms on MLton,
and 5.17 ms on Poly/ML. At 50 and 100 iterations, Rune measured
38.6 and 66.1 ms. The first batch includes demand compilation as well
as the call body. Similar controls for all nine small programs live
under `startup/test-perf`; the catalogue measures the elapsed time
outside its own timed body separately.

### Calls and frame traffic

`fib` executes 196.6M instructions on Rune against 127.8M on MLton and
112.3M on Poly/ML. The reported cycle ratios are 1.14 and 1.24. In the
verified Rune Callgrind run, compiled code accounts for 195.1M of
197.0M process instructions. Only 75.0M of the compiled instructions
are in the instruction bodies. Counter updates, landings, and frame
operations each account for about 22.5M. Returns and room checks each
account for about 15.0M.

Rune's two recursive `CALLK`s write the live value out, check frame
space, set the argument, save a landing address, then jump. Each landing
adjusts the stack and reloads the preserved value or moves the result.
The overflow branches are part of the arithmetic fast path. MLton's
retained listing has recursive continuation blocks and a dedicated
stack-check block. The Poly/ML listing exposes the recursive calls and
native frame and stack operations in `runeBody__(1)fib(1)`. The three
listings establish a shared cost to making the calls, with the Rune
role counts quantifying its own additional work. Exact host per-call costs still require a dynamic block or call count. See
`code/fib` and `callgrind/fib/roles`.

`tak` offers a second control with three non-tail calls and a tail call.
Rune is within 4% of Poly/ML's cycle count and uses 1.20 times MLton's
cycles. A smaller known-call protocol is worth testing against both.
Use `Workers` or the lowerer to identify direct calls with known
arity and representations. Reduce unnecessary home stores, reloads,
and frame work in `Regs` and the tier-2 emitter. Keep stack-space checks,
precise live roots, safepoints, exception unwinding, and budget checks
valid. Measure instruction-count batching at legal checkpoints
separately because observable limits and polling can constrain when
the count moves. Check the recursive language tests, deep recursion,
GC stress, and interpreter/JIT trace agreement.

### List and string materialization

`string_ops` is at 2.93 times MLton's cycles and 2.38 times Poly/ML's.
The code creates lists for tokens and character reversal, then
materializes the result of `String.translate` just to count its bytes.
Rune's Callgrind run attributes 147.0M of 868.4M process instructions to
JIT code. Hot samples include promotion and list-cell allocation, so an
emitter-only improvement has limited reach here. MLton's profile also
shows sequence allocation and copying. Poly/ML has generated-code
samples and collector samples. The two host gaps include different
amounts of out-of-line work.

- The checked reversal probe replaces explode, reverse, and implode with
  direct indexed construction. On this input, Rune instructions fell
  from 862.9M to 691.7M and allocation fell from 81.9 MB to 63.5 MB.
- The checked length-only translation probe counts non-space characters
  directly. Rune instructions fell from 862.9M to 662.9M and allocation
  fell from 81.9 MB to 57.8 MB. Both probes leave the expected output
  unchanged.

Work on bulk string construction in the Basis first. Then extend
`Simplify` to recognize producer and consumer combinations when the
consumer needs only the length or a fold. A general translation callback
may raise, mutate state, or return varying lengths. A rewrite still
needs to evaluate it in the original order and preserve exceptions.
Use an explicit bulk operation for known-pure reverse and length
cases. Check empty strings, embedded NULs, overflow and size bounds,
and callbacks with an observable trace. The independent probes can
overlap in the work they remove. See `probes/reverse` and
`probes/translate-size`.

`list_ops` has a smaller gap against both hosts. Replacing
`List.rev doubled @ l` with the existing `List.revAppend (doubled, l)`
lowered Rune instructions from 254.7M to 196.0M and allocation from
34.0 MB to 29.2 MB. The source probe removes one materialized list
spine while preserving the final traversal order and answer. Make that
rewrite in `Simplify` for evaluated operands. Review other map, filter,
and fold combinations individually because effect order and exception
position can be visible. Keep the bounded stack behavior described in
[the Basis performance plan](plans/performance/basis.md). See
`probes/rev-append`.

### Tight loops, tags, and arithmetic

- **`word_bits`.** Rune's Callgrind trace puts 151.5M of 175.0M process
  instructions in JIT instruction bodies. The retained program counts
  bits one at a time inside a 30-bit xorshift loop. The checked parallel
  bit-count probe uses 32.2M machine instructions against 174.4M for
  baseline Rune. Its allocation stayed at 6,032 bytes. This points to
  the loop idiom before register or frame tuning. Recognize the
  shift, mask, and add loop with a known target width in Low, lower a
  popcount primitive to the CPU feature when available, and retain a
  portable fallback. Preserve conversion and overflow behavior.
  See `code/word_bits` and `probes/fixed-width-popcount`.
- **`array_sieve`.** Checked array reads and writes remain in the
  strike and scan loops. Callgrind counts 7.4M poll instructions in the
  generated code. The packed byte-array source probe halves allocation
  from 16.4 MB to 8.0 MB, with machine instructions rising from 138.8M
  to 162.7M. Packing needs a low-cost load and store path before
  shipping it as an automatic representation change. Start with
  bounds and representation facts in Low and loop-aware guards in
  tier 2, then test packed flags with the same checks hoisted.
  Include negative and out-of-bounds indices and reference-valued
  arrays in the regression suite. See `probes/byte-flags`.
- **`hash_mod`.** The hot tier-2 loop already uses multiply and shift
  sequences for literal divisors. The remaining SML comparison is
  1.18 times MLton's cycles and 0.40 times Poly/ML's. Inspect
  redundant overflow and range checks and the bounds check on the
  string byte before revisiting the division lowering. The fixed
  normal input holds each lane below the SML reference's range. Any
  general rewrite needs a range proof and the right SML floor-modulus
  rule for negative values. See `code/hash_mod/jit.disassembly`.
- **`real_nbody`.** Rune's cycle ratio is 0.97 against MLton and
  0.54 against Poly/ML, even though it executes 3.21 times MLton's
  instructions. The dependency chain contains a square root and two
  divisions each iteration. Assembly inspection and a dependency
  probe are required before turning the instruction gap into a
  predicted cycle gain. Keep a check on boxed values, tuple
  materialization, and real arithmetic without changing rounding
  or exceptional-value semantics.
- **`intinf_fact`.** Rune still uses 6.38 times MLton's cycles and
  1.18 times Poly/ML's, including multiplication, quotient and
  remainder, decimal conversion, and exponentiation in the same
  workload. A checked small-int induction variable and tail-recursive
  accumulator raised Rune instructions from 13.4M to 15.3M and
  allocation from 175 kB to 208 kB. The original diagnostic
  batch makes 1,244 GMP calls and 3,733 GMP allocations.
  Optimizing the recursion alone
  therefore needs stronger evidence. Use the existing IntInf path
  counters and separate factorial, division, and decimal probes.
  Prioritize routing a small operand through compact or single-limb
  multiplication where the measured size distribution warrants it.
  Check dispatch around the immediate limit, all sign combinations,
  and conversions. See `probes/small-induction`.

## Mechanisms shared by larger workloads

### Text and streams

The external `output1` workload makes one billion single-character
calls. Rune allocated 16.0 GB and 1,000,000,316 objects in the original
count. MLton allocated 6,024 bytes. Rune's Basis implements the stream
operation as `outputWith (strm, V.fromList [e], "output1")`, so even the
device path builds a singleton vector on every call. In the replay,
roughly 33% of Rune's weighted samples were in user-space I/O and 13%
were in runtime allocation. The largest native samples on both hosts
were in generated code. Those profile categories are sampled locations,
and fast allocations can occur inside generated code.

A 20M-call diagnostic reuses a one-byte vector and calls `output`. Its
Rune allocation fell from 320 MB to 8.1 kB. The median dropped from
7.35G to 4.90G cycles and from 12.0G to 8.43G instructions. A separate
file check verified all 65,536 output bytes for both call paths.
MLton and Poly/ML used 0.25G and 1.88G cycles for the original call
in that paired diagnostic. The companion profile of the reused-value variant spends about 49%
in user-space I/O, up from 29% for its paired stock-source profile.
The remaining gap calls for fewer operations at the writer boundary
as well as fewer temporary objects.
See `structural-probes/output1`.

Give device-backed streams a scalar write operation. Specialize the
`TextIO` and `BinIO` paths through the existing stream abstraction.
Keep the custom writer fallback. Check all buffer modes, newline
flushes, custom writers, partial writes, close and flush order, and
the function name and position in an `IO.Io` exception. A later
`Simplify` or Low optimization may batch a run of writes when the
stream, buffer mode, effects, and error ordering are known. Arbitrary
user writes require those proofs.

`wc-input1` shows the corresponding read path. Rune's replay attributes
about 34% to `RuneStreamIOFn.input1`, 27% to the consumer loop, and
7% to `RuneStreamIOFn.force`. MLton's hot blocks are in its program,
and Poly/ML's are predominantly in `area1`. The catalogue median is
0.04 s on Rune, below the report's 0.01 s precision on MLton, and
0.06 s on Poly/ML. Optimize the buffered byte or character read and
its inlining into the consumer. Re-run both `wc` variants and test text
EOF, empty reads, a line boundary split between buffers, and binary
files. `string-concat` instead puts about 80% of the short Rune profile
in its vector-construction loop. Use the string and list probes above to
separate copying from allocation and callback overhead.

### Calls and checked loops

The archived `matrix-multiply` profile places 64% of Rune's sampled
cycles in `RuneArray2.sub` and 36% in the surrounding loop. The peer
profiles place most of the sampled cost in generated code. The
`Array2` implementation already has flat storage, with separate
row and column checks, a linear address calculation, and a further
Array access.

The checked 200-by-200 probe held the dot-product order and confirmed
three cells against independently computed sums. Rune's `Array2`
version used 860M cycles. Using a directly indexed flat `Array`
took 382M, and a flat `RealArray` took 321M. MLton and Poly/ML
took 75M and 611M on the same `Array2` fixture. Direct indexing
closes part of the MLton gap, and this representation probe clears
the Poly/ML target on this size. See `structural-probes/matrix-multiply`.

Add range and address facts at Low after inlining known accessors.
Hoist dimension and loop-bound checks, reduce a row stride to an
induction variable, and keep a checked fallback for unknown indices.
Use real payloads directly where they only flow through numeric
operations. Preserve `Subscript`, `Size`, integer overflow, real
rounding, and evaluation order. Verify the full original matrix
workload before extrapolating from the reduced fixture.

`flat-array` is a different case. It folds a vector of Int32 pairs
under an overflow handler. In its batched profile Rune spends about
51% in the fold callback and 32% in `Vector.go`. MLton's measured
profile is almost entirely generated code. Poly/ML spends about half
its profile in collector functions on this case. Specialize the
known fold callback and scalarize fixed-width pair payloads through
`Workers`, `Simplify`, and Low. Keep overflow recovery at the same
logical iteration.

The catalogue `stack_push_pop` loop is almost entirely generated code.
The Rune listing still allocates a 24-byte cons, loads and stores the
contents and length references, and checks the restored length per
iteration. A controlled 20M-iteration test held the expected completion
count and measured 1.23G Rune cycles, 453M for MLton, and 455M for
Poly/ML. Replacing only the IntInf induction value took 1.20G cycles.
Removing the transient push/pop pair while retaining the length check
took 295M cycles. The combined variant took 212M. This isolates the
dominant cost in this fixture. Specialize after inlining so the pass
can prove the updated object is local, the popped value is unobserved,
and no callback or exception handler can see the intermediate state.
See `structural-probes/stack_push_pop`.

The checked word-bit probe ran against both original host binaries on
one core. Its median was 17.0M cycles against MLton's 28.2M and
Poly/ML's 47.7M. The paired Rune baseline was 88.5M. The source probe
establishes the opportunity for an idiom recognition pass. A proposed
POPCNT lowering still needs its own cross-architecture and
feature-selection checks. See `probes/fixed-width-popcount/paired.json`.

### Allocation and collection

On the catalogue `DLXSimulator` replay, collector functions account for
about 47% of Rune's sample weight, 19% on MLton, and 11% on Poly/ML.
Applying those shares to each run's counters attributes about 52G of the
86G Rune–MLton cycle gap to the collector. The corresponding estimate
is about 56G of the 92G Rune–Poly/ML gap. Rune's top samples include
`promote`, object scanning, `List.go`, and append. The collector gap
establishes a large opportunity. Allocation-site census and a
matched retention experiment can identify which list spines, decoded
values, and closures survive long enough to cause it.

In the catalogue `constraints-strict` replay, Rune's collector share is
about 39%, with object scanning its largest named sample. The
collector estimates put about 50G excess cycles against MLton and
81G against Poly/ML in collection. The `ansi-strict` estimates
put about 18G and 17G excess cycles there. This points first to
allocation sites and object lifetimes. For lazy and symbolic-search cases, check whether
a captured thunk escapes, is forced once, or memoizes a shared value
before moving it to stack or scalar storage. An allocation-site census
can distinguish a temporary created in a tight loop from a genuinely
long-lived graph.

Start with the materialization changes supported by the string and
list probes. For the remaining allocated objects, propagate
non-escape and known-constructor facts through Mid and Low and scalarize
records and tuples that never require identity. Validate closure
capture, sharing, relocation, and precise safepoints. Tune nursery
placement and promotion only after measuring which sites and ages
survive, with both a throughput workload and a latency workload in
the acceptance test. Check peak residency as well as the cycle ratio.
The [collector plan](plans/garbage-collector-v3.md) describes the
runtime changes that can host those experiments.

### Memoized delays

Several nofib ports implement call-by-need in Standard ML with
`BenchLazy`. The reference cell can hold a pending closure, a value,
an exception, or the evaluating marker. Rune's named sample for
`BenchLazy.force` accounts for about 24% of the weight in `fish-lazy`,
27% in `calendar-lazy`, and 30% in `fibheaps-nofib-lazy`. The largest
estimated excess varies by host. The `fish-lazy` replay places much of
the MLton gap in generated code and more of the Poly/ML gap in Rune
runtime work. Collection accounts for a sizable share in all three
Rune profiles.

Separate, answer-checked counters on the normal Rune inputs count
444.2M created cells, 393.3M evaluations, and 56.7M memo hits in
`fish-lazy`. `calendar-lazy` creates 220.4M, evaluates 199.7M,
and has 34.1M memo hits. `fibheaps-nofib-lazy` creates 193.6M,
evaluates 193.5M, and has 104.2M memo hits. The memo hits establish
real sharing. They also show why optimization needs a per-site
escape or usage argument before removing a memo store. See
`lazy-counts.log`.

First inline and specialize the force path when the representation
is known. Test compact storage for a ready value and its tag.
Use escape and usage information to elide a pending cell or a
second state object when the caller can establish one-shot use.
Preserve memoized exceptions and recursive-force detection.
Validate the change with both a one-shot stream and the
fibheap replay, which has frequent memo hits.

### Integer ranges and representations

The original `psdes-random` workload allocates 27.0 GB in Rune and
1,112 bytes in MLton. The implementation iterates four `Word32` lanes
with tuple state and array lookups. About 99% of all three replay
profiles is in generated code or the enclosing Poly/ML generated-code
area. For Rune, the single hot JIT function takes about 75% of the
cycles. An optimized collector alone has little profile budget here.
Use per-allocation-site instrumentation to split intermediate tuples
from fixed-width result values before choosing the representation.

Carry modulo-width integer facts through `Simplify` and `LowShapes`.
Specialize loops whose producers and consumers agree on the width.
Keep a raw register value between arithmetic operations and convert
at escapes to ordinary references, closures, generic arrays, or an
object field. Keep boxed layout and GC maps correct at every crossing.
Use the `Word32` arithmetic and overflow edges, `psdes-random`,
`word_bits`, and `flat-array` as acceptance workloads.

In `mandelbrot-rat`, Rune spends about 10% each in GMP export and
import, with about 15% in the SML GCD. MLton's sampled GMP work
includes quotient shifts and limb shifts. Poly/ML's main generated
region absorbs nearly all its samples at this granularity. The
replay estimates about 1.1G additional Rune cycles against MLton
in the integer runtime and about 1.2G against Poly/ML in that same
bucket. The estimate describes where Rune's samples land. A typed
small-operand kernel and scoped allocation counters can resolve how
much of the advantage comes from dispatch and conversions.

Extend the compact or single-limb arithmetic path for the operations
and operand sizes confirmed by those counters. Preserve representation
independence, signs, zero and one cases, division rounding, and the
GMP size and memory limits. Keep separate checks for IntInf conversion
and arithmetic on numbers beyond one limb.

### Repaired catalogue fixtures

The original `reverse-complement` recipe omits its BenchInput
dependency. A private replay that supplies the existing helper
passes the expected-output check on all three engines. Its user-mode
cycle counts were 339M on Rune, 144M on MLton, and 471M on Poly/ML.
Rune has object-scanning samples. The short MLton run has few
samples, so its instruction count and correctness receipt support a
comparison more directly than individual cycle buckets.

For `id-ray`, placing the existing `DATA` files in the private
compile directory lets Poly/ML load the source and produce the
correct answer. The replays count 4.82G, 1.40G, and 6.73G cycles
on Rune, MLton, and Poly/ML respectively. About 95% of Rune's
sample weight lands in `Ray.sphmap`. MLton's top label is
`L_2022`, and Poly/ML's main region contains about 93% of its
samples. That puts the measured difference mainly in generated code.
Poly/ML's build performs some input work while loading declarations,
so the repaired run is a targeted diagnostic with different staging.
The isolated replays and their source changes are in
`catalogue-fixture-probes` and `catalogue-repaired`.

## Compiler and HOL4

### Compiler throughput and startup

The `compile-hello` control executes 350M instructions on Rune, 56M
on MLton's build of Rune, and 38M on Poly/ML's. In the independently
timed pass summaries, Rune uses 51 ms of startup out of 94 ms of
processor time. MLton starts in about 1 ms out of 13 ms and Poly/ML
in about 5 ms out of 17 ms. The Rune replay's named samples include
the loader, JIT compiler, and libc. Phase instrumentation and a small
number of samples make the exact attribution approximate. The evidence
puts loading and cold tiering ahead of a middle-end rewrite for this
input. See `phases/hello.*.stats` in the original run and
`test-perf/compile-hello` in the replay.

`compile-sigs` uses 3.88 times MLton's cycles and 4.62 times Poly/ML's.
In the Rune replay, roughly 37% of the sample weight is in the JIT
compiler, about 21% in generated code, and 12% in the interpreter.
Its elaborator trace places 91.5% of elaboration in the core bucket
for this input. Loading the Basis includes `IntInf`, `List`, and
`Real` among the expensive declarations. The report's engine controls
show that another execution engine moves the cycle result at the same
input. Use cold-threshold and warmed-compiler controls before selecting
a JIT cache, reduced startup work in library selection, or a new pass
in the signature elaborator. See
`compiler-analysis/test-perf-compile-sigs`.

`runedoc-page` spends more of its weight outside generated code than
the full compiler. The replay classifies about 20% as JIT compilation,
13% as primitive work, and 10% as interpreted code, with individual
string explode and concat samples. Relative to MLton, JIT compilation
is the largest identified excess bucket. Poly/ML spends most of its
recorded samples in its generated region. The string construction
changes and a cold-start optimization target different parts of the
gap. Run doc generation's expected-output tests and keep emitted
Markdown byte-for-byte equal.

For the pinned self-bootstrap, the three engines emit identical
compiler bytecode. Reported pass totals are 8.66 s on Rune, 6.99 s on
MLton's build, and 6.74 s on Poly/ML's build. On Rune, simplify, lower,
and register allocation account for about 3.82 s. On the other builds
they account for about 3.34 s and 3.18 s. The replay attributes roughly
54% of Rune's sample weight to generated code and 28% to the collector.
About 3.5G of Rune's extra replay cycles against MLton fall in
collector symbols. Against Poly/ML, the largest identified excess is
other Rune runtime work, with GC still contributing. These are
different implementations of the same source stages. Phase timings
locate the costly work, and the host profiles explain part of the
cost of running it.

Prioritize less allocation in Mid simplification and Low construction
and profile the integer maps and compiler worklists. Pool phase-local
data only when it cannot escape its lifetime. Preserve deterministic
stamps and output, live-root correctness, and behavior at every
`--fuel` boundary. A persistent or preloaded compiler should also
be tested under cold and warm library-index states. Keep its cache
keys tied to binary, source, flags, and representation identities.

### Signatures, functors, and the pinned MLton sources

For the module fixtures, the measured comparisons run the same Rune
compiler sources on all three engines, with the generation recipe
and target held fixed. The sharing cases expose ordered-map work
under Rune. The `where type` and exponential fixtures also show
cold JIT work. The nested-functor fixture has a substantial scan
and collection component. Tiny host profiles leave individual
optimized blocks unresolved. The appropriate controls are a
loading-only compile and a size sweep using the generator. Start
from each fixture's base receipt. The scale cases in `make perf-check`
have larger inputs and are useful as a separate asymptotic guard.

In the pinned whole MLton compile, the originally timed Rune/MLton
host ratio is 1.03 for processor time, with 2.48 times the machine
instructions. The whole-program outputs match. Both profiles have
substantial collector work. Rune's profile includes `mark_full`,
`mark_obj`, and `OrdMapFn.go`; MLton's includes `performGC`,
forwarding, and depth-first marking. The diagnostic elaborator trace
attributes 35% of Rune's elaboration to instantiation and 29% to
matching for this input. `PRECEDENCE_PARSE_STRUCTS`, the AMD64
code-generator functor, and the x86 code-generator functor are the
longest named declarations in that trace. Expansion visits 391
applications, and a single application can copy about 486,000 IR
nodes in the diagnostic build.

An additional replay of the exact whole input with the Poly/ML
build of Rune also emitted the same bytecode. It counted 757.0G
instructions under the 12 GiB virtual-address limit used by the
other hosted runs. Its most expensive phase was elaboration
(445 s in that replay) and roughly 69% of the diagnostic sample
weight was in the collector. The corresponding shares were
about 50% on Rune and 48% on the MLton build of Rune. This
comparison uses the same elaborator and active compiler sources,
with potentially different heap pressure.

The original units run accounts for 44.3 s in interface and link
stages out of 102.4 s total. The hash trace records 7.8 MB through
signature usages and 6.7 MB through functor usages. Memoize a
signature or functor fingerprint at the immutable summary boundary,
reuse dependency slices keyed by the observed names, and avoid
walking whole type or module environments when a summary suffices.
Keep fresh type names, sharing equations, named dependencies, and
invalidation under edits sound. Extend the current elaborator
realization and matching caches before considering more widespread
representation changes. Preserve the module tests, compile-in-units
bytecode equality, and determinism. Test the same large compiler
input and the normal and scaled signature/functor fixtures.

For the second-stage compilation cases, the executable measured on
Rune is MLton itself compiled by Rune. Its baseline is the native
MLton release, and the driver runs the same wrapped sources and
sizes under each. Those rows measure MLton's algorithms running on
different engines. The large `mlton.mlb` row uses the same pinned
MLton source. The bounded Rune-hosted replay linked the same ELF
executable byte-for-byte as the timed run. Of its 364,099 profile
samples, the weighted shares are about 43% generated code, 15%
collector work, 14% other Rune runtime work, and 14% integer-runtime
work. `scan_dirty`, `Id.make`, list loops, and GMP import and export
are visible. The native MLton release build is stripped, with about
89% of its samples in its unnamed compiler executable. The host
profile sets a bound on fine-grained subtraction. First test the
list and lookup work on Rune, lifetime of intermediate compiler
objects, and integer conversion traffic. Those are the evidenced
opportunities in this compiler workload. See the compile-target
table and `mlton-build/mlton` receipts. A separate, version-matched Poly/ML build of the pinned MLton
sources compiled the six benchmark inputs to executables. The
full `mlton.mlb` run on that host was terminated during the
previous boot's out-of-memory event. Its incomplete output remains
with the raw receipts. The bounded follow-up uses the common
`-stop tc` phase as a frontend control. Rune-hosted MLton took
81.84 s of CPU time through type checking, compared with 64.19 s
for native MLton. Rune executed 370.5G instructions and the
native release executed 102.7G. The 1.27 CPU-time ratio is much
smaller than the report's 4.50 full-build ratio. Most of the
full-build CPU gap therefore falls after type checking. The
next phase boundary to measure is `-stop g`, which exposes
how much remains for the assembler and linker while preserving
MLton's upstream pass pipeline. The bounded Poly/ML-hosted
type checker also completed and used 81.84 s and 362.1G
instructions. Its profile spends about 60% of the sample weight
in the collector.

### HOL4 proof scripts and kernel operations

HOL4's original theory measurements use HOL's own theory clock.
The Rune/Poly/ML time ratios are 1.66 for `logroot` and 1.67 for
`mergesort`. The profile replay around Holmake includes theory
setup and rebuild work outside that clock. Keep that distinction
when reading the profiling remainders. Direct replays of the
proof subprocesses captured their generated script and interface,
ran against the saved states, and verified theory exports on
both engines. The Rune symbol lists for both theories include
`Portable.pair_compare`, `Binarymap.mem`, and
`parse_term_dtype.ST_compare`. The `mergesort` replay also
exposes `Term.dest_term`. This points to repeated comparison,
tree lookup, and construction in the proof body. Poly/ML's proof
profile exposes some collector work and a large unnamed
generated region, so the exact comparison costs there remain
open. See `hol/proof-only-verified`.
HOL4's pinned MLton tools
provide tool targets such as Holmake. The report's theory and
kernel results use the saved HOL states for Rune and Poly/ML.
A direct MLton kernel or theory comparison needs an equivalent
kernel harness and proof corpus.

The isolated kernel profiles include an otherwise identical setup
control. Rune's control weights image relocation, loader and
runtime operations, and JIT compilation. The large `EVAL FACT 150`
case puts about 71% of Rune's profile in generated code. The
largest named Rune operation is `Type.ty_sub`. Poly/ML's native
diagnostic profiler exposes `equations.reduce_cst`,
`Term.dest_eq_ty`, `Term.ty_of`, `Type.ty_sub`, and collection
in this same workload. The `FACT 60` case has less proof work
to amortize startup. The two operations expose both type and term
traversal and repeated construction of intermediate proof objects.

For `PROVE_TAC`, `SIMP_CONV`, and `DECIDE`, compare the named
profiles for term destructors, substitutions, and equality before
specializing. Rune's `PROVE_TAC` profile has a visible setup share
even in the repeated diagnostic fixture. Poly/ML's named profile
includes `Term.dest_abs`, term and type equality, and
`Type.tymatch`. Derive savings from a checked proof operation
or a representation-aware equality worker while preserving the
kernel's observable theorem construction. For `type_of`, the
Rune profile exposes `Type.dom_rng` and the Poly/ML profiler
exposes `Term.ty_of`. This favors known-call and representation
work on the term traversal.

The multiplication kernel isolates another cost. Rune's
`Arbnum-mul-x200000` profile has about 30% in the integer runtime,
including GMP import. The named native profile provides its own
arithmetic path. Validate a compact-limb candidate in this kernel
as well as on the numeric benchmarks. The original multiplication
ratio is 9.27, which requires removing roughly 89% of Rune's time
at the same host time to meet the target. A small call-path saving
alone would leave a substantial gap.

The kernel acceptance gate should retain the same logical proofs,
the two untouched theorem rebuilds, and an independent startup or
image-restore measure. The saved-state format and the precise
marking and relocation contracts constrain any optimization to
image startup or generated proof code.


## Optimization order

Prioritize the changes below in this order. Each delivery should retain the
stock program and equivalent outputs, measure before and after on the
same core, and compare the resulting Rune ratio separately to each
host. The original timing metric remains the acceptance metric. Use
machine instructions, bytes, code size, startup, and resident memory
to explain the result and to catch a cost moved elsewhere.

| Priority | Change | First acceptance cases |
| --- | --- | --- |
| 1 | Reuse the existing list fusion and remove measured text and stream temporaries. Extend `Simplify` with narrowly checked producer–consumer rewrites. Add bulk or scalar Basis operations where the runtime boundary dominates. | `string_ops`, `list_ops`, the two `wc` variants, `output1`, and IO error and callback-trace cases |
| 2 | Add checked loop idiom recognition, bounds facts, and direct numeric representations in Low. Feed those facts into register allocation and tier-2 emitters. | `word_bits`, `array_sieve`, `matrix-multiply`, `flat-array`, and overflow, rounding and index checks |
| 3 | Add allocation-site measurements for the larger list, closure, and symbolic workloads. Specialize known calls, scalarize short-lived aggregates, then tune the collector for the objects that still survive. | `DLXSimulator`, `constraints-strict`, `ansi-strict`, `fib`, `tak`, and the latency and GC stress workloads |
| 4 | Reduce fixed-width boxing and exact-integer interop costs. Use size and escape facts to select a representation or a limb path. | `psdes-random`, `mandelbrot-rat`, `intinf_fact`, HOL4 Arbnum, and signed or multi-limb edges |
| 5 | Cut compiler startup and repeated compiler-table work. Preserve the existing deterministic build and unit semantics. | `hello`, `compile-sigs`, `runedoc-page`, bootstrap, the module fixtures, pinned MLton whole and units builds, and HOL4 |

The combined string source probe took 332M cycles on Rune in the
paired run, down from 565M. The same session measured 196M cycles
for MLton and 240M for Poly/ML. It closed roughly 63% and 72% of the
respective gaps. The rest needs separate evidence, such as token
scanning, copying, and remaining temporary allocation. Workload
rewrites in these receipts demonstrate individual changes on fixed
inputs. Turning one into a production optimization still requires its
stated invariants, tests, and measurements across other workloads.

Where a profile mainly shows anonymous generated code, identify the
hot block and its executed predecessors before committing to a
compiler transformation. The most useful next capture may be an
execution count by instruction or a narrower source probe. Leave
the unexplained part visible until that capture supports a proposal.


## Workload coverage

<!-- begin-workload-tables -->

### Small programs and compiler controls

First values are the original cycle ratios. The symbol is the largest named sample in the host profile. The signed differences are estimates in user-mode cycles from the corresponding replay. JIT-tier and `xc1` rows in the performance report are controls on the same workload.

| Workload | Rune hotspot | MLton | Poly/ML |
| --- | --- | --- | --- |
| `array_sieve` | `jit2:strike` 74% | 1.82× · 2.51× instructions · `loop_16` 19%<br>small samples (8/6) | 1.47× · 2.57× instructions · `area1` 83%<br>small samples (8/6) |
| `fib` | `jit2:fib` 100% | 1.14× · 1.54× instructions · `stackCheck_5` 27%<br>small samples (9/7) | 1.24× · 1.75× instructions · `area1` 84%<br>small samples (9/6) |
| `hash_mod` | `jit2:go` 85% | 1.18× · 2.40× instructions · `L_316` 35%<br>small samples (22/18) | 0.40× · 1.65× instructions · `area1` 99%<br>small samples (22/53) |
| `intinf_fact` | `x64_byte` 100% | 6.38× · 15.93× instructions · `__gmpn_mul_1` 26%<br>small samples (1/8) | 1.18× · 2.66× instructions · `do_lookup_x` 100%<br>small samples (1/1) |
| `list_ops` | `jit2:go` 13% | 1.92× · 2.34× instructions · `L_416` 19%<br>small samples (16/15) | 1.20× · 1.56× instructions · `area1` 57%<br>small samples (16/19) |
| `real_nbody` | `jit2:step` 96% | 0.97× · 3.20× instructions · `L_501` 97%<br>small samples (17/18) | 0.54× · 0.54× instructions · `area1` 74%<br>small samples (17/42) |
| `string_ops` | `promote` 14% | 2.93× · 3.71× instructions · `GC_sequenceAllocate` 19%<br>small samples (32/23) | 2.38× · 3.52× instructions · `area1` 78%<br>small samples (32/16) |
| `tak` | `jit2:tak` 100% | 1.20× · 1.38× instructions · `L_618` 32%<br>small samples (4/6) | 1.04× · 1.31× instructions · `area1` 74%<br>small samples (4/4) |
| `word_bits` | `jit2:bits` 75% | 2.99× · 3.25× instructions · `L_386` 34%<br>small samples (8/3) | 1.94× · 1.81× instructions · `area1` 83%<br>small samples (8/6) |
| `compile-sigs` | `loop_fast` 12% | 3.88× · 5.53× instructions · `forwardObjptr` 8%<br>small samples (75/24) | 4.62× · 8.13× instructions · `area1` 80%<br>small samples (75/23) |
| `runedoc-page` | `loop_fast` 7% | 1.55× · 1.83× instructions · `forwardObjptr` 15%<br>≈+79.7M in JIT compilation | 2.56× · 4.25× instructions · `area1` 88%<br>small samples (38/21) |
| `bootstrap` | `mark_full` 9% | 1.42× · 2.60× instructions · `forwardObjptr` 16%<br>≈+3.46G in collector | 1.32× · 2.05× instructions · `area1` 67%<br>≈+2.38G in Rune runtime |
| `compile-hello` | `validate_program_from` 13% | see startup case · 6.22× instructions · `L_10409` 28%<br>small samples (27/4) | see startup case · 9.12× instructions · `area1` 81%<br>small samples (27/5) |

### MLton’s benchmark programs

Each replay uses its host’s original Basis and the pinned workload size. `model-elimination` proved the 14 goals on each host. Its timed search can take different paths.

| Workload | Rune hotspot | MLton | Poly/ML |
| --- | --- | --- | --- |
| `even-odd` | `jit2:even'` 51% | 0.54× · 1.12× instructions · `L_186` 33%<br>≈−3.71G in generated code | 1.97× · 2.02× instructions · `area1` 100%<br>≈+4.82G in generated code |
| `fib` | `jit2:fib` 100% | 1.07× · 1.52× instructions · `L_183` 26%<br>≈−643.6M in allocation or stack checks | 1.28× · 1.81× instructions · `area1` 100%<br>≈+1.47G in generated code |
| `tailfib` | `jit2:fib'` 92% | 1.08× · 2.01× instructions · `L_94` 71%<br>≈+1.11G in generated code | 1.62× · 1.84× instructions · `area1` 100%<br>≈+2.57G in generated code |
| `tak` | `jit2:tak` 100% | 1.21× · 1.81× instructions · `L_185` 17%<br>≈+2.59G in generated code | 1.34× · 1.84× instructions · `area1` 100%<br>≈+2.36G in generated code |
| `tyan` | `jit2:P.plus` 30% | 1.30× · 1.97× instructions · `foreachObjptrInObject` 13%<br>≈+268.3M in generated code | 1.39× · 1.88× instructions · `area1` 77%<br>≈+265.2M in generated code |
| `logic` | `jit2:Unify.unifys` 16% | 1.59× · 1.62× instructions · `foreachObjptrInObject` 11%<br>≈+267.2M in generated code | 1.22× · 1.50× instructions · `area1` 84%<br>≈−76.6M in collector |
| `fft` | `jit2:Main.loop_i0` 80% | 1.80× · 4.05× instructions · `L_60` 43%<br>≈+10.46G in generated code | 0.16× · 0.13× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 43%<br>≈−139.97G in collector |
| `tsp` | `jit2:TSP.distance` 43% | 1.86× · 5.72× instructions · `L_726` 43%<br>≈+10.65G in generated code | 0.36× · 0.43× instructions · `area1` 29%<br>≈−31.14G in collector |
| `model-elimination` | `jit2:Subst1.g` 11% | 1.93× · 2.32× instructions · `forwardObjptr` 7%<br>≈+39.15G in generated code | 1.35× · 2.66× instructions · `area1` 91%<br>≈+21.75G in generated code |
| `simple` | `jit2:fn` 25% | 2.21× · 2.76× instructions · `L_2503` 17%<br>≈+298.1M in generated code | 0.70× · 0.82× instructions · `area1` 37%<br>≈−360.3M in collector |
| `knuth-bendix` | `jit2:Main.try_find_rec` 32% | 2.31× · 3.13× instructions · `L_1310` 18%<br>small samples (13/6) | 0.80× · 0.62× instructions · `area1` 89%<br>small samples (13/17) |
| `nucleic` | `jit2:Nucleic.tfo_combine` 27% | 2.32× · 3.12× instructions · `L_509` 27%<br>≈+640.9M in generated code | 0.99× · 1.47× instructions · `area1` 78%<br>≈+63.2M in generated code |
| `boyer` | `jit2:Terms.unify1` 25% | 2.38× · 3.06× instructions · `forwardObjptr` 23%<br>≈+348.0M in generated code | 0.89× · 1.21× instructions · `area1` 48%<br>≈−370.7M in collector |
| `mpuz` | `jit2:String.loop` 46% | 2.63× · 3.06× instructions · `L_331` 18%<br>≈+2.54G in generated code | 1.40× · 1.82× instructions · `area1` 100%<br>≈+1.51G in generated code |
| `imp-for` | `jit2:loop` 99% | 2.98× · 4.28× instructions · `L_28` 31%<br>small samples (56/17) | 1.30× · 2.29× instructions · `area1` 99%<br>≈+112.3M in generated code |
| `count-graphs` | `jit2:loop` 34% | 3.00× · 3.46× instructions · `L_659` 6%<br>≈+22.69G in generated code | 1.43× · 1.96× instructions · `area1` 94%<br>≈+11.04G in generated code |
| `mandelbrot` | `jit2:Main.loop2` 54% | 3.16× · 4.43× instructions · `L_32` 65%<br>≈+43.88G in generated code | 1.41× · 2.50× instructions · `area1` 93%<br>≈+19.15G in generated code |
| `barnes-hut` | `jit2:Grav.walksub` 47% | 3.23× · 4.20× instructions · `L_893` 33%<br>small samples (36/13) | 0.88× · 0.99× instructions · `area1` 78%<br>≈−58.6M in Poly/ML runtime |
| `string-concat` | `jit2:RuneStringVectorFn.go` 94% | 3.28× · 3.29× instructions · `L_109` 72%<br>small samples (52/16) | 2.10× · 2.14× instructions · `area1` 98%<br>≈+353.6M in generated code |
| `DLXSimulator` | `promote` 20% | 3.38× · 4.70× instructions · `L_1747` 11%<br>≈+26.93G in collector | 3.40× · 5.50× instructions · `area1` 79%<br>≈+28.56G in collector |
| `merge` | `minor_frames_kept` 16% | 3.80× · 7.04× instructions · `L_228` 21%<br>≈+388.4M in frames | 1.27× · 1.17× instructions · `X86TaskData::ScanStackAddress(ScanAddress*, stackIt…` 25%<br>≈+388.4M in frames |
| `vector64-concat` | `jit2:Vector.go` 72% | 4.01× · 6.55× instructions · `__memmove_avx_unaligned_erms` 37%<br>≈+4.88G in generated code | unavailable · Int64 |
| `peek` | `jit2:Plist.loop` 62% | 4.08× · 3.72× instructions · `L_188` 13%<br>≈+3.56G in generated code | unavailable · Int64 |
| `tailmerge` | `mark_obj` 23% | 4.17× · 6.78× instructions · `L_130` 29%<br>small samples (73/24) | 0.59× · 0.53× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 21%<br>≈−567.8M in collector |
| `wc-input1` | `jit2:Main.loop` 13% | 4.51× · 5.04× instructions · `forwardObjptr` 18%<br>≈+256.2M in frames | 0.31× · 0.25× instructions · `X86TaskData::ScanStackAddress(ScanAddress*, stackIt…` 24%<br>≈−2.31G in collector |
| `wc-scanStream` | `jit2:RuneStreamIOFn.input1` 17% | 4.94× · 4.79× instructions · `foreachObjptrInObject` 29%<br>≈+200.8M in frames | 0.36× · 0.24× instructions · `X86TaskData::ScanStackAddress(ScanAddress*, stackIt…` 27%<br>≈−2.38G in collector |
| `zebra` | `jit2:fn` 44% | 5.88× · 9.13× instructions · `L_1793` 2%<br>≈+10.97G in generated code | 4.18× · 7.26× instructions · `area1` 94%<br>≈+9.92G in generated code |
| `psdes-random` | `jit2:fn` 75% | 6.16× · 8.17× instructions · `L_90` 26%<br>≈+123.40G in generated code | 8.83× · 12.75× instructions · `area1` 95%<br>≈+131.04G in generated code |
| `matrix-multiply` | `jit2:RuneArray2.sub` 64% | 7.46× · 9.45× instructions · `L_56` 71%<br>≈+14.29G in generated code | 0.63× · 2.12× instructions · `area1` 85%<br>≈−2.44G in collector |
| `vector32-concat` | `jit2:Vector.go` 80% | 7.66× · 8.92× instructions · `L_99` 40%<br>≈+7.65G in generated code | 2.33× · 2.84× instructions · `area1` 93%<br>≈+4.26G in generated code |
| `life` | `values_equal` 46% | 8.62× · 15.75× instructions · `L_328` 17%<br>≈+20.84G in primitive work | 9.63× · 18.57× instructions · `area1` 97%<br>≈+20.84G in primitive work |
| `pidigits` | `jit_fill_from` 100% | 9.59× · 16.37× instructions · `IntInf_binop` 25%<br>small samples (1/91) | 2.53× · 4.09× instructions · `_dl_lookup_symbol_x` 53%<br>small samples (1/2) |
| `vector-rev` | `jit2:Vector.go` 50% | 11.03× · 9.16× instructions · `L_38` 31%<br>≈+15.24G in generated code | 4.60× · 5.91× instructions · `area1` 74%<br>≈+13.49G in generated code |
| `raytrace` | `read_code_and_tables` 100% | 11.84× · 35.48× instructions · `cfree@GLIBC_2.2.5` 100%<br>small samples (1/1) | 1.68× · 2.65× instructions · `_dl_relocate_object` 50%<br>small samples (1/2) |
| `md5` | `jit2:MD5.XX` 47% | 11.90× · 14.18× instructions · `L_747` 63%<br>≈+159.27G in generated code | 4.63× · 6.78× instructions · `area1` 99%<br>≈+137.08G in generated code |
| `checksum` | `jit2:RunePackWordFn.go` 79% | 12.23× · 10.95× instructions · `L_26` 73%<br>small samples (43/4) | 3.54× · 3.16× instructions · `area1` 95%<br>small samples (43/15) |
| `smith-normal-form` | `big_of_value` 74% | 16.25× · 24.80× instructions · `L_307` 52%<br>small samples (23/2) | 7.13× · 13.63× instructions · `area1` 25%<br>small samples (23/4) |
| `output1` | `jit2:Main.loop` 28% | 24.68× · 22.71× instructions · `L_220` 40%<br>≈+122.42G in user-space I/O | 3.32× · 5.18× instructions · `area1` 99%<br>≈+122.40G in user-space I/O |

### Catalogue

Each baseline ratio divides the median of three fresh processes by the corresponding host median. A rounded zero is below the report’s timing precision. The optional setup column estimates wall time outside the benchmark’s timed body on short fresh replays, in Rune, MLton, Poly/ML order. The raw counters also give instruction counts independently of the wall clock.

| Workload | Rune hotspot | MLton | Poly/ML | Setup outside body | Investigation lead |
| --- | --- | --- | --- | --- | --- |
| `tak` | `jit2:BenchTak.tak` 99% | 1.17× · 1.82× instructions · `L_1397` 22%<br>small samples (31/21) | 1.17× · 1.83× instructions · `area1` 95%<br>small samples (31/16) | — | [Calls and checked loops](#calls-and-checked-loops) |
| `kittmergesort` | `jit2:BenchKittSort.merge` 21% | 0.75× · 2.47× instructions · `L_1426` 11%<br>generated code / generated code in batched profiles | 0.75× · 1.84× instructions · `area1` 66%<br>generated code / generated code in batched profiles | 4.83 / 4.57 / 8.12 ms | Measured parity on this input |
| `primes-lazy` | `jit2:BenchPrimes.filter` 43% | 0.03/0.01 s · 3.01× instructions · `L_1429` 24%<br>generated code / generated code in batched profiles | 1.00× · 0.89× instructions · `area1` 86%<br>generated code / generated code in batched profiles | 4.12 / 2.56 / 7.54 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `primes-strict` | `jit2:List.filter` 86% | 0.96× · 0.95× instructions · `L_383` 27%<br>≈+445.0M in generated code | 0.96× · 1.68× instructions · `area1` 98%<br>≈+126.3M in generated code | — | Measured parity on this input |
| `bdd` | `jit2:Benchmark.conjunction` 21% | 2.00× · 3.22× instructions · `L_1483` 12%<br>generated code / generated code in batched profiles | 1.33× · 2.44× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 4.17 / 3.64 / 5.60 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `fib` | `jit2:BenchFib.fib` 99% | 0.01/0.00 s · 1.57× instructions · `L_1392` 27%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.75× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 11.65 / 2.95 / 34.77 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `tailfib` | `jit2:Benchmark.fib'` 67% | 0.00/0.00 s · 4.31× instructions · `L_366` 100%<br>small samples (3/2) | 0.00/0.00 s · 1.13× instructions · `area1` 64%<br>small samples (3/3) | 3.76 / 2.33 / 6.50 ms | [Startup](#compiler-throughput-and-startup) |
| `even-odd` | `jit2:Benchmark.even` 55% | 0.00/0.00 s · 1.33× instructions · `L_1408` 35%<br>generated code / generated code in batched profiles | 0.00/0.00 s · 1.80× instructions · `area1` 95%<br>small samples (32/16) | 3.04 / 3.10 / 9.45 ms | [Startup](#compiler-throughput-and-startup) |
| `merge` | `jit2:Benchmark.merge` 27% | 0.01/0.00 s · 2.34× instructions · `L_406` 16%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 3.85× instructions · `area1` 74%<br>generated code / generated code in batched profiles | 4.42 / 3.61 / 7.77 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `tailmerge` | `jit2:Benchmark.loop` 30% | 0.01/0.00 s · 2.30× instructions · `L_428` 13%<br>collector / generated code in batched profiles | 0.01/0.01 s · 2.21× instructions · `area1` 64%<br>collector / generated code in batched profiles | 4.29 / 3.40 / 7.15 ms | [Allocation and GC](#allocation-and-collection) |
| `imp-for` | `jit2:Benchmark.loop` 86% | 0.00/0.00 s · 5.36× instructions · `loop_13` 50%<br>small samples (6/2) | 0.00/0.00 s · 1.44× instructions · `area1` 72%<br>small samples (6/7) | 7.95 / 4.24 / 8.25 ms | [Startup](#compiler-throughput-and-startup) |
| `vector-rev` | `jit2:Vector.go` 38% | 0.00/0.00 s · 4.49× instructions · `L_347` 32%<br>small samples (53/12) | 0.00/0.00 s · 3.05× instructions · `area1` 93%<br>small samples (53/14) | 4.78 / 3.16 / 9.62 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `vector32-concat` | `jit2:Vector.go` 92% | 0.00/0.00 s · 7.70× instructions · `L_376` 35%<br>small samples (19/3) | 0.00/0.00 s · 1.78× instructions · `area1` 74%<br>small samples (19/8) | 8.53 / 4.52 / 8.74 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `vector64-concat` | `jit2:Vector.go` 61% | 0.00/0.00 s · 6.25× instructions · `loop_17` 29%<br>small samples (17/4) | unavailable · Int64 | — | [Calls and checked loops](#calls-and-checked-loops) |
| `string-concat` | `jit2:RuneStringVectorFn.go` 80% | 0.00/0.00 s · 3.94× instructions · `L_376` 45%<br>small samples (16/4) | 0.00/0.00 s · 1.70× instructions · `area1` 89%<br>small samples (16/9) | 8.93 / 2.10 / 7.74 ms | [Text and streams](#text-and-streams) |
| `wc-input1` | `jit2:RuneStreamIOFn.input1` 34% | 0.04/0.00 s · 10.79× instructions · `L_541` 27%<br>generated code / generated code in batched profiles | 0.67× · 1.18× instructions · `area1` 89%<br>generated code / generated code in batched profiles | 7.28 / 6.42 / 12.04 ms | [Text and streams](#text-and-streams) |
| `wc-scanStream` | `jit2:RuneStreamIOFn.input1` 39% | 0.04/0.00 s · 7.50× instructions · `L_420` 20%<br>generated code / generated code in batched profiles | 1.33× · 2.58× instructions · `area1` 89%<br>generated code / generated code in batched profiles | 14.76 / 4.21 / 18.62 ms | [Text and streams](#text-and-streams) |
| `checksum` | `jit2:RunePackWordFn.go` 73% | 0.09/0.00 s · 15.59× instructions · `L_372` 23%<br>generated code / generated code in batched profiles | 2.25× · 4.02× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 4.31 / 3.27 / 14.32 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `boyer` | `promote` 22% | 1.40× · 2.49× instructions · `forwardObjptr` 20%<br>small samples (35/20) | 0.54× · 1.65× instructions · `area1` 45%<br>≈−48.7M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `nucleic` | `jit2:Nucleic.tfo_combine` 26% | 2.25× · 3.39× instructions · `L_1714` 14%<br>generated code / generated code in batched profiles | 1.00× · 1.93× instructions · `area1` 74%<br>generated code / generated code in batched profiles | 9.10 / 2.54 / 10.13 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `life` | `jit2:LifeKernel.existsp` 43% | 5.00× · 10.36× instructions · `L_598` 19%<br>generated code / generated code in batched profiles | 5.00× · 11.75× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 5.08 / 2.45 / 6.09 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `matrix-multiply` | `jit2:RuneArray2.sub` 53% | 0.00/0.00 s · 9.01× instructions · `L_391` 47%<br>small samples (67/11) | 0.00/0.00 s · 3.24× instructions · `area1` 72%<br>generated code / generated code in batched profiles | 3.90 / 2.45 / 8.23 ms | [Startup](#compiler-throughput-and-startup) |
| `md5` | `jit2:MD5.XX` 45% | 0.01/0.00 s · 17.55× instructions · `L_1449` 34%<br>small samples (91/10) | 0.01/0.00 s · 6.32× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 7.62 / 3.00 / 9.25 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `fft` | `jit2:FFTKernel.loop_i0` 62% | 0.01/0.00 s · 3.87× instructions · `__sin_fma` 20%<br>generated code / generated code in batched profiles | 0.01/0.02 s · 1.34× instructions · `area1` 70%<br>generated code / generated code in batched profiles | 4.06 / 2.70 / 7.10 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `binary-trees` | `jit2:Benchmark.make` 43% | 0.01/0.00 s · 1.55× instructions · `L_1378` 12%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 2.29× instructions · `area1` 91%<br>generated code / generated code in batched profiles | 3.17 / 2.27 / 7.49 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `flat-array` | `jit2:fn` 51% | 0.22/0.01 s · 14.48× instructions · `L_370` 55%<br>generated code / generated code in batched profiles | 0.32× · 0.41× instructions · `area1` 41%<br>generated code / collector in batched profiles | 9.01 / 3.00 / 12.45 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `peek` | `jit2:Plist.loop` 62% | 4.04× · 3.72× instructions · `L_470` 19%<br>≈+3.65G in generated code | unavailable · Int64 | — | [Calls and checked loops](#calls-and-checked-loops) |
| `psdes-random` | `jit2:fn` 76% | 0.07/0.01 s · 7.16× instructions · `L_375` 37%<br>generated code / generated code in batched profiles | 1.75× · 4.22× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 4.25 / 2.76 / 7.26 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `mandelbrot` | `jit2:Benchmark.loop3` 61% | 0.03/0.01 s · 3.35× instructions · `L_179` 59%<br>generated code / generated code in batched profiles | 1.00× · 1.89× instructions · `area1` 95%<br>generated code / generated code in batched profiles | 4.29 / 2.79 / 9.19 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `pidigits` | `big_of_value` 30% | 0.01/0.00 s · 25.85× instructions · `__gmpz_add` 27%<br>small samples (201/14) | 0.01/0.00 s · 11.18× instructions · `SaveVec::push(PolyWord)` 13%<br>Rune runtime / Poly/ML runtime in batched profiles | 4.52 / 2.20 / 6.76 ms | [Integer representations](#integer-ranges-and-representations) |
| `logic` | `jit2:Unify.oc` 17% | 1.39× · 1.43× instructions · `foreachObjptrInObject` 11%<br>≈+3.98G in generated code | 1.16× · 2.22× instructions · `area1` 94%<br>≈+2.51G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `zebra` | `jit2:fn` 49% | 7.25× · 9.19× instructions · `L_2626` 4%<br>generated code / generated code in batched profiles | 2.90× · 7.51× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 3.74 / 3.26 / 8.21 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `count-graphs` | `jit2:loop` 30% | 0.02/0.00 s · 3.88× instructions · `L_1566` 13%<br>generated code / generated code in batched profiles | 1.00× · 2.15× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 3.68 / 3.11 / 8.67 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `many_refs` | `jit2:Array.go` 98% | 4.67× · 4.41× instructions · `L_465` 38%<br>generated code / generated code in batched profiles | 1.17× · 3.06× instructions · `area1` 88%<br>generated code / generated code in batched profiles | 4.52 / 2.25 / 7.68 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `tensor` | `jit2:BenchInput.closeReal` 47% | 7.00× · 6.79× instructions · `L_463` 21%<br>small samples (140/24) | 0.98× · 1.69× instructions · `area1` 59%<br>≈+1.11G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `zern` | `jit2:BenchInput.closeReal` 34% | 0.01/0.00 s · 3.94× instructions · `__sin_fma` 28%<br>generated code / generated code in batched profiles | 0.01/0.03 s · 0.49× instructions · `area1` 36%<br>generated code / collector in batched profiles | 4.06 / 2.38 / 7.13 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `smith-normal-form` | `jit2:fn` 19% | 0.00/0.00 s · 14.93× instructions · `IntInf_binop` 50%<br>small samples (11/2) | 0.00/0.00 s · 4.00× instructions · `area1` 61%<br>small samples (11/5) | 5.56 / 2.43 / 8.08 ms | [Startup](#compiler-throughput-and-startup) |
| `ratio-regions` | `jit2:loop` 33% | 0.03/0.01 s · 3.58× instructions · `L_3259` 10%<br>generated code / generated code in batched profiles | 0.03/0.01 s · 2.24× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 4.49 / 2.40 / 6.11 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `mpuz` | `jit2:String.loop` 42% | 2.67× · 2.96× instructions · `L_1521` 14%<br>≈+21.84G in generated code | 1.36× · 1.82× instructions · `area1` 100%<br>≈+14.08G in generated code | — | [Text and streams](#text-and-streams) |
| `DLXSimulator` | `promote` 19% | 3.07× · 4.69× instructions · `L_2653` 12%<br>≈+51.73G in collector | 3.25× · 6.25× instructions · `area1` 87%<br>≈+55.56G in collector | — | [Allocation and GC](#allocation-and-collection) |
| `knuth-bendix` | `jit2:KBKernel.try_find_rec` 29% | 2.06× · 3.26× instructions · `L_3420` 9%<br>≈+1.04G in generated code | 0.71× · 1.63× instructions · `area1` 66%<br>≈−460.4M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `tyan` | `jit2:P.plus` 20% | 1.33× · 1.96× instructions · `L_2790` 10%<br>≈+567.5M in generated code | 1.17× · 2.12× instructions · `area1` 87%<br>≈+592.3M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `lexgen` | `jit2:String.<=` 15% | 1.86× · 2.26× instructions · `L_3921` 18%<br>≈+119.4M in generated code | 0.72× · 1.52× instructions · `area1` 84%<br>≈−304.7M in generated code | — | [Text and streams](#text-and-streams) |
| `mlyacc` | `jit2:ListOrdSet.union` 11% | 1.80× · 3.18× instructions · `foreachObjptrInObject` 9%<br>generated code / generated code in batched profiles | 2.25× · 2.79× instructions · `area1` 76%<br>generated code / generated code in batched profiles | 9.43 / 2.33 / 8.18 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `hamlet` | `jit2:RuneStreamIOFn.outputWith` 9% | 0.04/0.00 s · 19.37× instructions · `L_28663` 11%<br>generated code / generated code in batched profiles | 0.04/0.00 s · 15.63× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 16.13 / 3.31 / 10.16 ms | [Text and streams](#text-and-streams) |
| `kitfib35` | `jit2:Benchmark.fib` 100% | 0.93× · 1.52× instructions · `L_1391` 26%<br>≈+171.9M in generated code | 1.18× · 1.76× instructions · `area1` 99%<br>≈+264.0M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `fib0` | `jit2:Benchmark.fib` 98% | 0.01/0.01 s · 1.57× instructions · `L_1393` 25%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.75× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 4.48 / 3.05 / 8.93 ms | [Integer representations](#integer-ranges-and-representations) |
| `kitreynolds2` | `jit2:fn` 84% | 2.14× · 3.83× instructions · `L_1410` 24%<br>small samples (47/23) | 1.00× · 2.02× instructions · `area1` 99%<br>≈−61.5M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `kitreynolds3` | `jit2:Benchmark.member` 82% | 4.00× · 3.65× instructions · `L_1406` 58%<br>generated code / generated code in batched profiles | 1.00× · 1.67× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 4.64 / 3.10 / 9.42 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitloop2` | `jit2:Benchmark.loop` 89% | 0.00/0.00 s · 2.77× instructions · `L_1686` 60%<br>small samples (16/8) | 0.00/0.00 s · 1.28× instructions · `area1` 91%<br>small samples (16/21) | 5.15 / 2.17 / 9.21 ms | [Startup](#compiler-throughput-and-startup) |
| `kitdangle` | `jit2:Benchmark.mklist` 78% | 0.02/0.00 s · 9.13× instructions · `L_373` 35%<br>small samples (242/22) | 0.01× · 0.01× instructions · `area1` 19%<br>generated code / collector in batched profiles | 4.19 / 3.17 / 14.35 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitdangle3` | `jit2:Benchmark.mklist` 82% | 0.05/0.00 s · 9.24× instructions · `loop_13` 43%<br>generated code / generated code in batched profiles | 0.02× · 0.02× instructions · `area1` 35%<br>generated code / collector in batched profiles | 4.45 / 2.99 / 17.37 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `msort` | `jit2:Benchmark.merge` 20% | 1.00× · 2.32× instructions · `foreachObjptrInObject` 13%<br>collector / generated code in batched profiles | 0.75× · 1.34× instructions · `area1` 46%<br>collector / collector in batched profiles | 7.44 / 4.45 / 15.91 ms | Measured parity on this input |
| `kittmergesort_tp` | `jit2:BenchKittSort.merge` 21% | 1.23× · 2.73× instructions · `L_1542` 8%<br>≈+517.0M in collector | 1.11× · 1.63× instructions · `area1` 57%<br>≈+267.1M in Rune runtime | — | [Calls and checked loops](#calls-and-checked-loops) |
| `barnes-hut` | `jit2:Grav.walksub` 34% | 2.50× · 4.04× instructions · `L_2543` 31%<br>≈+606.4M in generated code | 0.71× · 1.55× instructions · `area1` 80%<br>≈−87.5M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `tsp` | `jit2:TSP.distance` 28% | 0.01/0.00 s · 4.79× instructions · `L_2456` 39%<br>generated code / generated code in batched profiles | 0.01/0.00 s · 3.68× instructions · `area1` 62%<br>generated code / generated code in batched profiles | 5.70 / 3.42 / 9.26 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `fannkuch` | `jit2:FannkuchKernel.lp` 49% | 0.00/0.00 s · 4.34× instructions · `L_401` 30%<br>small samples (12/7) | 0.00/0.00 s · 1.60× instructions · `area1` 92%<br>small samples (12/19) | 4.10 / 3.06 / 6.85 ms | [Startup](#compiler-throughput-and-startup) |
| `f-arith` | `jit2:PiKernel.loop` 99% | 0.01/0.01 s · 3.50× instructions · `L_351` 99%<br>generated code / generated code in batched profiles | 0.01/0.02 s · 0.86× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 4.06 / 2.98 / 9.33 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `stream-sieve` | `jit2:Sieve.sift` 84% | 1.50× · 1.25× instructions · `L_1911` 30%<br>generated code / generated code in batched profiles | 1.00× · 2.33× instructions · `area1` 95%<br>generated code / generated code in batched profiles | 5.65 / 2.82 / 10.42 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `simple` | `jit2:map` 10% | 2.00× · 2.44× instructions · `gdtoa__strtodg` 18%<br>≈+351.9M in generated code | 0.90× · 1.04× instructions · `area1` 54%<br>≈−416.1M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `twenty-four` | `jit2:TwentyFour.eval` 59% | 1.78× · 1.74× instructions · `L_1498` 21%<br>≈+222.6M in generated code | 2.29× · 2.21× instructions · `area1` 93%<br>≈+300.7M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `nbody` | `jit2:NBodyKernel.lp2` 72% | 1.45× · 3.04× instructions · `L_526` 59%<br>≈+1.38G in generated code | 0.33× · 1.24× instructions · `area1` 95%<br>≈−3.21G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `output1` | `jit2:RuneStreamIOFn.outputWith` 19% | 0.07/0.00 s · 20.84× instructions · `L_738` 28%<br>user-space I/O / generated code in batched profiles | 3.50× · 5.56× instructions · `area1` 98%<br>user-space I/O / generated code in batched profiles | 4.57 / 3.09 / 7.31 ms | [Text and streams](#text-and-streams) |
| `ray` | `jit2:Ray.wave` 22% | 3.60× · 7.98× instructions · `L_2882` 27%<br>small samples (47/10) | 1.50× · 3.05× instructions · `area1` 81%<br>≈+116.1M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `raytrace` | `jit2:Matrix.vmul` 32% | 2.98× · 3.43× instructions · `L_5239` 15%<br>≈+3.50G in generated code | 0.99× · 1.55× instructions · `area1` 91%<br>≈+628.1M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `vliw` | `jit2:Stringmap.loop` 13% | 2.25× · 2.82× instructions · `GC_sequenceAllocate` 15%<br>generated code / generated code in batched profiles | 1.29× · 3.68× instructions · `area1` 83%<br>generated code / generated code in batched profiles | 8.69 / 3.28 / 10.88 ms | [Text and streams](#text-and-streams) |
| `fxp` | `jit2:Decode.doit` 19% | 1.56× · 2.04× instructions · `L_5032` 12%<br>small samples (44/22) | 0.44× · 0.73× instructions · `X86TaskData::ScanStackAddress(ScanAddress*, stackIt…` 39%<br>≈−557.0M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `model-elimination` | `jit2:Subst1.g` 13% | 1.89× · 2.47× instructions · `forwardObjptr` 6%<br>≈+26.08G in generated code | 1.12× · 2.61× instructions · `area1` 92%<br>≈+13.97G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `sat` | `jit2:fn` 78% | 3.00× · 3.45× instructions · `L_1559` 25%<br>small samples (47/17) | 1.12× · 2.66× instructions · `area1` 93%<br>≈+121.7M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `boyer-smlnj` | `jit2:Terms.unify1` 20% | 2.07× · 2.68× instructions · `forwardObjptr` 24%<br>≈+777.6M in generated code | 0.91× · 1.81× instructions · `area1` 71%<br>≈−660.2M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `logic-smlnj` | `jit2:Data.move_horiz` 14% | 1.25× · 1.44× instructions · `foreachObjptrInObject` 12%<br>≈+16.23G in generated code | 1.19× · 2.26× instructions · `area1` 88%<br>≈+10.05G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `life-smlnj` | `jit2:LifeMain.existsp` 51% | 3.65× · 10.05× instructions · `L_641` 16%<br>≈+6.62G in generated code | 5.03× · 11.93× instructions · `area1` 98%<br>≈+7.15G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `minimax` | `jit2:List.go` 23% | 2.11× · 3.67× instructions · `forwardObjptr` 14%<br>≈+1.97G in generated code | 0.29× · 0.31× instructions · `MTGCProcessMarkPointers::TestForScan(PolyWord*)` 19%<br>≈−14.60G in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `iter-pidigits` | `__gmpz_import` 23% | 0.00/0.00 s · 21.30× instructions · `__gmpn_invert_limb` 26%<br>small samples (95/4) | 0.00/0.00 s · 7.20× instructions · `make_canonical(TaskData*, SaveVecEntry*, int)` 21%<br>small samples (95/11) | 5.16 / 2.89 / 8.27 ms | [Integer representations](#integer-ranges-and-representations) |
| `mazefun` | `jit2:Maze.neighboringCavities` 26% | 2.00× · 2.03× instructions · `loop_75` 10%<br>small samples (39/21) | 1.25× · 2.22× instructions · `area1` 94%<br>small samples (39/23) | — | [Calls and checked loops](#calls-and-checked-loops) |
| `queens-lazy` | `jit2:BenchQueens.safe` 43% | 0.01/0.00 s · 2.98× instructions · `L_2135` 29%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 2.61× instructions · `area1` 73%<br>generated code / generated code in batched profiles | 5.02 / 3.15 / 8.86 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `queens-strict` | `jit2:BenchQueens.safe` 47% | 1.00× · 1.61× instructions · `foreachObjptrInObject` 13%<br>generated code / generated code in batched profiles | 1.00× · 1.62× instructions · `area1` 65%<br>generated code / generated code in batched profiles | 5.12 / 3.38 / 10.17 ms | Measured parity on this input |
| `nqueens` | `jit2:Benchmark.ok` 63% | 0.01/0.00 s · 2.56× instructions · `L_2046` 23%<br>generated code / generated code in batched profiles | 0.01/0.00 s · 2.25× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 4.70 / 2.50 / 8.20 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `rec_seq_ack` | `jit2:Benchmark.ack` 100% | 0.01/0.01 s · 1.55× instructions · `L_1397` 34%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 2.07× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 4.51 / 3.77 / 9.31 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `klife_eq` | `values_equal` 51% | 7.50× · 15.49× instructions · `L_647` 29%<br>primitive work / generated code in batched profiles | 5.00× · 13.01× instructions · `area1` 98%<br>primitive work / generated code in batched profiles | 5.54 / 2.73 / 9.28 ms | Map remaining hot code |
| `kitlife35u_smlnj` | `jit2:LifeKernel.exists'` 64% | 1.33× · 2.69× instructions · `L_632` 10%<br>generated code / generated code in batched profiles | 1.33× · 3.34× instructions · `area1` 98%<br>generated code / generated code in batched profiles | 5.96 / 4.07 / 9.80 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitqsort_no_basislib` | `jit2:SortKernel.partition` 45% | 0.01/0.01 s · 2.30× instructions · `L_1406` 18%<br>generated code / generated code in batched profiles | 0.01/0.02 s · 1.10× instructions · `area1` 47%<br>generated code / generated code in batched profiles | 4.68 / 3.31 / 9.05 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `tailfib-mlkit` | `jit2:Kernel.fib'` 77% | 0.00/0.00 s · 4.44× instructions · `L_362` 34%<br>small samples (4/3) | 0.00/0.00 s · 1.12× instructions · `area1` 65%<br>small samples (4/3) | 4.37 / 2.37 / 7.39 ms | [Startup](#compiler-throughput-and-startup) |
| `tak-mlkit` | `jit2:BenchTak.tak` 100% | 0.02/0.01 s · 1.84× instructions · `L_1402` 27%<br>generated code / generated code in batched profiles | 0.02/0.01 s · 1.81× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 4.26 / 2.88 / 8.46 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `matrix-multiply-mlkit` | `jit2:RuneArray2.sub` 51% | 0.04/0.00 s · 9.07× instructions · `L_411` 43%<br>generated code / generated code in batched profiles | 1.33× · 3.52× instructions · `area1` 73%<br>generated code / generated code in batched profiles | 4.90 / 2.76 / 8.32 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `vector-rev-mlkit` | `jit2:Vector.go` 46% | 0.01/0.00 s · 7.53× instructions · `L_347` 23%<br>small samples (109/13) | 0.01/0.00 s · 5.53× instructions · `area1` 81%<br>generated code / generated code in batched profiles | 5.09 / 3.13 / 8.78 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `vector-rev_smlnj` | `jit2:Vector.go` 49% | 0.00/0.00 s · 4.47× instructions · `L_391` 18%<br>small samples (63/13) | 0.00/0.00 s · 3.11× instructions · `area1` 96%<br>small samples (63/20) | 4.53 / 3.38 / 6.63 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `vector-concat` | `jit2:Benchmark.scan` 51% | 0.00/0.00 s · 4.05× instructions · `L_374` 69%<br>small samples (12/3) | 0.00/0.00 s · 1.42× instructions · `area1` 67%<br>small samples (12/9) | 3.25 / 2.59 / 7.27 ms | [Startup](#compiler-throughput-and-startup) |
| `vector-concat_smlnj` | `jit2:Benchmark.scan` 84% | 0.00/0.00 s · 2.06× instructions · `L_374` 36%<br>small samples (61/22) | 0.00/0.00 s · 1.42× instructions · `area1` 98%<br>generated code / generated code in batched profiles | 5.09 / 3.18 / 7.97 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `peek-mlkit` | `jit2:Plist.loop` 57% | 0.00/0.00 s · 11.05× instructions · `L_366` 37%<br>small samples (59/9) | 0.00/0.01 s · 2.20× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 5.01 / 3.63 / 16.53 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `wc-input1-mlkit` | `jit2:RuneStreamIOFn.input1` 29% | 0.03/0.01 s · 8.21× instructions · `L_207` 15%<br>small samples (154/22) | 0.75× · 1.38× instructions · `area1` 89%<br>generated code / generated code in batched profiles | 6.31 / 3.16 / 8.63 ms | [Text and streams](#text-and-streams) |
| `wc-scanStream-mlkit` | `jit2:RuneStreamIOFn.input1` 37% | 0.03/0.00 s · 6.24× instructions · `L_355` 14%<br>generated code / generated code in batched profiles | 1.50× · 3.17× instructions · `area1` 87%<br>generated code / generated code in batched profiles | 5.14 / 3.16 / 8.42 ms | [Text and streams](#text-and-streams) |
| `psdes-random-mlkit` | `jit2:fn` 74% | 0.01/0.00 s · 7.62× instructions · `L_378` 59%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 3.81× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 4.89 / 2.91 / 9.60 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `safe-for-space` | `jit2:Kernel.big` 64% | 0.06/0.01 s · 4.46× instructions · `L_1409` 42%<br>generated code / generated code in batched profiles | 1.00× · 2.68× instructions · `area1` 89%<br>generated code / generated code in batched profiles | 5.90 / 4.35 / 12.36 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `pidigits-smlnj` | `big_of_value` 23% | 0.01/0.00 s · 21.75× instructions · `IntInf_binop` 40%<br>small samples (140/7) | 0.01/0.00 s · 9.11× instructions · `SaveVec::push(PolyWord)` 14%<br>small samples (140/22) | 5.90 / 3.46 / 10.14 ms | [Integer representations](#integer-ranges-and-representations) |
| `fft-smlnj` | `jit2:Kernel.loop_i0` 50% | 0.00/0.00 s · 10.41× instructions · `__sin_fma` 47%<br>small samples (12/4) | 0.00/0.00 s · 3.01× instructions · `area1` 56%<br>small samples (12/14) | 5.43 / 4.85 / 9.54 ms | [Startup](#compiler-throughput-and-startup) |
| `nucleic-smlnj` | `jit2:Nucleic.tfo_combine` 36% | 2.00× · 3.39× instructions · `L_1567` 19%<br>generated code / generated code in batched profiles | 0.73× · 1.70× instructions · `area1` 86%<br>generated code / generated code in batched profiles | 7.40 / 3.63 / 14.09 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `count-graphs-smlnj` | `jit2:Kernel.loop` 24% | 0.00/0.00 s · 7.86× instructions · `L_1696` 14%<br>small samples (25/9) | 0.00/0.00 s · 2.97× instructions · `area1` 88%<br>small samples (25/16) | 9.65 / 6.40 / 9.65 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `matrix-multiply-ramp` | `jit2:RuneArray2.sub` 46% | 0.00/0.00 s · 5.77× instructions · `loop_70` 20%<br>small samples (58/24) | 0.00/0.00 s · 3.85× instructions · `area1` 84%<br>generated code / generated code in batched profiles | 5.70 / 3.45 / 12.32 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitreynolds2_no_basislib` | `jit2:fn` 87% | 0.01/0.00 s · 3.86× instructions · `L_1326` 17%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.91× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 7.72 / 4.40 / 8.89 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitreynolds3_no_basislib` | `validate_program_from` 52% | 0.00/0.00 s · 5.61× instructions · `L_1319` 100%<br>small samples (2/1) | 0.00/0.00 s · 1.07× instructions · `do_lookup_x` 35%<br>small samples (2/3) | 6.70 / 2.83 / 8.96 ms | [Startup](#compiler-throughput-and-startup) |
| `kittmergesort_no_basislib` | `jit2:BenchKittSort.merge` 28% | 0.01/0.01 s · 1.85× instructions · `forwardObjptr` 14%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.85× instructions · `area1` 69%<br>generated code / generated code in batched profiles | 6.31 / 5.18 / 10.35 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `hanoi` | `jit2:BenchOutput.loop` 32% | 0.00/0.00 s · 4.16× instructions · `L_2223` 17%<br>small samples (10/7) | 0.00/0.00 s · 1.70× instructions · `area1` 90%<br>small samples (10/10) | 4.49 / 3.32 / 8.88 ms | [Startup](#compiler-throughput-and-startup) |
| `fib-mlkit` | `loop_fast` 67% | 0.00/0.00 s · 6.57× instructions · `L_394` 100%<br>small samples (3/1) | 0.00/0.00 s · 1.26× instructions · `_dl_lookup_symbol_x` 53%<br>small samples (3/2) | 4.89 / 3.03 / 7.31 ms | [Startup](#compiler-throughput-and-startup) |
| `mandelbrot-smlnj` | `jit2:Kernel.loop3` 98% | 1.00× · 2.56× instructions · `L_382` 74%<br>generated code / generated code in batched profiles | 0.40× · 1.25× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 4.71 / 3.35 / 11.32 ms | Measured parity on this input |
| `mandelbrot-rat` | `jit2:Kernel.gcd` 15% | 3.21× · 4.45× instructions · `L_1823` 39%<br>≈+1.06G in integer runtime | 5.17× · 12.86× instructions · `area1` 99%<br>≈+1.21G in integer runtime | — | [Integer representations](#integer-ranges-and-representations) |
| `kitmandelbrot` | `jit2:Kernel.loop3` 69% | 0.00/0.00 s · 4.33× instructions · `L_382` 75%<br>small samples (16/8) | 0.00/0.00 s · 1.57× instructions · `area1` 93%<br>small samples (16/29) | 9.39 / 2.42 / 9.62 ms | [Startup](#compiler-throughput-and-startup) |
| `FuhMishra` | `jit2:Kernel.isin` 19% | 0.03/0.01 s · 3.61× instructions · `L_2723` 6%<br>generated code / generated code in batched profiles | 1.50× · 4.05× instructions · `area1` 86%<br>generated code / generated code in batched profiles | 5.13 / 2.91 / 8.67 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `black-scholes` | `jit2:Real.scan` 14% | 2.00× · 2.56× instructions · `gdtoa__strtodg` 22%<br>generated code / generated code in batched profiles | 1.33× · 2.32× instructions · `area1` 50%<br>generated code / generated code in batched profiles | 5.04 / 3.20 / 11.45 ms | [Text and streams](#text-and-streams) |
| `professor2` | `jit2:Kernel.findSol` 31% | 1.67× · 1.62× instructions · `GC_sequenceAllocate` 17%<br>generated code / generated code in batched profiles | 1.00× · 2.81× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 4.77 / 2.49 / 9.70 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `professor2_tp` | `jit2:Kernel.findSol` 28% | 2.00× · 1.62× instructions · `GC_sequenceAllocate` 19%<br>generated code / generated code in batched profiles | 1.00× · 2.81× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 5.20 / 3.15 / 14.90 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `professor_game` | `jit2:Kernel.findSol` 27% | 2.50× · 1.62× instructions · `GC_sequenceAllocate` 26%<br>generated code / generated code in batched profiles | 1.25× · 2.81× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 5.45 / 3.58 / 10.94 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `professor_game-mlkit` | `jit2:Kernel.findSol` 30% | 2.50× · 1.62× instructions · `GC_sequenceAllocate` 19%<br>generated code / generated code in batched profiles | 1.25× · 2.81× instructions · `area1` 95%<br>generated code / generated code in batched profiles | 4.77 / 3.56 / 10.60 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `professor_game_debug` | `x64_byte` 67% | 0.00/0.00 s · 7.08× instructions · `L_1597` 100%<br>small samples (3/1) | 0.00/0.00 s · 1.31× instructions · `do_lookup_x` 52%<br>small samples (3/2) | 5.52 / 3.20 / 8.26 ms | [Startup](#compiler-throughput-and-startup) |
| `kkb_eq` | `jit2:Kernel.match_rec` 41% | 2.60× · 3.75× instructions · `L_2465` 25%<br>small samples (41/21) | 1.08× · 2.99× instructions · `area1` 94%<br>≈+26.6M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `kitkbjul9_smlnj` | `jit2:Kernel.match_rec` 35% | 2.00× · 3.23× instructions · `L_1731` 14%<br>small samples (35/20) | 1.00× · 2.63× instructions · `area1` 93%<br>≈−46.8M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `kkb36c_smlnj` | `jit2:Kernel.match_rec` 31% | 2.20× · 3.24× instructions · `L_2385` 15%<br>small samples (31/18) | 0.92× · 2.62× instructions · `area1` 88%<br>≈+22.4M in C library | — | [Calls and checked loops](#calls-and-checked-loops) |
| `ratio-regions-mlkit` | `jit2:Kernel.loop` 38% | 0.04/0.00 s · 3.59× instructions · `L_2010` 5%<br>generated code / generated code in batched profiles | 0.04/0.01 s · 2.24× instructions · `area1` 94%<br>generated code / generated code in batched profiles | 5.64 / 3.08 / 8.08 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `ratio-regions_tp` | `jit2:Kernel.loop` 38% | 4.00× · 3.28× instructions · `L_2047` 9%<br>generated code / generated code in batched profiles | 1.33× · 2.07× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 5.20 / 3.39 / 8.63 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `ratio-regions-smlnj` | `jit2:Kernel.loop` 32% | 0.03/0.01 s · 3.63× instructions · `L_2054` 10%<br>generated code / generated code in batched profiles | 0.03/0.01 s · 2.26× instructions · `area1` 96%<br>generated code / generated code in batched profiles | 5.64 / 3.20 / 8.94 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `count-graphs-mlkit` | `jit2:Kernel.loop` 28% | 0.01/0.00 s · 4.71× instructions · `L_2025` 7%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 2.44× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 4.22 / 3.39 / 7.81 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `mpuz-mlkit` | `jit2:Kernel.List.loop` 43% | 2.85× · 2.96× instructions · `L_1566` 19%<br>≈+2.09G in generated code | 1.38× · 1.82× instructions · `area1` 100%<br>≈+1.07G in generated code | — | [Text and streams](#text-and-streams) |
| `knuth-bendix-smlnj` | `jit2:Kernel.match_rec` 27% | 2.00× · 3.23× instructions · `L_2300` 15%<br>small samples (36/23) | 0.60× · 1.38× instructions · `area1` 61%<br>≈−108.4M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `tyan-smlnj` | `jit2:M.mul` 18% | 1.20× · 1.94× instructions · `forwardObjptr` 11%<br>≈+604.3M in generated code | 1.35× · 1.94× instructions · `area1` 85%<br>≈+547.9M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `tyan-mlkit` | `jit2:M.mul` 20% | 1.30× · 1.95× instructions · `forwardObjptr` 9%<br>≈+316.0M in generated code | 1.08× · 1.91× instructions · `area1` 89%<br>≈+225.1M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `smith-normal-form-mlkit` | `jit2:Kernel.swapRowLoop` 21% | 0.00/0.00 s · 14.96× instructions · `L_577` 50%<br>small samples (18/2) | 0.00/0.00 s · 4.01× instructions · `area1` 51%<br>small samples (18/4) | 5.98 / 2.82 / 7.16 ms | [Startup](#compiler-throughput-and-startup) |
| `smith-nf` | `jit2:Matrix.loop` 15% | 0.00/0.00 s · 14.99× instructions · `L_497` 48%<br>small samples (17/2) | 0.00/0.00 s · 4.01× instructions · `area1` 60%<br>small samples (17/5) | 6.95 / 3.07 / 7.83 ms | [Startup](#compiler-throughput-and-startup) |
| `lexgen-smlnj` | `jit2:LexGen.Dict.search` 21% | 1.33× · 2.30× instructions · `L_4069` 12%<br>small samples (33/23) | 0.57× · 1.63× instructions · `area1` 76%<br>≈−118.3M in generated code | — | [Text and streams](#text-and-streams) |
| `mlyacc-smlnj` | `jit2:ListOrdSet.union` 14% | 2.33× · 3.59× instructions · `foreachObjptrInObject` 16%<br>generated code / generated code in batched profiles | 2.33× · 3.19× instructions · `area1` 77%<br>generated code / generated code in batched profiles | 12.63 / 3.38 / 13.14 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitsimple` | `jit2:Kernel.sub'` 36% | 0.01/0.00 s · 5.50× instructions · `L_3562` 23%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 4.87× instructions · `area1` 78%<br>generated code / generated code in batched profiles | 6.55 / 5.13 / 9.21 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitsimple_tp` | `jit2:Kernel.sub'` 37% | 0.03/0.01 s · 4.03× instructions · `L_3562` 25%<br>generated code / generated code in batched profiles | 0.03/0.01 s · 3.81× instructions · `area1` 86%<br>generated code / generated code in batched profiles | 6.86 / 3.25 / 9.93 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitsimple_no_basislib` | `jit2:Kernel.sub'` 37% | 0.01/0.00 s · 5.50× instructions · `L_3118` 22%<br>generated code / generated code in batched profiles | 0.01/0.00 s · 4.86× instructions · `area1` 83%<br>generated code / generated code in batched profiles | 8.50 / 4.57 / 7.53 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `simple-smlnj` | `jit2:fn` 13% | 0.04/0.01 s · 3.35× instructions · `gdtoa__strtodg` 8%<br>generated code / generated code in batched profiles | 2.00× · 2.94× instructions · `area1` 67%<br>generated code / generated code in batched profiles | 7.76 / 3.53 / 11.03 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `tsp-smlnj` | `jit2:TSP.distance` 34% | 0.00/0.00 s · 4.50× instructions · `L_2447` 35%<br>generated code / generated code in batched profiles | 0.00/0.00 s · 3.32× instructions · `area1` 58%<br>generated code / generated code in batched profiles | 5.69 / 3.50 / 9.41 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `DLXSimulator-mlkit` | `vm_frames_from` 13% | 2.00× · 5.03× instructions · `L_409` 12%<br>collector / generated code in batched profiles | 3.33× · 4.78× instructions · `area1` 59%<br>collector / generated code in batched profiles | 8.21 / 6.16 / 10.35 ms | [Allocation and GC](#allocation-and-collection) |
| `aobench` | `jit2:fn` 20% | 0.47× · 1.00× instructions · `loop_78` 31%<br>generated code / generated code in batched profiles | 1.75× · 2.49× instructions · `area1` 52%<br>generated code / generated code in batched profiles | 6.02 / 3.29 / 10.96 ms | [Integer representations](#integer-ranges-and-representations) |
| `id-ray` | `jit2:Ray.sphmap` 94% | 3.33× · 5.05× instructions · `L_2022` 76%<br>≈+3.39G in generated code | unavailable · input needed during loading | — | [Calls and checked loops](#calls-and-checked-loops) |
| `plclub-ray` | `jit2:Matrix.vmul` 22% | 0.06/0.01 s · 5.13× instructions · `L_5346` 16%<br>generated code / generated code in batched profiles | 0.86× · 1.10× instructions · `area1` 71%<br>generated code / generated code in batched profiles | 8.94 / 3.71 / 12.11 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `mc-ray` | `jit2:Sphere.hitTest` 63% | 2.18× · 3.56× instructions · `L_2246` 62%<br>≈+652.2M in generated code | 0.83× · 1.75× instructions · `area1` 96%<br>≈−103.0M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `ray-smlnj` | `jit2:Ray.dotProd` 22% | 0.02/0.00 s · 9.32× instructions · `L_3012` 44%<br>generated code / generated code in batched profiles | 1.00× · 3.24× instructions · `area1` 94%<br>generated code / generated code in batched profiles | 6.63 / 3.27 / 10.47 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `kitmolgard` | `jit2:Kernel.CPN'transition20_0` 22% | 0.02/0.01 s · 4.33× instructions · `L_2841` 26%<br>generated code / generated code in batched profiles | 1.00× · 2.72× instructions · `area1` 93%<br>generated code / generated code in batched profiles | 8.65 / 3.51 / 9.96 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `vliw-smlnj` | `jit2:Stringmap.loop` 15% | 1.80× · 2.91× instructions · `L_4917` 27%<br>≈+272.7M in generated code | 0.95× · 2.30× instructions · `area1` 89%<br>≈+140.3M in allocation | — | [Text and streams](#text-and-streams) |
| `rfib` | `jit2:Benchmark.nfib` 99% | 0.01/0.00 s · 3.58× instructions · `L_1382` 32%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 2.47× instructions · `area1` 94%<br>generated code / generated code in batched profiles | 5.58 / 3.38 / 11.10 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `tak-nofib-strict` | `jit2:BenchTak.tak` 55% | 0.00/0.00 s · 3.33× instructions · `L_1307` 59%<br>small samples (7/5) | 0.00/0.00 s · 1.20× instructions · `area1` 75%<br>small samples (7/4) | 5.15 / 3.18 / 12.59 ms | [Startup](#compiler-throughput-and-startup) |
| `tak-nofib-lazy` | `jit2:Benchmark.tak` 49% | 0.00/0.00 s · 2.01× instructions · `L_1562` 17%<br>generated code / generated code in batched profiles | 0.00/0.01 s · 2.34× instructions · `area1` 85%<br>generated code / generated code in batched profiles | 7.32 / 3.98 / 9.50 ms | [Memoized delays](#memoized-delays) |
| `exp3_8-lazy` | `promote` 24% | 3.10× · 6.22× instructions · `L_1321` 29%<br>≈+1.23G in collector | 0.31× · 0.43× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 49%<br>≈−5.13G in collector | — | [Memoized delays](#memoized-delays) |
| `exp3_8-strict` | `jit2:Kernel.add` 71% | 1.20× · 1.44× instructions · `L_1328` 34%<br>small samples (25/22) | 1.00× · 2.11× instructions · `area1` 81%<br>small samples (25/21) | — | [Calls and checked loops](#calls-and-checked-loops) |
| `digits-of-e1-lazy` | `jit2:fn` 61% | 1.25× · 1.10× instructions · `L_843` 11%<br>generated code / generated code in batched profiles | 1.00× · 2.22× instructions · `area1` 88%<br>generated code / generated code in batched profiles | 7.19 / 3.31 / 10.02 ms | [Memoized delays](#memoized-delays) |
| `digits-of-e2-lazy` | `jit2:fn` 28% | 1.83× · 1.99× instructions · `L_723` 15%<br>≈+242.5M in collector | 1.00× · 1.68× instructions · `area1` 56%<br>≈+184.9M in Rune runtime | — | [Memoized delays](#memoized-delays) |
| `latency-ring` | `__memmove_avx_unaligned_erms` 30% | 0.85× · 0.24× instructions · `L_531` 65%<br>≈−1.48G in generated code | 0.19× · 0.09× instructions · `area1` 55%<br>≈−3.70G in generated code | — | Measured parity on this input |
| `latency-map` | `jit2:Benchmark.balance` 19% | 0.96× · 0.86× instructions · `L_504` 34%<br>≈+803.3M in copying or scanning | 0.38× · 0.37× instructions · `area1` 53%<br>≈−3.14G in generated code | — | Measured parity on this input |
| `latency-static-map` | `jit2:Benchmark.find` 66% | 0.75× · 1.47× instructions · `L_664` 32%<br>≈−613.2M in generated code | 0.79× · 0.57× instructions · `area1` 77%<br>≈−551.1M in generated code | — | Measured parity on this input |
| `kahan` | `jit2:Real.fromLargeInt` 10% | 2.42× · 3.04× instructions · `gdtoa__strtodg` 15%<br>≈+2.74G in Rune runtime | 8.83× · 11.82× instructions · `area1` 27%<br>≈+2.74G in Rune runtime | — | [Integer representations](#integer-ranges-and-representations) |
| `x2n1-lazy` | `jit2:BenchX2N1.g` 40% | 0.00/0.00 s · 5.03× instructions · `L_516` 30%<br>generated code / generated code in batched profiles | 0.00/0.02 s · 1.30× instructions · `area1` 66%<br>generated code / generated code in batched profiles | 5.78 / 3.68 / 11.55 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `x2n1-strict` | `jit2:BenchX2N1.g` 39% | 0.00/0.00 s · 4.28× instructions · `L_1472` 25%<br>generated code / generated code in batched profiles | 0.00/0.01 s · 1.22× instructions · `area1` 67%<br>generated code / generated code in batched profiles | 5.60 / 3.19 / 10.43 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `integrate-lazy` | `jit2:BenchIntegrate.integrate1D` 22% | 1.33× · 4.03× instructions · `L_1927` 31%<br>small samples (24/15) | 0.50× · 0.65× instructions · `area1` 34%<br>small samples (24/35) | 6.38 / 4.67 / 10.68 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `integrate-strict` | `jit2:BenchIntegrate.integrate1D` 48% | 0.02/0.01 s · 4.39× instructions · `L_2539` 25%<br>generated code / generated code in batched profiles | 0.67× · 1.15× instructions · `area1` 68%<br>generated code / generated code in batched profiles | 5.49 / 3.97 / 8.27 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `bernouilli-lazy` | `big_of_value` 15% | 0.02/0.00 s · 6.65× instructions · `__gmpz_mul` 14%<br>Rune runtime / generated code in batched profiles | 0.02/0.01 s · 5.98× instructions · `area1` 32%<br>Rune runtime / Poly/ML runtime in batched profiles | 5.28 / 3.83 / 9.23 ms | [Integer representations](#integer-ranges-and-representations) |
| `bernouilli-strict` | `__gmpz_import` 13% | 0.02/0.00 s · 11.49× instructions · `IntInf_binop` 13%<br>Rune runtime / generated code in batched profiles | 0.02/0.00 s · 6.24× instructions · `PolyMultiplyArbitrary` 14%<br>Rune runtime / Poly/ML runtime in batched profiles | 5.54 / 3.87 / 9.04 ms | [Integer representations](#integer-ranges-and-representations) |
| `wheel-sieve1-lazy` | `jit2:Benchmark.notDivBy` 30% | 0.00/0.00 s · 1.51× instructions · `L_1674` 15%<br>generated code / generated code in batched profiles | 0.00/0.00 s · 2.54× instructions · `area1` 75%<br>generated code / generated code in batched profiles | 5.99 / 3.48 / 8.47 ms | [Memoized delays](#memoized-delays) |
| `wheel-sieve2-lazy` | `scan_object.part.0` 27% | 0.01/0.01 s · 2.51× instructions · `forwardObjptr` 28%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 3.09× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 50%<br>generated code / collector in batched profiles | 6.03 / 3.20 / 10.06 ms | [Memoized delays](#memoized-delays) |
| `gen_regexps-lazy` | `jit2:BenchLazy.force` 21% | 2.64× · 2.90× instructions · `foreachObjptrInObject` 15%<br>≈+459.0M in generated code | 0.43× · 0.69× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 37%<br>≈−1.80G in collector | — | [Memoized delays](#memoized-delays) |
| `gen_regexps-strict` | `mark_obj` 22% | 0.59× · 2.11× instructions · `forwardObjptr` 31%<br>≈+50.2M in collector | 0.56× · 0.74× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 17%<br>≈−228.5M in collector | — | Measured parity on this input |
| `paraffins-lazy` | `jit2:BenchLazy.force` 31% | 0.00/0.00 s · 6.59× instructions · `forwardObjptr` 19%<br>small samples (18/16) | 0.00/0.00 s · 3.90× instructions · `area1` 90%<br>small samples (18/16) | 5.13 / 2.97 / 8.09 ms | [Memoized delays](#memoized-delays) |
| `paraffins-strict` | `jit2:@` 24% | 0.00/0.00 s · 7.87× instructions · `L_2085` 19%<br>small samples (10/5) | 0.00/0.00 s · 2.26× instructions · `area1` 54%<br>small samples (10/6) | 5.09 / 2.92 / 7.46 ms | [Startup](#compiler-throughput-and-startup) |
| `mutstore1` | `scan_object.part.0` 15% | 0.00/0.00 s · 1.92× instructions · `L_428` 36%<br>small samples (47/12) | 0.00/0.00 s · 2.86× instructions · `area1` 49%<br>generated code / generated code in batched profiles | 4.99 / 3.92 / 8.82 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `mutstore2` | `promote` 16% | 0.00/0.00 s · 1.96× instructions · `L_427` 23%<br>small samples (38/24) | 0.00/0.00 s · 2.60× instructions · `area1` 65%<br>small samples (38/18) | 4.79 / 2.41 / 7.66 ms | [Startup](#compiler-throughput-and-startup) |
| `gc_bench` | `jit2:Benchmark.walk` 30% | 0.01/0.01 s · 2.17× instructions · `L_1473` 14%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.74× instructions · `area1` 47%<br>generated code / collector in batched profiles | 4.41 / 3.45 / 10.02 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `pidigits-nofib-lazy` | `big_of_value` 28% | 0.02/0.00 s · 33.16× instructions · `__gmpn_mul_1` 39%<br>small samples (377/21) | 0.02/0.00 s · 17.99× instructions · `__gmpn_mul_basecase` 36%<br>Rune runtime / integer runtime in batched profiles | 5.29 / 3.24 / 8.55 ms | [Integer representations](#integer-ranges-and-representations) |
| `pidigits-nofib-strict` | `big_of_value` 33% | 0.02/0.00 s · 34.52× instructions · `__gmpn_mul_1` 20%<br>small samples (429/18) | 0.02/0.00 s · 18.12× instructions · `__gmpn_mul_basecase` 32%<br>Rune runtime / integer runtime in batched profiles | 4.92 / 3.27 / 8.09 ms | [Integer representations](#integer-ranges-and-representations) |
| `hash` | `scan_object.part.0` 20% | 0.00/0.00 s · 2.74× instructions · `L_520` 15%<br>small samples (41/23) | 0.00/0.00 s · 2.20× instructions · `area1` 74%<br>generated code / generated code in batched profiles | 5.02 / 3.23 / 12.86 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `lcss-lazy` | `scan_object.part.0` 19% | 1.67× · 3.72× instructions · `forwardObjptr` 22%<br>collector / generated code in batched profiles | 0.50× · 0.63× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 32%<br>collector / collector in batched profiles | 5.47 / 3.42 / 11.15 ms | [Memoized delays](#memoized-delays) |
| `lcss-strict` | `jit2:Benchmark.update` 73% | 0.00/0.00 s · 2.14× instructions · `L_1811` 24%<br>generated code / generated code in batched profiles | 0.00/0.00 s · 1.77× instructions · `area1` 86%<br>generated code / generated code in batched profiles | 5.44 / 3.47 / 8.87 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `gcd-lazy` | `jit2:BenchLazy.force` 29% | 0.01/0.00 s · 2.20× instructions · `L_1860` 11%<br>generated code / generated code in batched profiles | 0.01/0.03 s · 1.62× instructions · `area1` 52%<br>generated code / generated code in batched profiles | 5.94 / 2.83 / 10.44 ms | [Memoized delays](#memoized-delays) |
| `gcd-strict` | `jit2:BenchExtendedGCD.loop` 48% | 0.00/0.00 s · 1.36× instructions · `L_2359` 12%<br>generated code / generated code in batched profiles | 0.00/0.01 s · 1.86× instructions · `area1` 77%<br>generated code / generated code in batched profiles | 5.92 / 6.04 / 9.28 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `treejoin-lazy` | `jit2:BenchLazy.force` 17% | 0.02/0.01 s · 3.53× instructions · `L_1804` 16%<br>collector / generated code in batched profiles | 0.40× · 1.70× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 34%<br>collector / collector in batched profiles | 6.36 / 3.91 / 10.83 ms | [Memoized delays](#memoized-delays) |
| `treejoin-strict` | `jit2:BenchTreeJoinFn.insert` 31% | 0.00/0.00 s · 2.51× instructions · `L_1567` 13%<br>generated code / generated code in batched profiles | 0.00/0.00 s · 2.10× instructions · `area1` 82%<br>generated code / generated code in batched profiles | 4.69 / 3.05 / 9.68 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `spellcheck-lazy` | `jit2:BenchWordSet.member` 21% | 0.02/0.01 s · 2.04× instructions · `L_541` 12%<br>generated code / generated code in batched profiles | 0.50× · 2.77× instructions · `area1` 60%<br>generated code / generated code in batched profiles | 7.42 / 4.25 / 10.70 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `spellcheck-strict` | `jit2:BenchWordSet.member` 33% | 1.50× · 1.68× instructions · `L_299` 15%<br>generated code / generated code in batched profiles | 1.00× · 2.47× instructions · `area1` 83%<br>generated code / generated code in batched profiles | 7.11 / 3.90 / 12.45 ms | [Text and streams](#text-and-streams) |
| `cse` | `p_string_concat` 11% | 0.00/0.00 s · 3.99× instructions · `GC_sequenceCopy` 24%<br>small samples (28/14) | 0.00/0.00 s · 2.81× instructions · `area1` 87%<br>small samples (28/22) | 5.34 / 3.23 / 9.90 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `power` | `jit2:BenchLazy.force` 17% | 0.00/0.00 s · 3.26× instructions · `L_1992` 16%<br>small samples (26/21) | 0.00/0.00 s · 3.14× instructions · `area1` 45%<br>generated code / collector in batched profiles | 5.08 / 2.91 / 8.85 ms | [Memoized delays](#memoized-delays) |
| `power-nofib` | `jit2:fn` 23% | 1.24× · 1.68× instructions · `forwardObjptr` 10%<br>≈+172.6M in generated code | 0.94× · 1.37× instructions · `area1` 70%<br>≈+149.6M in generated code | — | [Memoized delays](#memoized-delays) |
| `n-body` | `jit2:Benchmark.pairs` 82% | 0.01/0.00 s · 5.49× instructions · `L_626` 66%<br>generated code / generated code in batched profiles | 0.01/0.03 s · 1.16× instructions · `area1` 86%<br>generated code / generated code in batched profiles | 6.73 / 3.36 / 11.17 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `fasta` | `jit2:List.go` 32% | 1.00× · 2.28× instructions · `L_1641` 16%<br>generated code / generated code in batched profiles | 1.00× · 2.25× instructions · `area1` 92%<br>generated code / generated code in batched profiles | 6.63 / 4.04 / 11.31 ms | Measured parity on this input |
| `reverse-complement` | profile unavailable | unavailable · BenchInput absent | unavailable · BenchInput absent | — | correctness or profile needed |
| `rec_seq_evenodd` | `jit2:Benchmark.odd` 50% | 0.00/0.00 s · 2.08× instructions · `L_1396` 39%<br>small samples (14/18) | 0.00/0.00 s · 1.52× instructions · `area1` 85%<br>small samples (14/7) | 4.76 / 3.90 / 9.81 ms | [Startup](#compiler-throughput-and-startup) |
| `rec_seq_motzkin` | `jit2:Benchmark.sum` 65% | 0.00/0.00 s · 2.18× instructions · `L_1402` 15%<br>generated code / generated code in batched profiles | 0.00/0.00 s · 1.95× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 5.30 / 3.63 / 7.92 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `rec_seq_sudan` | `jit2:Benchmark.sudan` 80% | 0.00/0.00 s · 1.89× instructions · `L_1421` 32%<br>small samples (11/11) | 0.00/0.00 s · 1.28× instructions · `area1` 90%<br>small samples (11/8) | 4.83 / 3.83 / 8.06 ms | [Startup](#compiler-throughput-and-startup) |
| `rec_seq_fib` | `jit2:BenchFib.fib` 99% | 0.01/0.01 s · 1.54× instructions · `L_1397` 27%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.78× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 4.89 / 4.08 / 8.94 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `rec_seq_tak` | `jit2:BenchTak.tak` 99% | 0.01/0.00 s · 1.88× instructions · `loop_63` 32%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.77× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 4.39 / 3.11 / 9.02 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `lazy_primes` | `mark_full` 19% | 1.75× · 4.90× instructions · `forwardObjptr` 52%<br>≈+229.9M in collector | 0.24× · 0.09× instructions · `MTGCProcessMarkPointers::TestForScan(PolyWord*)` 40%<br>≈−5.64G in collector | — | [Allocation and GC](#allocation-and-collection) |
| `lazylist` | `jit2:BenchOcamlLazyList.addLazy` 65% | 1.39× · 1.18× instructions · `L_1435` 23%<br>≈+358.0M in generated code | 1.09× · 1.75× instructions · `area1` 89%<br>≈+140.7M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `sequence_cps` | `jit2:fn` 49% | 0.05/0.00 s · 19.38× instructions · `L_406` 24%<br>generated code / generated code in batched profiles | 0.05/0.00 s · 25.03× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 5.10 / 3.27 / 11.65 ms | [Integer representations](#integer-ranges-and-representations) |
| `compress-lazy` | `jit2:BenchLazy.force` 43% | 1.77× · 2.25× instructions · `L_1935` 18%<br>≈+2.44G in generated code | 0.93× · 1.88× instructions · `area1` 66%<br>≈+1.38G in generated code | — | [Memoized delays](#memoized-delays) |
| `compress-strict` | `jit2:BenchCompressFn.codeString` 81% | 1.21× · 1.60× instructions · `L_1872` 25%<br>≈+265.1M in generated code | 0.53× · 0.67× instructions · `area1` 48%<br>≈−922.0M in collector | — | [Text and streams](#text-and-streams) |
| `lcss-nofib-lazy` | `jit2:BenchLazy.force` 27% | 0.85× · 2.00× instructions · `L_1943` 19%<br>≈+585.3M in generated code | 0.98× · 2.24× instructions · `area1` 73%<br>≈+426.7M in Rune runtime | — | Measured parity on this input |
| `lcss-nofib-strict` | `jit2:Benchmark.update` 60% | 1.33× · 1.51× instructions · `L_1899` 23%<br>small samples (30/20) | 1.14× · 1.66× instructions · `area1` 89%<br>≈+42.2M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `treejoin-nofib-lazy` | `promote` 15% | 4.71× · 7.86× instructions · `L_1873` 17%<br>≈+4.70G in collector | 1.40× · 2.05× instructions · `area1` 34%<br>≈+2.27G in collector | — | [Allocation and GC](#allocation-and-collection) |
| `treejoin-nofib-strict` | `jit2:BenchTreeJoinFn.insert` 32% | 0.81× · 2.18× instructions · `L_1648` 9%<br>≈+165.6M in generated code | 1.08× · 1.74× instructions · `area1` 76%<br>≈+179.7M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `rsa-lazy` | `__gmpz_import` 19% | 10.50× · 9.68× instructions · `__gmpn_sbpi1_div_qr` 20%<br>integer runtime / integer runtime in batched profiles | 5.25× · 7.23× instructions · `__gmpn_mul_basecase` 13%<br>integer runtime / integer runtime in batched profiles | 7.12 / 3.82 / 12.80 ms | [Integer representations](#integer-ranges-and-representations) |
| `rsa-strict` | `__gmpz_import` 18% | 10.50× · 9.74× instructions · `IntInf_binop` 13%<br>integer runtime / integer runtime in batched profiles | 5.25× · 7.25× instructions · `__gmpn_sbpi1_div_qr` 11%<br>integer runtime / integer runtime in batched profiles | 7.06 / 3.43 / 12.30 ms | [Integer representations](#integer-ranges-and-representations) |
| `life-nofib-lazy` | `jit2:BenchLazy.force` 34% | 1.40× · 1.73× instructions · `forwardObjptr` 21%<br>≈+459.5M in generated code | 0.95× · 2.24× instructions · `area1` 82%<br>≈+260.8M in generated code | — | [Memoized delays](#memoized-delays) |
| `life-nofib-strict` | `jit2:BenchCellSequenceFn.zip3` 35% | 1.33× · 1.51× instructions · `L_1809` 13%<br>generated code / generated code in batched profiles | 1.33× · 2.36× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 5.45 / 3.40 / 13.16 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `maillist` | `jit2:TextIO.outstreamOf` 11% | 1.24× · 0.30× instructions · `L_1908` 65%<br>≈+336.2M in C library | 1.02× · 0.19× instructions · `area1` 77%<br>≈−1.12G in generated code | — | [Text and streams](#text-and-streams) |
| `hamming` | `jit_h_prim` 6% | 8.80× · 12.15× instructions · `L_1754` 11%<br>small samples (185/20) | 2.44× · 2.94× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 31%<br>≈+806.6M in Rune runtime | — | [Integer representations](#integer-ranges-and-representations) |
| `scc-lazy` | `_int_free` 21% | 0.00/0.00 s · 7.66× instructions · `L_1851` 100%<br>small samples (6/1) | 0.00/0.00 s · 1.44× instructions · `_dl_lookup_symbol_x` 34%<br>small samples (6/3) | 9.24 / 3.59 / 8.45 ms | [Startup](#compiler-throughput-and-startup) |
| `scc-strict` | `malloc_consolidate` 26% | 0.00/0.00 s · 6.32× instructions · `[unknown]` 100%<br>small samples (4/1) | 0.00/0.00 s · 1.15× instructions · `area1` 52%<br>small samples (4/2) | 5.65 / 3.23 / 8.41 ms | [Startup](#compiler-throughput-and-startup) |
| `awards-lazy` | `jit2:BenchLazy.force` 34% | 1.79× · 2.20× instructions · `L_2119` 6%<br>≈+818.2M in generated code | 0.86× · 2.22× instructions · `area1` 82%<br>≈+407.5M in generated code | — | [Memoized delays](#memoized-delays) |
| `awards-strict` | `jit2:BenchAwardsFn.qpart` 19% | 1.45× · 1.97× instructions · `L_1823` 10%<br>≈+534.0M in generated code | 1.16× · 2.34× instructions · `area1` 93%<br>≈+432.0M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `stack_fold` | `jit2:foldl` 98% | 1.50× · 2.79× instructions · `L_376` 39%<br>≈+1.06G in generated code | 1.55× · 2.24× instructions · `area1` 100%<br>≈+1.08G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `stack_push_pop` | `jit2:BenchOcamlStack.loop` 100% | 2.43× · 2.38× instructions · `L_371` 37%<br>≈+3.30G in generated code | 2.25× · 3.72× instructions · `area1` 98%<br>≈+3.71G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `S` | `promote` 23% | 0.19/0.00 s · 229.80× instructions · `L_345` 51%<br>small samples (3440/13) | 0.18× · 0.16× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 35%<br>collector / collector in batched profiles | 11.62 / 2.85 / 16.66 ms | [Allocation and GC](#allocation-and-collection) |
| `CS` | `jit2:fn` 30% | 0.03/0.00 s · 58.22× instructions · `x_0` 42%<br>small samples (917/17) | 0.60× · 1.96× instructions · `area1` 91%<br>generated code / generated code in batched profiles | 8.39 / 3.07 / 16.25 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `CSD` | `jit2:fn` 26% | 0.03/0.00 s · 50.59× instructions · `L_351` 43%<br>small samples (931/19) | 1.00× · 4.10× instructions · `area1` 92%<br>unresolved / generated code in batched profiles | 4.35 / 3.27 / 11.26 ms | Map remaining hot code |
| `FS` | `jit2:BenchLazy.force` 54% | 1.57× · 1.98× instructions · `L_1345` 19%<br>≈+319.3M in generated code | 1.10× · 2.44× instructions · `area1` 98%<br>≈+149.5M in generated code | — | [Memoized delays](#memoized-delays) |
| `VS` | `minor_frames_bare` 13% | 0.14/0.00 s · 129.17× instructions · `L_352` 56%<br>small samples (2354/18) | 0.04× · 0.03× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 28%<br>generated code / collector in batched profiles | 12.63 / 3.33 / 26.48 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `VSD` | `jit2:BenchStockState.bind` 63% | 0.02/0.00 s · 14.39× instructions · `L_186` 54%<br>generated code / generated code in batched profiles | 0.50× · 1.97× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 4.67 / 2.89 / 11.19 ms | [Memoized delays](#memoized-delays) |
| `VSM` | `jit2:BenchVanMtlState.bind` 61% | 0.02/0.00 s · 13.55× instructions · `L_186` 43%<br>generated code / generated code in batched profiles | 0.33× · 0.94× instructions · `area1` 90%<br>generated code / generated code in batched profiles | 5.65 / 3.70 / 10.37 ms | [Memoized delays](#memoized-delays) |
| `constraints-lazy` | `jit2:BenchLazy.force` 20% | 2.05× · 3.76× instructions · `forwardObjptr` 10%<br>≈+2.86G in collector | 1.25× · 3.11× instructions · `area1` 67%<br>≈+2.30G in Rune runtime | — | [Memoized delays](#memoized-delays) |
| `constraints-strict` | `scan_object.part.0` 17% | 1.71× · 3.92× instructions · `forwardObjptr` 35%<br>≈+49.69G in collector | 1.97× · 3.63× instructions · `area1` 76%<br>≈+81.11G in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `fibheaps-lazy` | `jit2:BenchLazy.force` 29% | 1.63× · 3.69× instructions · `forwardObjptr` 29%<br>≈+1.27G in collector | 0.44× · 0.37× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 30%<br>≈−5.35G in collector | — | [Memoized delays](#memoized-delays) |
| `fibheaps-strict` | `scan_object.part.0` 12% | 1.10× · 2.40× instructions · `L_1698` 18%<br>≈+58.2M in Rune runtime | 0.61× · 0.98× instructions · `area1` 42%<br>≈−225.0M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `fibheaps-nofib-lazy` | `jit2:BenchLazy.force` 30% | 1.67× · 3.13× instructions · `forwardObjptr` 18%<br>≈+16.66G in generated code | 1.35× · 3.31× instructions · `area1` 79%<br>≈+16.84G in collector | — | [Memoized delays](#memoized-delays) |
| `fibheaps-nofib-strict` | `jit2:BenchFibHeapsFn.loop` 12% | 1.23× · 1.83× instructions · `L_1783` 4%<br>≈+954.7M in generated code | 0.87× · 2.22× instructions · `area1` 88%<br>≈+370.7M in Rune runtime | — | [Calls and checked loops](#calls-and-checked-loops) |
| `quicksort` | `jit2:BenchOCamlArrayKernels.loop` 68% | 0.03/0.01 s · 3.64× instructions · `L_1469` 21%<br>generated code / generated code in batched profiles | 1.50× · 2.29× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 10.85 / 3.78 / 10.09 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `mergesort` | `jit2:BenchOCamlArrayKernels.loop` 69% | 2.00× · 3.21× instructions · `L_1468` 9%<br>generated code / generated code in batched profiles | 1.33× · 1.80× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 7.13 / 3.46 / 9.83 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `matrix_multiplication` | `jit2:BenchOCamlArrayKernels.loop` 59% | 0.02/0.01 s · 3.22× instructions · `L_646` 27%<br>generated code / generated code in batched profiles | 1.00× · 1.80× instructions · `area1` 87%<br>generated code / generated code in batched profiles | 4.56 / 3.09 / 9.64 ms | [Text and streams](#text-and-streams) |
| `floyd_warshall` | `jit2:fn` 53% | 0.03/0.01 s · 3.60× instructions · `L_648` 16%<br>generated code / generated code in batched profiles | 1.50× · 2.66× instructions · `area1` 84%<br>generated code / generated code in batched profiles | 11.18 / 3.86 / 9.66 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `ansi-lazy` | `scan_object.part.0` 21% | 6.63× · 7.87× instructions · `L_1827` 18%<br>≈+36.98G in collector | 0.77× · 1.23× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 45%<br>≈+15.65G in Rune runtime | — | [Allocation and GC](#allocation-and-collection) |
| `ansi-strict` | `promote` 11% | 14.25× · 20.01× instructions · `L_1752` 22%<br>≈+18.18G in collector | 8.50× · 13.14× instructions · `area1` 52%<br>≈+17.05G in collector | — | [Allocation and GC](#allocation-and-collection) |
| `grep-lazy` | `jit2:BenchLazy.force` 33% | 1.10× · 1.92× instructions · `forwardObjptr` 13%<br>≈+2.31G in generated code | 1.03× · 2.39× instructions · `area1` 76%<br>≈+3.84G in generated code | — | [Memoized delays](#memoized-delays) |
| `grep-strict` | `mark_obj` 14% | 1.28× · 2.32× instructions · `L_3137` 13%<br>≈+2.04G in collector | 1.35× · 2.39× instructions · `area1` 72%<br>≈+1.93G in collector | — | [Memoized delays](#memoized-delays) |
| `LU_decomposition` | `jit2:BenchInput.closeReal` 21% | 2.20× · 3.13× instructions · `gdtoa__strtodg` 15%<br>≈+413.1M in generated code | 0.71× · 0.98× instructions · `area1` 49%<br>≈−483.3M in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `calendar-lazy` | `jit2:BenchLazy.force` 27% | 2.70× · 2.93× instructions · `forwardObjptr` 8%<br>≈+12.29G in generated code | 1.44× · 3.52× instructions · `area1` 88%<br>≈+9.97G in collector | — | [Memoized delays](#memoized-delays) |
| `calendar-strict` | `jit2:BenchCellSequenceFn.append` 43% | 0.78× · 1.26× instructions · `L_1545` 17%<br>≈−357.8M in collector | 0.98× · 2.09× instructions · `area1` 91%<br>≈+491.5M in generated code | — | Measured parity on this input |
| `banner-lazy` | `jit2:BenchLazy.force` 38% | 1.46× · 1.64× instructions · `forwardObjptr` 12%<br>≈+10.84G in generated code | 0.72× · 1.75× instructions · `area1` 68%<br>≈+5.22G in generated code | — | [Memoized delays](#memoized-delays) |
| `banner-strict` | `jit2:Benchmark.consume` 49% | 1.23× · 1.82× instructions · `L_1805` 22%<br>≈+2.55G in generated code | 0.63× · 0.70× instructions · `area1` 40%<br>≈−3.04G in collector | — | [Calls and checked loops](#calls-and-checked-loops) |
| `sorting-lazy` | `jit2:BenchLazy.force` 24% | 2.24× · 3.70× instructions · `L_2349` 10%<br>≈+11.74G in collector | 1.31× · 2.88× instructions · `area1` 80%<br>≈+9.86G in collector | — | [Memoized delays](#memoized-delays) |
| `sorting-strict` | `jit2:Benchmark.compareRows` 21% | 1.28× · 1.76× instructions · `forwardObjptr` 8%<br>≈+282.1M in generated code | 1.46× · 2.36× instructions · `area1` 87%<br>≈+702.0M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `fish-lazy` | `jit2:BenchLazy.force` 24% | 3.02× · 2.99× instructions · `L_1491` 9%<br>≈+31.67G in generated code | 0.89× · 2.07× instructions · `area1` 58%<br>≈+21.45G in Rune runtime | — | [Memoized delays](#memoized-delays) |
| `fish-strict` | `promote` 13% | 2.69× · 3.72× instructions · `forwardObjptr` 22%<br>≈+7.97G in collector | 1.37× · 3.36× instructions · `area1` 78%<br>≈+8.12G in collector | — | [Allocation and GC](#allocation-and-collection) |
| `spectralnorm2` | `jit2:fn` 79% | 0.04/0.01 s · 3.69× instructions · `L_2370` 22%<br>generated code / generated code in batched profiles | 0.44× · 1.69× instructions · `area1` 91%<br>generated code / generated code in batched profiles | 4.87 / 3.87 / 9.48 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `game_of_life` | `jit2:fn` 83% | 4.50× · 4.40× instructions · `L_404` 7%<br>generated code / generated code in batched profiles | 2.25× · 1.96× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 4.49 / 3.17 / 9.02 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_fact` | `__gmpz_import` 15% | 0.08/0.00 s · 11.06× instructions · `__gmpz_mul` 23%<br>integer runtime / generated code in batched profiles | 4.00× · 5.67× instructions · `area1` 16%<br>integer runtime / Poly/ML runtime in batched profiles | 5.32 / 3.59 / 7.20 ms | [Integer representations](#integer-ranges-and-representations) |
| `zarith_fib` | `jit2:BenchZarithFibFn.fib` 98% | 0.01/0.01 s · 1.23× instructions · `L_1327` 31%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.84× instructions · `area1` 99%<br>generated code / generated code in batched profiles | 4.84 / 3.63 / 9.88 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_fib-int` | `jit2:BenchZarithFibFn.fib` 99% | 0.00/0.00 s · 1.57× instructions · `L_1310` 32%<br>generated code / generated code in batched profiles | 0.00/0.01 s · 1.81× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 5.71 / 7.16 / 11.48 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_fib-natint` | `jit2:BenchZarithFibFn.fib` 99% | 0.01/0.00 s · 2.03× instructions · `L_1349` 31%<br>generated code / generated code in batched profiles | 0.01/0.01 s · 1.83× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 4.00 / 3.38 / 9.93 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_fib-num` | `jit2:BenchZarithFibFn.fib` 98% | 0.01/0.01 s · 1.95× instructions · `L_1383` 35%<br>generated code / generated code in batched profiles | 0.01/0.02 s · 2.22× instructions · `area1` 98%<br>generated code / generated code in batched profiles | 4.83 / 3.28 / 10.67 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_tak` | `jit2:BenchZarithTakFn.tak` 100% | 1.00× · 1.26× instructions · `loop_59` 16%<br>generated code / generated code in batched profiles | 1.00× · 1.88× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 4.65 / 3.51 / 7.98 ms | Measured parity on this input |
| `zarith_tak-int` | `jit2:BenchZarithTakFn.tak` 98% | 0.01/0.01 s · 1.37× instructions · `L_1322` 22%<br>generated code / generated code in batched profiles | 0.01/0.02 s · 1.37× instructions · `area1` 100%<br>generated code / generated code in batched profiles | 5.09 / 3.17 / 8.79 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_tak-natint` | `jit2:BenchZarithTakFn.tak` 99% | 0.05/0.01 s · 3.36× instructions · `loop_63` 28%<br>generated code / generated code in batched profiles | 1.67× · 2.79× instructions · `area1` 95%<br>generated code / generated code in batched profiles | 7.30 / 3.34 / 10.94 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_tak-num` | `jit2:BenchZarithTakFn.tak` 56% | 1.67× · 1.55× instructions · `L_1375` 10%<br>generated code / generated code in batched profiles | 1.00× · 2.17× instructions · `area1` 97%<br>generated code / generated code in batched profiles | 4.72 / 4.66 / 12.62 ms | [Calls and checked loops](#calls-and-checked-loops) |
| `zarith_pi` | `big_of_value` 23% | 0.01/0.00 s · 28.04× instructions · `IntInf_binop` 41%<br>small samples (308/16) | 0.01/0.00 s · 11.92× instructions · `area1` 13%<br>Rune runtime / Poly/ML runtime in batched profiles | 10.91 / 5.02 / 8.83 ms | [Integer representations](#integer-ranges-and-representations) |
| `cryptarithm2-lazy` | `jit2:BenchLazy.force` 43% | 1.82× · 2.19× instructions · `forwardObjptr` 7%<br>≈+17.27G in generated code | 0.92× · 2.56× instructions · `area1` 89%<br>≈+6.89G in generated code | — | [Memoized delays](#memoized-delays) |
| `cryptarithm2-strict` | `jit2:fn` 22% | 1.72× · 2.18× instructions · `foreachObjptrInObject` 9%<br>≈+7.60G in generated code | 1.30× · 2.64× instructions · `area1` 90%<br>≈+5.95G in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |
| `cryptarithm1-lazy` | `jit2:BenchLazy.force` 21% | 2.80× · 3.38× instructions · `L_1572` 10%<br>≈+22.50G in collector | 0.34× · 0.60× instructions · `QuickGCScanner::ScanAddressAt(PolyWord*)` 51%<br>≈−100.03G in collector | — | [Memoized delays](#memoized-delays) |
| `cryptarithm1-strict` | `scan_object.part.0` 19% | 0.97× · 3.52× instructions · `forwardObjptr` 33%<br>≈+9.73G in Rune runtime | 0.47× · 0.32× instructions · `SortVector::sortList(PolyObject*, unsigned long, un…` 23%<br>≈−92.63G in collector | — | Measured parity on this input |
| `binarytrees5` | `jit2:BenchBinaryTrees5.check` 44% | 1.47× · 1.76× instructions · `L_1667` 16%<br>≈+155.3M in collector | 1.47× · 1.87× instructions · `area1` 56%<br>≈+413.1M in generated code | — | [Calls and checked loops](#calls-and-checked-loops) |

### Hosted compiler executables and HOL4 replays

The module probes run the same Rune compilation with the same published base-sized input under three engines. These compare hosts of Rune's compiler. The MLton build targets compare two builds of MLton. The initial HOL4 report supplies a Poly/ML comparison, and the individual kernel replays include setup. The manuscript’s HOL4 section interprets those measurements with a setup control.

| Compiler fixture | Rune hotspot | MLton-hosted Rune | Poly/ML-hosted Rune |
| --- | --- | --- | --- |
| `compile-share` | `jit2:OrdMapFn.go` 15% | 4.08× instructions · `L_90795` 12%<br>small samples (40/11) | 5.76× instructions · `area1` 94%<br>small samples (40/13) |
| `compile-sharenest` | `jit2:OrdMapFn.go` 10% | 4.15× instructions · `L_124222` 11%<br>small samples (40/12) | 5.93× instructions · `area1` 88%<br>small samples (40/14) |
| `compile-where` | `choose_homes` 12% | 3.80× instructions · `forwardObjptr` 22%<br>small samples (33/15) | 6.78× instructions · `area1` 63%<br>small samples (33/11) |
| `compile-sig` | `jit2:@` 20% | 2.64× instructions · `forwardObjptr` 24%<br>≈+101.1M in JIT compilation | 5.48× instructions · `area1` 80%<br>small samples (41/20) |
| `compile-funapp` | `jit2:OrdMapFn.bal` 7% | 3.87× instructions · `forwardObjptr` 18%<br>≈+212.8M in JIT compilation | 7.01× instructions · `area1` 96%<br>≈+212.8M in JIT compilation |
| `compile-funnest` | `scan_object.part.0` 9% | 2.67× instructions · `forwardObjptr` 17%<br>≈+213.4M in JIT compilation | 5.13× instructions · `area1` 93%<br>≈+218.2M in collector |
| `compile-expo` | `jit_compile_tier` 11% | 6.89× instructions · `L_36606` 18%<br>small samples (35/6) | 10.06× instructions · `area1` 67%<br>small samples (35/6) |

The following rows use the pinned MLton compiler and the reported build workloads. The hosted Rune comparisons above are distinct from running an MLton compiler that Rune built. The report’s second-stage MLton binaries both build the requested executable.

| Rune compiling pinned MLton | Rune hotspot | MLton-hosted Rune | Poly/ML-hosted Rune |
| --- | --- | --- | --- |
| whole | `mark_full` 17% | 2.48× instructions · `performGC` 24%<br>≈+19.75G in Rune runtime | 0.46× instructions · `SortVector::sortList(PolyObject*, unsigned long, un…` 34%<br>≈−829.56G in collector |
| units | `jit2:OrdMapFn.go` 20% | 2.21× instructions · `performGC` 9%<br>≈+28.38G in Rune runtime | 1.59× instructions · `area1` 62%<br>≈−69.51G in generated code |
| units-typecheck | `jit2:OrdMapFn.go` 15% | 3.66× instructions · `forwardObjptr` 15%<br>≈+55.79G in collector | 0.69× instructions · `SortVector::sortList(PolyObject*, unsigned long, un…` 43%<br>≈−97.85G in collector |

| MLton compile target | Rune-hosted MLton / MLton CPU time | Rune-hosted hotspot | MLton hotspot | Sampled difference | Rune / Poly-hosted MLton diagnostic |
| --- | --- | --- | --- | --- | --- |
| `boyer` | 3.01× | `jit2:fn` 12% | stripped executable 88% | 1% / 93% unnamed | 1.39× instructions · `area1` 49% |
| `barnes-hut` | 2.65× | `jit2:fn` 13% | stripped executable 91% | 1% / 94% unnamed | 1.31× instructions · `area1` 44% |
| `nucleic` | 2.50× | `jit2:fn` 14% | stripped executable 89% | 1% / 93% unnamed | 1.17× instructions · `area1` 40% |
| `model-elimination` | 4.07× | `jit2:fn` 10% | stripped executable 89% | 1% / 93% unnamed | 2.42× instructions · `area1` 43% |
| `mlyacc` | 4.07× | `jit2:fn` 8% | stripped executable 89% | 1% / 94% unnamed | 2.79× instructions · `area1` 40% |
| `hamlet` | 4.05× | `jit2:fn` 10% | stripped executable 89% | 1% / 93% unnamed | 2.40× instructions · `area1` 41% |
| `mlton.mlb` | 4.50× | `jit2:fn` 10% | stripped executable 89% | 1% / 92% unnamed | full build interrupted by memory pressure |

The third-host build tests use the same pinned sources. Its instruction ratios pair with the retained Rune-hosted counts. The original report supplies the Rune/MLton CPU-time ratios.

The bounded frontend run stops after MLton’s type-checking phase. It gives a separate comparison for the large build input.

| MLton type-checking engine | CPU time | Instructions | Hotspot |
| --- | --- | --- | --- |
| rune | 81.84 s | 370.54G | `jit2:fn` 15% |
| mlton | 64.19 s | 102.66G | stripped executable 94% |
| polyml | 81.84 s | 362.10G | `area1` 33% |

For each kernel workload below the two profiles include the same harness definitions. The term and proof operations are executed in the same order, with repeated short operations to make their hot code visible. Timing ratios belong to the original report.

| HOL4 workload | Rune / Poly/ML | Rune hotspot | Poly/ML hotspot |
| --- | --- | --- | --- |
| `logroot` | 1.66× | `jit2:Portable.pair_compare` 3% (proof) | `area1` 23% (proof) |
| `mergesort` | 1.67× | `jit2:Portable.pair_compare` 6% (proof) | `area1` 22% (proof) |
| `kernel` | 2.06× | `jit2:List.exists` 5% | `area1` 7% |
| `EVAL-FACT-60` | 2.05× | `jit2:Type.ty_sub` 5% | `area1` 20% |
| `EVAL-FACT-150` | 2.05× | `jit2:Type.ty_sub` 5% | `area1` 9% |
| `PROVE_TAC-x20` | 7.78× | `relocate_obj` 10% | `area1` 35% |
| `SIMP_CONV-arith-x200` | 2.89× | `relocate_obj` 6% | `area1` 29% |
| `DECIDE-x200` | 2.44× | `relocate_obj` 5% | `area1` 26% |
| `Arbnum-mul-x200000` | 9.27× | `__gmpz_import` 11% | `area1` 38% |
| `type_of-term-x200000` | 3.00× | `jit2:Type.dom_rng` 19% | `area1` 36% |

<!-- end-workload-tables -->

## Validation and resource limits

The evidence index contains 1,000 validated replay and profile
records. That includes 768 original catalogue replay cells and
six executions of the repaired catalogue recipes. The proof
subprocess audit verifies four new HOL4 theory exports.

The concurrent diagnostic run of the Poly/ML-hosted MLton compiler
on `mlton.mlb` was killed under system memory pressure. The previous
boot's kernel log identifies that process, with about 15.3 GiB of
anonymous resident memory at the kill. See
`previous-boot-oom.log`. The completed smaller Poly/ML-hosted
compilations have their own output receipts. The interrupted full
run contributes no complete compiler timing.

Recovery experiments run sequentially. The per-process virtual
address-space limits are 6 GiB for the six smaller compiler tasks
and 12 GiB for the large compiler controls. The run records also
give the CPU-time, file-size, and open-file limits. The launcher
requires available memory before starting each stage. The
resumed type-check and native short-compile profiles also recheck
available memory while their children execute.

The clean, bounded `make perf-check` passed all 48 tests. Its receipt
is `bounded-perf-check.log`.

The study's fresh `make check` was interrupted after the runner
reported 21,340 completed jobs and zero failures. Its receipt is
`check.log`. The refreshed report's earlier complete clean check
of the same source revision recorded 28,442 passes and five skips.
That receipt is `check-clean.log` in the original measurement
directory. The private workload source probes each checked their
expected result. The source and executable identities for the
baseline replay are retained in the evidence.

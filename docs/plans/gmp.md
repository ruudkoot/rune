# Roadmap: GMP-backed IntInf with an efficient SML fallback

Give the register VM GMP arithmetic, keep the same bytecode runnable without
GMP, and replace the current SML implementation with a substantially faster
one. The SML implementation remains useful in its own right: it supplies the
stack VM and `runeopt`, runs on host compilers, and provides an independent
check on GMP results.

Written on 2026-10-06 against `ca87fa07d239a072cff24bac03ce72b74ff93a7a`.
The owner approved the design below, including runtime backend selection,
representation changes, finite default limits, and pinned GMP release builds.
The original design was recorded before implementation. The status table and
dated evidence below distinguish that plan from completed work and measurements.
The original M1-M5 records retain their pre-rebase source and binary hashes;
post-rebase validation is recorded separately at the end.

## Status and requirements

| Milestone | Depends on | State |
|---|---|---|
| M0: record the design | the original brief and owner's decisions | done 2026-10-06; delivery evidence below |
| M1: establish correctness and performance baselines | M0 | done 2026-10-06; fixed corpus and baseline below |
| M2: replace the SML representation and kernels | M1 | done 2026-10-08; implementation and acceptance evidence below |
| M3: add GMP behind the shared interface | M2 | done 2026-10-11; integration and acceptance evidence below |
| M4: harden runtime integration and tune dispatch | M3 | implementation done 2026-10-12; expanded performance acceptance reopened 2026-10-15, below |
| M5: complete portability and release validation | M4 | local checks done 2026-10-14 and repeated after rebase; release acceptance awaits performance follow-up and remote CI |

Each completed milestone is committed separately, with its commands, results,
limitations, and comparison to the preceding milestone recorded here. A failed
completion gate leaves the milestone open. Unavailable checks are outstanding,
not passes. The dependency order is sequential so that the independent SML
implementation exists before GMP is introduced.

The original brief is accounted for as follows:

| Requirement | Where it is delivered |
|---|---|
| The register VM uses GMP for `IntInf` | M3, with dispatch tuning in M4 |
| Keep an SML implementation for the stack VM and when GMP is unavailable | M2; the same-register-bytecode check in M3 |
| Make that implementation much faster on Rune | M1's baseline, M2's kernels, the performance gates |
| Keep MLton compatibility and other hosts where practical, without sacrificing Rune performance | M2's width-specific kernels and host tests; M5's matrix |
| Account for the Lean soundness failures involving GMP | dependency provenance in M3, limits and independent checks in M2-M4 |

## Baseline at ca87fa07

At the baseline, [intinf.sml](../../lib/basis/intinf.sml) represents a value
as a sign and a little-endian list of base-2^30 limbs. It normalizes zero and
removes high zero limbs, so structural equality is numeric equality. Even
small nonzero values use the list representation. Multiplication builds and
adds shifted partial products; multi-limb division finds each quotient digit
by binary search. These are source observations, not measured explanations
of an end-to-end bottleneck.

There are no GMP arithmetic primitives. `IntInf` loads before `Int`, whose
large-integer conversions use it; `Word` and later numeric structures depend
on those. The replacement cannot simply depend on the public byte-array and
word structures later in the Basis load order.

The register and stack engines share the runtime, and `runeopt` uses its
native library. Heap values move during collection. Primitive arguments must
remain rooted until a result exists, and temporary values must be rooted
across any further allocation. The layout interface, image format, generated
primitive descriptions, and host primitive shim are existing integration
points; see [architecture.md](../architecture.md) and
[bytecode.md](../bytecode.md).

The Basis suite already covers `INT_INF`, generic integer operations, and
scanning. Its deviation ledger records arithmetic and conversion failures
in reference systems. Reference agreement is useful evidence, but neither a
single host's answer nor agreement between GMP-based implementations is an
independent correctness argument.

## The design

### Public contract and shared representation

Keep `INT_INF`, `LargeInt.int = IntInf.int`, overloaded constants, and value
equality. Compiler, primitive, representation, and image-format changes are
allowed; each must follow the repository's generation and validation rules.
No new public numeric type or alternative user-facing arithmetic API is
needed.

Use a canonical small-integer/large-integer representation. A small value
holds a machine integer. A large value holds a sign and an immutable packed
magnitude, least-significant byte first, independent of GMP's limb width and
the machine's byte order. Every constructor and operation establishes:

* zero has one representation, the small value zero;
* a large magnitude has no high zero bytes and is never negative zero;
* a result fitting the small range is reduced to the small form;
* no mutable workspace is exposed as part of a finished value.

Thus equality compares the value rather than an allocation's identity.
Small-range normalization is defined for the target representation, not by
the compiler host's `Int` width. Within one target, either backend constructs
the same values. Images carry ordinary Rune values, never native pointers.

Keep normalization, scanning, SML exception rules, and dispatch in SML.
Introduce private packed-storage helpers early in the Basis load order,
using the existing storage primitives and host adapters rather than creating
an `IntInf -> Int -> Word -> IntInf` cycle. An ordinary datatype and packed
bytes are the initial representation; a new VM object kind is not a
prerequisite.

### Efficient SML arithmetic

Use indexed temporary storage instead of repeated list construction and
reversal. Implement carry and borrow loops, single-limb operations,
schoolbook multiplication, normalized long division with quotient estimation
and correction, and direct bit operations. Include small-value arithmetic
and conversion paths. Scratch mutation remains internal to one operation.

Rune's kernel uses 30-bit arithmetic limbs with wide intermediates. Narrow
hosts use 15-bit limbs, selected through the arithmetic configuration. These
are workspace digits; they do not change the canonical packed format. The
width choice is established before the public `Int` structure loads and
must not rely on a large literal accepted only by the host compiling Rune.

Add Karatsuba multiplication only after the fixed workload shows a stable
crossover. Keep the schoolbook path below it and for operand shapes where
it wins. The same rule applies to later dispatch tuning: record the
experiment, crossover, and workloads that regress before changing a default.

MLton compatibility is required. Exercise Rune's actual fallback on the
other hosts rather than silently substituting their native `IntInf`. Retain
the compiler's existing host-build and bootstrap obligations. Host bugs get
minimized reports and explicit test deviations; a workaround must not slow
the Rune kernel or hide a wrong result.

### GMP boundary and backend selection

Begin with the documented `mpz` API. Import the packed magnitude, apply its
sign, compute, and export the result for SML normalization. GMP's
[import/export interface](https://gmplib.org/manual/Integer-Import-and-Export)
allows an explicit byte order without requiring the input to be aligned or
to match `mp_limb_t`.

A GMP object exists only during a primitive call. It is cleared on every
returning path; no finalizer or persistent native allocation is needed.
Import input bytes before a Rune allocation could move them. While exporting
and constructing results, obey the usual root discipline, including both
members of a quotient/remainder pair. GMP allocations must not invoke the
Rune collector or call back into SML.

| Interface | Behaviour |
|---|---|
| `GMP=auto` | Enable GMP for the register VM if a supported dependency is found; otherwise build the SML-only configuration and report that choice. |
| `GMP=yes` | Require a supported GMP dependency; missing or unsupported GMP is a build error. |
| `GMP=no` | Build without a GMP link dependency. |
| `--intinf=auto` | On the register VM, use the enabled GMP backend with the measured small-operation paths; otherwise use SML. |
| `--intinf=gmp` | Require the GMP backend; reject the request clearly if unavailable. |
| `--intinf=sml` | Force independent SML arithmetic even in a GMP-enabled build. |

The stack VM and `runeopt` use the SML fallback in this roadmap. Their
primitive tables still contain the same new primitive identities and safe
unavailable-backend handling. The same register `.rbc` runs on GMP-enabled
and GMP-free builds of the same ISA revision; this does not make stack and
register bytecodes interchangeable. A GMP-linked executable can still need
its shared library to start: a GMP-free VM is the fallback executable.

Primitive descriptions and fingerprints are identical across dependency
configurations. Availability and selected backend belong to the running VM,
not a persisted SML boolean or a compiler-folded fact. Restoration resolves
them again before resuming. No GMP pointer, capability cache, or allocation
accounting state is serialized. New primitive effects must describe their
allocation, failure, and runtime-state dependencies accurately.

### Semantics at the boundary

The [Basis specification](https://smlfamily.github.io/Basis/int-inf.html)
remains the authority. Preserve integer and word conversions, scanner
consumption, `~` in decimal output, and the documented radix conventions.
Special cases are handled before conversions to narrower C counts.

| Operation | Required handling |
|---|---|
| `div`, `mod`, `divMod` | Floor division; use GMP's `fdiv` family. |
| `quot`, `rem`, `quotRem` | Truncate towards zero; use the `tdiv` family. |
| Division by zero | Raise SML `Div` before entering GMP. |
| `~>>` and bit operations | Preserve arithmetic right shift and infinite two's-complement behaviour for negatives. |
| `pow` | Handle zero, unit bases, and negative exponents in SML before the ordinary positive-power path. |
| Conversions and `log2` | Check bounded results, including the permitted `Overflow` from an unrepresentable `log2` result; preserve `Domain` for nonpositive inputs. |

Do not implement SML `mod` with `mpz_mod`: that function ignores the
divisor's sign. GMP also deliberately faults on zero divisors, so SML's
check cannot be omitted. See the
[GMP division contract](https://gmplib.org/manual/Integer-Division).
Do not assume C `long` can hold Rune's machine integer on Windows or a
32-bit target; use checked conversions or the packed-byte boundary.

### Dependency provenance and arithmetic limits

CI and release builds use checksum-pinned GMP 6.3.0 initially, with its own
tests run for the build configuration. A local system GMP must be at least
6.3.0 and pass the version and ABI checks. Record the source archive and
digest or system package identity, any patches, compiler and linker flags,
target, limb width, header version, and actual linked-library version.
Recheck provenance when updating the pin. The
[GMP release page](https://gmplib.org/) lists 6.3.0 as current when this
roadmap was written; a version floor alone does not prove correctness.

The owner's defaults are finite and configurable:

| Limit | Initial default | Meaning |
|---|---|---|
| `--intinf-max-bits` | `134217728` bits | Maximum magnitude size, 16 MiB of packed bits, applied to both arithmetic backends. |
| `--intinf-gmp-memory` | `268435456` bytes | Maximum outstanding allocations tracked through GMP's allocation hooks. |

These are operational resource limits, not the `IntInf.precision` of the
language, which stays `NONE`. Validate limit arguments and all size/count
conversions, and retain hard implementation bounds even when the user raises
a budget. Check input and result-size bounds before expensive work, then
validate the result. Shifts, powers, and parsing need preflight checks of
their own; handle shrinking operations and zero/unit special cases without
constructing a hypothetical huge intermediate.

Use Rune's resource-limit failure path, with a diagnostic naming the limit,
rather than returning a truncated value or raising `Overflow` for an
unbounded arithmetic result. Keep bounded-conversion exceptions unchanged.
Restoring an image retains the stricter saved and invocation limits. Tests
use deliberately small limits so boundary failures need little memory.

Install GMP allocation hooks before the first GMP object. They track
allocation, reallocation, and release and terminate cleanly on exhaustion.
They must not return `NULL`, raise an SML exception across GMP, or use
`longjmp`: the [GMP allocation contract](https://gmplib.org/manual/Custom-Allocation)
does not support recovery that way. Document GMP stack temporaries and
system/allocator overhead as outside the tracked allocation budget. The
existing Rune heap limit still applies to the SML workspace and stored
values; neither arithmetic limit promises a total-process RSS or time cap.

### What the Lean incident changes

The [2026-08-24 postmortem](https://leodemoura.github.io/blog/2026-8-24-postmortem-for-the-kernel-soundness-bug-hunt/)
reports that Lean's Linux distribution used GMP 6.1.2 and that a known bug
there could be exploited to prove `False`. Requiring GMP 6.3.0 addressed
the dependency issue. A separate hardening change bounded kernel numeral
sizes after another exploit involving multi-gigabyte numerals on 6.1.2.
The authors did not claim that 6.3.0 excludes all similar extreme-size bugs.

Rune therefore needs dependency provenance, bounds, and independent checks.
No formal soundness claim follows from those checks. Keep the old list
implementation as a bounded test oracle, not a selectable production
backend, and do not treat it as infallible. Combine it with reviewed exact
answers, algebraic properties, and reference-system comparisons.

## The milestones

### M0: record the design

**Depends on:** the brief and the owner's approved plan.

**Deliver:** this document, the source baseline, decisions and alternatives,
requirement mapping, risks, milestone order, references, and acceptance gates.
Only `docs/plans/gmp.md` changes for this milestone. In particular, the
unrelated collector draft is not part of it.

**Done when:** every original requirement is covered; planned work and
performance targets cannot be mistaken for completed work or measurements;
local links and whitespace are checked; the repository's required
`make check` is run and its outcome recorded. Commit the document separately.

### M1: establish correctness and performance baselines

**Depends on:** M0.

**Deliver:** deterministic workloads and a reproducible runner. Cover small
integers, transitions around 15-, 30-, 31-, 32-, 62-, 63-, and 64-bit
boundaries, balanced and unbalanced large operands, carry chains, division,
conversion, shifts, and powers. Include the existing factorial benchmark,
compiler bootstrap, and representative compiler workloads. Preserve the
old arithmetic implementation as a test-only oracle before replacing it.

Freeze separate small-arithmetic, large multiplication/division, and broad
large-arithmetic suites. Give operands as exact inputs or recorded seeds;
verify answers before timing. Run the old oracle only at bounded sizes, so
large tests cannot turn its slowness into an unbounded job.

**Done when:** inputs, reviewed expected answers, seeds, commands, full source
commit, compiler/VM/dependency identity, machine/OS identity, raw repetitions,
timings, allocations, and peak memory are retained. Another run reproduces
the results within stated timing variation. The performance gates below
have named, fixed workload sets; there is no GMP speedup claim yet.

### M2: replace the SML representation and kernels

**Depends on:** M1's frozen workloads and independent test oracle.

**Deliver:** canonical packed values, small paths, indexed arithmetic,
normalized long division, improved conversions and bit operations, and the
wide/narrow workspace configurations. Establish shared normalization and
size preflight so that M3 can reuse the same checks. Update Basis load order,
host adapters, signature comments, language documentation, and generated
documentation with the implementation.

**Done when:** semantic tests pass on Rune and MLton; the other host outcomes
are recorded with minimized reports for failures; equality and overloaded
literals work; both bytecodes bootstrap; and the SML performance gate is met.
Run the library matrix against Rune's implementation itself. Add Karatsuba
only if the measured crossover justifies it. Leave the milestone open if a
performance target is missed rather than silently lowering it.

### M3: add GMP behind the shared interface

**Depends on:** M2's representation, semantics, and passing SML backend.

**Deliver:** primitive descriptions and generated tables, checked GMP
bindings, build/runtime selection, pinned dependency provisioning, version
reporting, and the complete arithmetic/allocation limit controls. Provide
unavailable-backend stubs in GMP-free builds and host adapters that permit
testing the fallback. Inspect actual linked dependencies in release builds.

**Done when:** the identical register `.rbc` passes with automatic GMP,
forced SML, and a GMP-free VM; explicit unavailable requests fail clearly;
an older GMP is rejected; and saved programs resolve availability correctly
when restored on the other backend build. Correctness, not a timing result,
is this milestone's first gate. Record initial GMP costs for M4.

### M4: harden runtime integration and tune dispatch

**Depends on:** M3's working backends and recorded initial costs.

**Deliver:** GC-rooting, equality, image, fork/resume, and malformed-argument
tests; subprocess tests of low size/allocation limits and allocation failure;
and profiling that separates GMP computation from import/export and Rune
allocation. Tune operation-specific thresholds on the frozen workloads.
Keep the documented `mpz` boundary and transient ownership model.

**Done when:** applicable sanitizers, heap checks, and GC stress pass;
bounded failures terminate with the expected diagnostic and status; returning
calls leave no live GMP allocations; and the GMP performance gate is met.
The register interpreter and JIT tiers agree within each backend, including
deoptimization and image restoration. Any measured conversion bottleneck and
remaining limitation is recorded explicitly.

### M5: complete portability and release validation

**Depends on:** M4's hardened, measured implementation.

**Deliver:** the full engine, host, and platform matrix for GMP and SML;
image round trips between backend builds and supported widths/byte orders;
release and installation checks for enabled and disabled GMP; and final
language, runtime, bytecode, build, register-architecture, and generated
Basis documentation. Update the image reader in `runeopt` if the image
format changed, and follow ISA generation rules if the bytecode changed.

**Done when:** the checks below pass for every supported configuration,
including bootstrap equality across compiler hosts. Test Windows, 32-bit
x86, big-endian PowerPC, and the supported JIT targets; a host-only result
cannot stand in for them. Publish before/after measurements and limitations.
Unavailable checks keep M5 open. Commit the final evidence with the milestone.

## Measuring and acceptance

### Correctness

Test exact answers and identities as well as differential results. Include
all sign combinations of division, zero divisors, borrow/carry chains,
normalization after cancellation, small/large transitions, equality in
polymorphic containers, minimum machine integers, oversized shifts,
negative powers, negative bit operations, scanner termination, and bounded
conversion overflow. Exercise each result through both arithmetic paths.

Test images containing small and large values between GMP-enabled and
GMP-free VMs of the same bytecode target, including stricter invocation
limits. A changed backend must not leave a stale choice in the resumed
program. Run resource and malformed-input cases in subprocesses with time
and memory limits; distinguish a planned resource failure from timeout,
signal, crash, or wrong answer.

Keep existing engine-equivalence checks by forcing the same arithmetic
backend: SML for stack/native/register comparisons, and separate GMP runs
across register interpreter and JIT tiers. Preserve the existing same-engine
count guarantees. SML and GMP execute different arithmetic work, so report
their instruction counts and managed/native allocations separately rather
than requiring those two backends to allocate or count alike.

### Performance targets, not measurements

| Gate | Required result on M1's fixed workload set |
|---|---|
| Faster SML | At least 2x geometric-mean speedup over the original list implementation on large multiplication/division. |
| GMP benefit | At least 2x geometric-mean speedup over the new SML fallback on the broad large-arithmetic suite. |
| Small and compiler workloads | No reproducible regression above 5% from the preceding accepted baseline; also report the comparison to M1. |

Compute speedups from per-workload repeated timings, with equal workload
weight in the geometric mean. Record warmup, repetition count, timer,
variance, machine load, and JIT mode. Use enough iterations that startup and
timer resolution do not dominate, and publish individual workloads as well
as aggregates. Separate compile time from execution time; compiler bootstrap
is an end-to-end workload of its own.

Report managed allocations, GMP allocations, peak RSS, and conversion costs
alongside speed. A faster arithmetic primitive with a slower real workload
does not meet the regression gate. Keep the input corpus and acceptance
thresholds fixed while tuning. If a gate is missed, publish the miss and
revisit the design explicitly; do not select a more flattering corpus.

### Required validation

At each implementation milestone run [AGENTS.md](../../AGENTS.md)'s
applicable checks, not just the new arithmetic tests:

* `make check`, including self-hosting, cross-host bytecode equality,
  register/JIT/native checks, and generated-document/ISA consistency;
* `make matrix-quick` after Basis changes, plus targeted arithmetic laws and
  the independent differential suite;
* stack and register sanitizer suites, `make test-stress`, and
  `make test-heap` for the affected runtime and layout work;
* `make windows` and `make test-windows` for runtime changes;
* `make portability` and `make test-portability` for layout and image work,
  with the supported JIT-target checks as applicable.

Record exact commands and dependency configurations. The large platform
matrix closes in M5, but an earlier change still obeys the checks required
for its scope. Generated documentation changes with the relevant milestone,
not only at the end. Keep raw logs and enough provenance to rerun a failure;
do not promise byte-identical toolchain builds merely from version names.

## Alternatives, risks, and neighbouring work

| Choice | Benefit | Cost or risk and response |
|---|---|---|
| Shared packed values and runtime selection | One program and image representation works with either backend. | Import/export can dominate small operations; keep small paths and measure thresholds in M4. |
| Independent SML arithmetic | Portable execution and a distinct implementation for checking GMP. | Two implementations need maintenance; run the same contract tests and freeze regression cases. |
| Documented `mpz` API with transient objects | No persistent foreign pointers, finalizers, or GMP-internal layout dependence. | Temporary copies and allocations; report their memory and timing cost. |
| Indexed SML kernels | Less list traffic and better division without requiring GMP. | Normalization and quotient correction are error-prone; boundary cases, independent answers, and properties are mandatory. |
| Finite configurable limits and a pinned dependency | Predictable rejection of extreme work and auditable release inputs. | Limits are operational policy, and a version pin cannot guarantee absence of bugs; retain independent checks and document exclusions. |

Separate bytecode variants were rejected in favour of runtime fallback.
Keeping the current limb lists was rejected because conversion and allocation
costs would remain. Persistent `mpz_t` objects and direct manipulation of
GMP internals are not part of the first integration: they would add lifetime,
GC, and image obligations before their benefit had been measured. Direct
`mpn` integration is a later design change if the recorded `mpz` results
justify one, not an unrecorded substitution inside a milestone.

The [collector brief](collector.md), [collector v2 draft](garbage-collector-v2.md),
and [heap-layout roadmap](heap-layout.md) are relevant interfaces, not
prerequisites to replace the collector. Packed immutable values remain
ordinary managed objects; GMP memory is separately accounted and temporary.
General FFI, new collectors, multithreading, and formal verification remain
outside this roadmap. Revisit allocation-hook ownership and synchronization
before embedding concurrent VMs or adding runtime threads.

## M0 delivery evidence

The source baseline and the cited specification, GMP documentation, and
Lean postmortem were read on 2026-10-06. This milestone edits only this file.

* The document check passed: all seven local links resolve, M0-M5 each have
  dependencies, deliverables, and a completion gate, M1-M5 were initially marked planned,
  and there is no trailing whitespace. The external source links above were
  opened and read. The unrelated collector draft's content is unchanged.
* `make check JOBS=4` first stopped inside the syscall sandbox when the
  32-bit SML/NJ host received `Bad system call`. Starting that host outside
  the sandbox succeeded; the first result was an execution restriction,
  not evidence of a missing or broken host installation.
* `make check JOBS=4` then passed outside the sandbox, exit status 0. Both
  bytecodes reproduced themselves; all six host builds passed the 338-test
  language suite; the Basis suite, 802 documentation examples, native and
  register/JIT checks, and generated-document/ISA checks passed. Cross-host
  checks found identical bytecode for 508 programs and agreement between
  the builds of `runedoc` and `runeopt`.
* Local full-check transcripts are
  `/tmp/rune-gmp-roadmap-check.2SuT8K.log` (sandbox restriction) and
  `/tmp/rune-gmp-roadmap-check-outside.iPZdEu.log` (pass). These are local
  temporary logs, not committed artifacts.

These checks validate M0 against the existing implementation. No new GMP or
replacement-SML implementation or performance gate has been run.


## M1: fixed corpus and baseline

Implementation started on branch `gmp` in `.worktrees/gmp` from M0's
`531e144b`. The runtime and Basis arithmetic remain those of `ca87fa07`.
`tests/intinf/oracle.sml` preserves the original list implementation with
only its structure name and primitive bindings adapted for a test program.
`tests/intinf/checks.sml` checks it and the current implementation against
independent integer fixtures: 1,154 checks on each, including 230 signed
operand pairs, 13 exact answers per pair, identities, and exceptional cases.
The new `make test-intinf` is part of `make check`.

The manifest and generator in `tests/intinf` freeze twelve workloads. Initial
calibration increased short workloads' iteration counts before freezing
M1. Two complete sequential timing runs varied substantially (up to 55% on
one workload), so the final runner also alternates current and saved-oracle
executions within each pair. The final baseline has seven measured pairs
after one warmup pair. Its calibration is not a GMP performance result.

`tests/intinf/baseline.json` records every sample, compiler timings, source
and tool hashes, machine identity, load, exact expected answers, and a
separate instrumented transcript for each workload. Complete local commands,
streams, statuses, input programs, source snapshots, and usage records are
under `tests/out/intinf/m1-paired`. Reproduce with:

```
python3 tests/intinf/run.py --bench --paired-oracle --compiler-workloads --samples 7 --out tests/out/intinf/m1-paired
```

Headline arithmetic times use `Time.now` around the loop, at microsecond
resolution. Process wall/CPU time and peak RSS are separate. Each subprocess
has a 180-second timeout and a 4 GiB address-space cap; timeout and
interruption kill the process group, not just its timing wrapper. VM mode
and GC environment overrides are removed unless supplied as explicit VM
options. These runs use the register VM's default optimizing JIT.

| Workload | Iterations | Median seconds | Sample range | Paired oracle/current ratio |
|---|---:|---:|---|---:|
| small-add | 1500000 | 0.283309 | 0.276094-0.313348 | 1.045 |
| small-mul | 1000000 | 0.284096 | 0.253099-0.317028 | 0.931 |
| mul-512 | 7500 | 0.273868 | 0.253631-0.280873 | 0.967 |
| mul-4096 | 320 | 0.680979 | 0.612439-1.975697 | 0.984 |
| mul-unbalanced | 6000 | 0.367812 | 0.325790-0.378109 | 1.023 |
| div-1024 | 400 | 0.507801 | 0.491890-0.526708 | 0.967 |
| div-4096 | 40 | 0.675502 | 0.651255-0.688535 | 0.995 |
| div-unbalanced | 400 | 0.689981 | 0.642282-0.713807 | 1.017 |
| bits-4096 | 10000 | 0.404504 | 0.351922-0.432386 | 0.910 |
| convert-4096 | 100 | 0.700974 | 0.649210-0.725966 | 0.997 |
| power-1024 | 300 | 0.596322 | 0.557167-0.608536 | 1.050 |
| factorial-300 | 300 | 0.279311 | 0.259225-0.308251 | 0.973 |

The paired calibration ranges from 0.910 to 1.050; a small difference
inside this variation is not evidence for or against a 5% regression gate.
M2 compares the new arithmetic to the preserved implementation in pairs,
and reports the raw samples and uncertainty with the speedup. Compiler
workloads retain their separate end-to-end comparisons.

Compiler medians: `compile-hello` 0.035818 s, `compile-sigs` 0.267001 s, `bootstrap` 2.366197 s.

M1 acceptance: `make check JOBS=8` passed outside the syscall sandbox,
including the new oracle test, all host builds, both bootstrap bytecodes,
native and register/JIT suites, the Basis suite, and generated documentation.
508 programs produced identical bytecode across the seven compiler builds.
The local transcript is `tests/out/intinf/m1-check.log`. `git diff --check`
also passed. The isolated M2 prototype under `tests/out/intinf` is not part
of this milestone or the arithmetic used by this acceptance run.


## M2: packed values and indexed SML arithmetic

The implementation uses canonical `S`/`B` values, immutable little-endian
magnitude bytes, 30-bit scratch digits on Rune, and 15-bit digits on narrow
hosts. Multiplication is schoolbook; division estimates and corrects quotient
digits in indexed scratch arrays. Karatsuba has not been added: the measured
basic kernels already exceed the multiplication/division target in exploratory
runs, and the remaining costs came from representation conversion.

**Refinement of the initial storage plan:** the first prototype implemented
packing with the existing scalar byte operations. Its division improved,
but factorial and bit operations regressed. Removing repeated power-of-two
calculations helped, but packing still dominated several workloads. Two
private storage primitives, `intinf_unpack` and `intinf_pack`, now convert
between bytes and scratch digits. They perform no integer arithmetic beyond
encoding the representation. Signs, normalization, addition, multiplication,
division, parsing, and bit operations remain SML. Their independently written
SML host adapters support both widths without wide intermediates on a 31-bit
host. This extends the primitive interface permitted by the design; the
canonical value format and backend independence are unchanged.

The new storage ABI has 150 boundary and malformed-argument checks, also
passed with a collection at every allocation. The language regression covers
small/large transitions, the negative machine boundary, bounded conversion,
canonical zero, shifts, and exact cases requiring quotient correction and
add-back. The old oracle and independent fixtures still pass 1,154 checks
each. Generated documentation and its checks pass.

The targeted `xc1` IntInf matrix passes all 5,418 checks on each of MLton,
SML/NJ legacy 64-bit and 32-bit, SML/NJ development, Poly/ML, and MLKit. This
runs Rune's implementation on the hosts, including the narrow 15-bit kernel;
the former SML/NJ32 signature-width deviation is removed. Local evidence is
`tests/out/intinf/m2-hosts.log` and `tests/out/matrix/report-intinf.md`.
The complete matrix also exposed host limitations that the old implementation
could not reach on SML/NJ32. Their minimized probes, exact check names, and
M1 comparison are recorded in [host-coverage.md](../../tests/intinf/host-coverage.md).
The final ledger was applied to the retained full-matrix results with the
unchanged official report generator: zero unexplained failures, with hashes
of those results and the reporter in `tests/out/intinf/m2-host-recheck`.
This was a report regeneration, not another execution of the full matrix.
The final mixed-comparison optimization receives another targeted IntInf
matrix and full `make check` below.

### M2 measured performance

[The measurement record](../../tests/intinf/sml-results.json) retains all
samples, machine identity, source/tool hashes, allocation counts, and peak
RSS. It uses M1's unchanged workloads, seven alternating pairs after one
warmup pair, default register JIT, and the same bounded runner:

```
python3 tests/intinf/run.py --bench --paired-oracle --compiler-workloads --samples 7 --out tests/out/intinf/m2-final4
```

| Workload | Median seconds | Sample range | Paired old/new speedup |
|---|---:|---|---:|
| small-add | 0.112883 | 0.096636-0.152245 | 2.768 |
| small-mul | 0.077865 | 0.063826-0.092494 | 3.570 |
| mul-512 | 0.108794 | 0.096108-0.122324 | 2.508 |
| mul-4096 | 0.226690 | 0.218127-0.236448 | 2.825 |
| mul-unbalanced | 0.219624 | 0.212173-0.236069 | 1.715 |
| div-1024 | 0.009810 | 0.009043-0.012413 | 51.466 |
| div-4096 | 0.011544 | 0.009762-0.014295 | 61.658 |
| div-unbalanced | 0.023256 | 0.022622-0.026578 | 29.968 |
| bits-4096 | 0.508458 | 0.486735-0.526929 | 0.727 |
| convert-4096 | 0.327949 | 0.304026-0.354119 | 2.212 |
| power-1024 | 0.056195 | 0.053983-0.071809 | 10.898 |
| factorial-300 | 0.254392 | 0.211759-0.258211 | 1.129 |

The multiplication/division geometric mean is **10.244x**, above the proposed
2x gate. Both small workloads improve. The 4096-bit bit-operation workload
regresses (0.727x): it is outside the stated small/compiler regression gate,
but is a recorded weakness for M4 tuning, not hidden by the aggregate.
No Karatsuba crossover is claimed.

An initial paired compiler run found a reproducible signature-workload
regression above 5%. Profiling found extra compilation work and unnecessary
packing during mixed small/large comparisons. Canonical values now make
those comparisons from the large operand's sign alone. The fixed corpus,
threshold, compiler flags, and sample order were not changed.
[The paired compiler record](../../tests/intinf/sml-compiler-results.json)
uses 25 measured pairs after two warmup pairs, with hash-verified M1 compiler
artifacts and each revision's own Basis. Every output matches its reference;
the full bootstrap and cross-host checks additionally validate reproduction.

| Compiler workload | M1 median seconds | M2 median seconds | Median paired M2/M1 |
|---|---:|---:|---:|
| compile-hello | 0.033179 | 0.033993 | 1.0021 |
| compile-sigs | 0.265039 | 0.268425 | 1.0102 |
| bootstrap | 2.447420 | 2.522527 | 1.0325 |

All three paired ratios are below 1.05. The exploratory 25-pair signature
rerun was 1.0252; the final run is 1.0102. Timings remain measurements on the
recorded machine, not guarantees on every host. The sequential M1 and M2
compiler measurements are retained in their respective records too.

### M2 acceptance

* `make check JOBS=8` passed outside the syscall sandbox after the final
  comparison change (`tests/out/intinf/m2-check4.log`): 339 language tests,
  139,218 Basis checks, native and register/JIT checks, documentation and ISA
  checks, both bootstrap bytecodes, and cross-host equality for 509 programs.
  Existing explained host/engine deviations remain visible in the reports.
* Full `make matrix-quick JOBS=8` ran with the new representation and kernels.
  Its host coverage and final report regeneration are described above. The
  final comparison change also passed all 5,418 IntInf checks on Rune and
  each of the six host configurations (`m2-hosts4.log`).
* Stack and register ASan/UBSan suites, `make test-stress JOBS=8`,
  `make test-heap JOBS=8`, `make test-windows JOBS=2`, and
  `make test-portability JOBS=8` passed. The runtime was unchanged after
  these runs; the final SML comparison change was rechecked as above.
  `tests/out/intinf/m2-runtime-acceptance.log` indexes their `m2-*3` logs.
  The storage ABI also passed its 150 checks under collection stress and
  ASan/UBSan. Windows, Linux32, big-endian PowerPC, and AArch64 tests ran;
  these were not inferred from the native Linux result.
* `make docs`, `make check-docs`, local-link checks, and `git diff --check`
  passed. Existing arithmetic allocation budgets were preserved.

Raw commands, streams, source snapshots, and reports are local under
`tests/out/intinf`; the portable performance records above are committed.
The main checkout and its unrelated collector draft remain untouched.

## M3: shared GMP bindings and finite runtime policy

The optional `runtime/intinf.c` implementation uses public `mpz` operations,
with canonical little-endian import/export and no native arithmetic pointers
in Rune values. Generated primitives are present in every build. SML keeps
small arithmetic, scanning, normalization, exceptional cases, and dispatch.
`GMP=auto|yes|no`, `GMP_PREFIX`, `--intinf=auto|gmp|sml`, and the wrapper default
`RUNEVM_INTINF` select availability without changing bytecode fingerprints.
Explicit unavailable GMP requests fail. Stack/native output remains SML.

The pinned recipe verifies the GMP 6.3.0 source checksum and installed artifacts,
runs upstream tests, and records requested/configured options, target, compiler,
commands, and provenance. Both header and linked-library versions are checked
before arithmetic and reported by the VM. CI invokes the pinned recipe; the
local pinned build and its upstream tests passed. Remote CI is not claimed
as executed here. CPU-family release packaging remains part of M5.

Both arithmetic paths enforce the 134217728-bit default budget. The supported
configuration range is 64 through 1073741822 bits: this keeps machine values
within the minimum and binary formatting and scanner scratch growth within their storage
representations at the maximum. Low limits may reject Basis initialization (Word64 constructs the
65-bit magnitude 2^64). GMP separately tracks allocations against the default
256 MiB live budget. Requested bytes, allocation calls, and peak live bytes
are reported separately from managed allocations and process memory. Image
format 11 carries both limits, preserving the stricter invocation/saved value;
backend selection comes from the current VM.

The initial backend suite passed the same bytecode with GMP, forced SML, and
a GMP-free VM on the interpreter and both JIT tiers. It checks independent
arithmetic fixtures, backend-equivalent counts, zero live GMP allocations,
bounded resource failures, and images restored between builds. Build probes
passed automatic fallback, explicit rejection, older headers, and modified
pinned artifacts. `make check JOBS=8` passed with the pinned GMP build,
including bootstrap and cross-host bytecode equality for 510 programs.

The first full host matrix caught a host-adapter name collision between the
new `intinf_power` stub and the packed-storage helper. The helper is renamed;
no deviation entries were changed for this failure. The rerun passed all
seven configurations with the existing explained host deviations. Its report
is preserved as `tests/out/intinf/m3/host-report.md`.

[M3 acceptance evidence](../../tests/intinf/gmp-integration.json) records the
source and transcript hashes, dependency provenance, bytecode counts, and
build-switch results. Final acceptance passed: `make check JOBS=8`, the full
host matrix, stack and register sanitizer suites (including deoptimization),
GC stress, heap header/barrier tests, Windows, and portability. The Windows,
Linux32, PowerPC and AArch64 VMs use the GMP-free path in this milestone;
GMP-enabled cross builds remain M5. `make check` includes 340 language tests,
139,218 Basis checks, and cross-host bytecode equality for 510 programs.

The dedicated sanitizer suite passed 76 bounded subprocesses across backends
and register tiers, with no live native allocations after returning calls.
Running the entire preserved list oracle with ASan and collection at every
allocation exceeded its 180-second timeout; that transcript remains recorded
as a timeout, not a sanitizer pass. The complete corpus then passed with a
collection interval of 101, and compact signed quotient/remainder, image,
limit and special-case tests passed with collection at every allocation.

Additional checks passed C99 builds with and without GMP, eleven option-bound
checks for each VM, eight dependency-configuration probes, and build switching
from pinned GMP to disabled and back to the identical pinned VM binary.
`git diff --check` and local roadmap links passed. Raw local evidence is under
`tests/out/intinf/m3`; remote CI has not been executed from this worktree.

## M4: runtime hardening and measured dispatch

Image format 12 adds requested-mode and reporting policy for emulated forks.
A reproduced failure showed a parent forced to SML resuming its child with
GMP; another showed an invalid inherited `RUNEVM_INTINF` default breaking the
child before its image could restore the parent's choice. Forks now inherit
policy, while saved-world restoration still selects from the current VM.
Native output observes the same option precedence. Neither path serializes
GMP objects or pointers.

The hardening harness rejects malformed primitive arguments and image policy
fields, including negative zero before division. A zero divisor raises `Div`
before any GMP allocation. Dedicated tests invoke the real allocator hooks
with injected `malloc` and `realloc` failures; both terminate with the runtime
limit diagnostic. Successful resize/shrink/zero-size calls leave no tracked
allocations. These tests and native fork checks are part of `make check`.

The operation/shape sweep found GMP faster for addition, multiplication and
bit operations at the first measured large sizes, but slower for a small
dividend divided by a much larger divisor (0.617x SML at 31/65 bits). Unit
and clearly smaller-dividend cases now return their direct SML answers; GMP
handles the remaining eligible large arithmetic. There is no measured case
for an extra arbitrary bit-count cutoff in the tested add/multiply/bit range.
The fallback's right shift works over indexed arithmetic digits and safely
saturates counts that cannot fit a machine int.

Initial measurements found a reproducible forced-SML compiler regression on
the signature workload. Profiling showed unnecessary initialization code:
Word and Word64 built powers of two with general power/multiply/divide
operations, retaining those kernels even for a program naming only signatures.
Their conversion constants now use exact shifts. Boundary and conversion
checks pass on both backends; a 50-pair rerun reduced the signature ratio to
1.0313 for SML versus M1 (GMP: 0.9559). Final measurements and acceptance
are recorded below. Earlier noisy timings and the reproduced failures remain
under `tests/out/intinf/m4`; they have not been relabelled as passes.

The final pre-acceptance run then reproduced a small-addition regression against
M2 (100 pairs each: GMP 1.0805 and 1.0845; SML 1.0582 and 1.0723).
The small-path bytecode still allocated temporary argument tuples. Binding the
two operands once lets Rune's existing worker transformation pass them directly;
no compiler or public interface change is needed. A separate 100-pair experiment
measured M4/M2 ratios of 0.8303/0.8406 for SML addition/multiplication and
0.8586/0.8695 for GMP. These are exploratory measurements; the full fixed corpus
and acceptance were rerun after integrating the change.


### M4 measured results

[The portable performance record](../../tests/intinf/gmp-performance.json)
retains the final commands, source/tool hashes, raw samples, counts, memory,
load and CPU affinity, conversion measurements, exploratory dispatch sweep,
and the earlier small-arithmetic regressions. The fixed corpus, expected
answers, iteration counts and 5% gate were unchanged. Arithmetic uses seven
alternating pairs; the separate small-kernel comparison uses 100 pairs.

| Workload | New SML / old list speedup | GMP / new SML speedup |
|---|---:|---:|
| small-add | 3.367 | 0.976 |
| small-mul | 4.170 | 1.028 |
| mul-512 | 2.314 | 4.946 |
| mul-4096 | 3.015 | 36.604 |
| mul-unbalanced | 1.582 | 4.038 |
| div-1024 | 43.245 | 4.321 |
| div-4096 | 59.812 | 9.983 |
| div-unbalanced | 29.241 | 5.663 |
| bits-4096 | 0.787 | 2.310 |
| convert-4096 | 1.870 | 1.000 |
| power-1024 | 11.096 | 36.134 |
| factorial-300 | 0.762 | 1.877 |

The SML multiplication/division geometric mean is **9.703x**; the GMP
large-arithmetic geometric mean is **5.555x**. Both exceed 2x. The SML bit
workload and factorial remain slower than the original list implementation;
formatting is still SML-owned and gains essentially nothing from selecting
GMP. These individual limitations are retained alongside the aggregates.
No Karatsuba implementation or crossover is claimed.

Compared to M2 in 100 paired runs, small-add/small-mul elapsed ratios are
0.8444/0.8593 with GMP selected and 0.8291/0.8678 with SML selected. The direct
argument calls remove approximately half the managed allocation in these
workloads: small-add falls from 144 MB to 72 MB, small-mul from 96 MB to 48 MB.
Counts are recorded separately from uninstrumented timings, including the
backend-dependent initialization work.

Compiler comparisons use 25 pairs after two warmup pairs, each revision's
own Basis, and hash-verified baseline artifacts. Every output matches its
reference. Ratios below mean current elapsed time divided by baseline time.

| Compiler workload | GMP / M1 | SML / M1 | GMP / M2 | SML / M2 |
|---|---:|---:|---:|---:|
| compile-hello | 0.9606 | 0.9410 | 0.9993 | 1.0294 (pooled) |
| compile-sigs | 1.0290 | 1.0492 | 0.9367 | 0.9575 |
| bootstrap | 1.0030 | 1.0255 | 1.0457 | 1.0169 |

The initial SML/M2 hello wall-time ratio was 1.0945 while its CPU-time ratio
was 0.9839. A prescribed 100-pair repeat measured 0.9999 wall time; pooling
all 125 pairs gives 1.0294. Both the repeat and pooled wall medians must pass;
CPU time is diagnostic and does not replace the wall-time gate. Original,
repeat and pooled evidence are retained. No reproducible small/compiler
regression above 5% remains in these measurements; this is evidence on the
recorded machine, not a timing guarantee on every host.

Conversion measurements use 50,000 roundtrips and seven pairs. The GMP
primitive imports, copies through power-one, exports and allocates its result;
the storage path unpacks and repacks with scratch allocation. These are
whole-boundary costs, not isolated import latency.

| Magnitude bits | GMP roundtrip microseconds | Storage roundtrip microseconds |
|---|---:|---:|
| 8 | 0.327 | 0.102 |
| 32 | 0.328 | 0.155 |
| 64 | 0.439 | 0.181 |
| 128 | 0.471 | 0.265 |
| 256 | 0.602 | 0.355 |
| 1024 | 1.552 | 0.885 |
| 4096 | 4.891 | 2.588 |
| 16384 | 24.129 | 12.266 |

### M4 acceptance

[The hardening record](../../tests/intinf/gmp-hardening.json) records source,
dependency and transcript hashes. All checks ran outside the syscall sandbox:

* `make check JOBS=8`: 343 language tests, 139,218 Basis checks (existing
  explained deviations retained), bootstrap, native/register/JIT checks,
  documentation and ISA checks, and identical bytecode for 513 programs
  across all seven compiler builds. Host builds of `runedoc` and `runeopt`
  also agree.
* `make matrix-quick JOBS=8`: Rune's Basis on Rune and all six host
  configurations; the report is retained at
  `tests/out/intinf/m4/host-report.md`. Existing documented host failures
  remain explained, not silently converted into passes.
* GMP ASan/UBSan stress: 76 bounded subprocesses, equal counts within each
  backend across register tiers, zero live GMP allocations after returning
  calls. The preserved full oracle uses GC interval 101; compact cases use
  interval 1, as established after M3's recorded interval-1 timeout.
* Hardening: 53 subprocesses including native fork policy, 35 with the
  GMP-free VM, and 47 through the sanitizer VM. The separate allocator
  harness passes success/accounting cases and predictable allocation and
  reallocation failures.
* Stack, register (including deoptimization) and native sanitizer suites;
  `make test-stress JOBS=8`; `make test-heap JOBS=8`;
  `make test-windows JOBS=2`; and `make test-portability JOBS=8` all pass.
  The cross-platform builds remain GMP-free here. GMP-enabled cross builds
  and release CPU provisioning belong to M5.
* `make docs`, documentation consistency, local roadmap links and
  `git diff --check` pass. No persistent GMP arithmetic objects were added.

Raw local evidence is under `tests/out/intinf/m4`. Remote CI has not run
from this worktree. The main checkout and collector draft remain untouched.


## M5: platform packages and release validation

Completed on 2026-10-14. The [release acceptance record](../../tests/intinf/gmp-release.json)
and [release measurements](../../tests/intinf/gmp-release-performance.json) retain
the final artifacts, dependency provenance, commands, samples and failures
followed by successful reruns. Remote CI remains unrun.

Each register target now configures and links its own checked GMP ABI. The
native, Windows64/32, Linux32, PowerPC64 and AArch64 dependencies are built from
the same pinned archive and run the upstream suites before installation.
Cross configuration is lazy per requested target, preserves exact flags and
artifact hashes, and relinks when the selection or inputs change. Physical
GMP-free builds retain the same primitive identities. Count comparisons
propagate forced SML into Windows through `WSLENV`.

Two release problems were found and retained:

* The optimized clang/PowerPC64 dependency failed upstream division. The
  [minimal case](../bugreport/gmp/ppc64-division/BUGREPORT.md) reduces the
  failure to a 256-bit numerator. The public mpz division passes that case;
  the internal upstream kernel does not. The default PowerPC package uses
  `--disable-assembly`, which passes the complete upstream suite and the
  retained probe. No source patch or extra test filter was used.
* Native fat assembly dispatch alone left Haswell-specific helpers in C.
  [The packaging regression](../bugreport/gmp/fat-package-target/BUGREPORT.md)
  produced a wrong shift and an unsupported instruction on older emulated
  CPUs. Fat packages now also use a generic target triple. The full
  independent corpus passes on baseline, Conroe, Opteron G1 and maximum
  x86-64 CPU models, across the interpreter and both JIT tiers, with equal
  counts. Linux32 additionally builds position-independent GMP objects so
  the PIE VM does not acquire text relocations.

Explicit build/host triples and a build-machine compiler also prevent WSL's
ability to execute Windows binaries from confusing configure's cross-build
detection. All upstream failures remain in the local evidence; a failed
upstream build is never installed as an accepted dependency.

Installations retain the register VM's source and transitive headers, exact
flags, binary/source hashes and a tested relinking script. Pinned builds also
retain GMP's source archive, header/static library, notices, provisioning
record and exact recipe. The installer checks those records before copying.
Both enabled and disabled staged installs have passed relocation, native
output, relinking and removal checks; altered pinned headers are rejected.
System builds retain explicitly unknown source/build provenance.

The cross-platform suite passed 557 bounded subprocesses, including the same
arithmetic bytecode, backend-specific counts, finite limits, real/emulated
forks, and 216 image producer/consumer combinations. Each combination tests
both stricter invocation and stricter saved limits. JIT checks run only on
architectures that implement those tiers. These checks establish functional
coverage under the recorded emulators, not native performance on every CPU.

### M5 measurements (2026-10-14)

The final package retains the fixed M1 inputs and iteration counts. Seven
alternating pairs measure an **8.9905x** geometric-mean SML improvement over
the original list implementation on the multiplication/division suite, and
**6.2623x** for GMP over the fallback on the large-arithmetic suite. Both
exceed their proposed 2x targets. These are measured results on the recorded
native machine, separate from the original targets.

| Workload | New SML / list speedup | GMP / new SML speedup |
|---|---:|---:|
| small-add | 3.0244 | 1.0533 |
| small-mul | 4.0462 | 0.8014 |
| mul-512 | 1.9963 | 3.6036 |
| mul-4096 | 2.8033 | 43.0507 |
| mul-unbalanced | 1.7841 | 4.7048 |
| div-1024 | 31.5414 | 4.3360 |
| div-4096 | 59.5133 | 26.5124 |
| div-unbalanced | 28.1776 | 5.6581 |
| bits-4096 | 0.9546 | 2.2754 |
| convert-4096 | 1.9519 | 1.0282 |
| power-1024 | 10.9288 | 41.9879 |
| factorial-300 | 0.8235 | 1.9888 |

The fallback bit-operation and factorial results remain visible even though
neither belongs to its multiplication/division gate. The seven-pair small
multiplication result triggers a larger direct-backend comparison below;
it is not dismissed by the passing aggregate.

One hundred paired small-arithmetic comparisons to M4, forcing the same
backend on both sides, give elapsed-time ratios 1.0099/0.9967 for GMP
addition/multiplication and 0.9909/0.9870 for SML. Compiler comparisons use
25 pairs after two warmup pairs, each revision's own Basis, verified baseline
artifacts, and matching output hashes. Ratios below are current elapsed time
divided by baseline time.

| Compiler workload | GMP / M1 | SML / M1 | GMP / M4 | SML / M4 |
|---|---:|---:|---:|---:|
| compile-hello | 1.0069 | 0.9852 | 0.9974 | 0.9986 |
| compile-sigs | 0.9505 | 1.0100 | 1.0470 | 1.0006 |
| bootstrap | 1.0285 | 1.0372 (pooled) | 0.9816 | 1.0096 (pooled) |

The initial SML bootstrap ratios were 1.0827 against M1 and 1.0572 against
M4. The prescribed 100-pair repeats gave 1.0292 and 0.9932; pooling all 125
pairs gives the table above. Both repeat and pooled medians must pass the
1.05 gate. Initial and repeat samples remain retained.

A direct comparison of the same final VM and bytecode, alternating forced
GMP and SML, resolves the earlier small-multiplication flag. One hundred
pairs give GMP/SML elapsed-time ratios **1.0057** for addition and **0.9983**
for multiplication. Twenty-five compiler pairs give **0.9983** for hello,
**0.9729** for signatures and **1.0004** for bootstrap. None exceeds 1.05.
No workload, iteration count, threshold or arithmetic implementation changed
between the initial measurements and these comparisons.

The final package's conversion measurements use the same 50,000 roundtrips
and seven pairs as M4. GMP includes import, copy through power-one, export
and result allocation; storage includes unpacking, scratch allocation and
repacking. These are complete boundary costs, not isolated import latency.

| Magnitude bits | GMP roundtrip microseconds | Storage roundtrip microseconds |
|---|---:|---:|
| 8 | 0.166 | 0.071 |
| 32 | 0.179 | 0.076 |
| 64 | 0.191 | 0.089 |
| 128 | 0.235 | 0.119 |
| 256 | 0.329 | 0.181 |
| 1024 | 0.858 | 0.485 |
| 4096 | 2.766 | 1.606 |
| 16384 | 10.942 | 6.360 |

Operation-specific dispatch thresholds remain as measured in M4. The release
record retains individual results, allocation counts, process memory, timing
samples and the limitations of the recorded machine; aggregate improvements
are not a speed guarantee for every operand or platform.

### M5 acceptance

All required local gates pass on the final pinned packages:

* `make check JOBS=8`: 343 language cases, 139,218 Basis checks, compiler
  bootstrap, documentation/ISA checks, register/JIT/native suites and
  identical bytecode for 513 programs across seven compiler builds.
  Host-built `runedoc` and `runeopt` outputs also agree.
* `make matrix-quick JOBS=8`: Rune and all six host configurations pass with
  their existing explained deviations. The initial run had one unexplained
  Rune `waitpid-without-it` exception. Four isolated rechecks and a full
  same-concurrency rerun passed, without changing tests or deviation ledgers.
  The initial failure's cause is not established; its report is retained.
* GMP backend and hardening checks under ASan/UBSan; stack, register and
  native sanitizer suites; `make test-stress JOBS=8`; and
  `make test-heap JOBS=8` all pass. GC stress retains the bounded M3/M4
  policy: the full original oracle at interval 101, compact cases at 1.
* `make test-windows JOBS=1` passes on all four VMs, including available
  register JIT tiers, runtime diagnostics, layout counts, images and the
  Windows Basis matrix. The first shared-directory attempt failed with
  empty diagnostics and wrong-bytecode errors. A dedicated-directory
  parallel rerun passed the four VMs but hit two WSL
  `UtilAcceptVsock: accept4 failed 110` launch errors in tier 2. The complete
  serial rerun passed without runtime or test changes. Both failed attempts
  remain recorded; the shared-directory failure's cause is not established.
* `make test-portability JOBS=8` passes for Linux32, big-endian PowerPC64
  and AArch64, including supported JIT tiers, count and image comparisons
  and all five stack/register Basis configurations. Existing explained
  platform deviations remain visible.
* All six pinned dependencies pass their upstream suites: 177 passes and
  one upstream `t-addaddmul` skip each, because these configurations do not
  provide `mpn_addaddmul_1msb0`. The separate retained division probe also
  passes on all six. The cross-backend suite passes 557 bounded subprocesses and 216
  image combinations with both limit orderings. Twelve older/current x86
  CPU-model and JIT combinations pass the independent arithmetic corpus.
* Enabled and disabled installations pass staging, relocation to a path
  containing spaces, compilation, native output, source relinking and
  removal. Altered pinned headers are rejected. Runtime sources, transitive
  headers, dependency sources/notices, options and hashes are retained.
* Generated Basis documentation is current; build, runtime, native,
  register-architecture and bytecode documentation describe the final
  configuration. Roadmap links, milestone consistency and whitespace pass.

The committed records index raw evidence under `tests/out/intinf/m5`,
including the original failures and successful repeats. Existing host Basis
limitations remain documented, and emulated architecture/CPU checks establish
functional coverage rather than native performance. Remote CI and external
publication have not run from this worktree and remain outstanding for a
release or pull request. The unrelated collector draft is unchanged by this work.


## Rebase onto origin/master

The implementation was first rebased onto `aeb6779788406ff25d7eebdff57f6b69c820712d`.
Its full check passed, but the host matrix found the existing upstream
`SysWord` literal-overloading issue. While validation ran, upstream supplied
the transparent host sealing fix and MLKit 4.7.25 integration. The branch and
comparison checkout were then advanced to
`3220230c1e026d9feb5af43f55c49e7917dd71fa`; the initial failure remains retained.
The original roadmap commit was already upstream. The pre-rebase branch is
retained as `gmp-before-master-rebase-20261014`; its sources and measured
binaries are also archived locally for paired comparisons.

This integrates the newer collector, debugger, test runner and MSYS2 build
support. `RuneBytes` now loads early through `lib/basis/library.build`;
`MANIFEST` is generated. Primitive tables and Basis documentation are
regenerated from the merged sources. Image format **14** combines upstream's
image changes with arithmetic limits and fork policy. Differential count
checks force SML even when the test runner is invoked directly; dedicated
IntInf tests exercise GMP separately.

The native UCRT64 build exposed a packaging bug: MinGW produced `runevm.exe`
while the provenance script tried to read `runevm`. The recorder and package
builder now resolve the executable suffix. Native MSYS2 bootstrap reproduces
both bytecode formats; both backends, a physical GMP-free build and the
relinked runtime pass the independent corpus. This uses a checked system GMP
installation and does not claim pinned-package provenance. The existing
upstream limitation of launching `/bin/sh` jobs from the native Windows test
runner remains; these checks run directly.

### Rebased validation, 2026-10-15

[The acceptance record](../../tests/intinf/gmp-rebase.json) indexes commands,
versions, source and binary hashes, failures and reruns. Raw evidence is under
`tests/out/intinf/rebase/final`. All required local correctness checks pass:

* `make check JOBS=4`: **14,336 passes and two existing native-interrupt skips**,
  including bootstrap, heap checks, generated documentation, ISA checks and
  engine equivalence. The report contains 14,338 test entries; skips are not
  counted as passes here.
* `make matrix-quick JOBS=4`: Rune and all six host configurations have no
  unexplained failures. Existing explained deviations remain, including the
  MLKit POSIX limitations. MLKit 4.7.25 was selected explicitly for this run.
* ASan/UBSan arithmetic, malformed-argument and allocation-failure tests;
  stack, register, both JIT tiers and native sanitizer suites; general stress;
  and GMP backend tests under both collectors pass. The low-pause check uses
  a 4 KiB nursery, cyclic stress and heap verification; the throughput check
  disables the nursery and verifies collections.
* `make test-windows JOBS=2`: all four VMs, supported JIT tiers, runtime and
  Basis cases, layout and image checks, terminal, debugger and kernel checks
  pass. Native MSYS2 checks described above pass separately.
* `make test-portability JOBS=4`: **3,478 passes**, including width, byte order,
  supported JIT tiers, counts and image transfers. The dedicated arithmetic
  cross-build suite passes **557 bounded subprocesses and 216 image
  combinations**. Dependency regression probes pass on all six targets;
  twelve x86 CPU-family/JIT combinations pass under emulation.
* GMP-enabled and GMP-free installation, relocation, native output, source
  relinking and removal pass. Restoring the enabled build reproduces its
  previously measured VM hash.

Remote CI and publication remain unrun. Emulated checks establish functional
portability, not native hardware performance. Native MSYS2 uses the installed
checked system GMP; pinned cross packages have separate evidence.

### Rebased performance review

[The performance record](../../tests/intinf/gmp-rebase-performance.json) retains
all individual results and paired samples. Historical speedups above remain
evidence of the earlier runtime. These measurements compare with the same
upstream revision, the preserved pre-rebase branch, and experimental constant
backend selection. Workloads retain their operands and iteration counts;
measurements run sequentially with CPU affinity. Initial flags are retained
alongside 100-pair repeats.

The fixed suites still exceed both large-arithmetic targets: SML is **9.85×**
faster than the saved list implementation on the multiplication/division
geometric mean, and GMP is **5.72×** faster than the new SML fallback on the
large-arithmetic geometric mean. The fixed small-integer suite improves over
upstream, and neither backend has a reproducible compiler regression above
5% against the same upstream revision:

| Compiler workload | GMP / upstream time | SML / upstream time |
|---|---:|---:|
| compile-hello | 1.0160 (pooled; repeat 1.0140) | 1.0240 |
| compile-sigs | 0.9846 | 1.0056 |
| bootstrap | 0.9977 | 1.0153 |

Ratios above one mean slower. The initial GMP hello ratio was 1.0716; the
100-pair repeat and pooled median both pass the 1.05 gate. Direct selection
between GMP and SML in the same VM and bytecode also passes that gate: ratios
are 0.9719/0.9939 for small addition/multiplication and
0.9887/0.9965/1.0132 for hello/signatures/bootstrap.

There are nevertheless real regressions. On the fixed suite, forced SML's
4096-bit bit operations are **15.0% slower** and factorial-300 **24.3% slower**
than upstream in 100-pair repeats (pooled medians: 16.6% and 23.7%). GMP improves
those two workloads. The broader operand-shape sweep also finds losses with
GMP, especially around the small/large boundary. Its initial run used different
library path spellings; every case with a ratio above 1.05 was rebuilt with
`--lib lib` on both sides and repeated for 100 pairs. Those corrected repeats,
not a pool with the initial builds, determine the boundary findings below.

| Operation and operand bits | GMP / upstream time | SML / upstream time |
|---|---:|---:|
| add 63/63 | 3.202 | 3.950 |
| add 128/128 | 3.638 | 4.827 |
| add 512/512 | 1.666 | 2.353 |
| add 4096/4096 | 0.869 | 1.624 |
| mul 31/33 | 1.943 | 2.339 |
| mul 63/63 | 1.263 | 1.754 |
| mul 128/128 | 0.829 | 1.335 |
| div 128/256 | 3.016 | 4.165 |
| bits 63/63 | 1.698 | 2.629 |
| bits 128/128 | 2.196 | 3.256 |
| bits 512/512 | 0.988 | 1.551 |
| bits 4096/4096 | 0.492 | 1.111 |

The 128/256-bit division case returns a zero quotient. Its timed loop includes
large/small operand preparation and the early return; it does not exercise
normalized long division. The fixed 18/12-bit small-add and small-multiply
workloads remain faster than upstream. The boundary regressions were missing
from those two acceptance workloads, which is why the expanded cases matter.

For the 128-bit addition workload, GMP executes 31.1 million VM instructions
and allocates 9.7 MB in Rune's heap, compared with upstream's 11.0 million
instructions and 16.7 MB. SML executes 59.5 million instructions and allocates
27.6 MB. These counters exclude GMP's native allocations and work inside C;
they show that reduced Rune heap allocation alone does not guarantee speed.

The pre-rebase comparison answers a different question. It includes the new
collector, compiler and other upstream changes. GMP's 1024-bit division,
4096-bit bit operations and power workload repeat at roughly 5.1%, 5.9% and
5.1% slower than the preserved runtime. Their cause has not been isolated.
Compiler hello is about 31% slower and bootstrap about 48% slower for both
backends in that comparison; each revision compiles its own input library
and compiler sources, and the compiler has grown. Those figures must not be
attributed to IntInf. The same-upstream comparisons above control for that
growth. An initial 22.8% SML unbalanced-division flag falls to 2.2% on repeat;
it is not a reproducible 5% regression.

### Costs of the shared design

The constant-selection experiment keeps packed values, normalization, limits
and GMP import/export. Both specialized copies pass the independent 1,154
current and 1,154 oracle checks, and disassembly confirms that capability
queries disappear. Compiler controls compile the same normal input library
and reproduce its output hashes. They retain the cost of parsing fallback
definitions; they do not measure persistent GMP objects.

Two boundary controls use the same source and normalized paths as the
corrected sweep, with 100 pairs each. Normal GMP selection divided by
constant-GMP time is **0.9943** for add-128/128 and **0.9663** for mul-31/33.
Removing runtime selection and unused fallback code therefore does not fix
either large regression. Both copies still use the shared representation
and arithmetic paths.

On the fixed arithmetic suite, normal GMP selection takes **6.5% longer**
than constant-GMP selection for div-1024 in the 100-pair repeat. Other initial
slowdown flags fall below 5% on repeat. Conversely, normal small-add is
about **10.3% faster** than the constant-GMP copy. All compiler controls are
within 5% after repeating the initial SML hello flag (repeat 1.0102, pooled
1.0021). The full record includes improvements as well as slowdowns.

Small arithmetic avoids capability queries on its hot path. For example,
normal and GMP-specialized small-add runs differ by only nine instructions
and one startup allocation, despite different code sizes and timings.
Changing selection also changes code layout, so the measured timing
difference cannot all be charged to the predicate. Removing the unused
backend shrinks the compiler bytecode by about 0.49% for GMP specialization
and 0.084% for SML specialization.

The bounded machine-`Int` control runs small addition **3.34×** and
multiplication **3.79×** faster than current IntInf. These workloads allocate
about 72 MB/4.5 million objects and 48 MB/3 million objects with IntInf,
respectively; the corresponding Int workloads allocate only about 2.7 KiB.
This measures remaining representation and checking costs on operands that
fit `Int`; it is neither an IntInf regression nor an equivalent arbitrary
precision implementation.

The final-package conversion experiment measures complete import/copy-through-
power-one/export and result allocation, not isolated import latency:

| Magnitude bits | GMP roundtrip microseconds | Storage roundtrip microseconds |
|---|---:|---:|
| 64 | 0.229 | 0.098 |
| 4096 | 4.151 | 2.123 |
| 16384 | 15.547 | 8.294 |

Nontrivial GMP calls in this design import operands and export results;
their exact costs depend on the operation and its sizes. SML instead unpacks
immutable bytes into scratch limbs and repacks the result. The old list
implementation operated directly on stored limbs without those conversions.
Normalization can also raise and catch an internal machine overflow
for values just outside the small range. These source observations identify
work to investigate; the timings do not separately assign a percentage to
each cost. The dispatch workloads include operand perturbations using small
additions, so their names do not describe isolated primitive latency.

### Performance acceptance still open

The fixed M1 performance gates pass, but the expanded small-arithmetic
no-regression goal is not met. M4 performance acceptance is therefore open
again; the successful M5 correctness evidence remains valid. Keeping an SML
fallback is not by itself an explanation for the losses: both modes share
the packed representation, and constant-selection controls retain its costs.

The next performance work depends on this recorded baseline. Deliverables
are improvements to boundary arithmetic and SML bitwise/factorial paths,
with individual timing and allocation comparisons. Candidate work includes
avoiding exception-driven normalization, specialized large/small arithmetic,
and reducing repeated unpacking or import/export where the ownership contract
allows it. Completion requires the original fixed suites plus the expanded
boundary cases to meet the unchanged 5% regression threshold, while semantic,
image, budget and engine-equivalence checks continue to pass. Retain the
fallback and shared immutable values; a different persistent native
representation needs a separate design and measurement, not an inference
from these controls.

### Follow-up optimization: validated locally

This work starts from `f729aa6d`, with its sources, compiler and VM retained
under `tests/out/intinf/optimization/baseline-tree`. It keeps the canonical
small/signed-byte representation and both independent arithmetic backends.
The changes remove redundant result normalization, use explicit
signed-boundary checks, update private byte copies for large/small addition,
and reuse scratch digits in fallback arithmetic. Small scratch results can
return directly without an intermediate packed string; overflowing machine
products convert directly to digits. No runtime primitive or image layout
change is needed.

`bin/rune-measure intinf-paths` compiles the exact retained workload sources
with normalized library paths, verifies expected answers, and compares both
backends with the retained bytecodes. Every exploratory iteration is kept;
its short measurements guided implementation and are not final acceptance.
The final evidence includes paired performance measurements, regression checks,
independent arithmetic and boundary tests, host-library validation, bootstrap
and the full required local checks. The performance gate above remains unchanged.

The implementation keeps `S of limb | B of bool * string`; it changes how
arithmetic reaches that representation. Known large results avoid another
small-range test. Small scratch results become `S` directly, without packing
and decoding a temporary string. Large/small addition and positive OR/XOR
copy bytes in bulk and visit the changing low bytes. The SML kernels reuse
private scratch arrays, handle carry with comparisons where possible, and
scale by a single digit without the general multiplication loop. Right shifts
round negative results from the discarded bits; byte-aligned left shifts copy
in bulk. Exact result-budget checks precede immutable result allocation.

The promoted multiplication path retains its boxed input arguments until
overflow and orders their magnitudes with a single tail swap. Besides putting
the shorter operand in the outer multiplication loop, this keeps the cold
routine separate: a measured prototype had inlined it into `mulI`, increasing
the hot function's register frame from 10 slots to 18 and slowing ordinary
small multiplication. The adopted form restores 10 slots. A separate shared
addition/subtraction/multiplication promotion experiment moved the cost into
addition and was rejected. A constant-30-bit configuration did not consistently
improve SML timings, so the portable width selection remains.

The tests add signed carry/borrow, operand ordering, minimum machine integers,
unchanged input values, exact and inexact shifts, and non-byte-aligned 65-bit
budget boundaries. An expanded deterministic corpus compares 622 pairs, up to
4096 bits, against Python answers and the retained list oracle: 3,114 checks
per implementation in each run. The focused and full local correctness checks
pass; the remaining performance gaps are listed below.

The compiler also reuses literal limits in a bounded table keyed by signedness
and widths 0 through 64. Each literal is still checked, other widths use the
ordinary arithmetic, and empty wide strings do not calculate unused limits.
This removes repeated `IntInf` work in the caller. The cached compiler agrees
byte for byte with its host-built reference and reproduces itself under both
backends. Mixed-width tests accept the endpoints and reject subsequent
out-of-range literals after the cache has been populated.

#### Follow-up measurements

The final compiler reproduced **all 56 measured arithmetic and oracle
bytecodes exactly**, using the same source paths, and the VM binary and
arithmetic library hash were unchanged. Those arithmetic samples are retained;
compiler timings were repeated with the new compiler. A separate bootstrap
check uses the build's `bin/../lib` spelling, while compiler benchmarks use
`lib` consistently. Confusing those debug paths caused an extra harness
assertion to fail; matching-path self-bootstrap passes in both modes.

The fixed large suites measure **11.48× SML over the saved list implementation**
and **6.91× GMP over the optimized SML fallback**, as geometric means. Direct
paired comparisons with `f729aa6d` show:

| Workload | GMP speedup | SML speedup |
|---|---:|---:|
| addition, 63/63 bits | 2.27× | 3.25× |
| addition, 128/128 bits | 2.96× | 4.03× |
| multiplication, 31/33 bits | 1.78× | 2.22× |
| bit operations, 128/128 bits | 2.56× | 2.97× |
| fixed bit operations, 4096 bits | 1.43× | 2.47× |
| factorial-300 | 1.45× | 1.83× |

For 128-bit addition, GMP's VM instruction count falls from 31.1 million to
8.0 million, and SML's from 59.5 million to 17.0 million. Rune heap allocation
falls from 9.7 to 8.6 MB and from 27.6 to 17.0 MB, respectively. GMP's native
allocations remain separately reported. The fixed small-arithmetic suite has
no repeat-confirmed regression above 5% against `f729aa6d`.

Compiler elapsed-time ratios, above one meaning slower, are:

| Workload | GMP / f729 | SML / f729 | GMP / upstream | SML / upstream |
|---|---:|---:|---:|---:|
| compile-hello | 1.0429 | 0.9344 | 1.0194 | 0.9980 |
| compile-sigs | 1.0279 | 1.0216 | 1.0421 | 1.0282 |
| bootstrap | 1.0401 | 1.0008 | 1.0134 | 1.0400 |

The flagged signature comparisons received 100-pair repeats; the table uses
pooled medians for those cases. Both repeat and pooled medians pass 1.05.
The earlier SML signatures regression of 6.6% motivated the literal-limit
cache and remains recorded with its superseded compiler.

The broader no-regression goal is still open. Remaining time ratios against
upstream `3220230c`, with repeated cases pooled, are:

| Workload | GMP / upstream | SML / upstream |
|---|---:|---:|
| addition, 63/63 bits | 1.3740 | 1.3621 |
| addition, 128/128 bits | 1.2364 | 1.2442 |
| multiplication, 31/33 bits | 1.1493 | 1.1113 |
| bit operations, 128/128 bits | 0.8374 | 1.0733 |

These losses are much smaller than the preceding implementation's, but they
still exceed the unchanged expanded gate. M4 remains open for that work;
the aggregate gains do not erase individual regressions.

#### Follow-up acceptance

[The acceptance record](../../tests/intinf/gmp-optimization.json) and
[performance record](../../tests/intinf/gmp-optimization-performance.json)
retain commands, versions, source and binary hashes, raw samples, repeat
results and rejected experiments. Raw local evidence is under
`tests/out/intinf/optimization/final4`; earlier candidates remain alongside it.

* `make check JOBS=4`: **14,432 passes and two existing native-interrupt skips**
  across 14,434 entries. Bootstrap, generated documentation, ISA checks,
  engine equivalence, heap checks and the new accepted/rejected literal probes
  pass.
* `make matrix-quick JOBS=4`: Rune and all six host configurations have
  **zero unexplained failures**. Existing host deviations and unavailable
  sections remain visible. The MLKit probe and filesystem diagnostics match
  existing limitations; the deviation ledger was not changed.
* ASan/UBSan backend and hardening suites, standalone stack sanitizer checks,
  register interpreter/JIT/deoptimization sanitizer checks, native sanitizer
  checks, both collector configurations and general GC stress pass.
  Backend suites run **92 bounded subprocesses**, and hardening runs **47**.
* Cross-build arithmetic, limits, fork and restore checks pass **557 bounded
  subprocesses and 216 image combinations**, including physical GMP-free VMs.
* `make test-windows JOBS=2` passes on all four VMs: **288 supported language
  cases and 30 runtime cases** per run, available JIT tiers, layout and image
  checks, the Windows Basis matrix, terminal, debugger and kernel checks.
* `make test-portability JOBS=4` passes **3,502 checks**, including supported
  widths, byte orders, JIT modes, counts and image transfers.

An initial limit-test assertion mistook the function name `mulOverflow` in a
stack trace for an uncaught `Overflow` exception. Its diagnostic and exit code
were correct; the assertion now identifies the exception diagnostic precisely.
The initial failure and successful rerun are retained. The bootstrap-path
assertion and superseded performance candidates are also preserved.

No C arithmetic, primitive identity or image layout changed. The native VM's
machine-code section is identical to the preceding implementation's; its
generated revision header differs. Emulated checks establish functional
portability, not native hardware timings. Remote CI and publication remain
unrun, and expanded M4 performance acceptance remains open.

### CI download follow-up (2026-10-15)

A reported GitHub Actions run stopped before compilation because the sole
download from `gmplib.org` timed out (curl exit 28). The provisioning recipe
now tries the GNU release site first and `gmplib.org` second, with bounded
transient-error retries. Both sites are listed on [GMP's download page](https://gmplib.org/#DOWNLOAD).
GMP 6.3.0 and its SHA-256 pin are unchanged. A source checksum mismatch is
fatal on either site; verified files enter the cache by atomic rename, and
separate partial files keep concurrent cross-build downloads independent.
The build record identifies a fresh download's URL or verified cache reuse.
CI retains command, download, configure, build and test logs on failure,
with the last 4 KiB of failed-command output also shown in the console.

[The downloader regression suite](../../tests/intinf/download.py), included
in `make test-intinf-dependency` and `make check`, passes 12 checks covering
timeouts, fallback, checksum rejection, partial files, interruption, cache
reuse and command diagnostics. A live GNU download returned the expected
2,094,196-byte archive and pinned hash. A bounded loopback HTTP check observed
three failed requests followed by a successful fallback using the real curl
executable. Rebuilding the native fat GMP package passed 177 upstream tests
with one existing skip; a repeated build verified and reused its cache.
Local evidence is retained under `tests/out/intinf/download-*`.

Full acceptance of the download and REPL follow-ups passes with
`make check GMP=yes GMP_PREFIX=build/deps/gmp/native JOBS=8`: **14,432 passes
and two existing native-interrupt skips**, across 14,434 entries in 1,381.3
seconds. The report is `tests/out/r/20261015-212059-3415469`; a copy is retained
under `tests/out/intinf/ci-repl-followup`. The preceding run was deliberately
interrupted to incorporate the reported REPL bug, after 937 passes and two
skips; it is retained as incomplete evidence. Remote CI with the download
fix still needs a rerun after publication.

### REPL value-printing follow-up (2026-10-15)

The packed representation exposed a missing printer regression: the REPL
selected datatype constructors before a structure's `toString`, showing
`S 3472347895` and `B (false, "...")` for `IntInf` values. Printer selection
now prefers a visible formatter with the matching argument and result types.
It searches aliases independently of the shortest displayed type name, so a
top-level abbreviation or shadowed `IntInf`/`LargeInt` structure does not hide
a formatter available through another alias. Installed custom printers keep
priority. Overloading metadata preserves numeric styling and word prefixes
through structure aliases.

[The transcript regression](../../tests/repl/intinf.in) covers the reported
small values and large product, zero, negative packed values, `LargeInt`,
nested containers, type aliases, shadowing, matching and mismatched datatype
formatters, word aliases and an installed custom printer. Its expected large
product was independently checked with Python integer arithmetic; the entire
expected transcript was reviewed.

* The transcript passes all **nine combinations** of GMP, forced SML and a
  GMP-free VM with the interpreter and both JIT tiers.
* `make test-repl` passes **9/9** entries (four REPL configurations and runner
  canaries); `make test-repl-protocol` passes **12/12**. An initial concurrent
  invocation failed during protocol-runner startup; its separate rerun and
  the full acceptance run pass. Both transcripts are retained.
* An engine-protocol probe verifies decimal values, numeric HTML styling and
  empty scalar children after the original structure names are shadowed.
* The full acceptance run recorded above passes **14,432 checks with two
  existing skips**, including the new transcript in every REPL configuration.

Focused evidence is under `tests/out/intinf/repl-printer`; suite logs and
preserved acceptance reports are under `tests/out/intinf/ci-repl-followup`
and `tests/out/intinf/repl-*.log`. Existing REPL sessions must be restarted
with the rebuilt image to use the new printer.

### Fast decimal formatting follow-up (2026-10-16)

Repeated squaring exposed a separate bottleneck: decimal formatting always
used SML, repeatedly dividing into nine-digit chunks and allocating a new
quotient array each time. At 50,000 digits this dominated the REPL entry.

The generated `intinf_decimal` primitive now converts a canonical unsigned
magnitude with GMP's documented `mpz_get_str` API. Its temporary integer and
text buffer use the tracked allocation hooks. The native text is copied into
a Rune string and freed before returning; no borrowed Rune pointer is read
after the managed allocation. SML retains backend selection and the `~` sign.
The buffer is released with its documented `strlen(text)+1` allocation size
([GMP conversion contract](https://gmplib.org/manual/Converting-Integers)).
Both backends check the magnitude budget when formatting a large value,
including under a stricter restored limit. The SML formatter now divides one
private scratch array in place. Public values remain immutable and all digits
are retained.

The primitive is present in GMP-enabled and GMP-free builds, with the same
identity and fingerprint. Adding it changes the fingerprint from the preceding
build, so bytecode, compiler and REPL images were rebuilt together. The public
`INT_INF` interface, `LargeInt` sharing, equality and scanning rules are unchanged.

#### Measured performance

[The measurement record](../../tests/intinf/gmp-decimal.json) retains all five
alternating process pairs, source and binary hashes, commands and acceptance
results. [The workload](../../tests/intinf/decimal-workload.sml) measures
`(2^83047-1)^2`, whose complete 50,000-digit output was independently checked
with Python integers. Each phase has a warm-up and a collection before timing;
the console REPL comparison evaluates three identical squares per process.
Results below are medians against `7a324e2b` on this machine.

| Measurement | Before | After |
|---|---:|---:|
| GMP-backed decimal conversion | 564.17 ms | 1.35 ms |
| Whole GMP-backed REPL entry, including compilation and echo | 607.0 ms | 13.8 ms |
| SML decimal conversion | 532.89 ms | 545.74 ms |
| Managed allocation per conversion, GMP selected | 124,158,424 bytes | 50,088 bytes |
| Managed allocation per conversion, SML selected | 124,158,424 bytes | 905,448 bytes |

Decimal conversion is about **418× faster with GMP**, and the complete REPL
entry about **44× faster**. SML conversion time is similar; its temporary
managed allocation falls from about 118 MiB to 0.86 MiB. Managed allocation
figures exclude GMP buffers and are not peak-process-memory measurements.
The separate multiplication and layout measurements are retained in the
record. This follow-up measures formatting at this input size; the expanded
arithmetic performance gate remains as recorded above.

The REPL output was captured through a pipe, so terminal-emulator rendering
is additional. A separate check using the ordinary `bin/rune-repl` wrapper
and default backend selection printed every digit in 14.8–17.8 ms per entry.
Raw evidence is retained under `tests/out/intinf/decimal`, including the
preceding VM, compiler, REPL image and bytecode under `before/`, and the final
paired samples under `final-paired/`.

#### Acceptance

* `make check JOBS=8`: **14,472 passes and two existing native-interrupt skips**
  across 14,474 entries. Bootstrap, generated documentation, ISA, heap and
  engine-equivalence checks pass.
* `make matrix-quick JOBS=8`: Rune and all six host configurations have **zero
  unexplained failures**. Existing deviations, absent sections and unavailable
  checks remain visible; the deviation ledger was not changed. The current
  MLton and MLKit IntInf suites each pass **4,884 checks**.
* The new decimal fixture passes nine backend/tier combinations with a
  collection at every allocation. ASan/UBSan and both collector configurations
  each pass **107 bounded backend subprocesses**; sanitizer hardening passes
  **57 subprocesses**, including malformed magnitudes, output-buffer limits
  and stricter restored formatting limits.
* Stack and register sanitizer suites pass **364 cases** per configuration;
  native-output sanitizers pass **363 cases with one expected skip**. General
  GC stress passes.
* Cross-platform arithmetic, formatting, limits and restoration pass **557
  bounded subprocesses and 216 image combinations**, including GMP-free VMs.
* Windows passes on all four VMs: **289 language and 30 runtime cases** per
  run, available JIT tiers, layout, images, Basis, terminal, debugger and kernel.
* Portability passes **3,514 checks**, covering supported widths, byte orders,
  JIT modes, counts and image transfers.

Acceptance logs and preserved reports are under
`tests/out/intinf/decimal/validation`. Remote CI and publication remain unrun.

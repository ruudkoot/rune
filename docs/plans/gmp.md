# Roadmap: GMP-backed IntInf with an efficient SML fallback

Give the register VM GMP arithmetic, keep the same bytecode runnable without
GMP, and replace the current SML implementation with a substantially faster
one. The SML implementation remains useful in its own right: it supplies the
stack VM and `runeopt`, runs on host compilers, and provides an independent
check on GMP results.

Written on 2026-10-06 against `ca87fa07d239a072cff24bac03ce72b74ff93a7a`.
The owner approved the design below, including runtime backend selection,
representation changes, finite default limits, and pinned GMP release builds.
This document completes the design milestone only. No GMP integration,
replacement arithmetic, or performance measurement is claimed here.

## Status and requirements

| Milestone | Depends on | State |
|---|---|---|
| M0: record the design | the original brief and owner's decisions | done 2026-10-06; delivery evidence below |
| M1: establish correctness and performance baselines | M0 | planned |
| M2: replace the SML representation and kernels | M1 | planned |
| M3: add GMP behind the shared interface | M2 | planned |
| M4: harden runtime integration and tune dispatch | M3 | planned |
| M5: complete portability and release validation | M4 | planned |

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

## Where we are

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
  dependencies, deliverables, and a completion gate, M1-M5 are marked planned,
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

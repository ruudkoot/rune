# event-lazy provenance

### Algorithm and workload

Simulate the source thirteen-wire circuit with timed three-state NAND events.
Merge the two periodic input clocks, process pending events in time order,
discard unchanged signals, update persistent state lists and schedule dependent
NAND outputs three simulated time units later. NAND results capture the state
snapshot at scheduling time. Stable merges process existing pending events before
new events at the same time; sorting preserves dependency order for equal times.

The source simulator returns changed events. A second source pass, findLastState,
reapplies those changes to an initial state for display. Retain both update passes;
do not replace them with the simulator's internal final state or a mutable-array
simulation. The independent heap-based model is only a correctness oracle.

### History, provenance and related workloads

Source [nofib spectral/hartel/event](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/hartel/event), pinned at
b7391df4540ac8b11b35e1b2e2c15819b5171798. No individual author or separate notice is
stated in Main.hs; the collection name alone is insufficient program attribution.
Preserve the complete generated Haskell module, Makefile and fixtures under
event-lazy/upstream/event, with the parent Fast2haskell.hs compatibility shim.
This is a timed event-queue simulator, distinct from the stream multiplier and
other circsim topologies/consumers. Names -lazy/-strict identify finite-state
policies, not exact duplicates of those programs.

### Translation and evaluation decisions

-lazy memoizes finite state/dependency list heads and spines. -strict evaluates
those finite lists eagerly when their root is requested. Both preserve lazy
infinite clock streams, pending-event streams, event values and control roots.
A state update's outer delay keeps unused state unforced at the horizon cutoff.
Persistent prefix copying, dependency construction, duplicate suppression,
stable mergesort and function-valued gate definitions remain.

Check time >= horizon before forcing an event's wire/value or previous state.
Preserve NAND's three-state pattern order: a low left input can yield high
without demanding the right input. The strict finite-state variant may evaluate
more state fields but does not turn event/control streams into infinite eager
lists. Retain the source reconstructed output event and its shared field values.

Fast2haskell's pinned miraseq is a no-op implemented through seq_const, despite
the strict terminology in generated fold helpers. Do not translate that stub as
an actual strict accumulator operation. The lazy dependency fold preserves its
behavior; the strict finite-list policy is a separately named port choice.
Global initial clock/dependency/state values retain source sharing across
repetitions and repeated Benchmark.run calls; simulation state updates remain
fresh persistent values. Every numeric profile value fits signed 31-bit integers.
No floating-point or OS-clock dependency is required.

### Inputs and exact result validation

| Profile | Repetitions | Exclusive event horizon |
|---|---:|---:|
| Smoke | 1 | 200 |
| Normal | 100 | 100000 |
| Large | 100 | 500000 |

Normal and large retain original parameters. Smoke reduces FAST's hundred runs
at horizon ten thousand to one run at horizon two hundred. These are deterministic
simulated-time bounds, not wall-clock search limits. The two clocks and thirteen
initial unknown states are the original fixed input. Wire two remains unused.

Validate every thirteen-symbol state and trailing newline exactly; the selected
profiles yield HHxLLHHLLHHLH. Return repetitions, checked characters and final
state instead of source repeated stdout. Input argument lookup is outside the
repetition loop; the event computation and both update passes remain inside it.
All checks are exact, with no numerical tolerance. Full SML large repetitions
remain unrecorded unless explicitly listed in validation.

### Correctness and runtime observations

Original GHC 9.4.7 matches all supplied FAST/NORM/SLOW fixtures. Export-only
observers record complete states, changed-event traces at twelve boundary
horizons and the dependency table. An independent stable-priority-queue model
agrees with every observed state/trace, including startup, equal timestamps and
exclusive cutoffs. The port matches those traces and the full normal profile.

The 72-check target also covers the NAND table/short circuit, cutoff demand,
persistent states, overwritten lazy fields, strict finite-state behavior,
unneeded initial states, gate callbacks, cached clocks with fresh simulation
state and wrong-result rejection. Recorded native/engine outcomes are separate
from the private development pilots.

### Literature and diagnostic questions

[Hartel and Langendoen, Benchmarking implementations of lazy functional languages](https://doi.org/10.1145/165180.165230)
(1993) supplies collection context for translated workloads. It does not establish
individual authorship of this module. The pinned program defines this circuit,
its stable event ordering and compatibility-shim behavior.

Investigate queue/list allocation, persistent updates, dependency sharing,
finite-state strictness, gate callbacks and retained clock prefixes. These are
source-based diagnostic hypotheses. Original/model traces establish selected
behavior; counts/timings alone do not identify compiler or collector causes.
Fresh and repeated execution retain the recorded sharing/measurement modes.

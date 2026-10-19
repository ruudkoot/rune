# Mandel workloads on legacy64 SML/NJ

The canonical runs account for all 168 selected smoke/normal cases: 162 pass,
five reject incorrect results and one raises a runtime Domain error. Every
failure is on managed SML/NJ 110.99.9 64-bit. All Rune engines pass both
optimization levels, and the other five native hosts pass every profile.

| Benchmark/profile | Canonical legacy64 outcome |
|---|---|
| mandel-lazy normal | Incorrect metadata/count/digest result |
| mandel-strict normal | Incorrect metadata/count/digest result |
| mandel2-lazy smoke/normal | Incorrect complete tree rows |
| mandel2-strict smoke | Incorrect complete tree rows |
| mandel2-strict normal | Runtime Domain error |

The historical orbit variants pass both profiles on this host. A passing smoke
sample must not be presented as evidence of normal-profile correctness. The
measurement adapter independently rejects mandel2-lazy's incorrect smoke
precheck; that configuration supplies no fresh timing sample in that run.
[Orbit coverage](../../../../rune-benchmark-results/m3-mandel/coverage.tsv) and
[tree coverage](../../../../rune-benchmark-results/m3-mandel2/coverage.tsv) retain every case and category.

Twenty-six orbit and 132 tree semantic/negative checks run on all ten
configurations twice, with Rune levels O0/O2 and native host defaults. Only
legacy64 fails: two orbit checks and three tree checks per pass. The particular
tree failures move between contexts. Its scalar binary32 bit tests and demand
checks pass. Other configurations pass every check. Complete level logs retain
exceptions and outcomes rather than suppressing them.

The six failing canonical contexts were replayed with unchanged sources,
inputs and working directories. All six pass with @SMLalloc=64m. Default
replays give four incorrect results, one Domain error and one pass: the lazy
tree smoke replay passes although its canonical run fails. Replay command,
input/source identities, working directory, limits and outputs are retained in
[orbit diagnostics](../../../../rune-benchmark-results/m3-mandel/host-diagnostics/canonical-legacy-replays.json)
and [tree diagnostics](../../../../rune-benchmark-results/m3-mandel2/host-diagnostics/canonical-legacy-replays.json).
The parent watchdog includes 15 seconds of launch overhead; these runs are
supplementary diagnostics and supply no accepted timing samples.

Earlier tree probes show the same nursery sensitivity, with diagnostic output
moving the first mismatch. One expects a uniform colour-2 leaf at bounds
(0,9)..(4,12) but receives an NS node. Source snapshots distinguish the earlier
point-binding context from the later module parameter introduced for demand
tests. Both default contexts fail; the parameterization was not a workaround.

These observations are consistent with existing
[legacy GC reports](../../../docs/bugreport/smlnj/README.md). They do not isolate
the first corrupt operation or establish a new minimized compiler bug. No
current upstream issue status is inferred. The kernels, expected values and
default settings remain unchanged; all failures stay visible and cannot
contribute accepted measurements.

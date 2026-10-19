# gg-lazy provenance

Graph mode: activity. Finite numeric evaluation: lazy.

## Algorithm and workload

Parse supplied GRIP runtime logs, collect processor metadata and timing records,
insert records in bucket order, gather activity or spark counters and generate
PostScript graphs. The activity, spark-activity and spark-pool algorithms have
separate benchmark names; each has lazy and strict finite numeric policies.

## History, authorship, revision and variants

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/gg.
The gg.1 manual, dated August 13, 1992, explicitly credits Iain Checkland,
University of York. Retain all nine original modules, manual, report templates,
input/output fixtures, example files and orchestration scripts under gg-lazy/
upstream. No separate individual redistribution notice is stated in these files;
do not infer a grant from another benchmark.

The source report script invokes three computations: -A activity, -S spark
activity and -P spark pool. The scripts in the root and example directories are
byte-identical. Their supplementary exclusions identify report orchestration,
LaTeX/dvips dependencies and temporary-file removal, while the three actual
graph computations are imported separately. The old scripts are retained as
provenance and are not used as suite adapters.

GRIP itself is a parallel graph-reduction machine, but gg is a sequential
postprocessor of existing data. The benchmark neither runs a parallel program
nor requires a GRIP runtime. Supplied traces have no separate dataset authorship
or notice; processor names/times remain unchanged.

The extra gg.stdin-2.Z is a compressed historical trace. Preserve its pinned
compressed identity and a decoded auxiliary fixture. The recorded gzip -cd
adaptation yields 133193 bytes, independently checked against all three source
graph modes. The compressed file is an explicitly reviewed source-data exception
to executable-artifact scans, never a generic binary exemption.

## Portable translation and evaluation

Use SML97 for parsing, insertion, accumulation, plotting, validation and hashing.
Input character lists are read once, then parsed for each interpretation.
Preserve the positional-power strToInt definition, source line splitting,
list insertion rather than a replacement sort, record equality/order behavior,
grouping and recursive outline transposition.

All source counters use explicit IntInf payloads; the recorded profiles stay
within the source integer range. This removes dependence on a host's default
int width without introducing modular changes. Lazy payloads defer unused
numeric fields; strict finite payloads evaluate them. Control streams and the
paired trace/final-state results remain memoized in both policies.

Retain the source's structural equality check before its bucket-order test.
Equal buckets retain insertion order. Activity/spark gathering retains zero
buckets and the source closing sample. Pool accumulation preserves its distinct
bucket sharing, post-update levels and final closing trace. Outline conversion
uses the original recursive transposition and zip structure.

Default filters do not inspect an ignored processor value. Constant PostScript
prefixes, boxes and title can be produced before unrelated input. Processor
configuration, axes, legend percentages and curves retain their source demand
order. The final aggregate is shared with trace generation rather than recomputed.

Percentage and tick labels use the source Float32 arithmetic and custom
printFloat function. Bare scale/moveto operands and centimetre conversion use
the source's defaulted Double arithmetic. Record those widths separately.
The finite binary32 helper handles the selected label domain; it is not a
general floating-point library.

Preserve historical source behavior instead of repairing graphs. FAST and NORM
have only one processor-header entry, so length(pes)-1 is zero and activity
scaling emits positive Infinity. The reference category is checked explicitly.
The larger supplementary trace also exposes the source's finite configuration
position list, which omits a final processor label at sixteen entries.
Those are documented source results.

GEN17 replaces GHC shortest Double spelling only for bare numeric operands.
All commands, literal text, colors, integer coordinates, labels, ordering and
line endings must match exactly. Integer operands remain exact; finite Double
operands use absolute 1e-12 plus relative 1e-12 bounds. Nonfinite operands must
match class and sign. Numeric comparison does not permit whitespace changes.

A streaming checker buffers one line, validates it and combines independently
computed per-line reverse polynomial hashes. The actual character stream also
computes the source forward Word64 hash; both whole-output hashes must agree.
Modified numeric spellings are checked before their actual line hash is used.
The driver emits stable repetitions:checked-lines output instead of source
compiler-dependent decimal hash lines.

## Profiles and correctness

| Profile | Original trace | Repetitions |
|---|---|---:|
| Smoke | gg.faststdin | 1 |
| Normal | gg.stdin | 500 |
| Large | gg.slowstdin | 1500 |

Smoke reduces FAST's 150 repetitions to one. Normal and large retain their source
counts. Each mode uses its own original PostScript reference and the suite's
default resource limits. Landscape is the comparative profile; portrait and
encapsulated output are auxiliary correctness cases.

Unmodified GHC runs match every stdout/stderr fixture. Export-only observers
supply sorted records, parameters and complete output for three graph modes,
portrait, EPS and selected-processor cases. Thirty complete SML outputs agree
under both policies across the three standard traces and five formats, allowing
only equivalent bare numeric operand spelling.

Tests compare all ordered records and full outputs, validate the decoded
supplementary trace, reject modified commands/points/colors/text/line counts/
numeric operands/nonfinite categories, exercise source rounding/scaling quirks,
and verify paired-state sharing and demand. Whole normal profiles are calibrated
under both payload policies. Full SML large repetition validation is recorded
separately when run.

[The host-result note](../validation/gg-host-results.md) retains the reduced
SML/NJ Word64 checker discrepancy. Valid source/checker code and canonical host
settings remain; failing configurations cannot supply accepted timing results.

## Literature and diagnostic questions

The retained [manual](../gg-lazy/upstream/gg.1) documents the interface and modes.
The report templates and README identify the historical application.
[Peyton Jones, Clack, Salkild and Hardie, GRIP: a high-performance architecture
for parallel graph reduction (1987)](https://www.microsoft.com/en-us/research/publication/grip-a-high-performance-architecture-for-parallel-graph-reduction/)
provides machine context. Its abstract and introduction were reviewed; it
describes the parallel machine, not this sequential SML postprocessor.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides suite context.

Investigate delayed numeric parsing, insertion shape, selected-field forcing,
state/trace retention, outline transposition, Float32 versus Double operations
and streaming text/hash consumers. These are source-based questions. Reference
agreement and measured configurations are separate from architectural hypotheses.

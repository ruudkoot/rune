# hidden-lazy provenance

Finite numeric evaluation: lazy.

## Algorithm and workload

Remove hidden portions of polygon edges, rotate the selected scene toward the
view direction, scale it onto the page and consume the resulting PostScript.
Preserve the original right-rotated polygon border order, support/heading edge
representation, pairwise overlap, clipping order and triangular visibility memo.

## History, authorship, revision and variants

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/hidden.
The retained December 1992 MAIL credits Stef Joosten's original Miranda program
and Mark Ramaer's Haskell translation and memoization. The correspondence
explicitly permits its inclusion in nofib; no broader separate license grant
is inferred. Original modules, Makefile, correspondence, prompts and all eight
scene files remain under hidden-lazy/upstream. Individual scene files state no
separate author or notice. MAIL describes four.plate as a composition of table,
horse, bookcase and houses. Other dataset origins are unstated.

The historical etc/nbpip.c is a pseudo-terminal/Ghostscript interaction wrapper,
not a second hidden-line algorithm. Its excluded support-program disposition,
identity and missing obsolete terminal setup are recorded in source-variants.tsv.
It is retained as provenance and is not linked into the portable benchmark.

The established hidden name is retained with explicit lazy/strict suffixes.
This program is distinct from the suite's other ray tracers and renderers.

## Portable translation and source behavior

All geometry, binary32 rounding, bounded scene parsing, rendering and checks are
SML97. Float arithmetic rounds after each primitive operation, including square
root. The selected computations use finite normal numbers or zero; the helper
does not claim general binary32 subnormal, overflow or transcendental support.
An independent eager binary32 model agrees exactly with GHC on every rotated
vertex and full visible edge in all three profiles. It records 34,715,488
operations, with no nonfinite or subnormal results.

Number's historical comparisons are unusual: equality uses abs(a-b)<epsilon,
while inequality uses abs(a-b)>epsilon. At exactly epsilon both are false.
Less-than and less-or-equal subtract epsilon on different operands; greater-than
and greater-or-equal derive from the source Ord comparison defaults. Preserve
these definitions, including min/max selection. Vector inequality instead
complements vector equality. Epsilon is binary32 word 953267991.

Vectors remain lists of numeric components. Dot products sum from zero in source
order. Keep rotation basis construction and repeated face normal calculations
at their source call sites. View zero or positive z leaves coordinates alone;
negative z negates every coordinate, as the source specifies.

Both policies retain lazy memoized control streams and lazy shared visibility
cells. Lazy numeric components avoid unused cross-product/rotation coordinates;
strict finite numeric construction evaluates them. The array of triangle cells
is freshly constructed inside each bottom-plate iteration, as written upstream.
Do not replace it with one global matrix. Reverse visibility queries retain
the source's cached-reverse test followed by an uncached forward calculation.

The driver retains 20 iterations for normal and large, with file reload, scene
parse and view parse on every iteration. Smoke reduces only repetitions to one.
Replace interactive prompts with explicit parameters and a stable checked-runs:
edge-count report. The parser handles the selected closed three-coordinate
plate grammar; it is not a general Haskell Read implementation.

PostScript keeps source path-continuity decisions using three-coordinate tolerant
vector equality, but prints only x/y. Primary checks compare every emitted x/y
binary32 word and every move/line/path-break command. They do not force an
otherwise irrelevant z coordinate just to validate output. Extra full-edge and
rotated-vertex checks are auxiliary observations.

GEN9 with a decimal minus sign replaces GHC's shortest Float formatting.
Every formatted value must round back to its exact binary32 word, including
signed zero. The full text is consumed by the source polynomial hash modulo
2^64, checked against an independent reverse polynomial calculation.
Golden text hash vectors are tested separately. Accepted results depend on the
coordinate/command oracle rather than compiler-specific decimal spellings.

## Profiles and correctness

| Profile | Original scene | Polygons | Repetitions | Visible edges per run |
|---|---|---:|---:|---:|
| Smoke | FAST houses.plate | 14 | 1 | 25 |
| Normal | NORM rad.plate | 51 | 20 | 130 |
| Large | SLOW four.plate | 119 | 20 | 238 |

All profiles use view 2,10,3 and their normal suite resource limits.
The unmodified GHC program runs 20 repetitions on every scene and matches empty
stdout plus its complete upstream stderr fixture. Export-only observers provide
full geometry and PostScript fixtures; the separate Python reference model
independently agrees on binary32 geometry. Command references are decoded from
the original PostScript with binary32 decimal roundtrip.

Primary geometry bounds are exact binary32 word equality, not a loose numerical
tolerance. The source's epsilon controls geometry rather than checker accuracy.
Tests exercise deliberately perturbed coordinates/topology, missing/extra output,
bad references, comparison boundary quirks, rotation special cases, border order,
memo sharing, finite numeric demand and unused z demand.

## Literature and diagnostic questions

[Joosten, The use of functional programming in software development (1989)](https://research.utwente.nl/en/publications/the-use-of-functional-programming-in-software-development/)
is the thesis identified by the original author correspondence. The university
bibliographic record confirms authorship, date and title; the thesis contents
have not been reviewed here.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides suite context.

Investigate list/vector representation, binary32 emulation, higher-order clipping,
short circuiting, memo construction versus cell forcing, unused coordinates and
numeric boxing. These are source-based questions, not measured optimization
claims. Compare the identical SML sources across compilers; Haskell supplies a
correctness reference.

## Recorded host limitations

[The host-result note](../validation/hidden-host-results.md) records the legacy
GC-sensitive failure and the SML/NJ external constructor-field defect. The
canonical defaults and checks retain these failures; successful control runs
do not replace them.

# mandel2-lazy provenance

Selected: memoized corner colours and children with source right-spine forcing.

## Algorithm and workload

Build an adaptive binary MandTree with NS/EW children and integer-colour leaves.
Check rectangle corners and selected perimeter points; retain a leaf when the
source considers them uniform, otherwise split the longer axis (x on ties).
The default root is inclusive (0,0)..(200,100); coordinate scaling still uses
the source size constant 200 and denominator199. It is not a 200x200 image.
Each point uses binary32 arithmetic, initial z=0, escape radius-squared20 and
26 colour levels. Test k+1==26 before demanding the next coordinate/radius.

## History, authorship, revision and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/mandel2/Main.hs,
Makefile and the NofibUtils.hs symlink to common/NofibUtils.hs. The header
credits David Hanley and is dated 11/03/1992; it cites The Beauty of Fractals,
page121. Preserve the exact date and source text. These individual files
state no separate redistribution notice; do not invent a grant from another
program's license. Record the symlink bytes, resolved source and original path.
The explicit names mandel2-lazy/mandel2-strict distinguish evaluation variants
from mandel's complex-orbit pixmaps and other Mandelbrot programs.

## Exact source quirks and evaluation variants

Preserve the original perimeter direction conditions. Positive-height vertical
checks usually stop immediately; zero-height rectangles can scan above/below
their bounds until colours differ. Do not repair the inequalities or clamp
coordinates. The complete independent 200-root model observes 707 distinct
outside coordinates; this is a model observation, not an instrumented GHC call
count. The resulting tree is the specified workload, not a claim of equivalence
to evaluating every interior pixel.

The source's par is locally defined as a sequential no-op. Its right child is
forced to WHNF before a node is constructed, while the left stays lazy; this
recursively forces a right spine. The lazy port preserves memoized children,
corner-colour sharing and short circuiting. The strict variant evaluates all
four corner bindings and completes the right subtree before the left. Those
costs and retention differences are intentional; complete tree results agree.
Counting point-function tests cover unused corners, one shared col1, the
single-point case, outward scans, right-first forcing and memoized children.

## Portable SML translation and numerical semantics

A finite-normal binary32 helper represents selected values exactly in binary64
and rounds every source add/subtract/multiply/divide to 24 significand bits,
nearest-even. It preserves signed zero. Source coefficients are dyadic except
the fixed 3/199 step; original bit fixtures validate coordinates, every selected
orbit step, radius and colour. Preserve left association in 2*x*y+q. SML97
Real is required to have binary64 representation; no new compiler/runtime
Float32 feature or native-host Real32 substitution is introduced.

This is a workload-specific helper, not general support for binary32 NaNs,
subnormals or overflow. Active selected orbits remain in its finite-normal/zero
domain; unsupported values raise Domain rather than silently widening the
workload. Complete tree comparisons and per-operation bit checks exercise
all selected paths. Final tree tags/bounds/colours require exact agreement;
no floating tolerance accepts a different split or colour.

Tree nodes retain delayed or strict children and the source NS/EW/Leaf shapes.
Default Int represents bounded geometry, colours and counts, all within signed
31-bit limits. A point-function module parameter permits direct demand tests;
it does not change the numerical function. Complete preorder validation
reconstructs bounds and checks every node, colour and EOF. Serialization,
checking and reference I/O are measured work. The final result reports checked
repetitions and node count rather than the source's empty stdout.

## Inputs, optimizer barrier and runtime questions

Smoke uses one root extent64 via the original build_tree API, with the global
coordinate scale left at200. Normal uses the full200 extent and upstream FAST
2 repetitions. Selected large uses full200 and upstream NORM20; source SLOW100
is retained as an original execution/reference, not silently relabeled.

The original salt is pure with NOINLINE, preventing invariant-input floating.
A deterministic SML97-generated size file supplies one runtime extent per
repetition as a portable input dependency. It preserves the fixed size values,
while adding documented one-line input/parsing work. The driver bounds extents
to1..200 and repetitions to1..100, validates each complete tree and requires
EOF in the size file. Its first line is the repetition count, followed by
exactly that many integer extents. Expected preorder rows contain NS/EW plus
four bounds, or L plus bounds and the leaf colour. No exact-value guard before construction exposes a
constant extent to the optimizer. No FFI, effects or parallel runtime is needed.

Source-based performance questions include emulated binary32 cost, corner
sharing/short circuiting, source outward scans, tree allocation/retention,
right-spine forcing, specialization and GC interaction. These remain hypotheses
unless supported by source analysis or measurements. Standard reports compare
identical SML; original Haskell supplies correctness evidence.

## References and recorded limits

Original executions terminate at2/20/100 repetitions. Complete GHC trees agree
with an independent struct-packed binary32/perimeter model for extents
1/2/3/8/16/64/200. Golden bit patterns and full-tree checks preserve the source's
unusual boundaries and arithmetic. Negative fixtures change colour/branch,
truncate or append rows. Large SML execution is claimed only when recorded.

A preliminary full-tree host run shows default-nursery differences on managed
legacy64 SML/NJ despite its passing scalar bit checks. The same original-source
contexts pass with a 64 MiB nursery. Diagnostic callback changes move the first
mismatch. This is nursery/context-sensitive evidence consistent with existing
GC reports; its first corrupt operation is not reduced. Preserve failed
outputs, source identities and diagnostic settings; do not change the kernel,
expectation or default configuration to hide the result. Final profile outcomes
must be recorded separately from these preliminary contexts.

[Peitgen and Richter, The Beauty of Fractals](https://doi.org/10.1007/978-3-642-61717-1)
provides the cited mathematical background; page121 is an upstream attribution,
not a claim that the page was independently audited here. The suite's nofib
and measurement references supply context. Neither the book nor these source
observations establishes the relative speed of the SML variants.

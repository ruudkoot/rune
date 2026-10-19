# mandel-old-lazy provenance

Selected: historical MandelOld.lhs with memoized cyclic orbits, coordinates and pixel streams.

## Algorithm and workload

Construct a pixmap by mapping a complex orbit escape count across a rectangular
viewport. Each orbit begins at c and applies z*z+c. Pixels enumerate Integer
coordinates s=1..width and t=1..height, mapping both axes with multiply before
divide. RGB is (count, limit-count, limit-count), sharing the latter value.
The pixmap retains Integer dimensions, Int depth and a list/stream of RGB tuples.
Force and consume every metadata field and colour; do not substitute a bitmap,
zero-based sampling grid or a different Mandelbrot recurrence convention.

## History, authorship, revision and names

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/mandel/Main.hs,
Mandel.lhs, MandelOld.lhs, PortablePixmap.lhs and Makefile. The literate modules
retain a report-style explanation and a Falconer citation. The format banner
credits Jon.Hill, 28/5/92; the embedded PPM manual retains Jef Poskanzer's
1989/1991 copyright. The individual workload modules state no separate grant;
preserve their bytes and notices without inferring one from another component.

GHC base's Data/Complex.hs and complete BASE LICENSE are separately pinned at
GHC 9.4.7 revision 00920f176b0235d5bb52a8e054d89a664f8938fe. Retain its
University of Glasgow and Haskell98 Report notices. Its multiplication and
scaled magnitude define the selected generic variant's library operations.
The source stem mandel is distinct from classic SML mandelbrot, nofib mandel2
and Sandmark mandelbrot6. Explicit -lazy/-strict names record evaluation choices;
mandel-old identifies the materially different historical module.

## Known variants and exact numeric differences

The current Mandel.lhs uses generic complex multiplication/addition and scaled
magnitude. Its magnitude scales components by the maximum exponent, squares,
sums, takes a square root and scales back. Divergence tests magnitude>radius,
where radius=max(viewport spans)/2. Take limit orbit elements, then count the
prefix before the first divergent element. A bounded orbit returns limit,
not zero. At limit0, neither the initial complex coordinate nor the next orbit
value is demanded by this consumer.

MandelOld.lhs explicitly squares complex components, using 2*(r*i) for the
imaginary product. It compares x*x+y*y>=max(viewport spans) directly; that
quantity is the source's radiusSq, not a replacement derived formula. The
predicate precedes the zero-limit test, forcing the current orbit head even
at limit0 and one additional head at an exhausted positive limit. Inclusive
boundary behavior differs from the current module. Preserve these algorithms,
operation associations and data flows separately.

The pinned Makefile excludes MandelOld.lhs from its default SRCS. Preserve it
as a historical variant rather than silently dropping it. The reference needs
two syntax-only adaptations for modern GHC: remove [sequential] from a literate
code delimiter and parenthesize both operands of :+ against +. Original bytes,
patches, failed compile attempts and adapted source remain recorded. No numeric
formula is repaired or replaced by a dense rendering shortcut.

## Portable SML translation and evaluation

Specialize the selected complex operations to real pairs with explicit component
types; preserve the separate generic multiply/add results and the historical
scalar expressions. The runtime requires binary64 Real. Integer grid indices
and pixmap dimensions remain IntInf. Bounded colour counts use the supported
hosts' default Int. All selected counts/dimensions fit even 31-bit Int.

Lazy variants retain explicit memoized orbit heads/spines and the feedback
list knot. The current module also retains a lazy take spine. Coordinates are
passed as delays so limit0 does not evaluate them. Historical zero-limit and
boundary behavior are tested separately. Strict variants materialize finite
orbits, with limit elements for the current module and limit+1 for the old
consumer; a final-element case avoids an unintended additional step. They may
compute unused post-escape IEEE infinities/NaNs before the consumer stops;
those values are not reported as pixel results. Strict grid/pixel lists replace
the lazy spines explicitly. Final integer RGB values must agree with the
corresponding original variant.

A polymorphic Pixmap wrapper retains metadata and either the stream or strict
list. Full-image reference checks remain available, while the timed driver
consumes every RGB channel into a checked 64-bit rolling digest and exact pixel
count, then checks metadata and EOF. It reports repetitions:checked instead
of the original empty stdout. The digest starts at 1013904223 and folds each
r/g/b in order with h=h*1664525+value modulo 2^64. Hashing/checking costs are
measured work; they are not original Haskell runtime timings.

## Profiles, repeated work and compiler/runtime questions

Smoke is 1 repetition of 7x5; normal preserves upstream FAST 25x25 for the
source's 100 repetitions; large preserves SLOW 180x180 for 100. All use the
original -2..2 viewport and depth75. Upstream NORM 80x80 remains a complete
reference. Deterministic SML97 generation writes each repetition's seven
parameters. The driver reads a fresh row each time, retaining the original
Main's repeated getArgs dependency and preventing the entire render from
becoming a loop-invariant value. It consolidates argument reading/parsing
into one file row and uses SML negative spelling. File I/O and parsing are
explicit driver adaptations. A parameter file starts with the repetition count,
then exactly that many minX/minY/maxX/maxY/width/height/limit rows. The reviewed
digest line contains width, height, depth, pixel count and uppercase hex hash. Width/height are limited to 1..180, depth to
0..75, repetitions to 1..100, and finite viewports to the documented +/-2 box.
No separately acquired dataset is needed.

Source-based questions include complex boxing/unboxing, generic specialization,
scaled-norm cost, lazy knot/take allocation, sharing, early escape, eager unused
orbits, strict list retention and Integer-index conversion. These are hypotheses
until established by compiler inspection or measurement. Ordinary comparisons
use identical SML. No parallelism or runtime facility is required merely because
the literate explanation discusses parallel mapping.

## References and validation

Complete original GHC RGB components and independent binary64 recurrence/scaled-
norm models agree through 180x180, including rectangular and zero/one-limit
cases. Separate original Word64 observers agree with independently derived
full-image digests. Checks cover all channels/metadata, exact count/digest/EOF,
boundary differences, zero-limit demand, extra historical orbit forcing,
cyclic sharing and strict evaluation after escape. Wrong RGB, metadata, counts,
digests, empty/truncated/extra references must fail. Final results are discrete
integer colours and require exact agreement; no generic floating tolerance
is applied to a changed escape decision. A mismatch alone is not a language-
conformance proof. Large SML execution is claimed only when recorded.

The retained modules explain their own implementation choices. Falconer's
[Fractal Geometry](https://doi.org/10.1002/0470013850) provides broader mathematical
background (the linked later edition is not claimed as the source's historical
edition). The nofib literature and suite measurement survey provide benchmark
context; they do not establish performance causes for this translation.

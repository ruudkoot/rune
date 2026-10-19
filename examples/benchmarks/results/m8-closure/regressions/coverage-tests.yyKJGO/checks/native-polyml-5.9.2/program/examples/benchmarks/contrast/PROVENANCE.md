# contrast provenance

### Algorithm and workload

Run the eight source image contrast pipelines in their original order:
adaptive contrast spreading; Niblack global RGB, local RGB and local monochrome;
Sauvola global RGB, global monochrome, local RGB and local monochrome.
Each method receives the same original RGB image and builds a fresh output.
Do not combine the passes or substitute integral-image statistics.

### History, names and notices

[Sandmark sauvola/contrast.exe](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/sauvola),
pinned at 5605805954a00497ed197c930641cddd580e1507, credits Andreas Romeyke, copyright 2009-2012,
under GPL version 2 or later. contrast is the executable name; Sauvola and
Niblack describe constituent algorithm families, not duplicate executables.
Preserve contrast.ml, its build files and complete LICENSE.

The input derives from the source example2_small.ppm, 267 by 200 RGB pixels.
The individual image states no separate author or dataset notice; record this
attribution limit alongside its pinned source path and original byte hash.
The JPEG example is an alternative encoding, not a separate runnable workload.

CamlImages 5.0.4 is pinned independently by archive SHA-256 in
LIBRARY-ARCHIVE.json. Selected source headers credit Francois Pessaux, Pierre
Weis and Jun Furuse/INRIA, copyright 1999-2004. Preserve those full headers and
License.txt, which supplies Library GPL version 2 and its linking exception.
The OCaml 4.14.1 hash adapter has its separate LGPL 2.1/linking-exception notices
under hashtbl_iter/upstream-library. Do not conflate these grants with the
contrast program's GPL notice.

### Portable translation and source variants

Use SML97 Word8Array RGB storage, records, loops, arrays, memoized thresholds
and portable PPM I/O. The original reference builds against pinned CamlImages
core with PPM support; the unused external image formats are not prerequisites
of the SML program. No FFI/compiler/runtime feature is introduced.

Contiguous byte storage replaces CamlImages' managed block storage. Subimages
are still materialized and RGB records are still returned from pixel reads.
Additional initialization, record construction and SML library costs are explicit.
Pixel brightness retains the active integer weights (54R+182G+19B)/255.
The source statistics scan columns before rows. Three squared sums use IntInf
to preserve source 64-bit integer values on 31-bit hosts; other selected integer
operations fit signed 31-bit values. Exact truncating division remains explicit.

Keep the source window radius fifteen, RGB subimage upper-border exclusion,
monochrome inclusive windows and rolling cache update, retained cache counts,
strict comparisons and bright-pixel skips. Preserve the distinct global and
local Sauvola formulas and constants. They are literal source variants rather
than claimed canonical formulas from a paper.

Threshold memoization retains one 1024-bucket table per method call, first-match
lookup and the source rule that the next miss clears a table with more than
1000 bindings. At most 1001 entries are possible, so table resizing and traversal
mutation are unreachable in this fragment. Integer/float tuple hashing retains
tag/header order, Murmur mixing, signed-zero and NaN normalization. Optional
packed-real structure names differ across hosts; a common SML97 binary64-word
encoder replaces the native reinterpretation. This adds arithmetic/conversion
cost and is explicitly a library representation adapter.

### Fixed profiles, input conversion and validation

| Profile | Image | Origin |
|---|---|---|
| Smoke | 32 by 32 | Original crop at (0,0). |
| Normal | 64 by 48 | Original crop at (40,40). |
| Large | 267 by 200 | Complete original image. |

Profiles select input files, retaining the source image parameter rather than
a universal size argument. A portable SML generator re-encodes pixels as ASCII
P3. Independent byte comparisons establish exact RGB preservation and crop
coordinates; the original OCaml program produces identical complete-image
outputs from P3 and P6. Encoding changes I/O cost, not pixel values.
INPUT-IDENTITIES.json records original/converted data and RGB identities.

Validate every RGB channel of all eight complete binary output images, with
exact geometry and reviewed zero/255 reference bits. No floating tolerance
is applied to these final discrete values. Additional checker work replaces
source progress/timing output and eight PPM filesystem writes. Returned
dimensions/pass counts consume only fully checked outputs.

Original reference programs establish all profile rasters, 81 float-pair hash
values and memo hit/clear traces. An independent bit/Murmur model agrees with
those hashes. Tests cover cache sharing, source window edges, brightness
weights, copy isolation, invalid colors, corrupted output, wrong reference
lengths and nonbinary reference data. The smoke and normal Rune pilots match
all eight original rasters; final configuration evidence and large runs are
recorded separately.

### Compiler/runtime behavior

Investigate repeated subimage allocation, boxed versus packed channel access,
wide squared-sum arithmetic, real-key encoding, memo collisions/clearing,
cache reuse and branch behavior on bright pixels. Source inspection motivates
these questions. Recorded measurements do not attribute individual costs.
The common SML sources are the standard compiler comparison; OCaml remains
a correctness reference.

### Literature and evidence scope

[Sauvola and Pietikainen (2000)](https://www.sciencedirect.com/science/article/pii/S0031320399000552),
publisher abstract and opening material inspected, supplies adaptive document
binarization context. The source additionally cites Niblack (1986) and
Sezgin/Sankur (2004); these are declared references, not newly claimed full
reviews. The particular eight formulas, window boundaries and caches come
from source inspection. Original raster/hash observations and independent
models support the translation; performance explanations remain hypotheses.

from pathlib import Path
import csv
root=Path.cwd();suite=root/'examples/benchmarks'
revision=next(r['revision']for r in csv.DictReader((suite/'upstreams.tsv').open(),delimiter='\t')if r['source']=='sandmark')
body=f"""### Algorithm and workload

Render the original roomfront triangle scene with sequential Monte Carlo
path tracing, emitter samples, Russian-roulette reflection, an octree and
progressive RGB accumulation. Preserve camera jitter, shadow rays, triangle
tests, material/sky handling and the source image tone-map/gamma/quantizer.
The complete application remains, rather than a triangle-intersection kernel.

### History, aliases and notices

[Sandmark's sequential MiniLight](https://github.com/ocaml-bench/sandmark/tree/{revision}/benchmarks/multicore-minilight/sequential),
pinned at {revision}, identifies MiniLight 1.5.2 OCaml and credits Harrison
Ainsworth/HXA7241, copyright 2006-2008. Preserve all modules, original CRLF
roomfront.ml.txt, build files and the BSD three-clause LICENSE.txt.
The individual scene states no separate author or dataset notice.
Later author-site downloads advertise CC0; that does not replace the notice
on this pinned historical source.

The sequential program contains no Domain/Task call. Its unused Dune
domainslib link dependency is omitted; the original also builds with plain
ocamlopt. Parallel MiniLight variants retain their separate feature-policy
disposition and are not silently represented by this sequential executable.

### Translation, demand and numeric decisions

Use SML97 RealArray three-vectors and ordinary arrays for vertex/frame/item
containers and image pixels. Records/datatypes/functions replace objects and
method dispatch. Explicit per-frame tracer environments and surface records
retain their construction scopes. Triangle identity uses a unique reference;
equal geometry does not make two triangles the same last-hit object.

Normal, tangent and area retain separate memoized delays. Original Lazy.is_val
observations establish their independent forcing order; repeated forces share
the result. Keep source octree depth/leaf limits, bounds/tolerances, stable
item order, subdivision controls and nearest-hit tie decisions.

Original observations establish OCaml's evaluation order. Preserve stochastic
tuple draws explicitly: camera y before x, triangle r2 before sqrt(r1), and
hemisphere radius before angle. Simultaneous let-and groups remain left first.
Pure operand/constructor allocation order and temporary representation can
differ under SML evaluation; record this when interpreting allocation costs.
The fixed Random.State.make [|1|] state is precomputed as 55 words; subsequent
draws and rejection logic use the common unchanged OCaml-random adapter.

Model parsing uses portable text tokens instead of Scanf; selected coordinates,
materials, light and camera values remain unchanged. Default reals are binary64
on the configured hosts. Selected indices/frame counts fit signed 31-bit
integers. No parallelism, FFI or compiler/runtime prerequisite is introduced.

### Fixed profiles, deterministic checkpoints and checks

| Profile | Frames | Viewport | Original scene |
|---|---:|---|---|
| Smoke | 1 | 8 by 5 | Unchanged geometry/material/light/camera records. |
| Normal | 2 | 81 by 50 | Unchanged scene; original 1.62 aspect ratio. |
| Large | 4 | 162 by 100 | Unchanged scene; original 1.62 aspect ratio. |

The source model requests 100 frames at 324 by 200. These are explicit smaller
frame/viewport selections, not a universal size loop. A portable SML generator
replaces only those header parameters and retains the original geometry suffix.
Input identities and original references accompany the profiles.

Replace wall-clock periodic saves with deterministic first/last-frame
checkpoints, merging them for a one-frame run. This retains the source start/
end image work without clock-dependent extra saves. Intermediate files and UI
progress are suppressed; both complete checkpoint images are consumed and
checked. The stopping rule remains a fixed frame count.

References contain every first/final linear RGB accumulation, both complete
quantized rasters and the exact final 55-word random state/index. Linear values
must be finite and within 1e-8 absolute plus 1e-8 relative error; quantized bytes,
header, geometry and random state are exact. Incorrect output contributes no
measurement. Original export-only observations agree byte-for-byte with the
unmodified executable's final P6 images. The initial exploratory byte tolerance
was tightened to exact equality before final validation.

### Validation and compiler/runtime interpretation

The private Rune smoke/normal pilots validate complete original results.
Controls cover demand sharing, exception caching, independent geometry identity,
known intersections, parallel misses, octree last-hit handling, numerical
perturbations, NaN, wrong byte/length and all source geometry forcing states.
Native 32-bit SML/NJ retains the known bounded-random Overflow; do not rewrite
its arithmetic or accept an alternate result.

Investigate method/closure specialization, vector and temporary allocation,
memoized geometry, octree traversal, object identity, random draws, recursion
and tone-map operations. These are source-based hypotheses; measurements alone
do not identify their individual costs. Complete target/profile outcomes and
full large-run coverage are recorded separately.

### Literature and evidence scope

[The author's description](https://www.hxa.name/minilight/), algorithm section
inspected, supplies renderer context and identifies its sampling, spatial
index and tone-mapping components. The current page and historical source have
different release/license contexts, recorded above.

[Moller and Trumbore (1997)](https://my.eng.utah.edu/~cs6965/papers/MT97.pdf),
abstract and opening page inspected, describes finding ray distance and
triangle coordinates without storing plane equations. This is an algorithm
anchor rather than a full review of its performance claims. The port's actual
tolerances, octree, sampling order and demand policy come from source analysis
and original/model observations.
"""
(suite/'minilight/PROVENANCE.md').write_text('# minilight provenance\n\n'+body)
f=suite/'README.md';text=f.read_text();pos=text.index('\n## ')
row='| [minilight](#minilight) | [Sandmark sequential MiniLight](https://github.com/ocaml-bench/sandmark/tree/'+revision+'/benchmarks/multicore-minilight/sequential) | Render the original scene with sequential Monte Carlo path tracing, emitter samples and an octree. |\n'
f.write_text(text[:pos].rstrip()+'\n'+row+text[pos:]+'\n## minilight\n\n'+body)

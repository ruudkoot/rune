# fulsom-nofib-lazy provenance

### Algorithm and workload

Render the fixed union of three coloured spheres using source interval
arithmetic, constructive-solid-geometry residual pruning, an octree, front-to-
back quadtree projection and the original coloured raster stream. Preserve
source child order, lighting calculations and the overlapping topBit z-half.
The workload is a sequential renderer, requiring no graphics or foreign API.

### History, variants and notices

Duncan Sinclair's Fulsom sources carry copyright 1990,1991,1992,1993 and an
individual permission grant. Complete original notices, including their
spelling, remain in source copies and translated derivative modules.
README.original and dated correspondence supply the program history;
README.nofib credits Will Partain with directory flattening. Historical machine,
heap and time examples are not current performance measurements.

[nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798) is pinned
at b7391df4540ac8b11b35e1b2e2c15819b5171798. The gc/fulsom and real/fulsom Main programs are materially
different consumers: one writes one complete raw raster; the other computes
and prints a signed machine-integer hash in 1000 iterations. Their shared
reachable renderer is implemented once. The unsuffixed family fulsom denotes
the GC source and fulsom-nofib the colliding real source, matching the inventory.
Each receives explicit -lazy/-strict finite-data names.

The source modules mostly match byte for byte; the interval copies also contain
formatting/type-context differences. Both exact copies are retained. Bah.hs
is an auxiliary test explicitly excluded by each Makefile. Cube, transforms,
other sample scenes and unused interval operations are not entrypoints of
either fixed Main workload. Retain their original definitions without
claiming runnable imports of inactive library APIs. No external dataset is
needed; scene coordinates, colours and light vector come from Shapes/Kolor.

### Translation, demand and numeric decisions

Keep infinite octree and quadtree control, CSG nodes, change flags, stream
spines and branch choices memoized in both policies. Fully eager infinite
control would not terminate. The lazy policy memoizes finite interval bounds,
RGB components and child-list spines; the strict policy materializes those
finite fields. Shared global scene definitions remain global.

False change flags leave the source dead-residual sentinel undemanded.
A full front quad skips hidden back octrees. Lighting is delayed until a
nonempty node requires it; RGB component calculation is shared. Retain source
short circuits and lazy raster prefixes instead of evaluating all colour data
when constructing a stream cell. Both policies use the same SML97 program on
every host.

Real values use binary64. Preserve source operation grouping, interval-specific
comparisons/minimum behavior, midpoint overlap and the 255.5 rounding formula.
Raster words are unsigned 16-bit values emitted high byte first. The real
source's hash is fixed explicitly to the original tested signed 64-bit
semantics: Word64 modular arithmetic and IntInf signed conversion, including
negative hashes. This avoids silently changing the reference on 31-bit hosts.
Small indices and raster counts fit signed 31-bit integers.

### Inputs, profiles and complete checks

| Consumer | Smoke | Normal | Large |
|---|---|---|---|
| GC/raw | one depth-four raster | one depth-seven raster | one depth-nine raster |
| Real/hashed | one depth-four raster | 1000 depth-five rasters | 1000 depth-six rasters |

Raw normal selects the source FAST depth seven for practical portable checks;
source NORM/SLOW depth nine remains the selected large profile. A depth-nine
default Rune pilot exceeded a protective 2 GiB process-tree limit; that guarded
attempt is not a workload failure at the suite's 4/8 GiB limits. Smoke reduces
source GC depth seven or real 1000 repetitions explicitly. Real normal/large
retain original parameters. Normal and large limits retain suite defaults.

Validate every raster byte against reviewed original outputs. ASCII hexadecimal
is only a reversible transport for binary fixtures; source byte lengths and
SHA-256 identities are recorded. Consume/check the raw stream without adding
hash arithmetic to the GC workload. The real consumer additionally checks each
signed modular hash. Drivers suppress raw/repeated stdout and return checked
byte/repetition counts; hex input and expected hash parsing occur outside
the repetition loop, replacing repeated getArgs. Online reference comparisons
add validation work, but do not materialize a second generated raster.

Original FAST/NORM fixtures match the unmodified Haskell executables.
An independent sphere/box projection model agrees on all 1365 selected
foreground-mask pixels through depth five, using neither CSG residuals nor
octree/quadtree construction. Complete original raster/hash equality also checks
colours and tile order. Interval observations cover 25 operand pairs and five
squares. Negative byte controls and hidden-branch/unused-colour tests exercise
essential demand. Original source and independent models remain distinct.

### Compiler/runtime concerns and recorded outcomes

Investigate retained lazy trees, residual pruning, finite-field specialization,
memo cells, stream allocation, colour sharing, online validation and modular
hash arithmetic. These are source-based questions; count agreement alone
does not establish individual performance effects. Fresh-process and repeated
execution remain separate measurement modes.

Canonical profiles, full semantic assertions, counts, host-specific diagnostic
failures and repository acceptance are recorded in the validation ledger.
Valid external interval-constructor tests are retained even where SML/NJ
misreads real-pair fields across a parameterized functor boundary, matching the
existing PIC reduction. The 32-bit all-ones Word64 literal control also exposes
the existing low-half literal defect. Neither changes expected benchmark values
or authorizes a compiler-specific kernel.

### Literature and evidence scope

[Partain's nofib suite paper](https://doi.org/10.1007/978-1-4471-3215-8_17), at the review scope recorded in the suite survey,
anchors the source family. Sinclair's 30 June 1993 correspondence and original
README supply the program-specific account of solid modelling and historical
space behavior. The actual algorithm, inactive APIs, numeric grouping and
demand decisions come from source inspection. No external paper is claimed
as a reviewed derivation of this renderer. Current correctness observations
are separate from historical timings and unmeasured performance hypotheses.

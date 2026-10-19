# Reptile provenance

## Algorithm and workload

Run a scripted tiling editor and generate its complete MGR terminal protocol.
Keep editor modes, rational geometry, drawing/erasure, transformations, tile
orientation and associations. Hash the complete protocol 500 times from the
source initial state and scripted input.

## History, authorship, revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/reptile.
Module headings credit Sandra Foubister's 1990 LML original and Colin Runciman's
May 1991 Haskell translation. Preserve their separate roles and all individual
headings. The pinned files do not supply the LML implementation or a separate
general licence grant. The scripted input files and hash stdout fixtures are
upstream data, with no additional authorship asserted.

## Known variants and selected executable

reptile-lazy memoizes finite drawing, association and text attributes;
reptile-strict materializes finite attributes eagerly. Both keep memoized
input-line and editor-transition control, and lazy producers before bounded
grid/tile prefixes. All complete protocol bytes and editor states agree.
The selected nofib Main consumes scripts and emits hashes; it does not need
a running MGR server.

Preserve the source's disabled SAVE/GET handlers as no-ops. The original
PostScript helpers remain in upstream/Psfuns.hs; only the used concrep helper
belongs to this executable path. No port of unused PostScript entry points
is claimed. The source's LML history is provenance, not a second imported port.

## Translation and adaptations

Keep exact rational-pair arithmetic, normalization, integer root search,
list geometry, association lookup/update order and finite editor state.
Use explicit two's-complement modular 64-bit integers for the pinned Haskell
Int operations. Hashing is also modular 64-bit; signed decimal conversion is
explicit. Preserve duplicate-removal quirks and both removals in deline.

The control state and transition tuples are memoized independently of the
finite-data policy. Infinite grids, indices and repeat producers are bounded
by the original consumers. concrep retains concat/take/repeat structure.
The driver reads and retains the fixed script eagerly; each repetition
starts the immutable source state and constructs fresh protocol output.
Every protocol hash is checked and printed before the verified count.

## Inputs, validation and limits

Smoke/normal/large preserve the three original scripts (18, 343 and 1029 bytes),
each with 500 source repetitions. Complete protocols have 22845, 47172 and
154800 bytes. Their signed hashes are -7953762212385260731,
5842283869563187271 and -992743539523439187. Full references and all three
modular digests are retained. Default profile limits remain unchanged.

Private checks match all three original stdout fixtures, all six complete
protocols, 178 complete transition-state observations and 38 protocol/geometry
component comparisons. Both policies pass the original smoke and normal
500-repetition drivers. A private combined six-case run reached its overall
600-second deadline during large; this is an incomplete combined check, not
a failure under the large profile's 3600-second allowance. Public profile, count and repository acceptance checks are recorded below.

## Runtime questions and literature

State retention, list copying, exact arithmetic, protocol construction and
sharing of immutable tables are source-based performance questions. Separate
instrumentation is needed to attribute allocation or GC costs. Original
module headers, Mgrfuns.hs and Progfuns.hs are the benchmark-specific references.
The roadmap's nofib literature supplies the suite context; historical
authorship does not itself establish a performance result.

### Compilation and execution phases

SML/NJ exported images evaluate declarations while the image is built.
Global tables and memoized streams can therefore enter the compilation
phase. Record build and fresh-process execution separately and interpret
them together. Repeated execution retains source global sharing and does
not imply steady state. Profiling/count instrumentation runs separately.


### Recorded public validation

The [application-wave evidence](../results/m4-parser-reptile-hpg-fluid/README.md)
records smoke/normal checks at O0/O2, all applicable Rune engines, supplied SML
hosts, independent semantic assertions, normal allocation counts, serial
adapter diagnostics and full repository acceptance. All 128 Rune profile
combinations pass. Host failures remain explicit; this link does not imply
that every host or the full large matrix passed.

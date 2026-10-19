# Fluid provenance

## Algorithm and workload

Compute a Taylor-Galerkin/pressure-correction step for the supplied finite
element channel model. Retain persistent binary radix tries, assembly,
minimum-degree ordering, elimination trees, generalized-envelope storage,
column Cholesky factorization, substitution and Jacobi iterations. Render
and hash the complete source result on each repetition.

## History, authorship, revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/fluid.
Dated 1991/1992 source headings identify XZ; Input_proc.hs also records XA.
Their initials are retained without inventing full names or a sole author.
The program, chan.hed/fluid.stdin, runtime_files/chan8.dat and historical res8
retain their actual headings; no broader program/dataset licence or additional
dataset authorship is inferred. The selected channel model contains eight
elements, 25 velocity nodes and nine pressure nodes. The historical reference
to a 200-element problem does not supply a second dataset in this snapshot.

## Known variants

fluid-lazy memoizes finite numeric/list fields and fluid-strict materializes
them eagerly. Both retain memoized trie/array/control roots and the explicit
Norm_pack forcing flags. Preserve the selected header's monitoring=false,
one main step and two maximum Jacobi iterations. Monitoring and two-step
controls are independent correctness fixtures. The historical res8 file is
retained separately from modern GHC-derived expected output.

## Translation and adaptations

Keep Float semantics through binary32 rounding after every arithmetic
operation, including subnormals and the original 1e-40 small constant.
Retain source operation association, zero-skipping multiplication, source
norm/guard order, stopping tests and default/undefined sparse-array behavior.
Control delays keep unused final backward-substitution updates and
out-of-block diagonal expressions unevaluated.

Sparse arrays remain persistent radix tries with source Null coalescing,
stable partition/update/accumulation order and sparse association traversal.
Selected indices and counters fit signed 31-bit integers. The hash is explicit
modular 64-bit. Norm_pack shares its object and memoized deep-forcing result.
Do not replace the source solver, matrix representation or tolerance tests.

The numeric input adapter is scoped to the reviewed decimal fixtures; it
does not implement every Haskell Read syntax. It preserves the independent
takeval/dropval parsing passes. All parsed source fields agree exactly with
GHC. Input files are read eagerly into SML strings. The header remains shared;
the dataset is opened/read afresh on each repetition as in the source loop.
The bounded driver preserves nonpositive counts as zero work.

Float formatting ports the pinned GHC.Float binary32 floatToDigits and
FFGeneric/Nothing behavior, using portable IntInf support. Preserve ShowS
character output, original spellings and complete result forcing. The driver
checks each complete output hash and adds a verified-count summary to the
source's empty stdout.

## Inputs, validation and limits

Smoke/normal/large retain 35/350/1750 repetitions, the unchanged fluid.stdin
header and chan8.dat. These profiles repeat the same model; they do not
claim mesh-size or memory scaling. The selected output rule has zero numerical error allowance: require the
exact binary32-derived bytes. The complete per-repetition
output has 814 bytes, SHA-256
4905e148b32fa11477a11852bc99f08f047cd2db42888a502fd069a0832fa6d3,
and modular digest 9DCE0361F540E943. Default profile limits apply.

Private checks cover 260 complete trie/default/value observations, 960 exact
binary32 matrix/product/tolerance observations, 36 minimum-degree orders,
complete parsed mesh/reordering/factorization/substitution observations,
10015 exact GHC Float Show cases, and ten complete simulation outputs.
Both policies match source output with monitoring, two steps and tolerance
stopping. The original 35-repetition driver passes locally. Public profile, count and repository acceptance checks are recorded below.

## Runtime questions and literature

Sparse traversal, persistent updates, graph ordering, normalization, floating
point boxing/rounding, IntInf formatting and I/O are source-based diagnostic
questions. The supplied main-step limit skips some convergence checks; retain
that workload rather than claiming broader convergence coverage.
[Liu (1990)](https://epubs.siam.org/doi/abs/10.1137/0611010) provides background on
elimination trees and sparse factorization. Original source comments identify
the implementation's generalized-envelope approach. The pinned GHC base source
and full licence accompany formatting support under shared/upstream.

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

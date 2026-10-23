# Build-generator inventory repair — 2026-10-23

The integrated `17c188d25` full check records a failed
`compiler/build-generators`: its isolated fixture copied only four program
build files, while the production generator now also consumes `runeffi.build`.
Reference generation therefore failed before the concurrency checks.

The fixture now lists all five programs and independently requires their
complete four-host output matrix: 20 nonempty files with the expected names.
Four rounds of eight concurrent writers must preserve those exact bytes.
The shell generator's behavior is unchanged; its comments name Runeffi too.

The exact repaired runner selection passes **6/6** cases, including five
canaries, in 2.6 seconds: `20261023-121409-468`. A planted script that
successfully generates the matrix and then removes `runeffi.mlb` is rejected
with `incomplete program/host output matrix`. Its output remains in
`/tmp/runeffi-generator-inventory-negative.log`.

The failed full-run receipt is retained as
`tests/out/r/20261023-112250-2501228`; this focused pass does not turn it into
a clean full run. Final integrated acceptance is recorded separately.

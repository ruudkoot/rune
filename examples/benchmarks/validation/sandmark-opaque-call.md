# Sandmark opaque-call microbenchmark

Reviewed 2026-10-16. The pinned
[morestacks source](https://github.com/ocaml-bench/sandmark/blob/5605805954a00497ed197c930641cddd580e1507/benchmarks/simple-tests/morestacks.ml)
defines bar n = n+5, then repeatedly ignores calls through Sys.opaque_identity.
Its measured operation is a call retained behind an optimization barrier.

The [pinned OCaml 4.14.1 interface](https://github.com/ocaml/ocaml/blob/99cb5d93fc30f1a6f3e69f5aa5d2063994d33a93/stdlib/sys.mli)
defines opaque_identity using %opaque. It makes a value unknown to optimization
while disappearing at runtime. This preserves calls to bar even though their
arithmetic results are unused. A portable pure checksum would make a result
observable, but would still allow the call to be inlined or eliminated. It would
measure a different workload from the original call-overhead test.

SML97 provides no equivalent optimization barrier, and Rune's current language,
Basis and source search supplies no portable call-preservation primitive. The
roadmap's agreed feature policy defers unavailable facilities instead of adding
prerequisite compiler/runtime features. This entry is therefore deferred, with
its original source, run configuration and provenance retained in the inventory.
Reconsider after a reviewed portable barrier protocol fits the suite contract,
or upstream supplies observable algorithmic work that can be ported faithfully.

Classification is guarded by the exact pinned source SHA256
b4153c8f1a4c4e9ea948113ee300fe62a7aee31e1ae0b69d79e121d4232eb946.
A changed program requires fresh review. Opaque wrappers on algorithmic workloads
receive individual review; the keyword alone does not trigger this disposition.
The original OCaml Cmm [retains the opaque load and indirect call](../../../../rune-benchmark-results/m5-opaque-audit/cmm.log).
Three discovery tests cover this blocker, changed-source reconsideration and
algorithmic opacity. All 38 inventory tests pass.

The review rebuilt all 143 Sandmark entries at the unchanged pinned revision,
verified a clean upstream tree and reconciled all 861 inventory entries. The one
new disposition is morestacks; existing alias relationships and ordering are unchanged. The exact source is a test fixture with the
aggregate upstream Unlicense retained alongside it. Deferred entries remain in
the inventory, outside runnable benchmark directories.

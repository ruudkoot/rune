# Opaque-call disposition evidence

Reviewed 2026-10-16. The exact morestacks source is retained as an inventory-test
fixture, with its upstream aggregate notice. The pinned source digest gates the
new defer classification. Rebuilding all 143 pinned Sandmark entries changes
only that disposition/reason; all 861 entries validate. All 38 inventory tests pass.

OCaml 4.14.1 `ocamlopt -O2 -dcmm -c` on the retained original source produces
[cmm.log](cmm.log), which still contains an opaque load followed by a call through
the resulting function value. This is the operation the microbenchmark preserves.
The [review](../../validation/sandmark-opaque-call.md) explains the missing
portable optimization barrier and reconsideration condition. No compiler/runtime
feature is added and no runnable benchmark or measurement is claimed here.

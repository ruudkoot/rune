# flat-array provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/flat-array.sml`. Original, patch and notice retained.

Vector of pairs and repeated fold, retaining the original overflow-reset policy.
Int32 makes the upstream 32-bit arithmetic assumption explicit on all hosts.
The original million entries are normal and large; the actual fold sums are
consumed in IntInf. Independent bounded Python arithmetic supplies fixtures.

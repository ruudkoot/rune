# string_map provenance

### Algorithm and workload

Map every original character to an exclamation mark.



### History, aliases and notices

This is selector string_map in [Sandmark's stdlib collection](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/stdlib),
pinned at 5605805954a00497ed197c930641cddd580e1507. Other selectors are separate workloads.
The Dune source credits adaptation from OCamlPro's benchmark repository;
the selected .ml/.inc files state no individual benchmark author or notice.
Preserve them and the suite Unlicense under string_get/upstream.

Pin OCaml 4.14.1 library source independently in string_get/DEPENDENCIES.json.
Bytes credits Xavier Leroy/INRIA, copyright 1996; String's implementation
credits Damien Doligez/INRIA, copyright 2014. Complete selected .ml/.mli
headers, LGPL 2.1 text and the linking exception are retained under
string_get/upstream-library. The library and benchmark notices are distinct.
The 574-byte Latin-like text is an embedded source literal, with no separate
dataset author or notice stated; INPUT-IDENTITY.json records its exact identity.

### Translation and variants

Use portable SML97 strings and Word8Array byte storage. Preserve operation
order, loop bounds, source text and per-call/global construction scopes.
Global text/byte input is shared; mutable bytes_set copies it per call.
No full OCaml library compatibility or identical storage/primitive cost is claimed.

Portable byte arrays may use different host packing and initialization.
Copy/sub/map use tabulation; blit/cat/concat use explicit element loops and
filled destinations in place of OCaml runtime block operations. Bytes.concat
retains one length pass and ordered segment copies. String.concat interleaves
separator list cells before the host String.concat, adding a temporary list.
String.split_on_char retains the source backward scan and empty fields.
ASCII uppercase and the exact five trim whitespace characters remain explicit.

OCaml's Sys.opaque_identity has no claimed identical SML97 barrier.
Full consumers and result checks add work and may expose constant results to
compiler specialization or hoisting. They do not establish equal work to the
original OCaml runtime. Standard comparisons use identical SML sources.

### Fixed inputs and checks

| Profile | Iterations | Published iterations | Expected count and digest |
|---|---:|---:|---|
| smoke | 1 | 20000000 | 1:1B281A12 |
| normal | 2000 | 20000000 | 2000:C2A3F6D5 |
| large | 100000 | 20000000 | 100000:FC708FA5 |

The source parameter is an operation count; input text remains fixed.
Normal reductions and selected large counts are explicit rather than a
universal size argument. Full final large SML runs are unrecorded unless
listed separately in validation.

Check every scalar, complete produced string/byte sequence or split word list.
bytes_set additionally checks every final byte. FNV-1a-style Word32 mixing
consumes the checked observations; it is an added modular result format,
not source kernel arithmetic. Counts and source character operations fit
signed 31-bit integers. No floating-point tolerance applies.

### Validation and runtime concerns

Original OCaml function observers and independent byte/word models agree on
100 edge-count results and all 55 selected profiles. Observer-only hooks
capture discarded blit/callback results without adding an FFI requirement to
the SML program. The semantic target checks overlapping copies, isolation,
trim/ASCII behavior, empty split fields, cyclic boundaries, all selectors,
unchanged global input and rejection of corrupt character/final-array results.
Private pilot evidence and canonical wrapper checks have separate scopes.

### Literature and diagnostic interpretation

The preserved benchmark and OCaml library sources establish these algorithms
and adaptations. Original observations and independent models establish the
reviewed expected results. No separate string-algorithm paper review is claimed.
Packing, bounds checks, byte/string conversions, callback specialization,
temporary allocation, source barriers and the added complete consumers are
performance questions inferred from source; timing alone does not isolate them.

# MLKit 4.7.23: region inference corrupts strings and values that are still in use

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a
specification bears on.** Programs that MLKit compiles without a warning
read strings that are no longer theirs -- a name `Json.decode` made comes
back as garbage -- or die with `SIGSEGV`. The same programs built with
`-no_ri` (no region inference; the garbage collector alone) run right, as
they do on MLton, SML/NJ, Poly/ML and Rune.

## Status: not reported upstream, not reduced below lib/json

**Still there in MLKit 4.7.25** (2026-10-09), the release that `make
hosts` installs since 2026-10-13: `repro.sml`, built as below, dies with
`SIGSEGV` as with 4.7.23, and so do `json.roundtrip`, `jsonrpc.jsonrpc`,
`dap.dap` and `pretty.pretty` in `tests/lib/run-hosts.sh mlkit`. The fix
of melsman/mlkit#234 to region inference, about the effect of an
exception constructor, does not reach it. `markdown.spec` passes there,
with 4.7.23 as well as 4.7.25, on the tree of 2026-10-13.

## What happens

On 2026-10-22, the JSON-RPC streaming/integer-width changes altered the
current `jsonrpc.jsonrpc` suite enough that it passed all six test groups
with MLKit 4.7.25's default region inference. Its now-stale deviation entry
was removed. This is not evidence that the underlying region-inference
fault is fixed: the reduced reproduction and the other affected suites
remain relevant. No library workaround or `-no_ri` setting was introduced.

`repro.sml` decodes the JSON text `{"ab":1}` with `lib/json` and prints the
name of the member it finds. Built with `$(SML_LIB)/basis/basis.mlb`,
`lib/unicode/utf8_sig.sml`, `lib/unicode/utf8.sml`, `lib/json/json_sig.sml`,
`lib/json/json.sml` and `repro.sml`, each file copied to a fresh directory:

```
$ mlkit -o r r.mlb && ./r
Segmentation fault (core dumped)
$ mlkit -no_ri -o r r.mlb && ./r
key size 2 bytes 97,98 valid true equal true string valid true
string: valid true
```

The name is made by the decoder's `string`, which concatenates the pieces
of a JSON string (`String.concat (rev acc)`) and returns the string with
an index, as it does for every string of the text; values that are
strings decode right, names of members do not. `gdb` stops in generated
code (`L_selLab_...`).

## LSP capability lookup (2026-10-22)

The new `tests/lib/lsp/protocol.sml` suite passes on Rune, MLton, both
legacy SML/NJ widths, SML/NJ 2026.2 and Poly/ML. MLKit 4.7.25 with default
region inference passes wire values, positions, inventory and request
ownership, but fails its capability lookup check. The input has
`workspace.configuration = true` and no `workspace.workspaceFolders`;
the check expects the first supported and the second unsupported.

Recompiling exactly the same source list with `-no_ri` passes all five
groups. This isolates a dependence on region inference, but the failure
has not yet been reduced to a specific decoder-name lifetime error. The
normal library suite retains default region inference and records a
`HOST-BUG`; the diagnostic flag is not a library or server workaround.

The failing native-host run is
`tests/out/r/20261022-040752-2175585/lib-hosts/mlkit/lsp.protocol`.
Its `.mlb` and compiler/run logs identify the unchanged input list; the
collector-only control was built as `tests/out/lsp-mlkit-no-ri`.

## What it breaks

`tests/lib/deviations.txt`, `native:mlkit`: `json.roundtrip`,
`jsonrpc.jsonrpc`, `dap.dap` and `markdown.spec` (all of which decode JSON
objects or encode random values), and `pretty.pretty`, which dies in its
random documents. Each of them passes when built with `-no_ri`. The
libraries are not changed for it (AGENTS.md). `markdown.spec` has passed
since, with MLKit 4.7.23 and 4.7.25 alike, and its line is gone
(2026-10-14).

## UTF-8 round trip: excessive memory use

Observed on 2026-10-19 with the installed binary release of MLKit 4.7.25,
while comparing the old native library driver with its Rune replacement.
`tests/lib/unicode/utf8.sml` compiles, then its scalar round trip exhausts
the address-space limit before printing a verdict. The program tests every
Unicode scalar by encoding it, decoding it, and checking that the encoded
string is valid. It does not need to retain the strings between iterations.
Both drivers encounter the failure; it also occurs when all source files
are copied into a fresh directory before compiling.

The same source files and `.mlb`, compiled with `-no_ri`, pass all five
tests. No library or test source was changed. These are `/usr/bin/time -v`
measurements from the comparison, with an address-space limit on each run:

| Build | Address-space limit | Exit | Peak RSS, KiB |
|---|---:|---:|---:|
| default, original paths | 2 GiB | 255 | 1,060,812 |
| default, original paths | 8 GiB | 255 | 4,236,236 |
| default, fresh source copies | 2 GiB | 255 | 1,060,848 |
| `-no_ri`, fresh source copies | 2 GiB | 0 | 7,620 |

The default builds stop with:

```
I could not allocate more memory; either no more memory is
available or the memory subsystem is detectively corrupted
: Cannot allocate memory
```

This comparison isolates the space growth to the region-inference
configuration. The reduced case in
[preserve-tail-calls](../preserve-tail-calls/BUGREPORT.md) identifies a tail
call that keeps its region and frame. The current
`native:mlkit | unicode.utf8 | HOST-FLAKY` entry in
`tests/lib/deviations.txt` records that it passes where enough memory is
available. The ordinary suite continues to compile with region inference
enabled and bounded memory.

To reproduce, run `bin/rune-test run 'lib-hosts/mlkit/unicode.utf8' --keep`
with `MLKIT` and `MLKIT_LIB` selecting 4.7.25. The run keeps the generated
`lib-hosts/mlkit/unicode.utf8/unicode.utf8.mlb`, compiler log, executable,
and program output. Rebuild that `.mlb` with the same compiler and
`SML_LIB`, adding `-no_ri`, to compare the collector-only configuration.
Keep the address-space limit when running either executable.

## Runeffi sidecar decoding — 2026-10-23

The same failure affects `tests/lib/ffi/model/policy.sml` on the pinned
MLKit 4.7.25. Rune, MLton, all three SML/NJ builds and Poly/ML pass the
48 checks. The default MLKit build corrupts a JSON member name in the first
valid sidecar. GDB shows `ForeignJson.object` trying to concatenate
`"unknown field: "` with a pair pointer interpreted as a string; the runtime
requests an impossible allocation, or dies with SIGSEGV. Peak RSS before
failure is about 7 MiB, so increasing the heap is not the remedy.

The same sources, compiler and 2 GiB address-space limit pass all 48 checks
with `-no_ri`. Removing source-adjacent caches and rebuilding does not fix
the default mode. The production libraries are unchanged for this compiler
fault. The native library suite records `ffi.model.policy` as `HOST-BUG`;
`ffi/model/mlkit-no-ri` retains the successful comparison as a separate job.

The target profile decoder added on the same date reproduces this fault:
`tests/lib/ffi/model/target.sml` stops with `alloc_lobjs: malloc returned
NULL` in the default configuration, while the same sources pass all **19**
checks with `-no_ri` under the same bounded host harness. The separate
`ffi/model/target-mlkit-no-ri` job preserves that comparison. Production
JSON and target decoding remain unchanged for MLKit.

The complete Runeffi generator reproduces the same failure (2026-10-23).
The default MLKit build compiles successfully, prints the inspection start
marker and exits with SIGSEGV (status 139) while decoding the original
`tests/ffi/generator/scalars.ffi` sidecar and target profile. The same
generator sources and inspection entrypoint compiled with `-no_ri` produce
exactly the same JSON artifact report as Rune. The explicit
`ffi/generator/mlkit-no-ri` job records that successful comparison;
`tests/ffi/generator-deviations.txt` retains the default failure as a strict
`HOST-BUG` expectation. A successful default run makes the expectation stale.
No production generator or library source is changed for the compiler fault.


## Generator library fixture — 2026-10-23

The default MLKit 4.7.25 build of the unchanged
`tests/lib/ffi/model/generate.sml` also exits with SIGSEGV (139), before
printing its first test verdict. A debugger backtrace stops in
`concatStringML` at `String.c:144`, called by generated
`L_ret_funcall_5A9g6iZHcn7joPTlRoDjQo`; the program has empty stdout.
The same original source list, compiler, and fixture compiled with
`-no_ri` pass **all 32 checks**, including both duplicate callback selector
checks. No production or fixture source is changed.

Reproduce the default mode with:

```
NATIVE_HOST=yes bin/rune-test run 'lib-hosts/mlkit/ffi.model.generate' --keep
```

The distinct `lib-hosts/mlkit/ffi.model.generate-no-ri` job builds that
same source list with a compiler wrapper adding only `-no_ri`, under the
same 2 GiB address-space and 600 second limits. It compares every named
verdict and the exact 32/32 summary. This positive comparison is labeled
explicitly; it does not replace the default-region execution or claim
that it passed.

For this new deviation the native judge accepts only a successful build,
status 139, and empty pre-verdict output. A build failure, timeout,
post-verdict crash, or different output remains unexpected. The separate
positive comparison and retained debugger evidence support attributing
this observation to the region-inference configuration, rather than
classifying arbitrary generator failures as host defects.

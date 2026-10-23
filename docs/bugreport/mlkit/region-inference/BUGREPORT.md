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

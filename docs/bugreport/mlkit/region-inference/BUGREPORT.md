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

# The fourth quadrant: Rune compiling another system's Basis

The matrix tests three of the four ways to pair a compiler with a library:

| | Rune's library | a host's library |
| --- | --- | --- |
| **Rune compiles** | `rune` | **missing** |
| **a host compiles** | `xc1:HOST` | `native:HOST` |

This is what the fourth would take. It was measured on 2026-09-21, not built.

## What it would prove

`xc1` shows that Rune's *library* does not depend on accidents of Rune, and
`native` shows that the *tests* are not a misreading of the specification.
Neither exercises Rune's *compiler* on a large body of SML written by other
people to another compiler's habits. That is what the fourth quadrant is for,
and it is why the answer matters even though no user will ever want to run
MLton's Basis on Rune's VM.

## What it needs

Only MLton ships its Basis sources in what `make hosts` fetches: 206 files
under `sml/basis`. Poly/ML's are in its source tarball and SML/NJ's are not
fetched at all, so MLton is where to start.

`tests/external/probe-host-basis.sh` gives every file to
`rune --no-prelude --typecheck-only --allow-prim` and counts what happens.
For MLton 20241230:

| | files | |
| --- | ---: | --- |
| `ok` | 10 | Rune took the file whole |
| `unbound` | 183 | it parses and elaborates as far as a name from the rest of that library |
| `fixity` | 8 | it parses where the ambient fixity is the one the build sets |
| `syntax` | 5 | Rune's parser will not take it |

**201 of 206 files already get past Rune's parser.** That is the finding: the
work is not in the frontend. The three things left are, in order of size:

1. **A shim for MLton's primitive layer.** The 183 `unbound` files want
   `Primitive`, `PrimitiveTypes`, `Basis1997`, `PosixError` and the rest. The
   layer is 13 files and about 3,000 lines under `primitive/`, declaring 378
   distinct `_prim` names and 631 `_import`s -- of which `basis-ffi.sml`
   alone is 1,373 lines of `_import`. Writing it over Rune's roughly 200
   primitives is the bulk of the project, and it is about the size of Rune's
   own `tests/basis/host/rune-prim.sml` turned around. It has to be written
   once per host.
2. **Five files Rune's parser rejects**, which are MLton's own syntax:
   `_overload` in MLton's form (`libs/basis-1997/top-level/overloads.sml` and
   the 2002 one), and `_address`, `_symbol` and `_import` expressions
   (`primitive/basis-ffi.sml`, `primitive/prim-mlton.sml`,
   `primitive/prim1.sml`). These are exactly the files the shim replaces, so
   they cost nothing extra; Rune's parser does not need to grow.
3. **`.mlb` semantics.** The order of the files, the scoping of
   `local ... in ... end` across them, and the ambient fixity: MLton compiles
   parts of the basis with `<` and `>` not infix, which is why
   `fun > (a, b) = < (b, a)` in `util/real-comparisons.sml` is prefix
   application there and eight files need a `nonfix` before them here. A
   small `.mlb` reader, or a generated file list with the fixity written in.

## What it would not prove

A shim makes MLton's Basis run on Rune's *primitives*, so what is tested is
Rune's compiler on MLton's SML, not MLton's library on its own terms: a
difference in, say, `Real.fmt` would be Rune's arithmetic under MLton's
algorithm. That is still worth having -- it is 200 files of unfamiliar SML --
but it is not a conformance test of MLton's library.

## Recommendation

Do it for MLton only, as `xc2:mlton`, and size it as its own roadmap: the
shim is the whole of the work and is not a session's worth. Until then,
`tests/external/run-mlton.sh` already runs MLton's regression programs
through Rune, which is the other way of putting Rune's compiler in front of
somebody else's SML, and `probe-host-basis.sh` re-measures the gap whenever
the frontend changes.

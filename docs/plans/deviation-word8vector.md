# Deviation: `Word8Vector.vector` admits equality

Found on 2026-10-18 while answering a question about the utf8 roadmap
(`docs/plans/utf8.md` on branch `utf8`, D18 and M8). This note records it for
later; nothing has been changed.

## What

In Rune, `Word8Vector.vector` admits equality. No other monomorphic vector
does. The specification promises it for none of them.

Probes, compiled by `bin/rune` at master `9b327248`:

| Program | Rune |
|---|---|
| `Word8Vector.fromList [0w1, 0w2] = Word8Vector.fromList [0w1, 0w2]` | `true` |
| the same with `Word16Vector` | error: "type vector does not admit equality" |
| the same with `IntVector` | error: "type vector does not admit equality" |
| the same with `BoolVector` | error: "type vector does not admit equality" |
| `s = s`, with `s` a `Word8VectorSlice.slice` | error: "type slice does not admit equality" |
| `a = a`, with `a` a `Word8Array.array` | `true`, as `MONO_ARRAY`'s `eqtype array` requires |

## Why

**The specification** declares `structure Word8Vector :> MONO_VECTOR where
type elem = Word8.word`, as it declares `Word16Vector`, `IntVector` and the
rest. `MONO_VECTOR` writes `type vector`, not `eqtype vector`, so that
`RealVector` can exist.

**In Rune,** the vectors are built in two ways:
- **`Word8Vector`** is a `string` underneath. The structure `RuneByteVector`
  seals it with `RUNE_MONO_VECTOR_BYTES`, which includes `MONO_VECTOR_EQ`, so
  inside the library its `vector` is an equality type
  (`lib/basis/word8vector.sml:24-26`, `lib/basis/mono_sigs.sml:1026-1031`).
  The public binding is a transparent ascription,
  `structure Word8Vector : MONO_VECTOR where type elem = Word8.word =
  Word8Vector` (`lib/basis/seal_word8vector.sml:4`), and a transparent
  ascription does not take equality away.
- **Every other monomorphic vector** is sealed `:> MONO_VECTOR` directly, for
  example `Word16Vector :> MONO_VECTOR where type elem = Word16.word =
  RuneMonoVectorFn (...)` (`lib/basis/mono_word16.sml:9`). Its `vector` is
  abstract without equality.

**It is recorded nowhere.**
- No `Deviation:`, `Implementation:` or `Reading:` note mentions it.
  `docs/lib/basis/readings.md` has only `Byte/free`, which says a
  `Word8Vector.vector` is a `string` underneath.
- No test in `tests/basis` pins the equality of `Word8Vector`, or its absence
  on the other vectors. The arrays have such checks
  (`*Array:MONO_ARRAY/eqtype` in `tests/basis/mono.*_sig.sml`); the vectors
  have none.

## What the other systems do

| | `=` on `Word8Vector.vector` | `=` on `IntVector.vector` |
|---|---|---|
| Rune | yes | no |
| SML/NJ 110.99.9 | yes | no `IntVector` |
| Poly/ML 5.9.2 | yes | yes |
| MLton 20241230 | yes | no |
| MLKit | not probed | not probed |

Every major system gives `Word8Vector` equality, so programs compare byte
buffers with `=` and expect it to work. Rune matches MLton exactly.

## Why it matters for the utf8 roadmap

The roadmap's D18 and M8 remove `MONO_VECTOR_EQ` from the public library,
because `WideCharVector` no longer needs it once it is pinned to
`WideString.string`. The signature has to survive inside the library, as E6
found, under the name `RUNE_MONO_VECTOR_EQ`.

The reason is this deviation. SML has no `where eqtype`, so saying "this
abstract vector admits equality" needs a signature that declares `eqtype
vector`. Without it, `Word8Vector` would lose equality, and programs that run
on every other system would stop compiling.

The roadmap's sentence (*The architecture*, *The symmetric text signatures*;
and E6), "because `Word8Vector`'s type is born at a vector seal and keeps its
equality that way", describes this mechanism but not the deviation behind it.

## The options

* **A. Keep it, and record it.** **Recommended.**
  - A `Deviation:` note on `Word8Vector`, pinned by a test that `=` works on
    it.
  - Tests that `=` does not work on the other vectors.
  - `deviations.txt` lines where a host differs, such as `native:polyml` for
    `IntVector`.
  - It matches MLton and the behaviour of every major system, and no
    program changes.
* **B. Give equality to every monomorphic vector whose elements admit it:**
  `Word16Vector`, `IntVector`, `BoolVector` and the others, but not
  `RealVector` or `Real32Vector`.
  - It is symmetric, and matches Poly/ML.
  - It is a wider deviation.
  - It needs each vector sealed with an `eqtype vector` signature, as
    `Word8Vector` is.
* **C. Remove it,** as the specification reads.
  - It breaks programs that compare byte buffers with `=`, which work on
    SML/NJ, Poly/ML and MLton.

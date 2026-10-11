# SML/NJ 110.99.9 and 2026.2: `inputAll` of a stream over an empty string or vector raises `Io` with the cause `Div`

## Status: reported and fixed upstream, after 110.99.9 and 2026.2

* **The report:** [smlnj/smlnj#449](https://github.com/smlnj/smlnj/issues/449),
  "`TextIO.inputAll` fails with 'divide by zero' error on empty stream"
  (2026-08-30).
* **The fix:** commit `60f1f56` of smlnj/smlnj (2026-09-01), for `TextIO`
  and `BinIO` alike; the first tag with it is `v2026.3-beta`. smlnj/legacy
  has it since `87b5080` (2026-09-03, "merge in fixes from the development
  repo"), so the next 110 release will too.
* **Releases:** 110.99.9 and 2026.2, the newest of each line, have the
  bug.

**What is worth sending SML/NJ:** nothing about `inputAll`. At most a
remark on #449 that the readers themselves still break the specification
(below, "What is left").

## Summary

* **The trigger:** `inputAll` of a stream whose reader has no elements
  from the start: `TextIO.openString ""`, `TextPrimIO.openVector ""`,
  `BinPrimIO.openVector` of an empty vector; functional
  (`TextIO.StreamIO.inputAll`, `BinIO.StreamIO.inputAll`) and imperative
  (`TextIO.inputAll`, `BinIO.inputAll`) alike.
* **What goes wrong:** it raises
  `Io {function = "inputAll", cause = Div, ...}` instead of returning the
  empty vector. `input` of the same stream gives `""`, and `inputAll` of a
  non-empty one works.
* **Required behaviour:** the
  [Basis `STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html#SIG:STREAM_IO.inputAll:VAL):
  "`inputAll f` returns the vector of the rest of the elements in the
  stream `f` (i.e., up to an end-of-stream)", here none. MLton and Poly/ML
  return the empty vector (#449).

## Where it happens

| Build | wrong of 8 |
|---|---|
| 110.99.9, 64-bit | 5 |
| 110.99.9, 32-bit | 5 |
| 2026.2 (64-bit) | 5 |
| smlnj/legacy `6ed5a0a`, smlnj/smlnj `17362d2` (by reading the code) | 0 |

```
$ sml bug.sml                           # 110.99.9 (32 or 64 bits) or 2026.2
TextIO.inputAll (openString "") = Io {function = "inputAll", cause = Div}, expected "": WRONG
TextIO.StreamIO.inputAll (getInstream (openString "")) = Io {function = "inputAll", cause = Div}, expected "": WRONG
TextIO.StreamIO.inputAll over TextPrimIO.openVector "" = Io {function = "inputAll", cause = Div}, expected "": WRONG
BinIO.StreamIO.inputAll over BinPrimIO.openVector of no bytes = Io {function = "inputAll", cause = Div}, expected 0 bytes: WRONG
BinIO.inputAll over BinPrimIO.openVector of no bytes = Io {function = "inputAll", cause = Div}, expected 0 bytes: WRONG
TextIO.inputAll (openString "ab") = "ab", expected "ab": ok
TextIO.input (openString "") = "", expected "": ok
chunkSize of TextPrimIO.openVector "" = 0
the same reader with chunkSize 1, inputAll = "", expected "": ok
```

## The cause

The readers of an empty string or vector have `chunkSize = 0`: `openVector`
(`IO/prim-io-fn.sml`) and `strReader` (`Unix/posix-text-prim-io.sml`,
`Win32/win32-text-prim-io.sml`) set `chunkSize = len`. `inputAll` reads
through `readChunk` (`IO/text-io-fn.sml`, and the same in
`IO/bin-io-fn.sml`), which rounds the request up to a multiple of the chunk
size:

```sml
case (chunkSize - 1)
 of 0 => (fn n => readVec n)
  | k => (* round up to next multiple of chunkSize *)
      (fn n => readVec(Int.quot((n+k), chunkSize) * chunkSize))
```

With `chunkSize = 0` that is `Int.quot (n - 1, 0)`: `Div`, which
`extendStream` wraps in `Io`. The last line of `bug.sml` gives the same
empty reader the chunk size 1, and `inputAll` returns `""`.

## The fix upstream, and what is left

`60f1f56` makes `readChunk` test `chunkSize <= 1` instead of
`chunkSize - 1 = 0`, in both functors, so a chunk size of 0 reads what is
asked. That is the whole of the symptom. It has not been run here: no
build with it was made.

**What is left:** the readers still have `chunkSize = 0`, and the
[`PRIM_IO` specification](https://smlfamily.github.io/Basis/prim-io.html#SIG:PRIM_IO.reader:TY)
says "chunkSize <= 0 is illegal". A program that takes the chunk size of
such a reader (`TextIO.StreamIO.getReader`) and divides by it fails the
same way. `chunkSize = Int.max (len, 1)` in `openVector` and the two
`strReader`s would mend that; no `fix.diff` is included, as upstream has
dealt with the symptom.

## How Rune met it

By the laws of Rune's Basis Library documentation: each `Law:` is tested
on generated values, and `tests/basis/run-laws-hosts.py` runs them against
the Basis Library of the other compilers (`docs/plans/quickcheck-hunt.md`,
the sections on the other compilers). The arbitraries of instreams in
`lib/test/property` show a drawn stream by reading it all with `inputAll`,
so on SML/NJ every law over an instream fails at the empty one: the lines
`native:smlnj* | STREAM_IO.input/law-1@*`, `STREAM_IO.input1/law-1@*` and
`IMPERATIVE_IO.*@*` of `tests/basis/law-deviations.txt`. Rune's Basis
suite had found `openString ""` before (`TextIO.openString/empty` in
`tests/basis/deviations.txt`).

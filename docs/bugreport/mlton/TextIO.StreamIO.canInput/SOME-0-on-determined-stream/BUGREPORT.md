# MLton 20241230: `StreamIO.canInput` answers `SOME 0` (end-of-stream) on a stream that has been read ahead, and so do `TextIO.canInput` and `BinIO.canInput`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (SML/NJ 110.99.9 and 2026.2, Poly/ML 5.9.2 and MLKit 4.7.23) does this.** In cases 1 to 3 below, SML/NJ, Poly/ML and MLKit answer `SOME 1`. In case 4, SML/NJ also answers `SOME 0`, but its `input` then returns nothing at all: it loses the bytes that `canInput` read ahead, a different fault of its own.

## Status

**Fixed upstream after 20241230, and not yet released.** Pull request
[#656](https://github.com/MLton/mlton/pull/656) ("Fix bug in
`StreamIO().canInput` on determined stream", merged 2026-09-19) makes the
change of `fix.patch` and also updates the copyright line. Its `CHANGELOG.adoc` entry reads: "Fix
bug in `TextIO.StreamIO.canInput` (and `BinIO.StreamIO.canInput` and
`SteamIO().canInput`) that would return `SOME 0` on a stream that had been
partly determined." It credits "https://github.com/Skyb0rg007/sml-basis-tests
for the (implicit) bug report", and adds the regression test
`regression/textio.5.sml`, whose first half is case 1 below. The latest release
is still 20241230 (checked on 2026-10-11), so every released MLton has the
bug. Nothing needs sending upstream. This report records the fault
for the pinned 20241230. Also found by the search, and not this bug:
[#535](https://github.com/MLton/mlton/issues/535) / pull request #536 (an
earlier `getInstream` fault, fixed in 2023 and in 20241230) and
[#649](https://github.com/MLton/mlton/issues/649) (`inputAll` and
`endOfStream`). The search covered issues and pull requests for `canInput`,
`getInstream`, `imperative`, `StreamIO`, `TextIO` and `BinIO`.

## Summary

* **The trigger:** `StreamIO.canInput (s, n)`, with `n >= 1`, on a
  functional stream `s` whose current buffer is used up and whose next
  buffer has already been read, for example after `StreamIO.input s` or
  `StreamIO.inputAll s`. Through the imperative streams the same happens:
  * `TextIO.canInput (f, n)` or `BinIO.canInput (f, n)` once the stream of
    `getInstream f` has been read ahead;
  * `BinIO.StreamIO.canInput (BinIO.getInstream h, n)` after
    `BinIO.canInput (h, n)` read ahead, where `h` was made by `mkInstream`
    from a functional stream.
* **What goes wrong:** `canInput` answers `SOME 0`, which means
  end-of-stream, although `input` then returns the elements.
* **Required behaviour:** the
  [Basis `STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html#SIG:STREAM_IO.canInput:VAL)
  says that `canInput (f, n)` "returns NONE if any attempt at input would
  block. It returns SOME(k), where 0 <= k <= n, if a call to input would
  return immediately with at least k characters. Note that k = 0
  corresponds to the stream being at end-of-stream." The
  [`IMPERATIVE_IO` specification](https://smlfamily.github.io/Basis/imperative-io.html#SIG:IMPERATIVE_IO.canInput:VAL)
  says the same of `canInput (strm, n)`. The discussion of
  `STREAM_IO` states this very case as a property: "If a stream has
  already been at least partly determined, then input cannot possibly
  block:"

  ```sml
  fun noBlock f = let 
   val (s,_) = TS.input f
   in 
   case TS.canInput (f, 1) of
   SOME 0 => (size s) = 0
   | SOME _ => (size s) > 0
   | NONE => false
   end
  ```

  MLton 20241230 fails `noBlock` whenever the stream's own buffer is used
  up and `input` gives a non-empty vector. Every fresh stream of
  `getInstream (TextIO.openString "ab")` is such a stream (case 1).

## Environment

* **MLton:** 20241230, the official binary release (`mlton` prints
  "MLton 20241230").
* **System:** Linux x86-64, Ubuntu 24.04 on WSL2 (kernel
  6.18.33.2-microsoft-standard-WSL2), glibc 2.39.
* **Basis Library: MLton's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlton bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "SOME(k) ... if a call to input would return immediately with at least k
   characters. Note that k = 0 corresponds to the stream being at
   end-of-stream." *)
fun opt NONE = "NONE" | opt (SOME k) = "SOME " ^ Int.toString k
fun show (what, f) = print (what ^ " = " ^ (f () handle e => "raised " ^ exnName e) ^ "\n")

(* 1. The functional stream alone, once input has read from it: the
      specification's noBlock. *)
val s = TextIO.getInstream (TextIO.openString "ab")
val (v, _) = TextIO.StreamIO.input s
val () = show ("1. StreamIO.input s gives \"" ^ v ^ "\"; StreamIO.canInput (s, 1)",
               fn () => opt (TextIO.StreamIO.canInput (s, 1)) ^ "   (expected SOME 1)")

(* 2. TextIO: the stream of getInstream f read to its end, then f itself. *)
val f = TextIO.openString "ab"
val _ = TextIO.StreamIO.inputAll (TextIO.getInstream f)
val () = show ("2. TextIO.canInput (f, 1)", fn () => opt (TextIO.canInput (f, 1)) ^ "   (expected SOME 1)")
val () = show ("2. TextIO.input f", fn () => "\"" ^ TextIO.input f ^ "\"")

(* 3. BinIO over a file of two bytes, likewise. *)
val name = OS.FileSys.tmpName ()
val () = let val out = BinIO.openOut name
         in BinIO.output (out, Word8Vector.fromList [0w1, 0w2]); BinIO.closeOut out end
val g = BinIO.openIn name
val _ = BinIO.StreamIO.inputAll (BinIO.getInstream g)
val () = show ("3. BinIO.canInput (g, 1)", fn () => opt (BinIO.canInput (g, 1)) ^ "   (expected SOME 1)")
val () = show ("3. Word8Vector.length (BinIO.input g)", fn () => Int.toString (Word8Vector.length (BinIO.input g)))
val () = (BinIO.closeIn g; OS.FileSys.remove name)

(* 4. BinIO over a reader of two bytes: canInput of the imperative stream reads
      ahead, and then the functional stream it is built on answers SOME 0. *)
val h = BinIO.mkInstream (BinIO.StreamIO.mkInstream
          (BinPrimIO.openVector (Word8Vector.fromList [0w1, 0w2]), Word8Vector.fromList []))
val () = show ("4. BinIO.canInput (h, 5)", fn () => opt (BinIO.canInput (h, 5)) ^ "   (expected SOME 2)")
val () = show ("4. BinIO.StreamIO.canInput (getInstream h, 5)",
               fn () => opt (BinIO.StreamIO.canInput (BinIO.getInstream h, 5)) ^ "   (expected SOME 2)")
val () = show ("4. Word8Vector.length (BinIO.input h)", fn () => Int.toString (Word8Vector.length (BinIO.input h)))
```

```
$ mlton bug.mlb && ./bug
1. StreamIO.input s gives "ab"; StreamIO.canInput (s, 1) = SOME 0   (expected SOME 1)
2. TextIO.canInput (f, 1) = SOME 0   (expected SOME 1)
2. TextIO.input f = "ab"
3. BinIO.canInput (g, 1) = SOME 0   (expected SOME 1)
3. Word8Vector.length (BinIO.input g) = 2
4. BinIO.canInput (h, 5) = SOME 2   (expected SOME 2)
4. BinIO.StreamIO.canInput (getInstream h, 5) = SOME 0   (expected SOME 2)
4. Word8Vector.length (BinIO.input h) = 2
```

In case 2, `StreamIO.canInput (TextIO.getInstream f, 1)` is `SOME 0` as
well: after the first `getInstream`, `f` and its stream are one stream (see
below).

## The other implementations

The same `bug.sml`, run on each of them:

| | 1 | 2 | 3 | 4: `canInput (h, 5)` | 4: of `getInstream h` | 4: `input h` |
|---|---|---|---|---|---|---|
| MLton 20241230 | `SOME 0` | `SOME 0` | `SOME 0` | `SOME 2` | `SOME 0` | 2 bytes |
| SML/NJ 110.99.9 (64 bits), 2026.2 | `SOME 1` | `SOME 1` | `SOME 1` | `SOME 2` | `SOME 0` | 0 bytes |
| Poly/ML 5.9.2 | `SOME 1` | `SOME 1` | `SOME 1` | raises `Io` | raises `Io` | 1 byte |
| MLKit 4.7.23 | `SOME 1` | `SOME 1` | `SOME 1` | `SOME 2` | `SOME 2` | 2 bytes |
| Rune | `SOME 1` | `SOME 1` | `SOME 1` | `SOME 2` | `SOME 2` | 2 bytes |

In cases 2 and 3 every implementation's `input` gives the two elements. In
case 4, Poly/ML's `BinPrimIO.openVector` reader has no `readVecNB`, so its
`canInput` raises `Io` (`NonblockingNotSupported`), as it may. SML/NJ's
`SOME 0` in case 4 goes with an `input` that returns no bytes. The two
bytes that `canInput (h, 5)` read are lost, which Rune's
`tests/basis/deviations.txt` records for `smlnj*`.

## The cause

`basis-library/io/stream-io.fun`, `canInput` (line 649), ends:

```sml
             in
               if pos < V.length inp
                 then SOME (Int.min (V.length inp - pos, n))
                 else case !next of
                        End => 
                          (case extendNB "canInput" is of
                             NONE => NONE
                           | SOME (Link {buf = Buf {inp, base, ...}}) =>
                               let
                                 val (inp, k) = start inp
                                 val buf = Buf {inp = inp,
                                                base = base,
                                                next = ref End}
                               in
                                 next := Link {buf = buf};
                                 SOME k
                               end
                           | SOME (Eos _) => SOME 0
                           | _ => raise Fail "extendNB bug")
                      | _ => SOME 0
             end
```

When the elements of the current buffer are used up (`pos` is its length),
`canInput` looks at the next buffer. If nothing has been read past this
buffer (`End`), it reads ahead. But if the next buffer has already been read,
`!next` is `Link {...}`, and the last case answers `SOME 0` as if it were
`Eos`.

A stream that `getInstream` makes of an imperative stream with nothing
buffered starts with an empty buffer (`mkInstream'`, line 729:
`Buf {inp = empty, ...}`). So every stream of
`getInstream (openString "ab")` is in this state once anything has read
past it. That gives case 1.

The imperative streams pass through to it.
`basis-library/io/imperative-io.fun`, `getInstream` (line 646), turns the
imperative stream into its functional stream for good,
`val () = setInstream (ib, s)` (line 684). From then on `f`'s state is
`Stream s`, and `canInput` (line 515) ends:

```sml
       | Stream s => SIO.canInput (s, n)
```

and `input` is `SIO.input s`. In cases 2 and 3, `inputAll` of `s` reads past
its empty first buffer, so `canInput (f, 1)` is `SIO.canInput (s, 1)` and
answers `SOME 0`, while `input f` follows the link to the two elements.

In case 4, `BinIO.mkInstream` gives the state `Stream s` at once.
`BinIO.canInput (h, 5)` is `SIO.canInput (s, 5)`: `next` is `End`, so it
reads the two bytes ahead, links them, and answers `SOME 2`.
`BinIO.getInstream h` is that same `s`, and now its `next` is a `Link`, so
the second `canInput` answers `SOME 0`. The stream of `getInstream h` does
hold the bytes (`input h` returns them), and only `canInput` misses them.

## The fix

Answer from the next buffer when it has been read (`fix.patch`, the change
of #656 to this file, which applies to 20241230 unchanged):

```diff
--- a/basis-library/io/stream-io.fun
+++ b/basis-library/io/stream-io.fun
@@ -680,7 +680,8 @@
                if pos < V.length inp
                  then SOME (Int.min (V.length inp - pos, n))
                  else case !next of
-                        End => 
+                         Link {buf as Buf {inp, ...}} => SOME (Int.min (V.length inp, n))
+                       | End =>
                           (case extendNB "canInput" is of
                              NONE => NONE
                            | SOME (Link {buf = Buf {inp, base, ...}}) =>
```

`Eos`, `Truncated` and `Closed` still answer `SOME 0`. The answer counts
only the next buffer, but the specification only asks that `canInput`
"should attempt to return as large a k as possible".

How it was tested: MLton compiles its Basis Library from source into every
program, so the fix was built without rebuilding MLton. The
installed library (`lib/mlton/sml/basis`, identical to `basis-library` of
the 20241230 sources) was copied with this patch applied and used with
`mlton -mlb-path-var 'SML_LIB <copy>' bug.mlb`. `bug.sml` then gives
`SOME 1`, `SOME 1`, `SOME 1`, `SOME 2` and `SOME 2`, and `input` still gives
the two elements in cases 2 to 4. Rune's suite, built the same way with the
patches of all four MLton reports of this directory:

* `tests/basis/textio_streamio.sml` goes from 193 checks with 7 failed to 6
  failed (`TextIO.StreamIO.canInput/determined-stream-does-not-block` now
  passes).
* `tests/basis/binio_streamio.sml` goes from 180 checks with 8 failed to 7
  (`BinIO.StreamIO.canInput/determined-stream-does-not-block`).
* `tests/basis/binio.sml` has the same 5 failures out of 150 before and
  after.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` in
`lib/basis` is tested on generated values. The laws were run against MLton's
own Basis Library with `tests/basis/run-laws-hosts.py`. The run is
described in the section "D10 on the split library" of
`docs/plans/quickcheck-hunt.md`, under "MLton's `canInput` after a read
through `getInstream`". The law of `IMPERATIVE_IO.canInput` in
`lib/basis/sig_imperative_io.sml`,
`canInput (f, n) = StreamIO.canInput (getInstream f, n)`, met cases 2 and 3
only through a fault of the tester. Showing the left side's value read the
stream through `getInstream` before the sides ran. Once that was mended no
law reached the cases, so they have no line in
`tests/basis/law-deviations.txt`. Case 4 is a counterexample to that same
law at `BinIO`, with an instream made by `mkInstream`: the left side reads
ahead, and the right side then answers `SOME 0`. It was met on 2026-10-11,
while the law was being restated.

Rune's Basis Library suite had already met the fault in its functional
form, case 1. The checks `TextIO.StreamIO.canInput/determined-stream-does-not-block`
and `BinIO.StreamIO.canInput/determined-stream-does-not-block`
(`tests/basis/textio_streamio.sml`, `tests/basis/binio_streamio.sml`,
which test the specification's `noBlock`) are recorded as a known
`HOST-BUG` for `mlton@*` in `tests/basis/deviations.txt` ("canInput on a
stream whose elements input has already read answers SOME 0, which means
end-of-stream (the noBlock predicate of stream-io.html)").

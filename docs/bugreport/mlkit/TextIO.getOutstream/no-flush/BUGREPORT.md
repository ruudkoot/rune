# MLKit 4.7.23: `TextIO.getOutstream` and `TextIO.setOutstream` do not flush the stream

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/imperative-io.sml` as the tag
`v4.7.23`, byte for byte, so the code below is unchanged there; `master`
was not built here. MLton's Basis Library, which the file comes from,
fails Rune's checks of this in the same way (release 20241230), and so do
SML/NJ 110.99.9 and Poly/ML 5.9.2.

## Summary

* **The trigger:** `getOutstream strm` or `setOutstream (strm, strm')` of
  `TextIO` or `BinIO` when `strm` has output in its buffer.
* **What goes wrong:** neither function flushes: the buffered output is
  not written. After `getOutstream` it stays in the buffer of the
  `StreamIO` stream that `getOutstream` returns; after `setOutstream` it
  stays in the buffer of the old `StreamIO` stream, which the imperative
  stream no longer refers to.
* **Required behaviour:** the
  [`IMPERATIVE_IO` specification](https://smlfamily.github.io/Basis/imperative-io.html)
  says that `getOutstream strm` "flushes strm and returns the underlying
  StreamIO output stream", and that `setOutstream (strm, strm')` "flushes
  the stream underlying strm, and then assigns a new low-level stream
  strm' to it."

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml` writes two characters to a file, which `openOut` makes block
buffered, calls `getOutstream` or `setOutstream`, and reads the file:

```sml
(* getOutstream and setOutstream on an output stream with buffered output *)
fun slurp name = let val ins = TextIO.openIn name in TextIO.inputAll ins before TextIO.closeIn ins end
fun report (what, name) = print (what ^ ": the file holds \"" ^ slurp name ^ "\"\n")

(* a file that is not a terminal: TextIO.openOut makes it block buffered *)
val out = TextIO.openOut "a.txt"
val () = TextIO.output (out, "ab")
val _ = TextIO.getOutstream out
val () = report ("after getOutstream", "a.txt")

val out = TextIO.openOut "b.txt"
val () = TextIO.output (out, "ab")
val other = TextIO.openOut "c.txt"
val () = TextIO.setOutstream (out, TextIO.getOutstream other)
val () = report ("after setOutstream", "b.txt")
```

```
$ mlkit -o bug bug.mlb && ./bug
after getOutstream: the file holds ""
after setOutstream: the file holds ""
```

Both lines should say `"ab"`.

## The cause

In `basis/io/imperative-io.sml` the imperative output stream is a
reference to a `StreamIO` output stream, and the two functions read and
assign it without flushing, in the functor `ImperativeIOExtra`, which
`TextIO` and `BinIO` apply (lines 85-86):

```sml
fun getOutstream (Out os) = !os
fun setOutstream (Out os, os') = os := os'
```

and in the same way in the functor `ImperativeIO` (lines 805-806).

## The fix

```diff
--- a/basis/io/imperative-io.sml
+++ b/basis/io/imperative-io.sml
@@ -82,8 +82,8 @@
 fun flushOut (Out os) = SIO.flushOut (!os)
 fun closeOut (Out os) = SIO.closeOut (!os)
 fun mkOutstream os = Out (ref os)
-fun getOutstream (Out os) = !os
-fun setOutstream (Out os, os') = os := os'
+fun getOutstream (Out os) = (SIO.flushOut (!os); !os)
+fun setOutstream (Out os, os') = (SIO.flushOut (!os); os := os')
 fun getPosOut (Out os) = SIO.getPosOut (!os)
 fun setPosOut (Out os, outPos) = os := SIO.setPosOut outPos
 
@@ -802,8 +802,8 @@
       fun flushOut (Out os) = SIO.flushOut (!os)
       fun closeOut (Out os) = SIO.closeOut (!os)
       fun mkOutstream os = Out (ref os)
-      fun getOutstream (Out os) = !os
-      fun setOutstream (Out os, os') = os := os'
+      fun getOutstream (Out os) = (SIO.flushOut (!os); !os)
+      fun setOutstream (Out os, os') = (SIO.flushOut (!os); os := os')
       fun getPosOut (Out os) = SIO.getPosOut (!os)
       fun setPosOut (Out os, out_pos) = os := SIO.setPosOut out_pos
 
```

`StreamIO.flushOut` is a no-op on a terminated or closed stream, so
`getOutstream` of a closed stream still returns it.

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions: `bug.sml` then prints `"ab"` on both
lines, and Rune's Basis Library tests of `BinIO`, `TextIO`, their
`StreamIO`, `IO`, the `PrimIO` functors, `OS.IO` on the standard streams
and `Unix` show no new failure. The change to the functor `ImperativeIO`
is compiled and the functor applied by Rune's test of the I/O functors,
which passes, but nothing here calls its `getOutstream` or
`setOutstream`. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks this in
`tests/basis/fn/imperative_io_fn.sml` (`getOutstream/flushes`,
`setOutstream/flushes-the-old-stream`), which
`tests/basis/binio_streamio.sml` and `tests/basis/textio_streamio.sml`
apply to `BinIO` and `TextIO`; all four checks fail on MLKit with
`got "", expected "ab"`. The failures are explained by this line of
`tests/basis/deviations.txt`, worded as the ones for MLton, SML/NJ and
Poly/ML:

```
native:mlkit@* | *IO.[gs]etOutstream/flushes* | HOST-BUG | getOutstream and setOutstream do not flush the stream ("flushes strm and returns the underlying StreamIO output stream", "flushes the stream underlying strm, and then assigns")
```

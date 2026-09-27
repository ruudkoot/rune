# MLKit 4.7.23: `TextIO.output1` on a closed stream raises `Io` with function `"output"`

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/stream-io.sml` as the tag `v4.7.23`,
byte for byte, so the code below is unchanged there; `master` was not
built here. The code comes from MLton's Basis Library, whose release
20241230 has the same `ensureActive` and fails Rune's check in the same
way.

## Summary

* **The trigger:** `TextIO.output1`, `BinIO.output1` or
  `TextIO.StreamIO.output1` on a stream that is closed (or, for
  `StreamIO`, terminated by `getWriter`).
* **What goes wrong:** the exception is
  `IO.Io {function = "output", cause = IO.ClosedStream, ...}`: the
  `function` field names `output`, a function that was not called.
* **Required behaviour:** the
  [`IO` specification](https://smlfamily.github.io/Basis/io.html) says of
  the field `function` of `Io`: "The name of the function raising the
  exception." `output1` should raise
  `IO.Io {function = "output1", ...}`.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* output1 and output on an output stream that has been closed *)
fun describe f =
  (f (); "no exception")
  handle IO.Io {function, name, cause} =>
           "Io {function = \"" ^ function ^ "\", name = \"" ^ name ^ "\", cause = " ^ exnName cause ^ "}"
       | e => exnName e

val out = TextIO.openOut "a.txt"
val () = TextIO.closeOut out
val () = print ("TextIO.output1: " ^ describe (fn () => TextIO.output1 (out, #"x")) ^ "\n")
val () = print ("TextIO.output:  " ^ describe (fn () => TextIO.output (out, "x")) ^ "\n")

val bout = BinIO.openOut "b.bin"
val () = BinIO.closeOut bout
val () = print ("BinIO.output1:  " ^ describe (fn () => BinIO.output1 (bout, 0w120)) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
TextIO.output1: Io {function = "output", name = "a.txt", cause = ClosedStream}
TextIO.output:  Io {function = "output", name = "a.txt", cause = ClosedStream}
BinIO.output1:  Io {function = "output", name = "b.bin", cause = ClosedStream}
```

The first and third lines should say `function = "output1"`.

## The cause

In `basis/io/stream-io.sml`, `closeOut` and `getWriter` call
`makeTerminated`, which marks the buffer of a buffered stream full, so that
the next `output1` finds no room; `output1` then calls `ensureActive`, and
for an unbuffered stream it calls `ensureActive` first. `ensureActive`
(lines 165-168), whose only callers are the three branches of `output1`,
names `output`:

```sml
      fun ensureActive (os as Out {state, ...}) =
         if active (!state)
            then ()
         else liftExn (outstreamName os) "output" IO.ClosedStream
```

## The fix

```diff
--- a/basis/io/stream-io.sml
+++ b/basis/io/stream-io.sml
@@ -165,7 +165,7 @@
       fun ensureActive (os as Out {state, ...}) =
          if active (!state)
             then ()
-         else liftExn (outstreamName os) "output" IO.ClosedStream
+         else liftExn (outstreamName os) "output1" IO.ClosedStream
 
       local
          val buf1 = A.array (1, someElem)
```

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions: `bug.sml` then prints
`function = "output1"` on the first and third lines (and still `"output"`
on the second), and Rune's Basis Library tests of `BinIO`, `TextIO`, their
`StreamIO`, `IO`, the `PrimIO` functors, `OS.IO` on the standard streams
and `Unix` show no new failure. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks this in `tests/basis/binio.sml`
(`BinIO.output1/Io-closed-stream-function`), which fails on MLKit with
`got "output", expected "output1"`, and in `tests/basis/textio.sml`
(`TextIO.output1/Io-closed-stream-function`). The second does not run on
MLKit: `textio.sml` does not compile there, because one of its checks
compares two `TextIO.instream` values with `=`, although the specification
declares `type instream`, not `eqtype` (a mistake of the test, not of
MLKit). With that check taken out, it fails in the same way. The failure is
explained by this line of `tests/basis/deviations.txt`, worded as the one
for MLton:

```
native:mlkit@* | *IO.output1/Io-closed-stream-function | HOST-BUG | output1 on a closed stream raises Io with function "output"
```

# MLKit 4.7.23: `TextIO.StreamIO.filePosIn` of a truncated stream raises nothing

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton raises nothing either, and SML/NJ raises only once the stream is closed; Poly/ML raises `Io` after `getReader`.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/stream-io.sml` as the tag `v4.7.23`,
byte for byte, so the code below is unchanged there; `master` was not
built here. The code comes from MLton's Basis Library, whose release
20241230 has the same `filePosIn` and fails Rune's check in the same way.

## Summary

* **The trigger:** `TextIO.StreamIO.filePosIn f` (or
  `BinIO.StreamIO.filePosIn f`) after `getReader f` has truncated `f`, or
  after `closeIn f`.
* **What goes wrong:** `filePosIn` returns a position as if the stream
  were still active.
* **Required behaviour:** the
  [`STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html)
  says of `filePosIn f`: "This raises the exception Io if the stream does
  not support the operation, or if f has been truncated", and of the
  states of an input stream: "A closed stream is also truncated."

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
(* filePosIn of an input stream that getReader has truncated *)
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
fun describe f =
  (ignore (f ()); "a position, no exception")
  handle IO.Io {function, name, cause} =>
           "Io {function = \"" ^ function ^ "\", name = \"" ^ name ^ "\", cause = " ^ exnName cause ^ "}"
       | e => exnName e

val () = write ("a.txt", "abc")
val f = TextIO.getInstream (TextIO.openIn "a.txt")
val () = print ("filePosIn before getReader: " ^ describe (fn () => TextIO.StreamIO.filePosIn f) ^ "\n")
val _ = TextIO.StreamIO.getReader f
val () = print ("filePosIn after getReader:  " ^ describe (fn () => TextIO.StreamIO.filePosIn f) ^ "\n")

val g = TextIO.getInstream (TextIO.openIn "a.txt")
val () = TextIO.StreamIO.closeIn g
val () = print ("filePosIn after closeIn:    " ^ describe (fn () => TextIO.StreamIO.filePosIn g) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
filePosIn before getReader: a position, no exception
filePosIn after getReader:  a position, no exception
filePosIn after closeIn:    a position, no exception
```

The second and third lines should report `Io`.

## The cause

In `basis/io/stream-io.sml`, `getReader` and `closeIn` record the state of
the stream in the cell at its end (`!(!tail)`, which becomes `Truncated` or
`Closed`), but `filePosIn` (lines 794-814) looks only at the position the
buffer was read from:

```sml
      fun filePosIn (is as In {common = {augmented_reader, ...},
                               pos,
                               buf = Buf {base, ...}, ...}) =
        case base of
           SOME b => (case xlatePos of
                         SOME {fromInt, toInt, ...} =>
                            (fromInt (Position.+ (Position.fromInt pos, toInt b)))
                       | NONE => ...)
         | NONE => liftExn (instreamName is) "filePosIn" IO.RandomAccessNotSupported
```

## The fix

Check the state first. The specification does not name a cause;
`IO.ClosedStream` is the one `getReader` uses for the same condition:

```diff
--- a/basis/io/stream-io.sml
+++ b/basis/io/stream-io.sml
@@ -791,9 +791,13 @@
                   end)
         | _ => liftExn (instreamName is) "getReader" IO.ClosedStream
 
-      fun filePosIn (is as In {common = {augmented_reader, ...},
+      fun filePosIn (is as In {common = {augmented_reader, tail, ...},
                                pos,
                                buf = Buf {base, ...}, ...}) =
+        case !(!tail) of
+           Truncated => liftExn (instreamName is) "filePosIn" IO.ClosedStream
+         | Closed => liftExn (instreamName is) "filePosIn" IO.ClosedStream
+         | _ =>
         case base of
            SOME b => (case xlatePos of
                          SOME {fromInt, toInt, ...} =>
```

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions: `bug.sml` then prints
`Io {function = "filePosIn", name = "a.txt", cause = ClosedStream}` on the
second and third lines, and Rune's Basis Library tests of `BinIO`,
`TextIO`, their `StreamIO`, `IO`, the `PrimIO` functors, `OS.IO` on the
standard streams and `Unix` show no new failure. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks the truncated case in
`tests/basis/binio_streamio.sml` and `tests/basis/textio_streamio.sml`
(`BinIO.StreamIO.filePosIn/Io-truncated`,
`TextIO.StreamIO.filePosIn/Io-truncated`); both fail on MLKit with `no
exception raised`. It does not check the closed case. The failures are
explained by this line of `tests/basis/deviations.txt`, worded as the one
for MLton and SML/NJ:

```
native:mlkit@* | *IO.StreamIO.filePosIn/Io-truncated | HOST-BUG | filePosIn of a truncated stream raises nothing
```

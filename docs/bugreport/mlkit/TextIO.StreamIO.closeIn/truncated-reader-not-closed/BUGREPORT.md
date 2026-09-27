# MLKit 4.7.23: `TextIO.StreamIO.closeIn` of a truncated stream does not close the reader

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/stream-io.sml` as the tag `v4.7.23`,
byte for byte, so the code below is unchanged there; `master` was not
built here. The code comes from MLton's Basis Library, whose release
20241230 has the same `Close.close` and fails Rune's check in the same
way.

## Summary

* **The trigger:** `TextIO.StreamIO.closeIn f` (or
  `BinIO.StreamIO.closeIn f`) after `getReader f` has truncated `f`.
* **What goes wrong:** `closeIn` does nothing: the reader is not closed.
  For a file, its descriptor stays open and the reader goes on reading.
* **Required behaviour:** the
  [`STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html)
  describes the states of an input stream: "When disconnected from its
  underlying primitive reader (e.g., by getReader), the stream is
  truncated. When closeIn is applied to the stream, the stream enters the
  closed state. A closed stream is also truncated. The only real
  difference between a truncated stream and a closed one is that in the
  latter case, the stream's primitive I/O reader is closed." `closeIn f`
  "marks the stream closed, and closes the underlying reader", and the
  notes add: "one can close a truncated or terminated string. This is
  intended as a convenience, with the inactive stream providing a handle
  to the underlying file".

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml` closes a truncated stream on a reader that counts the calls of
its `close`, and then one on a file, whose reader it tries afterwards:

```sml
(* closeIn of an input stream that getReader has truncated *)
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end

(* a reader of "abc" that counts the calls of its close *)
val closes = ref 0
val reader =
  TextPrimIO.RD {name = "counting", chunkSize = 1024, readVec = SOME (fn _ => "abc"),
                 readArr = NONE, readVecNB = NONE, readArrNB = NONE, block = NONE,
                 canInput = NONE, avail = fn () => NONE, getPos = NONE, setPos = NONE,
                 endPos = NONE, verifyPos = NONE, close = fn () => closes := !closes + 1,
                 ioDesc = NONE}
val f = TextIO.StreamIO.mkInstream (reader, "")
val _ = TextIO.StreamIO.getReader f
val () = TextIO.StreamIO.closeIn f
val () = print ("closeIn after getReader: the reader was closed " ^ Int.toString (!closes) ^ " times\n")

(* the same on a file: the reader is still usable after closeIn *)
val () = write ("a.txt", "abc")
val f = TextIO.getInstream (TextIO.openIn "a.txt")
val (TextPrimIO.RD {readVec, ...}, _) = TextIO.StreamIO.getReader f
val () = TextIO.StreamIO.closeIn f
val () = print ("readVec of the file's reader after closeIn: "
                ^ ("\"" ^ valOf readVec 10 ^ "\"" handle e => exnName e) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
closeIn after getReader: the reader was closed 0 times
readVec of the file's reader after closeIn: "abc"
```

The reader should have been closed once, and the file's reader should
refuse to read.

## The cause

In `basis/io/stream-io.sml`, `getReader` marks the end of the stream
`Truncated` (lines 786-792):

```sml
      fun getReader (is as In {common = {reader, tail, ...}, ...}) =
        case !(!tail) of
          End => (!tail := Truncated;
                  let val (inp, _) = inputAll is
                  in (reader, inp)
                  end)
        | _ => liftExn (instreamName is) "getReader" IO.ClosedStream
```

and `closeIn` is `Close.close o Close.make` (line 732), where `Close.close`
(lines 717-722) closes the reader only when the stream is still active:

```sml
            fun close (T {close, name, tail}) =
               case !(!tail) of
                  End =>
                     (!tail := Closed
                      ; close () handle exn => liftExn name "closeIn" exn)
                | _ => ()
```

## The fix

Close the reader of a truncated stream as well:

```diff
--- a/basis/io/stream-io.sml
+++ b/basis/io/stream-io.sml
@@ -719,6 +719,9 @@
                   End =>
                      (!tail := Closed
                       ; close () handle exn => liftExn name "closeIn" exn)
+                | Truncated =>
+                     (!tail := Closed
+                      ; close () handle exn => liftExn name "closeIn" exn)
                 | _ => ()
 
             fun equalsInstream (T {tail, ...}, is) = tail = instreamTail is
```

`Close.close` also closes, at exit, the streams that `mkInstream''`
registered, so with this change a truncated stream that is still
registered then closes its reader at exit too, which the program may have
wrapped in another stream. The file readers of `Posix.IO.mkTextReader` and
`mkBinReader` ignore a second `close` (`if !closed then () else ...`), so
this does no harm to them; a program's own reader may be closed twice.

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions: `bug.sml` then prints `closed 1
times`, and the file's `readVec` raises `IO.ClosedStream`; Rune's Basis
Library tests of `BinIO`, `TextIO`, their `StreamIO`, `IO`, the `PrimIO`
functors, `OS.IO` on the standard streams and `Unix` show no new failure.
`master` was not built.

(That `readVec` raises the bare `ClosedStream` and not `IO.Io` is another
departure, of `Posix.IO.mkTextReader`: the
[`PRIM_IO` specification](https://smlfamily.github.io/Basis/prim-io.html)
says "A reader is required to raise IO.Io if any of its functions, except
close or getPos, is invoked after a call to close", with the cause
`IO.ClosedStream`. It is not the subject of this report.)

## Relation to Rune

Rune's Basis Library suite checks this in `tests/basis/fn/stream_io_fn.sml`
(`closeIn/truncated-stream-closes-the-reader`), which
`tests/basis/binio_streamio.sml` and `tests/basis/textio_streamio.sml`
apply to `BinIO.StreamIO` and `TextIO.StreamIO`; both fail on MLKit with
`got 0, expected 1`. The failures are explained by this line of
`tests/basis/deviations.txt`, worded as the one for MLton:

```
native:mlkit@* | *IO.StreamIO.closeIn/truncated-stream-closes-the-reader | HOST-BUG | closeIn of a stream that getReader truncated does not close the reader ("one can close a truncated or terminated string")
```

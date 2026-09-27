# MLKit 4.7.23: `TextIO.StreamIO.closeOut` of a terminated stream does not close the writer

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton also leaves the writer open; SML/NJ and Poly/ML close it.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/stream-io.sml` as the tag `v4.7.23`,
byte for byte, so the code below is unchanged there; `master` was not
built here. The code comes from MLton's Basis Library, whose release
20241230 has the same `closeOut` and fails Rune's check in the same way.

## Summary

* **The trigger:** `TextIO.StreamIO.closeOut f` (or
  `BinIO.StreamIO.closeOut f`) after `getWriter f` has terminated `f`.
* **What goes wrong:** the stream is marked closed but its writer is not
  closed. For a file, the descriptor stays open and the writer goes on
  writing.
* **Required behaviour:** the
  [`STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html)
  describes the states of an output stream: "When disconnected from its
  underlying primitive writer (e.g., by getWriter), the stream is
  terminated. When closeOut is applied to the stream, the stream enters the
  closed state. A closed stream is also terminated. The only real
  difference between a terminated stream and a closed one is that in the
  latter case, the stream's primitive I/O writer is closed." `closeOut f`
  "flushes f's buffers, marks the stream closed, and closes the underlying
  writer. This operation has no effect if f is already closed. Note that if
  f is terminated, no flushing will occur." The notes add: "one can close a
  truncated or terminated string. This is intended as a convenience, with
  the inactive stream providing a handle to the underlying file".

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml` closes a terminated stream on a writer that counts the calls of
its `close`, and then one on a file, whose writer it tries afterwards:

```sml
(* closeOut of an output stream that getWriter has terminated *)
fun slurp name = let val ins = TextIO.openIn name in TextIO.inputAll ins before TextIO.closeIn ins end

(* a writer that counts the calls of its close *)
val closes = ref 0
val writer =
  TextPrimIO.WR {name = "counting", chunkSize = 1024,
                 writeVec = SOME CharVectorSlice.length, writeArr = SOME CharArraySlice.length,
                 writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                 getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                 close = fn () => closes := !closes + 1, ioDesc = NONE}
val f = TextIO.StreamIO.mkOutstream (writer, IO.BLOCK_BUF)
val _ = TextIO.StreamIO.getWriter f
val () = TextIO.StreamIO.closeOut f
val () = print ("closeOut after getWriter: the writer was closed " ^ Int.toString (!closes) ^ " times\n")

(* the same on a file: the writer still writes after closeOut *)
val f = TextIO.getOutstream (TextIO.openOut "a.txt")
val (TextPrimIO.WR {writeVec, ...}, _) = TextIO.StreamIO.getWriter f
val () = TextIO.StreamIO.closeOut f
val () = print ("writeVec of the file's writer after closeOut: "
                ^ (Int.toString (valOf writeVec (CharVectorSlice.full "abc")) handle e => exnName e) ^ "\n")
val () = print ("the file holds \"" ^ slurp "a.txt" ^ "\"\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
closeOut after getWriter: the writer was closed 0 times
writeVec of the file's writer after closeOut: 3
the file holds "abc"
```

The writer should have been closed once, and the file's writer should
refuse to write.

## The cause

In `basis/io/stream-io.sml`, `closeOut` (lines 287-296) closes the writer
only when the stream is not terminated:

```sml
      fun closeOut (os as Out {state, ...}) =
        if closed (!state)
          then ()
          else (flushOut os;
                if terminated (!state)
                  then ()
                  else (writerSel (outstreamWriter os, #close)) ();
                state := Closed
                ; makeTerminated os)
        handle exn => liftExn (outstreamName os) "closeOut" exn
```

(`terminated` is true of the states `Terminated` and `Closed`, and the
second is excluded by the first test, so the test leaves out exactly the
streams that `getWriter` terminated.) `flushOut` is already a no-op on a
terminated stream, which is what "no flushing will occur" asks.

## The fix

```diff
--- a/basis/io/stream-io.sml
+++ b/basis/io/stream-io.sml
@@ -288,9 +288,7 @@
         if closed (!state)
           then ()
           else (flushOut os;
-                if terminated (!state)
-                  then ()
-                  else (writerSel (outstreamWriter os, #close)) ();
+                (writerSel (outstreamWriter os, #close)) ();
                 state := Closed
                 ; makeTerminated os)
         handle exn => liftExn (outstreamName os) "closeOut" exn
```

The streams that `mkOutstream''` registers are closed at exit with
`closeOut`, so with this change a terminated stream that is still
registered then closes its writer at exit too, which the program may have
wrapped in another stream. That stream was registered later and comes
first in the list, so it is flushed and closed before; the file writers of
`Posix.IO.mkTextWriter` and `mkBinWriter` ignore a second `close`
(`if !closed then () else ...`). A program's own writer may be closed
twice.

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions: `bug.sml` then prints `closed 1
times`, the file's `writeVec` raises `IO.ClosedStream` and the file holds
`""`; Rune's Basis Library tests of `BinIO`, `TextIO`, their `StreamIO`,
`IO`, the `PrimIO` functors, `OS.IO` on the standard streams and `Unix`
show no new failure. `master` was not built.

(That `writeVec` raises the bare `ClosedStream` and not `IO.Io` is another
departure, of `Posix.IO.mkTextWriter`: the
[`PRIM_IO` specification](https://smlfamily.github.io/Basis/prim-io.html)
says "A writer is required to raise IO.Io if any of its functions, except
close, is invoked after a call to close", with the cause
`IO.ClosedStream`. It is not the subject of this report.)

## Relation to Rune

Rune's Basis Library suite checks this in `tests/basis/fn/stream_io_fn.sml`
(`closeOut/terminated-closes-the-writer`), which
`tests/basis/binio_streamio.sml` and `tests/basis/textio_streamio.sml`
apply to `BinIO.StreamIO` and `TextIO.StreamIO`; both fail on MLKit with
`got 0, expected 1`. The failures are explained by this line of
`tests/basis/deviations.txt`, worded as the one for MLton:

```
native:mlkit@* | *IO.StreamIO.closeOut/terminated-closes-the-writer | HOST-BUG | closeOut of a stream that getWriter terminated does not close the writer ("one can close a truncated or terminated string")
```

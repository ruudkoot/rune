# MLKit 4.7.23: `TextIO.StreamIO.output1` on an unbuffered stream lets the writer's exception through instead of raising `Io`

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton also lets the writer's exception through; SML/NJ and Poly/ML raise `Io`.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/stream-io.sml` as the tag `v4.7.23`,
byte for byte, so the code below is unchanged there; `master` was not
built here. The code comes from MLton's Basis Library, whose release
20241230 has the same `output1` and fails Rune's check in the same way.

## Summary

* **The trigger:** `output1` on an unbuffered (`IO.NO_BUF`) output stream
  whose writer raises an exception: `TextIO.StreamIO.output1`,
  `BinIO.StreamIO.output1`, and `TextIO.output1` or `BinIO.output1` on an
  unbuffered imperative stream, such as `TextIO.stdErr`.
* **What goes wrong:** the writer's exception comes out of `output1` as it
  is, not wrapped in `IO.Io`. `output` on the same stream raises
  `IO.Io {function = "output", cause = ..., ...}`, and so does `output1`
  on a buffered stream when the flush fails.
* **Required behaviour:** the
  [`STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html)
  says of `output1 (f, el)`: "This function also raises the Io exception
  if there is an error in the underlying writer", and the
  [`IO` specification](https://smlfamily.github.io/Basis/io.html): "Users
  who create their own readers or writers may raise any exception they
  like, which will be reported as the cause field of the resulting Io
  exception."

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml` writes with a writer that always raises `Broken`, then to
`TextIO.stdErr` after closing its descriptor underneath it:

```sml
(* output1 on an unbuffered stream whose writer fails *)
fun describe f =
  (f (); "no exception")
  handle IO.Io {function, name, cause} =>
           "Io {function = \"" ^ function ^ "\", name = \"" ^ name ^ "\", cause = " ^ exnName cause ^ "}"
       | e => exnName e ^ " (not Io)"

(* a writer that always fails *)
exception Broken
val writer =
  TextPrimIO.WR {name = "broken", chunkSize = 1024,
                 writeVec = SOME (fn _ => raise Broken), writeArr = SOME (fn _ => raise Broken),
                 writeVecNB = NONE, writeArrNB = NONE, block = NONE, canOutput = NONE,
                 getPos = NONE, setPos = NONE, endPos = NONE, verifyPos = NONE,
                 close = fn () => (), ioDesc = NONE}
val f = TextIO.StreamIO.mkOutstream (writer, IO.NO_BUF)
val () = print ("TextIO.StreamIO.output1: " ^ describe (fn () => TextIO.StreamIO.output1 (f, #"x")) ^ "\n")
val () = print ("TextIO.StreamIO.output:  " ^ describe (fn () => TextIO.StreamIO.output (f, "x")) ^ "\n")

(* TextIO.stdErr is unbuffered: close its descriptor underneath it *)
val () = Posix.IO.close Posix.FileSys.stderr
val () = print ("TextIO.output1 stdErr:   " ^ describe (fn () => TextIO.output1 (TextIO.stdErr, #"x")) ^ "\n")
val () = print ("TextIO.output stdErr:    " ^ describe (fn () => TextIO.output (TextIO.stdErr, "x")) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
TextIO.StreamIO.output1: Broken (not Io)
TextIO.StreamIO.output:  Io {function = "output", name = "broken", cause = Broken}
TextIO.output1 stdErr:   SysErr (not Io)
TextIO.output stdErr:    Io {function = "output", name = "<stderr>", cause = SysErr}
```

The first and third lines should be `Io {function = "output1", ...}` with
the causes `Broken` and `SysErr`.

## The cause

In `basis/io/stream-io.sml`, `output1` (lines 184-236) handles the writer's
exceptions only where it flushes a full buffer, through its local
`flush`:

```sml
         fun flush (os, size, array) =
            let
               val Out {augmented_writer, ...} = os
            in
               flushBuf' (augmented_writer, size, array)
               handle exn => liftExn (outstreamName os) "output1" exn
            end
```

The branch for an unbuffered stream writes without a handler:

```sml
             | NO_BUF =>
                  let
                     val _ = ensureActive os
                     val _ = A.update (buf1, 0, c)
                     val Out {augmented_writer, ...} = os
                  in
                     flushArr (augmented_writer, AS.slice (buf1, 0, SOME 1))
                  end
```

`output` has `handle exn => liftExn (outstreamName os) "output" exn` around
its whole body.

## The fix

```diff
--- a/basis/io/stream-io.sml
+++ b/basis/io/stream-io.sml
@@ -233,6 +233,7 @@
                      val Out {augmented_writer, ...} = os
                   in
                      flushArr (augmented_writer, AS.slice (buf1, 0, SOME 1))
+                     handle exn => liftExn (outstreamName os) "output1" exn
                   end
       end
 
```

The handler covers only the write, so the `Io` that `ensureActive` raises
for a closed stream is not wrapped a second time.

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions (one of them renames the function
`ensureActive` reports to `"output1"`): `bug.sml` then prints
`Io {function = "output1", name = "broken", cause = Broken}` and
`Io {function = "output1", name = "<stderr>", cause = SysErr}` on the
first and third lines, and Rune's Basis Library tests of `BinIO`, `TextIO`,
their `StreamIO`, `IO`, the `PrimIO` functors, `OS.IO` on the standard
streams and `Unix` show no new failure. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks this in `tests/basis/fn/stream_io_fn.sml`
(`output1/Io-when-the-writer-fails`), which `tests/basis/binio_streamio.sml`
and `tests/basis/textio_streamio.sml` apply to `BinIO.StreamIO` and
`TextIO.StreamIO`; both fail on MLKit with `raised an exception, expected
"Broken"`. The failures are explained by this line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | *IO.StreamIO.output1/Io-when-the-writer-fails | HOST-BUG | output1 on an unbuffered stream lets the exception of the writer through instead of raising Io with it as the cause (output raises Io)
```

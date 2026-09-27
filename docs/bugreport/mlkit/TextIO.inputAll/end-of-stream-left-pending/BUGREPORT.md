# MLKit 4.7.23: `TextIO.inputAll` stops before the end-of-stream it reaches, not past it

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/imperative-io.sml` as the tag
`v4.7.23`, byte for byte, so the code below is unchanged there; `master`
was not built here.

## Summary

* **The trigger:** `TextIO.inputAll` or `BinIO.inputAll` on a stream that
  `openIn` made (not one made with `mkInstream`), when the file grows after
  `inputAll` has read to its end. `TextIO.inputN` and `BinIO.inputN`, when
  they return fewer elements than asked for, do the same.
* **What goes wrong:** `inputAll` returns the elements up to the
  end-of-stream but leaves the stream *at* that end-of-stream. The next
  input operation consumes it and returns the empty vector; only the one
  after that returns what the file has gained. With the stream the same
  file gives through `getInstream`, `TextIO.StreamIO.inputAll` behaves as
  required, and so does an imperative stream that `TextIO.mkInstream`
  made.
* **Required behaviour:** the
  [`STREAM_IO` specification](https://smlfamily.github.io/Basis/stream-io.html)
  says of `inputAll f`: "The stream f' is immediately past the next
  end-of-stream of f", and gives the example: "if a stream f contains data
  "abc" followed by an end-of-stream followed by "defg" and another
  end-of-stream, then inputAll f returns ("abc",f'), and inputAll f'
  returns ("defg",f'')". The
  [`IMPERATIVE_IO` specification](https://smlfamily.github.io/Basis/imperative-io.html)
  says that "the redirectable streams are implemented in terms of
  low-level streams", and of `endOfStream`: "After a read from strm to
  consume the end-of-stream, it is possible that the next call to
  endOfStream strm may return false, and input operations will deliver new
  elements." A file that has grown after `inputAll` returned should
  therefore give `"abc"`, `"defg"`, `""` to three calls of `inputAll`.
  For `inputN`, `STREAM_IO` relates it to `inputAll` by the predicate
  `allAndN`: when `inputN (f, n)` returns fewer than `n` elements, the
  stream it returns is equivalent to the one `inputAll f` returns, past the
  end-of-stream.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml` reads a file with `inputAll`, appends to it and reads twice more;
then it does the same with `BinIO.inputAll`, with `TextIO.inputN` asking
for more than the file holds, and, for contrast, with
`TextIO.StreamIO.inputAll`:

```sml
(* inputAll, then the file grows, then inputAll twice more. *)
fun show s = "\"" ^ String.toString s ^ "\""
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
fun append (name, s) = let val out = TextIO.openAppend name in TextIO.output (out, s); TextIO.closeOut out end
fun report (what, results) = print (what ^ ": " ^ String.concatWith ", " (map show results) ^ "\n")

(* TextIO.inputAll on a file *)
val () = write ("a.txt", "abc")
val ins = TextIO.openIn "a.txt"
val r1 = TextIO.inputAll ins
val () = append ("a.txt", "defg")
val r2 = TextIO.inputAll ins
val r3 = TextIO.inputAll ins
val () = report ("TextIO.inputAll          ", [r1, r2, r3])

(* BinIO.inputAll on a file (the bytes shown as characters) *)
val () = write ("b.bin", "abc")
val ins = BinIO.openIn "b.bin"
val r1 = Byte.bytesToString (BinIO.inputAll ins)
val () = append ("b.bin", "defg")
val r2 = Byte.bytesToString (BinIO.inputAll ins)
val r3 = Byte.bytesToString (BinIO.inputAll ins)
val () = report ("BinIO.inputAll           ", [r1, r2, r3])

(* TextIO.inputN (ins, 5) on a file: fewer than 5 characters each time *)
val () = write ("c.txt", "ab")
val ins = TextIO.openIn "c.txt"
val r1 = TextIO.inputN (ins, 5)
val () = append ("c.txt", "cd")
val r2 = TextIO.inputN (ins, 5)
val r3 = TextIO.inputN (ins, 5)
val () = report ("TextIO.inputN            ", [r1, r2, r3])

(* for contrast: TextIO.StreamIO.inputAll on the same kind of file *)
val () = write ("d.txt", "abc")
val f = TextIO.getInstream (TextIO.openIn "d.txt")
val (r1, f) = TextIO.StreamIO.inputAll f
val () = append ("d.txt", "defg")
val (r2, f) = TextIO.StreamIO.inputAll f
val (r3, _) = TextIO.StreamIO.inputAll f
val () = report ("TextIO.StreamIO.inputAll ", [r1, r2, r3])
```

```
$ mlkit -o bug bug.mlb && ./bug
TextIO.inputAll          : "abc", "", "defg"
BinIO.inputAll           : "abc", "", "defg"
TextIO.inputN            : "ab", "", "cd"
TextIO.StreamIO.inputAll : "abc", "defg", ""
```

The first three lines should read like the last: `"abc", "defg", ""` and
`"ab", "cd", ""`.

## The cause

An imperative stream that `openIn` makes (functor `ImperativeIOExtra` in
`basis/io/imperative-io.sml`, which `TextIO` and `BinIO` both apply) reads
the file itself while it is in the state `Open {eos}`; `eos = true` means
that the reader has reported an end-of-stream that no operation has
consumed yet, and the next input operation returns the empty vector and
clears it. When `inputAll` meets the end-of-stream, it sets that flag
(lines 432-441):

```sml
                fun loop inps =
                   let
                      val inp =
                         readVec (augmentedReaderSel (ib, #chunkSize))
                   in
                      if V.length inp = 0
                         then (state := Open {eos = true}
                               ; V.concat (List.rev inps))
                      else loop (inp :: inps)
                   end
```

so the end-of-stream that `inputAll` consumed to find the end of its
result is delivered a second time, by the next operation. `inputN` does
the same when the reader returns 0 before `n` elements have been read
(lines 383-394):

```sml
                            fun loop i =
                               if i = n
                                  then i
                               else let
                                       val j =
                                          readArr
                                          (AS.slice (inp, i, SOME (n - i)))
                                    in
                                       if j = 0
                                          then (state := Open {eos = true}; i)
                                       else loop (i + j)
                                    end
```

A stream in the state `Stream s` (after `getInstream`, or made with
`mkInstream`) calls `StreamIO.inputAll` and `StreamIO.inputN` of
`basis/io/stream-io.sml` instead, which leave it past the end-of-stream;
that is the last line of the output above.

The files of `basis/io` come from MLton's Basis Library. MLton's
`imperative-io.fun` (release 20241230) has the same `inputN`, but its
`inputAll` has neither `state := Open {eos = true}` nor the `first := l`
that MLKit's has three lines above it.

## The fix

Do not mark as pending an end-of-stream that the operation has consumed:

```diff
--- a/basis/io/imperative-io.sml
+++ b/basis/io/imperative-io.sml
@@ -389,7 +389,7 @@
                                           (AS.slice (inp, i, SOME (n - i)))
                                     in
                                        if j = 0
-                                          then (state := Open {eos = true}; i)
+                                          then i
                                        else loop (i + j)
                                     end
                             val i = loop size
@@ -435,8 +435,7 @@
                          readVec (augmentedReaderSel (ib, #chunkSize))
                    in
                       if V.length inp = 0
-                         then (state := Open {eos = true}
-                               ; V.concat (List.rev inps))
+                         then V.concat (List.rev inps)
                       else loop (inp :: inps)
                    end
              in
```

`endOfStream` after `inputAll` still answers `true` on a file that has not
grown: it asks the reader, which reports the end-of-stream again.

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions: `bug.sml` then prints
`"abc", "defg", ""` on the first, second and fourth lines and
`"ab", "cd", ""` on the third, and Rune's Basis Library tests of `BinIO`,
`TextIO`, their `StreamIO`, `IO`, the `PrimIO` functors, `OS.IO` on the
standard streams and `Unix` show no new failure. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks this in `tests/basis/binio.sml`
(`BinIO.inputAll/file-grows-after-end-of-stream`), which fails on MLKit
with `got [[1, 2], [], [3, 4, 5]], expected [[1, 2], [3, 4, 5], []]`, and
in `tests/basis/textio.sml` (`TextIO.inputAll/file-grows-after-end-of-stream`).
The second does not run on MLKit: `textio.sml` does not compile there,
because one of its checks compares two `TextIO.instream` values with `=`,
although the specification declares `type instream`, not `eqtype` (a
mistake of the test, not of MLKit). With that check taken out, it fails in the same way: `got ["abc",
"", "defg"], expected ["abc", "defg", ""]`. The suite does not check
`inputN` on a file that grows. The failure is explained by this line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | *IO.inputAll/file-grows-after-end-of-stream | HOST-BUG | inputAll on a stream that openIn made leaves it at the end-of-stream where it stops, not "immediately past" it: after the file has grown, the next inputAll returns the empty vector and only the one after it the new elements
```

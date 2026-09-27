# MLKit 4.7.23: `TextIO.input1` that returns `NONE` leaves the stream before the end-of-stream

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton does the same on a file; Poly/ML meets it, and SML/NJ never moves past the end-of-stream.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/io/imperative-io.sml` as the tag
`v4.7.23`, byte for byte, so the code below is unchanged there; `master`
was not built here. The code comes from MLton's Basis Library, whose
release 20241230 has the same `input1` and fails Rune's check in the same
way.

## Summary

* **The trigger:** `TextIO.input1` or `BinIO.input1` on a stream that
  `openIn` made, at the end of the file, when the file grows afterwards.
* **What goes wrong:** the `input1` that returns `NONE` does not consume the
  end-of-stream: a second `input1` returns `NONE` again, and only a third
  one returns what the file has gained. On an imperative stream made with
  `TextIO.mkInstream` from the same file's `StreamIO` stream, `input1`
  moves past the end-of-stream as required.
* **Required behaviour:** the
  [`IMPERATIVE_IO` specification](https://smlfamily.github.io/Basis/imperative-io.html)
  says of `input1`: "After a call to input1 returning NONE to indicate an
  end-of-stream, the input stream should be positioned after the
  end-of-stream." So `input1` at the end of a file that has one character
  `a` and then gains `z` gives `SOME #"a"`, `NONE`, `SOME #"z"`, `NONE`.

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
(* input1 to the end of a file, then the file grows, then input1 twice more. *)
fun show NONE = "NONE" | show (SOME c) = "SOME #\"" ^ Char.toString c ^ "\""
fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
fun append (name, s) = let val out = TextIO.openAppend name in TextIO.output (out, s); TextIO.closeOut out end
fun report (what, results) = print (what ^ ": " ^ String.concatWith ", " (map show results) ^ "\n")

(* TextIO.input1 on a stream that TextIO.openIn made *)
val () = write ("a.txt", "a")
val ins = TextIO.openIn "a.txt"
val r1 = TextIO.input1 ins
val r2 = TextIO.input1 ins
val () = append ("a.txt", "z")
val r3 = TextIO.input1 ins
val r4 = TextIO.input1 ins
val () = report ("TextIO.input1, openIn    ", [r1, r2, r3, r4])

(* BinIO.input1 (the bytes shown as characters) *)
val () = write ("b.bin", "a")
val ins = BinIO.openIn "b.bin"
val r1 = BinIO.input1 ins
val r2 = BinIO.input1 ins
val () = append ("b.bin", "z")
val r3 = BinIO.input1 ins
val r4 = BinIO.input1 ins
val () = report ("BinIO.input1, openIn     ", map (Option.map Byte.byteToChar) [r1, r2, r3, r4])

(* for contrast: the same file through TextIO.mkInstream of its StreamIO stream *)
val () = write ("c.txt", "a")
val ins = TextIO.mkInstream (TextIO.getInstream (TextIO.openIn "c.txt"))
val r1 = TextIO.input1 ins
val r2 = TextIO.input1 ins
val () = append ("c.txt", "z")
val r3 = TextIO.input1 ins
val r4 = TextIO.input1 ins
val () = report ("TextIO.input1, mkInstream", [r1, r2, r3, r4])
```

```
$ mlkit -o bug bug.mlb && ./bug
TextIO.input1, openIn    : SOME #"a", NONE, NONE, SOME #"z"
BinIO.input1, openIn     : SOME #"a", NONE, NONE, SOME #"z"
TextIO.input1, mkInstream: SOME #"a", NONE, SOME #"z", NONE
```

The first two lines should read like the last one.

## The cause

An imperative stream that `openIn` makes (functor `ImperativeIOExtra` in
`basis/io/imperative-io.sml`, which `TextIO` and `BinIO` both apply) reads
the file itself while it is in the state `Open {eos}`; `eos = true` means
that the reader has reported an end-of-stream that no operation has
consumed yet. `update` refills the buffer and sets that flag when the
reader returns nothing (lines 271-281):

```sml
fun update (ib as In {buf, first, last, state, ...}) =
   let
      val i = readArr ib (AS.full buf)
   in
      if i = 0
         then (state := Open {eos = true}
               ; false)
      else (first := 0
            ; last := i
            ; true)
   end
```

That is right for `lookahead` and `endOfStream`, which must not consume the
end-of-stream. `input1` uses `update` too, and returns `NONE` without
clearing the flag (lines 313-346):

```sml
(* input1 will move past a temporary end of stream *)
fun input1 (ib as In {buf, first, last, ...}) =
   ...
             | Open {eos} =>
                  if eos
                     then
                        (state := Open {eos = false}
                         ; NONE)
                  else
                     if protect (ib, "input1", fn () => update ib)
                        then
                           (first := 1
                            ; SOME (A.sub (buf, 0)))
                     else NONE
```

so the end-of-stream it has just returned as `NONE` is still pending, and
the next `input1` returns `NONE` for it a second time (the branch
`if eos`). The comment above the function says what it should do. In the
state `Stream s` (after `getInstream`, or made with `mkInstream`) `input1`
calls `StreamIO.input1'` of `basis/io/stream-io.sml`, which does move past
the end-of-stream.

## The fix

Consume the end-of-stream that `update` has just found:

```diff
--- a/basis/io/imperative-io.sml
+++ b/basis/io/imperative-io.sml
@@ -334,7 +334,8 @@
                         then
                            (first := 1
                             ; SOME (A.sub (buf, 0)))
-                     else NONE
+                     else (state := Open {eos = false}
+                           ; NONE)
              | Stream s =>
                   let
                      val (c, s') = SIO.input1' s
```

Tested on a copy of the 4.7.23 library (`lib/mlkit/basis`) with this
change, together with the changes proposed in the other reports of this
series, which touch other functions: `bug.sml` then prints
`SOME #"a", NONE, SOME #"z", NONE` on all three lines, and Rune's Basis
Library tests of `BinIO`, `TextIO`, their `StreamIO`, `IO`, the `PrimIO`
functors, `OS.IO` on the standard streams and `Unix` show no new failure.
`master` was not built.

## Relation to Rune

Rune's Basis Library suite checks this in `tests/basis/binio.sml`
(`BinIO.input1/file-grows-after-end-of-stream`), which fails on MLKit with
`got [SOME 1, NONE, NONE, SOME 2], expected [SOME 1, NONE, SOME 2, NONE]`,
and in `tests/basis/textio.sml`
(`TextIO.input1/file-grows-after-end-of-stream`). The second does not run
on MLKit: `textio.sml` does not compile there, because one of its checks
compares two `TextIO.instream` values with `=`, although the specification
declares `type instream`, not `eqtype` (a mistake of the test, not of
MLKit). With that check taken out, it fails in the same way. The failure is
explained by this line of `tests/basis/deviations.txt`, worded as the one
for MLton:

```
native:mlkit@* | *IO.input1/file-grows-after-end-of-stream | HOST-BUG | the input1 that returns NONE leaves the stream before the end-of-stream; a second one consumes it
```

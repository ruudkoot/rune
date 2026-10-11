# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `TextIO.canInput` and `BinIO.canInput` lose input when they read more than one chunk ahead

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Major |
| Also present in the "development" version? | Yes: 2026.2 prints the same, and `text-io-fn.sml` and `bin-io-fn.sml` of smlnj/smlnj `17362d2` have the same `canInput` |

### Description

When `canInput (f, n)` has to call the reader more than once to look at `n`
elements, the elements of the first read are lost:

* `canInput (TextIO.openString "ab", 5)` says `SOME 2`, and then `input`
  gives `""`;
* on a file of 10,000 characters, `canInput (f, 6000)` says `SOME 1904`,
  and then `inputAll` gives the last 5,904 characters only.

The same happens with `BinIO`, and with the functional
`StreamIO.canInput`, whose stream value should not change. Also, when the
elements span buffers, the count is short: `SOME 1904` where 6,000 were
read.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
openString "ab": canInput (f, 2), input f = SOME 2, "ab", expected SOME 2, "ab": ok
openString "ab": canInput (f, 5), input f = SOME 2, "", expected SOME 2, "ab": WRONG
openString "ab": canInput (f, 3), inputAll f = SOME 2, "", expected SOME 2, "ab": WRONG
StreamIO: canInput (s, 5), input s = SOME 2, "", expected SOME 2, "ab": WRONG
BinIO, 2 bytes: canInput (g, 5), input g = SOME 2, 0 bytes, expected SOME 2, 2 bytes: WRONG
file of 10000 characters: canInput (f, 6000), inputAll f = SOME 1904, 5904 characters, expected SOME 6000, 10000 characters: WRONG
```

### Expected Behavior

The input is kept: the specification says a lookahead by `canInput`
"commits the stream to the characters read by `readVecNB`", and that "any
future call of `input` on the same input stream must return the same
vector of elements". MLton, Poly/ML and MLKit give `"ab"`. The count should
be as large as found ("as large a k as possible").

### Steps to Reproduce

```sml
(* canInput (f, n), then reading f. canInput "returns SOME k ... if a call to
   input would return immediately with at least k characters", and must not
   lose them. Run: sml bug.sml (it writes and removes bug.tmp in the current
   directory). *)
fun opt NONE = "NONE" | opt (SOME n) = "SOME " ^ Int.toString n
fun show (name, got, expected) =
      print (concat [name, " = ", got, ", expected ", expected, ": ",
                     if got = expected then "ok" else "WRONG", "\n"])
val () = let val f = TextIO.openString "ab"
             val a = TextIO.canInput (f, 2)
         in show ("openString \"ab\": canInput (f, 2), input f", opt a ^ ", \"" ^ TextIO.input f ^ "\"", "SOME 2, \"ab\"") end
val () = let val f = TextIO.openString "ab"
             val a = TextIO.canInput (f, 5)
         in show ("openString \"ab\": canInput (f, 5), input f", opt a ^ ", \"" ^ TextIO.input f ^ "\"", "SOME 2, \"ab\"") end
val () = let val f = TextIO.openString "ab"
             val a = TextIO.canInput (f, 3)
         in show ("openString \"ab\": canInput (f, 3), inputAll f", opt a ^ ", \"" ^ TextIO.inputAll f ^ "\"", "SOME 2, \"ab\"") end
(* a functional stream: s is a value, and canInput changes what it holds *)
val () = let val s = TextIO.getInstream (TextIO.openString "ab")
             val a = TextIO.StreamIO.canInput (s, 5)
         in show ("StreamIO: canInput (s, 5), input s", opt a ^ ", \"" ^ #1 (TextIO.StreamIO.input s) ^ "\"", "SOME 2, \"ab\"") end
val () = let val bytes = Byte.stringToBytes
             val g = BinIO.mkInstream (BinIO.StreamIO.mkInstream (BinPrimIO.openVector (bytes "ab"), bytes ""))
             val a = BinIO.canInput (g, 5)
         in show ("BinIO, 2 bytes: canInput (g, 5), input g", opt a ^ ", " ^ Int.toString (Word8Vector.length (BinIO.input g)) ^ " bytes", "SOME 2, 2 bytes") end
(* a file longer than a buffer *)
val text = CharVector.tabulate (10000, fn i => Char.chr (97 + i mod 26))
val () = let val out = TextIO.openOut "bug.tmp" in TextIO.output (out, text); TextIO.closeOut out end
val () = let val f = TextIO.openIn "bug.tmp"
             val a = TextIO.canInput (f, 6000)
             val s = TextIO.inputAll f
         in show ("file of 10000 characters: canInput (f, 6000), inputAll f", opt a ^ ", " ^ Int.toString (size s) ^ " characters",
                  "SOME 6000, 10000 characters");
            TextIO.closeIn f
         end
val () = OS.FileSys.remove "bug.tmp"
val () = OS.Process.exit OS.Process.success
```

### Additional Information

In `canInput`, `nextBuf`'s pattern `IBUF{more, ...}` does not bind `buf`,
so `extendStream (readVecNB, "canInput", buf)` gets `canInput`'s argument,
the stream's first buffer, instead of the last one in the chain. The
second read therefore sets the first buffer's `more` to its chunk (or to
`EOS`), in place of the chunk the first read put there. (`inputN`'s
`nextBuf` binds `buf as IBUF{...}`.) And `tryInput` returns `SOME n`, where
`n` is what remains of `amount` to be found from that buffer; when the
buffer has it, all of `amount` has been found.

The patch makes both changes in `TextIOFn` and `BinIOFn`. It is against
legacy `main` (`6ed5a0a`) and also applies to 110.99.9 and, with `-p2`, to
smlnj/smlnj:

```diff
diff --git a/base/system/Basis/Implementation/IO/bin-io-fn.sml b/base/system/Basis/Implementation/IO/bin-io-fn.sml
index 372986c..0dceb73 100644
--- a/base/system/Basis/Implementation/IO/bin-io-fn.sml
+++ b/base/system/Basis/Implementation/IO/bin-io-fn.sml
@@ -256,15 +256,16 @@ functor BinIOFn (
 			inputExn(info, "canInput", IO.NonblockingNotSupported)
 		    | (IBUF{info=INFO{readVecNB=SOME f, ...}, ...}) => f
 		  (* end case *))
+	    (* n is what remains of amount to be found, from position i of buf *)
 	      fun tryInput (buf as IBUF{data, ...}, i, n) = let
 		    val len = V.length data
 		    val remain = len - i
 		    in
 		      if (remain >= n)
-			then SOME n
+			then SOME amount
 			else nextBuf (buf, n - remain)
 		    end
-	      and nextBuf (IBUF{more, ...}, n) = (case !more
+	      and nextBuf (buf as IBUF{more, ...}, n) = (case !more
 		     of (MORE buf) => tryInput (buf, 0, n)
 		      | (EOS _) => SOME(amount - n)
 		      | TERMINATED => SOME(amount - n)
diff --git a/base/system/Basis/Implementation/IO/text-io-fn.sml b/base/system/Basis/Implementation/IO/text-io-fn.sml
index de48898..31b2df0 100644
--- a/base/system/Basis/Implementation/IO/text-io-fn.sml
+++ b/base/system/Basis/Implementation/IO/text-io-fn.sml
@@ -268,15 +268,16 @@ functor TextIOFn (
 			inputExn(info, "canInput", IO.NonblockingNotSupported)
 		    | (IBUF{info=INFO{readVecNB=SOME f, ...}, ...}) => f
 		  (* end case *))
+	    (* n is what remains of amount to be found, from position i of buf *)
 	      fun tryInput (buf as IBUF{data, ...}, i, n) = let
 		    val len = V.length data
 		    val remain = len - i
 		    in
 		      if (remain >= n)
-			then SOME n
+			then SOME amount
 			else nextBuf (buf, n - remain)
 		    end
-	      and nextBuf (IBUF{more, ...}, n) = (case !more
+	      and nextBuf (buf as IBUF{more, ...}, n) = (case !more
 		     of (MORE buf) => tryInput (buf, 0, n)
 		      | (EOS _) => SOME(amount - n)
 		      | TERMINATED => SOME(amount - n)
```

Not built: the functional streams of `text-io-fn.sml`, copied into a
standalone program with and without the patch, lose input as the Basis
does without it (8,033 of 10,000 random readers and operation sequences),
and with it read back every string, with `canInput (s, n)` always
`SOME (min (n, what is left))` on readers that never block (110.99.9, 32
and 64 bits, and 2026.2).

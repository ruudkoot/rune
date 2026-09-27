# MLKit 4.7.23: `PackReal*.subVec`, `subArr` and `update` raise `Overflow` instead of `Subscript` for an index near `Int.maxInt`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton and Poly/ML raise `Subscript`; SML/NJ has no `PackRealLittle`.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/PackRealLittle.sml` and `basis/PackRealBig.sml`
are identical to 4.7.23's.

## Summary

* **The trigger:** `subVec (v, i)`, `subArr (a, i)` or `update (a, i, r)` of
  `PackRealLittle`, `PackRealBig` (and the `PackReal64` structures, which are
  the same) with an index `i` so large that `8 * i` or `8 * (i + 1)`
  overflows `int`, such as `valOf Int.maxInt`.
* **What goes wrong:** they raise `Overflow`, from computing the byte
  offset, instead of `Subscript`.
* **Required behaviour:** the
  [Basis `PACK_REAL` specification](https://smlfamily.github.io/Basis/pack-float.html):
  subVec and subArr "raise the Subscript exception if i < 0 or if
  Word8Array.length seq < bytesPerElem * (i + 1)", and update "raises the
  Subscript exception if i < 0 or if Word8Array.length arr < bytesPerElem *
  (i + 1)" -- a condition on the mathematical product, which holds for
  `i = maxInt`.

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend (63-bit `int`).
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "They raise the Subscript exception if i < 0 or if Word8Array.length seq
   < bytesPerElem * (i + 1)." *)
val v = Word8Vector.tabulate (16, fn _ => 0w0)
val a = Word8Array.array (16, 0w0)
val i = valOf Int.maxInt
fun try (what, f) =
    print (what ^ ": " ^ ((f (); "no exception") handle Subscript => "Subscript"
                                                       | e => General.exnName e)
           ^ "   (expected Subscript)\n")
val () = try ("PackRealLittle.subVec (v, maxInt)     ", fn () => PackRealLittle.subVec (v, i))
val () = try ("PackRealLittle.subArr (a, maxInt)     ", fn () => PackRealLittle.subArr (a, i))
val () = try ("PackRealLittle.update (a, maxInt, 1.0)", fn () => PackRealLittle.update (a, i, 1.0))
val () = try ("PackRealBig.subVec (v, maxInt)        ", fn () => PackRealBig.subVec (v, i))
val () = try ("PackRealBig.subArr (a, maxInt)        ", fn () => PackRealBig.subArr (a, i))
val () = try ("PackRealBig.update (a, maxInt, 1.0)   ", fn () => PackRealBig.update (a, i, 1.0))
val () = try ("PackRealLittle.subVec (v, 2)          ", fn () => PackRealLittle.subVec (v, 2))
```

```
$ mlkit -o bug bug.mlb && ./bug
PackRealLittle.subVec (v, maxInt)     : Overflow   (expected Subscript)
PackRealLittle.subArr (a, maxInt)     : Overflow   (expected Subscript)
PackRealLittle.update (a, maxInt, 1.0): Overflow   (expected Subscript)
PackRealBig.subVec (v, maxInt)        : Overflow   (expected Subscript)
PackRealBig.subArr (a, maxInt)        : Overflow   (expected Subscript)
PackRealBig.update (a, maxInt, 1.0)   : Overflow   (expected Subscript)
PackRealLittle.subVec (v, 2)          : Subscript   (expected Subscript)
```

## The cause

The byte offset is computed with checked `int` arithmetic before any bounds
check. `basis/PackRealLittle.sml`:

```sml
    fun subVec (v,i) =
        let
          fun toL 9 l = l
            | toL j l = toL (j+1) (Word8Vector.sub(v,(i+1)*bytesPerElem - j) :: l)
        in fromBytes (Word8Vector.fromList (toL 1 []))
        end
    ...
    fun update (a,i,r) =
        Word8Array.copyVec {src=toBytes r, dst=a, di=i*bytesPerElem}
```

(`subArr` likewise), and `basis/PackRealBig.sml`:

```sml
    fun subVec (vec, i) =
        Little.fromBytes(
            reverse_gen Word8VectorSlice.length Word8VectorSlice.sub (
                Word8VectorSlice.slice(vec, i*bytesPerElem, SOME bytesPerElem)))
    ...
    fun update (arr, i, r) =
        Word8Array.copyVec {src=toBytes r, dst=arr, di=i*bytesPerElem}
```

## The fix

Check the index against the length first, in a form that cannot overflow:
`8 * (i + 1) <= len` is `i < len div 8` for `i >= 0`.

```diff
--- a/basis/PackRealLittle.sml
+++ b/basis/PackRealLittle.sml
@@
     val bytesPerElem = 8
     val isBigEndian = false
+    (* "Subscript if i < 0 or if length < bytesPerElem * (i + 1)",
+       checked before the offset is computed *)
+    fun check (len, i) =
+        if i < 0 orelse i >= len div bytesPerElem then raise Subscript else ()
@@
-    fun subVec (v,i) =
+    fun subVec (v,i) = (check (Word8Vector.length v, i);
         let
           ...
-        end
+        end)
 
-    fun subArr (a,i) =
+    fun subArr (a,i) = (check (Word8Array.length a, i);
         let
           ...
-        end
+        end)
 
     fun update (a,i,r) =
-        Word8Array.copyVec {src=toBytes r, dst=a, di=i*bytesPerElem}
+        (check (Word8Array.length a, i);
+         Word8Array.copyVec {src=toBytes r, dst=a, di=i*bytesPerElem})
```

and the same three calls of a `check` in `basis/PackRealBig.sml`. Tested as
wrappers with this check in a program built with MLKit 4.7.23, with the
`PackReal` structures shadowed: `maxInt` raises `Subscript` in all six
functions, `update` of index 1 into 15 bytes raises `Subscript` and into 16
bytes succeeds, and all 80 checks of Rune's `tests/basis/pack_real.sml` and
of `tests/basis/pack_real64.sml` pass (with the fixes of the two other
`PackReal` reports). The patch of the library itself was not built.

## Relation to Rune

The checks `*.subVec/Subscript-maxInt`, `*.subArr/Subscript-maxInt` and
`*.update/Subscript-maxInt` of `PackRealBig`, `PackRealLittle`,
`PackReal64Big` and `PackReal64Little` (12 checks of
`tests/basis/pack_real.sml` and `tests/basis/pack_real64.sml`, from
`tests/basis/fn/pack_real_fn.sml`) fail on MLKit with "raised a different
exception". Poly/ML has the same fault in its `PackWord` and `PackReal32`
structures (`HOST-BUG` lines of `tests/basis/deviations.txt`). Proposed
line:

```
native:mlkit@* | PackReal[BL6]*.*/Subscript-maxInt | HOST-BUG | subVec, subArr and update raise Overflow for an index near the largest int (bytesPerElem * i or bytesPerElem * (i + 1) overflows), not Subscript
```

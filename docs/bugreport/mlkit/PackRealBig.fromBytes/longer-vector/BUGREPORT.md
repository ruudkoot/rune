# MLKit 4.7.23: `PackRealBig.fromBytes` of a vector longer than 8 bytes reads its last 8 bytes

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton and Poly/ML read the first 8 bytes; SML/NJ has no `PackRealBig`.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/PackRealBig.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `PackRealBig.fromBytes v` (or `PackReal64Big.fromBytes`,
  the same structure) with `Word8Vector.length v > 8`.
* **What goes wrong:** the vector is reversed whole and handed to
  `PackRealLittle.fromBytes`, which reads the first 8 bytes of the reversed
  vector: the last 8 bytes of `v`, in reverse order. `[3F F0 00 00 00 00 00
  00 40 00]` gives `8.09477154146E~320` instead of `1.0`.
* **Required behaviour:** the
  [Basis `PACK_REAL` specification](https://smlfamily.github.io/Basis/pack-float.html):
  "The function fromBytes raises the Subscript exception if the argument
  vector does not have length at least bytesPerElem; otherwise the first
  bytesPerElem bytes are used."

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* 1.0 is 3F F0 00 00 00 00 00 00, most significant byte first. "The function
   fromBytes raises the Subscript exception if the argument vector does not
   have length at least bytesPerElem; otherwise the first bytesPerElem bytes
   are used." *)
fun vecOf l = Word8Vector.fromList (List.map Word8.fromInt l)
val eight = [0x3F, 0xF0, 0, 0, 0, 0, 0, 0]
val () = print ("PackRealBig.fromBytes [3F F0 00 00 00 00 00 00]       = "
                ^ Real.toString (PackRealBig.fromBytes (vecOf eight)) ^ "\n")
val () = print ("PackRealBig.fromBytes [3F F0 00 00 00 00 00 00 40 00] = "
                ^ Real.toString (PackRealBig.fromBytes (vecOf (eight @ [0x40, 0]))) ^ "   (expected 1.0)\n")
val () = print ("PackRealLittle.fromBytes [00 00 00 00 00 00 F0 3F 40 00] = "
                ^ Real.toString (PackRealLittle.fromBytes (vecOf (rev eight @ [0x40, 0]))) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
PackRealBig.fromBytes [3F F0 00 00 00 00 00 00]       = 1.0
PackRealBig.fromBytes [3F F0 00 00 00 00 00 00 40 00] = 8.09477154146E~320   (expected 1.0)
PackRealLittle.fromBytes [00 00 00 00 00 00 F0 3F 40 00] = 1.0
```

`8.09477154146E~320` (16384 times `minPos`) is the subnormal whose bytes, most significant first, are
`00 00 00 00 00 00 40 00`: the last eight bytes of `v`.

## The cause

`basis/PackRealBig.sml`:

```sml
    fun reverse_gen length sub vec =
        let val len = length vec
        in  Word8Vector.tabulate(len, fn i => sub(vec, len - 1 - i))
        end

    fun reverse vec = reverse_gen Word8Vector.length Word8Vector.sub vec

    structure Little = PackRealLittle

    fun toBytes r = reverse(Little.toBytes r)
    fun fromBytes vec = Little.fromBytes(reverse vec)
```

`reverse` reverses the whole vector, not its first `bytesPerElem` bytes.
(`subVec` and `subArr` take a slice of 8 bytes first and are right.)

## The fix

Reverse the first 8 bytes only; this also gives `Subscript` for a short
vector, which `PackRealLittle.fromBytes` does not check (see the report
`PackRealLittle.fromBytes/short-vector`):

```diff
--- a/basis/PackRealBig.sml
+++ b/basis/PackRealBig.sml
@@
     fun toBytes r = reverse(Little.toBytes r)
-    fun fromBytes vec = Little.fromBytes(reverse vec)
+    (* "otherwise the first bytesPerElem bytes are used" *)
+    fun fromBytes vec =
+        if Word8Vector.length vec < bytesPerElem then raise Subscript
+        else Little.fromBytes (reverse_gen (fn _ => bytesPerElem) Word8Vector.sub vec)
```

Tested as a wrapper with the same body in a program built with MLKit 4.7.23,
with `PackRealBig` and `PackReal64Big` shadowed: `[3F F0 00 00 00 00 00 00
40 00]` gives `1.0`, a vector of 7 bytes raises `Subscript`, and all 80
checks of Rune's `tests/basis/pack_real.sml` and of
`tests/basis/pack_real64.sml` pass (with the fixes of the two other
`PackReal` reports). The patch of the library itself was not built.

## Relation to Rune

The checks `PackRealBig.fromBytes/longer-uses-the-first` and
`PackReal64Big.fromBytes/longer-uses-the-first` (of
`tests/basis/pack_real.sml` and `tests/basis/pack_real64.sml`, from
`tests/basis/fn/pack_real_fn.sml`) fail on MLKit ("false"). Proposed line
of `tests/basis/deviations.txt`:

```
native:mlkit@* | PackReal*Big.fromBytes/longer-uses-the-first | HOST-BUG | PackRealBig.fromBytes reverses the whole vector and reads the first 8 bytes of that: of a longer vector it reads the last 8 bytes
```

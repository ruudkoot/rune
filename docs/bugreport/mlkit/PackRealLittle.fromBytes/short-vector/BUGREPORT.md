# MLKit 4.7.23: `PackRealLittle.fromBytes` and `PackRealBig.fromBytes` read past the end of a short vector instead of raising `Subscript`

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** `fromBytes` reads memory past the end of the vector.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/PackRealLittle.sml`, `basis/PackRealBig.sml` and
`src/Runtime/Math.c` are identical to 4.7.23's.

## Summary

* **The trigger:** `PackRealLittle.fromBytes v` or `PackRealBig.fromBytes v`
  (and the `PackReal64` structures, which are the same) with
  `Word8Vector.length v < 8`.
* **What goes wrong:** no `Subscript`: the runtime reads 8 bytes from the
  start of the vector whatever its length, so the bytes past its end (the
  terminating NUL of the string that represents it, and what follows it in
  memory) become part of the real returned.
* **Required behaviour:** the
  [Basis `PACK_REAL` specification](https://smlfamily.github.io/Basis/pack-float.html):
  "The function fromBytes raises the Subscript exception if the argument
  vector does not have length at least bytesPerElem".

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
(* "The function fromBytes raises the Subscript exception if the argument
   vector does not have length at least bytesPerElem" (8). *)
fun vecOf l = Word8Vector.fromList (List.map Word8.fromInt l)
fun try (what, f) =
    print (what ^ " = " ^ (Real.toString (f ()) handle Subscript => "Subscript")
           ^ "   (expected Subscript)\n")
val () = try ("PackRealLittle.fromBytes (7 bytes)", fn () => PackRealLittle.fromBytes (vecOf [0, 0, 0, 0, 0, 0xF0, 0x3F]))
val () = try ("PackRealLittle.fromBytes (0 bytes)", fn () => PackRealLittle.fromBytes (vecOf []))
val () = try ("PackRealBig.fromBytes (7 bytes)   ", fn () => PackRealBig.fromBytes (vecOf [0x3F, 0xF0, 0, 0, 0, 0, 0]))
```

```
$ mlkit -o bug bug.mlb && ./bug
PackRealLittle.fromBytes (7 bytes) = 1.7765824089E~307   (expected Subscript)
PackRealLittle.fromBytes (0 bytes) = 1.7765824089E~307   (expected Subscript)
PackRealBig.fromBytes (7 bytes)    = 1.7765824089E~307   (expected Subscript)
```

`1.7765824089E~307` is the real whose bytes, least significant first, are
`00 00 00 00 00 F0 3F 00`: the seven bytes of the vector and the NUL after
them. What the empty vector gives depends on the memory after it.

## The cause

`basis/PackRealLittle.sml` passes the vector to the runtime without looking
at its length:

```sml
    fun fromBytesS (s:string) : real = prim("sml_bytes_to_real",s)

    fun fromBytes (s: Word8Vector.vector) : real =
        fromBytesS(Byte.bytesToString s)
```

and `sml_bytes_to_real` in `src/Runtime/Math.c` reads 8 bytes from the
data of the string:

```c
size_t
sml_bytes_to_real(size_t d, String s)
{
  double r;
  char* a = s->data;
  r = ((double*)a)[0];
  ...
```

`PackRealBig.fromBytes` reverses the vector and calls
`PackRealLittle.fromBytes`, so it has the same fault.

## The fix

Check the length in `PackRealLittle.fromBytes` (and in
`PackRealBig.fromBytes`, as in the report
`PackRealBig.fromBytes/longer-vector`, which also makes it use the first 8
bytes):

```diff
--- a/basis/PackRealLittle.sml
+++ b/basis/PackRealLittle.sml
@@
     fun fromBytes (s: Word8Vector.vector) : real =
-        fromBytesS(Byte.bytesToString s)
+        if Word8Vector.length s < bytesPerElem then raise Subscript
+        else fromBytesS(Byte.bytesToString s)   (* reads the first 8 bytes *)
```

Tested as a wrapper with the same check in a program built with MLKit
4.7.23, with the `PackReal` structures shadowed: vectors of 7 bytes raise
`Subscript`, and all 80 checks of Rune's `tests/basis/pack_real.sml` and of
`tests/basis/pack_real64.sml` pass (with the fixes of the two other
`PackReal` reports). The patch of the library itself was not built.

## Relation to Rune

The checks `PackRealLittle.fromBytes/Subscript-short`,
`PackRealBig.fromBytes/Subscript-short`,
`PackReal64Little.fromBytes/Subscript-short` and
`PackReal64Big.fromBytes/Subscript-short` (of `tests/basis/pack_real.sml`
and `tests/basis/pack_real64.sml`, from `tests/basis/fn/pack_real_fn.sml`)
fail on MLKit ("no exception raised"). Proposed line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | PackReal[BL6]*.fromBytes/Subscript-short | HOST-BUG | fromBytes does not check the length: of a vector shorter than 8 bytes it reads 8 bytes, past the end of the vector, instead of raising Subscript
```

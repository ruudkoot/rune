# MLKit 4.7.23: `LargeIntVector`, `LargeIntArray`, ... hold `Word64.word`, not `LargeInt.int`

## Status: not reported upstream

It has not been reported upstream from here, and a search of the issues of
[melsman/mlkit](https://github.com/melsman/mlkit/issues) (`LargeInt vector
array`) found no report of it. MLKit's `master` at `c49fbea` (2026-09-25)
has the same `basis/inttables.sml` as 4.7.23, byte for byte, so the bug is
not fixed there either.

## Summary

* **The trigger:** any use of `LargeIntVector`, `LargeIntVectorSlice`,
  `LargeIntArray`, `LargeIntArraySlice` or `LargeIntArray2` with elements
  of type `LargeInt.int`.
* **What goes wrong:** the five structures are `Word64Vector`,
  `Word64VectorSlice`, `Word64Array`, `Word64ArraySlice` and
  `Word64Array2`: their `elem` is `Word64.word`. A program that stores a
  `LargeInt.int` in them does not compile, and one that stores a
  `Word64.word` does.
* **Required behaviour:** the specification gives them the elements of
  `LargeInt.int` (in MLKit `IntInf.int`, unbounded):
  [`MONO_VECTOR`](https://smlfamily.github.io/Basis/mono-vector.html) lists
  `structure LargeIntVector :> MONO_VECTOR (* OPTIONAL *) where type elem =
  LargeInt.int`, and
  [`MONO_ARRAY`](https://smlfamily.github.io/Basis/mono-array.html),
  [`MONO_VECTOR_SLICE`](https://smlfamily.github.io/Basis/mono-vector-slice.html),
  [`MONO_ARRAY_SLICE`](https://smlfamily.github.io/Basis/mono-array-slice.html)
  and [`MONO_ARRAY2`](https://smlfamily.github.io/Basis/mono-array2.html)
  the same for `LargeIntArray`, `LargeIntVectorSlice`,
  `LargeIntArraySlice` and `LargeIntArray2`. The structures are optional,
  but an implementation that provides them must give them this element
  type.

## Environment

* **MLKit:** v4.7.23 (`mlkit --version`: "MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]"), the official binary release
  `mlkit-bin-dist-linux.tgz`, X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The programs are standalone: `bug.mlb`
  lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml` (and `word64.mlb`
  `word64.sml`), built with `mlkit -o bug bug.mlb`; nothing of Rune is
  involved.

## The program

`bug.sml`, which the specification says is a valid program:

```sml
(* MLKit: the element type of LargeIntVector, LargeIntVectorSlice,
   LargeIntArray, LargeIntArraySlice and LargeIntArray2, which the
   specification gives as LargeInt.int *)
(* 10^27, a LargeInt.int that no machine word holds *)
val billion = LargeInt.fromInt 1000000000
val big : LargeInt.int = LargeInt.* (billion, LargeInt.* (billion, billion))
val v = LargeIntVector.fromList [LargeInt.fromInt 1, big]
val () = print (LargeInt.toString (LargeIntVector.sub (v, 1)) ^ "\n")
val a = LargeIntArray.array (2, big)
val () = print (LargeInt.toString (LargeIntArray.sub (a, 0)) ^ "\n")
val m = LargeIntArray2.array (1, 1, big)
val () = print (LargeInt.toString (LargeIntArray2.sub (m, 0, 0)) ^ "\n")
```

```
$ mlkit -o bug bug.mlb
bug.sml, line 7, column 8:
  val v = LargeIntVector.fromList [LargeInt.fromInt 1, big]
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: intinf list -> vector
   but I found operator type:      word64 list -> vector

bug.sml, line 8, column 16:
  val () = print (LargeInt.toString (LargeIntVector.sub (v, 1)) ^ "\n")
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: word64 -> string
   but I found operator type:      intinf -> string

bug.sml, line 9, column 8:
  val a = LargeIntArray.array (2, big)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: int * intinf -> array
   but I found operator type:      int * word64 -> array

bug.sml, line 10, column 16:
  val () = print (LargeInt.toString (LargeIntArray.sub (a, 0)) ^ "\n")
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: word64 -> string
   but I found operator type:      intinf -> string

bug.sml, line 11, column 8:
  val m = LargeIntArray2.array (1, 1, big)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: int * int * intinf -> array
   but I found operator type:      int * int * word64 -> array

bug.sml, line 12, column 16:
  val () = print (LargeInt.toString (LargeIntArray2.sub (m, 0, 0)) ^ "\n")
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: word64 -> string
   but I found operator type:      intinf -> string
Stopping compilation of MLB-file due to error (code 1).
```

(`mlkit` exits with status 255.) With the structures of the specification
it prints `1000000000000000000000000000` three times.

`word64.sml`, which the specification says is not a valid program, is
accepted:

```sml
(* the same structures take Word64.word *)
val v = LargeIntVector.fromList [0w1, 0wxFFFFFFFFFFFFFFFF : Word64.word]
val () = print (Word64.fmt StringCvt.HEX (LargeIntVector.sub (v, 1)) ^ "\n")
val () = print (Word64.toString (LargeIntArray2.sub (LargeIntArray2.array (1, 1, 0w42 : Word64.word), 0, 0)) ^ "\n")
```

```
$ mlkit -o word64 word64.mlb && ./word64
FFFFFFFFFFFFFFFF
2A
```

## The cause

`basis/inttables.sml`, lines 132-140, in the block that makes the `Int64`
structures:

```sml
  (** SigDoc *)
  structure LargeIntVector : MONO_VECTOR = Word64Vector
  (** SigDoc *)
  structure LargeIntVectorSlice : MONO_VECTOR_SLICE = Word64VectorSlice
  (** SigDoc *)
  structure LargeIntArray : MONO_ARRAY = Word64Array
  (** SigDoc *)
  structure LargeIntArraySlice : MONO_ARRAY_SLICE = Word64ArraySlice
  (** SigDoc *)
  structure LargeIntArray2 : MONO_ARRAY2 = Word64Array2
```

These are the lines that bind `LargeWordVector` ... `LargeWordArray2` in
`basis/wordtables.sml` (lines 134-142), with `LargeWord` changed to
`LargeInt` and the right-hand sides left as they were. MLKit's `LargeInt`
is `IntInf` (`basis/IntInf.sml`, line 1036: `structure LargeInt : INTEGER =
IntInf`), whose values the unboxed tables of `basis/wordtable-functors.sml`
cannot hold, and `Int64Vector` (`T.V` of the same block) would not have the
right element type either.

## The fix

Make the five structures of the polymorphic ones at `LargeInt.int`, in
`basis/inttables.sml`:

```sml
structure LargeIntVector : MONO_VECTOR where type elem = LargeInt.int =
struct
  open Vector
  type elem = LargeInt.int
  type vector = elem Vector.vector
end
structure LargeIntVectorSlice : MONO_VECTOR_SLICE where type elem = LargeInt.int
                                                where type vector = LargeIntVector.vector =
struct
  open VectorSlice
  type elem = LargeInt.int
  type vector = elem Vector.vector
  type slice = elem VectorSlice.slice
end
structure LargeIntArray : MONO_ARRAY where type elem = LargeInt.int
                                   where type vector = LargeIntVector.vector =
struct
  open Array
  type elem = LargeInt.int
  type vector = elem Vector.vector
  type array = elem Array.array
end
structure LargeIntArraySlice : MONO_ARRAY_SLICE where type elem = LargeInt.int
                                               where type vector = LargeIntVector.vector
                                               where type vector_slice = LargeIntVectorSlice.slice
                                               where type array = LargeIntArray.array =
struct
  open ArraySlice
  type elem = LargeInt.int
  type vector = elem Vector.vector
  type vector_slice = elem VectorSlice.slice
  type array = elem Array.array
  type slice = elem ArraySlice.slice
end
structure LargeIntArray2 : MONO_ARRAY2 where type elem = LargeInt.int
                                     where type vector = LargeIntVector.vector =
struct
  open Array2
  type elem = LargeInt.int
  type vector = elem Vector.vector
  type array = elem Array2.array
  type region = elem Array2.region
end
```

in place of the five lines above, and make `LargeInt` visible there, in
`basis/basis.mlb`:

```diff
     basis WordArrayVector =
-       let open General List ArrayVector Word Int
+       let open General List ArrayVector Word Int IntInf
            wordtable-functors.sml
```

(`basis IntInf` opens neither `WordArrayVector` nor anything that does, so
this makes no cycle.) The other choice the specification leaves is to drop
the five structures, which are optional.

Tested in part: the five structures above were compiled at the front of a
program on MLKit 4.7.23, in place of the basis library's, not in a build of
MLKit, so the change of `basis.mlb` is untried. With them `bug.sml` prints
`1000000000000000000000000000` three times, Rune's
`tests/basis/mono.largeint_sig.sml` passes all 30 of its checks, and
`tests/basis/mono.largeint.sml` compiles and runs: it then fails only the
checks that `Array2` and `ArraySlice` fail (reports
`Array2.appi/invalid-region-accepted`,
`Array2.copy/destination-uses-source-dimensions` and
`ArraySlice.copy/Overflow-not-Subscript`), as `LargeIntArray2.*` and
`LargeIntArraySlice.copy/Subscript-not-Overflow`.

A second fix, `alternative-fix.patch`, leaves `basis.mlb` as it is: it
declares the five structures at the end of `basis/inttables.sml` with the
compiler's primitive type `intinf`, which `LargeInt.int` is, over the
polymorphic `Vector`, `VectorSlice`, `Array`, `ArraySlice` and `Array2`.
It was built into a copy of MLKit's library, and Rune's
`tests/basis/mono.largeint_sig.sml` then passes all its 30 checks.

## Relation to Rune

Rune's Basis Library suite has two tests of these structures (Rune commit
`d180cfa`): `tests/basis/mono.largeint.sml`, whose checks need elements of
`LargeInt.int` (10^27 among them), and `tests/basis/mono.largeint_sig.sml`,
which matches the structures against the signatures of the specification
`where type elem = LargeInt.int`. On MLKit 4.7.23 neither compiles:
`@load/mono.largeint` fails with "Error in signature matching" at line 24
(the application of `TestMonoVectorFn` to `LargeIntVector`), and
`@load/mono.largeint_sig` with "Rigid type clash for: elem". The line of
`tests/basis/deviations.txt` for the first:

```
native:mlkit@* | @load/mono.largeint | HOST-BUG | LargeIntVector, LargeIntVectorSlice, LargeIntArray, LargeIntArraySlice and LargeIntArray2 are those of Word64, whose elem is Word64.word and not LargeInt.int: the test does not compile
```

and the second has the same cause (`@load/mono.largeint*` would cover both).

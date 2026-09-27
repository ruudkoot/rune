# MLKit 4.7.23: no constants and no overloaded operators at `Int8.int`, `Int16.int` and `Word16.word`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton compiles the program; SML/NJ and Poly/ML have no `Int8`.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same `basis/IntN.sml`, `basis/Ints.sml`, `basis/WordN.sml`,
`basis/Word16.sml`, `src/Common/EfficientElab/StatObject.sml` and
`src/Common/EfficientElab/Environments.sml` as 4.7.23 (the files are
identical), so it is not fixed there either.

## Summary

* **The trigger:** an integer constant at type `Int8.int` or `Int16.int`,
  a word constant at `Word16.word`, or an overloaded operator (`+`, `-`,
  `*`, `div`, `mod`, `~`, `abs`, `<`, ...) applied to values of these
  types.
* **What goes wrong:** the program does not compile: MLKit reports a type
  clash (with the confusing wording "type of left-hand side pattern: int,
  type of right-hand side expression: int"). Values of these types can
  only be made and combined with the functions of their structures
  (`Int8.fromInt`, `Int8.+`, ...).
* **Required behaviour:** the
  [top-level environment chapter](https://smlfamily.github.io/Basis/top-level-chapter.html)
  of the Basis Library defines the overloading classes as
  `int = {FixedInt.int, Int.int, Int<N>.int, IntInf.int, LargeInt.int, Position.int}`
  and `word = {LargeWord.word, Word.word, Word8.word, Word<N>.word, SysWord.word}`,
  noting that `Int<N>.int` and `Word<N>.word` "are optional types": a
  structure `Int8` that is provided has its type in the class, and the
  overloaded operators, and the constants of the class (the chapter's
  example is `val x = (1 : LargeInt.int)`), are available at it. MLKit
  provides `Int8`, `Int16` and `Word16`, and does overload constants and
  operators at `Int32.int`, `Int64.int`, `Word8.word`, `Word32.word` and
  `Word64.word`.

## Environment

* **MLKit:** v4.7.23 (`MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00)
  [X64 Backend]`), the official binary release `mlkit-bin-dist-linux.tgz`.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is standalone, built as
  `bug.mlb` (`$(SML_LIB)/basis/basis.mlb` and `bug.sml`) with
  `mlkit -o bug bug.mlb`.

## The program

`bug.sml`:

```sml
(* The specification puts Int<N>.int in the overloading class int and
   Word<N>.word in word (the top-level environment chapter), so integer and
   word constants and the overloaded operators (+, <, ...) are available at
   Int8.int, Int16.int and Word16.word.  MLKit rejects each of the lines below;
   the same lines at Int32.int and Word32.word compile. *)
val a : Int8.int = 63
val b = fn (x : Int16.int, y) => x + y
val c : Word16.word = 0wxFFFF
val () = print (Int8.toString a ^ "\n")
```

```
$ mlkit -o bug bug.mlb; echo "exit status $?"
[reading source file:	bug.sml]

bug.sml, line 6, column 4:
  val a : Int8.int = 63
      ^^^^^^^^^^^^^^^^^
Type clash,
   type of left-hand side pattern:     int
   type of right-hand side expression: int

bug.sml, line 7, column 33:
  val b = fn (x : Int16.int, y) => x + y
                                   ^^^^^
Type clash,
   operand suggests operator type: int * 'a -> 'b
   but I found operator type:      int * int -> int

bug.sml, line 8, column 4:
  val c : Word16.word = 0wxFFFF
      ^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   type of left-hand side pattern:     word
   type of right-hand side expression: word
Stopping compilation of MLB-file due to error (code 1).
exit status 255
```

The same three declarations at `Int32.int` and `Word32.word`
(`contrast.sml`, built as `contrast.mlb`) compile and run:

```sml
(* the lines of bug.sml at Int32.int and Word32.word, which MLKit accepts *)
val a : Int32.int = 63
val b = fn (x : Int32.int, y) => x + y
val c : Word32.word = 0wxFFFF
val () = print (Int32.toString (b (a, 1)) ^ " " ^ Word32.toString c ^ "\n")
```

```
$ mlkit -o contrast contrast.mlb
[reading source file:	contrast.sml]
[wrote X64 code file:	MLB/RI_GC/contrast.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	contrast]
$ ./contrast
64 FFFF
```

## The cause

`Int8` and `Int16` are made by the functor `IntN` of `basis/IntN.sml`,
which is ascribed opaquely, and `basis/Ints.sml` applies it:

```sml
functor IntN(I : INTEGER) :> INTEGER =
  struct
    ...
structure Int8 = IntN(struct open Int val precision=SOME 8 end)
structure Int16 = IntN(struct open Int val precision=SOME 16 end)
```

and `Word16` is `WordN(struct open Word val wordSize = 16 end)`
(`basis/Word16.sml`), with `functor WordN(W : WORD) :> WORD`
(`basis/WordN.sml`). `Int8.int`, `Int16.int` and `Word16.word` are
therefore new abstract types. The elaborator's overloading classes, on the
other hand, are fixed sets of the compiler's primitive type names: for an
integer constant `of_scon` in `src/Common/EfficientElab/StatObject.sml`
offers `tyName_INTINF`, `tyName_INT32`, `tyName_INT31`, `tyName_INT64` and
`tyName_INT63`, and for a word constant `tyName_WORD8`, `tyName_WORD31`,
`tyName_WORD32`, `tyName_WORD63` and `tyName_WORD64`; the overloaded
operators are given the same type names (with `tyName_REAL`, and
`tyName_CHAR` and `tyName_STRING` for the comparisons) in
`src/Common/EfficientElab/Environments.sml` (`tyvar_num`, `tyvar_realint`,
`tyvar_numtxt`, `tyvar_wordint`). An abstract type made by a functor can
be in none of these sets.

## The fix

Not proposed as a patch: it needs `Int8.int`, `Int16.int` and
`Word16.word` to be types the compiler knows, as `word8` is (a primitive
type name in `src/Common/TyName.sml`, added to the sets of `StatObject.sml`
and to the primitives the operators are resolved to), or some other way to
let a library type join an overloading class. Nothing was tried.

## Relation to Rune

The Rune tests `tests/basis/intn_int8.sml`, `intn_int16.sml` and
`intn_word16.sml` (Rune at `3d83f11`) have a section `constants`
(lines 14-20, 14-20 and 15-20) with checks such as
`Int8.+/overloaded` (`(63 : Int8.int) + 64`) and `Word16.+/wraps`
(`(0wxFFFF : Word16.word) + 0w5`). On MLKit the section does not compile,
which the matrix reports as `@section/intn_int8/constants`,
`@section/intn_int16/constants` and `@section/intn_word16/constants`;
the rest of the three tests runs. The failures are explained in
`tests/basis/deviations.txt` by

```
native:mlkit@* | @section/intn_*[68]/constants | HOST-BUG | no integer or word constant and no overloaded operator at Int8.int, Int16.int and Word16.word: they are abstract types made by the functors IntN and WordN, and the overloading classes of the compiler hold only its primitive types
```

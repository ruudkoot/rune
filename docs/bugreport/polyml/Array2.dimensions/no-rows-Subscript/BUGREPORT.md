# Poly/ML 5.9.2: `Array2.dimensions` of an array with no rows raises `Subscript`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and 2026.2, and MLKit 4.7.23) does this.** MLton and MLKit get every line of the program right that they can run; SML/NJ gives `(0, 0)` for `fromList []`, but loses the other dimension of `array (0, 5, 0)` and `array (5, 0, 0)`, a fault of its own.

## Status: not reported upstream

It has not been reported upstream from here, and a search of the issues of
[polyml/polyml](https://github.com/polyml/polyml/issues) (`Array2`,
`Array2 empty`, `Array2 Subscript`, `Array2 equality`, `Array2.array`,
`nCols`, `nRows`, `dimensions`, `empty array`, `zero rows`,
`two-dimensional`) found no report of it; the two hits,
[#126](https://github.com/polyml/polyml/issues/126) and
[#128](https://github.com/polyml/polyml/issues/128), are about loading
`libpolyml.so` and about `Array.update`. `basis/Array2.sml` and
`basis/IntArray2.sml` on `master` at `4221cec` (2026-10-10) are the same
as in 5.9.2, byte for byte, so it is not fixed there either. The source
knows of the main fault: a comment over `nCols` says "This next is wrong in
the case where nRows = 0. It'll do for the moment."

## Summary

* **The trigger:** a two-dimensional array with no rows: `Array2.fromList
  []`, `Array2.array (0, c, x)` or `Array2.tabulate trv (0, c, f)`, or the
  same of Poly/ML's MONO_ARRAY2 structures, `IntArray2`, `RealArray2`,
  `BoolArray2`, `CharArray2` and `Word8Array2`.
* **What goes wrong:**
  * `nCols` and `dimensions` raise `Subscript` (`nRows` gives 0). So do
    `app`, `fold`, `modify`, `appi`, `foldi` and `modifyi` over any region
    of it, `copy` from it or into it, and the top level's printing of it:
    `val e = Array2.fromList [] : int Array2.array;` at the prompt says
    `Exception- Subscript raised` instead of printing `e` (which is bound
    all the same).
  * The number of columns of `array (0, c, x)` is not kept anywhere, so a
    `nCols` that did not raise could not give `c` either. For the same
    reason `array (0, ~1, x)` and `tabulate RowMajor (0, ~1, f)` do not
    raise `Size`, and `column (array (0, 5, x), j)` is an empty vector for
    every `j`, such as `5` and `~1`, instead of raising `Subscript` (in
    `Array2` and in the MONO_ARRAY2 structures).
  * Every array with no rows is equal to every other: `Array2.fromList [] =
    Array2.fromList []` is `true`.
  * In the MONO_ARRAY2 structures, `row (a, i)` of an array with no
    columns is an empty vector for every `i`:
    `IntArray2.row (IntArray2.array (3, 0, 0), 7)` does not raise
    `Subscript`.
* **Required behaviour:** the
  [Basis `ARRAY2` specification](https://smlfamily.github.io/Basis/array2.html):
  * of `dimensions`, `nCols` and `nRows`: "nCols returns the number of
    columns, nRows returns the number of rows, and dimension returns a pair
    containing the number of rows and the number of columns of the array.
    The functions nRows and nCols are respectively equivalent to #1 o
    dimensions and #2 o dimensions";
  * of `array (r, c, init)`: it "creates a new array with r rows and c
    columns, with each element initialized to the value init. If r < 0, c <
    0 or the resulting array would be too large, the Size exception is
    raised." `tabulate` says the same of `r` and `c`;
  * of `app`, `fold` and `modify`: each is `appi`, `foldi` or `modifyi`
    over `{base=arr,row=0,col=0,nrows=NONE,ncols=NONE}`, a region that is
    valid for every array ("0 <= #row reg <= nRows (#base reg)");
  * of `row (arr, i)`: "If (nRows arr) <= i or i < 0, this raises
    Subscript", and of `column (arr, j)`: "This raises Subscript if j < 0
    or nCols arr <= j";
  * of equality: "two arrays are equal if they are the same array, i.e.,
    created by the same call to a primitive array constructor such as
    array, fromList, etc.; otherwise they are not equal. This also holds for
    arrays of zero length."

  The specification does not say how many columns `fromList []` has; MLton,
  SML/NJ, MLKit and Rune give 0, as does the fix below. An array with no
  columns but some rows, such as `array (5, 0, 0)`, is right, but for the
  `row` of the MONO_ARRAY2 structures.

## Environment

* **Poly/ML:** 5.9.2 (`poly -v`: "Poly/ML 5.9.2 Release RTS version:
  X86_64-5.9.2"), built from the release's sources with `./configure`
  (with GMP) and `make`; the native x86-64 code generator.
* **System:** Linux x86-64, Ubuntu 24.04 on WSL2.
* **Basis Library: Poly/ML's own.** The program is standalone, `poly
  --script bug.sml`, with nothing of Rune involved.

## The program

`bug.sml`:

```sml
(* Poly/ML 5.9.2: two-dimensional arrays with no rows.
   Each line shows what the Basis Library gives, and what the specification
   asks for where that differs. *)
fun check (what : string) (expected : string) (f : unit -> string) =
  let val got = f () handle e => "raised " ^ exnName e
  in print (what ^ ": " ^ got
            ^ (if got = expected then "" else "    <- WRONG, should be " ^ expected)
            ^ "\n")
  end
fun pair (r, c) = "(" ^ Int.toString r ^ ", " ^ Int.toString c ^ ")"

val empty : int Array2.array = Array2.fromList []
val noRows : int Array2.array = Array2.array (0, 5, 0)    (* 0 rows of 5 columns *)

val () = check "Array2.nRows (fromList [])" "0"
  (fn () => Int.toString (Array2.nRows empty))
val () = check "Array2.nCols (fromList [])" "0"
  (fn () => Int.toString (Array2.nCols empty))
val () = check "Array2.dimensions (fromList [])" "(0, 0)"
  (fn () => pair (Array2.dimensions empty))
val () = check "Array2.dimensions (array (0, 5, 0))" "(0, 5)"
  (fn () => pair (Array2.dimensions noRows))
val () = check "Array2.dimensions (tabulate RowMajor (0, 5, f))" "(0, 5)"
  (fn () => pair (Array2.dimensions (Array2.tabulate Array2.RowMajor (0, 5, fn _ => 0))))
val () = check "Array2.fold RowMajor op+ 0 (fromList [])" "0"
  (fn () => Int.toString (Array2.fold Array2.RowMajor op+ 0 empty))
val () = check "Array2.app RowMajor ignore (array (0, 5, 0))" "()"
  (fn () => (Array2.app Array2.RowMajor ignore noRows; "()"))
val () = check "Array2.modify ColMajor ~ (fromList [])" "()"
  (fn () => (Array2.modify Array2.ColMajor ~ empty; "()"))
val () = check "Array2.copy all of fromList [] into a 2 x 2 array" "()"
  (fn () => (Array2.copy {src = {base = empty, row = 0, col = 0, nrows = NONE, ncols = NONE},
                          dst = Array2.array (2, 2, 0), dst_row = 0, dst_col = 0};
             "()"))
val () = check "Array2.column (array (0, 5, 0), 5)" "raised Subscript"
  (fn () => Int.toString (Vector.length (Array2.column (noRows, 5))) ^ " elements")
val () = check "Array2.array (0, ~1, 0)" "raised Size"
  (fn () => (ignore (Array2.array (0, ~1, 0)); "()"))
val () = check "fromList [] = fromList []" "false"
  (fn () => Bool.toString (empty = Array2.fromList []))
val () = check "array (0, 5, 0) = array (0, 5, 0)" "false"
  (fn () => Bool.toString (noRows = Array2.array (0, 5, 0)))
(* for contrast: no columns *)
val () = check "Array2.dimensions (array (5, 0, 0))" "(5, 0)"
  (fn () => pair (Array2.dimensions (Array2.array (5, 0, 0))))

(* The MONO_ARRAY2 structures *)
val () = check "IntArray2.dimensions (IntArray2.fromList [])" "(0, 0)"
  (fn () => pair (IntArray2.dimensions (IntArray2.fromList [])))
val () = check "RealArray2.dimensions (RealArray2.fromList [])" "(0, 0)"
  (fn () => pair (RealArray2.dimensions (RealArray2.fromList [])))
val () = check "BoolArray2.dimensions (BoolArray2.fromList [])" "(0, 0)"
  (fn () => pair (BoolArray2.dimensions (BoolArray2.fromList [])))
val () = check "CharArray2.dimensions (CharArray2.fromList [])" "(0, 0)"
  (fn () => pair (CharArray2.dimensions (CharArray2.fromList [])))
val () = check "Word8Array2.dimensions (Word8Array2.fromList [])" "(0, 0)"
  (fn () => pair (Word8Array2.dimensions (Word8Array2.fromList [])))
val () = check "IntArray2.row (IntArray2.array (3, 0, 0), 7)" "raised Subscript"
  (fn () => Int.toString (IntVector.length (IntArray2.row (IntArray2.array (3, 0, 0), 7)))
            ^ " elements")
```

```
$ poly --script bug.sml
Array2.nRows (fromList []): 0
Array2.nCols (fromList []): raised Subscript    <- WRONG, should be 0
Array2.dimensions (fromList []): raised Subscript    <- WRONG, should be (0, 0)
Array2.dimensions (array (0, 5, 0)): raised Subscript    <- WRONG, should be (0, 5)
Array2.dimensions (tabulate RowMajor (0, 5, f)): raised Subscript    <- WRONG, should be (0, 5)
Array2.fold RowMajor op+ 0 (fromList []): raised Subscript    <- WRONG, should be 0
Array2.app RowMajor ignore (array (0, 5, 0)): raised Subscript    <- WRONG, should be ()
Array2.modify ColMajor ~ (fromList []): raised Subscript    <- WRONG, should be ()
Array2.copy all of fromList [] into a 2 x 2 array: raised Subscript    <- WRONG, should be ()
Array2.column (array (0, 5, 0), 5): 0 elements    <- WRONG, should be raised Subscript
Array2.array (0, ~1, 0): ()    <- WRONG, should be raised Size
fromList [] = fromList []: true    <- WRONG, should be false
array (0, 5, 0) = array (0, 5, 0): true    <- WRONG, should be false
Array2.dimensions (array (5, 0, 0)): (5, 0)
IntArray2.dimensions (IntArray2.fromList []): raised Subscript    <- WRONG, should be (0, 0)
RealArray2.dimensions (RealArray2.fromList []): raised Subscript    <- WRONG, should be (0, 0)
BoolArray2.dimensions (BoolArray2.fromList []): raised Subscript    <- WRONG, should be (0, 0)
CharArray2.dimensions (CharArray2.fromList []): raised Subscript    <- WRONG, should be (0, 0)
Word8Array2.dimensions (Word8Array2.fromList []): raised Subscript    <- WRONG, should be (0, 0)
IntArray2.row (IntArray2.array (3, 0, 0), 7): 0 elements    <- WRONG, should be raised Subscript
```

## The other implementations

The same program, each against its own Basis Library:

* **MLton 20241230** (`mlton bug.mlb`, the `.mlb` listing
  `$(SML_LIB)/basis/basis.mlb` and `bug.sml`): no line is wrong.
* **MLKit 4.7.23** (`mlkit -o bug bug.mlb`), without the lines of
  `CharArray2` and `Word8Array2`, which it does not have: no line is wrong.
* **SML/NJ 110.99.9 and 2026.2** (64-bit; `sml bug.sml`), without the
  MONO_ARRAY2 part, as SML/NJ has none of those structures: two lines are
  wrong, the same on both, and they are SML/NJ's own fault, not this one.
  Its `array` makes every array without elements `(0, 0)`
  (`base/system/Basis/Implementation/array2.sml`, `fun array`), while its
  `tabulate` keeps them:

  ```
  Array2.dimensions (array (0, 5, 0)): (0, 0)    <- WRONG, should be (0, 5)
  Array2.dimensions (array (5, 0, 0)): (0, 0)    <- WRONG, should be (5, 0)
  ```

  Every other line is right there, `fromList []` included.
* **Rune** (`bin/rune bug.sml -o bug.rbc && bin/runevm bug.rbc` in this
  repository): no line is wrong.

## The cause

`basis/Array2.sml` holds an array as its vector of rows and nothing else
(lines 25-34):

```sml
    (* This is implemented as a vector of rows i.e. Vector.sub(v, 0)
       returns the first row, Vector.sub(v, 1) the second. *)
    (* It's a bit messy though.  In order for this to be an eqtype for
       any 'a it needs to be treated specially by the compiler so we
       have to inherit a type that has been created specially for the
       purpose. *)
    type 'a array = 'a Bootstrap.array
    type 'a implementation = 'a Array.array Vector.vector
```

and takes the number of columns from the first row (lines 88-98):

```sml
    fun nRows a = Vector.length(fromArray a)

    (* This next is wrong in the case where nRows = 0. It'll do
       for the moment. *)
    fun nCols a = Array.length(Vector.sub(fromArray a, 0))

    fun dimensions a = (nRows a, nCols a)

    fun row(a, i) = Array.vector(Vector.sub(fromArray a, i))

    fun column(a, j) = Vector.tabulate(nRows a, fn i => sub(a, i, j))
```

With no rows there is no first row, and `Vector.sub (v, 0)` raises
`Subscript`. Everything else follows:

* `getRegion` (lines 102-127), the check of a region behind `appi`,
  `foldi`, `modifyi` and `copy`, and so behind `app`, `fold` and `modify`,
  starts with `val (lRows, lCols) = dimensions base`. `copy` also takes the
  `dimensions` of `dst`. The pretty printer installed at the end of the
  file starts with `val (nrows, ncols) = dimensions x` (line 238).
* `array` (lines 47-48) is

  ```sml
      fun array(r, c, init) =
          toArray(Vector.tabulate(r, fn _ => Array.array(c, init)))
  ```

  With `r = 0`, `Array.array (c, init)` is never called: `c` is not kept,
  nor checked for `Size`. `tabulate RowMajor` (lines 64-65) is the same;
  `tabulate ColMajor` tabulates the columns first, and does raise `Size`.
* `column` with no rows tabulates nothing, so `sub` never checks `j`.
* Equality on `'a Bootstrap.array` is pointer equality (`array2Constr` in
  `mlsource/MLCompiler/TYPE_TREE.ML`, with `equalPointerOrWordFn`), and the
  pointer is to the vector of rows. `Vector.fromList []` and
  `Vector.tabulate (0, _)` both return the one shared empty vector
  (`basis/Vector.sml`, lines 74 and 97: `wordAsVec
  LibrarySupport.emptyVector`), so all arrays with no rows are one object.

The MONO_ARRAY2 structures of `basis/IntArray2.sml` are `Array2` opened,
with all of the above, and a `row` and `column` of their own (lines 72-76
for `Word8Array2`, the same in the other four):

```sml
    (* Have to redefine row and column in terms of Word8Vector. *)
    fun row(a, i) =
        Word8Vector.tabulate(nCols a, fn j => sub(a, i, j))
    and column(a, j) =
        Word8Vector.tabulate(nRows a, fn i => sub(a, i, j))
```

With no columns, `row` tabulates nothing and `i` is never checked, as `j`
is not in `column` with no rows.

## The fix

`fix.patch`, against the sources of 5.9.2 (`git apply --check` passes
there, and on `master` the two files are the same):

* `basis/Array2.sml`: an array is `{rows, cols}`, its vector of rows and
  its number of columns, in a `ref`; `nCols` reads `cols`; `array` and
  `tabulate RowMajor` raise `Size` for `c < 0` themselves; `fromList` takes
  the number of columns from the length check it already makes (0 for no
  rows); `column` checks `j` against `nCols`. Everything else reaches the
  rows through `rowsOf`.
* `basis/IntArray2.sml`: the `row` and `column` of the five structures
  check their index first.

The `ref` is for equality. A fresh cell for each array makes two arrays
equal only if they are the same one, with no rows too. A plain record
`{rows, cols}` would be fresh at each call, but it is immutable, and
`PolyML.shareCommonData` merges immutable objects of equal contents: two
records `{rows = <the empty
vector>, cols = 5}`, cast to `int Array2.array`, were unequal until
`PolyML.shareCommonData`, and equal after it. Two arrays of the patched
`Array2` stay unequal through the same steps. The cost is one more load in
`sub` and `update`.

A smaller change, `fun nCols a = if nRows a = 0 then 0 else ...`, would
end the exceptions and pass the law below, but `array (0, 5, x)` would then
have the dimensions `(0, 0)`, and the faults of `Size`, `column` and
equality would stay.

Tested, but not in a build of Poly/ML, which cannot be rebuilt here. The
patched `basis/Array2.sml` and `basis/IntArray2.sml` were `use`d, as they
are, in front of the programs on the released 5.9.2, after

```sml
structure Bootstrap = struct type 'a array = 'a Array2.array end;
```

which gives them the type the compiler makes for `Array2.array`, with its
pointer equality.

* `bug.sml` then prints no wrong line.
* At the prompt, `val e = Array2.fromList [] : int Array2.array;` prints
  `val e = fromList[]: int Array2.array`.
* Rune's Basis Library suite, `tests/basis/array2.sml` (1255 checks): 71
  fail on 5.9.2 and 18 with the fix; `tests/basis/chararray2.sml`, the
  MONO_ARRAY2 checks at `CharArray2` (1263 checks): 73 and 18. The 18 left
  in each are another fault the patch leaves alone: the region checks of
  `getRegion` and `copy` compute `r+row` and `dst_row+nrows` with `int`
  addition, which raises `Overflow` where `Subscript` is due (Rune's
  `tests/basis/deviations.txt`, lines 261 and 759). No check that passed
  before fails with the fix.
* The eleven laws of `ARRAY2` (below) pass; without the fix `nRows`'s
  fails.

While checking that the new representation reaches nothing outside the two
files: `modules/IntInfAsInt/ArrayVector.sml` wraps `Array2` with `open
Array2` and is not affected, but it binds `column = fn (a, i) => row(a,
FixedInt.fromLarge i)`, so with `PolyML.loadModule "IntInfAsInt"`,
`Array2.column (Array2.fromList [[1, 2], [3, 4]], 0)` is the row `#[1, 2]`.
That is a fault of its own, not reported here.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` in the
comments of a signature is tested on generated values. The law of `nRows`
in `lib/basis/sig_array2.sml` is

```
Law: `nRows arr = #1 (dimensions arr)`
```

`tests/basis/run-laws-hosts.py` runs the laws against the Basis Library of
each of the other compilers, here Poly/ML's own (`docs/plans/quickcheck-hunt.md`,
the sections "The other compilers (D10, 2026-10-10)" and "D10 on the split
library (2026-10-10 and 11)"). Poly/ML failed it at the first case:

```
FAIL ARRAY2.nRows/law-1@Array2: right raised Subscript at case 1 (size 100): left 0; Subscript
```

The law of `nCols`, `nCols arr = #2 (dimensions arr)`, passes there, as
both of its sides raise `Subscript`. The lines of
`tests/basis/law-deviations.txt`:

```
native:polyml | ARRAY2.nRows/law-1@Array2 | HOST-BUG | Array2.dimensions of an empty array raises Subscript (dimensions (Array2.fromList []) should be (0, 0)), so nRows arr = #1 (dimensions arr) fails at it
native:polyml | MONO_ARRAY2.nRows/law-1@* | HOST-BUG | dimensions of an empty array raises Subscript, as Array2's does
```

Rune's Basis Library suite had met the same faults before:
`tests/basis/deviations.txt`, lines 262-265 for `Array2` and 760-763 for
the MONO_ARRAY2 structures (no number of columns, no `Size` for `array (0,
~1, x)`, arrays with no rows equal).

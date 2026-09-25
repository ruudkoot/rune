# Poly/ML 5.9.2: `Substring.substring`/`extract` raise `Overflow` instead of `Subscript`

## Status: reported upstream, unfixed

Filed as [polyml/polyml#315](https://github.com/polyml/polyml/issues/315) on
2026-09-25. No matching report existed before that (searched `substring`,
`extract`, `overflow subscript`, `bounds`, `Substring.substring`,
`Substring.extract`). Inspection of `basis/String.sml` on the current
`master` branch shows the same code that causes the bug below is still
present, so it is not fixed either.

## Summary

* **The trigger:** `Substring.substring (s, i, j)` or `Substring.extract`
  where `i` and/or `j` are large enough (individually valid `int` values,
  such as `valOf Int.maxInt`) that `i + j` overflows fixed-precision `int`
  arithmetic.
* **Required behavior:** the
  [Basis `SUBSTRING` specification](https://smlfamily.github.io/Basis/substring.html)
  says "Implementations of these functions must perform bounds checking in
  such a way that the `Overflow` exception is not raised" — an out-of-range
  index must raise `Subscript`, never `Overflow`.
* **`String.substring`/`extract` in the very same file already do this
  correctly**; only `Substring`'s own `substring`/`extract` are affected.

## Environment

* **Poly/ML:** 5.9.2, the official release.
* **System:** Linux x86-64.
* **Basis Library: Poly/ML's own.** The program is standalone,
  `poly --script bug.sml`, with nothing of Rune involved.

## The program

`bug.sml`:

```sml
fun check name f =
  (ignore (f ()); print (name ^ ": UNEXPECTED no exception\n"))
  handle Subscript => print (name ^ ": Subscript (expected)\n")
       | Overflow => print (name ^ ": Overflow (WRONG: expected Subscript)\n")
       | e => print (name ^ ": UNEXPECTED " ^ General.exnName e ^ "\n")

val big = valOf Int.maxInt
val small = valOf Int.minInt

val () = check "Substring.substring (s, 1, big)"              (fn () => Substring.substring ("abcde", 1, big))
val () = check "Substring.substring (s, big, 1)"               (fn () => Substring.substring ("abcde", big, 1))
val () = check "Substring.substring (s, big, big)"             (fn () => Substring.substring ("abcde", big, big))
val () = check "Substring.extract (s, 1, SOME big)"            (fn () => Substring.extract ("abcde", 1, SOME big))
val () = check "Substring.extract (s, small, NONE)"            (fn () => Substring.extract ("abcde", small, NONE))
val () = check "String.substring (s, 1, big) (for contrast)"   (fn () => String.substring ("abcde", 1, big))
```

```
$ poly --script bug.sml
Substring.substring (s, 1, big): Overflow (WRONG: expected Subscript)
Substring.substring (s, big, 1): Overflow (WRONG: expected Subscript)
Substring.substring (s, big, big): Overflow (WRONG: expected Subscript)
Substring.extract (s, 1, SOME big): Overflow (WRONG: expected Subscript)
Substring.extract (s, small, NONE): Overflow (WRONG: expected Subscript)
String.substring (s, 1, big) (for contrast): Subscript (expected)
```

`String.substring` on the exact same inputs already raises `Subscript`
correctly; only the `Substring` structure's own bounds check is wrong.

## The cause

`basis/String.sml` defines `String.substring`/`extract` using `word`
arithmetic specifically to avoid the overflow:

```sml
fun substring (s, i, j) =
    let
        val len = sizeAsWord s
        (* Check that the index and length are both non-negative. *)
        val i' = unsignedShortOrRaiseSubscript i
        and j' = unsignedShortOrRaiseSubscript j
    in
        if i'+j' > len
        then raise Subscript
        else unsafeSubstring(s, i', j')
    end

fun extract (s, i, NONE) = substring (s, i, size s - i)
 |  extract (s, i, SOME j) = substring (s, i, j)
```

`unsignedShortOrRaiseSubscript` (`basis/LibrarySupport.sml`) rejects a
negative or too-large `int` with `Subscript` and otherwise casts it to
`word`; the bounds check then adds two `word`s, which cannot spuriously
raise `Overflow`.

`Substring.substring`/`extract`, further down in the same file, are instead
hand-written with plain, checked `int` arithmetic:

```sml
(* Check that the index and length are valid. *)
fun substring(s, i, j) =
    if i < 0 orelse j < 0 orelse String.size s < i+j
    then raise General.Subscript
    else Slice{vector=s, start=intAsWord i, length=intAsWord j}

fun extract(s, i, NONE) = substring(s, i, String.size s-i)
 |  extract(s, i, SOME j) = substring(s, i, j)
```

`i+j` is computed as a boxed/tagged `int` addition before the comparison
happens at all, so when `i` and `j` are both large, fixed-precision integer
overflow checking (`INSTR_fixedAdd` in `libpolyml/bytecode.cpp`, or the
equivalent native-code check) raises `Overflow` first. The `extract(s, i,
NONE)` case has the same problem in `String.size s - i` when `i` is very
negative (`small` above).

## The fix

Give `Substring.substring`/`extract` the same treatment as
`String.substring`/`extract`: validate and convert to `word` with
`LibrarySupport.unsignedShortOrRaiseSubscript` before adding.

```sml
fun substring(s, i, j) =
    let
        val i' = LibrarySupport.unsignedShortOrRaiseSubscript i
        val j' = LibrarySupport.unsignedShortOrRaiseSubscript j
    in
        if i'+j' > sizeAsWord s
        then raise General.Subscript
        else Slice{vector=s, start=i', length=j'}
    end

fun extract(s, i, NONE) =
    let val i' = LibrarySupport.unsignedShortOrRaiseSubscript i
    in
        if i' > sizeAsWord s
        then raise General.Subscript
        else Slice{vector=s, start=i', length=sizeAsWord s - i'}
    end
  | extract(s, i, SOME j) = substring(s, i, j)
```

`unsignedShortOrRaiseSubscript` already raises `Subscript` for a negative
`i`, so the `extract(s, i, NONE)` case no longer computes `String.size s -
i` on a possibly-huge-magnitude negative `int` first. This mirrors an
identical pattern already used elsewhere in the same file, e.g.
`VectorSliceOperations.subslice` (used by every other monomorphic vector
slice type), so the technique is already established and low-risk in this
codebase; it has not been tried against a build of Poly/ML `master` (only
against the released 5.9.2 runtime, which shares the same source for this
function).

## Relation to Rune

Rune's own Basis Library implements `Substring.substring`/`extract`
independently (see
[`lib/basis/substring.sml`](https://github.com/ruudkoot/rune/blob/e840204151663baf1139c8096b566301e9ced37d/lib/basis/substring.sml#L22-L30),
whose checks are written "so that they cannot overflow: `n > size s - i`,
not `i + n > size s`") and does not have this bug. Rune's Basis Library
suite already covers this exact case in the "overflow" section of
[`tests/basis/substring.sml`](https://github.com/ruudkoot/rune/blob/e840204151663baf1139c8096b566301e9ced37d/tests/basis/substring.sml#L326-L359)
(`Substring.substring/Subscript-not-Overflow-sum-*`,
`Substring.extract/SOME-Subscript-not-Overflow-sum-*`,
`Substring.extract/NONE-Subscript-not-Overflow-smallest`, built from
`Int.maxInt`/`Int.minInt`), and records it as a known `HOST-BUG` for
`polyml@*` in
[`tests/basis/deviations.txt`](https://github.com/ruudkoot/rune/blob/e840204151663baf1139c8096b566301e9ced37d/tests/basis/deviations.txt#L181-L183).
`sh tests/basis/run-matrix.sh --configs native:polyml substring` against the
pinned `polyml-5.9.2` reproduces the same 7 failures and 0 unexplained ones.
(Links are pinned to commit `e840204` of
[ruudkoot/rune](https://github.com/ruudkoot/rune); the repository is public
but not otherwise affiliated with Poly/ML.)

This was first found independently while investigating SML/NJ regression
suite differences in the `rune-corpus-sml97` companion repository
(`packages/smlnj-regressions/95b939d/suites/basis-expanded/1/known-differences.md`,
"Poly/ML 5.9.2: extreme substring bounds").

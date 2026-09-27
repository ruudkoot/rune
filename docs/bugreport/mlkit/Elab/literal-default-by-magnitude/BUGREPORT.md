# MLKit 4.7.23: a literal of 2^30 or more that nothing constrains gets `int32`, or crashes the compiler

## Status: not reported upstream

This has not been sent to MLKit. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Common/ElabDec.sml` as the tag `v4.7.23`,
so the bug is still there.

## Summary

* **The trigger:** an integer or word literal whose declaration leaves its
  type open, so that the default decides it. For example
  `val big = 1073741824` alone, then `big` used as an `int` in a later
  declaration.
* **What goes wrong:** MLKit does not default such a literal to `int`
  (63 bits on MLKit) when its value is 2^30 or more.
  * **From 2^30 to 2^31 - 1:** it gets `int32`, and a later
    `Int.toString big` is a type clash (`bug.sml`).
  * **From 2^31 up:** the compiler stops with `Impossible: resolve_tv.hmm`
    (`bug-crash.sml`).
  * **Words:** `0wx80000000` gets `word32` in the same way
    (`bug-word.sml`).
  * **Below 2^30** the default is `int`, as it should be.
* **Required behaviour:** the
  [Definition of Standard ML](https://smlfamily.github.io/sml97-defn.pdf)
  (1997), appendix E, gives an overloaded constant its default type, `int`
  or `word`, when its context does not determine another. SML/NJ 110.99.9
  and Poly/ML 5.9.2, whose `int` has 63 bits like MLKit's, compile and run
  all three programs. MLton 20241230 runs `bug.sml` and `bug-word.sml`, and
  rejects `bug-crash.sml` with "Int constant too large for type", its
  `int` being 32 bits.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]"), whose `int` and `word` have
  63 bits.
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM.
* **Basis Library: MLKit's own.** Every program is built from an `.mlb`
  file that lists `$(SML_LIB)/basis/basis.mlb` and the program, with
  `mlkit -o prog prog.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`, which should print `1073741824`:

```sml
val big = 1073741824
val () = print (Int.toString big ^ "\n")
```

```
$ mlkit -o bug bug.mlb
bug.sml, line 2, column 16:
  val () = print (Int.toString big ^ "\n")
                  ^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: int32 -> string
   but I found operator type:      int -> string
```

`run.sh` builds all the programs (`MLKIT=/path/to/mlkit sh run.sh`):

```
MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00) [X64 Backend]
bug            compiler: Type clash,
bug-crash      compiler: Impossible: resolve_tv.hmm; maybe insert cases for string, etc; ts = {intinf,int64,int}
bug-word       compiler: Type clash,
ok-below-2-30  1073741823
ok-in-context  2147483648
```

`ok-in-context.sml` writes `Int.toString 2147483648` in one declaration,
where the context gives the literal its type: that works.

## The cause

When a declaration leaves an overloaded type variable unresolved,
`resolve_tv` in `src/Common/ElabDec.sml` chooses its type from the set
`ts` of type names still possible:

```sml
  fun resolve_tv (tv : TyVar) : Type =
    let val ts = StatObject.TyVar.resolve_overloaded tv
      open TyName
    in
      if Set.member tyName_INT32 ts then
          if Set.member tyName_INT31 ts then
            Type.IntDefault()
          else Type.Int32
      else
        if Set.member tyName_WORD32 ts then
          if Set.member tyName_WORD31 ts then
            Type.WordDefault()
          else Type.Word32
        else Crash.impossible ("resolve_tv.hmm; maybe insert cases for string, etc; ts = {"
                               ^ String.concatWith "," (map pr_TyName (Set.list ts)) ^ "}")
    end
```

It takes the default only while `int31` (`word31`) is still possible. A
literal of 2^30 or more does not fit 31 bits, so `int31` has been taken
out of `ts`:
* `1073741824` leaves `int32` in, and gets `Int32`;
* `2147483648` leaves only `{intinf, int64, int}`, where `int` is the
  63-bit default, and falls through to `Crash.impossible`.

The test was written when the default `int` was `int31`.

## The fix

Ask whether the default is still possible, whatever its width.
`TyName.tyName_IntDefault ()` and `tyName_WordDefault ()`
(`src/Common/TyName.sml`) are the type names of `Type.IntDefault ()` and
`Type.WordDefault ()`:

```sml
  fun resolve_tv (tv : TyVar) : Type =
    let val ts = StatObject.TyVar.resolve_overloaded tv
      open TyName
    in
      if Set.member (tyName_IntDefault ()) ts then Type.IntDefault ()
      else if Set.member (tyName_WordDefault ()) ts then Type.WordDefault ()
      else if Set.member tyName_INT32 ts then Type.Int32
      else if Set.member tyName_WORD32 ts then Type.Word32
      else Crash.impossible ("resolve_tv.hmm; maybe insert cases for string, etc; ts = {"
                             ^ String.concatWith "," (map pr_TyName (Set.list ts)) ^ "}")
    end
```

A literal that no fixed-width type holds, 2^63 on MLKit, would then still
reach `Crash.impossible`, where it should be an error that the constant is
too large; that case is not handled here. The patch has not been built or
tested: MLKit was not built from source.

## How Rune met it

It was not met in Rune's code. It turned up while the Basis Library suite
of Rune (`tests/basis`) was being run on MLKit, in a program written to
look into another failure: `val big = 2147483648` followed by
`Int.toString big`. Rune's compiler, its tools and the suite's checks
compile with MLKit as they are.

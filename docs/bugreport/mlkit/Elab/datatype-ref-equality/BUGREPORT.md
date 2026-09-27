# MLKit 4.7.23: a datatype that holds `t ref` does not admit equality when `t` does not

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The elaborator rejects a program that the Definition accepts; MLton, SML/NJ and Poly/ML compile it.

## Status: not reported upstream

This has not been sent to MLKit. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Common/EfficientElab/StatObject.sml` as the
tag `v4.7.23`, so the bug is still there.

A search of MLKit's issues and pull requests, their titles, texts and
comments, up to #229 of 2026-09-25, found no report of it (2026-09-27).

## Summary

* **The trigger:** a datatype with a constructor whose argument is `t ref`
  or `t array`, where `t` does not admit equality: a function type, or an
  abstract type such as a functor's parameter.
* **What goes wrong:** MLKit decides that the datatype does not admit
  equality and rejects `=` on its values with a type clash. MLton, SML/NJ
  and Poly/ML accept the program.
* **Required behaviour:** in the
  [Definition of Standard ML](https://smlfamily.github.io/sml97-defn.pdf)
  (1997), `τ ref` admits equality whatever `τ` is (section 4.4, *Types and
  Type Functions*), and a datatype declaration makes its types admit
  equality as far as their constructors allow (the side condition "TE
  maximises equality" of rule 19, section 4.9). So a constructor whose
  argument is `t ref` does not stop its datatype from admitting equality.
  The Basis Library gives `array` the same property.
* **Where it works:** `=` on a bare `(int -> int) ref` and on
  `datatype t = T of int ref` compiles. The argument has to be a `ref` of a
  type without equality, inside a datatype.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM.
* **Basis Library: MLKit's own.** Every program is built from an `.mlb`
  file that lists `$(SML_LIB)/basis/basis.mlb` and the program, with
  `mlkit -o prog prog.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`, which should print `equal when the same`:

```sml
datatype t = T of (int -> int) ref
val a = T (ref (fn x => x))
val () = print (if a = a andalso a <> T (ref (fn x => x)) then "equal when the same\n" else "wrong\n")
```

```
$ mlkit -o bug bug.mlb
bug.sml, line 3, column 33:
  val () = print (if a = a andalso a <> T (ref (fn x => x)) then "equal when the same\n" else "wrong\n")
                                   ^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   operand suggests operator type: t * t -> bool
   but I found operator type:      ''a * ''a -> bool

bug.sml, line 3, column 19:
  ...
Type clash,
   operand suggests operator type: t * t -> bool
   but I found operator type:      ''a * ''a -> bool
Stopping compilation of MLB-file due to error (code 1).
```

MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2 compile it, and it prints
`equal when the same`.

`run.sh` builds all the programs (`MLKIT=/path/to/mlkit sh run.sh`):

| Program | What it does | MLKit 4.7.23 |
|---|---|---|
| `bug.sml` | the program above | type clash |
| `bug-array.sml` | the same with `(int -> int) array` | type clash |
| `bug-functor.sml` | `datatype t = T of X.s ref` in a functor whose parameter's `s` is abstract | type clash |
| `ok-bare-ref.sml` | `=` on a `(int -> int) ref`, no datatype | `equal when the same` |
| `ok-int-ref.sml` | `datatype t = T of int ref` | `equal when the same` |

## The cause

Rule 19 is implemented by maximising the equality of the datatypes after
elaboration (`maximise_equality_in_VE_and_TE`,
`src/Common/EfficientElab/Environments.sml`). A datatype stays without
equality when the type of one of its constructors "violates equality".
That is decided by `violates_equality0` in
`src/Common/EfficientElab/StatObject.sml`:

```sml
        fun violates_equality0 T tau =
          case #TypeDesc (findType tau)
            of TYVAR _ => false
             | RECTYPE (r,_) =>
              (Type.RecType.fold (fn (tau, res) => res orelse violates_equality0 T tau)
               false r)
             | CONSTYPE (taus, tyname, _) =>
              (if TyName.equality tyname orelse TyName.Set.member tyname T then
                 foldl (fn (tau, res) => res orelse violates_equality0 T tau)
                 false taus
               else true)
             | ARROW _ => true
```

For `(int -> int) ref` the type name `ref` admits equality, so the function
goes on to its argument `int -> int`, which is an `ARROW`, and answers
`true`. The same file already knows better: `make_equality0`, used when
unifying, takes `ref` and `array` out first:

```sml
             | CONSTYPE (ty_list, tyname, _) =>
                if TyName.eq (tyname, TyName.tyName_REF) orelse
                   TyName.eq (tyname, TyName.tyName_ARRAY) then ()
                (* "ref" and "array" are special cases; take them out straight away,
                 * otherwise we'll damage any tyvars within the args. *)
```

## The fix

Give `violates_equality0` the same special case:

```sml
             | CONSTYPE (taus, tyname, _) =>
              if TyName.eq (tyname, TyName.tyName_REF) orelse
                 TyName.eq (tyname, TyName.tyName_ARRAY) then false
              else if TyName.equality tyname orelse TyName.Set.member tyname T then
                foldl (fn (tau, res) => res orelse violates_equality0 T tau)
                false taus
              else true
```

This has not been built or tested here: MLKit was not built from source.

## How Rune met it

Rune's Basis Library, compiled by MLKit (the configuration `xc1:mlkit` of
Rune's test suite, `tests/basis`), makes `TextIO.instream` a datatype that
holds a reference to a stream of a functor's parameter:

```sml
  datatype instream = InStream of SIO.instream ref
```

`SIO.instream` has no equality, so MLKit gives `instream` none. The check
`TextIO.instream/equal-when-the-same-stream` (section `instream-equality`
of `tests/basis/textio.sml`), which pins that equality, a deviation that
Rune documents, then does not compile. It compiles with MLton, SML/NJ and
Poly/ML. It is the line `xc1:mlkit@* | @section/textio/instream-equality`
of `tests/basis/deviations.txt`. Nothing in Rune works around it, since
only that check needs the equality.

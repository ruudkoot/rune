# MLKit 4.7.23: "Impossible: Mul: diffef failed" on an exception raised by a function passed to itself

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The compiler stops with `Impossible: Mul: diffef failed` on a valid program.

## Status: not reported upstream

This has not been sent to MLKit. No release has a fix: 4.7.21, 4.7.22 and
4.7.23 all crash on these programs. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Compiler/Regions` as the tag `v4.7.23`,
`Mul.sml` included. It was not built here, so the bug has not been seen
on `master` itself.

## Summary

* **The trigger:** a recursive function passes itself to a higher-order
  function, such as `List.app`. It also raises an exception with an
  argument, and that exception is declared in the same compilation unit.
* **What goes wrong:** the compiler stops in its multiplicity inference
  (`src/Compiler/Regions/Mul.sml`). It prints "oh-oh ... cannot subtract
  effects" and then `Impossible: Mul: diffef failed`. There is no
  executable. The program is well typed, and every other SML compiler
  accepts it.
* **What avoids it** (any one is enough):
  * the exception carries no argument;
  * its value is built once, outside the function;
  * it is declared in another compilation unit and rebound here;
  * the traversal is a function of its own, mutually recursive with the
    first (`fun f ... and app ...`);
  * the compiler runs with `-no_opt` or `--no_contract`.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]"). The binary releases of
  4.7.21 and 4.7.22 behave the same.
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM, gcc
  13.3.0.
* **Basis Library: MLKit's own.** Every program is built from an `.mlb`
  file that lists `$(SML_LIB)/basis/basis.mlb` and the program, with
  `mlkit -o prog prog.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`, which should print `1`:

```sml
exception E of int
fun f (n : int) : unit = if n = 0 then raise E 1 else List.app f []
val () = f 0 handle E k => print (Int.toString k ^ "\n")
```

```
$ mlkit -o bug bug.mlb
oh-oh ... cannot subtract effects
mulef1:

{e8:1,put(r1):1,put(r2):1,put(r3):1,put(r4):1,put(r5):1,put(r6):1,put(r7):1}
mulef2:

{put(r1):1}Mul: diffef failed
Impossible: Mul: diffef failed

instantiate.doSubst or diffef failed

eps0 is

e24eps0' is

e80
app[at r19]
WHOLE EXPRESSION:

let exception E : (int->(exn,r1),r1) (* exn value or name at r1 *);
    fun f at r1 n =
        case n = 0 of
          true => raise E at r1 1
        | _ =>
          let region r15:1;
              fun app at r15 [r19:1] var18 =
                  case var18 of
                    nil => ()
                  | :: v348 => let val v349 = #0 v348; val v350 = #1 v348; val _ = f v349 in app[at r19] v350 end;
              region r27:1
          in  app[at r27] nil
          end;
    ...
[[ERR in sub process:
  CRASH]]
Stopping compilation of MLB-file due to error (code 1).
```

`List.app` has been specialised to the local `app`. The same crash
follows when the program defines its own `app` (`bug-own-app.sml`), so the
cause is not the Basis Library.

## What triggers it and what does not

`run.sh` builds every program three ways: as MLKit builds it by default,
with `-no_opt`, and with `--no_contract`. `MLKIT=/path/to/mlkit sh run.sh`
runs it; it copies each program into a directory of its own, since MLKit
writes what it compiles next to the sources.

| Program | What it does | Default | `-no_opt` | `--no_contract` |
|---|---|---|---|---|
| `bug.sml` | the program above | crash | `1` | `1` |
| `bug-tree.sml` | the shape it was found in: a tree walked with `List.app`, `exception E of string` | crash | `leaf` | `leaf` |
| `bug-own-app.sml` | `bug.sml` with an `app` of its own in place of `List.app` | crash | `1` | `1` |
| `bug-helper.sml` | the exception value built by a helper, `fun fail k = E k` | crash | `1` | `1` |
| `ok-no-argument.sml` | `exception E`, without an argument | `1` | `1` | `1` |
| `ok-built-once.sml` | `val e = E 1` outside `f`, then `raise e` | `1` | `1` | `1` |
| `ok-mutual.sml` | `fun f ... and app ...`: the traversal mutually recursive with `f` | `1` | `1` | `1` |
| `ok-other-unit-a.sml` + `-b.sml` | `exception E of int` declared in a first unit, rebound in the second (`exception E = X.E`) and raised there as in `bug.sml` | `1` | `1` | `1` |

So it takes three things together:
* an exception with an argument, declared in the compilation unit;
* its value built inside a recursive function (inlining a helper that
  builds it does not help);
* that function passed to itself through a higher-order function which the
  optimiser specialises into a local recursive function.

Neither flag avoids the bug in a larger program. `-no_opt` and
`--no_contract` build these programs, but on Rune's compiler they make
MLKit fail the same way in another file (`src/frontend/lexer.sml`). Among
the flags `mlkit --help` lists, only these two change the outcome of
`bug.sml`. `--no_specialize_recursive_functions` avoids it with an `app`
of the program's own, but not with the Basis Library's `List.app`.

**A pitfall when trying flags:** MLKit keeps what it compiled in `MLB/`
next to each source, and reuses it under different flags. So a build
with `-no_opt` followed by one without it succeeds, with the code of the
first build. MLKit documents this: its option `--mlb-subdir` exists for
it. Remove the `MLB` directories between tries.

## The cause

`instantiate` in `src/Compiler/Regions/Mul.sml` computes the difference
of two multiplicity effects with `diffef`. Its precondition is that both
have the same domain:

```sml
  (* diffef(psi1,psi2) computes the difference between psi1 and psi2.
     Precondition: Dom(psi1) = Dom(psi2)
  *)
  ...
  fun diffef_aux ([]:mulef,[]:mulef) = []
    | diffef_aux ((ae1, mul1)::psi1', (ae2, mul2)::psi2')= ...
    | diffef_aux _ = raise DiffEf
```

It is called when `app[at r19]`, the specialised traversal, is
instantiated at its recursive call:

```sml
             val _ = doSubst(eps0, diffef(new_actual_psi,actual_psi), dep)
```

There the two effects differ in their domain:
* **new (`mulef1`):** the top-level effect variable `e8` and a put into
  every top-level region `r1` to `r7`;
* **actual (`mulef2`):** only `put(r1)`, the region of the exception
  value.

The exception constructor has type `(int->(exn,r1),r1)`. Building
`E at r1 1` inside `f` seems to put the effect of the constructor, which
is top level, into the latent effect of `f`, and through `f` into that of
the specialised `app`. The actual effect recorded for `app` is not updated
to match. That is a reading of the dump above, not a diagnosis.

## The fix

None is proposed here. The fault is in how multiplicity inference records
the effect of an exception constructor declared in the same unit, and a
fix needs someone who knows `Mul.sml` and `RegionStatEnv`. `bug.sml` is
the smallest program that shows it, and could serve as a regression test.

## How Rune met it

Rune, a self-hosting Standard ML compiler, can be built with MLKit.
MLKit 4.7.23 stopped at `src/elab/unify.sml`: `occursAdjust` walks a type
and calls itself through `List.app` on the parts of a type, and it raises
`Unify "circular type"` with `exception Unify of string` from the same
file. That is the shape of `bug-tree.sml`. It was the only place in
Rune's compiler, its documentation generator (`runedoc`) and its native
code generator (`runeopt`) that MLKit rejected.
* **The workaround:** `src/elab/unifyexn.sml`, a compilation unit of its
  own, declares the exception. `unify.sml` binds it again with
  `exception Unify = UnifyExn.Unify`, as `ok-other-unit` does. Nothing
  changes for the code that handles `Unify.Unify`.
* **What it costs:** nothing that can be measured. Rune compiled by itself
  executes the same number of instructions (2,944,963) and allocates the
  same (3,428,576 bytes) to compile `examples/hello.sml`, with or without
  the change.
* **When it can go:** once `make hosts` installs a release of MLKit that
  compiles `bug.sml`.

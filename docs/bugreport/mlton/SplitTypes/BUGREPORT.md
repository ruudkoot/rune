# MLton 20241230: `SplitTypes` splits the element type of `Array_copyArray`

## Status: already fixed upstream

MLton has already fixed this bug, but no release has the fix yet.
* **The fix:** MLton pull request
  [#632](https://github.com/MLton/mlton/pull/632), "Fix bug in `SplitTypes`
  SSA optimization", commit `323fed1e89`, merged into `master` on
  2025-12-17.
* **No release:** as of 2026-09-24 the newest release is still 20241230.

**What is worth sending MLton is a regression test.** The fix came without
one, and `regression/split-types-copy-array.sml` with its `.ok` in this
directory is ready to go into MLton's `regression/` directory. It is the
program of *The program* below.

## Summary

* **The trigger:** an array whose elements are lists of pairs, filled with
  pairs taken from another list, then made into a vector by `Array.vector`.
* **With `-type-check true`:** the compiler fails in its SSA type checker.
  `Array_copyArray` is applied to a `(list_0) array` and a
  `(list_1) array`.
* **Without the check** (the default): the program compiles, and at run
  time it stops with `MLton bug: control shouldn't reach here`.
* **The cause:** the `SplitTypes` pass. With `-disable-pass 'splitTypes.*'`
  the program is correct and type-checks.

## Environment

* **MLton:** 20241230, the official binary release
  `mlton-20241230-1.amd64-linux.ubuntu-24.04_glibc2.39`.
* **System:** Linux x86-64, Ubuntu 24.04 under WSL2 (kernel
  6.18.33.2-microsoft-standard-WSL2), gcc 13.3.0.
* **Basis Library: MLton's own.** Every program here is standalone and
  compiled as `mlton prog.sml`, with no `.mlb` file. Nothing of Rune is
  involved: not its Basis Library, not its compiler, not its runtime.

## The program

`bug.sml`, which should print `2`:

```sml
val a = Array.array (256, [] : (string * int) list)
fun add (w as (s, _)) =
  let val i = Char.ord (String.sub (s, 0)) in Array.update (a, i, Array.sub (a, i) @ [w]) end
val () = List.app add [("a", 1), ("ab", 2), ("c", 3)]
val table = Array.vector a
val () = print (Int.toString (length (Vector.sub (table, Char.ord #"a"))) ^ "\n")
```

```
$ mlton bug.sml && ./bug
MLton bug: control shouldn't reach here
Please send a bug report to MLton@mlton.org.

$ mlton -type-check true bug.sml
MLton 20241230 raised: Fail: TypeError (SSA): Ssa.TypeCheck.primApp (Array_copyArray(list_0) ((list_0) array, word64, (list_1) array, word64, word64)) in val _: unit = prim Array_copyArray[list_0] (x_1, global_1, x_0, global_1, global_0) in L_0 in main_0

$ mlton -disable-pass 'splitTypes.*' bug.sml && ./bug
2
```

With `-type-check true -verbose 2`, the SSA checks out after
`constantPropagation` and fails after `splitTypes1`:

```
splitTypes1 starting
   splitTypes1:typeCheck starting
      splitTypes1:typeCheck raised: Fail: TypeError (SSA): Ssa.TypeCheck.primApp (Array_copyArray(list_0) ((list_0) array, word64, (list_1) array, word64, word64)) ...
```

With only `splitTypes1` disabled, `splitTypes2` fails the same way.

## What triggers it and what does not

`run.sh` builds every program three ways: as MLton builds it by default,
with `-type-check true`, and with `-disable-pass 'splitTypes.*'`.
`MLTON=/path/to/mlton sh run.sh` runs it.

| Program | What it does | Default | `-type-check true` | No `SplitTypes` |
|---|---|---|---|---|
| `bug.sml` | the program above | stops: "control shouldn't reach here" | SSA type error | `2`, correct |
| `bug-cons.sml` | each element built with `::` instead of `@` | stops | SSA type error | `2`, correct |
| `bug-original.sml` | the shape it was found in: inside a function, pairs of a string and a datatype | stops | SSA type error | `found`, correct |
| `ok-tabulate.sml` | `bug.sml` with `Vector.tabulate` in place of `Array.vector` | `2`, correct | `2` | `2` |
| `ok-literal.sml` | an array of lists of pairs whose element is written as a literal, not taken from another list | `7`, correct | `7` | `7` |
| `ok-int-list.sml` | an array of `int list`, appended to | `7`, correct | `7` | `7` |

So it takes three things together:
* a copy of an array, by `Array.vector` or anything else that uses
  `Array_copyArray`;
* elements of a datatype, here `list`;
* values of that datatype that flow into the array from elsewhere, here
  pairs taken out of another list.

`SplitTypes` then gives the source and the destination of the copy two
different instances of `list`.

## The fix

`Array_copyArray` and `Array_copyVector` are a `memcpy` from one sequence
to another, and need both to have the same element type. `SplitTypes`
never unified their element types, so it could split them apart. The fix
merged as #632 (`mlton/ssa/split-types.fun`) makes it unify them. It
coerces the `TypeInfo` of the source, argument 2, into that of the
destination, argument 0:

```sml
fun copyPrim args =
   let
      val _ = TypeInfo.coerce (Vector.sub (args, 2), Vector.sub (args, 0))
   in
      TypeInfo.fromType Type.unit
   end
...
| Prim.Array_copyArray => copyPrim args
| Prim.Array_copyVector => copyPrim args
```

That matches what the type error shows:
`Array_copyArray[list_0] (x_1, global_1, x_0, global_1, global_0)` copies
from `x_0 : (list_1) array` into `x_1 : (list_0) array`.

The fix has not been checked here against a build of MLton's `master`:
this machine has only the 20241230 release. The regression test is the
check.

## How Rune met it

Rune, a self-hosting Standard ML compiler, is also built with MLton. Its
lexer puts the reserved words in a table by their first character, and it
made that table with the code of `bug-original.sml`. MLton 20241230 then
failed to compile the compiler, although Rune's build does not pass
`-type-check`:

```
MLton 20241230 raised: Fail: TypeError (SSA): Ssa.TypeCheck.primApp (Array_copyArray(void_0) ((void_0) array, word64, (list_0) array, word64, word64)) in val _: unit = prim Array_copyArray[void_0] (x_1, global_1, x_0, global_1, global_0) in L_0 in main_0
```

The small programs here compile without the check, and fail only when they
run.
* **The workaround** (`src/frontend/lexer.sml`): `Vector.tabulate` in place
  of `Array.vector`.
* **What it costs:** 3,819 bytecode instructions more for each compile
  when Rune compiles with itself, 0.06% of compiling a program that prints
  hello, and nothing measurable in the MLton build.
* **When it can go:** once Rune's hosts (`make hosts`) move to a release
  of MLton with #632.

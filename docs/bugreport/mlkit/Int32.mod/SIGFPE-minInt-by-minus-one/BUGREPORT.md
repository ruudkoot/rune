# MLKit 4.7.23: `Int32.mod (minInt, ~1)` and `Int64.mod (minInt, ~1)` kill the program with SIGFPE

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The program is killed by SIGFPE.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same `src/Runtime/Math.c` as 4.7.23 (the files are identical), so
the bug is not fixed there either.

## Summary

* **The trigger:** `Int32.mod (valOf Int32.minInt, ~1)`,
  `Int64.mod (valOf Int64.minInt, ~1)`, or the overloaded `mod` at
  `Int32.int` or `Int64.int` with these operands.
* **What goes wrong:** the process is killed by the signal `SIGFPE`
  ("Floating point exception", exit status 136); no exception is raised
  that the program could handle.
* **Required behaviour:** the
  [Basis `INTEGER` specification](https://smlfamily.github.io/Basis/integer.html)
  says `i mod j` "returns the remainder of the division of i by j. It
  raises Div when j = 0". The remainder of any `i` divided by `~1` is 0,
  and `Div` is the only exception specified (unlike `div` and `quot`, which
  raise `Overflow` "when the result is not representable"). Whatever
  reading one takes of the specification, it does not allow the program to
  be killed. MLKit's own `Int.mod`, `Int32.rem` and `Int64.rem` give 0 for
  these operands, and `Int32.div` and `Int64.div` raise `Overflow`.

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
(* Int32.mod (minInt, ~1) and Int64.mod (minInt, ~1) should be 0 ("It raises
   Div when j = 0"; nothing else), but the program is killed by SIGFPE.
   Run as `./bug CASE`, one case per process, since the crash ends it. *)
fun say s = (print s; TextIO.flushOut TextIO.stdOut)
fun try name f = (say (name ^ " = "); say ((f () handle e => "raises " ^ exnName e) ^ "\n"))
val min32 = valOf Int32.minInt
val min64 = valOf Int64.minInt
val () =
  case CommandLine.arguments () of
    ["contrast"] =>
      (try "Int.mod (minInt, ~1)   " (fn () => Int.toString (Int.mod (valOf Int.minInt, ~1)));
       try "Int32.rem (minInt, ~1) " (fn () => Int32.toString (Int32.rem (min32, ~1)));
       try "Int64.rem (minInt, ~1) " (fn () => Int64.toString (Int64.rem (min64, ~1)));
       try "Int32.div (minInt, ~1) " (fn () => Int32.toString (Int32.div (min32, ~1)));
       try "Int64.div (minInt, ~1) " (fn () => Int64.toString (Int64.div (min64, ~1))))
  | ["Int32.mod"] => try "Int32.mod (minInt, ~1) " (fn () => Int32.toString (Int32.mod (min32, ~1)))
  | ["Int64.mod"] => try "Int64.mod (minInt, ~1) " (fn () => Int64.toString (Int64.mod (min64, ~1)))
  | ["int32-mod"] =>  (* the overloaded operator at int32 *)
      try "(minInt : Int32.int) mod ~1" (fn () => Int32.toString (min32 mod ~1))
  | _ => say "usage: bug contrast | Int32.mod | Int64.mod | int32-mod\n"
```

```
$ mlkit -o bug bug.mlb
[reading source file:	bug.sml]
[wrote X64 code file:	MLB/RI_GC/bug.sml.s]
[wrote X64 code file:	MLB/RI_GC/base-link_objects.s]
[wrote executable file:	bug]
$ ./bug contrast; echo "exit status $?"
Int.mod (minInt, ~1)    = 0
Int32.rem (minInt, ~1)  = 0
Int64.rem (minInt, ~1)  = 0
Int32.div (minInt, ~1)  = raises Overflow
Int64.div (minInt, ~1)  = raises Overflow
exit status 0
$ ./bug Int32.mod; echo "exit status $?"
Int32.mod (minInt, ~1)  = Floating point exception
exit status 136
$ ./bug Int64.mod; echo "exit status $?"
Int64.mod (minInt, ~1)  = Floating point exception
exit status 136
$ ./bug int32-mod; echo "exit status $?"
(minInt : Int32.int) mod ~1 = Floating point exception
exit status 136
```

"Floating point exception" is bash's report of the signal `SIGFPE`
(exit status 128 + 8); the program prints nothing after the `=`.

## The cause

`mod` at `int32` and `int64` is compiled to a call of the runtime's
`__mod_int32ub` or `__mod_int64ub` (`src/Compiler/Lambda/CompileDec.sml`,
`binary_ccall_exn int32Type "__mod_int32"`). In `src/Runtime/Math.c`:

```c
ssize_t
__mod_int32ub(Context ctx, ssize_t x0, ssize_t y0, uintptr_t exn)
{
  int x = (int)x0;
  int y = (int)y0;
  if ( y == 0 )
    {
      raise_exn(ctx,exn);
      return 0;                               // never reached
    }
  if ( (x > 0 && y > 0) || (x < 0 && y < 0) || (x % y == 0) )
    {
      return x % y;
    }
  return (x % y) + y;
}
```

and `__mod_int64ub` the same with `long int`. For `x = INT_MIN` and
`y = -1`, `x % y` is undefined behaviour in C, and the x86-64 `idiv`
instruction that computes it traps (the quotient, 2^31 or 2^63, does not
fit), which the kernel delivers as `SIGFPE`. The functions next to them
already take the case out: `__div_int32ub` and `__div_int64ub` test
`y == -1 && x == minimum` and raise `Overflow`, and `Int32.rem` and
`Int64.rem` in `basis/Int32.sml` and `basis/Int64.sml` return 0 for
`y = ~1` before they reach the primitive ("the quotient overflows and the
machine division instruction traps, so the case is taken out"). `Int.mod`
(63 bits) goes through `__mod_int63`, which computes on tagged values and
does not trap.

## The fix

Return 0 for `y = -1` before dividing:

```diff
--- a/src/Runtime/Math.c
+++ b/src/Runtime/Math.c
@@ -222,6 +222,10 @@
       raise_exn(ctx,exn);
       return 0;                               // never reached
     }
+  if ( y == -1 )     /* x % -1 is 0; for the smallest x, the division traps */
+    {
+      return 0;
+    }
   if ( (x > 0 && y > 0) || (x < 0 && y < 0) || (x % y == 0) )
     {
       return x % y;
@@ -239,6 +243,10 @@
       raise_exn(ctx,exn);
       return 0;                               // never reached
     }
+  if ( y == -1 )     /* x % -1 is 0; for the smallest x, the division traps */
+    {
+      return 0;
+    }
   if ( (x > 0 && y > 0) || (x < 0 && y < 0) || (x % y == 0) )
     {
       return x % y;
```

`__mod_int32b` and `__mod_int64b` (the boxed variants) call these
functions and need no change of their own.

**Tested:** `Math.c` of the 4.7.23 sources with this change was compiled
with the flags of the runtime's `gc` and `plain` variants (from
`src/Runtime/Makefile`) and put in place of `Math.o` in copies of
`runtimeSystemGC.a` and `runtimeSystem.a` of the binary release's library;
with `SML_LIB` pointing at that copy, all four runs of `bug` exit with
status 0 and print `0` for `Int32.mod`, `Int64.mod` and the overloaded
`mod`, and the Rune test programs `intn_int32` and `intn_int64` (below)
run to their end and pass all their checks. The Arm64 backend was not
looked at. Not tried against a build of `master`.
The copy of the library had the fixes of the other reports of this
investigation applied as well (`Word.scan/0w-read-as-hex-prefix`,
`Word.fromLargeInt/Overflow-on-negative`, `IntInf.scan/*`,
`PackWord32Big.subVecX/no-sign-extension`, the `LargeIntVector` fix and
the runtime fix of `Int32.mod/SIGFPE-minInt-by-minus-one`); the Rune
programs were those the matrix compiled, `intn_word16` without its
`constants` section (`Int8.int/not-overloaded`).

## Relation to Rune

Rune's Basis Library suite checks `mod/minInt-by-minus-one` in
`tests/basis/fn/integer_fn.sml` (line 342, Rune at `3d83f11`), for every
`INTEGER` structure with bounds. For `Int32` and `Int64`
(`tests/basis/intn_int32.sml`, `tests/basis/intn_int64.sml`) the test
program is killed at that check on MLKit, after 334 checks have passed,
and the matrix reports `@load/intn_int32 -- did not load` and
`@load/intn_int64 -- did not load`. With the check left out, all the other
checks of both programs pass on MLKit 4.7.23 (2625 and 2622 checks).
SML/NJ raises an exception for the same operands (the `native:smlnj@*`
lines `Int[0-9]*.mod/minInt-by-minus-one` of `tests/basis/deviations.txt`).
The MLKit failures are explained by

```
native:mlkit@* | @load/intn_int[36][24] | HOST-BUG | mod (minInt, ~1) of Int32 and Int64 (mod/minInt-by-minus-one) kills the program with SIGFPE: the runtime's __mod_int32ub and __mod_int64ub compute x % y without taking out y = -1
```

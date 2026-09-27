# MLKit 4.7.23: `Posix.ProcEnv.time ()` is always 1000000000 seconds after the Epoch

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The library adds up the wrong fields of what the runtime returns, so the time is always 10^9 seconds.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Posix.sml` and `src/Runtime/Posix.c` as
the tag `v4.7.23`, byte for byte, so the code below is unchanged there;
`master` was not built.

## Summary

* **The trigger:** any call of `Posix.ProcEnv.time ()` between
  2001-09-09 and 2033-05-18 (while the seconds since the Epoch are
  between 10^9 and 2 * 10^9).
* **What goes wrong:** the result is 1000000000 seconds
  (2001-09-09T01:46:40Z), not the current time. The runtime splits the
  seconds into a quotient and a remainder of 10^9, and the ML code adds
  the status field to the quotient instead of the remainder.
* **Required behaviour:** the
  [`POSIX_PROC_ENV` specification](https://smlfamily.github.io/Basis/posix-proc-env.html)
  says of `time`: "The elapsed wall time since the Epoch."

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44), glibc 2.39, running as root.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* Posix.ProcEnv.time is the time since the Epoch, as Time.now. *)
val () = print ("Posix.ProcEnv.time () = " ^ LargeInt.toString (Time.toSeconds (Posix.ProcEnv.time ())) ^ " s\n")
val () = print ("Time.now ()           = " ^ LargeInt.toString (Time.toSeconds (Time.now ())) ^ " s\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
Posix.ProcEnv.time () = 1000000000 s
Time.now ()           = 1790468559 s
```

The two should agree.

## The cause

`sml_gettime` (`src/Runtime/Posix.c`, lines 1199-1213) returns the seconds
as `(t mod 10^9, t div 10^9, status)`:

```c
  first(pair) = convertIntToML(t % 1000000000);
  second(pair) = convertIntToML(t / 1000000000);
  third(pair) = convertIntToML(0);
```

and `time` (`basis/Posix.sml`, lines 537-544) adds the third field, the
status, to 10^9 times the second:

```sml
          val (l,s,r) = prim("sml_gettime", ()) : (int * int * int)
        in
          if r = ~1 then raiseSys "Posix.ProcEnv.time" NONE ""
          else Time.+(Time.fromSeconds(LargeInt.*(LargeInt.fromInt 1000000000, (LargeInt.fromInt s))),
                      Time.fromSeconds(LargeInt.fromInt r))
```

## The fix

```diff
--- a/basis/Posix.sml
+++ b/basis/Posix.sml
@@ -540,5 +540,5 @@
           if r = ~1 then raiseSys "Posix.ProcEnv.time" NONE ""
           else Time.+(Time.fromSeconds(LargeInt.*(LargeInt.fromInt 1000000000, (LargeInt.fromInt s))),
-                      Time.fromSeconds(LargeInt.fromInt r))
+                      Time.fromSeconds(LargeInt.fromInt l))
         end
```

Tested on a copy of the installed `lib/mlkit` with this change (together
with the changes proposed in the other reports of this series): `bug.sml`
then prints the same number twice, and Rune's
`tests/basis/posix_procenv.sml` passes (64 checks), built with its
constant `0w1999999999` computed at run time, to get past the bug of the
report `X64/push-immediate`, and with the checks of `getlogin`, `ctermid`
and `ttyname` left out, which meet the bug of the report `X64/is-null`.
`master` was not built.

## Relation to Rune

Rune's `tests/basis/posix_procenv.sml` compares `time ()` with
`Time.now ()` and with `date +%s` (`Posix.ProcEnv.time/now`,
`Posix.ProcEnv.time/date`). On MLKit the test does not build (report
`X64/push-immediate`), so the run reports only `@load/posix_procenv`;
built with that constant worked around, both checks fail. No line of
`tests/basis/deviations.txt` is needed while the test does not build.

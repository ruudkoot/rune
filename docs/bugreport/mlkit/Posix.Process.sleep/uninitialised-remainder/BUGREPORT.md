# MLKit 4.7.23: `Posix.Process.sleep` raises `Time` after it has slept

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The runtime returns an uninitialised remainder, so `sleep` raises `Time` after it has slept.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/IO.c` and `basis/Posix.sml` as the
tag `v4.7.23`, byte for byte, so the code below is unchanged there;
`master` was not built.

## Summary

* **The trigger:** any call of `Posix.Process.sleep`, `Time.zeroTime`
  included.
* **What goes wrong:** the process sleeps for the time asked, and then
  `sleep` raises `Time` instead of returning. The runtime returns the
  time that is left from the `rem` argument of `nanosleep`, which
  `nanosleep` fills in only when a signal interrupts it; otherwise it is
  whatever the stack held, here 140736775381568 seconds, too large for a
  `Time.time`. It also returns the nanoseconds of `rem` where the ML code
  expects microseconds.
* **Required behaviour:** the
  [`POSIX_PROCESS` specification](https://smlfamily.github.io/Basis/posix-process.html):
  "`sleep t` causes the current process to be suspended from execution
  until either t seconds have elapsed, or until the receipt of a signal
  that is either caught or that terminates the process." Its type,
  `Time.time -> Time.time`, is that of POSIX `sleep`, which returns the
  time left, zero when the whole time has passed.

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
(* Posix.Process.sleep t sleeps t and returns the time that is left: none,
   when no signal came. *)
fun try t =
  let val start = Time.now ()
      fun took () = Time.toString (Time.- (Time.now (), start))
  in print ("sleep " ^ Time.toString t ^ ": returned " ^ Time.toString (Posix.Process.sleep t)
            ^ " after " ^ took () ^ " s\n")
     handle e => print ("sleep " ^ Time.toString t ^ ": raised " ^ exnName e ^ " after " ^ took () ^ " s\n")
  end
val () = List.app try [Time.fromSeconds 1, Time.fromMilliseconds 250, Time.zeroTime]
```

```
$ mlkit -o bug bug.mlb && ./bug
sleep 1.000: raised Time after 1.000 s
sleep 0.250: raised Time after 0.250 s
sleep 0.000: raised Time after 0.000 s
```

Expected: `returned 0.000` each time. Calling the runtime's function
directly, `prim ("sml_microsleep", (0, 1000)) : int * int * int` gave
`(0, 140736775381568, 0)` in one run.

## The cause

`sleep` (`basis/Posix.sml`, lines 385-393) takes the time that is left
from the runtime:

```sml
          val (r,s,m) = prim("sml_microsleep", (s : int, m : int)) : (int * int * int)
          val _ = if r = ~1 then raiseSys "Posix.Process.sleep" (SOME (Time.toString t)) "" else ()
        in
          Time.+(Time.fromSeconds (Int.toLarge s),Time.fromMicroseconds (Int.toLarge m))
```

and `sml_microsleep` (`src/Runtime/IO.c`, lines 568-588) returns the
fields of `rem` whether `nanosleep` wrote them or not, and the
nanoseconds as they are:

```c
  struct timespec req, rem;
  ...
  r = nanosleep(&req, &rem);
  first(pair) = convertIntToML(r);
  second(pair) = convertIntToML(rem.tv_sec);
  third(pair) = convertIntToML(rem.tv_nsec);
```

`nanosleep` writes `rem` only when it returns -1 with `EINTR`. And that
case, a sleep that a caught signal ends early, is exactly the one in which
`sleep` should return the time left, but `sleep` raises `OS.SysErr` for
it (`r = ~1`). (`OS.Process.sleep` uses the same function and ignores its
result, so it is not affected.)

## The fix

```diff
--- a/src/Runtime/IO.c
+++ b/src/Runtime/IO.c
@@ -580,10 +580,14 @@
   }
   req.tv_sec = s;
   req.tv_nsec = (u * 1000);
+  rem.tv_sec = 0;
+  rem.tv_nsec = 0;
   r = nanosleep(&req, &rem);
+  if (r == -1 && errno == EINTR)
+    r = 0;                            /* interrupted by a signal: rem is what is left */
   first(pair) = convertIntToML(r);
   second(pair) = convertIntToML(rem.tv_sec);
-  third(pair) = convertIntToML(rem.tv_nsec);
+  third(pair) = convertIntToML(rem.tv_nsec / 1000);
   return pair;
 }
```

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with this change, in a copy of the installed
`lib/mlkit` (together with the changes proposed in the other reports of
this series, which touch other functions): `bug.sml` then prints
`returned 0.000` after 1, 0.25 and 0 s, and Rune's
`tests/basis/posix_process.sml` passes. A sleep interrupted by a signal
was not tried. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks `sleep` for one second and for zero
(`tests/basis/posix_process.sml`, `Posix.Process.sleep/one-second` and
`Posix.Process.sleep/zero`); on MLKit both raise an exception. The line
of `tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.Process.sleep/* | HOST-BUG | sleep raises Time after it has slept: the runtime returns the time left from the rem of nanosleep, which nanosleep writes only when a signal interrupts it (and in nanoseconds where microseconds are expected)
```

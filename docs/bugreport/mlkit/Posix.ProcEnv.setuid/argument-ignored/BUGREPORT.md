# MLKit 4.7.23: `Posix.ProcEnv.setuid` ignores its argument and sets the user ID to whatever is in a register

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** C's `setuid` is called without its argument and takes whatever a register holds.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Posix.sml` as the tag `v4.7.23`, byte for
byte, so the code below is unchanged there; `master` was not built.

A search of MLKit's issues and pull requests, their titles, texts and
comments, up to #229 of 2026-09-25, found no report of it (2026-09-27).

## Summary

* **The trigger:** any call of `Posix.ProcEnv.setuid u`.
* **What goes wrong:** `setuid` calls C's `setuid` without an argument,
  so the user ID it asks for is whatever the first argument register
  holds. In a process with appropriate privileges (root) the call
  succeeds and the process loses them: `setuid (getuid ())` of root sets
  the user ID to a number such as 3887194912, a different one on each
  run. Without privileges the call fails, which goes unseen (see the
  report `Posix.FileSys.unlink/int-result-read-as-long`).
* **Required behaviour:** the
  [`POSIX_PROC_ENV` specification](https://smlfamily.github.io/Basis/posix-proc-env.html):
  "`setuid u` sets the real user ID and effective user ID to u."

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

`bug.sml` (run it as root in a throw-away environment: it drops the
privileges of the process, nothing more):

```sml
(* setuid to the user ID the process already has changes nothing. *)
structure E = Posix.ProcEnv
fun uid () = SysWord.fmt StringCvt.DEC (E.uidToWord (E.getuid ()))
val () = print ("uid before: " ^ uid () ^ "\n")
val () = (E.setuid (E.getuid ()); print "setuid (getuid ()) returned\n")
         handle OS.SysErr (m, _) => print ("SysErr " ^ m ^ "\n")
val () = print ("uid after: " ^ uid () ^ "\n")
```

Two builds and runs:

```
$ mlkit -o bug bug.mlb && ./bug
uid before: 0
setuid (getuid ()) returned
uid after: 3887194912
$ mlkit -o bug bug.mlb && ./bug
uid before: 0
setuid (getuid ()) returned
uid after: 3995706144
```

Expected: `uid after: 0`.

## The cause

`basis/Posix.sml`, lines 554-559:

```sml
    fun setuid g =
        let
          val r = prim("@setuid", ()) : int
        in
          if r = ~1 then raiseSys "Posix.ProcEnv.setuid" NONE "" else ()
        end
```

`g` is not passed; `setgid` just above (line 525) passes its argument,
`prim("@setgid", g : int)`.

## The fix

```diff
--- a/basis/Posix.sml
+++ b/basis/Posix.sml
@@ -553,7 +553,7 @@
 
     fun setuid g =
         let
-          val r = prim("@setuid", ()) : int
+          val r = prim("@setuid", g : int) : int
         in
           if r = ~1 then raiseSys "Posix.ProcEnv.setuid" NONE "" else ()
         end
```

The test of the result for `~1` has the problem of the report
`Posix.FileSys.unlink/int-result-read-as-long`; the fix proposed there
calls a wrapper, `prim("@sml_posix_setuid", g : int)`. Tested in that
form, on a copy of the installed `lib/mlkit` with the changes of that
report (and the others of this series): `bug.sml` then prints `uid after:
0`, and the checks of `setuid` in Rune's `tests/basis/posix_procenv.sml`
pass (the test built with its constant `0w1999999999` computed at run
time, to get past the bug of the report `X64/push-immediate`). `master`
was not built.

## Relation to Rune

Rune's `tests/basis/posix_procenv.sml` checks `setuid` to the process's
own user ID and, when the process is not root, that `setuid` to root
raises `OS.SysErr` (`Posix.ProcEnv.setuid/own`,
`Posix.ProcEnv.setuid/root-raises`). On MLKit the test does not build
(report `X64/push-immediate`), so the run reports only
`@load/posix_procenv`; built with that constant worked around, it fails
both checks, and as root the process has then lost its privileges for
the checks after them (the shell it starts cannot create its files:
"Permission denied"). No line of `tests/basis/deviations.txt` is needed
while the test does not build.

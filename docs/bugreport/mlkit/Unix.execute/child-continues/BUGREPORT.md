# MLKit 4.7.23: when `Unix.execute` cannot run the program, the child process goes on running the caller's program

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** The child of SML/NJ also goes on running the program; MLton and Poly/ML report the failure in the parent.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Unix.sml` as the tag `v4.7.23`, byte for
byte, so the code below is unchanged there; `master` was not built.

## Summary

* **The trigger:** `Unix.execute` or `Unix.executeInEnv` of a program
  that cannot be executed, for instance one that does not exist.
* **What goes wrong:** the child that `executeInEnv` forks calls
  `Posix.Process.exece`, which raises `OS.SysErr` when `execve` fails.
  Nothing in the child handles it, so the exception propagates out of
  `Unix.execute` in the child, and the child runs the rest of the calling
  program (its handlers, what follows), with its standard input and output
  connected to the pipes of the parent. The parent sees a child that does
  whatever its own program does, and whose status is not 126.
* **Required behaviour:** the
  [`UNIX` specification](https://smlfamily.github.io/Basis/unix.html):
  "If the child process fails to execute the command (i.e., the execve
  call fails), then it should exit with a status code of 126."

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
(* Unix.execute of a program that does not exist. The parent reads what
   the child writes to its standard output. *)
val me = Posix.ProcEnv.getpid ()
fun pid () = SysWord.fmt StringCvt.DEC (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
val p : (TextIO.instream, TextIO.outstream) Unix.proc =
  Unix.execute ("./no-such-program", [])
  handle OS.SysErr (m, _) =>
    (print ("SysErr in process " ^ pid ()
            ^ (if Posix.ProcEnv.getpid () = me then " (the parent)" else " (a child, running this program's handler)")
            ^ ": " ^ m ^ "\n");
     TextIO.flushOut TextIO.stdOut;
     Posix.Process.exit 0w7)
val fromChild = TextIO.inputAll (Unix.textInstreamOf p)
val status = Unix.reap p
val () = print ("parent: the child wrote: \"" ^ String.toString fromChild ^ "\"\n")
val () = print ("parent: the child's status: " ^ (case Unix.fromStatus status of
                                                   Unix.W_EXITED => "W_EXITED"
                                                 | Unix.W_EXITSTATUS w => "W_EXITSTATUS " ^ Word8.fmt StringCvt.DEC w
                                                 | _ => "other") ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
parent: the child wrote: "SysErr in process 31878 (a child, running this program's handler): exec failed: No such file or directory\n"
parent: the child's status: W_EXITSTATUS 255
```

Expected: the child writes nothing and exits with 126,
`W_EXITSTATUS 126`. The handler of the program ran in the child, whose
standard output is the pipe the parent reads. (The child exited with 7,
from the handler; `reap` reports 255 because of another bug, report
`Unix.reap/status-lost`.)

## The cause

`startChild` in `executeInEnv` (`basis/Unix.sml`, lines 39-57) ends the
child's branch with the `exece`, without a handler:

```sml
             fun startChild () =
                case PP.fork () of
                   SOME pid => pid (* parent *)
                 | NONE => let
                              ...
                           in
                              ...
                              PP.exece (cmd, base :: argv, env)
                           end
```

and `Posix.Process.exece` raises `OS.SysErr` when `execve` returns
(`basis/Posix.sml`, lines 347-352). In the child the exception goes
through `(startChild ()) handle ex => (closep(); raise ex)` (line 60) and
out of `executeInEnv`.

## The fix

```diff
--- a/basis/Unix.sml
+++ b/basis/Unix.sml
@@ -54,6 +54,7 @@
                               else (PIO.dup2{old = oldout, new = newout};
                                     PIO.close oldout);
                               PP.exece (cmd, base :: argv, env)
+                              handle _ => PP.exit 0w126
                            end
              (* end case *)
              val _ = TextIO.flushOut TextIO.stdOut
```

`Posix.Process.exit` ends the child at once, without the actions of the
parent's `OS.Process.atExit`, which must not run twice.

Tested on a copy of the installed `lib/mlkit` with this change (together
with the changes proposed in the other reports of this series, among them
the fix of `reap`): `bug.sml` then prints that the child wrote `""` and
its status is `W_EXITSTATUS 126`, and Rune's `tests/basis/unix.sml`
passes. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks that `Unix.execute` and
`Unix.executeInEnv` of `./no-such-program` either raise `OS.SysErr` or
give a process whose status is `W_EXITSTATUS 126`
(`tests/basis/unix.sml`, `Unix.execute/no-such-program` and
`Unix.executeInEnv/no-such-program`); both fail on MLKit. The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | Unix.execute*/no-such-program | HOST-BUG | a child that cannot execute the command does not exit with 126: the SysErr of exece propagates out of Unix.execute in the child, which goes on running the caller's program
```

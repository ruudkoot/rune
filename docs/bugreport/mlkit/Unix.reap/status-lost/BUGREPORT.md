# MLKit 4.7.23: `Unix.reap` and `OS.Process.system` lose the exit status: `fromStatus` gives `W_EXITSTATUS 0w255` for every failure

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/IO.c`, `basis/Unix.sml` and
`basis/Posix.sml` as the tag `v4.7.23`, byte for byte, so the code below
is unchanged there; `master` was not built.

## Summary

* **The trigger:** `Unix.fromStatus` or `Posix.Process.fromStatus` of a
  status that `Unix.reap` or `OS.Process.system` returns for a process
  that did not succeed.
* **What goes wrong:** `fromStatus` is `W_EXITSTATUS 0w255` for every
  such process: one that exited with 3, one that exited with 200, one that
  a signal killed. `OS.Process.system` turns every non-zero wait status
  into `OS.Process.failure`, `Unix.reap` every exit status but `W_EXITED`
  into it (its comment calls this a "lossy assumption"), and `fromStatus`
  maps `failure` to `W_EXITSTATUS 0wxFF`.
* **Required behaviour:** the
  [`UNIX` specification](https://smlfamily.github.io/Basis/unix.html):
  "`reap pr` ... returns the exit status given by pr when it terminated",
  and "`fromStatus sts` returns a concrete view of the given status", where
  the concrete view is `W_EXITSTATUS` "termination with the given exit
  value" or `W_SIGNALED` "termination upon receipt of the given signal";
  the [`POSIX_PROCESS` specification](https://smlfamily.github.io/Basis/posix-process.html)
  has the same `fromStatus`. A shell that ran `exit 3` has the view
  `W_EXITSTATUS 0w3`; one killed by `SIGTERM`, `W_SIGNALED` of it.

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
(* The exit status of a process, as reap and system give it and fromStatus
   shows it. *)
fun show (Unix.W_EXITED) = "W_EXITED"
  | show (Unix.W_EXITSTATUS w) = "W_EXITSTATUS " ^ Word8.fmt StringCvt.DEC w
  | show (Unix.W_SIGNALED s) = "W_SIGNALED " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord s)
  | show (Unix.W_STOPPED s) = "W_STOPPED " ^ SysWord.fmt StringCvt.DEC (Posix.Signal.toWord s)
fun sh s = Unix.execute ("/bin/sh", ["-c", s]) : (TextIO.instream, TextIO.outstream) Unix.proc
val () = print ("fromStatus (reap (sh \"exit 3\"))         = " ^ show (Unix.fromStatus (Unix.reap (sh "exit 3"))) ^ "\n")
val () = print ("fromStatus (reap (sh \"kill -TERM $$\"))  = " ^ show (Unix.fromStatus (Unix.reap (sh "kill -TERM $$"))) ^ "\n")
val () = print ("fromStatus (OS.Process.system \"exit 4\") = " ^ show (Unix.fromStatus (OS.Process.system "exit 4")) ^ "\n")
val () = print ("fromStatus (OS.Process.system \"exit 0\") = " ^ show (Unix.fromStatus (OS.Process.system "exit 0")) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
fromStatus (reap (sh "exit 3"))         = W_EXITSTATUS 255
fromStatus (reap (sh "kill -TERM $$"))  = W_EXITSTATUS 255
fromStatus (OS.Process.system "exit 4") = W_EXITSTATUS 255
fromStatus (OS.Process.system "exit 0") = W_EXITED
```

Expected: `W_EXITSTATUS 3`, `W_SIGNALED 15`, `W_EXITSTATUS 4` and
`W_EXITED`.

## The cause

`OS.Process.status` is an `int` in MLKit (`basis/Process.sml`), with
`success = 0` and `failure = ~1`. Three places reduce every other outcome
to `failure`:

* `sml_system` (`src/Runtime/IO.c`, lines 530-540), the C side of
  `OS.Process.system`:

  ```c
    res = system(cmd->data);
    if (res != 0)
      {
        res = -1;
      }
    return convertIntToML(res);
  ```

* `Unix.reap` (`basis/Unix.sml`, lines 111-120):

  ```sml
                  (* XXX: this function must return an
                  OS.Process.status, but waitpid returns a
                  Posix.Process.exit_status.  We make the lossy
                  assumption of turning W_EXITED into a success and
                  everything else a failure. *)

                  val st' =
                      case st of
                          W_EXITED => OS.Process.success
                       |  _ => OS.Process.failure
  ```

* `Posix.Process.fromStatus` (`basis/Posix.sml`, lines 358-360), which is
  also `Unix.fromStatus`:

  ```sml
    fun fromStatus st =
        if OS.Process.isSuccess st then W_EXITED
        else W_EXITSTATUS 0wxFF
  ```

## The fix

Keep the outcome in the `int`: 0 for success, the exit status 1-255 of a
process that exited, 256 plus the signal of one that a signal ended, and
-1 (`failure`) for anything else, and decode it in `fromStatus`.
`OS.Process.exit` and `terminate` of a status from 1 to 255 still exit
with that status.

```diff
--- a/src/Runtime/IO.c
+++ b/src/Runtime/IO.c
@@ -532,10 +532,17 @@
 {
   int res;
   res = system(cmd->data);
-  if (res != 0)
-    {
-      res = -1;
-    }
+  /* An OS.Process.status is 0 for success, the exit status 1-255 of a
+     process that exited, 256 + the signal of one that a signal ended, and
+     -1 (OS.Process.failure) otherwise. */
+  if (res == -1)
+    ;
+  else if (WIFEXITED(res))
+    res = WEXITSTATUS(res);
+  else if (WIFSIGNALED(res))
+    res = 256 + WTERMSIG(res);
+  else
+    res = -1;
   return convertIntToML(res);
 }
--- a/basis/Posix.sml
+++ b/basis/Posix.sml
@@ -358,3 +358,11 @@
+    (* A status is 0 for success, the exit status 1-255 of a process that
+       exited, 256 + the signal of one that a signal ended, and ~1
+       (OS.Process.failure) otherwise (sml_system in IO.c). *)
     fun fromStatus st =
-        if OS.Process.isSuccess st then W_EXITED
-        else W_EXITSTATUS 0wxFF
+        let val i : int = prim("id", st : OS.Process.status)
+        in if i = 0 then W_EXITED
+           else if i > 0 andalso i < 256 then W_EXITSTATUS (Word8.fromInt i)
+           else if i > 256 then W_SIGNALED (i - 256)
+           else W_EXITSTATUS 0wxFF
+        end
--- a/basis/Unix.sml
+++ b/basis/Unix.sml
@@ -114,10 +115,13 @@
                   assumption of turning W_EXITED into a success and
                   everything else a failure. *)
 
-                  val st' =
+                  (* the status of OS.Process.system: see Posix.Process.fromStatus *)
+                  val st' : OSP.status =
                       case st of
                           W_EXITED => OS.Process.success
-                       |  _ => OS.Process.failure
+                       |  W_EXITSTATUS w => prim("id", Word8.toInt w)
+                       |  W_SIGNALED s => prim("id", 256 + SysWord.toInt (Posix.Signal.toWord s))
+                       |  W_STOPPED _ => OS.Process.failure
```

(`prim ("id", ...)` crosses the opaque `OS.Process.status`, as
`mkerrno_` in `basis/Initial2.sml` does for `syserror`; the comment
about the lossy assumption would go too.) `fromStatus OS.Process.failure`
stays `W_EXITSTATUS 0wxFF`.

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with this change, and a copy of the installed
`lib/mlkit` with the new `basis/Posix.sml` and `basis/Unix.sml` (together
with the changes proposed in the other reports of this series, which touch
other functions): `bug.sml` then prints `W_EXITSTATUS 3`, `W_SIGNALED 15`,
`W_EXITSTATUS 4` and `W_EXITED`, and Rune's `tests/basis/unix.sml`,
`posix_process.sml`, `os.process.sml` and `os.process_os.sml` pass.
`master` was not built.

## Relation to Rune

Rune's Basis Library suite checks the statuses in `tests/basis/unix.sml`
(`Unix.reap/status`, `reap/twice`, `fromStatus/system`,
`fromStatus/signaled`, `kill/term`, `kill/kill`, `W_SIGNALED/reap`,
`W_STOPPED/reap-waits-for-the-end`) and `tests/basis/posix_process.sml`
(`Posix.Process.fromStatus/system-exit-3`, `system-exit-200`,
`system-killed`); all fail on MLKit with `W_EXITSTATUS 255` where they
expect the exit status or the signal. (`Unix.W_EXITSTATUS/reap`, which
expects `W_EXITSTATUS 255` for `exit 255`, passes by chance.) The lines of
`tests/basis/deviations.txt`:

```
native:mlkit@* | *.fromStatus/s[iy]* | HOST-BUG | the status of a process that did not succeed is W_EXITSTATUS 0w255 whatever its exit status or signal: OS.Process.system and Unix.reap reduce every failure to OS.Process.failure (an int, ~1), which fromStatus maps to W_EXITSTATUS 0wxFF
native:mlkit@* | Unix.reap/[st]* | HOST-BUG | the status of a process that did not succeed is W_EXITSTATUS 0w255 whatever its exit status or signal: reap reduces every failure to OS.Process.failure (an int, ~1), which fromStatus maps to W_EXITSTATUS 0wxFF
native:mlkit@* | Unix.kill/* | HOST-BUG | the status of a process that a signal ended is W_EXITSTATUS 0w255, not W_SIGNALED: reap reduces every failure to OS.Process.failure (an int, ~1), which fromStatus maps to W_EXITSTATUS 0wxFF
native:mlkit@* | Unix.W_S*/reap* | HOST-BUG | the status of a process that did not succeed is W_EXITSTATUS 0w255 whatever its exit status or signal: reap reduces every failure to OS.Process.failure (an int, ~1), which fromStatus maps to W_EXITSTATUS 0wxFF
```

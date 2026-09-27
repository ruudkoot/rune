# MLKit 4.7.23: `Unix.exit` neither runs the actions of `OS.Process.atExit` nor flushes the output streams

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton and Poly/ML run the actions and flush the streams.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Unix.sml` as the tag `v4.7.23`, byte for
byte, so the code below is unchanged there; `master` was not built.

## Summary

* **The trigger:** `Unix.exit st` in a program that has output in the
  buffer of a stream, or actions registered with `OS.Process.atExit`.
* **What goes wrong:** the process ends at once: the buffered output is
  lost and the actions do not run. `Unix.exit` is `Posix.Process.exit`,
  which the specification makes skip both.
* **Required behaviour:** the
  [`UNIX` specification](https://smlfamily.github.io/Basis/unix.html):
  "`exit st` executes all actions registered with OS.Process.atExit,
  flushes and closes all I/O streams opened using the Library, then
  terminates the SML process with termination status st." Of
  `Posix.Process.exit` the
  [`POSIX_PROCESS` specification](https://smlfamily.github.io/Basis/posix-process.html)
  says the opposite: "Calling exit does not flush or close any open IO
  streams, nor does it call OS.Process.atExit."

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
(* Unix.exit after writing to a file and registering an action with
   OS.Process.atExit. After the run, flushed.txt should hold "flushed" and
   atexit.txt "ran". *)
val () = OS.Process.atExit (fn () =>
           let val out = TextIO.openOut "atexit.txt" in TextIO.output (out, "ran"); TextIO.closeOut out end)
val out = TextIO.openOut "flushed.txt"
val () = TextIO.output (out, "flushed")
val () = Unix.exit 0w0
```

`run.sh` builds and runs it and shows the two files:

```
$ MLKIT=mlkit sh run.sh
exit status 0
flushed.txt: []
atexit.txt: []
```

Expected: `flushed.txt: [flushed]` and `atexit.txt: [ran]`, which is what
the same program prints with `OS.Process.exit OS.Process.success` in place
of `Unix.exit 0w0`.

## The cause

`basis/Unix.sml`, line 128:

```sml
    fun exit st = PP.exit st
```

where `PP` is `Posix.Process`, whose `exit` (`basis/Posix.sml`, lines
286-290) calls C's `exit` directly. `OS.Process.exit`
(`basis/Process.sml`, lines 33-38) runs the actions of `atExit`, among
which MLKit's streams register their flushing, before it terminates.

## The fix

Do what `OS.Process.exit` does, and end with `Posix.Process.exit`, which
takes the `Word8.word` status (`List` is not in scope in `Unix.sml`, hence
the local loop):

```diff
--- a/basis/Unix.sml
+++ b/basis/Unix.sml
@@ -125,5 +129,15 @@
 
     fun kill (PROC{pid, ...}, signal) = PP.kill (PP.K_PROC pid, signal)
 
-    fun exit st = PP.exit st
+    (* as OS.Process.exit: the actions of atExit, which flush and close the
+       streams, then the end of the process *)
+    fun exit st =
+        let fun run [] = ()
+              | run (f :: fs) = ((f ()) handle _ => (); run fs)
+        in if !Initial.exitCalled then raise Initial.RaisedInExit
+           else (Initial.exitCalled := true;
+                 run (!Initial.exittasks);
+                 Initial.exittasks := [];
+                 PP.exit st)
+        end
   end (* structure Unix *)
```

Tested on a copy of the installed `lib/mlkit` with this change (together
with the changes proposed in the other reports of this series, which touch
other functions): `run.sh` then shows `flushed.txt: [flushed]` and
`atexit.txt: [ran]`, and Rune's `tests/basis/unix.sml` passes. `master`
was not built.

## Relation to Rune

Rune's Basis Library suite checks both in a child that calls `Unix.exit`
(`tests/basis/unix.sml`, `Unix.exit/flushes`: `got "", expected
"flushed"`, and `Unix.exit/runs-atExit`, which raises an exception on
MLKit because the file the action writes is missing). The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | Unix.exit/[fr]* | HOST-BUG | Unix.exit is Posix.Process.exit: it neither runs the actions of OS.Process.atExit nor flushes the output streams
```

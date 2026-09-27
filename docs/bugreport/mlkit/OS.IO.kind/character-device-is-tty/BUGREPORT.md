# MLKit 4.7.23: `OS.IO.kind` gives `tty` for every character device, `/dev/null` included

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton and SML/NJ also give `tty` for `/dev/null`; Poly/ML gives `device`.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/OS.sml` as the tag `v4.7.23`, byte for
byte, so the code below is unchanged there; `master` was not built.
MLton and SML/NJ do the same (Rune's
`tests/basis/deviations.txt` records it for both).

## Summary

* **The trigger:** `OS.IO.kind` of a descriptor of a character device
  that is not a terminal, such as `/dev/null`, `/dev/zero` or
  `/dev/urandom`; also standard input when it is redirected from
  `/dev/null`.
* **What goes wrong:** the kind is `OS.IO.Kind.tty`, although
  `Posix.ProcEnv.isatty` of the descriptor is false.
* **Required behaviour:** the
  [`OS_IO` specification](https://smlfamily.github.io/Basis/os-io.html)
  defines `tty` as "A terminal console." and `device` as "A logical or
  physical hardware device."

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
(* The kind of /dev/null, a character device that is not a terminal. *)
fun kindName k =
  if k = OS.IO.Kind.file then "file" else if k = OS.IO.Kind.dir then "dir"
  else if k = OS.IO.Kind.symlink then "symlink" else if k = OS.IO.Kind.tty then "tty"
  else if k = OS.IO.Kind.pipe then "pipe" else if k = OS.IO.Kind.socket then "socket"
  else if k = OS.IO.Kind.device then "device" else "other"
val fd = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
val () = print ("OS.IO.kind of /dev/null: " ^ kindName (OS.IO.kind (Posix.FileSys.fdToIOD fd))
                ^ " (Posix.ProcEnv.isatty: " ^ Bool.toString (Posix.ProcEnv.isatty fd) ^ ")\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
OS.IO.kind of /dev/null: tty (Posix.ProcEnv.isatty: false)
```

Expected: `device`.

## The cause

`OS.IO.kind` (`basis/OS.sml`, lines 80-93) takes every character device
for a terminal:

```sml
                in if ST.isReg s then Kind.file
                   else if ST.isDir s then Kind.dir
                   else if ST.isChr s then Kind.tty
                   else if ST.isBlk s then Kind.device
```

## The fix

A character device is a terminal when `isatty` says so:

```diff
--- a/basis/OS.sml
+++ b/basis/OS.sml
@@ -83,7 +83,8 @@
                 let val s = PosixStat.fstat fd
                 in if ST.isReg s then Kind.file
                    else if ST.isDir s then Kind.dir
-                   else if ST.isChr s then Kind.tty
+                   else if ST.isChr s then
+                     (if prim("@isatty", fd : int) = (1 : int) then Kind.tty else Kind.device)
                    else if ST.isBlk s then Kind.device
                    else if ST.isLink s then Kind.symlink
                    else if ST.isFIFO s then Kind.pipe
```

(`Posix.ProcEnv.isatty`, `basis/Posix.sml` line 463, calls `isatty` the
same way; `Posix` is not visible in `OS.sml`.)

Tested on a copy of the installed `lib/mlkit` with this change (together
with the changes proposed in the other reports of this series, which touch
other functions): `bug.sml` then prints `device`, and Rune's
`tests/basis/os.io.sml` and `tests/basis/os.io_std.sml` pass. A terminal
was not available to check that it is still `tty`. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks the kind of `/dev/null`
(`tests/basis/os.io.sml`, `OS.IO.Kind.device/dev-null`: `got tty,
expected device`, and `OS.IO.Kind.tty/dev-null`) and that a standard
descriptor has the kind `tty` exactly when it is a terminal
(`tests/basis/os.io_std.sml`, `OS.IO.Kind.tty/standard-descriptors`;
the runner gives the tests `/dev/null` as standard input). The lines of
`tests/basis/deviations.txt`, worded as the ones for MLton and SML/NJ:

```
native:mlkit@* | OS.IO.Kind.*/dev-null | HOST-BUG | kind gives tty for every character device: /dev/null, which is no terminal ("tty: A terminal console"), is not device
native:mlkit@* | OS.IO.Kind.tty/standard-descriptors | HOST-BUG | kind gives tty for every character device: standard input, /dev/null where the runner runs the test, is no terminal (Posix.ProcEnv.isatty is false)
```

# MLKit 4.7.23: `Posix.FileSys.chmod` and `fchmod` set every file to mode 1001

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The runtime is handed the flags of `open` where the mode belongs, so every file gets the mode 1001.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/Posix.c` and `basis/Posix.sml` as
the tag `v4.7.23`, byte for byte, so the code below is unchanged there;
`master` was not built.

## Summary

* **The trigger:** any call of `Posix.FileSys.chmod` or `fchmod`.
* **What goes wrong:** the mode given is ignored; the file gets the mode
  `01001` (sticky bit and execute for others, `---------t`), whatever the
  mode. The runtime passes the flags it built for `open` (`O_WRONLY |
  O_TRUNC`, which is `01001` on Linux) to `chmod` instead of the mode.
* **Required behaviour:** the
  [`POSIX_FILE_SYS` specification](https://smlfamily.github.io/Basis/posix-file-sys.html):
  "`chmod (s, mode)` changes the permissions of s to mode", and
  "`fchmod (fd, mode)` changes the permissions of the file opened as fd to
  mode."

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

`bug.sml` shows the mode as `stat(1)` prints it, so that nothing depends
on how MLKit codes modes (see the report `Posix.FileSys.S/mode-encoding`):

```sml
(* chmod and fchmod a file, and show its mode as stat(1) prints it. *)
structure FS = Posix.FileSys
structure S = FS.S
fun show what = (print (what ^ ": "); ignore (OS.Process.system "stat -c '%A (%a)' f.txt"))
val () = (let val out = TextIO.openOut "f.txt" in TextIO.closeOut out end)
val () = FS.chmod ("f.txt", S.flags [S.irusr, S.iwusr, S.irgrp])
val () = show "after chmod rw-r-----"
val () = FS.chmod ("f.txt", S.irwxu)
val () = show "after chmod rwx------"
val fd = FS.openf ("f.txt", FS.O_RDONLY, FS.O.flags [])
val () = FS.fchmod (fd, S.flags [S.irusr, S.iroth])
val () = Posix.IO.close fd
val () = show "after fchmod r-----r--"
val () = FS.unlink "f.txt"
```

```
$ mlkit -o bug bug.mlb && ./bug
after chmod rw-r-----: ---------t (1001)
after chmod rwx------: ---------t (1001)
after fchmod r-----r--: ---------t (1001)
```

Expected: `-rw-r----- (640)`, `-rwx------ (700)` and `-r-----r-- (404)`.

## The cause

`chmod` and `fchmod` (`basis/Posix.sml`, lines 785-786) go through the
runtime's `sml_lower`, with the open mode `O_WRONLY` and the flags
`O.trunc` that the function needs for its other uses:

```sml
    fun chmod (name : string, m) = (lower "chmod" (name, O_WRONLY, O.trunc, m, 0, 6);())
    fun fchmod (f,m) = (lower "fchmod" ("",O_WRONLY, O.trunc, m, f, 7);())
```

`sml_lower` (`src/Runtime/Posix.c`, line 165) builds from them the flags
of `open` in `f` and from the mode `perm` the mode in `mode`, and then
calls `chmod` and `fchmod` with `f` (lines 224-229):

```c
    case 6:
      res = chmod(name,f);
      break;
    case 7:
      res = fchmod(i,f);
      break;
```

`f` is `O_WRONLY | O_TRUNC`, `01 | 01000` on Linux.

## The fix

```diff
--- a/src/Runtime/Posix.c
+++ b/src/Runtime/Posix.c
@@ -222,10 +222,10 @@
       res = mkfifo(name, mode);
       break;
     case 6:
-      res = chmod(name,f);
+      res = chmod(name,mode);
       break;
     case 7:
-      res = fchmod(i,f);
+      res = fchmod(i,mode);
       break;
     default:
       res = 0;
```

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with this change, in a copy of the installed
`lib/mlkit` (together with the changes proposed in the other reports of
this series, among them the new code of the modes, report
`Posix.FileSys.S/mode-encoding`, which does not change what `bug.sml`
prints): `bug.sml` then prints `-rw-r----- (640)`, `-rwx------ (700)` and
`-r-----r-- (404)`, and Rune's Basis Library tests of `Posix.FileSys`
(`posix_filesys`, `posix_filesys_dir`) pass. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks `chmod` and `fchmod` in
`tests/basis/posix_filesys.sml`: `Posix.FileSys.S.*/chmod` (each mode set
alone and read back with `stat`), `chmod/sets-mode`, `chmod/not-masked`,
`chmod/no-permissions`, `fchmod/sets-mode`, `fchmod/fstat-agrees` and
`createf/existing-mode-kept` (which sets the mode of the file with
`chmod` first). On MLKit they fail with `got 0wx100` (the bit that
MLKit's code of the modes sets for the execute permission of others), or
`false` for `S.isgid/chmod`. The lines of `tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.FileSys.*chmod* | HOST-BUG | chmod and fchmod ignore the mode and set 01001 (---------t): the runtime passes them the flags it made for open, O_WRONLY | O_TRUNC
native:mlkit@* | Posix.FileSys.createf/existing-mode-kept | HOST-BUG | chmod, with which the check sets the mode of the file first, ignores the mode and sets 01001 (---------t): the runtime passes it the flags it made for open, O_WRONLY | O_TRUNC
```

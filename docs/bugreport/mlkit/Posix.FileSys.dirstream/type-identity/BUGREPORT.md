# MLKit 4.7.23: `Posix.FileSys.dirstream` and `access_mode` are not the types of `OS.FileSys`

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Posix.sml`, `basis/POSIX.sig` and
`basis/POSIX_FILE_SYS.sml` as the tag `v4.7.23`, byte for byte, so the
code below is unchanged there; `master` was not built.

## Summary

* **The trigger:** a program that uses a `Posix.FileSys.dirstream` as an
  `OS.FileSys.dirstream`, or a `Posix.FileSys.access_mode` as an
  `OS.FileSys.access_mode`, or the other way round.
* **What goes wrong:** the program does not compile: "Type clash".
* **Required behaviour:** the
  [`POSIX_FILE_SYS` specification](https://smlfamily.github.io/Basis/posix-file-sys.html)
  says of `type dirstream` "This type is identical to
  OS.FileSys.dirstream", and of `datatype access_mode` "This type is
  identical to OS.FileSys.access_mode." MLKit's own documentation of the
  signature (`basis/POSIX_FILE_SYS.sml`, lines 165-168 and 418-419) says
  the same.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44), running as root.
* **Basis Library: MLKit's own.** Each program is built from its `.mlb`
  file, which lists `$(SML_LIB)/basis/basis.mlb` and the program, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* Posix.FileSys.dirstream is identical to OS.FileSys.dirstream. *)
val d : OS.FileSys.dirstream = Posix.FileSys.opendir "."
val () = OS.FileSys.closeDir d
val () = print "dirstream: the same type\n"
```

```
$ mlkit -o bug bug.mlb
bug.sml, line 2, column 4:
  val d : OS.FileSys.dirstream = Posix.FileSys.opendir "."
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   type of left-hand side pattern:     dirstream
   type of right-hand side expression: dirstream<210-LsEskx4tKrJB8K4zFLuEZb-basis.mlb->Posix.sml>
Stopping compilation of MLB-file due to error (code 1).
```

`bug-access.sml` (built from `bug-access.mlb`):

```sml
(* Posix.FileSys.access_mode is identical to OS.FileSys.access_mode. *)
val modes : OS.FileSys.access_mode list = [Posix.FileSys.A_READ, Posix.FileSys.A_WRITE]
val () = print ("access_mode: the same type; access \".\": "
                ^ Bool.toString (OS.FileSys.access (".", modes)) ^ "\n")
```

```
$ mlkit -o bug-access bug-access.mlb
bug-access.sml, line 2, column 4:
  val modes : OS.FileSys.access_mode list = [Posix.FileSys.A_READ, Posix.FileSys.A_WRITE]
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Type clash,
   type of left-hand side pattern:     access_mode list
   type of right-hand side expression: access_mode<218-LsEskx4tKrJB8K4zFLuEZb-basis.mlb->Posix.sml> list
Stopping compilation of MLB-file due to error (code 1).
```

Both should compile and print `dirstream: the same type` and
`access_mode: the same type; access ".": true`.

## The cause

In `basis/Posix.sml`, the structure `FileSys` starts with the right types
(lines 578-588):

```sml
  structure FileSys : POSIX_FILE_SYS
      where type file_desc = ProcEnv.file_desc
      where type uid = ProcEnv.uid
      where type gid = ProcEnv.gid
      where type dirstream = OS.FileSys.dirstream =
  struct
    ...
    type dirstream = OS.FileSys.dirstream
    datatype access_mode = datatype OS.FileSys.access_mode
```

but two things undo them:

* line 645 declares `access_mode` again, as a new datatype, which `access`
  then converts to `OS.FileSys.access_mode` constructor by constructor:

  ```sml
    datatype access_mode = A_READ | A_WRITE | A_EXEC
  ```

* the whole structure is sealed opaquely by line 223, `structure Posix :>
  POSIX =`, and `POSIX` (`basis/POSIX.sig`) says nothing of `dirstream`,
  so the type is abstract outside; `POSIX_FILE_SYS`
  (`basis/POSIX_FILE_SYS.sml`, line 120) specifies `access_mode` as a
  datatype of its own, which opaque sealing makes a new type too.

## The fix

Say in the signatures what the specification says in prose, and drop the
second datatype:

```diff
--- a/basis/POSIX.sig
+++ b/basis/POSIX.sig
@@ -9,6 +9,7 @@
     structure ProcEnv : POSIX_PROC_ENV
       where type pid = Process.pid
     structure FileSys : POSIX_FILE_SYS
+      where type dirstream = OS.FileSys.dirstream
       where type file_desc = ProcEnv.file_desc
       where type uid = ProcEnv.uid
       where type gid = ProcEnv.gid
--- a/basis/POSIX_FILE_SYS.sml
+++ b/basis/POSIX_FILE_SYS.sml
@@ -117,7 +117,7 @@
     val lstat : string -> ST.stat
     val fstat : file_desc -> ST.stat
 
-    datatype access_mode = A_READ | A_WRITE | A_EXEC
+    datatype access_mode = datatype OS.FileSys.access_mode
 
     val access    : string * access_mode list -> bool
     val chmod     : string * S.mode -> unit
--- a/basis/Posix.sml
+++ b/basis/Posix.sml
@@ -642,7 +642,6 @@
     end
 
     datatype open_mode = O_RDONLY | O_WRONLY | O_RDWR
-    datatype access_mode = A_READ | A_WRITE | A_EXEC
 
     fun iodToFD (x:OS.IO.iodesc) : file_desc option = OS.iodToFD x
     fun wordToFD (x:SysWord.word) : file_desc = SysWord.toIntX x
@@ -701,13 +700,7 @@
         end
 
-    fun access (a,b) =
-        let
-          fun cvt A_EXEC = OS.FileSys.A_EXEC
-            | cvt A_WRITE = OS.FileSys.A_WRITE
-            | cvt A_READ = OS.FileSys.A_READ
-        in OS.FileSys.access (a,List.map cvt b)
-        end
+    fun access (a,b) = OS.FileSys.access (a,b)
```

A structure with this signature
still matches the specification's `POSIX_FILE_SYS`, whose
`access_mode` has the same constructors.

Tested on a copy of the installed `lib/mlkit` with these changes
(together with the changes proposed in the other reports of this series,
which touch other functions): both programs compile and print what they
should, and the sections `dirstream` and `access_mode` of Rune's
`tests/basis/posix_filesys_sig.sml` pass (the section `matches` needs
members MLKit lacks, `ST.atime` and `utime`, and was left out). `master`
was not built.

## Relation to Rune

Rune's Basis Library suite checks both identities in sections of their
own of `tests/basis/posix_filesys_sig.sml`
(`Posix.FileSys:POSIX_FILE_SYS/dirstream-is-OS.FileSys.dirstream` and
`access_mode-is-OS.FileSys.access_mode`); on MLKit neither section
compiles, and the run reports `@section/posix_filesys_sig/dirstream` and
`@section/posix_filesys_sig/access_mode`. The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | @section/posix_filesys_sig/[da]* | HOST-BUG | Posix.FileSys.dirstream and access_mode are not OS.FileSys.dirstream and access_mode ("This type is identical to ..."): Posix is sealed opaquely with a POSIX that does not share dirstream, and Posix.FileSys declares access_mode again as a datatype of its own
```

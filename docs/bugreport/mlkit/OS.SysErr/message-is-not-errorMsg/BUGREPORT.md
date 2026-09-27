# MLKit 4.7.23: the string of `OS.SysErr (s, SOME e)` is not `OS.errorMsg e`

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Initial2.sml` and `basis/FileSys.sml` as
the tag `v4.7.23`, byte for byte, so the code below is unchanged there;
`master` was not built.

## Summary

* **The trigger:** any `OS.SysErr` with a `syserror` that MLKit's Basis
  Library raises for a failed system call: `OS.FileSys.remove` of a
  missing file, `TextIO.openIn` (the cause of its `IO.Io`),
  `Posix.FileSys.opendir`, and so on.
* **What goes wrong:** the string is the name of the operation, the file
  and the message, `"remove failed on `no-such-file': No such file or
  directory"`, where `OS.errorMsg e` is `"No such file or directory"`.
* **Required behaviour:** the
  [`OS` specification](https://smlfamily.github.io/Basis/os.html), of
  `exception SysErr of (string * syserror option)`: "The first argument is
  a descriptive string explaining the error, and the second argument
  optionally specifies the system error condition. The form and content
  of the description strings are operating system and implementation
  dependent, but if a SysErr exception has the form SysErr(s,SOME e), then
  we have errorMsg e = s."

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
(* "if a SysErr exception has the form SysErr(s,SOME e), then we have
   errorMsg e = s" *)
fun check name f =
  (f (); print (name ^ ": no exception\n"))
  handle OS.SysErr (s, SOME e) =>
           print (name ^ ": SysErr (\"" ^ s ^ "\", SOME e), errorMsg e = \"" ^ OS.errorMsg e ^ "\": "
                  ^ (if OS.errorMsg e = s then "equal" else "DIFFERENT") ^ "\n")
       | IO.Io {cause = OS.SysErr (s, SOME e), ...} =>
           print (name ^ ": Io with SysErr (\"" ^ s ^ "\", SOME e), errorMsg e = \"" ^ OS.errorMsg e ^ "\": "
                  ^ (if OS.errorMsg e = s then "equal" else "DIFFERENT") ^ "\n")
val () = check "OS.FileSys.remove" (fn () => OS.FileSys.remove "no-such-file")
val () = check "OS.FileSys.chDir" (fn () => OS.FileSys.chDir "no-such-dir")
val () = check "TextIO.openIn" (fn () => TextIO.closeIn (TextIO.openIn "no-such-file"))
val () = check "Posix.FileSys.opendir" (fn () => ignore (Posix.FileSys.opendir "no-such-dir"))
```

```
$ mlkit -o bug bug.mlb && ./bug
OS.FileSys.remove: SysErr ("remove failed on `no-such-file': No such file or directory", SOME e), errorMsg e = "No such file or directory": DIFFERENT
OS.FileSys.chDir: SysErr ("chDir failed on `no-such-dir': No such file or directory", SOME e), errorMsg e = "No such file or directory": DIFFERENT
TextIO.openIn: Io with SysErr ("Posix.FileSys.openf failed: No such file or directory", SOME e), errorMsg e = "No such file or directory": DIFFERENT
Posix.FileSys.opendir: SysErr ("openDir failed on `no-such-dir': No such file or directory", SOME e), errorMsg e = "No such file or directory": DIFFERENT
```

## The cause

The library raises these exceptions with `raiseSys`, of which there are
two copies, `basis/Initial2.sml` (lines 23-30) and `basis/FileSys.sml`
(lines 95-103). Both put the operation and its operand in front of the
message:

```sml
    (* Raise SysErr with OS specific explanation if errno <> 0 *)
    fun raiseSys mlOp operand reason =
	let val errno = errno_ ()
	in if errno = 0 then raiseSysML mlOp operand reason
	   else raise SysErr
		      (formatErr mlOp operand (errorMsg errno),
		       SOME (mkerrno_ errno))
	end
```

where `formatErr mlOp (SOME operand) reason` is `mlOp ^ " failed on `" ^
operand ^ "': " ^ reason`.

## The fix

When there is a `syserror`, the string must be its message:

```diff
--- a/basis/Initial2.sml
+++ b/basis/Initial2.sml
@@ -24,9 +24,7 @@
     fun raiseSys mlOp operand reason =
 	let val errno = errno_ ()
 	in if errno = 0 then raiseSysML mlOp operand reason
-	   else raise SysErr
-		      (formatErr mlOp operand (errorMsg errno),
-		       SOME (mkerrno_ errno))
+	   else raise SysErr (errorMsg errno, SOME (mkerrno_ errno))
 	end
 
--- a/basis/FileSys.sml
+++ b/basis/FileSys.sml
@@ -97,9 +97,7 @@
         let val errno = errno_ ()
         in
             if errno = 0 then raiseSysML mlOp operand reason
-            else raise OS.SysErr
-                (formatErr mlOp operand (OS.errorMsg errno),
-                 SOME (mkerrno_ errno))
+            else raise OS.SysErr (OS.errorMsg errno, SOME (mkerrno_ errno))
         end
```

The name of the operation and of the file are then gone from the
exception of `OS.FileSys` and `Posix` (an `IO.Io` still has them in its
`function` and `name`); the specification leaves no room for them in the
string of a `SysErr` with a `syserror`. (The `SysErr`s that
`Posix.SysDB` raises, `basis/Posix.sml` lines 1039-1074, have the same
problem, `errorName ^ ": " ^ errorMsg`.)

Tested on a copy of the installed `lib/mlkit` with this change (together
with the changes proposed in the other reports of this series): all four
lines of `bug.sml` print `equal`, with the message `"No such file or
directory"`, and Rune's Basis Library tests of `OS`, `OS.FileSys`,
`Posix.Error`, `TextIO` and `BinIO` show no new failure. `master` was not
built.

## Relation to Rune

Rune's Basis Library suite checks the equation for a missing file and a
path through a plain file opened with `TextIO.openIn`
(`tests/basis/os.process.sml`, `OS.errorMsg/is-the-message-of-SysErr` and
`is-the-message-of-SysErr-notdir`), for six failing calls of
`OS.FileSys` (`tests/basis/os.process_os.sml`, `OS.errorMsg/remove-missing`,
`openDir-missing`, `chDir-missing`, `mkDir-existing`, `chDir-to-a-file`,
`rmDir-not-empty`), and in `tests/basis/posix_error.sml`
(`Posix.Error.errorMsg/of-SysErr`). All fail on MLKit. The lines of
`tests/basis/deviations.txt`:

```
native:mlkit@* | *.errorMsg/*of-SysErr* | HOST-BUG | the string of SysErr (s, SOME e) is not errorMsg e ("then we have errorMsg e = s"): it names the operation and the file first, "remove failed on `f': No such file or directory"
native:mlkit@* | OS.errorMsg/[!nis]* | HOST-BUG | the string of SysErr (s, SOME e) is not errorMsg e ("then we have errorMsg e = s"): it names the operation and the file first, "remove failed on `f': No such file or directory"
```

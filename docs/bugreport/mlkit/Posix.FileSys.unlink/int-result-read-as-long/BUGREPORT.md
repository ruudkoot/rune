# MLKit 4.7.23: `Posix.FileSys.unlink`, `rmdir`, `rename`, `link`, `symlink` and `Posix.IO.close` do not raise `OS.SysErr` when they fail

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The C functions' `int` result is read as a `long`, so a failure goes unseen.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Posix.sml`, `src/Runtime/Posix.c` and
`src/Compiler/Backend/X64/CodeGenUtilX64.sml` as the tag `v4.7.23`, byte
for byte, so the code below is unchanged there; `master` was not built.

## Summary

* **The trigger:** a call of `Posix.FileSys.unlink`, `rmdir`, `rename`,
  `link`, `symlink` or `Posix.IO.close` that fails: a missing file, a
  name that exists, a descriptor that is closed.
* **What goes wrong:** the call returns `()` as if it had succeeded. The
  Basis Library calls these functions of the C library directly, with
  MLKit's auto-conversion (`prim ("@unlink", path) : int`), and tests the
  result for `~1`. Auto-conversion reads an ML `int` result as the whole
  64-bit `%rax`, but these functions return a C `int`, in `%eax`; the
  x86-64 ABI leaves the upper half of `%rax` undefined, and glibc's
  `unlink` leaves it 0, so the -1 arrives as 4294967295 and no error is
  seen.
* **Required behaviour:** the
  [`POSIX_FILE_SYS` specification](https://smlfamily.github.io/Basis/posix-file-sys.html)
  and the [`POSIX_IO` specification](https://smlfamily.github.io/Basis/posix-io.html)
  describe these functions as their POSIX namesakes, and the
  [`POSIX` specification](https://smlfamily.github.io/Basis/posix.html)
  says how their failures are reported: "Many functions in the Posix
  structure can raise OS.SysErr for many reasons. ... The programmer will
  need to consult more detailed POSIX documentation." `unlink` of a
  missing file fails with `ENOENT`, `close` of a closed descriptor with
  `EBADF`, and so on.

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
(* Calls that fail, each of which must raise OS.SysErr. *)
fun try name f =
  (f (); print (name ^ ": no exception\n"))
  handle OS.SysErr (_, SOME e) => print (name ^ ": SysErr " ^ Posix.Error.errorName e ^ "\n")
       | OS.SysErr (_, NONE) => print (name ^ ": SysErr without a syserror\n")
structure FS = Posix.FileSys
val () = (let val out = TextIO.openOut "file.txt" in TextIO.closeOut out end)
val () = try "unlink of a missing file" (fn () => FS.unlink "no-such-file")
val () = try "rmdir of a missing directory" (fn () => FS.rmdir "no-such-dir")
val () = try "rename of a missing file" (fn () => FS.rename {old = "no-such-file", new = "new-name"})
val () = try "link to a missing file" (fn () => FS.link {old = "no-such-file", new = "new-name"})
val () = try "symlink onto an existing name" (fn () => FS.symlink {old = "x", new = "file.txt"})
val () = try "chown of a missing file" (fn () => FS.chown ("no-such-file", Posix.ProcEnv.getuid (), Posix.ProcEnv.getgid ()))
val () = try "close of a closed descriptor" (fn () => let val {infd, outfd} = Posix.IO.pipe ()
                                                   in Posix.IO.close infd; Posix.IO.close outfd; Posix.IO.close infd end)
val () = FS.unlink "file.txt"
```

```
$ mlkit -o bug bug.mlb && ./bug
unlink of a missing file: no exception
rmdir of a missing directory: no exception
rename of a missing file: no exception
link to a missing file: no exception
symlink onto an existing name: no exception
chown of a missing file: SysErr noent
close of a closed descriptor: no exception
```

All seven should raise `OS.SysErr` (`noent`, `noent`, `noent`, `noent`,
`exist`, `noent`, `badf`). `chown` does, by chance: glibc's `chown` is a
plain system-call stub whose error path sets all of `%rax` to -1, while
its `unlink` is a C function that returns the `int` in `%eax`. Under gdb,
for `unlink "no-such-file"`:

```
(gdb) finish
Run till exit from #0  __unlink (name=0x55555567e9f8 "no-such-file") at ../sysdeps/unix/sysv/linux/unlink.c:26
0x000055555565ac70 in F.unlink46_6tbEedf6kXjFQA8kZ9GUCc ()
Value returned is $2 = -1
(gdb) p/x $rax
$3 = 0xffffffff
(gdb) x/5i $pc
=> 0x55555565ac70 <F.unlink46_...+25>:	lea    0x1(%rax,%rax,1),%rax
   0x55555565ac75 <F.unlink46_...+30>:	mov    0x10(%rsp),%r13
   0x55555565ac7a <F.unlink46_...+35>:	mov    $0xffffffffffffffff,%r11
   0x55555565ac81 <F.unlink46_...+42>:	cmp    %r11,%rax
   0x55555565ac84 <F.unlink46_...+45>:	jne    0x55555565ace0
```

The tagged result `2 * 0xffffffff + 1` is compared with the tagged `~1`
(`-1`), and the error branch is not taken.

## The cause

`basis/Posix.sml` binds C library functions that return an `int`
directly with auto-conversion, for instance (lines 747-749 and 836-838):

```sml
    fun unlink (path : string) =
	let val a = prim("@unlink", path) : int
	in if a = ~1 then raiseSys "Posix.FileSys.unlink" NONE "" else ()
	end
...
    fun close f = let val a = prim("@close", f : int) : int
		  in if a = ~1 then raiseSys "close" NONE "" else ()
		  end
```

The X64 backend converts the result of such a call from all of `%rax`
(`maybe_tag_int_result` in
`src/Compiler/Backend/X64/CodeGenUtilX64.sml`, line 220: `lea 1(%rax,%rax)`).
That is right for a C function that returns a `long`, which is what the
manual's example of auto conversion uses (`long power_auto(long base, long
n)`, section "Auto Conversion" of `doc/manual/mlkit.tex`), and wrong for
one that returns an `int`. The same holds for every C library function
that the library calls this way and that returns an `int`: in
`basis/Posix.sml` `link` (line 732), `rename` (737), `symlink` (742),
`unlink` (747), `rmdir` (776), `chown` (789), `fchown` (794), `ftruncate`
(698), `close` (836), `kill` (377), `fork` (279), `setgid` (525), `setsid`
(532), `setuid` (556) and `setpgid` (565), and in `basis/Socket.sml`
`close` (237) and `shutdown` (245). Whether a given failure is seen depends
on how the C library happens to leave `%rax`.

(`Posix.ProcEnv.setuid` has a bug of its own on line 556:
`prim("@setuid", ())` passes no user ID at all.)

## The fix

Call these functions through wrappers of the runtime that return a
`long`, as the runtime's own `sml_dupfd` and `sml_readArr` do. In
`src/Runtime/Posix.c`:

```c
/* Auto-conversion (prim "@...") reads the result of the C function as a
 * long, so the functions of the C library that return an int are called
 * through these wrappers: a -1 in an int result is 0xFFFFFFFF in a long. */
long sml_posix_link(char *old, char *new) { return link(old, new); }
long sml_posix_rename(char *old, char *new) { return rename(old, new); }
long sml_posix_symlink(char *old, char *new) { return symlink(old, new); }
long sml_posix_unlink(char *path) { return unlink(path); }
long sml_posix_rmdir(char *path) { return rmdir(path); }
long sml_posix_chown(char *path, long uid, long gid) { return chown(path, (uid_t) uid, (gid_t) gid); }
long sml_posix_fchown(long fd, long uid, long gid) { return fchown((int) fd, (uid_t) uid, (gid_t) gid); }
long sml_posix_ftruncate(long fd, long len) { return ftruncate((int) fd, (off_t) len); }
long sml_posix_close(long fd) { return close((int) fd); }
long sml_posix_kill(long pid, long sig) { return kill((pid_t) pid, (int) sig); }
long sml_posix_fork(void) { return fork(); }
long sml_posix_setgid(long g) { return setgid((gid_t) g); }
long sml_posix_setuid(long u) { return setuid((uid_t) u); }
long sml_posix_setpgid(long p, long g) { return setpgid((pid_t) p, (pid_t) g); }
long sml_posix_setsid(void) { return setsid(); }
```

and in `basis/Posix.sml` the name of each call changes, `prim("@unlink",
path)` to `prim("@sml_posix_unlink", path)` and so on (and `setuid` passes
its argument: `prim("@sml_posix_setuid", g : int)`). `Socket.close` and
`Socket.shutdown` want the same.

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with the wrappers, and a copy of the installed
`lib/mlkit` whose `basis/Posix.sml` calls them (together with the changes
proposed in the other reports of this series, which touch other
functions): `bug.sml` then prints `SysErr noent`, `noent`, `noent`,
`noent`, `exist`, `noent` and `badf`, and Rune's Basis Library tests of
`Posix.FileSys`, `Posix.IO` (as far as it builds), `Posix.Process`,
`Posix.Error`, `OS` and `Unix` show no new failure. The socket functions
were not changed or tested. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks that these calls raise `OS.SysErr`:
`tests/basis/posix_filesys_dir.sml` (`Posix.FileSys.link/directory`,
`link/missing-file`, `symlink/existing-name`, `unlink/missing`,
`rename/missing`, `rmdir/not-empty`, `rmdir/a-file`, `rmdir/missing`,
all "no exception raised" on MLKit) and `tests/basis/posix_error.sml`
(`Posix.Error.badf/close-twice`, `got NONE, expected SOME badf`). The
lines of `tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.FileSys.link/[dm]* | HOST-BUG | link never raises OS.SysErr: the library calls C's link, which returns an int, by auto-conversion, which reads the result as a long, so -1 comes back as 4294967295
native:mlkit@* | Posix.FileSys.[su]*link/[em]* | HOST-BUG | symlink and unlink never raise OS.SysErr: the library calls the C functions, which return an int, by auto-conversion, which reads the result as a long, so -1 comes back as 4294967295
native:mlkit@* | Posix.FileSys.r[em]*/[amn]* | HOST-BUG | rename and rmdir never raise OS.SysErr: the library calls the C functions, which return an int, by auto-conversion, which reads the result as a long, so -1 comes back as 4294967295
native:mlkit@* | Posix.Error.badf/close-twice | HOST-BUG | Posix.IO.close never raises OS.SysErr: the library calls C's close, which returns an int, by auto-conversion, which reads the result as a long, so -1 comes back as 4294967295
```

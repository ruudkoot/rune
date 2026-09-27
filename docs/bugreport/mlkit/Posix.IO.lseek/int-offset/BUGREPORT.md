# MLKit 4.7.23: `Posix.IO.lseek` of a pipe returns 2147483647 instead of raising `OS.SysErr`, and an offset of 2^30 or more goes wrong

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/Posix.c` and `basis/Posix.sml` as
the tag `v4.7.23`, byte for byte, so the code below is unchanged there;
`master` was not built.

## Summary

* **The trigger:** `Posix.IO.lseek (fd, off, wh)` where the seek fails (a
  pipe) or where `off`, or the offset it leads to, is 2^30 or more.
* **What goes wrong:** the C function of the runtime, `sml_lseek`, takes
  and returns C `int`s where the ML side passes and expects 64-bit ML
  integers. A failing seek comes back as 2147483647 instead of -1, so
  `lseek` of a pipe returns 2147483647; an offset of 2^30 or more is
  truncated to 32 bits: `lseek (fd, 1073741824, SEEK_SET)` returns
  2147483647 (the seek failed), and `lseek (fd, 3000000000, SEEK_SET)`
  moves to 852516352 and returns that.
* **Required behaviour:** the
  [`POSIX_IO` specification](https://smlfamily.github.io/Basis/posix-io.html):
  "`lseek (fd, off, wh)` sets the file offset for the open file descriptor
  fd to off if wh is SEEK_SET; ..." and returns the resulting offset, a
  `Position.int` (63 bits in MLKit); a failing call raises `OS.SysErr` as
  for all of `Posix` ("Many functions in the Posix structure can raise
  OS.SysErr", [`POSIX`](https://smlfamily.github.io/Basis/posix.html)).
  POSIX `lseek` on a pipe fails with `ESPIPE`.

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
(* lseek on a pipe must raise OS.SysErr (ESPIPE); on a file it returns
   the offset it moved to. *)
structure FS = Posix.FileSys
structure IO = Posix.IO
fun show f = (Position.toString (f ())) handle OS.SysErr (m, _) => "raised SysErr \"" ^ m ^ "\""
val {infd, outfd} = IO.pipe ()
val () = print ("lseek of a pipe: " ^ show (fn () => IO.lseek (infd, 0, IO.SEEK_SET)) ^ "\n")
val fd = FS.createf ("file.bin", FS.O_RDWR, FS.O.flags [], FS.S.flags [FS.S.irusr, FS.S.iwusr])
val () = List.app (fn p => print ("lseek of a file to " ^ Position.toString p ^ ": "
                                   ^ show (fn () => IO.lseek (fd, p, IO.SEEK_SET)) ^ "\n"))
                  [1000, 1073741823, 1073741824, 3000000000]
val () = (IO.close fd; FS.unlink "file.bin")
```

```
$ mlkit -o bug bug.mlb && ./bug
lseek of a pipe: 2147483647
lseek of a file to 1000: 1000
lseek of a file to 1073741823: 1073741823
lseek of a file to 1073741824: 2147483647
lseek of a file to 3000000000: 852516352
```

Expected: `raised SysErr "Illegal seek"`, then `1000`, `1073741823`,
`1073741824` and `3000000000`.

## The cause

`basis/Posix.sml` (lines 856-865) passes ML integers and reads an ML
integer back:

```sml
          val r = prim("sml_lseek", (fd, Position.toInt p, k)) : int
        in if r = ~1 then raiseSys "lseek" NONE "" else Position.toInt r
```

but `sml_lseek` in `src/Runtime/Posix.c` (lines 386-403) is declared with
`int`s:

```c
int
sml_lseek (int fd, int p, int w)
{
  int r;
  switch (convertIntToC(w))
  {
    case 0:
      r = lseek(convertIntToC(fd), convertIntToC(p), SEEK_SET);
  ...
  return convertIntToML(r);
}
```

The tagged ML integer `2k+1` arrives in a 64-bit register, of which the
`int` parameter keeps the low 32 bits, so only offsets below 2^30 survive
`convertIntToC(p)`; 1073741824 (tagged `0x80000001`) becomes -1073741824
and the seek fails with `EINVAL`, and 3000000000 becomes 852516352. The
result is also an `int`: `convertIntToML(-1)` is the `int` -1, which comes
back to the ML code in `%eax` with the upper half of `%rax` zero, that is
as the ML integer 2147483647; it is not `~1`, and no exception is raised.

## The fix

Use 64-bit types throughout:

```diff
--- a/src/Runtime/Posix.c
+++ b/src/Runtime/Posix.c
@@ -383,10 +383,10 @@
-int
-sml_lseek (int fd, int p, int w)
+long
+sml_lseek (long fd, long p, long w)
 {
-  int r;
+  off_t r;
   switch (convertIntToC(w))
   {
     case 0:
```

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with this change, in a copy of the installed
`lib/mlkit` (together with the changes proposed in the other reports of
this series, which touch other functions): `bug.sml` then prints
`raised SysErr "Illegal seek"`, `1000`, `1073741823`, `1073741824` and
`3000000000`. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks which error `lseek` of a pipe reports
(`tests/basis/posix_error.sml`, `Posix.Error.spipe/lseek-on-pipe`); on
MLKit it raises nothing, `got NONE, expected SOME spipe`. (Rune's
`tests/basis/posix_io.sml`, which has more checks of `lseek`, does not
build with MLKit, which lacks `Posix.IO.fsync` and `FLock`.) The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.Error.spipe/lseek-on-pipe | HOST-BUG | lseek of a pipe returns 2147483647 instead of raising OS.SysErr: the runtime's sml_lseek takes and returns C ints, so -1 comes back as 2^31-1 (and an offset of 2^30 or more is cut to 32 bits)
```

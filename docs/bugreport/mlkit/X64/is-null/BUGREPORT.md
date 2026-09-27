# MLKit 4.7.23: the X64 backend's `__is_null` never finds a NULL pointer, so `Posix.ProcEnv.ttyname` returns NULL as a string

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Compiler/Backend/X64/CodeGenX64.sml` and
`CodeGenUtilX64.sml` as the tag `v4.7.23` (the whole `src/Compiler/Backend`
directory is identical), so the code below is unchanged there; `master`
was not built.

## Summary

* **The trigger:** the primitive `__is_null`, with which MLKit's Basis
  Library tests whether a C function returned `NULL`, in a program built
  with garbage collection (the default, where values are tagged).
* **What goes wrong:** the X64 backend compares the pointer with the
  address of a boxed constant 0, not with 0, so `__is_null` is false for
  `NULL`. Every function of the library that relies on it takes a `NULL`
  for a string and goes on with it. `Posix.ProcEnv.ttyname` of a
  descriptor that is not a terminal returns that `NULL` as its result
  instead of raising `OS.SysErr`, and the program crashes when it looks
  at the string.
* **Required behaviour:** the
  [`POSIX_PROC_ENV` specification](https://smlfamily.github.io/Basis/posix-proc-env.html):
  `ttyname fd` "produces a string that represents the pathname of the
  terminal associated with file descriptor fd. It raises OS.SysErr if fd
  does not denote a valid terminal device." With `-no_gc` (untagged
  values) the same program does raise it.

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

`bug.sml` applies `__is_null` to the result of the runtime's `sml_null`
(`src/Runtime/Posix.c`, which returns `NULL`), then asks `ttyname` for the
name of `/dev/null`:

```sml
(* __is_null is the primitive with which MLKit's Basis Library tests
   whether a C function returned NULL; sml_null is the function of MLKit's
   runtime that returns NULL. *)
fun isNull (s : string) : bool = prim ("__is_null", s)
fun null () : string = prim ("sml_null", ())
val () = print ("isNull (null ()) = " ^ Bool.toString (isNull (null ())) ^ "\n")

(* What it does to the Basis Library: ttyname of a descriptor that is not
   a terminal must raise OS.SysErr. *)
val fd = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
val r = (ignore (Posix.ProcEnv.ttyname fd); "returned")
        handle OS.SysErr (m, _) => "raised SysErr \"" ^ m ^ "\""
val () = print ("Posix.ProcEnv.ttyname of /dev/null: " ^ r ^ "\n")
val () = print ("its size: ")
val () = print (Int.toString (size (Posix.ProcEnv.ttyname fd)) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
isNull (null ()) = false
Posix.ProcEnv.ttyname of /dev/null: returned
its size: Segmentation fault
```

With `-no_gc` the program behaves as it should (the last exception is the
program's own, uncaught):

```
$ mlkit -no_gc -o bug bug.mlb && ./bug
isNull (null ()) = true
Posix.ProcEnv.ttyname of /dev/null: raised SysErr "Inappropriate ioctl for device"
its size: uncaught exception SysErr Inappropriate ioctl for device
```

The code of `isNull` (built with `--no_delete_target_files`):

```
F.isNull2_i7frh8kBrRcehb7b3qMCeb:
	leaq -8(%rsp),%rsp
	movq D.BoxedNumLab1_ceBhNqUre38YVfr0rEcA3A@GOTPCREL(%rip),%r11
	cmpl %r11d,%eax
	movq $1,%rdi
	movq $3,%r11
	cmoveq %r11,%rdi
	leaq 8(%rsp),%rsp
	ret
...
D.BoxedNumLab1_ceBhNqUre38YVfr0rEcA3A:
	.quad 0X80066
	.quad 0
```

`%eax` holds the string pointer; it is compared with the low 32 bits of
the address of a boxed 0.

## The cause

`src/Compiler/Backend/X64/CodeGenX64.sml`, line 1073, compiles `Is_null`
as a comparison of the argument with an integer constant 0 of precision
32:

```sml
                            | Is_null => cmpi_kill_tmp01_cmov {box=false,quad=false} I.cmoveq
                                                              (x, SS.INTEGER_ATY{value=IntInf.fromInt 0,
                                                                                 precision=32},d,fsz,C)
```

With tagged values, integers of precision 32 are boxed (`boxedNum`,
`src/Compiler/Backend/CodeGenUtil.sml` line 244), so `load_aty` loads the
constant with `move_num_boxed`: the address of a boxed 0 in static data
(`D.BoxedNumLab...` above). `cmpi_kill_tmp01_cmov` with `box=false` then
compares that address, not the 0 in it, with the pointer, and only in 32
bits (`quad=false`). The ARM64 backend compiles the same primitive as a
pointer comparison with 0 (`src/Compiler/Backend/Arm64/CodeGenArm64.sml`,
line 1485: `primitiveInto fsz {name = Equal_ptr,args = [a,integer 0],res = res}`).

In the Basis Library, `__is_null` guards `Posix.ProcEnv.ttyname`,
`getlogin` and `ctermid` (`basis/Posix.sml`), `OS.errorName` for an
unknown error number (`basis/FileSys.sml`), `NetHostDB.getHostName` and
`NetHostDB.toString` (`basis/NetHostDB.sml`), `Socket.Ctl.getPeerName` and
`getSockName` (`basis/Socket.sml`) and `Dynlib` (`basis/Dynlib.sml`).

## The fix

Compare the pointer with 0 in 64 bits, as an immediate. For instance, a
function next to `cmpi_kill_tmp01_cmov` in `CodeGenUtilX64.sml`, built
like it:

```sml
      fun is_null (x,d,fsz,C) =
        let val (x_reg,x_C) = resolve_arg_aty(x,treg0,fsz)
            val (d_reg,C') = resolve_aty_def(d,treg0,fsz,C)
        in x_C(I.cmpq(I "0", R x_reg) ::
               G.move_num(i2s BI.ml_false, R d_reg) $
               G.move_num(i2s BI.ml_true, R treg1) $
               I.cmoveq(R treg1, R d_reg) :: C')
        end
```

and in `CodeGenX64.sml`:

```diff
-                            | Is_null => cmpi_kill_tmp01_cmov {box=false,quad=false} I.cmoveq
-                                                              (x, SS.INTEGER_ATY{value=IntInf.fromInt 0,
-                                                                                 precision=32},d,fsz,C)
+                            | Is_null => is_null (x,d,fsz,C)
```

The moves after the comparison are those of `cmpi_kill_tmp01_cmov`, which
leave the flags alone. This has not been tested: an attempt to build
MLKit from source on this machine with MLton did not complete (the MLton
process was killed), so no compiler with the change was run.

## Relation to Rune

Rune's Basis Library suite checks which error `ttyname` of standard input,
`/dev/null` where the runner runs the tests, reports
(`tests/basis/posix_error.sml`, `Posix.Error.notty/ttyname-of-dev-null`).
On MLKit `ttyname` raises nothing, and the check fails with `got NONE,
expected SOME notty` (the check ignores the string, so it does not
crash). Rune's `tests/basis/posix_procenv.sml`, which does not build with
MLKit (report `X64/push-immediate`), meets the bug as well once it is
built with the constant that stops the assembler worked around: in this
environment, which has no login name (`logname` says "no login name"),
`Posix.ProcEnv.getlogin ()` returns `NULL` as its string instead of
raising `OS.SysErr`, and the check `Posix.ProcEnv.getlogin/user-or-SysErr`
crashes the program (a segmentation fault in `concatStringML`, when
`getpwnam` builds a message with the name). The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.Error.notty/ttyname-of-dev-null | HOST-BUG | compiler bug: the X64 backend compares the pointer of __is_null with the address of a boxed 0, so the library never sees that a C function returned NULL: ttyname of a descriptor that is not a terminal returns NULL as its string instead of raising OS.SysErr
```

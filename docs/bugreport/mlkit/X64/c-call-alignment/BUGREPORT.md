# MLKit 4.7.23: the X64 backend calls a C function with the stack misaligned when one argument goes on the stack, and `Posix.SysDB.getgrnam` crashes

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Compiler/Backend/CodeGenUtil.sml` and
`X64/CodeGenUtilX64.sml` as the tag `v4.7.23` (the whole
`src/Compiler/Backend` directory is identical), so the code below is
unchanged there; `master` was not built.

## Summary

* **The trigger:** a call of a C function with seven arguments, so that
  one of them is passed on the stack. In MLKit's Basis Library these are
  the runtime's `sml_getgrnam` and `sml_getpwnam`, the C side of
  `Posix.SysDB.getgrnam` and `getpwnam` (the record for the result, two
  regions, the context, the name, a buffer size and an exception).
* **What goes wrong:** the backend pushes the one stack argument and calls
  the function without padding the stack, so the function starts with the
  stack pointer 8 bytes off the 16-byte alignment that the x86-64 System V
  ABI requires at a call. Code that relies on the alignment fails: glibc's
  first look-up in the group or user database (`getgrnam_r`,
  `getpwnam_r`) saves an SSE register with `movaps` to the stack and the
  program dies with a segmentation fault.
* **Required behaviour:** the
  [`POSIX_SYS_DB` specification](https://smlfamily.github.io/Basis/posix-sys-db.html)
  says that `getgrnam` and `getpwnam` "return the group or user database
  entry associated with the given group ID or name, or user ID or name. It
  raises OS.SysErr if there is no group or user with the given ID or
  name." A program must not crash in them.

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
(* The first look-up in the group database: glibc reads /etc/nsswitch.conf
   and runs code that needs the stack aligned as the x86-64 ABI says. *)
val () = print "calling Posix.SysDB.getgrnam\n"
val g = Posix.SysDB.getgrnam "root"
val () = print "returned\n"
```

```
$ mlkit -o bug bug.mlb && ./bug
calling Posix.SysDB.getgrnam
Segmentation fault
```

It does so on every run. Under gdb, with a breakpoint on `sml_getgrnam`:

```
Breakpoint 1, sml_getgrnam (triple=140737488335672, memberListR=0x7fffffffb411, memberR=0x7fffffffb3f1, ctx=0x5555556842a0, nameML=0x5555556829f0, s=2049, exn=140737349110832) at Posix.c:975
(gdb) p/x $rsp
$1 = 0x7fffffffb2a0
(gdb) frame 1
#1  0x000055555566001d in L_ret_alloc_J5neU6JuKS2yzmZ7gAmnXr ()
(gdb) x/4i $pc-17
   0x55555566000c <L_ret_alloc_J5neU6JuKS2yzmZ7gAmnXr+60>:	mov    0xb8(%rsp),%r8
   0x555555660014 <L_ret_alloc_J5neU6JuKS2yzmZ7gAmnXr+68>:	mov    %rbx,%rcx
   0x555555660017 <L_ret_alloc_J5neU6JuKS2yzmZ7gAmnXr+71>:	push   %rax
   0x555555660018 <L_ret_alloc_J5neU6JuKS2yzmZ7gAmnXr+72>:	call   0x55555566bf20 <sml_getgrnam>
(gdb) continue
Program received signal SIGSEGV, Segmentation fault.
__nss_action_parse (line=line@entry=0x555555688ba0 "files\n") at ./nss/nss_action_parse.c:168
(gdb) x/i $pc
=> 0x7ffff7d51fd8 <__nss_action_parse+72>:	movaps %xmm0,-0xd0(%rbp)
(gdb) p/x $rbp-0xd0
$2 = 0x7fffffffae08
```

On entry to a function the ABI wants `%rsp + 8` to be a multiple of 16;
here `%rsp` itself is (`0x7fffffffb2a0`). Before the `push %rax` the stack
pointer was `0x7fffffffb2b0`, a multiple of 16: one push of 8 bytes and
the call's return address make it misaligned, and `movaps` faults on the
address `0x7fffffffae08` that follows from it.

`ok-getgrgid.sml` makes the same first look-up through `getgrgid`, whose C
function `sml_getgrgid` takes eight arguments, two on the stack:

```sml
(* The same first look-up through getgrgid, whose C function takes eight
   arguments, two of them on the stack. *)
val () = print "calling Posix.SysDB.getgrgid\n"
val g = (ignore (Posix.SysDB.getgrgid (Posix.ProcEnv.wordToGid 0w0)); "returned")
        handle e => "raised " ^ exnName e
val () = print (g ^ "\n")
```

```
$ ./ok
calling Posix.SysDB.getgrgid
raised Overflow
```

It does not crash: two pushes keep the alignment (under gdb, `%rsp` is
`0x7fffffffb168` on entry to `sml_getgrgid`, 8 more than a multiple of
16). The `Overflow` is another bug, of MLKit's runtime (`sml_getgrgid`
returns the result of `getgrgid_r` untagged; see the report
`Posix.SysDB.getpwuid/untagged-results`).

## The cause

`compile_c_call_prim` in `src/Compiler/Backend/X64/CodeGenUtilX64.sml`
(lines 135-153) moves the first six arguments into registers, pushes the
others and calls:

```sml
    fun compile_c_call_prim (name:string, args:SS.Aty list, opt_ret:SS.Aty option, fsz:int, tmp:reg, C) =
        let fun push_arg (aty,fsz,C) = push_aty(aty,tmp,fsz,C)
            val nargs = List.length args
            val args_stack = drop (List.length RI.args_reg_ccall) args
            val nargs_stack = List.length args_stack
            ...
        in shuffle_args fsz mv args
            (push_args push_arg fsz args_stack
              (maybe_align nargs_stack
                (fn C => callc_static_or_dynamic (name, nargs, NameLab dynlinklab, C))
                  (store_ret(opt_ret,C))))
        end
```

and `maybe_align` (`src/Compiler/Backend/CodeGenUtil.sml`, lines 735-738)
only pops the pushed arguments after the call; it does not align anything:

```sml
  (* better alignment technique that allows for arguments on the stack *)
  fun maybe_align nargs F C =
      if nargs = 0 then F C
      else F (G.add(I(I.i2s(8*nargs)),RI.spreg) C)
```

A call without stack arguments is aligned when the stack pointer is a
multiple of 16 in the ML code that makes it, as it was at both calls
above. An odd number of pushed arguments then leaves it misaligned at the
call.

## The fix

Pad the stack with one word before the arguments when their number is
odd, and pop it with them:

```diff
--- a/src/Compiler/Backend/X64/CodeGenUtilX64.sml
+++ b/src/Compiler/Backend/X64/CodeGenUtilX64.sml
@@ -140,6 +140,7 @@
             val args_stack = drop (List.length RI.args_reg_ccall) args
             val nargs_stack = List.length args_stack
+            val pad = nargs_stack mod 2
             val args = ListPair.zip (args, RI.args_reg_ccall)
             val args = map (fn (x,y) => (x,(),y)) args
             fun store_ret (SOME d,C) = move_reg_into_aty(rax,d,fsz,C)
@@ -150,10 +151,11 @@
             fun mv (aty,_,r,sz_ff,C) = load_aty(aty,r,sz_ff,C)
         in shuffle_args fsz mv args
-            (push_args push_arg fsz args_stack
-              (maybe_align nargs_stack
+            ((if pad = 1 then G.sub (I "8", RI.spreg) else (fn C => C))
+             (push_args push_arg (fsz + pad) args_stack
+              (maybe_align (nargs_stack + pad)
                 (fn C => callc_static_or_dynamic (name, nargs, NameLab dynlinklab, C))
-                  (store_ret(opt_ret,C))))
+                  (store_ret(opt_ret,C)))))
         end
```

(`push_args` takes the frame size so that `push_aty` finds the arguments
that are in the frame; the padding word adds one to it.) This keeps the
assumption that the stack pointer is a multiple of 16 in the ML code at a
call, which the calls without stack arguments already make. It has not
been tested: an attempt to build MLKit from source on this machine with
MLton did not complete (the MLton process was killed), so no compiler with
the change was run.

## Relation to Rune

The first check of Rune's `tests/basis/posix_sysdb.sml` is
`Posix.SysDB.getpwnam "root"`, whose C function `sml_getpwnam` also takes
seven arguments. The test program crashes there, in `__nss_action_parse`
called from `getpwnam_r` called from `sml_getpwnam`, before its buffered
output is written, so the run reports `@load/posix_sysdb` ("did not
load"). The checks after it would meet the bug of the report
`Posix.SysDB.getpwuid/untagged-results`. The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | @load/posix_sysdb | HOST-BUG | the program crashes in its first check, getpwnam "root": the X64 backend calls a C function of seven arguments (here the runtime's sml_getpwnam) with the stack misaligned, and glibc's first look-up in the user database faults on movaps; the entries of getpwuid, getgrgid and getgrnam are unusable as well (their C functions store ints untagged)
```

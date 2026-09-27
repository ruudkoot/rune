# MLKit 4.7.23: the X64 backend pushes a word constant that does not fit in a 32-bit immediate

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a specification bears on.** The code generator emits an instruction that the assembler rejects, for a valid program.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Compiler/Backend/CodeGenUtil.sml` as the tag
`v4.7.23` (the whole `src/Compiler/Backend` directory is identical), so the
code below is unchanged there; `master` was not built.

## Summary

* **The trigger:** a call that passes a `word` constant between
  `0w1073741824` (`0wx40000000`) and `0w2147483647` (`0wx7FFFFFFF`) as an
  argument that goes on the stack, for instance the third argument of a
  function of three arguments, in a program built with garbage collection
  (the default, where values are tagged).
* **What goes wrong:** the compiler emits `pushq $imm` with the tagged
  value `2w+1` of the constant, which lies between `0x80000001` and
  `0xFFFFFFFF`. `pushq` takes a 32-bit immediate that is sign-extended,
  so the assembler rejects the instruction and the program does not
  build: `Error: invalid instruction suffix for 'push'`.
* **Required behaviour:** the program is valid Standard ML and must
  compile; it prints `773593FF 3`, as it does with `-no_gc`.

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44), GNU assembler 2.42, gcc 13.3.0, running as root.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`, which should print `773593FF 3`:

```sml
(* f takes three arguments; MLKit's X64 backend passes the third on the
   stack. The call below pushes the word constant 0w1999999999 as an
   immediate, which the assembler rejects. Expected output: 773593FF 3 *)
fun f (a : int, b : int, w : word) =
  if a > 100 then f (a - 1, b, w) else Word.toString w ^ " " ^ Int.toString (a + b)
val () = print (f (1, 2, 0w1999999999) ^ "\n")
```

```
$ mlkit -o bug bug.mlb
MLB/RI_GC/bug.sml.s: Assembler messages:
MLB/RI_GC/bug.sml.s:52: Error: invalid instruction suffix for `push'
Compile error: command failed: as --64 -o MLB/RI_GC/bug.sml.o MLB/RI_GC/bug.sml.s
Impossible: Manager.readLinkFiles.error reading file MLB/RI_GC/bug.sml.o.lnk
[[ERR in sub process:
  CRASH]]
Stopping compilation of MLB-file due to error (code 1).
```

The call in `MLB/RI_GC/bug.sml.s` (`0xee6b27ff` is `2 * 1999999999 + 1`):

```
	leaq L_ret_funcall_myMPcur3Xxih2fv8zDqKbb(%rip),%r9
	pushq %r9
	pushq $0xee6b27ff
	pushq %rdx
	jmp F.f2_KAY1IU5o2CjgxqX80vktze@PLT
```

## What triggers it and what does not

`run.sh` builds every program twice, as MLKit builds it by default and
with `-no_gc`, and runs it (`MLKIT=/path/to/mlkit SML_LIB=/path/to/lib/mlkit
sh run.sh`):

```
MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00) [X64 Backend]
bug           default  compile error: invalid instruction suffix for `push'
bug           no_gc    773593FF 3
bug-lowest    default  compile error: invalid instruction suffix for `push'
bug-lowest    no_gc    40000000 3
bug-highest   default  compile error: invalid instruction suffix for `push'
bug-highest   no_gc    7FFFFFFF 3
ok-below      default  3FFFFFFF 3
ok-below      no_gc    3FFFFFFF 3
ok-above      default  80000000 3
ok-above      no_gc    80000000 3
ok-int        default  1999999999 3
ok-int        no_gc    1999999999 3
ok-registers  default  773593FF 1
ok-registers  no_gc    773593FF 1
```

| Program | The constant | Default | `-no_gc` |
|---|---|---|---|
| `bug.sml` | `0w1999999999`, third argument | does not assemble | correct |
| `bug-lowest.sml` | `0w1073741824` (`0wx40000000`) | does not assemble | correct |
| `bug-highest.sml` | `0w2147483647` (`0wx7FFFFFFF`) | does not assemble | correct |
| `ok-below.sml` | `0w1073741823` (`0wx3FFFFFFF`) | correct | correct |
| `ok-above.sml` | `0w2147483648` (`0wx80000000`) | correct | correct |
| `ok-int.sml` | the `int` `1999999999` | correct | correct |
| `ok-registers.sml` | `0w1999999999`, second of two arguments (in registers) | correct | correct |

So it takes a `word` (not an `int`) constant in `[0wx40000000,
0wx7FFFFFFF]`, passed on the stack, with tagged values.

## The cause

`push_aty` in `src/Compiler/Backend/CodeGenUtil.sml` (lines 545-559), which
pushes the arguments that go on the stack, pushes a constant as an
immediate when it thinks the constant fits:

```sml
  fun push_aty (aty,t:reg,fsz,C) =
      let fun default () = load_aty(aty,t,fsz,
                            G.push_ea (R t) C)
      in case aty of
             SS.PHREG_ATY aty_reg => G.push_ea (R aty_reg) C
           | SS.INTEGER_ATY i =>
             if boxedNum (#precision i)
                orelse #value i > 0x3FFFFFFF
                orelse #value i <= ~0x40000000 then default()
             else G.push_ea (I(fmtInt i)) C
           | SS.WORD_ATY w =>
             if boxedNum (#precision w) orelse #value w > 0x7FFFFFFF then default()
             else G.push_ea (I(fmtWord w)) C
           | _ => default()
      end
```

`fmtWord` (line 240) formats `maybeTagIntOrWord w`, which is `2 * value + 1`
for the tagged precisions 31 and 63 (lines 231-236). The bound for an
`INTEGER_ATY` allows for the tag (`0x3FFFFFFF`, whose tagged value is
`0x7FFFFFFF`); the bound for a `WORD_ATY` is that of the untagged value,
`0x7FFFFFFF`, so a word between `0x40000000` and `0x7FFFFFFF` is pushed as
an immediate of `0x80000001` to `0xFFFFFFFF`, which `pushq` cannot encode.

## The fix

Check the value that is pushed, after tagging:

```diff
--- a/src/Compiler/Backend/CodeGenUtil.sml
+++ b/src/Compiler/Backend/CodeGenUtil.sml
@@ -553,7 +553,8 @@
                 orelse #value i <= ~0x40000000 then default()
              else G.push_ea (I(fmtInt i)) C
            | SS.WORD_ATY w =>
-             if boxedNum (#precision w) orelse #value w > 0x7FFFFFFF then default()
+             if boxedNum (#precision w)
+                orelse maybeTagIntOrWord w > 0x7FFFFFFF then default()
              else G.push_ea (I(fmtWord w)) C
            | _ => default()
       end
```

This has not been tested: an attempt to build MLKit from source on this
machine with MLton did not complete (the MLton process was killed), so no
compiler with the change was run.

## Relation to Rune

Rune's Basis Library suite checks that `Posix.ProcEnv.wordToUid` and
`wordToGid` do no validation with the word `0w1999999999`
(`tests/basis/posix_procenv.sml`, `Posix.ProcEnv.wordToUid/no-validation`
and `Posix.ProcEnv.wordToGid/no-validation`). The harness's `T.eq` takes
the label, the expected value and a function, and MLKit passes the
constant on the stack, so the whole test fails to build with MLKit
(`@load/posix_procenv`, "invalid instruction suffix for `push'" at two
lines of the generated `posix_procenv.base.sml.s`). The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | @load/posix_procenv | HOST-BUG | compiler bug: the X64 backend pushes a word constant between 0wx40000000 and 0wx7FFFFFFF that is passed on the stack (here 0w1999999999) as a 32-bit immediate of its tagged value, which the assembler rejects ("invalid instruction suffix for `push'")
```

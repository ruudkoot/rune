# An exception a handler passes on is placed at the end of the handler's rule

Found 2026-11-14, from four failures of rhc's mutants
([hs-mutants-built-race](../hs-mutants-built-race/BUGREPORT.md)), whose
trace named `RuneStreamIOFn.flushOut` for an `OS.SysErr` that a file
operation had raised. Status: not fixed.

## What happens

A handler whose rules do not match the exception raises it again. Where no
other handler takes it, the VM ends with the frames at that raise
(`vm_raise`, `runtime/runtime.c`). The first frame of that trace is wrong:
it has the position of the end of the handler's last rule, and, when that
rule's code was inlined, the name of the function it came from.

`reraise.sml` (beside this file) has `OS.FileSys.rmDir` raise `SysErr` in
`job`, and `protect`'s handler, which matches only `Failed`, pass it on. The
handler's one rule, which never runs, calls `last`, which calls
`TextIO.flushOut`. Compiled by `bin/rune` at haskell98 `80792e82d`:

| Compiled | The trace |
|---|---|
| -O1 (the default) or -O2, register VM | `in RuneStreamIOFn.flushOut at .../lib/basis/streamio_fn.sml:333:104`, `in <toplevel> at reraise.sml:15:22` |
| -O1, stack VM (`bin/rune-stack`, `bin/runevm-stack`) | the same |
| -O0 | `in protect at reraise.sml:13:51`: the `()` of `last ()` |

`streamio_fn.sml:333:104` is the `()` of `flushOut`'s `else`, the last
position of its body. Other rules show the same thing:

| The handler | The first frame |
|---|---|
| `handle Failed why => ignore (other 1)` | `in ignore at .../lib/basis/pervasive.sml:9:16` |
| `handle Failed why => print why` | `in protect` at the `print` |
| `handle Failed why => print why \| e => raise e` | `in protect` at the `raise`: right |
| no handler | `in RuneFileSys.check`, `in RuneFileSys.checkUnit`, `in job`: right |

## Why

`lib/compiler/core/translate.sml:323` translates a handler with the default
rule `Raise (Var x)`, and gives it no position:

```sml
| EHandle (e, rules, _, _) =>
    let val x = MatchComp.freshVar ()
    in Handle (transExp e, x, MatchComp.compileMatch (x, transRules rules, Raise (Var x))) end
```

The defaults that raise `Match` and `Bind` have one (`Mark (sp,
raiseBuiltin exnMatch)`, translate.sml:340, 343, 478 and 514). The lowering
puts a `Mark` down as an `L.At` (`lib/compiler/backend/lower.sml:687`), and
the emitters (`stack.sml`, `regs.sml`) give each instruction the last `At`
before it. The match puts the default after the rules, so the raise takes
the last position of the last rule. At -O1 that rule's calls are inlined,
`flushOut`'s body with them, so the position is in `flushOut`, and the
trace names the function whose code the position is in.

So the fault is the compiler's: both VMs print the positions they are
given, and the Basis raises nothing there.

## How it misled

In rhc's mutants, `HsMutants.protect` was `f () handle Failed why => say
(...)`, and `Sh.say` ends in `TextIO.flushOut`. The trace sent the search to
the standard output's flush. A flush that fails there raises `IO.Io`
(`guarded` wraps the writer's `SysErr`), so a `SysErr` there could not be
explained. The `SysErr` came from a file operation of the job.

## A fix

Give the default rule the handler's position: `EHandle (e, rules, sp, _)`
and `Mark (sp, Raise (Var x))`. The trace would then name the function with
the handler, at the `handle`.

This changes the code of every handler, so it needs the bootstrap's gate
(stage 1 = stage 2, and the bytes that moved).

The test: `reraise.sml`'s trace at -O1, with its first frame `in protect`.

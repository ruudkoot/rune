# An exception a handler passes on is placed at the end of the handler's rule

Found 2026-11-14, from four failures of rhc's mutants
([hs-mutants-built-race](../hs-mutants-built-race/BUGREPORT.md)), whose
trace named `RuneStreamIOFn.flushOut` for an `OS.SysErr` that a file
operation had raised. Status: fixed 2026-11-14 on `hs-l-reraise`
(`3d6d700c9`), as the owner decided; [the fix and its test](#the-fix) are
below. The sections before them record the bug as it was found.

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

## The fix

The default rule now has the handler's position, as Match's and Bind's
defaults have theirs: `EHandle (e, rules, sp, _)` and `Mark (sp, Raise (Var
x))` (`3d6d700c9`). An exception that no rule matches is raised again at
the `handle`, in the function that has the handler. `reraise.sml`'s trace is
now the same at -O0, -O1 and -O2, on both VMs:

```
runevm: uncaught exception SysErr <value>
  in protect at reraise.sml:13:20
  in <toplevel> at reraise.sml:15:22
```

**The test** is `tests/lang/rt.trace_reraise`: the same program, raising
`Fail` where `reraise.sml` has the file's `SysErr`. It runs at -O1, and at
-O0 and -O2 as `rt.trace_reraise_O0` and `rt.trace_reraise_O2` (their
`.cargs`). Each `.stderr` names `protect` at the `handle`, in every way
tests/lang runs. Before the fix the three said `RuneStreamIOFn.flushOut`,
`protect` at the end of the rule, and `RuneStreamIOFn.flushOut` again.

**The bytes.** Every handler gains a position, so the bytecode moves:

- **The compiler is its own fixed point**, in both bytecodes. Register
  bytecode: stage 1 = stage 2, 5,498,854 bytes. Stack bytecode:
  `bin/rune.stack.rbc` is what stage 2 makes with `--target=stack`, and what
  it makes of itself on `runevm-stack`, 3,613,841 bytes.
- **The compiler's own bytes:** register 5,495,180 → 5,498,860 (+3,680),
  both made in trees whose version string has the same length. Stack
  3,610,223 → 3,613,841. The version in the second is 6 characters
  shorter (a commit, not `-dirty`), so the stack compiler grew by 3,624.
- **h98-ref's sources at the six modes**, compiled without and with the fix:

  | Mode | Without | With |
  |---|---:|---:|
  | -O1 | 5,406,126 | 5,409,737 |
  | stack | 3,559,027 | 3,562,590 |
  | -O0 | 4,780,234 | 4,781,270 |
  | -O2 | 5,474,444 | 5,478,056 |
  | stack -O0 | 2,842,618 | 2,843,660 |
  | stack -O2 | 3,597,128 | 3,600,691 |

- **The budgets** (`make perf-check`, 48 of 48) all hold, so none is
  re-based. The bootstrap's counts (`budgets/*/bootstrap`, the compiler
  compiling itself) moved:

  | Bytecode | Count | Without | With | Budget |
  |---|---|---:|---:|---:|
  | register | instructions | 2,569,869,927 | 2,570,818,982 (+0.04%) | 2,745,127,138 |
  | register | bytes | 3,067,909,200 | 3,069,380,320 (+0.05%) | 3,186,669,728 |
  | register | objects | 116,449,653 | 116,511,159 (+0.05%) | 120,494,788 |
  | stack | instructions | 4,208,321,349 | 4,210,028,819 (+0.04%) | 4,562,576,478 |
  | stack | bytes | 2,512,332,088 | 2,513,856,992 (+0.06%) | 2,639,747,079 |
  | stack | objects | 94,188,913 | 94,252,343 (+0.07%) | 98,596,817 |

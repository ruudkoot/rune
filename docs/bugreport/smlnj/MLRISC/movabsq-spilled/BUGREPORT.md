# SML/NJ 110.99.9 for amd64: "MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented" when a 64-bit constant goes to a spilled register

## Status: not reported

Found on 2026-10-21, while choosing a hash for Rune's unit cache
([functors-units.md](../../../../plans/functors-units.md), E6): a hash with
63-bit word constants would not compile under the 64-bit release. A search
found no report upstream.

**What is worth sending SML/NJ:** a new issue on smlnj/legacy. `upstream.md`
is the text. No fix is written yet.

## Summary

* **The trigger:**
  - a word constant of 2^30 or more, whose tagged form, 2w + 1, does not
    fit a signed 32-bit immediate;
  - or a `Word64` (or `Int64`) constant of 2^31 or more;
  - given to a loop whose parameter the register allocator spills.
  - The loop of `bug.sml` is enough: `fun go ([], a) = a | go (v :: r, a :
    word) = go (r, a + v)` applied to `0wx40000000`.
* **What goes wrong:** the compiler stops with "MLRisc bug: AMD64MCEmitter:
  MOVABSQ unimplemented" and prints the CPS of the function. `use` raises
  `ExnDuringExecution`; a CM build fails.
* **What does not go wrong:**
  - `0wx3FFFFFFF`, and `Word64` up to `0wx7FFFFFFF`, which fit 32 bits;
  - the same constant where nothing is spilled: a plain `val`, a
    multiplication by it, a call of a small function with it.
* **Required behaviour:** a program that type-checks compiles. A large
  constant is an ordinary value.

## Where it happens

| Build | 0wx3FFFFFFF | 0wx40000000 | 0wx4F1BBCD8C2F5E543 | `Word64` 0wx7FFFFFFF | `Word64` 0wx80000000 | no loop |
|---|---|---|---|---|---|---|
| 110.99.9, 64-bit release, Linux | ok | **crash** | **crash** | ok | **crash** | ok |
| 2026.2, 64-bit, Linux | ok | ok | ok | ok | ok | ok |

Other 64-bit releases were not tried. Linux is Ubuntu 24.04 on WSL2,
x86-64.

```
$ sml bug.sml                    # 110.99.9, 64-bit
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
word 0wx3FFFFFFF (tagged, fits 32 bits):
  result 40000000
word 0wx40000000 (tagged, needs 64 bits):
Error: MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented
...
  FAILS: ExnDuringExecution
word 0wx4F1BBCD8C2F5E543:
Error: MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented
...
  FAILS: ExnDuringExecution
Word64 0wx7FFFFFFF:
  result 80000000
Word64 0wx80000000:
Error: MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented
...
  FAILS: ExnDuringExecution
the same constant, no loop:
  result 4F1BBCD8C2F5E544
```

2026.2 prints a result for every case.

## The cause

Read from the sources of 110.99.9 (smlnj/legacy `f210dfe`; nothing under
`MLRISC/amd64` changes up to `6ed5a0a`). It was not traced in a debugger.

1. **Instruction selection** moves a constant that does not fit 32 bits
   with `MOVABSQ` into a register
   (`MLRISC/amd64/mltree/amd64-gen.sml:210`, `:866`). `gpr` always gives a
   register (`:62`), so this is a `MOVABSQ $imm64, %reg`, which x86-64 has.
2. **The CPS of the failing loop** (printed with the error) is a known
   function of ten parameters. Its closure's variables are passed as
   arguments, and the call passes the constant: `(L)v145(v237,
   (I63t)1073741824, ...)`. Ten parameters do not fit amd64's registers, so
   some are spilled.
3. **The spill rewrite** turns a move into a spilled register into a move
   into its spill slot. For a source that `immed` accepts it does so
   directly (`MLRISC/amd64/ra/amd64SpillInstr.sml:132-136`). `immed`
   accepts `Immed64` (`:36-38`), so `MOVABSQ $imm64, %reg` becomes `MOVABSQ
   $imm64, mem`. x86-64 has no such instruction: a 64-bit immediate can
   only go to a register.
4. **The machine-code emitter** encodes `MOVABSQ` only into a register
   (`MLRISC/amd64/amd64MC.sml:482-496`), and stops on anything else
   (`:497`, `unimplemented "MOVABSQ"`).

`move'` already takes a label that must go to memory through a temporary
register (`amd64-gen.sml:212-217`); the spill rewrite has no such case for
`Immed64`. The likely fix is that `Immed64` takes the spill rewrite's
temporary-register path, as a non-immediate source does (`:137-144`). That
is not written or tested.

**2026.2** keeps the same MLRISC code in its library
(`libraries/MLRISC/amd64/ra/amd64SpillInstr.sml:36-38`,
`libraries/MLRISC/amd64/amd64MC.sml:497`, smlnj/smlnj `6c47622`). But its
compiler makes code through LLVM and no longer uses MLRISC's amd64 back
end, so it compiles every case.

## Files

* `bug.sml`: six cases, each compiled on its own by `use`, so that one
  failure does not end the run. Run with `sml bug.sml`.
* `upstream.md`: the draft issue.

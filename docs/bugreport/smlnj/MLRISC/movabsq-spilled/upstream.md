# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues (new issue). Not posted.

---

**Title:** amd64: "MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented" when a 64-bit constant is passed to a spilled loop parameter

**Version:** 110.99.9, 64-bit, Linux (x86-64). 2026.2 compiles the same
programs.

**Description:** the compiler stops when a word constant of 2^30 or more (or
an `Int64`/`Word64` constant of 2^31 or more) is passed to a loop parameter
that the register allocator spills.

```sml
fun go ([], a) = a | go (v :: r, a : word) = go (r, a + v)
val () = print (Word.toString (go ([0w1], 0wx40000000)) ^ "\n")
```

```
$ sml t.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
Error: MLRisc bug: AMD64MCEmitter: MOVABSQ unimplemented
```

`0wx3FFFFFFF` compiles and prints `40000000`. `Word64` fails the same way
from `0wx80000000`. The same constants compile where nothing is spilled.

**Cause** (from reading the sources; not traced):
* `amd64-gen.sml` moves a constant that does not fit 32 bits into a
  register with `MOVABSQ`.
* The loop above is a known function of ten parameters in CPS, so some are
  spilled.
* `amd64SpillInstr.sml` rewrites a move of an immediate into a spilled
  register as a move into the spill slot (lines 132-136), and its `immed`
  accepts `Immed64` (lines 36-38). That makes `MOVABSQ $imm64, mem`, which
  x86-64 does not have.
* `amd64MC.sml` encodes `MOVABSQ` only into a register, and reports anything
  else as unimplemented (line 497).

Taking `Immed64` through the spill rewrite's temporary register, as for a
non-immediate source, should fix it; we have not tried that.

A program with six cases (thresholds and controls) is attached as `bug.sml`.

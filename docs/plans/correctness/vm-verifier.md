# Brief: a verifier of the register code in the VM

**What this is.** A brief for a later roadmap, of the VM: what the
compiler's check of the register code (`RegVerify`, the linting
roadmap's M8; [ir.md](../../ir.md), *The register target*) found that
belongs to the VM, and what such a roadmap can start from. The linting
roadmap ([linting.md](linting.md), D8 C, D11) leaves memory safety for
an untrusted `.rbc` to the VM, and hands it these.

## Why the VM needs one

**The loader checks the encoding, and a little of the representations**
(`runtime/register/isa_regs.c`, `validate_program_from`):
- the opcodes, each operand against its kind's range, and the jumps, which
  stay in their function;
- a `SWITCH`'s table, and `CALLK`'s count against the callee's registers;
- the rep a write gets where the instruction alone fixes it: `INT`,
  `CONTAG`, `UNIT`, `CON0`, the allocations, `SELF`, `EXNCON`, `CONST` by
  its constant's kind, and `PRIM` by the primitive's result (`prim_result`).

**Tier 2 of the JIT trusts the meta's representations** without tests
([linting.md](linting.md), *The VM's loader, and what tier 2 trusts*):
- an int register's arithmetic;
- a `ptr` register dereferenced for `SELECT`, `FIELD` and `CALL` with no
  test of its kind or length.

So a wrong representation, a tuple of another length, or a tag never tested
reads outside an object or calls the wrong function, in silence. `CALL`'s
function index is tested whatever the register (C-call, below): it can stop
there, and cannot jump anywhere.

## E7's corruptions, against the loader

The compiler's check is tried on eleven corruptions of the code of
`tests/register/regverify.sml`, which its switch makes
(`RUNE_REGVERIFY_INJECT=KIND`; `register/@regverify-*` of the tests). Each
is refused by the check. Here is what the VM makes of each, compiled with
the check off (`RUNE_REGVERIFY=0`):

| Corruption | Interpreter and tier 1 | Tier 2 (`--jit=all --jit-tier=2`) |
|---|---|---|
| `rep-write`: an `INT` into an int register made `CON0` | refused by the loader | refused by the loader |
| `rep-read`: `int_add` of a `ptr` register | wrong result (an uncaught `Subscript`) | the same |
| `unset`: a register read before it is set | runs, right output | runs, right output |
| `noresult`: a `CALLK`'s `RESULT` dropped | wrong result | the same |
| `arity`: a `CALLK` given one argument more | runs, right output | runs, right output |
| `catch`: a handler's `CATCH` dropped | runs, right output | runs, right output |
| `switch`: a `SWITCH`'s first `JUMP` dropped | fatal error: constructor field 2 out of range | **segmentation fault** |
| `env`: `ENV` past the closure's slots | fatal error | fatal error |
| `pop`: a `POPHANDLER` dropped | runs, right output | runs, right output |
| `image`: a `PRIMPUSH` made `PRIM` | runs, right output | runs, right output |
| `closure`: a `CLOSURE` of a function of two parameters | runs, right output | runs, right output |

The loader catches one of the eleven. "Runs, right output" means only
that this program takes no path the corruption matters on.

**The segfault, reproduced:**

```
RUNE_REGVERIFY=0 RUNE_REGVERIFY_INJECT=switch bin/rune tests/register/regverify.sml -o switch.rbc
bin/runevm switch.rbc                          # fatal error at pc ... in area: constructor field 2 out of range
bin/runevm --jit=all --jit-tier=2 switch.rbc   # Segmentation fault
```

The table of `area`'s `SWITCH` is short by its first `JUMP`, so the
`SWITCH` takes the instruction after the table for the last entry.
Each tag then goes to another constructor's block. The interpreter tests the
field's index and stops; tier 2 trusts the register's representation and
reads past the object.

## What tier 2 loses by trusting less

E7b measured three variants of tier 2 on 25 benchmarks
([linting.md](linting.md), E7b). It used the patch
`E7b-shapes.patch` (`-DRUNE_JIT_TRUST_LESS` and its parts) of the linting
campaign's prototypes; the outputs were the same as the stock VM's.

| Variant | Instructions, median (range) | Cycles, median |
|---|---|---:|
| C: the kind, length and function-index tests kept on every `ptr` and `con` register | +15.1% (0.1 … 41.7) | +12.2% |
| C-kind: the kind test only | +10.5% (0.1 … 33.7) | +6.3% |
| C-call: `CALL`'s test of the function index only | +0.06% (0 … 2.7) | about 0 |

- **C-call has landed** (`1488435c1`, the next section). It closes "a wrong
  rep sends control anywhere", for next to nothing. Measured again on the
  merged tree: a median of +0.06% of instructions (-0.07 to +2.7) on 24
  benchmarks at tier 2, every output the same. Cycles are too noisy on
  programs this short to say more.
- **Under C the segfault above becomes a fatal error.**

## C-call, and what `--checked` does not cover

**The test.** `CALL` reads the function's number from the closure's field 0
and indexes the table of calls with it, to find the address it jumps to.
`closure_function` (`runtime/register/jit/emit.c`) tests that number against
the count of functions. It used to skip the test where `ms_trusts` said the
register was a `ptr`, so that under a wrong representation a value of the
program's own picked where tier 2 read an address from.

**Why it landed before this roadmap** ([linting.md](linting.md), D8). A plain
`rune` compile runs at level 0 and `RegVerify` at level 1, so the code users
run through tier 2 is not verified, and a compiler's bug there would have
been a jump anywhere rather than a fatal error.

**What it closes, and what not.** `CALL` can only reach a real function's
entry, and a number out of range stops with "bad function index":
`register/@call-index`, a tuple called as a function, segfaulted before. That
is not memory safety:
- a wrong object whose field 0 happens to be in range calls a real function,
  the wrong one;
- `SELECT` and `FIELD` can still read past an object, so the segfault above
  stays, which only C makes a fatal error.

**`--checked` is another thing.** It tests the constructor's tag in `DECON`
and `FIELD` (`checked_tag`, `emit.c`), for testing the compiler, and
`check-levels` runs under it, the register bytecode at tier 2 too. It leaves
what tier 2 trusts alone: `ms_trusts` reads only the function's
representations, which `compile.c` sets at tier 2 whatever `--checked` says.
So under `--checked` a `ptr` register still skips the kind test, the length
test and `CALL`'s function index.
- **C-call is not behind it:** the test is there for code that runs without
  `--checked`, and it costs next to nothing, so it is always on.
- **`--checked` could make `ms_trusts` answer 0,** so that a test run tests
  kinds, lengths and function indices at tier 2, and a wrong representation
  stops with a fatal error. Those runs would no longer exercise the trusted
  paths users run, so tier 2 would have to run both ways. `RegVerify`
  already checks the representations in every test compile, at level 2, so
  this is left to this roadmap.

## What a verifier in the VM could be made of

**The instruction set's description says what a check needs**
(`src/isa/regs.sml`; [bytecode.md](../../bytecode.md), *The register
bytecode*). `runeisa` writes it today into the compiler's `RegCodes`
(`lib/compiler/backend/regcodes.sml`), and it can write C tables from the
same description:
- `roles`: each register operand read or written, and what it holds;
- `listHolds`: what a list's registers hold;
- `implicit`: what an instruction leaves, takes, pushes, and does with
  closures;
- `order`: `RESULT` after a call, a `SWITCH`'s table, `CATCH` at a handler;
- `flow`, `raises`, `handlers` (the VM has these already);
- `imageOnly` and `imagePrims`.

The primitives' types are read whole (`Isa.primType`; `PrimTys`,
`Prims.repsOf`). The loader's `prim_result` is still read from the type's
string, and the parsed type types the results of 20 more primitives
(`isagen.sml`, `loaderResult`).

**What the `.rbc` lacks.** `RegVerify` takes from the compiler what a
program's file does not carry:
- each function's result;
- what its closures' slots hold;
- what each global holds.

A unit's file carries them (version 3), but the `.rbc` does not (linting
D9). A verifier in the VM must either be given them in the file (a new
section) or derive them. Deriving them gives only a lower bound: a global
whose only store is a placeholder, or a branch the optimiser left that no
run takes, made E7's prototype refuse correct code (linting E3, and
`D-followup.md`).

**What no such verifier gives without types.** 12-33% of the writes into
typed registers are downcasts that only ML's types justify: a field read
from the heap, a polymorphic function's result (linting E7). A verifier of
representations finds the compiler's mistakes; it does not make an
untrusted `.rbc` safe for tier 2. That needs:
- tier 2 to trust less (C, C-kind);
- or types, or shapes of fields, in the file (linting D8 B).

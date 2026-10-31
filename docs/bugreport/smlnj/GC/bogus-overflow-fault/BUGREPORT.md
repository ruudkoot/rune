# SML/NJ 110.99.9: a deterministic program stops now and then with "bogus overflow fault" (for 64 bits never with the addresses fixed; for 32 bits with them too)

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a
specification bears on.** `tests/lib/unicode/normalize_props.sml`, ten
properties of `lib/unicode`'s `Normalize` drawn by `lib/test/property` from
fixed seeds, passes on every run of MLton, Poly/ML, MLKit, SML/NJ 2026.2,
SML/NJ 110.99.9 for 32 bits and Rune. On SML/NJ 110.99.9 for 64 bits it
stops now and then, in a different property each time, with

```
/home/.../bin/sml: Fatal error -- bogus overflow fault: pc = 0x7ac070450659, sig = 11
```

**A correction (2026-10-27): the 32-bit build has it too.** That the 32-bit
build passes holds for these two tests only. Rune's compiler built by SML/NJ
110.99.9 for 32 bits stops with the same message, compiling the Basis suite's
`tests/basis/word.sml` in `make check-cross`, and there fixing the addresses
does not make it go away
([On 32 bits](#on-32-bits-runes-compiler-compiling-crossbasis-word)).

## Status: not reduced, not reported upstream

Found on 2026-10-18 (docs/plans/utf8.md, M5), in `make test-lib-hosts`.
Seen on 32 bits on 2026-10-27, in Rune's compiler built by SML/NJ 110.99.9
for 32 bits ([On 32 bits](#on-32-bits-runes-compiler-compiling-crossbasis-word)):
there it does not go away with the addresses fixed, and the fixes of the two
faults below do not cure it.

## What happens

The program is the one `tests/lib/run-hosts.sh` runs as
`unicode.normalize-props`: `sml`, given the files of `lib/random`,
`lib/test/property`, `lib/test/unit` and `lib/unicode` that their MANIFESTs
mark `host yes`, then the test and a file that exits.

- With the kernel's address randomisation, 4 runs of 45 stopped (one of them
  in `make test-lib-hosts`), after two to six of the ten properties had
  passed.
- With it off (`setarch x86_64 -R sml ...`), none of 20 stopped.
- The faulting pc ends in `...0659` in every run: the same instruction,
  wherever it is mapped.

A program whose every input is fixed that fails only for some addresses
points to the collector or to a value read as an address. The 64-bit build
has two known faults of that kind, in `GC/real-corrupted-on-64-bit` (a real
or a `Word64` not saved across a collection) and
`GC/spilled-word64-argument` (a raw `Word64` among the pointers of a record
of arguments). `lib/test/property` draws its cases with `Word64` arithmetic.
Which of them this is, if either, has not been found.

## What it breaks

`tests/lib/unit/core.sml` stops the same way. One of 30 runs with
`@SMLalloc=512k` died at a pc ending in `0659`, and the GitHub-hosted
nightly of 2026-10-20 (run 39394299943) failed `smlnj-legacy unit.core`.
The nightly of 2026-10-19 passed that test, and on the failing run
MLton, SML/NJ 110.99.9 for 32 bits, SML/NJ 2026.2, Poly/ML and MLKit
passed it. The test draws its two properties through `lib/test/property`.

`tests/lib/deviations.txt` has a `HOST-FLAKY` line for
`unicode.normalize-props` and for `unit.core` on `native:smlnj-legacy`,
as it has for `property.shrink`. The library is not changed for it
(AGENTS.md).

## On 32 bits: Rune's compiler, compiling `cross/basis-word`

Found on 2026-10-27 (the linting roadmap's M14, branch `linting-a` at
`13894a8a0`), in `make check-cross`. `bin/rune-smlnj32`, the compiler built by
SML/NJ 110.99.9 for 32 bits, stops compiling the Basis suite's
`tests/basis/word.sml` with

```
/home/.../bin/sml: Fatal error -- bogus overflow fault: pc = 0xf7166649, sig = 11
```

and its bytecode, every time it finishes, is that of the other five builds.
The command is the one the oracle `cross` of `tests/runner/oracles.sml` runs,
from the root of the tree:

```
env RUNEVM_INTINF=sml RUNE_LINT=2 RUNE_TEST_CPUS=1 RUNE_TEST_ROOT=$PWD RUNE_TEST_RUN=$RUN \
  bin/rune-smlnj32 tests/basis/harness.sml tests/basis/fn/numstr.sml tests/basis/fn/word_fn.sml \
    tests/basis/word.sml tests/basis/finish.sml -o $RUN/cross/basis-word.smlnj32.rbc \
  3> $RUN/events.jsonl < /dev/null > /dev/null
```

with `$RUN` a run directory under `tests/out/r` (the runner leaves its
`events.jsonl` open on descriptor 3). `repro-32.sh N [HEAP] [PREFIX...]`, here,
runs it N times from the root of a tree, on another heap or under a prefix
such as `setarch x86_64 -R`, and counts the failures; `gdb-32.cmds` stops `gdb`
at the fault. The other scripts of the counts below (the heaps built from
`git archive`, the bisection, the scans and the rebuilt SML/NJ) are in the
campaign's notes, `~/.cache/claude-rune-drafts/linting/impl/li-a/m14/` on the
machine that found it, and are not kept in the tree.

### Counts

| What | failed |
|---|---|
| `bin/rune-test run cross/basis-word` (also with `-j 1`) | every run |
| the command, as it is | 7 of 10 |
| the command under `setarch x86_64 -R` / `setarch i386 -R` | 7 of 10 / 6 of 10 |
| with `@SMLalloc=` 1k, 128k, 256k, 1024k, 2048k or 8192k | 0 of 10 each |
| with `@SMLalloc=512k` (the default) | 7 of 10 |
| heaps of `13894a8a0` and of `4ef87f458` (`linting` before M14), built from `git archive` | 13 of 20 and 0 of 20 |
| `4ef87f458` with M14's `lib/compiler/util/inttable.sml` / `elab/sourcety.sml` / `elab/astlint.sml` and `sourcety.sml` | 0 / 0 / 20 of 20 |
| that last heap with `RUNE_LINT` 0, 1, 3 | 8, 0, 10 of 10 |
| any of these heaps, run from a copy of the tree elsewhere, 40 sizes of the environment | 0 of 40 |

The heaps of the table were run with `sml @SMLload=HEAP` from the same
directory, with the same environment and paths. Every input is fixed, and
the process makes no system call whose result varies but `getrusage`: the
compiler times its stages (`Pass.used`). The fault depends on where the
collections fall: on the size of the allocation area, on the heap image
(M14 changed only `AstLint`, which at `RUNE_LINT=0` does not run, and the
fault comes before it would) and on the paths and the environment. Unlike on
64 bits, fixing the addresses does not make it go away: under `setarch -R` the
pc is the same in every run, and the run still fails or not.

### What faults

* `strace -f`: `SIGSEGV {si_code=SEGV_MAPERR, si_addr=0x8}` about 74 ms into
  the run, after the sources are read, right after a collection's `munmap`.
  No signal is delivered before it.
* `gdb` (`handle SIGSEGV stop nopass`): the pc is in compiled ML code of the
  heap image, in the code object of `lib/compiler/util/ordmap.sml` (each code
  object ends with its file's name): an escaping function of `OrdMapFn`
  given a map in `%ebp` that is `0`, tested for `E` (`test $0x1,%cl`) and read
  as a `T` node (`mov 0x4(%ecx),%edx`). Its caller is a continuation in the code
  of `lib/compiler/elab/elaborate.sml`, which takes that argument from field 0
  of the record in the callee-save `%ecx`. That record, at `0xf5760004` (the
  first word of a 64K chunk), is all zero: a pointer to memory a collection
  freed and that was mapped again.
* SML/NJ 110.99.9 rebuilt with fixes, to a fixed point for 32 bits
  (`base/system/fixpt -32`, `makeml -32`, `installml -32`), and the compiler
  rebuilt with it:
  - with the `fix.diff` of [GC/real-corrupted-on-64-bit](../real-corrupted-on-64-bit/BUGREPORT.md):
    10 of 20 runs fail, and 7 of 10 under `setarch -R`;
  - with it and the `fix.diff` of [GC/spilled-word64-argument](../spilled-word64-argument/BUGREPORT.md):
    30 of 30 fail, with
    `Fatal error -- bad array tag 0, obj = 0xf5ae0004, desc = (nil)`: the
    collector meets a pointer of the same kind, to a zero object at the start
    of a 64K chunk.

The compiler uses no `Unsafe`, so a pointer to a freed object is SML/NJ's: of
its collector, or of code that keeps a pointer where the collector does not
see it. Which, and in what construct, has not been found. A scan of the heap
image's code for functions whose GC code saves fewer of their virtual
registers than they read, or packs a pointer they dereference into a raw
record, finds none in Rune's code.

The compiler is not changed for it (docs/building.md: it builds unchanged
with every host): a change that moves where the collections fall would only
move the fault.

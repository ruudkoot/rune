# runevm: glibc found the C heap corrupt, once, while the VM ran the compiler

**Not reproduced.** One abort in about 25,000 compiles of the linting roadmap's experiments
(2026-10-25), and none in 1,620 runs since of the same compile, four ways (below). Nothing
in the compiler's SML can corrupt the C heap, so if this is a bug it is the VM's: its C
runtime, or the code its JIT writes. It is recorded here because it is not known not to be
one.

## Status: open, not reproduced

## What happened

* **Where:** E3 of `docs/plans/correctness/linting.md`, round 2b, the good compiler's pass:
  compiles without lint, six at a time pinned to CPUs 9-15, on a machine at a load of 15 to
  30 (other sessions' test suites). The raw record is
  `~/.cache/claude-rune-drafts/linting/results/E3/raw/r2b/good/compile.json`, item
  `stack/mod.functor.functions_trace@O0`, written 2026-10-25 22:57 UTC; agent B's notes are
  in `results/E3/bugs/README.txt`, item 2.
* **The command** (cwd a built snapshot of functors-units `d551f19dd`):

  ```
  bin/runevm --heap-size 67108864 e3work/r2b/good.rbc --lib bin/../lib \
    --target=stack -O0 tests/lang/mod.functor.functions_trace.sml -o OUT
  ```

  * `bin/runevm` is the register VM of `d551f19dd`, built by `make` (`cc -std=c17 -O2`), at
    its default JIT.
  * `good.rbc` is the compiler of `d551f19dd` with the throwaway verifier patch of the
    roadmap's E7 applied, switched off (`RUNE_REGVERIFY` unset), built by `bin/rune`.
  * Environment: `TZ='NST3:30NDT,M3.2.0,M11.1.0'`,
    `GIT_CEILING_DIRECTORIES=/home/ruud/rune/.worktrees`, no `RUNE_LINT`, no `RUNEVM_JIT*`.
  * Limits: `RLIMIT_AS` 6 GiB, `RLIMIT_CPU` 60 s.
* **What it printed:** `malloc(): mismatching next->prev_size (unsorted)`, then the VM
  ended on signal 6 (SIGABRT) after 3.31 s.

  That message is glibc's check of a free chunk's neighbour as `malloc` walks the unsorted
  bin. It means a chunk's header had been overwritten: a write past the end of a block
  `malloc` gave out, or a write into a block already freed.
* The same compile at `-O2` in the same run succeeded, and so did every other compile of
  that program in the campaign.

## What was tried (2026-10-26)

The same compiler and VM, the same command, three at a time on a machine at a load of 10 to
20, with `repro.sh` (here; the campaign's copy is
`~/.cache/claude-rune-drafts/linting/results/heap-abort/`):

| Mode | Runs | Failures | Output |
|---|---:|---:|---|
| `asan`: `bin/runevm-asan` (`-fsanitize=address,undefined`, `-O1`), default JIT | 120 | 0 | all the same bytes |
| `mcheck`: glibc's `libc_malloc_debug.so.0`, `glibc.malloc.check=3`, `perturb=165` | 600 | 0 | all the same bytes |
| `plain`: as the abort ran | 600 | 0 | all the same bytes |
| `nojit`: `--jit=off` | 300 | 0 | all the same bytes |

All four modes give the same output (md5 `7bd4d9b8…`).

At the rate seen (about 1 in 25,000 compiles of all kinds) these runs could easily have
missed it.
* **ASan instruments the C runtime only, not the code the JIT emits.** A wrong write from
  JIT code into memory that `malloc` owns would pass ASan unseen, unless it happened to
  corrupt ASan's own allocator.
* **glibc's checks catch a corrupted chunk** only when `malloc` or `free` next walks it.

## What is known of the VM

* **It is single-threaded.** `runtime/` creates no thread and sets no timer. Its signal
  handlers are `SIGPIPE`, ignored around forks (`sys_posix.c:536-596`), and `SIGINT`, when a
  program asks for it (`:1455-1490`). So the load cannot change what the VM does, only how
  long it takes.
* **What varies from run to run:**
  - the addresses that ASLR gives `mmap`, the C heap and the stack;
  - the environment;
  - the clock, which the compiler reads only to account for time.
* **The likeliest cause** is therefore a memory error whose effect depends on where things
  happen to lie in memory: in the C runtime (the collector, the loader, the primitives), or
  in what the JIT writes or where it writes it. A fault of the machine (WSL2 under memory
  pressure, or a hardware error) cannot be excluded.

## What would find it

* **The same compile many more times** (tens of thousands), with the JIT at each tier
  (`--jit=off`, tier 1, tier 2), under glibc's checks.
* **A run of the whole test suite's compiles under `bin/runevm-asan`.** `make
  test-register-asan` covers `tests/lang` as programs, not the compiler as their compiler.
* **A core file next time.** `ulimit -c unlimited`, with `kernel.core_pattern` set, would
  keep the state of the abort. Once it reproduces, `--jit-only=LO-HI`
  (`docs/plans/jit.md`) narrows which functions the JIT compiles, to bisect a fault of the
  JIT.
* **The compiler's verifier of the register code** (`docs/plans/correctness/linting.md`,
  M8). The program that ran when the VM aborted was the compiler, which is register code
  that Rune compiled. Verifying the compiler's own bytecode would rule out one cause:
  a wrong rep in it that tier 2 trusted.

# Compiler determinism

Whether a compile's counts -- what `runevm --count` prints at exit:
instructions executed, bytes and objects allocated -- are a function of its
inputs, and if not, of what else. This began with the nightly of 2026-11-07
(run 42362880884, master aa4af735d, the first after the build-system
roadmap's merge), whose `port-jit/@boot-compare` failed: the compiler,
compiling itself on the aarch64 VM under qemu, counted 10 instructions more
with `--jit=off` than in every JIT mode, with the same output, bytes and
objects. The JIT was not at fault. As of 2026-11-08; every number below is of
the compiler at aa4af735d compiling itself (`scripts/plan-files.sh
rune.plan`, `--lib` the tree's `lib`), on the native VM unless it says
otherwise.

The short answer: a compile's count is exact given its inputs, the store it
reads, the paths it is given and the environment it runs in, with one
residual of 7 instructions that is not explained yet (*The residual*).
`--no-cache` is not a compile without a store; `RUNE_CACHE` empty is.

## Where counts are compared

* `jit/@boot-compare` (`make check`) and `port-jit/@boot-compare` (the
  nightly; `tests/runner/oracles.sml`, `jitBootCompare`): the compiler
  compiles itself once in each of six JIT modes, and the outputs and the
  counts must be the same.
* The budgets (`tests/runner/budgets.sml`) and the census
  (`tests/runner/censustrace.sml`) hold counts to recorded values.

The budgets and the census already run with `RUNE_CACHE` empty, for the
reason this page gives. The JIT's bootstrap did not, and does
since the branch `nightly-fixes`.

## What a compile reads besides its sources

* **The store.** Since build-system-v2 every compile has one, a plain compile
  too: the directory `--cache-dir` names, else `RUNE_CACHE`, else `.rune` in
  the directory of the nearest `rune.workspace` above the build file or the
  first input (`storeHome` in `src/driver/main.sml`). For anything in the
  checkout that is the checkout's `.rune`, which every test that compiles
  there shares. Besides units it keeps the
  records of the libraries' indexes, which a compile looks a library up in
  before the frozen layer, `lib/cache`, which `make` writes and nothing else
  changes (`LibraryIndex.stores`). `docs/build.md` (*A library's index*):
  "`--no-cache` turns units off, not the index: such a compile reads the
  store's records, and writes none." `RUNE_CACHE` empty is no store: the
  frozen layer alone.
* **The output.** A compile whose `-o` names a file that is there already
  does 18,102 instructions more (32,048 bytes, 1,327 objects) than one that
  writes a new file. Not traced to its cause.
* **Paths.** Their lengths reach the counts, which is why the bootstrap's
  modes run in directories whose names have one length: a directory name
  of three characters, for one, cost 17,880 instructions more than one of
  two. Their contents did not, in what was tried: directories named `n7`,
  `n8`, `m8`, `a8` and `z8` gave one count, and so did stores named `st` and
  `s0`.
* **The environment.** A compile under `env -i` (a `PATH`, `HOME` and
  `RUNE_CACHE` alone) counted 115 instructions more than one in the
  session's environment. Which variables matter was not found; adding one
  of `AAA`, `MMM`, `ZZZ`, `OLDPWD` or `RUNE_X`, or making one 6,000 bytes
  longer, changed nothing.
* **The clock.** The store's code compares times: a file's stat is racily
  clean only 2 seconds before a record's time (`UnitStore.clean`), and a
  record older than an hour has its time set again when a compile takes it
  (`UnitStore.touch`). With no store, shifting the clock the VM sees by a
  minute, an hour, a day either way or a year (a preloaded
  `clock_gettime`) changed nothing. With a store, records made two hours
  older changed nothing either, and were not set again: the hour is for a
  record a compile takes from its own store, which these were not.

## The store, measured

One set, run at once, with the tree, its frozen layer and `bin/rune.rbc`
unchanged throughout (checked), each compile in a directory of its own with
a name of two characters, each store at a path of one length. A store with
records holds the 8 that `bin/rune --basis-index` writes for `lib/basis`,
`lib/unicode`, `lib/json` and `lib/compiler`, as tests in the checkout write
them.

| The compile | Instructions | Bytes | Objects | Runs |
|---|---:|---:|---:|---:|
| no store (`RUNE_CACHE` empty) | 2,540,375,461 | 2,942,043,576 | 111,186,304 | 2 |
| an empty store | 2,540,390,440 | 2,942,064,192 | 111,187,111 | 3 |
| a store with records | 2,540,837,513 | 2,942,414,368 | 111,196,452 | 2 |
| `--no-cache`, an empty store | 2,540,390,454 | 2,942,063,856 | 111,187,104 | 1 |
| `--no-cache`, a store with records | 2,540,837,527 | 2,942,414,032 | 111,196,445 | 1 |

* Runs of one row agree exactly. A compile whose store does not change is
  exact.
* The records cost 447,073 instructions, with `--no-cache` or without: they
  are read either way. Looking in an empty store costs 14,979.
* A plain compile wrote nothing into an empty store, nor into one with
  records.
* A compile slowed down about six times (the native VM under
  `qemu-x86_64`) counted what one at full speed did, against one store at
  one time.

## The failure of 2026-11-07

The nightly's six modes ran side by side, on two CPUs, in a checkout whose
`.rune` the nightly's other tests write into as they go:

| Mode | Instructions | Bytes | Objects |
|---|---:|---:|---:|
| `off` | 5,051,312,006 | 5,279,373,992 | 199,735,547 |
| `all`, `odd`, `baseline`, `opt`, `deopt` | 5,051,311,996 | 5,279,373,992 | 199,735,547 |

On this machine (an aarch64 VM built from the same commit, under qemu; the
checkout's `.rune` as the store; nothing in it written while runs 3 to 7
ran):

| Run | Instructions | Bytes | Objects |
|---|---:|---:|---:|
| 1, aarch64 `off` | 2,540,482,262 | 2,942,150,040 | 111,190,288 |
| 3, aarch64 `off` | 2,540,482,252 | 2,942,150,040 | 111,190,288 |
| 2 and 4, aarch64 `all`; 5 and 7, native `off`; 6, native `all` | 2,540,482,245 | 2,942,149,608 | 111,190,270 |
| no store: aarch64 `off` twice, aarch64 `all`, native `off`, at once | 2,540,471,130 | 2,942,129,120 | 111,189,417 |

With no store all four agreed and wrote the same bytes, and since
`jitBootMode` runs each mode with `RUNE_CACHE` empty, `port-jit/@boot` passes
(13 of 13). But runs 3 to 7 shared a store that did not change, and the two
slow ones still disagreed: the store alone does not explain them.

## The residual

The same compile, with no store, a new output and a two-character directory,
has counted two ways:

| | Instructions | Bytes | Objects |
|---|---:|---:|---:|
| the set above, and one later set | 2,540,375,461 | 2,942,043,576 | 111,186,304 |
| every other set, before, between and after: more than 50 runs | 2,540,375,468 | 2,942,044,008 | 111,186,322 |

Seven instructions, 432 bytes and 18 objects: the bytes and objects by which
the slow aarch64 runs above differed from the rest. A store with records
moved by the same amount (2,540,837,520 against 2,540,837,513). Each value
held for every run of a set, and sets minutes apart differed; the same
command gave each value in different sets. What was ruled out, by holding
everything else and varying one thing:

* the clock (shifted by up to a year either way, above);
* the names of temporary files (`mkstemp` made to give seven fixed names);
* where the heap is (moved by 1 to 513 MB, with address randomization off);
* where the stack begins (the environment grown by 0 to 15 bytes one at a
  time, and by up to 6,000), and address randomization on or off;
* what else is in the directories above the compile's;
* single environment variables, as above;
* the VM's speed (the slowed runs);
* the number of processors: the VM's `sys_processors` reads the affinity
  mask, which does not change.

## Open

* **Where the residual comes from.** A trace (`runevm --trace`) of a run of
  each value, hashed a million lines at a time, would find the first place
  they part; that needs a way to bring each value about, which was not
  found. A start: the primitives that report the state of the machine or of
  the process (times, resource use, the heap's statistics) and who calls
  them in `lib/compiler` and `src/driver`.
* **Whether it is older than build-system-v2**: the same measurements with
  the compiler of 7b910ccb3.
* **What an existing output does**: the 18,102 instructions.
* **Whether a plain compile should read the store's index records.** It
  makes a plain compile's counts rest on the store, which tests change as
  they run, and a store with records costs a plain compile of the
  compiler 447,073 instructions more than none. A decision for the owner.
* **A rule for the tests**: every comparison of counts runs with `RUNE_CACHE`
  empty, in directories of one length, writing new outputs. The budgets, the
  census and the JIT's bootstrap do; nothing holds a new test to it.

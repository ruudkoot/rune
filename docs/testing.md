# Testing

How Rune's tests decide, without a human, that a run was right: the three
oracles the suites use, what a program's input is (more than the words on
its command line), and the rules a harness follows so that two runs it
compares differ only where the code differs. The evidence here was gathered
while the heap-layout roadmap was written, when an instrumented VM had to
report the same counts as the stock one on more than sixty programs and every mismatch
had to be explained.

Neighbouring pages: [building.md](building.md) lists the suites and the
`make` targets that run them; [runtime.md](runtime.md), *The same run
twice*, states what `--count` promises; [performance.md](performance.md)
is the budgets and the timing method; the roadmap
[plans/heap-layout.md](plans/heap-layout.md), *Testing a layout change*,
is what a change to the layout of values or objects has to pass;
*Measuring a collector* below is how a new collector is scored against
today's.

## The three oracles

**The output.** A program under `tests/` runs with `--checked` and its
standard output is compared with its `.expected` sibling; `.args`,
`.vmargs`, `.stdin` and `.exitcode` siblings fix the rest of the run
(`tests/run-tests.sh:6-7,66-74`). This is the ordinary test.

**The counts.** `runevm --count` prints, at exit, the instructions
executed and the bytes and objects allocated (`runtime/runtime.c:285`). The
numbers are exact, and the same on every engine: the suites check that
the two compilers' bytecodes allocate the same bytes and objects
(`scripts/check-register.sh`), that the interpreter and every JIT mode report
identical counts (`scripts/check-jit.sh:62-79`), that the 32-bit and the
big-endian VM agree with this machine's to the byte
(`tests/run-portability.sh:97-111`), that the three Windows VMs do
(`tests/run-windows.sh:184-191`), that native code does (`AGENTS.md`, the
native rule), and that the compiler, `runedoc` and the benchmark programs
stay within their budgets (`tests/perf/*.budget`, `make perf-check`,
`tests/perf/run-perf.sh`). Where cycles and seconds are noisy by percents,
a count is a number that either matches or is a bug.

**Byte-identical artefacts.** `make bootstrap` checks that the compiler
compiled by itself reproduces `bin/rune.rbc` byte for byte, and
`check-cross` that all host builds produce the same bytecode for every
test program (`building.md`, *Bootstrapping*). This rests on the compiler
being deterministic: ordered maps, counter-generated stamps, reals passed
through as text.

The rest of this page is about the second oracle, because it is the one
that is easy to break from outside the VM: a count that differs between
two runs of the same program is either a bug in an engine or a difference
in the input, and the input is larger than it looks.

## What the input is

[runtime.md](runtime.md) says the counts depend on the program and its
input alone, not on the machine, the pointer width, the heap size or the
collector's schedule. What the input includes, measured (a 50,000-object
program, `runevm --jit=off --count`, one thing changed at a time):

1. **The program's name and arguments.** `CommandLine.name` and
   `CommandLine.arguments` are strings on the heap, and a string's payload
   is rounded up to 8 bytes ([runtime.md](runtime.md)): the same program
   reached through a longer path allocates 8 bytes more for every 8
   characters of the path, with the same instructions and objects. The
   harnesses therefore run every program from a directory of its own under
   a fixed name (`scripts/check-jit.sh:65`: `cd "$out/$name"`, then
   `prog.rbc`), and a count taken by hand with the program's full path is
   not comparable with the harness's. The two sides of a comparison need
   paths of the same length, not only the same file name:
   `scripts/check-register.sh` ran its two VMs from directories named
   `stack` and `new`, two characters apart, and every program agreed until
   the directory above them got a name five characters longer and one
   program's name crossed a boundary of that rounding (16 bytes then) on one side alone. The current directory's name is the
   same kind of input for a program that asks for it: MLton's `lexgen`,
   `mlyacc` and `vliw` build the names of their inputs from
   `OS.FileSys.getDir ()`, and `vliw` walks that name a character at a
   time, 66 objects for every character of the checkout's path. Their
   counts were those of one checkout until the runner gave them a relative
   directory (`tests/external/mlton-bench/*.sed`).

2. **The kinds of the three standard streams.** A stream over a regular
   file or `/dev/null` has positions and gets the position closures at its
   first use; a pipe, a socket or a terminal has none
   (`lib/basis/runefile.sml:35-56`, `RuneFile.positions`, which asks
   `fileTell` once). Measured: a pipe on standard input instead of
   `/dev/null` is 17 objects, 408 bytes and 18 instructions fewer; a pipe
   on standard error instead of a file, 17 objects, 408 bytes and 12
   instructions fewer; standard output to a file instead of `/dev/null`,
   18 instructions fewer with the same bytes and objects. So a program run
   from a terminal, or with its output through `tee`, does not count the
   same as in a harness. The harnesses fix all three: standard input from
   `/dev/null` unless the test has a `.stdin` sibling, standard output and
   error to files (`tests/run-tests.sh:69-74`, `scripts/check-register.sh:40-49`,
   `scripts/check-jit.sh:49-65`, `tests/run-windows.sh:88-91`). The
   portability runner lets the VMs inherit its own standard input
   (`tests/run-portability.sh:107-109`), which is fine because every VM in
   the comparison gets the same one; that is the rule: both sides of a
   comparison get the same three streams, whatever they are.

3. **The clock.** It reaches the counts in two ways. Through control: a
   program that slices its work by CPU time does more per slice on a faster
   engine, so MLton's `model-elimination` benchmark allocated 79 GB on the
   stock VM and 76 GB on an instrumented VM four times slower, and printed
   a different search. Through output: a printed elapsed time is a string
   whose length follows the value, so MLton's `tensor` allocated 19 objects
   more on the slower VM. Such a program has no count until the clock is
   taken out of it: for a workload, shim `Timer` with a counter that
   advances a fixed amount per check (the census runs advance
   `checkCPUTimer` by 100 microseconds per call, about one inference of the
   timed run, so the sliced search does the same work everywhere) and keep
   every time out of the output. The basis tests that read the clock
   (`tests/basis/time.sml`, `timer_sig.sml`, `date_fmt.sml`) test
   properties of the values, not the values.

4. **Randomness and the file system.** A seeded generator is part of the
   program (MLton's `psdes-random` counts the same everywhere); entropy
   from the system, the order a directory lists its entries in, and the
   contents of a file the previous run wrote are input. A test that needs
   such a thing carries it (`.stdin`, `.args`) or makes it in a fresh
   directory. That a file exists is input too. The compiler refuses an
   output that is one of its sources, and asks by comparing the output's
   `OS.FileSys.fileId` with every source's (`src/driver/main.sml`): where
   the output is not there yet each comparison raises and is handled, one
   object, 32 bytes and four instructions more than where it is. The
   compiler compiling its own 50 files into a new file therefore counts 50
   objects, 1,600 bytes and 200 instructions more than into the file its
   last run left. A harness that compares two runs of the compiler removes
   the output before each (`scripts/census.sh`, `tools/heapsim/validate.sh`).

What was measured and did **not** matter: address-space randomisation,
the environment (an empty one gives the same numbers), whether the VM was
named by an absolute or a relative path, whether an output file already
existed, `--heap-size` (allocation does not depend on collection), and the
JIT tier (the premise of `check-jit.sh`).

## Rules for a harness

* Run both sides of a comparison with the same three streams: standard
  input from `/dev/null` or the test's `.stdin` file, standard output and
  error to files. Never inherit a terminal.
* Run from the program's own directory under a fixed name, with the same
  `.args` and `.vmargs`.
* Compare the count line as text after stripping the prefix
  (`sed -n 's/^runevm: count: //p'`, `scripts/check-jit.sh:67`) and print
  both lines on a failure, as `check-jit.sh:79` does; a reader can then
  see at once whether the difference is 17 objects and 408 bytes (the
  streams), a multiple of 8 bytes with nothing else (a string's length)
  or something new.
* Run an experimental VM under `timeout` and `ulimit -v`; a runaway
  semispace has taken the machine down before.
* Counts may be taken in parallel and on a loaded machine; times may not
  ([performance.md](performance.md)).
* A program whose count depends on the clock is not a test and not a count
  workload until its clock is shimmed.

## Harnesses that measure

Two C harnesses measure what a design costs on the machine rather than
what a program prints: `tests/layouts`, the heap-layout roadmap's layouts
(`make check-layouts`), and `tests/gcbench`, the collector roadmap's unit
costs (`make check-gcbench`; [plans/garbage-collector-v2.md](plans/garbage-collector-v2.md),
*The harness*). `make check` runs both but times neither: it holds them to
oracles that do not depend on the machine's speed. Every kernel of the
layout harness must give the same checksum under every layout and heap
size (`tests/layouts/check.sh`); every experiment of gcbench runs at tiny
sizes with its own checks on (`tests/gcbench/check.sh`, a second or two):
the copies and marks reach every object, the barriers' remembered sets
find every old-to-young pointer, the sweeps free the dead bytes, the stack
scans agree, and the replay allocators keep every object whole and apart,
against their closed forms and a shadow heap. gcbench reads its counters
in the process with `perf_event_open` and goes on with the TSC where it
may not, so the check needs neither `perf` nor the permission to count.
Their timed runs are each directory's `measure.sh`, alone on an idle
machine and pinned to one core ([performance.md](performance.md); the
READMEs of the two directories).

## An instrumented VM

A build that changes what the VM does per object, for an experiment, keeps
the second oracle as its acceptance test. The census VM of the heap-layout
roadmap widens every object header by a word and hooks allocation, stores
and the collector; it subtracts its extra word from the bytes it counts,
so its `--count` line must equal the stock VM's on every workload, and its
trace must add up to that line (the sum of the recorded sizes equals the
bytes, the number of records equals the objects). On 47 MLton benchmark
programs, the compiler and the perf programs it did, and the mismatches
that turned up on the large programs were all input: a pipe where the
stock run had `/dev/null`, and the two programs that read the clock. None
was the VM. The same discipline applies to a VM with a new layout: the
objects and instructions of `--count` stay identical across the change,
the bytes move once, and the budgets are re-based in the commit that moves
them ([plans/heap-layout.md](plans/heap-layout.md), *Testing a layout
change*).

## When a count differs

1. Rerun both sides with the same streams, directory and name. A
   difference of exactly 17 objects and 408 bytes per stream is the
   streams; a multiple of 8 bytes with equal objects and instructions is a
   string's length, usually the program's path.
2. If the program reads the clock, take the clock out (above) before
   reading anything else into the numbers.
3. Same VM, different modes: `--jit=off` against each mode of
   `check-jit.sh`, which names the mode that disagrees.
4. Different VMs or widths: the layout of a value or an object
   ([runtime.md](runtime.md)); `test-portability` and `test-windows` say
   which VM disagrees with this machine's.
5. Two compilers: `check-register.sh` diffs the counts of their bytecodes, and
   `--disasm` shows where the code differs.

## Measuring a collector

A collector is judged by what it costs in time, memory and pauses, which
no count says, so the second-generation collector
([plans/garbage-collector-v2.md](plans/garbage-collector-v2.md), D1) is
measured against today's copier on a fixed set of workloads, with the
counts and the outputs as the oracle that it changed nothing else.

**The evaluation set** is `scripts/gc-eval.tsv`: the runs, their groups
and the groups' weights, fixed before any result was in (the roadmap's
*The workloads*). The bootstrap (with and without the JIT), `compile-sigs`
and `runedoc-page`; MLton's benchmarks, the 35 of the normal tier and the
14 of the GC-stress tier over 2 GB (`tests/perf/mlton-bench.txt`); the
lazy programs and the collector's named programs of
[examples/benchmarks](../examples/benchmarks/README.md), `binary-trees` at
depth 18; the latency workloads (`latency-ring` and `latency-map` with 10
MB, 100 MB and 0.93 GB live, `latency-static-map` with 200 MB); and Rune
compiling MLton. Groups weighted 0 0 0 are extras: the compiler from the
default 4 MiB heap, `compile-sigs --jit=off`, the strict twins of the lazy
programs, the static map at 20 and 800 MB.

`scripts/gc-eval.sh CANDIDATE BASELINE` runs the set on both VMs, which
must take `--gc-log` ([runtime.md](runtime.md), *The collector's log*):
round by round, each run on one VM and then on the other, in an order that
alternates with the round, each under `ulimit -v` and `timeout`, `perf
stat` and `/usr/bin/time`, from its own directory with its standard input
fixed and the compiler's output file removed before it (the rules above).
Each run is scored by its round with the least task-clock, as candidate /
baseline: **T** the task-clock, **M** the peak resident memory, **P** the
mean of the ratios of the longest pause, the 99th-percentile pause (a
pause under 1 ms counts as 1 ms) and 1 - MMU at 10 ms (at least 0.01). A
group is the geometric mean of its runs, and each score the geometric mean
of the groups weighted by the set; the M and P columns sum to 95, a slip
found after the set was fixed, so the scores divide by the weight present,
and the report says so. `scripts/gc-eval-score.py` prints the runs, the
worst cases (the five highest ratios of each score, and every run more than
1.10 in T or M, which D1 forbids) and the scores, and lists as problems
every run that did not exit 0, a program of the catalogue that did not
print PASS, any standard output or compiler output that is not the
baseline's, and any run whose bytes and objects allocated (the log's end
line) differ from the others': a collector does not change what a program
allocates.

```sh
scripts/gc-eval.sh bin/runevm-new bin/runevm                 # the set, 3 rounds
scripts/gc-eval.sh --only boot-default,latency --rounds 1 NEW OLD
scripts/gc-eval.sh --candidate-opts '--heap-fill 75' bin/runevm bin/runevm
GC_EVAL_LOCK='flock /tmp/rune-timed' scripts/gc-eval.sh NEW OLD
scripts/gc-eval.sh --score --out tests/out/gc-eval           # score again
```

The set takes about 30 minutes at three rounds on the reference machine
(15 a VM, half of it the GC-stress tier and the 1 GB runs, which are run
once), and the preparation a few more: the catalogue's programs compiled by
`bin/rune -O2 --lint` into the output directory (`tests/out/gc-eval`),
MLton's by `tests/external/run-mlton-bench.sh --prepare` from `MLTON_BENCH`
(their runs are left out where it is missing). `--extras` adds about three
minutes. Rune compiling MLton is part of the set but runs only with
`--mlton-compile`: about 10 minutes a VM, 12 GiB of address space (the heap
capped at 5 GiB), so 20 GB of free memory, from MLton's sources at
`5fe943391` in `MLTON_SOURCES` with the order of its files in
`mlton-rune.txt`. Times need the machine to themselves: `GC_EVAL_LOCK` is a
command prefix under which each round is made, let go for a minute between
rounds so that others waiting for it have it, and a run waits until its
ulimit and 8 GB more are free (`GC_EVAL_MARGIN`). After an interruption,
`--resume` with the same options makes only the runs that are missing.

**Pauses** come from the log by `tools/mmu.py LOG`: the pauses (a collection
that grows the heap is two passes, one pause), their longest, mean and
percentiles and a histogram, the collector's share, the heap and the peaks,
and the minimum mutator utilisation (the least share of any window left to
the program; Cheng and Blelloch, PLDI 2001) at windows of 1 to 200 ms, on
two clocks: the monotonic wall clock of the log's `t_ns` (never the
program's `Time.now`, which a virtual machine may step), and the
instruction clock, where each collection falls at its instruction count
and only the pauses are timed, which removes the mutator's own noise.
`--json` and `--row` are for scripts; `--self-test` checks the MMU against
closed forms and a brute-force scan.

**The 32-bit address space**: `scripts/gc-probe32.sh` grows a program's live
data on `bin/runevm32` until the heap cannot grow, under a 2 GiB limit and
without one, and reports the most live data a collection completed with
(the copier: 255 and 512 MiB, where D1 asks for 768 MiB and 1.5 GiB);
`--latency` adds the latency window at its 32-bit size, 50,000 messages.
About half a minute.

# Roadmap: the heap layout

Every value a Rune program holds is a 16-byte cell with a tag byte, and
every object in the heap has the 8-byte header the first runtime gave it
on 2026-09-17; the collector is the same Cheney copier. Three compilers,
two bytecodes, a native code generator and a JIT have come and gone over
that layout and none touched it. This roadmap plans the layout that
replaces it: the candidates, the experiments that put numbers on each,
the decisions with their tradeoffs, and the milestones that change the
runtime, both loops, the JIT's emitters, the images and the budgets once,
behind an interface that makes the second change cheap. It prepares the
collectors that come after it and stops short of building them. It was
written on 2026-09-26 against `228b7b7`, jit M10 on branch `jit`, which
the merge of the JIT roadmap (`d278153`, 2026-09-27) rebased to
`bd28e89`; the citations were checked against the merged tree. On
2026-10-03 the branch was rebased onto `origin/master` at `3b86b52`;
*After the rebase* says what that changed here.

What it rests on:
* a reading of `vm/vm.h`, `vm/heap.c`, `vm/prims.c`, `vm/image.c`, the
  two loops, `vm/new/jit`, `runeopt` and the compiler's representations,
  and of every plan that puts a demand on the heap (*Where we are*,
  *Prerequisites and flags*);
* four sets of measurements made for it (*The experiments*): a census of
  what the bootstrap and forty other programs allocate, field by field;
  a simulator that replays those traces under every candidate layout and
  five collector models; a C harness that runs the compiler's own data
  structures under each layout; and today's VM profiled and swept over
  heap sizes. Every number below names the script that made it
  (*Measuring*);
* the source of twenty-five runtimes under `/home/ruud/reference` (*What
  the implementations do*) and the literature (*What the literature
  says*, *References*). Below, `performance.md` alone means
  [plans/performance.md](performance.md), the plan; `jit.md` is
  [plans/jit.md](jit.md).

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | Measure in the tree | done 2026-09-27, `36ef0a3` |
| M2 | The simulator and the harness in the tree | done 2026-09-27, `3f17fd2` |
| M3 | The layout behind an interface | done 2026-09-27, `93cc674` |
| M4 | Prototypes at full scale; the gate | done 2026-10-04: both prototypes run, pass the suites and are measured (branches `heap-layout-word` and `heap-layout-pairs`; the four sections *M4, ...* below), and the owner decided the gate that day (*M4, for the gate*). Not built in M4, and no longer wanted before M5: raw typed fields, the 32-bit header and its table, typed slots |
| M5 | The chosen layout, complete | in progress on `heap-layout-word`: the first of its four steps, the 64-bit types, is built and passes every suite (*M5, the first step*); the reals' encoding is next |
| M6 | Roots and maps | |
| M7 | The collector on the new layout, and the hooks for the next | |
| M8 | Flat arrays, strings and the FFI's objects | |

The owner decided every decision on 2026-09-27 (*Decisions*), D1 to D5
provisionally on the experiments here and finally at the gate of M4,
on the prototypes' numbers, with the alternatives they named
benchmarked there; the gate was decided on 2026-10-04. The JIT roadmap finished the same day (M11
`798c002`, M12 `1f7e55b`, merged as PR #21, `d278153`), and the
milestones run on branch `heap-layout`, one commit each. M5 to M8
were planned again at the gate (*The milestones*).

### After the rebase

On 2026-10-03 the branch was rebased from `d278153` onto `origin/master`
at `3b86b52`, 66 commits later; the hashes of the table are the rebased
commits'. The text below was written at `228b7b7` and its numbers,
names and `file:line` citations are that tree's unless it says
otherwise. What master changed that this roadmap names, and what each
change does to it:

* **The register bytecode is the compiler's default, and `bin/rune`
  runs on `runevm-new`** (`6618017`). `bin/rune.rbc` is the register
  compiler, the `bin/rune.new.rbc` of the text; the stack bytecode is
  `--target=stack`, `bin/rune.stack.rbc` and the wrapper
  `bin/rune-stack`, and `runeopt` translates that one. D15's target
  configuration, "the default to come", is the default. The tools of
  M1 and M2 follow the names.
* **The bootstrap is another run.** The reference program was the
  register compiler writing the stack bytecode. It is now the shipped
  compiler writing the register bytecode, the register backend's work
  included, and it is a third larger:

  | the bootstrap | at `228b7b7` | rebased |
  |---|---:|---:|
  | instructions | 458,049,116 | 584,981,676 |
  | bytes | 1,087,242,872 | 1,434,979,904 |
  | objects | 24,051,681 | 32,290,596 |
  | the list cell's share of the bytes | 27.3% | 37.1% |
  | constructors' share of the bytes | 62% | 64.5% |
  | largest live size (forced collections) | 82.6 MB | 86.7 MB |
  | survival of a 1 MiB nursery (bytes) | 26.2% | 21.8% |
  | L1, the tagged word | 0.5908 | 0.5925 |
  | L1 + headerless pairs | 0.5022 | 0.4873 |
  | L1 + 16-byte alignment | 0.6961 | 0.7113 |
  | L4-mono, L4-uniform | 0.6319, 0.7067 | 0.6326, 0.7096 |

  (`scripts/census.sh --summary bootstrap` on the rebased tree, 376 s;
  the left column is M1's census in the tree.) Two thirds of what was
  added are list cells, 5.9 million of them, and they die young: the
  live data grew by 5% where the allocation grew by 32%. So nothing
  decided moves, and two things lean further the way they were
  decided: headerless pairs (D4 C) take 1.5 points more, and the
  nursery of the next roadmap (D7) sees less survive. Compile-sigs is
  where it was (L1 0.5925, with pairs 0.5126, L4-mono 0.6121,
  L4-uniform 0.6896). The tables of *The experiments* stand as
  measured at `228b7b7`; M4 and D15 compare a prototype with the
  16-byte layout built from the same sources, the branch at M3, since
  a number of `228b7b7` is no longer a number of the same program.
* **Two more things a count depends on** (docs/testing.md, *What the
  input is*). Whether the output file exists: the compiler now refuses
  an output that is one of its sources (`fd10179`), and the check costs
  one object and four instructions more per source when the output is
  not there yet, so the census's two runs of the compiler no longer
  agreed until each started without the file (`scripts/census.sh`,
  `tools/heapsim/validate.sh`). And where the tree is: MLton's `lexgen`,
  `mlyacc` and `vliw` build their inputs' names from the current
  directory, which the rebase's worktree showed; they get a relative
  one now (`tests/external/mlton-bench/*.sed`) and
  `tests/perf/mlton-bench.txt` their counts without it. The other 30
  programs under 2 GB count on the rebased compiler what they counted
  before; the 14 above were not run again.
* **Resource limits** (`fd10179`). `--heap-limit N` caps the semispace
  and `--equality-work N` the steps of one structural comparison; a
  program past either stops through `vm_limit`. `values_equal` takes
  the VM and walks with a stack of pending objects of its own instead
  of recursing, and the rebase rewrote that walk over `value.h`, so M3's
  recount holds. The image is version 7 and carries both limits. For
  this roadmap: the heap has a cap, which *The collector today* said
  it had not, and M7's copier keeps it; D12's walk by header is this
  walk; D10's one bump at M5 makes the image version 8.
* **Seven builds, not five.** MLKit and SML/NJ 2026.2 joined the hosts
  (`3d83f11`, `a9e0198`), so six host builds and the self-hosted one
  are held to one output, the generated `src/opt/x64_layout.sml` and
  whatever M4 and M5 add to the compiler included.
* **The compiler checks its representations** (`0e85e23`, `f3cd52a`).
  LowLint holds every variable to its `Low.rep` wherever an operation,
  a primitive, a field or a parameter says what it is, and every
  capture to being read. D1 B's raw typed fields and M4's field kinds
  rest on those representations, which until now only tier 2 trusted
  and nothing checked.
* **A benchmark suite is in the tree** (`examples/benchmarks`,
  benchmarks.md): 149 programs from MLton, SML/NJ, the ML Kit, nofib
  and Sandmark, each with profiles and a result check;
  `make bench-smoke` runs in `make check`, and
  `examples/benchmarks/count-budgets.tsv` holds counts. It has MLton's
  set, which M1 reaches through `tests/external/run-mlton-bench.sh`, as
  ports with checks. M4 measures on both: M1's runner at the sizes this
  roadmap's tables were made at, and the suite's `normal` profile. Its
  lazy variants are the lazy workloads M4 was to port (M4). Its count
  budgets move with the layout as every `.budget` does (M5).
* **`lib/random` and `lib/test/property` are in the tree** (the
  property-testing roadmap, merged). The SplitMix64 generator D2 notes
  is `lib/random/random.sml`, `Word64` throughout; `make test-lib`
  runs it in `make check`, and `make test-laws` every law of the
  documentation on its generators. Under D2 B it is code every
  prototype must pass, not only a workload for the gate.
* **docs/performance.md says why `vm/new` is slower than MLton**
  (`c72dc95`), from instruction traces of tier 2's code: "the tagged
  16-byte Values written to memory at every result" among what recurs,
  ten instructions of an iteration of `word_bits` storing tags and
  payloads, `array_sieve` allocating 3.4 times MLton's bytes at 16 a
  cell. These are costs D1, D3 and M8 take away, measured without this
  roadmap's instruments; M4's table quotes the same programs.
* **Paths.** The man pages are under `share/man` (`87eebe6`).

### After the rename

On 2026-10-03, after the rebase, the owner had `vm/` renamed to
`runtime/` and the binaries renamed with it. The text of this roadmap
keeps the names it was written with; to read it against the tree:

* **Folders.** The runtime both VMs link is directly under `runtime/`
  (`vm.h`, `value.h`, `heap.c`, `loader.c`, `prims.c`, `image.c`,
  `runtime.c`, `main.c`). `runtime/sys/` is the system layer,
  `runtime/stack/` the stack VM (`interp.c`, `isa_stack.c`, the opcode
  tables), `runtime/register/` what was `vm/new/`, with the JIT in
  `runtime/register/jit/` (so `vm/new/jit/masm.c` is
  `runtime/register/jit/masm.c`), `runtime/native/` what a program of
  `runeopt` links (`native.c`, `native_offsets.h`), and
  `runtime/census/` the census build with `layouts.h`. A file names a
  header of another folder by its path from `runtime/`, with one include
  path, so a dependency across folders shows in the include.
* **What the instruction sets share** is the generated `runtime/isa.h`:
  the `.rbc` version, both fingerprints and the flow enum, which were in
  the stack opcode header. The shared `vm.h` includes nothing of the
  stack VM any more.
* **Binaries.** `runevm-new` is `runevm`, in every variant
  (`runevm-opt` is now the register VM at tier 2, `runevm32`,
  `runevm.exe`). The stack VM is `runevm-stack` (`runevm-stack32`,
  `runevm-stack.exe`). `runeopt`'s wrapper, which was `runevm-opt`, is
  `runevm-native`. `bin/rune-new` is gone: `bin/rune` makes the register
  bytecode. Messages still begin `runevm:` on both VMs.
* **Tests and targets.** `tests/vm` is `tests/runtime`, `tests/new` is
  `tests/register`, `scripts/check-new.sh` is `check-register.sh`, and
  `make test-new`, `test-new-jit` and `test-new-asan` are
  `test-register`, `test-register-jit` and `test-register-asan`. The
  configuration names of the tables (`rune`, `rune:new`, `rune:jit`,
  `rune:opt`) and the variables that go with them are as they were.

### M4, the first prototype so far

Branch `heap-layout-word`, from 2026-10-03; what follows is the state on
that day, not the gate's table. The prototype is the tagged word of D1 B
in every engine, `runeopt` since 2026-10-04: a value is one 8-byte word, an
immediate `2n+1`, a pointer the address; a real is Koka-encoded in the
word or a `K_REAL` box (D3 C); an integer or a word past 63 bits is a
`K_BOX` (D2 A, the default of the prototype, so that every suite runs
unchanged), with D2 B's 63 bits (`RUNE_INT63`) and D3 B's boxed reals
(`RUNE_REAL_BOXED`) as compile-time switches, each with a VM of its own
(`make bin/runevm-int63 bin/runevm-realboxed`). The header is the
8-byte one of today; fields are tagged words (raw typed fields are the
next stage). It passes `make test`, `test-register` (the Basis suite's
139,210 checks), `test-register-jit`, `test-stress` and
`test-register-asan`, and the bootstrap's fixed point holds; as native
code, `test-opt`, `test-native` (the Basis suite's 139,211, the counts
of 264 programs equal to the stack VM's, the compiler as native code
reproducing itself), `test-native-stress` and `test-native-asan`.

What building it found, that the plan did not have:

* **The payload is rounded to a word, not to 16 bytes.** Rounded as
  today the bootstrap's bytes were 0.654 of the 16-byte layout's; with
  `PAYLOAD_ALIGN` 8 (the smallest object 16 bytes) they are 849,752,320
  against 1,434,024,896: 0.5926, where the census said 0.5925 for L1.
* **Two numbers are equal by their words, or as two boxes by their
  bits.** An immediate is never the number of a box, so one of each is
  two numbers; comparing signed payloads said otherwise (a box of
  2^64 - 1 and the immediate 2^63 - 1). One function, `val_same_imm`,
  for `imm_eq`, `values_equal` and the fast paths.
* **The representation's boxes are counted apart.** A `K_REAL` or
  `K_BOX` is the layout's, not the program's: `--count` leaves them
  out, so objects agree between engines and with the 16-byte layout,
  and `--stats` prints them on a line of their own. Tier 2 would
  otherwise count a box at each write-back that the interpreter never
  makes; `Runtime.stats`' live bytes leave them out too.
* **Tier 2 keeps a real as a double.** An `xmm` home holds the double
  and its slot may be behind; the word is made (encoded, or boxed by a
  helper that reuses the slot's box when the bits are the same) where
  something needs it: a safepoint, a store, a move to a register without
  such a home. Without this `real_nbody` was 3.4 times slower at tier 2
  than on the 16-byte layout; with it, level.
* **An int or a word in a general home is its word**, so writing it
  back is one store and arithmetic is done tagged (`lea`, `add`, `jo`
  gives the overflow of 63 bits). Under D2 A each operand needs a test
  for the box and a word's result a test for the 64th bit, which is
  what `word_bits` pays below.
* **Raw typed fields are not sound as planned for a tuple that
  polymorphic code reads.** A reader at `'a` does not know a field is
  raw, so either every reader of a real or `'a` field tests the
  descriptor, or raw fields are confined to where no polymorphic reader
  can reach: constructor fields of a declared ground type and
  monomorphic arrays. Only reals (and `Int64`/`Word64` under D2 B) gain
  anything. For the gate; the next stage builds the confined form.

Cycles, of both prototypes and their switches, measured on an idle
machine on 2026-10-04 (`scripts/perf-cycles.sh --configs jit-off,new
--gc`, the least of five runs, a program at a time and only while the
machine's load was below 1.5; an earlier table, taken beside another
session's suites, is discarded: its cycles were up to a third too high
at the same instructions). 16-byte is branch `heap-layout` at M3, the
same sources; the pairs are prototype 2 (*M4, the second prototype so
far*); every word column keeps 64-bit integers (D2 A) but the one that
says 63:

| Program | 16-byte | word | word, reals boxed | word, 63 bits | pairs | pairs, 2 codes |
|---|---:|---:|---:|---:|---:|---:|
| *`runevm` as it runs (tiering)* | | | | | | |
| array_sieve | 151.2M | 118.7M | 115.3M | 115.0M | 116.8M | 114.5M |
| fib | 269.1M | 233.9M | 232.0M | 241.7M | 244.5M | 232.3M |
| intinf_fact | 212.7M | 165.3M | 164.5M | 169.2M | 166.2M | 166.6M |
| list_ops | 159.1M | 117.7M | 118.5M | 116.4M | 114.3M | 113.9M |
| real_nbody | 175.9M | 179.6M | 179.0M | 179.4M | 179.5M | 179.9M |
| string_ops | 364.0M | 264.8M | 270.2M | 261.1M | 243.0M | 242.9M |
| tak | 75.8M | 67.7M | 67.9M | 66.6M | 67.7M | 67.8M |
| word_bits | 73.0M | 91.3M | 91.3M | 75.0M | 92.1M | 91.9M |
| compile-sigs | 701.9M | 638.5M | 587.5M | 600.4M | 604.6M | 612.3M |
| runedoc-page | 337.6M | 286.0M | 288.6M | 279.6M | 284.0M | 294.3M |
| bootstrap | 7.76G | 6.52G | 6.33G | 6.47G | 6.51G | 6.43G |
| *the interpreter alone (`--jit=off`)* | | | | | | |
| array_sieve | 564.5M | 380.4M | 382.2M | 378.2M | 381.6M | 382.1M |
| fib | 843.7M | 800.8M | 796.4M | 768.2M | 910.9M | 856.0M |
| intinf_fact | 460.5M | 403.9M | 402.6M | 394.4M | 399.8M | 414.1M |
| list_ops | 356.8M | 295.1M | 299.3M | 290.0M | 271.2M | 270.1M |
| real_nbody | 631.3M | 958.2M | 2.20G | 977.8M | 1.02G | 1.00G |
| string_ops | 682.4M | 567.8M | 584.3M | 560.1M | 542.0M | 556.4M |
| tak | 226.7M | 207.2M | 207.9M | 199.3M | 220.4M | 218.8M |
| word_bits | 540.8M | 572.9M | 587.2M | 533.1M | 586.7M | 587.8M |
| compile-sigs | 1.16G | 996.3M | 970.4M | 970.1M | 950.2M | 961.5M |
| runedoc-page | 665.8M | 612.6M | 615.6M | 587.4M | 604.1M | 614.7M |
| bootstrap | 15.50G | 13.50G | 13.07G | 13.17G | 13.09G | 13.12G |

The bootstrap at the defaults: 7.76G cycles on the 16-byte layout and
6.52G on the word (0.84), 3.49 s of `task-clock` against 2.61 s,
234,502 page faults against 102,780, a semispace of 268 MB against
134 MB, 491.7 MB copied against 350.7 MB. The same layout built twice
(the word in its own worktree, and prototype 2's sources without pairs)
reads 6.52G and 6.32G on the bootstrap and 638.5M and 603.7M on
`compile-sigs`: a difference under a twentieth between two columns is
the build's, not the layout's, and under the interpreter alone a kernel
moves by more (`fib`, which makes no pair, reads 911M and 856M on the
pairs with three codes and with two).

What the table says:

* **The word against 16 bytes:** 0.73 to 0.91 of the cycles on every
  program that allocates or moves values, 0.84 on the bootstrap, and
  0.67 to 0.95 under the interpreter alone. Two programs lose.
  `real_nbody` under the interpreter is 1.52 times slower: every real
  operation decodes and encodes; at tier 2 the homes make it level
  (1.02). `word_bits` at tier 2 is 1.25 times slower under D2 A, the
  tests for the box.
* **D2 B against D2 A** (63 bits against the word): `word_bits` 0.82,
  level with the 16-byte layout; the rest within the noise at tier 2,
  and two to four percent under the interpreter (`fib` 768M against
  801M, the bootstrap 13.17G against 13.50G). Run on the library and
  the compiler as they are, which believe in 64 bits, 63 bits fail 7 of
  the language suite's 331 programs (the literals and limits of `Int`
  and `Word`, `IntInf`'s conversions) and in the Basis suite seven
  programs that do not load (`word`, `word8`, `word_large`, `real` and
  three of `intn_word`: 16,163 checks not reached) and 34 checks (32 of
  `PackReal`, whose bytes go through a 64-bit word and lose the sign
  bit, and `Int64.precision` twice). The compiler does not notice: its
  bootstrap on the 63-bit VM writes the bytecode the 64-bit one writes,
  byte for byte. That is the list M5 would work through under D2 B:
  the Basis' `Int` and `Word` at 63, `Int64`/`Word64`/`LargeWord` on
  boxes or two words, `PackReal` and `Real`'s conversions by another
  path.
* **D3 B against D3 C** (reals boxed against the word): level at tier
  2, where a real lives in its home either way; under the interpreter
  `real_nbody` is 2.3 times slower again (2.20G against 958M). Every
  suite passes with the switch on.
* **Pairs against the word:** on the kernels that build lists and
  strings, 0.92 (`string_ops` 243M against 265M) and 0.97 (`list_ops`),
  and 0.92 under the interpreter (`list_ops` 271M against 295M); on the
  compiler, nothing the noise does not cover (the bootstrap 6.51G
  against 6.52G and 6.32G; `compile-sigs` 605M against 604M on the same
  sources). The bootstrap's collector does less (8 collections for 10,
  240.6 MB copied for 350.7 MB, 405 ms for 500 ms on the same sources),
  which is four percent of its time, and the mutator gives it back: a
  field of a tuple or a constructor is read through a mask, and a
  constructor's tag through one more test. The harness's kernels
  promised more (*The harness*); at full scale the pairs are a saving
  of memory, 0.83 of the word's bytes, more than of time.
* **The third code:** two codes against three are level on every row.

`runeopt` on the word (2026-10-04) cost what D11 said it would: the
text backend of the assembler lost its tag bytes and gained the seven
new operations, the generator's list became the operations on words
(`twoImm`, `intAdd`, `setWord`, the reals with the label of their slow
path), and `src/opt/x64.sml`'s inline primitives were rewritten over
them, 190 lines; no template is written by hand. One thing the word
took away had to be given back: **a constant no longer says what it
is.** A value of one word does not tell an int from a word, a char or
an encoded real, and two readers need to: `--disasm`, and `runeopt
--from-image`, which makes a bytecode file of an image's program. The
program keeps the kind the bytecode gave each constant, and the image
(version 8) writes it with the constant's 64 bits as the bytecode has
them, so the reader in SML knows nothing of the encoding.

The other machines (2026-10-04): `make test-portability` and `make
test-windows` pass on the prototype as it is, with no change for them.
The language suite, the runtime's tests and the Basis suite pass on the
32-bit and big-endian builds of both VMs and on aarch64 with its JIT,
`--count` agrees on every one of them and an image of each is read by
every other; on Windows the four VMs pass the same, the JIT under the
Windows convention included. A value is 8 bytes on every width here
(D13 A): the 32-bit VMs' own word (D13 B) is M5's.

**64-bit words that cross slots** (2026-10-04; the workload D2's note
of 2026-09-27 asked for). `lib/random`'s SplitMix64 as a program: three
million words from one generator, and a tree of 2^18 splits, where a
generator, two `Word64`s in a record, is passed at every node. Half of
what it computes has its top bit set, which under D2 A has no immediate.
Instructions at the default tiering (they do not depend on the machine's
load, as cycles do), with programs of small numbers beside it and
MLton's `tailfib`, a loop of int additions, and `tyan`, whose ints pass
63 bits now and then:

| | 16-byte | D2 A: a home holds the word | D2 A, raw homes | D2 B |
|---|---:|---:|---:|---:|
| SplitMix64 | 1.01G | 9.36G | 2.11G | another answer |
| its cycles, on an idle machine | 456M | 3.43G | 816M | |
| its boxes | none | 21.6M, 346 MB | 8.3M, 133 MB | none |
| tyan | 1.92G | 4.04G | 2.18G | 1.83G |
| tailfib | 32.9G | 43.3G | 49.5G | 32.8G |
| fib | 635M | 687M | 822M | 612M |
| tak | 184M | 186M | 245M | 177M |
| word_bits | 251M | 331M | 449M | 251M |

(`bin/runevm`, `bin/runevm-rawhomes` and `bin/runevm-int63` of
prototype 1.)

* **With a home that holds the word, SplitMix64 is nine times the
  instructions of today**, and the JIT gains nothing over the
  interpreter (9.36G against 9.40G): an operand or a result past 63
  bits sends the operation to the primitive's C, and every such result
  is a box. The perf programs do not show it; `word_bits` keeps its
  words to 30 bits.
* **Raw homes are D5 A as the roadmap states it**, built as a switch
  (`RUNE_RAW_HOMES`): at tier 2 an int's or a word's home holds its 64
  bits, arithmetic between homes is the machine's with no test (a
  word's has none at all), an operand in a slot is unboxed in line, and
  a result is given its word, or boxed by a helper, only where it goes
  to a slot. The same mechanism as a real's home, with the same rule
  for an emitter (`ms_need_word`). SplitMix64 comes to 2.1 times
  today's instructions.
* **And they cost the small numbers.** A value that crosses a slot is
  decoded on the way in and encoded on the way out, and a call crosses
  slots: `fib` runs 822M instructions against 687M, `tak` 245M against
  186M, `word_bits` 449M against 331M, `tailfib` 49.5G against 43.3G.
  In cycles the bootstrap takes 7.68G with them against 6.52G, which
  is the 16-byte layout's 7.76G again, and `tak` 86M against 68M.
  That is why they are a switch and not the prototype's default: the
  two kinds of program want opposite things of a home, and nothing tier
  2 knows when it compiles says which kind it has.
* **D2 A costs the small numbers either way.** With a home that holds
  the word every operand is tested for a box and a word's result for
  its 64th bit: `tailfib` is 1.32 times the 16-byte layout's
  instructions (1.28 in cycles), `word_bits` 1.32 (1.25), and `tyan`,
  whose boxes go to the primitive's C, 2.1. Under D2 B they are 1.00,
  1.00 and 0.95. What would give D2 A that speed is tier 2 betting on
  small numbers: code with no test, as D2 B's, that hands the frame
  back to the interpreter when a box turns up, and a function that
  does so often compiled again with raw homes. The JIT has the
  deoptimisation to build it on; it is not built, and the interpreter
  would pay its two to four percent regardless.
* **What is left with raw homes is the slots.** x86-64 leaves tier 2
  three general registers for homes, so most of SplitMix64's
  intermediates live in slots, and D5 A says a slot holds a word: a
  64-bit result bound for a slot is boxed, 16 bytes each (26% of the
  remaining instructions are the boxing helper, which allocating in
  line would shorten). The record of two `Word64`s boxes its fields as
  well, which raw typed fields would not: this workload, not the reals,
  is the case for D1 B's second half. Short of typed slots (D5 B) the
  price of a 64-bit word that does not fit 63 is a box wherever it
  rests outside a home.
* **D2 B does not escape it, and is the cheapest for small numbers.**
  With `Int` and `Word` at 63 bits nothing tests for a box (`fib` 612M,
  below today's 635M), and the library's `Word64` is a type of its own,
  boxed in every slot whatever its value, so SplitMix64 pays at least
  what raw homes leave. The 63-bit VM as it is runs the program and
  prints another answer: its words wrap at 63.

Not built yet: raw typed fields and the rest of M4's list. The budgets
are not moved.

### M4, the second prototype so far

Branch `heap-layout-pairs`, from `heap-layout-word` on 2026-10-04, in a
worktree of its own so that the two prototypes stand side by side. It is
prototype 1 with D4 C: a tuple of two fields and a constructor of two
fields are their two fields alone, 16 bytes, with no header. It passes
`make test`, `test-register` (the Basis suite's 139,210 checks),
`test-register-jit`, `test-opt`, `test-native`, `test-stress`,
`test-register-asan`, `test-native-stress` and `test-native-asan`, and
the compiler's bootstrap on it writes the bytecode the others write.
`make test-portability` and `make test-windows` pass with the suites'
comparisons made per width (below): big-endian PowerPC and aarch64, with
its JIT, have the pairs, the 32-bit builds do not.

As built:

* **The pointer's code.** Objects are 8-byte aligned, so a pointer has
  three low bits: bit 0 says immediate, and bits 1 and 2 are a code: 0
  an object with a header; 1 a tuple of two, or a constructor of tag 0
  with two fields; 2 a constructor of tag 1 with two (a list's `::`); 3
  a constructor of tag 2 with two, or nothing where the code is kept for
  a lazy front end (`RUNE_PAIR_CODES=2`, `bin/runevm-pairs2`). The
  constructor's tag is the code less one, so a `case` on a list or on
  any such constructor reads no memory.
* **A pair's pointer is where its header would be**, eight bytes before
  its first field, with the code in the low bits. With the code masked
  off, field *i* is where field *i* of an object with a header is, so
  one access serves both: tier 2, which trusts the shape, masks and
  loads, and for a field past the second it does not mask at all. What a
  pair has no header to say is asked of the value, not of the object
  (`val_is_kind`, `val_len`, `val_contag` in `value.h`): 21 places in
  the runtime tested a kind through the object and now ask the value.
* **The pairs have a region of their own**, at the top of the semispace,
  growing down as the objects with headers grow up; the heap is full
  when they meet (`heap_end`). A walk of either region needs nothing of
  the other, which is what the collector's scan, an image and its
  relocation want; the allocation in line is the same six instructions
  with another bound. This is SML/NJ's pair arena and Chez's segments,
  at the cost of one more word in the VM.
* **Forwarding without a header.** A copied pair's first field becomes
  its copy, which is told from a value by being a pair of to-space:
  nothing in from-space points into to-space until it is copied. No
  marker pattern is taken from the values, and no side bitmap.
* **An image** writes the pairs after the objects, a pointer to one as
  its distance from the top of the heap, so that a heap restored at
  another size keeps them (version 9).

What building it found:

* **Code 1 does not say whether it is a tuple or a constructor of tag
  0.** The program's types keep them apart, as they keep an int from a
  char, and the collector, equality and an image need not know. A VM
  without pairs does: the 32-bit builds refuse a 64-bit image that has
  one, and M5 gives them a kind for "a pair, a tuple or tag 0" if such
  an image is to cross. The harness's assignment (a tuple, tag 0 and
  tag 1 a code each) says which, and has no code to spare.
* **That sharing is what makes the lazy code cheap.** With tuples and
  tag 0 on one code, giving up the third costs the two-field
  constructors of tag 2 alone: 474,184 bytes of the bootstrap's
  704,455,544, 0.067% (the census said 0.093%). Had a tuple a code of
  its own, the code given up would be a list's or a tuple's.
* **Bytes.** The bootstrap allocates 704,455,544 bytes in 32,274,744
  objects, against 849,800,368 without pairs on the same sources (0.829)
  and 1,434,024,896 on the 16-byte layout (0.491; the census's bound for
  every two-field object was 0.4873, and the simulator's for the three
  codes built 0.4 points above its bound). It collects 8 times where
  the word collects 10 and copies 240.6 MB where the word copies
  350.7 MB.
* **Bytes are per width now.** A 32-bit VM has no pairs, so `--count`'s
  bytes agree among the 64-bit VMs and differ on the 32-bit ones, and
  the tests that name a list cell's size accept 16 or 24. D13 B says as
  much of the 32-bit word.
* **`runeopt`** got it from the generated templates again: the shape
  loads, the allocation of a pair and its code are operations of the
  macro-assembler, and `src/opt/x64.sml` chooses by the instruction's
  count and tag which to write.

**MLton's benchmarks** (2026-10-04), the 33 of
`tests/perf/mlton-bench.txt` that run under 2 GB, on the three layouts
(`tests/external/run-mlton-bench.sh --vm-opts --stats`). Objects are
the same number on every one of the 33, which is the oracle holding
across layouts. Against the 16-byte layout:

| | word | pairs |
|---|---:|---:|
| bytes allocated, all 33 | 0.594 | 0.507 |
| the range over the programs | 0.529 to 0.683 | 0.400 to 0.683 |
| bytes copied | 0.494 | 0.366 |
| collections (2,915 on the 16-byte layout) | 1,973 | 1,665 |
| cycles, default tiering, geometric mean | 0.945 | 0.958 |
| their range | 0.61 to 1.58 | 0.54 to 1.65 |

* The numeric programs make no box: `fft` 0.571, `nucleic` 0.559,
  `ray` 0.590, `raytrace` 0.563, `barnes-hut` 0.588 and `zern` 0.579
  under the word are what the roadmap said raw real fields would give
  (0.56 to 0.59), because Koka's encoding holds every real they
  compute. In bytes, raw real fields have nothing left to save. Only
  `tsp` (4.2 million boxes, 67 MB) and `tyan` (1.2 million, 20 MB) box
  anything.
* **In cycles the reals pay.** At the default tiering, on an idle
  machine, the word runs the 33 programs at a geometric mean of 0.945
  of the 16-byte layout's cycles: 22 are faster (`tailmerge` 0.61,
  `merge` 0.71, `imp-for` 0.71, `knuth-bendix` 0.71, `checksum` 0.73,
  `hamlet` 0.75, `boyer` 0.78), and 11 slower: eight programs of reals
  (`nucleic` 1.58, `raytrace` 1.55, `tsp` 1.53, `mandelbrot` 1.45,
  `ray` 1.44, `barnes-hut` 1.35, `fft` 1.20, `simple` 1.12), `tyan`
  1.43 and `tailfib` 1.28, which are D2 A's (above), and `peek` 1.04.
  The programs of reals run 1.4 to 2.1 times the
  instructions: a real read from a tuple, a record or an array is
  decoded, twelve instructions, and one stored is encoded, fifteen, and
  `nucleic`'s time is in tier 2's code of functions that take a
  twelve-real tuple apart and build another. `real_nbody` hid it: its
  reals stay in their homes. Boxing them instead (D3 B) is worse on
  every one (`nucleic` 13.4G instructions against 4.0G and the 16-byte
  layout's 2.2G; `fft` 70.7G against 46.5G and 23.3G).
* **So raw real fields are worth their cost after all** (as it stood
  that day; *M4, what was measured for the gate* found the cost at
  every crossing and not only at fields, and a shorter encoding that
  removes most of it), for time and not for space: a real field that holds the double, the header saying
  so (D1 B's second half, D4 A's descriptor), read and written with no
  encoding where the reader's register is a real's. That is the next
  thing to build on prototype 1, with flat real arrays (M8) beside it,
  and until it is built the word's column of this set is D3 C without
  it. A pair has no header to say it: two reals as a headerless pair
  stay encoded, unless a pointer's code says "two raw reals", which is
  one more claim on D4 C's third code.
* Pairs take the list-heavy programs to 0.40 of the bytes (`merge`,
  `tailmerge`, `pidigits`, `smith-normal-form`) and leave untouched
  those that build no two-field object (`peek`, `imp-for`). In cycles
  they are the word's: 1.01 of it in the geometric mean, from 0.88
  (`tailmerge`) and 0.90 (`simple`) to 1.10 (`ratio-regions`, `peek`,
  `fft`, `zern`), which is about what two builds of one layout differ
  by.

Cycles: in the first prototype's table above, its last two columns.

### M4, for a lazy front end so far

**The lazy workloads** (2026-10-04). `examples/benchmarks` has six lazy
programs over `shared/lazy.sml`, a suspension as a ref to a pending
thunk or a value, and four strict twins; each at its `normal` profile,
censused on the 16-byte layout (`scripts/census.sh --stdin --cwd`, its
traces under `tests/out/census-lazy`) and simulated (`bin/heapsim`).
Bytes against the 16-byte layout, and the stores a nursery of 1 MB
(and of 4 MB) with promotion at the first survival would have to
remember:

| Program | bytes | word | pairs, 3 codes | 2 codes | updates | old to young, 1 MB | 4 MB | largest remembered set |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| primes-lazy | 100 MB | 0.619 | 0.571 | 0.571 | 585,305 | 0.62% | 0.15% | 100 |
| queens-lazy | 8.5 MB | 0.600 | 0.533 | 0.533 | 71,083 | 0.06% | 0.02% | 11 |
| tak-nofib-lazy | 12 MB | 0.625 | 0.625 | 0.625 | 190,835 | 0.08% | 0.02% | 28 |
| exp3_8-lazy | 1.23 GB | 0.632 | 0.632 | 0.632 | 16,145,867 | 5.60% | 1.52% | 4,146 |
| digits-of-e1-lazy | 1.06 GB | 0.599 | 0.428 | 0.428 | 1,581,401 | 2.07% | 0.48% | 121 |
| digits-of-e2-lazy | 3.13 GB | 0.613 | 0.481 | 0.481 | 8,078,615 | 6.70% | 1.94% | 573 |
| primes-strict | 565 MB | 0.600 | 0.400 | 0.400 | 5 | none | none | 0 |
| queens-strict | 22 MB | 0.603 | 0.423 | 0.423 | 5 | none | none | 0 |
| exp3_8-strict | 194 MB | 0.667 | 0.667 | 0.667 | 5 | none | none | 0 |

* **The update is the store.** A strict twin stores into a ref five
  times in its whole run; its lazy form 71 thousand to 16 million
  times, one update a thunk.
* **Most updates are young to young.** With a 1 MB nursery 93.3% to
  99.9% of the updates need no remembered entry, with 4 MB 98.1% to
  99.98%: a thunk is mostly forced soon after it is made. The set never
  holds more than 4,146 entries between two minor collections, and
  under 600 in every program but `exp3_8-lazy`.
* **The third code costs these programs nothing**: two codes and three
  give the same bytes on every row (24 bytes apart on the two
  `digits-of-e`). A suspension here is a ref and a one-field
  constructor, neither a pair, so what the pairs save is the lists and
  tuples the programs build, as in a strict program.
* A suspension is two objects here where GHC's thunk is one, so the
  bytes are an upper bound; the update pattern is the measurement, and
  it goes into M7's brief.

**The harness's lazy kernels** are in `tests/layouts` (`lazy_case` by
header, by code and by entering, at 0, 1, 10 and 50% thunks;
`lazy_stream`; `lazy_update_old`), with `L1+PAIRS2`, the build whose
third code means "a headered object, known to be evaluated", and
`check.sh` holds them to one checksum under all 22 configurations.
Cycles (`measure.sh`, gcc, an idle machine):

| Kernel | L1+PAIRS2 | L1+PAIRS | L1 |
|---|---:|---:|---:|
| lazy_case, no thunks: by the header | 0.99G | 0.93G | 0.89G |
| by the code | 0.94G | as the header | as the header |
| by entering | 1.50G | 1.48G | 1.28G |
| 1% thunks: header, code, entering | 6.98G, 7.02G, 6.88G | 6.84G, -, 6.88G | 6.80G, -, 6.90G |
| 10% thunks | 2.92G, 2.99G, 2.89G | 2.96G, -, 2.93G | 2.90G, -, 2.81G |
| 50% thunks | 1.10G, 1.09G, 1.08G | 1.11G, -, 1.07G | 1.08G, -, 1.06G |
| lazy_stream | 2.05G | 2.03G | 2.08G |
| lazy_update_old | 1.19G | 1.12G | 1.14G |

* **Entering every scrutinee costs half as much again** where they are
  values (1.50G against 0.99G), which is what GHC found before it
  tagged pointers; with thunks among them the three ways are one.
* **The code is 5% under the header's way** on a `case` over values
  (0.94G against 0.99G), inside what the harness calls noise: the
  header is read for the constructor's tag whichever way a thunk is
  ruled out, so the code spares a compare and not the load. GHC's gain
  is from the constructor's tag in the pointer, which one code cannot
  hold.
* The kernels with thunks spend most of their time choosing which
  elements to suspend (a remainder per element), which is the same for
  the three ways and drowns their difference; a kernel that suspends
  by a cheaper rule would say more.
* **The reserved code costs the strict kernels nothing that shows.**
  `L1+PAIRS2` against `L1+PAIRS`, on the seven kernels whose runs
  agreed within a tenth under both: `word_loop` 1.01, `strings` 1.02,
  `real_regs` 0.99, `real_array` 0.99, `strmap` 0.97, `gc_churn8` and
  `gc_churn64` 0.95. The machine was not idle for the whole of this
  run (another session's suites), and `list_ops`, `intmap`,
  `inttable`, `closures`, `int_loop` and `poly_eq_tree` spread by 13%
  to 56% between runs, so they are left out: a second run on a quiet
  machine is owed for them.
* `lazy_update_old` forces 7,995,392 old thunks, every update an old
  object given a young value, and with the card barrier they dirty
  1,026 cards of 512 bytes; `lazy_stream` forces 18.2 million thunks
  for 6,000 primes in ten collections, 40,903 of its updates (0.2%)
  old to young.

### M4, what was measured for the gate

On 2026-10-04, after the three sections above, for the four choices
the gate comes down to: 63 or 64 bits, the pairs, the reals, the third
code.

**The heap-size sweep** (`scripts/perf-cycles.sh --sweep`, an idle
machine, the default tiering). L is the most a collection keeps, found
at `--heap-fill 99` from a 4 MiB heap; the cycles there are the first
row, then at a semispace of k times each layout's own L:

| Bootstrap | 16-byte | word | pairs |
|---|---:|---:|---:|
| L | 86.4 MB | 51.7 MB (0.60) | 39.8 MB (0.46) |
| at L: collections, copied, cycles | 76, 3.64 GB, 13.6G | 70, 1.83 GB, 10.5G | 53, 1.16 GB, 9.7G |
| 1.25 L: semispace, cycles | 108 MB, 10.5G | 65 MB, 9.1G | 50 MB, 10.0G |
| 1.5 L | 130 MB, 9.3G | 78 MB, 7.8G | 60 MB, 8.8G |
| 2 L | 173 MB, 8.3G | 103 MB, 6.9G | 80 MB, 7.5G |
| 3 L | 259 MB, 7.5G | 155 MB, 6.1G | 119 MB, 6.5G |
| 4 L | 346 MB, 7.2G | 207 MB, 6.0G | 159 MB, 6.5G |
| 6 L | 518 MB, 7.2G | 310 MB, 5.7G | 239 MB, 6.2G |
| 8 L | 691 MB, 7.1G | 414 MB, 6.0G | 318 MB, 6.1G |
| 2 GiB, no collection | 6.6G | 5.3G | 5.5G |

* **The word wins at every heap size**, and by more where the heap is
  tight: with no collection at all it runs 0.81 of the 16-byte
  layout's cycles (the mutator alone: half the bytes written and
  read), at 173 MB 0.73, at 108 MB 0.65.
* **The pairs buy memory and not time.** Their L is 0.77 of the
  word's, so at the same multiple of L they run in three quarters of
  the memory for 1.01 to 1.13 of the cycles. Read at the
  same semispace instead (interpolated along each curve): 0.97 of the
  word's cycles at 80 MB and 0.99 at 108 MB, level at 130 MB, and 1.05
  to 1.06 from 173 MB up, where the collector has little to do and
  what remains is the mutator's mask at each field read. With no
  collection 1.03. Only where the heap is as small as it can be do
  they win clearly: 0.92 at L.
* `compile-sigs` says the same on a seventh of the data: L 13.6, 8.3
  and 7.5 MB; with no collection 657M, 598M and 639M cycles. On the
  two kernels the pairs are level or ahead: `string_ops` 243M to 281M
  cycles from 1.5 L up against the word's 258M to 309M (and 302M
  against 269M at 1.25 L), `list_ops` 110M to 126M against 110M to
  132M.

**Peak memory** (the resident set, `/usr/bin/time %M`, each VM at its
defaults; the bootstrap and the two compiler workloads from the 64 MiB
heap the budgets give them):

| Workload | 16-byte | word | pairs |
|---|---:|---:|---:|
| bootstrap | 532.9 MB | 274.4 MB | 274.8 MB |
| its semispace at exit | 256 MB | 128 MB | 128 MB |
| the most a collection kept | 72.0 MB | 44.9 MB | 35.9 MB |
| bootstrap from the VM's own 4 MiB | 534.8 MB | 273.2 MB | 273.5 MB |
| compile-sigs | 114.2 MB | 66.0 MB | 59.5 MB |
| runedoc-page | 84.8 MB | 53.7 MB | 47.0 MB |
| string_ops | 38.1 MB | 20.7 MB | 20.7 MB |
| list_ops | 21.9 MB | 12.5 MB | 12.5 MB |
| array_sieve | 17.5 MB | 10.2 MB | 9.9 MB |
| MLton's 33, the sum of their peaks | 3,363 MB | 1,985 MB | 1,590 MB |
| MLton's 33, geometric mean | 1.00 | 0.827 | 0.771 |
| the 14 of them over 16 MB | 1.00 | 0.637 | 0.534 |

* **The word halves the compiler's peak** (533 to 274 MB), and the
  programs that hold data follow: 0.64 in the mean of the fourteen of
  MLton's set whose peak is above the VM's own floor.
* **The pairs do not lower the compiler's peak**, though they keep a
  fifth less at a collection (44.9 to 35.9 MB): the semispace grows by
  doubling and both land on 128 MB. Where they cross a doubling they
  save a third to a half: `checksum` 384 to 231 MB, `fft` 355 to 227,
  `merge` 133 to 88, `tailmerge` 141 to 77, `knuth-bendix` 19 to 11.
  On MLton's set 0.93 of the word's peak in the mean, 0.84 on the
  fourteen. A growth policy finer than doubling would turn the
  compiler's 20% into resident memory too; that is M7's.
* The peak is two semispaces and the VM: a collector that does not
  copy everything (M7's successor) halves it again under any layout.

**MLton's set on 63 bits** (`bin/runevm-int63`, the same idle-machine
method as the word's column). The geometric mean of the 33 programs'
cycles against the 16-byte layout is 0.870, where the word that keeps
64 bits has 0.945: **63 bits are 8% faster than 64 across the set**
(0.921; 0.928 on the twelve programs whose object counts are the same
to the unit). Nothing is slower by more than what two builds differ
by (`barnes-hut` 1.05, `fft` 1.04, `knuth-bendix` 1.03); `tyan` runs
0.53 of the 64-bit word's cycles, `tailfib` 0.75, `simple` 0.82,
`even-odd` and `tsp` 0.85, `tensor` and `wc-scanStream` 0.87. The two
programs that boxed by the million under D2 A box nothing (`tsp` 6.3
million boxes, `tyan` 5.7 million), and every program prints what it
printed. The eleven slower than today become seven, every one a
program of reals (below).

**The strict kernels under the reserved code, again**, the six whose
runs were too far apart, on an idle machine: `L1+PAIRS2` against
`L1+PAIRS` is `list_ops` 1.07, `intmap` 1.00, `inttable` 0.97,
`closures` 1.01, `int_loop` 1.01, `poly_eq_tree` 1.04. Their runs
still spread by 9% to 73% (ten of each), so the harness cannot say
more than that nothing here contradicts the VM's own number: 0.067% of
the bootstrap's bytes and no cycles that show.

**Where the reals' cost is.** The eight programs of reals censused
(`scripts/census.sh --summary`, under `tests/out/census-reals`), their
reals by where they arise:

| Program | results of primitives | crossing a call | stored in a new object | stored later | zero among the results |
|---|---:|---:|---:|---:|---:|
| barnes-hut | 16.7M | 10.6M | 8.6M | 18,674 | 0.03% |
| fft | 1,309M | 39.1M | 33.6M | 272.1M | 2.3% |
| mandelbrot | 6,717M | 4,295M | none | none | 0.001% |
| nucleic | 83.0M | 3.8M | 15.0M | none | 0.2% |
| ray | 28.6M | 2.9M | 10.0M | none | 21% |
| raytrace | 609.5M | 16.8M | 66.5M | 0.4M | 21% |
| simple | 9.5M | 12.9M | 3.9M | 0.3M | 31% |
| tsp | 1,397M | 215.0M | 4.3M | none | 0.02% |

* **The fields are the smaller part.** A real crosses a call as often
  as it is stored in an object or more often on four of the eight
  (`mandelbrot`, `tsp`, `simple`, `barnes-hut`), and `mandelbrot`,
  1.45 times slower under the word, stores none: it allocates 353
  objects in its run. So raw real fields, which the second prototype's
  section called the next thing to build, would not have touched it.
* **The cost is the encoding, wherever a real leaves its home.** Tier
  2 keeps a real in an XMM register and the slots stay words (D5 A),
  so a real is encoded at every argument of a call, every result,
  every home written back around a primitive that may collect, and
  decoded on the way back, besides the fields. Koka's encoding squeezes
  the exponent by cases (zero, all ones, the middle), which in the
  JIT's code is fifteen instructions and four conditional branches to
  decode and fourteen to encode, where the 16-byte layout has one
  `movsd`. `mandelbrot`'s inner function is 27 KB of code under the
  word against 4 KB, and it decoded the constant 4.0 from the
  constant table at every iteration.
* **Zero is everywhere**: a fifth of what `ray` and `raytrace` compute,
  a third of `simple`'s, half of what `fft` stores in new objects
  (16.8 of 33.6 million). Whatever encodes a real must keep zero
  cheap. Apart from zero the reals outside Koka's range are none to
  speak of (129,844 of `raytrace`'s 66.5 million stored, 1,352 of its
  609.5 million results).

**Two changes on prototype 1 for it** (branch `heap-layout-word`):

1. *A real constant is decoded when the code is made*
   (`ms_set_real_known`): where the constant's register has a home,
   the code loads the double's bits. In the default build; 4% of
   `mandelbrot`'s instructions.
2. *A second encoding, by rotation*, behind `-DRUNE_REAL_ROT`
   (`bin/runevm-realrot`; `runtime/value.h`): the double's bits with
   2^61 added, rotated left by two; the word is an immediate where
   that leaves the low bit set, which is for the exponents 0x200 to
   0x5ff, Koka's range and two more. Decoding is the rotation back
   and the subtraction: seven instructions and one branch against
   fifteen and four, six to encode against fourteen. There are no
   cases, so zero, the subnormals, the infinities and NaN are not
   immediates: `+0.0` has one box that the VM keeps (`vm->real_zero`,
   a root, made where first wanted, loaded by the JIT's code in
   line), the rest are boxed where they are made. `tests/lang` passes
   at tier 1, at tier 2 and at the default tiering (331 each), and the
   Basis at the default tiering and at tier 2 (139,210 checks, as the
   word's).

Cycles and instructions against the 16-byte layout, the default
tiering, an idle machine, the least of three runs (of six for the
16-byte layout and the last column):

| Program | 16-byte | Koka's, 64-bit ints | rotation, 64-bit ints | Koka's, 63-bit | rotation, 63-bit | instructions: Koka's | rotation |
|---|---:|---:|---:|---:|---:|---:|---:|
| barnes-hut | 0.60G | 1.32 | 1.05 | 1.34 | 0.99 | 2.09 | 1.51 |
| fft | 25.8G | 1.20 | 0.99 | 1.19 | 0.92 | 1.98 | 1.52 |
| mandelbrot | 113.9G | 1.41 | 1.11 | 1.35 | 1.08 | 1.78 | 1.38 |
| nucleic | 1.17G | 1.50 | 1.17 | 1.49 | 1.12 | 1.83 | 1.36 |
| ray | 0.82G | 1.27 | 1.17 | 1.25 | 1.05 | 1.50 | 1.24 |
| raytrace | 5.44G | 1.52 | 1.20 | 1.49 | 1.16 | 1.71 | 1.35 |
| simple | 1.06G | 0.93 | 1.02 | 0.96 | 0.88 | 1.35 | 1.25 |
| tsp | 26.7G | 1.37 | 1.14 | 1.28 | 1.08 | 1.52 | 1.28 |
| geometric mean | | 1.30 | 1.10 | 1.29 | 1.03 | 1.70 | 1.36 |
| real_nbody | 0.18G | 1.02 | 1.01 | 1.02 | 1.01 | 1.11 | 1.10 |

* **The rotation takes the programs of reals from 1.30 of today's
  cycles to 1.10**, and with 63-bit integers, the build nearest to
  what is decided, to **1.03** (0.88 to 1.16). The word's one loss
  against the 16-byte layout is then three programs at 1.08 to 1.16
  (`mandelbrot`, `nucleic`, `raytrace`) and `tsp` at 1.08.
* What is left is seven instructions at a crossing where the 16-byte
  layout has one. Raw real fields would remove the crossings at
  fields, typed slots (D5 B) those at calls; neither is needed to make
  numeric code about as fast as today, which is what the second
  prototype's section asked raw fields for. The encoding is in the
  line of Melançon, Serrano and Feeley's self-tagging (2025, known
  here by its abstract): an invertible transformation of the float's
  bits that leaves the tag in the word for the floats met in practice;
  here a rotation, one tag bit, and an offset to put the common
  exponents under it.
* **The price of the rotation.** A zero in a field is a pointer the
  collector follows to the one box, where Koka's was skipped as an
  immediate. `-0.0`, the infinities and NaN allocate where they are
  made (16 bytes; a box each that the VM keeps would cover them as it
  covers zero). The interpreter's fast path has no VM at hand and
  leaves a zero result to the primitive; M5 would hand it the box.
  `simple`, a third of whose results are zero, is the one program not
  faster for the rotation with 64-bit integers (1.02 against 0.93) and
  the fastest with 63 (0.88), which is within what its runs differ by:
  two runs of one binary differ by up to 17% on `nucleic` and `ray`
  (a second or less, 80 to 105 collections) and by under 3% on the
  long ones.
* **The interpreter gains as much.** `real_nbody` with `--jit=off`:
  2.04G instructions on the 16-byte layout, 3.20G with Koka's
  encoding (1.57), 2.31G with the rotation (1.13), 5.71G with every
  real boxed (2.80). On the 32-bit interpreter, where the word's 64
  bits are two machine words: 2.93G, 5.99G (2.04) and 3.54G (1.21).
* **On every machine and in every engine** (after the gate, in a copy
  of prototype 1 with the rotation as every build's encoding): the
  JIT's suites, `make test-portability` (the 32-bit and big-endian
  VMs and aarch64 with its JIT: every suite on every VM, the counts
  agreeing, every image crossing) and `make test-windows` pass.
  `runeopt`'s templates wanted one line before they would regenerate,
  a name for the VM's field of the zero box
  (`runtime/native/native_offsets.h`, `c75f89fc`); with it they are
  293 lines against Koka's 322, and `make test-opt` and `make
  test-native` pass (331 programs, the counts of 264, the Basis'
  139,211 checks through `runeopt`'s code).

**The build M5 starts from** (2026-10-04, after the gate):
`bin/runevm-int63-realrot`, prototype 1 with 63-bit integers and the
rotation. It fails what the 63-bit build fails and nothing else: the
same seven programs of `tests/lang` and the same 41 of the Basis'
123,048 checks, which are the `Int64` and `Word64` work M5 begins
with. Cycles against the 16-byte layout, an idle machine, the default
tiering and the interpreter:

| Program | 16-byte, default tiering | 63 bits and the rotation | 16-byte, interpreter | 63 bits and the rotation |
|---|---:|---:|---:|---:|
| bootstrap | 7.76G | 0.84 | 15.50G | 0.87 |
| compile-sigs | 0.70G | 0.84 | 1.16G | 0.84 |
| runedoc-page | 0.34G | 0.84 | 0.67G | 0.90 |
| list_ops | 0.16G | 0.74 | 0.36G | 0.80 |
| string_ops | 0.36G | 0.73 | 0.68G | 0.82 |
| array_sieve | 0.15G | 0.75 | 0.57G | 0.68 |
| intinf_fact | 0.21G | 0.79 | 0.46G | 0.87 |
| fib | 0.27G | 0.91 | 0.84G | 0.94 |
| tak | 0.08G | 0.88 | 0.23G | 0.89 |
| word_bits | 0.07G | 1.03 | 0.54G | 1.08 |
| real_nbody | 0.18G | 1.01 | 0.63G | 1.14 |

MLton's 33 programs run at a geometric mean of **0.81** of the
16-byte layout's cycles (the word with 64 bits and Koka's encoding
0.945, 63 bits with Koka's 0.870), 27 of them faster, in 0.60 of the
bytes; slower by more than 2% are `raytrace` 1.15, `nucleic` 1.09,
`tsp` 1.08, `mandelbrot` 1.07, `ray` 1.05 and `peek` 1.03. That is
the number M5 has to keep.

### M4, for the gate

**Decided on 2026-10-04.** The owner took every recommendation of
this section, and two that M5's text turned on: the 8-byte word on
the 32-bit VMs too (D13 A, where B had been decided and was never
prototyped), and `runeopt` kept as D11 had it. So M5 is the word of
prototype 1 with 63-bit integers and words, `Int64` and `Word64` as
boxed types of their own, the rotation encoding of reals, the 8-byte
header on every machine, no headerless pairs and no raw typed fields;
the pairs stay a branch, a pointer's bits 1 and 2 stay unused for
them and for a lazy front end's code, and what was not prototyped has
a plan of its own: `real-encoding.md` and `32-bit-vm.md`.

What the two prototypes say to each decision the gate is to confirm,
on 2026-10-04; the tables are in the four sections above.

* **D1, the word: confirmed.** 0.59 of the bytes on the bootstrap and
  on MLton's set, 0.84 of the bootstrap's cycles, 0.61 to 0.90 on the
  programs that build structures; half the peak memory (533 to 274 MB
  on the bootstrap), and faster at every heap size. Its second half,
  raw typed fields, is not built, and is no longer what the programs
  of reals wait for: their loss was the encoding's (D3), and the
  shorter one brings them to 1.03 of today's cycles with every field a
  word. As planned raw fields are not sound for a tuple that
  polymorphic code reads; the form to build has the header's
  descriptor say which fields are raw and a reader test it where its
  register is a real's or `'a`. **Recommended:** M5 without raw
  fields; flat real arrays in M8 as planned; raw real fields decided
  after M5 on what `nucleic` and `raytrace` (1.12 and 1.16) still
  lose.
* **D2, integers and words: B holds, on new evidence.** At tier 2 the
  63-bit build is level with today on small numbers; keeping 64 bits
  costs 1.25 to 1.32 on a loop of ints or words (a test for the box at
  every operand), and raw homes move that cost to wherever a value
  crosses a slot. D2 A can have B's speed only if tier 2 bets on small
  numbers and deoptimises on a box, which is not built. What B needs
  is the Basis' list (*M4, the first prototype so far*) and `Int64`
  and `Word64` as boxed types, whose tier-2 homes hold the 64 bits: the
  mechanism is built (`RUNE_RAW_HOMES`) and brings SplitMix64 from 9.4
  to 2.1 times today's instructions. Neither choice makes 64-bit words
  that cross slots free: that takes typed slots (D5 B) or raw fields.
  On MLton's set 63 bits are 8% faster than 64 in the mean, nothing is
  slower, and `tyan` and `tailfib` go from 1.43 and 1.28 of today's
  cycles to 0.76 and 0.96.
* **D3, reals: C over B, by a shorter encoding than Koka's.** Boxing
  every real is worse wherever it differs (2.3 times on `real_nbody`
  under the interpreter, three times the instructions on `nucleic`).
  Koka's encoding is what made the programs of reals 1.2 to 1.5 times
  slower than today: fifteen instructions and four branches wherever a
  real leaves a register. The rotation (`RUNE_REAL_ROT`) is seven and
  one, and takes the eight programs from 1.30 to 1.10, to 1.03 with
  63-bit integers; its price is zero as a pointer to one box and a box
  for each infinity, NaN and subnormal made. **Recommended:** the
  rotation as D3 C's encoding in M5, with the VM's boxes for `-0.0`,
  the infinities and NaN beside zero's.
* **D4, headers: A as built; C is the owner's call.** The pairs pass
  every suite on every machine and save memory: 0.83 of the word's
  bytes on the bootstrap, 0.85 on MLton's set, a quarter to a third
  less copied, a fifth less kept at a collection (the bootstrap runs
  in 39.8 MB where the word needs 51.7), and 0.93 of the word's peak
  on MLton's set, though none of the compiler's, whose semispace
  doubles to the same 128 MB. They save little time: 0.92 to 0.97 on
  the kernels of
  lists and strings and nothing measurable on the compiler or on
  MLton's set (1.01 of the word's cycles in the mean), against
  the harness's promise of a quarter to a third; on the bootstrap
  they win 1% to 3% where the heap is tight and lose 5% where it is
  roomy. Their price is a
  second region in the heap, a mask where a tuple's or a constructor's
  field is read, and bytes and images that are per width. The third code costs
  nothing to keep back (0.067% of the bootstrap's bytes, nothing on
  the lazy programs): **recommended reserved**, for a lazy front end
  or for two raw reals. B and D, the 32-bit header and its table, are
  not built: the 32-bit VMs run the 8-byte word of D13 A.
* **D5, roots: A, with its price known.** The slots stay words, and
  the interpreter's shifts do not show outside real arithmetic. B is
  not built; SplitMix64 is the measure of what A costs a 64-bit word.

Not measured yet: `examples/benchmarks` at its `normal` profile, and
`runeopt`'s code beside the JIT's. `make test-lib` (22 programs) and
`make bench-smoke` pass on prototype 1, and `make test-laws` gives on
it what it gives on the 16-byte layout, law for law: 1,733 laws at
their structures, 1,318 passing, 313 failing, 102 stopped (run the
day of the gate, after it: its script had been broken by the rename
of the VMs' binaries, mended in `b3e6092e`).

### M5, the first step: the 64-bit types

Built on 2026-10-04 on branch `heap-layout-word` (`31872015` to
`ae2f8a8d`), which `heap-layout` was merged into first.

**What is there.**

* *The VM.* `int` and `word` are the immediate's 63 bits in the build
  with no switch: `Overflow` where an int would need a 64th, a word
  wraps there. 44 primitives `int64_*` and `word64_*` keep 64 bits on
  every VM: a number is an immediate where it fits 63 bits and a
  `K_BOX` where it does not, which is prototype 1's representation of
  D2 A, kept for the two types alone. The interpreter has their fast
  paths; `real_to_bits` and `real_from_bits` are `Word64`'s. Constant
  kinds 5 and 6, representations 9 and 10, bytecode version 6. The
  loader refuses an int or word constant past 63 bits and holds a
  `CONST` to its register by the constant's kind.
* *The compiler.* Two built-in type constructors, `Int64.int` and
  `Word64.word`, which the library names with `_prim "int64"` and
  `_prim "word64"` in a type (under `--allow-prim` alone). Their
  literals, in expressions and patterns, and the overloaded operators
  go to the primitives directly. A literal of `int` or `word` past 63
  bits is a compile-time error where it was a fatal error at load in
  the prototype. Folding is at 63 bits; the 64-bit primitives are not
  folded.
* *The Basis.* `Int64` (= `FixedInt`) and `Word64` are structures on
  the primitives; **`LargeWord` is `Word64`**, so `toLarge`,
  `toLargeX` and `fromLarge` of every word structure convert, and
  `PackWord`'s words and `PackReal`'s bits are `LargeWord`'s.
  **`SysWord` stays `Word` and `Position` stays `Int`**: Posix's flags
  and a file's positions fit 63 bits and stay out of boxes. `LargeInt`
  is `IntInf` as before.
* *The JIT.* A register the section says holds a 64-bit type has a
  raw home at tier 2, the 64 bits themselves (M4's `RUNE_RAW_HOMES`,
  now for those registers in every build), and 39 of the primitives
  are in line at both tiers, the conversions between the 64 bits and
  an int's or a word's 63 among them. aarch64 has them through the
  same macro-assembler.
* *D2 A behind its switch:* a VM built with `-DRUNE_INT64`
  (`bin/runevm-int64`) and a compiler given `--int-bits=64`. The
  property library's frozen hash of everything its generators draw
  moved in the default build, and under the switch the old value comes
  back to the bit: what changed is the width of `int` and `word` and
  nothing else.

**SplitMix64**, the workload D2's note asked for (`lib/random`'s
generator: three million words and a tree of 2^18 splits), at the
default tiering:

| VM | instructions | cycles | boxes |
|---|---:|---:|---:|
| 16-byte layout | 1.01G | 0.46G | none |
| prototype 1, 64 bits kept (M4) | 9.36G | 3.43G | 21.6M |
| the same with raw homes for every int and word (M4) | 2.11G | 0.82G | 8.3M |
| M5: 63-bit `int`, `Word64` its own type with raw homes | 2.20G | 0.95G | 11.7M |

The answer is the 16-byte VM's, where the 63-bit prototype of M4
printed another. What is left of the distance is the boxes: a
generator is two `Word64.word` in a tuple, passed at every call, and a
field of a tuple is a word of the VM (raw typed fields, D1's second
half, are what would hold them unboxed).

**The suites.** `test`, `test-register`, `test-register-jit`
(`check-jit` over 280 programs), `test-native`, `test-opt`, `test-ir`,
`test-lib`, `test-stress`, `test-register-asan`, `test-basis`,
`test-doc`, `check-docs`, `check-isa`, `check-templates`, `check-cross`
(the seven builds of the compiler, of `runedoc` and of `runeopt`
agree), `test-all`, `test-portability` (linux32, ppc64, aarch64 with
its JIT), `test-windows`, `test-census`, `check-heapsim`,
`check-layouts`, `bench-smoke` and `check-positions` pass. The Basis
suite is 139,216 checks (five more than before: the tests follow the
precision), all passing on the stack VM, one explained on the register
VM as before. The seven programs of `tests/lang` that named 64 bits of
`int` or `word` are at 63, and four new ones are their twins at the
64-bit types (`lex.int64_literals`, `rt.int64_overflow`,
`basis.int64_ops`, `basis.word64_ops`), their expected values checked
against a computation outside Rune. `perf-check` has two budgets
over, to move when the budgets are re-based: `compile-sigs` runs 5.4%
more instructions (a program that names `Word` now compiles
`word64.sml` too) and `word_bits` makes 25 more objects as it starts.

**Found on the way.** `check-cross` had not been run on prototype 1:
`runeopt` built by SML/NJ's 32-bit system (31-bit ints) raised
`Overflow` where a generated template made the word of a payload near
2^30 in the host's `int`; the generator writes that arithmetic in
`IntInf` now. `word_to_int_x` was a fatal error in the 63-bit
interpreter for a word of 2^62 or more, and the reals' rounding to an
int was fatal between 2^62 and 2^63: both are right at 63 bits.

**Not done in this step.** `runeopt` calls the 64-bit primitives' C
and does none in line; `word64_asr` and the reals' bits are not in
line in the JIT either; the middle end folds no 64-bit arithmetic.
None changes a result.

## The request

The owner's brief, as written:

> - this is a draft for a roadmap to improve rune's heap layout and garbage collector
>   - the heap-layout is first. advanced generational and concurrent collectors will be a separate roadmap after this unless your research find they are so related they need to be done in one roadmap
> - rune's current heap-layout is a leftover from the first runtime implementation and has not been toched even through several iteratons of compilers, bytecode and virtual machines
> - please take into account the following in progress and future roadmaps:
>   - plans/jit.md (currently in progress)
>   - plans/incremental-compilation (the follow after jit)
>   - ffi (no roadmap drafted yet)
>   - multithreading and high-core count support (no roadmap drafted yt)
> - you should consider all possible layout while designing the roadmap backed by actual experiments and benchmarks so a decision can be made on hard evidence
>   - redesigning the heap layout will be a substantial amount of work given the many places it touches in e.g. the jit compiller. we should do the hard work upfront to avoid having to do it a second time later
>   -  is suggest you build simulations of each thoroughly review their performance under a wide variety of workloads
> - you should do a thorough literature review and review of actual implementations
>   - i have left the source code of serveral compilers under /home/ruud/reference for you to study to see waht they do
> - each choice should be clear about any tradeoffs it makes
>   - e.g. i would consider having a 63-bit word a drawback over 64-bit word as many production code has been optimized to work with 64-bit words. so if we go for a heap designed with 63-words it should come with clear evidence of the performance benefits it brings

Two of the owner's notes frame it. `~/notes/virtual-machine.md` sets the
end state the layout must not close off: "very high-core count NUMA
machines", "no global locks and avoiding cache line bouncing and a
concurrent no-pause garbage collector", "millions of green threads", "an
in-VM isolated process framework", delimited continuations, possibly a
lazy front end, escape analysis "to predict memory allocation (size,
shape etc.) ... and exploit that in the VM & GC", an FFI "missing in
current Rune but it will be there", and "Always describe tradeoffs to me
and point to relevant literature". Region inference is "unproven ... Do
not treat it as a given". `~/notes/rune.md` says, under the VM: "we are
always 64-bit even on 32-bit platforms" -- which, the owner said on
2026-09-27, describes the architecture as it is, not a rule: they would
take 64-bit integers on 64-bit machines and 32-bit ones on 32-bit
machines, with one bytecode, if it costs nothing (D13).

**The owner's decisions after reading this roadmap (2026-09-27):** D1
B, and C later in the whole-program compiler if benchmarks show it
better; D2 B, 63-bit integers, against the recommendation ("int/word
are for things like length of lists and 63 bits is enough; for
algorithms that need word64 hopefully it will be monomorphic and get
unboxed"), and A behind a compile-time switch, as for the reals
(2026-09-27); D3 C, decided B at first ("and C benchmarked, may change my mind if it
helps") and changed the same day on the large set's numbers (Koka's
immediate encoding at polymorphic positions; the VM also builds with
B behind a compile-time switch, for benchmarks);
D4 A with C, headerless pairs, on 64-bit machines and B, the 4-byte
header, with D, the layout table, on 32-bit ones (changed on
2026-09-27 from A everywhere with B, C and D benchmarked); D5 A, and B benchmarked; D7 A; D11 keep `runeopt`, against
the recommendation; D13 B; D14: the JIT roadmap is finished, so nothing
waits; D15 accepted; D6, D8, D9, D10 and D12 as recommended (not
choices). Recorded in the *Decisions* table and per decision.

**The owner's decisions at the gate of M4 (2026-10-04)**, on the
prototypes' numbers, every recommendation of *M4, for the gate* taken:
D1 B, and M5 without raw typed fields (raw real fields are decided
after M5, on what the programs of reals still lose; flat real arrays
stay M8's); D2 B confirmed, with `Int64` and `Word64` as boxed types
of their own whose tier-2 homes hold the 64 bits, the first thing M5
builds; D3 C by the rotation encoding in place of Koka's, with a box
that the VM keeps for each of `+0.0`, `-0.0`, the infinities and NaN
(`real-encoding.md` has what is left to try); D4 A on every machine:
the headerless pairs of C are left out of M5 and kept as a branch,
bits 1 and 2 of a pointer stay unused for them, and the third code
stays reserved for a lazy front end; D5 A; D11 as it was, `runeopt`
kept; D13 A for M5, the 8-byte word on every width, where B had been
decided: the 32-bit VMs' own word, the 4-byte header and the layout
table (D4 B and D) were not prototyped and are `32-bit-vm.md`'s.
M5 to M8 are planned again below on these.

| The brief asks | Answered in |
|---|---|
| the layout first; the collectors after, unless they belong together | D7, *The experiments* (the coupling question), M7 |
| a leftover of the first runtime, untouched since | *Where we are*, *History* |
| jit.md, in progress | *Prerequisites and flags*, D14; jit D10's item 19 is decided here |
| incremental compilation, after jit | *Prerequisites and flags*, D10, D12 |
| the FFI, no roadmap yet | D9, M8, *Prerequisites and flags* |
| multithreading and high core counts, no roadmap yet | D8, M7, *Prerequisites and flags* |
| all possible layouts, on hard evidence | *The candidate layouts*, *The experiments*, D1 to D5 |
| the hard work upfront, so it is done once | *The architecture* (the interface), M3, M4's gate |
| simulations of each, under many workloads | *The experiments*: the simulator, the harness, the workloads |
| the literature and the implementations | *What the literature says*, *What the implementations do*, *References* |
| every choice clear about its tradeoffs; 63-bit words in particular | each decision's options; D2 with the census's and the harness's numbers |
| 64-bit on 64-bit machines, 32-bit on 32-bit, one bytecode, if it costs nothing (2026-09-27) | D13 |
| whether the layout suits a Haskell 98 front end, perhaps with a bytecode made for lazy languages; the findings added and their benchmarks done in M4 (2026-09-28) | *A lazy front end*; M4, M5, M7 |

## Where we are

### The layout today

A value is a `Value` of 16 bytes (`vm/vm.h:16-70`): a tag byte, seven
bytes of padding written out by hand, and an 8-byte payload that is an
`int64_t`, a `uint64_t`, a `double` or a pointer. The tags are `T_UNIT`,
`T_INT`, `T_WORD`, `T_REAL`, `T_CHAR`, `T_CON0` and `T_PTR`; the first
six are immediate, only `T_PTR` points into the heap. Unit is the
all-zero cell, and the JIT relies on that (`emit.c`'s fills are `xorpd`
and `movups`). There is no pointer tagging: a pointer is a plain
address, and what it points to is known from the tag byte beside it and
the header it points at. Under C11 the tag and its padding are also one
64-bit word, `hdr`, so that a value is built in two registers and stored
in two stores (jit M2 found a byte-wise tag store followed by a 16-byte
load stalling 38% of the fast path; `vm.h:29-36`).

An object (`vm.h:73-94`) is an 8-byte header -- `kind` (u8), `pad`
(u8, always 0), `contag` (u16), `len` (u32) -- and a payload rounded up
to a multiple of 16 bytes, at least 16 so that a forwarding pointer fits
(`vm/heap.c:1-15`). Every size is therefore 8 modulo 16, objects are
only 8-aligned, and a field is alternately 8- and 16-aligned, which is
why the JIT and `runeopt` load values with `movups`. The kinds:

| Kind | Payload | Bytes |
|---|---|---|
| `K_TUPLE` | `len` fields; a record, and a vector too | 8 + 16n |
| `K_CON` | a constructor with an argument: `contag` and 1 field, or the n fields of a tuple argument (`CONN`, middle-end M11, `src/backend/rep.sml`) | 24, or 8 + 16n |
| `K_CLOSURE` | field 0 a `T_INT` function index, fields 1.. the environment; `SETENV` writes them for `letrec` | 8 + 16(k+1) |
| `K_STRING` | `len` bytes, not NUL-terminated; `Word8Vector` and `CharVector` too | 8 + max(16, round16(len)) |
| `K_REF` | 1 field: the smallest object | 24 |
| `K_ARRAY` | `len` fields | 8 + 16n |
| `K_EXN` | the constructor and the payload, unit when there is none | 40 |
| `K_EXNCON` | the name; the identity is the address | 24 |
| `K_FORWARD` | during a collection: the new address in the first payload word | |

So a list cell is one `K_CON` of two fields, 40 bytes; `SOME x` is 24;
a tuple of three is 56. What is not there is as telling: `CharArray`
and `Word8Array` are `K_ARRAY`s of 16-byte cells, sixteen bytes per
byte (`lib/basis/mono_array_fn.sml:9`; a compact byte array is on
basis.md's list still); `RealArray` is 16 bytes per element;
`WideString` is a vector of 16-byte code points; `IntInf` is SML, a
`CONN` of a sign and a list of 30-bit limbs, 80 bytes for one limb
(`lib/basis/intinf.sml:1-25`; the owner's `rune.md` wants GMP);
`Real32` is a double rounded after every operation; `Int8` to `Int32`
and `Word8` to `Word32` are 64-bit immediates range-checked in SML.
There are no weak pointers, no finalisers, no foreign or pinned objects:
files, sockets and directory streams are `int` handles into the VM's
tables. `Int` and `Word` are 64 bits on every VM, the 32-bit ones
included (runtime.md, *Numbers*), at 1.4 to 1.8 times the cost there
(docs/performance.md); D13 asks whether they should stay so.

Two things the compiler knows and the heap does not. Since middle-end
M11 a constructor whose declared argument is a tuple of two or more is
one object of those fields, its tag in the header, chosen per datatype
(`rep.sml`); and since jit M8 the register bytecode carries, per
function, the representation of every register -- `any`, `int`, `word`,
`real`, `char`, a nullary constructor, `heap`, `either`, `unit`
(`docs/bytecode.md`, the representations section; `Lower.repOfTy`). The
heap is told none of it: every field is a 16-byte cell whatever its
type, and a polymorphic function runs on the same cells as a
monomorphic one. Nothing is monomorphised (middle-end M12 left it
unbuilt "since `vm/new` does not unbox").

### The collector today

`vm/heap.c` is 229 lines. `vm_alloc` (`:33-48`) bumps `heap_used` and
collects when the request does not fit, or every Nth object under
`--gc-stress`; it is the only C path, reached by both loops, the
primitives, `vm_cons`, the loader and a raise of a built-in exception.
The JIT's `ms_alloc` (`vm/new/jit/masm.c`) and `runeopt`'s template
(`src/opt/x64.sml`) copy the fast path -- the stress test, the room, the
bump, the counts, the header packed as one 32-bit store `kind |
contag << 16` and one of `len` -- and fall to C when it fails. Images
rebuild the heap without either (`vm/image.c`).

A collection (`collect_into`, `:99-138`) copies from the roots -- the
value stack below `sp`, the globals, the constants, each frame's
closure, the eight built-in exceptions (`:109-117`; the same list a
second time in `heap_relocate`, `:220-227`) -- with Cheney's scan, and
then `vm_gc` (`:158-184`) decides whether the heap grows: doubling until
the survivors are at most `--heap-fill` percent of it (50 by default),
guessed from the last two collections so that a growing program is not
collected twice (`9a3bc8a`). Both semispaces are kept (codegen M12: a
fresh to-space at every collection cost the kernel's page zeroing, 21%
of the native bootstrap's CPU). The collector's state is four
file-static variables; it is not reentrant and knows no thread. Nothing
polls: the compiler's target record says `barriers = false, safepoints =
false` (`src/core/target.sml:15-23`) and nothing reads them. There is no
write barrier because there is no generation: the stores into an
existing object are `ref_set`, `array_update` and `SETENV`, each in four
places (`vm/prims.c:1583,1607`, `vm/new/fastprim.h:150,157`,
`vm/new/reg_cases.h:352-362`, `vm/new/jit/emit.c`, `src/opt/x64.sml`);
everything else initialises a fresh object. Large objects have no space
of their own: an array of a gigabyte is copied at every collection. The
heap has no cap; the stack has one since jit M9. (Since `fd10179`,
2026-10-01, it has: `--heap-limit`; *After the rebase*.)

The primitives (297; `vm/prims.c`, 2,148 lines) read their arguments on
the value stack and pop them only when the result exists, so that a
collection inside the call finds them (`prims.c:1-19`); C code holds no
heap pointer across an allocation (architecture.md, the GC discipline),
and `--gc-stress 1` with the sanitiser build is how a violation is found.
`values_equal` (`vm/runtime.c:115-152`; since `fd10179` with a stack of
its own and a work limit) walks objects by kind for
polymorphic equality; `imm_eq` compares tags and bits where the
simplifier knows the type has no heap values (middle-end M11).

### Images and counts

An image (`vm/image.c`, 766 lines; version 6, and 7 since `fd10179`) writes every value in 9
bytes, tag and payload, with a pointer as its offset in the heap plus
one, and the heap object by object -- kind, contag, len, then the fields
or the bytes -- so that any VM restores what any other saved, across
widths and byte orders (runtime.md, *The system layer*). The reader
rebuilds the heap at the same offsets with `obj_size`: the format assumes
the 8-byte header, the 16-byte cell and the rounding to 16 without
saying so. `src/opt/rbcimage.sml:58-83` repeats the same arithmetic in
SML for `runeopt --from-image`, and `vm/native_offsets.c` names every
offset the templates use. The heap is not collected before it is
written: an image carries the garbage of the moment.

`runevm --count` reports instructions, bytes and objects allocated, and
the three depend on the program and its input alone (runtime.md, *The
same run twice*): the budgets of `tests/perf` hold them (bytes and
objects are the layout's, so every `.budget` moves with it); the
portability suite requires the counts of `bin/runevm`, `runevm32.exe`,
`runevm-new32` and the PowerPC VM to agree to the byte; `check-new`,
`check-jit`, `test-native` and `run-counts` hold every engine and every
tier to the same numbers. A change of layout keeps that oracle -- the
counts stay exact per engine and equal across widths -- and re-bases
every budget once.

### Who depends on the layout

What the heap map of this roadmap counted, by file: the lines that name
a tag, a kind, an `OBJ_` macro, `sizeof(Obj)`, a literal 16 or 8 of the
layout, or an `mk_` constructor.

| Where | What it knows | Lines of the file that know it |
|---|---|---|
| `vm/vm.h` | defines everything; `vm_expect_obj`; the frame's `Obj *closure` | 47 of 431 |
| `vm/heap.c` | allocation, the collector, relocation, `obj_size` | 58 of 229 |
| `vm/image.c` | the 9-byte value, offsets, the kind range | 49 of 766 |
| `vm/runtime.c` | `vm_cons`, `values_equal` by kind, exceptions | 56 of 294 |
| `vm/prims.c` | `check_tag`/`check_obj` everywhere; strings by `OBJ_BYTES`; a list walk needs a 2-field `K_CON`; `SOME` is `K_CON` 1; `order` is `CON0` 0/1/2 | about 593 of 2,148 |
| `vm/loader.c`, `vm/isa_stack.c`, `vm/new/isa_regs.c` | constants as values; the rep lint maps constant tags to `REP_*`; `contag` bounded to 65,535 | 26 |
| the stack loop (`vm/interp.c`, `interp_cases.h`, `ops.h`, from `src/isa/stack.sml`) | every instruction body | about 68, and 63 in the description |
| the register loop (`vm/new/interp.c`, `reg_cases.h`, from `src/isa/regs.sml`) | the same | about 68, and 63 |
| `vm/new/fastprim.h` | inline primitives by tag, kind and `len`; `HEAP_STORE` | 71 of 174 |
| `vm/new/jit/masm.c`, `masm.h` | slots at 16k, payload at +8, `offsetof(Obj, ...)`, the header packing, homes carry tags | 36 of 362 |
| `vm/new/jit/emit.c` | 29 sites of 16 or `shl 4` or +8, 19 `Obj` offsets, 101 tag or kind uses; the closure's index at `sizeof(Obj)+8`; unit is zero | 143 of 1,059 |
| `vm/new/jit/compile.c` | `jit_fill`; the entry fills unit; `choose_homes` maps reps to tags | 24 of 875 |
| `src/opt/x64.sml` (`runeopt`) | the slot formula, `8+16n`, the header as one `movl`, `shl $4`, `movb $T_*`; about 59 inline primitives | 141 of 968 |
| `vm/native_offsets.c`, `vm/native.c` | every offset by name; the slow paths | 38 |
| `src/opt/rbcimage.sml` | the image's arithmetic again, in SML | 193 |
| the compiler | `Rep`, `Lower.repOfTy`, `Simplify.immediate`, `Target.intBits = 64`, `Low.rep` | representations, not bytes |
| `lib/basis` | `runtime_sig.sml:45-48` states 16, 24 and 40; `intinf.sml`; `IntN`/`WordN`/`Real32` in 64-bit immediates; byte arrays as cell arrays | |
| tests | `tests/basis/runtime.sml:40-53` (40 and 24), `tests/new/masm_test.c:70-73`, every `.budget`, the count equality of `run-portability.sh:94-103`, `run-windows.sh:184-193`, `check-new.sh`, `check-jit.sh`, `run-counts.sh` | |
| docs | runtime.md, bytecode.md, architecture.md, building.md, native.md, `vm/new/ARCHITECTURE.md`, `share/man/runevm.1`, the generated `RUNTIME.md`; `examples/runtime/stats.sml:23-25` still says a list cell is two objects | |

M3 (2026-09-27) counted again, by the same rule, after the rewrite:
`vm/value.h` 40 lines (the definitions and every operation),
`vm/new/jit/masm.c` 25 (the same operations as machine code, its
numbers asserted against `value.h`), `src/opt/x64_layout.sml` 41
(generated from `masm.c`), `vm/native_offsets.h` 5 (the table of names).
Elsewhere: `prims.c` 0, `runtime.c` 0, the two loops' descriptions 1
each (the store hook by name), `fastprim.h` 0, `emit.c` 0, `compile.c`
0, `x64.sml` 3 (runeopt's frame-slot addressing form, its own
convention), `rbcimage.sml` 0 (its rounding and sizes from
`X64Layout`), and in `heap.c`, `image.c`, `loader.c` and `runtime.c`
the size of a `Value` as a C type for the arrays of them, 9 in all.

The counts above were taken at `228b7b7`. Jit M11 and M12 have since made
`emit.c` 1,054 lines, `masm.c` 348 and `compile.c` 897, and moved the
machine encoders into `asm_x64.c` and `asm_a64.c` (152 and 155 lines),
which name no layout fact; the layout lines are where they were. Two
of those are copies of the fast path by hand: the JIT's emitters and
`runeopt`'s templates, and native.md's *Keeping it in step* says so. A
third copy, in SML, is the image's arithmetic. M3 makes them one.

### History

The first VM came in the fourth commit of the repository, `c8880bc`
(2026-09-17, "Middle end, codegen, emitter, C VM, basis library"), with
this `enum Tag`, these nine kinds, this `struct Obj`, this rounding and
this collector. Since then `vm/heap.c` gained object counts and
`--gc-stress` (`4e99e4f`), the collector's time (`f227fd2`), 32-bit-safe
growth (`ed48e8c`), relocation for images (`cbfe379`), kept semispaces
and `--heap-fill` (`769bec1`) and the growth guess (`9a3bc8a`); `vm.h`
gained the explicit padding when the i386 ABI made the value 12 bytes
(`d32f8ce`) and the `hdr` word (`53681ee`). The header, the tags, the
16-byte field and the algorithm have not changed. The owner's premise
holds.

### The measurements

Taken for this roadmap on 2026-09-26 at `228b7b7` (*The experiments*,
*Today's VM*): an idle machine under a lock, `scripts/perf-cycles.sh`
with the additions M1 proposes (`--gc`, `--events`, `--vm-opts`,
compile-sigs and runedoc as programs), the least cycles of five runs of
`perf stat`, the profiles from a frame-pointer build of the same tree
under `perf record` with three runs aggregated. The bootstrap runs from
a 64 MiB semispace as `make perf` runs it. Every number a later
milestone compares against is here, or is made again by the scripts
of M1 and M2 (`tests/out/heapsim`, `tests/out/layouts`).

**The bootstrap today**, in four configurations (`rune` = `runevm`, the
stack VM; `jit-off` = `runevm-new --jit=off`; `new` = `runevm-new` as it
runs by default, tier 2 by the counters since M10; `opt` = `runeopt`'s
native program):

| | rune | jit-off | new | opt |
|---|---:|---:|---:|---:|
| cycles | 14.66G | 12.79G | 6.64G | 7.15G |
| instructions | 23.21G | 21.50G | 6.39G | 6.82G |
| instructions per cycle | 1.58 | 1.68 | 0.96 | 0.95 |
| task-clock | 4.92 s | 4.48 s | 2.45 s | 2.75 s |
| page faults | 232.5k | 232.9k | 234.8k | 232.6k |
| cache misses (sampled) | 18.0M | 18.5M | 18.3M | 17.8M |
| L1d load misses (sampled) | 120.8M | 129.4M | 87.1M | 78.7M |
| store-forward blocks, `r0203` (sampled) | 59.4M | 60.6M | 52.7M | 64.9M |
| collections | 7 | 7 | 7 | 7 |
| bytes allocated | 1.087G | 1.087G | 1.087G | 1.087G |
| bytes copied | 323.9M | 339.1M | 339.1M | 323.9M |
| largest live | 63.1M | 65.9M | 65.9M | 63.1M |
| collector's time (`--stats`) | 452 ms, 9.2% | 485 ms, 10.8% | 448 ms, 18.3% | 449 ms, 16.4% |
| collector's cycles (profile) | 7.6% | 9.4% | 17.1% | 15.9% |

What the table says:

* **The collector is the same work in every configuration** -- 1.12 to
  1.20G cycles for 324 to 339 MB copied in seven collections, 3.35 to
  3.53 user cycles per byte copied (4.3 to 4.7 by the `--stats` clock,
  which counts the semispaces' page faults) -- and its share is what
  the engine leaves it: 7.6% under the stack interpreter, 17.1% under
  the JIT, where `copy_obj` is the largest single symbol (14.0%; 13.1%
  in native code). The 27% performance.md measured for native code in
  September was a bootstrap that allocated 1.27 GB, collected 25 times
  from a 4 MiB heap and copied 846 MB; today's allocates 1.087 GB after
  the middle end, starts at 64 MiB and copies 324 MB. The register
  bytecode keeps a few more values live (65.9 against 63.1 MB) and
  copies 15 MB more.
* **The bootstrap's live data peaks at about 80 MB, not 205.** The
  collector sees 63 to 70 MB at its instants and 83 MB at the most in
  the sweep's tighter heaps; performance.md's 205 MB predates the
  middle end's shrinking of the compiler's data.
* **The JIT and native code are memory-bound:** under one instruction
  per cycle on the compiler against 1.6 to 3.4 in the interpreters and
  on the compute-bound perf programs. Both L1d misses and dTLB misses
  fall step by step as the heap grows (below), so the collector is the
  larger part of the memory traffic.
* **The 16-byte value stalls the store-to-load path.** `r0203`,
  LD_BLOCKS.STORE_FORWARD, is 52 to 65 million on the bootstrap in
  every configuration and 19.6M on `fib` and 14.2M on `real_nbody` in
  native code, where tier 2 -- which builds a value as a header word and
  a payload word since jit M2 and keeps homes in registers -- shows 977
  and 1.7k: a value written in two halves and read back as one 16-byte
  load is a stall the layout causes and an 8-byte word cannot.

**Where the time goes** (the profiles, percent of cycles; the collector
includes the `memcpy` `copy_obj` calls):

| Group | rune | jit-off | new | opt |
|---|---:|---:|---:|---:|
| dispatch | 73.98 | 80.72 | 1.13 | 0.04 |
| collector | 7.61 | 9.36 | 17.12 | 15.86 |
| allocation | 4.59 | 5.02 | 0.59 | 0.85 |
| primitives | 9.00 | 0.35 | 0.48 | 0.55 |
| `values_equal`, `imm_eq` | 1.27 | 0.47 | 0.79 | 0.76 |
| string primitives | 1.55 | 1.58 | 1.46 | 2.47 |
| JIT code | | | 71.30 | |
| native code | | | | 76.73 |
| the JIT compiler | | | 2.74 | |
| `memmove`, other callers | 0.80 | 1.10 | 0.95 | 0.21 |
| other | 1.21 | 1.41 | 3.44 | 2.53 |

Under the JIT the top symbols after `copy_obj` (14.03) are the
compiler's own loops: `fn` 5.05, `IntTable.lookup` 4.48, `map` 3.60,
`IntTable.find` 3.42, `collect_into` 2.59, `app` 2.21, `StringMap.go`
1.78, `IntTable.update` 1.76 -- the data structures the harness runs
(*The experiments*). compile-sigs, a run of 0.27 s, spends 19.4% of its
cycles in the JIT compiler itself and 6% interpreting before tiering,
which is the incremental roadmap's concern, not this one's.

**The heap-size sweep** (DaCapo's method: `--heap-fill 100 --heap-size
k·L`, L the largest live size the collector saw, so that the semispace
stays fixed; the least of three runs; the collector's nanoseconds per
byte copied from `--stats`):

| bootstrap | k = 1.25 | 1.5 | 2 | 3 | 4 | 6 | 8 | 2 GiB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| semispace | 86.5M | 103.8M | 138.4M | 207.6M | 276.8M | 415.2M | 553.6M | 2.15G |
| collections | 40 | 22 | 12 | 6 | 4 | 2 | 2 | 0 |
| bytes copied | 2.44G | 1.30G | 689.5M | 355.9M | 238.3M | 97.1M | 134.2M | 0 |
| new: cycles | 11.24G | 9.22G | 7.51G | 6.93G | 6.65G | 6.51G | 6.45G | 5.77G |
| new: task-clock | 3.62 s | 2.95 s | 2.44 s | 2.30 s | 2.28 s | 2.66 s | 2.53 s | 2.42 s |
| new: ns per byte copied | 0.73 | 0.82 | 0.90 | 1.17 | 1.41 | 1.77 | 1.58 | |
| opt: cycles | 10.77G | 9.25G | 7.62G | 7.50G | 6.97G | 6.39G | 6.72G | 6.19G |
| jit-off: cycles | 17.16G | 14.71G | 13.56G | 12.64G | 12.35G | 11.92G | 12.41G | 11.82G |
| new: dTLB load misses | 37.0M | 24.9M | 17.4M | 14.0M | 12.4M | 9.2M | 11.4M | 6.7M |
| new: page faults | 47.6k | 56.1k | 73.0k | 106.8k | 140.5k | 208.1k | 275.7k | 270.8k |

The knee is at two to three times the live size. From k = 1.25 to 2 the
JIT's bootstrap drops from 11.24G to 7.51G cycles (40 to 12 collections,
2.44 GB to 690 MB copied); from 2 to 4 only to 6.65G; and a heap that
never collects runs in 5.77G. The collector costs 0.7 to 0.9 ns per byte
copied while the heap is small enough for the survivors to be warm in
the caches and 1.2 to 1.8 ns when every collection walks a cold heap;
the usual run pays 1.3 to 1.4. The difference between the 1.25x heap
and the uncollected one is 48.7% of the 1.25x run under the JIT, 42.5%
in native code and 31.2% under the interpreter; against the usual run
the uncollected heap saves 13.1%, 13.4% and 7.6%. Past k = 6 the
remaining cost is the first touch of fresh pages, not copying: 271k
faults at 2 GiB against 48k at k = 1.25, and compile-sigs in native code
is slower uncollected (712M cycles) than collected twice (585M). So the
levers are two, and the sweep prices both: bytes copied, which the
layout halves and a nursery stops re-copying, and the working set's
misses, which fewer bytes per object reduce at every heap size. `--stats`'s
`live` is `heap_used` at exit, not live data (compile-sigs: 38 MB
against 12 MB largest live); M1's `max live` and `copied` fields are
what the sweep used.

**What the census says of the bootstrap** (`bin/runevm-census`, *The
experiments*; 458,049,104 instructions, 1,087,242,208 bytes, 24,051,664
objects, identical to the stock VM's `--count`): 62% of the bytes are
constructors with arguments, 20% tuples, 8% closures, 5.5% arrays (77
thousand of them, the hash tables' 64-slot arrays), 2.4% refs, 1.8%
strings. One shape is 27% of every byte allocated: the list cell, 7.4
million of them at 40 bytes; the compiler's balanced-tree node (a
constructor of five fields) is 12%, the pair 12%, a constructor of one
field 7%, the triple 6%. Of the 55 million fields written at
allocation, 56% hold a pointer, 23% an int, 19% a nullary constructor,
1.7% unit, 0.5% a char, and none a word or a real; of the ints, 48% fit
8 bits and every other one 31, except two constants, `Int.minInt` and
`Int.maxInt`. Of 25 million integer results of primitives, 19,397 exceed
31 bits (0.08%, the hash functions' multiplications) and four exceed 63,
at start-up; 69 word results in all, one of 64 bits. Nothing in the
compiler makes, passes or stores a real. Half the bytes (48.7%) are
allocated at sites whose every source register has a known
representation; 24% of fields come from a polymorphic register. Stores
into existing objects: 4.23 million, of which 2.69 million `:=`, 1.53
million `Array.update` and 8,863 `SETENV`; 2.25 million store a
pointer, and 99.95% of those store it into an object older than the
value -- the remembered-set traffic a nursery would see; 26.5% of the
`:=`s go into objects older than 32 MB of allocation (the compiler's
tables), and every `SETENV` into an object younger than 256 KB, so a
`letrec` closure never needs a barrier. Live data at exit 48.7 MB. The
first-order size of the same objects under each layout (`layouts.h`,
before any collector): the tagged word 0.591 of today; with headerless
pairs 0.502; a 4-byte header saves 0.03%; 16-byte alignment costs it
back (0.696); boxing ints at polymorphic positions under an untagged
layout gives it back too (L4-mono 0.632, L4-uniform 0.707); NaN-boxing
and a 64-bit box cost nothing on the compiler (two fields and four
results). compile-sigs is the same picture at a tenth the size (0.592,
0.511, 0.611, 0.689), with 14.1 MB live at most.

## What is different for SML

Most of what a heap layout does in a dynamic language it does because
the program does not know its types. Rune knows them, and since M8 the
bytecode says what each register holds. That moves the tag's purpose: it
no longer serves the program, only four things around it.

**What the tag is for, here.** The collector, which must know which
words are pointers; polymorphic code, which runs one body on `int`s and
on lists and needs them the same size; structural equality, ordering and
hashing on polymorphic types, which walk objects without a type; and the
things that read a value with no program beside it: images, the REPL's
printer (incremental-compilation.md D10 rests on "every value carries
its tag"), `--trace`, a fatal error's message. Everything else that a
JavaScript engine's tag does -- dispatch on the operand's type, guard a
speculation, box on demand -- has no counterpart. So the question is not
whether the program needs a tag but how cheaply those four can be served:
by a byte beside every value (today), by a bit in the word (OCaml,
SML/NJ, Poly/ML, Chez), by the object's header and the frame's map alone
(MLton), or by a mixture.

**Immutable data.** A tuple, a constructor, a closure's environment, a
string and a vector are never written after they are made; the stores
into an existing object are `:=`, `Array.update` and the `letrec` fix-up
`SETENV`, and nothing else -- three sites per engine (*The collector
today*). That is what makes a generational collector cheap for ML and
was so from the start (Appel 1989; Reppy 1993): old-to-young pointers
arise only at those stores, so a barrier costs a few instructions at a
few places and a remembered set stays small. It is also what makes a
per-thread young heap simple (Doligez and Leroy 1993; Manticore, OCaml 5):
an immutable object may be shared by copying it, and only the mutable
ones need a rule. The layout question this raises is whether to tell
mutable objects from immutable ones by kind (`K_REF`, `K_ARRAY`,
closures with `SETENV`), by a header bit, or by where they are put
(Poly/ML's mutable areas need no barrier at all).

**Allocation, and the shape of it.** The bootstrap allocates 1.12 GB in
24.6 million objects, 45 bytes each on average (`tests/perf/new/
bootstrap.budget`); most are tuples, closures and constructors of one to
three fields, and most die young (*The experiments* gives the survival
by nursery size). Allocation is a bump in line already, in the JIT and
in `runeopt`; what the layout decides is how many bytes that bump takes
and how much of it the collector copies again. Halving the cell halves
both, before any collector changes.

**Integers and words are 64 bits, and `Int` raises `Overflow`.** Today's
architecture ("always 64-bit even on 32-bit platforms") and the Basis
Library's `Int.precision = SOME 64`, `Word.wordSize = 64` are the
language a user sees; `word_bits`, hashes, `IntInf`'s limbs and the
compiler's own `Word` arithmetic use the top bits. OCaml, SML/NJ, Poly/ML
and MLKit-with-GC give the language a 63-bit `int` and box the 64-bit
types; MLton keeps 64 bits by knowing the type of every field. Any
tagged 8-byte word must either take a bit from the integer or box the
integers that need it, and D2 weighs that with the census's count of
how many values need all 64 bits. Where a 63-bit int helps is the
overflow check: SML must raise `Overflow`, which a tagged addition
detects with the same `jo` as a 64-bit one.

**Reals matter less, and are immediate today.** `real_nbody` allocates
30 objects; every arithmetic result is a 16-byte cell. Under a tagged
word a real is boxed (OCaml: 3 words per `float`; SML/NJ; Poly/ML), kept
in registers within a function by the compiler, or encoded immediate
when its exponent allows (Koka). The census counts how many reals a
program makes, how many cross a call and how many are stored; those
three numbers say what each choice costs, and the JIT's homes (M9)
already keep a real in `xmm` registers within a function.

**Polymorphism, without monomorphisation.** A polymorphic function's
argument is any value, and the compiler does not clone the function per
type (middle-end M12: not built). So a position of representation `any`
must hold every value in the same size: the cell today, a tagged word
under L1 to L3, a pointer or an immediate under L4 -- where an `int` in
a polymorphic position is boxed, as GHC boxes an `Int` in a list. The
static census says how much of the compiler's code is at `any`; the
incremental roadmap's units make whole-program monomorphisation
permanent work rather than a pass.

**The frames are the VM's and the slots are self-describing.** At every
tier a frame is slots on the value stack, and the collector's roots are
the slots below `sp`, precise by tag and conservative in liveness
(jit.md, *The runtime the JIT lives with*). This is what item 19 puts
in question: with an untagged word a slot's meaning must come from a map
per pc -- which the register bytecode can carry, since it knows each
register's representation and, with liveness, which are live -- or from
a tag bit in the word, which keeps the stack self-describing as Poly/ML's
is. jit M11's maps at tier-2 safepoints arrive either way.

**One program on five engines, at every width, in every byte order.**
The bytes and objects `--count` reports are the oracle that holds
`runevm`, `vm/new` at three tiers, `runeopt`'s code, the 32-bit VMs and
the PowerPC VM to one answer, and the portability suite carries an image
between them all. A layout is chosen for x86-64 and must still be
counted on i386: an 8-byte slot on every width, as the 16-byte cell is
16 bytes on every width, keeps the bytes equal too; a slot of the
pointer's width keeps objects and instructions equal and lets the bytes
differ, which is what a native word per machine costs the oracle (D13).
The web-native brief adds wasm32 to that list later.

**No identity hash, no locks, no finalisers.** SML has no object
identity but `Runtime.same` and the exception constructor's address;
there are no monitors, no `hashCode`, no weak references and no
finalisation in the language or the Basis. Java, .NET and Julia spend
header bits on those; Rune need not, and can spend them on the
collectors to come.

**Exceptions allocate.** A raise makes a `K_EXN` of 40 bytes, and
programs raise in loops (middle-end.md: the bootstrap installs 34,991
handlers). A nullary exception could be an immediate, as a nullary
constructor is; D4 notes it and M5 measures it.

## What the literature says

Each item: what it is, why it was built that way, what was measured,
and what of it transfers to a strict, typed language whose bytecode
already says what each register holds. Numbers are the sources' own;
the *References* give them, and where a source could not be read in
full the number is not quoted.

### Value representation

* **Tags in the word, and their cost.** Steele's memo of 1977 is the
  origin of the low-bit tag as MacLISP used it on the PDP-10; Gudeman
  (1993) surveys the schemes -- low-bit tags, high-bit tags, NaN-boxing,
  BIBOP typing by address, typed pointers -- with the operations each
  makes cheap, costed in the cycles of a generic RISC: a low-tag type
  test is one to three cycles, untagging two, a pointer dereference
  free when the tag is folded into the field's offset (Chez's `car` at
  +7), and an addition, subtraction or multiplication that must detect
  overflow four cycles more on tagged integers than on raw ones, where
  a high-end tag costs six (the report, sections 2.1 to 2.3). The
  report's "hybrid techniques" -- tagged words with typed objects
  behind them, partitioning by magnitude, typed locations -- are the
  design space L1 to L5 walk. *Transfers:* the tagged word of D1 B is
  the scheme every ML in the survey settled on; its arithmetic cost is
  the harness's to measure, and the harness agrees with the report's
  arithmetic: an overflow-checked add is 1.0 cycles on the word and 2.2
  with a box test (*The experiments*).
* **Unboxing by type.** Leroy (1992) gave a typed language a mixed
  representation -- unboxed where the type is known, boxed at
  polymorphic boundaries, with coercions inserted by the type checker
  -- and measured it in the Gallium compiler; Peyton Jones and
  Launchbury (1991) made unboxed values first-class in the compiler's
  intermediate language, which is how GHC unboxes by worker/wrapper
  today; Shao and Appel (1995) built representation analysis into
  SML/NJ; Harper and Morrisett (1995) and Tarditi et al. (1996) went
  the other way in TIL, passing types at run time so that polymorphic
  code can unbox too ("intensional type analysis"), at the cost of
  type-passing and a heavier compiler. Leroy's prototype found "important speedups on some programs", little
  effect on others and one contrived program slowed; Shao and Appel's
  type-based optimisations cut SML/NJ's heap allocation by 36% and made
  its code about 19% faster (the abstracts; TIL's numbers were not
  read). *Transfers:* Rune's
  representations section is the type information those systems
  computed; D1 B uses it where a field's type is known and boxes at
  `any`, which is Leroy's design with the coercions at the compiler's
  `Store` and `Load`. TIL's road, types at run time, is what D1 C would
  need for polymorphic code and is not taken.
* **Tag-free collection.** Appel (1989, "Runtime tags aren't
  necessary") argued that a typed language's collector can recover
  every object's layout from the types of the roots, keeping tags only
  for the variants of a datatype, and priced what SML/NJ's tags and
  descriptors then cost: descriptors 26% of the space and 2.2% of the
  instructions to make them, tag bits 3.1% of the space and 1.65% of
  the instructions to strip and re-attach, "about 28% in space and 4%
  in time" in all (the paper, section 5); Goldberg (1991) and Tolmach
  (1994) built it, with type parameters passed to make polymorphic
  frames scannable. Nobody in the survey ships it; MLton
  gets the same effect by monomorphising and by a header per object.
  *Transfers:* the reason D4 keeps a header: a descriptor per object is
  cheaper than types at every call, and the incremental roadmap's units
  make whole-program typing unavailable anyway.
* **The tag in the pointer.** Marlow, Yakushev and Peyton Jones (2007)
  put a constructor's number, or a value's evaluatedness, in a
  pointer's low bits so that a `case` on an evaluated value needs no
  load and no indirect jump: a 14% improvement for 2% more code, "much of the improvement" from
  the branch mispredictions the load and jump had caused (the paper). Chez, Guile and MLKit do the same for pairs and unboxed
  datatypes. *Transfers:* D4 C (L5), where the census's share of
  two-field constructors and the harness's `case` cost say what it is
  worth for a strict language that has no thunks to test.
* **Headerless objects and typed storage.** Dybvig, Eby and Bruggeman
  (1994, "Don't stop the BIBOP") describe Chez's hybrid: three low tag
  bits in the pointer for the common shapes (pairs, symbols, closures,
  fixnums, characters) with 8-byte alignment, a type word in the object
  for the rest, and a "metatype" per 4 KB segment for what only the
  collector needs -- whether a segment's objects hold pointers, whether
  they are mutable, their generation, code and stacks apart -- so that
  the collector sweeps no pointerless object, records old-to-young
  pointers only for writable pointer-holding segments, and leaves a
  large object in place by changing its segment's entry rather than
  copying it. Metatypes are assigned when an object survives its first
  collection, so the allocator keeps one pointer and "the segmented
  model results in no overhead outside the garbage collector" (the
  report, sections 3 to 6); frames carry a live-pointer mask behind the
  return point, which the report likens to Appel's tag-free records.
  SML/NJ's pair arena is the same idea applied at promotion.
  *Transfers:* L5's segregated space and its forwarding without a
  header; D8's mutable-by-kind rule; M7's large-object flag; the cost
  is a segment table lookup per pointer the collector scans, "a few
  bytes per 4K segment".
* **Closures and stacks.** Shao and Appel (1994) measured closure
  representations (flat, linked, shared) in SML/NJ; Appel and Shao
  (1996) measured heap-allocated frames against stack frames and found
  the heap's cost small when the collector is generational and the
  cache is considered. *Transfers:* Rune's closures are flat and its
  frames are the VM's stack; neither changes here.
* **Spare bits.** Swift's and Rust's enum layouts (survey) put a case in
  the bits a pointer payload cannot use; MLton's `PackedRepresentation`
  does the same for sum types with pointers. *Transfers:* a nullary
  constructor beside a pointer in the same word is what the tagged
  word's spare patterns give for free.

### Roots and maps

* Diwan, Moss and Hudson (1992) gave an optimising compiler for a
  typed language (Modula-3) precise stack maps, including derived
  pointers, and found "no significant changes" in the sample programs, tables "a
  modest fraction of the size of the optimized code" and stack tracing
  "a small fraction of total gc time" (the abstract); Agesen, Detlefs and Moss (1998)
  measured what liveness-precise maps buy in a JVM (the abstract, truncated where it says what the liveness analysis
  produces). Boehm and Weiser (1988) and Boehm
  (1993) are the conservative alternative, which Guile takes and Rune
  does not (jit D4: nothing on the machine stack). *Transfers:* D5's
  choice between a self-describing stack (no maps, Poly/ML's way) and
  maps per pc; jit M11 builds maps for tier 2's registers regardless,
  and roots precise by liveness (M6) are Agesen's gain.

### Collectors for a strict ML

* **Copying and generations.** Cheney (1970) is the copier `heap.c`
  is; Ungar (1984) is the generational idea and its measurement
  (survival of young objects a few percent); Appel (1989, "Simple
  generational garbage collection and fast allocation") is its form
  for ML: one young generation collected by copying, allocation as a
  bump with the limit test, and the observation that the cost of a
  collection is proportional to live data so that a large young
  generation makes collection cheap; Reppy (1993) is SML/NJ's
  multi-generational collector -- an allocation arena and up to
  fourteen generations, each split by object class, with a store list
  of "two or three instructions, and only one memory reference" per
  update as the nursery's barrier and card marking between the older
  generations -- which cut total CPU time by 10% on a SPARC and 20% on
  an SGI against the collector before it, with "less than 1% of live
  data" mutable and 60% of the updates to it remembered, pairs 20 to
  30% of the non-code objects and their dropped descriptor "a 10-15%
  space savings", and a card scheme that records the youngest
  generation referenced and so sweeps 80% fewer cards (the memo,
  sections 2, 5 to 7);
  Sansom and Peyton Jones (1993) found that a lazy language's thunk
  updates make old-to-young pointers common where a strict one's
  stores are rare. *Transfers:* the next roadmap's nursery, and this
  one's D7: the simulator's survival and remembered-set numbers on
  Rune's traces are these papers' measurements on Rune's programs.
* **Where the time goes.** Tarditi and Diwan (1996) measured storage
  management in SML/NJ with the cache included and found that "the cost
  of storage management is not the same as the time spent garbage
  collecting": for many programs the collector's time was less than the
  rest of storage management's, and the store list cost 0 to 1% of
  execution during mutation and 0 to 6% during collection (the report);
  Wilson, Lam and Moher (1992) found that a garbage-collected system's
  cyclic reuse of memory defeats a cache whose size is below the reuse
  cycle -- the youngest generation -- so that "allocation is the
  problem, not garbage collection per se", that for a cache larger than
  the youngest generation conflict misses from rapid allocation are the
  majority and set-associativity halves them, and that careful sizing
  "can avoid a several-percent performance hit" that grows as
  processors outrun memory (the paper, sections 2 and 7); Zorn (1991)
  the same for older machines. Blackburn, Cheng and McKinley (2004,
  "Myths and realities") measured collectors against each other in one
  framework and found a generational copying nursery the best for
  throughput and mutator locality at moderate heap sizes; Hertz and
  Berger (2005) found tracing collection matches explicit management
  only with about five times the memory: with three times it ran 17%
  slower on average, with twice it lost nearly 70% (the paper).
  *Transfers:* D15's targets include `task-clock` and cache misses,
  not cycles alone; the heap-size sweep of *The experiments* is the
  DaCapo method these papers use.
* **Non-moving and concurrent old spaces.** Blackburn and McKinley
  (2008, Immix) collect an old space by marking lines and blocks and
  compacting opportunistically, which improved total performance "by 7 to 25% on average" over the
  canonical algorithms and, as the mature space of a generational
  collector, matched or beat a tuned one (the paper); Detlefs et al. (2004, G1), Tene, Iyengar
  and Wolf (2011, C4) and Zhao, Blackburn and McKinley (2022, LXR) are
  the concurrent and low-latency designs a high-core-count machine
  wants; Doligez and Leroy (1993) and Doligez and Gonthier (1994) gave
  ML a concurrent major collector with per-thread young heaps, on the
  rule that an immutable object may be copied and a mutable one lives
  in the shared heap, which OCaml 5 (Sivaramakrishnan et al. 2020)
  re-derived with a stop-the-world minor collection instead; Marlow and
  Peyton Jones (2011) tried local heaps for GHC; Auhagen, Bergstrom,
  Fluet and Reppy (2011) built Manticore's split heaps for NUMA; Cheng
  and Blelloch (2001) a parallel real-time collector for an ML.
  *Transfers:* the header bits, the barrier's shape, the address range
  and the mutable-by-kind rule this roadmap fixes (D4, D7, D8) are what
  every one of these needs; none needs anything of the word itself.
* **Reference counting, regions.** Reinking, Xie, de Moura and Leijen
  (2021, Perceus) and Lorenzen and Leijen (2022) make counting precise
  and reuse objects in place, with the compiler inserting the counts;
  Tofte and Talpin (1997), Hallenberg, Elsman and Tofte (2002) and
  Elsman and Hallenberg (2021) infer regions and add a collector to
  them. *Transfers:* the owner's note leaves regions as an experiment,
  not a given; Perceus needs a refcount word per object that this
  header could reserve but does not; the escape analysis the owner's
  note wants is the compiler's and fits any of these.
* **Erlang's per-process heaps** (Sagonas and Wilhelmsson 2006) are the
  isolated-process design the owner's note names, made possible by an
  immutable heap and message copying. *Transfers:* nothing in D1 to D4
  closes it; D8 says what a per-process heap needs of the layout
  (nothing beyond a thread's allocation state).

### Barriers

* Hosking, Moss and Stefanović (1992) compared write barriers in
  Smalltalk; Blackburn and Hosking (2004) measured them in Java on
  three processors and found "the average overhead for a reasonable
  generational write barrier was less than 2% on average, and less than
  6% in the worst case", a read barrier of one unconditional mask 0.85%
  on the PowerPC and 8.05% on the AMD, and the read barriers' averages
  5.1%, 4.8% and 1.8% by processor -- so that barrier overhead should
  not be "a primary motivator" of designs that avoid them (the paper,
  sections 1 and 5); Yang, Blackburn, Frampton and Hosking (2012)
  again with newer hardware and barriers and found average overheads
  "as low as 5.4% and 0.9%" for read and write barriers respectively
  (the abstract). Zorn
  (1990) is the older survey. *Transfers:* a barrier in Rune guards
  three store sites; its cost is measured in M7 with a card mark behind
  a flag, and the census counts the stores it would see.
* Bacon, Fink and Grove (2002) built Jikes RVM's object model as a
  pluggable abstraction and compared its two-word header (a method
  table pointer, then lock state, hash code and collector bits) with
  three single-word models that compress the second word away -- the
  hash code in a bit stolen from the pointer and materialised on
  demand, the collector's bits likewise, and a second word kept only
  for the 2.5% of objects whose class has synchronized methods, a "lock
  nursery" handling the rest. The single-word models saved a mean of 7%
  of allocated space (14% excluding two programs of very large arrays;
  up to 21%) and ran from 2.3% faster to 1.6% slower on average under
  the most aggressive compression; arrays keep a length word, and a
  copying collector with one-word headers pays "a slight slow-down" for
  the forwarding pointer it can no longer keep beside the header (the
  paper, sections 3 to 5). *Transfers:* D4 B (the 4-byte header) is the
  same question for a smaller object and the census's answer is the
  same order (0.03% on the compiler, since 8-byte alignment rounds it
  away); D4 A's reserved collector bits are what Jikes compressed, and
  Rune has no lock or hash to compress at all.
* Cher, Hosking and Vijaykumar (2004) and Garner, Blackburn and
  Frampton (2007) show a mark-sweep collector's time is memory latency
  and tracing is "up to 65% of elapsed time" in Boehm's collector and a
  redesigned prefetch gave a 27% average speedup where the default gave
  16% (the abstract). *Transfers:* the
  copier's `copy_obj` is 19.8% of the native bootstrap; its misses are
  what fewer bytes and denser objects reduce, and the harness measures
  them.

### The method of the experiments

* Hertz, Blackburn, Moss, McKinley and Stefanović (2006, Merlin)
  compute exact object death times from reachability, "over two orders of magnitude faster" than collecting after every
  allocation (the paper); Stefanović, McKinley and Moss (1999) and
  Blackburn et al. (2001) use such traces to evaluate generational
  policies and pretenuring. *The experiments* approximates death times
  by forced collections at a fixed granularity, which Merlin would
  refine and which the simulator reports as a band.
* Blackburn et al. (2006, DaCapo) fixed the method of measuring a
  collector at heap sizes that are multiples of the smallest that
  runs; Barrett et al. (2017) showed virtual machines do not reliably
  reach a steady state, so whole runs are measured; Mytkowicz et al.
  (2009) showed link order and environment size move results enough "to draw wrong conclusions" (the abstract), which is why a relink here counts as 13%
  and same-binary runs as 3% of noise.

### What the numbers say

| Measured | Result | Source |
|---|---|---|
| dynamic pointer tagging in GHC | 14% faster for 2% more code; mispredicted branches removed | Marlow, Yakushev and Peyton Jones 2007 |
| type-based representation in SML/NJ | heap allocation -36%, code about 19% faster | Shao and Appel 1995 |
| closure representations in SML/NJ | allocation -36%, variable fetches -43%, about 17% faster | Shao and Appel 1994 |
| storage management in SML/NJ | the collector's time often less than the rest of storage management; store list 0-1% of mutation | Tarditi and Diwan 1996 |
| generational collection for Haskell | write barrier about 2%; under 3% total overhead at a 1 MB allocation area; 6-14% promoted | Sansom and Peyton Jones 1993 |
| a generational write barrier in Java | under 2% on average, under 6% at worst; a masking read barrier 0.85% (PowerPC) to 8.05% (AMD) | Blackburn and Hosking 2004 |
| write and read barriers in Java | 0.9% and 5.4% average | Yang, Blackburn, Frampton and Hosking 2012 |
| tags and descriptors in SML/NJ | about 28% of space and 4% of time | Appel 1989 |
| SML/NJ's generational collector against its predecessor | total CPU time 10% (SPARC) to 20% (SGI) less; pairs without descriptors 10-15% of space; 80% fewer cards swept | Reppy 1993 |
| an overflow-checked add on tagged integers, generic RISC | 4 cycles more than raw | Gudeman 1993 |
| tracing against explicit management | matched at 5x the memory; 17% slower at 3x; nearly 70% at 2x | Hertz and Berger 2005 |
| Immix against canonical collectors | 7-25% total performance; as a mature space, matches or beats a tuned generational collector | Blackburn and McKinley 2008 |
| one-word object headers in Java | 7% of space on average (14% without two array-heavy programs), up to 21%; from 2.3% faster to 1.6% slower | Bacon, Fink and Grove 2002 |
| cache misses of copying vs mark-sweep | up to 4x the miss rate on a direct-mapped cache | Zorn 1991 |
| OCaml 5's minor collectors against stock | parallel stop-the-world 3.5% slower, concurrent 4.9% | Sivaramakrishnan et al. 2020 |
| OCaml 5's effect handlers | mean 1% overhead on programs that use none | Sivaramakrishnan et al. 2021 |
| Merlin's lifetime traces | over two orders of magnitude faster than brute force | Hertz et al. 2006 |
| virtual machine warm-up | at most 43.5% of VM-benchmark pairs reach a steady state | Barrett et al. 2017 |
| V8's pointer compression | heap up to 43% smaller | Sheludko and Aboy Solanes 2020 |

One source is cited for what it establishes, not for a figure: TIL's
evaluation (1996). Wilson, Lam and Moher (1992) and Dybvig, Eby and
Bruggeman (1994) give no figure to tabulate; their findings are in the
text.

### What transfers to Rune

1. The tagged word is the settled representation for a strict ML with
   a C runtime; the unboxed-by-type layout is the faster one and needs
   either monomorphisation or coercions at polymorphic boundaries,
   which Rune's representations section makes possible field by field
   (D1 B).
2. A header per object with a descriptor beats tag-free collection and
   type-passing for a language compiled in units (D4).
3. The stack can stay self-describing at the cost of a shift per typed
   slot in the interpreter; maps buy liveness precision (D5, M6).
4. Immutable data makes the barrier cheap and rare, the nursery
   effective, and per-thread heaps simple; every collector in the
   survey that a NUMA machine wants needs header bits and address
   ranges, not a particular word (D7, D8).
5. The collector's cost is memory traffic: fewer bytes per object and
   a nursery that fits the cache are the two levers, and they compose.
6. Measure whole runs at equal memory, with `task-clock` and misses
   beside cycles, and treat anything under the noise as nothing.

## What the implementations do

Twenty-five runtimes were read under `/home/ruud/reference` for this
roadmap (the versions in parentheses); each claim below points at a
file, and the paths are relative to that directory. `dotnet` holds the
SDK repositories without CoreCLR's runtime, so its collector is cited
from the literature and only F#'s union layouts from the tree.

| Runtime | Word and tagging | Header | Floats | Allocation | Collector | Barrier | Threads | Roots |
|---|---|---|---|---|---|---|---|---|
| MLton 20241230 | 64-bit, no uniform tag: a representation per type (`PackedRepresentation`) | 1 word: bit 0 = 1, 19-bit type index into a per-program table, mark and counter bits | unboxed in objects, flat in vectors | bump `frontier`/`limit`; big sequences into the old generation | Cheney, mark-compact or generational, chosen at run time by live/RAM ratios | 256-byte cards and a cross map | one OS thread; stacks are heap objects | frame info per return address |
| SML/NJ 2026.2 (and 110.99.9) | low 2 bits: 00 pointer, 10 descriptor, x1 immediate; 63-bit int (31 on 32-bit) | 1-word descriptor: length, 5-bit kind, 2-bit tag; **pairs lose it** when promoted into a pair arena (BIBOP) | boxed raw object; `Int64`/`Word64` boxed | bump nursery; arenas per generation and kind | generational copying, up to 14 generations | a store list consed in the nursery, cards at minor GC | single-threaded | no stack: CPS, roots are the ML state registers |
| Poly/ML 5.9.2 | low bit 1 = 63-bit int; optional 32-in-64 word indices | length word before the object, 1 flag byte (byte/code/closure, mark, mutable, weak, sign, tombstone) | `Real64` boxed; `Real32` tagged in the top 32 bits | per-thread area, downward bump; mutable, immutable and code spaces | minor parallel copying; major parallel mark-compact; a sharing pass | **none**: the mutable areas are minor roots | native threads, shared heap, stop-the-world | self-describing stack words, no maps |
| MLKit 4.7.23 | with GC: 63-bit tagged; high-bit constructor tags on pointers; without GC: untagged 64 | tag word: 5-bit kind, size, a "skip" count of leading non-pointer words; pairs, triples and refs **tag-free** | boxed 2 words | region inference: 8 KB region pages, bump per region; large objects `malloc`ed | copying across region pages, optional generational | none found | ReML parallel threads without GC | frame descriptors before return addresses |
| OCaml 4.14.4 | low bit 1: 63-bit int | 1 word: 54-bit size, 2-bit colour, 8-bit tag | boxed `Double_tag`; **flat float arrays and records** | minor bump (256k words); major free lists, best-fit | minor copying, incremental major mark-sweep, compaction | `caml_modify`: remembered set, darkening while marking | master lock | frame descriptors |
| OCaml 5.5.1 | the same | reserved bits, size, colour, tag | the same | per-domain minor heaps in one reserved range; major: per-domain size-class pools, 32 classes to 128 words | parallel stop-the-world minor; concurrent mark-sweep major | deletion barrier and a major-to-minor remembered set; release store | domains; fibers off-heap | frame descriptors |
| GHC 9.14.1 | every value a pointer; **3 low bits = constructor number or evaluatedness**; `Int#` unboxed | info pointer to a table (pointer and non-pointer counts, type, constructor tag) | `D#` boxed; `Double#` raw | 4 KB blocks in 1 MB megablocks; per-capability nursery; pinned blocks | generational copying, parallel; optional concurrent non-moving oldest generation | dirty bits and mut-lists; cards on arrays; snapshot barrier for non-moving | capabilities; stop at heap checks | info-table bitmaps; the stack is a heap object |
| Chez 10.4.1 | 3-bit tag: fixnum 000 (61 bits), pair 001, flonum 010, closure 101, immediate 110, typed 111 | **none for pairs, flonums and closures**; typed objects carry a type word | boxed 8-byte flonum without header; local unboxing | per-thread bump; 8/16 KB segments typed by what they hold (BiBOP); 16-byte alignment | generational copying; mark in place for sparse or locked segments; parallel sweepers | a store buffer carved from the top of the thread's allocation area, then dirty cards | shared heap; `collect-rendezvous` | return-point header with a live mask |
| Racket 9.3 | CS: Chez's; BC: low bit 1 fixnum | CS: Chez's; BC: type and hash words | Chez's | Chez's | Chez's; BC: precise generational | Chez's; BC: page protection | places and futures as Chez threads on one heap | Chez's; BC: explicit frames |
| Koka 3.2.9 | low bit 1 = 63-bit value; `int` as `4n+1` so addition needs no untagging; **doubles immediate when the exponent fits 10 bits** | 8 bytes: scan count, field index, 16-bit tag, 32-bit refcount (negative = shared) | mostly immediate; else `KK_TAG_DOUBLE` | mimalloc per thread; in-place reuse | Perceus reference counting, compiler-inserted, no cycle collector | none | shared objects by atomic counts | none needed |
| Manticore | low bit 1 immediates; ints boxed in polymorphic positions | 1 word: 48-bit length, 15-bit ID selecting a generated scanner | raw objects | per-vproc local heap and global chunk | split heaps: local Appel generations, parallel global copying | promotion on escape, no store barrier | one vproc per core | CPS |
| Guile 3.0.11 | 62-bit fixnums; pairs untagged in memory | first word = type; pairs have none | boxed | Boehm GC | conservative non-moving mark-sweep | none | shared heap | conservative C stack; slot maps for inner VM frames |
| Erlang/OTP 29 | 2-bit primary tag: header, list, boxed, immediate; 60-bit smalls | arity and subtag; **lists headerless** | boxed | per-process young and old heaps; big binaries off-heap by refcount | per-process generational Cheney; no global collection | none (immutable heap) | per-process heaps | the stack shares the heap block; words self-describing |
| Go 1.27.1 | none | **none for small objects**: a pointer bitmap at the span's end; a type pointer for objects of 512 bytes and more | unboxed | per-P size classes to 32 KB; tiny allocator | concurrent non-moving tri-colour mark-sweep | hybrid Yuasa-Dijkstra, buffered | goroutines; brief stop-the-world | precise stack maps; stacks copied on growth |
| Julia 1.13 | none; `isbits` inline | 1 word: type pointer, 2 GC bits, 2 image bits | unboxed when `isbits` | per-thread pools to 2 KB | non-moving generational mark-sweep (sticky bits), parallel mark | `jl_gc_wb` remembered set | shared heap, stop-the-world | shadow-stack frames |
| Dart 3.13.4 | Smi tag 0, pointer tag 1; **new and old told apart by alignment** | 1 word: flags, size class, class id, hash | boxed | new-space bump; old-space free lists | parallel scavenger; concurrent mark-sweep and compact | header-bit barrier, card remembering | isolate groups share a heap | compressed stack maps |
| HotSpot 28 | none; compressed oops | mark word and class; compact 8-byte header by default | boxed `Double` | TLABs | Serial, Parallel, G1, ZGC, Shenandoah | G1: snapshot and cards; ZGC: coloured pointers | shared heap; safepoints | oop maps |
| V8 15.6 | Smi tag 0 (31-bit with compressed pointers), object tag 1 | map word | boxed `HeapNumber` | LABs | scavenger or minor mark-sweep; concurrent mark-compact | generational, marking and evacuation barriers | isolates | safepoint tables |
| JavaScriptCore | NaN-boxing | structure id, type, cell state | immediate | 16 KB blocks, 16-byte atoms, size classes | concurrent non-moving, sticky-mark generational | cell-state barrier | shared heap | conservative stack scan |
| SpiderMonkey | NaN-boxing (tag shift 47) | cell header, 3 GC bits | immediate | nursery and arenas | generational nursery; incremental, compacting mark-sweep | pre- and post-barriers, store buffer | per runtime | precise |
| LuaJIT 2.1 | NaN-tagging, 47-bit payloads | `nextgc`, mark, type | immediate | dlmalloc | incremental non-moving mark-sweep | back barrier on tables | one state | precise |
| CPython 3.14 (PyPy, Skybison) | none in the heap; tagged `_PyStackRef`s on the eval stack | refcount and type | boxed | obmalloc/mimalloc | refcounts and a cycle collector | -- | GIL or biased refcounts | eval stack |
| Swift | none; **spare bits of enums** carry the case | metadata pointer and inline refcounts | unboxed | malloc | ARC | -- | atomic counts | -- |
| Wasmtime 49 | 32-bit indices into a GC heap; `i31ref` low bit 1 | 8 bytes: kind, type index, **a 23-bit inline pointer bitmap** in the reserved bits | unboxed | bump | semispace copying (no barriers), deferred refcounting, or none | DRC: counts on stores to tables and globals | per store | Cranelift user stack maps |

The notes that bear on a decision:

* **MLton** (`runtime/gc/object.h:36-69`; `mlton/backend/packed-representation.fun`;
  `runtime/gc/model.h:10-138`). The header is `bit 0 = 1 | 19-bit type
  index | 11-bit counter | mark bit`, the index naming an entry of a
  per-program `objectTypes` table that says how many non-pointer bytes
  precede how many pointers; a normal object puts its non-pointers
  first. Sum types are packed by `ConRep`: `ShiftAndTag`, `Tag` or
  `Tuple`; where pointers are mixed in, the tag count is scaled "to
  remove all the tags that have 00 as their low bits"; a variant that
  carries pointers is told by its header's type index. `model.h` is a
  written rationale for pointer schemes, weighing a 32-bit compressed
  pointer's load cost against the memory it can address, and it says
  why a scheme without a spare low bit "leave[s] no room to represent
  small objects in sum types". Reals are raw bytes in objects and flat
  in `Real64` vectors; `(int * int) array` stores its pairs inline
  (`doc/guide/src/DeepFlatten.adoc`); `IntInf` is an immediate with the
  low bit set or a pointer to a vector of limbs (`MLtonIntInf.adoc`).
  The FFI passes arrays and refs as pointers to data with "the natural C
  representation" behind the header, and nothing is pinned
  (`ForeignFunctionInterfaceTypes.adoc`). Roots: `GC_frameInfo` per
  return address, the live pointer offsets of the frame
  (`runtime/gc/frame.h`). Regions were weighed and rejected because
  space safety needs a collector anyway (`Regions.adoc`).
* **SML/NJ** (`runtime/include/tags.h:27-78`, `ml-values.h:36-71`,
  `runtime/gc/minor-gc.c:307-322`, `gc/card-map.h`). `TAG_boxed 0`,
  `TAG_desc 2`, `TAG_unboxed_b0 1`; `INT_CtoML(n) = 2n+1`; unit,
  `false`, `nil` and `NONE` are the tagged 0. A descriptor is `len << 7 |
  dtag << 2 | 0b10`. On promotion a two-field record goes to the pair
  arena without its descriptor, found again through the BIBOP; vectors,
  arrays and strings are a two-word header object pointing at a data
  object; `Int64`, `Word64` and reals are boxed raw objects. The store
  list is a cons cell per update in the nursery, turned into 256-byte
  dirty cards at the minor collection. No ML stack: CPS with heap
  continuations. 110.99.9 adds `DTAG_raw64` for 8-aligned raw data.
* **Poly/ML** (`libpolyml/globals.h:28-44,65,136-146,223-261`,
  `reals.cpp:202-230`, `quick_gc.cpp:20-24,568-610`,
  `x86_dep.cpp:376-440`). A tagged int is `(s << 1) | 1`; the length
  word before an object has 7 bytes of length and a flag byte with
  `F_BYTE_OBJ`, `F_CODE_OBJ`, `F_MUTABLE_BIT`, `F_WEAK_BIT`,
  `F_NEGATIVE_BIT` (bignum sign), `F_GC_MARK`, `F_TOMBSTONE_BIT`
  (forwarding). Every word of a word object is a tagged int or a
  pointer, so objects and stacks are scanned without maps ("Local values
  must be word addresses"). `Real32` is tagged in the top 32 bits;
  `Real64` is a byte object. The minor collector copies "from the
  allocation areas into the mutable and immutable areas" and has no
  write barrier: the permanent mutable areas and "local mutable areas
  since these are roots as well" are scanned every time. Threads share
  the heap, each with its own allocation area; the major collector is a
  parallel mark, compact and update. The default `int` is 63-bit unless
  built with `--enable-intinf-as-int`.
* **MLKit** (`src/Runtime/Tagging.h:10-87,276-280`, `src/Runtime/
  Region.h`, `GC.c:991-1060,1636-1680`, `Backend/BackendInfo.sml:78,110`).
  `defaultIntPrecision () = if tag_values() then 63 else 64`: tagging is
  a property of building with the collector. The tag word carries the
  kind in 5 bits, a size, and "the number of leading non-pointer words"
  to skip; pairs, triples and refs are tag-free under `-DTAG_FREE_PAIRS`,
  which every GC build uses; constructor tags of unboxed datatypes sit
  in bits 48 and up of the pointer, stripped and restored by the
  collector. Regions are 8 KB pages with a bump pointer each; the
  collector copies across pages and marks stack-allocated and large
  objects immovable. Frame descriptors precede return addresses.
* **OCaml 4 and 5** (`runtime/caml/mlvalues.h:70-83,93-157,198-365`;
  `runtime/memory.c:183-231` in 5; `runtime/caml/sizeclasses.h`;
  `runtime/shared_heap.c:49-75`; `caml/address_class.h:50-58`;
  `caml/domain.h:34-41`). `Is_long(x) = x & 1`, `Val_long(x) = (x << 1)
  + 1`, `Max_long = 2^62 - 1`; the header is `wosize | color | tag` with
  reserved bits in 5. Floats are `Double_tag` boxes, but a record or
  array of floats alone is flat (`Double_array_tag`), a rule the type
  checker knows. OCaml 5 gives each domain a minor heap in one reserved
  range, so `Is_young` is a range check, a major heap of size-class
  pools (32 classes up to 128 words) and large allocations, a deletion
  barrier that darkens the old value and a remembered set for major-to-
  minor pointers, with the memory model of Dolan, Sivaramakrishnan and
  Madhavapeddy 2018 written into `memory.c:44-60`. The FFI is
  `CAMLparam`/`CAMLlocal` root registration, custom blocks and
  `Bigarray` for off-heap data; 4 allowed naked pointers through a page
  table, 5 does not. The manual states "Integer values encode 63-bit
  signed integers" and gives no rationale in the tree.
* **GHC** (`rts/include/MachDeps.h:110-118`, `rts/storage/
  ClosureMacros.h:256-280`, `compiler/GHC/StgToCmm/Closure.hs:322-350`,
  `rts/include/rts/storage/Closures.h:40-83,205-242`, `InfoTables.h:
  139-215`, `rts/sm/NonMoving.c:44-260`). Three tag bits in every
  pointer: for a family of up to seven constructors the constructor
  number, otherwise 1..max with the rest lumped, so that a `case` needs
  no load (Marlow, Yakushev and Peyton Jones 2007). Every closure begins
  with an info pointer whose table gives the pointer and non-pointer
  counts, the type and the constructor tag; small `Int`s and `Char`s are
  static closures. The heap is 4 KB blocks in 1 MB megablocks, a nursery
  per capability, pinned blocks for the FFI's byte arrays, a large-object
  threshold of 8/10 of a block; mutable arrays carry a card table of
  128-element cards; the oldest generation may be collected concurrently
  and non-moving with a snapshot-at-the-beginning barrier.
* **Chez Scheme** (`s/cmacros.ss:470-480,755-780,817-996,1427-1700,
  1757-1761,2132-2149`; `c/types.h:143-185`; `c/gc.c:24-130`; `c/alloc.c:
  462-490`; `c/gcwrapper.c:297-330`; `IMPLEMENTATION.md:303-380`). Three
  low bits: fixnum 000 (61 bits), pair 001, flonum 010, symbol 011,
  closure 101, immediate 110, typed object 111. A pair is two words with
  no header, a flonum eight bytes with none, a closure a code pointer and
  its free variables; typed objects (vectors, strings, records) have a
  type word. Allocation is 16-byte aligned "for the forward marker and
  forward pointer"; the heap is 8 or 16 KB segments each recording its
  space, generation, marks and dirty bytes per card (BiBOP: Dybvig, Eby
  and Bruggeman 1994). The barrier `remember` pushes an address into a
  store buffer between the thread's `eap` and `real_eap` -- the top of
  its own allocation area -- and skips fixnum stores; the collector is
  generational copying that marks in place where a segment is sparse or
  locked; `lock-object` pins by marking the segment must-mark, for the
  FFI. Since 10.0 the compiler unboxes flonums within a procedure.
* **Koka** (`kklib/include/kklib/box.h:13-50`, `kklib.h:54-147`,
  `kklib/integer.h:10-60`, `src/Backend/C/Parc.hs`). A box is a word
  with the low bit 1 for a 63-bit value; a double is encoded as a value
  when its 11-bit exponent fits 10, which "captures almost all doubles
  that are commonly in use for most workloads", and is heap-allocated
  otherwise; `int` is `4n+1` so that addition needs no untagging and
  `(z & 2) == 0` detects overflow or a pointer. The 8-byte header holds
  a scan count, a field index, a 16-bit tag and a 32-bit reference
  count, negative for objects shared between threads; Perceus inserts
  the counts in the compiler and reuses an object in place when its
  count is one.
* **Manticore** (`src/lib/parallel-rt/include/header-bits.h`,
  `gc/gc-scan.h`, `gc/README`, `gc/major-gc.c:239-250`). A one-word
  header of a 48-bit length and a 15-bit ID that selects a generated
  scanning function; a raw object has ID 0. Each vproc has a local heap
  with Appel's two-generation scheme and a chunk of the global heap;
  promotion on escape copies an object into the global heap, so there is
  no store barrier; a global collection is parallel and stop-the-world.
  Ints are boxed in polymorphic positions.
* **Guile, Erlang, Racket.** Guile puts a pair's two words in memory
  with no header and the pair-ness in the pointer's low bits
  (`libguile/scm.h:299-305`), runs on Boehm's conservative collector and
  scans the C stack conservatively; only the top VM frame is scanned
  without a slot map (`vm.c:713-772`). Erlang's heap is immutable per
  process, so a process's generational Cheney collector needs no
  barrier and no other process's collection touches it; lists have no
  header; binaries over 64 bytes live off-heap by reference count
  (`erts/emulator/beam/erl_term.h`, `internal_doc/GarbageCollection.md`).
  Racket CS is Chez with places, futures and threads on one heap
  (`racket/src/cs/README.txt:390-400`).
* **Go** (`src/runtime/mgc.go:5-120`, `mbarrier.go:24-50`, `mbitmap.go:
  5-52`, `internal/runtime/gc/malloc.go:47`, `sizeclasses.go`,
  `pinner.go`). No headers for objects under 512 bytes: a pointer bitmap
  at the end of each span, a type pointer in the first word above that;
  size classes up to 32 KB per P; a concurrent, non-moving, tri-colour
  mark-sweep with a hybrid barrier and brief stops; precise stack maps
  and stacks copied on growth; `runtime.Pinner` for cgo.
* **Julia, Dart, HotSpot, V8, JavaScriptCore, SpiderMonkey, LuaJIT.**
  Julia's word before the object is a type pointer with two GC bits and
  two image bits, pools per thread to 2 KB, a non-moving generational
  collector with sticky marks and `jl_gc_wb` (`src/julia.h:91-107`,
  `doc/src/devdocs/gc.md`). Dart keeps new-space objects offset from
  double-word alignment "checking an object's age without comparing to a
  boundary address" and puts the barrier's state in header bits
  (`runtime/docs/gc.md:5-24,74-140`). HotSpot's compact header is 8
  bytes of mark word with class, hash, age and lock bits
  (`oops/markWord.hpp:30-80`). V8's Smi is a 31-bit tagged int under
  pointer compression, and its write-barrier note lists three barriers
  and their elision (`src/heap/WRITE_BARRIER.md`). JavaScriptCore and
  SpiderMonkey NaN-box (`runtime/JSCJSValue.h:415-505`; `public/Value.h:
  96-222`); LuaJIT NaN-tags with 47-bit payloads (`src/lj_obj.h:224-280`).
* **Swift and Rust.** Swift's multi-payload enums put the case in the
  spare bits of a pointer payload and in "extra inhabitants"
  (`docs/ABI/TypeLayout.rst:167-240`); Rust's niche-filling enum layout
  is the same idea (`compiler/rustc_abi/src/layout.rs:576-750`), and
  its strict-provenance pointer API is how a tagged pointer is written
  soundly (`library/core/src/ptr/mut_ptr.rs`).
* **Wasmtime** (`crates/wasmtime/src/runtime/vm/gc/gc_ref.rs:37-44`,
  `gc/enabled/copying.rs:1-12`, `crates/environ/src/gc/copying.rs:
  37-80`). A GC reference is a 32-bit index; the header's reserved bits
  hold a 23-bit pointer bitmap when the object is small enough, an
  out-of-line table otherwise; the semispace collector "does not require
  any read or write barriers", and the minimum object size leaves room
  for the forwarding reference.

**Three families, and where Rune stands.** The ML implementations fall
into three shapes. MLton keeps every type's natural size and tells the
collector the layout through the header's type index and the frame's
map; it pays for that with whole-program compilation, and it is the
fastest. SML/NJ, Poly/ML, MLKit, OCaml and Chez keep one tagged word:
ints lose a bit (61 to 63), reals are boxed unless flat in an array or
kept in a register, and the collector needs no map of a stack word,
because every word says what it is. GHC keeps every value boxed and puts
the constructor's tag in the pointer, and unboxes by the compiler's
worker/wrapper. Every one of them drops the header on the commonest
small object where it can: SML/NJ's pairs, Chez's pairs and closures,
MLKit's pairs and refs, Erlang's lists, Guile's pairs, Go's small
objects. None uses a two-word cell: Rune's layout has its only
counterparts in the interpreters' operand stacks (Lua's `TValue`,
CPython's `_PyStackRef`), not in a heap. The tagged word is the
well-trodden road for a strict ML with a C runtime; MLton's is the road
to its speed, and Rune's bytecode already carries the representations
that road needs. D1 is the choice between them, and the numbers of *The
experiments* are what it is made on.

## The candidate layouts

A layout is four choices that can be made almost independently -- what a
word is, how an integer and a real are held, how the collector knows an
object, and how a frame's roots are found -- and every combination was
considered. Six design points cover the combinations that the
implementations use and the experiments can tell apart; the rest are
variants of one dimension, measured where that dimension is separable.
Each is stated with what it costs and what it buys, before the numbers;
*The experiments* puts the numbers on them, and D1 to D5 choose.

### L0: today

A 16-byte tagged cell; an 8-byte header; payloads rounded to 16; every
field, slot and array element a cell. Ints, words, reals, chars and
nullary constructors immediate at full width; the stack self-describing;
no maps anywhere; images and `--count` as they are; the JIT's homes and
`ms_trusts` as built. What it costs: every pointer field, slot and array
element carries eight bytes of tag for one bit of information; a list
cell is 40 bytes where every ML runtime in the survey makes it 16 or 24;
the collector copies twice the bytes and the cache holds half the
objects; a `Value` cannot be passed in a register and a 16-byte load
follows every 8-byte store (jit M2). It is the baseline every other
number is against.

### L1: the tagged word

An 8-byte word; the low bit 1 for an immediate, 0 for a pointer, as
OCaml, SML/NJ, Poly/ML, MLKit and Koka do it (Chez and Guile spend
three bits). Ints and words are 63 bits; chars, nullary constructors and
unit are immediates; a real is a boxed object of a header and a double
unless the compiler keeps it in a register, as the JIT's homes already
do within a function. The header stays 8 bytes with `kind`, `contag`
and `len`. The stack stays self-describing -- a slot is an immediate or a
pointer, told by its bit -- so the collector needs no map, the JIT's
write-back rule stands, images write a word and a tag bit, and
`values_equal` walks as today. What it costs: `Int.precision` and
`Word.wordSize` become 63, which the language, the Basis suite, `IntInf`'s
limbs, `word_bits` and every hash see (D2); a real that escapes a
register costs a 16-byte box, which numeric code pays at every store
into a tuple or an array (D3); every int operation shifts or masks (an
addition on `2n+1` words is one `lea` and one `jo`; a multiplication
untags one side); a nullary constructor and a `bool` need a distinct
encoding from an int, since polymorphic equality cannot tell them
apart otherwise (a tag bit pattern or a range). What it buys: half the
bytes for every pointer-heavy object; the collector's bytes halved; a
value in one register; a slot of 8 bytes on the value stack; the same
layout on the 32-bit VMs at the same counts (a word is 8 bytes there
too, D13).

**L1r** is L1 with reals immediate where their exponent fits ten bits
(Koka's rule) and boxed otherwise: no box for a real between 2^-511 and
2^512 in magnitude, which is almost every real a program computes, at
the cost of a test on every real operation's result and a slow path.

### L2: the tagged word with 64-bit integers

L1's word, but `Int` and `Word` keep 64 bits: a value that fits 63 bits
is immediate, one that does not is a boxed object, and every consumer
tests the bit before the arithmetic. This is Poly/ML's arbitrary-
precision path and OCaml's `Int64` applied to the default integer; no
runtime in the survey does it for its `int`. What it costs: a check on
the overflow path of every addition and multiplication that boxes
instead of raising; a load on every consumer of a word that might be
boxed; the census says how often a value needs the 64th bit -- if that
is rare outside hashes and `word_bits`, the cost is a branch never
taken. What it buys: the language unchanged, the owner's rule kept, and
L1's other gains.

### L3: NaN-boxing

An 8-byte word that is a double when it is not a NaN pattern, and
otherwise 48 or 51 bits of payload under a tag: a pointer, a 48-bit or
51-bit int, a char, a constructor. JavaScriptCore, SpiderMonkey and
LuaJIT do this because JavaScript's number is a double. What it costs:
ints of 48 or 51 bits, worse than L1's 63 for the language and with a
box for the rest; masking on every pointer use; pointers limited to 48
bits (52 on the coming five-level page tables); no runtime for a
typed language chose it. What it buys: reals immediate. It is here so
that the roadmap can say with numbers why not: the census's count of
reals against ints decides, and SML programs are int-heavy.

### L4: the untagged word, type-directed

An 8-byte word that is whatever its type says -- a raw 64-bit int, a raw
double, a pointer -- with no tag in the word, as MLton lays out
objects. The collector learns an object's layout from its header (a
skip count of leading non-pointer words as MLKit, a pointer bitmap as
Wasmtime and Go, or a type index into a table the compiler emits as
MLton), and a frame's roots from a map per pc that the register
bytecode can carry, since each register's representation is in the
representations section and liveness is computed by the compiler. A
polymorphic position -- a register or field of representation `any` --
holds a pointer or an immediate that still needs telling apart, so an
`int` or `real` in a polymorphic position is boxed (GHC's `Int` in a
list; Manticore's boxed ints); how many there are is the static
census's `any` share, and what unboxing at known types buys is the
difference between L4-mono and L4-uniform in the simulator. What it
costs: maps for the interpreter's frames and the JIT's (M11 makes tier
2's anyway); the collector, `values_equal`, images and the REPL's
printer need the layout descriptor instead of the tag (equality and
printing at a polymorphic type need the type, or a descriptor rich
enough to walk by); a `TUPLE` must say its fields' kinds, so the
description of every allocating instruction grows; polymorphism boxes
ints and reals; the whole runtime changes at once, nothing of it can be
staged. What it buys: 64-bit ints and reals unboxed wherever the type is
known, MLton's sizes for monomorphic data, no tag operations in
arithmetic, flat arrays of every raw type for free.

### L5: headerless small objects and the tag in the pointer

On L1 or L4: a two-field immutable object -- a list cell, a pair, a
`CONN` of two -- is two words with no header, and the kind and the
constructor's tag are in the pointer's low bits (Chez, SML/NJ's pair
arena, MLKit, GHC's dynamic tags). A `case` on a list needs no load; a
list cell is 16 bytes; the collector finds the object's shape in the
pointer. What it costs: two tag bits in every pointer beside the immediate
bit (the three that 8-byte alignment frees; Chez takes 16-byte alignment
for seven kinds, which the census prices at 0.696 against 0.591 for the
word alone), or a segregated space for headerless objects (SML/NJ's pair
arena; a BiBOP of segments typed by what they hold), so that a pointer
found in the heap can be scanned; a forwarding
scheme for an object with no header word to overwrite (Chez's forward
marker in the first word; Dybvig, Eby and Bruggeman 1994 assign a
segment's type when its objects first survive, so the allocator keeps
one pointer); constructors beyond the bits' range fall
back to a header; `contag` up to 65,535 today. What it buys: the
commonest object at 40% of its L1 size and 40% of L0's, and the tag
test of a `case` without a memory access.

### Variants

Measured on top of the layouts where the dimension is separable:

* **A 4-byte header.** `kind`, `contag` and `len` in 32 bits (a tag of
  16 bits and a length of 8, or a length word for large objects only):
  saves 4 bytes per object at the cost of an escape for long arrays and
  strings and of every header read. Objects stay 8-aligned, so the 4
  bytes are saved only when the payload has an odd number of words.
* **16-byte alignment** of objects (Chez's, for its seven pointer kinds;
  L5 needs only the two bits that 8-byte alignment frees): costs padding
  on odd-sized objects -- 0.696 against 0.591 on the bootstrap -- and
  buys aligned 16-byte loads and a third tag bit.
* **Compact arrays and strings.** `Word8Array`, `CharArray` at one byte
  per element, `RealArray` at eight, `IntArray`/`WordArray` at eight
  unboxed: the element type is known where the array is made
  (`_primtype "bytearray"` of basis.md; a monomorphic array's type at
  its allocation site under any layout), so this is orthogonal to the
  word and is measured on L0 as well. It is also what the FFI wants: a
  byte array whose bytes are C's behind the header.
* **Mutable objects segregated.** Refs, arrays and closures written by
  `SETENV` allocated in their own space or marked by a header bit:
  Poly/ML's answer to the write barrier (the mutable space is a root of
  the minor collection) and a step towards a per-thread young heap
  where only mutable objects need a rule.
* **Young and old told apart by address** (OCaml 5's reserved range for
  every minor heap) **or by alignment** (Dart): a decision the layout
  makes for the collector to come, at no cost now.
* **A nullary exception as an immediate**, and a length in the pointer
  for small tuples: small, noted, measured in M5 if cheap.

### What each does to the rest of Rune

| | L0 | L1, L1r | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|---|
| `Int.precision`, `Word.wordSize` | 64 | 63 | 64 | 48 or 51, boxed above | 64 | as its base |
| `Real` | immediate | boxed; L1r mostly immediate | boxed | immediate | raw where typed, boxed at `any` | as its base |
| the stack's roots | tags | tag bit | tag bit | tag | maps per pc | as its base |
| JIT homes and write-back | as built | tag bit written back | the same | the same | maps at safepoints (M11's) | the same |
| `ms_trusts` and the emitters | as built | header and pointer changes | the same | the same | descriptors | pointer tags |
| images | as built | a word and a bit | the same | the same | descriptors written | pointer tags written |
| `--count` bytes | as built | re-based | re-based | re-based | re-based | re-based |
| 32-bit VMs | 16-byte cells | 8-byte words with software ints, or the native 4-byte word (D13) | the same | the same | the same | the same |
| `values_equal`, `poly_eq` | by tag | by bit and header | the same | the same | by descriptor | by pointer tag |
| the REPL's printer, `--trace` | by tag | by bit and header | the same | the same | needs the type or a descriptor | by pointer tag |
| the collectors to come | header bits free: `pad` | header bits: `pad` plus what the header spares | the same | the same | the descriptor's spare bits | the same |
| the FFI | a `Value` by pointer | a word in a register | the same | the same | a raw value in a register | the same |

## The experiments

The brief asks for hard evidence: every candidate simulated, under many
workloads, before a decision. Four instruments were built for this
roadmap in a copy of the tree (`~/.cache/claude-rune-drafts/heap-layout`,
whose README says what is where; M1 and M2 bring them into the tree),
and every table below names the one that made it. What each can and
cannot settle is said at the end, so that the gate of M4 measures what
only a prototype can.

### The workloads

| Workload | What it is | Why |
|---|---|---|
| bootstrap | `bin/rune.new.rbc` compiling the compiler's sources, `--heap-size 67108864` (since the rebase `bin/rune.rbc`, writing the register bytecode: *After the rebase*) | the reference program: 1.12 GB, 24.6 M objects, live data to 205 MB; rebased, 1.43 GB and 32.3 M objects |
| compile-sigs, compile-hello | the compiler on `tests/perf/compile-sigs.sml` and on a hello program | a compiler run with less live data; a short one |
| runedoc-ir, runedoc-page | `runedoc` on `docs/ir.md` and on a Basis page | the other large program |
| list_ops, string_ops, array_sieve, intinf_fact | `tests/perf` | the allocating perf programs |
| fib, tak, word_bits, real_nbody | `tests/perf` | the compute-bound ones: what a tag on an int, a 63-bit word and a boxed real cost |
| MLton's benchmarks | `/home/ruud/reference/mlton/benchmark/tests`, 48 programs, `Main.doit n` with n chosen so that each allocates 200 MB to 1.5 GB (`tests/perf/mlton-bench.txt`) | the classic SML workloads: boyer, knuth-bendix, lexgen, logic, mlyacc, nucleic, ray, raytrace, simple, tsp, vliw, zern and the rest; 44 compile on Rune, 40 run, 28 were traced (*MLton's set* below) |

The Basis Library suite and the MLton regression corpus are correctness
gates, not workloads.

### The census VM

A build of `vm/new` with hooks under `RUNE_CENSUS` (`bin/runevm-census`,
run with `--jit=off` since the JIT allocates inline; on programs
compiled with `--target=registers`, the compiler's default since the
rebase, since only the register bytecode
carries representations). It gives every object an identity (an id word
added to the header in this build alone; `--count` still prints the
stock numbers, which is its acceptance test), records at each
allocation the kind, the constructor tag, the length, the allocating
instruction and function, and -- at the end of the allocating
instruction -- the tag of every field, its magnitude class (how many
bits an int or word needs; whether a real's exponent fits Koka's
immediate encoding) and the representation of the register it came
from; records every store into an existing object (the four sites)
with the ages of source and target; records the results of every
primitive and every value crossing a call by tag, magnitude and
representation; and approximates lifetimes by forcing a collection
every 256 KiB of allocation and noting which objects survive each. A
static census over the `.rbc`'s representations section counts
registers and allocation sites by representation, joined to the
dynamic counts by pc. The formats are `experiments/FORMAT.md` of the
drafts directory; M1 makes the build a target.

**The static census of the compiler** (`bin/rune.new.rbc` at `228b7b7`;
`census/static.c`): 2,130 functions, every one with a representations
section, 19,245 registers:

| Representation | Registers | Share |
|---|---:|---:|
| `any` (polymorphic) | 4,579 | 23.8% |
| `int` | 3,343 | 17.4% |
| `word` | 6 | 0.0% |
| `real` | 0 | 0.0% |
| `char` | 141 | 0.7% |
| a nullary constructor | 999 | 5.2% |
| a pointer (`heap`) | 5,363 | 27.9% |
| a constructor (`either`) | 4,260 | 22.1% |
| `unit` | 554 | 2.9% |

Allocation sites whose every source register has a known
representation: `TUPLE` 81.1% of 1,474 sites, `CONN` 64.5% of 3,087,
`CLOSURE` 84.3% of 1,235, `CON` 80.6% of 850, `MKEXN` 35.4% of 161.
The sources of allocation sites, unweighted: constructors 33.1%,
pointers 28.7%, `any` 17.1%, ints 14.4%, nullary constructors 1.9%,
unit 0.7%, chars 0.2%. Two things follow before any dynamic count: the
compiler computes no reals, so D3's cost is nil on the bootstrap and
is measured on `real_nbody` and MLton's numeric programs; and about a
sixth of what the compiler stores into objects comes from a
polymorphic register, which bounds what a raw typed field can be and
what a box at `any` costs under L4 (the pc-weighted shares are in the
dynamic tables).

**The dynamic census** (`census.txt` of each trace, `tests/out/census/NAME`
since M1; every trace's
`--count` line equals the stock VM's, its records sum to its bytes and
objects, and its samples end in the objects alive at exit):

| Workload | Instructions | Bytes (L0) | Objects | Samples at 256 KiB | Census wall |
|---|---:|---:|---:|---:|---:|
| bootstrap | 458,049,104 | 1,087,242,208 | 24,051,664 | 4,136 | 256 s |
| compile-sigs | 44,265,711 | 93,210,464 | 1,997,160 | 356 | 3.5 s |
| compile-hello | 1,681,414 | 3,431,832 | 50,731 | 14 | 0.1 s |
| runedoc-ir | 24,724,431 | 41,179,200 | 915,824 | 158 | 0.7 s |
| runedoc-page | 32,254,007 | 72,067,272 | 1,526,441 | 276 | 1.8 s |
| intinf_fact | 8,524,003 | 25,329,192 | 635,499 | 97 | 0.3 s |
| string_ops | 1,491,103 | 6,828,960 | 184,520 | 27 | 0.1 s |
| list_ops | 1,008,344 | 2,830,064 | 70,766 | 11 | 0.1 s |
| array_sieve | 1,844,333 | 1,881,600 | 18,208 | 8 | 0.0 s |
| fib, tak, word_bits, real_nbody | | 584 to 4,624 | 23 to 126 | 1 | 0.0 s |

M1 rebuilt the census from the tree (`make vm-census`, `scripts/census.sh
bootstrap`, 2026-09-27) and reproduced this table's first row to the
object: 458,049,116 instructions, 1,087,242,872 bytes and 24,051,681
objects in 4,136 samples, 321 s, the 12 instructions, 664 bytes and 17
objects more being the position closures of a seekable standard input
(`docs/testing.md`), and every share by kind and every first-order size
ratio equal to the fourth decimal (L1 0.5908, L1 with pairs 0.5022,
L4-mono 0.6319, L4-uniform 0.7067).

The bootstrap, by kind and by shape (bytes; compile-sigs in brackets
where it differs):

| Kind | Objects | Bytes | | Shape (kind, tag, fields) | Objects | Bytes |
|---|---:|---:|---|---|---:|---:|
| constructor with fields | 15.70M | 61.9% [61.9] | | list cell (CON 1, 2) | 7.43M | 27.3% [23.7] |
| tuple | 4.68M | 19.9% [20.1] | | pair (TUPLE, 2) | 3.39M | 12.5% [11.3] |
| closure | 1.85M | 8.4% [11.8] | | the map's node (CON 1, 5) | 1.45M | 11.7% [18.0] |
| array | 77k | 5.5% [2.1] | | a boxed argument (CON 1, 1) | 3.02M | 6.7% |
| ref | 1.09M | 2.4% [1.7] | | triple (TUPLE, 3) | 1.09M | 5.6% [6.9] |
| string | 648k | 1.8% [2.5] | | closure of one free variable | 1.09M | 4.0% [6.1] |
| exceptions | | 0.04% | | the hash tables' arrays (ARRAY, 64) | 38.8k | 3.7% |

Fields at allocation (55.0M): pointers 56.1%, ints 22.6%, nullary
constructors 19.1%, unit 1.7%, chars 0.5%, words and reals 0. Ints by
magnitude: 47.9% in 8 bits, 52.1% in 31, two constants of 64 bits, none
between. Fields by the source register's representation: constructor
30.1%, `any` 23.6%, pointer 18.1%, int 17.5%, a primitive's fill 9.7%.
Primitive results: nullary constructors 30.93M, ints 24.77M (19,397
over 31 bits; 35 over 48; 6 over 62; 4 over 63), pointers 15.73M, chars
2.90M, words 69, reals 0. Values crossing calls (112.1M): pointers
63.3%, ints 15.9%, nullary constructors 15.3%; from a polymorphic
register 14.9% in all, but 76.3% of the values through a closure call
(`CALL`, 6.26M) and 12.1% through a known call (`CALLK`, 52.1M).
Stores: 4,228,746 (`ref_set` 2,690,497; `array_update` 1,529,386;
`SETENV` 8,863); the new value a pointer in 2,247,342 and the object
older than it in 2,246,195 of those; `ref_set` into an object older than
32 MB of allocation 712k (26.5%), `array_update` 22k, `SETENV` none older
than 256 KB. Arrays: 41,243 with mixed elements (43.4 MB; unit then
pointers), 25,418 of booleans (12.1 MB), 10,651 of ints (4.0 MB); no
array of chars or reals, so compact elements touch 12,918 objects.
Every one of the compiler's characteristics holds for compile-sigs,
runedoc and the perf programs at their scale; `intinf_fact` is 97% list
cells of 30-bit limbs; `array_sieve`'s 113 thousand stores are booleans
into one array.

The first-order size of the same allocations under each layout, as a
fraction of L0's bytes (`layouts.h`, no collector, no lifetimes):

| Layout | bootstrap | compile-sigs | Note |
|---|---:|---:|---|
| L1, the tagged word | 0.591 | 0.592 | two fields L1 cannot hold (`Int.minInt`, `Int.maxInt`) |
| L1 + 4-byte header | 0.591 | | saves 0.03%: with 8-byte alignment a 2-field object is 24 bytes either way |
| L1 + 16-byte alignment | 0.696 | | what L5's three tag bits would cost if taken by alignment |
| L1 + headerless pairs (L5) | 0.502 | 0.511 | the list cell at 16 bytes |
| L1r, L1 + compact arrays | 0.591 | | no reals; 12,918 compact objects |
| L2, L3 (48 and 51 bits) | 0.591 | 0.592 | L1 plus two boxes |
| L4-mono | 0.632 | 0.611 | 2.79M boxes, 44.7 MB: ints from polymorphic registers |
| L4-uniform | 0.707 | 0.689 | 7.88M boxes, 126.0 MB |
| L4-mono + 4-byte header + pairs + compact | 0.539 | 0.528 | |

**MLton's set.** MLton's benchmark directory holds its 47 timed
programs and `fxp`, an XML parser that is not timed and has no input in
the suite. Of the 48 sources, 46 compile on Rune as they are; `tensor`
compiles with a three-line `Unsafe.Real64Array` shim (SML/NJ's and
MLton's unchecked array access), and `fxp` with shims for the 1997
Basis it was written against (`Timer.checkCPUTimer`'s `gc` field, the
slice-triple forms of seven `Vector` and `Array` iterators,
`Substring.all`) and a generated 2 MB XML document as its input. One
fails by design (`flat-array` checks a sum that only MLton's 32-bit
`int` overflows into: a WIDTH case, as `tests/external/mlton-skip.txt`
classes such programs). Three timed out in the first search for an
input size because it took MLton's iteration counts, which are sized
for native code; smaller inputs run them (`barnes-hut` at n = 128,
`ratio-regions` at n = 64, `smith-normal-form` at n = 1, whose time is
`IntInf` in SML), and `tensor`'s single iteration allocates 33 GB at
its own sizes, so its full trace uses a 40-square tensor and its
original form joins the large set. Fourteen programs allocate more
than 2 GB at their smallest input (`md5` 177 GB, `output1` 144 GB,
`psdes-random` 97 GB, the two `vector-concat`s 83 GB each,
`model-elimination` 79 GB, `count-graphs` 73 GB, `vector-rev` 22 GB,
`DLXSimulator` 21 GB, `zebra` 11 GB, `life` 9 GB, `mpuz` 7 GB,
`matrix-multiply` 5 GB, `string-concat` 3.5 GB); they were run at full
size in the census VM's summary mode -- no trace and no per-object
memory: the object's header carries its birth sample and each forced
collection histograms its survivors by age, which gives the nursery's
survival for every size directly -- and the seven under 22 GB were also
traced in full through `zstd` onto the archive disk. The
fifteen runs, at MLton's own sizes (census wall with four running at
a time; survival is the share of bytes alive after 256 KiB, 1 MiB,
4 MiB and 16 MiB of further allocation; the size columns as in the
table below):

| Program | Bytes | Objects | Census | Survives 256 KiB / 1 MiB / 4 MiB / 16 MiB | Real results | Int/word results | 64-bit results | L1 | L1 + pairs | L1r | L4-mono | L4-uniform |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| md5 | 177.5G | 2.02G | 44 min | 0.10% / 0.05% / 0.02% / 0.004% | 0 | 26.7G | 750M | 0.546 | 0.545 | 0.546 | 0.816 | 1.447 |
| output1 | 144.0G | 4.00G | 47 min | 0.04% / 0.01% / 0.002% / 0.001% | 0 | 1.00G | 5 | 0.611 | 0.444 | 0.611 | 0.611 | 0.611 |
| psdes-random | 97.2G | 2.25G | 39 min | 0.07% / 0.02% / 0.005% / 0.001% | 0 | 23.6G | 900M | 0.593 | 0.426 | 0.593 | 0.593 | 0.741 |
| vector32-concat, vector64-concat | 83.2G | 1.60G | 30 min | 46.2% / 46.2% / 41.6% / 14.1% | 0 | 2.00G | 4 | 0.577 | 0.500 | 0.577 | 0.962 | 1.192 |
| model-elimination | 78.8G | 1.88G | 22 min | 2.64% / 1.25% / 0.52% / 0.19% | 2.2M | 182M | 5 | 0.596 | 0.481 | 0.595 | 0.602 | 0.613 |
| count-graphs | 73.3G | 1.67G | 18 min | 0.94% / 0.32% / 0.12% / 0.04% | 0 | 249M | 4 | 0.591 | 0.448 | 0.591 | 0.777 | 0.831 |
| vector-rev | 22.4G | 401M | 12 min | 98.8% / 95.3% / 81.2% / 31.1% | 0 | 1.60G | 4 | 0.571 | 0.429 | 0.571 | 1.143 | 1.143 |
| DLXSimulator | 21.5G | 538M | 14 min | 98.8% / 95.9% / 79.1% / 28.3% | 0 | 753M | 100k | 0.600 | 0.400 | 0.600 | 1.000 | 1.000 |
| zebra | 10.7G | 278M | 3.3 min | 0.99% / 0.42% / 0.18% / 0.06% | 0 | 17.6M | 4 | 0.604 | 0.536 | 0.604 | 0.681 | 0.749 |
| life | 9.1G | 189M | 3.8 min | 5.36% / 1.43% / 0.36% / 0.09% | 0 | 18.6M | 5 | 0.583 | 0.530 | 0.583 | 0.587 | 0.587 |
| mpuz | 7.2G | 158M | 2.6 min | 0.51% / 0.14% / 0.04% / 0.01% | 0 | 373M | 4 | 0.588 | 0.446 | 0.588 | 0.732 | 0.732 |
| matrix-multiply | 5.0G | 126M | 4.4 min | 0.22% / 0.17% / 0.16% / 0.16% | 500M | 627M | 4 | 0.998 | 0.799 | 0.600 | 0.998 | 1.395 |
| string-concat | 3.5G | 60.6M | 1.1 min | 1.82% / 0.60% / 0.15% / 0.04% | 0 | 182M | 4 | 0.579 | 0.579 | 0.579 | 0.860 | 1.140 |
| tensor at [100,200] | 32.7G | 767M | 10 min | 0.91% / 0.76% / 0.58% / 0.43% | 1.19G | 440M | 5 | 0.848 | 0.689 | 0.594 | 0.601 | 0.604 |

Every run ended with the stock VM's counts, so the summary census
sees each program whole at the size MLton runs it. The set does not
change the picture of the scaled programs below; it sharpens three
parts of it. Survival lives in the vector programs: `vector-rev` and
`DLXSimulator` keep 10 to 14 MB of vectors and lists alive, so 99% of
their bytes are alive 256 KiB later and 28 to 31% after 16 MiB, and
the two `vector-concat`s 46% and 14%; a nursery promotes most of what
they allocate and copies it again, and what it copies is single
vectors of megabytes, the large-object space's case rather than the
nursery's. Everything else survives like the scaled set: under 1%
after 256 KiB but `life` (5.4%) and `model-elimination` (2.6%), and
under 0.2% after 16 MiB. The two real programs settled D3 (C, changed from B on these numbers):
`matrix-multiply` stores 125 million reals into its arrays and under
L1 allocates 0.998 of today, the whole gain boxed away, against 0.600
with Koka's rule; `tensor` 0.848 against 0.594. The untagged layout's
boxing shows at scale: L4-uniform is 1.447 on `md5`, 1.395 on
`matrix-multiply`, 1.19 on the `vector-concat`s and 1.14 on
`string-concat` and `vector-rev`, whose polymorphic vectors of words
and reals box every element; pairs pay 0.40 to 0.58 as everywhere.
And the set holds the corpus's only results with the 64th bit set in
numbers: 750 million in `md5`, 100 thousand in `DLXSimulator`, 900
million in `psdes-random`. The first two are the 32-bit word
emulation's intermediates (`lib/basis/wordn_fn.sml:11-33`: `notb` and
`<<` make a full-width pattern that `keep` masks to 32 bits), which a
63-bit word masks to the same values; the third is `Word.word`
arithmetic written for MLton's 32-bit `Word`, which already computes
other numbers at 64 bits and would at 63. None of the three stores a
word above 48 bits (the fields-at-allocation census of each), so
neither D2's option boxes anything in them.

Three runs first reported a count that differed from the stock VM's,
and each was the input rather than the VM: `life` and `DLXSimulator`
had a pipe on standard input where the stock run had `/dev/null` (17
objects: `RuneFile.positions`), `model-elimination` slices its search
by CPU time and did 4% less work on the slower VM until a `Timer` that
advances 100 µs per check made it the same run everywhere (78.8 GB
against 79.1 timed), and `tensor` prints its elapsed times, whose
digits allocate. `docs/testing.md` records the rules that came out of
this. Two programs were measured at MLton's sizes with the stock VM
only: `tensor` at [100..500] allocates 787 GB in 18.5 billion objects
(31 minutes) at the same 42.5 bytes per object as at [100,200], so its
census would have repeated the row above at five to seven hours' cost
(its live tensors of 24 MB copied at every forced collection); and
`smith-normal-form` at dim 35 had not finished after two hours in
either VM, past 2 TB allocated with its 1,225 entries near 10,000 bits
each, while dims 28, 30 and 32 allocate 1.20, 0.72 and 46.3 GB, the
size following the gcds of the elimination rather than the dimension,
so its dim-26 trace stands for it. Of the 48 sources, then, 47 ran
under the census: 33 traced in full at scaled inputs (32 timed
programs and `fxp`), 14 at full size in summary mode, and 7 of those
also in full through `zstd` (`/mnt/h/HEAPSIM/heap-layout/traces`: 51
`tar.xz` archives of the scaled programs, the compiler and the perf
programs, the 7 `zstd` directories, and every `census.txt` and `DONE`
under `census-txt/`).
The other programs were traced at inputs chosen for 200 MB to 1.9 GB of
allocation (`census/mlton-prep.sh`; the six of `knuth-bendix`, `lexgen`,
`mlyacc`, `nucleic`, `ray` and `hamlet` are kept raw, the rest archived
to `/mnt/h/HEAPSIM`). The census of each, with the first-order
size under each layout (`census-aggregate.md`; the reals column counts
Koka's rule as Koka states it, with zero, subnormals, NaN and infinity
encodable, which the census VM's rule left out):

| Program | Bytes | Objects | What it allocates | Real results | reals crossing calls | reals stored | Int results | over 63 bits | L1 | L1 + pairs | L1r | L4-mono | L4-uniform | all in |
|---|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bootstrap | 1,087M | 24.1M | 62% constructors, 20% tuples | 0 | 0 | 0 | 24.8M | 5 | 0.591 | 0.502 | 0.591 | 0.632 | 0.707 | 0.502 |
| hamlet | 1,732M | 42.4M | 41% constructors, 45% tuples | 2 | 0 | 0 | 28.0M | 5 | 0.598 | 0.529 | 0.598 | 0.702 | 0.753 | 0.529 |
| mlyacc | 410M | 9.9M | 77% constructors | 0 | 0 | 0 | 9.4M | 5 | 0.604 | 0.442 | 0.604 | 0.608 | 0.620 | 0.441 |
| lexgen | 441M | 11.3M | 79% tuples | 0 | 0 | 0 | 1.2M | 5 | 0.603 | 0.415 | 0.603 | 0.689 | 0.706 | 0.415 |
| knuth-bendix | 225M | 4.7M | 26% tuples | 0 | 0 | 0 | 22k | 5 | 0.584 | 0.523 | 0.584 | 0.589 | 0.591 | 0.523 |
| logic | 992M | 23.2M | 42% constructors, 30% tuples | 0 | 0 | 0 | 3.6M | 5 | 0.594 | 0.461 | 0.594 | 0.594 | 0.594 | 0.461 |
| boyer | 402M | 10.1M | 61% constructors | 0 | 0 | 0 | 631 | 5 | 0.600 | 0.478 | 0.600 | 0.600 | 0.633 | 0.478 |
| merge, pidigits | 208M, 251M | 5.2M, 6.3M | 100% list cells | 0 | 0 | 0 | 0.5M, 30.1M | 0, 5 | 0.600 | 0.400 | 0.600 | 0.600, 0.643 | 1.000, 0.998 | 0.400 |
| peek | 1,920M | 80.0M | 100% list cells (a polymorphic list of ints) | 0 | 0 | 0 | 90.0M | 4 | 0.667 | 0.667 | 0.667 | 1.333 | 1.333 | 0.667 |
| checksum | 560M | 10.0M | 71% tuples, 29% arrays | 0 | 0 | 0 | 90.0M | 5 | 0.571 | 0.429 | 0.571 | 0.857 | 1.143 | 0.304 |
| imp-for | 427M | 13.3M | refs of ints | 0 | 0 | 0 | 393M | 0 | 0.625 | 0.625 | 0.625 | 0.875 | 0.875 | 0.625 |
| fft | 940M | 16.8M | 71% tuples, 29% real arrays | 1,310M | 39.1M | 33.6M at allocation, 272M into arrays | 242M | 4 | 1.143 | 1.000 | 0.571 | 0.857 | 0.857 | 0.143 |
| nucleic | 416M | 6.1M | 74% tuples of reals | 83.0M | 3.8M | 15.0M | 205 | 4 | 1.135 | 1.091 | 0.559 | 0.610 | 0.614 | 0.516 |
| ray | 338M | 7.6M | 76% constructors of reals | 28.6M | 2.9M | 10.0M | 1.1M | 5 | 1.062 | 0.969 | 0.590 | 0.590 | 1.012 | 0.497 |
| raytrace | 1,528M | 24.0M | 84% tuples of reals | 610M | 16.8M | 66.5M | 4.5M | 5 | 1.260 | 1.232 | 0.564 | 0.593 | 0.619 | 0.534 |
| simple | 371M | 8.5M | 67% tuples | 9.5M | 12.9M | 4.2M | 17.1M | 5 | 0.758 | 0.588 | 0.592 | 0.794 | 0.877 | 0.407 |
| tsp | 358M | 6.4M | 70% constructors, reals in them | 10.5M | | | | 5 | 0.766 | 0.764 | 0.572 | 0.572 | 0.853 | 0.570 |
| zern | 402M | 8.0M | 93% tuples of reals, 7% arrays | | | | | 4 | 0.787 | 0.697 | 0.579 | 0.661 | 0.928 | 0.419 |
| tyan, vliw, wc-input1, wc-scanStream, tailmerge | 237M to 503M | 6.4M to 13.4M | constructors and tuples; tailmerge 100% list cells | 0 | 0 | 0 | | 0 to 5 | 0.60 to 0.61 | 0.40 to 0.53 | | | 0.68 to 0.79 | 0.40 to 0.53 |
| mandelbrot | 14 KB | 353 | nothing: reals in registers, ints into one array | 6,717M | 4,295M | 0 | 3,256M | 5 | 0.602 | 0.514 | 0.602 | 0.615 | 0.705 | 0.513 |
| even-odd, fib, tak (MLton's) | under 1 KB | | nothing: integer recursion | 0 | 0 | 0 | 1,600M to 2,000M | 0 | | | | | | |

What the set adds to the compiler's picture:

* **No program needs a 64-bit integer.** Four or five results per run
  exceed 63 bits, the Basis's start-up constants; `pidigits` and
  `intinf_fact` do their big arithmetic in 30-bit limbs, `checksum`
  and `word_bits` in words that fit; the large set's 1.65 billion
  results with the 64th bit set (`md5`, `DLXSimulator`, `psdes-random`,
  above) are a 32-bit emulation's intermediates and a generator's, and
  none of the three stores a word above 48 bits. D2's box is a path no
  program takes.
* **Boxed reals are ruinous where reals are.** Seven of the 28 have
  reals in the heap. Under L1, `fft`, `nucleic`, `ray` and `raytrace`
  allocate 1.06 to 1.26 times *today's* bytes, `tsp` and `zern` 0.77
  to 0.79 against 0.57 to 0.58 with raw fields: every real stored into a tuple or an array becomes a 16-byte
  object. Every real those programs store is encodable by Koka's rule
  (100% in each), so L1r allocates 0.56 to 0.59 like the rest; L4-mono
  gets the same from typed fields (0.59 to 0.61, `fft` 0.857 because
  its arrays are polymorphic `Array.array`s). `mandelbrot` stores no
  real and passes 4.3 billion across calls: what it needs is reals in
  registers across known calls, jit M10's last item, not a layout.
* **Boxing ints at polymorphic positions is the untagged layout's
  cost, and it is large.** `peek` (a polymorphic list of 80 million
  ints) is 1.333 under L4 against 0.667 under the tagged word;
  `checksum` 0.857 and 1.143 against 0.571; `imp-for` 0.875 against
  0.625; `merge` and `pidigits` 1.000 under L4-uniform against 0.400
  with pairs. The tagged word never boxes a small int.
* **Headerless pairs pay everywhere lists are:** 0.40 on `merge`,
  `pidigits`, `list_ops` and `intinf_fact`, 0.415 on `lexgen`, 0.44 on
  `mlyacc`, 0.46 to 0.53 on the rest.
* **Compact real arrays** are `fft`'s whole story (0.143 all in) and
  matter to no other program of the set.

### The simulator

`sim` replays a census trace under a layout's size model
(`experiments/layouts.h`, shared with the harness so that the two
cannot disagree) and a collector model, and prints bytes allocated,
the boxes a layout adds and for what, bytes copied, collections, the
largest heap, the remembered set and the survival per nursery size.
The collector models: the two-space copier with `heap.c`'s policy
transcribed (`fill_of`, `grown`, the growth guess); a nursery of 256
KiB to 32 MiB with promotion at the first or the second survival into
that copier, its remembered set from the recorded stores; sticky mark
bits (a non-moving old space, without fragmentation); a large-object
space at 2, 8 and 32 KiB; mutable objects segregated. Liveness between
two forced collections is a band, and every number that depends on it
is given as both bounds. Before any other run, the copier model was
held to the real VM: on 65 rows -- the bootstrap, compile-sigs, compile-hello, runedoc-ir,
runedoc-page and the eight perf programs at initial semispaces of 4 MiB,
64 MiB and 256 MiB with `--heap-fill 50`, and at fills 25 and 80 with 64
MiB -- the stock VM's collection count and final semispace equal the
model's lower band on every row, and its bytes copied and live data lie
inside the band: on the bootstrap's usual run the stock copies
339,135,904 bytes and the model 339,180,320 (0.013% apart; the band
there is 6% wide because one of the seven collections falls in a 256
KiB window in which 21 MB of a compiler phase's data dies), and at the
other four settings the band is 0.13 to 0.29% wide. Against the
measurement agent's heap-size sweep, run independently with a different
VM build, 7 of the 8 points match to the collection and within 0.01 to
0.1% in bytes copied (the fill-99 point differs by two collections over
a heap that doubled five times). The band is under 1% wherever the live
set is above about 30 MB; on the small programs the census's 256 KiB
interval makes the upper bound loose (`intinf_fact`'s live set is 45
KB), while the lower bound and the counts still hold. One thing the
validation taught about `--count` itself, checked on the stock VM with
compile-hello: the bytes move by 16 at each 16-byte boundary the `-o`
path's length crosses (the argument is a string object, and the
bootstrap keeps four copies of its path: 64 bytes), and a standard
stream that the VM can tell the position of -- a file, or `/dev/null`
-- costs 680 bytes, 17 objects and 12 to 18 instructions more than a
pipe (`RuneFile.positions`, `lib/basis/runefile.sml:39-56`, asks
`file_tell` once and builds the position closures when it answers); an
existing output file, the environment, address randomisation and the
program's name change nothing, and two runs alike in these give the
same count every time. Both are the program's inputs and the system's answers
showing in the count, which runtime.md's promise excludes by name, and
not a defect of the VM; a count is reproduced only with the driver's
exact arguments and redirections (`tools/heapsim/validate.sh` does;
M1's check does too).

**Heap bytes under each layout** (`sim-heap-bytes.md`; the ratio to L0's
bytes allocated, boxes included, boxing at the store level):

| Workload | L1 | L1 + pairs | L1 + 16-byte alignment | L2 | L3 | L4-mono | L4-uniform | L4 + pairs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bootstrap | 0.591 | 0.502 | 0.696 | 0.591 | 0.591 | 0.635 | 0.733 | 0.546 |
| compile-sigs | 0.592 | 0.511 | 0.691 | 0.592 | 0.592 | 0.611 | 0.703 | 0.531 |
| runedoc-page | 0.643 | 0.552 | 0.745 | 0.643 | 0.643 | 0.654 | 0.703 | 0.563 |
| intinf_fact | 0.600 | 0.402 | 0.799 | 0.600 | 0.600 | 0.655 | 0.994 | 0.456 |
| string_ops | 0.614 | 0.443 | 0.784 | 0.614 | 0.614 | 0.614 | 0.614 | 0.443 |
| list_ops | 0.600 | 0.400 | 0.800 | 0.600 | 0.600 | 0.715 | 1.000 | 0.515 |
| array_sieve | 0.539 | 0.487 | 0.590 | 0.539 | 0.539 | 0.745 | 0.848 | 0.693 |
| real_nbody | 0.766 | 0.755 | 0.830 | 0.809 | 0.723 | 0.681 | 0.723 | 0.670 |
| word_bits | 0.616 | 0.445 | 0.796 | 0.623 | 0.623 | 0.616 | 0.875 | 0.445 |
| fib, tak | 0.671 | 0.658 | 0.711 | 0.724 | 0.724 | 0.671 | 0.724 | 0.658 |

(The bootstrap's boxes under L4 are counted with their lifetimes here,
so its L4 columns are a little above the census's first-order 0.632 and
0.707.) The pattern holds on every workload: the tagged word takes 40% off,
headerless pairs another 10 to 20 where lists dominate (`list_ops`,
`intinf_fact`, `word_bits`'s lists of bits), 16-byte alignment gives a
third of it back, and boxing ints at polymorphic positions under an
untagged word costs from nothing (`string_ops`) to everything
(`list_ops` under L4-uniform is back at 1.000: a list of ints boxes
every element). L1r (reals immediate when encodable) is L1 on every
workload but `real_nbody`, where it is L4's 0.681 against L1's 0.766:
every real of that program is encodable. A 4-byte header saves nothing
(0.591 against 0.592). The 64-bit box of L2 costs two objects on the
compiler and four on `fib` (the arguments at the edge of the range in
its test), 5% of a program that allocates 600 bytes.

**Bytes copied, and the coupling question** (`sim-copied-64M.md`,
`sim-coupling.md`, `sim-survival.md`, `sim-remset.md`; the copier at
a 64 MiB semispace, the nursery at 1 MiB): For the bootstrap (`sim-answers.md`; the copier at 64 MiB with today's
policy, seven collections as the real VM makes):

| | L0 | L1, the word | L5, word + pairs | L4-mono | L4-uniform | L1 + 16-byte alignment |
|---|---:|---:|---:|---:|---:|---:|
| bytes allocated | 1,036.9 MiB | 612.6 (0.591) | 520.7 (0.502) | 658.0 (0.635) | 760.3 (0.733) | 721.8 (0.696) |
| boxes | 0 | 0 | 0 | 2.98M ints, 45.5 MiB | 9.68M ints, 147.8 MiB | 0 |
| bytes copied (lower band) | 323.5 (the VM: 323.9) | 199.4 (0.616) | 166.1 (0.513) | 168.0 (0.519) | 199.2 (0.616) | 208.1 (0.643) |
| collections | 7 | 7 | 6 | 5 | 6 | 6 |
| largest live | 62.8 MiB | 33.7 | 33.6 | 47.8 | 53.0 | 54.5 |
| nursery of 1 MiB: survival at the first minor | 25.72% | 24.83% | 23.44% | 25.22% | | |
| nursery of 1 MiB: minors | 1,034 | 586 | | | | |
| nursery of 1 MiB: largest remembered set per cycle | 13,472 entries, 838 cards | 22,054 | 27,416 | | | |

Per collection the work scales with the layout's live bytes (the word's
live set is 0.536 of today's, a little better than its 0.591 of the
bytes, since what survives is header-heavy); the nursery's survival
moves by a point (a smaller layout fits 1.7 times the objects into the
same nursery, so a few more die before the minor); the remembered set
grows with the objects a cycle holds. The number of copier collections
is a step function of the growth policy (double until half full, with
the survivor guess), so at any one initial heap a layout can gain or
lose a collection: L4-mono's 5 against the word's 7 at 64 MiB is such a
step, not a merit, and its boxes raise its live set (47.8 MiB) more than
its allocation because a box lives as long as its object. Read the
comparisons per collection or at the 1 GiB setting, where every 8-byte
layout collects zero times and today's once. So on the bootstrap as on
compile-sigs the layout and the collector compose, and D7 keeps them in
two roadmaps.. For compile-sigs the answer is already in the tables: the
nursery's survival at 1 MiB is 27.6% of the bytes allocated under L0
and 26.5% under L1 (24.7% and 23.7% promoted under a
promote-at-second-survival policy), the minors fall from 88 to 49 as
the objects shrink, the bytes a nursery copies fall to 0.536 of L0's
(the layout's 0.592 times the survival's 0.96), and the largest
remembered set per cycle is 930 entries (607 cards of 512 bytes) under
L0 and 1,502 under L1, from 24,537 old-to-young `:=` stores and 10,296
`Array.update`s over the run; no `SETENV` ever wrote into an old closure
at a 1 MiB nursery and three did at 256 KiB. So the collector's work
scales with the layout's bytes and nothing else changes: the two
savings compose, and D7 keeps two roadmaps. Survival is high for a
compiler -- 30% of what compile-sigs allocates outlives a 256 KiB
nursery and 13% a 32 MiB one, against 0% for the perf programs and
`list_ops`'s 74% of a workload that builds one list -- which says a
nursery must be several megabytes here and that the compiler's tables
would be promoted young; the large-object space would take 0.6 MB of
compile-sigs' 11.4 MB copied at 2 KiB (three hash tables' arrays), and
a sticky-bit old space would mark 20.6 MB and sweep 28 where the
copying one copies 26.7, in a heap of 32 MB against 49.

**What the bootstrap says about the collector to come** (`sim-answers.md`,
L0). Survival is high: 29.6% of what the compiler allocates outlives a
256 KiB nursery, 25.7% a 1 MiB one, 23.3% a 4 MiB one (25.2%, 23.1% and
21.4% promoted under a promote-at-second-survival policy). A 1 MiB
nursery would therefore promote 267 MB and its old space, run as
today's copier from 4 MiB, would copy another 172 MB in seven majors:
439 MB moved, against the 324 MB today's single copier moves in seven
collections from a 64 MiB start -- a nursery buys the bootstrap nothing
in bytes copied at today's heap size, and buys it a great deal at a
tight one (the sweep: 2.44 GB copied at 1.25 times live). What it buys
at any size is the heap (a 4 MiB old space growing to fit 63 MB of live
data, against two 256 MiB semispaces) and the pauses. The remembered
set at 1 MiB peaks at 13,472 entries and 838 cards per cycle, 452,036
entries over the run, from 340,898 old-to-young `:=`s and 469,232
`Array.update`s; no `SETENV` ever made an old-to-young pointer at 512
KiB or above, on the bootstrap or on any MLton program (8 did at 256
KiB, of the 8,863 `SETENV`s), so a `letrec` closure is filled within a
quarter megabyte of its allocation and a `SETENV` barrier is the
cheapest of the three, or none at all above that nursery size. A
sticky-mark-bits old space would mark 208 MB and sweep 372 in six
majors where the copying one copies 172 in seven. Objects of 2 KiB and
more are 6.1% of the bytes the copier moves (2,095 objects, 3.3 MiB live
at most; 5.1% at 8 KiB for 243 objects; 3.3% at 32 KiB), so a
large-object space is worth a threshold and a flag in the header, not a
second allocator now.

### The harness

`tests/layouts` (M2): the compiler's data structures written once in C
against a small interface -- make and test a value, box and unbox,
allocate, load and store a field (the store is the barrier's hook),
cons, the constructor's tag, a closure call through a table, structural
equality, root push and pop -- and compiled once per layout, each
layout a header of a few hundred lines with a Cheney copier of its own.
The kernels: list build, map through a closure, fold, reverse and
append; the compiler's `OrdMap` (a five-field node) and its
`StringMap`; `IntTable`'s array of ref lists with updates; closures
with free variables; `tak` and `fib` on overflow-checked tagged ints;
xorshift and a hash on 64-bit words (L1's boxes); an n-body loop on
reals in locals and the same storing into an array; string building;
structural equality on trees; and a churn over a fixed live tree at an
equal memory budget. Every kernel checksums its unboxed results and the
check fails if two layouts disagree. Measured with `perf stat` on one
core, five runs, the least kept, with gcc 13 and clang 18; differences
under 15% in cycles are reported as none.

Twenty configurations build with gcc 13 and clang 18 and every kernel
gives one checksum under all of them, at a 64 MiB semispace and at small
ones that force collections every few megabytes (`check.sh`). The timed
tables are `harness-cycles.md`, `-instructions.md`, `-l1d.md`, `-gc.md`
and `-counters.md`, made by `tests/layouts/tables.py` (least of five runs of `perf stat`
on one core, five more when the spread exceeds 5%, both compilers).
Cycles as a ratio to L0 under the same compiler, gcc 13 first and clang
18 in parentheses where the two differ by more than 10%; `~` marks a
cell within 15% of L0, which the noise here can produce:

| Kernel | L1 | L2 | L3 | L4-mono | L4-uniform | L1 + pairs | L4-mono + pairs |
|---|---:|---:|---:|---:|---:|---:|---:|
| list_ops (tabulate, map, fold, rev, append) | 0.23 (0.56) | 0.23 (0.56) | 0.23 (0.56) | 0.27 (0.52) | 0.26 (0.56) | 0.17 (0.43) | 0.18 (0.42) |
| intmap (the compiler's `OrdMap`) | 0.50 (0.60) | 0.51 (0.60) | 0.53 (0.60) | 0.52 (0.59) | 0.55 (0.66) | 0.49 (0.61) | 0.49 (0.58) |
| strmap (`StringMap`) | 0.58 (0.69) | 0.58 (0.71) | 0.60 (0.70) | 0.53 (0.66) | 0.59 (0.76) | 0.55 (0.72) | 0.57 (0.69) |
| inttable (`(int * 'a ref) list array`, updates) | 0.68 | 0.71 | 0.72 (0.83) | 0.55 (0.69) | 0.65 (0.74) | 0.55 | 0.54 |
| closures (map through closures with free variables) | 0.19 (0.62) | 0.20 (0.58) | 0.21 (0.69) | 0.17 (0.54) | 0.25 (0.74) | 0.17 (0.47) | 0.15 (0.50) |
| int_loop (tak, fib, overflow-checked) | 0.29 (0.85) | 0.33 (1.21) | 0.60 (2.27) | 0.24 (0.89~) | 0.24 (0.88~) | 0.27 (0.85) | 0.25 (0.87) |
| word_loop (xorshift, a hash with the top bit set) | 2.77 (6.15) | 3.32 (7.50) | 3.08 (7.31) | 0.44 (0.97~) | 0.43 (0.97~) | 2.57 (5.82) | 0.45 (0.96~) |
| real_regs (n-body in locals) | 1.80 (5.58) | 1.80 (4.91) | 0.60 (1.66) | 0.34 (0.93~) | 0.33 (0.87~) | 1.83 (4.90) | 0.37 (1.05~) |
| real_array (stores into a real array) | 3.50 | 3.50 (3.13) | 0.89~ (0.72) | 0.66 (0.56) | 3.32 (2.98) | 3.37 | 0.72 (0.60) |
| strings | 0.87 | 0.81 (0.95~) | 0.88~ | 0.77 | 0.80 | 0.89~ | 0.72 (0.85) |
| poly_eq_tree | 0.55 (0.69) | 0.56 (0.66) | 0.58 (0.67) | 0.71 | 0.67 | 0.37 (0.29) | 0.29 (0.24) |
| gc_churn, 8 MiB live | 0.41 (0.69) | 0.41 (0.70) | 0.41 (0.69) | 0.40 (0.65) | 0.57 (0.95~) | 0.34 (0.57) | 0.35 (0.58) |
| gc_churn, 64 MiB live | 0.35 (0.52) | 0.34 (0.51) | 0.35 (0.52) | 0.34 (0.50) | 0.48 (0.70) | 0.26 (0.44) | 0.29 (0.43) |

The variants that answer a decision, gcc (clang): `word_loop` under L1
with unboxed locals 0.44 (1.03~) against 2.77 boxed; `real_regs` under
L1 with unboxed locals 0.66 (2.76), with Koka's immediate encoding 3.71
(8.50); `real_array` under L1 with a flat real array 0.51, against 3.50
boxed; `strings` with compact byte arrays 0.76 (0.60); L1 with a 4-byte
header within noise of L1 on every kernel; 16-byte alignment 0.27
against 0.23 on lists and 0.39 against 0.35 on the churn; NaN-boxing at
51 bits within noise of 48; the card-marking barrier 0.67 against 0.68
on `inttable` (no measurable cost at this store rate). The collector's
cycles under the word are 0.21 to 0.45
of L0's on the allocating kernels (`harness-gc.md`; 0.05 to 0.18 with
pairs on lists and closures), since a smaller layout collects less
often and copies less at the same semispace; its share of a kernel's
time falls with it (the churn at 64 MiB live: 46.7% under L0, 28.1%
under the word, 20.9% with pairs).

The primitive operations alone (`harness-micro.md`; cycles per
operation, least of three, an 8 MiB semispace so that allocation stays
in the cache; gcc 13, clang 18 for L0 and L1):

| | add with overflow check | real add | field load | tag test | pointer chase | cons |
|---|---:|---:|---:|---:|---:|---:|
| L0 (gcc / clang) | 0.9 / 0.9 | 4.7 / 2.9 | 4.3 / 3.1 | 2.9 / 4.6 | 11.6 / 7.3 | 34.9 / 18.2 |
| L1 (gcc / clang) | 1.0 / 1.5 | 8.7 (a box) / 8.6 | 3.3 / 2.6 | 2.4 / 3.3 | 7.8 / 4.0 | 10.9 / 11.8 |
| L1 + Koka's immediate reals | 1.0 | 19.9 (clang 15.1) | 2.6 | 2.2 | 7.8 | 10.8 |
| L2 | 2.2 | 8.6 | 3.0 | 2.5 | 7.8 | 10.8 |
| L3 | 5.8 | 6.6 | 3.9 | 3.1 | 4.1 | 10.3 |
| L4-mono | 0.9 | 4.7 | 2.6 | 1.5 | 4.1 | 11.8 |
| L4-uniform | 0.9 | 4.8 | 2.4 | 1.5 | 4.1 | 17.1 (the head boxed) |
| L1 + pairs | 1.7 | 8.7 | 3.0 | 2.2 | 5.9 | 7.1 |
| L4-mono + pairs | 0.9 | 4.8 | 2.6 | 1.5 | 6.0 | 8.6 |

**Why the two compilers differ, and which to believe.** Under gcc,
today's 16-byte cell is materialised through memory and reloaded wider
than it was stored: `LD_BLOCKS.STORE_FORWARD` is 36 million on
`list_ops`, 64 million on `intmap`, 126 million on the churn, against
under a million under clang and under every 8-byte layout with either
compiler (`harness-counters.md`), so gcc's L0 runs at 0.44 to 0.52
instructions per cycle where clang's runs at 0.78 to 0.98 and is 1.3 to
3.3 times slower in absolute cycles, while L1 to L4 cost the same under
both. That is the stall jit M2 found in the interpreter and *The
measurements* found in every configuration of the real VM, which is
built with gcc: so gcc's ratios are what today's C pays and clang's are
the layout's own effect on code that stores and loads a value as two
matching 8-byte halves, as the JIT does. The roadmap's conclusions are
the ones both compilers put beyond 15% in the same direction.

What the harness says:

* **The word is 2 to 5 times cheaper than the cell wherever objects
  are made or passed** under gcc (list_ops 0.23 of L0, closures 0.19,
  intmap 0.50, strmap 0.58, inttable 0.68, the churn 0.35) and 1.4 to 2
  times under clang (0.56, 0.62, 0.60, 0.69, 0.68, 0.52), because a
  cons is 24 bytes not 40, the map's node 48 not 88, an option 16 not
  24, and a value crosses a call in one register; the collector's
  cycles fall to a quarter or a third with it. Structural equality
  gains a third to a half; strings, whose bytes are the same in every
  layout, gain a tenth from the smaller objects around them. The two
  compilers differ by up to a factor of three in magnitude and never in
  direction: clang makes better code of the 16-byte cell than gcc does,
  and neither makes the JIT's code, so the prototype of M4 is where the
  magnitude on the compiler is read.
* **The word loses exactly where it boxes:** every 64-bit word in
  `word_loop` (2.8 times L0 under gcc, 6 under clang; nine boxes an
  iteration) and every real in `real_regs` and `real_array` (1.8 and
  3.5 times). Unboxed locals -- the JIT's homes -- bring `word_loop` to
  0.44 of L0 under gcc (clang: parity); a flat real array brings
  `real_array` to 0.51. So D3's raw typed fields and registers, and
  M8's flat arrays, are not refinements but the condition for the word
  to win on numeric code, and the interpreter's real arithmetic, which
  has no homes, is what D5's raw slots for typed registers are for.
* **Koka's immediate encoding of reals is a 28-cycle dependent chain**
  in this implementation (rotate, mask, compare, select, or, rotate on
  each side of every operation), slower than allocating the box on a
  latency-bound loop (`real_regs` 3.71 times L0 against 1.80 boxed and
  0.66 unboxed, gcc). It saves the heap
  the boxes the census counted, and costs the mutator more than they
  did; it is worth having only at polymorphic positions, where the
  alternative is a box, and D3 says so.
* **Keeping 64-bit integers by boxing (L2) costs the tagged arithmetic
  a test:** an overflow-checked add is 6.2 cycles against 2.0 on the
  dependent chain, `int_loop` runs 0.33 against 0.29 under gcc and 1.21
  against 0.85 under clang, and `word_loop` mispredicts the box test on
  random data (3.32 against 2.77); on the allocating kernels the two
  are equal. In the VM a
  typed register is raw (the JIT's homes; the interpreter's D5 shift),
  so the test is paid where a value enters from a polymorphic position,
  not per operation; M4 measures that on the compiler.
* **NaN-boxing** pays on every int and every pointer (tag test 11.9
  cycles, add 8.7, field load 10.3): list_ops 0.76 against the word's
  0.45; its reals are immediate for free. As D1 D says.
* **The untagged layout (L4-mono) is the fastest on nearly every
  kernel** (raw everything: `word_loop` 0.31, `real_regs` 0.28, the tag
  test 3.9) and within noise of the word on the compiler's structures
  (intmap 1.53 against 1.57, strmap 1.72 against 1.61, list_ops 0.62
  against 0.45); its cost is what it boxes at polymorphic positions
  (L4-uniform: `real_array` back at 1.57, closures 0.36 against 0.19,
  the churn 1.26 against 0.76), which is D1 B's reason to take the
  word's uniform positions and the untagged layout's typed ones.
* **Headerless pairs** take list_ops from 0.23 to 0.17 (clang 0.56 to
  0.43), the churn from 0.35 to 0.26, closures from 0.19 to 0.17 and
  structural equality from 0.55 to 0.37 (clang 0.69 to 0.29), and a
  cons from 24 cycles to 16; the map's node, a five-field object, gains
  nothing.
* **Not solid** (under 15%, or placement-sensitive): the 4-byte header,
  51- against 48-bit NaN-boxing, the card barrier (a byte store),
  `int_loop` below a factor of two (builds whose executed code is
  identical range 0.25 to 0.47 s by code placement alone, and clang
  puts the word at 0.85 of L0 there against gcc's 0.29), the unboxed
  real kernels under clang, and L2 against L1 on the allocating
  kernels.

The harness's root discipline is the same in every layout (shadow-stack
slots, reloaded after allocations), its collector the same Cheney
copier, and its semispaces the same 64 MiB, so that only the layout
differs; its L4-uniform boxes fewer positions than `layouts.h`'s
upper-bound rule (typed constructor fields stay raw), which is said
where the two are compared.

### Today's VM

The results are the tables of *The measurements*: the profiles by
symbol, grouped (dispatch, collector with its `memcpy`, allocation,
primitives, equality, strings, JIT code, native code, the JIT compiler),
for the bootstrap and compile-sigs under `runevm`, `runevm-new --jit=off`,
`runevm-new` and the native program; `perf stat` with `task-clock`, page
faults, cache and TLB misses and the store-forward blocks beside the
`--stats` line, for the bootstrap, compile-sigs, runedoc-page and the
eight perf programs; and the heap-size sweep. Three facts of method:
the counters under WSL's virtual PMU multiplex beyond four programmable
events, so cycles and instructions were pinned (`:uD`) and the rest are
sampled at about two thirds of each run; `perf record` sampled at about
4,000 per second today, not the 1,000 of earlier sessions; a frame-
pointer build was used for the profiles alone. The three numbers the
decisions use most: the collector's share of the bootstrap's cycles
(7.6%, 9.4%, 17.1%, 15.9% in the four configurations), its cost per
byte copied (3.4 to 3.5 user cycles in the usual run; 2.3 to 2.7 when
the heap is small and the survivors warm, 3.9 to 5.8 when it is large
and cold), and the fraction of the bootstrap that is the collector's by
the sweep (48.7% of a run at 1.25 times live under the JIT; 13.1% of
the usual run).

### What the experiments settle, and what only M4 can

Settled here: the bytes each layout allocates and copies on every
workload, by kind and by site, exactly for bytes and to a band for
copying; how many reals, 64-bit ints and 64-bit words each layout
boxes, per workload and per primitive, at the three levels a compiler
can unbox to; the collector's work under each model -- survival per
nursery size, remembered-set and card counts, whether `SETENV` ever
targets an old closure, what a large-object space removes -- and so
D7's coupling question; from the static census, how much of the
compiler's code is at a known representation, which bounds D1 B's
typed fields; from the harness, the mutator's cost of tag tests,
boxing, overflow checks, header size, alignment and headerless pairs on
the compiler's own structures, within 15%; from today's VM, the
collector's share, the memcpy share and the heap-size curve that D15's
targets are stated against.

Two defects of the census tools are recorded here and fixed in M1: the
census numbers its samples from 0 where `FORMAT.md` says 1 (the
simulator detects which convention a trace uses), and its rule for an
encodable real classes 0.0 as not encodable where Koka's rule encodes
it (the tables above correct for it where they say so; under the
census's rule `fft` keeps 16.9 million boxes of zeros under L1r).

Only M4 can settle: the end-to-end cycles and `task-clock` of the
bootstrap and of `--jit=opt` and native code under a real layout (the
cache behaviour of the real access patterns, the interpreter's slot
traffic, the JIT's registers against the word); the cost of D5 B's maps
if they are wanted; which programs and Basis modules a 63-bit decision
would break (the MLton corpus is the instrument, after the prototype
exists); `IntInf`'s limbs under a raw word; `Real` boxing as seen
through equality and images; and everything the simulator does not
model -- locality, fragmentation of a non-moving space, the barrier's
cost inside the loop and in JIT code. And what a lazy front end's
`case` and update cost under each assignment of D4 C's pointer codes:
no lazy program runs on Rune, so M4's lazy kernels and its SML
programs over suspensions stand in (*A lazy front end*); the census
prices only the bytes. The decisions say, each, which of
the two they rest on.

## Constraints

* **C, not C++; C17 behind `#ifdef`s.** The owner's rule (jit.md,
  *Constraints*; `AGENTS.md`): anything beyond C99 behind a test of
  `__STDC_VERSION__`, so that `-std=c99` still builds both VMs. The
  layout is a header of macros and `static inline` functions, and the
  emitters take every offset by `offsetof` and `_Static_assert`.
* **A C compiler alone builds the VM from a clean checkout.** What
  `runeisa` generates is committed. A layout that needs a generator at
  build time is out; one that needs the description in `src/isa` to say
  more (a field's representation at a `TUPLE`) is in, since that is how
  every instruction changes.
* **`--count` stays the oracle.** Instructions, bytes and objects depend
  on the program and its input alone, are exact at every tier and equal
  across byte orders; across widths, instructions and objects stay
  equal, and bytes too unless D13 gives each width its word. The layout change re-bases every budget
  once, in one commit that quotes old and new (M5); after it the objects
  count is the same as before the change on every program (no layout
  here adds or removes an object except the boxes a layout needs, which
  are counted and reported as such), and the bytes are the new layout's.
* **Images stay in bytecode terms and cross machines.** The image
  format is bumped once (M5); a value is still written as tag and
  payload, a pointer as an offset, so that an image of the 64-bit VM
  restores on the 32-bit one and the PowerPC one. No native code in an
  image (jit D11).
* **`Int` and `Word` change once, by decision:** to 63 bits on 64-bit
  machines and 31 on 32-bit ones (D2 B, D13 B), with `Int64` and
  `Word64` as types of their own. `Int.precision`, `Word.wordSize`,
  `Real` semantics and the Basis suite's 137,276 checks are what a user
  sees; that change is made in M5 and nowhere else.
* **The 32-bit and big-endian VMs stay** (weak-points.md item 8, the
  portability suite). `make test-portability` passes before any change
  to the layout of a value, the heap or `vm/image.c` is done
  (`AGENTS.md`); `make windows` and `make test-windows` before a change
  to the VM core.
* **One output from every build; the interpreter stays complete.** The
  stack VM, `vm/new` at every tier and `runeopt` run the same layout,
  since they share `vm/`; the compiler's builds (five when this was
  written, seven since the rebase) emit the same
  bytecode; tier 0 runs everything. There is no layout for one engine
  alone (D11).
* **Nothing of a program on the machine stack; frames are the VM's**
  (jit D4). Roots are found in the VM's stack, by tag or by map, never
  by scanning the C stack.
* **Tests are deterministic.** Collections may move, but no test depends
  on when; `--gc-stress`, `--deopt-stress` and the sanitiser build run
  in `make check` as today.
* **The repository's rules.** One commit a milestone with `make check`
  green; a change to `vm/` also passes `make test-stress`, the sanitiser
  build, `make test-windows` and `make test-portability`; `.expected`
  files reviewed by hand; the docs that describe the layout change with
  it (runtime.md, bytecode.md, native.md, `ARCHITECTURE.md`).
* **The lasting record is `docs/`, not this file.** What is built goes
  into runtime.md and `ARCHITECTURE.md` as it lands; this roadmap is
  retired when done, as the others were.

## The architecture

```
                 the compiler: Rep, Low.rep, the representations section
                                        |
        .rbc (register bytecode; from M5 with field kinds per allocating site
              where D4 needs them; rbcVersion bumped once)
                                        |
      +------------------ vm/value.h: THE LAYOUT ------------------+
      |  the word or cell; tag tests; box and unbox; the header;   |
      |  field get and set (set = where a barrier goes); alloc     |
      |  fast path; the scan of an object; the roots of a frame;   |
      |  the image's encoding of a value                           |
      +--+-----------+------------+-----------+-----------+--------+
         |           |            |           |           |
   vm/interp.c   vm/new/       vm/prims.c   vm/heap.c   vm/image.c
   (stack loop)  interp.c +    (297 prims)  (collector,  (9-byte
                 fastprim.h                  policy,      values,
                     |                       relocate)    offsets)
              vm/new/jit/masm.c: the same operations as machine code:
              ms_alloc, ms_store_field, ms_load_obj, ms_tag_test, ...
                     |
              emit.c, compile.c (unchanged in what they say, changed in
              what the operations mean); runeopt's templates over the
              same names, or runeopt retired (D11)
```

**The layout in one header.** M3 makes `vm/value.h` (the name is
illustrative): every test of a tag, every construction of a value,
every box and unbox, every header read and write, every field access,
the allocation fast path, the collector's scan of one object and its
forwarding, the roots of a frame, and the image's encoding of one value
are functions and macros there, and nothing outside it names a tag bit,
a header field or an offset. `vm/prims.c`'s 593 lines, the two loops'
descriptions in `src/isa`, `fastprim.h`, `heap.c`, `image.c` and
`runtime.c` are rewritten over those names with today's layout as the
implementation, byte-identical output and `--count` unchanged. The
macro-assembler's operations (`ms_alloc`, `ms_store_field`,
`ms_load_obj`, `ms_load_tag_of_con`, `ms_trusts`'s loads) are the same
operations as machine code, and `emit.c` and `compile.c` say nothing
about the layout that `masm.c` does not. `runeopt`'s templates either
go over the same names, generated from the C, or `runeopt` is retired
first (D11). Then a layout is one implementation of the header and one
of `masm.c`'s operations, and M4 builds two of them.

**What the interface fixes for good, whichever layout wins:**
* the representation of a value is per position, not per program: the
  compiler's `Low.rep` says what a register holds, and the layout says
  how a value of that representation is stored in a register, in a slot
  and in a field; `any` is the uniform case;
* the form of a real at a polymorphic position (D3 C: Koka's encoding
  by default, the box behind a switch) and the width of an int (D2 B:
  63 bits by default; 64 with a box above 63 at polymorphic positions
  behind a switch) are compile-time choices of `value.h` and `masm.c`
  together, never run-time flags: every reader decodes the same way,
  the image format records which forms it holds, and the int switch is
  also a target property of the compiler (middle-end D12) and of the
  Basis's constants;
* the header, 8 bytes on 64-bit machines and 4 on 32-bit ones (D4),
  has bits the collectors to come will use and no one else may: a forwarding mark, two colour or age bits, a
  remembered bit, a pinned bit (D4 names them; M7 asserts them);
* every store into an existing object goes through one operation with a
  no-op barrier (`field_set` in C, `ms_store_field` in the JIT), and the
  compiler's `Store` is that operation; `emit.c:378`'s bypass is closed
  in M3;
* the allocation fast path is one operation with per-thread state
  (`heap_from`, `heap_used`, `heap_size` become the thread's, not the
  VM's, in name now and in fact when threads come), so that a nursery or
  a thread-local buffer changes it once;
* young and old are told apart by address (D7);
* the roots of a frame are asked from the interface, whether they are
  the tagged slots or a map;
* a value crosses into C in one register or by pointer as the layout
  says, and that is the FFI's calling convention (D9).

**Where the other plans plug in:** the collector at `field_set`'s
barrier and the allocation path (M7's hooks); threads at the allocation
state and the header bits; the FFI at the compact byte array and the
pin bit (M8) and at the value-in-a-register convention; the JIT's M11
maps at the roots interface; incremental compilation's `rt_load` at the
same roots and the descriptor table (if D4 chooses one) that grows per
unit; a lazy front end at the pointer code the gate may reserve, the
two kinds M5 reserves and the update M7 gives a barrier (*A lazy front
end*).

## Decisions

Each gives the options, what favours each, the evidence of *The
experiments* it turns on, and the recommendation it was written with.
D1 to D4 are recommended provisionally here and are the gate of M4,
where the owner decides them on the prototypes' numbers. Ten are the
owner's: D1 to D5, D7, D11 and D13 to D15. The other five -- D6, D8, D9,
D10 and D12 -- are not choices but what the recommendation fixes for
the plans around this one; they are written out so that those plans
can cite them. The owner decided all of them on 2026-09-27:

| Decision | Recommended | Chosen |
|---|---|---|
| D1. The word | B: the tagged 8-byte word, with raw fields where the type is known; headerless pairs as M4's second prototype | B; C later, in the whole-program compiler, if benchmarks show it better |
| D2. Integers and words | A: 64 bits kept; 63 bits immediate, a box above that, at polymorphic positions only | **B, 63 bits**, against the recommendation: "int/word are for things like length of lists and 63 bits is enough"; `Word64` for the algorithms that need it, unboxed where monomorphic; A (64 bits, a box above 63 at polymorphic positions) kept behind a compile-time switch of `value.h`, `masm.c` and the compiler's int-precision target property, for benchmarks (2026-09-27) |
| D3. Reals | B: raw in typed fields and registers; boxed at polymorphic positions; Koka's encoding there only if M4 shows it pays | **C**: raw where typed, Koka's immediate encoding at polymorphic positions, a box only outside its range; B kept behind a compile-time switch of `value.h` and `masm.c` for benchmarks (B at first; changed on 2026-09-27 when the large set showed `matrix-multiply` at 0.998 of today under B against 0.600 under C) |
| D4. Headers and descriptors | A: the 8-byte header kept, a raw-field descriptor in it, bits reserved for the collectors; C, headerless pairs, prototyped in M4 | **A + C (headerless pairs) on 64-bit machines; B (the 4-byte header) + D (the layout table) on 32-bit ones** (2026-09-27; A everywhere at first, with B, C and D benchmarked) |
| D5. Roots | A: the slots stay self-describing; no maps for the interpreter; jit M11's maps for deoptimisation alone | A; B benchmarked at M4 |
| D6. Allocation | as recommended: the bump kept; 8-byte alignment; minimum object 16; per-thread state in name now; a large-object space designed in, not built | as recommended |
| D7. The collector in this roadmap | A: the copier over the new layout with every hook the next roadmap needs; two roadmaps | A |
| D8. Threads | as recommended: per-thread allocation state, no collector globals, header bits, mutable objects known by kind | as recommended |
| D9. The FFI | as recommended: compact byte arrays with C's layout behind the header; a pin bit reserved; values in registers; handles for C-held values; pinning against copying, and callbacks, are the FFI roadmap's | as recommended |
| D10. Images and `--count` | as recommended: one version bump; a value written as its word and bit; objects unchanged, bytes re-based once | as recommended |
| D11. One layout for every engine | A: one, since the runtime is shared; `runeopt` retired or its templates generated, decided before M3 | **keep `runeopt`**, against the recommendation: its templates are generated from the macro-assembler's operations in M3 |
| D12. Equality, ordering, hashing, printing | as recommended: by the bit and the header; type-directed only where a raw field hides the type | as recommended |
| D13. 32-bit and wasm32 | B: the machine's word on each machine, one bytecode; objects and instructions equal across widths, bytes per width | B |
| D14. Order against the other plans | A: M1 to M3 now, beside jit M11; M4 after M11; jit M12 after M5 | the JIT roadmap is finished (M11 `798c002`, M12 `1f7e55b`, PR #21): nothing waits; M1 starts now |
| D15. What "better" means, measurably | A: the four targets | accepted |

At the gate of M4, on 2026-10-04, the owner confirmed or changed the
provisional ones on the prototypes' numbers (*M4, for the gate*):

| Decision | At the gate |
|---|---|
| D1 | B confirmed; M5 is built without raw typed fields, and raw real fields are decided after M5 |
| D2 | B confirmed: 63 bits, 8% faster than 64 on MLton's set; `Int64` and `Word64` their own boxed types, first in M5 |
| D3 | C, by the rotation encoding in place of Koka's; the VM keeps a box for each of `+0.0`, `-0.0`, the infinities and NaN (`real-encoding.md`) |
| D4 | A on every machine; C, the headerless pairs, left out of M5 and kept as branch `heap-layout-pairs`; a pointer's bits 1 and 2 kept unused, the third code reserved for a lazy front end; B and D not built (`32-bit-vm.md`) |
| D5 | A confirmed; B not built |
| D11 | unchanged: `runeopt` kept, its templates regenerated in M5 |
| D13 | A for M5: the 8-byte word on every width; B, the machine's word, is `32-bit-vm.md`'s |

### D1. The word

**Decided: B**, the tagged word with raw typed fields, provisionally
until M4's gate; and C later, in the whole-program compiler, if
benchmarks show it better. Recommended: B.

**At the gate (2026-10-04): B confirmed, and M5 built without its
second half.** The word is 0.59 of the bytes, 0.84 of the bootstrap's
cycles and half its peak memory. Raw typed fields were not built in
M4; what they were wanted for, the programs of reals, was the
encoding's cost and not the fields' (*M4, what was measured for the
gate*). Raw real fields are decided after M5 on what `nucleic` and
`raytrace` still lose; flat real arrays stay M8's.

* **A. Keep the 16-byte cell** (L0). Nothing moves; the JIT, the images
  and the budgets stay. What it forgoes is the whole of this roadmap's
  gain: the tagged word allocates 0.59 of L0's bytes on the bootstrap and
  0.50 with headerless pairs (the census, first order), copies
  0.62 as much at the same seven collections (0.44 in the upper band;
  0.51 with pairs, at six), and the harness runs the compiler's own
  structures in 2 to 5 times fewer cycles under the word with gcc
  (list building 0.23 of today, closures 0.19, the balanced map 0.50)
  and 1.4 to 2 times with clang (0.56, 0.62, 0.60), losing only where
  it boxes (D2, D3).
* **B. The tagged 8-byte word, with raw fields where the type is
  known.** The word of L1 and L2 everywhere a value can be anything: a
  slot, a polymorphic field, an argument. Where the compiler knows a
  field's representation -- a tuple of `int * real` made at a site
  whose registers are typed, a `real array`, a `Word8Array` -- the field
  is raw and the object's header says which fields are, so the
  collector skips them (MLKit's skip count, Wasmtime's bitmap). This is
  L2 first and L4 where it is free, in that order: M5 builds the word,
  the typed fields follow when the compiler emits field kinds (M5's last
  item, or a follow-up if the gate says the word alone is enough).
  **Recommended** because it takes L1's halving of every pointer-heavy
  object at once, keeps the language's 64-bit integers (D2), keeps the
  stack self-describing so that no engine needs a map (D5), and is a
  prefix of the type-directed layout rather than an alternative to it:
  nothing built for the word is undone by the typed fields. What it
  costs: every int operation is on `2n+1` (an `lea` and a `jo` for an
  add; an untag for a multiply); a real stored into a polymorphic
  position is encoded, or boxed outside the encoding's range (D3 C); the JIT's `ms_trusts` and the emitters change
  what they load (M5). Evidence: the census puts 48.7% of the
  bootstrap's bytes at sites whose every source has a known
  representation and 23.6% of its fields from a polymorphic register;
  its ints are small (52% in 31 bits, none needing 32 to 63) and it has
  no reals, so on the compiler a raw typed field saves no byte over a
  tagged one, and boxing at `any` under an untagged layout gives 4 to
  12 points back (L4-mono 0.635, L4-uniform 0.733 against the word's
  0.591). The typed fields pay for reals, 64-bit words and flat
  arrays: on MLton's numeric programs boxed reals would make the heap
  larger than today's (`raytrace` 1.26, `fft` 1.14, `nucleic` 1.14,
  `ray` 1.06) and raw fields bring it to 0.56 to 0.59. The harness puts
  the untagged layout within noise of the word on the compiler's
  structures (the map 0.52 against 0.50 of today, list building 0.27
  against 0.23) and far ahead on words and reals (`word_loop` 0.44
  against 2.77), which is what B's typed fields and registers take from
  it without its boxes at polymorphic positions (L4-uniform: closures
  0.25 against B's 0.19, the churn 0.48 against 0.35, a real array
  3.32 against a flat one's 0.51).
* **C. The untagged word everywhere** (L4 whole): every position typed,
  maps for every frame at every tier, boxes at every polymorphic
  position, descriptors on every object. MLton's layout without
  MLton's monomorphisation: the boxes at `any` positions are what GHC
  pays, and the census's `any` share says how much that is
  (23.6% of the fields the compiler writes, 23.8% of its registers). It changes the runtime in one step and can be
  staged from B, not from A; B is C's first half.
* **D. NaN-boxing** (L3). Rejected on the census: the compiler makes 24.8 million integer results and no real;
  35 of the ints exceed 48 bits. NaN-boxing costs the compiler nothing
  and gains it nothing, keeps every pointer masked and every int at 48
  or 51 bits for the programs that do compute, and no typed runtime in
  the survey chose it. B takes the reals another way.

### D2. Integers and words

**At the gate (2026-10-04): B confirmed.** On MLton's set 63 bits are
8% faster than 64 kept in the mean and nothing is slower; a loop of
ints or words pays 1.25 to 1.32 for keeping 64. `Int64` and `Word64`
are boxed types of their own whose tier-2 homes hold the 64 bits
(`RUNE_RAW_HOMES`' mechanism, for their registers alone), built first
in M5; on 32-bit machines `Int` is the same 63 bits (D13 at the
gate), not 31.

**Decided: B**, 63-bit `Int` and `Word`, against the recommendation.
The owner's reason: "int/word are for things like length of lists and
63 bits is enough; for algorithms that need word64 hopefully it will be
monomorphic and get unboxed." So the word is L1: no box for an integer
anywhere; `Int.precision = SOME 63`, `Word.wordSize = 63` on 64-bit
machines and 31 on 32-bit ones (D13 B); `Int64` and `Word64` become
types of their own, raw in a typed field or register (D1 B, D3) and
boxed at a polymorphic position, as `LargeWord` is in Poly/ML; `IntInf`
keeps its limbs; the hash functions and `word_bits` change their
answers; the Basis suite's expectations move where they name 64 (the
matrix already runs 63-bit hosts, SML/NJ and Poly/ML, so the mechanism
exists). The harness's price for A over B (an add 2.2 cycles against
1.0 on the tagged path; `int_loop` 0.33 against 0.29) is what B saves.
Recommended: A.

Added on 2026-09-27, after the large set: A stays available behind a
compile-time switch, as D3's box does (`-DRUNE_INT64`, the name
illustrative). Under the switch `value.h` and `masm.c` carry a second
implementation of the int and word operations (the harness's L2 over
its L1: make and unbox, the checked add, subtract and multiply, a box
kind the collector and equality know), the compiler's int precision
follows it as the target property middle-end D12 made it, the Basis
reads `Int.precision`, `Word.wordSize`, `minInt` and `maxInt` from the
runtime, and `Int64` and `Word64` are aliases of `Int` and `Word`
there (64 and 32 bits per machine under D13 B, against 63 and 31).
What the switch costs, stated because it was the reason to recommend
against carrying it: the box path stays alive and tested in every
engine, and the budgets and the Basis suite's 63-or-64 expectations
exist per build (the matrix already runs 63-bit hosts, so the
deviation mechanism exists). It is a target option, not a VM flag
alone: a 63-bit and a 64-bit build compile a program differently, and
the two builds are compared on the same source, not the same `.rbc`.
M4 builds it as a variant and M5 keeps it.

Noted on 2026-09-27, from the property-testing roadmap
(`docs/plans/quickcheck.md`, its *Risks*; merged into master since, with
the generator as `lib/random/random.sml` and its tests in `make check`:
*After the rebase*).
- **The workload.** Its random generator, SplitMix64, is `Word64` arithmetic of `word_loop`'s shape, in a library whose generators pass 64-bit addresses and seeds as arguments at every node.
- **What B does to it.** Under B with D5 A, those words are raw only in tier 2's register homes and in typed fields. They are boxed wherever they cross a slot: an argument, a result, the interpreter's frames, `runevm`. "Monomorphic" alone does not keep them unboxed.
- **What the harness says.** `word_loop` costs 2.77 times today's cycles boxed (6.15 under clang), against 0.44 unboxed in locals. With the top bit set in half the outputs, A's switch boxes them too.
- **For M4's gate.** Its `Word64` kernel is a workload: `exp_speed.sml` with `splitmix.sml` and `prop.sml` under `~/.cache/claude-rune-drafts/quickcheck/proto/`. It is run as that roadmap's E2 on `runevm`, `runevm-new` with and without the JIT, and MLton. It prices B, A's switch and D5 B's maps on real `Word64`-heavy code, as the compiler prices the allocating kernels.

* **A. `Int` and `Word` stay 64 bits.** In a typed register or field
  the value is raw (B of D1); in a polymorphic position it is
  `2n+1` when it fits 63 bits and a box of 16 bytes when it does not,
  Poly/ML's path for its long integers. `Int.precision` and
  `Word.wordSize` stay 64; the Basis suite and every program stay as
  they are. The cost is a branch on the overflow path of every
  polymorphic addition and a test before every use of a polymorphic
  word; the census counts how often a value needs the 64th bit: on the
  bootstrap four integer results (`int_add`, `int_sub`, `int_neg` at
  start-up) and one word result of 25 million, and two stored fields
  (`Int.minInt` and `Int.maxInt`); 19,397 results exceed 31 bits, the
  hash functions' products, and all fit 63; on MLton's large set,
  `md5`, `DLXSimulator` and `psdes-random` make 1.65 billion results
  with the 64th bit set (a 32-bit word emulation's intermediates and
  a generator on `Word`) and store none above 48 bits, so they box
  nothing either (*The experiments*). The box is a path never
  taken by the compiler; what remains of A's cost is the check on the
  overflow path, which the harness measures. **Recommended** at writing: the owner's rule, kept at a
  measured cost. Kept behind the compile-time switch (decided).
* **B. 63-bit `Int` and `Word`**, OCaml's and SML/NJ's choice. One
  instruction fewer on the overflow path, no box anywhere, `Word` ops
  simpler by one mask. Against it: the language changes
  (`Int.precision = SOME 63`, `Word.wordSize = 63`, `Word64` a boxed
  type as SML/NJ's), every hash and every `word_bits`-shaped program
  changes its answers, the 32-bit VMs' 64-bit-in-software arithmetic
  must become 63-bit-in-software, and the owner's brief asks for
  "clear evidence of the performance benefits". The harness puts a
  number on the difference between A and B where every operand is a
  tagged word: an overflow-checked add is 6.2 cycles against 2.0, `int_loop`
  runs 0.33 against 0.29 of today under gcc and 1.21 against 0.85
  under clang, a test on random words mispredicts (`word_loop` 3.32
  against 2.77), and the allocating kernels are equal. That is the
  interpreter's case; the JIT's typed registers are raw under either
  and pay the test only where a value enters from a polymorphic
  position. The recommendation is A, and M4 measures its cost on the
  compiler under the JIT, which is where the owner's rule is priced.
  **Decided.**
* **C. 62-bit** (Chez's 61 on 64-bit, `4n+1` as Koka's) for an
  addition without untagging: a variant of B with the same language
  cost, noted for the harness.

### D3. Reals

**At the gate (2026-10-04): C, by the rotation encoding.** Koka's
encoding, described below, is what the prototypes ran and what made
the programs of reals 1.2 to 1.5 times slower than today: fifteen
instructions and four branches wherever a real leaves a register.
The encoding M5 builds is the double's bits with 2^61 added and
rotated left by two, an immediate where the low bit is then set
(exponents 0x200 to 0x5ff, a real between 2^-511 and 2^513), seven
instructions and one branch to decode; zero, the subnormals, the
infinities and NaN are boxes, and the VM keeps one box for each of
`+0.0`, `-0.0`, the two infinities and NaN. With it and 63-bit
integers the eight programs run 1.03 of today's cycles. No raw real
fields in M5 (D1). `real-encoding.md` lists what is left to try.

**Decided: C** (2026-09-27). The first decision was B, "and C
benchmarked, may change my mind if it helps"; it changed the same day
when the large set showed `matrix-multiply` at 0.998 of today's bytes
under B, all 125 million of its stored reals arriving through a
polymorphic position (`Array2.tabulate`'s function), against 0.600
under C (*The experiments*, MLton's set). The form of a real at a
polymorphic position is a compile-time choice of `value.h` and of
`masm.c`'s operations together: the VM builds with B behind a switch
(`-DRUNE_REAL_BOXED`, the name illustrative) so that the two can be
benchmarked side by side at M4 and after; a run-time flag is ruled
out, since every reader of such a value must decode it the same way
and the image format must know which form it holds. The encoding is a
bit-for-bit bijection (the sign and the 52 mantissa bits carried
whole, the exponent squeezed to ten bits; zero, subnormals, infinity
and every NaN payload encodable; the rest boxed with their raw 64
bits), so IEEE 754 behaviour is unchanged: arithmetic runs on decoded
doubles, and encode and decode are integer moves, rotates and masks,
never a float conversion. The recommendation at writing was B; the
harness's latency numbers below are why, and the census's stored-real
counts are why C won.

* **A. Boxed always** at 16 bytes (OCaml, SML/NJ). Simplest; `real_nbody`
  becomes an allocator: it produces 335 thousand reals and allocates
  752 bytes today; boxed at every result it would allocate 5.4 MB, and
  MLton's `mandelbrot` 107 GB for its 6.7 billion (the census).
* **B. Raw where the type is known, boxed at polymorphic positions.**
  A real in a register of representation `real` is raw (the JIT's
  homes keep it in `xmm` already; the interpreter's slot holds it raw
  with the slot's kind known from the representations section -- see
  D5); a real in a typed field or a `real array` is raw (D1 B, D4); a
  real stored into an `any` field or passed to a polymorphic function
  is boxed. Evidence: the compiler produces, passes and stores no real at
  all; MLton's numeric programs are where the three levels are counted:
  `raytrace` produces 610 million reals, passes 16.8 million across
  calls and stores 66.9 million; `fft` 1.3 billion, 39 million and 306
  million (272 million into arrays); `nucleic` 83, 3.8 and 15 million;
  `ray` 29, 2.9 and 10 million; `mandelbrot` 6.7 billion, 4.3 billion
  across calls and none stored. Boxing at every store is 1.06 to 1.26
  of today's bytes; every stored real of every program is encodable
  under Koka's rule. **Recommended.**
* **C. Immediate when the exponent fits ten bits** (Koka's L1r) on top
  of B for the polymorphic positions: no box for almost every real, a
  test on the result of every real operation that reaches a
  polymorphic position. Kept as a measured option: every real stored by any
  of the 31 traced programs is encodable under Koka's rule (the census,
  with zero, subnormals, NaN and infinity encodable as Koka has them;
  the census VM's own rule counted zero as not encodable and put the
  share at 79 to 87% for that reason), and the harness measures the
  test's cost (28 cycles per real operation on a dependent chain in the harness's
  implementation, so `real_regs` runs at 3.71 times today encoded
  against 1.80 boxed and 0.66 unboxed, gcc: worth having only where the alternative is a
  box, a real stored at a polymorphic position, and never on the
  arithmetic, which B keeps raw). Built in M5 as the default; B stays
  behind the compile-time switch, and M4 measures the two builds side
  by side. **Decided.**
* **D. Immediate always** needs a 16-byte cell (L0) or NaN-boxing (L3),
  both rejected under D1.

### D4. Headers and descriptors

**At the gate (2026-10-04): A on every machine.** The headerless
pairs of C pass every suite and are left out of M5: they buy memory
(0.83 of the word's bytes, a fifth less kept at a collection) and no
time, and no resident memory on the compiler while the semispace
grows by doubling. They stay as branch `heap-layout-pairs`; bits 1
and 2 of a pointer stay unused for their two codes, and the third
code stays reserved for a lazy front end. B and D, the 32-bit header
and its table, were not built and are `32-bit-vm.md`'s.

**Decided: A with C on 64-bit machines, B with D on 32-bit machines**
(2026-09-27; A everywhere at first, with B "interesting for 32-bit
targets" and C and D benchmarked as "may be interesting enhancements
if benchmarks show good results"; C was decided the same day on the
harness's numbers below, and D for the 32-bit width because its
4-byte header has no room for the descriptor). Recommended: A.

One abstraction, two headers: `value.h`'s accessors (kind, tag,
length, the collector's bits, the descriptor, `obj_size`) choose by
the pointer size, and the allocator writes whichever applies. On
64-bit the 8-byte header of A. On 32-bit a 4-byte header: kind (4
bits), the collector's four bits, D's 12-bit layout index (the
constructor tag and the raw fields from the table; the census's
largest tag is 31 and the bootstrap has 1,435 shapes) and a 12-bit
length whose all-ones value says the length is in the word after the
header, so arrays and strings over 4,095 elements pay 4 bytes and
every length read carries a predictable branch. The 32-bit header
has no room for the raw-field descriptor, which is why D supplies it
there: the table gives the 32-bit build exact raw fields at the
table's cost, and M5 fixes the bit split on the linux32 numbers. Ceilings,
the runtime tests' size assertions and the byte budgets become per
width, which D13 B makes them anyway; the image format already writes
kind, tag and length as fields, so it needs only the escape. The
consumers on 32-bit are C alone (the two interpreters, the
primitives, the collector, the images): the JIT is x86-64 and
aarch64 and `runeopt` x86-64. The gain is on 32-bit only, where D13
B's 4-byte fields make a list cell 12 bytes instead of 16; on 64-bit
the census puts B at 0.03%. C on 32-bit would need 8-byte alignment,
since 4-byte alignment leaves a pointer two low bits, one for the
immediate tag and one spare.

* **A. The 8-byte header kept**, its fields re-cut: `kind` (4 bits:
  nine kinds), the constructor tag (16), `len` (32), and twelve bits
  (today's `pad` and the kind's spare half): a raw-field descriptor for small objects (which of the first
  fields are raw; longer descriptors from a table the compiler emits,
  or a kind that says "all raw", as `K_STRING` says now) and the bits
  the collectors need -- forwarding (the kind, as today), two colour or
  age bits, remembered, pinned -- named and asserted from M7. One
  header for every kind; `obj_size` from the header alone; `K_FORWARD`
  as today. How far the descriptor reaches, from the census: on the
  bootstrap 92.1% of objects (79.5% of bytes) have at most four
  fields, 7.4% (14.2%) five to eight, and 0.5% (6.3%) more, and those
  are arrays and long tuples, homogeneous. With the kind at four bits
  the descriptor takes eight, the first eight fields, and covers 99.5%
  of objects; the rest are an all-raw kind or the escape, one reserved
  descriptor value that says the layout is in a word inside the
  object, 8 bytes and a load for that object alone, and the compiler
  places raw fields first in a wide record (MLKit's rule) to make the
  escape rarer still. **Recommended:** it is what every consumer
  already reads, and the byte it spares is enough. **Decided for
  64-bit machines, with C.**
* **B. A 4-byte header.** Saves four bytes on objects of an odd number
  of words only (0.03% of the bootstrap's bytes, the census: with 8-byte alignment
  a two-field object is 24 bytes with either header); costs an escape for
  long arrays and strings and a narrower `contag`. Not worth its
  complexity unless the simulator says so. **Decided for 32-bit
  machines**, where D13 B's 4-byte fields make the header a quarter of
  a small object; the length escape and the descriptor's absence are
  above.
* **C. Headerless small objects with the kind in the pointer** (L5).
  The list cell at 16 bytes and a `case` without a load, at the price
  of 16-byte alignment or a segregated space, and a forwarding scheme
  for a header that is not there. The census says the bytes: 0.502 of L0 against the word's 0.591,
  since list cells are 27% of everything the compiler allocates; the
  simulator says the bytes copied (the bootstrap at 64 MiB: 166 MB with
  pairs against 199 with the word alone and 323 today, in six
  collections against seven) and the harness the
  cycles (list building 0.17 of today against the word's 0.23, the churn 0.26
  against 0.35, structural equality 0.37 against 0.55, closures 0.17
  against 0.19, a cons 16 cycles against 24; clang agrees in direction
  on each). With 8-byte alignment a
  pointer has three low bits: one says immediate, and the other two
  name a headerless shape and its constructor tag (a list's `::`, a
  pair), which is enough without Chez's 16-byte alignment -- the census
  puts that alignment at 0.696, most of the pairs' gain given back. Those numbers are large, and C is **decided for 64-bit machines**
  (2026-09-27): M4's second prototype is its first build, on A's word
  (it touches the collector's scan, the forwarding scheme and the
  emitters' `case`), and M5 builds it. Not on 32-bit, where it would
  need 8-byte alignment (above).
* **D. A type index into a per-program table** (MLton, Julia) instead
  of the raw-field descriptor: exact layouts for every object,
  monomorphic or not, at the cost of a table that grows per unit under
  incremental compilation and that every image must carry. The
  descriptor in the header covers what D1 B needs on 64-bit, so D is
  not built there; it is **decided for 32-bit machines** (2026-09-27),
  where the 4-byte header has no room for a descriptor and the table
  gives that width exact raw fields: a 12-bit layout index in the
  header (the constructor tag and the raw fields from the table; the
  bootstrap has 1,435 shapes) beside the kind, the collector's bits
  and a 12-bit length with its escape, the split M5's to fix on
  linux32. The table is emitted per program by the compiler, checked
  by the loader, carried by every image and merged per unit under
  incremental compilation. D stays the road to C of D1 on every width.

Noted on 2026-09-28, for a lazy front end (*A lazy front end*):
- **C's codes are not yet assigned.** The two bits give three
  non-zero codes. A lazy front end wants one of them to mean "a
  headered object, known to be evaluated", so that a `case` need not
  load a header to rule out a thunk.
- **What that costs SML.** The census prices it at 0.093% of the
  bootstrap's bytes and nothing on MLton's set, first order: the
  headerless objects a third shape would have kept. M4 builds both
  assignments behind a switch, and the gate decides.
  **Recommended:** reserve it.
- **C's 0.502 is an upper bound.** The simulator makes every two-field
  constructor headerless, which three codes cannot. About 0.94% of the
  bootstrap's bytes keep a header under any assignment, and M4
  re-makes the number for the codes built.
- **A's kind reserves two values**, `K_THUNK` and `K_IND`, in M5.

### D5. Roots

**Decided: A**, and B benchmarked at M4. Recommended: A.

**At the gate (2026-10-04): A confirmed.** B was not built. What A
costs is known: a 64-bit word or a real that crosses a slot is boxed
or encoded there (SplitMix64; the programs of reals), which D2 B and
the rotation of D3 reduce to 1.03 of today on the reals.

* **A. The slots stay self-describing.** Every slot of the value stack
  is a tagged word: an immediate or a pointer, told by its bit. A raw
  int or real lives in a slot only where the interpreter's instruction
  knows the slot's representation from the representations section --
  so the interpreter keeps typed registers tagged in their slots (a
  shift on load, a shift on store) and only the JIT's homes hold them
  raw, written back tagged at safepoints as M9 built it. The collector
  walks the stack by bit, as Poly/ML's does; no map at any tier;
  images, `--trace` and a fatal error read a slot as today.
  **Recommended:** it keeps jit D4 and D10's rule and M9's write-back,
  and costs the interpreter a shift where the JIT pays nothing.
* **B. Maps per pc for the interpreter's frames**, from the
  representations and liveness, so that typed slots hold raw values in
  the interpreter too. Saves the interpreter a shift per typed access
  and makes its roots precise by liveness; costs a map per pc in the
  bytecode (or computed at load) and a collector that consults it, at
  every tier, for every engine, and in images. M11's maps are a special
  case (tier 2's registers at safepoints). Measured in M4 as a variant
  if the interpreter's shifts show in its profile.
* **C. Conservative scanning** of slots or of the C stack: never;
  jit D4 keeps nothing on the machine stack and nothing here changes it.

### D6. Allocation

**Decided: as recommended** (not the owner's to weigh). A consequence of D1 and
D4, with the simulator settling its one variable.

* The bump stays the fast path in C, in the JIT's `ms_alloc` and in
  the templates if `runeopt` stays; objects 8-aligned (enough for D4 C's two shape bits); the minimum object a header and one word, so that a
  forwarding pointer fits; `heap_from`, `heap_used` and `heap_size`
  named as the allocating thread's state now (one thread, one state)
  so that a nursery per thread is a change of one struct later; a
  large-object space for objects above a threshold, kept out of the
  copy, if the simulator's LOS model shows the copied bytes it saves
  are worth a second allocator -- it does not: objects of 2 KiB and more
  are 6.1% of the bytes the bootstrap's copier moves, 5.1% at 8 KiB (243
  objects) and 3.3% at 32 KiB
  (*The experiments*) -- so it is designed in (a threshold, a header
  flag, a pinned page for the FFI) and not built here. Zeroing: the fill of unit into fresh
  fields stays the instruction's, not the allocator's.

### D7. The collector in this roadmap, and whether it is one roadmap

**Decided: A**, two roadmaps. Recommended: A.

* **A. The copier, over the new layout, with the hooks.** M5 carries
  the Cheney copier onto the new word and header; M7 rewrites it
  without file-static state, with the header bits asserted, the
  barrier operation in place as a no-op, young and old told apart by
  address, per-thread allocation state, a large-object space if D6
  says, `--stats` extended, and the generational roadmap's brief
  written from the simulator's numbers. The brief's question -- are the
  layout and the collector "so related they need to be done in one
  roadmap" -- is answered by the simulator: the word copies 0.62 of today's
  bytes at the same seven collections of the bootstrap (0.51 with
  pairs), a 1
  MiB nursery's survival is 24.8% under the word against 25.7% today,
  its minors fall with the bytes (586 against 1,034) and its remembered
  set grows with the objects a nursery holds (22,054 against 13,472
  entries at the peak); nothing else moves (*The experiments*). **Recommended** if, as expected,
  they compose: the layout halves what is copied and the nursery
  changes the heap a program needs and its pauses, and neither changes
  the other's choice. The simulator adds a warning the next roadmap
  starts from: the compiler's survival is high (a quarter of what it
  allocates outlives a 1 MiB nursery), so at today's 256 MiB
  semispaces a nursery moves more bytes than the copier does, and pays
  only at tight heaps, in memory and in pauses. What the layout must fix for the collector to come, it fixes
  (*The architecture*).
* **B. A nursery in this roadmap** as well. The barrier is one
  operation and the remembered set a list; the nursery is performance.md
  item 13's 400 lines. Against it: M5 is the largest milestone Rune has
  had, and every one of its suites must pass under a collector that is
  otherwise unchanged before another collector is measured against it.
  If the simulator shows the two are coupled -- a layout that only pays
  with a nursery, or a nursery whose size the layout decides -- B, and
  M7 becomes the nursery.

### D8. Threads and many cores

**Decided: as recommended.** Not the owner's to weigh here; the
multithreading roadmap decides between per-thread young heaps with a
shared old space (OCaml 5, Manticore, GHC) and per-process heaps
(Erlang) and this roadmap closes neither. What it fixes: the allocation
state is per thread; the collector has no global state; the header has
the two bits a concurrent marker needs and one for a remembered object;
mutable objects are known by kind (`K_REF`, `K_ARRAY`, a closure written
by `SETENV` -- M5 gives such closures their own kind or bit, so that
"immutable" is a property of the kind); an immutable object may be
copied freely between heaps; young and old are told by address, so that
a per-thread nursery is a range. What it does not do: no lock word, no
identity hash, nothing atomic in the fast paths.

### D9. The FFI

**Decided: as recommended** (not the owner's to weigh here). What the word and
the header fix for the FFI roadmap, which decides the rest (pinning
against copying around a call, callbacks). The owner's note asks where
the FFI becomes critical; here it is twice: at M5, where the calling convention of a
value into C is fixed (a tagged word in one register, a raw int or
real in one register where typed, as the JIT's transition into C does
it), and at M8, where the objects a foreign call reads and writes are
made: a compact byte array whose bytes are C's behind the header
(`Word8Array`, `CharArray`, strings), a flat `RealArray`, and a pin bit
in the header that the copier honours by not moving a pinned object
(a pinned object lives in the large-object space or a pinned page,
GHC's pinned blocks) or, until a non-moving space exists, by copying
in and out around the call (MLton's answer: no pinning at all). Values
that C holds across a collection go through a handle table that is a
root (OCaml's generational global roots, GHC's `StablePtr`). Callbacks
from C into SML stay jit.md's question (the no-nesting rule). What this
roadmap does not build: the FFI itself, `_import`, marshalling of
tuples and datatypes.

### D10. Images and `--count`

**Decided: as recommended** (not the owner's to weigh). A consequence of D1 and
D13. One image version bump at M5: a value is written as
its word plus one byte saying whether it is a pointer (so that a 32-bit
VM reading a 64-bit image, and a big-endian one, need no arithmetic on
the word beyond the byte order), a pointer as an offset plus one as
today, an object as its header and its fields or bytes, raw fields as
their bits; the heap is still not collected before it is written
(performance.md item 13's suggestion is the next roadmap's). `--count`'s
objects are unchanged by the layout on every program but for the boxes
a layout adds, which are objects and counted; the bytes are re-based in
one commit that quotes every budget's old and new number; across
widths the portability suite holds instructions and objects equal, and
bytes equal under D13 A or per width under D13 B, where an image also
crosses to a narrower machine only if its integers fit. `Runtime.stats` keeps its fields; its
documentation loses the sentence about 16, 24 and 40.

### D11. One layout for every engine, and `runeopt`

**Decided: keep `runeopt`**, against the recommendation. So M3 begins
with the generator of its templates from the macro-assembler's
operations (about 400 lines), and `runeopt` follows the layout through
M4 and M5 as a third engine of the same operations, never as a copy by
hand. Recommended: retirement. The runtime is one library: `vm/heap.c`, `prims.c`,
`image.c` and `runtime.c` serve the stack VM, `vm/new` at every tier
and `runeopt`'s programs, so there is one layout or two runtimes, and
two runtimes would double the 2,148 lines of primitives. `runeopt`'s
968-line translator copies the layout by hand a third time
(`src/opt/x64.sml`, *Who depends on the layout*). Jit D11 left "what
`runeopt` is for" to the owner once tier 1 matched it, and M7 did
(bootstrap 0.57 of the interpreter against `runeopt`'s 0.58) and M10
passed it. So: **decide `runeopt` before M3.** Retired, M3 and M5 have
one copy fewer to keep in step and `native.md` becomes history; kept,
its templates are generated from the macro-assembler's operations in
M3 so that they cannot drift, which is a milestone of its own (about
400 lines of generator). The recommendation is retirement; the
roadmap's sizes assume it and say what the other answer adds.

### D12. Equality, ordering, hashing and printing

**Decided: as recommended** (not the owner's to weigh). A consequence of D1 and
D4. `values_equal`, `poly_cmp` and the hash of a
polymorphic key walk an object by its header: the bit tells an
immediate from a pointer, the header tells the kind and the raw
fields, and a raw field compares as its bits (an `int` or a `word`) or
as a double (a `real` field, whose kind the descriptor names; `Real.==`
is not `=` in SML, and a raw real field never reaches polymorphic
equality at the language level, but `values_equal` must still walk
past it). The REPL's printer (incremental D10) prints a value from its
tag today and would print a raw field only with its type; the
descriptor names the kind of a raw field, so the printer stays
tag-directed, and the type-directed printing that incremental D10's
option B describes is needed only for what no descriptor can say: a
raw field's SML type beyond int, word, real, char. `imm_eq` stays as it
is.

### D13. The 32-bit VMs and wasm32

**At the gate (2026-10-04): A for M5.** B was decided and never
prototyped: both prototypes run the 8-byte word on the 32-bit VMs,
and pass the portability suite so. M5 keeps that, with `Int` 63 bits
on every machine, and the machine's own word is `32-bit-vm.md`'s,
with the experiments that would decide it. On the 32-bit interpreter
the word prototype with 63-bit integers and the rotation runs the
bootstrap in 1.03 of the 16-byte layout's instructions and 0.59 of
its bytes (`real_nbody` 1.22): M5 gives the 32-bit VMs the memory and
not the time.

**Decided: B.** Recommended: B. The owner's note that Rune is "always 64-bit even
on 32-bit platforms" describes the architecture as it is; on 2026-09-27
the owner said they would take 64-bit integers on 64-bit machines and
32-bit ones on 32-bit machines, with one bytecode, if it costs nothing.

* **A. An 8-byte word on every width.** On i386 and wasm32 a tagged
  word is two machine words and a pointer sits in the low half with the
  tag bit, as today's 8-byte payload holds a 4-byte pointer; ints are
  64-bit in software as today (runtime.md, *Numbers*). Object sizes,
  bytes allocated and images are identical across widths, which is what
  the portability suite checks today, and the 32-bit VMs stay 1.4 to
  1.8 times slower than they need be.
* **B. The machine's word on each machine.** A tagged word is 8 bytes
  on a 64-bit machine and 4 on a 32-bit one; `Int` and `Word` are 64
  and 32 bits, 63 and 31 immediate with D2's box above; a pointer is
  the machine's; objects are half the size on 32-bit machines, which
  is what every runtime in the survey does. **Recommended** because it
  costs nothing where it matters: on a 64-bit machine the layout is
  B's word exactly as A's, so the compiler, the JIT and every number of
  *The experiments* are unchanged; the 32-bit VMs gain the 1.4 to 1.8
  times they pay today for 64-bit ints in software. What it costs, and
  where: (1) `Int.precision` and `Word.wordSize` become the machine's,
  as SML allows and as SML/NJ's 32-bit build has them, so the Basis
  suite's expectations are per width where they name 64 (the matrix
  already runs a 31-bit host, SML/NJ 32-bit, and its annotations are
  the mechanism); (2) one bytecode for both widths means the compiler
  folds an integer constant only when the result fits 32 bits and
  emits the arithmetic otherwise, so that the 32-bit VM raises
  `Overflow` where the 64-bit one computes (middle-end D12's precision
  per target, applied as "the narrowest target the bytecode is for");
  (3) `--count`'s bytes differ per width: the portability suite
  compares instructions and objects across widths and bytes within a
  width, and the budgets are the 64-bit machine's; (4) an image
  written by a 64-bit VM restores on a 32-bit one only when every
  integer in it fits 32 bits, which the reader checks and refuses
  otherwise (as `Runtime.restore` refuses another program's image); (5)
  `IntN` and `WordN` for N above the machine's word are boxed on the
  32-bit VM, as `Int64` is on SML/NJ's. Built in M5 with the 32-bit
  builds; decided by the owner there if the compiler's folding rule
  turns out to cost the 64-bit code anything, which nothing here
  predicts.
* **C. Drop the 32-bit VMs.** Not proposed: weak-points.md item 8
  calls them a strength, and wasm32 is coming.

### D14. Order against the other plans

**Decided: the JIT roadmap is finished** (2026-09-27: M11 `798c002`,
M12 `1f7e55b`, merged as PR #21 `d278153`), so nothing of this roadmap
waits on it and M1 starts when the owner names the branch; what follows
is the reasoning as written, before that. M1, M2 and M3 change no layout and can start now,
beside jit M11 (deoptimisation), which they do not touch: M3's
interface is where M11's maps will be consumed, and both are about the
same files' names, not their meaning. M4 (the prototypes) and M5 (the
change) come after M11 is committed, since M5 rewrites what the
emitters load and M11 adds the maps that must survive that. Jit M12
(aarch64) comes after M5, so that its allocation path and its
transition into C are written once, against the new layout -- the
same argument jit D14 made for the collector. The incremental roadmap
starts after jit as planned; its `rt_load` appends to the same roots
and, if D4's descriptors grow a table, to that table. The FFI and
threads roadmaps are drafted after M7, with M7's hooks and M8's objects
in hand.

### D15. What "better" means, measurably

**Decided: accepted.** Four targets, measured with M1's tools against
`228b7b7` and this roadmap's tables, on `runevm-new` at its default
settings (`rune:new` in docs/performance.md) first: the owner named it
the optimisation target on 2026-09-27, as the fastest way to run Rune
today and the default to come; `runevm` and `runeopt`'s code are
reported beside it and held only to "not slower" (target 3). Since the
rebase of 2026-10-03 that configuration is the default, and the
baseline of every target is the 16-byte layout on the rebased sources
(the branch at M3), where the text says `228b7b7`: the bootstrap is a
third larger there, and its shares are in *After the rebase* (the
collector's 17.1% and 15.9% of target 2 are measured again at M4,
before the prototype is).

1. After M5, the bootstrap allocates at most 60% of its bytes under
   `228b7b7` at the same object count plus the boxes (the census's
   first-order 0.502 for the word with headerless pairs, D4 C; 0.591
   without), and every workload of *The workloads* within
   the simulator's prediction by 5%.
2. After M5, the collector's share of the bootstrap's cycles under
   `--jit=opt` and under the native program falls by the share of bytes
   it no longer copies (from 17.1% under the JIT and 15.9% in native
   code, *The measurements*), and the bootstrap's
   cycles under `--jit=opt` fall by at least 10% and its `task-clock`
   by at least 15% (the collector's 17% share at 40 to 50% fewer bytes
   copied gives 7 to 8 points alone; the rest is the mutator's memory
   traffic, which the harness puts at a factor of two on the compiler's
   structures and the prototype must show on the compiler itself).
3. Nothing is slower by more than the noise on any program of
   `tests/perf` under any engine, except where a decision says so
   (a real-heavy program whose reals cross polymorphic positions on a
   dependent chain, D3 C, measured and quoted against the B build).
4. Architecturally: every hook of *The architecture* exists and is
   asserted by a test; the next roadmap's nursery is a change to
   `heap.c` and the barrier's body alone.

## The milestones

Every milestone is one commit, or a few, each with `make check` green;
where it touches `vm/` it also passes `make test-stress`, the sanitiser
build, `make test-windows` and `make test-portability`, and where it
changes the layout of a value, the heap or `vm/image.c` it is not done
until the portability suite passes (`AGENTS.md`). Where it moves a
budget, the commit quotes the old and the new. Every milestone measures
itself with M1's tools against the one before it, in cycles and in
`task-clock`, and adds its part to runtime.md and `ARCHITECTURE.md`.
Sizes are lines of C or SML, estimated; M1 to M3 are about 2,500 lines
and change no layout; M4 and M5 are the change, about 6,000; M6 to M8
about 2,000 and are planned again at the gate.

### M1. Measure in the tree (M, about 600)

* **What:** the census as a build of the VM (`make vm-census`, the
  `RUNE_CENSUS` hooks of *The experiments* under `#ifdef` in `vm/`),
  its options `--census-dir`, `--census-every`, and `census.txt`; the
  static census over an `.rbc`'s representations section as a mode of
  `runeisa` or a small C tool; `--stats` extended with bytes copied,
  the collector's time and the largest live size, in both VMs and
  native programs; `scripts/perf-cycles.sh` with `--events`,
  `--vm-opts`, `--gc`, compile-sigs and runedoc as programs, `--profile`
  with call graphs, and `--mlton-bench`; `tests/external/run-mlton-bench.sh`
  and `tests/perf/mlton-bench.txt` (the input size per program) so that
  MLton's 48 benchmark programs are a workload set Rune runs from
  `/home/ruud/reference` without copying them; a heap-size sweep as a
  mode of the script.
* **Why now:** every number of this roadmap was made with throwaway
  copies of these; the tree must be able to make them again, and every
  later milestone measures with them.
* **Done when:** the tools are committed, `make check` runs the census
  build on one small program and checks its `--count` against the
  stock VM's, and the tables of *The experiments* are reproduced from
  the tree within the noise.

### M2. The simulator and the harness in the tree (M, about 3,600, mostly written)

* **What:** `tools/heapsim/` (the trace-driven simulator, its size
  models `layouts.h`, the sweep and the report scripts) and
  `tests/layouts/` (the C harness: the interface, the layouts, the
  kernels, the checksum check and the measurement script), with a
  README each saying how the tables of *The experiments* were made;
  `make check-layouts` runs the checksum check; the simulator's
  validation against `--stats` is a test.
* **Why now:** M4's prototypes are compared with what the simulator
  predicted, and the next roadmap's collector is designed on the same
  traces.
* **Done when:** committed; the validation test passes; the tables are
  reproduced.

### M3. The layout behind an interface (L, about 1,900 changed)

* **What:** first, since `runeopt` stays (D11), the generator that
  makes its templates from the macro-assembler's operations (about 400
  lines of SML over `src/opt/x64.sml`), so that the third engine
  follows the layout without a copy by hand; then `vm/value.h` (*The
  architecture*): every tag test, every
  `mk_`, every box and unbox, every header field, `field_get` and
  `field_set`, the allocation fast path, `obj_size`, the scan and the
  forwarding of one object, the roots of a frame, the image's encoding
  of a value; `vm/prims.c`, `vm/runtime.c`, `vm/heap.c`, `vm/image.c`,
  `vm/loader.c`, the two loops' descriptions in `src/isa/stack.sml`
  and `regs.sml`, `vm/new/fastprim.h` and `vm/new/isa_regs.c`'s lint
  rewritten over it, today's layout as the implementation, with
  `emit.c:378` closed; `masm.c`'s operations named for the same things
  and `emit.c`, `compile.c` using no layout fact of their own (a
  `_Static_assert` per offset); `runeopt` retired (D11), or its
  templates generated from the C, as a milestone of its own before this
  one; `rbcimage.sml`'s arithmetic taken from the same source; the rules
  in `AGENTS.md` (a layout fact lives in `value.h` or `masm.c` and
  nowhere else).
* **Done when:** every suite passes on every VM and every tier;
  `--count` is unchanged on every program; the compiler's bootstrap is
  byte-identical; `make test-portability` and `make test-windows` pass;
  the layout lines of *Who depends on the layout* are counted again and
  are in two files.
* **Touches:** jit M11 (the same files; coordinate by landing M3 first
  or after, not during).
* **Done (2026-09-27):** as described, in one commit. The generator is
  a text backend of the JIT's portable assembler (`vm/new/jit/asm_text.c`)
  and `bin/runeopt-templates` (`templates.c`), which runs each of
  `masm.c`'s operations against it with markers for its parameters,
  fits the numbers that move with a parameter as linear expressions and
  writes `src/opt/x64_layout.sml`; `x64.sml` is written over those
  templates as `emit.c` is over `masm.c`, and `rbcimage.sml` takes its
  rounding and sizes from the same constants. `vm/value.h` holds the
  layout; `masm.c` asserts its numbers against it; `emit.c` and
  `compile.c` name no offset. One bug on the way: a tail call's argument
  moves written through a register's home instead of its slot, which the
  JIT oracle caught on the bootstrap at tier 2. The recount is under
  *Who depends on the layout*. `make check`, `test-portability` and
  `test-windows` green; every count unchanged.

### M4. Prototypes at full scale, and the gate (XL, about 2,950)

* **What:** two implementations of `value.h` and of `masm.c`'s
  operations, complete enough that every workload of *The workloads*
  runs on `vm/new` at every tier, on `runevm` and on `runeopt`'s
  code: (1) the tagged word of D1 B with D2 B's 63-bit integers and raw
  typed fields (the compiler emitting field kinds at allocating sites:
  a `TUPLE`, `CONN`, `CLOSURE` operand, the representations section
  extended; the descriptor in the header; reals raw where typed and
  Koka-encoded at polymorphic positions, D3 C, with the boxed form of
  D3 B behind the compile-time switch); (2) the same with headerless
  pairs (D4 C, decided for 64-bit: this prototype is its first build).
  On (1) the alternatives the owner asked to see are measured as
  variants: the boxed reals of D3 B and the 64-bit integers of D2 A
  (the two switches, kept), the 4-byte header with the layout table on
  the 32-bit build (D4 B and D, decided for that width: the variant is
  their first build), and maps for the interpreter's frames (D5 B).
  Objects counted identically, bytes as each layout's; the Basis suite
  passing on both; the budgets not moved (they are checked against
  each prototype's own numbers by hand). Measured with M1: cycles,
  `task-clock`, the collector's share, bytes, the heap-size sweep, on
  every workload, against `228b7b7` (since the rebase: against the
  branch at M3, the 16-byte layout on the same sources) and against the simulator's and the
  harness's predictions -- on `runevm-new` at its defaults first, with
  `perf record --jit-perf-map` and the counters (`r0203`, L1d and TLB
  misses) by compiled function, since that is where the layout's
  effect on the real code is read; the interpreter and `runeopt` beside
  it. The workloads include the property-testing roadmap's SplitMix64
  kernel (D2, noted on 2026-09-27), the case where 64-bit words cross
  slots, and since the rebase the `normal` profile of
  `examples/benchmarks` beside M1's runner (*After the rebase*); the
  suites both prototypes pass include `make test-lib`, `make test-laws`
  and `make bench-smoke`, whose count budgets are checked by hand as
  the others are.
* **For a lazy front end** (*A lazy front end*, added on 2026-09-28).
  No lazy program runs on Rune, so the harness and SML programs over
  suspensions stand in; about 450 lines of the milestone's total.
  - *The pointer codes.* Prototype (2) builds the assignment behind a
    compile-time switch: three headerless shapes, or two with code 11
    reserved for "headered, evaluated". The simulator gets `LV_PAIRS`
    limited to the codes built (`PAIRS3`: constructor tags 0 to 2;
    `PAIRS2`: 0 and 1), so that it predicts the layout built rather
    than the any-two-field bound. Bytes, bytes copied and cycles of
    both builds on every workload; the census's first-order price
    (0.093% of the bootstrap's bytes) is what they confirm or correct.
  - *The harness's lazy kernels.* `iface.h` gets a thunk, an
    indirection and the reserved code, and `kernels.c` three kernels:
    `lazy_case`, a `case` on a headered three-constructor datatype with
    0, 1, 10 and 50% of its scrutinees thunks, tested by a header load,
    by the reserved code, and by an indirect call as GHC's before 2007;
    `lazy_stream`, a sieve over a stream whose every tail is a thunk
    (the update path, the copier's short-circuit of indirections, the
    bytes indirections hold until the next collection); and
    `lazy_update_old`, old thunks updated with young values under
    `BARRIER_CARD` (the cards and remembered entries a lazy program
    makes). `check.sh` holds them to one checksum under every layout,
    as the others. The existing kernels under the reserved-code build
    must be within noise of the three-shape build: masking a code that
    is never set is all it costs SML.
  - *Lazy workloads for the collector's question.* Four of nofib's
    imaginary programs (`/home/ruud/reference/ghc/nofib/imaginary`:
    `primes`, `wheel-sieve1`, `digits-of-e1`, `exp3_8`) in SML over a
    structure of memoised suspensions (a ref to a thunk or a value),
    under `tests/perf/lazy`, censused and simulated as the other
    workloads. (Since the rebase three of the four are in the tree,
    with `digits-of-e2`, `queens` and `tak` beside them:
    `examples/benchmarks/*-lazy` over `shared/lazy.sml`, a ref to a
    pending thunk or a value, each but the two `digits-of-e` with a
    strict twin that is the control. M4 censuses those and ports
    nothing; `wheel-sieve1` joins when the benchmark roadmap imports
    it.) The census's stores by age class give the share of
    updates that point old to young, and the simulator's
    remembered-set model (the table of `sim-remset.md`) their cost. A
    suspension is two objects here where GHC's thunk is one, so the
    bytes are an upper bound; the update pattern is the measurement,
    and it goes into M7's brief.
* **The gate:** the owner confirms or changes D1 to D5 on these
  numbers, as they said they might (D3 and D4 changed already, on the census and the harness; D5 B), and decides D4 C's third pointer code (a
  headerless shape, or reserved for a lazy front end: *A lazy front
  end*). The roadmap
  is planned again from here: M5's content is the chosen layout.
* **Done when:** both prototypes pass the suites, the table is in this
  file with the lazy kernels' and workloads' rows, the decisions are
  recorded. The prototypes are branches (`heap-layout-word` the
  first), not commits to `heap-layout`; the winner becomes M5.
* **Touches:** the compiler (field kinds), the FFI (the convention of a
  value into C appears in `masm.c`'s call operation).

### M5. The chosen layout, complete (XL, about 3,000)

Planned again at the gate (2026-10-04). The size is the first plan's:
the pairs and the 32-bit header are gone from it and the 64-bit types
have come in.

* **What:** prototype 1 finished (branch `heap-layout-word`, its work
  brought to `heap-layout`) as the gate left it: the tagged 8-byte
  word on every machine, 63-bit integers and words, reals by the
  rotation, the 8-byte header, no headerless pairs, no raw typed
  fields. In this order:
  1. *`Int64` and `Word64` as types of their own* (D2 B), first
     because it is the least proven part: the prototype has the
     mechanism (tier 2's homes holding the 64 bits, `RUNE_RAW_HOMES`)
     and not the types. A representation of their own in the compiler
     (`Rep`) and in the bytecode's representations section, so that
     their registers alone get raw homes; their primitives; a box
     where one reaches a value; `Int.precision` 63 and `Word.wordSize`
     63 on every machine, and what `LargeInt`, `LargeWord`, `SysWord`
     and `Position` are aliases of; the Basis' list of M4 (on the
     63-bit build seven programs do not load and 34 checks fail);
     `lib/random`'s SplitMix64 and `make test-lib` as the test, since
     the 63-bit prototype prints another answer there. D2 A, 64 bits
     kept with the aliases, stays behind its switch.
  2. *The reals* (D3 C): the rotation as the one encoding (Koka's
     stays on the prototype's branch for comparison; D3 B, every real
     boxed, behind its switch); a box that the VM keeps for each of
     `+0.0`, `-0.0`, the two infinities and NaN, made at start so
     that every engine has the same heap, and roots; the interpreter's
     fast path handed the VM, so that a zero result does not leave
     it; a real constant decoded as the code is made (built).
  3. *Every consumer:* every primitive, both loops, every emitter,
     `runeopt`'s templates regenerated, the image format bumped once
     (D10), `rbcVersion` bumped once (the representations section
     changes), Windows, the 32-bit and PowerPC VMs on the same word
     (D13 A at the gate: bytes, objects and images equal across
     widths, as the portability suite checks today), the Basis where a
     representation shows (`runtime_sig.sml`'s sentence; `IntInf`'s
     limbs if a raw word helps them; `Real32` untouched), every budget
     re-based in one commit that quotes old and new (those of
     `tests/perf` and `examples/benchmarks/count-budgets.tsv`),
     `tests/basis/runtime.sml`'s 40 and 24 replaced by the new sizes,
     `masm_test.c`, the docs (runtime.md's *Values and objects*,
     bytecode.md, native.md, `ARCHITECTURE.md`, `share/man/runevm.1`,
     the examples), and the small items D4 notes if cheap (a nullary
     exception immediate).
  4. *What is kept open:* bits 1 and 2 of a pointer are zero and
     unused, for the pairs' two codes and a lazy front end's
     "evaluated", asserted where a pointer is made; nothing masks
     them, since nothing sets them, and the mask comes with whichever
     uses a code first. The kinds `K_THUNK` and `K_IND` reserved and
     asserted, unused by SML. The header's byte for a raw-field
     descriptor kept free (D1's second half, undecided).
* **Not in M5**, by the gate: headerless pairs (branch
  `heap-layout-pairs`; to take up again when M7's growth policy can
  turn the fifth less they keep into resident memory, or with a lazy
  front end); raw typed fields; the 32-bit VMs' own word, the 4-byte
  header and the layout table (`32-bit-vm.md`); maps for the
  interpreter's frames (D5 B).
* **Done when:** every suite green on every VM at every tier, with
  `--gc-stress 1` and the sanitiser, `make test-lib`, `make
  test-laws` as far as it holds on the 16-byte layout and `make
  bench-smoke` among them; `make test-portability` carries an image of
  the new layout between every pair of VMs; D15's targets 1 and 3 met
  and target 2 measured; the perf tables of *The experiments* re-made
  with the new layout beside the old, the eight programs of reals and
  MLton's set among them, and on those the question the gate left
  open put to the owner: raw real fields or not.
* **Touches:** everything of *Who depends on the layout*; the
  incremental roadmap (the image and the `.rbc` version), the FFI (the
  convention).

### M6. Roots and maps (M, about 500)

* **What:** the roots of a frame precise by liveness where it is cheap:
  unit written into a dead pointer slot at the safepoints tier 2
  already has (jit M9's unbuilt item), the `RUNE-DEV` deviation of
  `Runtime.collect` retired if that makes the roots exact; the root
  list in one place (`heap.c` and `heap_relocate` share it), the
  boxes the VM keeps for the reals among them (M5); jit M11's maps
  consumed through one interface. The gate confirmed D5 A, so no maps
  per pc for the interpreter's frames are built here.
* **Done when:** `rt.*` tests of roots pass at every tier;
  `--gc-stress 1` green.

### M7. The collector on the new layout, and the hooks for the next (L, about 800)

* **What:** `heap.c` rewritten without file-static state (the
  collector's state in a struct the VM owns; per-thread allocation
  state in name); the header bits of D4 asserted (`_Static_assert` on
  their positions; a test that the copier preserves them); young and
  old told apart by address (the semispaces in one reserved range, or a
  range test that a nursery will reuse); `field_set`'s barrier as a
  no-op operation in C and in `masm.c`, with a build flag that makes it
  a card mark so that its cost is measured now, and the same hook on
  the update of an object in place, a header rewritten with its first
  field (a thunk's update to an indirection, *A lazy front end*), with
  the scan of `K_IND` reading that field alone; the large-object space
  if D6 chose it; the semispace's growth measured and chosen, since
  doubling is what holds the compiler at 128 MB whether a collection
  keeps 45 MB or 36 (M4's peak memory), and a finer step is what
  would let a smaller layout show in resident memory; `--stats` and
  `Runtime.stats` with the fields the
  next collector reports; the census hooks kept working; and the brief
  of the generational roadmap written from the simulator's tables
  (nursery size, survival, remembered set, what a sticky-bit old space
  would save) as `docs/plans/collector.md`, with the lazy workloads of
  M4 beside the strict ones.
* **Done when:** the copier's behaviour is unchanged on every test
  (collections, live, `--stats` equal); the barrier flag's cost is in
  this file; the brief exists.
* **Touches:** the multithreading roadmap (the state), the FFI (the
  pin bit).

### M8. Flat arrays, strings and the FFI's objects (M, about 700)

* **What:** `Word8Array`, `CharArray` and `Word8Vector`, `CharVector`
  at one byte per element with C's layout behind the header
  (basis.md's `_primtype "bytearray"`, `array_blit`); `RealArray` and
  `Real64Array` flat, the elements the double's own bits (and here,
  if the owner chose them after M5, raw real fields in tuples and
  records, with the header's descriptor: D1's second half); `WideString` at four bytes per character or as
  today by measure; the pin bit of D9 honoured (an object pinned is not
  moved: in the large-object space if D6 built it, else copied around
  the call); a handle table for values C holds, as a root
  (`Runtime` gets the primitives; the FFI roadmap gets the syntax); the
  compact kinds in images, `values_equal`, the census.
* **Done when:** the Basis suite passes with the new kinds; a test
  passes a byte array to a C function of the runtime through the
  handle table and back across a collection; budgets moved and quoted.
* **Touches:** the FFI roadmap (critical: this is where its objects
  are), incremental compilation (nothing), the collectors (the pin bit).

### Why this order

* **Measure, then make the tools permanent.** M1 and M2 cost nothing in
  layout and make every later number reproducible.
* **The interface before any layout.** M3 is the owner's "hard work
  upfront": once every consumer speaks `value.h`'s language, a layout
  is an implementation and the second change is a milestone, not a
  roadmap. It is also what makes M4's two prototypes affordable.
* **Prototypes before commitment.** The brief asks for hard evidence;
  the simulator and the harness give bytes and kernel cycles, and only
  the real VM on the real workloads gives the rest. The gate is where
  the owner decides with both in hand.
* **The layout complete before the collector moves.** M5 is the largest
  change the runtime has had; M7 changes the collector's code without
  changing what it does, so that the next roadmap starts from a
  measured, stable copier on the new layout.
* **Inside M5, the 64-bit types first** (the gate): they are the one
  part of the chosen layout that no prototype ran, so they are built
  while changing course is still cheap.
* **The FFI's objects last**, because they are the first thing the FFI
  roadmap needs and the last thing this one can measure.

## Prerequisites and flags

The brief asks what of the other plans must be taken into account.
Nothing of them must come first; what this roadmap needs from them, and
they from it:

* **jit.md** (finished 2026-09-27, PR #21). D10 left item 19 undecided;
  this roadmap decides it (D1). M11's maps arrive through M3's
  interface and are unchanged by M5, since tier 2 writes tagged words
  back at safepoints under D5 A as it does today. M12's aarch64
  allocation path and transition into C exist and change with the
  layout in M5, as x86-64's do, through the portable assembler's
  operations. `ms_trusts` (M10) reads the header and is rewritten in M3
  over the operations and in M5 for the new header.
  The JIT's homes are unchanged: a raw int or real in a machine
  register, written back as the layout's word.
* **Incremental compilation** (after jit). Its images and `.rbu` units
  carry values and closures: M5's image version is what it builds on,
  and the 32-bit build's layout table (D4 D) must grow per unit as
  `rt_load` appends. Its resident compiler keeps a large basis live
  (its D9): the copier re-copies it at every collection until the next
  roadmap's old space; M7's brief says by how much. Its REPL printer
  (its D10) stays tag-directed under D12.
* **The FFI** (no roadmap). Critical at M5 (the convention of a value
  into C: a tagged word or a raw value in a register, fixed by
  `masm.c`'s call operation) and at M8 (byte arrays with C's layout,
  the pin bit, the handle table). The FFI roadmap should be drafted
  after M8 with those in hand; callbacks from C stay jit.md's open
  question and nothing here decides it.
* **Multithreading and high core counts** (no roadmap). Critical at M7:
  per-thread allocation state, no collector globals, the header's
  colour and remembered bits, mutable objects known by kind, young and
  old by address. The roadmap for it chooses between per-thread young
  heaps with a shared old space and per-process heaps; this one closes
  neither (D8).
* **The collectors** (the next roadmap). D7: after M7, from
  `docs/plans/collector.md` written there with the simulator's tables.
  What this roadmap gives it: the barrier operation, the header bits,
  the address ranges, the large-object space, the census and the
  simulator on the new layout. What it withholds: a nursery, a
  remembered set, a non-moving space.
* **Delimited continuations and green threads.** Frames stay the VM's
  and slots stay self-describing (D5 A), so a captured stack segment is
  copied as data with no map, which is the simplest case for both.
* **A lazy front end** (a Haskell 98 front end, perhaps with a bytecode
  of its own). Walked through in *A lazy front end* below (2026-09-28):
  the layout fits it without 16-byte alignment, given one choice at
  M4's gate (the third pointer code of D4 C), two kinds reserved in M5
  and the update as an operation of M7's barrier; M4 measures what the
  choice rests on.
* **Web-native** (wasm32). D13: the machine's 4-byte word there, as on
  the i386 VM, with 32-bit integers; a host-managed heap (WasmGC) would
  be another layout behind the same interface.
* **Whole-program optimisation.** MLton-class flattening and
  monomorphisation would feed D1 C; D1 B's typed fields are the first
  step of it and the interface takes the rest.
* **Formal verification, error messages, the IDE.** The IDE's heap
  inspection (ide.md) and the owner's "heap walking (space leaks)" want
  a traversal the collector exposes: M1's census hooks are that
  traversal's first form.

## A lazy front end

The owner's notes ask for it -- "we may want to add a Haskell 98
front-end later or support high-performance lazy evaluation in Rune in
the future. The roadmap should get us ready for that"
(`~/notes/virtual-machine.md`) -- and on 2026-09-28 the owner asked
whether this layout is compatible with Haskell 98, possibly under a
bytecode made for lazy languages. It is, with one choice for M4's gate
and two reservations, for M5 and M7; M4 measures what the choice rests
on. The earlier note here said a lazy front end would need 16-byte
alignment or tags of its own; walked through, it needs neither.

**What a lazy language asks of a layout.** GHC's runtime is the model
(`rts/include/rts/storage/ClosureTypes.h` in `/home/ruud/reference/ghc`):
* a *thunk*: an object that holds a suspended computation and is
  overwritten when forced;
* an *indirection* (`IND`): what a forced thunk becomes, a pointer to
  its value. The copier short-circuits it, so that no one pays for it
  after the next collection (`rts/sm/Evac.c:978-982`);
* a cheap way for a `case` to tell an evaluated value from a thunk.
  GHC puts it in the pointer's low bits (Marlow, Yakushev and Peyton
  Jones 2007: 14% for 2% more code);
* a *blackhole*: a thunk under evaluation, so that a loop is detected
  and, with threads, a second thread waits instead of evaluating twice;
* the *selector thunk*: `fst p` unevaluated, which the collector
  evaluates once `p` is, so that a pair's dead half is not kept alive
  (Wadler 1987; `eval_thunk_selector`, `Evac.c:974-976`);
* the partial application, which Rune's closures already are.

**What the decided layout already gives it:**
* **The word (D1 B).** A lazy field of type `Int`, `Char` or `Double`
  holds either the evaluated value, immediate, or a pointer to a thunk,
  and the low bit tells them apart: forcing it is a bit test with no
  load. GHC boxes these at every lazy position (`I# n`, `D# d`); here
  they are boxed only where D3 C's encoding runs out.
* **63-bit `Int` (D2 B).** The Haskell 98 Report asks less: "The
  finite-precision integer type `Int` covers at least the range
  [-2^29, 2^29 - 1]", and overflow is undefined ("an implementation
  may choose error (⊥, semantically), a truncated value, or a special
  value", section 6.4). SML's `Overflow` and a wrap both conform, and
  the 32-bit VMs' 31 bits (D13 B) are above the Report's 30. `Integer`
  is `IntInf`, its small values immediate.
* **Raw typed fields (D1 B).** Haskell 98's strict fields
  (`data T = T !Int !Double`) are the positions a thunk can never
  occupy, and so the ones a raw field may take; a lazy field stays a
  word. D4 A's descriptor says which, as for SML.
* **Self-describing slots (D5 A).** The frame that updates a thunk when
  its value returns (GHC's update frame) is a VM frame like any other.
  A lazy program's deep stacks (a `foldl` chain) are scanned with no
  map, where GHC's stack is a heap object with info-table bitmaps.
* **The minimum object (D6).** A header and one word, so every thunk,
  however small, can be overwritten in place by an indirection. A
  thunk's first field is its function index, as a closure's is
  (`K_CLOSURE`), and becomes the indirection's target.
* **Headerless pairs (D4 C).** A thunk needs its header, so a headerless
  object is never a thunk: its pointer's code already says "evaluated,
  and this constructor", and a `case` on a list or a tuple gets pointer
  tagging's gain without a load. Lists and tuples are the commonest
  lazy data as they are the commonest strict data (`String` is
  `[Char]`: 16 bytes a character here, 24 in GHC).

**The one choice: the third pointer code.** With 8-byte alignment the
two bits beside the immediate bit give three non-zero codes, and D4 C
spends them on headerless shapes. What a lazy front end wants from them
is one code that means "a headered object, known to be evaluated" (a
`Just x`, a tree's node, a record). A pointer without it may be a
thunk, and a `case` loads the header to find out. Two ways:
* **Reserve code 11 for it.** Strict code never sets it: `val_ptr`
  masks the two bits under D4 C anyway, and the collector, equality,
  printing and images read 11 as 00, a headered object. The copier
  keeps a pointer's code as it copies, and when it short-circuits an
  indirection it writes the target's, so a thunk's referrers learn the
  value is evaluated at the next collection, as in GHC's (`Evac.c`:
  the tag kept at 698-699 and 274-309, the indirectee taken at
  978-982). What SML gives up is a third headerless shape. The census
  prices it, first
  order, from each `census.txt`'s (kind, contag, len) table, with the
  pointer carrying the constructor tag (codes for tags 0, 1 and 2, a
  tuple sharing tag 0's). The objects that take a header under two
  codes and not under three are, as a share of the bytes under
  L1+PAIRS:

  | workload | two codes' cost |
  |---|---|
  | bootstrap | 0.093% |
  | compile-sigs | 0.146% |
  | compile-hello | 0.063% |
  | runedoc-ir, runedoc-page | 0.028%, 0.015% |
  | every MLton program traced | 0 |

  Made by `results/pointer-codes.py` in the drafts directory (its table
  in `results/pointer-codes.md`), over the top 300 shapes of each
  table: those hold all but 0.73% of the bootstrap's bytes (all but
  4.4% of `runedoc-page`'s), so the costs are exact to that.
  **Recommended**, for the gate.
* **Spend it on a third shape**, and a lazy front end loads the header
  on a `case` of a headered type. What that costs is the load and a
  compare, not the indirect jump into the closure that GHC made before
  2007, whose mispredictions were "much of" the 14%. It is unmeasured;
  M4's harness measures it.

A side finding for D4 C itself. The simulator's `LV_PAIRS`
(`vm/layouts.h:31, 81`) makes every two-field constructor headerless
whatever its tag, which three codes cannot do: 5.3% of the bootstrap's
two-field objects have a constructor tag above 2 and keep a header
under any assignment, 0.94% of its bytes under L1+PAIRS (0.97% of
compile-sigs'). The 0.502 of *The experiments* is an upper bound by
about that much; M4 re-makes it for the codes the prototype builds.

On 32-bit machines (D4 B and D) there are no headerless pairs, and
4-byte alignment leaves one bit beside the immediate bit (D4): that bit
can be the evaluated code there, with nothing competing for it.

**Two reservations:**
* **Kinds (M5).** D4 A's kind is four bits. With `K_REAL` and `K_BOX`
  the prototype uses 11 of the 15 non-zero values (`vm/value.h`'s
  `enum ObjKind`), and M8's compact kinds may take more. M5 reserves
  two, `K_THUNK` and `K_IND`, asserted and unused by SML. A blackhole
  and a selector thunk are states of `K_THUNK` in the constructor-tag
  field (a blackhole is one header write; a selector's field number is
  its tag), and a partial application is a `K_CLOSURE`; GHC's 66
  closure types are its info tables' business, not a header's. `K_IND`
  is not `K_FORWARD`: the mutator follows one, the collector alone the
  other.
* **The update is an operation of the interface (M7).** Forcing a thunk
  writes its header (to `K_IND`) and its first field (the value), in an
  object that may be old: a store, and under the next roadmap's
  collector the commonest old-to-young store of a lazy program (Sansom
  and Peyton Jones 1993, *What the literature says*). `field_set`
  covers a field, not a header, so M7's barrier hook covers a header
  rewritten with its field, as one operation in C and in `masm.c`. The
  scan of a `K_IND` reads its first field alone: the thunk's other
  fields are dead free variables, and scanning them is a space leak.
  An image writes the target, not the indirection (D10).

**What it asks of the next roadmap.** A lazy program's old objects
point to young ones through updates, so its remembered set, not its
survival, is the cost, and *Variants*' mutable objects segregated
(Poly/ML's answer) stops being an answer when most of what is
allocated is a thunk that will be written once. The generational
roadmap's brief (M7) states the lazy case beside the strict one, from
M4's lazy workloads. With threads (D8), two threads may force one
thunk; GHC lets them race and tolerates the duplicate evaluation (lazy
blackholing), and a compare-and-swap of the header (8 bytes, or 4 on
32-bit machines) serves either answer.

**The bytecode.** The layout sits under the bytecode. A lazy front end
may bring instructions of its own -- thunk, force and update in the
same description, as jit.md's *Prerequisites and flags* sketches them,
or a loop of its own -- as long as it is one more reader of `value.h`
and of `masm.c`'s operations, which is what M3's interface is for; D13's
one bytecode is one across widths, not one for every front end. Sharing
the layout is what lets Haskell and SML code share a heap and call each
other. What a new loop must keep is D5 A (its frames the VM's, its
slots self-describing) and *Constraints* (`--count`, the images, one
output from every build).

## Relation to the other plans

| Elsewhere | Here |
|---|---|
| performance.md item 19 (8-byte values, "half the heap and half the collector's work") | D1, D2, D3; the numbers of *The experiments* |
| performance.md item 13 (generational collector) | D7; M7's hooks and brief; the next roadmap |
| real-encoding.md (2026-10-04: the experiments left on how a real sits in the word) | D3 at the gate; M5's second step; raw real fields, undecided until after M5 |
| 32-bit-vm.md (2026-10-04: the experiments that would decide a 32-bit VM's own word) | D13 A for M5 at the gate; D13 B, D4 B and D, not prototyped |
| docs/performance.md, *Why `vm/new` at `opt` is slower than MLton* (2026-10-02): the 16-byte tagged Value written at every result, the 16-byte array cell | D1, D3, M8; D15's targets on the same programs (*After the rebase*) |
| benchmarks.md (`examples/benchmarks`, 149 programs with result checks; `make bench-smoke` and its count budgets) | a workload set for M4 beside M1's runner; its lazy variants are M4's lazy workloads; its budgets move at M5 |
| quickcheck.md (`lib/random`, `lib/test/property`; `make test-lib`, `make test-laws`) | D2's note: `Word64` code that every prototype passes and M4 measures |
| performance.md items 10, 16 (done) and its measured-and-dropped (huge pages, fill 25%) | *Where we are*; the sweep of *The experiments* |
| jit.md D10 (16-byte value kept; item 19 before M9) | decided here (D1); M9 built on the 16-byte value, unchanged in what it does |
| jit.md D11 (`runeopt` and images) | D11 here: `runeopt` decided before M3 |
| jit.md D14 (collector after M7) | held; M7 here is the collector's code, not its algorithm |
| jit.md M10 item 6 (block allocation, measured and not built) | the bump path of D6; unchanged |
| jit.md M11 (maps at tier-2 safepoints) | consumed through M3's interface; D5 |
| jit.md *Prerequisites and flags* (the FFI critical at M4/M5 and M9; green threads; a lazy front end) | D9, M8; D8; *A lazy front end*, D4 C, M4, M5, M7 |
| the owner's `virtual-machine.md`: "a Haskell 98 front-end later or ... high-performance lazy evaluation", "the roadmap should get us ready for that" | *A lazy front end*; M4's lazy kernels and workloads; the third pointer code at the gate |
| middle-end.md D12 (int precision per target; "a `vm/new` with 8-byte values might have 63-bit ints") | D2: 64 bits kept, per target still |
| middle-end.md M11 (`Rep`, CONN/FIELD, `imm_eq`) | kept; the constructor's tag in the header (D4 A) and, for the pair, in the pointer (D4 C) |
| middle-end.md *Ready for, not built* (other collectors; `Alloc`, `Store`, `Safepoint`; stack maps from liveness; escape analysis and regions) | `Store` is `field_set`; maps in D5 B; escape analysis is the owner's note and nothing here precludes it |
| incremental-compilation.md D9, D10, D17 (the resident basis; printing by tag; the ABI across units) | M7's brief; D12; the constructor layouts of D4 are per datatype as `Rep` fixes them |
| codegen.md *To revisit* (D3 A, D11) and *Keeping it in step* | D11 here; the templates' copy of the layout ends in M3 |
| basis.md, the compact byte array (M3 there, undone) | M8 |
| weak-points.md items 2, 6, 7, 8 | D7, D8/D9, M3, D13 |
| the owner's notes: "always 64-bit even on 32-bit platforms" (the architecture as it is; a native word per machine welcome if free, 2026-09-27); the end state of `virtual-machine.md` | D2, D13; D8, *The architecture* |

## Risks

1. **The prototypes flatter or belie the kernels.** The harness runs
   the compiler's data structures, not the compiler; the simulator
   counts bytes, not cache misses. M4 runs the real workloads before
   anything is committed, and the gate compares the three.
2. **M5 is very large and the suites are slow.** About 3,000 lines
   across 20 files, five VMs and every tier. M3's interface is the
   mitigation: after it the change is local to two files and the
   prototypes of M4 are most of M5. Split M5 into green commits by
   kind (immediates, then tuples and constructors, then closures, then
   strings and arrays) if the interface allows it.
3. **The budgets and the portability suite move together.** Every
   `.budget` and every count equality changes in one commit, and the
   32-bit and PowerPC VMs must agree to the byte on the new layout the
   same day. The re-basing script of M5 is written before the layout
   is, on the prototype.
4. **A 63-bit decision the language feels** (D2 B, taken).
   `Int.precision`, `Word.wordSize`, every hash, the programs that
   assume 64 bits and the Basis suite's expectations change, and
   `Int64`/`Word64` become their own types; the MLton regression corpus
   (`tests/external`) and the Basis suite on every host are the
   instruments that find what else does, in M4 before anything is
   committed.
5. **The JIT's emitters drift from the C.** M3's `_Static_assert`s,
   the `--count` oracle at every tier, `--gc-stress 1` and the
   sanitiser under `make check`, and the rule in `AGENTS.md` that a
   layout fact lives in two named files.
6. **`runeopt` kept** (D11): a third engine to move. Its templates are
   generated from the macro-assembler's operations as M3's first item,
   so that it cannot drift; M5 grows by its 141 layout lines' worth,
   and `make test-native` holds it to `--count` as today.
7. **Windows and the 32-bit VMs.** A 4-byte tagged word with 32-bit
   integers (D13 B) is a second width of the layout, and a compiler
   that folds constants for the narrowest width; the portability suite
   (instructions and objects equal across widths, bytes within one),
   the Windows suite with `JOBS=8` and the Basis suite's per-width
   expectations are the gates, and M4's prototypes run them before the
   gate.
8. **The simulator's approximations mislead the coupling answer.** It
   models no locality, no mutator cost and no fragmentation, and its
   liveness is a band. D7 is decided on bytes copied, which it gets
   right to the band; the mutator's side is the harness's and M4's.
9. **Other sessions commit on the branch.** `git log` before every
   commit, as the repository's rules say; M3 and jit M11 touch the
   same files, so one lands before the other starts.
10. **The reference disk is slow and the fast one is small.** Raw
    traces live on the fast disk only while simulated; the archive is
    `/mnt/h/HEAPSIM`; the tools of M1 write `census.txt` alone by
    default.
11. **A lazy front end outgrows what is reserved for it.** Two kinds,
    one pointer code and an update with a barrier are what *A lazy
    front end* found necessary; GHC has 66 closure types. What a front
    end needs beyond them goes in `K_THUNK`'s constructor-tag field or
    its function's metadata, not the kind. M4's lazy kernels check that
    the common paths (a `case`, a force, an update) need nothing more,
    and nofib's programs in SML over suspensions are a proxy for a lazy
    program, not one: they double the objects of a thunk.
12. **Master moves under the branch.** The rebase of 2026-10-03 took 66
    commits. One of them rewrote `values_equal` by tag and `OBJ_FIELDS`,
    which compiles under today's layout whether or not it goes through
    `value.h`; another made the reference program a third larger. Until
    M1 to M3 are on master, code written there knows nothing of the
    interface, and a prototype's branch meets it at the next rebase.
    After every rebase the recount of *Who depends on the layout* is
    run again (it is how that function was found, beside the conflict),
    the census of the bootstrap is made again, and M1 to M3, which
    change no layout, are worth merging before M4's gate, not after.

## Testing a layout change

* **The oracle** is `--count`: objects equal to the old layout's on
  every program (plus the boxes a layout adds, counted), bytes equal
  across engines, tiers and widths, on `tests/lang`, `tests/perf`, the
  Basis suite, `tests/external`, the corpus and the bootstrap's fixed
  point.
* **Every kind,** in a program that makes and reads every kind of
  object and every immediate at every representation, run under every
  engine and tier, with `--gc-stress 1` and the sanitiser build
  (`tests/lang/rt.every_kind`, M3).
* **Images** of the new layout carried between every pair of VMs by
  `make test-portability`, and restored into every tier.
* **The collector's invariants:** header bits preserved across a copy,
  a pinned object not moved, the barrier flag's card marks counted
  (M7's tests).
* **The Basis suite on every VM** (137,276 checks), the MLton
  regression corpus and the benchmark set as the language-level
  instrument; since the rebase also the libraries' suites and laws
  (`make test-lib`, `make test-laws`) and the benchmark catalogue's
  result checks (`make bench-smoke`).
* **Rules for `AGENTS.md`** (M3): a fact of the layout lives in
  `vm/value.h` or `vm/new/jit/masm.c` and nowhere else; an emitter
  takes an offset by `offsetof` and asserts it; a primitive that stores
  into an object uses `field_set`; a change to `value.h` runs the
  census build's check and the portability suite.

## Measuring

* **The target configuration** is `runevm-new` at its default settings
  (`rune:new`; tier 2 by the counters since jit M10), the fastest way to
  run Rune today and the default to come, as the owner said on
  2026-09-27, and the default since `6618017`. Every table leads with it and every target is stated for
  it; `runevm` and `runeopt`'s native code are measured beside it, for
  the portable VM's and the ahead-of-time compiler's sake.
* **Cycles and time:** `perf stat -e cycles:u,instructions:u,task-clock,
  page-faults`, the least of five runs, on the bootstrap, the programs
  of `tests/perf` at their default input, compile-sigs and runedoc, and
  the MLton benchmark set at the sizes of `tests/perf/mlton-bench.txt`;
  `task-clock` and page faults beside cycles for anything touching
  memory (codegen M12's lesson); same-binary runs differ up to 3%, a
  relink up to 13%, so a change under that is not a change.
* **The collector's share:** `perf record` by symbol with `memcpy`
  attributed to `copy_obj`, grouped as *The experiments* groups it;
  `--stats`'s bytes copied and collector time.
* **Bytes and objects:** `--count`; the census build's `census.txt`
  by kind, site and field; the simulator's tables per layout.
* **The heap-size sweep** at multiples of the largest live size, as
  DaCapo's method, so that a change is compared at equal memory.
* **The harness** for a layout's mutator cost on the compiler's data
  structures, both compilers, ratios to today.
* **The scripts of M1 and M2** are how every milestone's table is made;
  *The experiments* says how this roadmap's were. M1 put them in the
  tree: `make vm-census` builds the census VM (`docs/census.md`:
  `--census-dir`, `--census-every`, `--census-summary`,
  `--census-static`), `scripts/census.sh WORKLOAD...` runs a workload on
  the stock and the census VM and keeps the traces under
  `tests/out/census`, `scripts/check-census.sh` is its check in `make
  check`; `--stats` prints bytes copied, the largest live size and the
  collector's time; `scripts/perf-cycles.sh` takes `--events`,
  `--vm-opts`, `--gc` (the collector's table), `--profile CONFIG[:PROGRAM]`
  (by symbol, then by group through `scripts/perf-groups.awk`),
  `--mlton-bench DIR NFILE` and `--sweep` (the heap-size sweep), with
  compile-sigs and runedoc-page as programs;
  `tests/external/run-mlton-bench.sh` runs MLton's benchmarks from
  `/home/ruud/reference` at the sizes of `tests/perf/mlton-bench.txt`
  and checks their counts (the benchmark roadmap's
  `scripts/measure-benchmarks.sh` times the catalogue of
  `examples/benchmarks`, with result checks, since the rebase). M2 put the simulator in `tools/heapsim`
  (`bin/heapsim`, `bin/heapsim-gen`; `test.sh`, `validate.sh`, `sweep.sh`,
  `report.py`; `make check-heapsim` in `make check`) and the harness in
  `tests/layouts` (`make -C tests/layouts`, `check.sh`, `measure.sh`,
  `micro.sh`, `tables.py`; `make check-layouts` in `make check`), each
  with a README saying how the tables of *The experiments* are made.

## References

The sources were read on 2026-09-26, and every DOI was checked against
Crossref's record that day; technical reports, blogs and engine pages
give their URL. Where a source could not be read beyond its abstract,
*What the literature says* quotes only what the abstract states.

**Tagging and unboxing** (*What the literature says*, D1 to D4):
* Steele. "Data representations in PDP-10 MacLISP." MIT AI Memo 420, 1977. https://dspace.mit.edu/handle/1721.1/6278
* Gudeman. "Representing type information in dynamically typed languages." University of Arizona TR 93-27, 1993. https://cs.arizona.edu/sites/default/files/TR93-27.pdf
* Leroy. "Unboxed objects and polymorphic typing." POPL 1992. doi:10.1145/143165.143205
* Peyton Jones and Launchbury. "Unboxed values as first class citizens in a non-strict functional language." FPCA 1991. doi:10.1007/3540543961_30
* Shao and Appel. "A type-based compiler for Standard ML." PLDI 1995. doi:10.1145/207110.207123
* Harper and Morrisett. "Compiling polymorphism using intensional type analysis." POPL 1995. doi:10.1145/199448.199475
* Tarditi, Morrisett, Cheng, Stone, Harper and Lee. "TIL: a type-directed optimizing compiler for ML." PLDI 1996. doi:10.1145/231379.231414
* Marlow, Yakushev and Peyton Jones. "Faster laziness using dynamic pointer tagging." ICFP 2007. doi:10.1145/1291151.1291194
* Appel. "Runtime tags aren't necessary." Lisp and Symbolic Computation 2(2), 1989. doi:10.1007/bf01811537
* Goldberg. "Tag-free garbage collection for strongly typed programming languages." PLDI 1991. doi:10.1145/113445.113460
* Tolmach. "Tag-free garbage collection using explicit type parameters." LFP 1994. doi:10.1145/182409.182411
* Weeks. "Whole-program compilation in MLton." ML Workshop 2006. doi:10.1145/1159876.1159877; slides http://mlton.org/References.attachments/060916-mlton.pdf
* Dybvig, Eby and Bruggeman. "Don't stop the BIBOP: flexible and efficient storage management for dynamically-typed languages." Indiana University TR 400, 1994. https://legacy.cs.indiana.edu/ftp/techreports/TR400.pdf
* Shao and Appel. "Space-efficient closure representations." LFP 1994. doi:10.1145/182409.156783
* Appel and Shao. "Empirical and analytic study of stack versus heap cost for languages with closures." Journal of Functional Programming 6(1), 1996. doi:10.1017/s095679680000157x
* Kennedy and Syme. "Design and implementation of generics for the .NET Common Language Runtime." PLDI 2001. doi:10.1145/378795.378797
* Melançon, Serrano and Feeley. "Float self-tagging." Proceedings of the ACM on Programming Languages 9 (OOPSLA2), 2025. doi:10.1145/3763108 (checked against Crossref on 2026-10-04; its abstract only; *M4, what was measured for the gate*)

**Roots and maps** (D5, M6):
* Diwan, Moss and Hudson. "Compiler support for garbage collection in a statically typed language." PLDI 1992. doi:10.1145/143095.143140
* Agesen, Detlefs and Moss. "Garbage collection and local variable type-precision and liveness in Java virtual machines." PLDI 1998. doi:10.1145/277650.277738
* Boehm. "Space efficient conservative garbage collection." PLDI 1993. doi:10.1145/155090.155109
* Boehm and Weiser. "Garbage collection in an uncooperative environment." Software: Practice and Experience 18(9), 1988. doi:10.1002/spe.4380180902

**Collectors** (D7, D8, M7):
* Cheney. "A nonrecursive list compacting algorithm." Communications of the ACM 13(11), 1970. doi:10.1145/362790.362798
* Ungar. "Generation scavenging: a non-disruptive high performance storage reclamation algorithm." ACM SIGSOFT/SIGPLAN Software Engineering Symposium on Practical Software Development Environments, 1984. doi:10.1145/800020.808261
* Appel. "Simple generational garbage collection and fast allocation." Software: Practice and Experience 19(2), 1989. doi:10.1002/spe.4380190206
* Reppy. "A high-performance garbage collector for Standard ML." AT&T Bell Laboratories technical memorandum, 1993. https://people.cs.uchicago.edu/~jhr/papers/1993/tm-gc.pdf
* Sansom and Peyton Jones. "Generational garbage collection for Haskell." FPCA 1993. doi:10.1145/165180.165195
* Blackburn and McKinley. "Immix: a mark-region garbage collector with space efficiency, fast collection, and mutator performance." PLDI 2008. doi:10.1145/1375581.1375586
* Shahriyar, Blackburn, Yang and McKinley. "Taking off the gloves with reference counting Immix." OOPSLA 2013. doi:10.1145/2509136.2509527
* Blackburn, Jones, McKinley and Moss. "Beltway: getting around garbage collection gridlock." PLDI 2002. doi:10.1145/512529.512548
* Blackburn, Cheng and McKinley. "Myths and realities: the performance impact of garbage collection." SIGMETRICS 2004. doi:10.1145/1005686.1005693
* Hertz and Berger. "Quantifying the performance of garbage collection vs. explicit memory management." OOPSLA 2005. doi:10.1145/1094811.1094836
* Jones, Hosking and Moss. "The Garbage Collection Handbook: The Art of Automatic Memory Management." 2nd edition, Chapman and Hall/CRC, 2023. doi:10.1201/9781003276142
* Detlefs, Flood, Heller and Printezis. "Garbage-first garbage collection." ISMM 2004. doi:10.1145/1029873.1029879
* Tene, Iyengar and Wolf. "C4: the continuously concurrent compacting collector." ISMM 2011. doi:10.1145/1993478.1993491
* Zhao, Blackburn and McKinley. "Low-latency, high-throughput garbage collection." PLDI 2022. doi:10.1145/3519939.3523440
* Doligez and Leroy. "A concurrent, generational garbage collector for a multithreaded implementation of ML." POPL 1993. doi:10.1145/158511.158611
* Doligez and Gonthier. "Portable, unobtrusive garbage collection for multiprocessor systems." POPL 1994. doi:10.1145/174675.174673
* Marlow, Harris, James and Peyton Jones. "Parallel generational-copying garbage collection with a block-structured heap." ISMM 2008. doi:10.1145/1375634.1375637
* Marlow and Peyton Jones. "Multicore garbage collection with local heaps." ISMM 2011. doi:10.1145/1993478.1993482
* Gamari and Dietz. "Alligator collector: a latency-optimized garbage collector for functional programming languages." ISMM 2020. doi:10.1145/3381898.3397214
* Sivaramakrishnan, Dolan, White, Jaffer, Kelly, Sahoo, Parimala, Dhiman and Madhavapeddy. "Retrofitting parallelism onto OCaml." ICFP 2020. doi:10.1145/3408995
* Sivaramakrishnan, Dolan, White, Kelly, Jaffer and Madhavapeddy. "Retrofitting effect handlers onto OCaml." PLDI 2021. doi:10.1145/3453483.3454039
* Auhagen, Bergstrom, Fluet and Reppy. "Garbage collection for multicore NUMA machines." MSPC 2011. doi:10.1145/1988915.1988929
* Sagonas and Wilhelmsson. "Efficient memory management for concurrent programs that use message passing." Science of Computer Programming 62(2), 2006. doi:10.1016/j.scico.2006.02.006
* Cheng and Blelloch. "A parallel, real-time garbage collector." PLDI 2001. doi:10.1145/378795.378823
* Ugawa, Jones and Ritson. "Reference object processing in on-the-fly garbage collection." ISMM 2014. doi:10.1145/2602988.2602991
* Reinking, Xie, de Moura and Leijen. "Perceus: garbage free reference counting with reuse." PLDI 2021. doi:10.1145/3453483.3454032
* Lorenzen and Leijen. "Reference counting with frame limited reuse." ICFP 2022. doi:10.1145/3547634
* Tofte and Talpin. "Region-based memory management." Information and Computation 132(2), 1997. doi:10.1006/inco.1996.2613
* Hallenberg, Elsman and Tofte. "Combining region inference and garbage collection." PLDI 2002. doi:10.1145/512529.512547
* Elsman and Hallenberg. "Integrating region memory management and tag-free generational garbage collection." Journal of Functional Programming 31, 2021. doi:10.1017/s0956796821000010
* Hudson. "Getting to Go: the journey of Go's garbage collector." Go blog, 2018. https://go.dev/blog/ismmkeynote
* Jaffer. "Compaction." ocaml/ocaml pull request 12193, merged 2023; shipped in OCaml 5.2.0. https://github.com/ocaml/ocaml/pull/12193

**Barriers and caches** (D7, M7, D4 B):
* Hosking, Moss and Stefanović. "A comparative performance evaluation of write barrier implementation." OOPSLA 1992. doi:10.1145/141936.141946
* Blackburn and Hosking. "Barriers: friend or foe?" ISMM 2004. doi:10.1145/1029873.1029891
* Yang, Blackburn, Frampton and Hosking. "Barriers reconsidered, friendlier still!" ISMM 2012. doi:10.1145/2258996.2259004
* Wilson, Lam and Moher. "Caching considerations for generational garbage collection." LFP 1992. doi:10.1145/141471.141500
* Zorn. "The effect of garbage collection on cache performance." University of Colorado TR CU-CS-528-91, 1991. doi:10.21236/ada444548 (the DTIC record)
* Zorn. "Barrier methods for garbage collection." University of Colorado TR CU-CS-494-90, 1990. https://scholar.colorado.edu/concern/reports/47429970d
* Cher, Hosking and Vijaykumar. "Software prefetching for mark-sweep garbage collection: hardware analysis and software redesign." ASPLOS 2004. doi:10.1145/1024393.1024417
* Garner, Blackburn and Frampton. "Effective prefetch for mark-sweep garbage collection." ISMM 2007. doi:10.1145/1296907.1296915
* Bacon, Fink and Grove. "Space- and time-efficient implementation of the Java object model." ECOOP 2002. doi:10.1007/3-540-47993-7_5
* Tarditi and Diwan. "Measuring the cost of storage management." Lisp and Symbolic Computation 9(4), 1996. doi:10.1007/bf01806316

**The method of the experiments** (*The experiments*, *Measuring*):
* Hertz, Blackburn, Moss, McKinley and Stefanović. "Generating object lifetime traces with Merlin." ACM Transactions on Programming Languages and Systems 28(3), 2006. doi:10.1145/1133651.1133654
* Stefanović, McKinley and Moss. "Age-based garbage collection." OOPSLA 1999. doi:10.1145/320384.320425
* Blackburn, Singhai, Hertz, McKinley and Moss. "Pretenuring for Java." OOPSLA 2001. doi:10.1145/504282.504307
* Blackburn et al. "The DaCapo benchmarks: Java benchmarking development and analysis." OOPSLA 2006. doi:10.1145/1167473.1167488
* Barrett, Bolz-Tereick, Killick, Mount and Tratt. "Virtual machine warmup blows hot and cold." OOPSLA 2017. doi:10.1145/3133876
* Mytkowicz, Diwan, Hauswirth and Sweeney. "Producing wrong data without doing anything obviously wrong!" ASPLOS 2009. doi:10.1145/1508244.1508275

**Lazy evaluation** (*A lazy front end*, added 2026-09-28; the DOI checked against Crossref and the Report read that day; Marlow, Yakushev and Peyton Jones 2007 and Sansom and Peyton Jones 1993 are above; GHC's runtime and nofib are cited by path under `/home/ruud/reference/ghc`):
* Peyton Jones (ed.). "Haskell 98 Language and Libraries: The Revised Report." 2003. Section 6.4, *Numbers*. https://www.haskell.org/onlinereport/basic.html
* Wadler. "Fixing some space leaks with a garbage collector." Software: Practice and Experience 17(9), 1987. doi:10.1002/spe.4380170904

**Engines and their documents** (*What the implementations do*; the sources under `/home/ruud/reference` are cited by path in the text):
* OCaml manual. "Interfacing C with OCaml." https://ocaml.org/manual/latest/intfc.html
* Eisenberg, White, Dolan, Spector-Zabusky and Casinghino. "Unboxed types (version 2)." OCaml RFC pull request 34, 2022. https://github.com/ocaml/RFCs/pull/34; the living documentation https://oxcaml.org/documentation/unboxed-types/intro/
* GHC wiki. "Pointer tagging." https://gitlab.haskell.org/ghc/ghc/-/wikis/commentary/rts/haskell-execution/pointer-tagging
* Gamari. "Low-latency garbage collector merged for GHC 8.10." Well-Typed blog, 2019. https://well-typed.com/blog/2019/10/nonmoving-gc-merge/
* Chez Scheme. IMPLEMENTATION.md. https://github.com/cisco/ChezScheme/blob/main/IMPLEMENTATION.md
* Dart SDK. runtime/docs/gc.md. https://github.com/dart-lang/sdk/blob/main/runtime/docs/gc.md
* Sheludko and Aboy Solanes. "Pointer compression in V8." V8 blog, 2020. https://v8.dev/blog/pointer-compression
* Hudson. "Go GC: prioritizing low latency and simplicity." Go blog, 2015. https://go.dev/blog/go15gc; "A guide to the Go garbage collector." https://go.dev/doc/gc-guide
* Julia manual. "Memory layout of Julia objects." https://docs.julialang.org/en/v1/devdocs/object/
* Larsson. "Erlang garbage collector." ERTS User's Guide. https://www.erlang.org/doc/apps/erts/garbagecollection.html
* Poly/ML. "Source code overview" and "The PolyML structure", SaveState. https://www.polyml.org/documentation/Overview.html; https://www.polyml.org/documentation/Reference/PolyMLStructure.html#SaveState
* SML/NJ. "110.94 release notes" (the first 64-bit release), 2019. https://smlnj.org/dist/working/110.94/110.94-README.html
* MLton wiki. "GarbageCollection"; "PackedRepresentation". http://mlton.org/GarbageCollection; http://mlton.org/PackedRepresentation

**Read from the owner's copies.** Seven of the sources above could not
be reached beyond their abstracts or their scans when this roadmap was
written on 2026-09-26; on 2026-09-27 the owner put their PDFs under
`/home/ruud/reference/papers/`, and all seven were read in full and their
findings put into *What the literature says* and *What the numbers say*:
Blackburn and Hosking 2004 (`1029873.1029891.pdf`), Wilson, Lam and
Moher 1992 (`141478.141500.pdf`), Appel 1989 (`appel1989.pdf`), Gudeman
1993 (`10.1.1.39.4394.pdf`; `TR93-27.pdf` is the same report as a scan
without a text layer), Dybvig, Eby and Bruggeman 1994 (`TR400.pdf`,
read as rendered pages, its text layer being garbled) and Reppy 1993
(`tm-gc.pdf`). Bacon, Fink and Grove 2002 (`Bacon02Space.pdf`) followed
later the same day and was read too.

# Roadmap: performance -- the compiler, and the code it makes

This plan replaces the plan of 2026-09-24, whose items are nearly all done
(*What became of the plan of 2026-09-24*). Since then:

* the register bytecode and its JIT became what Rune runs;
* values became 8 bytes, and the collector generational;
* the compiler learned units and a REPL;
* Rune compiled MLton and HOL4.

This plan says where Rune stands against MLton and Poly/ML now, why, and
what would close the gap. It has two tracks:

* **the compiler's own speed**, where large programs written with
  signatures and functors take minutes to elaborate;
* **the speed of the code it makes:** the register bytecode, the middle
  end that makes it, and the JIT's machine code.

It also measures what Rune's determinism costs: the instruction count, and
allocation counts that every engine must agree on.

It was written on 2026-10-11 against master `921af2cc`, on branch
`performance`. What it rests on:

* **Measurements and prototypes made for it** (*Measuring*), named E1 to
  E24 below. Each prototype is a patch kept with the drafts, gated on
  identical output and counts (E21 on the whole program's output).
  * The compiler: the elaborator's counters, generated programs that scale
    each construct, sharing done once, functors typed from a summary,
    types hash-consed.
  * The JIT: a dump of its code by role, a VM without counting, inline
    equality and exception paths, pointers in registers.
  * Allocation: a census of how far each object goes.
* **The sources of MLton, Poly/ML, SML/NJ, MLKit, OCaml, Chez, GHC and
  Wasmtime** under `/home/ruud/reference`, and the literature
  (*References*: every DOI checked against Crossref, and rr's report at
  DataCite).

`performance.md` alone below means this plan. [docs/performance.md](../performance.md)
is the page of timings, re-timed at M1 under load and at M10.

## Status

**Retired** (2026-10-20, M10): every milestone done, *Where we are*
measured again beside its first measurement (*Where we ended*), and what is
left moved into the plans that take it -- [jit.md](jit.md),
[garbage-collector-v3.md](garbage-collector-v3.md),
[middle-end.md](middle-end.md) and
[incremental-compilation.md](incremental-compilation.md), each under *Left
by the performance plan* or its own list of what is left -- or, where none
does, listed under *Left for the next plan* below.

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done (2026-10-11); every decision taken on 2026-10-12, D7 with an addendum |
| M1 | Measure: the JIT's code dumped, the elaborator's counters, the register VM in every timing target, HOL and MLton as scripts, new budgets | in part (2026-10-12, branch `perf-m1`): `--pass-stats` complete, the timing targets on Rune as shipped, Poly/ML in `perf-cycles.sh`, HOL's and MLton's measurements as scripts, the module language's budgets, Poly/ML's slowdown found and fixed, `docs/performance.md` re-timed in counts and ratios under load (its seconds again at M10) (*M1*, *Done so far*); the elaborator's counters (2026-10-12, branch `perf-front`): `--pass-stats=elab`, a line per top-level declaration (docs/ir.md); on MLton's 606 units, type-checked by MLton's build, the lines add up to 159.005 s against the elaborate stages' 158.991 s, with E18's counters (1.82G type nodes realised, 113M unifications, 400 applications that make code and 1,206 made to check); off, the counters cost 0.03% of those units' instructions (425.52G against 425.38G, fixed heap of 7 GB); the JIT's code dumped (2026-10-12, branch `perf-back`): `runevm --jit-dump=DIR` writes each function's code with the bytecode instruction and the role of every part, and perf's jitdump (`perf inject --jit` and `perf annotate` read it, checked by hand with perf 6.18); `scripts/jit-dump.py` disassembles it by role and counts callgrind's instructions by role; `tests/register/jit-dump.py` in `make test-register-jit`. It gives E9's 82.5 instructions per `fib` call again, role by role, and leaves `--count` and the code as they were |
| M2 | Signatures: sharing and `where` in one realisation | done (2026-10-12): a run of sharing by union-find, a chain of `where` at once, realisations that keep what they do not change (nothing allocated where nothing changes), matching's fast paths (equal schemes, its messages made only for an error, a merge sort, a set of the flexible names). MLton's 606 units type-checked by MLton's build: 476.0G to 153.0G instructions:u (`perf stat`, `max-heap 5g` as E20; repeatable only where the heap allows: with a fixed heap of 7 GB, 425.4G to 149.2G, E20's prototype 187.9G); `BASIS_EXTRA` 1.48-1.57 s to 0.016-0.024 s; type-checked by the compiler on `runevm --count`: 200 specs shared 16 ways 2,367M to 21.2M, nested 2,839M to 19.4M, `where` 1,000 by 400 317M to 13.3M, 2,000 specs 846M to 22.4M, one signature instantiated 256 times 90.6M to 75.4M (E20's regression gone); every output byte for byte the base's (bootstrap, Basis cache, suites, every error test's messages, xc2, MLton's 1,582 unit files); M1's budgets on the module language tightened to these counts (`compile-share`, `-sharenest`, `-where`, `-sig`, `-funsig`) |
| M3 | Functors: typed from their signature, copies only for code (D3 decided), cheaper matching, MidCanon's quadratic | done (2026-10-12): every application typed by the functor's signature (rule 54) -- inside a functor's declaration by its summary, with the counters replayed; one that makes code by the summary realised with its copy's names -- the signature in the export basis (`UnitBasis.version` 6), a use of a functor holding by the signature's fingerprint and an application that makes code using the unit the functor is from, MidCanon's quadratic gone. MLton's 606 units type-checked by MLton's build: 476.0G to 89.1G instructions:u (`max-heap 5g`; 96.9G with a fixed heap of 7 GB, against 425.4G); Rune at tier 2 compiling MLton's compiler: elaboration 82.1 s, the compile 99 s and 5.8 GB (one run, load average 14 to 25); the compiler type-checking on `runevm --count`: a functor applied 80 times 193.9M to 44.9M, nested functors 785M to 137M (compiled), M1's budgets `compile-funapp` and `-funnest` tightened to these counts. Gate as [functors.md](functors.md)'s *A contradiction in M3*: the whole program's output the base's byte for byte (bootstrap, suites, error messages, xc2, MLton's 606 files compiled whole); every unit's code the same with identities masked, and the linked program too (it carries the identities, all new with the version); a build through the cache the same as a fresh one; `used` the base's in 780 of 791 units, 11 recording 14 to 84 fewer type variables (the base's copies, elaborated with arguments whose types drop a parameter, were more general than the signature); scenarios S65 to S67. The equality program rejected (`tests/errors/err.functor_equality.sml`), and an application that makes code no more polymorphic than its signature (`err.functor_signature_types.sml`). HOL4 built by this compiler in a fresh clone (`$D/hol` of the drafts): `hol.state` in 1,419 s (at a low priority, under load), then 210 targets more in the two hours given and none failing, as with M3's earlier builds (218 and 182) |
| M4 | Types shared: `Ty.ty` hash-consed, `exponential.sml` compiled | done (2026-10-19, branch `perf-front`): `Ty.ty` abstract and hash-consed, each node numbered and knowing its size and generic variables; equality, Simplify's key, `subst`, `match`, `gens`, MidCanon's renaming, MidText's printing and `UnitMid`'s pickles by the numbers (version 3); MidText abbreviates a type of more than 1000 nodes (`(type %N TYPE)`); the translation's `--type-work` kept, set by what the conversion does (type-checker.md). `exponential.sml` passes `run-mlton.sh` at `-O0` to `-O2` with `--lint` and `--mid-roundtrip`, its line gone from `mlton-skip.txt`; flat from 16 to 128 applications (0.01 s, 10 to 13 MB, with the lint and the round trip), where 24 took 9.3 s and 2.8 GB; `compile-expo` at 20 applications 328.2M to 2.40M instructions on `runevm --count`. Ordinary programs pay a little for the table: the bootstrap +1.3% instructions and −1.8% bytes (+1.9% on the stack VM), a functor applied 80 times +7.1%, the others at most +3%; with MLton's build, the bootstrap 4.98G to 4.64G instructions:u and its live data 50 to 34 MB, MLton's compiler whole 119.6G to 119.1G and in units 1,161.7G to 1,162.4G (fixed heap of 7 GB). Gate: every output the base's byte for byte (bootstrap, Basis cache, suites, every error test's messages, xc2, MLton's 606 files whole and their 1,582 unit files, through the cache too); *M4*, as built |
| M5 | Runtime calls in line: equality, `ptr_eq`, strings, handlers, raise | done. D7 A and `TextIO` done (2026-10-12, branch `perf-back`): `=` decided in line where no walk is needed (identity, kinds, refs and arrays, boxes, strings word by word), `ptr_eq` in line, D7 B's `string_eq` in line whatever the strings' length, the order of strings in line where the shorter has at most 8 bytes (the slow path a lean call with the volatile homes saved, its arguments from scratch registers: E12's bug fixed; its test comes with M7, when pointers have homes), the handler pushed and the raise unwound in line (the REPL's mark and the debugger's raises handled), all in `fastprim.h` too; counts unchanged. HOL's kernel work 87.53G to 82.37G instructions (−5.9%, `perf stat`); `poly_eq` walked in C on 1.22% of HOL's 40.0M calls and 3.72% of the bootstrap's 2.91M (`--jit-stats`); 25.6M handlers pushed, none through C; 4.86M raises, 6,825 through C; no `ptr_eq` or `String.<` on the generic path. The bootstrap 17.32G to 17.06G instructions. `TextIO`'s output with no handler per call: `output1` 63 to 45 bytecode instructions and 4 objects to 1 per call, `ray` −19% of its bytes. D7 B done (2026-10-12, "Compare by type in the middle end, and match strings by their length"); D7 C benchmarked and kept, opt-in under `-O2` (2026-10-12, "Compare closed datatypes by equality functions of their own at -O2"): *M5*, as built |
| M6 | The call made lean | done (2026-10-12, branch `perf-back`) but for the closure in a register: no fill (the stack kept clean above its pointer, `VM.stack_clean`), the poll in the room check, the frames grown with the stack, `lea` for the return address, the landing in line, `rbp` the frame's record, no frame index kept by the code (`VM.fp` made from `rbp` at a sync), a return through the frame's `native_ret` (the caller's landing, or a trampoline for the interpreter and the top level) with the value in `rax` and nothing tested but the watermark (2 instructions), a table of calls by function for closure calls and calls into functions without code, known calls patched when the callee is compiled, tail calls' arguments in place, counting per extended block, compare and branch fused; a frame's registers are not filled with unit, so compiled code tells the VM at every call into C which are live, and a collection takes the frame that runs as precise as one that waits (`VM.top_live`). A `fib` call 82.5 to 39 instructions and 16 to 6 stores; a closure call (`CALL`) 52 to 25; calls and returns 31% to 16.8% of the bootstrap's instructions (2.36G of 14.04G, callgrind with the dump); the bootstrap 17.06G to 13.28G instructions and HOL's kernel work 82.37G to 54.93G (−33%, `perf stat`); `--count` unchanged. `ENV` reads the closure through `rbp` (one load) but keeps its null and length tests (7 instructions with the copy): nothing checks an `ENV`'s index against the closures made of its function (the loader could), so the tests stay -- at most about 150M of the bootstrap's instructions (37.5M `ENV`s, four tests each) |
| M7 | Pointers in registers | done (2026-10-12, branch `perf-back`): a pointer's, a constructor's and an unknown register's general home (tag `T_PTR`, the word as the slot has it), written back at every safepoint and loaded again after every call into C that may collect; tags, kinds and lengths tested as a slot's where the section does not vouch; a real or a 64-bit number moved into such a home boxed through its slot. Under `--gc-verify` and `--gc-stress` the code checks after every call into C, where no collection ran, that the homes C kept agree with their slots (a fatal error names the register), and `--gc-verify` fills the nursery with garbage after a minor collection; a home not reloaded and one not written back, put in on purpose, are both caught. E12's `string_order` bug has its test (`tests/lang/rt.gc_pointer-homes.sml`), which fails with the bug put back. The bootstrap's pointer loads from slots 743M to 262M and stores 447M to 121M (callgrind); the bootstrap 13.28G to 13.09G instructions and HOL's kernel 54.94G to 53.37G (`perf stat`); calls and returns 17.4% of the bootstrap (landings and write-backs carry the pointers now); `check-jit.sh` and the language suite green in every mode, under `--gc-stress` and `--gc-verify`; `--count` unchanged. Cycles, an indication on a loaded machine: the bootstrap about 10% fewer (median of five), a list walk 18% |
| M8 | Allocation in the middle end | done (2026-10-19, "Remove allocation in the middle end"): steps 1 to 6; `fft`, `barnes-hut`, `peek`, `imp-for` met, the bootstrap, `raytrace` and MLton's set not; *M8*, as built |
| M9 | Native frames: a gate, then a roadmap of its own | done (2026-10-20): [native-frames.md](native-frames.md)'s M1 to M9 -- frames in the value stack with a header of three words, returns through the header's return word, the watermark by a return barrier, arguments in registers, the allocation pointer in `rbp`, predicted returns behind `--jit-returns=call`. A `fib` call 39.0 to 26.0 instructions and 11.0 to 8.1 cycles (MLton 8.7), a `tak` call 47.3 to 31.7 and 13.2 to 10.2 (MLton 10.0); the bootstrap 1.64 to 1.43 times MLton's cycles, HOL's kernel work 3.10 to 2.20 times Poly/ML's, MLton's set 5.61 to 4.90 times MLton's in the geometric mean (WSL2, one session at a load of about 1); what is left is in M10 |
| M10 | Measure again, and retire this plan | done (2026-10-20, branch `perf-m10`): *Where we are* measured again with M1's tools, before (`921af2cc`) and after (`a6a024ab1`) in one session (*Where we ended*): the compiler compiling itself 2.39 to 1.38 times MLton's build's cycles (4.65 to 2.69 its instructions), HOL4's kernel work 5.96 to 2.14 times Poly/ML's (theories 4.1 and 3.9 to 1.7 and 1.6 by HOL's clock), MLton's set 9.7 to 3.7 times MLton's in the geometric mean, `examples/benchmarks` 5.05 to 2.34, Rune compiling MLton's compiler 984 s to 84 s (elaboration 953 s to 71 s), MLton built by Rune building MLton 9.2 to 4.6 times MLton built by MLton; [docs/performance.md](../performance.md) rewritten, the `xc1` hosts timed again; `--pass-stats`' check held to SML/NJ's clock (15% where 2%: it counts the collector twice); the frames' walk a group of `perf-groups.awk`; deep recursion's lost cycles found in the frames' walk, and MLton built in units found to be fingerprints hashed (*M10*); what is left moved to the plans that take it (*Left for the next plan*) |

## The request

The owner's brief, verbatim:

```
- below is old performance plan. many changes have landed in master since then. you task is to refresh this into a new roadmap to improve rune's performance
- the register bytecode with jit vm is now the default
- improved garbage collectors, incremental compilation and have landed in master among other big pieces of work.
  - gmp support for infint is already being worked on by antoher agent on the gmp worktree. we can measure if poor infint performance is an issue but no need to address it here as well (to avoid duplciating work).
- we have now been able to use rune to compile two very large systems:
  - HOL4 (docs/plans/hol4.md): rune is about 4.5x slower than PolyML when doing a full theory build in HOL4. the HOL4 agent speculated on these causes (unclear to me how much measurement was done):
    - bad code generation for code that calls a lot (fib, tak)
    - equality and string ordering are not inlined in the jit
    - nor are raising and exception handling
  - MLton: rune can build mlton since this PR https://github.com/MLton/mlton/pull/660
    - mlton-build-rune is about 4x faster than rune-build-rune (roughly what we saw in hol4)
    - rune-build-mlton is far worse than mlton-build-mlton (20x)
    - there measurements were before the heap layout and second generation garbage collectors
- one of the great strengths of rune during has been it's deterministic execution model. we want to retain this but should quantify the cost. and consider what improvements could be made
  - the vm does instruction counting and we should know how much overhead this adds
  - avoiding heap allocations should generally be a big win. i think we may have skipped some possible optimizations here to keep allocation counts exact accross vms. we need to quantify how much we lose because of this. is it possible to count heap allocations + elided heap allocations and then we use their sum to compare different vm?
- the new performance roadmap should focus on two things:
  1) compiler performance. the following items were noted:
     - signatures that share large structures;
     - functors applied many times, whose bodies are elaborated again in full at every application.
     - we also have the pathalogical https://github.com/MLton/mlton/blob/master/regression/exponential.sml
     - as always study exising sml implementations (some available at /home/ruud/reference) and the academic literature
  2) code quality. this encopasses both the register bytecode generated, the optimizations and intermediate languages to create it and the quality of the jit code. items flagged already:
     - Then the cost of a call at tier 2 and pointers in registers (stack maps)
     - avoiding heap allocations
     - please use tools like perf and inspection of intermediate represenation and generated machine code of both rune and other compiler to find the cause of what is needed to reach parity.
```

Where the brief's numbers came from, measured again here (*Where we are*):

* **"rune is about 4.5x slower than PolyML when doing a full theory
  build".**
  * [hol4.md](hol4.md) measured 3.7 to 5.2 for three theories, and 3.4 for
    the build through `src/boss`. Rune's build ran beside other builds.
  * Today `logroot` is 3.5 times and `mergesort` 5.1 times Poly/ML by
    HOL's own clock. HOL's kernel work is 5.6 to 9.3 times, and 31 times
    for `Arbnum`'s IntInf.
* **"mlton-build-rune is about 4x faster than rune-build-rune".**
  * This is MLton's PR #660: Rune compiling MLton's sources (MLton's own
    `make rune-mlton`), 900.96 s of user time on Rune against 121.80 s for
    MLton's build of Rune: 7.4 times, or 5.64 by the PR's own measure.
    That was at `4652d4a`, on the stack VM, before the JIT was the
    default, the 8-byte value and the generational collector.
  * Today the same compile on Rune takes 803 s of user time (E5, on a
    loaded machine). Against MLton's build of Rune, 625 s against 142.5 s
    on a quiet machine on 2026-10-09 is 4.4 times
    ([incremental-compilation.md](incremental-compilation.md), M1).
  * The compiler compiling itself is 2.46 times MLton's build in cycles.
* **"rune-build-mlton is ... 20x".**
  * PR #660: 37.22 times, MLton built by Rune building MLton, on the
    stack VM.
  * Today MLton built by Rune compiling MLton's benchmark programs takes
    5.6 to 7.1 times MLton built by MLton (E6). Building MLton itself:
    9.2 times the processor time (3,658 s against 396 s) and 13.3 times the instructions, at 8.7 GB and 8.3 GB at their largest (E6).

## Where we are

Measured on 2026-10-11 on master `921af2cc` (*Measuring*). Rune means the
VM it ships, `bin/runevm`, tiering up to tier 2 by default; MLton is
20241230 and Poly/ML 5.9.2.

* **Instruction counts repeat:**
  * Rune's own counts to within a few thousand instructions (the
    compiler's `--count` depends a little on its environment);
  * whole HOL processes within 2%;
  * Poly/ML's within 4%, with its collector.
* **Cycles and times are indications.** They are the least of several runs
  (or the mean of `perf stat -r 5` where marked), on a machine shared with
  other work, so treat their ratios to about ±10%. E5 and E6 are single
  runs. Ratios are within one session.

### Small programs

The programs of tests/perf, in cycles (E1):

| Program | Rune | MLton | Poly/ML | Rune / MLton | Rune / Poly/ML |
|---|---:|---:|---:|---:|---:|
| `array_sieve` | 117M | 30M | 37M | 3.9 | 3.2 |
| `fib` | 240M | 61M | 55M | 3.9 | 4.4 |
| `tak` | 68M | 20M | 21M | 3.5 | 3.3 |
| `word_bits` | 70M | 16M | 29M | 4.3 | 2.5 |
| `string_ops` | 367M | 115M | 149M | 3.2 | 2.5 |
| `list_ops` | 152M | 61M | 100M | 2.5 | 1.5 |
| `real_nbody` | 177M | 188M | 287M | 0.94 | 0.62 |
| `intinf_fact` | 163M | 0.8M | 4.5M | (MLton moves the repeated pure computation out of the loop: the plan of 2026-09-24) | 36 |

The same programs on Rune's other engines, in cycles (E1). The
interpreter executes the most instructions per cycle, but many more
instructions.

| Program | Tier 2 (default) | Tier 1 | Interpreter | `runeopt` | Stack VM |
|---|---:|---:|---:|---:|---:|
| `fib` | 240M | 248M | 780M | 262M | 1,020M |
| `word_bits` | 70M | 115M | 502M | 147M | 730M |
| `real_nbody` | 177M | 361M | 648M | 417M | 1,323M |
| the compiler compiling itself | 11.3G | 12.2G | 22.9G | 10.8G | 25.8G |

**MLton's benchmark set** (E2): 38 of its programs ran on Rune and MLton, and 23 on Poly/ML as well.
Twelve need the input files of MLton's own harness (`DATA/`), which
`scripts/perf-cycles.sh --mlton-bench` does not give them.
`smith-normal-form`, bound by IntInf, was stopped.

| | Programs | Geometric mean of Rune's cycles over theirs | Median | Range |
|---|---:|---:|---:|---|
| against MLton | 38 | 10.3 | 8.0 | 1.5 (`even-odd`) to 739 (`pidigits`) |
| against Poly/ML | 23 | 2.5 | 2.3 | 0.19 (`fft`) to 199 (`pidigits`) |

* **Programs of calls and closures** are 2.8 to 4.2 times MLton, as
  tests/perf is: `barnes-hut`, `nucleic`, `tak`, `logic`,
  `model-elimination`, `tyan`, `fib`.
* **The outliers are the Basis's own code** (*The Basis's own code*):
  * `vector32-concat` 89, `vector-rev` 65, `vector64-concat` 60;
  * `output1` 37, `checksum` 32, `string-concat` 26;
  * `imp-for` 25, `md5` 22, `matrix-multiply` 21, `mpuz` 20, `peek` 19.
* **IntInf:** `pidigits` 739 and `smith-normal-form` about 68.

**`examples/benchmarks`** (E3): 152 programs; Rune's times from a run with the JIT at its default.
Master's `make bench` gives its configuration `rune:new` `--jit=off` and so
times the interpreter: a first run done that way took 820 s where the JIT
takes 269 s. Medians of three fresh processes, startup included.

| | Programs | Rune | MLton | Ratio |
|---|---:|---:|---:|---:|
| programs of at least 0.10 s on Rune, in total | 71 | 268.8 s | 43.8 s | 6.1 |
| ... without `mandelbrot-rat` (IntInf) and `mpuz` | 69 | 184.0 s | 40.1 s | 4.6 |

* **The geometric mean** of Rune's time over MLton's is 5.2 (median 4.5,
  62 programs), and over Poly/ML's 2.6 (median 2.6, 66 programs).
* **Against 2026-10-03:** [docs/performance.md](../performance.md) had 7.8
  and 5.6 for the same two totals.
* **The worst:** `mandelbrot-rat` 164 (IntInf), `id-ray` 31, the
  `digits-of-e` programs 21 to 24 (IntInf), `mpuz-mlkit` 17, `zebra` 16.
* **The best:** `tak` 1.8, `kittmergesort_tp` 1.7, and the latency
  workloads 1.1 to 1.2.

### The compiler compiling itself

The compiler compiling its own sources, register target, means of
`perf stat -r 5` (E4). The outputs are the same but for the paths of the
Basis's files: the VM's runs were given `--lib lib`, the host builds'
wrappers `bin/../lib`.

| Build | Cycles | Instructions | Processor time |
|---|---:|---:|---:|
| Rune, tier 2 (default) | 11.95G | 17.32G | 3.76 s |
| Rune, tier 1 | 17.9G | 19.26G | 6.03 s |
| Rune, the interpreter | 27.6G | 49.05G | 8.49 s |
| MLton's build | 4.87G | 3.78G | 1.86 s |
| Poly/ML's build | 23.6G | 38.5G | 8.9 s |

So the compiler on Rune takes 2.46 times the cycles of MLton's build and
4.6 times the instructions.

**Poly/ML's build of the compiler has slowed down.** Timed again in pairs
(`/usr/bin/time`, user time), it took 5.1 and 6.1 s against MLton's
build's 1.65 s: 3.1 to 3.7 times. On 2026-10-03,
[docs/performance.md](../performance.md) had the two level: 1.08 s and
1.12 s, wall time, for the stack target. Nothing measured here explains
the change; M1 bisects it.

*M1 found no commit to blame* (2026-10-12): the slowdown is Poly/ML's
collector, at the heap Poly/ML starts with.

* **User time against wall time.** Poly/ML's collector runs on several
  threads, so its user time exceeds its wall time. At `6618017`, the
  commit docs/performance.md timed on 2026-10-03, the compile took 0.98 s
  of wall time and 2.45 s of processor time; MLton's build 1.09 s and
  1.05 s.
* **The input grew.** The compiler's own sources went from 14,116 lines to
  22,604, and both builds slowed with them: MLton's from 1.09 to 1.91 s.
  On a fixed input (`hamlet`, 22,907 lines) both commits time the same on
  both builds.
* **The collector's share grows faster than the input.** With one
  collector thread, compiling the compiler took 11.0G instructions at
  `6618017` and 22.4G now, against MLton's build's 2.03G and 3.59G. With
  an initial heap of 1 GB (`-H 1024`) it takes 2.05G and 3.58G: as many as
  MLton's build. So Poly/ML's collector, at Poly/ML's own initial heap,
  does five times the compiler's work, the more so the larger the
  program.

M1 gives the Poly/ML builds (`bin/rune-polyml`, its `runedoc` and
`runeopt`, and an installed `rune-polyml`) a heap of 1 GB to start with
(`POLYML_HEAP` in the Makefile). The compiler compiling itself then takes
1.8 to 1.9 s of user time on Poly/ML's build, as on MLton's, at 712 MB
resident against 342 MB; the bytecode is the same. The numbers:
`results/M1/bisect/` with the drafts.

### Large programs

**MLton's compiler, compiled by Rune** (606 files, 198,458 lines; E5):

* 878 s, 803 s of it user time, at 6.6 GB at its largest, on a loaded
  machine.
* Elaboration is 795 s of it. The nine passes after it take 0.19 to
  3.3 s each, 10.6 s in all.
* The collector promoted 112 GB in 26,313 minor collections.
* MLton's own build of Rune elaborates the same files in about 135 s
  ([incremental-compilation.md](incremental-compilation.md), M1). MLton
  itself type-checks them in 41.6 to 47.6 s (E19).

**MLton built by Rune** (MLton `5fe943391` compiled by Rune, run by
`runevm`), against MLton built by MLton (20241230), compiling MLton's
benchmark programs, in processor time (E6):

| Program compiled | MLton built by Rune | MLton built by MLton | Ratio |
|---|---:|---:|---:|
| `boyer` | 26.0 s | 4.6 s | 5.6 |
| `barnes-hut` | 25.2 s | 4.2 s | 6.0 |
| `nucleic` | 26.3 s | 4.6 s | 5.7 |
| `model-elimination` | 81.5 s | 13.5 s | 6.1 |
| `mlyacc` | 101.5 s | 14.4 s | 7.1 |
| `hamlet` | 148.8 s | 23.4 s | 6.4 |
| MLton itself (`mlton.mlb`) | 3,658 s | 396 s | 9.2 |

Building MLton itself took 13.3 times the instructions. PR #660 measured
37.22 for that build, on the stack VM. The MLton built by Rune is
`5fe943391`; the one built by MLton is the release 20241230.

**HOL4** (E7):

* **The builds.** HOL4 `3d15b18a8` built by master's Rune, and HOL4
  `bdc6917ee` built by Poly/ML. The five commits between them port HOL to
  Rune.
* **Theories** are rebuilt by Holmake. HOL's own clock runs from
  `new_theory` to `export_theory`. Instructions are the whole process's,
  of the same run.

The best of three:

| | Rune | Poly/ML | Ratio | Rune, instructions | Poly/ML, instructions | Ratio |
|---|---:|---:|---:|---:|---:|---:|
| theory `logroot` | 14.9 s | 4.2 s | 3.5 | 72.3G | 13.9G | 5.2 |
| theory `mergesort` | 26.5 s | 5.2 s | 5.1 | 91.2G | 16.7G | 5.4 |

HOL's kernel work in a restored `hol.state`, processor time, the best of
three:

| | Rune | Poly/ML | Ratio |
|---|---:|---:|---:|
| `EVAL ``FACT 60``` | 1.54 s | 0.27 s | 5.6 |
| `EVAL ``FACT 150``` | 16.4 s | 2.94 s | 5.6 |
| `PROVE_TAC`, 20 times | 0.149 s | 0.016 s | 9.3 |
| `SIMP_CONV arith_ss`, 200 times | 0.79 s | 0.12 s | 6.8 |
| `DECIDE`, 200 times | 0.97 s | 0.14 s | 6.9 |
| `Arbnum` multiplication, 200,000 times | 0.66 s | 0.021 s | 31 |

The Rune of 2026-10-10 that built HOL-rune is within the noise of master on
most of these. On `EVAL ``FACT 150``` its best was 22.0 s against master's
16.4 s; master's own three runs spread from 16.4 to 21.2 s.

### Where the time goes

| | The compiler compiling itself | HOL, theory `logroot` |
|---|---:|---:|
| the JIT's code | 66.7% | 80.5% |
| ... of whose instructions: calls and returns | 50% | 60% |
| the collector | 23.3% | 2.3% |
| equality, string order (runtime) | 1.9% | 5.1% |
| exceptions (runtime) | 0.0% | 3.1% |
| the JIT compiling | 1.5% | 1.2% |
| the interpreter | 0.1% | 0.1% |

Shares of samples are by `perf record` over `--jit-perf-map` (E8). Calls'
share of the JIT's instructions is by callgrind (E12; HOL's is from a slice
of its kernel work).

So for the compiler and for HOL, the code is where the time goes, and the
call is most of that. For MLton's compiler, it is the elaborator.

## Where we ended

*Where we are* measured again for M10 on 2026-10-20, with M1's tools, the
before and the after in one session:

* **before** is master `921af2cc`'s compiler and VMs, with M1's tools
  (`75d35ec8c`, the commit M1 re-timed docs/performance.md at), and the
  HOL4 of E7 built by it;
* **after** is `performance` at `a6a024ab1`: this plan's M1 to M9 and
  [native-frames.md](native-frames.md)'s M1 to M9, on master `1dd139fee`,
  and HOL4 `3d15b18a8` built again by it. Master's own changes since
  `921af2cc` are in the after too; the one that shows is GMP under `IntInf`
  ([gmp.md](gmp.md)): `intinf_fact`, `pidigits`, `smith-normal-form` and
  HOL's `Arbnum` are GMP's gains, not this plan's.

The before's instruction counts are E1 to E8's again, to within 3% where
a host's collector or the compiler's clock moves them: the compiler
compiling itself 17.37G (E4 17.32G), `logroot` 74.6G and `mergesort`
91.2G (E7 72.3G and 91.2G), MLton's units type-checked 476.8G (476.0G);
MLton built by MLton building MLton took 1,103.9G both times. Cycles and
seconds are the least of N runs. The compiler compiling itself,
`tests/perf` and HOL4 were taken one run at a time, at a load of 2 to 3
(one other run on another core); MLton's set, `examples/benchmarks` and
Rune compiling MLton up to six runs at once, at a load of 4 to 13; MLton
building MLton at 3 to 7. Where each number came from: *Measuring*, and
`results/M10/` with the drafts.

**The headline**, Rune over the yardstick:

| | Before | After |
|---|---:|---:|
| the compiler compiling itself, cycles over MLton's build's | 2.39 | 1.38 |
| ... instructions | 4.65 | 2.69 |
| HOL4's kernel work, cycles over Poly/ML's | 5.96 | 2.14 |
| ... instructions | 7.9 | 3.5 |
| HOL4's theories `logroot` and `mergesort` by HOL's clock, over Poly/ML | 4.1 and 3.9 | 1.7 and 1.6 |
| MLton's benchmark set, the geometric mean of cycles over MLton's (37 programs) | 9.7 | 3.7 |
| ... over Poly/ML's (35) | 3.6 | 1.5 |
| `tests/perf`'s `fib` and `tak`, cycles over MLton's | 3.8 and 3.4 | 1.02 and 1.05 |
| `examples/benchmarks`, the geometric mean of times over MLton's (the 152 of E3) | 5.05 | 2.34 |
| ... over Poly/ML's; over SML/NJ 110.99.9's | 2.47; 2.01 | 1.19; 0.83 |
| Rune compiling MLton's compiler, processor time (elaboration) | 984 s (953 s) | 84 s (71 s) |
| ... over MLton's build of the same compiler | 5.5 | 1.4 |
| MLton built by Rune building MLton, over MLton built by MLton: time (instructions) | 9.2 (13.3, E6) | 4.6 (7.1) |

### Small programs, again

`tests/perf` against MLton (`scripts/perf-cycles.sh`, the least cycles of
five, one run at a time at a load of 3 to 6), Rune over MLton:

| Program | before: instructions | after | before: cycles | after |
|---|---:|---:|---:|---:|
| `array_sieve` | 4.8 | 2.6 | 3.94 | 1.80 |
| `fib` | 4.9 | 1.5 | 3.83 | 1.02 |
| `tak` | 3.9 | 1.4 | 3.44 | 1.05 |
| `word_bits` | 4.5 | 3.3 | 4.27 | 2.96 |
| `string_ops` | 4.5 | 3.7 | 3.00 | 2.61 |
| `list_ops` | 3.0 | 2.4 | 2.38 | 1.89 |
| `real_nbody` | 4.1 | 3.2 | 0.94 | 0.94 |
| `intinf_fact` (GMP since) | 328 | 30 | 211 | 15 |
| `compile-sigs` | 6.6 | 6.4 | 4.02 | 3.46 |
| `runedoc-page` | 2.5 | 2.0 | 2.04 | 1.67 |

* **The call is MLton's now**: `fib` and `tak` from four times its cycles
  to within 5%, with 1.4 to 1.5 times its instructions where it was four to
  five times.
* **Rune's engines**, on the compiler compiling itself (instructions, the
  before's sources and the after's, at a load of 4 to 11): tier 2 17.37G
  to 13.45G, tier 1 19.31G to 17.18G, the interpreter 49.21G to 60.68G and
  `runevm-stack` 57.92G to 71.14G -- the compiler's own bytecode grew by a
  sixth (M8's copies of functions, accepted) while its sources grew too,
  and tier 2 executes fewer instructions on more work. `runeopt`'s native
  code, level with tier 2 before (1.08 times), is 1.6 times it after.
* **MLton's set** (`peek` and `vector64-concat` not on Poly/ML, `Int64`;
  `smith-normal-form` apart, IntInf: 11,920 to 2.9 times MLton's cycles):
  the programs of calls and closures `fib` 3.58 to 1.18, `tak` 3.42 to
  1.25, `tyan` 2.66 to 1.40, `logic` 3.73 to 1.46, `model-elimination`
  4.86 to 1.94, `nucleic` 3.67 to 2.39, `barnes-hut` 7.10 to 3.56; the
  Basis's outliers `vector32-concat` 81.7 to 7.9, `vector-rev` 63 to 12,
  `vector64-concat` 58 to 4.0, `string-concat` 27 to 3.6, `imp-for` 25 to
  3.0, `peek` 17 to 4.1, `mpuz` 12.8 to 2.4, `output1` 41 to 22,
  `checksum` 28 to 18, `md5` 23 to 12, `matrix-multiply` 17 to 11; IntInf's
  `pidigits` 907 to 17. Slower than before: `merge`, 3.54 to 3.76
  (M10, *As built*: deep recursion).
* **`examples/benchmarks`** (the 152 programs E3 timed, of the 510 the
  suite has now; a load of 4 to 12): the programs of at least 0.10 s on
  Rune 319.6 s against MLton's 50.0 s before, 126.2 s against 51.8 s after;
  the worst `mandelbrot-rat` 143 to 17 (GMP), `flat-array` 57 to 11, `id-ray`
  24, `peek` 22 and `many_refs` 20 to under 6.

### The compiler compiling itself, again

Each tree's compiler compiling its own sources, the least cycles of five
(`perf-cycles.sh`, one run at a time):

| Build | Before: cycles | instructions | After: cycles | instructions |
|---|---:|---:|---:|---:|
| Rune, tier 2 (default) | 11.08G | 17.37G | 8.47G | 13.45G |
| MLton's build | 4.63G | 3.74G | 6.13G | 4.99G |
| Poly/ML's build | 4.94G | 3.70G | 7.06G | 5.70G |

The after's sources are a third more work for MLton's build (4.99G
instructions against 3.74G): Rune does more with fewer instructions and
cycles. Five more runs of each, one after another, give 2.37 before and
1.46 after (`results/M10/quiet`); [native-frames.md](native-frames.md)'s
M9 measured 1.64 to 1.43 on a workload held fixed.

### Large programs, again

**MLton's compiler compiled by Rune** (E5; once each, a load of 7 to 11,
the compiles in units at about 2):

| | Before | After |
|---|---:|---:|
| the whole program on Rune at tier 2: processor time | 984 s | 84 s |
| ... elaboration | 953 s | 71 s |
| ... instructions | 3,436G | 304G |
| ... the largest resident set | 6.6 GB | 5.9 GB |
| ... minor collections; bytes promoted | 26,313; 112 GB | 2,750; 10 GB |
| the same on MLton's build: processor time (elaboration) | 180 s (169 s) | 60 s (49 s) |
| in units on MLton's build: processor time | 281 s | 263 s |
| ... elaboration; the units' interfaces (`unit-usages`, `unit-export`) | 139 s; 110 s | 20 s; 208 s |
| type-checked in units on MLton's build, instructions (M2's and M3's measure) | 476.8G | 93.7G |

M3's target, elaboration under 250 s at tier 2, is met at 71 s. In units
the compile is now the units' interfaces: fingerprints hashed, half of
them twice ([incremental-compilation.md](incremental-compilation.md),
*After M12: what is left*; M10 below).

**MLton built by Rune** (E6): compiling MLton's programs 2.5 to 3.7 times
MLton built by MLton, where it was 4.3 to 7.3 (`boyer` 5.2 to 2.8,
`hamlet` 7.3 to 3.7; the before run again in this session); building MLton
itself 1,952 s against 427 s, 4.6 times (E6: 3,658 s against 396 s, 9.2),
7,798G instructions against 1,104G (E6: 14,677G).

**HOL4** (E7; one run at a time, at a load of 2.1 to 2.5):

| | Before | After | Poly/ML | Before / Poly/ML | After / Poly/ML |
|---|---:|---:|---:|---:|---:|
| theory `logroot`, HOL's clock | 16.5 s | 6.8 s | 4.0 s | 4.1 | 1.7 |
| ... instructions | 74.5G | 35.4G | 14.1G | 5.3 | 2.5 |
| theory `mergesort`, HOL's clock | 19.3 s | 7.9 s | 4.9 s | 3.9 | 1.6 |
| ... instructions | 91.2G | 42.2G | 16.8G | 5.4 | 2.5 |
| the kernel's work, cycles | 52.36G | 18.77G | 8.78G | 5.96 | 2.14 |
| `EVAL ``FACT 60```, processor time | 1.16 s | 0.375 s | 0.204 s | 5.7 | 1.8 |
| `EVAL ``FACT 150``` | 13.3 s | 4.39 s | 2.19 s | 6.1 | 2.0 |
| `PROVE_TAC`, 20 times | 0.107 s | 0.073 s | 0.011 s | 9.7 | 6.6 |
| `SIMP_CONV arith_ss`, 200 times | 0.543 s | 0.244 s | 0.085 s | 6.4 | 2.9 |
| `DECIDE`, 200 times | 0.669 s | 0.290 s | 0.101 s | 6.6 | 2.9 |
| `Arbnum` multiplication, 200,000 times (GMP since) | 0.546 s | 0.102 s | 0.011 s | 50 | 9.3 |

### Where the time goes, again

By `perf record` over `--jit-perf-map`, grouped by `scripts/perf-groups.awk`
(E8; the compiler at a load of 8, HOL before at 11 and after at 2.3):

| | The compiler compiling itself: before | after | HOL, `logroot`: before | after | HOL's kernel work: before | after |
|---|---:|---:|---:|---:|---:|---:|
| the JIT's code | 66.5% | 54.2% | 80.9% | 76.9% | 85.7% | 76.5% |
| the collector | 23.1% | 34.0% | 2.5% | 4.9% | 5.0% | 9.7% |
| equality, string order (runtime) | 2.4% | 1.3% | 5.4% | 2.5% | 3.5% | 1.3% |
| exceptions (runtime) | 0.1% | 0.0% | 3.0% | 0.0% | 1.7% | 0.0% |
| the JIT compiling | 2.3% | 3.5% | 1.7% | 3.6% | 0.7% | 1.8% |
| the interpreter | 0.8% | 1.1% | 1.1% | 2.3% | 0.4% | 0.8% |
| restoring the image, loading | 0.1% | 0.2% | 0.5% | 1.8% | 0.7% | 2.9% |

So the code is still most of HOL's time, but no longer the call's
([native-frames.md](native-frames.md), M9: 39.7G instructions to Poly/ML's
11.3G, the bytecode's and the middle end's); the runtime's equality and
exceptions are gone from both; and the collector is a third of the
compiler's cycles, more than its whole gap to MLton's build.

## What became of the plan of 2026-09-24

The plan this one replaces ranked nineteen items by blast radius and gain
(`git show 938b29a:docs/plans/performance.md`). Other documents cite them as
"item N of performance.md", so their numbers are kept here. Seventeen are
done. Two are not done:

* item 9, which only `runeopt` would gain;
* item 18, in part.

| # | Item | What became of it |
|---|---|---|
| 1 | The lexer's lookups | done, `389321a` |
| 2 | The maps' inner loops | done, `389321a` |
| 3 | The file of a position, cached | done, `389321a` |
| 4 | Aliases share a slot; slots reused | done by the new back end (middle-end M4, `3e22cdd`) |
| 5 | Compares that return `order` | done, `bc54313` |
| 6 | The Basis's higher-order functions as local loops | done by workers and specialisation (middle-end M8 `e840204`, M10 `6e9188d`) |
| 7 | Jumps, returns and branches | done by the new back end (M4) and the simplifier (M7, `093fc42`) |
| 8 | No test on the last rule of an exhaustive match | done by decision trees (M9, `6dc3cf3`) |
| 9 | No frame reload after a return | not done; `runeopt`'s code alone (`docs/native.md`) |
| 10 | Grow the heap without collecting twice | done, `9a3bc8a`; the collector has since been replaced |
| 11 | The compiler's other constant factors | done, `add9616` |
| 12 | Loops for self tail calls; closed closures once | done (M8, `e840204`) |
| 13 | A generational collector | done: [garbage-collector-v2.md](garbage-collector-v2.md), merged as `b9506382` |
| 14 | Known calls with n arguments | done: `CALLK`, workers and wrappers (M8, `e840204`) |
| 15 | `runevm`'s loop | done (M6, `efc25ef`); the register VM's loop by jit M2 |
| 16 | The constructor tag in the tuple's header | done (M11, `48745cd`) |
| 17 | Decision trees and a tag switch | done (M9, `6dc3cf3`) |
| 18 | Values in registers across a run | in part: tier 2's homes for unboxed values ([jit.md](jit.md) M9, M10); pointers are this plan's D6 |
| 19 | 8-byte values | done: [heap-layout.md](heap-layout.md), merged as `ca87fa07` |

The plan also carried three assessments, added on 2026-10-05 (`9644da6f`)
"to be revisited". This plan revisits them:

* *The gap to MLton*: by measurement, in *Where we are* and *Where the time
  goes*.
* *Tier 2's registers*: in *The call* and *Pointers in registers* (D5, D6).
* *How good the JIT was*: in *Track B*.

**`docs/performance.md`** is stale until this plan's M1 re-times it:

* its tables are of 2026-10-02/03, the 16-byte value and the copier;
* its `make perf` column `rune` is the stack VM.

*Where we are* below has the numbers that replace it.

## What is different for SML, and for Rune

Most of what makes code fast is the same in every language. This section is
what is not.

**What SML programs do.**

* **Small objects, dying young.** A compiler written in SML allocates a
  tuple, a cons cell or a closure every few instructions. 24.8% of what the
  compiler allocates outlives a nursery of 1 MiB, by the census on the
  8-byte layout ([collector.md](collector.md)),
  so the collector matters. What is never made matters more.
* **Many calls, many of them unknown.** Functions are small. Higher-order
  functions pass closures, and module code calls through structures. A
  call's fixed cost is paid often.
* **Exceptions as control flow.** HOL4 computes with them (`can`, `total`,
  `ORELSEC`, `mk_HOL_ERR`, [hol4.md](hol4.md)), so a handler and a raise
  must be cheap.
* **Polymorphic equality.** `=` works on any type that admits equality. A
  call that is not specialised by type walks both values in the runtime.
* **Modules.** Signatures, sharing and functors are SML's way of building
  large programs. MLton's sources and HOL4 use them at a scale the compiler
  had not met before. MLton's compiler has 368 lines with `sharing`, 93 of
  them `sharing type`, in its 606 files. Its Basis signature `BASIS_EXTRA`
  has 317 `sharing type` and 138 `where type` in 888 lines.

**What Rune does that other compilers do not.**

* **Determinism as a contract.**
  * Every engine runs the same bytecode with the same result, and says so
    in numbers: the instruction count and the bytes and objects allocated
    of `runevm --count`. The engines are the stack VM, the register
    interpreter, the JIT's two tiers on three conventions, and `runeopt`'s
    native code.
  * The suites hold the engines to equal counts (`scripts/check-jit.sh`,
    `scripts/check-register.sh`), and the budgets of `make perf-check`
    are counts.
  * Programs see the count too, through `Runtime.stats`.
  * So an engine may not remove an allocation, nor skip counting an
    instruction, unless the count is kept another way (*Determinism*).
* **A compiler held to strict SML '97.** Functors are elaborated by static
  interpretation: each application is elaborated as its own structure
  ([incremental-compilation.md](incremental-compilation.md), D1). The
  compiler is written in the Basis alone and must build with five other
  compilers and with itself. So it can use no pointer identity, no
  mutable hash-consing tables keyed by address, and no threads.
* **A typed middle end.** Lambda and Mid carry types that two lints check
  after every pass ([ir.md](../ir.md); middle-end D3). Types are part of
  what each pass must keep right, and their size is part of what each pass
  costs: the exponential program shows both.
* **Frames on the VM's own stack.** A call pushes a 40-byte record on
  `vm->frames` and a frame of registers on `vm->stack`, and the collector
  finds its roots in those registers by their tags. Machine code does not
  use the machine stack for SML frames. That makes deoptimisation,
  tracebacks and images simple. It is also why tier 2 never keeps a pointer
  in a machine register ([jit.md](jit.md), D10, option A: "the tags are the
  stack map").
* **The 8-byte tagged word** with 63-bit `int` and `word`, and 64-bit
  integers boxed past 63 bits ([heap-layout.md](heap-layout.md)). MLton
  compiles `int` as 32 bits by default, and Poly/ML as 63.
* **More engines than other compilers keep.** A change to calls,
  allocation or primitives is made in up to four places:
  * the stack VM;
  * the register VM, and its JIT's emitters;
  * `runeopt`'s templates;
  * `fastprim.h`.

  ([weak-points.md](weak-points.md), item 4.)

## Track A: the compiler

### Where the time goes

**The compiler compiling itself** spends little time in its front end. Its
profile under MLton's profiler (E24):

| Part | Share |
|---|---:|
| Simplify | 16% |
| the elaborator | 14% |
| register allocation (`Regs`) | 12% |
| Lower | 9% |
| Translate | 8% |
| MidCanon, which `--pass-stats` does not show (M1 makes it complete) | 8% |
| Emit, likewise not shown | 5% |
| the collector | 17% |

Its build by MLton takes 1.74 to 1.78 s of wall time, and tier 2 3.35 to
3.46 s (three runs, E24; E4's processor times in another session are 1.86 s
and 3.76 s). For this workload the compiler's speed is the code's speed
(Track B).

**MLton's compiler** is the opposite. Rune at tier 2 compiling its 606
files takes 878 s (E5, on a loaded machine; 625 s on a quiet one,
[incremental-compilation.md](incremental-compilation.md), M1). Elaboration
is 795 s of that, against 1.2 to 3.3 s for each pass after it.

The elaborator's own counters on MLton's files, compiled one unit each and
type-checked only, with MLton's build of Rune (E18; 151.3 s of elaboration):

| Where | Seconds | Share |
|---|---:|---:|
| `sharing` in top-level signatures | 83.7 | 55.3% |
| functor bodies copied only to check a functor's declaration | 32.4 | 21.4% |
| functor bodies copied to make code | 22.8 | 15.0% |
| matching at declarations | 8.7 | 5.7% |
| instantiation | 2.7 | 1.8% |
| core type inference | about 4 | about 3% |

Inside the copies, most of the time is matching the argument against the
parameter (`SigMatch.ascribe`), 47 s in all.

* **The worst files:**
  * `x86-generate-transfers.sig`, 23.5 s, and its amd64 twin, 11.5 s:
    489 `shareTypes` calls, each realising about 540,000 type nodes.
  * `main.sml`, 22.7 s: 301 applications that make code, 21.3 s of it
    matching.
  * `main.fun`, 10.1 s, and `compile.fun`, 9.4 s: about 300 applications
    each, made only to check.
* **The counters:** 16,546 calls of `realizeEnv` visit 1.82 billion type
  nodes, 1.61 billion of them for sharing.

**Why** (the code, `src/elab/sigmatch.sml` and `elaborate.sml`):

* **Sharing re-realises the whole signature.** `shareTypes` realises the
  whole signature once per equation. `shareStructures` calls it once per
  type the two structures have in common. `Types.realize` rebuilds every
  node, even where nothing changes.
* **`where type` too:** one whole realisation per clause.
* **Functor bodies are elaborated again.** Each application copies the
  body's syntax and elaborates it in full, and so does each functor
  declaration that contains it. A body nested d deep is elaborated about
  d + 2 times.
* **Matching** sorts constructors by insertion and unifies every value's
  scheme, even when it is the same scheme.

**How it scales** (generated programs, against the other compilers; E19):

| Program | Rune (MLton's build) | Others |
|---|---|---|
| a signature of 200 specs shared by K substructures | quadratic in K: 8.4 s at K = 32 | Poly/ML under 0.05 s, SML/NJ 0.13 s, MLKit 0.9 s, Moscow ML 7.9 s |
| a signature of S specs alone | quadratic in S: 4.3 s at S = 4,000 | Poly/ML 0.5 s, SML/NJ 0.86 s |
| a functor of 40 declarations applied A times | linear: 0.13 s at A = 320 | Poly/ML out of store from 40 × 80, MLKit 73 s |
| nested functors, two applications in each body | doubles with each level: 2.9 s at depth 12 | MLton doubles as well (21.7 s at depth 12); SML/NJ 1.2 s; Poly/ML, Moscow ML and MLKit time out |
| `exponential.sml`, N applications | type-checking flat; a full compile ×2.2 per application, 2.67 GB at 24 (E23 below has the times) | MLton, SML/NJ and Moscow ML flat (MLton 3.6 to 4.1 s); Poly/ML ×2 per application; MLKit out of memory from 28 |

Tier 2 is 4.0 to 4.3 times slower than MLton's build on these.

**Memory.** MLton's files type-checked keep up to 2.17 GB live, with 24.8%
of the time in the collector and 153 GB allocated (E22). With a heap of
2.5 GB the compile runs out of memory in `main.sml`. With every prototype
below, it completes at about 2.49 GB live. So the live data is not the
signatures. It grows in the files full of functors, and what holds it is
not yet known: `Ty.binders`, or each unit's syntax kept in its slots, are
the suspects.

### What the prototypes did

Each prototype was gated on the same output as the base's:

* the bootstrap, the Basis's cache, the language suite, and the first line
  of every error test;
* for E20 and E24, also every unit file of MLton's 1,582;
* for E21, the whole program's output (below).

**E20: sharing in one realisation, and the signature and matching path.**

* Consecutive sharing specifications are resolved together, by union-find
  over the flexible type names, with one realisation for the run. Checks
  and messages are unchanged.
* A chain of `where type` becomes one realisation.
* A realisation gives back the same node where nothing changed.
* Matching gets a set of the flexible names, a merge sort, and no
  unification when the schemes are the same.
* The environment of the specifications is extended, not rebuilt per
  specification.

Results, all exact and identical in output:

| | Before | After |
|---|---:|---:|
| MLton's 606 units, type-checked (instructions) | 476.3G | 179.3G (−62%) |
| their signature files (elaboration) | 81.4 s | 2.6 s |
| `BASIS_EXTRA` | 1.43 to 1.54 s | 0.033 to 0.038 s |
| MLton's Basis, all its units | 2.7 to 3.0 s, 773 MB | 0.9 s, 279 MB |
| a signature of 200 specs shared 16 ways (`--count`) | 2,369M | 24.1M |

One regression: instantiating one big signature 256 times got 20% slower.

**E21: functors typed from a summary when only checked.**

* An application inside a functor declaration's check takes the applied
  functor's result, realised by the argument's match and with fresh names
  for the types its body makes. That is what MLton does
  (`functorClosure`). Applications that make code are elaborated as
  before, so static interpretation stays
  ([incremental-compilation.md](incremental-compilation.md), D1).
* Results:
  * instructions −19.5%;
  * `main.fun` from 9.2 s to 0.01 s (10.1 s in E18's run with counters),
    `rssa-simplify.fun` from 2.8 s to 0.5 s.
* What does and does not change:
  * The whole program's output is identical.
  * The bytes of 645 unit files differ, because fewer fresh names are
    made. Either the counters are replayed or the gate compares canonical
    output.
  * A datatype made in a body takes its equality from the functor's formal
    parameter. That is what the Definition's functor signatures say, and
    stricter than what Rune does today. A test written since shows the
    difference: [functors.md](functors.md), *What the Definition says*.

**E24: MidCanon's quadratic.** `MidCanon.program` derives `Ty.extras` again
over every datatype for each datatype it enters. A 20-line fix takes nested
functors of depth 10 from 20.3 s to 0.88 s, with identical output.

**Together.**

| | Instructions | Wall time |
|---|---:|---:|
| Rune's elaborator on MLton's 606 units, before | 476.3G | about 150 s |
| ... with all three prototypes | 97.0G (−80%) | 41.4 s, one run on a busy machine |
| MLton type-checking its own sources | | 41.6 to 47.6 s |

So with all three prototypes, MLton's build of Rune elaborates MLton's
sources in about the time MLton itself takes. The instructions are the
measurement; the times come from different sessions.

### Types in the IR, and the exponential program

* **Memoisation alone halves the time.** `exponential.sml` at 24
  applications takes 9.2 s and 2.72 GB today. Memoising `Ty.fromTypes` on
  the elaborator's cells gives 5.0 s and 1.87 GB, and memory still grows
  fourfold every two applications (E23).
* **The next walk unshares the type again.** The profile then shows
  MidCanon's renaming of types (62%) and `gensOfTy` (32%). MidCanon is a
  walk [type-checker.md](type-checker.md) did not list, and it rebuilds the
  shared types as trees.
* **Partial hash-consing was slower.** Hash-consing only in `fromTypes`,
  `gensOfTy`, `Ty.equal` and the specialisation key made the compile 3 to 8
  times slower: 93% of the time went to interning nodes that the other
  passes keep rebuilding.

So only all of `Ty.ty` made canonical would do: an abstract type with
smart constructors and integer identities, every walk memoised on them.
That is the recipe of Shao, League and Monnier for SML/NJ's FLINT, measured
on this very program (*What the literature and the implementations say*).

On ordinary code the gain would be small. The compiler's Mid has 497,000
type nodes as trees and 7,300 distinct ones, but a type is 3.3 nodes on
average. MLton's sources have 1.61 million and 50,000 distinct. Hash-consing
would shrink that 30 to 70 times, but it is about 50 MB. So
`exponential.sml` is the reason to do it, not ordinary programs.

## Track B: the code Rune makes

Everything here was measured on master `921af2cc` with the experiments named
in brackets (*Measuring* says how each was run).

* **Counts of instructions repeat**, whether bytecode (`runevm --count`) or
  machine instructions (callgrind, `instructions:u`): Rune's to within a
  few thousand instructions in billions.
* **Cycles do not.** Under WSL2 on a busy host they are given as the best
  of several runs, or as the mean of `perf stat -r 5` where so marked.

### Where the time goes

Of what the compiler executes compiling itself: 17.85G machine
instructions under callgrind, 0.5G of them the dump's own writing (E12).

| Part | Share of all instructions | Share of the JIT's code |
|---|---:|---:|
| The JIT's code (tier 2 and tier 1) | 62% | |
| of which: calls and returns | 31% | 50% |
| of which: pointers loaded from and stored to their slots | 6.4% | 10.3% |
| of which: the count (`lea r15`) | 3.3% | 5.3% |

In cycles (perf over the JIT's code by role, on a busy machine; E10), the
call machinery is:

* 22.7% of the bootstrap;
* 24.8% of `boyer`;
* 22.5% of `mlyacc`;
* 35.4% of `hamlet`.

The collector is 23% of the bootstrap's samples (E8).

In a slice of HOL's kernel work (E12), the call machinery is 59.7% of the
JIT's instructions and 38.6% of all. One bytecode instruction in 6.5 is a
call, and closure calls (27.5 million) outnumber known calls (26.0
million). [hol4.md](hol4.md)'s profile of `logroot` put 78.6% in the JIT's
code, and E8's 80.5%. So most of HOL's gap is in the JIT's code, and most of
that is the call.

### The call

**What a call costs** (machine instructions per call by callgrind, cycles
by `perf stat` from the difference of two run lengths; E9):

| | Rune, tier 2 | MLton | Poly/ML | OCaml |
|---|---:|---:|---:|---:|
| `fib`: instructions per call | 82.5 | 17.0 | 14.5 | 10.0 |
| `fib`: cycles per call | 31.3 | 8.6 | 6.8 | 5.1 |
| `tak`: instructions per call | 92.0 | 23.3 | 23.0 | 19.7 |
| `tak`: cycles per call | 38.3 | 11.4 | 9.8 | 6.7 |

**Where `fib`'s 82.5 go**, by the role of each machine instruction (a dump
of the JIT's code with each instruction's role, E9):

| Role | Instructions | |
|---|---:|---|
| the body: compare, subtract, add, the branch | 20 | |
| the return | 22 | a test for the top level, `imul` by 40, the result read from the frame record, a watermark compare, `r14` rebuilt, a test of `native_ret`, then an indirect jump to a landing out of line |
| the frame record | 14 | `vm->frames` loaded, `imul` by 40, seven stores |
| the count | 5.5 | `lea r15` per run, and a run ends at every primitive |
| the fill | 5 | unit stored into every register above the arity: the running frame's slots are all roots |
| the landing | 4 | homes reloaded after the return |
| two room checks and the poll | 9 | the stack, the frames array, the interrupt flag |
| arguments, the jump, the write-back | 3 | |

`fib` makes 16 stores and 15 loads per call, on a Haswell with one store
port. Other shapes cost more:

* a closure call, 52 instructions;
* a call to a function compiled after its caller, 5 more (6 instructions
  for 1): the call goes through the code object (19% of the bootstrap's
  known calls);
* `ENV`, 10;
* a callee of 30 registers, 455 per call, 18 of them the fill;
* a call inside a handler, 147, plus 43 in C to push the handler.

**The others** (their code, E9 and *What the implementations say*):

* MLton keeps its own stack. It stores the return address, returns with
  `jmp *-8(%rbp)`, and has one compare against the stack limit, which is
  also how a signal is seen.
* OCaml and Poly/ML use `call` and `ret`, with arguments in registers.
* None of the three keeps a frame record apart from the frame, fills a
  frame at entry, or returns through the frame's memory.

**What the parts are worth.** Five parts were prototyped, each alone and
all together, with identical counts and output. The language suite passes
with all of them:

| | Instructions per `fib` call | Bootstrap instructions | HOL kernel instructions | Cycles, best of 10 |
|---|---:|---:|---:|---|
| today | 82.5 | 17.33G | 87.5G | |
| no fill: the stack kept clean above the stack pointer | 77.5 | 17.09G | 85.3G | `fib` −10.8%, `tak` −11.7%, bootstrap −3.0% |
| all five | 71.5 | 16.55G (−4.5%) | 81.5G (−6.9%) | `fib` −15.7%, `tak` −20.1%, bootstrap −4.7% |

The five parts:

* the fill dropped;
* the poll folded into the room check;
* the frames array grown with the stack, so that its check goes;
* `lea` for the return address;
* the landing in line.

What was not prototyped would take more:

* the frame's address as a pointer, not an index times 40;
* trampolines for interpreted and top-level callers, so that a return
  tests nothing;
* the result returned in a register;
* a known call patched when its callee gets code;
* the closure kept in a register, so that `ENV` is one or two
  instructions.

The step after that is native frames: a return address in the frame, a
descriptor per return address, and one limit check that is also the poll.
That is what MLton does, at 17 instructions.

### Pointers in registers

Tier 2 keeps ints, words, chars, nullary constructors and reals in six
general and fourteen floating-point registers. It never keeps a pointer
there: the collector's roots are the frame's slots
([jit.md](jit.md), D10). A compiler's values and HOL's are mostly pointers.

**How much they are** (register uses weighted by how often each runs;
colouring with pointers allowed, E12):

| Workload | Pointer share of register uses | Served by a home today | ... with pointers, 6 homes | 10 homes | 14 homes |
|---|---:|---:|---:|---:|---:|
| the bootstrap | 63% | 34% | 87% | 89% | 89% |
| `boyer` | 92% | 6% | 90% | 90% | 90% |
| `logic` | 88% | 10% | 87% | 88% | 88% |
| `mlyacc` | 65% | 34% | 85% | 93% | 94% |
| `hamlet` | 63% | 36% | 84% | 89% | 90% |
| HOL, a slice | 86% | 13% | 88.5% | 90% | 90% |

So six homes would do, if pointers could have them.

* **The traffic.** Pointers loaded from and stored to their slots are 747M
  loads and 399M stores in the bootstrap. That is 6.4% of all its
  instructions, and HOL's slice is the same.
* **How long a home would last.**
  * 58 to 72% of pointer uses come with no safepoint since the value was
    last in a register, so a home saves the load.
  * There are 0.07 to 0.16 safepoints on the fast path per pointer use.
    Allocation and calls into C are safepoints only on their slow paths.

**A design that needs no maps.**

* A pointer home is written back to its tagged slot at every safepoint and
  reloaded after anything that may collect. The tags remain the map. In
  the fast path this costs nothing beyond what an int home already pays.
* A prototype of it, about 30 lines, passes the language suite with
  identical counts, at:
  * the bootstrap 6.5% fewer cycles (5.7% best-of-ten under load);
  * a list walk 39% fewer. A pointer carried round a loop no longer goes
    through store-to-load forwarding on its slot.

  Instructions barely move, so the gain is in the memory traffic.
* On the way the prototype found a latent bug: `string_order` loaded its
  arguments from homes into `rsi`, which is itself a home. M5 fixes it.
* Maps per return address are needed only with native frames and
  callee-saved registers (*The call*).

### Equality, strings and exceptions

The guesses of [hol4.md](hol4.md) are right in kind. Counted in a VM with
counters (E11):

| Workload | `poly_eq` calls | of which identical pointers | `ptr_eq` (exception match) | handlers pushed | raises |
|---|---:|---:|---:|---:|---:|
| HOL's kernel work | 40.1M | 37.7M (94%) | 13.6M | 25.6M | 4.86M |
| the bootstrap | 2.93M | 183K (strings 2.16M) | 4,263 | 110K | 4,263 |
| `tsp` | 160.4M | (158.3M on refs and arrays) | | | |
| `peek` | | | 200M | | |

**HOL's equality is not structural.** 94% of its `=` compare a pointer
with itself, mostly refs: `KernelSig.kernelid` is a `ref`, and
`Type.dom_rng`, `Portable.equal` and `Term.same_const` compare them. Each
such `=` today saves every register, calls `values_equal` in C and reloads,
for 25 cycles where 5 would do.

**What each costs today, and with a fast path in the JIT** (cycles per
operation, micro programs; E11):

| Operation | Today | With its fast path |
|---|---:|---:|
| `=` on identical pointers | 25.1 | 7.5 |
| `=` on refs | 26.7 | 4.2 |
| `=` on strings of 8 bytes | 40.4 | 18.1 |
| `String.<` (the generic primitive path) | 52.3 | 27.0 |
| `ptr_eq` (matching an exception) | 32.2 | 4.7 |
| a handler pushed and popped | 23.5 | 6.0 |
| a raise across one frame, packet and match | 71.0 | 40.3 (all prototypes) |

Matching an exception costs more than raising it. Five prototypes, each
with identical counts on the suites of tests/perf, 27 of MLton's programs
and every mode of `check-jit.sh`:

* (a) identity first in `=`;
* (b) `ptr_eq` in line;
* (c) short strings compared in line;
* (d) the handler pushed in line;
* (e) a fast path for a raise.

Together they gave:

* HOL's kernel work 5.6% fewer instructions and 3.7% fewer cycles;
* `peek` −32%, `tsp` −21%, `knuth-bendix` −22%, `logic` −13%, `lexgen` −10%,
  `boyer` −8% of cycles;
* the bootstrap −1.1% of instructions.

The raise's fast path did nothing on HOL. A REPL's raise mark or the
debugger's state made it bail, which a version to keep must handle.

**By type, in the middle end.** `=` at a ref or array type could become
`ptr_eq`, and `=` at `string` a string primitive. That covers `tsp`'s 158M
calls and most of HOL's. Equality functions per datatype, as MLton
generates, are not worth it here: structural calls are 1.2% of HOL's
`poly_eq` and 3.7% of the bootstrap's.

### Allocation

**Against MLton** (bytes allocated: Rune's `--count` against MLton's
`gc-summary` on the same programs; E15):

* The compiler compiling itself allocates 1.468 GB under Rune, and 1.095 GB
  when MLton's build of the compiler does the same compile: 1.34 times as
  much.
* On MLton's benchmarks the ratio runs:
  * 0.77 for `merge` and 0.99 for `mlyacc`;
  * 3.6 to 4 for `fft`, `barnes-hut` and `raytrace`;
  * 16 for `knuth-bendix`, 20 for `ratio-regions`, 31 for `ray`;
  * 1.2 million for `peek` and 366,000 for `imp-for`, where MLton allocates
    almost nothing at all.

**What is made, and who could avoid making it** (every object followed from
birth to death, by bytes; E14):

| Workload | The middle end alone: never leaves its function, or only through known calls | ... and functions specialised on the closures they are given | Only a JIT could: unknown calls | Escapes for good |
|---|---:|---:|---:|---:|
| the bootstrap (1.468 GB) | 28.8% | 28.2% | 0.0% | 43.0% |
| `fft`, `peek` | 100% | | 0 | 0 |
| `barnes-hut` | 77.9% | 8.2% | 0 | 13.9% |
| `raytrace` | 86.1% | 10.2% | 0 | 3.7% |
| `hamlet` | 39.9% | 42.9% | 0.0% | 17.1% |
| `lexgen` | 13.2% | 76.3% | 0.8% | 9.6% |
| `knuth-bendix` | 17.1% | 27.6% | 33.8% | 21.5% |
| `vliw` | 42.9% | 12.1% | 22.8% | 21.8% |
| `nucleic` | 50.3% | 2.0% | 6.7% | 40.8% |

So nearly all of what could go is the middle end's to remove. Across 28 of
MLton's programs, an allocation that only a JIT could remove is 0 to 0.8%
of the bytes, except in three:

* `knuth-bendix`, 34%;
* `vliw`, 23%;
* `nucleic`, 7%.

**MLton's passes that make the difference** (MLton with one pass dropped):

* flattening: `barnes-hut` allocates 39.6 MB with it and 158.5 MB without,
  `raytrace` 210 MB and 1.77 GB;
* contification: `peek` 1 KB and 640 MB;
* local refs: `imp-for` 728 bytes and 107 MB.

What Rune makes that MLton does not, in the code:

* `fft`'s `val (zr, kr) = if ... then (a, i) else (zr, kr)` makes a tuple at
  a join only to take it apart;
* `barnes-hut`'s `Vector3.subv` returns a record to callers that only
  select from it, and it is not inlined into its six callers;
* `peek`'s loop returns `SOME x` to a caller that cases on it at once.

A small object costs about 16 cycles to make and collect when it dies young
(E14).

### The bytecode, and the JIT's code for a body

What the middle end makes is not where the gap is for small functions.
`fib`'s register bytecode is 14 instructions with one known call per
recursion and no allocation. MLton's SSA for it has the same shape: a
compare, two calls, a subtraction and an addition with overflow checks
(E17). The JIT's code for a body has smaller faults of its own (E9):

* A comparison is not fused with its branch: `setl`, `movzx`, `lea`, `mov`,
  `cmp` and a jump, nine instructions where `cmp; jl` would do.
* Constants live in registers, not as immediates, and arithmetic goes
  through `rax` and `rcx`.
* `mod` by a constant is an `idiv` and two checks.
* `FIELD` tests `vm->checked` at run time, and tests the constructor's tag
  again after `JUMPIFNOTTAG` has.
* Allocation in line is 12 instructions, two of them read-modify-writes of
  the counters.

What the middle end leaves out shows on the programs that allocate (*Allocation*):

* the flattening of tuples returned by known calls, and of tuples at
  joins;
* contification of a loop called once;
* local refs as variables;
* functions specialised on the closures they are given.

### The Basis's own code

Some of MLton's benchmarks are 20 to 90 times MLton's cycles on Rune (E2),
far beyond what calls and allocation explain. Profiled, they spend their
time in the Basis Library's own code:

* **`vector-rev`** (65 times MLton's): `List.go`, `from_list` and
  `list_length` are 44% of its samples, and the collector 30%. The Basis
  builds and walks vectors through lists. `vector32-concat` and
  `vector64-concat` are 89 and 60 times.
* **`output1`** (37 times): `TextIO`'s output pushes an exception handler on
  every call (`TextIO.SI.guarded`, `vm_push_handler`), and implodes
  characters into strings.
* The other outliers have not been profiled: `checksum` 32, `string-concat`
  26, `imp-for` 25, `md5` 22 (`Word32` on 63-bit words), `matrix-multiply`
  21, `mpuz` 20, `peek` 19.

These are cheap to fix where they are, in `lib/basis`, and every engine
gains. They are ranked item 17, part of M5 (`TextIO`) and M8 (vectors).

### The collector, and IntInf

* **The collector's share of the bootstrap depends on how it is
  measured:**
  * 23% of the samples of a profile (11.2% minor collections, 12.1%
    major; E8);
  * about 19% in a busier run (E10);
  * 10% by `--stats`, which counts 340 ms of collection in 3.45 s, with
    391 minor collections and 284 MB promoted (E14).

  M1's profile should settle which parts `--stats` does not time.
  [garbage-collector-v3.md](garbage-collector-v3.md) holds what is left for
  the collector. Allocating less (*Allocation*) is this plan's part.
* **IntInf.**
  * HOL's `Arbnum` multiplication is 31 times Poly/ML's, and
    `intinf_fact` 36 times Poly/ML's.
  * But HOL's numerals are mostly symbolic. `EVAL FACT 150` takes 5.6
    times Poly/ML's time, the same factor as `SIMP_CONV`.
  * [gmp.md](gmp.md) is the roadmap for IntInf. It has M0 to M3 done on
    branch `gmp` (master has its M0), and this plan leaves IntInf there.

## What determinism costs

Rune's engines agree in output and in the three numbers of
`runevm --count`:

* the bytecode instructions executed;
* the bytes allocated;
* the objects allocated.

The brief asks what that costs, and whether it can cost less. Both parts
were measured.

### Counting instructions

**How it is counted.** The interpreter adds one per instruction. The JIT
adds a run's length with one `lea r15, [r15+k]` at the start of each
straight-line run (`runtime/register/jit/masm.c:1115`), and a run ends at
every primitive, whether or not it can raise. `r15` is reserved for the
count at every tier. No build turns counting off.

**What it costs** (E13). The figures compare a VM with counting compiled
out, against the same VM with it, on 18 workloads: the eight of
tests/perf, the bootstrap and nine of MLton's.

| | Without counting |
|---|---|
| machine instructions | −5.7% (geometric mean); −3.4% on the bootstrap, −2.7% on HOL's kernel work |
| cycles | −0.8% (geometric mean); −0.1% on the bootstrap, −1.1% on HOL |
| the code | 20,028 `lea`s, 80 KB of the bootstrap's 5.6 MB at tier 2 (1.4%) |

So on this machine the count is nearly free in time. Each `lea` adds to a
register that nothing reads in the loop, and an out-of-order core hides
it. What it costs is a register: `r15` as a seventh home would serve 1.4
more points of the bootstrap's register uses, 3.0 of `mlyacc`'s and 0.7 of
HOL's (E12, with pointers in homes).

**How it could cost less.**

* **Count per extended block, not per run.** A run need not end at a
  primitive that may raise if the raise's path corrects the count, as an
  exit from compiled code already does (`ms_exit`). That takes away 30% of
  the bootstrap's `lea`s, 45% of `fib`'s and 84% of the 30-register
  callee's (E13).
* **Wasmtime's fuel** adds a constant per basic block to a register that is
  saved at calls, and checks only at function entry and loop heads. It
  keeps its counts equal across its tiers by sharing one table of costs
  (*What the literature and the implementations say*).
* **Counting only when the count is read** would give `r15` back. The
  compiler itself reads the count through `Runtime.stats`, so whether a
  program reads it cannot be decided from its text: it needs a flag of the
  VM and a decision about what `Runtime.stats` then returns.

### Counting allocations

**The rule today.** The JIT removes no allocation ([jit.md](jit.md), D5 A),
and `check-jit.sh` and `check-register.sh` hold every engine to the same
bytes and objects. Boxes are already outside the count, because where a
box is made depends on the engine (`runtime/vm.h:350-357`). The middle end
does remove allocations, and since it runs before the bytecode is made,
every engine sees the same, smaller count.

**What the rule costs** (E14). Every object was followed from birth to
death in an instrumented VM, and classed by the furthest it went:

* never left the function that made it;
* passed to or returned through known calls only;
* passed to or returned through unknown calls, by where the closure came
  from;
* stored in the heap, raised, or returned further.

What only a JIT could remove is what goes through an unknown call to a
closure whose origin is not known statically. That is all the rule
forbids:

What the rule costs, in the last column, is estimated: the objects only
a JIT could remove, times 16 to 35 cycles an object.

| Workload | Removable by the middle end | Only by a JIT | What the rule costs (est.) |
|---|---:|---:|---:|
| the bootstrap | 57.0% of bytes | 0.0% (11 thousand objects) | about 0.003% of cycles |
| compile-sigs | 51.4% | 0.0% | about 0 |
| 25 of 28 of MLton's programs | | 0 to 0.8% | about 0 |
| `knuth-bendix` | 44.7% | 33.8% | 5 to 10% |
| `vliw` | 55.0% | about 23% | 24M to 53M cycles |
| `nucleic` | 52.3% | about 7% | 10M to 22M cycles |

So the rule costs nothing measurable on the compiler, and on HOL, which
the census could not run (its VM cannot restore images). The cost lands
on three of MLton's programs. What the
middle end leaves unremoved costs much more, in every engine (Track B,
*Allocation*).

**If a JIT ever removes allocations: the summed count.** The brief's idea
works, with two pairs of counters (E14b):

* **The program's counters** are what is allocated plus what was elided.
  They feed:
  * `--count`, `Runtime.stats` and images;
  * `--gc-log`;
  * the budgets and every oracle.

  An engine that elides an object adds its size there, as a constant per
  run, exactly as it adds instruction counts. The size is known when the
  code is compiled, and the counts stay exact at every point the runtime
  can see.
* **The heap's counters** are what was really allocated. They feed
  `--gc-stress`, the low-pause collector's pacing (`runtime/gc/cycle.c`)
  and `--stats`, which shows the elided objects beside the boxes.
* **Already engine-dependent.** Collections then come at different points
  in different engines. They do already, because of boxes.
* **What the oracles lose.** They would not see an elision that stops
  without the sum changing. The answer:
  * a `--no-elide` mode of `check-jit.sh`;
  * budgets on the heap's counters per engine (tiering is driven by
    counts, so it is deterministic);
  * a test that some object is elided.
* **Layouts.** Every object that does exist keeps the layout every engine
  shares, and an elided object counts with that layout's size.

## What the literature and the implementations say

Read for this plan in the papers (*References*: every DOI checked against
Crossref, and rr's report at DataCite) and in the sources under
`/home/ruud/reference`. Each line names
what it rests on. Where a paper was read only in its record or abstract,
*References* says so. The notes behind this section, with every file and
line, are kept with the plan's drafts (*Measuring*).

### Modules

* **Sharing is unification, and implementations do it once.**
  * SML/NJ instantiates a signature with Paterson and Wegman's linear
    unification (`smlnj/compiler/Elaborator/modules/instantiate.sml:4-31`).
  * MLton uses "disjoint sets to efficiently handle sharing ... copy
    signatures as dags rather than as trees"
    (`mlton/doc/guide/src/Elaborate.adoc:32-34`;
    `mlton/elaborate/interface.fun:790-815`).
  * MLKit builds one realisation from the classes of shared names
    (`mlkit/src/Common/EfficientElab/ElabTopdec.sml:189-298`).
  * The cost model is Tarjan's union-find (1975).
  * Rune re-realises the whole signature once per equation and per
    `where type` clause.
* **`where type` need not be expanded.** Leroy (POPL 1994): `with type`
  "can always be expanded before typing ... a typechecker would certainly
  avoid this expansion for the sake of efficiency". OCaml made signature
  substitution lazy in 4.14 (`ocaml5/Changes`, #10559;
  `typing/subst.mli:130-175`).
* **Functors are typed from a summary, not by re-elaborating the body.**
  * MacQueen and Tofte's semantics (ESOP 1994) re-elaborates a functor's
    body at each application. That is how Rossberg, Russo and Dreyer (JFP
    2014) describe it; only the record of the 1994 paper was read.
  * SML/NJ replaced that with an entity calculus: an application evaluates
    an entity expression (`evalent.sml:250-286`; Kuan and MacQueen 2010).
  * MLton elaborates a body once. An application *inside* another functor's
    body uses the functor's summary: it matches the argument and renames
    the result's generative types
    (`mlton/elaborate/elaborate-env.fun:4547-4720`, `functorClosure`).
  * Poly/ML types an application from the functor's result signature
    (`STRUCTURES_.ML:1442-1483`), and MLKit by matching against the
    functor's signature (`ElabTopdec.sml:397-425`).
  * In the formulation of Rossberg, Russo and Dreyer, an application needs
    one matching traversal plus a substitution.
* **Static interpretation is compatible with that.** Elsman (ICFP 1999):
  the ML Kit type-checks a functor once and generates code per
  application. On the Kit itself (about 87,000 lines), 6 of 138 functors
  were applied more than once, and the code grew by 10.9%. Rune's D1 of the
  incremental plan keeps static interpretation "for now to keep strict
  SML'97 semantics". The Definition does not require static
  interpretation; it requires typing by the functor's signature (rule
  54), which Rune's copies do not keep ([functors.md](functors.md)). Typing an application from a summary does not change
  what is generated.

### Types in a typed IR, and the exponential program

* **`exponential.sml` is the "toy" program of Shao, League and Monnier,
  "Implementing typed intermediate languages" (ICFP 1998).** It is easy to
  type in ML and blows up only in an IR that unfolds types into trees.
  * Their cure, in SML/NJ since 1997, has four parts:
    * every type hash-consed;
    * a normal-form flag and the free variables memoised in each node;
    * reductions done lazily and memoised;
    * one memoising fold as the only way to walk a type.
  * What it measured:
    * eXene's compile time fell by 72%;
    * the large benchmarks by 45% on average;
    * `toy` compiled in 0.11 s;
    * type-checking the IR after every phase cost nothing noticeable.
  * Naming types in the IR (TIL, direction 3 of
    [type-checker.md](type-checker.md)) still has to find the sharing. TIL
    found it with a CSE pass, "precisely the same machinery as
    hash-consing", run late and again and again.
* **Sharing alone is not enough.** Filliâtre and Conchon (ML 2006) made
  a normaliser of lambda terms 2.1 times slower with hash-consing alone
  (91.5 s to 195 s, in a third of the memory). With the normaliser's walks
  memoised in tables keyed by the nodes' integer tags, a run of 54 s took
  5.06 s.
  type-checker.md's prototype found the same: memory flat, time still
  doubling.
* **The implementations.**
  * MLton's IR types are hash-consed, with O(1) equality and memoised folds
    (`mlton/atoms/hash-type.fun:57-167`). Its elaborator memoises per
    union-find class (`type-env.fun:494-497,625-686`).
  * SML/NJ's FLINT types are hash-consed in weak tables, with the cells
    ordered without addresses (`FLINT/kernel/lty.sml:83-306`). Rune can
    have neither weak tables nor addresses, so its table must be keyed by
    numbers it gives out.
  * MLKit's lambda types are trees (`LambdaExp.sml:53-56`), which fits its
    running out of memory.
  * OCaml and Moscow ML drop types after checking.
  * Poly/ML's slowdown fits an occurs check with no visited set
    (`TYPE_TREE.ML:1984-2032`). That is a reading of the code, not traced.
* **Typability is DEXPTIME-complete** (Mairson 1990; Kfoury, Tiuryn and
  Urzyczyn 1990), so `--type-work` stays as a budget on inference.

### Calls, frames and stack maps

* **What a call costs elsewhere.** These are estimates read off each
  system's emitters (the notes with the drafts, *Measuring*), not
  measurements:

  | System | Call, entry and return of `fib` | How |
  |---|---:|---|
  | OCaml 4 | ~4 | `call`/`ret`, no stack check |
  | Poly/ML | ~5-6 | |
  | OCaml 5 | ~7 | a stack check |
  | MLton | ~12 | its own stack; a return is `jmp *-8(%rbp)` |
  | GHC | ~14-15 | |
  | Chez | ~16 | |
  | SML/NJ | ~20-25 | and a continuation record on the heap |

  Rune's tier 2 measures 82.5 (*The call*).
* **Keeping pointers out of registers across safepoints is the usual
  rule.**
  * MLton, Chez, GHC and Cranelift all do it. In Cranelift every non-tail
    call is a safepoint, and spilling is the producer's job
    (`cranelift/codegen/src/ir/user_stack_maps.rs:6-28`).
  * MLton puts in slots only the values live across a collection point
    (`backend/allocate-variables.fun:324-363`), and it coalesces heap
    checks (`backend/insert-checks.fun`, `limitCheckCoalesce` from line
    616).
  * Chez keeps a frame variable in a register between calls. Its
    allocation slow path never collects: it only sets a flag
    (`c/alloc.c:330-355`). So an allocation is not a safepoint there.
* **Pointers in registers, when they are, are found in one of three
  ways:**
  * a map per return address (OCaml's frame tables, OCaml 4's
    `asmcomp/amd64/emit.mlp:231-240`; HotSpot's oop maps);
  * scanning every word by its tag, with a mask saying which registers to
    scan (Poly/ML, `x86_dep.cpp:370-441`);
  * keeping them in slots across safepoints: Chez stores them at every
    call, Cranelift's producer spills them before each call.

  Rune's tags make the second and third possible without maps.
* **The cheapest call is the one the middle end removes.** That covers
  contification (Fluet and Weeks 2001), join points (Kennedy 2007; Maurer
  et al. 2017) and known calls. Appel and Shao (JFP 1996) put a stack
  frame at 5.4 instructions; "two instructions per frame is less than 2%
  of total execution cost".

### Exceptions

* **MLton, OCaml and Poly/ML cut the stack, and call no C.** SML/NJ
  allocates a continuation on the heap for each `handle`.
  * MLton keeps a handler as two words in the frame and the current one as
    an offset; installing it is a store and two or three instructions
    (`backend/implement-handlers.fun`, `backend.fun:716-758`). Raising is
    `stackTop = bottom + exnStack; jmp *(stackTop-8)`
    (`amd64-generate-transfers.fun:1069-1115`).
  * OCaml pushes a trap frame in 4 instructions and pops it in 2. A raise
    without a backtrace is 4 instructions, about 6 with the test for one.
    It calls C only to record a backtrace, behind a flag (OCaml 5's
    `asmcomp/amd64/emit.mlp:830-873`).
  * Poly/ML keeps the handler in a word of its thread state.
* **Matching an arm is a pointer compare**: of a `unit ref` per exception
  constructor in MLton (after a switch on the tag), of the constructor's
  block in OCaml.
* Ramsey and Peyton Jones (PLDI 2000) compare the four techniques. Stack
  cutting saves two pointers, against a `jmp_buf` of 6 to 84 words.

### Equality

* **Identity first.**
  * MLton: "deep equality always does an `MLton_eq` test first"
    (`doc/guide/src/PolyEqual.adoc:33`; `ssa/poly-equal.fun:32`).
  * SML/NJ tests `PTREQL` (`FLINT/trans/pequal.sml:397-399`), and Poly/ML
    tests identity for datatypes of more than one constructor
    (`TYPEIDCODE.sml:835-837`).
  * The test is sound for SML because `real` is not an equality type.
    OCaml's `compare` takes it, and its `=` cannot, because of NaN
    (`runtime/compare.c:141`).
* **By type.**
  * MLton generates an equality function per type (`ssa/poly-equal.fun`).
  * SML/NJ specialises to a depth of ten, and walks generically below
    that.
  * OCaml specialises immediate types (`translprim.ml:521-540`), and
    calls `caml_equal` for the rest.
* **Strings.** OCaml compares in a C call that allocates nothing: pointer,
  length, then words (`runtime/str.c:274-316`). Poly/ML compares in line
  with `REPE CMPSB`.

### Allocation

* **What unboxing gains.** Leroy (POPL 1992): symbolic code gains less
  than numeric code. "They benefit from having unallocated tuples to
  communicate with functions with several arguments", and from closures
  not allocated. MLton flattens argument tuples *and result* tuples
  (`ssa/flatten.fun:395`; multi-value `Return`, `ssa-tree.sig:110-127`).
  It also turns a local `ref` into a variable (`ssa/local-ref.fun`: the
  analysis at 421-443, the rewrite near 328),
  and removes useless fields and contifies.
* **Decide in the IR.** Peyton Jones and Launchbury (FPCA 1991) put
  unboxed types in the IR, so that boxing becomes an ordinary
  transformation. For Rune, that means deciding in Mid, where every engine
  then sees the same bytecode.
* **Escape analysis in JITs.**
  * Kotzmann and Mössenböck (VEE 2005): 3.8 of 5.3 million allocations
    removed on `mtrt`, 27.4% faster, 12% slower to compile.
  * Partial escape analysis (Stadler et al., CGO 2014): up to 58.5% fewer
    bytes and up to 33% faster.
  * Both need deoptimisation to rematerialise objects.
* **Removing allocations while keeping each accountable.**
  * OCaml's `comballoc` merges a block's allocations into one, and keeps
    each original size in the frame descriptor (`asmcomp/emitaux.ml:247-254`).
    Its memory profiler splits them back apart (`runtime/memprof.c:2059-2094`).
  * In HotSpot an eliminated object is allocated, and so counted, only if
    a deoptimisation rematerialises it (`runtime/deoptimization.cpp:1101-1170`,
    `realloc_objects`): the pattern to avoid.

### JIT tiers and inlining

* **Inlining in a JIT needs a map from machine pc to source frames** for
  backtraces and deoptimisation (Hölzle, Chambers and Ungar, PLDI 1992; in
  HotSpot, `ScopeDesc`). Rune does not speculate, so its inlining needs no
  deoptimisation. It does need a frame table for traces and handlers, which
  the middle end's inlining already keeps.
* **Copy-and-patch** (Xu and Kjolstad, OOPSLA 2021) chooses a template per
  operand location, register or stack. This is register allocation by
  template, as tier 2's homes are.

### The price of determinism

* **Wasmtime's fuel.**
  * It is a compile-time sum per basic block, added to an SSA variable
    that is flushed at calls (`crates/cranelift/src/func_environ.rs:545-659`).
    The check happens only at function entry and loop headers (`:527-536`,
    `:5176-5181`).
  * One cost table is shared by its compilers, and tests assert exact
    counts on Cranelift, Pulley and Winch (`tests/all/fuel.rs:567-597,650-692`;
    Winch is left out of some of the fuel tests).
  * Of the systems read, it is the only family that keeps counts equal
    across its own tiers by design.
  * It admits imprecision at trapping instructions (`:616-625`).
  * Epoch checks are "around a 10% slowdown"
    (`docs/examples-interrupting-wasm.md:47-48`), and epochs are "up to
    2-3x" faster than fuel "in some measurements"
    (`crates/wasmtime/src/config.rs:766-767`). No absolute number for
    fuel.
* **CoreDet** (ASPLOS 2010), in its "maximal" scheme, counts exactly with
  constants per basic block, flushed at merges and calls.
* **rr** (USENIX ATC 2017): no x86 retired-instructions counter is
  deterministic, so hardware counting cannot replace Rune's.
* **Elsewhere:**
  * Chez subtracts a tick at the entry of each procedure that calls and at
    each loop head, and checks every tick. Its timer defaults to 1000
    ticks.
  * Erlang counts a reduction per call and return in both tiers, but at
    different points.
  * LuaJIT's count hooks do not run inside traces.

## Constraints

These hold for every item, as [AGENTS.md](../../AGENTS.md) and the plans
before this one have them.

**The compiler and its output:**

* The compiler's sources stay in the language Rune accepts and build with
  every host compiler and with themselves
  ([building.md](../building.md)). Items 1, 7 to 12 and 15 of *The
  work, ranked* change the compiler.
* Every build of the compiler emits the same bytecode, and the bootstrap
  reaches its fixed point.
* A change of the elaborator keeps every error message. The prototypes
  were gated on the first line of every error test.

**The engines and their counts:**

* Every engine prints the same and counts the same (`--count`):
  `scripts/check-jit.sh` in every mode, `scripts/check-register.sh`. A
  change of the JIT that removes work removes none of what is counted.
  The JIT removes no allocation (D10).
* A change that moves `--count` re-measures the budgets
  (`tests/perf/run-perf.sh --update`, and `--stack --update`), the count oracle of
  MLton's set (`tests/perf/mlton-bench.txt`) and
  `examples/benchmarks/count-budgets.tsv`, quoting old and new in its
  commit. Items 10 to 12 move it.
* **The JIT's rules** (AGENTS.md, *runtime/register*):
  * the VM made exact before any call into C, and no heap pointer in a
    machine register across one. D6's homes are written back before such a
    call and reloaded after, which keeps this;
  * a store into an object through `ms_set_field`;
  * an emitter over the macro-assembler, never an encoder;
  * every change on x86-64 under both conventions and on aarch64
    (`make test-portability`).
* A change to `runtime/register` runs `make test-register-asan`, `make
  test-stress`, `make test-windows` and `make test-portability`. A change
  of the collector's roots (D5's clean watermark, D6's homes) runs
  `--gc-stress` and `--gc-verify` over the suites.
* **Traces stay observable.** An uncaught exception and `Runtime.trace`
  show every frame that is not a tail call. Inlining in the JIT, if it
  ever comes, keeps the inline frames the middle end's inlining keeps.

**Determinism:**

* `Runtime.stats` returns the same counts on every engine.
* An image saved by one engine restores on every other.
* The collector's points may differ between engines, as they already do
  because of boxes.

## Decisions

Each decision gives the options, the evidence, and a recommendation.
"Measured" means a prototype measured for this plan; "estimated" means
reasoned from measurements.

The owner took every recommendation on 2026-10-12, with one addendum: D7's
option C is to be benchmarked too, and implemented if it shows gains. Each
decision records it.

### D1. Workloads and yardsticks

**Decided (2026-10-12): as recommended.**

What the milestones are measured on, and against what.

* **A.** The compiler compiling itself; MLton's compiler compiled by Rune;
  HOL4's theories and kernel work; tests/perf; MLton's benchmark set. The
  yardsticks are MLton 20241230 and Poly/ML 5.9.2, side by side on this
  machine.
* **B.** As A, with `examples/benchmarks` as well.
* **C.** tests/perf alone, as before.

**Recommendation: A**, with `examples/benchmarks` timed at M1 and M10.

* **Counts carry the targets.** Every milestone target is a count:
  `runevm --count`, `instructions:u` or callgrind. Under WSL2, on a busy
  host, two runs of the same binary differ by up to 40% in cycles.
  Instructions repeat to the instruction, so a change of instructions is
  real.
* **Cycles are indications.** They are reported as the best of several
  runs, and as ratios measured in one session.
* **Poly/ML is the yardstick for HOL,** because HOL runs on it. MLton is
  the yardstick for everything else.

### D2. Sharing and `where type`

**Decided (2026-10-12): as recommended.**

* **A. Resolve each run of sharing specifications, and each chain of
  `where type`, as one realisation by union-find, with realisations that
  keep what does not change** (E20). Measured: MLton's units −62% of
  instructions, its signature files 81.4 s to 2.6 s, `BASIS_EXTRA` 40
  times faster, every output identical.
* **B. Signatures as MLton's interfaces,** shared names as union-find
  classes all the way through, copies memoised.
* **C. SML/NJ's entity calculus.**

**Recommendation: A.** After A, instantiation is under 3% of elaboration;
B and C would change the representation for little more. The path that
allocates where nothing changes is to be made free of allocation (one
regression of 20% measured).

### D3. Functors

**Decided (2026-10-12): A, extended, now; B to be revisited.**
[functors.md](functors.md) holds everything learned for that.

What the Definition says decides most of it. An application is typed from
the functor's signature (rules 86, 54, §5.4), never from its body again,
and evaluates the body afresh at run time (rule 154). So compiling once or
per application is the implementation's choice; typing by rule 54 is not.

Rune's applications that make code are typed from their elaborated copy,
which sees the actual argument. So Rune accepts a program the Definition
rejects (functors.md, *What the Definition says*). HaMLet, SML/NJ,
Poly/ML, Moscow ML and MLKit reject it; Rune and MLton accept it.

* **A, extended. Static interpretation for code, the functor's signature
  for types (MLKit's design).**
  * Every application is typed from the functor's signature: its
    parameter matched, its generated datatypes renamed apart. That
    includes applications that make code.
  * A copy of the body is elaborated only to make each application's code.
    It is safe because the body was checked against the abstract
    parameter at its declaration.
  * In units, the export basis carries the functor's signature, and a
    use of a functor depends on its signature's fingerprint for types and
    on the body's hash for code. Today it depends on its unit's identity
    alone.
  * The prototype of the part that types checks from a summary (E21)
    measured −19.5% of instructions, with `main.fun` from 9.2 s to 0.01 s
    and identical whole-program output.
* **B. Functors as functions,** compiled once and typed from their
  signature, as SML/NJ does.
  * It gives separate compilation: a client depends on the signature only.
  * It costs code quality, unless the whole-program build specialises each
    application from the cached Mid (a link-time expansion).
  * It changes Translate and Lambda (F-ing modules is the recipe).
* **C. As now.**

**Recommendation and decision: A, extended, with matching made cheaper.**

* Re-elaborating the copies that make code stays, as in MLton and MLKit.
  On nested functors MLton is exponential as well.
* What is left of `main.sml`'s 22.7 s is matching. The fast path of E20 for
  equal schemes, and a cheaper `checkEnrich` and `mergeInfo`, are for that.
* B is the answer to the incremental plan's risk 3 if functor-heavy
  projects (HOL4 first) show the cost of recompiling every application of
  a changed body.

### D4. Types in the IR

**Decided (2026-10-12): as recommended.**

* **A. `Ty.ty` hash-consed throughout**: an abstract type, smart
  constructors, an integer identity per node, every walk memoised on it.
  That covers renaming, substitution, the free variables, the
  specialisation key and equality. This is SML/NJ's recipe for exactly
  this program.
* **B. Types named once per function** (a `let` of types). MidText needs an
  abbreviation for big types anyway. Shao, League and Monnier found that
  this route pays the cost of hash-consing anyway.
* **C. Keep `--type-work` as the limit.**

**Recommendation: A**, after D2 and D3. Partial versions were measured and
do not work: memoising `fromTypes` halves the time and memory still grows
fourfold every two applications; partial hash-consing is slower. Ordinary
programs gain nothing measurable, so this milestone is for the
pathological program, and for the exponential cases of nested functors.
`--type-work` stays as a budget on inference, which is DEXPTIME-complete.

### D5. The call

**Decided (2026-10-12): as recommended.**

What a call at tier 2 should be. Today `fib` spends 82.5 machine
instructions and 31 cycles per call, against 17 and 8.6 in MLton. Calls and
returns are 31% of the bootstrap's instructions and 39% of HOL's (*The
call*).

* **A. Lean frames on the VM's stacks.** Keep the frame record and the
  register frame, and take out what the measurements found:
  * the fill at entry: the stack kept clean above the stack pointer;
  * the poll folded into the room check;
  * the frames array grown with the stack;
  * the landing in line;
  * `lea` for the return address;
  * the frame's address as a pointer;
  * trampolines for interpreted and top-level callers, so that a return
    tests nothing;
  * the result in a register;
  * a known call patched when its callee is compiled;
  * the closure in a register.

  The first five of these were prototyped together at 71.5 instructions
  per call (−13%), with the bootstrap 4.5% fewer instructions and HOL
  6.9% fewer. Deoptimisation,
  traces, images and the debugger keep working as they do.
* **B. Native frames.** The return address in the frame, a descriptor per
  return address (which slots hold what, the bytecode pc for traces), one
  limit check that is also the poll, and `call` and `ret`, or MLton's
  `jmp *-8(%rbp)`. This is what MLton, OCaml and Poly/ML do, at 10 to 17
  instructions. It changes the protocol between the interpreter and
  compiled code, deoptimisation, traces, the debugger and images, and it
  needs maps (D6).
* **C. Leave it**, and gain elsewhere.

**Recommendation: A now, and B as a gated milestone after it.** A is local
to the emitters (`emit.c`, `compile.c`, `masm.c`) and measured. B is where
parity is, but it is the largest change in this plan; A's parts are not
wasted by it (the fill, the poll and the patching carry over).
Targets for A:

* a `fib` call at most 50 instructions and 8 stores;
* a closure call at most 25 instructions (52 today);
* the bootstrap's calls and returns at most 18% of its instructions (31%
  today).

Targets for B: at most 25 instructions and 10 cycles for a `fib` call.

### D6. Pointers in registers

**Decided (2026-10-12): as recommended.**

* **A. Pointer homes written back to their tagged slots at every
  safepoint.** The tags remain the map; a home is reloaded after anything
  that may collect, as int homes are already written back and reloaded at
  calls. No maps, no change to the collector. Prototyped in about 30 lines:
  the bootstrap −6.5% of cycles, a list walk −39%, identical counts.
  Register uses served by a home go from 6-36% to 84-90% on every
  workload measured. It needs a boxing path for reals and 64-bit ints moved
  into a home of any type, and a `--gc-stress` check that slots and homes
  agree.
* **B. A save area with a mask per safepoint.** Adds little to A, since
  safepoints are only on slow paths.
* **C. Maps per return address**, as OCaml's frame tables. Needed only with
  native frames and callee-saved registers: with D5 B.

**Recommendation: A in the homes there are** (six general ones on x86-64,
twelve on aarch64): ten would add at most 8 points on two workloads
(E12). C comes with D5 B. Target: the
bootstrap's pointer loads from slots from 747M to at most 300M.

### D7. Runtime calls in line, and equality by type

**Decided (2026-10-12): A, then B, as recommended; and C benchmarked as
well, and implemented if it shows gains** (the owner's addendum).

* **A. Fast paths in the JIT.** Each keeps the count:
  * identity first in `=`: an immediate against a pointer is false, two
    refs or arrays compare by address;
  * `ptr_eq` in line;
  * short strings compared in line;
  * the handler pushed in line;
  * a raise that unwinds in compiled code.

  Prototyped with identical counts: HOL's kernel work −5.6% of
  instructions, `peek` −32%, `tsp` −21%, `knuth-bendix` −22% of cycles.
* **B. Equality by type in the middle end.** At a ref or array type, `=`
  becomes `ptr_eq`; at `string`, a string primitive; matches on string
  constants a switch on the length. Every engine gains, and the count of
  bytecode instructions is unchanged (one primitive for one).
* **C. Equality functions per datatype**, as MLton generates. Structural
  equality is 1.2% of HOL's `poly_eq` and 3.7% of the bootstrap's, so the
  counts predict little gain; the owner asked for it to be measured.

**Recommendation: A, then B.** C was recommended against on the counts.
The decision adds it as a benchmark: built and timed after A and B, and
kept if it gains.

**C, benchmarked (2026-10-12): kept, opt-in.** Built on B, C gains a
little where structural equality is frequent and costs the compiler a
little everywhere (*M5*, D7 C as built): HOL's kernel work −0.49% of
machine instructions, `boyer` −2.2% (−4.4% with A's prototypes), `mlyacc`
−1.1%, the compiler compiling itself +0.44% of instructions and +1% of
code. The owner kept it as an option: the pass `equality`, which `-O2`
runs and `-O1` does not (`-O2` was `-O1` until then), so that the default
compiler, its bytecode and the limit of `--equality-work` stay as they
were. Targets:

* `poly_eq` that reaches C at most 5% of its calls (99.8% on HOL today);
* `ptr_eq`, a handler's push and `String.<` never on the generic path of a
  primitive;
* HOL's kernel work at least 5% fewer instructions.

### D8. Allocation: the middle end, or the JIT

**Decided (2026-10-12): as recommended.**

* **A. The middle end.** In the order of what they gain (E14, E15):
  * tuples flattened at joins;
  * small leaves inlined, and tuple results of known calls flattened;
  * loops called once contified, with known cases on what they return;
  * local refs as variables;
  * functions specialised on the closures they are given (the Basis's
    iterators, `IntTable`, the readers of `StringCvt`).

  Everything removed this way is removed for every engine, and the counts
  stay exact: the budgets move once.
* **B. Escape analysis and scalar replacement in the JIT.** It needs
  inlining in the JIT, which this plan does not propose, and the summed
  count (D10). It reaches what is passed
  through unknown calls: 0.0% of the bootstrap's bytes, 0 to 0.8% of 22 of
  25 of MLton's programs.

**Recommendation: A.** jit D5 A (no allocation removed by the JIT) stands.
Targets, by `--count` on every engine:

* the bootstrap's bytes from 1.468 GB to at most 1.10 GB, what MLton's
  build of the same compiler allocates;
* `fft` −75%, `barnes-hut` −60%, `raytrace` −70%;
* `peek` and `imp-for` to about nothing;
* on MLton's programs, what E15 projects: no more than MLton but for
  IntInf, `tensor`, `knuth-bendix`, `ray` and `hamlet`.

### D9. Counting instructions

**Decided (2026-10-12): as recommended.**

* **A. Keep it as it is.** It costs 0.8% of cycles (E13).
* **B. Count per extended block**, with corrections on the paths that
  leave it: 30% fewer `lea`s in the bootstrap. A part of D5 A, since it
  touches the same emitters.
* **C. Count only when asked**, and free `r15`. Needs a flag and a decision
  about `Runtime.stats`; +1.4 points of the bootstrap's register uses.

**Recommendation: A, with B folded into D5 A's work.** C is not worth the
change of semantics today. Revisit it if D6 runs short of registers.
Determinism stays as it is.

### D10. Exact counts of allocation

**Decided (2026-10-12): as recommended.**

* **A. Keep them exact and the same on every engine.** It costs, by
  estimate (E14), about 0.003% of the bootstrap and nothing measurable on
  25 of 28 of MLton's programs. It costs 5 to 10% of `knuth-bendix`, and
  tens of millions of cycles in `vliw` and `nucleic`.
* **B. The summed count** (allocated plus elided, with the heap's own
  counters apart; *What determinism costs*). Only needed with D8 B.

**Recommendation: A.** B is designed and kept in this plan for the day a JIT
removes allocations.

### D11. `runeopt`

**Decided (2026-10-12): B, as recommended.** Whether to retire `runeopt` (C)
stays open.

`runeopt` translates the stack bytecode to native code. The owner kept it
in heap-layout's D11, against a recommendation to retire it. Measured
here (E1), its code against tier 2's, in cycles:

| | `runeopt` | tier 2 |
|---|---:|---:|
| the bootstrap | 10.8G | 11.3G |
| `fib` | 262M | 240M |
| `word_bits` | 147M | 70M |
| `real_nbody` | 417M | 177M |

So `runeopt` is level with tier 2 on code that calls, and behind on
numbers.

* **A. Keep it as it is.** Every change of D5 to D8 that touches code
  generation is made in it too, or it falls behind.
* **B. Keep it, but frozen.** It keeps its tests, but this plan's
  milestones do not carry their changes into its templates. Its gap to
  tier 2 grows.
* **C. Retire it**, as heap-layout's D11 recommended.

**Recommendation: B for this plan's milestones**, and the owner decides C.
The middle end's work (D7 B, D8) reaches it anyway, since it changes the
bytecode.

### D12. The order of the two tracks

**Decided (2026-10-12): as recommended.**

The tracks touch different code: the front end on one side; the JIT, the
runtime and the middle end on the other. They can go in parallel, on
branches of their own.

**Recommendation:**

1. M1 (measure) first. Its tools are what every target is checked with.
2. Then the cheap measured wins of each track: M2 (signatures) and M5
   (runtime calls in line).
3. Then M6 (the call) and M7 (pointers in registers), which share the
   JIT's emitters, and M3 (functors).
4. Then M8 (allocation in the middle end) and M4 (types).
5. M9 (native frames) is gated on what M6 and M7 leave.

## The work, ranked

Ranked as the plan of 2026-09-24 ranked its items: a smaller blast radius
or a higher gain goes first. Each is weighed by the work, by the complexity
it leaves behind, and by whether it still matters at parity.

The columns:

* **Gain** is *measured* (a prototype for this plan, identical output) or
  *est.* (reasoned from the measurements).
* **At parity** is one of:
  * *stays*: as useful once tier 2 calls and keeps pointers as native
    code does;
  * *subsumed*: native frames (M9) would do it anyway;
  * *fades*: only until then.
* **Counts** is one of:
  * *same*: `--count` does not move;
  * *move*: it moves the same on every engine, and the budgets are
    re-measured once.

| # | Item | Gain | Blast radius | Work | Complexity left | At parity | Counts |
|---|---|---|---|---|---|---|---|
| 1 | Sharing and `where` in one realisation (D2) | measured: MLton's units −62% of instructions; signature files 81.4 s to 2.6 s | `src/elab` (sigmatch, elaborate, types, env) | M, ~400 lines | union-find classes during a signature | stays | same |
| 2 | Identity first in `=`, `ptr_eq` in line (D7) | measured: HOL kernel −3.7% / −1.0% of instructions; `tsp` −20%, `peek` −26% of cycles | `emit.c`, `masm.c` | S, ~80 lines | none | stays | same |
| 3 | The handler pushed in line, a fast raise (D7) | measured: `knuth-bendix` −22% (all five); HOL needs the REPL's case handled | `emit.c`, `runtime.c` | S, ~100 lines | a second path for a raise | stays | same |
| 4 | Short strings compared in line; `String.<` not generic (D7) | measured, beyond item 2's identity test that it includes: `lexgen` −6.6%, `mlyacc` −7.8% of cycles; HOL about nothing more | `emit.c` | S-M, ~150 lines | none | stays | same |
| 5 | The call made lean: no fill, poll in the room check, frames grown with the stack, landing in line (D5 A) | measured: `fib` 82.5 to 71.5 instructions; bootstrap −4.5%, HOL −6.9% of instructions | the JIT's emitters, the collector's clean watermark | M, ~300 lines | a clean watermark for the stack | subsumed in part | same |
| 6 | Pointers in the homes there are (D6 A) | measured: bootstrap −6.5% of cycles, a list walk −39% | `compile.c`, `masm.c` | M, ~200 lines with the boxing path | homes that may move | stays | same |
| 7 | Functors typed from their signature, copies only for code (D3, extended A) | measured for checks: −19.5% of instructions; `main.fun` 9.2 s to 0.01 s; fixes a deviation from rule 54 | `src/elab`, the units' files | M, ~300 lines | summaries per body; replayed counters | stays | same |
| 8 | MidCanon's quadratic | measured: nested functors 20.3 s to 0.88 s | `src/core/midcanon.sml` | S, 20 lines | none | stays | same |
| 9 | Equality by type in the middle end (D7 B; C benchmarked, kept if it gains) | est.: `tsp`'s 158M calls and HOL's ref compares to `ptr_eq` | `simplify.sml`, a string primitive | S (C: M) | none (C: an equality function per datatype) | stays | same |
| 10 | Tuples flattened at joins and from known calls; small leaves inlined (D8) | est.: `fft` −75%, `barnes-hut` −60%, `raytrace` −70% of bytes | Mid passes | M-L | multi-value returns in Mid and Low | stays | move |
| 11 | Contification and local refs (D8) | est.: `peek`, `imp-for` to about nothing | Mid passes | M | a contification pass | stays | move |
| 12 | Functions specialised on the closures they are given (D8) | est.: up to 28% more of the bootstrap's bytes removable | `simplify.sml` (its specialisation) | M | code growth to budget | stays | move |
| 13 | The rest of the call: frame as a pointer, trampolines, result in a register, patched known calls, closure in a register (D5 A) | est.: `fib` to at most 50, a closure call to at most 25 | the JIT, the driver | M-L | trampolines for interpreted callers | subsumed in part | same |
| 14 | Counting per extended block (D9 B) | est. from the code dump: −30% of the `lea`s; about 0% of cycles (the count costs 0.8%) | `compile.c`, `ms_exit` | S | corrections on the leaving paths | stays | same |
| 15 | `Ty.ty` hash-consed (D4) | measured partly: partial versions do not suffice; est.: `exponential` flat | `src/core/ty.sml` and every walk | L | an abstract type with identities | stays | same |
| 16 | Native frames (D5 B, D6 C) | est.: `fib` at most 25 instructions and 10 cycles; most of HOL's call cost | the JIT, the interpreter's protocol, deoptimisation, traces, images | XL | frame descriptors per return address | stays | same |
| 17 | The Basis's hot paths: vectors without lists, `TextIO` without a handler per call | est.: `vector-rev`, `vector*-concat` and `output1` are 37 to 89 times MLton's cycles today | `lib/basis` | S-M | none | stays | move |

Item 17 came from the last measurements (E2). By blast radius and gain it
belongs beside items 2 to 4.

## The milestones

Each milestone ends with every suite green and its targets measured with
M1's tools. The prototypes behind them are kept with the drafts (*Measuring*).

### M1. Measure (S-M)

* **The JIT's code dumped**, with a role per machine instruction
  (`runevm --jit-dump=DIR`; prototype B1-jit-dump). A perf jitdump too, so
  that `perf annotate` works on compiled code.
* **`--pass-stats` made complete.** Every stage the compiler spends time
  in is timed, so that the stages add up to the compile's processor time:
  * MidCanon and Emit, which it does not show today (8% and 5% of the
    compiler compiling itself, E24);
  * whatever else a profile finds outside the stages;
  * a test holds the stages' sum to the total, within a margin.
* **The elaborator's time and counters per top-level declaration**
  (prototype A-e18-elab-stats), behind a flag of `--pass-stats`.
* **`make perf`, `perf-check`, `bench` and `scripts/perf-cycles.sh` on the
  register VM by default**, with the stack VM a configuration of its own.
  Today `make bench`'s configuration `rune:new` passes `--jit=off`
  (`scripts/measure-benchmarks.sh:252`), so it times the interpreter, not
  what Rune ships.
  `perf-cycles.sh` gets a configuration for Poly/ML.
  `scripts/perf-groups.awk` learns the generational collector's functions
  and `jit1:`/`jit2:`.
* **HOL's measurements as scripts in the tree** (from the drafts'
  `hol-theory.py` and `hol-kernel.sh`), and the setup of MLton's sources
  for `scripts/perf-units.sh`.
* **New budgets in tests/perf** (E19's generated programs; the budgets are
  their counts plus 10%):
  * sharing: 200 specs shared 16 ways, and nested;
  * a chain of `where type`;
  * a signature of 2,000 specifications;
  * a functor applied 80 times;
  * nested functors;
  * `exponential.sml` at 18.
* **`docs/performance.md` re-timed** on the register VM, the 8-byte value
  and the generational collector.

**Done when:** the tools are in `make check` where they can be, and
*Where we are* can be measured again with one command per table.

**Done so far** (2026-10-12, branch `perf-m1`, the commits "... (performance
M1)"):

* **`--pass-stats` complete.** Every stage is timed by the process's
  processor time from its start, and the output ends with
  `total: T s processor time, S s in the stages (P%)`. The new stages:
  `startup` (before the compiler's code runs), `lex` and `select` (the
  input files lexed, the libraries' files chosen), `midcanon`, `emit`, and
  `stats` and `checks` (the sizes it counts, `--lint` and the dumps).
  `tests/compiler` holds the stages to the total within 2%.
  * The compiler compiling itself: 3.646 of 3.649 s at tier 2, 2.419 of
    2.420 s on MLton's build; with `--units`, 99.0%.
  * At tier 2 the new stages take: `midcanon` 0.30 s (9%), `emit` 0.10
    s, `lex` 0.09 s, `select` 0.07 s, `stats` 0.07 s, `startup` 0.02 s.
    MLton's profiler (`-profile time`) finds nothing else outside them.
* **The timing targets on Rune as shipped** (`bin/rune` and
  `bin/runevm`, tiering up to tier 2):
  * `make perf-check`: `tests/perf/*.budget` are its counts;
    `run-perf.sh --stack` holds the stack VM to `tests/perf/stack`.
  * `make perf` and `make bench`: `rune` is Rune as shipped in a timing
    run (`run-matrix.sh --perf`, `--timing`), the stack VM `rune:stack`;
    `measure-benchmarks.sh` no longer passes `--jit=off`.
  * `scripts/perf-cycles.sh`: `rune` is Rune as shipped, the stack VM
    `stack`, and `polyml` is Poly/ML's build (the program run from
    `main`, its `CommandLine` shadowed inside a `local`). Every build of
    the compiler makes the register bytecode.
  * `scripts/perf-groups.awk` knows the generational collector (its
    minor and major work apart) and the tiers of the JIT's code.
* **HOL4 and MLton as scripts:** `scripts/hol-theory.py` and
  `scripts/hol-kernel.sh` (with `hol-kernel.sml`) take a built HOL4 tree
  as argument, never write into it, and give a Rune-built one a cache of
  units of their own; `scripts/setup-mlton.sh` makes MLton's sources at
  `5fe943391` ready for `scripts/perf-units.sh --mlton` and
  `scripts/gc-eval.sh`.
* **The module language's budgets** (`tests/perf/compile-*.budget`, made
  by `tests/perf/gen.py`, on Rune as shipped). Today's counts, the same
  as E19's; the budgets are 10% above them:

  | Budget | Program | Instructions |
  |---|---|---:|
  | `compile-share` | 200 specs shared 16 ways, type-checked | 2,369M |
  | `compile-sharenest` | the same, nested (MLton's shape) | 2,841M |
  | `compile-where` | a chain of 400 `where type` on 1,000 specs | 326M |
  | `compile-sig` | a signature of 2,000 specs | 876M |
  | `compile-funsig` | a parameter of 200 specs, matched 40 times | 35.1M |
  | `compile-funapp` | a functor of 40 declarations applied 80 times | 197M |
  | `compile-funnest` | nested functors, depth 8, two applications each | 791M |
  | `compile-expo` | `exponential.sml` at 18 | 82.6M |

  The first five are type-checked only, the last three compiled; M2 to M4
  tighten them.
* **Poly/ML's slowdown** is its collector at its initial heap, not a
  commit (*Where we are*, *The compiler compiling itself*): its builds now
  start with a heap of 1 GB.
* **`docs/performance.md` re-timed** on Rune as shipped, with these tools,
  on 2026-10-12 at a load of 20 to 33: its tables lead with instructions
  and with ratios to MLton and Poly/ML measured in the same session, and
  give seconds as indications. The ratios agree with *Where we are*
  (`examples/benchmarks` 5.1 times MLton by geometric mean, against E3's
  5.2; the compiler compiling itself 4.6 times the instructions of MLton's
  build, against E4's 4.6). The seconds, 1.5 to 2.5 times a quiet
  machine's, are M10's to take again, with `xc1`, which was not timed.

### M2. Signatures (M)

D2 A: the prototype of E20 made a change of the tree. It also makes the
path that allocates where nothing changes free of allocation.

**Targets:**

* MLton's 606 units type-checked by MLton's build in at most 180G
  instructions (476G today);
* `BASIS_EXTRA` in at most 0.05 s (1.26 to 1.54 s today);
* the budgets for sharing, `where` and big signatures met;
* every output byte for byte the same.

### M3. Functors (M)

* D3 A, extended ([functors.md](functors.md)):
  * every application typed from the functor's signature (rule 54), with a
    copy of the body elaborated only for each code-producing application's
    code;
  * the counters replayed, and the gate of [functors.md](functors.md), *A
    contradiction in M3, found while building it*: the whole program's
    output byte for byte the base's; units' code the same with their
    identities masked; a build through the cache the same as a fresh one;
    a functor's body changed and not its signature leaving the applying
    units' interface files the same; the versions of the cache and of unit
    files bumped. Unit files cannot stay the same as before, since M3 adds
    the functor's signature to the export basis and a check no longer
    records the usages of the applied body;
  * the functor's signature in the export basis;
  * a use of a functor depending on the signature's fingerprint for types
    and on the body's hash for code;
  * the equality program of functors.md rejected, with a test, and
    `docs/language.md`'s row for functors made true.
* Matching made cheaper: the fast path for equal schemes, `checkEnrich`
  and `mergeInfo`.
* MidCanon's quadratic.

**Targets:**

* MLton's units type-checked in at most 100G instructions;
* MLton's compiler compiled by Rune at tier 2 with elaboration under
  250 s: 795 s on 2026-10-11 on a busy machine, 611 s quiet. Estimated
  two ways:
  * the prototypes' 41.4 s on MLton's build, times tier 2's 4.5 to 5.3
    times MLton's build, is 186 to 219 s;
  * 611 s divided by the fivefold drop in instructions is 122 s.
* the functor budgets met;
* MLton's sources, HOL4, the Basis libraries of xc2 and every suite still
  compile: none may rely on the equality leak that MLton also has.

### M4. Types shared (L)

D4 A: `Ty.ty` hash-consed throughout, every walk memoised.

**Done when** type-checker.md's measure is met:

* `exponential.sml` passes `tests/external/run-mlton.sh` at `-O0` to
  `-O2`, with `--lint` and `--mid-roundtrip`;
* its line is gone from `mlton-skip.txt`;
* a tests/perf budget holds on a program of some 20 applications (M1 has
  one at 18);
* the translation's share of `--type-work` is dropped, or set by what the
  compiler then does.

This plan adds one target: a run at 32 applications flat in time and
memory, as MLton's, SML/NJ's and Moscow ML's are.

**As built (2026-10-19).**

* `Ty.ty` is abstract (`Ty.Node`): a node is its number, its hash, its
  size as a tree (to a million), its generic variables (in the order a
  walk from the left meets them) and its view. `Ty.view` shows it;
  `Ty.gen`, `var`, `con`, `tuple`, `arrow` and `exnCon` make it, each
  looking in the bucket of its hash for a node of the same constructor,
  numbers and parts -- a type name by its stamp, not its name -- and
  making a view only for a new node. The table has no more nodes than
  buckets and doubles; it is never emptied (Rune has no weak tables), so
  a node lives as long as the compile. The hash is in words, masked to 30
  bits, so it is the same on every host, though nothing depends on it:
  the numbers are given in the order nodes are made.
* Equality is of numbers (`Ty.equal`), and so is Simplify's key of a type
  (`tyKey`); `Ty.gens` and `Ty.size` are fields; `Lift.gensOfTy` and
  ToMid's `gens` read the field.
* `Ty.subst`, `Ty.match`, MidCanon's renaming (one table for a whole
  rename) and MidText's printing are memoised on numbers; `subst` and
  `match` walk a type of at most `Ty.smallType` (64) nodes as a tree,
  which makes nothing and is as quick. `Ty.fromTypes` converts a type of
  at most 64 nodes as a tree, and a bigger one with each bound cell of
  more than 64 nodes converted once (an association list: cells have an
  identity but no order).
* MidText writes a type of more than 1000 nodes as a tree once, at the
  head, as `(type %N TYPE)`, after its parts', and `%N` where it is;
  `MidText.parse` reads them (`--mid-roundtrip`). `Ty.toString` and
  Lambda's dump write a type of more than 100,000 nodes by its size.
* `UnitMid` (version 3) writes a type met again as a reference to the
  first (byte 6 and its number), so that a cache entry is as small as the
  shared type. `UnitBasis` writes types as trees as before, so that the
  `.rbi` files are unchanged.
* The translation's `--type-work` stays, set by what the conversion does
  (type-checker.md, *Since performance M4*).

### M5. Runtime calls in line (S-M)

* D7 A, from the prototypes:
  * identity first in `=`;
  * `ptr_eq` in line;
  * strings of up to 16 bytes compared in line, with the slow path for
    longer ones redone (it was 8 cycles worse);
  * string order of up to 8 bytes in line;
  * the handler pushed in line;
  * a raise that unwinds in compiled code, working with the REPL's raise
    mark and the debugger.
* D7 B, equality by type in the middle end.
* D7 C, equality functions per datatype in the middle end, as MLton's
  `poly-equal` pass makes them:
  * built after A and B, and benchmarked on HOL's kernel work, the
    bootstrap and MLton's set (`boyer`, `logic`, `mlyacc`, where
    structural equality is most frequent);
  * implemented if it shows gains over A and B; otherwise the result is
    recorded here and it is dropped.
* `TextIO`'s output without a handler per call (ranked item 17;
  `output1`).
* **The bug E12 found:** the emitter of `string_order` loads its arguments
  from their homes into `rsi` and `rdx`, and `rsi` is itself a home. It is
  latent today, since strings never have homes, and becomes live with M7.
  It is to load them from their slots, with a test that fails without the
  fix when pointers have homes.

**Targets:**

* HOL's kernel work at least 5% fewer instructions;
* `poly_eq` reaching C on at most 5% of its calls;
* `ptr_eq`, a handler's push and `String.<` never on the generic path of a
  primitive;
* `--count` unchanged on every program.

**D7 B as built (2026-10-12).**

* `Simplify` makes `=` of a type what the type says: `imm_eq` as before
  (M11); `ptr_eq` for a ref, an array, an array of bytes or of reals, and
  where one side is a nullary constructor, which no value in the heap
  equals (`l = []`, `x = NONE`); `string_eq` for strings. `string_eq` is a
  new primitive: its C, a case in the loop's `fastprim.h`, and in the JIT a
  call of a lean helper, as `string_order` has. `ptr_eq` stays a generic
  primitive in the loop and the JIT until A puts it in line.
* `MatchComp` finds a value among six or more strings written as constants
  by its length (`string_size`, tests of `imm_eq`, halved by `int_lt`),
  then compares it with each string of that length; among eight or more
  of one length, by a character first. The thresholds are the best of twelve
  settings measured on the compiler compiling itself: a test of a character
  saves comparisons of strings, but the code grows, and the compiler takes
  longer over every node it makes.
* Counted by a VM that counts every `PRIM` (the base's sources compiled by
  each compiler, compiling those sources, `--jit=off`): `poly_eq` from
  2,924,565 to 171,638 (5.9%); `ptr_eq` from 4,263 to 422,508;
  `string_eq` 1,550,952, where `poly_eq` compared 2,156,182 strings (E11);
  1,028,847,720 bytecode instructions to 1,027,220,383 (−0.16%); bytes
  and output the same.
* Machine instructions at tier 2 (`perf stat -e instructions:u`, three
  runs each, the same counts): `tsp` −8.4%, `knuth-bendix` −8.5%, `logic`
  −7.0%, `mlyacc` −2.5%, `hamlet` −0.8%, `boyer` −0.1%, `lexgen` +0.1%,
  `fxp` 0.0%, `peek` 0. `hamlet` allocates 520 bytes and 15 objects less;
  no other program of MLton's set moves.
* The bootstrap (the register target, `--count`) from 1,039,097,094 to
  1,045,295,433 instructions and 1,490,436,688 to 1,498,418,744 bytes: the
  compiler's sources grew, and the base's compiler compiling them takes
  1,045,522,524 and 1,499,456,240. The bootstrap's budgets are measured
  again; the other programs of tests/perf move by 0.2% or less.

**D7 C as built (2026-10-12): the pass `equality`, under `-O2`.**

* `Simplify` makes, for each datatype at a type with no type variable
  that `=` compares, and for tuples of such parts, a function of that
  type, as MLton's `poly-equal` pass does: a wrapper that tests identity
  (`ptr_eq`) and is small enough to be put where it is called, and a
  worker that compares the tags and then each field by its own type
  (`imm_eq`, `ptr_eq`, `string_eq`, the function of the field's type, or
  `poly_eq` where the type is not known). A recursive datatype's worker
  calls itself. Without the wrapper (a first variant) it was worse on
  every program.
* Measured against B (machine instructions, `perf stat -e
  instructions:u`, three runs each at tier 2; HOL's kernel work, MLton's
  programs where structural equality is most frequent, and the bootstrap):
  HOL's kernel work 86,854,176,117 to 86,425,697,858 (−0.49%); `boyer`
  −2.2% and `mlyacc` −1.1% (−4.4% and −1.2% with A's prototypes), every
  other program of the set 0; the base's compiler compiling the sources
  +0.07%. The bytecode instructions grow where the machine instructions
  fall (`boyer` 159,200,248 to 170,098,539, `mlyacc` 230,914,393 to
  235,084,346: a call of compiled code where one `PRIM` walked the
  values), and the compiler, which runs the pass, compiling itself +0.44%
  of instructions, +0.63% of bytecode, +1% of code.
* Decided (the owner, 2026-10-12): kept, but not by default. `equality` is
  a named pass that `-O2` runs (and `--passes` selects); `-O1`, the
  default, compiles as B does. Under `-O2` `=` at such a type is compiled
  code, which the limit of `--equality-work` does not stop; the test of
  that limit is compiled at `-O1`. tests/ir/equality-functions shows the
  functions made, and `check-levels` runs the tests of the language at
  `-O2` with them.

### M6. The call (M-L)

D5 A and D9 B: the parts prototyped (no fill, the poll in the room check,
the frames array grown with the stack, `lea` for the return address, the
landing in line), then:

* the frame's address as a pointer;
* trampolines for interpreted and top-level callers;
* the result in a register;
* known calls patched when the callee is compiled;
* the closure in a register;
* counting per extended block.

**Targets:**

* a `fib` call at most 50 machine instructions and 8 stores (82.5 and 16
  today);
* a closure call at most 25 instructions (52 today);
* calls and returns at most 18% of the bootstrap's instructions (31%
  today);
* `--count` unchanged.

### M7. Pointers in registers (M)

D6 A: pointer homes written back to their tagged slots at safepoints and
reloaded after anything that may collect. It needs:

* a boxing path for reals and 64-bit ints moved into a home of any type;
* a `--gc-stress` check that slots and homes agree.

**Targets:**

* the bootstrap's pointer loads from slots from 747M to at most 300M;
* the language suite and `check-jit.sh` green in every mode;
* the bootstrap's cycles down by the prototype's 6%, as an indication.

### M8. Allocation in the middle end (L)

D8 A, in this order:

1. tuples flattened at joins;
2. small leaves inlined, and the tuple results of known calls flattened;
3. contification of loops called once, with known cases on what they
   return;
4. local refs as variables;
5. functions specialised on the closures they are given;
6. the Basis's vectors built and walked without lists (ranked item 17;
   `vector-rev`, `vector*-concat`).

**Targets, by `--count` on every engine:**

* the bootstrap's bytes at most 1.10 GB (1.468 GB today; what MLton's
  build of the same compiler allocates);
* `fft` −75%, `barnes-hut` −60%, `raytrace` −70%;
* `peek` and `imp-for` near nothing;
* on MLton's set, what E15 projects: no more than MLton but for IntInf,
  `tensor`, `knuth-bendix`, `ray` and `hamlet`.

**As built (2026-10-19).**

* Step 1: `Simplify` gives a join point the fields of a tuple parameter
  its body only takes apart, where some jump gives it a tuple made there.
* Step 2: a function small once simplified is put where it is called,
  whatever it was before; `Workers` flattens a tuple parameter's fields
  that are tuples too, through the variables bound to them; and `Lower`
  returns results in globals (the optional pass `results`, the whole
  program only): a function of the top level, never a value, that returns
  a tuple made there, or a tail call of another such, to calls that take
  its fields returns the first and leaves the rest in globals each call
  reads at once (`Slot`, an operation of Low that is never read again
  where it is used) -- a call that needs the tuple whole makes it where it
  needs it, at most once on a way, and a function is left as it is where
  more than a quarter of its calls would make the tuple at once, or where
  that has more than four fields. A function of a datatype that returns a
  constructor made there to calls that only ask the constructor and take
  its argument returns the tag, and the argument in the datatype's
  globals. `Simplify` makes what a function returns in its returns (a
  tuple or a constructor bound and returned at once; a join point that
  only returns its parameter).
* Step 3, by the other steps rather than by contification: `peek`'s loop
  returns `SOME x` through a closure the program takes from a record that
  `addPeek` makes. A function that makes functions and returns them is
  inlined up to 24 nodes, so the closures are known where the record is
  taken apart; the loop given them is copied for them (step 5), and the
  copy gives them on to a function that does not call itself, which is
  copied from the copy; the loop's `SOME x` then goes to calls that only
  take it apart, and is returned in globals (step 2). Contification as
  MLton has it, a loop made a join point, needs join points that jump to
  themselves, which Mid does not have.
* Step 4: the pass `refs` gives a copy of a function the value of a ref
  parameter it only reads, sets and gives on to its calls of itself in
  tail position, and a call that gives it a ref made for it alone calls
  the copy with the value.
* Step 5: `specialise` copies a function for a local function given too,
  made a function of the top level of what it captured and its parameter
  (its tuple parameter's fields, where it only takes them apart), two
  copies deep at most; a copy may give it on to a function copied for it
  in turn, and from a copy a function that does not call itself is
  copied too.
* Step 6: `Vector.tabulate`, `mapi`, `map`, `concat`, `update`,
  `Array.tabulate` and `Array.vector` fill an array in place and copy it
  (`array_to_vector`, a new primitive) instead of making a list.
* Measured (`--count`, MLton's programs at tests/perf/mlton-bench.txt's
  sizes, bytes, before → after; MLton's from E15): `fft` 536.9M →
  134.2M (−75.0%; MLton 134.2M), `barnes-hut` 143.3M → 48.0M (−66.5%;
  MLton 39.6M), `raytrace` 837.5M → 299.5M (−64.2%; MLton 210.5M),
  `peek` 1.28G → 1,048 bytes (MLton 1,096), `imp-for` 266.7M → 408 bytes
  (MLton 728); `ratio-regions` −92.8%, `zern` −71.4%, `tensor` −69.9%,
  `simple` −68.2%, `hamlet` −22.7%, `fxp` −19.7%, `wc-input1` −19.7%,
  `nucleic` −16.6%, `ray` −16.8%, `vliw` −13.4%, `mlyacc` −9.0%,
  `lexgen` −2.6%; `vector-rev` −71%, `vector32-concat` and
  `vector64-concat` −77% (step 6); `boyer`, `logic`,
  `tailmerge`, `merge` the same. No more than MLton: `checksum`, `fft`,
  `imp-for`, `merge`, `mlyacc`, `peek`, `simple`, `tsp`, `zern`.
* The bootstrap: the base's sources compiled by the new compiler, compiling
  those sources, allocate 1,468.2M → 1,213.4M bytes (−17.4%) in 4.9% fewer
  bytecode instructions. The compiler compiling its own sources (the
  budget), 1,503.7M → 1,477.0M bytes (−1.8%; −2.0% of it step 6), in
  15.9% more bytecode instructions (1,049.3M → 1,216.5M) and as many
  machine instructions
  (19.040G → 19.054G, +0.07%): the sources grew by 6%, its own code by
  12%, most of it copies of `map`, `app` and `foldl` for the local
  functions given to them, and it compiles what it makes -- `specialise`
  costs 7% of its instructions where it cost 2%. Compiling other programs
  is cheaper: the compile programs of tests/perf 2 to 5% fewer
  instructions (`compile-expo` +1.3%, `compile-sigs` +0.4%) and 2 to 10%
  fewer bytes. The rise in the bootstrap's bytecode instructions is
  accepted (the owner, 2026-10-19).
* Not met: the bootstrap's 1.10 GB; `raytrace` (−70%); MLton's set but
  for those above. What is left is out of the middle end's reach: the
  bootstrap's bytes are lists (42%), balanced trees and the buckets of
  `IntTable`, and `raytrace`'s the tuples of its interval lists, which
  MLton, whole-program and monomorphic, flattens into the list's cells;
  `lexgen` (65% the tuple a call of `leq`, a function taken from a
  record, is given), `fxp`, `logic` and `wc-input1` (a record of the
  stream per character, in `TextIO`'s functional streams) make what they
  give to calls of unknown functions or keep. Copying functions that do
  not call themselves from anywhere, not only from copies, takes
  `barnes-hut` to 41.6M and `hamlet` to 677.1M, and the base's sources to
  1.4% fewer bytes, but grows the compiler's code by 4% and its own
  bootstrap's bytes by 0.9%: not taken.

### M9. Native frames: a gate, then a roadmap of its own (XL)

After M5 to M7, measure what is left of the call's cost against MLton and
Poly/ML. If the call is still the largest part of HOL's gap, plan native
frames (D5 B): return addresses, a descriptor per return address, and the
interpreter's protocol, deoptimisation, traces and images over them. Plan
maps for pointers in registers (D6 C) with them. This is a change of the
size of the JIT roadmap, and it gets one of its own. Its target to plan
for: a `fib` call at most 25 instructions and 10 cycles.

The roadmap is [native-frames.md](native-frames.md) (2026-10-12). Its
prototypes by hand put a `fib` call on frames in the value stack at 21 to
25.5 instructions and 6 to 10 cycles, MLton's at 17 and 9 to 10; M6's lean
frames at 39.5 and 17 to 18.

### M10. Measure again, and retire this plan

* *Where we are* measured again with M1's tools.
* `docs/performance.md` rewritten.
* What is left moved to the next plan. From M9 (native-frames.md, *M9*):
  * constant operands in tier 2's body: `int_mod`'s test for a power of
    two made at compile time (E9's `selftail` +8% instructions since M2),
    an `INT` folded into the instruction that reads it;
  * a call through a closure taking its argument in a register (native
    frames M6 built known calls only);
  * `--jit-returns=call` as the default: per call 15% and 11% fewer
    cycles, on the bootstrap and HOL 1.5% and 2.7% more (one session);
  * tiering's counter at a call: counting the caller's work (HANDOVER as
    its comment said) measured worse after native frames M8;
  * the cycles deep recursion lost though its instructions fell or held
    (`merge` +17%, `wc-input1` +14%, `wc-scanStream` +22% against M1's
    runtime);
  * the bootstrap's collector, 38% of its cycles and more than its gap to
    MLton; HOL's gap, the code's instructions (39.7G to Poly/ML's 11.3G).
  D7's count of objects per run is not built: the owner's decision,
  2026-10-19, on the lead's recommendation.

**As built (2026-10-20, branch `perf-m10` on `a6a024ab1`).**

* **`--pass-stats`' check made to hold under load.** M1's check that the
  stages add up to the compile (tests/runner's compiler job) failed once
  in a full `make check` at a load of 30, on SML/NJ 110.99.9's build. Its
  processor time counts the collector's twice (`Timer.checkCPUTimer` adds
  the collector's time to a user time that holds it already), so a minor
  collection in the driver's code between two stages is a gap: 1 to 5% of
  the compile quietly, up to 10% at a load of 30 to 40, under 1% with an
  allocation area of 4 MB. SML/NJ's builds are held to 15% of the total,
  the collector's share of it, the others to 2% as before (200 runs at a
  load of 25 to 38: the worst gap half the new bound; `rune-test run
  compiler/ --repeat 20 --under-load` at a load of 29 to 55, 20 of 20).
* **The session.** *Where we ended*: the before and the after built in
  trees of their own (the after detached at `a6a024ab1`, so that its
  version and builds stay put), timed through the drafts' `timed.sh` (six
  pinned slots), the headline one run at a time. MLton's set was run from
  binaries built once, three rounds; HOL4 was built again by the after's
  Rune (`hol.state` in 1,054 s). Not all of `examples/benchmarks` was
  timed: the suite has 510 programs now, and after the first 258 (the 152
  E3 timed among them) a program took 760 s a run on SML/NJ; the first
  pass of `make perf` with `xc1` took 50 minutes in the before's tree,
  pinned to one core, its programs compiled and kept for the passes
  after it.
* **docs/performance.md rewritten** from the session, with the `xc1`
  hosts timed again, MLton's set, MLton's compiler compiled by Rune, MLton
  built by Rune and HOL4 added, and the load of every table.
* **`scripts/perf-groups.awk`** groups the frames' walks, a frame's
  liveness and the return barrier, which were "other", and `reg_frame_live`,
  which it counted as the JIT compiling.
* **Deep recursion's lost cycles, explained.** Against M1's runtime on
  the same bytecode, `merge`, `wc-input1` and `wc-scanStream` take 14%, 16%
  and 15% more cycles (the least of seven runs, at a load of 11), M9's own
  runtime 10 to 13%; the frames' group grew from 11% to 37% of `merge`'s
  cycles and from 9% to 30% of `wc-input1`'s, `vm_frames_from` alone 17 to
  19%: about 170 cycles a frame walked where 40, with 12 slots a frame and
  4 roots where 9 and 1 ([garbage-collector-v3.md](garbage-collector-v3.md),
  *Left by the performance plan*).
* **MLton's compiler in units** (the lead's question, 2026-10-20): 433 s
  at tier 2 against 84 s whole, 367 s of it the units' interfaces. A
  profile gives `P.hash`'s loop 36% of its cycles and the collector 25%;
  a build that counts what it hashes, 2,136 MB: signatures' fingerprints
  818 MB, functors' 430 MB in the usages and the same 432 MB again in
  `export`, which does not ask the memo, the basis's pickle 220 MB at
  `export` and again at `load`. On MLton's build the interfaces took 110 s
  at `921af2cc` and 208 s at the tip, while elaboration fell from 139 s to
  20 s: M3's functor fingerprints moved the cost there. The memo serves
  the whole process (73% of its lookups hit); `export` goes around it
  ([incremental-compilation.md](incremental-compilation.md), *After M12:
  what is left*).
* **What M9 left, and what M10 found, moved to the plans that take it:**
  * [jit.md](jit.md), *Left by the performance plan*: constant operands in
    tier 2's body, division by a constant (and `P.hash`'s), `ENV`'s
    tests, a constructor's tag by its kind, a closure call's argument in a
    register, `--jit-returns=call` as the default (measured again: the
    bootstrap 0.8% fewer cycles, HOL's kernel work 1.9% more), tiering's
    counter at a call;
  * [garbage-collector-v3.md](garbage-collector-v3.md), *Left by the
    performance plan*: the bootstrap's collector (34% of its cycles,
    more than its gap to MLton's build) and deep stacks;
  * [middle-end.md](middle-end.md), *Left by the performance plan*: HOL's
    code (3.5 times Poly/ML's instructions) and the allocation M8 did not
    reach;
  * [incremental-compilation.md](incremental-compilation.md), *After M12:
    what is left*: MLton's compiler in units;
  * [functors.md](functors.md): B, functors as functions, not started, as
    before;
  * [hol4.md](hol4.md), *What is left*: a `bin/buildheap` that takes
    `$RUNEVM`, so that a theory is measured on the VM asked for.

### Left for the next plan

What fits no plan above:

* **The Basis's own code.** The farthest programs of MLton's set from
  MLton are the Basis's: `output1` 22 and `psdes-random` (`Word32`'s
  arithmetic) 5.3 times MLton's cycles, where MLton allocates nothing and
  Rune 16 GB and 27 GB (`output1` an object a character, since M5); `checksum` 18, `md5` 12,
  `vector-rev` 12, `matrix-multiply` 11; and of `tests/perf`,
  `string_ops` 1.9 to 3.6 times every host's time. M5 and M8 took
  `output1`, the vectors and `peek` from 19 to 89 times MLton's cycles to
  4 to 22; what is left is per primitive and per structure of `lib/basis`,
  measured by `scripts/perf-cycles.sh --mlton-bench`, and no plan holds
  the Basis's speed.

## Relation to the other plans

* **[gmp.md](gmp.md)** is the plan for `IntInf`. Master has its M0; branch
  `gmp` has M0 to M3. This plan only measured IntInf:
  * HOL's `Arbnum` multiplication at 31 times Poly/ML's;
  * `intinf_fact` at 36 times Poly/ML's;
  * `pidigits` allocating 264 times MLton's bytes, and `smith-normal-form`
    22 times (E15).

  Master's GMP (since `921af2cc`) took them to 9.3, 2.9, 1.6 and 0.05
  times (M10).
* **[garbage-collector-v3.md](garbage-collector-v3.md)** holds what is left
  for the collector:
  * a survivor space;
  * Rune compiling MLton at 1.10 of the copier's time.

  The collector is 23% of the bootstrap's cycles and 2% of HOL's (E8).
  This plan's M8 cuts what reaches it. At M10 it is 34% of the
  bootstrap's, and deep stacks' walks cost more since native frames: both
  are there now, under *Left by the performance plan*.
* **[jit.md](jit.md)** is done. This plan revisits three of its
  decisions and leaves a fourth:
  * D5, no allocation removed by the JIT: kept (D10);
  * D7, an IR of its own for tier 2: not needed for M5 to M7;
  * D10, the 16-byte `Value`, whose option A made "the tags the stack
    map": kept for pointers in homes (D6);
  * D11, `runeopt` and images, whose option B (native code in images) is
    left where it is.

  What M5 to M9 left of tier 2's code is there now, under *Left by the
  performance plan*.
* **[middle-end.md](middle-end.md)** left three things unbuilt:
  * escape analysis, as research;
  * 0CFA, measured;
  * monomorphisation, "since `vm/new` does not unbox".

  M8 takes what the census says the middle end could remove, without
  needing the first. What it did not reach, and HOL's code, are there
  now, under *Left by the performance plan*.
* **[incremental-compilation.md](incremental-compilation.md)**:
  * its D1 (static interpretation) stands for code (D3). The functor's
    signature joins the export basis, and a use of a functor gets a
    fingerprint for types (M3).
  * Functors as functions with a link-time expansion, the answer to its
    risk 3, are for later ([functors.md](functors.md));
  * its *Ready for, not built*, "the elaborator at the scale of MLton", is
    this plan's M2 and M3;
  * the 3.3 GB that building MLton in units keeps live is E22's open
    question;
  * MLton's compiler in units, five times its whole compile since M3, is
    in its *After M12: what is left* (M10).
* **[type-checker.md](type-checker.md)** is M4's brief, and its measure of
  done is M4's.
* **[hol4.md](hol4.md)**'s *What is left*: "the JIT's code" is M5 to M7 and
  M9, measured there again at M10, with `bin/buildheap`'s `$RUNEVM`.
* **[benchmarks.md](benchmarks.md)**: the suite is on master. Branch
  `benchmarks` adds more of nofib's and Sandmark's programs in 14 commits
  from before heap-layout, not merged. M1 times what master has. Master
  took them in since: 510 programs at M10, of which it timed 258.
* **[whole-program-optimization.md](whole-program-optimization.md)** (a note:
  native code, an optimising pipeline, profile-guided optimisation) is
  where M9 and anything beyond this plan's middle-end items would go.
* **[weak-points.md](weak-points.md)**, items 2 (programs run slower than
  under MLton) and 3 (large programs elaborate slowly), are this plan's
  two tracks.

## Risks

1. **Under WSL2 cycles are not measurements.** The same binary varied by
   up to 40% between busy and quiet periods today. Every target is
   therefore a count; cycles and seconds are quoted as best-of-N
   indications, and only beside numbers taken in the same session.
2. **The units gate of M3.** E21's summaries change the bytes of unit
   files, and not only by the counters: settled in [functors.md](functors.md),
   *A contradiction in M3, found while building it*, and M3's gate above.
3. **Programs that rely on the equality leak.** Typing by rule 54 rejects
   programs Rune accepts today: a datatype made in a functor body
   compared with `=` where only the actual argument admits equality.
   HaMLet, SML/NJ, Poly/ML, Moscow ML and MLKit reject them already. MLton
   accepts them, so code written for MLton may rely on the leak. M3
   compiles MLton's sources, HOL4 and xc2 before it lands.
4. **Pointer homes and the collector.** A home holding a stale pointer
   after a collection is the class of bug that the `RUNE_INT64` tier-2 fix
   (`75192718`) was. M7 needs `--gc-stress` with a check that slots and
   homes agree, at every tier, before it lands.
5. **M4 is large.** Every walk over `Ty.ty`, about 46 places and MidCanon,
   must move to the new type. Partial versions were measured and do not
   help, so it cannot be done in halves.
6. **M9 may be needed for parity.**
   * The estimate, from the parts measured:
     * calls are 39% of HOL's instructions, and M6 aims to take about 40%
       of that;
     * M5's prototypes measured −5.6% of HOL's instructions;
     * M7's prototype measured −6.5% of cycles on the bootstrap. On HOL
       only its instructions were measured, which barely move.
   * Together they would take perhaps a quarter off HOL's time. That
     brings its kernel work from 5.6 to 9.3 times Poly/ML's to about 4 to
     7, and its theories from 3.5 to 5.1 times to about 2.6 to 3.8.
   * MLton's and Poly/ML's 10 to 17 instructions per call are only
     reachable with native frames.
7. **`runeopt` falls behind** under D11 B. That is the owner's call.

## Measuring

Where each number of this plan came from, and how to take it again. The
scripts, the prototypes as patches, and every raw result are kept with
the drafts of this plan (`~/.cache/claude-rune-drafts/performance` on the
machine it was written on: `scripts/`, `patches/`, `results/E<n>/`). M1
brings the ones worth keeping into the tree.

* **The machine:** a Xeon E5-1680 v3 (Haswell, 8 cores, 16 threads) under
  WSL2, 31 GB, with VS Code, other agents and the Windows host running.
  Single-threaded runs were pinned to a core of their own (`taskset`), at
  most six at a time.
* **Counts:**
  * `runevm --count` for bytecode instructions and allocation;
  * `perf stat -e instructions:u` and callgrind for machine instructions.
  * Callgrind gives exact counts per machine instruction, and per role
    through the JIT dump (B1-jit-dump).
* **Cycles:** `perf stat -e cycles:u,instructions:u,task-clock`, the least
  of 3 to 10 runs, or the mean of `perf stat -r 5` where marked. E5 and
  E6 are single runs.
* **Profiles:** `perf record -e cpu-clock:u` over `runevm --jit-perf-map`,
  grouped by part (the drafts' `perf-group.py`; M1 teaches
  `scripts/perf-groups.awk` the same), with roles within the JIT's code
  from the dump.
* **MLton's compiler:** MLton `5fe943391` (the merge of PR #660), whose
  `make -C mlton rune-mlton RUNE=true` writes `mlton-rune.txt` (606 files,
  198,458 lines), compiled with `--type-work=1000000000 --pass-stats`. MLton
  built by Rune is the output of that compile under MLton's own
  `make rune-mlton`.
* **HOL4:**
  * HOL4 at `3d15b18a8`, built by master's Rune (HOL-perf) and by Rune of
    2026-10-10 (`~/.local/rune-hol`).
  * HOL4 at `bdc6917ee`, five commits earlier (before the port to Rune),
    built by Poly/ML 5.9.2.
  * Theories are rebuilt by Holmake on a fresh copy of their directory
    with only the theory's outputs removed, and timed by HOL's own "took"
    and by `perf stat`.
  * The kernel work runs in a restored `hol.state`.
  * Core theories (`arithmetic`, `pair`) cannot be rebuilt that way: their
    ancestors are in the heap already.
* **Allocation against MLton:** `@MLton gc-summary`, beside Rune's
  `--count`, on the same sources and sizes.
* **The escape census:** the census VM, extended to follow each object to
  the furthest it goes (B2-esc-census).
* **The literature and the implementations:** the notes, with every file
  and line, are with the drafts (`lit/`), with the Crossref records.

**The experiments:**

| | What |
|---|---|
| E1 | tests/perf on every engine, MLton and Poly/ML |
| E2 | MLton's benchmark set on Rune, MLton and Poly/ML |
| E3 | `examples/benchmarks` on Rune, MLton and Poly/ML |
| E4 | the compiler compiling itself, on every engine and host build |
| E5 | Rune compiling MLton's compiler |
| E6 | MLton built by Rune, against MLton built by MLton |
| E7 | HOL4's theories and kernel work, against Poly/ML |
| E8 | profiles by part of the runtime |
| E9 | instructions per call at tier 2, against MLton, Poly/ML and OCaml; the call's prototypes |
| E10 | the JIT's samples by role |
| E11 | equality, strings and exceptions: counts, cost, prototypes |
| E12 | pointers in registers: colouring, slot traffic, prototype |
| E13 | a VM without counting |
| E14, E14b | the escape census; the design of the summed count |
| E15 | allocation against MLton's, by kind; MLton with a pass dropped |
| E17 | intermediate code side by side (`fib`, `tak`) |
| E18 | the elaborator's time and counters per declaration |
| E19 | generated programs that scale each construct, on six compilers |
| E20 | prototype: sharing in one realisation |
| E21 | prototype: functors typed from a summary |
| E22 | what the elaborator keeps live |
| E23 | `exponential.sml`: memoisation and partial hash-consing |
| E24 | the passes after elaboration; MidCanon's quadratic |

E16 was folded into E15.

## References

Every DOI was fetched from Crossref, and each entry rebuilt from its record
(rr's report from DataCite). How far each was read is in brackets: in full,
in part, the abstract, or the record only (then what this plan says of it
comes from the work that cites it).

**Modules**

* M. S. Paterson, M. N. Wegman. Linear unification. *JCSS* 16(2), 1978,
  158-167. 10.1016/0022-0000(78)90043-0 [record]
* R. E. Tarjan. Efficiency of a good but not linear set union algorithm.
  *JACM* 22(2), 1975, 215-225. 10.1145/321879.321884 [record]
* X. Leroy. Manifest types, modules, and separate compilation. *POPL '94*,
  109-122. 10.1145/174675.176926 [in part]
* D. B. MacQueen, M. Tofte. A semantics for higher-order functors. *ESOP
  '94*, LNCS, 409-423. 10.1007/3-540-57880-3_27 [record; as characterised by
  Rossberg et al. 2014]
* M. Elsman. Static interpretation of modules. *ICFP '99*, 208-219.
  10.1145/317636.317800 [in part]
* C. V. Russo. Types for modules. *ENTCS* 60, 2004, 3-421 (the thesis of
  1998). 10.1016/S1571-0661(05)82621-0 [abstract]
* G. Kuan, D. MacQueen. Engineering higher-order modules in SML/NJ. *IFL
  2009*, LNCS, 2010, 218-235. 10.1007/978-3-642-16478-1_13 [record; as
  characterised by Rossberg et al. 2014]
* A. Rossberg, C. Russo, D. Dreyer. F-ing modules. *JFP* 24(5), 2014,
  529-607. 10.1017/S0956796814000264 [in part]

**Types**

* H. G. Mairson. Deciding ML typability is complete for deterministic
  exponential time. *POPL '90*, 382-401. 10.1145/96709.96748 [record]
* A. J. Kfoury, J. Tiuryn, P. Urzyczyn. ML typability is DEXPTIME-complete.
  *CAAP '90*, LNCS, 206-220. 10.1007/3-540-52590-4_50 [record]
* Z. Shao, C. League, S. Monnier. Implementing typed intermediate languages.
  *ICFP '98*, 313-323. 10.1145/289423.289460 [in full]
* J.-C. Filliâtre, S. Conchon. Type-safe modular hash-consing. *ML '06*,
  12-19. 10.1145/1159876.1159880 [in part]

**Calls and frames**

* A. W. Appel, Z. Shao. Empirical and analytic study of stack versus heap
  cost for languages with closures. *JFP* 6(1), 1996, 47-74.
  10.1017/S095679680000157X [in part]
* M. Fluet, S. Weeks. Contification using dominators. *ICFP '01*, 2-13.
  10.1145/507635.507639 [record]
* A. Kennedy. Compiling with continuations, continued. *ICFP '07*, 177-190.
  10.1145/1291151.1291179 [in part]
* L. Maurer, P. Downen, Z. M. Ariola, S. Peyton Jones. Compiling without
  continuations. *PLDI '17*, 482-494. 10.1145/3062341.3062380 [in part]

**Exceptions**

* N. Ramsey, S. Peyton Jones. A single intermediate language that supports
  multiple implementations of exceptions. *PLDI '00*, 285-298.
  10.1145/349299.349337 [in part]

**Allocation**

* X. Leroy. Unboxed objects and polymorphic typing. *POPL '92*, 177-188.
  10.1145/143165.143205 [in part]
* S. L. Peyton Jones, J. Launchbury. Unboxed values as first class citizens
  in a non-strict functional language. *FPCA '91*, LNCS, 636-666.
  10.1007/3540543961_30 [abstract and introduction]
* T. Kotzmann, H. Mössenböck. Escape analysis in the context of dynamic
  compilation and deoptimization. *VEE '05*, 111-120.
  10.1145/1064979.1064996 [in part]
* L. Stadler, T. Würthinger, H. Mössenböck. Partial escape analysis and
  scalar replacement for Java. *CGO '14*, 165-174. 10.1145/2544137.2544157
  [in part]

**JIT compilers**

* U. Hölzle, C. Chambers, D. Ungar. Debugging optimized code with dynamic
  deoptimization. *PLDI '92*, 32-43. 10.1145/143095.143114 [in part]
* H. Xu, F. Kjolstad. Copy-and-patch compilation: a fast compilation
  algorithm for high-level languages and bytecode. *PACMPL* 5(OOPSLA),
  2021, 1-30. 10.1145/3485513 [in part]

**Determinism**

* T. Bergan, O. Anderson, J. Devietti, L. Ceze, D. Grossman. CoreDet: a
  compiler and runtime system for deterministic multithreaded execution.
  *ASPLOS '10*, 53-64 (Crossref's record has the short title).
  10.1145/1736020.1736029 [in part]
* R. O'Callahan, C. Jones, N. Froyd, K. Huey, A. Noll, N. Partush.
  Engineering record and replay for deployability. *USENIX ATC '17*;
  report arXiv:1705.05937, 10.48550/arXiv.1705.05937 [in part]

**Without a DOI**

* The MLton guide, `doc/guide/src/Elaborate.adoc` and
  `PolyEqual.adoc`.
* Wasmtime's `docs/examples-interrupting-wasm.md` and
  `crates/wasmtime/src/config.rs`.
* OCaml's `Changes` (#10559, lazy signature substitution).
* All of these were read under `/home/ruud/reference`.

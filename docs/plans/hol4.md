# HOL4 on Rune

HOL4 built and run on Rune, which is M5 of
[incremental-compilation.md](incremental-compilation.md): what was done,
what it costs against Poly/ML, why, and what is left. As of 2026-10-09.

## Where it is

HOL4 Trindemossen-2 (`bdc6917ee`) lives on a local branch
`trindemossen-2-rune` of a HOL4 checkout, in four commits: `c5a2f741f`
builds HOL's tools with Rune's compiler, `7fd1a8d71` builds HOL itself,
and `7766d229d` and `419489d1e` make `bin/hol` start and the help build.
The branch is not pushed anywhere. Its `tools-rune/README.md` describes
the configuration; in short:

* **The tools.** Holmake, `build`, mllex, mlyacc, unquote and the rest are
  compiled by `rune` from the source lists MLton builds them from, each a
  `.rbc` with a script where Poly/ML's configuration puts the executable.
  The script passes `runevm --name` its own path, because Holmake re-runs
  itself by `CommandLine.name`.
* **Heaps are images.** Poly/ML's `buildheap` loads a heap into itself and
  goes on. A Rune image cannot be loaded into a running program, so every
  heap is a whole world with `buildheap` in it: `bin/buildheap` restores
  the heap `--holstate` names (the base image for `--poly`), and the world
  runs `buildheap`'s `main` on the arguments. Writing a heap (`-o`) is
  `Runtime.share` and then `Runtime.save`.
* **Poly/ML's names over Rune's.** `tools-rune/rune-polyml.ML` gives the
  parts of `PolyML`, `Thread`, `Mutex` and `Signal` that HOL uses:
  `PolyML.compiler` is `Compiler.compile`, `shareCommonData` is
  `Runtime.share`, `pointerEq` is `Runtime.same`, `Signal.signal` for
  SIGINT is `Runtime.catchInterrupt`, and a thread forked runs to its end
  before `fork` returns, Rune having no threads.
* **polyc.** The Holmakefiles make programs of files that `use` others
  (`$(POLYC)`): `tools-rune/polyc.sh` uses the file in `rune-repl` after
  the shim above, saves the world, and writes a script that restores it
  and runs `main`.
* **`src/portableML/rune`** holds what HOL asks of the ML system without
  threads, mostly as links to the plain-SML files of `../poly` and
  `../mosml`; `MLSYSPortable`, `Counter` and `PrettyImpl` are its own.
* **Outside `tools-rune`**, little: the sequence files take
  `[poly,rune]` tags, which `tools/buildutils.sml` reads; Holmake treats
  `rune` as `poly` where a Holmakefile tests `POLY`, and `build` makes the
  help as on Poly/ML; rawtheory's theorytool has a Rune `mktool`. HOL's
  REPL is `tools-rune/holrepl.ML`, `tools-poly/holrepl.ML` without the
  `+` that Poly/ML overloads on times and without `prettyRepresentation`
  of an exception.

What Rune needed and got for it: `Compiler.compile` (Poly/ML's
`PolyML.compiler`: a reader in, a function that runs what it read out),
`runevm --name`, `Runtime.share`, `Runtime.save` collecting first, and
`Compiler.compile` through the cache and parsing once (*What was done*).

**How far it builds.** `bin/build` builds the kernel, `bin/hol.state0`,
the core theories, `bin/hol.state` through `src/boss` and the help, and
ends "Hol built successfully": M5's line. A build of HOL4's `core`
collection (`src/parallel_builds/core`) on one job had built 102 of its
theories, none failing, after three and a half hours when this was
written. `bin/hol` proves and evaluates, and starts in 1.08 s (Poly/ML
0.43 s); it shows a term or a theorem as `?`, since it has no printers
(*What is left*), so `print (thm_to_string th)` shows one.

### Overloading's context (2026-10-26)

Rune now defaults an overloaded operator or constant where the declaration
at structure level around it ends (`--overloading=declaration`, Appendix
E's bound: [correctness/linting.md](correctness/linting.md), D18, M15;
[../language.md](../language.md), *Deviations*, Overloading). Before, it
did so where the declaration at top level ended, a whole structure
(`--overloading=toplevel`). HOL4's tree has seven constants that a later
declaration of their structure, or its signature, determines to be
`IntInf.int`, and that the new default makes `int`:

* `tools/Holmake/poly/MB_Monitor.sml:37`, `val time_units = [("m", 60), ...]`,
  which `compact_time` divides a `LargeInt.int` by;
* `src/portableML/poly/Arbnumcore.sml:15-17` and `Arbintcore.sml:10-12`
  (which `src/portableML/rune` links to), `val zero = 0`, `val one = 1`
  and `val two = 2` after `open IntInf`, which the opaque signatures make
  `IntInf.int`.

So `tools-rune/configure.sh` fails at Holmake. **Until the annotations land
in the HOL4 tree, HOL4 builds with `--overloading=toplevel`**, given to both
the compiler and the REPL that `configure.sh` takes from `RUNE` (the
directory of `rune`, `runevm` and `rune-repl`): a `rune` there that ends
`exec "$d/runevm" ... rune.rbc --lib "$d/../lib" --overloading=toplevel "$@"`,
and a `rune-repl` that ends `exec "$d/runevm" ... --restore
"$d/rune-repl.img" -- --overloading=toplevel "$@"`, so that every tool, every
`polyc` program and every heap is compiled in the context it was written
for. The annotations are
[hol4-overloading-declaration.patch](hol4-overloading-declaration.patch)
(three files of `trindemossen-2-rune` at `3d15b18a8`); with them HOL4
configures and builds to `hol.state` under the default, and they are valid
on Poly/ML too. That is how it was measured: the count of what the new
default breaks is in the linting roadmap's M15.

## What it costs

Measured on 2026-10-09 on one machine, Rune and Poly/ML 5.9.2 side by
side under the same load, which was other builds: the times are of
processor, user and system, and their ratio is what to read. "Before"
is Rune at `40e2b23a` (M6) with `Compiler.compile` and `runevm --name`,
"after" with the changes of *What was done* as well.

### Size

| | Poly/ML | Rune before | Rune after |
|---|---:|---:|---:|
| `bin/hol.state0` | 16.7 MB | 78.5 MB | 26.9 MB |
| `bin/hol.state` | 13.2 MB | 169.1 MB | 51.5 MB |
| the base image (`buildheap --poly`) | -- | 35 to 63 MB | 13.8 MB |
| `rune-repl`'s own image | -- | 20.8 MB | 8.5 MB |

The comparison is not like for like: Poly/ML saves child heaps
(`saveChild`), so its `hol.state0` is what was added to the heap of the
`poly` executable and its `hol.state` what was added to `hol.state0`. A
Rune image is the whole program, compiler and Basis Library included.

What the 169 MB of `hol.state` was, from walking the image (*How the
numbers were taken*):

| | MB |
|---|---:|
| garbage, written because `Runtime.save` did not collect first | 16 |
| live, reached from the REPL's own globals (the compiler's session) | 74 |
| live, reached only from what HOL bound | 55 |
| outside the heap: bytecode 8.8, functions 5.4, the line table 3.7 | 18 |

Of the REPL's 74 MB a bare `rune-repl` has 8.7; the rest grew with every
declaration HOL compiled. What each module of the compiler alone kept
alive: `Ty`'s tables 31.4 MB, the registry of sources 12.0 MB (9.9 MB of
it whole source texts), `Elaborate`'s tables 2.9 MB, `UnitBasis` 1.2 MB.
`Ty.binders` holds the type of every variable a compile binds, locals
included, under its stamp; after a unit is compiled the REPL loads it
again from its basis under fresh stamps after those, so that a cold and a
warm compile are the same bytes, and nothing names the compile's stamps
again -- but the tables, which only grow, kept what they held. An entry
costs a list cell, a pair and a ref of `IntTable`'s buckets besides the
type: a million of them.

Equal immutable values made one -- what Poly/ML's `shareCommonData` does
before every heap it saves, and what Rune did not have -- would have
taken 38 MB off HOL's 55 and 39 MB off the REPL's 74: HOL's terms and
types repeat.

### Speed

The theory scripts themselves, by the time each reports from
`new_theory` to `export_theory` (Rune before; what was done does not
touch it):

| theory | Rune | Poly/ML | |
|---|---:|---:|---:|
| `arithmetic` | 26.2 s | 7.0 s | 3.7 |
| `logroot` | 31.8 s | 7.1 s | 4.5 |
| `pair` | 9.4 s | 1.8 s | 5.2 |

and pieces of HOL's work in a restored `hol.state`:

| | Rune | Poly/ML | |
|---|---:|---:|---:|
| `EVAL ``FACT 60``` | 2.79 s | 0.38 s | 7.3 |
| `EVAL ``FACT 150``` | 30.8 s | 4.95 s | 6.2 |
| `PROVE_TAC`, twenty times | 0.28 s | 0.027 s | 10 |
| `SIMP_CONV arith_ss`, two hundred times | 1.17 s | 0.18 s | 6.6 |
| `Arbnum`, 2,000 multiplications | 0.015 s | under 0.001 s | |

Where Rune's time goes, from `perf` over `logroot` with
`runevm --jit-perf-map`:

| | % |
|---|---:|
| code the JIT compiled at tier 2 | 78.6 |
| the runtime's equality and string order (`values_equal`, `p_ptr_eq`, `jit_h_string_order`) | 6.3 |
| the collector | 4.2 |
| the runtime's exceptions (handlers pushed, raises) | 3.1 |
| other runtime | 2.1 |
| the interpreter | 1.0 |
| restoring the image | 0.8 |
| compiling (the JIT) | 0.8 |

The compiled code is spread over HOL's kernel, terms, types, maps and
the exceptions it computes with (`can`, `total`, `ORELSEC`,
`mk_HOL_ERR`), with no function above 3%. `Arbnum` and `IntInf` are 1.1%
of it, though Rune's `IntInf` is 180 times slower than Poly/ML's on
`intinf_fact` ([../performance.md](../performance.md)): HOL's numerals
are symbolic work, and so is most of the rest. The collector is 5 to 8%
of the processor time of a script (Poly/ML's 13 to 19%). So the factor
of four to six is the JIT's code against Poly/ML's native code, as
[../performance.md](../performance.md) has it for code that calls a lot
(`fib`, `tak`: four to five times Poly/ML), and the runtime calls that
equality and handlers still are.

Two costs come before a script's own:

* **Restoring the heap.** `buildheap --holstate=hol.state` that does
  nothing: 1.74 s and 1.1 s of processor before, against 0.54 s and
  0.14 s for Poly/ML, which maps its file. Rune reads the image and
  relocates every object; the time is in proportion to the image. After:
  0.70 s and 0.40 s.
* **Compiling what the heap lacks.** A script loads its ancestors that
  are not in the heap from source, on Poly/ML as on Rune; for `pair`
  that was 28 s on Rune and 17.5 s on Poly/ML, at every script that
  needs them. Rune's cache did not help: HOL loads through
  `PolyML.compiler`, which is `Compiler.compile`, which did not look in
  the cache (241 entries after the whole build); and `Compiler.compile`
  parsed a structure once for each of its declarations (*What was done*).
  After: 6.1 s from the cache that the build filled (8,509 entries,
  145 MB) and 10.3 s without it.

So a script, as a process, in seconds of processor:

| | Rune before | Rune after | Poly/ML |
|---|---:|---:|---:|
| `pair` | 40.8 | 18.9 | 22.0 |
| `arithmetic` | 50.9 | 45.4 | 23.1 |
| `logroot` | 37.7 | 34.1 | 9.0 |

A script that needs much that its heap lacks now costs about what it
does on Poly/ML; one whose time is its proofs costs the factor of the
JIT's code.

The whole of it, `bin/build --seq` through `src/boss`, as M1 measured
Poly/ML: Poly/ML 410 s of processor (370 user, 40 system) and 5 min 19 s
on sixteen jobs; Rune after, on one job and beside other builds, 1,405 s
(1,350 and 55), 3.4 times as much, and 35 min. Rune's largest process
was 272 MB, Poly/ML's 748 MB. (With the first three changes of *What was
done* and not the fourth, 1,628 s.)

## What was done

1. **`Compiler.compile` through the cache.** A part of a file that is
   there is compiled through the cache as `use`'s declarations are, its
   units named by the file and the line it begins at and keyed by its
   text (`src/repl/repl.sml`, `compileReader`; `tests/repl/compilecache`).
   A part is parsed as of its line, rather than behind as many newlines as
   put it there, which was a line table of the whole file before every
   declaration.
2. **`Runtime.share`** (`runtime/gc/share.c`, [../runtime.md](../runtime.md),
   *Sharing*): after a full collection every object is numbered bottom-up,
   equal immutable objects alike; every field and root is pointed at the
   first of its number, and a second collection frees the rest. HOL's
   `buildheap` calls it before each heap, as Poly/ML's does, and so do the
   base image and `rune-repl`'s own. `Runtime.save` collects before it
   writes.
3. **The REPL keeps less.** `UnitBasis.undo` takes the stamps a compile
   made out of `Ty.binders`, `Ty.exnArgs` and `Ty.realizations`
   (`IntTable.removeRange`); the registry of sources keeps a compiled
   file's line table and not its text (`Source.keepLines`), and nothing of
   a printer's source.
4. **One parse a declaration.** `Compiler.compile` parsed the text it had
   read at every `;`, to see whether the `;` ended a declaration; HOL's
   structures have one after most of their declarations, so a structure
   was parsed as many times as it has them. It now counts brackets and
   `let`, `local`, `struct`, `sig` and `abstype` against `end` as the
   characters come, outside strings and comments, and parses at a `;`
   at depth 0 alone; the parse still decides (`tests/repl/compile`).
   Found by profiling the loading that the cache did not speed up.

What they did:

| | before | after |
|---|---:|---:|
| `bin/hol.state` | 169.1 MB | 51.5 MB |
| its live heap, the REPL's and HOL's | 74 and 55 MB | 13.7 and 16.4 MB |
| `bin/hol.state0` | 78.5 MB | 26.9 MB |
| restoring `hol.state`, processor | 1.25 s | 0.40 s |
| `pair`'s ancestors loaded | 28 s | 6.1 s |
| the collector, in a script | 2.7 to 3.0 s | 1.0 to 1.6 s |

What HOL's proofs cost did not change: the 46 theories took 913 s
before and 972 s after, by their own clocks, beside other builds both
times.

## What is left

In the order of what they would gain:

* **The JIT's code**, three quarters of a script's time. Equality and
  string order are calls into the runtime where Poly/ML compares in line,
  and so are an exception handler's push and a raise; the rest is the
  code's own quality ([jit.md](jit.md)). Since then (2026-10-20,
  [performance.md](performance.md), *Where we ended*): equality, string
  order, handlers and raises in line, and the call native frames' -- HOL's
  kernel work from 6.0 to 2.1 times Poly/ML's cycles, `logroot` and
  `mergesort` from 4.1 and 3.9 to 1.7 and 1.6 times its time; what remains
  is the code's instructions, 3.5 times Poly/ML's ([middle-end.md](middle-end.md),
  *Left by the performance plan*).
* **Child images.** A heap that is what was added to its parent would make
  `hol.state` what HOL added and restoring it a matter of that part; the
  base and the parents could then be mapped rather than read.
* **The REPL's bookkeeping**, what is left of the 74 MB: the session's
  environment and the types of the names it binds, which the session
  needs, and the tables of `Elaborate`.
* **`bin/buildheap` and `$RUNEVM`.** The `bin/buildheap` that
  `tools-rune/configure.sh` writes runs the VM HOL was configured with,
  and takes neither `$RUNEVM` nor `$RUNEVM_OPTS`, so Rune's
  `bin/rune-measure hol-theory --vm` and `--vm-opts` (a VM to measure, `--jit-perf-map`)
  do not reach a theory's rebuild. The copy performance.md's measurements
  used ends `exec "${RUNEVM:-VM}" $RUNEVM_OPTS --name ...`.
* **What HOL has and Rune has not:** threads (`--mt`, `Future` in
  parallel), the language server (`--lsp`), executables made of a heap
  (`--exe`), and the directories only Poly/ML builds (`tactictoe`,
  `holyhammer`, `AI`).

## How the numbers were taken

* **Images**, by a program of C over `build/librune.a` that restores an
  image into a VM without running it, collects, and walks the heap:
  objects by kind and size; what the program's first globals reach (the
  REPL's: 6,814 in the bare `rune-repl` of before, 6,820 after) against
  what only the rest do;
  each module of the compiler by the globals its unit was given, found by
  loading the REPL's units into a second VM one by one; what a module
  alone keeps, by marking from every other root first; and what sharing
  would save, by numbering the objects bottom-up as `Runtime.share` does.
* **Scripts**, in a copy of the theory's directory: the script's `.uo`
  written from Holmake's dependency file, and `buildheap` run with the
  arguments Holmake gives it and a last file that reports the process's
  processor and collector time. Poly/ML's copy of HOL4 is M1's.
* **Profiles**, by `perf record -e cpu-clock:u` over `runevm
  --jit-perf-map`, which names the code the JIT made.

The programs and scripts are not in the repository; they are kept with
the drafts of this work, in `~/.cache/claude-rune-drafts/incremental/hol/tools`
on the machine it was done on.

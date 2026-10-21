# Roadmap: incremental compilation, a REPL, dynamic modules and a build system

Rune compiles a whole program from its sources every time it runs, the
Basis Library included, and can do nothing else: there is no `use`, no
interactive top level, no way to keep what a compile has done, and no
way to bring code into a running VM. This roadmap plans what removes
those limits, in order: a REPL that can host HOL4; units compiled apart,
cached on disk and linked; modules loaded into a running VM and checked
against a signature; a build language of Rune's own with late binding of
modules; and, planned again once those exist, hot reload, the compiler
as a service, reproducible and parallel builds, and packages. It was
written on 2026-09-25 against branch `jit` at `38e3420`, the commit of jit
M3, and its working tree, in which jit M4 is being finished; it starts when the JIT roadmap
([jit.md](jit.md)) has finished: at least its M7, the stopping point
the owner kept open, and M8 to M12 where they were built (*Prerequisites
and flags*).

What it rests on:
* a reading of the compiler's driver, elaborator, IRs and back end
  (`src/driver`, `src/elab`, `src/core`, `src/backend`), of the runtime
  and both VMs (`vm/`, `vm/new` with jit M3's `jit.h`), of
  `lib/basis/MANIFEST` and `sources.txt`, and of the plans that reserved
  hooks for this one (`middle-end.md`, `jit.md`, `codegen.md`,
  `weak-points.md`);
* HOL4's host layer for Poly/ML, read in its sources (`tools-poly/`,
  `tools/Holmake/poly/`, `src/portableML/poly/` of the `develop` branch)
  and in the built Trindemossen-2 at `/home/ruud/.local/hol4`: the
  contract a host must meet, measured rather than assumed (*HOL4
  today*);
* the timings of [performance.md](../performance.md) and the review of
  [weak-points.md](weak-points.md) of 2026-09-24 and 2026-09-25;
* the literature and the systems (*What the literature says*,
  *References*); every DOI was checked against Crossref on 2026-09-25.

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | Measure | done 2026-10-09, `0bc5bd38`: `bin/rune-measure perf-units`, the table in *What a compile costs* (*Measured again*), HOL4 on Poly/ML in *HOL4 today*, `tests/incremental/SCENARIOS.md`; D6 settled (Mid binary), D9 measured (4%), the globals given a barrier in M3 |
| M2 | Units in memory: the basis as a value, the front end resumable, a back end per unit | done 2026-10-09, `79e0598b`: `rune --units`, the linker, `Pass.whole`, errors recovered per declaration, `make check-units` (*M2, as built*); one question for the owner (flexible records) |
| M3 | Unit bytecode, the static linker, and the VM loads units | done 2026-10-09, `9d97b311`: `.rbu`, `--emit-units`, linking unit files, `rt_link`/`Runtime.link`/`Runtime.load`, the dynamic path in `check-units` (*M3, as built*); the globals' barrier moved to M4 |
| M4 | The resident compiler, `use` and the REPL | done 2026-10-09, `71f1916e`: `bin/rune-repl` and `rune -i`, Chapter 8, `use`, printing, the globals' barrier, the JIT across loads, the boot image, interrupts, a session saved and restored (*M4, as built*) |
| M5 | HOL4 on Rune | done 2026-10-10, `f8e9fdc5` and HOL4's local branch `trindemossen-2-rune`: `bin/build` through `src/boss`, `hol` proving, the costs against Poly/ML and why in [hol4.md](hol4.md), with what did not port; the rebuild from a warm cache verified (`RUNE_VERIFY_CACHE`, issues 13 and 14). Whether to go on to the rest of HOL4 is the owner's |
| M6 | The cache, with cut-off | the first two parts done 2026-10-09, `40e2b23a`: the export basis, names that do not depend on what came before, every unit through its basis, unit files by keys, the cache with usages by binder, the frozen Basis, `use` through it, `tests/incremental` (*M6, ... as built*); the soundness of it examined and fixed in [build-cache-issues.md](build-cache-issues.md), with `--verify-cache` and a mutation tester; the third part, fingerprints per entry and entries loaded across changed units, built 2026-10-10 (*M6, the third part as built*); issues 13 to 15 since. Not met: the two-line program from a warm cache in under twice `hello`'s time (*After M12*) |
| M7 | Mid per unit: whole-program builds from the cache | built 2026-10-10: `rune --units --whole`, units' Mid in the cache, the canonical renumbering, and a program made of its units' Mid the bytes of the whole-program compile (*M7, as built*) |
| M8 | The dependency graph, and a program from an entry point | built 2026-10-10: `rune --deps`, `--deps-dot`, `-I` entry points, the MANIFEST's requires column derived and checked (*M8, as built*) |
| M9 | Compiling against a signature alone, and dynamic modules | built 2026-10-10: `_dynamic` and `_export`, the signature's ABI and its fingerprint, the constructors' order renumbered, `Dynamic`, programs linked from units keeping their exports (*M9, as built*) |
| M10 | The build language and virtual modules | built 2026-10-10: `rune --build`, the programs' and the libraries' build files in place of `sources*.txt` and the MANIFESTs, `rune --basis-index`, `_virtual` and `implements` (*M10, as built*) |
| M11 | Parallel and reproducible builds | built 2026-10-10: `rune -j N` (children forked through the cache, the build the bytes of one process), `make check-reproducible`; measured, and no speed-up, for reasons in *M11, as built* |
| M12 | Hot reload, the compiler as a service, packages: research and prototypes | studied 2026-10-10: `Dynamic.reload` on Erlang's rule, `rune --serve` (diagnostics and hover over JSON-RPC), a survey of package systems and a lock file sketched; three decisions for the owner (*M12, as built*) |

The owner decided D1 to D9 and D11 to D19 on 2026-10-09, all as
recommended (*Decisions*), and asked for D10 to be reviewed against the
heap layout and the collector built since this was written; after the
review, which is in D10, the owner decided D10 as A on 2026-10-09. The
work runs on branch
`incremental`, one commit per milestone, from M1 in order; *Since this
was written* says what changed under the plan between 2026-09-25 and
2026-10-09. M1 to M7 are one part: at the end of M4
Rune has a REPL, at the end of M5 it hosts HOL4, at the end of M7 a
compile costs what changed, and the owner may stop at any of the three.
M8 to M12 are sized now and planned again after M7, with its numbers
and with the JIT roadmap's second part known.

## The request

The owner's brief, as written (`docs/plans/incremental-compilation.md`
before this roadmap replaced it; the same text was
`~/notes/incremental-compilation.md`):

> # Towards incremental compilation and dynamic modules
> ## Specification from the Human
> - We want to add several disting but implementation wise likely related items to Rune
>   - The first is that we want to be able to use Rune as the host language for HOL4. HOL4 requires a **REPL** which we do not support at all currently. In addition to HOL4 a REPL will also be useful for interactive developemnt. The REPL does not have to be very fancy on the first go. Enough to support HOL4. We can enhance it as a separate plan later.
>   - A second item is supporting **incremental compilation**. This is essential for keeping compile times reasonble while doing iterative development and testing on large code bases.
>     - I suggest having the compiler keep a cache in a .rune folder inside of each folder containing .sml source files. The cache could be a parsed ast, a typechecked ast, or even bytecode together with an interface specification, or a combination of these. File timestamps on the caches can be compared against the source files by the compiler to see if they are fresh or need regeneration.
>       - An earlier review flagged timestamps alone note being sufficient, we would also need needs compiler flags and identity etc.
>       - Ensure the caching system is tested thoroughly. It is a hard problem with many corner cases.
>       - A review flagged that a per folder .rune cache may have issues with debug vs release builds etc. So we should be able to locate it elsewhere (e.g. when the module-based build system discussed later is put into place? The per folder cache seems like a decent first solution. but feel free to disagree and propose another system.)
>     - The .rune cache will also be useful for a language server that will be developed later in a roadmap completely indepentently from this one. (No need to do any work on the LSP now - just keep it in mind it may be a user of the .rune folder later.)
>     - We should always retain the ability to do whole-program compilation. This is essential for production builds as it allows for greater program optimization.
>       - An earlier review flagged that cross-testing whole-program vs incremental builds would give valuable correctness and performance data.
>   - Once we have a REPL and incremenation compilation we probably also want a **dynamic module loading** system later. The code can interact with the dynamic module via a statically known signature (to be checked when loading the module). There a many interesting things to explore here:
>     - Run currently runs on a bytecode VM so this suggests a straightforward path: dynamic modules are just bytecode and VM loads and executes them.
>     - In the future we also want to add native code generation. This adds more compilications: do we keep storing the modules as bytecode and then either interpret or compile them by include an interpreter/compiler. Or we also compile the dynamic modules to native code and then only need to link them when loading. Likely we even want to support both approaches as both have their advantages and disadvantages (bytecode will be portable accross machines while native code will be faster to link and execute). Let keep our options open here. Adding native code generation is explictly not part of this roadmap though. It is something we will develop in a separate roadmap later. We just need to be ready in the design for this.
>     - A later add-on may be Erlang-style hotfixing of modules in a running system. This will likely we its own separate research project to assess feasibility and implemenation techniques. Do an initial review and keep it in mind. But it would be at the end of the roadmap if we decide to do this at all.
>   - Finally we have the **module-based build system**.
>     - This is not part of the SML language standard and it seems SML/NJ and MLton have taken different routes. Rune also has it's own adhoc system in the form of sources.txt and lib/basis/MANIFEST. I do not like any of these approaches.
>     - I think the first step here is to have the compiler be able to generate the module dependency graph from a given .sml file. The compiler should be able to dump/print that structure. Given ML's Module language this may be more complex than just a simple DAG of .sml files? For interactive development purposes the compiler should be able to use this graph to load the whole program given only a single .sml file as entry point.
>       - I am not sure if this is as easy for Standard ML as it is for Haskell as SML has a far more powerful Module language than Haskell. I do not know what the implications of this are. Please do thorough research (existing compilers, academic literature and by using your own reasoning powers) and include the results in the roadmap so I am aware and revise the plans if needed.
>         - An earlier review mentioned (Appel & MacQueen 1994; Swasey/Murphy/Crary/Harper SMLSC 2006; Elsman 1997; Blume’s CM) on incremental/separate/cutoff compilation but i have not read those. you should and report on it in the roadmap if relevenant.
>         - SML seems to have a distinction between .sml files and modules as the compilation units. This needs consideration. SML/NJ's CM and MLB alledgedly make different choices here. There may be some contention between how HOL4 uses SML in REPL mode and production software maybe can be expected to have a more clean layout of what is in each .sml file. If tradeoffs are required here then: we want to support HOL4 in Rune, but the module-based builds system should be optimized for clean production software where we may assume additional cleanlyness on the .sml files. I may even consider limiting what can be considered to be a valid .sml file if that materially improves Rune's build system. But in that case there needs to be some escape hatch as well because compling most of the existing SML systems is a near-term goal. If there is a tradeoff here this would require serious discussion in the roadmap.
>     - For a production system be likely still do want to have some kind of module structure language to build projects. This should be a proper language with ast, specification etc.
>       - Ideally we still have the ability to leave some things implict or depends on modules build definitions suplied by packages. So we do not constantly have to update our top-level if e.g. a library we use has 
>       - One feature I am particularly interested is late binding of modules. The .sml source can program against the interface of a structure of a virtual module. Then only the specificion in the Build language specifies the exact module to back the interface. This way we could e.g. easily swap out the implemention of a standard library module (e.g. use a concrete IntInf with an SML implementation or and IntInf backed by GMP primitives, or swap out two variant implementations of a module to do performance testing between them). Most of the program can be blissfully unware of all this. We can control this in one centralized place. This will be very helpful during automated testing of programs and to produced variant builds of the system without needing to touch the source code all over the place or use ad hoc pre-processors etc.
>       - An earlier review flagged Ocaml Dune as highly relevant here. I have not looked at it yet.
>     - I am only listing this item last because it has the largest number of unknowns for me. If you believe this or a part of this is a prerequisites
> - Other things we are likely to look at the end of the roadmap are:
>   - Compiler-as-a-service
>   - Deterministics/reproducible builds
>   - Highly parallel and declarative build system that can replace some of the ad hoc stuff currently in this repo
>   - Package manager and virtual environments
> - These are just my suggestions. You are to carefully review them and use your own judgement to come up with the final roadmap. Let me known if you disagree with anything here so we can build a solid roadmap before we being implementation.
> - The roadmap should contain milestones and give a dependency order as this work is large enough that it will require multiple sessions to implement fully (and some of the work may be post-poned to a later date if we find something else needs to be done more urgently).
> - Once we start implementing the roadmap make sure the implementing agents document and test this properly as some of this is bahaviour beyond the Standard ML Definition and different between each compiler (i.e. we cannot rely solely on the documenation from the Definition and cross-compiler testing anymore.)
>   - Note that this plan/roadmap file is ephemeral. Once the roadmap is fully implemented I do not want to keep it around. So the documentation should elsewhere (inside source code and new Markdown file(s) under the docs folder).
> - Also let me know if there is anything related to this that is missing from my items and that you think should or could be included in the roadmap because they are closely related / will have impact on these features / are found in other compilers, languages and systems.
> ### Prior research
> An earlier review flagged this is exisiting research and you may want to study it:
> - Appel & MacQueen, Separate Compilation for Standard ML (PLDI 1994) — functors, visible compiler, IRM.
> - Swasey, Murphy, Crary, Harper, SMLSC (ML 2006) + CMU-CS-06-104 — units vs modules, IC vs SC, handoff units, definite references.
> - Blume, CM manual + Dependency analysis for Standard ML + Hierarchical modularity — cutoff, groups/libraries, stabilize.
> - Adams, Tichy, Weinert — cutoff recompilation.
> - Elsman, Separate Compilation and Cut-Off Incremental Recompilation (TIL, 1997).
> - Russo, Types for Modules ch. 6 — why naive “compile against a signature” fails; abstractions as compilation units.
> - MLB spec (mlb-formal.pdf) vs CM new.pdf.
> - Moscow ML manual, compilation units / .ui/.uo.
> - Poly/ML PolyML.compiler, SaveState, NameSpace.
> - HOL tools-poly/hol.ML, holrepl.ML, prelude.ML — the actual host contract.
> - Dune virtual libraries; Haskell Backpack (parametrized packages).
> - Harper/Morrisett/Stone-style typed assembly / dynamic linking for the load-time match.

The owner's other notes that bear on this: `~/notes/virtual-machine.md`
(HOL4 "does not have to be fast if that means architecture sacrifices
elsewhere. And I can even live with dropping HOL4 support for Rune
entirely"; "OSR, deopt, code invalidation. Needed as soon as you
speculate or reload modules. Cheap to design in; brutal to retrofit";
"we have full control over the language and compiler so we can make
breaking changes"), `~/notes/rune.md` ("REPL (required for HOL4)"; "do
our functors copy, should they?"; "Core operates on Module based build
system"; "whole-program vs incremental"; "language server protocol"),
and the brief of a future IDE (`docs/plans/ide.md`), which will be the
first consumer of the compiler as a service (M12) and does no work here.

**The owner's decisions after reading this roadmap (2026-10-09):**
every recommendation taken, with three notes: D1 and D2 are A "for now
to keep strict SML'97 semantics", and B of each may be considered for
Rune 2.0; D18 is A, and C (first-class packages) may be considered for
Rune 2.0. D10 asked for a review: "is A still possible with the new
heap layout that has been introduced (and possible future optimization
planned) or is B now required?" The answer is in D10: A is still
possible and B is not required, but A's justification was wrong under
the new layout and is rewritten there with the conditions that keep it
true.

| The brief asks | Answered in |
|---|---|
| a REPL, enough for HOL4; enhanced separately later | D9 to D12, M4; *HOL4 today* for what "enough" is; the enhancements in *Ready for, not built* |
| incremental compilation for iterative development on large code bases | D1 to D6, M2, M3, M6, M7 |
| a `.rune` cache per source folder: parsed, typechecked or bytecode with an interface; timestamps against the sources | D14: content hashes and a configuration hash, never timestamps; per folder by default, relocatable; what it holds is D6 |
| timestamps alone are not sufficient: flags and identity | D14; *What the literature says*, CM and GHC |
| the cache tested thoroughly | M6's scenario suite; *Testing* |
| debug vs release; the cache elsewhere | D14 (the configuration hash and `--cache-dir`); M10 (the build file names it) |
| the cache useful to a language server later | D4 (spans and per-declaration positions kept), D19 (the service); *Prerequisites and flags* |
| whole-program compilation retained for production | D6, D8, M7; *Constraints* |
| cross-testing whole-program against incremental | M3's `check-units`, M7's byte-identity, *Testing* |
| dynamic module loading against a statically known signature | D17, D18, M9 |
| dynamic modules as bytecode the VM loads; native later, both kept open | D7, D18 (the code kind of a unit); *Prerequisites and flags* |
| Erlang-style hot fixing, reviewed, at the end if at all | D19, M12; *What the literature says*, Erlang and dynamic software updating |
| the module-based build system; dislike of CM, MLB, `sources.txt`, MANIFEST | D16, M10; *Today's build system* |
| the dependency graph from a `.sml` file, dumped; a program from an entry point; is it a DAG of files? | D15, M8; *What is different for SML* |
| research: existing compilers, literature, own reasoning, reported | *What the literature says*, *What is different for SML*, *References* |
| files versus modules as units; CM against MLB; HOL4's use of the REPL against clean production layouts; a restriction with an escape hatch; serious discussion | *What is different for SML*, D1, D15 (the discussion), D16 |
| a proper build language with an AST and a specification; things left implicit; packages | D16, M10 (`docs/build.md`) |
| late binding of modules: program against an interface, bind in the build language | D2, D16, D17, M9, M10 |
| Dune | *What the literature says*, D16, D17 |
| the build system as a prerequisite? | *Why this order*: no; M8 and M10 come after the REPL and the cache |
| compiler-as-a-service, reproducible builds, a parallel declarative build system, packages | D19, M11, M12 |
| review the suggestions; disagreements | *Disagreements and additions*, after *Decisions* |
| milestones in dependency order, over several sessions, some postponable | *The milestones*, *Why this order*; the stopping points after M4, M5 and M7 |
| document and test behaviour beyond the Definition; the plan file is ephemeral | *Constraints* (the lasting documents: `docs/units.md`, `docs/repl.md`, `docs/build.md`, rows of `docs/language.md`); *Testing* |
| what is missing | *Disagreements and additions* |
| the prior research listed | each item in *What the literature says*; Elsman's "1997" is his 1999 paper and his 2008 report, and his 2026 REPL paper is the closest precedent of all |

## Since this was written

Between 2026-09-25 and the owner's decisions of 2026-10-09, master
moved under this plan. What moved, and what it changes here; *Where we
are* below is the tree of 2026-09-25 and is left as it was read.

* **The JIT roadmap finished** (M1 to M12, merged as PR #21): code
  objects and the driver, tiering and invalidation with its poll points
  (M6), the representations section per function (M8), deoptimisation
  (M11) and aarch64 (M12) all exist, so every prerequisite of
  *Prerequisites and flags* holds as built, and none of the "without
  M6/M8/M11" fallbacks is needed. `runevm` tiers to tier 2 by default.
* **The tree was renamed** (2026-10-03): `vm/` is `runtime/`. The
  runtime both VMs link is directly under it (`vm.h`, `value.h`,
  `loader.c`, `image.c`, `prims.c`, `runtime.c`), the collector is in
  `runtime/gc/`, the system layer in `runtime/sys/` (`sys.h`), the stack
  VM in `runtime/stack/` (`bin/runevm-stack`, which was `runevm`), the
  register VM in `runtime/register/` (`bin/runevm`, which was
  `vm/new` and `runevm-new`) with its JIT in `runtime/register/jit/`;
  `rune` makes register bytecode unless told `--target=stack`. Every
  `vm/...` path below is the old tree's. The names they cite were all
  found again on 2026-10-09 at the new paths (`load_program_mem`,
  `validate_program`, `rop_kinds`, `op_kinds`, `JitProgram`,
  `CodeObject`, `jit_entry`, `PRIM_NEW_WORLD`, `heap_relocate`,
  `vm_become`); line numbers are not to be trusted.
* **The heap layout** ([heap-layout.md](heap-layout.md), merged as PR
  #33; `docs/runtime.md`, *Values and objects*). A value is one 64-bit
  word on every machine, and its low bit says only "immediate" or
  "pointer". `int` and `word` are 63 bits; `Int64` and `Word64` are
  boxed past 63 bits; a real is an immediate by the rotation encoding
  where its exponent allows, boxed otherwise; an object has an 8-byte
  header of kind, constructor tag and length; a constructor whose
  argument is a tuple is one object of the tuple's fields (`CONN`);
  `Word8Array`, `CharArray`, `RealArray` and `RealVector` hold raw
  bytes and doubles. **An immediate no longer says what it is**: an
  `int`, a `word`, a `char`, `unit`, a nullary constructor and a real
  in range are all odd words, and `val_tag` answers `T_INT` for every
  one of them ("the program knows which", `runtime/value.h`). This is
  what D10 had to be reviewed for. It changes nothing in D3 to D7: a
  datatype's representation is still a function of its declaration
  (`Rep.ofDatatype`), which is what lets a later unit match an earlier
  unit's constructors. Kept open by that roadmap and not built: raw
  real fields (deferred by the owner to a roadmap of their own),
  headerless pairs (branch `heap-layout-pairs`; its D1 C "later, in the
  whole-program compiler"), a 32-bit machine's own word
  (`32-bit-vm.md`), and a pointer code kept for a lazy front end.
* **The collector** (`garbage-collector-v2.md`, merged as PR #34;
  `docs/runtime.md`, *The heap* and *The garbage collector*): a nursery,
  an old space that is not copied (mark-region with opportunistic
  evacuation under `--gc throughput`, the default, and incremental
  marking from a snapshot under `--gc low-pause`), a large-object space,
  a heap of 2 MiB chunks rather than one block, and a barrier on every
  store into an object. What it changes here:
  * D9's cost and risk 4 shrink. The resident basis -- the Basis
    Library's and HOL4's static environment, kept live in the heap -- is
    promoted once and afterwards marked at each major collection, not
    copied at every collection. M1 still measures it, under both
    collectors.
  * A new cost to measure: the globals are roots of **every** minor
    collection and are scanned whole (`docs/runtime.md`, *The roots*),
    since `SETGLOBAL` has no barrier. A REPL session grows its globals
    with every declaration (HOL4's heap has tens of thousands of
    top-level values), so each minor collection pays for all of them.
    M1 measures the cost per global; if it matters, M3 gives the
    globals a dirty bit per slot (cards for the globals table), which
    `rt_load` sizes as it grows the table.
  * Nothing in M3 assumed one contiguous heap. An image after loads
    is still the whole program, its magic still the instruction set's
    fingerprint (which `rt_load`, a new primitive, changes), and a
    loaded unit's code makes its stores through the barrier as any
    bytecode does.
* **Numbers.** *What a compile costs* predates all three; M1 measures it
  again, on today's tree.

## Where we are

### The compiler today: the whole program is the unit

Everything the compiler does, it does to one program. The numbers and
lines are of 2026-09-25.

* **The driver** (`src/driver/main.sml:125-207`). `compile` tokenises
  the user's files, picks the files of the Basis Library whose
  `provides` column of `lib/basis/MANIFEST` names an identifier the
  tokens mention (`select`, `src/driver/basismanifest.sml:106-139`),
  and hands the `always` and `demand` files, the `final` files and the
  user's files to `frontEnd`, which parses them all, threading one
  fixity environment through every file (`main.sml:25,153-155`), and
  elaborates them into one `Env.env ref` (`main.sml:157-162`). It then
  translates the concatenation into **one** Lambda term
  (`Translate.transProgram (preludeProg @ userProg)`, `main.sml:169`)
  and drops the environment on purpose: "nothing of the first --
  tokens, syntax, environment -- is still reachable, and copied by every
  collection, while the second runs" (`main.sml:144-147`). `backEnd`
  runs `ToMid`, the optional passes `shake`, `lift`, `workers`,
  `simplify` from `-O1`, `Lower`, then `Stack` or `Regs` and `Emit`,
  to one `.rbc`. A project is the list of files on the command line, in
  order; `rune` reads no project file.
* **Every name comes from one counter.** Every value binder gets its
  stamp from `Elaborate.stampCounter` (`src/elab/elaborate.sml:7-8`),
  every type name from `Types.tyconCounter`, which starts at 100 since
  0 to 99 are the builtins (`src/elab/types.sml:44-54,73-75`), every
  type variable from `Types.tvarCounter`. The stamps are the names of
  Lambda, Mid and Low: `Global of int` is a top-level binding, and
  `MatchComp`, `ToMid`, `Lift`, `Workers`, `Simplify` and `MidText` all
  draw fresh variables from `Elaborate.freshStamp`. The lints require
  "every binder's stamp is bound once in the whole program"
  (`docs/ir.md:61-63,174`), and the five builds of the compiler must
  write the same bytes (`make check-cross`), so the numbering is part of
  the contract: whatever renumbers must be deterministic.
* **The static basis is spread over the program.** What the Definition
  calls the basis is here: the `env` of values, types and structures
  (a structure is a nested `env` with no identity of its own,
  `src/elab/env.sml:6-18`); signatures in `Elaborate.sigs`; functors in
  `Elaborate.funs`, each a `FunInfo` of its parameter signature, its
  **body as AST** and a snapshot of the environment, signatures and
  functors it was declared in (`elaborate.sml:12-19`); the fixity in
  `Main.fixity`; the overloading registry `Overload.table`; the tables
  `Ty.binders`, `Ty.exnArgs`, `Ty.datatypes` and `Ty.realizations`
  (`src/core/ty.sml:26-37`); `Translate.primAliases`; and the pending
  lists of overloads, flexible records, literals and deferred checks
  (`elaborate.sml:21-31,48`), which `Elaborate.finish` (`:104-112`)
  settles once, for the whole program. A structure ascribed opaquely
  hides its types from the program and not from the compiler:
  `Ty.bindRealization` records what each abstract type stands for
  (`src/elab/sigmatch.sml:286-293`), and the IRs see through it
  (`docs/ir.md:87-88`).
* **Functors are expanded at every application.** A functor body is
  type-checked once against its parameter signature when declared and
  kept as AST; each application copies the body (`Ast.copyStrexp`),
  elaborates the copy with the argument bound in the functor's
  definition-time environment, stores it in the `StrApp` node, and
  `Translate` emits it in place (`elaborate.sml:844-903`,
  `src/core/translate.sml:475-485`; `docs/architecture.md:112-126`).
  There are no functors at run time. This is static interpretation
  (Elsman 1999), MLton's and MLKit's choice, and the opposite of
  SML/NJ's, where a functor is a closure and its body is compiled once
  (Appel and MacQueen 1994). The consequence for this roadmap: a unit
  that exports a functor exports source, and its clients compile that
  source.
* **Structures are globals.** A top-level `val x` or a `val` inside a
  top-level structure is a VM global: `VGlobal` in the AST, `Global
  stamp` in Lambda and Mid, `GLOBAL i` in the bytecode, with `i` a dense
  index assigned in order of first use during emission
  (`src/backend/code.sml:134-137`). The `.rbc` records the **number** of
  globals and nothing else about them: no names, no types, no exports
  (`docs/bytecode.md:10-60`; `src/backend/emit.sml:62-152`). Function 0
  is the whole top level: every top-level definition of the program,
  lowered into one function body that runs them in order
  (`src/backend/lower.sml:611-651`). There is no other entry.
* **Mid's top level is already a list of units.** `Translate` marks the
  rest of the program after each top-level declaration (`Lambda.Rest`)
  and `ToMid` splits there into `Val`, `Funs` and `Do` definitions
  (`src/core/tomid.sml:305-343`; `docs/ir.md:143-147`).
  `docs/plans/middle-end.md:410-417` named this list "a unit for
  incremental compilation", and its *Ready for, not built* said what
  was left: "every pass takes a flag that says whether it sees the whole
  program. Stamps need only be unique within a unit. Mid's printed form
  can serve as a unit's interface, carrying what other units may
  inline" (`middle-end.md:1505-1513`). No pass has the flag yet.
  `MidText` (`src/core/midtext.sml`, 673 lines) prints Mid and reads it
  back (`--read-mid`, `--mid-roundtrip`), the only representation that
  round-trips; but Mid is not self-contained: `Rep.ofDatatype`
  (`src/backend/rep.sml:17-31`) decides a constructor's layout by
  asking `Ty.datatypeOf` at Lower time, so a Mid read from text without
  the elaborator's tables would box every constructor.
* **The passes assume the whole program.** `Shake` removes every global
  nothing reaches from the roots, because "the Basis Library is
  compiled whole into every program, and most of it is never used"
  (`src/core/shake.sml:1-11`); `Workers` rewrites every call site of a
  global function to its worker; `Simplify` inlines and specialises
  across top-level definitions; `Lower` knows every function
  (`knownFuns`, `src/backend/lower.sml:191,603-604`), fixes each known
  call's arity by its definition (`docs/bytecode.md:161-163`), and
  numbers functions program-wide; `Rep`'s layout is "the datatype's,
  whatever types it is used at" (`rep.sml:7-8`), the constructors'
  tags in declaration order.
* **What is already resumable.** `runedoc`'s `DocElab` keeps an `env`
  and a fixity after elaborating a library once and runs
  `Elaborate.elabTop (ref env, prog)` on new text on top of it
  (`src/doc/docelab.sml:18-36,63-78`): the elaborator can go on from a
  kept environment in one process, leaning on the global tables and
  counters still being live. It generates no code.
* **Errors.** `Error.error` raises `CompileError`, caught once in
  `Main.main` (`main.sml:230`): the first error ends the compile. There
  is no `use`, no top level, no printing of `val it = ...`; the derived
  form `exp ;` becomes `val it = exp` at the top level
  (`src/frontend/parser.sml:797-801`) and `it` may not be rebound
  except in patterns (`elaborate.sml:115-119`). `docs/language.md:27`
  records the deviation: "Rune is a batch compiler: a static error in
  any top-level declaration rejects the whole program, and an uncaught
  exception terminates it. Chapter 8 regards programs as interactive."
* **Size.** The compiler is 13,150 lines of Standard ML in 47 files
  (`sources.txt`); the Basis Library 20,546 lines; `bin/rune.rbc` is
  790 KB with 2,101 functions and 860 globals. The compiler as register
  bytecode, `bin/rune.new.rbc`, runs on `vm/new` and writes the same
  bytes as on `runevm` (`scripts/check-new.sh:62-78`): a compiler
  resident in the VM this roadmap targets already works.

### What a compile costs

From [performance.md](../performance.md) (2026-09-25, wall clock, best
of three rounds) and [weak-points.md](weak-points.md) (2026-09-24):

| Compile | `bin/rune` (`runevm`) | `bin/rune.new.rbc` (`vm/new`, before jit M2) | MLton's build |
|---|---:|---:|---:|
| `examples/hello.sml` | 21.7 ms | 29.3 ms | 5.9 ms |
| two lines using `List` and `TextIO` | 1.8 s | -- | 0.1 s |
| the compiler itself | 5.03 s | 6.01 s | 0.89 s |

* `hello` loads almost none of the Basis; the two-line program loads
  the files `List` and `TextIO` pull in, and elaborating them is where
  the 1.8 s go: "every compile starts from source" is item 1 of
  `weak-points.md` (`:17-39`), whose first step is "compile the Basis
  Library once and keep the result".
* The budgets of `tests/perf` fix what does not depend on the machine:
  compiling `hello` executes 3.24M VM instructions
  (`tests/perf/compile-hello.budget`), the bootstrap 470M (`jit.md`,
  M2, after `RET` folded `RESULT`).
* Nothing is cached anywhere in the compiler. The only caches in the
  tree are the test harness's: native translations keyed by the
  sha256 of the `.rbc` (`scripts/runevm-opt.sh:13-14,56-58`), and the
  Basis suite's saved host images keyed by a checksum of the library's
  sources and `vm/prims.def` (`tests/basis/run-matrix.sh:730-784`). Both
  key on content plus tool identity, never on time.

#### Measured again: M1, 2026-10-09

`bin/rune-measure perf-units` on `incremental` at M0 (master `b9506382`: the
JIT, the word layout and the second collector all in), on an idle
machine, the least wall time of five runs (one for MLton). The compiler
runs on `bin/runevm` tiering up to tier 2 (*tier2*), interpreted
(`--jit=off`), at tier 1 (`--jit=baseline`), as stack bytecode on
`bin/runevm-stack`, and as MLton's build. The phases are the processor
time `--pass-stats` gives each, in seconds; `parse` and `elaborate` are
new stages of it (M1), and both shakes are added together. The lines are
those of every file the compile reads, the Basis Library's included.

| Compiler | Program | wall | parse | elaborate | translate | mid | shake | lift | workers | simplify | lower | registers | lines read | lines/s, front end |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| tier2 | hello | 0.037 | 0.006 | 0.007 | 0.003 | 0.002 | 0.001 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 108 | 8,308 |
| interp | hello | 0.023 | 0.001 | 0.003 | 0.001 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 108 | 27,000 |
| baseline | hello | 0.033 | 0.004 | 0.006 | 0.002 | 0.002 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 108 | 10,800 |
| stack | hello | 0.022 | 0.002 | 0.002 | 0.001 | 0.001 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 108 | 27,000 |
| mlton | hello | 0.008 | 0.001 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 0.000 | 108 | 108,000 |
| tier2 | two lines | 0.291 | 0.050 | 0.092 | 0.030 | 0.017 | 0.009 | 0.005 | 0.006 | 0.025 | 0.013 | 0.012 | 7,419 | 52,246 |
| interp | two lines | 0.412 | 0.085 | 0.140 | 0.043 | 0.024 | 0.012 | 0.004 | 0.005 | 0.030 | 0.009 | 0.018 | 7,419 | 32,973 |
| baseline | two lines | 0.270 | 0.043 | 0.086 | 0.028 | 0.016 | 0.007 | 0.005 | 0.007 | 0.029 | 0.009 | 0.011 | 7,419 | 57,512 |
| stack | two lines | 0.449 | 0.101 | 0.157 | 0.043 | 0.028 | 0.012 | 0.004 | 0.005 | 0.034 | 0.011 | 0.016 | 7,419 | 28,756 |
| mlton | two lines | 0.100 | 0.016 | 0.041 | 0.008 | 0.005 | 0.003 | 0.001 | 0.001 | 0.007 | 0.003 | 0.003 | 7,419 | 130,158 |
| tier2 | the Basis whole | 0.784 | 0.096 | 0.284 | 0.095 | 0.071 | 0.028 | 0.007 | 0.009 | 0.046 | 0.036 | 0.076 | 23,616 | 62,147 |
| interp | the Basis whole | 1.612 | 0.247 | 0.606 | 0.176 | 0.130 | 0.065 | 0.007 | 0.010 | 0.067 | 0.054 | 0.202 | 23,616 | 27,686 |
| baseline | the Basis whole | 0.849 | 0.104 | 0.295 | 0.111 | 0.078 | 0.031 | 0.007 | 0.011 | 0.044 | 0.045 | 0.085 | 23,616 | 59,188 |
| stack | the Basis whole | 1.895 | 0.327 | 0.687 | 0.247 | 0.154 | 0.062 | 0.008 | 0.012 | 0.081 | 0.054 | 0.212 | 23,616 | 23,290 |
| mlton | the Basis whole | 0.387 | 0.054 | 0.170 | 0.043 | 0.034 | 0.017 | 0.002 | 0.002 | 0.017 | 0.006 | 0.014 | 23,616 | 105,429 |
| tier2 | the compiler | 2.011 | 0.100 | 0.277 | 0.121 | 0.118 | 0.051 | 0.077 | 0.113 | 0.337 | 0.276 | 0.325 | 25,267 | 67,021 |
| interp | the compiler | 4.231 | 0.240 | 0.567 | 0.275 | 0.207 | 0.090 | 0.160 | 0.162 | 0.633 | 0.592 | 0.811 | 25,267 | 31,310 |
| baseline | the compiler | 2.136 | 0.113 | 0.277 | 0.139 | 0.129 | 0.056 | 0.087 | 0.107 | 0.311 | 0.300 | 0.367 | 25,267 | 64,787 |
| stack | the compiler | 4.990 | 0.276 | 0.707 | 0.278 | 0.262 | 0.117 | 0.182 | 0.194 | 0.777 | 0.707 | 0.877 | 25,267 | 25,704 |
| mlton | the compiler | 1.131 | 0.067 | 0.097 | 0.162 | 0.042 | 0.032 | 0.036 | 0.030 | 0.214 | 0.108 | 0.150 | 25,267 | 154,067 |
| tier2 | the corpus harness | 0.846 | 0.067 | 0.145 | 0.054 | 0.032 | 0.020 | 0.031 | 0.020 | 0.153 | 0.055 | 0.154 | 16,544 | 78,038 |
| interp | the corpus harness | 1.761 | 0.156 | 0.279 | 0.091 | 0.058 | 0.037 | 0.051 | 0.039 | 0.261 | 0.111 | 0.504 | 16,544 | 38,032 |
| baseline | the corpus harness | 0.921 | 0.079 | 0.156 | 0.056 | 0.034 | 0.021 | 0.022 | 0.031 | 0.151 | 0.068 | 0.193 | 16,544 | 70,400 |
| stack | the corpus harness | 2.084 | 0.192 | 0.338 | 0.102 | 0.074 | 0.046 | 0.038 | 0.046 | 0.347 | 0.131 | 0.526 | 16,544 | 31,215 |
| mlton | the corpus harness | 0.393 | 0.025 | 0.069 | 0.050 | 0.017 | 0.016 | 0.007 | 0.006 | 0.084 | 0.022 | 0.054 | 16,544 | 176,000 |
| tier2 | MLton's compiler | 624.670 | 0.495 | 611.250 | 1.261 | 0.548 | 0.475 | 0.511 | 0.451 | 2.517 | 1.542 | 3.232 | about 205,000 | 335 |
| mlton | MLton's compiler | 142.486 | 0.138 | 135.504 | 0.658 | 0.352 | 0.199 | 0.409 | 0.324 | 0.845 | 0.871 | 1.392 | about 205,000 | 1,511 |

MLton's compiler is MLton at `5fe943391` (MLton PR #660, the first
commit Rune builds: 606 files, 198,458 lines, in the order of its
`mlton-rune.txt`), compiled under `ulimit -v 12582912` with `--heap-limit
5368709120`, as `bin/rune-measure gc-eval` compiles it.

What the numbers say:

* **Compiles are 3 to 6 times faster than when this was written**: the two
  lines 0.29 s at tier 2 (1.8 s on 2026-09-24), the compiler 2.0 s (5.03
  s). The JIT's tier 2, the word layout and the generational collector did
  it; the stack VM, which has none of the JIT, is where the old numbers
  were.
* **The Basis is the two-line program's compile.** Of its 7,419 lines two
  are the program's; the front end is half of its 0.29 s and the back end,
  translating the same Basis files, the rest. A compile against a Basis
  compiled once (D8, M6) would cost what `hello` costs, 0.04 s.
* **The front end reads 50,000 to 80,000 lines a second at tier 2** on
  ordinary code, about half of what MLton's build of the compiler reads:
  HOL4's `use` of a file of 5,000 lines is about 0.1 s of front end.
* **But not on MLton's sources: 335 lines a second, and 98% of the
  compile is elaboration** (611 s of 625 s; 135 s of 142 s on MLton's
  build of Rune, so it is the elaborator and not the VM). Elaborating each
  file as a unit (`--units --typecheck-only --pass-stats`, M2, MLton's
  build) puts 82 s of 130 s in the 282 signature files, 40 s in the 223
  files of functors and 9 s in the rest. The worst are signatures that
  share structures of a large signature five times over (`sharing amd64
  = amd64MLton.amd64` in `amd64-generate-transfers.sig`, 10 s each), then
  the files that apply the functors (`main.sml`, `main.fun`,
  `compile.fun`, 8 s each), whose bodies static interpretation
  elaborates again at every application. This is a cost of the
  elaborator, not of incremental compilation, and it is found here
  because MLton is the first large functorised program Rune compiles: the
  cache (M6) avoids paying it for files that did not change, but a change
  to a signature or a functor that much of MLton depends on pays it
  again. Profiling and fixing signature instantiation and sharing is
  worth a plan of its own; it is listed in *Ready for, not built*.
* **D6: Mid is stored binary.** The compiler's own Mid, printed (5.2 MB)
  and read back with `--read-mid`, takes longer to read than to make
  from the sources: 1.02 s against 0.72 s at tier 2, 0.43 s against 0.36
  s on MLton's build, and so at every configuration. D6's condition was
  "if text is not several times faster, Mid is stored binary"; M7
  stores it binary.
* **D9: the resident basis costs 4%.** The compiler with its front
  end's environment and syntax kept reachable through the back end (a
  scratch build, `keptEnv`), compiling itself, best of three: 32 MB more
  live (66 MB to 98 MB), 12% to 15% more time in the collector (427 to
  479 ms under `--gc throughput`, 457 to 490 ms under `--gc low-pause`),
  4% more wall time (1.95 to 2.02 s) and 35% more peak memory, the same
  output. The generational collector promotes the basis once; the
  collector's place in the plans does not move.
* **The globals cost every minor collection** (*Since this was
  written*): a program of N top-level values, at `-O0` so that all are
  kept, that then allocates 384 MB of short-lived lists:

  | globals | minor collections | their processor time | per minor collection | roots besides the stack |
  |---:|---:|---:|---:|---:|
  | 0 | 691 | 11.1 ms | 16.1 µs | 230 |
  | 1,000 | 691 | 13.6 ms | 19.7 µs | 1,231 |
  | 10,000 | 700 | 36.8 ms | 52.5 µs | 10,230 |
  | 50,000 | 770 | 159.7 ms | 207.4 µs | 50,230 |
  | 100,000 | 940 | 369.8 ms | 393.4 µs | 100,230 |

  About 3.8 ns a global at every minor collection. With 100,000 globals the
  program, whose run without them takes 0.2 s, spends 0.37 s more in the
  collector. A REPL session, and HOL4's above all, holds that many, so
  M3 gives the globals a barrier: a card per block of globals, marked by
  `SETGLOBAL` when the value is young, and only the marked cards scanned
  at a minor collection, as the old objects' fields are.

### The VM today: one program, absolute everywhere

* **One `Program` per VM**, embedded in the `VM` (`vm/vm.h:146-162,185`):
  constants, the count of globals, the function table, one contiguous
  code array, the files, the line table and the inlined frames. The
  globals and their `global_set` bytes are sized from it
  (`vm/loader.c:135-139`). A second `load_program_mem` would overwrite
  it. `docs/runtime.md:211-212` says it outright: "There is no dynamic
  loading afterwards: a program is one file, the basis library
  included."
* **Every operand is absolute and program-wide**: a `CALLK f`,
  `TAILCALLK f` or `CLOSURE d, f` names function `f` by its index, and a
  heap closure holds that index in its first field (`vm/new/reg_cases.h`);
  `GLOBAL`/`SETGLOBAL` index `vm->globals`; `CONST` and `NEWEXN` index
  `p->consts`; every jump, `PUSHHANDLER` and `SWITCH` table entry is an
  absolute code offset (`vm/new/regs.def:38`); so are `ret_pc` and a
  handler's `pc`; the line table's pcs, file indices and inlined-frame
  parents likewise. But the kinds are tabled: `rop_kinds` says which
  operand is `RK_FUNCTION`, `RK_GLOBAL`, `RK_CONSTANT`,
  `RK_STRING_CONSTANT`, `RK_LABEL` or `RK_HANDLER_LABEL`
  (`vm/new/isa_regs.c:17-34`; `op_kinds` for the stack set,
  `vm/isa_stack.c:130-146`), which is what lets a loader rebase a unit
  appended to the program without knowing the instructions.
* **The loop finds the program again after every primitive.**
  `RELOAD()` re-reads `code`, the constants and the function table
  after a `PRIM` (`RELOAD()`, `vm/new/interp.c:46`; `vm/interp.c:38`),
  since a primitive may have replaced the world (`PRIM_NEW_WORLD`,
  `vm/vm.h:363`). A primitive that grows the program's tables by
  `realloc` is therefore seen by tier 0 with nothing more; the line
  table stays sorted if a unit's code goes at the end; the collector and
  `heap_relocate` walk whatever `prog.nglobals` and `prog.nconsts` say
  (`vm/heap.c:111-112,221-222`).
* **Validation is of the whole file** (`validate_program`,
  `vm/isa_stack.c:107-185`; `vm/new/isa_regs.c:45-114`): operands
  against the counts, jump targets to their own function, functions
  contiguous with `code_end` the next offset, the deepest stack of each
  function. `runevm` treats a `.rbc` as untrusted input
  (`docs/runtime.md:207`); a unit must be held to the same.
* **Images carry the world** (`vm/image.c:155-257`): the heap, the
  whole `Program`, the globals, the built-in exceptions, the value
  stack, the frames and handlers, the open files; every value in 9
  bytes, so an image crosses word widths and byte orders, and never
  crosses an instruction set (the fingerprint is in the magic). `Runtime.save`
  writes one and resumes with `Saved` or `Restored`; `runevm --restore`
  carries on in another process; `Runtime.restore` becomes another
  world (`vm_become`, `image.c:686-714`). A REPL session whose static
  environment lives in the heap and whose code lives in the program is
  therefore snapshottable today, in one flat file: what Poly/ML's
  `SaveState` does without its parent-and-child hierarchy, and what
  SML/NJ's `exportML` does.
* **No signals, no threads, no `dlopen`.** `vm/sys.h` (272 lines) has
  files, processes, sockets, the registry and, since jit M3, executable
  memory (`sys_code_alloc`, `sys_code_protect`, `sys_code_flush`,
  `sys_code_free`, `vm/sys.h:267-270`); it has no signal handler (`SML90.Interrupt` is never raised,
  `weak-points.md:128-129`), no threads and no dynamic loading of
  anything.
* **The primitives** (`src/isa/prims.sml`, 297) have `rt_save`, "write
  the whole VM to a file", and `rt_restore`, "become the world in a file
  that `Runtime.save` wrote, bytecode and all"; `posix_exec`,
  `posix_spawn` and `os_system` start another `runevm` on another
  `.rbc`. Nothing brings bytecode into a running program.
* **`bin/rune` is bytecode on `runevm`**: `runevm --heap-size $(RUNE_HEAP)
  bin/rune.rbc --lib ...` (`Makefile:726-730`); `bin/rune-new` is the
  same compiler asked for register bytecode, still on `runevm`
  (`Makefile:688-690`).

### What the JIT gives, and withholds

jit M3 is committed (`38e3420`: `vm/new/jit.h`, `jit.c`) and M4 is in
the working tree (jit.md's Status). What this roadmap takes from it, and from the milestones after
it (`jit.md`, *Prerequisites and flags*: "Incremental compilation, the
REPL, dynamic modules, hot reload. Consumers of M3's entries, M6's and
M11's invalidation, and M8's metadata per unit"):

* **Code objects** (`jit.h:42-48`): one `CodeObject {entry, tier, size,
  calls, loops}` per function, in a `JitProgram {code, nfuncs, codes,
  ...}` that is "made when the driver first sees it, and again when the
  program changes (Runtime.restore)" (`jit.h:52-66`). A unit that
  arrives adds functions: the table grows, and `jit_entry` keeps
  working, since it indexes by function. The invalidation of M6 -- an
  entry reset to a stub, a frame returning into dead code returning
  through a stub -- is what a reload of a unit will use (M12).
* **The driver's no-nesting rule** (`jit.h:5-13`): one engine hands the
  VM back to the driver rather than calling another. A unit's top level
  is therefore not run from C: `rt_load` returns a closure and the SML
  side calls it (D7).
* **`--jit=all`** compiles every function at load (`JIT_ALL`,
  `jit.h:24`): the mode in which a unit that arrives is compiled at
  once, and the answer to why separate compilation need not cost speed
  (`jit.md`, *Why a JIT at all*: "the code that arrives is bytecode that
  no whole-program compiler saw; a JIT that compiles whatever arrives,
  and that recovers across units the inlining separate compilation
  lost, is what keeps that fast").
* **Poll points** (M6): counters at backward jumps and calls, "where a
  collector, a signal or a scheduler will poll later". An interrupt is
  a signal (D11).
* **Metadata per function** (M8): representations, loop heads and
  block starts in a section of the `.rbc`, "per function so that a unit
  of the incremental roadmap carries its own" (`jit.md`, M8).
* **Deoptimisation** (M11), if built: what lets a unit be reloaded
  while tier-2 frames of its old code are live.
* **What it withholds:** any notion of a unit. `JitProgram` is per
  program; the code cache is not in an image (jit D11); the interpreter
  is complete without it, so everything here works at `--jit=off` too.
* **What this roadmap gives back:** a compiler resident in the VM,
  which is what jit D7 C, "the metacircular tier", was waiting for.

### Today's build system

* **`sources.txt`** (47 files, ordered) is the compiler's own build
  list, and `sources-doc.txt`, `sources-opt.txt` and `sources-isa.txt`
  those of `runedoc`, `runeopt` and `runeisa`. `scripts/gen-build-files.sh`
  writes `build/PROG.mlb`, `build/PROG.cm` and a Poly/ML script of
  `use` lines from each; the Makefile compiles the self-hosted compiler
  as `bin/rune-boot -o bin/rune.rbc $(BOOT_SRCS)`. The header rule
  (`sources.txt:4`): "Files must contain only structure/signature/functor
  declarations", which is what SML/NJ's CM needs of them
  (`docs/building.md:367-391`, rule 2).
* **`lib/basis/MANIFEST`** (295 lines: 2 `always`, 174 `demand`, 73
  `seal`, 1 `final`) is a hand-maintained dependency graph of the Basis
  Library: `file | always|demand|seal|final | host | provides |
  requires`. A `demand` file is compiled for the programs that mention
  a name it provides and for the files that require it; a `seal` file
  re-ascribes a structure to its signature (`structure List : LIST =
  List`) for programs and never for the library; the one `final` file
  runs `RuneExit.run ()` after the program. `rune --basis-check` holds
  the columns to the sources and a demand file to modules and types
  only, so that the top-level environment does not depend on which
  files happened to load (`docs/architecture.md:182-207`). The
  selection is lexical (`namesOf` takes every identifier of the user's
  tokens, `basismanifest.sml:89-92`), so it may over-load and never
  under-loads.
* **Elsewhere:** the corpus harness (`/home/ruud/rune-corpus-sml97`)
  has its own `sources.txt` and a generated `corpus.mlb` for Millet;
  `millet.toml` points Millet at `build/rune.mlb`. Rune reads neither
  `.mlb` nor `.cm` (`weak-points.md:22-23`).

### HOL4 today: the host contract, measured

HOL4 (Trindemossen-2, `bdc6917`) builds on Poly/ML 5.9.2 or Moscow ML
2.01 (`INSTALL:6-14`); the copy at `/home/ruud/.local/hol4` was built on
Poly/ML on 2026-09-21. Its sources are 2,025 `.sml` and `.sig` files
under `src/`, of which 334 are `*Script.sml` theory scripts; `sigobj/`
holds 806 `.uo`, 806 `.ui` and 694 `.sig`; `bin/hol.state` is 13 MB and
`bin/hol.state0` 17 MB. What its Poly/ML layer actually asks of the ML
system, read in `tools-poly/`, `tools/Holmake/poly/` and
`src/portableML/poly/` of the `develop` branch:

1. **There is no separate compilation.** `Holmake`'s `poly_compile`
   (`tools/Holmake/poly/BuildCommand.sml:134-200`) compiles nothing: it
   writes `X.uo` and `X.ui` as text files listing the dependency
   modules (from `Holdep`) and then the source file, as
   `listTheory.uo` shows (`$(HOLDIR)/sigobj/Globals ...
   $(HOLDIR)/src/list/src/listTheory.sml`). `Meta.load`
   (`tools-poly/poly/poly-init2.ML:104-143`) reads the `.ui` and `.uo`,
   `use`s each `.sml` and `.sig` line and loads the rest recursively,
   remembering what it loaded in `loadedMods`. Loading is compiling
   from source again; the heaps are the cache.
2. **Heaps.** `buildheap -o` loads the objects, runs
   `PolyML.shareCommonData PolyML.rootFunction`, then
   `PolyML.SaveState.saveChild (heap, length (showHierarchy ()))`
   (`tools-poly/buildheap.ML:226-256`); `--holstate F` is
   `PolyML.SaveState.loadState F` (`:350-357`). `bin/hol` is
   `buildheap --gcthreads=1 --repl --holstate=$(heapname) Arbint
   Arbrat tools-poly/prelude.ML tools-poly/prelude2.ML "$@"`. A theory
   is built by `buildheap --holstate=HEAP ... XScript.uo -e "..." -c
   XTheory.sml ...` (`BuildCommand.sml:300-321`): everything from
   source into a heap, run the script, check that the files exist.
3. **The compiler as a function.** `QUse.use`
   (`tools-poly/poly/quse.sml:4-18`) loops `PolyML.compiler (infn,
   [CPFileName fname, CPLineNo line]) ()` over a character reader until
   the file ends; `prelude.ML:132` rebinds `use` to it. Poly/ML's
   signature: `compiler : (unit -> char option) *
   Compiler.compilerParameters list -> unit -> unit`, with
   `CPOutStream`, `CPNameSpace`, `CPErrorMessageProc`, `CPLineNo`,
   `CPLineOffset`, `CPFileName`, `CPPrintInAlphabeticalOrder`,
   `CPResultFun`, `CPCompilerResultFun`, `CPPrintDepth`,
   `CPPrintStream`, `CPErrorDepth`, `CPLineLength`, `CPRootTree`
   (the Poly/ML reference, *References*). The reader is
   `HolParser.fileToReader`, so the quotation filter is HOL's own
   Standard ML, in front of the compiler, not a separate process.
   `CompilerSpecific.quietbind` compiles a string with output
   discarded; `execompile.ML` compiles `val () = f ()` and
   `PolyML.export`s it, then links with `cc ... -lpolymain -lpolyml`.
4. **The REPL** (`tools-poly/holrepl.ML`, "derived from Poly/ML's
   implementation of its REPL"): per declaration `polyCompiler (readin,
   [CPOutStream TextIO.print])`, then the closure is run in the same
   heap; prompts from `PolyML.Compiler.prompt1/prompt2`, timing from
   `Compiler.timing`; a compile error is `Fail s`, after which the
   buffered input is flushed and the lexer remade; an uncaught
   exception is printed with `PolyML.Exception.exceptionLocation` and
   `prettyRepresentation` and then `reraise`d; a `--zero` mode
   terminates each reply with NUL for editors; `Signal.signal (2,
   SIG_HANDLE (fn _ => Thread.Thread.broadcastInterrupt ()))` turns
   Ctrl-C into `Thread.Thread.Interrupt`, caught by the loop.
   `HOL_Interactive.toggle_quietdec` silences the echo by setting the
   prompts to `""` and `print_depth 0`.
5. **Printing.** `PolyML.addPrettyPrinter` is called about 35 times by
   `prelude.ML` and 5 by `prelude2.ML` (terms, types, theorems,
   theories, maps, sets, simpsets, ...), each with a printer of type
   `int -> 'a -> 'b -> pretty` chosen by the static type of the value
   the top level prints. `print_depth` is set in 25 places.
6. **The portable layer** (`src/portableML/poly/MLSYSPortable.sml`,
   79 lines) is what HOL abstracts over the ML system: `Interrupt`,
   `listDir`, `pointer_eq = PolyML.pointerEq`, `ref_to_int`,
   `catch_SIGINT`, `md5sum`, `time` (with `Timer.checkGCTime`),
   `HOLSusp`, `reraise = PolyML.Exception.reraise`, `make_counter`,
   `syncref`. The Moscow ML version does the same with `Obj.magic` and
   `prim_val catch_interrupt`.
7. **Threads.** `src/portableML/poly/` carries Isabelle's `Future`,
   `Task_Queue`, `Par_Exn`, `Multithreading`, `Synchronized`,
   `Thread_Attributes` (with `uninterruptible` on `RunCall`) and
   `Standard_Thread`; `buildheap --mt=N` enables them
   (`buildheap.ML:391-399`). `sref-bootstrap.ML` bakes `Sref` and
   interrupt-safe locking into `bin/hol`.
8. **Shims Moscow ML left behind** (`poly-init2.ML:168-187`,
   `poly-init.ML:3`, `buildheap.ML:2`): `Mosml.run`, a `Word8` with
   `toLargeWord`, top-level `Path`, `Process` and `FileSys`,
   `exception Interrupt = SML90.Interrupt`, `Io = IO.Io`, `SysErr =
   OS.SysErr`, `structure BasicIO = SML90`.
9. **`Systeml`** has a fixed signature (`tools/Holmake/Systeml.sig`)
   that configuration fills per installation and ML system: `systeml`,
   `exec`, `protect`, `HOLDIR`, `POLY`, `POLYMLLIBDIR`, `DEFAULT_STATE`,
   `ML_SYSNAME`, `pointer_eq`, `canBindStr`, `bindstr`, and so on.
10. **Optional:** `PolyML.globalNameSpace` (12 uses: `allVal`,
    `allStruct`, `lookupVal`), `Compiler.forgetValue`, the parse-tree
    API (`PolyML.parseTree`, `PTtype`, `PTdeclaredAt`, about 20 uses)
    and `CPCompilerResultFun` in the IDE and LSP code
    (`tools-poly/lsp-server.ML`, 960 lines; `hol lsp`) and in the AI
    tools (`src/AI`, `src/tactictoe`).

Counts across the 47 files of `src`, `tools` and `tools-poly` that name
the API: `addPrettyPrinter` 39, `print_depth` 25, `Compiler.prompt*` 24,
`Exception.reraise` 17, `globalNameSpace` 12, `Pretty*` 30,
parse-tree functions about 20, `compiler` 6, `compilerVersionNumber` 6,
`pointerEq` 5, `exceptionLocation` 5, `export` 4, `SaveState.*` 6,
`shareCommonData` 2, `use` 2.

**In short, a host must provide:** a compiler callable on a character
stream that runs one top-level declaration at a time into a persistent
global environment, with file and line positions and hooks for output
and errors; a top level with prompts, a print depth, an echo of
bindings and type-directed user printers; exceptions with locations,
and `reraise`; SIGINT as an `Interrupt` exception; `use`; the shims;
heaps, or a substitute; and, for `--mt`, threads, or shims that run
futures at once. The owner has said the heaps need not be catered to
(`~/notes/virtual-machine.md:19`); images give them almost free (D13).
What Rune has of this today: images, `SML90.Interrupt` as an
exception that nothing raises, and nothing else.

**Measured on Poly/ML (M1, 2026-10-09)**, the baseline M5 is held to: a
fresh clone of the built copy (`bdc6917`), configured with Poly/ML 5.9.2
(`tools/smart-configure.sml`), built through `src/boss` and `bin/hol` --
the sequence files `kernel` and `core-theories` up to that line, as
`bin/build --seq=FILE --nograph -j 16` -- on an otherwise idle machine:

| | Poly/ML 5.9.2 |
|---|---:|
| `build` through `src/boss`, wall | 5 min 19 s |
| its processor time, user and system | 370 s and 40 s |
| its peak resident memory | 748 MB |
| theories built (`sigobj/*Theory.uo`) and objects (`sigobj/*.uo`) | 47 and 489 |
| `.sml` and `.sig` lines in the directories built | 245,533 |
| `bin/hol.state` and `bin/hol.state0` | 13.2 MB and 16.7 MB |
| `hol` started and ended, best of five | 0.43 s |
| `hol` with a declaration, a proof (`DECIDE`) or `load "pred_setTheory"` | 0.43 s each |

The heap's loading is the whole latency: a declaration or a small proof
adds nothing measurable to it. At the front end's 50,000 to 80,000 lines
a second (*What a compile costs*), compiling the 245,533 lines once would
take Rune about four seconds at tier 2; what HOL4's build spends is in
running proofs, which is the VM's speed and not this roadmap's.

**HOL4's sources obey Moscow ML's discipline** (*What the literature
says*): `X.sig` holds `signature X` and `X.sml` holds `structure X`
(HOL4 was written for Moscow ML, whose batch compiler requires it), so
the libraries are files of one module each; the `*Script.sml` files are
sequences of top-level `val` declarations that `use` runs. That
division is the one D15 makes: libraries are analysable, scripts are
input to the REPL.

## What is different for SML

Separate compilation is old and well understood for C, Modula and Java;
what makes it a research topic for Standard ML is the module language
and the Definition's view of a program. Each point below is a fact of
the language that a design here has to answer, with the answer it gets.

* **A unit is not a module.** In Modula, Java, OCaml or Haskell a
  compilation unit is a module with a name; in Standard ML a file is a
  sequence of top-level declarations of every kind -- `structure`,
  `signature`, `functor`, `val`, `datatype`, `infix`, `open` -- and
  signatures and functors cannot be components of structures. Swasey,
  Murphy, Crary and Harper (2006) made this the first principle of
  SMLSC: "It is tempting to identify compilation units with modules,
  but to do so would require that functors, signatures, and fixity
  declarations be permitted as components of modules", and "a unit is
  a series of Standard ML top-level declarations, given a name". Moscow
  ML took the other road, and its structure mode requires "a single
  Moscow ML structure declaration, binding the structure `unitid`" per
  file named after it (the Moscow ML Language Overview, section 11.1). **Answer:** a unit is
  a file of top-level declarations (D1); the file-per-module discipline
  is what makes automatic dependency analysis possible and is asked of
  the files that want it, never of all files (D15).
* **Dependencies are not syntactic in general.** Blume (1999) shows
  what a source-level analysis can find: the definition-use relation of
  module-level names, unique when every top-level definition is a
  module definition and there is no top-level `open` (the CM manual,
  2.4). A top-level `val x = ...` used by another file, an `infix` that
  changes how a later file parses, or a side effect one file relies on
  another having done, cannot be found by looking: SMLSC's design
  principle *Explicit dependencies* says so ("the side effects of one
  unit may influence the behavior of another"), and MLB makes the order
  explicit for that reason. **Answer:** an explicit order is the ground
  truth (D2, D16); the analysed graph of D15 is a derived convenience
  for files that obey the discipline, checked, and it is a DAG of files
  once it exists, the owner's question answered: the module language
  does not make the graph richer than a DAG, it makes it harder to
  find.
* **Functors are compile-time data here.** SML/NJ compiles a functor
  once, to a closure over the argument structure; MLton, MLKit and Rune
  expand it at each application (*The compiler today*). Under static
  interpretation a functor declaration produces no code -- Elsman
  (2026) writes it as the empty object, "for example when *d* is a
  functor declaration. All information needed to retain the declaration
  is then stored in the compilation basis contribution" -- and its
  clients need its body, with the environment it was declared in. A
  change to a functor body therefore recompiles every unit that applies
  it (the cut-off of D14 sees it as a changed assumption), which is the
  price of monomorphic modules and of `datatype` tags that are the
  argument's. Appel and MacQueen (1994) name this exact problem, from
  the other side: "the problem is particularly severe for ML because of
  its functor facility", since a dependency on a functor is a
  dependency on an implementation. **Answer:** the export basis carries
  functor bodies as AST with their definition-time basis (D4); a
  functor's clients compile against its body (D1); SC against a
  signature admits no functor (D17).
* **Generativity.** A `datatype` is a new type at every elaboration,
  an `exception` a new constructor at every evaluation, and a functor
  application makes fresh both. Rune's exceptions are dynamic already
  (`NEWEXN` at run time, `translate.sml:443-451`), so their
  generativity crosses units for free; its datatype constructors are
  static tags, so a datatype's identity across units is its stamp, and
  a stamp must name one datatype in the whole linked program (D3). Type
  names are the existential names of Elsman (2026) and Russo (2004):
  "results are identified up to consistent, capture-avoiding renaming"
  of the names a declaration generates, which is what lets an export
  basis be renumbered canonically for the cache and rebased at import.
* **Abstraction is seen through.** The compiler records what an opaque
  type stands for and the IRs use it (`Ty.realizations`); a unit
  compiled against a signature alone cannot. Russo's chapter on
  separate compilation makes the general point: compiling against a
  signature is compiling against an existential type, and two clients
  of the same abstraction only agree on its type if they refer to one
  implementation -- SMLSC's *definite references*: "if two separate
  units import a common unit, such as a well-known library, these units
  share a common understanding of the abstract types exported by that
  unit. No additional sharing specifications are required." **Answer:**
  IC by default, where every unit sees the actual bases before it
  (D2); SC only against a signature that fixes representation as well
  as types (D17); imports by unit identity (D18).
* **Programs are interactive in the Definition.** Chapter 8 "tacitly
  regards all programs as interactive": rules 187 to 189 skip a
  top-level declaration that fails to elaborate, and an uncaught
  exception discards that declaration's bindings but keeps its state
  effects. Rune is a batch compiler (`docs/language.md:27`). Elsman
  (2026) gives the session model as three rules over a static basis,
  a dynamic basis and a state, with the existential names of each
  declaration opened freshly, and proves that compiling each
  declaration as a unit and linking it into a persistent process
  simulates it. **Answer:** the REPL implements Chapter 8 (D12), batch
  mode keeps rejecting whole programs, and `docs/language.md` says
  both.
* **Type inference has context.** Overloading and flexible records are
  resolved at the end of a top-level declaration, and Rune today
  resolves flexible records by the end of the program
  (`docs/language.md:29`; `Elaborate.finish`). A unit, and a REPL
  declaration, end that context. **Answer:** `finish` per top-level
  declaration (M2); Rune's row changes to per declaration, which the
  Definition allows (unlimited context is the deviation, not the rule).
* **Small things that cross files:** an `infix` directive is in scope
  in every later file (`Main.fixity` is threaded through all of them);
  `it` is rebound by `exp ;`; `open` at top level puts a structure's
  contents into the top-level environment; the order of files is the
  order of effects. **Answer:** the fixity environment is part of the
  basis a unit exports (D4); the analysed graph refuses top-level
  `open` (D15); order is explicit (D2).
* **No types at run time.** A value carries a tag and nothing of its
  type, so printing `val it = ...` needs the compiler: Poly/ML generates
  printing code from the static type, Elsman (2026) sends type
  descriptions to the evaluator. Rune knows every top-level type at
  compile time. **Answer:** generated printers (D10).
* **Whole-program optimisation matters more than elsewhere.** MLton's
  case rests on it (Weeks 2006), and Rune's middle end already
  defunctorises by construction, shakes the Basis, and inlines and
  specialises across the program; separate compilation loses exactly
  that across unit boundaries, and Elsman (2008) built his framework to
  let "arbitrary compile time information propagate across program
  unit boundaries" for it. **Answer:** whole-program builds stay, from
  the cache (D6, M7); incremental builds lose cross-unit inlining at
  first (OCaml's `-opaque`) and the JIT recovers it at run time
  (jit D12).

## What the literature says

Each item: what it is, why it was built that way, what was measured
where anything was, and what transfers to Rune. Numbers are the
sources' own; the *References* give them.

### Separate and incremental compilation for ML

* **SML/NJ's binfiles and the visible compiler** (Appel and MacQueen
  1994). The compilation of a source file is a function from a static
  environment to a static environment plus code; the result is pickled
  into a *binfile*, "an important kind of cache", with the environment
  it was compiled in identified by a persistent identifier, so that a
  binfile is valid exactly when the same environment is in effect
  again. The compiler's internals are exposed to ML programs as "a set
  of internal compiler modules, a feature that they call the visible
  compiler", whose first client was CMU's incremental recompilation
  manager. Functors are closures at run time, so a functor body is
  compiled once. *Transfers:* the export basis as the value a unit is
  compiled against and produces (D4); the compiler as a library (D9);
  not the run-time functors.
* **Smartest recompilation** (Shao and Appel 1993) infers for each
  unit the least it assumes of its imports, by type inference over the
  free identifiers, so that a change elsewhere recompiles the unit
  only when it breaks an assumption the unit made. Elsman (2008)
  places it above smart recompilation (Tichy's: recompile when an
  interface you depend on changed) and below his own (recompile when
  an assumption you used changed, whatever the phase). *Transfers:*
  the principle that recompilation is decided by assumptions used, not
  by files touched (D14); not the inference of minimal interfaces,
  which Rune's IC model does not need.
* **CM** (Blume 1999; Blume and Appel 1999; the CM manual). CM "is
  largely source-oriented: Whereas with make one specifies the tree and
  lets the program derive the leaves, with CM one specifies the leaves
  and lets the program derive the tree". Its dependency analysis needs
  four rules of the sources: "All top-level definitions must be module
  definitions", one file per symbol per library, identical definitions
  where re-exported, and "The use of ML's `open` construct is not
  permitted at the top level of ML files compiled by CM". A library has
  an export list and members; groups are components with their own
  namespace; a *stable* library is one file that "can be used even if
  none of its original sources -- including the description file --
  are present". Recompilation is avoided when "The binfile has the same
  time stamp as the source" -- exactly the same, "This guarantees that
  all changes to a source will be noticed -- even those that revert to
  an older version" -- and "The current compilation environment for the
  source is precisely the same as the compilation environment that was
  in effect when the binfile was produced". The autoloader "cannot be
  turned off since it provides many of the standard pre-defined
  top-level bindings"; `CM.make` links by executing each unit's
  top-level code at most once per traversal, sharing state with the
  interactive system. *Transfers:* the analysis and its four rules
  (D15); stable libraries as the shape of the shipped Basis (D8);
  environment identity as the cache key, done with hashes instead of
  timestamps (D14); autoloading as an option of the REPL (D12).
* **MLB** (the MLton documentation; its formal semantics). "The order
  of files (and, hence, the order of evaluation) in the program is
  explicit"; a basis is a value with `bas`, `basis b = ...`, `local`,
  `open` and renaming of structures, signatures and functors at import;
  "A reference to an MLB file causes the basis denoted by that MLB
  file to be imported -- the basis at the point of reference does not
  affect the imported basis"; "Each MLB file is elaborated and
  evaluated only once, with the result being cached". No dependency
  analysis, no restriction on files. Annotations set per-file options
  and path maps name libraries. *Transfers:* the semantics of the
  build language (D16): bases as values, explicit order, one
  elaboration per file, path variables, annotations. The syntax the
  owner dislikes is not what is taken.
* **Static interpretation** (Elsman 1999) compiles Standard ML modules
  by interpreting the module language at compile time -- a functor
  application copies and specialises the body -- so that the core
  language's optimisations see monomorphic code, at the price of code
  per application and of a functor being a compile-time object. It is
  Rune's design already. *Transfers:* the treatment of functors in the
  export basis (D4), and the reason a functor's clients depend on its
  source (*What is different for SML*).
* **Cut-off incremental recompilation with inter-module
  optimisation** (Elsman 2008). The framework that runs MLKit: each
  translation phase of the compiler is a judgement from an environment
  and a program unit to an export environment and a translated unit,
  with the names it generates existentially bound; compilation is the
  composition of the phases; a *compilation basis* is the tuple of all
  phases' environments; a unit is recompiled if its source changed or
  "the assumptions under which the source file was previously compiled
  have changed", the assumptions being the basis restricted to the
  names the unit used, compared up to renaming. The framework "allows
  even open terms (objects containing free occurrences of names) to
  propagate across program unit boundaries at compile time", which is
  what lets inlining and region information cross units. Its example:
  change `val a1 = 5` to `4` in unit A; with types only propagated,
  nothing else recompiles; with constant propagation, B and D do and C
  does not. Measured on programs of "more than 250.000 lines of
  Standard ML" in day-to-day development. MLKit's MLB page adds the
  practical device: when a unit is recompiled, "the MLKit seeks to
  match the new exported information to the old exported information by
  renaming generated names", so that clients see no change where there
  is none. *Transfers:* the whole of D14's cut-off and D4's basis as a
  tuple of what each phase needs; canonical renumbering of an export
  basis (D3); the model in which a unit's object may carry Mid for a
  later whole-program pass (D6).
* **SMLSC** (Swasey, Murphy, Crary and Harper 2006; the revised report
  CMU-CS-06-133). A language, not a tool: `unit U = top ... end` with
  `import V` (incremental compilation: V's interface is inferred from
  its source) or `import V : intf ... end` (separate compilation: V
  need not exist); interfaces are `spec`s plus functor specifications;
  imports are definite references, "unit names have global scope and
  cannot be shadowed"; a *handoff unit* is a unit whose body is an SC
  import of the implementation, so that clients import the handoff
  unit by IC and never repeat its interface. "Compatibility with
  existing compilers, including whole-program compilers, is assured by
  making no commitment to the precise meaning of 'compile' and 'link'
  -- a compiler is free to limit compilation to elaboration and type
  checking, and to perform code generation as part of linking."
  Elsman (2008) notes that SMLSC "does not provide separate
  compilation for implementations of Standard ML that critically depend
  on propagating information other than language-level types across
  program unit boundaries". *Transfers:* IC and SC as the two modes
  (D2); definite references by unit identity (D18); the freedom to
  generate code at link time, which is D6's whole-program path; the
  handoff pattern is what a virtual module's signature is (D17). Not
  the language extension: the build language names units, not the
  source.
* **Selective recompilation measured** (Adams, Tichy and Weinert 1994)
  measured smart recompilation on real change histories and found that
  what remains when recompilations are cut is the cost of reading the
  environments the survivors need. *Transfers:* the export basis is
  pickled with sharing and loaded lazily, elaboration bases first and
  compilation bases when a unit needs them, as MLKit's REPL does
  (Elsman 2026, 5.3).
* **Moscow ML units** (the Language Overview, section 11). Structure mode: `unitid.sig`
  declares `signature unitid`, `unitid.sml` declares `structure
  unitid`, compiled to `.ui` and `.uo`, loaded with `load "unitid"`;
  toplevel mode: a file of declarations with a specification as its
  interface, where Moscow ML "will issue warning" if the implementation
  declares more than the interface says. `load` in the interactive
  system is what HOL4's `Meta.load` imitates. *Transfers:* the
  file-per-module discipline as the analysable case (D15); the `.ui`
  as the interface a client is checked against (D17, D18).
* **Types for modules** (Russo 2004; his 1998 thesis). Type names as
  existentially quantified, signature matching by instantiation,
  higher-order and first-class modules on that basis; the chapter on
  separate compilation shows that compiling against a signature is
  sound when the signature's abstract types are treated as unknowns
  shared through one definite implementation, and fails when two
  clients each guess. Dreyer, Crary and Harper (2003) give the type
  theory of higher-order modules, applicative and generative, that the
  owner's module-calculus notes build on. *Transfers:* the ABI
  signature of D17 and the fingerprint-and-identity check of D18 are
  the practical form of definite references.

### REPLs and resident compilers

* **Poly/ML** (the reference manual). `PolyML.compiler` compiles one
  top-level phrase from a character reader into a `unit -> unit`
  closure that, when run, performs the declaration's effects and
  enters its bindings into a name space (the global one by default);
  the function "is thread-safe". `NameSpace` is a record of lookup,
  enter and enumerate functions per namespace; `SaveState.saveState`
  "saves the current values of all the mutable data (i.e. refs and
  arrays) that were present in the executable together with any other
  data that is now reachable from it", `saveChild` saves only what a
  parent does not have, and "a saved state can only be loaded into the
  executable that created it"; `saveModule`/`loadModule` package
  structures, signatures and functors with a start-up function.
  `addPrettyPrinter` installs a printer by type. HOL4 is built on all
  of it (*HOL4 today*). *Transfers:* the shape of `Compiler.compile`
  and of printing (D9, D10); images stand in for `SaveState` (D13).
* **SML/NJ** compiles interactively to native code and offers `use`,
  `CM.make` and `CM.autoload` in the same top level; `SMLofNJ.exportML`
  writes the whole heap. *Transfers:* the interactive system is the
  compiler with its library resident; autoloading.
* **A REPL for a compiled, optimising ML** (Elsman 2026, DIKU
  technical report of 2026-09-19, with a Rocq development). "Each
  interaction forms a compilation unit. A compiler process generates
  shared libraries, and a persistent evaluation process loads and
  executes them; UNIX named pipes connect the processes"; the
  evaluator `dlopen`s each library and runs its initialiser; printing
  is *type-indexed*: the compiler sends a type description and a
  symbol, and a generic printer in the evaluator interprets the
  description over the native value, since MLKit's records carry no
  tags and its datatypes may carry no constructor object. A session is
  modelled as static basis, dynamic basis and state; an uncaught
  exception "retains state effects without extending the static or
  dynamic basis" but the loaded object stays; the paper states the
  compiler properties (correctness, existence, agreement on rejection,
  layout, renaming) under which compiled sessions simulate the source
  model, and mechanises the name-uniqueness half in Rocq. Its loader
  microbenchmark: 1,024 shared libraries in 0.050 s on Linux and 12.3 s
  under Rosetta, with per-load cost growing with the number loaded;
  "garbage collection is disabled in the tested MLKit REPL". *Transfers:*
  a declaration as a unit, the retained compilation basis, the
  exception rule and the session model (D12); the two-process design is
  the option this roadmap keeps for later, since HOL4 needs the
  compiler in the same process (D9); type-indexed printing is what Rune
  does not need, its values being tagged and its types known (D10).
* **CakeML** (Kumar et al. 2014; Sewell et al. 2023). A verified REPL,
  and then `Eval`, "dynamic computation" in which code compiled at run
  time shares values with and calls the running program. *Transfers:*
  the design point of compiling into the same heap and the same code
  space, which is D7's `rt_load`.
* **GHCi, OCaml's toplevel, Cling.** GHCi interprets bytecode beside
  compiled code and can run it in an external interpreter process over
  pipes; OCaml's toplevel executes bytecode and `#install_printer`
  chooses printers by type; Cling keeps Clang's state across inputs and
  JIT-compiles each fragment. *Transfers:* the external process as an
  option; printers by type; a JIT that compiles what arrives is normal.

### Recompilation avoidance elsewhere

* **GHC** (`GHC/Iface/Recomp.hs`). An interface file carries the
  source hash, the flag hash, the ABI hash of the module, the export
  hash, a fingerprint per declaration -- the MD5 of the declaration
  with the fingerprints of the names it refers to substituted for the
  names, so that a change anywhere below changes it -- and the
  *usages*: for each imported home module, the fingerprints of the
  entities this module used. A module is recompiled when its source
  hash, its flags, or a used entity's fingerprint changed; the reasons
  are enumerated (`RecompReason`), and `-ddump-hi-diffs` says which.
  Recursive groups are fingerprinted together; orphan instances are
  hashed separately since no name refers to them. *Transfers:* the
  configuration hash and the recorded usages of D14, and an
  `--explain-rebuild` that names the reason.
* **rustc** (the dev guide). A query system with a dependency graph in
  which "if a query is colored red, that means that its result during
  this compilation has changed from the previous compilation", and
  try-mark-green concludes a query is unchanged when all its inputs
  are, without re-running it. *Transfers:* the idea, at the granularity
  of a unit; a query-per-declaration compiler is the compiler as a
  service of M12 and not this roadmap.
* **OCaml** (`.cmi` digests, `-opaque`, `Dynlink`). An interface has a
  CRC; an object records the CRCs of the interfaces it was compiled
  against; the linker and `Dynlink` refuse an inconsistent assumption
  (`Inconsistent_import`); `-opaque` compiles a module so that its
  clients do not depend on its implementation, for the sake of
  recompilation. `Dynlink.loadfile` "links it with the running program"
  and "All toplevel expressions in the loaded compilation units are
  evaluated"; `allow_only` and `prohibit` restrict what loaded code may
  see. *Transfers:* the fingerprint of an export interface as what a
  dynamic module is checked against (D18), `-opaque` as the first
  incremental mode (D6), and the fact that a mature system does
  exactly this.
* **Build systems à la carte** (Mokhov, Mitchell and Peyton Jones 2018,
  2020). A build system is a *scheduler* (topological, restarting or
  suspending) and a *rebuilder* (a dirty bit, verifying traces,
  constructive traces or deep constructive traces): make is
  topological with a dirty bit, Shake suspending with verifying
  traces, Bazel restarting with constructive traces, Nix suspending
  with deep constructive traces. *Transfers:* Rune's cache is a
  constructive-trace store, content-addressed, so that switching
  branches or reverting a file finds what was built before (D14); the
  build of M11 is topological over the graph of M8, and its correctness
  argument is the paper's.

### Dynamic loading and typed linking

* **Alice ML** (Rossberg 2006, "The missing link"): components with
  import and export signatures, lazily linked; packages, `pack S : SIG`
  and `unpack e : SIG`, that carry a signature and are matched at run
  time, so that dynamically loaded code is checked once, at the
  boundary, against a statically known signature. *Transfers:* D18's
  `_dynamic "path" : SIG` is a package unpacked at load, checked by
  fingerprint rather than by a run-time signature match.
* **Typed assembly and linking** (Glew and Morrisett 1999; Hicks,
  Weirich and Crary 2001): object files with typed import and export
  interfaces, and a link-time check that makes the linked program
  well-typed by construction; dynamic linking of native code kept safe
  by the same interfaces. Cardelli (1997) is the model both Elsman
  (2026) and this roadmap use for linksets: an object with an import
  interface, an export interface and a body, linked by substitution.
  *Transfers:* the unit format has import and export tables that the
  loader checks (D6, D7), and `runevm`'s validation of bytecode stays
  the safety net below them.

### Hot code replacement

* **Erlang** keeps two versions of a module, current and old: "Both
  old and current code are valid, and can be evaluated concurrently";
  a fully qualified call `m:f()` goes to the current code, a local call
  stays in its version; loading a third version purges the old one and
  "Any processes lingering in it are terminated"; release handling adds
  `code_change` callbacks for state. *Transfers:* the semantics M12
  prototypes: a unit reloaded is a new unit, old closures keep old
  code, calls through the export table switch, and the JIT's
  invalidation (jit M6, M11) handles the code that called the old
  functions directly.
* **Dynamic software updating** (Hicks and Nettles 2005): updates at
  chosen points, type-safe by construction, with state transformers
  for changed representations; the literature's conclusion is that
  the update points and the state transformation, not the code
  swapping, are the hard part. Dart's hot reload, Java's HotSwap
  (method bodies only) and .NET's edit-and-continue are the engineered
  forms, each restricting what may change. *Transfers:* the review M12
  writes, and the reason it is a research milestone: code replacement
  is cheap after M3, state migration is not.

### Build languages and late binding

* **Dune's virtual libraries.** A library lists `virtual_modules`, each
  an `.mli` without an `.ml`; an implementation declares `implements`
  and supplies the `.ml`s; "It's impossible to link more than one
  implementation for the same virtual library in one executable"; "a
  module in an implementation either implements a virtual module or is
  private"; a `default_implementation` applies when nothing else was
  chosen; "It isn't possible to load virtual libraries into `utop`".
  *Transfers:* D17 in full, restrictions included, since they follow
  from compiling clients against the interface alone.
* **Backpack** (Kilpatrick, Dreyer, Peyton Jones and Marlow 2014):
  packages with signature files as holes, filled by other packages at
  the package level, with the type identities unified at instantiation.
  A virtual module is Backpack's one-hole case. *Transfers:* the
  reminder that filling a hole must unify type identities across every
  client, which definite references give (D18) and `where type` in the
  build language expresses (D16).
* **Package managers** -- Smackage for Standard ML, opam, cargo, Nix --
  are surveyed in M12; their common ground is a lock file over
  content-addressed sources, which the cache of D14 makes natural.

### What the numbers say

| Measured | Result | Source |
|---|---|---|
| Rune: a two-line program using `List` and `TextIO` | 1.8 s on `bin/rune`, 0.1 s on the MLton build; the Basis elaborated every time | `weak-points.md:24-31` |
| Rune: `hello`; the compiler compiling itself | 21.7 ms; 5.03 s on `runevm` | `performance.md:93-104` |
| HOL4: modules, scripts, heaps | 806 `.uo`; 334 theory scripts; `hol.state` 13 MB, `hol.state0` 17 MB | `/home/ruud/.local/hol4` |
| MLKit's cut-off recompilation | day-to-day development on over 250,000 lines | Elsman 2008 |
| MLKit's REPL loader, 1,024 libraries | 0.050 s Linux; 12.3 s under Rosetta; per-load cost grows with the count | Elsman 2026, table 1 |
| CM's freshness rule | timestamp equal, and the compilation environment "precisely the same" | the CM manual, 2.3 and 11.1 |
| GHC's recompilation | source hash, flag hash, per-entity usages; reasons enumerated | `Recomp.hs` |
| Dune | one implementation of a virtual library per executable | the Dune manual |

### What transfers to Rune

1. **Elsman's framework is the model**, since Rune is a static
   interpreter of modules with an optimising middle end as MLKit is:
   a compilation basis per phase, assumptions recorded per unit,
   recompilation on changed assumptions, open terms allowed across
   units.
2. **IC by default, SC on request** (SMLSC): the actual bases of the
   units before, in an explicit order (MLB); a signature alone only for
   virtual and dynamic modules, with representation fixed by it.
3. **A declaration is a unit** (Elsman 2026, CakeML): the REPL is the
   incremental compiler at the granularity of one declaration, linked
   into the same process (Poly/ML, since HOL4 requires it).
4. **Environment identity by hash, never by time** (CM's lesson, GHC's
   practice); the cache as a constructive-trace store.
5. **Dependency analysis under CM's four rules**, as a convenience for
   files that obey them; explicit order as the escape hatch.
6. **Definite references and interface fingerprints** for anything
   loaded at run time (SMLSC, OCaml).
7. **Virtual modules as Dune has them**, restrictions included.
8. **Heaps are images** already; hot reload is two versions and
   invalidation, later.

## Constraints

* **Five builds, one output.** The compiler builds with MLton, SML/NJ
  (64 and 32 bits), Poly/ML and itself, and all five write the same
  bytes (`make check-cross`). Whatever this roadmap renumbers,
  serialises or reorders is a deterministic function of the sources and
  the flags, and the whole-program build of a program from its cached
  units is byte-identical to its build from source (M7's oracle).
* **`--count` is the oracle where the program is the same.** A
  whole-program build stays held to its budgets and to `runeopt` and
  `vm/new` as today. An incremental build is a *different* program --
  fewer inlinings, more calls -- so between the two the oracle is the
  output, the exit status and the traces, as `make check-levels` already
  compares `-O0` with `-O2`; `make check-units` (M3) is that comparison
  between per-file and whole-program builds.
* **Images stay in bytecode terms** (jit D11) and carry the program
  whole: a unit loaded into a VM is in the next image as part of its
  program, with no unit boundaries the image needs to know (M3).
* **The VM stays C, with the driver's rule.** `rt_load` is a primitive
  (`src/isa/prims.sml`, `make isa`); it appends, validates and returns
  a closure; the unit's top level is run by the SML side, never by a
  nested loop. A `.rbu` is untrusted input as a `.rbc` is.
* **No native code here.** Units are bytecode; the unit header has a
  code kind so that a native unit can be a second kind in a later
  roadmap; `runeopt` is unchanged and native programs load nothing
  (`vm/image.c:697-707` refuses even an image of another program).
* **The repository's rules** (`AGENTS.md`): every change to what the
  language accepts -- `use`, the REPL's semantics, `_dynamic`, the
  build language's effect on a program -- is a row of `docs/language.md`
  with a test in `tests/lang`, or a suite of its own named there
  (`tests/repl`, `tests/incremental`, `tests/buildfile`); the instruction
  set and the primitives change through their descriptions; a signal
  handler goes behind `vm/sys.h` and every layer answers it; a change to
  the VM core, `vm/sys.h`, the loader or `vm/image.c` passes `make
  windows`, `make test-windows`, `make portability` and
  `make test-portability`, the sanitiser build and `make test-stress`;
  `.expected` files are reviewed by hand; one commit per milestone with
  `make check` green.
* **Whole-program compilation is kept**, as the owner asked and as
  production needs: `rune a.sml b.sml -o p.rbc` keeps meaning what it
  means, at every `-O`, with the same bytes.
* **The lasting record is `docs/`, not this file.** What each
  milestone builds is written into `docs/units.md` (units, bases,
  objects, the cache, the linkers), `docs/repl.md` (the REPL, `use`,
  the `Compiler` structure, printing, Chapter 8), `docs/build.md` (the
  build language, its grammar and semantics), the rows of
  `docs/language.md`, the unit format in `docs/bytecode.md`, loading in
  `docs/runtime.md`, and `vm/new/ARCHITECTURE.md` for what the VM
  learned. HOL4's port layer lives in a fork of HOL4 the owner names,
  documented there and pointed to from `docs/repl.md`. This roadmap is
  retired when done, as the others were.
* **Other sessions commit on the branch** while a milestone is in
  progress (jit M2, M3 and M4 landed while this was written). `git log`
  and `git status` before every commit.

## The architecture

```
  sources (files; a REPL declaration; a build file naming them)
     │  one unit each, compiled in order against the compilation basis:
     │  the export bases of the units before it (IC), or a signature (SC)
     ▼
  the compiler, batch or resident in the VM
     per unit: parse ─► elaborate ─► translate ─► Mid, unit-local passes
                  │                                   │
                  ▼                                   ▼
            export basis (.rbi)              Mid of the unit ─► lower ─► unit bytecode (.rbu)
            names, types, functor bodies,    self-contained         imports, exports, relocations,
            fixity, reps, arities, usages                            metadata per function
                  │                                   │                      │
                  └──────────── .rune/ cache: content-addressed, configuration hash, usages
                                                      │                      │
        whole-program build (production):             │                      │
          concatenate the Mid of every unit ─► shake, lift, workers, simplify, lower ─► one .rbc
        incremental build:                                                   │
          the static linker: units ─► one .rbc (rebased by operand kind) ◄───┘
        the REPL, use, dynamic modules:                                      │
          rt_load: a unit ─► appended to the running VM's program, validated, ─► its closure, run
                             code objects added (jit M3), compiled on arrival (--jit=all)
```

**A unit and its basis.** A unit is a file of top-level declarations,
or one declaration typed at the REPL (D1). It is compiled against a
*compilation basis*: one value that holds everything the elaborator
and the later phases know before the unit -- the environment,
signatures, functors with their bodies and their own definition-time
basis, fixity, overloading, the `Ty` tables, the primitive aliases,
and what the middle end and `Lower` want of earlier units: constructor
layouts, worker arities, the bodies small enough to inline (D4). The
basis before a unit is the sum of the *export bases* of the units
before it (Elsman's `+`), and what the unit contributes is its export
basis: the delta. In the REPL the basis lives in the heap; on disk it
is pickled with sharing and renumbered canonically (D3, D14).

**A unit's object** is three things (D6): its export basis (`.rbi`);
its Mid after the unit-local passes, self-contained (the constructor
layouts written into it, so `Lower` needs no table); and its bytecode
(`.rbu`): the sections of a `.rbc` for the unit alone, plus an import
table (which unit's which export, by identity and fingerprint), an
export table (name to global or function), a relocation table (every
operand of kind function, global, constant, label or handler label, by
offset), and jit M8's metadata per function. Names inside a unit are
local, from 0; nothing in a `.rbu` depends on where it will be linked.

**Two linkers, one relocation** (D7). The static linker, in the
compiler, resolves a list of units into one `.rbc`: it assigns each
unit a base for its functions, globals, constants and code, rewrites
every operand by its kind, joins the tables, and makes a function 0
that calls each unit's top level in order. The VM's `rt_load` does the
same to a running program: it appends the unit's code, functions,
constants, globals and debug tables, rewrites the operands with the
bases it chose, checks the imports against the exports it has (identity
and fingerprint), validates the unit's code as the loader validates a
file, grows the JIT's code objects, and returns the closure of the
unit's top level, which the caller runs. Both are held to the same
relocation by test: a program linked statically and the same units
loaded one by one print the same and count the same.

**The cache** (D14) is a directory of objects named by content: under
a configuration hash (the compiler's identity, the `.rbc` version and
instruction-set fingerprint, the flags that change output), an entry
per source hash holding the three parts of the object and the unit's
*usages*, the fingerprints of the basis entries it used. A compile
looks the entry up, checks the usages against the bases it would
compile against, and either loads the object or compiles and stores.
Nothing in it is time.

**The resident compiler and the REPL** (D9 to D12). The compiler is a
library of units loaded into the VM beside the program; `Compiler.compile`
takes a character reader and options, compiles one top-level
declaration as a unit against the session's basis, loads it with
`rt_load` and returns the closure that runs it; `use` reads a file
through it; `rune-repl` is a program that reads declarations, calls
`Compiler.compile`, runs the closure, prints the bindings by the
printers the compiler generated, and follows Chapter 8 on errors and
exceptions. The session's basis is data in the heap, so `Runtime.save`
of the REPL is a heap with its compiler, its library and its bindings:
the boot image of the REPL and the `hol.state` of HOL4.

**The build language** (D15 to D17) names units and their order,
groups whose order is found by analysis, libraries with export lists,
virtual modules and what implements them, packages by path variable,
and per-unit annotations. It elaborates to a list of units with their
bases and their mode (IC, or SC against which signature), which is what
every build above consumes; from it the `.mlb`, `.cm` and Poly/ML
scripts of the hosts are generated, so the bootstrap keeps building.

**Where the JIT plugs in.** At the code objects (a unit adds
functions); at `--jit=all` (a unit is compiled on arrival); at the poll
points (interrupts); at the metadata (each unit carries its own); at
invalidation and deoptimisation (reload, M12). Nothing here changes a
tier.

**Where the language server plugs in, later.** The export basis keeps
spans and per-declaration positions; the cache is its store; the
resident compiler, driven by a protocol instead of a terminal, is the
compiler as a service (M12). No work on it here.

## Decisions

Each gives the options, what favours each, and the recommendation it
was written with. The owner decided all but D10 on 2026-10-09, as
recommended; D10 was reviewed that day against the word layout and
waits for the owner:

| Decision | Recommended | Chosen |
|---|---|---|
| D1. What a unit is | A: a source file; a REPL declaration; functor bodies compiled at each application | A, "for now to keep strict SML'97 semantics"; B may be considered for Rune 2.0 |
| D2. Incremental or separate compilation | A: IC against the actual bases before it, in explicit order; SC only against a signature, for virtual and dynamic modules | A, "for now to keep strict SML'97 semantics"; B may be considered for Rune 2.0 |
| D3. Names across units | A: stamps stay `int`, local per unit; canonical renumbering at export, a base added at import and link | A |
| D4. The compilation basis | A: one record with deltas, holding what every phase needs; spans kept | A |
| D5. Memory before disk | A: the front end and back end made resumable and per-unit first (M2); serialisation after (M6) | A |
| D6. What a unit object holds | A: export basis, self-contained Mid, unit bytecode; whole-program builds from the Mid | A |
| D7. Linking | A: a static linker in the compiler and `rt_load` in the VM, one relocation, cross-checked; `rt_load` returns a closure | A |
| D8. The Basis and the compiler as units | A: the compiler is the first client of unit builds; the Basis ships as one frozen library | A |
| D9. The resident compiler | A: in-process, Poly/ML's model; a two-process front end later if wanted | A |
| D10. Printing at the top level | A: printers generated per declaration from the static type, plus a registry by type name | reviewed on 2026-10-09 (below): A still holds, B is not required; A's reason rewritten; decided A by the owner on 2026-10-09 |
| D11. Interrupts | A: a flag set by a handler behind `sys.h`, polled at the JIT's poll points, raised as `Interrupt`, maskable | A |
| D12. The REPL's semantics | A: Chapter 8: skip a failed declaration, keep effects of one that raised; errors recoverable per declaration | A |
| D13. HOL4 | A: a port layer in a HOL4 fork; images as heaps; single-threaded shims; the owner may stop before it | A |
| D14. The cache | A: `.rune/` per source directory by default, relocatable; content-addressed under a configuration hash; cut-off by usages; no timestamps | A |
| D15. The dependency graph and the file discipline | A: analysis for files with module-only top levels, checked; an explicit list as the escape hatch; nothing restricts `rune` | A |
| D16. The build language | A: a language of Rune's own with MLB's semantics, groups, virtual modules, packages, annotations; host build files generated from it | A |
| D17. Compiling against a signature alone | A: an ABI fixed by the signature: slots, tags and layouts in signature order, calls through wrappers, no functors | A |
| D18. Dynamic modules | A: `structure X = _dynamic "path" : SIG`, checked by interface fingerprint at load; plus an untyped `Dynamic.load` | A; C may be considered for Rune 2.0 |
| D19. The second part | as recommended: whole-program from the cache, parallel and reproducible builds; reload, service and packages as research with a decision each | as recommended |

### D1. What a unit is

**Decided: A**, a source file (2026-10-09), as recommended. "For now to keep strict SML'97 semantics": B may be considered for Rune 2.0.

* **A. A file of top-level declarations; a REPL declaration; a functor
  body compiled at each application in the applying unit.** The unit
  CM, MLB and SMLSC agree on; the file is what a build language names
  and what an editor saves; a declaration is a unit because the REPL
  needs one and the Definition's Chapter 8 is written at that grain.
  Functor bodies stay source in the export basis (static interpretation,
  as today), so a functor's clients compile against its body and are
  recompiled when it changes.
* **B. A module: one structure per file, named after it** (Moscow ML,
  HOL4's libraries). Makes analysis trivial and separate compilation of
  a structure's clients possible, and rules out most existing SML, the
  Basis Library's files and every script. The discipline is kept as the
  *analysable* case (D15), not as the unit.
* **C. A top-level declaration everywhere.** The finest grain, and the
  most bases: a file of 200 declarations would carry 200 export bases
  and 200 objects. The REPL is this case; batch compilation is not.

### D2. Incremental or separate compilation

**Decided: A**, incremental by default (2026-10-09), as recommended. "For now to keep strict SML'97 semantics": B may be considered for Rune 2.0.

* **A. IC: each unit compiled against the actual export bases of the
  units before it, in an order the build says; SC only against a
  signature, where a virtual or dynamic module asks for it.** IC is
  what CM, MLB and MLKit do and what SMLSC calls the default; it keeps
  abstraction seen through, known calls known and small functions
  inlinable across units, at the cost that a change in a unit's export
  basis reaches its dependents (cut-off limits it to what they used,
  D14). SC gives representation-independent code for the two features
  that need it (D17).
* **B. SC everywhere, against hand-written interfaces** (Moscow ML's
  `.sig`, SMLSC's `import U : intf`). True separate compilation, at the
  cost of an interface per file, of every cross-unit call being unknown,
  and of Rune's monomorphic modules losing their reason. Elsman's
  remark applies: it "does not provide separate compilation for
  implementations ... that critically depend on propagating information
  other than language-level types".

### D3. Names across units

**Decided: A**, integers, local per unit, rebased (2026-10-09), as recommended.

* **A. Stamps stay `int`; every unit numbers from 0 (type names from
  100, since 0 to 99 are the builtins, and type variables from 0); in
  a session the counters simply go on, since nothing there needs to be
  reproduced; an export basis written to the cache is renumbered
  canonically in the order a traversal of its exports meets the names,
  so that the same declarations always get the same numbers whatever
  came before (Elsman's equality up to renaming; MLKit's matching of new
  exports to old); at import and at link a unit's names are rebased by
  a base that is the sum of the counts of the units before it in the
  build's order, one kind-directed traversal per representation
  (`MidText` already walks every binder of Mid).** Global and function
  indices are assigned per unit in definition order and rebased the
  same way, which also fixes today's first-use order (`code.sml:137`).
  The lints keep their whole-program uniqueness after linking. The
  five builds stay byte-identical because every step is a function of
  the sources and the order.
* **B. A stamp is a pair, `(unit, local)`.** Cleaner to read and
  impossible to confuse, and it touches every `IntTable`, every IR,
  every lint and `MidText`: an XL change for what A does with a base.
* **C. One counter for everything and Elsman's renaming at every
  import**: open each imported basis with fresh names. Correct, and it
  renames the functor bodies, the `Ty` tables, the `Rep` cache, the
  overloads and the inlinable Mid at every import, destroying the
  sharing between sessions that the cache exists for.
* **D. Content hashes as names** (GHC's fingerprints). Stable across
  everything and 16 bytes wide in every table; they are kept for what
  they are good at, cut-off (D14), and not used as names.

### D4. The compilation basis as a value

**Decided: A** (2026-10-09), as recommended.

* **A. One record, `Basis.t`, with a delta type, holding what every
  phase needs of the units before:** the elaborator's environment,
  signatures, functors (parameter signature, body AST, and the basis
  they were declared in, as today's `FunInfo`), fixity, the overloading
  registry's entries, the `Ty` tables' entries (binders, exception
  arguments, datatypes, realisations), the primitive aliases; and, for
  the middle end and `Lower`, each exported function's arity and worker,
  each datatype's constructor layout (`Rep`), and the Mid of the
  functions small enough to inline; with the source spans of every
  declaration kept, for error messages and for the language server.
  Type variables are zonked before export; the pending lists are empty
  at a unit's end by construction (D12). Serialised with sharing, in
  the style of Elsman (2005): a type-specialised pickle with a version
  and the compiler's identity in its header.
* **B. The static environment only** (Appel and MacQueen's binfile
  environment), the rest recomputed. Simpler to write and it forbids
  every cross-unit optimisation, since `Lower` would not know a callee's
  arity nor `Rep` a constructor's layout: the JIT would have to recover
  even known calls.
* **C. `MidText` as the whole interface** (middle-end's *Ready for*).
  Mid carries types but not the elaborator's environment, signatures,
  functor bodies or fixity; it is the second part of the object (D6),
  not the basis.

### D5. Memory before disk

**Decided: A** (2026-10-09), as recommended.

* **A. Make the compiler resumable in memory first** (M2): `elabTop`
  takes a basis and returns a delta; `Elaborate.finish` and the
  pending lists run per top-level declaration, since a nested `use`
  runs during the execution of the enclosing one; a compile error
  rolls back the elaborator's state (signatures, functors, fixity,
  overloads, `Ty` entries, counters) to the declaration's start; the
  back end runs per unit with the whole-program passes off; the export
  table is made. Then serialise what M2 learned the basis must hold
  (M6). The REPL (M4) and HOL4 (M5) need only the first half; HOL4 on
  Poly/ML has no cache at all (*HOL4 today*).
* **B. Design the on-disk format first and make the REPL read it.**
  Elegant and slow to a REPL: the format would be designed before the
  in-memory version has shown what it must carry, and revised once.

### D6. What a unit object holds

**Decided: A** (2026-10-09), as recommended.

* **A. Three parts: the export basis (`.rbi`); the unit's Mid after
  the unit-local passes, made self-contained by writing each
  constructor's layout into it in `ToMid` (so that `Lower` reads no
  table); and the unit's bytecode (`.rbu`), with import, export and
  relocation tables and jit M8's metadata per function.** A
  whole-program build concatenates the Mid of every unit and runs the
  passes of today over it -- `Shake`, `Lift`, `Workers` (made
  idempotent over units already split), `Simplify`, `Lower` -- to one
  `.rbc` that is byte-identical to the build from source (M7's oracle,
  in `check-cross`). An incremental build links the `.rbu`s. The
  first incremental mode inlines nothing across units (OCaml's
  `-opaque`); what an export basis carries for inlining is decided by
  measurement in M7. M1 measures `--read-mid` on the interpreter
  against elaborating the Basis; if text is not several times faster,
  Mid is stored binary.
* **B. Bytecode only.** A production build compiles from source as
  today, and the cache serves incremental builds and the REPL. Half the
  format and none of the gain for production builds, whose front end
  is most of their time; kept as the fallback if M7 measures the
  concatenated path as no faster.
* **C. Parsed or typechecked AST** (the brief's first two options).
  The elaborator's annotations live in AST slots and its state in
  tables, so a typechecked AST without the tables is not resumable and
  with them is the basis of D4; a parsed AST saves only the lexer and
  parser, which are not where the time goes (`weak-points.md:24-31`).

### D7. Linking

**Decided: A** (2026-10-09), as recommended.

* **A. A static linker in the compiler and `rt_load` in the VM, with
  one relocation.** The static linker makes a `.rbc` from units, so
  batch incremental builds change nothing in the VM and every VM,
  `runeopt` included, runs their output. `rt_load` appends a unit to a
  running program: code, functions, constants, globals and debug tables
  at the end, operands rewritten by kind with the bases it chose,
  imports checked by unit identity and fingerprint against the exports
  loaded, the unit's code validated as a file's is (the checkers take a
  range), the JIT's code objects grown and, under `--jit=all`, the
  functions compiled on arrival; it returns the closure of the unit's
  top level and the SML side calls it, so the driver's rule holds. A
  unit loaded twice is two units: fresh globals, fresh code, the second
  top level run again (Elsman 2026: "Alpha-renaming permits a fresh
  instance of an object to be linked; it does not identify that
  instance with an earlier one"). The two are held to each other by
  test.
* **B. `rt_load` alone**, and a batch build is a program that loads
  its units and saves an image. Every batch build would depend on the
  VM and on images; `runeopt` would run nothing built incrementally.
* **C. The static linker alone**, and the REPL relinks the whole
  program after every declaration into a new image. A REPL that
  restarts the world at every line.

### D8. The Basis and the compiler as units

**Decided: A** (2026-10-09), as recommended.

* **A. The compiler is the first client of unit builds, and the Basis
  Library ships as one frozen library.** `bin/rune` is built in unit
  mode too -- one unit per file of `sources.txt`, nothing shaken,
  wrappers kept, an export table -- so that the REPL image holds one
  Basis shared by the compiler and the user's code: one `TextIO.stdOut`,
  one `Random`, one `RuneExit`. The Basis Library is built once into a
  library file of export bases and unit bytecode (CM's stable library),
  shipped under `lib/`, loaded by every compile; `MANIFEST`'s demand
  loading is replaced by the cache and by `Shake` in whole-program
  builds, its seals by re-ascriptions in the Basis's build file, its
  `final` file by a last unit.
* **B. `use` the Basis into the REPL from source at start.** Two
  copies of the Basis in one heap -- the compiler's and the user's --
  with two buffered `stdOut`s writing out of order, which is what the
  Plan review of this roadmap warned of.

### D9. The resident compiler

**Decided: A**, in-process (2026-10-09), as recommended.

* **A. In-process, Poly/ML's model.** The compiler is a library of
  units loaded into the same VM; `Compiler.compile {read, file, line,
  out, error, ...} : unit -> unit` compiles one top-level declaration
  against the session's basis and returns the closure that runs it;
  `use` reads a file through it; `rune-repl` (also `rune -i`) is an SML
  program over it; the session, basis and all, is an image when saved.
  Required by HOL4, which calls `use` and `compiler` from ML and whose
  heaps must hold the static basis beside the values (*HOL4 today*).
  Its costs are named and measured: the copying collector copies the
  live basis of the Basis Library and of HOL at every collection (the
  reason `main.sml:144-147` drops it today; jit D14's collector and a
  `shareCommonData` analogue are the answers, and M1 measures the cost
  first); `use` re-enters the compiler during a declaration's
  execution, so every pending list is settled per declaration (D5) and
  the compiler's tables are consistent between declarations; a compile
  error rolls back the tables; the user's environment is built from the
  Basis's export table and never from the compiler's own structures;
  the program grows monotonically, and a redefinition leaves its old
  code dead, as in Poly/ML; the compiler's throughput at tier 0 or 1 is
  a fraction of MLton's, and HOL4 `use`s files of thousands of lines,
  so M1 measures lines per second.
* **B. Two processes** (Elsman 2026; GHCi's external interpreter): a
  compiler process and an evaluation VM joined by pipes. Isolates the
  compiler's state from the user's heap and its collections, and lets
  a REPL front end be any program. It cannot be HOL4's host, since
  HOL4's `use` is a call from user code that must extend the caller's
  environment, and a heap saved by HOL4 must hold both halves. Kept as
  a later front end over A, where the second process talks to the
  first's `Compiler` structure.

### D10. Printing at the top level

**Decided: A, as rewritten by the review of 2026-10-09 below (the
owner, 2026-10-09).**
The owner asked whether A is still possible under the heap layout built
since this was written, and the optimisations it keeps open, or
whether B is now required. A is still possible and B is not required.
But the reason this section first gave for A -- "every value carries
its tag" -- is false under the word layout, and was never what A rests
on.

* **A. Printers generated from the static type, as typed code, before
  representations are chosen.** The compiler, knowing `val it : int *
  string list`, makes Standard ML code -- in the elaborated program
  that `Translate` reads, not in Mid, `Lower` or C -- that prints such
  a value: a `case` over a datatype's constructors, a selection of a
  tuple's fields, `Int.toString`, `Real.toString`, `!`, `Array.sub`.
  That code is compiled by the same passes as the value it prints, so
  `Rep`, the real encoding, the boxes and the flat arrays reach it the
  way they reach every other piece of code, and it never inspects a
  value's bits. It honours a print depth, a line length and a registry
  of user printers keyed by type name (`Compiler.addPrettyPrinter`,
  which HOL4 calls 39 times). It prints as Poly/ML 5.9.2 does, as
  checked on 2026-10-09: `val x = B 3: t` for a datatype whose
  constructors are out of scope, `?` for an abstract type, `fn` for a
  function, `E 3` for an exception value.
* **B. A type-indexed interpreter over type descriptions** (Elsman
  2026): one printer, written once, that walks a value at run time by a
  description of its type. Under the word layout the interpreter would
  have to know every representation that `Rep` and the runtime choose
  -- that an immediate is an `int`, a `char`, a nullary constructor's
  tag or a rotated real, which constructors are flattened, which reals
  and 64-bit numbers are boxed, which arrays are raw -- and would have
  to be kept in step with every later change. This is a second
  implementation of `Rep`. B is not required, and the new layout makes
  it dearer, not cheaper.
* **C. The compiler's `Ty` printer over a reflected value.** Now
  impossible, not only absent: the bits of an immediate do not say
  which type it has.

**The review (2026-10-09).** Under the word layout (*Since this was
written*), a value's low bit says "immediate" or "pointer" and nothing
more. `0`, `#"\^@"`, `false`, `()`, `nil` and `NONE` are one word. A
real in range is an odd word as well. An object's header gives a kind,
a constructor tag and a length, and a flattened constructor or a raw
array does not say what its fields are. The runtime's own
uncaught-exception message is the one printer in the tree that reads
bits without a type (`print_exn_payload`, `runtime/runtime.c`), and on
today's tree it prints wrong:

| `raise E v` with | prints | should print |
|---|---|---|
| `exception E of char`, `#"a"` | `E 97` | `E #"a"` |
| `exception E of bool`, `true` | `E 1` | `E true` |
| `exception E of real`, `1.5` | `E 4607182418800017408` | `E 1.5` |
| `exception E of int`, `0` | `E` | `E 0` |
| `datatype t = A \| B \| C`, `C` | `E 2` | `E C` |

The decided D12 of [heap-layout.md](heap-layout.md) said that the REPL's
printer "stays tag-directed" and needs types only for raw fields. That
was written before its gate chose the word on every machine with
untyped immediates, and the gate superseded it. Any printer that reads
bits is wrong now. A printer generated from types is unaffected: it
asks the static type, which the compiler has for every top-level
binding, and lets the back end deal with representation.

A stays true, against today's layout and the ones kept open, under six
conditions. M4 builds to them:

1. **Printers are made before `ToMid`**, as ordinary code from the
   elaborated types, and never by a walker in C or in `Lower`. Then raw
   real fields, headerless pairs, a 32-bit machine's word, or a pointer
   code for thunks change the printer exactly as they change the rest
   of the program, with no work here.
2. **A datatype's printer is made once**, from its constructors and
   the printers of its parameters, and kept in the basis beside its
   layout (D4). A declaration then only composes printers. A datatype
   whose constructors are out of scope (`local`, or a structure that
   hides them) still prints by its constructors, since the basis keeps
   them whether or not they are in scope. An abstract type (opaque
   ascription, or a slot of an SC import, D17) prints `?`. The basis
   carries no other description of a type.
3. **A type variable prints `?`**, and nothing under it is looked at.
4. **`exn` is the one open type**: the argument's type is unknown where
   the value is printed. An exception constructor keeps a printer for
   its argument, made where it is declared, in a second field of its
   `K_EXNCON` object beside the name (a layout change of
   `runtime/value.h`; images and `make test-portability` with it). A
   unit compiled without printers stores a default that prints the
   name alone. `exnMessage` and the uncaught-exception message can then
   print the argument correctly instead of guessing.
5. **A unit build keeps each datatype's representation a function of
   its declaration.** D3 to D6 need this anyway. The whole-program-only
   choices kept open (headerless pairs "in the whole-program compiler",
   heap-layout D1 C) stay out of unit builds and of the REPL, or are
   made per declaration. If they were made per program, a loaded unit
   could not match an earlier unit's constructors, before any printing
   happens.
6. **`addPrettyPrinter` is keyed at compile time.** The registry's key
   is the type name's stamp, taken from the static type of the
   printer's argument where the call is elaborated (a special the
   elaborator knows; Poly/ML's values carry no types either, so its
   `addPrettyPrinter` has to work from the static type too), never from
   a value. Generated
   code passes a registered printer the printers of the type's
   arguments, Poly/ML's `int -> 'a -> 'b -> pretty`.

**When B would be needed:** to print where no compiler made the code,
for a type known only as data at run time. A debugger reading a stopped
program's frames, or the IDE's hover on a live value, would need type
descriptions and a run-time model of `Rep`; jit M8's representations
section is a start on that model. None of this is in this roadmap. It
goes in *Ready for, not built*.

### D11. Interrupts

**Decided: A** (2026-10-09), as recommended.

* **A. A flag in the VM set by a signal handler behind `vm/sys.h`**
  (`SIGINT` on POSIX; `SetConsoleCtrlHandler` on Windows; `ENOSYS` in
  `sys_none.c`), polled at jit M6's poll points -- backward jumps and
  calls -- in the interpreter's loop and in tier 1's code, and in the
  portable VM's loop; when set, the poll raises `SML90.Interrupt` at
  that point as any raise, so the handler stack, the frames and the
  traces are unchanged. A mask, set by the program, defers it
  (`Thread_Attributes.uninterruptible` in HOL4 needs one). The REPL
  catches `Interrupt` at the top and continues.
* **B. Between declarations only.** Cheap, and useless against a
  tactic that loops.
* **C. A signal that longjmps out of the loop.** Leaves the VM
  inexact and the handler stack wrong; every rule of `jit.md` about the
  VM being exact where C can look is against it.

### D12. The REPL's semantics

**Decided: A** (2026-10-09), as recommended.

* **A. Chapter 8 of the Definition.** A declaration that fails to
  elaborate is reported and skipped, the session's basis unchanged; one
  that raises an uncaught exception keeps the effects it had on state
  and adds no bindings, and the unit it loaded stays loaded (a closure
  it stored may refer to its code: Elsman 2026, rule 10); one that
  completes extends the basis. Errors are therefore recoverable per
  top-level declaration (`weak-points.md`, item 3: an error datatype,
  and the driver going on at the next declaration), which batch mode
  also uses to report every independent error in a run. `it` is bound
  by `exp ;`. Batch mode still rejects a program with any static error,
  as `docs/language.md:27` says; the row gains its REPL half. Options
  for later, listed in *Ready for, not built*: autoloading a library on
  an unbound structure (CM's autoloader), multi-line editing, history.
* **B. Stop the session at the first error**, as batch mode does. Not
  a REPL.

### D13. HOL4

**Decided: A**, with the owner's stop before it kept open (2026-10-09), as recommended.

* **A. A port layer for Rune inside a fork of HOL4** -- `tools-rune/`
  and `src/portableML/rune/`, beside `poly` and `mosml` -- written to
  the contract of *HOL4 today*: `Systeml`; `Meta.load` reading the
  `.uo` lists and calling `use`; the quotation filter as HOL's own
  reader in front of `Compiler.compile`; `addPrettyPrinter` on Rune's
  registry; `MLSYSPortable` with `pointer_eq` (a new primitive),
  `Timer.checkGCTime`, `md5sum`, `reraise`, `exceptionLocation`;
  `Thread`, `Future`, `Synchronized` and `Thread_Attributes` as
  single-threaded shims that run futures at once and make
  `uninterruptible` a mask (green threads, when they exist, replace
  them); the Moscow ML shims; `buildheap` as a `rune-repl` script that
  loads and then `Runtime.save`s, `--holstate` as `--restore`, `hol` as
  a wrapper; `export` as an image plus a wrapper; Holmake's
  `BuildCommand` for rune from the Poly/ML one. Images are whole, so a
  heap per theory costs a file of the session's size each (Poly/ML's
  parent-and-child hierarchy, which HOL4 uses to keep children small,
  is noted and not built; the cache of M6 makes rebuilding from source
  cheap instead). Goal: `build` completes through `src/boss`, `hol`
  proves a theorem, both measured against Poly/ML. The Basis Library
  gaps HOL4 shows are fixed in `lib/basis` as any gap.
* **B. Stop at the REPL** (M4), and let HOL4 be a later decision. The
  owner's notes allow it; the brief asks for A; M5 is where the owner
  chooses.

### D14. The cache

**Decided: A** (2026-10-09), as recommended.

* **A. `.rune/` beside the sources by default, and anywhere the owner
  says** (`--cache-dir DIR`, `RUNE_CACHE`, and from M10 the build
  file). Inside, a directory per *configuration hash* -- the compiler's
  identity, which is the hash of its own deterministic `.rbc`, the
  `.rbc` version, the instruction-set fingerprint, and every flag that
  changes output (`-O`, `--target`, `--passes`, `--allow-prim`) -- and
  in it an entry per *source hash* holding the unit's three parts (D6)
  and its *usages*: for every basis entry the unit used, the entry's
  fingerprint. A compile of a unit against a basis is up to date when
  the entry exists and every usage's fingerprint is the fingerprint the
  basis has now; otherwise the unit is compiled and stored, and its
  dependents find their usages changed only if what they used changed
  (cut-off, Elsman 2008; GHC's usages). Entries are written by atomic
  rename, so concurrent compilers cannot see a half file; a corrupt or
  unversioned entry is a miss, never an error; `--explain-rebuild`
  names the reason a unit was recompiled (GHC's `-ddump-hi-diffs`,
  Shake's why); `--no-cache` compiles from source. Debug and release
  builds are two configuration hashes in one directory; two checkouts
  of one project share nothing and collide on nothing; reverting a
  file finds its old entry (a constructive-trace store, Mokhov et al.
  2018); a compiler rebuilt to the same bytes keeps its cache. Nothing
  in the cache is a timestamp: CM had to demand that the binfile's
  time *equal* the source's to survive reverts, and still could not see
  a flag change. The Basis's frozen library (D8) is a cache entry that
  ships.
* **B. One cache per user** (`~/.cache/rune`, ccache's and Bazel's
  way), content-addressed the same way. Better for many checkouts and
  worse for a project moved to another machine with its cache; kept as
  what `--cache-dir` points at, not as the default the brief chose.
* **C. Timestamps**, as the brief first suggested and its reviewer
  doubted. Rejected: they cannot see flags, compiler identity or a
  revert, and CM's rule is the proof.

### D15. The dependency graph and the file discipline

The owner asked for a serious discussion. The facts first.

* Blume's analysis finds the module-level names a file defines and
  uses and orders files by them, uniquely, when every top-level
  definition of a file is a module definition and no file has a
  top-level `open` (CM's rules 1 and 4). A top-level `val`, a top-level
  `infix`, a top-level `open` or a dependence on another file's side
  effect are invisible to it: the first two because a use of `x` or of
  an infix operator names no module, the last because it is not in the
  text.
* Rune's own sources obey the rules already, because CM needs them
  (`sources.txt:4`; `docs/building.md`, rule 2). HOL4's libraries obey
  a stronger one, Moscow ML's file-per-module. HOL4's theory scripts
  are files of `val` declarations, and they are not compiled by
  Holmake in the CM sense: they are `use`d into a heap. The Basis
  Library's files obey the rules but for the `always` files
  (`initial.sml`, `pervasive.sml`), which define top-level values and
  are the reason MANIFEST has the `always` class.
* So there is no trade-off to make between HOL4 and clean production
  code: HOL4's libraries are the clean case, and its scripts are
  interactive input, which no analysis is asked to order.

**Decided: A** (2026-10-09), as recommended.

* **A. Analysis for the files that obey the rules, checked, and an
  explicit order for everything else.** `rune --deps FILE...` parses
  the files, checks the discipline (a file that breaks it is named,
  with the line), computes the definition-use graph of module names,
  refuses a cycle and a name defined twice, and prints the order, as
  text or DOT. `rune main.sml` with no list compiles the closure: the
  files of `main.sml`'s directory and of every `-I DIR`, scanned and
  analysed, and of those the ones the free module names of `main.sml`
  reach, in the order the graph gives. A build file (M10) lists files
  in order where the discipline does not hold, or groups where it does.
  Nothing restricts what `rune` compiles: the discipline is a property
  of a *group*, asked of its files, and a file that fails it is put in
  an ordered list instead. The Basis's MANIFEST columns become what the
  analysis derives, and `--basis-check` checks the analysis.
* **B. No analysis; explicit order everywhere** (MLB). Simplest and
  honest; it makes "load the whole program from one entry point"
  impossible, which the brief asks for.
* **C. Restrict every `.sml` file to module declarations.** Breaks
  the `always` files, every script and most existing programs; the
  brief allows it only with an escape hatch, and A is that hatch made
  the rule.

### D16. The build language

**Decided: A** (2026-10-09), as recommended.

* **A. A language of Rune's own, with MLB's semantics inside.** The
  owner dislikes CM, MLB, `sources.txt` and MANIFEST, so the syntax is
  new and specified in `docs/build.md` with its grammar and AST; the
  semantics is MLB's, because it is formal, small and right: a basis
  is a value, a file is elaborated in the basis before it and
  contributes to it, `local`, `open` and renaming at import, each
  build file elaborated once, path variables for libraries. To it:
  *groups*, whose files the analysis of D15 orders; *libraries* with
  export lists (CM); *virtual modules* and their implementations
  (Dune, D17), with `where type` to share types across two virtual
  modules (Russo's point); *packages* as build files reached by path
  variable, with a lock file later (M12); per-unit *annotations*
  (`allowPrim`, warnings, `-O`); and the cache's location. It
  elaborates to the list of units and bases that every build consumes,
  and the `.mlb`, `.cm` and Poly/ML scripts of the hosts are generated
  from it, so the five builds keep building. It replaces `sources*.txt`
  and `lib/basis/MANIFEST`.
* **B. A superset of MLB**, same semantics, MLB's syntax with Rune's
  additions. Compatible with MLton and Millet as it stands, and what
  the owner said they do not like. Presented in case the compatibility
  weighs more than the syntax.

### D17. Compiling against a signature alone

**Decided: A** (2026-10-09), as recommended.

* **A. An ABI fixed by the signature**, and nothing else. A client
  compiled against `SIG` alone, for a virtual module (M10) or a dynamic
  one (M9), and an implementation that fills it, agree on: one global
  slot per specification of the signature, in the signature's order,
  substructures recursively; for a `datatype` declared in the
  signature, constructor tags in the signature's declaration order and
  each constructor's layout (`Rep`: one object of *n* fields, or a
  boxed argument) from the specification's argument type, so an
  implementation that declares `datatype t = B | A` for a signature's
  `A | B` is compiled with its tags renumbered to the signature's
  (renumbered, not rejected: the Definition allows the order to differ);
  abstract types abstract to the client, with no realisation and no
  specialisation; exceptions as values in their slots; every call across
  the boundary through the wrapper (later: a worker arity derived from
  the specification's type, with an adapter on the implementing side);
  no functor in a virtual signature (there are no functors at run
  time); no inlining across the boundary; equality by the run-time
  primitives, which are structural. An implementation adds no exports
  the signature does not name (Dune's rule), is ascribed opaquely, and
  is checked against the signature's ABI at link or load.
* **B. Reject an implementation whose representation differs**
  (tags in another order, a boxed constructor where the signature's
  layout is flat). Simpler and worse: an SML programmer may write
  constructors in any order.
* **C. Functorise instead** -- program against a signature by writing
  a functor and apply it in one place. The Definition's own answer; it
  moves every client into a functor body, which is what the brief
  called "pre-processors" in another form, and it is always available
  to a user who prefers it.

### D18. Dynamic modules

**Decided: A** (2026-10-09), as recommended. C, first-class packages, may be considered for Rune 2.0.

* **A. `structure X = _dynamic "path" : SIG`**, an extension in the
  family of `_prim` and `_overload` that the compiler already has: the
  client is compiled against `SIG` alone (D17), the compiler emits the
  fingerprint of `SIG`'s ABI as a constant, and at run time `rt_load`
  loads the unit at `path`, checks the fingerprint of its export
  interface against it (OCaml's interface CRCs; Alice ML's `unpack`),
  resolves the unit's own imports by unit identity and fingerprint
  against what is loaded (SMLSC's definite references: two dynamic
  modules that import one library share its types), runs its top level
  and binds `X`'s slots. A mismatch is an exception with both
  interfaces named. The unit header's code kind is bytecode; a native
  kind is a later roadmap's. Beside it, the untyped form
  `Dynamic.load : string -> unit` loads a unit that registers itself
  through a structure it imports (a plugin), which M3 makes trivial.
* **B. `Dynamic.load` only**, untyped, with plugins registering
  themselves. Half the brief.
* **C. First-class packages** (Alice ML's `pack`/`unpack` as values,
  Russo's first-class modules). A language change far beyond the
  brief, which the owner's module-calculus notes may take up later.

### D19. The second part

**Decided: as recommended** (2026-10-09), and planned again after M7:

* whole-program builds from the cache (M7) and parallel builds by
  processes over the graph, with the cache as the exchange between
  them (M11), since the VM has no threads and CM's compile servers and
  MLKit's batch mode show the shape; reproducibility as the
  five-builds identity extended to cached against uncached builds;
* hot reload, the compiler as a service and packages as research
  milestones with a prototype and a decision each (M12): reload on
  Erlang's two-version semantics through the export table, with jit
  M6's invalidation of direct calls and M11's deoptimisation of live
  frames, and the state migration question stated with the literature;
  the service as the resident compiler behind a protocol, which the IDE
  brief will consume; packages as path variables and a lock file over
  the content-addressed cache.

## Disagreements and additions

What this roadmap disagrees with in the brief, and what it adds, as
asked:

* **Timestamps** are not used at all, not even beside flags and
  identity: content hashes under a configuration hash (D14).
* **The per-folder `.rune` cache** is kept as the default and made
  content-addressed and relocatable, so debug and release, two
  checkouts and a moved tree cost nothing (D14).
* **The REPL comes before the cache**, since HOL4 on Poly/ML uses no
  cache and Rune's REPL needs none: a resident compiler and images
  (D5, *Why this order*).
* **The build language's semantics should be MLB's** even though its
  syntax is new: it is the one formal, proven design (D16).
* **Three prerequisites the brief does not list:** error recovery per
  declaration (the REPL cannot die at the first error), signals in the
  VM (Ctrl-C), and thread shims for HOL4 (D11 to D13).
* **`--count` stops being an oracle between incremental and
  whole-program builds**; output is, and the cached whole-program build
  is byte-identical to the uncached one (*Constraints*).
* **Images already are HOL4's heaps**, whole rather than hierarchical
  (D13).
* **Whole-program builds should come from the cache too**, by
  concatenating Mid, or the production build gains nothing from this
  roadmap (D6).
* **The compiler is the first client**: `bin/rune` in unit mode and the
  Basis as a frozen library, or the REPL holds two Bases (D8).
* **The metacircular JIT tier** (jit D7 C) becomes possible once the
  compiler is resident; noted for the JIT's second part.
* **The language server** gets what it will need designed in -- spans
  in bases, per-declaration positions, the cache as its store, the
  service protocol -- and no work (D4, D19).
* **Dependency analysis makes a DAG of files, not something richer**;
  the module language makes it harder to find, not deeper (*What is
  different for SML*).
* **Functors are the dependency the brief did not see**: a functor's
  clients depend on its source, so a change to a functor body
  recompiles them (D1, D4).

## The milestones

Every milestone is one commit, or a few, each with `make check` green,
as the repository's rules require; where it touches the VM, the loader
or `vm/image.c` it also passes the sanitiser build, `make test-stress`,
`make test-windows` and `make test-portability`. Every milestone that
adds behaviour beyond the Definition documents it in `docs/` and tests
it in a suite of its own, since no host compiler can be its oracle
(the brief's rule), and every milestone that changes numbers measures
itself against the one before (*Measuring*). Sizes are lines of code,
estimated. M1 to M7 are about 6,500 lines of Standard ML and 900 of C,
plus the HOL4 port; M8 to M12 about 3,500, and are planned again after
M7.

### M1. Measure (S, about 200)

* **What:** a script, `bin/rune-measure perf-units`, and a table in this
  file:
  * where a compile's time goes, by phase (`--pass-stats`), for
    `hello`, the two-line program of `weak-points.md`, the Basis whole
    (`--basis all`), the compiler and the largest programs of the
    corpus, on `bin/rune`, `bin/rune.new.rbc` at the JIT's tiers and
    the MLton build;
  * the compiler's throughput elaborating, in lines per second, on
    each, since HOL4 `use`s files of thousands of lines;
  * `--read-mid` of the compiler's own Mid against elaborating the same
    sources, to decide text or binary Mid (D6);
  * the cost of keeping the static environment reachable during the
    back end (a one-line experiment against `main.sml:144-147`): the
    collector's share, since a resident compiler keeps it (D9);
  * HOL4 on Poly/ML as the baseline: wall time of `build` through
    `src/boss`, the number of `use`s (`QUse` instrumented), the heaps'
    sizes, and the latency of `hol` starting, loading a theory and
    evaluating a small declaration;
  * the scenario list of the cache (M6) written as
    `tests/incremental/SCENARIOS.md`, tests-to-be.
* **Why now:** every estimate in this file is against these numbers,
  and the two decisions that depend on measurement (D6's Mid format,
  D9's collector cost) are taken from them.
* **Done when:** the script is committed and the table is in *What a
  compile costs*.

### M2. Units in memory: the basis as a value, the front end resumable, a back end per unit (L, about 900 SML)

* **What:**
  * `Basis` (`src/elab/basis.sml`): the record of D4 with a delta type
    and `plus`; the elaborator's global state (`sigs`, `funs`, fixity,
    `Overload.table`, the `Ty` tables, `Translate.primAliases`, the
    counters) moved into it or journaled against it, so that a basis
    can be snapshotted and restored;
  * `Elaborate.elabTop` takes a basis and returns its delta; `finish`
    and every pending list run at the end of each top-level
    declaration (flexible records included: `docs/language.md:29`
    changes from "the end of the program" to the end of the
    declaration, which the Definition allows);
  * a compile error rolls the basis back to the declaration's start
    (the maps are functional; the `IntTable`s get a journal), and the
    driver goes on with the next declaration in batch mode, reporting
    every independent error and failing at the end (`weak-points.md`,
    item 3), with an error datatype in place of strings;
  * `Pass.whole : bool ref`: with it false, `Shake` and `Simplify`'s
    inlining are off, `Workers` runs over the unit's functions alone,
    `Lower` knows the unit's functions and the arities the basis
    imports, and functions and globals are numbered per unit in
    definition order; `Code.program` gains an export table (name to
    global or function, with arity) and an import table;
  * an in-memory linker, `Link.programs : Code.program list ->
    Code.program`, that rebases by operand kind and makes function 0
    call each unit's top level in order;
  * `rune --units a.sml b.sml -o p.rbc`: one unit per file, linked; the
    default stays whole-program with the same bytes;
  * `bin/rune` builds in unit mode as well (D8), as a test of the
    mode on 13,000 lines;
  * `make check-units`: every program of `tests/lang` and `tests/perf`
    built with `--units` prints the same, exits the same and traces the
    same as its whole-program build, at every `-O`.
* **Why now:** the piece nothing else can do without and that cannot
  be retrofitted: a compiler that can be stopped and resumed at a
  declaration.
* **Done when:** `make check` green with `bin/rune.rbc` byte-identical
  to before (the whole-program path unchanged); `check-units` green;
  the five builds identical; `--pass-stats` shows the unit mode's cost
  per unit.
* **Touches:** every later milestone; the language server (an
  elaborator that resumes per declaration).

#### M2, as built (2026-10-09)

`rune --units` compiles every file -- of the Basis Library, of a library
beside it, of the program -- as a unit after the ones before it, and
links them (`docs/units.md`, the lasting record; `src/backend/link.sml`).
What was built, and where it differs from the plan above:

* **The passes per unit.** `Pass.whole`: false under `--units`, where
  `Shake` does not run, `Workers` keeps every wrapper and `Simplify` does
  not put in place a function called once; `Lower` knows the functions of
  the units before (`knownBefore`) and gives each it calls an id after the
  unit's own (`imported`); the lints of Mid and Low accept a global or a
  function of a unit before. Everything else ran per unit unchanged:
  `Translate`, `ToMid`, `Lift`, specialisation and both targets keep their
  tables between units, which the stamps being unique in a session
  allows.
* **The linker** works on `Code.program`s, not on bytes: each unit's
  functions, constants, labels, files and inlined frames get a base, its
  globals are numbered by stamp through the unit that sets them, and
  every operand that names a function, global or constant is renumbered
  by the kind the instruction set gives it, which `make isa` now writes
  into `RegCodes.linked` and `Opcodes.linked` (the fingerprint does not
  change). The export and import tables are the linker's record of a
  unit (`Link.unitCode`) rather than fields of `Code.program`; M3 writes
  them into the `.rbu`.
* **No function calls the units' top levels.** Each unit's top level ends
  in a tail call of the next one's, so function 0 is the first unit's top
  level and only one is ever on the stack: a trace shows the same frames
  as the program compiled whole, which `check-units` holds it to.
* **Numbering stays first use**, per unit: deterministic, which is all
  the five builds need; definition order is left to M6, where a unit's
  numbering must not depend on what came before.
* **Errors per declaration.** A top-level declaration that fails to
  elaborate is reported, undone (`Elaborate.snapshot`, `restore`) and
  skipped, whole or in units, and the compile fails at the end of the
  front end having reported every independent error; a syntax error still
  ends it. The state to put back is small because the elaborator's maps
  are functional and the tables keyed by stamps only grow. No error
  datatype was needed: `Error.report` prints and counts. `docs/language.md`
  says so in its *Programs* row.
* **Flexible records are settled at the end of each unit, not of each
  top-level declaration.** Settling them per declaration rejected
  `tests/lang/ty.record.flex_program`, which `docs/language.md` keeps on
  purpose (a generalised flexible record resolved by a later
  declaration; SML/NJ, MLKit, Moscow ML and Hamlet reject it, MLton and
  Poly/ML accept it as one top-level declaration -- measured 2026-10-09,
  correcting what this said before). So the program
  compiled whole is unchanged, and with `--units` a flexible record must
  be determined in its own file. **The owner decided (2026-10-09):** a
  language option with every variant the implementations have,
  `--flex-records=binding|declaration|topdec-monomorphic|topdec|program`,
  and Poly/ML's, `topdec`, the default; the REPL then compiles a
  top-level declaration as one unit, as Poly/ML does (`docs/language.md`,
  *Flexible records*; `tests/flexrec`).
* **The basis as a value** is, after M2, the environment (`Env.env`,
  threaded), the fixity (functional), the elaborator's snapshot and the
  tables that only grow. A record of all of it with a delta, which M6
  must serialise, is built in M6, where what it must hold is known; M2 did
  not need it.
* **Checked by** `make check-units` (in `make check`): every program of
  `tests/lang` and `tests/perf` the same whole and in units at `-O0`,
  `-O1` and `-O2` with the lint on, for both bytecodes (280 programs);
  `tests/units`, programs of several files; and the compiler compiled in
  units compiling its own sources whole to `bin/rune.rbc`, byte for byte.
  The whole-program path is unchanged: every program of `tests/lang` and
  `tests/perf` compiles to the same bytes as before M2, for both targets.
* **Cost**: a unit build of a small program is about ten times the size
  of its whole build, since nothing is shaken out of the Basis Library's
  files (`rt.trace_inlined`: 348 KB against 38 KB).

### M3. Unit bytecode, the static linker, and the VM loads units (L, about 600 C and 500 SML)

* **What:**
  * the `.rbu` format (`docs/bytecode.md`): the sections of a `.rbc`
    for one unit, its import table (unit identity, export name,
    fingerprint), its export table, its relocation table (offset and
    kind of every operand that names a function, global, constant,
    label or handler label), jit M8's metadata per function, a code
    kind, the compiler's identity; `rune -c a.sml b.sml` writes each
    unit's `.rbu` (the bases in memory until M6); `rune -o p.rbc
    a.rbu b.rbu` links them with the linker of M2;
  * `rt_load` (`src/isa/prims.sml`; `vm/loader.c`, shared by both
    VMs): appends a unit to the running program -- code, functions,
    constants, globals, files, lines, inlined frames -- rewrites its
    operands by kind with the bases chosen, checks its imports against
    the exports loaded, validates its code (the checkers of
    `vm/isa_stack.c` and `vm/new/isa_regs.c` take a range), grows
    `JitProgram.codes` and, under `--jit=all`, compiles the new
    functions, and pushes the closure of the unit's top level as its
    result; exposed as `Runtime.load : string -> unit -> unit` (a
    file) and `Runtime.link : Word8Vector.vector -> unit -> unit`
    (bytes, for the resident compiler);
  * images after loads: nothing new in the format, since the program
    is whole; a test that loads, saves, restores and calls;
  * `tests/vm`: a malformed `.rbu` refused with the loader's message; a
    missing import; a fingerprint mismatch; a unit loaded twice is two;
    `--count` of a program linked statically equal to the same units
    loaded one by one; `check-units` runs the dynamic path too.
* **Why now:** a REPL is a program that loads units; and the static
  linker over files is what makes `rune -c` real.
* **Done when:** the tests pass on both VMs, under `--jit=off` and
  `--jit=all`, the sanitiser, the stress mode, Windows and the portable
  machines.
* **Touches:** the JIT (code objects grown; `--jit=all` on arrival);
  images; `docs/runtime.md` (loading); `vm/new/ARCHITECTURE.md`.

#### M3, as built (2026-10-09)

* **The unit file** (`.rbu`, `docs/bytecode.md`, *Units*): a short header
  (version, the instruction set's fingerprint, a code kind, the compile's
  session), then the sections of a `.rbc` of the unit's own code, then the
  linker's tables: the stamp of each global it names, the globals it sets,
  the functions it names past its own (the next unit's top level being
  stamp -1) and those it exports. `rune --units --emit-units DIR` writes
  one per unit and `DIR/units`; `rune -o P.rbc` given unit files links
  them. The **static linker** reads a unit file back into the code the
  target made (`UnitFile.read`: every instruction decoded by the layout
  `make isa` now writes into `RegCodes` and `Opcodes`, its labels and
  positions made again) and links it with M2's linker, so a program linked
  from files is the same bytes as `--units` makes (`check-units`, every
  program). One relocation in SML (`Link`), one in C (`relocate_code`),
  held to each other by the dynamic path below.
* **Names across compiles.** Until M6 numbers them canonically, a unit
  names other units by the compiler's stamps, which mean nothing outside
  the compile; a unit carries its compile's *session* (a hash of the names
  and texts of all its units) and the linkers refuse units of two. The
  import table of the plan (unit identity, export name, fingerprint) is
  M6's.
* **`rt_load` is `rt_link`**, a primitive taking the unit's bytes, with
  `Runtime.link : Word8Vector.vector -> unit -> unit` and `Runtime.load :
  string -> unit -> unit` over it; `rt_link_error` gives why one failed,
  which `Runtime.link` raises as `Fail`. The VM's side (`load_unit_mem`,
  `runtime/loader.c`) reads the unit whole with the `.rbc` reader's own
  code, finds its imports in a table of what the units loaded export (by
  session, stamp and kind; saved in images, version 11), renumbers its
  operands (`relocate_code`, per instruction set), appends everything,
  makes its constants once the table that roots them has room, and checks
  its code from its first function (`validate_program_from`), taking the
  unit out again if it fails. A unit's top level returns where the static
  linker would chain it to the next. A unit loaded twice is two units, and
  the later units find the second. Native programs load nothing.
* **The JIT** was the one surprise: compiled code embeds the address of
  the table of code objects, so the table cannot be grown under it.
  `rt_link` is a `PRIMPUSH` that says `PRIM_NEW_WORLD`, as
  `Runtime.restore` does, and `jit_make` now invalidates every compiled
  function before it frees the tables, so that frames below the load
  return into the interpreter. Correct, and it costs the JIT all its code
  at every load; M4, where the REPL loads a unit per declaration, needs
  tables reserved to a capacity that does not move (the code objects, the
  fill table, the functions), or code that reads the table's address from
  the VM.
* **Tests.** `check-units` runs the dynamic path for every program of
  `tests/lang` and `tests/perf` (`tests/units/load.sml` loading each unit
  file and running it; same output and status, both instruction sets),
  leaving out programs that print their own call stack, take arguments or
  limit the heap; `tests/units` adds a unit loaded twice, one shadowed,
  files that are no unit or are cut short, imports not loaded or of
  another compile or instruction set, and a world saved after loading and
  restored to load the rest; `tests/basis/runtime.sml` the failing paths
  of `link` and `load`. `--count` of a program linked statically is not
  compared with its units loaded, as the plan said: the loader is a
  program of its own, whose instructions the count includes.
* **Left for later in M3's place:** the barrier for the globals that M1
  asked for (`SETGLOBAL` in every engine, the minor collection scanning
  only the cards of the globals written since, and the constants scanned
  once). A REPL is where it is needed, so it is M4's first step.

### M4. The resident compiler, `use` and the REPL (L, about 1,500 SML)

* **What:**
  * the compiler as a library: its units loadable into a program, and
    `bin/rune-repl` built from them in unit mode with a REPL main and
    the Basis as one library (D8);
  * `structure Compiler` (`docs/repl.md`): `compile : {read : unit ->
    char option, file : string, line : unit -> int, out : string ->
    unit, error : ..., nameSpace : ...} -> unit -> unit`, Poly/ML's
    shape, compiling one top-level declaration as a unit against the
    session's basis and linking it with `Runtime.link`; `use`;
    `addPrettyPrinter`, `printDepth`, `lineLength`, `prompt1`,
    `prompt2`; a `Pretty` datatype of blocks, breaks and strings in
    Poly/ML's shape, so that HOL4's printers port; `Exception.location`
    (the site of the last raise, kept by `vm_raise` from the line
    table) and `reraise`;
  * printing: a printer generated per top-level declaration from its
    static types, honouring the depth, the length and the registry
    (D10); `val it = ...`, `val x = ... : t`, `structure S : sig ...
    end`, `signature`, `functor`, `exception`, `datatype` echoed as
    SML/NJ and Poly/ML do;
  * Chapter 8 (D12): skip, keep effects, extend; `it`; the session's
    basis rolled back on error; nested `use`;
  * interrupts (D11): `sys_signal` in `vm/sys.h` answered by the three
    layers, the flag polled at the poll points and in both loops, raised
    as `SML90.Interrupt`, a mask;
  * the boot image: `bin/rune-repl.img` saved after loading the
    library, restored at start; `rune -i`;
  * `tests/repl`: transcripts (`.in`, `.expected`) run on both VMs
    and at `--jit=all`; errors, exceptions, shadowing, a closure that
    keeps its old binding, `use` of a multi-file library, a session
    saved and restored, an interrupt; rows of `docs/language.md`
    (`top.repl`, `top.use`, `top.it`, `top.recover`).
* **Why now:** the owner's first wish, and what HOL4 needs.
* **Done when:** the transcripts pass; `use` of a 5,000-line file
  completes and its time is in the table; the REPL survives every
  error and exception of its suite; Ctrl-C interrupts a loop and the
  session continues; a saved session restores with its bindings.
* **Touches:** HOL4 (M5); the language server (the service of M12 is
  this compiler behind a protocol).

#### M4, as built (2026-10-09)

* **The globals' barrier** (M1's finding, moved here from M3): every
  engine's `SETGLOBAL` already stored 1 in the global's byte of
  `global_set`, so a minor collection takes only globals marked 1 and marks
  them 2, and only the constants made since the last (`MINOR_ROOTS`,
  `runtime/gc/gc.h`) -- no engine changed. 100,000 globals: 14 roots besides
  the stack where there were 100,230.
* **The JIT across loads.** Compiled code read the tables of code objects,
  of fills and of functions, and the number of functions, as constants;
  they are read from the JitProgram and the VM now (`entry_of`,
  `closure_function`, `fill_unit_dynamic`, `to_callee_dynamic`), and the
  primitives' helpers are given where their operands are rather than a
  pointer into code a load may move. So a load grows the JIT's tables
  (`jit_grow`, by `VM.prog_epoch`) and keeps what it compiled. `use` of a
  file of 5,000 lines went from 7.4 s to 1.2 s (1.9 s with the JIT off).
* **The REPL** (`docs/repl.md`, the lasting record): `bin/rune-repl` is the
  compiler and the REPL compiled a unit per file and loaded unit by unit,
  so that they and what they compile share one Basis (D8 A). At start the
  resident compiler compiles the Basis's files again to have their
  environment, the compiler being deterministic, and holds each unit it
  makes to the unit file it was loaded from, byte for byte; the session's
  stamps start above the REPL's own. A declaration is a unit, linked with
  `Runtime.link`; Chapter 8 per declaration (D12): an error leaves the
  session as it was (`Elaborate.snapshot`), an uncaught exception keeps
  the effects and binds nothing, a declaration's bindings join the
  session once it has run, so that what a nested `use` compiled stays.
  `use`, `Compiler.printDepth`, `prompt1`, `prompt2`, in a new Basis
  structure `Compiler` (Rune's own; in a batch program `use` raises
  `Fail`). The new pipeline code is `src/driver/pipeline.sml`, shared by
  `Main` and the REPL.
* **Printing (D10 A, which the owner decided after the review):** a
  printer of SML text per declaration, made from the types it bound
  (`src/repl/show.sml`), compiled with it, from `RuneShow`'s pieces;
  datatypes matched by names of their own bound to the constructors the
  elaborator registers (`Elaborate.dataCons`), so that hidden ones print;
  `?` for abstract types and type variables; a print depth. Not yet:
  exceptions print by name only (D10's condition 4, the printer in the
  exception constructor), a type is printed without its structure's path,
  and the registry of user printers (D10's item 6,
  `Compiler.addPrettyPrinter` and a `Pretty` datatype in Poly/ML's shape)
  was not built in M4; it was built for M5, keyed by a name of the type
  that the cache keeps rather than by its stamp ([hol4.md](hol4.md);
  `docs/repl.md`, *Printers of one's own*).
* **Tests:** `tests/repl` (`make test-repl`, in `make check`): transcripts
  of values, Chapter 8, datatypes, `use`, on every mode of the JIT;
  `tests/lang/basis.compiler`, `tests/basis/compiler*.sml`.
* **The boot image:** `bin/rune-repl.img`, the REPL saved after its
  start (`--make-image`), restored by `bin/rune-repl` with `runevm --restore
  IMAGE -- FILE...`, whose arguments after `--` now replace the saved
  ones; a start and a declaration take 0.6 s rather than 3.
* **Interrupts (D11 A):** `sys_interrupt_catch` behind `sys.h` (SIGINT;
  Ctrl-C and Ctrl-Break at a Windows console; ENOSYS in `sys_none`) sets
  `VM.interrupt`; both loops poll it at a jump back and at a call
  (`POLL`), and the JIT's code with a compare and a slow path
  (`SLOW_INTERRUPT`), raising it as `RAISE` does, with what a handler needs
  live at a jump back as at a call (`live.c`). It is `SML90.Interrupt`,
  caught when a program asks (`Runtime.catchInterrupt`, `rt_interrupt_catch`)
  rather than as a built-in exception, so that a program that does not ask
  still ends at Ctrl-C; `Runtime.maskInterrupt` defers it, and raises it
  as the mask goes. A terminal's read is ended by it (through `poll`, which
  no signal restarts); streams pass it on rather than wrapping it in
  `IO.Io` (`rt_interrupt_is`); an image keeps it caught (images version 12).
  The REPL masks its own work and runs a declaration, and waits for a
  line, unmasked. Found on the way: `TextIO.stdIn` read a pipe or a
  terminal with `fread` of 4,096 bytes, which waits for all of them, so a
  REPL behind a pipe kept open never saw a line; such a handle is now read
  by one `read` of its descriptor. Tests: `rt.interrupt_self` and
  `rt.save_interrupt` (`tests/lang`, the program interrupting itself);
  `tests/repl/interrupt.in`, `SIGINT` sent to the REPL by
  `tests/repl/drive.py` while a declaration loops; checked by hand at a
  terminal: Ctrl-C at the prompt drops the line typed. What the polls
  cost, against M3's VM, three runs each: nothing measurable in the
  interpreter (a loop of 2*10^8 and `fib 32`: 14.1 s against 14.5 s);
  5% in compiled code that does nothing but jump back and call (the same:
  4.12 s against 3.91 s); within the noise for the compiler compiling
  itself (3.46 s against 3.41 s).
* **`rune -i`:** every `rune` wrapper -- the build's and the installed
  ones -- starts the `rune-repl` beside it for `-i`, which the compiler
  never sees; `make install` builds and installs the REPL, its image in
  `lib/rune`.
* **A session saved and restored:** `Runtime.save` from a declaration
  saves the whole session, and the world restored from it has its
  bindings. Found on the way: what the saving world had read ahead of its
  standard input was in `TextIO.stdIn`'s buffer, part of the heap, and the
  restored world read it again; `Runtime.save` now drops it in the world
  restored (`tests/repl/session.in`, `session.then`).

### M5. HOL4 on Rune (XL; in a fork of HOL4 the owner names)

* **What:** the port layer of D13, in order:
  1. what HOL4's sources need of the Basis and Rune lacks (`SML90`,
     `Timer.checkGCTime`, `Word8.toLargeWord`, a `pointer_eq`
     primitive, whatever `smart-configure` finds), fixed in `lib/basis`
     and `src/isa/prims.sml` with their rows and tests;
  2. `tools-rune/`: configuration, `Systeml`, `rune-init.ML` with
     `Meta` (`load` over the `.uo` lists, `loadPath`, `loaded`,
     `fakeload`), `QUse` over `Compiler.compile`, the REPL of
     `holrepl.ML` over `Compiler`, `buildheap` as a program that loads
     and `Runtime.save`s, `--holstate` as `--restore`, `hol` and
     `hol.bare` as wrappers, `--exe` as an image with a wrapper;
  3. `src/portableML/rune/`: `MLSYSPortable`, the thread shims
     (`Thread`, `Future`, `Synchronized`, `Thread_Attributes`,
     `Multithreading` running everything at once, `uninterruptible` as
     the mask), the Moscow ML shims;
  4. `tools/Holmake/rune/`: `BuildCommand` from the Poly/ML one;
  5. `bin/build` through `src/boss`; `hol` proving a theorem;
     `--selftest 1` as far as it goes;
  6. measured against Poly/ML: the build's wall time, the sizes of the
     images, the REPL's latency.
* **Why now:** the brief's first item; M4 exists for it.
* **Done when:** `build` completes through `src/boss` and `hol` runs a
  proof; the numbers are in this file; what did not port is listed
  with a reason. The owner decides here whether to go on to the rest of
  HOL4, to stop, or to postpone.
* **Touches:** the Basis Library; green threads (the shims are what
  they replace); the FFI (HOL4 has none, so nothing).

### M6. The cache, with cut-off (L, about 1,100 SML)

* **What:**
  * the export basis on disk (`.rbi`): a pickle with sharing of D4's
    record, renumbered canonically at export and rebased at import
    (D3); `TVar` cells zonked; spans kept; a version and the compiler's
    identity in the header;
  * usages: per unit, the fingerprints of the basis entries it used;
    fingerprints per entry over the pickled entry with the fingerprints
    of what it refers to (GHC's rule);
  * the cache directory (D14): `.rune/<configuration>/<source hash>/`
    with the three parts and the usages; `--cache-dir`, `RUNE_CACHE`,
    `--no-cache`, `--explain-rebuild`; atomic writes; a corrupt entry
    is a miss;
  * every compile goes through it: the Basis's units first, then the
    program's; `use` looks a file up by content hash and the hashes of
    the units it would see, and links the object instead of compiling
    where the usages hold;
  * the frozen Basis library: `lib/basis` built once into its entries,
    shipped and installed read-only, the cache for every user;
  * `tests/incremental`: a runner over a scratch project that edits,
    reverts, reorders, adds, removes and renames files, changes a
    dependency's interface in a used and in an unused declaration,
    changes flags, rebuilds the compiler, relocates the tree, runs two
    compilers at once, corrupts an entry, uses symlinks and a
    case-insensitive directory, and asserts what was recompiled
    (`--explain-rebuild`) and that the output equals the uncached one.
* **Why now:** after M2 has shown what a basis must hold and M4 has
  given `use` a reason to be fast; before HOL4's builds need thousands
  of `use`s to be cheap.
* **Done when:** the two-line program compiles from a warm cache in
  under twice `hello`'s time; the scenario suite is green on Linux and
  Windows; cold and warm `--units` builds are byte-identical;
  `check-cross` runs with the cache on and stays identical.
* **Touches:** the language server (its store); M7; M11.

#### M6, the first part as built (2026-10-09)

* **The export basis** (D4 A): `UnitBasis` (`src/driver/unitbasis.sml`)
  writes what the units after a unit need of it -- its environment,
  fixity directives, signatures, functors and overloading, and the
  compiler's tables of what it declared (each value's scheme, each
  exception's argument, each datatype's constructors, realisations, the
  primitives' aliases, the functions known by name, `dataCons`) -- and
  reads it back. Not written: the IRs' caches made from those tables
  (`Translate.schemes`, `ToMid.globalSchemes`), and Mid for inlining:
  nothing is inlined across units (D6's first mode). A functor's body is
  its place in the source and the hash of its text; loading parses the
  source again with the fixity of the unit's start, and refuses a source
  whose hash is not the one compiled. A functor's basis is what the unit
  added to its start (`envDelta`); its signatures and functors those the
  unit declared before it; a functor names one of another unit's by the
  unit's identity (`FunInfo.origin`).
* **Names** (D3 A, as a range per unit rather than a renumbering pass):
  stamps, type names and type variables are written as built in, the
  unit's own (numbered as the writing meets them), or an earlier unit's
  (its identity and number); loading gives a unit's numbers a range of the
  session after what its compile used, and registers it. A unit's
  identity is its name and the hash of its basis, without those counts.
* **Every unit through its basis:** after a unit is compiled its basis is
  loaded in place of what the compile left (`Pipeline.unitThrough`), so a
  unit after it sees the same whether the unit was compiled or taken from
  the cache, and the outputs are the same bytes (`check-units`, the
  compiler compiled in units compiling itself).
* **Keys in code:** `Link.unitCode` names globals and functions by
  `{unit, number}`; unit files are version 2 (identities of the units
  named, keys) and so is the VM's loader; units of different compiles
  link. `--emit-units` writes each unit's `.rbi` beside its `.rbu`.
* **The REPL** loads the Basis units' bases at start instead of compiling
  the Basis again (0.36 s without its image, was 3 s); a declaration is a
  unit through its basis, named `stdIn#N`.
* **The cache** (D14 A, `UnitCache`, `src/driver/unitcache.sml`):
  `--cache-dir`, `RUNE_CACHE`, `.rune` beside the first input,
  `--no-cache`, `--explain-rebuild`; a directory per configuration
  (`Config.identity`, a hash of the compiler's sources that
  `gen-build-files.sh` writes, the versions, the instruction set, `-O`,
  `--passes`, `--int-bits`, `--fuel`); an entry per key -- the unit's name,
  source, `_prim` and the identities of every unit before it -- holding its
  basis and code with their hash, written by rename; a damaged entry is a
  miss. **Coarser than D14's usages:** a key names every unit before, so
  every unit after one whose basis changed is compiled again; the cut-off
  is per basis (a body that changes keeps its identity).
* **Found on the way:** a functor's body was in no identity, so a unit
  applying a functor whose body changed would have been taken from the
  cache; the body's hash is now in its unit's basis (S8). Hashing was a
  third of a warm build (four passes over every byte); it is one.
* **Measured** (one machine, busy): the two-line program of *What a compile
  costs*, warm, 0.45 s (cold whole 0.29 s on a quiet machine): reading,
  checking, loading and linking its 56 Basis units each time. The compiler
  in units: 10.1 s cold, 5.4 s warm.
* **Tests:** `make check-units` builds every program without the cache,
  through a shared one and from it, and wants the same bytes; `tests/units`
  likewise; `make test-incremental` runs S1, S2, S3, S5, S6, S8, S13, S24,
  S31, S33, S34 and S36 (`tests/incremental`).
* **The keys of this part** named every unit before a unit; the second
  part (below) replaced them with usages.

#### M6, the second part as built so far (2026-10-09)

* **Usages** (D14 A, by binder rather than fingerprint): `Usage` records
  every name a compile looks up -- values, types, structures (the head of
  a long name), signatures, functors, and every identifier's fixity --
  where what was found is the session's binding (`Env.session`; a
  structure by a witness binding), and `UnitBasis.binders` says which unit
  bound each top-level name. A key is the unit's name, source and `_prim`;
  under it an entry per set of usages, and an entry serves where each name
  is bound by the same unit. So S17 (reorder), S18 (insert), S19 (shadow)
  and S8 without `main.sml` hold. Coarser than per-entry fingerprints:
  S3 compiles `c.sml` (which uses `a.sml`'s unchanged `SHAPE`), S4 every
  user of `a.sml`.
* **The frozen Basis** (D8): `make basis-cache` (in `make all`) compiles
  every unit of `lib/basis` for both bytecodes into `lib/cache` (8 MB),
  read after a compile's own cache and installed read-only. A two-line
  program's first compile takes all but one of its Basis units from it:
  `seal_string.sml` uses `Char`, which `seal_char.sml` binds where a
  program names `Char` and `char.sml` otherwise. Library units are named by
  their place in the library (`lib/basis/...`), so a cache follows the
  tree, and a unit from the cache names its source where it is now.
* **`use` through the cache** (S38): a used file's declarations are units
  named by the file and their place, in `$RUNE_CACHE` or `.rune` beside
  it (`tests/repl/usecache.in`).
* **Warnings** kept with an entry and given again (S32).
* **Found on the way:** the first recording of usages, every lookup's
  first name in whatever scope, made a functor's parameter `Array` a usage
  of the top-level `Array` (`io_functors.sml` missed the frozen Basis).
* **Left:** fingerprints per entry (S3, S4 as `SCENARIOS.md` wants them);
  the warm build within twice `hello`'s time (0.45 s, busy machine; the
  Basis's units decoded and linked per compile: within reach only for a
  compiler that keeps a loaded Basis between compiles -- an image of the
  compiler, or M12's service -- with a linker of bytes for the rest);
  S27 and S37, which the runner cannot make (`SCENARIOS.md` says why).
  Done since (2026-10-09, for the commit after M5's): S28, S39, S40 in the
  runners and S43 in `check-cross`; overloading resolved at a type is a
  usage of the type's name, bound by the unit that registered it -- which
  closed a real gap, `widestring.sml` registering overloading for a type
  `widechar.sml` declares.
* **Found when the owner asked how sure the cache is** (2026-10-09; all in
  [build-cache-issues.md](build-cache-issues.md)): a functor's body is
  elaborated again where it is applied, but what it found where it was
  declared -- its fixity, and names a later unit declares again -- was in
  no identity, and a warm build printed another result than a cold one
  (S49, S50; S51 failed at link). A unit that declares a functor now has
  in its basis the unit that bound each name its compile used. The REPL's
  echo of a file used was cached with the print depth and the printers of
  the session that compiled it (S53, S54), now usages. An entry whose code
  names a unit that is gone is a miss. `--verify-cache` compiles every unit
  found and compares; `tests/incremental/mutate.py` edits projects
  mechanically and replays the compiler's history, each warm build against
  compiling everything. Fingerprints and step 3 below wait for it.

#### M6, the third part: usages per entry (plan, 2026-10-09)

What D14 A asks and the second part did not do: a unit's usages by the
fingerprint of each entry it used, so that S3 (a type changed that a unit
did not use) and S4 (an entry added) compile only what used what changed.
Fingerprints alone gain nothing, because what a unit's basis and code name
of an earlier unit they name by that unit's identity and its numbers, and
a unit whose identity changed is not loaded again: a unit taken from the
cache that names it is a miss, whatever its usages say. So:

1. **A fingerprint per entry.** The hash of what an entry is -- a value's
   scheme, a type's definition (a datatype's constructors and their
   arguments, an abbreviation's body, an abstract type's equality and
   arity), a structure's entries, a signature, a functor's basis and the
   hash of its body, an exception's argument, and the compiler's tables
   for it (primitive alias, known function) -- with every name in it
   written by the unit's *name* and the path that reaches the name in
   that unit's export (`t A.shape`), and the fingerprint of the entry
   behind it, so that a change under a name changes every fingerprint
   that mentions it, and a change beside it none. A name no path reaches
   (a type made in a `local` whose values escape) is written by its place
   among the hidden names of its unit, which may move when the unit
   changes: then the fingerprints that mention it change too, which is a
   miss and never a wrong hit.
2. **Usages by whole names, with the fingerprint.** `Usage` records the
   long name (`v A.area`, not `s A`), and a structure used whole -- `open
   A`, `structure B = A`, a functor's argument -- as `s A`; a usage keeps
   the binder's identity, which settles most lookups at once, and the
   fingerprint, which settles the rest.
3. **Loading across a changed unit.** The cache keeps the basis of every
   unit it wrote by identity. A unit taken from it that names an identity
   no unit of the session has is loaded against the unit of the same name
   that is there: each of its names of the old unit is read by its path
   in the old unit's basis and found by that path in the new one, and its
   code's keys are mapped the same way before it is linked. Where a name
   has no path, or the path is not in the new unit, it is a miss.
   Formats do not change: the mapping happens before anything is linked.

S3 and S4 then want what `SCENARIOS.md` says; S5 to S8 hold as they are.

#### M6, the third part as built (2026-10-10)

The three steps as planned, with what building them showed (`docs/units.md`,
*The cache*, *Fingerprints*):

* **A value's fingerprint names the value**, by its anchor (its unit's name
  and path): otherwise a later unit that declares an `A.x` of the same type
  would hold the usage, and the entry's code would still call the first
  (S19). Signatures' specifications have paths (`sig:SHAPE.area`), or a unit
  that ascribed one could not be remapped; a fixity has a fingerprint (its
  precedence and side), or every usage of an operator would hold by binder
  only.
* **The units an entry's code names**, not only those its basis names, are
  remapped: a unit that declares nothing of `a.sml`'s still calls it.
* **Where usages are checked**: at the unit's place (`UnitBasis.position`),
  before the entry is looked for, and not where the unit before it began.
* **Exact before remapped**: of the entries whose usages hold, one whose
  binders are all the same is taken before one that holds by fingerprint,
  which needs a remapping (after a revert, the first entries: S5).
* **A load that fails half-way** -- a name with no path met in the middle
  of a basis -- takes out what it entered in the tables by stamp
  (`UnitBasis.abandon`).
* **The identity store** is `units/` beside the entries: a file per
  identity, its paths, written when a unit is compiled, read from the
  project's cache and then the frozen Basis.
* **Measured on the scenarios**: S3 compiles `a.sml`, `b.sml`, `d.sml` and
  `main.sml` (not `c.sml`), S4 and S5 `a.sml` alone, S9 and S10 not `c.sml`,
  S28 nothing (a value added to `pervasive.sml`), S28o `w.sml` alone; the
  mutation tester remaps about one unit in three of its builds and no build
  disagrees with `--no-cache`.
* **A type name's fingerprint is its anchor and the hash of its
  definition**, kept by stamp: the definition's own text, which names the
  types it is made of by theirs, grew with every datatype a type names --
  the usages of a unit of the compiler that names `Ast` were megabytes of
  text, and three quarters of compiling the compiler in units (24 s, 4.5 s
  with the hash; found measuring M11).

### M7. Mid per unit: whole-program builds from the cache (M, about 500 SML)

* **What:**
  * Mid made self-contained: `ToMid` writes each constructor's layout
    into the `Con` and `Decon` it makes, so `Lower` reads no `Ty`
    table; `MidText` carries it; `Workers` made idempotent over units
    already split;
  * the whole-program path from the cache: the Mid of every unit
    concatenated in order, then `Shake`, `Lift`, `Workers`, `Simplify`,
    `Lower` and the target, to one `.rbc`;
  * the oracle in `check-cross`: the `.rbc` of every program built from
    source equals the one built from its cached Mid, byte for byte,
    including `bin/rune.rbc`;
  * Mid's format decided from M1's numbers (text or binary); what the
    export basis carries for cross-unit inlining decided from a
    measurement of `--units` at `-O1` against the whole-program build
    on `tests/perf`.
* **Why now:** the cache exists; without this, production builds gain
  nothing from it.
* **Done when:** the oracle holds; the bootstrap from a warm cache is
  measured and in the table; `check-levels` holds for `--units`.
* **Touches:** `docs/ir.md` (Mid's constructor layouts); the JIT's
  metadata (M8's representations come from the same place).

#### M7, as built (2026-10-10)

* **One program of the units' Mid** (`rune --units --whole`): each unit's
  Mid as `ToMid` made it, before the optional passes, with the layouts of
  the datatypes its types name and its functions' names
  (`MidCanon.capture`), written with its names by key as a basis writes
  them (`UnitMid`, `src/driver/unitmid.sml`), kept in the unit's cache
  entry (version 5) and read back as the session names it -- from the
  entry, or from the compile just made, the same way -- then concatenated,
  renumbered and given the passes of a whole program, `Lower` and the
  target.
* **The renumbering is what makes the oracle hold** (`MidCanon`,
  `src/core/midcanon.sml`): every name -- variable, global, join point,
  type name, type variable -- numbered by where it first appears, the
  datatype layouts and function names entered again under the new names,
  and the counters the passes take fresh names from set after the last. A
  whole-program compile renumbers its Mid the same way, after `ToMid`, so a
  program and the one its units' Mid make are the same bytes: every
  program of `tests/lang` and `tests/perf` and the compiler itself, cold
  and from a warm cache (`check-units`; `check-cross`, `rune-whole`; S42).
  `check-levels` builds each both ways at `-O0` and `-O2`.
* **Against D6 as written:** the Mid is made self-contained by carrying
  the datatypes' layouts beside it rather than by writing a layout into
  each `Con` and `Decon`, which leaves `ToMid`, `MidText` and `Lower` as
  they are; and the Mid kept is the one before the optional passes, so
  `Workers` needs no idempotence over units already split. The passes after
  `ToMid` read two tables by stamp, `Ty.datatypeOf` and
  `Translate.funNames`; both travel with the Mid.
* **Inlining across units** (measured, instructions at `-O1`, the units
  linked against the whole program): `list_ops` 1.22, `array_sieve` 1.18,
  `string_ops` 1.05, `intinf_fact` 1.01, `fib`, `tak`, `real_nbody`,
  `word_bits` 1.00. A build that links its units inlines nothing across
  them and the export basis carries nothing for it: `--whole` is the
  production build, which inlines across units as a whole-program compile
  does, because it is one.
* **Measured** (the compiler, one machine, under the load of a check
  running beside it): compiled whole 4.0 s; in units from a warm cache,
  linked, 2.8 s; `--whole` from a warm cache 4.4 s; in units cold 11.9 s.
  `--whole` from the cache is not faster than the whole-program compile for
  the compiler, whose front end is about 1 s of its 4: the rest is the
  passes over the whole program (`simplify`, `lower`, `registers`), which
  `--whole` runs as the whole-program compile does. Where the front end is
  most of a compile -- MLton's sources, 611 s of elaboration in 625 (M1)
  -- `--whole` from the cache is what saves it.
* **Found on the way:** with usages checked by fingerprint, every unit
  worked out the fingerprint of every name it used, though most are the
  same entry for every unit that uses them: a cold build in units of the
  compiler took 40 s rather than 12. The fingerprint of a usage is now kept
  by its key and binder for the session (`UnitBasis.fingerprintAt`).

* **What the oracle costs a whole compile.** The renumbering copies the
  program's Mid once: about 7% of the instructions and of the bytes a
  whole-program compile allocates (measured on the bootstrap and on
  `compile-hello` with it and without). `tests/perf`'s budgets for those
  two were recorded again, with that and with the compiler's own sources,
  which the bootstrap compiles, grown by M6's third part and M7. `ToMid`
  numbering canonically in the first place would save the copy.

### M8. The dependency graph, and a program from an entry point (M, about 600 SML)

* **What:** `Deps` (`src/driver/deps.sml`): for each file, the
  module-level names it defines and uses, from the AST; the check of
  the discipline (D15) with the offending line named; the graph, its
  order, cycles and double definitions refused; `rune --deps FILE...`
  as text and as DOT; `rune main.sml -I DIR` compiling the closure of
  the entry point over the scanned directories; the Basis's MANIFEST
  columns derived by it and `--basis-check` checking the derivation;
  `tests/deps`; `docs/units.md`, *The graph*.
* **Why now:** the brief's first step towards the build system, and
  independent of everything but M2's parser per file.
* **Done when:** `rune --deps` on the compiler's own sources gives
  `sources.txt`'s order, or a valid one, and on the Basis gives
  MANIFEST's requires columns; the entry-point build of every example
  matches its listed build.
* **Touches:** M10; the language server (the graph of a project).

#### M8, as built (2026-10-10)

* **`Deps`** (`src/driver/deps.sml`): what each file declares at its top
  level -- structures, signatures, functors, type abbreviations -- and the
  module names it uses where nothing in scope binds them, from its syntax
  with the scopes of structures, functors' parameters, signatures'
  specifications and `let`; the discipline (a top-level value, function,
  exception, datatype, fixity directive or `open` named with its line); the
  order, which keeps the given order wherever the uses allow; a cycle and a
  name declared twice refused; `rune --deps` and `--deps-dot`; `-I DIR`,
  which makes the one input an entry point; `tests/deps` (`make test-deps`,
  in `make check`); `docs/units.md`, *The graph*.
* **The compiler's sources** come back from `rune --deps` in the order of
  `sources.txt`, and given in reverse, in an order the compiler builds in.
* **The Basis Library's MANIFEST**: `--basis-check` checks the requires
  column against what `Deps` derives rather than against every identifier
  of the file's tokens, and 27 files' column became what it derives. The
  tokens had made a requirement of a name in a specification (`structure
  Math : MATH` in `REAL`) or of a value's (the exception `Option`), and
  the `-Name` entries were the way around that; none is left.
* **The entry points** (examples/benchmarks, a program's `shared/main.sml`
  with `-I` its benchmark's directory, against the catalog's list of its
  sources): 122 of 152 are the same bytes; 10 are their list less a helper
  file the list names and the program never uses, which has no effect at
  its top level (`shared/output.sml`, `files.sml`, `input.sml`); 20 are
  ported programs whose files declare values or functions at the top level,
  which the analysis names and cannot order -- the case D15 leaves to an
  ordered list (M10).
* **Against D15 as written:** the entry point is `-I`'s and not every
  single-file compile's: `rune main.sml` alone compiles `main.sml`, as it
  did, so that a file that names a structure some other file of its
  directory declares (`tests/lang` has 276 files in one directory) is not
  compiled with that file.

#### M8 to M12, planned again after M7 (2026-10-10)

What M6 and M7 measured changes the plan below in three places:

* **The production build from the cache is `--whole`**, and it costs what
  the passes over the whole program cost: for the compiler 4.4 s warm
  against 4.0 s compiled whole, for MLton (whose front end is nearly all
  of its compile) to be measured by `tests/incremental/mlton.sh`. So M11's
  parallel build helps the front end and the units' own passes, and leaves
  the whole program's to one process: what it gains is the front end's
  share, which M11 measures rather than assumes.
* **A program that loads a dynamic module is built in units** (M9): a
  module names what it imports by unit identity (M3, M6), and a program
  compiled whole has none, its units renumbered into one (M7). The linked
  program keeps its units' exports for that; a whole program cannot host a
  dynamic module, and is told so.
* **M10's build files list units, and the cache is theirs** (M6): what a
  build file adds over `-I` and `sources.txt` is libraries, export lists
  and virtual modules, which M10 builds on M8's graph and M9's ABI as
  planned.

#### M9, the design (2026-10-10)

* **The ABI of a signature** (D17): a slot per value specification, in
  the signature's order, substructures' in place, recursively; a
  datatype specification's constructors take their tags in the
  specification's order; exceptions are values in their slots; abstract
  types stay abstract to the client. Its fingerprint is the hash of the
  signature's fingerprint text (`UnitBasis.fpSigma`), which names every
  type by its unit's name and path, so a client and an implementation
  compiled against the same signature in the same library agree.
* **The client**: `structure X = _dynamic "path" : SIG` elaborates as an
  opaque ascription of no structure: fresh abstract types, a fresh global
  per slot. Its translation calls `rt_dynamic (path, fingerprint, n)` where
  the declaration is, which loads the unit at `path`, runs its top level,
  checks the fingerprint it exported against the client's, and gives the
  slots as a tuple, which the client's globals are set from; a mismatch,
  or a unit that exports none, is `Dynamic.Mismatch` naming both.
* **The implementation**: `_export structure Name : SIG = strexp` in a
  unit, compiled with `--units`. The signature is known before the body,
  so a datatype of the body that a datatype specification of the signature
  matches by name takes its tags in the specification's order (D17's
  renumbering, without a second elaboration); the structure is ascribed
  opaquely; the unit's top level ends by handing the slots, in the ABI's
  order, and the fingerprint to `rt_dynamic_export`.
* **Linking the module into the program**: a unit's code names what it
  imports by unit identity, and a program linked from units keeps its
  units' identities and exports in a section of its `.rbc`, which the VM
  enters in its table of exports at start (the table `Runtime.link` already
  resolves a loaded unit against). So a module and the program share the
  Basis Library's units, and two modules that import one library share
  its types (SMLSC's definite references).
* **`Dynamic.load file`**, the untyped form (D18): `Runtime.load`, which
  M3 built, under the name D18 gives it, for a plugin that registers
  itself through a structure of the program.
* **Tests** (`tests/dynamic`): a plugin; a module through `_dynamic`; a
  mismatch; two modules sharing a library's types; a module loaded under
  `--jit=all`; the constructor order renumbered.

### M9. Compiling against a signature alone, and dynamic modules (M, about 700 SML and 100 C)

* **What:** the ABI of D17 (`docs/units.md`, *The ABI of a
  signature*): its slots, tags, layouts and fingerprint, computed from
  a signature; the elaborator binding a structure to a signature with
  no implementation (fresh abstract names, slots as imports of a unit
  still unknown); `Lower` and `Code` referring to the slots through the
  import table; the implementing side compiled to the same ABI, its
  tags renumbered, checked at link; `structure X = _dynamic "path" :
  SIG` (D18), the fingerprint emitted, checked by `rt_load` at load,
  the mismatch an exception; `Dynamic.load`; tests: a plugin, a
  mismatch, two dynamic modules sharing a library's types, a dynamic
  module loaded at `--jit=all`; rows of `docs/language.md`
  (`mod.dynamic`).
* **Why now:** the brief's third item, and the machinery virtual
  modules reuse.
* **Done when:** the tests pass on both VMs and every `--jit`; the
  ABI is documented and its fingerprint stable across the five builds.
* **Touches:** M10; native units later (the code kind).

#### M9, as built (2026-10-10)

* **As designed above**, with these as built: `_dynamic "path" : SIG` (a
  structure expression) and `_export structure X : SIG = e` (a top-level
  declaration), `StrDynamic` and `StrExport` in the syntax; the client's
  datatypes are given their constructors under their fresh names from the
  specification's own (an instance of a signature by name has fresh names
  that no table knows); the slots cross as units through `unsafe_cast`, a
  polymorphic one instantiated at unit, which changes nothing of its value;
  `RuneDynamic` and `Dynamic : DYNAMIC` in the Basis (`lib/basis/dynamic.sml`,
  `dynamic_sig.sml`); the units section of a program (`docs/bytecode.md`),
  which `Link` writes and the VM enters in its table of exports at start --
  the C of this milestone, about forty lines; `tests/dynamic`
  (`make test-dynamic`), `tests/lang/mod.dynamic_export_order.sml`.
* **The ABI's fingerprint** names no value or exception by where it was
  declared (its specification is not one), so a client and a module that
  declare the same signature in different files agree; types the signature
  names from other units by those units' names and paths. A program compiled
  whole can load no module and is none: its fingerprints are a constant, the
  same in a whole-program compile and one of the units' Mid (S42), and a
  usage, so that a unit compiled one way is not the other's entry.
* **A program that may load units** -- one that links `runtime.sml` or
  `dynamic.sml` -- keeps its units' exports in its file, under the
  identities a build from source gives them, which a module compiled from
  source names: so it takes no unit from the cache across a changed unit
  (M6's remapping), whose old identity it would keep. Other programs carry
  no units section, and are the bytes they were.
* **Left:** a constructor or an exception that a structure gives as a value
  specification (`val A : t` where `A` is a constructor) is refused at
  `_export`; the client's slots go through the wrapper of every call, as
  D17 says, with no adapter for a worker's arity.

### M10. The build language and virtual modules (L, about 1,200 SML)

* **What:** the language of D16 -- its grammar and AST in
  `docs/build.md`, a parser and an elaborator to the list of units
  with their bases and modes; files in order, groups ordered by M8,
  libraries with export lists, `local`, `open`, renaming, path
  variables, annotations, the cache's location; `virtual structure X :
  SIG` and `implements X = ...` with one implementation per program
  and `where type` between virtual modules; packages as build files
  reached by path variable; `.mlb`, `.cm` and Poly/ML scripts generated
  from it (`scripts/gen-build-files.sh` reads it); the file extension
  chosen here (not `.rune`, which the cache directory has);
  `lib/basis`'s build file replacing MANIFEST (seals as re-ascriptions,
  the epilogue as the last unit); the compiler built from its own build
  file; `tests/buildfile`; a `basis.virtual` example swapping `IntInf`'s
  implementation, the brief's own case.
* **Why now:** after the graph (M8) and the ABI (M9) it composes.
* **Done when:** `rune` builds itself, `runedoc`, `runeopt` and the
  Basis from build files; the five builds still identical from the
  generated scripts; `sources*.txt` and MANIFEST deleted; the virtual
  `IntInf` example runs with either implementation.
* **Touches:** the hosts' build files; `docs/building.md`;
  `AGENTS.md` (the rules about `sources.txt` and MANIFEST).

#### M10, as built (2026-10-10)

* **The language** is what `docs/build.md` has: files in order, `files`,
  `group` (in the order of M8's graph), `local`, `library` with an export
  list, `use` (a build file elaborated once), `implements`, `annotate`,
  `cache`, `libraries`, and path variables (`--path NAME=DIR`). `BuildFile`
  (`src/driver/buildfile.sml`) reads it; the units driver follows the plan
  it gives, a step's basis a snapshot of the elaborator's tables and a step
  what it adds to them (`Main`'s `snapshot`, `deltaOf`, `apply`), so an
  export list or a `local` hides what the files after it do not see.
  `rune --build FILE`, `--build-list FILE`; `tests/buildfile` (`make
  test-build`, in `make check`).
* **The programs** have build files, `rune.build`, `runedoc.build`,
  `runeopt.build` and `runeisa.build`, in place of `sources*.txt`; before a
  rune exists the Makefile and `scripts/gen-build-files.sh` read their
  `files` blocks with `scripts/build-files.sh`, and `rune --build rune.build
  --whole` is the bytes of the compiler built from the hosts' generated
  scripts (`scripts/check-cross.sh`, the build-files job).
* **The libraries** have `library.build` (`lib/basis`, `lib/random`,
  `lib/test/property`): the files in load order, in blocks annotated with
  what a file is to a program (`always`, `demand`, `seal`, `final`,
  `host=...`), and `libraries` for those a library is written on. What a
  file provides and requires is no longer written by hand: `rune
  --basis-index DIR` derives it -- the declarations, and `Deps`'s uses --
  and writes `DIR/MANIFEST`, which `make manifests` makes and git does not
  keep. The seals stay files of their own and the epilogue a `final` file,
  as they were; `scripts/gen-basis-sigs.sh` writes its block into the
  Basis's build file.
* **Virtual modules**: `structure X = _virtual : SIG` at a structure
  binding, `StrDynamic` with `DynamicVirtual X`; the build file's
  `implements X = ... end`, whose files end with `_export structure X :
  SIG`; `RuneDynamic.take` finds the export of the name, where the
  fingerprints agree, as `load` does for a loaded unit. What an
  implementation declares is hidden from the files after it, so the units
  compiled against the virtual module name none of it: in
  `examples/virtual/bigint`, two implementations of a `BIGINT` (the Basis's
  `IntInf`, lists of digits), the second build through the first one's
  cache compiles the implementation alone. Two implementations are refused;
  none raises `Dynamic.Mismatch` when the declaration runs, the build not
  knowing which units declare a virtual module when the cache serves them.
  A virtual module is part of its program, which can be compiled whole.
* **Left:** `open` and renaming in a build file, `where type` between
  virtual modules, levels per unit; and the brief's case exactly, the
  Basis's own `IntInf` virtual: inside the Basis it is named by `Int`,
  `Word`, `Real` and the scanners, which would all reach it through the
  slots, and the Basis is compiled by its MANIFEST, not a program's build
  file -- so the example swaps a program's big integers, one of them
  `IntInf`, and the Basis's waits for the Basis to be built from its build
  file as a program's units are.

### M11. Parallel and reproducible builds (M, about 500 SML)

* **What:** `rune -j N` over a build file: the units of the graph
  compiled by child processes (`Posix.Process.fork`, or `spawn` where
  there is no fork) in topological order, the cache as the exchange,
  the parent linking; `make check-reproducible`: a fresh checkout, a
  warm cache and a cold one build the same bytes; `--explain-rebuild`
  over a whole build; measurements: the compiler and the Basis at
  `-j 1`, `-j 8`, `-j 16`.
* **Why now:** the graph, the cache and the build file exist; the
  brief's "highly parallel and declarative build system" is this.
* **Done when:** the speed-up is in the table; `check-reproducible`
  is in `make check`.
* **Touches:** green threads (a later in-process pool); the corpus
  harness (its ad hoc build).

#### M11, as built (2026-10-10)

* **`rune -j N`** (`src/driver/parallel.sml`, `docs/units.md`, *Parallel
  builds*): the parent goes through the units in order, each through the
  cache, as a build by one process does, and forks children -- copies of
  itself at the unit it is at, so with its basis in memory -- for the units
  after it that are likely to be compiled, whose units before them are
  done, and whose text is at least `RUNE_PARALLEL_MIN` bytes (16384). A
  child goes through the units its own needs, from the cache, skips the
  others, compiles its unit into the cache and ends; the parent takes the
  unit from the cache when it gets there. A unit the parent misses and no
  child has, it compiles itself. The graph is M8's, by name, and the
  MANIFEST's for the Basis. What the build gives is the parent's pass, so
  `-j` changes the time and nothing else: S58 holds a project built with
  `-j 4` to the same units compiled, the same standard error and the same
  bytes as one process, cold, warm, after edits and after an error.
* **`make check-reproducible`** (`scripts/check-reproducible.sh`): the
  compiler built from `rune.build` is one set of bytes over eleven builds --
  in units and whole, without the cache, through a cold cache and warm, at
  `-j 1` and `-j N`, and from a copy of its sources in another directory --
  and the whole ones are `bin/rune.rbc`. A program names the Basis's files
  by the path the compiler was run by (`bin/../lib/basis/...`), so the
  builds run `bin/rune` by that name, the copy through a link to `bin`; a
  checkout elsewhere run the same way gives the same bytes.
* **Measured** (2026-10-10, 16 threads; another session's `make check`
  shared the machine, so each configuration ran five times interleaved
  with the others and the least is shown):

  | Build | `-j 1` | `-j 4` | `-j 8` | `-j 16` |
  |---|---|---|---|---|
  | the compiler in units, cold (the Basis from the frozen cache) | 5.63 s | 6.17 s | 7.11 s | 6.04 s |
  | the same, warm | 2.66 s | 2.93 s | 3.03 s | 2.85 s |
  | the compiler whole (`--whole`), cold | 6.88 s | | | 7.62 s |
  | the Basis, every file, no frozen cache | 4.38 s | 4.68 s | 4.85 s | 4.43 s |

  **There is no speed-up**, and the reasons are measured. Once a type
  name's fingerprint is a hash (*M6, the third part as built*), the
  compiler's 63 units compile in 4.1 s together, and the graph's critical
  path is 1.7 s of that: at most 2.4 times on the compile work. Under it
  is the parent's pass through the cache -- reading each unit's entry,
  loading its basis, linking -- which is what a warm build costs (2.7 s) and
  which is not parallel at all. So the best a cold build could be is about
  4.4 s against 5.6 s, and each child costs a fork, its collections over
  pages it shares with the parent (copied on the first write), and the
  parent's reading of what it compiled, which uses the margin up; `-j`
  also analyses every file's dependencies before it starts (0.2 s). The
  Basis is the same in small: 250 files, most a few hundred lines, in a
  graph that every `always` file and every seal file make deep.
* **What would make it pay**, in the order of what it would gain: the
  parent's pass made cheaper or parallel (loading the entries of the units
  that do not depend on each other at once; the link reading code in
  parallel), which is the floor of every build, cold or warm; a pool of
  compilers that stay up between builds and take units over a pipe, so
  that no process is forked per unit and no basis is copied (the green
  threads' in-process pool the plan named); and units coarser than a file
  where files are small. None of it is built; the measurement is the
  result.
* **Found on the way:** a unit's usages were most of a compile in units
  (the fingerprint of a type named the text of every type it was made of),
  fixed in M6's third part; `--pass-stats` reports what each unit took, and
  the phases of a unit's compile outside the passes (`unit-usages`,
  `unit-export`, ...).

### M12. Hot reload, the compiler as a service, packages: research and prototypes (L)

* **What:** three studies, each a section of this file with a
  prototype behind a flag and a decision for the owner:
  * **hot reload:** `Runtime.reload` on Erlang's semantics -- a
    reloaded unit is a new unit, its exports rebound in the export
    table's slots so that calls through them switch, old closures keep
    old code, direct calls across units invalidated through the JIT's
    code objects (jit M6) and live frames deoptimised where M11 is
    built; a prototype on a program that reloads a module in a loop;
    the state question (a changed datatype, a changed `ref`) stated
    with Hicks and Nettles's answers and left to the owner;
  * **the compiler as a service:** the resident compiler behind a
    protocol on stdio (open a project, elaborate a buffer, diagnostics
    with spans, the type at a position, the definition of a name),
    what the IDE brief (`docs/plans/ide.md`) will consume; a prototype
    answering diagnostics and hover for one file;
  * **packages:** a survey of Smackage, opam, cargo and Nix against
    Rune's build files and cache; a sketch of a lock file over
    content-addressed sources; no implementation.
* **Why now:** last, as the brief says, and after the JIT's second
  part is known.
* **Done when:** each study has its prototype measured and its
  decision written.

#### M12, as built (2026-10-10)

Three studies, each with its prototype behind a flag, what it measured, and
a decision for the owner.

**Hot reload.** `Dynamic.reload FILE` loads the unit in `FILE` again for
every `_dynamic` declaration that loaded it. A declaration's slots are now
set by a function of the module's tuple, which `RuneDynamic.load` calls and
keeps; `reload` runs the new unit's top level, checks its fingerprint and
calls the function again. This is Erlang's rule: a call through the
structure (`L.step`, a load of the slot's global) reaches the new code, and
a function taken from the structure before (`val kept = L.version`) stays
the old one, as a local call in Erlang does. A module of another signature
changes nothing, and `Mismatch` says so. `tests/dynamic/run.sh` reloads v1
to v2 while the program runs, under the interpreter and `--jit=all`; that
it passes under the JIT says that compiled code reads a slot's global when
it calls through it and keeps no old value of it. A reload of a 653-byte module costs 0.8 ms in the interpreter
and 1.1 ms with `--jit=all`, the file copied each time included (500
reloads in a loop). Old code is never freed: every version stays in the
VM's table of units, where Erlang purges a module's old version when a
third is loaded.

*The state question*, which the prototype answers only by refusing:

* **Abstract types.** The program holds values of the signature's abstract
  types (`S.t`) made by v1, and v2's functions read them by v2's
  representation. The fingerprint is the signature's, so it cannot see the
  difference, and the result is a type confusion. `reload` therefore
  refuses a module whose signature has an abstract type (datatypes are
  safe: their constructors and tags are the signature's). Hicks and
  Nettles (*Dynamic software updating*, TOPLAS 2005) answer this with a
  *state transformer*: the new version supplies `upgrade : old.t -> t`,
  applied to every value of the old type that is live, which needs either
  the collector to find them (a typed heap walk) or the values to be
  reached through one indirection that the update rewrites.
* **Module state.** A `ref` in v1 is not carried to v2: v2 starts with its
  own top level. Erlang's OTP carries state through `code_change/3`, a
  callback of the new version given the old state. In Rune that would be
  an `_export`ed `migrate : Old.state -> state` that `reload` calls with
  what v1 exports, which needs v1's state type in v2's signature.
* **When.** The reload happens when the program calls it, between two
  calls through the structure, which is Hicks and Nettles's update point
  chosen by the program. Frames of v1's functions on the stack keep
  running v1's code, as in Erlang.

*For the owner:* (a) keep `reload` for signatures without abstract types
and grow from there, (b) add state transformers (`upgrade` per abstract
type, chosen by the new module) with a heap walk at the update point, or
(c) leave hot reload as this prototype. Recommended: (a), with (b)
designed when a program wants it. Old versions could be dropped on the
third load, as Erlang does, once nothing names them: the units section
knows which unit a slot came from.

**The compiler as a service.** `rune --serve [OPTION...]` reads one
JSON-RPC 2.0 message per line on standard input and answers on standard
output, which is the transport `docs/plans/ide.md` chose for the IDE's
service (`src/driver/serve.sml`). A request names a program's files in
order and an editor's text of one of them, which is compiled in place of
the file (`Source.overlays`). The methods are `initialize`, `diagnostics`
(every error and warning with its byte span, line and column, kept as data
by `Error.note`), `hover` (the innermost variable whose span holds an
offset, its name and its type at that use, from the elaborated syntax that
`Main.keptSyntax` keeps) and `shutdown`. Each request is answered by a
child forked for it, which compiles the program in units through the cache
as far as types and ends: nothing one request leaves in the compiler's
state reaches the next, which is the isolation `docs/plans/ide.md` asks
for without making the compiler's state explicit. `tests/serve/run.py`
(`make test-serve`) drives it; a request on a two-file program takes 21 ms
warm, the Basis taken from the frozen cache. Not built: the definition of
a name and its references (the stamps in the syntax give both, as the
IDE's own adapter in rune-ide does), and a parent that keeps the
program's units loaded and forks at the edited unit -- as `Parallel`'s
children do -- so that a request compiles only that unit and the ones
after it, which is the next step for a large program.

*For the owner:* the IDE (rune-ide) builds the compiler's front end into
its own service and reads the elaborated syntax there. The choice is
between (a) the IDE driving `rune --serve` -- one compiler for the command
line and the IDE, with the cache, the build files and `-j` shared, at a
fork per request -- and (b) the IDE embedding the front end as now, which
avoids a process but keeps its own copy of the compiler's state.
Recommended: (a), with the methods grown to what rune-ide's M5 needs.

**Packages.** A survey of four systems against Rune's build files and
cache; no implementation.

| | Smackage | opam | cargo | Nix |
|---|---|---|---|---|
| What a package is | a git repository; versions are its tags (`v1.2.3`) | an `opam` file in a repository of descriptions, the sources a tarball or a git URL | a crate on a registry (crates.io), a `Cargo.toml` | a derivation: a build of inputs, each pinned |
| Choosing versions | the newest tag with the asked prefix | a solver (CUDF) over version constraints | semver ranges, one version per major per build, a lock file | none: every input pinned by hash |
| Pinned how | not pinned | `opam lock`: exact versions | `Cargo.lock`: exact versions and the checksum of each crate | `flake.lock`: revisions and the hash of each input's files |
| Builds | CM or MLB through a path variable | per package, by its own build (dune) | cargo, per project, with fingerprints | sandboxed, from the pinned inputs |
| Shared results | none | dune's cache, by the digest of each rule | none across projects | the store and binary caches, by the hash of the inputs |

Rune has two of the pieces already. A build file reaches another by a path
variable (`use $(JSON)/library.build`), which is what Smackage does with
CM's and MLB's variables; and the cache keeps a unit by its name, its text
and the identities of what it used (M6), which is content addressing at
the grain of a unit, finer than dune's rules or Nix's derivations. What is
missing is the lock: what a path variable names, pinned. A sketch:

```
(* rune.lock -- written by `rune lock`, read by `rune --build` *)
package json 1.2.0
  source git https://example.org/sml-json.git 4f1c2e9a...
  files sha256 9b0d...      (* the files its build file lists, in order *)
  path JSON                 (* the path variable it is reached by *)
```

`rune --build` would fetch each package by its revision into a store
named by the files' hash, set its path variable there, and refuse a
package whose files hash otherwise. A unit of a package is then named by
the package and its version (`json-1.2.0/parser.sml`), so that its entry in
the cache is the same in every project that locks that version, and a
cache could be shared between projects and machines as the frozen Basis is
between programs.

*For the owner:* (a) git repositories and tags, as Smackage, with the lock
file above, (b) a registry of descriptions, as opam and cargo, or (c)
nothing yet. Then: one version of a package per build (simplest; SML's
names would otherwise need `library` export lists to keep two apart), or
several. Recommended: (a) and one version per build, the lock first, since
it is what makes a build of someone else's code reproducible
(`make check-reproducible` holds that for Rune's own).

#### After M12: what is left (2026-10-11)

What this roadmap did not finish, and where each is written down:

* **M6's warm build of a small program.** Its "done when" asked for the
  two-line program from a warm cache in under twice `hello`'s time. It
  takes 0.34 to 0.45 s, `hello` 0.04 to 0.09 s, and compiling the two
  lines whole 0.32 to 0.46 s (five runs each, a busy machine): reading,
  checking and loading the bases of the 56 Basis units it uses, and
  linking them, cost what compiling does. Loading a basis is what to make
  cheaper -- the bases are smaller since issue 14 -- or a program could
  link against the frozen Basis's units without loading their bases
  whole.
* **Issue 15's remainder** ([build-cache-issues.md](build-cache-issues.md)):
  an entry taken across a unit that changed keeps the old unit's
  identity; written again against the new units when it is loaded, it
  would have a fresh compile's, and `--verify-cache` could compare it.
* **`-j` gives no speed-up** (*M11, as built*: what would make it pay).
* **M12's three decisions** for the owner (*M12, as built*): hot reload,
  the IDE on `rune --serve`, packages. `Dynamic.reload` frees no old code.
* **The compiler as a library**, as the owner meant M12's service:
  [compiler-library.md](compiler-library.md), after the REPL's branch is
  merged.
* **Two measurements not explained.** MLton's compiler built in units
  without the cache holds 3.3 GB at its peak, where through the cache the
  heap held 166 MB after 400 units; what the build without the cache
  keeps is not known (`tests/incremental/mlton.sh` allows for it). And
  measuring issue 14, a value a `ref` had held stayed reachable until the
  next store into that `ref` -- a list rebuilt into `UnitBasis.units` freed
  the old one only when the list was rebuilt a second time -- which may be
  a dead register of the measuring frame or something of the collector's;
  it was not looked into.
* **MLton's compiler in units costs five times its whole compile**
  (performance.md's M10, 2026-10-20, at `a6a024ab1`; the raw numbers with
  the drafts, `results/M10/units/`). At tier 2, `--units --no-cache` takes
  433 s against 84 s whole, and the units' interfaces take 367 s of it:
  `unit-usages` 174 s, `unit-export` 148 s, `unit-load` 29 s, `link` 15 s,
  with elaboration 56 s. MLton's build of the same compiler: 263 s, of
  which usages 98 s and export 110 s, against 60 s whole. What the time is:
  * **Hashing fingerprints' text.** `P.hash`'s loop is 36% of the
    cycles of the build at tier 2 (`perf record` over `--jit-perf-map`),
    the collector 25%, string concatenation and its copies 8%; building
    the text (`fpEnv`, `fpTy` and the rest) is 1.3%, `fpTy` 0.8% of it, so
    its list of type variables costs nothing that shows. The build hashes
    2,136 MB (counted by call site in a build with counters, which counts
    the same on every engine): a signature's fingerprint (`fpSigma`, the
    usages `sig`) 818 MB in 710 hashes, a functor's (`fpFunctor`, since
    performance M3 its signature) 430 MB in the usages and the same 432 MB
    again in `export`, whose `binding` asks `fingerprint` directly and not
    `fingerprintAt`, so the memo does not see it; the basis's pickle 220
    MB for the unit's identity in `export`, and the same 220 MB again in
    `load`; the rest 27 MB. `amd64-codegen.fun` alone hashes 190 MB: 12
    functors' fingerprints of 7.3 MB of text each, twice, and 11 MB of
    signatures. At tier 2 a byte costs about 170 cycles -- four `mod`s by
    constants per character, which tier 2 does with `idiv`
    ([jit.md](jit.md), *Left by the performance plan*).
  * **The memo is not the leak.** One process compiles every unit and
    `startSession` empties `fpMemo` once: 61,550 lookups hit and 23,096
    miss. What misses it is `export`'s path above.
  * **What M3 added.** On MLton's build, `921af2cc` takes 281 s in units:
    elaboration 139 s, usages 55 s, export 55 s; the tip 263 s: 20 s, 98 s
    and 110 s. Typing functors by their signature took 119 s out of
    elaboration and put 98 s into the interfaces.
  * **What would take it back:** the export's functor fingerprints through
    the memo (−432 MB); the identity `export` worked out given to `load`
    (−220 MB); fingerprints as hashes of their parts' hashes, kept per
    structure and signature, so that no text grows to megabytes; and a
    hash that costs less a byte on every host. These are the fixes of
    [units-fixes.md](units-fixes.md), with their order and measure of done.

### Why this order

* **Measure, then the front end.** Every estimate here predates the
  JIT's tiers; the two decisions that depend on numbers are taken after
  M1.
* **The resumable compiler before anything else** (M2): the one piece
  that cannot be retrofitted, built while nothing runs on it, and
  tested by the cross-test at once.
* **Loading before the REPL** (M3 then M4): a REPL is a compiler that
  loads what it compiled; the static linker beside it gives batch
  incremental builds the same day.
* **HOL4 before the cache** (M5 before M6): HOL4 on Poly/ML has no
  cache, so Rune needs none to host it; and the owner's first wish is
  answered as early as it can be.
* **The on-disk basis after the in-memory one** (M6 after M2 and M4):
  what it must carry is known by then, and `use` is what makes it
  worth having.
* **Whole-program from the cache after the cache** (M7), then the
  graph and the ABI, which are independent (M8, M9), then the language
  that composes them (M10), then the builds over all of it (M11), and
  research last (M12).
* **Three stopping points**: after M4 Rune has a REPL; after M5 it
  hosts HOL4; after M7 a compile costs what changed. Each is a whole
  result.

## Prerequisites and flags

This roadmap starts when the JIT roadmap has finished, and it assumes
at least jit M7 -- tier 0 finished, code objects and the driver, tier
1 complete and fast, tiering and invalidation -- since that is the
stopping point the owner kept open. What it takes from each JIT
milestone, and what it does where a milestone was not built:

* **jit M3, code objects and the driver:** taken as built. A unit adds
  functions; `JitProgram.codes` grows; the driver's rule is why
  `rt_load` returns a closure.
* **jit M6, tiering and invalidation, the poll points:** the poll
  points are where interrupts are raised (D11); invalidation is what a
  reload uses (M12). Without M6, interrupts poll in the interpreter's
  loop alone, and `--jit=all` is the JIT's only mode for loaded units.
* **jit M8, metadata per function:** each `.rbu` carries its own
  section; `Exception.location` reads the line table either way.
  Without M8, the section is empty.
* **jit M11, deoptimisation:** a reload with live tier-2 frames (M12).
  Without M11, a reload waits for the frames to return, or M12 says it
  cannot.
* **jit D12, target 4:** "the JIT compiles bytecode that arrives at run
  time" is what M3's `--jit=all` on arrival relies on.
* **jit D7 C, the metacircular tier:** becomes possible after M4, when
  the compiler is resident; a note for the JIT's second part, not work
  here.

What the other plans take from here, and when it becomes critical for
them:

* **The language server and the IDE** (`docs/plans/ide.md`): spans and
  positions in the export basis (M2, M6), the cache as the project's
  store (M6), the graph of a project (M8), and the service protocol
  (M12). Critical at M2: the basis must keep spans from the start, or
  it is rebuilt for the LSP.
* **Native code, and native dynamic modules:** the code kind in the
  unit header (M3) and the ABI of a signature (M9), which a native unit
  would implement with a calling convention of its own. Critical at M3:
  the header has the field from its first version.
* **Green threads:** HOL4's thread shims (M5) are what real threads
  replace; a parallel build in-process (M11) is their first user; the
  interrupt flag (M4) is a scheduler's first poll. Nothing here decides
  a thread's shape.
* **The FFI:** nothing; a dynamic module is bytecode.
* **The collector** (jit D14): the resident compiler keeps a large
  static basis live (D9), and a generational collector stops copying
  it at every collection. M1 measures the cost; if it is large, the
  collector's timing moves up.
* **Delimited continuations:** an interrupt raised at a poll point is
  an ordinary raise; a continuation captured across `use` is a question
  for that roadmap.

## Relation to other plans

| Elsewhere | Here |
|---|---|
| jit.md, *Prerequisites and flags*: incremental compilation, the REPL, dynamic modules, hot reload | consumers of M3, M6, M8, M11 as listed above |
| jit.md, *What is different for SML*: "The one thing that will invalidate compiled code is reloading a module" | M12 |
| jit.md, D7 C: the metacircular tier "once the incremental roadmap makes the compiler resident" | M4 makes it resident |
| jit.md, D11: no native code in images | kept; a unit in an image is bytecode |
| middle-end.md, *Ready for, not built*: a whole-program flag on every pass, stamps unique within a unit, Mid's printed form as an interface | M2 (`Pass.whole`), D3, D6 and M7 (Mid per unit, not as the interface) |
| middle-end.md, M3: the top level as a list of definitions | the unit of D1 at the REPL |
| codegen.md, *To revisit*, D11: "a compiler or an interpreter offered as a service may later let it continue into the other program" | M12, the service; `Runtime.restore` unchanged |
| performance.md item 13, a generational collector | the cost of the resident basis (D9, M1) |
| weak-points.md, items 1, 3, 4, 6, 9 | M6 and M8 (1), M2 and M4 (3), M4 (4), M4 (6), M10 and M12 (9) |
| sml97.md, *Out of scope*: "An interactive top level" | M4, and `docs/language.md`'s row |
| tests/basis/xc2/README.md, *How a program is made* (the `.mlb` files of MLton's and MLKit's libraries, flattened) | M10's build language reads what xc2 reads |
| docs/plans/ide.md | M12's service; spans kept from M2 |
| the corpus (`rune-corpus-sml97`) | its `sources.txt` and `corpus.mlb` become a build file (M10); its harness gains `--units` builds to compare (M2) |

## Risks

1. **The basis is bigger than it looks.** The elaborator's state is in
   nine places and the AST's slots; something left out of `Basis`
   shows as a unit that compiles in memory and not from the cache. M2
   moves everything behind one record before M6 serialises it, and
   M7's byte-identity oracle catches what was missed.
2. **Determinism breaks quietly.** A renumbering that depends on a hash
   table's order, a `Time.now` in a fingerprint, a path in a pickle:
   the five builds diverge or the cache never hits. `check-cross` runs
   with the cache on from M6, and the cold-equals-warm test is in
   `make check`.
3. **Functor bodies in the basis are large and change often.** Every
   client of a functor recompiles when its body changes; a project that
   functorises everything gets little cut-off. Measured on HOL4 (M5),
   whose kernel is functorised; the answer, if it matters, is SMLSC's
   handoff: an SC import against a functor signature, listed in *Ready
   for, not built*.
4. **The resident compiler's heap.** The Basis Library's basis and
   HOL4's live in the user's heap and are copied at every collection.
   M1 measures it; jit D14's collector is the cure; `shareCommonData`'s
   analogue and a basis kept in an old space are the palliatives.
5. **HOL4 is larger than its host layer.** Thread shims, `SML90`,
   Basis gaps and Rune's speed at tier 1 may stop `build` short of
   `src/boss`. M5 is where the owner decides, and it lists what did
   not port with a reason rather than promising.
6. **`--count` loses its reach.** Incremental builds are not
   `--count`-comparable to whole-program ones; output is the oracle
   (`check-units`), and the whole-program build from the cache stays
   byte-identical. A bug that shows only in `--count` of a unit build
   is found by the JIT's suites at `--jit=all`, which hold `--count` to
   the interpreter's on the same program.
7. **Format churn.** `.rbi`, `.rbu`, the cache's layout and the build
   language all change while they are young. Each carries a version
   and the compiler's identity; an old entry is a miss; the `.rbc`
   version bumps as `AGENTS.md` says.
8. **The file discipline surprises a user.** A file with a top-level
   `val` put in a group is refused with its line; the escape hatch is a
   line in the build file. `docs/build.md` says so in its first page.
9. **Interrupts at the wrong moment.** A raise at a poll point inside
   a primitive's arguments, or during `use`'s own bookkeeping, leaves
   the session's basis half-extended. The mask of D11 covers the
   compiler's critical sections; the rollback of D12 covers the rest.
10. **Other sessions on the branch.** jit M2, M3 and M4 landed while
    this file was written. `git log` before every commit.

## Testing

* **The cross-test** (`make check-units`, M2): every program of
  `tests/lang` and `tests/perf` built per file and whole gives the
  same output, exit status and traces at `-O0`, `-O1` and `-O2`; from
  M3 the same with the units loaded into a running VM instead of
  linked; from M6 the same from a warm cache.
* **Byte identity** (M2, M6, M7): the whole-program build unchanged by
  M2; cold equals warm; the build from cached Mid equals the build from
  source, `bin/rune.rbc` included, in `check-cross`.
* **The cache's scenarios** (`tests/incremental`, M6): the list of M1
  run by a script over a scratch project, asserting what recompiled and
  that outputs match.
* **The REPL's transcripts** (`tests/repl`, M4): inputs and expected
  outputs, run on both VMs and every `--jit`, with the Chapter 8 cases,
  `use`, printing, interrupts, save and restore.
* **The loader** (`tests/vm`, M3): malformed units, missing imports,
  wrong fingerprints, double loads, loads then images.
* **HOL4 as a corpus** (M5): `build` through `src/boss` and
  `--selftest 1`, run by hand, its time recorded.
* **The graph** (`tests/deps`, M8): orders, cycles, double
  definitions, the discipline's errors; the compiler's and the Basis's
  own graphs.
* **The ABI and dynamic modules** (M9): plugins, mismatches, shared
  types, every `--jit`.
* **The build language** (`tests/buildfile`, M10): its grammar's cases, the
  generated host files, the virtual `IntInf`.
* **Rules for `AGENTS.md`** (M2, M3, M6, M10): a unit's format is its
  description in `docs/bytecode.md` and its writer and reader; the
  basis has one record and everything the elaborator keeps is in it; a
  cache entry is content-addressed and versioned; the build files are
  the source of the hosts' scripts, never the reverse.

## Measuring

* **Compile time by phase** (`--pass-stats`) and wall clock, best of
  five, on the programs of M1, before and after each milestone that
  touches the compiler; `perf stat -e instructions:u` for the shipped
  compiler, where wall time is noisy (rune-verification's rule).
* **Cold and warm**: every compile of M6 onward reported twice, with
  `--explain-rebuild`'s count of units recompiled.
* **The REPL**: start-up from the boot image; `use` of a 5,000-line
  file; a small declaration's latency; a session's image size.
* **HOL4**: `build`'s wall time, the images' sizes, `hol`'s latency,
  against Poly/ML's numbers of M1.
* **The budgets** of `tests/perf` stay the deterministic gate for the
  whole-program build; a `--units` budget per program is added at M3
  for the incremental build, as a second set.
* **`--jit-stats`** on loaded units: functions compiled on arrival,
  time compiling.

## Ready for, not built

Listed so that the next roadmap, or the owner, finds them here:

* **SC against a functor signature** (SMLSC's functor specifications):
  a client compiled against `functor F (X : S) : T` without F's body,
  which needs run-time functors or a link-time expansion; the answer to
  risk 3 if HOL4 shows it matters.
* **A hierarchy of images** (Poly/ML's parent and child states): an
  image that holds only what a parent does not; for HOL4's hundreds of
  theory heaps.
* **The two-process REPL** (Elsman 2026) over `Compiler`: an editor or
  a notebook driving the compiler through a pipe.
* **Autoloading** (CM): a library loaded when an unbound structure is
  named at the REPL.
* **A REPL with editing**: history, multi-line editing, completion
  from the basis; the brief's "enhance it as a separate plan later".
* **Cross-unit inlining in incremental builds**: what the export basis
  carries beyond arities, decided in M7 by measurement.
* **A query-based compiler** (rustc): per-declaration incrementality
  inside a unit, for the language server; the service of M12 is the
  step before it.
* **Native units**: the code kind of the header, a second loader, the
  ABI implemented by a calling convention.
* **Hot reload in production**, if M12's decision is yes.
* **The elaborator at the scale of MLton** (M1): signatures that share
  structures of a large signature take seconds each, and functor bodies
  are elaborated again at every application; 98% of compiling MLton's
  compiler is elaboration. A profile and a plan of its own, with
  `type-checker.md`; the cache only hides it for files that do not
  change.
* **Printing without the compiler** (D10's review): type descriptions
  and a run-time model of `Rep` for a debugger or the IDE's hover on a
  live value; jit M8's representations section is its start.

## References

The papers were read on 2026-09-25 and every DOI checked against
Crossref's record that day; manuals, sources and blogs give their URL.

**Separate and incremental compilation for ML** (*What the literature
says*, D2 to D6, D14):
* Appel, MacQueen. "Separate compilation for Standard ML." PLDI 1994.
  doi:10.1145/178243.178245. Also Princeton TR-452-94.
* Shao, Appel. "Smartest recompilation." POPL 1993.
  doi:10.1145/158511.158702.
* Blume. "Dependency analysis for Standard ML." TOPLAS 21(4), 1999.
  doi:10.1145/325478.325481.
* Blume, Appel. "Hierarchical modularity." TOPLAS 21(4), 1999.
  doi:10.1145/325478.325518.
* Blume. "CM: The SML/NJ Compilation and Library Manager (for SML/NJ
  version 110.40 and later), User Manual." https://www.smlnj.org/doc/CM/new.pdf
* Adams, Tichy, Weinert. "The cost of selective recompilation and
  environment processing." TOSEM 3(1), 1994. doi:10.1145/174634.174637.
* Elsman. "Static interpretation of modules." ICFP 1999.
  doi:10.1145/317636.317800.
* Elsman. "A framework for cut-off incremental recompilation and
  inter-module optimization." IT University of Copenhagen, technical
  report, April 2008. https://elsman.com/mlkit/pdf/sepcomp_tr.pdf
* Elsman. "Type-specialized serialization with sharing." TFP 2005.
  https://elsman.com/pdf/TFP05final_mael.pdf
* MLKit. "ML Basis Files." https://elsman.com/mlkit/mlbasisfiles.html
* Swasey, Murphy, Crary, Harper. "A separate compilation extension to
  Standard ML." ML Workshop 2006. doi:10.1145/1159876.1159883. Revised
  and expanded as CMU-CS-06-133, September 2006.
  https://www.cs.cmu.edu/~crary/papers/2006/smlsc.pdf
* MLton. "ML Basis" and "ML Basis syntax and semantics"; the formal
  semantics, `mlb-formal.pdf`. http://mlton.org/MLBasis
* Romanenko, Russo, Sestoft. "Moscow ML Language Overview", version 2.00, June 2000, section 11,
  "Grammar for the Moscow ML Unit language". https://mosml.org/mosmlref.pdf
* Russo. "Types for Modules." ENTCS 60, 2004 (the Edinburgh thesis of
  1998). doi:10.1016/S1571-0661(05)82621-0.
* Dreyer, Crary, Harper. "A type system for higher-order modules." POPL
  2003. doi:10.1145/604131.604151.
* Weeks. "Whole-program compilation in MLton." ML 2006.
  doi:10.1145/1159876.1159877.

**REPLs and resident compilers** (D9 to D13, M4, M5):
* Poly/ML. "The PolyML structure"; "PolyML.Compiler";
  "PolyML.NameSpace"; "PolyML.SaveState".
  https://www.polyml.org/documentation/Reference/PolyMLStructure.html
* SML/NJ. "The SML/NJ interactive system."
  https://smlnj.org/doc/interact.html
* Elsman. "Crafting a REPL for HOT compiled execution." DIKU technical
  report, 2026-09-19. https://elsman.com/pdf/repl.pdf; the Rocq
  development, https://github.com/melsman/repl-rocq
* Kumar, Myreen, Norrish, Owens. "CakeML: a verified implementation of
  ML." POPL 2014. doi:10.1145/2535838.2535841.
* Sewell, Myreen, Tan, Kumar, Mihajlovic, Abrahamsson, Owens. "Cakes
  that bake cakes: dynamic computation in CakeML." PLDI 2023.
  doi:10.1145/3591266.
* GHC User's Guide, "Using GHCi" (the external interpreter).
  https://downloads.haskell.org/ghc/latest/docs/users_guide/ghci.html
* Vassilev. "Interactive C++ with Cling." LLVM blog, 2020.
  https://blog.llvm.org/posts/2020-11-30-interactive-cpp-with-cling/
* HOL4, branch `develop`, https://github.com/HOL-Theorem-Prover/HOL:
  `tools-poly/holrepl.ML`, `tools-poly/prelude.ML`,
  `tools-poly/prelude2.ML`, `tools-poly/poly-build.ML`,
  `tools-poly/execompile.ML`, `tools-poly/holinteractive.ML`,
  `tools-poly/poly/poly-init.ML`, `tools-poly/poly/poly-init2.ML`,
  `tools-poly/poly/quse.sml`, `tools-poly/poly/sref-bootstrap.ML`,
  `tools-poly/Holmake/CompilerSpecific.ML`,
  `tools/Holmake/poly/BuildCommand.sml`,
  `tools/Holmake/poly/poly-Holmake.ML`, `tools/Holmake/Systeml.sig`,
  `src/portableML/poly/MLSYSPortable.sml`,
  `Manual/Developers/developers.md`; and the built Trindemossen-2 at
  `/home/ruud/.local/hol4` (`bin/hol`, `bin/hol.ML`, `buildheap.ML`,
  `sigobj/`, `src/list/src/.hol/objs/listTheory.uo`).

**Recompilation avoidance and build systems** (D14, D16, M6, M11):
* GHC, `compiler/GHC/Iface/Recomp.hs` and its Notes.
  https://gitlab.haskell.org/ghc/ghc/-/blob/master/compiler/GHC/Iface/Recomp.hs
* rustc dev guide, "Incremental compilation."
  https://rustc-dev-guide.rust-lang.org/queries/incremental-compilation.html
* OCaml manual, "The Dynlink library."
  https://ocaml.org/manual/5.5/api/Dynlink.html
* Mokhov, Mitchell, Peyton Jones. "Build systems à la carte." PACMPL 2
  (ICFP 2018), article 79. doi:10.1145/3236774.
* Mokhov, Mitchell, Peyton Jones. "Build systems à la carte: theory
  and practice." JFP 30, 2020. doi:10.1017/S0956796820000088.
* Dune. "Virtual libraries."
  https://dune.readthedocs.io/en/latest/virtual-libraries.html
* Kilpatrick, Dreyer, Peyton Jones, Marlow. "Backpack: retrofitting
  Haskell with interfaces." POPL 2014. doi:10.1145/2535838.2535884.
* Smackage, a package manager for Standard ML.
  https://github.com/standardml/smackage

**Dynamic loading, linking and hot code** (D17, D18, M9, M12):
* Rossberg. "The missing link: dynamic components for ML." ICFP 2006.
  doi:10.1145/1159803.1159816.
* Cardelli. "Program fragments, linking, and modularization." POPL
  1997. doi:10.1145/263699.263735.
* Glew, Morrisett. "Type-safe linking and modular assembly language."
  POPL 1999. doi:10.1145/292540.292563.
* Hicks, Weirich, Crary. "Safe and flexible dynamic linking of native
  code." Types in Compilation 2000, LNCS 2071, 2001.
  doi:10.1007/3-540-45332-6_6.
* Erlang/OTP system documentation, "Compilation and code loading."
  https://www.erlang.org/doc/system/code_loading.html
* Hicks, Nettles. "Dynamic software updating." TOPLAS 27(6), 2005.
  doi:10.1145/1108970.1108971.

**In this repository:** [jit.md](jit.md), [middle-end.md](middle-end.md),
[codegen.md](codegen.md), [weak-points.md](weak-points.md),
[performance.md](performance.md) and [../performance.md](../performance.md),
[../../tests/basis/xc2/README.md](../../tests/basis/xc2/README.md), [ide.md](ide.md);
[../architecture.md](../architecture.md), [../ir.md](../ir.md),
[../bytecode.md](../bytecode.md), [../runtime.md](../runtime.md),
[../building.md](../building.md), [../language.md](../language.md);
`lib/basis/MANIFEST`, `sources.txt`, `AGENTS.md`; the owner's notes
`~/notes/virtual-machine.md` and `~/notes/rune.md`.

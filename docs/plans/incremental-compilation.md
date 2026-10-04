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
| M1 | Measure | |
| M2 | Units in memory: the basis as a value, the front end resumable, a back end per unit | |
| M3 | Unit bytecode, the static linker, and the VM loads units | |
| M4 | The resident compiler, `use` and the REPL | |
| M5 | HOL4 on Rune | |
| M6 | The cache, with cut-off | |
| M7 | Mid per unit: whole-program builds from the cache | |
| M8 | The dependency graph, and a program from an entry point | |
| M9 | Compiling against a signature alone, and dynamic modules | |
| M10 | The build language and virtual modules | |
| M11 | Parallel and reproducible builds | |
| M12 | Hot reload, the compiler as a service, packages: research and prototypes | |

The owner decides D1 to D19 after reading this (*Decisions*); what
starts first is theirs too. M1 to M7 are one part: at the end of M4
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

**The owner's decisions after reading this roadmap:** none yet. D1 to
D19 are written with a recommendation each (*Decisions*).

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
  (`tests/repl`, `tests/incremental`, `tests/build`); the instruction
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
was written with. The owner decides.

| Decision | Recommended |
|---|---|
| D1. What a unit is | A: a source file; a REPL declaration; functor bodies compiled at each application |
| D2. Incremental or separate compilation | A: IC against the actual bases before it, in explicit order; SC only against a signature, for virtual and dynamic modules |
| D3. Names across units | A: stamps stay `int`, local per unit; canonical renumbering at export, a base added at import and link |
| D4. The compilation basis | A: one record with deltas, holding what every phase needs; spans kept |
| D5. Memory before disk | A: the front end and back end made resumable and per-unit first (M2); serialisation after (M6) |
| D6. What a unit object holds | A: export basis, self-contained Mid, unit bytecode; whole-program builds from the Mid |
| D7. Linking | A: a static linker in the compiler and `rt_load` in the VM, one relocation, cross-checked; `rt_load` returns a closure |
| D8. The Basis and the compiler as units | A: the compiler is the first client of unit builds; the Basis ships as one frozen library |
| D9. The resident compiler | A: in-process, Poly/ML's model; a two-process front end later if wanted |
| D10. Printing at the top level | A: printers generated per declaration from the static type, plus a registry by type name |
| D11. Interrupts | A: a flag set by a handler behind `sys.h`, polled at the JIT's poll points, raised as `Interrupt`, maskable |
| D12. The REPL's semantics | A: Chapter 8: skip a failed declaration, keep effects of one that raised; errors recoverable per declaration |
| D13. HOL4 | A: a port layer in a HOL4 fork; images as heaps; single-threaded shims; the owner may stop before it |
| D14. The cache | A: `.rune/` per source directory by default, relocatable; content-addressed under a configuration hash; cut-off by usages; no timestamps |
| D15. The dependency graph and the file discipline | A: analysis for files with module-only top levels, checked; an explicit list as the escape hatch; nothing restricts `rune` |
| D16. The build language | A: a language of Rune's own with MLB's semantics, groups, virtual modules, packages, annotations; host build files generated from it |
| D17. Compiling against a signature alone | A: an ABI fixed by the signature: slots, tags and layouts in signature order, calls through wrappers, no functors |
| D18. Dynamic modules | A: `structure X = _dynamic "path" : SIG`, checked by interface fingerprint at load; plus an untyped `Dynamic.load` |
| D19. The second part | as recommended: whole-program from the cache, parallel and reproducible builds; reload, service and packages as research with a decision each |

### D1. What a unit is

**Recommended: A**, a source file.

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

**Recommended: A**, incremental by default.

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

**Recommended: A**, integers, local per unit, rebased.

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

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A**, in-process.

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

**Recommended: A.**

* **A. Printers generated per declaration from the static type**, as
  Poly/ML does: the compiler, knowing `val it : int * string list`,
  emits the code that prints one, honouring a print depth, a line
  length and a registry of user printers keyed by type name that the
  generated code consults (`Compiler.addPrettyPrinter`, which HOL4
  calls 39 times). Abstract types print by their name; functions as
  `fn`; exceptions by their constructor. No run-time type information
  is needed, because every value carries its tag and the compiler knows
  every top-level type.
* **B. A type-indexed interpreter over type descriptions** (Elsman
  2026). Needed where representations lose the type -- untagged
  records, unboxed constructors -- and Rune's values are tagged.
* **C. The compiler's `Ty` printer over a reflected value.** The
  VM has no reflection and D5's basis is not the value's type.

### D11. Interrupts

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A**, with the owner's stop before it kept open.

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

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A.**

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

**Recommended: A.**

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

**As recommended**, and planned again after M7:

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

* **What:** a script, `scripts/perf-units.sh`, and a table in this
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
  file; `tests/build`; a `basis.virtual` example swapping `IntInf`'s
  implementation, the brief's own case.
* **Why now:** after the graph (M8) and the ABI (M9) it composes.
* **Done when:** `rune` builds itself, `runedoc`, `runeopt` and the
  Basis from build files; the five builds still identical from the
  generated scripts; `sources*.txt` and MANIFEST deleted; the virtual
  `IntInf` example runs with either implementation.
* **Touches:** the hosts' build files; `docs/building.md`;
  `AGENTS.md` (the rules about `sources.txt` and MANIFEST).

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
| fourth-quadrant.md, *`.mlb` semantics* | M10's build language reads what xc2 would need |
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
* **The build language** (`tests/build`, M10): its grammar's cases, the
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
[fourth-quadrant.md](fourth-quadrant.md), [ide.md](ide.md);
[../architecture.md](../architecture.md), [../ir.md](../ir.md),
[../bytecode.md](../bytecode.md), [../runtime.md](../runtime.md),
[../building.md](../building.md), [../language.md](../language.md);
`lib/basis/MANIFEST`, `sources.txt`, `AGENTS.md`; the owner's notes
`~/notes/virtual-machine.md` and `~/notes/rune.md`.

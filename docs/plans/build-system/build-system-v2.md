# Roadmap: libraries, units, the store and the editor, at the scale of a monorepo

**Rune's build works, on everything it has been asked to build, and it will not scale.**
- **Libraries are not abstract.** One library of 28 has a boundary, and a `use` of a sub-build walks around it. What links is decided by which tokens a program contains, so renaming a bound variable can change its output.
- **MANIFESTs are generated and unchecked.** Six of 15 ways of leaving one stale give a silently wrong answer.
- **An up-to-date build costs 20-53% of a cold one** on real corpora, 39-40% at every size of the fixture, and a small edit costs what no edit costs.
- **The cache has holes,** though small ones: a warm build can differ from a cold one, and three settings are in no key.
- **The editor keeps nothing on disk.** It stops at 40-60k lines of ordinary code, or 1,000 files with a target. It asks which build a file belongs to in 210 cases, of which 4 are real.

**One bug fix should halve rebuilds:** forcing the remap takes E13's replay from 4,048 units to 1,874, and 20% off its instructions. Most of what the editor needs is keeping what it has already computed.

This roadmap plans seven things:
- **The fixes found, and independent checks of the cache** (track F): a statement of what a cache hit must satisfy, and checks that hold the compiler to it.
- **A unit model** (track U): logical names, and an interface in layers, so that the compiler and the editor can share one.
- **One store, and a warm path** (track C): `.rune` and `lib/cache` as layers of one thing. A no-op falls below 5% of today.
- **Libraries as abstract packages** (track L): declared imports, boundaries with their holes closed, clash errors and renaming, friends for tests and the compiler's drivers, Basis views, MANIFEST gone, 21 of 88 build files migrated by a tool and 12 by decision, with no flag day. The win32 work's 27 stay as they are, and are migrated after that work lands (D15).
- **A separately compilable restriction, and functor signatures** (track S): three classes of unit, as a warning, which Rune, MLton and HOL4's library code all fit; and a client compiled against a functor's signature alone, with virtual libraries, by the owner's decision (D22).
- **An editor at scale** (track A): an edit that costs its own unit's elaboration and little else, cold in about a second from a store on ordinary code to 200k lines (11-12 s on MLton until signatures are shared), and a question about the build only where contexts really differ. The evidence stops at 1.17M lines, and M20 runs only planning at 10M.
- **Rune 2's plan,** in [`docs/plans/rune2/separate-compilation.md`](../rune2/separate-compilation.md): what changes once Rune no longer aims to be SML '97.

**It recommends against four things the brief proposes or expects.** The evidence is in D18, D19, D22 and D29:
- **Compiling a library to one unit:** once the warm path is fixed it gains nothing, and costs 1.4 to 3.2 times on a one-file edit.
- **A term language for composing modules, as a compiler feature:** the idea is right at its smallest, and needs no feature. A program can print a `.build`.
- **A firewall:** only 31 of 4,048 rebuilt units are ones a firewall alone could avoid, and it costs at least 2.4 times at run time on `checksum`, the worst of six; layouts behind an opaque type unmeasured, no firewall prototyped.
- **Compiling against a functor's signature now:** the incremental benefit is there already. **The owner decided otherwise:** it is done now (D22, M21, M22).

It also makes a fifth, the restriction, a warning rather than a rule.

**The brief's request for modular libraries is also its most dangerous.** A `rune.build` that uses libraries, done the obvious way, stops the compiler's identity from covering them: a compiler with a real edit then serves another's stale entry. It was observed printing 233 where a cold build prints 234 (E12). D14 prevents this, and it comes before any root moves (M11 before M13).

Writing it found 37 defects on master (Appendix D), among them: alpha-renaming changing a program's output (E3); a program that merely names `Runtime` losing every remap hit, without which E13's replay rebuilds 54% fewer units (E13); warm differing from cold (E18); `install.sh` reporting success with no Basis installed (E28); analysis quadratic in a unit's declarations (E20).

It was written on 2026-11-01 against master `b12141ecc`, and decided on 2026-11-02. It lives in a worktree, on branch `build-system-v2`.

What it rests on:
- **The code:** a reading of the build language, MANIFEST, units, the caches and the language server (*Where we are*).
- **Twenty-eight experiments and a model** (*The experiments*):
  - the census, what MANIFEST costs, boundaries on everywhere, Basis views (E1-E4);
  - the rules as a checker, effects by permutation, the REPL, who fits, HOL4 and MLton through one build file, functor signatures (E5-E10);
  - aggregates, the plan, what a firewall could save, what can go in a unit (E11-E14);
  - the warm path, identity, interface layers, independent checks, codecs (E15-E19);
  - the editor and the batch compiler at scale, contexts, cut-off, storage (E20-E24);
  - the literature, twenty-odd systems, editors and tests against abstraction (E25-E27);
  - migration (E28);
  - an executable model of the cache (L1).
- **Real corpora, for the first time through this path:** HOL4's `src/boss` closure and MLton's 606 files, each from a `.build` and through the language server.
- **Throwaway prototypes,** kept as patches in the drafts: a friend view, a Basis view, a warm path, logical names, layers, a canonical plan, a migrator, an editor that keeps its units.

## Status

Decided, and being implemented on this branch. The owner took every recommendation, D1 to D29, on 2026-11-02, with two changes: D22 is done now, with an example program under `examples/virtual` as its first client, and D26 adds two language status items to the VS Code extension (*Decisions*). The win32 work is out of this roadmap, and is migrated later (D15). *The implementation so far* says what has landed.

| Milestone | Track | Size | Rests on | Status |
|---|---|---|---|---|
| M1. The fixes found, and guards | F | M | | done |
| M2. Independent checks of the cache | F | M | D20 | done; issue 15 closes with M4 |
| M3. Logical names and the workspace | U | L | D3, D4 | done |
| M4. Layers | U | L | D1 | done, but for two items: MLton's 4 units and the replay |
| M5. Codecs | F | L | D21 | not started |
| M6. The warm path | C | L | D2, D25 | not started |
| M7. One store | C | M | D24 | not started |
| M8. The library model | L | M | D7, D8, D11 | done |
| M9. One planner, and the plan | L | M | D5, D6 | done |
| M10. Namespaces and Basis views | L | M | D9, D12 | done |
| M11. Hosts' lists and the compiler's identity | L | S | D14 | done |
| M12. MANIFEST's end | L | L | D13 | not started |
| M13. Migration | L | M | D15 | not started |
| M14. Reaching in, runedoc | L | M | D10 | not started |
| M15. Generated sources and preprocessors | L | M | D16 | done |
| M16. The restriction | S | M | D17 | done |
| M17. Keeping what is computed | A | L | D27 | done; MLton's oracle moved to M18 |
| M18. Sidecars and the shared layer | A | L | D1, D27 | not started |
| M19. Contexts, and the end of the prompt | A | L | D26 | done |
| M20. The target, in CI | A | M | D28 | not started |
| M21. Functor signatures | S | L | D22 | done |
| M22. Virtual libraries | S | M | D22 | not started |
| M23. Retire | | S | | not started |

Gate G1 (aggregates) closed with D19. Gate G2 (the term layer) stays, with no milestone behind it: *Gates*.

### The implementation so far

`make check` on `6fce5270d`, this branch before the first milestone: 22,025 of 22,025, 3 of them skipped, 63 minutes at `JOBS=8`. Each line below is checked the same way on its exact commit.

- **M1's three editor items, and M19's two status items** (`defba4d61`, `make check` 22,025 of 22,025).
  - `Env.plus` is linear, a token key is compared without structural `=`, and the settings index is scoped, so `configurationFor` is no longer quadratic. `tests/lsp/project-replay.sml` is fixed, and is the target `test-lsp-replay`. The project replay's cost fell from 73.35G to 33.93G instructions, and `enrich` at 1,000 files from 13.07G to 0.041G.
  - `rune/status`, `rune/context` and `rune/setContext` go only to a client that asks under `experimental`. The extension has both items, `runelsp.chooseContext` and `runelsp.showOutput`. The editor suite ran on 1.106.0 in bubblewrap. Neither a VSIX nor Windows was exercised.
  - Two narrowings of D26: status is sampled every 250 ms, so shorter work may not show busy, and `docs/language-server.md` says so; a query's own failure does not set Error severity, only a worker's.
  - Found: `vscode-languageclient` 10.1.2 stops pulling a document after a cancellation with `retriggerRequest: false`, so the extension carries middleware (`editors/vscode/src/status.js:45`). Document symbols are quadratic, which is in M17's free fixes.
- **M1, the rest** (`e94330df8`, with the line above merged, `make check` 22,196 of 22,196).
  - All 16 items are in, each bug with its reproducer: S83 to S90, 22 `buildfile` scenarios, 3 `tests/lang` files, `tests/repl/functors`.
  - **A program loads units** if a unit's code names `Runtime.load`, `link`, `linkedUnits` or `linkedUnitSources`, or it holds `lib/basis/dynamic.sml`. Tokens catch the direct names, and each unit is judged by the keys its code names, which catches aliases, `open` and functors' arguments. A program found to load only after a unit was taken across a change compiles again, in a fresh `CompilerState` session (`src/driver/main.sml`, `compiledAgain`). A warning of the first compile then prints twice on stderr.
  - **S41 on program bytes** holds on HOL4's closure (293 units taken across a change, 13.3 MB) and MLton (195, 13.0 MB). Random edits: 477 builds, no disagreement.
  - **E13's replay** gives 1,978 rebuilds, not 1,874: MLton 678 against 684, HOL4 852 against 852, `lint31` 243 against 187 and `fu31` 205 against 151, none refused. E13's 187 and 151 had a frozen layer, whose first step compiled 69 and 58 of 235 units; with `--type-work` in the key, as M1 requires, that layer no longer applies to the replay. The base under the same conditions gives 609 and 427. Instructions on those two chains fall 22.2% and 17.4%. The 3,270G total is not comparable with 4,373G and 3,506G.
  - **Selection's parse:** hello +0.88%, warm hello in units +1.01%, a `rune.build` no-op unmeasurable, since a file whose tokens cannot add a name is not parsed; parsing all of them cost +9.2%. `compile-share` and `compile-sharenest` re-based for bytes, +4.5% and +5.9%.
  - **Reach-in warnings:** the 12 hand-written builds. The 5 generated pointers are exempted: nobody wrote them, and their generator goes with the win32 work's migration.
  - **Departures:** D8's replay rule is narrower, and D8 says how and why. D6's export rule is D6's, "nothing of that name is in scope"; `--basis-index` keeps its stricter one, which M9 must settle.
  - **Left:** selection by uses is batch only, which M9 takes. A program calling `_prim "rt_link"` directly and linked from `.rbu` files gets no units section; `--units` handles it. `--type-work` drops the frozen Basis for that compile. A `rune.build` no-op measured 10.39G with a matching frozen layer against 9.75G without, on one compiler, cause unknown: M6 and M7 should look.
- **M3** (`fbad51683`, `make check` 22,211 of 22,211).
  - A unit is named `LIBRARY:PATH` under the deepest `library.build`, and a library by its place under `--lib` or a workspace's roots. `:` and `@` in a library's name become `_`, which leaves room for a version, `LIBRARY@1.2:PATH`. A second unit of one name is `NAME#2`, in build order, and the rank is in the key, the identity and the anchors. The root file is `rune.workspace`, found upward from a file (`lib/compiler/driver/workspace.sml`). `RuneCompiler.Workspace` is new, `Project.read` takes one, and analysis names units as batch does, so `file#rank` is gone. `Config.identity` does not depend on the root.
  - E16's table: `worker.build` spelt `../../` compiles 1 unit, not 16; `rune.build` spelt `./` none, not 105; a moved library none, not 24. `same-file-twice` prints `0 10` whole, in units, cached and warm. Random edits: 430 builds, no disagreement. The stack bootstrap's budget re-based, +0.48%.
  - **Choices the roadmap left open:** a loose file is named from the directory of the first file on the command line; a build's file outside any library from the root, with no prefix; a file reached by `../` past the root by that path, `../out/a.sml`; the REPL's `use` by the path from where the session began, and its place. So "a program's units are named from the root" holds for builds, not loose files: `rune --units src/a.sml` and a build naming `src/a.sml` miss each other, never mislead.
  - **D4 refined:** the nearest root file, not dune's topmost, so that a worktree or a fixture under another root has its own.
  - **Left:** no flag selects a named target, and only the editor reads targets. `Project.buildLinks`, path completion, runedoc and the API's text compile do not see a workspace's roots. An unsaved `rune.workspace` is not read. A library under `--lib` wins over one in a root.
- **M8, with M2** (`3f0a7a84b`, M2, M3 and M8 together, `make check` 22,308 of 22,308).
  - **M8:** a library's header, at the top of `library.build`: `requires ... end`, `exports (kind NAME, ...)`, `friends PATH ... end`, `view NAME (...)`. A header in a program's build, or in a `use`d build, is refused. A library with a header is elaborated in the Basis and what it requires; a library with none keeps today's meaning, and with none in a program's closure the code path is today's. All six sites and `--basis-check` take one walk (`LibraryScope`), which M9 finishes. Friends hold in batch, in the cache and in analysis. The 3 additions, 1 removal and 3 program edges are in, and `lib/compiler`'s boundary is in a header. E3's 159 programs give the same bytes, whole and in units. Random edits: 280, no disagreement. The bootstrap rose 1.28%, and both budgets re-based.
  - **The no-header warning** is shown by `--basis-index`, once per library, and never in a client's compile: a client cannot act on it, and 31 libraries have none until the win32 work's migration.
  - **Syntax the roadmap left open:** a view is `lib#view`, since `:` is M3's; `fixity NAME` is a fifth kind of export, so a private infix stays private, and its directive is in an `always` file.
  - **No hash per filter was built,** and D8 says why.
  - **Until M10,** the `RuneCompiler` clash warns on every compile that imports `compiler`.
  - **M2:** `--verify-cache` compares an entry taken across a change: on MLton's S47 edit, 130 of 216 compared and all the same, 86 not loadable, as E18 found. A flags oracle, fact edits, root blanking from the `CompilerState` roots (31 of 339 roots matter), random edits as a tier (`make test-cache-random`) and E18's mutants (`make test-cache-mutants`): 47 mutants, 45 caught, 2 argued harmless (F1, F6), none a hole. Of the 13 survivors, 11 are killed by ordinary tests, so Appendix F's reading of U4, C3 and F5 was too pessimistic. `make check` grows by about 46 s at 8 jobs. Its scenarios are S98 to S101.
  - **Found:** E3's `make052` dies in `--units` with an internal error, `record selector did not resolve to a record type`, on master too. Whole-program mode accepts a flexible record that a later file settles, though `docs/units.md` says a file's end settles it; three lines reproduce it. So D17's "in default modes nothing crosses a unit's end" is not so. M16 fixes it.
- **M9** (`572e888be`, `make check` 22,314 of 22,314).
  - **One reader:** `CompilerProject.plan` reads every build file, and the command line is a plan too (`ofFiles`); `-I` with `--build` is refused. **One site:** a library is loaded and its boundary applied in `LibraryScope.group` alone.
  - **The plan's text,** `CompilerPlan` (`lib/compiler/driver/plan.sml`), and `rune --plan FILE.build|FILE.plan`: `requires` on the program and each library, `inline` and `inline val`, `replay`, and the inputs' provenance (`input PATH SHA256`) outside the body. `caches` is gone. `edge` and `scc` are reserved, and version 1 refuses them. `--build-list` is the plan flattened. Plans: `rune.build` 8,508 bytes and 115 units, MLton 122,691 and 606, HOL4 60,418 and 746. All 88 tracked builds round-trip, and MLton's and HOL4's reprint byte-equal.
  - **What went:** `group`, `local` and `cache` are errors that say what to write instead; a `library` block stands only in a `library.build`, around all its files. `basisIndex` is gone: the index is `LibraryIndex`, beside `Deps` and `CompilerProject`, where runedoc reaches it. `tools/generate` takes the Basis's files from the plan.
  - **Selection by uses everywhere:** a session, a query and an analysis select as batch does (`lib/compiler/driver/prelude.sml`).
  - **D6's rule,** settled: an export names what a source of the library declares. A header may not re-export a Basis name, nor one from a library it requires; a source passes one on by declaring it, `structure List = List`. `--basis-index` and the compile apply the one rule in the same words.
  - **MLton's translated build:** its 29 blocks and one `local` become 30 nested libraries with headers, and it still builds, on a private copy.
  - **Left:** the hosts' awk (`scripts/build-files.sh`) still reads build text, and goes with M11. `--basis` and `--no-prelude` are printed in the plan but read from the options: M10. A plan made outside the top of a checkout spells its way there. `use DIR/library.build` warns that it reaches in. The bootstrap rose 2.05% on the register VM and 3.1% on the stack VM, and both budgets re-based.
- **M4, M10, M11, M16 and M17** (`ee96ae951`, together, `make check` 22,420 of 22,420). The first run failed one test: M16 had moved the text compiler mutant E08 patches; E08 was brought up to it and is still caught. Each was checked on its own first, then merged with the others: M17's engine and M8's scopes by an agent of its own, with two guards and their tests; M10 and M16's header by hand.
  - **M4, layers:** format v15 to v23. Spans and origins in a sidecar no hash reads; hash-only fields out of the pickle, with export of load as a check; imports hashed by what they are, so an entry whose imports are the same is an exact hit; the fix in `typed`; a static and an ABI layer, one writer of the static, a hash per export, a constructor's flat size; reference stamps as runs and back references; `make test-layers`. Issue 15 closed, with M2's comparison. Random edits after every step: no disagreement.
    - **Not met:** analysis and batch agree on every export's static hash, MLton's 14,215 and HOL4's 28,242, and on HOL4's 910 units' static bytes, but 4 of MLton's 764 units differ in bytes (`allocate-registers.fun` and `generate-transfers.fun`, amd64 and x86: a type written in full on one side and by back reference on the other), so the tier runs on `rune.build` alone. E13's replay fell by 8, not up to 814: step 7 was dropped, and the datatype and signature edits change the static layer itself.
    - **Step 7 dropped:** an ABI layer of layouts let a client be taken across `int` becoming `word` behind `:>`, which the cached link then refused and the cold build did not. `docs/units.md` says why the realisation stays whole. **Step 8** cut MLton's ABI layer by 1.7%: its stamps repeat across units, which a unit's format cannot share.
    - **Mutant U3** (the usage `fun` not recorded) is harmless now: a caller of a changed functor's unit names a function no path reaches and is compiled. The lead built the mutant and probed five functor edits, warm against cold: all agree.
    - Costs: MLton cold +2.2%, hello in units +1.7%, no-ops within 0.5%; caches 0.3-2.8% smaller.
  - **The heap replay's rule:** `heap/replay/compile-sigs` failed after M4 by 2,184 bytes of 30.6M. The rule held the stock VM's copied total between two simulator runs' totals, which collect on schedules of their own and are no bound. Each of the stock's collections is now held to the simulator's band at its own clock: all 8 lie in it, and of 12 perturbed workloads the old rule failed all 12 while all 96 collections lay in their bands. `heapsim --probe` no longer drops clocks past 64.
  - **M10, namespaces and Basis views:** a rename at import, `NAME (KIND OLD as NEW, ...)`, in `libraries`, `requires` and `--library`; a clash is an error where a header or a rename is on one side, and two libraries with no header still shadow as today (D15). `RuneCompiler` is settled by `shadows (structure RuneCompiler)` in `lib/compiler`'s header, and D9 says why. A program with both `History`s compiles, with a rename, in a test. Basis views: a seal in the Basis's build with `view=NAME`, `view NAME` in a build and `--basis-view`, loaded after the libraries, in the program's scope alone; the Basis ships none yet, so a fixture tests them, with S41, S42, S58 and `--verify-cache`. The plan carries `--basis`, `--no-prelude` and the view, and the compile reads them from it. **Left:** the editor ignores a Basis view, which M19 takes.
  - **M11, hosts' lists and identity:** five plans committed beside their roots (`rune.plan` and four more), read by `scripts/plan-files.sh`; the awk is gone. `Config.identity` is a hash of a root's plan text and its whole closure, less the two config files, and every make refuses a stale plan. E12 now fails to go wrong: compiler B takes none of A's entries and prints 234, where the old scripts took them and printed 233. A toy second compiler has its own identity, and shares `rune`'s, wrongly, when it links `build/config.sml`, which is rhc's hole shown in Rune's tree: a second compiler gets its own identity only by linking its own Config first, not through `libraries compiler`. Each make costs about 10 ms more. After an edit of a root's build, `make plans`.
  - **M16, the restriction:** shared, entry and prelude units; the four rules as a warning, shown by `rune --deps` and the index, not by a plain build; `strict` in a header, which `--basis-index` enforces; `annotate "prelude"`; a prelude's fixity reaches `rune --deps` and selection; `rune --deps --build FILE`; `host=only`; the REPL takes `--flex-records` and `--or-patterns`, and `docs/repl.md` says where a session and a program differ. E8's table is a test: Rune's 1,007 units across 39 builds, MLton's 606 (from M9's translation) and HOL4's 744 with two declared preludes, all well-formed. **The flexible-record bug** was wider than found: two selectors' records unified into a variable nobody noted, so even one file died with an internal error; both modes now refuse it, and D17 is corrected.
  - **M17, keeping what is computed:** the free fixes, document symbols indexed, units kept between checks in a state of their own, a changed unit elaborated at its place, a walk by usages past a moved identity, closed units, origins by reference on M4's sidecar, a plan memo. A leaf comment's p95: `rune.build` 0.045 s, HOL4's closure 0.152 s, the 351k fixture 0.223 s, at 512 MiB, against 1.00 s and 9.3 s before. `make test-lsp-oracle` compares kept and fresh analysis after every edit: no disagreement on `rune.build`, a 117k fixture or HOL4. Cancellation mid-walk is tested.
    - **Moved to M18:** the oracle on MLton. Its checks agree, but the kept world is 12.75 GiB and a walk past a moved identity overruns the 15 GiB heap; M18's 2 KB a line is what makes it fit.
    - **Found:** usages alone cannot keep an open unit past a moved identity, since its facts print types by the paths that reach them there; such units are elaborated again. Types of one name are told apart by order, not a session's stamp.
- **M15, M19 and M21** (`dda604310`, together, `make check` 22,644 of 22,644). Their first run together failed 8 tests, each fixed at its cause: M19's shared library units were a table outliving the compiler's sessions, which the state audit refuses, and are now a pool the sharing contexts are handed; M21's exported functor gave a native symbol a space, `functor F`, which `nm` split, and a symbol now has none; the heap replay failed again, and its census now collects where the stock VM did (`--census-at`), since what is alive depends on where collections fell, so every number of the replay must equal the stock's; a budget and the generated docs.
  - **M15, generated sources and preprocessors:** `generate TOOL (ARGS) inputs ... end outputs ... end` and `preprocessor NAME TOOL (ARGS) inputs ... end`, with `annotate "preprocess=NAME"` for a file's class, run before a compile reads a source; a step is keyed by its tool's bytes, its arguments and its inputs, its outputs verified, and a hand-edited output refused while its key holds; a preprocessor's output is what a unit's key holds. A plan with either is `rune-plan 2`. `runeffi rehash` publishes a set under the hash its files make, on copies; no set under `ffi/` changed. HOL4's `src/boss` closure builds from its unfiltered sources with HOL's own `unquote` as a declared filter, the same 13,301,844 bytes as the filtered tree, and S41 holds across edits inside and outside quotations. `rune.build` and `runedoc.build` begin with the step that writes `build/config.sml`.
    - **That step cannot be keyed:** `scripts/gen-version.sh` reads git and every file of the closure, so it declares no inputs and runs on every build, 0.11-0.13 s. M6 must key it or name it. The editor and the API do not preprocess yet.
  - **M19, contexts:** a file in a library is checked in that library; candidate contexts are compared by binder, by each occurrence's definition and declaration, and a prompt appears only where they differ; a file in no build gets an implicit library beside it, its names looked up in its directory first and then the workspace; sweeps cover every file; a unit with errors reports each and answers past them; analysis contexts share a library's units; a Basis view reaches analysis; a root file above the editor's folder, or unsaved, is read. E22: prompts 124 to 1, the one a real difference of 32 against 64 bits; sweeps 153 to 220 of 220 files. E24's sample: clean files 251 to 517 of 726. A second build over `runelsp`'s library takes 254 of 257 units from the first, 2.2 s against 5.6 s. The editor suite on 1.106.0 passes A1's checks.
    - **Narrowed:** past the first error means within a unit; the walk stops after it. Comparing a file's candidates costs a check each on first discovery, up to 18 s for 5, and the verdict lasts as long as the plan memo. Workspace symbols wait for M18's sidecars. **Found:** analysis of `tests/units/flex/a.sml` raises `Failed` where it should report a diagnostic.
  - **M21, functor signatures:** `functor F = _virtual (X : A) : B`, `functor F = _dynamic "path" (X : A) : B` and `_export functor` in both parsers; an application is a call over nested records, typed by the signatures alone; `implements` takes a functor; the fingerprint holds version, calling convention, slots, descriptors and both signatures, and each field has a mutant refused at link or load. `examples/virtual/table` builds on an association list and on an AVL tree, with a `_dynamic` variant as a plugin; a body edit compiles only the implementation, a signature edit every unit that names it; the fingerprint is the same on every host, `7f5c2512d451806272a969fec81ef7a6`.
    - **`Pickle.hash` on `smlnj32`:** the difference was two SML/NJ 110.99.9 bugs, not word width. `lib/compiler/util/pickle.sml` now reads its Word64 constants from hex and never shifts by 0, beside its existing adaptation to MLRISC, so every host gives one hash and check-cross compares smlnj32 in units too. This is a host's bug answered in the compiler's sources, which `tests/cross/deviations.txt` says is not done; D22 asked for one fingerprint on the five hosts, and the owner may rule otherwise.
    - **Found:** an `_export structure` whose signature had `datatype d = D of u`, with `u` abstract and a tuple, compiled and then stopped the client's VM; such an export is now refused at compile time.

## Found while writing this roadmap

Every bug has a reproducer: Appendix D lists them all. The ones marked *reproduced* were run again by hand on `b12141ecc`.

**Wrong behaviour in the compiler**
- **Alpha-renaming changes a program's output,** because selection is by mention (E3, D7; *reproduced*).
- **A warm build differs from a cold one.** A compile reads another unit's text for a copied function's line table, and no key holds it. A same-size edit keeps the stale line, and a trace names it (E18; *reproduced*).
- **Three settings are in no key:** `--functor-budget`, `--type-work` and `--match-work`. A cache gives a hit where a miss is due; `--type-work=1` exits 0 warm and 1 cold (E18; the first *reproduced*).
- **A file given twice:** whole prints `0 10`, `--units` prints `10 10`. This is issue 22 in batch, and issue 23's "a batch build never has two units of one name" is wrong (E16).
- **`rune-repl` fails with an internal error** on `functor F (X : S) = X and G (Y : S) = Y`, which `rune` compiles (E7; *reproduced*).
- **`--typecheck-only` refuses what compiles,** in two ways: with a build, it loses a library's exported signatures and functors (E3, E9; *reproduced*), which made 630 false errors on MLton; and on open constructors (E17).

**Costs that were bugs**
- **`loadsUnits` fires on a mention:** a program that names `Runtime`, or declares its own, loses every remap hit (E13, D7; *reproduced*).
- **Analysis is quadratic in a unit's declarations:** `Env.plus`. A six-line fix takes `rune.build`'s check from 11.6 to 6.6 s (E20).
- **Membership is quadratic** through `configurationFor`, and `discover` runs `enrich` before every check (E20, E23).
- **A large declaration kills the worker:** the VM aborts on equality work, between 14,000 and 28,000 lines (E20).
- **`-j` makes a build slower on small units,** and a no-op slower everywhere: it parses every input (E15, E21).
- **A stale entry slows every later build:** MLton's warm path went from 83.9G to 116.2G, +38%, after about 15 edits: one observation, cause not isolated (E13).

**Tools**
- **`scripts/install.sh` with no MANIFEST reports success** and leaves no Basis (E28, D13).
- **`--build-list` omits the closure:** 23 files against 157 (E12).
- **`--basis-index` does not notice a name hidden by a dependency's boundary** (E28).
- **A relative path variable serves one directory** (E12).

**What published numbers say that is no longer so**
- MLton's no-op is 88.89G at tier 2, not 105.0G; 60.2G was a compiler built by MLton (E15).
- `rune.build` in the LSP holds 455-465 MB, not 271 MB, in a 512 MiB heap (E20).
- S47's 236 units are 20 that must compile and 216 that hold across the change, refused by `loadsUnits` (E18).
- `docs/build.md`: "Its semantics is MLB's", but `use` elaborates in the caller's basis, where an `.mlb` starts empty. `mlyacc-lib` saw MLton's `List` (E9).
- D17 of incremental's "no functor in a virtual signature" has been stale since functors-units (E10).
- Issue 11 is stale: code reads and writes back the same bytes, 246 of 246 (E19).
- `tests/lsp/project-replay.sml:61` fails on master (E20).

**What the Definition once had.** The 1990 Definition offered a separately compilable subset, §3.6 *Closure Restrictions*, and functor specifications as "essential". The 1997 revision removed both. A comment in its source says "implementors never exploited them" (*What the Definition says*).

HOL4's closure and MLton build, link and run from `.build`, with no unit refused: 21 s and 40 MB for HOL4 (E9). Unit bytes did not depend on legal order, on the 2-3 orders tried, once names are unique (E6). Boundaries on 31 libraries change no byte in 159 programs (E3). Generated sets need a rehash of 0.08 s, not a regeneration of 269.5G instructions (E28).

## The request

The owner's brief, as written. It is `docs/plans/build-system/build-system-v2.md` on master, which this roadmap replaces on its branch:

> - this is a draft roadmap for an improved build system in rune
> - please note this is about building sml code via .build files. bootstrapping the rune compuler itself via the Makefile is out of scope (other than the .build file used to build rune via rune)
> - the .build files are nice but there are some shortcomings we want to address
>   - we somehow still have a dependency on MANIFEST files that need to be generated. the .build files should be all we need
>   - we have library.build files for each library but most applications seem to still import the individual .sml files from libraries directly. this is not modular. ideally a library form a nice abstract package that an application includes/imports as a whole (or in a way that is controlled by the library specification if in part)
>   - probably need to go over all the .build files and make them consistent and nice. there is a mish mash of direct file includes, library keywords and 'use' command to import libraries. the build language should have one way of doing things ideally. maybe also throw a warning when tring to directly include a file that is under a library.build? i guess we can't outright forbid including a .sml files that is in a folder managed by a library.build becase of test?
>     - libraries should be more than a collection of .sml files under the same folder. they should offer something like the abstraction and encapsulation that a structures/signature has. i.e. a program is not supposed to reach into the internals of the library.
>       - additionally we can use libraries for hierachical unit compilation. we could have a --units --whole equivalents that compiles the units that make up a library into one big unit (i.e. still an open program unlike regular --whole). that would allow for additional optimizations over the library compiler into smaller units and speed up incremental compilation of programs using libraries (compiling against one big library unit expected to be faster than all the units that make up the library).
>     - perhaps we need different rules for code under src and lib directory. code under lib is libraries and most go via the library interface from outside? perhaps that also helps runedoc with knowing what docs to generate.
>       - i would like to retain some level of nested structure under lib. e.g. testing libraries go under lib/test not lib directly
>       - i also wonder about namespace management. how do we prevent different libraries from clashing? e.g. like we have with the COMPILER signature in basis and lib/compiler.
>     - finaly it would be nice to have different versions of the basis library that build can choose. i think smlnj does something similar e.g. BASIS_2024 signature. it would be the same basis codebases just some additional functions unhidden in the signature.
>     - tests are the bane of any module system as tests often need to break open the abstration a module system is trying to provide. we should deal with that as well eventually. how to other languages and build systems deal with that?
>   - i have the idea of using the sml term level language to compose modules. when used in the build system this should still keep strict phase separatation. an ideation of the design can be found in docs/plans/build-system/ideation.md. review and analyze it throroughly and critically. it is ideation only not a settled design.
>     - docs/plans/build-system/ideation1.md
>     - docs/plans/build-system/ideation2.md
>     - docs/plans/build-system/ideation3.md
>       - higher-order modules and applicative functors will likely be a separate future roadmap (unless you think you need them now). but there is some discussion on build system related things here as well
> - second thinkg to address is separate compilation
>   - i think we are in a much better place after completing the functors-units.md roadmap.
>     - units and pickling are still a complex and fragile part of the codes (see e.g. build-cache-issues.md). we are dependent on tests for correctness. is it possible to put this on a firmer / more formal footing?
>   - sml 97 was designed as an interactive / repl based languages and not everything meshes well with separate compilation. to scale to extremely large codebases and systems we need state-of-the-art support for seprate compilation
>   - do research on the sml separate compilation literature
>   - as we have a repl now i think we can leave the interactive part of the sml 97 definition and required software to be build via the build system to be in the separately compilable restriction / subset. verify this by checking we can keep supporting sml 97 definition via the repl and that e.g. rune, hol4 and mlton as would be build via the build system are in the separtely compileable subset / restriction
>   - as an additional artifact produce docs/plans/rune2/separate-compilation.md
>     - this will be a roadmap for rune 2.0 - an evolution of rune in which we no longer aim to be standard ml '97. instead we'll become an new optimal programming language. this plan describes how modules, the build system, separate compilation, and units look should look like
>     - e.g. separate compilation units should have minimal/no dependence on other units other than what the units declare what they expect
>     - we may want to rethink our sequence of intermediate languages so we have one ir that can go into separate compilation units and is optimal from that point of view (e.g. allows the optization passes application to open programs before being written to the unit file, is efficiently combinable/linkable with the other units during incremantal compilation). we still want to support very fast incremental compilations and optimal code generation during whole program compilation. but ideally we have the in-between as well: well-optimized code during fast incremental compiles and the option to generate code close or identical to a whole program compile from units (while still being cheaper than a whole program compile)
>     - we clear how we would differ from sml 97 (if anything) and what we would keep the same
> - a closely related item is the language server we have now
>   - it currently meets is functional and non-functional requirments but i think it will not scale to a very large code base (10,000,000+ lines, 100,000+ .sml files, 1000 .build files)
>   - it currently treats each .build file as a completely separate entity. work needs to be shared rather than duplicated as this will not scale beyond a dozen .build files
>   - leverage the fact that sml in the rune repo is in the separately compilable subset. ideally we keep loose .sml files / files intended for the repl working as well but i'm willing to compromise on this
>   - i think the lsp may be doing some in-memory caching. really it should be leveraging an on-disk cache for analysis etc. as we cannot recheck 100,000+ files on each lsp reload. ideally this is a cache shared with the compiler itself. i.e. the lsp uses the results from the separate compilation. and conversely the lsp may precompile some .sml files as we edit. so a later unit-based application compile already has work done
>   - probably we will have to introduce library-level / global-level caching/aggregation/database as well to make the lsp scale but we can do that in a future roadmap. let's first focus on making the indivudal file case fast by avoiding parsing/analysis.
>   - i don't like the lsp currently asks under which build files it needs to analyze an sml files. in a properly modular language i would expect this not to matter?
> - i don't fully understand the difference between stuff stored in .rune folders and the files under rune/lib/cache. investigate, explain, propose more coherent ways of doing this
> - please do thorough research on build systems and library/namespace management, both in the literature and exisiting implementations (some available under /home/ruud/reference)
>   - ocaml's dune seems especially relevant to me
>   - haskell's backpack is interesting though i believe in the end it was never able to be implemented due to haskell's type classes being anti-modular
>   - also look more widely at e.g. sml's smackage, haskell's cabal, rust's crate, etc. we are not looking to create a full package manager here though. just libraries within a single extremely large code base / monorepo. package manager will be a future roadmap that can build on top of the foundations creted here.
>   - https://github.com/HOL-Theorem-Prover/holbuild
>
> # compiling against a functor's signature alone
> - (added by claude, 2026-10-26, from the functors-units roadmap's *Later*; SMLSC calls these functor specifications)
> - what: a client compiled against `functor F (X : S) : T` before F's body exists, F's function supplied later: at link time (a "virtual" functor whose implementation the .build file chooses) or at load time (a `_dynamic` functor, a plugin)
> - structures have this already (incremental-compilation.md, M9): `structure X = _virtual : SIG` bound in the build language, and `structure X = _dynamic "path" : SIG` loaded at run time, each with an ABI fingerprint checked at link or load
> - what functors-units (M7) already provides
>   - a functor is a function over fixed nested records (D3), so its run-time interface follows from its signature
>   - every application is typed by the functor's summary alone (M3, M7): a client never needs the body to type-check
>   - dynamic modules use the same nested records (8188270fd)
>   - the incremental benefit is there already: a client depends only on F's signature, so an edit of F's body recompiles nothing else (S8, S65, S66; MLton's S48: 1 unit instead of 6)
> - what this would add: compiling clients before F exists, choosing F's implementation per build, functors as plugins
> - what is missing
>   - syntax and semantics for a functor's signature without a body: SML '97 has none (SML/NJ has `funsig FS (X : S) = T`, SMLSC functor specifications in signatures), so a language extension with its sml97-extensions.md entry and docs/language.md rows
>   - an ABI fingerprint for a functor: its parameter's and result's signatures, and the descriptors the caller works out for its argument's datatypes (D4)
>   - binding: an import slot resolved at link (the .build file) or at load (`_dynamic`), a mismatch an error
>   - tests and docs, the fingerprint stable across the five host builds
>   - a few hundred lines, like the structure half of the incremental M9
> - pros of doing it now: the machinery is fresh and mostly there; it completes SMLSC-style separate compilation for functors; per-build implementation choice and functor plugins

**The owner's answers while this was written (2026-11-01):**
- **The plan:** approved as proposed, with the defaults of the last two campaigns: on a new branch `build-system-v2`, in `.worktrees/build-system-v2`, committed as M0 and not pushed; a hybrid of measurements and throwaway prototypes; the form of `docs/plans/correctness/linting.md`; heavy runs under the usual rules; cut only what is fluff.
- **HOL4:** "rune-enabled hol is now under rune/corpus/hol4/HOL". Nothing was built in that tree. Experiments used a clone at `65ab0d8e6` with `docs/plans/hol4-overloading-declaration.patch` applied, since the seven annotations are not on `rune-build`.

**The decisions (2026-11-02):** "i take all decisions as recommended with one exception (D22) and one expanded request (D26)".
- **D22:** "we do now not later - the first client is an example program under examples/virtual".
- **D26:** "please also use LanguageStatusItem in the vs code extension for the lsp to add two items to the { } menu: one to show the progress of the lsp and a second to show the context a file is checked in and allow users to rechoose the context for the few files that have multiple contexts (the current popup only shows once)".
- **The win32 work:** "another agent is still woring on win32-desktop so we cannot touch it as part of this roadmap (has to be done later)" (D15).
- **rhc:** the recommendations taken include those made the same day for the Haskell 98 roadmap: a clause on each of D5, D6, D8, D14, D24 and D25, imports by name out of M3, and rhc's `mid.build` as a view (*Relation to the other plans*).

| The brief asks | Answered in |
|---|---|
| a roadmap for building SML code via `.build` files; the Makefile bootstrap out of scope, except the `.build` that builds rune | this document; D14 says where that line cannot hold, W4 |
| no dependency on generated MANIFESTs: `.build` is all we need | D13, E2, E28; M12 |
| libraries as abstract packages, imported as a whole or as the library specifies | D7, D8; E3; M8 |
| most applications import libraries' `.sml` files directly | E1 (12 hand-written builds); W4 says why; M13 |
| go over all `.build` files, consistent and nice; one way of doing things | D6, D15; E1, E28; M9, M13 |
| a warning on including a file under a `library.build`; can't forbid because of tests | D10, D11; M1, M14 |
| abstraction and encapsulation like a structure's; a program does not reach in | D8: a library hides names, not representation; E3; M8, M14 |
| hierarchical unit compilation: a library as one big open unit | D19, E11: **recommended against** |
| different rules for `src` and `lib`; helps runedoc | D10; E28; M14 |
| nested structure under `lib` | D10 |
| namespace management; the `COMPILER` clash | D9, E1; W1; M10 |
| different versions of the Basis, `BASIS_2024` | D12, E4; W2; M10 |
| tests must break abstraction; how do others deal with it | D11; E3, E27; *What the implementations do*; M8, M13 |
| composing modules in the SML term language, strict phase separation; review ideation1-3 thoroughly and critically | *The ideation, reviewed*; D5, D29; E12; Gate G2 |
| higher-order modules and applicative functors, unless needed now | D23: not now |
| units and pickling on a firmer, more formal footing | *What a cache hit must satisfy*; D20, D21; L1, E18, E19; M2, M5 |
| state-of-the-art separate compilation at extreme scale | E21; D1, D2, D25; M4, M6; cold at 10M: not answered (*Later*) |
| research the SML separate compilation literature | *What the literature says* (E25) |
| the REPL keeps the Definition; required software lies in the separately compilable subset | D17; *What the Definition says*; E5-E8; M16 |
| verify Rune, HOL4 and MLton fit, as built via the build system | E8, E9: they fit, with W6's qualification |
| `docs/plans/rune2/separate-compilation.md` | that document, written last; E14 |
| minimal or no dependence on other units beyond what a unit declares | D1, D3 here; Rune 2's document |
| one IR for units, with fast incremental, well-optimised incremental and near-whole | E14; Rune 2's document |
| clear on how Rune 2 differs from SML '97 | Rune 2's document |
| the language server at 10M+ lines, 100k+ files, 1000 builds | D26-D28; E20-E24; M17-M20 |
| work shared, not duplicated per `.build` | D26, D27; E22, E23; M17, M19: sharing between contexts is not measured yet |
| leverage the separately compilable subset; loose files may be compromised | D17, D26: a name-to-file index read from syntax, untested; E22, E24; M16, M19 |
| an on-disk cache shared with the compiler; the LSP precompiling for a later compile | D1, D27; E17, E24; M18 |
| library or global aggregation in a later roadmap | *Later*, for analysis results; a name-to-file index is M19 |
| not asking which build file | D26; E22; M19 |
| `.rune` against `lib/cache`: investigate, explain, propose | *`.rune` and `lib/cache`, explained*; D24; M7 |
| research on build systems, namespaces; `~/reference`; dune, Backpack, smackage, cabal, cargo, holbuild | *What the literature says*; *What the implementations do* (E25-E27); W3 |
| not a package manager, but foundations for one | D3 (a version in the name); *Later* |
| compiling against a functor's signature alone | D22, E10; M21, M22 |

## What the brief gets wrong, leaves open, or makes dangerous

Held to the code, as the other roadmaps' briefs were. The brief is a list of ideas to test, and it says so. Each item names what answers it.

### Wrong, or out of date

- **W1. "the COMPILER signature in basis and lib/compiler".** `COMPILER` exists only in `lib/basis/compiler_sig.sml:22`: D6 of `compiler-library.md` avoided the clash by naming `RUNE_COMPILER`. The real clashes are `structure RuneCompiler` (the Basis's against `lib/compiler/api/compiler.sml`, by shadowing) and `History`/`HISTORY` (`lib/terminal` against `lib/test/runner`). Once test/runner is in a closure, no order reaches terminal's (E1). D9.
- **W2. "smlnj does something similar e.g. BASIS_2024".** There is no such signature. SML/NJ has `basis-2004.cm` with `LIST_2004`, in which the older view is the named one and the newest the default. MLton has `basis-1997.mlb` and `basis-2002.mlb`. The technique is Rune's seals. D12.
- **W3. "backpack ... was never able to be implemented due to haskell's type classes being anti-modular".** Wrong on both counts. Backpack'17 shipped in GHC 8.2 and cabal-install 2.0, and its tests are in `~/reference/ghc/testsuite/tests/backpack`. The 2014 design failed because "its package-level semantics, were closely entwined with the semantics of Haskell itself" (Yang, ch. 1): the same entwining of build and compiler that module handles would bring back. Type classes do make its soundness theorem false, and it shipped anyway on "the social rules of Haskell". What it lacks is separate code generation. *What the literature says*.
- **W4. "most applications seem to still import the individual .sml files".** Twelve of 88 build files do, among them every root program but `runelsp.build`, and it has a cause: hosts have no `--library`, so `scripts/build-files.sh`, an awk reader, sees only `files` blocks and `use`. It is a rule the project wrote down for itself. So the bootstrap is not wholly out of scope: a modular `rune.build` needs D14 first, and without it the compiler's identity goes wrong (H1).
- **W5. "it currently meets is functional and non-functional requirments".** Its budgets are proposals in a ledger, enforced by an unbuilt milestone, and a leaf diagnostic's p95 was 942 ms against a proposed 250 ms. `rune.build` sits at 455-465 MB in a 512 MiB heap: retained 455-465 MB, peak at the cap. Ordinary code stops at 40-60k lines. Neither HOL4 nor MLton had been through it, nor is any scale target stated (E20). D28.
- **W6. "rune, hol4 and mlton as would be build via the build system".** HOL4 was not built through a build file, and `.build` cannot say how. Its tools come from a flattened `.mlb`; its code passes through `QUse`'s filter; its theories are scripts, each its own process, that generate `*Theory.{sml,sig,dat}`. E9 built the `src/boss` closure through one `.build` with theories taken as given. So the claim is verified for what `.build` can express: library code and compiled theories fit, and scripts are entry units. D16, D17.
- **W7. "units and pickling are still a complex and fragile part".** True, but the fragility is mostly not in the bytes. No value was misread. The fingerprint, a third traversal of the same types, diverged from the pickle (issues 8, 16-18), and the largest class is an input the key missed. *What a cache hit must satisfy*.
- **W8. "compiling against one big library unit expected to be faster".** It is not: *D19*. Once E15 lands, an aggregate adds nothing warm, costs 1.4 to 3.2 times on a one-file edit, and pushes the wrong way on link and decode.

### Contradictory

- **C1. "ideally a library form a nice abstract package" and tests that "need to break open the abstration".** No test defeats an ascription: they need names, not representation (E3). The two do not conflict once a library can name its friends. D11.
- **C2. "the separately compilable restriction" and a `.build` that stays Standard ML '97.** A restriction that made a correct program fail would contradict the Definition. Blume's restrictions serve inferring dependencies, and with written order a failing unit costs speed, never correctness. So D17 is a warning, and not a dialect.
- **C3. "one way of doing things" and a term language beside `.build`.** Two ways. The plan as contract makes the second invisible downstream, but it is still a second way. The review takes this as a reason not to build it now.
- **C4. "package manager will be a future roadmap" and "1000 .build files" in one repository.** No conflict in the end, but a logical name must have room for a version from the start. D3.

### Ambiguous

- **A1. "imports as a whole".** As a whole for names and meaning, yes. For what links, no: on the Basis, hello is 2 files by mention and 278 whole, 12 times the compile; a library loaded whole was not measured (E3). D7 separates available from loaded.
- **A2. "strict phase separation".** As written in the ideation, it is a discipline nobody enforces, and its own examples break it. *The ideation, reviewed* gives the six walls that make it a property.
- **A3. "the separately compilable subset".** Of what? A file's meaning under written order needs nothing. Under inferred order, or for reading names off syntax, it needs Blume's rules. D17 says which rule buys what, and drops the ones nothing needs.
- **A4. "the lsp may precompile some .sml files as we edit".** A shared static layer saves a client's re-elaboration, not the unit's own compile, since the back end starts from `decs` (`lib/compiler/driver/pipeline.sml:286-296`). D27.

### Dangerous

- **H1. A modular `rune.build` silently breaks the compiler's identity.** The awk's list feeds `Config.identity` (`scripts/gen-version.sh:51`). Done naively, an edit of `lib/unicode` leaves the identity unchanged, and a changed compiler serves a stale entry (E12, D14). D14 precedes every migration of a root.
- **H2. Removing MANIFEST first would ship an empty compiler from a green build,** since `scripts/install.sh` reports success with no Basis (E28). D13's order puts a one-line guard first.
- **H3. A key smaller than what the compiler reads gives wrong code without complaint.** Name-free keys (39 of 104 random edits disagree with no cache, E16) and a static-only batch key (an internal error, a link refusal, different bytes, E17) both look like improvements by the rebuild count. `results/L1`'s model shows why. Every proposal prototyped was checked against no cache. Those not prototyped (a layout-only ABI layer, imports out of the hash, a hash per filter) must pass the same check before they land.
- **H4. A boundary added on master merges cleanly into a branch and hides what the branch added** (E28). D15.
- **H5. Lazy load fills stamp-keyed tables on demand, so a missed read is silently wrong code.** E15 found one: the text of another unit. D2 and D20 keep the mask and per-unit verification in `make check` for this reason.
- **H6. An error for the restriction would refuse correct programs.** See C2.
- **H7. Migrating a live repository.** 34 refs are ahead of master. D15's recipe costs one rebase each, shown on `win32-desktop` in E28. This roadmap runs it on no win32 branch: that work is left alone, and migrated after it lands (D15).

### Where this roadmap recommends otherwise than the brief

The head names the four things it recommends against and the fifth it makes a warning; D17, D18, D19, D22 and D29 argue them. The owner took all of these but D22.

## Where we are

Master at `b12141ecc`. Paths are relative to the root and line numbers are of
that commit. To keep citations short:
- `main.sml`, `options.sml`, `parallel.sml` and `serve.sml` are in
  `src/driver/`;
- `buildfile.sml`, `project.sml`, `context.sml`, `libraryscope.sml`,
  `basismanifest.sml`, `deps.sml`, `unitcache.sml`, `unitbasis.sml`,
  `unitmid.sml` and `pipeline.sml` are in `lib/compiler/driver/`;
- `api/` is `lib/compiler/api/`, and `lsp/` is `src/lsp/`;
- `incremental-compilation.md`, `functors-units.md`, `build-cache-issues.md` and
  `language-server.md` are in `docs/plans/`;
- HOL4's paths are under `corpus/hol4/HOL` at `65ab0d8e6`. The reference tree
  does not check that submodule out, so they were read in a clone of that
  commit.

"Observed" means an experiment ran it. "Deduced" means it comes from reading the
code and nothing ran it. A sentence with a citation and neither word says what
the code does.

### The build language

A build file names a program's files, their order, and what each file sees.
`--build F` turns on `--units` (`options.sml:265`), and the files of F's plan
become the compile's inputs (`main.sml:464`).

- **Parser:** `buildfile.sml`, 195 lines, twelve forms of declaration
  (`:13-25`).
- **Planner:** `project.sml`, 151 lines. `plan` (`:85-139`) makes a tree of
  steps (`:5-9`): a unit with its annotations, `local`, `library`, `use`,
  `implements`. `libraries`, `inline` and `cache` make no step. They go into
  flat lists that forget where they were written (`:129-132`).
- **Meaning:** a unit is compiled in what "the steps before it leave"
  (`buildfile.sml:3-5`), and `elabSteps` follows the tree (`main.sml:917-958`).
  The same comment says the semantics is MLB's. It is not, in one respect: a
  `use` elaborates in the caller's basis, an `.mlb` in an empty one. Observed in
  E9: `mlyacc-lib`, first used after `lib/mlton`, saw MLton's `List`.

A census of the 88 tracked build files, read with the compiler's own parser,
none refused (E1):

| Construct | Uses | Files |
|---|---:|---:|
| bare path | 675 | 67 |
| `files` | 49 blocks, 466 paths | 35 |
| `use` | 38 | 38 |
| `libraries` | 39 | 39 |
| `annotate` | 57 | 35 |
| `implements` | 10 (5 hand-written) | 10 |
| `inline functor`, `inline val` | 2, 1 | 2, 1 |
| `library (...)` | 2 | 2 |
| `group`, `local`, `cache` | 0 | 0 |

- **Annotations:** `demand` 48, `host=no` 11, `always` 3, `seal` 3, `final` 2,
  `host=swap` 1. `allowPrim`, `noWarnings` and the source modes have no use.
  `group`, `local` and `allowPrim` are exercised only by the fixtures that
  `tests/runner/scenarios.sml:84-98` writes.
- **`Deps`' discipline** (`deps.sml:183-203`) is enforced in two places. One is
  a `group` (`project.sml:115-122`), which nothing uses. The other is
  `--basis-check`, on demand and seal files (`main.sml:186-192`), run by
  `make check-docs-generated` (`Makefile:1550`) and
  `tests/runner/tools.sml:286`.
- **Generated:** 15 of the 88: 10 in hash-named sets, 5 `current.build` pointers
  beside them (E1).
- **`..`** appears in 25 of the 88.

**The command line is a second build language.** `--library`, `--basis`,
`--no-prelude`, `-I` and plain file lists (`options.sml:229-236`,
`main.sml:272-300,489-493`) say what a build file says. 63 lines of the Makefile
give `$(RUNE)` a `--library`.

**Four readers of the syntax:**
- `BuildFile`;
- `basisIndex` (`main.sml:338-435`), a walker of its own, which refuses
  everything but files, `annotate`, `use`, `library`, `libraries` and `inline`
  in a `library.build` (`:370`) and expands no `$(VAR)` (`:348`);
- the awk script of *Hosts and the compiler's identity*;
- text rewriting for the Basis's signatures (`tools/generate/signatures.sml:14`,
  with `tools/generate/mlb.sml:9`).

**Six sites load a library and apply its boundary:** `main.sml:896-914`,
`main.sml:1112-1174`, `api/session.sml:214-237`, `api/query.sml:89-99`,
`api/analysis-engine.sml:231-240`, `src/doc/docelab.sml:34-45`.

**What passes without a word:**
- An unknown annotation is ignored (`project.sml:14-15`, `main.sml:378-383`):
  `annotate "demnad"` means demand.
- A program-level export that names nothing is dropped (`context.sml:22-26`).
  Only `--basis-index` and `--basis-check` check exports. Observed in E3.
- A relative `$(X)` is spliced, then resolved against the file that uses it
  (`buildfile.sml:173-192`), so it serves one directory. 4 tracked builds work
  only with an absolute value (E12, observed).

**One bug in this layer:** `--typecheck-only` with `--build` returns at
`main.sml:827`, before `logDeclared` at `:857`, and `context.sml:31-33` reads
that list. So a library's exported signatures and functors are lost, and a
correct program is refused. Observed in E3 and E9, with 630 false errors on
MLton.

**`docs/build.md` is out of date.** The numbers here are its lines:
- 13: "renaming", which does not exist;
- 51-52: the path characters, which differ from `buildfile.sml:38-47`;
- 60-61: hosts using `--build-list`, which they do not;
- 100-103: four libraries named, where 33 exist;
- 241: `tests/buildfile/run.sh`, which is absent.

### Libraries and boundaries

33 directories under `lib` have a `library.build`: 28 hand-written, 5 generated.
A library's name is its path under `--lib` (`basismanifest.sml:182-185`), so
nesting means nothing: `lib/test/property` and `lib/test/property/basis` are two
unrelated libraries, and `lib/test` and `lib/ffi` are plain directories. The
Basis is implicit; any other library needs `libraries` or `--library`
(`main.sml:518`).

**`libraries` is global, flat and transitive.** The names go to one list
(`project.sml:130`), merged with `--library`'s (`main.sml:453-455`), and every
library is compiled before every unit (`main.sml:1001-1003`). `local` cannot
scope one. The list closes over each MANIFEST's `# library:` lines
(`basismanifest.sml:228-240`), so a library sees what its dependencies depend
on: `lib/lsp` needs `Json` and names only `jsonrpc unicode`
(`lib/lsp/library.build:2`). The graph of the 33 (E1, with E12's recount):
- names used outside the declared closure: 0;
- edges used but reached only transitively: 12, 7 hand-written and 5 generated;
- declared and unused: 1;
- cycles: none;
- only the Basis has top-level values, datatypes or exceptions.

**Available is not loaded.** `libraries` says a library may be used. What loads
is `select` (`basismanifest.sml:136-171`): the `always` files, the files whose
public names a program mentions, and what those require. "Mentions" means tokens
(`:115-122`), not uses.
- `fn F => F + 1` and `fn E => E + 1` print differently when a library file
  declares `structure E` with an initialiser; a record label `{E = 1}` does the
  same. Observed in E3. So renaming a bound variable changes a program's output.
- Mention decides which initialisers run, and it is what keeps small programs
  small: `hello` loads 2 of the Basis's 278 files, and 295M instructions become
  3551M with `--basis all` (E3).

**A boundary is a filter of names.** The planner only records it
(`project.sml:124`). After a library's units are elaborated, `context.sml:21-41`
(units) or `libraryscope.sml:8-22` (whole) filters the environment. `select`
respects it too (`basismanifest.sml:144-146,158`). `local` (`main.sml:927-933`)
and MLB's export lists are filters as well. Exactly one hand-written library has
a boundary, `lib/compiler` (`lib/compiler/library.build:3`), plus the fixture
`tests/lib/exports/library.build`. Export lists put on 31 libraries changed no
byte of 159 client programs, and S41 and S42 held on the four programs tried
(E3, observed).

| Across a boundary | |
|---|---|
| A top-level value or exception | never: there is no such export kind (`buildfile.sml:12`, `context.sml:24`, `libraryscope.sml:13`) |
| Fixity | never (`context.sml:35`) |
| A structure, signature or functor | by name; an exported structure's members are not filtered |
| A type | by name; in a library only an abbreviation, since `Deps` declares no top-level datatype (`deps.sml:196`, `main.sml:399-404`) |
| A private type through an exported signature | yes, unnamed: it works, equality and re-ascription included, and naming it is refused (E3, observed) |
| Constructors through `datatype u = datatype t` | only in a program-level `library (type t)` over a top-level datatype; `--basis-index` refuses that form (E3, observed) |

- **The compiler has no closure rule; runedoc has one.** A structure that claims
  a signature the library does not export is an error
  (`src/doc/docclaims.sml:115`). With boundaries on, 21 of 22 libraries were
  refused for that until 90 ascribed signatures were exported too (E3,
  observed).
- **The Basis has no boundary and cannot have one today.** For the reason in the
  table, `--basis-index` refuses `type option`; with those exports dropped,
  `--units` loses every value (E3, observed).

**The bypass.** `use` keeps the raw delta of what it ran (`main.sml:939-946`;
`api/analysis-engine.sml:264-266`).
- The second `use` of a file shows what a boundary hid: after
  `library (structure Pub) = use x.build end`, a plain `use x.build` gives the
  private names (E3, observed).
- The first `use` of a sub-build is the same thing, and it is how the compiler
  is built: `rune.build` uses `lib/compiler/internal.build`, and
  `lib/compiler/library.build:1` says "Drivers use internal.build".
- Tests do the same, and say so (`tests/lsp/syntax-tests.build:1-3`).

**Reaching in** is 12 hand-written builds, or 17 by the mechanical rule, which
counts the 5 generated pointers (E1). Ten list library files directly, 216 path
entries; nine `use` a sub-build under a boundary; seven do both. Of the root
builds only `runelsp.build` does not reach in. `rune.build`'s 19 lines of
`lib/unicode` and `lib/json` are copied with their comment into 5 more builds,
because `lib/compiler/internal.build:1-3` declares no dependency. The cause is
in *Hosts and the compiler's identity*.

**Clashes.** Two libraries may declare one name with no diagnostic: both files
load and the later shadows (`basismanifest.sml:15-18,158,228-240`). A duplicate
is refused only inside a `group` (`deps.sml:232-235`). 15 names are public in
two or more libraries, 12 of them between generated alternatives never loaded
together (E1). Three are real:
- `structure RuneCompiler`: `lib/basis/compiler.sml:8` and
  `lib/compiler/api/compiler.sml:4`, by shadowing. The REPL binds the Basis's by
  name (`src/repl/repl.sml:741-742`).
- `structure History` and `signature HISTORY`: `lib/terminal` and
  `lib/test/runner`. Once `test/runner` is in the closure, no order reaches
  terminal's (E1, observed).

No name crosses kinds. `COMPILER` exists only in
`lib/basis/compiler_sig.sml:22`.

**Namespaces:** none. There is no renaming and no hierarchical name. The
convention is a `Rune` or `RUNE_` prefix, which `lib/basis/library.build:20-24`
calls "not a wall".

**Views of the Basis.** 80 seal files rebind a structure as its signature shows
it (`structure List : LIST = List`), class `Seal`, never pulled in by a library
file's requires (`basismanifest.sml:144-146`; `lib/basis/library.build:275`).
Basis files see structures whole and other libraries see them sealed
(`main.sml:520-526`). `--no-prelude` and `--basis all|demand` exist
(`options.sml:233-236`), and `--lib DIR` swaps a whole tree. There is no way to
choose among views.

### MANIFEST

Each library has a generated `MANIFEST`, one line a file in load order
(`basismanifest.sml:8-20,75-98`, written at `main.sml:428-432`):
`file | class | host | provides | requires`, a sixth column for a boundary, and
header lines `# library:`, `# inline:`, `# inline val:`. `lib/basis/MANIFEST` is
278 rows and 25 KB: 195 demand, 80 seal, 2 always, 1 final. Only `lib/compiler`
has six columns. `make manifests` (`Makefile:430-502`) makes them, in an order
of libraries written by hand there.

| Field | Comes from |
|---|---|
| file, order, class, host, `# library`, `# inline`, `# inline val`, boundary | `library.build` (`main.sml:352-370,378-383`) |
| provides | `Deps.declares` of the file (`main.sml:411`); the kind is lost |
| requires | `Deps.uses`, intersected with what earlier files, the Basis and the libraries provide (`main.sml:389-398,412-414`) |

So every column is a projection of `library.build` except provides and requires,
which also read the sources. `requires` is not a per-file fact: it depends on
the other libraries' MANIFESTs, and `uses` is the per-file fact beneath it.

**Why it exists.** `select` must map a mentioned name to a file it has not
loaded, so it needs `provides`, `requires` and `class` of every file up front. A
MANIFEST is what saves parsing them. Its cost, in `instructions:u` (E2,
observed):
- reading the Basis's: 6.44M;
- reading it and selecting for `hello`: 9.12M, or 3.1% of that compile's
  296.31M;
- reading all 33: 19.62M;
- `--basis-index lib/basis`: 622.93M, about 97 times a read.

**It is not validated.** It holds no hash, and nothing at compile time checks it
against `library.build` or the sources. `--basis-check` is a separate step and
never reads `library.build`. Over 15 stale scenarios (E2, observed):

| Outcome | Scenarios |
|---:|---|
| 6 | a silent wrong answer: a new shadowing file; a library file shadowing a Basis name; demand to always, initialiser not run; two files swapped; a boundary added, the hidden name still visible; a library adding a Basis name |
| 7 | an error |
| 2 | correct by accident |

4 of the 6 pass `--basis-check`. The cache stayed sound: a MANIFEST made, rolled
back and checked with `--verify-cache` gave the right result, and so did `-j`
over a stale `requires`.

**Two checks read a MANIFEST wherever they run.** Using a name only a later file
provides, and exporting a name no source declares, are refused in `--basis-index`
(`main.sml:415-417,402-404`) and in `--basis-check` (`:183-185,202-205`). Both
take the other libraries' facts from their MANIFESTs. `--basis-index` also
misses a name hidden by a dependency's boundary: it exits 0 and the client fails
(E28, observed).

**Its other jobs:**
- `-j` scheduling (`main.sml:967-971`);
- the compiler library and analysis (`api/prelude.sml:18-24`,
  `api/session.sml:65-81`, `api/query.sml:84-99`);
- runedoc's elaboration, public names and dependency graph
  (`src/doc/docelab.sml:34-45`, `src/doc/docsite.sml:29-33,1389-1417`);
- the REPL's inline headers (`src/repl/repl.sml:679-682`);
- the LSP's watcher (`lsp/controller.sml:75`,
  `lsp/worker-analysis.sml:397,414`);
- text-table readers: `scripts/install.sh:300-316`,
  `tools/builder/dist.sml:7-8,17-20`, `tools/builder/vscode.sml:74-78`,
  `tools/generate/host-basis.sml:36`, `tools/generate/flatten.sml:63`,
  `tools/generate/signatures.sml:28`, `tools/generate/xc2-poly.sml:41`,
  `tools/measure/basics.sml:60`, `tests/runner/hosts.sml:33-46`.

Fixtures: 21 tracked MANIFESTs under `tests/doc` and `tests/lib`, 16 of them
runedoc's, with no `library.build`, plus 7 test programs that write one inline
(E28), plus 2 provenance copies under `examples/benchmarks/validation`.

**Installs have no `library.build`.** `scripts/install.sh:298-316` and
`tools/builder/dist.sml:12-29` copy a MANIFEST and the files it lists, and
`tests/runner/distchecks.sml:219` asserts the build file's absence. With no
MANIFEST, `install.sh` exits 0 having installed 89 of 822 files and no Basis
(E28, observed).

Stage 0 makes its index before it has one: the Basis is linked without its
MANIFEST (`Makefile:1889-1896`), and `--basis-index` needs no other library's
for `lib/basis` (`main.sml:390`). Other libraries need their dependencies'
MANIFESTs first (E2, observed).

### Hosts and the compiler's identity

**The compiler is not built by `--build`.** `bin/rune.rbc` comes from a file
list (`Makefile:1913-1914`, `:269`). The only `--build rune.build` is the
reproducibility oracle (`tests/runner/oracles.sml:1107`). `rune.build` matters
for two other reasons: an awk script reads it, and the compiler's identity
hashes what the awk finds.

**The awk.** `scripts/build-files.sh` reads `files` blocks and follows `use`
(`:1-4,55-64`). Bare paths, `libraries`, `group`, `library` and `local` do not
exist for it. `Makefile:114` takes `SOURCES` from it, and
`scripts/gen-build-files.sh:30` makes the hosts' build files from it. A host has
no `--library`: MLton, Poly/ML, SML/NJ and MLKit are given flat lists. That is
why root builds list library files, and it is the cause of reaching in.

| Build | Awk | Plan, flattened | Difference |
|---|---:|---:|---|
| `rune`, `runedoc`, `runeisa`, `runeopt` | 104, 74, 9, 17 | 2 more each | `build/config.sml`, the main file |
| `runeffi` | 55 | 1 more | the main file |
| `runelsp` | 22 | 157 | the closure of its libraries, and the main file |

(E12, observed; the order agrees on all six.) `--build-list` is a third list: it
also omits the closure, 23 files against `runelsp`'s 157 (`main.sml:1294-1295`,
E12).

**The identity.** `scripts/gen-version.sh:51-55` hashes the awk's list for
`rune.build`: 104 files. The result is `Config.identity`, which is the first
setting of every cache configuration (`unitcache.sml:125`), goes into a unit's
provenance (`lib/compiler/backend/link.sml:105`) and starts analysis's chain
(`api/analysis-engine.sml:110`). It is what separates one compiler's entries
from another's.

- What it does not cover: `src/main/rune-main.sml`, `build/config.sml`, which
  holds it, and `lib/basis`, which `rune.build` does not name. None of the 104
  is one of those.
- A file the awk cannot see is outside the identity. E12 ran the case, with
  `rune.build` reaching `lib/unicode` and `lib/json` through `libraries`, and a
  compiler with a real edit took the old compiler's cache entry (D14).

**The hash.** `Pickle.hash` is rx2fw, 126 bits, not cryptographic
(`lib/compiler/util/pickle.sml:102-123`). Its values depend on the host's
`Word`, so `P.probe` is in every configuration and basis
(`unitcache.sml:120-131`, `unitbasis.sml:2196`), and a compiler whose hash
differs takes none of another's entries. It agrees on Rune, MLton, Poly/ML,
SML/NJ 64-bit and MLKit; `smlnj32` differs (E10, observed; the hash alone, not a
fingerprint's text).

### Units and what is in one

Under `--units` every file is a unit: a Basis file, a library's file, a
program's file (`main.sml:547-552`). A unit compiled is one cache entry
(`unitcache.sml:45-47`), which bundles four things:

| Part | Magic | Holds | Code |
|---|---|---|---|
| entry head | `RCE` | usages, warnings, source name, `others`, identity, lint level, imported schemes | `unitcache.sml:231-260,396-414` |
| basis | `RBI` | fixity, environment, signatures, functors, inlinable functions as Mid, overloading, per-stamp tables | `unitbasis.sml:2131-2215`, reader `:2698` |
| code | `RUNU` | identity, named units, code, keys, imports, exports, declared results | `lib/compiler/backend/unitfile.sml` |
| Mid | `RBM` | ToMid's output, datatypes, function names, pins, open types | `unitmid.sml` |

The same parts appear elsewhere: `--emit-units` writes `.rbu` and `.rbi`
(`main.sml:1052-1075`), the compiler library writes `.rbi`, `.rbm` and `.rbs`
(`api/session.sml:301-303`), and a program that can load units keeps their
exports in its `.rbc` (`main.sml:1044`). Where the entries live is the subject
of *`.rune` and `lib/cache`, explained*.

**Identity.** `name@hash` (`unitbasis.sml:2211`), the hash of a header and the
body of the basis (`:2196-2199`). The header lists the identities the basis
names, so identity is Merkle. Usage counts, source hash and mode stay outside
(`:2200-2210`). A unit whose body changed and whose basis did not keeps its
identity, and what used it stays valid (`:22-25`). This is the cut-off.

**A unit's name is a path as spelt.** A program's unit is named by its path
(`main.sml:578,924`), joined to the build file's directory with no
canonicalising (`project.sml:108,113`; `pathKey` serves only `use`, `:125-126`).
A library's file is named by its place in the library, `lib/basis/list.sml`
(`main.sml:569-574`), which is the one logical name that exists. The name
reaches five places: identity (`unitbasis.sml:2211`), a usage's binder
(`:1328-1330`), fingerprint anchors (`:262-271`), remapping (`:2632`), the key
(`unitcache.sml:217`). So:
- `tests/lsp/worker.build` lists `../../src/lsp/profile.sml` and `runelsp.build`
  lists `src/lsp/profile.sml`: one file, two keys, and the difference reaches
  dependents' binders;
- 149 of the 826 files in a readable build have 2 to 5 spellings (E22);
- `./ty.sml` for `ty.sml` changes 86 of 987 bytes of a `_dynamic` client (E10,
  observed);
- two files with one text are two units
  (`tests/incremental/SCENARIOS.md:35-37`); S7's own text says otherwise
  (`:71-74`) and is wrong;
- **one file under two builds is one result only with the same spelling, the
  same cache directory and the same configuration.**

**Usages.** A compile records each name it looks up
(`lib/compiler/util/usage.sml:1-6`) with the unit that bound it, as
`IDENTITY FINGERPRINT` (`unitbasis.sml:1328-1333`). An entry serves a compile
where every usage holds: by binder, a string compare, or, where the old binder
is not in the session, by fingerprint (`:1341-1353`). A hit by fingerprint needs
remapping, which the paths files of `units/` feed (`:2624-2643`). A program that
may load units takes no entry across a change (`unitbasis.sml:2619`,
`main.sml:590-592`).

**One interface, mixed.** A unit has one pickle, one identity and one
fingerprint stream. Static types sit beside back-end facts:
`Translate.primAliases`, `Lower.knownBefore`, `Expand.globalAliases` and
`Expand.primGlobals`, per stamp (`unitbasis.sml:2094-2098`), which `fpVal`
hashes too (`:507-521`). `fpVal` (`:496-528`) is a list of tables kept by hand,
and a new table that affects code must be added to it by hand.
- **Hash-only fields:** export of load was not the identity on 9 of 18 units at
  first, because a writer adds fields no reader keeps; with those left out it
  holds on 13,363 generated units, `rune.build`'s 246 and MLton's 791 (E19,
  observed). A basis holds a fingerprint inside its pickle.
- **Positions:** origins enter the pickle (`unitbasis.sml:1887,2113`) but batch
  never records them (`lib/compiler/elab/env.sml:41`). A compile also reads
  other units' text for a copied function's frames, which no key covers (E18,
  observed as a warm trace naming the old line).
- **Size:** in batch, MLton's 22 MB of pickles become 1.76 GB live once loaded
  (E15). In analysis its signatures are copied per unit: 2.7 GB of pickles, up
  to 42 MB a unit, for 8 MB of source (E20).

**Mid** is stored as ToMid made it, before the optional passes
(`pipeline.sml:199-200`). So per-unit optimisation is never reused, and
`--units --whole` reuses only the front end. Every entry keeps it whether or not
`--whole` is ever used (`main.sml:559`).

**The code that does this is hand-written:** about 4,600 lines (`unitbasis.sml`
2,930, `unitcache.sml` 437, `lib/compiler/backend/unitfile.sml` 347,
`unitmid.sml` 339, `lib/compiler/core/midcodec.sml` 216,
`lib/compiler/util/pickle.sml` 350), with four traversals of the same types:
writer, reader, fingerprint walk and `sameEnv` (`unitbasis.sml:1930`). Readers
are positional, with read-and-discard blocks (`:2781-2783,2821-2823`). Seven
version constants are bumped by hand:

| Constant | Value | Where |
|---|---:|---|
| `UnitBasis.version` | 14 | `unitbasis.sml:44` |
| `UnitCache.version` | 10 | `unitcache.sml:32` |
| `UnitMid.version` | 5 | `unitmid.sml:22` |
| `UnitFile.version` | 4 | `lib/compiler/backend/unitfile.sml:18` |
| `RCS` | 2 | `api/session.sml:278,283` |
| `rbcVersion` | 6 | `lib/compiler/backend/opcodes.sml:6`, `src/isa/stack.sml:14` |
| image | 15 | `src/opt/rbcimage.sml:23` |

Inside the cache they decide little, since `Config.identity` moves with any
source in its list. They matter for `.rbu`, `.rbi`, `.rbm` and `.rbs` read
directly, for bytecode and for images. `UnitMid.version` is in no configuration.

**How it has failed.** No value was misread. But the fingerprint, a third
traversal of the same types, diverged from the pickle (issues 8, 16, 17, 18), a
read and a write gave other bytes (11, stale for code today, E19), and three
readers assumed a hash's width (`build-cache-issues.md:456`). The largest class
is an input the key missed (`build-cache-issues.md:10-15`). Three more are live:
- `--functor-budget`, `--type-work` and `--match-work` are in no key: a warm
  build gives other bytes, and with `--type-work=1` exits 0 where a cold one
  exits 1 (E18, observed; `options.sml:332-337`);
- the line of a copied function, above;
- a file given twice: whole prints `0 10`, `--units` prints `10 10`, with or
  without the cache (E16, observed), which is issue 22 in batch.

**What checks it.** S41 (cold and warm give equal bytes) and S42
(`--units --whole` gives the bytes of a whole compile) in
`tests/runner/oracles.sml`; S43 (five hosts, one set of bytes) in `check-cross`;
every compiled unit reloaded from its own pickle (`pipeline.sml:300`); lint
levels; `--verify-cache`, which compares hits by binder and compiles hits by
fingerprint again without comparing them (`main.sml:720-726`, issue 15);
`tests/runner/soundness.sml`, which compares old fingerprints with new and has
no absolute oracle. Of 37 mutants of this code, 13 survive every check E18
tried, and `soundness.sml` alone catches 1 of 9 fingerprint mutants (E18). What
a hit must satisfy is in *What a cache hit must satisfy*.

### How a warm build goes

There is no shortcut: a warm build walks every unit.

1. **Plan.** Every build file is read and parsed (`main.sml:450`).
2. **Read and lex every input** (`main.sml:506-509`). No stat: no `modTime` in
   the driver or the cache, and "nothing in a key is a time"
   (`unitcache.sml:24`).
3. **Select.** Read the MANIFESTs, choose by mention, lex the chosen libraries'
   files, choose again (`main.sml:518-529`).
4. **For each unit in order** (`main.sml:689-800`):
   - hash its text and make its key (`:695`);
   - look in the project's cache, then in `lib/cache`, the frozen layer
     (`:708-714`): read each candidate entry whole, code and Mid included, hash
     it, check its usages (`unitcache.sml:231-260,264-307`);
   - decode the code and check the instruction set (`main.sml:735-736`);
   - work out a remapping, refuse absent units, check schemes (`:740-750`);
   - **load the basis in full** (`:751`);
   - relocate source names and bind (`:755,776-784`).
5. **Link every unit** (`main.sml:1029`) and write the program.

A no-op and an edit of a leaf cost nearly the same, because both do all of this.

| | Cold | No-op | Peak, no-op | Units |
|---|---:|---:|---:|---:|
| MLton, flat list | 454.7G, 98 s | 88.89G, 15-18 s | 1.92 GB | 791 |
| HOL4 closure | 80.5G | 26.06G, 5.6 s | 567 MB | |
| `rune.build` | 18.3G | 9.72G, 1.7 s | 265 MB | 246 |

(E15, stock compiler, tier 2, load 3-7. `rune.build`'s cold takes most units
from the frozen layer. MLton's published 60.2G is a compiler built by MLton, and
its 105.0G was taken at load 27.) Where the no-op goes, as a share of wall time
(E15):

| Stage | MLton | HOL4 | `rune.build` |
|---|---:|---:|---:|
| basis load | 62.3% | 2.6% | 4.1% |
| link | 17.3% | 32.4% | 32.8% |
| code decode | 8.7% | 15.9% | 25.8% |
| lex | 3.0% | 7.9% | 8.7% |
| entry read and hash | 2.3% | 8.5% | 11.3% |
| usage check | 0.9% | 3.4% | 3.9% |
| select | 1.1% | 3.1% | 3.0% |
| schemes | 1.6% | 1.7% | 1.7% |

Only MLton has that first row, for the reason under *Units and what is in one*.
GC is about 40% of its machine instructions.

**At scale** (E21, a generated fixture, one job; load 4-14): cold 60.4G at 117k
lines, 196.8G at 351k, 766.3G at 1.165M, at 4.81 GB. On this fixture a no-op costs
39-40% of cold at every size, and a small edit costs what a no-op costs.

**A unit that must compile** elaborates against the whole accumulated
environment (`main.sml:803,817`), every earlier basis loaded in full.

**`-j`** (`parallel.sml`, 235 lines): the parent walks units in order through
the cache; before each it forks for later likely misses, of at least 16,384
bytes of text (`main.sml:989-993`, `parallel.sml:143-162`), and children hand
results over through the cache. `Deps.analyse` parses every user file first
(`main.sml:973`). Dependencies come from `Deps` by name and from the MANIFEST
for the Basis, and a unit that breaks the discipline depends on everything
(`parallel.sml:61-62`). `-j 4` makes `rune.build`'s no-op slower, 12.75G against
9.71G (E15); `-j 8` gives no speed-up on the fixture, even with the threshold
lowered (E21).

**A name in a user's file can turn part of the cut-off off.** MLton's S47
published 236 units for an interface edit. 20 of them must compile; 216 hold
across the change (E18, by `--verify-cache`'s classification) and compile
anyway. MLton declares a `structure Runtime`, which is a mention, so `select`
pulls `lib/basis/runtime.sml`, and `loadsUnits` then turns remapping off for the
whole program (`main.sml:590-592`). Observed in E15 and E18.

### What separate compilation means today

**Three modes** (`main.sml:544,553-1030`):

| Mode | Front end | Passes | Back end |
|---|---|---|---|
| default | one program | all, `Pass.whole` true | one `.rbc` |
| `--units` | per unit | per unit, no Shake, Workers keep wrappers, Simplify inlines no called-once function (`docs/units.md:47-52`) | per-unit code, then `Link.program` |
| `--units --whole` | per unit, cacheable | all passes over the concatenated Mid (`main.sml:1016-1028`) | a closed program; `_dynamic` refused |

**A unit is compiled against the prefix, not its dependencies.** It sees what
the units before it declared (`docs/units.md:17`), in the order the build gives,
which is the program's order (`:20`). This is incremental compilation in SMLSC's
sense: `incremental-compilation.md:1492-1499` chose it, because it "keeps
abstraction seen through, known calls known and small functions inlinable across
units". `_virtual` and `_dynamic` are the separate exceptions
(`docs/build.md:211-245`).

**Across units**, the only optimisation in `--units` is inlining what is marked:
`inline functor`, `inline val` and functions that only apply a primitive,
carried as Mid in the basis (`docs/units.md:128-137`). Nothing aggregates units:
`library` is scope alone (`main.sml:934-938`), D8's single library file was not
built, and "units coarser than a file" is listed as unbuilt
(`incremental-compilation.md:3136`).

**No subset is named.** "Separately compilable subset" appears in no document
but the brief. The nearest thing is CM's discipline (`docs/units.md:575-584`), a
property of a `group` that exists to infer order. `rune` itself restricts
nothing. With written order, a unit that breaks a rule costs speed, never
correctness (E5). Host rule 2 (`docs/building.md:762`) is a separate rule, for
SML/NJ's CM.

**Who would fit** a rule of no top-level value, effect, exception, datatype,
`open`, fixity or `use` (E8, observed):

| Corpus | Shared units that fit |
|---|---:|
| Rune compiler | 84 of 84 |
| Rune libraries, their tests, the rest of `src` | 318 of 318 |
| Basis | 257 of 259 |
| MLton | 599 of 599 |
| HaMLet | 212 of 213 |
| HOL4 `src/boss` closure | 741 of 743 |
| HOL4 library | 1,176 of 1,179 |

A **shared unit** is one others depend on, and an **entry unit** one nothing
depends on. By the graph: MLton 599 and 7, HOL4's closure 743 and 3, HaMLet 228
and 11, Rune 686 and 137. HOL4's theory scripts are entries: nothing links to
one, only to what it generates. The units that do not fit are one kind,
**prelude units**, which define the language for those after them:
`src/thm/Overlay.sml` (`:42`, `open Kernel`; `:49`, a datatype replication), the
Basis's `always` files, HaMLet's `Syntax.sml`. 142 of the closure's 746 parse
differently without the fixity carried in.

**Order and effects.** Across random legal orders, a unit's bytes depend on
names, never on order, once names are unique: Rune 246 of 246, MLton 791 of 791,
HaMLet 310 of 310, HOL4 923 of 923 (E6, observed). The one cause of change is
one name declared twice (S19). The only hidden effect dependence is HOL4's: two
output lines, `Theory.ancestry` order and `srw_ss` fragment order. No cheap
static proxy for effects works: the two tried flag 8-37% of shared units, and
Rune's flagged units never mattered.

**Closures.** A unit compiled from its dependency closure alone gives the bytes
of the full build: Rune 22 of 22, HOL4 30 of 30 (E5, observed), HOL4 given one
added edge, Overlay before all, and its duplicate `Systeml` removed. Today's
code never does this.

**What each SML '97 feature does across units:**

| Feature | Today | Where |
|---|---|---|
| Top-level `open` | breaks the discipline; a change in what it opens recompiles the unit | `deps.sml:200` |
| Overloading | settled inside a unit in every mode; a usage holds by binder alone, so imprecise | `docs/units.md:33-35,499-503` |
| Flexible records | settled by a file's end; `--flex-records=program` is accepted whole and refused in units | `docs/units.md:42-45` |
| Free type variables | refused by default; the `later` modes end at the unit, not the program (E5, observed) | `docs/units.md:38-40` |
| Fixity | a parse depends on earlier units, and every identifier parsed is a usage; `Deps` parses with `Fixity.initial`, so it can be wrong (E5: `--deps` stops at HOL4's `Conv.sml:205`) | `lib/compiler/frontend/fixity.sml:26`, `main.sml:235-236` |
| `datatype` replication | breaks the discipline; tags go by sorted names | `deps.sml:197`, `docs/ir.md:455-459` |
| `where type` between virtual modules | not built | `incremental-compilation.md:3057` |
| Generative functors | fresh names per application; memoised applications are *Later* | `docs/units.md:137-141`, `functors-units.md:4174` |
| Exceptions | run-time `NEWEXN`, generative for free | `incremental-compilation.md:851-855` |
| Top-level `use` | `Compiler.use` raises in batch, REPL only; unbound as a name in both batch and the LSP (E22) | `lib/basis/compiler.sml:10-12` |
| Structures with no signature | the interface is inferred, so dependents need the real basis | `functors-units.md:1085-1088` |

**Opaque ascription is no firewall.** A realisation is a usage
(`unitbasis.sml:486-488`), `Ty.convert` sees through for everything entering Mid
(`lib/compiler/core/ty.sml:369-371`), and a client's own datatype layout depends
on it (`:459-467,478-486`). So a private change behind `:>` recompiles the
client: S11, and E5's `opaque-body` probe. This is not only a key policy: the
client's bytes can depend on what is hidden. HOL4 is firewall-ready in syntax
(340 `:>`, 2 `:`, 48 bare); Rune is not (161, 124, 247) (E5).

**Functors.** Changing a functor's body recompiles no client, because a client
depends on `fpFunctor` (`unitbasis.sml:1235-1245`); changing its result does.
Observed in E10. A client cannot compile before a functor exists: structures
have `_virtual` and `_dynamic`, functors have neither
(`incremental-compilation.md:2011`). `Ty.maxFlat` and `Ty.flatTags` limit what a
functor compiled to a function accepts (`docs/language.md:28`).

**The REPL keeps the Definition.** Of 361 `tests/lang` programs, 330 run through
the REPL. By `use`, 325 match; of the 5 that differ one is a real deviation
(`ty.infer.valuerestriction_later`, documented), and the rest are by design or
backtraces. On 616 corpus programs, 316 give the same result and 298 are refused
both ways, 295 with the same first error. The other 2 are an unterminated
comment and one bug: `rune-repl` has an internal compiler error on
`functor F (X : S) = X and G (Y : S) = Y` (E7, observed).

**Large programs already build.** Through one build file, with no unit refused:

| Build | Instructions | Wall | Peak |
|---|---:|---:|---:|
| HOL4 closure, 744 units, `--no-cache` | 72.7G | 21.1 s | 699 MB |
| the same, warm | 26.0G | 5.5 s | 568 MB |
| MLton, 606 files from 30 `.build`, `--no-cache` | 437.3G | 94.8 s | 2.6 GB |
| the same, warm | 81.5G | 19.0 s | 1.6 GB |

(E9, load 5-15, shared with other sessions. Warm equals cold byte for byte on
both. MLton's peak compile is 2.3-3.1 GB across these builds.)

### The language server

**Nothing on disk.** No code in `src/lsp` or the analysis engine names
`UnitCache`. The only file it writes is an opt-in profile log
(`lsp/profile.sml:4-5`). A reload loses everything, and
`Project.cacheDirectories` (`api/compiler.sml:112`) has no caller there.
`language-server.md:327-328` expected to reuse the frozen layer and the unit
cache; it was not built.

**Three workers a connection**, whatever the number of projects: `jobs`,
`basisJobs` and `workspaceJobs` (`lsp/service.sml:36-45`), routed by `lane`
(`:65`). Each runs `runevm --jit=opt --heap-limit 536870912`
(`lsp/server.sml:30`) under a 1.5 GiB address space (`lsp/jobs.sml:127`). A
job's deadline is 30 s (`lsp/service.sml:38-41`).

**No cut-off.** A unit is reused if the plan is unchanged, the prefix unbroken,
and name, `allow`, mode and text equal (`api/analysis-engine.sml:132-134`).
`prefix:=false` (`:137`) is never reset, so the first changed unit forces every
later unit. `Usage.record` runs (`:138`), but its result is not used for reuse.
In batch MLton's leaf costs 1 unit (`functors-units.md:120-122`).

**Contexts cannot share.** A context is keyed by build, target, library root,
bootstrap flag, flags and variables (`lsp/worker-analysis.sml:229-232`). What
blocks sharing is the per-session `stored` list (`api/analysis-engine.sml:21`),
the positional cursor (`:108,131`) and `unitName (file,rank)` (`:9,255`). The
chained `key` (`:127`) is not what blocks it: it is used for local type ids
(`:171`) and never read for reuse.

**Analysis identities cannot equal batch ones.** The unit's name differs
(`file#ordinal`, and Basis units by path, `:235`, where batch has `lib/...`).
`Env.tracking` is on only in analysis (`:89`), and origins enter the pickle.
Inline tables are not set: analysis calls only `language` (`:31`), and
`api/session.sml:65-81` sets them for a compile. Even with those fixed, a basis
holds the tables named under *Units and what is in one*, and analysis never runs
Translate, Lower or Expand. Every unit is also reloaded on every run, with no
known identity, so each is hashed again (`:206`, `unitbasis.sml:2929`).

**A front-only entry cannot save a later compile its elaboration:** the back end
starts from `decs` (`pipeline.sml:296`), which no entry keeps.

**Go-to-definition into a dependency needs origins,** which batch does not
record (`lib/compiler/elab/env.sml:41`, `api/analysis.sml:40-42`). Spans inside
the identity would make a moved definition change the unit.

**The prompt.** `W.select` looks at candidate count alone: none is Loose, one is
Selected, more is Ambiguous (`lsp/workspace.sml:197-208`). Ambiguous sends a
`window/showMessageRequest` (`lsp/controller.sml:48-60`), the rationale being D6
of `language-server.md:73`. A check then raises `ContextPending`
(`lsp/worker-analysis.sml:209`), so folding and selection wait too, and sweeps
drop the file (`:343`). Choices live in memory. It does not compare the
contexts. In this repo (E22, observed):
- 232 of 826 files have 2 or more candidates, and real divergence in binders is
  8 of them, `Config` from `build/config.sml` against `lib/compiler/config.sml`,
  and win32 32 and 64;
- prompts under discovery today: 210; on real divergence: 4;
- 118 of the 232 have a candidate that never reaches them;
- contexts compared by printed type look different when they are not: one type
  prints as `SML90.instream` or `TextIO.instream` by what `select` chose.

**Finding builds.** `RuneLspProjects.enrich` reads `*.build` directly in each
root and follows `use` (`lsp/projects.sml:38-47`, `lsp/workspace.sml:149-156`);
failing that, `discover` walks ancestors (`lsp/workspace.sml:157-174`). Nothing
scans descendants. Planning is where this goes wrong at scale. `enrich` calls
`configurationFor` (`lsp/workspace.sml:80-91`) once per URI
(`lsp/projects.sml:48-57`), and `enrich` and `W.select` read every target again
on every check. `enrich` took 21 s at 1,000 files and 10 builds, and more than
590 s at 10,000 and 100 (E20, observed).

**What it can hold** (E20):

| Workload | Stock | With caps lifted and the `Env.plus` fix |
|---|---|---|
| `rune.build`, 245 units | 455-465 MB in the 512 MiB heap, 12.4-16.1 s cold | |
| HOL4 closure, 746 units | dies at the deadline, 223 units | 53.9 s cold, leaf 11.8-20.9 s |
| MLton, 606 files | heap full at 26.5 s, 347 units | 235 s cold, leaf 72-78 s, 17.3 GB RSS |

The compiler itself retains 455-465 MB of a worker's 512 MiB heap, and peaks at
the cap. HOL4 and MLton had never been
through the server before this work.

| Cap | Where | Breaks at (E20, observed unless said) |
|---|---|---|
| 512 MiB heap | `lsp/server.sml:30` | 40k lines passes, 60k fails |
| 30 s deadline | `lsp/service.sml:38-41` | 1,000 files with one target: 25.6 s of planning first |
| VM equality work | `lib/compiler/syntax/incremental.sml:147` | one declaration of 14-28k lines: the VM aborts, uncatchably |
| 10,000 inputs | `api/analysis.sml:63` | 1.17M lines at 100 lines a file |
| 128 MiB of text | `api/analysis.sml:64-66` | not reached |
| 2 MiB retained source | `lsp/worker-analysis.sml:45` | by reading: at `rune.build`'s size one context, so switching builds re-analyses |

**What the memory is** (E20, the first breakdown, in process; MiB): `rune.build`
holds 426: syntax 226 (53%), typing 68-76, occurrences 52-55, facts 50, uses
17-21, pickles 2.9 (0.7%); the Basis's share is 55. HOL4 and the fixtures have
the same shape. MLton does not: 8,476, of which typing 58% and pickles 32%. At
measured density 10M lines would be 88 GB, more at MLton's; that is an
extrapolation.

**Time on a large unit.** `Env.plus` (`lib/compiler/elab/env.sml:131-136`)
filters every origin on every declaration, which only analysis has, so analysis
is quadratic in a unit's declarations: 7,000 lines in 4.1 s, 28,000 in 83.6 s
(E20, observed).

**Budgets are proposals.** `tests/lsp/baseline/2026-10-22-initial.json` proposes
250 ms for local diagnostics (`:321-327`); `language-server.md:1331` leaves
enforcement to a milestone not yet run. No scale target is stated anywhere in
that plan. A leaf diagnostic's p95 was 942 ms on `rune.build` on 2026-10-24, on
an older commit
(`rune-benchmark-results/lsp/2026-10-24-live-debug/latency-jit-opt/summary.json`,
outside this repo); E20 gives 1.1 s at 50k lines and 1.7 s at 117k.

**Loose files.** No candidate gives a context of one document, with its own
Basis prefix (`lsp/worker-analysis.sml:229,249-252`). `use` is unbound there,
and the first error hides the rest of the file (E22, observed). But top-level
`use` is in 1 of 3,955 tracked SML files. What matters more is that most of
those files are in no readable build (E22).

**Not there:** references and rename (`lsp/session.sml:76-98` lists no such
capability).

**`--serve`** (`serve.sml:17-21`) is a separate service: it forks a child per
request, which type-checks through both caches. `--typecheck-only` keeps the
cache lookup and skips storing (`main.sml:827`).

### Generated sources and HOL4

**`.build` has no step that runs anything.** None of its keywords runs a program
or a per-file preprocessor (`buildfile.sml:71-72`), and a plan is files and
scopes (`project.sml:5-9`). What is generated today is generated outside it:
- **`build/config.sml`** and `lib/compiler/config.sml`, by
  `scripts/gen-version.sh`, run from the Makefile. `build/config.sml` is the
  first file of `rune.build`, `runedoc.build` and `runelsp.build`.
- **FFI bindings,** by `runeffi`, as an explicit command (`runeffi.build:1-3`).
  The five sets live at
  `lib/ffi/sdl/generated/{native,windows32,windows64}/sets/HASH` and
  `lib/ffi/win32/generated/{32,64}/sets/HASH`. The hash covers `.build` text
  (`src/ffi/main.sml:113-117`; recomputed on all 5 sets in E28).
  `docs/plans/runeffi.md:253` calls them immutable. Regenerating costs 269.5G
  instructions, about 85 s, and the pinned Windows SDK (E28, observed). Nine
  builds reach a `current.build` by path variable or relative path.

**HOL4** (`corpus/hol4.md`, which still says `corpus/HOL`, `:3`) has three
parts.
- **Tools,** compiled by flattening an `.mlb` to a file list
  (`tools-rune/mlb-files.sh`).
- **Library code,** not all of it plain SML: every `.sml`, `.sig` and `.ML` goes
  through `QUse.use` (`tools-rune/buildheap.ML:316-318`). The quotation filter
  changes 13% of the library's files, none of the kernel's 18 (E8), and on the
  `src/boss` closure 36 of 745 files and 413 of 212,787 lines, every line count
  preserved (E20).
- **Theory scripts:** 334 in `src`, all with the `Theory`, `Ancestors` and
  `Libs` header, and 918 in `examples`, 17 with it. Each runs as its own process
  and generates `*Theory.{sml,sig,dat}`, which later code reads, some of it at
  load.

The graph is static. `tools/Holmake/Holdep.sml:45-58` maps `fooTheory` to
`fooScript.sml` by name, and the parser finds no `load` or `use` in 1,252
scripts (E9). Custom rules exist: in 86 of 108 Holmakefiles in `src`, 72 of 233
in `examples`, 53 of 83 in `tools`, mostly `selftest.exe`, heaps and opentheory
(E9).

**HOL4 through `.build` today** (E9, observed). The `src/boss` closure compiles
with no unit refused, once two base-image files no `.uo` names are added and
`.uo` paths are mapped; a main built on it loads every theory's `.dat` and
proves a goal. It skips what `.build` cannot say: the filter runs beforehand,
scripts are not run and theories are taken as given, `.dat` files are read from
an absolute `HOLDIR`, no heap is built, and `examples` is out.

**MLton through `.build` today** (E9, observed): 27 `.mlb` became 30 `.build`,
one for one, no renaming needed, 606 files as in the flat list. It type-checks
and takes `hi.sml` to C identical to the flat build's. The one fix was to hoist
`mlyacc-lib`, for the `use` difference under *The build language*. A shadowing
that still type-checked would have been silent.

## `.rune` and `lib/cache`, explained

**They are one mechanism used twice.** The same code (`UnitCache`, in
`unitcache.sml`), the same directory layout and the same entries. `.rune` is a
project's cache: a compile in units reads it and writes to it. `lib/cache` is a
cache that `make basis-cache` fills once, at the default settings, with the
libraries the compiler itself needs. After that nothing writes it, and every
compile reads it after its own. Three differences between them are essential.
The rest is history, and most of what goes wrong comes from the history.

Neither is touched by a plain `rune foo.sml`. A whole compile goes through
`frontEnd` and `backEnd`, and only `--units` or `--build` reaches the cache
(`main.sml:544`).

Paths are as in *Where we are*. Sizes and counts for `lib/cache` and
`build/.rune` are of the files in the reference tree, built at `b12141ecc`, read
with a parser of the entry format and no compiler. `lib/cache` is called the
*frozen* layer in the code.

### What a cache holds

A cache is a directory with this shape
(`unitcache.sml:143-150,220-221,327-329,402-405`):

```
DIR/                     .rune, or lib/cache, or --cache-dir's
  CONFIG/                one for each compiler and set of options
    KEY/                 one for each unit
      USAGES             one file for each set of usages: an entry
    units/
      about              what CONFIG is made of, as text
      HASH               one for each unit: the paths to its names
```

Each level answers one question.

- **`CONFIG`: did the same compiler, with the same options, make this?** It is
  the hash of `settings ()` (`unitcache.sml:124-141`): `Config.identity`, the
  cache, basis and unit-file versions, the instruction set, `-O`, `--passes`,
  `--int-bits`, `--flex-records`, `--overloading`, `--free-tyvars`, `--fuel`,
  the hash's probe, and both lists of inlining marks.
- **`KEY`: is it the same unit?** It is the hash of the unit's name, its text,
  whether it may use `_prim`, and for an input file the settings that hold for
  input files alone (`unitcache.sml:215-218`, `main.sml:641-654`). The name is
  in the key. So this is not a content-addressed store: the same text under two
  names is stored twice.
- **`USAGES`: do the units before it still say the same?** While a unit
  compiles, the compiler records each name it looked up and which unit bound
  that name. A later compile takes the entry if every recorded name is bound by
  the same unit, or by a changed unit whose fingerprint for that name is the
  same (`unitcache.sml:14-19`, `unitbasis.sml:1341-1353`). The file's name is
  the hash of that list (`unitcache.sml:404-405`), so one unit can have several
  entries, one for each set of usages it was compiled with.

The smallest real entry is `examples/hello.sml`'s, in `lib/cache`. It has four
usages:

| Usage | What it records |
|---|---|
| `v print` | the value `print`, bound by `lib/basis/pervasive.sml@5fcbd0cc...` |
| `inlv print` | that value's inlinable body, from the same unit |
| `fix print` | the fixity of `print`, bound by the initial basis |
| `o b5` | overloading at a built-in type |

If `pervasive.sml` changes in a way that keeps its basis, its identity stays,
these usages hold, and `hello.sml` is not compiled again. That is the cut-off.

An **entry** is one file (`unitcache.sml:45-47`) holding the usages, the
warnings the compile gave, the unit's basis (what later units are compiled
against), its code, its Mid, and some bookkeeping. It is written whole under
another name and renamed, so a compile running at the same time never sees half
of one (`:21-24,360-368`), and it carries a hash of itself, so a damaged one is
a miss (`:253-254`).

`units/about` lists what the configuration is made of, for `--explain-rebuild`.
Each other file in `units/` holds the paths to a unit's names. An entry compiled
against an old unit needs them to load against a new unit of that name
(`:322-329`, `unitbasis.sml:2622-2643`). The paths are found by unit name
(`unitbasis.sml:2632`).

**Nothing is ever invalidated, and nothing in a key is a time**
(`unitcache.sml:24`). An edit gives a new key or breaks a usage, and that is a
miss. The old entry stays, so undoing the edit finds it again (S5). The compile
reads and hashes each candidate entry in turn (`:264-307`).

### The two, side by side

| | `.rune` | `lib/cache` |
|---|---|---|
| **What it is** | a project's cache | a cache filled once, then only read |
| **Where** | `--cache-dir`, else `$RUNE_CACHE`, else `.rune` beside the first input (`unitcache.sml:183-194`); a build file's `cache` has no use | `cache` under `--lib` (`:201-208`): `lib/cache` in a checkout, `$prefix/lib/rune/cache` installed |
| **Code, layout, entry format, hit rule** | the same | the same |
| **Holds** | every unit a compile in units compiled | the Basis, `lib/compiler`, `lib/unicode`, `lib/json`, and `examples/hello.sml` |
| **Configurations** | as many as were ever used | two: the defaults, once per bytecode |
| **Entries per key** | one per set of usages | one |
| **Written by** | any compile in units (`main.sml:870-878`), not under `--typecheck-only` (`:827`), not where `--verify-cache` found a difference | `make basis-cache`, which is an ordinary compile with `--cache-dir lib/cache` (`Makefile:513-517`); then nothing |
| **Lint mark of its entries** | the level of the compile that made it | 2, the highest, so a compile at any level takes them (`unitcache.sml:57-58`) |
| **Read by the batch compiler, `--serve`** | first | second, on a miss (`main.sml:708-714`) |
| **Read by the REPL's `use`** | yes, alone (`src/repl/session.sml:266-270,324`) | no |
| **Read by the compiler library** | no | yes, alone (`api/session.sml:191-194`) |
| **Read by the language server** | no | no |
| **Goes stale** | never removed; a new compiler adds a new `CONFIG` beside the old | replaced whole: `rm -rf lib/cache` first (`Makefile:514`) |
| **Eviction** | none | not needed |
| **If it cannot be written** | a silent no-cache (`unitcache.sml:393-395,435`) | read-only on purpose (`scripts/install.sh:177`) |
| **Off with** | `--no-cache`, or an empty `$RUNE_CACHE` | the same (`unitcache.sml:202`, `main.sml:705-715`) |
| **In git** | ignored (`.gitignore:12`) | ignored (`.gitignore:13`) |
| **`make clean`** | `build/.rune` goes with `build/`; the others stay (`Makefile:2142-2144`) | stays until the next `make basis-cache` |
| **`make install`** | not involved | copied, read-only (`scripts/install.sh:173-178`) |
| **`make dist`** | not shipped, but see *Install and dist* | not shipped |
| **Size here** | `build/.rune`: 85 entries, 6.2 MB | 391 entries in each configuration: 17.3 MB and 14.2 MB |

### One compile, both directories

`rune --build runelsp.build`, from the root, after `make all`. This is deduced
from the code and agrees with the files in the reference tree.

1. The plan's files become the inputs (`main.sml:464`). The first is
   `build/config.sml`, so the cache is `build/.rune` (`unitcache.sml:192-193`).
2. The configuration is worked out once for the whole compile (`main.sml:605`).
   With no unusual flag it equals `lib/cache`'s register configuration.
3. Each unit is looked up in order, `build/.rune` first and `lib/cache` second
   (`main.sml:708-714`).
   - `lib/basis/list.sml`: not in `build/.rune`; `lib/cache` has one entry and
     its usages hold. It is taken.
   - `lib/lsp/uri.sml`: in neither. It is compiled and stored in `build/.rune`.
   - `src/lsp/profile.sml`: the same.
4. The next run finds everything, each unit in the directory that has it. A hit
   in `lib/cache` is never copied up.
5. The two are not independent. An entry in `build/.rune` names units in
   `lib/cache` by identity, and remapping reads paths from both
   (`main.sml:742`).

### What is in each today

**`lib/cache`** has two configurations, `60ce4d0e...` for the register bytecode
and `7b6b26fc...` for the stack bytecode. Their `about` files differ only in
`isa`. In each:

| Library | Units |
|---|---:|
| `lib/basis` | 278 |
| `lib/compiler` | 93 |
| `lib/unicode` | 17 |
| `lib/json` | 2 |
| `examples/hello.sml` | 1 |

That is what `--basis all --library compiler` closes over, plus the one input
the command needs (`Makefile:515-516`). The hello unit is a stray of that
command.

The register configuration has 17.0 MB of entries:

| Section | Share |
|---|---:|
| code | 47.7% |
| Mid | 29.7% |
| usages | 11.9% |
| basis | 7.1% |
| the rest | 3.6% |

Of its 41,143 usages, 19,576 are `fix`.

**`build/.rune`** has one configuration, the same `60ce4d0e...`, and 85 entries:
what `bin/runelsp.rbc` and the REPL's units needed and `lib/cache` lacked.

| Units | Entries |
|---|---:|
| `src/lsp`, `src/repl`, `src/driver`, `src/isa`, `src/opt`, `src/main` | 45 |
| `lib/terminal`, `lib/markdown`, `lib/pretty` | 16 |
| `lib/lsp`, `lib/jsonrpc`, `lib/digest` | 18 |
| `lib/compiler` | 3 |
| Basis seals | 2 |
| `build/config.sml` | 1 |

Two lines of that table explain how the layers meet.
- **Only three of the compiler's own files are there.** The REPL's list spells
  `lib/compiler/driver/deps.sml`, and that spelling is the library's logical
  name (`main.sml:569-574`), so the key matches `lib/cache`'s and the entry is
  taken. This is a coincidence of spelling, and it is what makes the compiler's
  cold build cheap. The three that remain, `link.sml`, `unitcache.sml` and
  `diagnostic.sml`, name `Config`, which `build/config.sml` binds here and
  `lib/compiler/config.sml` binds in `lib/cache`, so their usages fail.
- **Two seals are there.** A seal's usages depend on what the program names:
  `seal_string.sml` uses `Char`, which `seal_char.sml` binds where a program
  names `Char` and `char.sml` otherwise
  (`incremental-compilation.md:2633-2635`). So every Basis unit is frozen
  except for such seals (`docs/units.md:528-530`).

For scale: MLton's cold build takes 184 of its 791 units from `lib/cache` and
compiles 607 (E15).

### Why both exist

Both date from 2026-10-09, in `incremental-compilation.md`.

**`.rune` is D14.** The owner's brief for that roadmap asked for "a `.rune`
cache per source folder" (`:151`), and D14 chose "`.rune/` beside the sources by
default, and anywhere the owner says" (`:1885`). It wanted debug and release
side by side, a revert that finds its old entry, and a moved tree that costs
nothing (`:1901-1904,2077`). One cache per user, `~/.cache/rune`, was rejected
as the default and left to `--cache-dir` (`:1910-1913`). Timestamps were
rejected outright.

**`lib/cache` is D8.** The REPL needs one Basis shared by the compiler and the
user's code, and a small program should not compile the Basis. D8 planned it as
"a library file of export bases and unit bytecode (CM's stable library), shipped
under `lib/`, loaded by every compile", with MANIFEST's demand loading replaced
by the cache (`:1656-1658`). D14 called it "a cache entry that ships" (`:1908`).
What M6 built instead was `make basis-cache`: the Basis compiled once into a
cache directory, read after a compile's own (`:2630-2637`). That was 8 MB.
`--library compiler` came later, and it is 31.5 MB now, 38 MB on disk.

What it saves: on 2026-10-10 the whole Basis, compiled with no frozen layer,
took 4.38 s on a shared machine (`:3115`).

### Essential and history

**Essential.** There are three differences, and they are three faces of one: who
may write it, and for how long it is valid.
1. **Writable against read-only.** A project must be able to write its results.
   An install's library directory must not be written by a user's compile.
2. **Private against shared.** One serves a project. The other serves every
   program of one compiler.
3. **Many compilers against one.** `lib/cache` is valid for exactly the compiler
   that made it, so it is replaced whole, needs no eviction, and can sit beside
   that compiler in an install. `.rune` outlives compilers and holds whatever
   they left.

**History, or accident:**
1. **`.rune` sits beside the first input.** D14 said beside the sources, and the
   brief said per folder. What was built is one directory per compile, placed by
   whichever file comes first. Nothing asks for that.
2. **`lib/cache` is a directory of per-unit entries, not D8's single file.** So
   it carries what a cache carries: usages, Mid, paths, and a hello unit.
3. **Which libraries are frozen** is what one Makefile line closes over.
   `lib/lsp`, `lib/digest` and `lib/test/unit` are no less stable than
   `lib/json`, but every project that uses them compiles them into its own
   `.rune`.
4. **One configuration per bytecode.** Nothing says only the defaults deserve
   one.
5. **Which reader looks where.** The batch compiler reads both, the REPL only
   `.rune`, the compiler library only `lib/cache`, the language server neither,
   though `language-server.md:327-328` expected it to read both.
6. **Install ships it and dist does not.** No document gives a reason.
7. **The names.** `unitcache.sml:196` and `.gitignore:11` still say "frozen
   Basis Library", though it holds the compiler too. `docs/units.md:523` says
   "libraries".

The lint mark looks like a difference and is not one: any layer made at level 2
would have it.

### Why `build/.rune` exists

No rule names it. It is a side effect of three facts:
1. `.rune` goes beside the first input (`unitcache.sml:192-193`).
2. Under `--build` the inputs are the plan's source files, not the build file
   (`main.sml:464`). So the build file's own directory plays no part.
3. `rune.build:2`, `runedoc.build:2`, `runelsp.build:4` and `REPL_SRCS`
   (`Makefile:1442`) start with `build/config.sml`, because everything after it
   needs `Config` and that file is generated under `build/`.

So all four share `build/.rune`, by the accident of one first line. It happens
to work: their units share a cache, it stays out of the sources, and
`make clean` removes it. None of that is designed. Moved down a line,
`build/config.sml` would take the whole cache to `lib/unicode/.rune`
(`rune.build:4`). That is where `--build runeffi.build` puts it today
(`runeffi.build:3-4`). Deduced; neither was run.

### Install and dist

**`make install`.** `scripts/install.sh:173-178` copies `lib/cache` to
`$prefix/lib/rune/cache`, if `lib/cache/made` exists, and removes write
permission. The wrapper passes `--lib`, so `UnitCache.frozen` finds it
(`unitcache.sml:201-208`). It still serves after the move, because a library's
units are keyed by their logical name, not their path (`main.sml:569-574`), and
a hit renames its source to where it is now (`main.sml:755`). That is why an
entry can say `bin/../lib/basis/array.sml` in its `file` field and still serve
an install. Its entries serve only a compiler with the same `Config.identity`. A
host-built `rune` from the same sources has that identity, so it matches too,
unless its hash's probe differs (`unitcache.sml:120-123`).

**`make dist`.** `tools/builder/dist.sml:12-29` packs each library's MANIFEST,
sources and README, and the FFI assets. There is no `cache` in that list, and
`tests/runner/distchecks.sml:24,219` plants a `lib/cache/made` and asserts it is
not installed. So D14's "a cache entry that ships" holds for `make install` and
not for a release. A dist user has no frozen layer. Their first compile in units
compiles every Basis file it loads into `.rune` beside its first input, once per
project and per configuration (deduced; `unitcache.sml:208`).

**What a dist can ship by accident.** `--ffi-assets ffi` (`Makefile:2182`) packs
a directory tree with no filter (`tools/builder/dist.sml:80-82`,
`tools/builder/common.sml:47`), so `ffi/contracts/.rune` goes into the archive
wherever it exists, which it does in the owner's main checkout (deduced; no
archive was at hand to open).

### What goes wrong today

**1. The first file decides where the cache is.**
- `tests/lsp/worker.build` starts with `../../src/lsp/profile.sml`, so its cache
  is `src/lsp/.rune`, inside the server's source directory. Observed in the
  owner's main checkout: 32 entries, with names like
  `tests/lsp/../../src/lsp/build.sml`.
- A test's build leaves `ffi/contracts/.rune` the same way, with
  `tests/ffi/../../ffi/contracts/fixture.sml` in it.
- That checkout has `.rune` under `build`, `src/lsp`, `lib/random`,
  `tests/compiler`, `tests/lang`, `ffi/win32`, `ffi/contracts`,
  `tests/units/functor-earlier`, and throwaway ones under `tests/out`.
  `.gitignore:12` hides them all.
- Two builds of the same files with different first lines share no project
  cache. Reordering a build's first line starts a new one, without a word.

**2. One file has several keys.** The name in the key is the path as spelt.
- `src/lsp/profile.sml` under `runelsp.build` and
  `tests/lsp/../../src/lsp/profile.sml` under `tests/lsp/worker.build` are two
  units, in two directories, of one text.
- Even given one `--cache-dir`, `worker.build` after the root builds compiles 16
  units, and 1 would do (E16, observed).
- Spelling `rune.build`'s paths with `./` compiles 105 units where 0 would do
  (E16, observed).

*Units and what is in one* gives the condition for one file under two builds to
be one result.

**3. The frozen layer is all or nothing on configuration.** A compile with any
setting of `settings ()` other than the defaults has a `CONFIG` of its own,
misses every unit of `lib/cache`, and compiles the Basis into its project cache.
Nothing warns; `--explain-rebuild` says "no entry". By reading
(`unitcache.sml:124-141`, `main.sml:457-461,605`), that covers:
- `-O0` and `-O2`, `--passes`, `--int-bits=64`, `--fuel`;
- `--overloading`, which HOL4's branch sets on every compile
  (`docs/plans/hol4.md:81-86`), and `--flex-records`, `--free-tyvars`;
- an `inline functor` or `inline val` in a program's own build file, which
  changes the marks in the configuration, as
  `tests/units/functor-earlier/p.build` does.

**4. Libraries outside the closure are compiled per project.** `build/.rune`
holds 18 units of `lib/lsp`, `lib/jsonrpc` and `lib/digest`. Any project with
another first file compiles them again: in the owner's checkout `src/lsp/.rune`
holds 14 of the 18.

**5. `.rune` only grows.** There is no eviction, in the driver or the docs.
There is no sweeper for a `.tmp-` left by a crash; `find` just skips them
(`unitcache.sml:272`). Each compiler adds a `CONFIG`, and each edit a key.
- HOL4 reached 13,776 entries and 200 MB (`build-cache-issues.md:268-270`).
- `find` reads and hashes each candidate entry in turn, so entries per key cost
  linearly (`unitcache.sml:264-307`).
- Observed in the main checkout: `ffi/win32/.rune`, `ffi/contracts/.rune` and
  `lib/random/.rune` still hold configurations with 24-hex names, in an older
  format that no current configuration can reach. Only a person will remove
  them: `make clean` does not (`Makefile:2142-2144`).

**6. Four clients, four policies.** The table above has them. The language
server reads neither, so a reload rechecks everything, Basis included, though
the Basis is on disk already compiled. `Project.cacheDirectories` exists and has
no caller there (`api/compiler.sml:112`). The compiler library writes `.rbi`,
`.rbm` and `.rbs` beside its outputs, a fifth arrangement.

**7. A cache that cannot be written is silent.** A store that fails is dropped:
"a cache that cannot be written is a cache that is not there"
(`unitcache.sml:393-395`). A first input in a read-only directory means every
compile is cold and nothing says so (deduced).

**8. Both layers share the key's holes.** They have one mechanism, so they have
one set of faults: the settings in no key and the line of a copied function,
under *Units and what is in one*. A compile with `--functor-budget` also takes
`lib/cache`'s entries, made with the default (deduced for `lib/cache`; E18
observed it through a project's cache).

**What holds up.** Atomic rename and per-entry hashes (S33 to S35), a read-only
layer (S36), no locks, and a cache that stayed sound across a stale MANIFEST
(E2, observed). The format and the hit rule are not the problem here. Where the
entries live, what names them, and who reads them are.

What to do about all of this is D24.

## What the Definition says

The Definition of Standard ML (Revised, 1997) has no compilation unit, no
library and no linker. A program is one sequence of top-level declarations,
run in one session. Everything a build system does happens in a place the
Definition leaves to the implementer, and it says so in one sentence.

This section gives that sentence, the objects a build system must preserve,
the three contexts the text bounds or fails to bound, and what becomes of a
program after an uncaught exception. It ends with a table of what does not
mesh with separate compilation, which is the ground for D17.

Quotations are from the copy at `/home/ruud/The-Definition-of-Standard-ML-Revised`.
Section, rule and figure numbers are the book's. Pages are those of that
copy's `root.pdf`. The PDF that E25 read (from smlfamily.github.io) holds the
same text at other pages: Chapter 8 at pp.64-65, Appendix E at p.86, rules
87-89 at p.42, G.8 at p.110. The printed book was not checked.

### Many files

The Introduction states the model (§1, p.1):

> ML is an interactive language, and a program consists of a sequence of
> top-level declarations; the execution of each declaration modifies the
> top-level environment, which we call a basis, and reports the modification
> to the user.

Chapter 8 makes it a grammar, *program ::= topdec ; ⟨program⟩* (p.60), and
has the only passage on files (§8, p.60):

> In practice, ML implementations may provide a directive as a form of
> top-level declaration for including programs from files rather than
> directly from the terminal. In case a file consists of a sequence of
> top-level declarations (separated by semicolons) and the machine detects an
> error in one of these, it is probably sensible to abort the execution of the
> directive. Rather than introducing a distinction between, say, batch programs
> and interactive programs, we shall tacitly regard all programs as interactive,
> and leave to implementers to clarify how the inclusion of files, if provided,
> affects the updating of the static and dynamic basis.

Three things follow:
- **What a list of files means is the implementer's to say.** `.build`,
  `--units` and link order are each an answer to that last clause. None
  conforms or fails to conform by itself, but each must be written down.
  `docs/units.md:31-45` is Rune's answer today.
- **A file that stops is allowed.** "probably sensible to abort" covers a
  batch compiler, on a sentence that is only advice.
- **The only file the text imagines is a directive in a session,** which is
  `use`. A batch compile has no such thing: E7's `c05` gets `unbound variable
  or constructor: use`. So no rule about `use` is needed for a shared unit
  (E5).

It was not always so. The 1990 Definition offered a separately compilable
subset, and the revision removed it. Both passages survive in the copy's TeX as
deletions:
- Its §3.6, *Closure Restrictions*: "implementers who want to provide a simple
  facility for separate compilation may want to impose the following
  restrictions", because "they may ease separate compilation". It names the
  price too: they "may force the programmer to write many more sharing equations
  than is needed" (`synmod.tex:299-360`).
- Functor specifications, "useful, in fact essential, for separate compilation of
  functors" (`synmod.tex:100-118`).

The 1997 text records both removals. "Section 3.6 of the 1990 Definition has been
deleted." (G.16, p.108.) "SML '97 has neither functor signature expressions nor
functor specifications, since they could not occur in programs and did not gain
wide acceptance." (G.15, p.108.) A comment in the source, not printed, says of the
restrictions that "implementors never exploited them" (`whatisnew.tex:774-775`).
Elsewhere the words survive only in the history in Appendix F (pp.90-91) and in
the title of a reference. Blume's remark that the revised Definition "has dropped
every mention" of separate compilation of closed functors (thesis §7.2) stands.

So the Definition does not forbid a restriction, and it does not ask for one. A
restriction is the implementer's, and has to justify itself.

### What a build system must preserve

Execution is a sentence *s, B ⊢ program ⇒ B′, s′* (§8, p.61). Rule 189 gives
the step: each top-level declaration is elaborated and evaluated in the basis the
ones before it left, and the basis after it is that basis ⊕ what it gave. A
top-level declaration is a *strdec*, a *sigdec* or a *fundec*, each followed by an
optional *topdec* (Figure 8, p.15), under the restriction that "No topdec may contain,
as an initial segment, a strdec followed by a semicolon". So a `;` ends a top-level
declaration, and a file with no `;` is one.

The objects in that sentence are what a build must keep, in five parts:

- **The environment.** *B or T, F, G, E* (§5.1, p.32): type names, functors,
  signatures, and an environment of structures, types and values. Each
  declaration sees all that came before and names none of it. That is `.build`'s
  linear prefix, and the question of D2: nothing in the text says what a unit
  depends on. ⊕ also lets a later binding replace an earlier one without comment,
  so one name declared in two units is legal SML and an order-dependent build
  (S19).
- **Type names.** A datatype's names must be new: *t ∉ T of C* (rule 17, p.26);
  so must those of an opaque ascription (rule 53) and a functor application (rule
  54, p.35). New means new relative to a basis, and a unit compiled apart has not
  seen every basis it will end up in. Identity (O4) is what makes up the
  difference.
- **The state.** *(mem, ens) or s* (§6.3, p.42) threads through every declaration
  in order, and "each evaluation of a declaration of a exception constructor binds
  it to a new unique name" (§6.2, p.41). The order of effects is therefore the
  written order and nothing else. No rule licenses a reordering; a build that
  reorders must show it changes nothing (E6).
- **Identifier status.** The environment holds whether an identifier is a value, a
  constructor or an exception. Rules 34 and 35 turn a pattern `x` into a binding or
  a match, and "The context C determines which of these two rules applies" (p.29).
  So which identifiers a declaration binds is not a fact of its syntax (Elsman
  2008, §6.3).
- **Fixity, which is not in the basis.** "The scope of a fixity directive dir is
  the ensuing program text", with limits for `let`, `local` and `struct` (§2.6, p.7;
  §3.3, p.12), and "These directives and op are omitted from the semantic rules,
  since they affect only parsing" (§2.6, p.7). So the parse of one file depends on
  files before it, and the semantic objects have no place to carry that. Rune
  carries it beside the environment: a unit is parsed "with the fixity the units
  before left" (`docs/units.md:31-32`), and a usage covers it
  (`lib/compiler/driver/unitbasis.sml:1310-1314`). The graph does not: `Deps` parses
  with `Fixity.initial` (`src/driver/main.sml:235-236`).

### Three contexts, and where each ends

Three things are settled by context, and each could in principle wait for text
in another file. They differ in what the Definition says the context is.

**Overloading has a bound.** Appendix E, p.82:

> Every overloaded constant and value identifier has among its types a default
> type, which is assigned to it, when the surrounding text does not resolve the
> overloading. For this purpose, the surrounding text is no larger than the
> smallest enclosing structure-level declaration; an implementation may require
> that a smaller context determines the type.

A structure-level declaration lies inside one top-level declaration, and a file
is a sequence of those (§8, p.60). So a conforming resolution can never need
another file (deduced). Rune's four modes of `--overloading` hold to this and a
little more (`docs/language.md:31`): `declaration`, the default, is the bound;
`toplevel` and `topdec` are larger than the bound, and both stop at the end of the
file. E5's probe (`a3.sml`, `b3.sml`) confirms that overloading crosses a unit's
end in no mode. E5's rule for overloading is therefore vacuous: it holds by
construction.

**Flexible records have no bound.** §4.11, p.31: "the program context must
determine uniquely the domain" of the row type, "For this purpose, an explicit
type constraint may be needed". Nothing says how large the program context is.
Taken at its largest it is the whole program, so a record pattern in one file may
wait for a use in another. Rune's five modes of `--flex-records`
(`docs/language.md:32`) include that reading as `program`, which settles at the
end of a unit under `--units`; a program that leaves a record to a later file then
"compiles whole and not with `--units`" (`docs/units.md:42-45`). E5's probe
(`a1.sml`, `b1.sml`) observed exactly this. The default, `topdec`, ends at a `;` or
the end of a file. Nothing here depends on `program`: of the 2,085 programs E5 ran
(regressions, `tests/lang`, `tests/errors`), none passes only with it
(`results/E5/elab/rows.json`). Each of those is a single file, so this counts what
crosses a `;`, not what crosses a file.

**Free type variables end at a top-level declaration.** Rules 87 and 89 (p.40)
require *tyvars B″ = ∅*, and the comment says "No free type variables enter the
basis". G.8 (p.106) gives two ways to meet it:

> It is possible to satisfy this side-condition by replacing such type variables
> by arbitrary monotypes; however, implementers may instead choose to refuse
> elaboration in such situations.

Both settle at the end of the top-level declaration, so both end at a unit's end if
a unit's end acts as a top-level declaration's. Rune's `refuse` (the default),
`monotype` and `dummy` do (`docs/language.md:33`). `later` and `later-monotype`, the
readings of MLKit, Moscow ML and MLton, wait for a use further on, which a program
compiled whole can give and a unit cannot: E5's probe (`a2.sml`, `b2.sml`) is
accepted whole and refused under `--units`. Single files show how much relies on
it. 13 of the 1,514 regression programs pass only with `later-monotype`. In
`tests/lang`, 2 of 361 do, and both are tests of the modes (E5).

So in the default modes none of the three crosses a unit's end, and `docs/units.md:41`
states it: "So nothing of a unit waits on the units after it." The modes that cross
are accepted whole and refused in units, which breaks S42 for such a program by
design. They are a reason to keep those modes out of builds, not a reason for a rule
on shared units.

E25 found no SML author who names overloading or flexible records as an obstacle to
separate compilation (*What the literature says*). That is the same result from
the other side. E5 agrees with it, and neither is a rule D17 needs.

### Programs and sessions

Chapter 8 goes on after a failure (§8, p.61):

> It must be understood that executing a program never results in an exception. If
> the evaluation of a topdec yields an exception (for instance because of a raise
> expression) then the result of executing the program "topdec ;" is the original
> basis together with the state which is in force when the exception is generated.

Rules 187-189 give the three cases, each followed by the rest of the program. Rule
187: "A failing elaboration has no effect whatever." Rule 188: an exception
"nullifies the change in the static basis, but does not nullify side-effects on the
state".

That is a session. It is not what a built program does, and Rune says so as a
deviation: "Rune is a batch compiler: a static error in any top-level declaration
rejects the whole program, and an uncaught exception terminates it"
(`docs/language.md:29`). The sentence on files in §8 is what permits it. SMLSC does
the same: its rules "evaluate the units in a program in sequence, stopping on
uncaught exceptions" (§5.4).

The REPL keeps the Definition's behaviour (`docs/language.md:30`, `docs/repl.md:296`,
`:311-319`). Observed in E7's `c07`, three declarations with a `raise` in the second:
whole prints `one` and exits 1, `use` does the same, and text typed at the REPL prints
`one`, then `two`. So D17 can leave a shared unit to the batch reading without taking
anything from the language: the Definition stays whole where it was written for,
in a session. E7 measures that claim.

A topdec's end has one more consequence. Splitting a file with no `;` into a `;`
after each declaration makes a different program under the Definition, not a
deviation: three programs of `tests/lang` are refused that way and accepted as written
(E7). Concatenating two files with no `;` between them is the reverse: two top-level
declarations become one. So the statement "units in sequence mean their concatenation" (O8) has to say that a `;`
stands between units. Rune's whole compile treats a file's end the same way
(`docs/units.md:38`).

### What does not mesh with separate compilation, and what each needs

"Needs" is what the feature needs for the mechanism named. Unless the row says
otherwise, nothing is needed for correctness: with written order a unit that fails a
rule costs speed, never correctness (E25, E5). Named by: A&M is Appel and MacQueen; CM
rule n is item n of `smlnj/doc/src/manuals/cm/02-cm-model.tex:129-141`.

| Feature | In the Definition | Named by | Why it does not mesh | What it needs | Observed in Rune |
|---|---|---|---|---|---|
| Effects in order | Rule 189; the state threads through (§8, §6.3) | SMLSC §1.2; Blume §2.2 | Dependence on an effect is not in the text, and two orders that agree with every name can differ | Written order, or a named edge. Needed by any reordering, `-j` output order and closures | E6: bytes of a unit did not depend on legal order, on the 2-3 orders tried, once names are unique; only HOL4's output does, 2 probe lines (`Theory.ancestry`, `srw_ss` fragments). No cheap static proxy |
| The basis as a prefix | Rule 189: each topdec sees all before it | SMLSC §2 (TILT's default is the same) | A unit says nothing of what it needs | Nothing for correctness. For speed, D2's closures, which need the rows below | E5: each unit compiled from its closure alone: Rune 22 of 22 byte-identical, HOL4 28 of 30 sampled, and the other two once a duplicate `Systeml` was removed, by the report, that rerun's output not kept; none refused; HOL4 needs one added edge from `Overlay.sml` |
| One name bound twice | ⊕ in rule 189 replaces silently | Blume Claim 1, Restriction 1; CM rule 2 | Which binder a use means depends on the order | One definer per scope, not per group | E6: the only cause of unit bytes changing (S19): `Systeml`, `lcss-nofib-*`. MLton has 17 duplicate names across `library` scopes, legal by scope (E8) |
| Top-level `open`, datatype replication | Rules 22 and 18 (p.26): bindings the text does not show | Blume §4.2, §4.5; CM rule 4 | Uses cannot be resolved from syntax; unrestricted, finding an order is NP-complete (Claim 3) | Not at the top of a shared unit; a prelude unit otherwise | E8: 0 of the 635 shared units of HOL's library in the closure, 0 of 1,179 in all of `src`. HOL's one case is `src/thm/Overlay.sml:42,49`, its kernel seal, a prelude unit |
| Top-level values, exceptions, datatypes | Any *dec* is a *strdec* (Figure 6, p.14) | A&M footnote 4; CM rule 1 | A use of a value names no module (`docs/units.md:575-584`) | Not at the top of a shared unit, for dependency order and closures only | E5: warm cut-off needs no such rule. E8: shared units that fit: Rune's compiler 84 of 84, MLton 599 of 599 |
| Fixity | §2.6, §3.3: scope is the ensuing text; not in the basis | SMLSC §2 | The parse of a unit depends on earlier files | An export, or a prelude property: "must be activated when opening a unit" (SMLSC §2) | E8: 142 of 746 HOL closure units parse differently without carried fixity. `rune --deps` stops at `Conv.sml:205:6`. HaMLet's `Syntax.sml`: 27 units depend on it |
| Identifier status | Rules 34, 35 (p.29) | Elsman 2008 §6.3; Blume §3.6 | Binders cannot be told from uses without the basis; `val y = x` loses the status | The static layer holds it; a syntactic graph needs the discipline above | No experiment isolates it. `Deps` avoids it by refusing top-level datatypes (`lib/compiler/driver/deps.sml:196-197`) |
| Transparent ascription, structures with no signature | Rule 52 (p.35): the result keeps the realisation | A&M §2; Leroy §1.2; Cardelli Day 3; HOPL §5.7 | A signature is not the whole interface | Only compiling against an interface alone, which is a firewall. Not cut-off | E5: a signature on each shared structure is for firewalls only. A private change behind `:>` still recompiles a client today. Shape (`:>`, `:`, bare): Rune 161, 124, 247; HOL closure 340, 2, 48 |
| Interfaces no source can write | `local datatype t = A in val x = A end` is legal | SMLSC footnote 1, rule 99; Harper and Stone | An inferred interface has no written form | Inferred interfaces in written order: harmless. Written ones alone cannot cover it, so D8's check on this is a lint | E3: a private type through an exported signature works unnamed, and naming it is refused |
| No functor specification | Removed: G.15 (p.108) | SMLSC Figure 6 | A client cannot be compiled before the functor's body | A signature for functors: D22 | E10: changing a body already leaves a client alone; changing the result recompiles it |
| Signatures and functors only at top level | Figures 6 and 8: a *strdec* holds no *sigdec* or *fundec* | SMLSC footnote 2; Elsman 2008 §2 | A unit is not a structure, so a library cannot be wrapped in one | Namespaces outside the language: bounds D9 | Not measured |
| Overloading | Appendix E (p.82): bounded by a structure-level declaration | Cardelli Day 1, generically; no SML author | It does not fail to mesh: a unit's end cannot cut the context | Nothing | E5: crosses in no mode |
| Flexible records | §4.11 (p.31): "program context", no bound | No SML author | Only the reading that takes the whole program | A unit's end ends the context; `program` stays out of builds | E5: whole accepts, `--units` refuses. 0 of 2,085 pass only with `program` |
| Free type variables | Rules 87, 89 (p.40); G.8 (p.106) | E25, from rules 87-89 | Only the readings that look past a top-level declaration | A unit's end ends a topdec; `later` and `later-monotype` stay out of builds | E5: whole accepts, `--units` refuses. 13 of 1,514 regression programs, in single files |
| A topdec's end | Figure 8; §8: a `;` ends it | E7 | A file with no `;` is one topdec, and two such files concatenated are one too | A `;` stands between units: O8 says so | E7: 3 programs of `tests/lang` differ if split at each declaration |
| Going on after an exception | Rules 187-189 | E7 | A session, not a built program | Stop at the first uncaught exception; the REPL keeps the rules | E7: `c07` as above. Documented, `docs/language.md:29-30` |
| `use` | §8: a directive, not in the grammar | E5 | A file read while running is outside any graph | Nothing: batch has none | E7: `c05` is unbound in batch. Rule dropped (E5) |

### What this gives D17

- **The Definition asks a build for one thing:** a meaning for a list of files. A
  written order of units gives it: each unit's end a topdec's end, and the program
  their concatenation with a `;` between. O8 states that and E7 and S42 check it.
- **It asks for no restriction.** The rules of CM and `Deps` come from the rows on
  names, `open`, fixity and top-level values, and those rows are about finding an
  order or a closure from syntax. A unit that breaks one falls back to the linear
  prefix and loses speed.
- **Overloading, flexible records and free type variables need no rule in the
  default modes.** They need one statement: modes that wait past a unit's end stay
  outside builds.
- **What does need a position:** fixity (an export or a prelude unit), one definer
  per scope, and a way to name a dependence on an effect. E8's exceptions in the closures are all one
  thing, a prelude unit that defines the language for those after it: HOL4's
  `Overlay.sml`, the Basis's `always` files and HaMLet's `Syntax.sml`.
- **The REPL keeps the whole Definition,** because Chapter 8 describes the REPL.

## What the literature says

The papers answer six questions in turn: what a separately compilable unit is;
why the classic restrictions exist; what makes reuse sound; what may cross a
boundary; what Backpack actually shipped; and what a build system is, as a
thing with a correctness statement of its own. The argument of this section is
that SML's obstacles to separate compilation are real, but they are not where
the folklore puts them. A unit can be any sequence of declarations. The
restrictions are for finding an order, not for meaning. Reuse has a proof, and
its premises are the obligations of *What a cache hit must satisfy*.

E25 read the papers. Every DOI was checked against Crossref on 2026-11-01.
Quotations come from the versions in the table below, not always from the
published text. The notes, with the texts, are in the drafts (`results/E25/`).

| Paper | Version read | What was read |
|---|---|---|
| Appel, MacQueen, PLDI 1994 | Princeton CS-TR-452-94, 15 March 1994, headed "To appear". ACM refused the published text | All |
| Leroy, POPL 1994 | Author's copy, proceedings pagination | §§1-2; §§3-5 skimmed |
| Cardelli, POPL 1997 | Author's copy | §§1-2, 9, the theorem statements |
| Blume, thesis, 1997 | Princeton PhD thesis | Chapters 1-4 and 7 |
| Blume, TOPLAS 1999, and Blume, Appel, TOPLAS 1999 | **Neither seen.** The thesis's chapter 4 and Princeton TR-555-97 stand in for them | As above; the report |
| Swasey et al. (SMLSC), ML 2006 | CMU-CS-06-104, a working draft of 28 January 2006. **The ML 2006 text was not seen** | All |
| Elsman, 2008 | IT University of Copenhagen report, April 2008 | All |
| Elsman, ICFP 1999 | Page images: the PDF's fonts are broken and there is no OCR here | **pp.1 and 11 only** |
| Shao, ICFP 1998 | Page images, for the same reason | **pp.1, 10 and 11 only** |
| Harper, Stone, 2000 | Author's preprint | The sections on generativity and scope escape |
| Dreyer, Rossberg, ICFP 2008 | ICFP paper. The TOPLAS 2013 version was downloaded, not read closely | §§1-2 |
| Kilpatrick et al., POPL 2014 | Authors' copy | §§1-2 |
| Yang, thesis, 2017 | github.com/ezyang/thesis, release "final" | Chapters 1, 8, 9.1, 10.3-10.5, 11; §2.3; the end of chapter 7 |
| Mokhov et al., ICFP 2018 | Published text | §§2-4, 6 |
| Mokhov et al., JFP 2020 | Published text | §§7.3-7.5 |
| MacQueen, Harper, Reppy, HOPL 2020 | Published text | §5.7 |
| Flatt, ICFP 2002 | Author's copy | The introduction |
| Bour et al. (Merlin), ICFP 2018 | arXiv 1807.06702 | §2 |

So a claim below about Shao or Elsman 1999 rests on those pages alone, and one
about Blume's TOPLAS papers rests on the thesis. Nothing here reports the
unread middle of any paper.

### What a separately compilable unit is

Three answers, and the difference between them is what a client may see.

**Appel and MacQueen take the liberal view,** and it is the one Rune has: "a
compilation unit is a single source file containing any sequence of ML
declarations" (§3). They do not claim to have separate compilation.
"Classical separate compilation is not possible for ML, or any language with
inter-implementation dependence" (§1), because a transparent signature lets a
client depend on what lies behind it: "It is not always possible, in our system,
to compile a module in vacuo, without seeing all of the modules it imports". What
they built "is better termed an incremental recompilation system". The term of
art has been honest since 1994; "separate compilation" in SML usually means
incremental recompilation. Their footnote 4 recommends structures, functors and
signatures only, "but not top-level values and types". It is a recommendation,
and their own compiler manager's requirement, not a condition of the semantics.

**Leroy locates the obstacle in the language.** "SML signatures are not complete
specifications with respect to typing" (§1.2), since type specifications are
transparent. "Hence, typechecking and compilation must be done in bottom-up order,
just as in a toplevel-based approach." He reads the Definition as we do: SML "makes
no provision for separate compilation" (§1.1). His fix is a change to the language,
manifest types, with compilation units as "an additional layer on top of modules".
That belongs to Rune 2, not to this roadmap. His point stands for Rune 1: interfaces
that fully describe a unit do not exist in SML '97, so a build must either see through
them or give something up (D18).

**Cardelli gives the statement that the other two lack.** A fragment "cannot be
compiled (or typechecked) in isolation, but it can be compiled in the context of
adequate information about missing fragments" (§2.1). Interfaces are "typing
environments that are intrinsically external to the programming language" (§1).
Two of his obstacles matter here:
- Day 3: "Even when it is possible to typecheck MUsr purely against ILib, it may be
  that ILib does not convey all the information necessary to produce a linkable image
  LUsr. For example: the compiler may insist on performing global flow analysis, or
  some routines of ILib may require inlining, or the layout of opaque types in ILib
  may have to be determined." This is D1's reason for separating a static layer from
  an ABI layer. It also says why a static hash alone cannot be a firewall.
- Day 5: "The linked program should have the same effect as a program obtained by
  merging all the sources together and compiling the result in a single step. Such a
  merging of sources is not often characterized; then the semantics of linking is
  undetermined." This is S42, and O7 and O8, stated in 1997. *What the Definition
  says* gives the merge for SML: the units in order, with a `;` between.

His theorems 7-3 and 7-6 prove separate compilation and merge for a first-order
language with no SML in it, so they are a model of the statement, not a result about
Rune.

### Restrictions serve inference, not correctness

The restrictions everyone remembers come from one question: how to find an order
when nobody wrote one down.

Blume proved the question hard. "With multiple top-level definitions for the same
identifier the problem of finding a feasible ordering is NP-complete" (thesis, Claim
1). With `open`, it stays NP-complete even when multiple definitions are prohibited
(Claim 3). Under two restrictions the answer is unique: one definer per group, and no
`open` at top level (Claim 4). CM imposes them, and says why: "if one does not enforce
certain restrictions, then dependency analysis is intractable" (§2.2). Datatype
replication joins `open` as a binding "not lexically apparent" (§4.5). Elsman adds that
syntax alone is not enough even then: "source code dependency analysis for Standard ML
is possible only by integrating the dependency analysis with a kind of elaboration so
as to determine which identifiers have constructor status" (§6.3).

SMLSC starts from the other end. Units are "any sequence of top-level bindings,
including signature and functor declarations", and the order is written. Its §1.2
gives the reasons, and the second one is the finding for D17:

> The chief reason for this is that dependencies among units may not be syntactically
> evident—for example, the side effects of one unit may influence the behavior of
> another. Moreover, there are, in general, many ways to order effects consistently
> with observed dependencies, and these orderings need not be equivalent. A lesser
> reason is that supporting dependency inference requires restrictions on compilation
> units that are not semantically necessary, reducing flexibility.

So:
- **Written order needs no restriction.** Blume's rules say which order to use, and
  with a written order that question does not arise. E5 agrees from the other side:
  warm cut-off needs no rule, and no unit was refused when compiled from its closure.
- **Inference cannot see effects at all.** CM disclaims them: "It is up to the
  programmer to make sure that the ordering of side-effects is either unambiguous or
  unimportant" (§2.2). That is the stronger reason, and E6 measures it for SML: only
  HOL4 shows a hidden dependence on an effect.
- **The default of the proposal that writes the order is the linear prefix.** Omitted
  opens mean "every unit declared to that point in the assembly file" (SMLSC §2). That is
  today's `.build`. Closures (D2) are an optimisation of it, licensed by a checker, and
  not a meaning of their own.

What remains of the restrictions is real but different. Written interfaces cannot cover
everything: "since Standard ML lacks syntactically expressible signatures, some units
cannot be separately compiled from one another" (§1.2), as `local datatype t = A in val x
= A end` shows (footnote 1; Harper and Stone treat the same escape). That limits
compiling against a written interface, not reuse. And fixity is forced on any design
that splits a program between declarations: "the fixity information in any interface
must be activated when opening a unit so that parsing of its dependents is performed in
a manner consistent with integrated compilation" (§2). SMLSC argues this informally: "we
do not give a semantics to fixity declarations".

None of the SML authors read names overloading or flexible records as an obstacle: not
Appel and MacQueen, Blume, SMLSC, Elsman 2008 or Harper and Stone, nor HOPL's section on
the subject. Cardelli names overloading generically, among features that "may require
global analysis" (Day 1), and again at Day 7, for Java. The claim is about the texts in the
table. Shao and Elsman 1999 could not be searched, and E25's note on SMLSC marks its silence
as something to check against the published paper, which was not seen. *What the Definition
says* gives the reason it holds for overloading.

Blume's conclusions go to Rune 2. He asks that `open` be replaced by "the equivalent of
Modula-3's IMPORT", and recommends "against any language construct that can cause a change
of a definition in one part of the program to modify scopes in another part of the program"
(§7.2).

### Cut-off, and what makes reuse sound

Appel and MacQueen give the mechanism. Make a unit's identity a hash of its exported
static interface, and an edit that leaves the interface alone leaves the identity alone:
a bug fix goes through "without causing a cascade of recompilation" (§5). Nothing needs
to be compared but hashes: "we compare hash values and not full environments". The
hasher "must 'alpha-convert'" the names a compile makes, or the result is "dependent on
the number of hidden internal structures and types". Their warning about the pickle is
also Rune's: "The most troublesome and time-consuming part of the implementation" was
sharing, across "all the 115 variants in 36 data types" (§4).

Elsman 2008 gives the proof, and states what the proof assumes. Each translation step of
a compiler has the form E ⊢ p ⇒ ∃N.(E′, p′): in environment E, unit p translates to
target p′ and exports E′, generating names N. Four properties are assumed of every step
(§3.2). Compilation is their composition, a basis being a sequence of per-phase
environments. A repository holds, per unit, its import basis, source, names, export basis
and code. It is *well-formed* if each entry is a derivation and its import basis is
restricted to the unit's uses. Reuse is one line (§5): the stored source equals p, and
the current basis enriches the stored import basis. Theorem 1 then says the result does
not depend on whether repository judgements were used, and Corollaries 1 and 2 give
soundness and completeness against compiling from an empty repository.

Those premises line up with the obligations of *What a cache hit must satisfy* (O1-O9).
The pairing below is this roadmap's reading: Elsman does not know them, and D20's table groups
Properties 2 and 3 together where this one gives each its obligation.

| Elsman 2008 | What it says | Obligation |
|---|---|---|
| Property 4, deterministic | Two derivations from E and p give equal results, up to renaming of bound names. "It is this last property that guarantees completeness" | O1 Hermetic |
| Property 3, closed under restriction | A step depends only on the assumptions for what occurs free in p | O2 Usages suffice |
| Property 2, closed under enrichment | A step gives the same result in any environment that enriches E | O3 Fingerprints suffice: a usage that holds is enrichment, checked by hash |
| Property 1, name relations | Generated names are declared; part 4 says a target's uses stem from the source's uses through E | O4 Identity. Part 4 also carries O2 through the phases: the proof of Proposition 3 rests on it |
| Well-formed repository | Each entry is a derivation, with its import basis restricted to its uses | What an entry is. E18's mask tests the second half |
| Theorem 1, Corollaries 1, 2 | Reuse gives the result of compiling from scratch, and compiling in any well-formed repository gives the same | The claim itself, checked as S41 |

"It is the combination of Property 2 and Property 3 that allows the result of compiling a
program unit to be reused." That is the one-line argument of *What a cache hit must
satisfy*, with its two halves named. Three differences matter:
- **Elsman assumes per phase what Rune has only as a whole.** His restriction follows
  names through the phases, step by step. Rune's reads are spread through every pass,
  and the key is kept by hand. His form, stated for each of Rune's phases, is what D20
  should ask for.
- **He leaves out what Rune finds hard.** O5 (load), O6 (remap) and O9 (sessions) have no
  counterpart: the repository holds semantic objects, and serialisation is §6's
  implementation matter. O7 is Cardelli's and O8 the Definition's.
- **The proof is about reuse, not about the passes.** On inlining: "soundness of the
  actual in-lining procedure must be established outside of the framework" (§3.2). That
  is `soundness.sml`'s limit too: it is relative.

The cut-off itself is an implementation detail in §6.4. If matching gives an export basis
identical to the stored one, serialisation is avoided, "which leaves intact the time stamp
of the file containing the export compilation basis". The implementations section shows
what became of that (*The warm path*).

### Typed cross-module information

What may cross a boundary is wider than types, and the systems that optimise across units
all see through opaque ascription to do it.

Shao's `binfo` puts binding information in signatures. Each value carries Dyn, STFun(e) or
STVal(c), and "Signature matching on binfo is always transparent" (§4, p.10). The result
is "a near optimal cross-module compilation framework" (abstract). What he implemented was
smaller: it "currently only inlines and specializes all the primitive functions", though
it replaced an algorithm "which does not even propagate inlining information across
signature matching" (§5, in SML/NJ since 109.24, January 1997). On opaque types, he
erases: abstract types become stamps annotated with their representation, and the
translation drops the stamps. "This method does not propagate abstract types into the
intermediate language but is sufficient if the underlying compiler does not analyze
abstract types" (§5). Rune sees through in the same way: `shapeOf` follows a realisation
(`lib/compiler/core/ty.sml:478-486`), and a realisation is part of what a usage covers
(`lib/compiler/driver/unitbasis.sml:486-488`). His related work names the
tension at the heart of D18: fully transparent modules "interact poorly with true
separate compilation", and yet "full transparency is important in providing optimal
support to efficient cross-module compilation" (§6, p.11).

Elsman 1999 goes further and removes the module level. Functors are elaborated when
declared, so type errors come early, but "code generation for the functor is postponed
till the functor is applied" (§1). Region inference needs it: the technique "makes
available (for the compiler) the exact definition of abstract types" (§8). The cost was
small on the Kit: "only six of the 138 functors" were compiled more than once, and the
compiled lines grew by "only 10.9 percent" (§6), on about 87,000 lines. Rune compiles a
functor once (`docs/language.md:28`), so this is not Rune's cost. The point for D18 is that a
system which depends on exact abstract types gave up separate code generation for functors,
and stayed practical on one real compiler.

Elsman 2008 generalises what crosses: the framework "allows arbitrary compile time
information to propagate across program unit boundaries", open terms included. It also
says how heavy that gets. Elaboration information is "only five percent" of a compilation
basis, because region type schemes dominate (§6), and §6.1 calls 4.0 seconds to deserialise
the Basis Library's bases, on a 2.8 GHz Pentium 4, "still too costly for ordinary use". §6.3 answers with layers:
elaboration bases for every dependency, compilation bases only for the units actually
referred to. That is D1's argument from experience, in an SML compiler.

### What Backpack shipped, and what it did not

The brief recalls Backpack as never implemented because type classes are anti-modular. E25
finds otherwise on both counts, and the true story is the useful one.

- **Backpack'14 could not be implemented, for a different reason.** "The semantics of
  Backpack'14, especially its package-level semantics, were closely entwined with the
  semantics of Haskell itself, violating the traditional abstraction barrier between the
  compiler and package manager" (Yang, ch.1). The POPL 2014 design was read only in its
  first two sections, so this rests on Yang's account of it.
- **Backpack'17 shipped.** "Backpack has been fully implemented in the upcoming GHC 8.2 and
  cabal-install 2.0 releases" (ch.1). It splits the work: "mixin linking which is indifferent
  to Haskell source code, and typechecking against interfaces, which is purely the concern
  of the compiler". Its tests are in `ghc/testsuite/tests/backpack`: 61 should compile, 56
  should fail, 14 should run, 12 reexport.
- **What shipped is separate type-checking, not separate code generation.** "Instead, every
  distinct instantiation of a component is compiled against the code that implements its
  requirements" (§2.3). So users "pay no performance penalty", "because we don't do separate
  compilation of Backpack'17" (§10.5). This is Elsman's static interpretation and MLton's
  whole program, reached from the Haskell side. In Backpack a signature buys checking, not
  code. Rune compiles a functor once, so D22 has a different question to answer about code
  (E10).
- **Type classes make a theorem false, not an implementation impossible.** "The soundness
  result we desire is not true for full Haskell, and in fact, it cannot be made to be true as
  Haskell exists today" (§9.1.1). It shipped regardless, on "an unsound but pragmatic
  mechanism" (ch.1): "the social rules of Haskell allow us to maintain modularity and separate
  compilation". The soundness of compiled code reduces to GHC's, "because we retypecheck and
  compile every instantiation of a component" (§9.1). The rest is conjecture: "we can only
  conjecture" the result even without type classes and type families. "Anti-modular" is
  Yang's own word for them (ch.11).

Two smaller lessons carry over:
- **A negative result on the standard library.** Yang's team "were unable to parametrize the
  array package over base", because language features pick an implementation "bypassing the
  import mechanism" (§8.2). Rune's wired-in names will do the same to a Basis view (D12).
- **What the barrier costs.** Yang's conclusion lists where the abstraction barrier fails. One
  case is exactly D26's: IDEs "cannot invoke the compiler directly, because the only way to
  invoke the compiler with the right flags and the right environment is via the build
  system/package manager" (ch.11). A plan as a value (D5) is one answer to it.

On uptake the sources are participants, so this is opinion, not measurement. Yang wrote that
"The true test of Backpack'17 will be whether or not the larger Haskell community adopts it"
(ch.1). In 2021 he gave as the biggest reason it had not taken off that "no one is working full
time on it" (Haskell Discourse, thread 2499). A 2023 proposal opens "Backpack is not used much"
(thread 6739). Stack's release-candidate notes for v4.1.0.1 add cross-package support; whether
that release shipped as stable was not confirmed.

### Build systems

Mokhov, Mitchell and Peyton Jones give the vocabulary and, more usefully, a correctness
statement that does not mention SML at all.

- **Correctness** (Definition 3.1, ICFP 2018). A result is correct if the inputs were not
  corrupted and, for every non-input key, recomputing its task from the result gives the value
  stored. S41 is this, for Rune's store.
- **Static dependencies come from running the task differently** (§3.7). An applicative task
  yields its dependencies with no store and no inputs, by running it at `Const`. So a plan can be
  extracted without doing the work. This is the formal version of D5's plan and D29's phase
  separation.
- **Early cut-off needs a choice of trace.** Deep constructive traces, which hash only terminal
  inputs, "cannot support early cutoff" beyond n levels (§4.2.4), and they require deterministic
  tasks. They are what holbuild uses (*The warm path*). A unit's usages are a trace recorded by
  running the task, and the store keeps the result with them: a constructive trace, which does
  support cut-off. That classification is deduced here; the paper does not discuss Rune.
- **Determinism is not free once entries are shared.** Figure 11's *Frankenbuild* gives a result
  inconsistent with its own dependency, because a non-deterministic task met a deep trace. §6.4
  also relaxes Definition 3.1 for shallow builds, which materialise only the end products, and
  notes that evicting a value can evict every trace that mentions it (D24).
- **Self-tracking.** "The build systems that have precise self-tracking are all ones which use a
  non-embedded domain specific language to describe build tasks. Those which use a full
  programming language, e.g. Shake, are faced with the challenge of implementing equality on
  arbitrary task functions" (§6.5). So a plan compared by value has what an SML build program
  would have to earn. Blume, of keeping CM's impact on the language small: "I was not able to
  make it zero" (§7.2).
- **Sharing exposes what was undeclared.** From the JFP version, §7.4: "most issues encountered
  during the move to cloud builds for GHC were caused by failing to declare produced files", and
  "Irrelevant differences": paths recorded by the build mean users "will not share cache entries".
  The first is D16's reason to declare outputs. The second is D3's.

Flatt's introduction states D29's risk in a sentence: mingling compile-time and run-time values
"breaks programming tools that must parse code without executing it", and the fixes by annotation
are "fragile". The cure there is a separation the system enforces.

### What this means for the roadmap

- **D1:** Cardelli's Day 3 says what a static layer cannot hold, and MLKit's experience (Elsman
  2008, §6.3) says a layered store pays.
- **D2, D17:** the restrictions are for inference. Written order is sound, and the linear prefix is
  its default. A checker licenses speed.
- **D18:** the literature offers transparency or a firewall, not both. *What the implementations do*
  finds no system with both.
- **D20:** Elsman's properties are the form to state each phase in, and E18 is how Rune checks them.
- **D22:** what shipped in Backpack is checking against a signature, not code generated from one.
- **D5, D16, D29:** Mokhov's applicative tasks and self-tracking both favour a plan that is data.

MixML (Dreyer and Rossberg, ICFP 2008) is the one source here that points to recursive separate
compilation and to unifying structures and signatures. Only its first two sections were read, so it
goes to `docs/plans/rune2/separate-compilation.md` as a lead, not a finding.

## What the implementations do

E26 and E27 read the systems below, by decision rather than by system, since no
system answers all of them and each answer is only useful beside the others.
Nothing was built or run. Revisions are in *References*.

Paths without a prefix are relative to `/home/ruud/reference`. Web clones and
pages are under the drafts: `W/` is `results/E26/downloads/` and `X/` is
`results/E27/downloads/`. The clones are shallow and sparse, so a path missing
from a working tree is read with `git -C W/name show HEAD:path`. Line numbers are
at the revision given in *References*.

What could not be confirmed:
- The GHC wiki blocks scripts, so the Backpack wiki was not read.
- OCaml's `Private` submodule idiom has no primary source that E27 could find.
- holbuild's cache validation is cited from its design documents, not its code.
- Whether Stack 4.1 shipped as stable: only release-candidate notes were read.

### The systems at a glance

| System | Boundary | Namespaces | Generated sources |
|---|---|---|---|
| SML/NJ CM | Library with an export calculus; groups owned by a library | Groups; administrative renaming | Tool classes in ML, in-process |
| MLton MLB | `local` filter | Bases, `structure X = Y`, path maps | None |
| MLKit | MLB | As MLB; repository keyed `(uid, mlbid)` (Elsman 2008, §6.2) | None |
| Poly/ML | `saveModule` with explicit lists (`polyml/basis/FinalPolyML.sml:2186`) | Global | None; heaps, not unit files |
| OCaml, dune | `.mli`, `private_modules` | Wrapping by mangling, `-open` | `rule` stanzas |
| GHC, Cabal | Exports, `exposed-modules`, `other-modules`, private sublibraries | Package-qualified, `mixins`, `reexported-modules` | Build hooks |
| Cargo | Crate, `pub(crate)` | Crate names per dependency | `build.rs` |
| smackage | None | Anchor `$SMACKAGE/name/vN` | Delegates to `make` |
| holbuild | Package root, roots | One global logical name, rejected on clash | `[[generate]]` |
| Bazel | `visibility`, three systems | Labels | Rules with declared outputs |

### What a unit's interface is, in layers (D1, D18, D21)

| System | Static layer | ABI or optimisation layer | Implementation | What is hashed | Positions, docs | Self section |
|---|---|---|---|---|---|---|
| OCaml | `.cmi`: name, signature, import CRCs, flags (`ocaml5/file_formats/cmi_format.mli:23-28`) | `.cmx`: imports, approximations, known functions (`ocaml5/file_formats/cmx_format.mli:24-50`) | Object code | One CRC per file. The `.cmi`'s is taken before imports and flags are written, so it covers name and signature only (`ocaml5/file_formats/cmi_format.ml:84-92`) | In the signature by default (`ocaml5/utils/clflags.ml:195`, `ocaml5/typing/subst.ml:71`), so in the CRC (deduced). `.cmt`: Typedtree, shapes, occurrences (`ocaml5/file_formats/cmt_format.mli:53-73`) | None |
| GHC | `.hi`, `mi_public_` (`ghc/compiler/GHC/Unit/Module/ModIface.hs:280`) | The same part: unfoldings and strictness, left out by `-fomit-interface-pragmas` (`ghc/docs/users_guide/using-optimisation.rst:1022-1033`) | Object code; `mi_simplified_core_` to restart code generation (`ghc/docs/users_guide/phases.rst:698-704`) | Per declaration: "the fingerprint of a decl changes if anything in its transitive closure changes" (`ghc/compiler/GHC/Iface/Recomp.hs:1065-1080`) | None in `.hi`: names come back with `noSrcSpan` (`ghc/compiler/GHC/Iface/Env.hs:160`). `mi_docs_`; `.hie` | `mi_self_recomp_` (`ghc/compiler/GHC/Unit/Module/ModIface.hs:285`) |
| MLKit | `.eb`, the elaboration basis (`mlkit/src/Manager/Manager.sml:313-345`) | `.eb1`, the compilation basis, after opacity elimination (`:631-650`) | `.lnk`, target code | Pickle strings compared, and rewritten only if they differ (`:306-308`) | None read | Import basis restricted to the unit's free identifiers (`:626`) |
| SML/NJ | `senv` in the binfile (`smlnj/compiler/Execution/binfile/binfile.sml:36-46`) | None | `code`, in the same file | One static pid, and a rehash per filter (below) | None | Not separate |

- **OCaml alone is not the reference.** It has no per-export hash, and its `.cmi` hash
  covers locations by default. `.cmx` has one CRC, so any change to an approximation
  reaches every client (`ocaml5/file_formats/cmx_format.mli:38-50`).
  - What it does well is `-opaque`. The flag is in the imported `.cmi`
    (`ocaml5/typing/persistent_env.ml:316`), so `ocaml5/middle_end/compilenv.ml:203` skips
    the `.cmx` with no decision per client, and the link checks the two tables apart
    (`ocaml5/asmcomp/asmlink.ml:39-44`).
  - The firewall works because a client needs nothing from `.cmx` to lay out a value
    (deduced from `ocaml5/file_formats/cmx_format.mli:24-32`). That is not so in Rune
    (*Where we are*).
- **GHC is closest to D1.** The self-recompilation note gives "clarity about which parts of
  an interface file are used in order to **communicate**" against those used "to
  self-communicate" (`ghc/compiler/GHC/Iface/Recomp/Types.hs:21-55`), and its first motive is
  deterministic interfaces. Omitting a layer is a producer's flag, and the ABI hash covers
  what is there. Home modules are tracked per entity, packages per module
  (`ghc/compiler/GHC/Unit/Module/Deps.hs:313,332`).
- **MLKit is an SML compiler with layers.** It deserialises elaboration bases for every
  dependency and compilation bases only for what a unit refers to (*What the literature
  says*). Its import basis is the unit's usages under another name.
- **SML/NJ has one layer.** Its cut-off comes from the hash, not from a split.
- **rustc** has the same split at the crate: `.rmeta` can be used for "fast 'checks'", for
  documentation and "for pipelining", and "rmeta files do not support linking"
  (`X/rustc-libs/page.txt`).

**Firewalls.** E26 found no system that has a firewall, known calls and unboxed layout across
it at once.

| System | What crosses | What it gives up |
|---|---|---|
| OCaml `-opaque` | Types only | Cross-module information; relies on layouts needing none (deduced) |
| dune | `-opaque` in the `dev` profile, not in `release` (`W/dune/doc/reference/dune-workspace/profile.rst:43-53`) | Optimisation, in `dev` only. The firewall is a profile, not a property of a library |
| TILT | "interface ascription is coercive" (SMLSC §2) | See-through |
| Backpack, MLton | Everything | Separate code generation |
| MLKit | Everything, as region types and inline code | Separate code generation for functors (Elsman 1999) |
| SML/NJ, after Shao | Binding information, through signature matching | No firewall: abstract types are erased in the IR |

**A hash of the bytes, in every system read.** SML/NJ has `pickle2hash`, and `REHASH` for a filtered
environment (`smlnj/compiler/ElabData/pickle/pickmod.sml:44,61`). GHC overrides `putName` while
serialising. OCaml digests the file. Rune's third traversal is the outlier, and it is what diverged
(D21). Generation has precedents: CM's skeleton is "Generated from skeleton.asdl by asdlgen"
(`smlnj/cm/smlfile/skeleton.sml:3`), and MLKit's `pu` combinators give pickle and unpickle from one
value (`mlkit/src/Pickle/pickle.sig:9-30`).

### Identity (D3)

- **A path of names, not a counter.** rustc: "A DefPath is “stable” across changes made to the source
  code while a DefId isn’t" (`X/rustc-incr/page.txt`). SCIP replaced what its authors call "opaque
  global IDs" with strings of scheme, package and descriptors (`W/scip/scip.proto:190-226`,
  `X/scip-blog/page.txt`).
- **No machine paths.** holbuild: "machine paths and artifact roots exist only in the resolved views"
  (`W/holbuild/DESIGN.md:465-469`). JFP §7.4 gives the cost of the alternative (*What the literature
  says*).
- **One file, however spelt.** MLB: "Paths that denote the same file in the underlying file system are
  considered equal, though they may have distinct textual representations"
  (`mlton/doc/mlb-formal/mlb-formal.tex:210-212`). GHC normalises for the same reason: "eliminate
  spurious differences due to "./foo" vs "foo"" (`ghc/compiler/GHC/Iface/Recomp/Flags.hs:59`). Rune
  does neither: E10 finds `./ty.sml` for `ty.sml` changes 86 of 987 bytes of a client.
- **Names a compile makes.** Hashing them raw makes the hash depend on hidden internals, so Appel and
  MacQueen alpha-convert (§5), and MLKit renames explicitly (`mlkit/src/Manager/Manager.sml:283-300`).
- **Two identical files.** CM separates them with a `guid` built from the time
  (`smlnj/cm/smlfile/smlinfo.sml:273-275`), which Rune cannot copy and keep reproducible keys.
  A logical name separates them instead.
- **Input and output are two identities.** holbuild: "input key = can I reuse a cached build for these
  sources and resolved deps?", "output key = what semantic artifact did this build actually produce?"
  (`W/holbuild/DESIGN.md:525-527`).
- **A name outside the source can move.** Blume §3.7: a group name "never appears in source code", so
  groups can be "moved, renamed, or replaced freely".
- **Room for a version.** smackage's whole mechanism is an anchor with the major version in the path,
  `$SMACKAGE/cmlib/v1/cmlib.cm` (`W/smackage/README.md`).

### Boundaries and namespaces (D2, D7, D8, D9, D10, D22)

**A boundary is a name filter applied after elaboration, in every ML system read:** CM's export
calculus (`smlnj/doc/src/manuals/cm/04-exports.tex`), MLB's `local ... in`. None has a closure check.
Types legally escape (`local datatype t = A in val x = A end`, *What the Definition says*), so a
closure rule would be new, and a check on non-denotable types can only be a lint.

- **Hash per filter.** CM's filter is on the import edge (`smlnj/cm/depend/graph.sml:11,29`), and gets
  its own hash (`smlnj/cm/compile/traverse.sml:150-175`). The result is "the same value that would have
  been produced had the smaller environment been pickled (and hashed) in the first place"
  (`smlnj/compiler/ElabData/pickle/rehash.sml:9-12`). This is the nearest thing in SML to a hash per
  export, and it is what lets an aggregate keep cut-off.
- **What not to copy.** CM privileges: "there is no enforcement"
  (`smlnj/doc/src/manuals/cm/09-access.tex:47`).
- **What an import means.** MLB: "An MLB file is elaborated starting in an empty basis", and the
  importer's basis "does _not_ affect the imported basis"
  (`mlton/doc/guide/src/MLBasisSyntaxAndSemantics.adoc:61-68`). So closures at the level of a library
  need no language restriction, which `.build`'s `use` does not yet give: E9's MLton port had to hoist
  `mlyacc-lib` for that reason. "Each MLB file is elaborated and evaluated only once"
  (`:68-71`). CM goes the other way and compiles only what is "reachable" from a library's exports
  (`smlnj/doc/src/manuals/cm/02-cm-model.tex:110`), which drops a file kept only for its effect.
- **Transitive or not.** dune's default is transitive visibility, and it recommends trying `false`
  (`W/dune/doc/reference/dune-project/implicit_transitive_deps.rst`).
- **Private by path, or by declaration.** Go has one sentence: an import "is disallowed if the importing
  code is outside the tree rooted at the parent of the “internal” directory"
  (`golang/go/src/cmd/go/internal/load/pkg.go:1487-1489`). Bazel declares it: `__subpackages__`, and
  "Avoid setting `default_visibility` to public" (`W/bazel/docs/concepts/visibility.mdx:134`). Its
  advice to "prefer to expose a rule target rather than a source file" (`:198`) is the rule against reaching in.
- **Nesting.** dune stops a directory group at a nested `library`, and a subdirectory must opt out with
  `(include_subdirs no)` to stand apart (`W/dune/doc/reference/dune/include_subdirs.rst:21-31`). So a
  nested library is its own, not its parent's.

**Namespaces.** CM's model is the one that fits SML:
- Link by pid, not by name (Appel and MacQueen, §5).
- A clash arises only when two imports in one scope have different definitions (rule 3,
  `smlnj/doc/src/manuals/cm/02-cm-model.tex:136-138`). A local definition wins over an import.
- Renaming goes through "administrative" groups (Blume §3.6), since the source language has
  `structure B = A`. The caveat is that `val y = x` loses constructor status.

The others are MLB's `structure X = Y`, cargo's `package =`
(`W/cargo/doc/book/src/reference/specifying-dependencies.md:581-604`) and Cabal's `mixins`. dune wraps
because OCaml's top-level modules must be unique at link: it mangles object names
(`W/dune/src/dune_rules/modules.ml:104-105`) and generates an alias module opened with `-no-alias-deps`
(`W/dune/src/dune_rules/module_compilation.ml:375`). **That cannot be copied in SML:** a structure
cannot hold signatures or functors (*What the Definition says*), so a library cannot be wrapped in one.
holbuild takes the other extreme, one logical name per graph, because "HOL/PolyML process state has
global theory and ML module names" (`W/holbuild/DESIGN.md:393-394`). SMLSC leaves the question open: "We
leave the solution of this namespace problem to future work" (§6).

**Virtual libraries (D22).** dune's `virtual_modules` and `implements` allow one implementation per
executable and no new public modules (`W/dune/doc/virtual-libraries.rst:119-124`). Others are Cabal's
`signatures`, SMLSC's functor specifications and CM's `funsig`. MLKit's bug of 2005 is the trap: a
functor's body changed, its `eb` file did not, and recompilation was missed, until an md5 of the body
went in the closure (`mlkit/NEWS.md:655-663`). An ABI fingerprint must cover whatever a client compiled
from. Backpack's limit carries over too: the tests in `ghc/testsuite/tests/backpack/should_fail` include
`bkpfail43`, a failure that comes only at instantiation.

**smackage, Cabal and Cargo: what Rune takes.** All three answer a question a monorepo does not have yet, versions across repositories, and the package manager stays *Later*. Three things carry over. From smackage, room for a version in a name (D3). From Cabal, a package's exposed and hidden modules, which D8's header is, and the private sublibrary, which D11's friends answer with no convention. From Cargo, a rename per dependency (D9), and a warning: `build.rs` is outside what the graph knows (D16).

### Tests against abstraction (D11)

The test is whether the mechanism needs a second build of the library, and whether it fits SML, where a
test is another unit.

| Mechanism | Second build of the library? | Fits SML? |
|---|---|---|
| Rust `#[cfg(test)]` child module | Yes | No. rust-analyzer: "more or less every item in a `lib.rs` is a part of two distinct crates" (`W/rust-analyzer/crates/hir/src/semantics/source_to_def.rs:79-81`) |
| D `unittest`, dune `(inline_tests)` | Yes: "the version identifier unittest is predefined" (`X/d-unittest/page.html`); dune's release profile compiles them out | No |
| Java `--patch-module` | No | No. A command-line override, "intended only for testing and debugging" (`X/jep261/page.txt`) |
| Go `export_test.go` bridge | Yes, for tests: 44 such files in Go's `src` (`golang/go/src/net/http/export_test.go:5-6`) | Partly |
| C# `InternalsVisibleTo`, Bazel `//tests:__pkg__`, Kotlin test source sets | No | Yes. The library names its friends |
| Cabal private sublibrary (`ghc/libraries/Cabal/doc/cabal-package-description-file.rst:937-970`), Haskell `.Internal` | No | Yes, by convention |

A friend list fits, and a friend still cannot see through `:>`. Yang's §8.2 shows the limit of the
`.Internal` convention: a type lives in one module and is re-exported, because "we can't define the type
in both locations, since then they won't be the same type!" A mechanism that builds a library twice
recreates D26's problem, as rust-analyzer's comment says.

### Basis views (D12)

- **A view is a library.** `smlnj/libraries/old-basis/2004/basis-2004.cm` is `library($SMLNJ-BASIS/basis-common.cm)`
  minus the new modules, plus a rebinding file. MLton has `mlton/basis-library/basis-2002.mlb` and
  `basis-1997.mlb`. In both, the newest is the default and an older view is opt-in.
- **Order can leak.** `mlton/basis-library/default.mlb:8`: "Order here matters for choice of type names."
- **Per-section settings.** MLB's `ann` covers language options, as `mlton/basis-library/basis-1997.mlb` does
  with `allowOverload`. Cargo's `edition` is per package (`W/cargo/doc/book/src/reference/manifest.md:140`).
- **Wired-in names escape a view.** Yang's negative result (*What the literature says*) is the warning. E4 found
  the same order constraint in Rune: a view works if its seals load after the libraries.

### Generated sources (D5, D16, D29)

Every large system evaluates its configuration before it runs anything.
- **Bazel** has loading, analysis and execution phases, and "You must list explicitly which files will be
  generated before executing the actual commands" (`W/bazel/docs/extending/concepts.mdx:47-60`). Its
  configuration language is restricted to stay that way: a value loaded from another file is
  frozen (`W/bazel/docs/rules/language.mdx:92-100`), and "A file is read at most once per build"
  (`W/bazel/docs/extending/concepts.mdx:66`).
- **holbuild** runs `[[generate]]` steps "before source discovery". The command is argv, not shell text, with
  declared inputs and outputs, and every output must exist afterwards
  (`W/holbuild/skills/holbuild/references/manifest.md:179-190`). "theory/action keys still use the actual
  generated source bytes" (`W/holbuild/DESIGN.md:463-465`). It rejects `use` in project actions, `..` in paths,
  and unknown fields (`W/holbuild/DESIGN.md:458`, `W/holbuild/skills/holbuild/references/manifest.md:79,115`).
- **CM's tools** run ML rules in-process and compare timestamps (`smlnj/doc/src/manuals/cm/07-classes.tex`,
  `11-files.tex`). That is weaker.
- **Cargo's `build.rs`** is outside what the graph knows.
- **GHC** records observed inputs as `UsageFile`, a path with a hash of the contents
  (`ghc/compiler/GHC/Unit/Module/Deps.hs:344-351`), which D29 needs if a build program may read a file.

Non-determinism has a real price: rust-analyzer's one invalidation bug was "due to procedural macros being
non-deterministic" (`X/ra-three/page.txt`).

### Where the store lives and how it is evicted (D24)

| System | Location | Keys | Eviction |
|---|---|---|---|
| Go (`golang/go/src/cmd/go/internal/cache/cache.go`) | User cache | ActionID to OutputID | mtime on use at most hourly, trim at 5 days (`:348-350`) |
| holbuild | `$HOLBUILD_CACHE`, then XDG | `actions/<key>/manifest`, `blobs/<hash>` | 7 days; a hit refreshes the mtime; reachability sweep. "Races with builds should degrade to cache misses and source rebuilds" (`W/holbuild/DESIGN.md:594,653-655`) |
| dune | `XDG_CACHE_HOME/dune/db` | Rule hash | `dune cache trim --size`, by hand; user rules excluded by default (`W/dune/doc/reference/caches.rst:58-61,111-112`) |
| Bazel | `--disk_cache`, remote | Action cache plus content-addressed store | GC flags since 7.4 (`W/bazel/docs/remote/caching.mdx:313-317`) |
| Cargo | `target/` per workspace | Fingerprints | None shown for `target/`; a shared cache is third-party sccache (`W/cargo/doc/book/src/reference/build-cache.md:96`) |
| CM, MLKit | Beside the source (`CM/`, `MLB/`) | Path | None; Elsman 2008 §6.1: "deleting the MLB directory effectively resets the repository" |
| clangd | Beside `compile_commands.json`, or user cache for headers with no compile command | Per file | Not stated (`X/clangd-indexing/page.txt`) |

- **The shape that recurs** is a map from action to manifest, plus content blobs.
- **Hard links divide them.** holbuild refuses them, because project outputs "should not be able to mutate global
  cache contents by accident" (`W/holbuild/DESIGN.md:601-603`). dune uses them, and "systematically removes write
  permissions from all build results" (`W/dune/doc/reference/caches.rst:87-88`).
- **A store shared across machines rests on determinism.** holbuild says so outright: "sharing cache entries across
  machines rests on a reproducibility contract", and a restored theory "whose recorded parent `.dat` hashes differ
  from the local parents is rejected and rebuilt" (`W/holbuild/DESIGN.md:546-558`). That is the defence against the
  Frankenbuild of Mokhov's §6.4. Its policy line is D20's too: "A bad cache hit is worse than a missed cache hit"
  (`W/holbuild/DESIGN.md:21`).
- **Immutable layers exist elsewhere.** Glean stacks immutable databases, and each layer "can non-destructively add
  information to, or hide information from, the layers below" (`X/glean-blog/page.txt`). That is the shape of a
  frozen `lib/cache` under a writable overlay.

### The warm path (D19, D25)

- **Stat, on equality.** CM requires a binfile's timestamp to be "exactly the same" as the source's, so all changes
  are noticed, "even those that revert to an older version" (`smlnj/doc/src/manuals/cm/11-files.tex:68-72`). Timestamps
  are still weak: "Timestamps can be unreliable" (`W/cargo/doc/contrib/src/implementation/filesystem.md:15`), and dune
  added "device and inode number" to invalidate its cached digests (`W/dune/CHANGES.md:219`).
- **Not reading is the saving.**
  - MLKit skips deserialising by timestamp (Elsman 2008, §6.4).
  - rustc's try-mark-green exists to "avoid deserializing the result from disk when we don't need it"
    (`X/rustc-incr2/page.txt`).
  - GHC reads usages lazily: `mi_sr_usages` is `lazyPut` (`ghc/compiler/GHC/Iface/Recomp/Types.hs:67,89`).
  - Elsman uses Patricia trees for close to constant-time summing of bases (§6.1).
- **Whole sets at once.** Salsa's durability lets it "skip traversing their dependencies" when no high-durability input
  has changed (`W/salsa/book/src/reference/durability.md:9`). That is the shortcut a frozen layer should have: it needs no
  per-file check at all.
- **Cut-off by not writing has a trap.** MLKit compares pickle strings and leaves an unchanged file alone
  (`mlkit/src/Manager/Manager.sml:317-328`), but `.lnk` is always written (`:353-358`). Its 2026 release note shows why
  this is delicate: "unnecessary recompilation due to lnk-file not being written when content is unchanged"
  (`mlkit/NEWS.md:34-35`). A store with content hashes does not have this problem (deduced).
- **No early cut-off, on purpose.** holbuild: "V1 must not use output hashes to skip rebuilding dependents"
  (`W/holbuild/DESIGN.md:540`). So it is a model for trust, not for cut-off. Its reason is proofs: a comment edit cascades,
  and it pays for that elsewhere with checkpoints.
- **Scheduling.** holbuild forbids "a separate serial "all nodes up to date" preflight", and treats up-to-date, cached and
  built outcomes uniformly as completed nodes (`W/holbuild/DESIGN.md:412-418`). `src/driver/parallel.sml` can do the same (D25).
- **Skeletons.** CM strips the syntax to a "skeleton" and caches it per file (`smlnj/cm/Overview:40-44`,
  `smlnj/cm/smlfile/skeleton.sml`). That is the model for what replaces MANIFEST's `uses` (D13).

**Aggregates (D19).** Two things go by that name.
- **A packaging aggregate has precedent.** CM's stable library is one file with graph, code and symbol tables. With one, "no
  dependency analysis work and no recompilation work will be necessary" (`smlnj/doc/src/manuals/cm/05-usage.tex:44-45`), and
  it "touches far fewer file-system objects" (`smlnj/doc/src/manuals/cm/02-cm-model.tex:321-323`). Each member keeps its own
  code, so nothing is optimised across them. OCaml's `.cmxa` is a list of units, not a merged one
  (`ocaml5/file_formats/cmx_format.mli:55-61`).
- **An optimising aggregate has no ML precedent** in what was read. rustc's crate is the nearest, and matklad warns that "The
  minimal feasible unit of laziness, a crate, is still too big" (`X/ra-three/page.txt`). holbuild avoids aggregates on purpose:
  its groups do "not synthesize, load, or export an aggregate HOL theory" (`W/holbuild/DESIGN.md:307-308`).

### Editors at scale (D26, D27, D28)

**A file with several contexts.** The systems that refuse the question are the ones with no prompt:
- CM: "The same ML source file cannot appear more than once" (`smlnj/doc/src/manuals/cm/02-cm-model.tex:308`).
- MLKit checks that a source file is "included at most once in an entire MLB source-hierarchy" (`mlkit/NEWS.md:719-721`).
- dune: "Module %S is used in several stanzas" (`W/dune/src/dune_rules/ml_sources.ml:371`).

Those that allow it pay:
- rust-analyzer: "we don't really handle this well and return the first answer that works"
  (`W/rust-analyzer/crates/hir/src/semantics/source_to_def.rs:83-84`).
- clangd determines "a virtual compile command for each opened file" and infers one for a header from a file that includes
  it (`X/clangd-compile/page.txt`).
- HLS loads cradles per component, and its troubleshooting page gives the wrong cradle as the most
  common cause of compilation failures (`W/hls/docs/troubleshooting.md:162-163`).

matklad's advice is D26's direction: "Make sure that each source element corresponds to a single semantic element"
(`X/ra-three/page.txt`). Elsewhere he asks that name resolution "work well with the map-reduce paradigm". That is what top-level
names readable from syntax would give the LSP, and the reason D17 matters to the editor at all.

**What is stored.**

| Tool | Stores | Cold start | After a compiler upgrade |
|---|---|---|---|
| Merlin | Nothing of its own; reads `.cmi` of "an old build" (Merlin paper, §2.2) | Needs a build | Needs a rebuild for the new compiler (deduced from cmi magic numbers) |
| ocaml-index | An aggregate of `.cmt` occurrences (`W/merlin/src/index-format/index_format.mli:35-42`) | Build plus aggregate | The same |
| HLS, hiedb | `.hi`, `.hie`, SQLite; one cache folder per set of GHC options (`W/hls/ghcide/session-loader/Development/IDE/Session/Ghc.hs:529`) | hiedb database | The database name holds the GHC version (`W/hls/ghcide/session-loader/Development/IDE/Session.hs:391`), so a new database. `hieVersion` is the GHC version (`ghc/compiler/GHC/Iface/Ext/Types.hs:55-56`) |
| rust-analyzer | Nothing: the core "keeps all this input data in memory and never does any IO" (`W/rust-analyzer/docs/book/src/contributing/architecture.md:28`) | Caches primed at load if asked (`W/rust-analyzer/crates/load-cargo/src/lib.rs:199-201`) | The same as a cold start |
| rustc | On-disk query results, between sessions (`X/rustc-incr/page.txt`) | Per session | Metadata: "The compiler will refuse to load files from any other version" (`X/rustc-libs/page.txt`). The pages read do not say so for the query cache |
| clangd | A `*.idx` per file (`X/clangd-indexing/page.txt`) | Background; "avoids reindexing on startup if nothing changed" | Not tied to compiler internals (deduced); `MergedIndex` layers fresh over old |

- **Salsa has an on-disk form.** It has an optional `persistence` feature (`W/salsa/Cargo.toml:62`), which rust-analyzer does not
  enable (`W/rust-analyzer/Cargo.toml:126-132`). So nothing on disk is true of rust-analyzer, not of Salsa.
- **Keying decides what an upgrade costs.** `Config.identity` changes with every compiler, so a sidecar keyed by it would go cold
  on every upgrade. clangd's survives because it is not so keyed, and HLS's does not because it is (deduced).
- **Restarting code generation.** GHC's fat interface restarts code generation from stored Core
  (`ghc/docs/users_guide/phases.rst:703-704`). That is the shape E24 needs for "precompile as we edit".
- **Absence must not change the answer.** Merlin: "the presence or absence of saved state does not modify Merlin's results, only
  its performance" (footnote 3), with a mode that uses no cache. A no-cache mode is the check for that.

**Scale.**
- **Memory.** rust-analyzer assumes source "in tens of megabytes at most" (`W/rust-analyzer/docs/book/src/contributing/architecture.md:29`),
  so its in-memory input model does not carry to 10M lines (deduced).
- **Whole-repository indexes are remote.** clangd: "multiple hours even on very powerful machines for Chrome-sized projects", "multiple
  GB of RAM" (`X/clangd-indexing/page.txt`). The answer is a remote index, where "Results may not be entirely up-to-date"
  (`X/clangd-remote/page.txt`).
- **The honest cost function.** Glean: "in practice the best we can do is O(fanout)" (`X/glean-blog/page.txt`), and its ownership
  propagation takes O(facts) (`X/glean-incr/page.txt`). SCIP's symbols as strings exist for the same reason: for LSIF, "The heavy usage of
  opaque global IDs imposes an ordering constraint" that hinders incremental indexing (`X/scip-blog/page.txt`).
- **Laziness over incrementality.** matklad: incrementality is not what makes an IDE fast. "Rather, it's laziness" (`X/ra-three/page.txt`).
  rust-analyzer's own invariant is that "typing inside a function's body never invalidates global derived data"
  (`W/rust-analyzer/docs/book/src/contributing/architecture.md:174`). Its costs are stated too: "fine-grained tracking of dependencies
  takes time and memory". So D28's targets are best stated as cost functions, and caps removed by loading less rather than by raising them.
- **Dead ends.** stack-graphs is abandoned: "This repository is no longer supported or updated by GitHub" (`W/stack-graphs/README.md:1`).
  It should not be a candidate.

## The ideation, reviewed

The brief (line 14) asks for a thorough, critical review of `ideation1.md`, `ideation2.md` and `ideation3.md`,
16,537 lines of transcripts of conversations with an AI that had no web access. They are flattering by
construction and they are not evidence. This section treats them as a list of claims and checks each one.

Citations: `ideationN:L` is `docs/plans/build-system/ideationN.md`, line L. Rune's code is at `b12141ecc`. `W/` is
`results/E26/downloads`, and a bare `smlnj/`, `ghc/`, `mlton/`, `racket/` is under `~/reference`. "R" is Agent R's report
(E25-E27). Counts come from `results/I/counts.sh`, raw output `results/I/counts.txt`; the worked examples are in
`results/I/examples/`, and web pages read for systems R did not cover are in `results/I/web.md`. Statements about behaviour are deduced from reading: Agent I ran nothing of Rune's.

**The verdict first.**

- **What is right.** The observation that SML has no core-over-modules quadrant. That type identity, build identity and
  structure must be kept apart (ideation1:357-424), the best page in the three documents. The table of what a declarative
  description gives (ideation1:2919-2934). Explicit wiring over automatic resolution (ideation2:986-1016). The split
  between what programs may assume and what an optimiser may assume (ideation3:9657-9696).
- **What is wrong.** Strict phase separation is claimed and the ideation's own examples break it: `Build.test` hands run-time
  results to the build program. Elaborated module handles make planning depend on the elaborator, and the base case of the
  API, `Build.source`, cannot even be defined without the answer the plan is computing. `rewrite` over modules is reach-in
  with a traversal. "Rune's richer module calculus" does not exist: Rune has SML '97's modules, and the ideation misses the
  module features Rune does have.
- **What is left.** All four of the ideation's examples can be written today in `.build` with a path variable, and one of them
  is in the repo. The SML form of each is longer: 1.11 to 1.43 times the lines. A pure SML function that returns a plan is
  sound, keeps phases strictly, and needs no compiler feature: any SML program can print a `.build`, as `runeffi` already does.
- **Recommendation.** D5: the plan is the contract, `.build` its normal form, form (c) rejected. D23: not now. D29: a build
  program is a pure function of declared parameters, so there are no observed inputs to record. G2: on today's evidence, do not
  build the term layer. The test, with its numbers, is at the end.

### What is proposed

Stripped of rhetoric, the proposal is this. A project's build is an SML program that runs before compilation ("stage -1",
ideation1:20-36). It computes a description of how modules are composed. The compiler elaborates and compiles what the program
described, and nothing of the program is in the result (ideation1:278, :651-662).

**Three forms** (ideation1:280-355).
1. *Syntactic module generation.* `apply : ModuleSyntax.t -> ModuleSyntax.t -> ModuleSyntax.t`: the program builds ASTs and normal
   elaboration checks them afterwards.
2. *Elaborated module handles*, called "the more interesting Rune design" (ideation1:333). `import : path -> module`,
   `signatureOf : module -> signature`, `apply : functor * module -> module`: the build program calls the elaborator as it runs.
3. *Typed module combinators.* `('a, 'b) functor`, `'a module`. The ideation itself says SML's types cannot express this, and does
   not start there (ideation1:353-355).

**The `Build` API.** There is no one API. There are at least six versions, not compatible with each other: ideation1:313-323, :579-608,
:694-745, :4018-4053, ideation2:393-402 and :1070-1080, and ideation3:8475-8527 with `Build.library`, `Compiler.build` and `Optimize.*`.
`apply` is `functor * module -> module` in one and `module -> module -> module` in another. The common core:
- Graph: `source`, `structure_`, `apply`, `seal`, `rename` or `alias`.
- Effects: `compile`, `emit`, `target`, `dependency`.
- Run-time results: `test : executable -> Test.result`, `benchmark : executable -> Benchmark.result`, and `compileWith`
  (ideation1:737-741, :1816).
- Later and untyped, names only: `require`, `provide`, `resolve`, `profile`, `share`, `contract` (ideation2:396-401).

**`rewrite` and `replace`.** `rewrite : (module -> module option) -> module -> module` walks a module graph and wraps what a predicate
picks, by name (ideation1:1014-1028) or by signature (:3410-3424). `replace {root, path, replacement}` swaps a named submodule
(:719-723). The ideation itself demotes `replace`, keeps `rewrite` for cross-cutting work and says to use functor arguments for the
rest (:1853-1905).

**Profiles** are a name: `Build.profile` has no type and no semantics anywhere. Read kindly they are dune's: a named set of settings.

**The controlled embedding** (ideation1:4009-4098). The fix for arbitrary SML: pure SML over configurations, with observation only
through `Build.source`, `Build.env` and `Build.target`, in a type `'a t`, applicative if possible, monadic if needed: "support both"
(:4102-4153).

**ideation2** makes the build system a "typed dependency-injection assembler" over higher-order functors (ideation2:389-404), then an
adversarial review withdraws much of that (:710-1137).

**ideation3** is mostly language design (`freshtype`, specialisation, representation). Its build-related claim: a library's build
exports a public interface, code and an *optimisation catalogue*; an application's build imports the catalogues; the final compile
applies them, under explicit closed-world declarations and scopes (ideation3:8390-9758).

**What it assumes and never says:**
- that a program is a graph of functors applied at a root (`MainFn`, `ApplicationFn`, `CompilerFn`), which Rune's compiler is not;
- that a file is a module;
- that the build language has a Rune to run it, on every host and in every reader;
- that Rune has higher-order, applicative and first-class modules;
- nothing at all on how a build program's own dependencies are described, which is a regress: a build program that uses a library
  needs a build description, so `.build` stays whatever happens.

### Claim by claim

Verdicts: *sound*; *sound but already available without it*; *overstated*; *wrong*; *untestable here*.

**Against other systems**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 1 | "the feature neither really provides: higher-order computation over the space of module configurations" (ideation1:4202; also :3433) | Overstated | True of Backpack, whose mixins are declarative. Not of dune: a `dune` file can be an OCaml program (`W/dune/doc/advanced/ocaml-syntax.rst:8-13`), and generated stanzas come in through `include` and `dynamic_include` (`W/dune/doc/reference/dune/include.rst`). Dune's own verdict: the feature "doesn't work well with incremental builds", and "you must not build complex systems based on it" (`ocaml-syntax.rst:15-21`). Beyond those two it is routine: Nix, Starlark, Shake, `build.zig` and Gradle all compute graphs in a language. The narrower reading, over *typed* configurations, fails as well: see 20. | No novelty argument in D5 |
| 2 | Dune users must "enumerate configured targets" and cannot wrap across a program (ideation1:3207, :3307, :3872) | Wrong in part | `(context ...)`: "Each context builds the same sources with a different configuration" (`W/dune/doc/reference/dune-workspace/context.rst:4-7`). `(instrumentation (backend ...))` turns a declared rewriter on from the workspace or a flag (`W/dune/doc/instrumentation.rst:13-18,54-56`): that is ideation1's `logging`, `coverage` and `profiling`, declared, without `rewrite`. The `(alias ... (action ...))` at ideation1:3055-3061 is a removed form (`W/dune/doc/reference/dune/alias.rst`, warning). `(virtual_modules)` and `(implements)` are right. | D4 (named targets), D16 |
| 3 | Backpack "provides separately compiled components" (ideation1:2221, :2249) | Wrong | "every distinct instantiation of a component is compiled against the code that implements its requirements" (Yang §2.3, R): separate type checking, no separate code generation. Its check that a filling is sound has a hole: the theorem "cannot be made to be true as Haskell exists today" (Yang §9.1.1, R). Rune's `_virtual` does generate code against a signature alone (`docs/build.md:211-245`). | D22 |
| 4 | Backpack is the model, "the most important one to study" (ideation3:10620; ideation1:4096) | Overstated | The lesson runs against the ideation. Backpack'14 "could not be implemented" because its "package-level semantics, were closely entwined with the semantics of Haskell itself", "violating the traditional abstraction barrier between the compiler and package manager". The repair divides it into "mixin linking which is indifferent to Haskell source code" and type checking, "purely the concern of the compiler" (Yang ch.1, `results/E25/downloads/yang-thesis2/yang-thesis2.txt:364-373`). Form 2 is Backpack'14's mistake. The plan is Backpack'17's repair. | D5 rejects form 2 |
| 5 | CM: build-time use of SML itself, no; arbitrary higher-order computation, no (ideation1:1968-1976) | Wrong in part | Class rules "are programmed in ML" (`smlnj/doc/src/manuals/cm/07-classes.tex:25`). `CM.make`, `CM.Anchor.anchor` and `CM.symval` are SML functions (`02-cm-model.tex:92`, `03-naming.tex:142`, `08-condcomp.tex:72`), so an SML program can already loop over variants. `#if` guards members and exports (`08-condcomp.tex:12-15`), and `bind:` rebinds an anchor on one import edge (`results/E26/notes-cm.md`, line 16), which is module substitution in a declarative file. | Prior art for D6 |
| 6 | CM shows a build system "tightly integrated with the SML elaborator" (ideation1:1978) | Overstated | CM plans from a skeleton, the AST stripped of what it does not need, without elaborating (`smlnj/cm/smlfile/skeleton.sml`; `results/E26/notes-cm.md`, line 13). Even so, its author records: "I have tried to keep CM's impact on the ML language as small as possible, but I was not able to make it zero" (Blume thesis §7.2). | Evidence against form 2 |
| 7 | MLB holds "a fixed configuration" (ideation1:2023) | Wrong in part | Path variables, among them `TARGET_ARCH`, `TARGET_OS` and `DEFAULT_INT` (`mlton/doc/guide/src/MLBasisPathMap.adoc:24-33`), select files. MLB is `.build` plus a parameter. The rest of ideation1:2001-2005 is sound. | Confirms the core below |
| 8 | Racket units are "extremely close" to build-time composition (ideation1:2265-2287; ideation3:10676) | Wrong | A unit is one of "first-class values" and is invoked at run time (`racket/pkgs/racket-doc/scribblings/guide/unit.scrbl:19-24,274`). That is `_dynamic`'s side of the line, not the build's. It is also real higher-order computation over signature-checked components, so a counterexample to 1. | None |
| 9 | Racket shows compile-time power "does not require abandoning phase separation" (ideation1:2199-2201) | Sound, its price omitted | Below, *Phase separation*. Flatt's paper is not cited in ideation1. | D29 |
| 10 | "Shake-style embedding with Dune-style graph semantics" (ideation1:4096; :2399-2422) | Overstated | Shake's graph is not known until tasks run (Mokhov §2.3). A `dune` file's graph is known from reading it. One system cannot be both for the same dependency, and Rune needs the second. | D5 |
| 11 | Nix is "closely related in spirit" (ideation1:2474-2514) | Sound, under-read | Nix is the claimed feature: a pure language computing a graph, with overlays that override a package in the set (`results/I/web.md`), which is `replace` at package grain. Mokhov §5.4 classes it as monadic. The lesson it was not asked for: with `allow-import-from-derivation` off, evaluation finishes before anything is built; with it on, "evaluation will be paused". | D29: no `bind` |
| 12 | Starlark is "the opposite design point" (ideation3:10497) | Overstated | Starlark has functions and, in `BUILD` files, list comprehensions (`W/bazel/docs/rules/language.mdx`), so a product is one line. It withholds recursion, mutation after load and effects, and Bazel keeps "loading", "analysis" and "execution" apart (`W/bazel/docs/extending/concepts.mdx:47-60`). It is the same point as the ideation's controlled embedding, reached by subtraction. | Model for D29 |

Two systems closest to the proposal go uncited in 16,537 lines. **`build.zig`** is ideation1's design in production: running it adds steps to
a DAG, and `b.option` makes it configurable. **Gradle's** configuration cache stores "the task graph", tracks "Contents of files read at
configuration time" and environment variables used, and "On a hit, the entire configuration phase is skipped": property 2 of the plan
schema, in production, on a language that restricts nothing and so must track everything it reads.

**Phases**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 13 | "You can preserve very strong phase separation"; the program is prevented from "observing runtime values" (ideation1:222-267) | Wrong as written | `Build.test` and `Build.benchmark` return run-time results to the build program (ideation1:737-741, used at :879, :895, :1561, :1579, :3200). `Build.compileWith` runs a built compiler (:1816). `compile` and `emit` are effects of evaluating it. Observation "must go through" `Build.*` (:4082-4090), and no mechanism is named. | D29 |
| 14 | "The build program disappears once compilation is finished" (ideation1:278) | Sound if, and only if, its one output is a plan | Then it is a fact about a process boundary. With `Build.test` in the API it is false. | D29 |
| 15 | Embedding in SML escapes the trap of a DSL growing into a language (ideation1:2371, :2936-2956) | Sound as a warning | `.build` has 12 keywords (`buildfile.sml:71-72`), and `group`, `local`, `cache` and `allowPrim` have no uses (plan, census). It has not grown, and `ffi/sdl/native.build:1-3` already draws the line: ".build executes no shell commands". The answer is to stop at one parameter and let a generator do the rest, as `include` does in dune. | D6 |
| 16 | "Don't let SML generate strings containing SML" (ideation1:645, :218) | Wrong for Rune | A unit's key is its name and the hash of its text (`lib/compiler/driver/unitcache.sml:215-218`). A generated one-line unit has a key, a path, a position and a place in the LSP. A handle has none of these. `runeffi` writes `.build` text today (`src/ffi/main.sml:115-144`), 15 of the 88 build files. | D5, D16 |
| 17 | SML lacks core over modules, and the build layer fills the quadrant (ideation1:1-12, :505-522) | Sound as an observation, overstated as a result | `Build.module` is a description. The ideation says so (:528-573). The quadrant is filled as a program that prints SML fills it. | Say so in D5 |

**Planning and typing**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 18 | Elaborated handles are the design to choose (ideation1:311-333) | Wrong for this roadmap | The plan needs the elaborator, so "reading a plan runs nothing" (`draft/plan-schema.md`, property 2) fails by construction. Each LSP context holds a `Project.t` planned under overlays (`src/lsp/workspace.sml:11`, `lib/compiler/driver/project.sml:1-2`); hosts read with awk (`scripts/build-files.sh`), and that list is the compiler's identity (`scripts/gen-version.sh:51`). GHC has the same split: "ghc -M does not know about these dependencies - it does not execute TH" (`ghc/libraries/ghc-internal/src/GHC/Internal/TH/Syntax.hs:834`), and HLS must compile a module "if any file that depends on it uses TemplateHaskell" (`W/hls/ghcide/src/Development/IDE/Core/Rules.hs:1375`). | D5 rejects it; E12's bound is for the record |
| 19 | `Build.source : string -> module` (ideation1:318, :702) | Wrong: undefined | Below, *What `Build.source` would have to mean*. | D5 |
| 20 | "typed module graph" (ideation1:2584, :4190); "statically checked" (ideation2:704) | Overstated | The build function is `Module.t -> Module.t`, which "forgets those relationships" (ideation1:555-561). In forms 1 and 2 the only check of a composition is stage 0's elaboration. A one-line unit `structure P = F (A)` gets that check today, with a position. ideation2:728 withdraws the container. | No type claim in D5 |
| 21 | Errors "occur after generation" is a defect of form 1 (ideation1:299-309) | Overstated | If a unit is text, that is where errors belong. Form 2 runs the same check sooner, at the price of 18. What matters is that a generated unit's error is readable, which E12 did not measure. | D5 |
| 22 | Do not start with typed combinators (ideation1:353-355) | Sound | SML's types cannot say it. | Dropped |
| 23 | `Build.structure_` makes a structure of modules (ideation1:590, :706) | Wrong in part | A file may hold signatures and functors, and "Structures cannot hold signatures or functors" (R, finding 5). `module` conflates file, structure, functor and signature. `[Parser, optimizer, ...]` (:842) has no field names; a later version adds them (:3182). | None |

**Applicative and monadic**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 24 | Applicative descriptions show their dependencies without running (ideation1:4102-4118) | Sound | Mokhov §3.7. In SML it is a functor over an abstract signature, run at a recording structure (R, D29). The examples below are written that way. | D29 |
| 25 | "For Rune, I'd probably support both" (ideation1:4153) | Wrong | Nothing needs `bind`. Rune's sources are named up front, generated ones too (`Makefile:115`). MLton's 606 files are a static `.build` (`results/E9/README.md`). HOL4's `src/boss` closure, 746 units, is static given the generated theories (same file), a theory's outputs are named from its script (`hol/HOL/tools/Holmake/Holdep.sml:45-58`, plan), holbuild's audit found no literal or dynamic `load` in theory scripts, and generation is a stage before discovery (`results/E26/notes-holbuild.md`, lines 7 and 18). E9 takes the generated theories as given, so it shows the compile half, not the runs. Dynamic `load` in `examples` is in programs nothing depends on: entry units. One declared generation stage (D16) is all any of them asks. | No `bind` |
| 26 | The controlled API is applicative (ideation1:4018-4053) | Overstated | It does not compose as written. `source : Path.t -> module t` and `compile : module -> executable t` with only `pure` and `map` give `executable t t`: reaching `compile` from `source` needs `join`. Choosing a file from `target`'s `Target.info t` (:4037-4039), as `filesystemFor` does (:1137-1150), needs `bind`. Each example is monadic under the API meant to avoid that. Make the platform an argument of a pure function and `'a t` has no job left. | D29 |

**`rewrite`, `replace`, transformations**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 27 | `Build.rewrite` gives structural instrumentation (ideation1:725-729, :1033-1038) | Wrong as specified | Below, *`rewrite`*. | Dropped |
| 28 | `Build.replace` (ideation1:719-723) | Sound but already available | `implements`, or a path variable. The ideation demotes it (:1853-1861). Inside a library it is reach-in. | Dropped |
| 29 | The logging code "does **not exist at all**" in release (ideation1:1059-1078) | Sound but already available | It is not in the file list. See example 2. | Keep |
| 30 | A generic logger, from a signature, by reflection (ideation1:3435-3464) | Untestable here | The ideation admits it is "beyond ordinary SML functor composition". Nothing in Rune reflects on a signature. If wanted, it is a tool that reads a signature and writes a functor: `SGenerate`. | D16 |
| 31 | An algebra of transformations, `logging >>> profiling` (ideation1:1597-1672) | Overstated | `optimize`, `stripDebugInfo` and `boundsChecking` are compiler options, not functions on modules. ideation2:844-875 withdraws the composability. | Dropped |

**Variants**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 32 | "dozens of compiler configurations" (ideation1:4204); 24 compilers (:1725-1729) | Overstated | Below, *The matrix Rune has*. | Gate G2 |
| 33 | A product in SML is "one of the strongest arguments" (ideation1:901-936, :1496-1540) | Sound but already available | `tests/runner/oracles.sml:170-176` is that product, in SML, with no build language. | Keep the runner |
| 34 | "compiler builds can compile compiler builds" (ideation1:1776-1847) | Wrong here | A task that depends on running an output crosses the phases and is monadic. It is `bootstrap.md`'s job, which the brief puts out of scope. | Out of scope |
| 35 | Platform substitution by build (ideation1:1101-1226) | Sound but already available | `ffi/win32/{native,sdl,mock}.build`: one virtual `Win32`, three implementations. "another implementation compiles none of them again" (`docs/build.md:237-238`), better than the proposal, whose variants recompile. | Keep |
| 36 | Editions (ideation1:1270-1388) | Sound but already available | Conceded by the ideation: "arguably **better than arbitrary SML**" (:3728), "not much shorter" (:3841), and for platforms "isn't dramatically better" (:3628). | Keep |
| 37 | What a declarative description gives (ideation1:2919-2934) | Sound | Every row in favour of declarative is a requirement of this roadmap: graph without running, IDE inspection, scheduling, reproducibility. The rows in favour of SML are needs no workload here has shown. | D5 |

**Modules**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 38 | Structural, artifact and generative identity must not be conflated (ideation1:357-424) | Sound | Rune has this by way of the name: it is in the key (`unitcache.sml:215-218`) and in link identity (`lib/compiler/backend/link.sml:39`). Two instantiations are two logical names. | D3 must keep it |
| 39 | A graph could share functor code across applications (ideation1:426-448) | Sound but already available | "Each functor compiled once" (`docs/language.md:159`). | None |
| 40 | Applicative functors let the build memoise `F(A)` (ideation1:450-489) | Overstated | Below, *Higher-order modules and applicative functors*. | D23 |
| 41 | Rune "doesn't need higher-order functors" for this (ideation1:491-522) | Sound | Same section. ideation2 then says the opposite. | D23 |
| 42 | Higher-order functors are the decorator system (ideation2:147-242) | Overstated | Same section: every decorator shown reduces to first order. | D23 |
| 43 | "Use applicative functors for shared production dependencies" (ideation2:514-523, :548) | Wrong | The example is one named structure passed to two functors. It means the same in generative SML '97. | None |
| 44 | "Rune's richer module calculus" (ideation2:752; :292, :704; ideation3:8582) | Wrong | Below, *The calculus Rune has*. | Rune 2 |
| 45 | The build IR records requires and provides (ideation2:455-508) | Sound in part | `requires` and `exports` are in the schema. Capabilities, lifecycle and `resolve` are withdrawn by ideation2 (:924-1016). | Schema |

**ideation3's build claims**

| # | Claim | Verdict | Evidence | The roadmap |
|---|---|---|---|---|
| 46 | "The build system is the right authority" for optimiser knowledge (ideation3:8760-8798, :9758) | Overstated | Its "strongest practical precedent" is GHC's interface file (:10077-10111). That is written by the compiler, per module, and Cabal does not read it. The carrier is the unit's interface. Rune's true small version is `inline functor` and `inline val` (`docs/build.md:157-210`): marks, in a build file, for what the compiler already holds. | D1; marks stay |
| 47 | Importing a dependency's build imports its catalogue (ideation3:8470-8527) | Wrong for this roadmap | Planning would run dependencies' build programs. Families and layout predicates need `freshtype` and a typed IR, which do not exist. | Rune 2 |
| 48 | Programmer signature against optimiser contract (ideation3:9657-9696, :10089-10111) | Sound | This is D1's static layer against its ABI and optimisation layer. GHC's `.hi` separation agrees (R, D1). | D1 |
| 49 | Catalogues fingerprint what they describe (ideation3:9453-9486) | Sound but already available | `Config.identity` is in every cache config. Any cross-unit fact must be a usage (obligation O2). | D1, D20 |
| 50 | Closed-world declarations (ideation3:9490-9532) | Untestable here | A closed region needs a boundary that holds: 12 of 88 build files reach in, and the sub-build bypass stands (plan). | After D8; D19, Rune 2 |
| 51 | Scopes: `WithinLibrary`, `RecompiledDependents`, `WholeProgram`, `ABIStable` (ideation3:9121-9159) | Sound, as vocabulary | They name an aggregate's inside, today's see-through, `--whole`, and `_virtual`. | D18 |
| 52 | Do not give build scripts compiler internals (ideation3:9403-9449) | Sound | It applies to handles too, which the document does not notice. | D29 |
| 53 | Separate pure description from effects (ideation3:10510-10532) | Sound | It contradicts ideation1's `project.rune` with `Build.test`. | D29 |
| 54 | Strategies for separate specialisation (ideation3:7993-8019) | Sound as a taxonomy | Generic only, typed IR, generic plus selected, link time, JIT. | E14, Rune 2 |
| 55 | The "genuinely distinctive Rune idea" (ideation3:11183-11197) | Untestable here | Six parts, none of which exists in Rune. | Rune 2 |

### Phase separation: what it takes

The brief wants strict phase separation. Flatt's abstract states the failure: where one language serves two levels, implementers avoid
harm "by obeying certain macro-definition protocols", but "the annotations are fragile, the protocols are not enforced", and mingling "breaks
programming tools that must parse code without executing it" (Flatt 2002). The proposal as written is that failure: `Build.*` by convention.

| System | What enforces the split | What is left open |
|---|---|---|
| Racket | The expander: a phase per binding, an instance per phase (Flatt 2002) | Nothing of this kind, at the price of a module system built for it |
| Template Haskell | The type checker: a splice runs imported code only (`ghc/docs/users_guide/exts/template_haskell.rst:761-771`), now with explicit levels on imports (`:562-745`) | Effects. `runIO` is free, and `addDependentFile` is a manual record (`Syntax.hs:826-837`). A stage-1 compiler cannot run splices (`template_haskell.rst:773-779`): the hosts' position exactly |
| Zig `comptime` | The compiler's evaluator: "All code with runtime side effects or depending on runtime values emits a compile error"; "comptime call of extern function"; "evaluation exceeded 1000 backwards branches" | Nothing: this is enforcement, with a budget |
| Starlark | The interpreter: frozen after load, no recursion, ordered dictionaries (`W/bazel/docs/rules/language.mdx`) | A smaller language |
| Gradle | Tracking of reads, not prevention | Whatever is not tracked |
| Dune's OCaml syntax | Nothing | "you must not build complex systems based on it" |
| **The proposal** | **Nothing** | **Everything** |

So, as written, phase separation here is a discipline nobody enforces. It can be made a property of the design, in Rune, by six things, and it
takes all six:

1. **One output.** A plan value, printed canonically. No `test`, `benchmark`, `compile`, `compileWith`, `emit`.
2. **No observers.** `BUILD` is a signature of abstract types with constructors only: no `name`, `signature` or `interface`. Then a program
   cannot branch on a step, so it is applicative by its type, without an `'a t`.
3. **A Basis view.** Build programs compile against a view without `OS`, `Posix`, `Unix`, `Time`, `Date`, `Timer`, `TextIO`, `BinIO`, `CommandLine`,
   `Dynamic`, `RuneCompiler` or `Real`, and refuse `_prim`, `_dynamic`, `_virtual` and `use`. This is D12's mechanism. E4's prototype view refuses a hidden member at elaboration, in one cache, with S41 and S42 holding (`results/E4/view-measure.md`, T2, T3); hiding whole structures is untested.
4. **Its own process, without a system layer.** `make SYS=none` already builds a VM for which the library reports ENOSYS (`Makefile:125-127`), so a row missed
   from the view is an error, not a leak.
5. **A budget.** `while true do ()` (ideation1:4000) must stop the same way everywhere. VM instructions are countable, deterministically (`--count`). No limit
   exists: `--fuel` counts compiler rewrites (`src/driver/options.sml:161`). A hello compile is 1.82M VM instructions (`results/E2/deltas.md`).
6. **One level per file.** A `.sml` file is a build library's or a program's, never both, or D26's contexts return by another door. Bazel needed a
   visibility system of its own for build logic (`results/E26/notes-holbuild.md`, line 30).

With these, the program is a pure function, and there are no observed inputs to record: its key is the hash of its text and its imports' text, and the parameters.
That removes `Build.env`, `Build.target` as an effect, and all of `'a t`. The platform is an argument.

Notice what the six exclude: `Build.test`, handles, `rewrite` by signature, `Build.env`, `bind`. Every feature that distinguished the proposal from a list of
files is on the far side of the wall. What is left inside is a function from a few strings to a list of files. That is what strict phase separation costs.

### What `Build.source` would have to mean

Every example starts with `val Parser = Build.source "parser.sml"`. The ideation never says in what environment that file is elaborated. An SML file does not name
its imports: its free names resolve against the basis before it. In Rune, "a unit's basis being what the steps before it leave" (`buildfile.sml:1-7`). So elaborating
`parser.sml` needs a prefix of the plan, and the plan is what the build program is computing. Form 2 has only three ways out:

1. **Import lists on every `source`.** Then the program is a `.build` written in SML, and the elaborator could run after it.
2. **Elaboration in the closure of declared dependencies.** That is D2, licensed by D17, and only for units that pass the checker. It cannot be the base case for
   every build: in E8's raw census 112 of the Basis's 259 shared files fit the candidate rules (`results/E8/fit.txt`; the rules are not final).
3. **The program order is the plan,** with elaboration interleaved. That is `reify`, whose answer depends on how far type checking has got: "the type environment seen by
   `reify` includes all the top-level declarations up to the end of the immediately preceding declaration group, but no more" (`ghc/docs/users_guide/exts/template_haskell.rst:324-326`).

There is also the question of what `module` is. `Build.source` returns one value for a file that may declare a functor, three structures and a signature, and `Build.apply MainFn Config`
treats that value as a functor. A file is not a module. SMLSC's footnote 2 says it of units (R).

### `rewrite`

Tested against the four things the brief names, plus the document's own rules.

- **Library abstraction.** `rewrite instrument Application` traverses into libraries, or it does not. If it does, it names private structures from outside: reach-in, the thing D8 exists to end,
  by a route no boundary check sees. If it stops at the boundary, it can only wrap an export, after the library. Then the library's own calls to `Store` go to the unwrapped one, and "wraps
  `Store`" is untrue. The honest form is a seam the library declares: a functor parameter or a virtual module.
- **Text as key.** The key is name plus text hash (`unitcache.sml:215-218`). Either `rewrite` edits a unit's text or it inserts a unit. If it edits, the new text has to exist somewhere with a path: a
  generated file, keyed by its bytes as holbuild does (`results/E26/notes-holbuild.md`, line 7), with positions that no longer match the source, the problem HOL4's filter has now
  (`results/E9/README.md`: "Spans in tree/ are the filtered file's"). If it inserts, it is a one-line unit, `structure Store = LogStore (structure Inner = Store)`, and `.build` says that today.
- **Cacheability.** A closure has no key: "implementing equality on arbitrary task functions" is the unsolved case (Mokhov §6.5). The result can be compared if it is a plan, so caching is
  not the obstacle provided `rewrite` runs before the plan exists. Then it is a function on a list. Its cost in the store is the same as a hand-written wrapper: every client of `Store` sees a new
  binding and recompiles, per variant, down to E13's floor. A seam through `implements` costs none of that (`docs/build.md:237-238`), and `rewrite` cannot put one there.
- **Planning.** A predicate on a name needs only `Deps`' declared names, parsing every file. A predicate on a signature (ideation1:3410-3424) needs elaboration, so the shape of the graph depends on
  an elaborated result: form 2, and monadic. The applicative claim and the signature-driven `rewrite` cannot both stand.
- **Its own rules.** The ideation says strings are "weakly typed" (ideation1:1853-1861), then matches on `"Store"` (:1016). It says decorators must not be reordered merely because types
  match (ideation2:875), and `rewrite` applies them in traversal order, unspecified. Each wrapper is written by hand anyway (`LogStore`, `LogParser`, `LogSolver`), so the traversal saves
  three lines and costs abstraction.

Dune's `(instrumentation)` shows the shape that works: the library opts in, the tool is declared, and the build switches it on (claim 2). `rewrite` is dropped. Named wrappers are one line each.
A generic wrapper, if ever wanted, is a declared tool.

### The matrix Rune has

"Dozens of compiler configurations" reads as a description of Rune. Here is Rune.

| What runs | Where | Size | What varies | Module choices |
|---|---|---|---|---|
| `check-levels` | `tests/runner/oracles.sml:94-115` | 2 targets; 9 builds, 2 compared again; at most 14 runs per program, on 371 programs | `--target`, `-O`, `--units --whole`, `--units -O1`, `--checked`, `--jit` flags | 0 |
| Ways of `tests/lang` | `tests/runner/lang.sml` | 47 | VM binary, GC and JIT flags, host compiler | 0 |
| `check-cross` | `Makefile:62-64` | 7 builds | The host compiler, on the same sources, with its own `main` | One file |
| Compiler mutants | `tests/runner/compilermutants.sml:3-6` | 67 compilers | Exact text edits | 0: an expression has no module boundary |
| VMs | `Makefile` | Many | C build variants | Not SML |

**How variants are made.** `bin/rune-stack` is a one-line wrapper adding `--target=stack` (`Makefile:103-104`). `bin/rune.stack.rbc` is the same sources at that flag (`:1918-1919`). The product is
an SML value in the test runner, `levelTargets`, crossed at `oracles.sml:170-176`, compiling by process call. It skips a cell whose bytes equal an earlier one (`:166-169`).

**What the proposal would change: nothing.** `check-levels` is one plan with fourteen cells of flags. In `Build.compile {root, options}`, `options` is the same list. `Build.test` would move jobs, timeouts,
tiers and `FAIL` lines from the runner into the build language, and make the build program observe run-time results (claim 13).

**The compiler is not functorised.** `lib/compiler` and `src` hold 198 files and **one** functor, `OrdMapFn`. `MainFn` and `CompilerFn` do not exist. The GC is in C, and backends are `--target`. MLton, at 198 functors,
is the kind of program ideation1:2520-2533 describes, and even it does not choose a codegen by composition: it applies all four functors (`main/compile.fun:82-87`) and selects with `!Control.codegen` (`:543-547`). To functorise Rune would be the "fully functorized style": "very cumbersome" (A&M §10), "does
not scale well" (HOPL §5.7), both in R. It is also unnecessary. SML's top-level names are already holes: a `.build` that lists another file binding the same `structure Optimizer` substitutes it with no functor. The
cost is recompiling clients, which `_virtual` removes.

Rune's largest real module-level matrix is the Win32 layer: implementations `native`, `sdl`, `mock`, and generated sets chosen by `$(WIN32_GENERATED)` and `$(SDL_GENERATED)`. That is 2 axes, at most 6 plans.

### The calculus Rune has

| The ideation assumes | Where | Rune |
|---|---|---|
| Higher-order functors, functor signatures | ideation2:147-242, :704, :1043-1044 | No (`docs/language.md`, *Modules*; the parser has no `funsig`) |
| Applicative application, "stable applicative module functions" | ideation2:548; ideation3:8582 | No. Fresh per application: `mod.functor.generative`, `docs/language.md:157` |
| First-class modules, `pack`, `unpack` | ideation2:292 | No |
| `freshtype`, representation equality | ideation3:2740-3892 | No |
| "dependent functors and explicit type sharing" | ideation2:752 | Yes, and that is SML '97: `where type`, `sharing`, a result naming its parameter |
| `.rune` sources, `project.rune`, GC and backend as modules | ideation1:613; ideation2:408; ideation1:1696-1722 | No |

The conversations describe a Rune of their own. What the real one has beyond SML '97 for this purpose the ideation never mentions: `_virtual`, `_dynamic`, `_export`, `implements`, and functors compiled once. `_virtual`
with `implements` is Backpack's hole with something Backpack lacks: real code generation against the signature alone.

### Higher-order modules and applicative functors

**Does build-level composition need more than first-order application? No.** A build function over functors residualises to first-order units. `fun twice f x = apply f (apply f x)` leaves `structure A = F (X)` and
`structure B = F (A)`, which are SML '97. ideation2's decorators look higher-order, but each applies its `F` once, to the `D` it was given (ideation2:173-186, :191-201). So `WithTracing (F) (D)` is `WithTracing' (F (D))`, a first-order
functor over the result signature, and `Compose` is a sequence of lines. Only a decorator that applies `F` twice or to a different `D` would need more, and no example does. The price is not small: MacQueen and Tofte's scheme "necessitates the availability of the
functor body source at the point of functor application", and SML/NJ needed an entity calculus to leave it (`docs/plans/functors-units.md:1143-1146`), against functors-units' design of a body compiled once. What real higher-order functors give is abstraction *inside* the module language, as ideation1:524-573 says
correctly. That is a language question for its own roadmap.

**Does an applicative functor buy anything the store does not? No.** R, D23: Backpack's IR "is simply just a stylized applicative functor language" (Yang §10.4), and memoising an instantiation is a store key. In Rune:
- *Code.* A functor's body is compiled once, so there is nothing to memoise.
- *A unit.* `structure X = F (A)` in a unit is one entry, shared by every plan that holds that unit under that name.
- *Two generative instances.* Two units, two names. Nothing merges them wrongly while the name stays in the identity (claim 38). Two call sites of a build function must get names from the program, not from the text.
- *Run-time state.* Applicativity is a statement about type equality. It does not merge instances. ideation2:525-532 worries about duplicated state, and its cure is one binding, which is SML '97.

What applicativity would add is `F(A).t = F(A).t` between two libraries that each instantiate `F` privately. The SML answer is one shared library holding `structure M = F (A)`. That is a language feature, not a build feature. ideation1:450-489 ties the two
together, and they are not tied.

### Did ideation2's review go far enough?

No. It is honest about dependency injection: it withdraws the container, `resolve`, capability claims, lifecycle, and the composability of decorators. It stops where the build system begins.
- Its revised "Provide" list keeps `Build.replace`, `Build.rewrite`, `Build.test` and `Build.benchmark` (ideation2:1070-1080), the primitives with the worst problems, unexamined.
- Its point 3, that decorators must not be reordered (:844-875), condemns `rewrite`, and it does not notice.
- It keeps "Rune's richer module calculus" (:752) while calling the same syntax "proposed" at :884.
- It asks nothing about plans without running, hosts, the LSP, what a build program's key is, whether `source` is defined, or whether the program being wired is functorised.
- It reviews ideation2 only, and ideation1's claims go through untouched.
- It ends by keeping higher-order decorators (:1131), which it has given no evidence for, and which reduce to first order.

Its best line is the one the rest should have been built on: resolution should "elaborate into an explicit graph and produce a complete manifest showing every selected provider" (:1016). That manifest is the plan.

### The bibliographies

Better than the system descriptions. Of 31 citations sampled from the three documents (`results/I/citations.txt`, `citations-retry.txt`; R's `results/E25/doi-check.txt` covers three of them too), 30 are in Crossref under the authors given. For two, Tate and Willsey, the record found is a later version. *Playing by the Rules*
(ideation3:9800) is not in Crossref and is unverified here. Those that R read say what they are said to say: Mokhov on schedulers and rebuilders (ideation3:10542-10547), Leroy 1994 on type equations in signatures (:1256), Harper and Stone (:1260). Weak spots: "Pierce"
among linking calculi (ideation3:10672) could not be placed, and Bracha and Cook's paper is on inheritance, not mixin modules (:10696).

The failure is of omission. Nothing cites SMLSC or Elsman. Flatt appears once, for units, not for phases. Blume is named without a title. Mokhov appears only in ideation3. Yang is named, but his thesis, which holds the lesson of claim 4, is not cited, and neither Zig nor Gradle appears. The
models knew the papers by title, and did not know what the systems refuse to do.

### The sound core

The smallest thing worth keeping:

1. **A plan is a value, and nothing downstream reads anything else.** (ideation1:4056-4071; ideation2:1016.) The manifest, the provenance, the inspectable graph.
2. **A variant is a plan, chosen by parameters.** A matrix is a list of plans.
3. **Selection is explicit, at a seam.** `implements`, a path variable, or a functor application in a one-line unit. No resolver.
4. **Absence is structural.** What a release does not need is not in its list.
5. **Build identity stays apart from type identity.** Two instantiations are two logical names.
6. **Any SML that computes a plan is a pure function of declared parameters,** against a signature with no observers.
7. **What programs may assume is kept apart from what an optimiser may assume.** That is D1.

Dropped: handles, typed combinators, `rewrite`, `replace`, `Build.test`, `benchmark`, `compileWith`, `Build.env`, `bind`, `resolve`, capabilities. Catalogues go to Rune 2.

**What this needs of `draft/plan-schema.md`:**
- `options` must hold path variables, sorted. Today they are a global cell (`buildfile.sml:168-170`) that vanishes into expanded paths. They name the variant.
- `SImplements` stays. It is the seam.
- `SGenerate` is needed only for a generic wrapper, and D16 needs it anyway for HOL4.
- A named target `{name, build, options}` belongs to the workspace (D4), not the plan. `src/lsp/workspace.sml:9` already has much of that record, as editor settings: `{name, build, flags, variables, libraryRoot}`. That is what a profile is, and where a matrix can live.

**The test of the sketch.** The SML forms use this signature, first-order, with constructors only (R's D29 deduction, untested):

```sml
signature BUILD =
sig
  type step
  type plan
  val unit       : string -> step
  val local_     : step list * step list -> step
  val implements : string * step list -> step
  val plan       : (string * string) list -> step list -> plan   (* options, then steps *)
end
```

Each form gives the same list of plans. The SML sources being composed are the same in both, and are not counted.

**1. Compiler variants** (ideation1:754-936, :2960-3217): 3 × 2 × 2 = 12 plans.

```
(* variant.build *)
lib/opt/$(OPT).sml
lib/backend/$(BACKEND).sml
lib/gc/$(GC).sml
compiler.sml
```
```sh
for o in old new none; do for b in bytecode native; do for g in cheney marksweep; do
  rune --build variant.build --path OPT=$o --path BACKEND=$b --path GC=$g -o rune-$o-$b-$g.rbc
done; done; done
```
```sml
functor Variants (B : BUILD) =
struct
  fun product3 (xs, ys, zs) =
    List.concat (List.map (fn x => List.concat (List.map (fn y => List.map (fn z => (x, y, z)) zs) ys)) xs)
  fun plan (opt, backend, gc) =
    B.plan [("OPT", opt), ("BACKEND", backend), ("GC", gc)]
      [B.unit ("lib/opt/" ^ opt ^ ".sml"), B.unit ("lib/backend/" ^ backend ^ ".sml"),
       B.unit ("lib/gc/" ^ gc ^ ".sml"), B.unit "compiler.sml"]
  val plans = List.map plan (product3 (["old", "new", "none"], ["bytecode", "native"], ["cheney", "marksweep"]))
end
```
Each plan: `{libraries = [], program = [SUnit lib/opt/new.sml, ...], options = [(BACKEND, native), (GC, cheney), (OPT, new)], inputs}`. No functor is needed: each file binds the same structure name. For Rune's compiler this
example is hypothetical in both forms.

**2. Debug wrapper** (ideation1:940-1097, :3221-3464): 2 plans. `wrap.sml` is the same in both: `structure Store = LogStore (structure Inner = Store)`, and two more lines.

```
(* app.build *)
store.sml
parser.sml
solver.sml
use mode/$(MODE).build
app.sml

(* mode/debug.build; mode/release.build is empty *)
local log.sml log-store.sml log-parser.sml log-solver.sml
in wrap.sml
end
```
```sml
functor App (B : BUILD) =
struct
  val logging = List.map B.unit ["log.sml", "log-store.sml", "log-parser.sml", "log-solver.sml"]
  fun plan mode =
    B.plan [("MODE", mode)]
      (List.map B.unit ["store.sml", "parser.sml", "solver.sml"]
       @ (if mode = "debug" then [B.local_ (logging, [B.unit "wrap.sml"])] else [])
       @ [B.unit "app.sml"])
  val plans = List.map plan ["release", "debug"]
end
```
Release holds no logging unit, string or dependency: ideation1:1071-1078 in full. A wrapper goes between the definer and its first client, so a client inside a library needs a seam there.

**3. Platform substitution** (ideation1:1101-1266, :3468-3654): 4 plans, linux and macos sharing `posix`. This is `ffi/win32/native.build`'s shape. No `ApplicationFn` is needed.

```
(* app.build; platform.sml is: structure Platform = _virtual : PLATFORM *)
platform_sig.sml
implements Platform = platform/$(PLATFORM)/export.sml end
platform.sml
app.sml
```
```sml
functor App (B : BUILD) =
struct
  fun dir "windows" = "windows" | dir "wasi" = "wasi" | dir _ = "posix"
  fun plan platform =
    B.plan [("PLATFORM", dir platform)]
      [B.unit "platform_sig.sml", B.implements ("Platform", [B.unit ("platform/" ^ dir platform ^ "/export.sml")]),
       B.unit "platform.sml", B.unit "app.sml"]
  val plans = List.map plan ["linux", "macos", "windows", "wasi"]
end
```
Through one store, a second platform compiles its implementing files alone (`docs/build.md:237-239`). The price is a call through a slot, unless built `--whole`.

**4. Editions** (ideation1:1270-1388, :3658-3876): 3 plans.

```
(* edition/home.build; pro and enterprise are one such line each *)
db/sqlite.sml auth/local.sml reports/basic.sml cluster/single.sml

(* app.build *)
use edition/$(EDITION).build
features.sml
app.sml
```
```sml
functor App (B : BUILD) =
struct
  fun features "home" = ["db/sqlite.sml", "auth/local.sml", "reports/basic.sml", "cluster/single.sml"]
    | features "pro" = ["db/postgres.sml", "auth/local.sml", "reports/advanced.sml", "cluster/single.sml"]
    | features _ = ["db/postgres.sml", "auth/ldap.sml", "reports/advanced.sml", "cluster/distributed.sml"]
  fun plan edition = B.plan [("EDITION", edition)] (List.map B.unit (features edition @ ["features.sml", "app.sml"]))
  val plans = List.map plan ["home", "pro", "enterprise"]
end
```

| Example | Plans | `.build` + enumeration (lines) | SML (lines) | SML / `.build` | Is `.build` plus a parameter enough? |
|---|---|---|---|---|---|
| 1. Variants | 12 | 4 + 3 | 10 | 1.43 | Yes. The enumeration is outside the build file |
| 2. Debug wrapper | 2 | 8 + 1 | 10 | 1.11 | Yes for named wrappers. A generic one needs `SGenerate` in either form |
| 3. Platform | 4 | 4 + 3 | 9 | 1.29 | Yes. It is in the repo |
| 4. Editions | 3 | 6 + 1 | 8 | 1.14 | Yes |

Non-blank lines, `results/I/counts.sh`. Leaving out the three lines of functor wrapper, which flatters SML, the ratio is 0.71 to 1.00. Neither form saves anything worth a language.

**Where SML does win, plainly.** Two places:
- a *derived* axis, `fun gc (Linux, X86_64) = ParallelGC | gc (_, Wasm32) = SimpleGC | gc _ = CheneyGC` (ideation1:3646), which `.build` can only express as a table in the driver;
- keeping the matrix and its exclusions in one artefact (ideation1:3941-3948).

But Rune's driver is already SML, in the runner. And a variant multiplies LSP contexts in either form. With `implements` all variants' clients have the same resolved uses, so D26 prompts for nothing; a matrix without seams is the LSP's worst case, however it was written.

**A generator already gives this.** Any SML program can print a `.build`. `runeffi` does, into hash-named immutable sets, with a `current.build` pointer (`src/ffi/main.sml:115-144`). Dune's documented route is the same: generate `dune.inc`, commit it, and have a test `diff` it
against a fresh run (`W/dune/doc/reference/dune/include.rst`). The output is text that the LSP, `--build-list` and the awk reader all read, and no compiler feature is needed. The ideation calls this "introducing a meta-build language" as a fault (ideation1:3050). It is the feature, with the plan
kept visible.

### Verdict

**D5, the form.** A typed plan as the contract, with `.build` as its normal form. Form 2 (handles) is rejected without prototype: it fails property 2 by construction, `source` has no definition without the plan, and Backpack'14 is its history. E12's `--typecheck-only` lower bound, 5.31G on the flat list, is for the record; that list avoids
`results/E9/bugs/typecheck-only-exports`, which loses exported signatures and functors. Form 1 survives only as "a program that prints a plan". The word "typed" in the plan's name means the schema's type, not that compositions are checked before stage 0.

**D23, higher-order modules and applicative functors.** Not now. Nothing here needs more than first-order application, and an applicative functor adds no store hit. `docs/plans/rune2/separate-compilation.md` keeps them as an open question.

**D29, phase separation.** If any SML computes a plan, it is a pure function of declared parameters to a plan. The build Basis is the six walls above. There are no observed inputs: no `Build.env`, no file reads, no globbing, and `.build` has none either. The key is
the program's text, its imports' text, the parameters and a version of `BUILD`. It never runs for `rune.build`, on a host, or in a reader. This is stricter than `draft/plan-schema.md`'s property 2 and removes a mechanism from it.

**Gate G2: does the term layer earn its place?** The term layer here means a compiler feature: the compiler runs a build program, under the walls above, and stores its plan. All seven must pass, in order, and failing test 1 ends the matter.

| # | Test | Passes at | Today |
|---|---|---|---|
| 1 | **Demand.** The largest module-level matrix in a checked-in project that a tier or a maintained benchmark actually runs, excluding anything written for the gate. Axes must choose units, not flags | ≥ 12 plans, ≥ 3 axes, at least 1 derived axis. 12 is where ideation1:3038-3048 says "The pain appears immediately" | **6 plans, 2 axes, 0 derived. Fails** |
| 2 | **Saving.** Non-blank lines of SML against `.build` plus enumeration on that project, by E12's script | ≤ 0.5. A smaller saving does not pay for a second way, against brief line 6's "one way of doing things" | 1.11-1.43 on the ideation's four |
| 3 | **It beats a generator.** The same project with a plain SML generator, committed output and a `diff` check. 10 seeded edits to its inputs | ≥ 1 stale plan reaches a build undetected. If none does, integration buys nothing and the generator is the answer | Not run; expected 0 |
| 4 | **Equal plans, nothing runs.** Byte-equal canonical plans on all E12 workloads. With the program deleted, the LSP, `--build-list` and the hosts answer the same | 0 differences | **Byte-equal on the four examples, on three conditions** (E12); the run with the program deleted was not done |
| 5 | **Phases.** A fixture of 15 escapes: clock, date, environment, arguments, file read, directory listing, process, socket, `use`, `_prim`, `_dynamic`, `Dynamic.load`, FFI, `RuneCompiler`, `Real`. Three runs under different environment, directory and time. A non-terminating program | 0 of 15 compile; 3 identical plans; stopped at 10^8 VM instructions (55 hello compiles) with one message | Not built |
| 6 | **Editor cost.** An edit of a build program to a fresh plan, and a read of a stored plan, on the 1000-build fixture | ≤ 250 ms p95, the LSP plan's proposed leaf budget; stored read ≤ 2 × a `.build` read | **Fails on the one workload run:** 462 ms, 116 times a `.build` read, with a floor of 32 (E12). A stored read is 0.2 times. Not run on the 1000-build fixture |
| 7 | **S43.** Hosts and bootstrap build from `.build` alone | 0 dependence on a build program | By rule |

**It should not be built now.** Test 1 fails by a factor of two on plans and has no derived axis. The compiler, the workload the ideation names, has no module-level axes and one functor. The ideation itself concedes platforms and editions, Rune already does platforms, a debug wrapper is one line per module, and the
matrix is a loop. A term layer needs a Basis view, a VM mode, a budget, a store kind, an LSP context kind and a second way of writing builds, against brief line 6, and it must leave `.build` in place, for hosts and for build programs' own dependencies. Because the plan is
the contract, nothing is foreclosed: if a real project meets test 1, the layer can be added without any reader changing. So B1 moves to *Later* with this test attached, G2 stays the owner's to overturn, and the roadmap documents the generator route, which costs a paragraph.

### For Rune 2, a line each

- **Generativity as an effect on the functor arrow** (ideation3:1390-1404, :2254): the core of a higher-order modules roadmap.
- **Application as a path against a computation** (ideation3:1615-1695): the same roadmap.
- **Three module IR stages** (ideation3:2672): compare with E14's one IR.
- **`freshtype` and coercions** (ideation3:2740-3892): language design, with roles as the known hard part (:4466-4587).
- **Implementation families over capabilities, with a generic always present** (ideation3:5300-6595, :5809): specialisation, Rune 2.
- **Programmer signature against optimiser contract** (ideation3:9657-9696): a target for D1's layers when IR goes in units.
- **Strategies for separate specialisation** (ideation3:7993-8019): the IR question, with E14.
- **Optimisation scopes** (ideation3:9121-9159): vocabulary for what crosses a boundary.
- **Closed regions** (ideation3:9490-9532): once boundaries hold, with optimising aggregates.
- **Evidence levels on rules** (ideation3:9373-9395): `formal-verification.md`, if ever.
- **Profile-guided selection** (ideation3:11060-11095): later still.

## The experiments

Twenty-eight experiments and one model came before the writing, by nine agents and the lead. Three of them, E25 to E27, are reading. The rest ran.

**How they were gathered**
- **The tree.** Everything measures master `b12141ecc`. `.worktrees/bs-base` is the reference: built once and never modified, and every `path:line` here is against it. Each agent worked in a detached worktree of its own, copied from it: `bs-lib` (L, then P, then U), `bs-sep` (S, then M), `bs-cache` (C), `bs-lsp` (A, then E).
- **The inputs,** never edited: MLton's sources, HaMLet, the corpus. HOL4 was built once, in a clone under the drafts' `hol/` at `65ab0d8e6`, with `docs/plans/hol4-overloading-declaration.patch` applied, since those annotations are not on `rune-build`. Nothing was built in the owner's submodule.
- **The evidence.** Every number comes from a script kept with its raw output. Script paths are relative to `~/.cache/claude-rune-drafts/build-system/`; within a section, a bare name is in that experiment's directory.
- **The claims rest on instruction counts,** which do not vary with load: `instructions:u` from `perf stat`, which is machine instructions, and `runevm --count`, which is VM instructions. The two differ by a large factor and are named where they appear. A figure in G with no name is `instructions:u`. Spread over five runs was 0.0-0.3% (E2). The compiler ran at tier 2 unless said.
- **Seconds and peak memory are indications.** The machine has 31 GB and was shared with other sessions. Load was 3-7 for C and U, 3.5-7 for L, 4-14 for A, 5-15 for S, and 7-24 for P.
- **The prototypes** were throwaway, kept as patches in the drafts (`patches/`). None of them lands.
- **"Observed"** means an experiment ran it. **"Deduced"** means it comes from reading.

**The two waves.** Wave 1 (L, S, C, A, R) asked what is there today: E1-E10, E15, E16, E18-E22, E25-E27. Wave 2 (M, P, U, E) were fresh agents with narrow briefs who read wave 1's reports: E11-E14, E17, E23, E24, E28. They came second because they build on wave 1's results, and because several of them could claim the same saving.

**Predictions were written down before running,** in `results/<E>/PREDICTION.md`. Each section below states them and says where they were wrong. Two were written late: E9's after a first translation of MLton's `.mlb` files, and E18's after its first hole had turned up in E15. E25 to E27 have none, being reading. L1 has none on file. The wrong predictions are kept because they show what reading the code did not tell the people who read it.

**Why wave 2's numbers name their baseline.** E11, E23 and E24 all stand on the eager basis load that E15 removes. That load is 74% of MLton's no-op in instructions, and under 5% of HOL4's and `rune.build`'s in wall time, so a saving measured on top of it says little about a tree without it. Each of these experiments reports on today's tree and on `patches/E15-warm.patch`, and a number on the patch carries E15's letters (a, b, c, d, l, u; see E15). A number with no letters is today's compiler. So the roadmap never counts one saving twice.

**The programs** used throughout:

| Name | What |
|---|---|
| `rune.build` | the compiler's root build: 106 project files, 43k lines; 246 units with the Basis files it selects (E15), 245 in analysis, which has no `epilogue.sml` (E17) |
| MLton | MLton's compiler: 606 files, 198k lines; 791 units with the Basis |
| HOL4's closure | the `src/boss` closure after HOL's filter: 746 units in `results/E9/hol4/boss.build`, 744 once a duplicate `Systeml` is dropped; 212k lines; 922 units with the Basis |
| HaMLet | its 215 files at `/home/ruud/rune-hamlet`, in units; `hamlet` in lower case is the benchmark `examples/benchmarks/hamlet` |
| `f100k`, `f300k`, `f1m`, `s1m` | fixtures from `results/E20/gen.py`: 117k, 351k and 1.17M lines; `s1m` is the sparse million |
| a no-op | a warm build with nothing changed |
| a leaf | a warm build after a body edit of one unit |

**Every experiment, and what it feeds:**

| | Experiment | By | Feeds |
|---|---|---|---|
| E1 | The census, exact | L, wave 1 | D4, D6, D7, D9, D10 |
| E2 | What MANIFEST costs | L, wave 1 | D13 |
| E3 | Boundaries on, everywhere | L, wave 1 | D6, D7, D8, D10, D11, D15 |
| E4 | Basis views | L, wave 1 | D12 |
| E5 | Rules as a checker | S, wave 1 | D2, D6, D17 |
| E6 | Effects, by permutation | S, wave 1 | D2, D6, D7, D17 |
| E7 | The Definition stays whole in the REPL | S, wave 1 | D17, D20 (O8) |
| E8 | Who fits | S, wave 1 | D17, Rune 2 |
| E9 | HOL4 and MLton through one build file | S, wave 1 | D2, D3, D6, D7, D16 |
| E10 | Functor signatures | S, wave 1 | D3, D22, D23 |
| E11 | Aggregates | U, wave 2 | D19, Gate G1 |
| E12 | The build language's form | P, wave 2 | D5, D14, D16, D29, Gate G2 |
| E13 | What a firewall could save | M, wave 2 | D1, D3, D7, D18, D24, D25 |
| E14 | What can go in a unit | M, wave 2 | D19, D24, Rune 2 |
| E15 | Where a warm build goes | C, wave 1 | D1, D2, D19, D24, D25, D27 |
| E16 | Identity policies | C, wave 1 | D3, D24 |
| E17 | Interface layers | U, wave 2 | D1, D24, D27 |
| E18 | Independent checks of usages | C, wave 1 | D1, D2, D7, D13, D20 |
| E19 | Codecs | C, wave 1 | D1, D21 |
| E20 | Real runs and the scale fixture | A, wave 1 | D1, D16, D26, D27, D28 |
| E21 | The batch compiler at scale | A, wave 1 | D25, D28 |
| E22 | Contexts that are the same | A, wave 1 | D3, D4, D26 |
| E23 | Cut-off in analysis | E, wave 2 | D1, D3, D26, D27, D28 |
| E24 | Analysis from units, and units from analysis | E, wave 2 | D1, D2, D24, D26, D27, D28 |
| E25 | Modules and separate compilation (reading) | R, wave 1 | D1, D4, D9, D17, D20 |
| E26 | Implementations (reading) | R, wave 1 | D1-D25, by system |
| E27 | Editors at scale, and tests against abstraction (reading) | R, wave 1 | D4, D11, D26, D27, D28 |
| E28 | Migration | P, wave 2 | D7, D8, D10, D13, D15, D16 |
| L1 | A model of the cache | the lead | D1, D18, D20 |

### E1. The census, exact

**Question.** What do the 88 tracked build files use, who reaches into a library, what do the libraries really depend on, and which names clash?

**Prediction** (`results/E1/PREDICTION.md`).
- 15 generated files, of which 10 in sets and 5 pointing at them: right. The plan's "15 in hash-named sets" was the slip.
- `group`, `local`, `cache` and `allowPrim` at zero: right.
- Reach-in, 12 of 88: right for hand-written builds. The mechanical rule finds 17.
- 3 to 8 missing direct edges: wrong by a little, 12.
- "A similar number" of declared edges unused: wrong, 1.
- Clashes: exactly as predicted.

**How.** `results/E1/census.sml` reads every build through the compiler's own `BuildFile`, `Deps` and parser, never by grep (`census.sh`, `census.py`; `tables.md`, `reach-in.csv`, `edges.csv`, `clash.csv`, `exports.csv`). `verify.sh` and `clash-demo/` test the claims against the compiler. No file was refused. The constructs are in *Where we are*.

**Result.**
- **Reach-in,** by the rule "a path under the directory of a library not your own, deepest `library.build` wins": 17 of 88. 12 are hand-written: `rune`, `runedoc`, `runeffi`, `runeisa`, `runeopt`, `tests/compiler/{lint,state,witness}`, `tests/lsp/syntax`, `tools/compiler/state-audit`, `tools/lsp/bench`, `tools/lsp/syntax-bench`. 5 are the generated pointers. 9 more go through a path variable or into `lib/` outside any library. Of the root builds, only `runelsp.build` does not reach in.
- **The true graph of the 33 libraries** (appendix C):
  - names used outside the declared closure: 0;
  - edges used but reached only transitively: 12, of which 7 hand-written and 5 generated;
  - declared and unused: 1 (`test/unit` to `random`; removing it changed only the MANIFEST's header line, and 142 files were chosen both ways);
  - cycles: none.
- **Trust.** Each of the 32 libraries beside the Basis elaborates from its declared closure alone, with a program naming all its public names, and `--basis-check` passes on all 32 (`verify.out`).
- **Only the Basis has top-level values, datatypes or exceptions.** No other library has one.
- **Clashes:** 15 names are public in two or more libraries, 12 of them between generated alternatives never loaded together. Three are real: structure `History` and signature `HISTORY` (`terminal`, `test/runner`), and structure `RuneCompiler` (`basis`, `compiler`). No name crosses kinds. `lib/compiler`'s private names collide with nothing public.
- **Observed** (`clash-demo/demo.out`): any program with `test/runner` in its closure cannot reach `terminal`'s `History`, in either order on the command line.

**For the roadmap.**
- D6: `group`, `local` and `cache` have no uses, so nothing migrates if they go.
- D7: declared dependencies are cheap: 7 hand-written additions, 5 generated, 1 removal.
- D9: three real clashes today, so clash errors and two renames cover this repo. Namespaces are for the scale target, not for today's tree.
- D10: a reach-in warning hits 12 hand-written builds, and E3's friend view answers the test builds among them.

### E2. What MANIFEST costs

**Question.** What does `--basis-index` cost against a read of its output? What does a stale MANIFEST do? What breaks first if it goes?

**Prediction** (`results/E2/PREDICTION.md`).
- The index, 200-400M instructions: wrong, 623M, because of `Deps.analyse`'s list work and a read of each file.
- A read, 0.5-1M: wrong, 6.44M. The agent confused VM with machine instructions; the VM figure is 0.82M.
- Their ratio, 300 or more: wrong, about 97.
- An index per compile multiplies hello by at least 3: right, 3.1.
- "at least one silent wrong answer exists": too mild. Six of 15 scenarios are silent wrong answers.
- A new dependency between library files is an error: wrong. `select`'s second pass repairs it.
- Stage 0 can write the index with no MANIFEST: right.

**How.** `measure.sh` with the tool `manifest-cost.sml`, five runs each (`raw.tsv`, `table.md`, `deltas.md`). `stale.sh` edits a library or its build and leaves the MANIFEST (`stale.out`). `gone.sh` removes it (`gone.out`).

**Result.** Above a no-op of the same tool, or of `--version` for the index:

| What | `instructions:u` | VM instructions |
|---|---:|---:|
| read the Basis's MANIFEST | 6.44M | 0.82M |
| read and select, hello | 9.12M | 0.87M |
| read all 33 | 19.62M | 2.47M |
| `--basis-index lib/basis` | 622.93M | 70.31M |
| for scale: a hello compile, whole process | 296.31M | 2.16M |
| for scale: a `--library json` compile, whole process | 1,076.35M | 43.38M |

The index costs about 97 times a read in `instructions:u`, and 86 times in VM instructions. MANIFEST is 3.1% of a hello compile. An index per compile would make hello 3.1 times the cost. In time: 141.8 ms for the index against 64.8 ms for hello's whole compile.

**A stale MANIFEST, 15 scenarios** (`stale.out`):

| Outcome | Scenarios |
|---:|---|
| 6 | a silent wrong answer: a new shadowing file; a library file shadowing a Basis name; demand to always, so an initialiser does not run; two files swapped; a boundary added, the hidden name still visible; a library adding a Basis name |
| 7 | an error |
| 2 | correct by accident: a name added in a file already loaded, and a new dependency repaired by `select`'s second pass |

`--basis-check` passes on 4 of the 6 silent cases, since it never reads `library.build`. The cache stays sound across a stale MANIFEST: index made, rolled back and `--verify-cache` all give the right result.

**If it were gone** (`gone.out`, observed): every compile, `-j`, `runedoc` and `--basis-check` stop at once on `readManifest`, loudly. Reading the code, what breaks next is everything that reads the file by path as a text table: `dist.sml`, `vscode.sml`, the host tools. `scripts/install.sh:300-311` loops over `find . -name MANIFEST`, so it would copy no library (E28).

**Stage 0** does not build without an index. It makes one first. Observed: with no MANIFEST, and over a garbage one, `--basis-index` writes the bytes of `lib/basis/MANIFEST`. Other libraries need their dependencies' MANIFESTs first.

**The two checks of `--basis-index`** exist in `--basis-check` too, and both read a MANIFEST, so they go with it unless rehomed.

**For the roadmap.** D13: never compute the index per compile. Keep a stored index validated against `library.build`, since `--basis-check` is blind to 4 of 6 silent cases. Rehome the path readers first, and `install.sh` before anything.

### E3. Boundaries on, everywhere

**Question.** If every library had an export list derived from its clients, what would break? Do the holes in a name filter exist? What do tests need from inside? Can partial import replace selection by mention?

**Prediction** (`results/E3/PREDICTION.md`).
- 40-60% of names unused by clients: held, 55%, or 31% once `runedoc`'s signatures count.
- Fewer than 5 libraries fail, by top-level values: wrong on both counts. No library but the Basis has one, and the compile broke nowhere.
- `datatype u = datatype t` recovers dropped constructors through an exported name: wrong, except in one form below.
- A private type works through an exported signature, unnamed: right.
- The second `use` bypasses a boundary: right.
- Tests need names more than representation, over 80%: right, and stronger: no test defeats an ascription.
- A friend view costs no cache key: right. That it would be 2.8 times cheaper cold than reach-in was not predicted.
- Start-up depends on mention only for the Basis: right, but compile cost matters more than start-up.

**How.** Candidates from every non-benchmark client (`derive.py`, `candidates.md`), turned on in two rounds (`run.py`, `compile-all.py`; `compile-round1.tsv`, `compile-round2.tsv`), over 159 programs that pass at baseline: 62 Makefile recipes, 84 single files, 13 builds. 31 libraries wrapped. The holes: `holes/run.sh`, `holes/output.md`. Tests: `tests-need.py`, `tests-reps.py`, and one friend mechanism prototyped (`friend-measure.sh`; `patches/E3-friend.patch`). Partial import: `partial-run.sh`, `mention/run.sh`, `select-uses.py` (`patches/E3-select-by-uses.patch`).

**Result: boundaries are a pure filter.** Beside the Basis and `lib/compiler`, 372 names are public. Round 1 keeps 166 and hides 206 (55%). Round 2 adds 90 signatures, keeps 256 and hides 116 (31%).

| Check | Result |
|---|---|
| real compile, both rounds | 159 of 159, 0 byte differences |
| `--typecheck-only` | 155 of 159; the 4 are one bug (appendix D) |
| chosen files, 146 programs that are not builds | identical |
| S41, S42, units against none, `--verify-cache`, 4 programs (`units-check.md`) | all hold |
| compile cost (`boundary-cost.md`) | +0.4 to +0.5%; +5.49% on `test/property/basis` |

The +5.49% comes from MANIFEST's format, which repeats a sixth column on every row: `test/property/basis` goes from 12.8 KB to 124.8 KB, and a 259-name boundary on the Basis would be 1.5 MB.

**The break is `runedoc`, not the compiler.** Of 22 wrapped libraries that pass at baseline, 21 are refused: "Json claims to implement JSON, which is no signature of the library" (`runedoc-compare.md`). `runedoc` already enforces a closure rule the compiler does not. Round 2's 90 ascribed signatures fix all 21 (`runedoc-compare2.md`). They leave `test/unit`, which failed at baseline anyway, needing `SUITE_MAIN`, which the regex missed and E28 finds.

**The Basis cannot have a boundary today** (`basis-boundary.sh`). `Deps` declares no top-level datatype, so the index refuses one. With those names dropped, `--units` loses every value (`print` is unbound), and whole ignores the boundary, so whole and units disagree.

**The holes, observed** (the same in whole, units and units-whole):
- A private type through an exported signature works unnamed, including equality and re-ascription. Naming it is refused. Sound, as a filter.
- `datatype u = datatype t` does not recover constructors through a signature, transparent or opaque, or through an exported abbreviation. It does in one place: a program-level `library (type t)` over a top-level datatype. `--basis-index` refuses that form.
- `library (structure Pub) = use x.build end  use x.build` gives `PRIVATE`. So do the same across build files, after `local` and after `implements`. An export naming nothing is accepted silently.

**Tests** (`tests-need.py`, `tests-reps.md`).
- 68 names are exported only because of tests. 59 are the test libraries' own API, and 9 are real: `terminal` 4, `ffi/model` 2, `ffi/win32/common` 1, `language/c` 1, `zmtp` 1.
- `lib/compiler` has 91 private structures: 87 unascribed, 2 transparent, 2 opaque. The five test programs that reach in name 2 to 21 private modules.
- So tests need names, not representation.

A friend list in `library.build` is one keyword and 35 lines. The library names its tests. All four friend builds compile; a build that is not a friend is refused, and the same file there is recompiled and refused, not served from the cache (`friend-measure.md`):

| Cold, instructions | Reach-in | Friend |
|---|---:|---:|
| lint (units compiled) | 27,417M (97) | 9,941M (1) |
| state | 27,439M (97) | 9,127M (1) |
| witness | 26,979M (97) | 7,469M (1) |
| syntax | 32,126M (120) | 13,035M (27) |

The friend reuses the frozen layer, and no key changes. One cost: a friend loads by mention, so `state-analysis` sees 328 roots against 334.

**Selection by mention is a semantic hole.** `fn F => F + 1` and `fn E => E + 1` print differently when a library file declares `structure E` with an initialiser; so does a record label `{E = 1}` (`mention/run.sh`, `mention/output.txt`). `libraries` means available; mention means loaded. Every small program depends on it (`partial-run.md`):

| Program | Files, by mention | Files, `--basis all` | Compile | Start-up |
|---|---:|---:|---|---|
| hello | 2 | 278 | 295M → 3,551M | 0.6M → 11.8M |
| hello, `--units` | | | 245M → 4,225M | |
| json | 39 | 297 | 1,075M → 4,202M | 1.5M → 12.4M |
| test/unit | 132 | 303 | 2,356M → 4,351M | 18.5M → 26.3M |
| compiler | 221 | 390 | 11,862M → 14,330M | 20.0M → 28.3M |

Hand-written libraries have a median export closure of 1 to 6 files. Only the Basis (12 of 278, at most 68) and `lib/compiler` (13 of 93) are large (`partial-closures.md`).

Selecting from `Deps`' uses instead of tokens is about 15 lines (`select-uses.out`, `select-uses-lang.out`): 146 programs, 0 failures, 132 identical with equal bytes, 14 with fewer files, none with more; 623 files of `tests/lang`, basis, overloading and functors with identical exit codes. It closes the alpha-renaming hole.

**For the roadmap.**
- D7: separate "available" from "loaded", and replace token selection with `Deps`' uses. It is a drop-in.
- D8: the boundary stays a name filter and needs no closure check for soundness. Add the rule that a public structure's ascribed signature is public. Close the second `use`. Make program-level `type` exports match the index's rule.
- D11: tests need names, and one friend list suffices.
- D15: export lists derive mechanically, given the signature pass.

### E4. Basis views

**Question.** What are SML/NJ's and MLton's old-basis mechanisms, what would one seal set cost hooked before `wanted` in `select`, and what must a library and a client on different views mean, given that the cache config is global?

**Prediction** (`results/E4/PREDICTION.md`).
- Views are filters over one implementation: right for SML/NJ. MLton's `basis-1997.mlb` is more: convert functors re-implement the old API on the new.
- 30-50 lines of driver, one signature per structure: right, about 35.
- No new config if the view is no cache setting: right, on a condition not predicted: the seals must load after the libraries.
- One global `mentioned` cannot express a per-library view: right, though a private seal file inside a library's boundary gives one today, which was not predicted.

**How.** Reading of `basis-2004.cm`, `basis-2002.mlb`, `basis-1997.mlb`. A `seal@VIEW` row filtered before `wanted`, with `--basis-view NAME` and `.build`'s `view NAME` (`patches/E4-view.patch`). `results/E4/view-measure.sh`, `view-measure.md`. The hidden members were chosen for the test, not from history, and the view covers 4 structures.

**Result** (`view-measure.md`):

| Question | Observed |
|---|---|
| a hidden member, in the view | refused; the default is unaffected |
| one cache, two views, both orders | 1 config directory; the usage check on the binder catches it, with no key change |
| S41, S42, `--verify-cache` in the view | hold |
| frozen layer, seals after the libraries | +4 units, +12.5 KB, no new config |
| seals before the libraries, MANIFEST's order | 96 more units, then exit 1: `String.isSubstring` at `lib/compiler/frontend/lexer.sml:217`, `Option.app` at `lib/compiler/elab/env.sml:40` |
| library on the default, client in the view | works; values and types cross |
| a library's functor wants `LIST`, client in the view | refused: signature mismatch, its `List` is narrower |
| a library re-exports `structure L = List` | the client reaches the hidden member: a view filters names and is no capability |
| a per-library view | a private seal file inside a library's boundary works today, with no compiler change |

**For the roadmap.** D12: the position of the seals is the design. They load after the libraries, a view is a client-side filter, no config per view. Per-library views are seals inside a boundary. `library (...)` cannot be the Basis's mechanism, since it carries no values, fixity or datatypes.

### E5. Rules as a checker

**Question.** Which candidate rule on a unit does each mechanism really need: dependency order, cut-off, closures (D2), firewalls, the LSP?

**Prediction** (`results/E5/PREDICTION.md`).
- Every parser-tier rule is needed by exactly what must read dependencies from syntax, and warm cut-off needs none: held.
- Firewalls need something else, a signature on a shared unit: held.
- Fixity is the worst rule: held.
- Nothing compiled with the default modes crosses a unit's end: held.
- A top-level `val` in a shared unit is a visibility matter, not a soundness one: held.

**How.** `results/E5/tool/sepcheck.sml` (`patches/E5-sepcheck.patch`) works by the parser: 9,503 files in about a minute. `probes/cutoff.py` breaks each rule in a shared unit and changes something unused. `probes/a[1-3].sml`, `b[1-3].sml` are two-file programs that cross a unit's end. `elab/modes.py` typechecks the corpora under each mode. `closure_test.py` compiles a unit from its dependency closure alone and compares it with the full build.

**Result.** Every rule against every mechanism is appendix A. In short:
- **Keep for shared units:** no top-level `val`, `fun`, `exception`, `datatype` or replication; no top-level `open`; no top-level fixity, or make fixity an export; one module name in two units (S19), by scope and not by group.
- **Drop:** no `use`, since batch has none; nothing private in a `local` head, which hits MLton's `regexp.sml` and `bits.sml`, 168 HOL scripts and 27 HOL entry files; no bare `val _ =`, since an effect inside a structure is allowed anyway.
- **Firewalls only:** a signature on each shared structure.

**Warm cut-off needs no rule** (`probes/cutoff.out`). With a shared unit breaking each rule, an unused change rebuilds no client. A client's own `open` costs precision: "its entries used s M". Firewalls need something that does not exist today: a private change behind `:>` still recompiles the client.

**`Deps` parses with `Fixity.initial`** (`main.sml:235-236`), so a graph can come from a wrong parse. `rune --deps` on HOL's closure stops at `tree/src/1/Conv.sml:205:6` (`results/E8/deps-hol.err`), and on MLton's flat list reports 7 breaks (`results/E8/deps-mlton.err`).

**D2 tested directly.** Rune: 22 of 22 sampled units byte-identical from their closure, `.rbu` and `.rbi`, mean closure 29.5 of 106 files (`closure-rune.txt`). HOL4: mean closure 226 of 746, none refused; the kept output shows 28 of 30 identical (`closure-hol.txt`), and S's report says the other two, `SHA1_ML.sml` and `HolSatLib.sml`, matched once the duplicate `Systeml` was removed. That rerun's output was not kept. HOL needs one added edge: `Overlay.sml` before all later files.

**Elaboration tier** (`probes/crossing.sh.txt`, `elab/summary.txt`). The default modes cannot cross a unit's end. `--flex-records=program`, `--free-tyvars=later` and `later-monotype` are accepted whole and refused in `--units`, which for a crossing program breaks S42 by design. Overloading crosses in no mode. Of 1,514 regression programs, 13 pass only with `later-monotype` and 1 only with `overloading=topdec` or `toplevel`. The `tests/lang` cases are almost all tests of the modes themselves.

**Signature shape of shared units** (structure bindings, from `results/E8/files.json`):

| Corpus | `:>` | `:` | bare | functors with no result signature |
|---|---:|---:|---:|---:|
| Rune | 161 | 124 | 247 | 13 of 30 |
| MLton | 11 | 66 | 25 | 12 of 252 |
| HaMLet | 36 | 56 | 28 | 8 of 17 |
| HOL closure | 340 | 2 | 48 | 1 of 8 |

So HOL is firewall-ready in syntax, and Rune is not.

**For the roadmap.** D17: rules by scope, and drop the `use`, `local`-head and bare-effect rules from `Deps`' discipline. Fixity is what really breaks `Deps`: make it an export or a property of a prelude unit. D2: closures were byte-safe on these samples, given scoped S19 and a closed `use`.

### E6. Effects, by permutation

**Question.** Hidden effect dependence cannot be read off the syntax. If legal orders are permuted, do bytes or output change?

**Prediction** (`results/E6/PREDICTION.md`).
- The linked file's bytes differ on every permutation: right, 914 bytes on Rune.
- A few units' own bytes change: wrong. None do once names are unique.
- Rune's libraries and the compiler are insensitive: right.
- MLton's compiled output is insensitive: right.
- At least one project breaks under a legal permutation: right, and only HOL4.
- A sound proxy is far too strict: right.

**How.** `perm.py` and `perm_build.py` draw random orders legal under `Deps`' edges. `rune-perm.sh`, `rune-selfcheck.sh`, `mlton-perm.sh`, `ham-perm.sh`, `hol-perm.sh`, `bench.py` compile them. `cmp_units.py` compares `.rbu` and `.rbi` by source. `hol-probe.sml` prints what a HOL session holds. The proxies are counted by `results/E8/analyse.py` and `results/E5/tool/sepcheck.sml`.

**Result.**

| Project | Orders | Units the same | Output |
|---|---:|---|---|
| Rune compiler, 106 files | 3 | 246 of 246 | each compiled the compiler in units and whole, same md5 (`rune/self.md5`); 51 `tests/lang` programs the same |
| MLton, 536 and 549 of 606 moved, inside each `.build` | 2 | 791 of 791 | each takes `hi.sml` to identical C (`mlton/gen-*.md5`) |
| HaMLet, 215 files | 3 | 310 of 310 | the same on its 34 tests |
| Benchmarks | 2 each | the same on 386 | 386 the same; 122 have no other legal order; 2 refused (`bench/run.log`) |
| HOL closure | 3 | 923 of 923 with the duplicate removed; 16 of 925 differed with it | **2 lines differ** (`hol/nd-*.run`) |

The per-unit counts come from `cmp_units.py`, whose output was not kept. The orders, md5s and runs were.

- **The only hidden effect dependence is HOL4's.** `Theory.ancestry` order and the `srw_ss` fragment order change with load order. All other probe lines match, including `DECIDE`, `EVAL`, the type base and grammar counts. Whether fragment order changes a proof was not tested.
- **The hidden edge that made HOL fail outright** is `src/thm/Overlay.sml:42`, `open Kernel`, and `:49`, a datatype replication. They rebind `Term`, `Thm` and friends and bring in `QUOTE`. That `open` is HOL's kernel seal. Held in place by `perm.py`'s barrier, every order compiles.
- **S19 is the only cause of a unit's bytes changing:** the duplicate `Systeml`, and `lcss-nofib-*`, where a `structure Benchmark` uses the earlier `Benchmark` of the same name, an edge `Deps` drops.

**Two proxies** for "this unit's initialiser matters", as the share of shared units flagged, recounted from `results/E8/files.json`:

| Proxy | Rune | HOL closure | MLton | HaMLet |
|---|---:|---:|---:|---:|
| P1: an expansive binding, an effect or a functor application at module level | 33.8% | 37.3% | 8.8% | 16.7% |
| P2: the initialiser calls another unit | 28.4% | 35.7% | 8.2% | 14.9% |

Both are sound at module level and useless as rules: Rune's flagged units never mattered. There is no cheap, useful static proxy.

**For the roadmap.** D17, D7: a written-order tie-break for determinism, and a unit that relies on another's effect must name it, as HOL already does with `local open boolpp in end`. D2: bytes do not depend on order once names are unique.

### E7. The Definition stays whole in the REPL

**Question.** Does `tests/lang` and the corpus through the REPL agree with whole compilation? What does the REPL refuse, and why?

**Prediction** (`results/E7/PREDICTION.md`).
- Nearly everything agrees: right.
- `later` modes differ: right.
- Whole and `use` differ on overloading: wrong. Both close at the end of the file.
- Files piped by line differ from `use`: right.
- An uncaught exception stops whole and continues in the REPL: right for `-e`; `use` stops as whole does.

**How.** `results/E7/run.py`, `run2.py`, `report.py`, `report2.py`: 361 programs of `tests/lang`, of which 330 run through the REPL's ways and 31 are skipped (27 harness, 4 flags the REPL lacks); a sample of 616 corpus programs; 16 corner cases in `corners/`.

**Result** (`lang/report.txt`):

| Way | Same | Differ |
|---|---:|---:|
| `use` | 325 | 5 |
| `-e` text | 321 | 9 |
| a `;` after every declaration | 318 | 12 |

- **The 5 `use` differences:** `basis.compiler` by design, three backtraces with REPL frames, and `ty.infer.valuerestriction_later`. That last is the one real deviation: under `--free-tyvars=later` the REPL refuses what whole accepts. It is documented in `docs/repl.md`.
- **`-e`** adds four latin1 files, because typed text is read as UTF-8.
- **Splitting at each declaration** refuses three programs that a file with no `;` accepts. That is a different program under the Definition's topdec, not a deviation. Two more differ by Chapter 8's going on after an uncaught exception.

**Corpus sample, 616 programs** (`corpus/report.txt`): 316 the same; 298 both refuse, 295 with the same first error and 3 differing only in a stamp; one bug below; one unterminated comment, which whole refuses and the REPL reports as a file ending mid-declaration.

**One bug.** `rune-repl` gives an internal compiler error on `functor F (X : S) = X and G (Y : S) = Y`, which `rune` compiles (`bugs/repl-functor-and/`; found by HaMLet's `test/where-and.sml`). It needs a functor whose body is its parameter.

**For the roadmap.** D17: the REPL keeps the Definition, with one documented deviation and one bug. Against the brief: the REPL has no `--flex-records` or `--or-patterns`, and the `later` modes differ. D20: this is O8's check.

### E8. Who fits

**Question.** Per rule, per corpus, per class of unit, by the parser: who fits a restriction on shared units? This replaces an unverified claim about HOL4.

**Prediction** (`results/E8/PREDICTION.md`).
- Rune's compiler, `lib/` and MLton fit: right.
- MLton's duplicate names come by shadowing Basis names: partly; 17 names are duplicated, across its own library scopes.
- HOL4's theory scripts are entry units: right.
- `tests/lang`, the benchmarks and the corpus are full of top-level `val`: right, and the split rescues them.
- 10-30% of HOL library files break the `open` rule: wrong. 0 of 635 in the closure do, and 0 of 1,179 shared in `src`.

**How.** E5's checker over every corpus (`lists.py`, `list.tsv`, `census.tsv`), `analyse.py` (`summary.txt`, `fit.tsv`, `graph.txt`, `dups.json`). HOL4 layer by layer, each file after `QUse`'s filter, which is what the compiler sees (`hol-filter.py`, `hol-filter.json`). A *shared unit* is one others depend on, from the graph; an *entry unit* is one nothing depends on. "Fit" means no `val`, effect, exception, datatype, `open`, fixity or `use` in the unit. Duplicate names are counted apart.

**Result.** The main rows; appendix B has them all:

| Corpus, class | Shared units fit | Entry units fit | Note |
|---|---:|---:|---|
| Rune compiler | 84 of 84 | 1 of 2 | |
| Rune `lib`, `lib-test`, `src-other` | 318 of 318 | 79 of 106 | the `src-other` entries are mains |
| Basis | 257 of 259 | 18 of 19 | the two are `always` files; 145 files share a name (seals) |
| MLton | 599 of 599 | 6 of 7 | `call-main.sml` is the entry unit |
| HaMLet | 212 of 213 | 1 of 2 | `Syntax.sml`, a top-level fixity; 27 others depend on it |
| HOL closure | 741 of 743 | 3 of 3 | `Overlay.sml`, `rune-init2-rest`; 142 of 746 parse differently without carried fixity |
| HOL kernel | 17 of 18 | | `Overlay.sml`; 0 of 18 changed by the filter |
| HOL library | 1,176 of 1,179 | 42 of 143 | 172 of 1,322 (13%) changed by the filter; 263 shared units depend on fixity |
| HOL tools | 155 of 172 | 7 of 122 | |
| HOL examples, library | 641 of 646 | 55 of 164 | |
| HOL scripts, `src` | 0 of 2 | 0 of 332 | all open at top level; 234 depend on fixity |
| HOL scripts, `examples` | 0 of 2 | 0 of 916 | 803 depend on fixity |
| `tests/lang` | | 6 of 361 | all entry units |
| regressions | | 539 of 1,514 | 975 do not fit, 255 of them failing to parse |

- **Scripts are entry units:** nothing links to one, only to what it generates. 4 of 1,252 show as shared.
- **Two classes are not quite enough.** The exceptions in the closures are all one thing: `Overlay.sml`, the Basis's `always` files and HaMLet's `Syntax.sml` define the language for those after them. This is the third class, the **prelude unit**.

**Caveats.** Value edges are an over-approximation, and are excluded for the full HOL tree, which is no single prefix. `fit.tsv`'s `use` column merges `load`; `summary.txt` separates them, and the table above is `summary.txt`'s. HOL's duplicate names are across port variants and are not counted against fit.

**For the roadmap.** D17: three classes, shared, entry and prelude; the hypothesis holds for Rune, MLton and HOL4's library code nearly untouched, and entry units keep all of SML '97. The clean case for HOL4 is clean only given `Overlay.sml`, an unstated prelude 142 units need to parse. Rune 2's table of what changes takes its rows from here.

### E9. HOL4 and MLton through one build file

**Question.** The test the brief really asks for: can HOL4's `src/boss` closure and MLton compile from a `.build`, and what does that skip?

**Prediction** (`results/E9/PREDICTION.md`, written after the first MLton translation).
- MLton compiles after order fixes, in about the flat list's time, with at least one failure from `.build`'s `use` seeing the caller's basis: right, exactly there.
- HOL4: a handful of units refused, about 1,000 units, 1-3 minutes cold, a few hundred MB of cache: wrong. None refused, 746 units, 21 s, 40 MB.

**How.** `mlb2build.py` turns 27 `.mlb` files into 30 `.build` files, one for one, with no renaming needed; 606 files as in the flat list. `hol-tree.py` and `hol-closure.py` take the generated `*Theory.{sml,sig}` from the shared build as sources, and the order from the `.uo` files; `.uo` paths needed mapping to `.hol/objs`. `timings.sh`, raw in `timings/`. Load 5-15.

**Result** (`timings/`):

| Build | Instructions | Wall | Max RSS |
|---|---:|---:|---:|
| HOL, `--no-cache` | 72.7G | 21.1 s | 699 MB |
| HOL, cold into the cache | 80.4G | 27.9 s | 714 MB |
| HOL, warm | 26.0G | 5.5 s | 568 MB |
| MLton `.build`, `--no-cache` | 437.3G | 94.8 s | 2.6 GB |
| MLton flat list, `--no-cache` | 442.5G | 214.5 s | 3.1 GB |
| MLton `.build`, cold | 447.9G | 106.4 s | 2.3 GB |
| MLton `.build`, warm | 81.5G | 19.0 s | 1.6 GB |

The wall gap between `.build` and flat is noise; 1.2% in instructions is the real difference. MLton's peak here is 2.3-3.1 GB, not the older plans' 10.5 GB; E15's cold run peaks at 3.35 GB. Cache: 40 MB for HOL, 58 MB for MLton. Programs: 14.4 MB and 13.7 MB. Warm equals cold byte for byte on both (`timings/cache-sizes.txt`).

- **MLton runs:** it typechecks and takes `hi.sml` to C identical to the flat build's. One fix was needed. `.build`'s `use` elaborates in the caller's basis, an `.mlb` in an empty one, so `mlyacc-lib`, first used after `lib/mlton`, saw MLton's `List` at `lib/mlyacc-lib/parser2.sml:308` in MLton's tree (`mlton-run2/build.err`). It was hoisted. A shadowing that still typechecked would have been silent.
- **Spelling leaks.** 602 MLton units differ in size from the flat list's and 189 Basis units are identical (`flat-vs-build.txt`), consistent with the path as spelt being in the identity, though that was not isolated. Nested `use` writes paths like `main/../../lib/mlton/basic/../../stubs/...`.
- **HOL4 compiles with no unit refused,** after two base-image files that no `.uo` names, `regexpMatch` and `FunctionalRecordUpdate`. `boss-main.build` runs: it loads every theory's `.dat` and proves a goal.

**What this skips, for HOL4.**
- The filter was run beforehand: 36 of 745 closure files change (E20).
- Scripts are not run: theories are taken as given.
- `.dat` files are read at load from an absolute `HOLDIR`, so the program is not relocatable.
- Heaps are not built.
- Only the closure, not `examples`.

**The graph is static.** `tools/Holmake/Holdep.sml:45-58` maps `fooTheory` to `fooScript.sml` by name. The parser finds no `load` or `use` in 1,252 scripts. Theory name equals file stem in 1,220, differs in 1, and 31 are unresolved by a regex. 5 scripts touch files or processes. Custom Holmake rules exist: recipes in 86 of 108 Holmakefiles in `src`.

**For the roadmap.** D16: a true HOL4 build needs a declared per-file preprocessor with hashed tool and input, a run step, and outputs as inputs of later units. The graph stays static, so no monadic build. D3: each route to a file is a spelling. D6, D7: closures must not inherit `use`'s caller's basis. `docs/build.md`'s "MLB's semantics" is wrong there.

### E10. Functor signatures

**Question.** What did the structure half cost, what must a functor's ABI fingerprint hold, and is it stable on the five hosts?

**Prediction** (`results/E10/PREDICTION.md`).
- Functor signatures add one thing, the descriptor shape: held, among others below.
- A fingerprint holds static shape, slot order and descriptors: held, plus a version tag and the calling convention.
- Hosts with 31-bit integers are the risk: wrong in general. Only `smlnj32` differs, and MLton's 32-bit `Word` agrees.

**How.** On paper, with two probes. `fp/` changes a functor's body and then its result signature under a cached client (`fp/probe.out`). `hashprobe.sml`, lines 143-302 of `lib/compiler/util/pickle.sml` with six texts, prints a hash on each host (`out.*`). `spelling/` compares a `_dynamic` client under two spellings.

**Result.**
- **Cost of the structure half:** M9 (`23e6443e3`) was 43 files, +1,033/-166, 28 lines of C loader.
- **Cut-off already exists.** Changing a functor's body does not recompile its client; changing the result does: "used fun F". The static half is `fpFunctor`.
- **An ABI fingerprint must add:** record shape and slot order, which specifications carry a layout descriptor, an ABI version tag, and the calling convention. Applications become calls, with no expansion.
- **Hash stability:** `Pickle.hash` agrees on Rune, MLton (32-bit `Word`), Poly/ML, SML/NJ 64-bit and MLKit. `smlnj32` differs. Moscow ML cannot compile it, having no `Word64`. This is the hash only: the fingerprint's text was not run on hosts, since this tree has no host builds.
- **The instability that matters is spelling:** `./ty.sml` for `ty.sml` changes 86 of 987 bytes of a `_dynamic` client (`spelling/out.txt`), in its identity and one more hash, likely the ABI fingerprint, not confirmed.

**For the roadmap.** D22: later, unless a client appears. It is small, since cut-off already holds. The cheapest syntax is `functor F = _virtual (X : A) : B`. D3: spelling reaches ABI hashes too.

### E11. Aggregates

**Question.** The brief asks for a library compiled to one open unit. On `lib/unicode` and `lib/compiler`, with `runelsp` as client, does either aggregate earn its place? **Neither does.**

**Prediction** (`results/E11/PREDICTION.md`, written before the first run).
- A packaging aggregate saves 10-20% of a no-op today: wrong. Measured +0.8%, -3.7% and -9.4%: its own read, parse and hash cost most of what it saves.
- It is worth under 5% on E15's patch: wrong on `compiler-client`'s leaf, -7.0%; a leaf can also be worse, +7.8% on `runelsp`.
- An optimising aggregate gains 2-10% of run time on `lib/compiler`: held, 4.0%. It gains little on `lib/unicode`: 3.0%.
- A one-file edit recompiles the whole library: held, 2.9 times on `lib/compiler` today, 3.2 on E15's tree (10.15G against 32.22G, `summary-matrix.md`), 1.4 on `lib/unicode`.
- Link and load gain little over a closure load: held; in fact they get worse.
- Verdict predicted: neither earns its place once the warm path is fixed. Held for both forms.

**How.** The optimising form needs no compiler change: `mkagg.py` concatenates a library's members into one file, and a unit's passes already run on the whole unit with exports as roots. That is the optimising aggregate minus a file format. The packaging form is `patches/E11-pack.patch`, on E15's patch (`apply_pack.py`, `pack.sh`). `run.sh`, `cutoff.sh`, `runtime.sh`, `summary.py`; tables in `SUMMARY.md`, `summary-matrix.md`. "Run" uses `compiler-client`, an analysis of 67 files through `RuneCompiler`, since `runelsp` itself was measured for compile, link and start-up only. Each warm figure is on today's tree and on E15's patch.

**Result.** Warm clients, G (`summary-matrix.md`):

| | Members | One unit | Pack |
|---|---:|---:|---:|
| `runelsp` no-op, today | 12.83 | 13.06 | 11.62 |
| `runelsp` no-op, E15 abcdlu | 0.20 | 0.19 | 0.20 |
| `runelsp` leaf, today | 13.10 | 13.34 | 11.92 |
| `runelsp` leaf, E15 abcdl | 8.84 | 10.67 | 9.53 |
| `compiler-client` no-op, today | 9.89 | 10.39 | 9.97 |
| `compiler-client` leaf, E15 abcdl | 7.76 | 8.42 | 7.22 |

A one-file edit of the library:

| Edit | Members | One unit |
|---|---:|---:|
| `lib/compiler`, a body | 10.42G, 1 unit | 29.93G |
| `lib/compiler`, a helper | 13.33G, 12 units | 29.94G |
| `lib/unicode` | 1.81G | 2.54G |
| `runelsp`, `lib/compiler` body | 11.99G, 1 unit | 34.74G, 17 units |

Run at tier 2 (`runtime.tsv`; spread under 0.01%, `repeat.txt`):

| | Units | One unit | `--whole` |
|---|---:|---:|---:|
| `compiler-client` | 38.05G | 36.51G (-4.0%) | 33.59G (-11.7%) |
| `unicode-client` | 14.00G | 13.59G (-3.0%) | 13.68G (-2.3%) |

`unicode-client` was one run, and the unit beating `--whole` by 0.7% is layout noise, not a result.

- **`--whole` is three times the gain** on `compiler-client`, at 1.27 times a `--units` compile from nothing (32.6G against 25.6G, `whole-compile.txt`).
- **An aggregate pushes E15's floor the wrong way.** Link goes from 154M to 170M VM instructions on `compiler-client`, and code decode from 416M to 533M (`link-decode.txt`). Those two are what a leaf cannot avoid.
- **In a build that loads by closure,** a one-name client of `lib/unicode` gets 2.65 times the bytes and 1.72 times the start-up from one unit (`runtime.tsv`). This answers the brief: an aggregate gains nothing there.
- **Packaging** validates nothing against sources, so if it must, it reads them.
- **Invariants.** S41 held on 90 of 90 warm-against-cold outputs, S42 on 8 of 8, and pack bytes equal members' on 39 of 39. What the one-unit form loses is per-member entries, hence the edit table. The plan's table said aggregates need them for S41 and S42; they do not.
- **Cut-off.** A one-character body edit moved the aggregate's identity while every export's static and static+ABI hash stayed the same (deduced: shifted offsets in inline Mid). So per-name cut-off exists only through per-export hashes. Master refuses those to clients of `lib/compiler`, which is why all 16 of `runelsp`'s clients recompile. With remapping forced they hold, and warm differs from cold in 62 bytes confined to the client unit (`s41-diag.txt`), taken to be its imported identity.
- **`o NAME` usages:** 20 of 22 units have one, 51 of 53 bound by nothing and 2 by `lib/basis/word8.sml` (`overload-usages.txt`). No library outside the Basis has `_overload`, so this is only a Basis aggregate's problem.
- **The Basis, on paper.** E3's `--basis all` figures stand in: hello's `.rbc` from 6 KB to 2.8 MB, start-up from 0.6M to 11.8M. One open unit gives every program that. Refuse it.

**For the roadmap.** D19 and Gate G1: drop both aggregates. If release speed is wanted, `--whole` gives three times the gain on `compiler-client`. Packaging may stay as a dist format if a client ever asks. E15's warm path takes away what packaging was for, and per-member entries are what make a one-file edit cheap.

### E12. The build language's form

**Question.** Fix a plan schema. Does a plan round-trip through text on every build? Does flattening agree with the hosts' awk? Do `.build` and a pure SML program produce equal plans, and at what cost on a reader's path? Form (c), module handles, was dropped from this experiment when the ideation review rejected it; a lower bound stands in.

**Prediction** (`results/E12/PREDICTION.md`).
- Round trip on all, with the schema extended: held, plus two extensions not foreseen, `requires` on the plan and `inline`, `inlineValues` on a library.
- Sizes, 15-30 KB for `rune.build`: wrong, 8.3 KB, from a mistaken count of units. HOL4, 100-200 KB: wrong, 60 KB. MLton, 60-120 KB: nearly, 125 KB.
- A stored read costs 30-70% of planning: wrong. On flat builds it costs the same or more; against the plan with closure and hashes it is 32-40%, and 2.7% on MLton in this prototype.
- Under 10M instructions on `rune.build`: wrong by a little, 12.1M.
- The awk's list differs by `build/config.sml` and the main file, and `runelsp` loses its closure: exact.
- Through `libraries`, 19 files lost and identity unchanged: exact.
- The grown awk would be rejected as large: wrong on the reason, it grows only 15 lines.
- Property 1 holds with `inputs` outside the body and `use` flattened: held. Not predicted: the worked examples are not equal as written.
- 50-100 times a stored read: wrong, 525 times a stored read and 116 a `.build` read.

**How.** `tool/plancanon.sml`, pure SML with no IO, and `plantool.sml`, on the compiler's own `CompilerProject.plan` (`patches/E12-plan.patch`). The format is line-oriented so that awk can read it. `run-check.sh`, `run-check-abs.sh`, `measure.sh`, `run-flat.sh`, `typecheck-flat.sh`, `d14/run.sh`, `run2.sh`, `run3.sh`, `prop1/run.sh`, `prop1/wall.sh`. Perf `instructions:u`, best of 3, load 7-24.

**Result: the round trip** (`check.tsv`, `check-abs.tsv`). 90 of 90 builds, the 88 tracked and MLton's and HOL4's; 4 need an absolute path variable, a bug in appendix D. Reprinting is byte-equal and the steps equal `CompilerProject`'s.

| Plan | Text | Units | Above `.build`'s text | Plan | Closure and hashes | Print | Read |
|---|---:|---:|---:|---:|---:|---:|---:|
| `rune.build` | 8.3 KB | 106 | 3.2 times | 11.4M | 30.2M | 41.2M | 12.1M |
| `runelsp.build` | 13.2 KB | 157 | | 5.5M | 43.4M | 57.0M | 14.1M |
| HOL4 | 60.4 KB | 746 | 2.2 times | 26.7M | 78.8M | 114.8M | 31.2M |
| MLton | 125.3 KB | 606 | 4.3 times | 40.9M | 2,207M | 2,284M | 58.5M |

Instructions are above a no-op of 110.45M (`measure.tsv`). MLton's 2,207M is the prototype walking a tree that holds 4,840 `use` steps. A stored read's value is reading without Rune, not speed. All of it is under 1% of a compile. Form (c)'s lower bound on the flat list, `--typecheck-only`, is 5.31G (`typecheck-flat.out`), about 440 times a stored read.

**What a reader needs that the text lacks** (`READER.md`): which library files a program loads (flat 134, a compile chooses 122), so selection by mention blocks it; `Deps`' uses for `-j`; six fingerprint fields; the `--lib` root. The Basis stays implicit. `plan-schema.md` must add `requires` and `inline`, move `inputs` outside the compared body, keep `replay` or say what replaces it, and drop `caches`, which has no use.

**D14's danger, observed** (`d14/run.out`, `d14/run2.out`, `notes-d14.md`).

| `rune.build` | Awk's list | Identity after an edit of `lib/unicode` | B on A's cache | B cold |
|---|---:|---|---|---|
| as committed | 104 | changes | no entry, prints 234 | 234 |
| through `libraries` | 85 (17 `unicode`, 2 `json` lost) | **unchanged** | **hit, prints 233** | 234 |

A host's list fails loudly, with 69 errors. The obvious repair, `--library unicode --library json`, compiles, and that is how the hole goes silent.

**Flatten against the awk** (`flat/summary.tsv`): the same order on all six roots; the flat list is the awk's plus `build/config.sml` and the main file, or for `runeffi` the main file. `runelsp` is 22 against 157. `--build-list` also drops the closure: 23 against 157.

**What must replace it** (`d14/run3.out`):

| | Committed canonical plan | Awk grown |
|---|---|---|
| size | 8.6 KB per root; 5 roots; `identity.sh`, 4 lines | 84 lines against 69 |
| matches flatten | by construction | on 6 roots and through `libraries` |
| kept true | hashes checked with `sha256sum` alone; a hand edit needs a Rune-side `cmp` in `make check` | needs a Rune-side equality test |
| grammar | knows none | one more place to keep level with each syntax |
| failure mode | stale: loud, on a host | a construct it skips is the same silent bug again |
| cost | regenerate on a `.build` edit: 40 of 1,231 commits in six months; 10 of 33 live branches touch those files, at E12's count; E28 counts 34 refs, backups included | none |
| reading, instructions | 1.8M | 21.2M |

A host compile from the plan's flat list works, with Rune standing in for the host. No host was run.

**Property 1** (`prop1/run.out`). Byte-equal canonical plans on all four examples, on three conditions: `inputs` outside the body, a `use` that is never replayed dropped, and paths fixed. The ideation review's "same list of plans" is wrong as written for examples 2 and 4, because a path in a used build file is relative to that file. On a reader's path, the debug plan of example 2:

| Route | Instructions | Against a `.build` read |
|---|---:|---:|
| `.build` read | 9.2M | 1 |
| stored read | 2.0M | 0.2 |
| SML build program, compile and run | 1.07G | 116 |
| floor for any SML route: a hello compile | 296M | 32 |

The SML route's wall time is 462 ms, best of 5 at load 9 (`prop1/wall.out`). A reader never pays it if it reads a stored plan.

**For the roadmap.**
- D5: the plan is the contract and `.build` its normal form. Its value is reading without Rune, without a parser, across forms.
- D14: must precede any root migration. Identity hashes the closure, whichever option is taken. P recommends the committed plan for the 5 host-built roots, with the grown awk as fallback.
- D16: `build/config.sml` is the plan's first honest generated step.
- Gate G2: test 4 passes on the three conditions. Test 6 fails: 462 ms against 250 ms, and 116 times a `.build` read. This supports not building the term layer now.

### E13. What a firewall could save

**Question.** For each replayed edit, count the units whose code bytes really changed. That is the true floor for any see-through design. A replay of key policies alone would count savings that cannot exist. What could a firewall save? **Almost nothing.**

**Prediction** (`results/E13/PREDICTION.md`).
- (b)/(a) about 0.6 on the compiler: wrong in the middle of the range. It is 0.28 exact and 0.69 with remapping allowed.
- Body and helper edits, (a) = (b) = 1: right.
- A datatype behind `:>`: (b)/(a) under 0.3: right. A signature member, 0.1-0.5: right on MLton, 0.100; HOL is far lower, 0.002.
- HOL4 costs (a) large, (b) tiny: right, stronger than predicted at 0.009.
- More than half of (a) minus (b) is the static layer: wrong. The largest cause was not foreseen at all: a refused remap, 59%.
- A layered key gets most of it, and (b) minus edited units is under 15% of (a): right, 2.7%.
- The price of a firewall is 1.0-2.0 times run instructions: too low, at least 2.4 on `checksum`.

**How.** Tree `bs-sep` with `patches/E13-sidecar.patch`, which writes each unit's usages beside its entry and changes nothing the compiler makes. `rbu.py` reads `.rbu` files and applies the tiers; `replaylib.py`, `history.py`, `seeded.py`, `analyse.py`, `price.py`; method in `README.md`, tables in `tables.txt`.
- **Chains:** `lint31`, 30 steps of the linting branch; `fu31`, 29 steps of functors-units, whose first commit does not compile under today's compiler. The two chains share 10 commits, so 85 edits are 75 distinct ones: those 10 add 192 to (a) and 44 to (b), and none of those units is in the firewall's 31. Without them (b)/(a) is 0.089, not 0.096.
- **Seeded edits:** MLton 14, HOL's closure 12, on a corpus with no real commit chain here.
- **(a)** is the units the cache compiles, through one cache. **(b)** is those whose code changed.
- **Tiers of "changed":** C1 is the brief's form, identities become logical names; C2 also replaces another unit's key number by its first-mention place; C3 also drops trace data; C4 also drops metas and the expects tail. **(b) means C2,** because C1 counts a shifted import number as a change. C2 is validated: with remapping allowed, cached and cold compiles were C1-identical on all units in 61 of 61 compares.
- **"Compile everything" was a check, not done on every edit:** no-cache raw bytes equalled the cached build on 78 states with 0 units differing, in exact mode; with remap allowed, raw unit bytes differ in 64 of 65 checks, C1 equal. Only 5 MLton states were checked cold.

**Result** (`tables.txt`):

| Corpus | Edits | (a) | Edited | C1 | (b) | (b)/(a) | Real change, unedited unit | Only a firewall could avoid |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| compiler, `lint31` | 30 | 543 | 156 | 391 | 156 | 0.287 | 8 | 0 |
| compiler, `fu31` | 29 | 382 | 118 | 247 | 106 | 0.277 | 1 | 0 |
| MLton | 14 | 1,089 | 18 | 359 | 108 | 0.099 | 93 | 24 |
| HOL closure | 12 | 2,034 | 15 | 289 | 19 | 0.009 | 7 | 7 |
| **All** | 85 | 4,048 | 307 | 1,286 | 389 | 0.096 | 109 | 31 |

"Only a firewall" means a real change in an unedited unit where nothing static fired. With a static change the interface moved, and no firewall helps. So **31 of 4,048 units, 0.8%, are what a firewall could save, and none comes from a real commit.** The real commits here are the compiler's alone, and the 31 are all seeded.

With remapping allowed (`RUNE_E13_REMAP`):

| Corpus | (a) | (b)/(a) |
|---|---:|---:|
| `lint31` | 187 | 0.706 |
| `fu31` | 151 | 0.669 |
| MLton | 684 | 0.158 |
| HOL | 852 | 0.022 |

**Per kind of seeded edit,** (a) / (b):

| Kind | MLton | MLton, remap | HOL | HOL, remap |
|---|---|---|---|---|
| body behind a signature | 4 / 4 | same | 3 / 3 | same |
| private helper | 3 / 3 | same | 3 / 3 | same |
| datatype behind `:>` | 344 / 27 | 343 / 27 | 819 / 10 | 310 / 10 |
| signature member added | 738 / 74 | 334 / 74 | 1,209 / 3 | 536 / 3 |

Body and helper edits moved no identity across 13 edits and rebuilt only the edited unit: the cache is already a firewall for them. MLton's signature edits' 74 are nearly all two functor signatures, `PRIM` 31 and `SSA_TREE` 40; that suggests positional record slots, a deduction not checked.

**(a) minus (b) by cause, exact, 3,659 units:**

| Cause | Units | Share | What removes it |
|---|---:|---:|---|
| R: remap refused, no usage changed | 2,177 | 59% | fix `loadsUnits`, or logical identity (D3); no layer needed |
| fired A only: realisation, value anchors, back-end facts; code the same | 814 | 22% | at most, an ABI layer that holds layout, not the whole definition, if the compile's reads shrink with it (D1) |
| fired S: static layer; code the same | 639 | 17% | not a key: the compile really reads it |
| edited, code the same | 29 | 1% | comments, whitespace |
| implementation layer (`inl`, `inlv`) | 0 | | |

The brief says every unit in (a) but not (b) is a rebuild a layered key could avoid. That is true of R and A, not of S: a type that changed must be re-elaborated even if the code comes out the same. Of the S and A units, 717 on HOL fired only `s M`, a whole-structure usage from `open`. The A bucket is a throwaway split, not E17's layers.

**The biggest waste is not a layer at all.** `loadsUnits` fires on a mention, not on loading: `main.sml:590-593` tests whether `lib/basis/runtime.sml` or `dynamic.sml` is among the sources, and selection is by mention. MLton has its own `structure Runtime`, and HOL calls only `Runtime.same` and `catchInterrupt`. Neither loads a unit, yet both lose every remap hit, and so does the compiler. That is 54% of all rebuilds. With the refusal off (`RUNE_E13_REMAP`), (a) falls from 4,048 to 1,874 and warm instructions from 4,373G to 3,506G, -19.8% (`tables.txt`): MLton `sig-list` 202 to 9 units, `sig-control` 233 to 22; HOL `datatype-net` 515 to 104, `sig-lib` 564 to 206. `bugs/mention-runtime/` reproduces the refusal only: no fix was built, and a client's program bytes under one were not compared.

**Cost.** `mlton-extra.out`, `mlton.out`, `hol.out`:

| Build | No edit | Worst edit | Cold, no cache |
|---|---:|---:|---:|
| MLton | 83.9G | 493G | 490G |
| HOL | 29.2G | 82.9G | 79G |

The worst HOL edit, `Term.sig` plus a member, has 1 unit of real change. **Stale entries slow the warm path:** MLton's warm went from 83.9G to 116.2G after about 15 edits' entries, +38%.

**The price of a firewall** (`price.py`, `price.out`; MLton from `results/E14/mlton/`). Run instructions at tier 2, ratio to whole; all outputs the same:

| Program | Whole, G | Units today | No inlining across units | And no known calls |
|---|---:|---:|---:|---:|
| checksum | 1.10 | 1.273 | 3.072 | 3.117 |
| wc-input1 | 0.26 | 1.350 | 1.949 | 1.952 |
| mlyacc | 0.52 | 1.217 | 1.472 | 1.488 |
| hamlet | 0.19 | 1.326 | 1.339 | 1.347 |
| tyan | 1.88 | 1.088 | 1.089 | 1.095 |
| MLton on `hi.sml` | 34.45 | 1.594 | 1.665 | not run |

Inlining is the price: 2.4 times today on checksum. Known calls add 0.1-1.5% on these programs, far less than the plan implied. This is a lower bound, since losing layouts behind an opaque type was not measured. No real firewall was prototyped. C2 could hide a client whose import target changed at the same position; no sign of that was seen.

**For the roadmap.**
- D18: keep Mid see-through and build no firewall. The floor is 31 of 4,048 units against at least 2.4 times the run on `checksum`.
- Before D1, fix `loadsUnits`. D3 also removes the refusal outright.
- D1: an ABI layer that holds layout could save at most the 814, if the compile's reads shrink with it. The implementation layer earns nothing today. Finer `open` usages are worth as much as a layer on HOL.
- D24, D25: evict entries.

### E14. What can go in a unit

**Question.** For Rune 2: if Mid were captured later than ToMid's output, what would whole-from-units cost and give? Capture at three points: T, today, ToMid's; X, after expand; S, after simplify.

**Prediction** (`results/E14/PREDICTION.md`).
- `lift` and `workers` tolerate running twice: held for correctness; `--lint=2` and `3` clean.
- X saves 5-15% of compile: wrong, it saves nothing.
- S42 dies as soon as a unit has its own applications: partly. At X, bytes differ only in function order and numbering.
- S loses functor copies, with at least one benchmark 1.05-1.5 times worse: held, in a way not expected. It is not a shape check or an assert: Simplify deletes the marker.
- Whole from S takes 40-70% of whole from raw: wrong, about 1.0. MLton's warm whole would be 100-120G: wrong, 129.1G.
- Run within 3% except functor loss: wrong, 14% on a single-file program.
- A semantic differential replaces S42 at S: held.
- One case of cross-unit inlining closes over half of checksum's gap: held.

**How.** `patches/E14-capture.patch`, in `bs-sep`. 14 programs: 11 benchmarks, HaMLet's 215 files, the compiler, MLton. `e14.py`, `e14-hamlet.py`, `e14-rune.py`, `e14-mlton.sh`, `subsets.py`, `lint2.sh`, `keepmark.py`, `auto.py`, `xdiff.py`, `table.py`; `table.txt`. Every unit must be captured at one level, so the library ran with no `lib/cache`. Each figure is against whole from raw.

**Result** (`table.txt`): compile, code bytes, run instructions, each a ratio.

| Capture, and the whole passes run | Geometric mean | HaMLet (215 files) | MLton |
|---|---|---|---|
| X, all passes | 0.996, 1.000, 1.000 | 1.008, 1.000, 1.000 | 1.001, 1.000, 1.001 |
| S, all passes | 1.001, 1.011, 1.072 | 0.841, 0.863, 1.407 | 0.992, 1.196, 1.502 |
| S, no expand, `lift`, `workers` | 0.950, 1.005, 1.058 | 0.801, 0.852, 1.408 | 0.968, 1.222, 1.558 |
| S, `shake` only | 0.855, 1.014, 1.110 | 0.661, 0.768, 1.432 | 0.822, 1.093, 1.585 |
| `--units`, no whole | run in the table | run 1.447 | run 1.594 |

- **Capturing after expand costs nothing and gains nothing.** After simplify saves 0.8% of compile on MLton, 4.2% on the compiler and 15.9% on HaMLet, nothing on the geometric mean. It costs 1.41 times the run on HaMLet and 1.50 on MLton, and 1.03 on the compiler, which has few functors.
- **Beside the published 145.3G:** MLton's warm `--whole` is now 129.1G, 24 s, peak 2.2 GB, and its bytes equal the 356.4G whole compile's (`e14-mlton.out`). Run 34.45G.
- **The cache barely grows:** MLton's 63 MB raw, 63 MB at X, 65 MB at S.
- **All captures gave the same answer.** Output and exit equal whole's in all 14 programs and modes. Every MLton took `hi.sml` to the same C.

**What happens to functor copies.** After simplify, HaMLet's whole expand goes from 72 applications expanded to 0, leaving 42 calls. MLton's functions fall from 22,751 to 17,643. The cause: `functor_marker` is removable (`lib/compiler/backend/prims.sml:562,568`), so Simplify deletes it, and `lib/compiler/core/expand.sml:1380` then leaves the call. Keeping the markers (`keepmark.py`) gets 65 expansions back, of at most 602 nodes against 18,272, and the run is still 1.225 times. Most likely `workers` has split the functor's function and only a wrapper is copied, deduced. The single-file benchmarks hide all this: their S rows look fine.

**`workers` is not free at tier 2.** Subset runs (`subsets.py`): raytrace 1.143, plclub-ray 1.085, barnes-hut 1.052. Bytecode on raytrace is 0.996 of whole with less allocation, so this is a tier-2 effect, with its cause deduced, not traced.

**Mixed levels break.** A user unit at X over a frozen Basis at ToMid gave "global 21 read before initialization" (`bugs/mixed-capture.md`). This is a trap of the prototype, not a bug of master. The capture level is a property of the whole store and must be in the config, frozen layer included.

**What replaces S42.** At X, bytes equalled whole's on 3 of 14 programs. On 4 single-file programs by section (`xdiff.py`): the same constants and the same (name, length) multiset, so X differs only in function order and numbering, and a canonical order could keep S42. Multi-file programs add a few functions: compiler +41 of 6,453, HaMLet +3, MLton +51, probably `withInlined`'s copies, deduced. At S, bytes never match, and the replacement can only be a semantic differential. Output and exit were compared here; traces were not.

**One case of inlining beyond `inline val`** (`auto.py`, `RUNE_E14_AUTO=N`): every function of at most N Mid nodes goes in the basis. Run against whole:

| Program | Today | N=50 |
|---|---:|---:|
| checksum | 1.273 | 1.086 |
| wc-input1 | 1.350 | 1.256 |
| mlyacc | 1.217 | 1.139 |
| fxp | 1.204 | 1.117 |
| tyan | 1.088 | 1.078 |
| hamlet | 1.326 | 1.436 |

The cost: compile +21-54% and basis about 3.3 times. hamlet gets worse at tier 2 although its bytecode gap closes; it is a short run, so load and JIT probably dominate. checksum at N=400 is 1.786 and allocates 121 MB, so blind import needs a heuristic.

**A ThinLTO-style summary, on paper only:** MLton in units has 34,565 functions. At about 20 bytes each that is about 0.7 MB, roughly 3% of its 22 MB bases. The import list must go in the key, which worsens cut-off.

**For the roadmap.**
- D19: if an aggregate ever exists, it holds member Mid at ToMid or after expand, never after simplify.
- D24: the capture level goes in the config.
- Rune 2: near-whole keeps today's capture, where S42 holds byte for byte; after expand gains nothing measured. Well-optimised incremental means units plus a summary of small functions, with a heuristic. Optimised Mid in a unit is not worth it while functors are copied late.

### E15. Where a warm build goes

**Question.** Name the baseline and re-measure it. Split MLton's, `rune.build`'s and HOL4's warm builds by stage. Can prototypes bring a no-op below 5% of today, bytes equal? This came first in wave 1, since wave 2 builds on it.

**Prediction** (`results/E15/PREDICTION.md`).
- MLton's no-op is 105-120G: wrong, 88.89G, lower than 105.0G despite `checkSchemes`.
- Basis load 45-55%: too low, 62.3% of wall, and 74% of instructions counted with its GC.
- Entry read and hash 10-20%: wrong, 2.3%.
- The same shares on other corpora: wrong. Load is 4.1% and 2.6% there.
- (c) saves 3-6%: wrong, about 15%.
- A leaf at 10-30% of today: true on MLton only.
- A no-op below 5% holds only if link is also skipped: held, with `u` on all three corpora, or `abcdl` on MLton alone.
- A missed lazy read exists, in overloading or `Ty.extras`: a missed read exists, but it is source text.

**How.** `results/E15/run.sh`, `base-mlton.sh`, `base-hol.sh` for the baseline, raw in `base/`. `RUNE_E15_ACC` and `acc.py` split a run. `perf-mlton.sh` splits GC. `patches/E15-warm.patch` holds the prototypes behind `RUNE_E15_WARM`, one letter each: `proto.sh`, `proto2.sh`, `proto3.sh`, `compare.py`; tables in `proto/`. Load 3-7, pinned.

**Result: the baseline,** stock, at tier 2:

| Corpus | Cold | No-op | No-op peak | Hits |
|---|---:|---:|---:|---:|
| MLton | 454.7G, 98 s, 3.35 GB | 88.89G, 15-18 s | 1.92 GB | 791 |
| HOL4's closure | 80.5G | 26.06G, 5.6 s | 567 MB | |
| `rune.build` | 18.3G | 9.72G, 1.7 s | 265 MB | 246 |

The published 60.2G is a compiler built by MLton. 105.0G was a compiler at tier 2 at load 27. Quote 88.89G.

**The split of the no-op,** share of wall (`stats/mlton-noop`, `proto/hol-none/noop`):

| Stage | MLton | HOL4 | `rune.build` |
|---|---:|---:|---:|
| basis load | 62.3% | 2.6% | 4.1% |
| link | 17.3% | 32.4% | 32.8% |
| code decode | 8.7% | 15.9% | 25.8% |
| lex | 3.0% | 7.9% | 8.7% |
| entry read and hash | 2.3% | 8.5% | 11.3% |
| select | 1.1% | 3.1% | 3.0% |
| usage check | 0.9% | 3.4% | 3.9% |
| schemes | 1.6% | 1.7% | 1.7% |

The MLton column comes from one instrumented run on the stock cache. On MLton GC is about 40% of the machine instructions; the heap reaches 1.76 GB live from 22 MB of pickles. Removing the load removes 74% of its instructions. **Only MLton has this shape.**

**The prototypes.** `a`: binders-only, a hit loads no basis. `b`: a stat shortcut with a racy guard. `c`: a plan memo. `d`: lazy closure on a miss. `l`: a link memo. `u`: nothing changed, exit.

Per cent of the prototype compiler with no letter set: MLton 89.48G, HOL4 27.90G, `rune.build` 9.77G. A leaf is S45's kind / a real one (`elaborate-core.fun`, 985 usages; `patternMatchesLib.sml`; `driver/main.sml`):

| Set | MLton no-op | Leaves | HOL4 no-op | Leaves | `rune.build` no-op | Leaves |
|---|---:|---:|---:|---:|---:|---:|
| a | 26.2 | 85.4 / 85.7 | 88.0 | 90.4 / 89.8 | 104.4 | 107.0 / 92.0 |
| b | 99.6 | 99.6 / 99.7 | 98.3 | 98.3 / 98.3 | 98.2 | 98.6 / 98.4 |
| c | 84.6 | 93.7 / 94.6 | 85.0 | 84.1 / 84.1 | 85.1 | 85.0 / 86.2 |
| d | 26.2 | 26.2 / 34.7 | 88.0 | 89.4 / 89.1 | 104.4 | 106.0 / 91.5 |
| l | 80.9 | 99.4 / 100 | 68.6 | 98.1 / 98.1 | 78.7 | 100 / 98.1 |
| abcd | 20.3 | 19.6 / 27.2 | 61.8 | 71.4 / 68.7 | 75.8 | 77.7 / 69.9 |
| abcdl | 4.5 | 19.6 / 27.2 | 11.8 | 71.2 / 68.8 | 13.3 | 77.5 / 79.0 |
| abcdlu | 0.2 | 19.6 / 27.2 | 0.8 | 71.2 / 68.8 | 2.1 | 77.6 / 69.8 |

- abcdlu's no-op: MLton 0.22G, 67 ms, 19 MB. HOL4 0.24G. `rune.build` 0.21G.
- A MLton leaf peaks at 494-561 MB, loading 26 or 230 of 791 bases.
- Every output is the baseline's bytes, with no `E15 MISSED` line.
- **A leaf's floor is code decode plus link,** 70% of today on HOL4 and `rune.build`. Only a link from bytes would move it, and no such link was measured.

**Soundness of lazy load, observed.**
- One unit at a time compiled against the deferred bases of all others, its entry's basis, code and Mid compared: `rune.build` 246 of 246, mean 26 bases loaded, at most 148; a MLton sample 51 of 51, mean 108 of 791, at most 254 (`evict.sh`, `lazy/`).
- S41: 52 of 52 programs (`s41.sh`).
- `--verify-cache` on `rune.build`: 246 verified, 0 failed.
- Random edits against `--no-cache` (`mutate.sh`): abcd 135 builds, abcdlu 229 builds, 0 disagreements.
- `racy.sh`: all right, including same-second same-size edits and `cp -p` of old text.
- A missed read was found: `b` alone changed bytes until `Source.fault` loaded the other unit's source. That is bug `inline-line` in E18.

**The prices.** Light hits skip `checkSchemes`, so S82 fails by design. S71 fails as an artefact of the memos making the config directory. `u` trusts stats, and whole-second mtimes need a 2-second guard. `.build` text is only partly in the plan memo's key; a real memo must hash it. MLton's lazy verification is a 51-unit sample; HOL4 has only the byte comparison.

**`-j`:** `-j 4` makes a no-op slower, 12.75G against 9.71G on `rune.build`, since it parses every input.

**For the roadmap.** D25: `a` and `d` first on functor-heavy code, `b`, `c` and `u` for no-ops, `l` for the common rebuild. The next floor is the link. Decide `checkSchemes`' fate, since a light hit cannot run it. `-j` needs rework. D24: memos and sidecars are not keys, so "nothing in a key is a time" stands.

### E16. Identity policies

**Question.** Today's identity holds the path as spelt. Compare it with a name-free one and with logical, library-relative names, under real spellings.

**Prediction** (`results/E16/PREDICTION.md`).
- Tens of units gained across roots: wrong, 0 to 3.
- A moved file recompiles under today and logical, nothing under free: right.
- Logical equals free for a moved library: right.
- Remapping under free gives a wrong global, silently: right.
- Two identical files merge under free: right.
- Anchors under free are not wrong alone: right.
- A version fits logical and nowhere in free: right, by reading.

**How.** `RUNE_E16_POLICY=today|logical|free` in `patches/E16-policy.patch`, cumulative on E15's patch, on a copy of the tree with one cache per policy. `results/E16/scenarios.sh`, `scenarios2.sh`, `mutate.sh`, `identical/`, `remap/`, `bugs/`.

**Result.** Units compiled; `rune.build` has 248 in these runs (`scenarios.txt`, `scenarios2.txt`):

| Scenario | Today | Logical | Free |
|---|---:|---:|---:|
| across roots: `runeopt`, `runeffi`, `runedoc`, `runelsp` | 10, 55, 21, 63 | the same | 10, 55, 21, 60 |
| `tests/lsp/worker.build`, spelt `../../` | 16 | 1 | 1 |
| `rune.build`, spelt `./` | 105 | 0 | 0 |
| rename `parallel.sml` | 2 | 2 | 0, bytes differ |
| move `isa.sml` | 5 | 5 | 0, bytes differ |
| move `elab/types.sml`, central | 57 | 57 | 0, bytes differ |
| move `lib/unicode` to `vendor/` | 24 | 0 | 0, bytes differ |

- **Random edits:** logical 150 builds, 0 disagreements; free 104 builds, 39 disagreements (`mutate-logical.txt`, `mutate-free.txt`).
- **Two identical files in one build:** free prints `10 10`, where `0 10` is right, cold, warm and without the cache. It merges generative state (`identical/`).
- **Remapping under free:** warm prints 2, no cache prints 1. `List.find` by name at `unitbasis.sml:2632` takes the wrong unit silently (`remap/`).
- **Under free,** `others` and marked Mid lose their unit names, and a cached warning names the old path. No wrong hit came from anchors alone.
- **On the stock compiler:** a file given twice prints `0 10` whole and `10 10` in `--units`, with or without the cache (`bugs/same-file-twice/`). That is issue 22 in batch.

**For the roadmap.** D3: logical names, plus a rank for a repeated unit. They win what spellings cost, and were sound in all that ran. Reject name-free: moves gain 2-57 units of 248, at the price of wrong code three ways. A version has a place: `LIBRARY@1.2:PATH`.

### E17. Interface layers

**Question.** The experiment D1 rests on. Hash a unit's pickle by layer: how many bytes is each, what would each consumer rebuild on real edits, is each claim sound, and can the LSP and the compiler share a layer?

**Prediction** (`results/E17/PREDICTION.md`).
- Bytes on `rune.build`: held, static 55.1%, ABI 34.4%. On MLton, static 70%+: wrong, 28.0%.
- Spans 5-15%: wrong both ways, 0.2% in batch and 72-80% in analysis.
- Per-export static plus ABI is today with remap: held.
- Static saves 10-30% more on the compiler: wrong, 0%. HOL4: 61%.
- A static-only batch key breaks S41: held, and random edits are a weak detector.
- At least two leaks: held, and one was worse than expected, a false error.
- The static layer differs at first between analysis and batch: held. Several causes predicted: wrong, there is one.

**How.** `patches/E17-layers.patch`, holding E13's sidecar, E20's Env fix and U's changes. Each export, at every depth, gets a static hash and a static+ABI hash at bind (`RUNE_E17_DUMP`), reusing the third traversal with E13's mode. `bytes.sh`, `table.py`, `policies.py` and `replay.py` on E13's steps, `mutate.sh`, `abi-probes.sh`, `blank.sh`, `blank-hol.sh`, `leaks.sh`, `crux.sh`, `crux-hol.sh`, `crux-mlton.sh`, `compare.py`; `SUMMARY.md` classifies every pickle field.

**Result: bytes by layer** (`bytes-*.tsv`):

| Corpus | Pickles | Static | ABI+opt | Header | Self | Spans |
|---|---:|---:|---:|---:|---:|---:|
| `rune.build`, batch | 778 KB | 55.1% | 34.4% | 8.9% | 1.4% | 0.2% |
| HOL4's closure, batch | 2.20 MB | 53.7% | 31.6% | 12.7% | 1.8% | 0.2% |
| MLton, batch | 22.3 MB | 28.0% | 69.0% | 2.6% | 0.2% | 0.2% |
| `rune.build`, analysis | 2.28 MB | 19.7% | 4.7% | 3.0% | 0.5% | 72.2% |
| HOL4, analysis | 9.85 MB | 12.5% | 4.8% | 2.9% | 0.4% | 79.5% |

MLton's ABI layer is essentially one field: the value stamps and global flags of environment references, 58.6% of all its basis bytes. Spans are 72-80% of an analysis pickle, so they go to a sidecar first. Of a whole entry the static layer is about 4% on `rune.build` and 12% on MLton, which is what the LSP needs.

**The replay** (`policies.md`, E13's steps), units rebuilt:

| Chain | Shipped | With remap | S+A per export | Static (LSP) | Code really changed |
|---|---:|---:|---:|---:|---:|
| `lint31`, 30 edits | 543 | 187 | 184 | 184 | 132 |
| `fu31`, 29 | 382 | 151 | 144 | 144 | 101 |
| HOL4, 12 | 2,034 | 852 | 845 | 328 | 19 |
| HOL4, 3 datatypes behind `:>` | 819 | 310 | 310 | 3 | 10 |
| HOL4, 3 signature members | 1,209 | 536 | 529 | 319 | 3 |
| MLton, 14 | 1,089 | 684 | 661 | 334 | 108 |
| MLton, 3 datatypes behind `:>` | 344 | 343 | 330 | 3 | 27 |
| MLton, 4 signature members | 738 | 334 | 324 | 324 | 74 |

The MLton rows are `policies.py mltonr` on E13's final data, run while writing this: `policies.md` stops at 10 edits, because M's replay was unfinished when U stopped.

- **What the gain really is.** S+A per export is today's fingerprint with remap. On `rune.build` the gain against shipped comes from allowing remap, not from new hashes.
- **Which layers moved on `rune.build`,** 59 commits (`replay-sum.md`): 322 identities moved. The static hash moved on 258, ABI alone on 0, neither on 64. Those 64 are deduced to be imports' identities and private tables, so they would vanish with imports out of the hash.
- **Per export against one hash per layer per unit, OCaml's form:** at least 304 and 455 clients on `fu31` and `lint31`, against 151 and 187. Per-export is worth 2.0 to 2.4 times.
- **The LSP's static view** saves nothing on `rune.build`, which hides little. It saves 61.2% on HOL4 and 49.5% on MLton, and on a datatype behind `:>` all but the edited units. It saves nothing on MLton's signature members.

**Soundness.**
- **S+A under random edits** (project, functors, a new opaque project): 421 builds, 0 disagreements, 217 taken across, bytes equal to `--no-cache`.
- **Static-only as a batch key:** 421 builds, 4 disagreements, so random edits are a weak detector here.
- **Directed edits that keep static and move ABI** (`abi-probes.txt`): S+A, all 5 rebuild, bytes the same. Static-only: a function turned into a closure is an internal compiler error at link; an opaque realisation under a client's datatype is refused at link; an exception's identity gives different bytes. The other two were safe only because `inlv` stays in the key.
- **The LSP's claim, measured:** with every ABI table left out of every load, analysis gives identical facts, occurrences, diagnostics and static hashes on `rune.build` (245 units) and HOL4 (921) (`blank.sh`, `blank-hol.sh`).
- **Reads,** using E18's 26 roots, by judgement: 13 tables fall in static or ABI, 11 are name supply and indexes, 1 is a setting. `Source.files`, another unit's text, falls in no layer: E18's hole 1.

**Leaks found** (`leaks.txt`):
- A false error: `openConstructors` asks `isDatatype` of `Ty.datatypes`, which `specDatatypes` fills only `if code`, so `--typecheck-only` and analysis refuse a program that compiles and runs (`bugs/open-constructors-typecheck/`).
- A client's diagnostic reads a layout, `descriptors` at `lib/compiler/elab/elaborate.sml:1281`. With the ABI blank, analysis misses an error batch gives (`probes/leak-layout`). It is the only read of an ABI fact by the static path that was found.
- A sound but spurious move: a datatype behind `:>` in a functor body moves `fun F`'s static hash, through `fpBound` of `generated` (`probes/leak-generated`).

**The crux: batch against analysis, the static hash of each export:**

| Corpus | Units | Exports | Differ, stock | After the fix |
|---|---:|---:|---:|---:|
| `rune.build` | 245 | 13,705 | 64 units, 1,242 exports | 0 |
| HOL4's closure | 921 | 28,386 | not run | 0 |
| MLton, 252 functors | 790 | 15,127 | not run | 0 |

`typed` at `lib/compiler/elab/elaborate.sml:2231`, the application where no code is made, does not copy a generated datatype's constructors into `dataCons`, as `instance` does at `:1204`. The fix is seven lines. Nothing else differed.

**Equal hash, not equal bytes.** Analysis pickles are 2.9 times batch on `rune.build`, and 2.7 GB against 22 MB on MLton. So the layer needs one canonical writer. Analysis loading a basis cut to static alone was not tested here; that is E24's question.

**For the roadmap.**
- D1: three layers, plus a self section and sidecars, with per-export hashes. Take imports' identities out of the hash and positions out of hashed Mid. On `rune.build` the batch gain is remap, not the layering.
- A batch key must stay static plus ABI. Static-only is unsound: an internal compiler error, a link refusal, different bytes.
- D24: key by layer, and write the static layer canonically. MLton's reference stamps are the first thing to shrink.
- D27: the compiler and the LSP can share the static layer, given the fix in `typed`, the false error fixed, and a decision on the layout leak.

### E18. Independent checks of usages

**Question.** A key must cover what a compile reads, and nothing ties the two together but tests. Can usages be checked independently? Mask a compile to its recorded usages; track reads from `CompilerState`'s roots; verify all hits, closing issue 15; mutate the cache's code; re-inject issues 1-24.

**Prediction** (`results/E18/PREDICTION.md`). The first hole was found in E15, before this was written.
- The mask: most pass, with at least one real failure: wrong, none. It passes, and it does not cover what the holes were.
- Blanking: 40-80 of 335 roots matter: wrong, 26 of 339.
- Verify all hits fails until E19's property holds: not contradicted. With E19's fix in, all that were compared are the same.
- `--verify-cache` sees no fingerprint mutant: held.
- A dropped usage is caught by the mask: held for names.
- About half the issues can be re-injected: held, 12 of 24.
- At least one real hole: held.

**How.** `patches/E18-checks.patch`, on E15's. `RUNE_E15_EVICT` with `M` in `RUNE_E15_WARM` for the mask, at two depths. `blank/run.sh`, `blank/summary.py` for blanking. `RUNE_E18_ACROSS` for hits, in `across/`. `mutants/list.py`, `run.py`, `post.sh`, `gonly.sh`, `table.py` for 37 mutants and a control. `flags/oracle.sh`, `oracle2.sh` over 30 flags and variables.

**Result.**

**(1) The mask.** Usages only, structures cut to the paths named, fixity cut, under lazy load so that tables hold only the binders' closure: `rune.build` shallow 246 of 246, deep 246 of 246; MLton deep 51 of 51, mean 85 bases (`results/E15/lazy/`). It covers every lookup by name at depth and table reads outside the closure. It does not cover units a used unit's basis names, other units' text (it passes on the first hole below), or fingerprint hits.

**(2) Read tracking.** Each of the 339 roots blanked in a forked child before a compile, over 28 units: 26 matter (`blank/summary.txt`). By reading, which is judgement: settings 1, name supply 5, session units 6, basis tables 13, and `Source.files`, where another unit's text is covered by nothing. Blanking cannot see a flag at its default, which is why `flags/oracle.sh` exists.

**(3) Verify all hits.** An entry loaded with remap, its basis and code written again, compared with a fresh compile. Small projects: 9 of 9 the same, 6 not compared (`across/small.txt`). MLton's S47 with remapping forced: 216 across, 130 compared, 130 the same, 86 not compared, since a name raised `Missing` in a verify session (`across/mlton-verify2.txt`). None compared and different. Issue 15 can close once export of load holds.

**(4) Mutants** (`mutants/table.md`):

| Check | Mutants caught |
|---|---:|
| scenarios | 19 |
| fact edits, written for this | 6 |
| `mutate` | 5 |
| deep mask | 5 |
| `--verify-cache` | 4 |
| flags oracle | 3 |
| S42 | 1 |
| `soundness.sml` | 1 |

**13 of 37 survive everything** (appendix F). By reading, some are equivalent or need a driver not built. The mask catches all 5 dropped name usages, and is the only check that catches U3. `soundness.sml` caught 1 of 9 fingerprint mutants: its edits do not flip the facts.

**(5) Issues 1-24.**

| Issue | Mutant | Caught by |
|---|---|---|
| 1 | U1 | scenarios, mask |
| 2 | U6 | scenarios |
| 4 | C3 | none |
| 8 | F5 | none |
| 9 | C8, M3 | scenarios, `--verify-cache`; C8 also `mutate`, fact edits, flags |
| 13 | C10 | scenarios, `--verify-cache` |
| 15 | C6 | none: the guard is doubled |
| 16 | F8 | scenarios, `soundness.sml`, fact edits |
| 16 | F9 | none |
| 17 | C9 | none |
| 18 | C13 | scenarios |
| 21, 23 | C1 | none in batch |

Judgement, not injected: 3, 22, 24 (REPL); 5, 6, 10 (process); 7 (hash); 11 (stale); 12, 14, 19, 20 (cost).

**Holes on the stock compiler** (appendix D):
- **Bug 1, `bugs/inline-line/`: warm differs from cold, and a trace names the wrong line.** A compile reads the text of another unit: a copied function's frames go through `Source.lineColOf` (`lib/compiler/backend/code.sml:155`, `lib/compiler/util/source.sml:182`), and the `inlv` hash covers spans by offset. A same-size edit keeps the Mid and the basis, so the client's entry holds. Warm trace `a.sml:1:74`; cold `a.sml:2:41`. Seen from the other side, a comment above a marked function recompiles every unit that copied it. The trigger is rare; the class is exactly "an input the key missed".
- **Bug 2, `bugs/functor-budget/`: `--functor-budget` is in no key.** A hit where a miss is due. Reading `options.sml`'s assignments shows three settings in no key: `Expand.budget`, `Types.workLimit`, `Exhaust.workLimit`. `--type-work=1` and `--match-work=1`: warm exits 0, cold exits 1 (`flags/result2.txt`).
- **MLton never takes an entry across a change.** S47's published 236 units are 20 that must compile and 216 that hold (`across/mlton-verify.txt`). E13 traces and measures this as `loadsUnits`.

A pass here means the checks ran on small projects, nothing more.

**For the roadmap.** D20: `make check` takes the flags oracle, fact edits, the per-unit lazy verification and mask, root blanking, and across-verification, which closes issue 15 with E19's export of load. The fingerprint oracle stays a milestone. Selection by mention must not switch off remapping (D7, D13).

### E19. Codecs

**Question.** Does `export` of `load` hold byte for byte? What does generating one type's writer, reader and fingerprint from one description give?

**Prediction** (`results/E19/PREDICTION.md`).
- `export` of `load` fails at first, because a reader drops what only the hash needs, and holds once those fields leave: held.
- Issue 11's read-then-write gives other bytes: wrong. It gives the same bytes; the issue is stale.
- 66 hand lines from about 10 of description, a generator under 100: held closely, 64 lines from 7, a generator of 66.
- The same bytes and speed within 1%: held.
- Inside the cache, the unit version constants never decide anything: held, by reading.

**How.** `UnitBasis.exportAgain` in `patches/E19-codecs.patch`, run under `RUNE_E19_RT`, over `results/E19/functorgen.sh`'s programs, `rune.build` and MLton (`functorgen.txt`, `code-rw.txt`). The one-type spike is `gen.py`, `apply.py`, `spike.sh`, on `Env.valstatus` (`spike.txt`).

**Result.**
- **Export of load.** At first 9 of 18 units differed. A writer adds hash-only fields no reader keeps (a marked body's prims, aliases, known flags, inline hashes), and marked-body names sit in another table. So a basis holds a fingerprint inside its pickle. With those left out on both sides: the functor generator 13,363 of 13,363 units, `rune.build` 246 of 246, MLton with the Basis 791 of 791.
- **Issue 11 is stale:** code reads and writes back the same bytes, 246 of 246 (`code-rw.txt`).
- **One type:** 7 description lines and 66 generator lines against 64 hand lines. 15 lines stay by hand: `valFacts`, the table reads, the weak spot the plan names. A description can say a fact is in the fingerprint; it cannot say which table holds it unless the tables are declared too. The program and all 31 entry files are the same bytes. VM instructions, cold: 1,251,296,948 hand, 1,251,277,122 generated, -0.002%.
- **The full generator is untouched,** and `ty` and references are not field lists.
- **Seven version constants:** RBC 6, image 15, UnitFile 4, UnitBasis 14, UnitMid 5, UnitCache 10, RCS 2. By reading, inside the cache UnitCache, UnitBasis and UnitFile decide nothing, since `Config.identity` is in the configuration. They matter for `.rbu`, `.rbi`, `.rbm`, `.rbs`, bytecode and images. If D14 lets a source escape the awk's list, they become the last defence.

**For the roadmap.** D21: generate only after D1. Writer, reader and `sameVal` are safe and cost nothing; the fingerprint's table reads stay by hand unless tables are declared too. The cache needs no schema hash. D1: hash-only fields leave the pickle for a fingerprint layer, so that export of load is the identity.

### E20. Real runs and the scale fixture

**Question.** MLton and HOL4's closure through the LSP, for the first time. A generator of a synthetic monorepo from measured distributions. Planning stages to 100k files and 1000 builds, analysis to 1M lines. Where does each quadratic bite, which cap breaks first, and what is the memory?

**Prediction** (`results/E20/PREDICTION.md`).
- `rune.build`'s 271 MB within 15%: wrong, +70%.
- The heap breaks first on MLton: right.
- MLton cold 40-90 s, 1.0-1.6 GB live: wrong, 235 s and 8.5 GB.
- HOL4 "a project in itself": wrong, it just ran. Position mapping is smaller than feared.
- Depth 30-60 on Rune and 100+ on MLton: wrong, 20 and 65.
- `enrich` breaks at 5-10k files: wrong, at 1k.
- Analysis at 1M lines 5-6 GB: wrong, 9.9 GB.
- Memory: pickles 15%, syntax 20%: wrong, 0.7% and 53%.

**How.** Tree `bs-lsp`, b12141ecc with `patches/E20-caps.patch`, `E20-env-plus-origins.patch` and `E20-tools.patch` applied. `results/E20/baseline2.sh`; `mlton/run.sh`, `memory-mlton2.sh`; `hol4/run.sh`, `hol4/position-map.py`; `gen.py`, about 330 lines, deterministic for a seed, with `gen-as-run.py` for what actually ran; `shape/shape.py`; `plan.sh`, `plan-curve.sh`, `plan-select.sh`; `scale.sh`; `memory.sh` with `tools/memory.sml`; `quadratic/run.py`. Running notes in `NOTES.md`. Load 4-14.

**Result: the baseline** (`baseline2.sh`, `baseline/`). `rune.build` at b12141ecc is 455-465 MB retained, 511 MB peak, at the 512 MiB cap; 245 units; cold 12.4-16.1 s. The published 271 MB dates from 2026-10-24, before node types and 14 more units; that attribution rests on the breakdown and git history, not a bisect.

**MLton's 606 files,** each cap in the order it broke (`mlton/`):

| Run | Result |
|---|---|
| stock | heap exhausted at 26.5 s, 347 of 606 project units |
| heap 1 GiB | deadline at 30 s, 382 of 606 |
| heap 5 GiB, deadline 540 s | heap exhausted at 138 s, 506 of 606 |
| heap 9 GiB, in process | heap exhausted at 336 s |
| **heap 15 GiB, 20 GB address space, deadline 780 s, Env fix** | **completes** |

The complete run (`mlton/full/`): cold 235 s, hover 0.08 s, definition 0.05 s, leaf 72-78 s, of which 69 s reloads 789 units, 17.3 GB RSS. Signature specifications are copied into every unit's basis: pickles reach 42 MB per unit and 2.7 GB in total, for 8 MB of source. `gen.py --nested-sigs 1.0` reproduces it on the same 30k lines: pickles 4.9 to 151 MiB, typing 48 to 290 MiB, check 4.3 to 12 s (`memory/p30.txt`, `n30.txt`).

**HOL4's closure** (`hol4/`): E9's filtered tree, 746 units, 212,207 lines. Stock dies at the 30 s deadline with 223 of 746 units. With caps and the fix: cold 53.9 s, all requests succeed, no type-work override, leaf 11.8-20.9 s; in process, 26.5 s and 1,111 MiB. The filter changes 36 of 745 files and 413 of 212,787 lines, and preserves every line count, so columns need a map on 0.2% of lines. Theory scripts stay out of reach, not being in the closure.

**The generator's distributions** (`shape/shape-*.json`):

| | Rune | All of Rune | MLton | HOL4 boss |
|---|---:|---:|---:|---:|
| Files | 106 | 1,240 | 606 | 746 |
| Lines | 43k | 131k | 198k | 212k |
| Depth in files | 20 | 14 | 65 | 100 |
| Signature files / lines | 8.5% / 1.5% | 14% / 16% | 45% / 8% | 47% / 20% |
| Functor files | 1% | 3% | 40% | 1% |

Calibration: retained 9.0 KB per line against Rune's 8.8; cold batch 516k instructions per line against `rune.build --no-cache`'s 600k. Fan-out is the weak spot: the fixtures ran at a mean of 2.6, and `gen.py` now defaults to 3.9, still under the measured 6. The brief's 1000 builds over 100k files means 125 files per library, about four times what any corpus shows.

**The planning curve,** seconds per check, every build a target (`plan/`). "s" is the sparse fixture:

| Files / builds | Read all builds | Membership | `uris` | Full `enrich` | `W.select` | `Deps.order` |
|---|---:|---:|---:|---:|---:|---:|
| 1k / 10 | 0.12 | 2.5 | 0.12 | **21** | 1.2 | 0.018 |
| 3k / 30 | 0.41 | 11.6 | 1.3 | **211** | 7.0 | 0.11 |
| 10k / 100 (s) | 1.7 | 27 | 11 | **>590**, timed out | 9.9 | 1.1 |
| 30k / 300 (s) | 3.2 | 67 | 83 | not run | 30 | 8.6 |
| 100k / 1000 (s) | 16.1 | >500, timed out | not reached | not reached | **409** | **153** |

`W.select` at 100k files read 992 candidates and held 1.96 GB. `Project.read` is linear, but `enrich` re-reads every target on every check and `W.select` then reads every candidate again. Lexing, parsing and `Deps.analyse` run at 150k lines per second (`plan/parse-rate-s1m.txt`). `enrich`'s apply step extrapolates to about 37 minutes at 10k files, not measured. **The discovery path avoids all of this** (`scale/f100k-discover/`): with no target, `f100k` plans in 0.34 s, cold 17.4 s, leaf 1.7 s, but it sees only builds in the root and in ancestor directories.

**Analysis, in process, with the Env fix:**

| Lines | Units | Time | Retained | RSS |
|---:|---:|---:|---:|---:|
| 117k | 1,000 | 13.8 s (a phase in the server) | 1,052 MiB | 1.2 GB (peak live, server) |
| 351k | 3,001 | 59 s | 3,030 MiB | 4.1 GB |
| 1.17M | 10,003 | 641 s | 9,945 MiB | 14.6 GB |

Time grows 46 times for 10 times the lines. GC is 29% of the check at 300k (`memory/gc-f300k.log`); the rest at 1M was not separated.

**Which cap breaks first:**

| Cap | Breaks at | How it fails |
|---|---|---|
| 30 s deadline (`lsp/service.sml:38-41`) | 1,000 files with one target: 25.6 s of planning before analysis starts (`scale/f100k-stock`). Also HOL4 and 60k lines | the whole check restarts each time |
| 512 MiB heap (`lsp/server.sml:30`) | 40k lines passes at 514 MB; 60k fails with the heap full (`scale/c40-stock`, `c60-stock`) | a heap budget error, or thrash into the deadline |
| equality work, the VM's default | one declaration of 14-28k lines | VM abort |
| 10,000 inputs (`api/analysis.sml:63`) | 1.17M lines at the brief's 100 lines per file: `s1m`, observed | an immediate `Fail` |
| 1.5 GiB address space (`lsp/jobs.sml:127`) | not broken at a 1.24 GiB heap | |
| 128 MiB text (`api/analysis.sml:64-66`) | not reached; about 3.4M lines | |
| type work, 50M | not reached in analysis | |

**What the memory is:** the first breakdown (`memory.sh`; MiB):

| | `rune.build` | HOL4 | `f100k` | `s1m` | MLton |
|---|---:|---:|---:|---:|---:|
| Total | 426 | 1,111 | 1,052 | 9,945 | 8,476 |
| Syntax | 226 (53%) | 586 (53%) | 535 (51%) | 5,247 (53%) | 533 (6%) |
| Typing | 68-76 | 160 | 200 | 1,614 | 4,895 (58%) |
| Occurrences | 52-55 | 116 | 133 | 1,307 | 117 |
| Facts | 50 | 160 | 96 | 946 | 126 |
| Uses | 17-21 | 51 | 58 | 570 | 52 |
| Pickles | 2.9 (0.7%) | 19 | 14 | 140 | 2,707 (32%) |
| Text | 4 | 15 | 9 | 85 | 12 |
| Basis's share | 55 (13%) | 78 (7%) | 28 (3%) | not computed | 85 (1%) |

The incremental parser's reuse structures are the largest thing, and they can be rebuilt at 150k lines per second. The interface itself is under 1%, except on MLton. MLton's typing appears to hold each unit's loaded environment, deduced from reading and consistent with the nested-signature run.

**Extrapolations, not measurements:** 10M lines would be 88 GB at measured density, 430 GB at MLton's.

**Bugs** (appendix D).
- **Analysis is quadratic in a unit's declarations.** `Env.plus` (`lib/compiler/elab/env.sml:131-136`) filters every origin on every declaration. Batch has no origins and stays linear.

  | Lines in one unit | Stock (`quadratic/out.jsonl`) | With the fix (`NOTES.md`) |
  |---:|---:|---:|
  | 14,000 | 17.4 s | 1.8 s |
  | 28,000 | 83.6 s | 3.8 s |

  The fix is six lines. `rune.build`'s check goes from 11.6 to 6.6 s. Digests of binders, types and used names equal stock's for 145 of 145 units.
- **A large declaration kills the worker.** The VM aborts with `equality work limit exceeded`, uncatchably, at `lib/compiler/syntax/incremental.sml:147` (`bugs/equality-work/`). HOL4's largest file is 27,572 lines.
- **Membership is quadratic.** `configurationFor` (`lsp/workspace.sml:80-91`) parses a URI for each scoped entry on every miss: 29 ms, 32M instructions and 27 MB per call at 1,001 entries, 15 of the 17 s of `enrich` at 1,000 files.

**For the roadmap.** D28: state a scale target, since the LSP plan has none, and remove the 10,000 and 128 MiB caps once it holds. They are not what stops anything: the heap stops ordinary code at 40-60k lines and the deadline stops a configured target at about 1,000 files. D27: interface bytes are tiny on normal code, the bulk is recomputable or sidecar material, and signature sharing in pickles is a precondition for MLton-shaped code. Apply the Env fix first, or later baselines mislead.

### E21. The batch compiler at scale

**Question.** The same fixture through `--units`: cold, warm, after an edit, with `-j`. The brief's "extremely large codebases" is otherwise never measured outside the editor.

**Prediction** (`results/E21/PREDICTION.md`).
- 1M lines takes 20+ minutes and over 10 GB: wrong, 5 minutes and 4.8 GB.
- A no-op is 5-10% of cold: wrong, 39-40%.
- An interface edit recompiles users of the changed names only: right.
- `-j` under 3 times on 16 CPUs: too hopeful. It gives no speed-up.

**How.** `results/E21/run.py`, `curve.sh`, per fixture in `f100k/`, `f300k/`, `f1m/`, one job; `parallel-min.sh`.

**Result.** Seconds / G; "recompiled" counts `--explain-rebuild`'s lines in `top-interface-added.out`:

| Lines | Units | Cold | RSS | Warm no-op | Leaf | Most-used module, body | Interface added (recompiled) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 117k | 1,000 | 22.9 / 60.4 | 0.55 GB | 7.8 / 23.5 | 6.1 / 23.7 | 7.6 / 24.7 | 6.3 / 24.1 (6) |
| 351k | 3,001 | 52.9 / 196.8 | 1.65 GB | 15.4 / 76.4 | 16.2 / 76.6 | 16.5 / 76.8 | 16.8 / 77.1 (11) |
| 1.165M | 10,003 | 295.9 / 766.3 | 4.81 GB | 91.3 / 306.2 | 90.4 / 306.6 | 89.3 / 306.4 | 73.8 / 306.3 (4) |

- **Nothing stopped it up to 1M.**
- **On this fixture a no-op costs 39-40% of cold at every size, and a small edit costs what a no-op costs.** That is the curve for E15. Real corpora differ: a no-op is 19.5% of cold on MLton, 32.4% on HOL4, 53.1% on `rune.build` (E15), and MLton's worst edit is 493G against 83.9G (E13).
- Cold is slightly superlinear: 516k to 658k instructions per line.
- A body edit of a module with fan-in 88 recompiles only that unit.
- At 10M lines this extrapolates to about 50 minutes cold, 15 minutes warm and about 48 GB, which does not fit this machine.

**`-j 8` gives no speed-up.** At the default threshold, 16,384 bytes of text (`main.sml:991-993`), few units qualify, and `f300k` gets slower: cold 75.5 s, warm 34.4 s. Lowering it on `f100k` (`parallel-min.txt`), where one job took 22.9 s:

| Threshold | Jobs | Wall | CPU |
|---:|---:|---:|---:|
| 1,024 | 8 | 19.95 s | 59 s |
| 256 | 8 | 23.7 s | 141 s |
| 256 | 16 | 27.4 s | 218 s |

The parent's linear pass is the floor. `-j` at 1M lines was not run.

**For the roadmap.** D25: do not count on `-j`; `parallel.sml` needs rework, not tuning. The warm path is the first thing at any size. D28: batch has no cap of its own to 1M lines.

### E22. Contexts that are the same

**Question.** For each file in several builds, how many candidates really differ, under real spellings? What happens to prompts? What of loose files and `use "x.sml"`?

**Prediction** (`results/E22/PREDICTION.md`).
- Over 90% of contexts are the same: right, 96.6% of files.
- Under 5% of prompts remain: right, 1.9%.
- One file spelt two ways is two units: right, 149 files.
- A factor of 3 in memory: right.
- `use` is unbound in a loose file: right.
- A file in no build gets the Basis, no prompt and a hint: not enough. Such a file is the common case, and only 251 of 726 sampled are clean with the Basis alone.

**How.** `tools/contexts.sml` (`patches/E22-contexts-tool.patch`), `results/E22/run.sh`, `analyse.py`, `summary-repo.txt`; `fixture/`; `loose/`; `zero/run.py`.

**Result** (`summary-repo.txt`).
- 74 of 88 builds are readable, 14 needing path variables; 15 of those stop at a diagnostic.
- 826 files are in a build. 232 have 2 or more candidates, 1,360 in all.
- **Real divergence in binders: 8 of 232 files (3.4%).** The cases are `Config` from `build/config.sml` against `lib/compiler/config.sml` and the files that use it, plus win32 32 and 64.
- **Prompts today under discovery: 210. On real divergence: 4 (1.9%).** 16 and 9 would prompt if printed types counted, which is an artefact: the same type prints as `SML90.instream` or `TextIO.instream` depending on which Basis files mention selected.
- 118 of the 232 have a candidate that never reaches them; `lib/compiler/frontend.build`, for one, fails at unit 1 because it cannot stand alone.
- **Spellings:** 149 of 826 files have 2-5 spellings, so one file really is several units.
- **Memory if equal contexts shared:** 7,611 MB to 2,335 MB by text share, a factor of 3.26; 3.43 by binders.
- **Fixture** (`fixture/`): 301 of 307 files have 2 or more candidates, all one context by construction, so it says nothing about real repos.

**Loose files, observed** (`loose/`, `zero/out.txt`).
- `use` is unbound in batch and in the LSP, and works in the REPL. The first error hides the rest of the file.
- `use` barely matters: top-level `use` appears in 1 of 3,955 tracked files, and 0 of 1,751 in HOL4's `src`.
- What matters: **3,131 of 3,955 tracked SML files (79%) are in no readable build.** Of 726 sampled, with the Basis alone: 251 clean, 416 with unbound names, 59 with other errors. The unbound names mostly come from file lists kept in the Makefile.

**For the roadmap.** D26: prompt only on real divergence, comparing binder locations, never printed types. Drop candidates that cannot reach the file. A file in no build is the common case and needs more than the Basis: the nearest build's context, no prompt, a hint, and analysis that continues past the first error. Binding `use` is not the answer. D3: canonicalise spellings first.

### E23. Cut-off in analysis

**Question.** A leaf with everything reused still costs 0.9 s at 117k lines and 69 s on MLton (E20). What does it really cost, and what removes it? `prefix:=false` is never reset (`lib/compiler/api/analysis-engine.sml:137`), but it already reuses everything before a leaf, so usages should not move the leaf number. The suspects are the positional cursor (`:131`), a name made of the file and its rank among the inputs (`:9`, `:254-255`), a reload of every unit on every run (`:32`, `:206`), and `load` rehashing each identity (`lib/compiler/driver/unitbasis.sml:2929`). On leaf, interface and early-file edits: is p95 250 ms reachable for a leaf, and at what scale? How many units does a usage check keep on an interface edit? Does an early-file edit cost a leaf's price? Which of this needs D1's layers, and which needs only keeping what is already computed?

**Prediction** (`results/E23/PREDICTION.md`), written after reading the engine and one smoke run of a stock leaf, before any table.
- About half of the server's leaf is not the engine: right on `rune.build`, 1.0 s at 512 MiB against 0.48 s at 2 GiB.
- The engine's leaf is load 45-55%, flat lists 15-25%, key hash and `Source.register` 5-10%: right at `f100k`, at 45-50%, about 20% and 8%, with plan encode and hash another 9% (by the report: the accounts' output was not kept).
- Kept units take the engine's leaf under 30 ms on `rune.build` and `f100k`, and MLton's under 2 s: right, 8 ms, 10 ms and 34 ms.
- A walk of 1,000 units costs about 10 ms: wrong, 0.13-0.14 s at `f100k` (`raw/f100k/nkf`, a leaf body's first repetition and its restore). So the fast path, letter `f`, was needed.
- The flat lists then leave 40-100 ms at `f100k`: wrong, the whole leaf is 10 ms in process.
- p95 250 ms is reachable at 100k lines only with plan, file reads and `enrich` memoised: right, and it holds further on the fixtures, to 351k lines, but the memo was not enough. `f100k` needed closed units too: `nkfsw` at 4 GiB is 0.39 / 1.37 s, `nkfswd` at 512 MiB 0.064 / 0.094 s.
- An early body edit costs a leaf, and an early comment that moves spans needs an identity without spans: right.
- An added name keeps over 95% of later units: right, 99.5-100%.
- A datatype breaks 15-30% of later units on `rune.build`, more on MLton: `rune.build` 14% (11 of 79), just under; MLton less, not more, 6% (23 of 383).
- Go-to-definition in a reused client goes stale when spans shift: right, observed.
- D1's layers are needed for very little of this: right for cut-off. Sharing with batch is another matter (below, and E24).

**How.**
- **Baseline.** Tree `bs-lsp`: `b12141ecc` with A's `E20-caps`, `E20-env-plus-origins` and `E20-tools`, so the Env fix is on throughout. That is "stock" (`results/E23/tools/bench-eager.rbc` in process, `bs-lsp`'s `bin/e23-base.rbc` in the server). E15's patch lies beneath the prototype, its flags off unless stated.
- **Inputs.** `rune.build`'s come from `bs-base`, read-only. The first runs analysed `bs-lsp`, whose sources the prototype changes, and were thrown away (`raw/discarded/`).
- **The prototype,** `patches/E23-E24-prototype.patch`, 737 added lines shared with E24, behind letters in `RUNE_E23`:
  - `n`: a unit is named by its file and a rank within that file, not its place among the inputs.
  - `k`: units stay loaded between checks, a *world*, and usages decide reuse past a change.
  - `f`: a changed input is elaborated at its own saved position, with no walk.
  - `s`: an identity without origins.
  - `d`: closed units drop syntax, typing, facts and uses.
  - `w`: a worker memo of plan, discovery and stats.
  - `z`: E15's lazy load on the stock path: a reused unit taken without its basis, a compile given what it names.
  - The stale-state rule: a walk happens only when an identity moves.
- **In process:** `runall.sh` and `tools/bench.sml`, with edits from `sc/*.tsv` against one context; `summary.py` reads `raw/`. With `--oracle`, a fresh stock analysis follows every edit. Heaps: 4 GiB on `rune.build` and `f100k`, 5 GiB on HOL4, 15 GiB on MLton.
- **Instructions:** `perf-leaf.sh`, `perf/results.txt`, `instructions:u` from `perf stat`.
- **Through the real server:** `replay.sh`, `replays-rune.sh`, `replays-final.sh`, `queue4.sh`, by E20's `tools/replay.rbc`; `pct.py`, `replay-table.py` read `replay/`. Each leaf there is a comment appended to the last unit.
- Load 1-5. Seconds are medians of 1 to 5 repetitions, and indications.

**A leaf in this section.** A *leaf comment* is a comment appended to the last unit. A *leaf body* is a body edit near the end: `src/driver/main.sml`, `m7_6.sml`, HOL's `patternMatchesLib.sml`, MLton's `elaborate-core.fun`. Only the leaf body is a leaf in the sense of *The programs*. The instruction counts and the server's table below are leaf comments. An early edit is at input 26 of 106 on `rune.build` (`source.sml`), 4 of 1,000 on `f100k`, 79 of 746 on HOL4 (`Feedback.sml`) and 42 of 606 on MLton (`layout.sml`).

**Result: where stock's leaf goes** (`replay/`, `raw/`).
- **In process, stock's leaf is cheaper than the server's.** Leaf comment: `rune.build` 0.20 s, `f100k` 0.61 s, HOL4 0.80 s, MLton 69 s. So E20's "reloading is the target" is half the story.
- **Half of `rune.build`'s server leaf is the heap cap:** 1.00 s at 512 MiB, 0.48 s at 2 GiB, with the same 150 MB allocated per check.
- **A build as a target costs far more than E20 measured by discovery:** 19.1 s on `f100k` against 1.7 s, 9.3 s on HOL4. Analysis is about 1 s of `f100k`'s 19.1 s (`replay/f100k-stock/phases.jsonl`). The rest comes before it: a `discover` job runs `enrich` (`src/lsp/worker.sml:45-48`), and the check runs it again (`src/lsp/worker-analysis.sml:206`).
- **Reloading is not all of the engine's leaf.** Of the 0.47 s walk at `f100k`, load is 0.23-0.29 s, by the report; the rest is key hash, `Source.register` and library-boundary steps.
- **The chained key does not block reuse:** confirmed, as X4 read it.

**Result: in process,** seconds, stock → prototype, units re-elaborated in brackets (`runall.sh`, `summary.py`, `raw/`):

| Edit | `rune.build` | `f100k` | HOL4's closure | MLton |
|---|---:|---:|---:|---:|
| Leaf comment | 0.197 → 0.008 | 0.61 → 0.010 | 0.80 → 0.17 | 69.4 → 0.034 |
| Leaf body | 0.35 (3) → 0.14 (1) | 0.62 (2) → 0.015 (1) | 1.40 (14) → 0.85 (1) | 102.6 (27) → 1.35 (1) |
| Early body | 3.3 (80) → 0.020 (1) | 10.1 (996) → 0.012 (1) | 22.2 (667) → 0.060 (1) | about 230, deduced → 0.05 (1) |
| Early comment, spans move | 2.9 (80) → 0.017 (1) | 10.7 (996) → 0.010 (1) | 22.8 (667) → 0.045 (1) | not run → 0.044 (1) |
| Add a name | 3.6 (80) → 0.107 (1) | 12.2 (996) → 0.45 (6) | 18.3 (667) → 0.53 (1) | not run → 50 (2) |
| Datatype gains a constructor | 3.8 (80) → 0.68-1.22 (12) | 11.6 (996) → 1.16 (58) | 16.5 (673) → 14.0 (205) | not run → 100 (25) |

- The prototype is `nkfs`, except MLton's add and datatype, which are `nkfsd`: `nkfs` ran out of the 15 GiB heap on that add (`raw/mlton/nkfs.txt`).
- MLton stock ran out of heap after the leaf body, so its early rows have no stock measurement. The 230 s is its cold, 230.5 s, taken as the price of an edit that early.
- `rune.build`'s datatype edit ran twice, 0.68 and 1.22 s. The oracle and leak runs give 0.6-0.7 s.

**Instructions.** `instructions:u` (`perf-leaf.sh`, `perf/results.txt`). A leaf here is (cold plus 22 leaf comments, less cold) over 22:

| | Leaf, stock | Leaf, `nkfs` | Cold, stock | Cold, `nkfs` |
|---|---:|---:|---:|---:|
| `rune.build` | 1.46G | 42.6M | 28.9G | 24.9G |
| `f100k` | 4.58G | 40.3M | 62.7G | 52.5G |
| HOL4's closure | 5.63G | 549M | 115.4G | 106.9G |

**With E15's lazy load on the stock path,** seconds (`raw/*/z`), so that no saving is counted twice:

| | `rune.build` | `f100k` | HOL4's closure | MLton |
|---|---:|---:|---:|---:|
| Leaf comment, stock | 0.197 | 0.61 | 0.80 | 69.4 |
| Leaf comment, `z` | 0.092 | 0.37 | 0.58 | 0.42 |
| Leaf comment, `nkfs` | 0.008 | 0.010 | 0.17 | 0.034 |
| Leaf body, stock | 0.35 | 0.62 | 1.40 | 102.6 |
| Leaf body, `z` | 0.36 | 0.32 | 1.09-2.29 | not run |
| Leaf body, `nkfs` | 0.14 | 0.015 | 0.85 | 1.35 |

E15's load alone gives 164 times on MLton and 1.4-2.1 times elsewhere, on a leaf comment; on a leaf body nothing on `rune.build` or HOL4. Keeping units gives the rest. With units kept, E15's load adds nothing to a warm leaf on these four corpora (E24's `raw/*-lazy-edit` against `*-eager-edit`). `s1m`'s `all.sml` is the exception: 0.49 s eager, 0.08 s lazy. No `z` run was counted in instructions.

**Through the real server,** seconds for a leaf comment (`replay.sh`, `pct.py`):

| Corpus | Stock p50 | Prototype p50 / p95 / max | Heap, stock; prototype | RSS | Hover | Completion |
|---|---:|---:|---|---:|---:|---:|
| `rune.build` | 1.00 | 0.022 / 0.042 / 0.044 | 512 MiB | 666 → 159 MB | 26 → 4 ms | 169 → 8 ms |
| `f100k`, 117k lines | 19.1 | 0.064 / 0.094 / 0.155 | 4 GiB; 512 MiB | 2.49 GB → 293 MB | 86 → 4 ms | 523 → 11 ms |
| `f300k`, 351k lines | not run | 0.201 / 0.217 / 0.732 | 512 MiB | 769 MB | 7 ms | 54 ms |
| HOL4's closure, 212k lines | 9.3 | 0.248 / 0.275 / 0.368 | 5 GiB; 512 MiB | 2.70 GB → 354 MB | 95 → 15 ms | 2 → 2 ms |
| MLton | 72-78 (E20) | 0.099 / 0.121 / 0.128 | 15 GiB | 17.3 GB (E20) → 14.2 GB | 80 (E20) → 6 ms | 2 ms |
| `s1m`, 1.17M lines, 10,018 units | not run | 1.185 / 1.334 / 2.410 | 2 GiB, by discovery | 2.05 GB | 15 ms | 653 ms |

- The prototype is `nkfswd` with `RUNE_E24_OPEN` naming the edited file, 20 leaves each (`replays-final.sh`, `queue4.sh`). With 20 leaves, `pct.py`'s p95 is the 19th of 20.
- Stock ran 10 leaves on `rune.build` and `f100k`, 20 on HOL4.
- Hover and completion are on the open unit.
- The table shows the best run. Other runs at 512 MiB gave HOL4 0.296 / 0.331 s (`replay/hol4-final-512m`) and `f100k` 0.111 / 0.202 s (`replay/f100k-nkfswd-512m`).
- The letters one at a time on `rune.build`, at 512 MiB, p50: stock 1.00 s, `nkf` 0.20 s, `nkfw` 0.12 s (10 leaves, `replays-rune.sh`), `nkfswd` 0.022 s.

**Correctness.**
- **A fresh stock analysis after every edit gives the same facts, uses and diagnostics in every check** (`raw/*/nkfs-oracle`): 42 of 42 on `rune.build`, 34 of 34 on `f100k`, 13 of 13 on HOL4. 13 of 13 on edits that introduce errors (`raw/rune/errors-oracle`). Observed.
- **On `f100k` and HOL4 the oracle run took the same paths as the timed run.** On `rune.build` it did not: `nkfs-oracle` walked where `nkfs` took the fast path, on the leaf body, the early body and the comments. There the fast path rests on `nkf-oracle` (early body, a comment at the end), `errors-oracle` (`mid-body-after`), and `complete-oracle` (the span shift).
- **MLton, `f300k` and `s1m` have no oracle.**
- **Bindings differ exactly where a span moved under a reused client:** in 16 of 42 checks on `rune.build`, 16 of 34 on `f100k`, 4 of 13 on HOL4. A comment atop `source.sml` moves 316 of 186,193 occurrences (`raw/rune/complete-oracle.txt`). This is a design point, origins by reference, and the prototype does not fix it.
- **Leak test:** 225 edits on `rune.build`, live 385 → 472 MiB after collection (`raw/rune/leak`). Latency is flat: leaf body 0.15, 0.14, 0.14 s by thirds. A tree that keeps units loaded needs an occasional compaction.
- **Not tested:** cancellation mid-walk.

**Is p95 250 ms reachable, and at what scale?**
- **For a leaf comment, held on the fixtures to 351k lines and on `rune.build` at 512 MiB; 0.275 s on HOL4; 1.33 s at 1.17M,** and on MLton at its 15 GiB. The worst single leaf passes 250 ms on `f300k` (0.73 s) and HOL4 (0.37 s).
- **At `f300k` there is no headroom shown:** by the end the worker's heap is at the 512 MiB cap with 507 MiB reported live, though nothing failed and in process 296 MiB survives a collection (`raw/f300k/nkfsd.txt`).
- **The `f300k` figure is after one fix to the prototype:** with its own rank lookup still in the worker's path the same run gave 0.654 / 1.295 s (`replay/f300k-final-512m`).
- **A body edit costs its unit's own elaboration,** and no replay measured one. In process that is 0.14 s on `main.sml`, 0.85 s on `patternMatchesLib.sml`, 1.35 s on `elaborate-core.fun`. Most of HOL4's 0.25 s is the same thing: a median 0.20 s of analysis on `bossLib.sml` (`replay/hol4-final/phases.jsonl`).
- **At `s1m`, no.** The median leaf is 0.73 s of analysis, 0.18 s of stats and 0.21 s of view (`replay/s1m-final/phases.jsonl`). In process the same edit is 0.64 s on `all.sml` and 0.05 s on a module (`raw/s1m/nkfsd`). By reading, the cost is `Env.pathOf` per tycon (`lib/compiler/elab/env.sml:512`), O(top-level structures); E24's lazy view, at 0.08 s, agrees. At 1M lines a leaf needs a path index, file events and a per-unit view: deduced, not measured.

**An interface edit: how many later units does a usage check keep?** Held of held plus broken, `raw/*`:

| Edit | `rune.build` | `f100k` | HOL4's closure | MLton | `s1m` |
|---|---:|---:|---:|---:|---:|
| Add a name | 79 of 79 | 990 of 995 | 666 of 666 | 562 of 563 | 9,998 of 10,000 |
| Datatype | 68 of 79 | 938 of 995 | 469 of 671 | 360 of 383 | 9,942 of 10,000 |

What remains is reloading what follows. At `s1m` eagerly an add costs 11-14 s and a datatype 13-16 s (`raw/s1m/nkfsd`). That is O(later units), not a leaf's price. A reload of clients only was not tried.

**Does an early-file edit cost a leaf's price?** Yes for bodies and comments: 5-60 ms on every corpus, with the span-free identity. Without it a span move reloads all later units: on `f100k` 0.455 s against 0.012 s (`raw/f100k/nkf`, first repetition, against `nkfs`).

**Which of this needs D1?**
- **Keeping alone:** names, positions, no reload, the plan memo, per-unit lists, a query at its position, usage reuse (usages are batch's existing fingerprints), closed units.
- **One piece of D1:** origins out of the identity, the spans of E17's split.
- **D1 proper:** sharing units across writers. After loading batch's entries, the first analysis edit of a unit gets another identity and other fingerprints, so usages break: `rune.build`'s early body breaks 55 of 79 at 2.6 s against 0.02 s, MLton's 111-116 s against 0.05 s (E24's `raw/*-b-*-edit`). Only a static fingerprint from one writer fixes that: deduced.

**Bugs in stock.** Eight, with reproducers in `bugs/README.md`, listed in the appendix. Those that shaped this result:
- completion in an early file re-elaborates every later unit, 2.35 s against 0.012 s (`raw/rune/complete-*`);
- `enrich` before every check, above;
- one progress message per input per check (`lib/compiler/api/analysis-engine.sml:216`, `src/lsp/worker-analysis.sml:67-69`), 1,000 on a leaf at `f100k`;
- every hover filters all occurrences (`src/lsp/worker-analysis.sml:140-144`);
- `syntaxAt` per input is quadratic (`src/lsp/worker-analysis.sml:285`, `lib/compiler/api/analysis.sml:127-129`).

**For the roadmap.**
- **D27:** the order is keep, then store, then share, since keeping does nearly all of it:
  1. the free fixes, no D1;
  2. kept units with positions and usages, needing D3's names alone;
  3. origins out of the identity;
  4. closed units and sidecars (E24);
  5. batch's layer, needing D1.
- **D28:** leaf p95 250 ms holds on the fixtures to 351k lines and on `rune.build` at 512 MiB, for a comment, with HOL4 at 0.275 s; state the body edit as one unit's elaboration on top. State an interface edit as O(later units) today, O(clients) to aim at.
- **D1:** cut-off needs one piece of it, the identity without spans. Sharing across writers needs the rest.
- **D3:** kept units need its names, with a rank within a file, and nothing more.
- **D26:** a printed path depends on the environment given: a lazy view prints `OS.Process.status` where the whole one prints `RuneStatus.status` (`bugs/README.md`, 6). So contexts compare by binder, never by printed type.

### E24. Analysis from units, and units from analysis

**Question.** What does batch's entry lack for the editor, and what would a sidecar of it cost, per unit, keyed so that it survives an upgrade? How fast is a cold start from a throwaway store, and does D28's 2 KB a line hold? Which of the config's settings can a static layer ignore (`lib/compiler/driver/unitcache.sml:124-137`)? What does "precompile as we edit" save a later compile, given that the back end starts from `decs` (`lib/compiler/driver/pipeline.sml:286-296`)? And does the nearest build's context serve the 79% of tracked SML in no readable build (E22)?

**Prediction** (`results/E24/PREDICTION.md`), before any run. A note there says the first cold result, 0.34 s on `rune.build`, came before its numbers were re-read, and that they stand as written.
- A sidecar is 500-1000 bytes a line: wrong, 147-165.
- It decodes at 200-400 MB/s: wrong, 26-62 MiB/s. The 0.3-0.6 s predicted for all units was nearly right all the same (0.23-0.66 s), since the bytes are fewer.
- `Env.tracking` adds 20-30% to pickles: wrong, 3.0 and 3.5 times. Its cost in allocation was not measured; in instructions it is +3.6% and +13.8%.
- Cold from a store is 1.5-2.5 s on `rune.build`: wrong, 0.24 s. HOL4 5-8 s: wrong, 0.99 s. MLton 20-40 s eager and under 5 s lazy: right, 39 s and 0.42 s.
- Resident 150 MiB on `rune.build` and 350 MiB on HOL4: wrong, 24 and 103 MiB, eagerly.
- 2 KB a line is met only with closed units and sidecars, and MLton misses it until signatures are shared: right for eager MLton, wrong for lazy, at 0.13 KB.
- Level, passes and fuel do not reach a static layer: right. Int bits, flex records, overloading and free type variables do: wrong on `rune.build`, where those varied move nothing, but flex records and overloading do change what is accepted.
- A full entry on save saves the whole unit: right, 12% and 5.7% of a later compile. A worker costs 3-5 times analysis: wrong for the whole program, about 1 time.
- The nearest build takes unbound files from 416 to under 150 of 726: wrong, 390. Going past the first error gives 3-5 times more diagnostics per file: wrong, 1.9 per failing file.

**How.** The baseline and the letters are E23's: tree `bs-lsp`, `b12141ecc` with A's `E20-caps`, `E20-env-plus-origins` and `E20-tools`; E15's patch beneath the prototype, flags off unless stated. New letters: `r` read the store, `B` names as batch's and a store written by batch, `c` go past a unit's first error.
- **Sidecar:** `results/E23/tools/bench.sml` under `RUNE_E24_SIDECAR`, `sidecar.txt`.
- **Tracking:** `track.sh`, `track/results.txt`.
- **Cold:** `cold.sh`, `oracles.sh`, `mlton-batch.sh`, `edit-table.py`, `raw/`; MLton's analysis store by E23's `queue3.sh`. Stores are thrown away; `cold.sh` and `results/E20/gen-as-run.py` regenerate them.
- **Config:** `config-split.sh`, with U's layer dump and `results/E17/compare.py`, on `rune.build`; `config-split.txt`. `--int-bits=31` and `--free-tyvars=generalise` are refused. `--int-bits=64`, another `--free-tyvars` mode and `--fuel` are in that file but not in the script. `settings/` holds two small programs.
- **Precompile:** `precompile.sh`, `precompile-all.sh`, `precompile/`.
- **Zero-build:** `zero-sample.py`, `tools/zero.sml`, `zero-table.py`, `zero-names.py`, on E22's sample of 726, one world per build.
- Load 1-5. Instructions are `instructions:u`; seconds are indications.

**Result: what batch lacks, and the sidecar** (`sidecar.txt`). An entry in analysis holds `facts`, `types`, `uses` and `syntax` as well as the pickle (`lib/compiler/api/analysis-engine.sml:14`). Batch writes none of them. As a sidecar, facts, uses and types with a per-unit string table:

| Corpus | Sidecar | Facts | Uses | Strings | Bytes a line | Write | Decode all | Largest unit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `rune.build` | 8.41 MiB | 2.10 | 4.18 | 2.11 | 147 | 0.40 s | 0.23 s | 0.67 MiB |
| `f100k` | 17.14 MiB | 4.79 | 9.12 | 3.21 | 152 | 1.01 s | 0.66 s | 0.72 MiB |
| HOL4's closure | 36.69 MiB | 4.34 | 9.46 | 22.86 | 165 | 1.17 s | 0.60 s | 10.60 MiB |

- Lines here count the Basis units: 60,019, 118,488 and 232,538. Types are 0.01-0.03 MiB. The round trip compares list lengths and the first fact's type: same.
- In their stores, MLton's sidecars are 31.5 MB (`results/E23/queue3.log`) and `s1m`'s 174 MB (`cold-s1m.log`).
- **The key cannot be the source hash alone,** as R suggested. Facts hold the types of imports, so a client's sidecar goes stale with unchanged text. It takes source hash, a digest of the unit's usages and the format version: deduced.

**`Env.tracking` on in batch** (`track.sh`), compiling without a store:

| | Instructions | Peak RSS | Pickle bytes |
|---|---:|---:|---:|
| `rune.build` | 28.93G → 29.96G, +3.6% | 287 → 296 MB | 0.78 → 2.30 MB, 3.0 times |
| HOL4's closure | 84.92G → 96.64G, +13.8% | 690 → 727 MB | 2.20 → 7.78 MB, 3.5 times |

So origins are too dear in the pickle. They can live outside the identity: letter `s` works, and a comment at a unit's top gives cut-off (E23).

**Result: cold from a throwaway store** (`cold.sh`, `raw/*-eager`, `*-lazy`). Closed units drop syntax and typing, and the open unit reads its sidecar. Letters `nkfsrd` eager, `nkfsrdz` lazy, `B` for batch's entries. Stock cold is E20's and then this tree's own in process (E23's `raw/*/stock`), which ran at lower load; so the second is the fair comparison. `s1m` has no stock run here: its figure is the prototype's cold from nothing.

| Corpus | Cold, E20; here | Eager | Lazy | Resident eager / lazy | KB a line | Peak RSS, lazy |
|---|---:|---:|---:|---:|---:|---:|
| `rune.build` | 12.4-16.1; 4.9 s | 0.24 s | 0.15 s | 23.6 / 8.3 MiB | 0.40 / 0.14 | 35 MB |
| `f100k` | 24; 13.9 s | 0.67 s | 0.35 s | 78 / 26 MiB | 0.67 / 0.22 | 67 MB |
| HOL4's closure | 53.9; 26.1 s | 0.99 s | 0.58 s | 103 / 35 MiB | 0.45 / 0.16 | 82 MB |
| `s1m` | 641; 357 s | 11.5 s | 5.7 s | 725 / 212 MiB | 0.64 / 0.19 | 480 MB |
| MLton, analysis's store | 235; 231 s | 39 s | 0.42 s | 8,605 / 26 MiB | about 43 / 0.13 | 68 MB |
| MLton, batch's entries | 235; 231 s | 11-12 s | 0.41-0.48 s | 1,387 / 27 MiB | about 7 / 0.14 | 69 MB |

- Resident is live after two collections. On `f100k` alone it falls further in the same process with nothing done, to 25.5 and 11.7 MiB; this was not explained.
- Stores: `rune.build` 16 MB, `s1m` 449 MB. On MLton the pickles are 2.8 GB from analysis and 23 MB from batch, whose whole store is 36 MB.
- **D28's 2 KB a line is met everywhere lazily, by 9 to 15 times, and eagerly on all but MLton,** by 3 to 5 times. MLton misses it eagerly from either store: at about 43 KB from analysis's pickles, about 7 KB from batch's. Analysis-written pickles must not be what loads.
- **Closed units during an analysis, with no store:** `f300k` 296 MiB, `s1m` 885 MiB (0.77 KB a line, E20's 9,945 MiB), MLton 8,627 MiB. Peak RSS at `s1m` is 2.05 GB to 3.33 GB.
- **Cold from nothing does not meet 2 minutes per million lines:** `s1m` 357 s in process, 315 s through the server (E23), E20's stock 641 s.

**The crux, from U, tested from the other side: analysis loads batch's entries as they are.** `rune.build`: 245 units held, 0 elaborated, 0.23 s (`raw/rune-b-eager.txt`). MLton: 790 units, 0 elaborated, 11 s (`raw/mlton-b-eager.txt`). These are batch's whole entries. E17's question stands: a basis cut to the static layer alone was not tested.

**Oracles** (`oracles.sh`, `raw/rune-*-edit`, `rune-b-*-edit`, `edit-table.py`). They ran on `rune.build` alone, with a fresh stock analysis at each of 28 checks. They are narrow (`RUNE_E24_NARROW`): facts, uses and bindings are compared on the units that hold facts, which is the open unit, one of 245. Diagnostics are compared whole.

| | Facts | Uses | Bindings | Diagnostics |
|---|---:|---:|---:|---:|
| Analysis's store, eager | 28 | 28 | 28 | 28 |
| Analysis's store, lazy | 1 | 28 | 28 | 28 |
| Batch's entries, eager | 28 | 28 | 1 | 28 |
| Batch's entries, lazy | 1 | 28 | 1 | 28 |

- Lazy facts differ only in printed paths: a lazy view prints `OS.Process.status` where the whole environment prints `RuneStatus.status` (2 of 13 lines, by the report: the dump was not kept).
- From batch, 19 of the open unit's 21 occurrences have other bindings, since batch has no origins. Go-to-definition out of a unit needs the sidecar.
- The 1 in the batch rows is the cold check, on no unit at all: the open unit holds no facts yet. The 1 in the lazy row of analysis's store is the cold check too, whose facts come from the sidecar.
- HOL4, MLton and the fixtures had no oracle here.

**What goes wrong.** Observed, on edits after a cold start.
- **From batch's entries the first edit pays.** Usages are checked against fingerprints analysis did not write. `rune.build`'s early body breaks 55 of 79, 2.6 s against 0.02 s; MLton's re-elaborates about 430 units, 111-116 s against 0.05 s. Later edits of that unit are at the fast path's price (`raw/rune-b-eager-edit.txt`, `mlton-b-eager-edit.txt`, `mlton-b-lazy-edit2.txt`).
- **A lazy world is not yet right on an interface edit.**
  - MLton from batch, first run: false type errors from the leaf body on, `IntInf.int * t` against `int * t` (`raw/mlton-b-lazy-edit.txt`). A fix to the overload table took them away.
  - After that fix, leaf, body, comment and add work, and the datatype edit stops on a prototype `Fail`: `a name of no unit`, kind 2 (`raw/mlton-b-lazy-edit2.txt`).
  - HOL4 from its own store, lazy, before that fix: the datatype edit reports a false `type mismatch between int and int`, where the eager run, stock and `nkfs` report nothing (`raw/hol4-lazy-edit.txt`). It was not rerun.
- **Lazy is slower on `s1m`'s datatype edit:** 51-75 s against 11-14 s eager. On an add it is faster, 4.5-8.5 s against 10-12 s (`raw/s1m-*-edit.txt`).
- **Closed units answer nothing yet.** In the prototype only a unit named in `RUNE_E24_OPEN` reads its sidecar. Hover, definition and find-references into a closed unit are not wired. Decoding all sidecars is 0.66 s at `f100k`, so find-references needs an index: deduced.

**Survives an upgrade.** A store seeded under one `Config.identity` loads under another: 245 reused, 0 elaborated, 0.23 s (`upgrade.txt`; the build of that bench was not kept). The prototype's key simply leaves the identity out. That is fine for a sidecar as a stale hint. For a static layer it is sound only with a front-end version in the key: deduced.

**Result: the config split** (`config-split.txt`), `rune.build`, 246 units, 13,665 exports, against a compile with no flags:

| Setting | Static hashes moved | Today's fingerprint moved |
|---|---:|---:|
| `-O0` | 0 | 1,927 |
| `-O2` | 0 | 0 |
| `--passes=simplify` | 0 | 1,927 |
| `--fuel` | 0 | 841 |
| `--target=stack` | 0 | 0 |
| `--int-bits=64` | 0 | 0 |
| `--overloading=topdec` | 0 | 0 |
| `--flex-records=topdec`, the default, so a run against itself | 0 | 0 |
| `--free-tyvars` | 0 | 0 |

- Level, passes, fuel, target and int bits are back-end, observed. `isa` and the inline lists were not varied, and go with them by reading.
- Overloading and free type variables moved nothing on `rune.build`, and flex records were not varied; all three are language settings. `settings/over.sml` and `flex.sml` show the first two change what is accepted (`settings/results.txt`). They stay in the static key. `--free-tyvars` was not tried on a small program.
- So a static key is format, hash probe, language settings, and name and source, with `Pipeline.fingerprint` out: deduced from the above.

**Result: "precompile as we edit"** (`precompile.sh`, `precompile-all.sh`), `instructions:u`, G, a leaf body with one unit recompiled:

| | Cold | Typecheck | No-op | Edit, nothing prepared | After an entry written on save |
|---|---:|---:|---:|---:|---:|
| `rune.build` | 26.33 | 6.97 | 10.58 | 12.02 | 10.58 |
| HOL4's closure | 72.94 | 19.90 | 25.58 | 27.13 | 25.58 |
| `rune.build`, E15 `abcdl` | 28.96 | 7.39 | 8.12 | 10.17 | 8.57 |
| HOL4's closure, E15 `abcdl` | 84.98 | 22.12 | 20.00 | 23.48 | 19.95 |

- The rows are two compilers, `bin/rune.rbc` and `rune-e24.rbc`, whose cold is 28.93G with no letters (`track/`). So compare within a row: E15 does not cost 10% cold.
- With E15's `u` as well, the no-op is 0.24G, but the run after the entry did not hit it, at 8.57G (`precompile/rune-warmu`).
- **A stored static layer saves nothing in a later compile:** deduced, not measured. A client that must recompile needs its `decs` (`lib/compiler/driver/pipeline.sml:286-296`).
- **A full entry on save saves 12.0% on `rune.build`, 5.7% on HOL4, and 15.7% and 15.0% under E15.** Those are the same instructions moved to a worker, not removed.
- **The fat-interface equivalent is Mid before the passes.** The front is 26-27% of a compile, so it saves at most a quarter of one unit's cost, and it needs `makesCode` on (`lib/compiler/elab/elaborate.sml:133`), which analysis avoids. Do not build it.
- **Analysis costs what a compile costs:** 24.9G for `nkfs` and 28.9G for stock, cold, against 26.3G for a batch compile and 7.0G to type-check. So it is 3.6 to 4.1 times type-checking. The surplus was not separated.
- **Unsaved text.** The prototype's bench writes on every edit. A real store writes from the save path only, under the owner's rule: deduced, not gated in the prototype.

**Result: zero-build files** (`zero-table.py`, `raw/zero-*`), E22's 726, one world per build:

| | Clean | Unbound | Other |
|---|---:|---:|---:|
| Basis alone (E22) | 251 | 416 | 59 |
| Nearest build | 262 | 390 | 74 |
| Nearest build, past the first error | 262 | 408 | 56 |

- A file takes a median of 40 ms. Going past the first error gives 1.9 errors per failing file.
- **The nearest build barely helps.** Of the 408 files failing on an unbound name, the first such name (`zero-names.py`) is defined in the same directory for 154, in the same two top directories for 41, elsewhere in the repo for 174, and nowhere as a structure, signature or functor for 17. 22 messages name nothing it could look up.
- The loose run in a world crashed with `Domain` after 12 files (`raw/zero-loose-*`), so E22's row stands.

**Not done:** origins by reference; a static layer alone, with value stamps gone; sidecars written by batch; find-references from sidecars; an oracle beyond `rune.build`'s open unit.

**For the roadmap.**
- **D1:** a static layer from one canonical writer, an identity without spans, and usages on the static fingerprint. Without the fingerprint, analysis over batch's entries re-elaborates clients on the first edit. Origins go by reference, resolved at read.
- **D2:** loading by need has more traps than E15 found. A lazy world broke on the overload table and on a name of no unit, and a printed type depends on the view.
- **D24:** keys by layer, split as above. Batch's static bytes are small: on MLton 23 MB against 2.8 GB.
- **D26:** for zero-build files use an implicit library over the directory and a repo name index, not the nearest build. Closed units make an extra context cheap on `rune.build`, 8-24 MiB, so sharing contexts can wait while few are open.
- **D27:** analysis can load batch's entries today; a static layer alone is still untested. Sidecars keyed by source hash, usage digest and format. Entries on save are a background `rune --build`: no new mechanism, no fat interface.
- **D28:** keep 2 KB a line, met lazily at every scale measured. Replace cold from nothing with cold from a store, seconds at 1M lines: 5.7 s. Resident at 1M lines lazily is 212 MiB.

### E25. Modules and separate compilation

**Question.** What do Appel and MacQueen, Leroy, Cardelli, Blume, Shao, Elsman, SMLSC, Harper and Stone, MixML, Backpack and *Build Systems à la Carte* say that the roadmap must not get wrong?

**Prediction.** None: this is reading.

**How.** Primary sources, by agent R, with DOIs checked against Crossref (`results/E25/doi-check.txt`). Notes in `results/E25/notes-elsman-smlsc.md`, `README.md`. What could not be read in full, and which version was read, is in *What the literature says* and *References*.

**Result.** The findings are in *What the literature says*. Those that changed the plan:
- **Backpack.** The POPL 2014 design failed because its semantics were entwined with Haskell's, not because of type classes. It shipped in GHC 8.2. Type classes make its soundness theorem false as Haskell stands, and what shipped has no separate code generation.
- **Blume's restrictions serve automatic dependency inference, not separate compilation as such.** With written order, a unit failing a rule costs speed, never correctness.
- **Overloading may be no obstacle:** Appendix E bounds resolution by the smallest enclosing structure-level declaration, and no SML author read names it as one.
- **dune's wrapping cannot be copied:** SML structures cannot hold signatures or functors.

**For the roadmap.** D17, reshaped: a failing rule costs speed. D1: GHC and MLKit are closer references than OCaml alone. D9: bounded by what structures can hold. D20: Elsman's statements give the form of each obligation.

### E26. Implementations

**Question.** What do CM, MLB, MLKit, Poly/ML, OCaml, GHC and Cabal do, from `~/reference`; and cargo, dune, smackage, holbuild and Bazel, from the web?

**Prediction.** None: this is reading.

**How.** Notes in `results/E26/notes-*.md`, at the revisions listed in *References*; clones under `results/E26/downloads/`.

**Result.** The findings are in *What the implementations do*. Those that changed the plan:
- **OCaml has no per-export hash,** and by default its `.cmi` hash covers locations. `.cmi`, `.cmx` and `-opaque` are not the whole reference for layers.
- **holbuild has no early cut-off.** It is a model for trust, not for cut-off.
- **No system read has a firewall, known calls and unboxed layout across it at once.**
- **An optimising aggregate has no ML precedent read;** a packaging one has CM's stable libraries.
- **The hash is the hash of serialised bytes in every system read.** Rune's third traversal is the outlier, and it is what diverged.

**For the roadmap.** Each decision's evidence cites its system there. D18: dune's practice makes a firewall a profile, though E13 removes the need. D19: E11 tests what the reading suggested, that packaging may deliver most of the warm saving, and finds it does not. D21: one description, from CM's `asdlgen` and MLKit's `pu` combinators.

### E27. Editors at scale, and tests against abstraction

**Question.** What do rust-analyzer and Salsa, clangd's background index, Merlin, HLS and `.hie`, Glean and SCIP do at scale? How do Rust, Go, C#, Kotlin, OCaml and Haskell let tests past an abstraction?

**Prediction.** None: this is reading.

**How.** Notes in `results/E27/notes.md`, with clones under `results/E27/downloads/`.

**Result.** The findings are in *What the implementations do*, *Editors at scale* and *Tests against abstraction*. Those that changed the plan:
- **Salsa has optional persistence,** which rust-analyzer does not enable. "No on-disk" is true of rust-analyzer, not of Salsa.
- **stack-graphs is abandoned:** drop it as a candidate.
- **CM, MLKit and dune all refuse the question of a file in two contexts.** Those that allow it pay. One owning library per file removes the prompt for code under a library.
- **Friend lists fit SML,** where a test is another unit. Anything that builds a library twice recreates the context problem.

**For the roadmap.** D11: a friend list and the `structure FooImpl` convention. D26: one owner per file. D27: positions and occurrences in a sidecar keyed so that they survive an upgrade. D28: state targets as cost functions.

### E28. Migration

**Question.** Can a migrator carry master and `win32-desktop`'s 24 build files? Does a set's hash cover `.build` text? Can `runedoc` leave MANIFEST? In what order can MANIFEST go? What does a live branch pay?

**Prediction** (`results/E28/PREDICTION.md`).
- Mechanical on master, about 31 library files, 8 additions and 1 removal: right in shape, 33 changed, 7 additions and 1 removal.
- `lib/ffi/win32/templates` needs a fallback: wrong. Re-deriving on the branch's tree gives its exports. 0 of the branch's 24 need judgement.
- The set hash covers `.build` text: right.
- Regeneration takes seconds to a minute per set: wrong. 269.5G, for one changed file per set, and a 0.08 s rehash gives identical bytes.
- 2-4 fixtures test MANIFEST's own errors: nearly, 6 are not plain conversions.
- The order is install, readers, index format: confirmed by running it. New: install needs no list at all.
- Conflicts on 2-3 of 7 files: fewer, 1 of 7.
- Not predicted, and the most useful finding: a boundary merges cleanly and hides what a branch added.

**How.** `results/E28/tool/{facts.sh,migrate.py,run-tree.sh}`: facts from the compiler's `BuildFile`, `Deps` and parser through E1's census tool, reproducing E1's `edges.csv` and `exports.csv` exactly on master. `patches/E28-migrator.patch`, `E28-generator.patch`, `E28-migrated-master.patch`. `tool/regen*.sh`, `rehash.py`; `tool/fixtures.py`, `fixtures-doc.py`; `tool/install-check.sh`; `tool/rebase{,2,3}.sh`, `verify-lib.sh`. Rebases ran in a private clone, since deleted. Load 7-24.

**Result: the migrator** (`master.summary`, `win32-desktop.summary`, `win32-desktop-24.txt`):

| | Master, 88 | `win32-desktop`'s 24 |
|---|---:|---:|
| changed mechanically | 33 | 3 |
| nothing to do | 28 | 6 |
| generated: rehash | 15 | 15 |
| need judgement | **12** | **0** |

- The 33 are 26 new boundaries (234 of 342 names kept) and 7 program edges; the 8 library edges, 7 additions and 1 removal, land in those 26. The Basis is left out, since it cannot have a boundary (E3).
- The 12 are the hand-written reach-ins of E1. `--after-d14` replaces all 17 whole-library lists in 8 of them, and `rune`, `runedoc` and `runeffi` then build; the compiler so built compiles hello (`after-d14.out`). All 12 still need a decision: 9 sub-build uses need a friend, 6 partial lists need partial import.
- **Checks:** 88 of 88 plan and round-trip; the file set unchanged on all 33; a second run changes 0; 33 of 33 libraries index; 159 of 159 programs byte-equal to baseline; the branch's tree 102 of 102, also idempotent.

**Generated sets** (`regen/run.out`, `regen/rehash.out`). The set hash covers `.build` text: recomputed by hand it equals the directory name on all 5 sets.

| Route | Cost | Needs |
|---|---|---|
| regenerate | 269.5G, about 85 s | pinned SDK and MSVC headers, a one-line generator patch |
| `rehash.py` | **0.08 s** | nothing |

The rehash's bytes equal the regeneration's on all 5. Only `library.build` differs per set: 1,699 new bytes in the tree, or 9.64 MB duplicated if the old set stays. The generator should export all its names: a client-derived list would hide `SDLGenerated`, which clients reach through `implements`. Regeneration needs the old set gone first (appendix D). On the branch, a rehash was not compared with a real regeneration.

**`runedoc` off MANIFEST** (`runedoc/fixtures.tsv`, `fixtures-doc.out`).
- All 21 fixtures convert mechanically: 15 tables equal the index, 4 were wrong or incomplete against it, and 2 are the cycle pair, which with `library.build` become a plain cycle test.
- All 14 `.lib` fixtures give the same result (exit, diagnostics, site). This was P's comparison, not the runner's goldens.
- 7 more test programs write a MANIFEST inline, so "21" undercounts.
- What blocks `runedoc` is reach: the index lives in `main.sml:338-436`, and `frontend.build` lacks `deps.sml`.
- The claim rule moving into the compiler makes the signature pass mandatory. On migrated libraries `runedoc` gives 0 claim errors over 27. The compiler rule needs a new fact, `claims`, since `Deps` knows names, not which name ascribes to which signature. It was not prototyped.

**`install.sh`, run, not read** (`tool/install-check.sh`, `install/run.out`; package-runtime stubbed):

| | Exit | Files | Basis `.sml` | Installed `rune` on hello |
|---|---:|---:|---:|---|
| with MANIFESTs | 0 | 822 | 278 | works |
| none | **0**, prints "installed" | 89 | **0** | refused |

702 sources under libraries are listed, and only 5 are unlisted, all `export.sml` of generated sets, which install copies anyway. So install needs no list and no `.build` reader. The order is appendix E.

**The window** (`rebase/run.out`, `run2.out`, `run3.out`, `live.tsv`). On `win32-desktop`:

| Scenario | Conflicts |
|---|---|
| control: rebased on master | 2, no `.build` |
| on migrated master | **+1**: `lib/ffi/win32/model/library.build` |
| on migrated master with rehashed sets | **+6**: that file and the 5 `current.build` |
| migrate the branch first, then merge | 2 |

The recipe is: rebase, take the branch's text on any `.build` conflict, run the migrator and `rehash.py`. It changes 3 files, and the result equals direct migration on every `.build` of 105.

**The trap.** With no rerun, master's boundary on `ffi/win32/common` merges without conflict and hides the branch's new structures. `--basis-index` exits 0 and a client fails with `unbound signature: WIN32_DESCRIPTIONS`. It is loud, but late. P's first migrator, reading only public names, then deleted a real edge; it now recomputes a boundary it wrote from the sources alone.

**Every live branch** (`live.tsv`, by `merge-tree`): 34 refs are ahead of master, backups included. 19 gain conflicts, 58 files, or 148 with sets. 15 gain none. The conflicts inspected were all `.build`; the counts were not filtered by type.

**For the roadmap.**
- D15: mechanical, no flag day and no window for text, since the target is today's grammar. Ship migrator and rehash together, with the recipe and a warning at `--basis-index` for the trap. Enforcement rules land after a window; they are the only thing needing one.
- D13: MANIFEST's end starts with the install guard and appendix E's order. Move the index before `runedoc` moves. Add `claims`.
- D16: sets stay outside the plan as explicit commands, and `.build` text stays inside their hash. Add a rehash mode to `runeffi`, keep `check` as the oracle.

### L1. A model of the cache

**Question.** Does the claim of a cache hit, stated once, hold in a small system that can be checked exhaustively, and how tight is it?

**Prediction.** None on file. The lead wrote the statement and the model together.

**How.** `results/L1/model.sml`, 157 lines of SML and not Rune's code; `run.sh`, compiled and run by the reference tree's Rune; `output.txt`. 54 projects, 2,916 edits between them, six policies. It is exhaustive within those bounds and proves nothing beyond them.

**Result.** The statement, the obligations O1 to O9 and the model's table are in *What a cache hit must satisfy*. Its three findings: a key that reads less than the compile breaks silently, and from the rebuild count alone looks like an improvement; a key is sound exactly when it covers the reads; and a firewall is not a key policy, since two policies hold the same key and one is wrong.

**For the roadmap.** D20: the obligations and which check serves each. D1: each layer is a claim that a consumer reads no more than that layer, and E18's mask can check it. D18: a firewall must change what the compile reads, not what the cache hashes. E17's directed probes then showed the model's hole on the real compiler.

## Constraints

**The language does not change.** What Rune accepts stays what `docs/language.md` says. Nothing here refuses a correct SML '97 program, under `--build` or anywhere else (D17). A change to what the language accepts is a change for Rune 2's document, not this one. The one exception is the owner's: D22's functor signatures, an extension beside `structure X = _virtual : SIG`, which refuses nothing.

**Bytes.** These hold after every milestone:
- **S41:** a warm build gives the bytes of a cold one.
- **S42:** `--units --whole` gives the bytes of a whole compile.
- **S43:** five hosts give one set of bytes (`check-cross`).
- **S58:** `-j` changes no byte.
- **A check changes no byte,** with lint and every new check on or off.

**Each proposal against them,** and how that was measured:

| Proposal | S41 | S42 | S43 and hosts | Evidence |
|---|---|---|---|---|
| Lazy load, binders-only hits (D2, D25) | holds, if every read faults in | holds | fine | 52 of 52, 246 of 246; one missed read found and fixed (E15) |
| Logical names (D3) | holds | fine | fine | 150 random builds, 0 disagreements (E16) |
| Layers and a per-export hash (D1) | holds with static plus ABI, today's contents; **not** with static alone | fine | fine | 421 builds, 0 disagreements, on today's fingerprint split per export (E17); a layout-only ABI was not run |
| Name-free keys | **broken** | fine | fine | 39 of 104 (E16). Rejected |
| LSP-written entries (D27) | equal bytes, or keyed apart | fine | fine | Analysis loads batch's entries as they are; entries on save are a background `rune --build` (E24) |
| Generated codecs (D21) | fine | fine | output committed or host-buildable | one type (E19) |
| Aggregates | holds | holds only with raw member Mid | fine | 90 of 90, 8 of 8 (E11). Dropped |
| A firewall | fine | breaks if units and whole see different Mid | fine | Not built (D18) |
| Mid kept after expand (Rune 2) | fine | bytes on 3 of 14, otherwise up to function order | fine | 14 programs, no gain (E14). Rune 2 keeps today's capture |
| Mid kept after simplify (Rune 2) | fine | ends, by construction | fine | Run 1.41 on HaMLet, 1.50 on MLton, 1.03 on the compiler (E14) |
| A build program (D29) | fine | fine | never needed for `rune.build` | Not built |
| Functor signatures (D22) | holds, if the fingerprint covers what a client compiled from | holds, as for a virtual structure | the fingerprint must agree on the five; `Pickle.hash` differs on `smlnj32` (E10) | Not built; E10 is on paper |

**Five hosts and Rune.** The compiler's sources still compile on MLton, Poly/ML, SML/NJ and MLKit, from a list that needs no Rune (D14). The hosts cannot read `.build` and need not. Speed and correctness of the compiler's own code are decided on Rune at tier 2; the hosts are measured for information (the owner's rule of 2026-10-21). A host's bug is marked `HOST-BUG`, not worked around.

**The bootstrap is `bootstrap.md`'s.** This roadmap touches it at one point, what hosts read and what `Config.identity` hashes (D14), and agrees with that plan's aim that a host needs almost nothing.

**Costs.**
- **A compile:** hello is 296M instructions, of which MANIFEST is 3.1%. Nothing here may put the index on that path: a compile computing it would cost 3.1 times hello's (E2).
- **`make check`** stays within what the budgets (`make perf-check`) allow. New independent checks run as tiers with stated cost.
- **The editor's budgets:** D28.

**Determinism.** Nothing in a key is a time (`lib/compiler/driver/unitcache.sml:24`). A stat memo is not a key. An output depends on config, source and basis, and nothing else: obligation O1.

**The owner's rule on unsaved text.** The LSP plan's: text that is not saved never publishes under a saved identity.

**Libraries are of Rune's own making.** Generic code goes into `lib/`, well tested (the owner's rule of 2026-10-10). A library's documentation stays complete (`AGENTS.md`), and `make check-docs` keeps every library's signatures documented through the migration.

**Live branches.** 34 refs are ahead of master, about 25 worktrees of win32 among them. No milestone touches a win32 branch, or migrates a `.build` file that one changes (D15). When that work has landed it pays one rebase and a mechanical step, as E28 showed on `win32-desktop`.

## The architecture

What Rune looks like once the milestones are done. Each part names the decision that argues for it.

```
workspace root file          roots, named targets                         (D4)
        |
library.build, *.build       a normal form, written by hand or printed     (D5, D6)
        |  elaborate; no compiler pass runs
        v
plan                         canonical text; hosts and editors read it     (D5, D14)
        |
        v
units, by logical name       library:path, written order                   (D3, D6)
        |  loaded by need, each unit against what it names                 (D2)
        v
cache entry                  head | static | ABI | code | Mid | self       (D1)
  sidecar                    positions, occurrences, facts, types          (D1, D27)
        |
        v
store                        frozen layers under one overlay               (D24)
        |
   +----+-----------+-------------+
   v                v             v
 compile          editor        runedoc
 static + ABI     static        exports
```

### The plan (D5, D6, D14)

A `.build` file elaborates to a plan, an immutable value with a canonical text form. Everything downstream reads the plan: the units driver, the API, the editor, `--build-list`, runedoc, `identity.sh`. A plan's `body` is compared and hashed; its `provenance` (input hashes, machine paths) is not.

Reading a plan runs nothing. The five host-built roots have theirs committed, so a host reads a flat list with no parser, and the compiler's identity hashes the closure the plan names. Any program may print a `.build`, which is how variants and generated sets work: `runeffi` does today.

The one language has few constructs: paths in written order, `implements`, `annotate`, `use` within a library, `inline`, `libraries` in a program's build, and a library's header, which calls that `requires`. The command line makes a plan too.

### Libraries (D7-D12)

A library is a directory with a `library.build`, whose header says what it exports, what it requires, who its friends are and which views it offers. A library with no header keeps today's meaning until D15's window closes. The deepest `library.build` owns a file. A library is elaborated from its declared imports alone, in a basis empty but for the Basis.

`requires` says what may be named, and is not transitive. What links is the closure of what a program names, from `Deps`' uses, never its tokens. A boundary is a filter with a hash of its own, so a client's key holds what it could see. The claim rule, in the compiler, makes a public structure's signature public. Fixity crosses a boundary. Two imports of one name in one scope are an error, and a rename at import resolves it; identity carries the library, so private names never clash.

A friend sees the unfiltered view. A Basis view is a set of seals loaded after the libraries, a filter on what a client can name. The Basis itself is a prelude: it is not a library with a boundary.

### Units and the restriction (D1, D2, D3, D17)

A unit has a logical name, `library:path`, with a rank for a file given twice. A program's own units are named from the workspace root. Spelling never reaches a key.

A unit is well-formed if it is shared and holds D17's four rules, entry if nothing depends on it, prelude if the build says so. Well-formed units have top-level names readable from syntax, so `Deps` and the editor can plan without elaborating. A shared unit that fails falls back to the linear prefix at a cost in speed, with a warning; entry and prelude units fall back with none. Nothing changes meaning: written order stays the semantics.

A cache entry has sections, each hashed apart:

| Section | Holds | Read by | In whose key |
|---|---|---|---|
| Head | identity, imports' identities, what the sections hash to, usages | lookup | |
| Self | source hash, warnings, flags, level, schemes, source names | the cache | never a consumer's |
| Static | types, signatures, fixity, equality, constructor status, per export | compile, editor | compile, editor |
| ABI | layouts, value and exception anchors, known and primitive facts, per export | compile | compile |
| Code | the code | link | |
| Mid | ToMid's output, inline bodies | `--whole`, inline | `inl`, `inlv` |
| Sidecar | positions, occurrences, facts, types | editor | never |

One canonical writer makes the static layer, whichever made the unit. A fingerprint is the hash of the canonical bytes of the fields marked for a layer: there is no third traversal.

### What a cache hit must satisfy

The brief asks whether units can stand on a firmer footing than tests. Here is what a hit claims,
stated once, with a small model that checks it.

**The terms.** A compile is `C(cfg, src, E) = (c, x)`: settings, a unit's text and the environment
before it give code and exports. Write `R` for the facts of `E` that this compile reads. An entry is
kept under a key of `cfg`, the unit's name and `src`, with its usages `U`. A usage says what was read
and what the key holds of it.

**The claim.** If every usage in `U` holds in an environment `E'`, then `C(cfg, src, E')` is the stored
`(c, x)`, up to a renaming of imports.

**The argument is one line.** A compile that is a function of its inputs, and that reads only `R` of
`E`, gives the same result on any `E'` that agrees with `E` on `R`. Everything hard is in the premises,
and the history of the cache is the history of those premises failing:

| | Obligation | Today's issues (`build-cache-issues.md`) | Checked by |
|---|---|---|---|
| O1 | **Hermetic:** `C` is a function of `cfg`, `src`, `E` | 9, 11, 13, 24 | S41, S43, `-j` |
| O2 | **Usages suffice:** `U` covers `R` | 1, 2, 3, 4 | scenarios; E18 (mask, read tracking) |
| O3 | **Fingerprints suffice:** equal fingerprints mean no read can tell them apart | 8, 16, 17, 18 | `soundness.sml` (relative only); E18 |
| O4 | **Identity:** canonical up to renaming, Merkle, independent of the session | 15, 21, 22, 23 | E16, E18 |
| O5 | **Load:** exporting what was loaded gives what later units observe | 11, 14 | E19 |
| O6 | **Remap:** a path map preserves what was used | 15 | E16, E18 |
| O7 | **Link:** interfaces that fit give a well-typed program, equal to the whole one | | S42, S80, S82 |
| O8 | **Elaboration:** units in sequence mean their concatenation, modulo named deviations | | E7, E8 |
| O9 | **Sessions:** a REPL reload keeps O1-O4 | 21, 22, 23 | scenarios |

**The obligation that matters most is O2 with O3 together: a key must cover exactly what the compile
reads.** It is a property of two pieces of code that nothing ties together: the compiler's reads, spread
through every pass and table, and the key, kept by hand (`fpVal`'s list). Today's tests are the only
link. This is why the hard bugs were never in the bytes.

**A model.** `results/L1/model.sml` is 157 lines of SML, not Rune's code: three units, each import in
three layers (static, ABI, implementation), six policies, and every edit between 54 projects, 2,916
pairs, checked for S41. It is exhaustive within those bounds and proves nothing beyond them. It shows
the claim is tight in both directions:

| Policy | What a compile reads | What the key holds | S41 broken | Units rebuilt | Constants inlined |
|---|---|---|---:|---:|---:|
| Binder identity (today's exact hit) | static, ABI | identity | 0 | 7,104 | 7,290 |
| Layers, inlining | static, ABI | static, ABI | 0 | 7,030 | 7,290 |
| Static only, inlining | static, ABI | static | 336 | 6,670 | 7,290 |
| ABI only, inlining | static, ABI | ABI | 126 | 6,892 | 7,290 |
| A usage dropped | static, ABI | static, ABI, less one name | 476 | 6,498 | 7,290 |
| Static only, a firewall | static | static | 0 | 6,670 | 5,832 |

(`results/L1/run.sh`, `output.txt`.)

Three things follow:
* **A key that reads less than the compile breaks silently**: the three holes rebuild less and give wrong
  code, and from the rebuild count alone they look like improvements.
* **A key is sound exactly when it covers the reads, whatever it holds.** Lines 1 and 2 are both sound, and
  line 6, with the smallest key, is too, because that compile reads less.
* **A firewall is not a key policy.** Line 3 and line 6 hold the same key. One is wrong and one is right, and
  the difference is what the compiler may read. Line 6's price is a fifth of the inlining. This is D18's
  choice in one row: a firewall must change what the compile reads (`Ty.convert`, `shapeOf`), not what the
  cache hashes.

Each of D1's layers is a claim that a consumer reads no more than that layer, and each claim can be checked
(E18's mask).

### The store and the warm path (D24, D25)

`<workspace>/.rune/` is the overlay. Under it, read-only, sit the frozen layers: one per config, built at install, shipped by dist. A key is a logical name, text and settings; `RUNE_CACHE` and `--cache-dir` move the overlay. A lookup reads heads, and the `units/` paths stay by identity (D24). Eviction is by age and size, and a failure of any kind is a miss.

An up-to-date build is a stat, a plan memo and an exit. A hit loads no basis. A miss loads the closure of what it names. A leaf's floor is code decode and link, and the link is memoised while its inputs hold.

### The editor (D26, D27, D28)

A file has one owning library. A check holds its units between edits, finds a changed input by name, elaborates it at its own position, and asks usages which of the units after it still hold. Closed units keep their bases and drop their syntax and typing, so what is resident is a small fraction of what is open.

Bases come from the store, written by the compiler or by analysis through one writer, read as the static layer. Positions and occurrences are in sidecars. A loose file gets an implicit library over its directory and a name-to-file index read from syntax (M19). Nothing is resident for the repo as a whole: a global index of analysis results is a later roadmap.

## Decisions

Twenty-nine decisions, each with its options, the evidence and a recommendation. The owner took every recommendation on 2026-11-02 but D22's, and added to D26. Each decision says so under its heading, and the table gives the choice. Where a decision reverses something earlier, or something the brief expects, it says so.

| | Decision | Decided (2026-11-02) | Rests on |
|---|---|---|---|
| D1 | What a unit's interface is | C: static, ABI and implementation layers, a hash per export | E13, E15, E17-E20, E23-E25, L1 |
| D2 | A unit's environment | B: the prefix in meaning, loaded by need; a library starts empty but for the Basis | E5, E6, E9, E15, E18, E24 |
| D3 | A unit's identity | C: logical names | E9, E10, E13, E16, E22, E23 |
| D4 | The workspace | B: one explicit root file | E1, E22, E25-E27 |
| D5 | The form of the build language | C: the plan is the contract; `.build` its normal form; the plan is Rune's | E12, the review |
| D6 | The one way | B: fewer constructs, written order, per language, the command line makes a plan | E1, E3, E5, E6, E9 |
| D7 | What importing a library means | B: declared, not transitive; available is not loaded | E1, E3, E6, E9, E13, E18, E28 |
| D8 | What a boundary is | B: a filter in a library's header, with its holes closed; kinds of export are the language's | E3, E28 |
| D9 | Namespaces | B: clash errors and renaming at import | E1, E25 |
| D10 | `src`, `lib`, nesting, reaching in | B: a library is a directory; warn, then refuse | E1, E3, E28 |
| D11 | Tests against abstraction | A: a friend list, for tests and drivers | E3, E27 |
| D12 | Basis views | A: seal sets after the libraries | E4 |
| D13 | MANIFEST's end | B: a derived entry in the store | E2, E18, E28 |
| D14 | Hosts' lists and the compiler's identity | A: a committed canonical plan; one identity per compiler | E12 |
| D15 | Migration | A: mechanical, no flag day | E3, E28 |
| D16 | Generated sources and preprocessors | B: declared steps before planning | E9, E12, E20, E28 |
| D17 | The restriction | B: three classes; a warning; it enables planning from syntax | E5-E8, E25 |
| D18 | Firewalls | A: none | E13, L1 |
| D19 | Aggregates | A: dropped | E11, E14, E15 |
| D20 | The footing | B: stated obligations, independent checks in `make check` | E7, E18, E25, L1 |
| D21 | Codecs | B: generated after D1, table reads by hand | E19 |
| D22 | Virtual libraries and functor signatures | **A: now,** the first client under `examples/virtual`; against the recommendation, B | E10 |
| D23 | Higher-order modules and applicative functors | A: not now | The review, E10 |
| D24 | One store | B: one layout, layers, keys by layer, a head the client defines, eviction | E13-E17, E24 |
| D25 | The warm path | A: in the order below; a hit may read a head | E13, E15, E21 |
| D26 | The editor's context model | B: one owner; a prompt only on real divergence; **and two language status items,** the owner's addition | E20, E22-E24, E27 |
| D27 | The editor's storage | B: keep, then store, then share | E15, E17, E20, E23, E24, E27 |
| D28 | The editor's caps and scale target | B: a stated target, as cost functions | E20, E21, E23, E24, E27 |
| D29 | Phase separation of a term layer | A: not built; if ever, a pure function to a plan | The review, E12 |

### D1. What a unit's interface is

**Decided: C** (2026-11-02), as recommended.

Five things in this roadmap ask for an answer to this one question: identity, firewalls, aggregates, the editor's share of the cache and generated codecs. Today a unit has one pickle, one identity and one fingerprint stream, in which types and back-end facts lie side by side (`lib/compiler/driver/unitbasis.sml:2090-2112`, `:507-521`).

- **A. As today.** The cheapest. It leaves the editor unable to share with the compiler: analysis does not compute the back-end facts, and an identity that holds them cannot match.
- **B. Split the entry for cost alone:** head, code, basis and Mid hashed apart, one interface as today. This is what E15 needs. It gives the editor nothing.
- **C. Layers.** **Recommended.**
  - **Static:** types, signatures, fixity, equality, constructor status. No spans, no docs, no imports' identities. A hash per export.
  - **ABI:** what a client's code is built on: layouts, value and exception anchors, known and primitive facts. A hash per export. Today it also holds the whole realisation, which `Ty.convert` and `shapeOf` read (`lib/compiler/core/ty.sml:369-371`, `:478-486`). A layout-only layer is sound only if those reads shrink with it; that has not been built or tested. So this recommendation means today's contents split per export, and shrinking them is M4's step 7, conditional, and held to H3's check.
  - **Implementation:** the code and Mid, and inline Mid. A consumer's key holds an inline body by `inl`, `inlv` as today.
  - **Self:** source hash, warnings, flags, level, schemes, source names. Never in a consumer's key.
  - **Sidecars:** positions, occurrences, facts, types, outside every consumer's hash (D27 gives their own key), relocated as file names are. A sidecar holds no line table that a client's code depends on until a link fills it in.

**The evidence.**
- *It can be shared.* After a seven-line fix the static layer hashes the same from analysis and from a batch compile on all three corpora: 245, 921 and 790 units, 57,218 exports, no difference (E17). The fix is `typed` copying a generated datatype's constructors (`lib/compiler/elab/elaborate.sml:2231`), as `instance` does (`:1204`). Equal hashes are not equal bytes, since analysis pickles are 2.9 times batch's on `rune.build`, so the layer needs **one canonical writer**.
- *Per export is worth it.* 2.0-2.4 times fewer clients rebuilt than one hash per layer per unit (E17), which is OCaml's form. GHC's per-declaration fingerprint and SML/NJ's hash per filter are the nearer models (*What the implementations do*).
- *The batch key must stay static plus ABI.* Static alone gives an internal error at link, a link refusal and different bytes under directed edits (E17). That is `results/L1`'s line 3 happening in the real compiler: a key is sound exactly when it covers what the compile reads (*What a cache hit must satisfy*).
- *The ABI layer has work to do.* 814 of the 3,659 needless rebuilds fired only on what is now the whole realisation, the value anchors or back-end facts, with the code unchanged (E13). They are at most what a smaller ABI layer could save. E13's bucket is not E17's layer, no key this small was built or held to `--no-cache`, and with today's contents a static-plus-ABI key saved 40 of 1,874 (E17).
- *It is not the first saving.* On `rune.build` the batch gain is remapping, not layers: 543 rebuilds shipped, 187 with remapping, 184 with per-export static plus ABI (E17). So fix `loadsUnits` first (D7).
- *An implementation layer earns nothing as a key today:* no rebuild in E13 came from it. It stays a section of the entry.

**To do with it:**
- hash-only fields leave the pickle, into a fingerprint layer, so that exporting what was loaded gives the same bytes (E19);
- imports' identities leave the hash (64 of 322 moved identities on `rune.build` moved with no export moving; deduced to be these and private tables, E17);
- positions leave hashed Mid only together with the line tables of copied functions, which today are in the client's code (`lib/compiler/backend/code.sml:155`, `lib/compiler/util/source.sml:179-180`). Until a link fills those in from sidecars, under a link key that holds them, an `inlv` usage must hold line starts, not fewer positions: that fixes E18's bug 1 and keeps the comment above a marked function a rebuild;
- MLton's ABI layer is 69% of its pickle, and one field, the stamps and flags of environment references, is 58.6% (E17): the first thing to shrink. Signature specifications copied into every unit are the next: they are why MLton's analysis pickles reach 2.7 GB (E20);
- the layout leak of E17: a client's diagnostic reads a layout (`elaborate.sml:1281`). Either a constructor's flat size goes in the static layer, or that error moves to the back end. The first is smaller.

### D2. A unit's environment

**Decided: B** (2026-11-02), as recommended.

`.build` says a unit sees what the steps before it leave. While a compile *loads* that whole prefix, a warm build, `-j`'s floor and opening one file at 100k units all stay O(prefix).

- **A. The prefix, loaded eagerly.** Today.
- **B. The prefix in meaning, loaded by need.** **Recommended.** Nothing in the language changes.
  - Each of `rune.build`'s 246 units compiled alone against deferred bases of all the others gave its entry's basis, code and Mid, loading a mean of 26 bases, at most 148. An MLton sample: 51 of 51, a mean of 108 of 791 (E15).
  - The deep mask, which cuts structures to the paths named, passes on the same units (E18).
  - The trap is real: a compile also reads other units' *text*, and a lazy reader must fault that in (`Source.fault` in E15's patch). That read is also bug 1 of E18.
  - **Batch only, so far.** In analysis a lazy world broke on the overload table and on a name of no unit, and gave false type errors on interface edits (E24; D27).
- **C. The closure as the language's semantics.** Each unit sees only what it names. Byte-identical on Rune (22 of 22) and on 28 of 30 sampled units of HOL4, with `Overlay.sml` as an added edge; the other two differed until a duplicate `Systeml` was removed (E5, by the report: that rerun's output was not kept). It needs S19 by scope and a closed `use`, and it licenses reordering. B takes its cost without changing the meaning of a single program. C is a Rune 2 question.

**A library starts from a basis empty but for the Basis, whichever is chosen.** `.build`'s `use` elaborates in the caller's basis, MLB's in an empty one, so `docs/build.md`'s "Its semantics is MLB's" is wrong there. `mlyacc-lib` used after `lib/mlton` saw MLton's `List` (E9), and a shadowing that still type-checks would be silent. A library is elaborated from the Basis and its declared imports alone.

### D3. A unit's identity

**Decided: C** (2026-11-02), as recommended.

A unit's name is its path as spelt, and it is in the key and the identity. 149 of 826 files have 2-5 spellings (E22); `./ty.sml` for `ty.sml` changes a `_dynamic` client's bytes (E10).

| Policy | `worker.build` spelt `../../` | `rune.build` spelt `./` | move `lib/unicode` | rename `parallel.sml` | Random edits, disagreeing with no cache |
|---|---:|---:|---:|---:|---:|
| A. Today | 16 | 105 | 24 | 2 | |
| B. Name-free | 1 | 0 | 0, **bytes differ** | 0, **bytes differ** | **39 of 104** |
| C. Logical | 1 | 0 | 0 | 2 | 0 of 150 |

Units compiled (E16).

- **B. Name-free** is what "content-addressed" first suggests, and **it is wrong**. Two identical files merge their generative state. Remapping takes the wrong unit silently (warm prints 2, no cache prints 1). It gains 2-57 units on a move, of 248.
- **C. Logical names.** **Recommended.** `LIBRARY:PATH`, within the workspace (D4), with room for a version (`LIBRARY@1.2:PATH`), since a package manager is to build on this; and a rank for a file given twice, so that issue 22 closes in batch (E16's `same-file-twice`). Anchors need no change, and remapping none for logical names alone (E16). Names rather than numbers in imports are a further step, not run in E16: they change `Link.key`, `remapKeys` and `.rbu`, and remove most of the difference between E13's C1 and C2. That step is not in M3. It waits in *Later*, to be decided with rhc in view.

### D4. The workspace

**Decided: B** (2026-11-02), as recommended.

`libraries NAME` resolves under one `--lib` root or by path. A monorepo of 1000 builds needs something logical names can stand on, a place for the store and roots for the editor.

- **A. Nearest build file** (holbuild). Each library is its own world; there is no shared store.
- **B. One explicit root file.** **Recommended.** Found upward from a file. It names the library roots, which may be several, and the named targets `{name, build, options}`, much of the record `src/lsp/workspace.sml:9` has already. No ambient paths. Dune's topmost `dune-project` is the nearest model, but M3 takes the nearest root file, not the topmost, so that a worktree or a fixture inside another root has its own.
- **C. Environment variables.** Machine state in what must be reproducible.

### D5. The form of the build language

**Decided: C** (2026-11-02), as recommended, with a clause for a second language below.

The review of the ideation is *The ideation, reviewed*, and it decides this. In short: planning that needs the elaborator cannot serve the LSP, `--build-list` or the hosts, who need a plan without running anything.

- **A. Declarative `.build` only.** Nothing computes.
- **B. SML only.** Every reader then runs a program: 116 times a `.build` read, with a floor of 32 (E12).
- **C. A typed plan as the contract, `.build` its normal form.** **Recommended.** `CompilerProject.plan` is already nearly this (`lib/compiler/driver/project.sml:5-12`).
  - A canonical, line-oriented text, with `body` and `provenance` apart. It round-trips on all 90 builds, 8.3 KB for `rune.build`, 125 KB for MLton (E12).
  - Its value is reading without Rune, without a parser, across forms. It is not speed: a stored read costs about what planning costs.
  - The generator route is documented: any SML program can print a `.build`, as `runeffi` does, with a `diff` check.

The schema needs `requires` on the plan, `inline` and `inlineValues` on a library, `inputs` outside the compared body, and `replay` or its replacement; `caches` goes (E12).

**The plan is Rune's.** Nothing in the store reads it, and rhc scans imports (rhc's D46). The schema leaves room for discovered edges and SCC groups and builds neither: Rune 2's plan, computed from a scan of headers, wants the same room.

### D6. The one way

**Decided: B** (2026-11-02), as recommended, with a clause for a second language below.

Brief, line 6: "the build language should have one way of doing things".

- **A. Leave it.**
- **B. Fewer constructs.** **Recommended.**
  - **Keep:** paths in written order, one construct for bare paths and `files`; `implements`; `annotate`; `use` within a library; `inline`; `libraries` in a program's build, which a library's header calls `requires`.
  - **Drop:** `group`, `local`, `cache` (no uses in the 88 tracked files, E1; `local` and `group` are exercised by `tests/runner/scenarios.sml:84-98`, and E9's MLton build has 3 `local`), and the program-level `library` block (one use besides `lib/compiler` in the tree, a fixture; 29 in E9's MLton build, whose translator must move to headers or nested libraries). Its `type` export leaks constructors (E3).
  - **Move:** a library's boundary into a header of `library.build` (D8).
  - **Written order stays the semantics,** as in MLB and SMLSC, since effect order is not derivable (E6). Dependency order is derived for `-j`, never trusted for meaning.
  - **The command line** (`--library`, `--basis`, `-I`, file lists) is a second build language. It synthesises a plan, so there is one.
  - **Unknown words are errors,** including annotations: `annotate "demnad"` means demand today. An export naming nothing is one too. M1 first held a program-level `library` block's export to naming something in scope, which let E9's MLton build export the Basis's `CharArray`, while `--basis-index` asked that a source declare it. M9 settled one rule, the index's: an export names what a source of the library declares, so a header may not re-export a Basis name, nor one from a library it requires. A source passes one on by declaring it, `structure List = List`.
- **C. Dependency order everywhere.** The owner's "one way" read strongly. `group` has no users in the 88 tracked files, and a wrong parse of a file gives a wrong graph (`Deps` parses with `Fixity.initial`, E5). No.

**Written order is per language.** Its reason above is SML's: effects whose order cannot be derived. A Haskell module's place comes from its imports, and the Report's own libraries hold an 11-module cycle, which `Deps` refuses (`lib/compiler/driver/deps.sml:270`). rhc scans imports and uses neither `Deps` nor `group`, so nothing here changes for it.

### D7. What importing a library means

**Decided: B** (2026-11-02), as recommended.

- **A. Global and flat, as today.** `libraries` is transitive and not positional. 12 edges are used but only reached transitively (E1).
- **B. Declared, not transitive, and available is not loaded.** **Recommended.**
  - **Declared:** the migration is 7 additions, 1 removal and 7 program edges (E28), of which 4 additions and 4 program edges are the win32 work's and wait (D15). Nothing in the repo uses a name outside its declared closure (E1).
  - **Available is not loaded:** `libraries` says what may be named; the closure of what is named is what links. Every small program depends on this: hello is 2 files by mention, 278 with `--basis all`, 295M to 3,551M instructions (E3).
  - **Selection reads Deps' uses, not tokens.** Today alpha-renaming a bound variable changes a program's output, `fn F => F + 1` against `fn E => E + 1`, and an unused record label takes a compile from 2 files to 68 (E3; the lead reproduced it). Selecting from uses is about 15 lines, closes that, and regressed nothing on 146 programs and 623 language files, none of them HOL4 or MLton, so M1 keeps tokens for a file `Fixity.initial` cannot parse. This belongs in the first milestone.
  - **Initialisers** run once, in dependency order. A unit with a top-level effect in a library comes with the library's selection only through its names, as today. Only the Basis has file-level values or exceptions (E1); initialisers inside a structure's body are common (`CompilerState`'s roots in `lib/compiler`) and come with a unit's selection the same way.
  - **`loadsUnits` asks whether a program loads units,** not whether `lib/basis/runtime.sml` or `dynamic.sml` is among its files (`src/driver/main.sml:590-593`). A program that names `Runtime`, or declares its own, loses every remap hit. That is 54% of all rebuilds in E13's replay, with the refusal off: MLton `sig-list` 202 to 9 units, HOL4 `datatype-net` 515 to 104, the compiler's lint chain 543 to 187.
- **C. Whole libraries always.** The brief's "imports as a whole" read strictly. On the Basis, the one large case with `lib/compiler`, loading all of it makes hello 12 times slower to compile and start-up 20 times longer in a whole build, and 2.8 MB in `--units`. A library loaded whole was not measured. "As a whole" is right for *names and meaning*, wrong for *what links*.

### D8. What a boundary is

**Decided: B** (2026-11-02), as recommended, with a clause for a second language below.

- **A. A filter, as today, by a sixth column of MANIFEST.** Its cost: test/property/basis's table goes from 12.8 KB to 124.8 KB, and the repeated column is the only cost boundaries have (E3).
- **B. A filter in a library's header, with its holes closed.** **Recommended.** Export lists on 31 libraries changed no byte in 159 programs (E3): the boundary is a pure filter, and it is sound as one.
  - **A library hides names, not representation.** A boundary decides what a client can name; representation stays behind a structure's own `:>`.
  - **No closure check.** A private type behind an exported signature is usable, not nameable, and sound (E3). CM and MLB have no check either, and `local datatype t = A in val x = A end` has no source signature at all. A lint at most.
  - **One rule, moved from runedoc into the compiler:** a public structure's ascribed signature is public (the **claim** rule). runedoc refuses 21 of 22 wrapped libraries today for lacking it. It needs a new fact in the index: which name ascribes to which signature. It lands with M13's boundaries, or it refuses nothing (E28).
  - **Close the bypass.** A second `use` replays the raw delta (`src/driver/main.sml:939-946`), so a boundary is gone after it; `library (...) = use x.build end  use x.build` gives private names, also across build files (E3). A build with a boundary of its own replays as that boundary shows it, at every `use`; one with none replays through the boundaries closed around its first use. M1 found the first half: replaying everything through the first boundary, which this line first said, breaks a diamond. Two libraries sharing a bounded build then see its names or not by which comes first, and E9's MLton build fails with `unbound signature: WRAPPED`. An unbounded build shared by two libraries still depends on order, and is refused, not miscompiled, until it gains a boundary. A *first* `use` of a sub-build beneath another library is the same bypass, and it is how the compiler builds: that closes with friends (D11) and migration (D15), not sooner.
  - **Fixity crosses a boundary,** activated on import (SMLSC). Today it cannot, so a library cannot export an infix.
  - **Named subsets:** a library may declare a view, a named subset of its exports, whose files are the `requires` closure of those exports. No new loading primitive (E3). D10's three partial lists use these.
  - **A hash per filter,** as SML/NJ's: what a client's key holds is what would have been pickled for the smaller environment. M8 found it already holds without one: a usage is per name, with the fingerprint of what the filter lets through, which is finer than SML/NJ's pid per filter. An edit behind the boundary compiles no client, even in the unit it names; an export it does not name compiles none; removing what it names refuses it; random edits found no disagreement. A separate hash would make a client depend on more. What remains is a program that keeps its units' identities, whose code names units: that is M4's hash per export.
- **C. Signatures on every export,** the strict reading of "the abstraction and encapsulation that a structures/signature has". It adds nothing a structure's own ascription does not: 90 signatures had to be exported, and the claim rule gets that, without a second place to write them.

The Basis is not a library in this sense: `library (...)` has no values, fixity or datatypes, and whole builds ignore a boundary on it (E3). It stays what it is, with a prelude's status (D17).

**Kinds of export are the language's.** `structure`, `signature`, `functor` and `type` are SML's (`lib/compiler/driver/buildfile.sml:115-116`). If a `.build` ever names a Haskell library, `module M` is that language's kind, and a boundary, a view or a hash per filter cannot hide an instance: "Instance declarations cannot be explicitly named on import or export lists" (Haskell 98 Report, 5.4, as the rhc roadmap quotes it). rhc stays out of `.build`, so nothing is built for this.

### D9. Namespaces

**Decided: B** (2026-11-02), as recommended.

Only three names really clash, of 15 public in two or more libraries; the rest are generated alternatives never loaded together (E1). `History`/`HISTORY` is the serious one: once test/runner is in a closure, no order reaches terminal's. `RuneCompiler` clashes with the Basis's. `COMPILER` does not clash at all.

- **A. Prefix convention.** Today, and "not a wall".
- **B. Clash errors at import, renaming at import, identity qualified by library.** **Recommended.** Two libraries may keep a same-named private structure, since identity carries the library (D3). A clash is an error only where one scope imports both. Modules can be renamed; a value loses constructor status (Blume). Two renames settle today's repo. One settles `History`. The second settles `RuneCompiler`: a library may shadow a Basis name only by a declared rename at import, and the REPL's and the compiler's use keep working.
- **C. Wrapping, as dune does.** It cannot be copied: structures hold neither signatures nor functors (SMLSC, Elsman). This is what bounds D9, and why a language change belongs to Rune 2.

### D10. `src`, `lib`, nesting and reaching in

**Decided: B** (2026-11-02), as recommended.

- **A. Conventions only.**
- **B. A library is a directory.** **Recommended.**
  - A directory with a `library.build` is one library. The deepest wins, and a parent never owns a nested one, so `lib/test/property/basis` stands and `lib/test` keeps its grouping. Nesting is a name, as today.
  - `lib` holds libraries, reached through their interface; `src` holds programs. Private by default is a declared property of a library, and the path supplies only the default (Bazel's advice).
  - Reaching in is a warning first (M1): 12 hand-written builds, of which 4 are tests, 5 are drivers and tools on `lib/compiler`'s internals (`rune`, `runedoc`, `tools/compiler/state-audit`, `tools/lsp/bench`, `tools/lsp/syntax-bench`) and 3 have partial lists (`runeffi`, `runeisa`, `runeopt`). Friends answer the first two groups (D11), named views the third (D8). M13 moves them, and it becomes an error afterwards (M14) for a library with a header. D15's window holds the rest. A `.sml` under a `library.build` may be named by that library and its friends.
  - runedoc reads exports, not `Rune*` prefixes, so a library's header says which docs to generate: the help the brief's line 9 hoped for. On migrated libraries it gives 0 claim errors over 27 (E28).
- **C. Enforce by path alone,** Go's `internal/`. One sentence of rule, but it cannot express a test elsewhere.

### D11. Tests against abstraction

**Decided: A** (2026-11-02), as recommended.

No test defeats an ascription: tests need **names, not representation** (E3). Of 68 names exported only for tests, 59 are the test libraries' own API.

- **A. A friend list in `library.build`.** **Recommended.** It names the builds that see the unfiltered view: `InternalsVisibleTo`, in the library's own hands. That is the 4 tests and D10's 5 drivers: a compiler's driver is what `lib/compiler/library.build:1` already says uses internals, and the library naming its friends is the honest form of that; a public `internal` view would open to anyone what a friend list names. One keyword, 35 lines. It compiles 1 unit against 97, at 36% of the instructions, because it reuses the frozen layer, and it costs the cache key nothing (E3). A non-friend is refused. A friend still cannot see through `:>`: where that matters, the convention is `structure FooImpl` with `structure Foo :> FOO = FooImpl` (Haskell's `.Internal`).
- **B. Inline tests compiled into a second build of the library** (Rust, D, dune). It recreates the two-contexts problem D26 ends. In SML a test is another unit that names a structure.
- **C. Keep reaching in.** A back door open to anyone, and 2.8 times the cost.

### D12. Basis views

**Decided: A** (2026-11-02), as recommended.

The brief's `BASIS_2024` does not exist: SML/NJ has `basis-2004.cm` with `LIST_2004`, MLton `basis-1997.mlb` and `basis-2002.mlb`. Both are the same code under other signatures, as Rune's seals are, with the newest as the default.

- **A. Seal sets, loaded after the libraries.** **Recommended.** On a test view of 4 structures, four units, 12.5 KB, no new config: the usage check on the binder catches the difference, and S41, S42 and `--verify-cache` hold (E4). Before the libraries, `lib/compiler` itself fails.
  - A view is a client-side filter of names, **not a capability**: a library re-exporting `structure L = List` reaches a hidden member.
  - A library's own view of the Basis needs no compiler change: a private seal file inside a boundary. D8's views are another thing, a named subset of a library's exports.
  - Wired-in names stay outside views (Backpack's `base` lesson).
  - A functor of a library that wants `LIST`, in a client on a narrower view, is refused. That is the signature system working.
- **B. A view as a library.** Library units come after seals, and `library (...)` has no values or fixity. It cannot be.
- **C. A config per view.** A second frozen layer for nothing.

### D13. MANIFEST's end

**Decided: B** (2026-11-02), as recommended.

Brief: "the .build files should be all we need". Every column but `provides` and `requires` is a projection of `library.build`. It exists because `select` must map a name to a file it has not loaded (E2).

- **A. Recompute the index on every compile.** 622.93M instructions against 6.44M, 97 times a read; a compile doing it would cost 3.1 times hello's (E2). No.
- **B. A derived entry in the store, never a file in the tree.** **Recommended.** Per-file `provides` and `uses` are facts keyed by content (CM's skeletons), `requires` stays computed per library set, and an index is a store entry keyed by `library.build` and what it names. The frozen layer ships it. There is no `make manifests`, and it cannot be stale: deduced. `--no-cache` turns off units, not the index: the index is read from the frozen layer, or held per library set, under it too. It was not prototyped, and its key needs every library file's hash per compile, at a cost not measured, against *Measuring*'s line for hello.
- **C. Keep a generated MANIFEST, validated.** This answers staleness, which is real: 6 of 15 stale scenarios are silent wrong answers, and 4 of those pass `--basis-check`, which never reads `library.build` (E2). It leaves the generated file the brief objects to.

**The order matters** (Appendix E). `scripts/install.sh` with no MANIFEST exits 0 having installed 89 of 822 files and no Basis, and prints "installed" (E28, by running it). A one-line guard goes first. Then install, dist and vscode key on `library.build` and ship it; install needs no list at all. Then the index moves to one module both the driver and runedoc reach, then its readers, then the fixtures: 21 plus 7 test programs that write a MANIFEST inline.

### D14. How hosts get their lists, and what the compiler's identity hashes

**Decided: A** (2026-11-02), as recommended, with a clause for a second language below.

**This must be settled before `rune.build` moves.** `scripts/gen-version.sh:51` hashes the awk's list into `Config.identity`. Through `libraries`, the awk loses 19 files, an edit of `lib/unicode` leaves the identity unchanged, and **compiler B, with a real edit, takes compiler A's cache entry and prints 233 where the same compiler cold prints 234** (E12, the lead read the raw output). A host fails loudly with 69 errors, and the obvious repair, `--library unicode --library json`, compiles: that is how the hole goes silent.

- **A. A committed canonical plan for the five host-built roots.** **Recommended.** 8.6 KB per root; `identity.sh` is 4 lines; a host checks `input` hashes with `sha256sum`, and `gen-version.sh:53-55`'s fallbacks to `shasum` and `cksum` stay, though E12's `identity.sh` dropped them; no host was run (E12); `print | cmp` in `make check` catches a hand edit. It cannot silently lose a library, and it knows no grammar. The cost: a regenerated file on 3% of commits, and hash lines that can conflict on 10 of E12's 33 live branches.
- **B. Grow the awk.** 15 lines. It must refuse any unknown word and be tested for equality on the real roots. One more reader to keep level with every construct, and a construct it skips is the same silent bug. The fallback, if generated text in git is unwelcome.
- **C. An SML reader on each host.** It would run on every make through `gen-version`, against `bootstrap.md`'s aim. Rejected, as is the bytecode image for the from-source path (`bootstrap.md:23-26`).

Either way the identity hashes the **closure**, excluding the two generated files that hold the identity, `build/config.sml` and `lib/compiler/config.sml`. E12's prototype did not meet the second, since it kept `use lib/compiler/internal.build`. `Config.identity` has never covered the main file, `build/config.sml` or, by reading, `lib/basis`. `bootstrap.md`'s runemake should adopt the same plan when it comes.

**One identity per compiler.** The hole is the same for a compiler that is not host-built, as rhc will be (its D42). On its toy, a tool edited with `Config.identity` the same printed `MINE` warm where cold prints 7, and the hash of the tool's own sources as a setting closed it. So a second compiler has its own identity, over its own closure, and that setting is rhc's stopgap until M11. rhc asked for this per root, which is too fine: `rune`, `runelsp`, `runedoc` and the REPL all link one `build/config.sml`, and `runelsp` must keep `rune`'s identity for analysis to load batch's entries (D27).

### D15. Migration

**Decided: A** (2026-11-02), as recommended, with the win32 work left out below.

`win32-desktop` alone changes 24 build files, among 34 refs ahead of master.

- **A. Mechanical, no flag day.** **Recommended.** The migrator reads facts from the compiler's own `BuildFile`, `Deps` and parser; it is idempotent, and 159 of 159 programs stay byte-equal (E28). On master: 33 changed, 28 nothing to do, 15 rehashed, and 12 need judgement (the reach-ins, of which `--after-d14` resolves whole-library lists in 8, while 9 sub-build uses need friends and 6 partial lists need views).
  - **Generated sets are rehashed, not regenerated.** The set hash covers `.build` text. `rehash.py` takes 0.08 s, against 269.5G instructions and a pinned Windows SDK, and gives identical bytes on all 5. On the branch, a rehash was not compared with a real regeneration.
  - **A branch's recipe:** rebase, take the branch's text on any `.build` conflict, run the migrator and rehash. On `win32-desktop` that equals direct migration on every one of 105 build files. 19 of 34 refs gain conflicts, all of them, in the files inspected, in `.build` files.
  - **The trap:** master's new boundary merges cleanly into a branch and hides what the branch added. `--basis-index` passes, and a client fails later. So the index warns, and the migrator recomputes a boundary it wrote.
  - **Enforcement rules are the only thing that needs a window.**
- **B. A flag day.** No reason to pay for it.
- **C. Versioned `.build` files** (`(lang dune x)`, `cabal-version`). Unnecessary for this migration, since the target is today's grammar, less what is dropped. A version line costs little and may earn its place for a package manager; it can wait for one.

**The win32 work is left out** (the owner, 2026-11-02: "another agent is still woring on win32-desktop so we cannot touch it as part of this roadmap (has to be done later)"). The win32 work means `win32-desktop` and its 18 working branches. No milestone rebases, edits or merges one of them, or migrates a `.build` file that one changes.
- **What stays as it is:** 27 of E28's 88 files.
  - 8 boundaries: `ffi/model`, `ffi/win32/common`, `ffi/win32/mock`, `ffi/win32/model`, `ffi/win32/native`, `ffi/win32/sdldriver`, `sdl` and `unicode`. Their 4 declared additions go with them.
  - 4 program edges: `ffi/win32/{mock,native,sdl}.build` and `tests/ffi/win32/native/contract.build`.
  - All 15 generated files, so no set is rehashed.
  - A win32 branch changes 12 of these today: all of those `library.build` files but `ffi/win32/mock`'s, and the 5 generated `current.build`. `win32-desktop` itself changes 7. M13 recomputes the set when it starts, since that work goes on.
- **What a branch pays for this:** nothing. On a master that leaves these alone, `win32-desktop`'s rebase is E28's control, 2 conflicts and no `.build`, where a migrated master adds up to 6. And the trap above cannot spring, since these libraries gain no boundary.
- **A library with no header keeps today's meaning:** everything public, `libraries` transitive, with a warning. Every enforcement rule needs a header, so this is the window: no list and no flag, and a file shows by its own form whether it has migrated.
- **What waits:** `runeffi`'s 2 of 17 files of `lib/unicode` stay a reach-in with a warning, since a view needs a header.
- **The window closes** with that migration, in *Later*, by the recipe above. Then the old form is refused.

### D16. Generated sources and per-file preprocessors

**Decided: B** (2026-11-02), as recommended.

The brief does not mention these. What "as would be build via the build system" can mean for HOL4 depends on them. HOL4's graph is **static as far as `Holdep` goes** (E9): `Holdep.sml:45-58` maps `fooTheory` to `fooScript.sml` by name, and the parser finds no `load` or `use` in 1,252 scripts. Recipes stay in 86 of 108 Holmakefiles in `src`, 5 scripts touch files or processes, and 31 are unresolved by a regex. So nothing here needs a monadic build.

- **A. Left outside,** as Holmake does today. `.build` compiles what exists.
- **B. Declared steps, in a stage before planning.** **Recommended.** A step names its tool, inputs and outputs, all hashed; outputs are verified, and later units read them (holbuild's `[[generate]]`, Bazel's declared outputs).
  - `build/config.sml` is the first honest case, and the proposed plan's `SGenerate` holds it. M15 found it cannot be keyed: `gen-version.sh` reads git and every file of the closure, so its step declares no inputs and runs on every build.
  - A **per-file preprocessor** is a declared class: HOL4's `QUse` filter changes 36 of 745 closure files (E20), and with it the closure compiles (E9).
  - Generated sets stay outside the plan, as explicit commands, with `.build` text inside their hash (E28). `runeffi` gains a rehash mode, and its driver accepts or removes an old set.
  - **A run step** (a theory script as an entry unit over its ancestors, its outputs read by later units) is what a true HOL4 build needs beyond this. It is a small addition to a declared step, and it can wait for someone who wants HOL4 built this way: Holmake works.
- **C. Dynamic dependencies.** Must earn their place, and nothing here earns it. A static graph keeps planning without running.

### D17. The restriction

**Decided: B** (2026-11-02), as recommended.

The brief wants "the separately compilable restriction". The literature changes what it is for. Blume's restrictions serve **inferring dependencies**, not separate compilation as such (SMLSC says so), and Appel & MacQueen's units are "any sequence of ML declarations". With written order, a unit that fails a rule costs **speed, never correctness** (*What the literature says*). The 1990 Definition had such a subset, §3.6 *Closure Restrictions*, and the 1997 revision removed it: a source comment says "implementors never exploited them" (*What the Definition says*).

**Who fits, by the parser, per class** (E8, Appendix B): Rune's compiler 84 of 84 shared units, its libraries 318 of 318, MLton 599 of 599, HOL4's closure 741 of 743, the Basis 257 of 259. The hypothesis of two classes needed a third: in the closures, the units that don't fit are all the same thing:

- **Shared:** others depend on it. Restricted.
- **Entry:** nothing depends on it. All of SML '97. HOL4's scripts are these: nothing links to one, only to what it generates.
- **Prelude:** it defines the language for what follows: HOL4's `Overlay.sml`, the Basis's `always` files, HaMLet's `Syntax.sml`. A declared status, in the build.

**The rules** (Appendix A; a rule with no mechanism that needs it is dropped):

| Rule, for shared units | Needed by | Verdict |
|---|---|---|
| No top-level `val`, `fun`, `exception`, `datatype`, replication | dependency order, closures, the editor | Keep |
| No top-level `open` | dependency order, closures, the editor; cut-off's precision | Keep |
| No top-level fixity | **the parse itself** | Keep, or fixity is an export or a prelude's |
| One module name, per scope | dependency order, closures | Keep, per scope not per group |
| No `use` | nothing: batch has none | Drop |
| Nothing private in a `local` head | nothing | Drop from `Deps`' discipline |
| No bare `val _ =` at top | nothing | Drop |
| A signature on each shared structure | firewalls only | Drop, with D18 |

**Options:**
- **A. An error.** The strict reading. A correct SML '97 program failing under `--build` must never be a surprise, and nothing needs it: warm cut-off holds without any rule (E5).
- **B. A warning, with a per-library `strict`.** **Recommended.** A failing unit falls back to the linear prefix, at a cost in speed alone. Its name is **well-formed**, CM's word. No experiment measures what it buys. What it enables is planning from syntax, which M19's index uses. The elaboration tier needs nothing here: in default modes nothing crosses a unit's end (M16 found this false for a flexible record whose type two selectors merged, and fixed it), `--flex-records=program` and `--free-tyvars=later` already refuse in `--units`, and those modes stay outside builds. `Deps` must know a prelude's fixity before its graph is trusted: `rune --deps` stops on HOL4 at `Conv.sml:205`, and 142 of the closure's units parse differently without it (E8).
- **C. No restriction.** It loses what well-formed units buy: top-level names readable from syntax, which is what the editor's cheap planning and D2's C rest on.

**The REPL keeps the Definition.** Through `use`, 325 of 330 `tests/lang` programs behave the same. Of the five, three are backtraces, one is `basis.compiler` by design, and one is `--free-tyvars=later` at the REPL's end of input, documented. A corpus sample of 616 finds one internal error, which is a bug (E7). The REPL lacks `--flex-records` and `--or-patterns`.

**Effects.** No cheap static proxy exists (E6): the two tried flag up to 34-37% of shared units on two corpora and 9-17% on two, and Rune's flagged units never mattered. Unit bytes did not depend on legal order, on the 2-3 orders tried, once names are unique. HOL4 is the only hidden effect dependence found, two lines of `Theory.ancestry` and `srw_ss` order. So written order stays (D6), and a unit that relies on another's effect names it, as HOL4 already does with `local open boolpp in end`.

### D18. Firewalls

**Decided: A** (2026-11-02), as recommended.

Does an opaque library boundary stop recompilation? The brief's rune 2 goal, and incremental's D2 reopened.

- **A. No firewall.** **Recommended.** Mid stays see-through.
  - Over 85 replayed edits (75 distinct: 10 commits are on both chains, and count twice in these totals), 4,048 units were rebuilt and 389 really changed. **Only 31 units (0.8%) are ones only a firewall could avoid, and 0 of them came from the compiler's real commits;** MLton and HOL4 had seeded edits alone, 26 chosen by an agent, so the real commits are one project's (E13). No firewall was prototyped.
  - Body and helper edits already rebuild only the edited unit: the cache *is* a firewall for them.
  - The price is at least 2.4 times the run instructions on `checksum`, the worst of six, 3.07 against 1.27 of whole; `wc-input1` 1.95 against 1.35. Inlining is nearly all of it, known calls adding 0.1-1.5%; layouts behind an opaque type are unmeasured.
  - No system read has a firewall with known calls and unboxed layout across it at once.
- **B. A build profile,** as dune's `-opaque` in dev. Sound if it changes what the compile reads, as `results/L1`'s line 6 shows. No evidence asks for one.
- **C. Abstract Mid resolved at concatenation,** which gives up S42 or needs a budget gate. Rune 2's question.

What firewalls were wanted for, the rest gives: fix `loadsUnits`, then D3, then, if it passes H3's check, a smaller ABI layer.

### D19. Aggregates

**Decided: A** (2026-11-02), as recommended.

The brief's "hierachical unit compilation", a library compiled to one open unit, "expected to be faster". **It is not, and the recommendation is to drop it.** R separated two things, and E11 measured both, on today's tree and on E15's.

| Warm client, G instructions | Members | One unit | Pack |
|---|---:|---:|---:|
| `runelsp` no-op, today | 12.83 | 13.06 | 11.62 |
| `runelsp` no-op, E15 | 0.20 | 0.19 | 0.20 |
| `runelsp` leaf, E15 | 8.84 | 10.67 | 9.53 |

A one-file edit of `lib/compiler`: 10.42G against 29.93G, 2.9 times worse today; 10.15G against 32.22G, 3.2 times, on E15's tree; 1.4 times on `lib/unicode`. A one-name client of `lib/unicode` gets 2.65 times the bytes and 1.72 times the start-up. Link and code decode, E15's floor, grow.

- **A. Dropped.** **Recommended.** At run time an optimising aggregate gains 3-4%. On `compiler-client` `--whole` gains 11.7%, three times as much, for 1.27 times the compile, and `--units --whole` from cache already reuses the front end: MLton's is 129.1G against a 356.4G whole compile, with bytes equal (E14). Release speed has an answer.
- **B. A packaging aggregate for dist,** CM's stable libraries. It may stay as a format if a client ever asks. It saves at most 9.4% warm today; after E15 it moves a leaf between -7% and +8%.
- **C. Build it behind Gate G1.** Gate G1 is the owner's. E11 says no.

If a form is ever built, Mid is held at ToMid or after expand, never after simplify, `workers` runs once, and the capture level is part of the config (E14).

### D20. The footing

**Decided: B** (2026-11-02), as recommended.

*What a cache hit must satisfy* states the claim and its nine obligations.

- **A. More tests of the same kind.**
- **B. Stated obligations, each with an independent check in `make check`.** **Recommended.** Real holes appeared as soon as anyone looked: warm differs from cold (bug 1), three settings are in no key, so `--type-work=1` exits 0 warm and 1 cold (bug 2). 13 of 37 mutants survive every check (E18).
  - **The flags oracle:** every setting in a key, or declared not to be. It closes the class, not the instance.
  - **Fact edits, per-unit lazy verification and the deep mask.** The mask is the only check that catches some dropped usages, and it runs in seconds per unit under lazy load.
  - **Root blanking** driven from the 339 `CompilerState` roots, not a second hand-kept list.
  - **Across-verification,** which closes issue 15 once M4's step 2 exports what was loaded: 130 of 216 compared, all the same; 86 raised `Missing` (E18).
  - **The fingerprint oracle** once one writer exists (D21): `soundness.sml` alone caught 1 of 9 fingerprint mutants.
  - `results/L1`'s model moves to `tests/`, named from `docs/units.md`, as the statement of what the checks are for.
- **C. A mechanised proof.** The statement is short and the argument one line; what is hard is the premises, which live in the compiler. Elsman's properties and Cardelli's theorems say what to prove if `formal-verification.md` ever takes this up. Not now.

### D21. Codecs

**Decided: B** (2026-11-02), as recommended.

- **A. Hand-written, as today:** about 4,600 lines, four traversals. Writer, reader and fingerprint have diverged (issues 8, 16-18).
- **B. Generated after D1, from one description with field marks.** **Recommended.** The fingerprint is the hash of canonical bytes of the fields marked for a layer, so it is no longer a traversal of its own: every system read does this (SML/NJ's `pickle2hash`, MLKit's `pu`, GHC). A spike on one type: 7 description lines and 66 of generator against 64 by hand, same bytes on 31 entries, -0.002% (E19). 15 lines stay by hand, the table reads: `fpVal`'s weak spot needs tables declared too. `ty` and references are not field lists, so the full generator is real work. The output is committed, or host-buildable (S43).
- **C. Now, before D1.** It would be done twice.

The cache needs no schema hash: `Config.identity` is in its config, so UnitCache, UnitBasis and UnitFile's versions decide nothing there. They matter for `.rbu`, `.rbi`, `.rbm`, `.rbs`, bytecode and images, and they become the last defence if a source escapes D14.

### D22. Virtual libraries and functor signatures

**Decided: A** (2026-11-02), against the recommendation: "we do now not later - the first client is an example program under examples/virtual".

*The section added to the brief.* Compiling a client against a functor's signature alone.

- **A. Now,** while the machinery is fresh, as the section argues.
- **B. Later, when a client appears.** **Recommended.** The incremental benefit is there already: a body edit recompiles no client (E10). What it adds is compiling before a body exists, choosing an implementation per build, and functors as plugins, and nothing in this roadmap needs those. It is small when wanted: `functor F = _virtual (X : A) : B` matches `_virtual`, needs no new keyword, and costs about what M9's structure half did (+1,033 lines). An ABI fingerprint must add record shape and slot order, which specifications carry a descriptor, a version tag and the calling convention. `Pickle.hash` agrees on Rune and four hosts; smlnj32 differs, so a fingerprint on it is not stable across the five (E10). The fingerprint's text was not run on hosts. MLKit's 2005 bug is the trap: a body hash belongs in the layer that exposes it.

**What A means.** Neither half was prototyped: E10 is on paper, with two probes, and the sizes come from the structure half.
- **Functor signatures (M21).** `functor F = _virtual (X : A) : B` is bound at link: the build's `implements F = ... end` names files that end with `_export functor F (X : A) : B = ...`, as for a structure. `functor F = _dynamic "path" (X : A) : B` is bound at load, the plugin. A mismatch is an error at link or load. There is no new keyword, and the extension gets its `sml97-extensions.md` entry and `docs/language.md` rows.
- **A client's code.** An application is a call over functors-units' nested records, with no expansion, so nothing of the body reaches a client. That is a firewall at a seam the program chose. D18's answer for libraries stands.
- **The ABI fingerprint** lives in M4's ABI layer. It holds the parameter's and result's signatures, record shape and slot order, the descriptors a caller works out for its argument's datatypes, a version tag and the calling convention (E10). The brief wants it stable on the five hosts, and `Pickle.hash` differs on `smlnj32` today, so M21 must fix that or compute it another way. M21 found two SML/NJ bugs behind it and made the five agree; the fingerprint is computed in the ABI layer's terms and carried in the units' code, not stored in a basis.
- **The first client** is an example program, `examples/virtual/table`, beside `bigint`, the structures' example. A table functor, `functor Table = _virtual (K : KEY) : TABLE where type key = K.t`, on an association list and on a balanced tree, one build each, applied to two kinds of key. The client compiles against the signature alone, the second build through the first one's cache compiles the implementation alone, and a `_dynamic` variant takes an implementation as a plugin. It tests what `bigint` cannot: two applications give two generative types, and a result type is tied to the parameter.
- **Virtual libraries (M22).** One library declares a virtual module and another implements it, in their headers, with one implementation per program and no new public modules, as dune's. `ffi/win32`'s `native`, `sdl` and `mock` are the real case: one virtual `Win32`, three implementations, `use`d as sub-builds today. They move with the win32 work's migration, in *Later*, not in M22.

`where type` between virtual modules stays unbuilt: M21's client does not need it.

### D23. Higher-order modules and applicative functors

**Decided: A, not now** (2026-11-02), as recommended.

The brief: "unless you think you need them now". **Not now.** Nothing in E5-E12 needs more than first-order application: ideation2's decorators all reduce, and an applicative functor adds no store hit: memoising an instantiation is a store key, and it does not need applicative semantics (the review; Yang). Rune 2's document keeps them as an open question.

### D24. One store

**Decided: B** (2026-11-02), as recommended, with a clause for a second language below.

*`.rune` and `lib/cache`, explained* says what exists. One mechanism, with two policies. *Layer* has two senses here: the static, ABI and implementation layers are an interface's; the frozen layer and the overlay are the store's.

- **A. Leave it.**
- **B. One layout, in layers.** **Recommended.**
  - **Location:** `<workspace>/.rune/`, one per workspace (D4), not beside the first input. `RUNE_CACHE` overrides it, which is how a store is shared across worktrees, and `--cache-dir` (`src/driver/options.sml:253`) stays above that. A user-level default was rejected by incremental's D14, and nothing here reopens it: across-root gains are small (E16).
  - **Layers:** an ordered list, read-only layers under one writable overlay. The frozen `lib/cache` is such a layer, per config, built at install, and **dist ships it**, so a dist user's first `--units` compile stops building the Basis.
  - **Keys:** logical name (D3), text and settings to a cache entry, whose sections are hashed per layer (D1). An action to manifest map, as Go's and holbuild's. What a key covers is the client's: rhc's covers every member of an SCC of modules.
  - **A cache entry splits** into head and sections, so that a lookup reads heads. **The head belongs to the client:** the store holds its bytes and never reads them, and a `holds` callback says whether a candidate stands. Rune's head holds usages, since `find` checks each candidate's (`lib/compiler/driver/unitcache.sml:264-307`), and rhc's its level and export digests. On rhc's toy, 17 entries under one key went from 9.12M to 7.89M VM instructions, for +66 lines in the store (its E13). The `units/` paths that remapping reads (`:322-329`) stay by identity, beside the entries. Reading and hashing whole entries costs 2-11% of a no-op today (E15), and stale entries cost more: MLton's warm went from 83.9G to 116.2G, +38%, after about 15 edits, one observation with the cause not isolated (E13).
  - **Eviction:** by age and size, refreshing an entry's time at most hourly (Go), never during a build, and any failure is a miss. The owner's HOL4 tree holds the worst case on this machine, read-only: 1.9 GB, 205,450 files, 87,914 keys, in one config (`results/store-census/hol4.txt`). It holds REPL declarations through `use` (`docs/units.md:550`), so it is a worst case and not a growth model.
  - **`.tmp-` files swept;** `make clean` clears the overlay.
- **C. Content-addressed by name-free keys.** D3 B, and wrong.

### D25. The warm path

**Decided: A** (2026-11-02), as recommended, with a clause for a second language below.

Up to date costs 20-53% of cold on real corpora and 39-40% at every size of the fixture, and a small edit costs what a no-op costs (E15, E21). Where it goes differs by corpus: on MLton the basis load is 62% of the wall and GC 40% of the instructions, a 1.76 GB heap from 22 MB of pickles; on HOL4 and `rune.build` the load is 3-4%, and link and code decode are 48-59% (E15).

- **A. All of E15's, in this order.** **Recommended.**

| Step | MLton no-op | HOL4 | `rune.build` | Leaf |
|---|---:|---:|---:|---|
| a, d: no basis on a hit; lazy closure on a miss | 26.2% | 88.0% | 104.4% | MLton 26-35% |
| b, c: stat shortcut; plan memo | 20.3% | 61.8% | 75.8% | HOL4 69-71%, rune 70-78% |
| l: link memo | 4.5% | 11.8% | 13.3% | HOL4 69-71%, rune 78-79% |
| u: nothing changed, exit | **0.2%** | **0.8%** | **2.1%** | HOL4 69-71%, rune 70-78% |

  Percent of an unset compiler; all output is the baseline's bytes (E15). A no-op falls to 0.22G, 67 ms and 19 MB on MLton.
  - **A leaf's floor is code decode plus link,** 70% of today on HOL4 and `rune.build`. A link from bytes, or a relocation table, is the item after, and it is unmeasured.
  - **`checkSchemes` cannot run on a light hit:** it reads ToMid's tables, and S82 fails by design. A binder's identity covers what it checks, and a fingerprint hit is the one case it cannot check (`unitbasis.sml:1444-1446`), so it goes, or moves to `--verify-cache`, and S82 changes with it.
  - **A stat memo is not a key,** so "nothing in a key is a time" stands. It needs ctime, inode and the racy guard.
  - **A hit may read a head (D24).** "No basis" is a rule about SML's basis, not about what a client's check may read. For rhc a hit reads its imports' exports and the closure's instances through the head, inferred and not measured: its model counts 713 wrong answers in 15,750 edits with no instance read, and 298 with direct imports' alone (its E13).
  - **Memos go in `lib/compiler/driver`,** not `src/driver/main.sml`: 276 of the 321 `main.sml` additions in E15's patch name no compiler state, and a second driver then has them.
- **B. `-j` first.** `-j` gives no speed-up: the parent's linear pass is the floor, and `-j 4` makes a no-op slower, 12.75G against 9.71G, since it parses every input. `parallel.sml` treats a hit as a completed node once light hits make the parent's pass cheap, and not before.

### D26. The editor's context model

**Decided: B** (2026-11-02), as recommended, and two language status items, the owner's addition below.

The brief: "i don't like the lsp currently asks under which build files it needs to analyze an sml files. in a properly modular language i would expect this not to matter?" It should not, and in nearly every case it does not.

- **A. As today.** The prompt fires on the number of candidates. Of 826 files in a build here, 232 have two or more, and 210 prompts appear under discovery. Ambiguous files drop out of workspace sweeps.
- **B. A file has one owner, and a prompt means real divergence.** **Recommended.**
  - **One owning library per file,** with tests as friends, not second owners. CM, MLKit and dune all refuse the question in this form: "The same ML source file cannot appear more than once". That ends the prompt for all code under a library.
  - **Where a file still has several contexts,** compare their resolved uses by canonical binder, never by printed type: one type prints as `SML90.instream` or `TextIO.instream` depending on what was selected (E22). Real divergence is 8 of 232 files, 3.4%: `Config` from two places, and win32 32 against 64. **Prompts fall from 210 to 4** (E22).
  - **Drop candidates that cannot reach the file:** 118 of the 232 have one. `lib/compiler/frontend.build` fails at unit 1.
  - **Spellings** go with D3: 149 of 826 files are several units today.
  - **Sharing equal contexts can wait while few contexts are open.** It would save a factor of 3.26 by text share (E22). A context costs 8-24 MiB on `rune.build`, 212-725 MiB at 1.17M lines, unshared (E24); two contexts in one process were never measured.
- **C. A setting names each file's build.** Moves the question into a file.

**Zero-build files are the common case:** 3,131 of 3,955 tracked SML files, 79%, are in no readable build (E22). `use` is not the answer: a top-level `use` appears in 1 of 3,955 files. Nor is the nearest build's context, which E20 proposed and E24 tested: clean files go from 251 to 262 of 726. E24's figures show where the first unbound name lives, for 369 of 408 files: in the same directory for 154, in the same two top directories for 41, elsewhere in the repo for 174. For 17 it is nowhere, and 22 messages name nothing to look up. So the direction is **an implicit library over a directory, and a name-to-file index read from syntax,** which well-formed units make possible, with analysis going on past the first error and no prompt. That is M19's use of M16, and the answer to the brief's line 33. It is untested: E24's loose run crashed with `Domain` after 12 files. A name-to-file index says where a name is declared, and M19 builds it; a global index of analysis results is what waits for *Later*.

**Two language status items** (the owner's addition, 2026-11-02). The VS Code extension gains two items in the `{ }` menu beside the language mode, through `vscode.languages.createLanguageStatusItem`, which is stable at the extension's minimum, 1.106.0 (`editors/vscode/package.json:11`). It shows neither today: `editors/vscode/src/extension.js` is 36 lines.
- **Progress,** on `sml` and `rune-build` files. `busy` while the server discovers, checks or sweeps; `text` what it is doing; `detail` the context and the units checked and reused, which a failure's report already holds (`docs/language-server.md:147-148`). Error severity after a worker fails. Its command opens the output channel. A foreground check shows nowhere else today: `$/progress` goes only to a request that brought a `workDoneToken` (`src/lsp/service.sml:166`, `:283`), and the rest goes to `window/logMessage` (`:275`).
- **Context,** on `sml` files. `text` the context the active file is checked in, or that it has none; `detail` how many it has. A file with one has no command. A file with several has `runelsp.chooseContext`, a quick pick of them, whose answer takes the path a prompt's answer takes (`src/lsp/controller.sml:161`). An unresolved file shows Warning severity and the same command. A choice lasts as long as it does today.
- **Why, when there is a prompt:** it shows once. `context` skips a file in `asked` (`src/lsp/controller.sml:46`). A dismissal leaves it there (`controller.sml:157`), unresolved, with nothing on screen. A chosen file is `Selected` from then on (`src/lsp/workspace.sml:197-203`). Only closing it (`controller.sml:107`) or changing settings (`controller.sml:111`) goes back. The prompt stays, for the first ask and for other clients.
- **The protocol:** `rune/status` and `rune/context` notifications and a request that sets a context, only for a client that asks for them under `experimental` in `initialize`. Other editors see what they see today. Status is sampled every 250 ms, so that it adds no cost a budget can see (+0.06%), and shorter work may not show busy.

### D27. The editor's storage

**Decided: B** (2026-11-02), as recommended.

The brief wants the LSP on an on-disk cache shared with the compiler, and a compile to benefit from what the LSP did.

**Little of this needs a shared cache (E23).** Keeping what was already computed, with origins out of the identity and closed units (`nkfswd`), takes a comment at the end of the last unit from 1-78 s to tens of milliseconds through the real server. A body edit then costs that unit's own elaboration and little else. The order below follows from that.

| Corpus | Stock, leaf comment | Kept, leaf comment, p50 / p95 | Kept, leaf body | Stock, cold | From a store, eager / lazy | Resident KB a line, eager / lazy |
|---|---:|---:|---:|---:|---:|---:|
| `rune.build` | 1.00 s | 0.022 / 0.042 s | 0.14 s | 4.9 s | 0.24 / 0.15 s | 0.40 / 0.14 |
| 117k lines | 19.1 s | 0.064 / 0.094 s | 0.015 s | 13.9 s | 0.67 / 0.35 s | 0.67 / 0.22 |
| HOL4's closure | 9.3 s | 0.248 / 0.275 s | 0.85 s | 26.1 s | 0.99 / 0.58 s | 0.45 / 0.16 |
| MLton | 72-78 s | 0.099 / 0.121 s | 1.35 s, the first of three 10.08 s | 231 s | 11-12 / 0.41-0.48 s | about 7 / 0.14 |
| 1.17M lines | not run | 1.185 / 1.334 s | | 357 s | 11.5 / 5.7 s | 0.64 / 0.19 |

Leaf comments through the server; leaf bodies and cold in process; stock cold in process at low load, E20's server figures being higher; 1.17M lines' cold is the prototype's from nothing; MLton's store is batch's entries, and its about 7 KB a line is that run, while its kept leaf ran in a 15 GiB heap at 14.2 GB RSS. E23, E24.

- **A. In memory only, as today.**
- **B. Keep, then store, then share.** **Recommended.**
  1. **Keep:** names by file, units held between checks, a changed input elaborated at its own saved position, usages deciding reuse past a change, a memo of plan and discovery, origins out of the identity, and closed units, which drop syntax and typing. An early body edit costs 12-60 ms, a comment from 5 ms. Without origins out, a comment reloads everything after it. That is the one piece of D1 this needs, and it needs no M4 (E23); the prototype's letter `s` drops origins, and by reference, resolved at read, was never built (E24). On an added name a usage check keeps 79 of 79 later units on `rune.build`, 666 of 666 on HOL4, 9,998 of 10,000 at 1.17M lines; what remains is reloading what follows, O(later units). Facts, uses and diagnostics match a fresh analysis after every edit, on `rune.build` (42 checks), the fixture and HOL4, though `rune.build`'s oracle run walked where the timed run took the fast path, which narrower oracles cover there; MLton has none. Bindings differ exactly where a span moved under a reused client, until origins go by reference. Otherwise this step needs D3's names alone.
  2. **Sidecars in the store.** A sidecar of facts, uses and types is 147-165 bytes a line. Its key is **source hash, a digest of usages and a format version,** not source hash alone as R suggested: facts hold imports' types, so a client's sidecar goes stale with unchanged text (deduced). Not the compiler's identity, so it survives an upgrade as a stale hint. Hover and definition into a closed unit are not wired in the prototype.
  3. **Share the static layer with batch.** Analysis already loads batch's *whole* entries: 245 units, none elaborated, 0.23 s. Over 28 checks, diagnostics are the same, and on the open unit facts and uses too; that oracle ran on `rune.build` alone, on one unit of 245. Bindings need the sidecar, since batch records no origins. A basis cut to the static layer alone is untested. **D1 is what makes this last,** deduced: without a static fingerprint written by one writer, the first edit gives a unit another identity and breaks 55 of 79 usages on `rune.build`, 2.6 s against 0.02 s. MLton's batch pickles are 23 MB, its analysis-written ones 2.8 GB, so analysis's own pickles must never be what loads.
  4. **Split the config.** Level, passes, fuel, target and int bits move no static hash, and ISA and the inline lists go with them by reading; today's fingerprint moves on 1,927 exports with `-O0`. Language settings stay in the static key, with a front-end version.

  **Lazy load is not yet right in analysis.** It is verified in batch (E15), but a lazy *world* gave false type errors on interface edits: HOL4's datatype edit reports `type mismatch between int and int`, where eager, stock and the kept path report nothing, and MLton from batch's entries before a fix to the overload table; after that fix a datatype edit stops on a prototype failure (E24). So M18 starts eager, and lazy goes on only behind an oracle over all units. The table's lazy columns are what is on offer, not what is shown correct.
- **C. "Precompile as we edit", by a fat interface.** A stored static layer saves **nothing** in a later compile, since a client that must recompile needs its `decs` (`lib/compiler/driver/pipeline.sml:286-296`; deduced, not measured). GHC's route, keeping Mid before the passes, saves at most a quarter of one unit, and needs `makesCode`, which analysis avoids. No.
- **D. Entries on save.** A background `rune --build` from the save path, so no new mechanism and no unsaved text under a saved identity. It saves 12.0% of a later compile on `rune.build` and 5.7% on HOL4, instructions moved to a worker rather than removed. An option in M20, not a goal: with M6, an up-to-date compile costs almost nothing anyway.

**After a compiler upgrade:** sidecars stay as stale hints, and the static layer is rebuilt once. A cold store costs one analysis, 315-357 s at 1.17M lines. Analysis costs what a compile does, 24.9G for the prototype and 28.9G stock against 26.3G, and 3.6-4.1 times type-checking at 7.0G: the surplus is unexplained, and it is worth a look.

### D28. The editor's caps and scale target

**Decided: B** (2026-11-02), as recommended.

The LSP plan states no scale target. E20 found the caps in the order they break: the 30 s deadline at 1,000 files, the 512 MiB heap at 40-60k lines of ordinary code, the equality-work limit at one declaration of 14-28k lines, and only then the 10,000 inputs. Planning a check is the worst of it: `enrich` re-reads every target on every check, 21 s at 1k files and past 590 s at 10k, though `Project.read` itself is linear.

- **A. Raise the caps.** 10M lines at measured density is 88 GB: it does not fit (E20).
- **B. A stated target, as cost functions, and caps removed by laziness.** **Recommended.**

| Scope | Target | Today, stock | With E23-E24's prototype |
|---|---|---:|---:|
| **Workspace:** 10M lines, 100k files, 1000 builds | Planning a check at most 200 ms, reading no build outside the changed set | 16 s to read, then hours, extrapolated | Memoised; a median 0.18 s of stats at 1.17M lines is what remains |
| **A context:** one closure of 1M lines, 10k units | At most 2 KB a line resident | 8.8 KB | Eager 0.40-0.67 KB, lazy 0.13-0.22 KB; MLton eager about 7 KB from batch's entries, 43 from analysis's |
| Cold from a store | Seconds at 1M lines | none | 11.5 s eager, 5.7 s lazy |
| A leaf comment | p95 at most 250 ms | 1-78 s | Held on the fixtures to 351k lines and on `rune.build` at 512 MiB; 0.275 s on HOL4; 1.33 s at 1.17M |
| A body edit | That unit's own elaboration, on top | 0.35-103 s | 0.015-1.35 s in process, MLton's first of three 10.08 s; no replay measured one |
| An interface edit | O(clients) | O(all later units) | O(later units): 11-14 s eager at 1.17M lines, 51-75 s lazy on a datatype |
| Hover | At most 50 ms | 95 ms on HOL4 | 4-15 ms |

  - **Never resident:** the whole repo. At 1M lines a leaf also needs a path index for `Env.pathOf`, file events rather than stats, and a per-unit view: deduced, not measured.
  - **Cold from nothing is not a target:** 2 minutes per million lines is not met, at 315-357 s. The store is the answer.
  - **The caps:** 10,000 inputs and 128 MiB go once the target holds. 512 MiB held at 351k lines with no headroom. The deadline goes with planning.
  - **The brief's shape:** 1000 builds over 100k files is 100 files a build, or 125 a library if 80% of builds are libraries, as `gen.py` assumes: four times any corpus measured (E20).
  - **CI:** `gen.py --lines 100000 --files 1000 --builds 10` and a `--no-text` planning bench at 100k files.
- **C. Interim, proposed, not measured:** the bug fixes plus a 2 GiB heap and a longer deadline, for 200k lines and 1,000 units, which would cover HOL4's closure; neither is in M1. Not a target.

### D29. Phase separation of a term layer

**Decided: A** (2026-11-02), as recommended.

*The ideation, reviewed* gives the argument and Gate G2's test.

- **A. Not built.** **Recommended.** Test 1 fails: 6 plans, 2 axes and no derived axis against 12, 3 and 1, and test 6 fails on the one workload run: 462 ms against 250 ms (E12). If a real project ever passes, a build program is a pure function of declared parameters to a plan, with no clock, no environment and no file reads, stored under its text and parameters, and it never runs for `rune.build`, on a host or in a reader. Because the plan is the contract, nothing is foreclosed.
- **B. Build it behind Gate G2.** G2 stays the owner's to overturn.

## The milestones

Each milestone is one commit or a few, and each commit leaves `make check` green. One that touches the compiler's sources also passes the host builds and `make check-cross`; one that touches units or the cache passes `make test-incremental`; one that touches the LSP passes `make test-lsp`. Every milestone that changes a key shows no disagreement with `--no-cache` over random edits (E15's `mutate.sh`, kept as a tier in M2). The sizes are lines of code and tests.

M1 comes first. M2 follows, less what needs M4's export of load and M6's lazy load. M3 and M4 settle the unit model that most of what follows stands on; M6 and M17 do not need M4. After them C, L, S and A can go side by side, except where a milestone says so. Doing them in the order the brief lists them would do the work twice (*Why this order*).

| Track | Milestones |
|---|---|
| F, the footing | M1, M2, M5 |
| U, the unit model | M3, M4 |
| C, caches | M6, M7 |
| L, libraries and the language | M8 to M15 |
| S, separate compilation | M16, M21, M22 |
| A, the editor | M17 to M20 |
| All | M23 |

### M1. The fixes found, and the guards that cost nothing (F; M, about 500)

* **What:**
  - **`loadsUnits` asks whether a program loads units** (`src/driver/main.sml:590-593`; E13), not whether `runtime.sml` or `dynamic.sml` is among its files. Forcing the remap (`RUNE_E13_REMAP`) takes E13's replay from 4,048 rebuilds to 1,874 and from 4,373G to 3,506G. The fix was not built: it must define what counts as loading, keep refusing `RuneCompiler`'s clients, and show S41 on program bytes, since forced remap changed 62 bytes on a client that keeps its exports (E11). `load` and `stats` share `lib/basis/runtime.sml`, so it needs either the loading half in a file of its own or a usage test after elaboration. A program that really loads a unit keeps the refusal and `keepExports`, and that has a test.
  - **Selection reads `Deps`' uses, not tokens** (E3's `E3-select-by-uses.patch`, about 15 lines): alpha-renaming a bound variable no longer changes a program's output. A file that does not parse under `Fixity.initial` keeps its tokens as its mentions until M16 gives `Deps` a prelude's fixity (`Conv.sml:205` is such a file). Library files' second pass stays on tokens. Its parse is measured against hello and a `rune.build` no-op; HOL4's closure and MLton are in the done-when.
  - **An `inlv` usage holds line starts** (E18's bug 1; D1), so warm equals cold on a same-size edit, and the comment above a marked function stays a rebuild.
  - **Every setting in a key:** `Expand.budget`, `Types.workLimit` and `Exhaust.workLimit` (E18), with the flags oracle added in M2.
  - **`--diagnostics=full` gives its full text warm:** today the stored short text, 65 bytes against 123 (E18).
  - **`--typecheck-only --build` keeps exports** (`src/driver/main.sml:827` returns before `logDeclared` at `:857`), which made 630 false errors on MLton. **It compiles what compiles:** `openConstructors` asks of a table `specDatatypes` fills only with code (`lib/compiler/elab/elaborate.sml:1220`, `:2065`; E17).
  - **The REPL compiles** `functor F (X : S) = X and G (Y : S) = Y` (E7).
  - **Analysis is linear in a unit's declarations:** the six lines of `E20-env-plus-origins.patch`. It takes `rune.build`'s check from 11.6 to 6.6 s.
  - **A large declaration no longer aborts the worker:** `lib/compiler/syntax/incremental.sml:147`'s structural `=` of token keys (E20).
  - **`configurationFor` is not quadratic** (`src/lsp/workspace.sml:80-91`).
  - **`--build-list` gives the closure;** today 23 files of `runelsp`'s 157 (E12).
  - **`--basis-index` notices a name its dependency hides** (E28).
  - **A second `use` replays through its boundary** (`src/driver/main.sml:939-946`; D8).
  - **Unknown annotations and exports naming nothing are errors** (D6). A program-level `type` export matches the index's rule. E9's translator stops writing MLB annotations.
  - **`scripts/install.sh` refuses when no Basis was installed** (H2).
  - **A relative path variable serves every directory** (`lib/compiler/driver/buildfile.sml:191`; E12), so no machine path enters a plan.
  - **`.tmp-` files are swept,** and `make clean` clears the overlay.
  - **Reach-in warnings** (D10), with 17 builds warned of, 12 hand-written and the 5 generated pointers, unless the pointers are exempted.
  - **`docs/build.md` says what is so:** no "renaming", the path characters, how hosts get lists, 33 libraries, the tests' real path, `use`'s caller's basis. `corpus/hol4.md`'s paths, `SCENARIOS.md`'s S7, `tests/lsp/project-replay.sml:61`.
* **Why first:** a semantic bug, three holes in the cache, and the largest cut in rebuilt units, none of which waits for anything.
* **Done when:**
  - E3's alpha-renaming pair print the same;
  - selection by uses compiles HOL4's closure and MLton, and its parse has a measured cost;
  - E13's `mention-runtime` takes the client from the cache, S41 holds on its program bytes, and a program that really loads a unit stays refused;
  - each bug fixed here has its reproducer as a test;
  - `make check` is green.
* **Touches:** `src/driver/main.sml`; `lib/compiler/driver/{basismanifest,context,buildfile,unitbasis,unitcache}.sml`; `lib/compiler/elab/{elaborate,env}.sml`; `lib/compiler/syntax/incremental.sml`; `lib/basis/`; `src/lsp/workspace.sml`; `src/repl/`; `scripts/install.sh`; the `Makefile`; `docs/build.md`; `corpus/hol4.md`; `tests/`.

### M2. Independent checks of the cache (F; M, about 700)

* **What:** D20's checks as tiers of `make check`:
  - the flags oracle: every option reaches a key or is declared not to;
  - the mask, which lands with M6, since it runs under lazy load: a unit recompiled with its basis cut to its usages gives the same bytes;
  - root blanking from the `CompilerState` roots, and fact edits;
  - verification of all hits: `--verify-cache` compares what it now compiles again (E18);
  - random edits against `--no-cache` as a standing tier;
  - the mutants of E18 kept with `make test-compiler-mutants`, and the 13 survivors examined one by one.
* **Why here:** every later milestone changes a key, and these are what will catch it.
* **Done when:** issue 15's check runs and compares what it can; the issue closes with M4's step 2; each check catches its mutant; the budget of `make check` holds.
* **Touches:** `tests/runner/`, `src/driver/main.sml`, `lib/compiler/driver/unitbasis.sml`, `docs/testing.md`.

### M3. Logical names and the workspace (U; L, about 900)

* **What:** D3 and D4. A root file. `library:path`, with a rank for a file given twice. A key, an identity and an anchor hold the logical name. Spelling no longer reaches them. The LSP's `file#rank` goes. `RuneCompiler.Project` takes the workspace.
* **Why now:** before layers and the store, whose keys it fixes. Doing it after them does them twice.
* **Done when:**
  - E16's table: `worker.build` spelt `../../` compiles 1 unit, `rune.build` spelt `./` none, a moved library none;
  - E16's `same-file-twice` prints the same in whole and `--units`;
  - no disagreement over random edits.
* **Touches:** `lib/compiler/driver/{project,unitcache,unitbasis}.sml`, `src/driver/main.sml`, `lib/compiler/api/`, `src/lsp/workspace.sml`, `docs/units.md`.

### M4. Layers (U; L, about 1,200; after M3)

* **What:** D1. In this order, each step green:
  1. spans out of hashed data and into a sidecar, except what a copied function's line table needs: that stays in the client's code, with M1's line starts in its `inlv` usage, until a link fills it in from sidecars under a link key that holds them;
  2. hash-only fields out of the pickle, so that exporting what was loaded gives the same bytes, and the property becomes a test;
  3. imports' identities out of the hash;
  4. the fix in `typed` (`lib/compiler/elab/elaborate.sml:2231`), so that analysis and batch agree;
  5. static and ABI layers with a hash per export; a constructor's flat size in the static layer (E17's leak);
  6. one canonical writer of the static layer;
  7. if a read of `Ty.convert` and `shapeOf` can be cut to layout, the ABI layer holds layout, not the whole realisation; shown by the random edits and E17's directed edits, or dropped;
  8. MLton's stamps and flags of environment references shrunk, and signature specifications shared.
* **Why now:** the editor's sharing (M18) and the store's keys (M7) rest on it.
* **Done when:**
  - analysis and batch give equal static hashes on `rune.build`, MLton and HOL4's closure, as a tier;
  - E17's directed edits rebuild exactly what they should;
  - E13's replay falls, by at most 814, or the roadmap's record says why not;
  - no disagreement over random edits.
* **Touches:** `lib/compiler/driver/{unitbasis,unitcache,unitmid}.sml`, `lib/compiler/core/midcodec.sml`, `lib/compiler/elab/elaborate.sml`, `docs/units.md`, `docs/bytecode.md`.

### M5. Codecs (F; L, about 1,000 changed; after M4)

* **What:** D21. One description with field marks. Writer, reader and `sameEnv` generated, the fingerprint the hash of the marked fields' canonical bytes. Table reads stay by hand, or tables are declared. Output committed, as `make isa`'s is. The fingerprint oracle joins M2's checks.
* **Why after M4:** the marks are M4's layers.
* **Done when:** the same bytes on the Basis, `rune.build` and MLton; what the description covers replaced; table reads stay by hand; a change to a type cannot leave a traversal behind.
* **Touches:** `lib/compiler/driver/{unitbasis,unitmid}.sml`, `lib/compiler/core/midcodec.sml`, a generator under `tools/`, the `Makefile`.

### M6. The warm path (C; L, about 900)

* **What:** First the store's split: `lib/compiler/driver/unitstore.sml`, with the head and sections opaque to it and `holds` passed in (D24), since 130 of the 138 `unitcache.sml` additions in E15's patch are the store's. It starts from rhc's `E13-1-store.patch` (+338 -231, bytes unchanged, in the Haskell 98 drafts). Then D25, in its order: binders-only hits and lazy closures (`a`, `d`); the stat shortcut and plan memo (`b`, `c`); the link memo (`l`); nothing changed, exit (`u`). Memos go in `lib/compiler/driver`. `checkSchemes`' fate decided. `-j` stops parsing every input on a no-op; its cost on small units stays open (D25's B).
* **Why here:** it does not need M3 or M4, and it can go earlier. It is here because M2's mask lands with it, and because E15 measured it on today's format; re-measure on M4's.
* **Done when:** a no-op on MLton, HOL4's closure and `rune.build` is under 5% of today, with E15's verification as a test: unit by unit, S41, `--verify-cache`, the racy cases; the store has a test that links no compiler.
* **Touches:** `src/driver/main.sml`, `src/driver/parallel.sml`, `src/repl/session.sml`, `lib/compiler/driver/{unitbasis,unitcache,unitstore}.sml`, `lib/compiler/internal.build`, `lib/compiler/util/source.sml`, `lib/compiler/backend/unitfile.sml`.

### M7. One store (C; M, about 600; after M3, M4)

* **What:** D24. Layout, location, layers, keys, a head the client defines and sections, eviction, dist. *`.rune` and `lib/cache`, explained* becomes a page of `docs/units.md`.
* **Done when:** `build/.rune` and `src/lsp/.rune` are gone; a dist's first `--units` compile builds no Basis; HOL4's store stays bounded under eviction with no loss of correctness; warm cost does not grow with stale entries (E13's +38%).
* **Touches:** `lib/compiler/driver/unitcache.sml`, `src/driver/main.sml`, `tools/builder/dist.sml`, `scripts/install.sh`, the `Makefile`, `tests/incremental/`.

### M8. The library model (L; M, about 600)

* **What:** D7, D8 and D11. `requires` declared and not transitive, a library elaborated in a basis empty but for the Basis, a warning on a clash (M10 makes it an error, with renaming), fixity across a boundary, a boundary in the header, a hash per filter, named views, `friends` in the header. A library with no header keeps today's meaning, with a warning (D15).
* **Done when:** the 3 additions, 1 removal and 3 program edges outside the win32 work are in; in a library with a header, a library's name used undeclared is an error; a library with no header builds as it does today; E3's holes have tests.
* **Touches:** `lib/compiler/driver/{basismanifest,context,libraryscope,buildfile}.sml`, `src/driver/main.sml`, `docs/build.md`.

### M9. One planner, and the plan (L; M, about 700; after M8)

* **What:** D5 and D6. One reader in place of four, one site in place of six, the plan's canonical text, the constructs dropped, the command line through a plan. E9's translator moves to headers or nested libraries, which settles D6's two export rules. The index moves to a module the driver and runedoc both reach. Selection by uses reaches what M1 left on tokens: `lib/compiler/api/analysis-engine.sml:219`, `session.sml:173`, `query.sml:84` and `prelude.sml:22`, so that analysis and the API select as batch does.
* **Done when:** all 90 builds round-trip; `basisIndex` is gone; `tools/generate`'s text rewriting uses the plan.
* **Touches:** `lib/compiler/driver/{buildfile,project}.sml`, `src/driver/main.sml`, `lib/compiler/api/{compiler,session,query,analysis-engine}.sml`, `src/doc/docelab.sml`, `tools/generate/`.

### M10. Namespaces and Basis views (L; M, about 400; after M3, M8)

* **What:** D9 and D12. Clash errors and rename at import. Two renames: one settles `History`, and a second settles `RuneCompiler`, since a library may shadow a Basis name only by a declared rename at import, and the REPL's and the compiler's use keep working. M10 settled `RuneCompiler` in `lib/compiler`'s header instead, `shadows (structure RuneCompiler)`: the Basis is not imported by name, so it cannot be renamed at import, and a rename at each client's import would be written in every one. Seal sets after the libraries, `view NAME` in a build.
* **Why before M13:** otherwise files migrate twice.
* **Done when:** a program with both `History`s compiles; a clash with no rename is an error; `RuneCompiler`'s clients, the REPL and the compiler work; a view hides a member, with S41, S42 and `--verify-cache` holding.
* **Touches:** `lib/compiler/driver/basismanifest.sml`, `lib/basis/library.build`, `docs/build.md`.

### M11. Hosts' lists and the compiler's identity (L; S, about 200; after M9)

* **What:** D14. **Before any root moves.** Committed plans for the five host-built roots, `identity.sh` in `gen-version.sh`, `print | cmp` in `make check`, and the identity over the closure, less the two generated files that hold it. `rune`, `runelsp`, `runedoc` and the REPL keep one identity; a second compiler has its own, over its own closure.
* **Done when:** E12's experiment fails to go wrong: an edit of `lib/unicode` through `libraries` changes the identity, B does not take A's entry, and two makes with no edit give one identity; an edit in a second compiler's own sources changes its identity and not `rune`'s, shown on a toy until rhc lands.
* **Touches:** `scripts/gen-version.sh`, `scripts/build-files.sh`, `scripts/gen-build-files.sh`, the `Makefile`, `tests/runner/`.

### M12. MANIFEST's end (L; L, about 900; after M1, M7, M9)

* **What:** D13, in Appendix E's order: install, dist and vscode ship `library.build`; readers move to one query; compiler, LSP, select, `-j` and runedoc read the store; stage 0; the 21 fixtures and 7 test programs; `make manifests` goes; `.gitignore`.
* **Done when:** no file named MANIFEST exists or is read; a stale index is impossible by construction; hello's compile does not grow, with and without `--no-cache`.
* **Touches:** about 30 files: `src/driver/main.sml`, `lib/compiler/driver/basismanifest.sml`, `lib/compiler/api/`, `src/doc/`, `scripts/install.sh`, `tools/builder/`, `tools/generate/`, `tests/`, the `Makefile`.

### M13. Migration (L; M, mechanical; after M8-M12)

* **What:** D15. The migrator and `rehash` ship. They run on everything but the win32 work, whose set is recomputed first: declared dependencies, boundaries on 18 of the 26 libraries that lack one, with the claim rule (D8), the root builds through `libraries`, with the recipe in `docs/build.md`. A boundary keeps what master's clients use and what the win32 work's use, read from a copy of its commit and never its worktree, so that none hides a name that work needs. The sub-build uses from outside `lib/compiler` become friends or a declared view.
* **Done when:** 159 of 159 programs byte-equal, or their successors; no `.build` file of the win32 work has changed, and no win32 branch.
* **Touches:** the 33 build files outside the win32 work, 21 by tool and 12 by decision; `lib/compiler/driver/`, for the claim rule; `tools/`.

### M14. Reaching in, runedoc (L; M, about 500; after M13)

* **What:** D10. Reaching into a library with a header becomes an error. Into a library with no header it stays a warning until D15's window closes, which leaves `runeffi`'s 2 files of `lib/unicode`. runedoc reads exports, and keeps today's path for a library with no header.
* **Done when:** the 4 test builds and the drivers D11 names are friends; a non-friend is refused; rhc's `mid.build`, if it has landed, is a named view of `lib/compiler` (D8); `make docs` passes on every library.
* **Touches:** `lib/compiler/driver/`, `src/doc/`, `tests/compiler/*.build`, `tests/lsp/syntax-tests.build`, `docs/doc-comments.md`.

### M15. Generated sources and preprocessors (L; M, about 400; after M9)

* **What:** D16. Declared steps before planning, `build/config.sml` as the first, a per-file preprocessor class, and `runeffi`'s rehash mode.
* **Done when:** HOL4's `src/boss` closure builds from its unfiltered sources with a declared filter; `build/config.sml` is in the plan.
* **Touches:** `lib/compiler/driver/{buildfile,project}.sml`, `src/driver/main.sml`, `src/ffi/`.

### M16. The restriction (S; M, about 500; after M8)

* **What:** D17. Three classes; a prelude's fixity known to `Deps`; the four rules as a warning; `strict` per library; `Deps`' discipline loses the rules nothing needs; a row in `docs/language.md`; `docs/units.md`'s section. The name is well-formed.
* **Done when:** E8's table is a test: Rune's own libraries, MLton and HOL4's closure well-formed but for declared preludes; `rune --deps` finishes on HOL4's closure; the REPL's deviations are documented, or fixed.
* **Touches:** `lib/compiler/driver/deps.sml`, `src/driver/main.sml`, `docs/language.md`, `docs/units.md`, `tests/`.

### M17. Keeping what is computed (A; L, about 800; after M1, M3)

* **What:** D27's first step: the prototype's letters `nkfswd`, less the store. The free fixes first: `discover` running `enrich` before every check (`src/lsp/worker.sml:45-48`), completion in an early file re-elaborating every later unit, one progress message per input per check, hover filtering all occurrences, `syntaxAt` per input, `register` quadratic in units, and document symbols, quadratic in declarations (`RuneLspOutline.prepare` and `nested`, `src/lsp/outline.sml:8`, `:59`): 1.4 s at 1,000 declarations, 5.2 s at 2,000, past the 30 s deadline at 6,000, so E20's 28,000-line reproducer checks in 3.1 s and then dies on `textDocument/documentSymbol`. Then names by file, units held between checks, an input elaborated at its own position, usages deciding reuse past a change, a memo of plan and discovery, a query at a position. Origins out of the identity: by reference, resolved at read, is unbuilt, so bindings stay stale under a reused client until it is. Closed units drop syntax and typing, and a request into one opens it first, until M18's sidecars answer it. A compaction for a tree that keeps units loaded (E23: 385 to 472 MiB over 225 edits).
* **Why here, and not after M4:** it needs D3's names, and of D1 only origins out of the identity, which needs no M4 (E23). It is most of what the editor wants, and it should not wait for the rest. E23's order.
* **Done when:** a leaf comment's p95 is at most 250 ms on `rune.build`, HOL4's closure and the 351k fixture at 512 MiB, a target HOL4 is over today at 0.275 s, and a body edit costs that unit's elaboration, with a replay that measures one; a fresh-analysis oracle over every path stands as a tier, MLton's included (moved to M18, whose resident target lets MLton's kept world fit); cancellation mid-walk is tested.
* **Touches:** `lib/compiler/api/{analysis-engine,analysis}.sml`, `lib/compiler/driver/unitbasis.sml`, `src/lsp/{worker,worker-analysis,workspace,projects,service}.sml`, `tests/lsp/`, `tools/lsp/`.

### M18. Sidecars and the shared layer (A; L, about 1,000; after M4, M7, M17)

* **What:** D27's next steps. Sidecars in the store, keyed by source hash, usage digest and format. Analysis loads batch's entries, as a static layer. The config split in two. Facts and bindings kept apart from printed paths, since a lazy view prints another path.
* **Done when:** cold from a store is about a second on HOL4's closure and seconds at 1M lines, eagerly; at most 2 KB a line resident; analysis over batch's entries keeps its usages through an edit (E24: 55 of 79 break without this); go-to-definition and hover work into a closed unit; sidecars survive a compiler upgrade as stale hints; an oracle compares every unit, not the open one, and M17's oracle runs on MLton's edits that move an identity. Lazy load goes on in analysis only when that oracle passes on interface edits, on HOL4 and MLton: E24's false type errors are its first tests.
* **Touches:** as M17, with `lib/compiler/driver/{unitbasis,unitcache}.sml`, `lib/compiler/elab/env.sml`.

### M19. Contexts, and the end of the prompt (A; L, about 800; after M3, M8, M16; the status items after nothing)

* **What:** D26. First the two language status items, which need no other milestone: the server's progress, and the context a file is checked in, with a way to choose again. Then one owning library per file. Candidates that cannot reach a file dropped. Contexts compared by canonical binder, a prompt only on real divergence. A zero-build file gets an implicit library over its directory and a name-to-file index read from syntax, which well-formed units make possible: this is M19's use of M16, and it is untested. Analysis goes on past the first error.
* **Done when:**
  - E22's count holds: at most 4 prompts in this repo; workspace sweeps cover every file; E24's sample of 726 improves, with the name index; two builds over one library share their units, measured;
  - the editor suite, on 1.106.0: a file with several contexts shows the one it is checked in; a dismissed prompt leaves a Warning and a way to choose; choosing again changes the file's diagnostics; a file with one context offers no choice; progress is busy during a check and idle after it;
  - a client that did not ask gets no `rune/` message.
* **Touches:** `src/lsp/{workspace,projects,controller,service}.sml`, `lib/compiler/api/analysis-engine.sml`, `editors/vscode/`, `tests/lsp/`, `docs/language-server.md`.

### M20. The target, in CI (A; M, about 400; after M17, M18)

* **What:** D28. The fixture moves to `tools/`. The caps go. Planning reads only the changed set; a path index for `Env.pathOf`; file events rather than stats. Entries on save as an option (D27 D). The LSP plan's budgets are replaced by D28's.
* **Done when:** D28's table holds at the sizes CI can run, with the 10M planning bench at `--no-text`; `docs/language-server.md` states the target.
* **Touches:** `tools/lsp/`, `src/lsp/`, `tests/lsp/`, CI.

### M21. Functor signatures (S; L, about 1,000; after M3, M4)

* **What:** D22's first half. `functor F = _virtual (X : A) : B`, `functor F = _dynamic "path" (X : A) : B` and `_export functor`, in both parsers. `implements` takes a functor. An application typed by the signature alone and compiled as a call over nested records. The ABI fingerprint in M4's ABI layer, with a mismatch an error at link or load. `examples/virtual/table`, the first client, with its builds. The `sml97-extensions.md` entry and the rows of `docs/language.md`.
* **Why here:** spelling reaches a `_dynamic` client's bytes (E10) and the fingerprint lives in the ABI layer, so before M3 and M4 it would be done twice. It needs nothing of track L, so it can follow M4 at once.
* **Done when:**
  - `examples/virtual/table`'s client compiles with no implementation in the build, and with none it raises `Dynamic.Mismatch` when the declaration runs, as a structure's does;
  - the second build through the first one's cache compiles the implementation alone;
  - each implementation gives the same output and S42's bytes through `--units --whole`, and two implementations are refused;
  - a `_dynamic` functor loads as a plugin, and every field of the fingerprint has a mutant refused at link or load;
  - a body edit compiles no client, and an edit of either signature compiles every client (E10's probes, as tests);
  - the fingerprint agrees on the five hosts, and the scenario beside `bigint`'s runs in `make check`;
  - no disagreement over random edits.
* **Touches:** `lib/compiler/frontend/{ast,parser}.sml`, `lib/compiler/syntax/parser.sml`, `lib/compiler/elab/elaborate.sml`, `lib/compiler/driver/unitbasis.sml`, `lib/compiler/util/pickle.sml`, `lib/basis/dynamic.sml`, `src/driver/main.sml`, `examples/virtual/`, `tests/runner/scenarios.sml`, `tests/dynamic/`, `docs/language.md`, `docs/build.md`, `docs/units.md`, `docs/plans/sml97-extensions.md`.

### M22. Virtual libraries (S; M, about 400, not prototyped; after M8, M9, M21)

* **What:** D22's second half. A library's header declares a virtual module, structure or functor, and an implementing library's header names it. One implementation per program; no new public modules. The plan carries it.
* **Why here:** it needs M8's headers, M9's plan and M21's functors.
* **Done when:** `examples/virtual/table` also builds from libraries, its client's units compiled once across both implementations; two implementations in one program are refused; `ffi/win32`'s three fit the form, shown on a private copy of master's, with nothing under `ffi/win32` changed.
* **Touches:** `lib/compiler/driver/{buildfile,project,basismanifest}.sml`, `src/driver/main.sml`, `examples/virtual/`, `docs/build.md`.

### M23. Retire (S)

* **What:** final measurements against *Measuring*; `docs/build.md`, `docs/units.md`, `docs/language-server.md`, `docs/architecture.md`, `docs/language.md`; *At the close*; the worktrees named in it removed with the owner's word.

### Gates

**Gate G1: aggregates (closed).** The brief proposes them; E11 says no; the owner dropped them with D19 on 2026-11-02. There is no milestone behind the gate. If the owner ever reopens it, the packaging form goes after M7, and the optimising form holds member Mid at ToMid or after expand, with `workers` run once.

**Gate G2: the term layer (the owner's).** D29 decided it is not built now. *The ideation, reviewed* gives seven tests. Test 1 fails today, and test 6 on the one workload run. There is no milestone behind the gate. If a real project passes, the layer goes on top of M9 with no reader changing.

### Later

- **A global index of analysis results,** which the brief defers. A name-to-file index is not this: it is M19's.
- **A package manager,** on D3's version and D4's workspace.
- **The win32 work's migration,** once that work has landed (D15), by D15's recipe. Its 8 boundaries, 4 additions and 4 program edges; the 5 generated sets rehashed; `runeffi`'s view of `lib/unicode`; the Win32 generate driver accepting or removing an old set (Appendix D); `ffi/win32`'s three as a virtual library (M22). Then the old form is refused, which closes the window.
- **Imports in code by logical name, not number:** a step E16 did not run, out of M3 since 2026-11-02. It changes `Link.key`, `remapKeys` and `.rbu`, and rhc's link numbers, hashed by name with collisions unchecked, stand on today's form, so it is decided with rhc in view. No target here rests on it: remapping already takes a shifted number.
- **Higher-order modules** (D23), and memoised functor applications.
- **The term layer,** behind Gate G2.
- **A run step,** for a true HOL4 build (D16).
- **A link from bytes,** the warm path's next floor (D25).
- **Finer `open` usages,** worth as much as a layer on HOL4 (E13): 717 units fired only `s M`.
- **A parallel cold build and batch memory at 10M lines** (E21): `-j` gives nothing today, and 48 GB does not fit. No decision here answers this.
- **Mid after expand in units,** only if a pass needs it: E14 measured no gain, and byte S42 lost on 11 of 14 programs.
- **The rest of ideation3,** for Rune 2.

### Why this order

- **M1 first,** because a `loadsUnits` fix should halve rebuilds, and the semantic bugs should not wait for a roadmap.
- **M2 before anything after M1 that changes a key.** Every proposal here that shrinks a key looked like an improvement until it was held to `--no-cache`.
- **M3 before M4 and M7.** Names are in the keys and hashes those define.
- **M4 before M5:** the codecs need its marks.
- **M3 before M17, and M17 without M4:** the editor's largest gain needs only names. **M4 and M7 before M18:** it shares what the compiler stores.
- **M8 before M9:** M9 drops the block M8 moves. **M8 before M10:** a clash can be an error only once a rename can answer it, so M8 warns.
- **M9 before M11,** and **M11 before M13:** the plan is what hosts read, and no root moves until the identity is safe. This order prevents H1.
- **M1's guard before M12:** H2.
- **M10 before M13,** or files migrate twice.
- **Friends before M13, the error after it:** reaching in cannot be an error while builds do it.
- **M8 and M16 before M19:** ownership needs libraries, and the restriction is what makes names readable from syntax. M19's status items need neither.
- **M3 and M4 before M21:** names and the ABI layer are what a functor's fingerprint is built from.
- **M8, M9 and M21 before M22:** a virtual library needs headers, a plan that carries it, and functors.

## Prerequisites and flags

- **The base:** master `b12141ecc`. Line numbers here are of that commit, and are checked again before each milestone.
- **Flags and syntax this roadmap adds or changes:**
  - a workspace root file, `rune.workspace`, and logical names, `LIBRARY:PATH` and `NAME#2` (M3);
  - `view NAME` in a build, and `--basis-view` (M10);
  - `friends`, `requires`, exports and views in a library's header, `lib#view` for a view, and `fixity NAME` as an export (M8);
  - `make test-cache-random` and `make test-cache-mutants` (M2);
  - `prelude` and `strict` in a build (M16);
  - declared steps and preprocessors, `generate` and `preprocessor`, `annotate "preprocess=NAME"`, plan version 2 (M15); `runeffi rehash` (M15);
  - a canonical plan: `rune --plan FILE`, its text with `edge` and `scc` reserved (M9);
  - `--build-list` gives the closure (M1);
  - `rune/status`, `rune/context`, `rune/setContext`, `runelsp.chooseContext` and `runelsp.showOutput` (M19);
  - `functor F = _virtual (X : A) : B`, `functor F = _dynamic "path" (X : A) : B` and `_export functor` (M21);
  - virtual modules in a library's header (M22).
- **What goes:** `group`, `local`, `cache`, the program-level `library` block (M9); `make manifests`, `--basis-index` and `--basis-check` as user-facing steps (M12); `lib/*/MANIFEST`.
- **Files whose formats change:** the cache entry, the `.rbi` and the `.rbm` (M4, M7). The `.rbc` and the image do not, unless M21's binding needs it: the structure half added 28 lines of C loader.
- **What the owner decided:** D1 to D29, on 2026-11-02. Gate G1 closed with D19, and Gate G2 stays the owner's, with nothing behind it.

## Relation to the other plans

- **`bootstrap.md`** (a draft). Its runemake moves most of the Makefile into SML. D14's committed plan is the input it will want, and a host's flat list is its "from source" path. This roadmap changes `scripts/build-files.sh` and `gen-version.sh` only as far as D14 needs. `tools/builder` and the Makefile's complexity stay that plan's.
- **`language-server.md`.** Its M10 (references, rename) and M14 (budgets, distribution) are planned. M17-M20 here change what those stand on: D28 replaces its proposed budgets with a stated target, and M10's references want D27's sidecar. Its plan's stale statements are corrected where *Where we are* meets them.
- **`language-server-dist.md`:** dist's file list moves with D13.
- **`compiler-library.md`.** Its M2, library names and export lists, is what D8 finishes. Its D6 half that "it fills the Basis's `Compiler.use` and `Compiler.compile`" is still not there. `RuneCompiler.Project` takes the workspace and the plan.
- **`incremental-compilation.md`.** This roadmap reopens or completes its D1 and D2 for Rune 2 (and records that they deferred B there), D8 (the single library file never built: D19 says leave it), D14 (a user-level cache, still rejected as a default), D15 (the discipline, now D17's), D16 (the build language), D17 (compiling against a signature: D22; its "no functor in a virtual signature" is stale since functors-units).
- **`functors-units.md`.** Its *Later* item is D22, done here (M21). Its G1 target of 1.5 is not reopened. Its published warm figures are corrected: 88.89G, not 105.0G.
- **`build-cache-issues.md`.** Issues 15 and 22's batch case close here (M4, M3); new issues from E18 enter it with M1. Issue 11's text is stale: code reads and writes the same bytes.
- **`correctness/linting.md`.** Its D18 and D19 modes stay; `--free-tyvars=later` and `--flex-records=program` stay outside builds. Its lint levels apply to every new check.
- **`sml97-extensions.md`:** one extension, `_virtual` and `_dynamic` for functors (D22, M21), with its entry there. Nothing else here extends the language.
- **`specification.md`, `formal-verification.md`.** D20's obligations are the statement a proof would start from.
- **`hol4.md`, `corpus/hol4.md`.** The seven annotations are still not on `rune-build`. M15 gives HOL4 a way through `.build`; a true build needs the run step (*Later*).
- **`language/haskell98.md`** (on branch `haskell98`). rhc, a Haskell 98 compiler on Rune's back end, needs no milestone here. Neither roadmap waits on the other, and run one at a time this one goes first, as an order of convenience (its D46).
  - It asked that six decisions keep a second language in view, and each has its clause: D5 (the plan is Rune's), D6 (written order is per language), D8 (kinds of export are the language's, and a boundary cannot hide an instance), D14 (a second compiler has its own identity), D24 (a head the client defines), D25 (a hit may read a head; memos in `lib/compiler/driver`).
  - M6's first step is its M20, which then falls away.
  - Imports by name left M3 for *Later*, since its D46 names them as what would reopen the order.
  - Its `lib/compiler/mid.build` (its D41) is reaching in by D10. It becomes a named view of `lib/compiler` (D8), not a friend, and M14 holds it to that.
- **`docs/plans/rune2/separate-compilation.md`:** this roadmap's sequel, written with it.

## Risks

| Risk | Where | What guards it |
|---|---|---|
| A lazy read is missed, and the code is silently wrong | M6 | E15's unit-by-unit verification as a tier; the mask; a fault on any unfilled table in test builds |
| A lazy world in analysis gives false errors | M18 | Seen in E24 on HOL4 and MLton. M18 starts eager; lazy waits for an oracle over all units |
| A kept world drifts from a fresh analysis, or leaks | M17 | The oracle as a tier; a compaction (385 to 472 MiB over 225 edits, E23) |
| A layer leaks: a compile reads what its key does not hold | M4 | E17's directed edits; read tracking from `CompilerState`'s roots; M2 |
| A new key is smaller than what the compiler reads | M3, M4, M7 | Random edits against `--no-cache` on every such commit |
| The compiler's identity misses a source | M11, M13 | M11 precedes M13; `identity.sh` over the closure; the version constants are a last defence |
| An empty install from a green build | M12 | M1's guard; the order in Appendix E |
| A boundary hides what a live branch added | M13 | The index warns; the migrator recomputes; the recipe |
| Migration collides with the win32 work | M13 | No win32 branch is touched, and no `.build` file one changes is migrated; the set is recomputed when M13 starts (D15) |
| Shared tooling moves under the win32 work | M9, M12, M14 | `tools/generate/`, `tools/builder/`, `scripts/install.sh`, `src/doc/docsite.sml`, `tests/runner/` and the Makefile are also changed on those branches: ordinary conflicts at that work's next rebase, none in `lib/compiler`, `src/driver` or `src/lsp` |
| Stored plans go stale | M11 | Hash lines on a host; `print | cmp` in `make check` |
| The canonical writer of the static layer changes bytes for the Basis | M4 | The frozen layer is rebuilt; S41, S42 and the bootstrap's budgets |
| The warning of M16 is ignored | M16 | `strict` per library, on Rune's own from the start |
| A library elaborated from a basis empty but for the Basis breaks a build that relied on the caller's | M8 | E9 met exactly one, and hoisted it; the migrator reports them |
| Editor memory stays too high for MLton-shaped code | M4, M18 | D1's sharing of signatures; the stated interim target |
| Generated codecs make a compile slower | M5 | -0.002% on one type; re-measured per type; stop at the types that pay |
| A functor's fingerprint misses what a client compiled from | M21 | A mutant per field; E10's probes as tests; MLKit's bug of 2005 is the case to keep |

## Testing

- **`make check`** on every commit, with M2's tiers from then on.
- **Reproducers:** each bug's reproducer becomes a test in the milestone that fixes it.
- **Mutants:** E18's 37 join `make test-compiler-mutants`, with the survivors examined.
- **Random edits against `--no-cache`:** `mutate.sh` as a standing tier.
- **`tests/incremental`'s scenarios** change where a name is no longer in a key: S7, S21, S22 and S47 say so, and new scenarios cover D3's table.
- **`check-cross`** for each change to the compiler's sources or the hosts' lists.
- **The fixture:** `results/E20/gen.py` moves to `tools/`, with a CI size in M20.
- **The model:** `results/L1/model.sml` moves to `tests/`, as a statement that runs.

## Measuring

Instruction counts at tier 2 are the claims: `perf stat -e instructions:u` and `runevm --count`. Seconds are indications, with the load said. Each number here names its experiment and its script in the drafts, `~/.cache/claude-rune-drafts/build-system/results/`, and the patches are kept beside them. Worktrees `.worktrees/bs-*` and the HOL4 clone are kept until the owner says otherwise.

**The targets, for *At the close*:**

| What | Today | Target | From |
|---|---|---|---|
| Rebuilt over E13's 85 edits | 4,048 | 1,874, as with the refusal off, after M1; lower after M4 | E13 |
| No-op, MLton | 88.89G | under 5% | E15 |
| No-op, HOL4's closure | 26.06G | under 5% | E15 |
| No-op, `rune.build` | 9.72G | under 5% | E15 |
| Leaf, MLton | 89.6-93.4G | about 25% | E15 |
| A no-op against cold, at 1M lines | 39-40% | under 5% | E21 |
| A cold build at 10M lines | about 50 minutes and 48 GB, extrapolated | not answered (*Later*) | E21 |
| Stale files in the tree that generate work | 33 MANIFESTs | 0 | E2 |
| Reach-in builds | 12 | 0, an error, but for `runeffi` into `lib/unicode`, a warning until D15's window closes | E1, D15 |
| Libraries with a boundary | 1 | all but the Basis and the win32 work's 8, until its migration | E1, D15 |
| `make dist`'s first `--units` compile | builds the Basis | builds nothing | *`.rune` and `lib/cache`, explained*, D24 |
| Hello's compile | 296M | no more | E2 |
| Prompts in this repo | 210 | 4 or fewer | E22 |
| Leaf comment, p95, editor | 1-78 s, as p50 | at most 250 ms; 0.04-0.28 s shown, HOL4 over | E23 |
| Body edit, editor | 0.35-103 s | that unit's elaboration | E23 |
| Cold, editor | 4.9-231 s | about 1 s from a store, to 200k lines, MLton-shaped code excepted until M4's step 8 | E24 |
| Resident, editor | 8.8 KB a line | at most 2 KB a line | E20, E24 |

## References

The papers E25 read. Each DOI below was checked against Crossref on 2026-11-01. The version read is
noted where it differs from the published one; *What the literature says* gives how much of each was
read.

- Appel, MacQueen. Separate compilation for Standard ML. PLDI 1994, 13-23. doi:10.1145/178243.178245. Read: Princeton CS-TR-452-94
- Blume. Dependency analysis for Standard ML. TOPLAS 21(4), 1999, 790-812. doi:10.1145/325478.325481. Not seen; content read as chapter 4 of the thesis below
- Blume. Hierarchical Modularity and Intermodule Optimization. PhD thesis, Princeton University, 1997 (no DOI)
- Blume, Appel. Hierarchical modularity. TOPLAS 21(4), 1999, 813-847. doi:10.1145/325478.325518. Not seen; read: Princeton TR-555-97
- Bour, Refis, Scherer. Merlin: a language server for OCaml (experience report). PACMPL 2 (ICFP), 2018. doi:10.1145/3236798. Read: arXiv 1807.06702
- Cardelli. Program fragments, linking, and modularization. POPL 1997, 266-277. doi:10.1145/263699.263735
- Cejtin, Fluet, Jagannathan, Weeks. Formal Specification of the ML Basis System. 2004. `mlton/doc/mlb-formal/mlb-formal.tex` (no DOI)
- Dreyer, Rossberg. Mixin' up the ML module system. ICFP 2008, 307-320. doi:10.1145/1411204.1411248
- Elsman. Static interpretation of modules. ICFP 1999, 208-219. doi:10.1145/317636.317800. Read: pages 1 and 11, as images
- Elsman. A Framework for Cut-Off Incremental Recompilation and Inter-Module Optimization. IT University of Copenhagen technical report, April 2008 (no DOI)
- Flatt. Composable and compilable macros: you want it when? ICFP 2002, 72-83. doi:10.1145/581478.581486
- Harper, Stone. A type-theoretic interpretation of Standard ML. In Proof, Language, and Interaction, MIT Press, 2000, 341-388. doi:10.7551/mitpress/5641.003.0019. Read: authors' preprint
- Kilpatrick, Dreyer, Peyton Jones, Marlow. Backpack: retrofitting Haskell with interfaces. POPL 2014, 19-31. doi:10.1145/2535838.2535884
- Leroy. Manifest types, modules, and separate compilation. POPL 1994, 109-122. doi:10.1145/174675.176926
- MacQueen, Harper, Reppy. The history of Standard ML. PACMPL 4 (HOPL), 2020, 1-100. doi:10.1145/3386336
- Milner, Tofte, Harper, MacQueen. The Definition of Standard ML (Revised). MIT Press, 1997. doi:10.7551/mitpress/2319.001.0001. Read: the sources at `/home/ruud/The-Definition-of-Standard-ML-Revised`, and the PDF at smlfamily.github.io, which are paginated differently
- Mokhov, Mitchell, Peyton Jones. Build systems à la carte. PACMPL 2 (ICFP), 2018. doi:10.1145/3236774
- Mokhov, Mitchell, Peyton Jones. Build systems à la carte: theory and practice. JFP 30, 2020. doi:10.1017/S0956796820000088
- Rossberg, Dreyer. Mixin' up the ML module system. TOPLAS 35(1), 2013, 1-84. doi:10.1145/2450136.2450137. Downloaded, not read closely
- Shao. Typed cross-module compilation. ICFP 1998, 141-152. doi:10.1145/289423.289436. Read: pages 1, 10 and 11, as images
- Swasey, Murphy VII, Crary, Harper. A separate compilation extension to Standard ML. ML 2006, 32-42. doi:10.1145/1159876.1159883. Not seen; read: CMU-CS-06-104, a working draft of 28 January 2006
- Yang. Backpack: Towards Practical Mix-in Linking in Haskell. PhD thesis, Stanford University, June 2017. https://purl.stanford.edu/zf998bz8716 (no DOI). Read: github.com/ezyang/thesis, release "final"

**Sources** under `/home/ruud/reference`, cited in place, at these revisions:
- OCaml 5.5.1, `46e1c324fb`
- GHC `902339d332`
- Cabal `d9b0904b4`
- SML/NJ `6c476227`
- MLton `b15e2d289`
- MLKit `6dab5582`
- Poly/ML `45575540`
- Go `862c888e61`

**Web clones**, under `results/E26/downloads/`, shallow and sparse, read at these revisions:
- dune `46a15f1`
- cargo `809bcc5`
- holbuild `063d9f6`
- smackage `3fc3be9`
- Bazel `9a2abab`
- rust-analyzer `72bedfc`
- Salsa `7f49940`
- Merlin `58f43bf`
- HLS `bc2bbb8`
- hiedb `2232223`
- Glean `b70957d`
- SCIP `bbec534`
- stack-graphs `fcb7705`
- ocaml-index `0f9ffbb`

**Pages**, under `results/E27/downloads/`, fetched 2026-11-01:
- the rustc-dev-guide, "Libraries and metadata" and the incremental compilation chapters;
- matklad, "Three Architectures for a Responsive IDE", 2020-07-20;
- the clangd design pages (indexing, compile commands, remote index);
- Meta, "Indexing code at scale with Glean", 2024-12-19, and Glean's page on incremental indexing;
- Sourcegraph, "SCIP", 2022-06-08;
- GitHub, "Introducing stack graphs";
- JEP 261;
- Microsoft, "Friend assemblies";
- Kotlin, "Visibility modifiers";
- the D specification, "Unit Tests";
- *The Rust Programming Language*, chapter 11.3;
- the Haddock of `Data.Map.Internal`, containers;
- Stack, release-candidate notes for v4.1.0.1;
- Haskell Discourse, threads 2499 and 6739, on Backpack's uptake: participants, so opinion rather than measurement.

## Appendices

The tables too long for the body. Script paths are relative to `~/.cache/claude-rune-drafts/build-system/`. Tables A, B and C are generated from the raw files they name, with nothing edited but the layout, and one label in A.

### A. Every rule against every mechanism (E5)

From `results/E5/rules.tsv`. A column says whether that mechanism needs the rule; "-" means the rule is of no use to it or has no meaning there. Evidence is under `results/E5/` unless it names E6, E7 or E8. `probes` means `results/E5/probes/`. "incremental's D15" is that plan's decision, not this roadmap's, and `rules.tsv` says only D15; "linting D18" is the linting plan's.

| Rule | Source | Tier | Dependency order | Warm cut-off | Closures (D2) | Firewall | LSP context | Verdict | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| no top-level val/fun in a shared unit | CM rule 1, incremental's D15 | parser | yes | no | yes | no | yes | keep for shared | probes/cutoff.out; E8/summary.txt |
| no top-level exception | CM, Deps | parser | yes | no | yes | no | yes | keep for shared | same |
| no top-level datatype or replication | Deps; CM | parser | yes | no | yes | no | yes | keep for shared; HOL Overlay.sml:49 replication hid QUOTE | E6/hol/p0.err of first run |
| no top-level open | CM rule 4 | parser | yes | precision only | yes | no | yes | keep for shared; Overlay.sml:42 hides module rebinding | E6, cutoff open-client |
| no top-level fixity | CM, Deps | parser | yes: the parse | no | yes | no | yes | keep, or make fixity an export: Deps parses with Fixity.initial | E8/deps-hol.err |
| no `use` | - | parser | would | no | would | no | would | drop: batch already has no use (c05) | E7 corners |
| one module name in two units (S19) | Deps.order | parser | yes | no | yes: which binder | no | yes | keep but by scope, not by group | E6 HOL Systeml, benchmarks lcss, MLton 17 names |
| no private val/open in a top-level local head | Deps (break) | parser | no | no | no | no | no | drop: MLton regexp.sml and bits.sml, 168 HOL scripts, 27 HOL entry library files | E8 |
| no bare effect (val _ =) at top level | Deps (break) | parser | no: no name | no | no | no | no | drop as visibility rule; effect is E6's question | E8 |
| overloading settled in the unit | Appendix E, linting D18 | elaboration | - | - | yes | no | yes | holds by construction: no program mode | probes a3,b3 |
| flexible records settled in the unit | 4.11, --flex-records | elaboration | - | - | yes | no | yes | only `program` crosses: whole accepts, --units refuses | probes a1,b1 |
| free tyvars settled in the unit | rules 87-89, G.8 | elaboration | - | - | yes | no | yes | only later, later-monotype cross | probes a2,b2 |
| a signature on each shared structure | SMLSC | elaboration | no | no | no | yes | static layer, no | firewalls only: not a rule for the rest | E5 opaque-body, E8 shape counts |

### B. Who fits, per corpus and class (E8)

From `results/E8/summary.txt`, which `results/E8/analyse.py` makes from `sepcheck`'s census. *Role* is from the graph: a shared unit is one others depend on, an entry unit one nothing depends on. *Fit* means no top-level `val`, effect, exception, datatype, replication, `open`, fixity or `use`, and duplicates are counted apart in *dup*. *Parse* is files the parser refused. *Hidden* is a declaration private to a top-level `local` head. *Fixity* is files that parse differently without fixity carried from an earlier file. `polyml` was parsed only. `hol4` is the whole tree, `hol4-closure` the `src/boss` closure; `hol4`'s value edges are excluded, since that tree is no single prefix.

| Corpus | Class | Role | Files | Lines | Parse | Fit | `val` | Effect | Exception | Datatype | Replication | `open` | Fixity | `use` | `load` | Dup | Hidden | Depends on fixity |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| benchmarks | examples | entry | 868 | 244,316 | 1 | 768 | 79 | 48 | 23 | 13 | 0 | 2 | 17 | 0 | 1 | 86 | 21 | 0 |
| benchmarks | examples | shared | 301 | 97,919 | 0 | 284 | 17 | 7 | 6 | 4 | 0 | 2 | 5 | 0 | 1 | 133 | 3 | 0 |
| benchmarks | tests-benchmarks | entry | 161 | 13,386 | 0 | 155 | 1 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| corpus-harness | harness | entry | 5 | 660 | 0 | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| corpus-harness | harness | shared | 13 | 1,321 | 0 | 13 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| corpus-regressions | program | entry | 1,514 | 37,625 | 255 | 539 | 456 | 326 | 27 | 110 | 3 | 29 | 30 | 1 | 0 | 0 | 59 | 0 |
| hamlet | other | entry | 9 | 283 | 1 | 0 | 0 | 8 | 0 | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 0 |
| hamlet | other | shared | 15 | 9,681 | 0 | 14 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 4 | 0 | 0 |
| hamlet | source | entry | 2 | 46 | 0 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| hamlet | source | shared | 213 | 28,261 | 0 | 212 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 5 | 0 | 27 |
| hol4 | examples-lib | entry | 164 | 98,640 | 6 | 55 | 94 | 66 | 4 | 7 | 0 | 69 | 3 | 13 | 12 | 9 | 9 | 51 |
| hol4 | examples-lib | shared | 646 | 252,829 | 0 | 641 | 0 | 0 | 0 | 1 | 0 | 4 | 0 | 0 | 0 | 111 | 0 | 187 |
| hol4 | kernel | shared | 18 | 7,125 | 0 | 17 | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 14 | 0 | 0 |
| hol4 | library | entry | 143 | 24,595 | 2 | 42 | 82 | 88 | 6 | 1 | 0 | 82 | 8 | 2 | 10 | 3 | 27 | 50 |
| hol4 | library | shared | 1,179 | 244,165 | 0 | 1,176 | 2 | 2 | 3 | 0 | 0 | 0 | 0 | 2 | 1 | 116 | 0 | 263 |
| hol4 | script-examples | entry | 916 | 1,103,135 | 1 | 0 | 910 | 915 | 0 | 1 | 0 | 914 | 69 | 0 | 0 | 0 | 101 | 801 |
| hol4 | script-examples | shared | 2 | 4,050 | 0 | 0 | 2 | 2 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 2 | 1 | 2 |
| hol4 | script-src | entry | 332 | 397,651 | 0 | 0 | 293 | 332 | 0 | 0 | 0 | 332 | 20 | 0 | 0 | 0 | 67 | 232 |
| hol4 | script-src | shared | 2 | 9,766 | 0 | 0 | 2 | 2 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 1 | 2 | 2 |
| hol4 | tools | entry | 122 | 4,447 | 9 | 7 | 74 | 103 | 3 | 0 | 0 | 70 | 7 | 20 | 3 | 0 | 6 | 9 |
| hol4 | tools | shared | 172 | 57,616 | 0 | 155 | 12 | 12 | 11 | 0 | 0 | 6 | 1 | 11 | 3 | 70 | 7 | 1 |
| hol4-closure | generated-theory | shared | 60 | 33,906 | 0 | 60 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| hol4-closure | kernel | shared | 14 | 4,243 | 0 | 13 | 0 | 0 | 0 | 0 | 1 | 1 | 1 | 0 | 0 | 1 | 0 | 0 |
| hol4-closure | library | entry | 1 | 466 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| hol4-closure | library | shared | 635 | 141,845 | 0 | 635 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 140 |
| hol4-closure | prelude | entry | 2 | 49 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| hol4-closure | prelude | shared | 34 | 32,444 | 0 | 33 | 0 | 0 | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 5 | 1 | 0 |
| mlton | compiler | entry | 1 | 11 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| mlton | compiler | shared | 380 | 158,995 | 0 | 380 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 17 | 1 | 0 |
| mlton | generated | shared | 6 | 19,504 | 0 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| mlton | mlton-lib | entry | 6 | 335 | 0 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| mlton | mlton-lib | shared | 187 | 18,344 | 0 | 187 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 5 | 1 | 0 |
| mlton | mlyacc | shared | 5 | 1,016 | 0 | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| mlton | stubs | shared | 21 | 859 | 0 | 21 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| polyml | source | entry | 57 | 19,939 | 3 | 34 | 11 | 18 | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 10 | 0 |
| polyml | source | shared | 113 | 32,608 | 0 | 77 | 12 | 32 | 2 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 27 | 0 |
| rune | basis | entry | 19 | 836 | 0 | 18 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 15 | 0 | 0 |
| rune | basis | shared | 259 | 25,869 | 0 | 257 | 1 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 0 | 145 | 0 | 0 |
| rune | compiler | entry | 2 | 110 | 0 | 1 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| rune | compiler | shared | 84 | 38,953 | 0 | 84 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| rune | lib | entry | 17 | 3,073 | 0 | 17 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 10 | 0 | 0 |
| rune | lib | shared | 159 | 23,405 | 0 | 159 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 26 | 0 | 0 |
| rune | lib-in-compiler | shared | 20 | 4,092 | 0 | 20 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 |
| rune | lib-other | entry | 10 | 20 | 0 | 10 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 10 | 0 | 0 |
| rune | lib-other | shared | 5 | 380 | 0 | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 5 | 0 | 0 |
| rune | lib-test | entry | 62 | 1,162 | 0 | 62 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| rune | lib-test | shared | 91 | 5,885 | 0 | 91 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| rune | src-other | entry | 27 | 924 | 0 | 0 | 5 | 22 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| rune | src-other | shared | 68 | 19,918 | 0 | 68 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| tests-lang | program | entry | 361 | 5,387 | 6 | 6 | 281 | 337 | 12 | 43 | 1 | 1 | 3 | 0 | 0 | 0 | 3 | 0 |

### C. The clash matrix and the libraries' true edges (E1)

From `results/E1/clash.csv` and `results/E1/edges.csv`, which `results/E1/census.py` makes through the compiler's own parser and `Deps`.

**Names public in two or more libraries, 15.** `clash` is a real clash. `alternatives` is between generated alternatives of one binding, never loaded together. `sets/4fcd7b` stands for a hash-named set.

| Kind | Name | Libraries | Class |
|---|---|---|---|
| signature | `HISTORY` | terminal test/runner | clash |
| structure | `History` | terminal test/runner | clash |
| structure | `RuneCompiler` | basis compiler | clash |
| signature | `SDLGENERATED` | sdl/native/sets/4fcd7b sdl/windows32/sets/680425 sdl/windows64/sets/8ea892 | alternatives |
| signature | `SDLGENERATED_LAYOUT` | sdl/native/sets/4fcd7b sdl/windows32/sets/680425 sdl/windows64/sets/8ea892 | alternatives |
| signature | `SDLGENERATED_RAW` | sdl/native/sets/4fcd7b sdl/windows32/sets/680425 sdl/windows64/sets/8ea892 | alternatives |
| signature | `WIN32GENERATED` | win32/32/sets/26ff0d win32/64/sets/a61bdf | alternatives |
| signature | `WIN32GENERATED_LAYOUT` | win32/32/sets/26ff0d win32/64/sets/a61bdf | alternatives |
| signature | `WIN32GENERATED_RAW` | win32/32/sets/26ff0d win32/64/sets/a61bdf | alternatives |
| structure | `SDLGenerated` | sdl/native/sets/4fcd7b sdl/windows32/sets/680425 sdl/windows64/sets/8ea892 | alternatives |
| structure | `SDLGeneratedLayout` | sdl/native/sets/4fcd7b sdl/windows32/sets/680425 sdl/windows64/sets/8ea892 | alternatives |
| structure | `SDLGeneratedRaw` | sdl/native/sets/4fcd7b sdl/windows32/sets/680425 sdl/windows64/sets/8ea892 | alternatives |
| structure | `Win32Generated` | win32/32/sets/26ff0d win32/64/sets/a61bdf | alternatives |
| structure | `Win32GeneratedLayout` | win32/32/sets/26ff0d win32/64/sets/a61bdf | alternatives |
| structure | `Win32GeneratedRaw` | win32/32/sets/26ff0d win32/64/sets/a61bdf | alternatives |

The real clashes' closures: `HISTORY` and `History` meet in `test/runner`'s closure, `RuneCompiler` in `compiler`'s. `lib/compiler`'s private names collide with nothing public.

**The edges between the 33 libraries, 49.** The Basis is used by all and not shown. *declared* is declared and used, 36 edges. *transitive* is used but reached only through another library, 12 edges, of which 7 hand-written and 5 generated. *UNUSED* is declared and not used, 1 edge. Names used outside the declared closure: 0. Cycles: none. Names are what make the edge; a prefix says the kind where it is not a structure.

| From | To | Edge | Names |
|---|---|---|---|
| compiler | json | declared | Json |
| compiler | unicode | declared | DisplayWidth Grapheme Identifier Normalize UnicodeSecurity Utf8 |
| dap | json | transitive | Json |
| dap | jsonrpc | declared | Framing |
| ffi/marshal | unicode | declared | Utf8 |
| ffi/model | json | declared | Json |
| ffi/model | language/c | declared | CAnalysis CDeclarator CInteger CLayout CLex CParse CPreprocess CType |
| ffi/runtime | ffi/marshal | declared | ForeignScope |
| ffi/win32/mock | ffi/win32/common | transitive | Win32Common |
| ffi/win32/mock | ffi/win32/model | declared | fun:Win32ModelFn sig:WIN32_MODEL |
| ffi/win32/model | ffi/win32/common | declared | sig:WIN32 sig:WIN32_GUI_DRIVER Win32Common |
| ffi/win32/model | unicode | declared | Utf8 |
| ffi/win32/native | ffi/marshal | transitive | ForeignBytes ForeignText |
| ffi/win32/native | ffi/runtime | declared | ForeignMemory |
| ffi/win32/native | ffi/win32/common | declared | sig:WIN32 Win32Common Win32Values |
| ffi/win32/sdldriver | ffi/marshal | transitive | ForeignBytes ForeignScope ForeignText |
| ffi/win32/sdldriver | ffi/win32/common | declared | sig:WIN32_GUI_DRIVER Win32Common |
| ffi/win32/sdldriver | sdl | declared | sig:SDL |
| json | unicode | declared | Utf8 |
| jsonrpc | json | declared | Json |
| jupyter | digest | declared | Hex HmacSha256 |
| jupyter | json | declared | Json |
| jupyter | zmtp | declared | Zmtp |
| lsp | json | transitive | Json |
| lsp | jsonrpc | declared | JsonRpc |
| lsp | unicode | declared | Utf8 |
| markdown | pretty | declared | Pretty |
| markdown | unicode | transitive | DisplayWidth Utf8 |
| pretty | unicode | declared | DisplayWidth |
| sdl | ffi/marshal | transitive | ForeignBytes ForeignScope ForeignText |
| sdl | ffi/runtime | declared | ForeignMemory ForeignOwner |
| terminal | unicode | declared | Grapheme Utf8 |
| test/property | random | declared | Random |
| test/property/basis | random | declared | Random |
| test/property/basis | test/property | declared | Arb Co Gen PropertySource Show |
| test/runner | terminal | declared | Style |
| test/runner | test/unit | declared | Test TestFilter |
| test/unit | test/property | declared | Check Prop |
| test/unit | random | UNUSED |  |
| sdl/native/sets/4fcd7b | ffi/marshal | transitive | ForeignScope ForeignText |
| sdl/native/sets/4fcd7b | ffi/runtime | declared | ForeignGenerated ForeignMemory ForeignOwner |
| sdl/windows32/sets/680425 | ffi/marshal | transitive | ForeignScope ForeignText |
| sdl/windows32/sets/680425 | ffi/runtime | declared | ForeignGenerated ForeignMemory ForeignOwner |
| sdl/windows64/sets/8ea892 | ffi/marshal | transitive | ForeignScope ForeignText |
| sdl/windows64/sets/8ea892 | ffi/runtime | declared | ForeignGenerated ForeignMemory ForeignOwner |
| win32/32/sets/26ff0d | ffi/marshal | transitive | ForeignScope ForeignText |
| win32/32/sets/26ff0d | ffi/runtime | declared | ForeignGenerated ForeignMemory ForeignOwner |
| win32/64/sets/a61bdf | ffi/marshal | transitive | ForeignScope ForeignText |
| win32/64/sets/a61bdf | ffi/runtime | declared | ForeignGenerated ForeignMemory ForeignOwner |

### D. The bugs found

One line each. "Lead" says whether the lead reproduced it on `bs-base`, apart from the agent who found it. Items marked *not master* are traps of a change this roadmap proposes or of a prototype, kept here since a later agent would meet them.

| Bug | Reproducer | Found by | Lead |
|---|---|---|---|
| `--typecheck-only --build` loses a library's exported signatures and functors: 630 false errors on MLton (`main.sml:827` returns before `logDeclared` at `:857`) | `results/E3/bugs/typecheck-units-boundary/run.sh`, `results/E9/bugs/typecheck-only-exports/` | L, S | yes |
| selection by mention: alpha-renaming a bound variable changes a program's output | `results/E3/mention/run.sh` | L | yes |
| `rune-repl`: internal compiler error on `functor F (X : S) = X and G (Y : S) = Y`, which `rune` compiles | `results/E7/bugs/repl-functor-and/m1.sml` | S | yes |
| a same-size edit moves a copied function a line: warm differs from cold, and a trace names the old line | `results/E18/bugs/inline-line/run.sh` | C | yes |
| `--functor-budget` is in no key: a hit where a miss is due | `results/E18/bugs/functor-budget/run.sh` | C | yes |
| `loadsUnits` fires on a mention: a program that names `Runtime` loses every remap hit | `results/E13/bugs/mention-runtime/run.sh` | C, M | yes |
| `--type-work` and `--match-work` are in no key: warm exits 0, cold exits 1 | `results/E18/flags/oracle2.sh`, `result2.txt` | C | no |
| a file given twice: `--units` merges its generative state, printing `10 10` where whole prints `0 10`; issue 22 in batch | `results/E16/bugs/same-file-twice/run.sh` | C | no |
| `--diagnostics=full`: warm warnings are the stored short text, 65 bytes against 123 | `results/E18/flags/oracle2.sh`, `result2.txt` | C | no |
| a second `use` bypasses a boundary, and an export naming nothing is accepted | `results/E3/holes/run.sh`, H3 | L | no |
| a program-level `type` export of a datatype leaks its constructors through replication | `results/E3/holes/run.sh`, H2h | L | no |
| whole and units disagree on a boundary over the Basis; unreachable today, since the Basis has none | `results/E3/basis-boundary.sh` | L | no |
| a stale MANIFEST gives 6 silent wrong answers in 15 scenarios, 4 invisible to `--basis-check` | `results/E2/stale.sh` | L | no |
| `install.sh` with no MANIFEST exits 0, having installed 89 of 822 files and no Basis | `results/E28/tool/install-check.sh` | L, P | no |
| `--basis-index` does not notice a name hidden by a dependency's boundary | `results/E28/tool/rebase2.sh`, section G; `results/E28/rebase/run2.out` | P | no |
| a relative path variable serves one directory: 4 tracked builds work only with an absolute value | `results/E12/check.tsv`, the INVALID rows; `results/E12/run-check-abs.sh` | P | no |
| `--build-list` omits the closure: 23 files against 157 on `runelsp.build` | `results/E12/run-flat.sh`, `flat/summary.tsv` | P | no |
| the Win32 generate driver exits 1 when an old set remains (`tests/ffi/win32/native/check.sml:45`) | `results/E28/tool/regen.sh`, `regen/run.out` | P | no |
| `Config.identity` has never covered the main file or `build/config.sml`; nor `lib/basis`, by reading | `results/E12/run-flat.sh`, `flat/summary.tsv` | P | no |
| `--typecheck-only` and analysis refuse a program that compiles and runs: `constructor 256 of t is past what a descriptor can build` | `results/E17/bugs/open-constructors-typecheck/` | U | no |
| analysis is quadratic in a unit's declarations (`Env.plus`); fix in `patches/E20-env-plus-origins.patch` | `results/E20/quadratic/run.py` | A | no |
| a large top-level declaration kills the worker: the VM aborts on equality work, uncatchably | `results/E20/bugs/equality-work/` | A | no |
| `configurationFor` makes membership quadratic: 29 ms per call at 1,001 entries | `results/E20/plan.sh`, `plan/f100k-en.jsonl` | A | no |
| `-j` makes a `--build` slower on small units, and a no-op slower: 12.75G against 9.71G | `results/E21/parallel-min.sh`, `results/E15/base/rune-noop-j4/` | A, C | no |
| one type prints as `SML90.instream` or `TextIO.instream` by which Basis files mention selected | `results/E22/run.sh`, `summary-repo.txt` | A | no |
| `tests/lsp/project-replay.sml:61` fails on master: the position it asserts moved | `results/E20/NOTES.md` | A | no |
| `Deps` parses with `Fixity.initial`, so a graph can come from a wrong parse: `--deps` stops on HOL's `Conv.sml` | `results/E8/deps-hol.err` | S | no |
| `.build`'s `use` elaborates in the caller's basis, an `.mlb` in an empty one, so `docs/build.md`'s "MLB's semantics" is wrong there | `results/E9/mlton-run2/build.err` | S | no |
| a stale document: `SCENARIOS.md` S7's first half; issue 11; issue 23's "a batch build never has two units of one name" | `results/E18/bugs/README.md`, `results/E19/code-rw.txt` | C | no |
| completion in an early file re-elaborates every later unit: 2.35 s against 0.012 s | `results/E23/bugs/README.md`, 1 | E | no |
| a `discover` job runs `enrich` before every check (`src/lsp/worker.sml:45-48`): 19.1 s a leaf at 117k lines with a target | `results/E23/bugs/README.md`, 2 | E | no |
| half of `rune.build`'s leaf is GC at the 512 MiB cap: 1.0 s against 0.48 s at 2 GiB | `results/E23/bugs/README.md`, 3 | E | no |
| one progress message per input per check | `results/E23/bugs/README.md`, 4 | E | no |
| `register` is quadratic in units (`unitbasis.sml:163-170`), by reading | `results/E23/bugs/README.md`, 5 | E | no |
| `Env.pathOf` per tycon is O(top-level structures), and a printed path depends on the environment | `results/E23/bugs/README.md`, 6 | E | no |
| every hover filters all occurrences (`src/lsp/worker-analysis.sml:140-144`) | `results/E23/bugs/README.md`, 7 | E | no |
| `syntaxAt` per input is quadratic (`src/lsp/worker-analysis.sml:285`) | `results/E23/bugs/README.md`, 8 | E | no |
| *not master:* `rune.build` through `libraries` loses 19 files from the awk's list, and B takes A's entry | `results/E12/d14/run2.sh` | P | no |
| *not master:* a client's diagnostic reads a layout, so analysis with the ABI blank misses an error | `results/E17/probes/leak-layout`, `results/E17/leaks.sh` | U | no |
| *not master:* a datatype behind `:>` in a functor body moves `fun F`'s static hash; sound, but spurious | `results/E17/probes/leak-generated`, `results/E17/leaks.sh` | U | no |
| *not master:* a boundary merges cleanly into a branch and hides what the branch added | `results/E28/tool/rebase2.sh`, `rebase/run2.out` | P | no |
| *not master:* a unit captured after expand over a frozen Basis at ToMid: `global 21 read before initialization` | `results/E14/bugs/mixed-capture.md` | M | no |

### E. The order of MANIFEST's removal (E28)

From `results/E28/install/ORDER.md`. Each step leaves master working with MANIFEST still present.

The key fact: every `.sml` under a library directory is in its MANIFEST, 702 listed, and only 5 on disk are unlisted, all `export.sml` of generated sets, which install copies anyway. So install needs no list and no reader of `.build`: for each directory with a `library.build`, copy `*.sml`, `README.md` and `library.build`, keeping subdirectories and stopping at nested libraries.

0. **Today, independent of everything:** `install.sh` refuses to finish when it installed no `lib/basis`. One line (D13; `results/E28/tool/install-check.sh`). `tests/runner/installchecks.sml:45` has the same loop as `scripts/install.sh:300`, so its comparison of installed libraries passes vacuously.
1. **Install and dist.** `install.sh`, `tools/builder/dist.sml:13-27` and `installchecks.sml` key on `library.build`, not MANIFEST, and copy `library.build` too. `dist.sml` already walks it. This is additive: the install layout gains the build files. `tools/builder/vscode.sml:74-78` and `tests/runner/vscodechecks.sml:14` likewise for `lib/basis`; `vscodechecks.sml:37` plants `lib/basis/stray.sml` as excluded, against copying `*.sml`, and changes with it.
2. **One module holds the index.** `basisIndex` moves out of `main.sml:338-436` into `lib/compiler/driver`, beside `BasisManifest`, with `Deps` reachable from `runedoc`'s build, since `frontend.build` lacks `deps.sml` today. `--basis-check`'s two checks move with it.
3. **Readers of the table as text** become readers of that module, or of `rune --build-list` with the closure:
   - `tools/generate/host-basis.sml:36` (the host column), `tools/generate/flatten.sml:63`, `tools/generate/signatures.sml:28`, `tools/generate/xc2-poly.sml:41`;
   - `tests/runner/hosts.sml:36-45` (host and provides columns);
   - `tests/runner/matrixprepare.sml:14` and `tools/measure/basics.sml:60-61`, which only hash the file: `basics.sml` skips silently when it is absent, the same class as `install.sh`;
   - `tests/ffi/performance-check.sml:57`, which filters by name, silently.
4. **The compiler, the LSP's analysis (prelude), `select`, `-j` and `runedoc`** read the module's value, wherever it is stored (D24). The LSP's watcher (`lsp/controller.sml:75`, `lsp/worker-analysis.sml:397,414`) changes its glob, and `tests/runner/buildchecks.sml` reads and rewrites the file (`:73`, `:138`, `:169-177`, `:205`).
5. **Stage 0:** `Makefile:1889-1897`, then the 28 `lib/*/MANIFEST` rules and the generated sets' one (`Makefile:430-501`), and the dependencies of `lib/cache/made` and `bin/rune.rbc`.
6. **Fixtures:** the 21 files of E28, and 7 test programs that write a MANIFEST inline: `tests/lib/compiler/{analysis,api}.sml`, `tests/lsp/{distribution,semantic-protocol}-tests.sml`, `tests/runner/{distchecks,vscodechecks,benchmarkfaults}.sml`.
7. **The rest:** a `.gitignore` line, the documents (`rune.1`, `runedoc.1`, `docs/build.md`, completions), and usage text (`# library:` in `src/doc/docmain.sml:24`).

These are not MANIFESTs of this kind: `DISTMANIFEST` (`scripts/dist-*`) and `cloud/cache/MANIFEST` (`scripts/cloud-cache.sh`).

### F. The mutants that survive (E18)

From `results/E18/mutants/table.md`: 13 of 37 mutants are caught by none of scenarios, `mutate`, `soundness.sml`, the deep mask, `--verify-cache`, fact edits, S42 or the flags oracle. The control passes them all. `results/E18/mutants/list.py` holds each mutant's exact text.

The last column is judgement by reading, from `results/E18/SUMMARY.md`. "None recorded" means nobody has argued the mutant harmless, so it stands as a gap in the checks. A pass in E18 means the checks ran on small projects, nothing more.

| Mutant | What it does | File | Issue | Judgement |
|---|---|---|---:|---|
| F1 | `fpVal`: `primAliases` dropped | `unitbasis.sml` | | none recorded |
| F4 | `fpVal`: `primGlobals` dropped | `unitbasis.sml` | | none recorded |
| F5 | `fpVal`: which value dropped (the anchor) | `unitbasis.sml` | 8 | needs a remap that lookup by name refuses: a moved value's old unit is not there |
| F6 | `fpVal`: a constructor's tag dropped | `unitbasis.sml` | | looks equivalent: a definition's constructors are hashed in order |
| F9 | definition: a type name's equality dropped | `unitbasis.sml` | 16 | none recorded |
| U4 | usage: a marked functor's Mid (`inl`) not recorded | `lib/compiler/elab/elaborate.sml` | | not a name, so the mask cannot see it: it needs a mask of its table |
| K1 | key: `allow` dropped | `unitcache.sml` | | none recorded |
| K5 | configuration: the inlined functions dropped | `unitcache.sml` | | none recorded |
| C1 | broken: a unit still in the session no bar to a fingerprint | `unitbasis.sml` | 21, 23 | needs two units of one name, so a mutant REPL; the scenarios ran with a stock `rune-repl` |
| C3 | absent: the units an entry's code names not looked for | `unitbasis.sml` | 4 | reachable only once a usage is missed |
| C6 | a unit that keeps identities taken across a change | `unitcache.sml` | 15 | looks equivalent: remapping returns `[]` first and `absent` then refuses, so the guard is doubled |
| C9 | a signature's usage fingerprinted after the unit | `unitbasis.sml` | 17 | none recorded |
| M2 | `UnitMid`: the layouts a body fixed not kept | `unitmid.sml` | | none recorded |

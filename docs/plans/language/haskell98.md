# Roadmap: rhc, a Haskell 98 compiler on Rune's back end

**The owner decided this roadmap on 2026-11-09, and answered the lead's questions on 2026-11-10. rhc lowers a lazy typed Core of its own to Rune's Mid, where a lazy position has the abstract type `susp T` and force is one node, lowered to form C: a flat `K_THUNK` and four instructions, `FORCE`, `ENTER`, `BLACKHOLE` and `UPDATE`, on both bytecodes. Mid's `Ty` gains variable-headed application and a forall, and Mid gains a `Case`. `IntInf` takes the immediate representation, which rhc's `Integer` shares, and `IO` passes a state token. Mid's pass list becomes data, and rhc links a layer of `lib/compiler` with no front end in it. These change Rune more than the recommendations did, and each says by how much under the standing gate. Nine options are still to be measured, and the owner decides them on the figures: D3's `Force` right-hand side, multi-value return, eval/apply, pointer code 11, selector thunks, CAF tables, two forms of string literal, Sestoft-order trees and GHC's eta. Each is built and measured on the register VM first, and taken to the stack VM, runeopt and the other platforms only once the owner adopts it (*Decisions on the numbers*).**
- **The hook is Mid,** beneath a lazy typed Core that rhc owns. Hand-written Mid for knot-tied lists, mutually recursive CAFs, monad dictionaries and polymorphic recursion ran on both bytecode VMs and their tiers, not in native code, two of its ten programs only with D5's Simplify fixes (E1).
- **A thunk is a flat `K_THUNK`, and force is one Mid node lowered to `FORCE`** (D3, D11, D13). Form C is the base of E2's ratios. Rune could have hosted Haskell with no new instruction and no new kind of object: form G, a marked closure with force lowered to a test, a value read and `CALL`, cost 1.05 of form C on 113 lazy programs and 1.02-1.22 on output shaped as rhc's will be (E2, E5). The owner took C as "cleanest and most performant". The stack bytecode takes the instructions too, about 115 lines more [estimate] (D14).
- **Mid stays strict,** and a lazy position has a type of its own. That is what keeps its passes safe and tier 2 from reading a thunk blind. With casts erased a forgotten force is a fatal rather than a wrong answer, and in a function-typed slot `CALL` stops a `K_THUNK` (D4, D11). With `Ty` extended, `Any` is left for what `Ty` cannot say (D4).
- **rhc's cost, before any optimiser:** 3.4 to 5.2 times `ghc -O0` on three whole programs, 13 to 23 on Prelude-bound kernels, in instructions at tier 2. That is the kindest measure: in cycles the same runs give 5.8 to 7.0 and 18.8 to 42.8, and against `ghc -O2` the whole programs are 4.5 to 49.5. Four optimisations in Core take whole programs to 1.3 to 3.7 at Rune `-O2` (E5). These rest on hand-lowering, not on a compiler.
- **The store rhc needs has landed** with build-system-v2, built from E13's split: rhc writes its own format, head, key and settings, with no change to Rune (D43). On a toy language with no front end, one unit per module cycle cost the store and the linker nothing (E13).
- **The Report has been read clause by clause:** 3,901 rows, 54 readings, 16 of 18 errata unapplied in the text the brief links (E9). All three oracles now run. Of 82 conformance tests 48 show a disagreement, counting MicroHs and the expected result: 20 hard, 16 not Haskell 98, 7 oracle gaps, 5 environment (E7).
- **The Report's own recursive libraries are compiled as they stand (D36).** Its 11-module cycle is mostly scoping: no binding group crosses a module, though one type group needs kind inference across Prelude and Ratio and one expression depends on defaulting. The recursive-module work lands in the front end before the Prelude (M12, M13) and needs no cache, and a mechanical fallback exists: a small tool can derive the merged layout if the joined checker runs late (E16).
- **Lazy ML works on the same thunks.** All 10 of the spec's programs pass with no line changed in a Mid pass and no Core. It found a collector fault Haskell cannot reach, which would have stayed hidden had this roadmap stopped at Haskell (E14). It ran on form G, so M26 runs the checklist again on form C (D57).

**In what order: build-system-v2 is done.** It landed in origin/master `697724da5`, and implementation starts there. rhc's six questions of it were taken with a second language in view, and rhc uses its store, its friends and its identity per compiler (*What build-system-v2 gave rhc*). What may start at once: M1 to M8, M9 without D3's measured variant, and M31; then M28, M29 and M30's build for measurement after M6's walkers, and the rest as *The order* gives it.

This roadmap plans eight tracks:
- **T, tests:** the conformance table, the runners, the oracles, the corpus.
- **A, Rune's contract:** E11's patches, the pass list as data among them, Mid to bytecode, walkers and a fold, lints, and the owner's changes to `Ty`, Mid's `Case` and `IntInf`; multi-value return is built there to be measured. They stand on their own, whatever becomes of rhc.
- **B, back:** Core, thunks through the engines, Core to Mid.
- **F, front:** parser, modules, the checker, deriving, desugaring, HsLint.
- **L, libraries:** the Report's Prelude and libraries.
- **S, separate compilation:** HsIface and rhc's driver on the landed store, keys over a cycle.
- **P, optimisation:** the first Core optimiser.
- **Z, lazy ML:** a checklist that has been run.

**It recommends against five things the brief proposes or expects:**
- **Lambda as the hook:** it is not close to Core, and no optional pass runs on it (W1).
- **Separate compilation as the biggest decision:** the laziness boundary is harder to reverse (W5).
- **Haskell first as enough for lazy ML:** Haskell cannot reach two collector faults that lazy ML does (W6).
- **`K_THUNK` and a force instruction,** expected since the heap-layout roadmap: neither is needed (D11, D13). The owner took both.
- **The nofib left for this work as the corpus:** nhc98's older snapshot is the better one, though the brief's is closer than it looks (W7).

**Five questions were the owner's, needing a judgement rather than evidence, and the owner has answered them:**
- **G0** (D1-D6, D11-D13, D36): Mid beneath rhc's Core; `susp` an abstract tycon and force one node, lowered to form C's instructions, with a `Force` right-hand side built and measured against it; `Ty` extended; the evaluated invariant written and linted, with a checked `Any` in checked builds only; recursion through a cell; the Report's library layout.
- **Where the Report and every implementation part:** the text, with the one rule. R1, R2 and R5 depart, each with its ground, and `Just.let`, R21(b) and R38 follow the text (D38).
- **`default` and Rule 2 in a module cycle:** each module its own `default`, and Rule 2 closing at the end of each module, as recommended. At the owner's request an option, `--cycle-default=scc`, gives one `default` per SCC and the SCC's end, an extension off by default (D30); another, `--names=greatest`, gives the greatest fixpoint of names (D29).
- **Blackholing:** not applicable. Form C blackholes at entry, so re-entry is found at once and the captures are released then (D12).
- **A Rune-only `lib/language/haskell`:** Rune alone is required, other hosts informational, with the exception to the library rule written down (D42).

**What is not established.** No prototype has been through `make check`, or on aarch64, 32-bit, PowerPC or Windows. rhc's compile time and space behaviour are unknown, the front end's 12-20k lines are an estimate, and K rests on three hand-lowered programs and four kernels with no `Read` and no real `IO`. Form C's figures in E2 come from one prototype stage, `bin10`, which V2 reran on G's stage, `bin12`, with `--count` identical; form C never ran on the stack VM or in native code. The lazy ML checklist (D57) ran on form G. None of the changes to Mid's IR was built, neither D4, D8 and D10, which the owner took, nor D9's multi-value return, which is to be measured: each is sized by E4's or E12's counts alone.

Writing it found 8 defects, two of them live on master and reproduced by hand: `=` on a non-uniform datatype overflows the compiler's stack at `-O2`, and an unknown pass name is silently accepted (*Found while writing*).

It was written on 2026-11-01 against master `b12141ecc`, and its citations stay against that tree; a citation of origin/master `697724da5` says so. It lives in a worktree, on branch `haskell98`.

What it rests on:
- **The code:** a reading of the IRs, the runtime, the pipeline, the units and the tests (*Where we are*).
- **The Report,** clause by clause, with 17 further probes on the oracles (*What the Report says*).
- **Sixteen experiments** (*The experiments*):
  - Mid as a target, thunks on the real engines, `Any`, `Integer` and dictionaries, lazy ML (E1, E2, E4, E5, E14);
  - what real lazy code does, what cross-module information buys (E3, E6);
  - the oracles, the corpus, the Report (E7, E8, E9);
  - the parser and the layout rule, the literal layout (E10, E16);
  - pipeline as data, the IR census, the store (E11, E12, E13);
  - the literature and ten implementations (E15).
- **Real corpora:** 3,089 candidates judged by three oracles, 1,723 files through a real parser, and 113 lazy programs on every thunk form.
- **Throwaway prototypes,** kept as patches: every thunk form on the engines, a Mid unit, a pipeline client with no front end, a store with a toy language on it, a parser, and lazy ML.

## Status

Decided on 2026-11-09, with the owner's answers of 2026-11-10. Implementation began on 2026-11-10 on branch `haskell98`, from origin/master `697724da5`: each milestone is built on a branch of its own and merged into `haskell98`, which `make check` runs in a fresh tree after the merges. "Green" names the merge on which `make check` last passed; "on X" means `make check` ran on merge X with no failure of that milestone's. On `a39edfc34`, 27,953 tests: 27,919 pass, 33 held, no failure, and one timeout under load, `make/test-lsp-oracle`, which runs 1.018 times master's instructions for 3.4% more source and passes alone. G1 passed on 2026-11-10 under form C: 546 of the 555 clause programs print the same on Core's interpreter and on the VM, from the saved world and compiled whole alike. The decisions are in the table at the head of *Decisions*, and the six still to be taken on the figures in *Decisions on the numbers* (D3, D9 and D16 were taken on them on 2026-11-10).

| Milestone | Track | Size | Rests on | Status |
|---|---|---|---|---|
| M1. The conformance table and its enforcement | T | M | D38, D53 | done; green on `6793f7ee1` (23,523 tests) and on `57a5306a4` |
| M2. Runners generalised; round-trip harness | T | M | D28 | done; green on `6793f7ee1` and `57a5306a4` |
| M3. Oracle harness and the corpus imported | T | L | D52 | done: oracle harness, E7's and E8's data, all 188 of D56's programs vendored (45 under their LICENSE, 143 under a PROVENANCE, by the owner's rules of 2026-11-10) |
| M4. Rune's contract: E11's patches, as decided | A | L | D7, D39, D40, D41 | done; green on `6793f7ee1` and `57a5306a4` |
| M5. Mid to bytecode, Mid text with labels | A | S | D1, D26 | done; green on `6793f7ee1` and `57a5306a4` |
| M6. Walkers and a fold | A | M | D10 | done, every budget recovered (the compiler's own compile 3.2% fewer instructions than before M6); on `57a5306a4` |
| M7. Lints and the two Simplify fixes | A | S | D5 | done; on `57a5306a4` |
| M8. Core, its text, CoreLint, a Core interpreter | B | L | D2, D41 | done; on `57a5306a4` |
| M9. Thunks through the engines | B | L | D3-D6, D11-D14, D18, D19, D57 | done: form C on both instruction sets, every engine and tier; 115 of 115 lazy ports; bytes held but the fingerprint; re-entry of a suspension under evaluation raised as an exception, so a determined bottom ends with status 1 on every engine. Departure: the stack VM still retains `last`'s dead suspension (the owner's list) |
| M10. Core to Mid | B | L | D3-D6, D8, D9, D25 | done on form C, writing Mid's `Case` and M28's types, by units as well as whole; G1 passed on it. Under way: the rule that no `susp` heads a type argument, checked in Core to Mid at lint level 2 (MidLint cannot hold it, since SML uses polymorphic functions at `T susp`) |
| M11. Lexer, layout, parser, printers | F | L | D27, D28 | done; on `57a5306a4` |
| M12. Renamer, modules, fixity, recursive modules | F | L | D29, D30, D35, D36 | done; on `57a5306a4` |
| M13. Kinds, types, classes | F | L | D30, D31, D32, D33 | done: the Report's 20 modules and the 11-module unit check; 798 of 808 corpus programs; a declaration group's unsigned bindings typed as one, as 4.4.1 and 4.5.1 read, which refuses six corpus programs by 4.5.2 as the Report does; on `a39edfc34` |
| M14. Deriving | F | M | D33 | done; on `0f44dafbe` |
| M15. Desugaring to Core | F | L | D17, D34 | done: 546 of 555 clause programs agree on Core's interpreter and the VM; the library's Core and a program's desugared apart; on `0f44dafbe`. Under way: Core units by binding group |
| M16. HsLint | F | L | D54 | done: the second inference, replay of Faxén's rules, two judges held to one verdict, and the target check of the Core against the source types, which names the pass that broke it; M16's seeds caught; on `a39edfc34`. Under way: G2's lint and mutant lines, and HsLint's library inference kept in the saved world |
| M17. The Prelude: primitives, overlay | L | L | D20-D26, D36, D37 | done: the overlay as code over rhc's runtime, the token comparison with the Report, the 15 bottom probes right on the interpreter and the VM; on `0f44dafbe` |
| M18. The Report's libraries | L | M | D36 | done: the 20 modules compile and run, the 52 examples are programs; `ReadWriteMode` by the owner's word of 2026-11-10; `ExitFailure 0` an error; on `a39edfc34`. Under way: a full device reported as an error in Rune's runtime, by the owner's choice of 2026-11-12, `BlockBuffering`'s size honoured, and 21.6's discard of an input buffer |
| M19. Conformance: the table worked through | T | L | D52, D55, D56 | under way: 3,885 of 3,901 rows Supported, 16 Planned, each waiting on a named piece of work; four deviations recorded, each on a ground of D38's; the harness of D55 and D56's tiers in place |
| M20. The store's policy out of `UnitCache`, optional | S | S | D43 | done; on `0f44dafbe` |
| M21. HsIface and rhc's driver | S | L | D43, D44, D45 | under way: HsIface and its codec; `rhc --units FILE.hs`, each group of the module graph checked from the interfaces before it and kept in the store, its output byte for byte the whole compile's; the link joins the units' Core, keeps what `main` reaches and compiles it whole, behind a memo. A warm compile still costs more than a whole one (hello: 499M instructions edited, 145M whole), and the remedies are being built |
| M22. SCC keys | S | M | D30, D36 | not started |
| M23. Core simplifier, known dictionaries | P | L | D47, D48, D49 | built on its branch, to merge after G2 |
| M24. Strictness | P | M | D50 | not started |
| M25. What measurement justifies | P | | D15-D17, D19, D51 | under way: D3, D9 and D16 measured and decided; D15's C, D17's B and D19's B being measured; D24's and D34's first figures in |
| M26. Ready for lazy ML | Z | | D57 | not started |
| M27. Retire | | S | | not started |
| M28. `Ty` with application and forall | A | L | D4 | done; on `57a5306a4` |
| M29. Mid `Case` | A | L | D8 | done; on `0f44dafbe` |
| M30. Multi-value return, built to be measured | A | L | D9 | built and measured on `hs-a-m30`; the owner took A (2026-11-10), so it does not land |
| M31. `IntInf` immediate | A | M | D20 | done; on `57a5306a4` |

Gates: G0, the owner's decisions, passed on 2026-11-09; G1, hello on the interpreter and the VM, passed on 2026-11-10; G2, the Report's exit; and a standing gate on SML's budgets and bytes. M19 runs on a frozen Prelude, the saved world until M21, with M20 and M21 beside it and not gating it, and M22 comes before G2.

## Found while writing this roadmap

Every defect has a reproducer: *Appendix: defects* lists them. Those marked *reproduced* were run again by hand on `b12141ecc`.

**Wrong behaviour in the compiler**
- **`=` on a non-uniform datatype overflows the compiler's stack at `-O2`,** on plain Standard ML: `datatype 'a nest = N | C of 'a * ('a * 'a) nest`. `-O0` compiles it. `eqFunOf` makes a new function per type, without bound (`lib/compiler/core/simplify.sml:349-354`; E1; *reproduced*).
- **An unknown pass name is accepted.** `--passes=nosuchpass` exits 0 and silently runs no optional pass; `--dump-after=nosuchpass` prints nothing (E11; *reproduced*).

**Latent: nothing reaches these today, and rhc or lazy ML would**
- **`specialise` breaks polymorphic recursion.** `makeCopy` turns every self-call into the copy, ignoring type arguments, so at the default lint level the compiler makes ill-typed Mid and says nothing (`lib/compiler/core/simplify.sml:1182`, `:896`; E1). Comparing the arguments alone makes it diverge. No SML source reaches it.
- **Lower stops on a local function of two parameters at `-O0`,** which MidLint accepts and the front-end contract allows. Reachable only with `E1-readmid.patch`: on stock master `--read-mid` stops after the check, before Lower (E5; V1 ran `repro.mid` at `-O0` and `-O1`, exit 0 and no `.rbc`).
- **The collector takes an indirection as final** (`runtime/gc/minor.c:151`, `runtime/gc/mark.c:155`). For `'a susp susp` that runs an inner suspension early (E2); for a lazy ML body that outlives its own update it corrupts memory or silently gives the wrong value (E14). 162 of 1,302 runs failed on E2's collector.
- **`share.c` and `image.c` mishandle `K_IND`** in fields and frames (E2).
- **A step of Simplify leaves a call of a local function it dropped.** Seen only with E2's prims, so it may be the prototype's fault: not reproduced on stock (E2).

**In the Report** (*What the Report says*)
- The text at the URL the brief gives has 16 of 18 published errata unapplied.
- Its own code is an 11-module cycle containing the Prelude, which chapter 8 calls presentational; `Char` and `Numeric` import each other with no such disclaimer.
- Eight names in that code do not resolve as printed: four in `interact`, from a revision of late 2001, and `numericEnum*` in `Ratio`, as its own comment admits.
- `import List((\\))` in `Array` is dead since a rewrite of `//` that is in no change list (E16).
- Section 5 does not say which fixpoint it means, and a user module defining `map` gives two (E16).
- `[LT..]`, the Report's own example, does not lex by its own table (R7).

**In the other implementations**
- GHC's `-XHaskell98` enables `NondecreasingIndentation` and misreads the spacing of `@ ~ !`, and 9.4.7 reads `(!1)` as a bang (E7, E10).
- **Boot files cannot express every legal cycle:** two boots whose signatures name each other's types must import each other (E15; an argument, and one tested arrangement with boots).
- Nobody has compiled the Report's libraries in its own layout, as far as a search shows. Programatica type-checks them, and it adds no signature and moves no definition to do so (E16).
- `haskell-src-exts` defaults to Haskell 2010, not 98, against the survey (E15).

**What published statements say that is not so**
- `docs/plans/heap-layout.md:4999`: `Integer`'s small values are immediate. They are boxed (E5). `:1207` gives `K_THUNK` and `K_IND` as 12 and 13; they are 14 and 15.
- `examples/benchmarks/shared/lazy.sml` memoises exceptions and detects re-entry, which matches neither language, and 114 of 115 `-lazy` ports go through it (E2).
- `docs/units.md:637,704` name two scripts that do not exist. `docs/testing.md:434` cites `runtime/runtime.c:285`, where `--count` prints at `:421`. `lib/unicode/library.build` names `scripts/gen-unicode-tables.py`, which does not exist.

## The request

The owner's brief, as written. It is `docs/plans/language/haskell98.md` on master with the owner's uncommitted edits, which this roadmap replaces on its branch:

> - this is a draft roadmap to add a haskell 98 compiler to rune
> - haskell 98 will be support by an rhc program seprate from rune
>   - rhc will be implemented in sml97 / rune not in haskell 98
>   - rhc is a second class citizen compared to rune. i.e. no language server, repl, runedoc etc.
>     - do design a large test suite (accept/reject and all the other goodness we have for rune)
>       - add an independent type checking lint pass as for sml 97
>       - ast pretty printer to check round tripping
>       - a corpus of fully haskell 98 compliant programs may be hard to find. i have left nofib under /home/ruud/haskell/nofib. but give no guarantee that all or even any are exactly haskell 98 as per the revised report.
>     - we do want separate / incremental compilation under rhc. this may be the biggest design decision. can we re-use the rune separate compilation build cache for this? and without changes or with only changes that are a clear improvement for rune as well? or are bigger changes needed? and should we do a separate incremental compilation system for rhc in that case?
>       - please review docs/plans/build-system/build-system-v2.md on the build-system-v2 worktree (i.e. the full plan not the draft on the main tree) to see if any of this work should be done before this roadmap. this will decide the order in which which we do the roadmaps.
>   - rhc will use lib/compiler. rhc's frontend will live under lib/language/haskell. the driver under src/rhc
>     - lib/language/haskell may also be used for other tools than rhc in the future to analyze and process haskell source code
>   - the key decision will be where to hook the two up together
>     - lib/language/haskell will have its own lexer, parser, ast, type checker and elaborator (e.g. type class to dictionary transformation)
>     - lambda, mid are the obvious candidates. low a less obvious candidate. lambda should be conceptually close to GHC's Core. evaluation strategy would differ but it is not clear to me how that impacts this IR. perhaps some optimization passes are valid under a non-strict evaluation strategy and not under a strict evaluation strategy (or vice versa). but not clear if that impacts the design of the IR itself rather than the optimization passes rhc will plug into the compiler pipeline.
>     - analyze the changes needed to rune's lambda, mid, low, bytecode and vm. each change should be a decision in the roadmap (e.g. large change that is optimal for haskell, mid-sized change that works for haskell and is also a good thing for rune/sml97, a small change that haskell can live with minimizes the changes to rune, a limited/no changes that keeps rune the same but rhc would have to workaround in some way). basically: no silent changes to rune to support rhc.
>     - one of the reasons to do rhc/haskell98 now is to prepare rune for a lazy evaluation extensions (in the style of sml/nj's lazy ml). doing haskell first ensures the whole stack supports lazy evalaution properly and the lazy ml can be a properly supported language extension to rune later
>     - also use this roadmap to improve the overall architecture of the rune compiler and lib/compiler. ensure everything is abstracted properly so compiler passes can be assembled in a clean, efficieny, correct and testable pipeline easily. and so e.g. optimization passes can be swapped in and out cleanly in the future.
>       - it should also include a review of the various intermediate representations to make sure they all make sense overall: split between the IRs and the contructs available (or not available) in each.
> - the language target is haskell 98 as per the revised report
>   - https://www.haskell.org/onlinereport/
>   - the Prelude and other modules of the haskell 98 standard library are also discussed in the report.
>     - we should include those under share/rhc/haskell98 (as this is haskell code, lib only has sml97 code)
>   - ghc, hugs and haskell-srcs-exts are available under /home/ruud/haskell for study. they can be used as oracles but may deviate from the report
>   - ghc is not written in haskell 98 so compiling it with rhc will not be achievable in this roadmap
>   - hugs may be written in haskell 98?
>   - adding language extensions will a follow-up roadmap. to not a goal here, but keep it in mind.
>   - i think haskell 98 only needs a unification based type inferences. so no hm(x)/outsidein(x) needed. in the future we may add a second hm(x)/outsidein(x) based type inferencer to support modern haskell, but this is not a goal of this roadmap.
>     - haskell2010 will be a future language mode of rhc. not a goal of this roadmap.
>     - then later feature parity with current ghc
> - as always study the academic literature and existing implemenations thoroughly.
>   - another agent produced a haskell 98 compatibility study under haskell98-compatibility.md
>     - rhc intends to follow the haskell 98 revised report to the same extent that rune follows the sml 97 definition (with documented deviations only where the report is wrong, contradictory, ambiguous and always documented and pinned by tests)

The owner added one direction while this roadmap was being written, on 2026-11-01, after the Report's recursive module graph had come to light:

> since i'm interested in make a compiler close to the report it is very likely we'll support recurisve modules then and may also follow the report on its recursive structures. so these should be possible decions in the roadmap

D30 and D36 are those decisions. Where convenience and the Report's text pull apart, this roadmap leans to the text and states what that costs.

The owner decided on 2026-11-09, in this message:

> - the new build system has landed in origin/master. please work from origin/master when starting the implementation
> - the missing references are available at /mnt/h/Rune/haskell98. let me know if you still miss anything. let me know if this changes any recommendations.
> - please record my decisions as follow and let me know if you have any objections:
> - D1: A (as recommended)
> - D2: C (as recommended)
> - D3: B but with form C instead of form G. please also build C (a Force right-hand side) and benchmark it against B with form C.
> - D4: C (safest and also useful for higher-rank and higher-kinded type in rune)
> - D5: B (as recommended) (an C for checked builds/vms only if no perfomance impact on non-checked versions)
> - D6: A (as recommended). For the D3 = C (a Force right-hand side) variant please us C (a recursive form in Mid)
> - D7: B (as recommended)
> - D8: C (let's fix it now instead of later)
> - D9: B (let's do it now instead of later)
> - D10: C (let's fix it now instead of later)
> - D11: C: flat K_THUNK, four instructions (cleanest and most performant)
> - D12: n/a (I decided on Form C)
> - D13: C
> - D14: B if it doesn't leak into Low; otherwise C
> - D15: please build C and benchmark how it fares on rhc (and rune if that applies). then we decide if we take it over A based on the numbers.
> - D16: please build B and benchmark how it fares on rhc (and rune if that applies). then we decide if we take it over A based on the numbers.
> - D17: please build B and benchmark how it fares on rhc (and rune if that applies). then we decide if we take it over A based on the numbers.
> - D18: A (as recommended)
> - D19: please build B and benchmark how it fares on rhc. then we decide if we take it over A based on the numbers.
> - D20: D (rune should benefit from this)
> - D21: Representation: A; Tables: D (as recommended)
> - D22: A (as recommended)
> - D23: B (as recommended)
> - D24: A (as recommended) please also build and benchmark B and D but we are unlikely to take D even if it wins as there is no use in rune. just for the record.
> - D25: B (we will do Haskell2010 in the next roadmap)
> - D26: A (please port IntInf if we need it; Haskell/SML interop is a future roadmap)
> - D27: A (as recommended)
> - D28: C
> - D29: A (as recommended) but can we make least/greatest fixpoint a language/compiler option please as we did in rune for some of the sml97 ambiguities
> - D30: A & Each module its own default (both as recommended) but can we make default per module/per scc a language/compiler option please as we did in rune for some of the sml97 ambiguities
> - D31: A (as recommended)
> - D32: as recommended
> - D33: C
> - D34: please build B and benchmark how it fares on rhc. then we decide if we take it over A based on the numbers.
> - D35: B (as recommended)
> - D36: A (as recommended)
> - D37: Code: B and License: A (as recommended)
> - D38: B (as recommendad)
> - D39: D (leave it)
> - D40: B and C (as recommended)
> - D41: please review what build-system-v2 has changed and you decide based on that
> - D42: C (as recommended)
> - D43: please review what build-system-v2 has changed and you decide based on that
> - D44: C (as recommended)
> - D45: A, with B until M21 lands (as recommended)
> - D46: n/a (build-system-v2 is done)
> - D47: C (as recommended)
> - D48: C (as recommended) please also build D and benchmark it against C
> - D49: C (as recommended)
> - D50: C (as recommended)
> - D51: C (as recommended)
> - D52: C (as recommended)
> - D53: C (as recommended)
> - D54: C
> - D55: B (as recommended)
> - D56: B (as recommended)
> - D57: C (as recommended)

The decisions are recorded in *Decisions*: at the end of each section, and in the table at its head.

The owner answered the lead's questions on 2026-11-10, in this message:

> - D39: change to C
> - D9: land behind a measurement
> - "Build and benchmark": build on regisiter  vm only first and the rest only after after adoption
> - D14: C

These answers are recorded in *Decisions*, in D9, D14, D39 and D41, and in *Decisions on the numbers*.

## What the brief gets wrong, leaves open, or makes dangerous

Held to the code and the Report, as the other roadmaps' briefs were. The brief is a list of ideas to test, and it says so. Each item names what answers it.

### Wrong, or out of date

- **W1. "lambda should be conceptually close to GHC's Core".** It is not, and the hook should not be there. No optional pass runs on Lambda, it has no type abstraction, its types live in tables filled from the elaborator, and ToMid calls `Elaborate` (*Where we are*). Mid, with explicit suspensions, is what stands where GHC has STG and Strict Core has its strict arrows; Core is rhc's own. D1, D2.
- **W2. "perhaps some optimization passes are valid under a non-strict evaluation strategy and not under a strict evaluation strategy".** True, and it does not touch Mid's passes. `Let` in Mid is sequenced and strict, and the passes rely on it. If laziness is a distinct type in Mid, they stay safe; if it were not, they would be wrong in ways no lint sees. Sharing is a separate question (D51): safe is not the same as not copying a thunk. Transformations that need non-strictness go in Core. D1, D47.
- **W3. "hugs may be written in haskell 98?"** It is C: 56 `.c` files, no Haskell in `src`. The largest realistic target is nhc98's compiler, 24,186 lines in its closure, which needs a handful of libraries and 33 dotted module names outside `modid` (E8).
- **W4. "i think haskell 98 only needs a unification based type inferences".** Half right. No OutsideIn is needed, but unification is the smallest part: kind inference, context reduction, dependency analysis, the monomorphism restriction, defaulting and derived-instance contexts are what make it Haskell, and Haskell 98 has local class givens, so it belongs to qualified types rather than HM(X) (E15). D31.
- **W5. "this may be the biggest design decision".** It is not. The cache needs +338 -231 in three files and leaves Rune's bytes unchanged (E13). The laziness boundary is harder to reverse: D3, D4, D5, D11.
- **W6. "doing haskell first ensures the whole stack supports lazy evalaution properly".** Partly. Both languages can share one object, one force and most of the collector (E2). They do not share Core, and lazy ML needs none. Haskell cannot reach two collector faults that lazy ML does: the `K_IND` shortcut on `'a susp susp`, and a body outliving its own update, which E14 found by running. A Haskell-only stack would leave both broken. D57 turns "ready" into a checklist that has been run: the 10 spec programs pass with no change to a Mid pass and no Core (E14).
- **W7. "a corpus of fully haskell 98 compliant programs may be hard to find".** One is at hand, though not the one the brief names: `nhc98/tests/nofib` has 71 of 77 programs accepted by an oracle needing nothing, 59 by all three, and `conformance98` beside it. The nofib left for this work is closer than a grep suggests: a 144-line compat layer makes 106 of its 131 sequential programs usable, since the obstacle is the benchmark harness and not the programs (E8).
- **W8. "ghc ... can be used as oracles".** With care. GHC's `-XHaskell98` enables `NondecreasingIndentation`, misreads the spacing of `@ ~ !`, and sits on a Prelude where `Num` lacks `Eq` and `Show` and `Monad` needs `Applicative`. It takes a strict shim (E7), and it is one judge of three (D52).
- **W9. "https://www.haskell.org/onlinereport/".** That text is December 2002 with 16 of 18 published errata unapplied (E9). D38.
- **W10. "rhc will use lib/compiler".** Not as it stands. Its public boundary exposes `RuneCompiler` and Mid only as bytes; the rest is reached through `internal.build`, and the pipeline's pass list is fixed in code. E11 shows a client taking Mid text to bytecode with 48 of the 80 files after its patches, and no front end. D39, D40, D41.

### Contradictory

- **C1. "rhc is a second class citizen" and "the same extent that rune follows the sml 97 definition".** No conflict once the words are read apart: second class in tools, first class in conformance. It leaves open which hosts build rhc (D42) and what it costs `make check` (D56).
- **C2. "the same extent that rune follows the sml 97 definition" and a Report with no formal static semantics.** Rune's lints can name rules of the Definition. Nothing in the Report can be named that way: Hindley-Milner is a citation, and context reduction, defaulting and kind inference are prose (E9). The equivalent is a clause table, in which every normative sentence has an id, and a checker based on Faxén and Typing Haskell in Haskell. D53, D54.
- **C3. "no silent changes to rune" and "improve the overall architecture of the rune compiler".** They agree, given a rule: a change that alters no byte of Rune's output is not silent if it is a decision. E11's patches hold the bootstrap byte for byte. The standing gate keeps it so.
- **C4. Recursive modules are in the language; the Report's libraries are written with them; no implementation builds them so.** Chapter 5 says "Modules may be mutually recursive." Chapter 8 calls the Prelude's structure "purely presentational". Hugs refuses recursion; GHC needs boot files; jhc and Programatica join each cycle into one unit. Nothing in the Report requires the library layout, and nothing excuses refusing the feature. D30, D36.

### Ambiguous

- **A1. "as per the revised report".** With its errata or without? D38.
- **A2. "documented deviations only where the report is wrong, contradictory, ambiguous".** It says nothing of what the Report omits. E9 lists what a compiler must decide anyway: source encoding, mapping module names to files, `Char`'s range, the Unicode version, division by zero, NaN in `round`, exit codes. Those are choices, not deviations, and are recorded as such (D53).
- **A3. "separate / incremental compilation".** At what grain? A module; one unit per SCC; early cut-off by interface. D43, D44, D45.
- **A4. "properly supported language extension".** D57.
- **A5. What the brief leaves out: `seq`.** It matters: the Report's Prelude has it, so eta-equivalence is not free in Core (D48).

### Dangerous

- **X1. A thunk in a trusted slot.** Tier 2 drops tag and kind tests where a type says so. Run, a thunk in a slot typed list, tuple or `ref` gives a silent wrong answer at tier 2, where the interpreter and tier 1 stop (E2). A thunk in a function-typed slot passes every engine. D4, D5.
- **X2. A forgotten force behind a cast.** It runs silently at tier 2, even with `--checked` (E1). `Any` must mean evaluated, or the type that keeps the program safe is the type that hides the bug. D4.
- **X3. An edit to rhc's sources does not change `Config.identity`,** which hashes `rune.build`'s list alone. The toy showed a warm build serving the old tool's program (E13). D46, and v2's D14.
- **X4. A new instance two imports away, named on no list, changes what a default resolves to.** A usage must record the absence of an instance as well as its presence, and GHC prints the changed answer (E13). Obligations H2 and H4.
- **X5. Space.** The Report never requires call-by-need or any space bound, so a conforming compiler could still lose the corpus to leaks: CAFs held as roots, no selector thunks, a closure retained by its frame. The last is confirmed by running (E2). D12, D17, D19.
- **X6. Scope.** This is a Haskell compiler, a lazy runtime and an architecture review in one roadmap. The IR review stays a document unless Rune gains from it alone, and each change to Rune has its own decision. *What is cut first*.
- **X7. The licence.** The Report's code may be copied, but `share/rhc/haskell98` is a modified version, must say so, and must not claim to define Haskell 98. Rune's `LICENSE` cannot cover it (E9). D37.

### Where this roadmap recommends otherwise than the brief

- **The hook** is Mid, not Lambda, beneath a Core that rhc owns: W1.
- **Lambda stays** as it is, private to SML (D7), and the brief's review of the IRs recommends little change there: Mid's and Low's constructors all stay (E12).
- **No new instruction and no `K_THUNK`,** where the heap-layout roadmap reserved one: D11, D13.
- **The cache is not rhc's biggest problem,** and rhc waits on no milestone of build-system-v2: D43, D46. What it asks is six of that roadmap's decisions taken with a second language in view, and refused, none of them stops it.

## Where we are

Master at `b12141ecc`, read in the reference tree `.worktrees/hs-base`. Paths are relative to the root and line numbers
are of that commit. To keep citations short:
- `core/`, `backend/`, `driver/`, `elab/`, `frontend/` and `util/` are directories of `lib/compiler/`;
- `src/isa/regs.sml` and `src/isa/stack.sml` describe the two instruction sets, and `backend/regs.sml` and
  `backend/stack.sml` generate code for them: the pairs are different files;
- `README.md` with a line number is `runtime/register/README.md`;
- `results/` and `patches/` are under the campaign's drafts, `~/.cache/claude-rune-drafts/haskell98/`.

"Observed" means an experiment ran it, and the experiment is named. "Deduced" means it comes from reading the code and
nothing ran it. A sentence with a citation and neither word says what the code does. This section says what is; what to
do about it is in *The IRs, reviewed* and *Decisions*, and a decision is named here only where a reader would otherwise
go looking for it.

### The representations in one table

| Representation | Shape | Types | Constructors | Made by | Read by | Its check |
|---|---|---|---:|---|---|---|
| Lambda | a tree | side tables, and `Inst` at uses | 39 | `Translate`, `MatchComp` | `ToMid` alone | `LambdaLint`, level 1 |
| Mid | A-normal form, join points, a list of definitions | System F, on every binder and use | 31 | `ToMid`, `MidText.parse`, each Mid pass | the passes, `Lower`, `MidText`, `MidCodec`, `UnitMid` | `MidLint`, level 1 at the boundaries, 2 after each pass |
| Low | SSA blocks, closures explicit | none: a representation for each variable | 47 | `Lower` | `Stack`, `Regs` | `LowLint` and `LowShapes`, level 1; `LowLint.results`, level 0 |
| Stack bytecode | operand stack and locals | none | 41 | `backend/stack.sml` | `runevm-stack`, `runeopt` | the loader; `RbcCheck`, level 2 |
| Register bytecode | a frame's slots as registers | a section of representations | 41 | `backend/regs.sml` | `runevm` | the loader; `RegVerify`, level 1 |

The constructors are E12's census: `results/E12/census.tsv`, each counted again against the datatypes for this section.
The levels are `docs/ir.md:64-73`.

### Lambda

Lambda is SML after elaboration, as a tree (`core/lambda.sml:19-53`): 32 forms of expression and 7 of constant (`:10-17`).
`Fn` has one parameter and `App` one argument (`:24`, `:26`). `Try`/`Fail` and `Join`/`Jump` are two ways to say the same
jump (`:38-42`); `ToMid` turns the first into the second (`core/tomid.sml:236-243`). `Rest` marks the rest of the program
after a top-level declaration, which is where Mid's top level is split (`core/lambda.sml:52-53`).

It is typed, but it is not System F. There is no type abstraction. A binder's scheme lives in `Ty.binders`, a table of
the elaborator's `Types.ty` by stamp (`core/ty.sml:186`), which `LambdaLint` and `ToMid` read (`core/lambdalint.sml:46-51`,
`core/tomid.sml:48`). A use says its instance with `Inst` (`core/lambda.sml:25`).

Nothing but SML enters it, and only `ToMid` leaves it:
- No optional pass runs on it: `Pipeline.lowOf` goes straight to `ToMid` (`driver/pipeline.sml:197-203`).
- `ToMid` calls the elaborator for stamps and open constructors (`core/tomid.sml:25`, `:279`), and `Lambda.constAt` reads
  `Types` (`core/lambda.sml:72-76`).
- `Translate` and `MatchComp` build it, with 224 and 115 occurrences of its constructors (E12,
  `results/E12/occurrences.tsv`).
- `Lambda.const` leaks down: `Mid.Const` and `Low.Const` hold it (`core/mid.sml:41`,
  `backend/low.sml:42`).

On the compiler at `-O1`, `translate` makes 435,763 nodes and `mid` 208,346 (E12,
`results/E12/dumps/rune.O1.stats`).

### Mid

Mid (`core/mid.sml:38-78`) is where the program is the program. Five atoms, fourteen right-hand sides, nine expressions,
three definitions:
- **A-normal form.** Every operand is an atom, and the datatype says so. `Let` names one step (`rhs`), and `Return`
  gives one.
- **Join points.** `Join (j, params, body, scope)` binds a label that `scope` jumps to in tail position; no function
  captures one (`:7-10`).
- **`Handle` is a region.** A call in tail position of its body is no tail call (`:15-17`).
- **The top level is a list:** `Val`, `Funs`, `Do` (`:75-78`).
- **Functions** are `Fun` in an expression and `Funs` at the top level, with a list of parameters (`:73`). Their name
  is a stamp, and the only text for it is in a table keyed by the first parameter, `Translate.funNames`
  (`core/expand.sml:189`).

**Types.** Every binder says its type, a polymorphic one the variables it abstracts over, and every use the types it is
used at (`core/mid.sml:18-20`, `docs/ir.md:620-638`). That is System F at rank 1: schemes sit on binders, and a function's
parameters are monomorphic (`core/midlint.sml:338`). The types are `Ty.ty`, hash-consed, and `Ty.view` is all of them
(`core/ty.sml:27-33`): `Gen`, `Var`, `Con` of a stamp and arguments, `Tuple`, `Arrow`, `ExnCon`. The head of an application
is always a stamp and there is no forall, so `f a` and a field `forall a. ...` cannot be written. `Ty.view` is used in 18
files and its constructors are named in 19 (grep). MidLint compares types by `Ty.equal` and infers nothing
(`core/midlint.sml:90-92`, `docs/ir.md:649-651`). Casts are primitives: the program's `unsafe_cast` is anything (`src/isa/prims.sml:612`), and
the compiler's own, `functor_cast` and the rest, are held to their origin's rule (`core/irrules.sml:127-141`). A structure
that reaches a functor is already an erased record, its slots cast to `unit` (`docs/ir.md:420-427`).

**What it cannot say:**
- A recursive value. `Fun` binds functions and `Let` is not recursive, so `xs = 1 : xs` has no form (`core/mid.sml:64-65`).
- Code without a parameter. A function has at least one (`core/midlint.sml:333`), and there is no other way to hold code.
- A function of other than one parameter as a value (`core/midlint.sml:175-176`).
- Several results. `Return` gives one (`core/mid.sml:71`).
- A match. There is no `Case`; a test is `ConTag`, an equality primitive and `If` (*The IRs, reviewed*).

**Its text and its other readers.** `MidText` prints and reads Mid (`docs/ir.md:687-711`), and `--read-mid` is a non-SML
producer that already exists. It stops after the check, with no bytecode (`src/driver/main.sml:216-225`), and E1 took it
through to bytecode with +14 -2 lines (observed). The text carries no function names, exception argument types, pinned
layouts or open types (E1), and it reads an abstract type's arity and drops it
(`core/midtext.sml:648-650`). `MidCodec` writes one function and leaves names to its caller (`core/midcodec.sml:1-9`);
`UnitMid` writes a unit's whole Mid for its cache entry (`driver/unitmid.sml:1-12`).

### Low

Low (`backend/low.sml`) is what both targets are made from: functions of blocks with parameters, in SSA
(`:1-9`, `:88-103`). 24 operations, 8 transfers, 4 kinds of instruction, 11 representations. It carries no types. Each
variable has a `rep` (`:27`), which `Lower.repOfTy` makes from its Mid type (`backend/lower.sml:381-418`).

What Mid leaves implicit is explicit in `backend/low.sml`: closures (`Closure`, `SetEnv`, `Env`, `Self`), handlers (`Push`,
`Pop`), known calls (`CallK`, `TailCallK`), layouts (`Con`, `Decon`, `Field`, by `backend/rep.sml`) and table jumps (`IfTag`,
`Switch`) (`backend/low.sml:41-86`). Closures are flat: a function captures what its code reads, less itself, and a group's
members are set after with `SetEnv` (`docs/ir.md:909-914`).

No pass runs on Low. It exists so that two targets share one lowering, and so that the checks have something below Mid's
types to hold. `Lower` does five jobs: closure conversion, layouts, known calls and loops, recovering `Switch`, results
in globals (`docs/ir.md:905-967`). `Slot` exists for the last alone (`backend/low.sml:46-47`). `LowShapes` is what checks
that a `Decon` is under a test of its tag, which MidLint cannot say (`docs/ir.md:1040-1046`). Lower reads
`Translate.funNames` for its function names (`driver/pipeline.sml:193`).

### The two bytecodes

Both instruction sets are data, in `src/isa`, from which `runeisa` writes the VM's tables and the compiler's
(`docs/bytecode.md:3-8`). Each has 41 instructions (counted in `src/isa/stack.sml` and `src/isa/regs.sml`; agrees with
`docs/bytecode.md:453-454`), 37 of them under the same name. `LOCAL`, `SETLOCAL`, `POP` and `TEELOCAL` are the stack set's
alone; `MOVE`, `RESULT`, `PRIMPUSH` and `CATCH` the register set's.

- **Stack** (`src/isa/stack.sml:55` on): read by `runevm-stack`'s interpreter, and by `runeopt`, which translates it to
  x86-64, an instruction at a time (`docs/native.md:3-5`, `:23-26`).
- **Register** (`src/isa/regs.sml:202` on): a frame's slots as registers. It is `rune`'s default target
  (`lib/compiler/settings.sml:17`). Its `.rbc` adds a section of representations: what each register holds, the blocks
  and their parameters, the loop heads (`docs/bytecode.md:54-75`).

`.rbc` is version 6 (`docs/bytecode.md:15-44`). The file carries a **fingerprint** of the instruction set, worked out from
the instructions and from the primitives' names and arities: a VM refuses a file of another (`docs/bytecode.md:77-84`).
So a new primitive moves the fingerprint, and with it the cache's configuration (`driver/unitcache.sml:126`).

The loader refuses unknown opcodes, bad operands and a section that disagrees with the code (`docs/bytecode.md:69-75`,
`:151-153`). `RegVerify` checks register code in the compiler from level 1 (`docs/ir.md:1131-1172`), by a dataflow whose
rules `runeisa` generates; `RbcCheck` checks stack code from level 2 (`docs/ir.md:1084-1098`). Neither is a safety check
for an untrusted file (`docs/ir.md:1174-1175`).

`HALT` has no emitter in either code generator; only hand-written assembly names it: `tests/opt/every-opcode.rasm:243`, `tests/register/every-opcode.rasm:136,184`, `tests/register/fatal-call.rasm:12`, `tests/register/fatal-decon.rasm:15`, `tests/register/fatal-global.rasm:12` (grep).

### The VM and the JIT

**Values.** A `Value` is one word (`runtime/value.h:33-49`). Low bit 1 is an immediate: an int, a word, a char, a tag or
unit as 2n+1, or a real in its encoding. Low bit 0 is a pointer, 8-byte aligned, or NULL. The type of an immediate is the
program's, not the word's. There are no stack maps: the collector tells a slot's contents by that bit (`README.md:33-49`).

**Objects.** An 8-byte header: a byte of kind, a free byte, a 16-bit `contag`, a 32-bit `len` (`runtime/value.h:78-86`).
The least object is 16 bytes (`runtime/value.h:344-346`). The kind is four bits and every one of the fifteen non-zero
values has a name (`runtime/value.h:52-74`, `docs/plans/heap-layout.md:1650-1651`). The four collector bits are zero in
every object of a stock build (`runtime/value.h:241-251`).

**The collector.** A nursery that a minor collection copies out of, and an old space that a full one copies; a
low-pause cycle and compaction are options (`runtime/gc/cycle.c`, `runtime/gc/compact.c`, `README.md:33-49`). It runs only inside `vm_alloc`.
The barrier is one operation, `gc_barrier` in C (`runtime/vm.h:583-592`) and `ms_set_field` in compiled code
(`runtime/register/jit/masm.c:1761`). A store marks a card where a young pointer goes into an old object.

**Frames.** A frame is on the value stack: three header words below its registers, the middle one the closure it runs in
(`README.md:82-99`). A frame's registers are roots as far as they are live at the call it waits for
(`README.md:49-56`). Of a header the collector scans the closure alone, made `unit` where the function reads no closure
(`README.md:116-119`). A function that reads one, by `ENV` or `SELF`, keeps it a root for as long as the frame lives. The
stack doubles as it grows, to a limit of 1 GiB by default, 26 million frames by the comment there (`runtime/runtime.c:67`).

**Engines.** `bin/runevm` runs register code in an interpreter, tier 1 and tier 2; `--jit=opt` is the default
(`README.md:242-244`). Tier 1 is a template per instruction. Tier 2 is tier 1's code with some registers given homes in
machine registers, and it has no inlining (`README.md:654-661`, `:870`). Leaving compiled code needs no maps, since every
safepoint leaves the frame as the interpreter's (`README.md:868-876`). `--count` gives the same instructions and bytes on
every engine (`docs/testing.md:433-446`), which is what makes instruction counts a claim here and seconds an indication.

**Tier 2 trusts the types.** Where the section says a register holds a pointer, `ms_trusts` drops the tag, kind and length
tests (`runtime/register/jit/masm.c:1256-1273`, `README.md:822-847`). The section comes from `repOfTy`, so tier 2 believes
Mid's types. A program that lies "runs wrongly at tier 2 where the interpreter and tier 1 would have stopped it"
(`README.md:845-847`).

**Exceptions.** Handlers are an array of their own. `vm_raise` pops one, cuts the frames and goes on at its code
(`runtime/runtime.c:300-305`): nothing is run or repaired on the way. An uncaught exception prints and exits 1 (`:271-287`).

**Primitives** are C functions in `prim_table`, with a fast path in the loop and in compiled code for the common case
(`src/isa/regs.sml:303-316`). `PRIM` runs one and takes its result; it pushes no frame the VM could return into. The
only re-entry into SML from C that a grep finds is the foreign callback, bounded and in the interpreter alone
(`runtime/callback.c:12`, `runtime/vm.h:895-896`).

### What strictness gives each IR

SML's strictness is written into each level. Nothing states it as a rule of Mid: `results/E11/contract.md` lists it with
"nothing" under *Checked by*. This list is what a value that is not yet evaluated would meet.

**Lambda.** Evaluation order is the tree's: `ToMid` names every value "in the order Lambda evaluates it"
(`core/tomid.sml:1-2`). The value restriction has one home, `ToMid.isValue` (`core/tomid.sml:95-102`), and MidLint has no such
rule (`core/midlint.sml:298-304`).

**Mid.**
- `Let` is sequenced and strict. From memory of GHC, not read: it is closer to STG's `case` than to Core's `let`.
- Top-level `Val`s run in program order (`backend/lower.sml:1453-1455`, `:1468`), and reading a global before it is set is an engine
  fatal (`src/isa/regs.sml:217`) that no lint sees (E1, `results/E1/out/neg/unset.txt`, observed).
- A step nothing uses may go (`removable`, `core/simplify.sml:109-115`, used at `:1462`). `App` stays, `SetGlobal` stays, a
  primitive by its description, and everything else goes, `Decon` and `Select` included. Shake agrees
  (`core/shake.sml:22-37`).
- A variable of datatype type is a constructor value. The folds of known constructors read it so
  (`core/simplify.sml:470-503`), and a `Decon` "is only made where the translation has tested what it takes apart"
  (`core/simplify.sml:107-108`).
- `Workers` moves a `Select` from the callee to the call, which is valid only for an evaluated tuple
  (`core/workers.sml:8-11`).
- `Simplify` and `inline` copy a function's body to its call. A function is code to run each time it is called, and
  nothing in Mid marks one as to run once (deduced; `docs/ir.md:856-877`).
- A capture-free group is lifted to the top level even where it escapes (`core/lift.sml:7-10`), so a closure with no free
  variables is one object, made once.

**Low.** `repOfTy` turns a type into a claim about the word: an `int` is `RInt`, a tuple or a function `RPtr`, a datatype
`RCon0`, `RPtr` or `RCon` by its constructors (`backend/lower.sml:381-411`). A type variable is `RAny`, and so is a type name
with no datatype that is not `array`, `vector` or `ref` (`:412-417`). `RAny` keeps every test. There is no representation for
"this, or not yet".

**The bytecodes and the VM.**
- `DECON` tests no tag unless `--checked` (`src/isa/stack.sml:105-112`).
- Tier 2's trust, above. E2 observed what follows: a thunk in a slot typed list, tuple or `ref` gives a silent wrong answer
  at tier 2 where the interpreter and tier 1 stop, and in a slot of an abstract type stops on all three
  (`results/E2/tables/wrongslot.txt`). Under forms F and G, whose thunk is a closure, a thunk in a slot typed as a function
  passes every engine (`results/E2/tables/wrongslot-F.txt`).
- C reads its arguments as evaluated. `values_equal` walks objects (`runtime/runtime.c:171`) and answers "not equal" for a
  kind it does not know (`:233`, `:236`); `list_head` and `list_tail` read fields blind (`runtime/prims.c:706-707`).

**Tags.** A front end may number its own datatypes as it likes: `Ty.bindDatatypeDirect` takes its tags (`core/ty.sml:240`),
and sorted names are SML's (`docs/ir.md:455-459`). `If` wants `Ty.bool` (`core/midlint.sml:325`). `list` and `order` keep
the tags C reads (`runtime/value.h:104-109`); `bool` is 0 and 1, and `NONE` 0 and `SOME` 1 (`docs/bytecode.md:373`, `:376`),
which primitives construct (`results/E11/contract.md`).

### How a pass runs, and how the pipeline is assembled

**A stage** is one call of `Pass.stage` (`util/pass.sml:215-249`): a name, a function from one representation to one, how
to print and size what it made, and its check. A client's pass written as a stage gets dumps, lint and `--pass-stats` for
nothing. A check runs through `Pass.checkAt (key, level)`, and it may move none of the compiler's counters of names
(`util/pass.sml:167-205`). `Pass.enabled` says whether an optional pass runs (`:91-94`), and `Pass.spend` is one rewrite for
`--fuel` (`:97-101`). `Pass.whole` says whether the passes see the whole program (`:85`). `docs/ir.md:1226-1239` lists what a
new pass must bring.

**The stage is generic. The pipeline is not.** `Pipeline.lowOfMid` is a fixed sequence of `val mid = optional (...) mid`
lines: `expand`, `shake`, `lift`, `workers`, `simplify`, `refs`, and `shake` again where the inliner ran
(`driver/pipeline.sml:177-186`). `--passes` can only filter that list (`util/pass.sml:91-94`). To add a pass, a client copies
`lowOfMid`, or edits it. `--passes=nosuchpass` is accepted and runs no optional pass, and `--dump-after=nosuchpass` prints
nothing (a defect, observed: `results/defects/passes-unknown-name/`).

**Passes hidden inside passes.** Five names `--passes` accepts are not stages:

| Name | Where | What it is |
|---|---|---|
| `trees` | `core/matchcomp.sml:654` | how `translate` compiles a match, with no IR to run on |
| `inline`, `specialise` | `core/simplify.sml:1990`, `:2017` | woven into Simplify's rounds |
| `equality` | `core/simplify.sml:2014` | in Simplify, from `-O2` |
| `results` | `backend/lower.sml:849`, `:878` | an analysis inside `Lower` |

**What ties the passes to the front end:**
- Stamps come from `Elaborate.freshStamp` (`elab/elaborate.sml:9`), in `ToMid`, `Workers`, `Lift`, `Refs`, `Simplify`,
  `Expand`, `Lower` and `MidText` (E1, `results/E1/indep/grep.out`). Types' stamps come from `Types.freshTycon` (`elab/types.sml:115-116`).
- `Pipeline` sets global hooks when it loads (`driver/pipeline.sml:8-10`, `:142`), and hands `Lower` the table
  `Translate.funNames` (`:193`).
- `funNames` is semantic as well as cosmetic: `Simplify.functorFun` and `Expand.isFunctor` test a string prefix,
  `"functor "`, to know a functor's function (`core/simplify.sml:1982-1985`, `core/expand.sml:190-195`). Mid read back from
  text has no such name, and E1 observed the Basis fail at `-O1` and `-O2` for it (`results/E1/link/run.out`).
- `Ty` sits above `Types`, which holds the built-in type names (`core/ty.sml:186-210`, `results/E11/contract.md`).
- `unitOf` and `unitThrough` take `Ast.dec`, `Env.env` and `Fixity.env` (`driver/pipeline.sml:245`, `:286-287`).

**What ties them to a target:**
- `Workers` and `Lift` read `Target.stack`'s `maxArgs` whatever the target is (`core/workers.sml:212`, `core/lift.sml:244`).
- Target dispatch is by string (`driver/pipeline.sml:225`, `:240`).
- `Target.t`'s `switch`, `barriers` and `safepoints` are never read (`core/target.sml:9-16`; grep, and E11 also found `name`
  and `machine` unread). `Target.intBits` is a global, not in the record (`core/target.sml:22`).

**What a client can link.** `lib/compiler/library.build` exposes `RuneCompiler` alone, an interface to Standard ML that
reaches Mid only as bytes. `lib/compiler/internal.build` exposes every structure of its 76 files, and drivers use it
(`rune.build:24`). Nothing today is a layer with no front end in it. E11 built one as a test file: 48 of the 80 files after its patches, four of them new, take
Mid text to bytecode with no lexer, parser, elaborator, `Translate`, `ToMid` or `Expand` (observed; D41).
`results/E11/contract.md` is what such a client hands over, sets and calls.

**The elaborator makes code.** `Elaborate.functorCode` and `callCode` decide what a structure's record holds
(`docs/ir.md:431`, `:440`). That concerns SML alone, and rhc has its own elaborator.

### What thunks exist today

Two reserved kinds, one C function that only tests call, a library module for benchmarks, and no engine support.

**The kinds.** `K_THUNK` and `K_IND` are in the enum (`runtime/value.h:68-73`) past `K_LAST` (`:75`), which is `K_REALS`. By
order they are 14 and 15; `docs/plans/heap-layout.md:1207` says 12 and 13, which is stale. The comment there says "no
program of SML makes one".

**What is built:**
- `obj_become_ind` turns an object into an indirection in place: a barrier for each field, the kind rewritten, the first
  field the value, the length kept (`runtime/value.h:325-332`).
- The collector follows an indirection's first field alone (`obj_scanned_fields`, `:339`), and scans a `K_THUNK`'s fields as
  any object's.
- Shortcuts: a minor collection and a full one's marking give the field what the indirection holds, up to `IND_HOPS`, 16
  (`runtime/gc/minor.c:151`, `runtime/gc/mark.c:155`, `runtime/gc/gc.h:158-163`). The copier of `--nursery 0` and the low-pause
  cycle copy or mark it as it is (`:160-161`).
- Tests: `tests/runtime/heap_test.c:75-92`, `:476-492`, made by hand in C.

**What refuses them.** Every other part takes a kind past `K_LAST` for a corrupt heap:
- the image reader (`runtime/image.c:517`) and its relocation (`runtime/gc/chunk.c:401`);
- the heap check (`runtime/gc/check.c:105`, `:124`, `:170`), which `--gc-verify` runs;
- the census, by a static assertion (`runtime/census/census.c:306`).

**What no engine has.** No instruction, primitive or Low operation names either kind (grep of `runtime/register`,
`runtime/stack`, `src/opt`, `src/isa`, `lib/compiler`). `CALL` wants `K_CLOSURE`, and `ENV`, `SELF` and `SETENV` do too
(`src/isa/regs.sml:192`, `:226`, `:231`, `:393`). An image with a frame running anything but a `K_CLOSURE` is refused
(`runtime/image.c:906`). `put_object` writes `obj_len` fields, stale ones of a `K_IND` included (`runtime/image.c:143-150`;
`results/defects/latent-k-ind/`).

**The shortcut has no guard.** It fires whatever the indirection points at. A thunk whose value is itself a thunk, which
Haskell cannot make and `'a susp susp` can, loses a level, and E2 observed a forced outer thunk run its inner one after a
collection (`results/E2/tables/nested.txt`; D12).

**Spare bits.** `contag` in a thunk's header is free for states (`docs/plans/heap-layout.md:5075-5078`). The two bits beside the
immediate bit are reserved for a code meaning "evaluated"; nothing sets or masks them (`runtime/value.h:349-357`).

**The frame's closure.** `ENV` reads a captured value through the frame's closure (`src/isa/regs.sml:223-227`), again at each
use (`docs/ir.md:943-945`), and the closure stays a root while the frame runs (*The VM and the JIT*). So a thunk compiled as a
closure keeps what it captured for as long as its code runs. E2 confirmed this leak by running it (D12).

**In SML.** `examples/benchmarks/shared/lazy.sml` is `BenchLazy`, a `ref` of `Pending`, `Evaluating`, `Value` or `Failed`.
It memoises an exception and detects re-entry, which matches neither Haskell nor lazy ML (`:1-16`). 114 of the 115 `-lazy` ports
go through it (E2, observed).

**No Rune IR has a thunk.** The nearest are `docs/plans/middle-end.md:1514-1517`, which plans thunk, force and update as Mid
operations, and `heap-layout.md`'s *A lazy front end*, which reserved the kinds above.

### The calling convention and unknown calls

**Through a closure, one argument.** `CALL` takes a closure and one argument (`src/isa/regs.sml:122-124`, `:233-235`,
`docs/bytecode.md:396-402`). The callee's frame has the argument in register 0 and the closure in its header. Curried
functions are nested closures, and a tuple is one value. `Low.Call` has the same shape (`backend/low.sml:51`).

**Known, n arguments.** `CALLK f, n` calls a top-level function with up to 64 arguments and no closure, so such a function
reads no `ENV` or `SELF` (`src/isa/regs.sml:438-440`, `core/target.sml:28`, `backend/regs.sml:25`). A function of other than
one parameter is only called, never a value: MidLint, LowLint and RegVerify all hold to it (`core/midlint.sml:175-176`,
`docs/ir.md:997-998`, `:1165-1168`). Where the callee has code at tier 2, a known call puts arguments straight into its homes;
a call through a closure keeps the slots (`README.md:505-516`).

**Tail calls** are `TAILCALL` and `TAILCALLK`, on both bytecodes. A call in tail position of a `Handle`'s region is not one
(`core/mid.sml:15-17`). A function that calls itself in tail position is a loop (`docs/ir.md:935-938`).

**One result.** `RET` gives one value, and the instruction after a call takes it (`RESULT`, `src/isa/regs.sml:247`).

**Wrong arity cannot happen, and there is no partial-application object.** A partial application is a closure
(`docs/plans/heap-layout.md:4985`). An unknown call of n arguments makes n-1 closures and n calls (deduced). A method of a
dictionary is such a call, and E1 wrote State's `>>=` as three nested closures.

**What turns curried calls into known ones, all in Mid:**
- `Workers`: a top-level function whose body only makes a function, n deep, called with every level's arguments down one
  straight line (`core/workers.sml:15-20`).
- `Lift`: local functions that never escape (`core/lift.sml:1-6`).
- `specialise`: a self-recursive function of at most 64 nodes, copied for the known functions it is given
  (`docs/ir.md:878-885`).
- `inline`.

None of them sees through a dictionary (deduced). In the compiler's own register code at `-O1`, 21,748 of 23,748 call sites
are known: `CALLK` 18,658, `TAILCALLK` 3,090, `CALL` 1,588, `TAILCALL` 412 (E12,
`results/E12/isa.tsv`, static). E3 measured what a lazy
language does: D15.

### Data

| Type | At run time | Mid and Low | Range | Past it |
|---|---|---|---|---|
| `int` | immediate | `RInt` | 63 bits | `int_add` and the rest raise `Overflow` |
| `word` | immediate | `RWord` | 63 bits | wraps |
| `Int64.int`, `Word64.word` | immediate, or a `K_BOX` past 63 bits | `RInt64`, `RWord64` | 64 bits | `int64_add` raises; `word64_add` wraps |
| `IntInf.int` | a constructor object in the heap | `RPtr` (deduced) | a budget of bits | a runtime limit |
| `char` | immediate | `RChar` | 0 to 255 | `Chr` |
| `WideChar.char` | immediate, an `int` | `RInt` (deduced) | 0 to 0x10FFFF | `Chr` |
| `real` | immediate, or a `K_REAL` box | `RReal` | IEEE binary64 | IEEE |
| `Real32.real` | a `real` | `RReal` (deduced) | binary32 values, held in binary64 | rounded after each operation |
| `string` | `K_STRING`, bytes | `RPtr` | | |

**`int`** is the immediate's 63 bits (`runtime/value.h:39-41`, `core/target.sml:18-22`). Every `int` primitive that can
overflow raises (`src/isa/prims.sml:26-27`). No primitive wraps an `int`: wrapping needs `word_from_int`, `word_add` and
`word_to_int_x`, each of which has no `Raises` (`src/isa/prims.sml:62`, `:94`, `:96`). A VM built with `RUNE_INT64` keeps 64
bits by boxing (`runtime/value.h:45-47`), and `--int-bits=64` is its compiler's flag; it is behind a switch.

**`IntInf`** lives in the SML Basis, not the VM: `datatype int = S of limb | B of bool * string`
(`lib/basis/intinf.sml:13`). By `Rep`'s rule (`backend/rep.sml:1-7`), `S n` boxes its argument in a one-field `K_CON`, and `B`
is flat. So a small `IntInf` is a heap object of 16 bytes (deduced; E5 measures it), against
`docs/plans/heap-layout.md:4998-4999`, which says its small values are immediate. Arithmetic is in SML, with limbs of 30 bits
(`lib/basis/intinf.sml:29`), and an optional GMP behind `intinf_binary`, `intinf_divmod`, `intinf_shift`, `intinf_power` and
`intinf_decimal` (`src/isa/prims.sml:827-847`), which take signed magnitudes as byte strings. Values and images hold no GMP
pointers (`README.md:1102-1106`). A constant is converted from its digits where it is evaluated (`docs/language.md:24`).

**`char`** stops at 255: `int_to_char` raises `Chr` (`runtime/prims.c:205`), and the lint holds a constant to it
(`core/irrules.sml:55`). `string` is bytes. `CChar` is `Lambda.const`'s (`core/lambda.sml:17`).

**`WideChar`** is the code point: `type char = int`, sealed, `maxOrd` 1114111 (`lib/basis/widechar.sml:11-29`), so Mid sees an
`int` (`core/ty.sml:5-7`, deduced). Its classes and case conversions are ASCII's: a character above 127 is in no class and
is its own upper and lower case (`docs/language.md:307`). `WideTextIO` decodes UTF-8 with the primitive `utf8_decode`
(`src/isa/prims.sml:856`).

**`lib/unicode`** has tables of one version, 18.0.0 (`lib/unicode/grapheme_data.sml:18`): display width, grapheme clusters,
identifiers, normalisation, security, and UTF-8. It exports no general category and no case mapping (`lib/unicode/*_sig.sml`).
`bin/rune-generate unicode` makes its tables from the Unicode Character Database (`lib/unicode/README.md:11-12`).

**`real`** is a double. Exponents from 2^-511 to 2^513 are immediates by a rotation; the rest are `K_REAL` boxes, and the six
met everywhere (both zeros, both infinities, both quiet NaNs) are one box each that the VM keeps, so they do not allocate
(`runtime/value.h:115-124`). A constant is text, read by `strtod` (`docs/bytecode.md:136`). There are primitives for
what the Basis needs: `real_add`, `real_sqrt`, `real_exp`, `real_pow` and so on (`src/isa/prims.sml:101-151`).

**`Real32`** has no representation of its own. A value "is kept as a real (binary64) that binary32 represents, and an
operation rounds its result to binary32" by the primitive `real_to_single` (`lib/basis/real32.sml:1-8`, `:12`, `:17`,
`src/isa/prims.sml:553-554`). For `+`, `-`, `*`, `/` and `sqrt` that is the correctly rounded result (`lib/basis/real32.sml:3-5`).
`real_single_from_string` reads a numeral (`src/isa/prims.sml:555-556`). `structure Real32 :> REAL` seals it
(`lib/basis/real32.sml:247`), which types see and Mid does not.

**Constants in Mid** are `Lambda.const` at a type, `IrRules.const` holding each to its type's kind and range
(`core/irrules.sml:46-55`).

### Units, the cache and the link

This is the machinery v2 plans to change, and v2's own *Where we are* describes it at length. What follows is what rhc must see.

**A unit** is a file, in the build's order, compiled against what the units before it declared (`docs/units.md:13-20`). The
passes run with `Pass.whole` false: no `Shake`, `Workers` keeps wrappers, `Simplify` does not place a function called once,
results in globals is off (`docs/units.md:47-52`, `backend/lower.sml:849`). No code crosses a unit but marked functors and
functions, and functions that only apply a primitive (`docs/units.md:60-61`, `:126-137`).

**The interface** is one pickle, the *basis*: fixity, environment, signatures, functors, inline Mid, overloading, tables of
schemes and datatypes (`driver/unitbasis.sml:2131-2215`, `docs/units.md:109-117`). Loading it rebuilds the elaborator's tables
(`docs/units.md:176-182`).

**Identity and names.** A unit's identity is `name@hash`, the hash of its basis, Merkle over the identities it names
(`driver/unitbasis.sml:2196-2211`). A body that changes and a basis that does not keeps the identity: that is the
cut-off (`docs/units.md:196-199`). Names are built in, or a unit's own by number, or an earlier unit's by identity and number
(`docs/units.md:186-194`, `backend/link.sml:39`).

**The cache.** A directory by configuration, in it by key, in it one entry per set of usages (`docs/units.md:335-373`):
- Configuration: `Config.identity`, the versions, the instruction set, the options (`driver/unitcache.sml:124-141`).
- Key: name, hash of source, whether it may use `_prim`, settings (`driver/unitcache.sml:215-218`).
- Usage: each name the compile looked up, `("kind name", "IDENTITY FINGERPRINT")` (`util/usage.sml:1-6`,
  `driver/unitbasis.sml:1328-1333`). It holds by its binder, or by fingerprint with a remap (`:1341-1353`).
- Entry: usages, warnings, basis, code, Mid, the lint level, schemes (`driver/unitcache.sml:45-47`).
- `.rune` and `lib/cache` have one format; `lib/cache` is generated, frozen and read second (`:196-208`,
  `src/driver/main.sml:708-714`).

`UnitCache` is one file of 437 lines, and it is not separable as it stands. It reads `UnitBasis`, `UnitMid`, `Pipeline`,
`Elaborate` and `RegVerify` by name (`driver/unitcache.sml:59-61`, `:100-118`, `:124-137`, `:141`, `:283`, `:295-297`, `:399`). E13
counts seven such welds, and took them out (D43).

**The link.** `Link.program` gives each unit a base for its functions, constants, labels, files and frames, renumbers
operands by the kind the instruction set gives them, and resolves keys (`backend/link.sml:1-20`, `:118`). A unit's top level
tail-calls the next, so one is on the stack at a time (`docs/units.md:226-233`). A unit's register code declares what it
expects, and the link checks arities and representations at every level (`docs/units.md:235-258`). A global must be set by
a unit before (`backend/link.sml:197-203`). `Link` knows no SML, and E13 linked a toy language through it unchanged (observed).

**The driver** is `compileUnits` (`src/driver/main.sml:553`), a fold over the files in build order. `Deps` works out that order
for a program, and refuses a cycle (`driver/deps.sml:270`). `--units --whole` makes one program of the units' Mid
(`src/driver/main.sml:1018-1025`), which is why an entry keeps Mid.

**Neutral, and SML.** `Pickle`, `UnitFile`, `MidCodec`, `Usage` and `Link` carry no language. `UnitBasis`, `unitOf` and
`unitThrough`, `Deps`, `BuildFile` and `LibraryScope` carry SML's environment, signatures or AST (`driver/deps.sml:40`,
`driver/buildfile.sml:12`, `driver/libraryscope.sml:5-6`). `Types.ty` has no class
contexts and no variable-headed application (`elab/types.sml:8-12`), so a Haskell type does not fit a basis.
`Config.identity` hashes the files of `rune.build` alone (`scripts/gen-version.sh:51-53`), and it is copied into the library
(`:76-77`). An edit to a file `rune.build` does not list leaves the identity as it was, and E13 observed that on its toy: an
edited tool with the same identity served the old tool's program (`results/E13/toy/p7.out`).

### The test machinery

The runner is `bin/rune-test`, built from `tests/runner/*.sml` on `lib/test/runner` (`docs/testing.md:56-59`). A test is a
tree of commands with a judge, in a directory of its own, under a timeout and a cap on output (`docs/testing.md:59-64`), and
the runner sets `RUNE_LINT=2` for every compile (`docs/testing.md:72-75`). Tiers are tags; `make check` is `check-tools` and `--tier check` (`Makefile:2139-2140`).
`--affected` selects by `covers:GLOB` tags (`docs/testing.md:166-172`).

| Mechanism | Where | What it does |
|---|---|---|
| Accept and run | `tests/lang`, 361 programs | `.expected`, with `.cargs`, `.args`, `.stdin`, `.exitcode`, `.cwarn` siblings (`tests/runner/langchecks.sml:32`, `:124`) |
| Reject | `tests/errors`, 210 programs | `.expected` is the first line of the error (`tests/runner/langchecks.sml:50`) |
| Types alone | both directories | each program judged again by `--typecheck-only` (`tests/runner/lang.sml:203`) |
| IR | `tests/ir`, 34 `.sml` and 4 `.mid` | a first line `dump:` or `fail:`, at lint level 3 (`docs/ir.md:1185-1191`) |
| Three oracles | `docs/testing.md:422` on | output; `--count`, the same on every engine; identical bytes at the bootstrap and across hosts |
| Levels | `tests/runner/oracles.sml` | each program at `-O0`, `-O2`, whole and in units, both targets, against the stack bytecode's `-O0` (`docs/ir.md:1192-1204`) |
| Lints' negative tests | `RUNE_FAULT`, `compiler/lint-rules` | every rule of every lint refuses what breaks it (`docs/ir.md:1207-1221`) |
| AstLint | `elab/astlint.sml`, 1,957 lines | a checker that never unifies, on `Witness` records through `SourceTy`, 244 lines; 20 faults (`tests/runner/tools.sml:783-792`, `docs/ir.md:197-217`) |
| Mutants | `tests/runner/compilermutantlist.sml` | 68 seeded bugs, nightly; `make check` only builds them (`docs/testing.md:833-870`) |
| External corpora | `tests/runner/externalchecks.sml` | shims, skips, a table of counts; outside `make check` |
| Expectations | `lib/test/runner` | one format for a known failure, with `SPEC-AMBIGUOUS` among its categories (`docs/testing.md:315-333`) |
| Language contract | `tests/runner/docchecks.sml:12-69` | each of `docs/language.md`'s 200 rows marked Supported or Partial needs a test named for its id; each test's prefix must be such an id |

**Round trips.** `Ast.decToString` (`frontend/ast.sml:381`) is a debug printer behind `--dump-ast`. No test uses it and nothing
reparses what it prints, so Rune has no AST round trip. Mid has one: `MidText.roundTrip`, at level 3 after every stage, and
from level 1 with `--mid-roundtrip` (`driver/pipeline.sml:29`, `:121`).

**What is SML-bound.** `Lang` and `LangChecks` hard-code `.sml` and `tests/lang` (`tests/runner/lang.sml:67`, `:189`,
`tests/runner/langchecks.sml:37`, `:55`, `:87`, `:121`). `DocChecks.features` reads one file by name. AstLint, `SourceTy`, `Witness`,
the laws, the Basis matrix and the functor generator are SML through and through. `lib/test/runner`, `lib/test/unit`,
`lib/test/property`, `Pass.stage`, `Pass.checkAt`, and the oracles on bytecode are not.

### `lib/language/c`

It is the only other language in the tree: 24 files, 1,827 lines, a front end for C declarations in SML
(`lib/language/c/README.md:1-8`). It lexes, preprocesses, parses, evaluates constants, types expressions and lays out
structs for a target, with include resolution and target facts supplied by its caller.

It is a precedent for `lib/language/haskell` in being a library with no driver of its own, and only in that. It has no code
generator and joins `lib/compiler` nowhere: nothing in it names `lib/compiler` (grep), and `lib/ffi/model` and `runeffi` use it
(`lib/ffi/model/library.build`, `runeffi.build`). It has no syntax printer, `CDeclarator` rendering types alone
(`lib/language/c/README.md:36-38`). It is tested on six native hosts (`tests/runner/libhosts.sml:46-48`, `docs/testing.md:35`) and against
clang, on preprocessing and on the AST (`tests/ffi/frontend-check.sml:104-111`).

## What the Report says

The Definition of Standard ML has no compilation unit and no library, and rules for everything else. The Haskell 98
Report is the other way round. It has modules, a program, a Prelude and sixteen library modules, and it has no typing
rule: its type system is a citation and some prose. Its meaning is a translation into a kernel it never lists. Its
Prelude is a program that does not compile as printed.

The owner's rule of conformance is the one Rune keeps for the Definition: a deviation only where the Report is wrong,
contradictory or ambiguous, always documented and pinned by a test. This section says which text that rule applies to,
how much of it there is, what stands where a static semantics would, where the translations fail, what the worst
readings are and what the oracles do with them, what a compiler must settle alone, and how the modules and libraries
read. It ends with what these give the decisions.

Quotations are from `results/E9/text/`, the fetched HTML as text, with white space normalised; `_|_` is how the HTML
writes bottom. Section numbers are the Report's. **Readings** R1-R54 are `results/E9/readings.md`, row ids are those
of `results/E9/clauses.tsv`. A behaviour is marked by how it is known:

- **[run]**: E7's conformance run, E7's `hard/`, or E10's crafted cases (`results/E10/cases/cases.tsv`).
- **[probe]**: a small program run on the three oracles while writing this section, for a reading no experiment had
  run: `results/E7/hard/06-probes/` holds the programs, `run.py` and `out.txt`.
- **[read]**: read in the source, not run. GHC's source under `/home/ruud/haskell` is 9.14.1 and the binary is 9.4.7,
  so a [read] about GHC may not describe the oracle. Paths are under `/home/ruud/haskell`.
- **[inferred]**, **[memory]**: as they say.

Where a run corrects what was read, this section gives the run.

### Which text

The owner's link, `https://www.haskell.org/onlinereport/`, serves the Revised Report dated December 2002, and nothing
later. E9 fetched it on 2026-11-01: 36 files, of which the 33 `.html` are byte-identical to the official tarball
`haskell98-report-html.tar.gz` (compared again while writing). No later revision of Haskell 98 exists. Haskell 2010 is
a separate document and out of scope.

The errata page lists 18 entries, the last of September 2008. E9 tested each against the text by marker strings
(`results/E9/errata_check.py`, `errata-status.tsv`). **16 are unapplied:** the old wording is there and the new is
not. One is about the index of the printed book, which the online text does not contain. One, the `break` example in
the online index, could not be tested. So no erratum is known to be applied. The PDF agrees on the two markers its
text extraction shows, so it is unrevised too. The printed book was not checked, and the errata page's page numbers
are the book's, which it says may differ slightly from the online text.

| Date | Section | Erratum | Status | What it means for rhc | Reading |
|---|---|---|---|---|---|
| Dec 2005 | 2.2 | The comment production admits `--:`, a legal `varsym` | Unapplied | Lexer | R8 |
| Jul 2004 | 3.17.2 case 6 | "field list" means the pattern's list | Unapplied | Fixes an order, and so termination | R16 |
| Jan 2005 | 3.17.2 case 6 | Wording: a pattern is matched, not a value | Unapplied | None | |
| Mar 2008 | 3.17.2 case 8 | n+k: `x` should be `v` | Unapplied | None | R15 |
| Jul 2004 | 4.4.2 | `=<<` missing from Table 4.1; the HTML caption says Table 2 | Unapplied | None: the Prelude declares `infixr 1 =<<` | R52 |
| May 2003 | 6.3.4 | The `enumFrom` family on `Float` and `Double` is said to be strict; the Prelude's code is not | Unapplied | Overlay | R39 |
| Jun 2003 | 6.4.6 | `properFraction` wording fails at zero | Unapplied | A test's expectation | R45 |
| Feb 2008 | 7.2 | The `do` example's buffering | Unapplied | A test's expectation | |
| Feb 2003 | 8.2 | `lex`: an identifier may start with `_` | Unapplied | Overlay | R43 |
| Sep 2004 | 9.5 | `export` production: `qvar` should be `var` | Unapplied | Parser | R34 |
| Aug 2005 | 12 | `approxRational`: closed interval, not open | Unapplied | A test's expectation | R44 |
| Mar 2003 | 15 | The `Ix` law is bogus | Unapplied | A test's expectation | |
| Sep 2008 | 17 | `genericTake`, `genericDrop`, `genericSplitAt` on negatives | Unapplied | Overlay | R48 |
| Mar 2003 | 19 | "converts the to the character" | Unapplied | None | R52 |
| Nov 2006 | 21.3.2 | "doing so not an error" | Unapplied | None | R52 |
| Jul 2003 | Online index | `either` has no type; `print`'s is wrong | Unapplied | None | |
| Oct 2006 | Online index | The `break` example is wrong | Not testable | None | |
| Jun 2005 | Printed index | No entry for the keywords | Book only | None | |

**D38** takes this text plus the published errata, all listed: the table is the list. An erratum that changes what a
program does is applied and pinned by a test. One that changes the Prelude's code is an entry in the overlay (*The
libraries*), so that the exit test's diff against the Report stays explained. Everything else that departs from the
Report is a deviation under the owner's rule. The errata page does not cover the worst of them: R7's `[LT..]`, R42's
`Show Float` and R47's Prelude are on no list.

### The clause matrix and its counts

`results/E9/clauses.tsv` holds the Report's normative content as rows: an id, a section, a requirement in its own
words, a class, how it is tested. It has **3,901 rows**, with unique ids that obey the rule of
`tests/runner/docchecks.sml:21-22`. 2,648 were written by hand and validated by script. 1,253 are generated by
`build_clauses.py`: the 163 productions of 9.5, 444 for the Prelude's definitions, methods and exports, and 646 for
the libraries'.

| Ch | Title | Hand | Generated | Total | Accept | Reject | Run | None |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | Introduction | 11 | 0 | 11 | 4 | 4 | 1 | 2 |
| 2 | Lexical structure | 273 | 0 | 273 | 134 | 61 | 72 | 6 |
| 3 | Expressions | 452 | 0 | 452 | 96 | 89 | 256 | 11 |
| 4 | Declarations | 483 | 0 | 483 | 187 | 184 | 108 | 4 |
| 5 | Modules | 246 | 0 | 246 | 107 | 103 | 26 | 10 |
| 6 | Predefined types and classes | 307 | 0 | 307 | 16 | 21 | 255 | 15 |
| 7 | Basic I/O | 53 | 0 | 53 | 1 | 2 | 45 | 5 |
| 8 | Standard Prelude | 30 | 444 | 474 | 177 | 11 | 277 | 9 |
| 9 | Syntax reference | 164 | 163 | 327 | 278 | 42 | 0 | 7 |
| 10 | Derived instances | 165 | 0 | 165 | 20 | 20 | 120 | 5 |
| 11 | Pragmas | 10 | 0 | 10 | 6 | 0 | 1 | 3 |
| 12 | Ratio | 17 | 24 | 41 | 10 | 2 | 26 | 3 |
| 13 | Complex | 17 | 26 | 43 | 10 | 2 | 31 | 0 |
| 14 | Numeric | 30 | 47 | 77 | 19 | 0 | 57 | 1 |
| 15 | Ix | 24 | 13 | 37 | 4 | 3 | 29 | 1 |
| 16 | Array | 42 | 31 | 73 | 15 | 1 | 57 | 0 |
| 17 | List | 47 | 156 | 203 | 104 | 2 | 95 | 2 |
| 18 | Maybe | 3 | 18 | 21 | 10 | 0 | 10 | 1 |
| 19 | Char | 40 | 48 | 88 | 24 | 0 | 63 | 1 |
| 20 | Monad | 18 | 45 | 63 | 26 | 0 | 35 | 2 |
| 21 | IO | 110 | 119 | 229 | 72 | 0 | 137 | 20 |
| 22 | Directory | 31 | 32 | 63 | 15 | 0 | 46 | 2 |
| 23 | System | 16 | 14 | 30 | 8 | 0 | 19 | 3 |
| 24 | Time | 24 | 31 | 55 | 18 | 1 | 34 | 2 |
| 25 | Locale | 3 | 4 | 7 | 3 | 0 | 3 | 1 |
| 26 | CPUTime | 2 | 4 | 6 | 2 | 0 | 4 | 0 |
| 27 | Random | 30 | 34 | 64 | 13 | 0 | 47 | 4 |
| | **All** | **2,648** | **1,253** | **3,901** | **1,379** | **548** | **1,854** | **120** |

By class: library 786, module 702, prelude 620, static 488, syntax 480, dynamic 440, lex 287, layout 98. The 120
`none` rows each say why nothing can be observed.

**Coverage.** The contents page has 208 headings. 193 sections carry rows of their own; the other 15 are 14 parent
headings whose rows sit under their subsections (such as 4.2 or 21.3), and 9.6, a repeat of 9.4's literate comments,
where 9.4 is the text used. So every section with text of its own has rows (recounted against `clauses.tsv`).

**What the matrix is not.** Its accept and reject classes are read from the text, not run. Only 12 hand rows were
sampled by eye, and no reject row has been run. They are first readings, and M1 has to treat them so. The size settles
one thing: at 3,901 rows the table is about twenty times the 200 of `docs/language.md`, so it is a generated TSV
enforced by id, not a table kept by hand (D53).

### What stands in place of a static semantics

Section 4.5.1, on the static semantics of bindings, begins:

> In general the static semantics are given by the normal Hindley-Milner inference rules.

No rule of Hindley-Milner is printed; 4.1 cites Damas and Milner, and Hindley. The Report has no typing judgement of
any form. What it has instead (`results/E9/translations.md`):

| What | Where | What the Report gives |
|---|---|---|
| Type grammar, kinds | 4.1.1, 4.1.2 | Stated; kinds in English |
| Contexts, validity of types | 4.1.3, 4.1.4 | Informal. The preorder of 4.1.4 is the only near-formal definition |
| Hindley-Milner core | 4.1, 4.5.1, 4.5.2 | A citation |
| Typing of expressions | Each 3.x | One or two sentences a form; `do` and field labels by translation |
| Pattern typing | 3.17.2 | "obvious static type constraints", plus three class constraints |
| Dependency analysis | 4.5.1 | Two bullets and one identity |
| Generalisation with classes | 4.5.2 | Prose, one example |
| Context reduction | 4.5.3 | Prose: head normal form. No algorithm and no timing |
| Monomorphism restriction | 4.5.5 | Two rules in English: the most precise text in the chapter |
| Defaulting | 4.3.4 | Conditions in English. When it runs: "In situations where an ambiguous type is discovered" |
| Kind inference | 4.6 | Prose: dependency groups, "standard techniques of type inference", default `*` |
| Instance validity | 4.3.2 | Prose restrictions, on "the program" rather than the module |
| Class validity | 4.3.1 | Prose restrictions |
| Deriving | 10 | The form and context; `cx'` is "the smallest context" satisfying a condition, perhaps by "a fixpoint calculation" |
| Module scoping | 5 | Prose and tables. No semantics of recursion |

Missing entirely:
- the elaboration of overloading, by dictionaries or anything else;
- a rule for how `where`, guards and generalisation interact, other than by translation;
- an order of inference across declaration groups with monomorphic variables, which Rule 2 presumes (R20);
- kind or type inference across mutually recursive modules (R28, *Modules*);
- how polymorphic recursion meets dependency analysis: 4.4.1 presumes what 4.5.1 does not say (R21).

Three things follow:
- **The work is more than unification.** Everything in the table but the Hindley-Milner row is what makes this
  Haskell, and it is D31's list: kind inference, context reduction, dependency analysis, the restriction, defaulting,
  derived contexts.
- **HsLint has no rule numbers to name.** AstLint cites the Definition's rules
  (`lib/compiler/elab/astlint.sml:14-28`); the Report offers sections. A row of the matrix can say 4.5.3 and no more.
- **Its basis comes from outside the text (D54).** Faxén's *A static semantics for Haskell* and Jones's *Typing
  Haskell in Haskell* are entries [4] and [8] of the Report's bibliography, and no section of the body cites either
  (checked in the fetched HTML). Neither checks elaborated output.

### The chapter 3 translations and their defects

The dynamic semantics rests on one paragraph (1.2):

> If these translations are applied exhaustively, the result is a program written in a small subset of Haskell that we call the Haskell kernel. Although the kernel is not formally specified, it is essentially a slightly sugared variant of the lambda calculus with a straightforward denotational semantics.

| Form | Section | Into |
|---|---|---|
| Integer literal `i` | 3.2 | `fromInteger i` |
| Float literal `f` | 3.2 | `fromRational (n Ratio.% d)`, with `n/d = f` |
| `\ p1 ... pn -> e` | 3.3 | `\ x1 ... xn -> case (x1, ..., xn) of (p1, ..., pn) -> e` |
| `e1 op e2`, `-e` | 3.4 | `(op) e1 e2`, `negate (e)`, always the Prelude's |
| `(op e)`, `(e op)` | 3.5 | `\ x -> x op e`, `\ x -> e op x` |
| `if` | 3.6 | `case e1 of { True -> e2 ; False -> e3 }` |
| `[e1, ..., ek]` | 3.7 | `e1 : (e2 : ( ... (ek : [])))` |
| `(e)` | 3.9 | `e` |
| Arithmetic sequences | 3.10 | The four `enumFrom...` methods |
| List comprehensions | 3.11 | Five identities: `if`, `let ok`, `concatMap` |
| `let` | 3.12 | Three identities: tuple patterns, `case ... of ~p`, `fix` |
| `do` | 3.14 | Four identities: `>>`, `>>=`, `let ok`, `fail` |
| Field selector, `C { bs }`, `e { bs }` | 3.15 | `case`; `pickC`; `case` over the constructors holding all the labels, else `error "Update error"` |
| `e :: t` | 3.16 | `let { v :: t; v = e } in v` |
| `case` of any shape | 3.17.3 | Rules (a) to (s) |
| Strict constructor `K` | 4.2.1 | A lambda using `$` and `$!` |
| Function binding | 4.4.3.1 | `x = \ x1 ... xk -> case (x1, ..., xk) of ...` |
| Guarded pattern binding | 4.4.3.2 | `p = let decls in if g1 then e1 else ... error "Unmatched pattern"` |

The kernel is what is left, and the Report never lists it, so this is derived [inferred]: variables, application,
lambda over variables, `let` with a pattern (reduced by `fix` and `case ... of ~p`), constructor application,
`case v of { K x1 ... xn -> e; _ -> e' }` as given by the semantic rules (p), (q), (r), newtype construction, `error`,
`undefined`, `seq`, `fix`, kernel constants of `Integer`, `Rational` and `Char`, and the `prim*` names of chapter 8.

Other things have no translation and so are primitive in fact, though the Report does not say so: classes, instances
and overloading, for a kernel that holds `fromInteger` as a free name holds overloading; signatures, `newtype`,
`type`, `default` and `deriving` as declarations; top-level bindings and modules, for 3.12 is about `let` and chapter
5 has no translation box; `main` and the `IO` type; string literals.

**How binding the identities are.** The Report uses three wordings, and they differ. "The following identity holds"
(3.3 to 3.7). "may be used as a translation into the kernel" (3.11, 3.12, 3.14). And 3.17.3:

> Any implementation should behave so that these identities hold; it is not expected that it will use them directly, since that would generate rather inefficient code.

So a literal `-O0` (D34) is licensed as a semantics, not as a compilation scheme, and the defects below show that it
does not terminate or does not apply unless read with care.

**The defects,** numbered as in `results/E9/translations.md`. Read from the text; nothing here was run.

1. Chapter 3 opens: "Except in the case of let expressions, these translations preserve both the static and dynamic
   semantics." But a function binding translates to a simple pattern binding (4.4.3.1), which the restriction treats
   differently, so `f x = x + 1` and `f = \x -> x + 1` do not type alike. The `e :: t` and `ok` translations add
   `let`s whose effect on defaulting is not stated.
2. "Free variables and constructors used in these translations always refer to entities defined by the Prelude."
   `Ratio.%` is in the Ratio library, and the Prelude imports only `Rational` from it. `fix` is defined by no module.
3. Literals: `i` on the left is a literal, and on the right a value of type `Integer` that no syntax denotes. So too
   `n` and `d` in the float rule.
4. `let` at n=1 restates itself, for a one-tuple is a parenthesis; at n=0 it works only through the next rule.
5. The third `let` identity's right side is still a `let p`. It terminates only because the second identity's side
   condition now holds: order matters between "identities".
6. `[ e | q ] = [ e | q, True ]` loops at `q = True` unless the first identity is tried first.
7. String literals. 2.6 says "see Section 3.7", which does not mention them; the text is in 6.1.2. As a pattern, rule
   (h) compares a string with `==` while `['a','b']` goes by (g), and they agree only because `==` on lists runs left
   to right, which the Report does not say.
8. Rules (b) and (c) do not form a rewrite system. (b) substitutes `True` for absent guards, and (c)'s output has an
   unguarded alternative that must not be expanded again.
9. No rule takes a list pattern, an infix constructor pattern, a parenthesised pattern or a negative literal pattern
   to the `K` form. The last matters: R10, `numbers/negliteral` below.
10. Rules (m), (n), (o) are for data constructors, so `N { f = p }` and `N {}` on a newtype have no rule.
11. n+k: rule (s) says "numeric", 3.17.2 says integer and positive, and the grammar's `var + integer` admits `n+0`
    (R15).
12. Rule (d) with no variables gives a lambda of no parameters; `let True = False in 1` reaches it (R17).
13. Rules (e) and (g) rely on a hygiene the text never states; `v` is "a new variable" only in (a).
14. Rule (g) copies `e'` n+1 times, where (c) and (m) introduce `y` to avoid it. No semantic effect, but a literal
    `-O0` grows exponentially in pattern depth [inferred].
15. The field selector's `undefined` arm is dead: every constructor named holds the field, and one without it falls
    into rule (b)'s `error "No match"`.
16. Type-changing update exists only because the translation types; 3.15.3 says nothing of it, and its worked example
    omits the `error "Update error"` arm.
17. Strict constructors evaluate right to left, by `((K $! x1) $! x2)`, and `K` becomes a lambda, so a partial
    application is a value: `seq (K undefined) 1` is `1` for a two-field strict `K`.
18. `seq` makes the exact form of a translation visible. 6.2 says bottom is not the same as a lambda returning bottom,
    since `seq` distinguishes them. So ``seq (1 `undefined`) ()`` is `()` by the section's lambda, and bottom if the
    section is compiled as an application. Arity is visible too: `f 0 = \y -> y` against `g 0 y = y` (R35). All three
    oracles compile a section so as to share `e` [read], which R11 weighs.
19. **Sharing is never specified.** `(op e)` under the lambda re-evaluates `e` at every call. 4.5.5 motivates Rule 1
    by repeated computation, so the Report knows sharing matters, yet it never defines call-by-need: "non-strict" is
    the word, the semantics is denotational, and a call-by-name implementation conforms. A literal `-O0` and a
    `--count` budget must therefore state a rule of their own, and it is rhc's rule, not the Report's.
20. Fixity is in no translation: `e1 op e2` presumes parsing is done. The note in chapter 3 says implementations "may
    well use a post-parsing pass to deal with fixities" (R1, R9).

### The worst readings

`results/E9/readings.md` has 54 readings, each with its problem, the three implementations and a seed, the seed being
a proposal. E9's ten worst are given here in full, with R3, R7, R10 and R22, where what the oracles do changes what
the seed means. R29 is under *Modules*. All Report text is exact; each line of behaviour says how it is known.

Oracles find disagreements, not truth, and on these readings they often agree with each other against the text. How
far each can be trusted is part of the finding:
- **GHC `-XHaskell98`** turns on `NondecreasingIndentation` (R3), refuses `p@ Zero` and `t @(..)`, reads `f ~ p` as
  defining `~` and `(!1)` as a bang pattern. So its verdicts on `real/anna`, `real/hidden`, `real/veritas` and
  `Array/timeLargeArray` are GHC's deviation (E10, E8 `raw/`). It is no oracle for layout or for the spacing of
  `@ ~ !`.
- **Hugs `+98`** accepts tabs in strings, `then` at the `do` column and a `do` at the enclosing column [run], and
  resolves top-level monomorphism early (R20). Of 721 expected-failure candidates outside helium and hse, Hugs accepts
  32, nhc98 121 and GHC 11 (E8).
- **nhc98:** the `hmakerr` files and expected outputs of `conformance98` record nhc98's behaviour, not legality.

#### R1. `parse-error(t)` cannot be implemented in general

> The side condition parse-error(t) is to be interpreted as follows: if the tokens generated so far by L together with the next token t represent an invalid prefix of the Haskell grammar, and the tokens generated so far by L followed by the token "}" represent a valid prefix of the Haskell grammar, then parse-error(t) is true.

> The parse-error rule is hard to implement in its full generality, because doing so involves fixities. For example, the expression do a == b == c has a single unambiguous (albeit probably type-incorrect) parse, namely (do { a == b }) == c because (==) is non-associative.

The rule makes layout depend on the whole context-free grammar, and through non-associative operators on fixities,
which are known only after renaming and perhaps from an import. No separate layout pass can do it.

- **All three** use the grammar's error rule, without fixities [read]: GHC `close: vccurly | error {% popContext }`
  (`ghc/compiler/GHC/Parser.y:4186-4188`); Hugs `end: '}' | error` (`Hugs/src/parser.y:1016-1017`); nhc98's `rcurl`
  calls `lexicalCont` (`nhc98/src/compiler98/Parse/ParseLib.hs:155-162`).
- **On the Report's own example** GHC, Hugs, nhc98 and MicroHs all refuse [run: `r1-do-eq-eq`]. No oracle gives the
  "single unambiguous" parse.
- **How often it matters:** the rule fired 371 times in 165 of 1,670 files, closing `let` by `in` 200 times and `of`
  by `)` 103 times, and never on `then`, `else`, `of`, `|` or `}` (E10, `closes-hier.txt`). In the Report's own
  libraries it fires 8 times, none depending on fixity (E16, `closes.txt`).

**rhc:** the grammar-error rule with operators parsed flat (D27), so `do a == b == c` is refused at fixity resolution:
a pinned deviation from 9.3's example, on the ground that the Report concedes it (9.3's own words; D38, the owner's word of 2026-11-13), and the same
result as every oracle. E10 had no fixity pass, so that refusal is deferred, not run. R9 is the same problem for `let`.

#### R2. An explicit `}` under an implicit context: 2.7 and 9.3 disagree

> A close brace is also inserted whenever the syntactic category containing the layout list ends; that is, if an illegal lexeme is encountered at a point where a close brace would be legal, a close brace is inserted.

> By matching against 0 for the current layout context, we ensure that an explicit close brace can only match an explicit open brace. A parse error results if an explicit close brace matches an implicit open brace.

Equations are tried in order, and `L (}:ts) ms = parse-error` comes before the `parse-error(t)` equation. So
`let { x = case 1 of y -> y } in print x` and `R { f = case 1 of y -> y }` are refused by 9.3 and accepted by 2.7,
which calls itself informal: "Section 9.3 gives a more precise definition of the layout rules."

- **GHC, Hugs and MicroHs accept; nhc98 refuses,** "Unbalanced '}' (No explicit '{' in scope)" [run: `r2-record`,
  `r2-let`]. So nhc98 alone follows Note 3: its layout pass stops on a `}` under an implicit context
  (`nhc98/src/compiler98/Parse/Lexical.hs:84-89`).
- **Nothing depends on it:** no file of the corpus closes a block this way, and strict Note 3 loses 0 of 1,616 files
  (E10).

**rhc:** accept, as the two judges of D52 do, recording a deviation from Note 3's equation on the ground that 2.7 and
9.3 are contradictory (D38). `closeImplicit` does this
without extra work (D27). The corpus does not force the choice.

#### R3. Note 1 against equation 6, and what `n > m` means

> A nested context must be further indented than the enclosing context (n>m). If not, L fails, and the compiler should indicate a layout error.

> If the first token after a where (say) is not indented more than the enclosing layout context, then the block must be empty, so empty braces are inserted.

The equation `L ({n}:ts) ms = { : } : (L (<n>:ts) ms)` has no guard, so `L` does not fail where Note 1 says it does:
on Note 1's own example it inserts `{}` and the grammar refuses the result.

- **GHC:** `-XHaskell98` turns on `NondecreasingIndentation` (`ghc/compiler/GHC/Driver/DynFlags.hs:1310,1320`) [read],
  and 9.4.7 does the same: a nested `do` at the enclosing column is accepted, and refused with
  `-XNoNondecreasingIndentation` [probe `r3`]. E10 ran with it off.
- **Hugs** accepts it, by a deliberate choice (`Hugs/src/input.c:1529-1552`) [read, run: `do-at-enclosing-col`,
  `nested-do-same-col`].
- **nhc98** refuses, `if c > i` (`nhc98/src/compiler98/Parse/Lexical.hs:77`) [read, run].
- **In the corpus** it gains 3 files of 1,616, one a real program, `nofib/gc/happy/ProduceCode.lhs` (E10).

**rhc:** strict `n > m` and the empty-braces reading. A test here must not take GHC's `-XHaskell98` as its oracle.

#### R7. The `F..` trap, and `M.keyword`

2.4's table of sample lexical analyses gives `F..` as `F..`, the qualified operator `.`. Then 6.3.4 writes:

> For example, [LT..] is the list [LT,EQ,GT].

By 2.4 `LT..` is the operator `.` of a module `LT`, so the Report's own example does not lex as a sequence. 10.2
writes `[Orange ..]`, with the space. The same rule has a second consequence. `varid` excludes reserved words, so
`Just.let` is not a qualified name: it is `Just`, `.`, `let`, and `f = Just.let x = id in x` is a legal program.

- **`[LT..]`:** GHC, Hugs, nhc98 and MicroHs refuse; with the space, all accept [run: `enum-LT-dots`,
  `enum-LT-space`].
- **`Just.let`:** all four refuse [run: `qual-keyword`]. `conformance98/identifiers/qual` expects that failure, and
  GHC skips its own test of the point, `read023`, saying it no longer supports strict Haskell 98 for qualified
  identifiers (`ghc/testsuite/tests/parser/should_compile/all.T:34-37`).

**rhc:** follow 2.4 on both. 6.3.4's example is an error in the Report, to record, not to copy. 2.4 is neither wrong
nor ambiguous on `Just.let`, so the deviation rule does not apply: rhc accepts, as E10's spike does, and against every
oracle. The `conformance98` expectation is then a recorded disagreement. This is the plainest case of D52's rule that
an expected result cites a clause rather than an oracle.

#### R10. Negation

> Prefix negation has the same precedence as the infix operator - defined in the Prelude

> Because - is treated specially in the grammar, (- exp) is not a section, but an application of prefix negation, as described in the preceding section.

`(-5 +)` is legal and `(-5 *)` is not, so sections need a check after resolution. Negation has precedence 6 even if a
local `-` has another fixity. No rule gives a negative literal pattern a meaning: rule (h) covers "a numeric,
character, or string literal", and `negate (fromInteger 1)` and `fromInteger (-1)` differ for a user `Num`. The
grammar has `lexp6 -> - exp7`, so a negation cannot be the right operand of `*`, `!!` or `+`.

The runs are in the table below (`infix/minus`, `listindex`, `numbers/negliteral`): GHC holds to the grammar and to
3.4, Hugs departs on all three, and nhc98 on the first two. GHC checks with `checkSectionPrec`
(`ghc/compiler/GHC/Rename/HsType.hs:1600-1616`) [read]. Hugs's grammar for patterns is more liberal than the Report's
(`Hugs/src/parser.y:673,676-682`) [read].

**rhc:** the grammar; `negate (fromInteger k)` for a pattern, with `negate` the Prelude's; sections checked after
resolution.

#### R18. Two definitions of "simple pattern binding"

> A simple pattern binding has form p = e.

> a simple pattern binding is a pattern binding in which the pattern consists of only a single variable (Section 4.4.3).

Rule 1 turns on the word:

> every variable in the group is bound by a function binding or a simple pattern binding (Section 4.4.3.2), and

Under the first, `(x, y) = e` is simple. Under the second, `x | c = 1` may be. Three forms are open, and a signature
then lifts the restriction or does not. What the oracles do [probe `r18a` to `r18d`], each program printing `x` at
`Int` and at `Integer`:

| Program | GHC | Hugs | nhc98 |
|---|---|---|---|
| `x \| True = 1` | Refused | Refused | Accepted |
| `(x) = 1` | Refused | Refused | Refused: "Context for Prelude.Num needed in left hand pattern" |
| `~x = 1` | Refused | Refused | Refused, as above |
| `x :: Num a => a` and `(x) = 1` | Refused: "Overloaded signature conflicts with monomorphism restriction" | Accepted | Refused, as above |

GHC: any pattern binding is restricted, and a function binding of arity 0 unless signed
(`ghc/compiler/GHC/Tc/Gen/Bind.hs:803-812`) [read], so guards do not matter and `(x)` is a pattern. Hugs: a parallel
test (`Hugs/src/type.c:1902-1918`) [read], which treats `(x)` as the variable [probe].

The first and last rows separate them. **rhc (D32):** 4.5.5's definition, guards allowed, the parenthesis not simple.
That is GHC's row on all four.

#### R20. Rule 2, and defaulting at the end of a module

> Any monomorphic type variables that remain when type inference for an entire module is complete, are considered ambiguous, and are resolved to particular types using the defaulting rules (Section 4.3.4).

> Rule 2 states that the exact types of all the variables bound in a module must be determined by that module alone, and not by any modules that import it.

Rule 2 needs inference to hold a monomorphic variable open across declaration groups, so a type may be found only at
the end of a module, and depends on a later use. A one-pass inference in dependency order does not reach it. Local
defaulting is timed by nothing but "discovered". `x = read "1"` at the top is an error, but only at the end of the
module. And the exported type is known only then, which is a cost to any interface.

The Report gives two examples, and the oracles part on them. Taken with the top-level case from E7:

| Program | Report | GHC | Hugs | nhc98 |
|---|---|---|---|---|
| `n = 60`, `a :: Int`, `a = n + 1` [run: `E7/hard/mr/`] | Legal | `61` | Refused: `n` defaulted first, "Does not match : Int" | `61` |
| 4.5.5's `module M`, `len1` used at `Rational` [probe `r20`] | Legal | `10 % 1` | Refused: `Integer` against `Rational` | `10 % 1` |
| 4.5.5's `M1` with `default (Int, Double)`, `M2` using `len1` at `Rational` [probe `r20b`] | Refused | Refused | Refused | Accepted, `10 % 1` |

Both probes use a local `genericLength` of type `Num a => [b] -> a`, for 4.5.5's example does not type against chapter
17's own signature (R48).

GHC alone gets all three. Hugs's early defaulting is behind `Array/timeLargeArray`, and 30 candidates of E8 are
refused by Hugs alone; those read by hand are this case, the rest [inferred]. nhc98's `buildDefaults` per group
(`nhc98/src/compiler98/Type/Type.hs:294,385`) [read] does not predict its behaviour: it does not default early here,
and it lets Rule 2's own example through.

**rhc (D32):** as GHC, defaulting at the end of the module (`simplifyTop`, `applyMR`,
`ghc/compiler/GHC/Tc/Solver.hs:131,1527`). In a cycle there are two candidate `default`s: *Modules*, D30.

#### R21. Declaration groups: one context for all, and signatures do not cut dependencies

> When typing overloaded definitions, all the overloading constraints from a single declaration group are collected together, to form the context for the type of each variable declared in the group.

> If the programmer supplies explicit type signatures for more than one variable in a declaration group, the contexts of these signatures must be identical up to renaming of the type variables.

> If a given program includes a signature for a variable f, then each use of f is treated as having the declared type.

(a) Taken literally the first makes a variable ambiguous in a group whose members have different type variables. (b)
The second refuses reasonable programs. (c) 4.5.1 makes groups by binding alone, and a signature does not cut one, so
mutually recursive `f` and `g`, both signed, are a group; yet 4.4.1 says each use has the declared type, and its
polymorphic recursion example needs that.

- **(b) is enforced by no oracle:** `f :: Eq a => ...` and `g :: Ord a => ...`, mutually recursive, are accepted by
  all three [probe `r21`].
- GHC quantifies per binder (`ghc/compiler/GHC/Tc/Gen/Bind.hs:902,942`) [read].

**rhc (D32):** the explicit and implicit split of Typing Haskell in Haskell gives (c). Whether (b) is refused, under a
strict flag or at all, is marked for the owner. On the Report's own libraries the question does not arise: 0 recursive
value groups (E16).

#### R22. The conditions on defaulting

> at least one of these classes is a numeric class, (that is, Num or a subclass of Num), and

> all of these classes are defined in the Prelude or a standard library

The words "standard library" take in `Ix` and `Random`. A user class blocks defaulting, even if it holds of `Integer`.

- **GHC** `standardClassKeys` (`ghc/compiler/GHC/Tc/Solver/Default.hs:1071-1074`), **Hugs** the rule in its comment
  (`Hugs/src/preds.c:1012-1050`) [read].
- **nhc98** has no numeric test: `findDefault` takes the first type with all the instances
  (`nhc98/src/compiler98/Type/Ctx.hs:200-203`) [read]. `read/1x23` confirms it: on `print (reads "1x23")`,
  `(Show a, Read a)` with no numeric class, GHC and Hugs refuse and nhc98 prints `[(1,"x23")]` [run], which is what
  its suite records as expected.

**rhc:** the Report's text, and that program is refused.

#### R36, R37. What `catch` sees, and how a program ends

> When evaluated, errors cause immediate program termination and cannot be caught by the user.

> the catch function establishes a handler that receives any exception raised in the action protected by catch.

> If a program terminates as a result of calling error or because its value is otherwise determined to be _|_, then it is treated identically to the computation exitFailure.

> Before the program terminates, any open or semi-closed handles are first closed.

`catch` sees `IOError` only and `error` is not catchable, which is consistent, and is what lets looping on re-entry
conform. But `bracket` is built on `try`, so it skips its release on `error`, despite 21.1's "deallocation step must
occur even in the case of an error during computation". And 3.1's "immediate" goes against closing every handle:
buffered output is flushed by chapter 23 and lost by a literal 3.1.

- **`catch` around `error`:** not caught on any of the three [probe `r36`].
- **Buffered output before `error`:** written by all three [probe `r37`]. So all follow chapter 23.
- **Exit status:** GHC 1, Hugs 1, nhc98 255 [probe]. The Report says only that "exitfail" is
  "implementation-dependent". Hugs writes its message to standard output, the other two to standard error [probe].
- GHC's `Control.Exception.catch` does catch `error`, an extension [read]; the shim's Prelude `catch` does not
  [probe]. Hugs's rethrows anything else (`Hugs/libraries/hugsbase/Hugs/Prelude.hs:1754-1757`) [read].

**rhc:** chapter 23: close and flush, status 1, message to standard error. `error` is not an `IOError`. D12 rests on
this.

#### R41. `Read`, `Show` and records

> If the constructor is defined using record syntax, the derived Read will parse only the record-syntax form, and furthermore, the fields must be given in the same order as the original declaration.

The Report gives no figure for a record, and lists "braces, commas, field names, and equal signs" without saying where
spaces go. Open: the precedence at which a record is parenthesised, the precedence of a field's value, operator
fields, `C {}` for a record constructor with no fields. "0 to 10" for `readsPrec`'s precedence goes against Figure
10.1, which calls `readsPrec (app_prec+1)`, that is 11.

| | Parenthesised at | Field value at | `show (C 1 (-2))` | `show (Just (C 1 2))` |
|---|---|---|---|---|
| GHC | d >= 11 | 0 | `C {x = 1, y = -2}` | `Just (C {x = 1, y = 2})` |
| Hugs | Never | 0 | `C {x = 1, y = -2}` | `Just C {x = 1, y = 2}` |
| nhc98 | d > 9 | 10 | `C{x=1,y=(-2)}` | `Just (C{x=1,y=2})` |

The spacing is also [run: `fields/operator`, `fields/showread`, `fields/type`]; the rest of the table is [probe
`r41`]. It agrees with the sources: GHC `ghc/compiler/GHC/Tc/Deriv/Generate.hs:1133,1237,1299`; Hugs
`Hugs/src/static.c:3456-3485`; nhc98 `nhc98/src/compiler98/Derive/Show.hs:121-150`,
`nhc98/src/compiler98/Derive/Read.hs:112-114`.

**All three differ on text a program prints, so no oracle can settle it,** and any `conformance98` or nofib output
that prints a record is implementation-specific. **rhc (D33):** GHC's row, which Haskell 2010 took [memory].

#### R42. `showsPrec` and negative numbers

> The representation will be enclosed in parentheses if the precedence of the top-level constructor in x is less than d.

> The result of show is a syntactically correct Haskell expression containing only constants, given the fixity declarations in force at the point where the type is declared.

The Report's code is `instance Show Float where showsPrec p = showFloat`, and `Show Double` the same: `p` is dropped,
so `show (Just (-1.5))` is `Just -1.5`, which is not the expression meant. `Integer` is right, by
`showSigned showInt`, so the same program differs by type. Derived `Read` copes only because `readSigned` ignores `p`
as well.

All three depart from the Report's code, in the same way: `Just (-1.5)` for `Float` and `Double` [probe `r42`]. GHC by
`showSignedFloat` (`ghc/libraries/ghc-internal/src/GHC/Internal/Float.hs:636,1694`), Hugs in `Hugs/src/printer.c:316`,
nhc98 by `showSigned showFloat` (`nhc98/src/prelude/PreludeText/Show_Float.hs:6`) [read]. Of the copies only jhc keeps
the Report's text (`jhc/lib/jhc/Prelude/Text.hs:50-54`), so it should print `Just -1.5` [inferred, not run].

**rhc:** parenthesise, 10.4's text over chapter 8's code: the case where a literal Prelude is wrong and every oracle
agrees that it is. An overlay entry, pinned.

#### R5, R38. Unicode

> Characters not in the category ANY are not valid in Haskell programs and should result in a lexing error.

> For the purposes of Haskell, any alphabetic character which is not lower case is treated as upper case (Unicode actually has three cases: upper, lower, and title).

`ANY` is `graphic | whitechar`, and `graphic` holds letters that have case, symbols, punctuation and decimal digits. A
letter with no case (all of CJK, Hebrew, Arabic), a modifier letter, a mark or a letter number is in no class, so by
the letter it is a lexing error, **even in a comment or a string**. And `isAlpha c = isUpper c || isLower c` is the
Report's code with `isUpper` primitive, so by the sentence above `isUpper` of a CJK letter is `True`.

| Probe | GHC | Hugs | nhc98 |
|---|---|---|---|
| A CJK letter in a comment [`r5`] | Accepted | Accepted | Accepted |
| `isUpper`, `isLower`, `isAlpha` of U+4E2D [`r38`] | False, False, True | False, False, True | False, False, False |
| `fromEnum (maxBound :: Char)` [`r38`] | 1114111 | 1114111 | 255 |

So no oracle follows the sentence, and GHC and Hugs break the Report's `isAlpha` law. GHC extends the lexer's classes
(`ghc/compiler/GHC/Parser/Lexer/Interface.hs:101-107`) and has `isUpper` Lu or Lt only
(`ghc/libraries/ghc-internal/src/GHC/Internal/Unicode.hs:262`); Hugs likewise (`Hugs/src/char.c:168`); nhc98's `Char`
is 8-bit (`nhc98/src/prelude/Prelude/Bounded_Char.hs:5`) [read].

**rhc (D21):** any character in comments and literals, a stated deviation on the ground that the text is wrong here
(D38); identifiers by the Report's classes, or
GHC's extension for a stated reason. The Report's law on a frozen version named in the documents: the citation is
Unicode 3.0, 2.1 opens it to later ones, and Rune's `lib/unicode` is at 18.0.0 (`lib/unicode/grapheme_data.sml:18`).
Whether `Char` holds surrogates is marked for the owner.

#### What E7's conformance run adds

82 tests, 48 disagreements: 20 hard, 16 not Haskell 98, 7 oracle gaps, 5 environment (E7, `disagreements.tsv`). The
hard ones are where a reading is needed, all [run]:

| Tests | Program | The Report | GHC | Hugs | nhc98 | Reading |
|---|---|---|---|---|---|---|
| `infix/minus` | `3 * -4` | Refused: `*`'s right operand is `exp8`, and a negation is `lexp6` | Refused | Accepted | Accepted | R10 |
| `listindex` | `xs !! -1` | Refused, likewise | Refused | Accepted, fails running | Accepted, fails running | R10 |
| `numbers/negliteral` | `-2 :: N`, a user `Num` | `negate (fromInteger 2)`, by 3.4 | That | `FromInteger (-2)` | That | R10 |
| `layout/do` | `f a b = do a == b` | Legal: `do {e} = e`, at type `Bool` | Accepted | Refused: "Type error in final generator" | Accepted | None yet |
| `import/emptyprelude` | `import Prelude ()`, then `:` and `()` | Legal: built-in syntax stays (5.6.2) | Accepted | `:` undefined | `()` undefined | R32 |
| `import/specialchar` | `import Prelude([](..))` | Refused by the grammar; the harness's "accept" was its default | Refused | Refused | Refused | R34 |
| `read/1x23` | `print (reads "1x23")` | Refused (4.3.4) | Refused | Refused | Prints `[(1,"x23")]` | R22 |
| `fields/operator`, `showread`, `type` | Derived `Show` of a record | Silent on spacing | `Hash {(#) = 3}` | `Hash {(#) = 3}` | `Hash{(#)=3}` | R41 |
| `Array/timeLargeArray` | `(!1)`, and a restricted `size = 60` | Legal | Refused: a bang pattern in every mode | Refused: R20 | Accepted | R20 |
| `Enum/succ` (2), `numbers/floatdouble`, `integerdouble`, `subtract`, `parsing/rational_lits` | `show` of `Float`, `Double` | The Report's `showFloat` form | That | `1.0e+20`; 7 and 15 digits | That | None yet |
| `ctxsimpl` | Context `Eq (m a)` | Legal (4.1.3) | Accepted | Accepted | Refused; the suite calls it an nhc98 bug | None |
| `identifiers/twiddle` | `foo@(~(x,y)) = (1,2)` | Legal | Accepted | Accepted | Refused: the suite's expectation records that | None |
| `infix/derived` | Derived `Read`, infix constructor | Legal | Accepted | Accepted | Heap or time exhausted | R43 |

So in the hard cases GHC is on the Report's side but for `(!1)`, and each of Hugs and nhc98 has its own departures.
That is why D52 makes GHC-strict and Hugs the judges and nhc98 third, and why neither judge settles a case alone.

Three more came from E10's crafted cases and are in no reading. `f = x where`, then `{ x = 1 }` on a new line at
column 1: `L` gives a `;` before the brace, so the Report refuses it; Hugs, MicroHs and the spike refuse, GHC and
nhc98 accept [run: `where-brace-col1`]. `(1 + - 2)` behaves as `3 * -4` [run: `minus-after-op`]. nhc98 refuses a legal
`( funlhs ) apat` [run: `funlhs-paren`].

The rest of the 54, by what they are: lexing corners R4, R6, R8; expressions and patterns R9, R11 to R17; declarations
R19, R23 to R25, R27, R28; modules R26, R29 to R34, below; runtime R35, R39, R40, R43 to R46; library text and smaller
matters R47 to R54. R15, R21 and part of R38 are marked for the owner's call.

**The owner's calls of 2026-11-10.** R4: as its seed reads it, with each acceptance recorded as a deviation from the grammar taken literally, pinned by a program: a line comment that ends the file without a newline is accepted (end of file ends it); vertical tab and the other Unicode white space in a line comment are accepted, a vertical tab counting one column; an empty file is the module `Main` with no `main`, refused by chapter 5's rule, not by the grammar. R15: `n+0` is refused, as Hugs refuses it, by 3.17.2's "positive integer literal" over the grammar's `integer`; GHC and nhc98 accept it. R52: 9.4's `readLine` is a mistake in the Report, recorded as such; the example is tested with `getLine`, its likely meaning.

### What the Report does not say and a compiler must decide

Chapter 1 reserves the ground:

> We leave as implementation dependent the ways in which Haskell programs are to be manipulated, interpreted, compiled, etc. This includes such issues as the nature of programming environments and the error messages returned for undefined programs (i.e. programs that formally evaluate to _|_).

Beyond that, these are matters a program can observe, or a compiler cannot avoid, and the Report leaves open:

| Matter | What the Report has | Where it is settled |
|---|---|---|
| Source encoding | A character set, not a file format. A BOM and non-UTF-8 bytes are silent; 5 files of the nofib trees hold such bytes, and E10's spike reads them as Latin-1 | R5, M11 |
| `\end{code}` with no `\begin{code}`; an unterminated `\begin{code}` | Silent. GHC and the spike give an error on the first | R53, M11 |
| Module names to files, finding imports | "not defined by this report" (5.7) | M12 |
| `Char`'s width and `maxBound` | `primUnicodeMaxChar` has no value | D21 |
| Which Unicode version | Cites 3.0; 2.1 opens it to any later | D21 |
| `Char` above 255 in a file | Nothing | D21, D25 |
| `Int`'s range and overflow | At least [-2^29, 2^29 - 1], and exceptional results "undefined" (6.4) | R54, D22 |
| `Float` | "implementation-defined" | R54, D23 |
| Integral division by zero, any rule at all for `Integer` | Laws for non-zero `y`; 6.4's sentence covers only fixed precision | R45, D20, D22 |
| NaN and infinity in `round`, `floor`, `toRational` | Nothing | R45, D23 |
| Call-by-need | Never defined: *The chapter 3 translations*, item 19 | D34; `--count` is rhc's rule |
| Which bottom, when several are possible | Nothing [inferred] | R35 |
| Exit status | "exitfail" is "implementation-dependent" | R37 |
| Spacing in derived record `Show`; precedence of records and field values | Nothing | R41, D33 |
| Tuples beyond 15 | 15 is the required minimum | R51, M17 |
| When defaulting and context reduction run | "discovered"; no timing | R20, D31, D32 |
| `default` in a module cycle | "default declarations scope over a single module" | R20, D30 |
| Elaboration of classes | Nothing | D31 |
| Stack depth | Nothing | D18 |
| Default buffering | "The initial buffer mode is implementation-dependent." | D25 |
| Error message text | Implementation dependent (1) | M17 |

### Modules

**Mutual recursion.** Chapter 5 says it without condition, and gives it as a purpose:

> Modules may be mutually recursive.

> Because they are allowed to be mutually recursive, modules allow a program to be partitioned freely without regard to dependencies.

It also gives the meaning of a multi-module program, which covers a cycle:

> A multi-module Haskell program can be converted into a single-module program by giving each entity a unique name, changing all occurrences to refer to the appropriate unique name, and then concatenating all the module bodies

> First, default declarations scope over a single module (Section 4.3.4). Second, Rule 2 of the monomorphism restriction (Section 4.5.5) is affected by module boundaries.

Section 5.7 is the whole of what is said on compiling one:

> Depending on the Haskell implementation used, separate compilation of mutually recursive modules may require that imported modules contain additional information so that they may be referenced before they are compiled. Explicit type signatures for all exported values may be necessary to deal with mutual recursion. The precise details of separate compilation are not defined by this report.

So an implementation may ask for more information. It is unclear that it may refuse an otherwise legal program, and
the owner's deviation rule does not cover refusal: this is neither wrong nor contradictory. Recursive modules are
language, expected to be supported (D30), and not on any cut list.

No oracle does this as written (R29):

| | Plain cycle `A`, `B` [probe `r29`] | As documented [read] |
|---|---|---|
| GHC | Refused: "Module graph contains a cycle" | Hand-written `hs-boot` files |
| Hugs | Refused: "Recursive import dependency" (`Hugs/src/script.c:249`) | Not at all |
| nhc98 | Refused: "Cycles", then no `B.hi` | A hand-written `.hi` (`nhc98/docs/interface.html:19-23`) |

Rune's `Deps` refuses a cycle too (`lib/compiler/driver/deps.sml:270`). Of E8's candidates none has a plain import
cycle. 7 use `{-# SOURCE #-}`, and on those GHC accepts only `rn017` and the other two none (`E8/judged.tsv`). So
recursive modules have no independent oracle, and their tests are written by hand from the Report (D52). Boot files
cannot express every legal cycle (E15, an argument and one tested arrangement).

Concatenation gives the semantics, and one unit per SCC follows it. What it leaves open:
- **Which fixpoint.** Chapter 5 defines exports by what is in scope, circularly, and does not say which solution. E16
  shows the solution need not be unique (*The literal layout*).
- **Kinds across a cycle (R28).** "Defaults are applied to each dependency group", and a group spanning a module
  boundary has no stated treatment. Grouping over the SCC is the natural reading [inferred].
- **`default` and Rule 2 across a cycle (R20).** By chapter 5 each module has its own `default`, so a monomorphic
  variable reached across a cycle has two candidates. No implementation gives each module its own: Programatica
  rejects differing ones, jhc ignores `default` (E15). Rhc needs a rule of its own for `default`, and Rule 2 closes at
  the end of each module, as 4.5.5 says, with the end of the SCC an alternative outside the deviation rule (D30).

**Instances.** The two statements do not fit together (R26):

> A type may not be declared as an instance of a particular class more than once in the program.

> Thus, an instance declaration is in scope if and only if a chain of import declarations leads to the module containing the instance declaration.

Two modules with no import path between them can each declare `instance K T`, and neither sees the other. But every
module of a linked program is reached from `Main`, so by 5.4 `Main` at the latest has both in scope [inferred]: the
clash is checkable at the first common importer, and is not whole-program in the strict sense. What the oracles do
[probe `r26`, `r26u`]:

| Two instances, one program | GHC | Hugs | nhc98 |
|---|---|---|---|
| Unused | Accepted, runs | Refused on load: "Overlapping instances" | Refused at link: a duplicate symbol |
| Used in `Main` | Refused at the use: overlapping instances | As above | As above |

GHC checks per module against instances in scope (`ghc/compiler/GHC/Tc/Utils/Instantiate.hs:1030`) and so lets the
unused pair through, against 4.3.2. nhc98's refusal is a linker's, not a check [inferred]. **rhc:** check at link,
where it has all units; a check at the common importer would give an earlier message. Under recursion "chain" is
circular, and each module of an SCC sees all of its instances [inferred]. Instances cannot be hidden: "It is not
possible, however, to hide instance declarations in the Prelude." In the Report's own libraries all 112 instances
reach every program through the Prelude, and 21 of them name a class or type the Prelude does not export, so a program
cannot observe those [inferred] (E16).

**The Prelude's implicit import** (R32):

> The Prelude module is imported automatically into all modules as if by the statement `import Prelude', if and only if it is not imported with an explicit import declaration.

The text is plain and has consequences. `import qualified Prelude` is explicit, so unqualified Prelude names vanish.
GHC tests for any Prelude import (`ghc/compiler/GHC/Parser/Header.hs:125,130`), Hugs for unqualified imports and
aliases (`Hugs/src/static.c:7034-7038`): the same result by another route [read]. `import Prelude ()` leaves built-in
syntax in place, by 5.6.2:

> The special syntax for tuples (such as (x,x) and (,)) and lists (such as [x] and []) continues to refer to the tuples and lists defined by the standard Prelude; there is no way to redefine the meaning of [x], for example, in terms of a different implementation of lists.

Only GHC keeps `:` and `()` here (`import/emptyprelude`, above). The Prelude's sub-modules must be refused:

> These modules are not part of Haskell 98, and they cannot be imported separately.

E16 did that with a list of modules and a few lines of `check`, refused outside the library
(`results/E16/tests/hidden.out`). Two more things follow from the Prelude being an ordinary module. "It is possible to
construct and use a different module to serve in place of the Prelude", and a user's module may have a library
module's name: `nhc98/tests/nofib/real/infer` has its own `module Maybe`, which under the literal layout meets the
module of that name in the Prelude's closure, so a module's identity must include its library (E16). Dropping
`Array`'s dead import removes that case; `Char` and `Numeric` stay exposed. And the Prelude must not import itself: on
Programatica's copy, whose Prelude exports `module Prelude`, a literal self-import gives 792 pairs from below and
1,181 from above, and without it 792 from both (D29). Separately, 5.6 lets a compiler treat these modules specially:
"a compiler may optimize calls to functions in the Prelude without consulting the source code of the Prelude."

**Smaller points.**

| Reading | Point | GHC [read] | Hugs [read] | nhc98 [read] | Seed |
|---|---|---|---|---|---|
| R30 | `module M` in an export list: the alias or the module? | Alias (`ghc/compiler/GHC/Tc/Gen/Export.hs:398-399`) | Alias (`Hugs/src/module.c:895-908`) | Not read | Alias |
| R31 | Hiding what is not exported | A warning (`ghc/compiler/GHC/Rename/Names.hs:1272`) | An error (`Hugs/src/module.c:371`) | No check (`nhc98/src/compiler98/PreImport.hs:229`) | An error, as the Report |
| R33 | "by convention, must": `main` imported, re-exported | | | | Legal; a type not `IO t` is a static error |
| R34 | `modid` is one `conid`, so `Data.List` is outside the language | | | | Flat by default, a flag for the corpus (D35) |

### The libraries

**How literal they can be.** `results/E9/report-libs/extract.py` extracts 20 modules, with no hand edits, plus 12
interface synopses and 52 examples from the text. 17 of the 20 reach GHC's renamer with no parse error, and Directory,
Prelude and PreludeIO stop on the Report's own `...`. Left out of the code: 66 literal `...`, 24 uses of `prim*`
names, 69 signatures with no binding. `literal.py` classifies 528 definitions, a signature with its binding counted
once (`literal.tsv`):

| Module | Literal | `...` | Primitive | Not legal | All |
|---|---:|---:|---:|---:|---:|
| Prelude | 74 | 37 | 3 | 4 | 118 |
| PreludeList | 56 | 0 | 0 | 0 | 56 |
| PreludeText | 28 | 0 | 0 | 0 | 28 |
| PreludeIO | 8 | 3 | 9 | 0 | 20 |
| Ratio, Complex, Array | 46 | 0 | 0 | 3 | 49 |
| Numeric, Ix, List, Maybe, Monad | 116 | 0 | 0 | 0 | 116 |
| Char | 19 | 0 | 6 | 0 | 25 |
| IO | 10 | 4 | 38 | 0 | 52 |
| Directory, System, CPUTime | 2 | 4 | 21 | 0 | 27 |
| Time, Locale, Random | 12 | 20 | 5 | 0 | 37 |
| **All** | **371** | **68** | **82** | **7** | **528** |

**So 371 of 528 (70%) can be literal in form, and 166 of the 222 in the four Prelude modules (75%).** The
classification is by form: it counts a definition the overlay must change as literal. The rest is the primitive
surface:
- types: `Char`, `Int`, `Integer`, `Float`, `Double`, `IO`, `IOError`, `Handle`, `HandlePosn`, `ClockTime`, `StdGen`,
  and the built-in syntax of `()`, lists, tuples and functions;
- all instances of `Int`, `Integer`, `Float`, `Double` but `Enum Float`, `Enum Double`, and `Show` and `Read`: 29 of
  `...`;
- `seq`, `primError`, `(>>=)` and `return` of `IO`, the `Char` conversions and `primUnicode*`;
- PreludeIO's nine primitives; whole interfaces with no code: IO's handles (38 names), Directory (13), System (6),
  CPUTime (2), Random's generator;
- `PreludeBuiltin` and `UnicodePrims`, named in the code and defined nowhere.

**The overlay** the exit test must list, beyond that surface (D37). About 15 named definitions [counted by hand]:

| Item | Why | Reading |
|---|---|---|
| `Show Float`, `Show Double` | Drop the precedence | R42 |
| `getLine` | The Prelude's loop raises on end of file in mid-line; 21.9.2 returns the partial line | R46 |
| `interact` | Uses four names `PreludeIO` never imports | R47 |
| `numericEnumFrom...` in Ratio | Four names the Prelude does not export: "but not exported from it!", as Ratio's comment says | R47 |
| `data ()`, `[a]`, `(a,b)`, `(a,b,c)` | Not legal Haskell | R47 |
| Tuple instances to size 15, `Ix` too | Only 2 and 3 are given | R51 |
| `numericEnumFrom`, `numericEnumFromThen` | Erratum of May 2003 | R39 |
| `lex` | Erratum of February 2003 | R43 |
| `genericTake`, `genericDrop`, `genericSplitAt` | Erratum of September 2008 | R48 |
| `MkArray (a,a) (a -> b)` | `Array` as a function fails the "rapid access" chapter 16 expects: a change of representation | R49 |
| `import UnicodePrims`, `PreludeBuiltin` | Stand for rhc's primitives | |
| `Read IOError`, the `isAlpha` law, `gcd`, `Ratio`'s messages | Text and code disagree: no change, or the owner's call | R47, R38 |

The Report's prose and code also disagree where no overlay is needed: `showFFloat`, `StdGen`'s `read (show g) == g`
with no `Eq StdGen`, `calendarTimeToString`, `doesFileExist`, and 4.5.5's `genericLength` against chapter 17's (R48,
R49). Tests must pin one side of each.

**The local copies.** No copy is the Report. E9 compared the 742 definitions of the Report, each signature, binding,
class, instance, type and fixity separately, with each copy, after dropping comments, CPP lines, white space and
`Prelude.` qualifiers (`results/E9/copies/`). A rename counts as different, and this is a textual fact, not one about
behaviour.

| Copy | Same | Differs | Absent | Same in the Prelude's four |
|---|---:|---:|---:|---:|
| jhc | 484 | 176 | 82 | 176 |
| nhc98 | 473 | 234 | 35 | 207 |
| yhc | 445 | 217 | 80 | 204 |
| Hugs, with `packages/base` and `packages/haskell98` | 445 | 276 | 21 | 218 |
| uhc | 382 | 302 | 58 | 185 |
| Hugs, `hugsbase` alone | 246 | 200 | 296 | 185 |

268 definitions are the same in all five (counting Hugs's wider scan), and 135 in none. The 268 are the safest
differential partners for the literal Prelude; the 135 are where every implementer changed something, and deserve a
look when `share/rhc/haskell98` is written. By reading: nhc98 is the Report's module names as directories, one file
per definition, and 8-bit; yhc is `Prelude.hs` monolithic with `Time`, `Locale`, `CPUTime` and `Random` absent; jhc's
`Show Float` is the Report's text; uhc holds most of the Prelude in `uhcbase/UHC/Base.chs`; Hugs's is
`Hugs/Prelude.hs`, and the directory the brief names lacks `List`, `Maybe` and `Monad`.

**The licence.** From the Report's `index.html`:

> Copyright (c) Simon Peyton Jones. The authors intend this Report to belong to the entire Haskell community, and so we grant permission to copy and distribute it for any purpose, provided that it is reproduced in its entirety, including this Notice. Modified versions of this Report may also be copied and distributed for any purpose, provided that the modified version is clearly presented as such, and that it does not claim to be a definition of the language Haskell 98.

`share/rhc/haskell98` is a modified version: an extract, with an overlay. It may be shipped for any purpose, on two
conditions: it is clearly presented as modified, and it does not claim to be a definition of Haskell 98. rhc's
documents say "implements", never "is". Carrying the Notice is not literally required of a modified version, but it is
the safe reading, and it is what others do: `jhc/lib/haskell98/LICENSE`, `nhc98/COPYRIGHT` and
`Hugs/packages/haskell98/LICENSE`. The PDF's notice opens differently ("The authors and publisher").

It conflicts with Rune's `LICENSE` as a matter of labelling, not of permission. That file is CC0 for the whole
repository, and CC0 waives rights only for an owner and disclaims "clearing rights of other persons" (`LICENSE:113`),
so the owner cannot put those files under it. A reader of the repository would think the two conditions could be
dropped. The fix is D37: `share/rhc/haskell98/LICENSE`, carrying the Notice and a statement of modification, and a
sentence at top level excepting that directory. Not legal advice. Not established: whether a code listing in the
Report is separately protected, and what bytecode that links these libraries owes, which neither text addresses.

### The literal layout and what E16 found

**The graph.** As printed, counting the implicit Prelude import, the Report's code is one 11-module SCC,
`Prelude PreludeIO PreludeList PreludeText Array Char Ix List Maybe Numeric Ratio`, with 9 singleton modules above it
(`results/E9/report-libs/graph.txt`). **The cycle is presentational, not a requirement.** Chapter 8:

> This structure is purely presentational. An implementation is not required to use this organisation for the Prelude, nor are these three modules available for import separately. Only the exports of module Prelude are significant.

> These imports are not, of course, part of the specification of the Prelude. That is, an implementation is free to import more, or less, of the Library modules, as it pleases.

Those sentences cover the Prelude's imports. `Char` and `Numeric`, two public modules of Part II, still import each
other, with no such disclaimer; a program sees exports only, so it cannot tell [inferred,
`results/recursion/CORRECTION.md`]. The literal layout is therefore an option, D36, and the owner may follow it. Hugs,
GHC, nhc98, Yhc, jhc, UHC and MicroHs each break the cycle one way or another (*What the implementations do*). E16
priced it.

**Is the cycle real? Mostly not.** E16 built the definition-level graph over the 20 modules with E10's parser, the
`...` forms made parsable (69 lines, `norm.tsv`) and `prim*`, `PreludeBuiltin` and `UnicodePrims` taken as leaves. Its
files are under `results/E16/`. Without inference, instance use can only be bracketed, so GHC typed the merged unit as
one module and its Core gives T, the dictionaries actually used (`analysis-1.txt`, `truth.txt`):

| Graph | Groups crossing a module | Largest |
|---|---:|---:|
| E0, names only: a lower bound | 1 | 4 |
| T, GHC's resolved dictionaries | 4 | 20 |
| E1, class meets type: an estimate | 5 | 72 |
| E2, every instance: a bound on what is reached | 5 | 187 |

E1 overstates heavily: of its 1,063 definition-to-instance edges 172 are true and 891 spurious, and it misses 24. T's
closure lies inside E2's from every definition, with 0 exceptions, though 16 of T's edges are not edges of E2
(`truth.txt`). **There is no top-level mutual recursion among values anywhere in the 20 modules:** by 4.5.1 taken
literally, no value group is recursive through more than one binding, and none crosses a module. T's groups are three
of numeric dictionaries, of 20, 11 and 7 nodes, and one of types:
- `Show` at a numeric type calls Numeric, which needs that type's `Integral` or `RealFloat`, whose superclasses reach
  `Num` and then `Show` again. `Show` as a superclass of `Num` holds all three (`holds.txt`).
- `Real`, `Integral`, `Ratio`, `Rational`, held by the data context on `Ratio`.

Other facts of the graph:
- `import List((\\))` in `Array` is dead. Without it, List and Maybe leave, and the import SCC is 9 modules, not 11.
- With the Prelude's family as one module, as chapter 8 allows, 26 definition edges break the cycle: to Ratio 4, to
  Char 8, to Numeric 11, and Char to Numeric 3.
- Moving `Show Float` and `Show Double` alone changes nothing. It takes all numeric `Show`, all `Read`, `lex`,
  `words`, `Show Char`, the `Rational` edges and `readEsc` together.
- A layered layout must place 59 definitions, 329 lines, beneath the Prelude, making a bottom layer of 1,720 of the
  2,436 lines.

**The checker.** 7 of 311 values are unsigned: `arrPrec`, `asciiTab`, `protectEsc`, `maxExpt`, `minExpt`, `ratPrec`,
`reduce`. None is exported, used from another module, or in a group crossing one. All 887 cross-module value edges
land on signed values (415) or methods (472). Instance bodies do not order inference, only instance heads do
[inferred]. So given all the signatures, class heads and instance heads of the unit, values check module by module in
any order. **The flip E16 was set to find does not happen: the literal layout is a scoping problem and one unit-wide
pass over declarations, not an inference problem.** The exception is the four-node type group across Prelude and
Ratio: Haskell 98 has no kind signature, so kind inference must cross that boundary (R28). GHC typed the unit with 0
errors after one annotation, at the only site it could not default, in `floatToDigits` (`ghc/changes.txt`).

**Names** (`hs_modules.sml`, 364 lines, 318 of code).
- The fixpoint exists: 4 rounds from empty, 3 from full, and least equals greatest on the Report's text.
  `PreludeList`, `PreludeText` and `PreludeIO` re-export all their 53, 17 and 18 names, and the Prelude exports 236
  (`resolve.txt`).
- **Uniqueness is not general.** A user module defining `map` gives two fixpoints, of 690 and 693 pairs, for `map`
  circulates between Prelude and PreludeList; renaming it gives one (`tests/imp.out`, `tests/gfp.out`). Chapter 5 does
  not say which. The rule must say least, as Diatchki, Jones and Hallgren do (D29).
- **8 names do not resolve as printed**, in 10 uses (`graph.raw`): four in `interact` (R47) and the four
  `numericEnum*` in Ratio. Chapter 5 has no remedy. One hidden module moving 14 lines fixes the second set
  (`overlay.py`); importing `IO` for `interact` would make the SCC 12 [inferred].
- Derived `Ix` in `Time` needs methods it did not import, so deriving must name entities, not spellings.
- **Fixity:** 35 declarations, and of 260 uses needing fixity 152 come from another module of the unit. Fixity is an
  attribute of an entity read after names, with no iteration.
- **`default`:** the 20 modules have no declaration (checked), and the unit's 5 restricted bindings are local to their
  modules [E16's report; not recounted].

**What one unit costs a program.** The unit is 525 definitions, 1,436 lines of definitions, 2,436 lines of file.
Elided primitive bodies are not counted (`analysis-2.txt`):

| Program | Reachable in T | Lines | In E2 |
|---|---:|---:|---:|
| `putStrLn "hello"` | 19 (3.6%) | 34 | 24 |
| One `Char` function | 20 (3.8%) | 35 | 25 |
| `print 42` | 111 (21.1%) | 258 | 297 |
| `sort` | 113 (21.5%) | 264 | 299 |

**The three layouts.**

| | The literal layout | The merged layout | Layered |
|---|---|---|---|
| Front end | The fixpoint (needed anyway for D30), a unit-wide declaration pass, a hidden list | One module with no implicit Prelude, a hidden list | A hidden list |
| Cache | An SCC key, one unit | One unit, 11 thin | Several units |
| Dictionary recursion | Across modules | Inside one | In the bottom layer |
| The Report's text | Unchanged, but for the 8 names | Bodies and headers verbatim | 59 definitions move |

**A script joins the first two.** `merge.py`, 47 lines, generates the merged layout from the literal one. None of the
369 names in the 11 modules collide (recounted from `graph.raw`); it changes 2 lines (`Char.isSpace`) and drops 22
import lines. All 20 modules' 663 export pairs, 35 fixities and 164 instances come out identical (`check_merge.txt`).
It resolves Ratio's four names on its own, though not `interact`'s (`merged.raw`). It needs one rule outside the
Report: the internal module has no implicit Prelude. So a mechanical fallback exists if the joined checker runs late,
and D36 compiles the Report's layout directly, since M12 and M13 land before the Prelude first runs.

**Programatica's copy.** Programatica keeps the Report's layout, and its README says its checker passes it [read; its
checker was not run]. If the layout took bending to get through a checker, it would show in that copy. E15 found 1,201
of the 1,511 code lines of the 11 modules the same as E9's text. The E16 addendum read the other 310 by hand, in 111
diff hunks (`programatica/classes-summary.tsv`):

| Class | Hunks | Report lines altered |
|---|---:|---:|
| Older text: their copy predates the revisions | 26 | 78 |
| Primitives or `...` filled in | 21 | 73 |
| Export lists dropped, explicit `import Prelude` | 8 | 44 |
| The Report's bodies removed | 4 | 44 |
| Local rewrites, layout | 26 | 36 |
| Signatures commented out or absent | 14 | 19 |
| `default()` in Numeric and its annotation | 2 | 5 |
| `Rational` moved into Prelude | 2 | 4 |
| Illustrations made legal in their dialect | 3 | 3 |
| Instance contexts changed | 3 | 3 |
| Helpers for their derived-instance generator | 2 | 1 |

**No change adds a signature or moves a definition to get the cycle through a checker. The evidence points the other
way.**
- **Signatures went out, not in.** 24 names signed by the Report are unsigned there, among them `lex`, `array`, `(%)`
  and the six `generic*`; 0 unsigned in the Report gained one. Unsigned top-level values rise from 7 to 40, 16
  cross-module edges inside the SCC land on them, and 3 of those are unsigned depending on unsigned (`sigs.txt`). So
  their copy cannot be checked module by module and relies on the join in `TiModule.hs`. The Report's text has 0 such
  edges: their copy is harder for a checker than the Report.
- **The one move across modules** is `type Rational` into Prelude, with the comment "the type checker refers to
  Prelude.Rational!!!". It concerns the typing of literals, not the cycle. It breaks nothing: their SCC stays at 12
  with `PreludeBuiltin` (recounted from `libs/`), and they add `import Ix` to the Prelude.
- **The one change that touches the cycle's meaning is `default()`,** in Numeric only. `TiModule.hs` takes `default`
  declarations from the joined declarations, so this switches defaulting off for all 12 modules
  (`programatica/src/programatica/tools/base/TI/TiModule.hs:33-35,59`) [read]. Their copy then needs exactly one
  annotation, in `floatToDigits`: the site where GHC needed one, and jhc has it too (`jhc/lib/jhc/Numeric.hs:283`). So
  for the libraries R20's `default`-in-a-cycle problem is one expression; for a user's cycle it stays open.
- **Unexplained:** the 4 removed bodies, the context changes and the commented-out signatures. Nothing in the tree
  says why, and the layout needs none of them, for GHC typed the Report's unchanged text as one unit.

The addendum also dates two things. `interact`'s 4 unresolved names came in with the "Late Dec 2001" revision of the
change list; Programatica's older text has no `hSetBuffering`. And `Array`'s `import List((\\))` is live in their
text, where `//` uses `\\`; the Report's rewrite of `//` left it dead, and the change list has no entry for that
rewrite (searched while writing).

The precedent shows a joined checker passing the layout with more unsigned bindings than the Report has. It shows
nothing about code generation or cost, for Programatica has no back end. Offering the literal layout means a joined
SCC, as there and in jhc: module-by-module checking works on the Report's text, but not on a user's cycle with
unsigned bindings.

**Not established.** T rests on GHC typing a patched copy: built-in types, `Bool` and `Ratio` from GHC, 21 derived
stubs, 47 elided instance bodies, and derived instances by E16's own table of chapter 10. GHC is not rhc. Whether
dictionary recursion across modules needs thunks at link time is open [inferred: only if a unit is split]. The layered
layout was sized, not generated. Real primitive instances may add edges. That Programatica's checker passes today, and
why its bodies changed, are not known.

### What this gives the decisions

- **D38:** the December 2002 text and the 18-entry table above. The worst errors are on no errata page, so the
  deviation rule does more work than the errata do.
- **D53, M1:** 3,901 rows, generated, with classes that are first readings until M1 has run them.
- **D31, D54:** no rule numbers exist. The checker's structure and HsLint's basis come from outside the text, and rows
  can name sections only.
- **D34:** a literal `-O0` is a semantics, not a scheme, and needs care at rules (b), (c), (d) and (g). Its sharing is
  rhc's own rule.
- **D27:** R1, R2, R3 are settled by the grammar-error rule with flat operators, strict `n > m`, and two pinned
  deviations.
- **D32, D33:** on R18, R20 and R41 the recommendation is GHC's row, and the evidence is now run, not read. R21's
  second clause is enforced by nobody and is the owner's to call.
- **D52:** expected results cite clauses. R7's `Just.let` is the case where the Report beats all four oracles, and no
  oracle exists at all for recursive modules.
- **D29, D30:** least fixpoint, no self-import of the Prelude, one unit per SCC. Rhc needs a rule of its own for
  `default` in a cycle, and Rule 2 closes at the end of each module, as the text says.
- **D36, D37:** the literal layout is a scoping problem at a known price, with a derived merged form as the fallback. The
  overlay is listed, with 8 unresolved names among it, and the licence is a labelling fix.

## What the literature says

The papers settle shapes rather than sizes. They say what a lazy language must make explicit before it reaches a strict
machine, what a thunk owes the collector, what Haskell 98's static semantics needs beyond unification, which
optimisations carry the weight, and how little has been done to test a Haskell implementation. No paper measures the
thing this roadmap proposes: a lazy typed Core over a strict typed optimising IR, on a tiered VM. The argument of this
section is that the proposal is well founded in form and unmeasured in cost, and that several things the first plan took
for granted were wrong, in ways the papers show.

E15 read the papers. Every DOI was checked against Crossref on 2026-11-01 (`results/E15/dois.tsv`: 158 of 159 agree, and
the 159th differs only by markup in Crossref's title). The notes are in the drafts, `results/E15/lit/`, one block per
paper with what it says, on what evidence, and verbatim quotations. Eleven readers did the reading, so the notes are one
step from the papers; E15's lead audited 24 random cells of the implementation table and the claims that contradict the
plan against source or paper. Quotations below were checked against the paper texts again for this section. They come
from the version read, which *References* names and which is not always the published one. Source paths `ghc/`,
`ocaml5/`, `smlnj/` are under `/home/ruud/reference`; Rune's are against `b12141ecc`.

**Status of a reference.** *References* gives each one's status: **full**, **sections** (which ones), **abstract**, or
**memory**, which means no text was seen and the claim comes from the reader's memory or from other papers. Below, a
paper with no mark was read at least in the sections cited. **[abstract]** and **[memory]** mark the rest where they are
used, and *second hand* says whose account is being repeated. The five papers a decision leans on most that E15 could
not read, Faxén 2000, Augustsson 1993, Augustsson 1985, Sparud 1993 and Röjemo 1995, the owner supplied on 2026-11-09
with most of the rest. E15b read them; its notes give a page or section for every claim, one file per paper
(`results/E15b/P1/`, `P2/`, `P3/`, mapped in `results/E15b/map.tsv`). *References* lists what is still missing.
**[inference]** marks a step of a reader's or the writer's: no paper says it. A bare number such as 3.1 is a section of
the Report, and §3.1 a section of the paper named.

**The age of the evidence.** Most run-time figures below are 15 to 35 years old, on native code. None predicts Rune's
VM. Rates of updates and thunks are properties of programs and compilers and age moderately, though GHC's optimiser has
changed them. Cache, predictor and pipeline figures belong to their machines. The only interpreter figures are Hartel et
al. 1996, Sestoft 1997, Seward 1992's G-machine interpreter, Röjemo 1995's factor of four for nhc's bytecode, and Rohou
et al. 2015's on dispatch; the only JVM figures are Wakeling 1999; the only JIT figures are Schilling 2013's, a tracing
JIT. So a figure here ranks a mechanism and sizes nothing. Rune's own numbers are in *The experiments*. The papers that
carry numbers:

| Paper | Machine and compiler | Programs |
|---|---|---|
| Appel 1989 | VAX-8650, SML/NJ, 1988 | the SML compiler |
| Hammond, Blott 1990 | Sun-3/60, a prototype Haskell compiler against Chalmers LML | 4 small programs |
| Richard Jones 1992 | unnamed, a G-machine | 7 small programs |
| Peyton Jones 1992 | unnamed, early GHC, no optimiser | one type checker, 600 lines |
| Sansom, Peyton Jones 1993 | Sun 4/60, 12 MB, GHC | hsc, anna, pic, primes |
| Peyton Jones, Partain 1993 | SPARC 10, GHC of November 1993 | 17 nofib real |
| Augustsson 1993 | SparcStation2, hbc, collection excluded | 6, transformed by hand |
| Santos 1995 | SPARC counts, ghc-0.23 | nofib |
| Hartel et al. 1996 | SUN 4/690, 25-odd compilers | Pseudoknot alone |
| Peyton Jones et al. 1996 | SPARC counts, ghc-0.26 | 15 real |
| Gill 1996 | instruction counts, GHC 0.26 | nofib, 52 |
| Sestoft 1997 | 486DX4/100, SML/NJ 108.13 | primes |
| Boquist 1999 | UltraSPARC-I 140 MHz, ghc 4.01, hbc | 16, single-file, overloading removed by hand |
| Wakeling 1999 | 143 MHz UltraSPARC, JDK 1.2 | small programs |
| Faxén 2000, 2001 | Sun Ultra 5 at 270 MHz, Shade counts, a prototype compiler for "Plain" | 8 and 6, up to about 700 lines |
| Ennals, Peyton Jones 2003 | Pentium III, GHC of 2003 | 21 programs |
| Cheadle et al. 2004 | 500 MHz Pentium III, GHC 6.2 | nofib, 36 |
| Marlow, Peyton Jones 2006 | 1 GHz Pentium III, about GHC 5.04 | nofib, 88 |
| Marlow et al. 2007 | Opteron 250, 2.4 GHz Xeon, GHC of 2007 | nofib, 91 |
| Sergey et al. 2014 | i7, GHC of 2014 | nofib |
| Rohou et al. 2015 | Nehalem, Sandy Bridge, Haswell | interpreters: Python, JavaScript, CLI |

### Where the literature corrects the plan

"The plan" here is the campaign's first plan, `plan.md` in the drafts, as E15 read it. Most of this has since gone into
*Decisions*; the list records what changed and why. The strongest come first.

1. **Haskell's thunks and lazy ML's differ elsewhere (D12, D57).** The plan named three differences: a raising body
   re-run, re-entry undetected, effects in bodies. Report 3.1 says of errors "When evaluated, errors cause immediate
   program termination and cannot be caught by the user." So no Haskell 98 program forces a thunk again after its body
   raised: re-run and memoise are alike unobservable. Re-entry is bottom, and looping conforms. The real difference is
   one action, releasing the closure.
2. **Release need not happen at entry (D12).** Peyton Jones 1992 §9.3.3 shows it is enough to do it by the next
   collection.
3. **The plan did not name the precondition for release, and Rune fails it (D12).** Black-holing helps only if the
   running code no longer reads the closure. Rune's code reads free variables through the frame's closure, which is a
   root. E2 ran Jones's `last` leak on Rune.
4. **The collector is not simply shared (D57).** Rune's `K_IND` shortcut is wrong for `'a susp susp`. Haskell cannot
   reach it; lazy ML can. E2 confirmed it.
5. **That Mid's passes stay valid holds for safety, not for sharing (D3, D51).** A distinct type stops a blind read. It
   does not stop a pass copying a thunk.
6. **`Any` must mean evaluated (D4).** If it may hold a thunk, a forgotten force at a polymorphic position is invisible.
7. **E3's 5% threshold has no source and tests something else (D15).** Marlow and Peyton Jones argue from complexity at
   equal speed, and dropping eval/apply on Rune would mean literal currying, which they never measure.
8. **"like GHC's dynamic pointer tags" overstates code 11 (D16).** Most of the tagging gain is not available to one code
   over an in-object header.
9. **Core needs a simplifier, with eta, and the plan omitted both (D47, D48).** Every strictness and floating figure was
   taken with a simplifier running after the pass in the same IR.
10. **The specialiser and strictness cannot be cut apart (D49, D50).** On `sum = foldl (+) 0` an unknown `(+)` hides
    everything from the analyser (Augustsson 1993, §5.3).
11. **"Decision trees" can only mean Sestoft's order (D34),** and Rune's `trees` cannot be reused as it stands.
12. **HsLint's basis is half right (D54).** Neither Faxén nor THIH checks elaborated output, and a target check cannot
    see ambiguity.
13. **That Haskell 98 has no local assumptions is wrong as a reason, and its conclusion right (D31).** Haskell 98 has
    local class givens. It has no local equalities. It belongs to qualified types, not HM(X).
14. **Coherence has no proof for Haskell 98 (D32).** The conformance reading of the monomorphism restriction must be
    stated as an algorithm.
15. **Derived code may come before type checking; derived contexts cannot (D33).**
16. **`--count` budgets cite no clause (D52).** The Report never requires call-by-need.
17. **The plan had no generator and no metamorphic relations (D55).**
18. **`-O0` is a reference only by audit (D52),** and `conformance98` is the nearest thing to a suite, not a good one.
19. **"Extra information as 5.7 allows" is two options (D30):** boot files, which are incomplete, and signatures in the
    module.

### Hook (D1-D6)

**D1: the hook point.** Two papers argue for this shape. Neither measures it.

Peyton Jones, Shields, Launchbury and Tolmach 1998 ("Bridging the gulf") propose one intermediate language for ML and
Haskell. L1 is "totally explicit": `Int` denotes an unpointed set, `Lift Int` a possibly diverging one, effects are
monads. Its authors reject it as an IL (§3.6). In `let x = e in f x`, eager evaluation is wrong, a thunk breaks `f`'s
right to assume `Int` is evaluated, and a type-directed hybrid fails under polymorphism. L2 is the proposal: eager `let`
and application, a type `<tau>`, a term `<e>`, a `force`, and value types kept apart from computation types. ML
translates as before; Haskell gets `<...>` on arguments and fields, and `force` at variables. They conclude that L1 is
for reasoning and L2 for compiling, modestly: "we emerge with the core of a practical IL". On one IL for both languages
they are mixed: the evaluation model is common, but ML thunks are not L2 thunks (§5.5). It was not implemented, and
nobody says why it was not carried on. On record: Peyton Jones 2001 says keeping the IO monad explicit means "every
optimisation pass must deal explicitly with the new constructs"; Kennedy 2007 replaced MLj's monadic IL with CPS; Downen
et al. 2019 call a move "from a lazy-by-default to strict-by-default intermediate language" "quite a large change for
GHC". The likely reading, an inference from those sentences, is that it was not refuted but was too large a change to a
working Core.

Bolingbroke and Peyton Jones 2009 ("Types are calling conventions", Strict Core) call themselves an extension of L2.
Their transformations are stated as examples: "we have not provided any details about how a compiler would
algorithmically decide"; and "it still remains to implement the language in GHC". Nothing is measured.

Mid plus `susp` is L2 minus its `ST`. It differs in keeping a lazy typed Core above, which the paper did not consider
(it wanted one optimiser). That avoids L2's two main losses: full beta and free theorems stay in Core, where Haskell's
transformations live. The paper's ground rule, that a common IL must not impose "any unavoidable efficiency penalty", is
a claim this roadmap does not make.

Evidence on strict platforms is thin, and none of it is this hook:
- **Yale Haskell** ran on Common Lisp: overwriting a thunk was "impossible with the Common Lisp runtime system", and
  there was "a factor of 3 to 5 in lazy code that could not be overcome" (Hudak et al. 2007). Lisp of 1995, so a
  direction and not a number. Form A, the ref encoding, repeats that indirection (E2: 1.35 to 1.36 of form C); `K_IND`
  in place is what Yale lacked.
- **Wakeling 1999** on the JVM: see D13.
- **GHC's JS backend** keeps the STG machine with its own stack and a trampoline (`ghc/compiler/GHC/StgToJS.hs:36`): the
  platform is a machine, not a strict language.
- **Eta** maps calls to JVM calls with opt-in trampolining (slides, ICFP 2018; no paper found). **Mu** is a different
  language: "The runtime is strict, but some constructs have lazy operational semantics", laziness comes by pragma, and
  the whole program is monomorphised, with no run-time dictionaries (Dijkstra, Magalhães, Néron 2024, §2.3.1, §2.3.8).
  Its planned pipeline lowers GHC Core into Mu's strict IR and bytecode, the shape of rhc's hook; neither that report
  nor the two slide decks says how laziness is mapped or what it costs. **Frege:** no paper located.

**D2: Core, owned by rhc, and typed.** Support for typing is strong and anecdotal. Peyton Jones and Meijer 1997 (Henk):
after every transformation "the huge majority of transformation bugs can be nailed in short order". Peyton Jones 1996:
"One of the dumbest things we did was to delay writing Core Lint". Hudak et al. 2007: "many, perhaps most bugs in the
optimiser produce type-incorrect code". Tarditi et al. 1996 (TIL), independently, agree. Maurer et al. 2017 give the one
concrete catch: Core Lint "forensically identified several existing Core-to-Core passes" that destroyed join points.
Nobody counts bugs: this is the reported experience of two teams. Of ten implementations only GHC and jhc have typed
Core (*What the implementations do*), so a typed IL is not needed to implement the language. UHC names the cost of
lacking one: information "thrown away in earlier stages (e.g. absence of types in Core)" (Dijkstra et al. 2009). rhc's
own argument is stronger: Mid is explicitly typed and its types are memory safety, so Core must know a type at every
binder to lower at all. Against: Shao et al. 1998 find types "very hard to represent and manipulate efficiently",
chiefly for ML modules; sharing type nodes is cheap insurance.

How much type system: an IL must be explicitly typed, since inference is not preserved by transformation, and checking
then needs no unification (Henk, §2.2). Haskell needs F omega: higher-kinded variables, and rank-2 dictionary components
(Peyton Jones et al. 1998, §2; Faxén 2002 uses polymorphic constructor fields). FC is not needed; its features are GADTs
and type functions. One coercion is: `newtype T = MkT (T -> T)` has no System F encoding (Sulzmann et al. 2007, §2.4).
Hall et al. 1996 keep explicit polymorphism because it survives transformation, the argument Peyton Jones and Wadler's
draft already makes (p 4). Henk argues for a concrete syntax, which D2's Core text is. Join points are bound in it if
Core does case of case (Maurer et al. 2017).

Peyton Jones 1996 adds requirements on Core's form. Arguments are atomic, so every allocation is a visible `let`. `case`
is the only force. Above all, **evaluated and unevaluated values must be distinguishable in Core's types.** That is what
`Int#` did: it made evaluation and boxing expressible, so strictness results became ordinary transformations (Peyton
Jones, Partain 1993, §4; Peyton Jones 1996, §6.1). A Core in which every value is implicitly lazy has nowhere to put a
strictness result. rhc can state this with Mid's own split, `int` against `susp int`, in Core [inference].

**D3: Mid's laziness surface.** Strict Core's `{tau}` is sugar for the nullary function type `<> -> <tau>`, and force is
`x<>`; ENTER blackholes and pushes an update frame, UPDATE leaves `IND a` (Fig 7). `susp` has the same role, with three
differences: `{...}` may have several results, is a function that function code applies, and has polymorphic kinds
around it where Rune has `Any`. Its authors say "arguably, we should not conflate" thunks and functions. Mid gains from
not conflating, and has no nullary functions (`lib/compiler/core/midlint.sml:332-333`). The transformations they claim
follow from it are worker/wrapper at every type, dictionaries never thunked, CSE of force, floating a value out of a
thunk, arity raising, deep unboxing: all stated, none measured.

Call-by-push-value (Levy 2006) gives no better surface. `U B` and `F A` account cleanly for what L2 already split, and
Mid's atoms, right sides and expressions already embody it. Its thunks are not updated, so `susp` is `U` plus
memoisation, which CBPV does not treat.

The sharing hazard is Peyton Jones et al. 1998 §5.1: `<e>` is a value for call-by-name; for call-by-need, "replacing
`<e>` by `<v>` in the definition of values". Bolingbroke §3.4: a nullary function "would unacceptably lose sharing". So
thunks held in `Fun` groups, the plan's expected surface, could be copied by `inline`, which puts small functions at
their call sites (`docs/ir.md:856-876`): same value, work repeated, MidLint silent [inference]. D3's recommended surface
avoids that form of it: a thunk is not a `fundef` but the result of a primitive bound by `Let`, and force is a
primitive, so nothing calls the thunk's code by name for `inline` to copy (deduced from `patches/E2-all-forms.patch`; no
test counts re-evaluation under Simplify). D51 keeps the question open for what rhc's own passes do.

**D4: `Any` against extending `Ty`.** Peyton Jones and Launchbury 1991 Restriction 1: "Polymorphic functions cannot
manipulate unboxed values". Eisenberg and Peyton Jones 2017: "all polymorphic type variables have kind Type"; "Never
move or store a levity-polymorphic value". Those are rules about representation, and Rune has a uniform value. The rule
Rune needs concerns evaluatedness, which GHC arranges in reverse. In GHC a variable may be a thunk and evaluated types
are barred from polymorphism. In L2 a variable may be a thunk, "or a type variable (which might be instantiated to < >)"
(§4.1), so polymorphic positions escape the guarantee. In Strict Core `{a}` is the thunk and `a` is not:
`[[t1 -> t2]] = {[[t1]]} -> [[t2]]`. Take that: **`Any` means evaluated, of unknown type; a lazy polymorphic position is
`susp Any`.** Otherwise a cast from `Any` must itself force, and MidLint cannot see a forgotten force. Bolingbroke's
option of forbidding "thunks of thunks and instantiation of type variables with thunk types", "an acceptable tradeoff",
holds for Haskell's lowering automatically.

On how rich a type: TIL carries rich types to the bottom and pays eight times in compile time, on single-module
programs. GHC keeps System FC through Core, with `Any` for unconstrained variables only. Eisenberg's levity machinery
needed kind polymorphism, with a "steady stream of bug reports". The nearest precedent to D4 is SML/NJ: FLINT casts to
and from `void` through typed WRAP and UNWRAP (`smlnj/compiler/FLINT/reps/rttype.sml:59-60`), a strict typed IR with a
top type and explicit casts, in production. Nothing here supports extending `Ty` with higher kinds for rhc's sake.
Faxén's target has the shape D4 C takes, polymorphic constructor fields and higher-order polymorphism (abstract, §2.5).
Once `Ty` has type variables, whether one may be instantiated at `susp T` needs an answer [inference]. Strict Core's,
taken above for `Any`, is never. Launchbury and Paterson 1996 answer with a class: `Pointed` records which type
parameters recursion needs pointed, and `seq` takes only lifted types (§3, §5), so Haskell 98's `seq` at every type lies
outside their system.

One hazard for casts: GHC redesigned `unsafeCoerce` because a cast floated above the runtime test that justified it
(ticket #16893). Haskell 98 has no dynamic type tests, so a cast is justified by Core's types, not a branch. `Decon`
after a cast must still stay below its `ConTag` test (`lib/compiler/core/simplify.sml:107`).

**D5: the evaluated-datatype invariant.** Peyton Jones et al. 1998 §4.1 is this invariant. Bolingbroke §2.1 shows what
happens without types: GHC's `case x of y -> e` to `e[x/y]` under a strict `e` removes the evaluation a wrapper added,
"utterly wrong behaviour or even a segmentation fault", so GHC stays conservative; in Strict Core "the property becomes
robust". Peyton Jones and Launchbury 1991 §9.2 give the method for a contract: list each binding site and show that it
cannot bind bottom. For Mid that is `Let`, `fundef` parameter, `Join` parameter, `Decon`, `Select`, `ExnArg`, `Handle`
variable and global, plus `Any` by D4. Strict lets fit: `let x = R in E` with `E` strict in `x` becomes a `case`, after
which `x` is known evaluated (Peyton Jones 1996, §6.4), so strictness results lower straight to Mid's `Let`.

**D6: recursive values and CAFs.** Launchbury 1993: recursive lets are the only way to make cycles, "irreplaceable". STG
allocates closures that may be cyclic. GRIN leaves it unimplemented and sketches a hole then update (Boquist 1999,
§2.5.5). For Mid, with no recursive value form, that is E1's cell patch. Peyton Jones et al. 1998 §4.2: `letrec` binds
only values and thunks, both pointed, so "the syntactic restriction of letrec does not lose any useful expressiveness".
A CAF is an updatable closure with no free variables that the frame must reach by a fixed address (Peyton Jones 1992,
§10.8); under Mid's in-order `Val`s, a thunk in a global.

**Dictionaries are recursive values,** and that is the case that bites. Faxén's instance translation is literally
circular, with default methods reaching the instance's own methods through `vd` (fig 26), and all module-level bindings
in one `rec` (§4.5); Peyton Jones and Wadler's draft ties the same knot with `let rec dvar = ... in dvar` (pp 27-28).
Hall et al. tie the same knot with a fixpoint that "uses laziness in an essential way". For Haskell 98 the recursion
usually goes through a method's lambda, so building the record terminates even strictly. Three things break that
[inference from these schemes]:
- a method that is not a function, such as `maxBound`, makes a dictionary field that refers to its own dictionary;
- Faxén's `xdef (chi alpha) vd` applies a function to the dictionary being defined;
- lifting a sub-dictionary out of a method, the fix recommended everywhere for repeated construction, turns
  `eq (eqDList d)` into a value computed at construction, which strict, on a polymorphically recursive instance, is an
  infinite tower.

So dictionary fields are lazy in Core and thunks in Mid, and only laziness makes floating dictionaries safe. Under
polymorphic recursion dictionaries must be built at run time without bound: "there is no static bound to the depth of
recursion" (Peyton Jones et al. 1997, §4.3). Constant instances can be top-level CAFs; dictionary functions stay code.
Gofer allocates and indexes before filling, which gives cycles and sharing with no laziness, but only because Gofer had
no polymorphic recursion (Jones 1994, Gofer, §7.5). Superclasses are embedded in all sources; flattening trades
construction for selection, effect "not yet known" (Peterson, Jones 1993, §8.1); on hbc it took nfibI from 264 to 204
seconds, one program (Augustsson 1993, Table 1).

### IRs (D7-D10)

**D7: Lambda, D10: walkers.** Nothing in the literature bears on either. Nanopass, under D39, is the nearest thing to
D10.

**D8: Mid `Case`.** Kennedy 2007 argues for CPS: ANF is not closed under beta, commuting conversions cost O(n^2) in bad
cases, and join points are absent. Maurer et al. 2017 answer: keep direct style, make join points first class, "no
optimizing transformation that is accessible to a CPS compiler but not to a direct-style one". The result "applies
equally to a call-by-value language". Mid has `Join` and `Jump` with Kennedy's discipline
(`lib/compiler/core/mid.sml:7-10`), so his objections do not apply, and no paper gives a reason to change Mid's form. On
a `Case` constructor as such the literature is silent. Case-of-case and known-constructor are expressed on `case`, which
rhc's Core has. What rhc's matches need of Mid is parameterised join points and tag tests, which exist. If `Case` is
added its scrutinee must be evaluated, so force stays outside it. E12's reasons for it are compile time and clarity, not
rhc.

**D9: multi-value return.** First class in Strict Core (§3.1, §5.3), as CPR without a separate mechanism, unmeasured,
and in Lambdachine's bytecode (D13). GHC's unboxed tuples are "merely Haskell syntax for tying multiple values together"
(Eisenberg 2017, §2.3). Baker-Finch et al. 2004: CPR pays only if the function allocates the product, not by type, since
returning an existing pair unboxed re-allocates: run time -2.8%, allocation -5.4%, half of the programs under 3% (GHC
5.04, §6.2). Mid's `results` is CPR for tuples in whole programs (E12: turning it off gives -0.76% instructions, +4.4%
allocation on the compiler). So no multi-value return on rhc's account. Worth knowing: the Mid form stops at units and
at tuples, and user single-constructor types were a large share of strict arguments in Peyton Jones and Partain 1993
Table 6 (72% in hidden, 44% in bspt), which `workers` will miss unless Core lowers them as tuples [inference].

### Runtime (D11-D19)

**D11: the thunk object.** Two questions divide the sources.

*Who writes the update.* A frame costs "one extra instruction for every update frame pushed" and saves a test on every
constructor evaluation (Peyton Jones 1992). A VM that tests at force has no such saving to make. STG, GHC, UHC and
Strict Core use a frame; nhc98 and Yhc update on return of any eval frame; the G-machine, Hugs and hbc overwrite the
redex root; GRIN's `eval` does it, inlined at the forcing site; a cell model has the forcer do it (§3.1.2). Rune's form
G tests at force as a cell does, and updates in the thunk's own code as jhc's wrapper does, with STG's indirection.

*What is written.* Update in place saves the extra allocation and hop (§10.6), but "up to 10%" of updates copy an
existing constructor, 47% in one program, duplicating data no collector can merge. Marlow and Peyton Jones 1998 gave it
up: "we can no longer update thunks in place (except by copying the value, which is clearly a bad idea)". GHC has
written an indirection ever since, and since Harris et al. 2005 a result word first, so an update never overwrites free
variables. GRIN keeps update in place by returning nodes in registers.

What the numbers carry over, as directions:
- **Indirections are not rare.** Marlow et al. 2007 Fig 7: 10.43% of cases meet one at a 0.5 MB nursery, 18.04% at 32
  MB, up to 74.4%. GHC treats them as not evaluated and pays enter and return. For Rune, `K_IND` belongs in force's fast
  path, and the nursery size affects force's cost [inference].
- **Most forces find a value.** Fig 2: geometric mean 62%, minimum 0.2, maximum 99, falling to 54% at a 32 MB nursery.
- **The update path is hot.** Dropping one word from the update frame moved exp3_8 by -23.2% and puzzle by -12.1%
  (Marlow, Peyton Jones 2006, Fig 8, on a Pentium III); skipping whnf update elimination costs up to 1.22 (Boquist, Fig
  9.7).
- **A test against an indirect jump on recent hardware:** no paper here gives it. Marlow et al. 2007 report mispredicts
  of 10-12 and 24 cycles. Rohou et al. 2015 measure the dispatch branch of switch-based interpreters: mispredictions
  fall from 12-20 per thousand instructions on Nehalem to 0.5-2 on Haswell, and threaded code gains 10.1%, 4.2% and 2.8%
  on Nehalem, Sandy Bridge and Haswell (§1, §2.2). That is dispatch, not the enter jump of compiled lazy code [inference
  that it carries]. The nearest recent data is Rune's own: 1.50G cycles entering against 0.99G by header when all
  scrutinees are values, and no difference once 1% are thunks (`docs/plans/heap-layout.md:635-646`).
- **An updated thunk stops a tracing JIT's allocation removal.** Schilling 2013 §8.7: "Laziness further prevents some
  crucial allocation optimisations from becoming applicable." Rune's JIT compiles functions
  (`docs/performance.md:65-66`), so trace selection does not carry over and this does [inference]. A thunk form that
  skips the update, with a Core analysis to justify it, is worth leaving room for.

Wansbrough and Peyton Jones 1999 note that where the consumer writes the update, a function cannot take both a used-once
and a used-many thunk. A state on the thunk answers that in a VM [inference], so a usage analysis stays open under form
G.

**D12: release, blackholing, raise.** This is the decision the literature changes most.

*What must be released, and when.* Richard Jones 1992 made thunks under evaluation drop their free variables at entry,
because a tail-recursive `last` otherwise holds the list: 5211 words of heap against 223 at n = 1000. Peyton Jones 1992
§9.3.3, the same year, showed entry is unnecessary: "In almost all cases a thunk will be entered and updated between
garbage collections, so that no space improvement is gained by overwriting with a black hole". It suffices to
black-hole, at the start of a collection, the thunks the update frames point to. Appendix A.2: "So until we need
parallelism, black-holing is a waste of instructions." Marlow and Peyton Jones 1998 §5.1.1 made that GHC's design,
calling the entry store "gallingly expensive", and it remains the default. The requirement is: **no thunk under
evaluation keeps its free variables reachable at a collection.** This is D12's "release by the next collection". The
Report has no space semantics, so the requirement is not a conformance matter; it is what makes a lazy language usable.

*The precondition.* Black-holing helps only if the running code no longer needs the closure. Peyton Jones 1992 §9.4.1
rejects "saving Node" for that reason and copies live variables out. Reid 1998: the program "copies the contents of the
thunk onto the stack (or into registers)". Rune does the reverse. Code reads free variables through the frame's closure
(`ReadsClosure`, `src/isa/regs.sml:120`), and each frame's closure is a root (`runtime/register/README.md:45`). E2 ran
it: under the Haskell reading of forms A and B a non-tail body keeps 56 and 40 bytes per element, 6993 and 4995 words
over the base at n = 1000, where B with the drop and C, G and L keep none (`results/E2/tables/last.txt`). So Jones's
leak is Rune's until the body reads its captures at entry, which the prototype's `Low.hoistEnv` does.

*Detection.* Not needed for conformance: bottom is bottom (Launchbury 1993, §3.2; Report 3.1, "indistinguishable by a
Haskell program from non-termination"). Without a write at entry, `x = 1 + x` ends in stack overflow or a black hole
according to when a collection strikes. Peyton Jones 1992 and Marlow and Peyton Jones 1998 §5.1.2 diagnose by finding
two frames for one thunk at overflow. Against a 1 GiB stack that is slow to reach [inference]. This is the trade D12
sets out: G detects at once, L detects after a collection and saves 0.6% on the ports (E2).

*Raise.* Marlow et al. 2001 §8: a raise truncates the stack to the nearest catch frame. For a synchronous exception each
thunk under evaluation is overwritten with a closure that raises the same exception: re-evaluation would give it anyway,
and this needs no free variables. For an asynchronous one that reasoning fails, so the thunk is frozen (Reid 1998): each
black hole on the update list becomes a resumable object holding its stack chunk. Reid also shows why reverting to the
original is wrong in Haskell: it needs the free variables, the leak, and discards work. Peyton Jones et al. 1999 give
the semantics, with which exception is reported left imprecise. All of this serves `getException`, an extension. Haskell
98 needs none of it: `catch` takes `IOError` only (7.3), and Peyton Jones 2001 §5.1 says a pattern-match failure "brings
the entire program to a halt". nhc98 and jhc have no raise path through a thunk at all. D12's ruling, that no thunk can
outlive a raise, had lazy I/O to be checked against. It holds [inference]: pure code can only `error`, which ends the
program; an `IO` action runs inside a thunk only through lazy input; and a lazy-read thunk that fails ends its list by
21.2.2 and does not raise (D25). If rhc ever adds `Control.Exception`, release at entry brings in the repair.

**D13: library, prims or instructions.** Precedents only, nothing measured. Boquist writes `eval` as an ordinary
procedure of the intermediate language, with `fetch`, `case` and `update` explicit, which is the library form. It can do
so because GRIN can inspect a closure without forcing it, "something that can never be done" in STG's language (§2.5.2),
so a Mid-level force needs that inspection as a primitive: form G's `thunk_fready`. nhc98 and hbc have an EVAL
instruction. Lambdachine's register bytecode has `eval` and `update`, eval/apply calls and a multi-value `ret`
(Schilling 2012, §4.1): a precedent for D13 C, D15 C and D9 B, unmeasured. The one figure for a bytecode with thunks
against native code is nhc's, a factor of four slower and four times smaller (Röjemo 1995, §1, p 283); it isolates
neither force nor update. Sestoft 1997's final machine has twelve instructions and treats update as a stack marker. E2's
30% threshold has no literature behind it either way.

Wakeling 1999 is the nearest thing to a lazy language on a foreign VM. He lists allocation cost, no tail calls, no
usable reduction stack and no in-place update, and answers with heap frames and a trampoline. Rune controls its VM:
`K_IND` exists, Mid has tail calls, allocation is the VM's own, so three of the four do not apply. His ratios are old
(143 MHz UltraSPARC, JDK 1.2): JIT about five times the interpreter; slower than Ghc 4.01 -O2 by 6 to 35 times; lazy
against strict MLJ on one JVM 2 to 5 times under JIT, about 10 times interpreted, on three tiny programs, with no
strictness analysis. His tail-call goto gave -17.6% to +10.7%, unexplained: a warning that a JIT can undo a
bytecode-level fix.

**D14: stack bytecode and runeopt parity.** Marlow and Peyton Jones 1998 mix bytecode and compiled code by making both
agree on heap objects and frames, the requirement Rune's two bytecodes already meet. Nothing else bears on it.

**D15: eval/apply.** Marlow and Peyton Jones 2006 is the source. On about GHC 5.04, nofib, 88 programs, wall clock on
the half running over 0.5 s, on a 1 GHz Pentium III with no argument registers, eval/apply against push/enter by
geometric mean: code size +1.8% (-5.2 to +7.7), heap allocation +0.1%, instructions +0.0%, memory reads +1.1%, writes
-4.9%, run time -2.8% (-23.2 to +6.9). Pending arguments make stack walking hard (three failed schemes, §5.2) and make C
or C-- nearly useless as a target. Their argument is complexity at equal speed: "if eval/apply is no more expensive than
push/enter, it is definitely to be preferred" (§7). The conclusion is scoped to compiled code: "For an interpreter,
where performance is not such an issue, these hacks are not important, and push/enter may well be a more elegant
solution" (§10). Tier 2 is compiled code sharing frames with the interpreter, so the compiled conclusion governs both,
and pending arguments would break the pc-keyed liveness in `reg_frame_live`.

What does not carry: the `stgApply` generator and the argument shapes, because Rune's slots describe themselves by a low
bit and there are no stack maps (`runtime/register/README.md:46-48`). What carries: arity checked by the caller; "exact"
as the fast path; a PAP holding a function, not a PAP; over-application by a pushed continuation; and the distribution
of arities, p 54.4%, pp 34.4%, ppp 5.2%, v 5.2% of unknown calls (Fig 7), so a fast path for one to three arguments
covers almost everything. Wakeling's `do2`, "more than 99% of all do2, do3 ... invocations", which he ascribes to binary
methods from dictionaries in unoptimised programs, supports a fast path at two.

E3's first flip condition was that unknown calls of 2+ arguments under 5% would drop eval/apply. The paper gives no such
line. Frequency appears only to size the `stgApply` family. Rune's unknown call is unary today (`CallsClosure`,
`src/isa/regs.sml:122`), so to drop it means literal currying, one closure per extra argument, which the paper never
measures. Its own data sit on the number. It states 20% unknown, 40% of those with more than one argument, 8% of all
calls. A per-program join of Figs 6 and 7 (58 printed programs, `results/E15/lit/machines.fastcurry-join.out`) gives
mean 11.15%, **median 4.88%**, 30 of 58 under 5%, call-weighted 16.71%, range 0 to 64.9. So the verdict would depend on
the statistic. And those counts follow GHC's optimiser, with arity passed across modules, which "greatly increases the
number of known calls" (§8.1); x2n1 is 78.8% unknown through one overloaded `^`: "Overloading is a plentiful source of
unknown function calls." E3 then measured the corpus at each level: 63.1% at `-O0`, 3.5% at `-O2`, under GHC's
optimiser, not rhc's (D15). Partain 1992 adds that Imaginary is "distinctly unimportant", so a threshold should be
computed on Real.

Arity tags in pointers gained 1-2% in a preliminary test (Marlow et al. 2007, §6.3). `seq` on an unknown closure must
test for a function (Marlow, Peyton Jones 2006, §6.3), which is trivial with kinds.

Hammond and Blott 1990 measure the state conformance runs in until track P, run-time dictionaries against resolved
overloading, at 4.9 to 11.3 times; see D49. It agrees with D15's ground for A, and nothing in it argues against building
C.

**D16: pointer code 11.** Marlow et al. 2007, GHC of 2007, nofib, 91 programs. Semi-tagging alone: -7.2% on Opteron,
-9.4% on P4, code +1.5%, +2.2%. Pointer tagging: -13.7%, -12.8% (Opteron -37.3 to +10.6, P4 -44.4 to +11.4), code +2.4%,
+2.6%, L1 accesses -13.9%, L2 misses -20.1%. Three or fewer constructors cover 96.1% of cases. Tags cost about 600
lines, every pointer dereference in the runtime must untag, and the collector must propagate tags. The gain has two
parts. Semi-tagging comes from avoiding the enter and the return; a VM's force is a kind test, so Rune has that part.
The further 5.5% and 3.4% "comes from reduced cache activity": the constructor tag is in the pointer, so the info table
is never touched. One code cannot hold a constructor, and Rune's tag is in the object's own header, on the line the case
reads anyway (`docs/plans/heap-layout.md:647-652`: 0.94G against 0.99G, inside noise). Code 11 is an evaluatedness bit,
which the paper does not measure alone and for functions dismisses ("Little would be gained"). Rune's low bit already
tells an immediate from a pointer, so its supply of bits is tighter than GHC's. Nethercote and Mycroft 2002 propose an
evaluatedness bit in the pointer, to replace GHC's indirect enter jump by a better predicted local one, and do not
measure it (§5.4, pp 51-52). Rune's force takes no such jump, so code 11 can save only the header load, a memory access,
which would show in cycles and cache misses rather than instructions [inference]. So D16's none stands on the paper as
well as on E2.

**D17: selector thunks.** Wadler 1987: the collector rewrites `fst (x,y)` to `x` when the argument is already an
evaluated pair, and never calls the evaluator. With all lazy patterns translated through a tuple, no other rules are
needed. It breaks Hughes's result that `break` leaks under any sequential evaluator, since the collector counts as a
second evaluator. No implementation, no numbers. Sparud 1993 fixes the leak in the evaluator instead, with no collector
rule, and not by a construct of the core language: a pattern binding is desugared into the tuple form with selectors,
plus an impure compiler-internal `updatePat`, which "overwrites every vi with an indirection to the corresponding vi'"
(§3.3, p 119). For a typed IR he says to keep that form, his equation (8), and to optimise further only when generating
code (§4, p 120). The construct is Gustavsson and Sands' reformulation, and they adopt it: Wadler's rule "would destroy
many of the nice properties of our theory". hbc has it as an option, off by default (*What the implementations do*).

Measured: one figure was found. Runciman and Wakeling 1993, clausify under an LML G-machine: 47,548 to 34,083
byte-seconds, -28%, after black-holing had already taken 1,666,647 to 480,706. Sparud gives heap profiles only, of
`surprise` and a Fudgets mail reader, and says a program that does not leak "will run somewhat slower with our method",
unsized (§4, p 120). Röjemo 1995 measures nothing on selector thunks: it is about the compiler's own heap, and
"selector" does not occur in it (p 283). No paper says how often this leak bites across real programs.

Where it bites: two components of a lazily matched pair consumed at different rates. The Report's own Prelude is built
that way: `span` is `where (ys,zs) = span p xs'`, `lines` binds `(l, s') = break ...`, `unzip` uses `~(as,bs)`. So under
a literal Prelude a line of length n holds n pairs until the consumer reaches `s'`, then a chain n deep is forced
[inference; Wadler's `surprise` is the same program]. The cost is bounded by the longest line, or the distance between
two consumers, which is why it can wait. For rhc the choice is three-way: Wadler in Rune's collector, needing a
recognisable selector shape; Sparud's desugaring, needing an impure update of sibling thunks at Mid's surface; or
neither until a program needs it, D17's ruling. Sparud's method needs the tuple form, and the Report's kernel is the
per-variable one: 3.12 gives `let p = e1 in e0` = `case e1 of ~p -> e0`, and 3.17.3 rule (d) gives one
`case v of { p -> xi }` per variable, which is Augustsson's form (5), measured faster for patterns of under about five
variables (Sparud, §3.2, p 119). So Sparud's form is a different desugaring of pattern bindings and `~p`, which touches
D34 [inference]. It does not fix `partition` written with two `filter`s (§5, p 121). What it needs under form C is in
D17: the write cannot be a `K_IND` to an unevaluated component, and the sibling under evaluation must be skipped, or
D11's pin becomes Haskell's [inference from §3.3 and E2's patch].

**D18: depth.** Stack discipline first. Marlow and Peyton Jones 2006 §5.2: stubbing dead pointers by hand was needed
under conservative walking and frame layouts avoid it, "this turns out to be very important in practice". Shao and Appel
2000 state the rule for strict languages too: "any local variable binding must be unreachable after its last use within
its scope"; real programs were 2 to 80 times too large without it. Sestoft 1997: 200 primes needs over 3000 KB leaky,
under 8 KB with environment trimming. Rune has this for waiting frames by `reg_frame_live`, with named gaps
(`runtime/register/README.md:49-64`): a register past the 64th, the running interpreted frame, and the frame's closure,
the last of which D12 deals with. Functions take more registers once dictionaries arrive, so the 64 limit may be reached
more often than under SML [inference].

Update frames are stack cost. Frames are not roots: if a frame's thunk is otherwise dead, drop the frame and save the
update (Peyton Jones 1992, §10.7). Gustavsson and Sands 1999: `f = \x. let y = f y in y` then runs in constant space, as
in Hugs 98 and GHC 4.01 and not hbc 0.9999.5a. Adjacent frames collapse to one with the others as indirections (Marlow,
Peyton Jones 2006, §7). So stack growth from nested forces is not only depth of data.

Growth: Peyton Jones 1992 has a fixed area; Marlow and Peyton Jones 1998 a thread stack in the heap, doubled and copied
on overflow; GHC now uses 32k chunks (*What the implementations do*). Fixed stacks fail on real inputs: `foldr` over
10^5 fails under Hugs and MicroHs and succeeds under GHC at 10^7 (`results/E15/run/probes.tsv`). The 1 GiB stack is a
modern form of the same answer. With track P after G2, conformance runs without strictness and specialisation, and the
Report's `sum` builds a chain of n thunks and evaluates it deep (`foldl` on an unknown `(+)`; Jones 1995,
dictionary-free). So the depth decision carries that alone; E2's 10^7 chain fitting 1 GiB under G is what makes that
safe. If black-holing is at GC, each collection need walk only new frames: Marlow and Peyton Jones 1998 §5.1.3 and
Harris et al. 2005 §4.1 stop at the first frame already handled, and Rune has a stack watermark for minor collections
(`runtime/vm.h:329`) [inference].

**D19: CAF roots and the barrier.** Laziness makes every update a pointer store. Appel 1989: a pointer store is under 1%
of instructions and a barrier about 4 instructions plus 4 at collection. Sansom and Peyton Jones 1993, Sun 4/60: 16.7 to
35.0 pointer updates per KB allocated, 20,200 to 49,800 a second. Rune's ports: strict twins store 5 times, lazy forms
71 thousand to 16 million (`docs/plans/heap-layout.md:609`). Most fall in the young generation: 95% of closures updated
within 100 KB of allocation, over 99% within 1 MB. Seward 1992, in a G-machine interpreter, finds the barrier "virtually
zero" in cost, and "Ignoring Primes, ... at worst 97.6% of all updates are not in old-space" (abstract; §3.2.3). Cost of
the test: 2.0% and 1.6% on the two large programs (Sansom, Fig 10); on GHC 6.2, 15 instructions on a block-structured
heap against 2 on a contiguous one, and removing it altogether gains 1.67% or 0.51% (Cheadle et al. 2004). The authors
keep it. E2 found the existing path sufficient.

Promotion is the laziness-specific damage (Sansom §5.4): a promoted thunk roots its later value in the old generation,
unseen by minor collections; 6% of hsc's allocation was promoted dead at a 100 KB area. Promoting every survivor of a
minor collection, which Rune's nursery does (`runtime/gc/minor.c:1-7`), made sieve's collection take "nearly ten times"
the two-space collector's time (Röjemo 1995b, §5.1, p 155). The answers are aging; never promoting unevaluated thunks
(Sansom §6.1; Röjemo 1992, where it also removes the test on update); and eager promotion of what an old immutable
object points to, -6.8% GC time, -18.4 to +36.6 (Marlow et al. 2008). Röjemo 1995b ages, by a family of tags per node
kind, and found never tenuring updatable nodes "a bad idea" on lmlcomp, where the young heap fills with old updatable
nodes (§4, §5.4, p 159). Its old thunks add themselves to the remembered set on entry, with no test at update (§3, p
150). Add-on-entry needs eager black-holing (Cheadle §5), so it conflicted with form L; under form C, which the owner
took (D11), `BLACKHOLE` writes at entry and the conflict is gone. It is still no reason to change the barrier, which
needs nothing new [inference].

CAFs: Peyton Jones 1987 §18.6.2 calls per-supercombinator CAF lists "essential to prevent ever-expanding CAFs from
filling up the machine". Peyton Jones 1992 §10.8 keeps a list and retains every entered CAF for ever, "slightly
pessimistic". Marlow and Peyton Jones 1998 §4.6 call that a deficiency and add static reference tables: each code
segment lists the top-level functions and CAFs it references, the collector traces from live closures and frames, most
tables are empty, especially with cross-module information. Peyton Jones et al. 1996 confirm that in the GHC of the time
"all top-level values are retained for the whole life of the program". **No paper gives a number** for what collecting
CAFs saves. In Rune a CAF is a global, and globals are roots (`runtime/register/README.md:44-45`). For a CAF that is a
growing lazy list that is a linear leak; for conformance it is nothing. A table per function index, emitted at or below
Core-to-Mid, is the known fix. If CAFs stay roots, constant floating needs Santos's "safe" rule (D47).

### Data (D20-D26)

**D20: `Integer`.** Nothing measures defaulting. Literals are `fromInteger (dict) integer`, and Faxén 2002 §8.2 cites
Augustsson that "there are programs where the bulk of the execution time is spent in constructing literals". Augustsson
1993 §4.3 says it: "the biggest cost, by far, is the cost of computing the constant!", with `fromRational` worse;
precomputed literals took hinc from 242 s to 1.55 s on hbc (Table 1), under Haskell 1.2's default of `(Int, Double)`,
not Haskell 98's. Hammond and Blott's literal rewrite alone regained "a factor of 4" on Nfib (1990, p 282). One indirect
sign: `Integer` as a share of strict arguments is 96.9% in rsa, 38.4% in gg, 33.0% in gamteb and 25.1% in uid, small or
blank elsewhere (Peyton Jones, Partain 1993, Table 6, read from the table's layout). A defaulted site knows
`Num Integer` at compile time, so known-instance selection applies directly. E5 is the only evidence.

**D21: `Char`; D24: string literals; D26: library boundary.** No paper bears on these. Implementations do, and D26 rests
on E1 and E13.

**D22: `Int`.** No paper on the width. One consequence: an addition that can raise is not cheap-eager and not
`exprOkForSpeculation`. Faxén says so: "If such overflow is trapped, integer addition is an unsafe operation, but if
overflow just wraps around, as we will assume in this paper, it is safe" (2000, §3, p 152), with a footnote citing the
Report's 6.4. So D22's checked prims close D51's local form for `Int` arithmetic, and only a path that cannot raise,
such as the word prims, keeps it open. Every figure in Faxén 2000 assumes a wrapping `Int`, so his local column under
D51 is an upper bound on what the checked prims give up [inference]. MLj drops SML's `Overflow` and measures nothing
(Benton et al. 1998, §6.1). Strictness is unaffected.

**D23: `Float`.** No paper. E7 finds Hugs printing `Float` and `Double` in 7 and 15 digits against GHC's and nhc98's
shortest form, which the Report's `showFloat` defines, so the literal `Numeric` is the reference. Hartel et al. 1996's
Pseudoknot shows single against double differing by machine and compiler; it is no guide to rhc.

**D25: `IO` and lazy I/O.** Hudak and Sundaresh 1989: streams, continuations and systems are equal in expressiveness.
Peyton Jones and Wadler 1993: `IO a` abstract, implemented as `World -> IORes a`, combinators inlined, no code for the
world; `delayIO` gives lazy read. Launchbury and Peyton Jones 1995: `ST s a = State s -> (a, State s)`, with
`interleaveST` duplicating the state and `readFile` using it, its safety a disjointness argument left informal. Peyton
Jones 2001 gives the operational semantics that replaces "World -> (a, World)" as a meaning. The name
`unsafeInterleaveIO` is in no paper of this group.

What the Report says: `IO` is abstract, and in 21.2.2 `hGetContents` semi-closes, items are "read from hdl on demand",
and "Any I/O errors encountered while a handle is semi-closed are simply discarded." So a lazy-read thunk catches its
own read errors and ends the list. GHC deviates here; rhc should not.

The natural form for a strict target is D25's: a Mid function of a unit parameter that performs its effects. The token
form's reasons do not transfer. They are reordering by a lazy optimiser, kept out by data dependency (Launchbury, Peyton
Jones 1995, §9.3.3), and strictness expression. Mid's `Let` is already sequenced. Its costs do transfer: one more
parameter, and a returned pair per action unless the IR has unlifted multi-value returns, which Mid has not. Mid
requires a parameter anyway, so the direct form is token-passing with the result world dropped, and the objection to
dropping it (no data dependency) is an objection about Core [inference]. So Core's `IO` must be opaque: bind, return and
primitives as constants, lowered at the Core-to-Mid boundary. That is keeping the monad right through, whose cost Peyton
Jones 2001 §2.8 states per pass, and it is small for a small optimiser [inference]. If `IO` is instead a Core function
on a token, GHC's rules come with it: never duplicate a redex, never lose the chain, no CSE across `runST`-like dummies,
no let-floating into a lambda. GHC then needs the state hack: every lambda over `State#` is treated as one-shot, "we
don't really know, and sometimes it's false" (Note [The state-transformer hack],
`ghc/compiler/GHC/Core/Opt/Arity.hs:544`). No paper reports its benefit.

A lazy-input thunk does I/O when forced, so `thunk_fforce` is not pure in Mid and must not move across an effectful
step; `interact` depends on that order (Peyton Jones, Wadler 1993, §5.1, proof obligation). Failure by exception rather
than `Either` in each bind avoids "every >>= operation" testing (Peyton Jones et al. 1999, §7).

### Front end (D27-D38)

**D27: parser and layout.** Landin 1966's offside rule already exempts bracketed subsegments. The parse-error clause is
Haskell's own. L is a function from annotated tokens and a context stack to tokens with explicit braces (9.3). Write w
for the tokens L has emitted and G for the Report's grammar. parse-error(t) holds iff wt is not a prefix of L(G) and w}
is, and only where m /= 0. So L is defined by G's viable-prefix language: Adams 2013 calls it the oracle that "predicts
the future behavior of the parser". Haskell 98's grammar has fixity in it (`exp^i`), so G's prefixes depend on imported
fixities: that is reading R1.

An LR parser has the correct-prefix property: it never shifts t after wt stops being a viable prefix. So to try t, and
else behave as if } were there, is exactly an `error` alternative on a close nonterminal. GHC, Hugs, Programatica, HSE
and haskell-src all do that (*What the implementations do*). No backtracking is needed. This is a reading of why it
works; no paper proves that the device equals L. Adams warns it is fragile: "even minor changes to the error propagation
of the parser affected whether syntactically correct programs were accepted".

A pure pre-pass cannot be exact. Bracket counting handles `(do a; b)`, and with `let`/`in` as brackets, `let x = 1 in`
(Marlow 2021). A comma rule handles `[x | let y = 1, z]`. `where` needs the block's kind: `case x of y -> z where ...`
binds to the alternative, `do a where ...` closes. The rule tried at scale is GHC's AlternativeLayoutRule, from
Meacham's proposal, built to replace parse-error(t). It never became the default (Marlow 2014), and Marlow's verdict is
that the rule is "hard for implementers, but it's not actually that hard for users" (Marlow 2021). Run on GHC 9.4.7 it
gives a parse error on four one-liners the default accepts (`results/E15/lit/front.layoutprobe.tsv`, p5-p8), among them
`[case a of a -> a | a <- [1]]`. Commas in `vars ::` and fixity declarations are why a comma rule is wrong in general.
Erdweg et al. 2012 say the same of pre-passes in general. E10's S1, a token rule, agrees from Rune's side: 201 lines
against 22, and 9 of 36 legal crafted programs refused.

ML-Yacc has no error productions, only automatic correction (`/home/ruud/reference/mlton/mlyacc/doc/mlyacc.tex:140`), so
GHC's device cannot be a yacc token in SML, and Rune's parsers are hand-written anyway. The precedent for D27 is nhc98
and MicroHs: a lexer with get-next-token and pop-layout, and "the parser has enough communication with the lexer"
(Augustsson 2024). `closeImplicit` is that device. E10 gives the rate that was open when E15 wrote: 371 firings in 165
of 1,670 files.

Declarative treatments exist and do not help. Adams 2013: parse-error(t) "is simply implicit in the structure of the
grammar", with 93 modules of base giving identical trees through a modified Happy, 1.73 times slower, and no proof that
its grammars equal L; it targets Haskell 2010, so fixity does not arise. Erdweg et al. 2012 use GLR with constraints: 22
812 of 24 219 Hackage files alike, 1.8 times slower. Afroozeh and Izmaylova 2015 use GLL with 21 extra rules. All need a
generator SML does not have. Two searches found no mechanised treatment of L, which is weak evidence of absence.

Divergences on real programs:
- `-XHaskell98` turns on NondecreasingIndentation (`ghc/docs/users_guide/bugs.rst:128-148`, R3), which 274 of 24 219
  Hackage files rely on (Erdweg).
- An explicit `}` closing an implicit block is rejected by L and accepted by GHC (Sato 2019; R2). GHC, Hugs and MicroHs
  accept it and nhc98 refuses; no corpus file needs it (E10).
- GHC "doesn't do the fixity resolution in expressions during parsing as required by Haskell 98 (but not by Haskell
  2010)" (`ghc/docs/users_guide/bugs.rst:162`), so `let x = 42 in x == 42 == True` fails. Hugs documents the same. E15's
  probe p11 confirms it on GHC 9.4.7.
- parse-error(t) fires only at the first invalid token and never backtracks: `do { let x = 1 ; return () }` is rejected
  by the rule and by GHC, because the let block has swallowed `return ()` (p9).
- HSE, haskell-src and GHC share the `close: error` device and a lexer shape, so they are not independent on layout.
  HSE's default language is Haskell 2010. They serve printer tests, not as a second opinion on L.

Haskell 2010 kept L, dropped the fixity paragraph and added 10.6, a separate `resolve`. R1's seed, flat chains with a
pinned deviation, is the direction all took.

**D28: AST fidelity and printer.** GHC has two tests. `utils/check-ppr` checks parse of print against parse, with spans
blanked; `utils/check-exact` reproduces the source and needs annotations in every node. HSE has the same pair, and calls
itself "on life support". The first is what D28 calls the tree test. Nothing argues that a batch compiler needs exact
printing: Programatica rendered source by decorating the lexer's output, "preserving layout and comments" (Hallgren
2003). Amorim et al. 2018, which derives a parser and a printer from declarative layout rules, is not exact either: its
printer is "correct if the same abstract syntax tree" comes of parsing the original and the printed program (§5), it
"discards comments altogether" (§8), and 5 of 22,191 Haskell files printed wrong, from a ripple effect in its layout
fixer (§6.2); its parser costs 1.72 times the same files with explicit layout. An exact printer, D28 C, cannot print a
tree that carries no annotations, one a generator or a reducer made, so it comes beside the tree printer and its round
trips, as GHC keeps both tests [inference]. What the tree test needs of the AST is parentheses as nodes, since chains
are flat until fixity is resolved, and brackets can change meaning: `n + 1 = 7` defines `+`, `(n + 1) = 7` binds `n`
(Hudak et al. 2007). A corpus does not check a printer: Duregård et al. 2012 enumerate ASTs by size and found
`StringL "\n"` printed as `""` and `[Con..]`, with HSE as parser oracle. Erdweg's method is the one that tests layout:
print each AST explicit and implicit, and require one parse. A printer that only prints braces never exercises L. E10's
mutants add a token test, which is D28's second round trip.

**D29: names and fixity.** Use Diatchki, Jones and Hallgren 2002, not Faxén's section 4. It is about 200 lines of
relations, a name mapping to zero, one or many entities with errors only on use, and it computes in-scope and export
relations by a fixed point over cycles. It says the Report was revised partly because of this work. It covers only
names: not scoping inside bodies, nor instance visibility (5.4). Faxén deviates in two ways that Diatchki names ("non
Haskell 98 compatible"): `module Foo where {foo = 1; bar = Foo.foo}` is illegal in his rules and legal in the Report,
and a top-level binding hides an import rather than clashing. He also separates type and class name spaces (§2.2), and
chose that import lists filter qualified names too, since the Report is unclear (§4.3). Fixity is a precondition for
both specifications. The executable form exists as Haskell 98 in Programatica: Hallgren et al. 2004 report 90 seconds
for about 50,000 lines in 500 modules on a 1.9 GHz Pentium 4, which says only that the algorithm is not a cost concern.
E16 adds what the paper does not stress: section 5 does not say which fixpoint, and a user module defining `map` gives
two, so the rule must say least. Hbc alone resolved fixity in the parser (*What the implementations do*).

**D30: recursive modules.** Diatchki et al. say outright that "the compilation unit of a compiler is not a single
module, but a strongly connected component", and define name resolution over an SCC as a least fixed point. It is the
same text as Programatica's `programatica/src/programatica/tools/base/Modules/Modules.lhs`. It covers names alone.

**On types across a cycle no Haskell paper was found.** Faxén leaves them out because the Report does. Kilpatrick et al.
2014 call them "almost entirely unspecified". The Report defines no details. The nearest work is Nakata and Garrigue
2006, on ML. So rhc's semantics for a cycle is its own design. The search was the corpus, Crossref and two web searches,
so this is a negative result about a search.

That is not as bad as it sounds [inference; no paper makes the comparison]. The ML literature names two hard problems,
type checking and initialisation. Initialisation is a problem of strictness: Leroy 2003 spends most of a note on it. In
rhc every top-level binding is a thunk, so a cycle across modules is a recursive binding group, and an ill-founded one
is bottom; Yang 2017 says as much, "a binding like x = x can simply be compiled into a thunk which infinite loops when
forced" (appendix B.2, p 101). Type checking is hard in ML because modules carry abstraction and generativity, hence
recursively dependent signatures (Crary et al. 1999) and double vision (Kilpatrick et al.). Haskell 98 modules are
name-space control only, so pooling declarations under already unique names is enough, as jhc and Programatica do.
Typing an SCC as one unit is then the only option that accepts unsigned cross-module recursion and keeps dependency
analysis uniform.

No paper says why GHC needs boot files. Diatchki et al. call the mechanism the programmer "essentially implementing this
aspect of the module system manually". Yang 2017 takes them as given and does not say either. The nearest it comes is
that Haskell code "assumes an implicit ordering specified by the import statements", so ordering a signature among
modules needs "an hs-boot style {-# SOURCE #-} import syntax" (appendix B.1, p 101), and that an incremental GHC must
have "No backwards propagation" (B.2, p 102). GHC's own notes give the cost, in *What the implementations do*. That boot
files are incomplete comes from a forum post, checked by running it; no paper says it.

What remains is small and Haskell's own: `default` and the end of Rule 2 are per module, and a join loses the module.
E9's R20 seeds one rule per SCC as an extension; the literature offers nothing better. Build systems agree on the unit:
every model in Mokhov et al. 2018 is correct only on acyclic task graphs (§3.6), so a cycle must be one task. Leroy's
design has the same restriction. Flatt and Felleisen 1998 [abstract] are the usual precedent for keeping a cycle apart,
if one unit per SCC proved too slow.

**D31: checker structure.** The brief says Haskell 98 needs only unification. Precisely: types are solved by first-order
unification, predicates by one-way matching and backward chaining, and the two never feed back except through
defaulting.

| Component | Mechanism | Plain unification? |
|---|---|---|
| Damas, Milner 1982 monotypes | Robinson mgu, occurs check | yes |
| Generalisation of implicit groups | free variables minus environment | yes, with set difference |
| Dependency analysis (4.5.1) | SCCs of the binding graph | no: a graph pass before typing |
| Signatures, polymorphic recursion | check against a declared scheme (`tiExpl`) | no inference: semi-decidable (Mycroft 1984), undecidable (Henglein 1993, Kfoury et al. 1993) |
| Predicates, entailment | `bySuper`, `byInst`, one-way `match`, backward chaining | no: never binds a variable of the goal |
| Context reduction | `toHnf`, then `simplify` (Jones 1999, §7.4) | no; "only informal hints" in the Report |
| Ambiguity check | a variable-set test on the scheme | no |
| Constructor classes | `TAp` unification, kind-preserving (Jones 1995, constructor classes) | yes, first order: the type language has no lambda, and synonyms must be saturated |
| Kind inference | unification on kinds, default `*` per dependency group | yes, plus a default |
| Defaulting (4.3.4) | search the default list using `entail` | no, and the one place a predicate binds a type |
| Monomorphism restriction (4.5.5) | syntactic test, withhold generalisation, Rule 2 at module end | no |
| Derived contexts | smallest context, a fixed point (10.1) | no |
| Class and instance checks | syntactic; superclass instance exists; heights for acyclicity | no |

Peterson and Jones 1993 say context reduction is the only significant change to ML inference for correct typings, which
is true of the core and understates the table. Termination of `entail` rests on the Report's syntactic conditions (Jones
1999, §7.3), so those must be checked before entailment runs: without them typability with overloading is undecidable
(Volpano, Smith 1991 [abstract]). Jones says of `entail` that "we have not formally proved" soundness, completeness or
termination.

Why no solver with local assumptions. OutsideIn (Vytiniotis et al. 2011) lists signatures on local bindings as a source
of local constraints beyond HM(X), and Haskell 98 has those. The papers give the pieces of the answer, and the assembly
is E15's:
- Local assumptions exist: a signature's context, class and instance contexts over methods. They are only class
  predicates.
- A signature's variables are all quantified, and givens "only arise from user type annotations that contain no
  unification variables" (§3.6), so givens cannot constrain an outer unification variable. `tiExpl` discharges them in
  one step, once types are stable.
- Patterns bind nothing. A data context is wanted at a match, not given: "constructors from types with nonempty contexts
  are not overloaded in any semantic or operational sense" (Faxén, §8.4).
- Predicates never produce equalities. Improvement (Jones 1995, simplifying) is for multi-parameter classes.

OutsideIn's implication constraints and untouchables exist because a pattern match can make an equality hold in one
branch only, which destroys principal types. That is absent here. Vytiniotis et al. 2010's proposal not to generalise
local lets "is not conservative over Haskell 98", and does not apply. "No HM(X)" is literally defensible: the journal
HM(X) lists records, equational theories and subtypes as instances, not classes (Odersky et al. 1999), and only an
earlier version has a class section, for the Nipkow-Prehofer form (Sulzmann et al. 1997). Haskell 98 is at home in
qualified types (Jones 1994, qualified types; Jones 1995, constructor classes). Neither framework has its monomorphism
restriction, defaulting or dependency analysis.

When dictionaries are decided: during inference, by placeholder (Peterson, Jones 1993, §6). Types stabilise only at
generalisation, so the walker leaves `<method,type>` or `<class,type>` holes, listed so no second walk is needed, and
resolves each at generalisation as a dictionary parameter, an instance, deferred outward, or ambiguous. Those four line
up with THIH's `split`. A ref cell per placeholder suits an SML checker [inference]. The record that should survive into
the elaborated tree is Faxén's `dict` judgement: variable, dictionary function applied to types and sub-dictionaries,
superclass selector, tuple (fig 28). Binding groups: Faxén translates a generalised group through a tuple function and
selector wrappers, then lambda-lifts it away (figs 30-33). His is a typed target, so it is the one to copy for Core.
Yale avoided polymorphic methods with "an internal construct similar to a type cast" (Peterson, Jones, §8.5); Faxén uses
polymorphic constructor fields, so dictionaries need a rank-2 field in Core and cross to Mid as `Any` (D4).

GHC's way, typecheck the full syntax and desugar after, needs "a great deal of code (broad, but not deep)", with "the
huge advantage" being messages (Hudak et al. 2007). rhc is second class on messages, so that reason applies with less
force.

**D32: monomorphism and defaulting.** Hall et al. 1996 omit both. The restriction "was introduced in Haskell 1.1 for
efficiency reasons"; defaults "can technically lead to an incoherent semantics, as demonstrated by Blott". It exists for
sharing: `f xs = (len, len) where len = genericLength xs` "can actually be computed twice", Hughes's program "ran
exponentially slower", and the committee would not make that depend on optimisation (Hudak et al. 2007, who call it
"manifestly a wart"). The Report's second reason is ambiguity: `[(n,s)] = reads t`. Peterson and Jones §8.3 add that the
Report's single context for a group can make a member ambiguous from outside, which is R21.

Faxén's Definition 2 agrees with Rule 1 and does not state Rule 2 or defaulting. THIH states Rule 2 as one line in
`tiProgram`. Nothing before it states them. Peyton Jones and Wadler's draft gives the restriction one sentence, on its
BIND-PRED rule, "Haskell's (rather unsatisfactory) 'monomorphic pattern binding' rule" (p 31); its section on ambiguity
ends "These predicates are ambiguous. Should really say more here." (§9.3.3, p 35); it has no Rule 2 and no defaulting.
Nipkow and Prehofer 1995 "have not introduced ambiguity formally" (§8, p 223), though Hall et al. cite them for its
treatment. Hammond and Blott 1990 default per module, `default (Int, Float)` when none is given (§3.5), and do not treat
the restriction; nhc in 1995 had neither (Röjemo 1995, §1). **Programs that differ by reading:**
1. `n = 60; a :: Int; a = n + 1` at top level. By Rule 2, `n` stays open to the module's end and becomes `Int`; a reader
   who defaults per group rejects. E7 runs it: GHC prints 61, Hugs `+98` refuses, and nhc98 prints 61 by having no
   restriction at all (`results/E7/hard/mr/out.txt`). THIH agrees with the Report.
2. Jones's `f :: Eq a => a -> Bool; f x = (x==x) || g True; g y = (y<=y) || f True`, with `g` also used at `Char`: THIH
   accepts, Faxén's `bindg` rejects as E15 reads fig 30. Jones says of the example "some implementations accept it,
   while others do not". 4.5.1 defines groups by binding alone, which favours Faxén; R21 covers these clauses.
3. Faxén's `f x y = let g = isNil in (g x, g y)` has two legal types. THIH computes
   `forall a. IsNil a => a -> a -> (Bool,Bool)`. Faxén's rules also admit `[a] -> [b] -> ...`. rhc must pin the first.
4. A restricted mutually recursive group whose members have different type variables: THIH's `split` passes only
   variables common to all members, so a constrained variable in one member defaults at once, where Rule 2 keeps it
   open.
5. A signature on a non-simple pattern binding: THIH says restricted; R19 seeds refusal.

**Coherence.** Haskell 98's rules are not coherent. Faxén's two derivations of `show (read "True")` prove it. The sense
in which it holds is Jones's Theorem 5 for OML (Jones 1993, coherence): if the principal scheme is unambiguous, all
translations are equal. That needs a principal type, equal evidence for equal predicates, and a lazy equational theory.
Faxén shows the restriction removes the principal type (§10.1). Defaulting resolves an ambiguity by decree, so coherence
does not apply. Bottu et al. 2019 [abstract] say no proof existed even for superclasses and flexible contexts before
theirs, on a small calculus. So the meaning of a Haskell 98 program is defined by a deterministic inference procedure,
as Faxén observes of THIH. A checker must therefore not ask whether a type is legal, which Faxén's rules answer yes for
several types, but whether it is the type the pinned algorithm computes. For defaulted types the elaboration should
record the variable, its predicates, the default list in scope and the choice.

The Report's claim to infer "the principal type of all expressions" has two known failures: Haskell 1.4's simple
contexts (`g = \xs -> (map not xs) == xs`, Peyton Jones et al. 1997, closed by Haskell 98's context form), and Faxén's
example, which stands. All of this is 1989-2002 and none of it is measured; whether real programs hit cases 2 to 4 is a
question for E8 and the conformance table.

**D33: deriving.** Faxén omits it because "generating derived instances can be done before type checking" (§1.3). THIH
never mentions it. But 10.1 defines the context as the smallest satisfying a condition, by a fixed point for mutually
recursive types, and that condition is entailment over the instance environment. So derived code can come from syntax,
on the renamed AST as D33 says, while the derived context must be computed after kinds and instance heads are known and
before value bindings are typed [inference]. The methods then enter as ordinary instance bodies. Faxén has no rules for
deriving (§1.3), so only a derived instance made as AST and elaborated like a user's comes under replay and the second
inference (D54); the minimality of a derived context is then checked by conformance rows alone [inference]. `deriving`
occurrences do not count as dependencies (Faxén, Definition 1).

**D34: desugaring and match compilation.** Faxén's order is the conformant one, not THIH's: "we do only that desugaring
which is directly related to resolution of overloading or to modules" (§8.4), since the Report's translations are
themselves overloaded. Overloaded literal and n+k patterns therefore carry dictionary expressions into the match
compiler (§9.1). His target grammar omits char and string patterns, a slip.

The Report's rule, 3.17.2: "Pattern matching proceeds from left to right, and outside to inside". So the order of
forcing is a function of the values seen. A compiler is free only in tests on values already forced, and in sharing
(that argument is E15's). It is Augustsson 1985's: the patterns "are checked from top to bottom, and each pattern is
checked from left to right", and the scrutinee "is evaluated exactly as much as is needed to determine which pattern is
the first to match" (p 371). His scheme backtracks, with `default` as the failure join, which is D34 A, and measures
nothing. Three things follow:

- **Maranget's lazy result is about another semantics.** Maranget 1992: for
  `F (true,true)=1; F (_,false)=2; F (false,true)=3`, left to right `F bottom false` loops, right to left gives 2, and
  he calls the second correct. Under the Report the answer is bottom. A compiler that gives 2 is more defined than the
  Report and fails conformance. Maranget 2008 accepts the rule: "a match compiler for Haskell must preserve the
  termination behavior of Augustsson (1985)". Necessity heuristics are therefore unavailable, and so are the necessity
  semantics of Laville 1991 and Puel and Suárez 1993.
- **Decision trees are legal only in Sestoft's order:** "Our naive matcher, and hence our match compiler, implements
  pattern matching as required by the Haskell report" (Sestoft 1996, §8). Rune's `trees` picks the first row's first
  testing pattern, the same order (`lib/compiler/core/matchcomp.sml:238-245`). But it makes no test for a tuple or
  record (`:311`), and leaves the last constructor of a datatype untested, which is right for SML, where a value is
  evaluated, and wrong for `f () = 1`, which must force. It also works on Lambda and SML patterns.
- **Backtracking is the safe default.** Wadler's mixture rule, and every implementation with a matrix. Automaton size is
  linear in the source (Maranget 1992, §6). Mid's `Join` is the failure continuation. On hand-written strict ML
  heuristics change nothing in most programs and at most tens of percent in size, with run-time correlation r at most
  0.30 (Scott, Ramsey 2000). GAML image: trees 110%, failure automata 101% (Maranget 1994). Coq binaries within 2%.
  Bytecode interpretation is the one setting where tests were visible, with a path of 6.33 against 3.14 (Maranget 2008,
  §9.3), a reason to watch this on Rune's VM. Pettersson 1992's automaton holds for lazy languages only "with strict
  top-down, left-right evaluation" (p 270), so its "any column will do" (p 264) needs Sestoft's order; on his own SML
  system it gave no reduction in code size, 38 of 1,671 states shared (2.3%) over 231 constructs. So decision trees
  would show on rhc in tests executed, not in size [inference].

Repeated tests left by backtracking are removed in Core by case on a known variable (Peyton Jones 1996, §5.3). Literals
resist merging: a numeric literal is `==` at an overloaded type and may diverge. A probe for each match: put bottom at
each position. `F bottom False` is the first test. Tuples are lifted because `seq` on unlifted tuples would need
parallel evaluation (Hudak et al. 2007, §5.4), and Danielsson and Jansson 2004's caveat is a test case:
`f = \True x -> x` and `f' = \True -> \x -> x` differ on `f False` under `seq`, so a match compiler may not change
arity.

**D35: hierarchical names.** No paper.

**D36: library layout.** The Report calls chapter 8 "a specification", written "with clarity rather than efficiency in
mind", not required as shown, and no paper treats the Report's Prelude as an implementation. Hudak et al. 2007: the
Prelude was "remarkably un-buggy for code that had never been compiled", and hbc's first test was compiling it, which is
G1's precedent. See *What the implementations do* for who compiled what.

**D37: Prelude overlay.** Foldr/build needs a rewritten Prelude: fusion only happens "for compositions of functions from
the Standard Prelude, whose functions we reimplemented using foldr and build" (Peyton Jones, Tolmach, Hoare 2001, §3.3). Gains: 10-queens
2.8 times, others "much more modest"; about 3% time (Peyton Jones, Santos 1998); about 5% allocation, most programs
nothing, 5-25% for a few (Peyton Jones et al. 2001). So a literal Prelude gives up about 3-5% on GHC of 1996-2001, and
the overlay need not carry `build`. A desugaring that translates list comprehensions without `concatMap` keeps the
Prelude literal (from Gill et al. §4, inference). GHC's documentation treats the semantics, bottoms included, as
binding: `splitAt` "is more strict than specified in the Report" (`ghc/docs/users_guide/bugs.rst:425`). So GHC is no
oracle for strictness, and the literal Prelude is the reference. Text and code conflict in places (E9), so a probe needs
a reading.

**D38: which text, and Faxén's deviations.** "Many small flaws", four years of shake-down (Hudak et al. 2007): expect
E9's list to grow. Faxén 2002 has 44 figures, 32 of them of inference rules by their captions, so a checker can cite
rule names, contrary to the plan's "no rule numbers". The Lean project carries them (haskell-spec, version 0.1.0,
proving nothing, with the same hole on ambiguity). Its last section says more investigation "is indeed needed before
these inference rules can be used as a specification of the language". Citing it needs this list of where it leaves or
goes against the Report, for the conformance table: kind defaulting only sketched, and his Definition 1 on what counts
as a dependence (§3.1, §10.3); default method typing "not very explicit"; labelled fields, where update may change type
(§5.2); ambiguity, where his rules allow ambiguous schemes (§7.2.3, §10.2); defaulting in prose only; principal types
(§10.1); coherence (§10.2); polymorphic recursion "treated rather briefly"; import lists and qualified names (§4.3);
separate type and class name spaces (§2.2); qualified reference to one's own top-level names (§4.2); top-level names
against imports (§4.2); mutually recursive modules, left out (§1.3); data type contexts, "dubious" (§8.4, §10.3); eager
context reduction, which he reads 4.5.3 as mandating (§7.2.1); the class variable in a method's context (§6.2, §8.1);
and overloaded patterns needing constructs absent from the Report's translation (§9.1). Items of formal convenience go
against the Report. His policy, the Report beats implementations and vagueness is resolved by usefulness and "the
simplest formal description", is close to D38's and is not a licence.

### Architecture (D39-D42)

**D39: pipeline as data.** GHC's precedent is narrower than D39: only Core-to-Core is a list (`getCoreToDo`,
`ghc/compiler/GHC/Core/Opt/Pipeline.hs:120`), with lint between, which plugins edit. The rest is hooks, a record of
optional functions (`ghc/compiler/GHC/Driver/Hooks.hs:131`). UHC: "the very fact that the steps are isolated and
identified enables us to move them around" (Dijkstra et al. 2009). Nanopass argues for many small IRs, each formally
defined and enforced, with traversal generated (Sarkar et al. 2004); Keep and Dybvig 2013 show scale, 15-27% better code
at 1.75 times the compile time. That argument does not transfer without its framework: a bare list of `Mid -> Mid` has
no input and output language, so ordering constraints stay implicit [inference]. UHC's drawback, tasks that fit two
places or need lost information, is the case against too many levels.

**D40, D41: front-end independence.** Sizes of an independent Haskell, for range only: GHC 1992 about 14,000 listed
lines, 47% renamer, types and desugaring (Peyton Jones et al. 1993); UHC 60,000 of generated and hand code; MicroHs
under 10,000, 30% type checker (Augustsson 2024); nhc98's compiler closure 24,186 lines (E8, not the 32k E15 repeated
from the plan). Programatica's lexer and module system stand as pure Haskell 98 pieces; the rest was "perhaps also too
complicated" for a reference (Hallgren 2003).

### Separate compilation (D43-D46)

**D43: store option.** Mokhov et al. 2018: a verifying or constructive trace keyed on dependency hashes supports early
cut-off; a deep constructive trace, hashing inputs only, cannot (§4.2.4). So the key for an SCC should hold hashes of
imported HsIface values, and cut-off needs HsIface to be deterministic and canonical, with dictionary order and fresh
names stable. Rule 2 and whole-unit generalisation mean a change to a body can change an export, so HsIface is compared,
not assumed. These are model results, not measurements.

**D44: HsIface contents.** At least what Faxén exports, `FE = <CE,TE,DE,IE,VE>` (§2.7.8), globalised to original names:
classes with kind and superclass order, default-dictionary names; types and synonym expansions; constructors with
schemes and field environments; all instances ("the instance environment is unaffected by the filtering"); values with
class-method form. And, from elsewhere:
- kinds, since an exported abstract type's kind cannot be inferred (Jones 1995, constructor classes, §6);
- dictionary parameter order, an ABI fact: `(Foo a,Bar b)` and `(Bar b,Foo a)` differ (Peterson, Jones, §8.6), so a
  canonical order must be stated once;
- types known only at module end under Rule 2 (Jones 1999, §11.5.1), which is why an interface follows inference of the
  whole unit;
- export relations (Diatchki et al.) and fixities [inference];
- arity, which "greatly increases the number of known calls"; constructor tags of static constructors; emptiness of
  static reference tables (Marlow, Peyton Jones 1998, §4.6);
- under optimisation, a strictness signature (Peyton Jones et al. 2006). Peyton Jones and Partain 1993 §4.6 call it
  "absolutely essential", with up to 35% of single-constructor strict arguments unpacked no further "because of data
  abstraction". Worker/wrapper needs the wrapper's unfolding exported. Specialisation across modules needs unfoldings of
  overloaded functions, "the biggest outstanding problem" for Jones 1995 (dictionary-free).

Programatica fingerprints abstract syntax per definition, so comments and layout do not invalidate (Hallgren 2003): a
precedent for hashing at definition level.

**D45: the Prelude snapshot.** "The importance of the libraries is that they contain implementations of arithmetic over
basic types; if that is compiled badly then performance suffers horribly" (Peyton Jones, Marlow 2002, §4.5). All GHC
figures compile Prelude and program the same way. A snapshot compiled before track P, or without unfoldings, will
understate every result [inference]. E6 agrees: median instructions are 1.04 of `-O2` with a program's own pragmas
omitted, and 2.00 with the libraries' too.

**D46: order with build-system-v2.** Nothing in the literature bears on it, nor on D42, which hosts build rhc.

### Optimisation (D47-D51)

**D47: where it lives.** All GHC's work is on a typed, lazy, second-order Core where `let` allocates and `case`
evaluates (Peyton Jones 1996, §3.1). Each global pass is an analysis plus a transformation that relies on the simplifier
to clean up: "the simplifier is part of every transformation, so it cannot sensibly be measured in isolation" (Peyton
Jones, Santos 1998, §10.3). A worker's body rebuilds its boxed arguments and leaves case-of-known-constructor to remove
them; below inline threshold 2 wrappers do not inline and performance "drops dramatically" (Peyton Jones, Marlow 2002,
§7.7).

What each pass pays, as ratios on old GHCs. All are off-by-one against full optimisation unless noted, geometric means,
libraries rebuilt each way. Ratios of allocation should travel better than ratios of time. None is a modern figure.

| Change | Instructions or time | Allocation | Setting | Source |
|---|---|---|---|---|
| Everything off | +140% | | 15-50 nofib, mid-1990s GHC | Peyton Jones, Santos 1998, Fig 2 |
| Simplifier only (GHC without -O) | +80% | | same | Fig 2 |
| Full simplifier, against minimal | -11% | -12% | ghc-0.23 | Santos 1995, T4.1 |
| Simplifier and strictness, against minimal | -19% | -18% | same | T4.1 |
| All of -O, against minimal | -51% | -62% | same | T4.1 |
| Case of case off | +10% | mixed | same | Fig 4, T3.5 |
| Eta expansion off | +8% | +8% | same | Fig 4, T3.7 |
| Function inlining, one occurrence only | -21% | -35% | ghc-0.23 | T6.1, 6.2 |
| Function inlining, threshold 3 | -40% | -48% | same | T6.1, 6.2 |
| Loop breakers off | | +23%, +78% with libraries | about GHC 4 | Peyton Jones, Marlow 2002, Fig 2 |
| Strictness off | +18% time | | mid-1990s | Peyton Jones, Santos 1998, Fig 6 |
| Strictness on | -15% time (E15's geomean) | -12%, thunks -36% | 17 real, GHC 1993 | Peyton Jones, Partain 1993, T1, T2 |
| Strictness off | +15% time, max +57% | | 21 programs, GHC 2003 | Ennals, Peyton Jones 2003 |
| Float in off | +0.6% | +6.1% | 15 real, ghc-0.26 | Peyton Jones et al. 1996, T2 |
| Full laziness off | +7.3%, max +90.5% | +10.9% | same | T3 |
| Local floating off | +8.7% | +15.7% | same | T5 |
| All floating off | +16.4% | +34.4% | same | T6 |
| List fusion | about 3% time | about 5% | ghc 4.08 | Peyton Jones et al. 2001 |
| CPR | -2.8% time | -5.4% | GHC 5.04 | Baker-Finch et al. 2004 |
| SpecConstr | -10% time, code +3-4% | | 2007 GHC | Peyton Jones 2007 |
| Cardinality | few %, 8.8% best | | 2014 GHC | Sergey et al. 2014 |
| Call Arity alone | -0.2% | -0.0% | GHC 2014 | Breitner 2015 |
| Arity and enhanced occurrence analysis on | -1%, maillist -19%, 46 of 52 unchanged | | GHC 0.26, nofib | Gill 1996, Table 5.7 |
| Inliner: INLINE pragmas; thresholds tuned | 10% faster, most of it one package; 22-27% tuned | | GHC 8.10.3, Hackage packages | Hollenbeck et al. 2022, abstract, §6.1 |
| Specialisation of overloading, within a module | 9.2 times faster on nfib; 1.9 on choleski, idInt, hinc; 1.03 on sched | | hbc, by hand, 1993 | Augustsson 1993, Table 1; D49 |

Santos's Table 4.1 shows what off-by-one hides: from minimal, the simplifier gets 11%, strictness takes that to 19%,
everything else in -O to 51%. The separately measured passes do not obviously account for the gap, and the unmeasured
specialiser may be part of it [inference]. The papers warn against summing: one transformation often has "a dramatic
effect on a few programs", and the figures "probably overstate" what a pass is worth because the rest of the compiler
assumes it. E3's L1, L2 and `-O2` ladder is the modern parallel, on rhc's corpus.

Which passes could Mid do? What is strict by the time it reaches Mid [reading of the papers against `docs/ir.md`]. A
strict argument of Mid type `int` has nothing to unbox, `workers` flattens tuple parameters, `results` is close to CPR.
What Mid cannot do is anything that moves a lazy binding: float in, float out, let from let, let to case, inlining into
or out of a thunk, case of case across a lazy scrutinee. Those dominate the frequency chart (let from let 32%, let from
application 9%, let from case 5%, case of case 8%, Fig 3). Peyton Jones et al. 1998 §4.3 say why one `Let` is not
enough: "if we have just one form of let we lose valuable optimising transformations". Mid's one `Let` keeps `App`
non-removable (`lib/compiler/core/simplify.sml:110-116`), so Haskell's purity is invisible to Mid: what Core does not
remove before lowering stays. Strict Core §5.4-5.5 give the cases for a little Mid teaching: force of delay, dominated
force, a thunk around a value. These need Mid to know `susp` only as a force fact [inference].

**The strongest argument against D47** is one optimiser in Mid, shared with lazy ML. GRIN is the precedent: a strict
first-order IR with explicit thunks and whole-program flow analysis, reaching 3.6 times ghc 4.01, with the largest and
smallest factors removed, on 16 programs of up to 716 lines (Boquist 1999, Figs 9.2-9.3). Those conditions flatter it,
and the author says so: single file, overloading removed by hand, a full back end with interprocedural register
allocation, "A very interesting experiment would be to try to isolate the effects of our basic evaluation model", never
done. It rests on the whole program: "a basic assumption of the GRIN back-end is that the entire program is available at
compile time, otherwise we would not be able to construct an eval procedure in this way"; and module-level optimisation
does not help, since a local function "might very well escape" through a closure. So under separate compilation a force
stays an open dispatch [inference], and GRIN does not settle the question for rhc. Nor does it address space leaks
(Ennals, Peyton Jones 2003, §7.1). The objection that a Core simplifier duplicates an optimiser is true. Teaching Mid
about `susp` would not remove it, since the transformations that pay most move lazy bindings and in Mid `Let` is strict.

**A JIT does not replace this.** Lambdachine has GHC -O2 in front of a LuaJIT-derived tracer and is still "about 10 to
20 percent slower than GHC on statically optimised code", with overheads up to 105% on some benchmarks (Schilling 2013,
§6.3). PyHaskell [abstract] likewise does not beat GHC. No tiered, method-based JIT for a lazy language was found.
Supercompilation gets 0.01 to 1.04 of GHC -O2 on programs under 150 lines, whole program (Mitchell 2010): it shows how
much abstraction cost remains, and nothing about a first optimiser.

A pass list, inferred from the above (order from Peyton Jones et al. 1996 §3.4, Breitner 2015 §4, and
`ghc/compiler/GHC/Core/Opt/Pipeline.hs`): simplify; specialise known dictionaries, select methods, simplify; float
constants to the top under Santos's safe rule, not general full laziness; definition-based arity and eta; strictness and
absence, worker/wrapper, let to case, simplify; lower. Left out deliberately: float in (0.6%), general full laziness
(space risk), Call Arity (nothing to gain without fusion), SpecConstr, CPR in Core, cardinality, fusion. "Any serious
compiler for a non-strict language should implement (a) local floating to expose values ... (b) floating out of
constants" (Peyton Jones et al. 1996, §7). On let-floating generally: the three floats hit different targets and their
costs add up; what pays is local floating, which is simplifier work, and floating constants out. Full laziness is uneven
and can leak. Augustsson and Johnsson 1989 hold the opposite, "a transformer to full laziness is an essential part of a
serious compiler", after three places in one program where losing it cost "an order of magnitude in time" (§4, p 138):
one anecdote, against T3's measured +7.3%. Santos floated only bindings judged non-leaky for half the gain, worst
residency 1.18 times against 2.10. Peyton Jones 1987 §23.3.1 has the classic case, in which `f = drop 1000` comes to
drag a graph 1000 levels deep.

**D48: a Core simplifier with eta.** Eta costs about 8% of instructions and allocation when off, more than full
laziness. `let f = \x -> let ... in \y -> E` may become arity 2 if `f` is always applied to two arguments (Peyton Jones,
Santos 1998, §8); otherwise sharing of `...` is lost per call. The hard case is a thunk: `let t = foo x in t 1 + t 2`
must not expand, `if x then t 1 else t 2` may (Breitner 2015, §2.3). **GHC's default is not conforming:** after eta
through `case`, `(f bot) seq 1` converges where it should diverge, which GHC ignores unless `-fpedantic-bottoms` (Note
[Dealing with bottom], `ghc/compiler/GHC/Core/Opt/Arity.hs:467`). rhc needs the pedantic rule, or eta only where the
head is already a value. Mid's `workers` is safe: nothing sits between the lambdas. A Core optimiser should list which
of GHC's unsound rewrites it refuses: foldr/build is unsound under `seq` (Hudak et al. 2007, §10.3), and full laziness
changes strictness (Pałka 2012). Core Lint belongs in the first version.

Arity raising beyond the simplifier has one measurement. Gill 1996's arity analysis raises arity wherever sharing is
kept, and considers neither `seq` nor bottoms (§4.4); its own example moves a lambda out through an `if`, which D48's D
allows and C refuses [deduced]. With enhanced occurrence analysis it gives a geometric mean of 0.99 of instructions on
52 nofib programs, maillist 0.81 and 46 unchanged (Table 5.7), and earns most after deforestation, which rhc refuses.
Augustsson 1993 §4.2's method-arity eta, which "may loose full lazyness", is the other precedent; both predate
polymorphic `seq`. MLj raises arity only where effect types show termination (Benton et al. 1998, p 134), the
strict-language form of the pedantic rule. Johann and Voigtländer 2004 give foldr/build's condition under `seq`:
equality holds when `c` of two bottoms is not bottom and `n` is not bottom (§8.2).

**D49: known dictionaries and specialisation.** Jones 1995 (dictionary-free) is whole program: each overloaded function
at constant dictionaries becomes a clone, and members at known dictionaries are selected at compile time. It terminates
because Gofer's dictionaries are finite. Under polymorphic recursion "The set of dictionaries ... is infinite and the
specialization algorithm will not terminate". He wrote that of a suggested extension; Haskell 98 has it (4.4.1). So rhc
cannot go dictionary-free: dictionaries stay, and specialisation is an optimisation with a fuel limit. Augustsson 1993
gives such a function, `f x = if x == x then x else head (f [x])`, which has no bounded set of specialisations (§5.4,
fig 9). Separate compilation is "the biggest outstanding problem". Code got smaller on all seven programs, 3.8% on anna,
45% on calendar, since unused methods go; 15,000 lines at most, 1993-94, Gofer.

How much a program loses. An overloaded `sum (map fact (nums 1))` at `Int` on hbc takes 13.6 s and 43 MB,
hand-specialised 2.1 s and 9 MB, flagged as atypically heavy. Int signatures on small benchmarks "sometimes give a
ten-fold improvement", real programs far less. Augustsson 1993's Table 1 has six programs on hbc, transformed by hand,
collection excluded: automatic specialisation within a module gives 9.2 times on nfib (87 s to 9.5 s), 1.9 on choleski,
idInt and hinc, and 1.03 on sched, which has monomorphic signatures throughout [the rows read as cumulative, inferred].
Hammond and Blott 1990 put the naive translation against LML's built-in overloading on a Sun-3/60: 11.29 times on 8
Queens, 9.72 on Primes, 10.24 on Nfib and 4.89 on KWIC, and 2.74, 2.06, 0.98 and 4.47 after four local rewrites (§3.6,
§4). Under Gofer's naive code generator the gain is marginal, so **the gain is the optimiser's, not the dispatch's**.
Dispatch is cheap there: "a reference to a tuple element followed by a function call" (Peterson, Jones, §9). On hbc's
G-machine it was not: a method call took about 15 memory references against 6 for a known function (Augustsson 1993,
§4.1), and the dictionary representation alone gave 2.2 times on nfib; the specialiser still gave more. The cost is that
methods are unknown, so strictness, unboxing and inlining stop. Augustsson's table is the one figure for a specialiser;
for GHC's, at Core level, there is a sentence in each of Peyton Jones, Santos 1998 and Peyton Jones 1996, and
`ghc/compiler/GHC/Core/Opt/Specialise.hs` is the documentation. So E5 is the roadmap's only evidence on rhc's own
programs, with E3's L1, the simplifier and the class-op rule with specialisation off: thunks -47%, bytes -38% in total,
-26.2% and -17.7% for the median program.

Order: specialise before strictness (`ghc/compiler/GHC/Core/Opt/Pipeline.hs:216`). `sum` and `product` are
`foldl (+) 0`, `elem` is `any (== x)`, `(^)` has two class constraints. With `Integer` defaulting, dictionaries are
constant at the call, so a known-dictionary specialiser sees what it needs at the use site [inference]. Peyton Jones,
Partain 1993 §2.2 note dictionaries are tuples, so strictness with unpacking also catches some. Augustsson 1993 adds two
things a specialiser must cover: local overloaded bindings, since a specialised `sum` whose local `sum'` stays
overloaded "is hardly an improvement" (§5.4, fig 10); and `fromRational` as well as `fromInteger` (§4.3).

**D50: strictness.** The simple analyser is higher order, over top, bottom, functions and finite products, with each
iterate widened to one demand per argument (Peyton Jones, Partain 1993). Absence is a second interpretation, not
optional once products are unpacked. It does not look inside recursive types: a spine-strict append "might have a
terrible effect on the peak space requirement". On 17 real programs, "solid but modest", 10-20% typical. Table 1 runs
from -44.8% (pic) to +5.9% (maillist), E15's geomean -15%; thunks fall always, -5% to -92%, geomean -36%; total
allocation less, -12%, because unpacking allocates other things. The paper's "The best speedup we observed was about
30%" disagrees with its own table. Over ten years of GHC the figure held at 13-18% against a moving baseline. Mycroft
1980 is the origin; Wadler and Hughes 1987 the theory for lists. GHC later replaced forward abstract interpretation by
one backward analysis of strictness, absence and CPR (Peyton Jones et al. 2006), which takes usage with 240 more lines
(Sergey et al. 2014, §6.1). If rhc writes one analyser, the later advice is the backward form with signatures. Per
module: strictness "does not require a whole-program flow analysis, and readily adapts to separate compilation" (Ennals,
Peyton Jones 2003, §7.1).

Hartel et al. 1996 is the one cross-compiler comparison, on Pseudoknot, a float-intensive program that gains nothing
from laziness: one SUN 4/690, gcc 2.4 s, Glasgow 3.9, Chalmers 12.1, interpreted Caml Light 52, NHC 176, Gofer 370,
Miranda 1156. Without strictness and unboxing work, "support for laziness therefore costs directly a factor of 3".
Glasgow's place took hand work. One program, each team's own version, three decades old: it says strictness and unboxing
decide a factor of about 3, and that two bytecode systems differ by 3.4 times, the only comparison here near Rune's
interpreter [inference].

Danger for conformance: strictness may evaluate before an IO action what the source evaluates after it. GHC's Note
[Precise exceptions and strictness analysis] (`ghc/compiler/GHC/Types/Demand.hs:1526`) has
`f x y | x>0 = raiseIO# Exc | y>0 = ...`. In Haskell 98 terms `ioError` can be caught and `error` cannot, so the same
bug changes behaviour. If `IO` is a function in Core, the analyser needs this rule from the start. Which `error` a
failing program reports does change, legally (Peyton Jones et al. 1999).

**D51: cheap eagerness.** Faxén 2000: a static analysis finds expressions certain to be cheap and safe, and evaluates
them before it is known that their values are needed. Without knowing the global flow of control and which variables are
evaluated, "even a variable reference is a potentially unsafe expression" (abstract), hence a whole-program flow
analysis, and "separate compilation is impossible" (§6). Ennals and Peyton Jones put the point as "Is a thunk for x+1
cheap? It depends on whether x is evaluated" (2003, §7.1). The setting is a prototype compiler for a language "Plain",
eight programs of at most about 700 lines, Shade instruction counts, against a baseline with "a very simple strictness
analyser" (§4, p 157). Table 1 gives 0% (sort) to 52% (qf) fewer instructions and 1% to 58% less time; on the three
programs past toy size, event, sched and tc, 26%, 5% and 11% fewer instructions. The "0-25%" often quoted is Ennals
2004's summary. The gain does not come from thunks never run: those removed have "an about average probability of being
evaluated", and much of it comes from evals removed and unboxing that speculation enables (p 157). Every figure assumes
a wrapping `Int` (D22). Ennals warns that gains may shrink on a mature baseline.

A local version is old. GHC around 1995 floated a `case` out of a `let` for "cheap non-failing" primitives on unboxed
values, on Core, with no flow analysis (Santos 1995, §3.5). GHC 9.14 case-binds arguments that are
`exprOkForSpeculation`: reach WHNF, soon, no write side effect, cannot throw, so no division
(`ghc/compiler/GHC/CoreToStg/Prep.hs:1859`, Note [Speculative evaluation]), with a "Very Nasty Wrinkle": speculating a
recursive dictionary function loops. Faxén's "All evals expensive" column is a figure for the local form: it marks
expensive every thunk body that contains an eval and every lambda whose body is not another lambda, which "corresponds
roughly to what one can accomplish without a special cheap eagerness analysis" (pp 156-157). It keeps all of the gain on
the three queens programs, and gives 16%, 1% and 8% fewer instructions on event, sched and tc. With a wrapping `Int` and
a weak strictness baseline, that is a ceiling for rhc, not a measure [inference]. What the local form needs from rhc
[inference]: types that say a variable is evaluated, in place of the flow analysis; and total primitives. `Int` `+`
qualifies only if it cannot raise, which D22's checked prims do not give, and `div` is out; Faxén proposes testing a
divisor and building the thunk only when it is zero, and did not build it (§6). Under D20 D an `Integer` add of two
immediates cannot raise, but the big path is unbounded work and fails at `INTINF_DEFAULT_BITS` (`runtime/intinf.h:6`),
so only speculation guarded by a test for immediates qualifies, which is the form Faxén 2001 measured.

Faxén 2001 defers the choice to run time: speculate only if no variable the body evaluates is bound to a thunk, and in
one variant only while a depth counter is positive (§2). A test costs 7-8 instructions (§4.1); it cuts thunks built by
5% to 90%, but "hardly improves run-times and instructions counts at all for most programs" (§5): event, sched and infer
run at 99% to 106% of the static form's instructions (Table 1). The static form enables unboxing and the removal of
evals; the dynamic one does not, since later passes must still allow for a thunk (§5).

The prize is update avoidance. Sansom and Peyton Jones Fig 4, thunks evaluated zero, once, more: hsc 4.6/77.4/17.9, anna
16.3/56.2/27.5, pic 1.4/79.3/19.3, primes 14.2/50.1/35.7. E3 at `-O0` has 91% of thunks entered. Peyton Jones 1992 §4.3:
move bounded work out of a thunk to expose a head normal form, so `let xs = y1 : y2 : ...` allocates constructors, not
thunks. Boquist finds update elimination under 1% and whnf update elimination up to 22% on his programs. Cardinality
adds single-entry thunks (0-23% of thunks, up to 74% dynamically) for a few percent, and needs a thunk form without
update and a late pass (Sergey et al. 2014, §7).

Optimistic evaluation (Ennals, Peyton Jones 2003): each `let` has a runtime switch; speculate, abort after two sample
points, profile wasted work per let. Run time 84% of a strictness-analysed GHC, worst 114%, code +34%, residency 85%.
Without profiling, `constraints` is 35 times slower. It did not land, for maintenance: it "never got into GHC", and
Peyton Jones and Marlow decided it was too big to keep in the main compiler (Peyton Jones, glasgow-haskell-users, 8
February 2006, read through a fetch). For Rune [inference; no paper tries it]: two of its costs, the branch on every let
and doubled code, are a static compiler's. A tiered VM has counters and could compile one side. The hard part remains:
abortion captures a running computation as a heap suspension. A subset without abortion can speculate only what is
proved total, which is cheap eagerness steered by a profile: a possible later tier-2 milestone, not part of this plan.
Faxén 2001's measured run-time test weighs against it, unless that tier compiles a specialised side [inference].

### Testing (D52-D56)

**D52: oracle policy.** Evidence on differential testing. McKeeman 1998: the problem is evaluating results, and false
positives are legal differences in unspecified behaviour. Yang et al. 2011: Csmith needs one meaning per program, 191
undefined and 52 unspecified behaviours avoided. Shared bugs are undetectable, "an inherent limitation". They saw no
correlated failure and hypothesise that diversity of IRs is why, which does not carry to Haskell front ends: E7 finds 20
hard disagreements in 82 tests, and majority verdicts on `let`-fixity and NondecreasingIndentation are wrong by the
Report's letter. So voting decides nothing in the front end. Back-end comparison across tiers is close to their setting.
Implementation-defined items rhc must hold still: `Int` width, `Float`, exit status, `show` spacing, exception text.

**The Report never requires call-by-need.** Hudak et al. 2007: "lazy evaluation is simply one implementation technique
for a non-strict language". Sharing appears only as the motive of 4.5.5, "Rule 1 prevents computations from being
unexpectedly repeated", and in a note on `f = \x -> \y -> x+y`. GHC gives up sharing on purpose (`-fno-state-hack`,
"runs the risk of reducing sharing", `ghc/docs/users_guide/using-optimisation.rst:1017-1020`). So `--count` budgets are
rhc's policy, labelled so, outside the clause matrix, and ceilings: floating and strictness change counts freely. A
`--count` test beside each 4.5.5 test is the one budget with a clause to point to. No paper tests that a compiler
preserves call-by-need. The nearest is Moran and Sands 1999: count steps, every transition of Sestoft's machine
(Definition 3.1), and require no increase in any context. GHC's practice is perf tests with tolerances.

**`-O0` is a reference only by audit.** Pałka 2012 held the hypothesis that `-O0` is right and found a program that
`-O0` miscompiled and `-O` fixed ("not always true"). He generated `[Int] -> [Int]` terms with `seq`, printed unbuffered
with exceptions caught, and compared `-O0` with `-O -fno-full-laziness`: about one failure per 10,000 terms, four bugs,
too-lazy code. Order of evaluation needs a model, so he left it.

**Bottom probes.** Haskell 98 cannot see bottom: "the Haskell standard provides no way for a program to make the same
observation" (Claessen, Hughes 2000). A probe is one process with a recorded prefix of output, which works on oracles,
or a private prim. `isBottom` sees only a bottom that raises, so timeouts stay (Danielsson, Jansson 2004). A test
expecting an error must assert refinement: some exception the source permits, not one message. Runs agree "using the
same compiler optimisation level" (Peyton Jones et al. 1999, §3.5). Bottom probes accept loop, abort and stack overflow
alike; differencing compares "failed", not stderr.

**A reference interpreter.** Launchbury 1993 as specification and Sestoft 1997 as program is the literature's answer.
Launchbury: normalised lambda calculus with recursive `let`, heap as a set of bindings, sharing by the Variable rule.
Its correctness proof fails as written; the theorem holds, repaired twice (Breitner 2014, sections read). Sestoft's Mark
1 is (heap, control, stack) with five rules, proved equivalent; "easily written in Scheme or Standard ML". Counters are
direct: `let` allocations, var1 entries, var2 updates. Gustavsson and Sands 2001 supply a space measure with named
assumptions. Neither has `seq` or IO; those rules are rhc's own, and the Report is their authority. It is slow by
design: 5.3 times slower than Gofer in 1997. Differencing must class black hole, divergence and stack overflow as one
bottom, and fix primitives' operand order [inference].

**Is there a Haskell conformance literature?** None found: no paper, no published suite. `conformance98`'s README says
"far from comprehensive", and that there is no good way to tell which cases should fail (`nhc98/tests/README:1,23`).
GHC's testsuite is per-feature directories, each bug adding a tiny program. SML has what Haskell lacks: a formal
Definition, HaMLet as a faithful model, and a defects list (Rossberg). A formal semantics was an explicit goal: "we
never achieved this goal" (Hudak et al. 2007, §3.4). The Core interpreter on a literal translation is rhc's nearest
HaMLet.

**D53: the conformance table.** The Report's clause matrix has no literature. The caution from Faxén is under D38. Yang
et al. 2011: coverage metrics barely moved while bugs were found, so a full clause matrix does not show the tests are
strong.

**D54: HsLint's basis.** Faxén 2002 gives inference rules for nearly all of Haskell 98, each relating source phrase,
target phrase and derived information, so each is at once a check and a translation. It is paper work: no
implementation, no tested programs. It defines a translation and gives a grammar for its target but no typing rules for
it. What it leaves out, in its own words: a proper treatment of ambiguity, strictness flags, newtype, deriving, mutually
recursive modules. THIH (Jones 1999) is an algorithm of 429 lines. It omits, in its own words, synonyms ("fully expanded
before typechecking"), dependency analysis ("carried out prior to type checking"), checks on class and instance
declarations, labelled fields, lambda, case, comprehensions and do ("simple translations"), and "the implementation of
overloading". It was run under Hugs on the Standard Prelude, Maybe and List and its own source. Its printed `BindGroup`
refinement goes beyond the Report, and the paper says conformance needs all implicit bindings in one list (§11.6.3). The
only published typing of a Haskell elaboration is Hall et al. 1996 §5.2, which is rank-1. **So neither basis checks
elaborated output,** and a target check cannot see what the plan most fears: `show (read "True")` elaborated at `Int`
and at `Bool` are both well typed at `[Char]`, with different meanings (Faxén, §10.2).

An independent check is therefore three layers, all of which D54 C takes [synthesis; the papers give the parts]:
- *Target typing.* Type-check the elaborated term as a System-F-like term with kinds, by Faxén's target grammar (figs 5,
  6) and rules in the style of Hall's calculus (figs 15-18). It needs no unification. This is close to CoreLint; the
  owner should decide if they are one tool. Its obligation is Hall's soundness statement.
- *Rule replay.* Check (source, elaborated) pairs against Faxén's judgements. His rules guess types in premises; the
  elaboration recorded the guesses, so replay is deterministic. Messages cite his rule names. The `min` premises of kind
  inference are obligations no rule discharges, so kinds are recomputed. Faxén names the two places a recorded choice is
  needed: where both his "dict inst" and "dict super" rules apply, and premises whose types are absent from the
  conclusion, as in the app rule (§10.2.2, p 355). His `bindg` rule with Definition 2 states Rule 1 of 4.5.5 (p 338), so
  replay checks Rule 1. It cannot refuse ambiguity, since his rules admit ambiguous schemes (§7.2.3), and has nothing
  for Rule 2, defaulting, deriving, newtype, strictness flags or recursive modules (§1.3). His module rules are per
  module, so an SCC needs a rule of rhc's own, and his deviations of §2.2, §4.2 and §4.3 (D38) are amended first
  [inference].
- *Second inference.* A transliteration of THIH's `tiImpls`, `split`, `candidates`, `tiProgram`, in its conformant form,
  re-derives each group's scheme, ambiguity, deferred predicates and default choice. Only this layer can check Rule 2 of
  4.5.5, ambiguity and defaulting (4.3.4). It still depends on rhc's renamer, dependency analysis and kinds.

Superclass paths give several correct elaborations (Faxén, §10.2.2; Bottu et al.), so the first two layers must accept
any route. No machine-checked work on Haskell 98 was found in Coq or Isabelle. No paper studies an independent check of
a Haskell front end's output as such. Core Lint's success depends on Core being typed to the end; below it `Any` leaves
MidLint weaker, so CoreLint must run just before the crossing and the translation must be small. The draft Faxén started
from, Peyton Jones and Wadler's, read now in a copy dated February 19, 1992, is no second basis: it lists imports,
ambiguity, `deriving` clauses, default methods in classes, and constant and n+k patterns as not covered (§1.2, p 5), and
has 22 judgement forms and 78 rule names by its index. It already says the rules admit several derivations (pp 5, 34),
which is why replay needs the recorded choices. E15 had held it under Faxén's key without knowing it
(`downloads/papers/faxen02.pdf`, the same md5).

**D55: generators and metamorphic relations.** Csmith's authors conclude "fixed test suites ... are an inadequate
mechanism for quality control". The only Haskell work is Pałka's, plus smaller efforts (Fetscher et al. 2015 [abstract],
declarative type rules doubling as a generator, beaten by a hand-built one). Applying with no authority (Chen et al.
2020; measured on GCC and LLVM by Chen et al. 2016, §1): cross-optimisation, most effective and most efficient on
optimisation bugs; EMI (Le et al. 2014), the weakest and least efficient oracle, needing no second compiler, whose lazy
form replaces a thunk unforced on input I by `undefined` [inference]; and metamorphic pairs, where Pałka's caught what
cross-optimisation missed (ticket 5557). Metamorphic relations fit the Report better than C: it defines its semantics by
translations, so each translation (`results/E9/translations.md`) is a relation citing a clause. Reduction: McKeeman's 23
transformations to a fixpoint; Regehr et al. 2012 [abstract], reducers must stay valid; with an AST printer a reducer is
small. Lazy SmallCheck's refinement picks partial inputs by demand (Runciman et al. 2008); StrictCheck compares demand
as data (Foner et al. 2018); both need instrumentation Haskell 98 lacks, so they belong in the Core interpreter. Depth
enumeration suits Prelude functions, not programs (Duregård et al.).

**D56: budget, and nofib.** Partain 1992 is a position paper with no results. Real is "by far the most important";
Imaginary "distinctly unimportant". "The initial nofib suite will have no value as a predictive tool". Its standard is
"version 1.2 or greater", so no conformance claim exists and its expected outputs are recorded behaviour. Marlow,
haskell-cafe 2010: "steadily degraded in usefulness". Peyton Jones, haskell-cafe 2007: Imaginary is "useless for (say)
choosing a compiler", useful for weak spots. No study of its representativeness was found. For rhc its age is a virtue:
list-heavy Report-mode Haskell is what it must run, and `--count` is immune to short runs. Report Real apart from
Imaginary. Measuring finds bugs in the passes, a "substantial hidden benefit" (Santos, §10.1), so track P should have
allocation and instruction counts per pass from its first day. Peyton Jones 1996 §4.2 found the compiler rebuilding its
symbol table on every lookup after months. A residency budget is what would see `f = drop 1000`, which neither
differencing nor `--count` will.

### Lazy ML (D57)

Wadler, Taha and MacQueen 1998 have odd against even by counting constructors, `delay` and `force`, Okasaki's `$`, the
`lazy` keyword by translation, and SML/NJ's `$` as a suspending constructor. On memoisation: "overwritten with a value,
so the expression is not evaluated again". On a raising suspension they say nothing. Their claim that `BlackHole` is
raised by `let val rec lazy x = x in x end` does not follow from their translation: the cell is reassigned before any
force. The translation needs only `susp`, `delay`, `force` and match compilation, and SML/NJ implemented it in under 300
lines, at elaboration. Only Peyton Jones et al. 1998 §5.5 face the semantics: with
`$(let val y = !r - 1 in r := y; if y = 0 then 0 else force x + force x end)` activations overlap, each with a value of
its own. "A thunk has only one value, and there can be at most one activation of the thunk" holds for L2, not ML;
black-holing that program would raise instead of terminating [inference]. So Haskell's force, reused, is not neutral for
lazy ML.

The fields of a force protocol, as a table (E15's synthesis, updated from E2):

| Field | Haskell 98 | SML/NJ-style lazy ML | Shared? |
|---|---|---|---|
| Object, update on return, barrier, non-tail force | yes | yes | yes |
| No safepoint between reading the kind and the field | yes | yes | yes |
| A dominated second force can go | yes | yes | yes |
| Force not removable, not moved across an effect | yes (bottom, lazy input) | yes | yes |
| On raise | nothing needed: the program ends | leave as is | yes: neither installs a handler |
| Closure released | wanted, for space | forbidden: a body may run again | **no** |
| Re-entry detection | optional | forbidden in SML/NJ's semantics | **no**, and follows from the row above |
| Collector's shortcut of `K_IND` | safe | needs a guard, for `susp (susp t)` | **guard** (E2: +0.9%) |
| A value as its own suspension | safe | needs a guard | **guard** |

So one bit per thunk or per entry code, two guards, no second protocol. Reid's freezing would be wrong for lazy ML,
since resuming skips effects already run. With collector-time release a raise pops frames with nothing to repair; with
entry-time blackholing a raise must revert, which needs the free variables kept anyway. So the form that lets the stack
share a protocol is the lazy one [inference]. E2 refines "one bit": form L makes it a collector-read bit plus an entry
check, and form G has no mode bit, Haskell's body saying blackhole and lazy ML's not. E14 ran the rest (D57). Should lazy ML
ever want release at entry, the price is OCaml's: a `try` in the force and a memoised raise, which changes the spec's
`lazy.raise_again`. All of Core's strictness, floating and eta are Haskell-only: speculation is "only safe because
Haskell is a pure language" (Ennals, Peyton Jones 2003), and in OCaml inappropriate eta can change results (Downen et
al. 2019, §1). "Laziness can be added to a strict language (although not as easily as you might think)" (Peyton Jones
2003, hair shirt).

**The collector's shortcut.** `runtime/gc/minor.c:151` and `runtime/gc/mark.c:155` shortcut a `K_IND` whatever its
target. OCaml refuses when the target is itself lazy (`ocaml5/runtime/minor_gc.c:377-378`); SML/NJ never shortcuts
(`smlnj/runtime/gc/minor-gc.c:392-395`). Bolingbroke §5.5 gives the failure in the abstract: with `f : {Int} = {bottom}`
and `g : {{Int}} = {f}`, aliasing `g` to `f` evaluates bottom in a program that should terminate. Haskell cannot hit
this, since Core's translation never starts a type with a thunk. Lazy ML can: E2 confirmed it, and a guard must look
through forwarding. Rune's choice to shortcut is OCaml 4's. The double-float problem (`ocaml5/stdlib/lazy.ml:39-43`)
cannot occur, since `K_REALS` is chosen by type (`runtime/prims.c:2939`). The rule stands: no runtime operation may take
a kind to reveal the static type.

## What the implementations do

E15 read ten implementations, by decision rather than by system, since no system answers all of them and each answer is
only useful beside the others. The full table is `results/E15/implementations.md`: 40 rows, 10 columns, 1,103 citations,
each snippet checked on its line by script (`results/E15/check_citations.py`, 0 failures). This section keeps what a
decision rests on.

Most of it is reading, not behaviour. **[inferred]** marks a cell where the citation supports the claim and a step of
reasoning is in E15's notes (`results/E15/impl/*.notes`). Absent means looked for and not there. What was run is in
*What was run* below.

Paths are relative to `/home/ruud/haskell`. `ghc/` is that tree's checkout of `ghc-9.14.1-release`, the same commit as
`/home/ruud/reference/ghc`; `ocaml4/`, `ocaml5/`, `smlnj/`, `mlton/`, `mlkit/` and `racket/` are under
`/home/ruud/reference`; `HaRe-0.6/` is `downloads/hare-0.6/x/` in the drafts. Revisions are in *References*.

What limits it:
- **GHC's cells read 9.14.1; the probe and oracle binary is 9.4.7.** A citation may not describe that binary.
- **jhc, UHC, Yhc, hbc, Programatica and Helium were not run.** Only GHC, Hugs, nhc98 and MicroHs were.
- Helium's runtime is not in this tree, so its runtime rows are absent. Programatica has no back end. The hbc tree is
  0.9999.4, a Haskell 1.4 compiler.

### The systems at a glance

| System | What it is | On Haskell 98 | Typed IR | Strict IR with thunks | A module cycle | CAF values | Selector rule |
|---|---|---|---|---|---|---|---|
| GHC | Native compiler | "aims to behave mostly as a Haskell 98 compiler" | Core, System FC | STG, in effect | boot files | collected | yes |
| nhc98 1.22 | Bytecode compiler, 32-bit | "pretty close to being compliant" | none | no | hand-written `.hi` | collected | yes |
| Yhc 0.7.0 | nhc98 with a bytecode file | "not useable as a standard Haskell compiler yet" | none | no | refused | kept | yes, one step |
| Hugs | G-code interpreter in C | adheres closely; FAQ: "Not quite" | none | no | refused | kept | no |
| MicroHs 0.16.12.0 | Combinators, small C runtime | none: "an extended subset of Haskell" | none | no | boot files | collected [inferred] | no |
| UHC | Attribute grammars, GRIN to bytecode | "almost all Haskell98 features" | placeholders in Core | GRIN, per module | refused | kept | no |
| jhc | Whole program to C | "Full support for Haskell 98", with stated exceptions | `E`, a PTS | Grin | **one unit per SCC** | kept | no |
| hbc 0.9999.4 | Native, in LML | Haskell 1.4, not 98 | none | no | interface iteration | collected [inferred] | no |
| Programatica | Front end, no back end | Revised Report, by its project page | decorated AST | none | **one unit per SCC** | no runtime | no runtime |
| Helium | Teaching subset | "a subset of Haskell" | none | not seen | refused | not seen | not seen |

### The IRs (D1, D2, D3, D8)

- **How many.** GHC: HsSyn, Core, STG, Cmm (`ghc/compiler/GHC/Hs/Extension.hs:172`,
  `ghc/compiler/GHC/Driver/Main.hs:2028`). jhc: HsSyn, `E`, lambda-lifted `E`, Grin, C (`jhc/src/Main.hs:110`). UHC: HS,
  EH, Core, Grin, bytecode (`uhc/EHC/src/ehc/EHC/CompilePhase/Translations.chs:187`). MicroHs: `Expr`, then `Exp`, then
  combinators (`MicroHs/src/MicroHs/Compile.hs:254`). Hugs goes from a mutated Cell tree to G-code in memory
  (`Hugs/src/compiler.c:1975`).
- **Typed below the source (D2):** GHC, checked by Core Lint (`ghc/compiler/GHC/Core/Lint.hs:129`); STG lint checks only
  representations (`ghc/compiler/GHC/Stg/Lint.hs:15`). jhc: `E` is a typed PTS, linted by `inferType`
  (`jhc/src/E/TypeCheck.hs:248`); Grin has only `TyNode`, `TyINode`, `TyPrim` (`jhc/src/Grin/Grin.hs:174`). UHC has
  placeholder types in Core, erased early (`uhc/EHC/src/ehc/EH/ToCore.cag:1520`, `uhc/EHC/src/ehc/Core/Trf.chs:165`).
  nhc98, Yhc, Hugs [inferred], MicroHs, hbc and Helium [inferred] are untyped throughout
  (`nhc98/src/compiler98/PosCode.hs:35`, `yhc/src/libraries/core/Yhc/Core/Type.hs:6`, `MicroHs/src/MicroHs/Exp.hs:27`,
  `hbc/src/ExprE/Expr_t.m:17`).
- **Where laziness becomes explicit (D3).** Never at one point in GHC: CorePrep let-binds non-trivial lazy arguments,
  CoreToStg tags closures updatable or single-entry, StgToCmm emits entry code [inferred]
  (`ghc/compiler/GHC/CoreToStg/Prep.hs:90`, `ghc/compiler/GHC/Stg/Syntax.hs:414`). jhc: `Grin.FromE`, where `cc`
  compiles lazy context and `ce` strict (`jhc/src/Grin/FromE.hs:577`, `:618`). UHC: `Core.ToGrin`, a lazy application
  becoming a stored node (`uhc/EHC/src/ehc/Core/ToGrin.cag:237`). nhc98: `PosCode`, with `Lift` lifting lazy case and if
  into new functions (`nhc98/src/compiler98/Lift.hs:150`). Hugs: only in the code generator (`Hugs/src/machine.c:666`).
  MicroHs: nowhere; an application node simply is the thunk (`MicroHs/src/MicroHs/Abstract.hs:115`).
- **A strict IR with explicit thunks (D1, D3).** Two, plus STG in effect.
  - UHC's GRIN, per module: thunks are stored `Fun` or `App` nodes, `Eval` and `App` are primitive forms
    (`uhc/EHC/src/ehc/GrinCode/AbsSyn.cag:85`).
  - jhc's Grin has `StoreNode`, `Eval`, `Apply`, `Demote`, `Promote` (`jhc/src/Grin/Grin.hs:97`).
  - GHC's STG: a zero-argument `\u` closure in a `let` is the thunk and `case` forces it, with no force operator or
    thunk type [inferred] (`ghc/compiler/GHC/Stg/Syntax.hs:291`).

  **Neither GRIN compiler still uses a generated whole-program `eval`.** jhc's `Eval` is a call through the thunk's code
  pointer, and only `Apply` is a generated case (`jhc/src/C/FromGrin2.hs:590`, `jhc/src/Grin/EvalInline.hs:97`). UHC's
  generated eval is gone from this tree, with the HPT analysis (`uhc/EHC/changelog.md:36`,
  `uhc/EHC/src/ehc/Base/Target.chs:258`). So a strict IR with explicit thunks does not need one, which bears on D47's
  strongest objection. None of them keeps a typed strict IR with passes of its own beneath a lazy typed Core, as D1
  proposes.

### Runtime (D11-D19)

**Thunk layout and update (D11).**

| System | Layout | Words | Update |
|---|---|---|---|
| GHC | info pointer, a padding word that later holds the indirectee, payload (`ghc/rts/include/rts/storage/Closures.h:43`) | 2+n | update frame; the result word, then the header (`ghc/rts/Updates.h:469`) |
| nhc98 | header pointing at a per-function need and size pair, with a ZAP bit (`nhc98/src/runtime/Kernel/node.h:17`) | 1+n | no separate frame: return writes an indirection, always (`nhc98/src/runtime/Kernel/mutator.c:475`) |
| Yhc | info word, low bits IND, NORMAL, GC, HOLE (`yhc/src/runtime/BCKernel/node.h:20`) | 1+n | as nhc98 (`yhc/src/runtime/BCKernel/muthelpers.h:87`) |
| Hugs | an AP pair per argument, no header (`Hugs/src/storage.h:208`) | 2 per argument | compiled code ends in RUPDATE over the redex root (`Hugs/src/machine.c:1749`) |
| MicroHs | a two-word application cell (`MicroHs/src/runtime/eval.c:598`) | 2 per argument | every reduction overwrites the root (`MicroHs/src/runtime/eval.c:5714`) |
| UHC | header, code pointer, arguments (`uhc/EHC/src/rts/bc/types.ch:135`) | 2+n | a frame, then `Ind` (`uhc/EHC/src/rts/bc/interpreter.cc:1488`) |
| jhc | code pointer tagged 0b11, then fields (`jhc/rts/rts/jhc_rts.h:18`) | 1+n | no frame: a generated wrapper calls `f`, then writes the result in the head (`jhc/src/C/FromGrin2.hs:899`) |
| hbc | AP of 3 words, or a VAP with arguments inline (`hbc/src/runtime/node.h:208`) | 3, or 2+arity | copies the result over the root (`hbc/src/mcode/mupdate.m:22`) |

Form G's flat `K_CLOSURE` with the update in the thunk's own code is nearest jhc's wrapper, at 1+n plus an object
header. GHC's padding word exists so a payload survives update. Form G has that need only for a closed function, whose
fresh object gets a spare field (read from `patches/E2-all-forms.patch`).

**Indirection removal.** All remove them in the collector: GHC (`ghc/rts/sm/Evac.c:980`), nhc98
(`nhc98/src/runtime/Kernel/mark.c:156`), Yhc (`yhc/src/runtime/BCKernel/mark.c:353`), Hugs (`Hugs/src/storage.c:1992`),
MicroHs (`MicroHs/src/runtime/eval.c:2857`), UHC (`uhc/EHC/src/rts/mm/gbm/gbtrace.cc:85`), jhc
(`jhc/rts/rts/gc_jgc.c:109`), hbc (`hbc/src/runtime/garb.M:644`). Yhc also strips them when building nodes
(`yhc/src/runtime/BCKernel/mutins.h:148`).

**Force (D13).** Native GHC tests the pointer tag, then jumps through the info pointer
(`ghc/compiler/GHC/StgToCmm/Expr.hs:1216`). Every bytecode system has an EVAL that tests a header: nhc98
(`nhc98/src/runtime/Kernel/mutator.c:427`), Yhc (`yhc/src/runtime/BCKernel/mutins.h:382`), UHC
(`uhc/EHC/src/rts/bc/interpreter.cc:1402`). jhc's `eval` tests a low bit and calls through the head
(`jhc/rts/rts/jhc_rts.c:136`). hbc's tag table has an eval entry, and `-O` tests inline first
(`hbc/src/mcode/meval.m:46`). GHCi switches on closure type (`ghc/rts/Interpreter.c:791`). None has a library force.
nhc98 is the nearest precedent for a bytecode VM with thunks.

**Blackholing (D12).**
- **Lazy, at a stop:** GHC blackholes update-frame thunks when a thread stops (`ghc/rts/ThreadPaused.c:331`), and
  reports `<<loop>>` when a collection finds a self-blocked thread (`ghc/rts/Schedule.c:3343`). This is the literature's
  form, and form L's.
- **Eager:** nhc98 sets a ZAP bit in EVAL, and re-entry aborts with "Black hole detected."
  (`nhc98/src/runtime/Kernel/mutator.c:461`); liveness-driven `ZAP_ARG` also clears dead arguments
  (`nhc98/src/compiler98/GcodeMem.hs:19`). Yhc's holes block the thread, which then deadlocks
  (`yhc/src/runtime/BCKernel/process.c:266`). UHC panics "black hole", for `Fun` thunks only
  (`uhc/EHC/src/rts/bc/interpreter.cc:1467`). hbc overwrites the root with ZAP when the body may tail-call or collect
  (`hbc/src/mcode/mfunstart.m:88`).
- **None:** Hugs, except that its collector finds pure indirection cycles (`Hugs/src/storage.c:2105`); other
  self-dependence reaches "Control stack overflow". MicroHs (`MicroHs/src/runtime/eval.c:514`). jhc in normal builds
  [inferred] (`jhc/rts/rts/jhc_rts.c:145`).

So detection is optional in practice as in the Report, and the four systems that ran differ in what a program sees
(*What was run*).

**An exception through a thunk (D12, D57).** GHC updates each thunk under evaluation with one raising closure, and
freezes on an asynchronous exception (`ghc/rts/Exception.cmm:433`, `ghc/rts/RaiseAsync.c:895`). UHC overwrites each with
a rethrowing node (`uhc/EHC/src/rts/bc/interpreter.cc:1976`). **Nothing passes through in nhc98 and jhc:** `error`
prints and exits, and `catch` sees only `Left IOError` (`nhc98/src/prelude/LowB/PrimError.hs:8`,
`nhc98/src/prelude/PreludeIO/Catch.hs:11`, `jhc/lib/jhc/Jhc/IO.hs:88`). hbc's `catch` sees only `IOError`, leaving
thunks as they stand, so a re-force reports a black hole [inferred] (`hbc/src/runtime/mrun.M:3570`). Hugs and MicroHs
longjmp and leave thunks alone [inferred] (`Hugs/src/machine.c:1907`, `MicroHs/src/runtime/eval.c:6607`). Yhc leaves
them as holes, so re-forcing deadlocks [inferred] (`yhc/src/runtime/BCKernel/mutins.h:675`). So Haskell 98 systems that
need no repair exist; D12's rule not to repair has precedent.

**Lazy values in strict languages (D12, D57).** Read by E15 for the question of what lazy ML should do:

| Implementation | Body raises | Re-entry | Closure during evaluation |
|---|---|---|---|
| SML/NJ `Core.force` (`smlnj/system/smlnj/init/target64-core.sml:194-201`) | not updated, re-run | re-run, undetected | kept |
| MLKit `Susp` (`mlkit/basis/Susp.sml:13-17`) | re-run | re-run | kept |
| MLton `Promise` (`mlton/lib/mlton/basic/promise.sml:36-47`) | reset, re-run | raises `Force` | restored by the handler |
| OCaml 5 (`ocaml5/stdlib/camlinternalLazy.ml:44-56`) | memoised as a raising closure | `Undefined` | released at entry |
| Racket (`racket/racket/collects/racket/private/promise.rkt:69-71`, `:114`) | memoised | "reentrant promise" | not checked |
| `examples/benchmarks/shared/lazy.sml:7-15` | memoised | `Fail` | dropped |
| runespec `spec/ext/lazy.rs` (branch `runespec`) | not updated, re-run | re-run, undetected | kept |

All the SML systems re-run. OCaml, Racket and GHC memoise. Rune's spec is what SML/NJ does; the shipped module matches
neither, which E2 also found. OCaml releases at entry only because it stores the raise.

**Eval/apply (D15).** Eval/apply: GHC (`ghc/utils/genapply/Main.hs:1297`), nhc98
(`nhc98/src/runtime/Kernel/mutator.c:379`), Yhc (`yhc/src/runtime/BCKernel/mutins.h:280`), UHC
(`uhc/EHC/src/rts/bc/interpreter.cc:1586`), jhc (`jhc/src/Grin/EvalInline.hs:145`). Spine unwinding, closest to
push/enter: Hugs (`Hugs/src/machine.c:1329`), MicroHs (`MicroHs/src/runtime/eval.c:5710`), hbc
(`hbc/src/runtime/mrun.M:964`), all [inferred]. So every system with a partial-application object took eval/apply, and
push/enter survives only in spine unwinding.

Partial applications: GHC's `StgPAP` has arity, count, function, payload (`ghc/rts/include/rts/storage/Closures.h:132`).
nhc98's CAP has VAP's layout with a header at an earlier need/size pair (`nhc98/src/runtime/Kernel/newmacros.h:125`).
jhc uses an ordinary node tagged by arguments missing, and takes one argument at a time
(`jhc/src/Grin/EvalInline.hs:120`). UHC allocates a fresh larger PAP (`uhc/EHC/src/rts/bc/interpreter.cc:1540`). Hugs,
MicroHs and hbc have no object: the spine is it (`Hugs/src/machine.c:1606`, `MicroHs/src/runtime/eval.c:5835`,
`hbc/src/runtime/mrun.M:877`).

**Selector thunks (D17).** GHC: `THUNK_SELECTOR`, reduced in the collector, nesting capped at 16
(`ghc/rts/sm/Evac.c:61`, `ghc/compiler/GHC/StgToCmm/Bind.hs:367`). nhc98: single-constructor field selectors get
`SELECTOR_EVAL`, and mark reduces chains; the code calls this Wadler (`nhc98/src/compiler98/STGGcode.hs:22`,
`nhc98/src/runtime/Kernel/mark.c:226`). Yhc: one step, no chains (`yhc/src/runtime/BCKernel/mark.c:283`). Not done: Hugs
(`Hugs/src/compiler.c:1029`), MicroHs (`MicroHs/src/runtime/eval.c:7945`), UHC (`uhc/EHC/src/rts/mm/gbm/gbtrace.cc:70`),
and jhc, whose collector knows only pointer counts per slab (`jhc/rts/rts/gc_jgc.c:101`). hbc has Sparud's sibling
update as `-fpat-bin-update`, off by default (`hbc/src/transform/match.m:31`). So half the systems ship the leak, which
is D17's ruling in practice.

**Depth (D18).**

| System | Stack | Limit | On overflow |
|---|---|---|---|
| GHC | heap-allocated chunks, 32k, linked (`ghc/rts/RtsFlags.c:141`) | 80% of physical memory | exception, "Stack space overflow", exit 2 (`ghc/rts/hooks/StackOverflow.c:17`) |
| nhc98 | one block, heap up, stack down (`nhc98/src/runtime/Kernel/mutator.c:188`) | the heap | "ran out of heap memory" (`nhc98/src/runtime/Kernel/collector.c:627`) |
| Yhc | a heap node doubled on EVAL (`yhc/src/runtime/BCKernel/mutins.h:425`) | 1 MB, `-s` (`yhc/src/runtime/BCKernel/main.h:5`) | "ran out of stack!" |
| Hugs | fixed cell stack and C stack (`Hugs/src/storage.h:1103`) | 160000; eval depth 16384 (`Hugs/src/machine.c:1319`) | "Control stack overflow" |
| MicroHs | fixed explicit stack (`MicroHs/src/runtime/eval.c:504`) | 250000 entries, `-K` | fatal, exit 1 (`MicroHs/src/runtime/eval.c:825`) |
| UHC | fixed, 0xF00000 words (`uhc/EHC/src/rts/rts.ch:111`) | fixed | panic (`uhc/EHC/src/rts/bc/interpreter.cc:1008`) |
| jhc | C stack, unchecked [inferred] (`jhc/rts/rts/jhc_rts.c:149`) | system | crash |
| hbc | fixed pointer stack (`hbc/src/runtime/main.c:86`) | 100000 words, `-A` | catchable where mprotect is configured (`hbc/src/runtime/mrun.M:3688`) |

Only the growable stack passes the probes. Rune's 1 GiB is a large limit, which E2 shows sufficient for a 10^7 chain.

**CAFs (D19).** Collected by tracing from live code: GHC, by static reference tables (`ghc/rts/sm/Storage.c:594`,
`ghc/rts/sm/Scav.c:414`); nhc98, through constant tables of reachable code (`nhc98/src/runtime/Kernel/mark.c:322`); hbc,
through info vectors [inferred] (`hbc/src/runtime/garb.M:48`); MicroHs, whose definitions are ordinary graph nodes
[inferred] (`MicroHs/src/runtime/eval.c:4356`). Retained for ever: Yhc (`yhc/src/runtime/BCKernel/mark.c:480`), Hugs
(`Hugs/src/storage.c:3609`; its guide lists the leak), UHC (`uhc/EHC/src/rts/mm/gbm/gbtracesupmodule.cc:52`), jhc
(`jhc/src/C/FromGrin2.hs:900`). Rune's globals as roots are the second group, D19's starting point.

### Data (D20-D25)

**`Integer` (D20).** No system has an immediate small `Integer`, beyond Hugs's zero. GHC: `IS Int#`, `IP`, `IN`, boxed,
with no shared small table (`ghc/libraries/ghc-internal/src/GHC/Internal/Bignum/Integer.hs:176`). nhc98: a boxed
sign-magnitude node (`nhc98/src/runtime/Builtin/primIntegerFromInt.c:18`). Hugs: base-10000 digits in a heap list, with
literals in `Int` range through `fromInt` (`Hugs/src/bignums.c:125`). MicroHs: a `ForeignPtr` to imath
(`MicroHs/lib/Data/Integer_Type.hs:28`). UHC: a GMP or LibTomMath node (`uhc/EHC/src/rts/bc/types.ch:234`). hbc: BIGNUM
node, and a triple literal gives `Int` and `Double` without conversion (`hbc/src/ExprE/classtrans.m:57`). Two do not
conform: jhc's `Integer` is one `intmax_t` (`jhc/lib/jhc/Jhc/Type/Basic.hs:13`, `jhc/docs/differences.mkd:45`), and
Helium's is `type Integer = Int` (`helium/lib/Prelude.hs:137`).

**`Char` (D21).** Full Unicode: GHC, maxBound 0x10FFFF (`ghc/libraries/ghc-internal/src/GHC/Internal/Char.hs:19`); Hugs,
below 1280 immediate, identifiers Latin-1 (`Hugs/src/prelude.h:181`, `Hugs/src/char.h:32`); MicroHs,
`newtype Char = Char Word` (`MicroHs/lib/Primitives.hs:32`); UHC with gnulib tables
(`uhc/EHC/src/rts/base/unicode.cc:2`). Not usably: nhc98's `Bounded Char` is `'\255'`
(`nhc98/src/prelude/Prelude/Bounded_Char.hs:5`); hbc too (`hbc/src/hlib1.3/I_Bnd_Char.hs:4`); Yhc's `enumFrom` stops at
255 (`yhc/src/packages/yhc-base-1.0/Prelude.hs:1243`). jhc holds a 32-bit `wchar_t` with byte-wise I/O
(`jhc/rts/lib/lib_cbits.h:21`). So a Unicode `Char` has good precedent and nhc98 is no oracle above 255.

**`Int` (D22).** Word-sized: GHC, wrapping unchecked (`ghc/docs/users_guide/bugs.rst:518`); Yhc, though its Prelude
bounds stay 32-bit (`yhc/src/packages/yhc-base-1.0/Prelude.hs:837`); UHC, 62 bits on 64-bit, tagged
(`uhc/EHC/src/rts/base/sizes.ch:72`). 32-bit: nhc98 (`nhc98/src/prelude/Prelude/Bounded_Int.hs:3`), Hugs even on 64-bit
hosts (`Hugs/src/prelude.h:695`), jhc (`jhc/lib/jhc/Jhc/Type/Word.hs:17`), hbc with a `minBound` off by one [inferred]
(`hbc/src/hlib1.3/I_Bnd_Int.hs:7`). MicroHs alone traps: `+`, `-`, `*` raise `Overflow` under its Unix config
(`MicroHs/src/runtime/unix/config.h:85`), the one precedent for D22's checked prims. So oracles differ on overflow:
nhc98's 32-bit wrap is visible in the probes, no oracle has Rune's 63 bits, and a test that overflows `Int` has no
shared answer.

**String literals (D24).** Lazily unpacked, one cell per demand: GHC, through `unpackCString#`
(`ghc/libraries/ghc-internal/src/GHC/Internal/CString.hs:179`, `ghc/compiler/GHC/Core/Make.hs:329`); nhc98 and Yhc by a
`STRING` opcode [inferred] (`nhc98/src/runtime/Kernel/mutator.c:773`, `yhc/src/runtime/BCKernel/mutins.h:531`); Hugs
(`Hugs/src/machine.c:1666`); hbc (`hbc/src/runtime/mrun.M:1351`); UHC, on the Haskell side
(`uhc/EHC/ehclib/uhcbase/UHC/Base.chs:246`). MicroHs's first force builds the whole list
(`MicroHs/src/runtime/eval.c:6469`). jhc builds static cons cells, with nothing lazy [inferred]
(`jhc/src/E/Values.hs:91`).

**`IO` (D25).**
- *Token function:* GHC, an erased `State#` with an unboxed pair
  (`ghc/libraries/ghc-internal/src/GHC/Internal/Types.hs:553`); jhc, the same (`jhc/lib/jhc-prim/Jhc/Prim/IO.hs:16`);
  UHC, a real boxed pair (`uhc/EHC/ehclib/uhcbase/UHC/Base.chs:2138`); MicroHs, with a Scott-encoded result
  (`MicroHs/src/runtime/eval.c:6695`).
- *Dummy world, not threaded:* nhc98, `World -> Either IOError a`, so bind tests each step
  (`nhc98/src/prelude/Internal/Internal.hs:72`, `nhc98/src/prelude/PreludeIO/Monad_IO.hs:13`); Yhc, with real
  exceptions, so bind only unwraps (`yhc/src/packages/yhc-base-1.0/YHC/Internal.hs:81`).
- *Continuation:* Hugs (`Hugs/libraries/hugsbase/Hugs/Prelude.hs:1908`); hbc, over dialogues
  (`hbc/src/hlib1.3/_LibIO.hs:9`).
- *Unit function:* **Helium, nearest D25's form:** `bindIO io f = \_ -> case io () of IORes x -> f x ()`, a function
  of unit returning a one-field box, `() -> IORes a` (`helium/lib/LvmLang.core:104-105`, `:315`).

**Lazy input (D25).** `unsafeInterleaveIO` per character or chunk in a library: GHC
(`ghc/libraries/ghc-internal/src/GHC/Internal/IO/Handle/Text.hs:408`), MicroHs (`MicroHs/lib/System/IO/Base.hs:222`),
jhc (`jhc/lib/jhc/Prelude/IO.hs:58`), UHC (`uhc/EHC/ehclib/uhcbase/UHC/IO.chs:384`), Yhc through `unsafePerformIO`
(`yhc/src/packages/yhc-base-1.0/System/IO.hs:136`). A special primitive: Hugs, `_hreader` (`Hugs/src/iomonad.c:902`);
nhc98, an `HGETS` opcode with no semi-closed handles (`nhc98/src/prelude/IO/HGetContents.hs:16`); hbc, an INPUT node
(`hbc/src/runtime/mrun.M:1399`). D25's one interleaving primitive sits between these. GHC raises read errors where the
Report discards them (`ghc/docs/users_guide/bugs.rst:476`). Helium has no `getContents` (`helium/lib/Prelude.hs:651`).

### Front end (D27-D34)

**Layout's parse-error(t) (D27).**
- **Yacc's error token:** GHC, a `close` rule with an `error` alternative (`ghc/compiler/GHC/Parser.y:4188`); Hugs
  (`Hugs/src/parser.y:1018`); Programatica, a Happy `close`
  (`programatica/src/programatica/tools/base/parse2/Lexer/HsLexer.hs:14`).
- **The parser tells the lexer, with no error token:** nhc98 and Yhc, where `rcurl` facing a non-brace calls
  `lexicalCont` (`nhc98/src/compiler98/Parse/ParseLib.hs:160`, `nhc98/src/compiler98/Parse/Lexical.hs:45`); MicroHs,
  `popLayout` (`MicroHs/src/MicroHs/Parse.hs:399`, `MicroHs/src/MicroHs/Lex.hs:541`), restoring the stack on
  backtracking; hbc, a list of Badtokens (`hbc/src/syntax/curry.y:1174`); UHC, a popped-context alternative [inferred]
  (`uhc/EHC/src/ehc/Scanner/Common.chs:465`). `closeImplicit` is this family.
- **A token pass that approximates:** jhc's Layout2, with a bracket stack and per-block state
  (`jhc/src/FrontEnd/Lex/Layout2.hs:92`). tree-sitter-haskell, by heuristics: "Ending layouts with `in` heavily relies
  on parse errors in GHC, so this is difficult" (`tree-sitter-haskell/src/scanner.c:1955`).
- **Refused:** Helium, by design: only `in` closes a `let` (`helium/LAYOUTRULE.md:115`).

The other half of D27 is **what any implementation did with the Report's layout, to the letter: nothing.** R1's
fixity-dependent reading is implemented by none. GHC and Hugs document the deviation
(`ghc/docs/users_guide/bugs.rst:162`, `Hugs/docs/users_guide/haskell98.xml:57-63`). GHC adds NondecreasingIndentation
under `-XHaskell98` (`ghc/docs/users_guide/bugs.rst:127`). An explicit `}` closing an implicit block is accepted by GHC,
Hugs and MicroHs, refused by nhc98 (E10, R2), and Programatica accepts it in a comment-noted deviation
(`programatica/src/programatica/tools/base/parse2/Lexer/HsLexer.hs:40`). haskell-src pushes `max (indent+1) col`, not
the Report's `{n}` test (`haskell-src/Language/Haskell/ParseMonad.hs:166`); whether results differ was not established.
So a literal L, with the pinned reading of R1, has no precedent.

**Parser technique (D27).** Generated LALR: GHC (`ghc/compiler/GHC/Parser.y:104`), Hugs (`Hugs/src/parser.y:4`), jhc,
deliberately over-permissive (`jhc/src/FrontEnd/Lex/Parser.y.pp:3`), hbc (`hbc/src/syntax/Makefile:100`), Programatica.
Hand-written combinators: nhc98 and Yhc, backtracking with commit (`nhc98/src/compiler98/Parse/ParseCore.hs:27`);
MicroHs, ordered choice (`MicroHs/src/Text/ParserComb.hs:56`); Helium, Parsec (`helium/src/Helium/Parser/Parser.hs:38`);
UHC, error-correcting (`uhc/EHC/src/ehc/HS/Parser.chs:10`). Hand-written recursive descent in SML is new only in its
host language.

**Fixity (D29).** After parsing in all but hbc, whose lexer maps operators to yacc precedence tokens
(`hbc/src/syntax/currylex.c:438`). In the renamer: GHC (`ghc/compiler/GHC/Rename/HsType.hs:1374`), nhc98 and Yhc
(`nhc98/src/compiler98/Rename.hs:697`). Elsewhere after names: Hugs (`Hugs/src/static.c:5175`), jhc
(`jhc/src/FrontEnd/Tc/Module.hs:136`), Programatica (`programatica/src/programatica/tools/base/defs/ReAssoc.hs:48`),
Helium, as its own phase (`helium/src/Helium/Main/Compile.hs:58`). In the checker: MicroHs
(`MicroHs/src/MicroHs/TypeCheck.hs:1987`). D29's order, fixity after names, is the common one.

**The renamer (D29).** A pass of its own: GHC (`ghc/compiler/GHC/Tc/Module.hs:1689`), nhc98
(`nhc98/src/compiler98/Rename.hs:44`), Yhc, jhc, which also desugars first (`jhc/src/FrontEnd/Rename.hs:194`), hbc
(`hbc/src/rename/rename.m:3`), Programatica (`programatica/src/programatica/tools/base/defs/ScopeModule.hs:9`). Not a
pass: Hugs (`Hugs/src/static.c:6576`), MicroHs (`MicroHs/src/MicroHs/TypeCheck.hs:1972`), UHC
(`uhc/EHC/src/ehc/HS/NameAnalysis.cag:2`), Helium.

**Literate source (D27).** A text filter before the lexer in GHC (`ghc/compiler/GHC/Driver/Phases.hs:180`), nhc98
(`nhc98/src/compiler98/Unlit.hs:19`), Yhc, MicroHs (`MicroHs/src/MicroHs/Compile.hs:369`), jhc, from the Report's
appendix (`jhc/src/FrontEnd/Unlit.hs:4`), hbc and Programatica. In the lexer: Hugs (`Hugs/src/input.c:393`), UHC, which
keeps source positions (`uhc/EHC/src/ehc/Scanner/Machine.chs:163`). Absent: Helium.

**The checker (D31).** Algorithm W threading a substitution: nhc98, Yhc (`nhc98/src/compiler98/Type/Type.hs:581`), hbc,
after match compilation (`hbc/src/type/hcheck.m:192`), Hugs, by a global mutable substitution [inferred]
(`Hugs/src/type.c:710`). THIH's lineage: jhc, rewritten as boxy bidirectional checking
(`jhc/src/FrontEnd/Tc/Main.hs:39`). Constraints solved at each generalise: Programatica
(`programatica/src/programatica/tools/base/TI/TiSolve.hs:19`). A constraint tree: Helium, for messages
(`helium/src/Helium/StaticAnalysis/Inferencers/TypeInferenceRules.ag:20`). OutsideIn: GHC alone
(`ghc/compiler/GHC/Tc/Types/Constraint.hs:1032`). So nobody needs a solver with implications to check Haskell 98.
nhc98's `Type/` is about 1960 lines and hbc's `hbc/src/type/hcheck.m` 468, which is the scale of the core.

**Dictionaries (D31, D54).** All during inference, by a placeholder filled later, except Helium's side tables after
solving (`helium/src/Helium/ModuleSystem/DictionaryEnvironment.hs:28`) and jhc, which has no evidence: predicates are
dropped converting to `E`, methods stay placeholders until a whole-program typecase (`jhc/src/E/FromHs.hs:95`,
`jhc/src/E/TypeAnalysis.hs:381`). GHC: mutable `EvBindsVars` the solver fills
(`ghc/compiler/GHC/Tc/Types/Evidence.hs:175`). Hugs: a `DICTVAR` cell overwritten by entailment (`Hugs/src/preds.c:74`).
nhc98: arguments read lazily from a knot-tied table (`nhc98/src/compiler98/Type/Type.hs:121`). hbc: a lazy table
(`hbc/src/type/conutil.m:179`). UHC: `Hole` placeholders filled by a substitution over Core
(`uhc/EHC/src/ehc/Core/AbsSyn.cag:191`). MicroHs: bindings wrapped round equations, with no later pass
(`MicroHs/src/MicroHs/TypeCheck.hs:2755`). A ref cell per placeholder in SML is Hugs's way.

**Kinds (D31).** Inferred with defaults to `*` by GHC, Hugs (`Hugs/src/static.c:2317`), UHC, jhc in one run with no SCC
order (`jhc/src/FrontEnd/KindInfer.hs:117`), hbc (`hbc/src/rename/kind.m:23`), MicroHs by its one checker
(`MicroHs/src/MicroHs/TypeCheck.hs:1176`), Programatica (`programatica/src/programatica/tools/base/TI/TiDs.hs:66`).
**Absent in nhc98 and Yhc:** a documented bug, "no kind check in type definitions" (`nhc98/docs/bugs.html:70`,
`nhc98/src/compiler98/NT.hs:54`). So nhc98 is no oracle for kinds.

**Monomorphism restriction (D32).**
- As the Report: GHC, no deviation found [inferred] (`ghc/compiler/GHC/Tc/Gen/Bind.hs:782`,
  `ghc/compiler/GHC/Tc/Solver.hs:1528`); jhc (`jhc/src/FrontEnd/Tc/Main.hs:888`); Programatica
  (`programatica/src/programatica/tools/base/TI/TiGeneralize.hs:96` for the restriction's partition), with Rule 2 by
  deferral to the end of the module or module group (`programatica/src/programatica/tools/base/TI/TiModule.hs:55`).
- Rule 2 deviates: Hugs, defaulting each top-level group at once (`Hugs/src/type.c:1963`), which E7 confirms by running:
  30 corpus programs are rejected by Hugs alone, those read are this case.
- Not implemented: nhc98, documented (`nhc98/docs/98.html:28`); Yhc [inferred] (`yhc/src/compiler98/Type/Type.hs:282`).
  Relaxed: UHC (`uhc/EHC/src/ehc/HS/ToEH.cag:1141`), MicroHs at top level [inferred]
  (`MicroHs/src/MicroHs/TypeCheck.hs:1654`), Helium
  (`helium/src/Helium/StaticAnalysis/Inferencers/TypeInferenceOverloading.ag:80`), hbc for `f = \x -> ...` [inferred]
  (`hbc/src/type/hcheck.m:55`).

**Defaulting (D32).** At module end: GHC, though its `standardClassKeys` admits non-Report classes
(`ghc/compiler/GHC/Tc/Solver.hs:489`, `ghc/compiler/GHC/Builtin/Names.hs:2747`), and Programatica
(`programatica/src/programatica/tools/base/TI/TiModule.hs:55`). At each generalisation: Hugs (`Hugs/src/preds.c:959`),
nhc98 and Yhc, with no numeric-class test (`nhc98/src/compiler98/Type/Ctx.hs:201`); E7 shows the effect, nhc98 printing
`[(1,"x23")]` for `reads "1x23"` where the others reject. jhc: `default` declarations parsed and unused
(`jhc/src/FrontEnd/Tc/Class.hs:230`). UHC: per class, the Report's form ignored (`uhc/EHC/src/ehc/HS/ToEH.cag:230`).
hbc: the 1.4 list, `(Int, Double)` (`hbc/src/transform/remsign.m:24`).

**Deriving (D33).** On the renamed AST, before typing: nhc98 and Yhc, contexts by fixpoint iteration
(`nhc98/src/compiler98/MainNhc98.hs:220`, `nhc98/src/compiler98/Derive/Derive.hs:186`), and hbc
(`hbc/src/rename/deriv.m:32`). On source syntax: Hugs, before dependency analysis (`Hugs/src/static.c:7075`,
`Hugs/src/static.c:3056`); jhc, inside the renamer (`jhc/src/Deriving/Derive.hs:61`). Inside the checker: GHC, from the
`TyCon`, renamed then typechecked as user code (`ghc/compiler/GHC/Tc/Deriv/Generate.hs:218`); MicroHs
(`MicroHs/src/MicroHs/TypeCheck.hs:1131`); Programatica, with contexts by context reduction
(`programatica/src/programatica/tools/base/TI/TiDerivedInstances.hs:88`). On Core: UHC
(`uhc/EHC/src/ehc/Deriving.chs:93`). nhc98, Yhc, Hugs, hbc and Programatica compute the context by a fixed point, as
D33's split of code from context needs.

**Match compilation (D34).** The mixture rule, left to right, keeping the Report's order, everywhere that has a matrix:
GHC [inferred] (`ghc/compiler/GHC/HsToCore/Match.hs:91`), nhc98 (`nhc98/src/compiler98/Case.hs:304`), Yhc, Hugs
[inferred] (`Hugs/src/compiler.c:1063`), MicroHs (`MicroHs/src/MicroHs/Desugar.hs:413`), UHC [inferred]
(`uhc/EHC/src/ehc/AbstractCore/Utils.chs:354`), jhc [inferred] (`jhc/src/E/FromHs.hs:849`), hbc [inferred]
(`hbc/src/transform/case.m:31`). Helium tests each clause in turn
(`helium/src/Helium/CodeGeneration/PatternMatch.hs:217`). Programatica applies 3.17.3 literally in an optional rewrite
(`programatica/src/programatica/tools/base/transforms/SimpPatMatch.hs:37`). **None of the ten uses decision trees.**
D34's default stands on all of them.

### Recursive modules (D30, D36)

*The Report allows them; the implementations mostly do not.*

| Implementation | A cycle is | Extra files | Inference across the cycle | Source |
|---|---|---|---|---|
| Programatica | one unit per SCC: least fixed point for names, one joined module for types | none | yes, no signatures needed | `programatica/src/programatica/tools/base/Modules/Modules.lhs:364`, `programatica/src/programatica/tools/base/TI/TiModule.hs:62` |
| jhc | one unit per SCC: a lazy knot for names, declarations pooled for types, one `.ho` | none | yes, no signatures needed | `jhc/src/Ho/Build.hs:304`, `jhc/src/FrontEnd/Tc/Module.hs:139` |
| GHC | one module at a time, each cycle broken by a hand-written boot file | `.hs-boot` | no: the boot gives the signatures | `ghc/docs/users_guide/separate_compilation.rst:742` |
| MicroHs | as GHC, with linking by name closing the knot | `.hs-boot` | no | `MicroHs/src/MicroHs/Compile.hs:193` |
| hbc 0.9999.4 | rerun the compiler until the interface files stop changing [inferred] | an existing `.hi` per import | by iteration | `hbc/README.txt:29` |
| nhc98 | a hand-written or earlier `.hi`, in a hand-ordered build | `.hi` | no | `nhc98/docs/interface.html:20` |
| Yhc | refused: "Cyclic dependency detected" | | | `yhc/src/compiler98/Make.lhs:322` |
| Hugs | refused: "Recursive import dependency" | | | `Hugs/src/script.c:249` |
| UHC | refused, though it has the SCC list | | | `uhc/EHC/src/ehc/EHC/CompilePhase/TopLevelPhases.chs:183` |
| Helium | refused: `CircularImport` | | | `helium/src/Helium/Main/Make.hs:42` |

Of ten, two compile a cycle with no extra files, and neither has been maintained for years. Neither was run here.

**jhc.** `toCompUnitGraph` condenses the import graph with `G.sccGroups` (`jhc/src/Ho/Build.hs:304`), its comment naming
"sets of mutually recursive modules" as nodes (`:290`). `determineExports'` computes exports over the group by a lazy
`mdo` knot (`jhc/src/FrontEnd/Exports.hs:82`). That is not an iteration to a least fixed point, so what it does on a
pathological export cycle is not established. `tiModules` takes the list of modules
(`jhc/src/FrontEnd/Tc/Module.hs:118`), pools every declaration (`:139`), infers kinds, classes and fixities for the
pool, and analyses dependencies so binding groups cross module boundaries (`:224`), then runs `tiProgram` once (`:255`).
So inference across the cycle is ordinary binding-group inference. The group is one `.ho`, named for the first module in
sorted order (`jhc/src/Ho/Build.hs:628`). The docs claim "Full transparent support for mutually recursive modules"
(`jhc/docs/jhc.mkd:67`). jhc's own library depends on it, with SCCs of 10, 5 and 3 modules and no boot file
(`results/E15/run/module-sccs.txt`). The 10 hold `Numeric`, `Data.Ratio`, `Prelude.Text`, `Prelude.IO`, `Prelude.Float`
and others. `Prelude` itself is in none, since `jhc/lib/jhc/jhc.yaml:3` sets `NoImplicitPrelude`.

**Programatica.** `computeInsOuts` iterates from empty exports to a least fixed point (`lfpAfter`,
`programatica/src/programatica/tools/base/Modules/Modules.lhs:364`), and the text says that "the compilation unit of a
compiler is not a single module, but a _strongly connected component_" (`:348`). That file is the literate source of
Diatchki et al. 2002. `tcModuleGroup` then type-checks the group "by joining them into one module"
(`programatica/src/programatica/tools/base/TI/TiModule.hs:62`): `joinModules` concatenates the declarations (`:81`)
under the representative name, and `splitModule` puts results back by file. The join is safe because scoping has already
made names unique (`programatica/src/programatica/tools/base/TI/TiDs.hs:64`).

**The hole in both: `default`.** The Report's `default` is per module, and so is the end of Rule 2.
- Programatica collects every `default` of the group and solves each ambiguity under all of them, failing with
  "Conflicting default declarations" if they differ (`programatica/src/programatica/tools/base/TI/TiDefault.hs:48`,
  `:63`). A module with none takes the group's, not `Integer` and `Double`
  (`programatica/src/programatica/tools/base/TI/TiModule.hs:34`). So two members of a cycle with different `default`s
  are rejected, where the Report gives each its own.
- jhc parses `default` and never uses it, cycle or not (`jhc/src/FrontEnd/Tc/Class.hs:230`).
- No implementation gives each module its own. Tracking the modules an ambiguous variable's constraints arose in would
  [inferred], with a tie-break where one variable has constraints from two modules whose `default`s differ. rhc's rule
  is its own (D30, R20).

**GHC's boot files.** Every cycle must be broken by a hand-written `.hs-boot`, compiled to `.hi-boot` and checked
against the real module (`ghc/compiler/GHC/Tc/Module.hs:850`). GHC's notes give the cost. The policy of never touching a
forward-declared entity early "has proven to be a bug farm" (`ghc/compiler/GHC/IfaceToCore.hs:2098`, Note [Knot-tying
fallback on boot]). Every module on the path between a boot file and its real module must be rebuilt in memory to get a
truly cyclic structure (`ghc/compiler/GHC/Driver/Make.hs:1648`, Note [Rehydrating Modules]).

**Boot files cannot express every legal cycle.** A forum post of 2026-06-25
(`https://discourse.haskell.org/t/there-are-mutually-recursive-programs-that-ghc-cant-compile/14316`) gives three
modules, each defining a type and a signed function over all three. Tested on GHC 9.4.7 (`results/E15/run/boot3/`,
output in `results/E15/run/boot3.txt`):

| Attempt | Result |
|---|---|
| v0: no boot files | refused: "Module graph contains a cycle" |
| v1: boots for all three, importing each other's types by `SOURCE` | refused: "Unexpected non-cycle", which is GHC's internal message rather than a language rule |
| v3: the same declarations in one module | compiles |

That no arrangement exists is an argument, not a test [inferred]: whichever module compiles first needs the boots of the
other two for their signatures; each signature mentions the other's type; so those two boots import each other, and the
user's guide forbids a cycle among them (`ghc/docs/users_guide/separate_compilation.rst:821`). One arrangement with
boots was tried; the rest of the argument is by hand. Every value here has a signature, so 5.7's "Explicit type signatures for all exported values" is met: the failure
is GHC's mechanism, not the Report's permission. So D30's "extra information" has two forms, boot files and signatures
in the module, which must not be conflated.

**nhc98's hack.** nhc98 keeps the Report's module names but has no boot mechanism: a cycle is broken by hand-writing a
minimal `.hi`, found with `-P`, then compiling round (`nhc98/docs/interface.html:20`). For the libraries each definition
is its own file, compiled as a part (`--part`), and the build order is written by hand (`nhc98/src/prelude/Makefile:18`,
`nhc98/src/prelude/Makefile.common:20`). `Char`, `Ratio` and `Numeric` go first, against a `Prelude.hi` already in
`include/` [inferred], and a rule is marked "hack to get round mutual recursion between libraries"
(`nhc98/src/prelude/Makefile.common:87`).

**Hugs's refusal.** Import chasing marks a script postponed, and meeting one again raises "Recursive import dependency"
(`Hugs/src/script.c:249`). The stated cause is that `depVar` cannot resolve references to unprocessed objects
(`Hugs/src/static.c:6628`). Its guide: although "the Haskell 98 specification of the `Prelude` and library modules is
recursive", Hugs puts "most of these definitions in a module `Hugs.Prelude`"
(`Hugs/docs/users_guide/haskell98.xml:222-227`). Hugs's older manual says the same of the Report's text, "are mutually
recursive", and "This mutual recursion has been avoided by moving the following functions into the Prelude"
(`https://www.haskell.org/hugs/pages/hugsman/diffs.html`, read through a fetch): `Ix`, the `Char` predicates and
conversions, and `Ratio`.

**Has anyone compiled the Report's libraries in the Report's own layout? Type-checked, yes. Compiled to running code,
none that E15 could find.** That is a statement about the trees and pages read, not a proof of absence.

Programatica ships `tools/base/tests/HaskellLibraries`, the Report's 20 modules plus `PreludeBuiltin`, with the Report's
import graph: one SCC of 12, the Report's 11 and `PreludeBuiltin`, no boot files (`results/E15/run/module-sccs.txt`).
Its README calls them "Haskell 98 Prelude and Standard Libraries, with some minor changes to make them go through our
type checker" (`HaRe-0.6/tools/base/README.html:80`). `pfesetup` takes them by default
(`HaRe-0.6/tools/pfe/pfesetup:61`), so every Programatica project was checked against that SCC. The local `programatica`
tree lacks these files; they come from the HaRe 0.6 tar. E15 did not run it. By line, 1,201 of 1,511 Report code lines
in the 11 SCC modules are unchanged (`results/E15/run/report-diff.txt`). E16 classified the 111 diff hunks: **no change
adds a signature or moves a definition to get the cycle through a checker** (`results/E16/programatica/`). Unsigned
top-level values rise from 7 to 40, so their copy relies on the join; the one cross-module move is `type Rational` into
`Prelude`, for how literals are typed. Their `default()` in `Numeric` switches defaulting off for all 12 modules,
leaving exactly one annotation, in `floatToDigits`, the same site GHC needed in E16. Programatica has no back end, so
none of this was executed.

| Implementation | The Report's layout? | Source |
|---|---|---|
| nhc98 | The closest compiler: the Report's names, but per-definition parts against an existing `Prelude.hi` [inferred] | above |
| Hugs | No, and says why | above |
| GHC | No: layered internal modules with `SOURCE` edges; 24 boot files in `ghc-internal` | `results/recursion/CORRECTION.md` |
| Yhc | No: `Data._CharNumeric` breaks `Char` against `Numeric` | `results/recursion/CORRECTION.md` |
| jhc | No: its own layered modules with its own SCCs. It alone among compilers has the mechanism | `results/E15/run/module-sccs.txt` |
| UHC, MicroHs, Helium | No; MicroHs has 9 boot files | `results/E15/implementations.md`, row M5 |
| hbc | Not Haskell 98: the tree is Haskell 1.4 | `hbc/src/doc/hbc-diffs.html:9` |

So the literal layout passed a front end about twenty years ago and has no execution record. Nothing here says a
compiled SCC of 12 is cheap: jhc's largest is 10, and neither has published a cost. Under D36 rhc is the first to find
out, and the derived merged form is the fallback.

**Recursive modules have no oracle.** No candidate in E8's corpus has a plain import cycle; 7 have `SOURCE` imports, all
GHC-style. On the `.hs-boot` retest Hugs refuses a recursive import, nhc98 accepts none, and GHC accepts only `rn017`
(`results/E8/judged.tsv`). So D30's tests are written by hand from the Report.

### Interfaces and the Prelude (D44, D45, D36)

**What an interface holds (D44).** GHC's `.hi`: exports, fixities, declarations with `IdInfo`, defaults, instances,
rules, dependencies, fingerprints (`ghc/compiler/GHC/Unit/Module/ModIface.hs:326`). nhc98's is text, the closure of what
exports mention, with no unfoldings or versions (`nhc98/src/compiler98/Export.hs:193`). hbc's is text in Haskell-like
syntax, with `ARITY`, `STRICTNESS`, `SPECIALIZE` pragmas (`hbc/src/ExprE/hprexport.m:65`). UHC's binary `.hi` holds
gammas, a CHR store and a Grin inline map (`uhc/EHC/src/ehc/HI.chs:107`). jhc's `.ho` holds per group all `E` bodies and
no object code (`jhc/src/Ho/Type.hs:123`). Programatica's cache holds per-SCC types, kinds and instances
(`programatica/src/programatica/tools/pfe/PFE4.hs:261`). Hugs has none: every module is loaded from source each session
(`Hugs/src/script.c:196`). MicroHs has one optional cache of everything (`MicroHs/src/MicroHs/CompileCache.hs:26`).

**Cross-module inlining (D44).** GHC with `-O` carries unfoldings, arity, demand and CPR signatures, CAF info
(`ghc/compiler/GHC/Iface/Syntax.hs:456`), and `-O0` omits them. hbc carries arity, strictness, specialisations, no
unfoldings in practice (`hbc/src/misc/flags.m:150`). nhc98 and Yhc carry arity only
(`nhc98/src/compiler98/Export.hs:409`). UHC carries `LamInfo` and small Grin bodies (`uhc/EHC/src/ehc/HI.chs:130`). jhc
stores every body and optimises at link (`jhc/src/Ho/Type.hs:138`, `jhc/src/Main.hs:110`). Hugs and MicroHs: none, even
within a module (`Hugs/src/compiler.c:125`, `MicroHs/src/MicroHs/Compile.hs:269`). D44's Prelude unfoldings first follow
E6, and only GHC and jhc carry Core bodies at all.

**Instance visibility (D44).** Global or transitive, in practice everywhere the Report's 5.4 allows: nhc98 and Yhc
through `.hi` (`nhc98/src/compiler98/Export.hs:40`), Hugs in one list per class (`Hugs/src/subst.c:1391`), MicroHs by
session [inferred] (`MicroHs/src/MicroHs/TypeCheck.hs:63`), jhc over the dependency closure [inferred]
(`jhc/src/Ho/Build.hs:571`), Programatica by transitive imports (`programatica/src/programatica/tools/pfe/PFE4.hs:160`).
GHC tracks orphans so it need not load them (`ghc/compiler/GHC/Core/InstEnv.hs:491`,
`ghc/compiler/GHC/Unit/Module/Deps.hs:99`), and UHC likewise [inferred] (`uhc/EHC/src/ehc/EH/Orphan.cag:2`). hbc
documents a deviation (`hbc/src/doc/decls.html:138`).

**The Prelude (D36, D45).** An ordinary module with an implicit import and wired names in every system. GHC: `Prelude`
re-exports `ghc-internal`, with wired-in or known-key names (`ghc/libraries/base/src/Prelude.hs:2`,
`ghc/compiler/GHC/Builtin/Utils.hs:97`). Hugs: `Hugs.Prelude`, 2,020 lines, 75 primitive declarations, loaded first
(`Hugs/src/evaluator.c:198`). nhc98: many small files, each `module Prelude`, primitive types in a hand-written
`PreludeBuiltin.hi` (`nhc98/src/compiler98/PreImport.hs:207`, `nhc98/include/PreludeBuiltin.hi:48`). Yhc: one file of
2,611 lines (`yhc/src/packages/yhc-base-1.0/Prelude.hs:143`). MicroHs: `Prelude` plus a qualified `Mhs.Builtin` for
compiler-generated names, disabled together by an exact `import qualified Prelude()`
(`MicroHs/src/MicroHs/Compile.hs:289`). Helium: over Core libraries
(`helium/src/Helium/ModuleSystem/GatherImports.hs:74`). E9's copy comparison: of 742 definitions, 268 are the same in
all five copies and 135 in none. No copy is the Report.

### What is Haskell 98 itself (D38, D52)

The claims are in the table above. Three documents list deviations, and each is a list D38 can test:

- **GHC** (`ghc/docs/users_guide/bugs.rst:24`): nine lexical rules, do-layout (`:127`), fixity parsing (`:162`),
  eta-based definedness, `MonadFail`, refined binding groups, `-main-is`, hs-boot, the class hierarchy (`:357`), array,
  Prelude functions. "mostly" is its own word, and the default edition is GHC2021
  (`ghc/compiler/GHC/Driver/Flags.hs:69`). `-XHaskell98` is an oracle only through E7's strict shim, and E10 adds that
  9.4.7 is no oracle for the spacing of `@`, `~`, `!`.
- **Hugs** (`Hugs/docs/users_guide/haskell98.xml:12`): sixteen, among them Latin-1 identifiers, let/lambda fixity, left
  sections, polymorphic recursion, class constraints, the top-level restriction, `(:)`, rational literals and float
  show. E7 confirms by running: `import Prelude ()` loses `:`, floats print in 7 and 15 digits, and the top-level
  restriction resolves early.
- **nhc98** (`nhc98/docs/98.html:23`, dated 2001): library gaps, the simple context restriction kept, no
  `funlhs -> (funlhs) {apat}`, no restriction, no over-8-bit file I/O. `nhc98/docs/bugs.html:70` adds kinds. E7 and E10:
  it refuses `Eq (m a)` in a context, and record `Show` spacing differs from every other oracle.
- **Others.** Yhc has no list, and reading finds no restriction, no `Bounded Char`, no pattern guards. Helium lists its
  own (`helium/DIFFERENCESWITHHASKELL98.md:1`). jhc: `jhc/docs/differences.mkd:7`, stale on `Ix`. UHC's list is in
  documents outside this tree [inferred] (`uhc/EHC/changelog.md:30`). MicroHs's is on its wiki, and leaves out having no
  top-level restriction [inferred]. Programatica has none in the tree
  (`programatica/src/programatica/tools/base/TI/TiDs.hs:228` notes one).

### What was run (D12, D18, D52)

All three oracles run. E7 built them: Hugs unmodified; nhc98 v1.22 from its `.hc` files, 32-bit, under gcc 13, only with
`-m32`, `-O1`, no PIE, `-fno-strict-aliasing` and `-fcommon` (`results/E7/nhc98-flags.txt`); GHC 9.4.7 with the strict
shim. MicroHs is a smoke oracle: no Haskell 98 mode, no n+k patterns, no datatype contexts. E7's 82 tests give 48
disagreements, 20 of them hard; that is for *Testing*. The E15 probes ran each program with a 20 s timeout and a 6 GB
limit (`results/E15/run/probes.tsv`, `results/E15/run/probes2.txt`). Everything else in this section is reading.

| Program | GHC 9.4.7 `-O0` | Hugs | nhc98 | MicroHs |
|---|---|---|---|---|
| `let x = x` | timeout | timeout | compiler dies: "Black hole detected." | timeout |
| `x = x + 1`, local and top level | `<<loop>>` | control stack overflow | "Black hole detected." | stack overflow |
| `foldr` and `foldl`, n = 10^4 | ok | ok | ok | ok |
| `foldr`, n = 10^5 | ok | control stack overflow | ok, 32-bit wrap | stack overflow |
| `foldl`, n = 10^5 | ok | control stack overflow | ok, 32-bit wrap | stack overflow |
| `foldr`, n = 10^6 | ok | control stack overflow | ok, wrap | stack overflow |
| `foldl`, n = 10^6 | ok | **SIGSEGV** | ok, wrap | stack overflow |
| `foldr`, n = 10^7 | ok | control stack overflow | timeout | stack overflow |
| `foldl`, n = 10^7 | ok | **SIGSEGV** | timeout | stack overflow |
| a raising thunk forced twice | raised twice, effect once | same | no `Control.Exception` | same |

- **Only the growable stack passed everything.** Fixed stacks fail at 10^5, and Hugs crashes at 10^6.
- **GHC does not detect `let x = x` in 20 s,** a loop that allocates nothing reaching no collection [inferred]. Three of
  the four spin. nhc98's own compiler hits a black hole compiling it.
- **`self-arith` stops on all four by four routes.** Under Report 3.1 all are bottom, so D52's probes must take them as
  one.
- **The exception probe decides nothing.** It does not separate memoising from resuming after the effect, in either form
  (`exc-twice`, `exc-direct`), and it uses extensions: the plain GHC with `base`, not the shim.
- `results/E15/run/probes.tsv` keeps only Hugs's first error line, `Error occurred`. The text "Control stack overflow"
  is in `results/E15/run/probes2.txt` for `self-arith` and `foldr` at 10^5, and was seen again for this section by
  running `foldl` at 10^5 and `foldr` at 10^6 and 10^7.

### The survey, checked

`docs/plans/language/haskell98-compatibility.md` is another agent's survey. E15 checked the 43 claims a decision could
rest on (`results/E15/impl/*.survey`): **38 right, 1 wrong, 3 stale, 1 unverifiable.**

- **Wrong:** "HSE's documented default mode already uses Haskell 98 with no additional extensions". `defaultParseMode`
  has `baseLanguage = Haskell2010` (`haskell-src-exts/src/Language/Haskell/Exts/ParseMonad.hs:173`). An oracle harness
  must set the mode. Haskell98 mode adds only `NPlusKPatterns` to the common defaults
  (`haskell-src-exts/src/Language/Haskell/Exts/Extension.hs:730`).
- **Stale:**
  - MicroHs record updates cannot change polymorphic fields' types: since commit 690019d3, `needDsCase` routes such
    updates through a rebuilding case, by reading (`MicroHs/src/MicroHs/TypeCheck.hs:2223`).
  - Helium lacks user classes: true of 1.8.1 on Hackage; this tree is 1.9 (`helium/RELEASENOTES.txt:13`).
  - jhc ignores datatype contexts: its docs say so (`jhc/docs/differences.mkd:7`), but `qualConType` keeps them in the
    constructor's sigma, so they are dropped only by `E`; by reading (`jhc/src/FrontEnd/DataConsAssump.hs:89`).
- **Unverifiable:** Yhc's "almost all Haskell 98 programs". The phrase is in neither tree nor wiki; the nearest
  statement is "not useable as a standard Haskell compiler yet" (`yhc/web/index.html:36`). It should go.

Right, with something to add:
- **Hugs "nearly complete" with `+98`:** the phrase is not in the tree, and `+98` is the default rather than an opt-in
  (`Hugs/src/opts.c:32`).
- **Hugs's defaulting:** the guide files it under the monomorphism restriction
  (`Hugs/docs/users_guide/haskell98.xml:141-171`); E7 shows it rejecting corpus programs.
- **nhc98 "designed specifically for Haskell 98":** it began as nhc12 for a subset of Haskell 1.2
  (`nhc98/docs/implementation-notes/intro:8-17`).
- **nhc98's `-98`:** it also turns puns off, and n+k is already on without it (`nhc98/script/nhc98.inst:184`,
  `nhc98/src/compiler98/Flags.hs:251`).
- **nhc98 "requires a 32-bit environment":** true (`nhc98/docs/install.html:28`), and E7 shows how narrowly it builds.
- **Yhc "its author declared the project dead":** Neil Mitchell's post of 3 April 2011; he is a lead developer, one of
  three (`yhc/web/index.html:37`).
- **UHC:** "most of Haskell2010" is the authors' word where the survey has "much" (`uhc/EHC/hcar/20151116-UHC.tex:19`).
- **GHC's `-XHaskell98` extension list:** the guide lists eleven, and the code twelve
  (`ghc/compiler/GHC/Driver/DynFlags.hs:1310`).

**What the survey omits.** The Hugs guide's other deviations (`results/E15/impl/hugs.survey`, 6.1-6.16), which matter to
D52: limited lookahead for `Just.if` (`Hugs/src/input.c:757`), restricted left sections (`Hugs/src/parser.y:839`),
relaxed polymorphic recursion (`Hugs/src/type.c:2074`), relaxed class constraints (`Hugs/src/static.c:1367`), an
implicit module header (`Hugs/src/parser.y:134`), and `(:)` exported from the Prelude
(`Hugs/packages/base/Prelude.hs:46`). One entry is stale in the guide: `0xy` and `0oy` now lex as the Report says
(`Hugs/src/input.c:692`), by reading. The owner's question is settled by the same check: Hugs is C, with no Haskell in
`src` (160 C-family files).

## The IRs, reviewed

The brief asks for a review of the intermediate representations: the split between them, and the constructs available or
not available in each. This is that review. Paths are as in *Where we are*.

**The split is right.** Nothing in Mid or Low should go, and Lambda should stay, private to SML. What the review found is
smaller than a redesign:
- Lambda has two jump mechanisms, one of which can go (D7).
- Mid has no walker of its own, so every pass writes its own, and most of those over `rhs` take a new constructor without
  a word (D10).
- Mid has no `Case`, which costs compile time and clarity and does not cost code (D8).
- Mid has no multi-value return, and four mechanisms attack the same tuples. It should stay that way for now (D9).
- `Lambda.const` is in the wrong place, and function names are in a table: both moved in E11's prototype with no byte changed
  (D40).

rhc needs none of the above. Its demands on Mid are D3 to D6, and as recommended they add no constructor.

**The evidence is E12.** Every constructor of every representation, with what makes it, what reads it and what lint rule
holds it: 202 rows, of which 3 are proposals (`results/E12/census.tsv`). The verdicts in that file are by hand. The workload is
one program, the compiler compiling itself at `-O1`: large, symbolic, heavy on datatypes and light on numerics. Files below are
in `results/E12/` unless they say otherwise. Instructions and bytes are `runevm --count`.

### The verdicts

| Representation | Constructors | Keep | Move | Drop | Add |
|---|---:|---:|---:|---:|---|
| Lambda | 39 | 30 | 7 (`const`) | 2 (`Try`, `Fail`) | |
| Mid | 31 | 31 | | | a function's label (E11-5); `Case` for a later roadmap (D8) |
| Low | 47 | 47 | | | |
| Stack bytecode | 41 | 40 | | 1 (`HALT`) | |
| Register bytecode | 41 | 40 | | 1 (`HALT`) | |

Multi-value return is the third proposal in the census, and its verdict is not to add it (D9).

`HALT` has no emitter, and only hand-written assembly names it (*Where we are*). Dropping it moves the fingerprint, so it is not a tidy.
rhc does not need it gone, and no decision here takes it.

The census also says what the verdicts hide, none of which changes one:
- `Lambda.Inst` says more than is legal: `ToMid` refuses anything but `Inst` of a variable or a global
  (`core/tomid.sml:172-174`).
- `Lambda.Prim`'s optional type exists for three primitives, which `ToMid` must work out again (`core/tomid.sml:260-269`).
- `Mid.Prim` carries six primitives of the compiler's own that `Lower` alone translates (`backend/lower.sml:987-992`).
- `Low.Slot` exists for results in globals alone.
- Three instructions are nearly unused in the compiler's own code, statically: `JUMPIF` not at all, though `Regs` and `Stack`
  can emit it; `PRIMPUSH` twice, for images, by design; `CONTAG` three times, since `Lower` folds nearly every tag test into a
  branch (`isa.tsv`).

### What each is for, and whether the split is right

**Lambda** is SML after elaboration: a typed tree, where a program can still be written by composition. Its types are in side
tables and `Rest` marks the top level. No optional pass runs on it, and one thing reads it. `translate` makes 435,763 nodes
and `mid` 208,346 (`dumps/rune.O1.stats`).

**Mid** is where the program is the program: A-normal form, join points, System F, the top level a list of definitions. Every
optional pass runs here. The unit cache keeps it, and a client can read and write it as text.

**Low** is what both targets are made from: blocks in SSA, with closures, handlers, layouts and representations explicit. No
optimisation runs on it and none has been wanted. What it buys is that two targets share one lowering, and that three checks
(LowLint, LowShapes, RegVerify) have something below Mid's types to hold.

**The two bytecodes** are 37 instructions under the same name and 4 of each set's own. E12 gave verdicts instruction by
instruction and did not ask whether two sets should be one. rhc does not raise the question: a thunk needs no new instruction
(D13), and the stack target's parity is D14.

**Mid against Low: right.** Mid cannot hold closure conversion and stay a language the passes reason in. Low cannot hold types
and stay small.

**Lambda against Mid: Lambda could go, and it should stay (D7).** Removing it means `Translate` and `MatchComp` build Mid through
a builder, which is `ToMid`'s `atomize`, `deliver` and `branch` turned into a library (`core/tomid.sml:108`, `:130`, `:145`).
- That saves `core/lambda.sml`, 268 lines, `core/lambdalint.sml`, 255, and the walk of `ToMid`.
- It costs the last place where a program is a tree: 224 occurrences of Lambda's constructors in `Translate` and 115 in
  `MatchComp` would become continuations (`occurrences.tsv`).
- It costs a boundary lint at level 1, which catches a bug of `Translate` before Mid's A-normal form hides it.
- It buys Rune no speed that E12 can show: `translate` and `mid` took 0.60 s of about 5.0 s outside the dumps, on a machine whose
  load was not recorded (`dumps/rune.O1.stats`), and most of `mid`'s work would stay, as the builder's.

**Lambda is private to SML, and should be said to be.** With `const` moved and the label on the function, nothing below
`ToMid` needs Lambda but `Fault.lambda` (`backend/fault.sml:67`), which injects faults for the tests. No front end enters there
(D7, D1). What rhc wants of Lambda is `ToMid`'s builder, which is worth lifting out when M10's Core to Mid is written, and not
before.

### What is duplicated

**Walkers.** There is no `Mid.fold`. A walker here is a run of patterns naming at least six of `exp`'s nine constructors, seven
of `rhs`'s fourteen, three of `atom`'s five or of `def`'s three (`walkers.py`). A walker spread over more lines than the rule
allows is missed, so these are lower bounds:

| Sort | Walkers | Lines |
|---|---:|---:|
| `exp` | 88 | 745 |
| `rhs` | 38 | 479 |
| `def` | 36 | 136 |
| `atom` | 15 | 91 |

By shape, a heuristic reading of each (`walker-shapes.tsv`):

| Sort | Shape | Walkers | What replaces it |
|---|---|---:|---|
| `rhs` | lists its atoms | 12 | `Mid.atomsOfRhs` |
| `rhs` | all atoms hold, or a loop over them | 13 | `atomsOfRhs` with `List.all` or `List.app` |
| `rhs` | rebuilds with atoms mapped | 12 | `Mid.mapRhs` |
| `rhs` | its own | 1 | |
| `exp` | rebuilds, subexpressions mapped | 24 | `Mid.mapExp`, where no arm differs |
| `exp` | walks for an effect, folds or asks | 64 | a `Mid.fold`, where no arm differs |

The 12, 13 and 12 are firm enough to plan with. The split of `exp` is not.

Some are the same function. `Lift.atomsOfRhs` and `Refs.atomsOf` differ in their names (`core/lift.sml:31`, `core/refs.sml:27`).
`onlySelected` in `Workers` and in `Simplify` differ in how they say one case (`core/workers.sml:32`, `core/simplify.sml:1783`).
The two `free`s differ, and for a reason worth noting: Lower's must see through `tagTest` and `switchOf`, so that a closure does
not capture what a `Switch` leaves out (`core/lift.sml:64`, `backend/lower.sml:212-215`, `:247-251`). That is a cost of having no
`Case`.

The cost is not the lines. A new step of Mid means at least 38 walkers, and **28 of those 38, and 43 of the 88 over `exp`, end in a
catch-all** (`walker-defaults.tsv`; run again on the reference tree, same counts). A new constructor falls into `| _ =>` without a
word: as having no atoms (`core/lift.sml:45`, `core/refs.sml:41`), as using nothing (`core/simplify.sml:73`), as removable
(`core/simplify.sml:115`).

A `Force` constructor would hit exactly that, and it is one reason D3 recommends a primitive. `Prim` has an arm in every walker,
and `removable` asks the primitive's description (`core/simplify.sml:113`), which a force must therefore state truly. So D10 is
for Rune alone: rhc does not wait on it. If the owner took D3's medium option, a `Force` right-hand side, D10 would have to
come first.

**D10: `Mid.atomsOfRhs` and `Mid.mapRhs` first.** Small, with bytes held by construction (deduced, not prototyped). A `fold` over
`exp` is a second step, and only where a walker's arms are all the default.

**Two jump mechanisms in Lambda.** `Try`/`Fail` is `Join`/`Jump` with no parameters, as `ToMid` has always made it
(`core/tomid.sml:236-243`). `MatchComp`'s rule-by-rule compiler can make `Join (j, [], rest, rule)` instead: E11-10 is 22 lines
added and 6 removed, and no byte of the compiler moves at any level on either target, observed (`results/E11/verify-summary.txt`,
`results/E11/sizes.tsv`). Four expected dumps of Lambda in `tests/ir` change, `(try` to `(join`, as they must
(`results/E11/ir-try-diff.txt`). `LambdaLint` loses a rule and a `tail` flag, and `ToMid` its `fail` state. The constructors
themselves are still in E11's datatype, unused (D7).

**Four attacks on tuples.** Each turned off, and the compiler so built run on itself; every such compiler still compiled the
compiler to the same bytes (`passes.tsv`; for virtuals and `flattenJoin`, `results/E11/variants.tsv`, against its own control):

| Attack | What it does | Off: instructions | Off: bytes allocated | In the source |
|---|---|---:|---:|---|
| Virtual tuples and fields (`Lower.virtualised`, `backend/lower.sml:1097`) | a tuple, or a flat constructor's argument, not made | +31.85% | +232.6% | part of `Lower` |
| Workers (`core/workers.sml`) | flattens parameters | +24.7% | +154.6% | 492 lines |
| Results in globals (`Lower`, `Slot`) | a returned tuple not made | -0.76% | +4.4% | 468 lines of analysis (E11-7), `Lower`'s use of it, a level-0 lint |
| `flattenJoin` (`core/simplify.sml:1686-1780`) | a join point's tuple parameter | +0.0006% | +0.17% | 95 lines |

Only one of the four is about returns, and the table is one program. On the catalogue's numerical benchmarks that need no files
(`bench-summary.tsv`, recomputed from `bench-attacks.tsv`; normal profile) the two small ones are not small everywhere:

| Off | Allocation rises most on | Instructions | Allocation unchanged on |
|---|---|---|---|
| Results in globals | `nucleic-smlnj` +45.09%, `mandelbrot-rat` +20.29%, `nbody` +4.92% | from -1.70% to +0.56% | `fft-sandmark`, `nucleic2-lazy`, `nucleic2-shared-lazy` |
| `flattenJoin` | `fft-smlnj` +241.24% (of 40,520 bytes), `mandelbrot-rat` +9.26% | from -1.81% to +0.72% | `nbody`, `nucleic-smlnj`, `nucleic2-lazy`, `nucleic2-shared-lazy`, `tensor` |

These are rises with the attack off: +45.09% on `nucleic-smlnj` means the attack saves 31% of what that program would allocate
without it. 17 of the catalogue's 22 ran. `nucleic2-shared-strict` timed out under load, and `nucleic2-strict`, `tsp` and both
`x2n1` were not run. In instructions the two are about nothing either way, and in allocation they differ by program. Allocation is
what they were built for, so neither is a candidate to drop.

### What is missing

**Mid has no `Case`.** Lower rebuilds a match from `ConTag`, an equality primitive and `If` (`backend/lower.sml:160-209`). What
that costs, in the compiler, over the Mid given to Lower (`mid-stats.rune.O1.tsv`, by `analyze_mid.py`; Low's counts by parsing
`dumps/rune.O1.low`):

- **Decision points.** 12,064 tag tests, 58.4% of the 20,662 `If`s, and 262 more by `ptr_eq` with a nullary constructor. Each is
  three nodes where `Case` would be one: 24,128 `Let`s, 11.7% of Mid's 206,427 nodes.
- **Recovery works.** Low has 8,775 `IfTag` and 472 `Switch` of 3,286 arms, which is 12,061 of the 12,064, and 3 `tag` operations
  left: all of them accounted for. Of 484 chains of three tests or more, 472 became a `Switch`. Why the other 12 did not was not
  checked; `switchOf`'s bound on the table is the likely reason (`backend/lower.sml:208`). One chain in the program is broken by a
  binding between its tests.
- **Nothing is lost to it.** 31 of the 12,064 tests, 0.26%, are answered by a test that dominates them: 19 known equal, 12 known
  different. Decision trees leave almost nothing for a `Case` of known constructor to find.
- **Peepholes that exist only to recover it:** `tagTest` and `switchOf` (`backend/lower.sml:160-209`, 50 lines), their uses in `free`
  (`:247-251`, 5) and `exp` (`:1123-1146`, 24), and LowShapes' own `tagTest` (`backend/lowshapes.sml:490-506`, 17). 96 lines, in
  three places that must agree.
- **`Decon`'s guard is a convention.** 10,285 of 11,196 `Decon`s sit under a test or an exclusion of their variable. MidLint
  cannot say so; LowShapes checks it after Lower.

What `Case` would do for SML: 11.7% fewer Mid nodes, or 16.7% if arms bind what `Decon` takes (deduced: 10,285 more), which is
compile time and unit size; 96 lines of peephole gone; a guard MidLint can state; `free` shared with `Lift`. What it would not do is
make SML run faster: nothing shows it would change code. It costs an arm in at least 88 walkers, and in `MidText`, `MidCodec`,
`UnitMid`, `MidCanon` and `Fault`, and a change to Simplify's rounds, which is where the risk is.

**D8: none in this roadmap. `Case` stays recorded as medium, for clarity and compile time rather than code, for a later roadmap after D10.** rhc's match compilation is its own, in Core
(D34), and reaches Mid as the same tests (deduced; E1's hand-written Mid is that). Do the walkers first, and `Case` becomes a small
change. Until then a single `Mid.tagTest` view shared by Lower and LowShapes is the cheap half of it. No bytes should move if Lower
lowers it as it does now (deduced).

**Mid has no multi-value return.** A real one would be `Return` of several atoms, a `Let` of several variables, `Low.Return` of a
list, and `RET` and `RESULT` of several in both instruction sets. In a whole compile it wins what results in globals wins already.
What it adds is that gain in a build in units, where results in globals does not run (`backend/lower.sml:849`): by the whole-program
figures above (deduced), 4.4% of the compiler's allocation and up to the benchmarks' rises, and in instructions nothing. It would
retire `Slot`, the facts in `Pipeline.lowered` and `LowLint.results`. It is a change to 126 walkers and to two instruction sets.

**D9: none now, on Rune's account.** It is a real gain, in one mode, at the largest price on this list. After the walkers it is worth
asking again. If rhc wants unboxed returns that is rhc's case to make, with its own measurements, and it may not ride on this review.

**What Haskell finds missing.** E12's census asks what SML needs of each construct. Four things Haskell wants are absent, and each
has its decision:
- a position that may be unevaluated: `susp`, an abstract tycon, and force as one primitive node (D3);
- a type headed by a variable, and a forall: `Ty.view` has neither (`core/ty.sml:27-33`), and D4 chooses between `Any` and
  extending `Ty`;
- a recursive value, and code with no parameter: cell-patched recursion and thunks in globals, with no change to Mid (D6);
- a rule that a variable of datatype type is evaluated: a lint where one can reach (D5).

As recommended, none of these adds a constructor to Mid, Low or either bytecode. E2's prototype adds one function to
`backend/low.sml`, `hoistEnv`, over the existing operations, and primitives (`patches/E2-all-forms.patch`).

### What is in the wrong place

**`Lambda.const` in Mid and Low.** `Mid.Const` and `Low.Const` hold it (`core/mid.sml:41`, `backend/low.sml:42`), and so does the
code of each target. E11-9 moves it to `Literal`, with `datatype const = datatype Literal.const` in Lambda so that `Translate` is
untouched. Bytes held, observed (`results/E11/verify-summary.txt`; D40).

**Function names in a table keyed by first parameter.** A `fundef`'s name is a stamp, and `Translate.funNames` holds the text, read by
every pass that wants it (*How a pass runs*). E11-5 puts a `label` on the function: 17 files, +158 -193, bytes held, observed
(`results/E11/sizes.tsv`, `results/E11/verify-summary.txt`; D40).

**The elaborator making code.** `Elaborate.functorCode` and `callCode` are a representation decision inside the type checker: what a
structure's record holds, in what order, and what is in reach (`docs/ir.md:431`, `:440`). 43 lines of `elab/elaborate.sml` name
`Record`, `DescVar`, `DescLayout`, `slotsOf`, `inReach`, `openCon`, `functorCode` or `callCode`, and `Translate` names `Elaborate` on
26 lines (grep). It is there because an application's bindings get their stamps as it is elaborated. Moving it means the
elaborator hands `Translate` a neutral record of what it bound. That is worthwhile, it is not small, and it is the one thing here that
v2's M4 touches in the same file, in another function (`elab/elaborate.sml:2231`). rhc does not need it, since its elaborator is its
own. **Leave it, and name it as debt.**

**`Lower` does five jobs:** closure conversion, layouts, known calls and loops, recovering `Switch`, results in globals. E11-7 moved
the analysis half of the last out, 468 lines, with bytes held, observed (`patches/E11-7-results.patch`, `results/E11/verify-summary.txt`).
The lowering half cannot move, because `Slot` is Low (D39).

**`Types` is in `elab/`.** It is 440 lines that depend on `Source`, `Error` and `Pass`, and E11's Mid-only client links no other file of
that directory (`results/E11/contract.md`; D40).

**Stale words,** which mislead a new reader and cost nothing to fix:
- `core/mid.sml:1`, "the optimisations will work on", and the same at `docs/ir.md:586`;
- `core/mid.sml:11-12`, "until then each takes one";
- `backend/low.sml:11-12`, "(M5) will make";
- `core/target.sml:25-26`, "no switch yet", and `switch = false` in both records (`core/target.sml:28`, `backend/regs.sml:25`), beside two
  targets that emit `SWITCH`.

### What each pass is worth

Left out alone, the compiler so built compiling itself (`passes.tsv`, from `passes.sh`; each such compiler still compiled the compiler
to the same bytes). `inline` and `specialise` run inside `simplify`, so leaving out `simplify` takes them too:

| Left out | Instructions | Bytes allocated | Size of the compiler |
|---|---:|---:|---:|
| `simplify` | +63.4% | +162.0% | -9.0% |
| `workers` | +24.7% | +154.6% | -2.4% |
| `inline` | +14.6% | +11.5% | -16.0% |
| `lift` | +13.6% | +61.7% | -3.0% |
| `trees` | +6.6% | +1.2% | +5.5% |
| `specialise` | +5.4% | +16.4% | -9.2% |
| `expand` | +4.8% | +18.5% | +0.2% |
| `results` | -0.76% | +4.4% | -0.01% |
| `refs` | 0 | 0 | +37 bytes |
| `shake` | -0.001% | +0.03% | +52.4% |
| all ten | +67.7% | +237.7% | -9.8% |

`refs` does nothing on this program: it is for a loop's local refs (`docs/ir.md:844-855`). The table is why the hook
is above these passes and not below them (D1): a front end entering at Low misses all of it. It is also a measure of strict code. What
these passes do for lazy code, through `Any`, closures and thunks, is what rhc will measure (D47 to D51).

### What this review does not establish

- The census, `Case` and the walkers are one workload, the compiler. Only two of the four attacks on tuples ran on anything else, on 17
  numerical benchmarks.
- The `Case` gains are static. No compile with a `Case` was made, so the time it would save is not measured.
- The walker tables are a heuristic over source text: a lower bound in count, and an estimate in shape.
- The instruction-set verdicts are static counts over the compiler's own bytecode. Dynamic frequency and the JIT's view were not looked
  at here; E2 bears on `CALL`, `RET` and any new instruction.
- Nothing here measures rhc's output, whose Mid will differ from SML's: more calls through closures, and tests of evaluation (deduced).

## The experiments

Sixteen experiments came before the writing, by ten agents. E15 is reading, and E9 is reading with tools. The rest ran.

**How they were gathered**
- **The tree.** Everything measures master `b12141ecc`. `.worktrees/hs-base` is the reference: built once and never modified, and every `path:line` here is against it. Each agent that changed Rune worked in a detached worktree of its own, copied from it: `hs-mid` (M), `hs-vm` (V), `hs-arch` (A), `hs-cache` (C). N's tree holds E2's and E1's patches and its own. Z's is a copy of V's.
- **The inputs,** never edited: the Report's text, the sources under `/home/ruud/haskell`, GHC 9.4.7, `examples/benchmarks`, the spec's programs on branch `runespec`.
- **The evidence.** Every number comes from a script kept with its raw output. `results/` is under the drafts directory, `~/.cache/claude-rune-drafts/haskell98/`. **Within an experiment a bare file name is in that experiment's directory,** so in E3 `compare.txt` is `results/E3/compare.txt`, and in E2 `tables/` is `results/E2/tables/`. `patches/` is beside `results/`.
- **The claims rest on instruction counts,** which do not vary with load: `instructions:u` from `perf stat`, which is machine instructions, and `runevm --count`, which is VM instructions, called bytecodes here. The two differ by a large factor and are named where they appear. A figure in M or G with no name is `instructions:u`. Eight runs of 11 files of E4 and E5 agreed to under 0.2%. One file did not: E4's `state` with casts kept at `-O2` gives 732M or 865M from the same bytes, unexplained (`results/E4/w9-repeat.out`).
- **Seconds and cycles are indications.** The machine is WSL2 with 16 CPUs and 31 GB, shared with other sessions.
- **The prototypes** were throwaway, kept as patches. None lands as it stands.
- **Marks.** [read] is from reading. [inferred] and [deduced] are reasoned and were not run. [estimate] is a judgement. Anything else ran.

**The two waves.** Wave 1 asked what is there today, each agent on its own: E1, E2, E3, E6 to E13, E15. Wave 2 read wave 1's reports and built on them: E4, E5, E14, E16.

**The flips.** The plan wrote what would flip each experiment before it ran, as a first guess to be challenged. Where it set none, the table says so.

| | What | By | Settles | What would have flipped it | Did it? |
|---|---|---|---|---|---|
| E1 | Mid as a target: hand-written Mid for knots, CAFs, dictionaries, polymorphic recursion | M | D1, D5, D6, D26 | A pass rejects it, tier 2 faults, or specialise diverges | No. Two local Simplify faults; specialise diverged only under a naive fix |
| E2 | Thunks on the real engines: six forms on 115 ports | V | D3, D11-D14, D18, D19 | The primitive form over 30% worse than instructions, a line with no source | No: G is 1.05 of C, and 1.22 at worst on E5's output. D13 does not rest on the line |
| E3 | Ticky on nofib at four optimiser levels | O | D15's shape; the size of D47-D51 | No threshold: the 5% had no source | Nothing to flip. The verdict depends on the tier |
| E4 | `Any`: casts counted, erased, checked, and through Simplify | N | D4, part of D5 | Casts block method inlining | Fired on a local dictionary, then dissolved: real dictionaries are global `Val`s |
| E5 | Rune's own ladder by hand-lowering: `Integer`, dictionaries, curried calls, K | N | D13, D15, D20, D49, D56 | None set | No decision flipped. `docs/plans/heap-layout.md:4999` proved a plan, not a fact |
| E6 | Cross-module information | O | D44, D45 | Little difference defers unfoldings | Split: a program's own can wait, the Prelude's cannot |
| E7 | Hugs, nhc98 and MicroHs built; `conformance98` on each | O | D52 | Only GHC runs | No: all run |
| E8 | The corpus, judged on oracles | O | D52, D56, what "clean" means | None set | The best corpus is nhc98's nofib, not the owner's tree |
| E9 | The Report, clause by clause | R | D38, D53, seeds of D32, D37 | None set | Its size did: 3,901 rows cannot be kept by hand |
| E10 | Lexer, layout and parser spike | F | D27, D28 | None set. An automaton, had the two parsers disagreed | No: they agree on 1,723 files and 46 crafted cases |
| E11 | Pipeline as data | A | D7, D39-D41 | Bytes move, or the diff collides with v2 | No |
| E12 | The IR census | A | D7-D10 | None set. A `Case` that saved code | No: it saves none |
| E13 | The store split, with a toy language | C | D43-D46 | Sections cannot stay opaque | No |
| E14 | Lazy ML on the same thunks | Z | D2, D57, part of D12, D14 | Needing more than `susp`, force and match compilation reopens a shared Core | No. But G as V left it failed 162 of 1,302 runs, on a body outliving its update, until the collector took a pin |
| E15 | Literature and implementations | I | Every decision's precedents | None set | No flip; it removed the 5% |
| E16 | The literal layout | F | D29, D36, part of D30 | Cross-module binding groups without signatures | No: there are none |

### E1. Mid as a target

**Question.** Can rhc hand Rune plain Mid? Mid is strict System F with no thunk, no higher kind and no way to say a recursive value. Does it carry knots, mutual CAFs, dictionaries and polymorphic recursion, and do its passes and engines stand up to code no SML front end writes? **Settles:** D1, D6, the limits of D5, what D26 may link against. It gave D4 its first figures and M7 its Simplify faults.

**How.** Agent M wrote Mid by hand, as an unoptimised rhc would emit it. On master `--read-mid` stops before bytecode (`src/driver/main.sml:216-218`), so `patches/E1-readmid.patch`, +14 -2, carries it on. The runtime is Mid text (`prog/rts.mid`). A `susp` there is a `ref` to `Delayed | Done | Hole`, cast, which is E2's form A: force of `Delayed` blackholes, runs under a handler that restores the code so that a raise stays re-forceable, then updates. Each program ran 45 ways (`run.sh`): `-O0`, `-O1`, `-O2` on both targets at `--lint=2 --mid-roundtrip`, on 12 register modes (interpreter, tier 1, tier 2, `--checked`, `--jit-stress`, `--deopt-stress=1` and `=7`, gc-stress with verify) and 3 stack modes. Output and exit status were compared with `prog/*.expected`, derived by hand.

**Result: the programs.** `matrix-base.txt` has the read-mid patch alone, `matrix-fixed.txt` every prototype.

| Program | What it holds | Read-mid patch | All prototypes |
|---|---|---:|---:|
| `knot` | `xs = 1 : map (+1) xs`, mutual `evens` and `odds`, a sharing count | 45/45 | 45/45 |
| `cafs` | mutual CAFs, a CAF on a later CAF's value, an unforced `error` CAF | 45/45 | 45/45 |
| `monad` | `Monad` over `any`, `sumM` and `labelM` at Maybe and lazy State | 45/45 | 45/45 |
| `classes` | a superclass, defaults, `Eq [a]` and `Ord [a]` dictionary functions | 45/45 | 45/45 |
| `nest` | strict and lazy `Nest`, a dictionary built per level | 45/45 | 45/45 |
| `nest2` | polymorphic recursion against Workers, Lift, Refs, results in globals | 45/45 | 45/45 |
| `letpoly` | a polymorphic CAF, `Let` schemes, a local polymorphic function | 45/45 | 45/45 |
| `exceptions` | `seq`, `error`, match failure, re-force after a raise, `<<loop>>`, `catch` | 45/45 | 45/45 |
| `nest_static` | polymorphic recursion with a static function argument | 15 ran; 4 compiles failed at `-O1`, `-O2` | 45/45 |
| `nest_eq` | `poly_eq` on `int nest` | 30 ran; 2 compiles failed at `-O2` | 45/45 |
| `nest_any` | the `nest_static` function typed at `any` | 45/45 (`out/nest_any/matrix.txt`) | not run |

On the first compiler with both polymorphic-recursion fixes, `sweep.sh` made 232 compiles with 0 bad (`out/sweep/result.txt`): `--lint=3`, 16 `--fuel` values and 11 pass subsets across 8 programs. `letpoly`, `nest_any` and `nest_eq` were not swept. Sizes hit no limit: tuples, constructor fields, constructors, constructor arguments and parameters to 5,000 on both targets at `-O0` and `-O2`, 70 rows of `limits/limits.out`, and live lets likewise, 14 rows of `limits/lets.out`, where that file's own 14 `lets` rows are a generator's syntax error.

**What broke.**
1. **Specialise on polymorphic recursion.** `makeCopy` makes every self-call a call of the copy whatever its type arguments (`lib/compiler/core/simplify.sml:1182`), and `staticParams` ignores them too (`:896`). SML cannot reach this. With `--lint` at 1 or more it reads "an argument has type (int * int) nest where int nest is wanted". At the default level the compile succeeds with ill-typed Mid (`results/defects/specialise-polyrec/`). Comparing type arguments in `makeCopy` alone makes specialise diverge: killed at 60 s, status 124 (`fixA-only.sh`, `out/nest_static/fixA-only.txt`). Refusing such a function in `staticParams` is enough (`patches/E1-simplify-polyrec.patch`). With no change to Rune, rhc can type the function at `any`: `nest_any`.
2. **A defect on master, in plain SML.** `=` on a non-uniform datatype at `-O2` overflows the compiler's stack: `eqFunOf` makes a function per type, without bound (`lib/compiler/core/simplify.sml:349-354`, `results/defects/equality-nonuniform/`). A 256-node bound on the type fixes it, in the same patch, +10 -4 for both. rhc can also never emit `poly_eq` on a datatype.
3. **`funNames` is semantic.** `Expand.isFunctor` (`lib/compiler/core/expand.sml:190`) and `Simplify.functorFun` (`lib/compiler/core/simplify.sml:1982`) read a `"functor "` prefix from a table keyed by parameter. So the Basis read back from text fails `-O1` and `-O2` at lint 2, a `functor_cast` breach (`link/run.out`). At `--lint=0` it compiles with expansion skipped, 167,452 bytes against 50,422 (`link/runC.out` has the second; the first is from an unsaved run, by M's report). Printing the name in text fixes it (`patches/E1-midtext-functor-name.patch`, +14 -2).

**Where the lint stops.** A forgotten force is a lint error only without a cast. `tag` of a `susp` passes MidLint (`lib/compiler/core/midlint.sml:271-272`) and is a fatal at run time on all engines. Behind `unsafe_cast`, the interpreter and tier 1 go fatal, and **tier 2, even with `--checked`, exits 0 with output** (`out/neg/forget.txt`). That Mid is ill-typed: the `any` boundary is trusted. D5 tabulates it, and E4 prices an answer.

**A thunk in this encoding,** per iteration as slopes (`out/forcecount/slopes.txt`). VM instructions, register and stack targets:

| | Register `-O0` | Register `-O2` | Stack `-O0` | Stack `-O2` |
|---|---:|---:|---:|---:|
| Loop alone | 10 | 10 | 13 | 13 |
| Force of `Done` | 18 | 18 | 27 | 27 |
| Make and force | 39 | 37 | 60 | 55 |

A thunk made and forced is 4 objects and 72 bytes. `unsafe_cast` stays a real primitive call at tier 2: 12,164 of 12,229 primitive calls in `knot`, 305 of 327 in `monad` (`out/jitstats.txt`).

**What rhc must do, with no pass or lint changed.**
- A thunk's code takes `unit`, since a function has at least one parameter (`lib/compiler/core/midlint.sml:333`).
- A recursive value goes through a cell: `ghole`, build the closures, `gpatch`. Dictionary cycles in dictionary functions do too. Instance globals read themselves at call time instead.
- A function of more than one parameter is not a value, so a method gets curried wrappers: State's `>>=` is three nested closures.
- LowShapes demands a tag test in the same function before a `Decon` (`lib/compiler/backend/lowshapes.sml:376`). It caught a real slip of M's, but Core cannot drop a test on knowledge from another function.
- `monad` needed casts on 25 of its 274 lines. The other programs needed none outside the runtime, and `classes` typed its dictionaries as datatypes.

**What Mid text cannot say:** function names, so traces say `fn`; exception argument types, so `MkExn` and `exnarg` go unchecked; pinned layouts and open types [read]. Abstract arity is read and dropped (`lib/compiler/core/midtext.sml:648-650`). `char` stops at 255. A forward `Val` read is an engine fatal no lint sees, and `-O0` and `-O1` disagree on it (`out/neg/unset.txt`).

**The library boundary.** A hand-written Mid module can call compiled SML globals.
- **Whole-program text:** `TextIO.print` and `IntInf` ran, and 2^100+1 was right on both targets at all levels at lint 2, given the functor-name patch (`link/runC.out`). The text form loses what it cannot say [read].
- **Units, the recommended road:** `patches/E1-all-prototypes.patch`, +81 -12 with all the above, adds a `.mid` unit after the Basis's units. `gimp_NAME` resolves through `Env.findVal`, and an unknown type name through `Env.findTy`. Right on both targets at all levels (`link/runU.out`), and `List.map` given a Mid closure and `IO.Io` caught in Mid ran on registers at `-O0` and `-O2` (`link/runU2.out`). Output is unshaken: 574,784 bytes at `-O1`.

This needs `Env` and `UnitBasis` to look a value or type up, so rhc links them. Exception constructors are not resolved, so SML bridges them. It ran with SML elaborating the Basis in the session, not from `.rbi` alone.

**Front-end independence** (`indep/grep.out`, by grep, in the Mid-onward files). With the prototypes, every program ran with the front end's tables empty.
- **Link-time:** `Elaborate` 17 references, stamps among them; `Types` built-in tycons 109; `Lambda.const` and its constructors 96, inside Mid itself. `Pipeline` names `ToMid`, `Translate`, `Ast`, `Env`, `Fixity`, `UnitBasis`. rhc links the SML front end unless E11 lands.
- **Semantic:** `funNames`, 33 references (M's report says 41; the file says 33), for functor identity.
- **Performance or units only [read]:** `Translate.primAliases` and `primArity`, `Elaborate.markedFunctions`, `Ty.binders`.

**Changes to Rune,** graded:

| Grade | Change | Where | Size |
|---|---|---|---|
| none | `susp`, `any`, cell-patched recursion, CAF thunks | Mid text | 0 |
| none | polymorphic recursion at `any`, no `poly_eq` on datatypes | rhc | 0 |
| small, needed | `readMid` to bytecode | `src/driver/main.sml:218` | +14 -2 |
| small | `staticParams`, `makeCopy`, the equality bound | `lib/compiler/core/simplify.sml` | +10 -4, the compiler's bytes identical at `-O1` and `-O2` (`out/selfcheck.txt`) |
| small | a functor's name in text | `lib/compiler/core/midtext.sml`, overlapping E11 | +14 -2 |
| small | a Mid unit with imports | `lib/compiler/core/midtext.sml`, `lib/compiler/driver/pipeline.sml:245`, `src/driver/main.sml` | +43 -4, by difference in `E1-all-prototypes.patch` |
| small, not prototyped here | erase `unsafe_cast` | `lib/compiler/backend/lower.sml:987-990`, `runtime/prims.c:2365` | E4: 3 files, +45 |
| small, not prototyped | lints: `ConTag` to datatypes, forward `Val` reads, abstract arity | `lib/compiler/core/midlint.sml:271`, `lib/compiler/core/midtext.sml:648` | small [inferred] |
| medium, not prototyped here | stamps, `Types` builtins and `Lambda.const` out of the front end | E11 | see E11 |

**What would have flipped it.** The plan: a pass rejects it, tier 2 faults, or specialise diverges. A pass did reject legal output, and both fixes are local. Tier 2 never faulted on well-typed Mid. Specialise diverged only under the naive fix. Had any stood, Mid's System F could not carry Haskell, and rhc would erase to `any` throughout or hook at Low and lose every Mid pass. The nearest thing to a flip is the silent run at tier 2 behind a cast, which is why D5 and E4 exist.

**Not established.**
- Whether Simplify sees through casts, and casts per node: E4.
- Thunk chains deeper than 2,000: E2.
- Force cost against E2's forms.
- `runeopt` native code.
- Whether lost pins can miscompile. The Basis text did not show it.
- A Mid unit from `.rbi` alone, in the cache, or through `--emit-units`.
- Whether the `any` road survives real `Show` and `Eq` dictionaries for `Nest`.

### E2. Thunks on the real engines

**Question.** What is a thunk on Rune's engines, what does force cost, and does it need an instruction? **Settles:** D3, D11, D12, D13, D14, D18, D19, with the object lazy ML shares (D57).

**How.** Agent V, in `hs-vm`, through the loader, the collector, images, both bytecodes and tier 2. The workload is the 115 `-lazy` ports in `examples/benchmarks` at `normal`, with their strict twins, and kernels (`kernels/*.sml`, `kern.py`). The ports have no dictionaries or `Integer` defaulting and their delays are hand-placed: they compare thunk forms, not compilers. `INDEX.txt` maps forms, stages and scripts.

V added three forms to the brief's A, B and C. Each has Haskell's reading, which blackholes and releases, and lazy ML's, which does neither. Machine instructions are at tier 2.

| Form | What |
|---|---|
| A | ref encoding: no change to Rune |
| B | prims over a `K_THUNK` holding a closure, in C or in line; "with drop" also releases what the thunk captured |
| C | instructions: `FORCE`, `ENTER`, `BLACKHOLE`, `UPDATE`, over a flat `K_THUNK` |
| F | a marked `K_CLOSURE`, entered by plain `CALL`; `force` a library function |
| G | F with force one Mid node, `thunk_fforce`, which `Regs` lowers to a test, a value read and `CALL` |
| L | G with nothing written at entry; the collector does the release |

**Result: the forms,** under Haskell's reading unless it says so. The ports are the 113 of 115 that pass under every form: `lambda-monad-lazy` and `lambda-simple-lazy` fail to compile under B (`tables/summary.txt`). Delay, first force and evaluated force are machine instructions an operation less the loop, and bytes a delay are for a delay of two captures (`tables/micro.txt`).

| Form | Stage | Sum, G | Against C: all, densest 20 | Worst port | Allocated, GB | `--count`, G | Delay | Delay and first force | Evaluated force | Bytes |
|---|---|---:|---:|---|---:|---:|---:|---:|---:|---:|
| Shipped `lazy.sml` | `bin0` | 4,509 | 1.430, 1.394 | `ansi-lazy` 2.732 | 901 | 346 | | | | |
| A, lazy ML's | `bin0` | 4,232 | 1.347, 1.231 | `multiplier-lazy` 2.161 | 915 | 306 | 69 | 113 | 17 | 64 |
| A | `bin0` | 4,298 | 1.364, 1.270 | `ansi-lazy` 2.656 | 898 | 329 | 69 | 97 | 27 | 64 |
| B, prims in C | `bin1` | 7,209 | 2.116, 3.067 | `knights-lazy` 3.773 | 632 | 294 | 209 | 452 | 144 | 48 |
| B, in line | `bin12` | 3,371 | 1.110, 1.095 | `fft2-lazy` 1.392 | 632 | 294 | 60 | 110 | 29 | 48 |
| B, in line, with drop | `bin12` | 3,767 | 1.225, 1.275 | `sorting-lazy` 1.792 | 784 | 345 | 60 | 115 | 29 | 48 |
| **C** | `bin10` | 2,992 | 1.000 | | 564 | 269 | 63 | 102 | 13 | 32 |
| F | `bin10` | 3,600 | 1.169, 1.247 | `sorting-lazy` 1.488 | 649 | 347 | | | | 32 |
| **G** | `bin12` | 3,145 | 1.048, 1.065 | `knights-lazy` 1.196 | 564 | 303 | 60 | 109 | 24 | 32 |
| L | `bin15` | 3,125 | 1.043, 1.052 | `knights-lazy` 1.191 | 564 | 303 | 60 | 106 | 24 | 32 |

Lazy over strict twin, geomean over 109 pairs: shipped 1.684, C 1.169, G 1.227 (`tables/summary.txt`). F's extra allocation is Mid's inlining budget [inferred from objects per port]: a library `force` pushes thunk bodies past it, so rhc must emit force as one node. B with drop has the same wrapper-closure effect [inferred].

**What compares with what.** The forms ran on different stages, so a ratio on the ports crosses them (`INDEX.txt`). Three points, recomputed from `results-*-normal.jsonl`:
- **G against C** is `bin12` against `bin10`, and that crossing does not matter. V2 reran C on `bin12`, G's stage, on all 113 ports (`results/V2/chy.jsonl`): `--count` identical on all 113, instructions 1.00014 of C on `bin10`, worst port +1.57% on `atom-lazy`. On one stage G is 1.0481 of C, and 1.0653 on the densest 20. In cycles, best of 3 and pinned, the densest 20 give 1.062 (`results/V2/cyc.jsonl`), so cycles track instructions there. E5's `formc.tsv` also runs G, C and L on one stage.
- **L against G.** L's stage walks frames at every collection, which G does not need. As each would land, `LhZ` on `bin15` against `GhY` on `bin12`, L saves 0.64% on the sum and 0.55% by geomean. On one stage, `LhZ` against `GhZ`, it saves 0.83% and 0.73%: the walk costs G +0.19% by geomean there. Against `GhY` by port, L runs from -1.48% (`lcss-nofib-lazy`) to +0.81% (`transform-lazy`), so it is worse on some ports.
- **The guard** on the `K_IND` shortcut is in G's and L's figures. Whether it is in C's stage was not established.

`any-cost` (`bin4`) and `sml-cost` (`bin10`) are on other stages again, and are named below.

**How many ports go through the delay module.** 114 of 115. A counting `lazy.sml` shows each of them delaying and forcing at run time (`results-Acount-smoke.jsonl`, `count-ports.txt`). The 115th, `primes-lazy`, has its own copy in `shared/primes.sml`, which already reads as lazy ML. The design agent's 95 is a bare grep of `*-lazy/benchmark.sml`, 82 `BenchNeed` and 13 `BenchLazy`, rerun for this roadmap. It misses `BenchBannerNeed` and the ports that reach the module through `shared/*.sml`. An earlier grep's 45 was reproduced by no grep tried, the nearest giving 50.

**The closure as a root: confirmed by running.** Rune's frame holds the running closure, so a thunk compiled as a closure has Jones's `last` leak. Bytes kept an element, with a collection at every allocation (`tables/last.txt`):

| Form | `last`, a tail body | `leak`, a non-tail body |
|---|---:|---:|
| Any form, lazy ML's reading | 56 (B 40) | 56 (B 40) |
| Shipped, and A | 0 | 56 |
| B, in line | 0 | 40 |
| B with drop, C, G, L | 0 | 0 |
| A or B, with closure liveness | 0 | 0 |

- At n = 1000 that is 6,993 words over the base against 1. Clearing the thunk is not enough: the frame's closure slot holds the captures.
- Lazy ML's retention is unavoidable, since its body must be able to run again.
- Peak RSS at n = 4 x 10^6 (`tables/leak.txt`): 231 MB for A, 101 MB for B and for C and G under lazy ML's reading, 8.2 MB released.
- **The price of release:** first force +6 to +10 instructions, and on the ports' sums +1.5% (C), +2.5% (G), +1.9% (L) against their lazy ML twins. L's is across stages. On the `leak` kernel release halves instructions (`tables/leak.txt`).
- **Closure liveness,** a frame's closure a root only while later code reads it: about 25 lines, no compiler change, 1.0002 on 12 strict ports with identical `--count` (`tables/closurelive-cost.txt`). It does nothing for C, G and L, where the update needs the slot.

**Update and stack.** The update is in the thunk's own code, so hot `RET` is untouched. A VM-level update frame was not built. Stack per level (`tables/depth2.txt`):

| Kernel | SML recursion | A lazy ML's, B, C, G | A, Haskell's | B with drop | Tail body |
|---|---:|---:|---:|---:|---|
| `chain` | 64 | 80 | 144 | 88 | |
| `tailchain` | | A, B 72; C, G 56 | 80 | 80 | one frame either way |

A 10^7 chain fits 1 GiB in SML and in every form but A under Haskell's reading, which overflows. G takes 7.1 G instructions there against 25.5 G for A (`tables/depth-1e7.txt`). `chain` is one frame a level.

**Raise and re-entry.** Lazy ML gives `42, 2 runs` after a raise and `2, 3 runs` on re-entry, on all tiers (`tables/semantics.txt`, `tables/raise-F.txt`). The shipped module gives `~2, 1 run` and a `Fail` on re-entry, so it is not lazy ML's, and it keeps the closure on `leak`, so it is not Haskell's. Under Haskell's reading a raise leaves a blackhole, and with nothing done the next force says a false `<<loop>>`, as B still does (`tables/semantics.txt`, `tables/raise-repair.txt`). There are two cut sites, `vm_raise` and `emit_RAISE`'s inline cut. An 11-line frame walk marks the thunk failed so that it raises again, which works on C, F and G because the frame's closure is the thunk. Report 3.1 makes this diagnostics only (D12).

**L and re-entry.** L reports `<<loop>>` only after a collection (`tables/lreenter.txt`). Before one, a re-entered thunk just runs again. It needs an entry check for memory safety, since a released thunk re-entered must stop and not read dead fields. L's hook is about 14 lines.

**The `K_IND` shortcut: confirmed.** Forcing a forced outer suspension ran the inner one after a collection on forms B, C and G without a guard (`tables/nested.txt`). Haskell cannot reach this. V's first guard missed a target already forwarded in the same collection, so the guard must look through forwarding. It costs 1.00898 by geomean under lazy ML's reading and 1.00835 under Haskell's, at worst 1.058 and 1.055, both on `fulsom-lazy`, unexplained (`tables/guard-cost.txt`). The other latent faults of `K_IND` are in `results/defects/latent-k-ind/`.

**Tier 2 and safety.**
- A thunk in a slot typed list, tuple or `ref` gives a silent wrong answer at tier 2, a blind field read, while the interpreter and tier 1 stop. The same thunk typed `int susp`, which is `RAny`, stops on all three (`tables/wrongslot.txt`). No crash was obtained, and an out-of-bounds read was not demonstrated.
- **G's cost:** a thunk in a function-typed slot passes every engine silently (`tables/wrongslot-F.txt`), so MidLint is the only defence there.
- `Any` on every slot, as an upper bound: 1.19 by geomean and 1.39 at most on 16 ports, with `ms_trusts` answering 0 (`tables/any-cost.txt`, `bin4`). rhc pays this only on slots still `Any` [V's inference].

**Verification.**
- **Stress:** 504 runs on B, C and G (`tables/stress.txt`) and 98 on L (`tables/stress-L.txt`), 0 bad, over the interpreter, tier 1, tier 2, `--gc-verify`, `--jit-stress`, `--deopt-stress`, `--gc-stress`, low-pause and compact, with `--count` compared outside the collector modes.
- **Images:** evaluated, unevaluated and under-evaluation thunks all restore (`tables/image.txt`).
- **Lint:** `--lint=2` at `-O0`, `-O1`, `-O2` agrees on the kernels for G, C and B (`tables/lint-Y.txt`). Ports clean: G, L, C, F 115; B 113 (`tables/portlint-Y.txt`, `portlint-L.txt`, `portlint.txt`).
- **The barrier:** an old thunk with a young value passes. `vm_write_barrier` does not exist at `b12141ecc`; the masm form is `ms_set_field`.
- **Other engines:** F passes 7 kernels in both readings on the stack VM and in native code (`tables/F-stack-native.txt`). G's force did not run through the Stack target here, where it is a fatal stub. E14 built that.
- **SML:** 1.0056 in machine instructions on 12 strict ports with identical `--count`, on `bin10`, before L and liveness (`tables/sml-cost.txt`).

**What each form takes.** Hand-written lines, V's count from `patches/E2-all-forms.patch`, whose whole with generated tables is +1,051 -73.

| Form | Lines | Where |
|---|---:|---|
| A | 0 | |
| Shared by B, C, G, L | about 45 | `value.h`, `image.c`, `share.c`, `census.c`, `minor.c`, `mark.c`, `types.sml`, `env.sml` |
| B in line | about 120; drop +56 | `prims.c`, `fastprim.h`, `emit.c`, `prims.sml` |
| C | about 260; about 115 more for parity [estimate] | `isa/regs.sml`, `emit.c`, `compile.c`, `prims.c`, `backend/regs.sml`, `low.sml` |
| G | about 210 | `prims.c`, `fastprim.h`, `emit.c`, `prims.sml`, `low.sml`, `backend/regs.sml`, `stack.sml`, `regverify.sml` |
| L | about 50 more | `gc_release_thunks`, prims |

**What would have flipped it.** The plan: a primitive form over 30% worse justifies the instruction. G is within that line, and the line has no source, so D13 does not rest on it. V challenged it too: 30% of a whole program hides per-operation gaps, evaluated force being 24 against 13, and it fails B only while B's prims are in C. If rhc ran at 3 times the ports' density, G would sit about 20% over C [V's inference]. E5 measured that: density about 2 times at `D0`, and G 1.02 to 1.22 of C. `FORCE` stays an additive later option, since it changes neither the object nor the protocol.

**Not established.**
- rhc's real density: E5.
- aarch64, 32-bit, PowerPC, Windows.
- `make check`, bootstrap bytes, `test-native`.
- The census build, edited and not built.
- Release under the low-pause collector, skipped while marking.
- Selector thunks, CAF collection, cycles.
- Why `fulsom-lazy` pays 5.8% for the guard.
- A body outliving its own update with a collection between the updates: V's kernels had none. E14 found that this fails.

**Defects.** `results/defects/simplify-drops-local-fun/`: Simplify leaves a call of a dropped local function, a compile failure on `lambda-simple-lazy` and `lambda-monad-lazy` under B. It reproduces only with the prototype's primitives, so it may or may not be a master bug.

### E4. `Any` against extending `Ty`

**Question.** `Ty.view` has no type headed by a variable and no forall (`lib/compiler/core/ty.sml:27-33`). So how many casts does an `Any` translation really make, do they block method inlining, what do they cost, can a forgotten force behind one be caught, and is extending `Ty` worth it? **Settles:** D4, and D5's checked `Any`.

**How.** Agent N, on stage `results/E5/bin3`, form G under Haskell's reading. `results/E5/mrhc.py` lowers hand-written Core (E5). It casts where a type translated before instantiation differs from one translated after, so the counts are what the types force. Higher-kinded positions erase to `any`, a polymorphic method's dictionary slot is `any susp`, and an ordinary type variable stays a Mid type variable. Environment switches of the throwaway compiler select each mode (`patches/E4-E5-README.txt`).
- `state`: `mapM_` in a State monad. `foldm`: `foldM` at State and at Maybe. `queens` is E5's. `knot` and `monad` are E1's, on ref-encoded thunks.
- `casts.out` counts casts against Mid nodes. `simp.out` asks whether Simplify folds a method at a locally built dictionary. `e4.tsv` runs each cast as a primitive, a `MOVE`, another name, or checked. `neg.out` runs forgotten forces on four engines.

**Result: how many casts** (`casts.out`). "Into `susp`" is a value cast to a `susp` slot, which needs no thunk.

| Program, step | Nodes | `any` casts | Into `susp` |
|---|---:|---:|---:|
| E1's `monad` | 177 | 25 | 0 |
| `state` `D0` | 1,347 | 17 (1.3%) | 118 |
| `foldm` `D0` | 1,429 | 31 (2.2%) | 123 |
| `queens` `D0` | 1,372 | 0 | 124 |
| `state` `D2`+eta | 486 | 0 | 39 |
| `foldm` `D2`+eta | 523 | 0 | 44 |

E1's 25 in 274 lines is typical of monadic code, not of programs. Functions holding an `any` cast, dictionaries included, are 7.9% and 11.7% of nodes on `state` and `foldm` at `D0`, 9.9% and 14.3% at `D1`. `queens`, `primes` and `showk` have none at any step, and specialisation leaves none anywhere. nhc98's nofib has 1.3 `>>=` per 1,000 lines and 5 `Monad` or `Functor` instances, by grep (`monadic.out`).

**Does Simplify see through a cast?** The flip fires, then dissolves. VM instructions for a program calling a method at a locally built dictionary, where 7 means folded to the constant (`simp.out`):

| | No cast | `any` slot | `any susp`, forced | Called at another type |
|---|---:|---:|---:|---:|
| Stock | 7 | 16 | 21 | 23 |
| `patches/E4-simplify-casts.patch`, +50 | 7 | 7 | 7 | 7 |

On real programs the patch does little (`simpreal.out`, VM instructions at `-O2`):

| | `D0` | `D1` | `D2`+eta | `D3`+eta |
|---|---:|---:|---:|---:|
| `state`, stock | 21,705,375 | 20,404,621 | 19,203,227 | 17,103,004 |
| `state`, patched | 21,705,375 | 20,404,631 | 19,203,082 | 17,103,013 |
| `foldm`, stock | 32,710,302 | 28,608,898 | 26,406,340 | 23,905,912 |
| `foldm`, patched | 32,710,302 | 28,608,918 | 25,706,076 | 23,305,932 |

At `D0` and `D1` it changes nothing: dictionaries are global `Val`s, and Simplify knows the value of a local variable alone (`lib/compiler/core/simplify.sml:472-473`). Casts are not the blocker. `foldm` does gain 2.7% and 2.5% at `D2` and `D3`, and 4.9% and 4.2% of bytes. No `any` cast is left there, so that is the patch's rule for a force of a value cast to `susp` [inferred, not separated]. Method inlining belongs in Core.

**What a cast costs.** `patches/E4-cast-modes.patch`, 3 files, +45 (`lower.sml` +39, `regs.sml` +4, `regverify.sml` +2), holds four modes, of which `alias` makes a cast another name in Lower. Rune `-O2`, instructions and primitive calls from code at tier 2 (`e4.tsv`):

| | `knot` | `monad` | `state` | `foldm` | `queens` |
|---|---:|---:|---:|---:|---:|
| Kept over erased | 1.18 | 1.14 | 1.05 | 1.03 | 1.03 |
| Primitive calls, kept | 12,229 | 327 | 600,221 | 500,356 | 1,267,057 |
| Primitive calls, erased | 65 | 22 | 40 | 76 | 16 |

- Form G already took out the hot cast, since force needs none: compare `knot` and `queens`.
- Erasure takes a Lower rule dropping a force of a known non-thunk, and a `RegVerify` exception that lets `CALL` see a non-closure on force's slow path, which `--lint=2` demanded.
- The source's representation is kept, so tests stay. A trusted `MOVE` is no faster.
- `rbc/rune.keep.rbc` and `rbc/rune.alias.rbc`, the compiler compiled both ways, are byte-identical, and that shows nothing. The mode rewrites only Mid's `unsafe_cast`. The compiler's own casts are `functor_cast` and its kin, which the patch leaves alone, and in `lib` and `src` `_prim "unsafe_cast"` occurs only in `lib/basis/dynamic.sml:12` and `lib/basis/compiler.sml:290`, `demand` files that `rune.build` does not name. So there was probably nothing to erase [deduced; the compiler's own Mid was not dumped]. What is known of erasure is the table above, on programs that do cast.
- `state` kept at `-O2` gives 732M or 865M from one file, unexplained: 3 of 8 runs at 865M, on a machine at load 0.4 (`w9-repeat.out`, repeating N's observation). The table's 1.05 uses 733M, which `e4.tsv` and `results/E5/results.jsonl` both hold. Erased, the same program gave 696M in all 8.

**Can a forgotten force behind a cast be caught?** `neg.out`, three programs on four engines at `-O0` and `-O2`. `neg_fun` stops on every engine in every mode, so the table is of the other two, `neg_list` and `neg_poly`, at tier 2.

| Mode | Forgotten force behind a cast |
|---|---|
| Plain | wrong answer, 7, on both, `--checked` too |
| The lint, no cast leaves a `susp` (`patches/E4-cast-lint.patch`, +7) | refused; `neg_poly`, through a type variable, only at `-O2` |
| Casts erased | fatal on both, on every engine, since `RAny` keeps its tests |
| `any_check` at each cast of `any` | fatal on every engine |

- `any_check` costs +3% to +18% over erased at `-O2`, which is the price of keeping casts: `monad` has 40 checks in 305 casts, `queens` none, and check against kept is within 0.4% (`e4.tsv`).
- `neg.sh` ran the lint on those three programs alone, so nothing showed it accepts a legal one. Run for this roadmap over nine lowered programs at every step of `casts.out`, at `-O0` and `-O2`: 90 compiles, 0 refused (`w9-lintpos.out`). It has not been run over SML's own Mid.

**Extending `Ty`.** There are 96 `Ty.view` sites in 18 files, 82 of them ending in a catch-all (`tyview.out`, a heuristic). It needs variable heads, forall under hash-consed `equal`, and partial tycons. Erased newtypes make `m := State s` a type lambda, or keep a cast. N's estimate is 300 to 500 lines over 12 or more files. It buys MidLint a view of what CoreLint already sees, and no speed, since a position stays `RAny`. It leaves every cast into `susp`.

**What would have flipped it.** The plan: casts block method inlining. On a local dictionary they do. But real dictionaries are out of Simplify's reach with or without casts, and specialisation leaves no `any` cast, so the flip does not hold. `Any` stands.

**Not established.**
- Why `state` at `-O2` with casts kept is bimodal.
- The Simplify patch on SML.
- The lint on SML's Mid.
- A real `Monad IO`: E5 erases it.
- `Any` on programs with more monadic code than these two kernels.

### E5. Integer, dictionaries and curried calls

**Question.** What do an unoptimised rhc's programs cost on Rune, and what removes it? Is a small `Integer` immediate? Do curried calls need eval/apply? How far from `ghc -O0` is rhc: what is K? **Settles:** D13's rhc-shaped figure, D15, D20, D49 and D56.

**How.** Agent N, on stage `bin3`: form G under Haskell's reading, casts erased unless a row says kept. `mrhc.py` mechanises hand-lowering and is no compiler: its input is Core written by hand, dictionaries explicit (`core/prelude.core`: the Report's definitions, rhc's overlay marked), and it lowers that as an unoptimised rhc would. It cannot read Haskell. Its passes make E3's ladder on Rune:

| Step | What `mrhc.py` does |
|---|---|
| `D0` | dictionaries at run time, every method through its selector |
| `D1` | a method at a known dictionary resolved, a literal at a known type folded |
| `D2` | every overloaded function copied per known dictionary |
| `D3` | a known global function passed for a static parameter: a copy with the parameter gone |
| eta | a definition's arity from what its body visibly is |
| strict | first order: arguments evaluated at known calls, let to case, no worker/wrapper |

**E5's files call these steps `D0` to `D3`. They are not decisions: in this roadmap a step is always in code type.** Unless a row says otherwise, the figures are Rune `-O0`, tier 2, `Integer` as `IntInf`.

**The programs.** Three whole nofib programs, `queens` 10, `primes` 100 and `exp3_8` 8, with `read` left out and `IO` erased. Four kernels: `sum`, `sumint`, `list`, `showk`, the first, third and fourth under `Integer` defaulting (`kernels/`). No more than that. Every build passed `--lint=2`, and each run's stdout was compared: 278 rows, 0 not ok (`results.jsonl`, `k.txt`), 576 stress runs on 12 modes at small sizes (`stress.out`), 48 laziness checks at each step (`lazyk.out`). The stack target was not tried.

**Result: `Integer`.** `docs/plans/heap-layout.md:4999` says a small `Integer` is immediate. That is a plan: `IntInf`'s `S` boxes its limb, and a small one read as an int is a fatal (`intinf/run.out`). E5 measured two forms and no bignum path. **I0** is `IntInf`'s fast paths ported to Mid. **I1** is an immediate with primitives in line, `patches/E5-integer-prims.patch`, +70 -2, on `int_add`'s inline code, whose slow path is a fatal in this prototype. `mrhc.py` names an **I2**, tested in Mid, and has no runtime for it: it was not run. Per add, in a loop of 10^7 (`intinf/run.out`):

| Form | Instructions | Bytecodes | Bytes |
|---|---:|---:|---:|
| SML `int`, for scale | 19 | 9 | 0 |
| Real `IntInf`, SML | 74 | 17 | 16 |
| I0, the Mid port | 79 (`-O2`) to 85 (`-O0`) | 17 | 16 |
| **I1, immediate** | 24 | 8 | 0 |

On programs at `D0` (`results.jsonl`): `sum` -36.0%, `list` -23.6%, `showk` -17.2%. It does nothing on Int programs: `sumint`, `queens` and `exp3_8` under 0.1%, `primes` 0.4%.

**Result: the ladder.** M instructions (`k.txt`, `ladder.txt`, `ghc/ghc.tsv`, `ghc/r/r.tsv`, `ports.jsonl`):

| Step | `queens` | `primes` | `exp3_8` | `sum` | `sumint` | `list` | `showk` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `D0` | 2,542 | 553 | 4,023 | 3,636 | 2,333 | 7,910 | 1,405 |
| `D1` | 2,001 | 410 | 2,929 | 3,627 | 2,325 | 8,060 | 1,343 |
| `D2`+eta | 1,988 | 397 | 2,916 | 3,600 | 2,313 | 7,121 | 989 |
| `D3`+eta | 1,947 | 394 | 2,915 | 3,006 | 1,347 | 7,179 | 953 |
| `D1`+eta+strict: no specialisation | 1,265 | 267 | 2,866 | 3,247 | 2,052 | 5,268 | 1,297 |
| `D3`+eta+strict | 1,209 | 243 | 2,852 | 809 | 453 | 4,342 | 562 |
| The same, I1 | 1,208 | 241 | 2,852 | 472 | 452 | 3,189 | 352 |
| The same, Rune `-O2` | 987 | 188 | 2,850 | 444 | 421 | 3,160 | 276 |
| `ghc -O0` | 744 | 147 | 771 | 247 | 100 | 596 | 68 |
| `ghc -O0`, Report list functions | 935 | 171 | | 2,108 | 2,018 | 1,185 | |
| `ghc -O2` | 51 | 75 | 892 | 149 | 5 | 225 | 30 |
| `-lazy` port, Rune `-O2` | 110 | 159 | 2,829 | | | | |

"Report list functions" compiles the Report's `foldl`, `sum`, `length`, `map`, `filter`, `++` and so on at `-O0` with the program, instance methods staying `base`'s (`ghc/r/RP.hs`).

- **`D1`** saves 21.3%, 25.8% and 27.2% on the whole programs, and no thunk: `queens` makes 13.3M at `D0` and at `D1` (`density.txt`). On `sum` and `sumint` it saves 0.2% and 0.4%, and `list` rises 1.9%, unexplained.
- **Strictness** is the largest step on `queens` and `primes`, -37.9% and -38.3% from `D3`+eta. `queens` goes from 13.3M thunks to 5.3M and from 636 MB to 225 MB. It gives `exp3_8` 2.2%, and thunks stay at 8.07M: lazy data [inferred]. It costs `state` 3.2% at `-O0` (`ladder.txt`).
- **`sum` needs specialisation and strictness together:** `D1`+eta+strict is 3,247 and `D3`+eta+strict is 809. This confirms the plan's inference.
- **Eta alone,** `D2` to `D2`+eta, saves 0.0% to 1.1%. No step runs strictness without it, so what it gives there was not measured. Through an erased newtype, the state-hack case, it gains nothing at `D2`: `state` and `foldm` rise about 1% (`nt2e` rows); after strictness they fall 2.7% and 0.4% (`nt3es`).
- **Mid alone.** Rune's `-O2` on `D0` output saves 3.0%, 2.0% and -0.8% on the whole programs, and -7.2% to +10.9% on the kernels. After strictness it saves 18.4%, 21.6% and 0.0%. So Mid's passes do not recover the `D1` step, which answers D47's third argument on these programs, and they do pay once thunks have gone.
- **The collector** takes 75.3%, 70.4% and 71.4% of instructions on `sum`, `sumint` and `list` at `D0`, 49.5% on `exp3_8`, 9.4% on `primes`, 3.5% on `queens` (`gc/share.out`). A 256 MB nursery takes `sumint` from 2,360M to 629M, and `list` from 10,387M to 2,469M, each against an 8 MB one.
- **An accumulating `length`** takes `list` to 4,526 at `D0`, and its row of `D3`+eta+strict with I1 to 1,261 (`list2`).
- **Superclass flattening** could save at most 4.7% of `list`'s bytecodes, nothing on whole programs [inferred from `stats.jsonl`].

**Result: K.** K is rhc's slowdown at `D0`, as an unoptimised rhc would run, in instructions at tier 2 at Rune `-O0` (`k.txt`, `ghc/r/r.tsv`). It rests on the three hand-lowered programs and the four kernels, no more.

| Against | `queens` | `primes` | `exp3_8` | `sum` | `sumint` | `list` | `showk` |
|---|---:|---:|---:|---:|---:|---:|---:|
| `ghc -O0` | 3.4 | 3.8 | 5.2 | 14.7 | 23.3 | 13.3 | 20.7 |
| `ghc -O0`, Report list functions | 2.7 | 3.2 | | 1.7 | 1.2 | 6.7 | |
| `-lazy` port | 23.2 | 3.5 | 1.4 | | | | |

The kernels' 13 to 23 are mostly `base` at `-O2` and the collector: with the Report's list functions at `-O0`, GHC's own `sumint` costs 20 times what it did. So N takes **K = 5 for whole programs and K = 20 for Prelude- or `show`-bound ones [inferred]**: E8's 36.4 s becomes 182 s or 728 s, 1.5% or 6.1% of `make check`, before compile times and ways (D56). After the first optimiser, I1, Rune `-O2`, the row against `ghc -O0` is 1.3, 1.3, 3.7, 1.8, 4.2, 5.3, 4.1.

K is a ratio of instructions and a budget is seconds. The same runs' cycles, single loaded runs on Rune's side, give 5.8, 6.5 and 7.0 on the whole programs and 18.8 to 42.8 on the kernels (`k.txt`, last column): an indication that seconds run above instructions.

**Result: density and G against C.** Thunks made per 1,000 bytecodes, against the ports' median of 17.2, mean 15.0, maximum 27.6 on `fish-lazy` (`density.txt`):

| Step | `queens` | `primes` | `exp3_8` | `sum` | `sumint` | `list` | `showk` | `state` | `foldm` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `D0` | 37.7 | 30.5 | 33.3 | 26.8 | 37.5 | 26.7 | 26.8 | 44.4 | 38.2 |
| `D1` | 45.3 | 38.7 | 52.6 | 26.8 | 37.5 | 28.2 | 27.8 | 46.7 | 42.3 |
| `D3`+eta+strict | 25.7 | 17.7 | 52.6 | 11.9 | 19.2 | 18.6 | 15.7 | 51.1 | 42.5 |

So 2 times at `D0` on the whole programs, not V's 3. It rises at `D1`, which removes bytecodes and no thunk: `exp3_8` reaches 3 times there. `queens` makes 13.3M thunks where `ghc -O0` makes 8.48M (`ghc/queens/tk/queens.ticky`).

G over C on this output, on one stage (`formc.tsv`, `formc-lint0.out`, `results/V2/formc/`):

| | `queens` | `primes` | `exp3_8` | `showk` |
|---|---:|---:|---:|---:|
| `D0`, Rune `-O0` | 1.13 | 1.13 | 1.05 | 1.10 |
| `D0`, Rune `-O2` | 1.14 | 1.14 | 1.05 | 1.11 |
| `D3`+eta+strict, Rune `-O0` | 1.21 | 1.22 | 1.02 | 1.15 |
| `D3`+eta+strict, Rune `-O2` | 1.14 | 1.06 | 1.02 | 1.12 |

Form C fails `RegVerify` on all four programs at `D3`+eta+strict `-O2`. All four were rerun at `--lint=0`, with outputs correct, which is the last row: 867M, 179M, 2,804M and 404M, against G's 987M, 190M, 2,852M and 451M. D13 argues from these. L saves 0.2% to 1.6% against G on the same output, more than the ports' 0.6%, the most on `queens` at `D0`.

**Result: curried calls.** Per iteration, a call through a closure in a `ref` (`ncall/run.out`, tier 2):

| Call | Instructions, `-O0` | Instructions, `-O2` | Bytecodes, `-O0` | Bytes |
|---|---:|---:|---:|---:|
| Known, n-ary | 43 | 18 | 10 | 0 |
| One tuple | 82 | 78 | 15 | 24 |
| Argument in a `ref`, one-argument `CALL` | 113 | 106 | 19 | 0 |
| Curried | 116 | 114 | 16 | 24 |

An n-ary path would cost about 55 [N's inference: not built], so 61 less a chain. Chains of 2 or more arguments, with what that sum saves of each program [inferred] (`stats.jsonl`, counts from an instrumented build):

| | `queens` | `primes` | `exp3_8` | `sum` | `list` | `showk` |
|---|---:|---:|---:|---:|---:|---:|
| `D0` | 5.78M, 13.9% | 1.19M, 13.2% | 8.08M, 12.3% | 1.00M, 1.7% | 3.50M, 2.7% | 2.26M, 9.8% |
| `D1` | 0.38M, 1.2% | 1,200, 0.0% | 15, 0.0% | 1.00M, 1.7% | 2.00M, 1.5% | 1.77M, 8.0% |
| `D3`+eta+strict | 0 | 0 | 0 | 0 | 0 | 0 |

**What a first Core optimiser must contain,** by N's reading of the ladder, in Python lines of `mrhc.py`, a throwaway:
1. Known-dictionary resolution, literals included: 15.
2. Eta from visible arity: 20.
3. Dictionary and static-function specialisation: 143.
4. First-order strictness: 95. No worker/wrapper: a value fits a `susp` slot.

Outside it: immediate `Integer`, `length`-style overlays, the nursery.

**What would have flipped it.** The plan set none for E5. What the results would have changed:
- **D20,** had a small `IntInf` been immediate. It is boxed, so `Integer` is a decision.
- **D15,** had chains survived `D1` on whole programs. They do not: 14% becomes 1% on `queens`.
- **D49,** had resolution moved nothing. It moves instructions on whole programs and no thunk, and nothing on `sum`.
- **D13,** by V's own condition, had G passed 30% of C on rhc-shaped output. It is 1.22 at worst, and D13 no longer argues from that line.
- **D47's third argument,** had Mid recovered the `D1` step. It does not.

**Not established.**
- K with `Read`, a real `Monad IO` or a Prelude beyond this subset, or any real rhc's compile time.
- K on the stack VM, one of D56's three ways. The default tier is within 3.4% of tier 2 on the 18 rows run (`results-default.jsonl`).
- The stack target, `runeopt`, the bignum path, `make check`, bootstrap.
- I2, tested in Mid: not run.
- Eta's worth under strictness.
- The strictness pass's soundness beyond output checks and `lazyk`.
- Why `list` rises at `D1`.
- Why strictness gives `exp3_8` nothing.

**Defect.** `results/defects/lower-nary-local-fun/`: a local function of two parameters passes MidLint, and Lower stops at `-O0`. It is reachable only with `E1-readmid.patch`: on stock master `--read-mid` stops before Lower. `mrhc.py` lambda-lifts around it.

### E14. Lazy ML on the same thunks

**Question.** The brief: "doing haskell first ensures the whole stack supports lazy evalaution properly and the lazy ml can be a properly supported language extension to rune later". Does lazy ML run on form G with `susp`, force and match compilation, with no Core and no Mid pass changed? What do raise, re-entry, effects and a body that outlives its own update do? **Settles:** D57, "lazy ML needs no Core" in D2, the lazy ML side of D12, D14's cost.

**How.** Agent Z, in `hs-z`, a copy of V's tree, on G under lazy ML's reading: no blackhole, no release, re-run after a raise. A throwaway `--lazy` adds `$`, the forcing pattern, `susp` and SML/NJ's `val lazy`, `fun lazy`, `datatype lazy` and `val rec lazy` (`patches/E14-lazy.patch`). No surface syntax lands in this roadmap. `INDEX.txt` maps the stages: `bin-zq` is the patch as it stands, and `bin-z` is the same compiler on V's collector, the control.

The programs are the spec's 10, `spec-lazy/`, from `tests/spec/ext/lazy` at `runespec` `2e893cc07` with SML/NJ 110.99.9's output, and Z's 21, `t/`, with expected output from SML/NJ or from runespec (`oracle/`). Each compiled at `--lint=2`.

**Result: the matrix.** 31 programs, 124 compiles, 1,302 runs, 0 not ok on `bin-zq`, and `--count` the same across engine modes (`tables/matrix-final.txt`). Runs by mode, spec's programs plus Z's:

| Modes | Register, `-O0` and `-O2` | Stack, `-O0` and `-O2` |
|---|---:|---:|
| plain, interpreter, tier 1, tier 2 | 80 + 168 | plain: 20 + 42 |
| gc-verify, small heap | 40 + 84 | 40 + 84 |
| gc-stress 7, 1, 7 at tier 2 | 60 + 126 | 40 + 84 |
| low-pause, its stress, compact | 60 + 126 | low-pause: 20 + 42 |
| jit-stress, deopt-stress, `--checked` | 60 + 126 | |

`gc-stress 1` was 50 on six programs, and `deep` used 5000 in its stress modes (`scripts/matrix.py`). Also clean: 126 runs on three more programs (`tables/matrix2-final.txt`), 713 runs with each of 11 optional passes alone and left out (`passes-zq/summary.txt`), and 186 compile variants including `--lint=3` and `--units` (`variants-zq/summary.txt`).

**Form G as V left it was not ready.** On V's collector the same matrix fails 162 of 1,302 (`tables/matrix-V-collector.txt`), and the second matrix 42 of 126, on `k_outlive_three` (`tables/matrix2-V-collector.txt`):

| Program | Register, ok of 30 | Stack, ok of 12 |
|---|---:|---:|
| `k_outlive`, `k_outlive_int`, `outlive_nullary` | 0 each | 0 each |
| `outlive`, `outlive3` | 30 each | 0 each |
| `outlive2` | 30 | 1 |
| `reenter3` | 30 | 11 |
| the other 24 | all | all |

A body forces its own suspension, a lazy ML body being allowed to run again. The inner run updates, and the outer run outlives that update and updates again, its value standing (rule L5 of `spec/ext/lazy.rs`). SML/NJ and runespec agree. With a collection between the two updates, the `K_IND` shortcut gives the frame's closure slot the value (`results/defects/ind-not-final/`).
- **Register engine:** `thunk_fupd` writes the value object itself, so an ordinary list cell becomes a `K_IND`: "JUMPIFNOTTAG on non-constructor", at tier 2 "int_to_string: wrong argument type", under gc-stress a stack overflow. With an immediate value the slot holds no pointer: "no thunk running".
- **Stack engine:** `Frame.closure` is not shortcut and other slots are, so the update is lost, silently: `109 / 9` where the rules say `109 / 109`.
- `--gc-verify` sees nothing. `Low.hoistEnv` is not sufficient. V's kernels had no collection between the updates.

`t/outlive_nullary.sml` reaches it from SML/NJ's own surface syntax. It is latent on master, where no engine makes a `K_IND`. **Haskell cannot reach it:** a blackholed thunk has one run, and nothing runs after its update.

**The fix: the pin.** `gc_pin_running`: at each collection, a `K_IND` a frame still runs is marked `IND_RUNNING` and not shortcut (`runtime/gc/copy.c`, in the patch). A run on no frame can never write it again, so the rest stay shortcut. It returns at once for a program that blackholes or has no `thunk_fupd` [read]. Against V's collector, on 115 ports with E2's `GmZ` bytecode, all passing, `--count` unchanged (`tables/portcost-final.txt`, `tables/portcost.txt`):

| | Instructions: geomean, sum, worst port | RSS: geomean, worst port |
|---|---|---|
| **The pin, `bin-zq`** | **1.0003**, 1.0002, 1.0183 `transform-lazy` | 0.9995, 1.0435 `prolog-tree-lazy` |
| The pin, `ind_may_shortcut` left to the C compiler, `bin-zp` | 1.0036, 1.0038, 1.0215 `transform-lazy` | 0.9978, 1.0435 `prolog-tree-lazy` |
| No shortcut at all under lazy ML, `bin-zs` | 1.0747, 1.0864, 1.3813 `integrate-lazy` | 1.0814, 2.4725 `multiplier-count-lazy` |

`bin-zq` differs from `bin-zp` by `always_inline` on `ind_may_shortcut`, which gives about 0.3% back on its own: 12 strict ports go from 1.00108 to 0.99801 of V's tree (`tables/smlcost.txt`, `tables/smlcost-zq.txt`). So 1.0003 is the patch as it stands, and 1.0036 is nearer what the pin alone costs [inferred].

**The questions V left.**
- **Raise and effects** match the oracles (`t/raise_nested.sml`, `t/effects.sml`).
- **Re-entry:** no detection. Rune stops at the 1 GiB stack limit in 0.7 to 2.9 s. SML/NJ still ran at 60 s (`tables/forever.txt`, seconds, an indication).
- **`'a susp susp`** is right with the guard (`t/k_nested.sml`). On V's unguarded `bin17` the inner runs early (`tables/nested-noguard.txt`).
- **A release bit: none.** Low holds only `thunk_fmake`, `thunk_fforce`, `thunk_fupd` and `thunk_entry` (`tables/prims-used.txt`). Lazy ML's body leaves release unset. The difference between the languages is that, plus the pin.
- **Equality** on a suspension type: six programs refused. All 13 rejections in `reject/` agree with runespec's verdict (`tables/reject.txt`, `reject-runespec.txt`).
- **Match order:** backtracking and trees follow the rules. SML/NJ differs, as the spec's README says (`t/order.sml`).

**Mid's passes.** Nothing wrong. Of 634 thunk functions in the Mid of every program at `-O1` and `-O2`, none is named except by `thunk_fmake`: 0 violations (`tables/midshape.txt`, `scripts/midshape.py`). Agent I's claim, that `inline` could copy a thunk held in a `Fun` group with MidLint silent, is true and unreachable from `$`. `claim/fun_held.sml`, written with `_prim`, also calls a thunk's function: at `-O2` `inline` copies `thunk_fupd` into another closure's function, every lint passes, and the run stops "expected closure in call" (`tables/claim-fun-held.txt`). So the rule of `midshape.py` is what MidLint lacks.

**What was needed.** `patches/E14-lazy.patch`, on V's tree: 17 files, +239 -30 (`tables/lines.txt`).

| Area | Lines | Haskell needs it? |
|---|---:|---|
| Front end and driver: `parser.sml` +150 -20, `ast.sml`, `env.sml`, `options.sml`, `main.sml` | +164 -21 | no |
| `translate`, `matchcomp`, `lambdalint`, `tomid` | +29 -6 | no |
| Collector, `value.h`, loader flag: the pin | +24 -3 | no |
| Force in `lib/compiler/backend/stack.sml` | +22 | yes [inferred] |

Zero lines in Simplify, Workers, Lift, Shake, Refs, Expand, MidLint, MidText, Lower or Regs. So force through the Stack target has now been built and run, under lazy ML's reading: 372 of the runs above. Haskell's reading has run on that target only as E2's form F.

**SML's cost.**
- **Flag off, byte-identical:** 0 of 756 strict programs differ from V's tree, and 0 from master past the 12-byte header (`nocost/summary.txt`, `tables/masked.txt`). `--count` against master: 0 of 753 differ.
- **Flag on:** 753 byte-identical. 3 are refused, since they name a function `lazy`, which the spec reserves.
- The compiler compiled by V's tree and by Z's is byte-identical (`tables/self-bytes.txt`).
- 12 strict ports: instructions 0.998 of V's tree, one run each (`tables/smlcost-zq.txt`, spread checked on three, `tables/smlnoise-zq.txt`).
- **A leak:** V's `Env` entry binds `susp` with the flag off, and master refuses it (`tables/offcheck.txt`). `susp` must stay unbound.

**What would have flipped it.** The plan: needing more than `susp`, force and match compilation reopens a shared Core. It did not flip: lazy ML needs no Core and no line in a Mid pass, and all 10 spec programs pass. The second finding is of another kind. Form G needs a collector rule neither E2 nor Haskell's reading shows, so "thunks work" did not mean "ready for lazy ML", and without E14 the fault would have stayed latent until the extension. D57's checklist of six items comes from this.

**Not established.**
- `make check`, bootstrap bytes, native code, `runeopt`, other hosts.
- Images with a body mid-run.
- Real scoping: lazy constructors are a flat parser table, and a strict namesake breaks them.
- SML/NJ refuses a strict member in `val rec lazy`; the spec and Z accept it (`t/knot_mixed.sml`).
- Haskell's reading through the Stack target, and whether `stack.sml`'s +22 suffices for it [inferred].
- What the pin alone costs with `always_inline` held fixed.

### E3. Ticky: what a lazy program does before and after an optimiser

**Question.** Rune's `CALL` enters a closure with one argument (`src/isa/regs.sml:122-124`), so an unknown call of n arguments makes n-1 closures [deduced]. How many calls are of that shape, and at which optimiser tier? What does each tier of a Core optimiser remove? **Settles:** the shape D15 (eval/apply) must answer, which E5 prices, and the size of the optimiser in D47 to D51 and M23 to M25.

**How.** Agent O, on GHC 9.4.7: `-ticky -ticky-allocd -debug -rtsopts` over both nofib trees on their fast inputs (`results/E3/ticky.py`). Four levels. `-O0` and `-O2` are GHC's. **L1** and **L2** are O's addition, not levels GHC offers: `-O1` with passes off. L1 leaves method resolution at known dictionaries and little else; L2 adds strictness and worker/wrapper (`results/E3/ticky.py:15-22`). Call counters bump at call sites in instrumented code, so calls inside `base` are missing. RTS counters and `+RTS -s` count everything (`results/E3/summary.py:5-14`, read from GHC's sources at 9.14). These are counts, so load does not touch them.

`results/E3/compare.txt` holds four ladders. Every figure below is from the second, **the 152 programs that ran at all four levels and that E8 accepts as Haskell 98** (needs nothing, an import rewrite or the compat module). The first ladder, 171 programs, adds 19 E8 does not accept, 12 of them `real/eff` and shootout, and is not used. The ladder and paired figures count a run on its return code alone: the `stdout_ok` filter applies only in `ticky.*.agg.txt`. Recounted for this roadmap from `results/E3/keep/compat/*.json`: of the 152, 10 differ from the suite's stdout at some level on a strict comparison, and 15 have nothing to compare at `-O0`. So treat the ladder as unfiltered.

**Result.** A "2+ apply" is a generic apply of two or more arguments, the case a one-argument `CALL` pays for. Total, median and programs are `compare.txt`. The mean is recomputed from `keep/compat/*.json` with `compare.py`'s formula.

| Level | Calls | 2+ applies, % of calls: total | median | mean | Programs at or over 5%, of 152 | Thunks | Bytes | Closures a one-argument `CALL` adds, at 3 words, % of bytes [inferred] |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `-O0` | 3.39G | 63.1 | 56.9 | 54.2 | 148 | 2.68G | 191G | 28.0 |
| L1 | 1.96G | 12.0 | 2.9 | 12.1 | 66 | 1.42G | 119G | 4.9 |
| L2 | 1.99G | 11.8 | 3.0 | 11.2 | 65 | 1.13G | 106G | 5.5 |
| `-O2` | 0.67G | 3.5 | 0.0 | 4.8 | 26 | 0.38G | 44G | 1.5 |

Each step of the ladder, from the same totals, and each level's per-program median ratio to `-O2` (`compare.txt`). These are totals: five programs hold 40.3% of the thunks, and the median program gains less at every step: -26.2% thunks and -17.7% bytes on the first, -11.5% and -5.4% on the second, -36.7% and -25.7% on the last (`ladder.py`). L1 runs GHC's simplifier and class-op rule with `-fno-specialise` set (`ticky.py`), so it is not known-dictionary resolution alone, and no rung holds a specialiser:

| Step | Thunks | Bytes | | Level against `-O2` | Thunks | Bytes | Updates |
|---|---:|---:|---|---|---:|---:|---:|
| `-O0` to L1: simplifier and class-op rule | -47% | -38% | | `-O0` | 3.18 | 2.07 | 2.57 |
| L1 to L2: strictness | -20% | -11% | | L1 | 2.13 | 1.58 | 1.53 |
| L2 to `-O2`: the rest, not separated | -66% | -58% | | L2 | 1.58 | 1.35 | 1.24 |

At `-O0`, on the 152 (`compare.txt`):
- 57.9% of calls are `KNOWN_CALL_EXTRA_ARGS`, a class method through its selector at this level (the reading is `summary.py`'s).
- 91.3% of thunks are entered. 3.44G updates, 1.65G indirections entered.
- 29M PAPs against 2.14G applies of 2+ arguments, so nearly all saturate [inferred].
- Bytes: thunks 46.1%, constructors 10.6%, functions 0.9%, PAPs 0.6%, base or unattributed 41.8%.

By argument count, on all 175 programs that passed the output filter at `-O0` (`ticky.compat.agg.txt`): one argument 1.03G, two 4.38G, three 0.28G, four 0.06G, five 0.02G. Two arguments is the shape that matters.

**The undercount.** On 91 programs O built the Prelude's functions in source, instrumented, against base's uninstrumented Prelude (`compare.txt`, first section):

| At `-O0`, 91 programs | base's Prelude | Prelude in source |
|---|---:|---:|
| Calls | 1.39G | 2.38G |
| 2+ applies, % of calls: total (median) | 68.3 (55.0) | 56.2 (40.3) |
| Instrumented bytes, % of all (median) | 58.8 (49.3) | 71.4 (76.7) |
| Updates seen, % of all (median) | 72.9 (58.7) | 90.6 (95.1) |

Seeing 72% more calls lowers the 2+ share by 12 points. The ladder therefore overstates the share at `-O0` by something of that order [inferred].

**The threshold.** The plan first took 5% of calls as the line for eval/apply. E15 found no source for it: *Making a fast curry* argues from simplicity and never measures literal currying. Joining the paper's own figures 6 and 7 gives, for unknown calls of 2+ arguments as a share of calls on its 58 programs, median 4.88%, mean 11.15%, call-weighted 16.71%, with 30 of 58 under 5% (`results/E15/lit/machines.fastcurry-join.out`). The verdict depends on the statistic. So this roadmap reports the three statistics and names the tier: at `-O0`, which is where rhc starts, every statistic is above 50%; at L1, which M23 aims at, the median is 2.9% while the total and the mean are 12% and 66 of 152 programs are at or over 5%; at `-O2` all three are under 5%.

**What would have flipped it.** The plan set no threshold, for the reason above. What the data would have overturned is D15 itself, if the `-O0` shape had been rare: it is not. What decides D15 is E5's price on Rune, not a percentage here. The ladder does size the optimiser: known dictionaries are the largest single step at the level rhc can reach first, which is D49's order.

**Not established.**
- Instance methods, `Show`, `Read`, `Integer`, `Data.List` and arrays stay uninstrumented in both variants.
- The Report-style Prelude in the paired runs was written from memory, not from E9's text.
- L1 and L2 are O's constructions. Inlining, specialisation and floating are not separated within the last step.
- `spectral/minimax` timed out at `-O0`, L1 and L2, so it is missing from the ladder.
- Outliers reach 92,165,145 times on thunks and 204,338 times on bytes, `-O0` against `-O2` (`compare.txt`). O puts them to full laziness [inferred, untested].
- GHC's counts price nothing on Rune. The 3-word closure is an inference.

### E6. Cross-module information

**Question.** What must an interface carry beyond types? **Settles:** D44, whether a program's own unfoldings can wait, and D45's claim on the Prelude.

**How.** Agent O, GHC 9.4.7 (`results/E6/e6.py`). Multi-module nofib programs, four ways, on normal inputs (fast for one program, where `-O0` could not finish in the timeout): `-O2`; `-O2 -fomit-interface-pragmas`, where a program's own modules export types only and libraries keep their unfoldings; `-O2 -fignore-interface-pragmas`, where every import's unfoldings go, libraries' too; `-O0`. Measures are `instructions:u` and `+RTS -s` bytes. Of 95 programs in `e6.tsv`, 75 built and ran every way. Six are `real/eff`, left out as mtl benchmarks, and 14 failed to build or run.

**Result** (`results/E6/e6.summary.txt`). Median ratio to `-O2`:

| Way | All 75: instructions | allocation | nhc98 snapshot, 29: instructions | 47 large programs E8 accepts: instructions | allocation |
|---|---:|---:|---:|---:|---:|
| Own modules' pragmas omitted | 1.04 | 1.02 | 1.04 | 1.04 | 1.01 |
| All pragmas ignored, libraries too | 2.00 | 1.72 | 1.65 | 2.16 | 2.03 |
| `-O0` | 2.19 | 1.98 | 1.90 | 2.47 | 2.21 |

"Large" is at least 10^8 instructions at `-O2`, so that start-up does not hide the ratio. With own pragmas omitted, 19 of 75 programs exceed 1.10 and 4 exceed 1.50; the nhc98 snapshot's maximum is 1.59. Totals are worse than medians, 1.44 times in instructions, because two 2019 programs dominate: `real/fulsom` at 33.19 and `real/bspt` at 14.24.

**What would have flipped it.** The plan: little difference defers unfoldings. It split. A program's own unfoldings make little difference, so they can leave HsIface at first. Library unfoldings are worth about a factor of 2, so the Prelude's must not be lost: D44 keeps them from the start.

**Not established.**
- This is GHC's optimiser. It says nothing until rhc has a Core optimiser.
- The omit flag also drops arity and strictness, so it is a harsher test than unfoldings alone; and the brief's case, where libraries keep theirs, understates what ignoring costs.
- `real/fulsom` and `real/bspt` are unexplained. O suspects the repetition harness interacting with floating [inferred, untested].

### E7. The oracles

**Question.** Can Hugs, nhc98 and MicroHs be built, and do any of them judge Haskell 98 better than GHC does? **Settles:** D52.

**How.** Agent O, under `oracles/` in the drafts, from read-only copies (`results/E7/build-oracles.sh`, `build-nhc98.sh`).
- **Hugs** builds unmodified.
- **nhc98 v1.22** builds 32-bit from its `.hc` files under gcc 13 only with `-O1 -m32 -fno-pie -no-pie -fno-strict-aliasing -fcommon` (`nhc98-flags.txt`): without the PIE flags its binaries segfault, and `-O3` gives wrong results. Which of `-O1` and `-fno-strict-aliasing` cures the second was not separated.
- **MicroHs** builds, with no Haskell 98 mode, n+k patterns or datatype contexts: a smoke oracle, left out of E8.
- **GHC 9.4.7** runs through the package `oracles/ghc-shim`, which replaces the Prelude and hides every non-Report module. O reports its export list equals Hugs's apart from `(:)`; that was not rechecked here.

The 82 tests of `conformance98` and yhc's extras ran on all four (`conformance.py`).

**Result** (`results/E7/summary.txt`). `ok?` built and ran with nothing to compare. A `reject` may be right: some tests expect failure.

| Oracle | ok | ok? | accept | diff | reject | rtfail | timeout |
|---|---:|---:|---:|---:|---:|---:|---:|
| GHC, strict shim | 36 | 3 | 2 | 6 | 34 | 1 | 0 |
| Hugs `+98` | 30 | 2 | 2 | 13 | 33 | 2 | 0 |
| nhc98 `-98` | 54 | 2 | 0 | 2 | 20 | 3 | 1 |
| MicroHs | 35 | 3 | 2 | 7 | 33 | 2 | 0 |

48 tests disagree (`disagreements.tsv`, with O's class and note on each): 20 hard, 16 not Haskell 98, 7 oracle gaps, 5 environment. The 20 hard rows, grouped here; `Enum/succ` is in both suites, so two rows are one program:

| Rows | Tests | What disagrees | Reading |
|---:|---|---|---|
| 6 | `Enum/succ` twice, `numbers/floatdouble`, `numbers/integerdouble`, `numbers/subtract`, `parsing/rational_lits` | Hugs's `show` of a floating number: digits and form | none yet |
| 3 | `fields/operator`, `fields/showread`, `fields/type` | Derived record `Show`: nhc98 `Hash{(#)=3}`, the rest `Hash {(#) = 3}` | R41 |
| 2 | `infix/minus`, `listindex` | `3 * -4`, `xs !! -1`: GHC and MicroHs reject, Hugs and nhc98 accept | R10 |
| 1 | `numbers/negliteral` | `-2::N` on a user `Num`: GHC, nhc98 `Negate (FromInteger 2)`; Hugs, MicroHs `FromInteger (-2)` | R10 |
| 1 | `Array/timeLargeArray` | GHC 9.4 reads `(!1)` as a bang pattern in every mode; Hugs resolves a top-level restricted binding early | R20 |
| 1 | `read/1x23` | `(Show a, Read a)`: nhc98 defaults it, the rest refuse it as ambiguous | R22 |
| 1 | `layout/do` | `f a b = do a == b`: Hugs requires a monadic type | none yet |
| 1 | `import/emptyprelude` | `import Prelude ()` then `:` and `()`: GHC and MicroHs accept, Hugs and nhc98 refuse | R32 |
| 1 | `import/specialchar` | `import Prelude([](..))`: no oracle accepts it, and the manifest expects it to compile | R34 |
| 1 | `infix/derived` | Derived `Read`, infix constructor: nhc98 exhausts its heap or its time | R43 |
| 2 | `ctxsimpl`, `identifiers/twiddle` | nhc98 refuses code the others accept | none needed |

Hugs is not the better judge alone. Of the 721 expected-fail candidates outside helium and hse, nhc98 accepts 121, Hugs 32, GHC 11 (`results/E8/summary.txt`). But 30 corpus programs are rejected by Hugs alone (`-GN`, E8). The smallest case, top-level restriction resolved early, was run (`results/E7/hard/mr/`): Hugs refuses, GHC and nhc98 print 61. Those O read are this case; the rest are [inferred]. nhc98's `hmakerr` files and recorded outputs state nhc98's behaviour, not legality (`read/1x23`, `identifiers/twiddle`).

**What would have flipped it.** The plan: if only GHC ran, expectations would rest on the Report alone. All ran, so it did not flip. The result is D52's: GHC-strict plus Hugs as judges, nhc98 third. Twenty hard disagreements in 82 tests also mean a vote decides nothing: a disagreement yields a reading.

**Not established.** No verdict here says which oracle is right. MicroHs's verdicts are smoke. GHC's source tree here is 9.14.1 while the binary is 9.4.7, so a citation of the source may not describe the binary. Hugs is run in `+98`, whose tolerance of tabs in strings and of `then` at the `do` column E10 records.

### E8. The corpus

**Question.** Which programs are Haskell 98, exactly, on oracles rather than by grep? **Settles:** the accept, reject and run lists of D52, what "clean" means, and D56's numbers.

**How.** Agent O judged each candidate under GHC strict, Hugs `+98` and nhc98 `-98`, load or compile only with no linking, after blanking pragmas and expanding CPP where needed (`results/E8/judge.py`, `classify.py`). A candidate that failed was retried with import rewrites, the compat layer, shims, and extension modes, which gives its `needs`. Then every program with an expected output was run (`runset.py`). Harness errors: 0.

**Result: the candidates** (`results/E8/summary.txt`). "Accepted" is needs nothing, an import rewrite or the compat layer.

| Set | Candidates | Duplicates | Oracles accepting: 3 | 2 | 1 | 0 | Accepted | Lines |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| nhc98 nofib | 77 | 0 | 59 | 9 | 3 | 6 | 71 | 60,234 |
| nofib 2019 | 168 | 2 | 84 | 16 | 14 | 54 | 106 | 81,011 |
| `conformance98` | 67 | 0 | 36 | 5 | 13 | 13 | 44 | 399 |
| yhc's conformance | 15 | 0 | 10 | 0 | 3 | 2 | 10 | 98 |
| GHC legacy tests | 952 | 6 | 244 | 80 | 85 | 543 | 391 | 6,087 |
| jhc | 616 | 234 | 173 | 44 | 44 | 355 | 251 | 4,070 |
| helium | 813 | 44 | 171 | 50 | 141 | 451 | 362 | 4,988 |
| UHC `99` | 155 | 0 | 53 | 18 | 24 | 60 | 72 | 1,506 |
| haskell-src-exts | 226 | 0 | 19 | 25 | 7 | 175 | 50 | 277 |
| **All** | **3,089** | **286** | **849** | **247** | **334** | **1,659** | **1,357** | |

| Needs (`judged.tsv`) | Candidates |
|---|---:|
| nothing | 1,217 |
| import rewrite | 64 |
| compat module | 76 |
| shim | 84 |
| extension | 424 |
| none: rejected everywhere | 1,224 |

`accept.tsv` has 1,441 rows, the first four lines above, and `reject.tsv` 1,648, the last two. Reject rows by kind (`classify.py`, `summary.txt`):

| Kind | What it means | Rows |
|---|---|---:|
| `illegal` | the suite expects failure; refused in every mode | 872 |
| `illegal-in-h98` | the suite expects failure; refused in Haskell 98 mode, accepted with an extension | 59 |
| `extension` | the suite expects a compile; accepted only with an extension | 365 |
| `unjudged` | the suite expects a compile; no mode accepts; cause unexamined | 352 |

Of the 931 illegal rows, 857 rest on a static error, 49 on a missing import under some oracle and 25 under all.

**What beliefs it tested:**
- `nhc98/tests/nofib`: 65 of 77 by grep, 71 by oracle (66 need nothing, 5 of those with CPP). 59 pass all three.
- The 2019 nofib: 29 of 168 by grep with import rewrites, 30 by oracle (3 need nothing, 27 a rewrite). A 144-line Haskell 98 layer (`results/E8/compat/`: `pure`, `<$>`, `replicateM_`, `forM_`, `foldl'`, `NofibUtils`, bit operations) adds 76: 106 of the 131 sequential programs. The obstacle is the benchmark harness, not the programs.
- `nhc98/src/compiler98`: 32k lines by the first count. Its closure is 109 files, 24,186 lines (`compiler98/judge.out`), with no cycle. It imports `Data.Map`, `Data.Set`, `Data.PackedString`, `System.FilePath`, `System.Console.GetOpt`, `Debug.Trace` and an FFI wrapper; one file needs CPP; 33 of its modules have dotted names, outside `modid`. nhc98 `-98` compiled it with its packages (rc 0, all 108 modules, one `ld -r` step failing, `results/E8/compiler98/nhc98-98.log:22`). Hugs `+98` fails on library loading.

**Where GHC strict refuses and Hugs accepts, with no expected failure:** 210 programs (`judged.tsv`).

| GHC's rejection | Programs |
|---|---:|
| no `main` | 114 |
| a non-Report module | 42 |
| other | 41 |
| `@` or `!` whitespace | 7 |
| prefix minus | 2 |
| `Num` superclass | 2 |
| `Applicative` | 1 |
| instance clash | 1 |

**Suites' own expectations do not stand alone.** Of helium's 431 expected rejections, all three oracles accept 34 and two accept 28 (`summary.txt`). Recounted from `accept.tsv`: 240 candidates a suite expected to fail are accepted by at least one oracle, and 49 by both judges.

**Shape** (`summary.txt`). Multi-module programs: 38 in the nhc98 tree, 73 in the 2019 tree. Literate: 22 and 30.

**Mutual recursion.** No candidate has a plain import cycle (`cycle` is false on all 3,089 rows of `judged.tsv`). Seven use `{-# SOURCE #-}` in GHC's style: on the `.hs-boot` retest Hugs refuses all seven, nhc98 accepts none, and GHC accepts only `rn017`. So recursive modules have no independent oracle.

**The `-lazy` ports** (`lazy-ports.summary.txt`, `lazy-ports-corpus.summary.txt`). Pinned to nofib b7391df, which is absent locally. Of the 105 with upstream kept, against the 2019 tree: 46 the same (8 differing in imports only), 35 edited (mean similarity 0.94), 24 partly or wholly absent. Against the nhc98 snapshot: 1 the same. So they are the same programs, not the same texts. 108 of 115 map to an accepted program.

**The run set** (`run.tsv`, `run.summary.txt`). 283 programs have inputs and expected output. 223 are right under `ghc -O0`, with exit 0: `conformance98` 27, yhc 10, GHC legacy 32, jhc 16, nhc98 nofib 56, nofib 2019 82. 123 are right on all three oracles. Total cost under `ghc -O0`: 191.8 s CPU, median 0.10 s, maximum 31.0 s, at load 30 to 40, so the seconds are indications. Instructions: 4.519e11.

| At most, under `ghc -O0` | Programs | CPU seconds | Lines |
|---:|---:|---:|---:|
| 0.1 s | 112 | 1.2 | 18,321 |
| 1 s | 188 | 36.4 | 52,064 |
| 60 s, all | 223 | 191.8 | 70,031 |

**What would have flipped it.** The plan set no flip. The result that changes the plan is the corpus: the best one is `nhc98/tests/nofib`, not the tree the owner left, though the 2019 tree is usable through the compat layer.

**Not established.**
- Clause truth: no reject row is checked against the Report.
- Judgements are load or compile only, so a link-time failure passes.
- The 352 unjudged rows.
- haskell-src-exts goldens are parse-level only.
- `real/mkhprog` is unresolved under the compat layer.
- nhc98's output differences on the 2019 tree: 32-bit `Int` in hashes is suspected [inferred]. 19 of the 223 run programs print a wrapping 64-bit hash, and 13 of those have nhc98 and Hugs both differing, which fits (D22, `results/V2/hash/`).
- The 7 `@` and `!` rows, and four named programs in E10, are GHC 9.4's deviation, not illegality.
- Licences of the candidates were not surveyed.

### E9. The Report

**Question.** What does the Report require, clause by clause, and where is it wrong, contradictory or ambiguous? **Settles:** D38, D53, the seed of D32 and D37; the detail is in *What the Report says*.

**How.** Agent R fetched the online Report on 2026-11-01 into `downloads/report/`, enumerated its clauses into `results/E9/clauses.tsv` (2,648 rows by hand in `parts/`, 1,253 generated), wrote the readings and the translations, and extracted the libraries mechanically into `report-libs/`. No compiler was run; every statement about an implementation is [read].

**Result** (`counts.tsv`, recounted from `clauses.tsv`). 3,901 rows, every id unique and each obeying `docchecks.sml`'s rule (`tests/runner/docchecks.sml:21-22`):

| Test class | accept | reject | run | none, with a reason |
|---|---:|---:|---:|---:|
| Rows | 1,379 | 548 | 1,854 | 120 |

- 54 readings, R1-R54 (`readings.md`). `check_readings.py`, rerun for this roadmap: 99 quotations, 0 not found; 178 row ids named, none unknown; 177 rows pointing to a reading, all answered.
- The online text is December 2002 with no erratum applied: 16 of 18 errata confirmed unapplied, 1 unverified, 1 about the printed index (`errata-status.tsv`).
- 20 modules and 52 examples extracted (`report-libs/MANIFEST.tsv`).

**What would have flipped it.** The plan set none. The size did what a flip would: a table 20 times the 200 rows of `docs/language.md` cannot be kept by hand, so D53 generates it [inferred].

**Not established.** The accept, reject and run classes are read from the text, not run. Hand rows were written by five forks of one agent and validated by script; 12 were sampled by eye. R15, R21 and part of R38 are marked for the owner. GHC's source here is 9.14.1, the binary 9.4.7. One erratum is unverified.

### E10. Lexer, layout and parser

**Question.** How often does `parse-error(t)` fire, which parser technique survives it, and what does a front end cost per construct? **Settles:** D27, D28; a measured start for the size of track F.

**How.** Agent F wrote a lexer, layout algorithm, AST, parser and printer in SML (`results/E10/spike/`) and ran them over the corpus, 2,338 files with GHC's checks. **Technique A** is hand-written recursive descent pulling layout a token at a time, where a block that sees neither `;` nor its close takes the implicit close (`closeImplicit`, 22 lines, plus one call in `block`). Operators stay flat, so fixity is never consulted (R1). **Technique B** is bison's automaton for a Report grammar, driven in SML as Note 5 words it: no action on t and an action on `}`, so close. **S1** is a rule on tokens alone. All share one layout engine. GHC's `-ddump-parsed` is an independent check of the printed output (`ghc_check.py`).

**Result: the corpus** (`summary.txt`).

| Set | Files | Strict Haskell 98 | With dotted modules | With CPP | Refused |
|---|---:|---:|---:|---:|---:|
| nhc98 nofib | 423 | 402 | 402 | 418 | 5 |
| nofib | 590 | 268 | 510 | 544 | 46 |
| `conformance98` | 98 | 76 | 82 | 83 | 15 |
| jhc `0_parse` | 62 | 47 | 47 | 47 | 15 |
| GHC parser, positive | 192 | 88 | 96 | 97 | 95 |
| nhc98's compiler | 147 | 23 | 144 | 145 | 2 |

Refusals (`refused.tsv`, 445 rows, classes in `refused-summary.txt`): extensions and the Report's own holes, with none left that is the spike's fault as far as read. GHC's parser accepted 358 files the spike refused (`ghc/final.tsv`, `triage-final.tsv`). F read the 19 of those in nofib and nhc98 by hand, all extensions, and the rest by their error lines. Of `conformance98`'s 15: 7 expected failures, 3 illegal import or export forms, 5 `foreign`. The 318 files both refuse are classed by regex, unread. On `should_fail`, the spike accepts 46 of 223 (`neg-accepted.txt`); by GHC's expected errors none is a syntax violation, and 2 await a fixity pass.

**`parse-error(t)`** (`closes-hier.txt`) fired 371 times in 165 of 1,670 files, 961,535 tokens.

| Block closed | by | Firings |
|---|---|---:|
| `let` | `in` | 200 |
| `of` | `)` | 103 |
| `do` | `)` | 23 |
| `do` | `where` | 15 |
| `let` | `]` | 11 |
| `let` | `,` | 8 |
| others | | 11 |

Five of the 200 sit inside a `do`. It never fired on `then`, `else`, `of`, `|` or `}`. Variants (`summary.txt`, on 1,616 parsed files of the positive corpus):
- no rule at all: loses 160 files;
- R2's strict Note 3: loses 0, so no file needs it;
- NondecreasingIndentation: gains 3, one real (`nofib/gc/happy/ProduceCode.lhs`).

**Techniques.** A and B made the same layout decisions on all 1,723 files both accepted, LALR(1) and canonical LR(1) alike. B refused nothing A accepted; B alone accepted 90, being a recogniser without A's checks.

| | A | B, LALR(1) | B, canonical | S1 |
|---|---|---|---|---|
| Lines beyond the shared engine | 22 | 109 driver, 146 grammar | same | 201 |
| Tables | none | 176,122 bytes, 475 states | 1,807,750 bytes, 4,933 states | none |
| VM instructions per token | 560.5, with AST | 1,262.9, no AST | not measured | not measured |
| Files that differ from A, of 1,723 | | 0 | 0 | 0 |
| Crafted cases right, of 46 | 46 | 46 | not run | 37: refuses 9 of 36 legal |
| Needs in the bootstrap | nothing | bison | bison | nothing |

Rune's own lexer and parser cost 434.6 per token (`speed.tsv`). A's lexer is 400.2 of its 560.5. At tier 2 both run about 770k tokens/s at load about 25, an indication only. S1 also needed `let`/`in` pairing and four fixes while it was written. It tracks the grammar badly and buys nothing.

The 46 crafted cases and their expected results are F's own (`cases/cases.tsv`). No oracle matches all of them: GHC 39, Hugs 38, nhc98 36, MicroHs 35.

**Independent check.** Of 1,624 files GHC and the spike both parse, GHC's dump of the spike's explicit-brace print equals that of the source on 1,577 (`ghc/final.tsv`). The other 47: 28 white space or pragmas only, 14 `@` or `!` spacing, 3 NumericUnderscores, 1 UNPACK, 1 F's harness (`ghc/dump-diffs-kinds.txt`). None is a layout decision.

**Round trip.** 1,723 files, 0 tree failures, 0 token failures. Tree: parse, print, parse, compare with locations erased. Token: the tokens of the print equal `L` of the source, modulo empty items and a trailing comma. Mutants of 1,616 parsed files (`mutants.tsv`), `mutants.sh` seeding each:

| Mutant | Tree test fails | Token test fails |
|---|---:|---:|
| none | 0 | 0 |
| printer drops parentheses | 1,120 | 1,120 |
| printer drops `deriving` | 183 | 183 |
| printer swaps `if` branches | 538 | 538 |
| parser drops `where` on an `=` right-hand side | 0 | 743 |
| parser drops a signature's context | 0 | 227 |
| parser drops `deriving` | 0 | 184 |
| parser drops a fixity's precedence | 0 | 91 |
| parser drops `~` from patterns | 0 | 9 |
| parser drops parentheses | 1,076 | 1,120 |
| parser swaps `if` branches | 538 | 538 |
| parser and printer both swap `if` | 0 | 0 |

A dropped AST field passes the tree test on every file, since both sides lost it. Only the token test sees it. The last row passes both: only running programs catch a compensating pair.

**Size** (`loc.tsv`).

| Component | Lines |
|---|---:|
| Tokens | 72 |
| Lexer and literate | 476 |
| Layout | 203 |
| AST | 112 |
| Parser | 1,344 |
| **Front end proper** | **2,207** (2,003 code) |
| Printer | 258 |
| Driver and tests | 306 |
| Generated Unicode tables | 348 |

Rune's SML front end is 2,511 lines. That is 8.2 parser lines, or 13.5 lines all told, per production of 9.5's 163. Against Haskell doing the same job [read]: nhc98's `Parse/` 2,408, ratio 0.92; MicroHs's Lex and Parse 1,703, ratio 1.30. F's estimates past the parser, none measured: renamer through match compilation 7-14k lines of SML, HsLint and CoreLint about 3k from AstLint's 1,957 and MidLint's 457, through Core about 12-20k lines.

**What would have flipped it.** The plan set none. D27 would have gone to an automaton if `closeImplicit` and the automaton had disagreed on a file, or if a legal crafted case had needed the grammar's error rule in a way the block rule could not see. They agreed on all 1,723 and all 46.

**Not established.**
- There is no fixity pass, so R1, R9 and R10's refusals are deferred, not run. `do a == b == c` parses flat; all four oracles refuse it.
- Tree shape is checked only by GHC's dump.
- Diagnostics were not assessed.
- B has no AST, so its line count is not a full comparison.

**Handed to E9's readings and E8** (F's report, cases in `cases/`): `M.keyword` is refused by all four oracles though 2.4 accepts it (R7); `f = x where` then `{ x = 1 }` at column 1 gets `;` from `L`, accepted by GHC and nhc98, refused by Hugs, MicroHs and the spike; R2 settled by test, GHC, Hugs and MicroHs accepting and nhc98 refusing; GHC 9.4.7 `-XHaskell98` is no oracle for spacing of `@`, `~`, `!`.

### E11. Pipeline as data

**Question.** Can the pass list, stamps, labels, targets and literals be pulled apart with Rune's bytes unchanged, and does that collide with build-system-v2? **Settles:** D39, D40, D41, D7's `Try` and `Fail`; the order of track A against v2.

**How.** Agent A, in `.worktrees/hs-arch`: eleven patches (`patches/E11-*.patch`). A literal "fixed point byte-identical to hs-base's `bin/rune.rbc`" cannot hold, since edited sources make a different compiler image. What was tested on each patch is what the claim means (`results/E11/verify.sh`, `verify-summary.txt`): stage1 equals stage2; the edited compiler on hs-base's unedited sources makes hs-base's `bin/rune.rbc`; the same at stack, `-O0` and `-O2` on both targets. Suites ran directly, never through make (`suite.sh`). A planted wrong `.expected` was caught.

**Result.** Bytes held on every patch and on `all-but-10` (`verify-summary.txt`: 12 of 12 lines). Sizes are `lib` and `src` only (`sizes.tsv`).

| Patch | Change | Files | + | - | Grade |
|---|---|---:|---:|---:|---|
| 1 | `Stamp`, `util/stamp.sml` | 16 | 30 | 20 | small |
| 2 | `Target` passed to Lift and Workers | 5 | 13 | 17 | small |
| 3 | Counters register where they live; `Env.inlinedValue` set in `startSession` | 8 | 21 | 17 | small |
| 4 | Pass list as data | 1 | 50 | 16 | small |
| 5 | `label` on `fundef` | 17 | 158 | 193 | medium |
| 6 | Simplify and Lower take their options | 5 | 49 | 14 | small |
| 7 | `backend/results.sml`, the analysis, a move | 3 | 470 | 454 | small |
| 8 | `driver/midpipeline.sml`, a move | 3 | 187 | 167 | small |
| 9 | `Literal`, `Ty.constAt` | 22 | 147 | 137 | small |
| 10 | MatchComp stops making `Try`, `Fail` | 1 | 22 | 6 | small |
| 11 | Root names after 7 and 8 | 2 | 17 | 17 | fix |
| | **All** | **42** | **1,073** | **967** | |

| Tree | Jobs | Failing | File |
|---|---:|---:|---|
| Unedited | 409 | 0 | `base.jobs` |
| Patches 1-8 | 409 | 0 | `8-layer.jobs` |
| All | 499: 371 levels, 38 ir, 90 faults | 4 | `final.jobs` |
| All but patch 10 | 128: 38 ir, 90 faults | 0 | `no-try.jobs` |

The four are expected Lambda dumps under `--dump-after=translate`, `(try` becoming `(join` (`ir-try-diff.txt`). So patch 10 holds bytes and not `rune-test run ir`: D7 records four dumps to review. `levels` was not rerun on the all-but-10 tree.

In units, the compiler's sources gave the same program, with cache files identical and only the list of paths differing among unit files (`units/11-final/`). The compiler's own compile falls 0.81% in instructions and 0.64% in allocation (`compile-cost.txt`, measured at patch 10).

**A client that is not Main.** `tests/compiler/mid-client.sml` in the prototype takes Mid text to bytecode through an edited pass list, built from `mid-only.build`, 48 of the 80 files after the patches (master has 76; four are new), with no lexer, parser, elaborator, Translate, ToMid or Expand (`contract.md`). It writes the same bytes as the client on the whole of `internal.build` (`cmp` of `client/none.rbc` and `mo-none.rbc`, rerun). Removing `workers` and `refs` takes the program's allocation from 304 bytes to 87,091,544 (`runevm --count` of `client/mo-none.rbc` and `mo-remove.rbc`, rerun): the swap is real.

**Hidden passes** (`variants.tsv`, against the control).
- `results`: the analysis splits (patch 7). The lowering half cannot, because `Slot` is Low.
- `inline`, `specialise`: no. They are woven into Simplify's rounds. Options are now explicit and order is one line, but bytes move: `inline-second` +6.0% size, -1.4% instructions; `inline-then-shrink` -0.2% size. A real separation was not tried.
- `equality`: no [read]. It needs inlining's types.
- `trees`: no. It is a strategy of translate, with no IR to run on.

**What would have flipped it.** The plan: bytes move, or the diff collides with v2's M-series. Neither did. No M3-M7 Touches list names `pipeline.sml`, E11 changes nothing in `main.sml` (E1's `readMid` patch does, +14 -2), and the seven places it shares with v2's milestones (`unitbasis.sml`, `unitmid.sml`, `midcodec.sml`, `elaborate.sml`, `link.sml`, `unitfile.sml`, `api/`) overlap in lines that force no order. Patches 5 and 9 before v2's M5 are cheaper, as M5's generated codec must carry them.

**Not established.**
- Not run: `make check`, any host build, `check-units`, `check-docs`, the compiler mutants.
- Stale after the patches: `docs/ir.md`, `tests/runner/compilermutantlist.sml`, which names `lower.sml` where code moved; the `Try` and `Fail` constructors stay in the datatype though nothing makes them.
- `Target.intBits` stays global, and `Lower.shapesChecked`, `MatchComp.noteLocal`, `Overload.used` and others still wire at load.
- MidText carries no label, so a function read from text is `fn`.

**Defect on master.** `--passes=nosuchpass` is accepted and silently runs no optional pass; `--dump-after=nosuchpass` prints nothing (`results/defects/passes-unknown-name/`).

### E12. The IR census

**Question.** Does each IR hold what it should, and what would `Case` and multi-value return buy? **Settles:** D7, D8, D9, D10. The detail is in *The IRs, reviewed*.

**How.** Agent A, every constructor of every IR with its makers, consumers and lint rules (`results/E12/census.py`, verdicts by hand), walker shapes by heuristic, the compiler compiling itself at `-O1` as one workload (`dumps/`), each pass left out in turn (`passes.sh`), and 17 of 22 numerical benchmarks for two attacks on tuples.

**Result** (`census.tsv`, 202 rows counting 3 proposed; `review.md`).

| IR | Constructors | Keep | Move | Drop |
|---|---:|---:|---:|---|
| Lambda | 39 | 30 | 7 (`const`) | 2 (`Try`, `Fail`) |
| Mid | 31 | 31 | | |
| Low | 47 | 47 | | |
| Stack bytecode | 41 | 40 | | 1 (`HALT`) |
| Register bytecode | 41 | 40 | | 1 (`HALT`) |

- **Walkers** (`walker-defaults.tsv`, `walker-shapes.tsv`; lower bounds): 88 over `exp`, 38 over `rhs`. 25 `rhs` walkers reduce to `atomsOfRhs`, 12 to `mapRhs`. 28 of the 38 end in a catch-all, so a new step falls through silently.
- **`Case`** (`mid-stats.rune.O1.tsv`, `low-stats.rune.O1.tsv`): 12,064 tag tests, 58.4% of 20,662 `If`s; 12,061 are recovered in Low, and 472 of 484 long chains become `Switch` (parsed: `low-stats.rune.O1.tsv`'s own counts are substrings that also hit the printer's strings); only 31 are answered by a dominating test. `Case` buys compile time and clarity, not code.
- **Each pass left out** (`passes.tsv`; every such compiler still compiles itself to the same bytes), instructions on the compiler: `simplify` +63.4%, `workers` +24.7%, `inline` +14.6%, `lift` +13.6%, `trees` +6.6%, `specialise` +5.4%, `expand` +4.8%, `refs` 0, `shake` 0 with +52% size.
- **Tuples, turned off, on the compiler** (`results/E11/variants.tsv`, `passes.tsv`): virtuals +31.85% instructions, +232.6% allocation; workers +24.7%, +154.6%; results in globals -0.76%, +4.4%; `flattenJoin` about 0, +0.17%. On the 17 benchmarks (`bench-summary.tsv`, `bench-attacks.tsv`) turning `results` off raises allocation by up to 45.09% on `nucleic-smlnj`, so it saves 31% there (62,028,808 against 89,994,912 bytes); turning `flattenJoin` off raises it by 241.24% on 40,520 bytes (`fft-smlnj`) and 9.26% on `mandelbrot-rat`.

**What would have flipped it.** The plan set none. A `Case` that saved code would have raised D8 above medium; it saves none.

**Not established.** Census, `Case` and walker figures are one workload. `Case` is static only: no compile with it was made. 5 of 22 benchmarks did not run. Dynamic instruction use was not looked at here.

### E13. The store split

**Question.** Can Rune's separate-compilation cache serve rhc: as is, generalised, or not at all? What must a cache hit satisfy for Haskell? **Settles:** D43, D44, D45, D46; M20 to M22; what rhc asks of v2.

**How.** Agent C, in `.worktrees/hs-cache`. `unitcache.sml` split into a store, opaque sections (`'a format`) and a `holds` callback (`patches/E13-1-store.patch`). A toy language over Mid text, with import discovery and one SCC, driven through it, calling no `UnitBasis`, with `Link`, `UnitFile` and `Usage` unchanged (`E13-2-toy.patch`). A model of what a hit must satisfy, exhaustive over its projects (`results/E13/model/`, 293 lines). S41 below is v2's claim that a warm build equals a cold one.

**Result: the three options.**

| Option | Rune lines | Result |
|---|---|---|
| As is | 0 | Works with empty usages and a key folding whole interfaces and the instance closure. Warm equals cold; 40 units compiled against 29 over 26 edits (`toy/p9-sum.out`). No per-entity cut-off. A stopgap at most. |
| **Generalise** | +338 -231, 3 files (`split/tier.out`) | Recommended. |
| Wholly apart | 0 | About 1,560 lines: the store's 264, plus v2's M7 (about 600) and M2 (about 700) again [inferred]. Misses frozen layers, dist, M6 and later cache fixes. |

`UnitStore` is 264 lines; `UnitCache` falls from 437 to 279. rhc's interface, usages and driver are its own under all three. There are seven welds between the store and SML, not three: also the hash, the lint gate, `remapAllowed`, `RegVerify.injecting` [read].

**Rune unchanged** (`split/`):
- Fixed point: stage1 equals stage2; hs-base's sources give `bin/rune.rbc` and five variants byte for byte (`verify.out`).
- `rune.build`, no frozen layer: 494 unit files, 493 cache files, 0 differ; each compiler compiles 0 of 246 on the other's store (`units2.out`).
- 371 programs, both targets: 0 differ, 1,760 cache files the same (`programs.out`).
- `units-one`: 371 of 371 (`tier-units.jobs`, 178 passes; `tier-units2.jobs`, the 193 rerun after a setup call of C's failed).
- `tests/units`: 32 of 32 (`tier-tests-units.jobs`; its other 8 are jobs wrongly scheduled for fixtures expected to refuse). Incremental scenarios: 0 FAIL (`tier-incremental.out`), REPL not rebuilt.

**"A clear improvement for Rune" overstates it alone.** Net +107 lines, and the warm count flat: 1,063,193,748 to 1,063,190,918 instructions (`units2.out`). It pays with v2's M6 and M7: 130 of E15-warm's 138 `unitcache.sml` additions name no `UnitBasis` (`v2/patches.out`), and the store tests with no compiler (`split/storetest/`).

**The toy, observed** (`toy/p1.out` to `p9`):

| Case | Outcome |
|---|---|
| A body edit | Base compiled alone, identity unchanged |
| A type edit used by one client | 2 of 5 units compiled |
| A new instance two imports away, on no list | moves a default; Orphan and Main compile. With the absent read dropped, warm prints 7 and cold `mine`: S41 broken, as it should be |
| A cycle | key and identity over both; a body edit compiles the unit, clients untouched; a recursive type group hashes as one |
| An SCC splits | clients compile once |
| A frozen 11-module unit, the Report's graph, toy bodies | 20 modules, 10 entries, the layer unwritten; hello compiles 1 module, bytes equal from-source. A body edit recompiles no client; a type edit, only the user; importing a hidden member is refused; an instance in a hidden member moves a client's default |

**One unit per SCC against the alternatives** (`toy/p5.out`, `p6.out`; VM instructions, toy compiler).

| Edit | One unit | Alternative |
|---|---|---|
| 5-ring, a body | 5 modules, 1.90M | 5.7 signature: 1 module, 0.89M |
| 5-ring, a type used only inside | 5 | 5.7 signature: 2 |
| The Report's 11, the body of Numeric | 11 modules, 52.1M | layered: 1 module, 20.1M |

Refusing cycles saves about 45 lines of the toy's driver, of its 766 [inferred]; 5.7 costs about 12 plus hand-kept signatures, and a value through one is an internal error (`backend/link.sml:202`), needing forward links, unbuilt.

**What a hit must satisfy.** v2's claim, with E the import closure now and not a prefix. Its O1, O3, O7 carry; O6, O8, O9 fall away [inferred]; O2 grows. The model (`model/output.txt`) runs every single-module edit of its projects: 15,750 edits, of which 8,652 are refused cold and 3,150 fall in an SCC. Reading everything per name gives 0 wrong and 19,960 rebuilt; one hash of all imports gives 0 wrong and 23,128 rebuilt. Each hole is one obligation dropped.

| | A usage or the driver must cover | Hole in the model | Wrong of 15,750 |
|---|---|---|---:|
| H1 | Each name looked up, absent too (5.5.2); each import-list item | a name absent from imports not read | 81 |
| H2 | Each (class, type) looked up, absent too, through the closure (5.4) | an absent instance not read | 26 |
| | | no instance read | 713 |
| | | instances of direct imports only | 298 |
| H3 | What a unit sees comes from the graph, never an entry; the driver refuses a second instance on hits | what a unit sees taken from its entry | 440 |
| H4 | `default` is in the key; its choice is H2's. GHC prints 5, then `MyNum!` (`ghc/m/run.out`) | counted in H2 | |
| H5 | An instance's fingerprint holds its context; derived contexts move with imports (`ghc/more/run.out`) | an instance's context not held | 80 |
| H6 | Fixity in the entity's fingerprint | a fixity not held | 36 |
| H7 | Entities by origin; `module M` reads all M's exports | a re-exported module's exports not read | 68 |
| H8 | SCC key over every member; fingerprints by recursive group; unit name in the usage | an SCC's key holds its first member | 97 |
| H9 | Prelude names in translations; ABI facts | unmodelled [inferred] | |

Bounded, not a proof. The model's first run caught H3, part of which was a real flaw in the toy. One instance per (class, type) makes that key exact; overlap would not [inferred].

**Until the split lands** (`toy/p8.out`, machine instructions, one module edited): 634M whole-program on the store, 583M on a saved world, 458M in units, 1,142M with nothing kept. A world image needs no interface codec, but runs only on the VM, at 5,560,282 bytes against the store's 185,590. Toy ratios, not rhc's: the toy has no front end.

**What v2 is asked** is in *What rhc asks of build-system-v2*. The split itself needs nothing from v2's M3: E16's `unitcache.sml` hunks equal E15's (`v2/patches.out`).

**Agent M's Mid unit.** Its usages are not recorded: a new unit shadowing a name gives warm `hello !` and cold `from lib2 hello` (`midunit/t/`: the kept programs, rerun while writing; `run.out` does not hold this). Parse runs after `Usage.record` ends [read]. Holding such a usage needs a `UnitBasis` session, hence D26: SML names stay in the frozen library unit [inferred]. Prototype only, not master.

**What would have flipped it.** The plan: sections cannot stay opaque. They stayed a type variable, so the store cannot look. One unit per SCC costs the store, `Link` and `UnitFile` nothing.

**Not established.** rhc's real interface size or compile times; link size or start-up of the 11-module unit; hold cost at scale; stack-compiler `units-stack`; instances across a 5.7 edge; the toy calling Basis units; loader jobs. Link numbers hashed by name need no remapping, with collisions unchecked.

**Defect on master.** `docs/units.md:637,704` name missing scripts (`results/defects/docs-units-runsh/`).

### E15. Literature and implementations

Agent I read the papers and the implementations for every decision. `results/E15/literature.md` has 193 references (35 read in full, 99 in sections, 44 by abstract, 15 from memory), `implementations.md` 40 rows over 10 implementations with 1,103 citations, each snippet checked against its line by `check_citations.py`; `papers-for-the-owner.md` lists 54 papers no reader could reach. 158 of 159 DOIs agree in Crossref, the other only by markup (`dois.tsv`). Eleven readers did the reading, audited by I on 24 random cells and on every claim that contradicts the plan. Of 43 claims checked in `haskell98-compatibility.md`, 38 were right, 1 wrong (haskell-src-exts defaults to Haskell 2010, not 98), 3 stale and 1 unverifiable (`impl/*.survey`). A few probes ran (`run/probes.tsv`, `run/probes2.txt`, timeout 20 s): only GHC passed `foldr` and `foldl` at 10^7, and the boot-file test of three signed, mutually dependent modules, refused by GHC 9.4.7 in both forms, compiles when joined (`run/boot3.txt`); that no arrangement exists is I's argument, not a result. What it changed is in *What the literature says* and *What the implementations do*. It settles nothing alone and bears on every decision; nothing could flip it, and what it did not establish is the unread list, topped by Faxén 2000, Augustsson 1993 and 1985 and Sparud 1993, with Programatica, jhc, UHC, Yhc and hbc read and not run.

### E16. The literal layout

**Question.** The Report prints its libraries as a module graph whose 11-module SCC is presentational. Taken literally on E10's parser over `results/E9/report-libs`: is the cycle real at the level of definitions, how large are the binding groups, what crosses a module, what do signatures cut, and what does one 11-module unit cost a small program? **Settles:** D36, D29, part of D30, G1's order.

**How.** Agent F ran the 20 modules with `...` forms made parsable (`results/E16/libs/`, 69 lines logged in `norm.tsv`), `prim*` and the like as leaves, through `hs_modules.sml` (fixpoint name resolution, 364 lines) and a definition graph. Without inference, instance use can only be bracketed, so F bracketed it and measured it: GHC typed the merged unit as one module with one annotation, and its Core gives **T**, the dictionaries actually used.

**Result: is the cycle real?** Mostly not.

| Graph (`analysis-1.txt`, `truth.txt`) | Cross-module recursive groups | Largest |
|---|---:|---:|
| E0, names only: a lower bound | 1 | 4 |
| T, GHC's resolved dictionaries | 4 | 20 |
| E1, class meets type: an estimate | 5 | 72 |
| E2, every instance: an upper bound | 5 | 187 |

E1 has 1,063 definition-to-instance edges: 172 true, 891 spurious, and it misses 24 of T's 196. T's reachable instances lie inside E2's, with 0 exceptions (`analysis-2.txt`), though 16 of T's direct edges are not in E2 as edges (`truth.txt`).

- **Among values there is no recursion across the top level at all:** 0 binding groups by 4.5.1, in any of the 20 modules (`analysis-2.txt`).
- **T's four groups** (`scc-T.tsv`): three are numeric dictionaries, of 20, 11 and 7 nodes, where `Show T` calls Numeric, which needs `Integral T` or `RealFloat T`, whose superclass chain reaches `Num T`, then `Show T`. One is types: `Real`, `Integral`, `Ratio`, `Rational`.
- **Single edges hold them** (`holds.txt`): `Show` as a superclass of `Num` holds the first three, and the data context on `Ratio` the fourth.
- **`import List((\\))` in `Array.hs` is dead:** nothing uses it. Without it, List and Maybe leave and the import SCC is 9, not 11.
- **With the Prelude family as one module**, as chapter 8's words allow, 26 definition edges break the cycle: Prelude to Ratio 4, to Char 8, to Numeric 11, Char to Numeric 3.
- **Moving `Show Float` and `Show Double` alone changes nothing.** It takes all numeric `Show`, all `Read`, `lex`, `words`, `Show Char`, the `Rational` edges and `readEsc` together. A layered layout must put 59 definitions, 329 lines, beneath the Prelude.

**Signatures** (`analysis-2.txt`). 7 of 311 values are unsigned: `arrPrec`, `asciiTab`, `protectEsc`, `maxExpt`, `minExpt`, `ratPrec`, `reduce`. None is exported, used from another module or in a cross-module group. All 887 cross-module value edges land on signed values (415) or methods (472). Instance bodies do not order inference, only instance heads [inferred], so given all signatures, class heads and instance heads of the unit, values check module by module in any order. The exception: the 4-node type group spans Prelude and Ratio, and Haskell 98 has no kind signature, so kind inference must cross that boundary (R28). GHC typed the unit after one annotation, at the only site it could not default, in `floatToDigits` (`ghc/changes.txt`).

**Names** (`resolve.txt`, `tests/`).
- The fixpoint exists: 4 rounds from empty, 3 from full, least equal to greatest, 683 pairs. `PreludeList`, `PreludeText` and `PreludeIO` re-export all of their 53, 17 and 18 names; Prelude exports 236.
- **Uniqueness is not general.** A user module defining `map` gives two fixpoints, 690 and 693 pairs (`tests/imp.out`); renaming it gives one (`tests/gfp.out`). `map` circulates between Prelude and PreludeList. Section 5 does not say which fixpoint. The rule must say least, as Diatchki, Jones and Hallgren do [read, by I]. `tests/cyc.out` shows the solver can answer no.
- **8 names do not resolve** (`ERR` lines of `graph.raw`): four in `interact` (R47), and the four `numericEnum*` in Ratio, which Prelude does not export. Section 5 has no remedy. One hidden module, moving 14 lines, fixes the second set (`overlay.py`, `overlay-resolve.txt`). Importing `IO` for `interact` would make the SCC 12 [deduced].
- Derived `Ix` in Time needs methods it did not import, so deriving must name entities. The 20 modules contain no `hiding`; `tests/imp` covers it.

**Additions.**
- "Cannot be imported" is a list of modules, checked in a few lines, refused outside the library (`tests/hidden.out`).
- By the 5.4 chain, all 112 instances reach every program through Prelude. 21 name a class or type Prelude does not export, so a program cannot observe them [inferred].
- `nhc98/tests/nofib/real/infer` has a user `module Maybe` (`collisions.txt`). The library's module of that name lies in Prelude's closure, so a module's identity must include its library. Dropping the dead import removes this one case; `Char` and `Numeric` stay exposed.
- `default`: 0 declarations in the 20 modules. The 5 restricted bindings are local to their modules.
- Fixity: 35 declarations. Of 260 uses needing fixity, 152 come from another module of the unit (`analysis-2.txt`). Fixity is an entity attribute read after names, with no iteration. `parse-error(t)` fired 8 times, on `in` and `)`, none depending on fixity (`closes.txt`).

**What one unit costs a program** (`analysis-2.txt`). The unit is 525 definitions, 1,436 lines of definitions, 2,436 file lines, 14,965 tokens (rerun on the spike); elided primitive bodies are not counted.

| Program | Reachable in T | Lines | Upper bound, E2 |
|---|---:|---:|---:|
| `putStrLn "hello"` | 19 (3%) | 34 | 24 |
| one `Char` function | 20 (3%) | 35 | 25 |
| `print 42` | 111 (21%) | 258 | 297 |
| `sort` | 113 (21%) | 264 | 299 |

**The layouts compared.**

| | The Report's graph | Internal plus thin | Layered |
|---|---|---|---|
| Front end | Fixpoint (needed anyway for D30), a unit-wide declaration pass, a hidden list | One module without implicit Prelude, a hidden list | A hidden list |
| Cache | SCC key, one unit | One unit, 11 thin | Several units |
| Dictionary recursion | Across modules | Inside one | In the bottom layer |
| Report's text | Unchanged, but 8 names need the overlay | Bodies and headers verbatim | 59 definitions move; bottom layer 1,720 of 2,436 lines |

`merge.py`, 47 lines, generates the second layout from the first, so a mechanical fallback exists if the first cannot be compiled in time (D36). None of the 369 names of the 11 modules collide. It changes 2 lines (`Char.isSpace`) and drops 22 import lines (`merge.log`). All 20 modules' 663 export pairs, 35 fixities and 164 instances are identical (`check_merge.txt`), and it resolves Ratio's four names on its own. It needs one rule outside the Report: the internal module has no implicit Prelude.

**The Programatica addendum.** E15 found a Report-layout library that passed a checker: Programatica's `tools/base/tests/HaskellLibraries`, in the HaRe 0.6 tar, 21 modules with an SCC of 12, the Report's 11 plus `PreludeBuiltin`. Did it add signatures or move definitions to get the cycle through? F classified all 111 diff hunks by hand against E9's text, each under its main class (`results/E16/programatica/classes-summary.tsv`, `hunks.txt`), over the 310 altered Report lines of E15's "1,201 of 1,511".

| Class | Hunks | Report lines altered |
|---|---:|---:|
| Older text: their copy predates the revisions | 26 | 78 |
| Primitives or `...` filled in | 21 | 73 |
| Export lists dropped, explicit `import Prelude` | 8 | 44 |
| The Report's bodies removed | 4 | 44 |
| Local rewrites, layout | 26 | 36 |
| Signatures commented out or absent | 14 | 19 |
| `default()` in Numeric and its annotation | 2 | 5 |
| `Rational` moved into Prelude | 2 | 4 |
| Illustrations made legal in their dialect | 3 | 3 |
| Instance contexts changed | 3 | 3 |
| Helpers for their derived-instance generator | 2 | 1 |

- **No change adds a signature to get the cycle through** (`sigs.txt`). 0 bindings unsigned in the Report gained one; 24 names the Report signs are unsigned there. Unsigned top-level values rise from 7 to 40. 16 cross-module edges inside the SCC land on unsigned bindings, 3 of them unsigned on unsigned. So their copy cannot be checked module by module, and relies on the join I read in `TiModule.hs`. The Report's own text needs no such thing: it has 0 such edges.
- **The one move across modules** is `type Rational` into Prelude, with a comment about how literals are typed. Their SCC stays at 12.
- **The one change touching the cycle's semantics is `default()`,** in Numeric only. `TiModule.hs` takes `default` from the joined declarations, so it switches defaulting off for all 12 modules [read]. Their copy then needs exactly one annotation, at the site GHC needed in `floatToDigits`, which jhc's copy has too (`jhc/lib/jhc/Numeric.hs:283`). Three sources agree that one expression in the cycle depends on defaulting, though Programatica's commented-out bodies mean its run covers less code than GHC's. R20's `default` in a cycle stays open for user cycles: Programatica rejects differing ones, jhc ignores them, and neither gives each module its own, which is what the Report says.
- **Uniqueness, amended.** "Prelude importing itself has no effect" holds on the Report's text only. On Programatica's copy, whose Prelude exports `module Prelude`, a literal self-import gives 792 against 1,181 pairs; without it the solution is unique at 792 (`resolve.txt`, `resolve-noself.txt`). So D29: the least fixpoint, and Prelude does not import itself.
- **`interact`'s 4 names** date from the "Late Dec 2001" revision in the bug list, and **`Array`'s dead import** is live in their older text (hunk 92). Programatica did not resolve `numericEnum*` either: it commented out `Enum (Ratio a)`.

**What would have flipped it.** The plan: definition-level groups that cross modules without signatures would make the literal layout a checker problem, not a scoping one. It did not flip: 0 cross-module binding groups, and every cross-module value edge lands on a signature. The literal layout is a scoping problem plus one unit-wide pass over declarations, with kind inference across Prelude and Ratio the one exception. The addendum qualifies the carry: module-by-module checking works on the Report's text, and a user cycle with unsigned bindings needs a joined SCC, as Programatica and jhc have, which is D30's recommendation.

**Not established.**
- T rests on GHC typing a patched copy: built-in types, `Bool` and `Ratio` from GHC, 21 derived stubs, 47 elided instance bodies, derived instances by F's chapter 10 table. GHC is not rhc.
- Whether dictionary recursion across modules needs thunks at link time [inferred: only if a unit is split].
- The layered layout was sized, not generated. Whether real primitive instances add edges.
- That Programatica's checker passes today: "passes" rests on its README [read], and it was not run. It has no back end, so the precedent says nothing of code generation or cost.
- Why its bodies, contexts and signatures changed: nothing in the tree says. Hunk classes are one reader's, mixed hunks count once, and older-text status is confirmed against the bug list for most of the 26, not all.

## Constraints

**From the brief:**
- rhc is a program separate from `rune`, written in Standard ML '97 and compiled by Rune. It is not written in Haskell.
- Its frontend lives in `lib/language/haskell` and may serve other tools; its driver in `src/rhc`; the Report's Prelude and libraries in `share/rhc/haskell98`, because `lib` holds only SML.
- rhc is second class in tools: no language server, REPL or runedoc. It is first class in conformance.
- **The language is Haskell 98 as per the Revised Report.** rhc follows it to the extent Rune follows the Definition: a deviation only where the Report is wrong, contradictory or ambiguous, always documented and pinned by a test (D38). What the Report leaves open is a choice, recorded as one (D53).
- **No silent changes to Rune.** Each change to Lambda, Mid, Low, a bytecode or the VM is a decision graded large, medium, small or none. *Every change to Rune* lists them.
- Haskell 2010, extensions and an HM(X) or OutsideIn(X) checker are later roadmaps. They are kept in mind and not built.
- GHC cannot be compiled by rhc under this roadmap.

**From the owner's direction during writing:** recursive modules are expected to be supported, and the libraries may follow the Report's recursive structure (D30, D36). Where convenience and the text pull apart, lean to the text and state the cost.

**From Rune's rules** (`AGENTS.md`):
- A pass runs through `Pass.stage`, with its printer, size and lint; one that rewrites asks `Pass.spend`, and comes with a test in `tests/ir` and a written invariant in `docs/ir.md`.
- Instructions and primitives change only through `src/isa`, and a primitive that needs the operating system goes behind `runtime/sys/sys.h` in every layer.
- The layout lives in `runtime/value.h` and `runtime/register/jit/masm.c` and nowhere else.
- A change to `runtime/register` also runs the sanitizers, stress, Windows and portability.
- A library beside the Basis may not use `_prim`.
- Tests are written or reviewed by hand; `.expected` is never accepted blindly.
- Every live `.py` needs an owner (`tests/runner/migration.sml:2,10`), so the throwaway scripts of this roadmap do not land as they stand.

**From the owner's rules, neither of which is in `AGENTS.md`:**
- 2026-10-21: designs for code the compiler runs are chosen by speed and correctness on Rune at tier 2, and other hosts are informational. `AGENTS.md`'s library rule has `lib/language/c` running on hosts, so a Rune-only `lib/language/haskell` needs a written exception (D42).
- 2026-10-10: highly generic, reusable functionality goes into its own well-tested library under `lib/`, which is D21's ground for the Unicode tables.

**From the owner's decisions of 2026-11-09 and answers of 2026-11-10, and the tree they name:**
- **Work from origin/master `697724da5`,** where build-system-v2 has landed. The roadmap's citations stay against `b12141ecc`, where it was written; each is checked again on the new tree before its milestone, and a citation of the new tree says so.
- **v2's friend rule.** A build that names a file or sub-build of a library with a header is refused unless the header names it a friend (v2's M14; `lib/compiler/driver/project.sml:286-313`, origin/master). So `rhc.build` is a friend of `lib/compiler`, as `rune.build` is (D41).
- **Identity per compiler.** A second compiler links its own `Config`, which `scripts/gen-version.sh --config PLAN FILE` writes over its own plan; through `libraries compiler` it would take Rune's (v2's M11; D41).
- **Codecs are generated.** Mid's codecs come from `tools/codecs/compiler.sml` by `make codecs`, and `make check-codecs` refuses stale output (`Makefile:677-680`, origin/master). A change to a constructor of Mid, to `fundef` or to `Ty` is a change to that description (M4, M28, M29, M30).
- **What is measured is built on the register VM first,** its interpreter and JIT, and taken to the stack VM, runeopt and the other platforms only once the owner adopts it (*Decisions on the numbers*).

**The standing gate.** After any change to Rune, SML budgets and bootstrap bytes stay put unless a decision says otherwise, and that decision says by how much. Where a prototype here moved nothing, the milestone must show the same. Exceptions are known. The primitives and form C's instructions of D3, D11 and D13 change both instruction-set fingerprints, so every `.rbc` changes once and the compiler's budgets re-base (deduced, not measured); M9 reports what moved. The owner's D8 and D20 move more, and M29 and M31 say by how much. D9's multi-value return would move both fingerprints again, and lands only if the owner adopts it on M30's figures.

**From the Report's licence.** `share/rhc/haskell98` is a modified version of the Report's code: it says so, and does not claim to define Haskell 98 (D37). The corpus has licences of its own, which no experiment surveyed; M3 starts there.

## The architecture

**A lazy typed Core that rhc owns, lowered to a strict Mid with suspensions explicit in its types.** Everything above Mid is Haskell's. Everything from Mid down is Rune's, and changes there are decisions. D1-D57 are the owner's, decided on 2026-11-09 with the answers of 2026-11-10, and this is the design they give; nine options are still measured, each built on the register VM first (*Decisions on the numbers*).

```text
.hs, .lhs     literate source, Unicode
   |
Lexer, layout          closeImplicit, no fixity needed            D27
Parser                 flat operator sequences, spans             D27, D28
   |  AST              printers: tree, token and exact trips      D28
Modules, names         least fixpoint over each SCC; --names      D29, D30
Fixity                 an attribute, read after names             D29
   |  renamed AST
Kinds, instance heads  joined over an SCC                         D30, D31
Types, classes         joined over an SCC; evidence records       D30, D31, D32
Deriving               in the checker; instances made as AST      D33
   |                                     HsLint, three parts      D54
Desugaring, matching   chapter 3's translations                   D34
   |  Core             typed, lazy; text form is a contract       D2
Core simplifier        known dictionaries, then strictness        D47-D51   (track P)
   |                                                     CoreLint D2
Core to Mid            lazy position: susp T; evaluated: T        D3, D4, D5, D6
   |  Mid              strict; Ty with f a and forall; Case       D4, D8
   |                   multi-value return, if adopted             D9; MidLint
Mid's passes           a list as data, MidPipeline.lowOfMid       D39, D10
   |  Low, bytecode    FORCE ENTER BLACKHOLE UPDATE, K_THUNK      D11, D13, D14
   |                   both bytecodes, every tier
```

### Ownership

| Layer | Where | Who changes it |
|---|---|---|
| Lexer through Core to Mid | `lib/language/haskell` | rhc's roadmap, freely |
| rhc's driver: graph discovery, SCCs, the loop | `src/rhc` | rhc's roadmap, freely |
| The Report's code | `share/rhc/haskell98`, with its `LICENSE` | Report text plus a listed overlay (D37) |
| Mid and its layer of passes | `lib/compiler/mid.build`, with `driver/midpipeline.sml`, rhc a friend of `lib/compiler` (D39, D41) | decisions only |
| Low, bytecode, VM, collector | `lib/compiler/backend`, `src/isa`, `runtime` | decisions only |
| Store (`UnitStore`, landed with build-system-v2), `UnitFile`, `Link`, `MidCodec`, usage recorder | `lib/compiler` | decisions only (D43) |

rhc's interface, usages and fingerprints are rhc's own: `Types.ty` holds no class context or variable-headed application, and `UnitBasis` assumes one flat scope and an ordered prefix.

### The contracts

**Core text** stands between tracks F and B, as Mid text stands between B and Rune. With it, thunks, Core to Mid and a Core interpreter can run before a parser exists, and a fault is placed by which side of the text it falls on.

**The Mid contract** (D5, D39-D41) says what a front end hands over, declares, sets and calls: `results/E11/contract.md`. Its worst rule is the one no lint fully sees:

> A datatype-typed variable is evaluated.

`removable`, Workers, the constructor folds and tier 2's `ms_trusts` all rest on it. It holds by types, which is why a lazy position must have a distinct type. Across a cast it holds only by the lint of D4 and by CoreLint.

### Laziness in Mid

- **A lazy position of type T is `susp T`,** an abstract tycon. It gets `RAny`, so every engine keeps its tests (E2).
- **Functions take `susp` where lazy and return evaluated,** so a value of a datatype is always evaluated.
- **Force is one node,** the primitive `thunk_force`, which `Regs` lowers to `FORCE`: a value or an evaluated thunk gives its value at once, and otherwise it falls to `ENTER`, which finds a running thunk a loop (D3, D13; `regops.h` in `patches/E2-all-forms.patch`). As a library function force cost 1.17 of the instruction form where one node cost 1.05 under G, because a body passes the inlining budget [V's inference] (E2). A `Force` right-hand side is built and measured against the primitive (D3).
- **A thunk is a flat `K_THUNK`:** unevaluated, or under evaluation once its code says `BLACKHOLE`. Evaluated is `K_IND`, which the collector shortcuts. `CALL` stops a `K_THUNK`, so a thunk in a function-typed slot stops on every engine. The collector and images change: `obj_scanned_fields`, `K_LAST`, `put_object` and the frame check in `image.c` (D11). Both bytecodes have the four instructions (D14).
- **The update is in the thunk's own code,** `UPDATE`, so a thunk adds nothing to `RET`.
- **A running thunk's free variables are released at entry:** its code reads its captures and says `BLACKHOLE`, and the collector follows none of its fields from there, so re-entry is found at once (D12, not applicable under form C).
- **Types.** `Ty` gains variable-headed application and a forall (D4), so a higher-kinded position and a dictionary's polymorphic method have Mid types. `Any`, meaning evaluated, is left for what `Ty` cannot say, with a lazy one as `susp Any`, and no type variable is instantiated at `susp T`, as in Strict Core. The common cast, a value into a `susp` slot, 117-124 a program at E5's step `D0` against 0-31 of `any` (E4, `results/E4/casts.out`), stays, erased in `Lower` under a lint (D4).
- **Recursive values** are patched through a cell, and **CAFs** are thunks in globals (D6). For D3's measured variant, a recursive form in Mid instead.
- **Matching and returns.** A `case` of Core lowers to Mid's `Case` (D8). An unboxed product, `IO`'s state and value among them, lowers to a tuple, or the token is erased; to multi-value return only if the owner adopts it on the numbers (D9, D25).

### What is shared with lazy ML

`susp`, the thunk object, force and the collector, given a guard on the `K_IND` shortcut and a pin: a `K_IND` that a frame still runs is not shortcut, since a lazy ML body can outlive its own update. E14 found that failure by running; Haskell cannot reach it. Not Core, whose strictness analysis and dictionary work lazy ML has no use for: its extension took +239 -30 in 17 files, with no line in a Mid pass. What separates a lazy ML body from a Haskell one is that it does not blackhole and does not release: a body may be run again. No release bit is needed (D12, D57). E14 showed this on form G. Under form C lazy ML's reading is E2's `CmX`, whose thunk does not say `BLACKHOLE`, and M26 runs the checklist again on it.

### Modules

A module is found by scanning imports; each SCC of the graph is one unit (D30); name resolution is a least fixpoint over the SCC (D29), and the checker joins it. Whole-program compilation is the one-unit case, so all of this works before any cache exists, and the cache adds only a key and an identity over every member.

The Report's own libraries are compiled in its module layout, as one 11-module unit (D36). M12 and M13 land cycles and the joined checker before the Prelude first runs, so this needs no cache, and the first hello goes through recursive modules. If the joined checker runs late, a small tool can derive the merged layout as a fallback, built only then.

### What a cache hit must satisfy

E13's obligations H1-H9, set out with their holes in *The experiments*: every name looked up, absent too; every class and type looked up through the closure, absent too; what a unit sees taken from the graph, never an entry; `default` in the key; instance contexts and fixities in fingerprints; entities by origin; keys and identities over every member of an SCC.

### What stays possible

The brief keeps these in mind and does not build them. For each: which decision keeps it open, and what would close it. None adds a milestone, and the reasoning is this section's own [inference] unless it cites a result.

- **Other tools on `lib/language/haskell`.** D28 keeps it open: the AST holds spans, parentheses, flat operators and literals as written, and under the owner's C annotations in every node, with comments, pragmas and layout, behind an exact printer. D31's evidence is tables by node, so a tool can read what the checker chose. M8 gives the library a `library.build`, though M11's measured size has no signature files, which a library for others will want. It closes if the front end comes to depend on `src/rhc`'s driver state. **D42 pulls against this:** a Rune-only library runs on no other host, so a tool built by another compiler cannot link it. Taking D42's exception as a `LibHosts` entry, with failures recorded as `HOST-BUG`, costs less of this than a sentence in `AGENTS.md`.
- **Haskell 2010.** The brief's future language mode. D35 keeps its dotted names behind a flag, D38's rule names one text so a mode can name another, and D53's table is keyed by clause id, so a second text is a second set of rows. It closes if a Haskell 98 reading is written into the front end with no switch where 2010 differs, as `modid` would be without D35's flag.
- **Extensions.** D2 keeps these open: Core is typed and rhc's own, so it can move, and D2's reopening names the limit, an extension whose elaboration wants System FC. D25's state token is the form `ST` and Haskell 2010 will want, which is the owner's reason for it, and D12 records the raise repair that a catchable `error` would bring back. Core's text is a contract between tracks, so it closes the door a little with each tool that reads it. E14 shows that lazy ML, the extension the brief names first, needs no Core at all.
- **A second inference engine.** D31 keeps this open: desugaring and HsLint read evidence records by node, not the inferencer's state, so a second inferencer that writes the same records can sit beside the first. D54's second inference is a working precedent over one renamed AST. It closes if M15 reads the checker's ref cells directly instead of the records. An OutsideIn(X) engine would also want equalities in its evidence, which reopens D2.
- **Parity with GHC.** The brief's "then later feature parity with current ghc". Nothing here builds towards it, and no decision is taken for it. What keeps it open is what can be added later without moving the boundary, or is taken already: `FORCE`, taken (D13), multi-value return and eval/apply, measured (D9, D15), a Core optimiser that can grow (D47), a state token, taken (D25), and Core itself, since System FC is a later change in a library rhc owns. What would close it is cost and not design: every pass written against Core makes System FC dearer, and parity also means compiling GHC's dialect of the libraries, which the brief puts outside this roadmap.

## Decisions

Fifty-seven decisions, each with its options, the evidence and a recommendation. The owner decided them on 2026-11-09
(*The request*), and answered the lead's questions on 2026-11-10: D39 became C, D9 is taken on a measurement, D14's C is
confirmed, and what is measured is built on the register VM first. Each section ends with the decision. Where the owner
chose against the recommendation, the section's text stays as the evidence it was written on, and the decision says what
was chosen and the owner's reason in the owner's words. Nine are taken on the numbers: what is built for them, and how it
is measured, is *Decisions on the numbers*, after *Gates*. Where a decision reverses something earlier, or something the
brief expects, it says so.

Every change to Rune is graded on the brief's scale: **large**, optimal for Haskell; **medium**, good for both languages;
**small**, Haskell can live with it; **none**, rhc works around it. Paths are as in *Where we are*. `tables/` is
`results/E2/tables/`. Machine instructions are `instructions:u` at tier 2.

| | Decision | Recommended | Status, 2026-11-10 |
|---|---|---|---|
| D1 | Hook point | Mid, beneath a Core that rhc owns | decided: A |
| D2 | Core | Owned by rhc in `lib/language/haskell`: System F plus `f a`, lazy `let` and `letrec`, forcing `case`; typed, with a text form | decided: C |
| D3 | Mid's laziness surface | Small: `susp` an abstract tycon, force one primitive node, no new constructor | decided: B, with form C; measure C |
| D4 | `Any` against extending `Ty` | `Any` stands: evaluated, `susp Any` where lazy; casts erased in `Lower`, with a lint, and `any_check` in test builds | decided: C |
| D5 | The evaluated-datatype invariant | Written in `docs/ir.md`, linted where a lint can reach | decided: B; C in checked builds only |
| D6 | Recursive values and CAFs | Cell-patched recursion, CAFs as thunks in globals, no change to Mid | decided: A; C for D3's measured C |
| D7 | Lambda | Stays, private to SML; no front end enters there; `Try` and `Fail` may go | decided: B |
| D8 | Mid `Case` | None in this roadmap; recorded as medium, for clarity and compile time, for a later roadmap | decided: C, now |
| D9 | Multi-value return | None now | measure B against A |
| D10 | Walkers | Small: `atomsOfRhs` and `mapRhs` first | decided: C, now |
| D11 | Thunk object | `K_CLOSURE` with non-zero `contag`, evaluated is `K_IND`; `K_THUNK`'s reservation released | decided: C |
| D12 | Release, blackholing, raise | Form G, form L the alternative; no raise repair for Haskell 98 | n/a: form C |
| D13 | Library, prims or instructions | No new instruction; `FORCE` stays additive | decided: C |
| D14 | Stack bytecode and runeopt parity | Parity by G: force in `stack.sml`, +22 as built in E14, nothing in runeopt | decided: C, by the owner's rule; confirmed |
| D15 | Eval/apply | Not now: M25, on measurement | measure C against A |
| D16 | Pointer code 11 | None: force loads the header | measure B against A |
| D17 | Selector thunks | After leaks are measured on the corpus | measure B against A |
| D18 | Depth | None: a 10^7 chain fits 1 GiB under G | decided: A |
| D19 | CAF roots and the barrier | CAFs stay roots at first, measured on the corpus; the barrier needs nothing new | measure B against A; barrier as recommended |
| D20 | `Integer` | C: an immediate small `Integer`, primitives in line; the bignum path built first | decided: D |
| D21 | `Char` | Mid `int`, Unicode 18.0.0; general category and case mapping added to `lib/unicode` | decided: A; tables D |
| D22 | `Int` width and overflow | The checked prims: overflow an error, as 6.4 allows; the corpus's `hash` a compat function over `Integer`; reopened by a program outside `hash` that overflows | decided: A |
| D23 | `Float` | Re-rounding by `real_to_single`, as `Real32` does | decided: B |
| D24 | String literals | Lazily unpacked from a constant | decided: A; measure B and D |
| D25 | `IO` and lazy I/O | `IO a` a function of unit, no state token; `getContents` through one interleaving primitive | decided: B |
| D26 | Library boundary | Haskell over prims and a frozen SML support unit, SML names confined to that unit | decided: A |
| D27 | Parser and layout | Hand-written recursive descent, `closeImplicit` | decided: A |
| D28 | AST fidelity and printer | Spans, parentheses, flat operators, literals as written; tree and token round trips | decided: C |
| D29 | Names and fixity | Least fixpoint; the Prelude does not import itself; fixity resolved after names | decided: A; greatest an option |
| D30 | Recursive modules | One unit per SCC, joined checker, no extra files; a variable defaults by the module its constraints arose in, refused where those modules' `default`s differ; Rule 2 closes at the end of each module | decided: A, each module its own; per SCC an option |
| D31 | Checker structure and evidence records | In the manner of `Witness`; unification plus kinds, context reduction, dependency analysis, MR, defaulting, derived contexts; no OutsideIn | decided: A |
| D32 | Monomorphism and defaulting | The readings R18, R20, R21 | decided: as recommended |
| D33 | Deriving | On the renamed AST, chapter 10's text the specification | decided: C |
| D34 | Desugaring and match compilation | rhc's own, to Core; `-O0` keeps the Report's order; Sestoft-order trees optional | measure B against A |
| D35 | Hierarchical names | Refused by default, a documented flag for the corpus | decided: B |
| D36 | Library layout | The literal layout: the Report's graph compiled as one unit; the merged form a fallback, built only if the joined checker runs late | decided: A |
| D37 | Prelude overlay and licence | A listed overlay; `share/rhc/haskell98/LICENSE`, marked modified | decided: code B, licence A |
| D38 | Which text | The December 2002 text plus the published errata, all listed; rhc follows it unless it is wrong, contradictory, ambiguous or conceded by the Report (the owner struck "cannot be implemented" for that on 2026-11-13), and unanimity of implementations alone is no ground | decided: B |
| D39 | Pipeline as data | E11-4, 6, 8; bytes held | decided: C |
| D40 | Front-end independence | `Stamp`, `label` on `fundef`, `Literal`, `Target` passed in: E11-1, 2, 3, 5, 9 | decided: B and C |
| D41 | What `lib/compiler` exports | A third layer, `lib/compiler/mid.build` | decided by the lead: C |
| D42 | Which hosts build rhc | Rune alone is required; other hosts informational | decided: C |
| D43 | Store option | Generalise: +338 -231 in 3 files, Rune byte-identical | decided by the lead: B, as landed |
| D44 | HsIface | Names, types, classes, instances, fixities, by entity; the Prelude's unfoldings from the start, a program's own later | decided: C |
| D45 | Prelude snapshot | A frozen unit through the store; until M21, the saved world | decided: A, with B until M21 |
| D46 | Order with build-system-v2 | Side by side, neither waits; one at a time, v2 first; rhc asks that v2's D5, D6, D8, D14, D24, D25 be taken with a second language in view | n/a: v2 has landed |
| D47 | Where optimisation lives | In Core; Mid unchanged | decided: C |
| D48 | A Core simplifier with eta | Yes: every strictness and floating result assumes one | decided: C; measure D |
| D49 | Known-dictionary resolution and specialisation | First: E3's L1, thunks -47%, bytes -38% in total, -26.2%, -17.7% median; Rune's figures from E5 | decided: C |
| D50 | Strictness | Next: E3, a further -20%, -11% in total, -11.5%, -5.4% median | decided: C |
| D51 | Cheap eagerness, and what stops `inline` copying a thunk | Decided together with D22, whose checked prims close the local form for `Int` arithmetic, as Faxén 2000 §3 says | decided: C |
| D52 | Oracle policy | GHC-strict plus Hugs as judges, nhc98 third; every expected result cites a clause; a disagreement yields a reading | decided: C |
| D53 | Conformance table | Generated TSV of 3,901 rows, enforced by id | decided: C |
| D54 | HsLint | A target check and a second inference, on the elaborated output | decided: C |
| D55 | Generators and metamorphic relations | Both, with rhc's mutants | decided: B |
| D56 | Budget | The 188 programs under 1 s in `make check`, in 3 of `Lang.ways`' 18 ways, the rest nightly; K from E5 | decided: B |
| D57 | What "ready for lazy ML" means | A checklist of six, run by E14: the pin, a MidLint rule, stack force, the spec's programs, flag off, `susp` documented | decided: C; run again on form C |

**G0 is passed.** It needed D1-D6, D11-D13 and D36, which fix the boundary between Core and Mid, the thunk and the layout
of the libraries, each expensive to reverse once code stands on it. The owner decided them with the rest on 2026-11-09.
What G0 leaves open is D3's measured variant, a `Force` right-hand side, which M9 builds and the owner takes or not on the
numbers. A decision is "by the lead" where the owner asked the lead to decide it (D41, D43).

### D1. The hook point

Where does rhc join `lib/compiler`? Everything above the hook is Haskell's and changes freely. Everything below is Rune's
and changes only by decision. The brief names Lambda and Mid as the obvious candidates, and Low as a less obvious one.

- **A. Mid, beneath a Core that rhc owns (small).** **Recommended.** rhc lowers its Core (D2) to strict Mid with
  suspensions in the types (D3), and takes every pass below `expand`, which it leaves out (D39). Rune's side of it:
  - `--read-mid` through to bytecode, so that Mid can be tested by hand: `src/driver/main.sml`, 1 file, +14 -2
    (`patches/E1-readmid.patch`);
  - a Mid unit that imports compiled SML (D26): +43 -4, in `core/midtext.sml`, `driver/pipeline.sml` and
    `src/driver/main.sml`, by difference in `patches/E1-all-prototypes.patch` (4 files, +81 -12, which also holds `readMid`,
    D5's two fixes and the functor name);
  - no SML front end linked: D39-D41, each a decision of its own. Until they land, rhc links the SML front end and works
    (E1, `results/E1/indep/grep.out`).
- **B. Lambda (medium at least, not sized).** A front end would have to supply what Lambda takes from the elaborator:
  binders' schemes in `Ty.binders` (`core/ty.sml:186`), stamps and open constructors through `Elaborate`
  (`core/tomid.sml:25`, `:279`). There is no type abstraction, and every right side of a `LetRec` is a `Fn`
  (`core/lambda.sml:28`). No optional pass runs on it (`driver/pipeline.sml:197-203`), so it gains nothing over emitting
  Mid. This is W1.
- **C. Low (none, and rhc pays).** Rune stays as it is. rhc does closure conversion, layouts and representations itself,
  and gets no Mid pass and no MidLint.
- **D. A lazy Mid (large).** One IR for both languages. `Let` is sequenced and strict, and `removable`, `Workers`, the
  constructor folds and tier 2's `ms_trusts` all rest on that (*What strictness gives each IR*). Every pass would need an
  audit, with SML's correctness riding on it. Rejected; not built.

**The evidence.**
- *Mid can carry it.* E1 hand-wrote ten programs: `knot`, `cafs`, `monad`, `classes`, `nest`, `nest2`, `nest_static`,
  `nest_eq`, `letpoly`, `exceptions`. Each ran 45 ways, at three levels on twelve register modes and three stack modes, at
  `--lint=2 --mid-roundtrip`, against output derived by hand: 450 of 450 with the prototypes
  (`results/E1/matrix-fixed.txt`). On master with `readMid` alone, eight pass 45 of 45, and `nest_static` and `nest_eq`
  fail to compile, 6 compiles in all (`matrix-base.txt`). Both faults are local to Simplify (D5), and `nest_any` passes
  without a change by typing the function at `any`. A sweep of `--lint=3`, 16 `--fuel` values and 11 pass subsets gave 232
  compiles, 0 bad (`out/sweep/result.txt`).
- *Tier 2 never faulted on well-typed Mid* (E1). The hazard is Mid that lies behind a cast: D5.
- *What Mid's passes give.* All ten off, the compiler's own compile takes +67.7% instructions and +237.7% allocation
  (E12, `results/E12/passes.tsv`), and that is what C gives up on strict code. On rhc's output E5 has the figure. Rune
  `-O2` against `-O0` saves, on `queens`, `primes`, `exp3_8`, `sum`, `sumint`, `list` and `showk`, 3.0, 2.0, -0.8, -5.3,
  -7.2, 10.9 and 1.3% at `D0`, so three of the seven get worse, and 18.4, 21.6, 0.0, 5.5, 6.8, 0.1 and 19.8% at
  `D3`+eta+strict, so 0 to 22% after Core's steps (`results/E5/results.jsonl`). D49 reads the same data from the other
  side. So the hook does not stand on the passes being worth having. It stands on MidLint, tier 2's safety and that gain.
- *A client with no front end exists.* E11's `tests/compiler/mid-client.sml` takes Mid text to bytecode through an edited
  pass list with 48 of the 80 files after its patches.
- *The form has precedent, and no measurement.* Mid plus `susp` is L2 of Peyton Jones et al. 1998 minus its `ST`, with a
  lazy typed Core kept above, which that paper did not consider. Of ten implementations none keeps a typed strict IR with
  passes of its own beneath a lazy typed Core; jhc's Grin and UHC's GRIN are the nearest (*What the implementations do*).
- *SML.* A moves no byte of an SML program: `readMid` is driver code, and the compiler built with every E1 prototype
  compiled the compiler to identical bytes at `-O1` and `-O2` (`results/E1/out/selfcheck.txt`). No budget moves [deduced:
  no path of an SML compile changes].

**The strongest argument against: two optimisers.** Mid sees a thunk as an opaque primitive, so nothing Mid's passes do
can remove one. Core therefore needs its own simplifier with eta (D48), dictionary specialiser (D49) and strictness
analyser (D50), beside a `Simplify` of 2,090 lines that already inlines, folds known constructors and specialises. That is
two optimisers in one compiler, with two inliners, two occurrence analyses, and two sets of lints and mutants. Core's is
one language's alone. Lazy ML has no Core (E14), so the brief's reason for doing Haskell first, that the whole stack comes
to support laziness properly, stops at the runtime: lazy ML would inherit the thunk and no optimiser for it.

The other road is GRIN's (Boquist 1999): keep Core thin, desugaring and dictionary passing lowered at once, and teach Mid
what a suspension is, so that there is one optimiser and lazy ML shares it. On Rune that would mean, in rising order of
size:
- **Force facts in `Simplify`.** `force (delay f)` becomes a call of `f` where the thunk has no other use. A force
  dominated by a force of the same variable becomes the first's result. A thunk around an evaluated value becomes the
  value. Strict Core's §5.4-5.5 give these cases. They would need a force described as pure but possibly diverging, not
  `anything`, and either rewrites keyed on a primitive's name or D3's medium option.
- **Cheap eagerness in Mid.** A delay whose body is a total primitive over evaluated operands runs at once. Mid's types
  already say which operands are evaluated.
- **Strictness in Mid.** A new analysis over `fundef`s: a parameter of type `susp T` forced on every path becomes `T`, and
  the force moves to the caller, as `Workers` already moves a `Select` (`core/workers.sml:8-11`). It would serve lazy ML's
  hand-written suspensions as well.
- **Dictionaries in Mid.** `specialise`, today for a self-recursive function of at most 64 nodes passing functions
  (`docs/ir.md:878-885`), extended to known records of methods, seeing through `Any`'s casts (D4).
- **GRIN proper, at the limit.** A whole-program analysis of what each thunk can be, so that a force becomes a `case` over
  the code that can reach it.

That would buy one optimiser under `Pass.stage`, `--fuel` and MidLint, no second set of lints, and everything for lazy ML
on the day it lands. GRIN's own figure is 3.6 times ghc 4.01, with the largest and smallest factors removed.

**Why it does not flip the hook.** A thin Core lowered to Mid is this same hook. The argument moves where optimisation
lives, not where rhc joins `lib/compiler`, so taking A leaves that road open, and D47 is where it is decided. The reasons
this roadmap does not take it are D47's, in short:
- What pays most moves lazy bindings: let from let 32%, let from application 9%, let from case 5%, case of case 8% of
  transformations (Peyton Jones, Santos 1998, Fig 3). In Mid `Let` is strict, and a thunk is a closure.
- `App` is not removable (`core/simplify.sml:112`), so Haskell's purity is invisible to Mid: what Core does not remove
  stays.
- GRIN's analysis rests on the entire program. Under units `Pass.whole` is false, and a force stays an open dispatch
  [inference]. D43 wants separate compilation.
- Its 3.6 comes from 16 programs of up to 716 lines, overloading removed by hand, a full back end. Its author asks for the
  evaluation model to be isolated; nobody has done it. Neither jhc nor UHC keeps a generated whole-program `eval` (*What
  the implementations do*).
- The largest step E3 finds at the level rhc reaches first is L1, GHC's simplifier and class-op rule with specialisation
  off: thunks -47%, bytes -38% in total, -26.2% and -17.7% median (D48). That is Core's work before any question of thunks
  arises.

The first item costs little and survives: force facts can be added to Mid later without moving the hook [inference].

**What would reopen it.** Casts that block method inlining would make `Any` the wrong boundary, and rhc would erase to
`any` throughout or look at Low (D4). If Mid's passes add nothing after Core on real output, where E5's hand-lowered
programs give 0 to 22%, which M23 can measure, Low costs nothing and is simpler. A fault at tier 2 on well-typed Mid, or a
pass that cannot be made safe, reopens it at once. Lazy ML proving to need more than E14 found, `susp`, force and match
compilation, reopens a Core shared with lazy ML (D2). Taking the other side
of D47 reopens D3, not this. Lands in M5.

**Decided (owner, 2026-11-09).** A, as recommended: Mid, beneath a Core that rhc owns.

### D2. Core

What stands between the type-checked program and Mid, and who owns it? No option changes Rune: Core lives in
`lib/language/haskell`, and moving it later is cheap.

- **A. No Core.** Desugar straight to Mid. Mid has no form for `f a` (D4), and no transformation that moves a lazy binding
  can be written there (D47).
- **B. An untyped Core.** As nhc98, Yhc, Hugs, MicroHs and hbc, so a typed IL is not needed to implement the language. But
  Mid is explicitly typed and its types are memory safety (X1), so Core must know a type at every binder to lower at all.
- **C. System F plus `f a`, lazy `let` and `letrec`, forcing `case`, typed.** **Recommended.**
  - Its types separate evaluated from unevaluated, as Mid's `int` from `susp int` [inference]. A Core in which every value
    is implicitly lazy has nowhere to put a strictness result (Peyton Jones 1996, §6.1; Peyton Jones, Partain 1993, §4),
    and Bolingbroke and Peyton Jones §2.1 show what a compiler that cannot state the difference gets wrong.
  - Arguments are atomic and `case` is the only force, so every allocation and every evaluation can be seen.
  - Its text is a contract, between tracks F and B as Mid text is between B and Rune (*The architecture*). Thunks, Core to
    Mid and a Core interpreter can run before a parser exists.
  - CoreLint is in the first version.
  - It needs one thing beyond System F: `newtype T = MkT (T -> T)` has no System F encoding, so one coercion (Sulzmann et
    al. 2007, §2.4). `seq` is at every type (R35), so eta is not free in it (D48).
- **D. System FC.** GHC's. Its features are GADTs and type functions; Haskell 98 needs neither.
- **E. A Core shared with lazy ML, in `lib/compiler`.** Lazy ML needs none (E14). `spec/ext/lazy.rs` on branch `runespec`
  defines it as two kernel forms over `tau susp`, with `val rec lazy` tied through a ref cell, and neither strictness
  analysis nor dictionaries have any use there.

**The evidence.** For types the evidence is strong and anecdotal: the reported experience of two teams, with no count
(Peyton Jones, Meijer 1997; Peyton Jones 1996; Hudak et al. 2007). Of ten implementations only GHC and jhc have a typed
Core. rhc's own reason is stronger than theirs: E1 shows that behind a cast nothing checks a force (D5), so CoreLint is
the line of defence where MidLint stops. How much type system is settled by need: an IL must be explicitly typed, since
inference does not survive transformation, and Haskell needs higher-kinded variables and rank-2 dictionary components.
*What the literature says*, D2.

**Against.** Eight implementations of ten do without. Types cost compile time: TIL paid eight times, on single-module
programs, and Shao et al. 1998 find types "very hard to represent and manipulate efficiently", chiefly for ML modules. And
Core's types end where D4 begins: `f a` crosses to Mid as `Any`, so the typed part stops just where X2's bug lives. The
answer is the asymmetry: dropping types later is easy, and adding them is not.

**What would reopen it.** Compile time dominated by Core's types once type nodes are shared. An extension whose
elaboration wants System FC, which is a later roadmap's. Lands in M8.

**Decided (owner, 2026-11-09).** C, as recommended: System F with `f a`, lazy `let` and `letrec`, forcing `case`, typed, with a text form.

### D3. Mid's laziness surface

What does Mid gain so that a position can be unevaluated? This overturns the plan, which expected a `Force` right-hand
side.

- **A. None: form A.** A suspension is a `ref` of a datatype, cast, entirely in Mid text (E1's `results/E1/prog/rts.mid`).
  No file of Rune changes. E2 prices it at 1.364 of form C under Haskell's reading, 64 bytes a delay, and it leaks and
  overflows (D11, D12, D18).
- **B. Small: form G.** **Recommended.** `susp` is an abstract tycon, so `Ty.view` is untouched and `Lower` gives it
  `RAny` (`backend/lower.sml:412-417`). Force is one primitive node, `thunk_fforce`, which `Regs` lowers to a test, a
  value read and `CALL`. No constructor is added to Mid, Low or either bytecode. In all eight primitives, the seven of
  E2's `delay/Ghs/lazy.sml` (`thunk_fmake`, `thunk_fready`, `thunk_value`, `thunk_fcast`, `thunk_fbh`, `thunk_fupd`,
  `thunk_fforce`) and `thunk_move`, and one function over Low's existing operations, `Low.hoistEnv`, which uses the last.
  About 210 hand-written lines by V's count: `runtime/prims.c` 26, `fastprim.h` 13,
  `emit.c` 67, `src/isa/prims.sml` 14, `backend/low.sml` 48, `backend/regs.sml` 37, and `backend/stack.sml`,
  `backend/regverify.sml` and `isa_regs.c` 7. A further 45 or so are shared with every form but A (D11), so about 255.
- **C. Medium: a `Force` right-hand side.** A fifteenth `rhs`. Not built. It means an arm in at least 38 walkers of 479
  lines, 28 of which end in a catch-all and would take it without a word (`core/lift.sml:45`, `core/simplify.sml:73`,
  `:115`), and in `MidText`, `MidCodec`, `UnitMid`, `MidCanon` and `Fault`. D10 would have to come first. Thunks in `Fun`
  groups, the rest of the plan's expected surface, add the hazard that `inline` copies one (*What the literature says*,
  D3).
- **D. Large: a lazy Mid.** D1's option D. Rejected.

**The evidence.**
- *One node matters.* The same object with `force` a library function, form F, is 1.169 of C, 1.247 on the densest 20, and
  allocates 649 GB against 564. G is 1.048 and 1.065 and allocates what C does (`tables/summary.txt`). The reason given is
  Mid's inlining budget: a library `force` pushes a thunk's body past it [V's inference from objects per port].
- *`RAny` keeps the tests.* A thunk in a slot typed list, tuple or `ref` gives a silent wrong answer at tier 2, and in a
  slot of an abstract type stops on all three engines (`tables/wrongslot.txt`). That is why the type must be distinct (X1,
  D5).
- *A primitive has an arm in every walker,* and `removable` asks its description (`core/simplify.sml:113`). E2's force
  says `anything`, so it is never dropped and not moved across an effect [deduced], which is what `seq` needs.
- *Sharing.* A thunk here is the result of a primitive bound by `Let`, not a `fundef`, so nothing calls its code by name
  for `inline` to copy [deduced from the patch; no test counts re-evaluation under Simplify].
- *Runs.* 504 stress runs on B, C and G, 98 on L, 0 bad (`tables/stress.txt`, `stress-L.txt`). G and L are clean at
  `--lint=2` on all 115 ports (`tables/portlint-Y.txt`, `portlint-L.txt`).

**What landing adds to the prototype.** The prototype types `thunk_fforce` as `'b -> 'a`, two unrelated variables, so
MidLint cannot hold a force to its suspension. Landing needs `'a susp -> 'a`, with `susp` in `Types.builtinTycons`
(`elab/types.sml`, +3 -1 in the prototype), since `IrRules` takes any type for a name that is not built in
(`core/irrules.sml:64-66`, `:85-87`). The prototype's line in `elab/env.sml` is for SML kernels, and rhc does not need it
[deduced]. `thunk_fmake` says `WritesHeap` for its write to a fresh object, which `src/isa/isagen.sml:462-465` reads as
not removable, so an unused delay stays. Core drops dead lets anyway (D48), but the description should say what is true.

**SML, for every form but A.** The prototype moved no count: on 12 strict ports, stock against stage bin10, which holds
forms B, C and F but not G's node, L or liveness, `--count` is identical in instructions, bytes and objects. Machine
instructions are 1.0056 by geomean, from 0.9982 on `circsim-strict` to 1.0202 on `infer-strict`, which is the collector's
new test of each object (`tables/sml-cost.txt`). Bytes move once. Primitives are in the fingerprint
(`docs/bytecode.md:77-84`), so both sets' fingerprints move (`patches/E2-all-forms.patch`), every `.rbc` and image changes
there, and the cache's configuration moves (`driver/unitcache.sml:126`). The new primitives go at the end of the table, so
an SML program's code stays the same bytes [deduced]. The compiler's own image grows by the tables, so its budgets are
re-based in the commit that moves them (`docs/testing.md:670-673`) [deduced; by how much is not known]. Not run:
`make check`, `make perf-check`, the bootstrap. This is a place where the standing gate is asked to give, and M9 must
report what moved.

**Recommended: B.** A keeps a lazy position distinct too, at 1.36 of C and with the leak of D12. B is the smallest change
that removes both, and it needs no audit of a pass.

**Against.** `thunk_fforce` is a primitive no VM runs: its C body is a fatal stub, and it exists only for `Regs` to
expand. That is a node by another name, and an honest `Force` is cleaner once D10 has removed the catch-alls. If Mid ever
learns about `susp` (D1, D47), rewrites keyed on a primitive's name are a poor footing. There is precedent for the stub:
six primitives of the compiler's own that `Lower` alone translates (`src/isa/prims.sml:887`, `backend/lower.sml:987-992`).

**What would reopen it.** The owner taking the other side of D47, which makes C the better footing. A pass found to drop,
copy or move a force. rhc's measured density putting G too far from C, which is D13's question and leaves the surface as it is.
Lands in M9.

**Decided (owner, 2026-11-09).** B, with form C in place of form G: "B but with form C instead of form G". `susp` is an abstract tycon and force is one node of Mid, lowered to form C's instructions (D11, D13), not to form G's test, value read and `CALL`. In E2's form C that node is the primitive `thunk_force`, beside `thunk_make`, `thunk_blackhole` and `thunk_self_update`, which `Regs` makes into `FORCE`, `ENTER`, `BLACKHOLE` and `UPDATE` (`results/E2/delay/Chs/lazy.sml`, `patches/E2-all-forms.patch`). *SML* above holds for C as for G: C moves the same fingerprints, and the register set's opcode table with them (D13).

**Measured and decided (owner, 2026-11-10): B, as M9 landed it.** C was built on the register VM (branch `hs-r-d3`, `47a9f3c36`): `Force` a fifteenth step of Mid, and D6's C, a `Thunks` group of suspension codes, for recursive ones. On every program measured C gives B's bytecode byte for byte: the 115 lazy ports at `-O0` and `-O2` (`--count` 236.618 G and 469.038 G under both), E2's kernels and E5's four under both lowerings. D6's C saves 7 to 14 instructions and 24 to 64 bytes a recursive binding (30 knots: 420 and 210 instructions at `-O0` and `-O2`). The compiler's image grows by 0.79% and its own compile by 0.03% at tier 2. C is not taken; the branch is kept as the record (`impl/r/d3/` in the drafts).

**To be measured:** C, a `Force` right-hand side, built and benchmarked against B with form C, with D6's C, a recursive form in Mid, for that variant. The owner takes C over B, or not, on the numbers (*Decisions on the numbers*). Lands in M9, and the variant is built there too, after M6's walkers.

### D4. `Any` against extending `Ty`

`Ty.view` has no type headed by a variable and no forall (`core/ty.sml:27-33`), so Haskell's `m a` and a dictionary with a
polymorphic method cannot be written in Mid. How do they cross?

Whichever option is taken, **`Any` means evaluated, of unknown type, and a lazy polymorphic position is `susp Any`.** If
`Any` could hold a thunk, a cast from it would itself have to force, and a forgotten force at a polymorphic position would
be invisible (X2; *What the literature says*, D4). Strict Core takes the same rule: `{a}` is the thunk and `a` is not.

- **A. None.** `Any` is an abstract tycon that rhc declares; `unsafe_cast` at each boundary, a real primitive call at tier
  2. No file of Rune changes.
- **B. Small.** A, with `unsafe_cast` erased in `Lower` (`backend/lower.sml:987-990`, `runtime/prims.c:2365`), and a debug
  assertion after a cast (D5).
- **C. Large.** `Ty` gains variable-headed application and a forall in fields. `Ty.view` is used in 18 files and its
  constructors are named in 19, and passes that read types would each need a rule for them.

**The evidence before E4.**
- E1's `monad` has casts on 25 of its 274 lines (`results/E1/prog/monad.mid`). In `knot`, 12,164 of 12,229 primitive calls
  at tier 2 are `unsafe_cast`, and 305 of 327 in `monad` (`out/jitstats.txt`). Those figures are under form A, whose force
  is itself a cast, so under form G most of them go [deduced].
- `nest_any` shows polymorphic recursion typed at `any`, 45 of 45 on master, which is a way past D5's Simplify fault with
  no change.
- `Any` on every slot, as an upper bound, costs 1.19 by geomean and 1.39 at most on 16 ports (E2, `tables/any-cost.txt`,
  the stage with `ms_trusts` answering 0). rhc pays it only on slots still `Any`: a forced and cast value is trusted [V's
  inference].
- The nearest precedent is SML/NJ's FLINT, a strict typed IR casting to and from `void` through typed `WRAP` and `UNWRAP`
  (`smlnj/compiler/FLINT/reps/rttype.sml:59-60`). TIL carried rich types to the bottom and paid eight times in compile
  time.
- E4 was to flip this if casts blocked method inlining.

**E4's result: the flip fired, then dissolved.**
- *Casts and inlining.* Stock Simplify does not see through a cast: a method at a locally built dictionary costs 16 to 23
  VM instructions against 7 folded (`results/E4/simp.out`). A +50 patch folds them all, and on `state` and `foldm` at E5's
  steps `D0` and `D1` it changes nothing (`results/E4/simpreal.out`). Real dictionaries are global `Val`s, and Simplify
  knows the value of a local variable alone (`core/simplify.sml:472-473`). So casts are not the blocker, and method
  inlining belongs in Core (D47, D49). At steps `D2` and `D3` the patch saves `foldm` 2.7% and 2.5% of VM instructions, by
  its rule for a force of a value cast to `susp` [inferred]: no `any` cast is left there.
- *How many.* `any` casts are 0 to 2.2% of nodes at step `D0`, and specialisation leaves none. Casts of a value into a
  `susp` slot are about 9% of nodes, and stay under every option here (`results/E4/casts.out`).
- *Their price.* Kept over erased at `-O2`: 1.03 on `queens` and `foldm`, 1.05 on `state`, 1.14 and 1.18 on E1's
  ref-encoded `monad` and `knot` (`results/E4/e4.tsv`). Form G already took out the hot cast, since force needs none.
- *A forgotten force.* Plain, it is a wrong answer at tier 2. Erased, it is a fatal on every engine, since `RAny` keeps its
  tests. A lint that no cast leaves a `susp` refuses it, though through a type variable only at `-O2`. `any_check` stops
  it on every engine, at +3% to +18% over erased, which is the price of keeping casts (`results/E4/neg.out`, `e4.tsv`).
  The lint refused none of 90 compiles of legal output (`results/E4/w9-lintpos.out`).
- *Extending `Ty`.* 96 `Ty.view` sites, 82 ending in a catch-all (`results/E4/tyview.out`, a heuristic), and 300 to 500
  lines over 12 or more files [estimate]. It buys MidLint a view of what CoreLint sees, no speed, and leaves every cast
  into `susp`.

**Recommended: B, with a lint.** `Any` stands: evaluated, with a lazy polymorphic position as `susp Any`. The cast is
erased in `Lower`. That takes more than the cast: a Lower rule dropping a force of a known non-thunk, and a `RegVerify`
exception that lets `CALL` see a non-closure on force's slow path (`patches/E4-cast-modes.patch`, 3 files, +45, which holds
four modes). The lint that no cast leaves a `susp` runs always (`patches/E4-cast-lint.patch`, +7). `any_check` is D5's
assertion after a cast, in test builds. *SML.* The compiler compiled with casts kept and erased is byte-identical
(`results/E4/rbc/`), and that is no evidence: the compiler has no such cast to erase [deduced, *The experiments*, E4]. What
is known is E4's table, on programs that do cast, so M9 must test such programs. The lint has not been run over SML's own
Mid.

**Against.** C alone lets Mid's own lint see a polymorphic position. Under B the boundary is trusted: `neg_poly` passes the
lint at `-O0`, so between a forgotten force and a wrong result stand CoreLint and a test build. E4's casts come from
`mrhc.py`, which makes them by comparing types, on two monadic kernels; a real Core to Mid will have bugs that lowerer
does not.

**What would reopen it.** A wrong answer at tier 2 on output CoreLint passed. `any_check` firing on the corpus. The lint
refusing legal code on SML's Mid. The owner taking the other side of D47, when Mid would have to read through casts and
global dictionaries. Lands in M9: the erasure, the lint and `any_check`, with the primitives they concern. None is in M7,
and M10 is what emits the casts.

**Decided (owner, 2026-11-09).** C, against the recommendation: `Ty` gains variable-headed application and a forall in fields. The owner's reason: "safest and also useful for higher-rank and higher-kinded type in rune". The section above stays as the evidence it was written on.

*Lead's note.* E4 sized C at 300 to 500 lines over 12 or more files [estimate], with 96 `Ty.view` sites, 82 of them ending in a catch-all (`results/E4/tyview.out`, a heuristic), so it lands after D10's walkers, in M28, before M10. `Any` stays for what `Ty` cannot say, and still means evaluated. Value-to-`susp` casts remain, 117 to 124 a program at E5's step `D0` (`results/E4/casts.out`), and with them the erasure in `Lower` and the lint that no cast leaves a `susp`, which C does not replace [inference]; C removes the `any` casts. Since build-system-v2's M5 Mid's codecs are generated: `Ty.ty` is described at `tools/codecs/compiler.sml:168-176` (origin/master `697724da5`), so a new form of `Ty` is described there and `make codecs` run.

*From the papers (E15b).* With type variables in Mid the roadmap must say whether one may be instantiated at `susp T`: never, as Strict Core has it for `Any`; Launchbury and Paterson's `Pointed` class, with `seq` only at lifted types, is the alternative (*What the literature says*, D4).

### D5. The evaluated-datatype invariant

**A datatype-typed variable is evaluated.** `removable`, `Workers`, the constructor folds and tier 2's `ms_trusts` all
rest on it (*What strictness gives each IR*), and `results/E11/contract.md` lists it with "nothing" under *Checked by*. It
holds by types if a lazy position has a distinct type (D3). What enforces it?

- **A. None.** A rule in the contract, nothing more.
- **B. Small.** **Recommended.** Write it in `docs/ir.md`, stated site by site as Peyton Jones, Launchbury 1991 §9.2 do:
  `Let`, `fundef` and `Join` parameters, `Decon`, `Select`, `ExnArg`, `Handle`'s variable, globals, and `Any` by D4. Lint
  where a lint can reach, and fix what E1 found. The lints are small [inferred], and none is prototyped:
  - `ConTag` only of a datatype: today any `Ty.Con` passes, `susp` included (`core/midlint.sml:271-272`);
  - forward reads of a `Val`, which reach the engine (E1, `results/E1/out/neg/unset.txt`);
  - an abstract type's arity, which `MidText` reads and drops (`core/midtext.sml:648-650`);
  - a debug assertion after a cast, which is D4's `any_check` and lands with it in M9;
  - the two Simplify fixes E1 found, in `core/simplify.sml` alone, +10 -4 (`patches/E1-simplify-polyrec.patch`):
    `makeCopy` and `staticParams` ignore type arguments, which SML cannot reach and polymorphic recursion does, and `=` on
    a non-uniform datatype overflows the compiler's stack at `-O2`, which plain SML reaches
    (`results/defects/equality-nonuniform/`).
- **C. Medium.** A checked `Any` at run time, which does not exist yet. E4 prices one (D4).

**The evidence: where the rule stops.** E1's negative programs, four engine modes at each of `-O0` and `-O2` and lint
levels 0 and 2 (`results/E1/out/neg/forget.txt`), observed:

| A forgotten force | `--lint=2` | Interpreter, tier 1 | Tier 2, `--checked` too |
|---|---|---|---|
| before `Decon` | refused: "has type int hlist susp where int hlist is wanted" | at lint 0, fatal | at lint 0, fatal |
| before `ConTag` | passes | fatal | fatal |
| behind `unsafe_cast` | passes | fatal | **exits 0 with output** |

- E2 adds two more (`tables/wrongslot.txt`, `wrongslot-F.txt`): a thunk in a slot typed list, tuple or `ref` is a silent
  wrong answer at tier 2 alone; and under form G a thunk in a function-typed slot passes every engine, since a thunk is a
  closure. There MidLint is the only defence (D11).
- A forward `Val` read is a fatal at run time. For a function value read before its `funs`, `-O0` stops and `-O1` prints 7
  (`unset_fn` in `unset.txt`), so the levels disagree on an ill-formed program.
- The default lint level compiles ill-typed Mid silently: `nest_trust` before the fix (E1).
- *SML.* A lint adds no byte to a program. The Simplify fixes hold bytes: the compiler compiled itself to identical bytes
  at `-O1` and `-O2` (`results/E1/out/selfcheck.txt`), and they are in `simplify.sml` alone. No lint in the list has been
  run over SML's own Mid, so `ConTag` to datatypes may need an exception [inferred].

**Against.** A lint that stops at a cast gives comfort it has not earned. The bug that matters, a forgotten force behind
`Any`, passes every rule here. The real defence is CoreLint and a correct Core to Mid, and a run-time check under test is
worth more than the lints.

**What would reopen it.** `any_check`, at E4's +3% to +18% over erased, proving cheap enough on the corpus to leave on under `RUNE_LINT=2`. A wrong answer at
tier 2 on output CoreLint passed, which would raise this to C. Lands in M7.

**Decided (owner, 2026-11-09).** B, as recommended: the invariant written in `docs/ir.md`, site by site, and linted where a lint can. And C, "for checked builds/vms only if no perfomance impact on non-checked versions": a checked `Any` at run time behind a compile-time switch, as E4's `any_check` was, shown to leave a build without it byte-identical and its `--count` unchanged. The lints land in M7, the switch in M9.

### D6. Recursive values and CAFs

Mid cannot say a recursive value or code with no parameter: `Fun` binds functions, `Let` is not recursive
(`core/mid.sml:64-65`), and a function has at least one parameter (`core/midlint.sml:333`). How do `xs = 1 : xs` and a CAF
reach it?

- **A. None.** **Recommended.** A thunk's code takes `unit`. A recursive value goes through a cell: make the hole, build
  the closures, patch it. E1's `ghole` and `gpatch`, and E2's `knot` in each delay module. A CAF is a thunk in a global,
  made by a `Val` in source order, whose code reads other globals when it runs and not when it is made.
- **B. Small: recursion through the closure.** Not built. Under form G a thunk is a closure, so a `Fun` group of unit
  functions, marked after it is made, is a cyclic group of thunks with no cell, given a cast in each body [inference]. It
  saves a cell a binding, and it puts thunks back in `Fun` groups, where `inline` can reach them.
- **C. Medium: a recursive form in Mid.** Thunks in `Fun` groups as a form of their own, or a recursive `Let`. Not built.
  An arm in the walkers, and D10 first.

**The evidence.** E1's `knot` runs `xs = 1 : map (+1) xs`, mutual `evens` and `odds`, and a sharing count; `cafs` runs
mutual CAFs, a CAF on a later CAF's value and an unforced `error`; each 45 of 45 (`results/E1/matrix-base.txt`, so with no
change to Rune but `readMid`). E2's `knot`, on real thunks, is linear only if every cell is shared, and gives the same
answer under every form (`tables/semantics.txt`) and in 84 stress runs (`tables/stress.jsonl`). GRIN sketches the same
hole then update (Boquist 1999, §2.5.5).

Dictionaries are the case that bites. A method that is no function, such as `maxBound`, makes a dictionary field that
refers to its own dictionary, and floating a sub-dictionary out of a method is an infinite tower if strict under
polymorphic recursion [inference from the schemes in *What the literature says*, D6]. So dictionary fields are lazy in
Core and thunks in Mid. E1's workaround stands: instance globals read themselves at call time, and dictionary functions
patch cells.

*SML.* None: no file of Rune changes, so no budget or byte moves.

**Against.** A cell is a `ref` and an option for each recursive binding, read when its body runs, for what a real
recursive form does with neither. Every dictionary with a cycle pays it. And a forward read of a global is a run-time
fatal that no lint sees (D5), so the rule that a `Val` of a CAF makes a delay and reads nothing is Core to Mid's to keep,
with only D5's new lint behind it.

**What would reopen it.** Recursive bindings hot in E5's kernels or on the corpus. D3's option C, which would make C here
cheap. Lands in M10.

**Decided (owner, 2026-11-09).** A, as recommended: recursion through a cell, CAFs as thunks in globals. For D3's measured variant, a `Force` right-hand side, the owner chose C here: "For the D3 = C (a Force right-hand side) variant please us C (a recursive form in Mid)". That form is built with the variant in M9, after M6's walkers, and measured with it (*Decisions on the numbers*). A lands in M10.

### D7. Lambda

Should Lambda change, given that no front end enters there? The review is in *The IRs, reviewed*.

- **A. None.** It stays as it is.
- **B. Small.** **Recommended.** It stays, is said to be private to SML, and `Try` and `Fail` may go: `MatchComp` makes
  `Join (j, [], rest, rule)` instead. E11-10, 1 file, +22 -6 (`results/E11/sizes.tsv`). The constructors stay in the
  datatype unused until a further step takes them, a rule out of `LambdaLint` and a state out of `ToMid`.
- **C. Large: remove it.** `Translate` and `MatchComp` build Mid through a builder. It saves `core/lambda.sml`, 268 lines,
  and `core/lambdalint.sml`, 255. It costs the last place where a program is a tree: 224 and 115 occurrences of Lambda's
  constructors become continuations (E12, `results/E12/occurrences.tsv`), and a boundary lint goes.

**The evidence.** E11-10 moves no byte of the compiler at any level on either target (`results/E11/verify-summary.txt`).
It changes four expected Lambda dumps in `tests/ir`, `(try` to `(join`, as it must (`results/E11/ir-try-diff.txt`). No
budget moves [deduced from identical bytes]. C buys Rune no speed E12 can show. rhc wants only `ToMid`'s builder, worth
lifting out when M10 is written.

**Against.** B is a tidy that rhc does not need, and four dumps to review. It rides on this roadmap only because the brief
asked for a review of the IRs.

**What would reopen it.** `Translate` needing to be rewritten for another reason would change C's price. Lands in M4, if
taken.

**Decided (owner, 2026-11-09).** B, as recommended: Lambda stays, private to SML, and `Try` and `Fail` may go (E11-10). E11-10's change to `core/matchcomp.sml` still applies to origin/master `697724da5`; its line in the test build list, `tests/compiler/mid-only.build`, which E11-9 creates, does not (`git apply --check`, run while recording this). Lands in M4.

### D8. Mid `Case`

Mid has no match: a test is `ConTag`, an equality primitive and `If`, and `Lower` recovers the table. The full account is
in *The IRs, reviewed*.

- **A. None in this roadmap.** **Recommended.** rhc's match compilation is its own, in Core (D34), and reaches Mid as the same tests [deduced].
- **B. Small.** A single `Mid.tagTest` view shared by `Lower` and `LowShapes`, the cheap half of `Case`.
- **C. Medium: for a later roadmap, after D10.** A `Case` in Mid, for clarity and compile time. Not built. An arm in at least 88
  walkers, in `MidText`, `MidCodec`, `UnitMid`, `MidCanon` and `Fault`, and a change to Simplify's rounds, which is where
  the risk is.

**The evidence** (E12, the compiler at `-O1`, static). 12,061 of 12,064 tag tests are recovered, and 472 of 484 chains
become `Switch`. Only 31 tests are answered by a dominating test, so `Case` would save no code. It would save 11.7% of
Mid's nodes, or 16.7% if arms bind what `Decon` takes [deduced], 96 lines of peephole in three places that must agree, and
a guard on `Decon` that MidLint could state. *SML.* No bytes should move if `Lower` lowers it as it does now [deduced]; no
compile with a `Case` was made, so the compile time saved is not measured.

**Recommended: A.** Nothing in rhc asks for `Case`, and it is the riskiest edit on this list. It stays recorded as medium,
for clarity and compile time, for a later roadmap.

**Against.** The gain in clarity is real, and waiting leaves the peephole in three places that must agree.

**What would reopen it.** A later roadmap taking it up after D10, which should first make a compile with `Case` to show the
time saved. rhc's Mid turning out to be tag tests in a proportion that changes the sums. It has no milestone here.

**Decided (owner, 2026-11-09).** C, against the recommendation: a `Case` in Mid, now and not in a later roadmap. The owner's reason: "let's fix it now instead of later". The section above stays as the evidence.

*Lead's note.* It comes after D10's walkers, since it adds an arm to at least 88 of them. Bytes and budgets may move, since `Lower`'s own reconstruction of the table gives way to the node; the milestone says by how much, under the standing gate. `Case` is a new constructor of `exp`, so it is described in `tools/codecs/compiler.sml` (origin/master `697724da5`, `exp` at `:222-232`). Lands in M29.

### D9. Multi-value return

Mid's `Return` gives one value (`core/mid.sml:71`), and `RET` gives one, which `RESULT` takes (`src/isa/regs.sml:247`).

- **A. None.** **Recommended.** Four attacks on tuples already exist (*The IRs, reviewed*).
- **B. Large.** `Return` of several atoms, a `Let` of several variables, `Low.Return` of a list, and `RET` and `RESULT` of
  several in both instruction sets. Not built. 126 walkers and two instruction sets. It would retire `Slot`, the facts in
  `Pipeline.lowered` and `LowLint.results`.

**The evidence** (E12). In a whole compile it wins what results in globals wins already. What it adds is that gain in
units, where results in globals does not run (`backend/lower.sml:849`): by the whole-program figures, 4.4% of the
compiler's allocation and up to the benchmarks' rises [deduced], and in instructions nothing. CPR pays only where a
function allocates the product (Baker-Finch et al. 2004). *SML.* B moves both instruction sets' fingerprints, and budgets
with them [deduced]; A moves nothing.

**Against.** Results in globals stops at units and at tuples. rhc will build in units, and user single-constructor types
were a large share of strict arguments in Peyton Jones, Partain 1993, so `workers` and `results` will miss them unless
Core lowers them as tuples [inference].

**What would reopen it.** rhc's own measurements of unboxed returns, once track P runs. After D10 the price falls and it
is worth asking again. It may not ride on this review.

**Decided (owner, 2026-11-10).** To be measured: B, multi-value return, built and measured against A, today's four attacks on tuples; then A or B on the numbers, as for D15. The owner's answer: "land behind a measurement". It supersedes the answer of 2026-11-09, "B (let's do it now instead of later)". Until the owner adopts B, A stands. Built in M30 on the register VM, and landed only if adopted (*Decisions on the numbers*).

**Measured and decided (owner, 2026-11-10): A, today's attacks on tuples.** B was built on the register VM (M30, branch `hs-a-m30`, `8ce317123`): Mid's `Values` and `Lets`, the pass `values`, Low's `RetVal` and `ReturnN`, and the instructions `RETN` and `RETV`. On Rune's compiler compiling itself, with `results` on as today, values adds nothing (-0.03% instructions at tier 2, bytes unchanged); in place of `results` it wins back only part of `results`' saving (bytes -0.64% against neither's +4.63%). On 22 numerical benchmarks both together allocate about 2% less on f-arith and the mandelbrot family. In rhc's shapes (E5's kernels, E1's programs) the pass finds nothing, since pairs pass through closures, dictionaries and suspensions. M30 does not land; D25's token keeps its pair as a tuple. The branch is kept as the record (`impl/a/m30/summary.txt`).

*Lead's note.* E12 found that in a whole compile it wins what `results` already wins, and the rest only in units, where `results` does not run. Landed, it touches 126 walkers, both bytecodes, the JIT and runeopt, and moves both fingerprints; the build for measurement is Mid, Low and the register set, its interpreter and JIT. D25's state token does not wait on it: until B is adopted the token's returned pair is a tuple, or erased. Since every `IO` action returns that pair, rhc's programs are measured as well as Rune's compiler and benchmarks.

### D10. Walkers

Mid has no walker of its own, so each pass writes its own (*The IRs, reviewed*). A new step of Mid means at least 38
walkers, and 28 of those 38 end in a catch-all, as do 43 of the 88 over `exp` (E12, `results/E12/walker-defaults.tsv`;
lower bounds).

- **A. None.** rhc needs nothing here under D3's recommendation, since a primitive has an arm in every walker.
- **B. Small.** **Recommended, for Rune alone.** `Mid.atomsOfRhs` and `Mid.mapRhs` first: 25 of the 38 reduce to the one
  and 12 to the other (`results/E12/walker-shapes.tsv`, an estimate by shape). 12 files hold the 38 walkers, 479 lines to
  shrink (`results/E12/walkers.tsv`). Not prototyped.
- **C. Medium.** A `Mid.fold` over `exp`, a second step, only where a walker's arms are all the default.

**The evidence.** Some are the same function under two names (`core/lift.sml:31`, `core/refs.sml:27`). The risk is not the
lines: a new constructor falls into `| _ =>` without a word, as having no atoms (`core/lift.sml:45`), as using nothing
(`core/simplify.sml:73`), as removable (`core/simplify.sml:115`). *SML.* Bytes held by construction, and so budgets
[deduced, not prototyped].

**Against.** rhc does not need it, so it is scope (X6). If nothing adds a step to Mid, the catch-alls never fire.

**What would reopen it.** The owner taking D3's option C, or D8, makes it first and required. Lands in M6.

**Decided (owner, 2026-11-09).** C, now, going past the recommendation of B: `Mid.atomsOfRhs` and `Mid.mapRhs` first, then a `Mid.fold` over `exp`. The owner's reason: "let's fix it now instead of later". It comes first of D4, D8 and D9, since each adds an arm. Lands in M6.

### D11. The thunk object

What is a thunk at run time, and what does it become? Forms are as in *The experiments*. Machine instructions per
operation are less the loop (`tables/micro.txt`); the ratios are the ports at `normal` against form C, all ports and the
densest 20 (`tables/summary.txt`, 113 of 115 ports, those passing under every form); lines are V's hand count of
`patches/E2-all-forms.patch`, whose whole is 39 files, +1,051 -73 with generated tables.

| Option | Form | Against C: all, densest 20 | Worst port | Delay | Delay and first force | Evaluated force | Bytes a delay | Hand-written lines |
|---|---|---:|---|---:|---:|---:|---:|---:|
| none | A, Haskell's reading: a `ref` of a datatype | 1.364, 1.270 | `ansi-lazy` 2.656 | 69 | 97 | 27 | 64 | 0 |
| medium | B in line: `K_THUNK` holding a closure, primitives done in line | 1.110, 1.095 | `fft2-lazy` 1.392 | 60 | 110 | 29 | 48 | ~165 |
| **small** | **G: `K_CLOSURE`, non-zero `contag`** | **1.048, 1.065** | `knights-lazy` 1.196 | 60 | 109 | 24 | 32 | ~255 |
| small | L: G, the collector releasing | 1.043, 1.052 | `knights-lazy` 1.191 | 60 | 106 | 24 | 32 | ~305 |
| large | C: flat `K_THUNK`, four instructions | 1.000 | | 63 | 102 | 13 | 32 | ~305; ~420 with parity [estimate] |

Each count of lines includes about 45 shared by all but A: `runtime/value.h`, `image.c`, `share.c`, `census.c`, `minor.c`,
`mark.c`, `types.sml`, `env.sml`. E2's delay captures two values, so 32 bytes is the header, the function and two fields
[deduced from `runtime/value.h`]; a thunk of k captures is 16 + 8k bytes.

**Recommended: `K_CLOSURE` with a non-zero `contag`, unevaluated or under evaluation; evaluated is `K_IND`.** `K_CLOSURE`
with `contag` 0 is a function. `CALL`, `ENV`, `SELF` and the runeopt templates stay as they are, and an image needs only
what `K_IND` needs, below. The update is in the thunk's own code, so hot `RET` is untouched. **`K_THUNK` is not needed,**
and heap-layout's reservation of it can be released (`docs/plans/heap-layout.md:5075-5078`, `runtime/value.h:68-73`),
which frees one of the fifteen kind values.

**The evidence.**
- *Bytes.* C, G and L allocate 564 GB on the ports, B 632, A 898 and the shipped module 901 (`tables/summary.txt`).
- *What changes in the collector and images.* `obj_scanned_fields` (`runtime/value.h`) now reads a closure's `contag`, so
  the collector skips a blackholed thunk's fields, which is the mechanism of release. Every part that reads a kind takes
  one past `K_LAST` for corruption (*What thunks exist today*), so `K_LAST` moves, and `put_object` and `share.c` stop
  reading an indirection's dead fields, and `runtime/image.c:906` accepts a frame whose closure has been updated
  (`results/defects/latent-k-ind/`; `image.c` is +4 -2 in `patches/E2-all-forms.patch`). M26 adds the shortcut's guard, below. Evaluated,
  unevaluated and under-evaluation thunks restore from an image on every form tried, G and L among them
  (`tables/image.txt`).
- *The shortcut.* The collector's `K_IND` shortcut has no guard (`runtime/gc/minor.c:151`, `runtime/gc/mark.c:155`). A
  forced outer suspension ran its inner one after a collection (`tables/nested.txt`). Haskell cannot reach this and
  `'a susp susp` can, so the guard is lazy ML's, and it must look through forwarding. G's and L's figures include it. It
  costs 1.0084 under Haskell's reading and 1.0090 under lazy ML's by geomean, at worst 1.055 and 1.058, both on
  `fulsom-lazy`, unexplained (`tables/guard-cost.txt`). A strict program has no `K_IND` to test [deduced].
- *The pin.* A lazy ML body can outlive its own update. With a collection between the two updates the shortcut gives the
  frame's closure slot the value: on V's collector 162 of E14's 1,302 runs fail, on the register engine by overwriting the
  value, on the stack engine silently (`results/E14/tables/matrix-V-collector.txt`, `results/defects/ind-not-final/`).
  Reading captures at entry does not help. `gc_pin_running` does: at each collection, a `K_IND` a frame still runs is not
  shortcut. It costs 1.0003 on 115 ports as patched and 1.0036 before the shortcut's test was forced in line, where no
  shortcut at all costs 1.075, and up to 2.47 times in RSS (`results/E14/tables/portcost-final.txt`, `portcost.txt`).
  Haskell cannot reach this, since a blackholed thunk has one run. The pin returns at once in a program that blackholes
  [read], so it is lazy ML's, as the guard is.
- *Others.* nhc98 is the nearest precedent for a bytecode VM with thunks, and jhc's wrapper for the update. All eight
  systems tabulated remove indirections in the collector (*What the implementations do*).
- *SML.* D3's figures: identical `--count` on 12 strict ports, 1.0056 in machine instructions. The test falls on every
  object the collector scans, since `obj_scanned_fields` now reads a closure's `contag`. It is the one cost a strict
  program pays for this.

**Against.** A thunk that is a closure passes every engine in a function-typed slot (`tables/wrongslot-F.txt`). Under
`K_THUNK`, `CALL` would stop it; under G only MidLint does (D5). That is a real loss of defence in depth, bought with one
kind value that is otherwise spare.

**What would reopen it.** A bug of that class on the corpus. Selector thunks needing a kind of their own. A new front end
for which a closure and a thunk must differ in the header. Lands in M9; the guard and the pin, in M26.

**Decided (owner, 2026-11-09).** C, against the recommendation: a flat `K_THUNK`, entered by four instructions, `FORCE`, `ENTER`, `BLACKHOLE` and `UPDATE`. The owner's reason: "cleanest and most performant". `K_THUNK` keeps heap-layout's reservation. The section's case for G stays as the evidence.

*Note.* The changes to the collector and images above are shared by every form but A, so they land under C too, about 45 lines of the table's ~305. The loss of defence that *Against* names does not arise: `CALL` stops a `K_THUNK`. The guard on the shortcut and the pin stay lazy ML's and go with M26, unless D17's B makes the pin Haskell's too (*Decisions on the numbers*). Lands in M9.

### D12. Release, blackholing, raise

Haskell's thunks and lazy ML's differ in releasing the closure, not in raise or re-entry: "When evaluated, errors cause
immediate program termination and cannot be caught by the user" (3.1, R36), so re-run against memoise is unobservable, and
looping on re-entry conforms. What is needed is release by the next collection, and nothing of blackholing. The Report
itself sets no space bound (X5): release is what lets the corpus run. Rune fails it as it stands, since a frame's closure
is a root while the function reads it (`README.md:116-119`), and code reads captures through it (`ENV`,
`src/isa/regs.sml:223-227`).

**The owner's choice is between two forms.** Both release, and both read captures at entry (`Low.hoistEnv`).

| | **G. Written at entry (small). Recommended** | **L. The collector releases (small)** |
|---|---|---|
| A thunk's first act | `thunk_fbh`: the running closure goes under evaluation | `thunk_lchk`: reads the state, writes nothing |
| Delay and first force | 109 | 106 |
| Ports against C: all, densest 20 | 1.048, 1.065 | 1.043, 1.052 |
| Sum of machine instructions, billions | 3,145 | 3,125, 0.64% less (0.55% by geomean) |
| Retained on `last` and on `leak` | 0 and 0 bytes an element | 0 and 0 bytes an element |
| Re-entry | detected at once | after a collection; before one it runs again |
| Collector | D11's changes alone | D11's, and a hook of about 14 lines and a walk of frames at every collection |
| Rune, on top of G | | about +50 lines, the hook and two primitives |
| Under the low-pause collector | a slow path that shades the fields | release skipped while marking; not established |
| Lazy ML's difference | release unset: the body says no blackhole and there is no bit, plus the collector's pin (D11); E14 ran this | one collector-read bit and the entry check with it, and the pin [inferred]; not run |

Sources: `tables/micro.txt`, `summary.txt`, `last.txt`, `lreenter.txt`; lines by V's count. C and F ran on one stage, B
and G on another, L on a third (`results/E2/INDEX.txt`); C rerun on G's stage changes nothing that matters (E2). L's stage walks frames at every collection, which G's does not
need, so its 0.64% is L against G as each would land. On L's stage G pays the walk too, +0.19% by geomean, and there L
saves 0.73%. Against G by port L runs from -1.48% (`lcss-nofib-lazy`) to +0.81% (`transform-lazy`), recomputed from
`results/E2/results-LhZ-normal.jsonl` and `results-GhY-normal.jsonl`.

**The evidence.**
- *The leak is real.* A collection at every allocation, bytes kept an element (`tables/last.txt`). Under Haskell's
  reading, forms A and B keep 56 and 40 on a non-tail body. B with the drop, C, G and L keep none. At n = 1000 form A is
  6,993 words over the base against G's 1. Lazy ML's forms keep 56 (B 40) on both kernels, and must, since a body may run
  again.
- *Clearing the thunk is not enough.* The frame's closure slot holds the captures. Peak RSS at n = 4 x 10^6: 231 MB for A,
  101 MB for B and for C and G under lazy ML's reading, 8.2 MB released (`tables/leak.txt`). The drop halves instructions
  on that kernel: 2.95 billion to 1.37 billion under G.
- *What release costs.* First force +6 to +10 instructions, ports +1.5% (C), +2.5% (G), +1.9% (L) against their lazy ML
  twins (sums, `tables/summary.txt`).
- *A third way, for forms A and B only.* A frame's closure a root only while later code reads it: about 25 lines, no
  compiler change, 1.0002 on 12 strict ports with identical `--count` (`tables/closurelive-cost.txt`). It clears the leak
  for A and B, and does nothing for C, G and L, where the update needs the slot. It should help SML closures too
  [inferred, not measured]. It is not needed if G or L is taken.
- *The literature.* Release at entry is unnecessary (Peyton Jones 1992, §9.3.3). Marlow, Peyton Jones 1998 made lazy
  blackholing GHC's default, calling the entry store "gallingly expensive". Jones 1992 is the leak: 5,211 words against
  223. Detection is optional in practice as in the Report: of the four systems run, nhc98 and GHC report a loop, Hugs and
  MicroHs overflow (*What was run*).

**Raise repair: not for Haskell 98.** A raise leaves a blackhole, and the next force says a false `<<loop>>`
(`tables/semantics.txt`, `raise-repair.txt`). An 11-line frame walk marks each cut thunk failed so that it raises again,
at two sites, `vm_raise` and `emit_RAISE`'s inline cut; it works on C, F and G because the frame's closure is the thunk.

No Haskell 98 thunk outlives a raise. `catch` takes `IOError` only (7.3, R36). `error` ends the program, closing handles
first (R37). An `IO` action runs inside a thunk only through lazy input, and 21.2.2 makes that thunk end its list rather
than raise: "Any I/O errors encountered while a handle is semi-closed are simply discarded." [inference]. Two things must
hold for that inference: `IO`'s bind runs an action in a function, never in a thunk (D25); and `error` forces its message
before anything is cut, since a message forced after the raise can re-enter what the raise left [inference]. nhc98 and jhc
have no raise path through a thunk at all. So the walk, `THUNK_FAILED` and a closed thunk's spare field stay out [deduced
from the patch]. Lazy ML does not need them either: its body does not blackhole, and E2 shows it re-run with no repair
(`second 42 runs 2`, `tables/semantics.txt`).

*SML.* As D3. G adds nothing to the collector for a strict program beyond D11's test. L's hook returns at once where no
function of the program blackholes [deduced from `gc_release_thunks`].

**Recommended: G.** It detects re-entry at once and every time, which makes a loop a diagnosable event in testing, and it
adds nothing to the collector beyond D11's changes. The gain from L is 0.6% on the ports, and 0.2% to 1.6% on E5's output
(`results/E5/formc.tsv`).

**Against G, for L.** The literature's whole direction is L's: the entry store is a cost paid on every first force for a
diagnostic the Report does not ask for. L writes nothing, shares its body with lazy ML but for one bit, and is GHC's form.
And 0.6% is on ports whose delays are hand-placed; on E5's output, at about twice their density, it is up to 1.6%. **Against L.** Without a write at
entry, `x = 1 + x` ends in a stack overflow or a black hole according to when a collection strikes, and against a 1 GiB
stack that is slow to reach [inference]. It is worse than G on some ports, +0.81% on `transform-lazy`, and it is more code
in a collector with no second user.

**What would reopen it.** rhc's measured output taking L's saving well past E5's 1.6%. A need for the low-pause collector
under rhc, which L has not shown. Anything that makes `error` catchable, such as `Control.Exception`, brings the repair
back. Lands in M9.

**Decided (owner, 2026-11-09).** Not applicable: "I decided on Form C" (D11). Under form C a thunk's code reads its captures and says `BLACKHOLE` at entry, so re-entry is found at once and the captures are released then: E2's `last` leak is cleared on C (`tables/last.txt`). No raise repair for Haskell 98, for the reasons above. Lazy ML's reading, without blackhole or release, is form C's `CmX` in E2, and D57's checklist runs again on it (M26).

### D13. Library, prims or instructions

How is force made, on the register target? The options and their figures are the table in D11.

- **A. None: a library over refs.** Form A, 0 lines. 1.35 under lazy ML's reading, 1.36 under Haskell's.
- **B. Small: primitives done in line, force one Mid node.** **Recommended.** Form G. Two variants are rejected: F, a
  library `force` over the same primitives, at 1.169 (D3); and primitives left in C, form B at 2.116 and 3.067 on the
  densest 20, which is what makes in-line primitives part of the option.
- **C. Large: four instructions.** Form C: `FORCE`, `ENTER`, `BLACKHOLE`, `UPDATE` on the register set. About 260 lines
  over those shared, by V's count: `src/isa/regs.sml` 42, `emit.c` about 70, `compile.c`, `compile.h` and `masm.h` 18,
  `prims.c` 12, `src/isa/prims.sml` 14, `backend/regs.sml` about 55, `backend/low.sml` 48, `isa_regs.c` 2. About 115 more
  for parity, in `src/isa/stack.sml`, the Stack target, `x64.sml`, `native.c`, `every-opcode.rasm` and `docs/bytecode.md`
  [estimate, not built].

The medium option, form B in line, costs a kind and 16 bytes a delay, and gains nothing over G.

**Recommended: no new instruction.** G is 1.0481 of C on one stage and 1.0653 on the densest 20 (`results/V2/chy.jsonl`),
and 1.02 to 1.22 on rhc-shaped output, all four cells at `D3`+eta+strict `-O2` now measured (E5, `results/V2/formc/`). The
ground is three things. `FORCE` stays additive: it would change neither the object nor the protocol, so it can be added
the day a measurement asks. The gap is small against K, 1.02 to 1.22 beside 3.4 to 23. And C costs about 305 lines against
G's 255, about 420 with parity. Over strict twins, 109 pairs, the lazy forms cost 1.68 shipped, 1.17 under C and 1.23
under G.

**The evidence.** Beyond the table: on the ports G executes 303 billion bytecode instructions against C's 269 billion, 13%
more, for 5% more machine instructions, so `--count` overstates the gap (`tables/summary.txt`). C's `FORCE` is a jump on a
test; G's is two primitives and a branch. Nothing in the literature gives a threshold: E2's 30% was a first guess, no
paper sits behind it, and this decision does not argue from it. *SML.* No instruction means no opcode table moves. D3's fingerprint move applies; C moves the same
fingerprint and the register table with it. The 12 strict ports of D3 ran on a stage holding C's instructions, with
identical `--count`.

**Against.** Evaluated force is 24 instructions against 13, and most forces find a value (Marlow et al. 2007, Fig 2: 62%).
A whole-program 5% hides that gap, and it is measured on ports whose delays were placed by hand: at most 4,501 evaluated
thunks per million instructions, median 1,489 (`tables/summary.txt`). Lazy ports are not rhc: E5's output is about twice
their density at `D0`, and G is up to 1.22 of C there. Every bytecode system E15 read has an EVAL instruction, and none has
a library force. That does not decide it here. An EVAL saves an interpreter a dispatch, and those systems are interpreters
[inferred]; designs here are chosen at tier 2, where G's test, value read and `CALL` are in line, so its 13% more bytecodes
are 5% more machine instructions. But Rune owns its VM, so the reasons a JVM target gives for avoiding one do not apply,
and the interpreters do pay that dispatch.

**What would reopen it.** rhc's measured gap to C on the corpus proving large against K, on a line the owner sets. Fusing
G's test and value in tier 2 may close some of it first; not tried. Lands in M9.

**Decided (owner, 2026-11-09).** C, against the recommendation: four instructions, `FORCE`, `ENTER`, `BLACKHOLE` and `UPDATE`, on the register set, about 260 lines over those shared and about 115 more for parity (D14) [estimate, not built]. It is D11's choice, for D11's reason. The section above stays as the evidence. Lands in M9.

### D14. Stack bytecode and runeopt parity

The stack bytecode is read by `runevm-stack` and by `runeopt`. Must rhc's output run there?

- **A. None.** rhc refuses `--target=stack`. No lines. It loses the reference the `levels` oracle compares with, the stack
  bytecode's `-O0` (`docs/ir.md:1192-1204`), and native code.
- **B. Small: parity by G.** **Recommended.** `thunk_fforce` lowered in `backend/stack.sml`, +22 as built in E14
  (`patches/E14-lazy.patch`, against V's estimate of about 12), and nothing in `runeopt`: primitives go through
  `prim_table` (`docs/native.md:145`), and `fastPrim` is optional (`docs/native.md:185`). No row in `docs/bytecode.md`.
- **C. Large: parity by C.** About 115 lines [estimate, not built]: D13's list.

**The evidence.** Form F, the same object with a library `force`, passes 7 kernels under both readings on the stack VM and
in native code (`tables/F-stack-native.txt`): `chain`, `knot`, `share`, `raise`, `reenter`, `leak`, `barrier`. Form B ran
there too (`tables/stack-vm.txt`, `native.txt`). `Low.hoistEnv` is already called from the Stack target in the prototype.
In E2 `thunk_fforce` there was a fatal stub. **E14 built the lowering, and G ran through the Stack target:** the test, the
value and a `CALL`, as `Regs` has them. All 372 of its stack runs passed (`results/E14/tables/matrix-final.txt`), under
lazy ML's reading. Haskell's has run there only as form F, so that it needs no more is [inferred]. Lowering force in
`Lower` instead of in each target would make it one place, at the price of blocks in Low [inference, not built]. Marlow, Peyton Jones 1998 mix bytecode and compiled code by making both
agree on heap objects and frames, which Rune's two bytecodes already do. *SML.* No instruction; the stack set's
fingerprint moves as D3 says. Nothing measured the stack budgets; none should move [deduced].

**Against.** The lowering has not run under Haskell's reading, and neither G nor a call into C from native code for each
thunk primitive has been priced there. Designs here are chosen at tier 2 and other engines are informational, so A is defensible for a
language no one has asked to run natively.

**What would reopen it.** The Stack lowering failing under Haskell's reading. A wish for fast lazy native code, which
would want `fastPrim` entries and an owner. Lands in M9.

**Decided (owner, 2026-11-09; confirmed 2026-11-10).** The owner's rule, "B if it doesn't leak into Low; otherwise C", gives C: parity by form C, about 115 lines [estimate, not built], with the instructions on the stack set too, runeopt's templates, `tests/opt/every-opcode.rasm`, `x64.sml`, `native.c` and rows in `docs/bytecode.md`. The owner confirmed C on 2026-11-10: "D14: C".

**The owner, 2026-11-10:** the stack VM keeps `last`'s dead suspension alive (48 to 56 bytes an element), because it keeps every local of a waiting frame; the register VM releases it (M9). It is not fixed: the stack VM is for differential testing.

*Lead's note.* Low's datatype does not change between the targets. Force is one primitive there, which the register target expands, and E2's patch adds to `low.sml` only `Low.hoistEnv`, a function over Low's existing operations that both targets call (`patches/E2-all-forms.patch:1-60`). But B as written is parity by form G, and under form C a thunk is a flat `K_THUNK`, which the stack VM's `CALL` cannot enter (`EXPECT (cv, K_CLOSURE, ...)`, `runtime/stack/interp_cases.h:185`), and a C primitive cannot push a frame. So the stack bytecode needs the instructions too, and the rule gives C. Form C never ran on the stack VM in E2. Lands in M9.

### D15. Eval/apply

`CALL` enters a closure with one argument (`src/isa/regs.sml:122-124`), a partial application is a closure
(`docs/plans/heap-layout.md:4985`), and a function of other than one parameter is only called, never a value
(`core/midlint.sml:175-176`). So an unknown call of n arguments makes n-1 closures and n calls [deduced]. A method of a
dictionary is such a call: E1 wrote State's `>>=` as three nested closures, with curried wrappers for the methods. Is that
price acceptable, and at which tier?

- **A. None.** The curried `CALL` stays. Core's arity work and known dictionaries reduce the unknown calls, and `Workers`,
  `Lift`, `specialise` and `inline` make known what they can; none of them sees through a dictionary [deduced].
- **B. Medium.** A path for a saturated unknown call of two or three arguments: the closure's function has an arity, the
  caller tests it, and no partial-application object is made. SML's curried calls would gain too [inferred]. Not built; E5
  prices a kernel.
- **C. Large.** Eval/apply proper: arity tested by the caller, a partial-application object, over-application by a pushed
  continuation, on every engine, with `Low.Call`, MidLint's rule and `RegVerify`'s. Not built.

**The evidence so far.**
- E3 on GHC 9.4.7, the 152 programs E8 accepts (`results/E3/compare.txt`). Applies of two or more arguments, as a share of
  calls, in total, by median, and programs at or over 5%:

| Level | Total | Median | Programs at or over 5%, of 152 |
|---|---:|---:|---:|
| `-O0` | 63.1% | 56.9% | 148 |
| L1, simplifier and class-op rule | 12.0% | 2.9% | 66 |
| L2, strictness and worker/wrapper too | 11.8% | 3.0% | 65 |
| `-O2` | 3.5% | 0.0% | 26 |

- By argument count, two is the shape that matters: 4.38 billion against 1.03 billion of one and 0.28 billion of three
  (`results/E3/ticky.compat.agg.txt`, 175 programs at `-O0`). 29 million PAPs against 2.14 billion such applies, so nearly
  all saturate [inferred]. Instrumenting the Prelude lowers the `-O0` share by about 12 points on 91 programs, so the
  ladder overstates it by that order.
- At three words a closure, what a one-argument `CALL` adds is 28.0% of bytes at `-O0` and 1.5% at `-O2` [inferred]. GHC's
  counts price nothing on Rune.
- E3's first threshold, 5% of calls, has no source. Marlow, Peyton Jones 2006 argue from complexity at equal speed and
  never measure literal currying. Their own figures give a median of 4.88% and a mean of 11.15% on 58 programs, so the
  verdict would depend on the statistic. Every implementation with a partial-application object took eval/apply;
  push/enter survives only in spine unwinding (*What the implementations do*).
- On Rune today a local function of two parameters lowers at `-O1` and `-O2` through `Lift`, and stops `Lower` at `-O0`,
  though MidLint accepts it (`results/defects/lower-nary-local-fun/`, observed). rhc's `-O0` must not rely on one until
  that is fixed.
- What decides it is E5's price on Rune, not a percentage here.

**E5's price on Rune.** Per iteration at tier 2, Rune `-O0`: a known call 43 instructions, one tuple 82, an argument in a
`ref` 113, curried 116 and 24 bytes (`results/E5/ncall/run.out`). An n-ary path would cost about 55 [N's inference, not
built], so 61 less a chain. Chains of 2 or more arguments, with what that sum saves [inferred] (`results/E5/stats.jsonl`):

| E5's step | `queens` | `primes` | `exp3_8` | `showk` |
|---|---:|---:|---:|---:|
| `D0`, dictionaries at run time | 5.78M, 13.9% | 1.19M, 13.2% | 8.08M, 12.3% | 2.26M, 9.8% |
| `D1`, known dictionaries resolved | 0.38M, 1.2% | 1,200, 0.0% | 15, 0.0% | 1.77M, 8.0% |
| `D3`, with eta and strictness | 0 | 0 | 0 | 0 |

**Recommended: A, not now; M25, on measurement.** Known dictionaries do most of what a path would, at no cost to the VM:
14% of `queens` becomes 1%, as E3's 63% of calls at `-O0` becomes 3.5% at `-O2`. *SML.* A moves nothing.

**Against.** Track P comes after G2, so conformance and `make check` run at `-O0`, where the 14% is real. It is not all
dictionaries: `showk` keeps 8% after step `D1`. Every implementation with a partial-application object took eval/apply,
and SML's curried calls would gain from B too [inferred]. The 55 is an inference; nobody built the path.

**What would reopen it.** Chains on the corpus after M23 well above E5's after step `D1`. K at `-O0` putting D56's budget
out of reach before track P starts. A built path that gains SML enough to pay for itself. Lands in M25, if at all.

**Decided (owner, 2026-11-09).** To be measured: C, eval/apply proper, built and benchmarked on rhc's programs "and rune if that applies", which it does, since SML's curried calls would take the same path [inferred]; then A or C on the numbers. Until then A stands. Built in M25 (*Decisions on the numbers*).

### D16. Pointer code 11

The two bits beside a pointer's immediate bit are reserved for a code meaning "a headered object, known to be evaluated"
(`runtime/value.h:349-357`, `docs/plans/heap-layout.md:5019-5025`). Nothing sets or masks them. Should force use them?

- **A. None.** **Recommended.** Force loads the header.
- **B. Large.** Code 11: a mask at every pointer read in C, in `masm.c` and in runeopt's templates, the copier keeping the
  code and writing it when it shortcuts an indirection. Not built. Heap-layout reserved it
  (`docs/plans/heap-layout.md:4246-4250`) and its layouts have not been built either, which E2 confirmed: heap-layout's
  pointer codes do not exist.

**The evidence.** Evaluated force under G is 24 instructions with the header load (`tables/micro.txt`). On heap-layout's
own kernels the code takes 0.94 billion cycles against 0.99 billion by header on a `case` over values, inside what that
harness calls noise, because the header is read for the constructor's tag either way (`docs/plans/heap-layout.md:636`,
`:647-652`). Marlow et al. 2007 gain -13.7%, but a VM's force is already a kind test, so Rune has the semi-tagging part,
and the rest comes from a constructor tag in the pointer, which one code cannot hold (*What the literature says*, D16).
*SML.* A moves nothing. B moves every pointer read, and heap-layout prices giving up a third headerless shape at 0.093% of
the bootstrap's bytes by census and 0.067% by measure (`docs/plans/heap-layout.md:4246`, `:506-509`).

**Against.** A force of a value on a hot path pays a load the code would spare, and evaluated force is where G is furthest
from C (D13). Nobody has measured code 11 alone on lazy code.

**What would reopen it.** A measured evaluated-force cost on the corpus that fusing G's test and value cannot reach. The
bits stay reserved, so nothing is lost by waiting.

**Decided (owner, 2026-11-09).** To be measured: B, pointer code 11, built and benchmarked on rhc's programs and on Rune's; then A or B on the numbers. Until then A stands. Built in M25 (*Decisions on the numbers*).

**Measured and decided (owner, 2026-11-10): A.** B was built on the register VM (branch `hs-w-d16`, `cf6a69552`): code 11 set by the copier where it shortcuts an indirection to an evaluated object, masked at every pointer read in C and `masm.c`, and `FORCE` skipping the header for it. B against A at tier 2 (`instructions:u`; `--count` is equal by construction): Rune's compiler compiling itself 1.111 (cycles 1.073); 32 SML benchmarks, the masks' cost alone, geomean 1.0445 (cycles 1.029), none faster; 24 lazy ports on form C, through `FORCE`'s code-11 path, geomean 1.1215 (cycles 1.110), all slower. The masks are an upper bound, and cache misses were not taken. Code 11 is not used as an evaluated mark; the branch is kept as the record (`impl/w/d16/figures.md`); `heap-layout.md` records the same.

### D17. Selector thunks

`fst p` unevaluated keeps the whole pair alive after `p` is evaluated. The Report's own Prelude has the shape: `span` is
`where (ys,zs) = span p xs'`, `lines` binds `(l, s') = break ...`, `unzip` uses `~(as,bs)`. Under a literal Prelude a line
of length n holds n pairs until the consumer reaches `s'` [inference].

- **A. None for now.** **Recommended.** Measure leaks on the corpus first. Half the systems ship this leak.
- **B. Small, in Core's desugaring.** Sparud's method: a pattern binding desugared to the tuple form with selectors, plus an
  impure compiler-internal `updatePat`, which "overwrites every vi with an indirection to the corresponding vi'" (Sparud
  1993, §3.3, p 119). It is not a construct of Core: that is Gustavsson and Sands' reformulation, and for a typed IR Sparud
  keeps the tuple form, his equation (8) (p 120). It needs a primitive to update another thunk. hbc has it behind
  `-fpat-bin-update`, off by default. Not built.
- **C. Medium: Wadler's rule in the collector.** A thunk marked as a selector, reduced by the collector once its argument
  is evaluated. Good for lazy ML too [inferred]. Not built, no lines. GHC caps nesting at 16; Yhc does one step. Under
  form G the mark would be a `contag` state with the field number in it [deduced from
  `docs/plans/heap-layout.md:5075-5077`].

**The evidence.** E2 did not test this. One figure exists: clausify under an LML G-machine, 47,548 to 34,083 byte-seconds,
-28% (Runciman, Wakeling 1993). Sparud gives no numbers, only heap profiles, and says a program that does not leak runs
"somewhat slower" under his method (§4, p 120); `partition` written with two `filter`s still leaks under it (§5, p 121).
Röjemo 1995 measures nothing on selector thunks. No paper says how often it bites across real programs. The Report's
kernel is the form Sparud cannot fix: 3.12 gives `let p = e1 in e0 = case e1 of ~p -> e0`, and 3.17.3's rule (d) makes
that one projection per variable, so B means a different desugaring of pattern bindings and `~p`, which touches D34
(*What the literature says*, D17). The cost is bounded by the longest
line, or the distance between two consumers [inference], which is why it can wait. *SML.* A moves nothing. C adds a test
to the collector's path for closures, on top of D11's; not measured.

**Against.** The shape is in the Prelude, so every program that uses `lines` meets it, and the corpus may lose at G2 to a
leak that was known in 1987.

**What would reopen it.** A corpus program whose residency is explained by selector chains. Lands in M25, if measurement
justifies it.

**Decided (owner, 2026-11-09).** To be measured: B, Sparud's method, built and benchmarked on rhc's programs, and on Rune's where it applies; then A or B on the numbers. Until then A stands. Built in M25 (*Decisions on the numbers*).

*From the papers (E15b).* B is a desugaring of pattern bindings plus an impure `updatePat`, not a Core construct (Sparud 1993, §3.3). Under form C a sibling's component may be unevaluated, and `FORCE` takes what a `K_IND` holds as the value (`patches/E2-all-forms.patch:1566`), so the write may not be a `K_IND` to a thunk: it retargets the sibling's code and capture, or is made only when the component is evaluated. And the sibling whose force ran the match is under evaluation when `updatePat` runs, so overwriting it is E14's case of a body outliving its own update, which would make D11's pin Haskell's and move it from M26 to M25. The write skips any sibling that is not unevaluated, which avoids both [P1's inference; nothing built]. B changes how pattern bindings and `~p` are desugared, so it touches D34.

### D18. Depth

Forcing a chain nests a frame per thunk, and until track P the Report's `sum` builds a chain of n thunks (`foldl` over an
unknown `(+)`). The Report says nothing of stack depth. Is the default stack of 1 GiB (`runtime/runtime.c:67`) enough?

- **A. None.** **Recommended.** The limit stays, and `--stack-size` raises it, as the message says.
- **B. None to Rune.** rhc's driver or runtime start-up sets a larger limit for its programs.
- **C. Medium: a stack of linked chunks,** as GHC's. Not considered further.

**The evidence.** Stack per level on the `chain` kernel, one thunk body a level (`tables/depth2.txt`): SML's plain
recursion 64 bytes, G and C and lazy ML's form A 80, form A under Haskell's reading 144. On `tailchain` G and C take 56. A
10^7 chain fits 1 GiB under G, in 7.1 billion instructions against 25.5 billion for form A under lazy ML's reading, and
form A under Haskell's reading overflows (`tables/depth-1e7.txt`). So G's limit is about 13 million such levels [deduced].
The non-tail body costs little. Only a growable stack passed E15's probes: `foldr` at 10^5 fails under Hugs and MicroHs,
and GHC passes at 10^7 (*What was run*). *SML.* None.

**Against.** `chain` is one frame a level. A `foldr (+)` through a dictionary method is a thunk, a function and a method a
level, about three frames [inference], so the limit on real output may be nearer 5 million, and programs GHC runs at 10^7
may overflow until strictness (D50) arrives. The memory is real as well: a doubled stack at 1 GiB.

**What would reopen it.** Any corpus program that overflows at the default. Option B is then the first answer. Lands in
M9.

**Decided (owner, 2026-11-09).** A, as recommended: the stack limit stays, and `--stack-size` raises it. Form C takes the same 80 bytes a level as G on `chain` (`tables/depth2.txt`).

### D19. CAF roots and the barrier

Two questions on what a thunk asks of the collector. Globals are roots (`README.md:44-45`), so a CAF is kept for ever. And
an update is a pointer store into an object that may be old.

**CAFs.**
- **A. None.** **Recommended, at first.** CAFs stay roots. It is the literature's "slightly pessimistic" and the practice
  of Yhc, Hugs, UHC and jhc.
- **B. Medium.** A table per function of the CAFs its code reaches, emitted at or below Core to Mid, and a collector that
  traces from live code, as GHC's static reference tables. Not built, no lines.

For a CAF that is a growing lazy list this is a linear leak [inference]; for conformance it is nothing. No paper gives a
number for what collecting CAFs saves, and E2 did not measure it. If CAFs stay roots, floating constants needs Santos's
"safe" rule (D47).

**The barrier.**
- **None.** **Recommended.** `gc_barrier` in C (`runtime/vm.h:583-592`) and `ms_set_field` in compiled code
  (`runtime/register/jit/masm.c:1761`) are what an update needs. There is no `vm_write_barrier`.

An old thunk with a young value passes E2's `barrier` kernel, in 84 stress runs over B, C and G (`tables/stress.jsonl`),
and on the stack VM and native code (`tables/F-stack-native.txt`). `obj_become_ind` already takes the barrier for each
field (`runtime/value.h:325-332`). Lazy ports store 71 thousand to 16 million times where strict twins store 5, and with a
1 MB nursery 93.3% to 99.9% of those need no remembered entry (`docs/plans/heap-layout.md:609-616`, six programs over the
shipped module).

*SML.* Neither moves anything.

**Against.** CAFs held for ever are X5's named risk, and a program over a long lazy CAF list loses the corpus with no
warning. Promotion is the other: a promoted thunk roots its later value in the old generation, unseen by minor collections
(Sansom, Peyton Jones 1993, §5.4), and nothing here measures that on Rune. Add-on-entry, one of the literature's answers,
adds an old thunk to the remembered set when it is entered (Röjemo 1995b, §3, p 150); it needs eager blackholing, and so
went against L (D12). Under form C, whose `BLACKHOLE` writes at entry, that conflict is gone; it is still no reason for a
barrier of its own. Röjemo measured what promoting every survivor of a minor collection costs, which Rune's nursery does
(`runtime/gc/minor.c:1-7`): on sieve the simple collector "takes nearly ten times more time than the two-space
collector" (§5.1, p 155).

**What would reopen it.** A corpus program whose residency is a CAF, or whose old generation is thunks promoted dead.
Lands in M9.

**Decided (owner, 2026-11-09).** To be measured: B, a table of the CAFs a function's code reaches and a collector that uses it, built and benchmarked on rhc's programs; then A or B on the numbers. Until then A stands, and CAFs are roots. The barrier stays as recommended: nothing new. Built in M25 (*Decisions on the numbers*), whose figures include the promoted bytes that die in the old generation (Röjemo 1995b, §5.1).

### D20. `Integer`

**Question.** What is an `Integer` at run time, and who owns its arithmetic? It is hot by the Report's own rules: 4.3.4's `default (Integer, Double)` sends unannotated numeric code to it, and each integer literal is `fromInteger` of one (3.2).

- **A. None: `IntInf` as it stands,** reached through the support unit (D26). `datatype int = S of limb | B of bool * string` (`lib/basis/intinf.sml:13`). By `Rep`'s rule `S n` boxes its argument in a one-field constructor object (`lib/compiler/backend/rep.sml:1-7`), so a small `Integer` is a 16-byte heap object [deduced]. `docs/plans/heap-layout.md:4998-4999` calls it immediate. 0 lines in Rune.
- **B. Small: an immediate small `Integer`, tested in Mid.** `Integer` is an abstract tycon, so it is `RAny` and keeps its tests (`lib/compiler/backend/lower.sml:412-417`). A small value is an `int`, a big one a heap object. Addition is `int_add` under a `Handle`, with overflow taking the big path. One new primitive, to test the immediate bit. This is E5's I2 (`results/E5/mrhc.py:16-17`).
- **C. Medium: the same representation, with primitives in line.** `integer_add` and the others compile as `int_add` does (`runtime/register/fastprim.h:136`), with a slow path of their own and no `Handle`. New primitives move the instruction set's fingerprint (`docs/bytecode.md:77-84`). This is E5's I1 (`results/E5/core/rts-i1.mid:1-3`).
- **D. Medium: `IntInf` takes that representation too,** so that SML gains and `docs/plans/heap-layout.md` becomes true. `lib/basis/intinf.sml` is 651 lines. Not prototyped.

Under B, C and D big values keep `IntInf`'s signed magnitudes and its arithmetic, in the support unit. E5's prototype does not build that path: a big operand stops (`results/E5/core/rts-i1.mid:1-3`).

**What does not depend on E5.**
- *What the Report asks.* Table 6.1 says "Arbitrary-precision integers". `IntInf` has a budget, `INTINF_DEFAULT_BITS`, 134,217,728 bits (`runtime/intinf.h:6`), past which it fails with a runtime limit. Every option inherits it. It is a choice to record (D53), not a deviation.
- *Division by zero.* 6.4's sentence covers only fixed precision, so `Integer` has no rule at all (R45). All three oracles give an error [read]; rhc does too.
- *Literals.* R14: `Integer` is a kernel constant, which no syntax denotes in the translation.
- *Precedent.* No system has an immediate small `Integer`, beyond Hugs's zero (*What the implementations do*). GHC's `IS Int#` is boxed. B, C and D would be new.
- *The literature.* Nothing measures defaulting. One indirect sign: `Integer` is 96.9% of strict arguments in rsa and 38.4% in gg (Peyton Jones, Partain 1993, Table 6, *What the literature says*).
- *Overlap with D49.* A defaulted site knows `Num Integer` at compile time, so known-instance resolution applies directly. The two savings must not be counted twice.
- *Overlap with D51.* Under A an `Integer` operation is unbounded, so none is cheap-eager. Under B, C and D an add of two immediates cannot raise and does bounded work, while the big path is unbounded and fails at `INTINF_DEFAULT_BITS`; so only speculation guarded by a test of the immediate bit qualifies, the form Faxén 2001 measured and found to hardly improve (*What the literature says*, D51) [inferred].
- *E3 cannot answer it.* `Integer` stays uninstrumented in both of its variants.

**E5's result.** E5 measured two forms and no bignum path: I0, `IntInf`'s fast paths ported to Mid, and I1, which is option C, with a slow path that stops. **Option B was not measured:** `mrhc.py` names an I2 and there is no runtime for it. D is unprototyped. Per add, in a loop of 10^7 (`results/E5/intinf/run.out`):

| Form | Instructions | Bytecodes | Bytes |
|---|---:|---:|---:|
| SML `int`, for scale | 19 | 9 | 0 |
| Real `IntInf` (A) | 74 | 17 | 16 |
| I0, its Mid port | 79 to 85 | 17 | 16 |
| **I1, immediate (C)** | 24 | 8 | 0 |

- *`IntInf` is boxed,* as option A deduces. A small one read as an int is a fatal (`results/E5/intinf/run.out`), so `docs/plans/heap-layout.md:4999` is a plan and not a fact.
- *On programs.* At E5's step `D0`: `sum` -36.0%, `list` -23.6%, `showk` -17.2%. After the first optimiser `sum` goes from 809M to 472M, `list` from 4,342M to 3,189M, `showk` from 562M to 352M (`results/E5/results.jsonl`, `k.txt`). Both are in E5's ladder with D49's steps, so the two savings are not counted twice.
- *On Int programs it does nothing:* `sumint`, `queens` and `exp3_8` under 0.1%, `primes` 0.4%.
- *Built:* `patches/E5-integer-prims.patch`, ten primitives on `int_add`'s inline code (`runtime/register/fastprim.h:136`), +70 -2 with `any_check`, whose slow paths are a fatal.

**Recommendation.** C, an immediate small `Integer` with primitives in line, and **the bignum path is the first thing to build,** since nothing yet shows the small path keeps its 24 with one behind it. D is for Rune to take separately. **The strongest argument against:** only this form was built, and what makes it an `Integer` was not. The 24 is the cost of an add that never overflows. C moves the fingerprint and takes a slow path in every engine, for a gain Int programs never see, and B, one primitive and a `Handle`, might come near it with less: nobody knows, because B was not measured. No system but Hugs's zero has tried an immediate small `Integer`, so nothing here has a precedent.

**What would reopen it.** B measured close to C. The bignum path costing the fast path, or a program crossing the small range often. Specialisation leaving `Integer` rare on the corpus. The owner taking D for Rune, which gives rhc the representation with no primitive of its own. Lands in M17.

**Decided (owner, 2026-11-09).** D: `IntInf` takes the immediate representation too, with C's primitives in line. The owner's reason: "rune should benefit from this". The recommendation was C, with D left for Rune to take separately; the section above stays as the evidence.

*Lead's note.* The bignum path is the first thing to build, as for C. Hosts compile Rune's `lib/basis` in the `xc1` configurations, with the VM's primitives written on the host's library (`tests/basis/host/rune-prim.sml`, `docs/basis-compat.md`), so each new primitive has a host version there and `make matrix-quick` runs. rhc's `Integer` shares the representation and the small path (D26). Under D an add of two immediates cannot raise, which changes D51's sentence on `Integer` (above, *Overlap with D51*). Lands in M31; rhc's `Integer` on it in M17.

### D21. `Char`

**Question.** What is a `Char` in Mid, whose tables classify it, and at which Unicode version? Rune's `char` stops at 255: `int_to_char` raises `Chr` (`runtime/prims.c:205`) and the lint holds a constant to it (`lib/compiler/core/irrules.sml:55`). The Report's `Char` is Unicode, its `isUpper` and `toUpper` are primitives (`results/E9/report-libs/Char.hs:34`, `:67`), and `primUnicodeMaxChar` has no value. `lib/unicode` exports no general category or case mapping (`lib/unicode/*_sig.sml`), and `WideChar`'s classes are ASCII's (`docs/language.md:307`).

*Representation:*
- **A. None: Mid `int`.** **Recommended.** A code point, 0 to 0x10FFFF, as `WideChar` is (`lib/basis/widechar.sml:24-27`). Immediate, no allocation, comparisons by the `int` primitives. 0 lines in Rune.
- **B. Large: widen Rune's `char`.** It reaches `int_to_char`, the lint, `CChar` (`lib/compiler/core/lambda.sml:17`) and SML's own 0 to 255. Rejected: Haskell gains nothing over A.

*Tables:*
- **C. None: rhc's own tables in `lib/language/haskell`.** E10's spike has 348 generated lines for five lexical classes, at Unicode 15.0.0 (`results/E10/spike/hs_unicode_data.sml:1`), from a Python script that could not land. A second copy of the Unicode data, at a second version, against the owner's rule that generic functionality becomes a library (*Constraints*).
- **D. Small: general category and simple case mapping in `lib/unicode`.** **Recommended.** Generated from the same data by `bin/rune-generate unicode` (`lib/unicode/README.md:11-12`, `tools/generate/unicode-render.sml`), at 18.0.0 (`lib/unicode/grapheme_data.sml:18`). Not built. [inferred, from the spike's 348 lines and `lib/unicode/identifier_data.sml`'s 365:] some hundreds of generated lines, one signature, one renderer. `rune.build` lists `lib/unicode`'s files by name (`rune.build:4-12`), so a new file leaves bootstrap bytes alone [deduced]. rhc's lexer and `share/rhc/haskell98`'s `primUnicode*`, through the support unit (D26), then read one table. The lexer needs the general category first, so that half lands with M11 and the case mappings with M17.
- **E. Medium: `WideChar`'s classes become Unicode's as well.** Good for SML, and rhc does not need it. Left to Rune.

**What the tables must answer** (readings; behaviour is [probe], `results/E7/hard/06-probes/out.txt`):
- **R38, `isUpper` of a letter with no case.** Chapter 19 treats "any alphabetic character which is not lower case" as upper, and `isAlpha c = isUpper c || isLower c` is the Report's code. So `isUpper` of U+4E2D is `True`. GHC and Hugs answer `False`, `False`, `True`, breaking that law; nhc98 is 8-bit. **Recommended:** the Report's law, pinned, on the frozen version. It is a place where the Report and the oracles part, and D38 sorts it.
- **R5, the holes in `graphic`.** A letter with no case is in no lexical class, so by the letter it is a lexing error even in a comment. All three accept one. **Recommended:** any character in comments and literals, a stated deviation on D38's ground that the text is wrong here; identifiers by the Report's classes.
- **R6:** ASCII digits only in numeric literals, as GHC.
- **Which version:** 2.1 opens the citation of 3.0 to later ones, so 18.0.0, named in the documents.
- **Surrogates: marked for the owner.** Does `Char` hold them (`toEnum 55296`)? `WideChar.chr` does (`lib/basis/widechar.sml:27`). **Recommended:** yes: one range, 0 to `maxBound`, as `WideChar` has. `lib/unicode` writes UTF-8 strictly, so what `putChar` does with one needs its own rule.
- **Bytes in files.** The Report is silent. UTF-8, by `utf8_decode` (`src/isa/prims.sml:856`). Source bytes that are not UTF-8 occur in 5 files of the nofib trees, and E10's spike reads them as Latin-1 (`results/E10/summary.txt`).

**Recommendation.** A and D, with the readings as above. **The strongest argument against:** the table's cost is not all Haskell's to pay, and a private table is simpler. `lib/unicode` is shared with the compiler, so a Unicode bump would move `isUpper` under rhc's programs, and D would make a Rune library carry data only rhc reads today. On R38, a program calling `isUpper` on a CJK letter would print what neither judge prints, and the Report's own `uniLarge` calls that letter not upper, so the text is at odds with itself. If the owner reads that as contradiction, GHC's table is the deviation to take.

**What would reopen it.** The generated tables moving an SML budget or bootstrap bytes; the owner calling R38 contradictory; a corpus program printing a class of a letter with no case.

**Decided (owner, 2026-11-09).** Representation A, a code point in a Mid `int`; tables D, general category and simple case mapping in `lib/unicode`; both as recommended, with the readings as above.

### D22. `Int` width and overflow

**Decided with D51.** Read this with D51: the choice here sets what cheap eagerness may do.

**Question.** What does `Int` do past its range? 6.4: "The results of exceptional conditions (such as overflow or underflow) on the fixed-precision numeric types are undefined; an implementation may choose error (_|_, semantically), a truncated value, or a special value such as infinity, indefinite, etc." Rune's `int` is the immediate's 63 bits (`lib/compiler/core/target.sml:18-22`), above 6.4's lower bound (R54). No `int` primitive wraps.

- **A. None: the checked prims.** **Recommended.** `int_add`, `int_sub`, `int_mul`, `int_neg` raise `Overflow` (`src/isa/prims.sml:26-41`). Overflow is an error, which 6.4 expressly allows. 0 lines in Rune.
- **B. None: wrapping through the word prims.** `word_from_int`, `word_add`, `word_to_int_x`, none of which has `Raises` (`src/isa/prims.sml:62`, `:94`, `:96`). 6.4 allows "a truncated value" too. 0 lines in Rune, three primitives for one operation in rhc's output. At tier 2 that is +7 machine instructions on an add (19.07 to 26.07, +37% of that loop) and +3 on a mul-mod loop (47.07 to 50.07), and 3 and 1 more bytecodes (`results/V2/word/word.out`).
- **C. Small: wrapping `int` primitives.** A line each in `src/isa/prims.sml`, C bodies, cases in `runtime/register/fastprim.h` and the JIT, and a new fingerprint (`docs/bytecode.md:77-84`). Unbuilt [inferred]. SML has no use for them.
- **D. Large: a 64-bit `Int`.** `RUNE_INT64` and `--int-bits=64` keep 64 bits by boxing (`runtime/value.h:45-47`), behind a switch. It would meet GHC's width only with wrapping as well, and every value past 63 bits allocates. Rejected.

**The evidence.**
- *No oracle shares Rune's width.* GHC wraps at 64 bits; Hugs and nhc98 are 32-bit (*What the implementations do*), and nhc98's wrap is visible in E15's `foldr` probes. Where a program wraps, B gives a third answer, silently. A gives a visible stop. So a test that overflows `Int` has no shared answer under any option.
- *Precedent.* MicroHs alone traps (`MicroHs/src/runtime/unix/config.h:85`).
- *R40.* `succ maxBound` "should result in a runtime error" under every option; the bounded rule decides that, not this.
- *What a raise does.* `Overflow` is no `IOError`, so `catch` does not see it (R36) and D12 applies: no thunk outlives it. An uncaught exception prints and exits 1 (`runtime/runtime.c:271-287`), and rhc's top level wraps `main` so that chapter 23's close and flush still run (R37).
- *The corpus, established* (`results/V2/hash/`). nofib's `common/NofibUtils.hs` has `hash = foldl' (\acc c -> ord c + acc*31) 0`, and E8's compat copy keeps it. 19 of the 223 run programs print such a hash: 19 of the 82 2019 programs, and 13 of D56's 188.
  - Rebuilt with `hash` checked against [-2^62, 2^62-1], 17 overflow on every hash call (`hash63.tsv`), and `symalg` does too by its own output lines, `-> 1`, which that tally misses [V2's reading; the run's output was not kept]. The 19th, `spectral/sphere`, has its own `acc*61` hash (`Main.lhs:451`), read and not run.
  - Rune stops on it: a 12-character string fits, and an 18-character string raises `Overflow` (`results/V2/word/hash.out`).
  - 13 of the 19 have nhc98 and Hugs both differing and the other 6 have an oracle absent, which fits E8's suspicion of 32-bit `Int` [inferred].
- *Neither `Int` option matches them.* A stops. B prints another number wherever the expected value is outside 63 bits, as `4837159772545863515` and `-8791092626015977392` are: 13 of the 19 print at least one such value (recounted from the expected files). The other 6, `bspt`, `fulsom`, `gamteb`, `gg`, `parser` and `sphere`, print only values that fit, and B would reproduce those by congruence [deduced, not run]. So this does not decide A against B. It removes their stated difference on the corpus, and G2 needs more than either: **the corpus's `hash` becomes a compat function over `Integer` printing the 64-bit result,** with `sphere`'s own among them. That is a change to the test harness, like the rest of the compat layer, not to the language.

**With D51.** A checked `+` can raise, so it may not run before its demand. That closes the local form of cheap eagerness for `Int` arithmetic, as Faxén says himself: "If such overflow is trapped, integer addition is an unsafe operation" (Faxén 2000, §3, p 152). GHC's `exprOkForSpeculation` requires that the expression cannot throw (`ghc/compiler/GHC/Core/Utils.hs:1791-1792`). B keeps it open for `+`, `-`, `*`, not for `div`. Strictness is unaffected. What A gives up has one bound. Faxén's "All evals expensive" column, which he says "corresponds roughly to what one can accomplish without a special cheap eagerness analysis", saves up to 16%, 1% and 8% of instructions on event, sched and tc, his three programs larger than toys (Table 1, p 157). Every figure in his paper assumes a wrapping `Int`, against a very simple strictness analyser, so for rhc it is an upper bound, not a measure [inference] (*What the literature says*, D51). A third road keeps both: the word prims with a range test, and on overflow a thunk that raises. It is untested and costs more instructions than either [inferred].

**Recommendation.** A, the checked prims, now with B's cost measured against it. **The strongest argument against:** hash functions and generators in real programs wrap on purpose: 19 of 223 do. Under A a program that runs on every oracle stops with an error. Conformance is untouched, but the corpus is what proves rhc, and A closes D51's local form as well, for a stop that only a buggy program benefits from. The answer is that B does not rescue those programs and costs every `Int` add 7 instructions.

**What would reopen it.** A program outside `hash` that overflows; M25 showing cheap eagerness on `Int` is worth having.

**Decided (owner, 2026-11-09).** A, as recommended: the checked prims, overflow an error; the corpus's `hash` a compat function over `Integer`. What it costs cheap eagerness is bounded by Faxén's figures above.

### D23. `Float`

**Question.** What is a `Float`? 6.4: "Float is implementation-defined; it is desirable that this type be at least equal in range and precision to the IEEE single-precision type." Rune's `Real32` is a binary64 holding a binary32 value, rounded after each operation by `real_to_single` (`lib/basis/real32.sml:1-8`, `src/isa/prims.sml:553-554`), correctly for `+ - * /` and `sqrt` (`lib/basis/real32.sml:3-5`). Mid sees `real`.

- **A. None: plain `real`.** Legal by the Report's lower bound. `floatDigits` says 53, and `Float` and `Double` are one type at run time. Output differs from every oracle wherever `show` meets a value binary32 would have rounded [deduced].
- **B. None: the re-rounding.** **Recommended.** `Float` is Mid `real`; each operation is followed by `real_to_single`, and numerals go through `real_single_from_string` (`src/isa/prims.sml:555-556`). `floatDigits` says 24. 0 lines in Rune. rhc calls the primitives; `Real32` itself is sealed (`lib/basis/real32.sml:247`) and is not used.
- **C. Small: a fast path for `real_to_single`.** It has none today: it is a C primitive, absent from `runtime/register/fastprim.h` and the JIT (grep). Additive, only if measured.
- **D. Large: a binary32 representation in the VM.** Rejected: nothing observable gains over B.

**The evidence.** R54 says `Float` conforms either way. E7's six `show` disagreements (`Enum/succ` twice, `numbers/floatdouble`, `integerdouble`, `subtract`, `parsing/rational_lits`) are about Hugs's digits, and GHC and nhc98 agree on the Report's `showFloat` form, so `Numeric`'s literal code is the reference. That code works from `floatDigits` and `decodeFloat`, so the type must behave as 24 bits for output to match [deduced]. The cost of B is one C primitive per `Float` operation at tier 2 [deduced]; it has not been measured. Functions other than those five are binary64 results rounded once, so not correctly rounded, which the Report does not ask.

**Recommendation.** B, as output must compare with oracles. **The strongest argument against:** the Report's bar is only "desirable", and A is simpler and faster. D52 already excludes `Float` output from differencing as implementation-defined (*Testing and conformance*), and the corpus's float digits are compared with a tolerance, so B pays a C call per operation for a match the test plan half gives up. What remains for B is `conformance98`'s `show` tests and every expected output that was made on a binary32 `Float`; how much of that the tolerance already hides is not established.

**What would reopen it.** The corpus's `Float`-heavy programs showing the cost, which brings in C; or the corpus proving not to depend on binary32.

**Decided (owner, 2026-11-09).** B, as recommended: `Float` re-rounded to binary32 by `real_to_single` after each operation.

### D24. String literals

**Question.** What is `"hello"` at run time? 2.6 calls string literals "abbreviations for lists of characters", and `[Char]` is a lazy list. R14 makes a string a kernel constant. Mid's constant is `Lambda.CString`, bytes (`lib/compiler/core/lambda.sml:16`). Rune's `list` cannot be the Haskell list: its tail would be a `susp`.

- **A. None: a constant, lazily unpacked.** **Recommended.** UTF-8 in a constant, and one function in rhc's runtime that gives a cell per demand, reading by `string_sub` (`src/isa/prims.sml:169`). GHC, nhc98, Yhc, Hugs, hbc, UHC (*What the implementations do*). 0 lines in Rune.
- **B. None: a constant, the whole list on first force.** MicroHs. The same constant and a loop.
- **C. None: cells built in code.** jhc's static cells have no form here: Mid has no static data, so a literal of n characters is n constructor steps in the code.
- **D. Small: a primitive that unpacks.** nhc98's and Yhc's `STRING` opcode. `string_explode` exists, but gives an SML `char list` of bytes (`src/isa/prims.sml:189`), the wrong list and the wrong `Char`. New primitives move the fingerprint.

**The evidence.** No paper bears on it, and no experiment ran one: E1's Mid used strings only as SML strings. By reading, a literal has no bottom in it, so A and B differ only in time and space [inferred]. By D11's figure a delay is 32 bytes, so A's cell costs a thunk and a cons where B's costs the cons. Rule (h) against rule (g) on string patterns is translation defect 7, and rests on `==` on lists running left to right (*What the Report says*). Sharing is the Report's silence again (translation defect 19): a literal inside a function is unpacked at each evaluation at `-O0`, and D47's Core may float it to a CAF.

**Recommendation.** A. **The strongest argument against:** for the common case it is the worst of the three. Most literals are short and read to the end, so `putStrLn "hello"` pays a thunk per character for laziness nothing can observe. B, or chunks of cells per thunk, is cheaper and just as conforming. A is recommended as the plain baseline with the same shape as every other lazy list, and neither alternative needs a change to Rune, so the choice can be remade by one function.

**What would reopen it.** `--count` on string-heavy corpus programs showing the unpacking dominate: then chunks.

**Decided (owner, 2026-11-09).** A, as recommended: a constant, lazily unpacked. To be measured for the record: B and D, built and benchmarked; the owner: "we are unlikely to take D even if it wins as there is no use in rune. just for the record." Built in M17, measured as *Decisions on the numbers* says.

### D25. `IO` and lazy I/O

**Question.** What is an `IO a` in Core and in Mid, and how does lazy input work? The Report leaves `IO` abstract. Every option here is none: Mid's `Let` is sequenced, `Handle` and effects exist, and no Rune change is needed.

- **A. A function of unit, no state token.** **Recommended.** `IO a` lowers to a function of `unit`. Under the rule that functions return evaluated values (*The architecture*), `return undefined >>= k` needs `unit -> susp a` or a box [inference]; Helium's form is a box, `() -> IORes a` (`helium/lib/LvmLang.core:104-105`, `:315`), and M17 settles which. E5 erases `IO`, and E1's `exceptions` does not test this. The order is the code's, and a result needs no pair. In Core `IO` stays opaque: bind, return and primitives are constants, lowered at the Core-to-Mid boundary, so that no Core pass can reorder an effect.
- **B. A state token.** GHC, jhc, UHC, MicroHs. One more parameter and a returned pair per action unless erased, and Mid has no multi-value return (D9). Core then takes on GHC's rules: never duplicate a redex, never lose the chain, no CSE across dummies. GHC needs its state hack on top: "we don't really know, and sometimes it's false" (`ghc/compiler/GHC/Core/Opt/Arity.hs:544`).
- **C. A dummy world with `Either IOError a`.** nhc98. Bind tests each step, which an exception avoids.
- **D. Continuations or dialogues.** Hugs, hbc. A closure per step, and no reason here.

**`getContents`.** One interleaving primitive, rhc's own: a Core constant that suspends an `IO a`, lowered to an ordinary thunk whose body runs the action, so it needs nothing of Mid [deduced]. Its body catches its own read errors and ends the list, for 21.2.2 says "Any I/O errors encountered while a handle is semi-closed are simply discarded." GHC raises them (`ghc/docs/users_guide/bugs.rst:476`); rhc should not. This is why D12's raise repair is not needed for Haskell 98. Such a force does I/O, so it must not move across an effect. E2's `thunk_fforce` has `effects = anything` (`patches/E2-all-forms.patch:1875`), so passes treat it so [deduced], and `interact` depends on that.

**`catch` and the end.** `catch` is a Mid `Handle` for rhc's `IOError` alone, so `error` passes through it (R36). The program ends by chapter 23: close and flush, status 1, message to standard error (R37). A call inside a `Handle`'s body is no tail call (`lib/compiler/core/mid.sml:15-17`), which only a `catch` in a loop can notice.

**The evidence.** E1's `exceptions` program has this shape: actions of `unit -> 'a`, `catch` over an `IOError`, a top-level handler giving the message and exit 1 (`results/E1/prog/exceptions.mid:49`). It passed all 45 ways (`results/E1/matrix-base.txt`). It is hand-written, and no lazy input ran. The literature's reasons for the token do not transfer: they are reordering by a lazy optimiser and strictness expression, and Mid's `Let` is already sequenced (*What the literature says*).

**Recommendation.** A. **The strongest argument against:** opacity is a cost that recurs. With a token, `IO` is ordinary Core, so a simplifier inlines bind for nothing. With A, every Core pass must keep the monad, a closure per action survives until the simplifier is taught `bindIO`, and a later `ST`, FFI or Haskell 2010 will want the token's reasoning anyway. The cost per pass is small for a small optimiser [inferred], and it has not been measured.

**What would reopen it.** Closures per `IO` action dominating I/O-heavy corpus programs after M23; a roadmap adding `ST`.

**Decided (owner, 2026-11-09).** B, against the recommendation: a state token. The owner's reason: "we will do Haskell2010 in the next roadmap". The section above stays as the evidence.

*Lead's note.* The token does not wait on D9, which the owner put behind a measurement on 2026-11-10: until multi-value return is adopted, the token's returned pair is a tuple, or erased, as B above allows; if it is adopted, the pair goes through M30's multi-value return. Every action returns that pair, so D9's measurement includes rhc's `IO`-heavy programs. GHC's "state hack" is an eta-expansion through `IO` that D48's pedantic rule does not allow, so D48's measurement of D includes `IO`-heavy programs. With a token `IO` is ordinary Core, and Core takes on the rules B names above. Lands in M17.

### D26. The library boundary

**Question.** What may Haskell library code call? `share/rhc/haskell98` has `prim*` names and names `PreludeBuiltin` and `UnicodePrims`, defined nowhere (R47), and needs big-number arithmetic, number text and buffered handles from somewhere.

- **A. None: primitives only.** No SML below Haskell. `Integer`'s arithmetic, which `lib/basis/intinf.sml` holds in 651 lines of SML, is ported. All of `prim*` then run in the Core interpreter too. 0 lines in Rune.
- **B. Small: primitives, plus one frozen SML support unit.** **Recommended.** Haskell calls Mid's primitives directly. SML names are confined to one unit, frozen with the compiler, under `lib/language/haskell/support/` (M17). A Mid unit naming SML globals needs +43 -4 in `lib/compiler/core/midtext.sml`, `lib/compiler/driver/pipeline.sml:245` and `src/driver/main.sml` (E1's `patches/E1-all-prototypes.patch`). It ran on both targets at all levels (`results/E1/link/runU.out`).
- **C. Small: any Mid unit may name any compiled SML unit.** The same +43 -4, unrestricted. It is unsound in the cache as it stands: a unit's usages of SML names are not recorded, because `Parse` runs after `Usage.record` ends [read]. Observed: a new unit shadowing a name gives warm `hello !`, cold `from lib2 hello` (`results/E13/midunit/run.out`).
- **D. Medium: record a Mid unit's usages, so that C is sound.** It needs a `UnitBasis` session in rhc's unit [inferred]. Unbuilt.

**The evidence.**
- *E1.* A hand-written Mid module called `TextIO.print` and `IntInf`, and 2^100+1 came out right. In units it also passed a Mid closure to `List.map` and caught `IO.Io`, on registers at `-O0` and `-O2` (`results/E1/link/runU2.out`).
- *What E1 leaves open.* Exception constructors are not resolved, so SML bridges them. It ran with SML elaborating the Basis in the session, not from `.rbi` alone, and without the cache. Output is unshaken: 574,784 bytes at `-O1` (`results/E1/link/runU.out:7`), against 50,422 for the whole-program text (`results/E1/link/runC.out:14`).
- *E13.* Whatever the unit is, it must not change under a warm build. Frozen, it holds no usage that can go stale [inferred].
- *`AGENTS.md:396`* forbids `_prim` in a library beside the Basis. That rule is about SML source: rhc's `prim*` are Core constants lowered to Mid primitives, and the support unit uses the public Basis [deduced].

**Recommendation.** B. **The strongest argument against:** E1's route resolves names through `Env` and `UnitBasis`, so rhc links SML's elaborator, which goes against D41's layer with no front end, and every Haskell program carries the Basis in its link. A has none of this, and its libraries run whole in the Core interpreter. B stands on `IntInf`: porting 651 lines of tested arithmetic into a new language is the larger risk. A generated table of the unit's exports could replace the lookup through `Env`; that is unbuilt [inferred].

**What would reopen it.** D20 choosing arithmetic that needs no SML, which leaves the unit nearly empty and favours A; M21 finding the unit will not freeze; a need for SML names from user code, which is an extension and out of scope.

**Decided (owner, 2026-11-09).** A, against the recommendation: primitives only, no SML below Haskell. The owner: "please port IntInf if we need it; Haskell/SML interop is a future roadmap". The section above stays as the evidence.

*Lead's note.* The bignum core is primitives already: `intinf_binary`, `intinf_divmod`, `intinf_shift`, `intinf_power`, `intinf_decimal` (`src/isa/prims.sml:828-847`, the same lines at origin/master `697724da5`). So the port is the representation and the small path over them, which D20's D shares, not 651 lines of arithmetic. The support unit of B does not land, nor the lookup through `Env` and `UnitBasis` that went against D41's layer; M5's Mid unit that names SML globals is not needed by rhc. Lands in M17 and M18.

### D27. Parser and layout

**Question.** How is a parser made to do `parse-error(t)`, which makes layout depend on the whole grammar and, through non-associative operators, on fixities (R1)? Rune: none; B adds bison to rhc's build.

- **A. Hand-written recursive descent, pulling layout a token at a time.** **Recommended.** A block that sees neither `;` nor its close takes the implicit close: `closeImplicit`, 22 lines (`results/E10/spike/hs_layout.sml:169`), plus one call in `block` (`results/E10/spike/hs_parser.sml:499`). Operators stay flat, so fixity is never consulted. The family of nhc98, MicroHs, hbc.
- **B. An LR automaton driven as Note 5 words it.** What GHC and Hugs do with yacc's `error`. 109 driver and 146 grammar lines, and bison in a bootstrap that today needs none. ML-Yacc has no error productions (`/home/ruud/reference/mlton/mlyacc/doc/mlyacc.tex:140`).
- **C. A rule on tokens alone.** E10's S1, in the line of jhc's Layout2 and GHC's AlternativeLayoutRule. 201 lines.

**The evidence** (E10: `results/E10/summary.txt`, `cases/cases.tsv`, `speed.tsv`).

| | A | B, LALR(1) | C |
|---|---|---|---|
| Files differing from A, of 1,723 | | 0 | 0 |
| Crafted cases right, of 46 | 46 | 46 | 37: 9 of 36 legal refused |
| VM instructions per token | 560.5, with AST | 1,262.9, no AST | not measured |
| Tables | none | 176,122 bytes | none |

- `parse-error(t)` fired 371 times in 165 of 1,670 files. With no rule at all 160 of 1,616 files are lost, so it cannot be left out.
- A and B agree with canonical LR(1) as well, so the automaton's precision does not matter on this corpus.
- No oracle matches the 46 crafted cases: GHC 39, Hugs 38, nhc98 36, MicroHs 35. The expected results are F's.
- GHC's dump of the spike's explicit-brace print equals that of the source on 1,577 of 1,624 files, and none of the other 47 is a layout decision.

**The readings it settles.** R1: the grammar's error rule with flat chains, so `do a == b == c` is refused at fixity resolution, as all four oracles refuse it: a pinned deviation from 9.3's example (D38). R9 likewise. R2: accept, as GHC and Hugs do, a deviation from Note 3 that no corpus file needs. R3: strict `n > m` and the empty-braces reading, which loses `nofib/gc/happy/ProduceCode.lhs`; GHC's `-XHaskell98` is no oracle here. E10 had no fixity pass, so the refusals are deferred, not run.

**Recommendation.** A. **The strongest argument against:** A is the Report's rule by agreement on a corpus, not by construction. B's automaton is the grammar, so its correct-prefix property gives parse-error(t) directly; A's block rule is an approximation of it that has merely not failed yet, and Adams warns that small changes in error propagation change which programs are accepted. B is ruled out by what it costs, not by what it does. So B's grammar stays as a test: `results/E10/spike/hs_lr.sml` run over the corpus can be repeated when the parser changes, without being shipped.

**What would reopen it.** A file or crafted case on which A and an automaton disagree. That is what would have flipped E10.

**Decided (owner, 2026-11-09).** A, as recommended: hand-written recursive descent, with `closeImplicit`.

### D28. AST fidelity and the printer

**Question.** How much of the source does the AST keep, and which round trips hold it honest? The brief asks for a pretty printer to check round tripping, and `lib/language/haskell` may serve other tools. Rune: none. It has no AST round trip of its own: `Ast.decToString` is a debug printer nothing reparses (`lib/compiler/frontend/ast.sml:381`).

- **A. Spans on every node, parentheses, flat operator sequences with negation as an item, literals as written; layout, empty items, comments and pragmas dropped; tree and token round trips.** **Recommended.** E10's AST is 112 lines and its printer 258 (`results/E10/loc.tsv`).
- **B. The same AST, the tree round trip alone.** GHC's `check-ppr`.
- **C. An exact printer.** GHC's `check-exact`, with annotations in every node. HSE has the pair, and calls itself "on life support". Nothing argues that a batch compiler needs it. A tool that needs comments can take the token stream.

**The evidence** (E10, `results/E10/mutants.tsv`, 1,616 files).
- Tree: parse, print, parse, compare with locations erased. Token: the tokens of the print equal `L` of the source, modulo empty items and a trailing comma. Both pass on all 1,723 files.
- B misses what matters: a parser that drops `where` passes the tree test on every file and fails the token test on 743; a dropped context 227, `deriving` 184, a fixity's precedence 91, `~` 9. Both sides of a tree test lost the field.
- Neither catches a compensating pair: parser and printer both swapping `if` passes both. Only running programs do.
- Parentheses must be nodes, since chains are flat until fixity is resolved and brackets change meaning: `n + 1 = 7` defines `+`, `(n + 1) = 7` binds `n`.

**Recommendation.** A. **The strongest argument against:** a printer that prints only braces never exercises `L`, so these tests prove less about layout than they appear to. Erdweg's method prints each AST explicit and implicit and requires one parse, and a corpus does not test a printer at all (Duregård et al. 2012). So M2 adds an implicit print and generated ASTs (D55). The AST's weight, spans on every node, is paid in a batch compiler that does not need them; nothing has measured it.

**What would reopen it.** A tool on `lib/language/haskell` that needs comments in the tree; the AST's size showing in compile time.

**Decided (owner, 2026-11-09).** C, against the recommendation: an exact printer, with annotations in every node. The section above stays as the evidence.

*Lead's note.* E10's AST drops comments, pragmas and layout, and C keeps them, so M11 grows, unmeasured.

*From the papers (E15b).* C comes on top of A's printer and its two round trips, not in place of them. An exact printer cannot print a tree that carries no annotations: generated ASTs, the reducer's output, M2's implicit print. GHC keeps both `check-ppr` and `check-exact`, and Amorim 2018's printer, the nearest published, is not exact: it holds `parse(p) = parse(prettyPrint(parse(p)))` and drops comments (*What the literature says*, D28). Lands in M11.

### D29. Names and fixity

**Question.** Chapter 5 defines exports by what is in scope, circularly. Which solution is meant? When is fixity known? Rune: none.

- **A. The least fixpoint, over each SCC.** **Recommended.** Diatchki, Jones and Hallgren 2002: a name maps to zero, one or many entities, with errors only on use. The Prelude does not import itself. Fixity is an attribute of an entity, read after names.
- **B. Any solution, or the greatest.** Chapter 5 does not say, and neither is wrong by its words.
- **C. A lazy knot,** jhc's `mdo` (`jhc/src/FrontEnd/Exports.hs:82`). It is not an iteration to a fixed point, and what it does on a pathological cycle is not established. SML has no such knot.
- **D. Faxén's section 4.** Rejected: Diatchki names two ways it is "non Haskell 98 compatible", and Faxén leaves out recursive modules.
- **E. Fixity in the parser.** hbc alone. It needs imports resolved before parsing, which R1 and a cycle rule out.

**The evidence.**
- *The fixpoint exists* on the Report's text: 4 rounds from empty, 3 from full, least equal to greatest, 683 pairs (E16, `results/E16/resolve.txt`). `hs_modules.sml` is 364 lines, 318 of code (`loc.tsv`).
- *It is not unique.* A user module defining `map` gives 690 and 693 pairs (`results/E16/tests/imp.out`), for `map` circulates between Prelude and PreludeList. A cycle of two re-exports gives 5 and 7 (`tests/cyc.out`). So the rule must say which.
- *The Prelude's self-import.* 5.6.1 imports the Prelude "into all modules", which read literally includes itself. On the Report's text that has no effect. On Programatica's copy, whose Prelude exports `module Prelude`, it gives 792 pairs from below and 1,181 from above, and without it 792 from both (`results/E16/programatica/resolve.txt`, `resolve-noself.txt`).
- *Fixity.* R25: by entity. 35 declarations; of 260 uses needing fixity 152 come from another module of the unit (`results/E16/analysis-2.txt`). No iteration is needed. HsIface carries fixities (H6).
- *Cost.* Hallgren et al. 2004: 90 seconds for about 50,000 lines. The algorithm is no concern.
- *Limits.* The paper covers names only, not scoping inside bodies or instance visibility. Deriving must name entities: derived `Ix` in `Time` needs methods it did not import (E16).

**Recommendation.** A. The Prelude's self-import is a deviation from 5.6.1 read literally, recorded as such. **The strongest argument against:** the least fixpoint is a choice the Report does not make. Chapter 5 is satisfied by either solution, so this refuses a reading the text leaves open, on the strength of one paper. It is taken because a larger solution lets an export justify itself, and because the Report was revised partly on that paper's work (*What the literature says*). Which three pairs separate E16's 690 from 693 was not listed.

**What would reopen it.** A legal program whose meaning needs a larger solution; an erratum on the point.

**Decided (owner, 2026-11-09).** A, as recommended: the least fixpoint, with the Prelude not importing itself and fixity read after names. And at the owner's request, "can we make least/greatest fixpoint a language/compiler option please as we did in rune for some of the sml97 ambiguities": an option, `--names=least|greatest`, least by default, as Rune has `--flex-records`, `--overloading` and `--free-tyvars` for SML '97's (`src/driver/options.sml:90-96`). Chapter 5 is satisfied by either, so the greatest is a reading of the text, not a deviation. Lands in M12.

### D30. Recursive modules

Chapter 5 says "Modules may be mutually recursive.", and gives it as a purpose of modules. 5.7 is all it says on compiling them (*What the Report says*). The owner's direction, 2026-11-01:

> since i'm interested in make a compiler close to the report it is very likely we'll support recurisve modules then and may also follow the report on its recursive structures. so these should be possible decions in the roadmap

So support is expected, and recursive modules are on no cut list. The question is what support means.

**Question.** What does rhc do with a cycle of modules, and what does it ask of the programmer?

- **A. One unit per SCC, a joined checker, no extra files.** **Recommended.** The driver finds modules by scanning imports and takes the SCCs; each is one compilation unit.
  - *Names:* a least fixpoint over the SCC (D29).
  - *Types:* the members' declarations are pooled and checked as one, under names scoping has already made unique. Kinds go by dependency group over the SCC (R28). Binding groups cross modules, and no signature is needed.
  - *Semantics:* chapter 5's concatenation: "A multi-module Haskell program can be converted into a single-module program".
  - *Precedent:* jhc (`jhc/src/Ho/Build.hs:304`, `jhc/src/FrontEnd/Tc/Module.hs:139`) and Programatica (`programatica/src/programatica/tools/base/Modules/Modules.lhs:364`, `programatica/src/programatica/tools/base/TI/TiModule.hs:62`). Neither was run here, and neither has been maintained for years.
  - *Rune:* none. `Deps` refuses a cycle (`lib/compiler/driver/deps.sml:270`), and rhc's driver does not use it. One unit per SCC costs the store, `Link` and `UnitFile` nothing (E13). A cycle's top-level values are one recursive group of thunks (D6), so initialisation order is no problem [inferred].
  - *rhc:* about 45 lines of driver, of the toy's 766 [inferred], and the join, unsized. All of it works in whole-program mode before any cache exists; the key and identity over every member wait for M22.
- **B. Signatures in the module, 5.7's words.** "Explicit type signatures for all exported values may be necessary to deal with mutual recursion." Each module stays its own unit, and a signature cuts the cycle.
  - It rebuilds least, below. The toy's cost: about 12 lines, plus signatures kept by hand, with a check that each still holds (`results/E13/toy/p6.out`: "M5: f1 is not as its signature here says").
  - *Rune: small to medium, unbuilt.* A value read through such an edge is an internal error in `Link` (`lib/compiler/backend/link.sml:202`, `results/E13/toy/p6.out`), so forward links are needed.
  - It leaves two holes. Kinds do not cut: Haskell 98 has no kind signature, so a type group across modules needs inference over the boundary (R28). And it cannot accept a cycle with unsigned bindings, which chapter 5 calls legal and 5.7 only says "may" need more. Instances across such an edge were not established.
- **C. Boot files.** GHC and MicroHs. A hand-written `.hs-boot` beside each cycle. It is 5.7's "additional information" in another form, and must not be confused with B.
  - It cannot express every legal cycle. Three modules, each a type and a signed function over all three: GHC 9.4.7 refuses with no boots, and with boots for all three gives "Unexpected non-cycle", an internal message; joined into one module they compile (`results/E15/run/boot3.txt`). Every value is signed, so 5.7's condition is met. One arrangement with boots was tried. That none exists is an argument, not a test.
  - GHC's own notes say that keeping to its old rule, never touching a forward-declared entity before it is checked, "has proven to be a bug farm", and it now falls back on the boot file (`ghc/compiler/GHC/IfaceToCore.hs:2098`).
  - *Rune:* B's forward links. *rhc:* a second file format and a check of each boot against its module.
- **D. Refused.** Hugs, Yhc, UHC, Helium. *Rune:* none. It saves the 45 lines and the join, and no corpus program would notice. But chapter 5 is unconditional, and the owner's deviation rule covers what is wrong, contradictory or ambiguous; this is none of those. It also removes the literal layout from D36.

**What one unit per SCC costs** (E13, `results/E13/toy/p5.out`, `p6.out`; VM instructions of the toy's compiler).

| Edit | One unit per SCC | Alternative |
|---|---|---|
| 5-ring, a body | 5 modules, 1.90M | 5.7 signature: 1, 0.89M |
| 5-ring, a type used only inside | 5, 1.92M | 5.7 signature: 2, 1.04M |
| 5-ring, a type `Main` uses | 6, 2.03M | 5.7 signature: 2, 1.01M |
| The Report's 11, the body of Numeric | 11, 52.1M | layered: 1, 20.1M |

So an edit inside a cycle costs 1.8 to 2.6 times here. The toy has no front end, so those are ratios of a toy; rhc's real compile times are not established. The cost stays inside the cycle: a body edit recompiles no client, a type edit only its users, and a cycle that splits recompiles clients once (`results/E13/toy/p3.out`, `p5.out`). A program with no cycle pays nothing. H8 is what a hit must hold here: a key over every member, fingerprints by recursive group, the unit's name in the usage (97 wrong of 15,750 without).

**`default` in a cycle.** Chapter 5 names what concatenation does not preserve: "First, default declarations scope over a single module (Section 4.3.4). Second, Rule 2 of the monomorphism restriction (Section 4.5.5) is affected by module boundaries." A join loses the module, so these are the two things a joined checker must put back. **No implementation gives each module its own `default`:**
- Programatica solves each ambiguity under every `default` of the group, and fails with "Conflicting default declarations" if the results differ (`programatica/src/programatica/tools/base/TI/TiDefault.hs:48`, `:63`). A module with none takes the group's, not `(Integer, Double)` (`programatica/src/programatica/tools/base/TI/TiModule.hs:34`).
- jhc parses `default` and never uses it (`jhc/src/FrontEnd/Tc/Class.hs:230`).

Rhc needs a rule of its own, and three are open:
- **Each module its own.** **Recommended.** The join keeps each declaration's module, as Programatica's `splitModule` does by file (`programatica/src/programatica/tools/base/TI/TiModule.hs:70`). 4.3.4 defaults a type variable, not a constraint, so the rule is on the variable: it defaults by the `default` of the module its constraints arose in, and `(Integer, Double)` if that module has none. Where they arose in modules whose `default`s differ, rhc refuses that case only, which is Programatica's rule narrowed. A monomorphic variable left at the end takes the `default` of the module binding it. This is the Report's reading where the Report has one. It is untested, with one field on a placeholder as its cost [inferred].
  - *Where the tie-break bites* [deduced, not runnable, since no oracle takes cycles]: unsigned `f` in A and `g` in B are mutually recursive, `g :: RealFrac v => Bool -> v -> Int`, and `f` passes a literal. R21 gives one context per group, so `v` is ambiguous in `f`. `Num v` arose in A and `RealFrac v` in B. With `default (Integer, Double)` in A and `default (Int, Float)` in B the two modules give `Double` and `Float`, so rhc refuses.
- **One per SCC, differing ones refused.** Programatica's, and R20's seed. Simpler, and it refuses a program chapter 5 calls legal.
- **Ignored.** jhc's. Wrong wherever a module declares one.

**Rule 2 closes at the end of each module, even within a cycle.** 4.5.5 says "the exact types of all the variables bound in a module must be determined by that module alone, and not by any modules that import it", and in a cycle every member imports every other. So a joined checker keeps each monomorphic variable's module, and refuses a program in which another member's use would be what fixes the type. That follows the direction to lean to the text, and it is unbuilt. **The alternative is the end of the SCC,** as Programatica defers to the end of the module group (the partition at `programatica/src/programatica/tools/base/TI/TiGeneralize.hs:96`, the group's end at `programatica/src/programatica/tools/base/TI/TiModule.hs:55`). A use in another member can then fix a type. That is convenient, and it accepts what 4.5.5 forbids, so it is an extension, outside the deviation rule (R20).

The libraries do not need any of this: E16 finds no `default` declaration in the 20 modules, and Programatica's `default()` in Numeric reaches one expression. For a user's cycle it stays open.

**No independent oracle.** No candidate of E8's 3,089 has a plain import cycle (`results/E8/judged.tsv`). Of the 7 with `.hs-boot` companions GHC accepts only `rn017`, Hugs and nhc98 none. Probe `r29`: GHC, Hugs and nhc98 all refuse a plain cycle of two. Jhc and Programatica were not run. So every test of this decision is written by hand from the Report and has no independent check of its expected result (D52). What is available: each cycle's joined form runs on the judges, by chapter 5's own conversion, except at the two exceptions above; and, by hand, the literal layout against `merge.py`'s form (D36). No paper was found on types across a cycle (*What the literature says*), so the semantics is rhc's own design.

**Recommendation.** A, with each module its own `default` and Rule 2 closing at the end of each module. **The strongest argument against:** this builds, for a feature no corpus program uses, a design that no maintained compiler has, with a semantics of its own and no oracle to check it, and it costs 1.8 to 2.6 times on every edit inside a cycle. B is within the Report's words, is local to the edit, and is what 5.7 itself names. D is what most implementations do, and nothing in the corpus would fail. The answer is the owner's direction and the text: B and C refuse programs chapter 5 calls legal, and only A accepts every cycle.

**What would reopen it.** M22's real compile times, which would bring in Flatt and Felleisen's way of keeping a cycle apart, or B as an optional cut inside A where every edge is signed (E16 shows that the Report's text would allow one); the owner taking the simpler `default` rule, or the end of the SCC for Rule 2; a cycle that a join cannot type; v2's D5 and D6 fixing a written order for every language (`results/E13/toy/p7.out`).

**Decided (owner, 2026-11-09).** A and each module its own `default`, both as recommended. And at the owner's request, "can we make default per module/per scc a language/compiler option please as we did in rune for some of the sml97 ambiguities": an option, `--cycle-default=module|scc`, `module` by default.

*Lead's note.* Rule 2's closing point, the end of each module or of the SCC, is offered under the same option, since the two are the same choice about where a module of a cycle ends.

*Note.* The `scc` setting is outside D38's deviation rule, as the section says of both: it refuses a program chapter 5 calls legal, or accepts what 4.5.5 forbids. So it is an extension the owner asked for, off by default and documented as one. Lands in M12 and M13.

### D31. Checker structure and evidence records

**Question.** How is the type checker built, and what does it leave for Core and for HsLint? Rune: none under every option. `Types.ty` holds no class context and no variable-headed application (`lib/compiler/elab/types.sml:8-12`), so rhc has its own types; `Witness` is a model and not code to share.

- **A. One inference over the renamed AST, with evidence recorded by node.** **Recommended.** Types by first-order unification. Each overloaded use leaves a placeholder, a ref cell, resolved at generalisation as a dictionary parameter, an instance, deferred outward, or ambiguous. The final choices go into tables by node, as `Witness` records what SML's elaborator chose (`lib/compiler/elab/witness.sml:1-8`), for desugaring and HsLint to read.
- **B. Typing Haskell in Haskell as it stands.** Clear, and it produces no evidence, so it cannot elaborate. It is a basis for D54, not for rhc.
- **C. Constraint generation and a solver.** HM(X), OutsideIn, or Helium's constraint tree. It would buy messages and a head start on a later language, and the brief keeps that for a later roadmap.
- **D. Mutating the tree, or lazy tables.** Hugs's `DICTVAR` is close to A. nhc98's and hbc's knot-tied tables need laziness SML lacks.

**The evidence.**
- *W4.* Unification is the smallest part. The rest is the list this decision commits to: kind inference, context reduction, dependency analysis, the monomorphism restriction, defaulting, derived contexts (*What the literature says*, table under D31).
- *No solver is needed.* Givens come only from signatures, class and instance contexts, with no unification variables; patterns bind nothing; predicates produce no equalities. Nobody needs implications to check Haskell 98: GHC alone has them (`ghc/compiler/GHC/Tc/Types/Constraint.hs:1032`).
- *Scale.* nhc98's `Type/` is about 1960 lines, and hbc's `hcheck.m` 468. F's estimate from renamer to match compilation is 7-14k lines of SML [estimate, E10].
- *What must come first.* Termination of entailment rests on the Report's syntactic conditions, so class and instance checks run before it (Jones 1999, §7.3).
- *What the records hold.* Faxén's `dict` judgement: a variable, a dictionary function applied to types and sub-dictionaries, a superclass selector, a tuple (fig 28). For a default: the variable, its predicates, the list in scope and the choice, since a defaulted type is decided by decree and coherence does not apply. Dictionaries need a polymorphic field in Core, and cross to Mid as `Any` (D4).
- *Across a cycle.* E16: 0 cross-module binding groups in the Report's libraries, so the join matters for users' cycles (D30).

**Recommendation.** A. **The strongest argument against:** inference and elaboration share one pass and one set of ref cells, so a bug in resolving a placeholder yields well-typed Core that means the wrong thing. `show (read "True")` elaborated at `Int` and at `Bool` is well typed at `[Char]` either way, and CoreLint cannot see it. A does not protect itself; D54's second inference is what does, and without it A should not stand. C would also spare a second inferencer for Haskell 2010.

**What would reopen it.** D54 finding the records too weak to check against; the roadmap for later languages being brought forward.

**Decided (owner, 2026-11-09).** A, as recommended: one inference over the renamed AST, with evidence recorded by node.

### D32. Monomorphism and defaulting readings

**Question.** What does rhc do where 4.5 does not settle a program? This is R18, R20, R21, with R19 and R22 beside them. The meaning of a program here is defined by a deterministic procedure, so a checker must compute the type the pinned algorithm gives, not merely a legal one (*What the literature says*). Rune: none.

| Reading | What is open | Recommended | What the oracles do |
|---|---|---|---|
| R18 | "simple pattern binding" has two definitions, and Rule 1 turns on it | 4.5.5's: one variable, guards allowed; `(x)` and `~x` not simple | GHC on all four probes; Hugs and nhc98 each differ [probe `r18a`-`r18d`] |
| R19 | A signature on a non-simple pattern binding | Refused | GHC, Hugs refuse [read] |
| R20 | When a monomorphic variable defaults | The end of the module | GHC alone gets all three programs right [run, probe] |
| R21(c) | A signature does not cut a declaration group, yet each use "is treated as having the declared type" | Typing Haskell in Haskell's split of explicit from implicit | GHC per binder [read] |
| R21(a), (b) | One context per group; signed contexts "must be identical" | **Marked for the owner.** The text | No oracle enforces (b) [probe `r21`] |
| R22 | The conditions on defaulting | The text: `print (reads "1x23")` is refused | GHC and Hugs refuse; nhc98 prints [run] |

**The options** on each row are the text's reading and the differing oracle's. On R20: Hugs defaults each top-level group at once, which refuses 4.5.5's legal `module M` [probe `r20`]. 30 corpus programs are refused by Hugs alone; those read by hand are this case, the rest [inferred] (E8). nhc98 has no restriction, and lets Rule 2's own counterexample through [probe `r20b`].

**Where the pinned algorithm must not be copied.** Typing Haskell in Haskell's `split` passes only variables common to a group's members, so in a restricted group with different type variables a constrained variable defaults at once, where Rule 2 keeps it open. Faxén's rules admit two types for `f x y = let g = isNil in (g x, g y)`; rhc pins `forall a. IsNil a => a -> a -> (Bool,Bool)` (*What the literature says*).

**R21(a), (b), for the owner.** The text is plain, and all three oracles accept what it forbids. It is the same shape as D38's `Just.let`, and the same rule says follow the text: refuse. On the Report's libraries the question does not arise: 0 recursive value groups (E16). Whether a corpus program depends on it needs a checker to find out.

**Recommendation.** The table. **The strongest argument against:** on most rows the recommendation is GHC's behaviour, and an implementation's behaviour is what D52 says not to trust. And end-of-module defaulting is the costly reading: Rule 2 means a module's exported types are known only when it is finished (R20(e)), and in a cycle a joined check must still hold each module's to that module alone (D30). Hugs's early defaulting would make all of that simpler, at the price of refusing the Report's own example. On each row the choice follows the text; that GHC agrees is a check on it, not the reason.

**What would reopen it.** HsLint's second inference disagreeing on a corpus program; the owner's call on R21; a corpus program refused only by R21(b).

**Decided (owner, 2026-11-09).** The table, as recommended: R18 by 4.5.5, R19 refused, R20 at the end of the module, R21(c) by Typing Haskell in Haskell's split, R21(a) and (b) by the text, and R22 by the text.

### D33. Deriving

**Question.** Where is derived code made, and what specifies it? Rune: none.

- **A. On the renamed AST, with chapter 10's text as the specification.** **Recommended.** nhc98, Yhc, hbc. Code comes from the data declaration; the context is computed after kinds and instance heads are known and before value bindings are typed, by the fixed point 10.1 allows, over the SCC under D30 [inferred]. The methods then enter as ordinary instance bodies, and `deriving` adds no dependency.
- **B. On source syntax, before renaming.** Hugs, jhc. Spelling cannot do: derived `Ix` in `Time` needs methods `Time` did not import, so deriving must name entities (E16).
- **C. Inside the checker, from the typed constructor.** GHC, MicroHs, Programatica. More machinery, and no gain here.
- **D. On Core.** UHC. After types, so dictionaries are written by hand.

**The evidence.** Faxén omits deriving because "generating derived instances can be done before type checking" (§1.3), which holds for code and not for contexts: 10.1's context is a condition of entailment over the instance environment. nhc98, Yhc, Hugs, hbc and Programatica all compute it by a fixed point.

**The readings.**
- **R41:** the Report gives no figure for a record, and all three oracles differ on text a program prints, so no oracle can settle it. **Recommended:** GHC's row, which Haskell 2010 took [memory]. `conformance98`'s `fields/*` expectations then disagree with nhc98, on the record.
- **R27:** seven classes, `Ix` by 15.1 with 10's six.
- **R23:** `newtype` as `data`; a derived context that is not simple is a static error.
- **R42, R43:** text and code disagree in the Prelude, which is D37's.

**Recommendation.** A. **The strongest argument against:** chapter 10 is not a full specification, and on the point programs print most, record syntax, A's "text as the specification" means GHC's choice. C would at least catch a bad derivation by typing it. But A's output is typed as ordinary instances anyway, so that advantage goes, and the choice of GHC's row is recorded under R41 either way.

**What would reopen it.** Derived `Read` being unusable: its exponential cost on nested parentheses is the Report's own ("very inefficient", 10.4), and nhc98 exhausts its heap or time on `infix/derived` (E7).

**Decided (owner, 2026-11-09).** C, against the recommendation: deriving inside the checker, from the typed constructor, as GHC, MicroHs and Programatica do. The section above stays as the evidence.

*From the papers (E15b).* With D54's C, a derived instance made only as typed output gives neither replay nor the second inference a source phrase to check. So the instance is made as AST, after the checker has inferred its context, and is elaborated like a user's, which is GHC's route; HsLint then checks it as it checks any instance. Faxén has no deriving rules, so the minimality of a derived context (10.1) is checked by no layer of HsLint, only by conformance rows. Lands in M13 and M14.

### D34. Desugaring and match compilation

**Question.** How does the renamed, typed AST become Core, and in what order are patterns tested? 3.17.2: "Pattern matching proceeds from left to right, and outside to inside". A compiler is free only in tests on values already forced, and in sharing.

- **A. rhc's own desugaring to Core, with the mixture rule, keeping the Report's order, at every level.** **Recommended.** Backtracking, with a failure join point (`Join` in Mid). Every implementation with a matrix does this; none of the ten uses decision trees. Rune: none.
- **B. A, plus Sestoft-order decision trees as an option.** Legal: "Our naive matcher, and hence our match compiler, implements pattern matching as required by the Haskell report" (Sestoft 1996, §8). Off at `-O0`, and differenced against it (*Testing and conformance*). Rune: none. **Optional, recommended later.**
- **C. The rules of 3.17.3 as a compilation scheme.** Programatica has it as an optional rewrite. The Report says "it is not expected that it will use them directly"; rules (b) and (c) do not terminate as a rewrite system, and rule (g) grows exponentially in pattern depth [inferred]. A semantics, not a scheme.
- **D. Medium: reuse Rune's `trees`.** It picks the same order (`lib/compiler/core/matchcomp.sml:236-246`), but makes no test for a tuple or record and leaves the last constructor untested, right for SML where a value is evaluated, and wrong for `f () = 1`, which must force [deduced; not run]. It works on Lambda and SML patterns. Rejected as it stands.
- **E. Maranget's necessity heuristics.** Not conformant: they give `F bottom false` a value where the Report gives bottom.

**The evidence.**
- *Order of desugaring.* Faxén's, not Typing Haskell in Haskell's: the Report's translations are themselves overloaded, so overloaded literal and n+k patterns carry dictionaries into the match compiler (§8.4, §9.1).
- *Defects in the rules.* Translation defects 8, 9, 10, 12, 13 and 14 (*What the Report says*); R15, R16, R17. A literal `-O0` needs care at (b), (c), (d) and (g), and its sharing is rhc's own rule.
- *Size.* On hand-written strict ML heuristics change little (Scott, Ramsey 2000). But on a bytecode a path of 6.33 against 3.14 was seen (Maranget 2008, §9.3), and E12 has `trees` off at +6.6% instructions on the compiler, so B may be worth it on Rune's VM.
- *Arity.* `f = \True x -> x` and `f' = \True -> \x -> x` differ under `seq`, so a match compiler may not change arity. A test at each position: put bottom there.

**Recommendation.** A at first; B when a program shows the need. **The strongest argument against:** Rune already has a tested decision-tree compiler, and A writes a second match compiler that is slower on a bytecode by the literature's one figure. But `trees` would have to learn to force, down to a one-constructor type, and to carry the dictionaries of overloaded patterns, on an IR rhc does not use. Repeated tests left by backtracking go in Core by case on a known variable.

**What would reopen it.** `--count` on the corpus showing repeated tests dominate after D47's simplifier, which brings B forward.

**Decided (owner, 2026-11-09).** To be measured: B, Sestoft-order decision trees as an option, built and benchmarked on rhc's programs; then A or B on the numbers. Until then A stands. M15 builds it (*Decisions on the numbers*). Pettersson 1992 found no gain in code size from a matching automaton, so B is judged in VM instructions on match-heavy programs, not in size. D17's B, if taken, changes how pattern bindings and `~p` are desugared, which this decision's A covers.

### D35. Hierarchical names

**Question.** `modid` is one `conid` (R7, R34), so `Data.List` is outside the language. What does rhc do with it? Rune: none.

- **A. Refused, with no flag.** The Report exactly. E8's harness can rewrite imports instead. nhc98's compiler can then never be a target.
- **B. Refused by default, with a documented flag for the corpus.** **Recommended.**
- **C. Accepted by default.** Every oracle's own libraries use dotted names. It is a deviation the owner's rule does not cover. It also changes the meaning of legal programs: by 2.4 `A.B.c` is the qualified constructor `A.B`, then `.`, then `c`, and with dotted names it is one qualified variable [deduced from 2.4; not run].
- **D. Rewriting imports in the harness only.** E8's `import rewrite`: 64 candidates, 27 of them in the 2019 nofib. It serves `Data.List` for `List`. It does not serve a program's own dotted modules.

**The evidence** (E10, `results/E10/summary.txt`: files parsed, strict and with dotted names):

| Set | Strict | Dotted |
|---|---:|---:|
| nhc98 nofib, 423 | 402 | 402 |
| nofib, 590 | 268 | 510 |
| `conformance98`, 98 | 76 | 82 |
| nhc98's compiler, 147 | 23 | 144 |

33 of the 109 modules in nhc98's compiler closure have dotted names (`results/E8/compiler98/judge.out`). The flag is small: the spike has it at four lines (`results/E10/spike/hs_lexer.sml:24`, `:378`, `results/E10/spike/hs_parser.sml:61`, `results/E10/spike/hs_main.sml:276`). No paper bears on it.

**Recommendation.** B: a flag, off by default and documented, used by the corpus harness, with `mod.name.modid`'s row pinned on the default. **The strongest argument against:** a corpus run under the flag runs under a lexer that is not the Report's, so the tests prove a slightly different language from the one claimed. Each flag is also a mode to keep working. D avoids that for most of the 2019 nofib. B is kept because nhc98's compiler, the largest realistic target (E8), cannot be reached otherwise, and because the flag is four lines.

**What would reopen it.** The Haskell 2010 roadmap, whose mode has it on.

**Decided (owner, 2026-11-09).** B, as recommended: dotted names refused by default, with a documented flag for the corpus.

### D36. Library layout

Chapter 8 prints the Prelude as four modules that import Part II's libraries, which import the Prelude, so the Report's code as printed is one 11-module SCC with 9 singleton modules above it (`results/E9/report-libs/graph.txt`). The owner's direction, quoted in full at D30, says rhc "may also follow the report on its recursive structures". Chapter 8 permits every option here: "This structure is purely presentational. An implementation is not required to use this organisation for the Prelude, nor are these three modules available for import separately." and "These imports are not, of course, part of the specification of the Prelude." Those sentences cover the Prelude's imports. `Char` and `Numeric` still import each other with no disclaimer; a program sees only exports, so it cannot tell [inferred]. This is a G0 decision.

**Question.** What shape does `share/rhc/haskell98` have, and what does the compiler compile, when?

Rune: none under every option. *The three layouts* in *What the Report says* compares them; what decides is below.

- **A. The literal layout.** **Recommended.** The 20 modules as printed, the SCC one unit, `PreludeList`, `PreludeText` and `PreludeIO` present and not importable.
  - *Gain:* the Report's text, unchanged but for the 8 names of D37. The exit test's diff is by module. It is the largest cycle to hand, and the only one not written as a test.
  - *What it needs:* the fixpoint, which D30 needs anyway; one unit-wide pass over declarations; a list of hidden modules, a few lines of `check` (`results/E16/tests/hidden.out`).
  - *What E16 found:* it is not an inference problem. There are 0 cross-module binding groups, and all 887 cross-module value edges land on signed values or methods. The exception is the four-node type group across Prelude and Ratio, where kind inference must cross (R28). GHC typed the unit after one annotation (`results/E16/ghc/changes.txt`), at the one expression in the cycle that depends on defaulting.
  - *Cost:* it needs D30's fixpoint and joined checker before it compiles at all, which the order gives (below). A body edit recompiles 11 modules (52.1M, E13, toy bodies). It has no execution record: Programatica's copy passed a front end about twenty years ago, and nothing ever ran it. The 8 names of D37 and the `Char` clash below stand as costs.
- **B. The merged layout.** Hugs's. One internal module with no implicit Prelude, and thin public modules.
  - *Gain:* bodies and headers verbatim, one unit, dictionary recursion inside one module, and no recursive modules needed for G1.
  - *Cost:* one rule outside the Report, that the internal module has no implicit Prelude. The exit test's diff is by definition and export list.
- **C. Layered.** GHC's, jhc's, UHC's.
  - *Gain:* the best rebuild: a body edit of Numeric recompiles 1 module (20.1M, E13).
  - *Cost:* it departs furthest. 59 definitions, 329 lines, must sit beneath the Prelude, making a bottom layer of 1,720 of the 2,436 lines (`results/E16/analysis-2.txt`). Moving `Show Float` and `Show Double` alone changes nothing: it takes all numeric `Show`, all `Read`, `lex`, `words`, `Show Char`, the `Rational` edges and `readEsc` together. It was sized, not generated.
- **D. A as the source of truth, B derived from it.** The fallback. `share/rhc/haskell98` holds the Report's layout and a tool derives the merged form, which the compiler runs until D30 lands. Built only if the joined checker runs late.

**The fallback's tool cannot be `merge.py`.** It is 47 lines of Python, and `tests/runner/migration.sml:2,10` requires an owner for every live `.py`, so it cannot land as it stands. It becomes a small tool in SML. Proposed here: under `src/rhc`, running at build time. Its size is not measured.
- *What `merge.py` showed* (E16): 2 lines changed (`Char.isSpace`), 22 import lines dropped (`results/E16/merge.log`); all 20 modules' 663 export pairs, 35 fixities and 164 instances identical (`results/E16/check_merge.txt`). It resolves Ratio's four names on its own, not `interact`'s (`results/E16/merged.raw`).
- *What it did not do.* Its header says no two of the 11 modules define one name, "checked below", and the script has no such check. The 369 names were recounted clean for *What the Report says*. The SML tool must make that check.
- `check_merge.py`'s table of exports, fixities and instances lands under any option, as a test in SML (M17).

**A user module named `Char`.** Under the literal layout the library's `Char` lies in the Prelude's closure, so it is in every program, and a user's `module Char` meets it. So a module's identity must include its library: in the resolver, in entities by origin, in unit names and usages (H7, H8). This is rhc's cost, and no Rune line. E16 did not build it and gives no size.
- *In the corpus* (`results/E16/collisions.txt`, over E10's positive list): `Maybe` once, `nhc98/tests/nofib/real/infer/Maybe.hs`, and `Prelude` once, a GHC test. None is named `Char` or `Numeric`. Chapter 5 allows a user's `Prelude` outright.
- *Dropping `Array`'s dead `import List((\\))`* takes `List` and `Maybe` out and makes the SCC 9, which clears the one corpus case. It is one more overlay entry. `Char`, `Numeric`, `Array`, `Ix` and `Ratio` stay exposed.
- *Under the merged layout* the exposure narrows but does not go. The thin `Char` imports only the internal module (`results/E16/merged/Char.hs`), so nothing in the Prelude's closure imports it, and a user's `Char` meets the library's only through `Time` or `Directory` (`results/E16/merged/Time.hs`) [deduced]. A needs the identity rule from M12, since the literal form is what runs.

**What one unit costs a program** is the same for A, B and D. The unit is 525 definitions; `putStrLn "hello"` reaches 19 (3.6%) and `print 42` 111 (21.1%) (E16). Units do not shake (`docs/units.md:47-52`), so a frozen unit links whole; D45's frozen form must say what that costs. Link size and start-up of the 11-module unit are not established (E13). With a frozen unit hello compiles one module (E13, `toy/p5.out`).

**The evidence for A over D.**
- The roadmap's own order lands M12 and M13, with cycles and the joined checker, before M17 and G1 (*The order*). So the risk D guards against, a first hello waiting on recursive modules, does not arise, and all of this runs whole-program with no cache.
- D buys a tool, a test and a rule outside the Report against that risk. Under A the Report's text is what is on disk and what the compiler runs, and the overlay stays a list against it.
- It is the owner's stated direction.
- E16 shows that the two forms agree in exports, fixities and instances, and `merge.py` shows the merged form can be derived. So if the joined checker runs late, D is a mechanical fallback, built only then.

**Recommendation.** A, the Report's graph compiled directly as one unit, with D as the fallback. **The strongest argument against:** it puts the largest cycle to hand under the first hello, in a feature with no oracle (D30) and a layout with no execution record, so a fault in the joined checker first shows as a broken Prelude. It also gives up the strongest check D30 could get, the literal form against the merged form on every run program, which only D has. `merge.py` stays in the drafts and that comparison can be made once by hand, but it does not land (`tests/runner/migration.sml:2,10`). B alone is simpler, and C rebuilds best. Chapter 8 says a program cannot observe the difference, so A pays the 8 names and the `Char` clash for the owner's direction and the text, not for a result.

**What would reopen it.** The owner, at G0. The joined checker running late against M17, which brings in D. D30 taken as refused, which leaves B. M21 or M22 showing the literal unit far dearer to compile than the merged one: no one has published a cost, and jhc's largest SCC is 10. Library edits being frequent enough that 2.6 times matters, which brings in C for rhc's own use.

**Decided (owner, 2026-11-09).** A, as recommended: the Report's graph compiled as one unit, with D as the fallback, built only if the joined checker runs late.

### D37. Prelude overlay and licence

**Question.** What is shipped in `share/rhc/haskell98` beyond the Report's text, and under what terms? Rune: none in the compiler; one sentence in the top-level licence.

*The code:*
- **A. The Report's text alone.** It does not compile: `data ()`, `...`, 8 names that do not resolve (R47).
- **B. A listed overlay.** **Recommended.** Every change names its reason, a reading or an erratum, and is pinned. The list is the table in *The libraries*: about 15 named definitions [counted by hand], among them `Show Float` (R42), `getLine` (R46), `interact` and `numericEnum*` (R47), tuples to 15 (R51), `Array`'s representation (R49). So the exit test's diff against the Report stays explained.
- **C. Rewritten for speed.** Foldr/build needs a Prelude rewritten: about 3-5% on GHC of 1996-2001. Not now, and the overlay need not carry `build` (*What the literature says*).
- **D. A local copy as the base.** No copy is the Report: the nearest, jhc's, is the same in 484 of 742 definitions (E9).

*The 8 names* (`results/E16/graph.raw`, 10 uses): `hSetBuffering`, `stdin`, `stdout`, `NoBuffering` in `interact`, and four `numericEnum*` in Ratio, which the Prelude does not export, as Ratio's own comment admits. Chapter 5 has no remedy. In the literal layout one hidden module moving 14 lines fixes the second set (`results/E16/overlay-resolve.txt`); the merged form resolves them on its own. `interact` needs an entry under either; importing `IO` for it would make the SCC 12 [inferred]. `interact`'s names came with the revision of late December 2001 (E16 addendum).

*The licence.* The Report's notice lets a modified version be copied "for any purpose, provided that the modified version is clearly presented as such, and that it does not claim to be a definition of the language Haskell 98."
- **A. `share/rhc/haskell98/LICENSE`, carrying the Notice and a statement of modification, and a sentence at top level excepting the directory.** **Recommended.** jhc, nhc98 and Hugs carry it too. rhc's documents say "implements", never "is".
- **B. Leave it under the repository's CC0.** CC0 waives only the owner's rights and disclaims "clearing rights of other persons" (`LICENSE:113-114`), so a reader would think the two conditions could be dropped.
- **C. Fetch the text at build time.** It adds a network step to a bootstrap, and buys nothing.

**Recommendation.** B and A. **The strongest argument against:** "about 15" is a hand count, and an overlay that can change `Array`'s representation can change anything, so an exit test that allows the overlay is only as strict as the list is short. Text and code disagree in further places where E9 says no change is needed (R49), and each of those is a test that pins one side. On the licence: not legal advice, and it is not established whether a code listing is separately protected, nor what bytecode linking these libraries owes.

**What would reopen it.** M17 finding the list much longer than 15; legal advice on either open point.

**Decided (owner, 2026-11-09).** Code B and licence A, as recommended: a listed overlay, and `share/rhc/haskell98/LICENSE`, marked modified. **The owner, 2026-11-10:** "Don't change the toplevel license please and no need for the note": the top-level `LICENSE` stays as it is, with no sentence about `share/rhc/haskell98` and no NOTICE file; `share/rhc/haskell98/LICENSE` alone says that the Report's notice covers that directory and the repository's CC0 dedication does not.

### D38. Which text

**Question.** "haskell 98 as per the revised report" names which text, and what does rhc do where the text and every implementation part? This sets the rule the other decisions apply. Rune: none.

- **A. The online Report as served.** December 2002, with no erratum applied: 16 of 18 confirmed unapplied, 1 about the printed index, 1 untestable (E9, `results/E9/errata-status.tsv`). It keeps known mistakes that change what a program does: R16's field order, R39's `Enum`, R43's `lex`, R48's `genericTake`.
- **B. That text plus the published errata, all listed.** **Recommended.** The list is the table under *Which text*. An erratum that changes behaviour is applied and pinned; one that changes the Prelude's code is an overlay entry (D37). What it leaves open is a choice, recorded as one (D53). On departures from the text, one rule, below.
- **C. The printed book.** Not checked. The errata page's page numbers are the book's. The PDF agrees with the online text on the two markers its extraction shows.
- **D. The Report as implementations read it.** It fails the owner's rule. E7's hard cases show that the oracles part among themselves, and on R7, R42 and R5 they agree against the text.

The errata do not reach the worst of it. R7's `[LT..]`, R42's `Show Float` and R47's Prelude are on no list, so the deviation rule does more work than the errata do. Faxén's rules may be cited as a basis, with his departures from the Report listed (*What the literature says*).

**One rule for departures from the text.** rhc follows the text unless it is wrong, contradictory, ambiguous or cannot be implemented. Unanimity of implementations alone is no ground. Every departure names its ground and is pinned by a test. The first three grounds are the brief's; the fourth is this roadmap's reading of "wrong", that a sentence no compiler can implement as written cannot bind one, and the owner may strike it. Every case, sorted:

| Case | The text | rhc | Ground |
|---|---|---|---|
| R1, and R9 for `let` | 9.3's `parse-error(t)` gives `do a == b == c` one parse | Refused at fixity resolution, with all four oracles | Cannot be implemented as written: `parse-error(t)` depends on fixities, known only after renaming |
| R2 | 9.3 refuses a `}` under an implicit context, and 2.7 closes one | Accepted, as GHC and Hugs | Contradictory: 2.7 and 9.3 disagree |
| R5 | A character outside `ANY` is a lexing error | Any character in comments and literals, with all three | Wrong: by the letter, an error in a comment |
| R42, R43, R47 | The Report's own code disagrees with its text, or names what does not resolve | An entry in the overlay (D37) | Contradictory or wrong, entry by entry |
| The Prelude's self-import | 5.6.1 imports the Prelude "into all modules" | Not into itself (D29) | Ambiguous: on the Report's text it has no effect, and chapter 5 does not say which fixpoint |
| `[LT..]`, R7 | 2.4 reads an operator `.` of a module `LT`; 6.3.4's example does not | Refused, with all four | Wrong: the example, recorded and not copied. 2.4 stands |
| `Just.let`, R7 | 2.4: `Just`, `.`, `let` | Accepted, against all four | None: not wrong, only unpopular. Marked for the owner |
| R21(b) | Signed contexts in a group "must be identical" | Refused, against all three | None: the same. Marked for the owner (D32) |
| R38 | A letter with no case is upper | `isUpper` of U+4E2D is `True`, against GHC and Hugs | None as it stands: the same. Marked for the owner |

**R38 may belong in the first group.** Chapter 19 treats "any alphabetic character which is not lower case" as upper, and 2.2's `uniLarge` is "any uppercase or titlecase Unicode letter", which leaves that letter out. If the owner reads the two as at odds, the ground is "contradictory", and GHC's table is the deviation to take (D21).

**Where the Report and every implementation part: `Just.let`.** **Marked for the owner.** 2.4 is plain. `qvarid` is `[modid .] varid`, `varid` excludes reserved words, and 2.2 says "at each point, the longest possible lexeme satisfying the lexeme production is read." So `Just.let` is `Just`, `.`, `let`, and `f = Just.let x = id in x` is a legal program: `Just` composed with a `let` (R7).
- *All four oracles refuse it* [run, E10 `qual-keyword`]. nhc98's `conformance98/identifiers/qual` records that failure. GHC documents a neighbouring deviation (`ghc/docs/users_guide/bugs.rst:38-41`) and skips its own test, `read023`, whose comment says "M.<keyword> isn't a qualified identifier", with a note that the test "is in fact incorrect Haskell 98 anyway" (`ghc/testsuite/tests/parser/should_compile/all.T:34-37`). That note gives no reason, and ticket #1215 was not read. Hugs lists `Just.if` under limited lookahead (`Hugs/docs/users_guide/haskell98.xml:38`).
- *jhc keeps GHC's test in its pass directory* (`jhc/regress/tests/0_parse/2_pass/ghc/read023.hs`). It was not run.
- *Cost of following the text:* none. E10's spike accepts it, on all three techniques. A grep run while writing this, over the 2,095 files of E10's positive list that can be opened, with comments and strings stripped by regular expression, finds the form in 3 files, and all 3 are tests of this point.
- *The recommendation is to follow the text, and accept.* 2.4 is neither wrong nor contradictory nor ambiguous here, so the deviation rule does not apply. `conformance98`'s expectation becomes a recorded disagreement, D52's plainest case of a result that cites a clause rather than an oracle.
- *The same rule refuses `[LT..]`:* by 2.4 `LT..` is the operator `.` of a module `LT`. All four refuse it; `[LT ..]` passes on all four [run]. 6.3.4's example is an error in the Report, recorded and not copied. Here the Report and the implementations agree, against one sentence of the Report.

**Recommendation.** B, with the one rule above, and the text on `Just.let`, R21(b) and R38. **The strongest argument against:** on `Just.let` rhc alone would accept it. A program using the form runs on nothing else, no program in the corpus wants it, the implementers who met the point refuse it and two of them say so in their documents, and nothing is gained for any user. Letting unanimity win remains the alternative: where every implementation agrees and no program is affected, follow them. That rule would be new, and it would reach R21(b) and R38 as well, so it should be taken as a rule and not for one token.

**What would reopen it.** The owner's call on that rule; a further erratum; a mode for Haskell 2010, which has its own text.

**Decided (owner, 2026-11-09).** B, as recommended: the December 2002 text plus the published errata, all listed, with the one rule for departures above; `Just.let`, R21(b) and R38 follow the text, as the recommendation has them.

**The fourth ground, decided (owner, 2026-11-13).** "Cannot be implemented" is struck. Its two departures stay deviations, filed under a ground of the text's own: **conceded by the Report**, where the Report itself says implementations will not meet the passage and advises programmers to avoid the construct. Both are fixity met during parsing: 9.3's `parse-error(t)` ("hard to implement in its full generality, because doing so involves fixities ... Programmers are therefore advised to avoid writing code that requires the parser to insert a closing brace in such situations"; `do a == b == c`, R1) and chapter 3's let/lambda meta-rule ("implementations may well use a post-parsing pass to deal with fixities, so they may well incorrectly deliver the former parse. Programmers are advised to avoid constructs ..."; `let x = True in x == x == True`, R9). rhc refuses both at fixity resolution, as GHC, Hugs, nhc98 and MicroHs do. The grounds are now wrong, contradictory, ambiguous, and conceded by the Report.

### D39. The pipeline as data

**Question.** The brief wants a pipeline in which "optimization passes can be swapped in and out cleanly". Today `Pipeline.lowOfMid` is a fixed run of calls (`driver/pipeline.sml:177-186`), `--passes` can only filter it (`util/pass.sml:91-94`), and `Pipeline` names the elaborator and `UnitBasis` as it loads (`driver/pipeline.sml:8-10`). Should the pass list be data, and how far should that go?

- **A. Large: every hidden pass a stage.** `inline`, `specialise` and `equality` taken out of Simplify's rounds. Not tried, and not sized. Moving them changes code: `inline-second` gives +6.0% size and -1.4% instructions, `inline-then-shrink` -0.2% size (E11, `variants.tsv`). That is a question about Rune's optimiser. rhc does not ask it, and the brief does: *What remains*, below.
- **B. Medium: passes with declared languages.** Each pass states what it needs and what it leaves, and the list is checked (Sarkar et al. 2004). Not prototyped, and sized only under *What remains*.
- **C. Small: E11-4, E11-6, E11-8.** **Recommended.** A pass is a record `{name, from, gate, run}`, and a client edits the list with `removePass`, `insertBefore`, `insertAfter` and `replacePass`. Simplify and Lower take their options as arguments. `driver/midpipeline.sml` holds everything from Mid down and names no front end; `Pipeline` adds `expand` and what else is SML's. A front end calls `MidPipeline.lowOfMid passes mid` with its own list.
- **D. None: leave it.** No file changes. rhc can call `lowOfMid` as it is, since its own passes run on Core. It then links `Pipeline` and so the whole of Rune's front end, and it cannot leave out `expand`, whose file names `Translate`, `Elaborate` and `ToMid` (E11, `deps.summary`). The brief's swapping is not met.

| Patch | Change | Files | + | - | Bytes | Grade |
|---|---|---:|---:|---:|---|---|
| E11-4 | Pass list as data | 1 | 50 | 16 | held | small |
| E11-6 | Simplify and Lower take their options; `parts` names what has no stage | 5 | 49 | 14 | held | small |
| E11-8 | `driver/midpipeline.sml`, a move | 3 | 187 | 167 | held | small |
| E11-7 | `backend/results.sml`: the analysis of `results` out of `Lower`, a move | 3 | 470 | 454 | held | small |
| E11-11 | Root names after E11-7 and E11-8 | 2 | 17 | 17 | held | fix |

E11-7 and E11-11 have no other decision, and land here. E11-11 is needed: the state audit passed once the moved roots were renamed (E11, A's report; not rerun). Sizes are `lib` and `src` only (`results/E11/sizes.tsv`, recounted from the patches). Bytes held means what E11 in *The experiments* says it means, on `results/E11/verify-summary.txt`, whose 12 lines all hold.

**The evidence.**
- *The whole of E11.* All eleven patches are 42 files, +1,073 -967 in `lib` and `src` (`sizes.tsv`), and 5 test files, +229 -13 (recounted from `patches/E11-all.patch`). The rows sum to +1,164 -1,058, since later patches rewrite lines of earlier ones; the net is +106 either way. The compiler's own compile falls 0.81% in instructions and 0.64% in bytes allocated (`compile-cost.txt`, measured at E11-10).
- *E11-10 is D7's,* and neither D39 nor D40 depends on it. It holds bytes (`verify-summary.txt`, line `10-try`) and it does not hold `rune-test run ir`: four expected dumps change, `tests/ir/handle.expected`, `letrec`, `match` and `types`, where `(try` becomes `(join` (`final.jobs`, `ir-try-diff.txt`). Those four are read and accepted by hand. Without it the tree holds bytes too (`11-no-try`), and 128 of 128 ir and fault jobs pass (`no-try.jobs`); `levels` was not rerun on that tree.
- *A swap is real.* A client took Mid text to bytecode through an edited list; removing `workers` and `refs` took its allocation from 304 bytes to 87,091,544 (`client/mo-none.rbc`, `mo-remove.rbc`, by `runevm --count`). Each optional pass left out alone gave a compiler that still compiled itself to the same bytes (E12, `passes.tsv`).
- *Precedent is narrower than this.* In GHC only Core to Core is a list, with lint between (`ghc/compiler/GHC/Core/Opt/Pipeline.hs:120`). The rest is hooks.

**Not run on any of this:** `make check`, a host build, `check-units`, `check-docs`, the compiler mutants. `docs/ir.md` and `tests/runner/compilermutantlist.sml`, which names code E11-7 moves out of `lower.sml`, go stale until M4 updates them.

**Recommendation.** C, with E11-7 and E11-11. **The strongest argument against:** A bare list of `Mid -> Mid` promises more than it gives. It has no input or output language, so what must run before what stays implicit [inference from Sarkar et al.]. Passes still read global state: `Pass.enabled`, `Target.intBits`, `Lower.knownBefore`. `Lower.shapesChecked`, `MatchComp.noteLocal` and `Overload.used` still wire at load. A client that reorders the list gets a compiler no test has seen. rhc itself needs only one edit, leaving out `expand`. The answer is that the brief asks for the swap, that `expand` cannot be left out at link time any other way, and that the cost is E11-4 and E11-6, +99 -30, beside two moves. The list is a seam, not a proof of independence, and `docs/ir.md` should say so.

**With it:** `--passes=nosuchpass`, a defect on master (`results/defects/passes-unknown-name/`), becomes a lookup in the list and `parts` [not prototyped]. That fix is M4's.

**What remains, as work for Rune.** The brief asks that "optimization passes can be swapped in and out cleanly", for Rune and not only for rhc. C gives a swap at the top level and stops there. No milestone holds what follows: these are next steps if the owner wants them, not decisions.
- *Passes keep global state.* `Pass.enabled`, `Lower.knownBefore` and `Target.intBits` are on 31 lines, and `Lower.shapesChecked`, `MatchComp.noteLocal` and `Overload.used`, which wire at load, on 10 more (grep over `lib/compiler` and `src`). A next step is a record of settings passed down the list in their place: about those 41 lines, with bytes held by E11's test [inferred].
- *The hidden passes.* `inline`, `specialise` and `equality` stay woven into Simplify (*Where we are*), left alone because rhc does not need them out. A next step is to take one out where it runs today and show bytes held: `equality`, a flag on Simplify from `-O2` (`core/simplify.sml:2014`), looks the smallest [inferred]. Moving one is a change to code, and `variants.tsv` is the price, above. Not sized.
- *Declared languages.* Option B: two fields on the pass record and a check of the list. With about ten optional passes that is about 50 lines [estimate]. It is what would make "correct and testable" more than a seam, and it is what a client's order breaking something a lint should have seen would ask for.

**What would reopen it.** A client's order breaking something a lint should have seen, which is the case for B; `make check` or a host refusing a patch; Rune wanting `inline` as a stage for reasons of its own.

**Decided (owner, 2026-11-10).** C, as recommended: "D39: change to C". E11-4 (the pass list as data), E11-6 (Simplify and Lower take their options) and E11-8 (`driver/midpipeline.sml`) land in M4, with E11-7 (`backend/results.sml`) and E11-11 (root names after E11-7 and E11-8), as the recommendation says. The owner's answer of 2026-11-09, "D (leave it)", is superseded by this one. *What remains* stays work for Rune that no milestone holds.

*Lead's note.* This answers the lead's objection of 2026-11-09, that D41's layer needs E11-8: it lands, so D41 is C without condition. rhc calls `MidPipeline.lowOfMid` with its own list, which leaves out `expand`, and links no front end through `Pipeline`. The `--passes` defect is fixed by the list, in M4 (*With it*, above). The patches were made on `b12141ecc`, and M4 redoes them on origin/master `697724da5`, where none of the five applies as it stands.

### D40. Front-end independence

**Question.** What ties Mid and everything below it to Rune's front end, and which ties does rhc need cut? Stamps come from `Elaborate.freshStamp` (`elab/elaborate.sml:9`, read by `core/lift.sml:27`, `core/workers.sml:29`, `core/simplify.sml:277`, `core/refs.sml:20`). Function names live in `Translate.funNames`, read by every pass that wants one (`core/simplify.sml:803`, `core/workers.sml:392`, `core/refs.sml:178`). `Workers` and `Lift` read the stack target's `maxArgs` whatever the target is (`core/workers.sml:212`, `core/lift.sml:244`). `Mid.Const` holds `Lambda.const` (`core/lambda.sml:10`).

| Patch | Change | Files | + | - | Bytes | Grade |
|---|---|---:|---:|---:|---|---|
| E11-1 | `Stamp`, `util/stamp.sml` | 16 | 30 | 20 | held | small |
| E11-2 | `Target` passed to Lift and Workers; `switch`, `barriers`, `safepoints` gone | 5 | 13 | 17 | held | small |
| E11-3 | Counters register where they live; `Env.inlinedValue` set in `UnitBasis.startSession` | 8 | 21 | 17 | held | small |
| E11-5 | `label` on `fundef` | 17 | 158 | 193 | held | medium |
| E11-9 | `Literal`, `Ty.constAt` | 22 | 147 | 137 | held | small |

Sources and bytes as in D39.

- **A. Medium: `Ty` split from `Types`.** `Ty` proper, and `TyOfTypes` holding `convert`, `binders`, `exnArgs` and `realizations`, with 108 lines in 14 files to follow (`results/E11/contract.md`, by grep). It gives rhc nothing the small move below does not, and for tidiness alone it does not pay. Rejected.
- **B. Medium: E11-5.** **Recommended.** `fundef` gains `label : string option` (`core/mid.sml:73` today has none). It changes a record every pass of Mid rebuilds, which is why it is 17 files, and it removes more lines than it adds. `Translate.funNames` then lives only from Translate to ToMid (`patches/E11-5-label.patch`).
- **C. Small: E11-1, E11-2, E11-3, E11-9.** **Recommended.** Later, and small: the built-in tycons and `freshTycon` out of `elab/types.sml` into a file below `Ty`, about 40 lines [inferred], when rhc's first type name needs it. Until then a client links that one 440-line file of `elab/`, which depends on `Source`, `Error` and `Pass` alone (`results/E11/contract.md`).
- **D. None.** rhc calls `Elaborate.freshStamp`, writes `Translate.funNames` and builds `Lambda.CInt`, and links all 76 files to do it. It works: E1 ran Mid programs on master with one small driver change (`patches/E1-readmid.patch`). But a front end then keeps its names in another front end's table, and "no front end" cannot be a build fact (D41).

**The evidence.** The five patches above held bytes one by one. With all patches applied, a client lists 48 files of `lib/compiler` and no lexer, parser, elaborator, Translate, ToMid or Expand, at `RUNE_LINT=3`, and writes the same bytes as a client on the whole of `internal.build` (`results/E11/contract.md`; `cmp` of `client/none.rbc` and `mo-none.rbc`, rerun). What the Mid layer still names of the front end: `Types` 47 times, and `Translate`, `Elaborate`, `ToMid` 8 times, all in `core/expand.sml`, which a client leaves out (`deps.summary`).

**Known limits.** `Target.intBits` stays a global. E11 leaves MidText with no label, so a function read from text is `fn`; M5 lands the label in Mid's text, which changes dumps (*Every change to Rune*). A label beginning `functor ` still means something to Simplify and Expand (`core/simplify.sml:1982-1985`, `core/expand.sml:190-195`): it is semantic, not cosmetic, and `contract.md` should say so.

**Recommendation.** B and C. **The strongest argument against:** This is 42 files of churn in `lib/compiler`, for a client that does not exist yet, and `none` is known to work. Rune's own gain is 0.81% of its compile and a few honest names. Holding bytes shows the code is the same; it does not show a host still builds, and only M4's `make check` will. The answer is that D41's fact depends on these patches, and that they remove what Rune pays for too: a global table of names keyed by first parameter, three unread `Target` fields, a stack-only `maxArgs`, a hook in `Pipeline` for every counter. E11-5 and E11-9 are the two whose order matters: D46.

**What would reopen it.** M4's host builds or `make check` refusing a patch; a front-end tie these patches do not cut, as `Target.intBits` is left uncut today, turning out to matter.

**Decided (owner, 2026-11-09).** B and C, as recommended: E11-1, E11-2, E11-3, E11-5 and E11-9, and the built-in tycons out of `Types` when rhc's first type name needs them.

*Note.* The patches were made on `b12141ecc`. On origin/master `697724da5` E11-2 applies and the others do not (Y, `git apply --check`, and again while recording this), so M4 rewrites them there. Mid's codecs are generated now, so E11-5's `label` on `fundef` is described in `tools/codecs/compiler.sml` (`fundef` at `:234-237`) and `make codecs` run, in place of E11-5's hand edits of `midcodec.sml` and `unitmid.sml`; `make check-codecs` refuses stale output.

### D41. What `lib/compiler` exports

**Question.** `lib/compiler/library.build` exposes `RuneCompiler` and nothing else, and reaches Mid only as bytes. `lib/compiler/internal.build` exposes every structure of its files, and drivers use it (`rune.build:24`). Which should rhc use, and what makes "no front end" a fact?

- **A. Large: widen `RUNE_COMPILER`** to export Mid, Ty, Low and the passes. A public API over IRs that change. `RUNE_COMPILER` hides `Mid`, so a client cannot write a pass, and that is right for an interface to Standard ML (`results/E11/contract.md`). Rejected.
- **B. Medium: a real library,** with a `library.build` and an export list, or a named view of `lib/compiler` under v2's D8. Not possible today: v2's M8 brings views.
- **C. Small: `lib/compiler/mid.build`.** **Recommended.** A third layer, `use`d by `src/rhc` and by `internal.build`, that lists what a front end of another language links: Mid, Low, `Ty`, the passes, Lower, the targets, Emit, `MidPipeline`. The list exists as a test, `tests/compiler/mid-only.build` in `patches/E11-all.patch`: 74 lines, 48 files of `lib/compiler` and 19 of `lib/unicode` and `lib/json`. As a layer it adds `backend/link.sml`, `backend/unitfile.sml` and, after D43, the store, which that test never needed [inferred]. `internal.build` and `frontend.build` must be reordered so the layer comes first; that was not prototyped, and bytes must be shown to hold.
- **D. None.** `src/rhc` uses `internal.build`, as `rune` does. No lines. The test list stays beside the build, a second list to keep, and a name of the elaborator in rhc's code compiles.

**The evidence.** E11: `mid-only.build` builds, and its client gives the same bytes. Its 48 files are of the 80 that `util.build`, `frontend.build` and `internal.build` list after the patches; master's 76 is before them, and four of the 48 are new files (`util/stamp.sml`, `util/literal.sml`, `backend/results.sml`, `driver/midpipeline.sml`; counted from the prototype's build files). `core/lambda.sml` stays in the list for `Fault` alone (`backend/fault.sml:61`, `:67`; grep of the 48). So "no front end" means no lexer, parser, elaborator, Translate, ToMid or Expand, and not no Lambda.

**Recommendation.** C. **The strongest argument against:** v2 is about to say how a program reaches into a library. Under its D10 a `use` of `lib/compiler/mid.build` is reaching in: a warning from v2's M1, an error after its M14. Under its D11 the five drivers become friends. A third hand-kept build list goes the wrong way, and v2's named view is the proper form of the same thing, since a view's files are "the `requires` closure of those exports". The answer is order. rhc cannot wait for v2's M8 (D46), so the layer lands as a `use`, and it becomes a view or a friend entry when v2's M8 and M14 land. rhc is then a sixth driver on v2's list. That asks nothing new of v2's D10 or D11, which is why they are not among D46's six.

**What would reopen it.** The reordering moving bytes; a pass of the layer coming to need the elaborator; v2's D8 decided without views, when the layer stays a build list.

**Decided (owner, 2026-11-09; settled 2026-11-10).** The owner asked the lead to decide after reviewing what build-system-v2 changed: "please review what build-system-v2 has changed and you decide based on that". The lead's decision: C, `lib/compiler/mid.build`, with rhc's root build, `rhc.build` (M8), a friend of `lib/compiler` and rhc linking its own `Config` (`scripts/gen-version.sh --config PLAN FILE`). On 2026-11-09 it was C if E11-8 landed and D otherwise; the owner's change of D39 to C on 2026-11-10 lands E11-8, so it is C without condition.

*Lead's note.* At origin/master `697724da5` reaching into a library with a header is an error unless the reaching build is a friend (v2's M14), and one line in `friends` of `lib/compiler/library.build` lets the `use` through, so C's worry above is gone. A named view, B under v2's D8, must be a subset of the exports, so it would make `lib/compiler` export Mid, Low, `Ty` and the passes to every client, which is A, and through `libraries` it gives rhc Rune's identity, the hole v2's M11 found. v2's own text says the layer "becomes a named view of lib/compiler (D8), not a friend" (`build-system-v2.md:5791`); its M11 contradicts that, and the line should say a friend. The layer needs the Mid half of `pipeline.sml` moved out, which is E11-8, and D39's C lands it in M4 beside the layer. Lands in M4.

### D42. Which hosts build rhc

**Question.** Rune is built by six hosts and five roots are host-built (`Makefile:602`; v2's D14). The brief says rhc is "implemented in sml97 / rune". Must it build on the others?

- **A. Large: all six.** rhc as a sixth host-built root: three mains in `src/main`, as `runedoc-mlton-main.sml`, `-polyml-` and `-mlkit-`, about 55 lines of Makefile as `runedoc-host-builds` takes (`Makefile:738-792`), and a committed plan under v2's D14 at 8.6 KB. `make check-cross` would cover it.
- **B. Medium: Rune and MLton.** A native `bin/rhc-mlton` for a fast loop, as `make test RUNE=bin/rune-mlton` is for Rune (`Makefile:66`). One main, one rule. Not sized further.
- **C. None: Rune alone required.** **Recommended.** Other hosts are informational, by the owner's rule of 2026-10-21 (*Constraints*). rhc joins `runelsp` and the REPL, which have no host mains (`src/main/runelsp-main.sml`, `src/main/repl-main.sml`).

**A cost this leaves.** `lib/language/haskell` is a library, and the rule for libraries runs a library's tests on the hosts (`AGENTS.md:392-403`); `lib/language/c` is on that list (`tests/runner/hostchecks.sml:90-95`). So the recommendation needs a sentence of exception in `AGENTS.md`, or a `LibHosts` entry whose failures are recorded as `HOST-BUG`. D41's layer is unaffected: `rune` links it, so it is host-built whatever is decided here.

**The evidence.** None by experiment: no host build ran in E11 or E13, and rhc does not exist. Nothing in the literature bears on it (*What the literature says*).

**Recommendation.** C. **The strongest argument against:** rhc's speed is unknown, and a native build is the cheapest answer if it is slow: `make check` may run up to 3,781 clause programs (D45), and E10's parser alone costs about 560 VM instructions per token. And other SML compilers are a free differential test of Rune itself on 12-20k lines of new SML [E10's estimate, through Core]: a host that disagrees has found a bug in one of them. The answer is that the first is met better by D45's snapshot, that a native build can be added any day because the sources are Standard ML, and that the second is a benefit to Rune which can be had informationally.

**What would reopen it.** rhc's measured compile time keeping `make check` out of budget after M21; a host finding a Rune miscompile in rhc's sources.

**Decided (owner, 2026-11-09).** C, as recommended: Rune alone is required, other hosts informational, with the exception to the library rule written down.

### D43. The store

**Question.** The brief: "can we re-use the rune separate compilation build cache for this? and without changes or with only changes that are a clear improvement for rune as well? or are bigger changes needed? and should we do a separate incremental compilation system for rhc in that case?" `UnitCache` is 437 lines, welded to `UnitBasis`, `UnitMid`, `Pipeline`, `Elaborate` and `RegVerify` by name (`driver/unitcache.sml:124-141`, and *Where we are*).

- **A. Large: one interface for both languages.** `UnitBasis`, 2,930 lines, made language-neutral. `Types.ty` holds no class context and no variable-headed application (`elab/types.sml:8-12`), so a Haskell type does not fit a basis. Not built or sized, and it would stand where v2's M4 and M5 are at work. Nothing needs it: E13's toy calls no `UnitBasis`.
- **B. Small alone, medium with v2's M6 and M7: generalise.** **Recommended.** `unitcache.sml` is split into `driver/unitstore.sml`, which knows nothing of a unit, and what is left. +338 -231 in 3 files (`results/E13/split/tier.out`): `unitcache.sml` +73 -231, down to 279 lines; `unitstore.sml` 264; `internal.build` +1. Sections are a type variable (`'a format`), so the store cannot look. `Link`, `UnitFile` and `Usage` stay unchanged. E13 counts seven welds, and none is hard.
- **C. None: as is.** No lines. rhc calls `UnitCache` with empty usages and a key that folds whole interfaces and the instance closure. Warm equals cold, and it compiled 40 units against 29 over 26 edits (`toy/p9-sum.out`). There is no per-entity cut-off, and a configuration holds Rune's settings. A stopgap at most.
- **D. None: wholly apart.** No lines of Rune; about 1,560 of rhc's: the store's 264, plus v2's M7 and M2 again, about 600 and 700 [inferred]. It misses frozen layers, dist, v2's M6 and later cache fixes. Its one gain, independence from v2, the split gives anyway.

Under all of these rhc's interface, usages and driver are its own (D44).

**The evidence, E13,** in `results/E13/split/`, observed:
- *Rune unchanged.* Fixed point; hs-base's sources give `bin/rune.rbc` and five variants byte for byte (`verify.out`).
- `rune.build` in units: 494 unit files and 493 cache files, 0 differ; each compiler compiles 0 of 246 on the other's store (`units2.out`).
- 371 programs on both targets: 0 differ, 1,760 cache files the same (`programs.out`).
- `units-one` 371 of 371 (`tier-units.jobs`, `tier-units2.jobs`). `tests/units` 32 of 32; its other 8 jobs were scheduled by mistake for fixtures expected to refuse (`tier.out`). Incremental scenarios: 0 FAIL, with the REPL not rebuilt (`tier-incremental.out`). Loader jobs were not run.
- *It serves a second language.* The toy took Mid text to bytecode through the store, linked and ran it, and held body edits, type edits, instances and a cycle (`toy/p1.out` to `p4.out`; E13 in *The experiments*). One unit per SCC costs the store, `Link` and `UnitFile` nothing.

**"A clear improvement for Rune" overstates it alone.** It is net +107 lines, and a warm no-op on `rune.build` is flat: 1,063,193,748 to 1,063,190,918 instructions (`units2.out`). Rune gains nothing measurable from the split by itself. **It pays with v2's M6 and M7:** 130 of the 138 `unitcache.sml` additions in v2's warm-path prototype name no `UnitBasis` (`v2/patches.out`), so they go to a file that tests with no compiler (`split/storetest/`), and v2's M7 has one file to change. If neither lands, Rune has paid 107 lines for rhc.

**Recommendation.** B. **The strongest argument against:** Do not move 231 lines out from under v2's M3, M4, M6 and M7 in the same file, for no gain to Rune today; let rhc start on `as is`, and generalise when v2's M7 redesigns the store anyway. The toy says `as is` is sound. The answer: `as is` gives no per-entity cut-off, so rhc's usage work would be written against a configuration that holds Rune's settings and then moved. And the split needs nothing from v2's M3: v2's prototypes all carry the same `unitcache.sml` hunks (`v2/patches.out`), so what is moved is known.

**What would reopen it.** A hold at scale, unmeasured, or rhc's real interface size changing the store's shape; the owner deciding v2's D24 against a split entry; `make check` or a host refusing the patch, since neither has run on it.

**Decided (owner, 2026-11-09).** The owner asked the lead to decide after reviewing build-system-v2. The lead's decision: B, as landed. v2's M6 and M7 built `lib/compiler/driver/unitstore.sml` from E13's prototype: an `('h, 's) format`, sections hashed apart, a client's head judged by `holds`, settings passed in, keys of several parts, eviction by age and size (Y; 746 lines at origin/master `697724da5`). rhc writes its own format, head, `holds`, key and settings. No change to Rune is needed.

*Lead's note.* Moving the store's location and trim policy out of `unitcache.sml` (`:223-275`, `:565-583` at origin/master), about 60 lines, is optional, and is what remains of M20. `unitstore.sml` sits in `frontend.build`, so under D41's C it moves into the Mid layer (Y). If rhc shares `.rune`, its entries and Rune's share one budget for trimming [Y's inference]. C would now mean Rune's settings and Rune's head; A and D lose for their old reasons.

### D44. HsIface

**Question.** What does a unit's interface hold, how is it hashed, and how much of it must exist from the start? Under all options this is rhc's own code in `lib/language/haskell`: **none** for Rune. M21 estimates about 1,500 lines for it and rhc's driver; the toy's driver, interface and usages together are 766 (`patches/E13-2-toy.patch`), with no real type in them.

- **A. One hash per interface.** The key folds whole interfaces and the instance closure.
- **B. By entity, no unfoldings.**
- **C. By entity, with the Prelude's unfoldings from the start and a program's own later.** **Recommended.** The section exists in the format from M21, and the Prelude's are written when M23 has something to put there.
- **D. By entity, with every unfolding from the start.** A compile then reads bodies across every edge, so a body edit stops being cut off wherever a body is used [inference].

**Contents,** by entity, from the literature and E13:
- names, with origin, and each export relation, so `module M` reads all M's exports (H7);
- types with kinds, synonym expansions, constructors with schemes and fields;
- classes with kinds, superclass order and default-dictionary names;
- all instances, with contexts (H5): "the instance environment is unaffected by the filtering" (Faxén);
- fixities (H6), in the entity's fingerprint;
- ABI facts: dictionary parameter order, stated once and canonical; arity; constructor tags (H9, unmodelled);
- later, a strictness signature (D50), with a wrapper's unfolding.

A fingerprint is per recursive group, and it is compared, not assumed: Rule 2 and whole-unit generalisation mean a change to a body can change an export (*What the literature says*, D43). What a hit must read is H1-H9, in *The architecture*.

**The evidence.**
- *E6, on GHC:* median instructions are 1.04 of `-O2` with a program's own pragmas omitted, 2.00 with every pragma ignored, libraries' too; allocation 1.02 and 1.72 (`results/E6/e6.summary.txt`, 75 programs). So the Prelude's matter and a program's own can wait.
- *How far that carries.* It is GHC's optimiser. It says nothing until rhc has one, the omit flag also drops arity and strictness, and the medians hide a tail: 19 of 75 exceed 1.10, 4 exceed 1.50, and the total is 1.44 times, from `real/fulsom` at 33.19 and `real/bspt` at 14.24, unexplained.
- *E13's toy:* a body edit compiles one unit; a type edit used by one client, 2 of 5 (`toy/p1.out`); a new instance two imports away, on no list, compiles Orphan and Main, and with the absent read dropped warm prints 7 and cold `mine` (`toy/p2.out`). GHC moves too: 5, then `MyNum!` (`results/E13/ghc/m/run.out`).
- *E13's model:* every single-module edit of its projects, 15,750, of which 8,652 are refused cold (`model/output.txt`). Reading per name gives 0 wrong, 19,960 rebuilt.

**Recommendation.** C. **The strongest argument against:** The same model gives one hash of all imports 0 wrong and 23,128 rebuilt: 16% more rebuilds, and most of H1-H9 gone, since a hash of everything cannot forget a read. It must still cover the closure's instances and every member of an SCC. It is what rhc would have on `as is` (D43). By entity is the larger design, and on a bounded model of small projects it buys 16%. The recommendation stands because one hash makes a single new export rebuild every client, and because the brief asks for incremental compilation of real programs. It is the closest call among D43 to D46: M21 should measure it on E8's 38 and 73 multi-module programs before the usage machinery grows.

**What would reopen it.** That measurement showing by entity saving little on real programs; M23 showing a program's own unfoldings matter on Rune as `real/fulsom`'s do on GHC; a hold at scale proving too dear.

**Decided (owner, 2026-11-09).** C, as recommended: by entity, with the Prelude's unfoldings from the start and a program's own later.

### D45. The Prelude snapshot

**Question.** A whole-program compile carries the Report's 11-module unit, 14,965 tokens per program, of which the Prelude's four modules are 6,908 (E16's text through E10's spike, rerun by V2 and for this section; no file holds the counts), and the conformance suite is up to 3,781 clause programs (E9: 3,901 rows less the 120 whose `test` is `none`). At E10's 560 VM instructions per token that is 8.4M instructions to parse each time [deduced]; the checker and Core passes are unmeasured. What does rhc do about it, and when?

- **A. Small: a frozen unit through the store.** **Recommended,** with D43, which is its whole cost to Rune: `.rune` and `lib/cache` already have one format, and a frozen cache is read second and never written (`driver/unitcache.sml:196-208`). `share/rhc/haskell98` compiled once, at install, into read-only entries. Under D36 that holds the 11-module SCC, as one unit, so its key must cover every member: for a frozen unit, a hash of its files at install [inferred], with M22 doing the rest for cycles a user edits.
- **B. None: a saved world.** The library's session saved as an image. It needs no interface codec. It runs only on the VM, and it is a stopgap: **recommended until M21 lands.**
- **C. None: whole-program always.** Whole-program is the one-unit case, a flag in the toy, and it stays as the fallback and as the reference for `unitsOne`.

**The evidence, E13: toy ratios and not rhc's, since the toy has no front end.** With one module edited, in machine instructions (`toy/p8.out`):

| | Native | Note |
|---|---:|---|
| Nothing kept | 1,142M | |
| Whole-program on the store | 634M | |
| Whole-program on the saved world | 583M | image 5,560,282 bytes, frozen store 185,590 |
| Units on the store | 458M | |

A frozen unit of the Report's 11 modules and toy bodies: 20 modules, 10 entries. Hello compiles 1 module, 19.26M VM instructions against 56.39M from source, with the bytes equal and the layer unwritten (`toy/p5.out`). A body edit recompiles no client, a type edit only its user, and importing a hidden member is refused. An instance in a hidden member moves a client's default, which is right by 5.4.

**The order.** M19 runs on a frozen Prelude, option B's saved world until M21. M20 and M21 run beside it and do not gate it. The argument for landing them first asked for a frozen Prelude, not for those milestones, and the saved world is one with no change to Rune, at 583M on the toy against 634M for the store. The objection that decided it: M21 would fix HsIface before conformance has shaken out classes and instances.

A rough rate [V2's estimate]: the compiler's own compile is 2.158G VM instructions over 379,395 tokens (E12, with V2's token count), about 5,700 a token, so about 85M for the 11-module unit. If rhc matched that, 3,781 programs would take tens of minutes to an hour of CPU. That is a budget matter for `make check`, not a limit on running M19 on 16 CPUs. 1,927 of the rows stop before code generation, and a program may cover several ids.

**Recommendation.** A, with B until M21 lands. **The strongest argument against:** A snapshot is a second path. Every program then runs on the frozen Prelude, while whole-program stays the reference, so the two must be held equal (`unitsOne`, *Testing and conformance*), and a snapshot taken before track P, or without unfoldings, understates every later result [inference, Peyton Jones, Marlow 2002]. The link size and start-up of a frozen unit are not established: hello reaches 19 definitions of 525 (E16), and a unit links whole, since Shake runs only on a whole program (`driver/pipeline.sml:166`). If rhc's compile turns out cheap, whole-program with Shake might do. The answer is the arithmetic above: at 3,781 programs a small per-compile cost is a real share of `make check`, and the saved world shows the path works before the store is needed.

**What would reopen it.** M21 finding start-up of the frozen unit worse than a whole compile; rhc's measured compile making whole-program affordable; D36's literal layout needing a unit the store cannot freeze.

**Decided (owner, 2026-11-09).** A, with B until M21 lands, as recommended: a frozen unit through the store, and the saved world until then.

### D46. Order with build-system-v2

**Question.** The brief: "please review docs/plans/build-system/build-system-v2.md on the build-system-v2 worktree ... to see if any of this work should be done before this roadmap. this will decide the order in which which we do the roadmaps."

**The answer: no work of v2's needs to come first. rhc waits on no milestone of v2. The two roadmaps may run side by side.** What rhc asks of v2 is not milestones but six decisions taken with a second language in view: v2's D5, D6, D8, D14, D24 and D25. v2's status is "Written, and undecided", so they still can be. Refused, none of the six stops rhc.

- **A. v2 first, then rhc.** No conflict in the files. rhc's track S would stand still behind v2's M1 to M7, sized M, M, L, L, L, L and M, for a store it can already use. Nothing in E13 asks for it, and it is the answer only to the serial question below.
- **B. rhc first, then v2.** v2's M1 alone closes real holes in the cache, and none of it waits on rhc. No reason.
- **C. Side by side.** **Recommended.** Changes to Rune: none beyond what each roadmap already decides, plus a clause in each of six decisions of v2.

**For an owner who runs one at a time: v2 first.** It is the smaller, it fixes real cache holes, and rhc's track S then sits on a finished store rather than a moving one. There is no technical dependence either way, so this is an order of convenience.

**What rhc asks of build-system-v2.** None of the six needs a different option from the one v2 recommends. All of it was run on E13's toy (`results/E13/toy/p7.out`, except where stated).

| v2's | Its milestone | What the toy showed | What rhc asks |
|---|---|---|---|
| D5, the form of the build language | M9 | Four written orders of one project, by scan, reverse scan, and a build file against the order and with it, gave the same 2,026-byte program and the same 3 cache files | The plan is Rune's. Nothing in the store reads it. rhc scans imports |
| D6, the one way | M9 | `Deps` refuses a cycle (`driver/deps.sml:270`), so rhc bypasses it | "Written order stays the semantics" is a rule of SML: written order is per language. A Haskell module's place comes from its imports |
| D8, what a boundary is | M8 | `module M` and `instance` exports are refused (`driver/buildfile.sml:115-116`); an instance in a hidden member moved a client's default (`toy/p5.out`) | Kinds of export are the language's, if a `.build` ever names a Haskell library. A boundary cannot hide instances: 5.4, "Instance declarations cannot be explicitly named on import or export lists." |
| D14, the compiler's identity | M11 | With a tool edited and `Config.identity` the same, the old tool compiles 4 and prints `MINE`; the new tool on the old store compiles 0 and prints `MINE`; cold, it prints 7. With the hash of the tool's own sources a setting, warm equals cold | Identity per root, over that root's closure, for a root that is not host-built as well (D42). `scripts/gen-version.sh:51` hashes `rune.build`'s list alone |
| D24, one store | M7 | Two configurations in one store, each warm, the same bytes; eviction and a damaged entry are misses. Entries split in two: 9.12M to 7.89M VM instructions with 17 entries under one key (E13-3, +66 lines in `unitstore.sml`) | The head is defined by the client: Rune's level and rhc's export digest go there, and the store still cannot look |
| D25, the warm path | M6 | The stat memo worked as a side file of the store | "No basis on a hit" means, for rhc, that a hit reads imports' exports and the closure's instances, so it needs v2's D24's head [inferred]. Memos go in `lib/compiler/driver`: 276 of 321 `main.sml` additions in v2's warm-path prototype name no compiler state (`v2/patches.out`) |

**The order in which to take the six:**
1. **v2's D14, its identity half.** First: it is the only one of the six where a wrong answer is a silent wrong program, and v2 already puts it before any root moves. Its other half, how hosts get their lists, can follow v2's D5, as v2 has it. Until v2's M11, rhc's own source hash as a setting closes the hole for rhc, as the toy showed (X3).
2. **v2's D24.** Before M20 if it can be, and before v2's M7 at the latest. It is the only one of the six that fixes a format.
3. **v2's D25.** After v2's D24, because what a hit may skip is read from the head. Before v2's M6, which v2 says can go early.
4. **v2's D8.** Before v2's M8.
5. **v2's D5, then its D6.** Before v2's M9: the second's rule is a rule about the first's plan.

The last three cost a sentence each, and change no byte of Rune. Refused, none of the six stops rhc: it can keep its own source hash as a setting, read whole entries, keep its memos in `src/rhc`, and stay out of `.build`.

**v2's generated codecs against HsIface's hand codec.** v2's M5 generates each codec from one description with field marks (v2's D21), because four hand-kept traversals diverged. HsIface's codec is rhc's own and hand-written in M21 (D44), so it has the same exposure at a smaller size. rhc should not wait for M5. If M5 has landed by M21, and its generator can take a description that is not SML's [inferred; v2 does not say], HsIface should be one, and otherwise it stays by hand with a round-trip test.

**The order of the work:**
- **Track A's M4 to M7 may start at once,** and so may v2's M1 and M2. No order is forced, and what they share is small: `driver/unitbasis.sml` +11 -9, `elab/elaborate.sml` 3 lines, `backend/link.sml` 1, `backend/unitfile.sml` 8, `api/` 2 (`patches/E11-all.patch`). No Touches list of v2's M1 to M7 names `pipeline.sml`, and E11 changes nothing in `src/driver/main.sml`. E1's `readMid`, which this roadmap's M5 needs, is +14 -2 there (`patches/E1-readmid.patch`).
- **The `fundef` label and `Literal` are cheaper before v2's M5.** E11-5 and E11-9 touch `core/midcodec.sml` (+36 -25) and `driver/unitmid.sml` (+23 -19), which v2's M4 edits and M5 replaces with generated code. If they land first, v2's description has them from its first line; if they land after, each is a change to a description and a regeneration [inferred]. That is a saving, not a dependency.
- **M20 waits on no milestone of v2,** and needs nothing from v2's M3. Before v2's M6 and M7 it saves them work: 130 of 138 additions go to the store (D43). After them it moves more lines. The store's layout stays in v2's M7.
- **v2's M14** adds a friend entry or view for rhc (D41).

**Recommendation.** C. **The strongest argument against:** Two roadmaps in one file at once. v2's M3, M4, M6 and M7 all touch `unitcache.sml`, and M20 moves 231 lines out of it. v2's prototypes were built on the unsplit file. In sequence nobody rebases, and v2's M7 might build the store rhc wants anyway. The answer is that v2's M7 comes after its M3 and M4, both large, so track S would stand still behind them for a store it can use today; and that the conflict is of known shape, since the prototypes' hunks are identical and 130 of 138 name no `UnitBasis`. A rebase is a known cost. A stall is not.

**What would reopen it.** v2 going further in its M3 than its table: names rather than numbers in imports change `Link.key`, `remapKeys` and `.rbu`, and rhc's link numbers, hashed by name, have collisions unchecked (E13); a v2 milestone making `Link`, `UnitFile` or `Usage` carry SML, which today they do not; the owner deciding any of the six the other way, which costs rhc what is said above.

**Decided (owner, 2026-11-09).** Not applicable: "build-system-v2 is done". It landed in origin/master `697724da5`, and implementation starts there. Its D5, D6, D8, D14, D24 and D25 were taken with a second language in view (Y); *What build-system-v2 gave rhc* says what rhc takes from it. The section above is the record of what was asked.

### D47. Where the optimiser lives

**Question.** Rune has an optimiser, on Mid. Haskell needs transformations that move lazy bindings. Do they go in Core, in Mid, or in both?

- **A. Large: one optimiser, in Mid.** Core is a desugaring and no more. Mid learns laziness: that `thunk_fmake` and `thunk_fforce` are what they are, that a Haskell `App` is pure, how to move a suspended body. It changes what `Let` means to the passes that rely on it (W2). Not built, not sized.
- **B. Medium: a Core optimiser, with force facts in Mid.** Simplify learns three facts: force of a delay, a dominated force, a thunk around a value (Strict Core §5.4-5.5). Shared with lazy ML. It needs Mid to know `susp` only as a force fact [inference]. Not built.
- **C. None: in Core; Mid unchanged.** **Recommended.** rhc's passes, in `lib/language/haskell`, over Core, through `Pass.stage`. Mid and everything below is as D3 leaves it. About 2,000 lines to M23, 800 to M24, both estimates; for scale, Rune's `core/simplify.sml` is 2,090.

**Recommendation.** C. **The strongest argument against, in full:** one optimiser in Mid, which lazy ML shares.

1. **Lazy ML gets nothing from Core.** It needs no Core (D2). The brief's reason for doing rhc now is that "doing haskell first ensures the whole stack supports lazy evalaution properly". Every line of a Core optimiser is a line lazy ML never runs. A rule in Simplify runs for both.
2. **Mid already is an optimiser, and a strong one.** Left out alone, on the compiler: `simplify` +63.4% instructions, `workers` +24.7%, `inline` +14.6%, `lift` +13.6%, `specialise` +5.4% (E12, `passes.tsv`). A Core optimiser writes a second simplifier, inliner and specialiser, in another IR, each with a lint, `--fuel`, `tests/ir`-style tests, mutants and budgets. The objection that it duplicates an optimiser is simply true.
3. **Mid is where laziness is explicit.** A value of `susp T` and a value of `T` differ by type there (D3), which is the very split L2 and Strict Core ask for. A strictness result, in those terms, rewrites a parameter from `susp T` to `T`, and `Workers` already rewrites parameters and their calls. A dictionary lowers to a tuple of closures; Simplify already folds known constructors (`core/simplify.sml:470`), and `specialise` already copies a function for the known functions it is given (`docs/ir.md:878-884`). The largest rung of E3 might be most of the way there with no new pass at all.
4. **Separate compilation is free there.** Mid already crosses units, in `inl` and `inlv`, through `MidCodec`, under v2's layers and codecs. Core bodies in HsIface (D44) need a second codec, a second usage discipline and a second place for a hole like H9.
5. **What costs on Rune is visible only below Core.** A one-argument `CALL`, `n-1` closures on an unknown call, `K_IND`, tier 2's trust. GHC's cost model is GHC's. An optimiser above Mid is blind to what Rune's engines charge.
6. **There is a precedent.** GRIN is a strict first-order IR with explicit thunks and whole-program analysis, and it reached 3.6 times ghc 4.01, with the largest and smallest factors removed (Boquist 1999). Peyton Jones et al. 1998 wanted one optimiser for ML and Haskell.
7. **It keeps Core small.** rhc wants the translation to Mid small (D4), and `-O0` a literal translation, its nearest reference (*Testing and conformance*). An optimiser in Core is the largest thing that can grow there.

**Why it does not win.**
- **What pays most moves lazy bindings, and `Let` in Mid is strict.** Let from let 32%, let from application 9%, let from case 5%, case of case 8% of transformations (Peyton Jones, Santos 1998, Fig 3). In Mid a lazy binding is a closure and a primitive (`patches/E2-all-forms.patch`), and to float one, inline into one or merge two, Mid would need a law for each, about what it treats today as an opaque primitive. "If we have just one form of let we lose valuable optimising transformations" (Peyton Jones et al. 1998, §4.3).
- **Purity is invisible to Mid, and rightly.** `App` is not removable (`core/simplify.sml:112`), because SML's calls have effects. Mid's passes are sound because of that. If `App` could be dropped or moved for Haskell, Mid would hold two semantics, chosen per call, in the passes Rune's own speed depends on. That is W2's danger: wrong in ways no lint sees.
- **Lazy ML could not use most of it.** Strictness, floating and eta on Core are Haskell's: speculation is "only safe because Haskell is a pure language" (Ennals, Peyton Jones 2003), and SML bodies have effects (D57). What the two languages can share is B's force facts, and those are small. Argument 1 is an argument for those, not for moving the optimiser.
- **The duplication is the price either way.** Teaching Mid does not remove a second simplifier; it puts its rules in the first.
- **Arguments 4 and 5 are costs, and small ones at first.** D44 starts with the Prelude's unfoldings alone. Mid's passes still run below Core and still see what Rune charges; Core's passes decide what is lazy, which is what Mid cannot.
- **GRIN does not settle it for rhc.** Single file, overloading removed by hand, a full back end, 16 programs of up to 716 lines, and "a basic assumption of the GRIN back-end is that the entire program is available at compile time". Under separate compilation a force stays an open dispatch [inference]. Its author says the effect of the evaluation model was never isolated.
- **Argument 3 is the one with teeth.** If Mid's passes on lowered dictionaries reached most of E3's first rung by themselves, a first Core pass would be smaller than this decision assumes. E5 priced that on its programs, and they do not: D49.

**The evidence.** The literature (*What the literature says*, D47), not an experiment: nothing here built either side. E12 measures Mid's passes on strict code. E3 sizes GHC's Core passes (D48).

**What would reopen it.** Real programs showing Mid alone recovering most of a known-dictionary rung, which E5's do not; M23 showing a Core simplifier out of proportion to what it gains on Rune; lazy ML's programs needing more than force facts (D57). B can be taken at any time, by itself, as M25's measurements justify.

**Decided (owner, 2026-11-09).** C, as recommended: rhc's optimiser in Core; Mid unchanged by it.

### D48. A Core simplifier, with eta

**Question.** Every strictness and floating figure in the literature was taken with a simplifier running after the pass, in the same IR: "the simplifier is part of every transformation, so it cannot sensibly be measured in isolation" (Peyton Jones, Santos 1998, §10.3). Does rhc's Core have one, and on what terms does it eta-expand? Changes to Rune under every option: **none**.

- **A. No Core simplifier.** rhc lowers what desugaring gives, and Mid's passes do what they can. This is `-O0` for good.
- **B. A simplifier, no eta.**
- **C. A simplifier, with eta under a pedantic rule.** **Recommended.** Eta only where the head is already a value, or GHC's `-fpedantic-bottoms` reading (`ghc/compiler/GHC/Core/Opt/Arity.hs:467`, Note [Dealing with bottom]). Core Lint from the first version (D2). A list of GHC's rewrites it refuses: foldr/build, which is unsound under `seq` (Hudak et al. 2007, §10.3); general full laziness, which changes strictness (Pałka 2012).
- **D. A simplifier, with GHC's default eta.** Not conforming: after eta through `case`, `(f bot) seq 1` converges where it should diverge. 6.2: "the provision of seq has important semantic consequences, because it is available at every type."

**How far E3 carries, for D48 to D51.** E3's ladder is the one modern measure here (`results/E3/compare.txt`, the section of 152 programs E8 accepts). It sizes a direction, on GHC, and it is not a measure of these decisions:

| Step, from the totals | Thunks | median program | Bytes | median program |
|---|---:|---:|---:|---:|
| `-O0` to L1 | -47.2% | -26.2% | -37.7% | -17.7% |
| L1 to L2 | -20.2% | -11.5% | -10.9% | -5.4% |
| L2 to `-O2` | -66.0% | -36.7% | -58.3% | -25.7% |

(Medians recomputed from `results/E3/keep/compat/*.json` with `compare.py`'s counts; 150, 149 and 145 programs for thunks, where both counts are non-zero.)

- **L1 is not "known dictionaries" alone.** It is `-O1` with 13 passes or analyses off and both unfolding thresholds at 0 (`results/E3/ticky.py:18-20`). GHC's simplifier stays on, with case of known constructor, case of case, and rewrite rules (`Opt_EnableRewriteRules`, `ghc/compiler/GHC/Driver/DynFlags.hs:1240`, read at 9.14; the run was 9.4.7) [inferred from the flags]. So its step is D48 and D49 together, and no run separated them.
- **No rung holds a specialiser.** `-fno-specialise` and `-fno-cross-module-specialise` hold at L1 and L2. D49's specialisation is inside the last step, with inlining and floating.
- **No rung holds eta.** `-fno-do-lambda-eta-expansion` holds at L1 and L2.
- **L2 adds more than strictness.** It restores worker/wrapper too, and CPR is never turned off (`ghc/compiler/GHC/Driver/DynFlags.hs:1257`), so CPR's worker/wrapper comes with it [inferred from the flags].
- **`-O0` is not rhc's `-O0`.** Only the user's program moves. `base` is optimised at every level, and from L1 on the program reads its unfoldings, which `-O0` ignores (`ghc/compiler/GHC/Driver/DynFlags.hs:1222`). On 91 programs at `-O0`, a Report-style Prelude in source allocates 1.59 times the thunks and 1.24 times the bytes of `base`'s (`compare.txt`, first section). rhc starts nearer that, and no ladder was run on it.
- **Totals flatter.** Five of the 152 programs hold 40.3% of `-O0`'s thunks and ten hold 61.0% (recomputed), so the median program gains about half what the totals say. By tree, the first step is -63.4% on the nhc98 snapshot and -44.2% on the 2019 tree.
- **Thunks carry better than bytes** [inference]. A thunk count is what a lazy translation makes. Bytes hold GHC's boxes, which Rune's immediate `int` does not have, and 41.8% of them at `-O0` are `base`'s or unattributed.
- **The runs are unfiltered:** 10 of the 152 differ from the suite's stdout at some level (E3).
- **Nothing is priced on Rune.** GHC's counts say nothing of what a thunk or an unknown call costs at tier 2. E5 does that, by hand, on a few kernels (D49).

**The evidence for this decision.** Old GHCs, off-by-one: everything off +140%, the simplifier alone +80%; case of case off +10%; eta off +8% instructions and +8% allocation (Peyton Jones, Santos 1998; Santos 1995, in *What the literature says*). Ratios on 1990s compilers. E3 cannot size eta at all.

**Recommendation.** C. **The strongest argument against:** Eta is the one transformation in this list where Haskell 98's `seq` makes a wrong rewrite silent. No oracle helps: GHC's default gets it wrong on purpose, so a judge at `-O` may agree with rhc's bug. It is worth 8% on a 1990s compiler, and something less under the pedantic rule [inference]. rhc could leave eta out, and leave arity to Mid's `workers`, where nothing sits between the lambdas. The answer is that a function's arity decides whether its calls are known, which on Rune decides `n-1` closures (E3, D15), and that a bottom probe (D55) sees this bug where an oracle does not. E5 does not settle it: an unknown call costs 116 instructions against 43, but eta alone saved 0.0% to 1.1% after specialisation, and no step ran strictness without it. If M23 finds the pedantic rule gains nothing, it goes.

**What would reopen it.** M23 finding on the corpus what E5 found on seven programs, that eta alone moves almost nothing; bottom probes showing the rule too hard to hold.

**Decided (owner, 2026-11-09).** C, as recommended: a simplifier, with eta under the pedantic rule. To be measured: D, GHC's default eta, built and benchmarked against C (*Decisions on the numbers*). D is not conforming, so taking it would need a deviation D38's rule does not cover, or the owner's word. Built in M23.

### D49. Known dictionaries and specialisation

**Question.** Dictionary passing hides every method: at `-O0`, 57.9% of calls are `KNOWN_CALL_EXTRA_ARGS`, a method through its selector, and 63.1% of calls apply two or more arguments, median 56.9% (E3, `compare.txt`). What does rhc resolve, and in what order? Changes to Rune under every option: **none**.

- **A. Nothing: dictionaries at run time.** `-O0`.
- **B. Resolution at known dictionaries.** A method selected from a constant dictionary becomes its instance's function. In GHC's terms, the class-op rule.
- **C. That, then specialisation with a fuel limit.** **Recommended, and first in track P.** Overloaded functions cloned at constant dictionaries, under fuel, with the Prelude's unfoldings available (D44). With `Integer` defaulting, dictionaries are constant at the call, so a specialiser sees what it needs at the use site [inference].
- **D. Dictionary-free, whole program** (Jones 1995). Not possible: Haskell 98 has polymorphic recursion (4.4.1), and "The set of dictionaries ... is infinite and the specialization algorithm will not terminate". Dictionaries stay, and specialisation is an optimisation.

**The evidence.**
- *E3:* thunks -47%, bytes -38% in total, -26.2% and -17.7% median, and 2+ applies falling from 63.1% to 12.0% of calls, median 2.9, on the first step. D48 says how far that carries: that step is the simplifier and the class-op rule, with GHC's specialiser off. It is the one measure this decision has on a corpus, and it measures something next door. The one published figure for a specialiser is Augustsson 1993's Table 1, on hbc, by hand transformation within a module, the collector excluded: 9.2 times on nfib, 1.9 on choleski, idInt and hinc, 1.03 on sched, whose signatures were already monomorphic, with the table's rows read as cumulative, which the paper does not say (*What the literature says*, D49).
- *Order:* GHC specialises before strictness (`ghc/compiler/GHC/Core/Opt/Pipeline.hs:216`). `sum` and `product` are `foldl (+) 0`: an unknown `(+)` hides everything from a strictness analyser, as Augustsson 1993 §5.3 says.
- *On Rune:* E5 ran the ladder by hand-lowering, on three whole nofib programs and four kernels: `mrhc.py` is no compiler, and its steps, in code type, are not decisions. M instructions at Rune `-O0`, tier 2 (`results/E5/k.txt`; E5 has the rest):

| Step | `queens` | `primes` | `exp3_8` | `sum` | `list` | `showk` |
|---|---:|---:|---:|---:|---:|---:|
| `D0`, dictionaries at run time | 2,542 | 553 | 4,023 | 3,636 | 7,910 | 1,405 |
| `D1`, known dictionaries resolved | 2,001 | 410 | 2,929 | 3,627 | 8,060 | 1,343 |
| `D3`+eta, specialised | 1,947 | 394 | 2,915 | 3,006 | 7,179 | 953 |
| `D1`+eta+strict, no specialisation | 1,265 | 267 | 2,866 | 3,247 | 5,268 | 1,297 |
| `D3`+eta+strict | 1,209 | 243 | 2,852 | 809 | 4,342 | 562 |
| The same, immediate `Integer`, Rune `-O2` | 987 | 188 | 2,850 | 444 | 3,160 | 276 |
| `ghc -O0` | 744 | 147 | 771 | 247 | 596 | 68 |

Step `D1` saves 21% to 27% of instructions on whole programs and no thunk: `queens` makes 13.3M at `D0` and at `D1`, and strictness then takes that to 5.3M (`results/E5/density.txt`). On `sum` it saves 0.2%, and `list` rises 1.9%, unexplained. `sum` needs specialisation and strictness together: 3,247 with strictness alone, 809 with both, which confirms the order above. Mid does not do this by itself: Rune's `-O2` on `D0` output saves 3.0%, 2.0% and -0.8% on the whole programs, against 21.3%, 25.8% and 27.2% for `D1`, and that answers D47's third argument on these programs. **The first optimiser is four things:** known dictionaries with literals, eta from visible arity, dictionary and static-function specialisation, first-order strictness without worker/wrapper: 15, 20, 143 and 95 lines of the throwaway `mrhc.py`. Eta's place is the least measured: alone it saves 0.0% to 1.1%, and no step ran strictness without it.

**Recommendation.** C, first in track P. **The strongest argument against:** "The gain is the optimiser's, not the dispatch's." Dispatch is cheap, "a reference to a tuple element followed by a function call" (Peterson, Jones, §9), and under Gofer's naive code generator specialisation gains little. On hbc it was not cheap: a method call took about 15 memory references against 6 for a known call, and the dictionary's representation alone gained 2.2 times on nfib (Augustsson 1993, §4.1, Table 1); specialisation gained most there all the same, so the point stands. So resolving a method buys nothing by itself on a compiler with no optimiser behind it; the gain comes from what is then known. That is why D48 comes with it, and why E3's first step cannot be read as this decision's alone. On Rune E5 splits this: resolution alone saves 21% to 27% of instructions on whole programs, and on `sum` and `sumint` 0.2% and 0.4%, and no thunk on any. The other argument is D47's third: Mid's `specialise` may already do part of this. E5 finds little of it, above.

**What would reopen it.** M23's counts on the corpus showing resolution alone moving nothing, as on `sum` in E5, when track P starts from D50 or from Mid.

**Decided (owner, 2026-11-09).** C, as recommended: resolution at known dictionaries, then specialisation with a fuel limit, first in track P.

*From the papers (E15b).* Augustsson 1993 adds three things C must do. It specialises local overloaded bindings: a SPECIALIZE'd `sum` "is hardly an improvement" while its local `sum'` stays overloaded (§5.4, fig 10). It folds `fromRational` as well as `fromInteger` (§4.3). And it keeps its fuel, since polymorphic recursion defeats specialisation (fig 9). Lands in M23.

### D50. Strictness

**Question.** Next after D49, in M24. What analysis, and where do its results go? Changes to Rune under every option: **none**: a strict parameter lowers to `T` and a lazy one to `susp T`, which D3 already gives, and Mid's `workers` then flattens tuples. Core's types must separate evaluated from unevaluated, or a result has nowhere to go (D2).

- **A. No analysis.**
- **B. Forward abstract interpretation** (Peyton Jones, Partain 1993): top, bottom, functions, finite products, with absence as a second interpretation.
- **C. One backward analysis with signatures** (Peyton Jones et al. 2006). **Recommended,** if rhc writes one analyser: it takes absence with it, and it works per module, since strictness "does not require a whole-program flow analysis, and readily adapts to separate compilation" (Ennals, Peyton Jones 2003, §7.1). Signatures go in HsIface (D44). It does not look inside recursive types: a spine-strict append "might have a terrible effect on the peak space requirement".

**The evidence.** E3: a further -20% thunks and -11% bytes on the totals, -11.5% and -5.4% on the median program, with calls +1.9%. D48 says how far that carries; here it means strictness, worker/wrapper and CPR together, with call-site inlining off. The literature agrees in size: thunks always fall, -36% geomean, total allocation -12%, time 10-20% typical, on 17 real programs (Peyton Jones, Partain 1993).

**A danger for conformance.** Strictness may evaluate before an I/O action what the source evaluates after it. In Haskell 98 `ioError` can be caught and `error` cannot, so the same bug changes behaviour. With `IO` a function in Core (D25), the analyser needs GHC's rule from the start (`ghc/compiler/GHC/Types/Demand.hs:1526`, Note [Precise exceptions and strictness analysis]). Which `error` a failing program reports may change, legally (Peyton Jones et al. 1999).

**Recommendation.** C. **The strongest argument against:** The ladder's last step is three times this one, and a too-strict compiler is the characteristic lazy bug. An analyser for -11.5% of the median program's thunks is a poor first bet if inlining and floating would do more. The answer is that the last step is mostly D48's and D49's own work done fully, not a rival [inference: E3 did not separate it], and that specialisation is what makes the analysis see anything. Bottom probes hold the danger (D55).

**What would reopen it.** M23's counts on Rune leaving too few thunks for this to matter; a force on Rune proving too cheap to repay it.

**Decided (owner, 2026-11-09).** C, as recommended: one backward analysis with signatures, in M24.

### D51. Cheap eagerness, and what stops `inline` copying a thunk

**Question.** Two questions, decided together with D22, because each is about what may run early or twice. May rhc evaluate a cheap expression instead of building a thunk? And what stops a pass copying a thunk, so that its work runs twice?

**Cheap eagerness.** D22's checked prims mean `int_add` raises (`src/isa/prims.sml:27`, `effects = [Raises]`). So `Int +` is not speculable: run early, it can stop a program that would never have demanded it. That closes the local form of cheap eagerness for `Int` arithmetic, as Faxén says himself (Faxén 2000, §3, p 152). `div` is out on any reading. Under D20's D an `Integer` add of two immediates cannot raise, but the big path is unbounded, so only speculation guarded by a test of the immediate bit qualifies, the form Faxén 2001 measured [inference].

- **A. Small: a primitive that cannot raise.** D22's C, or one that reports overflow, so that a site can speculate and fall back to a thunk. Faxén 2000 §6 proposes that form for division and did not build it; not built here. One primitive per operation, through `src/isa` on every engine.
- **B. None: reopen D22.** Its B: `Int` wraps through the word prims, and `+` is total. The cost falls on every `Int` operation: +7 machine instructions on an add, +3 on a mul-mod loop (`results/V2/word/`).
- **C. None: total operations only.** **Recommended, and not before M25.** Speculate what cannot raise, on values Core's types say are evaluated: GHC's `exprOkForSpeculation` (`ghc/compiler/GHC/Core/Utils.hs:1791-1792`), with the warning about recursive dictionary functions in its Note (`ghc/compiler/GHC/CoreToStg/Prep.hs:1859`). Constructors of values, and moving bounded work out of a thunk to expose a head normal form.
- **D. None: no speculation.**
- **E. Rejected: flow analysis** (Faxén 2000): whole program; "separate compilation is impossible" (§6, p 158).

**The evidence.** None on rhc's question. E3 has no rung for this, and D48's limits apply. It gives that 91.3% of thunks are entered at `-O0` (`compare.txt`), which is beside the point: Faxén's gain is in thunks not built, evals removed and unboxing, from thunks with "an about average probability of being evaluated" (Faxén 2000, p 157). His Table 1 gives 0% (sort) to 52% (qf) fewer instructions, and 26%, 5% and 11% on event, sched and tc, his three programs larger than toys, with a wrapping `Int`, programs of at most 700 lines and a very simple strictness analyser. His "All evals expensive" column is a figure for the local form: 16%, 1% and 8% on those three, a ceiling for rhc (D22). "0-25%" is Ennals's summary, and Ennals warns such gains shrink on a mature baseline. The dynamic form costs 7 to 8 instructions a test and "hardly improves run-times and instructions counts at all for most programs" (Faxén 2001, §5), which weighs against A, and against cheap eagerness steered by a profile, unless that tier compiles a specialised side [inference]. The prize elsewhere is update avoidance (Sansom, Peyton Jones; Sergey et al. 2014).

**What stops `inline` copying a thunk.** A distinct type stops a blind read. It does not stop a copy, and "safe" is not "shared" (W2).
- **D3's surface does the first half.** A thunk is not a `fundef`. It is the result of a primitive bound by `Let`, and force is a primitive, so nothing calls the thunk's code by name for `inline` to copy (`docs/ir.md:856-862`; deduced from `patches/E2-all-forms.patch`). No test counts re-evaluation under Simplify.
- **Small, and recommended: a sharing budget, and a lint.** The budget of *Testing and conformance* is what sees a copy, and its mutant "a thunk copied" is seen by that and only that. A rule in MidLint adds a little: the function a thunk is made from has no other use. That is D57's item 2, not built in Rune; E14's `midshape.py` is the rule as a script.
- **Core's own inliner is rhc's problem.** Pushing a redex under a lambda loses sharing with every type intact. D48's simplifier needs an occurrence analysis from its first version. A thunk used once inside a lambda is not used once.
- **Lazy ML:** E14 tested the claim on a language where a copied body repeats effects: 634 thunk functions, 0 violations (D57).

**Recommendation.** C, not before M25; for copies, the sharing budget and D3's surface. **The strongest argument against** taking the two together: cheap eagerness is an optimisation and D22 is a language choice, and letting a late pass decide `Int` arithmetic gets the order wrong. So D22 stands by itself, on the Report and on cost, and this decision only records that it closes the door, and what it would take to open it.

**What would reopen it.** A program outside `hash` overflowing, which reopens D22 and with it this; M25 finding cheap `Int` thunks dominating on Rune; a sharing budget catching a copy under D3's surface.

**Decided (owner, 2026-11-09).** C, as recommended: total operations only, not before M25; for copies, the sharing budget and D3's surface. Under D20's D an `Integer` add of two immediates is total, so a site guarded by a test of the immediate bit may speculate it; Faxén 2001's figures say not to expect much of that.

### D52. Oracle policy

**Question.** The Report has no semantics to check against, and no published Haskell conformance suite was found (E15). Who judges an expected result? Changes to Rune: **small,** in `tests/runner` only: `Oracles` takes its compile command and programs as arguments, with Rune's inventory unchanged (M2, about 400 lines changed for all the runners [estimate]). No compiler source changes. The design is *Testing and conformance*.

- **A. GHC alone, or Hugs alone.**
- **B. A majority of three.**
- **C. GHC with the strict shim and Hugs `+98` as judges, nhc98 `-98` third, MicroHs a smoke oracle.** **Recommended.** Every expected result cites a clause. Where the judges disagree, or agree against the clause, that yields a reading, and rhc follows the Report (D38). Recursive modules have no oracle.

**The evidence.** E7: of 82 tests 48 disagree, 20 hard, 16 not Haskell 98, 7 oracle gaps, 5 environment (`results/E7/disagreements.tsv`). E8: of 721 expected-fail candidates nhc98 accepts 121, Hugs 32, GHC 11 (`results/E8/summary.txt`), and GHC refuses what Hugs accepts on 210 programs with no expected failure, so neither judge is enough alone. Majority verdicts on `let` fixity and NondecreasingIndentation are wrong by the Report's letter (E15), so a vote decides nothing. Of 3,089 candidates none has a plain import cycle (E8).

**Recommendation.** C. **The strongest argument against:** Two judges and a third are a standing cost, and not an independent one: the shim is ours, nhc98 builds only 32-bit under flags found by trial (`results/E7/build-nhc98.sh`), and bugs the judges share are invisible. A citation is one reader's reading. The answer is that nothing better exists, and that rhc's table states what each result rests on.

**What would reopen it.** A judge's build ceasing to work where it runs nightly; the shim proving to be the source of a verdict.

**Decided (owner, 2026-11-09).** C, as recommended: GHC with the strict shim and Hugs `+98` as judges, nhc98 third, MicroHs a smoke oracle.

### D53. The conformance table

**Question.** `docs/language.md` is kept honest by id, in both directions, and has 200 rows. rhc's clause matrix has 3,901 (E9, `results/E9/clauses.tsv`). Changes to Rune: **small,** in `tests/runner`: a check over a TSV, beside `DocChecks.features`, about 250 lines [M1's estimate]. Design: *Testing and conformance*.

- **A. No table:** suites alone.
- **B. By hand, in Markdown,** as `docs/language.md`.
- **C. A generated TSV of 3,901 rows, enforced by id.** **Recommended.** `tests/hs/conformance.tsv`, every row `Planned` at M1, and G2 is the state in which none is. It lands as data: `tests/runner/migration.sml:2,10` requires an owner for every live `.py`, so `build_clauses.py` does not land.

**The evidence.** 1,379 accept rows, 548 reject, 1,854 run, 120 `none` (`clauses.tsv`). Their classes are first readings: read from the text, not run, with 12 rows sampled by eye (E9). 1,253 rows are generated, so one program must be able to name many ids.

**Recommendation.** C. **The strongest argument against:** A full table shows the tests exist, not that they are strong: Yang et al. saw coverage metrics barely move while bugs were found. And up to 3,781 programs is a large item, for evidence of a kind no Haskell implementation was found to have. Mutants and generators answer the first (D55); D45 and M19's order answer the second.

**What would reopen it.** E9's first readings proving wrong often enough that the rows must be rebuilt; D38's errata changing the structure rather than rows.

**Decided (owner, 2026-11-09).** C, as recommended: a generated TSV of 3,901 rows, enforced by id.

### D54. HsLint

**Question.** The brief: "add an independent type checking lint pass as for sml 97". AstLint cannot be copied: it checks the Definition's rules from the elaborator's records and "never unifies" (`elab/astlint.sml:16`), and the Report has no rules. Changes to Rune: **none:** HsLint is in `lib/language/haskell`. Design: *Testing and conformance*. Size: about 3k lines for HsLint and CoreLint together [E10's estimate], 2,000 to 2,500 of it HsLint [M16's estimate], against AstLint's 1,957 and MidLint's 457.

- **A. A target check alone.** Close to CoreLint. It cannot see that `show (read "True")` elaborated at `Int` and at `Bool` are both well typed at `[Char]`, with different meanings (Faxén, §10.2).
- **B. A target check and a second inference, on the elaborated output.** **Recommended.** Hall's soundness statement, and a transliteration of THIH's `tiImpls`, `split`, `candidates` and `tiProgram` in its conformant form, compared with rhc's evidence records. Only this part can check Rule 2 of 4.5.5, ambiguity and 4.3.4's defaulting; Rule 1 has a second check under C.
- **C. Those, and replay of Faxén's rules.** It adds messages that cite his rule names, and a check of Rule 1: his `bindg` with Definition 2 states it (Faxén 2002, p 338). It cannot refuse ambiguity, since his rules admit ambiguous schemes (§7.2.3), and it has nothing for deriving, `newtype`, strictness flags or recursive modules (§1.3). Not recommended.

**The evidence.** The literature, not an experiment. Faxén 2002 and THIH are the bases; neither checks elaborated output, Faxén was never implemented, and THIH omits the implementation of overloading. The only published typing of a Haskell elaboration is Hall et al. 1996 §5.2 (*What the literature says*).

**Recommendation.** B. **The strongest argument against:** A second inference by the same author, from the same reading of R18, R20, R21 and R22, shares its misreadings with the first, and it shares the renamer outright. It is a second type checker to keep. The answer is that it catches the slip and not the misreading, as AstLint does, and that the misreading is what D52's oracles are for.

**What would reopen it.** Mutants of the second inference's rules surviving it; its costing more than the checker it checks.

**Decided (owner, 2026-11-09).** C, against the recommendation: a target check, a second inference, and replay of Faxén's rules. The section above stays as the evidence, corrected: replay checks Rule 1.

*Lead's note.* Faxén's rules leave out recursive modules, so replay cannot check a module cycle by his rules.

*From the papers (E15b).* His rules leave out deriving, `newtype` and strictness flags too (§1.3), and their module rules are per module, so an SCC under D30 needs a rule of rhc's own [inference]. They admit ambiguous schemes (§7.2.3), so replay cannot refuse ambiguity: Rule 2, ambiguity and defaulting stay the second inference's alone. His deviations from the Report in §2.2, §4.2 and §4.3 are amended before replay runs. Replay needs recorded choices at two places, "dict inst" against "dict super" and premise types absent from the conclusion (§10.2.2, p 355), which rhc's evidence records must hold (D31) [inference]. With D33's C, derived instances made as AST give replay something to check. Lands in M16.

### D55. Generators, metamorphic relations and rhc's mutants

**Question.** A fixed suite is not enough, and a table cannot say so. Changes to Rune: **small,** in `tests/runner`: `CompilerMutants` reused with its corpus passed in. Rune's own mutant list must follow track A, since E11-7 moves code it names. Design: *Testing and conformance*.

- **A. The clause suite and the corpus alone.**
- **B. Three generators, cheapest first: syntax, Core, programs; metamorphic relations citing clauses; bottom probes; rhc's mutants.** **Recommended.** A fixed seed in `make check`, long runs nightly, a reducer with the printer.

**The evidence.** Pałka 2012 is the one body of Haskell work here: `[Int] -> [Int]` terms with `seq`, about one failure per 10,000 terms, four bugs, too-lazy code. His metamorphic pairs caught what cross-optimisation missed. Csmith's authors: "fixed test suites ... are an inadequate mechanism for quality control". E10's parser mutants: dropping `where`, a context, `deriving`, a precedence or `~` passes the tree round trip on every one of 1,616 files, and fails the token test on 743, 227, 184, 91 and 9. The Report defines its semantics by translations, so each relation can cite a clause.

**Recommendation.** B. **The strongest argument against:** Cost. Rune's mutants are a job of their own, and generated programs must stay inside what the judges can compare, which E15's "hold still" list narrows. The answer is the order: syntax and Core generators need no type checker and run before a front end exists, and the rest is nightly.

**What would reopen it.** Generators finding nothing the suites do not, over a long run. Mutants showing a stage no test sees is a finding, not a reason to stop.

**Decided (owner, 2026-11-09).** B, as recommended: three generators, cheapest first, metamorphic relations, bottom probes and rhc's mutants.

### D56. What rhc costs `make check`

**Question.** Second class in tools, first class in conformance (C1): how much of Rune's `make check`, 11,879 s of CPU (`docs/testing.md:258`), may rhc take? Changes to Rune: **none** to the compiler; a tier's contents. Design: *Budgets and tiers*.

- **A. All 223 run programs, every way.**
- **B. The 188 programs under 1 s in `make check`, in 3 of `Lang.ways`' 18 ways; the rest nightly.** **Recommended.** `test`, `register`, `register-opt`: the stack VM, `bin/runevm` at its default `--jit=opt`, and tier 2 (`tests/runner/lang.sml:105-126,275-278`). The 35 others, and every way and both bytecodes on gc-stress, are nightly, where G2 is met.
- **C. The 112 programs under 0.1 s** (1.2 s under `ghc -O0`).
- **D. No corpus in `make check`:** clause programs alone, the corpus nightly.

**The evidence.** E8: 223 programs right under `ghc -O0`, 191.8 s of CPU, median 0.10 s; 188 at or under 1 s, 36.4 s (`results/E8/run.summary.txt`), at load 30 to 40, so indications. One way of the 188 takes 36.4 × K s, K/326 of `make check`. 19 of the 223 and 13 of the 188 print a wrapping hash, and run through D22's compat `hash`.

**K, rhc's slowdown against `ghc -O0`:** 3.4 to 5.2 on three whole programs, `queens`, `primes` and `exp3_8`, and 13 to 23 on four Prelude-bound kernels (`results/E5/k.txt`), in instructions at tier 2, on E5's step `D0` at Rune `-O0`. With the Report's list functions compiled `-O0` on GHC's side three of the four kernels, `sum`, `sumint` and `list`, fall to 1.2 to 6.7 (`results/E5/ghc/r/r.tsv`, which has no `showk`), so their K is mostly `base` at `-O2` and the collector. **Use K = 5 for whole programs and K = 20 for Prelude- or `show`-bound ones [inferred].** One way of the 188: 36.4 s becomes 182 s or 728 s, 1.5% or 6.1% of `make check`, before compile times and ways. **K rests on three hand-lowered programs and four kernels,** with `read` left out and `IO` erased. Two limits on the sum for three ways. K is tier 2's: the default tier is within 3.4% of it on the 18 rows run (`results/E5/results-default.jsonl`), and E5 ran nothing on the stack VM, one of the three ways. E10's gap from tier 2 to an interpreter is 3.8 to 6.5 times (`results/E10/speed.tsv`), so if the stack way costs about six times [V2's estimate], three ways are about 8K: 1,456 s or 5,824 s, about 12% or 49% of `make check`, not the 4.6% or 18.4% of K on all three. And K is a ratio of instructions laid on seconds: the same runs' cycles, single loaded runs, give 5.8 to 7.0 and 18.8 to 42.8 (`results/E5/k.txt`), an indication that seconds run above it.

K comes from hand-lowering three programs and four kernels. It prices running, not compiling. rhc's compile time is unmeasured (E8), and at the clause rows' scale it is the larger term until D45's snapshot lands.

**Recommendation.** B. **The strongest argument against:** The figure that decides this is the one not measured. A budget set on three hand-lowered programs and four kernels, for a compiler that does not exist, may be off by an order of magnitude, and the recommendation fixes a count of programs instead of a share of the time. At K = 20 the estimate above is half of `make check`, which this set cannot carry. So what binds is the share: M19 measures it, and programs or the stack way move to nightly if it is too high.

**What would reopen it.** M19's measured K or compile time putting the set above what the owner gives `make check`.

**Decided (owner, 2026-11-09).** B, as recommended: the 188 programs under 1 s in `make check`, in 3 of `Lang.ways`' 18 ways, the rest nightly.

### D57. What "ready for lazy ML" means

**Question.** The brief: "doing haskell first ensures the whole stack supports lazy evalaution properly and the lazy ml can be a properly supported language extension to rune later". Haskell alone does not ensure that: W6. What is the exit of track Z?

- **A. Large: a Core shared by both languages.** Rejected by D2 unless E14 finds lazy ML needs more than `susp`, force and match compilation.
- **B. Medium: ship the extension.** `$`, the forcing pattern, `susp` behind a flag. A follow-up: no surface syntax lands in this roadmap.
- **C. Small: a checklist that has been run.** **Recommended.** A throwaway patch carries the spec's programs through the stack, and what it finds is fixed or written down. Changes to Rune so far known: the guard on the collector's `K_IND` shortcut (`runtime/gc/minor.c:151`, `runtime/gc/mark.c:155`), +0.9% geomean on the lazy ports, worst 5.8% on `fulsom-lazy` (E2, `results/E2/tables/guard-cost.txt`), which Haskell cannot reach and which must look through forwarding.
- **D. None: thunks work, so it is ready.** W6 says why not. `'a susp susp` breaks after a collection on forms B, C and G without the guard (E2, `tables/nested.txt`), and no Haskell test can see it.

**What is known without E14.** One object, one force, most of the collector. A lazy ML body does not blackhole and does not release, because it may run again (D12), and a Haskell body does: form G needs no mode bit. The table of what the two share is in *What the literature says*, D57.

**E14:** the flip did not fire. Lazy ML needs no Core and no line in a Mid pass, and all 10 of the spec's programs pass: 31 programs, 1,302 runs, 0 not ok, on both targets at `-O0` and `-O2` (`results/E14/tables/matrix-final.txt`). The patch is +239 -30 in 17 files (`results/E14/tables/lines.txt`). With the flag off, 756 strict programs are byte-identical to V's tree (`results/E14/nocost/summary.txt`).

**But form G as V left it was not ready.** On V's collector 162 of those runs fail, on a body outliving its own update: the register engine overwrites the value, and the stack engine silently loses the update (`results/E14/tables/matrix-V-collector.txt`). D11's pin fixes it at 1.0003 on the ports. There is no release bit: lazy ML's difference is release unset, plus the pin (`results/E14/tables/prims-used.txt`). Agent I's claim that `inline` can copy a thunk with MidLint silent is true and unreachable from `$`: 634 thunk functions, 0 violations (`results/E14/tables/midshape.txt`, `claim-fun-held.txt`). So Haskell's programs alone would have left this undetected, which is W6.

**"Ready for lazy ML" means, from E14, which ran it:**
1. **The pin landed:** a `K_IND` a frame still runs is not shortcut, with `k_outlive*` and `outlive_nullary` on both engines.
2. **A MidLint rule:** a function given to `thunk_fmake` is named by nothing else, and `thunk_fupd` appears nowhere else (`results/E14/scripts/midshape.py` is the rule as a script).
3. **The stack target lowers force.**
4. **The spec's 10 programs green** over the mode table plus `--lint=3`, with raise, re-entry, effects, nesting, rule order and equality pinned.
5. **Flag off:** bytes and `--count` unchanged, and `susp` unbound. V's tree binds it (`results/E14/tables/offcheck.txt`).
6. **`susp` documented** and in `tests/ir`.

Items 2, 3 and 6 are Haskell's too, and land in M9. Items 1, 4 and 5 are M26's, with the guard. E14's patch stays in the drafts, since no surface syntax lands, so items 4 and 5 are shown on it and do not stay in `make check`. What stays is the lint, force on the stack target, `susp` in `tests/ir`, and the pin's programs, which need rewriting under `--allow-prim` as E2's kernels are [inference, not built].

**Recommendation.** C. **The strongest argument against:** a throwaway patch proves the stack on 10 programs, and the proof rots the day it is deleted. The answer belongs with E14's result: what stays in `make check` once the patch is gone.

**What would reopen it.** The extension being scheduled, when this checklist becomes its first milestone.

**Decided (owner, 2026-11-09).** C, as recommended: a checklist that has been run. E14 ran it on form G, and the owner took form C, so M26 runs it again on form C: the pin, the MidLint rule, the stack target's force, the spec's 10 programs, flag off, and `susp` documented. Lazy ML's reading under C is E2's `CmX`, without `BLACKHOLE` and without release.

## The milestones

Each milestone is one commit or a few, and each commit leaves `make check` green. One that touches the compiler's sources also passes the host builds and `make check-cross`; one that touches units or the cache passes `make check-units` and `make test-incremental`; one that touches `runtime/register` also runs `make test-register-asan`, `make test-stress` and the Windows and portability rules (`AGENTS.md:168-170`). A build made only to be measured is the exception: it is built on the register VM first, and lands with the rest only if the owner adopts it (*Decisions on the numbers*). rhc's own sources are built by Rune alone (D42).

A heading gives the track, the size and the order. **What** says what lands, by file. **Starts from** names the prototype, if there is one. **Rests on** names the decisions, and what changes if the owner decides otherwise. **Gate** appears on every change to Rune, and says what the standing gate asks of that change. **Done when** is what a test can show. Paths under `lib/language/haskell`, `src/rhc`, `share/rhc` and `tests/hs`, and new files in `tests/runner`, are proposals. Line numbers are of `b12141ecc`, where the roadmap was written, and stay so. Implementation starts from origin/master `697724da5`, where build-system-v2 has landed, so each is checked there before its milestone, and a citation of that tree says so.

**A prototype is evidence, not code to land.** Every patch under `patches/` and every spike under `results/` was written to answer a question. They carry comments marked throwaway, hold several forms at once, or skip what a landing needs. A milestone takes from one its design, its tests and its numbers, writes what lands, and shows the gate again on what it wrote.

**Sizes** are lines of SML added, tests not counted, unless the heading says otherwise. A prototype's size is that patch's own count. The only measured rate in the front end is E10's parser: 2,207 lines, which is 8.2 parser lines and 13.5 lines all told per production of 9.5's 163. Everything else marked [estimate] has no rate behind it. E10's estimate through Core is about 12-20k lines of SML, without signature files, real diagnostics, Core to Mid or a Core optimiser, which are extra and unmeasured. How that range divides is this section's own estimate, from nhc98's and MicroHs's phases at E10's ratios of SML to Haskell, 0.92 and 1.30:

| Part | Lines of SML | Basis |
|---|---:|---|
| M11 | 2,207, printer 258 | measured, E10 |
| M12 | 2,000 to 3,500 | [estimate] nhc98 `Rename.hs` and `RenameLib.hs` 1,729, with its import and export files. E16's name resolution alone is 364, measured |
| M13 | 3,000 to 7,500 | [estimate] nhc98 `Type/` 1,963; MicroHs `TypeCheck.hs` 4,213, which holds names too |
| M14 | about 1,000 | [estimate] nhc98 `Derive/` 1,074 without its Binary and XML; MicroHs `Deriving.hs` 853 |
| M15 | 1,000 to 2,000 | [estimate] nhc98 `Case*.hs` 839; MicroHs `Desugar.hs` 695; both before the dictionaries |
| CoreLint in M8, M16 | about 3,000 | [estimate] E10, from AstLint's 1,957 and MidLint's 457 |

These parts sum to 12.5-19.5k, which is E10's range. The range has no line for Core's own definitions or its interpreter [deduced from E10's sum], so M8 adds to it, as M10 does, and D28's exact printer adds to M11, unmeasured. There is no calendar here. The owner's decisions of 2026-11-09 add four milestones, numbered after M27 so that nothing renumbers: M28, `Ty` with application and forall (D4); M29, Mid `Case` (D8); M30, multi-value return (D9), which since the owner's answer of 2026-11-10 is built to be measured and lands only if adopted; M31, `IntInf` immediate (D20). What is built only to be measured sits in the milestone where it belongs, and *Decisions on the numbers* gathers it. D46 is not applicable: build-system-v2 has landed.

### The order

```text
at once, from origin/master 697724da5; G0 passed on 2026-11-09
  T    M1 table     M2 runners     M3 oracles, corpus
  A    M4 contract -> M5 Mid to bytecode     M7 lints, Simplify
       M6 walkers -> M28 Ty, M29 Case; M30 multi-value return, to be measured
       M31 IntInf immediate, the bignum path first
  B    M8 Core -+-> M10 Core to Mid, after M28
       M9 thunks, form C; D3's measured variant after M6
  F    M11 parser, after M2 -> M12 names, modules -> M13 types, classes -> M14 deriving, M15 desugaring, M16 HsLint
  L    M17 Prelude, in the Report's layout, after M31 -> M18 libraries

G1   hello

  T    M19 the bulk of conformance, on the saved world until M21; the first measurements on the run set
  S    M20 the store's policy, optional     M21 HsIface, driver, beside M19
  S    M22 SCC keys

G2   the Report

  P    M23 -> M24 -> M25, with the measurements of Decisions on the numbers
  Z    M26, on form C
       M27
```

**At once, from origin/master `697724da5`.** build-system-v2 has landed there, and the owner's decisions are taken, so G0 is passed. What may start at once: M1, M2, M3, M4, M5, M6, M7, M8, M9 without D3's variant, and M31. M11 follows M2; M28, M29 and M30 follow M6, since each adds an arm to Mid's walkers, as does D3's variant in M9. M10 follows M28, whose `Ty` it emits. M31 comes before M17, whose `Integer` shares its representation (D20, D26). M30 is a build for D9's measurement and gates nothing: until the owner adopts it, M17's state token returns its pair as a tuple, or erased (D25). E11's patches were made on `b12141ecc`: on origin/master E11-2 applies, E11-4 after it, and of the rest only E11-10's hunk in `matchcomp.sml` (`git apply --check`), so M4 redoes them. Mid's codecs are generated now: a change to a constructor of Mid, to `fundef` or to `Ty` is a change to `tools/codecs/compiler.sml` and a run of `make codecs`, which `make check-codecs` holds to (M4, M28, M29, M30). What rhc took from build-system-v2 is *What build-system-v2 gave rhc*.

M5 keeps `--read-mid` to bytecode and the label in Mid's text. Its Mid unit that names SML globals is not needed under D26's A, since no SML lies below Haskell.

**Tracks B, F and L.** Core text stands between B and F, so B needs no parser: M9 runs on E2's kernels and M10 on Core written by hand, as E1 ran on Mid written by hand. M8 and M9 go side by side, and M10 needs both and M28. F goes in the order of its heading; M14, M15 and M16 overlap once M13 stands. M17's text is written as M12 and M13 need it, since names and types are tested on the Report's own modules, and it first runs after M10 and M15. So cycles and the joined checker land before the Prelude first runs, and the Report's layout needs no fallback (D36). If M13 runs late against M17, D36's option D is the fallback, built only then.

G1 stands after M18 in the order. Hello needs less than that: M8 to M10, M11 to M15 and M17. If it passes sooner, M16 and M18 go on behind it, and the bulk of M19 waits for them.

**After G1: the bulk of M19, with M20 and M21 beside it, M22, then G2.** M19 runs on a frozen Prelude, the saved world (D45's option B) until M21. M20 and M21 do not gate it: the case for landing them first asked for a frozen Prelude, not for those milestones, and M21 would fix HsIface before conformance has shaken out classes and instances (D45). M22 comes before G2, since recursive modules are in the Report's exit. M20 is what remains of the store split now that build-system-v2 has built the store: an optional move of its policy, on no milestone (D43).

**After G2: tracks P and Z, then M27.**

| Track | Milestones |
|---|---|
| T, tests | M1, M2, M3, M19 |
| A, Rune's contract | M4 to M7, M28 to M31 |
| B, back | M8 to M10 |
| F, front | M11 to M16 |
| L, libraries | M17, M18 |
| S, separate compilation | M20 to M22 |
| P, optimisation | M23 to M25 |
| Z, lazy ML | M26 |
| none | M27 |

### M1. The conformance table and its enforcement (T; M, 3,901 rows of data and about 250 lines [estimate]; at once)

* **What:**
  - **`tests/hs/conformance.tsv`:** E9's `results/E9/clauses.tsv`, with the three columns of *The conformance table* added: `status`, `reading`, `deviation`. Every row is `Planned`.
  - **The errata (D38).** E9 built its rows from the online text, where 16 of 18 errata are unapplied (`results/E9/errata-status.tsv`). The rows an erratum changes are edited here, and the list of errata lands beside the table.
  - **`tests/runner/hsconformance.sml`:** the five rules of *The conformance table*, each direction a failure, on top of `DocChecks.tsv`'s header and duplicate checks (`tests/runner/docchecks.sml:93-102`), with further ids on a program's first line.
  - **The table lands as data, and no `.py` lands.** Every live `.py` needs an owner (`tests/runner/migration.sml:2,10`), so `build_clauses.py` stays in the drafts. Only errata and readings edit the table. If it must ever be regenerated, the generator is a `tools/generate` command in SML.
* **Starts from:** no patch. `results/E9/clauses.tsv` and `counts.tsv`. The `test` classes are first readings, read from the text and sampled on 12 rows (E9): the table is a list of work, not a result.
* **Rests on:** D53, D38. If the owner keeps a Markdown table, the same rules hold, by hand, at 20 times `docs/language.md`'s 200 rows. If D38 takes the text unamended, E9's rows stand and each erratum becomes a reading.
* **Done when:**
  - the table loads in `make check`, with every row accounted for: 3,901, or the list of errata says why not;
  - a test plants a breach of each of the five rules, and each is refused;
  - `runner/migration-inventory` shows no new `.py`, `.sh` or `.awk`.
* **Touches:** `tests/hs/conformance.tsv`, `tests/runner/`, `tests/runner/docchecks.sml`, `Makefile` (`RUNNER_SRCS`, `Makefile:2032`), `docs/testing.md`.

### M2. Runners generalised; round-trip harness (T; M, about 400 changed [estimate]; at once)

* **What:**
  - The rows of *What Rune has, and what must be generalised*: `Lang` takes a record of root, suffixes (`.hs`, `.lhs`), compilers and ways, and a program may be a directory with a `Main`; `LangChecks` takes its root; `Oracles` takes its compile command and programs; `ExternalChecks` takes a manifest, shims and a skip file; `CompilerMutants` takes its corpus and `rhc.build` in place of `bootSources`.
  - rhc's tree in `tests/runner/hslang.sml`, with `covers:` tags for `lib/language/haskell/*`, `src/rhc/*` and `share/rhc/*`.
  - **The round-trip harness,** `tests/runner/hsroundtrip.sml`: the tree test and the token test of *Round trips*, over a print command and a tokens command, with an implicit print and generated ASTs beside the explicit print (D28, D55), since a printer that prints only braces never exercises `L`. It has no parser until M11, so it is first tested on a stub that plants differences.
* **Starts from:** no patch. `results/E10/run.sh` and `mutants.sh` show the shape, and do not land.
* **Rests on:** D28. With the tree test alone, a dropped AST field is invisible: E10's five parser mutants pass it on all 1,616 files.
* **Done when:**
  - `bin/rune-test list` shows Rune's inventory unchanged: the same jobs under the same names;
  - a stub compiler is scheduled and judged over a `.hs` program, a `.lhs` program and a multi-module directory, and a stub that prints nothing fails, as `jitOne` does (`tests/runner/oracles.sml:430-444`);
  - the harness fails a planted tree difference and a planted token difference.
* **Touches:** `tests/runner/{lang,langchecks,oracles,externalchecks,compilermutants,main}.sml`, new files in `tests/runner/`, `Makefile`, `docs/testing.md`.

### M3. Oracle harness and the corpus imported (T; L, the corpus and about 500 lines [estimate]; at once, its first task before anything lands)

* **What, in this order:**
  1. **The corpus's licences.** E8 surveyed none, and the repository's CC0 cannot cover these programs (*The corpus's home*). The survey lists, for each program that may land, its licence and where that is stated, the 188 of D56 first. On its result the owner chooses for those 188: vendored under `tests/hs/corpus/` with their licences, or a `Test.requires` (`lib/test/unit/test_sig.sml:52-54`) that skips them where the corpus is absent. A skip is an error in `make check` today (`AGENTS.md:311-313`), so that second option needs either the corpus on every machine or a weaker `make check`.
  2. **The manifests as data:** E8's `accept.tsv`, `reject.tsv` and `run.tsv` under `tests/hs/corpus/`, pinned to the trees they name, and E8's 144-line compat layer, with `hash` over `Integer` printing the 64-bit result, `spectral/sphere`'s own included: 19 of the run programs print such a hash, and no `Int` of rhc's matches them all (D22).
  3. **The harness,** `tests/runner/hsoracles.sml`: the judges by capability, nightly, and their disagreements in `tests/hs/oracles.txt` (*The harness*). `results/E7/build-oracles.sh`, `build-nhc98.sh`, `oracles.py` and E8's `judge.py` do not land (`tests/runner/migration.sml:2,10`). The recipes become doctor hints and the rest SML.
  4. **The hard cases:** the six programs of E7's 20 with no reading yet each yield one (D52).
* **Starts from:** no patch. `results/E7/`, `results/E8/`, `oracles/ghc-shim`.
* **Rests on:** D52. If the owner wants fewer oracles, nhc98 can go: it cannot judge rejections, accepting 121 of 721 expected failures (E8), and it needs a 32-bit build with chosen flags (E7). Neither judge is enough alone. Licences are not a decision: a program whose licence does not allow it does not land.
* **Done when:**
  - nothing lands under `tests/hs/corpus/` without a surveyed licence;
  - with no rhc, the harness reproduces E7's 82 tests and E8's verdicts on the trees present: any difference is a line in `tests/hs/oracles.txt`, and a line that no longer matches fails;
  - a missing oracle skips its nightly job with how to install it;
  - each of the 20 hard cases has a reading, or is one of the two that need none.
* **Touches:** `tests/hs/`, `tests/runner/`, `LICENSE`, `docs/testing.md`, `Makefile`.

### M4. Rune's contract: E11's patches, as decided (A; L, +1,073 -967 in 42 files for all eleven by `results/E11/sizes.tsv`, measured on `b12141ecc` and redone on origin/master; at once)

* **What:**
  - **Front-end independence (D40):** E11-1 `util/stamp.sml`, E11-2 `Target` passed in, E11-3 counters registered where they live, E11-5 `label` on `fundef`, E11-9 `util/literal.sml`. Mid's codecs are generated since build-system-v2's M5, so E11-5's `label` is a field of `fundef` in `tools/codecs/compiler.sml` (`:234-237` at origin/master `697724da5`) and E11-9's `Literal` changes the type `const` describes there (`:183-188`, `Lambda.const` today), each followed by `make codecs`, in place of E11's hand edits of `core/midcodec.sml` and `driver/unitmid.sml`.
  - **The pipeline as data (D39's C, the owner's answer of 2026-11-10):** E11-4 the pass list, a record `{name, from, gate, run}` that a client edits; E11-6 Simplify's and Lower's options passed in; E11-8 `driver/midpipeline.sml`, everything from Mid down, naming no front end; E11-7 `backend/results.sml`, the analysis of `results` out of `Lower`; E11-11's root names after E11-7 and E11-8.
  - **What `lib/compiler` exports (D41, the lead's: C):** `lib/compiler/mid.build`, from the prototype's `tests/compiler/mid-only.build`: 48 of the 80 files after the patches (master has 76; four are new), with no lexer, parser, elaborator, Translate, ToMid or Expand, `use`d by `internal.build`. `internal.build` and `frontend.build` are reordered so that the layer comes first, with `unitstore.sml` and `pickle.sml` moved into it (Y). A client of the layer is a friend of `lib/compiler`, since at origin/master a build that reaches into a library with a header and is not a friend is refused (v2's M14). rhc's own entry in `friends` comes with `rhc.build` in M8.
  - **`Try` and `Fail` (D7):** E11-10, with four expected dumps reviewed line by line and the constructors removed, which E11 left in the datatype. Its change to `core/matchcomp.sml` still applies at origin/master.
  - **The clients as tests:** `tests/compiler/mid-client.sml`, Mid text to bytecode through the layer, and `pipeline-client.sml`, which edits the list.
  - **What E11 left stale:** `docs/ir.md` takes `results/E11/contract.md`, and says that the list is a seam, not a proof of independence (D39); `tests/runner/compilermutantlist.sml` follows E11-7's move out of `lower.sml`, since a mutant that no longer applies is a FAIL.
  - **The defect:** a pass list that is data can refuse a name it does not hold, so `--passes=nosuchpass` and `--dump-after=nosuchpass` stop being accepted (`results/defects/passes-unknown-name/`).
* **Starts from:** `patches/E11-1-stamps.patch` to `E11-11-roots.patch`, in that order, each redone on origin/master. As they stand only E11-2 applies there, and E11-4 once E11-2 has; E11-10's `matchcomp.sml` hunk applies, and its line in `tests/compiler/mid-only.build`, which E11-9 creates, does not; E11-11 names `backend/results.sml` and `driver/midpipeline.sml`, which E11-7 and E11-8 create (`git apply --check`: by Y, again while recording the decisions, and for E11-4, -6, -7, -8 and -11 on 2026-11-10). Each patch is a design and a test; what lands is written on the new tree.
* **Rests on:** D7, D39, D40, D41, as decided. D39 is C by the owner's answer of 2026-11-10, which supersedes the D of 2026-11-09; D41's layer needs E11-8, so D41 is C without condition.
* **Gate:** bytes stay put, and budgets stay put. E11 held bytes on every patch on `b12141ecc` (`results/E11/verify-summary.txt`), and the compiler's own compile fell 0.81% in instructions and 0.64% in allocation (`results/E11/compile-cost.txt`, at E11-10), so no budget need move. The redone patches must show the same on origin/master: stage1 equals stage2, and the edited compiler on the sources before the edit gives that tree's `bin/rune.rbc`, at stack, `-O0` and `-O2`, on both targets. `make check-codecs` passes after each change to the description. It also runs what E11 did not: `make check`, the host builds, `make check-units`, `make check-docs`, the compiler mutants.
* **Done when:**
  - the gate, on each commit;
  - `tests/compiler/mid-client.sml` built from `lib/compiler/mid.build` writes the same bytes as the client on `internal.build`, at `RUNE_LINT=3`, and a name of the elaborator in it fails to compile;
  - that client, with `workers` and `refs` removed from its list, allocates as E11 saw, 304 bytes against 87,091,544 (`results/E11/client/mo-none.rbc`, `mo-remove.rbc`, by `runevm --count`): the swap is real;
  - an unknown pass name is refused.
* **Touches:** the 42 files of `patches/E11-all.patch` at origin/master, among them `lib/compiler/driver/pipeline.sml`, `lib/compiler/core/{mid,midtext,simplify,matchcomp}.sml`, `lib/compiler/backend/lower.sml`, `lib/compiler/{internal,frontend}.build`; new `lib/compiler/util/{stamp,literal}.sml`, `lib/compiler/backend/results.sml`, `lib/compiler/driver/midpipeline.sml`, `lib/compiler/mid.build`; `tools/codecs/compiler.sml` and the generated regions of `core/midcodec.sml` and `driver/unitmid.sml`; `tests/compiler/`, `tests/runner/compilermutantlist.sml`, `tests/ir/`, `docs/ir.md`, `docs/architecture.md`.

### M5. Mid to bytecode, Mid text with labels (A; S, about 30, from +14 -2 and +14 -2 measured; at once, its second step after E11-5)

* **What:**
  - **`rune --read-mid FILE -o OUT` reaches bytecode** (`src/driver/main.sml:218` at `b12141ecc`, whose comment says there is none yet; `main.sml` has grown at origin/master and the hunk is placed again there).
  - **Mid text carries a function's `label`,** so a functor's function read from text stays one. `Expand.isFunctor` (`core/expand.sml:190`) and `Simplify.functorFun` (`core/simplify.sml:1982`) depend on that name, and without it Basis Mid read back from text breaks a lint at `-O1` and `-O2` (`results/E1/link/run.out`).
  - **No Mid unit that names SML** (D26's A). E1's Mid unit resolved `gimp_NAME` and type names through `Env` and `UnitBasis`; rhc's library is Haskell over primitives, so that part of `patches/E1-all-prototypes.patch` does not land.
* **Starts from:** `patches/E1-readmid.patch` and `E1-midtext-functor-name.patch`. The second reads `Translate.funNames`, which E11-5 takes away, so it is rewritten on the label.
* **Rests on:** D1, D26, as decided.
* **Gate:** bytes stay put. With E1's prototypes on top of its read-mid patch the compiler's sources compiled to identical bytes at `-O1` and `-O2` (`results/E1/out/selfcheck.txt`), and the read-mid change is outside SML's path [deduced]. The same test as M4. Mid's text changes, so a dump in `tests/ir` that shows a labelled function is reviewed by hand; the round trip at level 3 holds.
* **Done when:**
  - E1's programs, `results/E1/prog/*.mid` over `rts.mid`, are tests in `tests/ir`'s form, compiled and run on both targets at three levels, against E1's hand-derived `.expected`, those that call SML through a Mid unit rewritten over primitives or left out;
  - Basis Mid read back from text compiles at `-O1` and `-O2` at lint 2.
* **Touches:** `src/driver/main.sml`, `lib/compiler/core/midtext.sml`, `tests/ir/`, `docs/ir.md`.

### M6. Walkers and a fold (A; M, removes most of 479 lines [deduced], not prototyped; at once, before M28, M29, M30 and D3's variant)

* **What:** `Mid.atomsOfRhs` and `Mid.mapRhs` in `core/mid.sml`. The 25 `rhs` walkers that list their atoms or loop over them move to the first, and the 12 that rebuild to the second (*The IRs, reviewed*). `Lift.atomsOfRhs` and `Refs.atomsOf` become one (`core/lift.sml:31`, `core/refs.sml:27`). Then D10's C, taken now: `Mid.fold` over `exp`, where a walker's arms are all the default; 43 of the 88 walkers over `exp` end in a catch-all (`results/E12/walker-defaults.tsv`).
* **Why here:** M28, M29 and M30 each add a form to Mid's types, expressions or returns, and D3's measured variant an `rhs`, and a new form falls into a catch-all without a word. So the walkers come first.
* **Starts from:** no patch. `results/E12/walker-shapes.tsv`, `walker-defaults.tsv`, lower bounds by a heuristic.
* **Rests on:** D10, decided: C, now.
* **Gate:** bytes stay put, deduced and not prototyped. The same test as M4; budgets as M4.
* **Done when:**
  - the gate;
  - the 28 of 38 `rhs` walkers that end in a catch-all fall to a listed few, each with its reason;
  - a scratch constructor added to `rhs` draws "match is not exhaustive" (`elab/exhaust.sml:274`) at both new functions, and one added to `exp` at `fold`;
  - the 43 of 88 `exp` walkers that end in a catch-all fall to a listed few, each with its reason.
* **Touches:** the files of `results/E12/walkers.tsv`: `lib/compiler/core/{mid,simplify,workers,expand,lift,shake,midtext,midcanon,refs,midcodec}.sml`, `lib/compiler/backend/lower.sml`, `lib/compiler/driver/unitmid.sml`, `docs/ir.md`.

### M7. Lints and the two Simplify fixes (A; S, +10 -4 measured and about 150 of lints [estimate]; at once)

* **What:**
  - **E1's two Simplify fixes, together.** `staticParams` refuses a function that calls itself at other types (`core/simplify.sml:896`), and `makeCopy` compares type arguments (`:1182`). The second alone makes specialise diverge (`results/E1/fixA-only.sh`). SML cannot reach this. Mid written by rhc can, and at the default lint level it compiles to ill-typed Mid in silence (`results/defects/specialise-polyrec/`).
  - **The equality bound.** Past a type of size 256, `eqKindOf` takes `poly_eq` (`core/simplify.sml:349`). **This also fixes a defect on master in plain SML:** `=` on a non-uniform datatype at `-O2` overflows the compiler's stack (`results/defects/equality-nonuniform/`).
  - **D5's lints:** `ConTag` only of a datatype (`core/midlint.sml:271` passes `tag` of a `susp`, a fatal at run time on every engine); no forward read of a `Val`, which no lint sees and on which `-O0` and `-O1` disagree (`results/E1/out/neg/unset.txt`); abstract arity (`core/midtext.sml:648` reads it and checks nothing). D5's C, a checked `Any` at run time, is `any_check` behind a compile-time switch, and lands in M9 with the casts.
  - **D5 written down** in `docs/ir.md`, with what no lint can reach: `results/E11/contract.md`'s rule, held only by types.
* **Starts from:** `patches/E1-simplify-polyrec.patch`. The lints were not prototyped.
* **Rests on:** D5, decided: B, for the lints. The Simplify half stands whatever the owner decides, since one of its three parts is a bug on master. If the owner declines the rest, rhc can live without it, by typing a polymorphically recursive function at `any` (`results/E1/prog/nest_any.mid`) and never emitting `poly_eq` on a datatype (E1).
* **Gate:** bytes stay put. With the fixes the compiler's sources compiled to identical bytes at `-O1` and `-O2` (`results/E1/out/selfcheck.txt`). Budgets count level 0 (`docs/testing.md:95-96`), where these lints do not run [deduced], and `levelsOne` holds a linted build to a plain one (`tests/runner/oracles.sml:99`). No lint here has been run over SML's own Mid, so `ConTag` to datatypes may need an exception [inferred]; any exception is named in `docs/ir.md`, not a quiet weakening.
* **Done when:**
  - `nest.sml`, the defect's reproducer, compiles at `-O2` and prints what `-O0` prints, as a test;
  - after M5, `nest_static` and `nest_eq` pass all 45 ways, as `results/E1/matrix-fixed.txt`, and E1's sweep stays at 0 bad of 232 compiles (`results/E1/out/sweep/result.txt`);
  - each new lint refuses its fault with its message in `tests/compiler/lint-rules.sml`.
* **Touches:** `lib/compiler/core/{simplify,midlint,midtext}.sml`, `tests/compiler/lint-rules.sml`, `tests/ir/`, `tests/lang/`, `docs/ir.md`.

### M8. Core, its text, CoreLint, a Core interpreter (B; L, about 2,000 [estimate]; at once)

* **What:**
  - `lib/language/haskell/core.sml`: System F with type application `f a`, lazy `let` and `letrec`, forcing `case`, and types that separate evaluated from unevaluated (D2).
  - `lib/language/haskell/coretext.sml`: printer and reader. Core text is a contract, read back after every stage at level 3.
  - `lib/language/haskell/corelint.sml`: syntax-directed, with no unification, run at each boundary and on text read by `--read-core`, and last just before the crossing into Mid (*HsLint and CoreLint*).
  - `lib/language/haskell/coreinterp.sml`: Launchbury as specification, Sestoft's machine as program, slow by design.
  - `src/rhc/{main,options}.sml`, `rhc.build`, `bin/rhc` in the `Makefile`, with `--read-core`, `--dump-after`, `--lint`.
  - **rhc's identity and its place in `lib/compiler`.** `rhc.build` lists `src/rhc/config.sml` first, which `scripts/gen-version.sh --config rhc.plan src/rhc/config.sml` writes over rhc's own committed plan, so rhc's identity is its own and Rune's stays as it was (v2's M11; `tests/runner/buildchecks.sml:467-489` tests a second compiler doing it, origin/master `697724da5`). `rhc.build` is named in the `friends` of `lib/compiler/library.build`, since a build that reaches into a library with a header and is not a friend is refused (D41).
  - `tests/hs/core/`, in `tests/ir`'s form (`tests/runner/tools.sml:27-44`), and the Core generator of D55.
  - `lib/language/haskell/library.build`, `README.md`.
* **Starts from:** no patch. E1's `results/E1/prog/*.mid` are what Core text must be able to say one level up, and they are its first tests.
* **Rests on:** D2, D41, D42, as decided. An untyped Core would leave CoreLint nothing to check and strictness results nowhere to go; dropping types later is easy, adding them is not.
* **Done when:**
  - print, read, print is the identity on every Core test, at level 3;
  - each CoreLint rule refuses its fault with its message, as `astlintFaults` does (`tests/runner/tools.sml:783`);
  - the interpreter runs E1's eight programs rewritten in Core text and prints their `.expected`, with `knot`'s sharing count right;
  - loop, abort and stack overflow are one bottom in its results, and a run that prints nothing fails.
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `rhc.build`, `rhc.plan`, `lib/compiler/library.build`, `Makefile`, `tests/hs/core/`, `tests/runner/`, `docs/testing.md`.

### M9. Thunks through the engines (B; L, about 420 by hand for form C with parity [estimate; not built as one], +45 and +7 from E4, and D57's lint, not built; D3's measured variant beside it, not sized; at once, the variant after M6)

* **What, under D3's B with form C, D11's C, D13's C and D14's C:**
  - **The object.** A thunk is a flat `K_THUNK`, entered by `ENTER`, under evaluation once its code says `BLACKHOLE`, and evaluated as `K_IND` (D11). `K_THUNK` keeps heap-layout's reservation (`runtime/value.h:72`). The collector skips a blackholed thunk's fields, which is release, and `K_LAST` moves. `CALL` stops a `K_THUNK`, so a thunk in a function-typed slot stops on every engine, where under form G only MidLint stood (D11).
  - **`susp` in `Types.builtinTycons`,** so that force types as `'a susp -> 'a` and MidLint holds it to its suspension (D3).
  - **The primitives and the instructions.** Mid sees primitives, E2's form C names among them `thunk_make`, `thunk_force`, `thunk_blackhole` and `thunk_self_update`, and `thunk_move`, which `Low.hoistEnv` uses; `Regs` makes them `FORCE`, `ENTER`, `BLACKHOLE` and `UPDATE` (`results/E2/delay/Chs/lazy.sml`, `patches/E2-all-forms.patch`). The primitives go at the end of their list, the instructions after `FIELD`, through `make isa`: `src/isa/{prims,regs}.sml`, `runtime/prims.c`, `runtime/register/isa_regs.c`, `runtime/register/jit/{emit.c,compile.c,compile.h,masm.h}`, `lib/compiler/backend/{low,regs}.sml`. About 305 lines with the 45 shared by every form (D11's table).
  - **Force is one Mid node.** `thunk_force` stays a `Prim` through every pass, and `Regs` makes it `FORCE`, with `ENTER` and `RESULT` on its slow path. `removable` asks a primitive's description (`core/simplify.sml:113`): force's says `anything`, so it is never dropped and not moved across an effect, which `seq` needs, and `thunk_make`'s must say what is true (D3).
  - **Parity by form C (D14), which is D57's item 3:** the four instructions on the stack set too, in `src/isa/stack.sml`, the Stack target, `runtime/stack/`, runeopt's templates and `src/opt/x64.sml`, `runtime/native/native.c`, `tests/opt/every-opcode.rasm` and `docs/bytecode.md`: about 115 lines [estimate, not built]. Form C never ran on the stack VM or in native code in E2; only forms B and F did (`tables/stack-vm.txt`, `F-stack-native.txt`).
  - **Release and re-entry (D12, not applicable under C).** A thunk's code reads its captures at entry (`Low.hoistEnv`) and says `BLACKHOLE`, so its captures are released and re-entry is found at once.
  - **CAFs and the barrier (D19).** CAFs stay roots until D19's measurement decides (M25), and the update writes through the barrier that exists, with nothing new.
  - **`K_IND` made live.** Three latent faults come alive with the first thunk: `share.c`'s `contents_hash` and `same_contents`, `image.c`'s `put_object`, and `runtime/image.c:906`, which refuses a frame whose closure is no longer a `K_CLOSURE` (`results/defects/latent-k-ind/`).
  - **Casts (D4, D5).** Value-to-`susp` casts remain under D4's C (M28 removes the `any` ones): the cast erased in `Lower`, with a Lower rule dropping a force of a known non-thunk, and always the lint that no cast leaves a `susp`. D5's C, a checked `Any` at run time, is `any_check` behind a compile-time switch, in checked builds and VMs only, since a forgotten force behind a cast runs silently at tier 2 even under `--checked` (`results/E1/out/neg/forget.txt`). E4's `RegVerify` exception let `CALL` see a non-closure on form G's slow path; whether form C needs one is shown here [inference: `FORCE` gives a value that is not an unevaluated thunk as itself, `regops.h` in E2's patch]. `patches/E4-cast-modes.patch` holds four modes and does not land as it stands.
  - **D57's item 2, which is Haskell's too:** a function given to `thunk_make` is named by nothing else, and `thunk_self_update` appears nowhere else. Without it `inline` can copy a thunk's update into another closure's function with every lint passing (`results/E14/tables/claim-fun-held.txt`, through `_prim`, on form G). `results/E14/scripts/midshape.py` is the rule as a script, for G's names.
  - **Docs:** `docs/ir.md` for `susp` and force, `docs/bytecode.md` for the primitives and the four instructions on both sets, `runtime/register/README.md`.
  - **`susp` in `tests/ir`,** with its documentation D57's item 6, which is Haskell's too.
  - **D3's measured variant, after M6:** C, a `Force` right-hand side, a fifteenth `rhs` with an arm in every walker, and D6's C with it, a recursive form in Mid for thunks; described in `tools/codecs/compiler.sml` and lowered to the same instructions as B's primitive. It is built on a branch beside B, for the register target alone, measured as *Decisions on the numbers* says, and lands, with its lowering in the Stack target, only if the owner takes it.
* **What does not land:**
  - the other forms' primitives in the same patch: form G's, `thunk_fforce` among them, and those of B, F and L;
  - the raise repair, with `THUNK_FAILED` and the spare field: neither language needs them, so there is no failed state (D12);
  - closure liveness (`-DRUNE_CLOSURE_LIVE`);
  - the guard on the collector's shortcut (`runtime/gc/minor.c:151`, `runtime/gc/mark.c:155`), which Haskell cannot reach and which cost Haskell's thunks +0.84% on form G (`results/E2/tables/guard-cost.txt`), and the pin (`gc_pin_running`), which Haskell cannot reach either: both are lazy ML's, and go with M26, unless D17's B is taken, which makes the pin Haskell's (*Decisions on the numbers*);
  - `susp` in SML's initial basis. E2's line in `Env.builtinTysNow` (`elab/env.sml:416`) is for its SML kernels and would change what every SML program accepts, and rhc does not need it (D3). A test in SML takes `_prim` syntax, as `_int64` does (`elab/env.sml:428-430`).
* **Starts from:** `patches/E2-all-forms.patch`, form C (`ChX` on `bin10`, rerun by V2 as `ChY` on `bin12`), which holds every form at once and cannot land as it stands. `results/E2/INDEX.txt` says which build is which; `results/E2/kernels/` are the tests.
* **Rests on:** D3, D4, D5, D6, D11, D12, D13, D14, D18, D19, D57, as decided. What the numbers may change: D3's C, which replaces force's primitive by an `rhs`, with D6's C; D17's B, which brings the pin here or to M25; D19's B, which changes what the collector roots.
* **Gate:** E2's forms have not been through `make check`, bootstrap bytes on the final form, `make test-native`, or the other machines: aarch64, 32-bit, PowerPC, Windows. M9 runs all of these, with `make check-isa`, `make bootstrap`, `make check-cross`, `make check-templates`, `make test-opt`, `make test-register-asan`, `make test-stress`, `make test-windows`, `make test-portability`, `make test-census` and `make perf-check`.
  - **Bytes move once, by one word.** New primitives and instructions change each set's fingerprint (`AGENTS.md:75-77`), which every `.rbc` and image carries (`docs/bytecode.md:18`) and the cache's configuration holds. Existing primitives and opcodes keep their numbers. So the edited compiler on the unedited sources gives `bin/rune.rbc` but for that word, and any other byte fails [deduced, not run]. D3 is the decision that says so.
  - **SML programs' budgets stay put.** E2 saw identical `--count` on 12 strict ports, and 1.0056 in machine instructions (`results/E2/tables/sml-cost.txt`), on `bin10`, the stage that holds form C's instructions (D13). The machine figure is taken again on the final form and recorded in D3.
  - **The compiler's own budgets re-base** [deduced, not measured]. Its image grows by the tables, by how much is not known. A budget is a ceiling, 10% over the count when written (`tests/runner/budgets.sml:111`), so a small rise may pass unchanged. M9 reports what moved, and re-bases in the commit that moves them (`docs/testing.md:670-673`).
  - **`any_check` off moves nothing:** a build without the switch is byte-identical to one without the code, and its `--count` unchanged (D5).
* **Done when:**
  - the gate;
  - E2's kernels are tests on every tier, in Haskell's reading, in `tests/thunks/` under `--allow-prim`: `chain`, `tailchain`, `knot`, `share`, `reenter`, `barrier`, `image`, `wrongslot`, `last` and `leak`;
  - `last` and `leak` keep 0 bytes an element (`results/E2/tables/last.txt`), and a 10^7 chain fits 1 GiB (D18);
  - a thunk typed `susp` in a mistyped read stops on all three engines, as `RAny` did in E2, and a thunk in a function-typed slot stops at `CALL`;
  - evaluated, unevaluated and under-evaluation thunks survive an image (`results/E2/tables/image.txt`);
  - E2's stress modes pass with `--count` compared, 504 runs and 0 bad there (`results/E2/tables/stress.txt`), and both bytecodes allocate alike;
  - form C through the Stack target, in native code and in the census build, none of which E2 ran, pass the same; release under the low-pause collector, skipped while marking in E2, is tested or stated;
  - `susp` has its cases in `tests/ir`, and each of the four instructions its line in `tests/opt/every-opcode.rasm`;
  - programs that do cast print the same with casts kept and erased, and each new lint refuses its fault with its message in `tests/compiler/lint-rules.sml`. The compiler's own bytes show nothing here, since it has no such cast (D4);
  - **force stays one node:** a `dump:` test finds `thunk_force` as one `Prim` after every pass at every level, and E2's 113 ports on the final form stay at or under `ChX`'s 268.86 G of `--count` (`results/E2/tables/summary.txt`), any rise explained before landing;
  - D3's variant is measured and the owner's choice recorded in D3.
* **Touches:** `src/isa/{prims,regs,stack}.sml` and what `make isa` writes, `runtime/{value.h,prims.c,image.c,runtime.c,vm.h}`, `runtime/gc/`, `runtime/census/census.c`, `runtime/stack/`, `runtime/register/{fastprim.h,isa_regs.c,README.md}`, `runtime/register/jit/`, `runtime/native/native.c`, `src/opt/`, `lib/compiler/backend/{low,lower,regs,stack,regverify}.sml`, `lib/compiler/core/midlint.sml`, `lib/compiler/elab/types.sml`, `tests/thunks/`, `tests/ir/`, `tests/opt/every-opcode.rasm`, `tests/compiler/lint-rules.sml`, `tests/runner/`, `docs/ir.md`, `docs/bytecode.md`; for the variant, `tools/codecs/compiler.sml` and the walkers M6 left.

### M10. Core to Mid (B; L, about 1,000 to 1,500 [estimate]; after M4, M5, M8, M9, M28)

* **What:** `lib/language/haskell/coretomid.sml`:
  - a lazy position of type T is `susp T`; functions take `susp` where lazy and return evaluated, so a datatype-typed variable is evaluated (D5);
  - **every force is one `thunk_force` node,** never a call of a library function and never its test written out;
  - a thunk's code takes `unit`, since `Fun` needs a parameter (`core/midlint.sml:333`); after reading its captures its first act is `thunk_blackhole` and its last `thunk_self_update`;
  - recursive values through a cell, and CAFs as thunks in globals (D6), as E1 wrote them; for D3's measured variant, the recursive form of D6's C, emitted only where that variant is measured;
  - **types in M28's `Ty`:** a higher-kinded position and a dictionary's polymorphic method have types of their own, and `Any`, meaning evaluated, is left for what `Ty` cannot say, with a lazy one as `susp Any`. A type variable is never instantiated at `susp T`, as Strict Core has it (D4). Value-to-`susp` casts remain, erased in `Lower` under M9's lint;
  - a `case` of Core lowered to M29's `Case` once it has landed, and until then to a tag test in the same function before each `Decon`, as LowShapes demands (`backend/lowshapes.sml:376`);
  - n-ary functions through curried wrappers where they are values (E1), unless D15's C is taken (M25);
  - several results, where Core returns an unboxed product, among them `IO`'s state and value (D25), as a tuple, or with the token erased; on M30's branch, for D9's measurement, through multi-value return;
  - the output handed to `MidPipeline.lowOfMid` with rhc's own pass list, which leaves out `expand` (D39's C, M4), as `results/E11/contract.md` says.
  - Two small steps in Rune, if wanted: the built-in tycons out of `Types` when rhc's first type name needs them, about 40 lines [inferred] (D40); `ToMid`'s builder lifted out of `core/tomid.sml:108,130,145`.
* **Starts from:** no patch. `results/E1/prog/rts.mid` and `monad.mid` are the hand lowering, and `results/E2/delay/Chs/lazy.sml` a thunk's shape under form C.
* **Rests on:** D3, D4, D5, D6, D8, D25, as decided, and D9 on the numbers. If the owner takes D3's C, force is the `Force` right-hand side and recursive thunks D6's recursive form; if D9's B, an unboxed product is a multi-value return.
* **Gate:** no change to Rune but the two small steps, each with M4's test. `Ty`, `Case` and multi-value return are M28's, M29's and M30's; the cast erasure and lint M9's. Force stays one Mid node, shown below.
* **Done when:**
  - E1's programs, through Core text, pass the ways E1's hand-written Mid passed: 45 each, on both targets;
  - the Core interpreter and the VM print the same on every Core test (*Differential self-oracles*), loop, abort and stack overflow being one bottom;
  - a `dump:` test finds one `thunk_force` for each force in Core;
  - CoreLint and MidLint are clean at level 2, and the two seeds of *rhc's mutants* for Core to Mid are caught: a force forgotten behind a cast, a thunk in a typed slot;
  - no type variable is instantiated at `susp T`, by a rule of MidLint or CoreLint with its fault;
  - E2's `last` and `leak` go through rhc as residency tests at two sizes;
  - the sharing budgets for recursive values run (D6).
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `tests/hs/core/`, and for the two small steps `lib/compiler/elab/types.sml`, `lib/compiler/core/{ty,tomid}.sml`.

### M11. Lexer, layout, parser, printers (F; L, 2,207 and printer 258, measured, plus real diagnostics and D28's exact printer, unmeasured; after M2)

* **What:**
  - `lib/language/haskell/{token,lexer,layout,ast,parser,print}.sml`: literate source and Unicode in the lexer; layout pulled a token at a time, with `closeImplicit`; operators flat, patterns parsed relaxed and checked afterwards (D27).
  - The AST of D28: spans on every node, parentheses, negation as an item, literals and contexts as written; a printer with an explicit-brace print and an implicit one.
  - **D28's C, on top of that:** annotations in every node, keeping comments, pragmas and layout, which E10's AST drops, and an exact printer whose print of a parsed file is that file. It comes beside the tree printer and its two round trips, not in place of them: an exact printer cannot print a tree that carries no annotations, such as a generated AST, the reducer's output or M2's implicit print. GHC keeps `check-ppr` and `check-exact` both, and Amorim 2018's printer, the nearest published, is not exact (*What the literature says*, D28).
  - Real diagnostics, which E10 did not assess: the size above does not count them.
  - `src/rhc`: `--parse-only`, `--dump-ast`.
  - **The general category of D21,** added to `lib/unicode` by `rune-generate unicode` (`tools/generate/README.md:26`). The lexer needs it first, so this half of D21 lands here and the case mappings with M17. E10's `gen_unicode.py` does not land.
* **Starts from:** no patch: `results/E10/spike/hs_{token,lexer,layout,ast,parser,print}.sml`, without signatures or diagnostics, and it has no fixity pass.
* **Rests on:** D27, D28, as decided. An automaton instead takes 146 grammar lines, 109 of driver, bison in the build and 1,262.9 instructions a token against 560.5, and still has no AST (E10). S1, the token rule, refuses 9 of 36 legal crafted programs.
* **Gate:** rhc's own code needs none. The addition to `lib/unicode` is a library change: `make check-docs` with every new member documented, and `make matrix-quick`. The compiler shares `lib/unicode` file by file (`rune.build:4`), so the addition goes in new files that `rune.build` does not list, and M4's test shows the compiler's output unchanged.
* **Done when:**
  - the 1,723 files E10 accepted parse, as E10 ran them, with 0 tree and 0 token failures;
  - E10's 46 crafted cases give their `results/E10/cases/cases.tsv` results;
  - each of E10's five parser mutants fails the token test;
  - the exact print of each of those files is the file, byte for byte, and a mutant that drops a comment fails it;
  - the syntax generator of D55 runs from a fixed seed in `check`;
  - GHC's dump runs nightly under the judges' capability, with E10's 47 known differences as expectations;
  - a budget holds the cost per token against E10's 560.5, with what diagnostics add stated;
  - the lexical and syntax rows that need only the parser have programs, which starts M19.
* **Touches:** `lib/language/haskell/`, `lib/unicode/`, `tools/generate/`, `src/rhc/`, `tests/hs/`, `docs/testing.md`.

### M12. Renamer, modules, fixity, recursive modules (F; L, 2,000 to 3,500 [estimate]; after M11)

* **What:**
  - `lib/language/haskell/modules.sml`: export and import resolution as the least fixpoint over each SCC; Prelude does not import itself (D29); the greatest fixpoint under `--names=greatest`, an option the owner asked for, least by default, documented as Rune documents `--flex-records` (`src/driver/options.sml:90-96`);
  - `--cycle-default=module|scc`, `module` by default, which M13 reads (D30); a list of modules that cannot be imported; a module's identity includes its library, since `nhc98/tests/nofib/real/infer` has a `module Maybe` of its own (E16).
  - `lib/language/haskell/rename.sml`: entities by origin, as H7 will need.
  - `lib/language/haskell/fixity.sml`: an entity's attribute, read after names, with no iteration; flat sequences resolved here, with R1, R9 and R10's refusals.
  - `src/rhc/graph.sml`: modules found by scanning imports, SCCs, the search path over `share/rhc/haskell98`. rhc does not use `Deps`, which refuses cycles (`driver/deps.sml:270`). Whole-program is the one-unit case.
  - Dotted names refused, with a documented flag (D35).
  - The Report's 11-module SCC resolved as one unit, with `PreludeList`, `PreludeText` and `PreludeIO` on the list of modules that cannot be imported (D36).
* **Starts from:** no patch: `results/E16/hs_modules.sml`, 364 lines, and its fixtures `results/E16/tests/{imp,gfp,cyc,hidden}`.
* **Rests on:** D29, D30, D35, D36, as decided, with the two options the owner asked for. Chapter 5 is satisfied by either fixpoint, so `--names=greatest` reads the text; `--cycle-default=scc` is an extension (D30).
* **Done when:**
  - E16's fixtures give the least fixpoint: 690 pairs on `imp`, one solution on `gfp`, an answer of no on `cyc`, a refusal on `hidden`; and under `--names=greatest`, 693 on `imp` (`results/E16/tests/imp.out`);
  - the Report's 20 modules resolve at E16's 683 pairs, with the 8 unresolved names reported until M17's overlay;
  - `do a == b == c`, which E10 parsed flat, is refused, as all four oracles refuse it;
  - a module named `Char` in a program does not meet the library's;
  - the three signed modules of `results/E15/run/boot3/` compile;
  - the seeds of *rhc's mutants* for names and fixity are caught: greatest for least fixpoint, a hidden module importable, fixity read before names.
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `tests/hs/`.

### M13. Kinds, types, classes (F; L, 3,000 to 7,500 [estimate]; after M12)

* **What:** `lib/language/haskell/{kinds,infer,classes,evidence}.sml`, and `--typecheck-only`:
  - kind inference, dependency analysis, unification, context reduction, the monomorphism restriction, defaulting and derived contexts; no OutsideIn (D31);
  - joined over an SCC, so a user cycle with unsigned bindings checks, and type groups and kinds cross modules (R28, D30);
  - evidence records in the manner of `Witness`, which are what M15 translates and M16 reads;
  - R18, R20 and R21 as D32 reads them; and in a cycle a variable defaulting by the `default` of the module its constraints arose in, refused where those modules' `default`s differ, with Rule 2 closing at the end of each module, a refusal where another member's use would fix a type (D30); and under `--cycle-default=scc`, one `default` per SCC with differing ones refused, and Rule 2 closing at the end of the SCC, documented as an extension (D30);
  - derived contexts inferred here, for M14's instances made as AST (D33's C);
  - `reject` rows' messages, which are rhc's own and pinned, and real diagnostics, not counted in the size.
* **Starts from:** no patch. `results/E16/ghc/changes.txt` shows what the Report's text asks of a checker.
* **Rests on:** D30, D31, D32, D33, as decided. A different reading of R18, R20 or R21 is one row and one program changed, not a redesign. Rule 2 resolved early, as Hugs does, is simpler and refuses legal programs (R20, E7).
* **Done when:**
  - the Report's 11-module unit checks as one unit, with no annotation at the one expression in `floatToDigits` that depends on defaulting (E16);
  - the programs for R18, R20 and R21 pin their readings, 4.5.5's examples among them;
  - a user cycle with unsigned bindings, a type group across modules, and fixity and instances across a cycle check (*Recursive modules have no oracle*);
  - both settings of `--cycle-default` are pinned by programs, among them D30's tie-break case;
  - the corpus programs both judges accept that need nothing, 815 rows of `results/E8/accept.tsv`, pass `--typecheck-only`, and it agrees with the compile on each; a difference is a reading or a bug, never an expectation accepted blind;
  - the E7 rows mapped to R10, R20, R22, R32, R34, R41 and R43 have programs.
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `tests/hs/`.

### M14. Deriving (F; M, about 1,000 [estimate]; after M13)

* **What:** `lib/language/haskell/derive.sml`: `Eq`, `Ord`, `Enum`, `Bounded`, `Ix`, `Show` and `Read` inside the checker, from the typed constructor (D33's C), with chapter 10's text as the specification of the code. M13 infers the context; the instance is then made as AST and elaborated like a user's, so that HsLint's three parts check it as any instance (D54). No layer of HsLint checks that a derived context is the least (10.1), since Faxén has no deriving rules: conformance rows do. A derived instance names entities, not text, since derived `Ix` in `Time` needs methods `Time` did not import (E16). Derived contexts are inferred by the checker, and move with imports, as H5 will need. R41 and R42 as read.
* **Starts from:** no patch. E9's chapter 10 rows; E16's table of derived instances.
* **Rests on:** D33, decided: C. Made only as typed output, a derived instance would leave HsLint no source phrase to check (D54).
* **Done when:**
  - chapter 10's programs run on the Prelude's types, 165 rows of which 120 are `run` rows, compared with the judges where they agree and against R41 and R42's pins where they do not;
  - `read` of `show` holds at each derived type, as a law;
  - the seed of a derived context too wide is caught.
* **Touches:** `lib/language/haskell/`, `tests/hs/`.

### M15. Desugaring to Core (F; L, 1,000 to 2,000 [estimate]; after M8, M13)

* **What:** `lib/language/haskell/{desugar,match}.sml`: chapter 3's translations and pattern matching in the Report's order, as `-O0`; dictionaries from M13's evidence records; Sestoft-order trees as an option, built for D34's measurement and kept only if the owner takes B (*Decisions on the numbers*). Translations name entities a program cannot shadow, `Ratio.%` and `fix` among them, though neither is a Prelude entity (E9), and H9 holds those names in a key. Rune's `trees` is not reused (D34).
* **Starts from:** no patch. `results/E9/translations.md`, with its 20 defects.
* **Rests on:** D34: A, with B measured. If D17's B is taken, pattern bindings and `~p` are desugared Sparud's way (M25). Trees as the only form would lose the literal `-O0` that the Report licenses as a semantics. Reusing `trees` would first need it to test a one-constructor type, as `f () = 1` must.
* **Done when:**
  - every Core output passes CoreLint, and its text round-trips;
  - each translation has its relation (*Generators and metamorphic relations*): the 92 `tr.*` rows, stdout compared, and braces and parentheses compared as Core text;
  - `-O0` against Sestoft-order trees agrees on stdout and on bottom or not;
  - the Core interpreter on a literal translation agrees with the VM;
  - the seeds for desugaring are caught: clause order reversed, `~` made strict, a `newtype` pattern forcing.
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `tests/hs/`.

### M16. HsLint (F; L, about 2,000 to 2,500 [estimate], and replay, not sized; after M13, M15)

* **What:** `lib/language/haskell/hslint.sml`, in three parts (D54's C; *HsLint and CoreLint*): a target check, that the elaborated term types by CoreLint's rules at the translation of its source type; a second inference, a transliteration of THIH's `tiImpls`, `split`, `candidates` and `tiProgram` in the conformant form, with kinds and dependency groups recomputed; and replay of Faxén's rules on (source, elaborated) pairs, with messages that cite his rule names. It shares only the renamer with the checker, and its unifiers are its own. Run through `Pass.checkAt` at level 2.
  - **What replay checks:** Rule 1, which his `bindg` with Definition 2 states (Faxén 2002, p 338). Not Rule 2, ambiguity or defaulting, which stay the second inference's: his rules admit ambiguous schemes (§7.2.3).
  - **What it cannot:** deriving, `newtype`, strictness flags and recursive modules have no rules of his (§1.3), and his module rules are per module, so an SCC under D30 needs a rule of rhc's own [inference]. Derived instances made as AST (M14) are checked as instances.
  - **Before it runs:** his deviations from the Report in §2.2, §4.2 and §4.3 are amended. Where his rules need a recorded choice, "dict inst" against "dict super" and premise types absent from the conclusion (§10.2.2, p 355), replay reads rhc's evidence records (D31).
* **Starts from:** no patch.
* **Rests on:** D54, decided: C. A target check alone cannot see `show (read "True")` elaborated at `Int` against `Bool` (Faxén, section 10.2).
* **Done when:**
  - each rule has a fault that corrupts its datum and is refused with its message, as `astlintFaults`;
  - the seeds for types and classes are caught by the second inference and the target check: Rule 1 off, Rule 2 by group, defaulting without a numeric class, a superclass path wrong, a method slot swapped; and Rule 1 off is caught by replay too, citing his rule;
  - replay's rule for an SCC has a fault of its own, refused with its message;
  - every suite is clean under `RUNE_LINT=2`, and a linted build equals a plain one at level 0, as `levelsOne`.
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `tests/hs/`, `tests/runner/`, `docs/testing.md`.

### M17. The Prelude: primitives, overlay (L; L, 2,436 lines of the Report's Haskell, and about 1,000 of overlay and rhc's runtime [estimate], with `IntInf`'s representation and small path over its primitives; first runs after M10, M15; after M31)

* **What:**
  - **`share/rhc/haskell98/`:** the Report's 11 modules as printed, 525 definitions and 2,436 file lines (E16), plus D38's errata, in the Report's layout: `Prelude`, `PreludeList`, `PreludeText`, `PreludeIO`, `Ratio`, `Numeric`, `Char`, `Ix`, `Array`, `Maybe`, `List`. rhc compiles the 11 as one unit, whole-program, with no merged form (D36).
  - **`share/rhc/haskell98/LICENSE`,** which says the files are modified and do not claim to define Haskell 98, and a sentence in the top-level `LICENSE` (D37).
  - **The overlay, listed:** the 8 unresolved names, among them `interact`'s and `numericEnum*`, the `...` forms and `prim*` uses of these modules, and about 15 named definitions [hand count, E9].
  - **The primitives, and no SML below Haskell (D26's A):** every `prim*` is a Core constant lowered to Mid's primitives, so all of them run in the Core interpreter too.
    - `Integer` (D20's D, D26's A): M31's representation, an immediate small value and `IntInf`'s signed magnitudes, with its small path, ported to rhc's runtime over the primitives `IntInf` itself uses (`intinf_binary`, `intinf_divmod`, `intinf_shift`, `intinf_power`, `intinf_decimal`, `src/isa/prims.sml:828-847`) and M31's in-line ones; ported as far as rhc needs it.
    - `Char` as Mid `int`, with the case mappings of D21 in `lib/unicode`; `Int` on the checked primitives (D22); `Float` by `real_to_single` (D23).
    - String literals unpacked lazily (D24's A), and, for D24's measurement, B, the whole list on first force, in rhc's runtime, and D, a primitive that unpacks, built on the register VM alone as a patch to Rune that lands, with the stack VM, runeopt and native code, only if the owner takes it (*Decisions on the numbers*).
    - `IO` with a state token (D25's B): an action takes the state and returns it with its value, as a tuple or with the token erased, until the owner adopts D9's multi-value return, which carries both with no pair built (M30); `getContents` through one interleaving primitive, whose body ends its list on a read error (21.2.2).
* **Starts from:** no patch: `results/E9/report-libs/`, with its `primitives.tsv` and `literal.tsv`, and `results/E16/overlay.py`. E5's kernels and `results/E5/core/`, whose `rts-i1.mid` is the small path with no bignum behind it.
* **Rests on:** D20 to D26, D36, D37, as decided.
  - D36's fallback, if M13 runs late: the merged form, derived at build time by a small tool in SML under `src/rhc`, since `merge.py` does not land (`tests/runner/migration.sml:2,10`). The tool makes the check `merge.py` claimed and did not make, that no two of the 11 modules define one name, and it needs one rule outside the Report: the internal module has no implicit Prelude. Layered: 59 definitions, 329 lines, move beneath the Prelude, and the bottom layer is 1,720 of 2,436 lines (E16).
  - D25's B makes `IO` ordinary Core, so Core takes on the rules that keep the token's order: never duplicate a redex, never lose the chain, no CSE across dummies (D25).
* **Done when:**
  - `check_merge.py`'s table as a test in SML: all 20 modules' 663 export pairs, 35 fixities and 164 instances as E16 found them, once M18 has the other 9;
  - G1's check passes;
  - `PreludeList`, `PreludeText` and `PreludeIO` cannot be imported by a program;
  - a token comparison against the pristine transcription, as `DocChecks.signatures` (`tests/runner/docchecks.sml:203-254`), finds nothing outside the overlay, by module;
  - the bottom probes on the literal Prelude agree with the overlay on each listed definition;
  - `Integer` agrees with `IntInf` on both paths, across the small range's edges, in the Core interpreter and on the VM.
* **Touches:** `share/rhc/haskell98/`, `lib/language/haskell/`, `lib/unicode/`, `tools/generate/`, `src/rhc/`, `LICENSE`, `Makefile`, `tests/hs/`.

### M18. The Report's libraries (L; M, 511 lines of the Report's Haskell, and about 500 of SML and overlay [estimate]; after M17)

* **What:** the 9 modules outside the unit, `Complex`, `Monad`, `IO`, `Directory`, `System`, `Time`, `Locale`, `CPUTime`, `Random`, in `share/rhc/haskell98/`, and what M17 left of chapters 12 to 19. The Report gives no code for `IO`'s handles, for `System` and `CPUTime`, or for much of `Directory`, `Time` and `Random` (`results/E9/report-libs/primitives.tsv`), so these go through primitives, those the Basis itself calls, with no SML below Haskell (D26's A). A primitive that needs the operating system goes behind `runtime/sys/sys.h` in every layer, and that is a change to Rune with a decision of its own; none is expected [inferred].
* **Starts from:** no patch. `results/E9/report-libs/`.
* **Rests on:** D36. Under another layout the 9 modules are the same, and only their imports change.
* **Done when:**
  - the 20 modules compile;
  - the 663 export pairs pass, table-driven (*The conformance table*);
  - the Report's 52 examples (`results/E9/report-libs/examples/`) are tests, as far as each is a program;
  - the bottom probes cover chapters 12 to 27's `run` rows that need them.
* **Touches:** `share/rhc/haskell98/`, `lib/language/haskell/`, `tests/hs/`.

### M19. Conformance: the table worked through (T; L, 3,781 rows of programs and about 1,500 lines of harness [estimate]; first rows with M11, the bulk after G1, on a frozen Prelude)

* **What:**
  - **The clause programs:** 1,379 accept, 548 reject and 1,854 run rows (E9), in `tests/hs/lang/`, `tests/hs/errors/` and `tests/hs/run/`, each citing its clause, and a reason in `how` for the 120 `none`. Export rows are table-driven and a program may name several ids, so there are fewer programs than rows.
  - **The corpus,** by E8's admission rules (*The suites*): the 188 in `check`, the 35 others nightly, `reject-unchecked` nightly.
  - **D56's tiers:** `quick`, `check`, `nightly`, `test-rhc-mutants`, with the run set in three ways in `check`.
  - **Bottom probes, sharing budgets** in `tests/hs/perf/*.budget`, labelled rhc's policy, **generators** and the reducer, **metamorphic relations,** and **rhc's mutants** in `tests/runner/hsmutants.sml`.
  - **`-lazy` ports:** rhc's output against `examples/benchmarks`' hand-written lazy SML.
  - **The first measurements on the run set** of *Decisions on the numbers*, once it compiles: D3's variant against B, D9's multi-value return against today's attacks on tuples, with `IO`-heavy programs named, D24's B and D against A, and D34's B against A at `-O0`, each for the owner to decide before G2.
* **On a frozen Prelude:** the saved world (D45's option B) until M21, then the store. Up to 3,781 programs, each carrying the 11-module unit's 14,965 tokens, is what a whole-program compile means, and D45's rough rate makes that a budget matter for `make check`. M20 and M21 run beside this milestone and do not gate it.
* **Starts from:** no patch. `results/E9/clauses.tsv`, `results/E8/*.tsv`, `results/E8/compat/`.
* **Rests on:** D52, D55, D56. D56 rests on K, which E5 gives from three programs and four kernels. What binds is the share of `make check`, not a count of programs: M19 measures K and the compile, and programs move to nightly by Rune's rule, with D56's 112 programs the next step down. If the owner drops D55, *The conformance table*'s warning stands: a full table does not show strong tests.
* **Done when:** every line of G2's table in *The gates' exits* passes.
* **Touches:** `tests/hs/`, `tests/runner/`, `Makefile`, `docs/testing.md`.

### M20. The store's policy out of `UnitCache` (S; S, about 60 lines [Y's estimate], optional; beside M19, on no milestone)

* **What:** build-system-v2's M6 and M7 built the store rhc needs, from E13's split: `lib/compiler/driver/unitstore.sml`, 746 lines at origin/master `697724da5`, with an `('h, 's) format` whose sections are hashed apart, a head the client defines and judges by `holds`, settings passed in, keys of several parts, layers, and eviction by age and size (D43, decided by the lead: B, as landed). What is left is optional: the store's location, `.rune` in the workspace, and its trim policy, a week and 4 GiB, sit in `driver/unitcache.sml` (`:223-275`, `:565-583` at origin/master), which names SML's modules. Moved where a client can call them without `UnitCache`, about 60 lines, rhc need not copy them. Under D41's C, `unitstore.sml` also moves from `frontend.build` into the Mid layer (M4).
* **Starts from:** origin/master. `patches/E13-1-store.patch` landed there through v2, in a more general form.
* **Rests on:** D43. Taken or not, rhc writes its own format, head, `holds`, key and settings; if it shares `.rune`, its entries and Rune's share one budget for trimming [inferred].
* **Gate:** bytes stay put and cache files too, and no budget moves: the test as M4's, with `make check-units`, `make test-incremental` and the REPL's incremental scenarios.
* **Done when:** the gate; `tests/lib/compiler/store.sml`, a client that is not a compiler, passes, and a test of the moved policy links no `UnitCache`.
* **Touches:** `lib/compiler/driver/{unitcache,unitstore}.sml`, `lib/compiler/frontend.build`, `docs/units.md`.

### M21. HsIface and rhc's driver (S; L, about 1,500 [estimate]; after M13, M17; beside M19)

* **What:**
  - `lib/language/haskell/hsiface.sml`: names, types, classes, instances and fixities by entity, and a section for unfoldings in the format from the start (D44). The Prelude's are written when M23 has something to put there, and a program's own later: 1.04 without them against 2.00 without the libraries' (E6).
  - **rhc's usages and fingerprints,** which hold the obligations H1 to H9 (*What a cache hit must satisfy*).
  - `src/rhc/driver.sml`: the loop over the graph through the store, with `--whole` as one flag. rhc is its own driver: it scans imports and takes SCCs itself, since `Deps` still refuses a cycle (`lib/compiler/driver/deps.sml:394` at origin/master `697724da5`), and drives `Pipeline`, `Link`, `UnitFile`, `UnitStore` and `UnitMemo`. Its main sets `UnitStore.stat` and `lstat` as `src/main/rune-main.sml:4-17` does, or no stat memo is kept. It uses none of `CompilerPlan`, `LibraryScope`, `LibraryIndex`, `CompilerPrelude` or `Workspace` [Y's reading].
  - **rhc's entries in the store (D43):** its own `('h, 's) format`, head, `holds`, key and settings over `UnitStore`, with no change to Rune.
  - **The Prelude snapshot:** the 11-module unit frozen through the store, with its key over every member (D45).
  - **rhc's identity** is its own `Config` (M8), which `scripts/gen-version.sh --config` writes over rhc's plan and closure (v2's M11), and it goes in the store's settings, so rhc's entries have a configuration of their own [inferred].
* **Starts from:** origin/master's `unitstore.sml` and `unitmemo.sml`, which is language-neutral but for `Config.identity` and the `Source.reading` hooks (Y); `patches/E13-2-toy.patch`, a toy language with no front end, `results/E13/toy/p5.sh`, a frozen 11-module unit with toy bodies, and `results/E13/model/model.sml`, 293 lines. The toy's bodies are Mid text and its numbers are toy ratios.
* **Rests on:** D43, D44, D45, as decided; D46 is not applicable. It comes after conformance has begun, so that HsIface is fixed once classes and instances have been shaken out (D45). If D44's Prelude unfoldings were dropped, E6's 2.00, on GHC's optimiser, would be the measure of what M23 loses.
* **Gate:** no change to Rune. Should M21 need one of the store, it is M20's gate.
* **Done when:**
  - each of H1 to H8 has a test that fails with its hole, E13's holes as mutants of the usages, and `results/E13/ghc/` as the two cases GHC shows; H9, which E13's model leaves out, has tests of its own;
  - a body edit compiles one module and leaves its identity unchanged; a type edit compiles its users; a new instance two imports away moves a default;
  - warm equals `--whole` over random edits, as a standing tier, with `unitsOne`'s comparison (`tests/runner/oracles.sml:626-693`);
  - hello compiles one module against the snapshot, with bytes equal from source as far as D45 allows;
  - the compile cost of a clause program is measured and recorded, which E13 could not do;
  - what the 11-module unit costs a program is measured: link size and start-up, which E13 left open.
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `rhc.build`, `tests/hs/`, `tests/runner/`, `docs/units.md`.

### M22. SCC keys (S; M, about 300 [estimate]; after M12, M21; before G2)

* **What:** a key and an identity over every member of an SCC, fingerprints by recursive group, and the unit's name in a usage (H8). User cycles have compiled whole since M13, and the Report's own layout since M17; this makes a cycle incremental.
* **Starts from:** `results/E13/toy/p3.sh`, `p5.sh`: a cycle's key, and a frozen 11-module unit with toy bodies. `UnitStore`'s keys take several parts at origin/master, which is what a key over every member needs (Y).
* **Rests on:** D30, D36. If D30 goes to refusal there is no key to write, chapter 5's rows on cycles become a deviation outside the rule, and D36 falls to the merged form. If D36 takes its fallback, M22 also compiles the Report's graph as one unit, frozen through the store, and then the literal and merged layouts must print the same on every run program. If D30 takes 5.7's signatures, forward links must be built first (M12).
* **Gate:** no change to Rune. One unit per SCC costs the store, `Link` and `UnitFile` nothing (E13).
* **Done when:**
  - a body edit in a cycle compiles that unit and no client; a split SCC recompiles clients once; a recursive type group hashes as one (`results/E13/toy/p3.out`).
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `tests/hs/`.

### M23. Core simplifier, known dictionaries (P; L, about 2,000 [estimate]; after G2)

* **What:** `lib/language/haskell/coresimplify.sml`: a Core simplifier with eta (D48), and known-dictionary resolution and specialisation first (D49), through `Pass.stage` with CoreLint after each pass and `Pass.spend` before each rewrite, and it writes the Prelude's unfoldings into the section M21 left for them.
  - **D49's C, with what Augustsson 1993 adds:** the specialiser clones local overloaded bindings too, since a specialised `sum` "is hardly an improvement" while its local `sum'` stays overloaded (§5.4); literal folding covers `fromRational` as well as `fromInteger` (§4.3); and fuel bounds it, since polymorphic recursion defeats specialisation (fig 9).
  - **For D48's measurement:** D, GHC's default eta, as an option of the simplifier, measured against C as *Decisions on the numbers* says, and landed only if the owner takes it. Under C the pedantic rule refuses GHC's state hack, an eta-expansion through `IO` (D25).
  - **D34's B measured again** after the simplifier, as its reopening asks. The comparison is `core/simplify.sml`, 2,090 lines with its inlining and specialisation, and no rate exists.
* **Why first in P:** E3's first step is the largest rhc can reach first, on GHC's simplifier and class-op rule with specialisation off: thunks -47%, bytes -38% in total, -26.2% and -17.7% for the median program. Those are GHC's figures, and that rung holds more than known dictionaries (D48). E5 gives Rune's.
* **Starts from:** no patch.
* **Rests on:** D47, D48, D49, as decided.
* **Done when:**
  - `-O0` against optimised agrees on stdout and on bottom or not, over every run program;
  - sharing budgets and bottom probes hold at every setting, both bytecodes;
  - every lint holds at any `--fuel`, and a bottom probe holds eta under `seq`, where a wrong rewrite is silent and no oracle helps (D48);
  - G2's lines are shown again at the new top level;
  - E3's ladder is measured on rhc, `--count` over the 188 before and after, with a program that rises listed and explained. E3's percentages are for comparison, not a target;
  - D48's measurement is taken and the owner's choice recorded in D48.
* **Touches:** `lib/language/haskell/`, `src/rhc/`, `tests/hs/`, `docs/ir.md`.

### M24. Strictness (P; M, about 800 [estimate]; after M23)

* **What:** `lib/language/haskell/corestrict.sml`: one backward analysis with signatures, which go in HsIface, and its result in Core's types, the evaluated and unevaluated distinction of D2. A strict parameter lowers to `T` and a lazy one to `susp T`, and Mid's `workers` then flattens tuples, so nothing changes in Rune (D50). With `IO` a state token in Core (D25), the analyser must not evaluate before an I/O action what the source evaluates after it. No rate exists; `core/workers.sml` is 492 lines.
* **Starts from:** no patch.
* **Rests on:** D50. E3 gives a further -20% of thunks and -11% of bytes, on GHC. It cannot be cut apart from M23 on `sum = foldl (+) 0` [inferred], so declining M23 declines most of this.
* **Done when:** as M23, with the bottom probes as the first line: a result that is too strict shows there and nowhere else; a mutant that marks a lazy argument strict is caught; a test holds the order of an `error` and an I/O action; E3's L2 step is measured on rhc.
* **Touches:** `lib/language/haskell/`, `tests/hs/`.

### M25. What measurement justifies: eval/apply, pointer code 11, selector thunks, CAF tables, cheap eagerness (P; not sized; after M24, each built on the register VM and measured, and landed only if the owner takes it)

* **What:** each of the first four is built here, on the register VM first, measured on rhc's own output as *Decisions on the numbers* says, and taken or closed by the owner on the figures.
  - **Eval/apply (D15's C, its measurement):** arity tested by the caller, a partial-application object, over-application by a pushed continuation, on the register VM, its interpreter and JIT, with `Low.Call`, MidLint's rule and `RegVerify`'s; on the stack VM, runeopt and native code only once taken. `CALL` takes one argument today (`src/isa/regs.sml:122-124`), so this is a change to Rune, measured on Rune's programs too.
  - **Pointer code 11 (D16's B):** set by the copier when it shortcuts an indirection, masked at every pointer read in C and in `masm.c`, measured on the register VM and on Rune's programs too; runeopt's templates and the stack VM only once taken.
  - **Selector thunks (D17's B):** Sparud's desugaring of pattern bindings and `~p` with an impure `updatePat`, whose write skips any sibling not unevaluated, so that D11's pin need not come here; if it must, the pin lands here and not in M26.
  - **CAF tables (D19's B):** a table per function of the CAFs its code reaches, emitted at or below Core to Mid, and a collector that traces from live code.
  - **Cheap eagerness (D51's C):** total operations only, on values Core's types say are evaluated; under D20's D an `Integer` add of two immediates, behind a test of the immediate bit. M25 also settles what stops `inline` copying a thunk held in a `Fun` group, if D3's C put thunks there.
* **Starts from:** no patch. E5's `results/E5/ncall/` and `stats.jsonl` for eval/apply; E2's `last` and `leak` for residency.
* **Rests on:** D15, D16, D17, D19, D51. Selector thunks and eval/apply are on the list of what is cut first.
* **Gate:** a build for measurement runs on the register VM, its interpreter and JIT, and is measured there against the standing gate before the owner decides. What the owner takes then gets the stack VM, runeopt and native code, and M9's list of checks, Windows and portability among them, before it lands, and states its budget; what is not taken does not land.
* **Done when:** each item is landed with its test or closed with its figures, and the owner's choice recorded in its decision; the sharing budget for what `inline` could copy passes in every case.
* **Touches:** as each decision says.

### M26. Ready for lazy ML (Z; size set by D57; after G2)

* **What:** the checklist D57 names, run again on form C, since E14 ran it on form G. Lazy ML's reading under C is E2's `CmX`, whose thunk does not say `BLACKHOLE` and releases nothing (`results/E2/delay/Cml/lazy.sml`):

  1. **The pin landed:** a `K_IND` a frame still runs is not shortcut (`gc_pin_running`), with `k_outlive*` and `outlive_nullary` on both engines. The guard on the shortcut, looking through forwarding, lands with it. M26's.
  2. **A MidLint rule:** a function given to `thunk_make` is named by nothing else, and `thunk_self_update` appears nowhere else. Haskell's too: M9.
  3. **The stack target lowers force.** Haskell's too: M9.
  4. **The spec's 10 programs green** over E14's mode table plus `--lint=3`, with raise, re-entry, effects, nesting, rule order and equality pinned. M26's, on E14's patch brought up to the landed tree.
  5. **Flag off:** bytes and `--count` unchanged, and `susp` unbound. M26's, on the same patch.
  6. **`susp` documented** and in `tests/ir`. Haskell's too: M9.

  So M26 itself holds items 1, 4 and 5: +24 -3 in the collector, `value.h` and the loader flag as E14 measured them on form G, with E2's guard, measured again on form C. No surface syntax lands in this roadmap. Whatever the checklist needs of Rune lands as tests, or as a change that keeps M9's gate. The pin's programs use `$`, so what stays in `make check` is them rewritten under `--allow-prim`, as E2's kernels are [inference, not built].
* **Starts from:** E14's drafts patch, on form G, brought to form C; it stays in the drafts.
* **Rests on:** D57. Lazy ML itself is a later roadmap, and this milestone says only that the stack is ready for it.
* **Gate:** bytes and budgets stay put, or the decision says by how much. E2 priced the guard on the collector's shortcut at +0.84% on Haskell's thunks and +0.90% on lazy ML's (`results/E2/tables/guard-cost.txt`). E14 priced the pin at 1.0003 over the guard on lazy ML's ports, 1.0036 before the shortcut's test was forced in line (`results/E14/tables/portcost-final.txt`, `portcost.txt`). It returns at once in a program that blackholes [read]. Both figures are form G's; M26 takes them again on form C.
* **Done when:** each line of the checklist is shown by a test in a named tier.
* **Touches:** as the checklist says; `docs/ir.md`, `tests/ir/`, `docs/plans/lazy-evaluation.md`.

### M27. Retire (no track; S; after G2 and what the owner keeps of P and Z)

* **What:**
  - the final measurements against *Measuring*: rhc's compile time and K, E2's ports on the landed form, E13's cases on real rhc;
  - **into `docs/`,** what the roadmap holds that stays true: a new `docs/rhc.md`, `docs/architecture.md`, `docs/ir.md`, `docs/testing.md`, `docs/units.md`, `docs/bytecode.md`;
  - *At the close*, as earlier roadmaps did, with the Status table finished;
  - the worktrees named there removed with the owner's word.

### M28. `Ty` with application and forall (A; L, 300 to 500 lines over 12 or more files [E4's estimate]; after M6, before M10)

* **What:** D4's C. `Ty.ty` gains variable-headed application and a forall in fields, which `core/ty.sml:27-33` has neither of. Each pass that reads types takes a rule for them: 96 `Ty.view` sites in 18 files, 82 ending in a catch-all (`results/E4/tyview.out`, a heuristic). `Ty.ty` is described at `tools/codecs/compiler.sml:168-176` (origin/master `697724da5`), so the forms go there and `make codecs` runs. `Any` stays for what `Ty` cannot say, and still means evaluated; the `any` casts, 0 to 2.2% of nodes at E5's step `D0` (E4), go where `Ty` can say the type. Value-to-`susp` casts stay (M9). MidLint refuses a type variable instantiated at `susp T`, as Strict Core has it; Launchbury and Paterson's `Pointed` is the alternative not taken (D4).
* **Starts from:** no patch. E4 sized it and built nothing.
* **Rests on:** D4, decided: C, "safest and also useful for higher-rank and higher-kinded type in rune".
* **Gate:** SML's front end makes neither form, so SML programs keep their bytes [deduced], shown by M4's test; the compiler's own compile is measured, and its budgets move only by what this milestone states. `make check-codecs`.
* **Done when:**
  - the gate, with the figures;
  - each new form round-trips through Mid's text and codec at level 3;
  - MidLint refuses each form ill-applied, and a type variable instantiated at `susp T`, each with its message in `tests/compiler/lint-rules.sml`;
  - E1's `monad`, written with the new forms in place of its `any` casts, passes the ways E1's did;
  - a scratch form added to `Ty.ty` draws "match is not exhaustive" at each site that M6 and this milestone left without a catch-all.
* **Touches:** the 18 files of `results/E4/tyview.out`, among them `lib/compiler/core/{ty,midlint,midtext,midcanon,simplify,workers,refs,expand}.sml` and `lib/compiler/backend/{lower,lowshapes,rep}.sml`; `tools/codecs/compiler.sml` and the generated regions of `core/midcodec.sml` and `driver/unitmid.sml`; `tests/ir/`, `tests/compiler/lint-rules.sml`, `docs/ir.md`.

### M29. Mid `Case` (A; L, not built or sized: an arm in at least 88 walkers, and Simplify's rounds [E12]; after M6, beside M28)

* **What:** D8's C. A `Case` in Mid's `exp`: a test of a constructor's tag with an arm for each and a default, whose arms may bind what `Decon` takes. `Lower` lowers it to the `SWITCH` and tests it makes today, so its own recovery of the table from `ConTag`, an equality primitive and `If` gives way, and the 96 lines of peephole in three places that must agree become one. The guard on `Decon` becomes a rule of MidLint. `MidText`, `UnitMid`, `MidCanon` and `Fault` take it, and the codec's description of `exp` (`tools/codecs/compiler.sml:222-232` at origin/master); Simplify's rounds learn it, which is where the risk is. Rune's front end emits it where it emits tag tests now [inference], and rhc's Core to Mid once it lands (M10).
* **Starts from:** no patch. E12: 12,061 of 12,064 tag tests are recovered, 472 of 484 chains become `SWITCH`, and only 31 tests are answered by a dominating test, so `Case` saves no code; it would save 11.7% of Mid's nodes, or 16.7% if arms bind [deduced] (D8).
* **Rests on:** D8, decided: C, now: "let's fix it now instead of later".
* **Gate:** bytes and budgets may move, since `Lower`'s own reconstruction gives way to the node. The milestone measures by how much, states it, and budgets move only by that. E12 deduced that no byte need move if `Lower` lowers `Case` as it lowers the tests now; no compile with a `Case` was made.
* **Done when:**
  - the gate, with the figures;
  - the compiler's own compile time is measured before and after, which E12 could not do;
  - a scratch arm left out of a walker draws "match is not exhaustive", or goes through M6's `fold`;
  - every `tests/ir` dump that shows a match is reviewed by hand.
* **Touches:** `lib/compiler/core/{mid,midtext,midcanon,midlint,simplify,workers,lift,refs,shake,expand,tomid}.sml`, `lib/compiler/backend/{lower,lowshapes,fault}.sml`, `lib/compiler/driver/unitmid.sml`, `tools/codecs/compiler.sml` and the generated codecs, `tests/ir/`, `docs/ir.md`.

### M30. Multi-value return, built to be measured (A; L if landed, not built or sized: 126 walkers and both instruction sets [E12]; the build after M6, on the register VM; landed only if the owner adopts it)

* **What:** D9's B, built for the owner's measurement (*Decisions on the numbers*). `Return` of several atoms and a `Let` of several variables in Mid; `Low.Return` of a list; `RET` and `RESULT` of several values in the register set, its interpreter and its JIT; and the codec's description of Mid. The stack set and the Stack target, runeopt's templates and native code, `tests/opt/every-opcode.rasm` and `docs/bytecode.md` come only if the owner adopts it, as its landing. It would retire `Slot`, the facts in `lowered` (`Pipeline` at `b12141ecc`, `MidPipeline` after M4) and `LowLint.results` (D9). On its branch rhc uses it for `IO`'s state and value (D25's B) and for products Core returns unboxed; on master those stay tuples, or the token is erased (M10, M17).
* **Starts from:** no patch. E12: in a whole compile it wins what `results` already wins; in units, where `results` does not run (`backend/lower.sml:849`), about 4.4% of the compiler's allocation [deduced], and nothing in instructions.
* **Rests on:** D9, to be measured: the owner's answer of 2026-11-10, "land behind a measurement", which supersedes the B of 2026-11-09. If the owner keeps A, nothing of this lands, and the four attacks on tuples stay as they are.
* **Gate:** while it is measured, none on master, since the build is a branch; its figures are taken against the standing gate on the register target. Whether SML's code changes depends on whether `Lower` uses it for SML's products, which the build decides and states. If adopted: both instruction sets' fingerprints and opcode tables move, and every `.rbc` with them; budgets move only by what the figures say; M9's list of checks for a change to the engines applies.
* **Done when:**
  - the measurement of *Decisions on the numbers* is taken and the owner's choice recorded in D9;
  - if adopted: the gate, with the figures; a function returning two values makes no tuple, by `--count`, on both bytecodes and in native code; each new form of `RET` and `RESULT` has its line in `tests/opt/every-opcode.rasm`.
* **Touches:** for the measurement, Mid's and Low's walkers, `lib/compiler/backend/{low,lower,lowlint,regs,regverify}.sml`, `lib/compiler/driver/midpipeline.sml`, `src/isa/regs.sml` and what `make isa` writes, `runtime/register/`, `tools/codecs/compiler.sml`, `tests/ir/`, `docs/ir.md`; if adopted, `lib/compiler/backend/stack.sml`, `src/isa/stack.sml`, `runtime/stack/`, `runtime/native/`, `src/opt/`, `tests/opt/every-opcode.rasm`, `docs/bytecode.md`.

### M31. `IntInf` immediate (A; M, not sized: `lib/basis/intinf.sml` is 651 lines, and E5's ten primitives are +70 -2 with no bignum path; at once, before M17)

* **What:** D20's D. `IntInf.int` takes the immediate representation: a small value an immediate `int`, a big one `IntInf`'s signed magnitudes, with C's primitives in line, `integer_add` and the others compiled as `int_add` is (`runtime/register/fastprim.h:136`), each with a slow path of its own. **The bignum path is built first,** since nothing yet shows the small path keeps its 24 instructions an add with one behind it (E5). The hosts compile `lib/basis` in the `xc1` configurations with the VM's primitives written on their own library, so each new primitive has a host version in `tests/basis/host/rune-prim.sml` (`docs/basis-compat.md`). `docs/plans/heap-layout.md:4999` then becomes true. rhc's `Integer` shares the representation and the small path (M17, D26).
* **Starts from:** `patches/E5-integer-prims.patch`, ten primitives whose slow paths are a fatal, and `results/E5/core/rts-i1.mid`.
* **Rests on:** D20, decided: D, "rune should benefit from this".
* **Gate:** `IntInf` changes representation, so SML programs that use it change in bytes and counts, the compiler among them, whose constants are `IntInf` [deduced], and the primitives move both fingerprints. The milestone states by how much on `tests/perf` and the bootstrap, and budgets move only by that. `make matrix-quick`, `make test-basis`, `make check-cross`.
* **Done when:**
  - the gate, with the figures;
  - `IntInf` agrees with the hosts' on both paths and across the small range's edges, in `tests/basis` and under `xc1`;
  - E5's loop of 10^7 adds over small values stays at 24 instructions an add with the bignum path in place (`results/E5/intinf/run.out`), or the rise is stated;
  - `INTINF_DEFAULT_BITS` still bounds a big value.
* **Touches:** `lib/basis/intinf.sml`, `src/isa/prims.sml` and what `make isa` writes, `runtime/prims.c`, `runtime/register/fastprim.h`, `runtime/register/jit/emit.c`, `tests/basis/host/rune-prim.sml`, `tests/basis/`, `docs/bytecode.md`, `docs/plans/heap-layout.md`.

## Gates

**G0: the owner's decisions. Passed on 2026-11-09.** The owner decided D1 to D57, among them D1 to D6, D11 to D13 and D36: the hook, Core, Mid's laziness surface, the evaluated invariant, recursive values, the thunk and the library layout, on which tracks B, F and L stand. What it leaves open is measured, and decided by the owner on the figures: *Decisions on the numbers*.

**G1: hello.** The Report's Prelude, in the Report's layout, runs hello on the Core interpreter and on the VM, with identical output. *The gates' exits* gives the check, and what it does not show. It needs M8 to M10, M11 to M15 and M17, and it opens M20, M21 and the bulk of M19.

**G2: the Report.** Conformance holds when every line of G2's table in *The gates' exits* passes: every normative clause has a test or a pinned deviation; `conformance98` is green or each failure a recorded reading; the clean nofib programs match at `-O0` and at the top level, 19 of them through D22's compat `hash`; the Prelude's diff from the Report is empty but for the listed overlay; HsLint, CoreLint and MidLint are clean at level 2; rhc's mutants are caught; and all of it holds on both bytecodes, every tier and gc-stress. M19 and M22 stand behind it. Recursive modules are in this exit, since chapter 5's rows are in the table. At G2 the top level is Mid's passes, as track P comes after, and M23 shows these lines again at its own. Sharing budgets, generators and bottom probes are tests from their milestones on, and no line of this exit.

**The standing gate.** After any change to Rune, SML budgets and bootstrap bytes stay put unless a decision says otherwise, and that decision says by how much. Where a prototype here moved nothing, the milestone must show the same.
- **SML budgets** are `tests/perf/*.budget` under `make perf-check`, counted at level 0 (`docs/testing.md:95-96`). None is re-based to let a change of this roadmap pass unless a decision says so, with the figure.
- **Bootstrap bytes:** `make bootstrap` and `make check-cross`, and, for a change that means to leave the compiler's output alone, E11's test: the edited compiler on the sources before the edit gives that tree's `bin/rune.rbc`, at stack, `-O0` and `-O2`, on both targets. A compiler's own image differs once its sources do, so a plain comparison of images says nothing.
- **What moved in the prototypes:** E11's patches and E13's split moved no byte. E1's Simplify fixes moved no byte of the compiler. E2 is the exception, since it was never run against this gate: M9 is where its bytes are shown. Its primitives and form C's instructions move the fingerprint word and the compiler's own budgets, which D3 states.
- **What the owner's decisions move:** form C's instructions, both opcode tables (M9); `IntInf`'s representation, SML's programs that use it and the compiler (M31); `Case`, SML's compiled code by `Lower`'s change (M29); `Ty`'s forms, the compiler's own code (M28). M6's walkers should hold bytes. Each of these milestones measures what moved and says by how much, and that is the only room the gate gives it. What is built only to be measured moves nothing on master unless the owner adopts it; multi-value return would then move both instruction sets and perhaps SML's code (M30).
- **Rune's own rules apply on top,** by what a change touches: `AGENTS.md` for `src/isa`, `runtime/register`, native code and a pass of the compiler. rhc's own code under `lib/language/haskell`, `src/rhc` and `share/rhc` is not under this gate, and any later change a milestone finds it needs in Rune is a decision graded as the brief asks, never a silent edit.

## Decisions on the numbers

The owner took nine decisions on measurement: build the option, measure it, and decide on the figures; eight on 2026-11-09, and D9 on 2026-11-10. Until then the option the owner kept, or the recommended one, stands. This section says, for each, what is built, against what, on what, in which milestone, what figures the owner sees, and who decides.

**What every one shares.**
- **Built on the register VM first.** The owner's rule of 2026-11-10 (*The request*): what is measured is built on the register VM only, its interpreter and JIT tiers, and the rest only after the owner adopts it. That holds for D9, D15, D16, D17 and D19, and for D3's variant, D24's B and D, D34's B and D48's D as far as they touch a VM. What is on the compiler's side, D3's `Force` right-hand side, D24's B in rhc's runtime, D34's trees and D48's eta, is built for and measured on the register target. The stack VM and the Stack target, runeopt's templates and native code, `tests/opt/every-opcode.rasm`, and the sanitizers, stress, Windows and portability rules for a change to `runtime/register` (`AGENTS.md:168-170`) come only with adoption, as part of landing it. A build for measurement is a branch, so the rule that each commit leaves `make check` green applies when it lands.
- **What "register VM only" leaves out.** Shared runtime that an option needs changes with it: pointer code 11 is set by the copier and read through `runtime/value.h`, and a CAF table is the collector's. On a measurement branch the stack VM, runeopt, the other machines and Windows are neither extended nor run, and nothing claims they work; once the owner adopts an option, its milestone brings them to parity and runs them.
- **On what.** rhc's programs: E5's hand-lowered set, `queens`, `primes` and `exp3_8` and the kernels `sum`, `sumint`, `list` and `showk` (`results/E5/`), until rhc runs; then D56's run set, the 223 run programs, the 188 of `make check` and the 35 nightly. Rune's programs where the owner said "and rune if that applies": D15 and D16, and D17 where it applies; and D9, whose gain E12 found in Rune's compiler. Rune's programs are E2's 113 lazy ports and 12 strict ports, `tests/perf`'s budgeted programs and the compiler's own compile.
- **What the owner sees.** Instructions at tier 2, `instructions:u`, and `runevm --count`, which are the claims (*Measuring*); per program, with totals, geomeans and medians, and every program that moves the wrong way named. Cycles, best of N with the load stated, where E1's and E2's lessons say instructions mislead: on the ports G ran 13% more bytecodes than C for 5% more machine instructions, so `--count` overstates a gap there; and E5's K is 3.4 to 5.2 in instructions against 5.8 to 7.0 in cycles on the whole programs (`results/E5/k.txt`). D16 is such a case.
- **Who decides:** the owner, on the figures. Each decision records the choice at its end.

**D3: C, a `Force` right-hand side, against B with form C.**
- *Built:* a fifteenth `rhs`, `Force`, lowered to the same instructions as B's `thunk_force`, with D6's C for recursive thunks, a recursive form in Mid; on M6's walkers, and described in `tools/codecs/compiler.sml`. M9 builds it on a branch beside the landed B, for the register target; the Stack target lowers it only once it is taken.
- *On:* E5's set, lowered by hand to both, in M9; then the run set, with M10 emitting either, in M19.
- *Figures:* instructions at tier 2 and `--count`, at Rune `-O0` and `-O2`; the compiler's own compile time and bytes, since SML pays an arm in every walker; and whether any pass drops, copies or moves a force under either, with the sharing budget of D51.
- *Measured, decided (2026-11-10):* B, as landed; C gives the same bytecode on every program measured (D3's section).

**D9: B, multi-value return, against A, today's four attacks on tuples.**
- *Built:* `Return` of several atoms and a `Let` of several variables in Mid, `Low.Return` of a list, and `RET` and `RESULT` of several values in the register set, its interpreter and JIT; in M30, after M6, on a branch. The build says whether `Lower` uses it for SML's products. The stack set, runeopt and native code take it only once adopted.
- *Against:* A, the four attacks as they stand on the same tree: virtual tuples and fields, `Workers`, `flattenJoin` and results in globals. E12's figures with each turned off are the scale (*The IRs, reviewed*).
- *On:* Rune's compiler compiling itself, as a whole compile and as a unit build, since E12 found B's gain only in units, where `results` does not run (`backend/lower.sml:849`); Rune's benchmarks, `tests/perf`'s budgeted programs and the 17 numerical benchmarks E12 ran (`results/E12/bench-summary.tsv`); and rhc's programs, since D25's state token returns a pair with every action: E5's hand-lowered set, which erases `IO`, until rhc runs, then the run set in M19 with `IO`-heavy programs named.
- *Figures:* instructions at tier 2, `--count` and bytes allocated, per program, in a whole compile and in units. E12's figure for units, about 4.4% of the compiler's allocation and nothing in instructions, is deduced from the whole-program figures; this measures it.
- *Who:* the owner. If B is taken, M30 lands with the stack set, runeopt and native code, and D25's pair goes through it.
- *Measured, decided (2026-11-10):* A; M30 does not land (D9's section).

**D15: C, eval/apply proper, against A.**
- *Built:* arity tested by the caller, a partial-application object, over-application by a pushed continuation, on the register VM, its interpreter and JIT, with `Low.Call`, MidLint's rule and `RegVerify`'s; in M25. The stack VM, runeopt and native code take it only once adopted.
- *On:* the run set at `-O0` and at the top level after M23 and M24; and Rune's programs, since SML's curried calls take the same `CALL` (D15).
- *Figures:* instructions at tier 2 and `--count`; chains of two or more arguments and partial applications made, as E5 counted them (`results/E5/stats.jsonl`); bytes allocated. E5 priced a curried call at 116 instructions and 24 bytes against a known call's 43, and guessed an n-ary path at about 55 [N's inference].

**D16: B, pointer code 11, against A.**
- *Built:* the code set by the copier when it shortcuts an indirection, and masked at every pointer read in C and in `masm.c`, on the register VM; in M25. The stack VM and runeopt's templates take it only once adopted.
- *On:* the run set, and Rune's programs, since every pointer read moves.
- *Figures:* instructions at tier 2 and `--count`, and cycles and cache misses, best of N. Code 11 can save only the header load: Rune's `FORCE` has no indirect enter jump for it to spare, unlike GHC's, where Nethercote 2002 §5.4 proposes the bit, unmeasured. On heap-layout's kernels the code was within noise (D16).
- *Measured, decided (2026-11-10):* A; B costs 4.5% to 12% at tier 2 everywhere measured (D16's section).

**D17: B, Sparud's method, against A.**
- *Built:* pattern bindings and `~p` desugared to Sparud's tuple form with selectors, his equation (8), plus an impure `updatePat` that overwrites each sibling. It is a desugaring and a primitive, not a Core construct (Sparud 1993, §3.3). Under form C the write skips any sibling that is not unevaluated, and is not a `K_IND` to an unevaluated component: it retargets the sibling's code and capture, or is made only when the component is evaluated. Otherwise the sibling whose force ran the match outlives its own update, E14's case, and D11's pin becomes Haskell's and lands with B, not in M26 [P1's inference]. B changes D34's desugaring. In M25.
- *On:* the run set, and programs over `lines`, `span`, `break` and `unzip` on long input, with E2's `last` and `leak` as residency tests at two sizes, the form M10 set. On Rune it applies only through a lazy pattern binding, which SML has not; lazy ML's would be one, and this roadmap does not land it, so Rune's figure is that nothing moves [inference].
- *Figures:* residency, peak and byte-seconds, as Runciman and Wakeling gave for clausify, 47,548 to 34,083 byte-seconds; bytes allocated; and instructions at tier 2, since Sparud says a program that does not leak runs "somewhat slower".

**D19: B, CAF tables, against A.**
- *Built:* a table per function of the CAFs its code reaches, emitted at or below Core to Mid, and a collector that traces from live code; in M25.
- *On:* the run set, with the programs whose residency is a CAF named.
- *Figures:* residency and peak RSS; the collector's time; instructions at tier 2; and the bytes promoted that die in the old generation. Rune's nursery promotes every survivor of a minor collection (`runtime/gc/minor.c:1-7`), and Röjemo 1995b measured that policy on sieve at "nearly ten times" the two-space collector's time (§5.1, p 155).

**D24: B and D, against A, for the record.**
- *Built:* B, the whole list on first force, a loop in rhc's runtime; D, a primitive that unpacks a constant, as nhc98's `STRING`, a change to `src/isa` that moves the fingerprint, built on the register VM alone and kept as a patch; both in M17. The other engines take D only if it is adopted.
- *On:* the run set, in M19, with string-heavy programs named.
- *Figures:* instructions at tier 2, `--count` and bytes allocated.
- *Who:* the owner, who said D is unlikely to be taken whatever it shows, "as there is no use in rune". D conforms as B does; what taking it needs is the owner's word for a change to Rune that Rune does not use.

**D34: B, Sestoft-order decision trees, against A.**
- *Built:* an option of M15's match compiler, off at `-O0` and differenced against it.
- *On:* the run set at `-O0` in M19, and again after M23's simplifier, with match-heavy programs named.
- *Figures:* VM instructions at tier 2 and `--count`, not code size: Pettersson 1992's automaton gave no reduction in size. Compile time too.

**D48: D, GHC's default eta, against C.**
- *Built:* an option of M23's simplifier, eta through `case` as GHC's default has it; in M23.
- *On:* the run set at M23's top level, with `IO`-heavy programs among them, since under D25's state token GHC's state hack is an eta-expansion through `IO` that C refuses.
- *Figures:* instructions at tier 2 and `--count`; per program, the expansions D makes and C refuses; and D55's bottom probe run on D, which C passes and D is expected to fail on `(f bot) seq 1`. Gill 1996's arity analysis gave 0.99 of instructions by geomean on 52 nofib programs, mostly after foldr/build, which rhc refuses, so D's margin over C should be about 1% or less [P3's inference].
- *Who:* the owner. D is not conforming, so taking it would need a deviation that D38's rule does not cover, or the owner's word.

## Testing and conformance

The brief asks for "a large test suite (accept/reject and all the other goodness we have for rune)", "an independent type checking lint pass as for sml 97", "ast pretty printer to check round tripping" and a corpus. Rune's machinery covers much of that. What it cannot lend is an authority. The Definition has rule numbers, HaMLet and a defects list; the Report has prose, and no semantics of sharing, and its implementations disagree hard on 20 of 82 tests (E7). No published Haskell conformance suite was found (E15). So the design rests on several independent sources of evidence, each of which fails in a different way: a clause table, oracles that find disagreements, a lint with a second inference, round trips, self-oracles, bottom probes, generators and mutants. Path names under `tests/hs/` are proposals; everything else cites `b12141ecc`.

### What Rune has, and what must be generalised

A family of tests is a `Test.tree` of `Run.command`s, each with a `judge`, registered in `tests/runner/main.sml:147-148`, its source listed in `RUNNER_SRCS` (`Makefile:2032`). `bin/rune-test` is a wrapper that sets `RUNE_LINT=2` (`Makefile:2050-2051`). `make check` is `check-tools` and then `--tier check` (`Makefile:2139-2140`). Programs are found by scanning directories. A tier or profile is a tag, and `covers:GLOB` serves `--affected` (`docs/testing.md:141-172`).

**Reused unchanged:**
- `lib/test/runner`, `lib/test/unit`, `lib/test/property`.
- `Expectations`, with its strict, lenient, skip and quarantine meanings (`lib/test/runner/expectations.sml:10-14`, `docs/testing.md:322-331`).
- `Pass.stage` and `Pass.checkAt` (`util/pass.sml:167,215`) and the levels of lint (`util/pass.sml:20-32`).
- The lints from Mid down, and `runevm --count` (`runtime/runtime.c:421`; `docs/testing.md:434` gives a stale line).

**Generalised (M2).** Each of these is bound to SML by a path or a suffix. The judges and comparisons themselves are language-free.

| What | Where | Bound to | rhc needs |
|---|---|---|---|
| `Lang.programs`, `compile`, `error`, `typecheck`, `run` | `tests/runner/lang.sml:62-78,186-245` | `.sml`, `tests/lang`, `tests/errors` (`tests/runner/lang.sml:67,189,197,205`) | A record of root, suffixes (`.hs`, `.lhs`), compilers and ways. A program may be a directory with a `Main`: E8 has 38 and 73 multi-module nofib programs, and 22 and 30 literate |
| `LangChecks` | `tests/runner/langchecks.sml:37,55,87,121,126` | paths | The root passed in |
| `Lang.ways` | `tests/runner/lang.sml:104-167` | kept | A chosen subset: *Budgets and tiers* |
| `DocChecks.features` | `tests/runner/docchecks.sml:12-92` | `docs/language.md`, `tests/lang`, `tests/basis` | The same two-way rule over a table: below |
| `Oracles` | `tests/runner/oracles.sml:52,94-98,412` | `bin/rune`, `tests/lang`, `tests/perf` | The compile command and the programs passed in. The comparing half needs only bytecode |
| `ExternalChecks` | `tests/runner/externalchecks.sml:25,31-32` | `tests/external/mlton-skip.txt`, `.sml`, `.ok` | A corpus's manifest, shims and skip file |
| `CompilerMutants` | `tests/runner/compilermutants.sml:68,70-122,254-273` | its corpus, the bootstrap | *rhc's mutants* |
| `broadInputs` | `tests/runner/main.sml:145-146` | every test | Stays. rhc's tree adds its own `covers:` for `lib/language/haskell/*`, `src/rhc/*`, `share/rhc/*`, so that a change there does not select Rune's suite |

The condition on M2: Rune's inventory is unchanged, the same jobs under the same names, which `bin/rune-test list` shows.

**Not reusable, though the pattern transfers:** AstLint, `SourceTy` and the `Witness` code; `functorgen.sml`; the laws, the Basis matrix, flexrec and overloading.

**New to the tree:** a round trip. `Ast.decToString` (`frontend/ast.sml:381`, behind `--dump-ast`, `src/driver/options.sml:287`) is a debug printer that no test uses and nothing reparses. The only round trip in Rune is Mid's text (`driver/pipeline.sml:29,121`). The oracle harness, bottom probes, sharing budgets and the program generator are new too.

The rest of Rune's goodness carries by being generic: `.expected`, `.cargs`, `.args`, `.stdin`, `.exitcode` and `.cwarn` siblings (`tests/runner/lang.sml:8-11`); `--accept`, read line by line (`docs/testing.md:429-431`); every program judged again by `--typecheck-only`, which must agree with the compile (`tests/runner/lang.sml:203-206`, `tests/runner/langchecks.sml:85-118`). rhc has a `--typecheck-only` for that reason. Core tests take `tests/ir`'s form, a `dump:` or `fail:` marker on the first line (`tests/runner/tools.sml:27-44`), with `--read-core` as `--read-mid` is there.

### The conformance table (D53, M1)

`DocChecks.features` keeps `docs/language.md` honest, in both directions:
- An id is lower-case letters, digits and dots (`tests/runner/docchecks.sml:21-22`).
- Every Supported or Partial id has a test named `ID_...` (`tests/runner/docchecks.sml:30-35`).
- No id occurs twice (`tests/runner/docchecks.sml:36`).
- Every test's prefix is a Supported or Partial id (`tests/runner/docchecks.sml:37-43`).
- Every test has its `.expected` (`tests/runner/docchecks.sml:69-70`).

By that rule `docs/language.md` has 200 rows. E9's clause matrix has 3,901 and every id obeys the rule (recounted from `results/E9/clauses.tsv`). A table 20 times the size is not kept by hand in Markdown, so D53 makes it a TSV: `tests/hs/conformance.tsv`, read with the header and duplicate checks `DocChecks.tsv` already has (`tests/runner/docchecks.sml:93-102`).

**Columns.** E9's `id`, `section`, `statement`, `class`, `test`, `how`, `source`, and three more: `status` (`Supported`, `Partial` or `Planned`, the words of `docs/language.md:10-13`), `reading` (an R number or empty) and `deviation` (empty, or a pointer to its pin).

**Enforcement, by id, each direction a failure:**
1. A row whose `test` is `accept`, `reject` or `run`, not `Planned`, has a program in the suite of that class whose id is the row's.
2. A program's id is a row's. A program with no row fails, as it does today.
3. A row whose `test` is `none`, 120 of them, has a reason in `how`.
4. A row with a `reading` has a program that pins the reading chosen, and a deviation has its note, in both directions as `DocChecks.notes` does for the Basis (`tests/runner/docchecks.sml:166-199`).
5. The table's `reject` rows hold a program in `tests/hs/errors`, whose `.expected` pins rhc's own message, so that a program refused for the wrong reason does not pass (`tests/runner/langchecks.sml:50-72`).

**One extension of the rule.** A file name carries one id, and 1,253 rows are generated: 163 productions, and the Prelude's and libraries' definitions, methods and exports. One program may cover many of those. So a program may name further ids on its first line, as `tests/ir` puts a marker there. Export rows can be table-driven from the Report's export lists: E16 lists 663 export pairs in its 20 modules (`results/E16/check_merge.txt`). A definition's `run` row needs a program.

**Status of the rows.** `test` classes are first readings: read from the text, not run, with 12 rows sampled by eye (E9). M1 lands the table with every row `Planned`, and M19 works through it. A row leaves `Planned` when its program exists and the judges have seen it. G2 is the state in which no row is `Planned`.

**Which text.** Rows follow D38: the December 2002 text plus the published errata, all listed. E9's rows were built from the unamended text, so the errata that change a clause change a row.

**The generator.** `runner/migration-inventory` requires an owner for every live `.sh`, `.py` and `.awk` file (`tests/runner/migration.sml:2,10`; `docs/testing.md:217-219`), so `build_clauses.py` does not land as it stands. The Report is fixed, so the table lands as data, and only errata and readings edit it. If it must be regenerated later, the generator is a `tools/generate` command in SML.

A full table does not show that the tests are strong: Yang et al. saw coverage metrics barely move while bugs were found (*What the literature says*). Mutants and generators answer that.

### The suites: accept, reject and run

Two sources feed each suite: clause programs written for the table, which are the conformance evidence, and the corpus, which is breadth and scale. E8's programs are not keyed to clauses. Counts are rows of `results/E8/accept.tsv`, `reject.tsv` and `run.tsv`; distinct counts hash the main file, and are recounted here.

| Suite | Clause programs (E9) | Corpus (E8) |
|---|---:|---|
| Accept | 1,379 rows | 1,441 accepted by some oracle. 928 by both judges, 807 distinct, of which 815 rows need nothing. 849 by all three. 326 by one judge, 187 by neither |
| Reject | 548 rows | 931 illegal, 825 distinct, 857 resting on a static error. 365 `extension`. 352 `unjudged` |
| Run | 1,854 rows | 283 with inputs and expected output. 223 right under `ghc -O0`, 123 right on all three oracles |

**Sources, by E8's sets.**
- **`nhc98/tests/nofib`** is the best large corpus: 71 of 77 accepted, 59 by all three, 60,234 lines. **The 2019 nofib** adds 30 as it stands or by rewrite and 76 through a 144-line compat layer: 106 of 131 sequential programs, 81,011 lines.
- **`conformance98`** and yhc's extras are the nearest thing to a conformance suite, and only that: "far from comprehensive" in its own README (`nhc98/tests/README:1`), and E7 finds that 16 of the 48 disagreements on it and yhc's extras are not Haskell 98.
- **GHC's legacy tests, jhc, UHC** give the bulk of small accept and reject programs: 244, 173 and 53 accepted by all three.
- **helium** is rich in rejects, and its verdicts need rechecking: all three oracles accept 34 of its 431 expected rejections, and two accept 28.
- **The Report** gives 52 examples from its running text (`results/E9/report-libs/examples/`).

**Admission.**
- A corpus program enters **accept** when both judges accept it and it needs nothing, a rewrite or the compat layer. A split between judges goes to the oracle policy below.
- It enters **reject** only with a clause cited. No reject row has been checked against the Report (E8), and 240 candidates that a suite expected to fail are accepted by an oracle, 49 of them by both judges. Until a row is cited it runs nightly as `reject-unchecked`, judged on refusal alone.
- `extension` rows must be refused, which keeps rhc from growing a silent extension. They cite the grammar, sit in `reject-unchecked`, and say nothing of conformance. `unjudged` rows are out until their cause is known.
- **Run** expectations are recorded behaviour: nofib's standard is "version 1.2 or greater", seven years before the Report (E15). An expected output cites a clause where it is a clause test. For a corpus program it is a regression baseline, checked against the judges at import, and its float digits are compared with E8's tolerance.
- nhc98's `hmakerr` files record nhc98 (E7), and carry no weight.

**The corpus's home.** E8 did not survey licences. The repository is CC0, which cannot cover these programs, as E9 found for the Report's libraries. The precedents are `rune-corpus-sml97`, pinned recipes in a repository of its own, and `ExternalChecks`, whose first line says "Source trees are inputs, kept outside Rune" (`tests/runner/externalchecks.sml:1`), and neither is in `make check`. That fits everything but the part of the run set D56 puts in `make check`. Either those programs are vendored under `tests/hs/corpus/` with their licences, after a survey, as `share/rhc/haskell98/LICENSE` does for the libraries (D37); or the job carries `Test.requires` (`lib/test/unit/test_sig.sml:52-54`) but `AGENTS.md` makes a skip an error in `make check`, so that needs the corpus on every machine, or a weaker `make check`. The survey is M3's first task.

### Oracle policy and evidence without an authority (D52, M3)

**The rule.** Oracles find disagreements, not truth. GHC 9.4.7 with the strict shim and Hugs `+98` are the judges, nhc98 `-98` third, MicroHs a smoke oracle. Every expected result cites a clause. When the judges agree with the clause, that is a test. When they disagree, or agree against the clause, that yields a reading, and rhc follows the Report (D38). A majority decides nothing: E15 records majority verdicts on `let` fixity and NondecreasingIndentation that are wrong by the Report's letter.

**Why two judges and a third.** Neither judge is enough alone. nhc98 accepts 121 of 721 expected-fail candidates, Hugs 32, GHC 11 (E8), so nhc98 cannot judge rejections. GHC refuses what Hugs accepts on 210 programs with no expected failure, for its own reasons (E8). Hugs alone refuses 30 corpus programs; those O read were the top-level restriction resolved early, and the rest are [inferred] (E7, E8).

**Where an oracle is known not to be one:**

| Matter | Oracle | Why | Source |
|---|---|---|---|
| Layout | GHC `-XHaskell98` | Enables NondecreasingIndentation: run with `-XNoNondecreasingIndentation` | R3, E10 |
| Spacing of `@`, `~`, `!` | GHC 9.4.7 | Refuses `p@ Zero`, reads `(!1)` as a bang in every mode | E7, E10 |
| Record `Show` | all three | Three behaviours, on text a program prints | R41 |
| `Show Float` at a precedence | all three | All depart from the Report's code the same way | R42 |
| `3 * -4`, `xs !! -1` | split | GHC refuses, Hugs and nhc98 accept | R10 |
| Top-level Rule 2 | Hugs | Resolves early | R20, E7 |
| Hugs's floating `show` | Hugs | Not the Report's `showFloat` form | E7 |
| Recursive modules | all | Below | E8 |

**The 20 hard cases.** E7 lists them, with each oracle's position. Two are nhc98 refusing legal code, and need no reading. Eleven rows map to R10, R20, R22, R32, R34, R41 and R43. Seven rows, six programs, have no reading yet: Hugs's floating digits and `do a == b`. Under D52 each yields one in M3, before its row leaves `Planned`.

**The harness.** The judges run nightly, by capability, as hosts do: `Test.requires` over probes in `Inventory.capabilities` (`tests/runner/main.sml:77`), with the recipes of `results/E7/build-oracles.sh`, `build-nhc98.sh` written up as doctor hints. Their disagreements are lines in the one format, `tests/hs/oracles.txt`: `hugs | conformance98/fields/showread | SPEC-AMBIGUOUS | R41`, or `HOST-BUG` for an oracle's fault. Those categories are strict: a line that no longer matches a failure is stale and fails (`docs/testing.md:328`), so a new oracle build cannot silently change the evidence.

**What is held still.** Differencing needs one meaning per program (Yang et al.). The implementation-defined items are `Int` width, `Float`, exit status, `show` spacing and exception text. So generated and differenced programs avoid them, and compare "bottom or not", not which bottom.

**Recursive modules have no oracle.** No candidate of 3,089 has a plain import cycle. Of the 7 `{-# SOURCE #-}` tests GHC accepts only `rn017`, Hugs refuses a recursive import and nhc98 accepts none (E8). Chapter 5 is plain: "Modules may be mutually recursive." So the evidence is built:
- **The Report's own conversion.** Chapter 5 says "A multi-module Haskell program can be converted into a single-module program", by unique names and concatenation, with two exceptions, `default` and Rule 2. So each hand-written cycle has a joined form the judges can run, and rhc's output on the cycle must equal theirs on the join. The two exceptions are exactly where D30 needs a rule of rhc's for `default` and holds Rule 2 to each module's end, and those programs cite D30. This is an inference from the text, not a tested harness.
- **Names.** E16's fixtures: a user module that gives two fixpoints (`results/E16/tests/imp`), a renamed one that gives one (`gfp`), a solver that answers no (`cyc`), a hidden module refused (`hidden`). Expected: the least fixpoint.
- **What cannot be split.** The three signed, mutually dependent modules boot files cannot express (`results/E15/run/boot3/`), a user cycle with unsigned bindings, which needs the joined SCC (E16's addendum), a type group and kind inference across modules (R28), fixity and instances across a cycle.
- **The libraries.** The literal layout compiled as one unit is the largest cycle to hand, and every run program goes through it (D36). Its exports, fixities and instances are checked against E16's table. `merge.py`'s form stays in the drafts, so the two can be compared once by hand on the run programs; that comparison does not land.

Every one of these cites a clause of chapter 5 or a rule of rhc's, and none has an independent check of its expected result. The table says so in `how`.

### Round trips (D28, M2, M11)

Two tests on every file the parser accepts (E10), at `make check`:
- **Tree:** parse, print, parse, compare with locations erased. `haskell-src-exts/tests/Runner.hs` has this shape.
- **Token:** the tokens of the print equal `L` of the source, modulo empty items and a trailing comma.

**Why the token test is needed.** A parser mutant that drops something from the tree prints without it, and the reparse agrees with itself. E10's mutants show it: dropping `where`, a signature's context, `deriving`, a precedence or `~` passes the tree test on every one of 1,616 files, and fails the token test on 743, 227, 184, 91 and 9. Without the token test an AST drop is invisible.

**What neither test sees.** A compensating swap in both parser and printer passes both (E10). Only running programs catch it, which is why these are two checks among many.

Tree shape is checked only by an outside dump: GHC's `-ddump-parsed` of the printed explicit-brace form against that of the source, on 1,624 files in E10. It stays, nightly, under the judges' capability, with E10's 47 known differences as expectations. The printer has its own traps: `\~`, `@~` and `~~` lex as operators, which the round trip caught on a jhc test (E10).

Core's text is a contract (D2), so it has the round trip Mid has: read back after every stage at level 3, as `Pipeline.roundTrip` does (`driver/pipeline.sml:29`).

### HsLint and CoreLint (D54, M8, M16)

AstLint is the pattern, and cannot be the plan. It is "A checker, not an inferencer": it reads the elaborator's `Witness` records and works every node's type out, and "It never unifies" (`elab/astlint.sml:1-17`), checking against the Definition's numbered rules. It can be that because the Definition's rules are deterministic given the witnesses [inferred]. The Report has no typing rules: Hindley-Milner is a citation, and context reduction, defaulting and kind inference are prose (E9).

**CoreLint** (M8) checks Core: explicitly typed, so syntax-directed, with no unification. It runs at each boundary and, at level 2, after each Core pass, through `Pass.stage`. It also runs on text read by `--read-core`, so that track B is tested before a parser exists. It must run just before the crossing into Mid, because below that point `Any` positions leave MidLint weaker, and the translation must stay small (D4, E15). It is first-version work: "One of the dumbest things we did was to delay writing Core Lint" (*What the literature says*).

**HsLint** (M16) checks elaboration. A target check alone cannot see what matters most: `show (read "True")` elaborated at `Int` and at `Bool` are both well typed at `[Char]`, with different meanings (Faxén, §10.2). Neither Faxén nor THIH checks elaborated output. So D54, as the owner decided it, has three parts, on rhc's own evidence records (D31):
1. **A target check.** The elaborated term types in the System-F-like target, by CoreLint's rules, and its type is the translation of the source type: Hall's soundness statement. It must accept any route to a superclass, since several elaborations are correct.
2. **A second inference.** A transliteration of THIH's `tiImpls`, `split`, `candidates` and `tiProgram`, in the conformant form its §11.6.3 describes, re-derives each group's scheme, ambiguity, deferred predicates and default choice, and compares them with the records. Only this part can check Rule 2 of 4.5.5, ambiguity and 4.3.4's defaulting. Kinds and dependency groups are recomputed.
3. **Replay of Faxén's rules** on (source, elaborated) pairs, E15's third layer, taken by the owner (D54's C). It gives messages that cite his rule names, and a second check of Rule 1, which his `bindg` with Definition 2 states (Faxén 2002, p 338). It cannot refuse ambiguity, since his rules admit ambiguous schemes (§7.2.3), and has no rules for deriving, `newtype`, strictness flags or recursive modules (§1.3), so an SCC needs a rule of rhc's own and derived instances are checked as the AST M14 makes of them. His deviations in §2.2, §4.2 and §4.3 are amended before it runs.

**Independence and its limit.** HsLint shares no code with the checker but rhc's renamer, so a renaming bug is outside it. Unlike AstLint it does unify, so its unifier is its own. A citation of Faxén is checked against E15's list of 17 places where his rules depart from or are silent on the Report.

**How they are held.** As AstLint is:
- Each rule has a fault that corrupts its datum and must be refused with its message, as the 20 of `astlintFaults` (`tests/runner/tools.sml:783`).
- `bin/rune-test` already sets `RUNE_LINT=2`, and every suite compiles under it.
- No check moves a byte: `levelsOne` compares a linted build with a plain one at level 0 (`tests/runner/oracles.sml:123-149`), and rhc's builds take the same comparison.

Size, from AstLint's 1,957 lines and MidLint's 457: about 3k for both [estimate, E10].

### Differential self-oracles

These need no other compiler and most of them no clause. Exactness depends on what is compared: **between runs of the same bytes, everything; across a change of code, only what the Report fixes.** Rune's `levelsOne` compares stdout, stderr and exit across levels (`tests/runner/oracles.sml:184-191`). rhc cannot: which `error` fires may change with optimisation, and runs agree only "using the same compiler optimisation level" (Peyton Jones et al. 1999).

| Comparison | Milestone | Exact on | Relaxed on |
|---|---|---|---|
| Every tier, the same bytes: `jitModes`' eight (`tests/runner/oracles.sml:393-401`) | M9 | stdout, stderr, exit, `--count` | nothing |
| Both bytecodes (`registerOne`, `tests/runner/oracles.sml:198-230`) | M9, D14 | stdout, exit, allocation where parity holds | instructions |
| GC ways and stress (`tests/runner/lang.sml:104-143`) | M9 | as a run | |
| Core interpreter against the VM | M8 | stdout | loop, abort and stack overflow are one bottom; primitives' operand order fixed |
| `-O0` against Sestoft-order trees (D34) | M15 | stdout, bottom or not | stderr |
| `-O0` against optimised | M23 on | stdout, bottom or not | stderr, counts |
| Whole against units (`unitsOne`, `tests/runner/oracles.sml:626-693`) | M21 | bytes, where D45 allows | |
| Merged against literal layout, under D36's fallback | M22 | stdout | |
| rhc against `examples/benchmarks`' `-lazy` ports | M19 | stdout, where the texts agree | |

**`-O0` is a reference by audit only.** It is the Report's translation taken literally, which the Report licenses as a semantics, not as a scheme: "Any implementation should behave so that these identities hold; it is not expected that it will use them directly" (3.17.3). Pałka 2012 held the hypothesis that `-O0` is right and found a program `-O0` miscompiled and `-O` fixed. So agreement of `-O0` with an optimised build is evidence, not proof, and it is the Core interpreter on a literal translation that is rhc's nearest HaMLet.

**The Core interpreter** is Launchbury as specification and Sestoft's machine as program. Its `seq` and I/O rules are rhc's own. It is slow by design, and it is not budgeted on corpus-size programs until measured.

**The `-lazy` ports** are 115, of which 108 map to an accepted program, 46 the same text as the 2019 tree and 35 edited (E8). They bound rhc's output against hand-written lazy SML, and they have no dictionaries or `Integer` defaulting, so they compare back ends only.

**Nothing ran is no pass.** `jitOne` fails a run that did not start or a silent one (`tests/runner/oracles.sml:430-444`), and `jitProbe` holds each VM to a known output (`tests/runner/oracles.sml:461-486`), since a past check compared two empty outputs. Every comparison above inherits both.

### Bottom probes

A lazy compiler's characteristic bug makes a program too strict or too lazy, and a run on total inputs cannot see it. The Report's Prelude defines each function's strictness by its code: `take 0 undefined` is `[]` by the first guard, `zip [] undefined` is `[]`, and `zip undefined []` is bottom (`results/E9/report-libs/PreludeList.hs:185-188,318-334`).

Haskell 98 cannot see bottom: `catch` takes `IOError`, and "cannot be caught by the user" is 3.1. So a probe is one of two things:
- **One process with a recorded prefix of output.** Print a marker, then the term; the expected result is the prefix and whether it then fails. This is Pałka's trick, and it runs on the oracles too.
- **A private primitive,** which costs one overlay entry (D37) and works inside the Core interpreter.

**Rules.** All of loop, abort, black hole and stack overflow are one bottom. Timeouts stay, since a catching test sees only a bottom that raises. A test expecting an error asserts refinement, some exception the source permits, and not a message (*What the literature says*). Infinite values are cut off by `take`.

**What they cover.** The literal Prelude is the reference, compiled at `-O0` and on the Core interpreter, against the overlay and, later, against optimised builds. Inputs are partial lists and tuples at each argument position of each function in chapter 8 and the libraries, enumerated to a small depth, which suits Prelude functions and not whole programs (Duregård et al.). Rows that need it: the `run` rows of chapters 8 and 12 to 27, and R17 and R35. Demand compared function by function, in the manner of Lazy SmallCheck and StrictCheck, needs instrumentation Haskell 98 lacks, and belongs in the interpreter later.

### Sharing budgets, rhc's policy

The Report never requires call-by-need. It says non-strict; E9 finds sharing unspecified, and it appears only as a motive, "Rule 1 prevents computations from being unexpectedly repeated." (4.5.5), and in a note on `f = \x -> \y -> x+y` (E15). A compiler that re-evaluated every thunk would conform, and be useless. **So these budgets are rhc's policy, labelled so, and outside the conformance table.** They have no row and cite no clause, with one exception: a budget beside each 4.5.5 test, whose clause is that sentence.

**Mechanism.** `runevm --count` gives exact instructions, bytes and objects. `tests/perf/*.budget` is the form, and a budget is a ceiling, 10% over the count when written (`tests/runner/budgets.sml:111`), checked by `actual <= limit` (`tests/runner/budgets.sml:138`). Ceilings fit: floating and strictness change counts freely, and full laziness may lower them. The same program at sizes n and 2n also bounds growth, so a lost share is caught as an exponential rather than as a percentage.

**The programs** are those exponential if unshared:
- a `let` or `where` thunk used twice on each of n levels: `f n = let y = f (n-1) in y + y`;
- `let len = genericLength xs in (len, len)`, the case 4.5.5 names, with and without its signature;
- a CAF used repeatedly; a self-referring list and a recursive array definition (E1's recursive values, D6);
- a dictionary-derived value inside a loop;
- what `inline` could copy: a thunk held in a `Fun` group, which MidLint would not see (E15, D51).

**Where they run.** Every optimisation setting, both bytecodes, since optimisation changes sharing. Budgets are per bytecode, as `tests/perf/stack/` is (`tests/runner/budgets.sml:97-98`).

**What they cannot see.** Space. A retained closure leaves `--count` unchanged (Peyton Jones's `f = drop 1000`). The release rule of D12 needs a residency test: E2's `last` and `leak` kernels report live bytes at two sizes (`results/E2/tables/last.txt`), and those kernels go into the suite through rhc as soon as M10 can compile them.

### Generators and metamorphic relations (D55)

A fixed suite is not enough, and the only Haskell work in the field finds its bugs by generation (*What the literature says*). Rune has the tools: `lib/test/property` draws, shows and shrinks, and `tests/runner/functorgen.sml` holds the compiler to a property over generated programs, "made well typed by construction", each failure shrunk and replayable (`docs/testing.md:395-397,412-420`). `functors/@generated` runs 16 programs from seed 1 in `make check` (`tests/runner/oracles.sml:1377-1380`), `tests/functors/known.txt` lists known failures, and long runs are by hand.

**Three generators, cheapest first.**
1. **Syntax.** Random ASTs from 9.5's 163 productions, with random fixities, printed and reparsed, and tokens compared. It needs no type checker, and it reaches what the corpus never writes.
2. **Core.** Well-typed lazy Core terms, in Pałka's shape: `[Int] -> [Int]` with `seq`, applied to partial lists, compared across interpreter, `-O0` and VM. It can run before a front end exists, so it tests M9 and M10 first. Its oracle is the self-oracles above, with bottom-or-not.
3. **Programs.** Well-typed Haskell with classes, instances, defaulting and modules, as a plan of choices, after M13. It can go to the judges, for what they agree on.

Generated programs stay inside E15's "hold still" list.

**A reducer** comes with the printer: type-preserving shrinking is what made Pałka's reports possible, and a reducer must keep a program valid, so each step recompiles it.

**Metamorphic relations** are pairs of programs that must behave alike. They need no second compiler, and they suit the Report better than C, because it defines its semantics by translations, so each relation cites a clause. Pałka's pairs caught what cross-optimisation missed.

| Relation | Source | Compare |
|---|---|---|
| Each translation applied by hand: `if` to `case`, sections, `do`, comprehensions, `[a..b]`, literals, `e :: t`, field access, clauses to `case`, guards | Chapters 3, 4; 92 `tr.*` rows; `results/E9/translations.md` | stdout, not counts: a section's translation loses sharing (R11) |
| Explicit braces against layout | E10's print | Core text |
| Full parentheses against operators resolved | Fixity pass | Core text |
| Multi-module against joined single module | Chapter 5, two exceptions | stdout |
| Literal layout against `merge.py`'s form, once by hand and in no tier (D36) | E16 | stdout |
| Alpha renaming of locals; order of top-level declarations | Chapters 3, 4; Rule 2 aside | stdout |
| A thunk unforced on an input replaced by `undefined` | EMI's lazy form [inference]; the Core interpreter gives the profile | stdout |
| The Report's laws at each instance: Functor and Monad, `quot`/`rem` and `div`/`mod`, `read` of `show` | 6.3, 6.4, 10.4 | as `tests/runner/laws.sml` does for the Basis |

The translations are not all safe as rewrite rules: rules (b) and (c) of 3.17.3 do not terminate as a system, and literals are circular (E9). A relation is written for each case, not generated from the rule.

### rhc's mutants

Round trips, lints and differences are worth what they catch. `tests/runner/compilermutants.sml` measures that for Rune: 68 mutants (`tests/runner/compilermutantlist.sml`), each exact edits of the sources, built into a compiler of its own, compiled over a fixed corpus and judged `LINT`, `OTHER`, `UNCAUGHT`, `UNEXERCISED` or `STILLBORN` (`tests/runner/compilermutants.sml:385,491-496`). It takes 7.6 hours of CPU in the nightly; `make check` only builds each mutant, about 7 minutes of CPU (`docs/testing.md:833-836,866-869`, `tests/runner/compilermutants.sml:37-40`).

rhc takes the machinery: `build`, `places`, `compile`, `classify`, the verdicts and the `built-ID` jobs. **What changes:**
- **The corpus** (`tests/runner/compilermutants.sml:70-122`) becomes rhc's suites at `-O0`, and at the top level once P exists.
- **There is no `boot` part.** rhc is SML, compiled by Rune, and never compiles itself. A mutant is built by `bin/rune` from `rhc.build`, which replaces `bootSources` (`tests/runner/compilermutants.sml:68`) and the stage comparison (`tests/runner/compilermutants.sml:476-488`).
- **The stages that read `tests/errors`** (`tests/runner/compilermutants.sml:389`) are rhc's lexer through checker.
- **`lintCaught`** (`tests/runner/compilermutants.sml:350-354`) is a list of its own: the mutants HsLint and CoreLint must catch.
- **The tier** is `test-rhc-mutants`, nightly, with `built-ID` in `check`.
- **The verdicts** add one sense of `OTHER`: seen only by a round trip, a sharing budget or a bottom probe, which is how each of those earns its place.

Rune's own list must follow track A: a mutant that no longer applies is a FAIL (`tests/runner/compilermutants.sml:39-40`), and E11's patch 7 moves code that `tests/runner/compilermutantlist.sml` names in `lower.sml`, so M4 updates those sites.

**What to seed, and what should see it** [proposal]:

| Stage | Seed | Should be seen by |
|---|---|---|
| Parser | E10's: drop `where`, a context, a precedence, `~`, `deriving` | token test |
| Parser and printer | a compensating swap | a run |
| Names, fixity | greatest for least fixpoint; a hidden module importable; fixity read before names | fixtures, reject |
| Types | Rule 1 off, Rule 2 by group, defaulting without a numeric class, ambiguity check off | second inference |
| Classes | a superclass path wrong, a method slot swapped, a derived context too wide | target check, second inference, a run |
| Desugaring | clause order reversed, `~` made strict, a `newtype` pattern forcing | run, bottom probe |
| Core to Mid | a force forgotten behind a cast, a thunk in a typed slot | MidLint, CoreLint. E1 and E2 ran both, silent at tier 2 |
| Thunks | no update, a thunk copied | sharing budget, and only that |
| Libraries | a Prelude definition stricter than the Report's | bottom probe |

An `UNCAUGHT` mutant is a missing test or a redundant line of code, and is settled as one or the other.

### Budgets and tiers (D56)

E8's run set gives the sizes, measured under `ghc -O0` at load 30 to 40, so as indications. K is rhc's slowdown against `ghc -O0`, from E5: 3.4 to 5.2 on whole programs, 13 to 23 on Prelude-bound kernels, so **K = 5 for whole programs and K = 20 for Prelude- or `show`-bound ones [inferred]**. K rests on three hand-lowered programs and four kernels, in instructions at tier 2, with no compile time. Rune's `make check` is 11,879 s of CPU (`docs/testing.md:258`).

| Run programs | CPU under `ghc -O0` | One way under rhc, K = 5 | K = 20 | Share of `make check`, K = 5 | K = 20 |
|---:|---:|---:|---:|---:|---:|
| 188, each at most 1 s | 36.4 s | 182 s | 728 s | 1.5% | 6.1% |
| 223, all | 191.8 s | 959 s | 3,836 s | 8.1% | 32.3% |

K is a ratio of instructions laid on seconds of `ghc -O0`, and it is tier 2's. The same runs' cycles, single loaded runs, give 5.8 to 7.0 and 18.8 to 42.8 (`results/E5/k.txt`), an indication that seconds run above it.

**The recommendation stands: the 188 programs in `make check`, the 35 others nightly.** Two things the figures leave out:

- **Ways.** That is one way. `Lang.ways` tags 18 ways for `check` beside the hosts' and native code's (`tests/runner/lang.sml:105-126,275-278`), and 188 programs in 18 ways is 18 times the figure. So in `check` the run set takes three: the stack VM, `bin/runevm` at its default `--jit=opt`, and tier 2 (`test`, `register`, `register-opt`). E5 ran nothing on the stack VM, and D56 restates the sum with that way's cost as an estimate. The rest are nightly, which is where G2's "every tier and gc-stress" is met.
- **Compiles.** rhc's compile time is unmeasured (E8). The clause rows alone are up to 3,781 programs. Until D45's snapshot, each compile is whole-program with the 11-module unit's 14,965 tokens (E16). At E10's 560.5 instructions per token, parsing alone is 8.4M VM instructions per compile [deduced], and the checker and Core passes are not measured at all. So M19 runs on a frozen Prelude: E13's saved world, which needs no interface codec, until M21's snapshot, with M20 and M21 beside it (D45). The saved world is 583M machine instructions against 1,142M with nothing kept, on the toy, which has no front end. D45's rough rate makes the whole a budget matter for `make check`.

| Tier | Holds |
|---|---|
| `quick` | Clause programs on the default way, round trips on a sample, CoreLint and HsLint faults |
| `check` | Clause programs and their `--typecheck-only`; the 188 in three ways; round trips on the corpus present; sharing budgets; bottom probes; `conformance.tsv` enforcement; Core tests in `tests/ir`'s form; the syntax and Core generators from a fixed seed; `built-ID` |
| `nightly` | The 35 others; every way, both bytecodes, gc-stress; the judges and GHC's dump; `reject-unchecked`; long generator runs |
| `test-rhc-mutants` | The mutants, a job of its own |

`--affected` works through `covers:` tags. A change under `lib/compiler` selects everything already, rhc's tests included, and rhc's own paths select rhc's tests alone.

### The gates' exits

**G1: hello.** The Report's Prelude, in the Report's layout, runs hello on the Core interpreter and on the VM, with identical output. The check is one program in the interpreter-against-VM comparison, with `jitProbe`'s rule that a run printed what it should. G1 says nothing of conformance: hello reaches 19 definitions of the 525 in the unit (E16).

**G2: the Report.** Conformance holds when each line passes:

| Exit | Check |
|---|---|
| Every normative clause has a test or a pinned deviation, enforced as `docs/language.md` is | `conformance.tsv` enforcement with no row `Planned` |
| `conformance98` green, or each failure a recorded reading | The harness, `tests/hs/oracles.txt`. Green here is not conformance, by its own README |
| The clean nofib programs match at `-O0` and at the top level | The run set's 56 nhc98 and 82 2019 programs right under `ghc -O0` (E8), 19 of the 82 through D22's compat `hash` |
| The Prelude's diff from the Report is empty but for the listed overlay: by module, or under D36's fallback by definition and export list | A token comparison against the pristine transcription, as `DocChecks.signatures` holds the Basis to its transcriptions (`tests/runner/docchecks.sml:203-254`) |
| HsLint, CoreLint and MidLint clean at level 2 | Every suite, under `RUNE_LINT=2` |
| rhc's mutants caught | `test-rhc-mutants`: no `UNCAUGHT` |
| All of it on both bytecodes, every tier and gc-stress | The nightly ways |

Sharing budgets, generators and bottom probes are not lines of the Report's exit: the first because the Report asks nothing of sharing, the others because they find bugs and state no coverage. Each runs from the milestone that makes it possible, and from then on it is a test like any other.

## What build-system-v2 gave rhc

build-system-v2 landed in origin/master `697724da5`, and rhc's implementation starts there (D46). This is a review of what it built against what this roadmap asked of it, and every citation in it is of that tree (`agents/Y-v2-review.md` in the drafts).

**The six decisions rhc asked about were taken with a second language in view.** None needed another option than the one v2 recommended, and v2's text names rhc in each:

| v2's decision | What rhc asked | What v2 says |
|---|---|---|
| D5, the plan | A plan can carry discovered edges and SCC groups | "rhc scans imports"; the schema "leaves room for discovered edges and SCC groups and builds neither" (`build-system-v2.md:5090`) |
| D6, the one way | Written order per language | "Written order is per language"; rhc "uses neither `Deps` nor `group`" (`:5108`) |
| D8, boundaries | Kinds of export are the language's | "Kinds of export are the language's", and a boundary cannot hide an instance (`:5140`) |
| D14, identity | Identity per root, over its closure | "One identity per compiler", over the compiler's own closure (`:5212`) |
| D24, the store | A head the client defines | "The head belongs to the client", judged by a `holds` callback; rhc's key "covers every member of an SCC" (`:5383-5384`) |
| D25, the warm path | A hit may read imports' exports and instances; memos in `lib/compiler/driver` | "A hit may read a head"; "Memos go in `lib/compiler/driver`" (`:5408-5409`) |

**What rhc uses of it:**
- **The store.** `lib/compiler/driver/unitstore.sml`, 746 lines, built in v2's M6 and M7 from E13's prototype: an `('h, 's) format` with sections hashed apart, a head judged by `holds`, settings passed in, keys of several parts, layers, eviction by age and size. It knows nothing of SML. rhc writes its own format, head, `holds`, key and settings, so D43's B is done (D43). The store's location and trim policy still sit in `unitcache.sml` (`:223-275`, `:565-583`), about 60 lines, which M20 may move.
- **Friends.** Naming a file or sub-build of a library with a header is an error unless the header names the build a friend (`lib/compiler/driver/project.sml:286-313`), and `rune.build` is one. One line in `lib/compiler/library.build`'s `friends` lets `rhc.build` in (D41).
- **Identity per compiler.** `scripts/gen-version.sh --config PLAN FILE` writes another compiler's `Config` over its own plan (`:27-30`, `:119-123`); a toy second compiler is tested doing so with Rune's identity unchanged (`tests/runner/buildchecks.sml:467-489`). Through `libraries compiler` rhc would get Rune's `Config` instead, the hole v2's M11 found, since `Link.provenance` and `UnitMemo` both name it. So rhc links its own (M8).
- **The memos.** `unitmemo.sml` is language-neutral but for `Config.identity` and the `Source.reading` hooks, and right once rhc links its own `Config`. The warm walk itself stayed in `src/driver/main.sml`, which grew from 1,309 lines to 1,996, so a second driver gets the memos and not the walk.
- **Generated codecs.** Mid's codecs are generated from `tools/codecs/compiler.sml` (`fundef` at `:234-237`, `Ty` at `:168-176`), and `make check-codecs` refuses stale output. A `label` on `fundef`, a `Case`, a multi-value `Return` or a form of `Ty` is an edit of that description and `make codecs` (M4, M28 to M30).

**What it leaves to rhc:**
- **`edge` and `scc` are reserved and refused** in plans of version 1 (`lib/compiler/driver/plan.sml:52-56`), and `Deps` still refuses a cycle (`lib/compiler/driver/deps.sml:394`). So rhc is its own driver: it scans imports, takes SCCs and drives the pipeline, `Link`, `UnitFile`, `UnitStore` and `UnitMemo` itself, setting `UnitStore.stat` and `lstat` as `src/main/rune-main.sml:4-17` does (M21). It uses none of `CompilerPlan`, `LibraryScope`, `LibraryIndex`, `CompilerPrelude` or `Workspace`, which pulls in `CompilerProject`, `Deps` and `Ast` [Y's reading].
- **A view where a friend is right.** v2's text says rhc's `lib/compiler/mid.build` "becomes a named view of `lib/compiler` (D8), not a friend" (`build-system-v2.md:5791`). A view must be a subset of the exports, so it would make `lib/compiler` export Mid, Low, `Ty` and the passes to every client, which is D41's A, and through `libraries` it would give rhc Rune's identity. v2's own M11 contradicts the line, and it should say a friend (D41).
- **`pipeline.sml` still names the front end,** essentially as at `b12141ecc`: the elaborator's counters, `Env.inlinedValue`, `Translate.funNames` in `lowOfMid`, `ToMid`, `Ast`, `UnitBasis` and `Fixity`. E11-8 moves the Mid half into `driver/midpipeline.sml`, which names none of them, and M4 redoes it on this tree (D39, D41).
- **E11's patches no longer apply** but for E11-2, E11-4 after it, and E11-10's compiler hunk (`git apply --check`): M4 redoes them on the new tree.

## Every change to Rune

The brief's rule: no silent changes. This is the whole list. Grades are the brief's. A size is the prototype's by `git apply --numstat`, files first, over `lib`, `src` and `runtime` with tests apart; a hand count or an estimate says so.

"Bytes held" is E11's test on each patch, which compares bootstrap bytes: stage 1 equals stage 2, and the edited compiler on the unedited sources gives `bin/rune.rbc`, at stack, `-O0` and `-O2` (`results/E11/verify-summary.txt`, all 12 lines hold). Suites are another test, pass or fail, and ran on a subset: `results/E11/suite.sh`, with results for the base tree, patches 4 and 8, the final tree and the tree without patch 10. None has been through `make check`, a host build or another machine. The prototypes were made on `b12141ecc`; at origin/master `697724da5` only E11-2 applies as it stands, so their sizes are the prototypes' and what lands is rewritten.

| Change | Grade | Decision | Milestone | Size | Effect on SML |
|---|---|---|---|---|---|
| `tests/runner`: `Lang`, `LangChecks`, `Oracles`, `ExternalChecks` and `CompilerMutants` take their roots and programs as arguments; the table's enforcement, the oracle harness, the round trips and rhc's mutants added | small | D52, D53, D55 | M1, M2, M3, M19 | about 400 changed, 250 and 500 new [estimates] | Rune's inventory unchanged; no compiler source |
| `Stamp`, out of `Elaborate` (E11-1) | small | D40 | M4 | 16 files, +30 -20, rewritten on origin/master | bytes held |
| `Target` passed in (E11-2) | small | D40 | M4 | 5, +13 -17; applies on origin/master | bytes held |
| Counters register where they live (E11-3) | small | D40 | M4 | 8, +21 -17, rewritten | bytes held |
| Pass list as data (E11-4) | small | D39 | M4 | 1, +50 -16; applies on origin/master after E11-2 | bytes held |
| `label` on `fundef` (E11-5), described in `tools/codecs/compiler.sml` | medium | D40 | M4 | 17, +158 -193, rewritten on the codecs' description | bytes held |
| Simplify and Lower take options (E11-6) | small | D39 | M4 | 5, +49 -14, rewritten | bytes held |
| `backend/results.sml` (E11-7) | small | D39 | M4 | 3, +470 -454, a move, rewritten | bytes held |
| `driver/midpipeline.sml` (E11-8) | small | D39, D41 | M4 | 3, +187 -167, a move, rewritten | bytes held |
| `Literal`, `Ty.constAt` (E11-9) | small | D40 | M4 | 22, +147 -137, rewritten | bytes held |
| MatchComp stops making `Try`, `Fail` (E11-10), and the constructors go | small | D7 | M4 | 1, +22 -6; the removal not built | bytes held; four expected dumps change |
| Root names after E11-7 and E11-8 (E11-11) | small | D39 | M4 | 2, +17 -17, rewritten | bytes held |
| `--passes` and `--dump-after` refuse an unknown name | small | D39 | M4 | not prototyped | a CLI change, which fixes a defect on master |
| `lib/compiler/mid.build` | small | D41 | M4 | not built | none expected |
| `rhc.build` in `lib/compiler/library.build`'s `friends` | small | D41 | M8 | one line | none |
| `atomsOfRhs`, `mapRhs`, then `Mid.fold` over `exp` | medium | D10 | M6 | not built | should hold bytes [inferred] |
| `--read-mid` to bytecode | small | D1 | M5 | 1, +14 -2 | none |
| Mid text carries `label` | small | D40 | M5 | 1, +14 -2, rewritten on E11-5's label | dumps change; the compiler's bytes identical at `-O1` and `-O2` with E1's prototypes |
| `staticParams`, `makeCopy`, equality bound | small | D5 | M7 | 1, +10 -4 | a lesser test than bytes held: the compiler's sources at `-O1` and `-O2` alone, with no fixed point, no suites and no stack target (`results/E1/selfcheck.sh`). It fixes a defect on master, and its bound `Ty.size t <= 256` can change a large program's `=` at `-O2` [deduced from the patch] |
| Lints: `ConTag`, forward `Val`, abstract arity | small | D5 | M7 | not built | lint only |
| Exception to the library rule | small | D42 | M8 | a sentence in `AGENTS.md`, or a `LibHosts` entry | none |
| Form C on the register set: `susp` tycon, thunk primitives, `FORCE`, `ENTER`, `BLACKHOLE`, `UPDATE` | large | D3, D11, D13 | M9 | about 305 by hand, the 45 below among them, of 39 files and +1,051 -73 for all forms | both instruction-set fingerprints and the register set's opcode table move, so every `.rbc` changes once; strict ports 1.0056 in machine instructions on `bin10`, which holds C's instructions, `--count` identical |
| The four instructions on the stack set, runeopt's templates and native code | large | D14 | M9 | about 115 [estimate, not built] | the stack set's fingerprint and opcode table move |
| The collector and images: `obj_scanned_fields`, `K_LAST`, `put_object`, the frame check at `runtime/image.c:906`, `share.c` | small | D11 | M9 | about 45 by hand, shared by all forms but A; `image.c` +4 -2 | the collector tests each object, which is that 1.0056 |
| Cast erased in Lower, with a Lower rule dropping a force of a known non-thunk | small | D4 | M9 | in 3 files, +45, holding four modes, with form G's `RegVerify` exception | not known: `rune.rbc` identical kept and erased shows nothing, since the compiler has no such cast. M9 tests programs that do cast |
| Lint: no cast leaves a `susp` | small | D4 | M9 | 1, +7 | lint only |
| Lint: a thunk's function named by nothing else, `thunk_self_update` nowhere else (D57's item 2) | small | D57 | M9 | not built | lint only |
| `any_check`, behind a compile-time switch, in checked builds and VMs only | small | D5 | M9 | in `E5-integer-prims.patch` | none on a build without it, shown by bytes and `--count` |
| `Ty` with variable-headed application and a forall | large | D4 | M28 | 300 to 500 over 12 or more files [E4's estimate], 96 view sites | SML programs' bytes held [deduced: SML makes neither form]; the compiler's own code and budgets move by what M28 states |
| A `Case` in Mid | medium | D8 | M29 | not built: an arm in at least 88 walkers, and Simplify's rounds | bytes and budgets may move, since `Lower`'s reconstruction gives way; M29 says by how much |
| `IntInf` immediate, with in-line primitives and their host versions in `tests/basis/host/rune-prim.sml` | medium | D20 | M31 | E5's ten primitives, +70 -2 with no bignum path; `lib/basis/intinf.sml` is 651 lines | SML programs that use `IntInf` change, the compiler among them; fingerprints move; M31 says by how much |
| Built-in tycons out of `Types` | small | D40 | M10 | about 40 [inferred] | M4's test, not run |
| `ToMid`'s builder lifted out | small | D7 | M10 | not sized | M4's test, not run |
| General category and case mapping in `lib/unicode` | small | D21 | M11, M17 | not measured | a library addition; none on the compiler [deduced] |
| A sentence in the top-level `LICENSE` | small | D37 | M17 | a sentence | none |
| The store's location and trim policy out of `unitcache.sml`, optional | small | D43 | M20 | about 60 [Y's estimate] | bytes held |
| Guard on the `K_IND` shortcut, in `minor.c` and `mark.c` | small | D57 | M26 | in E2's patch | Haskell's thunks +0.84% on form G if taken; none on SML |
| The pin, `gc_pin_running` | small | D57, D17 | M26, or M25 if D17's B needs it | +24 -3 with the flag and loader | ports 1.0003 on form G |

**Built for measurement on the register VM first, landing with the rest only if the owner takes it** (*Decisions on the numbers*):

| Change | Grade | Decision | Milestone | Size | Effect on SML |
|---|---|---|---|---|---|
| A `Force` right-hand side, with a recursive form in Mid | medium | D3, D6 | M9 | not built: an arm in every walker after M6 | measured on the compiler's own compile |
| Multi-value return in Mid, Low and the register set; the stack set, runeopt and native code if taken | large | D9 | M30 | not built: 126 walkers, both sets, the JIT, runeopt | if taken, both fingerprints move; SML's code as the build decides and states, measured on the compiler and benchmarks |
| Eval/apply proper, every engine if taken | large | D15 | M25 | not built | SML's curried calls take it too; measured on Rune's programs |
| Pointer code 11 | large | D16 | M25 | not built | every pointer read; measured on Rune's programs |
| Sparud's `updatePat`, a primitive that updates another thunk | small | D17 | M25 | not built | none [deduced: SML has no lazy pattern binding] |
| CAF tables and a collector that traces from live code | medium | D19 | M25 | not built | the collector's roots; measured |
| A primitive that unpacks a string constant | small | D24 | M17 | not built | the fingerprint moves; Rune has no use for it |

**What does not change:** Lambda, but for `Try` and `Fail`; pointer codes, unless D16's B is taken; frames. The rest of what this list once held still moves only by decision, and the owner's decisions move much of it: Mid gains `Case`, `Ty` two forms, both instruction sets `FORCE`, `ENTER`, `BLACKHOLE` and `UPDATE`, and `K_THUNK` is used. Multi-value return, with Low's `Return` of a list and a multi-value `RET` and `RESULT`, comes only if the owner adopts it (D9).

**What does change there, in code and not in output, by test for E11 and by deduction for M6.** E11-5 adds `label` to `fundef` and rewrites `expand`, `lift`, `refs`, `shake`, `simplify`, `workers`, `midcanon`, `midtext` and the codecs' description. E11-9 changes `Mid.Const` and `Low.Const`, `lambda.sml` and `simplify.sml`. E11-4 and E11-6 make the pass list data and pass Simplify's and Lower's options in; E11-7 and E11-8 move the analysis of `results` and the Mid half of `pipeline.sml` into files of their own. M4 removes `Try` and `Fail` from Lambda. M6 rewrites Mid's walkers and adds a fold.

**The collector and images do change.** D11 and M9 change `obj_scanned_fields`, `K_LAST`, `share.c`, `put_object` and the frame check at `runtime/image.c:906`, and M26 the shortcut in `minor.c` and `mark.c`.

## Risks

1. **Scope.** A compiler, a lazy runtime and an architecture review in one roadmap. The front end is the mass: 12-20k lines of SML through Core, an estimate, against 2,207 measured for the parser. *What is cut first* is the answer, and M4-M7 stand alone if rhc stops.
2. **Silent unsafety.** With casts kept, a wrong cast puts a thunk in a trusted slot, and tier 2 gives a wrong answer with no fault (E2, E1). With casts erased, as D4 recommended for the casts that remain, that is a fatal on every engine, and the lint of D4, `any_check` in checked builds and the interpreter as oracle are the defence. In a function-typed slot `CALL` now stops a `K_THUNK` (D11).
3. **Space.** The Report sets no bound, and the corpus can still die of CAFs held as roots, no selector thunks or retained closures. D17's B and D19's B are built and measured on real programs (M25), which is the right order and leaves this unknown until then.
4. **Speed.** Integer defaulting, dictionaries and curried calls compound. K is from three hand-lowered programs and four kernels with no `Read` and no real `IO`. Nothing in the roadmap depends on K's being small, but D56's budget does.
5. **Recursive modules have no oracle.** No candidate in 3,089 has a plain import cycle, and all three oracles refuse one. Tests rest on the Report and on conversion to a single module, which is an inference. Under D36 the Prelude is such a cycle, so a fault in the joined checker first shows as a broken Prelude, and D36's fallback is the answer.
6. **Oracles are not authorities.** 48 of 82 conformance tests show a disagreement (E7). Following the text sets rhc against all of them in places (`Just.let`, R21(b), R38): a reader may take that for a bug. D38 lets the owner choose otherwise.
7. **The prototypes have been on one machine.** No form has been through `make check`, bootstrap bytes on its final form, aarch64, 32-bit, PowerPC or Windows. Form C's figures are from one prototype stage, `bin10`, with V2's rerun on `bin12`, and form C never ran on the stack VM or in native code (E2). The lazy ML checklist ran on form G (D57).
8. **The budgets.** A rise in the compiler's image from the prims is deduced, not measured. Budgets are ceilings 10% over the count.
9. **Master has moved.** Every citation is to `b12141ecc`, and implementation starts from origin/master `697724da5`, where v2 has split the store out of `unitcache.sml`, generated `midcodec.sml`'s and `unitmid.sml`'s codecs, and grown `src/driver/main.sml` from 1,309 lines to 1,996. Each milestone checks its citations there.
10. **The corpus's licences** were not surveyed, and a skip is an error in `make check` (`AGENTS.md:311-313`). M3 starts there.
11. **The IR changes the owner took at once.** `Ty` with application and forall (300 to 500 lines over 12 or more files, 96 view sites, D4), Mid's `Case` (at least 88 walkers and Simplify's rounds, the riskiest edit E12 found, D8) and the fold over `exp` (D10). None was built. Each changes code that SML compiles through, so a fault in one is a fault in Rune's own compiler, and each moves SML's code under the standing gate by what its milestone states. M6's walkers come first, so that a new form cannot fall into a catch-all without a word, and each milestone runs E11's test of bytes before it says what moved. Multi-value return (126 walkers, both instruction sets, the JIT and runeopt, D9) is no longer among them: since the owner's answer of 2026-11-10 it is built on the register VM to be measured (M30), and it carries this risk only if adopted, with its landing on the stack set, runeopt and native code after the figures.

## What is cut first

In order: D7's `Try` and `Fail`; the options built for measurement, which land only if the owner takes them; cheap eagerness; then track P as a whole, which leaves a conforming and slow compiler. The owner took D4, D8 and D10 now; cutting one is the owner's call, and M6 can go only with M28, M29 and the builds for measurement that add a form to Mid (D3's variant, M30).

**Never cut:** literate Haskell, the Report's libraries, Unicode `Char`. Recursive modules are a decision (D30), expected to be taken for support, and on no list to cut, and under D36's recommendation the Prelude depends on them.

## Measuring

Claims rest on instruction counts: `runevm --count`, and `perf stat -e instructions:u` at tier 2. Cycles are best-of-N indications, and WSL2's wall time is noise; load is stated where seconds appear. Each experiment's script is beside its data under the drafts' `results/`. A milestone that claims a change holds bytes shows it by the test E11 used: stage 1 equals stage 2, and the edited compiler on the unedited sources equals the old compiler's `bin/rune.rbc`, at stack, `-O0` and `-O2`.

**Not measured, on purpose:** speed against GHC as a goal; `Read` and `Show` cost; rhc's compile time, since there is no rhc; selector thunks or pointer tags before real programs run. The `-lazy` ports do not predict rhc: they compare thunk forms, not compilers.

## At the close

Written at M27.

## References

The papers E15 and E15b read, as far as *What the literature says* and *What the implementations do* use them. Each DOI
in the list below is in `results/E15/dois.tsv`, checked against Crossref on 2026-11-01, unless the entry says otherwise;
"no DOI" means Crossref had no match and the text itself was read. Each entry ends in its status: **Full**, **Sections**
(which), **Abstract**, or **Memory**, the last meaning that no text was seen. The version read is noted where it differs
from the published one. E15's full list holds 193 references, with notes per paper (`results/E15/literature.md`,
`results/E15/lit/`).

E15's table classes as *abstract* some papers whose abstract was read and then sections. Those are given here as
Sections, with the sections named.

E15b read the papers the owner supplied on 2026-11-09, 53 files from `/mnt/h/Rune/haskell98`, copied to
`downloads/owner-papers/` and mapped to E15's keys in `results/E15b/map.tsv`. Its notes are one file per paper in
`results/E15b/P1/`, `P2/` and `P3/`, with a page or section for every claim, and its entries say (E15b). A DOI of an
E15b entry comes from E15's list for the owner or from the PDF, and is marked where it is not in `dois.tsv`.

- Adams. Principled parsing for indentation-sensitive languages: revisiting Landin's offside rule. POPL 2013.
  doi:10.1145/2480359.2429129. Sections 1, 3.1-3.2, 5.8, 6, 7
- Afroozeh, Izmaylova. One parser to rule them all. Onward! 2015. doi:10.1145/2814228.2814242. Sections 1, 3.5, the
  Haskell evaluation
- de Souza Amorim, Steindorfer, Erdweg, Visser. Declarative specification of indentation rules: a tooling perspective on
  parsing and pretty-printing layout-sensitive languages. SLE 2018, 3-15. doi:10.1145/3276604.3276607, not in
  `dois.tsv`. Sections: abstract, 1, 2.1, 5, 6, 8 (E15b). Cited as Amorim et al. 2018
- Appel. Simple generational garbage collection and fast allocation. Software: Practice and Experience 19(2), 1989,
  171-183. doi:10.1002/spe.4380190206. Full, as Princeton TR-143-88. `downloads/papers/appel89.pdf` is another paper;
  the text is `appel89sgc`
- Augustsson. A compiler for lazy ML. LFP 1984, 218-227. doi:10.1145/800055.802038. Sections 3.7-3.9, 5; the rest
  skimmed (E15b)
- Augustsson. Compiling pattern matching. FPCA 1985, LNCS 201, 368-381. doi:10.1007/3-540-15975-4_48. Full (E15b), an
  OCR text
- Augustsson. Implementing Haskell overloading. FPCA 1993, 65-73. doi:10.1145/165180.165191. Full (E15b); Table 1 read
  from the page image
- Augustsson. MicroHs: a small compiler for Haskell. Haskell Symposium 2024. doi:10.1145/3677999.3678280. Sections 1-5
  and part of 6
- Augustsson, Johnsson. The Chalmers Lazy-ML compiler. The Computer Journal 32(2), 1989, 127-141.
  doi:10.1093/comjnl/32.2.127. Pages 127 and 134-138, read as images (E15b); pages 128-133 and 139-141 not read
- Baker-Finch, Glynn, Peyton Jones. Constructed product result analysis for Haskell. JFP, 2004.
  doi:10.1017/s0956796803004751. Sections 1, 2.3, 3.7, 3.11, 5, 6, 8
- Bakewell, Runciman. A model for comparing the space usage of lazy evaluators. PPDP 2000. doi:10.1145/351268.351287.
  Sections 1-2, the opening of 4; the rest skimmed (E15b)
- Benton, Kennedy, Russell. Compiling Standard ML to Java bytecodes. ICFP 1998. doi:10.1145/289423.289435, not in
  `dois.tsv`. Sections 1-6 and the tables; 7-9 skimmed (E15b)
- Bolingbroke, Peyton Jones. Types are calling conventions. Haskell Symposium 2009. doi:10.1145/1596638.1596640. Full,
  as the preprint of 2009/5/14
- Boquist. Code Optimisation Techniques for Lazy Functional Languages. PhD thesis, Chalmers, 1999. ISBN 91-7197-792-9.
  https://research.chalmers.se/en/publication/890 (no DOI). Sections 2.5.2-2.5.5, 9.1-9.5, 10.1-10.2, OCR text
- Bottu, Xie, Marntirosian, Schrijvers. Coherence of type class resolution. PACMPL 3 (ICFP), 2019. doi:10.1145/3341695.
  Sections: abstract and 1
- Breitner. The correctness of Launchbury's natural semantics for lazy evaluation. arXiv:1405.3099, 2014. Sections 1,
  the start of 2.3. The JFP successor, doi:10.1017/s0956796817000144, not read
- Breitner. Call Arity. TFP 2014, LNCS, 2015. doi:10.1007/978-3-319-14675-1_3. Full, as the preprint of 2014/5/25
- Burn, Hankin, Abramsky. Strictness analysis for higher-order functions. Science of Computer Programming 7, 1986,
  249-278. doi:10.1016/0167-6423(86)90010-9. Sections: abstract, introduction; the rest skimmed (E15b)
- Cheadle, Field, Marlow, Peyton Jones, While. Exploring the barrier to entry: incremental generational garbage
  collection for Haskell. ISMM 2004. doi:10.1145/1029873.1029893. Sections 1-3, 4.1, 4.6, 5, 6
- Chen, Hu, Hao, Xiong, Zhang, Zhang, Xie. An empirical comparison of compiler testing techniques. ICSE 2016.
  doi:10.1145/2884781.2884878, not in `dois.tsv`. Sections: abstract, the findings of 1 (E15b)
- Chen, Patra, Pradel, Xiong, Zhang, Hao, Zhang. A survey of compiler testing. ACM Computing Surveys 53(1), 2020.
  doi:10.1145/3363562. Sections 1, 3.3.3, 3.4.1, 4, 7
- Claessen, Hughes. QuickCheck: a lightweight tool for random testing of Haskell programs. ICFP 2000.
  doi:10.1145/351240.351266. Section 6.5, and searches of the rest
- Crary, Harper, Puri. What is a recursive module? PLDI 1999. doi:10.1145/301618.301641. Sections: abstract and the
  start of 1
- Damas, Milner. Principal type-schemes for functional programs. POPL 1982. doi:10.1145/582153.582176. Sections 1, 7
- Danielsson, Jansson. Chasing bottoms: a case study in program verification in the presence of partial and infinite
  values. MPC 2004. doi:10.1007/978-3-540-27764-4_6. Sections 1-2, 5, 9
- Diatchki, Jones, Hallgren. A formal specification of the Haskell 98 module system. Haskell Workshop 2002.
  doi:10.1145/581690.581692. Sections 1-5, 7-9, section 6's checks in part
- Dijkstra, Fokker, Swierstra. The structure of the Essential Haskell compiler, or coping with compiler complexity. IFL
  2007. doi:10.1007/978-3-540-85373-2_4. Sections 1-3 and the opening of 4, in the draft proceedings, Kent TR 12-07
  (E15b)
- Dijkstra, Fokker, Swierstra. The architecture of the Utrecht Haskell compiler. Haskell Symposium 2009.
  doi:10.1145/1596638.1596650. Sections 1, 2.2, 4 (introduction), 5
- Dijkstra, Magalhães, Néron. Functional programming in financial markets (experience report). PACMPL 8 (ICFP), 2024,
  article 244. doi:10.1145/3674633, printed on the paper, not in `dois.tsv`. Section 2 in full, the rest skimmed (E15b).
  With two slide decks on Mu: Agren, Haskell reinterpreted, HIW, 22 August 2021, read in full; Magalhães, ACM TechTalk,
  20 August 2025, skimmed
- Downen, Sullivan, Ariola, Peyton Jones. Making a faster curry with extensional types. Haskell Symposium 2019.
  doi:10.1145/3331545.3342594. Sections 1, 2, 7, 8
- Dreyer. A type system for recursive modules. ICFP 2007. doi:10.1145/1291151.1291196. Sections: abstract, 1, the
  openings of 2.1-2.2 (E15b)
- Duregård, Jansson, Wang. Feat: functional enumeration of algebraic types. Haskell Symposium 2012.
  doi:10.1145/2364506.2364515. Sections 1, 7, 8
- Eisenberg, Peyton Jones. Levity polymorphism. PLDI 2017. doi:10.1145/3140587.3062357. Sections 1-5, statements of 6,
  7, 8, 9
- Ennals. Adaptive evaluation of non-strict programs. PhD thesis, Cambridge, 2004; UCAM-CL-TR-730, 2008 (no DOI).
  Sections 12.2, 12.7.3, 13.1.3, 14
- Ennals, Peyton Jones. Optimistic evaluation: an adaptive evaluation strategy for non-strict programs. ICFP 2003.
  doi:10.1145/944705.944731. Full
- Erdweg, Rendel, Kästner, Ostermann. Layout-sensitive generalized parsing. SLE 2012. doi:10.1007/978-3-642-36089-3_14.
  Sections 1-2, 4.1-4.2, 5
- Faxén. Cheap eagerness: speculative evaluation in a lazy functional language. ICFP 2000, 150-161.
  doi:10.1145/351240.351255. Full (E15b); Tables 1 and 2 checked against the page images
- Faxén. Dynamic cheap eagerness. IFL 2001, LNCS 2312, 105-120, Springer 2002. No DOI printed on the paper. Full (E15b)
- Faxén. A static semantics for Haskell. JFP 12(4-5), 2002, 295-357. doi:10.1017/s0956796802004380. Full, the published
  text
- Fetscher, Claessen, Pałka, Hughes, Findler. Making random judgments: automatically generating well-typed terms from
  the definition of a type-system. ESOP 2015. doi:10.1007/978-3-662-46669-8_16. Sections: abstract and 1
- Finne, Burn. Assessing the evaluation transformer model of reduction on the Spineless G-machine. FPCA 1993.
  doi:10.1145/165180.165229. Full (E15b)
- Flatt, Felleisen. Units: cool modules for HOT languages. PLDI 1998. doi:10.1145/277650.277730. Abstract
- Foner, Zhang, Lampropoulos. Keep your laziness in check. PACMPL 2 (ICFP), 2018. doi:10.1145/3236797. Sections 1, 1.1,
  related work
- Gill. Cheap deforestation for non-strict functional languages. PhD thesis, Glasgow, 1996.
  http://theses.gla.ac.uk/4817/ (no DOI). Sections 4.3, 4.4, 5.3, 5.4.2-5.4.4; 2.4 skimmed (E15b)
- Gill, Launchbury, Peyton Jones. A short cut to deforestation. FPCA 1993. doi:10.1145/165180.165214. Sections 1, 3.3
  (start), 7.1, 9
- Gustavsson, Sands. A foundation for space-safe transformations of call-by-need programs. ENTCS, 1999.
  doi:10.1016/s1571-0661(05)80284-1. Sections 4-5 (start), OCR text
- Gustavsson, Sands. Possibilities and limitations of call-by-need space improvement. ICFP 2001.
  doi:10.1145/507663.507667. Sections 1-3, 6, OCR text
- Hall, Hammond, Peyton Jones, Wadler. Type classes in Haskell. TOPLAS 18(2), 1996, 109-138. doi:10.1145/227699.227700.
  Full as the short preprint; sections 1.1-1.2 and 5-7 of the published text
- Hallgren. Haskell tools from the Programatica project. Haskell Workshop 2003 (demo). doi:10.1145/871895.871907. Full
- Hallgren, Hook, Jones, Kieburtz. An overview of the Programatica toolset. 2004 (no DOI). Sections on the front end and
  the tool list, by search
- Hammond, Blott. Implementing Haskell type classes. In Davis, Hughes (eds), Functional Programming, Glasgow 1989,
  Springer 1990, 266-286. doi:10.1007/978-1-4471-3166-3_18, not in `dois.tsv`. Full, in a copy of the whole volume
  (E15b)
- Harris, Marlow, Peyton Jones. Haskell on a shared-memory multiprocessor. Haskell Workshop 2005.
  doi:10.1145/1088348.1088354. Sections 1-4, 6
- Hartel, Feeley, Alt, Augustsson, et al. Benchmarking implementations of functional languages with 'Pseudoknot', a
  float-intensive benchmark. JFP 6(4), 1996, 621-655. doi:10.1017/s0956796800001891. Sections 1, 5.6.3-5.6.4 in part, 6,
  7, Table 9
- Haskell 2010: Marlow (ed.). Haskell 2010 Language Report. 2010. https://www.haskell.org/definition/haskell2010.pdf (no
  DOI). Sections 3 (introduction), 10.3, 10.6, 12
- haskell-spec. Mechanization of the Haskell Language Report. Lean 4, version 0.1.0.
  https://github.com/haskell-spec/haskell-spec. Full, of README and DIFFERENCES.md; no Lean source read
- Henglein. Type inference with polymorphic recursion. TOPLAS 15(2), 1993, 253-289. doi:10.1145/169701.169692. Sections:
  abstract, 1.1, and searches of the rest (E15b)
- Hieb, Dybvig, Bruggeman. Representing control in the presence of first-class continuations. PLDI 1990.
  doi:10.1145/93542.93554, not in `dois.tsv`. Sections: abstract, 1-3; the rest skimmed (E15b)
- Hinze, Peyton Jones. Derivable type classes. ENTCS 41(1), 2001. doi:10.1016/s1571-0661(05)80542-0, not in `dois.tsv`.
  Sections: abstract, 1 (E15b)
- Hollenbeck, O'Boyle, Steuwer. Investigating magic numbers: improving the inlining heuristic in the Glasgow Haskell
  Compiler. Haskell Symposium 2022. doi:10.1145/3546189.3549918. Sections: abstract, 1, the opening of 6.1 (E15b)
- Hudak, Hughes, Peyton Jones, Wadler. A history of Haskell: being lazy with class. HOPL III, 2007.
  doi:10.1145/1238844.1238856. Sections 2.5 (part), 3.1, 3.4, 3.7 (part), 4.1, 5.2, 5.4, 5.7, 6.2, 6.3, 7.1, 7.3 (part),
  9.1-9.6, 10
- Hudak, Sundaresh. On the expressiveness of purely functional I/O systems. Yale YALEU/DCS/RR-665, 1989 (no DOI).
  Sections 1, 2.3, part of 2.4
- Johann, Voigtländer. Free theorems in the presence of seq. POPL 2004. doi:10.1145/964001.964010, not in `dois.tsv`.
  Sections 1, 8; 2-7 skimmed (E15b)
- Johnsson. Efficient compilation of lazy evaluation. SIGPLAN Symposium on Compiler Construction 1984, 58-69.
  doi:10.1145/502949.502880. Sections 3-5, 7.3; the rest skimmed (E15b)
- Jones, Mark P. Coherence for qualified types. Yale RR-989, 1993. https://web.cecs.pdx.edu/~mpj/pubs/RR-989.pdf (no
  DOI). Sections 1-3, 7-8 by search; the proofs not read
- Jones, Mark P. Qualified Types: Theory and Practice. CUP, 1994. doi:10.1017/cbo9780511663086. Sections 6-7 of the
  revised paper "A theory of qualified types", which is what was read; the book was not
- Jones, Mark P. The implementation of the Gofer functional programming system. Yale RR-1030, 1994.
  https://web.cecs.pdx.edu/~mpj/pubs/RR-1030.pdf (no DOI). Section 7.5, and the binding-group cases by search
- Jones, Mark P. Dictionary-free overloading by partial evaluation. Lisp and Symbolic Computation, 1995.
  doi:10.1007/bf01019005. Full; the PDF looks like the 1994 conference text
- Jones, Mark P. A system of constructor classes: overloading and implicit higher-order polymorphism. JFP 5(1), 1995,
  1-35. doi:10.1017/s0956796800001210. Sections 2.3, 4.4, 4.5, 5, 6
- Jones, Mark P. Simplifying and improving qualified types. FPCA 1995. doi:10.1145/224164.224198. Section 1, and the
  Haskell uses in section 3 by search
- Jones, Mark P. Typing Haskell in Haskell (THIH). Haskell Workshop 1999; revised 23 November 2000 (no DOI). Full, the
  revised version
- Jones, Richard. Tail recursion without space leaks. JFP 2(1), 1992, 73-79. doi:10.1017/s0956796800000277. Full
- Kaes. Parametric overloading in polymorphic programming languages. ESOP 1988. doi:10.1007/3-540-19027-9_9. Sections:
  abstract, 1; the rest skimmed (E15b)
- Keep, Dybvig. A nanopass framework for commercial compiler development. ICFP 2013. doi:10.1145/2500365.2500618.
  Sections: abstract, 1, 3 (introduction), 4
- Kennedy. Compiling with continuations, continued. ICFP 2007. doi:10.1145/1291220.1291179. Sections 1, 2.3, 2.4, 3
  (opening), 4.3 (opening), 6
- Kfoury, Tiuryn, Urzyczyn. Type reconstruction in the presence of polymorphic recursion. TOPLAS 15(2), 1993, 290-311.
  doi:10.1145/169701.169687. Sections: abstract, the opening of 1 (E15b)
- Kilpatrick, Dreyer, Peyton Jones, Marlow. Backpack: retrofitting Haskell with interfaces. POPL 2014.
  doi:10.1145/2578855.2535884. Section 3 on recursive modules and the double-vision passages of section 2
- Lämmel, Peyton Jones. Scrap your boilerplate with class: extensible generic functions. ICFP 2005.
  doi:10.1145/1086365.1086391, not in `dois.tsv`. Section 5 (E15b). Its recursive dictionaries come from instance
  contexts Haskell 98 forbids, not D6's kind
- Landin. The next 700 programming languages. CACM 9(3), 1966. doi:10.1145/365230.365257. The offside-rule passage
- Launchbury. A natural semantics for lazy evaluation. POPL 1993. doi:10.1145/158511.158618. Full, an OCR text with
  errors
- Launchbury, Peyton Jones. State in Haskell. Lisp and Symbolic Computation 8(4), 1995. doi:10.1007/bf01018827. Sections
  4 (opening), 9, 10 (opening), 10.1
- Launchbury, Paterson. Parametricity and unboxing with unpointed types. ESOP 1996, LNCS 1058.
  doi:10.1007/3-540-61055-3_38, not in `dois.tsv`. Full (E15b)
- Laville. Comparison of priority rules in pattern matching and term rewriting. Journal of Symbolic Computation 11,
  1991, 321-347. doi:10.1016/s0747-7171(08)80109-5. Sections: abstract, 1, 4.5 (E15b)
- Le, Afshari, Su. Compiler validation via equivalence modulo inputs. PLDI 2014. doi:10.1145/2594291.2594334. Sections:
  abstract, 1
- Leroy. A proposal for recursive modules in Objective Caml. INRIA note, version 1.1, 13 May 2003 (no DOI). Section 1
  and the passages on initialisation, by search
- Levy. Call-by-push-value: decomposing call-by-value and call-by-name. Higher-Order and Symbolic Computation 19, 2006.
  doi:10.1007/s10990-006-0480-6. Sections 1, 2.2, 3-5, 7.1-7.2, 11, as the manuscript
- Maranget. Compiling lazy pattern matching. LISP and Functional Programming 1992. doi:10.1145/141471.141499. Sections
  1, 6
- Maranget. Two techniques for compiling lazy pattern matching. INRIA RR-2385, 1994 (no DOI). Section 1, the opening of
  the backtracking section, the final discussion and the code-size table
- Maranget. Compiling pattern matching to good decision trees. ML Workshop 2008. doi:10.1145/1411304.1411311. Sections
  1, 2.1, 7, 9, 10
- Marlow. Re: proposal: HaBench, a Haskell Benchmark Suite. haskell-cafe, 25 June 2010.
  https://mailman.haskell.org/archives/list/haskell-cafe@haskell.org/message/BFH2P6MCNCOMMBBUV76BYOFFADMXLVX4. Full
- Marlow. Re: AlternateLayoutRule. glasgow-haskell-users, 13 May 2014.
  https://mailman.haskell.org/archives/list/glasgow-haskell-users@haskell.org/message/RL2FGWEOMRWMEWQAMU24FFJQQCVG5AYB.
  Full
- Marlow. Re: How does GHC implement layout? ghc-devs, 6 April 2021.
  https://mail.haskell.org/pipermail/ghc-devs/2021-April/019794.html. Full
- Marlow, Harris, James, Peyton Jones. Parallel generational-copying garbage collection with a block-structured heap.
  ISMM 2008. doi:10.1145/1375634.1375637. Sections 1, 2, 4.1, 5.7
- Marlow, Peyton Jones. The New GHC/Hugs Runtime System. Glasgow, 27 August 1998.
  https://www.microsoft.com/en-us/research/wp-content/uploads/1998/01/new-rts.pdf (no DOI). Full
- Marlow, Peyton Jones. Making a fast curry: push/enter vs. eval/apply for higher-order languages. JFP 16(4-5), 2006,
  415-449. doi:10.1017/s0956796806005995. Full, Figs 6-8 with layout
- Marlow, Peyton Jones, Moran, Reppy. Asynchronous exceptions in Haskell. PLDI 2001. doi:10.1145/381694.378858. Sections
  1-7.2, 8, 9, 10, as the authors' copy of 2006
- Marlow, Yakushev, Peyton Jones. Faster laziness using dynamic pointer tagging. ICFP 2007. doi:10.1145/1291220.1291194.
  Full
- Maurer, Downen, Ariola, Peyton Jones. Compiling without continuations. PLDI 2017. doi:10.1145/3140587.3062380.
  Sections 1, 2, 7, 8, 9, 10
- McKeeman. Differential testing for software. Digital Technical Journal 10(1), 1998, 100-107 (no DOI). Full
- Mitchell. Rethinking supercompilation. ICFP 2010. doi:10.1145/1863543.1863588. Sections 1, 4, the author's version
- Mokhov, Mitchell, Peyton Jones. Build systems à la carte. PACMPL 2 (ICFP), 2018. doi:10.1145/3236774. Sections 2, 3.6,
  4.2, 6.5, 6.6, others in part. E15's key is `mitchell18`
- Moran, Sands. Improvement in a lazy context: an operational theory for call-by-need. POPL 1999, 43-56.
  doi:10.1145/292540.292547. Sections 1-4 of the POPL text, which is clean (E15b); the extended version's text layer is
  garbled
- Morris. Type classes and instance chains: a relational approach. PhD thesis, Portland State, 2013.
  doi:10.15760/etd.1010, not in `dois.tsv`. Sections: abstract, the opening of 5.3, 5.5, and searches (E15b)
- Mycroft. The theory and practice of transforming call-by-need into call-by-value. LNCS, 1980.
  doi:10.1007/3-540-09981-6_19. Full, formulas partly garbled
- Mycroft. Polymorphic type schemes and recursive definitions. International Symposium on Programming 1984.
  doi:10.1007/3-540-12925-1_41. Sections 1, 7, 8
- Nakata, Garrigue. Recursive modules for programming. ICFP 2006. doi:10.1145/1159803.1159813. The introduction
- Nethercote, Mycroft. The cache behaviour of large lazy functional programs on stock hardware. MSP 2002, 44-55.
  doi:10.1145/773146.773044, not in `dois.tsv`. Sections 1, 5; 6-8 skimmed (E15b)
- Nipkow, Prehofer. Type reconstruction for type classes. JFP 5(2), 1995, 201-224. doi:10.1017/s0956796800001325, not in
  `dois.tsv`. Sections: abstract, the openings of 1-2.1, 8 (E15b). Hall et al. cite its conference version for "a good
  treatment of ambiguity"; its §8 says ambiguity is not introduced formally
- Nöcker. Strictness analysis using abstract reduction. FPCA 1993. doi:10.1145/165180.165219. Sections 1-2, 4.8, 5
  (E15b)
- Odersky, Sulzmann, Wehr. Type inference with constrained types. TAPOS 5(1), 1999, 35-55.
  doi:10.1002/(sici)1096-9942(199901/03)5:1<35::aid-tapo4>3.0.co;2-4. Sections 1, 2, 8
- Pałka, Claessen, Russo, Hughes. Testing an optimising compiler by generating random lambda terms. AST 2011.
  doi:10.1145/1982595.1982615. Sections: abstract, 1, 6.3-6.5 (E15b): one failure in about 20,000 terms, `-O0` against
  `-O1`, which agrees with the thesis. And sections 1, 4, 4.1-4.5 of Pałka's licentiate thesis of that title, Chalmers
  2012, which extends it; cited as Pałka 2012
- Partain. The nofib benchmark suite of Haskell programs. Glasgow workshop 1992. doi:10.1007/978-1-4471-3215-8_17. Full
- Peterson, Jones. Implementing type classes. PLDI 1993. doi:10.1145/173262.155112. Sections 1-6, 8-10
- Pettersson. A term pattern-match compiler inspired by finite automata theory. CC 1992, LNCS 641, 258-270.
  doi:10.1007/3-540-55984-1_24. Full (E15b)
- Peyton Jones. The Implementation of Functional Programming Languages. Prentice Hall, 1987.
  https://www.microsoft.com/en-us/research/wp-content/uploads/1987/01/slpj-book-1987.pdf (no DOI). Sections 5.2.6-5.2.7,
  12.4, 18.6.2, 23.3
- Peyton Jones. Implementing lazy functional languages on stock hardware: the Spineless Tagless G-machine. JFP 2(2),
  1992, 127-202. doi:10.1017/s0956796800000319. Sections 1-3, 4.2-4.3, 5.6, 7, 8, 9 (overview, 9.3.3, 9.4.1), 10, 11,
  appendix A, as Version 2.5, 9 July 1992
- Peyton Jones. Compiling Haskell by program transformation: a report from the trenches. ESOP 1996.
  doi:10.1007/3-540-61055-3_27. Full
- Peyton Jones. Tackling the awkward squad. In Engineering theories of software construction, IOS Press, 2001 (no DOI).
  Sections 2.1, 2.2 (opening), 2.6-2.8, 3.1, 3.2 (opening), 5.1, 5.2, the copy of 2010
- Peyton Jones. Wearing the hair shirt: a retrospective on Haskell. Invited talk, POPL 2003 (slides, no DOI). The slides
  on process, laziness, purity and conclusions
- Peyton Jones. RE: proposal: HaBench, a Haskell Benchmark Suite. haskell-cafe, 29 January 2007.
  https://mailman.haskell.org/archives/list/haskell-cafe@haskell.org/message/XORLCKLT3YZJFKE7HY2MUUCG53HSS2EZ. Full
- Peyton Jones. Call-pattern specialisation for Haskell programs. ICFP 2007. doi:10.1145/1291151.1291200. Sections 1, 5,
  6 (opening), 7
- Peyton Jones (ed.). Haskell 98 Language and Libraries: The Revised Report. CUP 2003; JFP 13(1), 2003.
  https://www.haskell.org/onlinereport/ (no DOI checked). The text is E9's crawl, December 2002 (`results/E9/text/`)
- Peyton Jones, Hall, Hammond, Partain, Wadler. The Glasgow Haskell compiler: a technical overview. JFIT Technical
  Conference, Keele, 1993 (no DOI). Sections 1-3.1, 6.2, 7
- Peyton Jones, Jones, Meijer. Type classes: an exploration of the design space. Haskell Workshop 1997 (no DOI).
  Sections 3.1-3.2, 3.7, 4.1-4.3
- Peyton Jones, Launchbury. Unboxed values as first class citizens in a non-strict functional language. FPCA 1991.
  doi:10.1007/3540543961_30. Sections 1-10.1
- Peyton Jones, Marlow. Secrets of the Glasgow Haskell Compiler inliner. JFP, 2002. doi:10.1017/s0956796802004331.
  Sections 1, 4.5, 4.6, 6.4, 7.7, 8, 9, as the earlier workshop text
- Peyton Jones, Meijer. Henk: a typed intermediate language. Workshop on Types in Compilation, 1997 (no DOI). Sections
  1, 2, 3 (opening), 6
- Peyton Jones, Partain. Measuring the effectiveness of a simple strictness analyser. Glasgow workshop 1993, published
  1994. doi:10.1007/978-1-4471-3236-3_17. Full
- Peyton Jones, Partain, Santos. Let-floating: moving bindings to give faster programs. ICFP 1996.
  doi:10.1145/232627.232630. Full
- Peyton Jones, Reid, Hoare, Marlow, Henderson. A semantics for imprecise exceptions. PLDI 1999.
  doi:10.1145/301631.301637. Sections 1-3, the case rule of 4.3, 4.5 (opening), 5, 6, 7
- Peyton Jones, Salkild. The Spineless Tagless G-machine. FPCA 1989, 184-201. doi:10.1145/99370.99385. Sections 4-5; the
  rest skimmed (E15b). Superseded by Peyton Jones 1992
- Peyton Jones, Santos. A transformation-based optimiser for Haskell. Science of Computer Programming 32, 1998.
  doi:10.1016/s0167-6423(97)00029-4. Sections 6.3.1, 8-11, the authors' preprint
- Peyton Jones, Sestoft, Hughes. Demand analysis. Draft, 26 July 2006.
  https://www.microsoft.com/en-us/research/wp-content/uploads/2006/07/demand-1.pdf (no DOI). Sections 1, parts of 5
- Peyton Jones, Shields, Launchbury, Tolmach. Bridging the gulf: a common intermediate language for ML and Haskell. POPL
  1998. doi:10.1145/268946.268951. Full
- Peyton Jones, Tolmach, Hoare. Playing by the rules: rewriting as a practical optimisation technique in GHC. Haskell
  Workshop 2001. https://www.microsoft.com/en-us/research/wp-content/uploads/2001/09/rules.pdf (no DOI). Sections 1-3,
  the start of 4
- Peyton Jones, Wadler. A static semantics for Haskell. Glasgow draft, dated February 19, 1992 in the copy read; Faxén
  and Hall et al. give 1991 (no DOI). Pages 1-14, 16-20, 24, 26-38 and 42-46, the rest skimmed, read as images (E15b).
  E15 held the same file as `downloads/papers/faxen02.pdf` without knowing it
- Peyton Jones, Wadler. Imperative functional programming. POPL 1993. doi:10.1145/158511.158524. Sections 1-5.2, 5.3
  (opening)
- Puel, Suárez. Compiling pattern matching by term decomposition. Journal of Symbolic Computation 15, 1993, 1-26.
  doi:10.1006/jsco.1993.1001. Pages 1-2, read as images (E15b)
- PyHaskell: Trace-based just-in-time compiler for Haskell with RPython. Master's thesis, NTNU, 2013, author not
  confirmed. https://hdl.handle.net/11250/253137. Abstract, as search-result text
- Regehr, Chen, Cuoq, Eide, Ellison, Yang. Test-case reduction for C compiler bugs. PLDI 2012.
  doi:10.1145/2254064.2254104. Abstract
- Reid. Putting the spine back in the Spineless Tagless G-machine: an implementation of resumable black-holes. IFL 1998.
  doi:10.1007/3-540-48515-5_12. Full
- Rohou, Narasimha Swamy, Seznec. Branch prediction and the performance of interpreters: don't trust folklore. CGO 2015.
  doi:10.1109/cgo.2015.7054191, not in `dois.tsv`. Sections 1-2, 5 skimmed (E15b). Cited as Rohou et al. 2015
- Röjemo. A concurrent generational garbage collector for a parallel graph reducer. IWMM 1992, LNCS 637, from memory:
  the PDF prints no venue (no DOI). Abstract, introduction and 2; the rest skimmed (E15b). A chapter of Röjemo's thesis,
  and the collector that never tenures updatable nodes
- Röjemo. Highlights from nhc: a space-efficient Haskell compiler. FPCA 1995, 282-291. doi:10.1145/224164.224217. Full
  (E15b). It measures the compiler's own heap, nothing on selector thunks
- Röjemo. Generational garbage collection without temporary space leaks for lazy functional languages. IWMM 1995, LNCS
  986, 146-162. doi:10.1007/3-540-60368-9_22. Full (E15b). Cited as Röjemo 1995b. It ages nodes, and finds never
  tenuring updatable nodes "a bad idea" on lmlcomp (§5.4); that policy is Röjemo 1992's
- Rossberg. HaMLet: to be or not to be Standard ML. Version 2.0.1 manual.
  https://people.mpi-sws.org/~rossberg/hamlet/hamlet-2.0.1.pdf; with Defects in the Revised Definition of Standard ML.
  Sections 1.2, the conclusion on test cases, change log entries
- Runciman, Naylor, Lindblad. SmallCheck and Lazy SmallCheck: automatic exhaustive testing for small values. Haskell
  Symposium 2008. doi:10.1145/1411286.1411292. Sections 1, 4, 5 in part
- Runciman, Wakeling. Heap profiling of lazy functional programs. JFP 3(2), 1993, 217-245.
  doi:10.1017/s0956796800000708. Sections 3-4 in part
- Russo. Recursive structures for Standard ML. ICFP 2001. doi:10.1145/507643.507644. Sections: abstract, 1, the opening
  of 2 (E15b)
- Sansom, Peyton Jones. Generational garbage collection for Haskell. FPCA 1993. doi:10.1145/165180.165195. Full
- Santos. Compilation by transformation in non-strict functional languages. PhD thesis, Glasgow, 1995.
  https://www.microsoft.com/en-us/research/wp-content/uploads/2017/03/santos-thesis.pdf (no DOI). Sections 2.4, 3.5,
  3.7, 4.2, 5.2.2, 6.6, 10, and tables 3.5-6.6
- Sarkar, Waddell, Dybvig. A nanopass infrastructure for compiler education. ICFP 2004. doi:10.1145/1016850.1016878.
  Sections 1-2
- Sato. Proposal: Fix a "bug" in the layout interpretation algorithm in Section 10.3 of Report 2010. haskell-prime, 29
  April 2019. https://mail.haskell.org/pipermail/haskell-prime/2019-April/004450.html. Full
- Schilling. Challenges for a trace-based just-in-time compiler for Haskell. IFL 2011, LNCS, 2012.
  doi:10.1007/978-3-642-34407-7_4. Sections 3-4 (E15b). Cited as Schilling 2012; superseded by his thesis
- Schilling. Trace-based just-in-time compilation for lazy functional programming languages. PhD thesis, Kent, 2013 (no
  DOI). Sections 1.3, 2.6, 3.10, 3.11, 6.3, 6.6, 6.8 (start), 7.4.1, 8.3, conclusions, from a copy attached to a GitHub
  issue
- Scott, Ramsey. When do match-compilation heuristics matter? Virginia technical report, May 2000 (no DOI). Full
- Sergey, Vytiniotis, Peyton Jones. Modular, higher-order cardinality analysis in theory and practice. POPL 2014.
  doi:10.1145/2535838.2535861. Sections 1, 2, 6, 7
- Sestoft. ML pattern match compilation and partial evaluation. Partial Evaluation, LNCS 1110, 1996.
  doi:10.1007/3-540-61580-6_22. Sections 7.3, 7.5 (start), 8
- Sestoft. Deriving a lazy abstract machine. JFP 7(3), 1997, 231-264. doi:10.1017/s0956796897002712. Sections 1-3.3,
  3.5, 4, 5 (start), 7, 8, 9
- Seward. Generational garbage collection for lazy graph reduction. IWMM 1992, LNCS 637, 200-217.
  doi:10.1007/bfb0017191. Sections 1-3; 4 skimmed (E15b)
- Shao, Appel. Efficient and safe-for-space closure conversion. TOPLAS 22(1), 2000. doi:10.1145/345099.345125. Sections
  1-2, OCR text
- Shao, League, Monnier. Implementing typed intermediate languages. ICFP 1998. doi:10.1145/289423.289460. Sections 1, 3
  (opening)
- Sparud. Fixing some space leaks without a garbage collector. FPCA 1993, 117-122. doi:10.1145/165180.165196. Full
  (E15b)
- Sulzmann, Chakravarty, Peyton Jones, Donnelly. System F with type equality coercions. TLDI 2007.
  doi:10.1145/1190315.1190324. Sections 1, 2 (opening), 2.4, 3.8-3.10, as the 2011 version
- Sulzmann, Odersky, Wehr. Type inference with constrained types. Karlsruhe, about 1997.
  https://publikationen.bibliothek.kit.edu/26696/1987 (no DOI). Section 6
- Tarditi, Morrisett, Cheng, Stone, Harper, Lee. TIL: a type-directed optimizing compiler for ML. PLDI 1996.
  doi:10.1145/249069.231414. Sections 1, 2 (openings)
- Turner. A new implementation technique for applicative languages. Software: Practice and Experience 9, 1979, 31-49.
  doi:10.1002/spe.4380090105. Sections: abstract, introduction; the rest skimmed (E15b)
- Volpano, Smith. On the complexity of ML typability with overloading. FPCA 1991. doi:10.1007/3540543961_2. Abstract
- Vytiniotis, Peyton Jones, Schrijvers. Let should not be generalized. TLDI 2010. doi:10.1145/1708016.1708023. Sections
  1-3.3, 6.3
- Vytiniotis, Peyton Jones, Schrijvers, Sulzmann. OutsideIn(X): modular type inference with local assumptions. JFP
  21(4-5), 2011, 333-412. doi:10.1017/s0956796811000098. Sections 1, 2.1-2.2, 3.5-3.6 in part, 4, 4.1, the opening of
  4.2
- Wadler. Fixing some space leaks with a garbage collector. Software: Practice and Experience 17(9), 1987, 595-608.
  doi:10.1002/spe.4380170904. Full
- Wadler, Hughes. Projections for strictness analysis. FPCA 1987. doi:10.1007/3-540-18317-5_21. Sections 0, 1, 5
  (start), 8
- Wadler, Taha, MacQueen. How to add laziness to a strict language without even being odd. Workshop on Standard ML, 1998
  (no DOI). Full
- Wakeling. Compiling lazy functional programs for the Java Virtual Machine. JFP 9(6), 1999.
  doi:10.1017/s0956796899003603. Sections 1, 2, 3 (opening), 7-13
- Wansbrough, Peyton Jones. Once upon a polymorphic type. POPL 1999. doi:10.1145/292540.292545. Sections 1, 9 and a pass
  over the type rules, as the technical report. `downloads/papers/wansbrough99.pdf` is the talk slides
- Yang, Chen, Eide, Regehr. Finding and understanding bugs in C compilers. PLDI 2011. doi:10.1145/2345156.1993532.
  Sections 1, 2.1, 2.2, 2.6, 3 (introduction), 3.1, 3.3, 3.5, 4
- Yang. Backpack: towards practical mix-in linking in Haskell. PhD thesis, Stanford, 2017, the "augmented" edition.
  https://purl.stanford.edu/zf998bz8716 (no DOI). Sections 9.1-9.2, appendix B.1-B.2, and searches of the rest (E15b).
  It gives no account of why GHC needs boot files

**Sources** under `/home/ruud/haskell`, cited in place, at these revisions:
- GHC `902339d332`, tag `ghc-9.14.1-release`, also `/home/ruud/reference/ghc`. The binary run is 9.4.7
- nhc98 `b4d4152`, version 1.22
- Yhc `c669451`, version 0.7.0
- Hugs `2719ab8`, the September 2006 tree
- MicroHs `f17be7f0`, version 0.16.12.0
- UHC `f2b94a90`
- jhc `1ff035af`
- hbc `5a417fe`, version 0.9999.4
- Programatica `a3bb039`, and the library files from HaRe 0.6 (`downloads/hare-0.6/`), which the local tree lacks
- Helium `5928bff4`, version 1.9
- haskell-src `bce81d2`, version 1.0.4.2
- haskell-src-exts `bf2917a`, version 1.24.0
- tree-sitter-haskell `97288e5`

**Sources** under `/home/ruud/reference`:
- OCaml 5.5.1 `46e1c324fb` and 4.14.4 `2257629c20`
- SML/NJ `6c476227`
- MLton `b15e2d289`
- MLKit `6dab5582`
- Racket `bbf7dea831`

**Pages:**
- The Hugs 98 manual, its page on differences from Haskell 98: https://www.haskell.org/hugs/pages/hugsman/diffs.html,
  read through a fetch on 2026-11-01
- "There are mutually recursive programs that GHC can't compile", Haskell Discourse, 2026-06-25:
  https://discourse.haskell.org/t/there-are-mutually-recursive-programs-that-ghc-cant-compile/14316
- Eta, slides, ICFP 2018; Mu, HIW 2021 and 2022 abstracts (icfp21.sigplan.org, icfp22.sigplan.org), now with the
  report and slides under Dijkstra, Magalhães, Néron 2024
- Peyton Jones, glasgow-haskell-users, 8 February 2006, on optimistic evaluation:
  https://mail.haskell.org/pipermail/glasgow-haskell-users/2006-February/009658.html, read through a fetch

### Papers for the owner

The owner supplied 53 files on 2026-11-09. They cover 47 of the 54 keys E15 asked for, and the papers they hold are in
the list above. Still missing, of what a decision cites:
- Peyton Jones 1987, the book (D19, D31). E15 read sections of Microsoft's copy, listed above; the dependency analysis
  the Report cites in 4.5.1 was not among them.
- Röjemo's thesis in full: *Garbage Collection, and Memory Efficiency, in Lazy Functional Languages*, Chalmers 1995,
  ISBN 91-7197-126-2, https://research.chalmers.se/en/publication/1353. One chapter came, the 1992 collector.
- Hall et al. The Glasgow Haskell compiler: a retrospective. 1992. doi:10.1007/978-1-4471-3215-8_6 (D39, D40). Only its
  abstract was seen.
- Flatt, Felleisen 1998, above (D30): the precedent for keeping a cycle's units apart, if one unit per SCC is too slow.
- PyHaskell, the NTNU thesis of 2013, above (D47): the repository gave no PDF.

Frege and Eta have no paper to supply: none was located for Frege, and Eta has only its ICFP 2018 slides.

## Appendix: defects

Under the drafts' `results/defects/`. Nothing here was fixed on master.

| Directory | What | State at `b12141ecc` |
|---|---|---|
| `equality-nonuniform` | `=` on a non-uniform datatype: the compiler overflows its stack at `-O2` | live; plain SML; *reproduced*; a bound on the type fixes it |
| `passes-unknown-name` | `--passes=nosuchpass` accepted, runs no optional pass; `--dump-after` of an unknown name prints nothing | live; *reproduced* |
| `specialise-polyrec` | `makeCopy`, `staticParams` ignore type arguments on polymorphic recursion | latent: no SML source reaches it |
| `lower-nary-local-fun` | Lower stops on a local function of two parameters at `-O0` | reachable only with `E1-readmid.patch`: on stock master `--read-mid` stops before Lower |
| `ind-not-final` | The collector takes `K_IND` as final, with a body outliving its update | latent: no engine makes `K_IND` |
| `latent-k-ind` | The shortcut on `'a susp susp`; `share.c`, `image.c` on `K_IND` | latent |
| `simplify-drops-local-fun` | Simplify leaves a call of a function it dropped | seen with E2's prims only; not reproduced on stock |
| `docs-units-runsh` | `docs/units.md:637,704` name scripts that do not exist | a stale document |

## Appendix: prototypes

Each is a patch under the drafts' `patches/`, and is evidence, not code to land as it stands.

| Patch | Experiment | What |
|---|---|---|
| `E1-readmid.patch`, `E1-midtext-functor-name.patch`, `E1-simplify-polyrec.patch`, `E1-all-prototypes.patch` | E1 | Mid to bytecode, functor names in text, polymorphic recursion, Mid units |
| `E2-B-prims.patch`, `E2-C-instructions.patch`, `E2-all-forms.patch` | E2 | Forms B, C, and every form with F, G and L |
| `E4-cast-modes.patch`, `E4-cast-lint.patch`, `E4-simplify-casts.patch` | E4 | Cast erasure, the lint, Simplify through casts |
| `E5-integer-prims.patch` | E5 | Immediate `Integer`, `any_check` |
| `E11-1` to `E11-11`, `E11-all.patch` | E11 | Rune's contract |
| `E13-1-store.patch`, `E13-2-toy.patch`, `E13-3-parts.patch` | E13 | The store split, the toy language, two-file entries |
| `E14-lazy.patch`, `E14-lazy-cumulative.patch` | E14 | Lazy ML, on V's tree |

`results/E10/spike/` is the parser, `results/E16/merge.py` the merged layout, D36's fallback, `results/E9/clauses.tsv` the conformance table, `results/E8/` the corpus, `results/E5/mrhc.py` the lowering. The worktrees `.worktrees/hs-*` hold the same; their cleanup is the owner's.

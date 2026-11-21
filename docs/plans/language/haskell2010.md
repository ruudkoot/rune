# Roadmap: Haskell 2010 for rhc, its extensions, and how rhc tracks language settings

**rhc gains a second edition, Haskell 2010, chosen per program by `--language`, with each module's language a record
of features that every stage reads and every unit key carries. The 2010 Report makes 18 changes, not the 4 its preface
lists: 13 to the language, the rest to the libraries, the Prelude, the text and its numbering; none but the FFI
touches anything below Core. Its library is 30 modules, 26 of them prose without code. Its foreign function interface
is required and needs three small changes of Rune and one large one, on which the owner decides. Beyond 2010's own
six, 66 more of GHC's 148 LANGUAGE names are recommended, 72 in all: none needs OutsideIn(X), and those that touch
types fit the Haskell 98 checker extended by a deferred store of class constraints, as prototypes of tiers T1, T2,
T4a and T5 showed (T3 and T8 were not prototyped). 98 mode stays Haskell 98: it takes one alignment, `genericLength`'s
type (D13a); three recommended options touch it at its edges (D2: a file naming `Haskell2010` is read as 2010; D6:
`--print` keeps header pragmas; D8: `--names=greatest` stops reaching the library, one pinned test going from 958 to
955 pairs); and M18 fixes two checker defects. Each needs the owner's word.** Nothing here is decided; the owner
decides at G0.

- **The 2010 language is front-end work.** Pattern guards, empty data declarations, DoAndIfThenElse, n+k removed,
  relaxed dependency analysis, `foreign` reserved, hierarchical names and the LANGUAGE pre-scan were prototyped in 350
  lines of code; nothing below the front end changed, and 98 mode stayed byte-identical over 591 programs, the run
  set and 633 refusals (E3). rhc's fixity resolution was already 2010's algorithm.
- **The library is mostly prose.** The Prelude's code is 98's but for three renamed imports (E1); around it, 26 of 30
  modules come without code, so rhc writes them, from 98's code where a module continues and from `base` 4.3, whose
  documentation the chapters are, where the prose is thin (E9). About 4,660 lines of Haskell, half of them Foreign.*.
  Two of the four printed modules do not compile as printed (*Found while writing*).
- **The FFI** carries all four kinds of `ccall` import over Rune's libffi bridge, end to end, with the optimiser keeping
  IO calls in order and pure imports lazy (E10). Rune is asked for three small changes and, for `Ptr` as an address, a
  large one to its safety model (D29). `foreign export` needs an embedding API Rune lacks: it waits only on the owner's
  word, since leaving out a required feature is no ground for a departure (D28).
- **One record of language settings** replaces the per-run refs and the hard-coded `haskell98`, with the library a
  descriptor per edition (E4). Its resolution mirrors GHC's, written as data and checked on 137 probes (132 agree; the
  5 that differ lie outside resolution: GHC's `forall` and prefix `!`, and two OverloadedStrings programs the
  predictions misjudged) (E5, E13). Under 43 edits of pragmas and editions the
  store gave the bytes of a cold compile every time (E13).
- **Extensions:** all 148 LANGUAGE names classified by area, tier of type-system machinery (T0-T8), Core and runtime
  needs, HsLint's cost, usage on Stackage and a recommendation (E6, E7). Multi-parameter classes, functional
  dependencies, existentials and the core of rank-N types were built in the checker and in HsLint on today's unifier
  with a deferred class store, 98 mode's bytecode and messages unchanged with every switch on, its interface bytes
  not (D9) (E12). The line is GADTs and type families
  (OutsideIn), kinds, and meta-programming. Even so, every recommended extension admits 28.3% of Stackage's packages
  whole: this roadmap does not make Hackage compile (E7).
- **98 mode and the 2010 text:** of 232 readings, deviations, overlay entries and rulings, two pass the brief's
  test and one is recommended, `genericLength` (D13a); two more differ but would override 98's plain text, among them
  `isUpper` of a caseless letter, the case that looked arbitrary and was rhc following 98's text (E2).

**What the owner decides at G0.** All 44 decisions, of which these need a judgement rather than evidence: D2, D3, D6,
D7 (C8), D8 (`--names=greatest` changes one pinned test), D13a-D13d (98 mode), D16 (a reading of 4.5.1), D21 (`Int`
modulo 2^n in 2010 mode), D23 (the library's cycle), D27 (stdcall off Windows), D28 (`foreign export`), D29 (`Ptr`
and Rune's safety model), D31 (callbacks outside a call), D32 (Foreign.C.Types' constructors), D33, D38 (98's errata
in 2010's text); and, within D35 and D37, the fundep coverage regime and how T5 reaches Mid. Four recommended options
change 98 mode: D2, D6, D8 and D13a; every option that would is said in bold where it is argued. Four findings about
98 mode are the owner's too: two checker defects at the pin, and two readings with surprising results, R20's refusal
of an unsigned `main = return ()` (in 2010 mode too) and R41's derived `Show` of records (*Found while writing*).

**Where it departs from the brief** (*What the brief gets wrong*): the library is per program and an edition pragma
sets one module's rules (D1, D2); the default flips at G3, on the 2010 Report's exit, not when the extensions are done
(D3); `foreign export` may wait, by the owner's word (D28); GHC2021 and GHC2024 are not accepted as editions. D29,
the owner's call on Rune's safety model, holds G2's FFI. A 2010 clause tier adds 19% to 44% to `make check`'s CPU
base (D41).

**In what order.** Tracks T (tests), M (modes) and H (98 mode's fixes) start at once; F (the 2010 front end), L (the
library) and V (the FFI) after M4's record; X (extensions) after M5, never gating G2 or G3. G1 is a 2010 hello with a
pattern guard from the 2010 snapshot; G2 the 2010 Report's exit; G3 the default flip (*The milestones*).

**What is not established.** No Rune change was built. The library's 3,470 new lines and the production sizes of the
tiers are estimates (E9, E12). The corpora barely use 2010's own changes (pattern guards in 5 of 1,279 accept
candidates: E8), so the 2010 table needs clause programs of its own. The 98-mode identity checks met no LANGUAGE
pragma (*Testing and conformance*). The final build of E12's tiers was not run over the corpus.

It was written on 2026-11-17 and 2026-11-21 against `haskell98` at `75ed95861`, and its citations stay there; the
other session's 24 later commits are in *Where we are*. It lives on branch `haskell2010`.

What it rests on:
- **The code:** rhc at the pin, read and prototyped (*Where we are*; E3, E4, E10, E12, E13).
- **Both Reports, clause by clause:** 5,259 rows of 2010 mapped to 98's 3,901 (E1), and every 98 choice set against
  2010's text (E2).
- **Thirteen experiments by twelve agents** (*The experiments*), among them five prototypes kept as patches, a census
  of 148 names, 49,394 Stackage modules, three oracles beside GHC and a 2010 shim for it, and the literature.

## Status

Not decided. G0, the owner's decisions, is next. No milestone has started.

| Milestone | Track | Size | Rests on | Status |
|---|---|---|---|---|
| M1. The 2010 clause table and its enforcement | T | M | D38, D41 | not started |
| M2. Oracles and corpora for 2010 | T | M | D39, D40 | not started |
| M3. 98 mode held byte-identical, a standing check | T | S | the standing gate | not started |
| M4. The language record and the library descriptor | M | L | D4, D8, D9, D10 | not started |
| M5. The header pre-scan, errors, diagnostics, printers | M | M | D5, D6, D7, D11 | not started |
| M6. `--language`, edition pragmas, the 2010 snapshot | M | S | D1, D2 | not started |
| M7. n+k off, DoAndIfThenElse, empty data, `foreign` | F | S | D15, D17, D27 | not started |
| M8. Pattern guards | F | S | D14 | not started |
| M9. Relaxed dependency analysis | F | S | D16, D10, D7 | not started |
| M10. Hierarchical names in 2010 | F | S | D18, D8 | not started |
| M11. Defaulting per edition; `Int` in 2010 | F | S | D20, D21 | not started |
| M12. The 2010 Prelude and the printed modules | L | L | D23, D24, D25 | not started |
| M13. The nine continuing modules | L | L | D24, D26 | not started |
| M14. Data.Bits, Data.Int, Data.Word, System.* | L | L | D22, D21 | not started |
| M15. The FFI in Core, and Rune's three small changes | V | M | D27, D31, D32 | not started |
| M16. Foreign.*, Ptr, finalizers, StablePtr | V | L to XL | D29, D30, D33 | not started |
| M17. `foreign export` and HsFFI.h, if taken | V | M | D28 | not started |
| M18. 98 mode: `genericLength` and two checker defects | H | S | D13a | not started |
| M19. Front-end and T0 extensions | X | L | D35, D36, D7 | not started |
| M20. CPP | X | M to L | D12 | not started |
| M21. Deriving | X | L | D35, D37 | not started |
| M22. A+ and T1 | X | L | D34, D35, D7 | not started |
| M23. T2, FunctionalDependencies | X | M | D34, D35 | not started |
| M24. T3 | X | M to L | D34, D9, D36 | not started |
| M25. T4a, existentials | X | L | D34, D37 | not started |
| M26. T5, RankNTypes | X | L | D34, D37 | not started |
| M27. T8 | X | S | D35, D36, D10 | not started |
| M28. The default flip | D | S | D3 | not started |
| M29. Retire | D | S | | not started |

Gates: G0, the owner's decisions; G1, a 2010 hello with a pattern guard on the interpreter and the VM from the 2010
snapshot, 98 byte-identical; G2, the 2010 Report's exit; G3, the default flip; and the standing gate on 98 mode's
bytes and SML's.

## Found while writing this roadmap

Every item has a reproducer or a citation; *Appendix: defects* lists the reproducers of rhc's defects and of the
Report's uncompilable code. "At the pin" means rhc at
`75ed95861`.

**In rhc, at the pin**
- **Rule 1 is not enforced by the checker when a signed binding shares a group with an unsigned one.** With
  `f :: Num a => a -> a` using `xs`, and `xs = [f (1 :: Int)]` using `f`, 98's 4.5.1 puts both in one group, which `xs`
  restricts, so `f`'s signature with a context must be refused (4.5.5). The checker accepts it and the program prints
  `(3,3.5,[2])`; HsLint refuses it at lint level 2 (`mr.rule1.constrained`). HsLint is right
  (`results/E3/defects/rule1-signed/`, observed). The checker's Rule 1 code is untouched by the 24 commits after the
  pin, so the defect is very likely on `haskell98`'s tip too [deduced]. Not fixed at the pin; M18 fixes it on the
  owner's word.
- **The checker accepts a signature more general than a non-simple pattern binding gives.** `p :: a -> a` with
  `(p, q) = (not, 'x')` compiles and prints `(False,'x')` in both modes; HsLint refuses it at level 2
  (`dec.sig.toogeneral`), as GHC refuses it (`results/D16-probes/`, observed). The checker unifies such a variable with
  an instance of its signature, not a rigid one (`lib/language/haskell/infer.sml:1364-1370`) [read].
- **`--dotted-names` was in neither a unit's configuration nor its key.** A program read one way under the flag and
  another without it took the other reading's unit from the store (`results/E3/dotted/`, observed). The other
  session's build-cache work found the same hole and fixed it after the pin (issue 27 of
  `docs/plans/build-cache-issues.md` on `haskell98`).
- **`docs/rhc.md:319-327` is stale.** It says rhc does not meet the conformance rows "whose status is `Planned`";
  every one of the 3,901 rows has been Supported since `82b5e482c`, and the text is unchanged at the tip.
- **The library's file list is flat.** `RhcGraph.libraryFiles` lists only the top level of the library directory
  (`src/rhc/graph.sml:122-138`), and the numbering of the library's fresh names reads that list
  (`src/rhc/names.sml:117-130`). A hierarchical library (`Data/Char.hs`) needs it to recurse [deduced].

**In the 2010 Report** (the text of 2010-07-20; no errata to it were ever published: E1)
- **The preface lists 4 changes from 98; the text makes 18** (E1, Delta1-Delta18; T10:1287-1294).
- **`0**y` "is 1 if y is 1, and 0 otherwise"** (T10:6389-6390): a misprint for "y is 0"; for a negative y it
  contradicts IEEE either way (D13b).
- **Rule (s) of 3.17.3 names a variable it never uses:** "where y is a new variable" (T10:3438-3447). Erwig and
  Peyton Jones's original binds the fall-through once.
- **Two of the four printed library modules do not compile as printed.** Data.Maybe defines and exports a `maybe`
  beside the Prelude's (T10:13431-13440): GHC 9.4.7 reports an ambiguous occurrence (`results/E9/probes/MaybeClash.hs`),
  and hiding the Prelude's breaks every user of Data.Maybe (`results/E9/probes/maybeprobe/`). Data.Ratio's `Show`
  instance is a parenthesis short (T10:13723-13730; GHC: a parse error).
- **The other printed code has defects too:** Data.Array's is headed `module Array (` (T10:11476) and keeps the dead
  `import Data.List( (\\) )` (T10:11481); Data.Complex's synopsis prints its export as `Complex(:+)`, a parse error in
  GHC, though its code has `Complex((:+))`; the Ix law has a stray parenthesis (E1).
- **Foreign.C.Types contradicts chapter 8.** 8.4.2 says the module does not export its newtypes abstractly
  (T10:6911-6912); its export list does (T10:14480-14485), which by 8.4.2's own rule makes `CInt` unmarshallable outside
  it and refuses the chapter's own examples (D32).
- **Data.Int makes `Int`'s arithmetic modulo 2^n** (T10:12381-12382) where 6.4 leaves overflow undefined (T10:6240);
  and it says a left shift of a negative value by the full width gives -1, where arithmetic gives 0 (N6; D21).
- **Smaller defects of the library chapters:** `type IOError = IOError` (T10:16722); `makeStablePtr`, which no module
  defines (T10:15764); addForeignPtrFinalizerEnv described as "Like addForeignPtrFinalizerEnv" (T10:14984); "(see the
  array package)" (T10:12504); Ix instances listed to 5-tuples where the text requires 15 (T10:12553, 12562); the
  numeric C types' prose omits Real (T10:14828); "are are" (T10:14521, 14828, 14859), "the the" (T10:13221, 16520),
  "((non-associative)" (chapter 20).
- **Eight of 98's eighteen errata are not absorbed** into 2010's identical text, among them `enumFrom`'s `seq` and
  `lex`'s `_`; 10.5 keeps `qvar` in an export where 5.2 says `var` (E1; D38).
- **Chapter 8's grammar and lists are short:** `chname` admits no digit (`x86_64.h`); `Word` is missing from 8.4.2's
  basic foreign types; re-initialising after `hs_exit` is required (N1).
- **A leftover "Haskell 98"** in 5.6.1 (T10:5532).

**In GHC** (9.14.1's source and documents; 9.4.7's behaviour)
- **9.4.7 under `-XHaskell2010` refuses two valid programs that `bugs.rst` does not list:** `1_000` with a variable
  `_000` in scope, and `Just.do` (`results/E6/X1-probes/numund.hs`, `qualdo.hs`).
- **`NoPatternGuards` refuses nothing;** it warns (`compiler/GHC/Rename/Bind.hs:1474-1479`), and `-XHaskell98` accepts
  pattern guards.
- **`bugs.rst` still lists the relaxed dependency analysis as a divergence from Haskell 2010** (`bugs.rst:24, 240-284`),
  which 2010 adopted.
- **`bugs.rst` calls GHC's parenthesised derived `Show` of records a divergence:** "Haskell 2010 calls for ...
  `Just Hello {aField=42}`" (E2). The 98 roadmap's ruling 14 took GHC's row as 2010's choice; 11.4 is 98's text word for
  word.
- **Three errors in GHC's documents:** `empty_data_deriving.rst:11` puts EmptyDataDeriving in Haskell2010; the edition
  lists in `control.rst` omit ListTuplePuns; `overloaded_strings.rst:52-54` says `length "foo"` defaults to String,
  which with base's Foldable `length` it does not (X3, probe P18j).
- **GHC2021 is not closed under its own implications:** its TypeOperators implies ExplicitNamespaces, which it does not
  list, so `module M (type T)` is refused under the default edition (X3, probes P05a, P05b).

**In the other implementations and tools**
- **haskell-src-exts** voids every pragma of a file that names two editions, and drops unknown names silently
  (`haskell-src-exts/src/Language/Haskell/Exts.hs:144-148`;
  unknown names: `haskell-src-exts/src/Language/Haskell/Exts/Extension.hs:749-750`; X3).
- **Cabal passes `-XHaskell98`, not GHC2021, when `default-language` is absent**
  (`Distribution/Simple/GHC/Internal.hs:586`): 1,262 module files of Stackage LTS 24.67 are built as Haskell 98 that way
  (E7).
- **MicroHs has no escape check for existentials** ("XXX must check for leaking skolems", `TypeCheck.hs:2886`), and its
  2024 paper understates its FFI: the tree has `foreign export`, `dynamic`, `wrapper` and an HsFFI.h (W1).
- **jhc refuses multi-parameter classes outright** (`KindInfer.hs:428-430`) though its manual describes functional
  dependencies (W1).

**In the 98 roadmap and its drafts**
- **Three claims marked [memory] are wrong against the 2010 text** (R21(b), R45(g), R41: `results/E2/alignment.tsv`;
  haskell98.md:1303 for the last): that 2010 dropped 4.5.2's identical contexts (it
  keeps them, T10:4752); that `gcd 0 0` is defined in 2010 (an error there too, T10:6336); that 2010 took GHC's row for
  derived records (11.4 is 98's text). Ruling 14's premise rests on the last.
- **98's E9 said chapter 17 gives `genericLength` a `Num` type;** chapter 17's prose and code say `Integral`
  (T98:11645, 12016). It is 4.5.5 that needs `Num`, which is why D13a aligns it.

**In rhc's store and options, by E4**
- **A snapshot's entries depend on the path it was built at.** The layer h10-base inherited names
  `worktrees/h98-cs-base` in 20 files, and 10 of its 33 unit entries differ from the same layer built in another tree
  (`results/E4/README.md`, observed). Issue 31 of the other session's build-cache work (paths in a unit's entry, fixed
  2026-11-17) addresses it after the pin, as issue 9 did for SML units before it.
- **`--names=greatest` lets a program change the library's exports.** At the pin the option also solves the library's
  cycle at the greatest fixpoint, so a program's `T1.map` enters the library List's exports;
  `tests/hs/names/imp/greatest.names` pins the 958 pairs that gives. With the library read under its own language the
  dump has 955, as under the least fixpoint (E4, observed). D8 asks the owner which to keep.

**In GHC, by E8**
- **GHC types a fractional literal's argument as base's `Rational` even under RebindableSyntax,** so no shim can give
  a 2010 program the Report's `Ratio`; and GHC marshals a newtype only when its constructor is in scope, so a shim that
  follows Foreign.C.Types' printed export list cannot compile the chapter's own FFI examples (`results/E8/limits/`).

**In 98 mode, by E12 and V2**
- **rhc refuses an unsigned `main = return ()`.** Rule 2's defaulting runs at the module's end, before `main`'s
  `IO t` is applied, so `m` in `Monad m => m ()` meets no default (R20's reading). A direct probe shows the refusal and
  the signed program accepted (`results/verify/V2/r20/run.out`); E12 met it in GHC's GivenOverlapping test with T2 on
  (`results/E12/ghc/run-T2-on.tsv`). 2010 mode inherits it, its 4.5.5 being 98's text: a reading for the owner in both
  modes.

## The request

The owner's brief, as written. It is `docs/plans/language/haskell2010.md` in the main tree, untracked, and this
roadmap replaces it on its branch:

> - this is a draft roadmap to add a haskell 2010 support to rhc
>   - please review this draft carefully and object if you disabree with anything
> - rhc needs to support both haskell98 and haskell2010 with a --language=haskell98 or --language=haskell2010 (default to 2010 after the roadmap is complete)
> - the specification can be found at https://www.haskell.org/onlinereport/haskell2010/
>   - ghc may be able to be used as a reference as well but be careful with it like for haskell 98 as it does not always agree with the report even in strict haskell 2010 mode. rhc aims to follow the report as closely as possible.
>   - the haskell98 mode needs to stay haskell 98 as per its report. in case we made an arbitrary choice during the haskell98 roadmap in rhc because the haskell 98 report was ambiguous or underspecified you may bring rhc in haskell98 mode in line with haskell 2010 (reading the haskell 2010 report as clarifying what the haskell 98 should have said, but be very explicit in the roadmap that you will be doing so, so i can review)
> - haskell 2010 has a different standard library than haskell 98. please store the haskell 2010 prelude under share/rhc/haskell2010 to keep it distinct from share/rhc/haskell98. --language= also selects the right prelude.
> - in addition to the language extensions required by the haskell 2010 reports also survey ghc's documentation and implementation for further language extensions
>   - we aim to implement as many of the extension as possible without adding outsidein(x) - that will require a full roadmap on its own - or that are highly ghc specific or require extensive runtime support
>   - classify each extension by area (parsing, desugaring, type system, runtime, ..), implementation complexity, if it can and should be implemented on the haskell 98 type system, i.e. before we have outsidein(x) and a recommendation if we should implement as part of this roadmap or defer to a future roadmap.
>   - specifications are ghc's documenation and implemenation, possibly implementations of some of the other haskell compiler and the academic literature
> - design a good way to track language extensions during rhc combination as we will have language pragma's in the source code (no necesailty corresponding one-to-one to how rhc will keep track of language flags), compiler flags on the command line, etc.

The owner answered three questions about the campaign on 2026-11-17, before any research ran:

- **When to start**, with another session's agents still at work on `haskell98`: at once, capped.
- **How much of Hackage to read**: its index, and the latest source of each package in the current Stackage LTS
  snapshot.
- **Whether to push this branch**: no.

## What the brief gets wrong, leaves open, or makes dangerous

The brief asks for objections ("please review this draft carefully and object if you disabree [sic] with anything").
Each item is held to the 2010 Report, rhc's code at `75ed95861` and the experiments, and names the decision that answers
it.

### Wrong, or out of date

- **W1. "haskell 2010 has a different standard library than haskell 98".** The Prelude is not what changed. Of its 927
  non-blank lines of code, 915 are the same as 98's, 9 differ in tabs, and 3 rename an import (`Ratio` to
  `Data.Ratio`, `Char` to `Data.Char`) (E1). What changed is the library around it: 5 of 98's 16 modules are gone,
  11 continue as 13, and 17 are new, 30 in all (E9). The deeper change is that 26 of the 30 come without code: the
  Report prints signatures and prose taken from GHC's `base` 4.3, and code for the Prelude and four modules only
  (Data.Array, Data.Complex, Data.Maybe, Data.Ratio). The Prelude itself imports two of the codeless ones, Data.Char
  and Numeric (T10:8867-8869). So "store the haskell 2010 prelude under share/rhc/haskell2010" is the easy part; writing
  26 modules against prose, with `base` 4.3 as the source of truth where the prose is thin, is the work (D23, D24).
- **W2. "--language= also selects the right prelude".** It can, per program; it cannot per module. A LANGUAGE pragma
  is per module and a library is per program: two Preludes cannot meet in one program. GHC's editions select no
  library (`{-# LANGUAGE Haskell98 #-}` with `import Monad` fails: E5, probe P17e), and the 2010 committee left
  library selection to implementations (E11). So `--language` chooses the library and the default rules, and an
  edition pragma chooses one module's rules (D1, D2).
- **W3. "the language extensions required by the haskell 2010 reports".** The Report's own list is four: the FFI,
  hierarchical module names, pattern guards, and n+k patterns removed (T10:1287-1294). A word-by-word diff of the whole
  text finds 18 changes, 13 of them to the language (E1, Delta1-Delta18), among them DoAndIfThenElse, empty data
  declarations with a sixth condition on deriving, 98's precedence-indexed grammar replaced by `infixexp` and 10.6's
  resolution, the relaxed dependency analysis, the LANGUAGE pragma, `:` joining `ascSymbol`, `foreign` reserved,
  defaulting reaching `Bits`, and 98's chapter 23 on how a program ends removed. The preface is not the scope; the
  clause table is (D38).
- **W4. "without adding outsidein(x)".** OutsideIn is one line of several, and "the haskell 98 type system" is not
  one thing. rhc's checker solves class constraints at once against an instance index of one class and one type
  constructor (`lib/language/haskell/classes_sig.sml:18, 39`); its predicates take one type
  (`lib/language/haskell/types_sig.sml:59`); its types have no forall (`types_sig.sml:46-51`). On that, an extension
  needs one of nine things, the tiers T0 to T8 (*The extensions*): rank-N types need bidirectional checking, kinds a
  kind system, MonoLocalBinds a different generalisation, and only GADTs and type families need OutsideIn. Two
  results from the literature move the line (E11): local class givens on a universal variable lose principal types
  without any GADT (OutsideIn's own example), so existentials split into a safe part (T4a) and a part that belongs with
  OutsideIn (T4b); and improvement by a functional dependency from a given cannot be elaborated to System F, so it must
  be refused, as GHC does. T1 to T5, with T4 as T4a, have been built twice without implication constraints, in Hugs and
  in MicroHs, on a unifier with a deferred store of class constraints (D34's A+).
- **W5. "... or require extensive runtime support"** cannot apply to the FFI: it is chapter 8 of the 2010 Report.
  `ccall` is required (T10:6828), and `foreign export` is defined beside the imports (T10:6968-6978). Rune's FFI
  carries all four kinds of import, prototyped end to end (E10), but has no raw address, no finalizer, no StablePtr
  outside C, and no way to export a function to C. Leaving any of these out is none of the grounds the 98 roadmap's
  D38 gives for a departure (wrong, contradictory, ambiguous, conceded by the Report). D27-D33; D28 in particular asks
  the owner whether `foreign export` may wait.
- **W6. "ghc ... does not always agree with the report even in strict haskell 2010 mode".** True, and further than the
  brief says. GHC's Haskell2010 edition adds DeepSubsumption, ListTuplePuns and ImplicitStagePersistence
  (`compiler/GHC/Driver/DynFlags.hs:1332-1349`); RelaxedPolyRec cannot be turned off
  (`compiler/GHC/Driver/Flags.hs:116-117`), so GHC is no oracle for 98's stricter dependency rule; 9.4.7 under
  `-XHaskell2010` refuses valid 2010 programs (`1_000` with a variable `_000` in scope, `Just.do`, `forall` as a type
  variable, a prefix `!`: E6, X1's probes; `docs/users_guide/bugs.rst:44-57`); and its `base` is not the Report's
  library (`Num` without `Eq` and `Show`, `Monad` under `Applicative`, `isSpace` by category Zs, Unicode 14). GHC
  judges 2010 programs only through a shim, and only on what the shim can reproduce: E8's shim (the Report's Prelude
  and 30 modules over GHC 9.4.7, with a defaulting plugin) agrees with the Report on 15 of 23 probes (one of them by
  reading) and departs on 8, each a stated limit (D39).
- **W7. "the specification can be found at https://www.haskell.org/onlinereport/haskell2010/".** It is the edition
  of 2010-07-20, and no errata to it were ever published; ten mistakes were reported on the haskell-prime list from
  2010 to 2019 and none reached the text (E1). Eight of 98's eighteen errata are not absorbed into its identical text
  (among them `enumFrom`'s `seq` and `lex`'s `_`), and its code chapters have defects of their own: Data.Maybe defines
  a `maybe` that clashes with the Prelude's, Data.Ratio's `Show` instance is a parenthesis short, Data.Array's code is
  headed `module Array (` (E1, E9). D38.

### Contradictory

- **C1. "the haskell98 mode needs to stay haskell 98" and "you may bring rhc in haskell98 mode in line with haskell
  2010".** They agree under a test with three parts: 98's text admits two readings, rhc picked one, and 2010 picks
  the other. Applied to all 232 of 98 mode's readings, deviations, overlay entries and rulings, it passes two items,
  two more differ from 2010 only where 98's text was plain, and the obvious candidate is one of those: on `isUpper` of a
  caseless letter rhc followed 98's plain text, so aligning it would override 98, not clarify it. One alignment is
  recommended, `genericLength`'s type, where 98 contradicts itself (D13a). *Haskell 98 mode and the 2010 text* argues
  each.
- **C2. "rhc aims to follow the report as closely as possible" and a library text generated from an
  implementation.** The library chapters are `base` 4.3's documentation (88.9% of their prose lines word for word:
  E9), and in places the text and `base` part: Data.Int says "All arithmetic is performed modulo 2^n" of `Int` while
  `base` raises an overflow error on ``minBound `quot` (-1)``; allocation failure gives `nullPtr` by the text and an
  `IOError` in `base`; `isAlphaNum` admits marks in `base` and not in the prose. The text wins where it speaks;
  `base` 4.3 decides only where it is silent (D24, D21, D26).
- **C3. Data.Int and 6.4.** Within the 2010 Report: chapter 18 makes `Int`'s arithmetic modulo 2^n (T10:12381-12382);
  6.4 leaves overflow undefined. rhc's `Int` is checked (98's D22). D21.

### Ambiguous

- **A1. "a good way to track language extensions".** The brief does not say whether settings are per module or per
  program, how flags and pragmas combine, or what an unknown or unsupported name does. Chapter 12 settles the last:
  "any attempt to compile or otherwise use that file ... must fail with an error" (T10:10990). GHC's semantics, read
  from its source and probed (E5), give precedents for the rest. D4-D11.
- **A2. "ghc's documenation and implemenation".** Two GHCs are at hand: 9.14.1's source, which knows 148 LANGUAGE
  names, and the installed 9.4.7, which knows 137 of them (E5). The survey takes 9.14.1 as its record and marks the
  eleven 9.4.7 cannot probe "source only".
- **A3. "as many of the extension as possible".** As many as possible is not enough to compile Hackage, and the
  roadmap should not let it be read so. On the 3,392 packages of Stackage LTS 24.67, every extension this roadmap
  recommends admits 28.3% of packages whole; every name below T6, whatever its recommendation (TemplateHaskell,
  MagicHash and Safe among them), admits 42.6%, a ceiling and not a set this roadmap proposes; GADTs and type families
  take it to 59.2%, and kinds to 85.2% (E7). The rest is modern `base`, which is not the Report's library either. D35.
- **A4. CPP,** which the brief does not mention, is the most widespread extension of all: on in 46.6% of Stackage's
  packages and 18.6% of their files (E7), and chapter 12's own example (T10:10987). D12.
- **A5. What the 2010 text leaves to the implementation,** which the brief cannot have known: how a program ends (98's
  chapter 23 rules are gone: N21), the Unicode version (98 named 3.0, 2010 none), and how a library is selected (E11).
  These are choices, recorded as such, not deviations (D38).

### Dangerous

- **X1. Extensions that change valid programs.** 67 of the census's 148 names change the meaning or acceptance of some
  valid Haskell 2010 program when turned on: LambdaCase makes `cases` a keyword, OverloadedStrings makes
  `print (length "abc")` ambiguous, BangPatterns reads `f !x` as a bang, every flag that implies ExplicitForAll reserves
  `forall`, MonoLocalBinds stops generalising (E6, `results/E6/census.tsv`; 41 probe modules of X1's measure such
  changes on GHC 9.4.7). An edition such as GHC2021 is a bundle of them. On by default, any of them breaks conformance.
  D36.
- **X2. Every type extension costs twice.** HsLint, rhc's independent checker, must specify each one again, and it has
  no rigid type variables today (`lib/language/haskell/hslint_infer.sml:698-723`), so the tiers from T3 up each cost it
  skolems and an escape check (E6, X2). D41, D34.
- **X3. Untrusted code in the corpus.** A file's own `{-# LANGUAGE TemplateHaskell #-}` runs code at compile time and
  the command line cannot turn it off; a CPP `#include` reads local files. The corpus is filtered before any oracle
  compiles it (D40).
- **X4. A setting that changes how a text is read must be in the unit's key.** At the pin, `--dotted-names` was in
  neither the unit's configuration nor its key; the other session's build-cache work found and fixed it after the pin
  (issue 27 of `docs/plans/build-cache-issues.md` on `haskell98`). Every feature this roadmap adds is a new such
  setting (D9). E3 reproduced the hole at the pin (`results/E3/dotted/`).
- **X5. Ptr as an address changes Rune's safety rule** that SML never sees a native address
  (`docs/plans/runeffi.md:465-467`). The identities that rule gives buy no safety for a pointer C returns, whose extent
  is unbounded: a read 1 GB past `getenv`'s result is a segmentation fault under them (E10). D29 is the owner's.
- **X6. Scope.** A language mode, a library of 30 modules, an FFI, 72 extensions and a tracking design are one
  roadmap. Track X never gates the default flip, and *What is cut first* orders the rest.

### Where this roadmap recommends otherwise than the brief

- **The library is per program; an edition pragma sets one module's rules** (W2; D1, D2).
- **The default flips on the 2010 Report's exit, not on the extensions** (D3, G3): the brief's "after the roadmap is
  complete" would tie the flip to track X. E4 counted what the flip touches: 52 command lines in 17 runner files
  through 9 helpers, 14 Makefile lines and 77 lines of documents (`results/E4/flip-inventory.tsv`); an `RHC_LANGUAGE`
  default set beside `RHC_STORE=` in the test wrapper pins them all in about 6 lines.
- **98 mode takes one alignment only, `genericLength`** (D13a), and not `isUpper`, the place that looked like an
  arbitrary choice and was not (D13c); D2, D6 and D8 change it at its edges outside the alignments, and M18 fixes two
  checker defects, each the owner's.
- **`foreign export` waits, if the owner says so** (D28); everything else in chapter 8 lands.
- **GHC2021 and GHC2024 are not accepted as editions** in this roadmap: they need rank-N types and kinds, and both need
  T6 (GHC2021 through DeriveGeneric's type family, GHC2024 through GADTs too) (E6, X2, W12). Their parts below OutsideIn
  can each be asked for by name.

## Where we are

rhc at `75ed95861`, the tip of branch `haskell98` when this roadmap began, read in the reference tree
`.worktrees/h10-base`. Paths are relative to the repository's root, and line numbers are of that commit. A file of
`lib/language/haskell/` is named without its directory, so `infer.sml:2010` is `lib/language/haskell/infer.sml:2010`;
every other path is given in full. "Observed" means an experiment ran it, and the experiment is named; "deduced" means
it comes from reading the code and nothing ran it. A sentence with a citation and neither word says what the code
does. This section says what is; what to do about it is in *The architecture* and *Decisions*. What the other session
merged on `haskell98` since is the last subsection; the citations here stay at `75ed95861`.

In short:
- **rhc is a compiler of Haskell 98 and of nothing else.** No option names a language, and nothing reads a LANGUAGE
  pragma: a pragma is a comment to every stage.
- **Its settings have no single home.** Each is a ref or an argument of its own, read by the stage that needs it;
  the checker's two are set once per unit, so one unit has one setting.
- **"haskell98" is written into 15 lines of 9 files** of the front end and driver, and the names of six of the
  library's modules into the names, the interfaces, the desugarer and HsLint.
- **Of the 2010 changes,** fixity (10.6), the layout algorithm and the line comment are done; pattern guards, empty
  data, DoAndIfThenElse, the relaxed dependency analysis, `foreign` and dotted names in the library are not; n+k
  patterns are a level of the grammar with no switch.
- **The type system is Haskell 98's in its representations,** not only in its rules: a predicate has one type,
  instances are indexed by class and type constructor, a type has no forall; Core's alternatives bind no types and
  its kinds have no variables. HsLint's second inference is Typing Haskell in Haskell's, with no rigid variables.
- **rhc reaches the runtime only through Core's primitives.** Core has no Word, IntN or bit operation though the VM
  has them, and Rune's FFI is reachable from SML alone.
- **The conformance table has 3,901 rows, all Supported,** held by a runner that hard-codes three counts. Under a 2010
  spike, 21 of 1,475 tests flip (E3).

### What rhc is, and how it is driven

rhc compiles the Revised Report of 2002 with its 18 errata (`docs/rhc.md:3-11`). It is SML, built by Rune alone from
`rhc.build`: the front end and Core are `lib/language/haskell/` (103 files, 27,849 lines), the driver `src/rhc/`
(15 files, 3,736 lines) (counted). A program is read, named, checked and desugared into Core, a typed lazy language of
rhc's; Core to Mid lowers it, and from Mid on it is Rune's compiler and `bin/runevm` (`docs/rhc.md:5-9`). A module `M`
is `M.hs` or `M.lhs` beside the first file given, failing that the library's; a cycle of modules is one unit
(`docs/rhc.md:27-32`).

`bin/rhc` is a script that runs `bin/rhc.rbc` on `bin/runevm` with `--share` and `--snapshot` (`Makefile:830-832`).
`RhcMain.run` (`src/rhc/main.sml:457-473`) splits off the program's arguments after `--` (`:85-97`), takes `--share`,
`--snapshot` and `--whole` (`:439-455`), and sends a command line that names a `.hs` or `.lhs` file or a view to
`RhcSyntax.command` (`:473`); anything else is Core text (`:488`). `RhcSyntax.command`
(`src/rhc/syntax.sml:273-368`) takes the store's options (`:99-108`), sets the refs of its own (`:285-310`), refuses
what no stage knows (`:311-325`), reads three of the compile's options ahead of the units (`:326-339`, below), and
gives what is not its own (`:341-346`) to `RhcMain.haskell` (`src/rhc/main.sml:374-430`), which parses the back end's
(`src/rhc/options.sml:180-262`).

A check or a compile is made in units by default: each strongly connected group of the module graph is a unit,
named and checked from the interfaces of the units before it, desugared alone, checked by HsLint at level 2, and kept
in a store; the library's units come from the snapshot (`docs/rhc.md:51-71`; `src/rhc/driver.sml:1-10`).

### How a setting reaches each stage

There is no record of language settings. Each setting is a ref or an argument, and each stage takes its own:

| Stage | The setting | Where |
|---|---|---|
| Lexer | `{hierarchical : bool}`, given at each call | `lexer_sig.sml:37`, `lexer.sml:7-8, 24`; made at `src/rhc/syntax.sml:244`, `src/rhc/graph.sml:230` and `tests/hs/syntax/driver.sml:28` |
| Parser | the lexer's options and the annotations, `hierarchical` copied into a global `dotted` at each parse | `parser_sig.sml:26`; `parser.sml:159, 1587-1588` |
| Names | `fixpoint`, `Least` or `Greatest`, an argument | `modules_sig.sml:77`; `src/rhc/names.sml:135, 222`; `src/rhc/driver.sml:359`; `src/rhc/iface.sml:123, 149` |
| Fixity | none: fixities by entity | `src/rhc/names.sml:174-179` |
| Checker | `cycleDefault`, an argument per unit, copied into the ref `cycle`; the ref `standard`, set at each call to a prefix test on `thaskell98:` | `infer_sig.sml:42, 60`; `infer.sml:141, 343, 2005-2010`; mapped at `src/rhc/syntax.sml:136-141` |
| HsLint | `cycleDefault : bool`, `false` on the units path | `hslint_sig.sml:70`; `src/rhc/driver.sml:300` |
| Desugarer | the global `HsMatch.order`; `CoreRuntime.strings`, an argument | `match.sml:8-10`; `coreruntime_sig.sml:49-74`; set at `src/rhc/syntax.sml:331-337`, `src/rhc/main.sml:346-354` |
| Core simplifier, back end | refs: `eta`, `cheap`, `unfoldings`, `simplifyStats`; `Pass.level`, `CoreStrict.enabled`, `CompilerSettings.target` | `src/rhc/options.sml:12-25, 180-262` |
| Driver | `fixpoint`, `cycleDefault`, `dotted`, `layers`, `whole`, `strings`, the store's; `RhcIface.byInterface`; `RhcLint.claims` | `src/rhc/syntax.sml:74-97`; `src/rhc/iface.sml:33`; `src/rhc/lint.sml:73` |

The checker is called once per unit (`infer.sml:2005-2010`), and a unit is a cycle of modules, so a cycle whose
modules wanted different rules would be checked under one (deduced). `HsMatch.order` is one for the whole run.

**The store's configuration and keys.** A unit's entry sits under a configuration: rhc's tool name and identity, the
store's version and the hash's probe, then `extra` (`src/rhc/storeconfig.sml:24-26`); the link's adds the unit file's
version, the instruction set, the level, the passes, the width of `int` and the checks of casts (`:31-36`). `extra` is
`RhcDriver.extraOf`: the strings' form, the match's order, `driver=hs`, and `sections=unfoldings` under `--unfoldings`
at `-O2` (`src/rhc/driver.sml:172-178`, used at `:368`). A unit's key is `hs:` and its name, with each member's
identity and the hash of its text (`:231-234`, `:402-403`); a module's header is kept by `module:MODE`, its name and
its text's hash, where the mode is `library`, `dotted` or `program` (`:183-184`; `src/rhc/graph.sml:241`).
`--dotted-names` is in the header's mode and in neither `extra` nor the unit key. So a unit made without the flag is
taken by a compile with it, though the two read the text differently: E3 observed it (`results/E3/dotted/repro.out`:
`(M.Just.id) 'x'` prints `Just 'x'` through the store where `--no-store --dotted-names` refuses the program). Any
setting that changes how a text is read must enter the configuration or the key; the other session fixed this one
(below).

**Which options go whole.** The units path runs for a check (not `--by-interface`) or a compile, not under `--whole`,
and only with `fixpoint = Least` and per-module defaulting (`src/rhc/syntax.sml:142-154`). So `--names=greatest`,
`--cycle-default=scc`, `--whole`, `--by-interface` and every dump read the library whole, with no snapshot and no
store (`docs/rhc.md:73-76, 87-88`). `--strings=whole`, the match's order and `--unfoldings` at `-O2` stay in units and
change the configuration (`docs/rhc.md:77-82`). The rule is that an option that shapes how the library is read goes
whole (`src/rhc/syntax.sml:142-151`); a language would be such an option, unless each has a snapshot (deduced).

**The snapshot.** `make` writes a `Main` that imports the 16 modules of `RHC_LIBRARY_MODULES`, compiles it twice into
the store `bin/rhc.layer` at `RUNE_LINT=2`, once per match order, and prunes every configuration of another rhc
(`Makefile:821-829`). The snapshot is read only, after the program's store and `--layer`'s
(`src/rhc/driver.sml:373-376`; `docs/rhc.md:89-90`). It holds the library's units at `strings=lazy` for the two
orders and nothing else; a unit of another configuration is made at the first compile and kept in the program's
store (`docs/rhc.md:77-82`). The Prelude's group is one unit of 14 modules (observed: `results/E3/dotted/repro.out`
names it). An entry keeps the path each definition was read from (`hsiface.sml:73-74`), so a snapshot names the tree
it was built in (observed by E4, `results/E4/README.md`, *Snapshots*).

**Where "haskell98" is hard-coded.** In code, on 15 lines (counted, comments left out):
- the library's name, which is both its directory under `--share` and the prefix of its modules' identities:
  `src/rhc/library.sml:44`, used at `:49, 51` and `src/rhc/graph.sml:325`;
- defaulting's standard classes, every class of the library: `infer.sml:2010`;
- HsLint: which modules are the library's (`hslint.sml:132, 242-243`), a module's identity (`hslint_env.sml:90`), the
  standard classes (`hslint_env.sml:604`), the Prelude's identity where none is read (`hslint_env.sml:1035, 1049`),
  Core's own types (`hslint_target.sml:64`);
- the Core simplifier: the Prelude's prefix for folding `fromInteger` (`coresimplify_fold.sml:145`), `error` as a
  bottom (`coresimplify_base.sml:186`), Ratio's `:%` (`coresimplify_simp.sml:450`);
- the help text (`src/rhc/options.sml:56, 97`).

Seven more lines are in the test runners: `tests/runner/hslibrary.sml:39, 357`, `tests/runner/hsunits.sml:260-261,
280, 476`, `tests/runner/hsmeta.sml:302`. `Makefile` and `rhc.build` name it in comments only.

**Where 98's module names are hard-coded.**
- `Prelude`: the implicit import (`src/rhc/graph.sml:72-74, 301-302`), the translations' names
  (`src/rhc/desugar.sml:27`; `desugar.sml:16-20`), HsLint (`hslint_env.sml:774-775, 1047`).
- `Ix`: the class and its methods are taken from module `Ix`, not the Prelude (`src/rhc/names.sml:151-161`,
  `src/rhc/iface.sml:105-110`), and HsLint's derivable classes name it (`hslint_env.sml:774-775`). 2010 moves `Ix` to
  `Data.Ix`.
- `Ratio`: the type and `:%` of the translations (`desugar.sml:20`, `desugar_env.sml:282`).
- `PreludeText`: `Read` and `Show` for HsLint's deriving (`hslint_env.sml:774-775`).
- `PreludeBuiltin` and `UnicodePrims`: the two modules no file holds (`src/rhc/library.sml:60-69, 216-220`;
  `desugar.sml:1284`), and the seven hidden modules (`src/rhc/library.sml:53-58`).

### Pragmas

The lexer reads `{-#` as trivia: a nested comment whose third byte is `#` is of kind `Pragma`, nesting is counted, and
it ends at the matching `-}` (`lexer.sml:109-124`, `:396`; `token_sig.sml:42-47`). Trivia attach to the next token,
or to `EOF` at the end (`lexer.sml:61-67, 424-425`). Nothing reads a pragma: the kind is made at `lexer.sml:112` and
tested nowhere, and the exact printer prints every trivium, pragmas among them, as bytes (`print.sml:65-66`). So
LANGUAGE, OPTIONS_GHC, INLINE and SPECIALIZE are all ignored, as the Report allows; the `prag.*` rows pin that
(`tests/hs/accept/prag.unknown.hs`, `tests/hs/lang/prag.specialize.example.hs`).

The lexer's options are fixed before a file is lexed: `HsParser.parseFile` unlits a literate file, lexes it with the
options it is given and parses (`parser.sml:1601-1606`), and its callers build the options first
(`src/rhc/graph.sml:226-234`; `src/rhc/syntax.sml:240-247`). A header's pragmas are trivia of the first token, known
only once the file is lexed. So a pragma that changes the lexer needs a scan of the header before the lexer runs,
after unlitting, and a module's language must enter the header's mode and the unit's key (deduced).

### The front end against each 2010 change

*What the 2010 Report says* gives the changes (E1); here is where each lands in rhc.

- **Pattern guards: absent.** A guard is an expression: `Guard of ann * exp * exp` (`ast_sig.sml:130-132`), read by
  `rhsWith` as `| opExp` (`parser.sml:1021-1068`), which equations and alternatives share (`:1014, 1125`). In an
  alternative a guard whose type took the arrow is read again stopping before it (`:1033-1046`). Qualifiers are read
  already, by `stmt`, which tries a pattern and `<-` and backs off (`:977-1008`). Every site that walks a guard
  assumes a Boolean: the renamer (`rename.sml:247-251`), the checker (`infer.sml:1086-1102`, and the free variables at
  `:1201, 1327`), the desugarer (`desugar.sml:464-472`, `:118`), HsLint (`hslint_infer.sml:416-419, 668-678`;
  `hslint_replay.sml:176`), fixity (`fixity.sml:248`), the dump (`dump.sml:106-108`) and the printer
  (`print.sml:297-298`). The desugarer's `guards` names the fall-through once, at the end (`desugar.sml:469-472`);
  Sestoft's trees bind a clause's right-hand side as a function of its variables and of what its guards fall to,
  reached once its patterns matched (`match.sml:313-324`).
- **n+k: no switch.** `toPat`'s `nk` is the level of the grammar a pattern sits at, not a setting
  (`parser.sml:554-583`): `var + integer` is n+k at `pat`, refused elsewhere and for k = 0 (`:562-567`); a statement's
  pattern is at that level (`:1004`). Without the n+k case the pattern falls to the next, which refuses a variable
  operator in a pattern (`:568-574`; deduced). The checker records n+k evidence as `npk` (`infer.sml:624, 692-694`),
  the desugarer follows rule (s) through the Integral dictionary's superclasses (`match.sml:208-224`), and HsLint
  replays it (`hslint_infer.sml:286, 324`; `hslint_replay.sml:144, 503`).
- **Empty data: refused by the parser, faked in the library.** `data` expects `=` (`parser.sml:1377`), though the
  tree allows no constructors (`ast_sig.sml:149`); the message is "expected `=` in a `data` declaration" (observed:
  `results/E3/run-programs3/results.tsv`). The library's constructor-less types (`share/rhc/haskell98/Prelude.hs:447,
  511, 537, 595, 650, 740`; `share/rhc/haskell98/PreludeIO.hs:24`; `share/rhc/haskell98/PreludeRuntime.hs:79-81`)
  parse only because `elidedData` rewrites each to `data T = PrimT` (`src/rhc/library.sml:115-139`), and the desugarer
  makes each a primitive type of Core, for library modules alone (`desugar.sml:868-872, 1088-1094`). Deriving takes a
  type with no constructors for an enumeration, since `List.all` of nothing holds (`infer.sml:1781`), so every class of
  its list would be derived, Enum, Bounded and Ix among them, where 2010 derives none (deduced). Core and Mid needed
  nothing in E3's spike, which changed only the parser, the checker's deriving, HsLint and the printer
  (`patches/E3-03-empty.patch`): a `Data` declaration carries a list of constructors (`core_sig.sml:87`), Core to Mid
  makes it a datatype of that list (`coretomid.sml:371-372`), and a program of `data Void` and `data Phantom a` ran
  through CoreLint and MidLint on the interpreter and both bytecodes at `-O1` and `-O2` (observed:
  `results/E3/run-programs3/results.tsv`, `empty1`, `empty3`).
- **Dependency analysis: one edge set in two places.** The checker's `groupsOf` (`infer.sml:1135-1247`) takes edges
  over every binding's free variables (`:1208-1211`), checks R21(b), identical contexts in a group, over those SCCs
  (`:1212-1228`), and types the implicitly typed bindings of each SCC as one, a signature cutting nothing
  (`:1235-1243`). HsLint's `groupsOf` has its own successors (`hslint_infer.sml:432-440`, `:437`), and says it is
  THIH's conformant form of 11.6.3 (`:1-6`). The desugarer's `let`/`letrec` grouping is a third SCC
  (`desugar.sml:829-858`), which must keep every edge whatever the checker does (deduced).
- **DoAndIfThenElse: absent.** `if` expects `then` and `else` at once (`parser.sml:746-756`). In a `do` block layout
  puts a virtual semicolon before a line at the block's column (`layout.sml:95-104`), so `then` there is refused:
  "expected `then` after the condition of `if`, found a new line at the indentation of its layout block"
  (`tests/hs/errors/lay.parseerror.thensamecol.expected`).
- **Fixity: already 10.6's algorithm.** `HsFixity` resolves operator sequences after renaming, "the Report's algorithm
  of 10.6, over tokens" (`fixity.sml:43-109`, run at `src/rhc/names.sml:179`): negation is left-associative at 6 and
  cannot be the right operand of an operator of 6 or more (`fixity.sml:80-90`), and mixed associativity is refused
  (`:98`). The two deviations of fixity met while parsing, `lay.parseerror.fixity` and `exp.parse.letnonassoc`
  (`tests/hs/deviations.tsv:2, 9`), are refused there (`docs/rhc.md:281`); 2010 drops the passages they depart from
  (R1, R9; *Haskell 98 mode and the 2010 text*).
- **Layout: unchanged.** `HsLayout` is the algorithm L on demand, with parse-error(t) as `closeImplicit`
  (`layout.sml:121-125`), called only from the parser's block (`parser.sml:668-677`); the module's first `{n}` is owed
  unless the first token is `{` or `module` (`layout.sml:139-148`), which a pragma, being trivia, does not move.
- **The line comment: done.** `--:` is an operator because `HsChar.isSymbol` counts `:` (`char.sml:48-52`), the erratum
  of December 2005 (`tests/hs/errata.tsv:2`; `tests/hs/conformance.tsv:68`), which 2010 writes into `ascSymbol`.
- **`foreign`: not reserved.** The reserved identifiers are 98's (`token.sml:25-46`), and nothing parses a foreign
  declaration.
- **Hierarchical names: for programs, behind `--dotted-names`.** In `large`, with `hierarchical` on, `A.B.c` goes on
  qualifying; off, `A.B` is one QCONID and lexing stops there (`lexer.sml:309-370`, the switch at `:329-330`), so
  `A.B.c` is `A.B . c`. `modid` takes a QCONID as one name under the flag and refuses it otherwise
  (`parser.sml:161-168`), for the header, imports, `as` and an export's `module M` (`:1461, 1527-1528, 1573`). A
  module `A.B` is the file `A/B.hs` beside the first root (`src/rhc/graph.sml:50-57, 277`). The library is never
  dotted: it is lexed without the flag (`:230`) and looked up flat (`:259`), and its directory is listed one level
  deep (`:122-138`), which the numbering of its units' fresh names reads (`src/rhc/names.sml:117-130`). The flag is
  98's D35 (`docs/plans/language/haskell98.md:6608-6632`), which says what would reopen it: "The Haskell 2010 roadmap,
  whose mode has it on" (`:6630`). The corpus harnesses retry a refused program with it
  (`tests/runner/hsrhccorpus.sml:86-107`, `tests/runner/hscorpusrun.sml:96-133`), and `tests/hs/names/dotted/` tests
  it.

### The checker and Core, as they bound extensions

- **A predicate has one type.** `pred = {cls, ty}` (`types_sig.sml:58-59`). The assumption is in the parser too, a
  class declaration binding one variable (`ast_sig.sml:151`) and a class assertion read as a class applied to one
  type (`parser.sml:347-356`); in interfaces, which write a predicate as a class and a type (`hsiface.sml:66`,
  instances at `:85`); in the desugarer's `dictArg`, a dictionary's type being its class applied to one type
  (`desugar_env.sml:187-190`); and in HsLint's `IsIn of id * ty` (`hslint_types.sml:180`) and `predTy`
  (`hslint_target.sml:88`).
- **Instances are indexed by class and type constructor.** An instance is `{id, cls, tycon, vars, ctx, ...}`
  (`classes_sig.sml:13-19`), found by `findInstance (env, cls, tycon)` (`:37-39`). The checker solves at once: a
  predicate headed by a constructor is solved by its instance or refused there, and only one on a unification variable
  is kept (`infer.sml:296-339`). HsLint matches heads as THIH does (`hslint_classes.sml:67-80`) but refuses any head
  that is not 98's when it reads an instance (`hslint_env.sml:684-720`).
- **A type has no forall.** `HsTypes.ty` is `TCon`, `TAp`, `TMeta`, `TGen` and `TRigid` (`types_sig.sml:45-51`); a
  scheme is prenex, its variables `TGen 0` to `TGen (vars - 1)` (`:61-63`), numbered by their first appearance in the
  signature's type (`infer.sml:576-601`). The checker has rigid variables already, with an escape check
  (`types_sig.sml:42-43`; `infer.sml:182-204, 604`).
- **Core is System F, with Haskell 98's data.** Core's types have `TForall` (`core_sig.sml:38`), but an alternative
  binds only its fields (`AltCon of string * string list * exp`, `:77`), a constructor has only the types of its
  fields, with no type variable or context of its own (`:87`), and a `Cast` goes into or out of a newtype at its head
  (`:73`). Kinds are `Star`, `Unlifted` and `Arrow`, with no variables (`:27-30`).
- **HsLint is a specification of Haskell 98.** Its second inference is a transliteration of Typing Haskell in Haskell
  (`hslint_infer.sml:1-6`), its replay Faxén's static semantics (`hslint_replay.sml:1-4`). It has no rigid variables:
  a signature is instantiated with flexible variables, the binding inferred, and the result requantified and compared
  (`hslint_infer.sml:698-722`; its types at `hslint_types.sml:32-38`); the replay makes a rigid variable a constant
  (`hslint_replay.sml:70-71`).
- **Global refs.** The checker's environment and settings are refs, reset at each call, once a unit
  (`infer.sml:138-145, 343, 2007-2010`); `HsMatch.order` is one ref for the run (`match.sml:10`); the parser's
  `dotted` is set at each parse (`parser.sml:1588`).

### The library

`share/rhc/haskell98` holds the Report's 20 modules in its own layout (98's D36): the Prelude split into `Prelude`,
`PreludeList`, `PreludeText` and `PreludeIO`, and the 16 modules of chapters 12 to 27; and two of rhc's,
`PreludeRuntime` and `PreludeEnum` (`docs/rhc.md:250-263`; 22 files, counted).
- `pristine/` is the Report's code transcribed mechanically from the HTML, never edited, with `synopsis/` and a
  manifest of hashes (`share/rhc/haskell98/pristine/MANIFEST.tsv:1-8`).
- `errata.tsv` lists all 18 errata and what rhc did with each (`share/rhc/haskell98/errata.tsv:1-11`).
- `overlay.tsv` lists every place rhc's code differs from pristine, with its ground and status
  (`share/rhc/haskell98/overlay.tsv:1-16`); `hs/library/overlay` holds the modules to it token by token, and
  `hs/library/pristine` pristine to its manifest (`tests/runner/hslibrary.sml:1-31`). `LICENSE` says what changed.
- `PreludeRuntime` is the primitives, as Haskell sees them: a signature with no binding names a primitive of Core's or
  of the runtime's, and a constructor-less type names a type of Core's (`Str`, `Ref a`, `Arr a`); the rule is "no SML
  below Haskell" (D26 A; `share/rhc/haskell98/PreludeRuntime.hs:1-20, 79-81`). `PreludeEnum` holds the four
  `numericEnum*` functions so that Ratio can see them (`share/rhc/haskell98/PreludeEnum.hs:1-6`).
- Every library file is read through eight rules, I1 to I8, that the driver calls interim (`src/rhc/library.sml:6-37`,
  applied at `src/rhc/graph.sml:228`), and a signature with no binding is made `= primElided` with an import of
  `PreludeBuiltin` (`src/rhc/library.sml:186-223`).

**How modules map to files.** A program's module `M` is `M.hs` or `M.lhs` beside the first root, failing that the
library's `DIR/haskell98/M.hs`; a leaf has no file; a hidden module is refused to a program; a missing one is
diagnosed; the library imports from the library alone; every module but one named `Prelude` imports the Prelude
(`src/rhc/graph.sml:7-16, 255-283, 301-302`). **The module-identity rule** is built: a module's identity is its name
in a program and `haskell98:` and its name in the library, so a program's `Char` is not the library's
(`src/rhc/graph.sml:10-13`; `src/rhc/library.sml:39-40, 49`), and `tests/hs/names/char/` tests it. A second library
changes the prefix, not the rule (deduced).

### The runtime rhc reaches

rhc reaches the runtime only through Core's primitives, lowered by Core to Mid. Core's own (`coreprim_sig.sml:18-59`,
`coreprim.sml:47-116`) are on `Int` (63 bits, checked: `docs/rhc.md:47-48`), `Integer`, `Char`, `Double`, `Float`,
`Str`, arrays, cells, I/O by handle, `interleave`, the selector mark and exceptions of nine kinds (`coreprim.sml:133`).
There is no `Word`, no fixed-width integer and no bit operation among them. A family of primitives, in a file of its
own, adds primitives with a type, an interpreter function and a Mid function (`coreprimfamily_sig.sml:1-37`; lowered
at `coretomid.sml:1380-1384`); its arguments are `!Int`, `!Str` and `!Bool` and its results one of those
(`coreprimfamily_sig.sml:9-11, 17`). There are two families, I/O and the system's (`coreprim.sml:119`).

The VM has what Core lacks. Its `word` is 63 bits unsigned with `andb`, `orb`, `xorb`, `notb`, `lsl` and `lsr`
(`runtime/prims.def:29-48`); `int64` has checked arithmetic (`:355-372`); `word64` has arithmetic modulo 2^64, and
bit operations with shifts of 64 or more giving 0 (`:374-395`); `IntInf` has GMP's and, or, xor and shift
(`:446, 448`). Plain `int` has no bit operation (`:10-27`).

Rune's FFI roadmap is done, M0 to M10 (`docs/plans/runeffi.md:17-29`): a trusted Basis structure, `RuneForeign`
(`lib/basis/rune_foreign_sig.sml:1-20`), over the VM's `foreign` and `foreign_callback` (`runtime/prims.def:470-471`).
Resources are opaque identities and native addresses never reach SML (`docs/plans/runeffi.md:465-467`), and no
finalizer is in it (`:471`). `_prim`, by which the Basis reaches the VM, is allowed only with `--allow-prim`
(`docs/language.md:34`), and rhc's rule is no SML below Haskell, so a Haskell program reaches none of it: no
`Foreign`, no `IORef`, no concurrency (`docs/rhc.md:311-314`). `catch` sees an `IOError` and nothing else (R36;
`coreruntime.sml:46-54`); cells, `unsafe_perform_io` and `interleave` exist inside `PreludeRuntime` only
(`share/rhc/haskell98/PreludeRuntime.hs:154-159`). E10's prototype reached `foreign` through a new family (*The
foreign function interface*).

### The tests

**The table.** `tests/hs/conformance.tsv` has a row for each clause of the 98 Report: 3,901 rows under a header of
ten columns, id, section, statement, class, test, how, source, status, reading and deviation
(`tests/runner/hsconformance.sml:44`). All 3,901 are Supported; by test, 1,380 accept, 554 reject, 1,869 run and 98
none; 2,648 written by hand and 1,253 generated; 234 name a reading and 8 a deviation (counted). `docs/rhc.md:319-327`
still says rhc does not meet the rows "whose status is `Planned`", and lists them; there are none since `82b5e482c`
made every row Supported.

**Its enforcement** (`tests/runner/hsconformance.sml:1-39`) holds the table and the programs to each other both ways.
A program of `tests/hs/lang`, `accept` or `errors` names the row of its file name's part before the first `_`, and the
further rows of its first line, `-- rows:` (`:12-15`). The runner hard-codes `clauses = 3901`, `errataCount = 18`,
`readings = 54` and the three directories (`:48-58`), and its paths (`:100, 150, 196-198`). The ids share one
namespace, so a second table needs directories of its own and a suite that passes `--language` (deduced).

**The families.** `tests/hs` has 20 directories: `lang` (compiled and run), `errors` (refused, the message in
`.expected`), `accept` (checked), and `core`, `corpus`, `desugar`, `hslint`, `iface`, `library`, `meta`, `names`,
`oracles`, `perf`, `roundtrip`, `runner`, `selectors`, `simplify`, `syntax`, `types` and `units` (counted). Their
runners are `tests/runner/hs*.sml` (`Makefile:2227-2230`). The suite of `lang` compiles with `bin/rhc` and
`bin/rhc --target=stack`, plus `RUNE_HS_RHC_FLAGS` (`tests/runner/hslang.sml:89-114`). A program may carry a
`.cargs` of compile options (`tests/runner/lang.sml:268`; `docs/testing.md:525`); none in `tests/hs` does (counted).

**The pins that flip under 2010.** E3's spike ran every test of `errors`, `lang` and `accept` under
`--language=haskell2010`: 21 of 1,475 flip (observed: `results/E3/flips/flips.tsv`, `attribution.tsv`). By cause:
- n+k, 10: `pat.class.npk`, `pat.m.npk.positive`, `pat.m.npk.succeed`, `pat.m.npk.diverge_undef`,
  `pat.class.infer.npk`, and five programs that use n+k on the way (`dec.bind.patvsfun`, `pat.ctx.lambda`,
  `syn.pat.1_tour`, `dec.note.funbind.plus`, `exp.free.eq`); 16 rows of the table name `npk` (counted);
- the dotted lexer, 3: `mod.name.modid`, `lex.qual.modname`, `lex.qual.twodots`;
- DoAndIfThenElse, 3: `lay.parseerror.thensamecol`, `lay.parseerror.doif`, `exp.if.do.semi`;
- empty data, 3: `dec.data.noconstructors`, `syn.r.dataconstrs`, `kind.implicit`;
- `foreign` reserved, 1: `lex.reserved.notspecial`;
- the relaxed groups, 1: `dec.gen.sig.identical_where`.

The two fixity deviations do not flip: they stay refused, and under 2010 the refusal is the text (R1, R9). *Testing
and conformance* takes these up.

### What changed on haskell98 after 75ed95861

The other session merged 24 commits on `haskell98`, to `1429fe5fc` (2026-11-21; `git log --oneline
75ed95861..1429fe5fc`): six merges, the commits under them, and the 98 roadmap's record of them. Under
`lib/language/haskell`, `src/rhc`, `share/rhc` and `tests/hs` they change 116 files, 1,755 lines in and 340 out;
`share/rhc` is untouched (`git diff --stat`). This roadmap's citations stay at `75ed95861`; its milestones are built on
whatever tip they start from. What bears on it:

- **rhc's store, issues 25 to 39 of `docs/plans/build-cache-issues.md`** (merge `8134f92fe`, and the six commits
  under it). Four were wrong results, each fixed with a probe:
  - issue 27, a literate file read as a plain one: a unit's key and a header's mode now say whether a member is
    literate, and "`--dotted-names`, by which a text is read otherwise too, is in the units' configuration", as
    `("names", "dotted")` added to `extra` in `RhcDriver.front` (`src/rhc/driver.sml:421-422` at the tip). That
    closes the hole E3 observed at `75ed95861` (above). It is the place a module's language joins too: E4 puts each
    member's language in the unit key and the program's in the header's mode, beside the literate flag
    (`results/E4/other-session.md`);
  - issue 25, a class's defaults: `HsClasses.class` gains `defaults`, and `HsIface` goes to version 4;
  - issue 26, an instance in scope along a chain of imports (5.4): a usage of its own, `HsUsage.Reaches`;
  - issue 29, the link's memo across levels and machines.

  The others: a damaged part read late (28); a unit's fresh names numbered by a range of its own
  (`RhcNames.programSlot`, 30); places written by module, not by the path read, so a snapshot no longer names the
  tree it was built in (31); `--verify-store` (32); the store trimmed after the link (34); the link keyed by each
  unit's Core (35); the state of the units before made once (36); and a unit's desugaring and HsLint costing what it
  holds, not what came before (39: `HsInfer.part` by module, `HsClasses.instancesOf`, `classesAt`, `instanceById`).
  Issues 37 and 38 stay open. Three bugs of rhc's own were fixed on the way: an assumed header's export placed in its
  own file; a `default` type checked against the instances in scope in its module (4.3.4 with 5.4); a superclass
  named twice taken once (`tests/hs/errors/def.decl.num_scope`, `mod.header.abbrev.nomain_imported`,
  `tests/hs/lang/cls.class.super_repeat`). This merge touches 16 of the 34 files E4's prototype changes, and E4's
  patch applies to the tip with 12 of its 121 hunks rejected, in `src/rhc/driver.sml` (4), `hslint.sml` (3),
  `src/rhc/graph.sml` (2), `hslint_env.sml`, `src/rhc/names.sml` and `src/rhc/syntax.sml` (1 each) (observed:
  `results/E4/other-session.md`). So E4's language record is written on this driver and graph, not `75ed95861`'s.
  Every hard-coded `haskell98` listed above is still there, some lines moved (`infer.sml:2033` at the tip). The
  instance index that T1 rebuilds is the tip's `HsClasses`, with `defaults` and lookups by id and by module.
- **98's D17 C, gaps 1 and 2** (merge `2ac942b9c`; `8aa1071aa`, `9d5826f8e`): a pattern binding or lazy pattern of
  one variable that is a field of a variable's value, and a CAF that selects a field of a CAF, become marked
  selectors. It changes `match.sml`, `match_sig.sml`, `desugar.sml` and `coretomid.sml`, where pattern guards (D14)
  will be desugared; gaps 3 and 4 are still under way (`docs/plans/language/haskell98.md` at the tip, *Left
  open*).
- **Mid's simplify and the shapes lint** (merges `646f5bbbd`, `e51faeffe`): a `Case` of a variable whose known tags
  leave one folds to that arm, and the lint takes it. They are in `lib/compiler`, not rhc's sources; rhc's run set
  runs 0.071% fewer bytecodes at `-O2`, none more (the other session's figure: the 98 roadmap at the tip, *After the
  close*). So some of rhc's bytecode at `-O2` is not `75ed95861`'s, and E3's and E4's checks of identical bytes hold
  at `75ed95861` only.
- **`Real.round`** (merge `75a2bde45`): the VM's `real_round` rounds to nearest, ties to even, in every rounding mode
  (`runtime/prims.def:64` at the tip). Haskell's `round` lowers through `real_round_r` (`coretomid.sml:1355-1357`),
  which was ties to even in every mode already (`runtime/prims.c:548-557`) and now shares the new rounding, so rhc's
  results should not move (deduced; not run).
- **The make targets and the Windows VMs** (merge `0c7f50a9d`): every target that runs a tier builds the tools its
  tests run, and the foreign calls on the Windows VMs are skipped where those VMs were built without libffi
  (`docs/ffi/runtime.md` and `tests/runner/ffijobs.sml` at the tip). A 2010 FFI test on those VMs would be skipped
  alike (deduced).
- **The 98 roadmap's record** (`1429fe5fc`): what came after the close, and what is left open, among it that
  `haskell98` is not merged into master. `share/rhc` is untouched by the 24 commits, but the branch is not closed,
  which bears on D25.

## What the 2010 Report says

The Haskell 2010 Report is the 98 Report revised in place. Chapters 1 to 7 keep their numbers and most of their words,
the Prelude's code is the 98 code with three imports renamed, and a chapter on the foreign function interface is new.
What changed most is the library: 30 module chapters, 26 of them prose with no code. The preface lists four changes;
E1 counts eighteen in the text. The committee published no errata.

The owner's rule of conformance is 98's, as 98's D38 left it on 2026-11-13: rhc follows the text, and departs only
where it is wrong, contradictory, ambiguous or conceded by the Report, each departure named and pinned by a test. This
section says which text that rule applies to under 2010, what changed from 98 (with the 98 errata), how the Prelude
and the libraries read, how large the clause matrix is, where 2010's own text fails (N1-N21) and what GHC does there,
and what all this gives the decisions. *Haskell 98 mode and the 2010 text* puts 98's choices against it.

Quotations are from T10 (pdftotext of the 2010 PDF) or the HTML Report, exactly; `_|_` stands for the Report's bottom
sign and `^` for its caret. Section numbers are the 2010 Report's unless "98's" is written. Every change and reading
comes from E1 (`results/E1/`: `delta.md`, `readings2010.md`, `errata2010.md`, `prelude-diff.md`, `libraries.tsv`,
`clauses2010.tsv`). A behaviour is marked by how it is known:

- **[read]**: read at the line cited.
- **[probe]**: a program E1 ran on GHC 9.4.7 with `-XHaskell2010` (and `-XHaskell98` where said), compiled at `-O0`
  and run: `results/E1/probes/NAME.hs`, its output in `probes/out/NAME.2010.txt`. No 2010 shim was used (E8 builds
  one), so a probe of a library function tests GHC's `base` 4.17, not the Report's library; such probes are marked
  **(base)**. GHC claims [read] are from 9.14.1's source under `/home/ruud/haskell/ghc`.
- **[measured]**: a count from E1's files, recounted while writing.
- **[inferred]**, **[memory]**: as they say.

### Which text

The brief's link, `https://www.haskell.org/onlinereport/haskell2010/`, serves the Report as generated on 2010-07-20.
E1 fetched it on 2026-11-17 (`downloads/report2010/MANIFEST.tsv`): 51 HTML pages (the root URL serves `haskell.html`
again: 52 files), every one carrying `<meta name="date" content="2010-07-20 13:11:00">`, with the style sheet and
figures [measured]. The PDF in the 98 drafts (`haskell98/downloads/papers/haskell2010.pdf`) gives T10, 17,918 lines. The
HTML loses none of the PDF's text: 91.7% of T10's 101,362 tokens are matched section by section
(`results/E1/coverage.tsv`), and the low sections are tables and figures that pdftotext scrambles (3.17.3's rules, 6.4's
class figure, 10.5's grammar), which E1 read by hand. Code is taken from the HTML, since pdftotext splits code columns
(T10:8268 prints `= numericEnumFrom` on a line of its own).

**No errata were ever published** (`results/E1/errata2010.md`) [read]:
- The Report links no errata page. haskell.org's definition page links errata for Haskell 98 only. The wiki's
  "Haskell 2010 errata" page has no text (HTTP 404). The wiki's specification page asks that mistakes be sent to the
  haskell-prime list.
- E1 searched the haskell-prime archive, 95 monthly archives from 2009 to 2021, and read the threads it found. They
  hold ten reports of mistakes in the 2010 text. None reached the published Report. Some were fixed in the Report's
  sources (darcs, later GitHub `haskell/haskell-report`), which E1 did not read, as they were outside its network
  permission; their history would list every fix made after 2010.

| # | Date | Where | The mistake | Fate | For rhc |
|---|---|---|---|---|---|
| E10-1 | 2010-11 | 20.4.3 | "iteratef", "repeatx", "replicaten x": spaces lost in the generated library chapters | Trac ticket; not published | None (a misprint, like 98's R52) |
| E10-2 | 2010-11 | unknown | Trac #140, #141, "small fixes"; unreachable | "a few minor fixes" in darcs | Unknown |
| E10-3 | 2011-04 | 6.4.3 | `0**y` "is 1 if y is 1": surely "y is 0" | No reply; text unchanged | N10 |
| E10-4 | 2011-06 | 4.4.3.2, 4.5.5 | "simple pattern binding" and "declaration group" disagree | Promised for a "Haskell 2012 Report" that never appeared | N19 |
| E10-5 | 2012-08 | 5.6.1 | "These modules are not part of Haskell 98" (T10:5532), a leftover | Fixed in the sources; not published | None |
| E10-6 | 2012-08 | 5.2 | `module M` in an export list: M is an import's alias, not necessarily a module's name | Agreed; not published | N14 |
| E10-7 | 2014-08 | 4.4.2, 10.5 | `fixity [integer] ops` admits `infix 0x7` though the prose says a digit | A question; 98 has the same text (R25) | None new |
| E10-8 | 2018-03 | 3.17.3 rule (s) | "where y is a new variable", though no y occurs | Merged into the GitHub sources; not published | N3 |
| E10-9 | 2018-03 | 4.4.3.2, 4.5.5 | "simple pattern binding" defined two ways: "What a mess!" | No fix | N19 |
| E10-10 | 2019-12 | 3.17.2 | The newtype and data examples show no difference (both _\|_) | Referred elsewhere; no fix | None |

**So D38's 98 choice, "the December 2002 text plus the published errata", has no 2010 counterpart.** The 2010 mode's
text is the Report of 2010-07-20 as published; its reported mistakes are readings below, each with its ground. 98's own
errata against the 2010 text are *98's errata in 2010*, below.

### What changed from 98

The preface lists four changes under "Extensions to Haskell 98" (T10:1287-1294): the FFI, hierarchical module
names and pattern guards added, n+k patterns removed. It is not the list. E1 diffed every language section of 98 (the
HTML text the 98 campaign used) against 2010's, word by word: 338 hunks, each read (`results/E1/textdiff/`). Most are
renumbering; the rest are eighteen changes, Δ1-Δ18 in `results/E1/delta.md`. T98 lines 1-2760 and 14746-18546 are the
98 HTML as text, the rest the book's PDF.

| Δ | Change | In the preface | 98 | 2010 | Rows of the matrix | For rhc |
|---|---|---|---|---|---|---|
| Δ1 | The FFI: chapter 8, `foreign` reserved, `topdecl -> foreign fdecl`, 14 Foreign modules, Data.Bits, Data.Int, Data.Word | Yes | T98:2488 (no `foreign`) | T10:6663-7459, 1741, 3502 | 1,037 new, 1 changed | D27-D33, track V |
| Δ2 | Hierarchical module names | Yes | T98:2540, 18018-18020 | T10:1795, 1806, 5026-5039 | 4 changed, 5 new | D18 |
| Δ3 | Pattern guards, and guards translated by `case ()` | Yes | T98:15990-15992, 16406-16411, 16443-16446, 17637-17643 | T10:2745-2806, 3278, 3436-3447, 4688-4693 | 6 reworded, 5 changed, 22 new, 1 removed | D14 |
| Δ4 | n+k patterns removed | Yes | T98:16228-16240, 16359-16366, 16504-16506 | T10:3080-3089, 10998 | 20 removed, 6 changed, 1 new | D17 |
| Δ5 | `if exp [;] then exp [;] else exp` | No | T98:15472, 15753-15754 | T10:2083, 2437 | 2 changed, 3 new | D17 |
| Δ6 | Empty data declarations; derived instances' condition 6 | No | T98:16557, 16899, 16926 | T10:3496, 3860, 3911, 10670 | 4 changed, 5 new | D15 |
| Δ7 | The precedence-indexed grammar deleted: `infixexp` plus fixity resolution (10.6); 98's two parsing notes deleted | No | T98:15440-15468, 15532-15543, 317-324 | T10:2048-2071, 2145-2152, 2172-2173, 4647-4653, 10543-10644 | 8 reworded, 18 changed, 11 new, 16 removed | DV1, DV8 lapse |
| Δ8 | Relaxed dependency analysis, generalisation per group | No | T98:17667-17687 | T10:4704-4724, 4751-4752, 10998 | 2 reworded, 2 changed, 4 new | D16 |
| Δ9 | The LANGUAGE pragma; unrecognised pragmas "should be ignored" | No | T98:10356-10357 | T10:10924-10930, 10977-11002 | 1 reworded, 8 new | D4-D7 |
| Δ10 | `:` joins ascSymbol | No | T98:2415, 2427-2433, 2507-2509 | T10:1626, 1633, 1660, 1674, 1767-1768 | 8 reworded, 1 new | None |
| Δ11 | `0**y`: "undefined" becomes "1 if y is 1, and 0 otherwise" | No | T98:15328 | T10:6389-6390 | 1 changed | D13b, N10 |
| Δ12 | The libraries: 30 module chapters, 5 modules dropped, IO and System split, 26 without code, new names, 4 types changed, Data.Char's Unicode semantics, program termination's text gone | No | 98 chapters 12-27 | chapters 13-42 | 866 changed, 257 new, 216 removed | D21-D26 |
| Δ13 | The Prelude: code unchanged but 3 imports; its 2 code errata not absorbed | No | T98:1139-2323 | T10:7460-9330 | 3 changed | D2, D38 (N18) |
| Δ14 | Defaulting's "standard library" now holds Bits, a Num subclass, and Storable | No (same words) | T98:17392-17396 | T10:4366-4369, 11629, 15819 | None | D20 |
| Δ15 | Unicode: 98 cites version 3.0, 2010 none | No | T98:2355, 14112 | T10:1540, 16864 | None | D26 |
| Δ16 | Editorial: renumbering, misprints fixed, one "Haskell 98" left | No | various | various | 5 reworded | None |
| Δ17 | 98's 18 errata: 6 absorbed, 8 not, 1 moot, 3 not applicable | n/a | rhc's `tests/hs/errata.tsv` | various | 3 reworded, 7 changed | D38 (N18) |
| Δ18 | Chapters renumbered: 8 is the FFI, 98's 8-11 become 9-12, the libraries 13-42 | n/a | n/a | n/a | Every row's section | The 2010 table |

Rows are `results/E1/delta-rows-counts.tsv` [measured]; "reworded" rows keep 98's requirement and id with new
production text. The counts overlap (Δ1's library rows are also Δ12's; Δ3 and Δ7 share 10.5's productions).

**Δ1. The FFI.** Chapter 8 is new (T10:6663-7459). It requires one calling convention: "Any implementation of the
Haskell FFI must at least implement the C calling convention denoted by ccall. All other calling conventions are
optional." (T10:6828-6829). It defines static, `&`, `dynamic` and `wrapper` imports and `foreign export`, the
marshallable types (8.4.2) and the C side, `HsFFI.h` with `hs_init`, `hs_exit`, `hs_set_argv`, `hs_perform_gc`,
`hs_free_stable_ptr` and `hs_free_fun_ptr` (T10:7418-7459). `foreign` becomes a reserved word (T10:1741; 98's list,
T98:2488-2492, has none); `ccall`, `stdcall` and the other convention names are special only inside a foreign
declaration (T10:6734-6738). Data.Bits, Data.Int, Data.Word and the Foreign modules come with it. For rhc: `foreign`
is a variable today (`lib/language/haskell/token.sml:25-46` has no such word; row `lex.reserved.notspecial`, R62), so
it is reserved in 2010 mode only; everything else is *The foreign function interface*.

**Δ2. Hierarchical module names.** 2.4's `modid -> {conid .} conid` (T10:1795) replaces `modid -> conid` (T98:2540),
and chapter 5 says "A module name (lexeme modid) is a sequence of one or more identifiers beginning with capital
letters, separated by dots, with no intervening spaces." (T10:5026-5027), then that the hierarchy "is purely a
convention ... in this report a modid is treated as a single identifier occupying a flat namespace" (T10:5038-5039).
So `M.N.x` is now `x` qualified by `M.N`, where 98 reads `M.N`, `.`, `x` (row `lex.qual.twodots`). For rhc:
`--dotted-names` gives the lexer hierarchical names for programs and never for the library
(`src/rhc/graph.sml:230`); 2010 needs them for both (D18).

**Δ3. Pattern guards.** 3.13's `guards -> | guard1, ..., guardn` with `guard -> pat <- infixexp | let decls | infixexp`
(T10:2745-2758) replaces `gd -> | exp0` (T98:15992). Guards are tried left to right, their bindings scope over the
guards after them and the body, and a failing guard passes to the next guarded expression, then to the next
alternative (T10:2798-2805); "A boolean guard, g, is semantically equivalent to the pattern guard True <- g."
(T10:2783-2784). 3.17.3 translates guards through nested `case () of { () | gs -> e; _ -> ... }` and adds rules (s)
to (v) (T10:3436-3447 and Figure 3.3); 4.4.3.2's guarded pattern binding becomes `p = let decls in case () of ...`
(T10:4688-4693) where 98 had a chain of `if` (T98:17637-17643). For rhc: absent; guards parse as one expression
(`lib/language/haskell/parser.sml:1021-1045`). D14 and N3.

**Δ4. n+k removed.** 3.17.1's `pat -> var + integer` (T98:16228) is gone, with its matching rule, its translation
(98's rule (s), T98:16504-16506) and "Many people feel that n+k patterns should not be used. These patterns may be
removed or changed in future versions of Haskell" (T98:16365-16366). 2010's patterns are
`pat -> lpat qconop pat | lpat` (T10:3080-3089), and 12.3 names NoNPlusKPatterns among the features "integrated into
this report" (T10:10998-11002). For rhc: `nk` is the grammar level a pattern sits at
(`lib/language/haskell/parser.sml:554-556`), so 2010 mode needs a condition that 98 mode does not; 98's pattern binding
`(x + 1) = 5`, which defines `x` as 4, is refused (row `dec.note.patbind.npk`). D17.

**Δ5. `if` with semicolons.** `lexp -> if exp [;] then exp [;] else exp` (T10:2083, and 3.6 at T10:2437) against
`if exp then exp else exp` (T98:15472). No prose mentions it and 12.3 does not list it. For rhc: the parser expects
`then` at once (`lib/language/haskell/parser.sml:746-756`), and two tests pin the refusal that 2010 reverses,
`errors/exp.if.do.semi` and `errors/lay.parseerror.thensamecol` (R12). The semicolons are absorbed in any layout
block, not only `do` (N13). D17.

**Δ6. Empty data.** `data [context =>] simpletype [= constrs] [deriving]` (T10:3496, 3860) against `= constrs`
(T98:16557, 16899); "a new type constructor T with zero or more constituent data constructors" (T10:3911) against
"one or more" (T98:16926). Chapter 11 adds a sixth condition: "If the data declaration has no constructors (i.e. when
n = 0), then no classes are derivable (i.e. m = 0)" (T10:10670). For rhc: the parser requires `=`
(`lib/language/haskell/parser.sml:1377`); zero-constructor types in Core and Mid are *Where we are*'s. D15 and N12.

**Δ7. Fixity resolution replaces the precedence grammar.** 98 parsed with families `exp^i`, `lexp^i`, `pat^i`
indexed by precedence (T98:15440-15468). 2010 has `infixexp -> lexp qop infixexp | - infixexp | lexp`
(T10:2048-2071), says that "An example algorithm for resolving expressions involving infix operators is given in
Section 10.6" (T10:2150) and that "the rest of this section will assume that expressions involving infix operators
have been resolved according to the fixities of the operators" (T10:2172-2173). 10.6 is that algorithm in Haskell
(T10:10543-10644). 4.4.3.1 applies it to infix function bindings: `a ## b : xs = exp` "would be illegal"
(T10:4647-4653). Two 98 notes are deleted: chapter 3's "A note about parsing" on `let x = True in x == x == True`
(T98:15532-15543) and 9.3's "The parse-error rule is hard to implement in its full generality, because doing so
involves fixities" on `do a == b == c` (T98:317-324). For rhc: resolution is already 10.6's algorithm over tokens
(`lib/language/haskell/fixity.sml:43`, `resolveToks` at :77), so nothing changes in the parser; 98's two deviations
filed as "conceded by the Report" (`tests/hs/deviations.tsv:2`, `:9`) become 2010's text, since the passages that
conceded them are gone (*Haskell 98 mode and the 2010 text*). N2.

**Δ8. Relaxed dependency analysis.** "A binding b1 depends on a binding b2 in the same list of declarations if either
1. b1 contains a free identifier that has no type signature and is bound by b2, or 2. b1 depends on a binding that
depends on b2. A declaration group is a minimal set of mutually dependent bindings." (T10:4710-4713), where 98 put
two variables in one group "if either they are bound by the same pattern binding, or their bindings are mutually
recursive" (T98:17673-17677). 4.5.2 generalises per group (T10:4721-4724) and keeps "If the programmer supplies explicit
type signatures for more than one variable in a declaration group, the contexts of these signatures must be identical
up to renaming of the type variables." (T10:4751-4752), so 98's R21(b) stays live. 12.3 calls the change
RelaxedPolyRec (T10:10998): one change, not two. For rhc: one edge set in `groupsOf`
(`lib/language/haskell/infer.sml:1135`) and in HsLint's `succs` (`lib/language/haskell/hslint_infer.sml:437`). D16
and N4.

**Δ9. Pragmas.** Chapter 12 now says "An implementation is not required to respect any pragma, although pragmas that
are not recognised by the implementation should be ignored. Implementations are strongly encouraged to support the
LANGUAGE pragma described below" (T10:10927-10930). 12.3 makes LANGUAGE "a file-header pragma" that "must precede the
module keyword" (T10:10981), and: "If a Haskell implementation does not recognize or support a particular
language feature that a source file requests (or cannot support the combination of language features requested), any
attempt to compile or otherwise use that file with that Haskell implementation must fail with an error."
(T10:10989-10990). Implementations that support the pragma must support `{-# LANGUAGE Haskell2010 #-}` (T10:10993-10995)
and are encouraged to support PatternGuards, NoNPlusKPatterns, RelaxedPolyRec, EmptyDataDecls and
ForeignFunctionInterface (T10:10997-10999). Its only example names CPP (T10:10987). INLINE, NOINLINE and SPECIALIZE are
98's text. For rhc: pragmas are trivia today, read only by the exact printer (`lib/language/haskell/lexer.sml:112`).
D4-D7, D19, N5.

**Δ10. `:` joins ascSymbol.** `ascSymbol` gains `:` (T10:1673-1674), `graphic` loses its separate `:` (T10:1633), and
`varsym` and `consym` are rewritten around it (T10:1767-1768). The operators a program can write are the same. The
effect is on comments: `comment -> dashes [ any<symbol> {any} ] newline` (T10:1626) now excludes `--:`, which is 98's
erratum of December 2005, absorbed this way. rhc applies that erratum already (`tests/hs/errata.tsv:2`). No change.

**Δ11. `0**y`.** 98: "The value of x^0 or x^^0 is 1 for any x, including zero; 0**y is undefined." (T98:15328). 2010:
"The value of x^0 or x^^0 is 1 for any x, including zero; 0**y is 1 if y is 1, and 0 otherwise." (T10:6389-6390;
the HTML says the same). "y is 1" is a misprint for "y is 0", reported in April 2011 and never corrected (E10-3).
D13b and N10.

**Δ12. The libraries.** In brief here; *The libraries* has them in full.
- **30 module chapters, 686 exported names** (`results/E1/libraries.tsv`) [measured]. Four have code: Data.Array
  (14.6, 65 lines), Data.Complex (17.4, 73), Data.Maybe (21.2, 31) and Data.Ratio (22.1, 74). The other 26,
  Control.Monad, Data.Char, Data.List, Numeric, the System modules, Data.Bits, Data.Int, Data.Word and the Foreign
  modules among them, are signatures and prose generated from GHC's `base` of 2010.
- **Dropped:** Directory, Time, Locale, CPUTime and Random (98's chapters 22, 24-27), IO's `bracket` and `bracket_`,
  System's `system`. **Split:** IO into System.IO and System.IO.Error; System into System.Environment and System.Exit.
- **New names in modules 98 had:** Control.Monad 9, Data.Char 41 (general categories among them), Data.List 7,
  System.Exit 1, System.IO 8, System.IO.Error 11 (`libraries.tsv`).
- **Four types changed**, of 257 compared (`results/E1/libs/lib10-entities.tsv`) [measured]:
  `genericLength :: Num i => [b] -> i` (T10:13317) against 98's `Integral` (T98:11819, 12016), and `readDec`, `readOct`,
  `readHex :: Num a => ReadS a` (T10:16049-16055) against 98's `Integral`. 253 have the same type.
- **Semantics changed in prose.** Data.Char's `isSpace` "Returns True for any Unicode space character, and the
  control characters \t, \n, \r, \f, \v." (T10:11833) against 98's "The isSpace function recognizes only white
  characters in the Latin-1 range." (T98:12253). `isUpper` "Selects upper-case or title-case alphabetic Unicode
  characters (letters)." (T10:11844) and `isAlpha` adds "letters of caseless scripts and modifiers letters"
  (T10:11848), against 98's rule that "any alphabetic character which is not lower case is treated as upper case"
  (T98:12229-12235) and its code `isAlpha c = isUpper c || isLower c` (T98:12309). Data.Int: "All arithmetic is
  performed modulo 2^n, where n is the number of bits in the type." of a list that names Int (T10:12381-12382), and
  Data.Word the same of Word (T10:13780-13781).
- **How a program ends has no text.** 98's chapter 23 said that `exitWith` closes "any open or semi-closed handles"
  first, that a program ending in `error` or a determined _|_ "is treated identically to the computation
  exitFailure", and that one not calling `exitWith` is `(p >> exitWith ExitSuccess)` with a `catch` to `exitFailure`
  (T98:13470-13484). System.Exit in 2010 (chapter 40) keeps none of the three sentences. N21.
- **The code chapters have defects:** 14.6 is headed `module Array (`; 22.1's `Show (Ratio a)` has lost an opening
  parenthesis and does not parse (T10:13724-13730); Data.Complex's export list prints `Complex(:+)`; 19.1's law has a
  stray parenthesis (T10:12510); Data.Maybe now defines `maybe` (T10:13438-13440) where 98's module re-exported the
  Prelude's, and so does not compile either. Data.Array's `array` is rewritten with guards to the same checks
  (`results/E1/libs/libcode-diff.txt`). N11.

**Δ13. The Prelude.** Its code did not change: *The Prelude's code*, below.

**Δ14. Defaulting reaches Bits.** 4.3.4's conditions are 98's words (T10:4366-4369 against T98:17392-17396): a
defaultable variable's classes include "a numeric class, (that is, Num or a subclass of Num)" and are all "defined in
the Prelude or a standard library". 2010's standard library declares `class Num a => Bits a` (T10:11629) and
`class Storable a` (T10:15819). So `print (shiftL 1 3 .|. 1)` defaults to `Integer` and prints 9 in 2010, where 98
had no Bits. For rhc: the checker's test of a standard class is a prefix match on `thaskell98:`
(`lib/language/haskell/infer.sml:2010`), so it must be per edition. D20 and N9.

**Δ15. Which Unicode.** 98 cites "The Unicode Standard, Version 3.0" (T98:14112); 2010 cites "[2] Unicode
Consortium. Unicode standard. http://unicode.org/standard/standard.html." (T10:16864) with no version. Both keep
"Haskell compilers are expected to make use of new versions of Unicode as they are made available." (T10:1542-1543,
T98:3413). rhc's `lib/unicode` is at 18.0.0 (`lib/unicode/grapheme_data.sml:18`). D26 and N8.

**Δ16. Editorial.** 3.15.2's "see the third bullet above" becomes "fourth" (T10:2960); 5.6's "complex numberss" is
mended (T10:5510); 1.3 says "indistinguishable" (T10:1478); the bibliography, figures and cross-references are
renumbered. 5.6.1 keeps "These modules are not part of Haskell 98" (T10:5532), fixed in the sources in 2012 and never
published (E10-5). Nothing for rhc but the 2010 table's statements.

**Δ17. 98's errata.** *98's errata in 2010*, below.

**Δ18. Renumbering.** Chapters 1-7 keep their numbers and section titles. Chapter 8 is the FFI; 98's 8 (Prelude),
9 (syntax), 10 (derived instances) and 11 (pragmas) become 9, 10, 11 and 12, with 10.6 (fixity resolution) and 12.3
(LANGUAGE) new. The libraries are chapters 13-42, one per module, in alphabetical order: 98's Ratio is 22, Complex 17,
Numeric 38, Ix 19, Array 14, List 20, Maybe 21, Char 16, Monad 13, IO 41 and 42, System 39 and 40
(`results/E1/secmap.tsv`). Within a library chapter 98's sections per function become sections per topic.

### The Prelude's code

Chapter 9's code against the Prelude rhc vendors as the Report's (`share/rhc/haskell98/pristine/`), with blank
lines dropped (`results/E1/prelude-diff.md`) [measured]:

| Module | Lines | Identical | Spacing only | Different |
|---|---:|---:|---:|---:|
| Prelude | 466 | 457 | 8 | 1 |
| PreludeList | 240 | 239 | 0 | 1 |
| PreludeText | 164 | 162 | 1 | 1 |
| PreludeIO | 57 | 57 | 0 | 0 |
| All | 927 | 915 | 9 | 3 |

The three are the imports, renamed for the hierarchy: `import Data.Ratio( Rational )` (T10:7543),
`import qualified Data.Char(isSpace)` (T10:8422) and `import Data.Char(isSpace, isAlpha, ...)` (T10:8867). The nine
spacing lines are 98's tabs written as spaces. The prose before the code changes only module names. **So every 98
reading of the Prelude's code carries over unchanged:** R39 (Enum Float), R42 (`showsPrec p = showFloat`, still at
T10:9089-9093), R43 (`lex`), R46 (`getLine`), R47 (the code does not compile as printed), R51 (tuples).

**98's two code errata are not in it.** Against 98 with its errata as rhc's overlay applies them, 2010 reverts both:
`enumFrom` and `enumFromThen` of `Enum Float` and `Enum Double` are again `numericEnumFrom` and
`numericEnumFromThen` with no `seq` (T10:8258-8292; erratum of May 2003), and `lex` again tests `isAlpha` in its third
guard and holds `'_'` in `isSingle` (T10:9036-9051; erratum of February 2003). So 6.3.4's "For all four of these Prelude
numeric types, all of the enumFrom family of functions are strict in all their arguments." (T10:6097-6098) disagrees
with the code again, and so does 2.4's identifier with a leading underscore with `lex`. Whether the 2010 mode applies
98's errata to 2010's identical text is N18.

**The Prelude still imports modules that now have no code.** PreludeText imports seven names of Data.Char and seven
of Numeric (T10:8867-8870), PreludeList Data.Char's `isSpace`. In 98 those modules had code (Char 19.1, Numeric 14.4);
in 2010 they are prose (chapters 16 and 38). Their code must come from somewhere, and the types of the fourteen
names are 98's but `readDec`'s (`Num` in 2010, `Integral` in 98's code). *The libraries* takes it from there (D23,
D24).

### 98's errata in 2010

rhc's 98 mode applies all 18 published errata (`tests/hs/errata.tsv`). Against the 2010 text [read]
(`results/E1/delta.md`, Δ17):

| Erratum | 98 section | In 2010 | Where | Behaviour at issue |
|---|---|---|---|---|
| Dec 2005, `--:` | 2.2 | Absorbed, by `:` joining ascSymbol | T10:1626, 1674 | None |
| Jul 2004, field order | 3.17.2 case 6 | **Not absorbed**: "in the order they are named in the field list" | T10:3199 | None: rule (m) fixes the pattern's order (N17) |
| Jan 2005, match wording | 3.17.2 case 6 | **Not absorbed** | T10:3199 | None |
| Mar 2008, n+k | 3.17.2 case 8 | Moot: n+k is gone | | None |
| Jul 2004, `=<<` in Table 4.1 | 4.4.2 | **Not absorbed**: the table still lacks it | T10:4503-4522 | None: the Prelude declares `infixr 1 =<<` |
| May 2003, `enumFrom` strict | 6.3.4 | **Not absorbed** (code) | T10:8258-8292 | Yes (N18) |
| Jun 2003, `properFraction` at zero | 6.4.6 | **Not absorbed** | T10:6446-6447 | A test's expectation |
| Feb 2008, the `do` example | 7.2 | **Not absorbed**: still `putStr` | T10:6608 | A test's expectation |
| Feb 2003, `lex` and `_` | 8.2 | **Not absorbed** (code) | T10:9036-9051 | Yes (N18) |
| Sep 2004, `qvar` in exports | 9.5 | **Not absorbed**: 10.5 keeps `qvar` where 5.2 says `var` | `results/E1/html10/ch10.txt:182` | Parser (R34(b)) |
| Aug 2005, `approxRational` | 12 | Absorbed in effect: "within epsilon of x" | T10:13563-13564 | None (N15) |
| Mar 2003, the Ix law | 15 | Absorbed, with a stray parenthesis | T10:12510 | None |
| Sep 2008, `genericTake` on negatives | 17 | Absorbed in effect: "an overloaded version of take" | T10:13323 | None |
| Mar 2003, "converts the to" | 19 | Absorbed by rewrite | T10:12095-12096 | None |
| Nov 2006, "doing so not an error" | 21.3.2 | Absorbed | T10:16308 | None |
| Three index errata | indexes | Not applicable: 2010's index is its own | | None |

So 6 absorbed, 8 not, 1 moot, 3 not applicable. Of the 8, the two code errata change what a program does, two
(field order, `qvar`) bear on readings rhc has already settled, and four are wording or examples. GHC's `base`
behaves as the errata on `lex` and as the code on `enumFrom` [probe `n18a_enum_float_strict`,
`n18b_lex_underscore`] (base): `take 0 (enumFrom (undefined :: Double))` is `[]`, and `lex "_foo bar"` is
`[("_foo"," bar")]`.

### The clause matrix and its counts

`results/E1/clauses2010.tsv` holds the 2010 Report's normative content in `tests/hs/conformance.tsv`'s row form, with
three more columns: `map98` (the 98 rows a row comes from), `delta` and the T10/T98 lines. It has **5,259 rows**
[measured]:
- **2,736 same:** the 2010 text states 98's requirement, and the row keeps 98's id. Its statement may be reworded where
  only a production, a nonterminal's name or a cross-reference changed.
- **912 changed:** a new id (98's plus `.h2010`, or the 2010 module's name for a library row) whose requirement,
  module or form differs; `map98` names the 98 row.
- **1,358 new:** no 98 row; 126 written by hand (`results/E1/new10.txt`: guards, empty data, the FFI, 10.6, derived
  instances, pragmas), 1,232 generated from the 2010 chapters' exports, values, classes, types and instances.
- **253 removed:** 98 rows with no 2010 counterpart, 216 of them library rows (the five dropped modules, `bracket`,
  `bracket_`, `system`, and helpers of 98 code that 2010 has as prose) and 37 language rows (n+k, the precedence
  grammar).

Every one of 98's 3,901 rows is in some row's `map98`; the builder checks it. 107 hand decisions on 98 rows
(`results/E1/rules.tsv`) settle the sections the diff showed changed; elsewhere 98's chapters 1-11 map as same, 9.5's
productions are compared with 10.5's, and library rows follow the module that exports the name.

| 2010 chapters | Same | Changed | New | In 2010 | Accept | Reject | Run | None |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 Introduction | 11 | 0 | 0 | 11 | 4 | 4 | 1 | 2 |
| 2 Lexical structure | 270 | 3 | 5 | 278 | 137 | 64 | 74 | 3 |
| 3 Expressions | 428 | 5 | 26 | 459 | 104 | 88 | 258 | 9 |
| 4 Declarations | 476 | 6 | 10 | 492 | 192 | 188 | 110 | 2 |
| 5 Modules | 244 | 2 | 3 | 249 | 110 | 104 | 26 | 9 |
| 6 Predefined types and classes | 305 | 2 | 0 | 307 | 16 | 21 | 259 | 11 |
| 7 Basic I/O | 53 | 0 | 0 | 53 | 1 | 2 | 46 | 4 |
| 8 Foreign function interface | 0 | 0 | 54 | 54 | 18 | 8 | 17 | 11 |
| 9 Standard Prelude | 472 | 2 | 0 | 474 | 177 | 11 | 278 | 8 |
| 10 Syntax reference | 284 | 26 | 26 | 336 | 282 | 45 | 2 | 7 |
| 11 Derived instances | 165 | 0 | 2 | 167 | 21 | 21 | 120 | 5 |
| 12 Pragmas | 10 | 0 | 8 | 18 | 11 | 2 | 1 | 4 |
| **Language, 1-12** | **2,718** | **46** | **134** | **2,898** | **1,073** | **558** | **1,192** | **75** |
| 13-23 Control.Monad and Data.* | 0 | 565 | 375 | 940 | 264 | 10 | 653 | 13 |
| 24-37 Foreign.* | 0 | 0 | 767 | 767 | 308 | 0 | 459 | 0 |
| 38 Numeric | 18 | 48 | 0 | 66 | 18 | 0 | 47 | 1 |
| 39-42 System.* | 0 | 253 | 82 | 335 | 101 | 0 | 215 | 19 |
| **Libraries, 13-42** | **18** | **866** | **1,224** | **2,108** | **691** | **10** | **1,374** | **33** |
| **All in 2010** | **2,736** | **912** | **1,358** | **5,006** | **1,764** | **568** | **2,566** | **108** |

From `clauses2010.tsv`, recounted by chapter while writing [measured]; the per-chapter counts are
`results/E1/clauses2010-counts.tsv`. Chapter 25 (Foreign.C) only re-exports and has no rows. Of the 5,006 rows,
2,663 are written by hand and 2,343 generated.

**What the matrix is not.** It is a first reading, as E9's was for 98:
- The T10/T98 lines of hand rows are pointers to the line with the best word match (column `lines` says how each was
  found), not quotations; `delta.md` cites lines read by hand.
- 98's library prose rows (`lib.r.*`) are mapped by name. Unless a hand rule rewrote one (`isSpace`, `isUpper`,
  `isAlpha`, `genericLength`, `approxRational`, the Ix law), a row keeps 98's statement under the 2010 module and must
  be checked against 2010's prose by whoever writes the 2010 table.
- "Changed" covers both a renamed module with the same code (Data.Array, Data.Complex, Data.Maybe, Data.Ratio) and
  code replaced by prose; the `note` column tells them apart.
- Accept and reject classes are read from the text, not run.

rhc's enforcement fixes 98's figures (`clauses = 3901`, `errataCount = 18`, `readings = 54`:
`tests/runner/hsconformance.sml:48`, `:49`, `:57`), so a 2010 table needs figures of its own and directories of its
own, since a test's id is its file name (D38, *Testing and conformance*).

### The libraries, in brief

*The libraries* covers them: what each of the 30 modules is, where the code of the 26 prose modules comes from, the
layout of `share/rhc/haskell2010` and its cycle. What the Report itself contributes:
- **The code is the text for four modules only,** and two of the four do not compile as printed (N11). For the rest
  the prose is the specification, generated from GHC's `base` of 2010, and thin in places: no strictness is stated for
  most functions, so 98's rule that a library's strictness is its code's (98's ruling 30) has nothing to stand on.
- **The Prelude's code imports Data.Char and Numeric,** both prose now (*The Prelude's code*).
- **Data.Char changes meaning** beyond Latin-1 (N7; *Haskell 98 mode and the 2010 text*, D13c, D13d) and names no
  Unicode version (N8).
- **Data.Int and Data.Word describe wrapping arithmetic** of `Int` and `Word` (N6; D21, D22).
- **Data.Bits is a Num subclass** and so reaches defaulting (N9; D20).
- **Data.Maybe's code defines its own `maybe`,** beside the Prelude's (N11); D23's overlay entry restores 98's
  re-export, since hiding the Prelude's name instead breaks every user of Data.Maybe (E9).
- **Data.Ix's instance list stops at 5-tuples** while 19.2 requires 15 (N16).

### The readings of 2010

`results/E1/readings2010.md` has 21 places where the 2010 text is wrong, contradictory, ambiguous or underspecified
(its heading says N1-N20; it holds N21). Each is checked on GHC 9.4.7. Four restate 98 readings unchanged (N15,
N17, N19, N20), N2 and N3 carry parts of R1, R9 and R65, and the rest are new with 2010.

| N | Where | The problem | Kind | GHC 9.4.7 [probe] | Decision |
|---|---|---|---|---|---|
| N1 | 8 | The FFI: when a pure import is called; `chname` admits no digit; spacing in an entity; newtypes across modules; `Word` not a basic type; threads, exceptions, `hs_init` after `hs_exit`; a `wrapper`'s lifetime | Underspecified; `chname` wrong | Lazy as a value, strict in its argument; accepts `x86_64.h`, extra spaces and no entity; refuses `Integer`, accepts `Word` | D27-D33 |
| N2 | 3, 10.6 | The grammar derives `a + - b` and `- - a`, which 3's prose and 10.6 refuse; 10.6 is "an example" | Ambiguous | Refuses both, and `(+ - 1)` | D17 |
| N3 | 3.13, 3.17.3 | Rule (s) names a `y` it never uses; a `where` cannot see a guard's bindings; a `let` guard and a `let` expression part only at `in` | Wrong (rule (s)); underspecified | `where` refused ("not in scope"); `let` guard closed at `,` | D14 |
| N4 | 4.5.1, 4.5.5 | Rule 1 acts on 2010's smaller groups, so a program 98 refuses is legal in 2010 | A consequence; 4.5.2's reach open | Accepts in both modes | D16 |
| N5 | 12 | "should be ignored" against "must fail"; a pragma after `module`; case; combinations; CPP undefined | Ambiguous | Error on an unknown name; warns on a misplaced one; accepts lower case and `Haskell98, Haskell2010, NPlusKPatterns, NoNPlusKPatterns` | D4-D7 |
| N6 | 6.4, 18, 23 | `Int` modulo 2^n against 6.4's "undefined"; a left shift of a negative value by the width is "-1"; Word "the same size as Int" | Contradictory, or narrowing (both read below); the shift sentence wrong | Wraps; `shiftL (-1 :: Int8) 8` is 0; Word 64 bits (base) | D21, D22 |
| N7 | 16 | `isSpace`'s "any Unicode space character": category Zs, or the White_Space property | Ambiguous | Zs and the five controls (base) | D26 |
| N8 | 2.1, 16 | No Unicode version | Underspecified | Unicode 14.0 (base) | D26 |
| N9 | 4.3.4, 15 | Defaulting reaches Bits, a Num subclass in a standard library | Plain text; GHC departs | Refused: ambiguous type | D20 |
| N10 | 6.4.3 | `0**y` "is 1 if y is 1, and 0 otherwise" | Wrong (a misprint) | IEEE: `0 ** 0` is 1, `0 ** (-1)` infinity (base) | D13b, D38 |
| N11 | 14, 17, 19, 20, 21, 22 | `module Array (`; Ratio's missing parenthesis; Data.Maybe's own `maybe`; `Complex(:+)`; the Ix law; "iteratef" | Wrong | Ratio's and Complex's text are parse errors, Data.Maybe's `maybe` ambiguous; Array compiles as module Array | D23, D38 |
| N12 | 4.2.1, 11 | Empty data: deriving, kinds, `case` on one | Underspecified | Refuses `deriving (Eq, Show)`, accepts `deriving ()` | D15 |
| N13 | 3 | `if`'s semicolons are absorbed in every layout block, and no prose says so | Underspecified | Accepts in `let` and `case` blocks; refuses under 98 | D17 |
| N14 | 2.4, 5.2 | `A.B.C` lexes by context; `module M` in exports names an alias | Ambiguous (98's R30) | By alias | D18 |
| N15 | 6.4.6, 22 | `approxRational`'s "within" | Ambiguous (98's R44) | Closed interval (base) | D38 |
| N16 | 19 | The instance list gives Ix to 5-tuples; 19.2 requires 15 | Contradictory | Ix of a 6-tuple works (base) | D38 |
| N17 | 3.17.2 | "the field list": the pattern's or the declaration's | Ambiguous (98's R16; erratum not absorbed) | The pattern's | D38 |
| N18 | 9, 6.3.4, 2.4 | Do 98's eight unabsorbed errata apply to 2010's identical text? | Ambiguous | `enumFrom` lazy (code); `lex "_foo"` one lexeme (erratum) (base) | D38 |
| N19 | 4.4.3.2, 4.5.5 | "Simple pattern binding" defined twice | Contradictory (98's R18) | Not probed | None new |
| N20 | 4.2.1 | Strict fields forced last first by the translation | 98's R24, unchanged | Forces the first field first | None new |
| N21 | 3.1, 7.3, 40 | How a program ends: chapter 23's rules gone | Underspecified | Writes buffered output, then exits 1, as 98's chapter 23 | D38 |

The ones that shape decisions, in more detail:

#### N1. The FFI's gaps

- **When a pure import runs.** "External functions are strict in all arguments." (T10:6892), and a pure import "asserts
  that the external entity is a true function" (T10:6948); nothing says the call is lazy as a value, or when and how
  often `foreign import ccall foo :: CInt`, "a pure C function foo with no arguments" (T10:7064-7066), is called. GHC: a
  pure import is an ordinary lazy function, strict in its arguments once applied: `const 1 (c_sin undefined)` is 1, and
  ``c_sin undefined `seq` ()`` fails [probe `n01a_ffi_pure_lazy`].
- **`chname -> {chchar} . h` with `chchar -> letter | ascSymbol<&>`** (T10:6742-6755): no digit, so `x86_64.h` is no
  header name. A defect. GHC does not check: it compiles and runs `"x86_64.h abs"` [probe `n01b_ffi_header_digits`].
- **`impent -> " [static] [chname] [&] [cid] "`** (T10:7030-7036) gives no separator, while every example writes a
  space. GHC accepts runs of spaces, no header, and no entity string at all, the C name then the variable's [probe
  `n01c_ffi_entity_spaces`].
- **Newtypes:** marshallable only if "the constructor N is visible where T is used" (T10:6893-6912). What an interface
  must carry for that across modules is the implementation's (D9, D32).
- **Basic types** are "Char, Int, Double, Float, and Bool" and the sized types (T10:6862-6864): no `Word`, though
  Data.Word and Foreign.Storable treat it as foreign. GHC accepts `Word` and refuses `Integer` ("cannot be marshalled")
  [probe `n01f_ffi_word`, `n01e_ffi_nonforeign_type`].
- **Left implementation-defined or undefined:** threads (T10:6680-6682); an exception escaping an exported function
  (T10:6980-6981); an unsafe call that calls back (T10:6957-6958).
- **`hs_init` after `hs_exit`** must work (T10:7436-7439). GHC does not support it and says so
  (`docs/users_guide/bugs.rst:488-491`) [read].
- **Callbacks** are spoken of only between a safe call and its return: "a callback into the Haskell system implies
  that a garbage collection might be triggered after an external entity was called, but before this call returns"
  (T10:6959-6960). Nothing says whether one may come after the call has returned, nor how long a `wrapper`'s function
  pointer lives before `freeHaskellFunPtr`. D31 reads 8.4.3 as the limit; *The foreign function interface* sets it
  against Rune's callbacks.

#### N2. 10.6 against chapter 3's grammar

3's `infixexp -> lexp qop infixexp | - infixexp | lexp` (T10:2058-2071) derives `a + - b` and `- - a`. 3's prose says
negation "has the same precedence as the infix - operator" (T10:2151-2152), and 10.6's code refuses a negation after
an operator of precedence 6 or more. 3 calls 10.6 "An example algorithm" (T10:2150), so the rules are 3's prose and
10.6 illustrates them; where 10.6 is the only precise statement it is, in effect, the definition. GHC refuses
`1 + - 2`, `- - 1` and the section `(+ - 1)` and accepts `1 == - 1` and `- 2 ^ 2` (-4) [probe `n02a_neg_after_op`,
`n02b_double_neg`, `n02d_section_neg`, `n02c_neg_low_op`]. Patterns: 10.6 says "Fixity resolution also applies to
Haskell patterns, but patterns are a subset of expressions" (T10:10547-10548), yet `lpat -> - (integer | float)` is a
negative literal, not a negation; GHC matches `x : -1 : _` [probe `n02g_pattern_neg`]. 10.6's "precedences in the
range 1 to 10" (T10:10638-10639) should read 0 to 9; a misprint with no effect.

**The two 98 deviations become the text.** With the conceding notes deleted, a `let` or `do` takes the whole operator
sequence and resolution refuses it. GHC refuses `let x = True in x == x == True` and `do a == b == c` in both modes:
"cannot mix '==' [infix 4] and '==' [infix 4]" [probe `n02e_let_nonassoc`, `n02f_do_nonassoc`, `.2010` and `.98`].
rhc does the same in 98 mode, as deviations DV1 and DV8.

#### N3. Pattern guards

- **Rule (s)** reads "case () of { () | g1, ..., gn -> e; _ -> e' } = case () of { () | g1 -> ... case () of { () | gn
  -> e; _ -> e' } ... _ -> e' } where y is a new variable" (T10:3436-3447; the HTML's ellipses and primes in ASCII): no
  `y` occurs, and `e'` is copied n times. A copy from rule (c), reported in 2018 (E10-8). Copying `e'` keeps the
  meaning; an implementation shares it as (c) does. A defect for *Found while writing*.
- **Scope.** Guard bindings "are in scope in the following guards and the corresponding expression"
  (T10:2800-2801), and the `where` declarations "scope over all of the guards and expressions of the alternative"
  (T10:2771). So a `where` cannot name a pattern guard's variable. GHC: "Variable not in scope: y" [probe
  `n03c_guard_where_scope`].
- **`let` in a guard.** `guard -> let decls` sits beside `guard -> infixexp`, whose `lexp` may be `let decls in exp`,
  so a parser must look past the declarations for `in`; the implicit block a `let` guard opens closes at `,`, `->` or
  `=` by parse-error(t). GHC: `f x | let y = x * 2, y > 4 = y` gives `(0,6)` for `(f 1, f 3)` [probe
  `n03a_guard_let_comma`]. 3.13 keeps 98's "note about parsing" (T10:2806-2814), and GHC still refuses its example, as
  for 98 (R65) [probe `n03b_guard_let_vs_letexp`].
- **Fall-through** to the next guarded expression, then the next alternative: GHC `(5,-5,0)` [probe
  `n03d_guard_fallthrough`]. A guarded pattern binding binds lazily: `5` [probe `n03e_guard_patbind`].

#### N4. Smaller groups under the monomorphism restriction

Rule 1 is stated per declaration group ("We say that a given declaration group is unrestricted if and only if",
T10:4847), and 2010's groups are smaller. In `f :: Num a => a -> a; f x = x + fromIntegral (length k);
k = [f (1 :: Int)]`, 98 makes `f` and `k` one group, restricted by `k`, so `f`'s signature is too general and the
program is refused; 2010 puts `k`, which reaches `f` only through its signature, in a group of its own, and `f`
generalises [inferred from the two texts]. GHC accepts it in both modes, `(3,3.5)` [probe `n04b_relaxed_mr`, `.2010`
and `.98`], because it always uses the relaxed analysis (`docs/users_guide/bugs.rst:241-262`) [read]. **So GHC is no
oracle for 98 here,** nor for its own documented example [probe `n04a_relaxed_ghcdoc`]. Rule 2 is untouched
[probe `n04c_relaxed_default`]. 4.5.2's identical contexts now bind only variables of one pattern binding, which Rule 1
restricts anyway, and GHC reports the restriction first [probe `n04d_identical_contexts`]; whether 4.5.2 can still
refuse a program Rule 1 accepts is open [inferred: it cannot, since a pattern binding of two variables is never simple].

#### N5. Chapter 12

- **Two rules meet.** Unrecognised pragmas "should be ignored" (T10:10927-10928); an unrecognised or unsupported
  feature "must fail with an error" (T10:10989-10990). Read together: the pragma is recognised and its feature is
  not, so the second rule applies. GHC: "Unsupported extension: NoSuchFeatureAtAll" [probe `n05a_lang_unknown`].
- **"must precede the module keyword"** (T10:10981) says nothing of a pragma after it. GHC warns
  (`-Wmisplaced-pragmas`) and ignores it, unknown name and all [probe `n05c_lang_after_module`]. A module with no
  header has no `module` keyword; GHC takes the pragma there [probe `n05d_lang_no_header`].
- **Case** is not discussed; GHC accepts `{-# language EmptyDataDecls #-}` [probe `n05b_lang_lowercase`].
- **Combinations** must fail when unsupported, and none is named. GHC accepts
  `Haskell98, Haskell2010, NPlusKPatterns, NoNPlusKPatterns` in one pragma, the later winning [probe
  `n05g_lang_combination`].
- Unknown pragmas draw a warning [probe `n05e_unknown_pragma`]; INLINE and SPECIALIZE are `decl`s and so sit in
  `where` blocks too [probe `n05f_inline_local`]. CPP is named by the only example and defined nowhere (D12).

#### N6. `Int`: 6.4 against Data.Int

6.4: "The results of exceptional conditions (such as overflow or underflow) on the fixed-precision numeric types are
undefined; an implementation may choose error (_|_, semantically), a truncated value, or a special value such as
infinity, indefinite, etc." (T10:6239-6241). Data.Int: "This module provides signed integer types of unspecified
width (Int) and fixed widths (Int8, Int16, Int32 and Int64). All arithmetic is performed modulo 2^n, where n is the
number of bits in the type." (T10:12381-12382). Two readings, both stated in D21:
- **A contradiction** (E1): 6.4 allows an error on overflow, which is rhc's checked 63-bit `Int` (98's D22), and
  Data.Int requires wrapping. Data.Int's prose is generated from `base`'s documentation, where `Int` wraps, and may
  name `Int` loosely. On this reading 2010 settles nothing.
- **A narrowing** (the lead's reading): chapter 18 is the more specific text and picks one of the behaviours 6.4
  allows, a truncated value.

Two smaller defects: "Right and left shifts by amounts greater than or equal to the width of the type result in
either zero or -1, depending on the sign of the value being shifted" (T10:12388-12389) is right for right shifts,
but a left shift of a negative value by the width is 0, not -1; and "A Word is an unsigned integral type, with the
same size as Int." (chapter 23) gives a 63-bit Word under rhc's `Int`. GHC (base): `maxBound + 1 :: Int` is
`minBound`, Int8 and Int32 wrap [probe `n06a_int_overflow`]; `shiftL (-1 :: Int8) 8` is 0 and `shiftR` is -1
[probe `n06b_shift_width`]; Int and Word are 64 bits [probe `n06c_word_size`].

#### N7, N8. `isSpace` and the Unicode version

"Returns True for any Unicode space character, and the control characters \t, \n, \r, \f, \v." (T10:11833): general
category Zs, or Unicode's White_Space property, which adds U+0085, U+2028 and U+2029. GHC's `base` takes Zs: True for
U+00A0, U+1680, U+2003, U+202F and U+3000; False for U+0085, U+2028, U+2029, U+200B, U+180E and U+FEFF; `words`
splits at U+2003 and U+00A0 and not at U+2028 [probe `n07a_isspace`] (base). 2.2's `uniWhite`, "any Unicode
character defined as whitespace", is the same question for source text (98's R4, R5). No version is named (Δ15):
GHC 9.4.7's `base` knows U+1FAD7 (Unicode 13.0) and U+1FAE0 (14.0) and not U+1FAE8 (15.0), so it is at 14.0
[probe `n08a_unicode_version`] (base). On `isUpper` and `isAlpha` GHC follows 2010's prose: U+4E2D (Lo) and U+02B0 (Lm)
are alphabetic and not upper case, U+01C5 (Lt) is upper case [probe `n07b_isupper_caseless`] (base).

#### N9. Defaulting reaches Bits

By Δ14 `print (shiftL 1 3 .|. 1)` is legal 2010 and prints 9. GHC refuses it, "Ambiguous type variable"
[probe `n09a_default_bits`]: its Bits has no Num superclass, a departure it documents
(`docs/users_guide/bugs.rst:370-372`) [read], and its standard classes are a fixed list with neither Bits nor
Storable in it (`compiler/GHC/Builtin/Names.hs:2746-2755`) [read]. Here the Report is plain and GHC is not the
oracle.

#### N10. `0**y`

Read literally, `0 ** 1` is 1 and `0 ** 0` is 0, against arithmetic. Read as meant ("1 if y is 0"), it agrees with
IEEE's `pow` for y >= 0 and says 0 where IEEE gives an infinity for y < 0; neither reading mentions a NaN. GHC
(base): `(0 ** 0, 0 ** 1, 0 ** 2, 0 ** (-1))` is `(1.0,0.0,0.0,Infinity)` [probe `n10a_zero_pow`]. rhc's 98 mode takes
IEEE (R45, `tests/hs/lang/std.pow.undefined.hs`); D13b keeps it there, and the 2010 mode must record a reading for
negative y, since even the corrected sentence says 0.

#### N11. The code chapters

- **14.6 is headed `module Array (`** while exporting `module Data.Ix`; GHC compiles it with `-fno-code` as module
  Array [probe `n11c_array_spec_as_printed`]. A naming defect.
- **22.1's `Show (Ratio a)`** reads `showsPrec p (x:%y) = showParen (p > ratPrec) showsPrec (ratPrec+1) x . showString
  " % " . showsPrec (ratPrec+1) y)` (T10:13724-13730), one opening parenthesis short of 98's. GHC: "parse error on
  input ')'" [probe `n11b_ratio_spec_as_printed`]. 98's line is the evident correction.
- **21.2's Data.Maybe** defines and exports `maybe` (T10:13431-13440) while the Prelude, imported implicitly, exports
  its own (T10:8103-8106), so the export is ambiguous. GHC reports an "Ambiguous occurrence" of `maybe`
  (`results/E9/probes/MaybeClash.hs`, E9's probe; E1's N11 does not list it). Hiding the Prelude's `maybe` in the
  module compiles it and makes every unqualified use by an importer ambiguous (`results/E9/probes/maybeprobe/`).
- **Data.Complex's export list** prints `Complex(:+)` (`results/E1/html10/ch17.txt:5`; 17.4's code has
  `Complex((:+))`). GHC: "parse error on input ':+'" [probe `n11a_complex_export`].
- **19.1's law** `map (index (l,u)) (range (l,u))) == [0..rangeSize (l,u)-1]` has a stray parenthesis (T10:12510).
- **20's "iteratef", "repeatx", "replicaten x"** (E10-1).

So the 2010 code chapters, like 98's Prelude, do not compile as printed. D23 gives the defects overlay entries.

#### N12, N13. Empty data, and `if` in layout blocks

An empty type derives nothing (condition 6, T10:10670), so `data T deriving (Eq, Show)` is refused and
`data T deriving ()` is legal. GHC refuses the first in 2010 mode, naming EmptyDataDeriving, refuses the empty
declaration itself in 98 mode, and accepts the second [probe `n12a_empty_deriving`, `.2010`, `.98`;
`n12b_empty_deriving_unit`]. The kind of an empty type's parameter is unconstrained, so 4.6's default `*` applies
[inferred]. `case x of {}` stays illegal: "A case expression must have at least one alternative" (T10:2791; 98's R13).

`lexp -> if exp [;] then exp [;] else exp` puts the semicolons in the grammar, so a layout `;` before `then` or `else`
is absorbed in any block: a `let` binding and a `case` alternative as well as a `do` statement. GHC accepts both under
`-XHaskell2010` and refuses both under `-XHaskell98` ("Unexpected semi-colons in conditional ... Perhaps you intended
to use DoAndIfThenElse") [probe `n13a_ifthen_let`, `n13b_ifthen_case`]. No prose says so; the grammar implies that a
parser shifts the `;` into the conditional rather than end the binding.

#### N16. Ix for tuples

6.1.4 requires tuples to size 15 "together with the instances for Eq, Ord, Bounded, Read, and Show"
(T10:5698-5699), and 19.2 keeps 98's "A Haskell implementation must provide Ix instances for tuples up to at least
size 15." (T10:12562). But 19's instance list, generated from `base`, stops at 5-tuples
(`results/E1/html10/ch19.txt:40-43`). The list is incomplete; 19.2's sentence is the requirement, and 98's R51 stands.
GHC's `base` has Ix of a 6-tuple [probe `n16a_ix_tuple6`] (base).

#### N18. 98's errata and 2010's text

Eight 98 errata are not in the 2010 text, and 2010 has none of its own. Two readings: (i) the 2010 mode takes 2010's
text as printed, 98's errata notwithstanding; (ii) the errata mended mistakes the 2010 editors copied, and apply to
2010's text where it is 98's word for word. What a program sees: `enumFrom` and `enumFromThen` at Float and Double lazy
(the code) or strict (6.3.4's prose and the erratum), and `lex "_foo"` one lexeme or two. 6.3.4's prose contradicts
the code in 2010 too, so reading (ii) is also "the prose over the code", 98's R39 ground. D38 recommends (ii) where the
text is identical, each a reading on the ground "wrong".

#### N21. How a program ends

98's chapter 23 is gone (Δ12). 2010 keeps 3.1's "When evaluated, errors cause immediate program termination and
cannot be caught by the user." (T10:2181-2182) and 7.3's "When an exception propagates outside the main program, the
Haskell system prints the associated IOError value and exits the program." (T10:6654-6655). So under 2010 it is
unspecified whether buffered output is flushed at exit, what the status is after `error`, and what a normal end
returns; or 3.1's "immediate" decides against flushing. The editors may only have dropped the prose with the System
module's split. GHC writes the buffered text before the error message and exits with status 1, as 98's chapter 23 says
[probe `n21a_error_exit`]. rhc's R37 and the lead's rulings 57-58 of the 98 campaign rest on chapter 23, which has no
2010 counterpart. D38 recommends keeping 98's behaviour in 2010 mode as implementation-defined, documented.

### What this gives the decisions

- **D38:** the 2010-07-20 text as published; no errata list to adopt. 98's eight unabsorbed errata are a reading
  (N18); the code chapters' defects are overlay entries (N11); Ix to 15-tuples (N16); program end (N21). The 2010 table
  is `clauses2010.tsv`'s 5,006 rows, a first reading to be worked through as 98's was.
- **D2, D23:** the Prelude's code is 98's, so a 98 module in a 2010 program meets the same Prelude; what it cannot
  find is 98's other modules. The Prelude imports two prose modules, whose code rhc must supply.
- **D14:** pattern guards by 3.13 and 3.17.3, rule (s) shared as (c) does, a `where` blind to guard bindings, `let`
  guards closed by parse-error(t) (N3).
- **D15, D16, D17, D18:** empty data with condition 6 (N12); relaxed groups in the checker and HsLint, where GHC cannot
  judge 98 (N4); `if` semicolons in every block (N13), negation by 10.6 (N2), n+k off, `foreign` reserved; hierarchical
  names everywhere (N14).
- **D4-D7, D19:** an unknown or unsupported feature is an error; a misplaced pragma, case and combinations are rhc's to
  define (N5); INLINE and SPECIALIZE as in 98.
- **D20:** defaulting's standard classes per edition, Bits included, against GHC (N9).
- **D21, D22:** `Int` under 2010 has two readings (N6).
- **D26:** `isSpace` as Zs plus the five controls, or White_Space; `isUpper` and `isAlpha` by 2010's prose; the Unicode
  version implementation-defined (N7, N8).
- **D27-D33:** chapter 8's gaps (N1).
- **D13a-D13d:** 2010 changes four library behaviours that 98 mode also has: `genericLength`'s type, `0**y`,
  `isUpper`/`isAlpha` and `isSpace` (*Haskell 98 mode and the 2010 text*).
- **Tracks:** F takes Δ2-Δ10 (N2, N3, N4, N12, N13, N14); L takes Δ12-Δ15 (N6-N11, N15, N16, N18).
- **Oracles:** GHC 9.4.7 departs from 2010's text on Bits defaulting (N9), cannot test 98's grouping (N4), and
  answers library questions from `base` 4.17, not the Report; E8's shim narrows the last.

## Haskell 98 mode and the 2010 text

The brief allows one kind of change to 98 mode, and asks that it be made plain:

> the haskell98 mode needs to stay haskell 98 as per its report. in case we made an arbitrary choice during the
> haskell98 roadmap in rhc because the haskell 98 report was ambiguous or underspecified you may bring rhc in
> haskell98 mode in line with haskell 2010 (reading the haskell 2010 report as clarifying what the haskell 98 should
> have said, but be very explicit in the roadmap that you will be doing so, so i can review)

**This roadmap recommends one such change: D13a, `genericLength`'s type in 98 mode's List.** One more passes the test
and is recommended against (D13b); two would override 98's plain text and are recommended against (D13c, D13d). Three
points that are not alignments are put to the owner because they would change 98 mode too if taken (R41, R21(c), R54).
Of the alignments, everything else leaves 98 mode as it is; D2, D6, D8 and M18's two defect fixes change it otherwise
(*Decisions*). Every item that would change what 98 mode does says so in bold where it is argued.

Source: E2 (`results/E2/alignment.tsv`, 232 rows, made and checked by `alignment.py`; the argument in
`alignment.md`), on E1's account of the 2010 text (*What the 2010 Report says*). rhc's pins are cited against
75ed95861; T98 and T10 lines were opened while writing.

### The rule and the test

E2 put every choice rhc made for 98 to a three-part test, the brief's condition taken literally:
1. **98's text admits two readings,** is silent, or contradicts itself;
2. **rhc picked one;**
3. **2010's text picks the other,** or picks one where rhc's choice was free.

Each item gets one of five outcomes:
- **ALIGN:** all three hold. The brief allows the change, on the owner's word.
- **OVERRIDE:** 2010 differs from rhc, but 98's text was plain and rhc followed it, so (1) fails. Changing 98 mode
  would break "98 stays 98"; the brief does not allow it.
- **CHANGE:** 2010 changes the language (pattern guards, n+k, empty data and the like). Not a clarification of 98, so
  not eligible; 2010 mode takes it and 98 mode does not.
- **SAME:** 2010 agrees with rhc, with its text unchanged or changed in rhc's direction.
- **OPEN:** 2010 does not settle it: the same ambiguous text, a text that contradicts itself, or a subject 2010 drops.

The test is stricter than "2010 says something else". rhc's 98 mode already sorts every departure from the 98 text by
one rule, decided by the owner (98's D38: wrong, contradictory, ambiguous, conceded by the Report), and several
choices that look arbitrary were readings of a plain text, some decided by the owner by name. An item that rhc
settled by following the text fails at (1) whatever 2010 says.

### The 232 items by outcome

E2 covers every reading (R1-R95 and R150-R158, with sub-items where a reading has several parts), the 8 deviations
of `tests/hs/deviations.tsv`, the 53 entries of `share/rhc/haskell98/overlay.tsv`, and the language rulings and owner
items of the 98 campaign (`haskell98` drafts, `impl/rulings.md` and `impl/owner-list.md`) [measured, from
`alignment.tsv`]:

| Kind | Rows | SAME | OPEN | CHANGE | ALIGN | OVERRIDE |
|---|---:|---:|---:|---:|---:|---:|
| Readings R1-R95, R150-R158 | 120 | 51 | 57 | 7 | 2 | 3 |
| Deviations DV1-DV8 | 8 | 2 | 6 | 0 | 0 | 0 |
| Overlay entries | 53 | 27 | 23 | 0 | 1 | 2 |
| Rulings | 42 | 10 | 30 | 2 | 0 | 0 |
| Owner items | 9 | 7 | 2 | 0 | 0 | 0 |
| **All** | **232** | **97** | **118** | **9** | **3** | **5** |

Rulings and owner items about process, measurement or implementation, with no clause of either Report at issue, are
not in the table; `alignment.md` lists them.

**The 8 ALIGN and OVERRIDE rows are 4 items.** The ALIGN rows are R48 with its overlay entry `ov.list.genericlength`
(D13a), and R45(b) (D13b). The OVERRIDE rows are R38(a) with R153(b), `ov.char.prims` and `ov.char.isalpha` (D13c), and
R153(a) (D13d). E2 files `ov.char.prims` under both, but the entry names `isUpper` and not `isSpace`
(`share/rhc/haskell98/overlay.tsv:44`), so it belongs to D13c alone; `isSpace` is the Report's line, with no entry.

**The 9 CHANGE rows,** each a 2010 feature that 98 mode does not take: R7(c) (`M.N.x` is a qualified name, Δ2), R12
(`if` with semicolons, Δ5), R15 and ruling 6 (n+k, Δ4), R21(c) and ruling 55 (signatures cut dependency groups, Δ8),
R23(b) and R34(c) (empty data, hierarchical names, Δ6 and Δ2), R62 (`foreign` reserved, Δ1). Their pins flip under
`--language=haskell2010` only.

| D | Item | 98's text | rhc's 98 mode | 2010's text | Outcome | Recommendation |
|---|---|---|---|---|---|---|
| D13a | R48, `genericLength` | Contradicts itself: 4.5.5 `Num`, chapter 17 `Integral` | `Integral` (chapter 17) | `Num` | ALIGN | **Align: changes 98 mode** |
| D13b | R45(b), `0**y` | "undefined" | IEEE `pow` | "1 if y is 1, and 0 otherwise" (a misprint) | ALIGN | Decline: 98 mode unchanged |
| D13c | R38(a), R153(b): `isUpper`, `isAlpha` of a caseless letter | Plain: "not lower case is treated as upper case" | Upper case, as the text (owner, 98's D38) | Upper or title case only | OVERRIDE | No: 98 mode unchanged |
| D13d | R153(a), `isSpace` beyond Latin-1 | Plain: "only white characters in the Latin-1 range" | The seven Latin-1 white characters | "any Unicode space character" | OVERRIDE | No: 98 mode unchanged |

#### D13a. R48: `genericLength :: Num a => [b] -> a` in 98 mode (ALIGN, recommended)

**Taking D13a changes 98 mode: List's `genericLength` gets a different type, and programs 98 mode refuses today are
accepted.**

1. **98 contradicts itself.** 4.5.5's motivation for Rule 1 says "genericLength is a standard function (in library
   List) whose type is given by genericLength :: Num a => [b] -> a" (T98:6325-6326), and its example needs that type:
   `len1 = genericLength "Hello"; len2 = (2*len1) :: Rational`, where "the type variable a is resolved to Rational when
   performing type inference on len2" (T98:6391-6397). Rational is not Integral. Chapter 17 gives
   `genericLength :: Integral a => [b] -> a` in its prose (T98:11819), in its list of signatures (T98:11645) and in
   17.9's code (T98:12016). E9's R48 said that 17.7 gives `Num`; it does not, so the contradiction is between chapters 4
   and 17.
2. **rhc picked chapter 17.** `share/rhc/haskell98/List.hs:185` has `genericLength :: (Integral a) => [b] -> a`, the
   Report's code. The overlay entry `ov.list.genericlength` (`share/rhc/haskell98/overlay.tsv:66`) is a `nochange`:
   "the code stands, and both examples are tests". Row `lib.r.list.generic.length` (`tests/hs/conformance.tsv:3112`)
   says "typed Integral a => [b] -> a here though 4.5.5 types it Num a". 4.5.5's example is tested with a local
   `genericLength` of 4.5.5's type (`tests/hs/accept/mr.rule2.laterdecl.hs:7-8`; also `accept/mr.rule1.def.fun.hs`,
   `accept/mr.rule2.m1.type/`, `errors/mr.rule2.m1m2/`, `errors/mod.flatten.mr/`, `hslint/rule2.hs`). The 98 roadmap
   left the choice open in so many words: "Tests must pin one side of each" (haskell98.md:1574-1575).
3. **2010 picks 4.5.5's side.** Data.List: `genericLength :: Num i => [b] -> i` (T10:13317), "instead of returning an
   Int, it returns any type which is an instance of Num" (T10:13319-13320); and of `length`, "the result type of which
   may be any kind of number" (T10:12673-12674). 4.5.5 is unchanged (T10:4864). It is one of four library types that
   2010 changed (*What the 2010 Report says*, Δ12). GHC agrees: `base`'s `genericLength :: (Num i) => [a] -> i`
   (`libraries/ghc-internal/src/GHC/Internal/Data/OldList.hs:1018`) [read], which the GHC oracle's shim for 98
   re-exports as List's (`tests/hs/oracles/ghc-shim/List.hs:30`), so rhc's oracles already answer `Num`.

**What changes if it is taken:**
- **Code:** one signature, `share/rhc/haskell98/List.hs:185`, to `(Num a) => [b] -> a`. The definition,
  `1 + genericLength xs`, needs only `Num`.
- **Overlay:** `ov.list.genericlength` becomes an applied entry (kind `reading`, ground D13a), so that
  `hs/library/overlay`'s token comparison accepts the line that now differs from `pristine/List.hs:180`.
- **Rows:** `lib.r.list.generic.length` changes its statement; `lib.list.genericlength`
  (`tests/hs/conformance.tsv:3155`, "genericLength has its Report type") then means 4.5.5's type.
- **Tests: no verdict flips** [inferred from the tests' text, not run]. `lang/lib.list.genericlength_literal`,
  `lib.list.genericlength_probe1`, `lib.r.list.generic.length_text`, `mr.ex.len.shared` and `pre.r.generic_length` use
  it at `Integer` and `Int`, which `Num` admits, and defaulting still picks `Integer`;
  `accept/lib.list.export.elemindex_imported` only names it (`v32 _ = genericLength`). `errors/mr.ex.len.twotypes`
  (`let len = genericLength "ab" in (len :: Int, len :: Double)`, with List's function) stays refused, now by Rule 1
  alone, where today `Double` also fails `Integral`; its expected text is `` `len` ``, which the message should still
  hold, but it must be rerun. The local copies in the tests above could import List's function instead, as the
  Report's example means.
- **Programs newly accepted:** `genericLength` at a `Fractional` type, which is 4.5.5's own example.
- **Corpus:** four uses, none affected [read]: nofib's and nhc98's `primetest` (`log2 = genericLength . chop 2` at
  `Integer`), `knights`'s documentation, which defines a copy of 4.5.5's type in a code block
  (`tests/hs/corpus/vendored/nofib/spectral/knights/root.lit:110-113`), and `linear`'s `Matlib.lhs:399` at `Int`.
- **Store:** List's interface changes, so the snapshot and every unit that imports List are rebuilt once [inferred].

**Recommendation: align.** It is the brief's case exactly: a choice between two texts of 98, which 2010 settles. It
costs one line and moves no verdict. The strongest argument against: the Report's code is the text in rhc's 98 library
(98's D36, D37), and this would be the first overlay entry grounded in 2010 rather than in 98's own text or errata.

#### D13b. R45(b): `0**y` (passes the test; recommended against)

**Taking D13b would change 98 mode: `0 ** y` would stop being IEEE's `pow` at Float and Double.**

1. **98 says** "0**y is undefined." (T98:15328), which E9's R45 reads as either bottom or unspecified.
2. **rhc chose IEEE's `pow`,** where Rune's real is: 1 at 0, 0 for a positive y, an infinity for a negative y
   (`tests/hs/readings.md:434-441`). `tests/hs/lang/std.pow.undefined.hs:9-10` prints
   `(0 ** 2, 0 ** 0, 0 ** (-1))` at Double and the like at Float, and expects `(0.0,1.0,Infinity)` twice; row
   `std.pow.undefined` (`tests/hs/conformance.tsv:1729`).
3. **2010 says** "0**y is 1 if y is 1, and 0 otherwise." (T10:6389-6390), a misprint for "1 if y is 0", reported on
   the haskell-prime list in April 2011 and never corrected (*What the 2010 Report says*, N10).

**What changes if it is taken** [inferred from the test's text]:
- **To the sentence as printed:** `0 ** 0` becomes 0 and a negative y gives 0, so both expected lines become
  `(0.0,0.0,0.0)`; `0 ** 1` would be 1, which no test has.
- **To the sentence as meant:** only a negative y changes, so both lines become `(0.0,1.0,0.0)`.
- Either way Float's and Double's `**` need a test before `pow`.

**Recommendation: decline.** As printed the sentence is wrong arithmetic; as meant it contradicts IEEE at a negative
y, and neither reading mentions a NaN. rhc's IEEE choice agrees with the corrected sentence wherever y >= 0. The
misprint goes in *Found while writing*; what 2010 mode does at a negative y is N10's reading (D38).

#### D13c. R38(a), with R153(b): `isUpper` and `isAlpha` of a letter with no case (OVERRIDE; recommended against)

**Taking D13c would change 98 mode against 98's plain text and against the owner's decision of 2026-11-09: a CJK,
Hebrew or modifier letter would stop being upper case, and `isAlpha` would stop being `isUpper || isLower`.**

1. **98's text is plain.** Chapter 19: "For the purposes of Haskell, any alphabetic character which is not lower case
   is treated as upper case (Unicode actually has three cases: upper, lower, and title)." (T98:12229-12235); its table
   gives `isUpper` to every "Other Alphabetic" character (T98:12238-12245); 19.1's code is
   `isAlpha c = isUpper c || isLower c` (T98:12309). The one ground for calling it contradictory is 2.2's
   `uniLarge -> any uppercase or titlecase Unicode letter` (T98:2427), which leaves a caseless letter out of every
   lexical class. 98's D38 saw that ground ("R38 may belong in the first group", haskell98.md:6727), listed R38 among
   the points that follow the text (haskell98.md:6725), and **the owner decided that R38 follows the text**
   (haskell98.md:6740).
2. **rhc follows it.** `primUnicodeIsUpper` is true of Lu, Lt, Lm and Lo
   (`lib/language/haskell/coreruntime.sml:622-625`); `isAlpha c = isUpper c || isLower c` stands as printed
   (`share/rhc/haskell98/Char.hs:42`); overlay entries `ov.char.prims` (applied, `overlay.tsv:44`) and `ov.char.isalpha`
   (`nochange`, `overlay.tsv:67`); rows `lib.r.char.table.other.upper` and `lib.r.char.isalpha`
   (`tests/hs/conformance.tsv:3308`, `:3334`); reading R153 (`tests/hs/readings.md:492-506`), which records that no
   oracle follows the rule.
3. **2010 differs.** `isUpper` "Selects upper-case or title-case alphabetic Unicode characters (letters)."
   (T10:11844); `isAlpha` selects "lower-case, upper-case and title-case letters, plus letters of caseless scripts and
   modifiers letters" and is "equivalent to Data.Char.isLetter" (T10:11848). GHC does the same [probe
   `results/E1/probes/n07b_isupper_caseless`] (base) and calls its `isAlpha` a divergence from "the Haskell 98
   definition" (`docs/users_guide/bugs.rst:466-473`) [read].

So the test fails at (1). It passes only if the owner now reads chapter 19 against 2.2 as contradictory, reversing
98's D38 on R38.

**What changes if it is taken** [inferred from the tests' text, not run]:
- **Code:** `primUnicodeIsUpper` becomes Lu and Lt; `isAlpha` stops being `isUpper || isLower` (a category test), so
  `Char.hs:42` departs from `pristine/Char.hs:37` and `ov.char.isalpha` becomes an applied entry; `ov.char.prims`
  changes its text.
- **Tests that flip:** `lang/lib.r.char.table.other.upper_unicode`: expected line 1 (`table "\x1C5\x5D0\x4E2D"`, the
  source's line 22), whose `isUpper` row goes from `[True,True,True]` to `[True,False,False]`, and line 13 (the law
  over every character, the source's line 34), from `True` to `False`. `lang/lib.r.char.table.other.upper_categories`:
  the rows of U+4E2D, U+05D0 and U+02B0 (expected lines 7-9) go from `1111000` to `1110000`. `core/runtime-unicode`
  (the change being made in `primUnicodeIsUpper`): expected lines 7, 18 and 33, of U+00AA (Lo), U+02B0 and U+4E2D, go
  from `U.AP` to `..AP`.
- **Rows:** `lib.r.char.table.other.upper` and `lib.r.char.isalpha` change their statements, and 98's D38 table
  changes its R38 line.
- **Unchanged:** ASCII, `lang/lib.r.char.table.lower.print_latin1`, and the lexer, whose classes are 2.2's. Latin-1's
  U+00AA and U+00BA (Lo, R153) do change. `isUpper`, `isAlpha` or `isSpace` appear on 40 lines of 15 files of the
  vendored corpus, by word (`results/verify/V2/numbers-a/corpus-grep.out`; E2's 47 counted `isAlphaNum` too), on
  input that is ASCII as far as read [inferred].

**Recommendation: no.** 98 mode keeps chapter 19, as the owner decided; 2010 mode follows Data.Char (D26). If the owner
does take it, the roadmap records it as an override of 98's chapter 19 and of 98's D38, not as an alignment.

#### D13d. R153(a): `isSpace` beyond Latin-1 (OVERRIDE; recommended against)

**Taking D13d would change 98 mode against 98's plain text: `isSpace`, `words` and `lex` would treat Unicode spaces
above Latin-1 as white space.**

1. **98's text is plain:** "The isSpace function recognizes only white characters in the Latin-1 range."
   (T98:12253), and 19.1's code is ``isSpace c = c `elem` " \t\n\r\f\v\xA0"`` (T98:12302).
2. **rhc follows it:** `share/rhc/haskell98/Char.hs:35`, as printed; row `lib.r.char.isspace`
   (`tests/hs/conformance.tsv:3322`).
3. **2010:** "Returns True for any Unicode space character, and the control characters \t, \n, \r, \f, \v."
   (T10:11833).

The test fails at (1).

**What changes if it is taken,** with D26's reading of 2010 (category Zs and the five controls) [inferred from the
tests' text]:
- **Code:** `Char.hs:35` departs from `pristine/Char.hs:30`, which needs an overlay entry of its own.
- **Tests that flip:** `lang/lib.r.char.table.other.upper_unicode`'s expected line 8 (the source's line 29) goes from
  `([False,False,False],True)` to `([True,True,False],True)`: U+2003 and U+3000 are spaces, U+2028 is not;
  `lang/lib.r.char.table.other.upper_categories`'s row of U+3000 (expected line 14) goes from `1000000` to `1000001`.
- **Unchanged under Zs:** `lang/lib.r.char.table.lower.print_latin1`, since the seven Latin-1 white characters are Zs
  or among the five controls and U+0085 is neither. Under the White_Space reading U+0085 becomes a space too, and the
  first element of that test's last list flips.
- **Behaviour:** `words` (PreludeList) and `lex` (PreludeText) both call `isSpace`, so splitting words and `read`'s
  skipping of white space change on input above Latin-1.

**Recommendation: no.** 2010 mode reads "Unicode space character" as Zs (D26), as GHC's `base` does (N7).

### For the owner, though not alignments

Three points are not alignments as E2 files them, and each would change 98 mode if taken.

**R41, R87, ruling 14: derived `Show` of a record.** **A re-reading, if the owner takes it, changes 98 mode's output for
every record shown at precedence 11.**
- 98's 10.4 and 2010's 11.4 are the same words: "if d is 11 it is always surrounded in parentheses, unless it is an
  atomic expression (recall that function application has precedence 10)" (T98:10223-10225, T10:10789-10790). So
  this is no alignment: 2010 settles nothing 98 left open.
- rhc took GHC's row, a record parenthesised at 11, "which Haskell 2010 took [memory]" (haskell98.md:1303, 6569;
  the 98 campaign's ruling 14, "GHC's row as Haskell 2010 chose; implementation-defined ... the owner may overrule",
  `impl/rulings.md:49-50`; `tests/hs/readings.md:257-262`). The premise is false twice. The 2010 text did not change,
  and GHC's own documentation calls its parentheses a divergence: "The Haskell 2010 definition of Show stipulates that
  the rendered string should only include parentheses which are necessary to unambiguously parse the result ...
  whereas Haskell 2010 calls for ... show (Just (Hello {aField=42})) == "Just Hello {aField=42}""
  (`docs/users_guide/bugs.rst:438-451`) [read].
- A record construction is an `aexp` in 3's grammar (T10:2140, 2143). If that makes it "an atomic expression", 10.4
  itself says not to parenthesise it at 11, which is Hugs's row, not GHC's [inferred].
- If re-read: `lang/der.show.record.form_ghc`'s second expected line goes from `(S {h = 1})` to `S {h = 1}`, with
  derived `Read` at precedence 11 to match, and row `der.show.record.prec` (`tests/hs/conformance.tsv:2737`) changes
  [inferred]. 98 and 2010 modes would change together, on the 98 text's own ground under 98's D38.

**R21(c), ruling 55: signatures cut dependency groups.** **A CHANGE, so not eligible; aligning it anyway would change
98 mode's grouping and accept six programs 98 mode refuses.**
- 98 groups by binding alone (T98:17673-17677), while 4.4.1 says "each use of f is treated as having the declared
  type" (T98:17443-17445). 2010's 4.5.1 lets a signature cut a dependency (T10:4710-4713), and 12.3 names
  RelaxedPolyRec among the features "integrated into this report" (T10:10997-11002): a change of language.
- It is arguable only if the owner reads 98's 4.4.1 against 4.5.1 as contradictory. Then aligning would accept the
  six corpus programs ruling 55 refuses (tc196, tcfail071, tcfail144 and jhc's three copies; `impl/rulings.md:184-190`)
  and flip `dec.dep.sig.group` and `dec.gen.sig.identical`'s second test (`tests/hs/conformance.tsv:1141`, `:1148`).
- GHC accepts them in both its modes, as it always groups the relaxed way (*What the 2010 Report says*, N4), so GHC
  cannot judge 98 here. **Recommendation:** keep 98's grouping in 98 mode; 2010 mode takes the change (D16).

**R54, ruling 11, 98's D22: `Int` overflow.** **OPEN until D21; D21's option C is this alignment, and it changes 98
mode.**
- 6.4 leaves overflow undefined in both texts, "an implementation may choose error (_|_, semantically), a truncated
  value, or a special value" (T10:6239-6241), and rhc chose an error (98's D22; the 98 campaign's ruling 11,
  `impl/rulings.md:37`). That is a free choice in 98, so (1) and (2) hold.
- 2010's Data.Int says "All arithmetic is performed modulo 2^n" of a list naming Int (T10:12381-12382). On E1's reading
  that contradicts 6.4 and settles nothing (N6), so E2 marks R54 OPEN. On the lead's reading chapter 18 narrows 6.4 to
  a truncated value, and then (3) holds and R54 is an ALIGN.
- D21 decides which: A keeps checked `Int` everywhere, B wraps in 2010 mode only (recommended; 98 mode unchanged), C
  wraps in both. **C would change 98 mode:** every overflow test flips (`def.pick.first_overflow`, R81's and R93's
  rows: `tests/hs/readings.md:222-226`, `:288-291`), and ruling 11's compatibility layer for wrapping bit tricks goes.

Smaller items where 2010 weakens or removes the ground of a 98 choice, with nothing to align [read]:
- **R37, R95, rulings 57-58 (how a program ends).** Their ground, 98's chapter 23, is gone from 2010's System.Exit
  (N21). 98 mode keeps them; 2010 mode needs its own reading (D38).
- **R39, R43, R82, R34(b) (98 errata 2010 did not absorb).** 2010 prints the pre-erratum text, which was itself at odds
  with another part of the Report, so it settles nothing. 98 mode keeps its errata; 2010 mode's question is N18.
- **R46 (`getLine`).** 2010 drops System.IO's "shorthand for hGetLine stdin" sentence and keeps 7.1 and the Prelude's
  loop of `getChar`, so one of the two sentences rhc's `ov.preludeio.getline` rests on is gone. 98 mode keeps it.
- **Numeric's `readDec`, `readOct`, `readHex`** are `Num a =>` in 2010 and `Integral a =>` in 98 (T10:16049-16055).
  No 98 reading names them and 98's text is plain, so they are no candidates.

### 98's deviations under 2010

rhc's 98 mode has eight deviations, each with a ground and a pin (`tests/hs/deviations.tsv:2-9`). Under 2010 two become
the text; six stay deviations, since the text they depart from is unchanged:

| DV | Deviation | Reading | Ground in 98 | Pin | Under 2010 |
|---|---|---|---|---|---|
| DV1 | `lay.parseerror.fixity` | R1 | Conceded by the Report | `errors/lay.parseerror.fixity_refused` | **The text:** 9.3's conceding paragraph is deleted (T98:317-324 has no 2010 counterpart), Note 5 kept (T10:9758) |
| DV2 | `lay.note3.implicit` | R2 | Contradictory | `accept/lay.note3.implicit_closes` | Stays: Note 3 unchanged (T10:9754-9756) |
| DV3 | `lex.comment.line.eof` | R4 | Wrong | `accept/lex.comment.line.eof_noeol` | Stays: a comment still ends in a newline (T10:1626) |
| DV4 | `lex.any.linecomment` | R4 | Wrong | `accept/lex.any.linecomment_uniwhite` | Stays: `any` is still graphic, space or tab (T10:1632) |
| DV5 | `lay.col.vt` | R4 | Ambiguous | `accept/lex.any.linecomment_uniwhite` | Stays: 10.3 unchanged |
| DV6 | `lay.first.empty` | R4 | Ambiguous | `errors/lay.first.empty_nomain` | Stays: unchanged |
| DV7 | `lex.int.unidigit` | R6 | Contradictory | `errors/lex.int.unidigit` | Stays: a `digit` is still an ascDigit or a uniDigit (T10:1676), and Data.Char's digits outside ASCII "not by isDigit" (T10:11852) |
| DV8 | `exp.parse.letnonassoc` | R9 | Conceded by the Report | `errors/exp.parse.letnonassoc_refused` | **The text:** chapter 3's note is deleted (T98:15532-15543 has no 2010 counterpart) |

So DV1 and DV8 are conforming rows in the 2010 table, with no deviation, and stay deviations in 98's: the refusal is
the same program behaviour in both modes, under two texts. GHC refuses both programs in both its modes
[probe `results/E1/probes/n02e_let_nonassoc`, `n02f_do_nonassoc`].

### Where 2010 confirms what rhc chose

97 items are SAME. Those worth citing, because 2010 settles a point 98 left open in rhc's direction, or because the
98 drafts said otherwise from memory [read]:
- **R1, R9:** DV1 and DV8 above.
- **R7(a):** 6.3.4's example is respaced, "[LT ..] is the list [LT,EQ,GT]" (T10:6070), so rhc's refusal of `[LT..]` by
  2.4's rule is 2010's reading too.
- **R16:** rule (m) still matches the pattern's fields in the pattern's order (N17).
- **R36:** System.IO.Error's `catch` "receives any IOError raised" (`results/E1/html10/ch42.txt:71`).
- **R44:** "within epsilon of x" (T10:13563-13564); the "open interval" is gone.
- **R152:** Data.Array lists `instance Ix i => Functor (Array i)` (`results/E1/html10/ch14.txt:14`).
- **R154:** `lexLitChar` is prose only in 2010, so the prose rhc took over 98's code is all there is.
- **R52:** 2010 still prints `readLine` in 10.4's example (T10:9804), and rhc still does not copy it.
- **R38(b), R153(c):** 2010 names no Unicode version (T10:16864), so rhc's 18.0.0 stays implementation-defined.
- **R21(b):** 4.5.2 keeps identical contexts for the signed variables of a group (T10:4751-4752). E9's "H2010 dropped
  it [memory]" is wrong.
- **R45(g):** "gcd 0 0 raises a runtime error." (T10:6336) in 2010 too. E9's "unlike H2010 [memory]" is wrong.

### Errors in the preliminary list

The plan's list of candidates came from an exploration report (`agents/X-explore-choices.md`), which E2 checked line
by line. Its errors, each checked again against that report and the texts while writing [read]:
1. **R38 offered as the first candidate** ("2010's Data.Char takes GHC's isUpper/isAlpha", X-explore-choices.md:327).
   rhc followed 98's plain text there, by the owner's decision: an OVERRIDE (D13c).
2. **R48 missed,** the one clean ALIGN: its 2010 column is a bare dash (:73). E9's own R48 is wrong too: 17.7 says
   `Integral` (T98:11819).
3. **R45(b) missed:** R45's 2010 note checks only `gcd 0 0` (:70), and 6.4.3's `0**y` changed (D13b).
4. **R37 missed** (:62): 2010 drops chapter 23's sentences on how a program ends.
5. **R46 incomplete** (:71): "7.1's wording the same" is right, but the System.IO sentence on `getLine` is gone.
6. **R41 incomplete** (:66): right that 2010's text is unchanged, but GHC's `bugs.rst` makes the 98 ruling's premise
   fail twice.
7. **R16, R36, R44, R152, R154 not concluded** (:41, :61, :69, :135, :137): each is SAME.
8. **R62 "not checked"** (:94): `foreign` is reserved in 2010 (T10:1741), a CHANGE.
9. **R23's citation** (:48): T10:10670 is chapter 11's condition 6 on deriving; the grammar is T10:3860 and the prose
   T10:3911.
10. **R2's line** (:27): Note 3 is at T10:9754, not 9755.
11. **"2010 does not resolve: R2, R5, R41, R42, R52"** (:333): 118 items are OPEN, not five, and R52 is SAME.

Correct as reported: R1 and R9 (SAME), R7's example, R12, R15, R23(b), R34(c) (CHANGE), and the three [memory] claims
of the 98 drafts that are wrong against 2010 (R21(b), R45(g), R41).

### What the owner is asked

- **D13a:** align R48 in 98 mode. **This changes 98 mode** (one signature, one overlay entry, no verdict flips).
- **D13b:** decline R45(b); record 6.4.3's misprint.
- **D13c, D13d:** no; 98 mode keeps chapter 19's plain text (for R38, as the owner decided in 98's D38).
- **R41:** whether to re-read 98's 10.4 for records. **Taking it changes 98 mode** on 98's own text.
- **R21(c):** keep 98's grouping (recommended); aligning it **would change 98 mode**.
- **R54:** settled by D21; its option C **changes 98 mode**.

Whatever the owner takes becomes track H: each item a change to `share/rhc/haskell98` or the checker, its overlay
entry or reading, and its tests, with 98 mode's other output held byte for byte.

## The extensions

The brief asks for three things here. Survey GHC's language extensions, from GHC's documentation and implementation,
the other compilers and the literature. Implement as many as possible without OutsideIn(X), without the highly
GHC-specific and without extensive runtime support. Classify each by area, by implementation complexity, by whether it
can and should be built on the Haskell 98 type system before OutsideIn(X), and recommend this roadmap or a later one.
This section answers each point. *Appendix: the extension table* has one row for every name; the census's reason and
evidence for each row are in `results/E6/census.tsv`.

- **Every name GHC accepts was classified:** the 148 LANGUAGE names of GHC 9.14.1, on one schema, by three agents
  (E6), with 41 probe modules run on GHC 9.4.7.
- **72 are recommended for this roadmap.** Six of them are Haskell 2010 itself, built by tracks F and V; the other 66
  are track X, milestones M19-M27. 50 are deferred to four kinds of later roadmap, 14 should never be built, and 12 are
  editions or other spellings of a name.
- **The line is a ladder, not OutsideIn alone.** Nine tiers, T0-T8, with T4 split into T4a and T4b, say what a name
  needs of rhc's checker and Core that they lack today. Every recommended name sits at T5 or below, or at T8. E12 built
  T1, T2, T4a and the core of T5 on D34's A+, in the checker and in HsLint, with no implication constraints and 98 mode
  byte-identical. System F Core was enough; Mid is the limit for T5.
- **Track X does not make Hackage compile.** On Stackage LTS 24.67 the recommended set admits 28.3% of packages whole
  (E7). Every name below T6 would admit 42.6%, through T6 59.2%, through T7 85.2%. The gap is type families, GADTs and
  the kinds, beside modern `base`.
- **67 names change the meaning or acceptance of some valid 2010 program** when turned on, 28 of them recommended. Each
  comes only when written, and each has its test (D36).

rhc's paths are against `75ed95861` and under `lib/language/haskell/` unless written in full. GHC's paths are under
`/home/ruud/haskell`, the tree of `ghc-9.14.1-release`, as in *What the implementations do*.

### What was surveyed

- **The names** (E5, `results/E5/names.tsv`) [read]. GHC 9.14.1 has 135 `Extension` constructors
  (`ghc/libraries/ghc-internal/src/GHC/Internal/LanguageExtensions.hs:30-170`), 3 alternate names
  (`ghc/compiler/GHC/Driver/Flags.hs:265-271`), 3 deprecated names (`Flags.hs:273-278`), 4 editions and 3 Safe modes
  (`ghc/compiler/GHC/Driver/Session.hs:2710-2723`): 148 in all. The editions' members
  (`ghc/compiler/GHC/Driver/DynFlags.hs:1305-1413`), the 38 implications (`Flags.hs:286-359`) and the deprecations
  (`Flags.hs:112-124`) were taken as data, not judged.
- **The specifications.** For each name, its page of GHC's users guide (`ghc/docs/users_guide/exts/`), and GHC's code
  where the page is thin. Then the other implementations (*What the implementations do*) and the papers (E11, *What the
  literature says*).
- **The probes.** GHC 9.4.7 is the only GHC binary at hand. It knows 137 of the 148 names; the other 11 are "source
  only": ExplicitLevelImports, ExtendedLiterals, GHC2024, ImplicitStagePersistence, ListTuplePuns, MultilineStrings,
  NamedDefaults, OrPatterns, RequiredTypeArguments, TypeAbstractions and TypeData. Where a row says a name changes a
  valid 2010 program, the change was measured when it could be. X1 ran 41 probe modules under `-XHaskell2010` with the
  extension off and on, 82 runs (`results/E6/X1-data/probes.tsv`); X3 used E5's probes P14 and P18
  (`results/E5/probes/results.tsv`). No probe enabled TemplateHaskell or QuasiQuotes.
- **Use.** E7 scanned Stackage LTS 24.67 (3,392 packages, 49,394 module files) and Hackage's index (19,711 packages).
- **Calibration.** E12 built four tiers in the checker and HsLint, E3 the 2010 switches, E10 the FFI. Every other size
  is an estimate.

How the three agents divided the names, and how they were merged, is in *The experiments*, E6.

### How a name is classified

E6's schema (`results/E6/schema.md`) gives each name 22 columns. Four are computed from GHC's source: since, in_947,
editions and implies. The rest are judged, each row with a reason and its evidence. The brief's questions map onto
them:

| The brief asks | Column | Values |
|---|---|---|
| the area | area | 22 areas, from lexing and layout through types, classes and deriving to ffi, meta and driver; a second may follow |
| implementation complexity | size, with core, runtime and hslint | size S under 300 lines, M to 1,000, L to 3,000, XL more, counting the front end, HsLint and tests; Core: nothing new, System F as it is, a cast under constructors, System FC, new primitives; runtime: none, small, extensive; HsLint: none, mirror (the same rule again), spec (a specification of its own) |
| whether it can be built on the 98 type system | tier, outsidein | the tiers below; what an OutsideIn checker would rework: none, small, large |
| the brief's three exclusions | tier, ghc_specific, runtime | OutsideIn is T4b and T6; GHC-specific no, partly, yes; extensive runtime support |
| whether it should be built, and when | rec | now; later-outsidein, later-other, later-meta, later-runtime; never; n/a for editions and other spellings |
| what it does to valid programs | changes_valid | yes if turning it on changes the meaning or acceptance of some valid 2010 program; for a name on in 2010, its No form |

The other columns are gates (what the name permits: declarations, uses, a whole module), others (seven other systems)
and paper.

**The tiers.** Each rung is something a name needs of rhc that rhc lacks today. A row takes the lowest rung that the
name's whole GHC semantics needs, not the rung of its commonest use; where a cheap subset exists, the reason says so
(X2's convention). T4 is split as E11 found it must be (*What the literature says*, correction 1). *Where we are*
reads the checker and Core in full; the citations below are the facts that set each rung.

| Tier | What it needs | What rhc lacks today | Examples |
|---|---|---|---|
| `-` | nothing of the checker: settled before lexing, in the lexer or layout, in the parser onto today's tree, in the renamer, or in the desugarer | nothing | CPP, BinaryLiterals, RecordWildCards, StrictData |
| T0 | a typing rule taken from a translation into 2010, or a 98 restriction lifted alike in the checker and HsLint | nothing of the type system; a new expression or pattern form touches 11 files (X1) | LambdaCase, BangPatterns, ViewPatterns, KindSignatures, TypeSynonymInstances, GADTSyntax on ordinary types |
| T1 | predicates over several types; instances found by matching; a wanted that no instance matches yet is deferred, not refused | a predicate has one type (`types_sig.sml:59`); instances are keyed by class and type constructor (`classes_sig.sml:18, 39`); `solve` refuses at once a wanted headed by a constructor with no instance (`infer.sml:299-339`) | MultiParamTypeClasses, FlexibleInstances, FlexibleContexts, overlap |
| T2 | improvement: the solver unifies | `solve` only looks up, in the givens and the index (`infer.sml:317-339`) | FunctionalDependencies |
| T3 | prenex schemes that keep the user's variable order; type variables in scope over bodies | `schemeOf` orders a scheme's variables by the type, then the context (`infer.sml:578-601`); HsLint's second inference has no rigid variables (`hslint_infer.sml:698-722`) | ScopedTypeVariables, TypeApplications, InstanceSigs |
| T4a | class givens on existential variables only, with type binders in Core | Core's `AltCon` binds no type variable and a `Data` constructor has only its fields' types (`core_sig.sml:77, 87`); the checker scopes givens and rigid levels for signatures only (`infer.sml:1113-1125, 1495-1519`) | ExistentialQuantification |
| T4b | contexts on universal variables, a GADT-style given: implication constraints, so it goes with T6 | the same, and no implications | `data T a = C a => K a`; OutsideIn's MkR |
| T5 | nested forall, bidirectional checking, simplified subsumption | `HsTypes.ty` has no forall (`types_sig.sml:46-51`); MidLint takes a polymorphic type only as a field or a tuple's component (`lib/compiler/core/midlint.sml:213, 222`) | RankNTypes |
| T6 | local equalities: OutsideIn(X), with System FC | Core's `Cast` goes only into or out of a newtype, at its head (`core_sig.sml:73`) | GADTs, TypeFamilies |
| T7 | kinds: variables, promotion, constraints as types | kinds are `KStar`, `KFun` and `KVar`, and a variable left unsolved becomes `*` (`lib/language/haskell/types_sig.sml:18, 28-29`); Core's kinds are `Star`, `Unlifted` and `Arrow` (`core_sig.sml:27-30`) | PolyKinds, DataKinds, ConstraintKinds |
| T8 | the generalisation policy, per module | the checker's settings are refs set once a run (`infer.sml:2007-2010`); a `let` is grouped and generalised by the top level's rule (`infer.sml:861-863, 1133-1135, 1235-1243, 1336`) | MonoLocalBinds, NoMonomorphismRestriction |

Two conventions differ between the agents, and the reader of a row should know them. X1 wrote `-` where the checker
and HsLint need no rule at all, and T0 where they need one taken from a translation; X2 wrote T0 for a lifted
restriction too (ConstrainedClassMethods, TypeSynonymInstances, KindSignatures). And the census keeps one T4: its
ExistentialQuantification row is T4a, and its PatternSynonyms row is not split.

### The census in numbers

From `results/E6/census.tsv`, 148 rows [measured]:

- **Kinds:** 133 extensions, 4 editions, 3 Safe modes, 3 alternate names, 5 deprecated names (two deprecated
  constructors, NullaryTypeClasses and TypeInType, and three deprecated spellings).
- **Areas** (the first named): the front end 60 (literals 9, records 9, parsing 7, expressions 6, patterns 6, layout 4,
  `do` 4, modules 4, lexing 4, comprehensions 4, evaluation 2, desugaring 1); the type system 66 (types 25, classes 16,
  deriving 14, kinds 11); the FFI and runtime 9; meta 5; the driver 5 (CPP and the editions); safety 3.
- **Complexity:** size S 57, M 47, L 25, XL 7, none for the 12 editions and spellings. Core: nothing new 111, System
  F as it is 17, a cast 5, System FC 5, new primitives 10. Runtime: none 131, small 9, extensive 8. HsLint: none 56,
  mirror 33, spec 59. GHC-specific: no 69, partly 51, yes 28.
- **Changes valid 2010 programs:** 67.
- **The brief's three exclusions, as the census applies them.** OutsideIn: all 5 names at T6 go to the OutsideIn
  roadmap, with 4 more that need it (later-outsidein, 9 in all). Highly GHC-specific: 28 rows say yes; every one of the
  14 never rows is among them, and of the rest 5 are meta, 4 later (CUSKs, LinearTypes, RoleAnnotations, Safe), 3
  editions and spellings (GHC2021, GHC2024, TypeInType), and 2 recommended, Trustworthy and Unsafe, as markers that
  restrict nothing while rhc has no Safe mode. Extensive runtime support: 8 rows; ForeignFunctionInterface, which 2010
  requires, is the one recommended, and the others are meta (3), runtime (2) and never (2).

**Tier against recommendation:**

| Tier | now | later | never | n/a | all |
|---|---:|---:|---:|---:|---:|
| `-` | 25 | 10 | 7 | 4 | 46 |
| T0 | 28 | 8 | 1 | 2 | 39 |
| T1 | 9 | 3 | | 2 | 14 |
| T2 | 1 | 1 | | | 2 |
| T3 | 4 | 3 | | 1 | 8 |
| T4 | 1 | 1 | | | 2 |
| T5 | 1 | 6 | | 2 | 9 |
| T6 | | 5 | | | 5 |
| T7 | | 11 | 6 | 1 | 18 |
| T8 | 3 | 2 | | | 5 |
| **all** | **72** | **50** | **14** | **12** | **148** |

So 125 names sit at tiers `-` to T5 or at T8, the part of the ladder below OutsideIn and the kinds, and 23 at T6 or
T7. "Below" says where a name starts, not that A+ carries all of it: PatternSynonyms' unsplit T4 row is later-outsidein,
and ImpredicativeTypes and DeepSubsumption go past the simplified subsumption E12 built.
The 50 later are 33 later-other, 9 later-outsidein, 6 later-meta and 2 later-runtime. Of the 72 recommended:
- sizes S 45, M 21, L 4 (MultiParamTypeClasses, FlexibleInstances, FunctionalDependencies, ExistentialQuantification),
  XL 2 (RankNTypes, ForeignFunctionInterface), before E12's calibration (below);
- Core: nothing new for 66, System F for 3 (DefaultSignatures, ExistentialQuantification, RankNTypes), a cast for 2
  (GeneralizedNewtypeDeriving, DerivingVia), new primitives for the FFI; none needs System FC;
- HsLint: none 32, mirror 25, spec 15;
- runtime: extensive for the FFI alone, which Haskell 2010 requires (*The foreign function interface*);
- GHC-specific: yes for 2, Trustworthy and Unsafe, accepted as markers; partly for 17;
- source only: 2, MultilineStrings and OrPatterns, which 9.4.7 cannot judge;
- 28 change valid 2010 programs.

**The cross-check.** Ten names were classified by all three agents, without conferring (`results/E6/overlap.tsv`).
They agree on the recommendation for all ten, on runtime for ten, on Core, changes_valid, GHC-specificity and rework
for nine, on the tier for eight (OverloadedStrings T1, T1, T2; RecordWildCards `-`, T0, T0), on size for six and on
the area for three. Where they differ the census keeps the owner's row. The one disagreement on changes_valid was a
mistake: X2 said LambdaCase changes no valid program, and X1's `lcases.hs` measured `\cases -> cases + 1` refused once
it is on. 138 rows have one classifier only. *The experiments*, E6, has the table.

### Where the line falls: E12

E12 (agent N) built one throwaway prototype per tier on D34's A+: today's unifier, a deferred store of class
constraints solved at generalisation, and improvement as unification repeated until nothing changes. Each was built in
the checker and in HsLint, behind a switch, on 75ed95861 (`results/E12/`; `patches/E12-T1.patch` to `E12-T5.patch`).
T3 was not built. *The experiments*, E12, has the method. What sets this section:

- **A+ carried all four** [measured]. No tier needed implication constraints: `solve` became a loop to a fixpoint, and
  T4a needed a scope for a pattern's local givens.
  - **T1:** MultiParamTypeClasses with FlexibleInstances and FlexibleContexts. A wanted is deferred where no instance
    matches yet, and non-HNF contexts are inferred, as GHC infers them. The Paterson conditions are checked,
    UndecidableInstances lifts them, and a depth bound of 200 stands behind them.
  - **T2:** FunctionalDependencies. Jones's coverage condition, the liberal one under UndecidableInstances, and
    improvement from a given refused with a message, as GHC refuses it. An mtl-style MonadState with ReaderT lifting
    gives GHC's output.
  - **T4a:** existentials with contexts on the existential variables. A context on a universal variable is refused as
    T6's: OutsideIn's MkR, which GHC 9.4.7 accepts with a non-principal type, and GHC's test T10856.
  - **T5:** nested forall checked against annotations with simplified subsumption, elaborated to System F type and
    dictionary lambdas with no coercion.
- **Size** (`results/E12/areas.tsv`; lines added / added lines of code; T2 is built on T1, T4a and T5 on neither):

| Tier | Checker | HsLint | Core | Desugarer | Parser, front end | Interfaces, switch | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| T1 | 466 / 394 | 479 / 428 | 0 | 92 / 84 | 28 / 25 | 36 / 33 | 1,101 / 964 |
| T2 | 318 / 285 | 155 / 126 | 0 | 1 / 1 | 21 / 20 | 17 / 14 | 512 / 446 |
| T4a | 176 / 150 | 134 / 119 | 148 / 133 | 85 / 65 | 43 / 38 | 0 | 586 / 505 |
| T5 | 193 / 161 | 203 / 184 | 0 | 23 / 19 | 22 / 21 | 9 / 9 | 450 / 394 |
| all | 1,136 / 974 | 962 / 848 | 148 / 133 | 200 / 168 | 113 / 103 | 58 / 52 | 2,617 / 2,278 |

  HsLint took 848 code lines against the checker's 974, 0.87 of the checker's: below D41's budget of no less than the
  checker's cost, which errs safe. The prototypes are lower bounds. A pseudo-tuple stands in for a predicate over
  several types, where an honest `pred = {cls, tys}` touches about 68 predicate sites in the checker and 61 `IsIn` sites
  in HsLint [N's grep, no result file; a grep at the pin finds `IsIn` on 63 lines of HsLint; the size inferred]. Fundeps
  sit in a side table, HsLint's codec does not write its extras, and there are no tests or docs. N's estimates of
  production differ by tier [inferred]: the T1 group 1,600-2,400 lines, 1.5 to 2.2 times its prototype, which is L for
  the group, one refactor and not one per row; FunctionalDependencies 800-1,200, 1.6 to 2.3 times (M, at its upper end);
  ExistentialQuantification 1,000-1,500, 1.7 to 2.6 times (L); RankNTypes 1,500-2,500, 3.3 to 5.6 times (L under
  simplified subsumption, XL only with DeepSubsumption or ImpredicativeTypes). *Appendix: the extension table* stars
  these sizes.
- **98 mode byte-identical with the switches off** [measured, `results/E12/identity/`]: `tests/hs/lang` 591 of 591
  bytecode files the baseline's, at T1's state and at the final build; `tests/hs/errors` 633 of 633 with the same status
  and stderr; the corpus run set of 98's D56, 193 of 193 jobs and 354 of 354 bytecode files, at T1's state only; GHC's
  133 selected files the baseline's status and first line.
- **Conservativity, switched on over 98's programs** [measured]. With T1 on, `tests/hs/lang` and the corpus are
  byte-identical (591, 354), and 38 of the 633 error programs differ: 26 now accepted, each a 98 restriction T1 lifts,
  and 12 refused with another message. With every tier on, `tests/hs/lang` is still identical and 40 error programs
  differ: T1's 38, `cls.inst.ctx.vars` (T2) and `ty.quant.noforall`, accepted because T5's switch made `forall` a
  keyword in every type (see D36 below). E8's 2010 accept list had 32 rows when E12 ran, so these runs used 98's
  programs; the corpus was not run on the final build.
- **GHC's own tests** (9.14.1's `typecheck/should_compile` and `should_fail`, filtered to the tier's extensions;
  `results/E12/ghc/summary.tsv`): T1 accepts 7 of 10 and refuses 19 of 19; T2 27 of 32 and 16 of 16; T4a 0 of 2 and 6
  of 6; T5 11 of 31 and 16 of 17. Unchanged rhc accepts none of the 75 should_compile files. T1's three failures need
  overlap. Of T5's twenty, ten need a forall in a result skolemised against a clause's further patterns; then
  contexts in nested types without a forall (3), polytypes through synonyms (2), patterns on polytypes (2), and one
  each for Traversable, T4a's syntax and an unsigned rank-2 binding (`ghc/categories.tsv`).
- **Core and Mid** [measured]. System F Core was enough for all four. T1, T2 and T5 changed no Core; T4a added an
  alternative with type binders and a convention for existentials on `Data` (133 code lines in 13 files). Mid is T5's
  limit: `rank2.hs` fails MidLint at -O0 and -O1 ("is polymorphic, ..., other than as a field") and passes at -O2 only
  because the simplifier removed the binder. So T5 needs CoreToMid to box a polytype in a one-field datatype, as
  dictionaries are boxed (200-400 lines [inferred]), or rank-N types in Mid, a Rune change (D37). T4a needed no Mid
  change.
- **Separate compilation** [measured, `results/E12/units/log.txt`]. With a store, T1's class extras and T4a's
  constructor are lost across a unit boundary: an uncaught `Subscript` at lint level 2, "HsDsCore: Conv.Box at 1
  types" at level 1. N puts the fix at 50-150 lines [inferred].
- **Option C** (constraint generation with a solver, 98's D31 option C) would cost 1,500-3,000 checker lines before
  the first tier and then save next to nothing over T1-T5: N's own per-tier figures for C sum to 961-1,061 lines
  against A+'s 990 (W13) [inferred, N]. It pays only at T6. D34 takes A+ and leaves C to the
  OutsideIn roadmap.

### What Hackage uses: E7

E7 counts the names a module's effective setting holds, from its pragmas and its cabal file, over Stackage LTS 24.67.
It counts names written, not constructs used: a `default-extensions` list names extensions a module may never need.

- **The order by package.** A greedy cover over the recommended names (`results/E7/cover-pkg-recnow.tsv`) adds at
  each step the name that admits the most, each package weighing one, so a family of generated packages cannot steer
  it. Its first twenty steps: OverloadedStrings, CPP, BangPatterns, NoImplicitPrelude, ScopedTypeVariables (with
  ExplicitForAll), FlexibleContexts, RankNTypes, LambdaCase, TypeApplications, RecordWildCards, FlexibleInstances,
  GeneralizedNewtypeDeriving, Trustworthy, MultiParamTypeClasses, TupleSections, NamedFieldPuns, ViewPatterns,
  UndecidableInstances, FunctionalDependencies, ExistentialQuantification. From 307 packages (9.05%) that need nothing
  beyond 2010, the first step reaches 356 whole packages (10.50%), the twentieth 864 (25.47%) and the fiftieth 961
  (28.33%). The front end, T1 and T3 lead, and every rung from T1 to T5 is among the twenty.
- **What the set leaves out** comes early in the unrestricted cover (`cover-pkg.tsv`): `OPTIONS:-F` 3rd (a custom
  preprocessor such as hspec-discover, in 458 packages: a driver question, not a language one), DeriveDataTypeable 4th,
  DeriveGeneric 11th, Safe 12th, TemplateHaskell 13th, QuasiQuotes 20th, MagicHash 22nd, TypeFamilies 29th, DataKinds
  31st, ConstraintKinds 32nd, GADTs 33rd, PolyKinds 34th.
- **The ceilings** (`tier-needs.tsv`): what would be admitted if every name of a class were implemented.

| Implemented | Files | Whole packages |
|---|---:|---:|
| nothing beyond 2010 | 17.72% | 9.05% |
| every recommended name | 44.66% | 28.33% |
| every recommended name but CPP | 38.38% | 19.84% |
| every name at `-` or T0, and T8 | 29.29% | 16.24% |
| also T1 | 45.33% | 26.62% |
| also T2 | 45.62% | 27.36% |
| also T3 | 50.57% | 32.58% |
| also T4 | 54.67% | 33.79% |
| also T5 | 59.26% | 42.60% |
| also T6 | 68.36% | 59.17% |
| every census row (T7 too) | 98.10% | 85.23% |

  The tier rows count every name at that tier or below, whatever its recommendation: TemplateHaskell, QuasiQuotes,
  Safe and MagicHash (`-` and T0), PatternSynonyms (T4) and DeriveDataTypeable (T5) are in them. So 42.6% is what the
  tiers below OutsideIn could reach, not what this roadmap reaches. The files figure through T6 is summed from the same
  file's counts by highest tier [computed]. The last row's gap is `OPTIONS:-F` (546 files), `-fplugin` (300),
  MonadFailDesugaring (95) and MonoPatBinds (2), names GHC 9.14 no longer knows (`results/E7/tier-needs.tsv:54`).
- **Plainly: track X does not make Hackage compile.** 28.3% of packages whole is its ceiling. GADTs and type families
  (T6) would add about 17 points of whole packages and the kinds (T7) another 26. And "admitted" means only that a
  file's names are covered: E8 found that 43 of the 398 plain-2010 components that GHC's own 2010 mode accepts fail
  over the 2010 library, for want of modern `base` (*The experiments*, E8).
- **What goes together** (`cooc-pkg.tsv`, by package). FlexibleInstances is named in 89.6% of the packages that name
  MultiParamTypeClasses, and in 75.1% of those that name FlexibleContexts. MultiParamTypeClasses is in 86.4% of those
  naming FunctionalDependencies. ScopedTypeVariables is in 87.8% of those naming TypeApplications and 79.1% of those
  naming RankNTypes, and TypeApplications in 83.4% of those naming AllowAmbiguousTypes. So the class forms land
  together (M22), fundeps right after them (M23), and scoped type variables with type application and ambiguous types
  (M24). DeriveFunctor is in 79.2% of the packages naming DeriveTraversable, which waits for a library with
  Traversable. The deferred cluster hangs together as well: TypeFamilies is in 79.3% of the packages naming DataKinds,
  TypeOperators in 80.9% of those naming PolyKinds.
- **The editions:** 7,456 files (15.1%) in 200 packages are GHC2021 or GHC2024 (`editions.tsv`). None is admitted
  within 50 steps of any cover, since each needs its whole edition.
- **Over time:** the per-package ranks agree with the GHC2021 proposal's Hackage data of 2020, Spearman's rho 0.869
  over 106 names (`ghc2021-crosscheck.tsv`).

### The recommended set, in landing order

The 72 names fall into groups where one representation changes once (X2) and where packages use them together (E7),
in the order of the milestones. Every name is a feature of the language record (D4), looked up per module (D10) and
read by the header pre-scan (D6, M5). A 98 module reads only edition names (D6), so 98 mode never meets them. For each
group: its members, its size (E12's calibration where E12 measured, E6's band otherwise), its use (E7: packages of the
3,392 naming it), what it changes in valid 2010 programs, and its conservativity test.

The test has two forms (D36; *Testing and conformance* has the design). For a name that changes no valid program, the
standing gate: with it on, the 2010 corpus's bytes do not change. For a name that does, its probe: off, the Report's
answer; on, GHC's. Where GHC departs from the Report in every mode, the expected answer is the Report's and the test is
rhc's own (D39). The probe names below are X1's, in `results/E6/X1-probes/`.

**Haskell 2010 itself (6 names; tracks F and V).** PatternGuards (M8), DoAndIfThenElse, EmptyDataDecls and
NPlusKPatterns (M7), RelaxedPolyRec (M9) and ForeignFunctionInterface (M15, M16). In a 2010 module all are on but n+k
patterns, which 2010 removes. Their work is the Report's, sized by E3 and E10: pattern guards 136 added lines (110 of
code) in 12 files; relaxed groups 41 code lines; empty data 13; DoAndIfThenElse 3; turning n+k off 2
(`results/E3/diffstat.tsv`). The record adds their names and No forms. NoDoAndIfThenElse and NoEmptyDataDecls refuse
valid 2010 programs (`doif.hs`, `emptydata.hs`). Two of GHC's No forms are not what their names say: NoPatternGuards
only warns (`pguard.hs`; `ghc/compiler/GHC/Rename/Bind.hs:1474-1479`), and GHC refuses NoRelaxedPolyRec ("You can't turn
off RelaxedPolyRec any more", `Flags.hs:116-117`); what rhc does with each is D7's. NPlusKPatterns in a 2010 module
brings back 98's n+k, and a top-level `x + 1 = x` still defines `+` (`nplusk.hs`).

**M19, the front end and T0 (39 names).**
- *Lexer and layout:* BinaryLiterals, HexFloatLiterals, NumericUnderscores, NegativeLiterals, LexicalNegation (which
  subsumes NegativeLiterals), MultilineStrings, UnicodeSyntax; NumDecimals (one typing rule for a literal);
  NondecreasingIndentation (one layout condition).
- *Renamer and modules:* NamedFieldPuns, RecordWildCards, DisambiguateRecordFields, DuplicateRecordFields,
  NoFieldSelectors, NoImplicitPrelude, ImportQualifiedPost; NoTraditionalRecordSyntax and NoDatatypeContexts, which
  are parser refusals; Trustworthy and Unsafe, accepted as markers while rhc has no Safe mode.
- *Expressions, one node each:* LambdaCase, TupleSections, EmptyCase, MultiWayIf, BlockArguments (the parser only),
  ParallelListComp, PostfixOperators (a changed rule for a left section), QualifiedDo.
- *Patterns and strictness:* BangPatterns, ViewPatterns, OrPatterns, best built with D14's Sestoft trees so that they
  learn views, bangs and or-patterns once (X1); Strict and StrictData in the desugarer.
- *Types in the front end:* TypeOperators, KindSignatures, StandaloneKindSignatures, StarIsType, GADTSyntax for
  ordinary types (normalised to 98's constructors; existential constructors written in it come with M25), and
  LiberalTypeSynonyms (its forall-in-a-synonym case comes with M26).

Order inside it: the lexical names need M5's pre-scan before rhc lexes (X1's finding 8); MultiWayIf's guards are full
guards, so it follows M8; EmptyCase pairs with D15's empty types in M7. StandaloneKindSignatures needs `Data.Kind`'s
`Type`, which the 2010 library lacks (its census row). **Size:** 31 S and 8 M by E6 (the M are BangPatterns,
DuplicateRecordFields, GADTSyntax, OrPatterns, RecordWildCards, Strict, TypeOperators and ViewPatterns). E3's pattern
guards, a new guard form through 12 files without tests, came in at 136 lines, which puts one new node inside S
[inferred]. HsLint needs nothing for 24 of the 39, since it reads the renamed tree and "shares only the renamer with the
checker" (`hslint_infer.sml:35-36`), and the same rule again for 15. **Use:** LambdaCase 928 packages, RecordWildCards
801, BangPatterns 790, TypeOperators 715, TupleSections 504, ViewPatterns 431, NoImplicitPrelude 375. **Changes:** 18 of
the 39 change valid 2010 programs (the table under D36 below); GHC cannot judge NumericUnderscores, QualifiedDo or
BangPatterns off, since 9.4.7 refuses `1_000` with a variable `_000` in scope, `Just.do` and `f !x` even under
`-XHaskell2010`. **Test:** the gate for the other 21; the probes for the 18; MultilineStrings and OrPatterns are source
only and have rhc's tests alone.

**M20, CPP (1 name).** D12 decides how (a subset in SML), and *Tracking language settings* where it runs. It is the
most used name: 1,581 packages (46.6%) and 18.6% of files (E7). It pays only with the rest: 1,123 files (2.3%) need CPP
and nothing else, but leaving it out of the recommended set costs 8.5 points of whole packages (28.33% to 19.84%).
**Size:** M by E6. **Changes:** `__GLASGOW_HASKELL__` is an ordinary name in 2010 (`cpp.hs`), and a string gap breaks
under cpp (`cppgap.hs`: `abcdef` without CPP, a compile error with it). **Test:** those two probes, and E3's check that
directive and skipped lines are blanked so positions hold.

**M21, deriving (8 names).** StandaloneDeriving, DeriveFunctor, DerivingStrategies, DeriveAnyClass and
EmptyDataDeriving are T0: trees made by `derive.sml`'s scheme, which the checker and HsLint see as a user's instance
(`derive_sig.sml:1-6`). GeneralizedNewtypeDeriving and DerivingVia are T1: they reuse a dictionary through a cast of the
whole dictionary, where Core's `Cast` goes only through a newtype's head (`core_sig.sml:73`; D37); without type families
or GADTs no roles are needed (X3) [inferred]. DefaultSignatures is T1. **Size:** S for four, M for DeriveFunctor, GND,
DerivingVia and DefaultSignatures (E6). **Use:** GND 892 packages, StandaloneDeriving 580, DeriveFunctor 442,
DerivingStrategies 379, DefaultSignatures 337. **Order:** EmptyDataDeriving needs D15's empty types (M7). M21 rests on
M5 alone, but three of its names gain from landing after M22: GND and DerivingVia pay mostly for classes of several
parameters (mtl's `deriving (MonadState s)`), and DefaultSignatures' real contexts (`Generic a`, `MonadTrans t`) are
beyond 2010's, so its row says after T1. DeriveAnyClass pays only with DefaultSignatures and a Generic, which waits
(below). **Changes:** none; GND leaves the stock-derivable classes of a newtype as they were (E5's P18n). **Test:** the
gate.

**M22, A+ and T1 (8 names).** The deferred store of class constraints (D34), and with it MultiParamTypeClasses,
FlexibleInstances, FlexibleContexts, TypeSynonymInstances, ConstrainedClassMethods and UndecidableInstances: one
refactor of the predicate, the instance index and the instance's identity, through the checker, evidence,
interfaces, the desugarer and HsLint (X2). GHC's implications tie them: MultiParamTypeClasses implies
ConstrainedClassMethods, and FlexibleInstances TypeSynonymInstances (`Flags.hs:294, 296`). Then overlap:
OverlappingInstances with the OVERLAPPING, OVERLAPPABLE and OVERLAPS pragmas, choosing the most specific instance and
deferring while one that does not match still unifies. And OverloadedStrings, which is T1 because its one standard
instance is at `[Char]`. **Size:** E12 built MultiParamTypeClasses, FlexibleInstances and FlexibleContexts with the
Paterson conditions and UndecidableInstances' lifting: 1,101 added lines, 964 of code; 1,600-2,400 in production, L
for the group. Overlap and OverloadedStrings were not built: M each by E6. HsLint's instance lookup already matches
heads as THIH does (`hslint_classes.sml:67-80`), nearer to T1 than the checker's index (X2). **Use:** OverloadedStrings
1,499 packages, FlexibleInstances 1,300, FlexibleContexts 1,148, MultiParamTypeClasses 933, UndecidableInstances 687.
**Changes:** none but OverloadedStrings. T1 accepts programs 98 refuses (26 of `tests/hs/errors`), which is what
lifting a restriction means, and deferral moves when some errors are reported. OverloadedStrings makes a literal
`fromString "..."`, so a 2010 call `c "abc"` at a user's class becomes ambiguous (`ovlstr.hs`). Three points are open.
`print (length "abc")` with 2010's list `length` leaves `IsString [a]`, which GHC solves through
`instance (a ~ Char) => IsString [a]` (`ghc/libraries/ghc-internal/src/GHC/Internal/Data/String.hs:105`), a T6
equality: rhc either refuses it, with an instance at `[Char]`, or adds an improvement rule of its own (X2). IsString
is a class the 2010 library does not have. And defaulting learns IsString and String
(`ghc/docs/users_guide/exts/overloaded_strings.rst:41-50`), which reaches D20's test of standard classes. **Test:**
E12's measure, with T1 on `tests/hs/lang` and the corpus byte-identical, and the error suite's 26 newly accepted and 12
reworded programs listed and pinned (`results/E12/identity/t1on-errors/`); OverloadedStrings by its probe.

**M23, T2 (1 name).** FunctionalDependencies: improvement from instances, from the givens' superclasses and from pairs
of wanteds, repeated to a fixpoint; ambiguity and generalisation judged modulo the dependencies. Jones 2000, section 6,
is HsLint's specification; improvement from a given is refused, since it cannot be elaborated to System F (*What the
literature says*, correction 2). **Size:** E12 512 added lines (446 of code); 800-1,200 in production, M, at its upper
end. GHC's tests: 27 of 32 accepted and 16 of 16 refused; of the five failures, three need EmptyDataDecls, one overlap,
and one meets R20, rhc's refusal of an unsigned `main = return ()` (`results/E12/ghc/categories.tsv`). **The regime is
the owner's** (D35). Jones's coverage condition refuses mtl's lifting instances. GHC's liberal coverage under
UndecidableInstances admits them and leaves termination to a depth bound. A liberal coverage with the Paterson
conditions kept does not guarantee termination (GHC's own `Mul a b c => Mul a [b] [c]` meets both and loops: W13,
`instances.rst:293-307`); Sulzmann et al.'s Terminating Weak Coverage, which also asks that a dependent argument be a
variable where coverage is broken (Def. 14), is proven terminating with full dependencies, admits E12's mtl instances
and refuses `Mul` (*Decisions*, D35); it was not built. **Use:** 383 packages, 86.4% of them naming
MultiParamTypeClasses too. **Changes:** none. **Test:** the gate; with every tier on, one error program is refused with
another message (`cls.inst.ctx.vars`).

**M24, T3 (5 names).** ExplicitForAll (T0 in the census, grouped here as the milestone has it), ScopedTypeVariables,
TypeApplications, AllowAmbiguousTypes and InstanceSigs. One change serves all five: schemes keep the user's variable
order and the distinction between specified and inferred variables, and a scope of type variable names reaches
expressions, pattern signatures and class and instance bodies (X2). It gives HsLint the rigid variables its second
inference lacks (`hslint_infer.sml:698-722`), which T4a and T5 reuse. Two constraints: 98 mode keeps `schemeOf`'s
order (`infer.sml:578-601`), since a scheme's order is the order of Core's type binders and 98's bytes must hold; and
the order must be in the interface (D9). **Size:** not built by E12; S, M, M, S, M by E6. Eisenberg, Breitner and
Peyton Jones 2018 specify ScopedTypeVariables, and Eisenberg, Weirich and Ahmed 2016 prove visible type application
conservative (*What the literature says*). **Use:** ScopedTypeVariables 1,401 packages, TypeApplications 625,
AllowAmbiguousTypes 265, InstanceSigs 210. **Changes:** ExplicitForAll makes `forall` a keyword in types, where 2010
has it as an ordinary variable (`forall.hs`, `idf :: forall -> forall`). GHC reserves it in every mode
(`ghc/compiler/GHC/Parser/Lexer.x:1067`; `ghc/docs/users_guide/bugs.rst:44-49`), so GHC cannot judge it.
ScopedTypeVariables lets a class's variable scope over its methods' bodies, so an inner signature that names it
changes meaning (`stv.hs`). TypeApplications' `@` cannot occur in a 2010 expression, and AllowAmbiguousTypes only
accepts more. **Test:** `forall.hs` against the Report, `stv.hs`, and the gate for the other three.

**M25, T4a (1 name).** ExistentialQuantification, with contexts on the existential variables only. **Size:** E12 586
added lines (505 of code), Core's share 133 code lines in 13 files; 1,000-1,500 in production, L. Refused by design: a
context on a universal variable (T4b), existential pattern bindings, selectors and deriving. GHC's tests: 0 of 2
should_compile accepted, T10856 by design and the other for want of existential record fields and NoImplicitPrelude in
the prototype; 6 of 6 should_fail refused. Laeufer 1996's three rules are HsLint's specification (*What the literature
says*). **Use:** 302 packages. **Changes:** only through the `forall` its implied ExplicitForAll reserves (E5's P18c).
**Test:** the gate and `forall.hs`.

**M26, T5 (1 name).** RankNTypes under simplified subsumption: a forall in `HsTypes.ty`, arguments checked against
polytypes, annotations required, System F with no coercions. Its aliases Rank2Types and PolymorphicComponents follow it.
**Size:** E12 450 added lines (394 of code), accepting 11 of GHC's 31 should_compile files and refusing 16 of 17
should_fail. To cover GHC's tests it needs a forall in a result skolemised against a clause's further patterns,
CoreToMid's boxing (above), polytypes through synonyms (LiberalTypeSynonyms) and contexts in nested types: 1,500-2,500
in production, L, the largest of the four. It is XL only with DeepSubsumption or ImpredicativeTypes, which stay
later. GHC's Haskell2010 edition turns DeepSubsumption on (`DynFlags.hs:1346`), so a GHC probe of T5 needs
`-XNoDeepSubsumption` (*What the implementations do*). **Use:** 967 packages, 79.1% of them naming
ScopedTypeVariables. **Changes:** only through ExplicitForAll. E12's switch reserved `forall` in every type and so
accepted `ty.quant.noforall`; the milestone ties the keyword to ExplicitForAll (D36). **Test:** the gate and
`forall.hs`, and a property the Haskell' page on rank N states: "Programs containing no foralls are typeable if and
only if they are typeable in Haskell 98" (`HP/RankNTypes.txt:96`, as *What the literature says* cites it).

**M27, T8 (2 names).** NoMonomorphismRestriction and MonoLocalBinds. They change how a group is generalised,
`implicitGroup` in the checker (`infer.sml:1336`), `tiImpls` in HsLint's inference (`hslint_infer.sml:811`) and the
replay's `bindg` rule (X2), beside the edge filter M9 puts in `groupsOf` and HsLint's `succs`; so M27 rests on M9
alone, and D35 places it before T1. Being per module, each needs D10's lookup where a ref is today
(`infer.sml:2007-2010`).
**Size:** S and S (E6). **Use:** NoMonomorphismRestriction 163 packages, MonoLocalBinds 72. **Changes:** both. Without
the restriction a restricted group is generalised, its sharing lost, and Rule 2 goes: in X2's example `big = 2^64`,
used at `Int` and printed, is an `Int` under the restriction and an `Integer` without it (not probed). MonoLocalBinds
refuses `f x = let g y = (x, y) in (g 1, g 'c')` at `f :: Int -> ((Int, Int), (Int, Char))` (`monolocal.hs`;
`results/E6/X1-data/probes.tsv:37`). GHC implies MonoLocalBinds only from GADTs, TypeFamilies and LinearTypes
(`Flags.hs:304, 305, 356`), none of them recommended, so in this roadmap it comes only when written. **Test:**
`monolocal.hs`, a probe for the restriction's No form written from X2's example, and mixed-cycle tests in the checker
and HsLint (D10).

### What is deferred, and to which roadmap

**To the OutsideIn roadmap** (later-outsidein, 9 names, and T4b):
- T6: GADTs beyond GADTSyntax and T4a, TypeFamilies, TypeFamilyDependencies, OverloadedLists (its `Item` is a type
  family) and DeriveGeneric (its `Rep` is one);
- names over type-level strings or DataKinds: OverloadedRecordDot (HasField and improvement), OverloadedLabels
  (IsLabel), ListTuplePuns;
- PatternSynonyms (T4 in the census), whose provided contexts are local givens or equalities and whose matchers take
  rank-2 continuations;
- T4b, a context on a universal variable, which M25 refuses, as GHC's T10856 and OutsideIn's MkR show it must.

The T6 names need System FC in Core (D37). DeriveGeneric is the most used, in 830 packages. UHC's Generic used a
two-parameter class, `class Representable0 a rep` (`uhc/EHC/ehclib/uhcbase/UHC/Base.chs:2472`), so an encoding at T1 or
T2 could bring it into this roadmap, at the price of a Generic that is not GHC's: D35 asks for that recheck.

**To a kinds roadmap** (T7; 8 of the later-other names): PolyKinds, DataKinds, ConstraintKinds, TypeData, CUSKs,
LinearTypes (multiplicity variables, and a usage checker no rung holds), OverloadedRecordUpdate, and UnboxedTuples,
whose Core is there already (`UTuple`, `AltUTuple`: `core_sig.sml:72, 79`) and which waits only on HsTypes' kinds.
Kind variables reach HsTypes, Core, CoreLint, interfaces and HsLint's kinds. ConstraintKinds could go first: it needs a
Constraint kind but no kind polymorphism (X2).

**Later, beside this roadmap** (the other 25 later-other names):
- rank N beyond its core (T5): DeepSubsumption, ImpredicativeTypes, QuantifiedConstraints, RequiredTypeArguments,
  TransformListComp (a rank-2 argument), and DeriveDataTypeable (Data's rank-2 `gfoldl`, and a Typeable GHC solves
  kind-polymorphically), the most used of them at 729 packages, which D35 also asks to recheck;
- a library beyond 2010's: ApplicativeDo (Applicative as Monad's superclass), MonadComprehensions (MonadZip),
  RecursiveDo (MonadFix), DeriveFoldable and DeriveTraversable (Foldable, Traversable);
- large or experimental: Arrows, RebindableSyntax;
- after their tier: IncoherentInstances (HsLint could only replay its choice), UndecidableSuperClasses, RoleAnnotations
  (meaningful with Coercible and T6), ImplicitParams, PartialTypeSignatures, NamedWildCards, TypeAbstractions,
  ExtendedDefaultRules, NamedDefaults;
- modules: ExplicitNamespaces, PackageImports (meaningless without packages), and Safe, which refuses valid 2010
  programs (a pure foreign import, E5's P18l) and switches GND, DerivingVia and TemplateHaskell off with a warning (E5).

**To a meta roadmap** (later-meta, 6): TemplateHaskell, TemplateHaskellQuotes, QuasiQuotes, DeriveLift,
ExplicitLevelImports, ImplicitStagePersistence. They run code at compile time. rhc has a Core interpreter
(`coreinterp.sml`), so what is extensive is TemplateHaskell's syntax library, reification and staging (X3); and they
are what D40's filter keeps out of the corpus. TemplateHaskell is in 668 packages, QuasiQuotes in 291.
ImplicitStagePersistence is in every edition and inert without TemplateHaskell (D7).

**To the runtime** (later-runtime, 2): CApiFFI, which needs a C stub per import and so a C toolchain in rhc's build;
and InterruptibleFFI, which is `safe` until threads and `throwTo` exist, the concurrent-runtime roadmap's.

**Never** (14), GHC-specific or experimental: the layout experiments (AlternativeLayoutRule, its Transitional
variant, RelaxedLayout); GHC's primitive representation (MagicHash, ExtendedLiterals, UnboxedSums, UnliftedDatatypes,
UnliftedNewtypes, UnliftedFFITypes, GHCForeignImportPrim); JavaScriptFFI; StaticPointers; and ParallelArrays and
AutoDeriveTypeable, which GHC itself reads only for their implications (E5). Some are accepted as inert names (D7).
MagicHash is the most used, in 357 packages.

**Not applicable** (12): the four editions (Haskell98 and Haskell2010 are the modes, D1 and D2; GHC2021 and GHC2024
below), and eight other spellings that follow their canonical rows. GeneralisedNewtypeDeriving, Rank2Types,
PolymorphicComponents, PatternSignatures, RecordPuns and NullaryTypeClasses come with their targets in this roadmap;
DoRec and TypeInType wait with theirs.

### The editions GHC2021 and GHC2024

- **GHC2021** has 48 names (`DynFlags.hs:1351-1402`): Haskell2010's set without CUSKs, DatatypeContexts and
  DeepSubsumption, and 36 more. 28 of the 36 are recommended. The other 8 are PolyKinds and ConstraintKinds (T7),
  DeriveGeneric (T6 in the census), DeriveDataTypeable (T5, later), DeriveFoldable and DeriveTraversable (a library
  beyond 2010's), DeriveLift (meta) and NamedWildCards (T3, later).
- **GHC2024** is GHC2021 and 8 more, 56 (`DynFlags.hs:1404-1413`): GADTs (T6), DataKinds (T7), RoleAnnotations and
  ExplicitNamespaces (later), and DerivingStrategies, DisambiguateRecordFields, LambdaCase and MonoLocalBinds, which are
  recommended.
- **So neither can be accepted faithfully in this roadmap.** GHC2021 needs T7, T5 beyond its core, and T6 through
  DeriveGeneric as the census tiers it; GHC2024 adds GADTs. D5 does not accept them, and a module that names one fails
  as known but not supported (D7).
- **Both change valid 2010 programs.** Under GHC2021 a type variable `_a` is a wildcard (NamedWildCards, E5's P18s) and
  a data type's context is refused (E5's P18u), besides each recommended member that changes programs (below).
- **Their weight:** 7,456 Stackage files (15.1%), in 200 packages (E7).

### Extensions that change valid programs (D36)

67 of the 148 names change the meaning or acceptance of some valid Haskell 2010 program when turned on: 59 extensions,
3 editions (Haskell98, GHC2021, GHC2024), Safe, 2 alternate spellings and 2 deprecated ones. 28 of them are recommended.
D36's rule: each comes only when written, as a pragma, a `-X` flag or an edition, never because rhc turned it on; and
each has its test. The 28, by how they change a program (X1's and X2's notes; the probes are X1's unless named):

| How | Recommended names | Probe |
|---|---|---|
| the No form of something 2010 has | ImplicitPrelude, TraditionalRecordSyntax, FieldSelectors, DatatypeContexts, MonomorphismRestriction, DoAndIfThenElse, EmptyDataDecls | `noprelude`, `notrad`, none yet, E5's `dtctx` (P18t, P18u), none yet, `doif`, `emptydata` |
| a lexeme 2010 reads as two | BinaryLiterals (`0b1`), HexFloatLiterals (`0x1p4`), NumericUnderscores (`1_000`) | `binlit` (0 against 1), `hexfloat` (1.0 against 16.0), `numund` |
| spacing round `-` or `!` | NegativeLiterals, LexicalNegation, BangPatterns | `neglit`, `lexneg`, `bang`, `bang2` |
| a symbol 2010 lets an operator use | UnicodeSyntax | `unisyn` |
| a name becomes a keyword | LambdaCase (`cases`), QualifiedDo (`M.do`), ExplicitForAll (`forall`), and through it ScopedTypeVariables, ExistentialQuantification, LiberalTypeSynonyms and RankNTypes | `lcases`, `qualdo`, `forall`, E5's P18a-c |
| the type or meaning of 2010 syntax | OverloadedStrings, NumDecimals, PostfixOperators, Strict, StrictData, ScopedTypeVariables (scoping), MonoLocalBinds | `ovlstr`, `numdec` ((1000.0,2.0) against (1000,2)), `postfix`, `strict`, `strictdata`, `stv`, `monolocal` |
| preprocessing | CPP | `cpp`, `cppgap` |

The names left for later change programs the same ways: keywords taken by RecursiveDo (`mdo`, `rec`), Arrows (`proc`),
TransformListComp (`group`, `by`, `using`), PatternSynonyms (`pattern`) and TemplateHaskell (`$x`, `[e|`); a symbol by
OverloadedLabels (`#`) and OverloadedRecordDot (a tight `.`); MonoLocalBinds' rule by every name that implies it.

What follows for rhc:
- **`forall` is a keyword only under ExplicitForAll and the names that imply it,** since the Report has it as a
  variable. GHC reserves it in every mode. E12's T5 switch reserved it in every type and so accepted
  `ty.quant.noforall`, a 98 refusal: the milestones must not.
- **BangPatterns' reading of `!` applies only when it is on.** GHC reads `f !x` as a bang in every mode and refuses it
  without the extension (`bugs.rst:51-57`; `bang.hs`, `bang2.hs`).
- **GHC cannot judge these two,** nor `1_000` with a variable `_000` in scope, nor `Just.do`, which 9.4.7 refuses under
  `-XHaskell2010` though `bugs.rst` does not say so (*Found while writing*). For them the expected result is the
  Report's (D39).
- **No recommended name brings in a meaning-changing one unseen.** ExplicitForAll is implied by RankNTypes,
  QuantifiedConstraints, ScopedTypeVariables, LiberalTypeSynonyms and ExistentialQuantification (`Flags.hs:289-293`),
  each of which a module names itself and each of which reserves `forall` in its own row; the names that imply
  MonoLocalBinds are all later.
- **The editions are bundles of such changes** (above), which is a second reason they are not accepted.
- **A changes_valid row is a claim, and the census has been wrong once** (LambdaCase, above). Every `no` that was not
  probed is argued, not measured; the standing gate is what checks it (*Testing and conformance*).

## Tracking language settings

The brief's last request: "design a good way to track language extensions during rhc combination as we will have
language pragma's in the source code (no necesailty corresponding one-to-one to how rhc will keep track of language
flags), compiler flags on the command line, etc." This section is that design, written for whoever builds it (M4,
M5, M6 and M20). It is one record per module: an edition and a set of rhc's own features, resolved once from the
command line and the module's header by GHC's rules, kept in one canonical form, and asked by every stage by module.

Two throwaway prototypes stand under it: E3's header pre-scan behind a stub (`patches/E3-07-pragma.patch`) and E4's
record through every stage of rhc, with the library made a descriptor (`patches/E4-language-record.patch`). Each part
below says whether it was **prototyped** (built and measured in E3 or E4), **measured on GHC** (E5), or **designed**
only. D4 to D12 argue the choices; D1 to D3 the mode around them. The state at the pin is in *Where we are* (*How a
setting reaches each stage*, *Pragmas*) and is not repeated here.

### The design in brief

- **A setting** is an edition and an ordered list of steps, each a feature on or off, as GHC's is (E5). It is resolved
  once per module into a canonical set of rhc's features. The edition is kept beside the set to be named in
  diagnostics; nothing else reads it.
- **The inputs,** in the order they apply: the base edition from `--language`; `-X` flags and rhc's own language
  options, in command-line order; the module's header, its LANGUAGE pragmas and OPTIONS_GHC's `-X` flags, in text
  order. The library is read under its own language, whatever the program's.
- **The names** are GHC 9.14.1's 148 and their No forms, in a closed table. Each is supported, inert, or not supported
  by rhc; a name not in the table is unknown. Unknown and unsupported names are errors, as chapter 12 requires
  (T10:10989-10990).
- **In a Haskell 98 module only the edition names are read.** Every other name is ignored, as rhc ignores every pragma
  today. This is what holds 98 mode's bytes.
- **Every stage asks one question:** whether this module has feature F, by the file it reads or the module a binding
  belongs to. A cycle's own settings must agree across its modules.
- **The store** keys each member of a unit by its canonical set, Haskell 98's own set as nothing, so that 98's keys
  stand; the header by the program's base setting; the configuration by the library. The snapshot cannot see the
  program's flags.
- **The printers** print the header's pragmas. **CPP,** if D12 takes it, runs between two reads of the header.

### The inputs

*Status: prototyped (E4), but for OPTIONS_GHC and `RHC_LANGUAGE`, which are designed.*

| Input | What it gives | Status |
|---|---|---|
| `--language=haskell98`, `--language=haskell2010` | the base edition of every module of the program, and the library `share/rhc/<edition>` with its configurations in the snapshot (D1); haskell98 when absent, until the flip (D3, G3) | prototyped: E4's `RhcSyntax.edition` and `RhcLibrary.select` |
| `RHC_LANGUAGE` | the default of `--language`, read as `RHC_STORE` is (`src/rhc/storeconfig.sml:49`); the flag wins | designed (D3) |
| `-XName`, `-XNoName` | steps, in command-line order, for every module of the program and for none of the library's | prototyped (E4) |
| `--dotted-names`, `--cycle-default=scc`, `--names=greatest` | steps of three of rhc's own features (D8): hierarchical module names in 98 mode, one `default` per cycle (98's D30), a cycle's names at the greatest fixpoint (98's D29) | prototyped (E4) |
| `{-# LANGUAGE ... #-}` in the header | steps, in text order, after the command line's | prototyped (E3, E4) |
| `{-# OPTIONS_GHC ... #-}`, `{-# OPTIONS ... #-}` in the header | its `-X` flags and `-cpp` as steps, in text order among the LANGUAGE pragmas; any other flag ignored with a warning | designed (D6) |
| the library's descriptor | the language the library's modules are read under: 98's for `haskell98`, 2010's for `haskell2010` | prototyped (E4) |

An edition named by `-XHaskell98` or `-XHaskell2010` on the command line is a step like an edition pragma: it sets the
rules of every module that does not name its own, and leaves the library to `--language` (D2) [designed]. A command line
copied from Cabal, `-XHaskell2010` with no `--language`, so gets 2010's rules over 98's library until the flip; the
diagnostics name both (D11) [inferred].

**What is not an input.**
- *The compile's modes.* `--strings`, `--match`, `--eta`, `--unfoldings`, `--no-cheap-eagerness`, `-O`,
  `--by-interface`, `--whole` and `--lint` change how a program is compiled, not what it means. They stay where they
  are, in the unit's configuration (`extraOf`, `src/rhc/driver.sml:172-178`) or the link's, and out of the record (D8;
  E4, `agents/A-report.md` finding 9). `HsMatch.order` stays one ref for the run (`lib/language/haskell/match.sml:10`).
- *A package description.* rhc reads none. Cabal hands a component's settings to GHC as flags: its `default-language`
  as `-XHaskell98` when the field is absent (`ghcOptLanguage = toFlag (fromMaybe Haskell98 (defaultLanguage bi))`,
  `ghc/libraries/Cabal/Cabal/src/Distribution/Simple/GHC/Internal.hs:586`), then `default-extensions` as `-X` flags
  in order (E5, `results/E5/others.md`). A driver that reads Cabal files would do the same through rhc's command line.

**How often each is written** [measured]. LANGUAGE pragmas in the header: 6,751 of the GHC testsuite's 11,227 files
and 655 of the 3,089 corpus candidates; several LANGUAGE pragmas in 2,278 and 50; one over several lines in 282 and 52;
a comment before one in 220 and 42; the keyword not in capitals in 175 and 1 (`Language` 350 times and `language` 209
in the testsuite); OPTIONS_GHC or OPTIONS with `-X` in 106 and 66; a LANGUAGE pragma after the header in 13 and none
(E3, `results/E3/pragmas/summary.tsv`, `spellings.tsv`). On Stackage, OPTIONS with `-X` or an old `-f` spelling, `-F`
and `-fplugin` aside, is in 47 of 49,649 module files (E7, `results/E7/modules.tsv`, column `options_x`). Of the 195
distinct names written in the three sets' headers, 17 are none of GHC's (one a comment inside a pragma, as the census
read it): misspellings that tests make on purpose (`ExistientialQuantification`, `wibble wibble wibble`) and other
compilers' names (`ExtensibleRecords`, `HereDocuments`, `M4`, `Generics`) (`results/E3/pragmas/names.tsv` against
`results/E5/names.tsv`).

### How they resolve (D5)

*Status: measured on GHC (E5: 137 probes on 9.4.7, 129 as predicted from 9.14.1's source); prototyped in E4 without
implications (its `implied` is the empty table, `patches/E4-language-record.patch`, `language.sml`); modelled as data
by E13 and checked against E5's probes, below.*

For each module of the program:
1. **Start** from the base edition (`--language`, else `RHC_LANGUAGE`, else haskell98 until G3) and no steps.
2. **The command line, left to right.** An edition replaces the edition and nothing else. `-XName` appends `On f` for
   the feature `f` it names, then, at that point, the steps its implications give, recursively; `-XNoName` appends
   `Off f` and nothing else.
3. **The header, in text order,** LANGUAGE and OPTIONS_GHC alike, a pragma's names left to right: the same steps.
4. **The 98 rule.** If the last edition named (step 1's, the command line's or the header's) is Haskell98, the
   header's names other than editions are dropped before they become steps, unread, with no warning and no error. The
   command line's steps stay (D6).
5. **The set** is the edition's features with the steps replayed over them, oldest first.
6. **Checks:** every name written is known, and supported or inert; an implied feature rhc does not support fails no
   setting, only its construct where it is written (E13's C4); the set passes the combination table; the Safe Haskell
   names combine (D7). An error is said at the name's own line and column.
7. **Result:** the edition and the set, sorted.

**What rhc keeps of GHC** [measured: E5, `results/E5/semantics.md` sections 2-8, probe ids in
`results/E5/probes/results.tsv`]:
- An edition is a base, not a step: `-XTupleSections -XHaskell2010` keeps tuple sections, `-XNoTupleSections -XGHC2021`
  loses them (P02a, P02b), and of two editions the last wins (P02c, P02d). `lang_set` replaces the edition and
  recomputes from the same list (`ghc/compiler/GHC/Driver/DynFlags.hs:1127-1132`).
- The set is the edition's list with the steps folded oldest first (`flattenExtensionFlags`, `DynFlags.hs:757-761`).
- An implication is a step at its position: "When you set f, set the ones it implies" and "When you un-set f, however,
  we don't un-set the things it implies" (`ghc/compiler/GHC/Driver/Session.hs:2985`, `:2995`). So `-XGADTs
  -XNoMonoLocalBinds` leaves MonoLocalBinds off and the reverse leaves it on (P04c, P04d), and `-XGADTs -XNoGADTs`
  keeps what GADTs implied (P04e). GHC's table has 38 implications, three of them negative
  (`ghc/compiler/GHC/Driver/Flags.hs:286-359`).
- The header comes after the command line, as more of the same flags: a LANGUAGE name becomes `"-X" ++ ext`
  (`ghc/compiler/GHC/Parser/Header.hs:451-457`), parsed over the command line's flags (`getFileArgs`,
  `ghc/compiler/GHC/Driver/Pipeline/Execute.hs:658-667`). The command line cannot override a module's pragma (P03b).
- Within the header, LANGUAGE and OPTIONS_GHC in text order (P11c, P11d).
- Alternate names are one feature (P07h); a deprecated name warns when it is written (P08a-P08d), and an edition's
  member never warns (P08o).
- Nothing crosses a module boundary (P15a-P15c).
- Repeats are allowed, as chapter 12 asks: "multiple attempts to enable the same, supported language features ... are
  specifically permitted" (T10:10991-10993).

**Where rhc departs, each by a decision:**
- *The default edition.* GHC's is GHC2021 (`defaultLanguage = GHC2021`, `Flags.hs:69`); rhc's is haskell98 until the
  flip and haskell2010 after it (D3).
- *GHC2021 and GHC2024* are known names that rhc does not support: they need rank-N types and kinds, and both need T6
  too (GHC2021 through DeriveGeneric's type family, GHC2024 through GADTs as well) (D5; E6; W12). So GHC2021's own gap,
  TypeOperators without the ExplicitNamespaces it implies (E5, P05a), does not arise.
- *rhc's editions are the Reports, not GHC's lists.* GHC's Haskell98 adds NondecreasingIndentation, DeepSubsumption,
  ListTuplePuns and ImplicitStagePersistence, its Haskell2010 the last three (`DynFlags.hs:1310-1349`). A name in
  GHC's list that states a rule of the Report (ImplicitPrelude, MonomorphismRestriction, DatatypeContexts,
  TraditionalRecordSyntax, FieldSelectors, StarIsType; NPlusKPatterns in 98; the five of chapter 12 and
  DoAndIfThenElse in 2010) is on in rhc's edition, so writing it is a step that changes nothing. GHC's additions are
  not in rhc's editions: NondecreasingIndentation is an extension in either, as the census has it (E6,
  `results/E6/census.tsv`).
- *The 98 rule* (step 4): GHC reads every name in every edition (D6).
- *Errors GHC does not give:* a known name rhc does not support, and a combination rhc's table refuses (D7). GHC refuses
  no combination when it reads flags (`makeDynFlagsConsistent`, `Session.hs:3592` on, tests no extension).
- *OPTIONS_GHC:* rhc reads its `-X` flags and `-cpp` and ignores any other flag with a warning; GHC obeys every
  dynamic flag there and refuses the others, "Unknown flag in {-# OPTIONS_GHC #-} pragma: -package" (P09k) (D6).
- *Two of GHC's deprecation texts.* Deprecations are warned where the name is written, as GHC does. But GHC's text
  for DatatypeContexts, "It was widely considered a misfeature, and has been removed from the Haskell language."
  (`Flags.hs:118-119`), is untrue of both Reports, which have datatype contexts, so rhc's warning says only that GHC
  deprecates the name [designed]. And GHC cannot turn RelaxedPolyRec off, "You can't turn off RelaxedPolyRec any
  more" (`Flags.hs:116-117`), where rhc has both rules: `NoRelaxedPolyRec` in a 2010 module is E13's combination C8,
  the owner's, recommended inert with that warning, as GHC; the prototype's resolution gives such a module 98's 4.5.1
  instead (`results/E13/edits.tsv`, p06 step 2, in a 98 program, refuses 4.5.1's case under the pragma) (D7).
- *The edition is out of the key* (D9). GHC's interface fingerprint covers both the edition and the set
  (`ghc/compiler/GHC/Iface/Recomp/Flags.hs:48-50`), so two spellings of one set rebuild [inferred].

**What E13's model shows** [measured: `results/E13/model.py`, `predictions.tsv`, `showlang.tsv`, `agreement.md`].
The rules above written as data, over GHC 9.4.7's own editions, its 35 implications and flag names (E5's
`probes/api/tables-947.txt`) and 9.14.1's 148 names, reproduce all 19 of E5's `:show language` captures, edition and
every modifier (implication chains, a No after its implier, the negative implications, Safe, `-fglasgow-exts`, GHC2021's
missing ExplicitNamespaces), and 132 of the 137 probes' outcomes, all 116 of P01-P17. The 5 misses are GHC departing
from the Report outside resolution, with the model's set equal to GHC's in each: `forall` a keyword in every type
(P18a), a prefix `!` a bang in every mode (P18f, P18o), and OverloadedStrings' defaulting (P18i, P18j). So the
prototype's empty `implied` takes GHC's implication table as data, the negative implications with it (D5). rhc's design
answers 60 of the 137 probes as GHC does and 77 otherwise, a probe for one or more stated reasons: no edition given, so
rhc's default and not GHC2021 (45); GHC2021 or GHC2024 named (9); Safe (8); a name rhc does not support (24); CPP (7);
an OPTIONS_GHC flag other than `-X` (1); GHC's old `-f` spellings, which are not rhc's options (5)
(`predictions.tsv`, column `rhc_design`) [inferred from the rulings].

**A worked example** [designed; E4's prototype gives the same set]. `rhc --language=haskell98 -XNoNPlusKPatterns
Main.hs`, where `Main.hs` opens with `{-# LANGUAGE Haskell2010, NPlusKPatterns #-}`:

| Step | Edition | Steps | Note |
|---|---|---|---|
| 1 | Haskell98 | | `--language` |
| 2 | Haskell98 | Off NPlusKPatterns | the command line |
| 3 | Haskell2010 | Off NPlusKPatterns, On NPlusKPatterns | the header: an edition, then a name |
| 4 | Haskell2010 | as above | the last edition is 2010, so the header's names were read |
| 5 | | | 2010's six features, then the steps: DoAndIfThenElse, EmptyDataDecls, ForeignFunctionInterface, HierarchicalModules, NPlusKPatterns, PatternGuards, RelaxedPolyRec |

The module is read under that set over 98's library, and its key is the set's canonical string. Had the header been
`{-# LANGUAGE BangPatterns #-}`, the last edition would be Haskell98, BangPatterns would be dropped unread, and the set
would be 98's own, `NPlusKPatterns`, removed by the command line's step: the empty set.

### The representation (D4)

*Status: prototyped (E4: `HsLanguage`, `lib/language/haskell/language{,_sig}.sml` in the patch, 226 lines with the
library's names); the table of 148 names designed.*

**The record.** `HsLanguage.t` holds the edition and the resolved set; the steps exist only while resolving. Stages
see it through `has (t, f)`, `edition t` (for messages) and `canonical t` (for keys); E4's signature is that shape
(`edition`, `features`, `has`, `ofEdition`, `apply`, `canonical`, `pragmas`). Production adds the table, the
implications, the classes of D7 and, for each step, where it was written, so that an error can point at it.

**The names: a closed table of GHC 9.14.1's.** 148 names: 135 `Extension` constructors
(`ghc/libraries/ghc-internal/src/GHC/Internal/LanguageExtensions.hs:30-170`), 3 alternate names and 3 deprecated ones
(`ghc/compiler/GHC/Driver/Flags.hs:265-278`), 4 editions and 3 Safe Haskell modes; every one of the 141 extension names
has a No form, editions and Safe modes none (E5, `results/E5/names.tsv`, `semantics.md` section 1). A row gives the
name's class (D7), the feature or features it sets, its implications as GHC's table has them, and its deprecation text.
The names mean what
GHC 9.14.1 means by them: one name, one semantics, since the same name has meant different things in different
compilers ("although GHC and Hugs use the same syntax, the meaning of type variables is quite different", E11,
`HP/ScopedTypeVariables.txt:58`). The Haskell' proposal's own names that are not GHC's (RelaxedDependencyAnalysis,
EmptyDataDeclarations, FixityResolution, LineCommentSyntax, HierarchicalModules, LanguagePragma) are unknown unless
the owner asks (D4; E11). The table is SML, about 300 lines for 148 rows, 38 implications and the deprecations
[inferred], and a generated test holds every row (*Testing and conformance*, *Tests of the tracking design*, item 2).

**The features: rhc's, one per rule a stage tests.** The mapping from names is not one to one in four ways, which is
what the brief asks for:
- *several names, one feature:* the alternates and deprecated names (GeneralisedNewtypeDeriving; Rank2Types and
  PolymorphicComponents onto RankNTypes; DoRec, RecordPuns, PatternSignatures onto RecursiveDo, NamedFieldPuns,
  ScopedTypeVariables: `ghc/compiler/GHC/Driver/Flags.hs:267-278`);
- *one name, several features:* through the implications (GADTs sets GADTSyntax and MonoLocalBinds, P04b);
- *a name with no feature:* the inert names, which rhc accepts and nothing tests (D7), and the names of Report rules
  that rhc has on in its edition and cannot yet turn off (`ImplicitPrelude` until NoImplicitPrelude lands in track X);
- *a feature with no GHC name:* HierarchicalModules for `--dotted-names` and the two cycle settings (D8), set from the
  command line only.

jhc is the precedent for the many-to-one direction: ExplicitForAll, ExistentialQuantification, ScopedTypeVariables,
Rank2Types, RankNTypes and PolymorphicComponents all set jhc's one `FO.Forall` (`jhc/src/Options/Map.hs:56-74`; E5,
`others.md`). rhc may merge only names whose meanings coincide in rhc: jhc's merge gives ScopedTypeVariables' scoping
to a module that asked for ExplicitForAll, which one name, one semantics forbids [inferred].

**Features at M4** (E4's nine, less the two that D8 renames): Haskell 2010's DoAndIfThenElse, EmptyDataDecls,
ForeignFunctionInterface, HierarchicalModules, PatternGuards and RelaxedPolyRec; Haskell 98's NPlusKPatterns; and
rhc's two cycle settings. Each track X milestone adds its own (D35).

**The canonical form** is the set's feature names sorted and joined by commas, with no edition (E4's `canonical`).
It is sound only if every rule an edition changes is a feature, so that no stage needs the edition: that is an
invariant of the design, and a test of two spellings of one set holds it (*Testing it*; D9) [designed].

### Scope

*Status: prototyped (E4, `results/E4/permodule/`), at `RUNE_LINT=2`, by units and `--whole` alike in every case.*

- **Per module.** A module's setting is the program's command line and its own header. A 98 `Main` that uses n+k and
  imports a module headed `{-# LANGUAGE Haskell2010 #-}` that relies on 4.5.1 runs, printing `(True,True,120)`
  (`permodule/mixed/`, `results3.txt`) [measured].
- **Mixed settings inside one recursive unit.** The checker takes each binding under its own module's setting: in a
  cycle of A under RelaxedPolyRec and B not, each holding 4.5.1's example, only B's bindings are refused (R21's
  message at `cycle2/B.hs:7:1`); with both under it the program prints `(True,True,1)` (`permodule/cycle2`, `cycle3`;
  `results2-b6.txt`) [measured]. HsLint's rule must be the group's, not the binding's: where any module of a group is
  relaxed, every signed binding of the group has its signature in scope from the start, as the checker already had it.
  E13's edit test found the binding's rule failing on build 8, a cycle of a relaxed A and a 98 B refused at level 2,
  "rhc: lint after hslint: ./B.hs:5:7: hslint has no type for `A.a`" (`results/E13/README.md:13`; the refusals are
  `results/E13/edits-build8.tsv`, p03 steps 1 and 4, with an empty diagnostic: the message is in no kept file), which
  E4's cases had not met; build 9 fixed it (`anyRelaxed`, `patches/E13-language-record-b9.patch`) [measured]. Every
  per-module feature needs a mixed-cycle test in the checker and in HsLint (D10).
- **A cycle's own settings.** The fixpoint of a cycle's names and a cycle's one `default` belong to the cycle, so its
  modules must agree on them: "the modules of a cycle, A, B, differ on CycleDefaultScc, which is a cycle's setting",
  and with `--cycle-default=scc` for both they agree and the program prints `(1,3)` (`permodule/cycle`) [measured].
  Under D8 these settings come from the command line only, so the modules of a program always agree; the check stays
  for the day they get a pragma [inferred].
- **Per program:** the library and its language (D1), and the compile's modes. A module's edition pragma chooses its
  rules and never its library (D2): under `{-# LANGUAGE Haskell98 #-}` GHC too refuses `import Monad`, "Could not find
  module 'Monad'" (E5, P17e).

### Where each stage reads it

*Status: prototyped (E4): +470/-222 lines in 33 files, `rhc.plan` aside, and 226 lines in two new ones, 121 hunks in
all (counted in `patches/E4-language-record.patch`).*

| Stage | At the pin (*Where we are*) | With the record |
|---|---|---|
| Header pre-scan | none: a pragma is trivia (`lib/language/haskell/lexer.sml:109-124`) | new: the header's pragmas read from the unlit text before the lexer runs; E3's `HsLexer.headerPragmas` (71 code lines in `lexer.sml`, 106 with its plumbing: `results/E3/diffstat.tsv`) keeps each pragma's span, E4's `HsLanguage.pragmas` does not |
| Lexer | `{hierarchical : bool}` (`lexer_sig.sml:37`) | `{language}`; `foreign` reserved under ForeignFunctionInterface, dotted names under HierarchicalModules |
| Parser | `hierarchical` copied into the global `dotted` (`parser.sml:1587-1588`) | a `language` ref set at each parse, as `dotted` was: n+k under NPlusKPatterns, `if`'s semicolons under DoAndIfThenElse, an empty `data` under EmptyDataDecls |
| Graph | `dotted` for the program's modules (`src/rhc/graph.sml:230`) | where an import's file is looked for, by the importing module's HierarchicalModules |
| Names | `fixpoint`, an argument for the run (`src/rhc/names.sml:135`) | per cycle, by the members' agreement on the greatest-fixpoint feature (E4's `ofCycle`) |
| Checker | the refs `cycle` and `standard`, set per call (`infer.sml:2007-2010`) | each binding's dependencies by its module's RelaxedPolyRec (`languageOf` in `groupsOf`); `standard` from the library's descriptor; `cycle` per unit, by agreement |
| HsLint | `cycleDefault = false` on the units path (`src/rhc/driver.sml:300`) | by module and by group: `groupsOf` takes RelaxedPolyRec per binding, and where any module of a group is relaxed every signature is in scope from the start, as Typing Haskell in Haskell's `tiBindGroup` has it (E13's build 9) |
| Desugarer | `HsMatch.order`, a global (`match.sml:10`) | unchanged: no feature of M4 reaches it, and the match's order is a compile mode |
| Core simplifier | the library's prefix, `"haskell98"` (`coresimplify_fold.sml:145`) | the library's names through its options, from the descriptor |
| Driver | `extraOf`, the header's mode, the unit key (`driver.sml:172-183`, `:231-234`) | below, *The store* |

E4's HsLint took four changes for RelaxedPolyRec where the checker took one: its dependencies, the signatures in scope
first at the top level and in local declarations, and two places in the replay; without the signatures first, level 2
refused the mixed program, "hslint has no type for `A.g`" (E4, `agents/A-report.md` finding 7; the output was not
kept), and E13 a fifth, the group's rule above. Every feature that changes typing costs HsLint at least what it costs
the checker (D41). E13's build 9 is the prototype of record: +495/-222 tracked lines and 252 in the new files
(`results/E13/README.md`).

What the record removes [read in the patch]: every hard-coded `"haskell98"` in code (*Where we are*: 15 lines), and
the names of 98's role modules (Prelude, PreludeText, Ix, Ratio, PreludeBuiltin), which the descriptor gives; what
remains is the two descriptors, the 98 exception in `extraOf`, the option parser, the implicit `Prelude` import (a rule
of the language, not a library's name) and the test runner `tests/runner/hslibrary.sml`, which serves one library.

### The store (D9)

*Status: prototyped (E4); tested under edits (E13).*

- **The unit key** (`hs:` and the unit's name with each member's identity and text hash, `src/rhc/driver.sml:231-234`)
  takes each member's canonical set as well, written only when the set is not Haskell 98's own: a 98 key is the key
  of the pin. The other session's issue 27 adds ` literate` to the member's identity in the same place, and the two
  compose (`id ^ literate ^ languageKey`) (E4, `results/E4/other-session.md`).
- **The header's mode** (`module:MODE`, `src/rhc/driver.sml:183-184`) takes the program's base setting, the command
  line's, in place of `dotted`: the pragmas are a function of the text, which the hash already holds, and the base is
  all else that decides how the header is read. The pragmas are kept in the header's entry, and written only where a
  file has any, so the warm path stays a `stat` and 98's header entries keep their bytes.
- **The configuration** (`extraOf`) takes the library's name, except for `haskell98`, whose configurations are 98's.
- **The library is read under its descriptor's language,** so no `-X` flag and none of rhc's own options reaches it.
  E4's store runs: under `-XRelaxedPolyRec`, `--cycle-default=scc`, `--names=greatest` and `--language=haskell2010`
  the library's unit is taken from the snapshot, and under `-XRelaxedPolyRec` the program's module A is taken too,
  since its own `Haskell2010` pragma already gave that set, while `Main` is compiled again
  (`permodule/results3.txt`) [measured]. At the pin the first two forced a whole compile (`src/rhc/syntax.sml:142-154`).
- **One layer for both languages:** the Makefile's new rule made both into `bin/rhc.layer` in 43.2 s wall, 26.4 s user
  and 5.1 s system, 82,954,000 bytes against 98's 41,334,255 alone (`results/E4/cost.md`: the times from
  `logs/build6-layer.log`, the layer's size from build 5's `logs/build-layer.log:20`, 98's alone from A's report,
  reproduced in `results/verify/V2/numbers-c/snapshot-sizes.txt`) [measured].
- **Interfaces** need nothing for M4: a module's setting changes how it is checked, not the shape of what it exports
  (E4), and E13's importers, taken after every edit of a module they import, show it (below). HsIface takes a field
  only for content that depends on a feature: the user's order of a scheme's variables for TypeApplications, which
  `schemeOf` does not keep (`lib/language/haskell/infer.sml:578-601`; E6, X2), and a newtype's constructor visibility
  for the FFI, which D32 finds a unit's part already holds (D9).

**What E13 measured under edits** [measured: `results/E13/edits.tsv`, build 9; `edits.py`]. Ten programs of two to
four modules (a recursive unit beside other modules, a chain, a diamond, a literate module), 43 steps at `RUNE_LINT=2`:
pragmas added, removed and changed, editions changed by pragma, refused steps, an ordinary edit of an interface, the
base changed by `-X` and by `--language`. At every step the warm compile's bytes, or its diagnostics where both
refuse, equal the `--no-store` compile's: 43 of 43, each as expected.
- *What was made:* 47 units compiled, 50 taken and 1 only named, behind a failed one; the library's units taken from
  the snapshot in all 40 steps that made units (the report says 39).
- *The edited module's unit* is compiled again whenever its text or its set changes; in the cycle that is the whole
  unit of A and B.
- *Entries are shared* when the text and the set come back to an earlier state (p01, p02, p04, p05, p06, p09, p10);
  under `-XRelaxedPolyRec` or `-XNoNPlusKPatterns` on the command line, a module whose own `Haskell2010` pragma already
  gave that set is taken and only `Main` is compiled (p09).
- *`--language`* puts each library in configurations of its own, so a switch back and forth takes everything (p10).
- *Importers are taken* in every step that edited a module with importers and compiled, an added export included (p08
  step 3): a feature changes how a module is checked, not what its interface says, and an importer is judged by the
  usages it recorded.
- *98's output on build 9:* tests/hs/errors 633 of 633, tests/hs/accept 251 of 251, every tenth program of
  tests/hs/lang 120 of 120 bytecode files (`bytes9-*.log`).
- *What the edits are.* Every program but p10 runs in 98 mode throughout, and most edits put a feature's name in a
  module of a 98 program (`RelaxedPolyRec`, `NoRelaxedPolyRec`, `NoNPlusKPatterns` or `DoAndIfThenElse` in p01 to
  p06), which the prototype reads and the design's 98 rule drops (D6). The mechanism they test, keys that follow a
  module's set, is the same for a 2010 module, and the test rhc keeps moves those edits into modules that name
  `Haskell2010` [inferred].

**What E4 measured of 98 mode** [measured]:
- *98's snapshot, entry for entry.* Built by the prototype and by `75ed95861` at one `--share` path and one Main path,
  all 68 entries are equal, keys and bytes; only rhc's identity differs (`results/E4/snapshot-98-compare.txt`, build 4).
  The Makefile's two-language layer of build 6 against `75ed95861`'s 98 snapshot: the library's 32 entries of each
  match order equal, the snapshot's own `Main` differing by the path it was made at
  (`snapshot-98-compare-b6.txt`). An entry keeps the path it was read from at the pin; the other session's issue 9/31
  removes that (`results/E4/README.md`, *Snapshots*).
- *98's bytes, build 6:* tests/hs/lang 1,182 of 1,182 bytecode files (591 programs, both targets); tests/hs/errors 633
  of 633 diagnostics and statuses; tests/hs/accept 251 of 251; the check tier's corpus run, 198 compiles byte for
  byte and 52 refused tries alike (`bytes6-lang.log`, `bytes6-errors.log`, `bytes6-accept.log`, `bytes6-corpus.log`);
  210 of the 211 check-tier jobs of rhc's suites, the one failure `hs/names/imp/greatest`, which D8 asks the owner
  about (`logs/suites6.log`).
- *What those runs did not test.* No file of tests/hs/{lang,errors,accept} has a LANGUAGE pragma (grep at the pin),
  and the corpus harness blanks every LANGUAGE and OPTIONS pragma before rhc sees a program
  (`tests/runner/hscorpus.sml:195`, `tests/runner/hssource.sml:276-298`). So neither prototype's 98 identity met a
  pragma. The 98 rule needs a test of its own: the eight vendored originals of the run set that name LANGUAGE pragmas
  (`DatatypeContexts` in tcrun006 and tcrun029, `ConstrainedClassMethods` in tcrun037 and tcfail149,
  `ExistentialQuantification` in tcrun004, `GeneralizedNewtypeDeriving` in tc159, `CPP` in nofib's
  `common/NofibUtils.hs`, `BangPatterns` in `shootout/pidigits`) and the three whose OPTIONS carry GHC flags (rn039's
  `-fwarn-name-shadowing`, `-fglasgow-exts` in hartel's `Fast2haskell.hs` and `Fast2haskell2.hs`) (grep of
  `tests/hs/corpus/vendored`), compiled unblanked in 98 mode, must give the bytes of their blanked copies
  [designed]. E4's prototype refuses an unknown name in a 98 module (E13, `combo/results.txt`, `Unknown98.lhs`) and
  would refuse the eight [inferred from its code, not run]: it raises `Unknown` for any name outside its features, in
  98 modules too (`language.sml`'s `apply`). E3's spike reads only the edition in a 98 module
  (`patches/E3-07-pragma.patch`, `languageOf`), which is the design.
- *Merging.* On `haskell98`'s tip of 2026-11-21, 12 of the patch's 121 hunks are rejected, in `src/rhc/driver.sml`
  (4), `hslint.sml` (3), `src/rhc/graph.sml` (2), `hslint_env.sml`, `src/rhc/names.sml` and `src/rhc/syntax.sml`
  (1 each), where the other session's store work landed (`other-session.md`). M4 is written on that driver.

### Unknown, unsupported and combination errors (D7)

*Status: unknown names prototyped (E3, E4) and placed at the name (E13); the combination table drafted by E13
(`results/E13/combinations.md`), one row prototyped; the classes designed.*

Chapter 12: "If a Haskell implementation does not recognize or support a particular language feature that a source
file requests (or cannot support the combination of language features requested), any attempt to compile or otherwise
use that file with that Haskell implementation must fail with an error." (12.3, T10:10989-10990). The chapter's other
rule, that unrecognised pragmas "should be ignored" (T10:10928), is for a pragma rhc does not know, not for a LANGUAGE
pragma's feature (*What the 2010 Report says*, N5).

A name is one of four:
- **Supported:** it sets features rhc implements.
- **Inert:** accepted, and it sets no feature of its own: ParallelArrays, AutoDeriveTypeable, TypeInType, the No form
  of JavaScriptFFI, ImplicitStagePersistence, whose effect in GHC is their implications or nothing (E5,
  `semantics.md` section 1); and a name whose rule is already on in the edition, RelaxedPolyRec in 2010. Its
  implications are steps like any others: ParallelArrays turns ParallelListComp on (E6 recommends it now, T0), and
  TypeInType turns on KindSignatures, which rhc will have, and DataKinds and PolyKinds
  (`ghc/compiler/GHC/Driver/Flags.hs:311-313`), which it will not, so by C4 below the setting stands and a construct of
  those two is refused where it is written [designed]. Trustworthy and Unsafe are markers rhc accepts (E6, rec now).
  E13's model counts TypeInType and AutoDeriveTypeable as not supported, by their census rows (`predictions.tsv`, P08i,
  P08l), where this list, the lead's, has them inert.
- **Not supported:** a name of the table that rhc does not implement, GHC2021 and GHC2024 among them: an error, "not
  supported by rhc", never a silent acceptance. Safe is one until rhc has its import checks (E6, `later-other`); two
  different Safe Haskell modes are an error, as GHC's "Incompatible Safe Haskell flags! (Safe, Trustworthy)" (P16a;
  `combineSafeFlags`, `Session.hs:578-585`).
- **Unknown:** not in the table; an error with the near names, as GHC's "Unsupported extension" lists the supported
  ones (`PsErrUnsupportedExt`, `Header.hs:465-467`; P09a). On the command line it is a usage error before any file is
  read, "no language or extension FooBar that rhc knows" (E4, `permodule/results3.txt`); in a pragma, an error at
  the name's own line and column. E4's build 6 said "Unknown.hs: error: ..." in a compile; E13's build 8 says
  "Unknown.hs:3:14: error: the language `FooBar`, which rhc does not know (a LANGUAGE pragma: 12)" in a compile, under
  `--whole` and in the views, and "Unknown98.lhs:3:16" through unlit (`results/E13/combo/results.txt`) [measured].
  Every language error is said so.

In a Haskell 98 module none of these arises from the header: its names are not read (the 98 rule). From the command
line they arise in either mode.

**Combinations.** rhc's own table, new, since GHC refuses none when it reads flags. E13 drafted it over D35's 72
recommended names and rhc's own switches (`results/E13/combinations.md`):

| # | Combination | rhc |
|---|---|---|
| C1 | two Safe Haskell modes, Trustworthy with Unsafe | refused, as GHC (P16a, P16b, P16g) |
| C2 | the modules of one recursive unit differing on a cycle's setting (the cycle default, the names' fixpoint) | refused at the first module's header (E4, `permodule/cycle`) |
| C3 | HierarchicalModules off in a program whose library has hierarchical names (2010's) | refused at the name: "NoHierarchicalModules, with a library whose module names are hierarchical (haskell2010), which this module could then not import: a combination rhc cannot support (12)" (`combo/results.txt`, `NoHier.hs:3:31`); under 98's library the same file runs |
| C4 | a recommended feature that implies one rhc does not support (TypeOperators implies ExplicitNamespaces; StandaloneKindSignatures, NoCUSKs) | the policy: the setting stands, and the unsupported construct is refused where written, naming both |
| C5 | a feature with what it implies turned off after it (`-XRankNTypes -XNoExplicitForAll`, FunctionalDependencies with NoMultiParamTypeClasses, Strict with NoStrictData) | accepted, as GHC; the construct refused, the message naming both (GHC: "Illegal symbol 'forall' in type", P07d) |
| C6 | GeneralizedNewtypeDeriving with DeriveAnyClass | accepted, as GHC, with its warning |
| C7 | NegativeLiterals with LexicalNegation | accepted, as GHC |
| C8 | NoRelaxedPolyRec in a 2010 module | the owner's: inert with GHC's warning (recommended), or 98's 4.5.1 in that module |
| C9 | an edition pragma unlike the program's library | accepted (D2) |
| C10 | CPP in a literate file | D12's: unlit, then CPP, as GHC |
| C11 | ForeignFunctionInterface under 98's library | accepted; a type only Foreign.\* defines is not in scope where written |
| C12 | features mixed by module inside one unit | accepted (D10) |

So the refusals proper are three, and C4 is the line that keeps them few: refusing the setting would refuse every
TypeOperators module, which D35 recommends now. C3 cannot be written in the design, since HierarchicalModules has no
LANGUAGE or `-X` name (D4, D8); it stands as a guard against a way to turn it off. The table is held both ways, as the
conformance table is: each refusal has a program that must fail with its message, and every pair of supported features
it does not refuse must resolve and compile a small module with both on (*Testing and conformance*, *Tests of the
tracking design*, item 3).

### Diagnostics that name the extension (D11)

*Status: measured on GHC (E5); prototyped for n+k (E4); designed.*

- **GHC.** Of 37 diagnostic probes under `-XHaskell2010`, 35 are refused, and 26 of the refusals name the extension
  that would accept the construct, in five phrasings ("use TupleSections", "Perhaps you intended to use LambdaCase",
  "You need DeriveFunctor", "Enable MultiParamTypeClasses to", "requires GHCForeignImportPrim"). The other 9 are all
  decided in the lexer, which made other tokens, so the parser saw a plain parse error: capi, interruptible,
  ExtendedLiterals, MagicHash, UnboxedTuples, UnboxedSums, parallel arrays, a foreign import under `-XHaskell98`, and
  `javascript` off its platform (`results/E5/probes/diag-names.tsv`). One names the wrong extension: `forall` under
  Haskell2010 suggests RankNTypes, not ExplicitForAll (D-scoped). GHC's hints have three shapes, one extension, any of
  several, all of several, and a fourth for a known fix (`SuggestSingleExtension`, `SuggestAnyExtension`,
  `SuggestExtensions`, `SuggestExtensionInOrderTo`: `ghc/compiler/GHC/Types/Hint.hs:63-99`).
- **rhc at the pin** names no extension: it refuses a construct in the Report's terms, "expected `then` after the
  condition of `if`, found a new line at the indentation of its layout block" (`permodule/results3.txt`, DoIf.hs in
  98). E4's prototype names the edition and the feature: "an n+k pattern, which Haskell2010 does not have
  (NPlusKPatterns is off)" [measured].
- **The design.** A refusal of a construct that a feature would allow names the feature, the edition that has it
  where one does, and both ways to turn it on (a pragma, `-X`); the names are rhc's table's, so a hint never names a
  feature rhc does not support without saying so. A hint is added only on a path that already fails, so diagnostics
  never change what is accepted. Where an extension's token cannot occur in a valid program of the module's setting
  (`\case`, a tuple section, `foreign import` in a 98 module), the lexer may read it whatever the setting and the
  parser refuses it with the hint; where it can (`a#b` with a user's `#`, `(# 1)`, `static = 1`, `[e|e<-xs]`: E5,
  P14a-P14i), the lexer follows the setting, and any hint is a guess on the parse error that follows [designed].
- **In 98 mode** messages keep their bytes: tests/hs/errors pins 633 refusals (E4). The hints are for modules under
  2010, unless the owner re-pins 98's messages (D11).
- **Warnings.** rhc prints none at the pin: neither `src/rhc` nor `lib/language/haskell` has one [read: grep]. The
  design adds three, in 2010 modules only: a LANGUAGE pragma after the header, ignored ("Misplaced LANGUAGE pragma",
  GHC's `-Wmisplaced-pragmas`, `Header.hs:312-322`; P10a); an OPTIONS_GHC flag rhc ignores; a deprecated name
  written (`ghc/compiler/GHC/Driver/Flags.hs:112-124`, `:273-278`). They go to standard error in the form of rhc's
  errors, and the 2010 tests pin them.

### The printers and round trips

*Status: the loss measured (E3); the fix designed (D6).*

The explicit and implicit prints emit no trivia (`lib/language/haskell/print.sml:129-139`); only the exact print does
(`:65-66`). A pragma is trivia (`lexer.sml:112`), so `--print` and `--print-layout` drop the header's pragmas, and with
them the module's language: E3 printed its `programs/pragma1.hs` (a header of `{-# language Haskell2010 #-}` and two
more pragmas, then an empty `data` and a pattern guard) and 98 mode refused the print (E3, `agents/F-report.md` item
7; no result file keeps the print). `--print-exact` gives every parseable 2010 program back byte for byte, `.lhs`
included (E3).

So both printers print the header's LANGUAGE and OPTIONS pragmas as written, before `module`, in both modes; a module's
own steps then survive a print, and the command line's, which are not the file's, do not. The round trip reparses the
print with no `--language`, so the header alone sets the module's language, and its tree command prints the module's
resolved setting, so a printer that drops or reorders a pragma fails it (*Testing and conformance*, *Round trips*).
That setting needs a view: `--dump-language`, the edition, the set and each step with where it was written, one line a
module [designed: no such view at the pin]. Printing the pragmas changes 98 mode's `--print` of a file that has them;
no test file of tests/hs outside the corpus has one, and the round trip's token test reads no trivia (D6).

### CPP's place

*Status: GHC measured (E5, E3); designed for rhc, if D12 takes CPP.*

GHC unlits, reads the header, runs cpp if CPP is now on and reads the header of its output again, then runs any `-F`
preprocessor and reads it once more (`preprocessPipeline`, `ghc/compiler/GHC/Driver/Pipeline.hs:709-742`). So a pragma
inside `#if 1` counts and inside `#if 0` does not (P13a, P13b); a macro expands inside a LANGUAGE pragma (P13d); and CPP
must be on before the first `#` line, since a `#if` before `LANGUAGE CPP` ends the header and fails to parse, "parse
error on input '#'" (P13c), where `-XCPP` or `OPTIONS_GHC -cpp` works (P13e, P13f). CPP is the one extension known only
from the text it governs (E5, `semantics.md` section 9).

rhc, under D12's A:
1. unlit; read the header (CPP is on if a pragma before the first `#` line names it, or `-XCPP`, or OPTIONS_GHC's
   `-cpp`);
2. if CPP is on, run rhc's preprocessor over the unlit text, blanking every directive line and every line a
   conditional skips, so that every line keeps its number (E3: `cpp -traditional -P` takes 122 lines to 82,
   `results/E3/cpp/lines.tsv`);
3. read the header of the output again, from the command line's setting, the second read replacing the first;
4. lex the output under the setting.

GHC's second read starts from the first read's flags (`T_FileArgs hsc_env1 cpp_fn`, `Pipeline.hs:719-724`), so the
header's steps are applied twice; replacing the first read gives the same set wherever the steps are idempotent, which
every case in E5 is [inferred]. The first read's warnings are dropped once the second is made: before the
preprocessor runs, a LANGUAGE pragma after a `#if` line looks misplaced (E13 found this in its model, P13a, P13d,
P13f). The header's entry in the store keeps the second read's names. The macros defined on rhc's command line and
each `#include`d file's hash enter the unit's key [designed]. In a Haskell 98 module `CPP` in a
pragma is dropped by the 98 rule, as today, and `-XCPP` on the command line runs it. If D12 is cut, CPP is "not
supported by rhc" (D7).

### Testing it

*Status: designed; E13 ran the model against the probes and the store under edits on the prototype.*

*Testing and conformance* holds the tests: E5's 137 probes as rhc's tests of resolution, with each probe rhc answers
otherwise naming its decision (GHC2021 as the default and as an edition, CPP, Safe Haskell, conservativity); a test per
name of the table; the combination table both ways; E5's 35 refusals for diagnostics; E3's `--dotted-names`
reproducer generalised to every feature that changes how a text is read; E4's per-module cases; E3's header shapes
(*Tests of the tracking design*, items 1-7). Two belong to this design and are added here:
- **The 98 rule:** the eleven vendored originals above, unblanked, compiled in 98 mode, give the bytes of their
  blanked copies; and a 98 file headed `{-# LANGUAGE BangPatterns #-}` compiles as it does at the pin.
- **The store under edits:** E13's cases (`results/E13/edits.py`), made a test of rhc's runner, since a live script
  needs an owner: 10 programs, 43 steps, each warm compile's bytes or diagnostics equal to the `--no-store` compile's,
  the edits that name a feature moved into 2010 modules (*The store*, above); with three cases E13 lacks: two
  spellings of one set giving one key (an alias, an implied feature written out), a mixed cycle for each per-module
  feature in both checkers (D10), and an `#include`d file edited once CPP lands.

## The foreign function interface

**Chapter 8 is required, and Rune's FFI carries most of it.** Rune's libffi bridge gives rhc static calls, function
pointers and callbacks. E10's prototype ran all four kinds of `ccall` import through a family of Core primitives
over the VM's `foreign` and `foreign_callback`: `math.h sin`, an IO import, an `&` import called through a `dynamic`
stub, and qsort with a Haskell comparator made by `wrapper`. The optimiser dropped, duplicated and reordered no IO
call, and kept pure imports lazy and strict in their arguments, at every level. Callbacks nest, carry exceptions back
through C, and report `<<loop>>` on a blackholed suspension.

What does not fit is Rune's model of memory and of entry. Rune's pointers are opaque identities, never addresses. It
has no finalizer and no weak reference. A callback can run only while a foreign call is active on the owning thread,
and nothing lets C enter a bytecode program. E10 set the Report's requirements against that model in 36 rows:
- 20 need no change to Rune, and 3 a workaround in rhc;
- 5 need a small change and 2 a medium one;
- 2 are large: `foreign export` and HsFFI.h;
- 4 are large under one option and cheaper, or a stated deviation, under another: raw addresses (D29), `ptrToIntPtr`
  with them, collector-driven finalizers (D30), and callbacks when no call is active (D31).

The decisions are D27 to D33. D28's recommendation leaves a required feature out of this roadmap, so it stands only on
the owner's explicit word.

Writing this section found a contradiction in the text: by 8.4.2's visibility rule, Foreign.C.Types' own export list
makes `CInt` unmarshallable outside that module (*What chapter 8 requires*, last item).

### What chapter 8 requires

*What the 2010 Report says* gives the chapter's place in the delta and its lexical changes (Δ1: `foreign` reserved,
the convention names special only inside a foreign declaration) and its readings (N1). What binds a runtime:

- **One calling convention.** "Any implementation of the Haskell FFI must at least implement the C calling convention
  denoted by ccall. All other calling conventions are optional." (8.4.1, T10:6828-6829). `stdcall` is defined: "The
  specification of external entities under the stdcall calling convention is identical to that for standard C calls.
  The two calling conventions only differ in the generated code." (8.5.2, T10:7180-7181). `cplusplus`, `jvm` and
  `dotnet` are names only: "Only the semantics of the calling conventions ccall and stdcall are defined herein"
  (T10:6833).
- **Four kinds of import** (8.5.1). The entity is `" [static] [chname] [&] [cid] "`, `" dynamic "` or `" wrapper "`
  (T10:7036-7038).
  - **A static function** may have any foreign type, IO or not. "If a function that is not pure is not imported in the
    IO monad, the system behaviour is undefined." (T10:7088-7089).
  - **A non-functional type** is still a call: `foreign import ccall foo :: CInt` "refers to a pure C function foo with
    no arguments" (T10:7064-7066).
  - **A missing `cid`** defaults to the Haskell variable's name (T10:7044-7045).
  - **A header** has "no impact on the semantics of a foreign call" (T10:7134).
  - **An address (`&`)** has the type `Ptr a` or `FunPtr a` (T10:7095-7096). A C variable imported so "can be read and
    updated using the routines provided by the module Foreign.Storable" (T10:7071-7072). The chapter's own example is
    `foreign import ccall "errno.h &errno" errno :: Ptr CInt` (T10:7103).
  - **`dynamic`** has the type `(FunPtr ft) -> ft` (T10:7106-7107).
  - **`wrapper`** has the type `ft -> IO (FunPtr ft)` (T10:7114-7115). Its storage "should be released with
    Foreign.Ptr.freeHaskellFunPtr when no longer required" (35.2, T10:15641-15642).
- **Marshallable types** (8.4.2).
  - **Basic types:** "Char, Int, Double, Float, and Bool as exported by the Haskell Prelude", and "Int8, Int16,
    Int32, Int64, Word8, Word16, Word32, Word64, Ptr a, FunPtr a, and StablePtr a, for any type a" (T10:6862-6865).
  - **Type synonyms** of a marshallable type.
  - **A newtype** `T`, provided "the constructor N is visible where T is used" and its field is marshallable
    (T10:6905-6909). "Consequently, in order for a type defined by newtype to be used in a foreign declaration
    outside of the module that defines it, the type must not be exported abstractly." (T10:6910-6911).
  - **A result** may also be `()` or "a type matching Prelude.IO t, where t is a marshallable foreign type or ()"
    (T10:6916-6917), and newtypes and synonyms of either.
  - So `Integer`, `String` and data types are refused.
- **Strict, and pure when asked.** "External functions are strict in all arguments." (T10:6892). A pure import
  "asserts that the external entity is a true function" (T10:6948). When such a call runs, and how often, the text
  does not say (N1).
- **Callbacks during a safe call** (8.4.3). "A safe call is less efficient, but guarantees to leave the Haskell system
  in a state that allows callbacks from the external code. In contrast, an unsafe call, while carrying less overhead,
  must not trigger a callback into the Haskell system. If it does, the system behaviour is undefined. The default for
  an invocation is to be safe." (T10:6956-6959).
  - A callback "implies that a garbage collection might be triggered after an external entity was called, but before
    this call returns" (T10:6959-6960), so only stable pointers stay put (T10:6960-6961).
  - The chapter says nothing of a callback after the call has returned. A `wrapper`'s pointer lives until
    `freeHaskellFunPtr` releases it (T10:15672-15676), so C may keep it.
- **`foreign export`** (8.4.4). The exported `v` "may be a value, field name, or class method that is declared on the
  top-level of the same module or imported", at an instance of its type (T10:6969-6973). "If an evaluation triggered
  by an external invocation of an exported Haskell value returns with an exception, the system behaviour is undefined."
  (T10:6980-6981).
- **HsFFI.h** (8.7).
  - **Contents:** the types and limits of Tables 8.2 and 8.3 (T10:7272-7276), and the prototypes of `hs_init`,
    `hs_exit`, `hs_set_argv`, `hs_perform_gc`, `hs_free_stable_ptr` and `hs_free_fun_ptr` (T10:7418-7428).
  - **Re-initialising:** the Haskell system "may be de-initialised with hs_exit() and be re-initialised with hs_init()
    at a later point in time" (T10:7437-7438). GHC does not support that (N1).
  - **Null:** `nullPtr` and `nullFunPtr` map to C's `NULL` "and vice versa" (T10:7407-7409).
- **What the libraries ask of a runtime** (chapters 24 to 37). *The libraries* covers the 14 modules; these are the
  items that reach Rune.
  - **Ptr** (35.1): Eq, Ord and Storable instances (T10:15576-15579), `plusPtr`, `alignPtr` and `minusPtr` on
    addresses (T10:15594-15605).
  - **IntPtr and WordPtr** are "losslessly converted to and from Ptr" (35.3, T10:15684).
  - **ForeignPtr's finalizers** (29.1.1). A finalizer is "a pointer to a foreign function" (T10:14955). It "will be
    executed after the last reference to the foreign object is dropped. There is no guarantee of promptness, however
    the finalizer will be executed before the program exits." (T10:14966-14967).
  - **StablePtr** (36.1): a stable pointer "will neither be deallocated nor will the value of the stable pointer
    itself change during garbage collection" (T10:15749-15751). It casts to and from `Ptr ()` (T10:15777-15786).
  - **Memory** (31.1): `free` frees what `malloc`, `realloc`, `new` and the C string functions allocated
    (T10:15193-15197). `finalizerFree` is "a foreign function equivalent to free" (T10:15203-15205). "If any of the
    allocation functions fails, a value of nullPtr is produced." (T10:15125).
  - **errno:** `getErrno :: IO Errno` (26, T10:14116).
- **Foreign.C.Types contradicts the rule it is said to follow.**
  - **The claim:** "The module Foreign.C.Types that defines the Haskell equivalents for C types follows this
    convention" (T10:6911-6912), that is, it does not export its newtypes abstractly.
  - **The export list** says otherwise. It reads `CChar, CSChar, CUChar, CShort, CUShort, CInt, ...` with no
    constructors (T10:14480-14485). The chapter calls the types newtypes (T10:14521) but shows each as `data CChar`
    (T10:14523).
  - **Read literally,** `CInt` is then no marshallable type outside Foreign.C.Types. The chapter's own examples
    would be refused: `cstrlen :: Ptr CChar -> IO CSize` (T10:6936-6937) and `sin :: CDouble -> CDouble`
    (T10:6945-6946) [inferred].
  - **The sources disagree too.** base 4.3.1.0, the base of record (E9), exports the types abstractly under GHC
    (`Foreign/C/Types.hs:31-37` in E9's download). GHC 9.14.1 checks visibility
    (`compiler/GHC/Tc/Gen/Foreign.hs:120-123`, `:198-204`) and exports the constructors
    (`libraries/ghc-internal/src/GHC/Internal/Foreign/C/Types.hs:43-48`).
  - **What rhc should do:** its 2010 Foreign.C.Types exports the constructors, on the "contradictory" ground, and the
    owner reviews it. D32's visibility check and D23's literal export lists must agree on this point. It belongs in
    *Found while writing this roadmap*.

### Chapter 8 against the FFI Addendum

E11 compared the Addendum (FFI 1.0, 2003) with chapter 8 sentence by sentence (`results/E11/ffi/ch8.summary.txt`).
The Addendum has 245 sentences and chapter 8 has 261. Of the Addendum's sentences:
- 202 are the same;
- 25 changed;
- 18 are only in the Addendum.

39 sentences are only in 2010. The script matches each Addendum sentence to its best 2010 sentence, so the 227 it
calls the same or changed land on 222 distinct 2010 sentences. Five 2010 sentences take two each, four of them
fragments of Table 8.3 (`ch8.tsv`).

The changes in substance are four. *What the literature says* has the quotations and the Haskell' rationale.
- **A newtype is marshallable only where its constructor is visible** (T10:6905-6911). The Addendum allowed any
  "renamed datatype of a marshallable foreign type". This is the rule rhc's checker needs scope for (D32), and the
  Foreign.C.Types contradiction above comes from it.
- **A result may be a newtype or synonym of a result type** (T10:6920-6924), so a newtype over `IO` is a valid
  result. The prototype's checker already unfolds a newtype to `IO` (`resultOk` in the patch's `infer.sml`) [read].
- **"generally" is gone** from "External functions are generally strict in all arguments" (T10:6892). D32 forces
  every argument before the call.
- **Thread-local state is "implementation-defined"** (T10:6680-6682). That leaves a single-threaded rhc free (D31).

In the libraries, `unsafePerformIO` became `Foreign.Marshal.unsafeLocalState` (T10:15091-15100). An alignment
guarantee was added. IntPtr, WordPtr, `finalizeForeignPtr` and `withArrayLen` are new (line counts in both texts:
`results/E11/ffi/lib-counts.tsv`).

### What Rune's FFI provides

Rune's FFI is the runeffi roadmap, M0 to M10 complete (`docs/plans/runeffi.md:18-30`). rhc reaches it only through
Core primitives. 98's D26 A, the owner's, puts no SML below Haskell, so rhc cannot call RuneForeign's SML.

- **Two trusted primitives.**
  - **`foreign`** has five arguments: operation, resource, extent, metadata and bytes. **`foreign_callback`** roots a
    closure and prepares a libffi closure (`runtime/prims.def:470-471`).
  - **Both have the effects "anything"** (`src/isa/prims.sml:872`), so no Mid pass drops or moves them.
  - **RuneForeign** is the SML bridge over them (`lib/basis/rune_foreign_sig.sml:7-193`):
    - `openLibrary` and `symbol`;
    - `allocate`, and `read`, `write` and `view` on memory;
    - `prepare`, with ABI 0 for the target default and ABI 1 for "Windows x86 stdcall", and `prepareVariadic`;
    - `callback`, `invoke` and `invokeDeferred`;
    - `sameAddress`, `release` and `live` (`:49-79`, `:91`, `:106`, `:131-143`, `:179-192`).
- **Scalars:** "fixed signed/unsigned 8/16/32/64-bit integers, float, double, void results and pointers"
  (`docs/ffi/runtime.md:51-53`). Errors are "captured immediately after `ffi_call`", errno among them
  (`docs/ffi/runtime.md:106-108`).
- **Resources are identities, never addresses.**
  - **The rule:** "SML contains identities and liveness tombstones, never native addresses"
    (`docs/ffi/runtime.md:77-78`). The roadmap made it a rule: "Native addresses are held outside the SML heap,
    rather than cast to SML integers" (`docs/plans/runeffi.md:465-467`).
  - **Bounds:** Rune's own allocations are bounds-checked (`runtime/foreign.c:301-312`).
  - **Pointers from C:** a pointer C returns that is not inside a Rune allocation gets the extent `SIZE_MAX`
    (`runtime/foreign.c:693`), as a callback's pointer argument does (`:528`). "Releasing a pointer identity alone
    never frees native-owned storage." (`docs/ffi/runtime.md:96`).
  - **Comparison:** `sameAddress` compares two identities' addresses without exposing either
    (`lib/basis/rune_foreign_sig.sml:173-179`). Nothing orders them, takes their difference or aligns them.
- **Callbacks are confined to a call.**
  - **When:** entry from "another thread, or entry outside a native call belonging to the context, returns the
    annotated native failure value without executing SML" (`docs/ffi/callbacks.md:9-12`).
  - **How:** a callback runs in "an explicit bounded interpreter scope" with no JIT: "A maximum of 64 nested callback
    scopes bounds growth of the C stack" (`docs/ffi/callbacks.md:28-37`; `runtime/callback.c:12`).
  - **Exceptions:** RuneForeign's SML wrapper catches an escaping exception, keeps it for the call around it, and
    re-raises it "only after native control has returned" (`docs/ffi/callbacks.md:58-64`). The VM itself does none of
    this. `vm_raise` pops the next handler (`runtime/runtime.c:268`, `:300`), which may belong to the frames parked
    below the callback. `vm_callback_apply` notices a lost handler only after a normal return (`runtime/callback.c:44`).
  - **Other threads:** foreign-thread and asynchronous entry "remain outside the delivery contract"
    (`docs/ffi/callbacks.md:91-94`).
- **What is absent.**
  - **No finalizers:** "No finalizer or new heap object kind is a prerequisite for this roadmap"
    (`docs/plans/runeffi.md:471`). `runtime/prims.def` has no weak or finalizer primitive.
  - **StablePtr:** the VM's handles are C only (`runtime/vm.h:693-697`).
  - **No entry from C:** no embedding API, and no symbol exported from a bytecode program. `runeopt` targets Linux on
    x86-64 alone (`docs/native.md:3-4`).
  - **Images and fork:** refused "with `EBUSY`" while foreign resources live (`docs/ffi/runtime.md:115-116`).
- **Targets.**
  - **Required evidence:** runeffi names Linux x86-64, Windows x86-64 and x86, Linux x86, AArch64 and big-endian
    PowerPC64 (`docs/plans/runeffi.md:427-433`).
  - **On AArch64 and PowerPC64** plain `char` is unsigned (`docs/ffi/portability.md:59-61`). "There is no native
    `runeopt` or GUI acceptance claim for these targets" (`:53-54`).
  - **On h10-v,** libffi is in: `available true`, x86-64, 8-byte pointers, `stdcall false` (E10,
    `probe/avail.out`).
- **rhc's side.**
  - **The family rule:** a family of Core primitives "takes arguments of `!Int`, `!Str` and `!Bool`"
    (`lib/language/haskell/coreprimfamily_sig.sml:9-11`). The families today are io and sys
    (`lib/language/haskell/coreprim.sml:119`).
  - **Types:** Core has no Word, IntN or WordN type (`lib/language/haskell/coreprim.sml:47-116`). Mid has
    `Int64.int` and `Word64.word` (`lib/compiler/elab/types.sml:86-87`).

### What the prototype showed (E10)

**The shape.** The patch is `patches/E10-ffi-prototype.patch`, 846 lines added and 4 deleted, against `75ed95861`.
Every program was compiled whole on h10-v at `RUNE_LINT=2`, so HsLint, CoreLint and Mid's lint accepted each one.

| File | Added | What it does |
|---|---:|---|
| `parser.sml` | 25 | reads `foreign import CONV [SAFETY] ["ENT"] v :: t` as the binding `v = (primForeign "CONV" "ENT" :: t)`, so the renamer, the checker and HsLint see an ordinary binding |
| `infer.sml` | 73 | 8.4.2's structural check at that signature, and a wrapper's `ft -> IO (FunPtr ft)` |
| `desugar.sml` | 326 | `ffiImport`: the binding's Core, written as Core text and parsed; each argument forced through its newtypes and encoded; a static call's identity a top-level CAF `v%ffi` |
| `coreprimffi.sml` (new) | 218 | 17 primitives `ffi_*`, each a Mid function over `foreign` (operations 1 to 10 and 13) or `foreign_callback`, speaking RuneForeign's wire protocol |
| `share/rhc/haskell98/Foreign.hs` (new) | 200 | a sliver of Foreign.*: Int8 to Word64, Ptr and FunPtr as newtypes of Int; CInt, CSize, CChar, CDouble, CString; malloc, free, peek and poke of CInt |
| `core.build`, `coreprim.sml`, `rhc.plan` | 4 | registration |

Sizes from `git apply --numstat`. The Foreign module lives in the 98 library, for want of a 2010 one.

**All four kinds of import work** (E10, `Basic.hs`).
- Pure imports: `c_sin 0.5` gives 0.479425538604203, and `c_pow 2 10` gives 1024.0.
- `abs` through CInt, a newtype of Int32 that is itself a newtype of Int, gives 42.
- `puts` takes a CString marshalled by hand; `srand` and `rand` are IO imports.
- qsort with a `wrapper` comparator gives `[1,2,3,5,7,8,9]`.
- An `&qsort` import called through a `dynamic` stub with a descending comparator gives `[9,8,7,5,3,2,1]`.

`matrix.tsv` runs 11 programs at -O0, -O1, -O2 and on the stack target: 41 runs. Each program printed the same at every
configuration, except that Gaps.hs's text names the stack VM's binary on that target, and except FreeClash, which frees
Rune's allocation with C's `free` and Haskell's: status 0 at -O0, 134 in glibc at -O1, -O2 and on the stack target
(G19). A second run of every binary
printed the same again. Compiled a unit at a time, Basic printed the same (`out/units.log`).

**The optimiser keeps every IO call and every pure call's laziness** (E10, `Opt.hs`).
- **The probe:** each observation is a line C's `puts` writes.
- **Configurations:** stdout is identical (md5 `5c70abe1`) at seven: -O0, -O1, -O2, -O2 `--no-cheap-eagerness`, -O2
  `--eta=ghc`, -O2 `--strictness=off`, and the stack target.
- **IO calls:**
  - three calls come out A, B, A;
  - an action bound once and run twice runs twice;
  - an action never run, or only `seq`'d, does not run;
  - results discarded by `>>`, or bound and unused, still run.
- **Pure calls:**
  - a `let` that is not demanded does not call;
  - an argument that `pick` does not demand is not called;
  - a `let` used twice calls once;
  - a loop of three calls three times, so nothing floated the call out;
  - `c_abs (error ..)` applied but never demanded raises nothing.
- **Strictness:** when the call is demanded, the argument's error comes first: ErrorCall, status 1, at every
  configuration (`Strict.hs`).
- **The simplifier did real work** at -O2: 216 declarations became 40 (`out/Opt.O2.simplify-stats.txt`). The import
  wrappers were inlined into `main`, and 7 `prim ffi_call` sites remain (`out/Opt.O2.core-simplify-2.txt`).
- **Cheap eagerness** cannot make a foreign call eager. Its whitelist names arithmetic, comparisons and conversions
  only, and `ffi_*` are not on it (`lib/language/haskell/coresimplify_cheap.sml:50-61`, `:113`) [read].

**Callbacks** (E10).
- **Nesting:** inside qsort's comparator, a pure `bsearch` makes a nested foreign call with a nested callback, and
  works (`Nested.hs`).
- **The blackhole:** a comparator forcing the very suspension whose evaluation made the call gives `rhc: bottom:
  NonTermination: <<loop>>` at every configuration (`Loop.hs`). The VM's blackhole raises Loop, the trampoline keeps it,
  and the call raises it.
- **Exceptions:**
  - an ErrorCall in a comparator surfaces after qsort returns (`Boom.hs`);
  - an IOError raised in a callback is caught by `catch` around the call, and later calls work (`Catch.hs`);
  - raised 70 times from a callback, all 70 came back through the call, and callbacks still worked afterwards
    (`Escape.hs`).
  - Had one escaped past qsort's C frames, the VM's callback depth would have stayed raised. After 64 escapes entry
    would be refused, so no exception would come [inferred from `runtime/callback.c:12`, `:26`, `:54`].
  - The same holds with the wrapper in another module, compiled a unit at a time (`out/TwoUnits70.units.stdout`). The
    pending-exception cell, a global of the family's Mid text, is one per program because a program's units become
    one Mid at link (`docs/rhc.md:55-61`).
- **The trampoline is mandatory.**
  - The VM trusts the closure it roots never to raise (above).
  - So rhc's Mid wrapper, `gffWrap`, catches every exception, Loop among them, and returns the failure value. The call
    raises the exception once native control is back.
  - Once an exception is kept, later callbacks in that call return the failure value without running Haskell, as
    RuneForeign's wrapper does.
- **Callbacks outside a call are refused silently** (`Later.hs`).
  - An `on_exit` handler runs after `main`, and a SIGALRM handler fires while Haskell code spins. Neither ran Haskell,
    and the program ended with status 0.
  - That the signal was delivered rests on the spin outlasting the alarm's second: SIGALRM's default action would have
    killed the process [inferred; no time was recorded].

**The marshallability check** (E10).
- **Refused:** a data type, `String` (seen as `[Char]`), `IO Box` and `Integer`, each with an error at its line.
  Accepted: a newtype of a newtype of CInt, and `CInt -> IO CInt` (`out/Marshal.compile`).
- **Visibility is not checked.** `Visible.hs` imports `c_secret :: Secret -> Secret` although `Abstract` exports
  `Secret` abstractly, and it ran (`out/Visible.stdout`).
  - The checker has the newtypes and the constructors' types (`lib/language/haskell/infer.sml:26-27`) but no module
    scope.
  - Passing the scope in from the renamer is about 40 lines [inferred].
  - HsLint has no check of its own. It needs about 80 lines over its environment's newtypes [inferred].
- **Interfaces need nothing new.**
  - A unit's part holds every value, tycon and constructor whose home is the module, exported or not
    (`lib/language/haskell/infer.sml:44-52`). The interface writes the exports beside it
    (`lib/language/haskell/hsiface.sml:80-83`, `:97`).
  - Compiled a unit at a time, Visible and Basic marshal Abstract's newtypes and CInt through Int32 to Int correctly
    (`out/units.log`).

**The cost of a call** (E10, `Cost.hs` at -O2, `runevm --count` at 100,000 and 200,000 iterations). The figures are
the difference between the two runs, so start-up cancels (`out/units.log`):

| Per iteration | VM instructions | Bytes | Objects |
|---|---:|---:|---:|
| Haskell's own `abs` on CInt | 39.4 | 56 | 2 |
| a pure import of C's `abs` | 186.0 | 400 | 21 |
| an IO import of C's `abs` | 203.0 | 464 | 23 |

- **The difference:** a pure call costs 146.6 instructions, 344 bytes and 19 objects more than Haskell's `abs`; an IO
  call 163.6, 408 and 21. libffi's native work is not counted.
- **Where it goes:** most of it is strings. Each argument is encoded as nine bytes made of eight one-byte strings and
  their concatenations (`gffWordBytes`, `gffEncInt` in the patch) [inferred from the code].
- **Wall time:** 0.33 to 0.43 s per 100,000 pure calls, against 0.025 to 0.039 s for Haskell's `abs`, three runs each,
  on a shared machine.

**Further lessons** (V's report, from the build).
- The family rule above admits no Double and no function argument. The prototype breaks it in `ffi_enc_real`,
  `ffi_dec_real` and `ffi_wrap`: Core to Mid copes, and the Core interpreter cannot run them.
- At -O2 the simplifier refined a lambda's result to `!Str`, which CoreLint then compared exactly against the
  primitive's type, so `ffi_wrap` takes its function argument lazily.

**Not covered.**
- **The Core interpreter:** every `ffi_*` primitive raises an IOError there (`noInterp` in the patch), so FFI programs
  run compiled only (G35).
- **Bool, Float, Char and StablePtr:** no program imports a function over them. The desugarer's `foreignBasic` has no
  Bool and no StablePtr, though the checker accepts both [read].
- **Export:** `foreign export` and HsFFI.h were not attempted.
- **Targets:** only x86-64 Linux, on the register and stack VMs. Not `runeopt`, AArch64 or Windows. `stdcall` was only
  refused (G26).
- **Tests:** GHC 9.14.1's FFI tests have 121 files, 116 of them with a foreign declaration. 36 have no LANGUAGE pragma
  and no GHC-only import; none was run (`ghc-ffi-tests.txt`).
- **The syntax** is F's (E3, `patches/E3-06-foreign.patch`): a FOREIGN token reserved in 2010 only (T10:1741), a
  `DForeign` declaration (export or import, calling convention, safety, entity, variable, type) parsed by chapter 8's
  grammar, through both printers and the dump, the imported variable bound by `modules.sml`: +53 -7 lines, 44 of
  code, in 10 files (`results/E3/diffstat.tsv`). GHC parses the same declarations (`results/E3/programs/foreign1.hs`).
  The prototype's parser rewrite above is what D32 replaces with that declaration form.

### Where the Report and Rune's model part

Each row is E10's `gaps.tsv`: its grade verbatim, its size and the decision it names. The grades are the 98 brief's
four (haskell98.md:151), from a change to Rune that is large down to none, where rhc lives with Rune as it is,
sometimes by a workaround. "None" says nothing of rhc's own work, which the size column gives. The changes to Rune
have one estimate each, and none was built.

**None: 20 rows.**

| Id | The requirement | What rhc does | Size | Decision |
|---|---|---|---|---|
| G01 | a static `ccall` import; `ccall` required (8.4.1, 8.5.1) | syntax, the 8.4.2 check, Core primitives and their Mid (prototyped) | 846 lines in the prototype; a real one needs an AST form in about 12 files | D27, D32 |
| G03 | a pure import a true function, strict in all arguments, lazy where not demanded (8.4.2, 8.4.3) | force the arguments by case, call with `real_world`'s token (`coreruntime.sml:674-676`'s form) | - | D32 |
| G04 | IO calls neither dropped, duplicated nor reordered | nothing: `foreign`'s effects are anything, and Core threads the state token | - | D32 |
| G05 | an `&` import of a function, called by a `dynamic` stub (8.5.1) | nothing: a symbol is passed as a pointer and prepared (`runtime/foreign.c:349`, `:414-424`) | - | D27 |
| G08 | a `wrapper` called during a call (8.5.1, 8.4.3) | the Mid trampoline (prototyped) | in the prototype | D27, D31 |
| G10 | a callback forcing a suspension under evaluation | nothing: Loop is raised, kept and re-raised after the call | - | D31 |
| G12 | at most 64 nested callbacks, interpreter only | document the limit | - | D31 |
| G18 | peek and poke at any address C gave (37) | nothing: past an object is C's undefined behaviour in Haskell too; Rune's own allocations are checked, which conforms | - | D29 |
| G20 | `alloca`, `allocaBytes`, `realloc`, `reallocBytes` (31.1) | `alloca` over allocate and release; `realloc` as C's over G19's memory | library ~40 | D33 |
| G23 | `freeHaskellFunPtr` (35.2) | nothing: release of a callback frees its closure (`runtime/foreign.c:818-826`) | - | D30 |
| G26 | `stdcall`, optional (8.4.1, 8.5.2) | ABI 1 on x86 Windows; elsewhere refuse at compile time, or read it as `ccall` | rhc ~10 | D27 |
| G27 | every target; C types' sizes and `char`'s sign (28) | a target profile picks Foreign.C.Types; a `.rbc` using C types becomes target-specific | library: a module per profile ~150 | D27, D33 |
| G29 | images and fork with live foreign resources | nothing for 2010 (no image or fork API); a constraint on a future REPL | - | D29 |
| G30 | Int8 to Word64 as basic foreign types (8.4.2, 18, 23) | rhc's IntN and WordN (D22); the prototype's Word64, a newtype of Int, overflowed on 2^64-1 (`Wide.hs`) | D22's | D22, D33 |
| G31 | `safe` and `unsafe` (8.4.3) | read and ignored: every call allows callbacks | - | D27 |
| G32 | variadic C functions, "deprecated in portable code" (8.5.1) | nothing: a Haskell type cannot say variadic | - | D27 |
| G33 | the marshallability rule (8.4.2) | the structural check (prototyped), visibility from scope, HsLint's own reading | checker 73 (prototype), visibility ~40, HsLint ~80 | D32 |
| G34 | a newtype's representation across modules | nothing beyond G33: interfaces hold hidden constructors | - | D32 |
| G35 | the FFI on rhc's Core interpreter (`bin/rhc Main.hs`, `docs/rhc.md:19`) | CoreInterp over RuneForeign's public API, callbacks re-entering CoreInterp | rhc ~250 | D32 |
| G36 | `nullPtr` and `nullFunPtr` are `NULL` both ways (8.7) | `nullPtr` the identity 0; a null result is no identity (`runtime/foreign.c:687-711`) | - | D29 |

**None with a workaround: 3 rows.**

| Id | The requirement | The workaround | Size | Decision |
|---|---|---|---|---|
| G09 | an exception escaping a callback (undefined only for exports, 8.4.4) | the trampoline catches every exception, keeps it and returns the failure value; the call raises it after native return (prototyped). Optionally `vm_raise` could stop at a callback's scope | VM hardening, optional: C ~15 and a test | D31 |
| G19 | `malloc` and `free` are C's: `free` frees what `newCString` made, `finalizerFree` is C's `free` (27, 29, 31) | rhc's `malloc` and `free` call C's; Rune's `allocate` stays for `alloca`. Today C's `free` of a Rune allocation followed by Haskell's `free` aborts in glibc, status 134, at -O1, -O2 and on the stack target, and is silent at -O0 (`FreeClash.hs`) | library ~30 | D29, D33 |
| G28 | `errno`: `getErrno` (26); the Report's `"errno.h &errno"` (8.5.1) | rhc keeps the errno captured after the last call; `&errno` cannot work (thread-local, and glibc's symbol is unreadable: G06) | rhc ~30 in Mid, and library | D33 |

**Small: 5 rows.**

| Id | The requirement | The change to Rune | Size | Decision |
|---|---|---|---|---|
| G02 | a static import resolved with no library named (8.5.1: `chname` is a header) | an operation for the program's own namespace (`dlopen(NULL)` or `RTLD_DEFAULT` on POSIX, the loaded modules on Windows), and rhc options naming libraries. Today libraries open by name only (`runtime/sys/sys_posix.c:1784`). `dlopen("")` reaches the program's namespace on glibc (`probe/global.out`); elsewhere is untested [inferred]. Even so `atexit` is not found (`Gaps.hs`): glibc keeps it in the static `libc_nonshared.a`, not in `libc.so.6` [read with nm] | C ~30, rhc option ~40, tests | D27 |
| G06 | an `&` import of a C variable, read and written by Storable (8.5.1) | let `region()` take a symbol, of unknown extent as a returned pointer is. Today "resource is not foreign memory" (`runtime/foreign.c:301-305`), measured with `optind` and `&errno` (`Gaps.hs`) | C ~5, tests ~30, `docs/ffi/runtime.md` | D29 (taken under D27 in *Decisions*) |
| G07 | `dynamic` of any FunPtr: a wrapper's, or one C returned (8.5.1) | prepare a pointer or callback identity too, the prepared call retaining it. Today `prepare` takes a symbol alone (`runtime/foreign.c:349`), so a wrapper's FunPtr gives "invalid foreign call specification" (`Gaps.hs`) | C ~10, tests ~40 | D27, D29 |
| G22 | StablePtr (36) | a table in Haskell, and for `castStablePtrToPtr` a pointer identity made of an integer that C must not dereference; or D29 A; or a primitive over `vm_handle_*` | library ~40, C ~20 | D30 |
| G17 | a callback's pointer argument used after the callback returns (35); graded "small (with G16)" | canonical identities with G16, or D29 A. Today they are borrowed and retired on return (`docs/ffi/callbacks.md:73-75`) | C ~20 | D29, D31 |

**Medium: 2 rows.**

| Id | The requirement | The change to Rune | Size | Decision |
|---|---|---|---|---|
| G15 | `Storable (Ptr a)`, `(FunPtr a)`, `(StablePtr a)`: a pointer read from or written to memory, as in argv arrays and struct fields (35, 37) | two operations: adopt the address at (memory, offset) as a pointer identity, and write an identity's address at (memory, offset). Under D29 A a pointer is bytes like any other [inferred] | C ~60, SML ~20, tests ~80 | D29, D33 |
| G16 | pointers C returns have no lifetime in Haskell | a canonical identity per live address, as `aliasHandle` gives handles (`lib/basis/rune_foreign_sig.sml:154-161`), or D29 A. Today each is a new identity never released: 1,000 `getenv` calls add 1,000 live identities, and Gaps.hs ends at 1,036 (`Gaps.hs`) | C ~80, tests | D29 |

**Large: 2 rows.**

| Id | The requirement | The change to Rune | Size | Decision |
|---|---|---|---|---|
| G24 | `foreign export`: a Haskell value as a C symbol (8.4.4) | `runeopt`'s native builds emit a C-callable stub per export that enters the VM, linked with the program's C; x86-64 only at first, since `runeopt` has no other target | runeopt and runtime ~600, tests | D28 |
| G25 | HsFFI.h: Tables 8.2 and 8.3, `hs_init`, `hs_exit`, `hs_set_argv`, `hs_perform_gc`, `hs_free_stable_ptr`, `hs_free_fun_ptr` (8.7) | an embedding API in `librune` (start, stop, arguments, collect) and a header, with G24. Today `runtime/main.c`'s `main` is the VM's only entry from C | with G24 | D28 |

**Large under one option: 4 rows.** The grade is gaps.tsv's text.

| Id | The requirement | Grade | The options | Size | Decision |
|---|---|---|---|---|---|
| G11 | callbacks when no call is active: after it returned (`atexit`, `on_exit`), a signal handler, another thread | large (or a stated deviation) | on the same thread, a VM entry from arbitrary native frames, against the no-nested-driver rule; other threads belong to the concurrent runtime. Today such entries are refused silently (`Later.hs`) | the concurrent-runtime roadmap; here a deviation row and a test | D31 |
| G13 | Ptr as an address: `plusPtr` by any offset, `minusPtr`, `alignPtr`, Eq and Ord (35.1) | large (A, a change of Rune's model) or medium (B) | A: raw addresses for Haskell's Ptr, against Rune's rule that SML never sees one. B: identity plus offset in rhc, with new operations for order, difference, the alignment offset, a view before its parent's start, and a canonical identity per address | A: C ~200, SML ~100, a safety review. B: C ~150, tests ~150 | D29 |
| G14 | `ptrToIntPtr`, `intPtrToPtr`, `ptrToWordPtr`, `wordPtrToPtr` (35.3) | large (with G13 A) or a deviation | trivial under A; under B a deviation, since an identity is no address | - | D29 |
| G21 | ForeignPtr's finalizers: after the last reference, with no promptness, before exit (29.1.1) | large (A) or none-with-workaround (B) | A: finalization driven by the collector (a weak table scanned after a major collection, C finalizers called at a safe point) on every engine, kept out of images. B: run each ForeignPtr's finalizers at `finalizeForeignPtr` and at program exit only, which T10:14966-14967 allows, memory held until exit | A: C ~400, tests. B: library ~60, an exit hook in rhc's runtime ~20 | D30 |

E10 measured what G13's options turn on (`Gaps.hs`, `FarPeek.hs`).
- **Eq on identities:** `getenv` twice gives two identities that are not `==`, though `sameAddress` says they are
  one address.
- **Offsets in the prototype:**
  - `plusPtr` makes a zero-length view, since the parent's remaining extent is not known to it. So C can use the
    offset pointer (`strlen` of `plusPtr hello 6` is 5), but Haskell's own `peekCString` through it is refused as out
    of bounds.
  - Past the end of the allocation, `plusPtr` is refused.
- **Pointers C returns:** a peek 1 GB past `getenv`'s result is a segmentation fault, status 139, at every
  configuration. Bounds protect Rune's own allocations and nothing C returns, which is C's undefined behaviour in any
  Haskell.

### What the decisions take from this

The decisions are D27 to D33 in *Decisions*. Their shape:

- **D27, conventions and kinds.**
  - **Recommended:** all four `ccall` kinds through a Core primitive family over `foreign` and `foreign_callback`, as
    prototyped.
  - **The Rune changes,** each small: G02 (the program's own namespace, with rhc options naming libraries), G06 (an
    `&`-imported variable readable) and G07 (`dynamic` of any FunPtr).
  - **`stdcall`** is ABI 1 where the target has it, which is x86 Windows. Elsewhere the owner picks: refuse it at
    compile time (recommended; 8.4.1 makes it optional) or read it as `ccall` as GHC does with a warning
    (`docs/users_guide/using-warnings.rst:738-740`).
  - **`safe` and `unsafe`** are read and ignored.
- **D28, `foreign export` and HsFFI.h.**
  - **Large** (G24, G25).
  - **Recommended:** not in this roadmap. It is recorded as Planned, and G2 says it is a declared gap.
  - **Why the owner must say so:** leaving out a feature the text requires (8.4.4, 8.7) is none of the four grounds a
    deviation may stand on (wrong, contradictory, ambiguous, conceded). So the recommendation stands only on the
    owner's explicit word.
  - **The alternative:** a milestone after G2, on x86-64 first.
- **D29, Ptr.** The owner's call on Rune's model.
  - **A, recommended:** a raw address through a trusted address-level family for rhc's Core alone. It changes runeffi's
    rule (`docs/plans/runeffi.md:465-467`): large as policy, about 300 lines [inferred]. It makes G13 to G17 exact.
    The identities give no safety where it matters (G18, FarPeek), break Eq and grow without bound (G16). G06 is
    needed under either option.
  - **B:** identity plus offset in rhc, medium, with `ptrToIntPtr` a deviation (G14) and canonical identities (G16).
- **D30, finalizers and StablePtr.**
  - **ForeignPtr** takes G21's B: about 80 lines of library and exit hook, and no Rune change. Collector-driven
    finalization is deferred.
  - **StablePtr** is a table in Haskell: trivial under D29 A, and about 20 lines of C in Rune under B (G22).
- **D31, callbacks.**
  - **Rune's contract stays:** during a call, on the owning thread, at most 64 deep, a limit documented as the
    implementation's.
  - **The trampoline is mandatory** (G09). The blackhole case needs nothing (G10).
  - **Callbacks after the call returned, or from signals,** are refused silently (G11). The recommendation reads 8.4.3
    so, with a test, since the text speaks only of callbacks a safe call allows before it returns (T10:6956-6961). The
    owner may call it a deviation instead.
  - **Other threads** belong to the concurrent-runtime roadmap.
- **D32, the FFI in Core.** The prototype's shape, with these changes:
  - an AST declaration form instead of the parser's rewrite;
  - IO imports thread World; pure imports force their arguments, then call with `real_world`;
  - a static call's identity is a top-level CAF;
  - the family interface widened for Double and functions, or the FFI primitives made first-class in CorePrim and
    CoreToMid;
  - the pending exception and the last errno are per-program state;
  - the structural check, the constructor's visibility from scope and HsLint's own check (G33); this section adds
    that Foreign.C.Types must then export its constructors (*What chapter 8 requires*);
  - interfaces unchanged (G34);
  - the FFI primitives off cheap eagerness's whitelist.
- **D33, Foreign.\*.**
  - **Where it lives:** in Haskell over new Core primitives, with typed peek and poke.
  - **The rest:** Foreign.C.Types per target profile (G27); C's `malloc` and `free` (G19); the last errno kept (G28).
  - **Allocation failure** gives `nullPtr`, as the text says, and C strings are Latin-1, as base 4.3 has them
    (*The libraries*).
  - **The cost of a call** is an optional Rune optimisation: typed scalar arguments without strings.
  - **On the Core interpreter,** the owner picks: compiled only, documented (recommended), or about 250 lines over
    RuneForeign's API (G35).

## The libraries

The 2010 Report's library is chapter 9's Prelude and the 30 modules of Part II, chapters 13 to 42. E9 read all 30
against rhc's 98 library, GHC's `base` of 2010, the `haskell2010` package and the other implementations; the
Prelude's code is E1's. What follows is what the text gives, what rhc can reuse, and what is left to write. The
decisions are D20 to D26 (*Decisions*); the FFI's runtime, on which Foreign.* stands, is *The foreign function
interface* (D27 to D33).

In short:
- **26 of the 30 modules are prose only;** 4 print code (Data.Array, Data.Complex, Data.Maybe, Data.Ratio). The
  prose is `base` 4.3's Haddock text, not 4.2's. So for 26 modules "follow the report" means code written against
  signatures and sentences, with `base` 4.3 as the reading of what their authors meant (D24).
- **Of 98's 16 library modules, 5 are gone and 11 continue as 13;** 17 are new: Data.Bits, Data.Int, Data.Word and
  14 Foreign.* modules.
- **rhc's 98 code carries into 11 of the 30:** 953 code lines, the 98 code of nine codeless modules and the overlay
  lines of two printed ones. Data.Char's predicates are the exception: three change meaning.
- **Two of the four printed modules do not compile as printed** (Data.Maybe, Data.Ratio), and a third is headed
  `module Array (`.
- **Bits, IntN and WordN need no Rune change;** the VM has the word operations. Foreign.* rests on the FFI's
  decisions.
- **The Prelude's printed imports already form a 7-module cycle.** rhc's own code for Data.Char and Numeric makes it
  9 or 14 (D23).
- **The 30 modules come to about 4,660 code lines,** about 3,470 of them new, 2,500 of those Foreign.* (E9).

### What has code, and where the prose came from

The four modules with code are the only "Specification" sections of Part II: Data.Array 14.6, Data.Complex 17.4,
Data.Maybe 21.2 and Data.Ratio 22.1 (T10:11475-11603, 12188-12364, 13430-13511, 13573-13763). No module is code only.
Data.Ix prints the derived instance for pairs as code (T10:12586-12611), a scheme, not the module. Every other module
is an export list, signatures and prose.

The prose is GHC's library documentation of 2010. E9 looked for each of T10's 1,078 library prose lines of
eight or more words, word for word, in five versions of `base` and the `haskell2010` package
(`results/E9/provenance.tsv`, `provenance-summary.txt`):

| Source | Lines found | Share |
|---|---:|---:|
| `base` 4.3.0.0 and 4.3.1.0 | 958 | 88.9% |
| `base` 4.2.0.2 | 905 | 84.0% |
| `haskell2010` 1.0.0.0 | 215 | 19.9% |
| any of them | 1,018 | 94.4% |

34 lines are in `base` 4.3 and in neither 4.2 nor the package, among them the sentences of `void`, `withFile` and
`isSpace` (T10:11189, 16264-16265, 11833); 6 are in 4.2 only, Char's opening paragraph (T10:11803-11808). So the
base of record is 4.3. The `haskell2010` package needs it
(`downloads/libs/src/haskell2010-1.0.0.0.x/haskell2010-1.0.0.0/haskell2010.cabal:17`, `base >= 4.3`), re-exports it,
and overrides some comments.

The package is also a mechanical source of the printed code: its four modules hold the code as `$code` comments
(`results/E9/code2010/`). They agree token for token with E1's extraction from the HTML Report
(`results/E1/libs/code2010/`) [measured by this writer's comparison; no result file]. The PDF's text cannot serve:
its columns break (T10 prints `= numericEnumFrom` on a line of its own, T10:8268). The package's Prelude is GHC's
re-exports, not chapter 9, so the Prelude's code comes from the HTML (E1, `results/E1/prelude/prelude2010/`).

The export lists of the package equal T10's in all 30 modules but one name: the package exports `CLDouble` under
`#ifdef HASKELL_REPORT` (`Foreign/C/Types.hs:35-38`), and T10 does not (T10:14480-14485). The 30 lists hold 620
items, 686 names once methods and constructors are counted. The PDF moves the ends of header lines below `) where` in
15 modules; E9 restored those 37 items by hand, each checked against its T10 line (`results/E9/exports.tsv`,
`scripts/exports.py`).

### What 2010 dropped and added

| 98 module | 2010 | Code in 2010 |
|---|---|---|
| Ratio, Complex, Array, Maybe | Data.Ratio, Data.Complex, Data.Array, Data.Maybe | printed |
| Char, Ix, List, Monad, Numeric | Data.Char, Data.Ix, Data.List, Control.Monad, Numeric | prose |
| IO | System.IO and System.IO.Error | prose |
| System | System.Environment and System.Exit | prose |
| Time, Locale, CPUTime, Random, Directory | gone | |
| | Data.Bits, Data.Int, Data.Word (the FFI Addendum's) | prose |
| | Foreign, Foreign.C, Foreign.C.Error, Foreign.C.String, Foreign.C.Types, Foreign.ForeignPtr, Foreign.Marshal, Foreign.Marshal.Alloc, Foreign.Marshal.Array, Foreign.Marshal.Error, Foreign.Marshal.Utils, Foreign.Ptr, Foreign.StablePtr, Foreign.Storable | prose |

Three exported names of continuing modules are gone: `bracket` and `bracket_` (98's IO) and `system` (98's System)
(`results/E9/delta98.tsv`). The five dropped modules are 480 of the 5,240 lines of `share/rhc/haskell98`
(`results/E9/sharing.tsv`).

### What carries over from rhc's 98 code

Nine codeless modules continue a 98 module whose code rhc has (`results/E9/delta98.tsv`, `modules.tsv`; code lines are
non-blank lines outside comments):

| 2010 module | From 98's | Names carried / all | 98 code lines carried | New code lines | What changes |
|---|---|---:|---:|---:|---|
| Control.Monad | Monad | 31 / 40 | 63 | 16 | 9 new names, one-liners in `base` |
| Data.Char | Char | 23 / 64 | 117 | 94 | 41 new names (GeneralCategory and its 30 constructors among them); `isUpper`, `isAlpha`, `isSpace` change |
| Data.Ix | Ix | 5 / 5 | 142 | 0 | none; the new instances come with their types |
| Data.List | List | 104 / 111 | 196 | 33 | `intercalate`, `subsequences`, `permutations`, `foldl'`, `foldl1'`, `stripPrefix`, `isInfixOf` |
| Numeric | Numeric | 18 / 18 | 251 | 0 | none |
| System.Environment | System | 3 / 3 | 12 | 0 | none |
| System.Exit | System | 5 / 6 | 15 | 2 | `exitSuccess` |
| System.IO | IO, PreludeIO | 59 / 67 | 110 | 45 | 8 new: `fixIO`, `withFile`, `hSetFileSize`, `hTell`, `hIsTerminalDevice`, `hSetEcho`, `hGetEcho`, `hShow` |
| System.IO.Error | IO | 16 / 27 | 35 | 40 | `mkIOError`, `annotateIOError`, IOErrorType and its 8 values |

The carried lines of Monad, Char, Ix, List and Numeric are those whole files (`share/rhc/haskell98/*.hs`); the
lines of IO.hs (145) and System.hs (31) are apportioned between the modules they split into [inferred]. The new
lines are counted from `base` 4.3's definitions of the new names where `base` has portable ones
(`results/E9/newdefs.tsv`), else judged.

Two details of the carry:
- **`withFile` needs `bracket`, which 2010 no longer exports.** Its sentence, that an exception from closing the
  handle "will be raised by withFile rather than any exception raised by act" (T10:16264-16265), is what 98's
  `bracket` does (`share/rhc/haskell98/IO.hs:162-170`), so System.IO keeps it unexported [inferred].
- **The four printed modules carry 98's overlay, not 98's code:** Data.Array 11 lines (`ov.array.representation`,
  `ov.array.strictbounds`), Data.Ratio one import (`ov.prelude.numericenum`), so 953 lines in all.

### The printed modules and their defects

**The Prelude.** Chapter 9's code is 98's: of 927 non-blank lines 915 are identical, 9 differ in spacing, and 3
differ, all module names in imports (E1, `results/E1/prelude-diff.md`). Against 98 with its errata, 2010 reverts both
code errata: `enumFrom` and `enumFromThen` on Float and Double lose their `seq` (T10:8258-8292), and `lex` loses the
leading underscore (T10:9036-9051). Whether rhc's overlay entries for them (`ov.prelude.enumfloat`,
`ov.preludetext.lex`) carry into 2010 mode is D38's (E1's N18). The other 98 overlay entries on the Prelude's four
modules apply again, `interact`'s four names (T10:9274-9278) and the hidden numeric enumerations among them, but for
`ov.prelude.int`, Int's checked arithmetic, which D21 may change in 2010 mode.

**The four library modules** (`results/E9/code2010/*.diff`, tokens common with 98's pristine code):
- **Data.Complex** is 98's code but the module name and spacing (971 of 973 tokens). Its chapter's export list,
  outside the code, prints `Complex(:+)` (T10:12108), which does not parse (E1's N11); 17.4's code has `Complex((:+))`.
- **Data.Ratio** is 98's code but the name, one error text and one parenthesis (738 of 741 tokens). `Show (Ratio a)`
  is one `(` short: `showsPrec p (x:%y) = showParen (p > ratPrec) showsPrec (ratPrec+1) x . showString " % " .
  showsPrec (ratPrec+1) y)` (T10:13723-13730; the package's source has the same line). GHC 9.4.7 `-XHaskell2010`:
  "parse error on input \`)'" (`results/E9/probes/ghc.out`). The fix is 98's line. Its comment still says the
  numeric enumerations are "as defined in Prelude.hs but not exported from it!" (T10:13708-13714), so
  `ov.prelude.numericenum` and PreludeEnum stay.
- **Data.Array** rewrites `array` with guards and new error texts (769 of 795 tokens). Its header is
  `module Array (` (T10:11476), the 98 name left in; GHC compiles it as module Array (E1, N11). It keeps 98's dead
  `import Data.List( (\\) )` (T10:11481), rhc's open entry `ov.array.listimport`.
- **Data.Maybe** now defines `maybe` (T10:13439-13440) and exports it, where 98's re-exported the Prelude's. The
  Prelude, imported implicitly, defines `maybe` too (T10:8103-8106), so the module's own export is ambiguous by 5.5.2
  (T10:5417-5418). GHC 9.4.7: "Ambiguous occurrence \`maybe'" (`results/E9/probes/MaybeClash.hs`).

So the 2010 overlay is 98's on the Prelude, Data.Array and Data.Ratio, plus three entries 98 did not need: the header
`module Data.Array (`, Ratio's parenthesis, and Data.Maybe's `maybe`. Data.Maybe's has one right form. Hiding the
Prelude's `maybe` inside Data.Maybe, E9's other suggestion, compiles the module but makes two entities named `maybe`, so
every program that imports Data.Maybe and calls `maybe` unqualified is ambiguous [inferred from 5.5.2; GHC 9.4.7 says
"Ambiguous occurrence" on that shape: `results/E9/probes/maybeprobe/` (`DM.hs`, `User.hs`, `ghc.out`)]. The entry must
drop the printed definition and re-export the Prelude's, 98's shape. These are D23's entries and D38's defects (N11);
the ones no earlier source lists are in *Found while writing*.

### Where the prose is thin or disagrees with `base`

Where the prose says nothing, `base` 4.3 is the source of truth (D24); where the prose says something `base` does
not do, the Report is (D26's rule, the brief's "follow the report as closely as possible"). The places, with `base`
4.3.1.0's line (`downloads/libs/`) and what rhc does:

| Module | The text | `base` 4.3 | rhc |
|---|---|---|---|
| Data.Int, Data.Word | "All arithmetic is performed modulo 2^n" of a list naming Int (T10:12381-12382; Word: 13781) | not modulo for ``minBound `quot` (-1)``: `overflowError` in Int (`GHC/Real.lhs:246-254`) and every IntN (`GHC/Int.hs:89-92`, 36 uses) | Int: D21; IntN and WordN modulo by the text, that `quot` included |
| Data.Int, Data.Word | shifts by the width or more give "either zero or -1, depending on the sign" (T10:12388-12389); Word, zero (T10:13787) | counts at or past the word size guarded (`GHC/Base.lhs:803-823`) | guarded in Haskell (D22); a left shift of a negative value gives 0, not the sentence's -1 (E1's N6) |
| Foreign.Marshal.Alloc | "If any of the allocation functions fails, a value of nullPtr is produced." (T10:15125) | an IOError, ResourceExhausted (`Foreign/Marshal/Alloc.hs:110`, `:215-228`) | the text (D33) |
| Foreign.C.String | "by default, is determined by the current locale" (T10:14295-14296) against "Currently these functions are identical to their CAString counterparts" (T10:14322) and "Currently only Latin-1 characters are representable" (T10:14357) | Latin-1: `peekCString = peekCAString`, `charIsRepresentable c = return (ord c < 256)` (`Foreign/C/String.hs:135`, `:190`) | Latin-1 (D33) |
| System.IO.Error | `annotateIOError` "Adds a location description" (T10:16748) | GHC and Hugs replace the location, nhc98 appends (`System/IO/Error.hs:417-428`) | a reading to pin |
| Numeric | `showEFloat`: "at most d digits after the decimal point" (T10:15987) | `max dec 1`, so `Just 0` shows one digit (`GHC/Float.lhs:509-510`), as 98's code (`share/rhc/haskell98/pristine/Numeric.hs:183`) | 98's code, a place where code and text part |
| Data.Char | `isAlphaNum`: "alphabetic or numeric digit" (T10:11851) | letters, marks and numbers (`cbits/WCsubst.c:4123-4125`) | the prose (D26) |
| Data.Char | `isSpace`: "any Unicode space character" (T10:11833) | Zs and the five controls (`GHC/Unicode.hs:71-78`; `cbits/WCsubst.c:4117`) | D26, below |
| System.Exit | `ExitFailure 0`: "some values may be prohibited (e.g. 0 on a POSIX-compliant system)" (T10:16130-16132), no behaviour | an IOError, InvalidArgument (`System/Exit.hs:72-78`) | 98's IllegalOperation (`ov.system.exitzero`); 2010's IOErrorType has no InvalidArgument (T10:16708-16716) |
| Data.Bits | "Minimal complete definition" and no default methods (T10:11633) | the class's defaults (`Data/Bits.hs:73` on) | `base`'s |
| System.IO | `fixIO`: a signature, no prose (T10:16204) | an IORef read lazily (`System/IO.hs:460-466`) | over `ref_new` and `interleave` (`lib/language/haskell/coreprim.sml:94-96`) |
| System.IO.Error | `ioeGetErrorString`, `ioeGetHandle`, `ioeGetFileName`: signatures only (T10:16787-16789) | the text for user errors, else `show` of the type (`System/IO/Error.hs:337-339`) | 98's: the error's text for every error (`share/rhc/haskell98/IO.hs:145-146`), which 98 left implementation-dependent beyond user errors (T98:12818-12820); or `base`'s, a reading to pin |
| Data.List | `foldl'`: "A strict version of foldl." (T10:12727) | the accumulator `seq`'d (`Data/List.hs:975-980`) | `base`'s |
| Data.List | `subsequences`, `permutations`: fixed only by their examples' order (T10:12707, 12712) | `Data/List.hs:750-780` | `base`'s code, or one with its order |
| Data.Ix | "Minimal complete instance: range, index and inRange." (T10:12512): `rangeSize`'s default and `index`'s failure unstated | `GHC/Arr.lhs:89-91` | 98's code has both |
| Data.Ix | instances listed to 5-tuples (T10:12553), "at least size 15" (T10:12562) | | 15, as 98 (`ov.tuples.fifteen`; D38, E1's N16) |
| Foreign.C.Error | 99 errno constants with no values; `errnoToIOError`'s mapping unstated (T10:14140) | from configure, -1 where absent; `isValidErrno (Errno errno) = errno /= -1` (`Foreign/C/Error.hs:271-277`) | values by name, below |
| Foreign.Storable | Bool's and Char's representation unstated (T10:15886-15887) | Bool a C `int`, Char 32 bits (`Foreign/Storable.hs:176-180`, `:190-193`) | D33 |
| System.Exit | 98's chapter 23, how a program ends, is gone (E1's N21) | | D38: 98's behaviour, documented |

Smaller defects of the text, for *Found while writing*: "type IOError = IOError" (T10:16722); `deRefStablePtr`
returns what was passed to "the corresponding call to makeStablePtr" (T10:15763-15764), a function no module defines;
`addForeignPtrFinalizerEnv` is "Like addForeignPtrFinalizerEnv" (T10:14984); Data.Ix sends the reader to "the array
package" (T10:12504); the numeric C types' prose omits Real, which their instance list gives (T10:14828-14829); "are
are" (T10:14521, 14828, 14859) and "the the" (T10:13221, 16520); Data.Ix's law has a stray parenthesis (T10:12510);
Data.List's "iteratef", "repeatx", "replicaten x" (E1, `errata2010.md`).

### Data.Char and Unicode

2010 changes three of 98's predicates. Against rhc's 98 code two answer differently, and the third keeps its answers
but not its code:

| Predicate | 2010 | rhc's 98 mode | In 2010 mode |
|---|---|---|---|
| `isUpper` | "upper-case or title-case" (T10:11844): Lu, Lt | Lu, Lt, Lm, Lo (R38; `lib/language/haskell/coreruntime.sml:622-625`) | narrows |
| `isAlpha` | every letter, "equivalent to Data.Char.isLetter" (T10:11848) | `isUpper c \|\| isLower c` (`share/rhc/haskell98/Char.hs:42`): every letter, given 98's `isUpper` | the same answers; the 98 definition would lose Lm and Lo under 2010's `isUpper`, so it is rewritten |
| `isSpace` | "any Unicode space character, and the control characters \t, \n, \r, \f, \v" (T10:11833) | the seven Latin-1 white characters (`share/rhc/haskell98/Char.hs:35`) | widens beyond Latin-1 |
| `isAlphaNum` | "alphabetic or numeric digit" (T10:11851) | L and N (`coreruntime.sml:630-636`) | unchanged |
| `isPrint` | "letters, numbers, marks, punctuation, symbols and spaces" (T10:11856) | not Zl, Zp or C (`coreruntime.sml:638-640`) | unchanged; `base` the same (`cbits/WCsubst.c:4116`) |

98 mode keeps R38 and the Latin-1 `isSpace`: the 2010 text for them is an override of 98's plain text, not an
alignment (D13c, D13d). `isSpace` reaches the Prelude: PreludeList's `words` and PreludeText's `lex` import it from
Data.Char (T10:8422, 8867), so `words` splits at U+3000 in 2010 mode and not in 98 mode.

**The category is already computed.** GeneralCategory's 30 constructors are "in the order they are listed in the
Unicode standard" (T10:12009), which is the order of `lib/unicode`'s `CodePoint.category`
(`lib/unicode/code_point_sig.sml:34-64`) and of rhc's runtime numbering, "0 Lu, 1 Ll, ... 29 Cn"
(`coreruntime.sml:547-560`; `rtCategoryOf` at `:618`). So `generalCategory` is `toEnum` of one value the runtime
already computes, exposed as one more name of UnicodePrims, and every 2010 predicate can be Haskell over it, as
`base`'s are (`Data/Char.hs:136-205`). The 98 `primUnicodeIs*` stay for 98 mode. `toTitle` needs one more table:
`lib/unicode` has Simple_Titlecase_Mapping (`code_point_sig.sml:137-146`), and rhc renders only `rtUpper` and
`rtLower` (`coreruntime.sml:774-775`). It differs from `toUpper` only for the digraphs and Georgian
(`code_point_sig.sml:140-141`).

**"Any Unicode space character"** has two readings (D26):
- general category Zs, which `base` 4.3 takes and GHC 9.4.7 answers (E1's N7), and which rhc's lexer already uses
  for the Report's `uniWhite` (`lib/language/haskell/char.sml:22-33`);
- the White_Space property, which adds U+0085, U+2028 and U+2029 (`/usr/share/unicode/PropList.txt:12-22`, version
  15.1.0 on this machine). `lib/unicode` has no White_Space table.

**The version.** 2010 names none (T10:16864) and expects compilers "to make use of new versions of Unicode as they
are made available" (T10:1542-1543). `base` 4.3's tables date from 2008 (`cbits/WCsubst.c:3`), GHC 9.4.7 answers as
Unicode 14.0 (E1's N8), and `lib/unicode` is at 18.0.0 (`lib/unicode/code_point_data.sml:16`), as 98 mode is (98's
D21).

### The primitives

What each group needs below its Haskell, and what exists (`src/isa/prims.sml` is the VM's table; rhc's Core table is
`lib/language/haskell/coreprim.sml:47-117`, which has no Word, IntN or bit primitive):

| Need | Modules | What exists | Change |
|---|---|---|---|
| bits on Int: and, or, xor, not, shifts | Data.Bits, Data.Int, Data.Word, Foreign.C.Types | the VM's 63-bit `word`: `word_andb`, `word_orb`, `word_xorb`, `word_notb`, `word_lsl`, `word_lsr`, and `word_from_int`, `word_to_int_x`, "Two's complement reinterpretation" (`src/isa/prims.sml:61-99`) | Core primitives in rhc; none in Rune |
| an arithmetic right shift | Data.Bits | no `word_asr` (only `word64_asr`, `:752`) | `complement (shiftR (complement x) i)` for a negative `x` [inferred] |
| Word, 63 bits | Data.Word, Foreign.Ptr's WordPtr | the VM's `word`, "Wrapping addition" (`:61-99`); "the same size as Int" (T10:13792) | a Core type |
| Int64, Word64 | Data.Int, Data.Word, Foreign.C.Types | `word64_*`, modulo 2^64 (`src/isa/prims.sml:717-771`); `int64_*` for signed comparison and division (`:682-716`) | a Core type over `word64` |
| Int8 to Int32, Word8 to Word32 | Data.Int, Data.Word | Int | narrowing or masks in Haskell |
| bits on Integer | Data.Bits | `intinf_binary` and `intinf_shift` are GMP's (`:839-844`), fatal without GMP (`runtime/intinf.c:569-576`) | `base` 4.3's portable branch over `quot`, `rem` and Int's bits (`Data/Bits.hs:284-302`, `toInts`, `fromInts`): none |
| the general category; title case | Data.Char | `rtCategoryOf`; `lib/unicode`'s `toTitle` | one runtime name; one table |
| isatty, ftruncate | System.IO | `file_descriptor` (`src/isa/prims.sml:525`), `posix_isatty` (`src/isa/prims.sml:427`), `posix_ftruncate` (`src/isa/prims.sml:451`) | io-family primitives in rhc |
| echo | System.IO | `posix_tcgetattr`, `posix_tcsetattr` (`src/isa/prims.sml:539-542`); the ECHO bit by `posix_const` (`lib/basis/posix_tty.sml:28-33`, `:119`) | io-family primitives in rhc |
| `hTell`, `fixIO` | System.IO | `h_tell` (`lib/language/haskell/coreprimio.sml:26-28`); `ref_new`, `interleave` | none |
| IOErrorType, `mkIOError` | System.IO.Error | `exn_io_full`: codes 0 user, 1 already exists, ... 7 permission, 8 other (`coreprim.sml:106-107`), the 8 types of 2010 and one more | none; a location goes in the text or a new field [inferred] |
| errno by name | Foreign.C.Error | `sys_error_of_name`: "The errno value of a name; ~1 when it is not known" (`src/isa/prims.sml:301-302`), `base`'s -1 convention exactly | an io-family primitive |
| Foreign.*'s memory, pointers, finalizers, stable pointers, C sizes | Foreign.* | Rune's FFI | *The foreign function interface* |

So **bits, IntN and WordN need no Rune change** (D22): rhc adds Core types and primitives lowered to operations the
VM has, about 150 to 300 lines of SML across CorePrim, CoreToMid, CoreInterp and CoreLint [inferred: Integer is named
at 13 places in 8 files of `lib/language/haskell`]. An io-family primitive takes and gives only Int, Str and Bool
(`lib/language/haskell/coreprimfamily_sig.sml:9-11`), which every System.IO addition fits. Two corrections to E9's
table: the errno constants need no search, since the VM already maps a name to its value; and `hSetEcho` and
`hGetEcho` are better over `posix_tcgetattr`, which can report the current echo, than over `term_enter`, which saves
and restores a whole mode.

Defaulting meets the new classes: 4.3.4's "defined in the Prelude or a standard library" (T10:4368) now covers
MonadPlus, Bits, Ix and Storable (T10:11097, 11629, 12501, 15819), and Bits has Num as superclass, so
`print (shiftL 1 3 .|. 1)` defaults to Integer in 2010 where GHC refuses it (E1's N9). rhc's test is a prefix match on
`thaskell98:` (`lib/language/haskell/infer.sml:2010`); D20 takes the prefix from the library's descriptor.

### Foreign.*

The 14 Foreign.* modules are about 2,500 of the 3,470 new lines, and their shape is the FFI's (E10, *The foreign
function interface*). What the library takes from it:
- **Ptr.** `plusPtr`, `minusPtr`, `alignPtr`, Eq and Ord on addresses, IntPtr and WordPtr, and `Storable (Ptr a)`
  are raw-address operations, and Rune's pointers are registry identities by design (E10's G13 to G16). Under D29 A
  (a raw address, recommended) Foreign.Ptr is ordinary code; under B (identity plus offset) `ptrToIntPtr` stays a
  deviation.
- **ForeignPtr.** The text promises no promptness, only that "the finalizer will be executed before the program
  exits" (T10:14966-14967). D30 runs finalizers at `finalizeForeignPtr` and at exit: about 60 library lines and a
  20-line exit hook in rhc's runtime, no Rune change (G21). Collection-driven finalization is deferred.
- **StablePtr.** A table in Haskell, about 40 lines, plus, for `castStablePtrToPtr`, an opaque pointer made of an
  integer, about 20 lines of C in Rune under D29 B (G22); trivial under D29 A.
- **Memory.** `malloc`, `realloc` and `free` must be C's: Rune's `allocate` is registry-owned, and C's `free` of it
  followed by Haskell's is a double free, measured as glibc's abort (G19). `alloca` stays over `allocate` and
  `release` (G20).
- **errno.** `getErrno` reads the errno rhc keeps from the last foreign call; `&errno` cannot work (G28).
  `resetErrno` sets that value [inferred]. The constants come by name, as above.
- **C types.** The sizes and the sign of `char` differ by target (`lib/basis/rune_foreign_sig.sml:38-45`), so
  Foreign.C.Types is one module per target profile, and a program's bytecode that uses it is target-specific (G27).
- **The text's open points** D33 settles: allocation failure (the text's `nullPtr`), the C string encoding (Latin-1),
  Storable's Bool and Char (`base`: a C `int`, 32 bits), and `errnoToIOError`'s mapping (`base`'s table). With a
  63-bit Int, `Storable Int` moves 8 bytes, and a value read past 63 bits has no Int [inferred, untested]; E10's
  prototype, whose Word64 was a newtype of Int, overflowed on 2^64-1 (G30), which D22's Core types remove.

### The layout and the cycle

The printed imports alone make a cycle. The Prelude imports PreludeList, PreludeText, PreludeIO and Data.Ratio
(T10:7538-7543); PreludeList imports Data.Char (T10:8422); PreludeText imports Data.Char and Numeric (T10:8867-8870);
and every module but the Prelude imports the Prelude, implicitly if not explicitly (5.6.1, T10:5522-5523). So under
98's D36 layout, which D23 keeps, Prelude, PreludeList, PreludeText, PreludeIO, Data.Char, Numeric and Data.Ratio are
one SCC of 7 (`results/E9/layout-graphs.txt`, case 3). Chapter 9's disclaimers are 98's but for the module names
(T10:7470-7476), so the Report allows fewer imports, which D23 does not take.

What changed is underneath. In 98, Char and Numeric printed code, which imported Array, Ratio and each other, so the
printed graph was one SCC of 11, and rhc's 98 library is 14 (cases 1 and 2). In 2010 they print none, so beyond the 7
the size is rhc's choice, made by the code it writes for them (cases 4 and 5):

| Layout | SCC through the Prelude | What it takes |
|---|---:|---|
| as printed | 7 | |
| 98's code for Data.Char and Numeric as it stands | 14 | the 7, Data.Array, Data.Ix, Data.List, Data.Maybe, System.IO, PreludeEnum, PreludeRuntime |
| the same, without Data.Array's dead import | 12 [inferred from case 4's edges] | Data.List and Data.Maybe leave |
| Data.Char and Numeric without Array; `interact`'s and `getLine`'s names from PreludeRuntime | 9 | the 7, PreludeEnum, PreludeRuntime |

The 14 come from 98's code: Char imports Array for its 33 control-character names (`share/rhc/haskell98/Char.hs:19`,
`:136`), Numeric for its cache of 1,101 powers of two (`Numeric.hs:19`, `:65-75`), Data.Array imports Data.Ix and
Data.List, Data.List imports Data.Maybe (`List.hs:35`), and rhc's PreludeIO imports from IO the names `interact` and
`getLine` use (`PreludeIO.hs:17`; `ov.preludeio.interact`, `ov.preludeio.getline`). The 9 cost little [inferred]: the
name table becomes a list, the cache an `Arr` of PreludeRuntime's (`arr_new`, `arr_get`, which the unit already
holds), and BufferMode, `hSetBuffering`, `stdin`, `stdout` and `hGetLine` move from IO's code (`IO.hs:51-58`,
`:74-81`, `:102-103`) into PreludeRuntime, re-exported by System.IO. D23 recommends 9. 14 is the size rhc's 98 unit has
today, so either compiles.

**A program's module named like the library's.** Under 9, Data.Char, Numeric and Data.Ratio are in every program's
closure; under 14, five more. 98 met this with `Char` (98's D36), and rhc already gives each library module an
identity of its own, "a module of the library has the identity `haskell98:` and its name"
(`src/rhc/library.sml:39-40`, `:49`), tested with a program's own `Char` (`tests/hs/names/char/`). 2010 needs only the
prefix from the descriptor (D1). The hidden modules keep their names (`src/rhc/library.sml:56`), but two places in
the driver are 98's: UnicodePrims' export list (`src/rhc/library.sml:65-67`), which 2010's category and title case
extend, and derived Ix's names, resolved in `Ix` (`src/rhc/names.sml:155`), which 2010 calls Data.Ix.

**What D36's literal layout becomes.** `pristine/` and `overlay.tsv` work as in 98 for the five modules with printed
code, the Prelude counted as one: the printed text, and a listed overlay against it. The 26 codeless modules have no
pristine, so no overlay can be "against" them. Each carries a provenance record instead: "98's Char, with these
changes", or "`base` 4.3's `Data/List.hs:750-780`" (D23). That record is not the owner's PROVENANCE file, which is for
vendored code with no licence (haskell98.md:66); every source here has one.

### Sources and licences

| Source | For | Licence |
|---|---|---|
| The 2010 Report's code | the Prelude's four modules, Data.Array, Data.Complex, Data.Maybe, Data.Ratio | "Modified versions of this Report may also be copied and distributed for any purpose, provided that the modified version is clearly presented as such, and that it does not claim to be a definition of the language Haskell 2010." (T10:7-11; the HTML's is the same) |
| rhc's 98 library | the nine continuing modules | the 98 Report's notice (`share/rhc/haskell98/LICENSE`); PreludeRuntime.hs CC0 |
| `base` 4.3 | the new names, Integer's bits, Foreign.*'s portable code | BSD-style, with the 98 Report's and the FFI Addendum's notices; one LICENSE, the same in all five tarballs and in Hugs's `packages/base` (md5 61ec3aa7) |
| Hugs | IntN and WordN, as calibration | BSD (Hugs's `License`) |

jhc (MIT, its own primitives) and MicroHs (Apache-2.0, today's `base` interface) fit poorly
(`results/E9/sources.tsv`). Every candidate is licensed, so `share/rhc/haskell2010/LICENSE` carries the 2010 notice,
the 98 notice for the carried code, and `base`'s text where `base` code is vendored, under the owner's rules of
2026-11-10 (haskell98.md:66) and 98's D37 A: the top-level LICENSE unchanged. E9's notes are wrong in one place:
PreludeEnum.hs is the Report's 14 lines moved, under the 98 notice (`share/rhc/haskell98/LICENSE`), not CC0.

### Shared or copied

No file derived from a Report can be the same bytes in both directories: every one names modules 2010 renames
(`module Ratio` becomes `module Data.Ratio`; Numeric's `import Char` becomes `Data.Char`), and three printed modules
differ in code too. Of `share/rhc/haskell98`'s 5,240 lines, 4,760 (90.8%) are in modules that continue: the Prelude's
four 2,262, rhc's own runtime layer 852 (PreludeRuntime 826, PreludeEnum 26), the four printed again 361, and the
codeless ones whose code carries 1,285 (`results/E9/sharing.tsv`, `sharing-totals.txt`). Only the runtime layer could
be one file, and it must grow for 2010 (IOErrorType, the new primitives, under 9 the IO names above), which 98 mode
does not use. D25's options: A copy everything (recommended: the brief asks for distinct directories, and 98's
library has its roadmap behind it, closed at `75ed95861` (haskell98.md:8381), so a fix made twice should be rare
[inferred]); B share the runtime layer, at the price of a third directory the descriptor names and a 98 snapshot that
moves when 2010 adds to it; C 2010 as overlays on 98, which "distinct" rules out.

### The size

| Group | Modules | Carried from 98 | Printed in 2010 | New | Total |
|---|---:|---:|---:|---:|---:|
| The nine continuing | 9 | 941 | 0 | 230 | 1,171 |
| The four printed | 4 | 12 | 236 | 1 | 249 |
| Data.Int, Data.Word, Data.Bits | 3 | 0 | 0 | 740 | 740 |
| Foreign.* | 14 | 0 | 0 | 2,496 | 2,496 |
| **All 30** | **30** | **953** | **236** | **3,467** | **4,656** |

In code lines (`results/E9/modules.tsv`, `estimate-totals.txt`). Beside the 30, the Prelude's family carries 1,530
code lines (Prelude 716, PreludeList 176, PreludeText 563, PreludeIO 60, PreludeEnum 15) with E1's three changed
imports, and PreludeRuntime 556 plus about 55 for the new primitives' names [inferred]. rhc's SML is the 150 to 300
lines above; the FFI's own Core and runtime work is E10's.

What is measured and what is not:
- **Measured:** the 236 printed lines; 781 of the 953 carried, whole files and the two overlays' lines; the other 172
  are IO.hs and System.hs apportioned [inferred].
- **Of the 3,467 new:** 111 are `base` 4.3's own definitions of the new names, counted (`newdefs.tsv`); 1,926 are
  scaled from the code lines of another implementation's module, Hugs's or `base`'s (`sources.tsv`): Data.Int 280
  and Data.Word 370 on Hugs's 281 and 370 (`Hugs/libraries/hugsbase/Hugs/Int.hs` 268 and
  `Hugs/libraries/hugsbase/Hugs/Word.hs` 359, the rest `Hugs/packages/base`'s wrappers:
  `results/verify/V2/numbers-e/hugs_loc.out`), most of Foreign.* on Hugs; 1,430 are judged, 1,100 of them
  Foreign.C.Types.
- **Foreign.C.Types** is the largest single item: 26 types, 249 instances written out at about 4 lines each, about
  1,100 lines; about 120 if the library may derive newtype instances, about 300 if they are generated [inferred].
  Haskell 2010 has neither CPP nor newtype deriving, and `base` makes them with both (`include/CTypes.h:181-193`). One
  module per target profile (G27) multiplies whichever form is taken, which argues for generating them.
- **E10's sizes** for the parts it prototyped agree in order with E9's: finalizers about 60 lines against Hugs's 113
  for all of Foreign.ForeignPtr, StablePtr about 40 against 30, `malloc` and `free` about 30, `alloca` and `realloc`
  about 40 (`results/E10/gaps.tsv`).
- **Not counted:** tests. The Data.Maybe entry makes the module 28 code lines, four fewer than E9 counted.

## What the literature says

The papers settle shapes, not sizes. They say what went into Haskell 2010 and why, how far a type checker can go without
implication constraints, and what the FFI asks of a runtime. On the second point they draw the line the tiers draw, with
one correction: T4 as the plan stated it is not safe without implications, and must split. No paper measures anything
this roadmap proposes, and none tests a Haskell 2010 implementation. The argument of this section is that the plan's
ladder is sound up to T5 if three restrictions are kept: givens only on existential variables (T4a), no improvement from
a given (T2), and simplified subsumption (T5). Each keeps Core in System F.

E11 read 56 sources (`results/E11/refs.tsv`): 29 PDFs fetched for this campaign, 42 Wayback captures of 40 pages of the
Haskell' committee's wiki and the 2003 hierarchical-modules page, 15 messages of the haskell and haskell-prime lists,
three GHC proposals, and the 98 campaign's papers and the owner's set, reused. Its 22 DOIs were checked against Crossref
(`results/E11/dois.tsv`); one, Marlow et al. 2004's, was wrong from memory and is corrected there. The DOIs of the
reused papers are in the 98 campaign's `results/E15/dois.tsv`. A script compared the FFI Addendum with the Report's
chapter 8 sentence by sentence (`results/E11/ffi/`). Every quotation below was opened again in its local text for this
section, and its page checked; a ligature the text extraction broke (fi, ff) is written out.

Conventions:
- "p. N" is the page of the local PDF as `pdftotext` counts it (one more than the form feeds before the line), not the
  printed page, unless "printed" is said. They differ where a PDF has front matter: the FFI Addendum's PDF pages are its
  printed pages plus six, and its printed pages are given too.
- The Report is cited by section; T10 line numbers are in *The experiments* and in E11's notes.
- The Haskell' wiki is cited as `HP/<page>.txt:line`, list messages as `HPM/<file>.txt`, the haskell-prime archive of
  May 2010 as `ERR/haskell-prime-2010-May.txt:line`, and GHC proposals as `GP/<file>.rst:line`. Under the drafts
  (`~/.cache/claude-rune-drafts/haskell2010/`) these are `downloads/haskell-prime/txt/`,
  `downloads/haskell-prime/mail/txt/`, `downloads/report2010/errata/` and `downloads/ghc-proposals/`; each capture's
  time and URL is in its directory's `MANIFEST.tsv`.
- *References* gives each source's status: **Full**, **Sections** (which), **Abstract**, or **Not read**. Below,
  **[abstract]** marks a source of which only the abstract was read, where it is used. **[inferred]** marks a step no
  source states. Source paths under `/home/ruud/haskell` are cited as in *What the implementations do*.

Eight items could not be read (`results/E11/wanted.md`), first among them Läufer and Odersky 1994, the paper the
Haskell' page on existentials cites. No finding below rests on them alone; substitutes are named where they matter, and
*References* lists them for the owner.

### Where the literature corrects the plan

"The plan" is the campaign's `plan.md` in the drafts, as E11 read it. Most of this has gone into *Decisions*; the list
records what changed and why. The strongest come first.

1. **T4 must split (D34, D35, D37).** The plan put "local class givens without equalities" below OutsideIn, with
   existentials as the example. OutsideIn(X) §2.3 shows that "axiom schemes combined with local assumptions are no
   better, even in the absence of GADTs", using only type classes (Vytiniotis et al. 2011, p. 8): with
   `class B a b where op :: a -> b`, `instance C a => B a [a]` and `MkR :: C a => a -> R a`, the function
   `k (MkR x) = op x` has the two incomparable types `forall a b. B a b => R a -> b` and `forall a. R a -> [a]`. The
   given `C a` there constrains `a`, a universally quantified variable of `R a`. Läufer's existentials pack a context on
   the existentially bound variables: on a match, "Nothing is known about the anonymous types, except that they satisfy
   the local context for the constructor K" (Läufer 1996, p. 4, printed p. 488). So the tier splits in two: **T4a**,
   class givens on existential (skolem) variables only, implication-free; and **T4b**, contexts on universal variables,
   `data T a = C a => K a` read as a local given and every GADT-style context, which goes with T6 [inferred]. OutsideIn
   §4.1 makes the same point of `MkSet :: Ord a => [a] -> Set a`, a context on a universal variable: "Older GHC type
   inference implementations did not support" it, for want of implications (p. 25).
2. **Improvement from a given cannot be elaborated to System F (D34, D37).** The plan's T2 was "improvement, where the
   solver unifies". Karachalias and Schrijvers 2017: "due to the non-parametric semantics of functional dependencies, it
   is not possible to translate them to a statically-typed language like System F that features only parametric
   polymorphism", and Hugs "suffers from the same problem" (p. 2). GHC rejects `f :: C Int b => b -> Bool; f x = x`
   under `class C a b | a -> b` and `instance C Int Bool`, though the dependency fixes `b` (pp. 2-3). System FC's paper
   gives the case where T2 meets T4: `data T a = forall b. F a b => MkT (b -> b)`, and
   `combine (MkT f) (MkT f') = MkT (f . f')` is rejected because "it cannot be translated into System F_A" (Sulzmann,
   Chakravarty et al. 2007, p. 3). Improvement from wanted constraints alone is unification and needs no evidence (Jones
   2000 §6.2). So T2 is sound on a System F Core provided improvement never equates types on the strength of a given,
   and such programs are refused, as GHC refuses them [inferred]. Full fundeps need FC: Karachalias and Schrijvers
   translate them into type families and elaborate to System FC (p. 3).
3. **Rank N stays in System F only under simplified subsumption (D35, D36, D37).** The plan's T5 was "nested forall,
   with bidirectional checking", with no word on subsumption. Peyton Jones, Vytiniotis, Weirich and Shields 2007 (PVWS)
   give "a conservative extension of Damas-Milner" (p. 4) whose translation to System F inserts coercions that "after
   type erasure, are eta-expansions of the identity function" (p. 33); they come from the subsumption judgement with
   deep skolemisation and the prenex conversion it rests on (§4.6.2, p. 22; Figure 11, p. 32). GHC proposal 287,
   implemented in 9.0, removed covariance and contravariance of function types, deep skolemisation and deep
   instantiation, because "all four change the semantics of Haskell, by performing eta-expansion, changing bottom into
   non-bottom" (`GP/0287-simplify-subsumption.rst:17-24`). The cost was measured: of 457 compilable Stackage LTS 13.6
   packages using RankNTypes, Rank2Types or ImpredicativeTypes, 399 needed no change, and the remaining changes were
   almost all one eta-expansion each (Serrano et al. 2020, Appendix A, p. 30). So T5 under simplified subsumption
   elaborates to plain System F with no coercion, and deep skolemisation would be a change of meaning in D36's sense
   [inferred]. GHC's own `Haskell2010` edition still turns DeepSubsumption on (*What the implementations do*).
4. **Finalizers are C functions, and run before exit (D30).** The plan listed "finalizers or weak pointers" among Rune's
   gaps without saying which finalizers. The FFI Addendum: "Finalizers in Haskell cannot be safely realised without
   requiring support for concurrency" (Chakravarty 2003, p. 20, printed p. 14, a footnote citing Boehm), and "The only
   guarantee is that the finalizer runs before the program terminates" (pp. 20-21, printed pp. 14-15). The 2010 Report
   keeps both: "A finalizer is represented as a pointer to a foreign function", and "There is no guarantee of
   promptness, however the finalizer will be executed before the program exits" (29.1, 29.1.1). In 2001 `newForeignPtr`
   still took a Haskell `IO ()` action (Peyton Jones 2001, p. 41); the Addendum changed it. Boehm 2003 [abstract] argues
   that finalizers' asynchrony "is necessary for correctness of client code" (p. 1). So rhc's finalizers run no Haskell
   code and need no prompt collector: running the C finalizers at `finalizeForeignPtr` and at exit meets the text. E10
   sizes that at an exit hook in rhc and about 80 library lines, with no Rune change, and leaves finalization driven by
   the collector for later (D30). A `wrapper` FunPtr passed as a `FinalizerPtr` would run Haskell code at finalisation;
   nothing in the 2010 text forbids it, so D30 must say whether rhc refuses it.
5. **Today's unifier or a solver is a false choice (D34).** The plan set the two against each other, with a solver as
   98's D31 option C reopened. Jones 2000 shows both forms of fundep improvement need only unification: "we can use
   unification to ensure that the equalities are satisfied", and "we will, in general, need to iterate this process
   until no further opportunities for improvement can be found" (§6.2, p. 12). Hugs does exactly that in C, a loop to a
   fixpoint (`Hugs/src/subst.c:1480-1500`), and so does MicroHs, which solves equalities "incrementally using
   unification in the usual way" and class constraints "at certain points" (Augustsson 2024, p. 2), then performs the
   improving unifications and solves again (`MicroHs/src/MicroHs/TypeCheck.hs:3716-3741`). OutsideIn(X) says where the
   line is: "Type inference for HM(X) is tractable: it boils down to constraint solving for existentially quantified
   conjunctions of primitive constraints"; GADTs' local constraints and top-level axiom schemes go beyond it (p. 5).
   This is **A+**: 98's option A with a deferred store of class constraints solved at generalisation, and improvement as
   iterated unification. Implications are needed only for T4b and T6 [inferred].
6. **The fundep conditions mtl needs lose termination (D34, D35).** The plan named no regime for T2. The FD-Conditions
   (Coverage, Consistency, Bound Variable) give sound, complete and decidable inference with Haskell 98's instance rules
   (Sulzmann, Duck et al. 2007, Corollary 1, pp. 20-21) or with the Paterson conditions (Corollary 2, p. 22). But
   "weakening the Coverage Condition loses the global termination property" (p. 27), and with the Weak Coverage
   Condition "the resulting CHRs can be non-confluent" unless the dependencies are full (p. 26). The monad library's
   `instance (Monoid w, MonadReader r m) => MonadReader r (WriterT w m)` breaks Coverage (Example 19, p. 29); the
   Terminating Weak Coverage Condition, which asks that the range be a variable, admits it (Definition 14, p. 30). The
   Haskell' page on fundeps says GHC and Hugs relax coverage and that "this relaxation breaks the guarantees of
   termination and coherence" (`HP/FunctionalDependencies.txt:158-168`); Hugs bounds the search with a depth limit
   instead (`Hugs/docs/users_guide/hugs_ghc.xml:200-205`). Which regime HsLint must specify is D35's.
7. **The Report's five names are GHC's (D4).** The plan expected the Haskell' proposal names to need a decision. The
   accepted LanguagePragma delta encouraged ten names (`HP/LanguagePragma.txt:71`). Reviewing the draft Report, Ian
   Lynagh asked "Does anything support these?: DoAndIfThenElse, HierarchicalModules, FixityResolution,
   LineCommentSyntax, LanguagePragma", whether "RelaxedDependencyAnalysis" should be "RelaxedPolyRec", and that
   "EmptyDataDeclarations" be "EmptyDataDecls" (`ERR/haskell-prime-2010-May.txt:449-453`). The Report's 12.3 encourages
   five: PatternGuards, NoNPlusKPatterns, RelaxedPolyRec, EmptyDataDecls, ForeignFunctionInterface, all GHC's spellings.
   Its example changed too, from `ForeignFunctionInterface, CPP` to `ScopedTypeVariables, CPP`. Six of the ten Haskell'
   names are not GHC names (RelaxedDependencyAnalysis, EmptyDataDeclarations, FixityResolution, LineCommentSyntax,
   HierarchicalModules, LanguagePragma: E5's `names.tsv`), and nobody implemented them; accepting them as aliases is the
   owner's question.
8. **Rule (s) of the pattern-guard semantics has a dangling side condition (D14).** Erwig and Peyton Jones bind the
   fall-through expression once, in `case e' of { y -> ... _ -> y }` with `y` a new variable (p. 5). The Report's Figure
   3.3 (3.17.3) copies `e'` into each alternative but keeps "where y is a new variable", with no `y` in the rule, in the
   PDF and the HTML alike. It is harmless to the meaning and a defect of the text (*Found while writing*). The desugarer
   should bind `e'` once, as a join point, as rules (c) and (m) do [inferred].

### Modes and tracking (D1-D12)

**What 2010 was meant to be (D1, D3).** The preface calls Haskell Prime "a relatively conservative extension of Haskell
98, taking on board new features only where they were well understood and widely agreed upon", and 2010 the first of
yearly revisions "each revision integrating only a small number of well-understood extensions and changes". It lists
four changes: the FFI, hierarchical names, pattern guards, and n+k removed. The committee expected implementations to
keep several editions behind a flag: "We expect that GHC will support a number of previous revisions to the language,
with a flag such as -language-revision=2010. Individual extensions can be enabled and disabled separately as usual"
(`HP/Process.txt:115-117`), with major revisions "supported for longer" (`:101-104`); and of 98, "Implementations may
choose to remain backwards compatible (by retaining a Haskell98 flag, for example)" (`HP/Principles.txt:11`). Marlow's
announcement of the final ten said "Compilers can start implementing the changes, and flags to select the Haskell 2010
revision" (`HPM/haskell-2009-11-021750.txt:61-62`). Nothing in the literature ties a default flip to extensions; D3
rests on G2.

**How the ten were chosen.** In April 2009 the status page listed as accepted, besides the ten: KindAnnotations,
ScopedTypeVariables, InfixTypeConstructors, ExistentialQuantification, PolymorphicComponents, "add RankNTypes or
Rank2Types", MultiParamTypeClasses, removing the monomorphism restriction, Concurrency and NondecreasingIndentation
(`HP/Status-20090427.txt:45-83`); and as undecided FunctionalDependencies, AssociatedTypes, overlapping and undecidable
instances, GADTs, FlexibleContexts and FlexibleInstances (`:145-247`); implicit parameters were rejected (`:121`). The
committee had already split the work "so that we could defer the difficult topic of Functional Dependencies and Type
Families until later" (`HP/Process.txt:13-15`). In July 2009 Marlow marked everything not yet in the draft Report "old"
and limited the first revision to extensions "either already fully specified (i.e. the FFI) or are small and
well-understood" (`HPM/prime-2009-07-002812.txt:35-37, 61-62`). NondecreasingIndentation and QualifiedOperators were on
that provisional list and gone by November; LanguagePragma was added (`HPM/haskell-2009-11-021750.txt:26-35`).

**The library was left to implementations (D1, D2, D23).** Editing the Report in April 2010, Marlow found that a
`haskell2010` package re-exporting `base` makes imports ambiguous for a program that uses both, and "The Prelude is a
bit of a thorny issue too"; he gave two non-options and three options and asked for ideas
(`HPM/prime-2010-04-003158.txt:37-88`). Wallace: "The committee's decision is clear enough. The question is to do with
implementation issues that are not specified by the Report" (`HPM/prime-2010-04-003161.txt:27-28`). Allbery proposed
that 2010 code say `{-# LANGUAGE Haskell2010 #-}` "to distinguish from Haskell '98 code (no LANGUAGE pragmas)"
(`ERR/haskell-prime-2010-May.txt:619-628`); the Report requires only that the pragma be supported. So rhc's choice of a
library per program, with an edition pragma choosing a module's rules and not its library, is the problem the committee
left open, answered the way GHC answers it; the literature has no better answer [inferred]. GHC2021 has no `No` form
either: "there is no `-XNoGHC2021`" (`GP/0380-ghc2021.rst:42`).

**The pragma (D4-D7).** 12.3 is the LanguagePragma delta nearly word for word (`HP/LanguagePragma.txt:61-71`). A
file-header pragma "must precede the module keyword", and pragmas "can be preceded or followed by comments". An unknown
feature, or a combination the implementation "cannot support", means that "any attempt to compile or otherwise use that
file ... must fail with an error"; "multiple attempts to enable the same, supported language features ... are
specifically permitted". Nothing E11 read covers literate files, case, or where after comments a pragma stops counting:
those rules are GHC's (*What the implementations do*). The proposal cited SRFI 0, Scheme's feature-based conditional
expansion (`HP/LanguagePragma.txt:45-47`); the Report has no feature test, so rhc need offer none [inferred].

**One name, one meaning (D4).** The Haskell' page on scoped type variables: "although GHC and Hugs use the same syntax,
the meaning of type variables is quite different" (`HP/ScopedTypeVariables.txt:58`). A name does not fix a semantics
across compilers, so rhc's table must say that its names mean GHC 9.14.1's [inferred].

**Interfaces (D9).** "Only 'specified' type parameters can be instantiated via explicit type applications", and "Type
parameters from user-supplied types of imported functions are specified" (Eisenberg, Weirich and Ahmed 2016, p. 7). So
TypeApplications needs each scheme to keep the order its user wrote, across interfaces; `TGen` numbering loses it
[inferred].

**CPP (D12).** Both the proposal and the Report use CPP as their example of a pragma; what Hackage asks of CPP is E7's
(D12). The only Haskell implementation of CPP to hand is cpphs 1.2 in Hugs's tree: 1,100 lines of Haskell in
`Language/`, 1,318 with its parser library (`results/E11/cpphs-wc.txt`), with options `--unlit`, `--layout` and
`--hashes` for Haskell's needs (`Hugs/cpphs/README:17`). It is LGPL (`Hugs/cpphs/cpphs.cabal:5`), so it sizes D12's
option A, an SML subset written afresh, at about a thousand lines, and is not a source to copy [inferred].

### Front end (D14-D18)

**Pattern guards (D14).** The Haskell' page took the Report delta from Erwig and Peyton Jones: "the required changes to
the Report are clearly laid out in the above paper" (`HP/PatternGuards.txt:43`). The paper claims, without proof, that
the extension is upward compatible and every existing program keeps working (p. 1). Its semantics is by rewriting to
`case` (p. 5). On match compilation it says that the standard technique for efficient matching trees "can be adapted
straightforwardly" to pattern guards, and asks how many times a view function is then called (p. 5). For 98's D34
(Sestoft's trees at `-O2`) the open point is order: a guard's expressions may run only after its clause's patterns have
matched, so a tree must not evaluate a qualifier earlier than the Report's top-to-bottom, left-to-right order would
[inferred]. In the 2010 text a `let` in a guard scopes over the rest of the guard and the right-hand side (Figure 3.3,
rule (u)). GHC's coverage checker desugars every pattern form, pattern guards included, into guard trees, and "guard
trees only have three different constructs" (Graf, Peyton Jones and Scott 2020 [abstract], p. 1); rhc warns of no
non-exhaustive match (its one test of exhaustiveness is in lowering, `lib/language/haskell/coretomid.sml:1109`), so this
matters only if warnings are added.

**Relaxed dependency analysis (D16).** The Haskell' delta became 4.5.1 word for word. Its notes say the old
transformation "is no longer always possible" (`HP/RelaxedDependencyAnalysis.txt:109`), and its source is Mark Jones's
suggestion, "most compilers already implement this" (`:59`): Typing Haskell in Haskell §11.6.3, "In the presence of
explicitly typed bindings, we can refine the dependency analysis process a little further" (Jones 1999, p. 34). HsLint
already transliterates THIH, in the form 11.6.3 calls conformant to 98 (`lib/language/haskell/hslint_infer.sml:1-4`), so
2010's rule is the paper's other form. The page lists GHC, nhc98, Hugs, UHC, JHC and LHC as "full"
(`HP/RelaxedDependencyAnalysis.txt:24-36`); for nhc98 1.22 the source says otherwise (*What the implementations do*).
The 2009 status page rejected MonomorphicPatternBindings and two variants of making the monomorphism restriction
optional (`HP/Status-20090427.txt:127-133`) while "Remove the monomorphism restriction" was accepted (`:53`) and later
went "old"; 2010 adopted neither, so 4.5.2's sentence that signatures in one declaration group have identical contexts
remains, reachable now only through one pattern binding of two signed variables. That keeps R21(b) live in 2010
[inferred].

**Small syntax (D17).** DoAndIfThenElse was "recently added to jhc, GHC and Hugs" in 2009, and the extension to
`case ... of` "is not part of the proposal as accepted for Haskell 2010" (`HP/DoAndIfThenElse.txt:72, 77`).
LineCommentSyntax: in 98's grammar a sequence beginning `--:` is a comment, which "appears to be unintentional"; 2010
took Ross Paterson's fix, moving `:` into `symbol` (`HP/LineCommentSyntax.txt:10-21`). n+k: the reason it survived 98
was that "some Haskell books use it" (`HP/RemoveNPlusK.txt:27`); GHC's switch dates from 6.12, nhc98's is `--nonplusk`,
and UHC never had n+k (`HP/NoNPlusKPatterns.txt:11-17`).

**Fixity resolution (98 alignment).** The proposal "doesn't affect anything except the presentation of the report,
because all Haskell implementations currently do it this way anyway"; `\x -> x == x == True` was legal 98 and "As far as
I know, no Haskell compiler gets this right" (`HP/FixityResolution.txt:29, 35-47`). This supports R1 and R9 as rhc read
them; under 2010 they are the text (*Haskell 98 mode and the 2010 text*).

**Empty data (D15).** The proposal: "syntactically allow all deriving clauses for empty data, but semantically limit the
clauses to deriving ()" (`HP/EmptyDataDecls.txt:97-99`). Lynagh found Hugs refusing `data Foo deriving ()`, and Marlow
answered "Yes, it's legal according to the grammar" (`ERR/haskell-prime-2010-May.txt:424-428, 864`).

**Hierarchical names (D18).** The delta is the 2003 addendum: `modid` becomes a dotted `qconid`. It "steals one
extremely rare construction from Haskell 98": `A.B.C.D` was a composition and is now a qualified name (Marlow and
Wallace 2003, p. 5). The mapping of modules to files "is not part of the specification" (p. 5), so `--dotted-names`'
file layout is rhc's own choice.

### FFI (D27-D33)

**What changed from the Addendum.** The script split the Addendum's language part and its HsFFI.h section (FFI 1.0,
sections 1-4 and part of 6.1) and the Report's chapter 8 into sentences: 245 and 261; 202 the same, 25 changed, 18 only
in the Addendum, 39 only in 2010, some of those 39 being 8.6's introduction, which the Addendum has in a section outside
the range compared (`results/E11/ffi/ch8.summary.txt`, `ch8.tsv`). Read sentence by sentence, the changes are four:

| What | Addendum 1.0 | 2010 | Decision |
|---|---|---|---|
| Strictness | "External functions are generally strict in all arguments" (p. 11, printed p. 5) | "External functions are strict in all arguments" (8.4.2) | D32 |
| Marshallable argument | "a basic foreign type or (2) a type synonym or renamed datatype of a marshallable foreign type" (p. 11, printed p. 5) | a basic type, a synonym, or a newtype whose constructor "is visible where T is used"; "the type must not be exported abstractly" (8.4.2) | D9, D32 |
| Marshallable result | a marshallable type, `()`, or `IO t` (p. 11, printed p. 5) | also synonyms and visible newtypes of result types, so a newtype over `IO` (8.4.2) | D32 |
| Threads | thread-local state "not sufficiently mature to be included into Version 1.0" (p. 7, printed p. 1) | "currently implementation-defined" (8.1) | D31 |

The Haskell' page says why the newtype rule changed: "Only if its constructor is visible, can the newtype be
transparently marshalled", against "the FFI addendum (and it's implementation in GHC)"; and "We allow GHC's newtype
wrapping of the IO monad" (`HP/ForeignFunctionInterface.txt:112-116`). So the marshallability check needs, across an
interface, a newtype's representation and whether its constructor is in scope where the foreign declaration is (D9, D32)
[inferred].

**What stayed, and binds rhc.** A safe call "guarantees to leave the Haskell system in a state that allows callbacks",
and "a callback into the Haskell system implies that a garbage collection might be triggered after an external entity
was called, but before this call returns" (8.4.3). `dynamic`, `wrapper`, `&` imports and `foreign export` are unchanged.
HsFFI.h must declare `hs_init`, `hs_exit`, `hs_set_argv`, `hs_perform_gc`, `hs_free_stable_ptr` and `hs_free_fun_ptr`;
`hs_init` may be called again after `hs_exit` (8.7). The libraries took hierarchical names; `unsafePerformIO` became
`Foreign.Marshal.unsafeLocalState`, allowed only local allocation, pointer operations on it and foreign functions whose
only observable effect is on that memory (chapter 30); an alignment guarantee was added; and `finalizeForeignPtr`,
`ptrToIntPtr`, `castCharToCUChar`, `withArrayLen` and `throwErrnoPath*` are new
(`HP/ForeignFunctionInterface.txt:53-104`; counts in both texts, `results/E11/ffi/lib-counts.tsv`).
`Foreign.Marshal.Pool` was left out "as it doesn't appear to be widely used" (`:84`).

**Why it is shaped so.**
- *Pure imports (D32).* "The non-IO type indicates that the programmer takes on a proof obligation" that the procedure
  is a function (Peyton Jones 2001, p. 37). Strictness in all arguments is now the text's, not a "generally".
- *`Ptr` (D29).* Pointers are "'Uninterpreted' in the sense that they are treated simply as bit patterns. The Haskell
  garbage collector does not follow the pointer" (Peyton Jones 2001, p. 37, footnote 9). Raw addresses are the design,
  which Rune's opaque pointers are not.
- *`wrapper` (D27, D31).* Making a C function pointer from a Haskell closure means to "register the Haskell value as a
  stable pointer ... and then embed the stable pointer in the C function", freed explicitly (Finne et al. 1999, p. 4),
  and a code fragment made at run time (p. 5). So `wrapper` needs StablePtr-like roots and C entry points made at run
  time, which Rune's libffi closures give only during a native call [inferred]; E10 built `wrapper` that way, within
  that limit (D27, D31).
- *Callbacks (D31).* 8.4.3 places a callback "after an external entity was called, but before this call returns", so
  Rune's rule that callbacks arrive only during a native call is a reading of the text, not a gap [inferred].
- *Threads (D31).* The FFI and Concurrent Haskell "were specified independently, but their combination is quite tricky"
  (Marlow, Peyton Jones and Thaller 2004, p. 1). 2010 leaves threads implementation-defined, so a single-threaded rhc
  whose callbacks arrive only while Haskell is inside a safe foreign call on its own thread meets chapter 8; Rune's
  limit of 64 nested callbacks is in no text and is an implementation limit to document [inferred].
- *Finalizers (D30):* correction 4 above.
- *Partial FFIs (D28).* Hugs implements no `foreign export`. MicroHs's paper says its FFI "is basically limited to
  foreign import ccall" and that "Some FFI libraries are missing, like Foreign.StablePtr" (Augustsson 2024, p. 1), but
  the tree of record, 0.16.12, has `foreign export`, `dynamic` and `wrapper` imports, an HsFFI.h and Foreign.StablePtr
  (*What the implementations do*). The 2010 text admits no exception, so leaving `foreign export` out is a deviation,
  and none of D38's grounds (wrong, contradictory, ambiguous, conceded) covers leaving out a required feature: only the
  owner's explicit word can make it one (D28) [inferred].

### Extensions: the checker (D34)

**Vocabulary.** Jones's qualified types (Jones 1992) are the theory of 98's checker. Jones 1995 [abstract] adds "two new
rules, one for simplification and one for improvement", which permit "a better treatment of the previously troublesome
multiple parameter extensions" (p. 1); an improvement is a substitution that leaves satisfiability unchanged, so it may
be applied at any time (restated in Jones 2000, p. 12). HM(X) (Odersky, Sulzmann and Wehr 1999 [abstract]) parameterises
Hindley-Milner by a constraint system; today's checker with a store of class constraints is HM(X) with X Haskell's
classes [inferred].

**Precedent for A+.** Correction 5. Two implementations of T1, T2, T4a and T5 exist without implication constraints:
Hugs (T5 at rank 2 only) and MicroHs (with no escape check for existentials; *What the implementations do*). Both defer
class constraints and loop improvement through the unifier. MicroHs is under 10,000 lines of Haskell, "out of which the
type checker is about 30%" (Augustsson 2024, p. 1).

**What A+ must still refuse.** Improvement from a given (correction 2); a given on a universal variable (correction 1);
deep subsumption (correction 3). Each refusal is where GHC also draws a line or once did: GHC refuses the first, older
GHCs could not do the second, and GHC 9.0 dropped the third.

**What HsLint can follow (D41).** Each type extension needs an independent specification, and the literature has short
ones: Jones 2000 §6 for T2, three pages (coverage and consistency, §6.1; improvement, §6.2; ambiguity modulo the closure
of determined variables, §6.3; generalisation over `T \ V+` only, §6.4; pp. 12-13); Läufer 1996 for T4a, three rules,
CONS, TEST and PAT, the last for "pattern-matching let-expressions" (p. 17); PVWS 2007 for T5, which give "a complete
implementation of Damas-Milner" and then "all the changes needed to make it work at higher rank" (p. 4), or Dunfield and
Krishnaswami 2013, a declarative and an algorithmic system for "predicative System F", proved complete (p. 1). Neither
T5 source has type classes. HsLint's second inference has no rigid variables today: it instantiates a signature with
flexible variables, requantifies and compares (`lib/language/haskell/hslint_infer.sml:698-722`; E6, X2), so T3-T5 each
cost it a skolem and an escape check.

**Let should not be generalised.** Vytiniotis, Peyton Jones and Schrijvers 2010 list among the extensions that make
local let-generalisation hard "functional dependencies (Jon00), GADTs ..., and type functions" (p. 1). Without local
generalisation 20 of 533 modules of GHC's libraries (3.7%) needed changes, 127 lines, and 95 of 793 Hackage packages
(12%) failed to compile (p. 5). MonoLocalBinds therefore rejects valid 2010 programs; GHC implies it only from GADTs,
TypeFamilies and LinearTypes (E5), and in rhc it must never be implied by a T1-T5 feature (T8, D36) [inferred]. The
paper's argument is that T6 needs it, so the OutsideIn roadmap inherits the question.

### Extensions: the tiers (D35, D36)

**The committee's line.** History of Haskell §6.5: the 98 committee kept classes to one parameter because more "would be
an unforced step into the dark, and we were anxious about questions of overlap, confluence, and decidability of type
inference" (Hudak et al. 2007, p. 19). §6.6: fundeps "have turned out to be extremely tricky in detail, especially when
combined with other extensions such as local universal and existential quantification" (p. 20). The 2006 straw poll on
fundeps split three ways: MPTC and fundeps in, 10 votes; delay MPTC until associated types are tested, 11; delay the
standard until fundeps or associated types win, 4, among them Peyton Jones (`HP/StrawPoll-FDs-20060921.txt:9-19`). The
2009 status page drew the line at T2/T6 (above). GHC2021 drew nearly the same one: MultiParamTypeClasses,
FlexibleContexts, FlexibleInstances, RankNTypes, ExistentialQuantification, ScopedTypeVariables, KindSignatures,
TypeApplications, GADTSyntax, PolyKinds and ConstraintKinds in; FunctionalDependencies, GADTs and TypeFamilies out
(`GP/0380-ghc2021.rst:23-30`). Peyton Jones, Jones and Meijer 1997, on classes alone, recommend as "an upward-compatible
extension of Haskell without losing anything important": multi-parameter classes, arbitrary contexts, reduction by
instances only when forced by a signature (2d, with 2e "also viable"), no overlap (3a), repeated variables in heads,
instance contexts on variables only, free superclass contexts, and "Prohibit improvement (Choice 8a)" (p. 15). Three
independent sets agree on MPTC, existentials, rank N, scoped type variables and kind annotations, and leave out GADTs
and type families; fundeps are the one item they split on, and mtl needs them (correction 6). The GHC2021 committee's
Hackage counts of 2020 still rank the extensions much as the Stackage snapshot of 2026 does (Spearman's rho 0.869 over
106 names, E7, `results/E7/ghc2021-crosscheck.tsv`).

**T1.** With free contexts, "context reduction is forced only by" explicit signatures, the type of `main`, the
monomorphism restriction, the existentials' no-escape rule and the remaining restrictions on contexts
(`HP/FlexibleContexts.txt:83-93`); deferring "delays (and sometimes avoids) type errors" and "is required by
OverlappingInstances" (`:120-124`). Overlap: "A program that type checks can have its meaning changed by adding an
instance declaration" (`HP/OverlappingInstances.txt:52`), and "Hugs compares instance declarations, while GHC delays
tests until the instances are used" (`:67`). Undecidable instances: "the boundary between legal and illegal programs is
unclear, and possibly implementation-dependent" (`HP/UndecidableInstances.txt:45`). The fundep page expected neither
overlap nor undecidable instances in Haskell' (`HP/FunctionalDependencies.txt:292`).

**T2.** Jones 2000 §6 is the specification (above). The fundep page knows "(at least) three different versions of FDs,
none of which is satisfactory": Jones's, which "excludes some uses"; GHC's, which "makes type checking undecidable"; and
Chameleon's, which "Needs type inference based on constraint handling rules" (`HP/FunctionalDependencies.txt:81-87`).
Jones and Diatchki 2008 take covering and consistency "as both necessary and sufficient" (p. 4), and say the
interactions of fundeps with overlap, higher rank, existentials and GADTs "have not, to the best of our knowledge, been
formally studied" (p. 8). Morris and Jones 2010 [abstract] offer instance chains in place of overlap; no other
implementation has them.

**T3.** Peyton Jones and Shields 2004 (a draft) contrast "two main alternative designs", SML 97's "type-lambda" and the
"type-sharing" of GHC and OCaml (p. 1). GHC's ScopedTypeVariables "was never properly specified"; Eisenberg, Breitner
and Peyton Jones 2018 specify it, with binding in patterns (p. 1). Visible type application is proved a conservative
extension of Hindley-Milner with principal types (Eisenberg, Weirich and Ahmed 2016, p. 1, Lemma 1 on p. 13).

**T4a.** Adding existentials to a language with classes "requires only a minor syntactic extension", and the extension
"has been implemented in the Chalmers Haskell B. system" (Läufer 1996, p. 1). The dictionaries travel with the value:
"the method dictionaries are packed implicitly with the component values" (p. 6). Läufer's PAT rule opens an existential
in a `let`; Haskell implementations differ there. "Hugs and Nhc98 allow matching on an existentially quantified
constructor in a pattern binding declaration, except at the top level"; GHC does not, nor in any irrefutable pattern,
and "It is said that the translation to GHC's intermediate language is problematic"; no implementation derives instances
for existential types (`HP/ExistentialQuantification.txt:126-138`). A lazy match must bind the type variable where no
`case` forces the value, which a System F Core whose `AltCon` binds the variable cannot say; rhc should refuse it, as
GHC does [inferred]. Läufer and Odersky 1994, the paper the page cites, was not read; Läufer's 1992 thesis and the 1992
ML Workshop paper (abstracts) and Läufer 1996 stand in for it.

**T5.** PVWS 2007: "The inference algorithm is only a little more complicated than the Damas-Milner algorithm" (p. 4),
and the system is predicative (§3.4, p. 10). The Haskell' page on rank N adds a test D36 can use: "Programs containing
no foralls are typeable if and only if they are typeable in Haskell 98" (`HP/RankNTypes.txt:96`). Hugs's rank 2 is a
cheaper subset: a signature is required, polymorphic arguments "can only be matched by a variable or wildcard" pattern,
and "the polymorphic arguments must be supplied" (`Hugs/docs/users_guide/hugs_ghc.xml:396-407`); polymorphic components
are "a simple extension of Hindley-Milner" (`HP/PolymorphicComponents.txt:80`), the theory being Jones 1997's
first-class polymorphism, prototyped as "an extension of the Hugs implementation of Haskell" (p. 12). Boxy types
(Vytiniotis, Weirich and Peyton Jones 2006 [abstract]) are the impredicative design jhc's checker follows (*What the
implementations do*).

**Meaning changes (D36).** The literature names, as changing the meaning of programs that were valid without them:
overlapping instances (adding an instance changes meaning, above); implicit parameters with the monomorphism
restriction, where "in an effort to preserve sharing, we have altered our language semantics" and "the monomorphism
restriction is the wrong solution to the sharing problem" (Lewis et al. 2000, p. 9); MonoLocalBinds (12% of packages
fail, above); FlexibleContexts' deferred reduction, which moves errors; and deep skolemisation, whose eta-expansions
turn bottom into non-bottom. Rank N (PVWS) and visible type application (Eisenberg et al., with a proof) are stated to
be conservative; pattern guards are claimed so, without proof. The 98 committee's choice 2d also changes when reduction
happens and so which types are inferred, though Peyton Jones, Jones and Meijer call the set upward compatible
[inferred].

### Extensions: the boundary and Core's target (D37)

System FC's paper states the limit of System F as a target: "Unlike System F, FC is expressive enough to serve as a
target for several different source-language features, including Haskell's newtype, generalised algebraic data types,
associated types, functional dependencies, and perhaps more besides" (Sulzmann, Chakravarty et al. 2007, p. 1). Together
with corrections 1-3 that gives the partition [inferred from the sources cited there]:
- **System F suffices for:** T1; T2 without improvement from givens; T3; T4a, with type binders in `AltCon` and in
  `Data`'s constructors, which rhc's Core lacks (`lib/language/haskell/core_sig.sml:77, 87`); T5 under simplified
  subsumption.
- **A cast of a whole dictionary** for GeneralizedNewtypeDeriving and DerivingVia; rhc's `Cast` is only "into or out of
  a newtype, at its head" (`core_sig.sml:73`). Roles were introduced to resolve "the interaction of newtype coercions
  with type families" (Breitner et al. 2014, p. 2); without type families or GADTs no unsoundness of reusing a
  dictionary through a newtype is known, so roles can wait for T6 [inferred].
- **FC** for T4b, GADTs (Peyton Jones et al. 2006 [abstract]), type families and associated types (Chakravarty et al.
  2005 [abstract]), and full fundeps (Karachalias and Schrijvers 2017).
- **T7** promotes data types and polymorphism into kinds (Yorgey et al. 2012 [abstract], p. 1); rhc's Core kinds are
  `Star`, `Unlifted` and `Arrow` (`core_sig.sml:27-30`), so T7 needs kind variables in Core, which is a change of its
  own though not FC [inferred].

Untyped cores sidestep the question: UHC's Core is "an untyped, lazy functional language" (Dijkstra, Fokker and
Swierstra 2009, p. 1), and MicroHs compiles to combinators. rhc's Core is typed and linted, so D37 is a real choice for
rhc. UHC's stepwise variants also show the order in which an implementation built in layers can take these: higher
ranked types and existentials at EH4, before data types (EH5) and classes (EH9) (Dijkstra, Fokker and Swierstra 2007,
Figure 3, p. 117 of the proceedings).

### Testing (D38-D41)

The literature has nothing on testing a Haskell 2010 implementation beyond what the 98 roadmap found for 98 (98's D52,
98's D55). What it gives this roadmap's tests:
- **A conservativity test for each type extension** that claims one: rank N's "no foralls" theorem, visible type
  application's Lemma 1, pattern guards' claim. Each is a relation D36's tests can check on the 2010 corpus: with the
  extension on and no use of it, the bytes are unchanged.
- **Oracles' known gaps (D39).** GHC cannot turn RelaxedPolyRec off: "You can't turn off RelaxedPolyRec any more"
  (`ghc/compiler/GHC/Driver/Flags.hs:116-117`); so it is no oracle for 98's stricter rule, and its `bugs.rst` still
  lists the refined analysis as a divergence from both Reports, which is stale for 2010. MicroHs does deep skolemisation
  and no escape check for existentials, so it cannot judge T4a or T5. Hugs has rank 2 only, a different
  ScopedTypeVariables, and checks overlap when instances are declared. *What the implementations do* has the rest.
- **HsLint parity (D41):** each type extension costs a second specification; the sources above are short enough to be
  followed independently, which is what 98's D54 requires of HsLint.
- **The mistakes reported against the 2010 draft on the haskell-prime list,** and the absence of published errata, are
  E1's (*What the 2010 Report says*).

## What the implementations do

Nine systems were read for this roadmap: GHC, Cabal, haskell-src-exts, jhc, Hugs, nhc98, MicroHs, UHC and Helium. The
questions were three: how each selects an edition and its extensions, which of 2010's changes and which type extensions
it implements, and so what each can judge as an oracle (D39). Only GHC was run. The answer for D39 is that GHC 9.4.7 is
a usable judge of 2010 programs once a list of known departures is excluded, and that every other system falls short of
2010 in a place 2010 changed.

Sources:
- **E5** (agent X3) read GHC 9.14.1's resolution of settings and ran 137 probes on GHC 9.4.7, 129 of them as predicted
  from the source, and 37 diagnostic probes (`results/E5/semantics.md`, `probes/results.tsv`, `probes/diag-names.tsv`).
  It read Cabal, haskell-src-exts, jhc, Hugs, MicroHs and UHC on the same questions (`results/E5/others.md`,
  `others-names.tsv`).
- **E6** ran 41 probe modules on 9.4.7 under `-XHaskell2010`, each without and with its extension, 82 runs
  (`results/E6/X1-data/probes.tsv`). A sub-agent of X2's graded 55 type-level names over seven systems
  (`results/E6/X2-data/others.tsv`, method in `others-method.txt`); X2 spot-checked only part of it.
- **E11** read how Hugs, UHC, jhc, MicroHs and nhc98 implement MPTC, fundeps, existentials and higher rank; its 49
  citations were checked against the source by script (`results/E11/impl-citations.tsv`, `check_impl.out`).

Every citation below was opened again for this section, and the reports were checked against the source; where they were
wrong, the source is given. Paths are relative to `/home/ruud/haskell`; GHC's are under `ghc/`, the tree of
`ghc-9.14.1-release`, and Cabal's under `ghc/libraries/Cabal/`, the copy in that tree. Revisions are in *References*.

What limits it:
- **GHC's citations read 9.14.1; the binary is 9.4.7.** 11 of 9.14.1's 148 names are not in 9.4.7, among them
  OrPatterns, MultilineStrings, TypeAbstractions and the edition GHC2024 (E5 `names.tsv`); they are "source only".
- **What was run.** GHC throughout; E8 ran Hugs (`+98`), nhc98 and MicroHs on the 2010 corpus as well (results/E8/:
  summary.txt, judged.tsv, limits.tsv); jhc did not build (its configure needs six packages that are not
  installed: `jhc-prereqs.tsv`). Every other claim about Hugs, nhc98, jhc, MicroHs, UHC, Helium and haskell-src-exts is
  reading. "No" means looked for in the grammar, the
  checker or the documentation and not found there.
- **UHC's documentation is not in its tree**: it "moved to separate repo" (`uhc/EHC/changelog.md:30`), so its cells rest
  on its source, its variant list and its regression tests, and are the least certain.

### The systems at a glance

| System | What it says it is | Editions | Extension switches | Unknown name |
|---|---|---|---|---|
| GHC 9.14.1 (9.4.7 run) | "aims to be able to behave (mostly) like a Haskell 98 or Haskell 2010 compiler" | Haskell98, Haskell2010, GHC2021, GHC2024: flat sets, the last wins, default GHC2021 | 148 names, a `No` form for each extension, ordered steps, 38 implications | error |
| Cabal 3.16 | a build tool, passing settings to GHC | the four, as a field; `-XHaskell98` when the field is absent | 152 names with Enable, Disable and Unknown forms, no implications | refused at configure |
| haskell-src-exts 1.24.0 | a parser | Haskell98, Haskell2010; default Haskell2010 | 109 names; implications closed over the final set | dropped |
| jhc 0.8.2 | whole-program compiler to C | Haskell98 and Haskell2010 the same set | names mapped many to one onto its own flags; 12 always on | warned on the command line, dropped in a file |
| Hugs, September 2006 | interpreter | `+98`/`-98`, once per session | none: a LANGUAGE pragma is a comment | - |
| nhc98 1.22 | compiler | Haskell 98 with four extensions | no pragmas; n+k by a flag | - |
| MicroHs 0.16.12.0 | "an extended subset of Haskell-2010" | none | 72 always on; CPP the only switch | ignored |
| UHC | "almost all Haskell98 features and most of Haskell2010" | none read | 12 LANGUAGE names | not read |
| Helium 1.9 | a teaching subset of Haskell 98 | none | none | - |

The table's quotations: `ghc/docs/users_guide/bugs.rst:27-29`; `MicroHs` README before commit e2b24fbb, line 43 (E5
saved it as `results/E5/others-data/microhs-README-e2b24fbb-parent.md`, cited below as `README@e2b24fbb^`);
`uhc/EHC/hcar/20151116-UHC.tex:19`. The rest of the table is cited where each system is described.

### GHC: how it resolves settings

The design rhc takes from this is in *Tracking language settings*; the facts are these. Paths in this subsection are
under `ghc/compiler/GHC/`; probe ids are E5's.
- **State.** A module's setting is an optional edition and an ordered list of `On`/`Off` steps
  (`Driver/DynFlags.hs:374, 395`). The effective set is the edition's list with the steps replayed oldest first
  (`flattenExtensionFlags`, `Driver/DynFlags.hs:757-761`); no edition means GHC2021 (`Driver/Flags.hs:68-69`,
  `Driver/DynFlags.hs:1308`). An edition replaces only the edition (`lang_set`, `Driver/DynFlags.hs:1127-1132`):
  measured, `-XTupleSections -XHaskell2010` keeps tuple sections, `-XNoTupleSections -XGHC2021` loses them, and of two
  editions the last wins (E5 P02a-P02d).
- **Implications are steps.** Turning a flag on appends what it implies at that moment, recursively
  (`Driver/Session.hs:2979-2992`); turning it off undoes nothing, "When you un-set f, however, we don't un-set the
  things it implies" (`:2994-2996`). So `-XGADTs -XNoMonoLocalBinds` leaves MonoLocalBinds off and the reverse leaves it
  on (P04c, P04d). The table has 38 implications, three of them negative (`Driver/Flags.hs:286-359`; E5). Editions are
  not run through it, and GHC2021 is not closed under it: its TypeOperators lacks the ExplicitNamespaces it implies, so
  `module M (type T)` is refused under the default edition (P05a).
- **Pragmas come after the command line.** Each module's header pragmas are parsed as more flags on top of the command
  line's (`Driver/Pipeline/Execute.hs:658-667`, `Driver/Session.hs:825-829`), in text order; the command line cannot
  override a module's pragma (P03b).
- **The header.** Pragmas and comments up to the first other token (`Parser/Header.hs:297-298`). The keyword is
  case-insensitive (`clean_pragma`, `Parser/Lexer.x:3520-3521`) and the names are case-sensitive: `LANGUAGE Cpp` is
  "Unsupported extension" (P09h). A LANGUAGE pragma after `module` is ignored with a warning, "Misplaced LANGUAGE
  pragma" (P10a). The header is read from unlit's output, again after CPP, and once more after any preprocessor
  (`Driver/Pipeline.hs:709-742`): a pragma inside `#if 0` does not count (P13b), and CPP must be on before the first `#`
  line (P13c).
- **Per module, and no library.** Nothing crosses a module boundary (P15a). The interface fingerprint covers the edition
  and the flattened set (`Iface/Recomp/Flags.hs:48-50`). An edition chooses no library: under
  `{-# LANGUAGE Haskell98 #-}`, `import Monad` is "Could not find module 'Monad'" (P17e).
- **Errors.** An unknown name is an error in a pragma, on the command line and in `OPTIONS_GHC` (P09a-P09c). No
  combination of extensions is refused when flags are parsed (`makeDynFlagsConsistent`, `Driver/Session.hs:3592` on,
  tests none). Safe Haskell is the exception: two modes are an error, and Safe turns GeneralizedNewtypeDeriving,
  DerivingVia and TemplateHaskell off with only a warning (`Driver/Session.hs:578-603`; P16c).
- **Diagnostics.** Of 35 refusals under `-XHaskell2010`, 26 name the extension that would accept the construct; the 9
  that do not are all decided in the lexer, and come out as plain parse errors (`results/E5/probes/diag-names.tsv`).
  `forall` under Haskell2010 suggests RankNTypes, not ExplicitForAll (D-scoped).

### Where GHC departs from the 2010 Report

GHC keeps its own list, "the known deviations from the standards", which apply "in both Haskell 98 and Haskell 2010
mode" unless the entry says otherwise (`ghc/docs/users_guide/bugs.rst:24-31`). By the Report's chapters:
- **Lexical** (`bugs.rst:35-120`): `M.\` is one qualified operator; `forall` "is always a reserved keyword"; `!` in
  prefix form is a bang pattern, and `~` and `@` likewise depend on spacing, as do strictness annotations (GHC proposal
  229); decimal literals take ASCII digits only; identifiers accept more Unicode classes than the Report; `((f)) x =` is
  accepted.
- **Context-free syntax** (`:124-179`): NondecreasingIndentation in Haskell 98 mode only; no fixity resolution while
  parsing, as Haskell 98 (but not 2010) requires.
- **Expressions** (`:186-237`): eta-expansion makes some programs more defined, unless `-fpedantic-bottoms`; a failable
  pattern in `do` needs MonadFail.
- **Binding groups** (`:241-288`): the dependency analysis ignores references to variables with a signature. This is
  2010's 4.5.1 itself, so the entry is a divergence from 98 only and is stale for 2010. GHC cannot turn it off: "You
  can't turn off RelaxedPolyRec any more" (`ghc/compiler/GHC/Driver/Flags.hs:116-117`).
- **Modules** (`bugs.rst:292-350`): `-main-is` changes the default export list; recursive modules need `hs-boot` files.
- **Classes and the library** (`bugs.rst:357-481`): Num has no Show or Eq superclass; Bits has no Num superclass; Read
  has two extra methods; Monad has an Applicative superclass; five extra instances; `array` does not check duplicate
  indices; `splitAt` is strict in its first argument; derived Show parenthesises records, "whereas Haskell 2010 calls
  for" `Just Hello {aField=42}`; `read` of integers accepts hexadecimal, octal and binary; `isAlpha` accepts caseless
  letters; `hGetContents` raises errors where 98 discards them.
- **FFI** (`bugs.rst:488-491`): `hs_init` after `hs_exit` is not supported, which 8.7 requires.
- **Implementation-defined** (`bugs.rst:505-565`): `maxBound :: Char` is `0x10FFFF`; `Int` arithmetic wraps modulo 2^n,
  the reading D21's B takes; tuples up to 64, their instances up to 15.

Beyond that list:
- **Two refusals of valid 2010 that bugs.rst does not list** (E6, X1, measured on 9.4.7 under `-XHaskell2010`):
  `x = 1_000` with a variable `_000` in scope is "Illegal underscores in integer literals" (`numund.hs`), and
  `f = Just.do id`, which 2010 reads as `Just . (do id)`, is "Illegal qualified 'Just.do' block" (`qualdo.hs`). So 9.4.7
  applies part of NumericUnderscores and QualifiedDo in every mode. For *Found while writing*.
- **The documented ones, measured:** `a !b = a + b` defining `!` is "Illegal bang-pattern", `1 !2` is "Bang pattern in
  expression context", and a type variable named `forall` is "Illegal symbol 'forall' in type" (`bang.hs`, `bang2.hs`,
  `forall.hs`; E5 P18a, P18f, P18o).
- **The editions are not the Reports** (`ghc/compiler/GHC/Driver/DynFlags.hs:1310-1349`). Haskell2010 is the Report's
  switches plus DeepSubsumption, ListTuplePuns and ImplicitStagePersistence. Haskell98 adds NondecreasingIndentation,
  "strictly speaking non-standard", kept because "Cabal uses -XHaskell98 by default unless you specify another language"
  (`:1320-1325`), and DeepSubsumption. 9.4.7's lists are the same less ListTuplePuns and ImplicitStagePersistence
  (`results/E5/editions-check.txt`); its Haskell2010 has DeepSubsumption [measured: `probes/api/tables-947.txt`]. So
  RankNTypes under `-XHaskell2010` subsumes deeply, inserting eta-expansions
  (`ghc/docs/users_guide/exts/rank_polymorphism.rst:212-222`), which D35's T5 does not.
- **NoPatternGuards refuses nothing.** `rnGRHS'` only adds a diagnostic (`ghc/compiler/GHC/Rename/Bind.hs:1474-1479`),
  which is a warning without a flag (`ghc/compiler/GHC/Tc/Errors/Ppr.hs:2428-2429`): "accepting non-standard pattern
  guards" (`pguard.hs`). GHC cannot judge a refusal of pattern guards.
- **The library is base, not 2010's,** and an edition chooses no other (above). GHC 9.14.1 ships no `haskell98` or
  `haskell2010` package (E5, section 3). An oracle for 2010 programs needs a shim, as the 98 campaign's did for 98 (E8).
- **Three errors in GHC 9.14.1's own documentation** (E6, X3): `ghc/docs/users_guide/exts/empty_data_deriving.rst:11`
  says EmptyDataDeriving is "Included in" Haskell2010, which the edition's list (`Driver/DynFlags.hs:1332-1349`), the
  Report (11, condition 6) and 9.4.7 (D-emptyderiving) contradict; `control.rst`'s edition lists omit ListTuplePuns; and
  `overloaded_strings.rst:52-54` says `length "foo"` defaults to String, where with base's Foldable `length` it is
  ambiguous (P18j). For *Found while writing*.

### How the others select editions and extensions

- **Cabal 3.16.** A closed table: `data Language = Haskell98 | Haskell2010 | GHC2021 | GHC2024 | UnknownLanguage String`
  (`Cabal-syntax/src/Language/Haskell/Extension.hs:47-62`), and `EnableExtension`, `DisableExtension` and
  `UnknownExtension` (`:110-118`) over 152 known names, a `No` prefix parsed (`:592-602`). Ten of the 152 are not GHC
  9.14.1 names, and two of GHC's are missing (E5). It resolves nothing itself: no implications, and deprecations for two
  names only (`:568-572`). It passes `-XHaskell98` when `default-language` is absent:
  `ghcOptLanguage = toFlag (fromMaybe Haskell98 (defaultLanguage bi))`
  (`Cabal/src/Distribution/Simple/GHC/Internal.hs:586`), then `default-extensions` and the old `extensions` field in
  order (`Cabal-syntax/src/Distribution/Types/BuildInfo.hs:282-285`); `other-extensions` is never passed. E7 measured
  what that default reaches: 1,262 module files in 423 components (309 packages) of the Stackage snapshot (2.55%) are
  Haskell 98 by it, and so get GHC's NondecreasingIndentation (`results/E7/editions.tsv`, README).
- **haskell-src-exts 1.24.0.** Knows Haskell98 and Haskell2010 only (`Exts/Extension.hs:105-106`); a GHC2021 pragma
  falls through to an unknown name and is dropped, "We just throw away UnknownExtensions" (`:749-750`). Its Haskell2010
  is DoAndIfThenElse, PatternGuards, ForeignFunctionInterface and EmptyDataDecls over the defaults, and its Haskell98
  NPlusKPatterns over them (`:729-735`). The last word on a name wins (`:722-725`), but implications are closed over the
  final set (`:744`, `impliesExts` at `:580-606`), so a `No` of an implied name never wins. Two different edition
  pragmas in one file void all of that file's pragmas (`Exts.hs:144-148`). The default is Haskell2010
  (`Exts/ParseMonad.hs:173`). It is a parser, and can serve printer tests, not judge a program.
- **jhc 0.8.2.** GHC's names map many to one onto jhc's flags: ExplicitForAll, ExistentialQuantification,
  ScopedTypeVariables, Rank2Types, RankNTypes and PolymorphicComponents all set `FO.Forall`
  (`jhc/src/Options/Map.hs:56-74`), the nearest precedent for D4. Haskell98 and Haskell2010 both erase the language
  flags and set the same three (`:73-77`): jhc does not tell 98 from 2010. Twelve names are accepted and ignored because
  jhc always has them, NPlusKPatterns and EmptyDataDecls among them (`:79-91`). Its list of GHC's other names is
  "imported from ghc simply to provide better warnings" (`:106`). An unknown `-X` flag prints "Unrecognized -X flags"
  and compilation goes on (`jhc/src/Options.hs:191-194`); in a file the list is dropped (`jhc/src/Ho/ReadSource.hs:40`).
  Pragmas are read from the first 2,048 bytes before preprocessing and again after it (`:30, 57-73`).
- **Hugs, September 2006.** Reads no LANGUAGE pragma: a search of `Hugs/src/` finds no code that reads one, so a pragma
  is a comment. One switch, `Bool haskell98 = TRUE` (`Hugs/src/opts.c:32`), set by `+98`/`-98`, and "Haskell 98
  compatibility cannot be changed while the interpreter is running" (`:520-529`). It gates lexing too: `?x`, `#x`,
  `forall` and `mdo` are tokens only under `-98` (`Hugs/src/input.c:1679, 1688, 1761, 1764`).
- **nhc98 1.22.** Haskell 98 with four extensions: the FFI, hierarchical names, existentials and pattern guards ("new in
  1.20") (`nhc98/docs/extensions.html:17-27`). It reads only `OPTIONS_YHC` pragmas
  (`nhc98/src/compiler98/Parse/Pragma.hs:13-18`). n+k patterns are on by default and off under `-nonplusk`
  (`Flags.hs:251, 425-426`).
- **MicroHs 0.16.12.0.** No switches: 72 extensions are always on (`README@e2b24fbb^:48-119`) and "The only extension
  that is not always on is `CPP`" (`:120`). CPP is detected by scanning the file, lowercased, for `cpp` inside a pragma
  before `module`: "This is pretty hacky and not really correct" (`MicroHs/src/MicroHs/Compile.hs:389-402`); `-XCPP` is
  its one `-X` flag (`Main.hs:160`). Other pragmas are skipped (`Lex.hs:487-496`). Several of the 72 change the meaning
  or acceptance of valid 2010 programs, as X1's probes show them doing in GHC: BangPatterns, MagicHash,
  NegativeLiterals, NumericUnderscores, OverloadedStrings, OverloadedRecordDot and QualifiedDo [inferred from the list];
  and `forall`, `mdo` and `pattern` are keywords (`isKeyword`, `Parse.hs:180-203`), where 2010 lets a program name a
  variable so. The README adds "Many things that should be an error (but which are mostly harmless) are not reported"
  (`README@e2b24fbb^:122`).
- **UHC.** Accepts a LANGUAGE name only from a table of 12: NoImplicitPrelude, CPP, GenericDeriving, BangPatterns,
  PolyKinds, OverloadedStrings, ExtensibleRecords, Fusion and some `No` forms (`uhc/EHC/src/ehc/Base/Pragma.chs:69-90`).
- **Helium 1.9.** A restricted Haskell 98 with no switches: no records, no `newtype`, no strictness annotations, no
  literate files, no n+k (`helium/DIFFERENCESWITHHASKELL98.md:3-11`), and "(single parameter) type classes"
  (`helium/RELEASENOTES.txt:13`).

What the comparison says:
- **Only GHC has implications as ordered steps;** haskell-src-exts closes them at the end, the others have none.
- **Only GHC refuses an unknown name in a module,** and Cabal at configure; haskell-src-exts, jhc and MicroHs ignore it.
  Chapter 12 requires the refusal (D7).
- **The internal designs are three:** jhc maps many names to a few flags; Hugs has one switch; MicroHs and UHC have a
  fixed superset. D4's closed table over GHC's names, mapped many to one, is jhc's design with GHC's resolution.

### The 2010 changes in each

| Change | GHC | Hugs | nhc98 | MicroHs | jhc |
|---|---|---|---|---|---|
| Pattern guards | yes | no | yes | yes | no |
| n+k removed | off in Haskell2010 | always accepted | `-nonplusk` | never had them | always accepted |
| Empty data declarations | yes | yes, not `deriving ()` | yes | yes | yes |
| DoAndIfThenElse | yes | yes | no | yes | unsettled |
| Hierarchical names | yes | yes | yes | yes | yes |
| FFI | yes, no re-initialisation | no `foreign export`; `wrapper` on three architectures | no `wrapper`, no `stdcall`; exports restricted | `ccall`, `capi`, `dynamic`, `wrapper`, `foreign export`, HsFFI.h | yes |
| Relaxed dependency analysis | always | yes, as its extension | no | yes | yes |
| LANGUAGE pragma | yes | no | no | CPP only | yes |

Where each cell comes from:
- **GHC:** the Haskell2010 edition (`ghc/compiler/GHC/Driver/DynFlags.hs:1332-1349`); n+k refused under it and accepted
  under Haskell98 (E5 P17b, P17a); FFI, `bugs.rst:488-491`; relaxed dependency analysis, `Driver/Flags.hs:116-117`.
- **Hugs:** a guard is one expression, `'|' exp0 '=' exp` and `'|' exp0 ARROW exp` (`Hugs/src/parser.y:619, 875`); n+k
  in the grammar with no switch (`:655, 661`); empty data with no deriving clause (`:289`), and Lynagh found
  `data Foo deriving ()` refused (*What the literature says*); `if` with optional semicolons (`:799-804`); the
  hierarchical namespace and the FFI's limits (`Hugs/docs/users_guide/haskell98.xml:398-412, 421-432`); relaxed
  polymorphic recursion, documented as Hugs's own relaxation of 98 (`:88-91`).
- **nhc98:** `docs/extensions.html:17-27`; empty data, `data T` with no `=` (`src/compiler98/Parse/Parse.hs:66`); `if`
  requires `then` and `else` with no semicolon (`Parse.hs:278-281`); the FFI's limits (`docs/ffi.html:40-50`); the
  dependency analysis drops signatures and makes every use an edge (`src/compiler98/SccModule.hs:60-81`), which is 98's
  grouping. The Haskell' wiki's table lists nhc98 as "full" on relaxed dependency analysis
  (`HP/RelaxedDependencyAnalysis.txt:28`); the 1.22 source does not bear it out.
- **MicroHs:** a guard is a list of statements (`MicroHs/src/MicroHs/Parse.hs:784-785`); no n+k (haskell98.md:3626, from
  the 98 campaign's runs); EmptyDataDecls and DoAndIfThenElse always on (`README@e2b24fbb^:61, 64`); hierarchical names
  throughout its library (`lib/Foreign/StablePtr.hs` among them); the FFI: `foreign export` parsed (`Parse.hs:416`) and
  lowered (`Exp.hs:106-114`, `tests/ForExp.hs`), `dynamic` and `wrapper` (`Desugar.hs:610-621`), the calling conventions
  `ccall`, `capi` and `javascript` (`Parse.hs:443-444`), HsFFI.h with all six functions of 8.7
  (`src/runtime/HsFFI.h:69-75`) and `lib/Foreign/StablePtr.hs`; relaxed dependency analysis, "Find definitions without a
  type signature and split them into strongly connected components" (`TypeCheck.hs:1604-1618`); CPP, above. Its 2024
  paper's "The FFI is basically limited to foreign import ccall" is out of date for this tree.
- **jhc:** a guard is one expression (`jhc/src/FrontEnd/Lex/Parser.y.pp:285-293`), PatternGuards being only in its list
  for warnings (`Options/Map.hs:124`); n+k and empty data always on (`:80-81`); the FFI flag (`:59`); signed names left
  out of the dependency edges (`jhc/src/FrontEnd/Tc/Main.hs:990-994`); hierarchical names in its 2010 library
  (`jhc/lib/haskell2010/haskell2010.yaml.m4:8-30`); pragmas, above. Its grammar has no semicolons in `if`
  (`Parser.y.pp:377`), but the 2009 wiki says DoAndIfThenElse had been "recently added to jhc"
  (`HP/DoAndIfThenElse.txt:72`), and its layout pass was not read, so that cell is open.

UHC and Helium are left out of the table: UHC's cells could not be settled without its documentation, though it never
had n+k (`HP/NoNPlusKPatterns.txt:17`) and its variant list gives the FFI as partly done (`uhc/EHC/mk/shared.mk.in:48`).
Helium has no n+k and cuts dependency edges at signatures
(`helium/src/Helium/StaticAnalysis/Inferencers/BindingGroupAnalysis.hs:66-71`), and lacks too much else of 98 to judge a
2010 program.

### The type extensions in each

| | MPTC | Fundeps | Existentials with contexts | Higher rank |
|---|---|---|---|---|
| GHC | yes | yes; improvement from a given refused | yes, T4a and T4b, not in lazy patterns | yes; simplified subsumption from 9.0, deep under Haskell98 and Haskell2010 |
| Hugs | yes (`-98`) | Jones 2000: improvement by unification in a loop | skolems, escape errors, local dictionaries; matching in local pattern bindings | rank 2 only |
| MicroHs | yes | yes, improvement by unification, then solving again | yes, with no escape check | PVWS with deep skolemisation |
| UHC | yes | parsed, never used | from variant 4 | from variant 4 |
| jhc | refused | refused with MPTC | yes; the type travels with the value | boxy types, never inferred |
| nhc98 | refused | refused with MPTC | yes | no |

How each does it:
- **GHC** solves all of them with OutsideIn(X) over System FC (*What the literature says*); this section does not read
  its solver. That it refuses improvement from a given is Karachalias and Schrijvers's report (p. 2). That it refuses an
  existential in a lazy pattern is the Haskell' page's (`HP/ExistentialQuantification.txt:131-133`).
- **Hugs** implements Jones 2000 in C: `improve` loops over the predicates until nothing improves
  (`Hugs/src/subst.c:1480-1500`), with `instImprove` and `pairImprove` (`:1549, 1590`); implicit parameters are improved
  the same way (`ipImprove`, `:1565`); fundeps are inherited from superclasses (`Hugs/src/static.c:1194-1196`).
  Existentials: "Existentially quantified variable in inferred type" and "escapes from pattern" are its errors
  (`Hugs/src/type.c:561, 580`), and a constructor's local dictionaries are bound on a match (`:963`); a local pattern
  binding may open an existential (`HP/ExistentialQuantification.txt:126`). Rank 2: "Functions that take polymorphic
  arguments must be given an explicit type signature", the arguments "can only be matched by a variable or wildcard",
  and "the polymorphic arguments must be supplied" (`Hugs/docs/users_guide/hugs_ghc.xml:396-407`;
  `type.c:991-1004, 1169`). Undecidable contexts are cut by a depth limit, `-c` (`hugs_ghc.xml:200-205`).
- **MicroHs** collects class constraints and solves them in `solveConstraints`; improvements come back as pairs to unify
  (`type Improve`, `MicroHs/src/MicroHs/TypeCheck.hs:3716`), and after unifying them it solves again (`:3735-3741`).
  Fundeps are canonicalised first (`:1438-1440`). Subsumption is "Rule DEEP-SKOL" (`:2863`), and `skolemise` "Performs
  deep skolemisation" (`:3283-3284`). Opening an existential binds its dictionaries with the comment "XXX must check for
  leaking skolems" (`:2886-2887`). Its GADTs keep given equalities as a rewrite system on rigid variables, "not sure it
  always works properly" (`:4087-4099`); Coercible is solved by pretending "newtypes are type synonyms" (`:3861`), with
  no roles.
- **UHC** builds its compiler in variants: "4 : + quantifiers everywhere, existentials", "9 : + CHR, class system, local
  instances", "15: + (TBD) functional dependencies", "31: + (TBD) GADT" (`uhc/EHC/mk/shared.mk.in:29-46`). Fundeps are
  parsed (`uhc/EHC/src/ehc/EH/Parser.chs:577`) and collected (`EH/HMTySys/InferClass.cag:122-127`), and no solver uses
  them [read, by search]. Its own library uses MPTC (`uhc/EHC/ehclib/uhcbase/UHC/Generics.hs:4`). Impredicative binding
  is decided in `fitsIn` (`uhc/EHC/src/ehc/Ty/FitsIn.chs:1167`).
- **jhc** refuses MPTC, "Multi-parameter type classes not supported" (`jhc/src/FrontEnd/KindInfer.hs:428-430`), an error
  (`jhc/src/FrontEnd/Warning.hs:155`), so its documentation's claim that fundeps save run time
  (`jhc/docs/jhc.mkd:115-116`) describes no working feature. Existentials carry their type with the value (E11's reading
  of `jhc/src/E/FromHs.hs:96`); its checker is boxy (`boxyMatch`, `jhc/src/FrontEnd/Tc/Unify.hs:135`), and "jhc will
  never infer types of higher rank" (`jhc/docs/unboxed.mkd:95`).
- **nhc98** parses multi-parameter classes and then refuses them: "Multi-parameter type-classes ... are not supported"
  (`nhc98/src/compiler98/Rename.hs:272-273`). Existentials: "Local forall quantification on datatypes"
  (`docs/extensions.html:23`), with "ctxs introduced due to pattern matching on existential"
  (`src/compiler98/Type/Data.hs:30-31`). Higher rank is not among its extensions (`docs/extensions.html:17-27`).

Over all 55 type-level names X2's sub-survey graded (`results/E6/X2-data/others.tsv`): haskell-src-exts parses 42,
MicroHs implements 32 and 6 in part, Hugs 17 and 3, UHC 16 and 6 with 12 unsettled, jhc 12 and 2, nhc98 2 and 1, Helium
1 and 1. MicroHs and Hugs are the only implementations, besides GHC, of T1, T2, T4a and T5 together, and both do it
without implication constraints: the precedent for D34's A+.

### What this means for the oracle policy (D39)

98's D52 took GHC with a strict shim and Hugs `+98` as judges, nhc98 third and MicroHs a smoke oracle
(haskell98.md:7157). For 2010 the same four reach less:
- **GHC 9.4.7 with a 2010 shim** judges acceptance and output of 2010 programs, except where it departs. rhc follows the
  Report there, and the expected result cites the clause. The exclusions, from this section:
  - lexical: `forall` as a name; `!`, `~` and `@` by spacing; `M.\`; non-ASCII decimal digits and the wider identifier
    classes; `((f)) x =`; `1_000` with `_000` in scope; `M.do`;
  - a refusal of pattern guards (NoPatternGuards only warns); 98's dependency analysis (RelaxedPolyRec cannot be turned
    off);
  - T5: GHC's `-XHaskell2010` subsumes deeply, so T5 probes need `-XNoDeepSubsumption` (9.4.7 has the flag:
    `results/E5/probes/supported-extensions-947.txt:135-136`) [inferred];
  - bottoms: eta-expansion unless `-fpedantic-bottoms`;
  - the library: base's departures (Num's and Bits' superclasses, Monad's Applicative, extra instances, `array`,
    `splitAt`, record Show, integer Read, `isAlpha`, `hGetContents`), which the shim must cover or the test exclude;
  - FFI: re-initialisation after `hs_exit`;
  - the 11 names 9.4.7 lacks.
- **Hugs** cannot judge pattern guards (it refuses them), n+k (it always accepts them), `foreign export` (absent) or
  `deriving ()` on an empty type (refused), and reads no LANGUAGE pragma. It agrees with 2010 on relaxed dependency
  analysis and DoAndIfThenElse, by its own extensions. A second judge for 2010 programs without those.
- **nhc98** judges pattern guards, n+k under `-nonplusk`, empty data and FFI imports without `wrapper`. It refuses
  DoAndIfThenElse and programs that need 4.5.1's refined groups, and reads no pragma.
- **MicroHs** is a smoke oracle only: never a judge of a refusal, since 72 extensions are always on and it reports less
  than it should; not of T4a, with no escape check; not of T5, with deep skolemisation; not of `forall` or `pattern` as
  names. It implements `foreign export` and HsFFI.h, and nhc98 `foreign export` with restrictions, so these two can
  judge D28's programs if D28 brings them in.
- **jhc, UHC, Helium and haskell-src-exts are not oracles:** jhc does not tell 98 from 2010, accepts n+k in both and has
  no pattern guards; UHC is unsettled; Helium is a subset; haskell-src-exts is a parser.

How they did on the 2010 corpus (E8, `results/E8/summary.txt`, `limits.tsv`):
- **GHC 9.4.7 with the 2010 shim (g10)** agrees with the Report on 15 of 23 probes (14 recorded in `limits.tsv`, L22
  by reading) and departs on 8, each a stated limit, in four causes (base's derivable classes, so a record's derived
  `Show` takes GHC's parentheses and `read "0x10"` parses; base's `Ratio`; RebindableSyntax's names in scope; GHC's own
  departures in `bugs.rst`). A ninth limit has no probe: the C types' constructors exported so that GHC will marshal
  them (W8). GHC's own `-XHaskell2010` over base departs on 10.
- **On Hackage's plain-2010 components** (compile only), g10 accepts 355 of the 398 GHC's own 2010 mode accepts; the
  other 43 fail on the library alone (Applicative 13, Semigroup and Monoid 7, Data.Bits beyond 2010 5, Foldable 4, ...):
  "Haskell2010" on Hackage is 2010's language over modern `base`.
- **Hugs** has no pattern guards and accepts n+k and some illegal programs; **nhc98** has pattern guards but neither
  DoAndIfThenElse nor the relaxed dependency analysis. Neither accepts any of the 415 judged extension and
  illegal-in-98 rows of the 98 corpus.
- **MicroHs** accepts much of what g10 refuses for language reasons (45 of 57 GHC testsuite files; 68 of 170 of its own
  tests) and rarely refuses what g10 accepts: a judge of acceptance only, never of refusal.

## The experiments

Thirteen experiments came before the writing, by twelve agents. E11 is reading; E1, E6 and E9 are reading with tools
and probes. The rest ran rhc, GHC or both. This part gives the head, the table and E1-E5 and E13 in full; E6-E12
follow.

**How they were gathered**
- **The tree.** Everything measures haskell98's tip of 2026-11-17, `75ed95861`. `.worktrees/h10-base` is the
  reference: seeded by rsync from the other session's built tree at the same commit, built once and never modified,
  and every `path:line` here is against it. Each agent that changed rhc worked in a detached worktree of its own,
  seeded from it: `h10-f` (F, E3), `h10-a` (A, E4 and E13), `h10-v` (V, E10), `h10-n` (N, E12). Nothing was
  committed. haskell98 moved on after the pin (`1429fe5fc` on 2026-11-21, 24 commits); *Where we are* records what
  changed, and E4 measured how its patch meets it.
- **The inputs,** never edited: the 2010 Report as text (T10, pdftotext of the PDF, 17,918 lines) and as HTML
  (fetched 2026-11-17 into `downloads/report2010/`, 52 pages); the 98 Report as text (T98); the haskell-prime archive,
  2009 to 2021; GHC 9.14.1's source (`/home/ruud/haskell/ghc`), the record, and the installed GHC 9.4.7, the only
  binary probed; Hugs, MicroHs, nhc98, jhc, haskell-src-exts and nofib under `/home/ruud/haskell`; rhc's corpus
  (`tests/hs/corpus`); Hackage's index and the sources of Stackage LTS 24.67 (E7); the 98 campaign's drafts, read
  only.
- **The evidence.** Every number comes from a script kept with its raw output. `results/` is under the drafts
  directory, `~/.cache/claude-rune-drafts/haskell2010/`, and `patches/` is beside it. **Within an experiment a bare
  file name is in that experiment's directory,** so in E3 `flips/flips.tsv` is `results/E3/flips/flips.tsv`, and in
  E13 `edits.tsv` is `results/E13/edits.tsv`. Each directory has a README that says how to reproduce it.
- **The claims rest on bytes and outcomes,** not on time. "Byte-identical" compares rhc's bytecode files, or its exit
  status and whole standard error, between the unpatched and the patched compiler on one machine. GHC's answers are
  accepted, refused or warned, and the program's output. Seconds (E4's snapshot builds) are indications.
- **The machine** is WSL2 with 16 CPUs and 31 GB, shared with another session's agents working on haskell98. The
  build logs record a load average of 20 to 59 at their starts, mostly 25 to 55. Every heavy job ran through the
  campaign's slot script (four slots), and builds one at a time.
- **The stop.** On 2026-11-17 the account's weekly rate limit stopped every agent then running: F, A, G, N and three
  writers. All resumed on 2026-11-21 with nothing lost. F's and A's job chains had finished before the stop, and
  their worktrees and scratch outputs were intact; A rebuilt its prototype (build 6) and ran every check again that
  day, and E13 ran then.
- **The prototypes** were throwaway, kept as patches. None lands as it stands.
- **Marks.** [read] is from reading, with its citation. [measured] ran, with its result file. [inferred] is reasoned
  and was not run. [counted] is a count this section's writer made in a raw file or the tree, where the agent gave
  none or a wrong one. An agent's claim with no result file says so.

**The two waves.** Wave 1, E1-E11, asked what is there today, each agent on its own; E2 started from E1's delta.
Wave 2 read wave 1: E12 built on E6's tiers and E11's literature, E13 on E4's prototype and E5's semantics. E13
follows E5 here, the semantics it tests.

**The flips.** The plan promised that each experiment would state what would flip it (plan.md, *Phase 1*), but its
tables name only the decisions settled. Where the brief or the plan's own text implies a condition (a byte check that
must hold, a suspicion to test, an expectation stated as a fact), the table gives it as implied; elsewhere it says
none was set.

| | What | By | Settles | What would have flipped it | Did it? |
|---|---|---|---|---|---|
| E1 | The Report's delta from 98 with its errata: a clause table on 98's 3,901 rows, the Prelude's diff, the 30 library chapters, 2010's errata, its own defects | R | D7, D14-D21, D26, D27, D38; tracks F and L | None set. The plan's premise: the preface's four changes are not the delta | No flip; the premise held. 18 changes, not 4; the Prelude's code unchanged but for 3 imports; no 2010 errata ever published |
| E2 | 98's choices against 2010's text: 232 items through the brief's three-part test | R | D13a-D13d | None set. Implied: the plan named R38 the obvious candidate and the Unicode version and `isSpace`'s range cleaner ones | Yes, against the plan: R38 and `isSpace` are overrides, the Unicode version SAME. One clean ALIGN (R48), one to decline (R45(b)) |
| E3 | Front-end spikes behind a stub `--language`: pattern guards, n+k off, empty data, DoAndIfThenElse, `:`, relaxed groups, `foreign`, the header pre-scan, a CPP probe, the `--dotted-names` key | F | D6, D12, D14-D18; track F's size | Implied: 98 mode not byte-identical; the plan's suspected `--dotted-names` key hole | 98 held on every set compared, but only with a pre-scan that reads edition names alone in a 98 module (D6). The key hole is real at the pin, fixed after it |
| E4 | One language record per module and a per-language library descriptor; two snapshots; a 2010 tier's cost; what the default flip touches | A | D1, D3, D4, D9, D10, D41; D8's sorting | Implied: 98's bytes move, or the diff collides with BC's | 98 held but for one pinned dump of `--names=greatest` (an owner item). It collides: 12 of 121 hunks rejected on haskell98's tip, so M4 is written on BC's driver |
| E5 | GHC's flag semantics as data, from 9.14.1's source, probed on 9.4.7; Cabal, haskell-src-exts, jhc, Hugs, MicroHs | X3 (the plan named X1) | D4-D7, D11 | None set | No flip. 129 of 137 probes as predicted from the source; the 8 misses explained |
| E6 | The census: a row per LANGUAGE name, three agents on one schema | X1, X2, X3 | D35-D37 | None set; ten names classified by all three as a check | No flip. The ten agree on the recommendation 10 of 10 and on the tier 8 of 10 (`results/E6/overlap.tsv`) |
| E7 | Usage on Hackage: the index, and every module of Stackage LTS 24.67's 3,439 packages | O | D12, D35; a 2010 corpus | None set | No flip; it orders D35. Every rec-now name admits 44.66% of modules and 28.33% of whole packages (`results/E7/tier-needs.tsv`) |
| E8 | Oracles and corpus for 2010: a 2010 shim for GHC 9.4.7, MicroHs, Hugs, nhc98; the untrusted-code filter | G | D38-D41 | None set | No flip. The shim is the Report's on 15 of 23 limit probes (14 recorded in `results/E8/limits.tsv`, one by reading) |
| E9 | The libraries: the 30 modules' code or prose, sources and licences, primitives, the Prelude's layout | L | D20-D26, D33; track L's size | None set | No flip. 26 modules prose only, 4 with code (`results/E9/modules.tsv`); about 4,656 lines (`estimate-totals.txt`) |
| E10 | The FFI on rhc: the four `ccall` import kinds through Core to Rune's `foreign` and `foreign_callback`; Foreign.* against Rune's model | V | D27-D33 | Implied: the optimiser drops, duplicates or reorders an IO call | No. `Opt.hs`, the ordering test, prints the same at `-O0`, `-O1`, `-O2` and on the stack target (`results/E10/matrix.tsv`); 36 gaps graded (`gaps.tsv`) |
| E11 | Literature for the decisions: Haskell', the FFI Addendum, pattern guards, the type-system papers, how Hugs, UHC, jhc and MicroHs build them | I | D34, D37; every decision's precedents | None set | No flip. It named D34's design (A+, as Hugs and MicroHs) and split T4 into T4a and T4b; 56 sources (`results/E11/refs.tsv`) |
| E12 | Where the 98 type system ends: T1, T2, T4a and the T5 core prototyped on A+ in the checker and HsLint, each behind a switch | N | D34-D37 | Implied: a tier needs implication constraints, or breaks 98's bytes | No. All four fit A+ in both checkers: 2,617 lines added, 2,278 of code, over 46 files (`results/E12/areas.tsv`). Switched off, 98 held: tests/hs/lang 591 of 591, errors 633 of 633 and GHC's 133 selected files as the baseline on the final build; the run set 354 of 354 on T1's state only, since the final build's corpus runs were stopped early at the lead's request, a mistaken check. Every tier on, lang stays 591 of 591 (`identity/`). But T5 needs CoreToMid to box polytypes, which Mid takes only as fields: `rank2` fails MidLint at `-O0` and `-O1` (`programs-rhc/summary.txt`) |
| E13 | The tracking design under test: GHC's resolution as data against E5; a combination table; the store under language edits | A | D5, D7-D10 | Implied: a warm compile's bytes differ from `--no-store`'s | No: 43 of 43 steps equal. On the way it found an HsLint fault in a mixed cycle, fixed in build 9 |

### E1. The 2010 Report's delta

**Question.** What does the 2010 Report change from the 98 Report as rhc reads it, with its 18 errata, clause by
clause, and where is the 2010 text itself wrong, contradictory or underspecified? The plan's fact 1 was a checklist,
not the answer. **Settles:** D7, D14-D21, D26, D27, D38, and the scope of tracks F and L. It gave M1 its table, E2 its
evidence, D2 the Prelude's identity and *Found while writing* most of its entries on the Report.

**How.** Agent R, on 2026-11-17, reading with tools; network to haskell.org only.
- The HTML Report was mirrored (`fetch_report2010.py`; `downloads/report2010/MANIFEST.tsv`: 58 files with status 200,
  52 of them HTML pages, and one 404 for a figure) and turned into text (`h2t10.py`, `html10/`). `coverage.py` checks
  that the HTML loses nothing of the PDF: 91.7% of T10's tokens matched over 303 sections (`coverage.tsv`), the low
  ones tables and figures that pdftotext scrambles [counted].
- `sections.py` maps 98's numbering to 2010's (`secmap.tsv`). `textdiff.py` diffs every language section word by
  word: 338 hunks (`textdiff/hunks.tsv`), every one read.
- `prelude_diff.py` puts chapter 9's code against h10-base's `share/rhc/haskell98/pristine/`, as printed and with the
  two Prelude code errata applied as rhc's overlay writes them (`prelude/`).
- `libraries.py` and `lib10.py` inventory the 30 library chapters and compare their types with 98's (`libs/`).
- `build_clauses2010.py` builds the clause table from 98's 3,901 rows (`tests/hs/conformance.tsv`), 107 hand decisions
  on 98 rows (`rules.tsv`) and 126 hand rows new in 2010 (`new10.txt`), and checks that every 98 row lands in some
  row. `delta_rows.py` lists the rows each change moves (`delta-rows.tsv`, `delta-rows-counts.tsv`).
- For errata: the haskell-prime archive month by month from 2009-01 to 2021-11 (95 monthly archives), the wiki and
  haskell.org's definition page (`fetch_errata.py`, `errata_threads.py`, `errata-threads.txt`).
- 54 probe programs on GHC 9.4.7, 61 runs, under `-XHaskell2010` and, where it matters, `-XHaskell98`
  (`probes/run_probes.sh`, `probes/results.tsv`, `probes/out/`). A probe of a library function tests GHC's `base` 4.17,
  not the Report's library; `readings2010.md` marks those.

**Result: the changes** (`delta.md`, Δ1-Δ18, each with T98 and T10 lines and the rows it moves). The preface lists four
(T10:1287-1294): Δ1 the FFI, with `foreign` reserved (T10:1741); Δ2 hierarchical module names; Δ3 pattern guards;
Δ4 n+k patterns removed. The text makes fourteen more:
- Δ5 DoAndIfThenElse, `if exp [;] then exp [;] else exp` (T10:2083), named nowhere in the prose or in 12.3;
- Δ6 empty data declarations (T10:3860), with a sixth condition on derived instances (T10:10670);
- Δ7 98's precedence-indexed grammar deleted for `infixexp` plus 10.6's resolution, and 98's two parsing notes with
  it (T98:15532-15543, T98:317-324): R1's and R9's deviations become the text;
- Δ8 relaxed dependency analysis (T10:4704-4716), which 12.3 calls RelaxedPolyRec (T10:10998); 4.5.2's identical
  contexts are kept (T10:4752);
- Δ9 the LANGUAGE pragma (T10:10977-11009); Δ10 `:` joins ascSymbol (T10:1674), absorbing 98's comment erratum;
- Δ11 `0**y` "is 1 if y is 1, and 0 otherwise" (T10:6389-6390), a misprint for "y is 0";
- Δ12 the libraries; Δ13 the Prelude; Δ14 defaulting now reaching `Bits`, a subclass of Num in a standard library
  (T10:11629), with 4.3.4's words unchanged; Δ15 no Unicode version (T10:16864); Δ16 editorial; Δ17 98's errata;
  Δ18 the chapters renumbered.

Rows moved, from `delta-rows-counts.tsv` (the changes overlap, so these do not add up):

| Change | Same | Changed | New | Removed |
|---|---:|---:|---:|---:|
| Δ1 FFI (with the Foreign.*, Data.Bits, Data.Int, Data.Word rows) | 0 | 1 | 1,037 | 0 |
| Δ3 pattern guards | 6 | 5 | 22 | 1 |
| Δ4 n+k removed | 0 | 6 | 1 | 20 |
| Δ7 fixity resolution | 8 | 18 | 11 | 16 |
| Δ12 libraries | 0 | 866 | 257 | 216 |

**Result: the clause table** (`clauses2010.tsv`, counts in `clauses2010-counts.tsv`). 5,259 rows: 2,736 same, 912
changed, 1,358 new, 253 removed in 2010; every one of the 3,901 98 rows is in some row's `map98` [counted]. The
language chapters 1-12 hold 2,898 rows (2,718 same, 46 changed, 134 new); the library chapters 13-42 hold 2,108 (18
same, 866 changed, 1,224 new) [counted]. A changed row takes a new id; a same row keeps 98's.

**Result: the Prelude** (`prelude-diff.md`, `prelude/prelude-diff.tsv`). Of 927 non-blank lines, 915 are identical, 9
differ in spacing only, and 3 differ: imports renamed `Ratio` to `Data.Ratio` (T10:7543) and `Char` to `Data.Char`
(T10:8422, 8867). Against 98 with its errata, 2010 has neither Prelude code erratum: Enum Float and Enum Double's
`enumFrom` has no `seq` again (T10:8258-8292), and `lex` puts `_` in `isSingle` again (T10:9036-9051).

**Result: 98's 18 errata** (`delta.md` Δ17): 6 absorbed (three of them in effect or by rewording), 8 not absorbed, 1
moot (n+k) and 3 not applicable (indexes). The 8: field order and match wording in 3.17.2, `=<<` missing from Table
4.1, enumstrict, properFraction, 7.2's `do` example, `lex`, and exportvar (10.5 keeps `qvar` where 5.2 says `var`).

**Result: the libraries** (`libraries.tsv`, `libs/`). 30 module chapters export 686 names in 620 items [counted]. Four
have code: Data.Array 65 lines, Data.Complex 73, Data.Maybe 31, Data.Ratio 74; 26 are prose. Directory, Time, Locale,
CPUTime and Random are gone, with `bracket`, `bracket_` and `system`. IO splits into System.IO and System.IO.Error,
System into System.Environment and System.Exit. Four signatures change: `genericLength :: Num i => [b] -> i`
(T10:13317), and `readDec`, `readOct` and `readHex` at `Num a`. Data.Char's `isSpace` takes "any Unicode space
character" (T10:11833), `isUpper` and `isAlpha` read otherwise of caseless letters, and Data.Int says "All arithmetic is
performed modulo 2^n" of a list naming Int (T10:12381-12382). 98's chapter 23 on how a program ends has no counterpart:
chapters 39 and 40 (T10:16077-16162) keep only exitWith's, exitFailure's and exitSuccess's descriptions.

**Result: errata and readings.** No errata to the 2010 Report were ever published (`errata2010.md`): the online
Report is the edition generated on 2010-07-20, and the wiki's errata page does not exist. Ten reports of mistakes
reached the haskell-prime list from 2010 to 2019 (E10-1 to E10-10 there); none was fixed in the published text.
`readings2010.md` holds 21 places where the 2010 text is wrong, contradictory, ambiguous or underspecified, each with
a GHC probe where one helps:
- N1, the FFI: `chname` has no digits (GHC accepts "x86_64.h"); nothing says when a pure import is called (GHC: lazy
  as a value, strict in its arguments); `Word` is missing from 8.4.2's list; `hs_init` must work again after
  `hs_exit`, which GHC cannot do.
- N3: rule (s) of 3.17.3 ends "where y is a new variable" and no y occurs (T10:3447); a `where` cannot see a
  pattern guard's bindings (GHC: "Variable not in scope: y").
- N4: Rule 1 acts on 2010's smaller groups. GHC accepts `n04b_relaxed_mr` under `-XHaskell98` too, so GHC is no oracle
  for 98's groups.
- N6: 6.4 leaves Int overflow undefined (T10:6239-6241) and Data.Int requires wrap-around.
- N7: GHC's `isSpace` is general category Zs (U+2028 is not a space). N8: GHC 9.4.7's `base` is at Unicode 14.0.
- N9: GHC refuses the `Bits` defaulting that 2010's text allows ("Ambiguous type variable").
- N11: the code chapters' defects: 14.6 headed `module Array (`; 22.1's `Show (Ratio a)` a parenthesis short (GHC:
  "parse error on input ')'"); 19.1's law with a stray parenthesis.
- N13: the semicolons DoAndIfThenElse admits are absorbed in `let` and `case` blocks too (GHC accepts both under
  `-XHaskell2010`, refuses both under `-XHaskell98`).
- N16: 19.2 requires Ix for tuples to size 15 (T10:12562) though the instance list stops at 5.
- N18: whether 98's unabsorbed errata apply to 2010's identical text. N21: how a program ends has no text.

**What would have flipped it.** None set. The plan's checklist was a premise, and it held: the preface is not the
delta. E1 added what the checklist missed (the grammar's deletion, the two notes, `0**y`, `Bits` in defaulting, the
unabsorbed errata, the code chapters' defects), so track F takes Δ2-Δ10 and Δ1's syntax, not the preface's four.

**Where the report and the files are wrong** (W3 and W8 found most; each rechecked here).
- `clauses2010.tsv` marks `lay.parseerror.doif` and `lay.parseerror.thensamecol` `same`, with 98's statement that
  `do { if a ; then b ; else c }` is refused. 2010 accepts it, as E1's own new rows `exp.if.semi.*` say, and E3
  measured both tests flip to accepted (`results/E3/flips/flips.tsv`). They are `changed`.
- Five 98 rows of chapter 23 are mapped `changed` into chapters 39 and 40 with 98's statements:
  `lib.r.systemexit.term.error`, `.term.ioerror`, `.term.normal`, `lib.r.systemenvironment.exitwith.close` and
  `.term.loop`. T10:16077-16162 has no such text, against E1's own N21. `lib.r.systemexit.exitwith.nocatch` is right:
  the sentence is at T10:16146-16147.
- The report's "55 probe programs" are 54 programs and 61 runs. `readings2010.md`'s heading says N1-N20 and the file
  holds N21. Rule (s)'s unused y is N3; the report files it under N2 and `delta.md`'s Δ3 points to N4. N20's probe is
  named `n19a_strict_fields_order`.
- N10 says IEEE pow "agrees with the corrected sentence"; it does for y >= 0 only. At a negative y the corrected
  sentence gives 0 and IEEE infinity.
- The README's "58 pages" are 58 files fetched with status 200, of which 52 are HTML pages. `errata2010.md`'s 404 for
  `errata.html` has no row in either MANIFEST [counted].

**Not established.**
- The T10 line of 2,033 rows is the line with the best word match, a pointer and not a quotation (column `lines`)
  [counted]; `delta.md` cites lines checked by hand.
- 98's prose rows of the libraries (`lib.r.*`) were mapped by name and keep 98's statement under the 2010 module, except
  where a rule rewrites them; the README says they need checking against the 2010 prose.
- Every probe of the library tests `base` 4.17, not the 2010 library.
- The GitHub `haskell/haskell-report` history and the Trac tickets 140-142 were outside the network permission; the
  sources' fixes after 2010 are known only from the list.
- The PDF's provenance is not recorded.

### E2. 98's choices against 2010's text

**Question.** Which of rhc's 98 choices does the 2010 text settle the other way, so that 98 mode may follow 2010 under
the brief's rule? **Settles:** D13a-D13d, and the owner's review list.

**How.** Agent R, after E1's delta, on 2026-11-17. Every item went through the brief's three-part test: (1) 98's text
admits two readings, or is silent, or contradicts itself; (2) rhc picked one; (3) 2010's text picks the other, or picks
one where rhc's choice was free. Outcomes: SAME (2010 agrees with rhc), ALIGN (passes), OVERRIDE (2010 differs but
98's text was plain, so aligning would override "98 stays 98"), CHANGE (2010 changes the language) and OPEN (2010
does not settle it). The 232 items (`alignment.tsv`) [counted]: 120 reading rows (R1-R158 with sub-items), 8
deviations (`tests/hs/deviations.tsv`), 53 overlay entries (`share/rhc/haskell98/overlay.tsv`), 42 rulings and 9
owner items (the 98 drafts' `impl/rulings.md` and `impl/owner-list.md`). `alignment.py` holds the rows by hand, each
read against T98, T10 and E1, and checks that every R number, deviation and overlay entry is present and every outcome
one of the five. `alignment.md` argues the ALIGN and OVERRIDE items. R started from the exploration report
(`agents/X-explore-choices.md`) and checked every line of it.

**Result** (`alignment.tsv` [counted]):

| Outcome | Rows | Items |
|---|---:|---|
| SAME | 97 | |
| OPEN | 118 | |
| CHANGE | 9 | |
| ALIGN | 3 | 2: R48 with `ov.list.genericlength`; R45(b) |
| OVERRIDE | 5 | 2: R38(a) with R153(b), `ov.char.prims` and `ov.char.isalpha`; R153(a) |

- **D13a, R48, `genericLength`: ALIGN, recommended.** 98 contradicts itself. 4.5.5 types it `Num a => [b] -> a`
  (T98:6325-6326) and its example needs Num (T98:6386-6398); chapter 17 says Integral in its prose (T98:11819), its
  signature list (T98:11645) and its code (T98:12016). rhc took chapter 17 (`share/rhc/haskell98/List.hs:185`); 2010
  takes Num (T10:13317). Aligning changes one signature and newly accepts uses at a Fractional type.
- **D13b, R45(b), `0**y`: passes, decline recommended.** 2010's sentence is a misprint ("1 if y is 1",
  T10:6389-6390), and its "0 otherwise" contradicts IEEE, which rhc follows, at a negative y.
- **D13c, R38(a), `isUpper` and `isAlpha` of a caseless letter: OVERRIDE.** rhc followed 98's code, which is the text;
  it becomes an ALIGN only if the owner accepts D38's "contradictory" ground (chapter 19 against 2.2's lexical
  classes). Recommended: no.
- **D13d, R153(a), `isSpace` beyond Latin-1: OVERRIDE.** 98's text is plain. Recommended: no.
- **For the owner, not alignments:** R41 (derived Show of records): 2010's 11.4 is 98's 10.4 word for word, and GHC's
  own `bugs.rst` calls its parenthesised records a divergence, so ruling 14's premise ("GHC's row as Haskell 2010
  chose") is false twice. R21(c) is a CHANGE (RelaxedPolyRec, T10:10997-10998). R54 (Int overflow) is OPEN because
  2010 contradicts itself (N6); on the lead's reading of D21 (chapter 18 narrows 6.4) it would pass and be an ALIGN.
- **Under 2010,** deviations DV1 and DV8 (R1, R9) are what the text says, and DV2-DV7 stay deviations.
- The exploration report had 11 errors, listed in `alignment.md`; R's report says 12, but the twelfth entry lists what
  the exploration got right. Among them:
  R38 offered as a candidate though rhc followed 98's text; R48, R45(b) and R37 missed; GHC's `bugs.rst` on R41 missed;
  R23 cited at T10:10670, which is condition 6 on deriving, where the grammar is T10:3860.

**What would have flipped it.** None set as a threshold. The plan expected R38 to be the obvious candidate and named
the Unicode version and `isSpace`'s range as cleaner ones (plan, fact 7). That expectation flipped: R38 and `isSpace`
are overrides, the Unicode version is SAME (R38b, R153c), and the one clean case is one the plan did not name, R48.

**Where the report and the files are wrong** (W3 found these; rechecked here).
- The README and `alignment.md` say 55 overlay entries; `overlay.tsv` has 53, and `alignment.tsv` 53 `ov.*` rows
  [counted].
- D13b's effect: `alignment.tsv` says `std.pow.undefined` flips "(0 ** 1 = 1)", but the test has no `0 ** 1`
  (`tests/hs/lang/std.pow.undefined.hs:9-10`). Under the sentence as printed `0 ** 0` is 0 too, so both expected lines
  would become `(0.0,0.0,0.0)`.
- D13d's entry: E2 files `isSpace` under `ov.char.prims`, which names `isPrint`, `isUpper`, `isLower`, `isAlphaNum`,
  `toUpper` and `toLower` (`share/rhc/haskell98/overlay.tsv:44`). `isSpace` is the Report's line with no entry
  (`share/rhc/haskell98/Char.hs:35`), so D13d would need a new one.
- `alignment.md` and the report cite chapter 17's code at T98:11645; that is the signature list, and the code is at
  T98:12016.
- D13a's "no existing test flips" holds for verdicts only: `tests/hs/errors/mr.ex.len.twotypes.hs:4-7` uses List's
  `genericLength` at Double, so its expected message needs a rerun. W7 found D13c would also flip lines 7, 18 and 33 of
  `tests/hs/core/runtime-unicode`.
- E2's 47 corpus lines for `isUpper`, `isAlpha` and `isSpace` come from a substring grep that counts `isAlphaNum`; by
  word the three name 40 lines in 15 files (W3's count).

**Not established.**
- No test was run for any alignment: every "flips" is read from the test sources and their expected files.
- Which reading of D21 the owner takes, on which R54's outcome turns.
- The rulings and owner items about process rather than text (listed in `alignment.md`) were not put to the test.

### E3. Front-end spikes

**Question.** What does each 2010 change to the front end cost in rhc, does 98 mode stay byte-identical, what must the
LANGUAGE pre-scan do, how is CPP written in the corpora, and is the suspected `--dotted-names` hole in the store's key
real? **Settles:** D6, D12, D14-D18, and track F's size.

**How.** Agent F in `h10-f`, on 2026-11-17; every job had finished before the stop. All behind a stub: `--language`
sets one ref for the program's modules, the library is always read as 98, and a file's own `{-# LANGUAGE Haskell98 #-}`
or `Haskell2010` overrides it for that file. Nine patches in a series, `patches/E3-00-stub.patch` to
`E3-08-dotted.patch`, each on the one before; `scripts/series.py` checks they give the final tree. Lines by
`scripts/diffstat.py` ("code": added lines that are not SML comments).
- 98 identity, the patched build 3 against a copy of `h10-f`'s `bin/` taken before any edit (its `rhc.rbc` the unpatched
  one E4 used too, sha256 `ff2c9aa316ea...`): tests/hs/lang's 591 programs to register bytecode at `RUNE_LINT=2`, at
  `-O1` and at `-O2` (`scripts/sweep-lang.sh`, `compare.sh`); 98's D56's 188 run-set programs through their own harness
  (`bin/rune-test run 'hs-corpus-run/...' -j 3`), with a wrapper that keeps every bytecode the harness makes
  (`scripts/rhc-capture.sh`); tests/hs/errors' 633 refusals, status and whole stderr; four views (`--dump-ast`,
  `--print`, `--print-layout`, `--print-exact`) of 953 files of lang and accept.
- 2010: `scripts/sweep-2010.sh` over errors, lang and accept; 24 programs of its own on the interpreter and at `-O1`
  and `-O2` on both bytecodes (`run-programs3/results.tsv`), and GHC 9.4.7 under `-XHaskell98` and `-XHaskell2010` on
  the same (`ghc/ghc.tsv`); ruling 55's six corpus programs (`r21/r21.tsv`).
- Censuses of header pragmas and CPP (`pragmas/census.py`, `cpp/census.py`), and `cpp/probe.sh` on 16 sample files
  against `ghc -cpp -E`. Reproducers: `dotted/repro.sh`, `defects/rule1-signed/repro.sh`.

**Result: lines** (`diffstat.tsv` [counted]).

| Patch | Feature | Added / removed | Code | Files |
|---|---|---:|---:|---:|
| E3-00 | the stub | +33 / -11 | 22 | 7 |
| E3-01 | n+k off in 2010 | +3 / -1 | 2 | 1 |
| E3-02 | DoAndIfThenElse | +5 / -0 | 3 | 1 |
| E3-03 | empty data, condition 6 | +19 / -4 | 13 | 4 |
| E3-04 | pattern guards | +136 / -22 | 110 | 12 |
| E3-05 | relaxed dependency analysis | +57 / -8 | 41 | 3 |
| E3-06 | `foreign` reserved, declarations read | +53 / -7 | 44 | 10 |
| E3-07 | the header pre-scan | +142 / -16 | 106 | 7 |
| E3-08 | hierarchical lexing in 2010 | +13 / -6 | 9 | 2 |
| | all | +461 / -75 | 350 | |

**Result: 98 mode held** [measured]. tests/hs/lang: 591 of 591 bytecode files identical at `-O1` and 591 of 591 at
`-O2` (`identity/lang-O1.tsv`, `identity/lang-O2.tsv`). The run set: 193 of 193 jobs pass with each rhc, 354 of 354
bytecode files identical, 406 of 406 compile steps' stderr identical; 177 programs make bytecode, and the other 11 are
refused in every variant by the unpatched rhc too (`identity/corpus-summary.txt`). tests/hs/errors: 633 of 633
(`identity/errors98.tsv`). Views: 3,812 of 3,812, four of each of 953 files (`identity/views.tsv`).

**Result: what flips under 2010.** 21 of 1,475 tests (`flips/flips.tsv`: 251 accept, 633 errors, 591 lang, no header
row): 6 now accepted, 5 refused with another message, 10 now refused. By feature (`flips/attribution.tsv`): n+k 10,
DoAndIfThenElse 3, empty data 3, hierarchical lexing 3, `foreign` 1, relaxed groups 1. The plan had listed
`mod.name.modid`, `lay.parseerror.thensamecol`, the n+k rows and two deviations; the deviations do not flip (only
their ground changes, R1 and R9), and the rest are E3's, among them
`accept/lex.qual.twodots`: under 2010's `modid` (T10:1795) `M.Just.negate` is a variable of module `M.Just`, so 2010
mode lexes hierarchically, a change of meaning against 98.

**Result: each feature.**
- **Pattern guards** (E3-04). The AST's guard holds a list of qualifiers; a 98 boolean guard is a single expression
  qualifier and keeps the old code at every site, which is why 98's bytes hold. The alternatives' re-reading
  (`lib/language/haskell/parser.sml:1033-1046`) retries the whole qualifier list, and a `let` qualifier closed by `,`
  needs no new code. The desugarer follows rules (s)-(v), binding the fall-through with a lazy `let` when more than one
  qualifier can fail. At `-O2` guards are opaque leaves of the Sestoft tree (`sestoft/core.sestoft.txt`): what the
  clause patterns tested survives a guard's fall-through, but a pattern guard's own test does not feed the tree.
  guards1, guards2 and guards-sestoft print the same on the interpreter and at both levels on both bytecodes, and what
  GHC prints, up to the wording of an uncaught error (`run-programs3/results.tsv`, `ghc/ghc.tsv`). 3.13's note example
  (`programs/guards-note.hs`) is accepted by rhc and refused by GHC in both modes ("parse error on input ';'").
- **n+k off** (E3-01): one condition in the parser; a top-level `n + 1 = ...` still defines `(+)` in both languages,
  as GHC (`programs/npk-top.hs`).
- **Empty data** (E3-03): a Core `Data` with no constructors passes CoreLint at level 2, CoreToMid, and runs on `runevm`
  and `runevm-stack` at `-O1` and `-O2`, with GHC's output up to the error's wording (`programs/empty1.hs`). `deriving
  Show` is refused, `deriving ()` accepted (T10:10670). Nothing below the front end changed.
- **DoAndIfThenElse** (E3-02): an optional semicolon before `then` and `else`. **`:` in ascSymbol:** no change, since
  98's comment erratum already made `--:` an operator; `programs/colon.hs` prints the same in both modes (F's "114
  tokens" has no file).
- **Relaxed groups** (E3-05): 7 code lines in the checker, 34 in HsLint, which must also assume every explicit signature
  first, as Typing Haskell in Haskell's `tiBindGroup` does, or it meets a signed binding typed later ("hslint has no
  type"). `r21/r21.tsv`: tc196 and tcfail071 (GHC's and jhc's copies) are refused in 98 by R21 and accepted in 2010;
  tcfail144's two copies are refused in both, by their own `{-# LANGUAGE Haskell98 #-}`. The spike keeps the edge to
  a signed variable of a non-simple pattern binding.
- **`foreign`** (E3-06): reserved in 2010 only; declarations parsed by T10's grammar into a new node, printed and
  dumped; the renamer then refuses them (no lowering: that is E10's).
- **The pre-scan** (E3-07): `HsLexer.headerPragmas`, 71 code lines in `lexer.sml`, after unlit, reading every pragma
  before the first lexeme past comments. On `programs/pragma1-6`: lower-case `language` works, both literate styles
  work, a LANGUAGE pragma after `module` is ignored, an unsupported feature in a 2010 module is an error, and a file
  that says `Haskell98` refuses a pattern guard whatever the command line says. The finding that shaped D6: a strict
  pre-scan in 98 mode refused 8 vendored run-set programs that name DatatypeContexts, ExistentialQuantification,
  ConstrainedClassMethods, GeneralizedNewtypeDeriving, CPP or BangPatterns, which rhc ignores today (F's report; no
  result file lists them). The vendored corpus holds exactly 8 files with a LANGUAGE pragma, naming those six
  [counted]. So a 98 module reads edition names only, and with that the spike's one change to 98 mode is that a file
  naming `Haskell2010` is read as 2010.

**Result: how headers are written** (`pragmas/summary.tsv`):

| | GHC's testsuite | nofib | corpus |
|---|---:|---:|---:|
| files scanned | 11,227 | 657 | 3,089 |
| a LANGUAGE pragma in the header | 6,751 | 126 | 655 |
| several LANGUAGE pragmas | 2,278 | 40 | 50 |
| a LANGUAGE pragma over several lines | 282 | 6 | 52 |
| a comment before a LANGUAGE pragma | 220 | 10 | 42 |
| keyword not all capitals | 175 | 0 | 1 |
| OPTIONS_GHC or OPTIONS with `-X` | 106 | 0 | 66 |
| a LANGUAGE pragma after the header | 13 | 0 | 0 |

**Result: CPP** (`cpp/cpp-summary.tsv`, `cpp/probe.tsv`, `cpp/lines.tsv`).

| Corpus | Files | Enable CPP in the header | Have directives | Directives, CPP not enabled | `#include` |
|---|---:|---:|---:|---:|---:|
| tests/hs/corpus | 3,089 | 12 | 41 | 33 | 19 |
| nofib | 657 | 76 | 93 | 20 | 22 |
| GHC's testsuite files naming Haskell2010 | 508 | 2 | 2 | 0 | 1 |

On 16 samples with no `#include`, TemplateHaskell or QuasiQuotes, ignoring blank lines and line markers,
`cpp -traditional -P` matches `ghc -cpp -E` on 14, and so does `-undef`; with `-undef -x assembler-with-cpp` and GHC's
own `-D` flags it matches on 16. The two misses test `__GLASGOW_HASKELL__`. `-P` loses line numbers: sample s07 goes
from 122 lines to 82, s08 from 183 to 124. GHC 9.4.7's own line is `gcc -E -undef -traditional ... -x
assembler-with-cpp` (`cpp/ghc-cpp-invocation.txt`).

**Result: two defects at the pin** [measured].
- **`--dotted-names` is missing from the store's key** (`dotted/repro.out`). `print ((M.Just.id) 'x')` with `import
  qualified Prelude as M` prints `Just 'x'` plainly and is refused under `--dotted-names --no-store`. Compiled plainly
  into a store and then with `--dotted-names` against it, the unit Main is taken and the program prints `Just 'x'`
  (also with `-o` and `--typecheck-only`). `extraOf` names no such flag (`src/rhc/driver.sml:172-178`). haskell98 fixed
  it after the pin (build-cache-issues.md, issue 27).
- **Rule 1 in 98 mode** (`defects/rule1-signed/repro.out`): `f :: Num a => a -> a` and `xs = [f (1 :: Int)]`, each
  using the other, are one group under 98's 4.5.1, restricted by xs, so f's signature with a context must be refused.
  The checker accepts it (`RUNE_LINT=0` prints `(3,3.5,[2])`); HsLint refuses it at level 2 (`mr.rule1.constrained`).

**What would have flipped it.** Implied: 98 mode moving, and the explorer's suspicion of the key. 98 held, but only
after the strict pre-scan was replaced by the edition-only reading of a 98 module; had no such reading existed, D6
would have had to choose between 98's bytes and chapter 12's error. The suspicion was right.

**Not established.**
- The identity checks ran once, on the whole series, not on each prefix.
- **No 98 check met a pragma.** The run-set harness blanks every LANGUAGE and OPTIONS pragma in a program's sources as
  it prepares them, in every variant but `ext` (`tests/runner/hssource.sml:276-298`, applied at
  `tests/runner/hscorpus.sml:190-195`) [read], and tests/hs/lang, accept and errors hold no LANGUAGE pragma at all
  [counted]. So the run-set identity was measured on copies without pragmas, and where the 8 refusals above came from is
  not recorded.
- That `--print` and `--print-layout` drop header pragmas, so that a printed `pragma1.hs` is refused in 98 mode, rests
  on F's report; it is consistent with the printer, where only Exact mode prints trivia
  (`lib/language/haskell/print.sml:129-140`) [read].
- The reading of 4.5.1 for a signed variable of a non-simple pattern binding. The lead's probe (`results/D16-probes/`,
  `rhc.out`) shows the spike in 2010 mode refusing `PatCut.hs`, which GHC accepts in both modes.
- DoAndIfThenElse in `let` and `case` blocks (E1's N13): only `do` blocks were tested.
- Dotted library modules: the 2010 library was not spiked, and the library's file list is read one level deep
  (*Where we are*).
- The production size. F's guess, 700 to 1,100 lines of SML before tests, is [inferred].

### E4. One language record

**Question.** Can one language record, looked up per module, replace rhc's scattered settings (global refs, the
hard-coded "haskell98", the library's module names), with the library a descriptor per language, while 98's bytes stay
put? What does a second snapshot cost, what share of `make check` would a 2010 tier take, and what does the default
flip touch? **Settles:** D1, D3, D4, D9, D10, D41, and it sorted rhc's own options for D8.

**How.** Agent A in `h10-a`. First it read the other session's branches with read-only git (`other-session.md`): hs-bc,
hs-bc2 and hs-bc3 (rhc's store), hs-rr, hs-tt, hs-cs. The prototype (`patches/E4-language-record.patch`, 2,070 lines)
adds `HsLanguage` and `HsLibraryNames` in two new files (`lib/language/haskell/language.sml`, `language_sig.sml`) and
threads a module's language through the lexer, parser, graph, checker, HsLint, simplifier, driver and unit keys. The
2010 library is a stub: `cp -a share/rhc/haskell98 share/rhc/haskell2010`, read under 2010's features. Build 4 ran on
2026-11-17; build 6, the final patch, on 2026-11-21 after the stop, and every check was run again on it.
- Bytes: `dualrhc.sh` runs the prototype and `75ed95861`'s rhc (a copy of `h10-a`'s `bin/` taken before any edit) on
  one command line, each against its own 98 snapshot, and compares; `lang_bytes.sh` over tests/hs/lang (both
  targets), errors and accept at `RUNE_LINT=2`; the check tier's `hs-corpus-run` jobs with `RUNE_HS_RHC=dualrhc.sh`.
  Then 211 check-tier jobs of rhc's own suites.
- Per module: `permodule/` (`run3.sh`, `results3.txt`; `run2.sh`, `results2-b6.txt`), each case on the units path and
  under `--whole`.
- Snapshots: `snapshot.sh` as make's rule builds one (two `RUNE_LINT=2` compiles, timed), and `compare_stores.py`
  compares two stores entry by entry.
- `cost.md` from existing timings; `flip_inventory.py` over h10-base for every place that runs rhc.

**Result: the record.** An edition plus an ordered list of on and off flags, resolved to a sorted set of features, as
E5's model has it. Nine features: six of 2010's (DoAndIfThenElse, EmptyDataDecls, ForeignFunctionInterface,
HierarchicalModules, PatternGuards, RelaxedPolyRec), one of 98's (NPlusKPatterns), two of rhc's (CycleDefaultScc,
GreatestFixpointNames). Its canonical form, used in keys, leaves the edition out, and 98's own set keys as the empty
string, so 98's keys do not change. Unknown names are errors; `implied` is empty (E13 fills it). A pre-scan reads the
LANGUAGE pragmas from the unlit text.

**Result: the patch** [counted with `git apply --numstat`]: tracked +470 / -222 over 33 files (`rhc.plan` aside) and
226 lines in the two new files, in 121 hunks. By area: `src/rhc` +291 / -136, HsLint +81 / -39, the checker +25 / -9,
lexer and parser +24 / -11, the simplifier +20 / -13, the Makefile +12 / -4, test drivers +11 / -8, build files
+4 / -2, `docs/rhc.md` +2. It removes the hard-coded "haskell98" from rhc's code (among them `src/rhc/library.sml:44`
and the checker's `standard` test, `lib/language/haskell/infer.sml:2010`), but for the two descriptor records,
`extraOf`'s 98 exception and the option parser, and sends the library's role modules (Prelude, PreludeText, Ix, Ratio,
PreludeBuiltin) through the descriptor.

**Result: per module** [measured: `permodule/results3.txt`, build 6; the units path and `--whole` agree in every case].
The checker looks a binding's language up by the binding's module, replacing the run-wide `cycle` and `standard`
(`lib/language/haskell/infer.sml:2007-2010`); HsLint by module and by group, so the hard-coded `cycleDefault = false`
(`src/rhc/driver.sml:300`) goes. n+k runs in 98, is refused in 2010, is refused in 98 under `-XNoNPlusKPatterns` and
restored in 2010 by `-XNPlusKPatterns`. 4.5.1's example is refused in 98 by R21 and accepted in 2010 and under
`-XRelaxedPolyRec`. A 98 Main with n+k imports a module marked `Haskell2010` and runs. A `.lhs` with
`NoNPlusKPatterns` is refused at its line (`mixed/B.lhs:4:10`). A cycle whose modules differ on CycleDefaultScc is
refused; agreeing, it runs. In one recursive unit with A under RelaxedPolyRec and B not, only B's group is refused
(`cycle2/B.hs:7:1`); with both under it the program runs (`permodule/results2-b6.txt`).

**Result: keys and the store.** Each member's canonical set goes into the unit key, the program's base language into
the header's mode, the library's name into the configuration (`extraOf`) for every library but haskell98's. Pragmas
are cached in the header entry and written only when present, so the warm path stays stat-only and 98's header bytes
do not change. HsIface is unchanged: a feature changes how a module is checked, not its interface. Measured in
`permodule/results3.txt`: under `-XRelaxedPolyRec` the store takes A, whose own 2010 pragma already gives that set,
and compiles Main again; under `--cycle-default=scc`, `--names=greatest` and `--language=haskell2010` the library's
units are taken from the snapshot, where at the pin the first two force a whole compile
(`src/rhc/syntax.sml:152-154`).

**Result: snapshots** [measured].
- The prototype's 98 snapshot against `75ed95861`'s, both built at one `--share` path and one Main path: 68 entries in
  four configurations, every entry and key equal; only rhc's identity differs (`snapshot-98-compare.txt`). The
  library's 24 unsigned bindings infer the same types under 98's and 2010's features, the library's prefix aside
  (`libtypes/hslint98.txt`, `hslint10.txt`) [counted].
- One compile of a snapshot takes 5.7 to 8.2 s of user and system time whichever language, at a load of about 50 by
  A's report (`snapshot-times-{base98,new98,new10}.tsv`) [counted]; the report's 5.5 to 7.5 s misses the base 98
  run's 8.2 s.
- The Makefile's new rule builds both languages into one layer: 43.2 s wall, 26.4 s user, 5.1 s system on build 6
  (`logs/build6-layer.log`). The layer is 82,954,000 bytes on build 5 (`logs/build-layer.log`); build 6's log records
  no size. The single-language sizes, 41,334,255 bytes for 98 and 41,620,966 for the 2010 stub, are A's; no file keeps
  the measurement.
- A snapshot's entries depend on the path they were built at: the layer shipped in h10-base names the other session's
  tree in 20 files, and 10 of its 33 unit entries differ from the same layer built in `h10-a` (README). BC's issues 9
  and 31 fix this after the pin.

**Result: 98's output** [measured, build 6].

| Set | Result |
|---|---|
| tests/hs/lang | 1,182 of 1,182 bytecode files identical: 591 programs, two targets (`bytes6-lang.log`) |
| tests/hs/errors | 633 of 633 status and output identical (`bytes6-errors.log`) |
| tests/hs/accept | 251 of 251 identical (`bytes6-accept.log`) |
| the check tier's run set | 198 compiles byte-identical (99 programs, two targets) and 52 refused tries identical (`bytes6-corpus.log`); 116 of 116 jobs pass (`logs/corpus-run6.log`) |
| rhc's suites, 211 check-tier jobs | 210 pass (`logs/suites6.log`) |

The one failure is `hs/names/imp/greatest`. At the pin `--names=greatest` also solves the library's cycle at the
greatest fixpoint, which lets a program's `T1.map` into List's exports; `greatest.names` pins 958 pairs. With the
library immune to the program's flags it prints 955, as at the least fixpoint. That is the owner item in D8. The checks
found three faults on the way, fixed in build 6: three malformed literate files escaped as an uncaught exception on
build 4 (`lit.bird.adjacent.after`, `.before`, `lit.latex.unterminated`: `DIFF-OUT` in `bytes-errors.log`), and on build
5 `hs/syntax/budget` went over its budget by about 14% (A's report; no file).

**Result: what HsLint costs.** RelaxedPolyRec took one change in the checker (`groupsOf`'s edges) and four in HsLint:
`groupsOf`, signatures in scope from the start at the top level and in local declarations, and two replay sites.
Without the signatures, level 2 refused the mixed program with "hslint has no type for `A.g`" on build 3 (A's report;
output not kept).

**Result: rhc's own options** (for D8). `--dotted-names` fits as a per-module feature; `--cycle-default=scc` and
`--names=greatest` as settings of a whole cycle with an agreement check, which also stops them forcing a whole compile.
`--strings`, `--match` (whose `HsMatch.order` stays global and in `extraOf`), `--eta`, `--unfoldings`,
`--no-cheap-eagerness`, `-O`, `--by-interface`, `--whole` and `--lint` are compile modes, not language.

**Result: the other session** (`other-session.md`, `apply-h98tip.log`). haskell98 reached `1429fe5fc` on
2026-11-21. Its merge `8134f92fe` (hs-bc2, the store) touches 16 of the patch's 34 files; `0c7f50a9d` (hs-tt) touches
another rule of the Makefile. On the tip 12 of the patch's 121 hunks are rejected: `src/rhc/driver.sml` 4,
`lib/language/haskell/hslint.sml` 3, `src/rhc/graph.sml` 2, and one each in `hslint_env.sml`, `src/rhc/names.sml` and
`src/rhc/syntax.sml` [counted: 12 rejected hunks]. BC closes the `--dotted-names` hole through `extraOf`; the record
closes it through the key, which covers pragmas too.

**Result: cost** (`cost.md`, [inferred] from existing timings). rhc's check tier is 4,515 s of CPU, 38.0% of the
11,879 s base (`docs/plans/language/haskell98.md:7231`, `docs/testing.md:258-261`); the clause families are 4,400 of
rhc's 5,133 check jobs (`check-tier-list.txt`), so 86% of the tier is taken as theirs. A 2010 tier of 98's shape, at
98's cost per row:
- rows shared by clause id, adding the changed and new rows: 4,515 x 0.86 x 2,270 / 3,901 = 2,259 s, +19.0% of the
  base and +7.7% of the 29,255 s that `make check` took at `e5db9feca`;
- every row its own program: 4,515 x 0.86 x 5,259 / 3,901 = 5,235 s, +44.1% and +17.9%.

`cost.md` used 5,348 rows with 1,447 new, which `clauses2010-counts.tsv` does not have; it gave 2,350 s and 5,320 s
(+20% to +45%). The rule is A's, the row counts E1's (W8 found this). Its "FFI's 1,063 new rows" and "libraries' 1,402"
are 1,038 and 1,339 in `results/E1/delta-rows-counts.tsv`. The conclusion stands either way.

**Result: the default flip** (`flip-inventory.tsv`, 239 rows [counted]): 52 lines that build or run an rhc command in
17 runner files, and 9 helper definitions; 19 runner files have one or the other, and 22 mention rhc at all, prose
included (74 prose lines). Then 14 Makefile lines that invoke rhc (and 5 comments), 77 lines of docs, 8 in tests/hs
READMEs. A helper's callers are not counted line by line. The report and `cost.md` say "52 command lines in 22 runner
files"; the 52 are in 17. Nothing pins them all in one place. The cheapest pin is an `RHC_LANGUAGE` default read as
`RHC_STORE` is (`src/rhc/storeconfig.sml:49`), set to haskell98 in `bin/rune-test`'s wrapper beside `RHC_STORE=`
(`Makefile:2240`): about 6 lines against about 60 call sites [inferred]. In rhc the flip itself is two defaults.

**What would have flipped it.** Implied: 98's bytes moving, or the patch colliding with BC's work on the store and
driver. The bytes held except for the one pinned `greatest` dump, which the design changes on purpose and the owner must
accept. The collision is real but local: 12 hunks in six files, so the record's milestone is written on BC's driver.

**Not established.**
- **The 98 checks met no pragma.** tests/hs/lang, accept and errors hold none, and the run-set harness blanks them
  (E3's *Not established*). The prototype refuses an unknown name in a 98 module, where D6 ignores it; its corpus run
  met the vendored files that name one (`tcrun006`, `tcrun029`, `tc159` are in the check tier) only with their
  pragmas blanked.
- **The per-module cases put feature names in 98 modules** (`permodule/cycle2`, `cycle3`, `mixed/B.lhs`), which D6's
  edition-only reading would ignore. They show the mechanism; the kept tests need the features in 2010 modules (as
  for E13).
- The 2010 library is a stub, so the 2010 snapshot's size and time are those of 98's library read under other
  features.
- The patch was not rebased on BC's driver.
- No 2010 tier was timed: Run D gives no split by family, and the clause families' share is taken from job counts.
- HsIface stayed unchanged because none of the nine features changes an interface. TypeApplications' variable order
  and the FFI's newtype visibility will (D9).

### E5. GHC's flag semantics as data

**Question.** How does GHC turn editions, `-X` flags and pragmas into a module's set of extensions, precisely enough
for rhc to mirror it as data, and what do the other implementations do? **Settles:** D4, D5, D6, D7, D11.

**How.** Agent X3, on 2026-11-17, with its share of the census (the plan named X1; the briefs gave E5 to X3). The
source of record is GHC 9.14.1: `names.py` over its extension constructors and flag tables (`names.tsv`),
`lexer_bits.py` over the lexer (`lexer-bits.tsv`), `uses.py` for where each extension is consulted (`ext-uses.tsv`),
`editions_check.py` for the editions against the implications (`editions-check.txt`). Every claim was probed on GHC
9.4.7 where it can be: 137 probes, each with the outcome predicted from the source before it ran, and 37 diagnostic
probes (`probes/run.sh`, `probes/results.tsv`, 174 rows); GHCi's `:show language` (`probes/show-language.txt`); 9.4.7's
own editions and implications read through the installed `ghc` library (`probes/api/tables-947.txt`). `others.py` and
`others.md` read Cabal, haskell-src-exts, jhc, Hugs and MicroHs. No module enabling TemplateHaskell or QuasiQuotes was
compiled; one probe enables TemplateHaskellQuotes, which runs no code.

**Result: the names** (`names.tsv`, 148 rows [counted]). 135 extension constructors, 3 alternate names
(GeneralisedNewtypeDeriving, Rank2Types, PolymorphicComponents), 3 deprecated names (DoRec, RecordPuns,
PatternSignatures), 4 editions and 3 Safe Haskell modes. Every extension name has a `No` form; editions and Safe modes
have none. GHC 9.4.7 has 137 of the 148; the 11 newer ones (GHC2024 among them) are "source only".

**Result: resolution** (`semantics.md`, section 0), each point read in 9.14.1 and measured on 9.4.7:
- A module's setting is an optional edition and an ordered list of On and Off steps; the effective set is the edition's
  list with the steps replayed oldest first. No edition means GHC2021 (GHC 9.14.1
  `compiler/GHC/Driver/Flags.hs:66-69`).
- An edition is a base, not a step: `-XEdition` replaces only the edition
  (`compiler/GHC/Driver/DynFlags.hs:1127-1132`), and the last edition wins (P02a-P02d).
- Turning a flag on appends what it implies at that moment, recursively; turning it off undoes nothing
  (`compiler/GHC/Driver/Session.hs:2979-2996`). A later No wins over an earlier implication and loses to a later one
  (P04c, P04d), inside one pragma too.
- There are 38 implications in 9.14.1 (`compiler/GHC/Driver/Flags.hs:286-359`) and 35 in 9.4.7, three of them
  negative. Editions are not closed under them: GHC2021's TypeOperators lacks the ExplicitNamespaces it implies
  (`Flags.hs:324`), measured by `module M (type T)` refused under the default and accepted with an explicit
  `-XTypeOperators` (P05a, P05b).
- Header pragmas are later steps on top of the command line, in text order; the command line can never override a
  module's pragma (P03a-P03f, P11c, P11d).
- The header is pragmas and comments up to the first other token; a `#!` line may come first. The keyword is
  case-insensitive, the names case-sensitive (P09h refuses `Cpp`). A LANGUAGE pragma after `module` is ignored with a
  warning (P10a). Unlit runs first, and after CPP the header is read again, so a pragma inside `#if` counts by the
  condition (P12a-P12c, P13a-P13d).
- Settings are per module (P15a-P15c), and an edition selects no library: `{-# LANGUAGE Haskell98 #-}` with
  `import Monad` fails (P17e).
- Of the lexer's 50 extension bits, 31 change the lexer, 18 only the parser, and one is unused (`lexer-bits.tsv`)
  [counted]. Five flags are consulted nowhere beyond their implications: RelaxedPolyRec, ParallelArrays, TypeInType,
  AutoDeriveTypeable, JavaScriptFFI (`ext-uses.tsv`).
- No combination of extensions is refused when flags are read; the Safe modes are the exception (two modes are an
  error, P16a, P16b, P16g).
- Of 35 diagnostic probes GHC refuses under `-XHaskell2010`, 26 name the extension that would accept the construct;
  the 9 that do not are all decided in the lexer (capi, interruptible, ExtendedLiterals, MagicHash, UnboxedTuples,
  UnboxedSums, parallel arrays, a foreign import under `-XHaskell98`, `javascript`) (`probes/diag-names.tsv`)
  [counted].
- GHC's editions are not the Reports': its Haskell98 has NondecreasingIndentation and DeepSubsumption (P17c, P17d), and
  its Haskell2010 adds DeepSubsumption, ListTuplePuns and ImplicitStagePersistence.

**Result: the others** (`others.md`). Cabal has 152 known extensions and 4 languages with no implications, and passes
`-XHaskell98` when a package gives no `default-language`
(`libraries/Cabal/Cabal/src/Distribution/Simple/GHC/Internal.hs:586` in GHC's tree) [read], which E7 weighs.
haskell-src-exts closes implications over the final set, so a No of an implied extension never wins, and drops unknown
names. jhc maps many names onto a few flags. Hugs reads no LANGUAGE pragma. MicroHs has about 72 extensions always on
and CPP as its only switch. Only GHC has ordered implications and errors on unknown names.

**Result: the probes.** 129 of the 137 matched the prediction (`probes/results.tsv` [counted]). Three misses were X3's
own readings of 9.14.1's source that 9.4.7 does not share or that the source hid: TypeInType's deprecation is newer
than 9.4.7 (P08i); under the default GHC2021, which contains GeneralizedNewtypeDeriving, every Safe module warns about
it (P16e); an edition's DatatypeContexts is silent where X3 expected a warning (P18t). Five are GHC departing from the
Report outside resolution: `forall` is always a keyword in types (P18a), a prefix `!` is a bang in every mode (P18f,
P18o), and OverloadedStrings' defaulting and base's Foldable `length` decide P18i and P18j.

**What would have flipped it.** None set. Had GHC's resolution not been expressible as a base plus ordered steps, D5's
"mirror GHC" would have needed GHC's code rather than its tables; E13 confirms that the tables suffice.

**Not established.**
- TemplateHaskell and QuasiQuotes were never compiled, by the campaign's rule.
- The 11 newer names, GHC2024, 9.14.1's three newer implications and TypeInType's deprecation are source only.
- The other implementations were read, not run.
- That two spellings of one set with different editions fingerprint differently in GHC is [inferred] from the source.

### E13. The tracking design under test

**Question.** Does the tracking design hold? (a) Can GHC's resolution be written as data that reproduces what GHC does?
(b) Which combinations must rhc refuse, given that GHC refuses none? (c) Does the store stay right when pragmas,
editions, `-X` and `--language` change between compiles, with mixed settings inside a recursive unit? **Settles:** D5,
D7, D8, D9, D10.

**How.** Agent A, on 2026-11-21, on E4's prototype in `h10-a`, builds 7 to 9. `patches/E13-language-record-b9.patch`
(2,121 lines) is E4's patch plus 25 tracked lines and 26 lines in the new files: tracked +495 / -222, new files 252
[counted].
- (a) `model.py` is the model as data: GHC 9.4.7's own editions, 35 implications, flag names and `-fglasgow-exts` set
  (`results/E5/probes/api/tables-947.txt`), the 148 names of `results/E5/names.tsv` with their deprecations, and E5's
  rules. Each probe file has a predicate saying what it needs on or off, written from the file and the probe's question,
  not from GHC's answer. Its predictions are compared with GHC's 137 outcomes (`results/E5/probes/results.tsv`) and its
  sets with the 19 `:show language` captures.
- (b) `combinations.md`, a table over D35's 72 recommended names and rhc's own switches, and the prototype refusing one
  (`combo/`).
- (c) `edits.py`: 10 programs of 2 to 4 modules (a recursive unit A+B beside C and Main, a chain, a diamond, a literate
  module), 43 steps at `RUNE_LINT=2`. Each step is compiled warm into one store and cold with `--no-store`; the oracle
  is the same bytecode, or the same diagnostics where both refuse. Each step's units to be compiled again were written
  beforehand.
- Then E4's 98 byte check again on build 9 (`bytes9.sh`).

**Result: resolution** [measured]. All 19 `:show language` sets agree, edition and every modifier (`showlang.tsv`):
implication chains, a No after its implier, the negative implications, Safe, `-fglasgow-exts` and GHC2021's missing
ExplicitNamespaces. 132 of the 137 outcomes agree (`predictions.tsv` [counted]), all 116 of P01-P17; by kind 52
accepted, 63 refused and 17 warned, as GHC (`agreement.md`). The 5 that do not are P18a, P18f, P18i, P18j and P18o,
where the model's feature set is GHC's and GHC departs from the Report outside resolution (E5's result). One bug of the
model was fixed on the way: after CPP, the warnings of the first header read must be dropped (P13a, P13d, P13f). The
report says these 5 are "the same 5 that E5 had already flagged"; E5 flagged 8 (`results/E5/probes/results.tsv`), and
the model, built on 9.4.7's own tables, gets the other 3 right.

Where rhc's design would resolve differently (`predictions.tsv`, column `rhc_design`, [inferred]): 77 of the 137, a
probe for one reason or several. 45 give no edition, so rhc's default applies (98, or 2010 after G3), not GHC2021; 9
name GHC2021 or GHC2024, refused (D5); 8 use Safe, not supported; 24 name a feature outside rhc's set; 7 use CPP (D12);
1 has an OPTIONS_GHC flag other than `-X`; 5 use GHC's old `-f` spellings.

**Result: combinations** (`combinations.md`). Refuse C1, two Safe modes (as GHC); C2, the modules of one recursive unit
differing on a setting of the whole cycle (CycleDefaultScc, GreatestFixpointNames); C3, HierarchicalModules off in a
program whose library is hierarchical. C4, the policy: a recommended feature that implies an unsupported one fails no
setting; only the unsupported construct is refused, where it is written. Accept, as GHC, C5-C7, C9, C11 and C12; C8
(NoRelaxedPolyRec in a 2010 module) is the owner's; C10 follows D12. The prototype refuses C3 at its name,
`NoHier.hs:3:31`, under 2010's library and runs the same file under 98's (`combo/results.txt`, build 8). An unknown name
is now reported at its line and column (`Unknown.hs:3:14`) in compiles, under `--whole`, `--parse-only` and in a `.lhs`
file; on build 6 it read `Unknown.hs: error:` (`results/E4/permodule/results3.txt`).

**Result: the store under edits** (`edits.tsv`, build 9 [counted]).
- Warm equals the `--no-store` oracle in 43 of 43 steps, and 43 of 43 went as expected; 39 compile and 4 are refused,
  warm and cold alike.
- Unit fates: 47 compiled, 50 taken, 1 named (a unit after a failed one). The library's units were taken from the
  snapshot in all 40 steps that got as far as units; the report says 39, and the fortieth is `p06` step 2, refused
  after A was compiled.
- The edited module's unit is compiled again whenever its text or its resolved set changes; in the cycle that is the
  whole A+B unit. In the 17 steps where a module with importers was compiled again, every importer was taken: a
  feature changes how a module is checked, not its interface, and importers are judged by the usages they recorded.
- Entries are shared whenever the text and the resolved set return to an earlier state (`p01`, `p02`, `p04`, `p05`,
  `p06`, `p09`, `p10`). Under `-XRelaxedPolyRec` or `-XNoNPlusKPatterns` on the command line, a module whose own
  `Haskell2010` pragma already gives that set is taken and only Main is compiled (`p09`). `--language` puts each
  library in its own configuration, so switching back and forth takes everything (`p10`).
- **The HsLint fault.** On build 8, `p03` steps 1 and 4, a cycle with A under RelaxedPolyRec and B not, were refused,
  warm and cold alike (`edits-build8.tsv`). The cause: HsLint put signatures in scope early only for bindings of relaxed
  modules. Build 9 does it for every signed binding of a group in which any module is relaxed, as THIH's `tiBindGroup`
  does and as the checker already did. E4's per-module cases had not met it. The message the report and README quote,
  "hslint has no type for `A.a`", is in no kept file: `edits-build8.tsv`'s diagnostic column is empty.
- **The expectations moved once.** On build 8, 13 of 43 steps were marked unexpected: the 10 first compiles (the
  harness then expected nothing to be made at step 0), `p03`'s two, and `p08` step 3, where an export was added to A and
  the harness expected B and C to be compiled again. They were taken, warm equal to cold, and build 9's expectation is A
  alone. So the report's "this held even when an export was added" is a result the harness first did not predict; the
  oracle is what stands.
- 98's output on build 9: tests/hs/errors 633 of 633 and accept 251 of 251 identical, and every tenth program of lang,
  60 programs on two targets, 120 of 120 (`bytes9-errors.log`, `bytes9-accept.log`, `bytes9-lang.log`).

**What would have flipped it.** Implied by the plan: a warm compile whose bytes differ from the `--no-store` oracle.
None did. Had one, the canonical set in the unit key would not have been enough, and D9 would have needed the edition or
the step list in keys, or HsIface fields for features that change nothing in an interface.

**Not established.**
- **D6's 98 modules.** 9 of the 43 steps put a feature name other than an edition into a module with no edition
  pragma, compiled under the default `--language=haskell98`, so a 98 module: `p01` steps 1 and 4, `p02` step 3, `p03`
  steps 1 and 2, `p04` step 1, `p05` step 2 and `p06` steps 1 and 2 [counted from `edits.py`]. That is 9 of the 25
  steps that edit a pragma. D6 reads only edition names in a 98 module and ignores the rest; the prototype honours them.
  So these steps show the store's mechanism (a module's resolved set in its key), which holds, but under D6 their
  pragmas would be ignored and they would test edits of text, not of language. W9 found this. The kept edit test
  should move those edits into 2010 modules, with a `Haskell2010` pragma or `--language=haskell2010`; the mixed cycle
  of `p03`, which found the HsLint fault, becomes a 2010 module and a 98 module in one unit.
- **C8's evidence.** `combinations.md` cites `p06` step 2 to show that rhc can check NoRelaxedPolyRec by 98's 4.5.1.
  That step's module is a 98 module (its pragma replaced the `Haskell2010` one) [counted from `edits.py`], so it shows
  98's rule, not NoRelaxedPolyRec in a 2010 module, which nothing tested.
- The model mirrors 9.4.7's tables, the only binary there is; 9.14.1's three newer implications are not checked
  against a run.
- The prototype has no OPTIONS_GHC, no CPP and no Safe, and it refuses an unknown name in a 98 module where D6 ignores
  it.
- Of the combination table only C3 (here) and C2 (E4) were prototyped; the rest is drafted.
- The edit test has 10 small programs; it edits no library module, and no feature yet changes an interface (D9's
  variable order and newtype visibility).
- 98's bytes on build 9 were sampled: every tenth program of tests/hs/lang.

### E6. The census

**Question.** What does each of GHC 9.14.1's 148 LANGUAGE names ask of rhc? For each name: its area; the rung of the
type-system ladder it needs (T0-T8); what Core needs (nothing, System F as it is, a Cast under constructors, System FC,
new primitives); runtime support; how GHC-specific it is; who else implements it; its specifying paper; whether turning
it on changes a valid Haskell 2010 program; what it costs HsLint; what OutsideIn(X) would rework; its size; and whether
this roadmap should do it. **Settles:** D35, D36, D37, and the extension table of the appendix. It gave track X
(M19-M27) its rows.

**How.** Three agents on one schema, on 2026-11-17. Files are in `results/E6/`, and a bare file name below is there.
- `schema.md` fixes 22 columns and their values; `validate.py` checks a file against it. The lead's `assign.tsv` gave
  each name one owner, by area: X1 53 names (syntax, lexing, layout, literals, records, patterns, `do` and
  comprehensions, modules, desugaring), X2 49 (types, classes, kinds, generalisation), X3 46 (FFI variants, runtime,
  meta, unboxed and unlifted, deriving, the editions, the Safe modes, alternate and deprecated names).
- Ten names were classified by all three, without conferring: BangPatterns, OverloadedStrings, RecordWildCards and
  LambdaCase (X1's), ScopedTypeVariables, GADTs, MultiParamTypeClasses and ExistentialQuantification (X2's),
  TemplateHaskell and DeriveFunctor (X3's). So `X1.tsv` has 59 rows, `X2.tsv` 55 and `X3.tsv` 54: 168 rows over 148
  names. The validator passes on all three.
- Four columns are computed from GHC's source, not judged: `since` (the docs' `:since:`), `in_947`
  (`ghc --supported-extensions` on 9.4.7), `editions` (`languageExtensions` in DynFlags.hs) and `implies`
  (`impliedXFlags` in Flags.hs). The rest is classification: GHC's docs page for the name
  (`docs/users_guide/exts/*.rst`), its implementation where the docs are thin, the other implementations under
  `/home/ruud/haskell`, and rhc's checker. The schema lists the checker's facts that set the tiers: a predicate has one
  type (`lib/language/haskell/types_sig.sml:59`), instances are keyed by class and type constructor
  (`lib/language/haskell/classes_sig.sml:18`), `HsTypes.ty` has no forall (`types_sig.sml:46-51`), and Core's `AltCon`
  binds no type variables (`lib/language/haskell/core_sig.sml:77`).
- `changes_valid` was measured where it could be. X1 wrote 41 probe modules (`X1-probes/`) and ran each on GHC 9.4.7
  under `-XHaskell2010`, without and with its extension: 82 runs, 2026-11-17T07:04:38Z to 07:05:31Z
  (`X1-data/probes.tsv`, `X1-data/probes.when`). X3 used E5's probes P14 and P18 (`results/E5/probes/`). No probe
  enabled TemplateHaskell or QuasiQuotes.
- X2 checked its evidence column with `X2-data/checkrefs.py`, which opens each of 209 distinct path:line references;
  rerun for this roadmap, 0 bad. X2's `others` column is a sub-agent's survey of seven systems, with a path:line for
  each yes (`X2-data/others.tsv`, method in `X2-data/others-method.txt`), which X2 spot-checked only in part.
- The lead merged the files (`merge.py`). `census.tsv` takes the owner's row of each name and joins E7's usage
  (`results/E7/ext-freq.tsv`) for 124 names; E7 has no row for the other 24 (the editions, the alternate and deprecated
  spellings, and names no snapshot module writes). The first join was by the positive spelling only, so for a name on in
  2010 it counted the form that matters least: ImplicitPrelude's row had 4 packages, where NoImplicitPrelude is named
  by 375, and FieldSelectors' 1 against NoFieldSelectors' 107 (`results/E7/ext-freq.tsv`). W11 found it; `census.tsv`
  now carries the No form's usage too (`no_packages`, `no_pct_packages`, `no_modules`). `overlap.tsv` sets the ten
  names' three rows side by side, column by column.
- Sizes are estimates without a prototype: S under 300 lines, M 300 to 1,000, L 1,000 to 3,000, XL more, counting the
  front end, HsLint and tests.

**Result: the recommendation** (`census.tsv`, 148 rows).

| rec | Names | Which |
|---|---:|---|
| now | 72 | the owners' own rows: X1 36, X2 25, X3 11 |
| later-other | 33 | the kinds (PolyKinds, DataKinds, ConstraintKinds, CUSKs, TypeData, LinearTypes), rank N beyond its core (ImpredicativeTypes, QuantifiedConstraints, DeepSubsumption, RequiredTypeArguments), RebindableSyntax, ImplicitParams, Safe, UnboxedTuples, ... |
| later-outsidein | 9 | GADTs, TypeFamilies, TypeFamilyDependencies, DeriveGeneric, OverloadedLists, OverloadedRecordDot, OverloadedLabels, ListTuplePuns, PatternSynonyms |
| later-meta | 6 | TemplateHaskell, TemplateHaskellQuotes, QuasiQuotes, DeriveLift, ExplicitLevelImports, ImplicitStagePersistence |
| later-runtime | 2 | CApiFFI, InterruptibleFFI |
| never | 14 | the three layout experiments, MagicHash, UnboxedSums, the unlifted family, ExtendedLiterals, GHCForeignImportPrim, JavaScriptFFI, StaticPointers, ParallelArrays, AutoDeriveTypeable |
| n/a | 12 | 4 editions, 3 alternate names, 5 deprecated names |

The agents' files count more "now" rows (`X1.tsv` 40, `X2.tsv` 30, `X3.tsv` 18), because each also holds the overlap
rows of the other two. Only the owners' rows count: 36 + 25 + 11 = 72.

**The 72, by tier.**

| Tier | Names | Which |
|---|---:|---|
| `-`, no type-system rule | 25 | the 2010 switches (DoAndIfThenElse, EmptyDataDecls, ImplicitPrelude, TraditionalRecordSyntax, FieldSelectors), ForeignFunctionInterface, CPP, the literals (BinaryLiterals, HexFloatLiterals, NumericUnderscores, NegativeLiterals, LexicalNegation, MultilineStrings), the records (NamedFieldPuns, RecordWildCards, DisambiguateRecordFields, DuplicateRecordFields), BlockArguments, ImportQualifiedPost, UnicodeSyntax, NondecreasingIndentation, Strict, StrictData, Trustworthy, Unsafe |
| T0 | 28 | PatternGuards, NPlusKPatterns, LambdaCase, TupleSections, MultiWayIf, EmptyCase, BangPatterns, ViewPatterns, OrPatterns, the deriving group, KindSignatures, ExplicitForAll, TypeOperators, ... |
| T1 | 9 | MultiParamTypeClasses, FlexibleInstances, FlexibleContexts, UndecidableInstances, OverlappingInstances, OverloadedStrings, GeneralizedNewtypeDeriving, DerivingVia, DefaultSignatures |
| T2 | 1 | FunctionalDependencies |
| T3 | 4 | ScopedTypeVariables, TypeApplications, AllowAmbiguousTypes, InstanceSigs |
| T4 | 1 | ExistentialQuantification |
| T5 | 1 | RankNTypes |
| T8 | 3 | RelaxedPolyRec, MonomorphismRestriction, MonoLocalBinds |

- **Sizes:** S 45, M 21, L 4 (MultiParamTypeClasses, FlexibleInstances, FunctionalDependencies,
  ExistentialQuantification), XL 2 (RankNTypes, ForeignFunctionInterface).
- **Core:** nothing new for 66; System F as it is for 3 (DefaultSignatures, ExistentialQuantification with type binders
  in `AltCon`, RankNTypes); a Cast under constructors for 2 (GeneralizedNewtypeDeriving, DerivingVia); new primitives
  for the FFI. No recommended row needs System FC. The five rows that do (GADTs, TypeFamilies, TypeFamilyDependencies,
  DeriveGeneric, OverloadedLists) are all later-outsidein, which is D37's boundary.
- **HsLint:** none 32, mirror 25, spec 15.

**Over all 148.** Tiers: `-` 46, T0 39, T1 14, T2 2, T3 8, T4 2, T5 9, T6 5, T7 18, T8 5. 67 names change some valid
2010 program: 59 extensions, 3 editions (GHC2021, GHC2024, Haskell98), 2 alternate names, 2 deprecated names and Safe.
28 of the 67 are recommended now, and come only when asked (D36). 11 names are source only, absent from 9.4.7.

**The cross-check** (`overlap.tsv`): how many of the ten names the three agents agree on, column by column.

| Column | Agree | Where they differ |
|---|---:|---|
| `kind`, `canonical` and the four computed columns | 10 | |
| `rec` | 10 | |
| `runtime` | 10 | |
| `core` | 9 | TemplateHaskell: X2 `prims`, the others `none` |
| `changes_valid` | 9 | LambdaCase: X2 `no`. X2 is wrong: X1 measured `\cases -> cases + 1` refused once LambdaCase is on (`lcases.hs`), and X3 too (E5's P18e) |
| `ghc_specific` | 9 | ScopedTypeVariables: X2 `partly` |
| `outsidein` | 9 | TemplateHaskell: X1 `small` |
| `tier` | 8 | OverloadedStrings T1, T1, T2 (X3); RecordWildCards `-` (X1), T0, T0 |
| `gates` | 8 | GADTs, OverloadedStrings |
| `hslint` | 8 | DeriveFunctor (X3 `none`), LambdaCase (X2 `none`) |
| `size` | 6 | BangPatterns M, S, S; OverloadedStrings M, S, M; RecordWildCards M, S, S; ScopedTypeVariables M, M, L |
| `others` | 5 | which systems each credited |
| `area` | 3 | whether a second area is named |
| `paper` | 0 | three conventions for keys |

The census keeps the owner's value where they differ: OverloadedStrings at T1 and RecordWildCards at `-`, both X1's.

**Found on the way** (measured unless marked; most of it is told in *Found while writing* and *What the implementations
do*):
- **GHC 9.4.7 under `-XHaskell2010` refuses valid 2010 programs in four places** (`X1-data/probes.tsv`): `x = 1_000`
  with a variable `_000` in scope ("Illegal underscores in integer literals", `numund.hs`); `f = Just.do id`, which 2010
  reads as `Just . (do id)` ("Illegal qualified 'Just.do' block", `qualdo.hs`); a `!` that defines an operator
  (`bang.hs`, `bang2.hs`); and `forall` as a type variable (`forall.hs`). bugs.rst documents the last two
  (`/home/ruud/haskell/ghc/docs/users_guide/bugs.rst:44-57`), not the first two.
- **Other probes:**
  - LambdaCase changes valid programs since GHC 9.4: after a backslash, `cases` is a keyword (`lcases.hs`: "Variable
    not in scope: cases").
  - NoPatternGuards only warns ("accepting non-standard pattern guards", `pguard.hs`).
  - PostfixOperators changes a left section's strictness (`postfix.hs`: `whnf` off, `Prelude.undefined` on).
  - OverloadedRecordUpdate without RebindableSyntax refuses every record update (`recupd.hs`).
  - With NPlusKPatterns on, a top-level `x + 1 = x` still defines `+` (`nplusk.hs`).
- **Chapter 12 encourages five names, in GHC's spelling:** "PatternGuards, NoNPlusKPatterns, RelaxedPolyRec,
  EmptyDataDecls, ForeignFunctionInterface" (T10:10997-10999). DoAndIfThenElse is in GHC's Haskell2010 edition, not in
  that list.
- **X2, reading rhc** [read]:
  - HsLint's second inference has no rigid variables: `checkExpl` instantiates a signature with flexible variables,
    then requantifies and compares (`lib/language/haskell/hslint_infer.sml:698-722`). So T3, T4 and T5 each cost HsLint
    skolems and an escape check.
  - The one-type predicate reaches past the checker: a class declaration holds one variable
    (`lib/language/haskell/ast_sig.sml:151`), interfaces write a predicate as a class and a type (`hsiface.sml:66`),
    the desugarer's `dictArg` takes the one argument of a dictionary's type (`desugar_env.sml:186-190`), and HsLint's
    `IsIn` holds one type (`hslint_types.sml:180`).
  - `schemeOf` orders a scheme's variables by the type and then the context (`lib/language/haskell/infer.sml:578-601`),
    not left to right as GHC does. TypeApplications makes that order visible.
  - The checker takes its program-wide settings from refs set once per run (`infer.sml:2007-2010`), so every T8 flag
    needs D10's lookup per module.
- **The editions:** GHC2021 needs T5 (RankNTypes), T6 (DeriveGeneric) and T7 (PolyKinds, ConstraintKinds), and
  GHC2024 adds GADTs (T6). rhc cannot accept either honestly before those tiers (X2, W12).
- **Three defects in GHC 9.14.1's documentation** (X3):
  - `ghc/docs/users_guide/exts/empty_data_deriving.rst:11` puts EmptyDataDeriving in Haskell2010. X3's notes cite
    :8-9; the status line is at :11 (W1).
  - `control.rst`'s edition lists omit ListTuplePuns.
  - `overloaded_strings.rst:52-54` says `length "foo"` defaults to String; 9.4.7 refuses it as ambiguous (P18j).

**Not established.**
- **The sizes.** No row was built in E6. E3 (the 2010 switches), E10 (the FFI) and E12 (T1, T2, T4, T5) are the
  calibration; E12's result says how far the column moves.
- **Agreement beyond the ten.** 138 rows have one classifier. The ten are no random sample: eight are recommended now,
  and all ten are among the 36 names most used by package (E7's `ext-freq.tsv`: OverloadedStrings 2nd,
  ExistentialQuantification 36th).
- **T4's split.** The census has one T4; E11 split it later (its finding 3). ExistentialQuantification's row is T4a,
  givens on existential variables only. PatternSynonyms' T4 row is not split.
- **The `others` column.** X2's survey was spot-checked only in part; its least certain cells are listed in
  `X2-data/others-method.txt`. W1's corrections of the implementations' claims (E11, item 13) were made against E11,
  not against this column.
- **The paper keys.** They follow three conventions. X1 gave four from memory, X2 five, X3 seven (and three more with
  authors and years from memory). E11 did not check them.
- **`changes_valid = no`** is argued, not measured, except for the five X1 probed: NPlusKPatterns,
  DuplicateRecordFields, NondecreasingIndentation, RelaxedLayout, PatternGuards. GHC cannot show the `forall` and prefix
  `!` cases at all, since it departs from the Report there in every mode.
- **Usage.** E7's figures, joined here, count names written, not constructs used, and only the positive spelling
  (above): for ImplicitPrelude, FieldSelectors and ListTuplePuns, E7's No rows are the ones to read.

### E7. Usage on Hackage

**Question.** Which extensions does Haskell code on Hackage turn on, how often, and with which others? How much of it is
plain Haskell 2010? Which extensions, in what order, admit the most of it? What does CPP do in it? **Settles:** D12
(CPP) and D35 (the order of the recommended set and what it buys); and the Hackage part of E8's corpus.

**How.** Agent O, on 2026-11-17, with the network the owner allowed: Hackage's index and the sources of the latest
Stackage LTS. Files are in `results/E7/`; `README.md` there has the definitions and every command. The downloads are in
`downloads/hackage/` (about 1.2 GB, under the 3 GB cap), each fetch a row of `MANIFEST.tsv` (3,452 rows, each with its
sha256). Nothing from a download was run.
- **The index.** `01-index.tar.gz`, fetched at 06:55Z: 141,129,806 bytes, 362,208 entries, 19,711 packages
  (`index-summary.tsv`). Measure 1 reads the latest version of every package's `.cabal`.
- **The snapshot.** stackage.org/lts redirected to LTS 24.67 (ghc-9.10.3): 3,402 pinned packages, and 37 boot packages
  pinned at their ghc-9.10.3 versions from Stack's `global-hints.yaml`. That is 3,439 tarballs, 265,631,017 bytes, every
  one matching the index's sha256. 536 of the pinned versions are not Hackage's latest. Only `.cabal`, `.hs`, `.lhs`,
  `.hsc` and `.hs-boot` files were extracted: 59,563 files.
- **The population** of measure 2: 49,394 module files (hs, lhs, hsc) that a component names, from 3,392 packages
  (`scan-summary.tsv`). 255 hs-boot files are kept apart; 3,056 files no component names and 2,569 `Setup.hs` are left
  out.
- **Header pragmas** are read as GHC's `getOptions` reads them: after unlit, in the header only, both arms of an `#if`
  kept. Against a naive regex they disagree on 167 of 49,649 files, each the naive reader taking a pragma from a
  comment, an example or a string (`check-header.tsv`).
- **The edition** is a pragma's, else the component's `default-language`, else Haskell98: Cabal passes `-XHaskell98`
  when `default-language` is absent
  (`ghc/libraries/Cabal/Cabal/src/Distribution/Simple/GHC/Internal.hs:586`, under `/home/ruud/haskell`), although
  GHC's own default is GHC2021 (`ghc/compiler/GHC/Driver/Flags.hs:68-69`).
- **The effective set** follows GHC's `flattenExtensionFlags`: the edition's list, then each On (with its implications)
  or Off in order, the cabal file's first and the module's pragmas after. `r10` is what a file needs beyond Haskell2010.
- **The greedy cover** (measure 3) adds at each step the item that admits the most weight per new item, closed under
  GHC's implications. It is weighted by file (`cover.tsv`) and by package (`cover-pkg.tsv`, each package weighing 1).
  The restricted covers and the ceilings join E6's tiers (`tiers.tsv`). The md5s of the census files it read
  (`tiers-inputs.md5`) equal the final `X1.tsv`, `X2.tsv` and `X3.tsv`, and `tiers.tsv` matches `census.tsv` row for row
  (checked for this roadmap).
- **Measure 4** compares with the GHC2021 proposal's data (`downloads/hackage/ghc2021/`, from
  nomeata/ghc-proposals-stats). **Measure 5** lists plain-2010 modules for E8 (`plain2010.tsv`).

**Result: editions.**
- **The index** (`index-languages.tsv`), by component (39,312): Haskell2010 28,209 (71.8%), none 7,172 (18.2%), GHC2021
  2,376 (6.0%), Haskell98 784 (2.0%), GHC2024 771 (2.0%). By package (19,626): Haskell2010 68.2%, none 23.8%, GHC2021
  4.8%, Haskell98 2.0%, GHC2024 1.2%. Of packages whose latest version was uploaded in 2026: Haskell2010 72.8%, GHC2021
  16.2%, GHC2024 8.5%. All but 3 of the 4,667 packages with no `default-language` were last uploaded before 2021.
- **The snapshot's modules** (`editions.tsv`): Haskell2010 38,408 (77.8%); GHC2021 or GHC2024 7,456 (15.1%), from only
  200 packages; Haskell98 3,530 (7.1%), of which 2,268 name it and 1,262 get it by Cabal's default (309 packages).

**Plain Haskell** (`plain.tsv`, of 49,394 files).

| Measure | Files | Share | Packages |
|---|---:|---:|---:|
| plain2010: edition Haskell2010, nothing beyond it | 6,983 | 14.14% | 1,442 |
| plain98: edition Haskell98, nothing beyond it | 1,497 | 3.03% | 269 |
| clean2010: edition 98 or 2010, nothing beyond 2010 | 8,550 | 17.31% | 1,726 |
| clean2010, the Safe names allowed | 8,800 | 17.82% | 1,757 |
| clean2010, importing only the Report's library | 665 | 1.35% | 392 |

Whole packages that are clean2010: 287 of 3,392 (8.46%). Library files are less plain: 11.6% of them are plain2010.

**Frequency, by package** (`ext-freq.tsv`; packages naming it, of 3,392): CPP 1,581 (46.6%), OverloadedStrings 1,499
(44.2%), ScopedTypeVariables 1,401 (41.3%), FlexibleInstances 1,300 (38.3%), FlexibleContexts 1,148 (33.8%),
TypeFamilies 1,042 (30.7%), RankNTypes 967 (28.5%), MultiParamTypeClasses 933 (27.5%), LambdaCase 928 (27.4%),
GeneralizedNewtypeDeriving 892 (26.3%); then DeriveGeneric 830, RecordWildCards 801, BangPatterns 790, DataKinds 744,
DeriveDataTypeable 729, TypeOperators 715, UndecidableInstances 687, TemplateHaskell 668, GADTs 643, TypeApplications
625. By file the order differs, because large packages and `default-extensions` lists weigh in: OverloadedStrings
17,656 (35.7%), TypeFamilies 11,523, RecordWildCards 11,216, ScopedTypeVariables 10,506, LambdaCase 10,468, DataKinds
9,815, NoImplicitPrelude 9,475, CPP 9,184. The files that need one name only: OverloadedStrings 1,799, CPP 1,123,
PatternSynonyms 563, `OPTIONS:-F` (a custom preprocessor) 358, NoImplicitPrelude 238.

**Co-occurrence, by package** (`cooc-pkg.tsv`): FlexibleInstances is in 836 of the 933 packages with
MultiParamTypeClasses (89.6%); MultiParamTypeClasses in 331 of the 383 with FunctionalDependencies (86.4%);
ScopedTypeVariables in 549 of the 625 with TypeApplications (87.8%); TypeApplications in 221 of the 265 with
AllowAmbiguousTypes (83.4%); ScopedTypeVariables in 765 of the 967 with RankNTypes (79.1%); FlexibleInstances in 862 of
the 1,148 with FlexibleContexts (75.1%).

**CPP** (`cpp.tsv`, `cpp-macros.tsv`).
- On in 9,184 files (18.6%) and 1,581 packages (46.6%): by a pragma in 80.7% of those files, by the cabal file in
  17.0%, by both in 2.4%. For 1,123 files (2.3% of all) CPP is the only thing beyond 2010.
- 2,872 CPP files (31.3%) have no directive and expand no macro; 5,000 (54.4%) use only conditionals; 3,450 (37.6%)
  use only `#if`, `#elif`, `#else` and `#endif` on `MIN_VERSION_*` and `__GLASGOW_HASKELL__`.
- Of the 6,258 files with a directive: `#include` in 871 (13.9%), `#define` in 517 (8.3%); `MIN_VERSION_*` is tested in
  3,587 (57.3%), `__GLASGOW_HASKELL__` in 1,355 (21.7%).
- 336 CPP files (3.7%) expand a macro in code: their own `#define` in 257, a cabal `-D` in 50, a built-in in 29. 750
  (8.2%) include a local file. 190 define a function-like macro; 2 paste tokens.

**The covers.**
- **All items, by package** (`cover-pkg.tsv`): 50 steps admit 34,635 files (70.1%) and 2,326 whole packages (68.6%). By
  file (`cover.tsv`): 34,986 files (70.8%) and 2,182 packages (64.3%). The base, with nothing beyond 2010, is 8,751
  files (17.72%: clean2010 plus the hsc files). None of the 7,456 GHC2021 and GHC2024 files is admitted within 50 steps:
  each needs its whole edition.
- **Recommended items only, by package** (`cover-pkg-recnow.tsv`), the order D35 takes: OverloadedStrings, CPP,
  BangPatterns, NoImplicitPrelude, ScopedTypeVariables (with ExplicitForAll), FlexibleContexts, RankNTypes, LambdaCase,
  TypeApplications, RecordWildCards, FlexibleInstances, GeneralizedNewtypeDeriving, Trustworthy,
  MultiParamTypeClasses, TupleSections, NamedFieldPuns, ViewPatterns, UndecidableInstances, FunctionalDependencies,
  ExistentialQuantification. At 50 steps it reaches 22,053 files (44.65%) and 961 packages (28.33%).

**Ceilings** (`tier-needs.tsv`): what would be admitted if every item of a class were implemented.

| Implemented | Files | Whole packages |
|---|---:|---:|
| nothing beyond 2010 | 17.72% | 9.05% |
| every recommended item | 44.66% | 28.33% |
| every recommended item but CPP | 38.38% | 19.84% |
| every recommended or later-outsidein item | 50.39% | 31.87% |
| tiers `-` and T0-T5, and T8 | 59.26% | 42.60% |
| also T6 (packages: every module at most T6) | | 59.17% |
| every census row | 98.10% | 85.23% |

- The last row's gap is `OPTIONS:-F` (546 files), `-fplugin` (300) and MonadFailDesugaring (95), a name GHC 9.14 no
  longer knows.
- T8 is kept off the ladder in that file: 14,938 files (30.2%) need a T8 item, 14,330 of them MonoLocalBinds, mostly as
  GADTs' and TypeFamilies' implication.

**Against the GHC2021 data** (`ghc2021-crosscheck.tsv`): Spearman's rho 0.869 between the 2020 per-package use over all
of Hackage (13,951 packages) and this scan (106 names); 0.914 for the share of `default-extensions` users naming each
name, 2020 against today's index (105 names). Stackage's shares run higher throughout. CPP rose from 7th to 1st (22.8%
to 46.6%) and TypeApplications from 30th to 20th; OverlappingInstances fell from 44th to 82nd and DeriveDataTypeable
from 9th to 15th.

**The corpus for E8** (`plain2010.tsv`, md5 d9020a34..., the version E8 judged): 8,550 rows from 1,726 packages. 6,983
are plain2010 and 1,567 are `98-in-2010` (Haskell98 by `default-language` 1,116, by Cabal's default 451). 823 rows in
392 packages are `closed2010` (the module and its in-package imports listed, every other import a Report module); 665
import only Report modules; 115 have a `foreign` line. "Plain" is about flags only: most rows import modern libraries.

**Not established.**
- **Use.** A name written is not a construct used: a `default-extensions` list names extensions a module never needs,
  and a GHC2021 module carries its whole edition. The per-file figures overstate; whole packages are the union of
  their names.
- **Hackage at large.** Stackage is curated and maintained; its shares run above all of Hackage's (the cross-check). The
  pinned versions stand for "latest", 536 of them behind Hackage.
- **Compiling.** "Admitted" means only that the names are covered, not that rhc would compile the file: the library
  is not counted. E8 found that of 398 plain components GHC's 2010 mode accepts, 43 need modern base.
- **CPP's macros.** Headers included through `-optP` (20 cabal files) are not read, so 3.7% for macros in code is a
  lower bound. Both arms of an `#if` are counted, a union.
- **The tiers** in the covers and ceilings are E6's, not calibrated. O asked for two rows to be rechecked: DeriveGeneric
  (T6, 830 packages) and DeriveDataTypeable (T5, 729).

### E8. Oracles and a corpus for 2010

**Question.** Can rhc's 2010 mode be judged by something other than GHC's own reading of 2010, which departs from the
Report and comes with modern base? Which other compilers reach 2010? What 2010 programs exist once untrusted code is
filtered out, and what would a run tier cost? **Settles:** D38, D39, D40, D41; the content of M2.

**How.** Agent G (the plan named O), in two sessions: 2026-11-17 07:24 to 08:28, and, after the account limit stopped
it, 2026-11-21 19:41 to 20:22 (`README.md`, *Order of events*). Files are in `results/E8/`; the oracles are in
`oracles/` beside `results/`.
- **The filter runs first** (`scripts/scan2010.py`). A candidate any of whose modules enables TemplateHaskell, its
  quotes or QuasiQuotes, uses CPP (a pragma, `-cpp`, or any `#` directive line), uses `capi`, or names a preprocessor,
  plugin or option file in OPTIONS, goes to no compiler (`filtered.tsv`). ANN pragmas are blanked in every compiled
  copy, since GHC evaluates an annotation.
- **g10:** GHC 9.4.7 with `-XHaskell2010 -XRebindableSyntax -XImplicitPrelude -hide-all-packages`, over the package
  `haskell2010-report` and the defaulting plugin `h2010-default` (`oracles/ghc2010/`, `oracles/README.md`). The package
  is the Prelude and the 30 modules, with export lists checked against T10's chapters 13-42
  (`report-signatures.json`); the numeric classes' code is the Report's, as rhc's 98 Prelude has it. The plugin
  applies 4.3.4's rule to the shim's classes, which GHC's own defaulting cannot see.
- **gbase:** GHC 9.4.7 `-XHaskell2010` over base and 14 common packages: GHC's reading of the language with modern
  libraries. g10 against gbase tells the language from the library.
- **The others:** MicroHs 0.16.12 (f17be7f) for acceptance only; Hugs (September 2006) in `+98`; nhc98 1.22, compile
  only (its library links in part). jhc was not built: its configure wants zlib, utf8-string, HsSyck, random, old-time
  and regex-compat, which are not installed (`jhc-prereqs.tsv`), and G had no network. `gext` (GHC2021, every package,
  pragmas kept) feeds the extension corpus.
- **Seven sets, 3,217 candidates** (`manifest.tsv`): GHC 9.14.1's testsuite files naming Haskell2010 (`ghc-h2010`, 509),
  nofib b7391df (170), MicroHs's tests (243) and its compiler (1), the 98 corpus's 365 extension and 59
  illegal-in-h98 rows (`h98-corpus`, 424), the 98 corpus's 1,441 accept rows (`h98-accept`, g10 and gbase only), and the
  823 closed2010 modules of E7's `plain2010.tsv` as 429 package components (`hackage`, compiled, never run).
- **23 probes** (`limits/`, `limits.tsv`) of what the shim reproduces and what it cannot, run on every oracle.
- **The run tier:** 90 programs built with `ghc -O0` (with g10 if g10 accepted, else gbase), output compared with the
  expected, CPU seconds and `instructions:u` from `perf stat` (`run.tsv`, `runraw/`).
- **Re-asked on 2026-11-21:** the shim was rebuilt twice (the Report's `splitAt`; the C types' constructors exported),
  MicroHs was asked again with `-c` of the 590 candidates whose main module is not Main, and g10 again of the 39 with a
  foreign declaration.

**Result: the shim** (`limits.tsv`). g10's column records 14 agreements with the Report, 5 different outputs and 4
refusals. L22 (`realToFrac` of a NaN: g10 prints `-Infinity`, the Report's code gives a number that is not NaN) is
agreement by reading (`oracles/README.md`). So g10 agrees on 15 and departs on 8, in four causes:
- base's Eq, Ord, Show, Read, Enum, Bounded and Ix, because `deriving` names only base's: derived Show parenthesises a
  record argument (L04), and `read "0x10" :: Int` parses (L05);
- base's Ratio, because GHC types a fractional literal at base's Rational: Ord of `Ratio a` for a type variable `a` is
  refused (L01);
- RebindableSyntax, which reads literals, negation, `do` and `if` through the names in scope: a program that defines
  `ifThenElse` or redefines `>>=` or `negate` is misjudged (L02, L03, L23);
- GHC's own departures in bugs.rst: prefix `!` read as a bang (L06), duplicate array indices unchecked (L15).

A ninth limit has no probe: since 2026-11-21 the C types and IntPtr and WordPtr are exported with their constructors
(GHC marshals a newtype only with its constructor in scope), so a program that writes `CInt 3` is wrongly accepted.
G's report counts 15 without saying that one is by reading, and names "six stated limits", the README's six items;
W8 recounted the raw file as above. gbase's column records 12 agreements; with L22, gbase agrees on 13 and departs on
10. 9.4.7 accepts `forall` as a term variable (L07); it refuses it as a type variable (E6's `forall.hs`), and 9.14.1
reserves it always.

**The sets** (`summary.txt`; "plain" names no extension beyond 2010).

| Set | Candidates | Filtered | Judged | g10 accepts | gbase accepts | Plain | g10 accepts of plain |
|---|---:|---:|---:|---:|---:|---:|---:|
| ghc-h2010 | 509 | 31 | 478 | 72 | 108 | 96 | 33 |
| nofib-2025 | 170 | 64 | 106 | 50 | 71 | 84 | 49 |
| mhs-tests | 243 | 4 | 239 | 28 | 46 | 236 | 28 |
| mhs-src | 1 | 0 | 1 | 0 | 0 | 0 | |
| h98-corpus | 424 | 9 | 415 | 1 | 9 | 51 | 1 |
| h98-accept | 1,441 | 57 | 1,384 | 890 | 932 | 1,317 | 860 |
| hackage | 429 | 2 | 427 | 358 | 401 | 424 | 355 |

- **GHC's testsuite.** Only 96 of the 509 files name nothing beyond 2010; the rest name Haskell2010 beside extensions.
  Of the 96, g10 accepts 33 and refuses 63: 57 for the language, 5 for the library, 1 for a missing module. 51 of the
  plain files are expected to fail, and all four of g10, gbase, Hugs and nhc98 refuse 43 of them. `accept.tsv` takes 32
  rows (19 accepted by every oracle), `reject.tsv` 63. Two run tests survive the filter.
- **The 98 corpus's extension and illegal rows.** All 58 judged illegal-in-h98 rows stay refused. Of the 357 judged
  extension rows (G's report says 356; the file has 357), g10 accepts one, rn058, through the FFI; gbase accepts 9.
  Neither Hugs nor nhc98 accepts any of the 415. These rows are an extension corpus, not 2010 tests.
- **The 98 corpus's accept rows** (beyond the brief; bears on D38). Of the 975 rows GHC-strict-98 accepted (the
  `v_ghc` column of h10-base's `tests/hs/corpus/accept.tsv`), g10 accepts 856, refuses 70 and 49 are filtered; 34 rows
  GHC-strict-98 refused are accepted under 2010. Of the 70: 51 import a 98 module name (Char 11, System 10, List 10,
  Array 7, Ratio 4, IO 3, Complex 3, Directory, Random, Ix), 3 System.Random, 6 a name outside the Report (`<$>`,
  `hSetBinaryMode`), and 10 others, which G reads as 3 needing NondecreasingIndentation, 1 n+k, 3 RebindableSyntax
  artefacts and 3 odd cases. rhc's 98 mode already refuses the 3 NondecreasingIndentation programs
  (`tests/hs/rhc-corpus.txt:9-11`, W8), so they need no new pin.
- **Hackage**, 429 components (137,577 lines), compiled only. Of the 427 judged, gbase accepts 401, g10 358, Hugs 324.
  18 refusals are Markdown `README.lhs` files and 8 import modules outside the closed set: harness artefacts. Of the 398
  plain components gbase accepts, g10 accepts 355 (89%); the other 43 fail only on the library: the Applicative names
  13, Semigroup and Monoid 7, Data.Bits beyond 2010 5, Foldable 4, Word, `dropWhileEnd`, the environment functions,
  Monad instances for Either and `(->)` and Ratio's shim limit 2 each, and 4 single names. "Haskell2010" on Hackage is
  2010's language over modern base.
- **nofib** loses 64 of 170 programs to the filter, all for CPP. Of the 84 plain programs g10 accepts 49, every oracle
  34. The library gaps: Control.Concurrent 8, `<$>` 3, Data.IORef 2, and 13 programs need modules neither library has
  (Control.Parallel ...).
- **MicroHs's tests:** g10 accepts 28 of 239, gbase 46; g10 refuses 104 of the 105 expected to fail. MicroHs's compiler
  is not a 2010 program.

**The other oracles.** MicroHs accepts 45 of the 57 plain GHC testsuite files g10 refuses for the language, 24 of 37 in
the 98 corpus's plain rows, 68 of 170 of its own tests. It refuses 3 of g10's 33 acceptances in the testsuite, 1 of 28
of its own tests, and 11 of 49 nofib programs (library gaps). So it judges acceptance only. Hugs refuses pattern guards
(L17) and the FFI probe (L16); nhc98 refuses DoAndIfThenElse (L19) and relaxed dependency analysis (L21); both accept
n+k. Mean seconds a verdict (`raw/*.json`): g10 1.09, gbase 0.59, MicroHs 3.16, nhc98 0.76, Hugs 0.42.

**The filter** kept 167 of the 3,217 candidates from every compiler (5%): CPP 129 (19 of them with `#include`),
TemplateHaskell 30, QuasiQuotes 4 (3 rows name both), `capi` 3, options naming a plugin, `-F` or `-optc` 4. nofib loses
38%, the testsuite 31 (26 of them TemplateHaskell), Hackage 2 of 429. Two files with CPP in literate text were caught
late, after a fix: they had been compiled with CPP off, so no directive of theirs ran, and they are out of every list.

**What the corpora use of 2010's changes** (`deltas.txt`, regex readings [inferred]). Of the 1,279 accept candidates:
pattern guards in 5, foreign declarations in 22 (18 of them Hackage), empty data in 14, DoAndIfThenElse in 46,
hierarchical imports in 284.

**The run tier** (`run.tsv`).

| Set | Programs | Built with g10, gbase | Matched | CPU of the matched |
|---|---:|---:|---:|---:|
| ghc-h2010 | 2 | 1, 1 | 2 | 0.0 s |
| mhs-tests | 39 | 24, 15 | 34 | 0.8 s |
| nofib-2025 | 49 | 41, 8 | 47 | 129.0 s |
| all | 90 | 66, 24 | 83 | 129.8 s |

- 89 built and 83 matched (65 of them built with g10); 2.56e11 instructions. The mismatches: 5 MicroHs tests under gbase
  (threads, Weak, ST, Read), nofib gc/cacheprof under g10 (not examined), and smp/callback001, which did not build.
  The largest is imaginary/x2n1, 19.2 s.
- 51 programs ran under 1 s, 8.84 s together. That overstates what is new (W8). 15 of them (8.0 s) are nofib programs
  in 98's D56's 188 (`tests/hs/corpus/licences.tsv`, `d56=yes`, matched by name), already in the 98 run set; 13 were
  built over base only, and the 11 of those not among the 15 are not 2010 programs (threads, ByteString, Typeable). The
  new run tier is 25 programs (24 MicroHs tests and 1 GHC test, all built with g10), 0.78 s of `ghc -O0`.
- With the 98 roadmap's K (5 for whole programs, 20 for Prelude-bound ones: haskell98.md:4343), the 25 cost rhc 4 to 16
  s a way, and the 51 would have cost 44 to 177 s [inferred].

**The extension corpus** (`extcorpus.tsv`): 1,198 rows, 84 extensions, 528 candidates GHC accepts with their own
pragmas; most often FlexibleInstances 100, MultiParamTypeClasses 90, RankNTypes 87, TypeFamilies 82.

**Not established.**
- **g10 is not the Report.** It departs on 8 probes in four causes, has the ninth limit, and inherits GHC's other
  departures from bugs.rst. GHC 9.4.7 is not 9.14.1, the record of D39.
- **Running Hackage.** Its components were compiled, never run.
- **What the filter kept back.** 129 CPP candidates were judged by nothing: 38% of nofib.
- **nofib gc/cacheprof's** different output under g10 is unexplained.
- **jhc** gave no verdict.
- **The use of 2010's changes** is a regex reading. The breakdown of the 70 refused 98 rows beyond the 51, 3 and 6 is
  G's reading of the messages.
- **rhc's cost** of the run tier comes from the 98 roadmap's K [inferred], not from rhc.

### E9. The libraries

**Question.** For each of the 2010 Report's 30 library modules (chapters 13-42): is it code, prose or both; what does it
export; what carries over from rhc's 98 library; where is the prose too thin to implement from, and what did base do
there; what primitives does it need; which sources could supply its code, under which licences? Then: what is the
Prelude's layout when Data.Char and Numeric have no printed code, and what is shared with `share/rhc/haskell98` or
copied? **Settles:** D20-D26, D33; the size of track L (M12-M14).

**How.** Agent L, on 2026-11-17, reading T10's chapters 13-42 against rhc's 98 library at 75ed95861 and against base
4.2.0.0-4.2.0.2 and 4.3.0.0-4.3.1.0 and the `haskell2010` package 1.0.0.0-1.1.2.0: 10 tarballs fetched from Hackage
into `downloads/libs/` (with `MANIFEST.tsv`), none compiled. Also read: Hugs's packages, jhc's `lib/`, MicroHs's `lib/`.
Files are in `results/E9/`; each script in `scripts/` runs in seconds (`README.md`).
- `exports.py` reads each export list from T10; `code2010.py` takes the four printed modules from the package's `$code`
  chunks and diffs them with 98's pristine; `delta98.py`, `sharing.py`, `newdefs.py` and `sizes.py` measure what carries
  and what is new; `layout.py` draws the module graphs and their SCCs in five cases; `provenance.py` looks for every
  library prose line of T10 with 8 or more words in the package and in each base.
- Two GHC 9.4.7 probes of L's own (`probes/MaybeClash.hs`, `probes/RatioParen.hs`, output in `probes/ghc.out`), and
  one of W2's (`probes/maybeprobe/`).

**Result: kinds and provenance.**
- 26 modules are prose only and 4 prose and code (`modules.tsv`): Data.Array (14.6), Data.Complex (17.4), Data.Maybe
  (21.2), Data.Ratio (22.1). None is code only.
- Of the 1,078 prose lines of 8 or more words (`provenance-summary.txt`): base 4.3.0.0 and 4.3.1.0 have 958 (88.9%),
  base 4.2.0.2 905 (84.0%), the `haskell2010` package 215 (19.9%), one of them at least 1,018 (94.4%). 34 lines are only
  in base 4.3, among them the sentences for `void`, `withFile` and `isSpace` (T10:11189, 16264, 11833). The base of
  record is 4.3 (GHC 7.0), not 4.2 as the plan had it.

**Exports** (`exports.tsv`): 620 items, 686 names. The PDF's text moves the ends of header lines in 15 modules; 37
items were restored by hand from cited T10 lines (L's report says 47; the script's table and the file's column say 37:
W2). Every list then matches the package's, except CLDouble, which the package exports under `#ifdef HASKELL_REPORT`
and T10 does not (T10:14480-14485).

**What carries from 98** (`delta98.tsv`): nine codeless modules continue a 98 module whose code rhc has.

| 2010 module | From 98's | Names carried, of all |
|---|---|---:|
| Control.Monad | Monad | 31 of 40 |
| Data.Char | Char | 23 of 64 |
| Data.Ix | Ix | 5 of 5 |
| Data.List | List | 104 of 111 |
| Numeric | Numeric | 18 of 18 |
| System.Environment | System | 3 of 3 |
| System.Exit | System | 5 of 6 |
| System.IO | IO | 59 of 67 |
| System.IO.Error | IO | 16 of 27 |

- Three names are gone: `bracket` and `bracket_` (98's IO) and `system` (98's System).
- `share/rhc/haskell98` has 22 files and 5,240 lines (`sharing-totals.txt`): 4,760 (90.8%) in modules that continue
  into 2010, 480 in the five 2010 drops (CPUTime, Directory, Locale, Random, Time). rhc's own runtime layer
  (PreludeRuntime, PreludeEnum) is 852 lines. PreludeEnum holds 14 of the Report's lines under the 98 notice, not CC0 as
  `layout.md` labels it (W2).

**Data.Char changes against 98's code** [read]. `isUpper` is now Lu or Lt (T10:11844); `isAlpha` is every letter
(T10:11848); `isSpace` is "any Unicode space character, and the control characters `\t`, `\n`, `\r`, `\f`, `\v`"
(T10:11833), which reaches the Prelude's `words` and `lex` (T10:8422). base 4.3 reads `isSpace` as Zs and those five.
`isAlphaNum`'s prose says letters and digits; base takes marks too. rhc's 98 `isAlpha` is `isUpper c || isLower c`
(`share/rhc/haskell98/Char.hs:42`) but already answers for every letter, so its answers stay and only its definition
changes (W2).

**The printed modules** (`code2010/`). Data.Complex and Data.Ratio are 98's code but for names (99.8% and 99.6% of
tokens in common); Data.Array rewrites `array` and its error texts (96.7%), and its header reads `module Array (`
(T10:11476). Two do not compile as printed:
- Data.Maybe defines and exports `maybe` (T10:13431-13440) beside the Prelude's: GHC says "Ambiguous occurrence
  \`maybe'" (`probes/ghc.out`). E9 offered two fixes. W2's probe shows the first, hiding the Prelude's `maybe` inside
  Data.Maybe, makes every user that imports Data.Maybe and calls `maybe` ambiguous (`probes/maybeprobe/ghc.out`); only
  98's re-export of the Prelude's `maybe` works.
- Data.Ratio's Show instance is one "(" short (T10:13723-13730): "parse error on input \`)'" (`probes/ghc.out`).

L wrote that the package's code tokens "are in T10 in order". `code2010.py`'s output finds only 754 of 795, 908 of 973,
160 of 216 and 638 of 741 in order, because the PDF breaks code columns; against E1's HTML the match is full (W2's
comparison, no result file).

**Thin prose and disagreements** (`modules.md`). Data.Int: "All arithmetic is performed modulo 2^n, where n is the
number of bits in the type" (T10:12381-12382), of a list that names Int, against 6.4's latitude; base 4.3 itself
raises an overflow for ``minBound `quot` (-1)`` (`downloads/libs/src/base-4.3.1.0.x/base-4.3.1.0/GHC/Real.lhs:246-254`).
Allocation failure gives `nullPtr` by the text (T10:15125) and an IOError in base. `fixIO` and the three `ioeGet*`
functions have no prose; Data.Bits gives no default methods; the Unicode version is unstated. D21, D26 and D33 take
these.

**Primitives** [read].
- Bits on Int, a 63-bit Word, Word64 and Int64 need no Rune change: the VM has 63-bit word operations and the
  word64 and int64 families (`src/isa/prims.sml:61-99`, `682-771`). rhc needs new Core types and primitives only.
- Integer's bit operations exist in the VM only through GMP (`runtime/intinf.c:569-576` is fatal without it), so base
  4.3's portable Haskell, with `quot` and `rem`, is the road.
- Data.Char needs the category, which `rtCategory` computes, and one new table for `toTitle`.
- System.IO's additions sit on existing primitives. For `hSetEcho` and `hGetEcho`, `posix_tcgetattr` and
  `posix_tcsetattr` (`src/isa/prims.sml:539-542`) can read the current echo, which `term_enter` and `term_leave`, E9's
  choice, cannot (W2).
- Foreign.C.Error needs the errno of the last foreign call, which E10's G28 keeps; `sys_errno`, E9's choice, is the
  VM's last failed system call (W2). Errno constants need no search: `sys_error_of_name` gives ~1 for an unknown name
  (`src/isa/prims.sml:301-302`), base's -1 convention (W2).

**The layout** (`layout-graphs.txt`). The 2010 Prelude's printed imports (T10:7538-7543, 8422, 8867-8870) already form a
7-module SCC: Prelude, PreludeList, PreludeText, PreludeIO, Data.Char, Numeric, Data.Ratio. 98 as printed has 11, rhc's
98 library 14. Reusing 98's code as it is gives 14 again. Case 5 gives 9: Data.Char and Numeric drop 98's Array tables,
and `interact`'s and `getLine`'s names (BufferMode, `hSetBuffering`, `stdin`, `stdout`, `hGetLine`) move from IO's code
into PreludeRuntime, where they are not today. W2 counts 11 without the move (System.IO and Data.Ix stay in the cycle).
The module-identity rule a library module needs against a user's module of the same name already exists
(`src/rhc/library.sml:39-40, 49`; `tests/hs/names/char/`): only its prefix changes (W2; E9 had it "needed again").

**Size** (`estimate-totals.txt`): about 4,660 lines of Haskell. 953 are carried from rhc's 98 library and 236 printed by
the Report (both measured); 3,467 are new. Of the new, Foreign.* is 2,496 (14 modules; the file says 15: W2), Data.Int,
Data.Word and Data.Bits 740, Foreign.C.Types alone 1,100 if its instances are written out (about 120 if the library may
use newtype deriving). rhc's SML: about 150 to 300 lines across CorePrim, CoreToMid, CoreInterp and CoreLint
[inferred].

**Not established.**
- **The new lines.** Only the 1,189 carried and printed lines are measured. The 3,467 new ones are base 4.3's own
  definitions where they could be counted, else scaled from Hugs's or base's module, else judged (`modules.tsv`,
  `est_basis`) [inferred]. The Hugs calibration counts `packages/base` too: Hugs's Int and Word alone are 268 and 359
  code lines, not 281 and 370 (W2's count).
- **The Prelude's code.** It is in neither the package nor T10's text; E1 took it from the HTML.
- **Compiling.** No library module was written or compiled under rhc; the two probes are GHC's.
- **Licences** were read, not settled. The package's LICENSE is not T10's notice word for word ("The authors intend"
  against "The authors and publisher intend": W2).
- **A 63-bit Int in Storable:** what a peek of a value beyond 63 bits does is open [inferred, untested].

### E10. The FFI on rhc

**Question.** Can rhc implement chapter 8 over Rune's FFI as it is? The four kinds of `ccall` import, IO and pure calls
through rhc's optimiser, callbacks including the hard cases, and the marshallability rule; and, for each FFI
requirement of the Report, what Rune has and what it would take. **Settles:** D27-D33 and every FFI change to Rune;
the content of M15-M17.

**How.** Agent V, on 2026-11-17, in `.worktrees/h10-v` at 75ed95861. The prototype is
`patches/E10-ffi-prototype.patch` (959 lines, md5 e02a449cfc94d04afd562194f06f67b6); its diffstat is 846 lines added
and 4 removed over 8 files. Files are in `results/E10/`; every run is at `RUNE_LINT=2`, so HsLint, CoreLint and MidLint
accepted each program.
- **The prototype.** `parser.sml` (+25) reads `foreign import CONV [safe|unsafe] ["ENT"] v :: t` as the binding
  `v = (primForeign "CONV" "ENT" :: t)`, so the renamer, the checker and HsLint see an ordinary binding. `infer.sml`
  (+73) checks 8.4.2's marshallability at that signature. `desugar.sml` (+326) writes the binding's Core as Core text
  and parses it. `coreprimffi.sml` (218, new) is a family of 17 primitives `ffi_*`, each a Mid function over the VM's
  `foreign` or `foreign_callback`. `share/rhc/haskell98/Foreign.hs` (200, new) is a sliver of Foreign.*: Int8 to Word64,
  Ptr and FunPtr as newtypes of Int, CInt, CSize, CDouble, CString, `malloc`, peek and poke of CInt.
- **The programs** (`progs/`, 20, each saying what it tests). `matrix.sh` runs 11 of them at `-O0`, `-O1`, `-O2` and on
  the stack target, and `exits.sh` runs each again (`matrix.tsv`, 41 runs). `units.sh` compiles a unit at a time and
  measures a call's cost with `runevm --count` at 100,000 and 200,000 iterations (`out/units.log`).
- **The requirements:** one row each in `gaps.tsv` (36 rows, written by `scripts/gaps.py`): the requirement, its T10
  lines, what Rune has, the change, the brief's grade, a size, evidence and decision.

**Result: the four kinds work end to end** [measured]. `Basic.hs` calls the pure `math.h sin` (0.479425538604203) and
`pow`, `abs` through CInt (a newtype of Int32, itself a newtype of Int), `puts` with a CString marshalled by hand, IO
`rand` and `srand`, `qsort` with a `wrapper` comparator ([1,2,3,5,7,8,9]) and an `&qsort` import called through a
`dynamic` stub ([9,8,7,5,3,2,1]).

**The matrix** (`matrix.tsv`): each program prints the same at every level and on the stack target, and every rerun
printed the same again, with two exceptions that are not the FFI's:
- `FreeClash`, which frees Rune's allocation with C's `free` and again with Haskell's, exits 0 at `-O0` and aborts in
  glibc (status 134) at `-O1`, `-O2` and on the stack target;
- `Gaps` on the stack target differs only in the VM's path inside an error message (`out/Gaps.-O1*.stdout`, diffed).

**The optimiser** keeps IO calls and pure laziness. `Opt.hs` observes every call through `puts`. Its stdout is the same
(md5 5c70abe1) at `-O0`, `-O1`, `-O2`, `-O2 --no-cheap-eagerness`, `-O2 --eta=ghc`, `-O2 --strictness=off` and on the
stack target (`out/Opt.*.stdout`).
- IO calls run once each, in order; an action bound once and run twice runs twice; one never run, or only `seq`'d,
  does not run; a discarded result still runs.
- A pure call not demanded is not made; a `let` used twice calls once; a loop of 3 calls 3 times; `c_abs (error ..)`
  never demanded raises nothing. `Strict.hs`: once the call is demanded, the argument's error comes first, at every
  level.
- At `-O2` the simplifier works on this code: 216 declarations become 40, and 7 `prim ffi_call` sites remain
  (`out/Opt.O2.simplify-stats.txt`, `out/Opt.O2.core-simplify-2.txt`). Cheap eagerness cannot make a foreign call
  eager: its whitelist of primitives does not hold the `ffi_*` ones
  (`lib/language/haskell/coresimplify_cheap.sml:50-61`, `:113`) [read].

**Callbacks** [measured unless marked].
- A comparator that forces a suspension already under evaluation (`Loop.hs`) gives `<<loop>>` at every level and on
  the stack target. A callback that makes a nested foreign call with a nested callback (`Nested.hs`) works.
- An ErrorCall raised in a comparator surfaces after `qsort` returns (`Boom.hs`); an IOError raised in a callback is
  caught by `catch` around the call (`Catch.hs`). `Escape.hs` raises from a callback 70 times: "raised to the caller in
  70 of 70 calls", and callbacks work after. Nothing escaped past the C frames, which would have pinned the VM's
  callback depth at its 64-deep limit. The same holds with the wrapper in another unit
  (`out/TwoUnits70.units.*`).
- The trampoline is mandatory [read]. The VM trusts a callback's closure never to raise: `vm_raise` takes
  `vm->handlers[--vm->hp]` (`runtime/runtime.c:268`, `:300`), a handler that belongs to the frames below the callback,
  and `runtime/callback.c:44` checks the handler stack only after a normal return. So rhc's Mid trampoline catches every
  exception, keeps it, and the call raises it after native control returns.
- Callbacks outside a call are refused silently: an `on_exit` handler run after `main`, and a SIGALRM handler, ran no
  Haskell, and the process went on (`Later.hs`). That the alarm fired during the spin is inferred: no time was
  recorded (W4).

**Marshallability.** `Marshal.hs`'s four bad declarations are refused at their lines: an argument of type Box (a data
type), `[Char]`, a result `IO Box`, an argument Integer (`out/Marshal.compile`). The two good ones, a newtype of a
newtype of CInt and `CInt -> IO CInt`, are accepted. Visibility is not checked: `Visible.hs` accepts an import at a
newtype that its module exports abstractly, which 8.4.2 forbids (T10:6905-6911). Interfaces need nothing new: compiled
a unit at a time, `Visible` and `Basic` marshal the other module's newtypes correctly (`out/units.log`).

**The cost of a call** (`out/units.log`, `-O2`, `runevm --count`). Marginal figures, the 200,000-iteration run minus the
100,000 (W4; V's report divides the totals at 100,000 by n, start-up included: 39.5, 186.1, 203.1).

| A loop of | VM instructions | Bytes | Objects |
|---|---:|---:|---:|
| Haskell's own `abs` | 39.4 | 56 | 2 |
| a pure FFI call | 186.0 | 400 | 21 |
| an IO FFI call | 203.0 | 464 | 23 |

A pure call costs 146.6 instructions, 344 bytes and 19 objects more, the native libffi work aside; most of it builds
strings. Wall time on the shared machine: 0.33 to 0.43 s for 100,000 pure calls against 0.025 to 0.039 s for `abs`.

**The 36 requirements, by their raw grades** (`gaps.tsv`). A grade is of the change to Rune; rhc's own work is in the
size column. V's report says "4 small, 3 medium"; the file has 5 small (G17 among them, graded "small (with G16)") and 2
medium (W4).

| Grade | Rows | Which |
|---|---:|---|
| none | 20 | static calls, `&` of a function with a `dynamic` stub over it, `wrapper`, purity and order, the blackhole, nesting, peek and poke at any address, `alloca` and `realloc`, `freeHaskellFunPtr`, stdcall's reading, targets, images and fork, IntN and WordN, safety levels, variadic calls, the marshallability rule, newtypes across modules, the Core interpreter, `nullPtr` |
| none with a workaround | 3 | G09 an exception escaping a callback (the trampoline), G19 C's `malloc` and `free` for rhc's, G28 errno kept by rhc |
| small | 5 | G02 the program's own namespace (`dlopen("")` is glibc-only: `probe/global.out`), G06 reading an `&`-imported C variable, G07 `dynamic` of any FunPtr, G17 a callback's pointer after it returns, G22 StablePtr |
| medium | 2 | G15 a Ptr stored in memory, G16 returned pointers never released (1,000 `getenv` calls, 1,000 live identities) |
| large | 2 | G24 `foreign export`, G25 HsFFI.h |
| large under one option | 4 | G11 callbacks outside a call, G13 Ptr as an address, G14 `ptrToIntPtr`, G21 ForeignPtr's finalizers |

- **Rune's facts behind them** [read, and measured where marked]. A SYMBOL identity is "not foreign memory"
  (`runtime/foreign.c:301-305`), so G06; a call needs a SYMBOL (`runtime/foreign.c:349`), so G07, and a wrapper's FunPtr
  was refused, measured. A pointer C returns, or a callback's pointer argument, has extent SIZE_MAX
  (`runtime/foreign.c:528`, `:693`): `FarPeek.hs` reads 1 GB past `getenv`'s result and dies of SIGSEGV (status 139),
  C's undefined behaviour. Rune's own allocations are bounds-checked. `getenv` twice gives pointers `==` False but the
  same address. Opacity is a design rule (`docs/plans/runeffi.md:465-467`), and no finalizer was a prerequisite of
  Rune's FFI (`runeffi.md:471`).
- **stdcall:** on x86-64 Linux Rune refuses ABI 1 ("calling convention unavailable on this target"), measured.
- **Wide types:** a Word64 result of 2^64-1 overflows the prototype's Int (`Wide.hs`: "Overflow"), which D22 settles.
- **The primitive family** allows only Int, Str and Bool (`lib/language/haskell/coreprimfamily_sig.sml:9-11`); the FFI
  needs Double and a function argument. The prototype breaks the rule; CoreToMid copes, and the Core interpreter cannot.
- **GHC's FFI tests** (`ghc-ffi-tests.txt`): 116 of 121 files have a foreign declaration; 36 have no pragma and no
  GHC-only import, candidates for rhc's suite. None was run.

**Not established.**
- **Any Rune change.** None was built; every size in `gaps.tsv` is an estimate.
- **Other platforms.** Only x86-64 Linux with glibc ran. aarch64, Windows and stdcall's ABI 1 were not run;
  `dlopen("")` beyond glibc is inferred to fail.
- **The Core interpreter.** The prototype raises an IOError under `bin/rhc Main.hs`; it runs compiled only. G35's 250
  lines are inferred.
- **Visibility and HsLint.** The checker has no module scope (about 40 lines to pass it in [inferred]); HsLint has no
  check of its own (about 80 lines [inferred]).
- **Bool, Float, Char and StablePtr.** No test program imports a function over them, and the desugarer's
  `foreignBasic` has no Bool and no StablePtr, though the checker accepts both (W4; the patch's
  `lib/language/haskell/desugar.sml` hunk).
- **`foreign export` and HsFFI.h** were not tried.
- **A stack overflow V saw** in a 20M-iteration loop at `-O1` (fine at `-O2`) was not kept and is not a finding.

### E11. Literature for the decisions

**Question.** What do the Haskell' process, the FFI Addendum, the papers behind the type extensions and the other
implementations say that bears on the decisions? **Settles:** D34, D37, and the precedents of the rest; *What the
literature says* and *What the implementations do* rest on it.

**How.** Agent I, on 2026-11-17, with the network allowed for papers (authors' pages, arXiv, repositories; no
paywall). Files are in `results/E11/`: `literature.md` (577 lines) is the result, `refs.tsv` its 56 sources, `wanted.md`
what could not be read.
- **Fetched:** 29 PDFs into `downloads/papers/` (`MANIFEST.tsv`, text by `pdftotext`); 43 Wayback captures of the
  Haskell' Trac wiki (42 of 40 pages, and the 2003 hierarchical-modules page) and 15 list messages into
  `downloads/haskell-prime/`; GHC proposals 287, 380 and 613 into `downloads/ghc-proposals/`. Reused, not fetched again:
  the 98 campaign's papers, the owner's, and E1's haskell-prime archives.
- **Checked:** every DOI in Crossref (`verify_dois.py`; marlow04's, from memory, was wrong and is corrected); the page
  of every quotation (`pageof.py`, `quotes-pages.txt`; "p. N" is the PDF's page as pdftotext counts it, not the printed
  page); every citation of an implementation's source against the source (`check_impl.py`: "ok 49 bad 0",
  `check_impl.out`).
- **Measured:** chapter 8 against the FFI Addendum, sentence by sentence (`ffi/sentdiff.py`; the Addendum's lines
  155-712 and 1447-1631 of `ffi03.txt` against T10:6663-7459); cpphs's size (`cpphs-wc.txt`).
- **Paths below:** `HP/`, `HPM/` and `ERR/` are `literature.md`'s abbreviations for `downloads/haskell-prime/txt/`,
  `downloads/haskell-prime/mail/txt/` and `downloads/report2010/errata/`; an implementation's path is under
  `/home/ruud/haskell`.

**Result** [read unless marked; `literature.md` has each passage].
1. **The Haskell' committee drew the line the tiers draw.** The April 2009 status page lists as accepted
   MultiParamTypeClasses, ExistentialQuantification, PolymorphicComponents, "RankNTypes or Rank2Types",
   ScopedTypeVariables and KindAnnotations (`HP/Status-20090427.txt:45-83`), and as undecided FunctionalDependencies,
   AssociatedTypes, FlexibleContexts, FlexibleInstances, overlapping and undecidable instances and GADTs (`:145-247`;
   I's range `:145-229` misses FlexibleInstances at `:241`: W1). ImplicitParams was rejected (`:121`). GHC2021 later
   left out fundeps, GADTs and type families too (`downloads/ghc-proposals/0380-ghc2021.rst:23-30` lists its members).
2. **T1-T5 have been built twice without implications** (A+): unification, a deferred store of class constraints solved
   at generalisation, and fundep improvement as more unification, iterated. Jones 2000, section 6.2, p. 12; Hugs in C
   (`Hugs/src/subst.c:1480-1590`); MicroHs (`MicroHs/src/MicroHs/TypeCheck.hs:3716`, `:3738`).
3. **T4 must split.** OutsideIn's section 2.3 (p. 8): with `MkR :: C a => a -> R a` and `instance C a => B a [a]`,
   `k (MkR x) = op x` has two incomparable types. That given constrains a universal variable; Laeufer's existentials
   constrain only the existential ones (Laeufer 1996, p. 4). So T4a, givens on skolems only, and T4b with T6
   [inferred].
4. **Improvement from a given cannot be elaborated to System F** (Karachalias and Schrijvers 2017, p. 2); GHC refuses
   such a program. Improvement from wanteds needs no evidence, so T2 is sound under System F if given-improvement is
   refused [inferred].
5. **The fundep conditions decide termination.** With 98's instance rules or Paterson's conditions, the FD-Conditions
   give sound, complete and decidable inference (Sulzmann et al. 2007, corollaries 1 and 2, pp. 20-22). mtl needs the
   relaxed Terminating Weak Coverage Condition (definition 14, p. 30); Hugs uses a depth limit.
6. **Rank N elaborates to plain System F under GHC 9's simplified subsumption** (proposal 287:14-25). On Stackage, 399
   of 457 compilable higher-rank packages needed no change (the Quick Look paper, p. 30). PVWS 2007's coercions come
   from deep skolemisation and its prenex conversion (W1 sharpened I's "only deep skolemisation"). MicroHs still deep
   skolemises (`TypeCheck.hs:2863`, `:3283`).
7. **Chapter 12's names are GHC's because of a review.** Ian Lynagh asked whether anything supported the Haskell' names
   and whether RelaxedDependencyAnalysis should be RelaxedPolyRec (`ERR/haskell-prime-2010-May.txt:449-453`). Six of the
   ten Haskell' names are not GHC's; DoAndIfThenElse is (W1; I's report says seven).
8. **Chapter 8 is the Addendum with four language changes** [measured: `ffi/ch8.summary.txt`]: 202 sentences the same,
   25 changed, 18 only in the Addendum, 39 only in 2010. The changes: a newtype's constructor must be visible
   (T10:6903-6911); newtypes of result types are allowed; "generally" left "strict in all arguments"; multithreading is
   implementation-defined.
9. **Finalizers are C functions, run before exit** (T10:14955, 14966-14967; the Addendum, p. 20, printed p. 14).
   I's minimal Rune change, a registry of C finalizers, is superseded by E10: an exit hook in rhc and library code, no
   Rune change (W1).
10. **Rule (s) of the pattern-guard translation** keeps "where y is a new variable" though y no longer occurs
    (T10:3438-3447, and the HTML); Erwig and Peyton Jones bind the expression once.
11. **GHC cannot judge 98's dependency rule**: "You can't turn off RelaxedPolyRec any more"
    (`ghc/compiler/GHC/Driver/Flags.hs:116-117`). The wiki lists every compiler of 2009 as "full"; nhc98 1.22 in fact
    groups as 98 does, dropping signatures and making every use an edge (`nhc98/src/compiler98/SccModule.hs:60-81`: W1).
12. **Library selection was left open in 2010 too** (Marlow, `HPM/prime-2010-04-003158`).
13. **The implementations** (`impl-citations.tsv`, 49 of 49 matching). Hugs: MPTC, Jones's fundeps, existentials,
    rank 2. UHC: MPTC; fundeps parsed but no improvement found. MicroHs: all four, with no escape check for existentials
    ("XXX must check for leaking skolems", `TypeCheck.hs:2886`). nhc98: existentials only. W1 corrected two claims
    against the trees:
    - MicroHs has `foreign export` (`MicroHs/src/MicroHs/Parse.hs:416`, lowered in `Exp.hs:106-114`,
      `tests/ForExp.hs`), `dynamic` and `wrapper`, and an HsFFI.h with 8.7's six functions
      (`src/runtime/HsFFI.h:69-75`). E11 had taken MicroHs's 2024 paper's word that it leaves `foreign export` out.
    - jhc refuses MultiParamTypeClasses (`jhc/src/FrontEnd/KindInfer.hs:428-430`, fatal by `Warning.hs:155`), where
      E11 had it knowing the fundep name only for warnings.

    The Hugs tree is the September 2006 release (`Hugs/src/version.c:42`), not May 2006 (W1).
14. **For D12:** cpphs is 1,100 lines of Haskell, 1,318 with its parser library (`cpphs-wc.txt`) [measured].

**Not established.**
- **No implementation was built or run.** Every claim about Hugs, UHC, jhc, MicroHs and nhc98 is from source and
  documentation; E8 ran some of them as oracles, not on type extensions.
- **Unread:** Laeufer and Odersky 1994 (substitutes read) and Jones's *Qualified Types* book; `wanted.md` lists 8
  items for the owner. Duck et al. 2004's text cannot be extracted (Type 3 fonts); the journal version was read.
- **Parts of papers.** Several were read only in the sections that bear on a decision (`refs.tsv`, how much was read).
- **The census's paper keys** (E6) were not checked here.

### E12. Where the Haskell 98 type system ends

**Question.** Where, in rhc, does the Haskell 98 type system end? Built one tier at a time on D34's A+ (today's unifier
plus a deferred store of class constraints solved at generalisation, with improvement as iterated unification), in the
checker and in HsLint: what does each of T1, T2, T4 and T5 cost, does 98 mode keep its bytes, is each prototype
conservative, and how much of GHC's testsuite for the feature does it pass? **Settles:** D34, D35, D36, D37; the sizes
of M22, M23, M25 and M26 (T3's M24 was not built) and E6's size column.

**How.** Agent N, in wave 2, in `.worktrees/h10-n` at 75ed95861 (its brief: `agents/briefs.md`, *N*). N read first X2's
census notes (the one-type predicate in the checker, parser, HsIface, the desugarer's `dictArg` and HsLint; instances by
class and type constructor; no rigid variables in HsLint's second inference) and E11's parts on D34 and D37. E4's
language record was not ready, so each prototype sits behind a plain global switch, which is enough for throwaway
work. One throwaway prototype per tier, in the checker and in HsLint (both its inference and its replay where they
apply), as patches `patches/E12-<tier>.patch`, results in `results/E12/`:
1. **T1:** MultiParamTypeClasses with FlexibleInstances and FlexibleContexts: predicates over several types, the
   instance index and instance identity, deferral in place of immediate refusal, non-HNF inferred contexts,
   dictionaries in Core, HsIface. Programs: a two-parameter class with instances, a Collection-style class, flexible
   heads.
2. **T2:** FunctionalDependencies on T1, with improvement from wanteds only. A program that needs improvement from a
   given (Karachalias and Schrijvers' example) is refused with a clear message. N says which coverage condition it
   implements (Jones's, or the terminating weak coverage mtl needs) and runs an mtl-style MonadState class.
3. **T4:** existentials with contexts on the existential variables only (T4a): type binders in Core's `AltCon` and
   `Data` (`lib/language/haskell/core_sig.sml:77`, `:87`), dictionaries bound by a pattern, the escape check. A context
   on a universal variable (T4b, with T6) is refused, and OutsideIn's MkR example with it.
4. **T5:** the RankNTypes core: bidirectional checking with simplified subsumption (no deep skolemisation), annotations
   required, elaborated to System F with no coercions.

For each tier: lines by area (checker, HsLint, Core, parser, interfaces); whether 98 mode stays byte-identical
(`tests/hs/lang` and the corpus run set compiled in 98 mode before and after, by a script in `results/E12/`);
conservativity (the prototype switched on over the 98 lang suite and E8's 2010 accept list, output byte-identical); GHC
testsuite programs for the feature (`typecheck/should_compile` and `should_fail`, TemplateHaskell, QuasiQuotes and CPP
files filtered out) and how many pass; an estimate of the same tier on D34's option C (constraint generation with a
solver); and what the measured sizes do to E6's size column. The brief allowed no commit, every build through the
campaign's `scripts/build.sh`, and tests at `-j 3`.

**Result: A+ was enough for all four tiers, in the checker and in HsLint** [measured]. No constraint solver and no
implication constraints were needed. Each tier sits behind the environment variable `RHC_E12` (`T1`, `T2`, `T4`, `T5`,
and `UI` for UndecidableInstances), over rhc's 98 library; E4's record was not used. The patches are a series:
`patches/E12-T1.patch`, `E12-T2.patch`, `E12-T4.patch` and `E12-T5.patch`, with `E12-cumulative.patch` all four
(`scripts/check-series.sh` rebuilds h10-n's tree from 75ed95861 with them).
- **E12's own programs.** The 9 accepted programs (`programs/t1`, `t2`, `t4`, `t5`) print GHC 9.4.7's output under
  their tier and under all tiers, on the interpreter and at `-O0`, `-O1` and `-O2`, all at `RUNE_LINT=2`
  (`programs-rhc/summary.txt` against `programs-ghc/ghc.tsv`). The exception is T5's `rank2.hs` at `-O0` and `-O1`
  (Mid, below). The 19 refusal programs are refused under their tier and under all tiers (`programs-rhc/results.tsv`).
- **T1** (MultiParamTypeClasses, FlexibleInstances, FlexibleContexts).
  - A class of n parameters keeps `pred = {cls, ty}` and holds its arguments as a pseudo-tuple `#n t1 .. tn`, so every
    one-parameter path keeps its bytes.
  - A flexible instance is found by one-way matching, beside the (class, type constructor) index that 98-shaped
    instances keep; an instance's identity is its flattened head.
  - A wanted with unsolved variables that no instance matches is deferred; at the pin `solve` refuses it at once
    (`lib/language/haskell/infer.sml:317`). So non-HNF contexts are inferred as GHC infers them
    (`hasOne :: Collection c Int => c -> Bool`).
  - Instance contexts must meet the Paterson conditions, which `UI` lifts, under a depth bound of 200. Overlapping
    heads are refused.
  - Dictionaries become data types of n parameters, and HsIface gains an option field per class and per instance.
    HsLint takes the same encoding, defers in its `toHnf`, and replays and target-checks the new records.
- **T2** (FunctionalDependencies, on T1).
  - Improvement unifies the determined arguments, from instances, from the givens' superclass closure and between
    wanteds; solve and improve repeat until nothing changes. HsLint has its own copy (Jones 2000, section 6.2).
  - Ambiguity is judged modulo the dependencies, and a variable they determine is not generalised (sections 6.3 and
    6.4). Coverage is Jones's by default, the liberal form under `UI`.
  - Karachalias and Schrijvers' program (`programs/t2-fail/given-improvement.hs`) is refused as improvement from a
    given, "an equality System F cannot express", as GHC 9.4.7 refuses it.
  - The mtl-style MonadState program (`programs/t2/mtl.hs`, State and a ReaderT lift) gives GHC's output, with `UI`
    on, which it needs for coverage only. Its instances meet the Paterson conditions [inferred, N]. Liberal coverage
    with the Paterson conditions kept does not terminate in general (GHC's `Mul`: W13, D35), so D35 recommends
    Terminating Weak Coverage with the Paterson conditions, which admits mtl.hs; that mode was not built.
- **T4a** (ExistentialQuantification, givens on existential variables only).
  - A constructor's context must constrain its existential variables. OutsideIn's MkR (`programs/t4-fail/mkr.hs`) is
    refused as a context on a universal variable, T6's; GHC 9.4.7 accepts it with a non-principal type.
  - In a pattern the existentials become skolems one level deeper and the context becomes givens. At the end of the
    scope (case alternatives, clauses, lambdas) a predicate left on a skolem is an error; escape is caught by the
    checker's existing watch. Pattern bindings of existentials and deriving are refused.
  - Core gains `AltConEx`; a Data constructor's existentials are, by convention, its fields' free type variables
    beyond the type's parameters. CoreToMid erases a hidden type to Mid's `unit`, with `unsafe_cast` at construction.
  - HsLint has skolem constants and its own scope rule.
- **T5** (the RankNTypes core). `HsTypes.ty` gains `TForall`. An argument whose parameter is a polytype is checked
  against it with its variables rigid, and desugared to type and dictionary lambdas: System F, no coercions. Only
  simplified subsumption; annotations required; binding a variable to a polytype is refused as impredicative. HsLint
  has its own `TForall` and the same rules.

**Sizes** (`areas.tsv`: lines added / added code lines; T2 is on T1, T4 and T5 independent of both in meaning).

| Tier | Checker | HsLint | Core | Desugar | Parser, front end | Interfaces | Switch | Total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| T1 | 466 / 394 | 479 / 428 | 0 | 92 / 84 | 28 / 25 | 18 / 18 | 18 / 15 | 1,101 / 964 |
| T2 | 318 / 285 | 155 / 126 | 0 | 1 / 1 | 21 / 20 | 12 / 12 | 5 / 2 | 512 / 446 |
| T4 | 176 / 150 | 134 / 119 | 148 / 133 | 85 / 65 | 43 / 38 | 0 | 0 | 586 / 505 |
| T5 | 193 / 161 | 203 / 184 | 0 | 23 / 19 | 22 / 21 | 9 / 9 | 0 | 450 / 394 |
| all four | 1,136 / 974 | 962 / 848 | 148 / 133 | 200 / 168 | 113 / 103 | 35 / 35 | 23 / 17 | 2,617 / 2,278 |

- The cumulative patch touches 46 files; the tiers remove 154, 33, 73 and 19 lines.
- HsLint's code lines against the checker's: 428 to 394 at T1, 126 to 285 at T2, 119 to 150 at T4, 184 to 161 at T5.
  N's report calls T2's "a little less"; it is under half.
- The lines are a lower bound. The pseudo-tuple stands in for `pred = {cls, tys}`, which would touch about 68
  predicate sites in the checker and 61 `IsIn` sites in HsLint (N's grep; the size inferred). T2's dependencies sit in a
  side table, not a field of `DClass`. HsLint's extras are side maps its codec does not write. The new paths have no
  fault injection, and the prototypes no tests or docs.

**98 mode, switch off** [measured].
- `tests/hs/lang`: 591 of 591 bytecode files are the baseline's, with no stdout or stderr difference, at T1's state and
  at the final build with every tier's code (`identity/t1off-lang.tsv`, `identity/t5off-lang.tsv`).
- `tests/hs/errors`: 633 of 633 have the baseline's status and whole stderr (`identity/t1off-errors/errors98.tsv`,
  `identity/t5off-errors/errors98.tsv`).
- 98's D56's corpus run set, at T1's state: 193 of 193 jobs pass, and 354 of 354 bytecode files are the baseline's
  (`identity/t1off-corpus.tsv`).
- GHC's 133 selected files, final build: the baseline's status and first error line in every one
  (`ghc/run-*-finaloff.tsv` against `ghc/run-*-off98.tsv`).
- The baseline is h10-n's `bin/` before any edit (`rhc.rbc` sha256 ff2c9aa316ea..., h10-base's). Interfaces change: an
  option byte per class and per instance, which moves store bytes and `--dump-iface`, not bytecode.

**Switch on, over 98 programs** [measured].
- **T1 on:** `tests/hs/lang` 591 of 591 identical (`identity/t1on-lang.tsv`); the corpus 354 of 354
  (`identity/t1on-corpus.tsv`); `tests/hs/errors` 38 of 633 differ, 26 now accepted and 12 refused with another message
  (`identity/t1on-errors/errors98.tsv`). Each accepted one is a 98 restriction T1 lifts: flexible heads, classes of
  several parameters, non-HNF or constant contexts, and `dec.ctx.noinstance`, now a deferred context.
- **Every tier on** (`RHC_E12=T1,T2,T4,T5`), final build: `tests/hs/lang` 591 of 591 identical, no text difference
  (`identity/allon-lang.tsv`); `tests/hs/errors` 40 differ, 27 accepted and 13 refused with another message
  (`identity/allon-errors/errors98.tsv`). They are T1's 38 and two more:
  - `cls.inst.ctx.vars`: an instance context with a variable its head lacks, refused before as "not a parameter of its
    declaration"; T2 allows such variables, and the Paterson conditions now refuse it;
  - `ty.quant.noforall`: accepted, because T5 makes `forall` a keyword in types. This is D36's point: reserve `forall`
    only under ExplicitForAll.

**GHC 9.14.1's testsuite** (`ghc/summary.tsv`, `ghc/categories.tsv`). `typecheck/should_compile` and `should_fail`,
selected by `scripts/ghc-select.py`: the tier's and T0 extensions only, no CPP, TemplateHaskell or QuasiQuotes, one
file, imports of rhc's library only; each run `--typecheck-only` at `RUNE_LINT=2`.

| Tier | Files | should_compile accepted | should_fail refused | of those, for another reason |
|---|---:|---:|---:|---:|
| T1 | 29 | 7 of 10 | 19 of 19 | 2 |
| T2 | 48 | 27 of 32 | 16 of 16 | 0 |
| T4 | 8 | 0 of 2 | 6 of 6 | 1 |
| T5 | 48 | 11 of 31 | 16 of 17 | 7 |

- **The baseline** accepts none of the 75 should_compile files and refuses the same should_fail files (`refused_98`
  equals `refused` in every tier). So the should_fail column shows the tiers refuse no less than 98 mode does, not that
  they refuse for the right reason; 10 refusals are for another reason.
- **The failures** (`categories.tsv`):
  - T1, 3: all need overlap (OVERLAPPABLE, OVERLAPPING), T1's next group.
  - T2, 5: 3 need 2010's EmptyDataDecls, 1 overlap, and GivenOverlapping meets rhc's R20 reading: 98 mode refuses an
    unsigned `main = return ()` too, since Rule 2 defaults before main's IO type is known.
  - T4, 2: T10856, a constructor context on a universal variable, refused by design as T6's; update-existential, whose
    NoImplicitPrelude is not read and whose existential record fields the prototype lacks.
  - T5, 20 of 31: 10 need a forall in a result skolemised against the clause's further patterns (GHC 9 keeps that), 3
    a context inside a nested type without `forall`, 2 a polytype through a type synonym (LiberalTypeSynonyms), 2 a
    pattern on a polytype, 1 T4's syntax, 1 an unsigned rank-2 binding, 1 Traversable, which rhc's library lacks. The
    should_fail it accepts, T18455, is a SPECIALISE instance pragma rhc does not read; 98 mode accepts it too.
- **All tiers on.** T1, T2 and T4 give the same verdicts as alone (`ghc/run-*-allon.tsv` against `run-*-on.tsv`). T5
  does not, against N's report: `should_fail/tcfail196.hs` (`bar :: Num (forall a. a) => Int -> Int`) is accepted with
  every tier on (`ghc/run-T5-allon.tsv`), since FlexibleContexts lets the context's shape through and T5 does not refuse
  a polytype as a class argument. All on, T5 refuses 15 of 17. Under T5 alone that file is refused by 98's
  context-shape rule ("a class assertion on a type that is neither a type variable nor one applied"), not for syntax
  as `categories.tsv` has it.

**Core and Mid** [measured].
- CoreLint accepted every program: System F Core was enough for all four tiers. T1, T2 and T5 changed nothing in Core
  (`Core.TForall` exists already); T4 added `AltConEx` and the existential convention, 133 code lines in 13 Core files.
- Mid is T5's limit. MidLint takes a polymorphic type only as a tuple component or a field
  (`lib/compiler/core/midlint.sml:213`, `:222`), so `programs/t5/rank2.hs` fails at `-O0` and `-O1`: "lint after mid:
  internal compiler error: the type of v4357 is polymorphic, ... other than as a field" (`programs-rhc/summary.txt`).
  It runs at `-O2` only because the simplifier removes the polymorphic binder. T5 needs CoreToMid to box a value of
  polytype in a one-field datatype, as dictionaries are, or rank N in Mid: 200 to 400 lines [inferred, N].
- T4 needed no Mid change.

**Separate compilation** (`units/log.txt`). A two-module program with a two-parameter class and an existential
(`units/Conv.hs`, `units/Main.hs`) runs as a whole program, on the interpreter and at `-O1`, and on a store's first
compile. Once `Conv` is taken from the store it fails: at `RUNE_LINT=2` with an uncaught Subscript, at `RUNE_LINT=1`
with "HsDsCore: Conv.Box at 1 types". N reads these as HsLint's codec missing T1's class extras and the desugarer's unit
data missing the existential constructor's information: 50 to 150 lines [inferred].

**Option C** [inferred, N's estimate]. Constraint generation with a worklist solver would replace what A+ extends:
`byInstance`, `solve` and defaulting (`lib/language/haskell/infer.sml:296-467`) and `implicitGroup` (`:1336-1480`), and
change `explicitExp` and `checkAgainst` (`:1109`, `:1490`).
- Building that and regaining 98's bytes (the same evidence, defaulting, MR behaviour and messages): perhaps 1,500 to
  3,000 checker lines before any tier.
- Then, checker only: T1 about 300 lines against 394, T2 about 250 against 285, T4 250 to 350 against 150 (implications
  for an alternative's givens, more general than needed), T5 about the same.
- So C costs 1,500 to 3,000 lines first and then saves next to nothing: N's per-tier figures for C sum to 961-1,061
  checker lines against A+'s 990 (W13); it pays only at T6. HsLint costs the
  same under either: it is independent.

**E6's size column** [inferred from the measured lines]. N puts a production version at 1.5 to 2 times the prototype
(tests, docs, overlap, full error wording, the codec), though N's own estimates below are 1.5 to 2.6 times for T1, T2
and T4a and 3.3 to 5.6 times for RankNTypes.

| Census rows | E6's size | Prototype | Production, estimated | Suggested |
|---|---|---:|---:|---|
| MultiParamTypeClasses, FlexibleInstances, FlexibleContexts, UndecidableInstances | L, L, M, M | 1,101 for the group | 1,600 to 2,400 | L for the group: one refactor, not four rows to sum |
| FunctionalDependencies | L | 512 | 800 to 1,200 | M, upper |
| ExistentialQuantification | L | 586 | 1,000 to 1,500 | L, lower |
| RankNTypes | XL | 450, passing 11 of 31 | 1,500 to 2,500 | L under simplified subsumption; XL only with DeepSubsumption or ImpredicativeTypes |

**Not established.**
- **The corpus at the final build.** The chain's last steps, 98's D56's corpus run set on the final build (switch off
  and every tier on) and the refusal programs under T2, T4 and T5 alone, were stopped early at the lead's request, on a
  mistaken check (`logs/chain-t5.log`: "killed ... 2026-11-21T21:48:29"). So the corpus's byte identity, off and on,
  rests on T1's state; the final build was compared on `tests/hs/lang`, `tests/hs/errors` and GHC's 133 files only.
- **2010 programs.** E8's accept list was not used for conservativity: N found 32 rows when it looked, and
  `results/E8/accept.tsv` now has 1,279, of which 32 are the GHC testsuite's. Conservativity rests on 98 programs.
- **HsLint's refusals on their own.** N reports that HsLint's inference refuses the 19 programs too; no result file
  separates its refusals from the checker's.
- **Separate compilation** of a program that uses the tiers fails (above): only whole programs were shown to work.
- **What was not built:** T3 (ScopedTypeVariables, TypeApplications), T4b, overlap, the T8 policy, and the coverage
  mode that keeps the Paterson conditions. mtl itself was not compiled, only an mtl-style program.
- **The estimates.** Production sizes and option C are N's judgements; the shortcuts above make the measured lines a
  lower bound.

## Constraints

**From the brief:**
- rhc supports both editions, chosen by `--language=haskell98|haskell2010`; the default becomes 2010 when the roadmap
  is complete (D3 says when).
- **98 mode stays Haskell 98** as its Report reads. A choice the 98 Report left ambiguous or underspecified may follow
  2010, read as a clarification, only where this roadmap says so explicitly for the owner's review (*Haskell 98 mode
  and the 2010 text*; D13).
- **The 2010 Report is the authority.** GHC is a reference, used with care: it departs from the Report in its 2010
  mode as in its 98 mode (*What the implementations do*). rhc follows the 2010 text to the extent it follows 98's:
  a departure only on the 98 roadmap's D38 grounds (wrong, contradictory, ambiguous, conceded by the Report), named
  and pinned by a test. What the text leaves open is a choice, recorded as one.
- **The 2010 library lives in `share/rhc/haskell2010`,** distinct from `share/rhc/haskell98`, and `--language` selects
  it (D1, D25).
- **Extensions:** as many as possible without OutsideIn(X), without the highly GHC-specific, and without extensive
  runtime support; each classified and recommended (*The extensions*).
- **A design for tracking language settings** that need not match the pragmas one to one (*Tracking language
  settings*).

**From the 98 roadmap's standing rules, which carry over:**
- **No silent changes to Rune.** Each change to Mid, Low, a bytecode, the VM, the collector or Rune's FFI is a
  decision graded large, medium, small or none (*Every change to Rune*).
- rhc is written in Standard ML and built by Rune alone (98's D42); its front end lives in `lib/language/haskell` and
  its driver in `src/rhc`; rhc is second class in tools and first class in conformance.
- No SML below Haskell (98's D26 A): Haskell code reaches the runtime through Core primitives, never through an SML
  library such as `RuneForeign`. This is what puts the FFI's marshalling in Haskell over Core primitives (D33).
- HsLint, rhc's independent checker, runs at lint level 2 on everything the checker accepts, so every feature that
  changes typing is specified twice (D41).

**From the owner's rules, recorded in Rune's memory of earlier campaigns:**
- Designs for code the compiler runs are chosen by speed and correctness on Rune at tier 2; other hosts are
  informational (2026-10-21).
- Highly generic functionality goes into a library of its own under `lib/` (2026-10-10).
- No mechanism with a single user (2026-11-03).
- Code may be vendored with a `LICENSE` beside it, or, if it has none, a `PROVENANCE` (2026-11-10). `base` 4.3 is
  BSD-3 (D24).

**The standing gate.** After any change, 98 mode's output, its budgets and SML's bytes stay put unless a decision says
otherwise and by how much. E3 and E4 held 98 mode byte-identical under their prototypes (`results/E3/identity/`:
591 programs at `-O1` and `-O2`, 354 bytecode files of the run set, 633 error outputs, 3,812 views;
`results/E4/bytes6-*.log`: 1,182 bytecode files, 633 errors, 251 accepts; 98's snapshot entry for entry,
`results/E4/snapshot-98-compare.txt`, build 6 matching it but for the snapshot's own Main, which differs by its path),
so a milestone that moves a 98 byte has a defect or a decision behind it. Those checks met no LANGUAGE pragma (the test
directories have none and the run-set harness blanks them: W10), so M3 adds the 11 vendored files that carry pragmas,
compiled unblanked under D6's 98 rule. Each extension that changes no valid program leaves the 2010 corpus's bytes
unchanged when it is turned on (D36).

**From the tree.** This roadmap was written against `haskell98` at `75ed95861`, and its citations stay there. The
other session merged 24 commits after it (*Where we are*), 8134f92fe among them, the other session's build-cache
work, which changes nine files of `src/rhc` (+402 -124); E4's patch rejects 12 of its 121 hunks on that tip
(`results/E4/other-session.md`). Each milestone is written on the tree of its day, and a citation of a later tree says
so.

## The architecture

**One record of language settings per module, read by every stage; one library per program; the 2010 changes as
features of that record, and every extension a feature too.** Everything below Core is unchanged by the 2010 language
itself; the FFI and the fixed-width numbers add Core primitives over operations the VM already has, and the FFI asks
three small changes of Rune (G02, G06, G07) and, for `Ptr`, D29's large one.

```text
.hs, .lhs                       literate, Unicode; CPP if asked (D12)
   |
Header pre-scan     LANGUAGE / OPTIONS_GHC -X after unlit (D6)   -> each module's setting
   |                command line: --language, -X; rhc's own options (D8)
Resolution          edition as base, ordered steps, implications (D4, D5); errors (D7)
   |  Language      per module: canonical feature set; per cycle: agreed settings (D10)
Lexer, layout       2010: hierarchical names, `foreign` reserved                       D17, D18
Parser              pattern guards, DoAndIfThenElse, empty data, FFI declarations       D14, D15, D17, D27
   |  AST           printers print header pragmas (D6)
Names, fixity       10.6's algorithm (already rhc's); dotted modules                     D18
Kinds, types        relaxed groups (2010); defaulting per edition; tiers T0-T5 (X)      D16, D20, D34
Classes             A+: a deferred class store, improvement by unification (X)           D34
   |                                    HsLint: the same features, specified again       D41
Desugaring          pattern guards by 3.17.3; FFI imports as Core primitives             D14, D32
   |  Core          System F; AltCon binders for T4a; a whole-dictionary Cast for GND    D37
Core to Mid         Word, Word64, Int64 and FFI primitives over the VM's own              D22, D27
   |  Mid, bytecode unchanged by 2010 itself; Rune's FFI: G02, G06, G07 (small), D29's Ptr
Library             share/rhc/<edition>, a descriptor per edition; one snapshot layer     D1, D23-D26
```

### Ownership

| Layer | Where | Who changes it |
|---|---|---|
| Header pre-scan, the language record, resolution | `lib/language/haskell` (E4's `language.sml`) | this roadmap, freely |
| Lexer through Core to Mid | `lib/language/haskell` | this roadmap, freely; 98's paths byte-identical |
| rhc's driver, store keys, the library descriptor | `src/rhc` | this roadmap, freely, on the tree of the day |
| The 2010 Report's code and rhc's code for the codeless modules | `share/rhc/haskell2010`, with its `LICENSE` and provenance records | Report text plus a listed overlay (D23, D24) |
| The 98 library | `share/rhc/haskell98` | untouched (D25), but for D13a's one signature if the owner takes it (M18) |
| Mid, Low, bytecode, VM, collector, Rune's FFI | `lib/compiler`, `src/isa`, `runtime`, `lib/basis/rune_foreign*` | decisions only |

### The contracts

**The language record** is the contract between the driver and the stages: a stage asks the record of the module (or
binding, or group) it is working on, never a global. E4 replaced the per-run `standard` and `cycle` refs and HsLint's
hard-coded `cycleDefault = false` with lookups and kept 98's bytes (`results/E4/README.md`, `permodule/`). Compile
modes (`--strings`, `--match`, `--eta`, `-O`) stay outside it (D8).

**The unit key** carries each member's canonical feature set, so a setting that changes how a text is read can never
let one reading's unit serve another: the hole `--dotted-names` had at the pin (*Found while writing*) cannot recur
for any feature (D9).

**The library descriptor** is the one place a library's directory, unit-id prefix, role modules (Prelude, Ix, Ratio,
PreludeBuiltin), hidden modules, leaves and module list are named; E4 removed every hard-coded `haskell98` from code
through it.

**Core primitives** remain the only door from Haskell to the runtime. The FFI is a family of them over the VM's
`foreign` and `foreign_callback` (E10), with a trampoline that keeps a callback's exception and raises it after the
native call returns (D31).

### What stays possible

- **OutsideIn(X).** The A+ checker (D34) defers class constraints to a store solved at generalisation; OutsideIn's
  implication constraints extend that store rather than replace the unifier (E11). The boundary is T4b, T6 and T7
  (D37), and Core's step to System FC is the next roadmap's.
- **GHC2021 and GHC2024.** Not accepted as editions here (they need T5, T7 and T6: GHC2021 through DeriveGeneric,
  GHC2024 through GADTs too), but every part of them below OutsideIn can be asked for by name, and the resolution
  machinery accepts an edition as a base (D5).
- **Concurrency.** Single-threaded: `safe` and `unsafe` calls are alike, callbacks stay on the owning thread, and
  InterruptibleFFI waits for threads (the concurrent-runtime roadmap, being written from the owner's
  untracked brief `docs/plans/concurrent-runtime/` in the main tree).
- **Template Haskell and quasi-quotes.** Later, meta: they run code at compile time (E6), and the corpus filter keeps
  them away from every oracle until then (D40).
- **`foreign export` and an embedding API** (D28), if the owner defers them.
- **Haskell 98 untouched.** 98 mode's features are the empty set in the key, its library is frozen but for D13a, and
  every 2010 feature is off in it unless a module names `Haskell2010` (D2).

## Decisions

Forty-one decisions, D13 split into four, so forty-four in all. Each states its question with the clauses and the code
it turns on; then its options, graded, each with what it costs; the evidence; a recommendation with the strongest
argument against it; and what would reopen it. Nothing here is decided: the owner decides at G0, and the roadmap
then records each decision under its section as 98's did. Every change to Rune is graded on the 98 roadmap's scale:
**large**, optimal for Haskell; **medium**, good for both languages; **small**, Haskell can live with it; **none**, rhc
works around it. An option marked **changes 98 mode** does; one not so marked leaves `--language=haskell98` as it is at
`75ed95861`, held by M3. "The owner's call" marks a decision that needs a judgement rather than evidence: a reading
of a text, a change to 98 mode, a departure from the brief, Rune's model, or a choice its section leaves to the owner.
D34 to D41 are argued in *Decisions* (Extensions, Testing); the table gives them as the lead's rulings have them.

| | Decision | Group | Recommended | Rune | Changes 98 mode | The owner's call |
|---|---|---|---|---|---|---|
| D1 | What `--language` selects | Modes | per program: every module's base edition, the library `share/rhc/<edition>`, its snapshot; one layer for both | none | no | no |
| D2 | Edition pragmas | Modes | accepted: an edition pragma sets its module's rules, the library stays the program's | none | yes: a file naming `Haskell2010` is read as 2010 (no test does) | yes |
| D3 | The default flip | Modes | at G3, on G2 and the 98 harnesses pinned, never on track X; pinned by `RHC_LANGUAGE=haskell98` in `bin/rune-test`'s wrapper | none | no | yes |
| D4 | Representation | Tracking | GHC 9.14.1's 148 names in a closed table onto rhc's features, many to one; one canonical set; the edition for messages only | none | no | no |
| D5 | Resolution | Tracking | GHC's measured order: edition a base, ordered steps, eager implications, pragmas after the command line; GHC2021 and GHC2024 not accepted | none | no | no |
| D6 | Header pragmas | Tracking | a pre-scan of the header after unlit; OPTIONS_GHC's `-X` read; in a 98 module only edition names; the printers print the pragmas | none | yes: `--print` of a file with header pragmas (no test has one) | yes |
| D7 | Unknown, unsupported, combinations | Tracking | unknown and unsupported names errors, at the name; inert names accepted; rhc's own table: C1-C3 refused, an implied unsupported feature failing only its construct (C4); C8 inert | none | no | yes (C8) |
| D8 | rhc's own options | Tracking | `--dotted-names`, `--cycle-default=scc`, `--names=greatest` as rhc features from the command line only; compile modes outside the record | none | yes: `--names=greatest` stops reaching the library (`hs/names/imp/greatest`, 958 pairs to 955) | yes |
| D9 | Keys and interfaces | Tracking | each member's canonical set in its unit key, 98's own set as nothing; the base in the header's mode; the library in the configuration; HsIface gains fields only for track X's content, 98's interfaces unchanged | none | no | no |
| D10 | Per module | Tracking | looked up by module: the checker by a binding's module, HsLint by module and by group; a cycle's own settings by agreement | none | no | no |
| D11 | Diagnostics | Tracking | name the feature and how to turn it on, on a path that already fails; in 2010 modules | none | no | no |
| D12 | CPP | Tracking | a subset in SML, off unless asked, lines kept by blanking; no `__GLASGOW_HASKELL__` | none | no | no |
| D13a | `genericLength` (R48) | 98 alignment | align: `Num i => [b] -> i` | none | yes | yes |
| D13b | `0 ** y` (R45(b)) | 98 alignment | decline; IEEE's `pow` in both modes; the misprint for *Found* | none | no | yes |
| D13c | `isUpper`, `isAlpha` of a caseless letter (R38(a)) | 98 alignment | no: 98 mode keeps chapter 19 | none | no | yes |
| D13d | `isSpace` beyond Latin-1 (R153(a)) | 98 alignment | no: 98 mode keeps the seven Latin-1 characters | none | no | yes |
| D14 | Pattern guards | Front end | qualifiers in the AST; Erwig and Peyton Jones's translation, the fall-through bound once | none | no | no |
| D15 | Empty data | Front end | a `Core.Data` with no constructors; condition 6 in both checkers | none | no | no |
| D16 | Relaxed dependency analysis | Front end | 2010 only, in both checkers; (i) the edge to a signed variable of a pattern binding cut too | none | no | yes |
| D17 | Small syntax | Front end | n+k off; DoAndIfThenElse in every block; `:` needs nothing | none | no | no |
| D18 | Hierarchical names | Front end | on in 2010 for program and library; `--dotted-names` kept for 98 | none | no | no |
| D19 | Chapter 12's pragmas | Front end | INLINE, NOINLINE, SPECIALIZE ignored, as in 98 | none | no | no |
| D20 | Defaulting's standard classes | Front end | from the library descriptor's prefix | none | no | no |
| D21 | `Int` under 2010 | Numbers | wraps in 2010 only, over the word primitives (B1); wrapping `int` primitives (B2) if measured | none (B1); small (B2) | no | yes |
| D22 | IntN, WordN, Bits | Numbers | Core types over the VM's `word`, `word64`, `int64` | none | no | no |
| D23 | The library's layout | Libraries | the printed modules literal; the cycle 9 | none | no | yes |
| D24 | Sources and licences | Libraries | 98's code, the Report's code, `base` 4.3's portable branches; `base` 4.3 where the prose is thin | none | no | no |
| D25 | Shared or copied | Libraries | a copy | none | no | no |
| D26 | Unicode | Libraries | one category primitive, the predicates in Haskell; `isSpace` Zs and five controls; 18.0.0 | none | no | no |
| D27 | Conventions, kinds of import | FFI | all four kinds through a Core primitive family; Rune's G02, G06, G07; stdcall refused where there is no ABI 1 | small | no | yes |
| D28 | `foreign export`, HsFFI.h | FFI | not in this roadmap: a declared gap at G2 | none | no | yes |
| D29 | `Ptr` | FFI | raw addresses for rhc's Core through a trusted primitive family | large | no | yes |
| D30 | Finalizers, StablePtr | FFI | finalizers at `finalizeForeignPtr` and at exit; StablePtr a table in Haskell | none | no | no |
| D31 | Callbacks | FFI | Rune's contract and rhc's trampoline; a callback outside a call refused, a reading of 8.4.3 | none | no | yes |
| D32 | The FFI in Core | FFI | the prototype's lowering with an AST form; Foreign.C.Types exports its constructors | none | no | yes |
| D33 | Foreign.\* | FFI | in Haskell over new Core primitives; compiled only | none | no | yes |
| D34 | The checker | Extensions | A+: today's unifier with a deferred store of class constraints; no improvement from givens | none | no | no |
| D35 | The recommended set | Extensions | the census's 72 `now` names, by tier and package weight, co-occurring groups together; fundeps under the Paterson conditions and Terminating Weak Coverage | none | no | yes: the fundep regime |
| D36 | Meaning-changing extensions | Extensions | only when asked, each with its conservativity test | none | no | no |
| D37 | Core's target | Extensions | System F through T5; binders in `AltCon`; a whole-dictionary Cast; T5 boxed in CoreToMid; FC with OutsideIn | none (boxing); large (rank-N in Mid) | no | yes: T4b stays T6's; boxing or rank-N in Mid |
| D38 | The 2010 table | Testing | E1's 5,259 rows beside 98's, tests shared by clause id; 98's unabsorbed errata where the text is the same | none | no | yes |
| D39 | Oracle policy | Testing | GHC 9.14.1's source the record; 9.4.7 with E8's shim; MicroHs for acceptance only | none | no | no |
| D40 | Corpus and filter | Testing | E8's filter as built; Hackage compile-only | none | no | no |
| D41 | Budget, HsLint parity | Testing | rows shared by clause id in `make check`, the rest nightly; HsLint budgeted at the checker's cost per type feature | none | no | no |

### Modes

### D1. What `--language` selects

**Question.** What do `--language=haskell98` and `--language=haskell2010` choose, and over what? The brief: "rhc needs
to support both haskell98 and haskell2010 with a --language=haskell98 or --language=haskell2010", and "--language=
also selects the right prelude". A LANGUAGE pragma is per module and a library per program, since two Preludes cannot
meet in one program (*What the brief gets wrong*, W2). At the pin rhc has one library, whose name `haskell98` is both
its directory under `--share` and the prefix of its modules' identities (`src/rhc/library.sml:44`), and one snapshot,
`bin/rhc.layer`, made at `make` time from the modules of `RHC_LIBRARY_MODULES` (`Makefile:822-829`). Rune: none under
every option. 98 mode is unchanged under every option: `haskell98` selects today's library and rules.

- **A. None: per program, three things.** **Recommended.** The base edition every module of the program starts
  from (*Tracking language settings*, *How they resolve*); the library's descriptor, `share/rhc/<edition>`, which
  holds the library's names, its own language, its hidden modules, its leaves and the module list the snapshot's
  `Main` imports (`rhc --library-modules`); and that library's configurations in the snapshot. As E4 prototyped it:
  `RhcLibrary.haskell98` and `.haskell2010`, chosen by `--language` (`patches/E4-language-record.patch`,
  `src/rhc/library.sml` and `src/rhc/main.sml`). Within A:
  - **(i) One layer for every language.** **Recommended.** The Makefile's rule makes each language's library into
    `bin/rhc.layer`, each in configurations of its own: 82,954,000 bytes for both, against 41,334,255 for 98's alone,
    in 43.2 s wall, 26.4 s user and 5.1 s system for four `RUNE_LINT=2` compiles and the prune (`results/E4/cost.md`;
    the times from `logs/build6-layer.log`, the layer's size from build 5's `logs/build-layer.log:20`, 98's alone from
    A's report, reproduced in `results/verify/V2/numbers-c/snapshot-sizes.txt`) [measured]. About 41.6 MB and two
    compiles per language.
  - **(ii) A layer per language,** `bin/rhc.layer.haskell2010` beside 98's: an install takes only the language it
    wants, and `bin/rhc` must pick a layer by the flag, a second place that knows the language [inferred].
- **B. None: per module, the library included.** Impossible: a 98 module and a 2010 module in one program would each
  want a Prelude, and the program would hold two `Prelude`s, two `Int`s, two `Show` classes. Rejected.
- **C. None: an edition in the store's configuration only,** one library for both. Against the brief's
  `share/rhc/haskell2010` "to keep it distinct", and the libraries differ (*The libraries*). Rejected.

**The evidence.**
- *GHC.* An edition selects no library: under `{-# LANGUAGE Haskell98 #-}`, `import Monad` is "Could not find module
  'Monad'" (E5, probe P17e), and GHC 9.14.1 vendors no `haskell98` or `haskell2010` package (E5, `semantics.md`
  section 3).
- *The committee left it open.* Marlow, editing the Report in April 2010, found that a `haskell2010` package beside
  `base` makes imports ambiguous; Wallace answered "The committee's decision is clear enough. The question is to do
  with implementation issues that are not specified by the Report" (E11; *What the literature says*, *Modes and
  tracking*).
- *What A replaces.* The 15 code lines that name `haskell98` and the role modules named in code (*Where we are*, *How
  a setting reaches each stage*) go through the descriptor; with it, 98's snapshot keeps all 68 entries, keys and
  bytes (`results/E4/snapshot-98-compare.txt`) and the library's unsigned bindings infer the same 20 types, with the
  same 3 defaultings, under 2010's features as under 98's (`results/E4/libtypes/`) [measured].

**Recommendation.** A with (i). **The strongest argument against:** every install carries both libraries' units, 41.6 MB
it may never read, and every `make` of `bin/rhc` compiles both; (ii) costs a second place that knows the language, and
the snapshot is read only from the configurations a compile asks for, so (i)'s cost is disk and build time alone.

**What would reopen it.** An install size that matters, which brings in (ii); a third edition (GHC2021), which adds a
library or decides that an edition may share one.

### D2. Edition pragmas

**Question.** What does `{-# LANGUAGE Haskell98 #-}` or `{-# LANGUAGE Haskell2010 #-}` in a module do, when the
library is the program's (D1)? Chapter 12: "Haskell 2010 implementations that support the LANGUAGE pragma are required
to support {-# LANGUAGE Haskell2010 #-}" (T10:10993-10995). At the pin rhc ignores every pragma
(`lib/language/haskell/lexer.sml:112`; *Where we are*, *Pragmas*). Rune: none under every option.

- **A. None: refuse an edition pragma that differs from `--language`.** A program is then one edition throughout. In a
  98 program a file naming Haskell2010 fails, which 98 mode does not do today: **changes 98 mode**; in a 2010 program
  every corpus file naming Haskell98 fails, tcfail144 among them (E3, `results/E3/r21/r21.tsv`).
- **B. None: accept; an edition pragma sets its module's rules, the library stays the program's.** **Recommended.**
  GHC's model (E5, P03d: a pragma's edition beats the command line's). **Changes 98 mode,** narrowly: a file of a 98
  program that names `Haskell2010` is read under 2010's rules, where today the pragma is ignored. No test file of
  tests/hs has a LANGUAGE pragma outside the corpus and the oracles' shim, and the corpus harness blanks the corpus's
  (`tests/runner/hscorpus.sml:195`), so no 98 test or run-set program changes [read].
- **C. None: ignore edition pragmas,** as rhc does today. Against T10:10993-10995 in 2010 mode, and a 2010 program
  could not hold the corpus's 98 files under 98's rules.

**The evidence.**
- *Prototyped.* A 98 `Main` using n+k imports a module headed `{-# LANGUAGE Haskell2010 #-}` that needs 4.5.1, and
  the program runs by units and whole, printing `(True,True,120)` (`results/E4/permodule/results3.txt`, `mixed/`); E3's
  `programs/pragma3.hs`, headed `{-# LANGUAGE Haskell98 #-}`, refuses its pattern guard whatever the command line says
  (`results/E3/run-programs3/results.tsv`) [measured].
- *What a 98 module meets in a 2010 program.* The Prelude's code is 98's: 915 of its 927 lines are the same, 9 differ
  in tabs and 3 rename an import (E1; *What the 2010 Report says*, *The Prelude's code*). What it cannot find is 98's
  other modules, `List`, `Monad` and the rest, an error as in GHC (P17e). Per program, not per module, are `Int`'s
  arithmetic (D21), the standard classes of defaulting (D20) and the library's text, so two of 98's code errata that
  2010's text lacks, `enumFrom`'s `seq` and `lex`'s `_`, follow the library (D38, N18).
- *The literature.* Allbery proposed that 2010 code say `{-# LANGUAGE Haskell2010 #-}` "to distinguish from Haskell
  '98 code (no LANGUAGE pragmas)"; the Report took only the requirement to support the pragma (E11; *What the
  literature says*).

**Recommendation.** B. **The strongest argument against:** a module can then ask for rules its program's library was
not written for, and a 98 module in a 2010 program gets 2010's library under 98's rules, a combination neither Report
describes; A is simpler to state. But A refuses programs GHC compiles, and B is the one reading under which chapter
12's required pragma means something in a 98 program.

**What would reopen it.** The owner keeping 98 mode deaf to every pragma, which is A for 98 programs and B for 2010
ones; a library that cannot serve the other edition's modules.

### D3. The default flip

**Question.** When does rhc's default become haskell2010, and how do 98's harnesses stay on 98? The brief: "default
to 2010 after the roadmap is complete". At the pin nothing names a language: every test, harness and document runs
`bin/rhc` bare. Rune: none under every option. 98 mode is unchanged under every option; what changes is what a bare
command line means.

*When:*
- **A. At G3, which rests on G2 and every 98 harness pinned to 98.** **Recommended.** G2 is the 2010 Report's exit
  (every clause Supported or pinned, oracles and corpus green, HsLint at level 2, the FFI on the platforms D27 names).
  Track X never gates it.
- **B. After the whole roadmap, track X included,** the brief's letter. The flip would wait on 72 extensions (D35)
  that no 2010 program needs.

*How the harnesses stay on 98:*
- **(i) An `RHC_LANGUAGE` default.** **Recommended.** rhc reads `RHC_LANGUAGE` as it reads `RHC_STORE`
  (`src/rhc/storeconfig.sml:43-51`, the `getEnv` at `:49`), and `bin/rune-test`'s wrapper sets it to `haskell98` beside
  `RHC_STORE=` (`Makefile:2240`); the 2010 tiers pass `--language=haskell2010`. About 6 lines: one in the wrapper, about
  5 in rhc (`results/E4/cost.md`) [inferred]. In rhc the flip is then two defaults, E4's `RhcSyntax.edition` and
  `RhcLibrary.current` (`patches/E4-language-record.patch`).
- **(ii) `--language=haskell98` at each site:** about 60 call sites in 19 files, the 52 invocation lines of 17 runner
  files and the 9 helper definitions, besides 14 Makefile lines (`results/E4/flip-inventory.tsv`), the corpus
  harnesses through `HsRhcCorpus.rhc ()` (`cost.md`) [inferred]; and every new test must remember it.
- **(iii) No pin: re-pin the tests to 2010.** 98 mode would lose its tests. Rejected.

**The evidence.**
- *What the flip touches* (`results/E4/flip-inventory.tsv`, `flip_inventory.py` over h10-base) [measured]: 52 lines in
  17 runner files that build or run an rhc command, through 9 helper definitions (`val rhc = "bin/rhc"` in hscore,
  hsdesugar, hsinterp; `fun rhc ()` in hsiface, hssnapshot, hssimplifyfigures; `HsRhcCorpus.rhc ()`, which
  `RUNE_HS_RHC` overrides; hslang's `rhcFlags`; hsunits' `rhc` and `rhcIn`), the runner rows in 22 files in all, 74 of
  them prose; 14 Makefile lines that run rhc and 5 comments; 77 lines of documents that name an rhc command,
  `docs/rhc.md` the most; 8 in tests/hs's READMEs and drivers. A helper's callers are counted once: hscore uses its
  `rhc` 9 times, hssimplifyfigures 5, hsdesugar 4, hsiface, hssnapshot and hsrhccorpus 2 each.
- *The literature.* The committee expected compilers to keep earlier revisions behind a flag, "We expect that GHC will
  support a number of previous revisions to the language, with a flag such as -language-revision=2010"; nothing ties
  a flip to extensions (E11; *What the literature says*, *Modes and tracking*).
- *An environment default is visible.* The base setting is part of the header's mode and of every key (D9), so a
  default from the environment cannot mix two languages in one store; and rhc's messages name the edition (D11)
  [inferred].

**Recommendation.** A and (i). **The strongest argument against:** a user's shell that sets `RHC_LANGUAGE` compiles
another language than the bare command line says, which (ii) cannot do; and the brief asked for the flip "after the
roadmap is complete", which A reads as after its exit for the Report. (ii) costs about ten times the lines, in every
test written later.

**What would reopen it.** The owner reading "complete" as including track X, which is B; a harness that runs rhc
outside `bin/rune-test` and so outside the wrapper.

### Tracking

### D4. Representation

**Question.** How does rhc hold a module's language settings, given pragma names that need not map one to one onto
what rhc tests? At the pin each setting is a ref or an argument of its own, and nothing reads a pragma (*Where we are*,
*How a setting reaches each stage*). Rune: none under every option. 98 mode is unchanged under every option.

- **A. None: GHC's names at the surface, rhc's features inside.** **Recommended.** A closed table of GHC 9.14.1's 148
  LANGUAGE names and their No forms, each a row giving its class (D7), the features it sets, its implications and its
  deprecation; the resolved set held canonically, sorted and with no edition; the edition kept beside it for
  messages; the steps kept only while resolving (*Tracking language settings*, *The representation*). Names may map
  many to one, one to many, or to nothing, and rhc may have features no GHC name has (D8). E4 prototyped the record,
  `HsLanguage`, with nine features (226 lines with the library's names).
- **B. None: rhc's own names,** a switch per tier or Hugs's single `-98`. The files of the corpora name GHC's (E3,
  E7), so B needs GHC's table as well, to translate. Rejected.
- **C. None: GHC's names one to one, each its own feature.** No merging: Rank2Types and RankNTypes two features with
  one meaning, each tested at every site, and the inert names features that nothing tests. More to key and to test
  for nothing [inferred].
- **D. None: as A, and the Haskell' proposal's own names too:** RelaxedDependencyAnalysis, EmptyDataDeclarations,
  FixityResolution, LineCommentSyntax, HierarchicalModules and LanguagePragma, which were in the accepted delta and
  which no compiler implemented (E11). Only on the owner's word.

**The evidence.**
- *The names.* 148: 135 constructors, 3 alternate and 3 deprecated names, 4 editions, 3 Safe Haskell modes; every
  extension name has a No form, editions and Safe modes none; 288 strings in a LANGUAGE pragma on x86_64 Linux (E5,
  `results/E5/names.tsv`, `semantics.md` section 1). GHC 9.4.7 knows 137 of the 148 (E5).
- *What the files write.* Of 195 distinct names in the headers of the GHC testsuite, nofib and the corpus, 17 are
  none of GHC's, misspellings and other compilers' names (`results/E3/pragmas/names.tsv` against E5's table)
  [measured].
- *Precedents.* jhc maps GHC's names many to one onto its own flags (`jhc/src/Options/Map.hs:56-74`); Cabal and
  haskell-src-exts hold closed tables with Enable, Disable and Unknown (E5, `others.md`; *What the implementations do*).
- *One name, one semantics.* "although GHC and Hugs use the same syntax, the meaning of type variables is quite
  different" (E11, of ScopedTypeVariables), so rhc's names mean GHC 9.14.1's, and a merge is allowed only where the
  meanings coincide in rhc: jhc's `FO.Forall` gives ScopedTypeVariables' scoping to ExplicitForAll [inferred].
- *The Report's own names are GHC's.* Chapter 12's five, PatternGuards, NoNPlusKPatterns, RelaxedPolyRec,
  EmptyDataDecls and ForeignFunctionInterface (T10:10998-10999), are GHC's spellings (E11, finding 7).

**Recommendation.** A. **The strongest argument against:** a table of GHC's names ties rhc to GHC's vocabulary, and
each GHC release adds names that rhc must then classify; B would let rhc name what it implements. But the files name
GHC's, chapter 12 requires an error on an unknown one, and a name rhc has not classified is simply unknown until it is.

**What would reopen it.** A file in a corpus that names a Haskell' proposal name (D); a GHC release that changes a
name's meaning, which a table pinned to 9.14.1 does not follow.

### D5. Resolution

**Question.** In what order do the edition, the command line and the pragmas apply, and what do implications, No
forms and deprecated names do? The 2010 Report says only that repeating a supported feature is "specifically
permitted" (T10:10991-10993). Rune: none under every option. 98 mode is unchanged under every option: a 98 module
reads no names from its header (D6), and nothing in 98's tests passes `-X`.

- **A. None: GHC's measured semantics.** **Recommended.** The edition a base, the last edition named winning; ordered
  On and Off steps replayed over it; an implication a step at the point its implier is turned on, recursively; a No
  undoing nothing it implied; the header's pragmas after the command line, in text order; a deprecation warned only
  where the name is written (E5, `semantics.md` sections 0-8; *Tracking language settings*, *How they resolve*, which
  lists where rhc departs and why). GHC2021 and GHC2024 are known names rhc does not support in this roadmap.
- **B. None: haskell-src-exts's.** The last word on a name wins, and implications are closed over the final set, so a
  No of an implied name never wins (`haskell-src-exts/src/Language/Haskell/Exts/Extension.hs:722-725`, `:744`; E5,
  `others.md`). Files tested against GHC then mean something else where they turn an implied feature off, as
  `-XGADTs -XNoMonoLocalBinds` does (P04c).
- **C. None: jhc's.** An edition erases every earlier flag (`jhc/src/Options/Map.hs:73-77`). A command line's `-X`
  before a pragma's edition is lost, where GHC keeps it (P03a).
- **D. None: no implications,** as Cabal resolves none itself. `-XGADTs` would not give MonoLocalBinds, and every
  implier would need its implied names written.

*Within A, the editions GHC2021 and GHC2024:* **(i) not accepted in this roadmap,** **recommended**: GHC2021 needs
rank-N types and kinds, and both need T6 (GHC2021 through DeriveGeneric's type family, GHC2024 through GADTs as
well) (E6, X2, W12), so each is "not supported by rhc" (D7), and their parts
below OutsideIn can each be asked for by name; **(ii) accepted as far as rhc supports them,** silently dropping the
rest, which chapter 12 forbids (T10:10989-10990). Under (i), GHC2021's own gap, TypeOperators without the
ExplicitNamespaces it implies (P05a), does not arise.

**The evidence.**
- *GHC's semantics, read and measured.* 137 probes on GHC 9.4.7, 129 as predicted from 9.14.1's source; the 8 misses
  are one deprecation newer than 9.4.7 (P08i), one Safe Haskell warning under the default edition (P16e) and six
  census probes about single extensions, none about the order of resolution (`results/E5/probes/results.tsv`). The
  code: `flattenExtensionFlags` (`ghc/compiler/GHC/Driver/DynFlags.hs:757-761`), `lang_set` (`:1127-1132`),
  `setExtensionFlag'` (`ghc/compiler/GHC/Driver/Session.hs:2979-2996`), the header after the command line
  (`ghc/compiler/GHC/Driver/Pipeline/Execute.hs:658-667`), 38 implications (`ghc/compiler/GHC/Driver/Flags.hs:286-359`).
- *Prototyped.* E4's record resolves editions and ordered steps with an empty table of implications; its cases agree
  with GHC's order: `-XNoNPlusKPatterns` refuses n+k in 98 and `-XNPlusKPatterns` restores it in 2010, and a command
  line's step sits under a module's pragmas (`results/E4/permodule/results3.txt`) [measured].
- *The model against GHC* (E13, `results/E13/model.py`, `predictions.tsv`, `showlang.tsv`, `agreement.md`) [measured]:
  A's rules as data, over GHC 9.4.7's editions, 35 implications and flag names and 9.14.1's 148 names, reproduce all
  19 of E5's `:show language` captures and 132 of the 137 probes' outcomes, all 116 of P01-P17. The 5 misses (P18a,
  P18f, P18o, P18i, P18j) are GHC departing from the Report outside resolution, `forall` and a prefix `!` read the same
  in every mode and OverloadedStrings' defaulting, with the model's set equal to GHC's in each. So the prototype's empty
  `implied` takes GHC's implication table as data, the negative implications included. rhc's design answers 60 of the
  probes as GHC does and 77 otherwise, each for a stated reason (its default edition 45, GHC2021 or GHC2024 9, Safe 8,
  a name rhc does not support 24, CPP 7, an OPTIONS_GHC flag 1, GHC's old `-f` spellings 5; a probe may have several).
- *Only GHC has implications as ordered steps;* haskell-src-exts closes them at the end, the others have none (E5,
  `others.md`). Files are written and tested against GHC.

**Recommendation.** A with (i). **The strongest argument against:** GHC's rules let a user build a set GHC itself calls
inconsistent, a feature on without one it implies (`-XRankNTypes -XNoExplicitForAll`, P07d), and rhc copies that
latitude; B is simpler and has no such sets. A matches what every file was tested against, E13's model shows GHC's
resolution is all data, and D7's table accepts such a set as GHC does (C5), its message at the construct naming both
steps.

**What would reopen it.** A probe of order on which the model and GHC part; the owner asking for GHC2021 as an
edition, which needs T5, T6 and T7 first.

### D6. Header pragmas

**Question.** Where may a pragma that sets the language sit, how is it read, and what do OPTIONS_GHC, literate files,
a Haskell 98 module and the printers do with it? 12.3: "A file-header pragma must precede the module keyword in a
source file. There can be as many file-header pragmas as you please, and they can be preceded or followed by
comments." (T10:10981-10983). At the pin a pragma is trivia, read by nothing, and the lexer's options are fixed before
a file is lexed (`lib/language/haskell/lexer.sml:109-124`; `parser.sml:1601-1606`). Rune: none under every option.

*Where and how:*
- **A. None: a pre-scan of the header,** before the lexer runs, on the text after unlit. **Recommended.** The header is
  pragmas, white space and comments up to the first other token, a first `#!` line allowed in 2010 mode as GHC allows
  it (`ghc/compiler/GHC/Parser/Lexer.x:318`; P10d); the pragma's keyword in any case, as GHC's `clean_pragma`
  lowercases it (`Lexer.x:3520-3521`; P09j), the names case-sensitive conids between commas (P09h: `Cpp` is not
  `CPP`); several pragmas, one over several lines, comments between (P10f). A LANGUAGE pragma after the header is
  ignored with a warning, as GHC's "Misplaced LANGUAGE pragma" (P10a). As spiked: E3's `HsLexer.headerPragmas`, 106
  code lines with its plumbing (`patches/E3-07-pragma.patch`; `results/E3/diffstat.tsv`), and E4's `HsLanguage.pragmas`.
- **B. None: any pragma before `module`,** past code as well, as MicroHs scans for `cpp` ("This is pretty hacky and
  not really correct", E5, `others.md`). A module with no `module` line has no such place. Rejected.

*OPTIONS_GHC and OPTIONS:*
- **(i) Read their `-X` flags and `-cpp` as steps, in text order among the LANGUAGE pragmas; any other flag ignored
  with a warning.** **Recommended.** rhc is not GHC, and its other flags mean nothing to rhc.
- **(ii) Ignore them,** as E3's and E4's prototypes do. A file that asks for a feature there is compiled without it.
- **(iii) Obey every flag rhc has an equivalent for.** A source file would then set rhc's compile modes; GHC refuses
  non-dynamic flags there (P09k). Rejected.

*A Haskell 98 module* (one whose last edition named is Haskell98):
- **(a) Read only the edition names; every other name is dropped unread, with no warning or error.** **Recommended.**
  98's own rule: "the pragma should be ignored if an implementation is not prepared to handle it" (T98:10356-10357),
  and 98 has no LANGUAGE pragma. As E3 spiked it ("only the edition is read", `languageOf` in the patch). The command
  line's `-X` flags still apply.
- **(b) Read every name, strictly, as in 2010.** Eight vendored programs of the run set name DatatypeContexts,
  ConstrainedClassMethods, ExistentialQuantification, GeneralizedNewtypeDeriving, CPP or BangPatterns (grep of
  `tests/hs/corpus/vendored` at the pin), and rhc ignores them today: (b) refuses each original. **Changes 98 mode.**
  E4's prototype does this: it refuses an unknown name in a 98 module (E13, `results/E13/combo/results.txt`,
  `Unknown98.lhs`) [measured], and would refuse the eight [inferred from its code; the harness blanks the pragmas, so
  its corpus run did not meet them].
- **(c) Read every name, accepting what rhc supports.** A 98 file naming BangPatterns would change meaning once
  BangPatterns lands (`f !x` reads as a bang, D36). **Changes 98 mode.**

*The printers:*
- **(1) `--print` and `--print-layout` print the header's LANGUAGE and OPTIONS pragmas as written, in both modes.**
  **Recommended.** **Changes 98 mode:** the printed form of a 98 file with header pragmas gains them. No test file of
  tests/hs outside the corpus has one, and the round trip's token test reads no trivia
  (`tests/runner/hsroundtrip.sml:1-31`); eleven vendored corpus files have a LANGUAGE or OPTIONS pragma (grep at the
  pin) [read].
- **(2) Print them in 2010 mode only.** A 98 file naming `Haskell2010` (D2) loses its language in print, as every file
  does today.

**The evidence.**
- *How headers are written* (E3, `results/E3/pragmas/summary.tsv`) [measured]: in the GHC testsuite's 11,227 files and
  the corpus's 3,089, a LANGUAGE pragma in the header in 6,751 and 655; several in 2,278 and 50; one over several lines
  in 282 and 52; a comment first in 220 and 42; the keyword not in capitals in 175 and 1; OPTIONS_GHC or OPTIONS with
  `-X` in 106 and 66; a LANGUAGE pragma after the header in 13 and none. On Stackage, OPTIONS with `-X` or an old `-f`
  in 47 of 49,649 module files (E7, `results/E7/modules.tsv`).
- *GHC's reading* (E5, `semantics.md` section 7): the header reader stops at the first other token
  (`ghc/compiler/GHC/Parser/Header.hs:294-298`); OPTIONS_GHC may carry `-X` and an edition (P11a, P11e); LANGUAGE and
  OPTIONS_GHC in text order (P11c, P11d); a literate file's pragma counts on a code line and not in commentary (P12a,
  P12b).
- *Prototyped.* The pre-scan after unlit: a `.lhs` file's pragma is read and acted on, and refuses n+k at the right
  line (`results/E4/permodule/results3.txt`, `mixed/B.lhs`); bird and LaTeX forms, a lower-case keyword, a pragma
  after `module` ignored (E3, `programs/pragma1.hs` to `pragma6.lhs`) [measured]. E4's build 4 let three malformed
  literate files escape as an uncaught exception, since it unlit them outside the error handler; build 6 reads no
  pragmas from a file that does not unlit (`results/E4/README.md`).
- *98's bytes.* With (a), E3's whole series held tests/hs/lang, the run set, the 633 refusals and 3,812 views
  (`results/E3/identity/`) [measured]; the only change (a) and D2 make to 98 mode is a file naming `Haskell2010`.
- *The printers lose the language.* The explicit and implicit prints emit no trivia
  (`lib/language/haskell/print.sml:129-139`); E3 printed its `pragma1.hs` and 98 mode refused the print (E3's report;
  no result file keeps it).
- *CPP* adds a second read after the preprocessor (D12; *Tracking language settings*, *CPP's place*).

**Recommendation.** A, (i), (a) and (1). **The strongest argument against (a):** a 98 module cannot take an extension
from its own header, only from the command line, and a module headed `{-# LANGUAGE Haskell98, ExistentialQuantification
#-}` is read without the extension and then fails at the construct; GHC would compile it. That is 98's rule for a
pragma it does not handle, and it is what holds 98 mode's output; D11's message names the command line's flag.

**What would reopen it.** The owner wanting extensions in 98 modules by pragma, which is (c) with its own conservativity
tests; a corpus whose OPTIONS_GHC carries flags that change meaning beyond `-X`.

### D7. Unknown and unsupported names, and combinations

**Question.** What does rhc do with a name it does not know, one it knows and does not implement, one that changes
nothing, and features it cannot support together? 12.3: "If a Haskell implementation does not recognize or support a
particular language feature that a source file requests (or cannot support the combination of language features
requested), any attempt to compile or otherwise use that file with that Haskell implementation must fail with an
error." (T10:10989-10990). Rune: none under every option. 98 mode is unchanged under every option: a 98 module's
header names are not read (D6), and nothing in 98's tests passes `-X`.

- **A. None: four classes and rhc's own combination table.** **Recommended.**
  - *Unknown* (not in the table): an error, with the near names, in a pragma at the name's own line and column, and on
    the command line before any file is read.
  - *Not supported* (in the table, not implemented): an error, "not supported by rhc", never a silent acceptance;
    GHC2021, GHC2024 and Safe among them.
  - *Inert:* accepted, setting no feature of its own: ParallelArrays, AutoDeriveTypeable, TypeInType, the No form of
    JavaScriptFFI, ImplicitStagePersistence, and a name whose rule the edition already has, RelaxedPolyRec in 2010.
    Their implications are steps like any other, under the policy C4 below (TypeInType's DataKinds and PolyKinds,
    `ghc/compiler/GHC/Driver/Flags.hs:311-313`, refused where their constructs are written). Trustworthy and Unsafe
    are markers rhc accepts (E6).
  - *Combinations:* rhc's own table, as E13 drafted it (`results/E13/combinations.md`). Refused: **C1** two Safe Haskell
    modes, as GHC; **C2** the modules of one recursive unit differing on a cycle's setting (D8, D10); **C3**
    HierarchicalModules off under a library with hierarchical names, which no name of the design can write (D4, D8) and
    which stands as a guard. **C4**, the policy: a recommended feature that implies one rhc does not support
    (TypeOperators implies ExplicitNamespaces; StandaloneKindSignatures, NoCUSKs) fails no setting; the unsupported
    construct is refused where written, naming both. Accepted as GHC: **C5** a feature with what it implies turned off
    after it (`-XRankNTypes -XNoExplicitForAll`), the construct refused; **C6** GeneralizedNewtypeDeriving with
    DeriveAnyClass, with GHC's warning; **C7** NegativeLiterals with LexicalNegation; **C9** an edition pragma unlike
    the program's library (D2); **C11** foreign declarations under 98's library; **C12** features mixed by module in one
    unit (D10). **C10**, CPP in a literate file, is D12's; **C8**, below, the owner's.
- **B. None: GHC's policy.** Unknown names an error (P09a-P09c), no other class, no combination refused when flags are
  read (`makeDynFlagsConsistent`, `ghc/compiler/GHC/Driver/Session.hs:3592` on, tests none). A name rhc lacks would be
  unknown and a file would learn only that rhc has never heard of it; and 12.3's combinations would go unchecked.
- **C. None: ignore unknown names,** as haskell-src-exts ("We just throw away UnknownExtensions"), jhc in a file and
  MicroHs do (E5, `others.md`). Against 12.3. Rejected.

*Within A, C8: `NoRelaxedPolyRec` in a 2010 module,* which GHC cannot honour, "You can't turn off RelaxedPolyRec any
more" (`Flags.hs:116-117`), and rhc can, having both rules:
- **(i) Inert, with GHC's warning.** **Recommended.** A 2010 module keeps 2010's dependency analysis whatever it says.
- **(ii) 98's 4.5.1 in that module,** as the prototype's resolution gives: E13's `p06` step 2, in a 98 program,
  refuses 4.5.1's example under the pragma (`results/E13/edits.tsv`). It refuses valid 2010 programs on request, a
  meaning-changing switch (D36).

**The evidence.**
- *Prototyped.* An unknown name is refused in a pragma and on the command line, by units and whole: "the language
  `FooBar`, which rhc does not know (a LANGUAGE pragma: 12)" and "no language or extension FooBar that rhc knows"
  (`results/E4/permodule/results3.txt`); E3's spike refuses an unsupported feature in a 2010 module at the pragma,
  `pragma2.hs:1:1` (`results/E3/run-programs3/results.tsv`) [measured]. E4's message in a compile had no place; E13's
  build 8 puts every language error at the name, in compiles, `--whole`, views and through unlit: "Unknown.hs:3:14:
  error: the language `FooBar`, which rhc does not know (a LANGUAGE pragma: 12)", "Unknown98.lhs:3:16"
  (`results/E13/combo/results.txt`) [measured].
- *The inert names* are consulted nowhere in GHC but through their implications (E5, `semantics.md` section 1:
  RelaxedPolyRec, ParallelArrays, TypeInType, AutoDeriveTypeable, JavaScriptFFI; ImplicitStagePersistence is on in every
  edition, source only).
- *Safe Haskell.* GHC's three modes set `safeHaskell`, not the set; two modes are "Incompatible Safe Haskell flags!"
  (`Session.hs:578-585`; P16a), and Safe switches GeneralizedNewtypeDeriving, DerivingVia and TemplateHaskell off with a
  warning (P16c). E6 recommends Trustworthy and Unsafe now as markers and Safe later (`results/E6/census.tsv`).
- *The combination table is new:* no implementation E5 read has one. E13 drafted it over D35's 72 names and rhc's
  own switches; the prototype refuses C3 at the name, "NoHier.hs:3:31: error: NoHierarchicalModules, with a library
  whose module names are hierarchical (haskell2010), which this module could then not import: a combination rhc cannot
  support (12)", and runs the same file under 98's library (`combo/results.txt`), and E4's refuses C2 at the first
  module's header (`results/E4/permodule/results3.txt`) [measured]. C4 keeps the refusals few: refusing the setting
  would refuse every TypeOperators module, which D35 recommends now.
- *E13's model and this list part on two names:* its column `rhc_design` counts TypeInType and AutoDeriveTypeable as
  not supported, by their census rows (`results/E13/predictions.tsv`, P08i, P08l), where A has them inert.

**Recommendation.** A, with C8's (i). **The strongest argument against:** "not supported" and "unknown" differ only in
the message, and the table must classify every name GHC adds; B is GHC's and simpler. But a user told "not supported
by rhc" knows the name was read, and 12.3's combinations need somewhere to live. Against (i): rhc ignores a request it
could honour, where (ii) would give 98's analysis to a module that asks; GHC's warning tells the user so.

**What would reopen it.** A combination rhc cannot support and the table misses, found by a test; GHC dropping a name
rhc's table classifies.

### D8. rhc's own options

**Question.** Which of rhc's options are language, to be folded into the record, and which are modes of the compile?
rhc has three options that change what a program means: `--dotted-names`, which reads dotted module names in 98 mode
(98's D35); `--cycle-default=scc`, one `default` per cycle and Rule 2 at the cycle's end, an extension (98's D30); and
`--names=greatest`, the greatest fixpoint of names, which "reads the text" since chapter 5 is satisfied by either
(98's D29; haskell98.md:7577). At the pin the last two make a compile go whole, the library with it
(`src/rhc/syntax.sml:142-154`), and `--dotted-names` was in neither the unit's key nor its configuration until the other
session's issue 27 (E3, `results/E3/dotted/repro.out`). Rune: none under every option.

- **A. None: the three as rhc's features, set from the command line only; the compile's modes outside the record.**
  **Recommended.** HierarchicalModules for `--dotted-names` (on in 2010's edition, D18), and the two cycle settings,
  each a per-cycle feature whose modules must agree (D10). They have no pragma spelling and no GHC-looking name: in a
  98 module a pragma could not set them anyway (D6). `--strings`, `--match`, `--eta`, `--unfoldings`,
  `--no-cheap-eagerness`, `-O`, `--by-interface`, `--whole` and `--lint` stay modes, in the unit's configuration or the
  link's, as today. The library is read under its own language, so none of the three reaches it, and the two cycle
  settings stop forcing a whole compile. **Changes 98 mode:** `--names=greatest` no longer applies to the library's
  cycle; below, the owner's item.
- **B. None: as A, with pragma spellings under an `Rhc` prefix** (`RhcCycleDefaultScc`, `RhcGreatestNames`) for 2010
  modules. A file using one is an unknown name to GHC, which is honest; the agreement check then has work to do. Only
  if a per-module need appears.
- **C. None: as A for `--dotted-names` and `--cycle-default=scc`; `--names=greatest` stays a program-wide mode that
  goes whole, the library included,** as at the pin. 98 mode keeps its output; the option keeps costing a whole
  compile with no snapshot.
- **D. None: every option in the record, the modes too.** The modes change no meaning, and each would enter every
  member's key for nothing. Rejected.

*The owner's item.* At the pin `--names=greatest` also solves the library's cycle at the greatest fixpoint, which lets
the program's `T1.map` into the exports of the library's `List`: `tests/hs/names/imp/greatest.names` pins "pairs 958",
an ambiguity at `T1:4:9` and "EXPORT haskell98:List vT1 map". With the library immune, the run prints 955 pairs, the
count `least.names` pins, and the test fails with 5 expected lines missing and 1 unexpected
(`results/E4/logs/suites6.log`) [measured]. So under A the library's exports no longer depend on the program, and the
option no longer shows a difference on its own fixture, whose two fixpoints part inside the library's cycle, where
`map` circulates between Prelude and PreludeList (98's D29, haskell98.md:6433). Taking A re-pins that test; C keeps
it.

**The evidence.**
- *Prototyped* (E4's finding 9; `results/E4/permodule/results3.txt`) [measured]: with the three as features, the store
  takes the library's unit from the snapshot under `--cycle-default=scc` and `--names=greatest`, where the pin went
  whole; a cycle whose modules differ on the cycle default is refused, "the modules of a cycle, A, B, differ on
  CycleDefaultScc, which is a cycle's setting", and agrees under the flag, printing `(1,3)`. The prototype spelt them
  `CycleDefaultScc` and `GreatestFixpointNames` and accepted them in a LANGUAGE pragma, GHC-looking names that A drops.
- *98's other outputs held* with the three folded: 210 of the 211 check-tier jobs of rhc's suites pass, the failure the
  item above (`logs/suites6.log`).
- *The modes.* `HsMatch.order` is one ref for the run (`lib/language/haskell/match.sml:10`) and in `extraOf` with the
  strings' form and `--unfoldings` (`src/rhc/driver.sml:172-178`); the rest are the back end's refs
  (`src/rhc/options.sml:12-25`).
- *E13* [measured]: through the command line with the store, `-XRelaxedPolyRec` and `-XNoNPlusKPatterns` take a module
  whose own pragma gave that set already and compile only `Main`, and a third compile as at the first takes every unit
  (`results/E13/edits.tsv`, p09); C2 refuses a cycle that disagrees on a cycle's setting, and C3, the prototype's
  `NoHierarchicalModules` refused at the name, shows why rhc's own features must not become pragma names
  (`combinations.md`).

**Recommendation.** A. **The strongest argument against:** the owner asked for `--names=greatest` as a reading of
chapter 5 for a program, and the Report's library is part of every program; A narrows the option to the program's own
cycles and re-pins its one test. C keeps the option as asked, at the price of a whole compile and a library whose
exports can include a name no library module defines.

**What would reopen it.** The owner keeping `--names=greatest` program-wide, which is C; a need for one of the three in
one module of a 2010 program, which is B.

### D9. Keys and interfaces

**Question.** How does a module's setting reach the store, so that a unit made under one setting is never taken by a
compile under another, while 98's keys and snapshot stay as they are? At the pin a unit's key is its name with each
member's identity and text hash (`src/rhc/driver.sml:231-234`), a header's key its mode, name and hash, the mode
`library`, `dotted` or `program` (`:183-184`; `src/rhc/graph.sml:241`), and the configuration `extraOf`
(`driver.sml:172-178`). E3 reproduced what a missing setting does: a unit made without `--dotted-names` is taken by a
compile with it, which prints `Just 'x'` where `--no-store` refuses the program (`results/E3/dotted/repro.out`). Rune:
none under every option.

- **A. None: each member's canonical set in its unit key; the base setting in the header's mode; the library in the
  configuration; the library read under its own language.** **Recommended.** As E4 prototyped it: Haskell 98's own
  set keys as nothing and the `haskell98` library adds nothing to the configuration, so 98's keys and configurations are
  the pin's; the pragmas are kept in the header's entry, written only where a file has any, so the warm path stays a
  `stat`; HsIface unchanged (*Tracking language settings*, *The store*). HsIface takes a field only for content that
  depends on a feature: with TypeApplications (M24) each scheme's variables keep the order the user wrote, which
  `schemeOf` does not (`lib/language/haskell/infer.sml:578-601`; E6, X2); for the FFI a newtype's constructor
  visibility, which D32 finds a unit's part already holds; and with track X the class parameters and instance heads of
  T1, T2's dependencies and T5's polytypes (E12; W13). E12's T1 encoding writes an option byte for every class and
  instance, which would move 98's store bytes and `--dump-iface` (E12's identity checks compared bytecode and messages,
  not interfaces): the production encoding leaves 98's interfaces byte for byte as they are, or says by how much.
- **B. None: the program's setting in the configuration,** as the other session's issue 27 did for `--dotted-names`
  (E4, `results/E4/other-session.md`). Sound for the command line, not for a module's pragmas: two modules of one
  program with different headers share a configuration. Rejected as the whole answer; it is A's treatment of the
  library.
- **C. None: GHC's way, the edition and the set both in the key** (`ghc/compiler/GHC/Iface/Recomp/Flags.hs:48-50`).
  Two spellings of one set rebuild, and 98's keys would change if the edition entered them [inferred].
- **D. None: one hash of the program's whole setting in every key.** Any flag recompiles every unit, the library's
  included, and the snapshot serves no compile with a flag. Rejected.

**The evidence.**
- *98's snapshot.* Made by the prototype and by `75ed95861` at one `--share` path and one Main path: all 68 entries
  equal, keys and bytes, only rhc's identity differing (`results/E4/snapshot-98-compare.txt`). The Makefile's
  two-language layer of build 6 against the pin's 98 snapshot: the library's 32 entries of each match order equal, the
  snapshot's own `Main` differing by its path (`snapshot-98-compare-b6.txt`), a dependence on paths that the other
  session's issue 9/31 removes (`results/E4/README.md`) [measured].
- *98's bytes* on build 6: tests/hs/lang's 1,182 bytecode files, tests/hs/errors' 633 refusals, tests/hs/accept's 251,
  the check tier's corpus run (198 compiles and 52 refused tries) all identical (`results/E4/bytes6-*.log`) [measured].
  None of these meets a pragma: no file of tests/hs/{lang,errors,accept} has one, and the corpus harness blanks them
  (`tests/runner/hscorpus.sml:195`).
- *The store takes what it should* (`results/E4/permodule/results3.txt`) [measured]: warm, every unit taken; under
  `-XRelaxedPolyRec`, `A` taken, since its own `Haskell2010` pragma gave that set already, and `Main` compiled; under
  `--language=haskell2010`, the library's units from 2010's configurations.
- *The other session's store work* adds ` literate` to a member's identity where E4 adds its set; they compose, and 12
  of E4's 121 hunks are rejected on `haskell98`'s tip, in six files: the driver 4, `hslint.sml` 3, the graph 2,
  `hslint_env.sml`, names and syntax 1 each (`apply-h98tip.log`, `other-session.md`).
- *Under edits* (E13, `results/E13/edits.tsv`, build 9) [measured]: 10 programs, 43 steps of pragmas, editions, `-X`
  and `--language`, the warm compile's bytes or diagnostics equal to `--no-store`'s in 43 of 43; units 47 compiled, 50
  taken, 1 named; an edited module's unit compiled again whenever its text or set changed; entries shared whenever
  both came back; every importer of an edited module taken, an added export included, since a feature changes how a
  module is checked and not its interface. 98's output on build 9: tests/hs/errors 633 of 633, tests/hs/accept 251 of
  251, every tenth tests/hs/lang program 120 of 120 bytecode files (`bytes9-*.log`).

**Recommendation.** A. **The strongest argument against:** a member's key now depends on its setting's canonical
string, so renaming a feature in rhc's table changes every key under that feature, and the soundness of leaving the
edition out rests on an invariant, that every rule an edition changes is a feature. A test of two spellings of one set
holds the invariant, and a renamed feature rebuilds once.

**What would reopen it.** A stage found reading the edition, which breaks the invariant and puts the edition in the
key (C's half); E13's warm bytes differing from `--no-store`'s under an edit.

### D10. Settings per module

**Question.** How does each stage find a module's setting, when one recursive unit may hold modules with different
settings? At the pin the checker is called once per unit and sets the refs `cycle` and `standard` for the call
(`lib/language/haskell/infer.sml:2007-2010`), HsLint's `cycleDefault` is `false` on the units path
(`src/rhc/driver.sml:300`), and the match's order is one ref for the run (`lib/language/haskell/match.sml:10`), so a
cycle whose modules wanted different rules would be checked under one (*Where we are*). Rune: none under every option.
98 mode is unchanged under every option: a 98 program's modules all have 98's set unless the command line says
otherwise.

- **A. None: a lookup by module wherever a rule is tested.** **Recommended.** The lexer and parser by the file they
  read; the graph by the importing module; the checker by a binding's module (`languageOf` in `groupsOf`); HsLint by
  module and by group; a cycle's own settings by the agreement of its members (D8); `standard` from the library's
  descriptor (D20); `HsMatch.order` stays global, a mode (D8). As E4 prototyped it (*Tracking language settings*,
  *Where each stage reads it*).
- **B. None: one setting per unit;** modules of a cycle with different settings refused. The checker keeps one call,
  one setting. GHC takes each module's own (E5, P15a), and a program that GHC compiles would be refused for its module
  structure alone.
- **C. None: global refs, as at the pin,** one setting for the run. Per-module pragmas cannot be honoured. Rejected.

**The evidence.**
- *Prototyped inside one recursive unit* (`results/E4/permodule/cycle2`, `cycle3`; `results2-b6.txt`) [measured]: A
  under RelaxedPolyRec and B not, each with 4.5.1's example, and only B's bindings refused, by R21's message at
  `cycle2/B.hs:7:1`; both under it, the program prints `(True,True,1)`. Every case agreed by units and whole, at
  `RUNE_LINT=2`.
- *HsLint costs more.* RelaxedPolyRec by module took HsLint four changes to the checker's one: its dependencies, every
  signature in scope first at the top level and in local declarations, and two places in the replay; without the
  signatures first, level 2 refused the mixed program, "hslint has no type for `A.g`" (E4, `agents/A-report.md` finding
  7; that output not kept).
- *The generalisation policy is per run today* (E6, X2: `groupsOf` and `implicitGroup` read no per-module setting), so
  every T8 flag of track X (MonoLocalBinds, NoMonomorphismRestriction) needs A.
- *HsLint's rule is the group's* (E13) [measured]. On build 8, a cycle of A under RelaxedPolyRec and B not was refused
  at level 2, "rhc: lint after hslint: ./B.hs:5:7: hslint has no type for `A.a`" (`results/E13/edits-build8.tsv`, p03
  steps 1 and 4): HsLint put signatures in scope first only for bindings of relaxed modules. Build 9 does so for every
  signed binding of a group in which any module is relaxed, as the checker already did (`anyRelaxed`,
  `patches/E13-language-record-b9.patch`), and every step of that program then gives `--no-store`'s bytes. E4's
  per-module cases had not met it: every per-module feature needs a mixed-cycle test in the checker and in HsLint.

**Recommendation.** A. **The strongest argument against:** every rule becomes a lookup, and a site that forgets it
reads another module's setting silently, as HsLint's did on E13's build 8; B makes that impossible by construction. A
test per feature in a mixed cycle, in both checkers, catches the forgetting, and B refuses programs for their shape.

**What would reopen it.** A feature whose rule cannot be decided per binding, such as a cycle's names or default, which
A already treats by agreement; a cost of the lookups in the checker's time.

### D11. Diagnostics

**Question.** When rhc refuses a construct a feature would allow, does it say so? At the pin rhc refuses in the
Report's terms and names no extension: "expected `then` after the condition of `if`, found a new line at the indentation
of its layout block" (`results/E4/permodule/results3.txt`, `DoIf.hs` in 98). Rune: none under every option.

- **A. None: name the feature, the edition that has it, and how to turn it on, on a path that already fails; in 2010
  modules.** **Recommended.** GHC's three shapes of hint, one feature, any of several, all of several
  (`SuggestSingleExtension`, `SuggestAnyExtension`, `SuggestExtensions`: `ghc/compiler/GHC/Types/Hint.hs:63-99`). A
  token that cannot occur in a valid program of the module's setting (`\case`, a tuple section, `foreign import` in a
  98 module) may be lexed whatever the setting and refused by the parser with the hint; a token that can (`a#b`,
  `(# 1)`, `static`, `[e|`) is lexed by the setting, and any hint is a guess on the error that follows. A hint never
  changes what is accepted.
- **B. None: as A, in 98 modules too.** **Changes 98 mode:** 98's refusals gain hints, and tests/hs/errors' 633 pinned
  messages are re-pinned where they meet one.
- **C. None: no hints;** messages in the Report's terms only, as at the pin.

**The evidence.**
- *GHC* (E5, `results/E5/probes/diag-names.tsv`) [measured]: 37 probes under `-XHaskell2010`, 35 refused, and 26 of the
  refusals name the extension; the other 9 are all decided in the lexer, which made other tokens, and come out as plain
  parse errors (capi, interruptible, ExtendedLiterals, MagicHash, UnboxedTuples, UnboxedSums, parallel arrays, a foreign
  import under `-XHaskell98`, `javascript`). One names the wrong extension: `forall` suggests RankNTypes, not
  ExplicitForAll.
- *Lexing regardless is not always safe.* Valid Haskell 2010 that a lexer-level extension changes: `a#b` with a user's
  `#` under MagicHash, `static = 1` under StaticPointers, `[e|e<-xs]` under TemplateHaskellQuotes, `(# 1)` under
  UnboxedTuples and UnboxedSums (E5, P14a-P14i). So the lexer can read a token whatever the setting only where the
  token cannot occur in a valid program; elsewhere it must follow the setting [inferred].
- *Prototyped for n+k:* "an n+k pattern, which Haskell2010 does not have (NPlusKPatterns is off)", and under
  `-XNoNPlusKPatterns` in 98 "which Haskell98 does not have" (`permodule/results3.txt`) [measured].
- *Warnings are new.* rhc prints none at the pin [read: no warning in `src/rhc` or `lib/language/haskell`]; D6 and D5
  add three, in 2010 modules: a misplaced LANGUAGE pragma, an OPTIONS_GHC flag ignored, a deprecated name written.

**Recommendation.** A. **The strongest argument against:** the hints stop at 98 mode, where a user of n+k or a pattern
guard is the likeliest to need one, and two message styles live in one compiler; B gives the same help everywhere. But
98's 633 messages are pinned and in the Report's terms, and B re-pins them for a convenience.

**What would reopen it.** The owner asking for hints in 98 mode, which is B; a hint that misleads, as GHC's `forall`
one does, found by E5's 35 cases run on rhc.

### D12. CPP

**Question.** Does rhc run the C preprocessor that a file's `{-# LANGUAGE CPP #-}` asks for, and how? The brief does not
mention CPP; chapter 12's only example names it, `{-# LANGUAGE ScopedTypeVariables, CPP #-}` (T10:10987), and defines
it nowhere. GHC runs `gcc -E -undef -traditional ... -x assembler-with-cpp` with its own `-D` flags and an included
`ghcversion.h` (`results/E3/cpp/ghc-cpp-invocation.txt`), and reads the header again after it (D6). Rune has an ISO C
preprocessor in SML for C headers, `CPreprocess` in `lib/language/c` (`lib/language/c/preprocess_sig.sml:4-32`), with
`CConst` evaluating its `#if` expressions (`const_sig.sml:4-25`); its lexer reads `//` and `/*` as comments and `'` as a
character literal (`lib/language/c/lex.sml:72-73`, `:79-82`), which Haskell's `//`, `foldl'` and `x'` are not, so it
cannot run over a Haskell text [read; not run]. Rune: none under every option. 98 mode is unchanged under every option:
in a 98 module `CPP` in a pragma is not read (D6), as today.

- **A. None: a subset written in SML, off unless asked.** **Recommended.** Conditionals (`#if`, `#ifdef`, `#ifndef`,
  `#elif`, `#else`, `#endif`) with integer expressions and `defined()`; object-like and function-like `#define` and
  `#undef`, expanded in code; `#include` confined to the program's own directory; every directive line and every line a
  conditional skips blanked, not dropped, so that positions hold; in traditional mode, so that Haskell's own tokens
  pass. rhc defines no `__GLASGOW_HASKELL__`, and `MIN_VERSION_x(...)` is false for every package rhc does not have, a
  decision of its own in M20. About a thousand lines [inferred: cpphs is 1,100 lines of Haskell in `Language/`, 1,318
  with its parser library, `results/E11/cpphs-wc.txt`]; `CConst` may serve the `#if` expressions, over `CLex` tokens
  of the directive line alone [inferred].
- **B. None: an external `cpp -traditional`.** A host dependency rhc has nowhere else; `-P` loses line numbers, and
  without it the `# N "file"` markers need a reader rhc's lexer lacks.
- **C. None: refuse,** "not supported by rhc" (D7), as 12.3's error. The fallback if D12 is cut.

**The evidence.**
- *How much CPP there is* (E7, Stackage LTS 24.67, `results/E7/cpp.tsv`, `cpp-macros.tsv`, `ext-freq.tsv`) [measured]:
  on in 9,184 module files (18.6%) of 1,581 packages (46.6%), by a pragma in 80.7% of them; but only 1,123 files (2.3%
  of 49,394) need CPP and nothing else beyond 2010. Of the CPP files, 2,872 (31.3%) have no directive and expand no
  macro; 5,000 (54.4%) use conditionals only; 336 (3.7%) expand a macro in code, a lower bound, since headers pulled
  in by `-optP` are not counted; 750 (8.2%) include a local file. Of the files with a directive (6,258), `MIN_VERSION_*`
  is tested in 3,587 (57.3%) and `__GLASGOW_HASKELL__` in 1,355 (21.7%); 871 (13.9%) `#include`; 2 files paste tokens
  with `##`. `cpp-macros.tsv` counts 6,255 files with a directive where `cpp.tsv` counts 6,258.
- *The corpora* (E3, `results/E3/cpp/cpp-summary.tsv`) [measured]: 12 of the corpus's 3,089 candidates turn CPP on in
  the header and 41 have directives; nofib's 657 files, 76 and 93; the GHC testsuite's 508 files naming Haskell2010, 2
  and 2. E8's filter kept 167 of 3,217 candidates from every compiler, 129 of them for CPP (19 with `#include`), and 64
  of the 170 of nofib 2025 (`results/E8/filtered.tsv`, `manifest.tsv`): D12 would bring nofib back (D40).
- *An external cpp against GHC* (E3, `results/E3/cpp/probe.tsv`, 16 sample files with no `#include`, TemplateHaskell or
  QuasiQuotes) [measured]: with blank lines and line markers dropped, `cpp -traditional -P` matches `ghc -cpp -E` on 14,
  with `-undef` too on 14, and with `-undef -x assembler-with-cpp` and GHC's `-D` flags on 16; with blank lines kept,
  on none. The two misses test `__GLASGOW_HASKELL__`. `-P` takes 122 lines to 82, 183 to 124 (`lines.tsv`).
- *GHC's order:* CPP must be on before the first `#` line, a `#if` before `LANGUAGE CPP` failing to parse (P13c); a
  pragma under `#if 0` does not count (P13b) (E5, `semantics.md` section 9).
- *Untrusted code:* `#include` reads local files, and the filter keeps such files from every oracle (D40); A's
  confinement to the program's directory answers that.

**Recommendation.** A. **The strongest argument against:** it pays only beside the other extensions, since 2.3% of
files need CPP alone, and a thousand lines of preprocessor are a thousand lines that are not the Report. But CPP is the
most widespread extension by package (46.6%), most of its use is the small part A covers, and B's host dependency and
lost positions are worse.

**What would reopen it.** The owner keeping rhc to the Report and its listed extensions, which is C; a need for
macro expansion beyond A's subset in a corpus that matters; the owner's rule that generic code becomes a library under
`lib/`, which would put the subset beside `lib/language/c` and make it a small Rune change.

### Haskell 98 alignment

The brief allows one kind of change to 98 mode: "the haskell98 mode needs to stay haskell 98 as per its report. in case
we made an arbitrary choice during the haskell98 roadmap in rhc because the haskell 98 report was ambiguous or
underspecified you may bring rhc in haskell98 mode in line with haskell 2010 (reading the haskell 2010 report as
clarifying what the haskell 98 should have said, but be very explicit in the roadmap that you will be doing so, so i
can review)". E2 put every choice rhc made for 98 to a three-part test, that condition taken literally: (1) 98's text
admits two readings, is silent, or contradicts itself; (2) rhc picked one; (3) 2010's text picks the other, or picks
one where rhc's choice was free. All three hold for an ALIGN; an OVERRIDE fails (1), since 98's text was plain and rhc
followed it; a CHANGE is new language, not a clarification. Of 232 items (every reading, the 8 deviations, the 53
overlay entries of `share/rhc/haskell98/overlay.tsv`, the rulings and owner items), 97 are SAME, 118 OPEN, 9 CHANGE,
and 3 rows ALIGN and 5 rows OVERRIDE, which are 4 items (`results/E2/alignment.tsv`; E2's README says 55 overlay
entries, the file has 53). Each is argued in *Haskell 98 mode and the 2010 text*; the decisions below are those four.
**Every option marked "changes Haskell 98 mode" does, and each D13 is the owner's call.** Whatever the owner takes
becomes track H, its pins re-pinned and 98 mode's other output held byte for byte.

### D13a. `genericLength` in 98 mode (R48)

**Question.** Does 98 mode's List type `genericLength` as chapter 17 does, or as 4.5.5 does and 2010 settles? The
clause pair: 98's 4.5.5, "genericLength is a standard function (in library List) whose type is given by genericLength
:: Num a => [b] -> a" (T98:6325-6326), with an example that needs it, `len2 = (2*len1) :: Rational`, where "the type
variable a is resolved to Rational" (T98:6391-6397); against 98's chapter 17, `genericLength :: Integral a => [b] -> a`
in its list of signatures (T98:11645), its prose (T98:11819) and 17.9's code (T98:12016). 2010's Data.List:
`genericLength :: Num i => [b] -> i` (T10:13317), "instead of returning an Int, it returns any type which is an
instance of Num" (T10:13319-13320), with 4.5.5 unchanged (T10:4862-4864). rhc took chapter 17:
`share/rhc/haskell98/List.hs:185`, and the overlay entry `ov.list.genericlength` is a `nochange`, "the code stands, and
both examples are tests" (`share/rhc/haskell98/overlay.tsv:66`). The 98 roadmap left the choice open: "Tests must pin
one side of each" (haskell98.md:1574-1575). E2: ALIGN. **Taking it changes Haskell 98 mode.** Rune: none under every
option. **The owner's call.**

- **A. None: align; List's signature becomes `(Num a) => [b] -> a`.** **Recommended.** **Taking it changes Haskell 98
  mode: List's `genericLength` gets another type, and programs 98 mode refuses today are accepted.** One line; the
  definition, `1 + genericLength xs`, needs only Num (`List.hs:186-187`). `ov.list.genericlength` becomes an applied
  entry of kind `reading`, ground D13a, so that the overlay check accepts the line that now differs from
  `share/rhc/haskell98/pristine/List.hs:180`. Rows `lib.r.list.generic.length` and `lib.list.genericlength`
  (`tests/hs/conformance.tsv:3112`, `:3155`) restate. List's interface changes, so the snapshot and every unit that
  imports List rebuild once [inferred].
- **B. None: keep chapter 17's type.** 98 mode unchanged; the contradiction stays pinned as today, 4.5.5's example
  tested with a local `genericLength` of 4.5.5's type (`tests/hs/accept/mr.rule2.laterdecl.hs:7-8`).

**The evidence.**
- *Tests whose expected output changes: none* [inferred from the tests' text, not run]. Every use of List's function in
  `tests/hs` is at Integer or Int, which Num admits, or unapplied, and defaulting still picks Integer:
  `lang/lib.list.genericlength_literal` (`tests/hs/lang/lib.list.genericlength_literal.hs:259`, against the Report's own
  code at both types), `lang/lib.list.genericlength_probe1`, `lang/lib.r.list.generic.length_text`,
  `lang/pre.r.generic_length`, `lang/mr.ex.len.shared` (`len1, len2 :: Integer`) and
  `accept/lib.list.export.elemindex_imported` (`v32 _ = genericLength`).
- *One test to rerun:* `errors/mr.ex.len.twotypes` uses List's function at Int and Double, `let len = genericLength "ab"
  in (len :: Int, len :: Double)`, and must stay refused. Today Double fails Integral as well; after A Rule 1 alone
  refuses it, and its `.expected`, `` `len` ``, must still be in the first line of what rhc says
  (`docs/testing.md:532-534`) [inferred; W3].
- *Programs newly accepted:* `genericLength` at a Fractional type, 4.5.5's own example. The six tests that define a
  local copy of 4.5.5's type (`accept/mr.rule1.def.fun`, `accept/mr.rule2.laterdecl`, `accept/mr.rule2.m1.type/`,
  `errors/mr.rule2.m1m2/`, `errors/mod.flatten.mr/`, `hslint/rule2`) could then import List's, as the Report means.
- *Corpus* [read]: nofib's and nhc98's `primetest` use it at `Integer -> Integer`
  (`tests/hs/corpus/vendored/nofib/spectral/primetest/IntLib.lhs:89`,
  `tests/hs/corpus/vendored/nhc98/tests/nofib/spectral/primetest/IntLib.lhs:96`), and `linear` at Int, through `take`
  (`tests/hs/corpus/vendored/nofib/real/linear/Matlib.lhs:399`); `knights`'s documentation defines a copy of 4.5.5's
  type in a code block (`tests/hs/corpus/vendored/nofib/spectral/knights/root.lit:110-113`). None changes.
- *The oracles already answer Num:* GHC's `genericLength :: (Num i) => [a] -> i`
  (`ghc/libraries/ghc-internal/src/GHC/Internal/Data/OldList.hs:1018`), which rhc's GHC shim re-exports as List's
  (`tests/hs/oracles/ghc-shim/List.hs:30`) [read].

**Recommendation.** A. **The strongest argument against:** rhc's 98 library is the Report's code, departing only where
an erratum or a reading of 98's own text says so (98's D36, D37), and this would be the first overlay entry grounded in
2010's text. It is the brief's case exactly, a choice between two texts of 98 that 2010 settles, for one line and no
verdict moved.

**What would reopen it.** `errors/mr.ex.len.twotypes` failing its expected text after the change; a program that needs
the Integral context to resolve a type, which no test has [inferred].

### D13b. `0 ** y` (R45(b))

**Question.** Does 98 mode take 2010's sentence on `0 ** y`? The clause pair: 98's 6.4.3, "0**y is undefined."
(T98:15328); 2010's, "0**y is 1 if y is 1, and 0 otherwise." (T10:6389-6390), a misprint for "1 if y is 0", reported
on the haskell-prime list in April 2011 and never corrected (E1's N10, `results/E1/errata2010.md`). rhc took IEEE's
`pow`, where Rune's real is: 1 at y = 0, 0 for a positive y, an infinity for a negative y (R45,
`tests/hs/readings.md:434-441`); Double's `(**)` is `double_pow` (`share/rhc/haskell98/Prelude.hs:781`), and Float's
goes through it (`:707`). "Undefined" left the value free, so E2 files an ALIGN. **Taking it, under either reading of
the sentence, changes Haskell 98 mode.** Rune: none under every option. **The owner's call.**

- **A. None: decline; IEEE's `pow` in both modes.** **Recommended.** 98 mode unchanged. The misprint goes in *Found
  while writing*; what 2010 mode gives at a negative y is N10's reading, with D38.
- **B. None: align to the sentence as printed.** **Taking it changes Haskell 98 mode.** A test before `double_pow`: 1
  at y = 1 and 0 everywhere else, **so `0 ** 0` becomes 0 too**, where the same sentence makes `x ^ 0` and
  `x ^^ 0` 1 for any x, including zero (T10:6389). A few lines in the Double instance and a change to
  `ov.prelude.double`'s text (`overlay.tsv:27`) [inferred].
- **C. None: align to the sentence as meant, "1 if y is 0".** **Taking it changes Haskell 98 mode.** Only a negative y
  changes, from an infinity to 0. The same few lines [inferred].

**The evidence.**
- *The test whose expected output changes:* `tests/hs/lang/std.pow.undefined` prints `(0 ** 2, 0 ** 0, 0 ** (-1))` at
  Double and `(0 ** 0.5, 0 ** 0, 0 ** (-2))` at Float (`std.pow.undefined.hs:9-10`) and expects `(0.0,1.0,Infinity)`
  twice. Under B both lines become `(0.0,0.0,0.0)`; under C both become `(0.0,1.0,0.0)` [inferred from the test's text,
  not run]. Row `std.pow.undefined` (`tests/hs/conformance.tsv:1729`) restates under either. E2's effect column has the
  printed sentence flip the test by `0 ** 1`, which the test does not compute; what flips is `0 ** 0` (W3).
- *IEEE and the corrected sentence agree for y >= 0;* at a negative y IEEE gives an infinity and the sentence 0, and
  neither reading says what a NaN gives. 6.4 asks that "Double should cover IEEE double-precision" (T10:6239) [read].
- *No oracle gives B or C:* GHC gives IEEE's answers (E1's probe `n10a_zero_pow`); Hugs errs at a negative y and nhc98
  gives the largest finite number (`tests/hs/readings.md:436-437`).

**Recommendation.** A. **The strongest argument against:** the item passes the brief's test, 98's "undefined" being a
free choice that 2010 replaced with words, and declining keeps 98 mode at IEEE where 2010 says something else. The
words are wrong arithmetic as printed and against IEEE as meant, and taking either would give an answer no
implementation gives.

**What would reopen it.** A published correction of 6.4.3; D38 giving 2010 mode the corrected sentence, after which the
two modes differ at a negative y and C would make them agree.

### D13c. `isUpper` and `isAlpha` of a letter with no case (R38(a), with R153(b))

**Question.** Does 98 mode take 2010's Data.Char for letters with no case? The clause pair: 98's chapter 19, "For the
purposes of Haskell, any alphabetic character which is not lower case is treated as upper case (Unicode actually has
three cases: upper, lower, and title)." (T98:12229-12235), its table giving `isUpper` to every "Other Alphabetic"
character (T98:12240-12245), and 19.1's `isAlpha c = isUpper c || isLower c` (T98:12309); 2010's Data.Char, `isUpper`
"Selects upper-case or title-case alphabetic Unicode characters (letters)." (T10:11844), and `isAlpha` "Selects
alphabetic Unicode characters (lower-case, upper-case and title-case letters, plus letters of caseless scripts and
modifiers letters). This function is equivalent to Data.Char.isLetter." (T10:11848). rhc follows 98:
`primUnicodeIsUpper` is true of Lu, Lt, Lm and Lo (`lib/language/haskell/coreruntime.sml:622-625`), and `isAlpha`
stands as printed (`share/rhc/haskell98/Char.hs:42`), under `ov.char.prims` (applied) and `ov.char.isalpha`
(`nochange`) (`share/rhc/haskell98/overlay.tsv:44`, `:67`). **An OVERRIDE, not an alignment:** the test fails at (1),
since 98's sentence is plain. **Taking it changes Haskell 98 mode.** The one ground for calling it contradictory is
2.2's "uniLarge -> any uppercase or titlecase Unicode letter" (T98:2427), which leaves a caseless letter in no lexical
class; 98's D38 saw it ("R38 may belong in the first group", haskell98.md:6727), and the owner decided that R38
follows the text (haskell98.md:6740). Rune: none under every option. **The owner's call, and B only on the owner's
explicit word that the "contradictory" ground applies, reversing 98's D38 on R38.**

- **A. None: no; 98 mode keeps chapter 19.** **Recommended.** 2010 mode follows Data.Char (D26).
- **B. None: override; `isUpper` is Lu and Lt in 98 mode, and `isAlpha` a letter test.** **Taking it changes Haskell 98
  mode, against 98's plain text and the owner's decision of 98's D38: a CJK, Hebrew or modifier letter stops being
  upper case.** `isAlpha`'s answers stay (Lu, Ll, Lt, Lm and Lo either way), but it stops being
  `isUpper c || isLower c`, so `Char.hs:42` departs from `pristine/Char.hs:37` and `ov.char.isalpha` becomes an
  applied entry; `ov.char.prims` changes its text; rows `lib.r.char.table.other.upper` and `lib.r.char.isalpha`
  (`tests/hs/conformance.tsv:3308`, `:3334`) restate; 98's D38 table changes its R38 line [inferred, not built].

**The evidence.**
- *Tests whose expected output changes under B* [inferred from the tests' text, not run]:
  - `tests/hs/lang/lib.r.char.table.other.upper_unicode`: expected line 1 (the source's line 22, the table of U+01C5,
    U+05D0 and U+4E2D), whose `isUpper` row goes from `[True,True,True]` to `[True,False,False]`, U+01C5 being Lt and
    the others Lo; and expected line 13 (the source's line 34, the law `isAlpha c == (isUpper c || isLower c)` at every
    character), from `True` to `False`.
  - `tests/hs/lang/lib.r.char.table.other.upper_categories`: expected lines 7, 8 and 9, the rows of U+4E2D and U+05D0
    (Lo) and U+02B0 (Lm), from `1111000` to `1110000`; U+01C5's row (line 6) stays.
  - If the change is made in `primUnicodeIsUpper` rather than in `Char.hs`, `tests/hs/core/runtime-unicode` changes
    too: expected lines 7, 18 and 33, of U+00AA (Lo), U+02B0 and U+4E2D, from `U.AP` to `..AP`.
- *Unchanged:* ASCII; `lang/lib.r.char.table.lower.print_latin1`, which has no caseless letter; the lexer, whose classes
  are 2.2's [read].
- *The oracles part from 98:* GHC, Hugs and MicroHs take a letter of no case as neither upper nor lower
  (`tests/hs/readings.md:502-503`), and GHC calls its `isAlpha` a divergence from "the Haskell 98 definition"
  (`ghc/docs/users_guide/bugs.rst:466-473`) [read].
- *Corpus:* the three predicates appear on 40 lines of 15 files of the vendored corpus, by word (`grep -w`, run while
  writing, `results/verify/V2/numbers-a/corpus-grep.out`; E2's 47 matched `isAlphaNum` too, W3), on input that is ASCII
  as far as read [inferred].

**Recommendation.** A. **The strongest argument against:** under A rhc's 98 mode prints, for `isUpper` of a CJK letter,
what no judge prints, and 98's own `uniLarge` calls that letter not upper, so the text is at odds with itself (98's
D21, haskell98.md:6249); 2010 then says what the committee meant. That was weighed in 98's D38 and decided, and the
brief lets this roadmap change 98 mode only where 98 was ambiguous and rhc's choice arbitrary; here rhc followed a
plain sentence by the owner's ruling. If the owner takes B, the roadmap records it as an override of 98's chapter 19
and of 98's D38, not as an alignment.

**What would reopen it.** The owner reading chapter 19 against 2.2 as contradictory, which is B. 98's D38 named "a mode
for Haskell 2010, which has its own text" among what would reopen it (haskell98.md:6738); this is that reopening.

### D13d. `isSpace` beyond Latin-1 (R153(a))

**Question.** Does 98 mode take 2010's `isSpace`? The clause pair: 98's chapter 19, "The isSpace function recognizes
only white characters in the Latin-1 range." (T98:12253), with 19.1's ``isSpace c = c `elem` " \t\n\r\f\v\xA0"``
(T98:12302); 2010's Data.Char, "Returns True for any Unicode space character, and the control characters \t, \n, \r,
\f, \v." (T10:11833). rhc follows 98: `share/rhc/haskell98/Char.hs:35` is the Report's line as printed
(`pristine/Char.hs:30`), row `lib.r.char.isspace` (`tests/hs/conformance.tsv:3322`). **It has no overlay entry
today:** E2 files `ov.char.prims` under R153(a), but that entry names `isPrint`, `isUpper`, `isLower`, `isAlphaNum`,
`toUpper` and `toLower` (`share/rhc/haskell98/overlay.tsv:44`), not `isSpace` (W3). **An OVERRIDE, not an alignment:**
98's text is plain, in its prose and its code alike, so the test fails at (1) and no ground of 98's D38 reaches it.
**Taking it changes Haskell 98 mode.** **The owner's call, and B only on the owner's explicit word.**

- **A. None: no; 98 mode keeps the seven Latin-1 white characters.** **Recommended.**
- **B. None or small, by the reading: override, with one of D26's two readings of "any Unicode space character".**
  **Taking it changes Haskell 98 mode, against 98's plain text: `isSpace`, `words` and `lex` treat Unicode spaces above
  Latin-1 as white space.** `share/rhc/haskell98/Char.hs:35` departs from `pristine/Char.hs:30` and needs a new
  overlay entry of its own; row `lib.r.char.isspace` restates.
  - **(i) None: general category Zs and the five controls,** D26's reading for 2010, over the category the runtime
    already computes (`coreruntime.sml:618`).
  - **(ii) Small: Unicode's White_Space property,** which adds U+0085, U+2028 and U+2029
    (`/usr/share/unicode/PropList.txt:12-22`, version 15.1.0 on this machine): a table `lib/unicode` lacks (*The
    libraries*).

**The evidence.**
- *Tests whose expected output changes under B* [inferred from the tests' text, not run]:
  - `tests/hs/lang/lib.r.char.table.other.upper_unicode`: expected line 8 (the source's line 29, `isSpace` of U+2003,
    U+3000 and U+2028, then of U+00A0), from `([False,False,False],True)` to `([True,True,False],True)` under (i) and
    `([True,True,True],True)` under (ii).
  - `tests/hs/lang/lib.r.char.table.other.upper_categories`: expected line 14, U+3000, from `1000000` to `1000001`
    under either; under (ii) line 12, U+2028, from `0000000` to `0000001` too.
  - `tests/hs/lang/lib.r.char.table.lower.print_latin1`: unchanged under (i), since the seven are Zs or among the five
    controls and U+0085 is neither; under (ii) U+0085 is a space, and the last line's second list goes from
    `[False,False,False,False]` to `[True,False,False,False]`.
- *Beyond the tests:* `words` (`share/rhc/haskell98/PreludeList.hs:250-253`) and `lex` (`PreludeText.hs:109`, and its
  string gaps at `:120-123`) call `isSpace`, so splitting words, `read`'s skipping of white space and string gaps change
  on input above Latin-1 [read; the effect inferred].
- *The oracles:* GHC and MicroHs take U+2003 and U+3000 as spaces (`tests/hs/readings.md:504`); GHC follows Zs
  (E1's N7, probe `n07a_isspace`: false of U+0085, U+2028 and U+2029).

**Recommendation.** A. **The strongest argument against:** 98 mode then splits Unicode text otherwise than every judge
that answers above Latin-1, and Unicode input to 98 programs is real. The 98 text says Latin-1 in so many words, and
the brief allows no override.

**What would reopen it.** The owner's explicit word to override, which is B, with D26 picking between (i) and (ii).

**Three points for the owner that are not alignments.** E2 found three more items that it does not file as ALIGN but
that would change 98 mode if taken; *Haskell 98 mode and the 2010 text* argues each.
- **R41, R87 and ruling 14, derived `Show` of a record at precedence 11: a re-reading of 98's own text, not an
  alignment.** 2010's 11.4 is 98's 10.4 word for word: "if d is 11 it is always surrounded in parentheses, unless it is
  an atomic expression (recall that function application has precedence 10)" (T98:10223-10225, T10:10789-10790). rhc
  took GHC's row, a record parenthesised at 11, "which Haskell 2010 took [memory]" (haskell98.md:1303;
  `tests/hs/readings.md:257-262`); GHC's own documentation calls those parentheses a divergence: "whereas Haskell 2010
  calls for...", `show (Just (Hello {aField=42})) == "Just Hello {aField=42}"` (`ghc/docs/users_guide/bugs.rst:438-451`)
  [read]. **Re-reading it changes Haskell 98 mode,** and 2010 mode with it, on 98's own text, not 2010's: if a record
  construction, an `aexp`, is "an atomic expression", 10.4 says not to parenthesise it [inferred]. Then
  `lang/der.show.record.form_ghc`'s second expected line goes from `(S {h = 1})` to `S {h = 1}`, derived `Read` follows,
  and row `der.show.record.prec` (`tests/hs/conformance.tsv:2737`) restates [inferred].
- **R21(c) and ruling 55, signatures that cut dependency groups: a CHANGE.** 12.3 names RelaxedPolyRec among the
  extensions "integrated into this report" (T10:10997-11002), so 2010 mode takes it (D16) and it is not eligible.
  **Aligning it anyway would change Haskell 98 mode:** the six corpus programs ruling 55 refuses would be accepted, and
  `dec.dep.sig.group` and `dec.gen.sig.identical`'s second test would flip (`tests/hs/conformance.tsv:1141`, `:1148`).
  Not recommended.
- **R54, ruling 11 and 98's D22, `Int` overflow: OPEN or ALIGN, by the reading of D21.** 98's 6.4 leaves overflow
  undefined (T98:7554-7556) and rhc chose an error; 2010 keeps 6.4 (T10:6239-6241) and adds Data.Int's "All arithmetic
  is performed modulo 2^n" of a list naming Int (T10:12381-12382). On E1's reading 2010 contradicts itself (N6),
  settles nothing, and R54 is OPEN; on the reading D21 takes, chapter 18 narrows 6.4 to a truncated value, all three
  parts hold, and R54 is an ALIGN. D21's option C is that alignment, and **it changes Haskell 98 mode:** every overflow
  test flips (`lang/def.pick.first_overflow`, R81's and R93's rows, `tests/hs/readings.md:222-226`, `:288-291`), and
  ruling 11's compatibility layer for wrapping bit tricks goes. D21 recommends B, wrapping in 2010 mode only, so 98 mode
  stays checked under either reading.

### Front end

### D14. Pattern guards

**Question.** How does rhc read, type and translate 2010's guards, and how do they meet 98's D34, which compiles
matches by Sestoft's trees at `-O2`? A 2010 guard is a list of qualifiers, each `pat <- infixexp`, `let decls` or a
boolean (3.13, T10:2745-2758); the bindings of each are in scope in the qualifiers after it and in the body, and a
failing qualifier fails its guarded expression, which falls to the next (T10:2798-2804). Figure 3.3 translates them by
rules (s) to (v) (T10:3438-3459). rhc's guard is one expression today (`Guard of ann * exp * exp`,
`lib/language/haskell/ast_sig.sml:132`), desugared to `if` (`lib/language/haskell/desugar.sml:469-472`). Rune: none
under every option.

- **A. None: qualifiers in the AST, Erwig and Peyton Jones's translation with the fall-through bound once.**
  **Recommended.** As E3 spiked it (`patches/E3-04-guards.patch`):
  - a guard is a list of statements, and a 98 boolean guard is a single `SExp`, which every site sends down its old
    code, so 98's Core and bytes do not move;
  - qualifiers are tried left to right, each failing to what the guard falls to: the later guards, bound once by a
    `let` where a qualifier can fail (rule (c)'s `y`, T10:3320-3337), the last guard falling straight to its clause's
    failure;
  - a pattern guard's pattern is matched in the Report's way (`HsMatch.pattern`) at both match orders, and guards are
    opaque leaves of D34's trees.

  110 code lines in 12 files, +136/-22: parser 44, desugarer 21, HsLint's inference 17, checker 16, renamer 4, dump 2,
  and one each in the AST, its signature, fixity, the printer, HsLint's replay and the syntax tests' generator
  [measured: `results/E3/diffstat.tsv`].
- **B. None: rule (s) as printed.** As A, but `e'` written out at each failing qualifier. The meaning is the same, and
  a clause's code grows with its qualifiers times the size of what follows them. The copy is a defect of the text
  (below), so B buys its letter and nothing else.
- **C. None: a pattern guard's test feeds the tree.** At `-O2` a later clause would not test again what a pattern guard
  tested: in E3's `h`, the second clause tests `Just` again after the guard `Just k <- m` failed
  (`results/E3/sestoft/core.sestoft.txt`). Erwig and Peyton Jones say the standard technique for matching trees "can be
  adapted straightforwardly", and warn that how often a view function then runs depends on the match compiler (E11,
  `results/E11/literature.md`, Part C). An optimisation, not needed for correctness.
- **D. None: rewrite pattern guards into `case`, `let` and `if` before checking.** The checker and HsLint would change
  nothing (their 33 lines saved), but type errors would name the rewrite, `--print` would show code the user did not
  write, and HsLint would check a translation rather than the program, which is its point (98's D54) [inferred].
  Rejected.

**The evidence.**
- *Behaviour.* `guards1`, `guards2` and `guards-sestoft` print the same on Core's interpreter and at `-O1` and `-O2` on
  register and stack bytecode, at `RUNE_LINT=2`, and the same as GHC 9.4.7 `-XHaskell2010`
  (`results/E3/run-programs3/results.tsv`, `results/E3/ghc/ghc.tsv`) [measured]. `guards2` ends in the error "second
  qualifier forced" under both: the qualifiers run in order and no further.
- *The trees.* At `-O2` what a clause's patterns tested survives a guard's fall-through (`f`'s second clause does not
  test `Just` again), and no qualifier runs before its clause's patterns matched (`sestoft/core.sestoft.txt`)
  [measured]. 98's `hs/simplify/sestoft` already holds the trees to the Report's order "where a tree could force what
  the Report does not", guards among the cases (haskell98.md:6606).
- *The fall-through `let`* is the device rhc's match compiler already uses for a clause's failure (the `%fail` lets of
  `sestoft/core.report.txt`), so the simplifier and CoreToMid treat both alike. Core has no join point of its own: its
  `let` is lazy (`lib/language/haskell/core_sig.sml:67`), and a join is Mid's, made by CoreToMid for a continuation
  (`coretomid.sml:726-736`). 98's D34 found a failure bound lazily at a match's head built a suspension at every
  entry, and moved the raise to the leaves (haskell98.md:6606); that guards gain nothing new to tune is [inferred],
  not measured.
- *98 mode held* over the whole series of E3's patches, not this one alone: tests/hs/lang's 591 programs byte for byte
  at `-O1` and `-O2`, 354 of 354 bytecode files of 98's D56's run set, 633 of 633 refusals, 3,812 of 3,812 views
  (`results/E3/identity/`) [measured].
- *Scope* (E1's N3). A `where` sees no guard's bindings (T10:2771, 2800-2801); GHC refuses one, "Variable not in scope"
  (`results/E1/probes`, `n03c_guard_where_scope`). A `let` qualifier's block is closed at `,`, `=` or `->` by
  parse-error(t), which the parser's existing implicit close does with no new code (E3, `programs/guards1.hs`,
  `guards2.hs`; GHC `n03a_guard_let_comma` gives `(0,6)`).
- *3.13's note* (T10:2806-2814): `| let b = not a in b :: Bool -> a` is accepted by rhc in both modes, as 98's R65 has
  it, and refused by GHC in both, "parse error on input ;" (`ghc/ghc.tsv`). The spike's re-reading of an alternative's
  guard (`lib/language/haskell/parser.sml:1028-1043`) retries the whole qualifier list.
- *GHC cannot judge 98 mode here:* it accepts pattern guards under `-XHaskell98` with a warning only
  (`ghc/compiler/GHC/Rename/Bind.hs:1473-1488`) [read].
- *The defect.* Rule (s) copies `e'` into every alternative and ends "where y is a new variable" with no `y` in it
  (T10:3447; the HTML the same). Erwig and Peyton Jones's own rule binds `e'` once, `case e' of { y -> ... }` (E11,
  finding 10, `P10/erwig01.txt` p. 5); it was reported in 2018 (E1's N3). For *Found while writing*.

**Recommendation.** A. **The strongest argument against:** A's shared fall-through is a `let` that rule (s) does not
write, so the translation `-O0` runs is not the text's letter, which 98's D34 kept at `-O0` for conformance. The
meaning is the same, rule (c) shares through `y` itself, and B pays code size for a misprinted rule.

**What would reopen it.** `--count` on 2010 programs showing repeated tests after failed pattern guards, which brings in
C; ViewPatterns in track X (D35), which wants C's machinery. 98 mode is unchanged under every option: pattern guards
are a change of language, and 98's own reading of a guard, R65, is SAME in E2 (`results/E2/alignment.tsv`).

### D15. Empty data declarations

**Question.** 4.2.1 allows `data [context =>] simpletype [= constrs] [deriving]` (T10:3860), a type "with zero or more
constituent data constructors" (T10:3911), and chapter 11 adds a sixth condition: "If the data declaration has no
constructors (i.e. when n = 0), then no classes are derivable (i.e. m = 0)" (T10:10670). rhc's parser requires the `=`
(`lib/language/haskell/parser.sml:1373-1385`); the AST allows an empty list; and the library fakes its primitive types
with `elidedData`, which writes a constructor of its own (`src/rhc/library.sml:115-139`). Rune: none under every
option. 98 mode is unchanged (E2: R23(b) is a CHANGE row).

- **A. None: a `Core.Data` with no constructors.** **Recommended.** As spiked (`patches/E3-03-empty.patch`): the parser
  takes `[= constrs]`, the printer writes no `=`, and condition 6 is one check in the checker and one in HsLint. 13 code
  lines in 4 files, +19/-4: checker 5, parser 3, HsLint 3, printer 2 [measured: `diffstat.tsv`]. Nothing below the front
  end changes.
- **B. None: one hidden constructor,** as `elidedData` does for the library. It gains nothing, since nothing below the
  front end needed a constructor (below), and it puts a constructor no program can name into every dump and into
  Core's shape of the type. Rejected.

**The evidence.**
- *Below the front end.* A `Core.Data` with no constructors passes CoreLint at level 2 and CoreToMid, and runs on
  `runevm` and `runevm-stack` at `-O1` and `-O2`: `programs/empty1.hs` (a wildcard forcing nothing, `seq` to bottom,
  `[] :: [Void]`) prints the same on every way and as GHC (`results/E3/run-programs3/results.tsv`, `ghc/ghc.tsv`)
  [measured]. runeopt's native code was not among E3's ways (`results/E3/README.md`).
- *Condition 6.* `data Void deriving Show` is refused, as GHC refuses it, and `deriving ()` accepted (`empty2.hs`,
  `empty3.hs`) [measured]. The Haskell' proposal: "syntactically allow all deriving clauses for empty data, but
  semantically limit the clauses to deriving ()"; Hugs refused `data Foo deriving ()`, and Marlow answered "Yes, it's
  legal according to the grammar" (E11, Part A2).
- *Flips:* `errors/dec.data.noconstructors` and `errors/syn.r.dataconstrs` are accepted under 2010, and
  `errors/kind.implicit` is refused with another message (`results/E3/flips/attribution.tsv`).
- *What 2010 leaves open* (E1's N12): an empty type's parameters get no kind from a constructor, so 4.6's default `*`
  applies [inferred]; `case x of {}` stays illegal, "A case expression must have at least one alternative" (T10:2791,
  98's R13), so EmptyCase is track X's (D35).
- *The library.* `elidedData` stays: a printed `data Char` in the library stands for a primitive type, not an empty
  one [inferred], and D23's normalisation keeps it.

**Recommendation.** A. **The strongest argument against:** a type with no constructors has no execution record in
rhc beyond E3's three programs, and a lowering that assumes a constructor would fail only on one. CoreToMid's case on
such a type has no constructor arm and takes its default (`lib/language/haskell/coretomid.sml:1109`, `:1116-1118`)
[read], and E3 ran both VMs at two levels; the native back end is the gap a conformance row closes.

**What would reopen it.** A lowering fault on an empty type; EmptyDataDeriving (track X), which derives for one.

### D16. Relaxed dependency analysis

**Question.** 2010's 4.5.1: "A binding b1 depends on a binding b2 in the same list of declarations if either 1. b1
contains a free identifier that has no type signature and is bound by b2, or 2. b1 depends on a binding that depends
on b2." (T10:4710-4712). 98 groups by binding alone, a signature cutting nothing (R21(c),
`lib/language/haskell/infer.sml:1235-1239`). The edges are the checker's `deps` in `groupsOf`
(`infer.sml:1135-1247`, `deps` at `:1208-1211`) and HsLint's `succs` (`lib/language/haskell/hslint_infer.sml:433-439`),
which the replay's `[bindg]` and `[scc]` rules reuse (`hslint_replay.sml:609`, `:646`). Rune: none.

- **A. None: in 2010 mode, the edge to an explicitly typed binding cut, in both checkers.** **Recommended.** As
  spiked (`patches/E3-05-relaxed.patch`): 41 code lines, +57/-8: checker 7, HsLint 34 [measured: `diffstat.tsv`].
  HsLint must also assume every explicit signature before the groups, as Typing Haskell in Haskell's `tiBindGroup` does,
  or a group meets a signed binding typed later and fails, "hslint has no type for ..." (E3, finding 5). R21(b)'s check
  of identical contexts stays.
- **B. None: in both modes.** **Changes 98 mode:** it aligns R21(c), which E2 files as a CHANGE and so not eligible
  (*Haskell 98 mode and the 2010 text*): six programs ruling 55 refuses would be accepted, and `dec.dep.sig.group` and
  `dec.gen.sig.identical`'s second test would flip. Not recommended.

*A reading within A, the owner's ruling: a signed variable of a pattern binding that is not simple.* 4.5.1 speaks of
identifiers, so a use of such a variable makes no edge either.
- **(i) Cut that edge too.** **Recommended.** The text as written, and what GHC does: its `mkEdges` drops the edge to
  any name with a complete signature, the binders of a pattern binding among them
  (`ghc/compiler/GHC/Tc/Gen/Bind.hs:427-450`) [read]. It needs the signed variables of such a binding assumed at their
  signatures before the groups, and the binding then checked against them, as `explicitBinding` checks a function:
  rhc's checker today unifies such a variable with an instance of its signature inside its own group
  (`infer.sml:1364-1370`), which does not hold the binding to the signature's generality once other groups have used
  it [inferred]. A few lines in each checker [inferred; not built].
- **(ii) Keep it,** as the spike does: rhc's `explicit` takes a pattern binding as explicitly typed only when it is
  simple (`infer.sml:1148-1152`; HsLint's likewise in the spike), because such a variable's type is known only after its
  group is inferred (E3, finding 5).

Two probes show GHC 9.4.7 and rhc on the reading [measured: `results/D16-probes/` (`PatCut.hs`, `PatGen.hs`,
`ghc.out`; rhc's runs in `rhc.out` and `rhc/README.md`)]: with `p :: a -> a`, `(p, q) = (\x -> x, fst k)` and
`k = (p 'c', p True)`, GHC accepts the program under `-XHaskell98` and `-XHaskell2010`, which needs the edge cut, as
`k` uses `p` at two types inside what would else be one group; with `(p, q) = (not, 'x')` under the same signature it
refuses, "Couldn't match expected type: forall a. a -> a", the check (i) needs. rhc refuses the first in both modes
(the edge is kept) and ACCEPTS the second in both, printing `(False,'x')`, which only HsLint refuses at level 2 ("the
signature a -> a is more general than the type inferred, Bool -> Bool"): the missing rigid check is a defect of the
checker at the pin, not only a cost of the reading (*Found while writing*).

**The evidence.**
- *Ruling 55's six programs* (`results/E3/r21/r21.tsv`), `--typecheck-only` at `RUNE_LINT=2`: tc196 (GHC's and jhc's
  copies) and tcfail071 (both copies) refused in 98 by R21's message and accepted in 2010; tcfail144 (both copies)
  refused in both, by its own `{-# LANGUAGE Haskell98 #-}` [measured].
- *Programs:* `relaxed1`, `relaxed2` and `relaxed3` behave in 2010 as under GHC `-XHaskell2010`
  (`run-programs3/results.tsv`, `ghc/ghc.tsv`). One test flips: `errors/dec.gen.sig.identical_where` is accepted
  (`flips/attribution.tsv`).
- *R21(b) stays and cannot fire:* an explicitly typed simple binding is a group of its own, and a non-simple pattern
  binding's signatures carry no context (R19, `infer.sml:1153-1169`); E3's `r21b.hs` prints `(2,4)` in both modes
  [measured]. The text keeps 4.5.2's sentence (T10:4751-4752), so the check stays.
- *The monomorphism restriction acts on smaller groups* (E1's N4): a program 98 refuses by Rule 1 is legal in 2010. E3's
  `relaxed3` is accepted in 2010 and refused in 98 mode at lint level 2 by HsLint.
- *GHC is no oracle for 98's grouping:* "You can't turn off RelaxedPolyRec any more"
  (`ghc/compiler/GHC/Driver/Flags.hs:116-117`), and it accepts E1's `n04b_relaxed_mr` in both modes [read; probe].
- *The specification:* the Haskell' delta became 4.5.1 word for word, and its source is Typing Haskell in Haskell
  §11.6.3, which HsLint already transliterates in the form 11.6.3 calls conformant to 98
  (`lib/language/haskell/hslint_infer.sml:1-6`; E11, finding 11). GHC, Hugs, MicroHs, jhc and Helium cut edges at
  signatures; nhc98 1.22 does not (*What the implementations do*).
- *A 98-mode defect found on the way* (`results/E3/defects/rule1-signed/`): with `f :: Num a => a -> a` and `xs = [f 1]`
  in one 98 group, the checker accepts what HsLint refuses at level 2. 2010 mode accepts it in both checkers. Not this
  decision's: *Found while writing*.

**Recommendation.** A, with (i); (i) is the owner's ruling. **The strongest argument against (i):** it is the one point
where the spike and the text part, and it is unbuilt, for a case that is rare [inferred]; (ii) is what both checkers do
today. Against A there is none: it is the text.

**What would reopen it.** The owner reading 98's 4.4.1 against 4.5.1 as contradictory, which brings in B; (i)'s rigid
check proving larger than a few lines.

### D17. Small syntax

**Question.** Three small changes of the grammar, each behind 2010 mode's setting: DoAndIfThenElse (E1's Δ5), n+k
removed (Δ4), and `:` joining ascSymbol (Δ10). Rune: none. 98 mode is unchanged (E2: R12, R15, ruling 6 are CHANGE
rows).

- **A. None: each as the text, as spiked.** **Recommended.**
  - *n+k off* (`patches/E3-01-npk.patch`): one condition at `lib/language/haskell/parser.sml:562`, 2 code lines, with a
    message that names Haskell 2010. 2010's `pat -> lpat qconop pat` (T10:3080-3089) has no `var + integer`, so `+` is
    no constructor operator there. A top-level `n + 1 = ...` still defines `(+)` in both modes (`programs/npk-top.hs`
    prints `N 3` in both, as GHC). The pattern binding `(x + 1) = e` is refused in 2010 (E1's row
    `dec.note.patbind.npk`).
  - *DoAndIfThenElse* (`patches/E3-02-doif.patch`): an optional SEMI or VSEMI before `then` and before `else`
    (`lexp -> if exp [;] then exp [;] else exp`, T10:2083, 2437), 3 code lines in `if`'s parse
    (`parser.sml:746-756`).
  - *`:` in ascSymbol* (T10:1674 against T98:2433): no change. `--dump-tokens` of `programs/colon.hs` gives the same
    114 tokens in both modes, since the erratum of December 2005 already made `--:` an operator [measured:
  `results/verify/V2/numbers-c/colon/`].
- **B. None: DoAndIfThenElse in `do` blocks only.** The semicolons are in `lexp`, so they are absorbed in every layout
  block, a `let` binding or a `case` alternative as well (E1's N13; GHC accepts both under `-XHaskell2010` and refuses
  both under `-XHaskell98`, probes `n13a_ifthen_let`, `n13b_ifthen_case`). B departs from the grammar. Rejected.
- **C. None: n+k accepted in 2010 mode with a warning,** as Hugs and jhc always accept it (*What the implementations
  do*). It changes no valid 2010 program, but it is an extension under 2010's name; NPlusKPatterns, GHC's name, turns
  98's path back on per module (D35), the spike's condition becoming a feature test [inferred]. Rejected.

**The evidence.**
- *Flips:* 21 of the 1,475 tests of tests/hs/{accept,errors,lang} change verdict or message under 2010
  (`results/E3/flips/flips.tsv`, `attribution.tsv`): n+k 10 (4 accept tests and 4 lang tests refused, 2 errors tests
  with another message), DoAndIfThenElse 3 errors tests accepted (`exp.if.do.semi`, `lay.parseerror.doif`,
  `lay.parseerror.thensamecol`), and D15's 3, D18's 3, `foreign`'s 1 and D16's 1.
- *`if` in every block.* The spike's code is in `if`'s own parse, so it reaches every block [inferred]; E3's
  `programs/doif.hs` tests `do` blocks only, so `let` and `case` blocks want a test each.
- *Not decisions, for completeness.* Fixity resolution (Δ7) needs no change: `lib/language/haskell/fixity.sml:43-109`
  is 10.6's algorithm, and DV1 and DV8 become the text (*Haskell 98 mode and the 2010 text*). Negation (E1's N2): rhc
  refuses a negation as the right operand of an operator of precedence 6 or more (`fixity.sml:84-86`), as 10.6 and
  GHC do (probes `n02a`, `n02b`, `n02d`). `foreign` is reserved in 2010 only (T10:1741): 44 code lines with its
  declaration, which is D27's and D32's (E3, finding 6).

**Recommendation.** A. **The strongest argument against:** a semicolon absorbed before `then` in any block is a
change no prose states, and a VSEMI that should end a binding could be taken by an `if` [inferred]. The grammar says
it, GHC agrees, and the tests above pin it.

**What would reopen it.** A layout case where the absorbed semicolon parses a program differently from GHC.

### D18. Hierarchical names

**Question.** 2010's `modid -> {conid .} conid` (T10:1795): "Module names are a dot-separated sequence of conids"
(T10:1806). It changes lexing, not only file names: `M.Just.id` is `id` of module `M.Just` in 2010, and `M.Just . id`
in 98 (E3, finding 11). It also answers 98's D35, which named this roadmap as what would reopen it
(haskell98.md:6630): `--dotted-names` reads dotted names in 98 mode for a program's modules only
(`src/rhc/graph.sml:230`), mapping `A.B` to `A/B.hs` (`graph.sml:50-52`), and the 98 library is flat. Rune: none.
98 mode is unchanged under A (E2: R7(c) and R34(c) are CHANGE rows).

- **A. None: 2010 mode reads every module hierarchically, the program's and the library's; `--dotted-names` stays 98
  mode's documented flag, in the unit configuration.** **Recommended.** For a program's modules, as spiked
  (`patches/E3-08-dotted.patch`): the lexer's `hierarchical` on in 2010 and a dotted import mapped to a path, 9 code
  lines, +13/-6 [measured: `diffstat.tsv`]. The library's dotted modules were not spiked: they need D23's library, with
  files laid out as a program's are, `share/rhc/haskell2010/Data/Char.hs` [inferred]. The mapping of modules to files
  "is not part of the specification" (Marlow and Wallace 2003, p. 5; E11, Part A2), so the layout is rhc's.
- **B. None: drop `--dotted-names` now that 2010 mode reads dotted names.** **Changes 98 mode:** a documented flag goes.
  The corpus's dotted 98 programs cannot move to 2010 mode instead: they import 98's flat modules (`List`, `Char`),
  which 2010 does not have, and would meet 2010's other changes, n+k off and `foreign` reserved [inferred]. Those are
  the many: with dotted names nofib parses 510 of 590 files against 268 strict, and nhc98's compiler 144 of 147 against
  23 (haskell98.md:6619-6624). Rejected.
- **C. None: flat names in 2010 mode unless a flag asks.** Against the text. Rejected.

**The evidence.**
- *Programs* (`results/E3/programs/dotted2010.tsv`): `import Data.Thing` from `Data/Thing.hs` is refused in 98 mode,
  and runs in 2010 mode and in 98 mode under `--dotted-names` [measured].
- *Flips:* `accept/lex.qual.twodots` is refused under 2010, and `errors/lex.qual.modname` and `errors/mod.name.modid`
  are refused with other messages (`flips/attribution.tsv`).
- *The store-key defect.* Confirmed at the pin: a unit compiled without `--dotted-names` is taken by a compile with
  it, which prints `Just 'x'` where `--no-store` refuses the program (`results/E3/dotted/repro.out`) [measured]. Fixed
  after the pin: "`--dotted-names`, by which a text is read otherwise too, is in the units' configuration" (issue 27 of
  `docs/plans/build-cache-issues.md` on branch `haskell98`, past `75ed95861`) [read]. A module's edition must reach
  the unit configuration the same way (D9, D10).
- *The literature.* The 2003 addendum "steals one extremely rare construction from Haskell 98": `A.B.C.D` was a
  composition and is a qualified name (Marlow and Wallace 2003, p. 5; E11, Part A2).
- *What 2010 leaves as 98* (E1's N14): `A.B.C` lexes by context, and `module M` in an export list names an alias,
  as rhc's R30 reads it; GHC agrees (probes `n14b_export_module_alias`, `n14c_export_module_name_not_alias`).
- *The flag's spelling and place among rhc's options:* E4 folds it into the language record as a per-module feature
  (HierarchicalModules, an rhc name: GHC has none), set by `--dotted-names` as before in 98 mode and on in 2010; it then
  sits in the unit key with every other feature (`results/E4/README.md`; D8).

**Recommendation.** A. **The strongest argument against:** rhc keeps two readings of a dotted name, 98's under a flag
and 2010's by the text, each a mode to keep working, and the flag's is not the 98 Report's (98's D35). The flag is
small, and the corpus's largest targets need it.

**What would reopen it.** The owner retiring the corpus's dotted 98 programs, which brings in B.

### D19. Chapter 12's pragmas

**Question.** What does rhc do with INLINE, NOINLINE and SPECIALIZE in 2010 mode? They are `decl`s (12.1, 12.2), as in
98's chapter 11: E1 maps each of their rows to 98's as the same (`results/E1/clauses2010.tsv`, rows `prag.inline`,
`prag.noinline`, `prag.specialize` and their meanings). Chapter 12 says "An implementation is not required to respect
any pragma, although pragmas that are not recognised by the implementation should be ignored" (T10:10927-10928).
rhc lexes every `{-#` comment as trivia (`lib/language/haskell/lexer.sml:112`), which only the exact printer reads, and
98's rows are Supported (`tests/hs/conformance.tsv:2793-2802`). What chapter 12 adds is LANGUAGE (D4 to D7).

- **A. None: as in 98 mode, trivia with no meaning.** **Recommended.** 0 lines. They are hints with no observable
  meaning: "Nothing to meet (ruling 49)" (`conformance.tsv:2799`, `:2801`).
- **B. Small, rhc only: honour INLINE and NOINLINE in the simplifier.** The parser would keep the pragma as a
  declaration (it never sees it now), the renamer resolve its `qvars`, and the inliner read it; about 100 lines
  [inferred, not sized]. Worth it only on a measured need: rhc's simplifier inlines by its own rule (98's M23).
- **C. Small, rhc only: honour SPECIALIZE.** rhc already specialises at known dictionaries, with fuel: 3,000 copies in
  all, 24 of one function (`lib/language/haskell/coresimplify_spec.sml:1-21`, `:28-30`). SPECIALIZE would force a copy
  where the fuel stops or the dictionary is unknown, and across modules it needs the copy in the interface. Later.
- **D. None: check them,** refusing an INLINE of a name not in scope or a SPECIALIZE at a type that is no instance of
  the signature, as GHC does. The text asks for no check, and D would refuse programs it lets an implementation ignore
  [inferred]. Rejected.

**The evidence.** GHC accepts INLINE and SPECIALIZE in a `where` block, as `decl`s may stand there (E1's N5, probe
`n05f_inline_local`, `(3,2)`); under A rhc accepts them anywhere, as its row `prag.unknown` says of every pragma
(`conformance.tsv:2795`). Other compilers' pragmas (UNPACK, OPTIONS_GHC and the rest) are ignored as unrecognised;
OPTIONS_GHC's `-X` flags are D6's.

**Recommendation.** A. **The strongest argument against:** library writers and the corpus write INLINE and SPECIALIZE
for speed, and under A rhc's own heuristics decide alone. No measurement shows that costs anything, and 98's D49
covers SPECIALIZE's common case.

**What would reopen it.** A corpus program where an ignored INLINE or SPECIALIZE costs a measured share of `--count`.

### D20. Defaulting's standard classes

**Question.** 4.3.4 defaults a variable only if "all of these classes are defined in the Prelude or a standard
library" (T10:4368), 98's words. The 2010 library's classes beyond the Prelude are MonadPlus (T10:11097), Ix
(T10:12501), Bits, with Num as superclass (T10:11629), and Storable (T10:15819); 98's were Ix, MonadPlus, RandomGen and
Random (E9). rhc's test is a prefix of the class's identity: `"thaskell98:"` in the checker
(`lib/language/haskell/infer.sml:2010`) and `"haskell98:"` in HsLint (`lib/language/haskell/hslint_env.sml:604`); a
class is numeric by its superclasses (`infer.sml:346-348`), so Bits counts. Rune: none. 98 mode keeps its set.

- **A. None: the prefix from the library's descriptor** (D1), so each edition's standard classes are its library's.
  **Recommended.** A few lines at the two sites; they are among the places D1 rids of a literal "haskell98" (plan,
  fact 5) [inferred].
- **B. None: a list of class names per edition.** A second record of the library beside the library, and a class the
  library gains and the list forgets is silently not standard [inferred].
- **C. None: GHC's list** (`ghc/compiler/GHC/Builtin/Names.hs:2743-2755`): neither Bits nor Storable, and Monoid,
  IsString, Foldable and others the Report does not have. Against the text (E1's N9). Rejected.

**The evidence.** Under A, `print (shiftL 1 3 .|. 1)` defaults to Integer and prints 9 [inferred from 4.3.4 and
T10:11629]; GHC refuses it as ambiguous (probe `n09a_default_bits`), since its Bits has no Num superclass, a departure
it documents (`ghc/docs/users_guide/bugs.rst:370-372`). A variable with `(Num a, Storable a)` defaults to Double,
since Storable has no Integer instance (T10:15886-15900) [inferred]. So GHC is no oracle here, and the tests are rhc's
own, from the text.

**Recommendation.** A. **The strongest argument against:** rhc then accepts 2010 programs GHC refuses. The text is
plain, and 98's D38 offers no ground to depart from it.

**What would reopen it.** None foreseen: the library is the set, and A reads it.

### Numbers

### D21. `Int` under 2010

**Question.** What does `Int` do past its range in 2010 mode? 6.4, unchanged from 98: "The results of exceptional
conditions (such as overflow or underflow) on the fixed-precision numeric types are undefined; an implementation may
choose error (_|_, semantically), a truncated value, or a special value such as infinity, indefinite, etc."
(T10:6239-6241). Chapter 18: "This module provides signed integer types of unspecified width (Int) and fixed widths
(Int8, Int16, Int32 and Int64). All arithmetic is performed modulo 2^n, where n is the number of bits in the type."
(T10:12381-12382). rhc's `Int` is the VM's 63-bit immediate on the checked primitives, an overflow an error (98's D22,
`share/rhc/haskell98/overlay.tsv:24`; `int_add` "raises Overflow", `src/isa/prims.sml:26-41`). **The owner's call.**

Two readings, both stated (E1's N6; *What the 2010 Report says*):
- **a contradiction** (E1): 6.4 allows an error and Data.Int requires wrapping; Data.Int's prose is `base`'s
  documentation, where `Int` wraps, and may name `Int` loosely; on this reading 2010 settles nothing;
- **a narrowing** (the lead's): chapter 18 is the more specific text and picks one of the behaviours 6.4 allows, a
  truncated value; on this reading 98's R54 passes all three parts of E2's test and is an ALIGN.

Options:
- **A. None: checked `Int` in 2010 mode too.** 0 lines. On the narrowing reading a departure from the text, which
  98's D38 admits on the ground "contradictory" only under the first reading; arguable.
- **B. `Int` wraps in 2010 mode only.** **Recommended.** 98 mode unchanged. Two ways:
  - **B1. None in Rune: over the word primitives,** `word_from_int`, `word_add`, `word_to_int_x`, none of which raises
    (`src/isa/prims.sml:61-99`). 98's D22 measured the cost at tier 2: +7 machine instructions on an add (19.07 to
    26.07, +37% of that loop) and +3 on a mul-mod loop (haskell98.md:6262).
  - **B2. Small in Rune: wrapping `int` primitives:** a line each in `src/isa/prims.sml`, C bodies, cases in
    `runtime/register/fastprim.h` and the JIT, and a new instruction-set fingerprint (98's D22 C, haskell98.md:6263;
    unbuilt).
- **C. `Int` wraps in both modes.** **Changes 98 mode:** every overflow test flips (`def.pick.first`, R81's and R93's
  rows), and ruling 11's compatibility layer for wrapping bit tricks goes (*Haskell 98 mode and the 2010 text*, R54).

**What B means in rhc** [inferred, from D1, D2 and the overlay entry]:
- *Per program, not per module.* `Int`'s arithmetic is the library's Prelude instance (`ov.prelude.int`), and the
  library is the program's (D1). So a 98 module in a 2010 program meets wrapping `Int`, and a module that names
  `Haskell2010` in a 98 program meets checked `Int` (D2).
- *Which operations wrap:* `+`, `-`, `*`, `negate`, `abs` and `fromInteger`, which today raises past the range (R81).
  By the text ``minBound `quot` (-1)`` and ``minBound `div` (-1)`` give `minBound` and the remainders 0, where `base`
  4.3 raises `overflowError` for Int and every IntN (`GHC/Real.lhs:246-254`, `GHC/Int.hs:89-92`; *The libraries*): a
  reading for the owner with this decision. Division by zero stays an error, and `succ`, `pred` and `toEnum` past
  the bounds keep their errors by the bounded rule (6.3.4; Data.Int extends it to every Int type, T10:12385-12387).
- *No oracle shares the answer.* GHC wraps at 64 bits and rhc would wrap at 63, so a program that leaves 63 bits
  prints a third number, as 98's D22 found of the corpus's hashes (haskell98.md:6267, `:6275`). The corpus's `hash`
  stays a compatibility function over Integer under every option.
- *Cheap eagerness.* A wrapping `+`, `-` or `*` cannot raise, so 98's D51 could speculate it in 2010 programs, which a
  checked one forbids (haskell98.md:6277); unmeasured, it may win back part of B1's cost.
- *The 2010 table.* R81's and R93's rows become 2010 rows of their own: `2^70 :: Int` prints 0 under wrapping, which
  still shows that Int was picked [inferred].

**A reading in chapter 18, with this decision** (E1's N6): "Right and left shifts by amounts greater than or equal to
the width of the type result in either zero or -1, depending on the sign of the value being shifted" (T10:12388-12389)
is right for right shifts; a left shift of a negative value by the width is 0, which GHC gives (probe
`n06b_shift_width`, `shiftL (-1 :: Int8) 8` is 0). Recommended: 0, arithmetic over the sentence, a reading on 98's
D38 ground "wrong".

**Recommendation.** B, B1 first, B2 if the measured cost on the corpus warrants a Rune change: it follows the more
specific text and leaves 98 mode as decided. **The strongest argument against:** 98's D22 chose a visible stop over a
silent third answer, and B gives the third answer whenever a 2010 program leaves 63 bits, at +37% on an add loop, with
the default edition (D3); A keeps one `Int` in both modes and a deviation the first reading supports.

**What would reopen it.** The owner reading chapter 18 as contradictory, which brings in A; a measurement of B1 on the
corpus, which brings in B2; the owner aligning R54, which is C.

### D22. IntN, WordN and Bits

**Question.** What are Int8 to Int64, Word, Word8 to Word64 and the Bits instances at run time, and what do they need
from Rune? rhc's Core has no Word, IntN or bit primitive (`lib/language/haskell/coreprim.sml:47-117`). The VM has a
63-bit `word` with wrapping arithmetic and bit operations, `word_andb` to `word_lsr`, and the reinterpreting
conversions `word_from_int` and `word_to_int_x` (`src/isa/prims.sml:61-99`); `word64_*` modulo 2^64
(`:717-771`); `int64_*`, checked, for signed comparison and division (`:682-716`). Integer's bit primitives are GMP's:
`intinf_binary`'s and, or and xor and `intinf_shift` (`:839-844`) stop the VM when it is built without GMP
(`runtime/intinf.c:569-576`).

- **A. None: Core types over what the VM has.** **Recommended.**
  - Word is the VM's `word`, 63 bits, "with the same size as Int" (T10:13792); Word64 is `word64`; Int64 is `word64`
    for arithmetic, modulo 2^64 as chapter 18 says, with `int64_*` for comparison and division; Int8 to Int32 and Word8
    to Word32 are Int with narrowing after each operation.
  - Bits on Int over the word primitives; an arithmetic right shift, which `word` lacks (only `word64_asr`,
    `src/isa/prims.sml:752`), by floor division by 2^i or `complement (shiftR (complement x) i)` [inferred]; shifts at
    or past the width guarded in Haskell, 0 or -1 for Int (D21's reading) and 0 for Word (T10:13787), whatever
    `word_lsl` does there (not checked).
  - Integer's bits in `base` 4.3's portable Haskell over `quot`, `rem` and multiplication by powers of two
    (`Data/Bits.hs:284-302`, BSD).
  - rhc: about 150 to 300 lines of SML across CorePrim, CoreToMid, CoreInterp and CoreLint [inferred: Integer, the
    nearest precedent, is named at 13 places in 8 files of `lib/language/haskell`; E9]. Library code: Data.Int about
    280, Data.Word about 370, Data.Bits about 90 code lines (`results/E9/modules.tsv`) [inferred, calibrated on Hugs:
    `Hugs/Int.hs` and `Hugs/Word.hs` are 268 and 359 code lines, 281 and 370 with `base`'s wrappers, W2's recount].
- **B. Small: `int` bit primitives in Rune,** and the wrapping `int` primitives of D21's B2, so that Int's bits need no
  reinterpretation. Fewer instructions per operation [inferred], a new fingerprint. Only if measured.
- **C. Medium: GMP-free Integer bit primitives in Rune.** Integer's bits become primitive in every build. `base`'s
  portable shift is a multiplication or a division by `2^i`, so a long run of bit operations on a large Integer is
  slower than GMP's [inferred]. Only if a program shows it.
- **D. None: IntN and WordN as newtypes over Integer, narrowed after each operation.** Simplest, and every operation
  allocates. Rejected.

**The evidence.** E9 found every operation the 2010 text names reachable over the primitives above, with no Rune
change (`results/E9/modules.md`, *Primitives*). E10's prototype, whose Word64 was a newtype of Int, overflowed on
2^64-1 (`results/E10/gaps.tsv`, G30), which A's Core types remove. GHC gives 64-bit Int and Word (probe
`n06c_word_size`); rhc's 63 bits are implementation-defined ("signed integer types of unspecified width (Int)",
T10:12381), so `bitSize (0 :: Int)` is 63 [inferred] and differs from GHC's 64. Int64 values past 63 bits are boxed on
the VM ("an immediate, or a box past 63 bits", `src/isa/prims.sml:682`) [read].

**Recommendation.** A. **The strongest argument against:** three primitives for one Int bit operation, as B1 is for
D21, and a 63-bit Word that no other implementation has; B removes the first at a fingerprint's cost, and nothing
removes the second short of 98's rejected 64-bit Int (98's D22 D).

**What would reopen it.** A measured cost of the reinterpretations (B); a program heavy in Integer bits (C).

### Libraries

### D23. The layout of `share/rhc/haskell2010`

**Question.** What shape does the 2010 library take, given that its Prelude's printed code imports two modules
that print none? Prelude imports PreludeList, PreludeText, PreludeIO and Data.Ratio (T10:7538-7543); PreludeList imports
Data.Char (T10:8422); PreludeText imports Data.Char and Numeric (T10:8867-8870); every module imports the Prelude. So
the printed graph alone is one SCC of 7 (`results/E9/layout-graphs.txt`, case 3). Chapter 9's disclaimers are 98's but
for names, "an implementation is free to import more, or less, of the Library modules" (T10:7470-7476), so every layout
below is allowed. 98's D36 decided the literal layout for 98 (haskell98.md:6677). Rune: none under every option. *The
libraries* has the detail; this decision takes it.

- **A. The literal layout, the cycle 9.** **Recommended.**
  - The printed modules literal, as 98's D36: the Prelude's four, Data.Array, Data.Complex, Data.Maybe and Data.Ratio,
    each a pristine with a listed overlay (98's D37). 2010 needs three entries 98 did not: Data.Array's header
    `module Array (` (T10:11476), Data.Ratio's missing parenthesis (T10:13723-13730), and Data.Maybe's `maybe`, which
    must re-export the Prelude's as 98's did, since hiding the Prelude's breaks every unqualified user
    (`results/E9/probes/maybeprobe/`).
  - The 26 codeless modules carry a provenance record instead of a pristine ("98's Char with these changes", "`base`
    4.3's `Data/List.hs:750-780`"), as no overlay can stand against a text that does not exist.
  - The cycle 9: the printed 7 with PreludeEnum and PreludeRuntime. Data.Char and Numeric, whose code is rhc's, drop
    98's Array tables: Char's 33 control-character names (`share/rhc/haskell98/Char.hs:19`, `:136`) become a list, and
    Numeric's cache of 1,101 powers of two (`Numeric.hs:19`, `:65-75`) an `Arr` of PreludeRuntime's. And `interact`'s
    and `getLine`'s names, BufferMode, `hSetBuffering`, `stdin`, `stdout` and `hGetLine`, move from IO's code
    (`IO.hs:51-59`, `:74-81`, `:102-103`) into PreludeRuntime, re-exported by System.IO; without that move PreludeIO
    imports System.IO (`PreludeIO.hs:17`), which brings Data.Ix, and the cycle is 11 [inferred from case 5's edges].
    A few lines each [inferred].
- **A14. The literal layout with 98's code as it stands, the cycle 14:** Data.Array, Data.Ix, Data.List, Data.Maybe
  and System.IO join (case 4); 12 if Data.Array's dead `import Data.List( (\\) )` (T10:11481) goes [inferred]. 0 new
  lines, and the size of rhc's 98 unit today (case 2), which the joined checker already compiles.
- **B. The merged layout** (98's D36 B, Hugs's): one internal module and thin public ones.
- **C. A layered layout** (98's D36 C, GHC's): the cycle broken, at the cost 98 measured of moving 59 definitions
  beneath the Prelude (haskell98.md:6652); not sized for 2010.

**The evidence.**
- *Sizes:* the 30 modules are about 4,660 code lines, 953 carried from rhc's 98 library, 236 printed by the Report
  and about 3,470 new, 2,500 of those Foreign.* (`results/E9/estimate-totals.txt`, `modules.tsv`; *The libraries*,
  *The size*). Beside them the Prelude's family carries 1,530 code lines and PreludeRuntime 556 plus about 55.
- *What a program meets.* Under 9, Data.Char, Numeric and Data.Ratio are in every program's closure; under 14, five
  more. rhc already gives each library module an identity of its own (`src/rhc/library.sml:39-40`, `:49`), tested
  with a program's own `Char` (`tests/hs/names/char/`); 2010 needs only the prefix from the descriptor (D1). Two driver
  places are 98's: UnicodePrims' exports (`library.sml:65-67`), which D26 extends, and derived Ix's names, resolved in
  `Ix` (`src/rhc/names.sml:155`), which 2010 calls Data.Ix.
- *The text's code.* The Prelude's comes from the HTML (E1, `results/E1/prelude/prelude2010/`), as the PDF's columns
  break; the four library modules from the `haskell2010` package's `$code`, which agrees with the HTML token for
  token (W2's comparison; no result file).
- *The library's normalisation* (`elidedData` and its kin, `src/rhc/library.sml:115-139`) carries over, D15 leaving it.

**Recommendation.** A with the cycle 9. **The strongest argument against:** A14 costs nothing and compiles today, and
9 changes code that rhc's 98 mode carries verbatim, so the two directories diverge in Data.Char and Numeric from the
start. But that code is rhc's, not the Report's, the change is a few lines, and a smaller cycle puts five fewer modules
in every program's closure and in every Prelude rebuild. The layout is the owner's, as 98's D36 was.

**What would reopen it.** The joined checker meeting the 2010 cycle late, which brings in B as 98's D36's fallback
did; the owner preferring 98's code unchanged (A14).

### D24. Sources and licences

**Question.** Where does the code of the 26 codeless modules come from, what is the source of truth where the prose
is thin, and under what terms is it shipped? The prose is `base`'s documentation of 2010: of T10's 1,078 library prose
lines of eight or more words, 958 (88.9%) are word for word in `base` 4.3.0.0 and 4.3.1.0, 905 (84.0%) in 4.2.0.2, 215
(19.9%) in the `haskell2010` package; 34 are in 4.3 alone, among them `isSpace`'s sentence (T10:11833), and 6 in 4.2
alone (`results/E9/provenance-summary.txt`). Rune: none.

- **A. 98's code, the Report's code, and `base` 4.3 for the rest.** **Recommended.**
  - 98's code (rhc's 98 library, under the 98 Report's notice) for the nine continuing modules: Control.Monad,
    Data.Char, Data.Ix, Data.List, Numeric, System.Environment, System.Exit, System.IO, System.IO.Error.
  - The 2010 Report's printed code for the Prelude and the four printed modules (D23).
  - `base` 4.3's portable branches (BSD) for the new names, Integer's bits (D22) and Foreign.*'s support code; Hugs
    only as calibration of sizes.
  - Where the prose is silent, `base` 4.3 is the source of truth, not 4.2; where it says something `base` does not do,
    the Report is (the table in *The libraries*, *Where the prose is thin or disagrees with base*: allocation failure,
    `isAlphaNum`, and the rest).
- **B. New code from the prose alone, no `base` code.** The licence is simpler, but `base` 4.3 is still the reading of
  thin prose, and some names are fixed only by the order of their examples (`subsequences`, `permutations`,
  T10:12707, 12712), so their code must reproduce `base`'s order anyway.
- **C. jhc's `lib/haskell2010` (MIT) or MicroHs's library (Apache-2.0).** jhc's rests on its own primitives and
  MicroHs's on today's `base` interface (`results/E9/sources.tsv`): a poor fit.
- **D. `base` 4.2 as the source of truth.** The Report's prose matches 4.3 better (above).

*The licence.* Every source is licensed, so no PROVENANCE file is needed under the owner's rules of 2026-11-10
(haskell98.md:66). `share/rhc/haskell2010/LICENSE` carries the 2010 Report's notice ("Modified versions of this Report
may also be copied and distributed for any purpose, provided that the modified version is clearly presented as such,
and that it does not claim to be a definition of the language Haskell 2010", T10:7-11), the 98 notice for the code
carried, and `base`'s BSD text where `base` code is vendored: one LICENSE, the same in all five `base` tarballs and in
Hugs's `packages/base` (md5 `61ec3aa7`). The top-level LICENSE stays as it is (98's D37, haskell98.md:6700).

**Recommendation.** A. **The strongest argument against:** three licences in one directory, and `base` code vendored
for names a few lines long. B saves the third licence only by writing that code again against the same `base`.

**What would reopen it.** Legal advice on the Report's notice or on what bytecode linking these libraries owes, open
since 98's D37.

### D25. Shared with haskell98, or copied

**Question.** The brief: "please store the haskell 2010 prelude under share/rhc/haskell2010 to keep it distinct from
share/rhc/haskell98". Of `share/rhc/haskell98`'s 5,240 lines, 4,760 (90.8%) are in modules that continue into 2010
(`results/E9/sharing.tsv`, `sharing-totals.txt`), but no file derived from a Report can be the same bytes in both,
since every one names modules 2010 renames and three printed modules differ in code too. Only rhc's own runtime layer
could be one file: PreludeRuntime and PreludeEnum, 852 lines, which must grow for 2010 (IOErrorType, the new
primitives, under D23 the IO names). Rune: none.

- **A. Copy everything.** **Recommended.** `share/rhc/haskell2010` holds its own copy, PreludeRuntime included:
  distinct, as the brief asks. About 4,700 lines duplicated, and a fix to shared logic made twice. 98's library has
  its roadmap behind it (*At the close*, haskell98.md:8381, at `75ed95861`), so such fixes should be rare: none of
  the 24 commits on `haskell98` past the pin touches `share/rhc/haskell98` (`git diff --stat`, 2026-11-21) [read].
- **B. Share the runtime layer, copy the rest.** One PreludeRuntime both libraries name: a third directory for the
  descriptor (D1), and 98's library and snapshot move whenever 2010 adds to the layer, unless it is split by edition.
- **C. 2010 as overlays on 98.** Not distinct: ruled out by the brief's word.

**The evidence.** E9's sharing tables above. Under A, 98's library files are untouched by 2010's work, which is what
98's "bytes held" checks need; whether a copy leaves 98's snapshot entry for entry the same is E4's: with the library a
descriptor and 2010's a copy, 98's snapshot keeps all 68 entries and keys equal and its size (41,334,255 bytes), only
rhc's identity differing, when both are built at one `--share` path and one Main path
(`results/E4/snapshot-98-compare.txt`); build 6 matches it in the library's 32 entries of each match order, Main
differing by its path and the two one-entry configurations keeping their bytes under another key
(`results/E4/snapshot-98-compare-b6.txt`).

**Recommendation.** A. **The strongest argument against:** two copies of the handle and Read code, kept in step by
tests alone. B shares only the 852 runtime lines, and pays for it in 98's stability.

**What would reopen it.** A run of fixes that must be made in both copies.

### D26. Unicode

**Question.** How does 2010 mode answer Data.Char's predicates, and at which Unicode version? 2010 changes three of
98's (*The libraries*, *Data.Char and Unicode*): `isUpper` "Selects upper-case or title-case alphabetic Unicode
characters" (T10:11844), Lu and Lt, where rhc's 98 mode takes Lu, Lt, Lm and Lo by chapter 19 (R38,
`lib/language/haskell/coreruntime.sml:622-625`); `isAlpha` is "equivalent to Data.Char.isLetter" (T10:11848), the same
answers as rhc's 98 `isUpper c || isLower c` (`share/rhc/haskell98/Char.hs:42`) but no longer that definition;
`isSpace` "Returns True for any Unicode space character, and the control characters \t, \n, \r, \f, \v." (T10:11833),
where 98 mode takes the seven Latin-1 white characters (`Char.hs:35`). `isSpace` reaches the Prelude's `words` and
`lex` (T10:8422, 8867). 98 mode keeps its answers (D13c, D13d, the owner's for 98). Rune: none, but for (ii) below.

*How the predicates are computed:*
- **A. None: one category primitive, the predicates in Haskell over `generalCategory`.** **Recommended.** The runtime
  already computes the category, numbered "0 Lu, 1 Ll, ... 29 Cn" (`coreruntime.sml:547-560`; `rtCategoryOf` at
  `:618`), in the order of `lib/unicode`'s `CodePoint.category` (`lib/unicode/code_point_sig.sml:34-64`), which is the
  order 2010 gives GeneralCategory's 30 constructors, "in the order they are listed in the Unicode standard"
  (T10:12009). So `generalCategory` is `toEnum` of one more name in UnicodePrims (`src/rhc/library.sml:65-67`), and
  every predicate is Haskell, as `base`'s are (`Data/Char.hs:136-141` and on). Data.Char is about 94 new code lines
  beside 117 carried (`results/E9/modules.tsv`). `toTitle` needs one more table beside `rtUpper` and `rtLower`
  (`coreruntime.sml:774-775`), from `lib/unicode`'s `toTitle` (`code_point_sig.sml:137-146`).
- **B. None: a primitive per predicate,** as 98's `primUnicodeIs*` (`coreruntime.sml:622-640`). Faster per call, with no
  constructor built [inferred], and more of rhc's own runtime text. Only if measured: `isSpace` is in `words` and `lex`.

*The readings:*
- **`isSpace`: (i) general category Zs and the five controls.** **Recommended.** `base` 4.3's reading
  (`GHC/Unicode.hs:67-78`, `cbits/WCsubst.c:4116`) and GHC's answer (probe `n07a_isspace`: true of U+00A0, U+1680,
  U+2003, U+202F, U+3000; false of U+0085, U+2028, U+2029). rhc's lexer already reads the Report's `uniWhite` as Zs
  (`lib/language/haskell/char.sml:23-34`), so the two agree. **(ii) Unicode's White_Space property,** which adds U+0085,
  U+2028 and U+2029: a small Rune change, a White_Space table `lib/unicode` lacks, and the lexer would then differ from
  `isSpace` unless it moved too [inferred].
- **`isAlphaNum`: the prose,** "alphabetic or numeric digit" (T10:11851), letters and numbers as rhc's 98 mode answers
  (`coreruntime.sml:630-636`). **Recommended,** over `base`'s, which adds the marks (`cbits/WCsubst.c:4123-4125`): the
  Report is the authority (D24's rule).
- **The version: implementation-defined,** `lib/unicode`'s 18.0.0 (`lib/unicode/code_point_data.sml:16`), as 98 mode
  (98's D21). 2010 names none (T10:16864) and expects new versions to be used "as they are made available"
  (T10:1543); GHC 9.4.7 answers as 14.0 (probe `n08a_unicode_version`), so the tests that pin these answers use
  characters whose category has not moved between 14.0 and 18.0.0, as 98's R153 rows do since 3.0 [inferred rule].

**Recommendation.** A, with (i), the prose's `isAlphaNum` and 18.0.0. **The strongest argument against:** `isSpace` in
Haskell over a 30-constructor type sits in `words` and `lex`, which every `read` reaches, where B is one primitive call;
A is the simpler runtime, and `rtCategory` already answers Latin-1 from a table of its own (`coreruntime.sml:552-553`),
so only characters past U+00FF pay the search [read].

**What would reopen it.** A measured cost of the predicates in `read`-heavy programs, which brings in B; the owner
reading "Unicode space character" as White_Space, which is (ii).

### FFI

### D27. Calling conventions and kinds of import

**Question.** Which calling conventions and which kinds of import does rhc implement, and what must Rune change for
them? 8.4.1: "Any implementation of the Haskell FFI must at least implement the C calling convention denoted by ccall.
All other calling conventions are optional." (T10:6828-6829). Under `ccall` an entity is a static function or address,
`" [static] [chname] [&] [cid] "`, a `" dynamic "` stub or a `" wrapper "` stub (8.5.1, T10:7036-7038). E10 ran all
four through a family of Core primitives over the VM's `foreign` and `foreign_callback` (`runtime/prims.def:470-471`);
the detail is in *The foreign function interface*, *What the prototype showed*. Three of 8.5.1's requirements fail on
Rune as it is (E10's G02, G06, G07). 98 mode is unchanged under every option: `foreign` is reserved in 2010 mode only
(T10:1741; `patches/E3-06-foreign.patch`), and in 98 mode a `foreign import` stays a parse error at `import`
(`results/E3/run-programs3/results.tsv`, `foreign1`). A module that names `Haskell2010` in a 98 program would read
foreign declarations by D2, over the basic types the Prelude exports, with no Foreign module to import [inferred].

*The kinds:*
- **A. Small: all four kinds through a Core primitive family, with three Rune changes.** **Recommended.**
  - *G02, the program's own namespace.* A header has "no impact on the semantics of a foreign call" (T10:7134), so a
    static import names no library. Rune opens libraries by name only (`runtime/sys/sys_posix.c:1784`). The change: an
    operation for the program's own namespace (`dlopen(NULL)` or `RTLD_DEFAULT` on POSIX, the loaded modules on
    Windows), C ~30 in the posix, Windows and none layers, with tests; and rhc options naming libraries, ~40 (their
    spelling an rhc option, not a LANGUAGE name: D8 keeps compile modes out of the language record) [inferred, not
    built].
  - *G06, an `&`-imported C variable.* It "can be read and updated using the routines provided by the module
    Foreign.Storable" (T10:7071-7072). Today a SYMBOL identity is refused, "resource is not foreign memory"
    (`runtime/foreign.c:301-305`). The change: `region()` takes a SYMBOL, of unknown extent as a returned pointer is
    (`:693`); C ~5, tests ~30, `docs/ffi/runtime.md` [inferred]. `gaps.tsv` files G06 under D29; it is taken here, with
    the kind of import it serves.
  - *G07, `dynamic` of any FunPtr.* The stub "converts any pointer to a C function" (T10:7112). Today `prepare` takes a
    SYMBOL alone (`runtime/foreign.c:347-350`). The change: prepare a POINTER or CALLBACK identity too, the prepared
    call retaining it; C ~10, tests ~40 [inferred].
  - rhc: the prototype is 846 lines added (`patches/E10-ffi-prototype.patch`); D32 gives the shape it takes.
- **B. None: the four kinds over Rune as it is.** The prototype's state. A static import resolves only through
  `dlopen("")`, which reaches the program's namespace on glibc and is untried elsewhere [inferred]; no `&` variable can
  be read, the chapter's own `foreign import ccall "errno.h &errno" errno :: Ptr CInt` (T10:7103) among them; and
  `dynamic` of a `wrapper`'s FunPtr, or of a pointer C returned, is refused. Three requirements of 8.5.1 unmet, none on
  a ground of 98's D38. Rejected.

*`stdcall` and the other conventions* (the owner's pick):
- **(i) None: ABI 1 where the target has it, refused at compile time elsewhere.** **Recommended.** RuneForeign's "ABI 1
  is Windows x86 stdcall" (`lib/basis/rune_foreign_sig.sml:76`), and `target ()` reports whether the target has it
  (`:33`, `:37`). Elsewhere rhc refuses the declaration with D7's "not supported by rhc", which "All other calling
  conventions are optional" allows; rhc ~10 (G26) [inferred]. nhc98 lists `stdcall` among its "Unsupported calling
  conventions" (`nhc98/docs/ffi.html:40-41`) [read].
- **(ii) None: read as `ccall` off Windows, with a warning,** as GHC does: "if the stdcall calling convention is used
  then it will be treated as ccall" (`ghc/docs/users_guide/using-warnings.rst:738-740`) [read]. The two "only differ
  in the generated code" (8.5.2, T10:7180-7181), so where a target has one convention a program means the same either
  way [inferred].
- `cplusplus`, `jvm` and `dotnet` are refused under either: "Only the semantics of the calling conventions ccall and
  stdcall are defined herein" (T10:6833), and implementations "need not implement all of these conventions"
  (T10:6830).

*`safe` and `unsafe`* are read and ignored, since every call allows callbacks (G31; `Basic.hs` imports `rand`
`unsafe`) [measured].

**The evidence.**
- *All four kinds ran* (`results/E10/progs/Basic.hs`) [measured]: `c_sin 0.5` gives 0.479425538604203; qsort with a
  `wrapper` comparator gives `[1,2,3,5,7,8,9]`; an `&qsort` import called through a `dynamic` stub gives
  `[9,8,7,5,3,2,1]`. The same stdout at -O0, -O1, -O2 and on the stack target, and on a second run of each binary
  (`results/E10/matrix.tsv`, md5 `ae67cf1b`); the same compiled a unit at a time (`results/E10/out/units.log`).
- *The three gaps* (`results/E10/out/Gaps.-O1.stdout`) [measured]: "a dynamic call of a wrapper's FunPtr: IOError:
  foreign: invalid foreign call specification"; `optind` and `&errno`: "resource is not foreign memory"; `atexit`:
  "undefined symbol", since glibc keeps it in `libc_nonshared.a`, not `libc.so.6` (W4, read with `nm`; no result
  file). `dlopen("")` finds `sin` and `qsort` (`results/E10/probe/global.out`).
- *`stdcall` on x86-64 Linux:* "calling convention unavailable on this target" (`Gaps.-O1.stdout`) [measured]; h10-v's
  libffi reports `stdcall false` (`results/E10/probe/avail.out`).
- *What the grammar leaves out* (E1's N1(b)): `chname -> {chchar} . h` with `chchar -> letter | ascSymbol<&>`
  (T10:6742-6755) admits no digit, so "x86_64.h" is no header by the letter; GHC accepts it (probe
  `n01b_ffi_header_digits`). A header has no semantics (T10:7134), so D32's entity parser takes any header name ending
  in `.h`, a reading on D38's ground "wrong" for *Found while writing* [inferred].

**Recommendation.** A, with (i). **The strongest argument against:** A's three changes are to Rune's C for rhc, and the
gaps they close could instead be documented. They are each small, tested and listed (*Every change to Rune*), and
without them the chapter's own `errno` example and `dynamic` of a `wrapper` fail. Against (i): a program that names
`stdcall` and runs under GHC on Linux is refused by rhc; (ii) accepts it with one more silent reinterpretation.

**What would reopen it.** G02's operation not reaching the program's symbols on some target, which brings in a symbol
table at link time; programs in the corpus or the GHC FFI tests naming `stdcall` off Windows, which brings in (ii).

### D28. `foreign export` and HsFFI.h

**Question.** 8.4.4 lets a module make a Haskell value a C entity: `foreign export ccall "addInt" (+) :: Int -> Int ->
Int` (T10:6974-6977), and "an external invocation of the external entity e is translated into evaluation of v"
(T10:6971-6972). 8.7 requires a header HsFFI.h with Tables 8.2 and 8.3 and six functions, `hs_init`, `hs_exit`,
`hs_set_argv`, `hs_perform_gc`, `hs_free_stable_ptr` and `hs_free_fun_ptr` (T10:7418-7428), "useful for mixed language
programs, where the main application is implemented in a foreign language" (T10:7429-7430). Rune has neither part: a
bytecode program run by `runevm` has no link step and exports no symbol (E10's G24), `runtime/main.c`'s `main` is the
VM's only entry from C (G25), and `runeopt`, the native back end, targets Linux on x86-64 alone (`docs/native.md:3-4`).
**The owner's call, and only by the owner's explicit word:** leaving out a feature the text requires is none of the
grounds 98's D38 allows a departure on (wrong, contradictory, ambiguous, conceded by the Report: haskell98.md:6742).
98 mode is unchanged under every option.

- **A. None: not in this roadmap; recorded as Planned, a declared gap at G2.** **Recommended, on the owner's explicit
  word alone.** rhc reads `foreign export` (E3's `DForeign` has the export form: `results/E3/programs/foreign1.hs`) and
  refuses it with D7's "not supported by rhc"; no HsFFI.h ships. The rows of 8.4.4 and 8.7 are Planned in the 2010
  table, and G2's exit names them as the one requirement of the text left open. 0 lines in Rune.
- **B. Large: a milestone after G2, on x86-64 first.** `runeopt`'s native builds emit a C-callable stub per export that
  enters the VM, linked with the program's C, and `librune` gains an embedding API (start, stop, arguments, collect)
  and the header: runeopt and runtime ~600 lines with tests (G24, G25) [inferred, not built]. Bytecode programs would
  still export nothing, and other targets wait on `runeopt`: "There is no native `runeopt` or GUI acceptance claim for
  these targets" (`docs/ffi/portability.md:53-54`).
- **C. Large: B inside this roadmap, before G2.** The same work, with G2 and so the default flip (D3) waiting on a
  native embedding no Rune roadmap plans [inferred].

**The evidence.**
- *Why `wrapper` does not stand in for it.* A `wrapper` makes a C function pointer of a Haskell function, but Rune
  enters it only while a foreign call of the program is active on the owning thread (D31;
  `docs/ffi/callbacks.md:9-12`). An export is entered by name from C code that Haskell did not call, which is the entry
  Rune's contract refuses [inferred from G11 and G24].
- *Exceptions:* "If an evaluation triggered by an external invocation of an exported Haskell value returns with an
  exception, the system behaviour is undefined." (T10:6980-6981). Under B the stub would catch them, as D31's
  trampoline does [inferred].
- *Re-initialisation:* the Haskell system "may be de-initialised with hs_exit() and be re-initialised with hs_init() at
  a later point in time" (T10:7437-7438); GHC does not support it (E1's N1(g)). An rhc embedding would meet the same
  question.
- *Precedent* (*What the implementations do*) [read]: Hugs has no `foreign export`; nhc98 has it with restrictions, the
  export's type taken as the function's signature, so no class dictionary (`nhc98/docs/ffi.html:45-48`); MicroHs
  0.16.12 parses it (`MicroHs/src/MicroHs/Parse.hs:416`), tests it (`tests/ForExp.hs`) and ships an HsFFI.h with the six
  functions (`src/runtime/HsFFI.h:70-75`). So MicroHs and nhc98 can judge B's tests when it lands. The precedent is no
  ground: the 2010 text admits no exception (*What the literature says*).
- *Use:* how many programs of the corpus or of Stackage export to C was not measured.

**Recommendation.** A, on the owner's explicit word. **The strongest argument against:** it leaves 2010 mode short of
the text in a required feature, the one gap at G2 with no ground of the text behind it, where GHC, MicroHs and, with
restrictions, nhc98 have it. The answer is the cost: an embedding API and a native stub generator, a target at a time,
for mixed-language programs that the conformance tests and the corpus do not need [inferred], and B keeps the way open.

**What would reopen it.** The owner declining to leave a required feature out, which brings in B or C; a Rune roadmap
that adds an embedding API for its own ends, which leaves rhc only the stubs.

### D29. `Ptr`

**Question.** What is a `Ptr a` at run time? 35.1 treats it as an address: Eq, Ord, Show and Storable instances
(T10:15576-15579); `plusPtr` "Advances the given address by the given offset in bytes" (T10:15594-15596); `alignPtr`
"yields the next higher address that fulfills the alignment constraint" (T10:15597-15601); `minusPtr` satisfies
``p2 == p1 `plusPtr` (p2 `minusPtr` p1)`` (T10:15602-15605); IntPtr and WordPtr "can be losslessly converted to and
from Ptr" (T10:15684, 15711). Rune never shows an address: "SML contains identities and liveness tombstones, never
native addresses" (`docs/ffi/runtime.md:76-78`), a rule of the runeffi roadmap: "Native addresses are held outside the
SML heap, rather than cast to SML integers" (`docs/plans/runeffi.md:465-467`). **The owner's call on Rune's model.**
98 mode is unchanged under every option.

- **A. Large, as policy: raw addresses for Haskell's `Ptr`, through a trusted address-level primitive family for rhc's
  Core alone.** **Recommended.** Read, write, call arguments and adopt by address; SML keeps its identities, and rhc's
  Core is the one exception to the rule. C ~200, SML ~100 and a safety review, about 300 lines (G13 A) [inferred, not
  built]. It makes G13 to G17 exact: `plusPtr`, `minusPtr`, `alignPtr`, Eq and Ord on addresses; the IntPtr
  conversions trivial (G14); a pointer stored in memory bytes like any other (G15); no registry growth (G16); a
  callback's pointer arguments usable after it returns (G17) [inferred].
- **B. Medium: identity plus offset in rhc.** Rune's rule stands, and it gains operations: order, difference, the
  alignment offset, a view before its parent's start and a canonical identity per address (G13 B: C ~150, tests ~150);
  adopting an address read from memory as an identity and writing an identity's address into memory, for
  `Storable (Ptr a)` (G15, medium: C ~60, SML ~20, tests ~80); canonical identities for pointers C returns (G16,
  medium: C ~80 and tests) and for a callback's pointer arguments (G17, small: C ~20). About 560 lines with G16's tests
  unsized [inferred: the sum of `gaps.tsv`'s estimates; none built]. The IntPtr conversions stay a deviation, since an
  identity is no address (G14), and no ground of D38 covers that either, so B too would rest on the owner's word
  [inferred].
- **C. None: the prototype's identities as they stand.** `Ptr` a newtype of an identity's number. Eq fails, offsets are
  views Haskell cannot read through, and `minusPtr`, `alignPtr` and Ord have no counterpart (below). 35.1 unmet, with
  no ground. Rejected.

**The evidence.**
- *Eq and offsets on identities* (`results/E10/out/Gaps.-O1.stdout`) [measured]: `getenv` twice gives two identities
  that are not `==`, though `sameAddress` says they are one address; `plusPtr` into an allocation passed to C works
  (`strlen` gives 5), but Haskell's own peek through it is refused, "foreign memory range is out of bounds", as is
  `plusPtr` past the end. Nothing orders identities, takes their difference or aligns them
  (`lib/basis/rune_foreign_sig.sml:173-179`) [read].
- *The identities protect nothing C made.* A pointer C returns, and a callback's pointer argument, get the extent
  SIZE_MAX (`runtime/foreign.c:693`, `:528`). A peek 1 GB past `getenv`'s result is a segmentation fault, status 139,
  at -O0, -O1, -O2 and on the stack target (`results/E10/progs/FarPeek.hs`, `matrix.tsv`) [measured]. Bounds hold for
  Rune's own allocations only (`runtime/foreign.c:308-310`), and D33 makes `malloc` C's, so a program's `malloc`ed
  blocks are unchecked too, `alloca`'s alone staying Rune's [inferred]. Past an object is C's undefined behaviour in
  any Haskell (G18).
- *The identities grow without bound.* Each pointer C returns is a new identity never released: 1,000 `getenv` calls
  add 1,000 live identities, and `Gaps.hs` ends with 1,036 (`Gaps.-O1.stdout`) [measured]. "Releasing a pointer
  identity alone never frees native-owned storage." (`docs/ffi/runtime.md:96`).
- *The design of record.* Peyton Jones 2001: `Ptr` values are "Uninterpreted ... treated simply as bit patterns. The
  Haskell garbage collector does not follow the pointer" (E11, `results/E11/literature.md`, Part B). Raw addresses are
  the FFI's design.
- *Under every option* G06 is needed (taken in D27), and save, restore and fork stay refused "with `EBUSY`" while
  foreign resources live (`docs/ffi/runtime.md:115-116`; G29), a constraint on a future rhc REPL, not on 2010.

**Recommendation.** A. **The strongest argument against:** it breaks, for rhc, a rule Rune made on purpose, and the
safety review is real work: an address-level family lets bytecode read and write anywhere in the process, which the
identity model exists to prevent, and SML programs gain nothing by it [inferred]. The answer is that the identities
guard only Rune's own allocations, which a 2010 program uses for `alloca` alone once `malloc` is C's, while B costs
more lines in Rune, keeps a deviation, and still leaves pointers from C unchecked.

**What would reopen it.** The owner keeping Rune's rule whole, which brings in B and its IntPtr deviation; a Rune
decision to give SML raw addresses too, which makes A Rune's own.

### D30. Finalizers and StablePtr

**Question.** 29.1.1: a ForeignPtr's finalizer "will be executed after the last reference to the foreign object is
dropped. There is no guarantee of promptness, however the finalizer will be executed before the program exits."
(T10:14966-14967). "A finalizer is represented as a pointer to a foreign function" (T10:14955). 36.1: a stable pointer
"will neither be deallocated nor will the value of the stable pointer itself change during garbage collection"
(T10:15749-15751), and it casts to and from `Ptr ()` (T10:15777-15786). Rune has no finalizer and no weak reference:
"No finalizer or new heap object kind is a prerequisite for this roadmap" (`docs/plans/runeffi.md:471`), and
`runtime/prims.def` has no such primitive; its handles are C's alone (`runtime/vm.h:693-697`). 98 mode is unchanged
under every option.

*ForeignPtr:*
- **A. Large: finalization driven by the collector.** A weak table scanned after a major collection, C finalizers
  called at a safe point, on every engine, kept out of images: C ~400 and tests (G21 A) [inferred, not built]. No Rune
  plan has it, the concurrent runtime's included (G21).
- **B. None: each ForeignPtr's finalizers run at `finalizeForeignPtr` and at program exit.** **Recommended.** A dropped
  ForeignPtr's block is held until exit, which "There is no guarantee of promptness" allows. rhc library ~60 and an
  exit hook in rhc's runtime ~20 (G21 B) [inferred].

*StablePtr:*
- **(i) None: a table of values in Haskell, the index the StablePtr.** **Recommended.** Library ~40 (G22). The result of
  `castStablePtrToPtr` "may not refer to an accessible memory location" (T10:15780-15781), so C must not dereference
  it: under D29 A it is an integer as an address, trivially; under D29 B a POINTER identity made of an integer, about
  20 lines of C in Rune (G22, small; W2) [inferred].
- **(ii) Small: a primitive over the VM's `vm_handle_*`.** A second root mechanism, for nothing (i) lacks [inferred].

`freeHaskellFunPtr` needs nothing: releasing a callback identity frees its closure (`runtime/foreign.c:818-826`);
`Basic.hs` frees two wrappers (G23) [measured]. `hs_free_stable_ptr` is HsFFI.h's (D28).

**The evidence.**
- *The text was written for B.* The FFI Addendum: "Finalizers in Haskell cannot be safely realised without requiring
  support for concurrency", hence finalizers that are C functions, and "The only guarantee is that the finalizer runs
  before the program terminates"; in 2001 `newForeignPtr` still took a Haskell action (E11, finding 9; *What the
  literature says*).
- *A `wrapper` as a finalizer.* Nothing in the text forbids a `FinalizerPtr` made by `wrapper`, which would run Haskell
  code (*What the literature says*). Under B rhc calls each finalizer by a foreign call of its own, so a `wrapper`
  finalizer is a callback during that call, which Rune allows once G07 lets a wrapper's FunPtr be called (D27)
  [inferred, not run]. No refusal is needed.
- *At exit.* rhc's top level already wraps `main` so that 98's close and flush run (98's D22, R37); the finalizers join
  that hook [inferred]. How a 2010 program ends has no text (E1's N21; D38).

**Recommendation.** B and (i). **The strongest argument against B:** a program that makes and drops ForeignPtrs in a
loop holds every block until it exits, where GHC frees them as it goes, so a long run can exhaust memory under rhc
alone [inferred]. The text allows it, `finalizeForeignPtr` frees at once when a program asks, and A is a collector
feature no Rune roadmap plans.

**What would reopen it.** A program of the corpus or the tests running out of memory under B; a Rune roadmap that adds
weak references, which makes A cheap.

### D31. Callbacks

**Question.** When may C call back into Haskell, and what does rhc do with a callback Rune will not run? 8.4.3, on
safety: "A safe call is less efficient, but guarantees to leave the Haskell system in a state that allows callbacks from
the external code. In contrast, an unsafe call, while carrying less overhead, must not trigger a callback into the
Haskell system. If it does, the system behaviour is undefined. The default for an invocation is to be safe. Note that a
callback into the Haskell system implies that a garbage collection might be triggered after an external entity was
called, but before this call returns. Consequently, objects other than stable pointers (cf. Section 36) may be moved or
garbage collected by the storage manager." (T10:6956-6961). The text names no other moment, and a `wrapper`'s FunPtr
lives until `freeHaskellFunPtr` releases it (T10:15672-15676), so C may keep it past the call. Rune's contract: entry
from "another thread, or entry outside a native call belonging to the context, returns the annotated native failure
value without executing SML" (`docs/ffi/callbacks.md:9-12`), and "A maximum of 64 nested callback scopes bounds growth
of the C stack" (`:28-37`; `runtime/callback.c:12`). 98 mode is unchanged under every option.

- **A. None: Rune's contract, rhc's trampoline, and the refusal outside a call read as 8.4.3 allows.**
  **Recommended.** Callbacks run during a call of the program, on the owning thread, at most 64 deep, a limit
  documented as the implementation's (G12). rhc's Mid trampoline catches every exception, Loop among them, keeps it,
  returns the failure value, and the call raises it once native control is back (G09, prototyped as `gffWrap`). A
  callback that forces a suspension under evaluation is already `<<loop>>` (G10). A callback after its call returned,
  or from a signal handler, is refused silently, and a test pins that. Rune: none; rhc: in the prototype.
- **B. None: as A, with the refusal outside a call a deviation.** The same behaviour, filed in
  `tests/hs/deviations.tsv` with a ground. **The owner may prefer it:** E1's N1(h) finds that "Nothing says a callback
  may run after the call that received it returned", which makes the text silent rather than permissive, and the
  ground would be "ambiguous" [inferred].
- **C. Large: entry outside a call.** On the same thread, a VM entry from arbitrary native frames, against "The
  register driver remains nonrecursive: no engine calls `vm_loop`, another driver, the JIT compiler, or native entry"
  (`docs/ffi/callbacks.md:30-31`); from other threads, the concurrent runtime's (G11). Not in this roadmap.
- **Optional with A or B, small: `vm_raise` stops at a callback's scope.** C ~15 and a test (G09) [inferred]. The
  trampoline makes it unneeded for rhc; it would protect the VM from a wrapper that forgets.

**The evidence.**
- *The trampoline is mandatory.* The VM trusts the closure `foreign_callback` roots never to raise: `vm_raise` takes
  the next handler (`runtime/runtime.c:268`, `:300`), which may belong to the frames parked below the callback, and
  `vm_callback_apply` checks the handler stack only after a normal return (`runtime/callback.c:44`) [read].
  RuneForeign's SML wrapper does the same for SML (`docs/ffi/callbacks.md:58-64`).
- *What ran* (`results/E10/matrix.tsv`, `out/`) [measured]: an ErrorCall in qsort's comparator surfaces after qsort
  returns, status 1 (`Boom.hs`); an IOError raised in a callback is caught by `catch` around the call (`Catch.hs`);
  "raised to the caller in 70 of 70 calls", callbacks still working after (`out/Escape.stdout`); the same with the
  wrapper in another module, compiled a unit at a time (`out/TwoUnits70.units.*`); a nested foreign call with a nested
  callback inside a comparator (`Nested.hs`); and a comparator forcing its own suspension, `rhc: bottom:
  NonTermination: <<loop>>`, at -O0, -O1, -O2 and on the stack target (`Loop.hs`). Had an exception escaped past
  qsort's C frames, the callback depth would have stayed raised, and after 64 escapes entry would be refused [inferred
  from `runtime/callback.c:12`, `:26`, `:54`].
- *Outside a call* (`results/E10/progs/Later.hs`, -O2) [measured]: an `on_exit` handler and a SIGALRM handler, both
  made by `wrapper`. Neither ran Haskell; the program printed "main returns" and ended with status 0
  (`out/Later.-O2.stdout`, `matrix.tsv`). That the alarm fired rests on the spin outlasting its second, which was not
  timed [inferred].
- *What the reading rests on.* The quoted sentences say a safe call leaves the system "in a state that allows
  callbacks" and place a callback "after an external entity was called, but before this call returns"; the word
  "during" is not in them, and chapter 8 has it only of `hs_init` (T10:7433, 7447). Neither sentence says callbacks
  are allowed only then: a `wrapper`'s FunPtr that C keeps and calls later, from `atexit`, a signal or an event loop,
  is a use the text does not exclude. So A's reading is thinner than it looks [inferred].
- *Threads.* 2010 leaves "the treatment of thread-local state" implementation-defined (T10:6680-6682); a
  single-threaded rhc whose callbacks arrive only inside its own calls meets the chapter (E11, Part B, on Marlow,
  Peyton Jones and Thaller 2004) [inferred].

**Recommendation.** A; whether the refusal outside a call is a reading (A) or a deviation (B) is the owner's. **The
strongest argument against A:** a C library that keeps a callback for later gets the failure value, silently, and the
Haskell program cannot tell; GHC runs such callbacks. The text does not require them, the test makes the behaviour
visible, and C would make the VM re-entrant from arbitrary frames, which no Rune roadmap plans.

**What would reopen it.** The concurrent-runtime roadmap, which brings other threads; a program of the corpus or of
GHC's FFI tests that needs a callback after its call returned (36 plain FFI candidates listed, none run or examined
for callbacks: `results/E10/ghc-ffi-tests.txt`), which makes B's deviation or C a need.

### D32. The FFI in Core

**Question.** What is a foreign import in rhc's Core and Mid, how do the checker and HsLint hold 8.4.2's rule, and what
reaches an interface? The prototype read `foreign import CONV [SAFETY] ["ENT"] v :: t` as the binding
`v = (primForeign "CONV" "ENT" :: t)` and lowered it through 17 `ffi_*` primitives, each a Mid function over `foreign`
or `foreign_callback` (`patches/E10-ffi-prototype.patch`; *The foreign function interface*). Rune: none under every
option. 98 mode is unchanged: the declaration form sits behind 2010's `foreign` token, and 98 mode's bytes held over
E3's whole series of patches, this one among them (`results/E3/identity/`) [measured].

- **A. None: the prototype's lowering, with these changes.** **Recommended.**
  - *An AST declaration form,* E3's `DForeign` (export or import, calling convention, safety, entity, variable, type),
    not the parser's rewrite: +53/-7, 44 code lines in 10 files, through both printers and the dump
    (`results/E3/diffstat.tsv`, `E3-06-foreign`) [measured]. GHC parses the same declarations
    (`results/E3/programs/foreign1.hs`).
  - *IO imports thread World; pure imports force their arguments, then call with `real_world`'s token,* the form of
    `unsafe_perform_io` (`lib/language/haskell/coreruntime.sml:674-676`).
  - *A static call's identity is a top-level CAF* (`v%ffi` in the prototype), so the symbol is resolved and prepared
    once.
  - *The family interface.* A family's primitive "takes arguments of `!Int`, `!Str` and `!Bool`"
    (`lib/language/haskell/coreprimfamily_sig.sml:9-11`); the prototype breaks the rule for Double and function
    arguments (`ffi_enc_real`, `ffi_dec_real`, `ffi_wrap`), which CoreToMid copes with and the Core interpreter cannot
    (V). Either the rule widens for Double and functions, or the FFI primitives become first-class in CorePrim and
    CoreToMid; the milestone picks [inferred: either is small].
  - *Per-program state:* a call's pending exception and the last errno. A program's units become one Mid at link
    (`docs/rhc.md:55-61`), so a global of the family's Mid text is one per program; under Mid-level units they move to
    CoreToMid's `shared` globals (`lib/language/haskell/coretomid.sml:108`) (V).
  - *8.4.2's rule in both checkers* (G33): the structural check in the checker (prototyped, 73 lines), the
    constructor's visibility from the renamer's scope (~40 lines), and HsLint's own reading (~80 lines over its
    environment's newtypes) [inferred, the last two not built].
  - *Interfaces unchanged* (G34): a unit's part holds every value, tycon and constructor whose home is the module,
    exported or not (`lib/language/haskell/infer.sml:44-52`), and the interface writes the exports beside it
    (`lib/language/haskell/hsiface.sml:80-83`, `:97`).
  - *The FFI primitives stay off cheap eagerness's whitelist,* which names arithmetic, comparisons and conversions only
    (`lib/language/haskell/coresimplify_cheap.sml:50-61`, `:113`) [read].
- **B. None: the prototype as it is, the parser's rewrite.** No declaration form: `--print` shows a binding the user did
  not write, `foreign export` has no form at all, and a type error names `primForeign` [inferred]. E3's form exists and
  costs 44 lines. Rejected.

*Foreign.C.Types against 8.4.2* (W4's finding; with D23, and for *Found while writing*):
- 8.4.2 makes a newtype marshallable only where "the constructor N is visible where T is used", and goes on:
  "Consequently, in order for a type defined by newtype to be used in a foreign declaration outside of the module that
  defines it, the type must not be exported abstractly. The module Foreign.C.Types that defines the Haskell
  equivalents for C types follows this convention; see Chapter 28." (T10:6908-6912).
- Chapter 28's export list exports the types abstractly, `CChar, CSChar, CUChar, CShort, CUShort, CInt, ...` with no
  constructors (T10:14480-14485), the types "represented as newtypes" (T10:14521) yet printed as `data CChar`
  (T10:14523).
- Read literally, `CInt` is no marshallable type outside Foreign.C.Types, and the chapter's own examples are refused:
  `cstrlen :: Ptr CChar -> IO CSize` (T10:6936-6937) and `sin :: CDouble -> CDouble` (T10:6945-6946) [inferred].
- **(i) None: rhc's 2010 Foreign.C.Types exports the constructors.** **Recommended; the owner's ruling,** on D38's
  ground "contradictory" (8.4.2's sentence against chapter 28's list), recorded in the module's provenance record (D23)
  and pinned by the chapter's two examples as tests. GHC 9.14.1 exports them
  (`ghc/libraries/ghc-internal/src/GHC/Internal/Foreign/C/Types.hs:43-48`) and checks visibility
  (`ghc/compiler/GHC/Tc/Gen/Foreign.hs:120-123`, `:198-204`); MicroHs exports them too
  (`MicroHs/lib/Foreign/C/Types.hs:2-15`) [read].
- **(ii) None: the list as printed, and the visibility rule waived for Foreign.C.Types' types.** Chapter 28's letter
  kept, at the price of a rule in the checker and HsLint that 8.4.2 does not have [inferred]. The sources of the day
  export them abstractly: `base` 4.3.1.0 (`Foreign/C/Types.hs:31-37` in E9's download), GHC's `haskell2010` package
  1.1.2.0 (`Foreign/C/Types.hs:17-23`, the same download), and Hugs's copy of `base`, which exports the constructors
  only for nhc98, "to fix an interface file problem" (`Hugs/packages/base/Foreign/C/Types.hs:27-33`, `:50-58`) [read];
  so those systems did not hold the visibility rule at these types [inferred].
- **(iii) None: both as printed,** the chapter's examples refused. Rejected: it keeps the contradiction and breaks every
  program that imports a C function over a C type.

**The evidence.**
- *The optimiser keeps the calls* (`results/E10/progs/Opt.hs`) [measured]. Each observation is a line C's `puts`
  writes, and stdout is identical (md5 `5c70abe1`) at seven configurations: -O0, -O1, -O2, -O2
  `--no-cheap-eagerness`, -O2 `--eta=ghc`, -O2 `--strictness=off` and the stack target (`out/Opt.*.stdout`). IO calls
  come out in order; an action bound once and run twice runs twice; one never run, or only `seq`'d, does not run;
  results discarded by `>>` still run. A pure import not demanded is not called, a `let` used twice calls once, a loop
  of three calls three times, and `c_abs (error ..)` applied but never demanded raises nothing. At -O2 the simplifier
  takes 216 declarations to 40 (`out/Opt.O2.simplify-stats.txt`), and 7 `prim ffi_call` sites remain
  (`out/Opt.O2.core-simplify-2.txt`).
- *Strict in all arguments* ("External functions are strict in all arguments.", T10:6892): when the call is demanded,
  the argument's error comes first, `rhc: bottom: ErrorCall: the argument, forced by the call`, status 1, at every
  configuration (`Strict.hs`, `matrix.tsv`) [measured]. GHC reads a pure import the same way, lazy as a value and strict
  once applied (E1's N1(a), probe `n01a_ffi_pure_lazy`).
- *The structural check* refuses a data type, `String` (as `[Char]`), `IO Box` and `Integer`, each "no marshallable
  foreign type (8.4.2)" at its line, and accepts a newtype of a newtype of CInt (`out/Marshal.compile`) [measured].
- *Visibility is unchecked today:* `Visible.hs` imports `c_secret :: Secret -> Secret` though `Abstract` exports
  `Secret` abstractly, and it ran, printing 5 and 7 (`out/Visible.stdout`) [measured]. The checker has the newtypes and
  constructors (`lib/language/haskell/infer.sml:26-27`) but no module scope.
- *Across units:* Visible and Basic, compiled a unit at a time, marshal Abstract's newtypes and CInt through Int32 to
  Int correctly (`out/units.log`) [measured].
- *Not covered:* the desugarer's `foreignBasic` has no Bool and no StablePtr, though the checker accepts both, and no
  program imports a function over Bool, Float, Char or StablePtr (W4, from the patch) [read]; `runeopt` was not among
  E10's ways.

**Recommendation.** A, with (i). **The strongest argument against A:** the visibility check and HsLint's reading are
about 120 lines the prototype did without, for a rule that only refuses programs, and they force (i). Without them rhc
accepts what 8.4.2 forbids. **Against (i):** rhc's Foreign.C.Types then exports more than its printed list, so
`import Foreign.C.Types (CInt(..))` works in rhc and not under a literal reading [inferred]; that is the
contradiction's price on either side.

**What would reopen it.** Mid-level units splitting a program's Mid, which moves the per-program state; a test of GHC's
FFI suite that the structural check refuses wrongly.

### D33. Foreign.\*

**Question.** How are the Foreign modules of chapters 24 to 37 built, and over what? E9 sizes the 14 at about 2,496 new
lines, 1,100 of them Foreign.C.Types written out instance by instance, about 120 if the library may derive newtype
instances (`results/E9/estimate-totals.txt`, which says 15 modules; `modules.tsv` has 14) [inferred]. 98's D26 A, the
owner's, puts no SML below Haskell (haskell98.md:6363), so rhc cannot reach RuneForeign's SML marshalling
(`lib/basis/rune_foreign_sig.sml:7-193`). 98 mode is unchanged: the modules are 2010's, in `share/rhc/haskell2010`.
**The prototype's placement would change Haskell 98 mode:** its `Foreign` module sits in `share/rhc/haskell98` for want
of a 2010 library, a module the 98 Report does not have; it moves.

- **A. None in Rune: Foreign.\* in Haskell over new Core primitives, with typed peek and poke.** **Recommended.** Reads
  and writes at byte offsets for 8 to 64 bits, Float, Double and pointers (E9's Foreign.Storable row), in place of the
  prototype's bytes assembled in Haskell; the code from `base` 4.3's portable branches and Hugs (BSD; D24). With:
  - *Foreign.C.Types per target profile* (G27). C types are newtypes fixed at compile time, so a profile (LP64, LLP64,
    ILP32) picks the module; plain `char` is unsigned on AArch64 and PowerPC64 (`docs/ffi/portability.md:59-61`), so
    CChar is Int8 on x86 and Word8 there, and a `.rbc` that uses C types is target-specific. Library: a module per
    profile, ~150 [inferred]. The sizes are known to `abiFacts` in SML (`lib/basis/rune_foreign_sig.sml:38-45`), out of
    Haskell's reach, so a Core primitive or a table fixed with the profile [inferred, E9].
  - *`malloc` and `free` are C's* (G19). `free` frees what `malloc` and the C string functions made
    (T10:15193-15197), and `finalizerFree` is "a foreign function equivalent to free" (T10:15203-15205). Rune's
    `allocate` is registry-owned, a `calloc` released by Rune (`runtime/foreign.c:289-296`), and stays for `alloca`
    (G20). Library ~30, and ~40 for `alloca` and `realloc` [inferred].
  - *errno* (G28). rhc keeps the errno captured after the last call for `getErrno` (T10:14116); Rune captures it
    "immediately after `ffi_call`" (`docs/ffi/runtime.md:106-108`). The VM's `sys_errno` is the wrong one, its last
    failed system call (W2). The Report's `"errno.h &errno"` cannot work: errno is thread-local and glibc's symbol is
    unreadable (G06). rhc ~30 in Mid, and library [inferred].
  - *Allocation failure gives `nullPtr`,* as the text says: "If any of the allocation functions fails, a value of
    nullPtr is produced." (T10:15125). `base` 4.3 raises an IOError instead (`results/E9/modules.md:57-58`).
  - *C strings are Latin-1,* as `base` 4.3 has them and the text concedes: "Currently only Latin-1 characters are
    representable." (T10:14357), against "by default, is determined by the current locale" (T10:14296).
- **B. Small in rhc: Foreign.\* over RuneForeign's SML.** Against the owner's decision of 98's D26. Rejected.
- **C. None: bytes assembled in Haskell over the generic `foreign` operations,** the prototype's way. It works, and
  pays per access what a call pays per argument (below) [inferred]. Rejected for A's typed primitives.

*The cost of a call* (`results/E10/progs/Cost.hs` at -O2, `runevm --count` at 200,000 iterations minus 100,000, so
start-up cancels: `results/E10/out/units.log`) [measured]:

| Per iteration | VM instructions | Bytes | Objects |
|---|---:|---:|---:|
| Haskell's own `abs` on CInt | 39.4 | 56 | 2 |
| a pure import of C's `abs` | 186.0 | 400 | 21 |
| an IO import of C's `abs` | 203.0 | 464 | 23 |

A pure call costs 146.6 instructions, 344 bytes and 19 objects more than Haskell's `abs`, an IO call 163.6, 408 and 21;
libffi's native work is not counted. Most of it is strings: each argument is encoded as nine bytes made of eight
one-byte strings and their concatenations (`gffWordBytes`, `gffEncInt` in the patch) [inferred from the code]. Wall
time, three runs each on a shared machine: 0.33 to 0.43 s per 100,000 pure calls, against 0.025 to 0.039 s for
Haskell's `abs`. **An optional Rune change, size not estimated:** typed scalar arguments and results for `foreign`,
without strings.

*On the Core interpreter* (`bin/rhc Main.hs` runs CoreInterp, `docs/rhc.md:17-19`), the owner's pick:
- **(i) None: compiled only, documented.** **Recommended.** The prototype's primitives raise an IOError there
  (`noInterp` in the patch; G35).
- **(ii) None in Rune: CoreInterp's FFI over RuneForeign's public API,** callbacks re-entering CoreInterp, ~250 lines of
  rhc [inferred]. `bin/rhc Main.hs` is how a program is run by default, and under (i) a 2010 program that imports C
  runs only compiled.

**The evidence.**
- *The double free* (`results/E10/progs/FreeClash.hs`) [measured]: C's `free` of a Rune allocation followed by
  Haskell's `free` aborts in glibc, "malloc_consolidate(): unaligned fastbin chunk detected", status 134, at -O1, -O2
  and on the stack target, and is silent at -O0 (`matrix.tsv`, `out/FreeClash.-O1.stderr`).
- *The prototype's Word64* is a newtype of Int and overflows at 2^64-1, "rhc: bottom: Overflow: arithmetic overflow"
  (`out/Wide.stderr`) [measured]; D22's IntN and WordN replace it (G30).
- *Where the text is thin* (E9, `modules.tsv`): Storable's 41 instances include Bool and Char with no representation
  given, and `base` stores Bool as a C int and Char in 32 bits; Foreign.C.Error's 99 errno constants have no values, so
  they are the platform's [read by E9].

**Recommendation.** A, with (i). **The strongest argument against:** a profile per target makes a 2010 `.rbc` that uses
C types non-portable, against Rune's portable bytecode, and no FFI program runs on the interpreter. The first is the
text's own model, C types being the platform's, and the second a documented limit that (ii) can lift later.

**What would reopen it.** A call's cost mattering to a corpus program, which brings in the Rune change; the owner
wanting FFI programs under `bin/rhc Main.hs`, which is (ii).

### Extensions

### D34. The checker for extensions

**Question.** On what does rhc check the extensions of track X: today's checker as it is, today's checker extended, or
constraint generation with a solver that OutsideIn(X) would extend? The last is the option 98's D31 left as its C: "It
would buy messages and a head start on a later language, and the brief keeps that for a later roadmap"
(haskell98.md:6515). The owner took 98's D31 A, "one inference over the renamed AST, with evidence recorded by node"
(haskell98.md:6530), and the checker is shaped for Haskell 98:
- a predicate has one class argument, `type pred = {cls : string, ty : ty}` (`lib/language/haskell/types_sig.sml:59`);
- an instance is found by class and type constructor (`lib/language/haskell/classes_sig.sml:18`, `:39`);
- a type has no forall (`types_sig.sml:46-51`);
- `solve` answers each wanted from the givens or from one instance at once, refuses one on a rigid variable that no
  given answers, and hands back only those on unification variables (`lib/language/haskell/infer.sml:317-335`).

The options are lettered as 98's D31's. Rune: none under every option. 98 mode is unchanged under every option: each
tier is a feature, off in every 98 module (D6).

- **A. None: today's checker as it is.** Track X stops where the checker would have to change: the front end, T0 and
  T8. By E7's ceilings that admits 29.29% of Stackage's module files and 16.24% of its packages whole, against 44.66%
  and 28.33% for every recommended name (`results/E7/tier-needs.tsv`). It gives up T1 to T5, and with T1
  OverloadedStrings, the first step of E7's package-weighted cover (D35).
- **A+. None: today's unifier, a deferred store of class constraints solved at generalisation, and improvement as
  unification repeated until nothing changes.** **Recommended.** The design of Hugs, of MicroHs and of Jones 2000,
  section 6.2 (*What the literature says*; *What the implementations do*). As E12 built it, a tier at a time behind a
  switch, in the checker and in HsLint (`patches/E12-T1.patch`, `E12-T2.patch`, `E12-T4.patch`, `E12-T5.patch`):
  - *T1:* `solve` defers a wanted that has unsolved variables and that no instance matches, where 98's refuses it; a
    flexible instance is found by one-way matching and a 98-shaped one by the old index; a class of n parameters keeps
    `pred` by a pseudo-tuple of its arguments, so every one-parameter path keeps its bytes; the Paterson conditions,
    which UndecidableInstances lifts, with a depth bound of 200.
  - *T2:* improvement from instances, from the givens' superclass closure and from pairs of wanteds, with solving and
    improving repeated to a fixpoint (`solveT2`); ambiguity judged modulo the dependencies, and no generalisation of a
    variable the dependencies determine (Jones 2000 section 6.3, section 6.4).
  - *T4a:* a match on an existential constructor makes its variables skolems one level deeper and its context givens,
    in a scope of their own around the alternative, clause or lambda (`exScope`), solved at its end; escape is caught
    by the checker's existing watch.
  - *T5:* `TForall` in the checker's types; an argument is checked against a polytype parameter with its variables
    rigid and elaborated to type and dictionary lambdas; simplified subsumption only, and annotations required.

  No implication constraint and no general solver was needed. 974 code lines in the checker over the four tiers, 848
  in HsLint (`results/E12/areas.tsv`, row `E12-cumulative`). What A+ refuses, each where GHC also draws a line or once
  did (D37): improvement from a given, a constructor context on a universal variable (T4b), deep subsumption.
- **C. None in Rune, large in rhc: constraint generation and a worklist solver, with the tiers built on it.** It
  replaces what A+ extends: `byInstance`, `solve` and defaulting (`infer.sml:296-470`, 175 lines) and `implicitGroup`
  (`infer.sml:1336-1481`, 146 lines), and it changes `explicitExp` and `checkAgainst` (`:1109`, `:1490`). Then it must
  win 98 mode's bytes back: the same evidence, defaulting, monomorphism restriction and messages. E12's agent puts that
  at about 1,500 to 3,000 checker lines before the first extension, and the tiers on it at about 300 lines for T1
  (A+ took 394), 250 for T2 (285), 250 to 350 for T4a (150, the implications being more general than T4a needs) and the
  same 161 for T5 [inferred, not built]. Those figures sum to 961 to 1,061 lines against A+'s 990: between 29 lines
  saved and 71 spent over T1-T5 [counted on them]. HsLint costs the same under A+ and C, since it infers on its own.

**The evidence.**
- *What the prototypes did* [measured]. E12's 9 accepted programs print GHC 9.4.7's output on the Core interpreter and
  at `-O0`, `-O1` and `-O2`, at `RUNE_LINT=2`, each under its own tier and under all four, but for T5's `rank2.hs` at
  `-O0` and `-O1` (D37); its 19 refusal programs are refused by the checker and by HsLint's own inference
  (`results/E12/programs-rhc/summary.txt`, `results.tsv`; `programs-ghc/ghc.tsv`). Among the accepted is an mtl-style
  program (`programs/t2/mtl.hs`: MonadState with `m -> s`, a state monad, a ReaderT lifting it, a state type found by
  improvement alone).
- *GHC 9.14.1's testsuite* (`typecheck/should_compile` and `should_fail`, one-file tests naming only the tier's and T0
  extensions, no CPP, TemplateHaskell or QuasiQuotes, importing only rhc's library: `results/E12/ghc/summary.tsv`,
  `categories.tsv`) [measured]:

  | Tier | Files | should_compile accepted | should_fail refused (of them for another reason) | 98 checker accepts |
  |---|---:|---:|---:|---:|
  | T1 | 29 | 7 of 10 | 19 of 19 (2) | 0 of 10 |
  | T2 | 48 | 27 of 32 | 16 of 16 (0) | 0 of 32 |
  | T4a | 8 | 0 of 2 | 6 of 6 (1) | 0 of 2 |
  | T5 | 48 | 11 of 31 | 16 of 17 (7) | 0 of 31 |

  The failures are named in `categories.tsv`: T1's three need overlap, M22's next group; T2's five are three that need
  2010's empty data (E3), one overlap, and `GivenOverlapping`, which meets R20's reading (*Found while writing*); T4a's
  two are T10856, a context on a universal variable refused by design (D37), and a record of an existential with
  NoImplicitPrelude; T5's twenty are listed under D35. T1, T2 and T4a give the same counts with all four tiers on; T5
  does not: with every tier on, tcfail196 (`Num (forall a. a) =>`) is accepted, FlexibleContexts letting the context's
  shape through, so T5 refuses 15 of 17 (`ghc/run-*-allon.tsv`).
- *98 mode* [measured]. With the switches off: `tests/hs/lang`, 591 of 591 bytecode files and their stdout and stderr
  the baseline's, at T1's state and at the final build (`results/E12/identity/t1off-lang.tsv`, `t5off-lang.tsv`);
  `tests/hs/errors`, 633 of 633 in status and whole stderr (`t1off-errors/`, `t5off-errors/`); 98's D56's run set, 193
  of 193 jobs and 354 of 354 bytecode files, at T1's state (`t1off-corpus.tsv`); the 133 GHC files, the baseline's
  status and first line (`ghc/run-*-finaloff.tsv` against `run-*-off98.tsv`). The run set on the final build was not
  run: the run was stopped early (`results/E12/README.md`). Like E3's and E4's, these checks met no LANGUAGE pragma
  (W10), so M3 compiles the 11 vendored files that carry pragmas, unblanked (8 LANGUAGE, 3 OPTIONS, by grep at the pin;
  `tests/hs/corpus/vendored/nhc98/tests/nofib/real/parser/Main.hs:6-7` has OPTIONS_COMPILE lines besides).
- *Interfaces.* T1's encoding writes an option for every class and every instance (the lists at
  `lib/language/haskell/hsiface.sml:83-87`; `E12-T1.patch`), so the store's bytes and `--dump-iface` move in 98 mode
  though no bytecode does; T2 adds the dependencies to that option, and T5 a tag for a polytype. A production encoding
  writes the extras only where a module's features need them, or 98's interfaces move (D9) [inferred].
- *Why the sizes are lower bounds* (E12's agent) [read in the patches]: the pseudo-tuple predicate stands in for an
  honest `pred = {cls, tys}`, which would touch about 68 predicate sites in the checker and 61 `IsIn` sites in HsLint
  (N's grep, no result file; a grep at the pin finds `IsIn` on 63 lines of HsLint); fundeps sit in a side table keyed by
  the class declaration's span; HsLint's extras are side maps its codec does not write; the new paths have no fault
  injection (the `dict super` and `super` faults do not fire on them); there are no tests or docs. D35 takes N's
  estimates of production: 1.5 to 2.2 times the prototype for the T1 group, 1.6 to 2.3 for T2, 1.7 to 2.6 for T4a and
  3.3 to 5.6 for RankNTypes [inferred].
- *Separate compilation* (`results/E12/units/log.txt`) [measured]: a two-module MPTC and existential program runs
  whole, and fails once a unit is taken from the store: an uncaught `Subscript` at `RUNE_LINT=2` (HsLint's codec
  lacks T1's class extras) and `HsDsCore: Conv.Box at 1 types` at `RUNE_LINT=1` (the existential constructor lost).
  About 50 to 150 lines to fix [inferred].
- *The precedent.* Jones 2000: "we can use unification to ensure that the equalities are satisfied" and "will, in
  general, need to iterate this process" (p. 12); Hugs does so in C and MicroHs in Haskell (E11, finding 2;
  `results/E11/literature.md`). OutsideIn's own account: HM(X) inference "boils down to constraint solving for
  existentially quantified conjunctions of primitive constraints", and what goes beyond it is GADTs' local constraints
  and top-level axiom schemes (p. 5). So the step to implications is needed only for local assumptions [inferred].

**Recommendation.** A+. **The strongest argument against:** every line A+ adds to `solve` is a line the OutsideIn
roadmap may rewrite, HsLint's twin included, and A+'s three refusals are differences from GHC that users will meet. The
answer is that C costs 1,500 to 3,000 lines and 98's bytes before its first extension, and on E12's own figures saves
nothing measurable over T1-T5; that OutsideIn's implications extend a constraint store rather than replace the unifier
(*The architecture*, *What stays possible*); and that each refusal is where GHC draws a line or drew one.

**What would reopen it.** The OutsideIn roadmap scheduled before track X, which makes C its first milestone; a T1-T5
feature found to need an implication; production sizes well past E12's agent's estimates (T1 group 1,600-2,400,
RankNTypes 1,500-2,500).

### D35. The recommended set and its order

**Question.** Which of GHC 9.14.1's 148 LANGUAGE names does track X implement, in what order, and what does that buy?
*The extensions* classifies all 148 (E6) and gives their use on Stackage (E7); this decision takes the set and the order
from them. The census recommends 72 for this roadmap (`rec` = `now`, `results/E6/census.tsv`). The owners' rows are
X1's 36, X2's 25 and X3's 11; the agents' files, which repeat the ten rows all three classified, hold 40, 30 and 18,
and on those ten the three agree on `rec` (`results/E6/overlap.tsv`; W11). By tier the 72 are 25 with no type-system
work (`-`), 28 T0, 9 T1, 1 T2, 4 T3, 1 T4, 1 T5 and 3 T8 [counted]. They include 2010's own switches, the Report's
encouraged names among them ("PatternGuards, NoNPlusKPatterns, RelaxedPolyRec, EmptyDataDecls,
ForeignFunctionInterface": T10:10996-10999), which are tracks F's and V's. Rune: none. 98 mode is unchanged: no
extension name is read in a 98 module (D6).

- **A. None: the 72, ordered by what each needs of the checker, by package weight within a step, co-occurring names
  in one milestone.** **Recommended.**
  1. 2010's own switches (tracks F and V: M7-M9, M15-M16).
  2. The names that need no type-system work, then T0: the lexer and renamer group (M19), CPP (M20, D12), deriving
     (M21; GND, DerivingVia and DefaultSignatures after the T1 group, M22, with D37's whole-dictionary Cast).
  3. T8: RelaxedPolyRec, which is 2010 itself; the monomorphism restriction's No form; MonoLocalBinds (M27).
  4. A+ and the T1 group (M22): MultiParamTypeClasses, FlexibleInstances, FlexibleContexts, TypeSynonymInstances,
     ConstrainedClassMethods, UndecidableInstances, the overlap pragmas; and OverloadedStrings, which needs
     `IsString [Char]`, a flexible instance, where base's is the T6 `(a ~ Char) => IsString [a]` (`census.tsv`).
  5. T2 (M23): FunctionalDependencies, with improvement of wanteds only, under the regime below.
  6. T3 (M24): ScopedTypeVariables, TypeApplications, AllowAmbiguousTypes, InstanceSigs; the scheme's variable order
     in HsIface (D9).
  7. T4a (M25): ExistentialQuantification, contexts on existential variables only.
  8. T5 (M26): RankNTypes under simplified subsumption.

  Production sizes, by E12's agent's estimates per tier, 1.5 to 2.6 times the prototypes for T1, T2 and T4a and 3.3 to
  5.6 times for RankNTypes [inferred by E12's agent]: the T1 group L, one refactor rather
  than four rows summed (1,101 lines in the prototype; about 1,600 to 2,400); FunctionalDependencies M (512; 800 to
  1,200); ExistentialQuantification L (586; 1,000 to 1,500, with records, known-constructor reduction, Sestoft's trees
  and units); RankNTypes L under simplified subsumption (450, passing 11 of 31; 1,500 to 2,500, with result-position
  skolemisation, CoreToMid's boxing, nested contexts, LiberalTypeSynonyms and polytype patterns), XL only with
  DeepSubsumption or ImpredicativeTypes. The census's sizes for these four were set before E12 reported (L for
  MultiParamTypeClasses and FlexibleInstances each, L for fundeps, XL for RankNTypes); E12's replace them.
- **B. None: the same 72 in E7's order of package weight** (`results/E7/cover-pkg-recnow.tsv`): OverloadedStrings,
  CPP, BangPatterns, NoImplicitPrelude, ScopedTypeVariables, FlexibleContexts, RankNTypes, LambdaCase,
  TypeApplications, RecordWildCards, FlexibleInstances, GeneralizedNewtypeDeriving, ... A+ with T1, T3 and T5 would
  come within the first seven steps, before the cheap front-end names; RankNTypes, the largest, is step 7 and takes the
  whole packages from 585 to 608. Rejected: the order of what admits most is not the order in which it can be built.
- **C. None: fewer, the front end, T0 and T8 only** (D34's A): 29.29% of files and 16.24% of packages whole.
- **D. None here: more, T4b, T6, T7, meta-programming and the runtime-heavy names.** The OutsideIn roadmap's and
  later ones' (D37); TemplateHaskell and QuasiQuotes run code at compile time (D40).

*The fundep coverage regime, within A: the owner's call.* What coverage an instance of a class with dependencies must
meet. Coverage in Jones's form: for `class C a b | a -> b` and `instance theta => C t1 t2`, "fv(t2) `subset` fv(t1)";
GHC's liberal form, "fv(t2) `subset` closeWrtFunDeps(fv(t1), theta)"
(`ghc/compiler/GHC/Tc/Instance/FunDeps.hs:357-359`), which "ensures the self-consistency of the instance, but it does
not guarantee termination" (`:361-362`).
- **(i) Jones's coverage and the Paterson conditions, never relaxed for a class with dependencies.** Terminating
  (Sulzmann et al. 2007, Cor. 2, *What the literature says*). It refuses mtl's lifting instances: E12's `mtl.hs`
  needs UndecidableInstances for coverage alone, and `programs/t2-fail/coverage.hs` shows the message.
- **(ii) GHC's: under UndecidableInstances, liberal coverage and the Paterson conditions lifted** (GHC passes the flag
  to `checkInstCoverage` as "be liberal": `ghc/compiler/GHC/Tc/Validity.hs:2068-2075`), with termination left to a
  depth bound, 200 by default (`ghc/compiler/GHC/Settings/Constants.hs:25-26`). E12 built this under its `UI` switch.
  It admits mtl and GHC's own `instance Mul a b c => Mul a [b] [c]`, which "makes instance inference go into a loop"
  (`ghc/docs/users_guide/exts/instances.rst:293-307`).
- **(iii) The Paterson conditions kept, and liberal coverage only where Sulzmann et al.'s Terminating Weak Coverage
  Condition holds:** where an instance breaks coverage, it meets the weak (liberal) condition and its dependent
  argument "is a variable" (Def. 14, `downloads/papers/txt/sulzmann07chr.txt`, p. 30); with full dependencies the
  result is "confluent, terminating, and range-restricted" (Cor. 3, ibid.) [read]. **Recommended.** It admits `mtl.hs`'s
  instances, whose dependent argument is a variable (`MonadState s m => MonadState s (ReaderT r m)`) [read], and their
  real counterparts in mtl as the paper's Example 19 does for MonadReader [inferred], and refuses Mul's, with D7's
  "not supported by rhc" naming the condition. Not built. E12's agent proposed liberal coverage with the Paterson
  conditions kept and no more; that admits Mul, whose context `Mul a b c` is Paterson-smaller than its head, and it is
  the paper's Example 15 of a loop (`sulzmann07chr.txt`, p. 24-25) [read], so the variable clause is what keeps
  termination. What UndecidableInstances does for classes without dependencies stays T1's, as E12 built it.

*T5's subsumption.* GHC's Haskell2010 edition turns DeepSubsumption on (`ghc/compiler/GHC/Driver/DynFlags.hs:1346`), so
GHC's RankNTypes in a 2010 module subsumes deeply and eta-expands (*What the implementations do*). rhc's RankNTypes is
GHC's under NoDeepSubsumption, and DeepSubsumption is a known name rhc does not support (D7) [inferred]. When GHC 9.0
made the same change, 399 of 457 higher-rank packages that compiled needed no change and almost all of the rest one
eta-expansion (E11, finding 6). E12's T5 failures show what production adds (`results/E12/ghc/categories.tsv`): 10 of
the 20 should_compile failures need a forall in a result skolemised against the clause's further patterns, which GHC 9
keeps; 3 a context in a nested type without `forall`; 2 polytypes through synonyms (LiberalTypeSynonyms); 2 patterns on
polytypes; 1 T4's syntax; 1 Traversable, absent from the library; 1 an unsigned rank-2 binding. The one should_fail
file it accepts, T18455, is a SPECIALISE instance pragma rhc does not read; with every tier on it also accepts
tcfail196.

*A recheck before M21* (E7's agent's request): DeriveGeneric is T6 in the census (830 packages; Generic's `Rep` is an
associated type family) and DeriveDataTypeable T5 (729; `gfoldl` and `gunfold` are rank 2, beside Typeable). UHC's
encoding of Generic as a two-parameter class, `Representable0 a rep`, could put DeriveGeneric at T1 or T2
(`census.tsv`) [inferred, not checked].

**The evidence.**
- *What the set buys* (`results/E7/tier-needs.tsv`; a file is admitted when every name it needs is implemented, a
  package when all its module files are) [measured]:

  | Implemented | Module files | Whole packages |
  |---|---:|---:|
  | nothing beyond 2010 | 17.72% | 9.05% |
  | the front end, T0 and T8, any census row | 29.29% | 16.24% |
  | every recommended name | 44.66% | 28.33% |
  | every recommended name but CPP | 38.38% | 19.84% |
  | every census row of tiers `-` and T0-T5, and T8 | 59.26% | 42.60% |
  | also T6 | | 59.17% |
  | every census row | 98.10% | 85.23% |

- *The order's yield* (`cover-pkg-recnow.tsv`, each package weighing 1) [measured]: after the first 20 steps, through
  ExistentialQuantification, 36.16% of files and 25.47% of packages; after 50, 44.65% and 28.33%.
- *Track X does not make Hackage compile.* The gap past the recommended set is the cluster of type families, GADTs,
  DataKinds and PolyKinds (T6 and T7: the last two rows above), and beside it modern base: of the 398 plain-2010
  Hackage components GHC's own 2010 mode accepts, the 2010 shim accepts 355, and the other 43 fail on the library
  alone (E8, `results/E8/summary.txt`).
- *What lands together* (`results/E7/cooc-pkg.tsv`, by package) [measured]: FlexibleInstances is in 836 of the 933
  packages with MultiParamTypeClasses (89.6%); MultiParamTypeClasses in 331 of the 383 with FunctionalDependencies
  (86.4%); ScopedTypeVariables in 549 of the 625 with TypeApplications (87.8%); TypeApplications in 221 of the 265 with
  AllowAmbiguousTypes (83.4%).
- *Package weight from E7, by spelling.* The census's `packages` counts the positive spelling and `no_packages` the No
  form: ImplicitPrelude 4 against NoImplicitPrelude 375, FieldSelectors 1 against NoFieldSelectors 107 (W11;
  `results/E6/census.tsv`, `results/E7/ext-freq.tsv`).
- *Three independent sets* (the Haskell' committee's accepted list of 2009, GHC2021, and Peyton Jones, Jones and Meijer
  1997) agree on multi-parameter classes, existentials, rank N, scoped type variables and kind annotations, leave out
  GADTs and type families, and split on fundeps (*What the literature says*).

**Recommendation.** A, with (iii) for fundeps and simplified subsumption for T5. **The strongest argument against A:**
it puts some of Stackage's most used names (OverloadedStrings in 1,499 packages, ScopedTypeVariables 1,401,
FlexibleInstances 1,300) behind A+ and the T1 refactor, and it still admits only 28.33% of packages whole. The order is
what can be built on what, and B would start with the largest pieces of checker work. **Against (iii):** a program that
GHC accepts under UndecidableInstances may be refused by rhc, where (ii) would accept it and lean on a depth bound.
What (iii) refuses is what is not known to terminate, the refusal names the condition, and nothing (iii) accepts means
anything other than it does under GHC [inferred].

**What would reopen it.** The recheck of DeriveGeneric; production sizes for T1 or T5 well past E12's estimates,
which moves them up *What is cut first* (T5 is second there already); a corpus of mtl-style code that (iii) refuses,
which brings in (ii).

### D36. Extensions that change the meaning of valid programs

**Question.** 67 of the census's 148 names, when on, change the meaning or the acceptance of some valid Haskell 2010
program, and 28 of the 72 recommended do (`results/E6/census.tsv`, column `changes_valid`) [counted]. When may such a
name be on, and what holds it to that? The Report's reserved identifiers are `case`, `class`, `data`, `default`,
`deriving`, `do`, `else`, `foreign`, `if`, `import`, `in`, `infix`, `infixl`, `infixr`, `instance`, `let`, `module`,
`newtype`, `of`, `then`, `type`, `where` and `_` (T10:1740-1743), so `forall` is a variable in 2010. Rune: none under
every option. 98 mode is unchanged: a 98 module reads no extension name (D6).

- **A. None: each such name only when asked, by name, and each with its conservativity test.** **Recommended.** Asked
  means a LANGUAGE pragma, `-X` or a name that implies it (D5's eager implications); rhc's 2010 mode turns none on by
  itself. The test is one program compiled with the name off and on: off gives the Report's answer, cited, and on the
  extension's. With it:
  - `forall` is a keyword only under ExplicitForAll and the names that imply it: RankNTypes, QuantifiedConstraints,
    ScopedTypeVariables, LiberalTypeSynonyms and ExistentialQuantification (`ghc/compiler/GHC/Driver/Flags.hs:289-293`);
  - BangPatterns' whitespace rule for `!` only when it is on;
  - no T1-T5 feature implies MonoLocalBinds, which GHC implies only from GADTs, TypeFamilies and LinearTypes
    (`ghc/compiler/GHC/Driver/Flags.hs:304-305`, `:356`; *What the literature says*);
  - GHC2021 and GHC2024 are not accepted (D5), so no edition turns such a name on; DeepSubsumption is not supported
    (D35).

  The names that change nothing (81 in the census, 44 recommended) have a test of absence instead: the 2010 corpus,
  compiled with the name on, byte-identical to the corpus compiled without it. *Testing and conformance*
  (*Conservativity*) gives both kinds and where they run.
- **B. None: GHC's lexical departures always on in 2010 mode,** as GHC's are in every mode: "`forall` is always a
  reserved keyword", and a prefix `!` "is interpreted as a bang pattern, contrary to the Haskell Report"
  (`ghc/docs/users_guide/bugs.rst:44-57`). rhc would agree with GHC and refuse valid 2010 programs, on none of 98's
  D38 grounds. Rejected.
- **C. None: the most used of them on by default** (OverloadedStrings is named by 44.2% of Stackage's packages:
  `results/E7/ext-freq.tsv`). Every 2010 program would meet it: under OverloadedStrings a 2010 call `c "abc"` at a
  user's class becomes ambiguous (`census.tsv`). Against the brief's "rhc aims to follow the report as closely as
  possible". Rejected.

**The evidence.**
- *How the 28 recommended change valid programs* (`census.tsv`, reasons; X1's mechanisms,
  `results/E6/X1-notes.md:118-129`) [counted]:
  - the No form of a 2010 feature: ImplicitPrelude, DoAndIfThenElse, EmptyDataDecls, TraditionalRecordSyntax,
    FieldSelectors, MonomorphismRestriction, DatatypeContexts;
  - a lexeme 2010 reads as two, or a symbol or a space it reads otherwise: BinaryLiterals (`0b1`), HexFloatLiterals
    (`0x1p4`), NumericUnderscores (`1_000`), NegativeLiterals, LexicalNegation, UnicodeSyntax, BangPatterns,
    QualifiedDo (`M.do`), LambdaCase (`\cases`);
  - `forall` reserved: ExplicitForAll and the four recommended names that imply it, ScopedTypeVariables also making
    a class's variables scope over its methods' signatures
    (`ghc/docs/users_guide/exts/scoped_type_variables.rst:266-271`);
  - the typing or meaning of 2010 syntax: OverloadedStrings, NumDecimals, PostfixOperators, Strict, StrictData,
    MonoLocalBinds;
  - preprocessing: CPP (a variable named `__GLASGOW_HASKELL__`, a string gap).
- *The tests are ready* [measured]: X1's 41 probe modules, each run off and on under GHC 9.4.7 (82 runs,
  `results/E6/X1-data/probes.tsv`), differ off and on in 38 of the 41; in five the off side is GHC refusing valid 2010
  (`bang`, `bang2`, `forall`, `numund`, `qualdo`), so the off result is the Report's, not GHC's. Of the 28, 22 have one
  of X1's probes and 2 one of E5's; RankNTypes and LiberalTypeSynonyms change programs only through `forall`;
  FieldSelectors and MonomorphismRestriction have none yet (*Testing and conformance*).
- *E12, the type tiers switched on over 98's programs* [measured]: with T1 on, `tests/hs/lang` 591 of 591 and the run
  set 354 of 354 the baseline's bytes (`results/E12/identity/t1on-lang.tsv`, `t1on-corpus.tsv`); with all four on,
  `tests/hs/lang` 591 of 591 (`allon-lang.tsv`). Of the 633 refusals, 38 differ under T1 (26 now accepted, each a 98
  restriction T1 lifts, and 12 refused with another message: `t1on-errors/errors98.tsv`) and 40 under all four (27 and
  13: `allon-errors/errors98.tsv`); the two more are `cls.inst.ctx.vars`, refused with another message, and
  `ty.quant.noforall`, accepted because the T5 switch made `forall` a keyword: the case A confines to ExplicitForAll.
  An invalid program accepted under an extension is the extension's purpose, not a change of meaning. Not measured:
  the 2010 corpus with any tier on (E8's 2010 accept list had 32 rows when E12 looked), and the run set under the
  final build.
- *GHC cannot judge these cases:* on 9.4.7 under `-XHaskell2010`, `idf :: forall -> forall`, `a !b = a + b`,
  `x = 1_000` with `_000` in scope and `f = Just.do id` are refused (X1's `forall.hs`, `bang.hs`, `numund.hs`,
  `qualdo.hs`); the last two are not among `bugs.rst`'s deviations (E6, X1's finding 1).
- *The literature* names as meaning-changing overlapping instances, implicit parameters with the monomorphism
  restriction, MonoLocalBinds (12% of 793 Hackage packages failed without local generalisation), FlexibleContexts'
  deferred reduction and deep skolemisation; rank N and visible type application are proved conservative
  (*What the literature says*).

**Recommendation.** A. **The strongest argument against:** a program written for GHC with ScopedTypeVariables and a
type variable named `forall` is refused by rhc as GHC refuses it, while the same program without the pragma is
accepted by rhc and refused by GHC; rhc's 2010 mode and GHC's then differ in both directions, and a user porting from
GHC meets the second. The Report allows `forall` as a name, and rhc follows the Report where GHC states it does not.

**What would reopen it.** An extension whose conservativity test or corpus identity fails, which reclassifies its
census row (X2 classed LambdaCase "no" where X1 and X3 said yes: `results/E6/overlap.tsv`); the owner accepting an
edition (GHC2021), which turns many of these on at once.

### D37. The boundary with the OutsideIn roadmap, and Core's target

**Question.** Where does this roadmap's type system stop, and what must Core and Mid gain for what it takes? Core is
System F with `f a`, lazy `let` and `letrec` and a forcing `case`, as the owner decided for 98 (98's D2 C,
haskell98.md:5418), with System FC left to "An extension whose elaboration wants System FC, which is a later roadmap's"
(:5415-5416). It has `TForall` already (`lib/language/haskell/core_sig.sml:38`); an `AltCon` binds "a constructor and
the binders of its fields", no type variable (`:77`); a `Cast` goes "into or out of a newtype, at its head" (`:73`).
Mid is System F too, but "a forall is a field's type alone, never a binder's, a parameter's or a step's but a `Let`'s
at a scheme" (`docs/ir.md:728-729`), and MidLint holds it (`lib/compiler/core/midlint.sml:213`, `:222`). Mid is Rune's
IR, shared with SML. 98 mode is unchanged under every option.

*The boundary:*
- **A. None: T1, T2 without improvement from givens, T3, T4a, and T5 under simplified subsumption here; T4b, T6 and T7
  in the OutsideIn roadmap.** **Recommended.** Full fundeps, GADTs, type families and associated types want FC (E11,
  findings 3 and 4; *What the literature says*); kinds want kind variables in Core, whose kinds are `Star`, `Unlifted`
  and `Arrow` (`core_sig.sml:27-30`).
- **B. Small in rhc: FC in Core now.** Coercions in Core for nothing T1-T5 needs: E12 changed no Core for T1, T2 and T5.
  It is the OutsideIn roadmap's first step. Rejected.

*T4b, within A: the owner's call.* A constructor context on a universally quantified variable, `data R a = C a => MkR
a` read as a local given (GADT-style).
- **(i) Stays T6's.** **Recommended.** Refused in 2010 mode with D7's message, as E12's T4a refuses it.
- **(ii) Accepted as GHC 9.4.7 accepts it.** OutsideIn's own example with classes alone, `k (MkR x) = op x`, has two
  incomparable types (E11, finding 3), and GHC 9.4.7 infers one of them, `k :: B a p => R a -> p` (E12,
  `programs/t4-fail/mkr.hs`). Without implications A+ cannot give it a principal type [inferred]. Rejected.

*Core, within A:*
- **T4a: type binders in alternatives.** **Recommended.** E12's `AltConEx` (a constructor, its type binders, its field
  binders, a right-hand side) and a convention on `Data`: a constructor's existentials are its fields' free type
  variables beyond the type's parameters, its dictionaries its first fields. 133 code lines in 13 Core files: CoreLint
  (arity and escape), CoreToMid (a hidden type is Mid's `unit`, with `unsafe_cast` at construction), the interpreter,
  units, the runtime and the `-O2` passes; the simplifier does not reduce a known constructor against an `AltConEx`, and
  Sestoft's matcher hands such clauses to the Report's order (`patches/E12-T4.patch`; `results/E12/areas.tsv`). A
  production version may prefer explicit existential binders in `Data` (E12's agent). A pattern binding of an
  existential is refused, as GHC refuses it: a lazy match has no `case` to bind the type (E12's `t4-fail/patbind.hs`;
  *What the literature says*).
- **GND and DerivingVia: a Cast of a whole dictionary** (M21), where today's `Cast` is at a newtype's head only. Without
  type families or GADTs no unsoundness of reusing a dictionary through a newtype is known, so roles wait for T6 (E11)
  [inferred].
- **T1, T2, T5: nothing.** A class of n parameters is a dictionary data type of n parameters; improvement needs no
  evidence; a polytype argument is a type and dictionary lambda (E12).

*How T5 reaches Mid, within A: the owner's call if Rune's IR is to change.*
- **(a) None: CoreToMid boxes a value of polytype in a datatype of one field,** as a dictionary's polymorphic method is
  a field ("So a polymorphic function is put in a dictionary and taken out of one, at a scheme": `docs/ir.md:695-709`),
  and unboxes it at its use. **Recommended.** About 200 to 400 lines of rhc [inferred by E12's agent, not built].
  CoreToMid also refuses "a function polymorphic in a type after a value argument" and "the polymorphic x of a letrec"
  (`lib/language/haskell/coretomid.sml:798`, `:998`), which T5's foralls in results reach, so the same boxing serves
  them [inferred].
- **(b) Large: rank-N in Mid.** A forall as a parameter's and a binder's type: MidLint's rule (`midlint.sml:204-222`)
  and the passes that rely on "a parameter's type is no forall", `Workers`, `flattenJoin`, a lifted function and
  `Lower` (`docs/ir.md:706-709`). Optimal for Haskell and of no use to SML, which has no rank-N types [inferred]. Not
  sized.

**The evidence.**
- *System F was enough* [measured]: CoreLint accepted every E12 program at every tier, and T1, T2 and T5 changed no
  Core file (`results/E12/areas.tsv`: Core rows for T4 only).
- *Mid is T5's limit* [measured]: `rank2.hs` fails at `-O0` and `-O1` with "lint after mid: internal compiler error:
  the type of v4357 is polymorphic, (forall ['a4358] ('a4358 susp -> 'a4358) susp), other than as a field", and runs
  at `-O2` and on the interpreter only because the simplifier removed the polymorphic binder
  (`results/E12/programs-rhc/results.tsv`). CoreToMid writes a Core `TForall` as a Mid forall wherever it stands
  (`coretomid.sml:421`), and MidLint accepts it only as a tuple's component or a field (`midlint.sml:213`, `:222`).
- *T4a in Mid needed no Mid change* [measured]: hidden types erased to `unit` with casts (E12).
- *The boundary's refusals hold* [measured]: `mkr.hs` and GHC's T10856 refused as T6's (`ghc/categories.tsv`);
  improvement from a given refused with the message "an equality System F cannot express (Karachalias and Schrijvers
  2017), which rhc refuses, as GHC does", and GHC 9.4.7 refuses it too (`programs/t2-fail/given-improvement.hs`;
  `programs-rhc/work/t2-fail/given-improvement/T1,T2,UI/err`; `programs-ghc/ghc.tsv`).
- *Separate compilation* is D34's: the prototypes lose T1's class extras and T4a's constructor across a unit boundary.

**Recommendation.** A, with T4b T6's, `AltConEx` binders, the whole-dictionary Cast and boxing in CoreToMid. **The
strongest argument against (a):** a box costs an allocation and an indirection on every rank-N argument and result,
which (b) would not, and both VMs and `runeopt` must agree on it. Against that, it is the device Mid already uses for
dictionaries, it is rhc's alone, and (b) changes Rune's IR for one front end, against the owner's rule of no mechanism
with a single user (*Constraints*). **Against (i):** MkR-style contexts are accepted by GHC and written in real code;
rhc refuses them until the OutsideIn roadmap gives them a principal type.

**What would reopen it.** The OutsideIn roadmap, which takes T4b and brings FC; a measured cost of T5's boxes in a
corpus program; another front end wanting rank-N in Mid, which makes (b) good for two languages.

### Testing

### D38. The 2010 conformance table

**Question.** How is conformance to the 2010 Report recorded and held? 98's table is `tests/hs/conformance.tsv`,
enforced with `clauses = 3901`, `errataCount = 18` and `readings = 54` and the directories `lang`, `accept` and
`errors` written in (`tests/runner/hsconformance.sml:48-58`). E1 built a 2010 table in the same row form
(`results/E1/clauses2010.tsv`): 5,259 rows, 2,736 `same`, 912 `changed`, 1,358 `new` and 253 `removed-in-2010`, every
one of 98's 3,901 ids in some row's `map98` (`clauses2010-counts.tsv`). No errata to the 2010 Report were published;
ten mistakes were reported on the haskell-prime list, none fixed in the text (`results/E1/errata2010.md`). Rune: none.
98 mode is unchanged under every option: 98's table and programs stay as they are. *Testing and conformance* gives
how the table lands; this decision is its shape and the readings that set what it takes as the text.

- **A. None: a second table beside 98's, programs shared by clause id, every shared program run in both modes.**
  **Recommended.** A `same` row's program is 98's; the changed and new rows, 2,270, need programs, 817 of the 912
  changed rows being a 98 row under a renamed module (*Testing and conformance*).
- **B. None: one table with an edition column.** `hsconformance.sml`'s constants and 98's file change, so 98's table,
  closed with its roadmap, moves for nothing that A's `map98` column lacks [inferred]. Rejected.
- **C. None: a second table with its own programs throughout.** 5,006 programs for the rows that are not removed, 98's
  suite unused, and 5,235 s in `make check` were they all run there (D41). Rejected.

*The readings, within A:*
- **(a) 98's eight errata that 2010's text does not absorb (E1's N18; `delta.md`, Delta17): the owner's call.**
  - **(i) Applied where 2010's text is 98's,** each a reading on the ground "wrong", since the errata are the editors'
    own corrections of the text 2010 copied; 98's pinning programs then serve both tables unchanged. **Recommended.**
  - **(ii) 2010 as printed.** The two code errata change behaviour: `enumFrom` and `enumFromThen` on Float and Double
    strict or lazy in their argument, and `lex "_foo"` one lexeme or two; each needs a 2010 program of its own. GHC's
    base takes the printed code for the first and the erratum for the second (E1, probes `n18a`, `n18b`), so it judges
    neither choice. In 2010, too, 6.3.4's prose contradicts the code, so (i) is also the prose over the code (E1, N18).
- **(b) The code chapters' defects (N11) as overlay entries** of the 2010 library (D23): Data.Ratio's missing
  parenthesis, the header `module Array (` and Data.Maybe's second `maybe`. Data.Complex's `Complex(:+)` is in the
  chapter's synopsis, not its code (W8); the Ix law's stray parenthesis and 20.4.3's typesetting losses are readings on
  their rows. **Recommended.**
- **(c) Ix for tuples to size 15 (N16).** 19.2: "A Haskell implementation must provide Ix instances for tuples up to at
  least size 15." (T10:12562); 19.1's list, generated from base, stops at 5. The list is incomplete, the sentence the
  requirement; 98's R51 stands. **Recommended.**
- **(d) How a program ends (N21): the owner's call.** 98's chapter 23 has no 2010 counterpart: chapter 40 keeps only
  `exitWith`, `exitFailure` and `exitSuccess` (T10:16108-16160), and 3.1 keeps "errors cause immediate program
  termination".
  - **(i) 98's behaviour kept as implementation-defined and documented,** output flushed and the exit statuses of
    98's chapter 23; the five rows E1 maps from it leave the table (*Testing and conformance*). **Recommended.** GHC
    writes the buffered text before the error message and exits 1 (E1, probe `n21a`).
  - **(ii) 3.1 read strictly:** no flush after `error`. A change of behaviour from 98 mode with no text requiring it.
- **(e) The 98 module names (List, Char, Array ...) are not in the 2010 library.** **Recommended.** The brief keeps the
  libraries distinct, and GHC 9.14.1 ships no `haskell98` package (*What the implementations do*). The 51 shared
  98-corpus programs that import one stay 98-only.
- **(f) E1's table corrected before it lands** (W8): `lay.parseerror.doif` and `lay.parseerror.thensamecol` are
  `changed`, not `same`, since 2010 accepts `do { if a ; then b ; else c }` as E1's own `exp.if.semi.*` rows say;
  the five chapter-23 rows follow (d).

**The evidence.**
- *Sharing works for most of the 98 corpus* [measured]: of the 975 rows of the 98 corpus GHC-strict-98 accepted, the
  2010 shim accepts 856, refuses 70 and 49 are filtered; of the 70, 51 import a 98 module name, 3 need
  NondecreasingIndentation, which rhc refuses in 98 mode already (R3), and 1 is the n+k program (E8,
  `results/E8/summary.txt`; recounted by W11 from `tests/hs/corpus/accept.tsv`).
- *Sharing needs both modes* [measured]: under E3's spike 21 of 1,475 programs of `lang`, `accept` and `errors` flip
  under 2010 (`results/E3/flips/flips.tsv`), and 9 of the 21 are named by rows E1 marks `same` (W8): four use n+k on
  the way to another clause, two change their message, one tests a clause no rhc program reaches under relaxed groups,
  and two are (f)'s.
- *The changes need programs of their own* [inferred, regex readings]: of E8's 1,279 accept candidates, pattern guards
  occur in 5, foreign declarations in 22 and empty data in about 14 (`results/E8/deltas.txt`).
- *The grounds* for a reading or a departure are 98's: wrong, contradictory, ambiguous, conceded by the Report (98's
  D38, haskell98.md:6702-6742; `hsconformance.sml:54`).

**Recommendation.** A, with (a)(i), (b), (c), (d)(i), (e) and (f). **The strongest argument against (a)(i):** it reads
into 2010's text corrections that its editors, with 98's errata published since 2002, did not make, so rhc's 2010 mode
follows neither the 2010 text as printed nor GHC on `enumFrom`. The 2010 text is 98's word for word at those places,
the reading is labelled on its rows, and the alternative is a mode that knowingly keeps the 98 Report's admitted
mistakes. **Against A:** sharing couples the two tables, so a change to a 98 program moves both; running every shared
program in both modes is what makes that visible.

**What would reopen it.** Fixes to the 2010 text found in the haskell-report repository's history, which E1 did not
consult (`errata2010.md`); the owner taking 2010 as printed (a)(ii); a shared program whose 2010 result differs for a
reason no row names.

### D39. Oracle policy

**Question.** Who judges rhc's 2010 mode, and of what? The owner took for 98 GHC with the strict shim and Hugs `+98` as
judges, nhc98 third and MicroHs a smoke oracle (98's D52, haskell98.md:7157). For 2010 the only GHC binary is 9.4.7;
9.14.1, the census's record, is source; GHC's base is not the 2010 library; and GHC's 2010 mode departs from the Report
(*What the implementations do*). Rune: none. 98 mode is unchanged: its oracles stay as 98's D52 has them.

- **A. None: 9.14.1's source the record; 9.4.7 with E8's shim (g10) for acceptance and output, its limits stated;
  GHC's own 2010 over base (gbase) beside it, to tell language from library; MicroHs for acceptance only; Hugs and
  nhc98 as further opinions on programs without the 2010 changes; jhc not built.** **Recommended.** The shim is
  `oracles/ghc2010/` (`oracles/README.md`): the Prelude and the Report's 30 modules, export lists checked against T10,
  with a defaulting plugin for 4.3.4. For track X the record is 9.14.1's testsuite as written (`should_compile`,
  `should_fail`), E12's method; T5's probes on 9.4.7 run under `-XNoDeepSubsumption` (D35); 9.4.7's acceptance of
  `forall` as a term variable is "source only", since 9.14.1 reserves it.
- **B. None: 98's D52 as it stands.** Hugs refuses pattern guards (E8's L17), nhc98 DoAndIfThenElse and relaxed groups
  (L19, L21), and the 98 shim has no 2010 library. Rejected.
- **C. None in Rune: a 9.14.1 binary beside 9.4.7.** It would lift the "source only" marks, not GHC's departures, which
  `bugs.rst` lists for 9.14.1 itself; a bootstrap build of GHC on a shared machine, for no verdict the 2010 Report
  needs [inferred]. Rejected for this roadmap.

**The evidence.**
- *g10's limits* (`results/E8/limits.tsv`, 23 probes, also run on gbase, Hugs, nhc98 and MicroHs) [measured]: g10
  agrees with the Report on 14 as recorded and on L22 by reading (both print `-Infinity` where the Report's
  `realToFrac` gives "not NaN": `oracles/README.md`), so 15, and departs on 8 in four causes: base's Ratio (L01);
  RebindableSyntax reading a program's own `ifThenElse`, `>>=` or `negate` (L02, L03, L23); base's derivable classes,
  record parentheses and `read "0x10"` (L04, L05); GHC's own departures, prefix `!` and duplicate array indices (L06,
  L15). A ninth limit has no probe: the C types' constructors are exported so that GHC marshals them, so `CInt 3` is
  wrongly accepted (W8). gbase departs on 10. *Testing and conformance* turns each into a standing line of the oracle
  file.
- *Where GHC is no judge* [measured and read]: `forall` as a type variable, prefix `!`, `1_000` with `_000` in scope
  and `Just.do` (D36); a refusal of pattern guards, since NoPatternGuards only warns
  (`ghc/compiler/GHC/Rename/Bind.hs:1474-1479`); 98's stricter dependency analysis, since "You can't turn off
  RelaxedPolyRec any more" (`ghc/compiler/GHC/Driver/Flags.hs:116-117`).
- *MicroHs judges acceptance only* (`results/E8/summary.txt`) [measured]: it accepts 45 of the 57 testsuite files g10
  refuses for language, 24 of 37 plain rows of the 98 corpus and 68 of 170 of its own tests, and refuses 3 of 33, 1 of
  28 and 11 of 49 nofib programs g10 accepts. It does deep skolemisation and no escape check for existentials, so it
  judges neither T4a nor T5 (E11).
- *Hugs and nhc98* accept none of the 415 judged rows of the 98 corpus's extension and illegal-in-h98 set
  (`summary.txt`); both accept n+k (L18).
- *jhc* was not built: its configure needs six packages GHC 9.4.7's database lacks, zlib, utf8-string, HsSyck, random,
  old-time and regex-compat (`jhc/configure.ac:53-68`; `results/E8/jhc-prereqs.tsv` lists nine, readline, editline and
  DrIFT being optional).
- *Cost* per candidate at load about 30: g10 1.09 s, gbase 0.59 s, MicroHs 3.16 s, nhc98 0.76 s, Hugs 0.42 s
  (`results/E8/raw/*.json`, the field `s`).

**Recommendation.** A. **The strongest argument against:** g10 is a shim over a compiler that departs from the Report
in ways no shim undoes, so it will call rhc wrong where rhc follows the text, and its derivable classes are base's.
The rule is 98's: oracles find disagreements, not truth (haskell98.md:8032), and each known departure is a standing
line, so a disagreement outside them is a question with a clause behind its answer.

**What would reopen it.** A rebuilt shim that moves a limit probe; a verdict traced to the shim; a 9.14.1 binary
installed for another reason.

### D40. The corpus and the filter for untrusted code

**Question.** Which code feeds the 2010 oracles and tests, and how is code that would run at compile time kept from
every compiler? GHC runs a splice or an annotation while compiling; CPP's `#include` reads files; a file's own pragma
can turn TemplateHaskell on, and no command line turns it off (*What the brief gets wrong*). E8 drew 3,217 candidates
from GHC's testsuite, nofib, MicroHs, Hackage and the 98 corpus (`results/E8/summary.txt`). Rune: none. 98 mode is
unchanged.

- **A. None: E8's filter as built, run before any compiler and kept as data.** **Recommended.** Out: TemplateHaskell,
  QuasiQuotes, CPP, `capi`, and OPTIONS naming a plugin, `-F` or `-optc`; ANN pragmas blanked in every copy compiled;
  CPP lines found in literate files too. Hackage compiled, never run. A re-pinned or new corpus is filtered again
  before any oracle sees it.
- **B. None: narrower, admitting CPP without `#include`** to the oracles once rhc has D12's CPP (M20). 110 more
  candidates, 63 of nofib's 64 (`results/E8/filtered.tsv`) [counted]. A cpp with no `#include` reads no other file
  [inferred], though a cabal file's `-optP` flags could make it, so B needs the option filter to name them too. For
  when M20 lands.
- **C. Large: a sandbox that runs TemplateHaskell and plugins.** Nothing in this roadmap needs them: TemplateHaskell
  and QuasiQuotes are known names rhc does not support (D7) and the census's `later-meta` (D35). Rejected.

**The evidence.**
- *What the filter kept out* (`filtered.tsv`) [measured]: 167 of 3,217 candidates, 5%: CPP 129 (19 with `#include`),
  TemplateHaskell 30, QuasiQuotes 4 (3 rows name both), `capi` 3, options 4. By set: nofib 64 of 170 (38%), all CPP;
  GHC's testsuite 31, 26 of them TemplateHaskell; Hackage 2 of 429.
- *Two late catches* (`results/E8/README.md`): nofib's `gc/happy` and a Hackage `README.lhs` were found only after the
  filter learnt to read CPP lines in literate files; both had been given to GHC with CPP off, so none of their
  directives ran, and both are excluded from every list since.
- *What remains* is in *Testing and conformance* (*The corpora and the untrusted-code filter*): 32 accept and 63
  reject rows of GHC's testsuite, 49 nofib programs, 27 MicroHs tests, 355 Hackage components, and the extension corpus
  for track X (`results/E8/extcorpus.tsv`: 1,198 rows, 528 candidates, 84 names).
- *rhc itself* runs no code at compile time; its one reach into the file system would be CPP's `#include`, which D12
  confines to the program's own directory.

**Recommendation.** A. **The strongest argument against:** it costs nofib 38%, the largest set of real programs that
run, for the risk of a cpp without `#include`, which is small. Until M20 rhc cannot compile those programs anyway, and
B is the step for that day.

**What would reopen it.** M20 landing, which brings in B; TemplateHaskell support in a later roadmap; a corpus whose
licence or provenance a survey cannot settle, which stays outside the tree as 98's did.

### D41. The `make check` budget and HsLint parity

**Question.** What may 2010 mode add to `make check`, and what must HsLint check of it? Rune's `make check` is 11,879 s
of CPU (`docs/testing.md:261`); rhc's 98 tier is 4,515 s of it, 38.0%, which the owner measured and accepted
(haskell98.md:7231), with 98's D56's 188 programs under 1 s run in three ways (`:7229`). HsLint "shares only the renamer
with the checker" (`lib/language/haskell/hslint_infer.sml:35-36`), so every rule the checker gains it must state again,
from its own specification (98's D54). Rune: none. 98 mode is unchanged: its tiers stay as they are.

*The budget:*
- **A. None: 2010's rows shared by clause id in `make check`, the rest nightly.** **Recommended.** The 2010 clause tier
  adds its changed and new rows, 2,270 of them: about 2,259 s of CPU, +19% of the 11,879 s base and +7.7% of `make
  check` at the 98 roadmap's close (29,255 s at `e5db9feca`) [inferred: E4's rule on E1's counts]. A shared program runs
  in `make check` under one edition, 98's until G3 and 2010's after, and under the other nightly, with
  `--typecheck-only` under the other in `make check`, since all 21 of E3's flips are verdicts or messages [inferred,
  not measured]. The run tier is 25 new programs, 0.78 s under `ghc -O0`: about 4 to 16 s of rhc for one way and 31
  to 125 s in 98's D56's three ways [inferred by the 98 roadmap's K].
- **B. None: every 2010 row its own program in `make check`.** About 5,235 s, +44% of the base and +17.9% of
  `e5db9feca`'s `make check` [inferred], counting the 253 removed rows as E4's rule does (4,983 s without them).
- **C. None: the 2010 tier nightly only.** Nothing in `make check`, and conformance unheld change by change, against
  "first class in conformance" (*Constraints*; 98's D56). Rejected.

*HsLint parity:*
- **(i) Parity per feature, at level 2.** **Recommended.** No row leaves `Planned` until HsLint checks its feature at
  level 2. For the 2010 table that is pattern guards, relaxed dependency groups, empty data's condition 6 and the FFI's
  marshallability; for each extension, its tier's rules. HsLint is budgeted at no less than the checker's cost per
  type feature.
- **(ii) Extensions at `RUNE_LINT=1` until a later roadmap.** It saves HsLint's 848 lines over T1-T5 (E12) and makes
  level 2 mean nothing for any program that uses an extension. Rejected.

**The evidence.**
- *E4's rule* (`results/E4/cost.md`) [inferred from timings, none run]: the clause families (`hs/lang`, `hs/compile`,
  `hs/errors`, `hs/accept`) are 4,400 of rhc's 5,133 check-tier jobs (`results/E4/check-tier-list.txt`), so 86% of
  4,515 s at 98's cost per row, times rows over 3,901. `cost.md` used 5,348 rows and 1,447 new, giving 2,350 s and
  5,320 s; E1's file has 5,259 and 1,358 (`results/E1/clauses2010-counts.tsv`), which give 2,259 s and 5,235 s (W8).
  Run D gave no split of the 4,515 s by family, so 86% is a share of jobs, which the run set's 111 programs in three
  ways probably makes too high (`cost.md`).
- *The run tier* (`results/E8/run.tsv`) [measured under `ghc -O0`, load about 30]: 90 programs, 89 built, 83 matching
  their expected output in 129.8 s of CPU; the 51 under 1 s take 8.84 s. Of those 51, 15 (8.0 s) are nofib programs
  whose names are among 98's D56's 188, which rhc already runs (`tests/hs/corpus/licences.tsv`, column `d56`; matched by
  name), and 11 more were built over base, not the 2010 library. That leaves 25, 24 MicroHs tests and one GHC test,
  0.78 s [counted, W8].
- *What HsLint cost beside the checker*, in added code lines [measured: `results/E3/diffstat.tsv`,
  `results/E12/areas.tsv`]:

  | Feature | Checker | HsLint |
  |---|---:|---:|
  | Pattern guards (E3) | 16 | 18 |
  | Relaxed dependency groups (E3) | 7 | 34 |
  | Empty data's condition 6 (E3) | 5 | 3 |
  | T1 (E12) | 394 | 428 |
  | T2 (E12) | 285 | 126 |
  | T4a (E12) | 150 | 119 |
  | T5 (E12) | 161 | 184 |

  Over E12's four tiers HsLint took 848 lines to the checker's 974, with its extras in side maps its codec does not
  write, so a lower bound (D34). E4's relaxed groups took the checker one change and HsLint four, signatures in scope
  first as Typing Haskell in Haskell's `tiBindGroup` has them (E4's report, finding 7). The FFI's check is D32's:
  the checker's 73 lines and about 40 for visibility, HsLint's about 80 [inferred, not built].
- *What it catches*: at the pin the checker accepts two programs HsLint rightly refuses at level 2 (*Found while
  writing*; `results/E3/defects/rule1-signed/`, `results/D16-probes/`).

**Recommendation.** A, with (i). **The strongest argument against:** about +19% of `make check`'s CPU for a mode that is
not yet the default, on top of rhc's 38%, and an HsLint rule for every checker rule. The 2010 rows are the second
edition's conformance, which the brief asks for and the default flip rests on (D3); A keeps the 98 suite's programs
working for both; and the table above shows HsLint's twin costing from under half the checker's lines to nearly five
times them, never nothing. **Against "no less than the checker's":** E12's T2 and T4a came in below it (126 lines to
285, 119 to 150); as a budget it errs on the safe side, and HsLint's code for both leans on side tables its codec does
not yet write.

**What would reopen it.** Run D's cost by family, which replaces the 86%; `--typecheck-only` missing a flip that only a
run shows; a tier whose HsLint cost runs far past the checker's, which goes to *What is cut first* with its tier.

## The milestones

Each milestone is one commit or a few, and each commit leaves `make check` green. One that touches Rune (`runtime/`,
`src/isa`, `lib/basis`) also passes what `AGENTS.md` asks of what it touches: a primitive changes through its
description and `make isa`, and one that needs the operating system goes behind `runtime/sys/sys.h` in every layer
(`AGENTS.md:65-74`); a change to the primitives moves the instruction set's fingerprint (`:75-77`); a change to
`runtime/register` runs its sanitiser, stress and portability rules (`:186-191`). rhc's own code under
`lib/language/haskell`, `src/rhc` and `share/rhc` is built and tested by Rune alone (`AGENTS.md:438-442`). Every
milestone passes the standing gate (*Gates*).

A heading gives the track, the size and the order. **Why** says what the milestone is for. **What** says what lands, by
file, and the decisions it carries out. **Starts from** names the prototype. **Rests on** names the decisions, and what
changes if the owner decides otherwise. **Gate** appears where Rune changes. **Done when** is what a test shows; every
milestone's list ends with M3's check, which is the standing gate's for 98 mode. **Size** gives the figure and the file
it comes from. Paths under `tests/hs2010`, `share/rhc/haskell2010` and new files are proposals. Line numbers are of
`75ed95861`, where the roadmap was written, and stay so. Implementation starts from the tree of its day: by
2026-11-21 haskell98's tip was 24 commits on, and E4's patch rejects 12 of its 121 hunks there
(`results/E4/other-session.md`), so each citation is checked on that tree before its milestone, and a citation of it
says so.

**A prototype is evidence, not code to land.** E3's spikes, E4's and E13's language record, E10's FFI and E12's
tiers were written to answer questions: they sit behind stubs and switches (E3's `HsLexer.program2010`, E12's
`RHC_E12`), skip tests and documentation, and in places take shortcuts a landing cannot (E12's pseudo-tuple predicate,
E10's parser rewrite). A milestone takes from a prototype its design, its tests and its numbers, writes what lands,
and shows the gate again on what it wrote.

**Sizes** are lines of SML added, tests not counted, unless the heading says Haskell (the library) or C (Rune). A
prototype's size is its own patch's: `results/E3/diffstat.tsv` (added lines, and added lines of code, comments not
counted), `git apply --numstat` of `patches/E4-language-record.patch`, `E13-language-record-b9.patch` and
`E10-ffi-prototype.patch`, and `results/E12/areas.tsv`. A production size is an estimate: F put track F at 2 to 3
times the spike's code (F's report), N put track X at 1.5 to 2.6 times its prototypes for T1, T2 and T4a and 3.3 to 5.6
times for RankNTypes (E12), E9 sized the library from 98's code, base 4.3 and Hugs, and E10 graded Rune's changes
without building them. Letters are E6's scale: S under 300 lines, M 300 to 1,000, L 1,000 to 3,000, XL more
(`results/E6/schema.md:23`). There is no calendar here.

### The order

```text
G0   the owner's decisions; M1, M2 and M3 may start before it

at once, after G0, from the tree of the day
  T    M3 the 98 check, first    M1 the 2010 table    M2 oracles, corpora
  M    M4 record, descriptor, keys -> M5 pre-scan, errors, diagnostics
  H    M18 98 mode: D13a, two checker defects (each on the owner's word)
  F    after M4: M7 small syntax    M8 pattern guards    M9 relaxed groups    M10 hierarchical names
  L    after M4 and M10: M12 Prelude, printed modules -> M13 nine modules    M14 Bits, Int, Word, System.*
  M    after M12: M6 --language, edition pragmas, the 2010 snapshot
  F    after M12: M11 defaulting, Int

G1   hello with a pattern guard, from the 2010 snapshot (M4 to M8, M10, M12)

  V    after M7: M15 the FFI in Core -> after M14 and M15: M16 Foreign.*
  T    every milestone's rows out of Planned

G2   the 2010 Report (M1 to M16)

  D    M28 the flip -> G3 -> M29 retire
  V    M17 foreign export, after G2, only on D28's B

  X    from M5 on, gating neither G2 nor G3
       M19 front end, T0    M20 CPP    M21 deriving (GND, DerivingVia, DefaultSignatures after M22)
       M22 A+, T1 -> M23 T2
       M22 -> M24 T3 -> M25 T4a    M24 -> M26 T5
       M27 T8, any time after M9
```

**G0, and what may start before it.** The owner's decisions come first (*Gates*). M1, M2 and M3 rest on no owner's
item but D38's N18 and N21, which edit rows of the table, not its shape, so they may start before G0 [inferred]. M3
goes first of all: its check is what every later milestone shows, and tracks M and F should land nothing it has not
measured (*Testing and conformance*).

**Track M before F and L.** E3's spikes ran under one stub ref, and E4 replaced every per-run ref with a lookup by
module, binding or group (`results/E4/permodule/`). Each of track F's changes is a feature of M4's record
(*Tracking language settings*: the features at M4), so F follows M4 and is written on its lookups, not on E3's stub.
M5 follows M4 because it fills the record from the header. M4 itself is written on the other session's store and
driver work (the merge 8134f92fe): that is where E4's 12 rejected hunks fall.

**M12 needs M10.** The 2010 Prelude imports `Data.Ratio` and `Data.Char` (T10:7543, 8422), the library is read under
its own language (D9), and rhc reads the library's files from one directory by base name
(`src/rhc/graph.sml:122-138`). So the Prelude cannot be read before 2010's hierarchical lexer and the library's paths,
which are M10's. RULINGS puts M12 after M4 alone and G1 after M4 to M8 and M12; this section adds M10 to both, inside
their headings.

**The critical paths.**
- **To G1:** M3, then M4, M10, M12 and M6. M5, M7 and M8 go beside M10 and M12 once M4 stands.
- **To G2:** M4, M10, M12, M14 and M16, with M15 joining M16 after M7. The bulk is M16: about 2,500 lines of Haskell
  (E9) and D29's change to Rune, which is the owner's call on Rune's model (*Gates*, G0). D29 is the decision that
  most holds G2 [inferred]. M13 and M11 go beside M14.
- **To G3:** G2, then M28, about 6 lines and a full 98 run (E4's `cost.md`). No extension is on it.

**The rows.** No milestone works the 2010 table through on its own, as 98's M19 did. M1 lands the table with every row
`Planned`; each milestone of tracks F, L and V writes the programs of the rows it changes, and G2 is when none is left.
The changed and new rows, by the 2010 chapter that holds them (`results/E1/clauses2010.tsv`, counted): chapters 2 to 6
and 10 to 12, the language, 124 (M5, M7 to M11); chapter 8, 54 (M15); chapters 9, 14, 17, 21 and 22, 195 (M12);
chapters 13, 16, 19, 20 and 38 to 42, 930 (M13, with M14's additions); chapters 15, 18 and 23, 200 (M14); chapters 24
to 37, 767 (M16). That is 2,270 (E1's file as it stands; after M1's corrections 126, 925 and 2,267), of which 51
test nothing and 2,219 need programs; of those rows E1 generated 1,756 and wrote 463 by hand, and 817 of the 912
changed rows are a 98 row under a renamed module, whose programs M1's generator writes (counted on
`source` and `note`). The 2,736 `same` rows keep 98's programs, run in both modes (M1).

**Track X** starts after M4 and never gates G2 or G3. In practice it starts after M5, since an extension is asked for
by name in a header or by `-X`. Its order is D35's: the front end and T0 (M19), then T8's policy (M27), then the T1
group (M22), fundeps (M23), T3 (M24), T4a (M25) and T5 (M26), with CPP (M20) and deriving (M21) beside. M27 is
numbered last but rests on M9 alone, so it may land any time after M9, before T1 as D35 has it. Within M21, the T0
names follow M5, and GND, DerivingVia and DefaultSignatures follow M22 (E6 puts all three at T1; *The extensions*).
E12 found T4 and T5 independent of T1 and T2 in meaning (`results/E12/README.md`), so the chain from M22 through
M24 to M25 and M26 is an order of landing, not of need: what M25 and M26 need is M24's `forall` keyword and HsLint's
rigid variables [inferred]. What track X buys is bounded: every
recommended name implemented admits 44.7% of Stackage's module files and 28.3% of whole packages; every census name
below T6, whatever its recommendation, at most 42.6%, through T6 59.2%, T7 85.2% (ceilings, not sets)
(`results/E7/tier-needs.tsv`). It does not make Hackage compile.

| Track | Milestones |
|---|---|
| T, tests and conformance | M1, M2, M3 |
| M, modes and tracking | M4, M5, M6 |
| F, the 2010 front end | M7 to M11 |
| L, the 2010 library | M12 to M14 |
| V, the FFI | M15 to M17 |
| H, 98 mode | M18 |
| X, extensions | M19 to M27 |
| D, the default flip and retire | M28, M29 |

### M1. The 2010 clause table and its enforcement per edition (T; M, 5,259 rows of data and about 300 lines [estimate]; at once)

* **Why:** G2 is "every clause Supported or pinned", which needs a table rhc is held to both ways, as 98's is. The
  enforcement and the suites are bound to one table and one edition by constants (*Testing and conformance*).
* **What (D38, D41):**
  - **`tests/hs2010/conformance.tsv`:** E1's `results/E1/clauses2010.tsv`, 5,259 rows: 2,736 `same`, 912 `changed`,
    1,358 `new`, 253 `removed-in-2010` (`clauses2010-counts.tsv`), 98's columns plus `map98` and `delta`, every row
    `Planned`. Two of E1's errors are corrected before it lands (W8): `lay.parseerror.doif` and
    `lay.parseerror.thensamecol` become `changed`, since DoAndIfThenElse makes `do { if a ; then b ; else c }` legal;
    the five rows of 98's chapter 23 (System) that E1 maps `changed` into 2010's chapters 39 and 40, with 98's
    statements, leave the table under D38's N21, their programs
    kept as rhc's documented choice.
  - **What D38 settles, as rows:** 98's eight unabsorbed errata as readings on 2010's identical text (N18, if the
    owner takes it); Ix for tuples up to 15 (N16, T10:12562); the code chapters' defects as overlay rows (N11, for
    M12); the errata file empty, its count 0 (`results/E1/errata2010.md`). 98's deviations DV1 and DV8 (R1, R9) are
    2010's text (D13), so the 2010 deviations file starts with 98's other six.
  - **`tests/runner/hsconformance.sml`:** a record per table (its file, row count, errata count, reading ids,
    directories) in place of the constants at `:44-58` (`clauses = 3901`, `errataCount = 18`, `readings = 54`,
    `dirs`); the five rules per table; a program's ids looked up in its own table.
  - **The 2010 suites:** a second `Lang.suite` record in `tests/runner/hslang.sml` (`:94-114`), group `hs2010`, its
    compilers passing `--language=haskell2010`; the library's checks per edition (`tests/runner/hslibrary.sml:39`
    names `share/rhc/haskell98`); the unit prefix per edition in the units and meta runners.
  - **Shared by clause id:** a program of `tests/hs` serves the 2010 table when every id it names is a 2010 row, and
    the 2010 suite runs it under `--language=haskell2010` to the same `.expected`. Every shared program runs in both
    modes: 9 of E3's 21 flips are named by rows E1 marks `same` (W8, `results/E3/flips/attribution.tsv`), so the
    `delta` column alone cannot be trusted.
  - **The generator:** a `tools/generate` command in SML that writes a changed row's program from its 98 program by
    the import map [inferred, not built]. `build_clauses2010.py` does not land (`tests/runner/migration.sml:2,10`).
  - **D41's tiers:** in `make check`, the 2010 rows' programs, and each shared program under one edition with
    `--typecheck-only` under the other; the second edition's full run nightly.
* **Starts from:** no patch. E1's table and counts, E3's flips.
* **Rests on:** D38, D41. If the owner declines N18, the two code errata (`enumFrom`'s `seq`, `lex`'s `_`) need 2010
  programs of their own. If every 2010 row gets its own program, the tier costs about 5,235 s of CPU instead of 2,259
  s, +44% of the 11,879-s base instead of +19% (E4's rule on E1's counts: W8).
* **Done when:**
  - the 2010 table loads in `make check`, every row accounted for (5,259 less the rows D38 removes, each named);
  - the 98 table's enforcement is unchanged: 3,901 rows, and `bin/rune-test list` names the same 98 jobs before and
    after;
  - a planted breach of each of the five rules fails, in each table;
  - each of the 21 flips (`results/E3/flips/flips.tsv`) is split, given a 2010 `.expected`, or has its row corrected,
    so that every shared program passes in both modes once the feature it flips on has landed;
  - M3's check holds.
* **Size:** 5,259 rows of data (E1, measured). The runner's generalisation about 300 lines [estimate; 98's M1 put the
  first table's enforcement at about 250, haskell98.md:7345]. The generator not sized.

### M2. Oracles and corpora for 2010 (T; M, a shim of 36 modules and 1,675 lines of Haskell as built, E8's lists as data, about 250 lines [estimate]; at once)

* **Why:** GHC is a reference, not a judge (the brief), and its 2010 mode runs over base. The judges need a shim that
  gives GHC the Report's library, and every corpus must pass the untrusted-code filter before a compiler sees it
  (D39, D40).
* **What:**
  - **The shim** (`oracles/ghc2010/`, E8): the Prelude and the 30 modules with export lists checked against T10's
    chapters 13 to 42, and a defaulting plugin for 4.3.4, vendored under `tests/hs/oracles/` beside 98's shim with
    base's licence, as 98's is (`tests/hs/oracles/BASE-LICENSE`). `build.sh` and `gen.py` become a doctor hint and
    generated files, as 98's recipes did.
  - **The harness** (`tests/runner/hsoracles.sml:1-10`): a second shim and E8's 2010 sets, nightly by capability.
    Each limit of g10 is a standing line of `tests/hs/oracles.txt`: the 8 probes on which it departs from the Report
    (L01, L02, L03, L04, L05, L06, L15, L23; `results/E8/limits.tsv`, where `g10_agrees` reads 14 yes and L22 agrees by
    reading: W8) and a ninth limit no probe covers, the C types' constructors exported so that GHC marshals them, which
    makes `CInt 3` wrongly accepted.
  - **E8's lists as data** under `tests/hs2010/corpus/`: `accept.tsv`, 1,279 rows (ghc-h2010 32, h98-accept 816,
    hackage 355, mhs-tests 27, nofib-2025 49); `reject.tsv`, 882; `run.tsv`, 90; `filtered.tsv`, the 167 candidates
    kept from every compiler; `extcorpus.tsv`, 1,198 rows over 84 extensions, for track X (counted).
  - **The filter as built** (D40): TemplateHaskell, QuasiQuotes, CPP, capi, and OPTIONS naming a plugin, `-F` or
    `-optc`; ANN pragmas blanked in every copy; CPP lines found in literate files too. It runs before any compiler,
    and again on any corpus re-pinned.
  - **The run programs:** the 25 new 2010 ones (24 MicroHs tests and 1 GHC test, 0.78 s under `ghc -O0`: W8, counted on
    `run.tsv`) vendored after a licence survey, as 98's M3 did; the other 26 of E8's 51 under 1 s are 98's D56's or
    built over base only (*Testing and conformance*). Hackage stays compile-only and is never vendored.
  - The 51 shared programs that import a 98 module name stay 98-only (D38: the 2010 library offers no 98 names).
* **Starts from:** no patch. `results/E8/`, `oracles/ghc2010/`, `oracles/README.md`.
* **Rests on:** D39, D40. MicroHs judges acceptance only: it accepts 45 of the 57 testsuite files g10 refuses for
  language (`results/E8/summary.txt`).
* **Done when:**
  - with no rhc, the harness reproduces E8's verdicts on the trees present (`results/E8/judged.tsv`), any difference a
    line of the oracle file, and a line that no longer matches fails;
  - each of g10's eight probed limits is a line its probe still shows, and the ninth, which has no probe (the C types'
    constructors exported), is stated in the shim's README;
  - a missing oracle skips its job with how to build it;
  - nothing lands without a surveyed licence, and the filter refuses planted TemplateHaskell, `#include` and ANN files
    before any oracle runs;
  - M3's check holds.
* **Size:** the shim as built, 36 modules, the 67-line plugin among them, 1,675 lines of Haskell (counted in
  `oracles/ghc2010/`); E8's lists as data; the harness about 250 lines [estimate; 98's M3 put the first harness at
  about 500, haskell98.md:7374]. Nightly, the five oracles take about 10,700 s: g10 3,334 s and gbase 1,803 s over
  3,052 candidates, MicroHs 3,917 s over 1,239, nhc98 941 s over 1,238, Hugs 699 s over 1,666 (summed from
  `results/E8/raw/*.json`).

### M3. 98 mode held byte-identical: a standing check (T; S, about 300 lines [estimate]; at once, its first task before anything lands)

* **Why:** "the haskell98 mode needs to stay haskell 98 as per its report" (the brief). The 98 suites hold what a 98
  program prints, not its code, and none of E3's or E4's checks met a LANGUAGE pragma (W10): `tests/hs/lang`,
  `accept` and `errors` hold none, and the run-set harness blanks every LANGUAGE and OPTIONS pragma before rhc reads
  a file (`tests/runner/hssource.sml:276-298`, applied at `tests/runner/hscorpus.sml:190-195`). So the one 98 path
  the pre-scan changes has never been compared.
* **What:**
  - **The per-change comparison,** E3's method in SML under `tests/runner/`: the change's rhc against its parent's, on
    one Rune, over (a) `tests/hs/lang`'s 591 programs to register and stack bytecode at `RUNE_LINT=2`, at `-O1` and
    `-O2`; (b) 98's D56's run set through its own harness, `RUNE_HS_RHC` a wrapper that keeps every bytecode
    (`tests/runner/hsrhccorpus.sml:39`); (c) `tests/hs/errors`' 633 refusals and `tests/hs/accept`'s 251, status and
    all of stderr; (d) the views `--dump-ast`, `--print`, `--print-layout` and `--print-exact` of
    `tests/hs/{lang,accept}`; (e) the 98 snapshot's entries and keys.
  - **The 11 vendored files with pragmas,** compiled unblanked in 98 mode under D6's rule: the 8 with LANGUAGE
    pragmas, DatatypeContexts in `tcrun006` and `tcrun029`, ConstrainedClassMethods in `tcrun037` and `tcfail149`,
    ExistentialQuantification in `tcrun004`, GeneralizedNewtypeDeriving in `tc159`, CPP in nofib's
    `common/NofibUtils.hs` and BangPatterns in `shootout/pidigits/Main.hs`; and the 3 whose OPTIONS carry GHC flags,
    `rn039`'s `-fwarn-name-shadowing` and `-fglasgow-exts` in hartel's `Fast2haskell.hs` and `Fast2haskell2.hs` (grep of
    `tests/hs/corpus/vendored`, counted). Each gives its blanked copy's bytecode and stderr. Three of them,
    `tcfail149`, `tcrun004` and `tcrun037`, are refused at the pin in every variant
    (`results/E3/identity/corpus-summary.txt`), so for them the check is the same refusal.
  - **Nightly,** a manifest in the tree: each 98 program's canonical Core (`--dump-after=desugar --canonical-core`,
    `docs/rhc.md:195`), the errors' messages and the views. Core is rhc's own output, so Rune's changes do not move it
    [inferred]; a commit that moves the manifest names its decision.
  - E3's six scripts (131 lines of shell) and E4's `dualrhc.sh` do not land (`tests/runner/migration.sml:2,10`).
* **Starts from:** `results/E3/scripts/` (`sweep-lang.sh`, `compare.sh`, `corpus-run.sh`, `rhc-capture.sh`,
  `errors98.sh`, `views.sh`), `results/E4/lang_bytes.sh`, `dualrhc.sh`.
* **Rests on:** the standing gate.
* **Done when:**
  - rhc against itself passes over (a) to (e) and the 11 files;
  - a planted 98 change fails it in (a) and in the 11 files: `foreign` reserved in 98 mode, n+k refused, an unknown
    pragma name refused in a 98 module (E4's prototype's behaviour, which D6 forbids);
  - the manifest's job runs nightly, and a planted Core change fails it.
* **Size:** about 300 lines [estimate]. The run set alone costs 2,832 to 3,302 s of CPU per rhc
  (`results/E3/identity/corpus-summary.txt:2-3`), so the per-change check is each milestone's, not `make check`'s.

### M4. The language record and the library descriptor (M; L, +755 -224 in 36 files measured in E13's build 9, about 1,000 to 1,500 [estimate]; at once, on the driver of the day)

* **Why:** rhc has one language, held in refs and literals: the checker's `standard` and `cycle`, set once per run
  (`lib/language/haskell/infer.sml:2007-2010`, the prefix `"thaskell98:"`), HsLint's `cycleDefault = false`
  (`src/rhc/driver.sml:300`), the library's name (`src/rhc/library.sml:44`) and its module list in the Makefile
  (`Makefile:822`). Every 2010 feature, and every extension after it, needs each module's setting where it is used.
* **What, as E4 prototyped it (D4, D8, D9, D10):**
  - **`lib/language/haskell/language{,_sig}.sml`,** `HsLanguage`: an edition, ordered flags, the resolved set, a closed
    table of features, and a canonical form without the edition for keys. At this milestone the features are 2010's
    changes, 98's NPlusKPatterns, HierarchicalModules for `--dotted-names`, and rhc's two cycle settings (D8;
    *Tracking language settings*); each track X milestone adds its own.
  - **Lookups, not refs (D10):** the lexer and parser through their options; the graph by the importing module's
    HierarchicalModules; the checker by binding module; HsLint by module and by group, with every signed binding of a
    group in which any module is relaxed in scope from the start (E13's build 9, `anyRelaxed`); a cycle's settings
    agreed across it, or an error. `HsMatch.order` stays global, a compile mode (D8).
  - **Keys (D9):** each member's canonical set in the unit key (98's is empty, so 98 keys stay), the base language in
    the header's mode, the library in the configuration (`extraOf`, `src/rhc/driver.sml:172-178`), pragmas cached in
    the header entry. HsIface is unchanged here, since no feature of this milestone changes an interface; M22 adds the
    class and instance extras and M24 the variable order.
  - **The library descriptor** (`RhcLibrary.haskell98`, `.haskell2010`): the prefix and role modules (Prelude,
    PreludeText, Ix, Ratio, PreludeBuiltin), the library's own language, its hidden modules, leaves and module list.
    Every hard-coded "haskell98" in code goes through it (E4 removed those at `src/rhc/library.sml:44`,
    `infer.sml:2010` and `hslint_env.sml:604` among others), so D20's standard classes come from the descriptor's
    prefix. `rhc --library-modules` replaces `Makefile:822`'s list.
  - **rhc's own options (D8):** `--cycle-default=scc` and `--names=greatest` as per-cycle settings with an agreement
    check, which stops them forcing a whole compile (`src/rhc/syntax.sml:154`). The other options are compile modes and
    stay out of the record.
* **Starts from:** `patches/E13-language-record-b9.patch`, which is E4's patch with E13's fixes. On haskell98's tip of
  2026-11-21, 12 of E4's 121 hunks are rejected: `src/rhc/driver.sml` 4, `hslint.sml` 3, `src/rhc/graph.sml` 2,
  `hslint_env.sml`, `src/rhc/names.sml` and `src/rhc/syntax.sml` 1 each (`results/E4/other-session.md`). The other
  session's `("names", "dotted")` in `extraOf` and its `literate` in a member's id compose with the member's language.
* **Rests on:** D4, D8, D9, D10. D8's owner item: folding `--names=greatest` makes the library immune to it, which
  changes `tests/hs/names/imp/greatest` from 958 pairs to 955 (`results/E4/logs/suites6.log:2`); the alternative keeps
  it a program-wide mode that goes whole, and the pinned dump stays.
* **Done when:**
  - E4's per-module cases are tests, with the features in 2010 modules, since the prototype put them in 98 modules,
    which D6 reads for edition names only: n+k by edition and by `-X`, 4.5.1's example, a mixed program, a mixed
    recursive unit in which only B's bindings are refused, and a cycle that disagrees on a cycle setting
    (`results/E4/permodule/`);
  - E13's edit test is a test: 10 programs, 43 steps, the warm compile equal to `--no-store` in all 43, importers taken
    in all 17 steps that edit an imported module, entries shared when text and set return (`results/E13/edits.tsv`);
  - two spellings of one set give one key;
  - the 98 snapshot's 68 entries and keys are equal to `75ed95861`'s, made at one `--share` and one Main path
    (`results/E4/snapshot-98-compare.txt`);
  - M3's check holds, `hs/names/imp/greatest` apart if the owner takes D8's fold.
* **Size:** the prototype is +755 -224 in 36 files (E13's build 9), E4's +704 -224, of which 226 in the two new files
  (`git apply --numstat`). E4's tracked part by area: `src/rhc` +291 -136, HsLint +81 -39, the checker +25 -9, lexer
  and parser +24 -11, the simplifier +20 -13, the Makefile +12 -4 (E4's report; +470 -222 without `rhc.plan`,
  recounted). About 67 of E13's 169-line `language.sml` are the pre-scan, which is M5's (counted). Production on the
  driver of the day, with the tracking tests: about 1,000 to 1,500 [estimate; there is no rate for track M, so E12's
  1.5 to 2 times is borrowed].

### M5. The header pre-scan; unknown, unsupported and combination errors; diagnostics; printers print header pragmas (M; M, the pre-scan 106 code lines measured in E3, the rest about 400 to 600 [estimate]; after M4)

* **Why:** "If a Haskell implementation does not recognize or support a particular language feature that a source
  file requests (or cannot support the combination of language features requested), any attempt to compile or
  otherwise use that file with that Haskell implementation must fail with an error" (12.3, T10:10989-10990). A
  module's setting starts in its header. Today rhc ignores every pragma, which 98 allows and 98 mode keeps.
* **What (D5, D6, D7, D11, D19):**
  - **The pre-scan:** the header only, pragmas and comments up to the first other token, a `#!` line allowed; after
    unlit; the keyword case-insensitive, names case-sensitive; several pragmas, comments between them, a pragma over
    several lines. A LANGUAGE pragma after the header is ignored with a warning. In OPTIONS_GHC and OPTIONS, `-X`
    flags count and any other flag is ignored with a warning. **In a 98 module only edition names are read and every
    other name is ignored, as today, with no warning:** that is what keeps 98's bytes, and `rn039`'s and hartel's
    OPTIONS lines would otherwise add a warning to 98 stderr (M3's 11 files).
  - **Resolution as GHC's (D5):** the edition a base and the last edition wins; ordered On and Off steps; implications
    as eager steps, taken from GHC's `impliedXFlags` as data, the negative ones included, a later No winning and
    undoing nothing; the command line, then pragmas in text order. E13's model is the specification. GHC2021 and
    GHC2024 are refused.
  - **The closed table (D4, D7):** GHC 9.14.1's 148 names and their No forms (E5's `names.tsv`), each a feature, "not
    supported by rhc", or inert (RelaxedPolyRec in 2010, ParallelArrays, TypeInType, AutoDeriveTypeable, JavaScriptFFI's
    No form, ImplicitStagePersistence). An unknown name is an error at its line and column (E13's fix of E4's
    position-less message).
  - **Combinations** (`results/E13/combinations.md`): refuse C1 (two Safe modes), C2 (a recursive unit's modules
    differing on a cycle-wide setting), C3 (NoHierarchicalModules under a hierarchical library); C4 the policy that a
    recommended feature implying an unsupported one fails no setting, only the construct where written; accept C5 to
    C7, C9, C11, C12. C8 is M9's, C10 M20's.
  - **Diagnostics (D11):** a refusal names the extension, with single, any-of and all-of hints as GHC gives them; a
    token is lexed regardless of the setting only where it cannot occur in a valid program, and a hint given only on a
    path that already fails. The three warnings above are rhc's first.
  - **Printers:** `--print` and `--print-layout` print the header pragmas; today only Exact mode prints trivia
    (`lib/language/haskell/print.sml:129-140`), so a printed 2010 module loses its language (E3's report; no result
    file: W8).
  - Chapter 12's INLINE, NOINLINE and SPECIALIZE stay as in 98 mode (D19).
* **Starts from:** `patches/E3-07-pragma.patch` (`HsLexer.headerPragmas`), whose 98 rule is the design; E13's
  `HsLanguage.scan` and `pragmaAt` for positions; `results/E13/model.py`; E3's `pragmas/` census.
* **Rests on:** D5, D6, D7, D11. E4's and E13's prototypes refuse an unknown name in a 98 module, against D6; the
  milestone follows D6.
* **Done when:**
  - E13's 19 `:show language` captures and the 132 of E5's 137 probe outcomes it reproduces are tests of resolution
    (`results/E13/showlang.tsv`, `predictions.tsv`); the 5 it misses (P18a, P18f, P18i, P18j, P18o) are GHC departing
    from the Report outside resolution, and their tests take the Report's answer;
  - E3's `pragma1` to `pragma6` give their results (`results/E3/run-programs3/results.tsv`), and each header shape E3
    counted has a test: several pragmas, one over several lines, a comment before one, a lower-case keyword,
    OPTIONS_GHC with `-X` (`results/E3/pragmas/summary.tsv`);
  - an unknown name, an unsupported name and C1 to C3 are refused at the name's line and column, in compiles,
    `--whole`, the views and `.lhs` files;
  - a 2010 module printed by `--print` and by `--print-layout` and compiled again gives the same bytes;
  - M3's check holds, the 11 vendored files included: no 98 stderr gains a warning.
* **Size:** the pre-scan is 106 code lines in E3 (71 of them in `lexer.sml`; `results/E3/diffstat.tsv`) and about 67
  lines in E13's `language.sml` (counted). The 148 names and the implications are data. OPTIONS_GHC, the combination
  checks, the hints, the warnings and the printers were not built: about 400 to 600 lines in all [estimate].

### M6. `--language`, edition pragmas and the 2010 snapshot (M; S, about 100 [estimate]; after M4 and M12)

* **Why:** the brief: `--language=haskell98` or `--language=haskell2010`, which "also selects the right prelude"
  under `share/rhc/<edition>`. D1 makes it a setting of the program.
* **What (D1, D2):**
  - `--language` sets the edition every module's setting starts from, the library descriptor, and its configurations in
    the snapshot. The default stays haskell98 until M28.
  - **Edition pragmas (D2's B, GHC's model):** `{-# LANGUAGE Haskell98 #-}` or `Haskell2010` sets that module's rules;
    the library stays the program's. A 98 module in a 2010 program that imports `List` or `Monad` fails, as under GHC
    (E5's P17e).
  - **One layer holding both languages** (D1's recommendation), built by the snapshot rule (`Makefile:823-828`) from
    `rhc --library-modules` per language: two `RUNE_LINT=2` compiles per language and the prune. `bin/rhc`'s wrapper
    (`Makefile:830-831`) names the layer whatever the language.
* **Starts from:** E4's option parser, its two defaults (`RhcSyntax.edition`, `RhcLibrary.current`) and its Makefile
  rule (`patches/E4-language-record.patch`).
* **Rests on:** D1, D2. Per-language layers instead, if install size matters (D1's alternative).
* **Done when:**
  - a 2010 program's and a 98 program's library units are taken from the one layer (`--show-units`, `docs/rhc.md:192`);
  - a module naming `Haskell2010` in a 98 program, and one naming `Haskell98` in a 2010 program, compile under their
    own rules over the program's library, and a 98 module's `import Monad` in a 2010 program is refused with a message
    that names the edition and the library;
  - switching `--language` back and forth takes every unit (E13: each library in its own configuration, both kept);
  - M3's check holds.
* **Size:** about 100 lines [estimate]. E4's layer of both languages was 82,954,000 bytes on its build 5
  (`results/E4/logs/build-layer.log:20`), against 98's 41,334,255 alone (E4's report; no raw file: W10), and took
  43.2 s wall and 26.4 s user on build 6 (`logs/build6-layer.log:17-18`); each of one language's two compiles took 5.7
  to 8.2 s of user and system time, the pair 12.3 to 15.0 s (`snapshot-times-*.tsv`). Its 2010 library was 98's modules
  copied, so the figures are measured again on M12's.

### M7. Small syntax: n+k off, DoAndIfThenElse, empty data with condition 6, `foreign` reserved (F; S, 62 code lines measured, about 120 to 190 [estimate]; after M4)

* **Why:** four of 2010's changes are a few lines each, and each changes what some 98 program means: n+k patterns are
  gone (E1's Δ4), `then` and `else` may follow a semicolon (Δ5, `if exp [;] then exp [;] else exp`, T10:2437), a data
  declaration may have no constructors, with derived instances' condition 6 (Δ6, T10:10670), and `foreign` is
  reserved (T10:1741).
* **What (D15, D17), each a feature of M4's record:**
  - **n+k off** where NPlusKPatterns is off: one condition at the n+k case (`lib/language/haskell/parser.sml:562-566`),
    with a message that names the feature. A top-level `n + 1 = ...` still defines `(+)`.
  - **DoAndIfThenElse:** an optional semicolon, explicit or layout's, before `then` and before `else`; and E1's N13:
    the semicolons reach `let` and `case` blocks too.
  - **Empty data:** the parser's `[= constrs]` and the printer without `=`; a Core.Data with no constructors, nothing
    below the front end changed; condition 6 in the checker and in HsLint, `data T deriving ()` legal and `deriving
    Show` refused. The library's `elidedData` goes with M12.
  - **`foreign`** reserved in 2010 only, and a `DForeign` node (export or import, convention, safety, entity,
    variable, type) parsed by T10:6772-6800's grammar, printed and dumped, and refused by the renamer until M15
    lowers it. This node is D32's AST declaration form.
  - **`:` in ascSymbol** needs no change: the Dec 2005 erratum did it (E3: `--dump-tokens` of `colon.hs` gives the
    same tokens in both modes).
  - Δ7's and Δ10's rows need no code, since fixity resolution is already rhc's and R1 and R9 are 2010's text (D13);
    their programs are written here.
* **Starts from:** `patches/E3-01-npk.patch`, `E3-02-doif.patch`, `E3-03-empty.patch`, `E3-06-foreign.patch`.
* **Rests on:** D15, D17, D27 (the `foreign` keyword).
* **Done when:**
  - the 17 of E3's 21 flips that belong to these features (n+k 10, DoAndIfThenElse 3, empty data 3, `foreign` 1:
    `results/E3/flips/attribution.tsv`) behave in 2010 mode as E3 measured, and M1 has split their rows;
  - E3's `npk`, `npk-top`, `doif`, `empty1` to `empty3`, `foreign1`, `foreign98` and `colon` give their results on the
    interpreter and at `-O1` and `-O2` on both VMs (`results/E3/run-programs3/results.tsv`), `empty1`'s output being
    GHC's; `foreign98`'s `foreign` stays an identifier in 98 mode and prints 42;
  - each feature turned off and on by `-X` in each edition;
  - these features' rows of chapters 2 to 6, 10 and 11 leave `Planned`;
  - M3's check holds.
* **Size:** 62 code lines in the spike: n+k 2, DoAndIfThenElse 3, empty data 13, `foreign` 44 (+80 -12;
  `results/E3/diffstat.tsv`). Production about 120 to 190 [estimate: F's 2 to 3 times].

### M8. Pattern guards (F; S, 110 code lines in 12 files measured, about 220 to 330 [estimate]; after M4)

* **Why:** 2010's guards are lists of qualifiers, `pat <- exp`, `let decls` and boolean (Δ3; 3.13, 3.17.3), and G1's
  hello uses one.
* **What (D14):**
  - **The AST:** a guard as a list of statements; a 98 boolean guard a single `SExp`, which every site takes by its old
    code, so 98's Core holds.
  - **The parser:** 3.13's re-reading of a guard that took the alternative's arrow
    (`lib/language/haskell/parser.sml:1031-1046`) retries the whole qualifier list; a `let` qualifier closed by `,`,
    `=` or `->` closes by layout's parse-error(t), as the existing `block` does.
  - **The desugarer:** Erwig and Peyton Jones's translation with the fall-through bound once, a join point (rule (c)'s
    `y`), the last guard falling to the clause's own failure; rules (s) to (v) (T10:3440-3460). Rule (s)'s "where y is a
    new variable" (T10:3447) names a `y` that does not occur, a defect of the text for *Found while writing this
    roadmap*.
  - The checker, HsLint's inference and replay, both printers and the dump.
  - **Sestoft's trees at `-O2`:** guards are opaque leaves; a guard never runs before the clause's patterns matched;
    what the clause's patterns tested survives the fall-through. Feeding a pattern guard's own test to the tree is a
    later optimisation.
* **Starts from:** `patches/E3-04-guards.patch`.
* **Rests on:** D14.
* **Done when:**
  - E3's `guards1`, `guards2` and `guards-sestoft` give GHC 9.4.7's output on the interpreter and at `-O1` and `-O2` on
    both VMs at `RUNE_LINT=2` (`results/E3/run-programs3/results.tsv`, `ghc/ghc.tsv`);
  - 3.13's note example (`results/E3/programs/guards-note.hs`) is accepted, as the text allows, though GHC refuses it;
  - a sharing budget shows a fall-through evaluated once;
  - a module that says `{-# LANGUAGE Haskell98 #-}` refuses a pattern guard whatever the command line says (E3's
    `pragma3.hs`);
  - Δ3's 27 changed and new rows leave `Planned` (`results/E1/delta-rows-counts.tsv`);
  - M3's check holds.
* **Size:** +136 -22, 110 code lines in 12 files: parser 44, desugarer 21, HsLint's inference 17, checker 16, renamer
  4, dump 2, six files 1 each (`results/E3/diffstat.tsv`). Production about 220 to 330 [estimate: F's 2 to 3 times].

### M9. Relaxed dependency analysis, with the rigid check of a signed pattern-binding variable (F; S, 41 code lines measured, the check not built; after M4)

* **Why:** 4.5.1 cuts the dependency on any identifier with a type signature and 4.5.2 generalises per group
  (T10:4706-4724; Δ8); 12.3 calls the change RelaxedPolyRec (T10:10998).
* **What (D16, D10, D7's C8):**
  - **In 2010 modules only:** an edge filter in the checker's `groupsOf` (`lib/language/haskell/infer.sml:1135`) and in
    HsLint's (`hslint_infer.sml:433-440`, its `succs`). THIH 11.6.3 is HsLint's specification: every explicit
    signature is assumed first (tiBindGroup), at the top level and in local declarations, and the rule is the group's,
    as M4 has it.
  - **D16's reading, the owner's:** the text cuts the edge to a signed variable of a non-simple pattern binding too, and
    the recommendation follows the text (E3's spike kept the edge). Then that variable's type comes from its signature,
    so its binding must be checked against it rigidly. At the pin the checker accepts `p :: a -> a; (p, q) = (not,
    'x')` in both modes and HsLint refuses it at level 2 (`results/D16-probes/rhc.out`). The check lands here for 2010
    modules; M18 decides it for 98 modules. It is one code path, written by whichever lands first.
  - R21(b)'s check stays (4.5.2 keeps identical contexts, T10:4752), though no rhc program reaches it.
  - **C8,** NoRelaxedPolyRec in a 2010 module, the owner's: rec inert with a warning, as GHC. E13's step for it was a 98
    module (W10), so its test is written here in a 2010 module.
* **Starts from:** `patches/E3-05-relaxed.patch`; the group rule of `patches/E13-language-record-b9.patch`.
* **Rests on:** D16, D10, D7. If the owner keeps the edge, PatCut stays refused and the rigid check serves only the
  checker's agreement with HsLint.
* **Done when:**
  - ruling 55's programs: `tc196` and `tcfail071` (both copies of each) refused in 98 and accepted in 2010, `tcfail144`
    refused in both by its own `{-# LANGUAGE Haskell98 #-}` (`results/E3/r21/r21.tsv`);
  - E3's `relaxed1` to `relaxed3` behave as under GHC `-XHaskell2010` (`run-programs3/results.tsv`);
  - `results/D16-probes/`' PatCut and PatGen give the ruled answers at `RUNE_LINT=0` and `2` alike: PatGen refused by
    the checker, not first by HsLint; PatCut accepted and printing GHC's `(('c',True),'c')` if the edge is cut;
  - mixed-cycle tests in the checker and in HsLint (D10), and C8's test in a 2010 module;
  - `dec.gen.sig.identical_where` is split as M1 says, and Δ8's rows leave `Planned`;
  - M3's check holds.
* **Size:** +57 -8, 41 code lines: the checker 7, HsLint 34 (`results/E3/diffstat.tsv`). The rigid check was not built.
  This feature cost HsLint four changes to the checker's one (E4's report, finding 7), which is D41's argument.

### M10. Hierarchical names in 2010: the lexer, library paths, a recursive libraryFiles (F; S, 9 code lines measured for program modules, the library's side about 50 to 100 [estimate]; after M4)

* **Why:** `modid -> {conid .} conid` (T10:1795) changes lexing, not only file names: `M.Just.id` is `id` of module
  `M.Just` in 2010 and `M.Just . id` in 98 (E3). The 2010 library's own modules are hierarchical, and its Prelude
  imports them (T10:7543, 8422).
* **What (D18, D8):**
  - 2010 modules lexed hierarchically: the parser's `dotted` from the module's HierarchicalModules
    (`lib/language/haskell/parser.sml:1587-1588`), which `--dotted-names` sets in 98 mode today. `--dotted-names`
    stays 98's extension, in the unit configuration since issue 27 (after the pin), and is HierarchicalModules in the
    record (D8).
  - A dotted program module found at its path, `Data/Thing.hs`, by the importing module's setting (M4's graph lookup).
  - **The library's side:** `libraryFiles` reads one directory, `.hs` and `.lhs` files by base name
    (`src/rhc/graph.sml:122-138`). The 2010 library needs it recursive, `Data/Char.hs` named `Data.Char`, with the
    descriptor's module list the source of truth (M4). A program's own module of a library name stays the program's
    (`src/rhc/library.sml:39-40, 49`; W2), with the edition's prefix.
  - C3: NoHierarchicalModules under the 2010 library is refused (M5).
* **Starts from:** `patches/E3-08-dotted.patch` (program modules only); `results/E3/programs/dotted2010/`.
* **Rests on:** D18, D8.
* **Done when:**
  - `tests/hs/accept/lex.qual.twodots` is refused in 2010 mode and `tests/hs/errors/lex.qual.modname` and
    `mod.name.modid` give their 2010 messages, as E3 measured; M1 has split their rows;
  - `dotted2010` runs (`results/E3/programs/dotted2010.tsv`);
  - a library in nested directories is read, and a program's `Data/List.hs` is the program's, not the library's;
  - E13's `NoHier.hs` is refused under the 2010 library and runs under 98's (`results/E13/combo/results.txt`);
  - Δ2's rows leave `Planned`;
  - M3's check holds.
* **Size:** +13 -6, 9 code lines for program modules (`results/E3/diffstat.tsv`). The library's side was not built:
  about 50 to 100 [estimate].

### M11. Defaulting per edition; Int modulo 2^n in 2010 (F; S, under 100 [estimate]; after M4 and M12)

* **Why:** 4.3.4 defaults only where "all of these classes are defined in the Prelude or a standard library"
  (T10:4368), and 2010's library adds Bits, with Num as superclass (T10:11629), and Storable (T10:15819), where 98's
  had RandomGen and Random (E9). Chapter 18 says of a list that names Int, "All arithmetic is performed modulo 2^n"
  (T10:12381-12382), where 6.4 lets overflow be an error (T10:6239-6241).
* **What (D20, D21):**
  - **Defaulting:** the standard classes from the descriptor's prefix, which M4 put where the literals were
    (`infer.sml:2010`, `hslint_env.sml:604`); a class is numeric by its superclasses (`infer.sml:346-348`), so Bits
    counts. No list per edition.
  - **Int under D21's B, the owner's call:** Int wraps in 2010 mode only, through the 2010 Prelude's Int instance (98's
    `ov.prelude.int`, `share/rhc/haskell98/overlay.tsv:24`) over word primitives that never raise (`word_from_int`,
    `word_add`, `word_to_int_x`: `src/isa/prims.sml:61-99`), which is B1. B2, wrapping `int` primitives, is a Rune
    change taken only if the measured cost warrants it. Since Int's instance is the library's, a 98 module in a 2010
    program meets wrapping Int (D2). `+`, `-`, `*`, `negate`, `abs` and `fromInteger` wrap; ``minBound `quot` (-1)``
    follows the text, a reading the owner takes with D21; division by zero, and `succ`, `pred` and `toEnum` past the
    bounds, keep their errors.
  - E1's N6: a left shift of a negative value by the width gives 0, a reading on the ground "wrong".
* **Starts from:** no patch. M4's descriptor; 98's D22 measurement.
* **Rests on:** D20, D21. Under D21's A Int stays checked and a deviation is recorded; under C 98's overflow tests flip.
* **Done when:**
  - `print (shiftL 1 3 .|. 1)` defaults to Integer and prints 9, once M14 has Data.Bits (GHC refuses it as ambiguous:
    E1's probe `n09a_default_bits`); a `(Num a, Storable a)` variable defaults to Double once M16 has Storable;
  - `default ()` and `default (Int, Float)` behave as 4.3.4 says (E8's probes `p01` and `p06` as tests);
  - R81's and R93's rows are 2010 rows of their own: `2^70 :: Int` prints 0 [inferred];
  - the cost of an add loop is measured by `--count` at tier 2 and recorded in D21 (98's D22 measured +7 machine
    instructions an add, 19.07 to 26.07: haskell98.md:6262);
  - M3's check holds: 98's Int unchanged.
* **Size:** under 100 lines [estimate]: a few at the two defaulting sites, which M4 mostly does, and the 2010
  Prelude's Int instance.

### M12. The 2010 Prelude and the printed modules (L; L, about 2,330 lines of Haskell carried or printed and about 55 new [E9], three overlay entries; after M4 and M10)

* **Why:** the brief: the 2010 library under `share/rhc/haskell2010`, distinct from 98's. The Prelude's code is 98's but
  for three import names (E1: 915 of 927 non-blank lines identical, 9 differing in spacing only;
  `results/E1/prelude-diff.md`), and four modules print code: Data.Array, Data.Complex, Data.Maybe, Data.Ratio (E9).
* **What (D23, D24, D25):**
  - **`share/rhc/haskell2010/`:** Prelude, PreludeList, PreludeText and PreludeIO in the Report's layout, as 98's D36
    did, from the 2010 printed code (E1's extraction from the HTML, `results/E1/prelude/prelude2010/`); Data.Array,
    Data.Complex, Data.Maybe and Data.Ratio from their printed code (`results/E9/code2010/`; the haskell2010 package's
    `$code` agrees with E1's HTML token for token: W2). A copy, not shared with 98's (D25's A); PreludeRuntime and
    PreludeEnum copied and grown.
  - **A pristine and an overlay,** as 98's (`share/rhc/haskell98/overlay.tsv`), with entries for the text's three
    defects: Data.Maybe's second `maybe` (T10:13431-13440), fixed by 98's re-export of the Prelude's, since hiding it
    breaks every user of Data.Maybe (W2's probe, `results/E9/probes/maybeprobe`); Data.Ratio's missing parenthesis in
    its Show instance (T10:13723-13730); and the header `module Array (` (T10:11476). Data.Complex's `Complex(:+)` is
    in the synopsis only; its code has `Complex((:+))` (W8). 98's two unabsorbed Prelude code errata are overlay
    entries too if D38's N18 holds.
  - **The cycle (D23):** at least the 7 modules the printed imports join (Prelude, PreludeList, PreludeText, PreludeIO,
    Data.Char, Numeric, Data.Ratio: `results/E9/layout-graphs.txt`). Rec 9: Char's and Numeric's Array tables
    dropped, and `interact`'s and `getLine`'s names (BufferMode, `hSetBuffering`, `stdin`, `stdout`, `hGetLine`) moved
    from System.IO's code (`share/rhc/haskell98/IO.hs:51-58, 74-81, 102-103`) into PreludeRuntime; without the move it
    is 11 (W2).
  - **Provenance (D24):** codeless modules carry a record, "98's X with these changes" or base 4.3 with its licence;
    `share/rhc/haskell2010/LICENSE` holds the 2010 notice, 98's, and base's BSD text.
  - The descriptor's 2010 record (M4) names the roles; `elidedData` goes now that empty data exists (D15); D21's Int
    instance lands here as M11 sets it.
* **Starts from:** no patch. E1's `prelude/` and `libs/code2010/`; E9's `code2010/`, `layout.md`, `layout-graphs.txt`,
  `provenance.tsv`.
* **Rests on:** D23, D24, D25. Under D25's B the runtime layer, 852 lines, is shared and both libraries move with it.
* **Done when:**
  - a token comparison of `share/rhc/haskell2010` against its pristine, as 98's `DocChecks.signatures`
    (`tests/runner/docchecks.sml:203-254`), finds nothing outside the overlay, by module;
  - PreludeList, PreludeText and PreludeIO cannot be imported by a program;
  - the Prelude's and the four modules' exports equal T10's (E9's `exports.tsv`), table-driven;
  - G1's check passes, with M6 and M8;
  - the 195 changed and new rows of chapters 9, 14, 17, 21 and 22 leave `Planned`;
  - M3's check holds: `share/rhc/haskell98` is untouched.
* **Size:** Haskell, almost all copied: the Prelude family's 1,530 code lines (Prelude 716, PreludeList 176,
  PreludeText 563, PreludeIO 60, PreludeEnum 15) and PreludeRuntime's 556 carried, with about 55 new
  (`results/E9/layout.md:106-107`); the four printed modules' 236 lines of the Report's code and 12 of 98's overlay
  (`results/E9/modules.tsv`), Data.Maybe 28 code lines with the re-export (W2). No SML [inferred].

### M13. The nine continuing modules from 98's code with 2010's changes (L; L, 941 lines of Haskell carried and about 143 new [E9]; after M12)

* **Why:** nine codeless 2010 modules continue a 98 module whose code rhc has. Names carried of each module's total:
  Control.Monad 31 of 40, Data.Char 23 of 64, Data.Ix 5 of 5, Data.List 104 of 111, Numeric 18 of 18,
  System.Environment 3 of 3, System.Exit 5 of 6, System.IO 59 of 67, System.IO.Error 16 of 27
  (`results/E9/modules.tsv`). Three names are gone: `bracket`, `bracket_` and `system`.
* **What (D24, D26):**
  - Each module from 98's code under its 2010 name, with its provenance record; the new names from base 4.3's portable
    definitions (BSD-3; `results/E9/newdefs.tsv`): Control.Monad's 9 and Data.List's 7, `permutations` and
    `subsequences` in base's order, which only their examples fix (T10:12707, 12712).
  - **Data.Char (D26):** one category primitive, rhc's `rtCategory` (`lib/language/haskell/coreruntime.sml:547`), and
    2010's predicates in Haskell over `generalCategory`: `isUpper` Lu or Lt (T10:11844); `isAlpha` every letter
    (T10:11848; 98's `isAlpha c = isUpper c || isLower c`, `share/rhc/haskell98/Char.hs:42`, already gives every
    letter, but its definition must change: W2); `isSpace` Zs and the five controls (base's reading of T10:11833);
    `isAlphaNum` letters and numbers, by the prose (T10:11851), over base's marks. GeneralCategory's 30 constructors
    in lib/unicode's order (`lib/unicode/code_point_sig.sml:34-64`); `toTitle` from one new table, which lib/unicode
    has (`code_point_sig.sml:137-141`); the Unicode version lib/unicode's, implementation-defined.
  - **Data.Ix:** instances for tuples up to 15 (T10:12562, N16), though the printed list stops at 5 (T10:12553).
  - The names whose code needs primitives rhc lacks are M14's.
* **Starts from:** no patch. `results/E9/delta98.tsv`, `sharing.tsv`, `newdefs.tsv`, `modules.md`.
* **Rests on:** D24, D26. White_Space instead of Zs would add U+0085, U+2028 and U+2029 to `isSpace` (W2).
* **Done when:**
  - the nine compile into the 2010 snapshot and their exports equal T10's (`results/E9/exports/`);
  - Data.Char's predicates are tested over every code point against `generalCategory`, `isSpace` against the Report's
    sentence;
  - Ix holds at a 15-tuple;
  - the changed and new rows of chapters 13, 16, 19, 20 and 38 to 42 (930, most of them renames) leave `Planned`, but
    for M14's names;
  - M3's check holds.
* **Size:** 941 lines of Haskell carried from 98's code (Control.Monad 63, Data.Char 117, Data.Ix 142, Data.List 196,
  Numeric 251, System.Environment 12, System.Exit 15, System.IO 110, System.IO.Error 35) and about 143 new
  (Control.Monad 16, Data.Char 94, Data.List 33), from `results/E9/modules.tsv`'s `est_reuse98` and `est_new`, summed.
  The `toTitle` table is a few lines of CoreRuntime [inferred].

### M14. New modules over new Core types: Data.Bits, Data.Int, Data.Word; System.IO, System.IO.Error, System.Exit, System.Environment additions (L; L, about 830 lines of Haskell [E9] and 150 to 300 of SML [E9, inferred]; after M12)

* **Why:** Data.Bits, Data.Int and Data.Word are new in 2010, and System.IO, System.IO.Error and System.Exit gain names
  that reach the operating system.
* **What (D22):**
  - **Core types and primitives, in rhc only:** Word over the VM's 63-bit word, with its bit operations and the
    reinterpreting `word_from_int` and `word_to_int_x` (`src/isa/prims.sml:61-99`); Word64 over word64, and Int64 over
    word64 with int64's checked operations for comparison and division (`prims.sml:682-771`); Int8 to Int32 and Word8
    to Word32 over Int with narrowing; shifts at or past the width guarded in Haskell (T10:12388-12389, with M11's
    reading). In CorePrim, CoreToMid, CoreInterp and CoreLint.
  - **Data.Bits,** with Num as superclass (T10:11629) and base's default methods, which the text does not give
    (T10:11633). Integer's bits in base 4.3's portable Haskell, since the VM's are GMP's and fatal without it
    (`runtime/intinf.c:569-576`).
  - **Data.Int and Data.Word,** calibrated on Hugs (E9's `sources.tsv`), modulo 2^n by the text,
    ``minBound `quot` (-1)`` as M11 reads it; their Ix instances.
  - **System.*'s additions** as io-family primitives over what the VM has, no Rune change: `hIsTerminalDevice` by
    `posix_isatty`, `hSetFileSize` by `posix_ftruncate`, `hTell` by `h_tell`, `hGetEcho` and `hSetEcho` by
    `posix_tcgetattr` and `posix_tcsetattr` with the ECHO bit (`prims.sml:539-542`; `term_enter` and `term_leave`
    cannot report the echo: W2), `fixIO` over `ref_new` and `interleave`, `withFile`; System.IO.Error's `mkIOError`,
    `annotateIOError` (base replaces the location under GHC and appends under nhc98: a reading), IOErrorType and its
    values; System.Exit's `exitSuccess`. How a program ends keeps 98's chapter 23 behaviour, implementation-defined and
    documented (N21), and what `ExitFailure 0` does is a recorded choice.
* **Starts from:** no patch. `results/E9/modules.md` (*Primitives*), `sources.tsv`; E10's `progs/Wide.hs`.
* **Rests on:** D22; D21 for ``minBound `quot` (-1)``.
* **Done when:**
  - E10's `Wide.hs` prints 2^64-1 for a Word64 result, where the prototype's Int overflowed
    (`results/E10/out/Wide.*`);
  - each IntN and WordN wraps at its width, and shifts at and past the width give 0 or -1, on the Core interpreter and
    on both VMs;
  - Integer's bits agree with a reference on random values, on a VM built without GMP too;
  - E8's `L12_bits_num` holds, and M11's Bits defaulting test passes;
  - the 200 changed and new rows of chapters 15, 18 and 23 leave `Planned`, and the rows of System.*'s new names;
  - M3's check holds.
* **Size:** Haskell: Data.Int about 280, Data.Word about 370 and Data.Bits about 90 (E9's estimate, on Hugs's 281 and
  370 code lines; the Hugs files alone are 268 and 359: W2), and about 87 for System.*'s additions
  (`results/E9/modules.tsv`). SML about 150 to 300 over CorePrim, CoreToMid, CoreInterp and CoreLint [inferred, E9].

### M15. The FFI in Core: declarations, marshallability with visibility, the four imports over Rune's `foreign`; Rune's G02, G06, G07 (V; M, 643 lines of SML measured in E10's prototype, about 800 to 900 with D32's changes [estimate], and Rune's C about 45 with tests about 70 for G06 and G07, G02's not sized [E10's estimates]; after M7)

* **Why:** chapter 8 is part of 2010 (Δ1): "Any implementation of the Haskell FFI must at least implement the C calling
  convention denoted by ccall" (T10:6828-6829), with its static, `&`, `dynamic` and `wrapper` imports. E10 ran all four
  end to end over Rune's libffi bridge.
* **What (D27, D31, D32):**
  - **Declarations:** M7's `DForeign` node through the renamer (which binds the variable), the checker and HsLint, in
    place of the prototype's parser rewrite to `primForeign`, which a landing would have to thread through about 8
    files that match every declaration form and about 4 more (`results/E10/gaps.tsv`, G01).
  - **Marshallability (8.4.2):** the checker's rule, basic types and newtypes of them, a `wrapper` checked as `ft -> IO
    (FunPtr ft)`; the constructor's visibility from the renamer's scope, about 40 lines (the prototype accepts
    `Visible.hs`'s abstract newtype); HsLint's own check, about 80 lines over its data and newtype records (G33).
    Interfaces are unchanged, since a unit's part holds hidden constructors and the interface writes the exports (E10;
    D32).
  - **Desugaring:** a Core primitive family over the VM's `foreign` and `foreign_callback`. IO imports thread World;
    pure imports force their arguments, then call with `real_world`; a static call's identity is a top-level CAF. The
    family interface is widened for Double and functions, since it allows `!Int`, `!Str` and `!Bool` only
    (`lib/language/haskell/coreprimfamily_sig.sml:9-11`), or the FFI's primitives become first-class in CorePrim and
    CoreToMid. The pending exception and the last errno are per-program state, in CoreToMid's `shared` globals under
    Mid-level units (`coretomid.sml:108`). The FFI's primitives stay off core-cheap's whitelist
    (`coresimplify_cheap.sml:50-61`).
  - **The trampoline (D31), mandatory:** a callback catches every exception, `<<loop>>` included, keeps it and returns
    the failure value, and the call raises it after native return, since the VM trusts a callback never to raise
    (`runtime/runtime.c:268, 300`; `runtime/callback.c:44`). Callbacks during a call, on the owning thread, at most 64
    deep. Callbacks after the call returned or from a signal are refused silently, recorded as a reading of 8.4.3 with
    a test (T10:6956-6961; the word "during" is not in the text: W4); the owner may call it a deviation.
  - **Conventions:** `ccall`; `stdcall` as ABI 1 where the target has it, x86 Windows, and refused at compile time
    elsewhere (D27's (i), the owner's pick; about 10 lines, G26); `safe` and `unsafe` read and ignored. A header name
    ending in `.h` is taken as written (D27, E1's N1(b)).
  - **Rune (D27):** G02, the program's own namespace (`dlopen(NULL)` or `RTLD_DEFAULT` on POSIX, the loaded modules on
    Windows, ENOSYS in the none layer; C about 30), with rhc options naming libraries (about 40); G06, `region()`
    taking a SYMBOL of unknown extent, so an `&` import of a C variable can be read and written
    (`runtime/foreign.c:301-305`; C about 5, tests about 30); G07, `dynamic` of a POINTER or CALLBACK identity, not
    only a SYMBOL (`foreign.c:347-351`; C about 10, tests about 40). G09, `vm_raise` stopping at a callback's scope,
    is optional hardening (C about 15).
  - **The Core interpreter:** compiled only, documented (D33's rec); G35 would be about 250 lines over RuneForeign's
    API.
  - Ptr and FunPtr land here as types, for the tests; Foreign.Ptr's operations are M16's.
* **Starts from:** `patches/E10-ffi-prototype.patch`; `results/E10/progs/`.
* **Rests on:** D27, D31, D32. D29 changes nothing here. Under D27's (ii) `stdcall` is read as `ccall` off Windows
  with a warning, as GHC does.
* **Gate:** G02, G06 and G07 change Rune's C (`runtime/foreign.c` and the `sys` layers): every layer answers
  (`AGENTS.md:69-73`); the FFI's suites run on the portability targets (`make test-ffi-portability`, `Makefile:2866`)
  and in the Windows builds (`docs/ffi/runtime.md:34-41`). No primitive or instruction is added, since the operations
  go through `foreign`, so the fingerprint and SML's bytes stay put [inferred: E10 used operations 1 to 10 and 13 of
  the one primitive]; `make bootstrap` and `make perf-check` show it.
* **Done when:**
  - E10's 11 programs of `matrix.tsv` give one stdout at `-O0`, `-O1`, `-O2` and on the stack target, and a second
    run the same (41 runs), in units mode as whole; `Opt.hs` gives one stdout in its seven configurations (md5
    `5c70abe1`): IO calls in order, pure imports lazy and strict in their arguments;
  - `Loop.hs` gives `<<loop>>`, and `Nested.hs`, `Boom.hs`, `Catch.hs` and `Escape.hs`'s 70 exceptions behave as E10
    measured, the wrapper in another unit too (`out/TwoUnits70.units.*`);
  - `Gaps.hs`'s three failures pass: a `dynamic` call of a wrapper's FunPtr, `optind` and `&errno` read, a static
    import with no library named;
  - `Marshal.hs`'s four refusals and two acceptances hold, `Visible.hs` is refused, and imports over Bool, Float and
    Char run (none of E10's programs has them, and its desugarer has no Bool: W4);
  - `stdcall` off Windows is refused with "not supported by rhc"; `Later.hs`'s callbacks after the call are refused,
    by a test;
  - a `--count` budget holds a call's cost against E10's marginal figures: 146.6 VM instructions, 344 bytes and 19
    objects over Haskell's own `abs` (`results/E10/out/units.log:36-42`; W4's recount);
  - chapter 8's 54 changed and new rows leave `Planned`, 8.4.4's `foreign export` and 8.7's HsFFI.h pinned as
    `Planned` by D28;
  - M3's check holds: in 98 mode `foreign import` stays a parse error at `import` and `foreign` an identifier
    (`results/E3/run-programs3/results.tsv`, `foreign1`, `foreign98`).
* **Size:** rhc: the prototype's 643 lines of SML (desugarer 326, the family 218, checker 73, parser 25, `coreprim.sml`
  1; `git apply --numstat`; its other 203 lines are the Foreign sliver and build files), less the parser rewrite,
  plus visibility about 40, HsLint about 80, errno about 30, `stdcall` about 10 and the AST form's walkers: about 800
  to 900 [estimate]. Rune: C about 45, tests about 70 for G06 and G07, G02's not sized (`results/E10/gaps.tsv`, G02,
  G06, G07 [estimates]).

### M16. Foreign.* (14 modules); Ptr per D29; finalizers at exit; StablePtr (V; L to XL, about 2,500 lines of Haskell [E9] and Rune's C about 200 (A) to 330 (B) by D29's option [E10's estimates]; after M14 and M15)

* **Why:** chapters 24 to 37 are the FFI's library, 14 modules with no code in the Report (E9), 277 exported names
  among them (`results/E9/modules.tsv`). Chapter 8's own examples need Ptr, Storable and the C types.
* **What (D29, D30, D33, and the ruling on Foreign.C.Types):**
  - **The modules:** Foreign, Foreign.C, Foreign.C.Error, Foreign.C.String, Foreign.C.Types, Foreign.ForeignPtr,
    Foreign.Marshal and its Alloc, Array, Error and Utils, Foreign.Ptr, Foreign.StablePtr and Foreign.Storable, in
    Haskell over new Core primitives, with no SML below Haskell (98's D26 A), from base 4.3's portable branches
    (BSD-3) with Hugs as calibration (D24).
  - **Ptr, D29, the owner's call.** A (rec): a raw address through a trusted address-level primitive family for rhc's
    Core only, a change of Rune's rule that native addresses stay outside the SML heap
    (`docs/plans/runeffi.md:465-467`): C about 200, SML about 100 and a safety review (G13). It makes Eq, Ord,
    `minusPtr`, `alignPtr`, IntPtr, Storable of pointers and callbacks' pointer arguments exact (G14 to G17 follow
    from it). B: identity plus offset in rhc, about five new operations (G13 names order, difference, alignment
    offset, a view before its parent's start, a canonical identity), canonical identities (G16: 1,000 `getenv` calls
    leave 1,000 live identities, measured), Storable of pointers (G15) and persistent callback pointers (G17);
    `ptrToIntPtr` is then a deviation (G14).
  - **Memory:** rhc's `malloc` and `free` are C's, since Rune's registry-owned allocate freed by C and then by Haskell
    is a double free that glibc aborts, exit 134 (G19, measured); `alloca` over allocate and release, `realloc` as C's
    (G20); allocation failure gives `nullPtr`, by the text (T10:15125; base raises an IOError).
  - **Typed peek and poke primitives,** not bytes assembled in Haskell (D33).
  - **Foreign.C.Types** per target profile, about 150 lines a profile (G27): CChar is unsigned on AArch64 and
    PowerPC64 (`docs/ffi/portability.md:59-61`), so a `.rbc` that uses C types is target-specific. Its newtypes are
    exported with their constructors, on the ground "contradictory": the text says the module does not export them
    abstractly (T10:6911-6912) and its printed list does (T10:14480-14485), which by 8.4.2 would refuse the chapter's
    own `strlen` and `sin` (W4). D23's export lists follow this ruling.
  - **Foreign.C.Error:** the last foreign call's errno, which M15 keeps (G28), not the VM's `sys_errno`, the last
    failed system call's (W2); the constants by `sys_error_of_name`, ~1 for a name it does not know
    (`src/isa/prims.sml:301-302`).
  - **Foreign.C.String:** Latin-1, as base 4.3 (T10:14357).
  - **ForeignPtr (D30's B):** finalizers run at `finalizeForeignPtr` and at program exit, which the text allows ("There
    is no guarantee of promptness", T10:14966-14967): about 60 library lines and an exit hook in rhc's runtime of about
    20 (G21). GC-driven finalization is deferred.
  - **StablePtr:** a table in Haskell, about 40 lines; `castStablePtrToPtr` trivial under A, about 20 lines of C in Rune
    under B (G22; W2).
  - What a peek of a 63-bit Int or Word does with 64 stored bits is a choice recorded here (E9's open question 5).
* **Starts from:** E10's sliver `share/rhc/haskell98/Foreign.hs` (200 lines, the prototype's), `results/E9/modules.md`
  (*Primitives*), `results/E10/gaps.tsv`; `progs/FarPeek.hs`, `progs/Gaps.hs`.
* **Rests on:** D29, D30, D33. Under D29's B, G13's operations and G15 to G17 are Rune's, and `ptrToIntPtr` is a
  recorded deviation.
* **Gate:** a new primitive family (D29's A, or StablePtr's under either) goes through `src/isa/prims.sml` and `make
  isa`, with its C in `runtime/` and every `sys` layer (`AGENTS.md:65-74`), and moves the instruction set's
  fingerprint, which every `.rbc` and image carries (`AGENTS.md:75-77`): bytes move once, by that word, and the
  milestone says so. SML programs' budgets stay put (`make perf-check`). D29's safety review is the owner's.
* **Done when:**
  - the 14 modules' exports equal T10's (`results/E9/exports/`), table-driven;
  - chapter 8's examples compile and run: `strlen` with its CSize result (T10:6936-6937), `sin` over CDouble
    (T10:6945-6946), the `errno` import (T10:7103);
  - `Gaps.hs`'s pointer cases under D29's answer: order, difference, alignment, a pointer peeked from memory (argv);
    under B, no growth of live identities over 1,000 `getenv` calls;
  - `FarPeek.hs`'s read 1 GB past a C pointer stays C's undefined behaviour, documented (status 139, measured);
  - finalizers run at `finalizeForeignPtr` and at exit, once each; a StablePtr round-trips through C;
  - Foreign.C.Types' sizes and signedness are checked per profile on x86-64 and, under `make test-ffi-portability`, on
    Linux x86, AArch64 and PowerPC64;
  - the 767 changed and new rows of chapters 24 to 37 leave `Planned`;
  - M3's check holds; 98 mode has no Foreign module.
* **Size:** Haskell about 2,500 lines (E9: 2,496 new over the 14, Foreign.C.Types 1,100 of them written out, or about
  120 if the library may derive newtype instances: `results/E9/estimate-totals.txt`, which says "15 modules" where
  there are 14: W2). rhc's SML for the primitives not sized. Rune's C under A about 200 and SML about 100; under B
  about 150, with G15's 60 and SML 20, G16's 80, G17's 20 and `castStablePtrToPtr`'s 20, and tests
  (`results/E10/gaps.tsv` [estimates]).

### M17. `foreign export` and HsFFI.h, x86-64 first: only if the owner takes D28's B (V; M, about 600 and tests [E10's estimate]; after G2)

* **Why:** 8.4.4's `foreign export` and 8.7's HsFFI.h are required. Leaving them out is none of D38's grounds, so G2
  records them as `Planned` only on the owner's explicit word (D28's A). This milestone is D28's B.
* **What:** a C-callable stub per export from runeopt's native builds, entering the VM and linked with the program's C
  (G24); a librune embedding API (start, stop, arguments, collect) and a header with Tables 8.2 and 8.3's types and
  limits and 8.7's functions (G25). x86-64 only at first: runeopt has no acceptance on the portability targets
  (`docs/ffi/portability.md:53-54`).
* **Starts from:** no patch. MicroHs 0.16.12, which has `foreign export` and an HsFFI.h, and nhc98 as judges of its
  tests (D28).
* **Rests on:** D28.
* **Gate:** runeopt and the runtime: `make test-opt`, `make test-native`, `make bootstrap`, and the standing gate.
* **Done when:** a C `main` calls exported Haskell functions through HsFFI.h's initialisation and exit, with callbacks
  and exceptions crossing, on x86-64; 8.4.4's and 8.7's rows leave their `Planned` pin on x86-64 and keep it, stated,
  elsewhere; M3's check holds.
* **Size:** runeopt and the runtime about 600 lines and tests (`results/E10/gaps.tsv`, G24 and G25 [estimates]).

### M18. 98 mode: D13a (genericLength); the Rule 1 defect; the signature-generality defect (H; S, a signature, an overlay row and two checks [estimate]; at once, each on the owner's word)

* **Why:** the brief allows bringing 98 mode in line with 2010 where the 98 Report was ambiguous, stated explicitly
  for the owner's review. D13a is the one alignment this roadmap recommends. Two checker defects were found at the
  pin, in each of which HsLint is right.
* **What:**
  - **D13a (R48):** `genericLength :: Num i => [b] -> i` in 98 mode too. 98 contradicts itself (4.5.5 and its example
    need Num; chapter 17's prose and code say Integral); rhc took Integral (`share/rhc/haskell98/List.hs:185`, with
    the overlay's `ov.list.genericlength` "nochange" at `share/rhc/haskell98/overlay.tsv:66`); 2010 takes Num
    (T10:13317). The overlay row becomes a change, R48 records the alignment, and the pristine stays. This edits
    `share/rhc/haskell98`, which *The architecture*'s ownership table otherwise leaves untouched.
  - **Rule 1** (`results/E3/defects/rule1-signed/`): `f :: Num a => a -> a` and `xs = [f (1 :: Int)]`, each using the
    other, are one group under 98's 4.5.1, restricted by `xs`, so `f`'s signature with a context must be refused
    (4.5.5). The checker accepts it (`RUNE_LINT=0` prints `(3,3.5,[2])`); HsLint refuses at level 2
    (`mr.rule1.constrained`). The checker refuses it, in 98 modules: under 2010's groups `f` is a group of its own.
  - **A signature more general than a non-simple pattern binding** (`results/D16-probes/`, PatGen): the checker refuses
    it, as HsLint does at level 2 and GHC does in both modes. The check is M9's, the same code path in both modes.
  - Not here: R20's consequence, an unsigned `main = return ()` refused in 98 mode (E12), a reading left to the owner.
* **Starts from:** E3's `defects/rule1-signed/`, `results/D16-probes/`.
* **Rests on:** D13a, and the owner's word on each defect (*Found while writing this roadmap*). Declined, a defect
  stays, and its test is HsLint's refusal at level 2.
* **Done when:**
  - `genericLength` at a Fractional type is accepted in 98 mode (4.5.5's `len2 = (2*len1) :: Rational`), and no 98
    test changes its verdict (D13a);
  - both defect programs are refused by the checker at `RUNE_LINT=0`, with a message citing 4.5.5 and the signature;
  - M3's check moves only what these decisions name: List's unit in the 98 snapshot and the programs that call
    List's `genericLength`: 5 files of `tests/hs/lang`, 1 of `accept` and 1 of `errors` (grep -w, local copies
    excluded), each listed in the commit.
* **Size:** a signature, an overlay row and a reading; two checks of a few dozen lines each [estimate].

### M19. Lexer- and renamer-only extensions and T0 (X; L, 39 names, 31 sized S and 8 M by E6, none prototyped; after M5)

* **Why:** the most used extensions are front-end ones that need no checker change: LambdaCase in 928 of Stackage LTS
  24.67's packages, RecordWildCards 801, BangPatterns 790, TypeOperators 715, TupleSections 504, ViewPatterns 431,
  NoImplicitPrelude 375 (`results/E6/census.tsv`).
* **What (D35, D36):** the recommended names of tiers `-` and T0 that are neither 2010's own nor another milestone's,
  39 in all, as *The extensions* lists and groups them: literals and layout, records and modules, one expression node
  each, patterns and strictness, types in the front end. Each is a feature of M4's record under its GHC name (D4),
  off unless asked. The 18 that change valid 2010 programs come with their conservativity test (D36); BangPatterns'
  `!` rule holds only when it is on. Trustworthy and Unsafe are accepted as markers, two Safe modes refused (C1).
  Inside the milestone: the lexical names need M5 before rhc lexes; MultiWayIf follows M8; EmptyCase pairs with M7's
  empty types; StandaloneKindSignatures needs a `Type` the 2010 library lacks; GADTSyntax's existential constructors
  come with M25 and LiberalTypeSynonyms' forall in a synonym with M26 (*The extensions*).
* **Starts from:** no patch. X1's probes (`results/E6/X1-probes/`, `X1-data/probes.tsv`), E5's P14 and P18, E8's
  `extcorpus.tsv`.
* **Rests on:** D35, D36, D7.
* **Done when:** for each name, its accept and reject programs from the extension corpus and its own; on and off by
  pragma and by `-X`; HsLint clean at level 2; a meaning-changing name's probe (off, 2010's answer, cited; on, the
  extension's); for the others, the 2010 corpus byte-identical with the name on (the standing gate); M3's check holds,
  since a 98 module reads no such name.
* **Size:** 39 names, 31 S and 8 M on E6's scale (`results/E6/census.tsv`, `schema.md:23`), none prototyped
  [estimate]. The only measured rate for a front-end feature is E3's: 2 to 110 code lines each.

### M20. CPP, a subset in SML (X; M to L, about 1,000 [inferred]; after M5)

* **Why:** CPP is on in 46.6% of Stackage's packages and 18.6% of its files, the most used name, but only 1,123 files
  (2.3%) need it and nothing else (E7); E8's filter loses 64 of nofib 2025's 170 programs to it (D40).
* **What (D12's A):** off unless asked; conditionals (`#if`, `#ifdef`, `#ifndef`, `#elif`, `#else`, `#endif`) with
  integer expressions and `defined()`, `lib/language/c`'s `CConst` serving the directive line's expression
  (`lib/language/c/const_sig.sml:4-25`; W9), since that library's lexer cannot read Haskell; object- and function-like
  `#define` and `#undef`, expanded in code, in traditional mode so Haskell's tokens pass; `#include` confined to the
  program's own directory; every directive line and skipped line blanked, not dropped, so positions hold (`cpp -P`
  takes 122 lines to 82: E3's `cpp/lines.tsv`). rhc defines no `__GLASGOW_HASKELL__`, and `MIN_VERSION_x(...)` is false
  for every package rhc lacks, a decision of its own here. The header is read again after CPP, as GHC does
  (`ghc/compiler/GHC/Driver/Pipeline.hs:711-735`), the first read's warnings dropped (E13's model fix); C10, CPP in a
  literate file, after unlit. Where the subset lives is the owner's rule on generic code under `lib/` (D12).
* **Starts from:** E3's `cpp/` (census, 16 samples, `probe.tsv`, `lines.tsv`).
* **Rests on:** D12. Its fallback is C, a refusal, as 12.3's error.
* **Done when:** E3's 16 samples give `ghc -cpp -E`'s text with every line at its own number, but for the 2 (s10, s15)
  whose `__GLASGOW_HASKELL__` tests change the text, which differ by design (`results/E3/cpp/probe.tsv`); E5's P13b and
  P13c are tests; a planted `#include` outside the program's directory is refused; nofib's filtered programs that use
  conditionals only compile [inferred]; M3's check holds (CPP in a 98 module is not read).
* **Size:** about 1,000 lines [inferred: cpphs is 1,100 lines of Haskell, 1,318 with its parser library,
  `results/E11/cpphs-wc.txt`, via D12], less what `CConst` serves.

### M21. Deriving: StandaloneDeriving, DeriveFunctor, DerivingStrategies, DeriveAnyClass, EmptyDataDeriving; GND and DerivingVia (a whole-dictionary Cast); DefaultSignatures (X; L, 8 names, 4 S and 4 M by E6, none prototyped; after M5, GND, DerivingVia and DefaultSignatures after M22)

* **Why:** GND is in 892 packages, StandaloneDeriving 580, DeriveFunctor 442, DerivingStrategies 379, DefaultSignatures
  337 (`results/E6/census.tsv`).
* **What (D35, D37):** the T0 names as trees made by the deriving scheme, which the checker and HsLint see as a user's
  instance (*The extensions*); EmptyDataDeriving over M7's empty types. GeneralizedNewtypeDeriving and DerivingVia
  reuse a dictionary through a Cast of the whole dictionary, where Core's `Cast` goes only through a newtype's head
  today (`lib/language/haskell/core_sig.sml:73`; D37), a Core change of rhc's, not Rune's. DefaultSignatures: a default
  method's own context, checked at each instance that uses it. C6: GND with DeriveAnyClass picks DeriveAnyClass, with a
  warning, as GHC. **The split:** the five T0 names follow M5; GND, DerivingVia and DefaultSignatures follow M22, since
  E6 puts them at T1: GND and DerivingVia pay mostly with classes of several parameters (`deriving (MonadState s)`),
  and DefaultSignatures' real contexts (`Generic a`, `MonadTrans t`) are beyond 2010's.
* **Starts from:** no patch.
* **Rests on:** D35, D37.
* **Done when:** each name's programs from the extension corpus; CoreLint at level 2 accepts the whole-dictionary Cast,
  and HsLint checks it independently; the 2010 corpus byte-identical with each name on (none changes valid programs,
  E5's P18n for GND); M3's check holds.
* **Size:** 8 names: S for StandaloneDeriving, DerivingStrategies, DeriveAnyClass and EmptyDataDeriving, M for
  DeriveFunctor, GND, DerivingVia and DefaultSignatures (E6), none prototyped [estimate].

### M22. A+ and T1: the deferred class store; MPTC, FlexibleInstances, FlexibleContexts, TypeSynonymInstances, ConstrainedClassMethods, UndecidableInstances, overlap pragmas; OverloadedStrings (X; L, 1,101 added and 964 code lines measured in E12, about 1,600 to 2,400 [estimate]; after M5)

* **Why:** OverloadedStrings is in 1,499 packages, FlexibleInstances 1,300, FlexibleContexts 1,148,
  MultiParamTypeClasses 933, UndecidableInstances 687 (`results/E6/census.tsv`). D34's A+ is what they need, and E12
  measured it enough through T5.
* **What (D34, D35):**
  - **A+:** today's unifier plus a deferred store of class constraints solved at generalisation. A wanted with unsolved
    variables that no instance matches is deferred, not refused as `solve` does today
    (`lib/language/haskell/infer.sml:317`); a given that could unify with a wanted defers it; one with no variables
    and no instance is still an error.
  - **Predicates of n parameters:** `pred = {cls, tys}`, not the prototype's pseudo-tuple (about 68 predicate sites in
    the checker and 61 `IsIn` sites in HsLint, by E12's grep); classes with their kinds and superclasses, instances
    with heads matched one way, an instance's identity its flat head; dictionaries data types of n parameters.
  - **The names:** MultiParamTypeClasses, FlexibleInstances, FlexibleContexts; TypeSynonymInstances (expand, then 98's
    head test, where the checker and HsLint refuse today: `infer.sml:1711, 1733`, `hslint_env.sml:711`);
    ConstrainedClassMethods (`infer.sml:1674`, `hslint_env.sml:635`); UndecidableInstances, lifting the Paterson
    conditions with a depth bound of 200; overlap with the OVERLAPPING, OVERLAPPABLE and OVERLAPS pragmas, which E12
    did not build; OverloadedStrings at T1 through an instance at `[Char]`, IsString reaching D20's defaulting.
  - **HsLint independently:** deferral in its `toHnf`, flexible heads, the replay of flexible instances, superclasses of
    multi-parameter classes and their target checks; its fault injections (`dict super`, `super`) wired on the new
    paths, which E12 did not do.
  - **Separate compilation, E12's gap:** HsLint's codec carries the class and instance extras, and the interface its
    option fields. With a store, E12's two-module program died with an uncaught `Subscript` at `RUNE_LINT=2` once a
    unit was taken (`results/E12/units/log.txt`); with M25's half, about 50 to 150 lines [inferred, E12]. E12's extra
    byte per class and instance changes store bytes and `--dump-iface`, not bytecode: either a 98 class keeps its
    encoding, or D9 records the change.
* **Starts from:** `patches/E12-T1.patch`, its `RHC_E12` switch replaced by M4's features.
* **Rests on:** D34, D35, D7's C4.
* **Done when:**
  - E12's T1 programs give GHC's output on the interpreter and at `-O0` to `-O2` at `RUNE_LINT=2`, and its refusals are
    refused by both checkers (`results/E12/programs-rhc/results.tsv`);
  - GHC's typecheck tests for T1 (`results/E12/ghc/select-T1.tsv`): E12's 7 of 10 should_compile and 19 of 19
    should_fail at least, and the 3 that need overlap now pass;
  - a two-module MPTC program through a store at `RUNE_LINT=1` and `2`;
  - with T1 on, `tests/hs/lang`'s 591 and the run set's 354 bytecode files unchanged, as E12 measured, and
    `tests/hs/errors`' 26 newly accepted programs and 12 new messages listed and pinned
    (`results/E12/identity/t1on-errors/`), each a restriction T1 lifts;
  - M3's check holds with the code in and the features off (E12: 591, 633 and 354 unchanged).
* **Size:** 1,101 added lines, 964 of code: checker 394, HsLint 428, desugarer 84, front end 25, interfaces 18, switch
  15 (`results/E12/areas.tsv`). About 1,600 to 2,400 in production, one refactor whose rows are not summed by name
  [N's estimate, 1.5 to 2.2 times, inferred]; overlap and OverloadedStrings M each by E6, unbuilt.

### M23. T2: FunctionalDependencies (wanted-only improvement; the coverage condition) (X; M, 512 added and 446 code lines measured, about 800 to 1,200 [estimate]; after M22)

* **Why:** FunctionalDependencies is in 383 packages, most of them with MultiParamTypeClasses; mtl needs it, the Report
  does not.
* **What (D34, D35):** improvement as unification repeated to a fixpoint, from instances, from the givens' superclass
  closure and between pairs of wanteds, superclasses included (Jones 2000, 6.2), in the checker and again in HsLint;
  ambiguity judged modulo the dependencies (6.3); determined variables not generalised (6.4); consistency checked
  pairwise; the dependencies in a field of the class declaration, not E12's side table (about 26 mechanical edits).
  Improvement from a given is refused: Karachalias and Schrijvers's example, which GHC refuses too. **Coverage, the
  owner's (D35):** Jones's condition by default; under UndecidableInstances the recommendation is the Paterson
  conditions kept plus Sulzmann et al.'s Terminating Weak Coverage, which admits mtl and refuses GHC's looping `Mul`
  (not built), over GHC's depth bound alone.
* **Starts from:** `patches/E12-T2.patch`.
* **Rests on:** D34, D35.
* **Done when:** E12's T2 programs, `programs/t2/mtl.hs` among them, give GHC's output; GHC's tests: E12's 27 of 32
  should_compile and 16 of 16 should_fail at least, the 3 that need empty data passing in 2010 mode and the 1 that needs
  overlap after M22; GivenOverlapping recorded under R20's reading; `cls.inst.ctx.vars`'s new message pinned; M3's
  check holds.
* **Size:** 512 added lines, 446 of code: checker 285, HsLint 126 (`results/E12/areas.tsv`); 800 to 1,200 in production
  [N, inferred].

### M24. T3: ExplicitForAll, ScopedTypeVariables, TypeApplications, AllowAmbiguousTypes, InstanceSigs; HsLint's skolems (X; M to L, 5 names, 2 S and 3 M by E6, not prototyped; after M22)

* **Why:** ScopedTypeVariables is in 1,401 packages, TypeApplications 625, AllowAmbiguousTypes 265, InstanceSigs 210
  (`results/E6/census.tsv`); D35 lands them as one group.
* **What (D34, D9, D36):** schemes keep the user's variable order and tell specified from inferred variables; a scope
  of type-variable names reaches expressions, pattern signatures and class and instance bodies; HsLint gains the rigid
  variables its second inference lacks (`hslint_infer.sml:698-722`), which M25 and M26 reuse. 98 mode keeps
  `schemeOf`'s order (`infer.sml:578-601`), since it is Core's binder order and 98's bytes must hold. The order enters
  the interface (D9), as M22's class and instance extras do. `forall` is a keyword in types only under
  ExplicitForAll and what implies it (D36): E12's T5 switch reserved it everywhere and so accepted `ty.quant.noforall`.
* **Starts from:** no patch. X2's notes (`results/E6/X2-notes.md`), X1's `forall.hs` and `stv.hs`.
* **Rests on:** D34, D9, D36.
* **Done when:** each name's programs; `forall.hs` judged against the Report, not GHC, which reserves `forall` in every
  mode; `stv.hs`'s change of meaning only when on; a module under TypeApplications exports its order, and a client in
  another unit applies it; HsLint clean at level 2; M3's check holds.
* **Size:** 5 names, not prototyped: ExplicitForAll and AllowAmbiguousTypes S, ScopedTypeVariables, TypeApplications
  and InstanceSigs M (E6) [estimate].

### M25. T4a: existentials with contexts on existential variables (AltCon binders) (X; L, 586 added and 505 code lines measured, about 1,000 to 1,500 [estimate]; after M24)

* **Why:** ExistentialQuantification is in 302 packages; T4a is the part System F can elaborate (D34, D37).
* **What (D34, D37):** a constructor `forall a. ctx =>` whose context is on its existentials only; a context on a
  universal variable refused as T4b's, for the OutsideIn roadmap (E12's `programs/t4-fail/mkr.hs`, which GHC 9.4.7
  accepts with a non-principal type). A pattern binds the existentials as skolems a level deeper and the context as
  givens; a scope for local skolem givens at case alternatives, clauses and lambdas solves the wanteds there and
  catches escape. Pattern bindings of existentials and deriving refused. Core: type binders in AltCon and Data (D37;
  E12's `AltConEx` and convention), CoreLint's arity and escape checks; CoreToMid erases hidden types to Mid's unit
  with casts, no Mid change. Sestoft's matcher hands such clauses to the Report's order. Beyond the prototype:
  existential record fields, the simplifier's known-constructor reduction against an existential alternative, and
  separate compilation: the constructor's existentials through the desugarer's unit data, which E12 lost across a unit
  ("HsDsCore: Conv.Box at 1 types" at `RUNE_LINT=1`: `results/E12/units/log.txt`).
* **Starts from:** `patches/E12-T4.patch`.
* **Rests on:** D34, D37.
* **Done when:** E12's T4 programs on every way at `RUNE_LINT=2`; GHC's 6 of 6 should_fail refused, T10856 refused by
  design, `update-existential` accepted once record fields and NoImplicitPrelude (M19) exist; a two-module program
  through a store; M3's check holds.
* **Size:** 586 added lines, 505 of code, Core's share 133 code lines in 13 files (`results/E12/areas.tsv`); about
  1,000 to 1,500 in production [N, inferred].

### M26. T5: RankNTypes with simplified subsumption (X; L, 450 added and 394 code lines measured, about 1,500 to 2,500 [estimate] with CoreToMid's boxing; after M24)

* **Why:** RankNTypes is in 967 packages (`results/E6/census.tsv`). Every census name at T5 or below, whatever its
  recommendation, would admit at most 42.6% of whole packages, a ceiling and not a set; the recommended set admits
  28.3% (`results/E7/tier-needs.tsv`).
* **What (D34, D37):** a forall in `HsTypes.ty` through unification, zonking, generalisation, printing, interfaces and
  desugaring; an argument whose parameter is a polytype checked against it, its variables rigid, desugared to type and
  dictionary lambdas, System F with no coercions; simplified subsumption only, annotations required; a binding to an
  impredicative type refused. Beyond the prototype, for GHC's tests: a forall in a result skolemised against a clause's
  further patterns (10 of the 20 failing should_compile tests need it), polytypes through synonyms, contexts in nested
  types, patterns on polytypes. **Mid is in scope:** MidLint allows a polymorphic type only as a field or a tuple
  component (`lib/compiler/core/midlint.sml:213, 222`), so E12's `rank2.hs` failed at `-O0` and `-O1` with "the type of
  v4357 is polymorphic, ... other than as a field" and ran at `-O2` only because the simplifier removed the binder
  (`results/E12/programs-rhc/results.tsv:66-67`). CoreToMid boxes a polytype value in a one-field datatype, as
  dictionaries are (D37's rec); rank-N in Mid instead is a Rune change and a decision. HsLint the same, with its own
  forall and escape checks.
* **Starts from:** `patches/E12-T5.patch`.
* **Rests on:** D34, D37. A probe of GHC needs `-XNoDeepSubsumption`, since its Haskell2010 edition turns
  DeepSubsumption on (*The extensions*).
* **Done when:** `rank2.hs` at `-O0`, `-O1`, `-O2` and on the interpreter; GHC's should_compile for T5 well past E12's
  11 of 31, and 17 of 17 should_fail, T18455's SPECIALISE instance pragma refused; a program with no forall types as
  in 2010 ("Programs containing no foralls are typeable if and only if they are typeable in Haskell 98", as *The
  extensions* cites it), by the 2010 corpus's bytes; M3's check holds.
* **Size:** 450 added lines, 394 of code (`results/E12/areas.tsv`); about 1,500 to 2,500 in production, of which
  CoreToMid's boxing about 200 to 400 [N, inferred]. The largest of the four tiers (D35).

### M27. T8: NoMonomorphismRestriction, MonoLocalBinds (X; S, 2 names sized S by E6, not prototyped; any time after M9)

* **Why:** NoMonomorphismRestriction is in 163 packages and MonoLocalBinds in 72 (`results/E6/census.tsv`); D35 puts
  T8's policy before T1. RelaxedPolyRec, T8's third recommended name, is 2010 itself (M9).
* **What (D35, D36):** both change how a group is generalised, in the checker's `implicitGroup` (`infer.sml:1336`),
  HsLint's `tiImpls` (`hslint_infer.sml:811`) and the replay's `bindg` rule, beside M9's edge filter.
  NoMonomorphismRestriction generalises a restricted group and drops Rule 2 (Rule 1's test is at `infer.sml:1376`);
  MonoLocalBinds generalises a local group only if its free variables are closed. Both are per module, by D10's
  lookup, and both change valid programs, so each is opt-in with its test.
* **Starts from:** no patch. X1's `monolocal.hs`; X2's example for the restriction's No form.
* **Rests on:** D35, D36, D10.
* **Done when:** `monolocal.hs` and a probe written from X2's example (`big = 2^64` an Int under the restriction and an
  Integer without it); mixed-cycle tests in the checker and in HsLint; M3's check holds.
* **Size:** 2 names, S each (E6), not prototyped [estimate].

### M28. The default flip (D; S, about 6 lines and 77 lines of docs [E4]; after G2)

* **Why:** the brief: "default to 2010 after the roadmap is complete". D3 reads that as G3, which rests on G2 and on
  every 98 harness pinned to 98; track X never gates it.
* **What (D3):** rhc reads `RHC_LANGUAGE` as it reads `RHC_STORE` (`src/rhc/storeconfig.sml:49`), and
  `bin/rune-test`'s wrapper sets it to haskell98 beside `RHC_STORE=` (`Makefile:2240`); the 2010 suites pass
  `--language=haskell2010` themselves. Then E4's two defaults, `RhcSyntax.edition` and `RhcLibrary.current`, become
  haskell2010. The Makefile's rhc lines that run outside the wrapper are pinned where they are: the snapshot rule
  passes each library's language (M6), and `test-rhc-mutants` runs through `bin/rune-test` (`Makefile:2306-2307`), so
  under the wrapper's variable. The documents' 77 lines that name an rhc command, `docs/rhc.md` the most, and
  `tests/hs`'s 8 say which language they mean.
* **Starts from:** `results/E4/flip-inventory.tsv`, `cost.md`.
* **Rests on:** D3. Under D3's (ii), `--language=haskell98` at about 60 call sites in 19 files instead (the 52
  invocation lines and 9 helpers), besides 14 Makefile lines.
* **Done when:** G3's checks pass.
* **Size:** about 6 lines in rhc and the wrapper [E4, inferred], and the docs. The inventory: 52 invocation lines in 17
  runner files through 9 helper definitions, 14 Makefile lines that run rhc, 77 lines of docs and 8 in `tests/hs`
  (`results/E4/flip-inventory.tsv`, counted).

### M29. Retire: docs, *At the close* (D; S; after M28)

* **What:** into `docs/`, what stays true: `docs/rhc.md` (both editions, `--language`, the pragmas, rhc's own
  features), `docs/language.md`, `docs/testing.md` (the 2010 table, suites and tiers, the standing check),
  `docs/units.md` (keys with languages); *At the close*, as earlier roadmaps did, with what the roadmap promised and
  what it gave; the worktrees `h10-f`, `h10-a`, `h10-v` and `h10-n` removed with the owner's word.
* **Done when:** `make check-docs` passes and *At the close* is written.

## Gates

**G0: the owner's decisions.** Not passed. The owner decides D1 to D41 (*Decisions*). The items that are the owner's
call, with the milestone each holds:
- D2 and D6, which change 98 mode at its edges (M6, M5); D3, the flip's timing against the brief (M28);
- D8, folding `--names=greatest` and the 958-to-955 change it brings (M4);
- D13a, and the two checker defects of *Found while writing this roadmap* (M18); D13b to D13d, recommended no;
- D16's reading of a signed variable of a non-simple pattern binding, and D7's C8 (M9);
- D21, Int under 2010, with ``minBound `quot` (-1)`` and the shift reading (M11);
- D23, the library's cycle (M12);
- D27's pick for `stdcall`, and D31's callbacks outside a call as a reading or a deviation (M15);
- D28, `foreign export` left `Planned` at G2 by the owner's explicit word, or M17 (M17);
- D29, Ptr, a change of Rune's model under A (M16);
- D32's Foreign.C.Types constructors and D33's compiled-only FFI (M15, M16);
- D35, the regime of fundeps under UndecidableInstances (M23);
- D37's T4b and boxing or rank-N in Mid (M25, M26);
- D38's N18 (98's unabsorbed errata on 2010's identical text) and N21 (how a program ends) (M1, M12, M14);
- for the owner with no milestone unless taken: R41 and R87's re-reading of derived Show of records, and R20's
  consequence in 98 mode.

*Exit:* every row of the decisions table records the owner's word and its date, and no milestone's **Rests on** names
an item still open. M1, M2 and M3 may start before it.

**G1: hello.** A 2010 program with a pattern guard, from the 2010 snapshot, on the Core interpreter and on the VM, with
98 mode byte-identical. It needs M4 to M8, M10 and M12 (M10 for the library's hierarchical modules: *The order*). The
program:

```haskell
main :: IO ()
main = putStrLn (greet (Just "world"))
  where greet m | Just w <- m = "hello, " ++ w
                | otherwise   = "hello"
```

*Exit, each a command or a job:*
1. `bin/rhc --language=haskell2010 --show-units hello.hs` runs it on the Core interpreter and prints `hello, world`,
   and every library unit is taken from the layer's 2010 configuration;
2. compiled at `RUNE_LINT=2` to register and stack bytecode, it prints the same on `bin/runevm` and `bin/runevm-stack`,
   checked as the interpreter-against-VM jobs check (`tests/runner/hsinterp.sml`, `hs-interp-vm`), with `jitProbe`'s
   rule that a run printed what it should (`tests/runner/oracles.sml:489`);
3. under `--language=haskell98` the same file is refused at the guard's `<-`;
4. M3's per-change check passes over its four sets and the 11 vendored files.

G1 says nothing of conformance.

**G2: the 2010 Report.** M1 to M16 stand behind it. Each line is a test or a family of tests [the names under
`hs2010` are proposals]:

| Exit | Check |
|---|---|
| Every normative clause has a test or a pinned deviation | `hs2010/conformance`: the table's enforcement over `tests/hs2010/conformance.tsv` with no row `Planned`; 8.4.4 and 8.7 `Planned` only by D28's word, and declared so |
| Every shared program right in both modes | the `hs2010` suites over `tests/hs/{lang,errors,accept}` under `--language=haskell2010` and over `tests/hs2010/{lang,errors,accept}`: every program to its `.expected` |
| The judges' disagreements explained | `hs-oracles` nightly over E8's 2010 sets with g10, gbase, MicroHs, Hugs and nhc98: each difference a line of `tests/hs/oracles.txt`, g10's nine limits among them |
| The corpus | E8's 1,279 accept rows compile under 2010 rhc or each is a line with its reason (the 51 programs with 98 names 98-only); its 882 reject rows are refused; Hackage's 355 components that g10 accepts compile, nightly, never run |
| The run programs right | the 25 new 2010 run programs in 98's D56's three ways; those of 98's D56's run set that are 2010 programs, under 2010 too |
| The library's diff from the Report empty but for its overlay | the token comparison of `share/rhc/haskell2010` against its pristine; the export table of E9's 620 items and 686 names over 30 modules |
| HsLint, CoreLint and MidLint clean at level 2 | every `hs2010` suite under `RUNE_LINT=2` |
| rhc's mutants caught | `make test-rhc-mutants`, 98's mutants and 2010's (*Testing and conformance*): no `UNCAUGHT` |
| The FFI on every platform Rune's FFI runs on | chapter 8's and Foreign.*'s tests natively on x86-64, under `make test-ffi-portability` on Linux x86, AArch64 and PowerPC64 (`Makefile:2866`), and in the Windows builds (`docs/ffi/runtime.md:34-41`), `stdcall` through ABI 1 on 32-bit Windows |
| All of it on both bytecodes, every tier and gc-stress | the nightly ways |
| 98 mode unmoved | the standing gate's checks below |

The FFI's line reads RULINGS' "the FFI on every platform D27 names" as the targets Rune's FFI is built and tested on,
since D27 itself names only x86 Windows (for `stdcall`) and the posix, Windows and none layers (for G02). Sharing
budgets, generators and conservativity tests are tests from their milestones on, and no line of this exit.

**G3: the default flip.** After M28.
*Exit:*
1. G2's checks pass on the commit;
2. `bin/rune-test list` names the same jobs before and after the flip, and the 98 check tier gives the same results,
   with `RHC_LANGUAGE` coming from the wrapper; a 98 job that changes is a missing pin, and the gate is not passed;
3. M3's check passes between the rhc before the flip, run bare, and the rhc after it, run with
   `RHC_LANGUAGE=haskell98`;
4. `bin/rhc` with no `--language` and no `RHC_LANGUAGE` runs G1's hello and refuses an n+k pattern;
5. no document line names an rhc command without saying which language it means (the 77 of the flip inventory,
   re-read).

Track X gates neither G2 nor G3.

**The standing gate.** After any change of this roadmap, 98 mode's output, the budgets and SML's bytes stay put unless
a decision says otherwise, and that decision says by how much.
- **98 mode's output:** M3's per-change check is in every milestone's **Done when**: `tests/hs/lang`'s 591 programs on
  both targets at `-O1` and `-O2`, the run set through its harness, `tests/hs/errors` and `tests/hs/accept` with all of
  stderr, the four views, the 98 snapshot's entries and keys, and the 11 vendored files with pragmas compiled
  unblanked. Nightly, the manifest of canonical Core, messages and views. What may move is only what a decision names:
  M18's D13a and, on the owner's word, its two defects; M4's `hs/names/imp/greatest` under D8.
- **Budgets:** `make perf-check`'s SML budgets and `tests/hs/perf`'s ratio budgets; none is re-based to let a change of
  this roadmap pass unless a decision gives the figure.
- **SML's bytes:** a change to Rune (M15, M16, M17) passes `make bootstrap` and `make check-cross`, and, where it means
  to leave the compiler's output alone, the 98 roadmap's test: the edited compiler on the sources before the edit gives
  that tree's `bin/rune.rbc` (haskell98.md:7862-7867). A new primitive moves the instruction set's fingerprint once, by
  one word, which M16 states.
- **Extensions:** one that changes no valid 2010 program leaves the 2010 corpus's bytes unchanged when it is turned on;
  one that does is off unless asked, with its conservativity test (D36). *Testing and conformance* gives both tests.

## Testing and conformance

The 98 roadmap built rhc a test system for one edition: a clause table held to its programs both ways, suites by
directory, oracles that find disagreements, a lint with a second inference, round trips, self-oracles, generators and
mutants (haskell98.md:7939-8260). A second edition reuses all of it. What it adds is four things the first never
needed: a second table whose rows and programs are shared with the first by clause id; a check, standing like the 98
roadmap's gate on SML's bytes, that 98 mode does not move; tests that an extension changes nothing it should not; and
tests of the tracking design itself, which has no counterpart in 98. Path names under `tests/hs2010/` are proposals;
everything else cites `75ed95861`.

### What rhc has, and what a second edition must generalise (M1)

*Where we are* gives the inventory: the table, its enforcement, the 20 directories of `tests/hs`, their runners. Each
piece below is bound to one edition by a constant, a path or a namespace. The judges and comparisons are
language-free.

| What | Where | Bound to | 2010 needs |
|---|---|---|---|
| The table's enforcement | `tests/runner/hsconformance.sml:44-58` | `clauses = 3901` (`:48`), `errataCount = 18` (`:49`), `readings = 54` (`:57`), `dirs = ["lang", "accept", "errors"]` (`:58`) | A record per table: its file, its row count, its errata count (0 for 2010: E1, `errata2010.md`), its reading ids (R1-R54 and 98's later ones; 2010 adds N1-N21), its directories |
| The table's files | `tests/runner/hsconformance.sml:100, 150, 196-198, 344-349` | `tests/hs/conformance.tsv`, `errata.tsv`, `deviations.tsv`, `readings.md` | The same four under the record's root |
| A program's ids | `tests/runner/hsconformance.sml:121-123` (the file name before its first `_`, then the first line's `-- rows:`), rule 2 at `:260-266` | one namespace: a program naming no row of the table fails | Directories of their own for programs of 2010 rows, or rule 2 fails them in 98's table |
| The suites | `tests/runner/hslang.sml:94-114` | `group = "hs"`, `tests/hs/{lang,errors,accept}`, compilers `bin/rhc` and `bin/rhc --target=stack` | A second `Lang.suite` record, group `hs2010`, its compilers passing `--language=haskell2010`; `RUNE_HS_RHC_FLAGS` (`:91`) is one knob for every compile and cannot be the mechanism |
| Tiers of a program | `tests/runner/hslang.sml:80-87` | errors in `check` and `quick`, `late` programs nightly | Kept; the 2010 suite takes the same function |
| The library's checks | `tests/runner/hslibrary.sml:39` | `share = "share/rhc/haskell98"` | Per edition: the 2010 pristine (the Prelude's and four modules' printed code), its overlay, its names table (E1's 686 exported names over 30 modules) |
| Unit names | `tests/runner/hsunits.sml:260-261, 280, 476`; `tests/runner/hsmeta.sml:302` | the string `haskell98:` | The edition's unit prefix |
| The judges | `tests/runner/hsoracles.sml:1-10, 27-36` | the 98 strict shim, E7's and E8's 98 sets | The 2010 shim (g10) and E8's 2010 sets, beside 98's |
| rhc in the corpus harnesses | `tests/runner/hsrhccorpus.sml:39` | `RUNE_HS_RHC`, else `bin/rhc` | Kept: it is how the 98-mode check below captures every bytecode |

**Reused unchanged:** `Lang`'s siblings and judges (`.expected`, `.cargs`, `--typecheck-only` agreeing with the
compile), `Expectations`, the oracle file's format and its strict categories, the round-trip harness, HsLint's dumps
and shards, the mutant machinery, the ratio budgets of `tests/hs/perf` (ratios hold across modes as they hold across
machines: `tests/runner/hsperf.sml:1-14`).

**Default flip.** Until G3 the default stays 98, so the 98 suites need no flag and the 2010 suite passes one. The flip
needs every 98 harness pinned to `--language=haskell98` first: E4 found no single place that runs rhc
(`results/E4/flip-inventory.tsv`), and D3 recommends one default, `RHC_LANGUAGE`, set in `bin/rune-test`'s wrapper.
The 2010 suite passes `--language=haskell2010` itself, so it never rests on that default. A 98 job that changes when
the default changes is a missing pin, and G3 is not passed while one does.

### The 2010 table (D38, M1)

E1's `clauses2010.tsv` is the table's first reading, built as 98's E9 was: 5,259 rows, of which 2,736 are `same` (the
98 id kept), 912 `changed` (a new id, `.h2010` or the 2010 module's name; `map98` the 98 row), 1,358 `new` and 253
`removed-in-2010` (the 98 id, no 2010 text) (E1, `clauses2010-counts.tsv`). Every one of the 3,901 98 ids is in some
row's `map98` (recounted). The 5,006 rows that are not removed test by run 2,566, accept 1,764, reject 568 and none 108
(counted). It lands as `tests/hs2010/conformance.tsv`, with 98's columns plus `map98` and `delta`, every row `Planned`,
and a row leaves `Planned` as 98's did: when its program exists and the judges have seen it.

**Shared by clause id.** A `same` row's program is 98's. A program of `tests/hs/{lang,errors,accept}` serves the 2010
table when every id it names is a 2010 row, and the 2010 suite runs it under `--language=haskell2010` to the same
`.expected`. That is most of the 98 suite: under E3's spike 1,454 of 1,475 programs of `errors`, `lang` and `accept`
gave the same verdict and message in 2010 mode (E3, `flips/flips.tsv`). What is left to write is the changed and new
rows: 2,270, of which 51 test nothing, so 2,219 need programs, 1,756 of them generated rows (productions, exports,
library entities) and 463 by hand (counted). 817 of the 912 changed rows are a 98 row under a renamed module
(`note` says `rename`, e.g. List to Data.List; counted), so their programs are 98's with the imports rewritten, a
mechanical step the generator does [inferred, not built]. The 2010 library offers no 98 module names (D38).

**The 21 that flip.** E3 ran the 98 suite in 2010 mode: 6 programs are accepted that 98 refuses, 5 refused with
another message, 10 refused that 98 accepts (n+k 10, the dotted lexer 3, DoAndIfThenElse 3, empty data 3, `foreign`
1, relaxed groups 1: `flips/attribution.tsv`). Set against E1's table (counted):
- 12 are named by rows that 2010 changes or removes: 7 changed (`lex.qual.twodots`, `lex.reserved.notspecial`,
  `syn.pat.1`, `dec.data.noconstructors`, `exp.if.do.semi`, `mod.name.modid`, `syn.r.dataconstrs`) and 5 removed (the
  n+k rows). These stay 98-only, and their 2010 rows get programs of their own.
- 9 are named by rows E1 marks `same`. Four use n+k on the way to another clause (`dec.bind.patvsfun`,
  `pat.ctx.lambda`, `dec.note.funbind.plus`, `exp.free.eq`): a 2010 program without n+k. Two keep their clause and
  change their message (`kind.implicit`, `lex.qual.modname`): a 2010 `.expected`. One tests a clause 2010 keeps but no
  rhc program reaches under relaxed groups (`dec.gen.sig.identical`, 4.5.2's identical contexts: D16): its 2010 row
  is `none` with that reason, or a pattern binding of two signed variables. Two are E1's error:
  `lay.parseerror.doif` and `lay.parseerror.thensamecol` say `do { if a ; then b ; else c }` is refused, which
  DoAndIfThenElse makes legal, and E1's own new rows `exp.if.semi.*` say so. They should be `changed`.

So sharing by id needs a check the row's `delta` cannot give: **every shared program runs in both modes**, and one
whose 2010 result differs is a failure until it is split or its row corrected. The flips also check E1's default of
`same` for chapters 1 to 11, which rested on the text alone.

**Errata and readings.** No errata to the 2010 Report were ever published; ten mistakes were reported on the
haskell-prime list from 2010 to 2019, none fixed in the text (E1, `errata2010.md`). So the 2010 errata file is empty
and its count 0. Three questions D38 settles become rows:
- **98's unabsorbed errata (N18).** Eight of 98's 18 errata are not in 2010's text, which is otherwise 98's; they name
  12 rows of the 98 table (`tests/hs/errata.tsv`). Under D38's recommendation each applies to 2010's identical text,
  as a reading on the "wrong" ground, and 98's pinning programs serve both tables unchanged. If the owner declines,
  the two code errata change behaviour (`enumFrom` on Float and Double strict or lazy; `lex "_foo"` one lexeme or two)
  and need 2010 programs of their own. GHC's base takes the printed code's reading for the first and the erratum's
  for the second (E1, probes `n18a`, `n18b`), so it judges neither choice.
- **The code chapters' defects (N11)** are overlay entries of `share/rhc/haskell2010/overlay.tsv`, held by the 2010
  library's overlay job as 98's are: Data.Ratio's missing parenthesis, the header `module Array (`, and Data.Maybe's
  second `maybe` (D23; *The libraries*). Data.Complex's `Complex(:+)` is in the chapter's synopsis, not its code,
  which has `Complex((:+))` (E1, `libs/code2010/Data.Complex.hs:1`). The Ix law's stray parenthesis and 20.4.3's
  typesetting losses are prose: readings on their rows.
- **How a program ends (N21).** 2010 has no text for 98's chapter 23. E1's table nonetheless keeps five of its rows,
  98's statements under System.Exit and System.Environment (`lib.r.systemexit.term.error`, `.term.ioerror`,
  `.term.normal`, `lib.r.systemenvironment.exitwith.close`, `.term.loop`), while chapter 40 keeps only
  `exitWith`, `exitFailure` and `exitSuccess` (T10:16108-16160). Under D38's recommendation (98's behaviour kept,
  implementation-defined, documented) they leave the table: their programs stay, as rhc's documented choice, outside
  it as the sharing budgets are (haskell98.md:8135).

Readings 2010 settles: R1 and R9, whose deviations (DV1, DV8) become the text (E2), so the 2010 deviations file starts
with 98's other six, each on a `same` row (counted), plus what D21 and the Foreign.C.Types ruling under D33 add.

**The generator.** As 98's: the table lands as data, and `build_clauses2010.py` does not land
(`tests/runner/migration.sml:2,10`); a regeneration would be a `tools/generate` command in SML (haskell98.md:8000).

### Oracle policy (D39, M2)

The rule is 98's: oracles find disagreements, not truth; every expected result cites a clause; where the judges
disagree, or agree against the text, the result is a reading and rhc follows the Report (haskell98.md:8032). GHC
9.14.1's source is the record for what GHC does; 9.4.7 is what runs. *What the implementations do* gives each
oracle's reach; what testing takes from E8:

- **g10:** GHC 9.4.7 `-XHaskell2010 -XRebindableSyntax -XImplicitPrelude`, only the shim's package (the Prelude and
  the Report's 30 modules, export lists checked against T10) and a defaulting plugin for 4.3.4 (`oracles/README.md`).
  It judges acceptance and output. On E8's 23 probes it agrees with the Report on 14 as recorded and on L22 by reading
  (both print `-Infinity`, not NaN), so 15, and departs on 8 (E8, `limits.tsv`): L01 (base's Ratio), L02, L03 and L23
  (RebindableSyntax reads a program's own `ifThenElse`, `>>=`, `negate`), L04 and L05 (base's derivable classes:
  record parentheses, `read "0x10"`), L06 and L15 (GHC's own departures: prefix `!`, duplicate array indices). A
  ninth limit is no probe: the C types' constructors are exported so that GHC will marshal them, so `CInt 3` is
  wrongly accepted. Each departure is a standing line of the oracle file, `g10 | limits/L04_show_record | HOST-BUG |
  output: base's derived Show`, so a rebuilt shim cannot change the evidence silently.
- **gbase**, GHC's own `-XHaskell2010` over base, beside g10 to tell language from library: of 398 plain Hackage
  components gbase accepts, g10 accepts 355, and the other 43 fail on the library alone (E8, `summary.txt`).
- **MicroHs for acceptance only:** it accepts 45 of the 57 testsuite files g10 refuses for language, 24 of 37 of the
  98 corpus's plain rows and 68 of 170 of its own tests; it rarely refuses what g10 accepts (3 of 33, 1 of 28; 11 of
  49 nofib programs, library gaps) (`summary.txt`). Never a judge of a refusal.
- **Hugs and nhc98** are opinions on programs without the 2010 changes: Hugs refuses pattern guards (L17), nhc98
  DoAndIfThenElse and relaxed groups (L19, L21), and both accept n+k (L18). Neither accepts any of the 415 judged rows
  of the 98 corpus's extension and illegal-in-h98 set.
- **Where GHC is no judge at all:** `forall` as a type variable and prefix `!`, refused on 9.4.7 (X1's `forall.hs`
  and `bang.hs`, E5's P18a and P18f) and in every mode by 9.14.1's `bugs.rst:44-57`; `1_000` with `_000` in scope and
  `Just.do`, refused on 9.4.7 and not in `bugs.rst` (X1); 98's stricter dependency analysis, since RelaxedPolyRec
  cannot be turned off (D16); a refusal of pattern guards, since NoPatternGuards only warns (X1). 9.4.7 accepts
  `forall` as a term variable (L07); 9.14.1's `bugs.rst` says it no longer does, so that acceptance is "source only".
- **jhc** was not built (`jhc-prereqs.tsv`).

**The harness** is 98's, nightly and by capability (`tests/runner/hsoracles.sml:1-10`), with g10's recipe
(`oracles/ghc2010/build.sh`) as its doctor hint and E8's 2010 sets as its data. Its cost, per candidate as E8
recorded it at load about 30: g10 1.09 s, gbase 0.59 s, MicroHs 3.16 s, nhc98 0.76 s, Hugs 0.42 s; about 10,700 s for
the five together, g10 and gbase over 3,052 candidates and the others over 1,238 to 1,666 (summed from `raw/*.json`).

### The corpora and the untrusted-code filter (D40, M2)

Two sources again: clause programs, which are the conformance evidence, and corpora, which are breadth. E8's 3,217
candidates, by what they give 2010 (`summary.txt`, `accept.tsv`, `reject.tsv`, `run.tsv`):

| Set | Candidates | What 2010 takes |
|---|---:|---|
| `h98-accept`, the 98 corpus's accept rows | 1,441 | Of the 975 GHC-strict-98 accepted, g10 accepts 856, refuses 70 and 49 are filtered (recounted). Of the 70, 51 import a 98 module name (Char 11, System 10, List 10, Array 7, ...) and stay 98-only (D38); 3 need NondecreasingIndentation, which rhc already refuses in 98 mode by R3 (`tests/hs/rhc-corpus.txt:9-11`) and g10 refuses too, so no new pin; 34 that GHC-strict-98 refused are accepted |
| `h98-corpus`, the extension and illegal-in-h98 rows | 424 | Not 2010 tests: of 357 judged extension rows one is legal 2010 (`rn058`, the FFI); all 58 judged illegal-in-h98 rows stay illegal. They are the extension corpus |
| `ghc-h2010`, GHC 9.14.1's testsuite naming Haskell2010 | 509 | 96 name nothing beyond 2010: 32 accept rows, and 43 of the 51 expected to fail are refused by g10, gbase, Hugs and nhc98 alike. Only 2 run tests survive the filter |
| `nofib-2025` (ghc/nofib b7391df) | 170 | 49 accepted of 84 plain; 64 filtered, all CPP |
| `mhs-tests` (MicroHs f17be7f) | 243 | 27 accept rows; 104 of the 105 `Error*.hs` refused by g10 |
| `hackage`, E7's closed2010 modules | 429 components | 355 accepted by g10, compile only, never run |

**The changes are hardly exercised.** Of the 1,279 accept candidates, pattern guards occur in 5, foreign declarations
in 22, empty data in 14, DoAndIfThenElse in 46 and hierarchical imports in 284 (E8, `deltas.txt`; regex readings
[inferred]). The corpora show that 2010 rhc compiles what people wrote; only clause programs test 2010's changes.

**The filter** runs before any compiler and lands as data, not code: `filtered.tsv` records the 167 candidates kept
from every compiler, 5% of all, and why: CPP 129 (19 with `#include`), TemplateHaskell 30, QuasiQuotes 4 (3 rows
name both), `capi` 3, OPTIONS naming a plugin, `-F` or `-optc` 4 (recounted); ANN pragmas are blanked in every copy
compiled. It costs nofib 38% (64 of 170), all CPP, which D12 would recover. The filter protects the oracles and the
machine: GHC runs a splice or an annotation at compile time. rhc runs no code at compile time (TemplateHaskell and
QuasiQuotes are known and not supported, D7); its one reach into the file system would be CPP's `#include`, which D12
confines to the program's own directory. Two files were caught only after the filter learnt to see CPP lines in literate
files, both already given to GHC with CPP off (E8, `README.md`); a re-pinned corpus is filtered again before any oracle
sees it.

**What lands where.** As 98's corpus did (`tests/hs/corpus/README.md:1-14`): programs `make check` runs are vendored
with their licence or a provenance after a survey; the rest stay outside, read through `RUNE_HS_CORPUS`. The 2010
sets' licences, read for this section: GHC's testsuite is under the Glasgow Haskell Compiler License
(`/home/ruud/haskell/ghc/testsuite/LICENSE:1`); MicroHs under Apache 2.0 (`/home/ruud/haskell/MicroHs/LICENSE:1-3`);
nofib states none, as 98's survey found for 2019's; each Hackage package has its own, and Hackage is never vendored:
a pinned recipe (LTS 24.67, the tarballs' sha256 in `downloads/hackage/MANIFEST.tsv`) compiled nightly, never run.
E7's `plain2010.tsv` (8,550 rows, 823 closed2010 in 392 packages; md5 d9020a34..., the version E8 judged) is the
list. **The extension corpus** for track X is E8's `extcorpus.tsv`: 1,198 rows, 528 candidates GHC accepts with
their own pragmas, under 84 names (FlexibleInstances 100, MultiParamTypeClasses 90, RankNTypes 87, ...); each
extension's milestone draws its accept and reject programs from it.

### Holding 98 mode byte-identical (M3)

The brief: "the haskell98 mode needs to stay haskell 98 as per its report". The 98 suites already hold what a 98
program prints and what rhc says of a refused one. They do not see code: a 2010 change that alters 98's Core, its
sharing or its speed and not its output passes every 98 job. E3 measured the rest, unpatched rhc against its spike
of track F in 98 mode, on one Rune:

| Compared | How | Result |
|---|---|---|
| `tests/hs/lang`, 591 programs | register bytecode at `RUNE_LINT=2`, at `-O1` and at `-O2` | 591 and 591 identical (`identity/lang-O1.tsv`, `lang-O2.tsv`) |
| 98's D56's run set, 188 programs | through its own harness, `RUNE_HS_RHC` a wrapper keeping every bytecode (each target, each variant) | 193 of 193 jobs pass; 354 of 354 bytecode files and 406 of 406 compiles' stderr identical (`identity/corpus-summary.txt`) |
| `tests/hs/errors`, 633 programs | status and all of stderr | 633 identical (`identity/errors98.tsv`) |
| Views of 953 files of `lang` and `accept` | `--dump-ast`, `--print`, `--print-layout`, `--print-exact` | 3,812 of 3,812 identical (`identity/views.tsv`) |

**None of these met a LANGUAGE pragma** (W10): `tests/hs/lang`, `accept` and `errors` contain none, and the run-set
harness blanks every LANGUAGE and OPTIONS pragma before rhc reads a file (`blankPragmas`,
`tests/runner/hssource.sml:276-298`, applied at `tests/runner/hscorpus.sml:190-195`). So the identity they show is for
pragma-free texts. The 8 vendored files that do carry LANGUAGE pragmas (DatatypeContexts, ExistentialQuantification,
ConstrainedClassMethods, GeneralizedNewtypeDeriving, CPP, BangPatterns), and the 3 with GHC flags in OPTIONS, must be
compiled unblanked under D6's 98 rule (only edition names read) as part of M3, or the standing check is blind to the
one 98 path the pre-scan changes.

E4 did the same for track M's prototype (the language record, the library descriptor, the keys): 1,182 of 1,182
`lang` bytecode files identical (591 programs on both targets), 633 of 633 errors and 251 of 251 accepts identical in
status and output, and 198 run-set compiles identical with 52 refused tries (`results/E4/bytes6-*.log`).

It has earned its place twice. E3's first LANGUAGE pre-scan refused unknown names in 98 modules, which would have
broken 8 vendored run-set programs that name DatatypeContexts, CPP, BangPatterns and others (E3's report; not kept as
a result file). E4's comparison on its build 4 found three malformed literate files (`lit.bird.adjacent.after`,
`.before`, `lit.latex.unterminated`) whose output differed, an exception escaping where 98 refuses with a message
(`results/E4/bytes-errors.log`), and its suites found `hs/syntax/budget` about 14% over on build 5 (E4's report);
both were fixed in build 6. Each spike ran the comparison on its final build, not on each change.

**The standing check.** After any change of this roadmap, 98 mode's output and code stay put unless a decision says
otherwise, and that decision says by how much. As the 98 roadmap's gate does for SML's bytes (haskell98.md:7862-7867):
- **Per change,** E3's comparison is part of each milestone's *Done when*: the change's rhc against its parent's, on
  one Rune, over the four sets above, both targets for `lang` as E4 ran it. It needs two builds of rhc and costs about
  2,800 to 3,300 s of CPU for the run set alone per rhc (`results/E3/identity/corpus-summary.txt`), so it is not in
  `make check`.
- **Standing, nightly,** against a manifest in the tree: each 98 program's canonical Core
  (`--dump-after=desugar --canonical-core`, `docs/rhc.md:195`), the errors' messages and the four views. Core is rhc's
  own output, so Rune's changes do not move it, where they move every bytecode [inferred]; a commit that moves the
  manifest names its decision. The register and stack bytes stay the per-change check's.
- **What may move:** only what a decision names: M18's D13a (`genericLength`) and, if the owner takes them, the two
  checker defects of *Found while writing*; and E4's one intended change, `hs/names/imp/greatest`, whose dump goes
  from 958 pairs to 955 once the library is immune to `--names=greatest` (`results/E4/logs/suites6.log:2`), which
  needs the owner's word. The pre-scan reads only edition names in a 98 module (D6), and a file that names
  `Haskell2010` is read as 2010; no test or run-set program names it (E3).
- **M3 builds it** at once, before tracks M and F land anything, so that their first change is measured.

### Conservativity (D36, M19-M27)

**Extensions that change valid programs** come only when asked, each with a test of the change: one program, compiled
with the extension off and on, off giving 2010's answer (the Report's, cited), on giving the extension's. X1's 41
probe modules (`results/E6/X1-probes/`, 82 runs in `X1-data/probes.tsv`) are those tests, ready: 36 for extensions
that change valid programs, by mechanism (a No form, a lexeme 2010 splits, a symbol 2010 lets name an operator, a
keyword stolen, whitespace, typing or meaning, layout, CPP: `X1-notes.md:118-133`), and 5 for ones that do not. On
9.4.7 off and on differ on 38 of the 41. What a test takes from GHC, case by case (counted on `probes.tsv`):
- In five the off side is GHC refusing valid 2010 (`bang`, `bang2`, `forall`, `numund`, `qualdo`): their off result
  is the Report's, never GHC's.
- In three GHC shows no difference: `bang2` (refused both ways), and the "no" rows `dupfields` and `nplusk`.
- Two accept what 2010 refuses (`nondecr`, `relaxed`): they test that 2010 mode stays strict, not a meaning.
- E5's census probes add 31 runs (P14, P18): MagicHash, StaticPointers, TemplateHaskellQuotes, UnboxedTuples and
  UnboxedSums, `forall` under ScopedTypeVariables and ExistentialQuantification, LambdaCase, BangPatterns,
  OverloadedStrings, Safe, GND, NamedWildCards, DatatypeContexts.

Of the census's 28 recommended rows that change valid programs (`census.tsv`), 22 have one of X1's probes and two one
of E5's (DatatypeContexts, ExistentialQuantification); RankNTypes and LiberalTypeSynonyms change valid programs only
through the `forall` their implied ExplicitForAll reserves, which `forall.hs` and P18a-c test; FieldSelectors and
MonomorphismRestriction, both by their No forms, have none yet, and their milestones write them from the census's
description (counted). The editions GHC2021 and GHC2024 change valid 2010 programs too (P18s, P18u); rhc refuses
them in this roadmap (D5), and the refusal is their test.

**Extensions that do not change valid programs** (81 in the census, 44 of them recommended now) have a test of
absence: the 2010 corpus, compiled with the extension on, is byte-identical to the corpus compiled without it. The
corpus is the 2010 clause programs, the shared 98 programs and E8's accept rows. Proposed [inferred, not built]:
- in `make check`, one compile of each 2010 clause program with every such feature on together (the combination table
  permitting), against the plain compile, by canonical Core;
- nightly, each feature alone over the whole corpus, by bytecode.

A moved byte is a bug or a census row classed wrongly, and the census has been wrong before: X2 classed LambdaCase
"no" where X1 and X3 said yes (`results/E6/overlap.tsv:100`), and X1's `lcases.hs` measured `\cases -> cases + 1`
stop compiling.

### HsLint parity (D41)

HsLint "shares only the renamer with the checker" (`lib/language/haskell/hslint_infer.sml:35-36`), so every rule the
checker gains HsLint must state again, from its own specification. Otherwise HsLint refuses 2010 programs or checks
them less, and level 2 means nothing for them. It has paid: at the pin the checker accepts two programs HsLint
rightly refuses at level 2 (E3's `defects/rule1-signed/`, `results/D16-probes/`).

**For the 2010 table** parity needs only the 2010 changes: pattern guards, relaxed groups, empty data's condition 6
and the FFI's marshallability (D41). E3 spiked the first three in HsLint: 17 code lines of inference for pattern
guards; 34 for relaxed groups against the checker's 7, where HsLint must assume every explicit signature first, as
THIH's `tiBindGroup` does, or a group meets a signed binding not yet typed; condition 6 beside the checker's
(`results/E3/diffstat.tsv`). E4 found the same in its prototype: relaxed groups took the checker one change and
HsLint four (E4's report, finding 7). So D41 budgets HsLint at no less than the checker for each type feature. The
FFI's check is D32's, about 80 lines.

**For extensions** the census grades HsLint's cost (`census.tsv`, column `hslint`): of the 72 recommended now, 32 cost
it nothing (the lexer or renamer removes them before HsLint sees them), 25 must be mirrored and 15 need a
specification HsLint can follow independently (counted). HsLint's types have no rigid form: `ty` is `TVar`, `TCon`,
`TAp` or `TGen` (`lib/language/haskell/hslint_types.sml:32-37`), and a signature is checked by instantiating it with
fresh variables and comparing schemes after (`lib/language/haskell/hslint_infer.sml:697-720`); only the replay turns
the checker's rigid variables into constants (`lib/language/haskell/hslint_replay.sml:65-71`). So T3, T4a and T5 each
cost HsLint skolems and an escape check (X2).

**How it is held**, as 98's HsLint is: each new rule has a fault that corrupts its datum and must be refused with its
message; the dump, accept, lang and errors shards of `tests/runner/hslint.sml:6-26` run over the 2010 directories;
every 2010 suite compiles under `RUNE_LINT=2`. The rule for parity: no feature's rows leave `Planned` until HsLint
checks the feature at level 2.

### Round trips (D6, M5)

98's two tests, on every file the parser accepts: the tree test and the token test on the explicit print in
`make check`, and the implicit and exact prints' nightly (`tests/runner/hsroundtrip.sml:1-31`). 2010 adds syntax
(guards' qualifiers, `foreign` declarations, empty data, the optional semicolons of DoAndIfThenElse, dotted names) and
one thing the printers never had to keep: **the header's pragmas**. The explicit and implicit prints emit no trivia
(`lib/language/haskell/print.sml:129-139`); only the exact print does (`:65-66`). So a printed 2010 module loses its
LANGUAGE pragmas and with them its language: E3 printed its `pragma1.hs` and 98 mode refused the print (E3's report;
no result file keeps the print). The exact print gives every parseable 2010 program back byte for byte, `.lhs`
included (E3).

So, with D6:
- the two printers print the header's pragmas;
- the round trip reparses the print with no `--language`, so the header alone sets the module's language;
- the tree command prints the module's resolved settings, so a printer that drops or reorders a pragma fails the tree
  test;
- the stub's faults (`hs/roundtrip/@faults`) gain a printer that drops a pragma, which the tree test must catch;
- the syntax generator (98's D55) gains 10.5's productions (E1's `syn10.*` rows).

### Tests of the tracking design (D4-D11, M4-M6)

98 had one edition and no settings, so nothing here exists. Proposed [inferred, not built]:

1. **Resolution against GHC (D5).** E5's 137 P-probes (`results/E5/probes/probes.tsv`, run on 9.4.7, 129 as predicted
   from the source) become rhc's tests: flags and a header in, the effective set or the error out, through an rhc
   option that prints a module's resolved settings (none exists at the pin). The expected result is GHC's where D5
   mirrors it and the decision's where it does not, each exception naming its decision: up to 40 probes rest on GHC's
   default edition GHC2021 or name GHC2021 or GHC2024 (counted on flags and module text), which rhc does not accept
   (D5); 5 need CPP (P13, D12); 7 are Safe Haskell's (P16, D7); P14 and P18 are conservativity's.
2. **The closed table (D4, D7).** One generated test per name of GHC's 148 and per No form: each is exactly one of
   supported, inert, not supported ("not supported by rhc") or unknown (an error, T10:10989-10990).
3. **Combinations (D7).** Chapter 12: "If a Haskell implementation does not recognize or support a particular language
   feature that a source file requests (or cannot support the combination of language features requested), any
   attempt to compile or otherwise use that file with that Haskell implementation must fail with an error."
   (12.3, T10:10989-10990). GHC refuses no combination (E5, `semantics.md` section 12), so rhc's table is new, and it is
   held both ways as the conformance table is: every combination it refuses has a program that must fail with the
   combination's message, and every pair of supported features it does not refuse resolves and compiles a small
   module with both on. With the 72 names recommended now that is 2,556 pairs, resolution alone for most
   [inferred].
4. **Diagnostics (D11).** E5's 35 refusals under `-XHaskell2010` (`probes/diag-names.tsv`): GHC names the extension in
   26; rhc's test is all 35, the 9 lexer-level ones included.
5. **Keys (D9).** E3's `--dotted-names` reproducer (`results/E3/dotted/repro.sh`: a unit made without the flag taken
   by a compile with it) generalised: for each feature that changes how a text is read, compile with it off into a
   store and then on against that store; the unit must not be taken. Two spellings of one set (an alias such as
   Rank2Types; an implied feature written out) must give one key.
6. **Per module (D2, D10).** E4's per-module cases are ready tests (`results/E4/permodule/results3.txt` and
   `results2-b6.txt`, its final build, at `RUNE_LINT=2`, units and `--whole` agreeing): n+k by edition and by
   `-XNPlusKPatterns` and its No form; 4.5.1's example refused in 98 and accepted under 2010 or `-XRelaxedPolyRec`; a
   98 `Main` importing a `{-# LANGUAGE Haskell2010 #-}` module; a pragma read after unlit; one cycle whose modules
   differ on RelaxedPolyRec, only the other module's bindings refused; a cycle whose modules disagree on a whole-cycle
   setting, an error. Beside them: a 98 module in a 2010 program, whose `import Monad` fails as GHC's does (E5,
   P17e), and a file's own `{-# LANGUAGE Haskell98 #-}` refusing pattern guards whatever the command line says (E3).
7. **The header (D6).** E3's `pragma1` to `pragma6` and the shapes its census counts (several pragmas, one over
   several lines, comments between, a lower-case keyword, OPTIONS_GHC with `-X`: `results/E3/pragmas/summary.tsv`).

### Budgets and tiers (D41)

Rune's `make check` is 11,879 s of CPU (`docs/testing.md:261`). rhc's 98 tier already takes 4,515 s of it, 38.0%,
rhc's compile 15.6% of that, which the owner accepted (haskell98.md:7231).

**What a 2010 clause tier costs.** E4 priced one of 98's shape from existing timings, none of it run
(`results/E4/cost.md`) [inferred]. The clause families (`hs/lang`, `hs/compile`, `hs/errors`, `hs/accept`) are 4,400
of rhc's 5,133 check-tier jobs (`results/E4/check-tier-list.txt`), so 86% of the 4,515 s is taken as theirs, at 98's
cost per row:
- **Shared by clause id,** 2010 adding only its changed and new rows: about 2,259 s, +19.0% of the 11,879 s base and
  about +7.7% of `make check` at the 98 roadmap's close (29,255 s of CPU over 28,360 tests at `e5db9feca`, the 98
  drafts' `impl/checks/batch21.log`).
- **Every 2010 row its own program:** about 5,235 s, +44.1% and +17.9%.
- These count E1's file, 5,259 rows, 1,358 of them new (`results/E1/clauses2010-counts.tsv`). E4's `cost.md` used
  5,348 rows, 1,447 new, and gave 2,350 s and 5,320 s (W8): the same conclusion.
- The 2010 snapshot adds two compiles to `make bin/rhc`: the layer for both languages took 43.2 s wall and is
  82,954,000 bytes, against 98's 41,334,255 alone (`results/E4/cost.md`; the time from `logs/build6-layer.log`, the
  layer's size from build 5's `logs/build-layer.log:20`, 98's alone from A's report, reproduced in
  `results/verify/V2/numbers-c/snapshot-sizes.txt`).

D41 recommends rows shared by clause id in `make check` and the rest nightly. Under it a `same` row's program runs in
`make check` under one edition, 98's until G3 and 2010's after, as E4 assumed; its run under the other edition is
nightly. The 21 flips are all verdicts or messages, which `--typecheck-only` sees, so a shared program's second
edition can be checked in `make check` by `--typecheck-only` alone, at the cost of the front end and the checker
[inferred, not measured].

**The run tier is small.** E8 built 90 programs under `ghc -O0`: 89 built, 83 match their expected output, 129.8 s of
CPU (`run.tsv`). The 51 under 1 s take 8.84 s; at the 98 roadmap's K (5 for whole programs, 20 for Prelude-bound
ones: haskell98.md:4343) that is 44 to 177 s of rhc for one way [inferred]. But most of it is already there:
- 15 of the 51, 8.0 s, are nofib programs whose names are in 98's D56's 188, vendored and run in 98 mode already
  (`tests/hs/corpus/licences.tsv`, column `d56`; matched by name, the texts not compared);
- 11 more were built over base only (threads, ByteString, Typeable), not over the 2010 library: not 2010 programs;
- that leaves 25 new 2010 programs, 24 MicroHs tests and one GHC test, 0.78 s under `ghc -O0` (counted on `run.tsv`):
  4 to 16 s of rhc for one way, about 31 to 125 s in the three ways 98's D56 runs [inferred: three ways are about 8K,
  haskell98.md:7221].

So what the 2010 tier costs is compiles, not runs, and D41's figure, the 51 under 1 s taking 8.84 s, counts 15
programs 98's D56 already runs and 11 that are not 2010's.

| Tier | Holds |
|---|---|
| `quick` | 2010 clause programs on the default way; the table's enforcement; resolution and closed-table tests; HsLint's and the round trip's faults |
| `check` | 2010 clause programs (changed and new rows) and their `--typecheck-only`; each shared program under one edition, and `--typecheck-only` under the other; the 25 new run programs in 98's D56's three ways; the 2010 library's overlay, pristine, names and compile jobs; round trips over the 2010 directories; HsLint's shards over them; the conservativity tests of every extension that has landed, and the all-features-on compile; tracking tests 1 to 7 |
| `nightly` | the standing 98 check against its manifest; every shared program under its second edition, every way; each feature's corpus identity by bytecode; the judges over E8's 2010 sets (about 10,700 s); Hackage's 429 components, compile only; the extension corpus; every way and both bytecodes in both modes, gc-stress; `reject-unchecked` |
| `test-rhc-mutants` | 98's mutants plus 2010's (below) |

**2010's mutants**, each with what should see it [proposal]: a 2010 feature reaching 98 mode (n+k refused, `foreign`
reserved, the dotted lexer) seen by the 98 suite and the standing check; relaxed groups' edge kept in 2010, seen by
`dec.dep.sig.ctxdiff`'s program and HsLint; condition 6 dropped, seen by its reject program; a pattern guard's
fall-through evaluated twice, seen by a sharing budget beside rule (c)'s `y`; a header pragma dropped by a printer,
seen by the tree test; a setting missing from the unit key, seen by tracking test 5.

### The gates' exits

| Gate | Check |
|---|---|
| G1 | A 2010 hello with a pattern guard from the 2010 snapshot, on the Core interpreter and the VM, with identical output (98's interpreter-against-VM comparison); the per-change 98 check over all four sets |
| G2 | No row of the 2010 table `Planned`; every shared program run in both modes; g10's disagreements each a line of the oracle file; the 2010 corpus's run programs right; the 2010 pristine's diff empty but for its overlay; HsLint, CoreLint and MidLint clean at level 2 on every 2010 suite; 2010's mutants caught; the FFI on every platform Rune's FFI runs on, on both bytecodes, every tier and gc-stress |
| G3 | Every 98 harness pinned (D3), its jobs unchanged by the flip; the 98 table green under the pin |
| Standing | 98 mode's manifest unmoved but by a decision; every extension's conservativity test green |

Track X gates neither G2 nor G3; its features carry their conservativity and HsLint tests into each milestone.

## Every change to Rune

The brief's rule for the 98 roadmap stands: no silent change to Rune. The 2010 language itself changes nothing below
Core: pattern guards, empty data, the relaxed analysis and the rest are front-end work (E3: nothing below the front end
changed, measured on both VMs), and Word, Word64, Int64 and the bit operations lower to primitives the VM already has
(D22, E9). What Rune is asked for comes from the FFI, and one optional item from CPP. Sizes are E10's estimates
(`results/E10/gaps.tsv`), none built.

| Change | Where | Grade | Size [estimate] | Decision | Needed for |
|---|---|---|---|---|---|
| Resolve a C name in the program's own namespace (`dlopen(NULL)`/`RTLD_DEFAULT`; Windows: the loaded modules) | `runtime/`, `sys` layers | small | C ~30 | D27 (G02) | a static import with no library named |
| Read and write a C variable an `&` import names | `runtime/foreign.c` | small | C ~5, tests ~30 | D27 (G06) | `&errno`-style imports |
| Call any FunPtr, not only a SYMBOL identity | `runtime/foreign.c` | small | C ~10, tests ~40 | D27 (G07) | `dynamic` of a `wrapper`'s or a C-returned pointer |
| `castStablePtrToPtr` as a POINTER identity of an integer | `runtime/foreign.c` | small | C ~20 | D30 (G22), only under D29 B | StablePtr under D29 B (under A, D30's table in Haskell needs none) |
| Ptr as a raw address, through a trusted address-level primitive family for rhc's Core only | `runtime/foreign.c`, `src/isa` | **large** (a change of Rune's safety model, `docs/plans/runeffi.md:465-467`) under D29 A; medium (identities plus offsets, canonical identities) under B | A: C ~200, SML ~100 and a safety review | D29 (G13-G17) | plusPtr, minusPtr, alignPtr, Ord, ptrToIntPtr, Storable of pointers |
| A callback scope that `vm_raise` stops at | `runtime/runtime.c`, `callback.c` | small, optional | C ~15 and a test | D31 (G09) | hardening only: rhc's trampoline already keeps exceptions out of C frames |
| `foreign export` and an embedding API (HsFFI.h's `hs_init`, `hs_exit`) | `runeopt`, the runtime | **large** | ~600 and tests; x86-64 first | D28 (G24, G25) | only if the owner takes it |
| Typed scalar arguments to `foreign`, without strings | `runtime/foreign.c`, `lib/basis` | small, optional | not sized | D33 | the ~147 VM instructions a call costs over Haskell's own (E10) |
| Rank-N types in Mid (a polymorphic type outside fields; `lib/compiler/core/midlint.sml:213, 222`) | Mid, MidLint, Lower | **large**: Mid is Rune's IR | not sized | D37 | only if the owner prefers it to boxing a polytype in CoreToMid (~200-400 lines, rhc's) |
| CPP's `#if` expressions through `lib/language/c`'s `CConst` | `lib/language/c` | none to small (a reuse, not a change) | not sized | D12 | if D12 takes the SML subset |

What it does **not** ask, under the recommendations: no change to Mid, Low, the collector or images; the instruction
set gains only D29's primitive family, moving its fingerprint once (M16); no
finalizer or weak reference in the VM (D30 runs C finalizers at `finalizeForeignPtr` and at exit, as the 2010 text
allows, T10:14966-14967); no threads (D31 keeps callbacks on the owning thread). Core's own changes (type binders in
`AltCon` for T4a, a whole-dictionary Cast for GND, kind variables later) are rhc's, not Rune's (D37). The standing
gate applies to every row: SML's bytes and budgets hold unless the row's decision says by how much.

## Risks

- **Scope.** A language mode, a 30-module library, an FFI with Rune changes, 72 extensions and a tracking design.
  Track X never gates G2 or G3, and *What is cut first* orders it.
- **The tree moves.** The other session's 24 commits after the pin changed rhc's store and driver (the build-cache merge
  alone: nine files of `src/rhc`, +402 -124); E4's prototype rejects 12 of its 121 hunks on the tip. Every milestone is
  written on the tree of its day.
- **98 bytes.** The standing check met no LANGUAGE pragma (*Testing and conformance*); the one 98 path the pre-scan
  changes needs the 11 vendored files compiled unblanked (M3).
- **HsLint's double cost.** Every typing feature is specified twice; E4's RelaxedPolyRec cost HsLint four changes to
  the checker's one, and E13 found a per-group rule only a mixed cycle exposed. A tier that lands in the checker
  without HsLint fails level 2.
- **Meaning-changing extensions.** 67 of 148 names change some valid 2010 program; one left on by default breaks
  conformance silently. Each is opt-in with its conservativity test (D36).
- **The library's prose.** 26 modules have no code; where the prose is thin, `base` 4.3 decides, and where prose and
  `base` disagree (Data.Int's modulo, allocation failure, `isAlphaNum`), the owner's reading decides (D21, D24, D26).
- **Rune's FFI model.** D29 A changes a stated rule of Rune's; B keeps it at the price of deviations (ptrToIntPtr) and a
  registry that grows (E10 measured 1,000 identities for 1,000 `getenv` calls).
- **The OutsideIn boundary drifts.** A T4 or T2 feature that quietly admits T4b's universal givens or a given's
  improvement makes types non-principal or Core unelaborable (E11). HsLint's independent specification is the
  guard; the tests of T4a and T2 include the refusals (OutsideIn's MkR example; Karachalias and Schrijvers').
- **GHC as an oracle.** Its 2010 mode departs in ways the shim cannot undo (E8: 8 of 23 probes); a disagreement is a
  question, never an answer (D39).
- **Untrusted code.** The corpus filter keeps TH, quasi-quotes and CPP includes away from every compiler (D40); a new
  corpus goes through it first.
- **Budget.** A 2010 clause tier adds 2,259 to 5,235 s of CPU to `make check`'s 11,879 s base (E4's rule on E1's
  counts); shared by clause id, with the rest nightly, is the recommendation (D41).

## What is cut first

In this order, each cut leaving the rest whole:
1. `foreign export` and HsFFI.h (M17), if the owner has not already deferred it (D28).
2. T5, RankNTypes (M26).
3. T2, FunctionalDependencies (M23): mtl needs it, but nothing in the 2010 Report does.
4. T4a, existentials (M25).
5. CPP (M20): D12's fallback is chapter 12's error.
6. T8 policy flags (M27).
7. The deriving group's GND and DerivingVia (the Cast), keeping the rest of M21.
8. T3 (M24), then T1 (M22).
9. The lexer- and renamer-only extensions (M19) last of track X: they are cheap and widely used (E7).

**Never cut:** the 2010 Report itself, M1-M16, which is G2: every clause Supported or pinned, the 30 modules, the FFI's
required parts but `foreign export` (D28); 98 mode byte-identical (M3); HsLint at level 2 on everything the checker
accepts; the clause table.

## Measuring

The figures this roadmap rests on are instruction counts and byte comparisons, which do not vary with load: rhc's
outputs compared byte for byte (E3, E4, E13), `runevm --count` for the FFI's cost (E10), and counts of rows, files and
packages (E1, E6, E7, E8, E9). Seconds are indications on a machine shared with another session at load 25 to 55.
What is not measured: speed against GHC; rhc's compile time beyond the snapshot; any extension's run-time cost; the
library's speed; anything concurrent. A milestone that claims speed measures it by `--count` and says so.

## At the close

Empty until the roadmap is carried out: the last checks, what it promised and what it gave, bugs found in Rune and in
other compilers, and what is left open.

## References

**The texts.**
- The Haskell 2010 Language Report, ed. Simon Marlow, 2010: https://www.haskell.org/onlinereport/haskell2010/ (the
  HTML of 2010-07-20, fetched 2026-11-17 into the drafts' `downloads/report2010/`; the PDF,
  https://www.haskell.org/definition/haskell2010.pdf, as text in the 98 campaign's
  `downloads/papers/txt/haskell2010.txt`, cited as T10:line). No errata to it were published (E1).
- The Haskell 98 Language and Libraries, the Revised Report, ed. Simon Peyton Jones, December 2002, with its 18
  published errata, as rhc reads it (`share/rhc/haskell98/errata.tsv`); as text, `report98.txt`, cited as T98:line.
- The 98 roadmap: `docs/plans/language/haskell98.md` at `75ed95861`, cited as haskell98.md:line.

**Implementations and data**, at the revisions under `/home/ruud/haskell` that the experiments name: GHC 9.14.1
(`ghc-9.14.1-release`, the census's record) and the installed GHC 9.4.7; MicroHs 0.16.12 (`f17be7f0`); Hugs (September
2006); nhc98 1.22; jhc; Helium; haskell-src-exts 1.24.0; Cabal in GHC's tree; Hackage's index of 2026-11-17 and the
sources of Stackage LTS 24.67 (E7, with every file's sha256 in `downloads/hackage/MANIFEST.tsv`); `base` 4.2 and 4.3 and
the `haskell2010` package (E9, `downloads/libs/MANIFEST.tsv`); the Haskell' wiki and the haskell-prime list, through the
Wayback Machine (E11, `downloads/haskell-prime/MANIFEST.tsv`).

**How paths are written.** A path of rhc or Rune is relative to the repository root, at `75ed95861` unless it says
otherwise; a bare SML file name (`infer.sml`, `hslint_infer.sml`) is in `lib/language/haskell/`. A GHC path is relative
to `/home/ruud/haskell/ghc` (written `ghc/compiler/...` or `compiler/...`); a path of another implementation is
relative to its tree under `/home/ruud/haskell` (`MicroHs/`, `Hugs/`, `nhc98/`, `jhc/`, `haskell-src-exts/`); `base`
4.3's files are under the drafts' `downloads/libs/src/base-4.3.1.0.x/base-4.3.1.0/`. A bare `:N` continues the file
cited just before it in the same sentence. `results/` and `patches/` are under
`~/.cache/claude-rune-drafts/haskell2010/`.

**Papers.**

The sources E11 read, as far as *What the literature says* and *What the implementations do* use them, each keyed as
`results/E11/refs.tsv` keys it. Each DOI is in `results/E11/dois.tsv` or, for a paper the 98 campaign fetched, in its
`results/E15/dois.tsv`, checked against Crossref, unless the entry says otherwise; "no DOI" means none was found and
the text itself was read. Each entry ends in its status: **Full**, **Sections** (which), **Abstract**, or **Not read**.
"p. N" in the text is the page of the local PDF; local copies are in `refs.tsv`.

- Augustsson. MicroHs: a small compiler for Haskell. Haskell Symposium 2024. doi:10.1145/3677999.3678280. Sections 1-3.
  Key `augustsson24`
- Boehm. Destructors, finalizers, and synchronization. POPL 2003; HP Labs HPL-2002-335 (no DOI checked). Abstract, as
  the technical report. Key `boehm03`
- Breitner, Eisenberg, Peyton Jones, Weirich. Safe zero-cost coercions for Haskell. ICFP 2014.
  doi:10.1145/2628136.2628141. Sections 1-2, 7. Key `breitner14roles`
- Chakravarty (ed.) et al. The Haskell 98 Foreign Function Interface 1.0: an addendum to the Haskell 98 Report. 2003
  (no DOI). Full: sections 1-4, 5.5 and 6.1, the language part and HsFFI.h compared with the 2010 Report by script; a
  Wayback copy of the editor's PDF. Key `ffi03`
- Chakravarty, Keller, Peyton Jones, Marlow. Associated types with class. POPL 2005. doi:10.1145/1040305.1040306.
  Abstract. Key `chakravarty05`
- Dijkstra, Fokker, Swierstra. The structure of the Essential Haskell compiler, or coping with compiler complexity. IFL
  2007. doi:10.1007/978-3-540-85373-2_4. Section 3 and Figure 3, in the draft proceedings the owner supplied. Key
  `dijkstra07`
- Dijkstra, Fokker, Swierstra. The architecture of the Utrecht Haskell compiler. Haskell Symposium 2009.
  doi:10.1145/1596638.1596650. Section 1. Key `dijkstra09`
- Dunfield, Krishnaswami. Complete and easy bidirectional typechecking for higher-rank polymorphism. ICFP 2013.
  doi:10.1145/2500365.2500582. Sections: abstract, 1. Key `dunfield13`
- Eisenberg, Breitner, Peyton Jones. Type variables in patterns. Haskell Symposium 2018. doi:10.1145/3242744.3242753.
  Sections 1-2. Key `eisenberg18`
- Eisenberg, Weirich, Ahmed. Visible type application. ESOP 2016. doi:10.1007/978-3-662-49498-1_10. Sections 1-3 and
  Lemma 1, as the extended version. Key `eisenberg16`
- Erwig, Peyton Jones. Pattern guards and transformational patterns. Haskell Workshop 2000, ENTCS 41(1), 2001.
  doi:10.1016/s1571-0661(05)80540-7, found by a Crossref title search. Full. Key `erwig01`
- Finne, Leijen, Meijer, Peyton Jones. Calling hell from heaven and heaven from hell. ICFP 1999.
  doi:10.1145/317636.317790. Sections 2-3. Key `finne99`
- GHC Steering Committee. GHC2021, GHC proposal 380. 2021.
  https://github.com/ghc-proposals/ghc-proposals/blob/master/proposals/0380-ghc2021.rst (no DOI). Sections: lines
  1-60. Key `ghc2021`
- Graf, Peyton Jones, Scott. Lower your guards: a compositional pattern-match coverage checker. PACMPL 4 (ICFP), 2020.
  doi:10.1145/3408989. Abstract. Key `graf20`
- Haskell' committee. The Haskell' (haskell-prime) Trac wiki, 2006-2019: Process, Principles, Status (the capture of
  27 April 2009), and the proposal pages cited, from the Wayback Machine (captures in
  `downloads/haskell-prime/MANIFEST.tsv`; no DOI). Full, for the pages cited. Key `prime-wiki`
- Hudak, Hughes, Peyton Jones, Wadler. A history of Haskell: being lazy with class. HOPL III, 2007.
  doi:10.1145/1238844.1238856. Sections 6.5-6.7, 12.7. Key `hudak07`
- Jones. A theory of qualified types. ESOP 1992, LNCS 582. doi:10.1007/3-540-55253-7_17. Sections; the 98 campaign's
  file `jones94.pdf` is this paper, not the 1994 book. Key `jones92esop`
- Jones. Simplifying and improving qualified types. FPCA 1995. doi:10.1145/224164.224198. Abstract and section 1. Key
  `jones95simp`
- Jones. First-class polymorphism with type inference. POPL 1997. doi:10.1145/263699.263765. Section 1, and the
  conclusion's sentence on Hugs. Key `jones97fcp`
- Jones. Typing Haskell in Haskell. Haskell Workshop 1999 (no DOI). Section 11.6. Key `jones99`
- Jones. Type classes with functional dependencies. ESOP 2000, LNCS 1782. doi:10.1007/3-540-46425-5_15. Full. Key
  `jones00fundeps`
- Jones, Diatchki. Language and program design for functional dependencies. Haskell Symposium 2008.
  doi:10.1145/1411286.1411298. Sections 1-3, 6. Key `jones08`
- Karachalias, Schrijvers. Elaboration on functional dependencies: functional dependencies are dead, long live
  functional dependencies! Haskell Symposium 2017. doi:10.1145/3122955.3122966. Sections 1-2. Key `karachalias17`
- Läufer. Polymorphic type inference and abstract data types. PhD thesis, New York University, 1992 (no DOI). Sections:
  abstract, contents. Key `laufer92thesis`
- Läufer. Type classes with existential types. JFP 6(3), 1996. doi:10.1017/S0956796800001817. Sections 1-4. Key
  `laufer96`
- Läufer, Odersky. An extension of ML with first-class abstract types. ACM SIGPLAN Workshop on ML and its Applications,
  1992 (no DOI found). Abstract. Key `laufer92ml`
- Läufer, Odersky. Polymorphic type inference and abstract data types. TOPLAS 16(5), 1994. doi:10.1145/186025.186031.
  Not read: no open copy (below). Key `laufer94`
- Lewis, Shields, Meijer, Launchbury. Implicit parameters: dynamic scoping with static types. POPL 2000.
  doi:10.1145/325694.325708. Sections 1, 5-6, from a scan. Key `lewis00`
- Lynagh, Marlow, Allbery et al. The haskell-prime archive of May 2010: the review of the draft Report and the proposal
  of `{-# LANGUAGE Haskell2010 #-}`, as fetched for E1 (`downloads/report2010/errata/`). Sections: lines 400-660,
  850-870. Key `lynagh10`
- Marlow. Announcing the new Haskell Prime process, and Haskell 2010. haskell-prime, 7 July 2009.
  https://mail.haskell.org/pipermail/haskell-prime/2009-July/002812.html. Full. Key `marlow09a`
- Marlow. Announcing Haskell 2010. haskell, 24 November 2009, with replies.
  https://mail.haskell.org/pipermail/haskell/2009-November/021750.html. Full. Key `marlow09b`
- Marlow et al. Haskell 2010 libraries. haskell-prime, the thread of 30 April 2010, Wallace's reply among its 8
  messages. https://mail.haskell.org/pipermail/haskell-prime/2010-April/. Full. Key `marlow10a`
- Marlow, Peyton Jones, Thaller. Extending the Haskell foreign function interface with concurrency. Haskell Workshop
  2004. doi:10.1145/1017472.1017479, found by a Crossref title search (the DOI first given from memory was another
  paper's). Sections: abstract, 1. Key `marlow04`
- Marlow, Wallace. The hierarchical module namespace extension, version 0.0: an addendum to the Haskell 98 Report
  (draft). 2003 (no DOI). Full, a Wayback copy. Key `wallace03hier`
- Marlow (ed.). Haskell 2010 Language Report. 2010. https://www.haskell.org/definition/haskell2010.pdf (no DOI). Full in
  E1; in E11 the preface, 3.13, 3.17, 4.5, 8, 12 and 24-37. Key `haskell2010`
- Morris, Jones. Instance chains: type class programming without overlapping instances. ICFP 2010.
  doi:10.1145/1863543.1863596. Abstract. Key `morris10`
- Odersky, Sulzmann, Wehr. Type inference with constrained types. TAPOS 5(1), 1999.
  doi:10.1002/(sici)1096-9942(199901/03)5:1<35::aid-tapo4>3.0.co;2-4. Abstract. Key `odersky99`
- Peyton Jones. Tackling the awkward squad: monadic input/output, concurrency, exceptions, and foreign-language calls
  in Haskell. Engineering theories of software construction, Marktoberdorf 2000, 2001 (no DOI). Section 6. Key
  `awkward01`
- Peyton Jones. Simplify subsumption, GHC proposal 287. 2020.
  https://github.com/ghc-proposals/ghc-proposals/blob/master/proposals/0287-simplify-subsumption.rst (no DOI). Full.
  Key `ghcp287`
- Peyton Jones, Jones, Meijer. Type classes: an exploration of the design space. Haskell Workshop 1997 (no DOI).
  Sections 3-6. Key `spj97`
- Peyton Jones, Shields. Lexically-scoped type variables. Draft, 2004 (no DOI). Sections 1-4. Key `spj04scoped`
- Peyton Jones, Vytiniotis, Weirich, Shields. Practical type inference for arbitrary-rank types. JFP 17(1), 2007.
  doi:10.1017/S0956796806006034. Sections 1-4. Key `pvws07`
- Peyton Jones, Vytiniotis, Weirich, Washburn. Simple unification-based type inference for GADTs. ICFP 2006.
  doi:10.1145/1159803.1159811. Abstract. Key `pvww06`
- Serrano, Hage, Peyton Jones, Vytiniotis. A quick look at impredicativity. PACMPL 4 (ICFP), 2020.
  doi:10.1145/3408971. Sections 5.8, 7 and Appendix A. Key `serrano20`
- Sulzmann, Chakravarty, Peyton Jones, Donnelly. System F with type equality coercions. TLDI 2007.
  doi:10.1145/1190315.1190324. Section 1, and the fundep example on p. 3. Key `sulzmann07`
- Sulzmann, Duck, Peyton Jones, Stuckey. Understanding functional dependencies via constraint handling rules. JFP
  17(1), 2007. doi:10.1017/S0956796806006137. Sections 1, 4-6, 8. Key `sulzmann07chr`
- Vytiniotis, Peyton Jones, Schrijvers. Let should not be generalised. TLDI 2010. doi:10.1145/1708016.1708023.
  Sections 1, 4. Key `letgen10`
- Vytiniotis, Peyton Jones, Schrijvers, Sulzmann. OutsideIn(X): modular type inference with local assumptions. JFP
  21(4-5), 2011. doi:10.1017/s0956796811000098. Sections 1-2, 4.1-4.2. Key `outsidein11`
- Vytiniotis, Weirich, Peyton Jones. Boxy types: inference for higher-rank types and impredicativity. ICFP 2006.
  doi:10.1145/1159803.1159838. Abstract. Key `vytiniotis06`
- Yorgey, Weirich, Cretin, Peyton Jones, Vytiniotis, Magalhães. Giving Haskell a promotion. TLDI 2012.
  doi:10.1145/2103786.2103795. Abstract. Key `yorgey12`

**Sources** under `/home/ruud/haskell`, cited in place, at these revisions:
- GHC `902339d332`, tag `ghc-9.14.1-release`. The binary run is 9.4.7, `/usr/bin/ghc`
- Cabal and Cabal-syntax 3.16.0.0, the copy in GHC's tree, `libraries/Cabal` at `d9b0904b4`
- haskell-src-exts `bf2917a`, version 1.24.0
- jhc `1ff035af`, version 0.8.2
- Hugs `2719ab8`, the September 2006 tree (`Hugs/src/version.c:42`; its `Readme` still says May 2006), with cpphs 1.2
  (`Hugs/cpphs/cpphs.cabal:2`)
- nhc98 `b4d4152`, version 1.22 of 2010-07-09
- MicroHs `f17be7f0`, version 0.16.12.0; its list of extensions from the README before commit `e2b24fbb`, saved as
  `results/E5/others-data/microhs-README-e2b24fbb-parent.md`
- UHC `f2b94a90`
- Helium `5928bff4`, version 1.9

**Papers for the owner** (`results/E11/wanted.md`, for `/mnt/h/Rune/haskell2010`). No finding rests on them alone:
- Läufer, Odersky 1994, above: the typing of existentials the Haskell' page cites (D34's T4a, D37, D41). Read instead:
  Läufer 1992, Läufer and Odersky 1992, Läufer 1996.
- Odersky, Läufer. Putting type annotations to work. POPL 1996. doi:10.1145/237721.237729 (Crossref:
  `results/E11/dois2.tsv`). The system PVWS start from. Read instead: PVWS 2007, sections 3-4.
- Jones. Qualified Types: Theory and Practice. CUP, 1994. doi:10.1017/cbo9780511663086. Read instead: Jones 1992, 1995
  and 2000.
- Duck, Peyton Jones, Stuckey, Sulzmann. Sound and decidable type inference for functional dependencies. ESOP 2004.
  doi:10.1007/978-3-540-24725-8_5. Fetched, but its text cannot be extracted (Type 3 fonts); Sulzmann et al. 2007 is
  the journal version.
- Stuckey, Sulzmann. A theory of overloading. TOPLAS 27(6), 2005. doi:10.1145/1108970.1108974 (Crossref:
  `dois2.tsv`). Nothing read instead.
- Glynn, Stuckey, Sulzmann. Type classes and constraint handling rules. Workshop on Rule-Based Constraint Reasoning and
  Programming, 2000 (no DOI known). Read instead: Sulzmann et al. 2007.
- Perry. The implementation of practical functional programming languages. PhD thesis, Imperial College, 1991 (no
  DOI). Read instead: Läufer 1996.
- The Haskell' committee's private list, haskell-prime-private, 2006-2010: the reasons for the reset of July 2009 and
  the final list of November 2009 may be there. Read instead: the public archive and the wiki.

## Appendix: the extension table

Every LANGUAGE name GHC 9.14.1 accepts (E5: 148), one row each, from `results/E6/census.tsv` (the owner's row of
each name; `merge.py`). Columns as `results/E6/schema.md` defines them: the area; the tier T0-T8 (`-` for none); what
Core needs; runtime support; whether turning it on changes a valid 2010 program; HsLint's cost; the size estimate
(S under 300 lines, M to 1,000, L to 3,000, XL more; a starred size is E12's calibration from its prototypes, the
T1 group's four rows being one refactor of about 1,600-2,400 lines, not four); the census's
recommendation; and the Stackage LTS 24.67 packages naming it, and its No form (E7, of 3,392). The reason and the
evidence for each row are in the TSV. Tiers T0-T5 (T4 as T4a) and T8 fit the Haskell 98 checker with A+ (D34);
T4b, T6 and T7 wait for OutsideIn or a kinds roadmap (D37); a T4 row is T4a unless its recommendation is
later-outsidein.

| Name | Area | Tier | Core | Runtime | Changes 2010 | HsLint | Size | Rec | Packages |
|---|---|---|---|---|---|---|---|---|---|
| AllowAmbiguousTypes | types | T3 | none | none | no | mirror | S | now | 265 |
| AlternativeLayoutRule | layout | - | none | none | yes | none | M | never | - |
| AlternativeLayoutRuleTransitional | layout | - | none | none | no | none | S | never | - |
| ApplicativeDo | do,desugaring | T0 | none | none | yes | spec | L | later-other | 53 |
| Arrows | expressions,desugaring | T0 | none | none | yes | spec | L | later-other | 55 |
| AutoDeriveTypeable | deriving | - | none | none | no | none | S | never | 9 |
| BangPatterns | patterns,lexing | T0 | none | none | yes | mirror | M | now | 790 / No 1 |
| BinaryLiterals | literals | - | none | none | yes | none | S | now | 52 |
| BlockArguments | parsing | - | none | none | no | none | S | now | 128 |
| CApiFFI | ffi,runtime | - | prims | extensive | no | none | L | later-runtime | 52 |
| ConstrainedClassMethods | classes | T0 | none | none | no | mirror | S | now | 24 |
| ConstraintKinds | kinds,classes | T7 | systemf | none | no | spec | L | later-other | 433 |
| CPP | driver,lexing | - | none | none | yes | none | M | now | 1581 / No 1 |
| CUSKs | kinds | T7 | none | none | no | mirror | M | later-other | 2 / No 0 |
| DataKinds | kinds,renaming | T7 | systemf | none | no | spec | L | later-other | 744 |
| DatatypeContexts | types | T0 | none | none | yes | none | S | now | 2 / No 0 |
| DeepSubsumption | types | T5 | systemf | none | no | spec | M | later-other | 2 / No 1 |
| DefaultSignatures | classes | T1 | systemf | none | no | spec | M | now | 337 |
| DeriveAnyClass | deriving,classes | T0 | none | none | no | mirror | S | now | 205 |
| DeriveDataTypeable | deriving,classes | T5 | systemf | none | no | spec | L | later-other | 729 |
| DeriveFoldable | deriving | T0 | none | none | no | none | M | later-other | 216 |
| DeriveFunctor | deriving | T0 | none | none | no | none | M | now | 442 |
| DeriveGeneric | deriving,types | T6 | systemfc | none | no | spec | L | later-outsidein | 830 |
| DeriveLift | deriving,meta | T0 | none | none | no | none | M | later-meta | 77 |
| DeriveTraversable | deriving | T0 | none | none | no | none | M | later-other | 307 |
| DerivingStrategies | deriving,parsing | T0 | none | none | no | none | S | now | 379 |
| DerivingVia | deriving | T1 | cast | none | no | spec | M | now | 157 |
| DisambiguateRecordFields | records,renaming | - | none | none | no | none | S | now | 32 / No 1 |
| DoAndIfThenElse | parsing,do | - | none | none | yes | none | S | now | 37 |
| DoRec (deprecated, RecursiveDo) | do | T0 | none | none | yes | mirror | - | n/a | - |
| DuplicateRecordFields | records,renaming | - | none | none | no | none | M | now | 195 |
| EmptyCase | expressions | T0 | none | none | no | mirror | S | now | 106 |
| EmptyDataDecls | parsing,desugaring | - | none | none | yes | none | S | now | 188 |
| EmptyDataDeriving | deriving | T0 | none | none | no | none | S | now | 10 |
| ExistentialQuantification | types | T4 | systemf | none | yes | spec | L* | now | 302 |
| ExplicitForAll | parsing,types | T0 | none | none | yes | none | S | now | 52 |
| ExplicitLevelImports | meta,modules | - | none | extensive | no | none | M | later-meta | - |
| ExplicitNamespaces | modules,renaming | - | none | none | no | none | S | later-other | 68 / No 1 |
| ExtendedDefaultRules | classes | T8 | none | none | yes | mirror | M | later-other | 32 |
| ExtendedLiterals | literals,runtime | T7 | prims | small | yes | mirror | M | never | 1 |
| FieldSelectors | records,renaming | - | none | none | yes | none | S | now | 1 / No 107 |
| FlexibleContexts | classes | T1 | none | none | no | spec | L* | now | 1148 |
| FlexibleInstances | classes | T1 | none | none | no | spec | L* | now | 1300 |
| ForeignFunctionInterface | ffi,runtime | - | prims | extensive | no | spec | XL | now | 251 / No 2 |
| FunctionalDependencies | classes | T2 | none | none | no | spec | M* (upper end) | now | 383 |
| GADTs | types,parsing | T6 | systemfc | none | yes | spec | XL | later-outsidein | 643 |
| GADTSyntax | parsing | T0 | none | none | no | none | M | now | 19 |
| GeneralisedNewtypeDeriving (alias, GeneralizedNewtypeDeriving) | deriving,classes | T1 | cast | none | no | spec | - | n/a | - |
| GeneralizedNewtypeDeriving | deriving,classes | T1 | cast | none | no | spec | M | now | 892 / No 8 |
| GHC2021 (edition) | driver | - | none | none | yes | none | - | n/a | - |
| GHC2024 (edition) | driver | - | none | none | yes | none | - | n/a | - |
| GHCForeignImportPrim | ffi,runtime | T7 | prims | extensive | no | spec | L | never | 10 |
| Haskell2010 (edition) | driver | - | none | none | no | none | - | n/a | - |
| Haskell98 (edition) | driver | - | none | none | yes | none | - | n/a | - |
| HexFloatLiterals | literals | - | none | none | yes | none | S | now | 9 |
| ImplicitParams | types,lexing | T2 | none | none | yes | spec | L | later-other | 58 |
| ImplicitPrelude | modules,renaming | - | none | none | yes | mirror | S | now | 4 / No 375 |
| ImplicitStagePersistence | meta | - | none | none | no | none | S | later-meta | - |
| ImportQualifiedPost | modules,parsing | - | none | none | no | none | S | now | 161 |
| ImpredicativeTypes | types | T5 | systemf | none | yes | spec | L | later-other | 19 |
| IncoherentInstances | classes | T1 | none | none | no | spec | S | later-other | 18 / No 2 |
| InstanceSigs | classes | T3 | none | none | no | spec | M | now | 210 |
| InterruptibleFFI | ffi,runtime | - | prims | extensive | no | none | S | later-runtime | 9 |
| JavaScriptFFI | ffi | - | prims | extensive | no | none | L | never | 9 |
| KindSignatures | kinds | T0 | none | none | no | mirror | S | now | 341 |
| LambdaCase | expressions | T0 | none | none | yes | mirror | S | now | 928 |
| LexicalNegation | lexing,expressions | - | none | none | yes | none | S | now | - |
| LiberalTypeSynonyms | types | T0 | none | none | yes | mirror | S | now | 65 |
| LinearTypes | types | T7 | systemf | none | yes | spec | XL | later-other | 6 |
| ListTuplePuns | parsing,kinds | T7 | none | none | yes | none | S | later-outsidein | No 2 |
| MagicHash | lexing,runtime | T0 | prims | small | yes | none | S | never | 357 |
| MonadComprehensions | comprehensions | T0 | none | none | yes | mirror | M | later-other | 15 |
| MonoLocalBinds | types | T8 | none | none | yes | mirror | S | now | 72 / No 11 |
| MonomorphismRestriction | types | T8 | none | none | yes | mirror | S | now | 10 / No 163 |
| MultilineStrings | literals,lexing | - | none | none | no | none | S | now | - |
| MultiParamTypeClasses | classes | T1 | none | none | no | spec | L* | now | 933 |
| MultiWayIf | expressions,layout | T0 | none | none | no | mirror | S | now | 240 |
| NamedDefaults | classes,modules | T8 | none | none | no | mirror | M | later-other | - |
| NamedFieldPuns | records,renaming | - | none | none | no | none | S | now | 288 |
| NamedWildCards | types,renaming | T3 | none | none | yes | spec | S | later-other | 9 / No 1 |
| NegativeLiterals | literals,lexing | - | none | none | yes | none | S | now | 23 |
| NondecreasingIndentation | layout | - | none | none | no | none | S | now | 18 |
| NPlusKPatterns | patterns | T0 | none | none | no | mirror | S | now | - |
| NullaryTypeClasses (deprecated, MultiParamTypeClasses) | classes | T1 | none | none | no | spec | - | n/a | - |
| NumDecimals | literals | T0 | none | none | yes | mirror | S | now | 9 |
| NumericUnderscores | literals | - | none | none | yes | none | S | now | 78 |
| OrPatterns | patterns | T0 | none | none | no | mirror | M | now | - |
| OverlappingInstances | classes | T1 | none | none | no | spec | M | now | 29 |
| OverloadedLabels | lexing,classes | T7 | none | none | yes | spec | M | later-outsidein | 49 |
| OverloadedLists | literals,classes | T6 | systemfc | none | yes | spec | M | later-outsidein | 97 / No 1 |
| OverloadedRecordDot | records,expressions | T7 | none | none | yes | spec | M | later-outsidein | 27 |
| OverloadedRecordUpdate | records | T7 | none | none | yes | spec | M | later-other | - |
| OverloadedStrings | literals,classes | T1 | none | none | yes | mirror | M | now | 1499 / No 6 |
| PackageImports | modules,driver | - | none | none | no | none | S | later-other | 92 |
| ParallelArrays | comprehensions | - | none | none | no | none | S | never | - |
| ParallelListComp | comprehensions | T0 | none | none | no | mirror | S | now | 72 |
| PartialTypeSignatures | types | T3 | none | none | no | spec | M | later-other | 61 |
| PatternGuards | patterns | T0 | none | none | no | mirror | M | now | 219 / No 6 |
| PatternSignatures (deprecated, ScopedTypeVariables) | types,patterns | T3 | none | none | yes | spec | - | n/a | - |
| PatternSynonyms | patterns | T4 | systemf | none | yes | spec | L | later-outsidein | 366 |
| PolyKinds | kinds | T7 | systemf | none | no | spec | XL | later-other | 335 / No 4 |
| PolymorphicComponents (alias, RankNTypes) | types | T5 | systemf | none | yes | spec | - | n/a | - |
| PostfixOperators | expressions | T0 | none | none | yes | mirror | S | now | 15 |
| QualifiedDo | do | T0 | none | none | yes | mirror | S | now | 2 |
| QuantifiedConstraints | classes | T5 | systemf | none | yes | spec | L | later-other | 74 |
| QuasiQuotes | meta,lexing | - | none | extensive | yes | none | L | later-meta | 291 |
| Rank2Types (alias, RankNTypes) | types | T5 | systemf | none | yes | spec | - | n/a | - |
| RankNTypes | types | T5 | systemf | none | yes | spec | L* | now | 967 |
| RebindableSyntax | desugaring,renaming | T0 | none | none | yes | mirror | M | later-other | 28 / No 2 |
| RecordPuns (deprecated, NamedFieldPuns) | records | T0 | none | none | no | none | - | n/a | - |
| RecordWildCards | records,renaming | - | none | none | no | none | M | now | 801 / No 1 |
| RecursiveDo | do | T0 | none | small | yes | mirror | M | later-other | 55 |
| RelaxedLayout | layout | - | none | none | no | none | S | never | - |
| RelaxedPolyRec | types | T8 | none | none | no | mirror | S | now | 6 |
| RequiredTypeArguments | types,renaming | T5 | none | none | no | spec | L | later-other | 3 |
| RoleAnnotations | types | T1 | cast | none | no | spec | M | later-other | 113 |
| Safe (safety) | safety,modules | - | none | none | yes | none | L | later-other | 162 |
| ScopedTypeVariables | types,renaming | T3 | none | none | yes | spec | M | now | 1401 |
| StandaloneDeriving | deriving | T0 | none | none | no | none | S | now | 580 |
| StandaloneKindSignatures | kinds | T0 | none | none | no | mirror | S | now | 43 |
| StarIsType | kinds,parsing | T0 | none | none | no | none | S | now | 3 / No 69 |
| StaticPointers | runtime,expressions | - | prims | small | yes | spec | L | never | 3 |
| Strict | evaluation,desugaring | - | none | none | yes | none | M | now | 40 / No 1 |
| StrictData | evaluation | - | none | none | yes | none | S | now | 204 / No 3 |
| TemplateHaskell | meta,runtime | - | none | extensive | yes | spec | XL | later-meta | 668 |
| TemplateHaskellQuotes | meta | - | none | small | yes | spec | L | later-meta | 97 |
| TraditionalRecordSyntax | records | - | none | none | yes | none | S | now | 2 |
| TransformListComp | comprehensions | T5 | systemf | none | yes | spec | M | later-other | 7 |
| Trustworthy (safety) | safety,modules | - | none | none | no | none | S | now | 228 |
| TupleSections | expressions | T0 | none | none | no | mirror | S | now | 504 |
| TypeAbstractions | types,patterns | T3 | none | none | yes | spec | M | later-other | 16 |
| TypeApplications | types,expressions | T3 | none | none | no | spec | M | now | 625 / No 5 |
| TypeData | kinds,parsing | T7 | systemf | none | no | spec | M | later-other | 4 |
| TypeFamilies | types | T6 | systemfc | none | yes | spec | XL | later-outsidein | 1042 |
| TypeFamilyDependencies | types | T6 | systemfc | none | yes | spec | M | later-outsidein | 56 |
| TypeInType (deprecated, DataKinds,PolyKinds) | kinds | T7 | systemf | none | no | spec | - | n/a | 58 |
| TypeOperators | parsing,types | T0 | none | none | no | none | M | now | 715 |
| TypeSynonymInstances | classes | T0 | none | none | no | mirror | S | now | 295 |
| UnboxedSums | runtime,kinds | T7 | prims | small | yes | spec | L | never | 16 |
| UnboxedTuples | runtime,kinds | T7 | none | none | yes | spec | L | later-other | 219 |
| UndecidableInstances | classes | T1 | none | none | no | spec | L* | now | 687 / No 2 |
| UndecidableSuperClasses | classes | T1 | none | none | no | spec | M | later-other | 60 |
| UnicodeSyntax | lexing | - | none | none | yes | none | S | now | 45 |
| UnliftedDatatypes | kinds,runtime | T7 | none | small | no | spec | L | never | 3 |
| UnliftedFFITypes | ffi | T7 | prims | small | no | spec | M | never | 50 |
| UnliftedNewtypes | kinds,runtime | T7 | cast | small | no | spec | M | never | 19 |
| Unsafe (safety) | safety,modules | - | none | none | no | none | S | now | 36 |
| ViewPatterns | patterns | T0 | none | none | no | mirror | M | now | 431 |

## Appendix: the clause delta

E1's `results/E1/clauses2010.tsv` has one row per normative clause of the 2010 Report, mapped to the 98 table's
3,901 rows. By chapter of the 2010 Report (`clauses2010-counts.tsv`):

| chapter2010 | same | changed | new | removed-in-2010 | total |
|---|---|---|---|---|---|
| 1 | 11 | 0 | 0 | 0 | 11 |
| 2 | 270 | 3 | 5 | 0 | 278 |
| 3 | 428 | 5 | 26 | 0 | 459 |
| 4 | 476 | 6 | 10 | 0 | 492 |
| 5 | 244 | 2 | 3 | 0 | 249 |
| 6 | 305 | 2 | 0 | 0 | 307 |
| 7 | 53 | 0 | 0 | 0 | 53 |
| 8 | 0 | 0 | 54 | 0 | 54 |
| 9 | 472 | 2 | 0 | 0 | 474 |
| 10 | 284 | 26 | 26 | 0 | 336 |
| 11 | 165 | 0 | 2 | 0 | 167 |
| 12 | 10 | 0 | 8 | 0 | 18 |
| 13 | 0 | 63 | 38 | 0 | 101 |
| 14 | 0 | 73 | 2 | 0 | 75 |
| 15 | 0 | 0 | 52 | 0 | 52 |
| 16 | 0 | 84 | 39 | 0 | 123 |
| 17 | 0 | 43 | 2 | 0 | 45 |
| 18 | 0 | 0 | 75 | 0 | 75 |
| 19 | 0 | 37 | 16 | 0 | 53 |
| 20 | 0 | 203 | 67 | 0 | 270 |
| 21 | 0 | 21 | 9 | 0 | 30 |
| 22 | 0 | 41 | 2 | 0 | 43 |
| 23 | 0 | 0 | 73 | 0 | 73 |
| 24 | 0 | 0 | 1 | 0 | 1 |
| 26 | 0 | 0 | 149 | 0 | 149 |
| 27 | 0 | 0 | 58 | 0 | 58 |
| 28 | 0 | 0 | 301 | 0 | 301 |
| 29 | 0 | 0 | 37 | 0 | 37 |
| 30 | 0 | 0 | 2 | 0 | 2 |
| 31 | 0 | 0 | 16 | 0 | 16 |
| 32 | 0 | 0 | 40 | 0 | 40 |
| 33 | 0 | 0 | 11 | 0 | 11 |
| 34 | 0 | 0 | 20 | 0 | 20 |
| 35 | 0 | 0 | 66 | 0 | 66 |
| 36 | 0 | 0 | 14 | 0 | 14 |
| 37 | 0 | 0 | 52 | 0 | 52 |
| 38 | 18 | 48 | 0 | 0 | 66 |
| 39 | 0 | 15 | 0 | 0 | 15 |
| 40 | 0 | 13 | 6 | 0 | 19 |
| 41 | 0 | 182 | 48 | 0 | 230 |
| 42 | 0 | 43 | 28 | 0 | 71 |
| removed | 0 | 0 | 0 | 253 | 253 |
| all | 2736 | 912 | 1358 | 253 | 5259 |

## Appendix: defects

Reproducers under the drafts' `results/`. Nothing here was fixed by this roadmap.

| Directory | What | State |
|---|---|---|
| `E3/defects/rule1-signed/` | The checker accepts a signed binding in a group Rule 1 restricts; HsLint refuses it at level 2 | live at `75ed95861`; likely on `haskell98`'s tip (the Rule 1 code is untouched after the pin) [deduced] |
| `D16-probes/` (`PatGen.hs`) | The checker accepts a signature more general than a non-simple pattern binding gives (`p :: a -> a`, `(p, q) = (not, 'x')`); HsLint refuses it | live at `75ed95861`, both modes |
| `E3/dotted/` | `--dotted-names` in neither the unit's configuration nor its key: one reading's unit served the other | live at `75ed95861`; fixed after it on `haskell98` (build-cache issue 27) |
| `E9/probes/MaybeClash.hs`, `E9/probes/maybeprobe/`, `E9/probes/RatioParen.hs` | Data.Maybe's and Data.Ratio's printed code does not compile (the 2010 Report's defects) | in the text since 2010-07-20 |

## Appendix: prototypes

Each is a patch under the drafts' `patches/`, evidence and not code to land as it stands. Each applies to
`75ed95861`; E4's rejects 12 of its 121 hunks on `haskell98`'s tip (`results/E4/other-session.md`).

| Patch | Experiment | What |
|---|---|---|
| `E3-00-stub` to `E3-08-dotted` (a series) | E3 | `--language`, n+k off, DoAndIfThenElse, empty data, pattern guards, relaxed groups, `foreign`, the LANGUAGE pre-scan, hierarchical lexing |
| `E4-language-record.patch` | E4 | The language record, the library descriptor, keys, two snapshots |
| `E13-language-record-b9.patch` | E13 | E4's record at build 9: positions for language errors, C3's refusal, HsLint's per-group rule |
| `E10-ffi-prototype.patch` | E10 | The four kinds of ccall import over Rune's `foreign`, the marshallability check, a sliver of Foreign.* |
| `E12-T1.patch`, `E12-T2.patch`, `E12-T4.patch`, `E12-T5.patch`, `E12-T1T2-cumulative.patch`, `E12-cumulative.patch` | E12 | One type extension or group for each of T1, T2, T4a and T5, on A+ |

The oracles E8 built are under the drafts' `oracles/` (`ghc2010/`: the 2010 shim for GHC 9.4.7; `mhs2010-shim/`). The
worktrees hold the reference tree (`.worktrees/h10-base`) and the prototypes' working trees (`h10-f`, `h10-a`, `h10-v`,
`h10-n`); their cleanup is the owner's.

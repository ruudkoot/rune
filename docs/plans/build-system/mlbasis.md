# ML Basis as Rune's build language

**Status:** a question for a roadmap, not started, nothing decided. Written
2026-11-04, while `build-system-v2` (branch `build-system-v2`) was finishing its
last milestones. This document says why the question arises, what is known, and
what a roadmap must find out before anything is built.

## Why this question

The owner, 2026-11-04, on build-system-v2's finding that MLton cannot be both
headered and well-formed: "this makes me think we made a mistake during this
roadmap: our build language should have been mlbasis (.mlb) instead (maybe with
some small extensions). this is too big of a change to do now - it needs a full
roadmap to do the proper analysis before implementing."

The finding (build-system-v2, M14):
- Under D9, a name a library with a header exports clashes with the same name
  from the Basis or another library, and the clash is an error.
- M9 translated MLton's 27 `.mlb` files into 30 libraries with headers. They
  export 16 Basis names (`List`, `Array`, `String`, `Int` and others), and 5
  names come from two or three of the libraries.
- MLton's `.mlb` files rely on shadowing in order, which is SML's own rule for
  declarations, and on `local` to keep two declarations of one name apart.
- `.build` has lost both. M9 removed `local`, and M14, by the owner's ruling,
  removed `use DIR/library.build`, which had let shadowing happen.
- So MLton is now built from a flat build. 13 of its 606 units are not
  well-formed under M16's restriction: each declares a name that another unit
  also declares, which MLB's `local` had kept apart.
  - The names: `STREAM` and `Stream` (`lib/mlton/basic` against
    `lib/mlyacc-lib`), `MLton` (the two stub copies), `CONTROL`, `FIELD`,
    `FIELD_STRUCTS` and `Field` (`mlton/control` and `mlton/atoms` against
    `lib/mlton/basic`), and xml's `SHRINK`, `TYPE_CHECK` and `SimplifyTypes`
    and x86's `PEEPHOLE` against their `ssa/` and amd64 originals.
  - The test `scenarios/deps/wellformed-mlton` expects exactly these 13 units
    (17 warnings), and fails on one more or one fewer. It runs only where
    `RUNE_WELLFORMED_MLTON` names MLton's flat tree; `make check` skips it.
  - The evidence is in the build-system drafts,
    `~/.cache/claude-rune-drafts/build-system/impl/`: MLton's flat tree and its
    translator (`bs-m14/mlton-flat/`, `bs-m14/mlb2build3.py`), M9's library
    form that D9 cannot express (`bs-m16/mlton-m9/`), and the clash
    reproducers (`bs-m14/clash/`). Keep them when the drafts are cleaned up.

**How the roadmap missed it.** D5 chose among a declarative `.build`, an SML
program, and a typed plan with `.build` as its normal form. MLB was studied
closely, as prior art: *What the implementations do*, E9 and E26. But adopting
it was never put as an option. Several of the roadmap's results are MLB's
semantics, found again:
- Written order is the meaning (D6).
- A build file used twice is elaborated once (D8's replay rule).
- Exports are a filter (D8).
- Basis versions are other views of one implementation (D12).
- A library is hermetic: E9 found `.build`'s `use` elaborating in the caller's
  basis where an `.mlb` starts empty, and `docs/build.md`'s "its semantics is
  MLB's" wrong there.
- Logical, relocatable names (D3, D4) are what MLB's path variables and path
  maps give.

## What ML Basis is

The reference is MLton's `doc/guide/src/MLBasisSyntaxAndSemantics.adoc`, and
the formal semantics in the style of the Definition is
`mlton/doc/mlb-formal/mlb-formal.tex` (Cejtin, Fluet, Jagannathan, Weeks,
2004).

**Syntax:**
- Basis declarations: `basis b = basexp`, `open b`, `local ... in ... end`,
  `structure A = B` (and `signature`, `functor`), source files (`.sml`, `.sig`,
  `.fun`), other `.mlb` files, and `ann "..." in ... end`.
- Basis expressions: `bas ... end`, `let ... in ... end`.
- Paths may hold path variables, `$(SML_LIB)`, expanded by a path map.

**Semantics:**
- Sequencing merges bases, later bindings taking precedence, as SML
  declarations do.
- An `.mlb` file is elaborated starting in an empty basis, and the importer's
  basis does not affect it.
- Each `.mlb` file is elaborated and evaluated once, however often it is
  included.
- There is no implicit Basis: a file includes `$(SML_LIB)/basis/basis.mlb`, or
  another view such as `basis-1997.mlb`.

**Who reads it:**
- **MLton**, natively.
- **MLKit and SMLtoJs**, natively, with separate compilation keyed by
  `(uid, mlbid)` (Elsman 2008, §6.2). MLKit's dialect is stricter: a source
  file may be included "at most once in an entire MLB source-hierarchy"
  (`mlkit/NEWS.md:719-721`).
- **Millet**, the SML language server, reads `.mlb` and `.cm` group files.
  Not checked here.
- **SML/NJ** reads CM, not MLB. Its `smlnj-lib` ships `.mlb` files beside its
  `.cm` files for JSON, SExp and ml-lpt: 9 in `~/reference/smlnj`.
- **Poly/ML** reads neither.

**What is written in it:**
- `~/reference/mlton` holds 93 `.mlb` files, and HOL4's tools 5, flattened today
  by `tools-rune/mlb-files.sh`.
- The SML '97 corpus has 9 `.mlb` and 6 `.cm` files.
- Rune's tree tracks 80 `.mlb` files, nearly all bug reports for MLton and MLKit.
- **Rune already writes MLB for two of its hosts.** `Makefile:129` makes
  `build/rune.mlb` for MLton and `build/rune-mlkit.mlb` for MLKit, beside
  `build/rune.cm` and `build/polyml-build.sml`. Both are generated from the
  committed plans (M11).

## Where `.build` and MLB stand today

| Concern | MLB | `.build` after build-system-v2 |
|---|---|---|
| Order | Written order | Written order (D6) |
| Included twice | Elaborated once | Elaborated once (D8's replay rule) |
| Hiding | `local ... in ... end`, anywhere | A library's header alone; `local` gone (M9) |
| A name defined twice | Later shadows earlier | Clash error where a header is on one side (D9); rename at import (M10) |
| What a library sees | Its includes alone, from an empty basis | The Basis and its header's `requires` (M8) |
| The Basis | Included explicitly; a view is another `.mlb` | Implicit; views are seals selected by `view NAME` (M10) |
| Logical names | Path variables and a path map | `LIBRARY:PATH` under a workspace root (M3, D4) |
| Libraries, friends, reaching in | None: any file may be included by any path | Headers, friends, reaching in an error (M8, M14) |
| Loading | Everything included is elaborated and evaluated | Available is not loaded: selection by uses (D7) |
| Generated sources, preprocessors | None | `generate`, `preprocessor` (M15) |
| Picking an implementation | Path variables (MLton's `TARGET_ARCH`) | Virtual libraries and `implements` (M22) |
| Options | `ann` | `annotate`, `strict`, `inline` |
| Hosts | MLton and MLKit natively | None natively; plans flattened (M11) |

## What MLB lacks that Rune uses

Each row needs an answer: drop it, a convention, an annotation, or a path map.
Each must also pass the owner's rule against a mechanism with one user
(2026-11-03, on `shadows`).

1. **Loading by need.** The Basis is 195 demand files. Hello compiles 2 of them
   by mention and 278 with `--basis all`, 295M against 3,551M instructions (E3).
   MLB elaborates and evaluates all it includes; MLton removes what is dead
   after a whole-program compile, which a VM cannot do. Rune's `annotate
   "demand"` could become an `ann`, but its meaning must be stated against
   MLB's "evaluated once, in order". That is sound only where a file's
   evaluation has no effect, or its effect is allowed to move. This is the
   largest question.
2. **Libraries.** MLB has none. One candidate: a library is a directory under a
   root that a path map names, with one public `.mlb`. Including any other file
   under that root from outside is reaching in. Then what is a friend? A test
   commonly includes an internal `sources.mlb`.
3. **Declared dependencies** come free: an `.mlb` sees its includes and nothing
   else, so D7's "declared, not transitive" holds by construction. Check that
   the plan's `requires` can be derived, not written.
4. **Generated sources and preprocessors** (M15, HOL4's quotations). MLton
   leaves them to make. Keep them outside, as Holmake does, or add an
   annotation. Count M15's users first.
5. **Virtual libraries** (M22) against path variables, which already pick
   implementations in MLton. M21's functor signatures are language, and are
   not touched.
6. **Workspace roots** (D4) against `mlb-path-map` files, which MLton and MLKit
   both read.
7. **Namespaces** (D9). MLB's answer is SML's: shadowing, and `structure A = B`
   to rename. A lint could warn where a library shadows a Basis name. D9's
   clash error would go.
8. **The restriction** (M16). "One module name in two units" is a global rule.
   Under MLB, names are scoped by bases, so the rule must be per basis.
   Otherwise MLton's 13 units fail it again.
9. **One way of doing things** (the brief). MLB has `basis`, `let`, `open` and
   `local`. Building third-party MLB unchanged means accepting all of them.
   That is several ways to write a thing, but every one is standard.

## What carries over

Most of build-system-v2 lies below the surface language, and D5 already made a
typed plan the contract, with room for other forms that produce it. An `.mlb`
reader that produces a plan keeps:
- the plan (M9);
- units, logical names, layers, codecs, the warm path and the store (M3-M7);
- hosts' lists (M11), simpler, since MLton and MLKit would read the source;
- the library index (M12), fed from MLB's export lists;
- the restriction (M16), per basis;
- functor signatures (M21);
- the editor (M17-M20).

What would be replaced or reshaped:
- the `.build` parser and headers (M8);
- rename at import and the clash rule (M10, D9);
- the migration (M13) and the rule on reaching in (M14);
- the syntax of steps (M15) and of virtual libraries (M22);
- Basis views (M10, D12).

The plan's schema must grow at least by named and anonymous bases, for `basis`,
`let` and `open`.

## Why an interface edit re-checks every later file

This is the editor's cost that build-system-v2 could not bring down to its
target, and the build language's semantics is its cause.

**The target.** D28 asks that an edit to a unit's interface cost
O(clients): the units that use what changed, and no others. At the close it
is O(later units), at about a seventh of its first cost per unit (M20).

**How the editor works.** Analysis keeps a context's units between edits.
`.build` says a unit sees what the steps before it leave, so each unit is
checked in the environment that all units before it leave: D2 kept that
meaning, and loads it by need. When an edit changes a unit's interface, the
environment of every later unit changes with it.

**What M17 and M20 achieved.**
- A later unit that does not use a changed name is not type-checked again.
- M20 narrowed the walk: it looks at a later unit's usages only where a unit
  before it bound a name they use and changed identity.
- But every later unit is still taken again into the new environment, which
  costs about 40k VM instructions a unit, against 340k before. A walk rebuilds
  its structures in one pass from the edited unit on: the binders of each place,
  the units loaded by need, their order, and the paths a type is printed by.
- At CI's 1,017 units, a name added costs 120M VM instructions (0.18 s) and a
  constructor added 454M (0.9 s). At 10k units the taking again would add
  roughly 0.4G, half a second to a second.

**What O(clients) needs.** A non-client unit must not be touched at all. The
walk's structures would have to change in place for the changed names alone,
in the middle of a walk. More fundamentally, a unit's environment would have to
be the closure of what it depends on, not everything before it. D2 rejected
that as the language's meaning (option C: "a Rune 2 question"), because it
changes what SML programs mean under `.build`'s semantics. M20 judged the work
milestone-sized, and build-system-v2 leaves it to *Later*.

**Why it belongs here.** An `.mlb` file is elaborated from an empty basis and
sees only what it includes. Under MLB, then, closures are the language's own
meaning at the level of an `.mlb` file, with no restriction added. An interface
edit could reach only the `.mlb` files that include the changed one, directly
or through others, and the editor's walk could stop at that boundary. Within
one `.mlb` file, order is still the meaning, so the cost there stays O(later
units of that file). That makes it bounded by the file's size, not the
workspace's.

## What the roadmap must answer

1. **One way or two.** Does MLB replace `.build`, the owner's "one way", with a
   migration of the 123 tracked build files and of the win32 work's, after D15's
   window? Or does it stand beside it?
2. **Which MLB.** MLton's, MLKit's, or their intersection? What Rune refuses
   (MLKit refuses a file included twice), and what it adds as `ann`, each with
   its users.
3. **Loading by need under MLB's semantics** (item 1 above). Measure hello, the
   test suite and `rune.build` under each answer.
4. **Libraries, friends, reaching in and tests** on path maps and conventions,
   against D8, D10 and D11's decisions. Which of them survive, and in what
   form?
5. **The Basis as `basis.mlb`**, its views as other `.mlb` files, and what that
   costs D12's seals.
6. **The plan.** Is a plan made from MLB equal to one made from today's `.build`
   on every tracked build? Does it round-trip?
7. **Hosts.** MLton and MLKit build Rune from its own `.mlb`, and SML/NJ and
   Poly/ML from a flattened list. Does S43 hold, and what does `bootstrap.md`
   need?
8. **The editor.** D26's contexts become "which `.mlb` roots reach this file".
   What does Millet do, and what does it get wrong at scale?
9. **HOL4.** Its tools are MLB already. Can its theories be expressed without
   M15's steps, or do the steps stay?
10. **The cost.** Which of build-system-v2's L-track work is undone, and what is
    the migration's size?
11. **Interface edits.** Does elaborating each `.mlb` from an empty basis let
    the editor stop an interface edit's walk at the `.mlb` files that include
    the changed one? What does it cost the batch compiler's warm path, which
    also loads the prefix by need (D2)?

## Experiments, before writing the roadmap

- **E1.** An `.mlb` reader that produces today's plan, on MLton's 27 `.mlb`
  files unchanged and HOL4's tools. Compare units, bytes and well-formedness
  against today's flat MLton build.
- **E2.** Rune's own builds written as `.mlb`, by a translator from the plans:
  `rune.build`, the libraries and the Basis. Measure what has no MLB form.
- **E3.** Loading by need under MLB: hello, `--basis all`, the test suite. Count
  instructions.
- **E4.** MLton and MLKit compiling Rune from the translated `.mlb` directly, in
  place of the generated `build/rune.mlb`.
- **E5.** Millet on Rune's tree and on MLton, set against `runelsp`.
- **E6.** On MLton's `.mlb` files: for each of M20's interface edits, how many
  units an `.mlb`-bounded walk would take again, against today's O(later
  units). Count VM instructions on the CI fixture and on MLton.

Each states its prediction first, as build-system-v2's experiments did.

## Constraints

- S41 (cold = warm), S42 (units-whole = whole), S43 (hosts agree) and S58 (`-j`
  changes no byte) hold through any change.
- The win32 work is migrated only when its owner says (D15).
- No mechanism is added for a single user.
- The REPL keeps the whole Definition.
- `build-system-v2`'s record stands as written. This document does not reopen
  its decisions, but a roadmap may, with the owner.

## Relation to other plans

- `build-system-v2.md`: D5, D6, D8, D9, D10, D12 and D15 are the decisions at
  stake. Its plan, store, units and editor work carry over.
- `rune2/separate-compilation.md`: Rune 2's units and imports in source. MLB is
  a build-file answer, and HOL4's `Ancestors`/`Libs` headers an in-source one.
- `bootstrap.md`: how hosts build Rune.
- `language/haskell98.md`: rhc builds through `lib/compiler` and the plan. Ask
  what it needs from the build language.

## Out of scope

A package manager, and higher-order modules, as in build-system-v2.

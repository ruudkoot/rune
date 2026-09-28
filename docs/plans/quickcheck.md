# Roadmap: property testing, and laws that are tested

Rune's documentation makes two kinds of claims about its library.
- **Examples**, such as `take ([1, 2, 3], 2) = [1, 2]`. The equations among them have been run since the docgen roadmap.
- **Laws**, such as `rev (rev l) = l`, which claim to hold for every value of their free variables. None has ever been run.

This roadmap plans the library that tests the second kind: Rune's first
library besides the Basis, `lib/test/property`, a QuickCheck for Standard
ML, with a small `lib/random` under it. It then plans the use runedoc
makes of it: every example becomes a claim that runs, and every law is
tested on generated values, with the counterexample shrunk until a
person can read it.

It was written on 2026-09-27 against `d278153`, the merge of the JIT
roadmap into master. It was then rebased onto master at `7fff793`, the
merge of the structure-docs work, and its census and citations were made
again there. It lives in a worktree, on branch `quickcheck`.

What it rests on:
* **The code.** A reading of runedoc (`src/doc`), the driver's handling of the Basis (`src/driver`), the Basis's comments, and the Basis suite's harness (*Where we are*).
* **A census**, on master, of the 286 laws (387 code spans) and of the 21 example spans that are not run. It records syntax, types and the checks written beside the laws, and nothing about whether a law holds (*Where we are*, *The blind test*).
* **A prototype** of about 300 lines: SplitMix64, generators over an implicit sample tree, and internal shrinking. It was run on the named law, planted bugs, problems of the shrinking challenge and properties of its own functions, never on another documented law (*The experiments*).
* **The literature and the implementations**, in Standard ML and in languages with and without type classes (*What the literature says*, *What the implementations do*, *References*).

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | The Example rule | done 2026-09-28 |
| M2 | Libraries: `rune --library` | done 2026-09-28 |
| M3 | `lib/random` | done 2026-09-28 |
| M4 | The property core | done 2026-09-28 |
| M5 | Shrinking and functions | done 2026-09-28 |
| M6 | The Basis's instances, and the generators frozen | done 2026-09-28 |
| M7 | Laws elaborated | done 2026-09-28; the rewrites await the owner's review |
| M8 | Laws run | |
| M9 | The hunt | |

The owner decided D1 to D13 on 2026-09-28, every one as recommended
(*Decisions*). M1 is independent of
the rest and can be done first. M2 to M6 are part 1 of the brief; M1 and
M7 to M9 are part 2.

## The request

The owner's brief, as written:

> - we are going to add our first non-basis library to Rune: rune/lib/test/property
> - this will be the Rune/SML equivalent of Haskell's QuickCheck. please study it carefully
> - Haskell QuickCheck relies on typeclasses which Rune/SML does not have. study other SML implementation of quickcheck and quickchek implementation in other languages to see how they handle the lack of typeclasses.
> - part 1 of the roadmap is to design and implement the rune/lib/test/property (quickcheck) library
> - part 2 is using it in runedoc:
>   - each Example in the documentation must be of type bool and need to evaluate to true. i.e. it can have no free variables
>   - Laws are allowed to have free variables and rune/lib/test/property will be used to test the laws by generating arbitrary values 
>   - i believe the current documentation contains a law that is both subtly wrong under sml '97 semantics (i.e. the claimed law does not hold). this law would be very hard to test with rune/lib/test/property and it would be even harder to find the exception to law. so it would be a very good test case to see if it can be found using property testing
> - rune/lib/test/property should use to quickcheck principles of arbitrary data generation and shrinking when a counterexample is found
> - you may need an auxiliary library rune/lib/random

**The owner's answers while this was written (2026-09-27 and 28):**
- **Where it was written:** in a worktree, `/home/ruud/rune-quickcheck`, on a new branch `quickcheck` from master, committed as M0 and not pushed.
- **The named law:** a wrong law found while writing, the division law of `INTEGER`, is named here (*The named law*).
- **The owner's law** is a different one, and stays a blind test (*The blind test*).
- **The decisions** (2026-09-28): the owner took every recommendation, D1 to D13.

| The brief asks | Answered in |
|---|---|
| Rune's first library besides the Basis | D1, M2 |
| study QuickCheck carefully | *What the literature says*, *What the implementations do* |
| how other SML libraries and other languages do without type classes | *What is different for SML*, *What the implementations do*, D4 |
| part 1: design and build `lib/test/property` | *The architecture*, D1 to D6, M2 to M6 |
| part 2: every example a `bool` that is true, with no free variables | D11, M1 |
| part 2: laws with free variables, tested on generated values | D5 to D8, M7, M8 |
| the law the owner believes wrong, as a test case | *The blind test*, M9; and one found already, *The named law* |
| generation and shrinking, as QuickCheck does | D3, *Generator principles*, M4, M5 |
| perhaps a `lib/random` | D2, M3 |

## Where we are

### Examples

`docs/doc-comments.md` ("Examples that run") sets the rule today: a piece
of code in an `Example:` paragraph that is an equation, `e = v`, is a
claim, checked twice.

1. **When the documentation is made,** `DocElab.checkExample` (`src/doc/docelab.sml:464-472`) elaborates it as `val it : bool = ...` under `let open S in ... end`.
   - `S` is the structure with the shortest name among those the specification requires, plus `open S.Sub` for a member of a substructure (`src/doc/docexamples.sml:45-73`).
   - An example that is no Standard ML, names something that is not there, or compares what has no equality is an error at its comment.
2. **When `make test-basis` runs,** `runedoc --examples DIR` writes one program per signature (`src/doc/docexamples.sml:81-91`), and `tests/basis/run-examples.sh` compiles and runs them. An example that is `false`, or raises, fails.

Which pieces count as equations is decided by `DocExamples.isEquation`
(`src/doc/docexamples.sml:24-38`). What is not an equation is shown but
never run.

The Basis has 793 `Example:` paragraphs with 810 code spans. 789 of the
spans are run, in 65 signatures (`docs/generated/basis/coverage.md`,
"Examples that are run"). The other 21 are:

| Where | Span | What it is | Rewrite (M1) |
|---|---|---|---|
| `runtime_sig.sml:73` | `#objects (#2 (profile (fn () => ()))) <= 1` | a closed `bool` that is no equation | run as it is (D11) |
| `sig_list.sml:235` | `3 - (2 - (1 - 0))` | a side piece ("which is") | `foldl (op -) 0 [1, 2, 3] = 3 - (2 - (1 - 0))` |
| `sig_list.sml:247` | `1 - (2 - (3 - 0))` | the same for `foldr` | likewise |
| `sig_list_pair.sml:160` | `all (op =) ([1, 2], [1, 2, 3])`, `true` | a side piece with its result in prose | one equation |
| `sig_net_host_db.sml:51` | `Option.map (toString o addr) (getByName "localhost")`, `SOME "127.0.0.1"`, `/etc/hosts` | a result in prose, and a path; the prose makes it depend on the machine | an equation, or prose |
| `sig_net_host_db.sml:63` | `Option.map name (getByAddr ...)`, `SOME "localhost"` | a result in prose, "on most machines" | likewise |
| `sig_net_prot_db.sml:26` | `Option.map protocol (getByName "tcp")`, `SOME 6`, `/etc/protocols` | a result in prose, and a path | likewise |
| `sig_net_serv_db.sml:27` | `Option.map port (getByName ("http", SOME "tcp"))`, `SOME 80`, `/etc/services` | a result in prose, and a path | likewise |
| `sig_real.sml:426` | `IEEEReal.toString (toDecimal 0.1)` | a side piece ("which is") | `fmt StringCvt.EXACT 0.1 = IEEEReal.toString (toDecimal 0.1)` |
| `sig_string.sml:294` | `\`, `n` | names two characters; not SML | prose |
| `word_sig.sml:60` | `LargeWord` | a structure's name, no expression | prose |
| `word_sig.sml:121` | `Word8.toInt 0wxFF` | a result written in prose | `Word8.toInt 0wxFF = 255` |

Twenty-one spans in twelve paragraphs:
- side pieces written after "where" or "which is";
- results written in prose, four depending on the machine, three of them naming an `/etc` file;
- one claim that is no equation;
- names in backquotes.

The examples run on Rune only, because they state what Rune's library
does: `Int.precision = SOME 64` is an example (`run-examples.sh`, lines
8-9).

### Laws

`Law:` paragraphs are only rendered (`src/doc/docpage.sml:128`).
- They are never parsed, elaborated or run.
- The only checks are that the body is not empty (`src/doc/doctext.sml:161-179`) and that a law belongs to a value (`src/doc/docextract.sml:29-37`).
- `docs/doc-comments.md` says it outright: "What holds for every argument is a `Law:`, which is not run; an example has no free variables."

The census, made for this roadmap, records syntax, types and the checks
written beside the laws (*Appendix: the census of laws*):

- **Size.** There are 286 `Law:` paragraphs with 387 code spans, in 45 files and 48 signatures, all of them signature files. 286 spans are the laws themselves, 4 are second laws, 41 are conditions written as code, 47 name variables or results in the prose, and 9 are asides.
- **Types.** Typed by SML/NJ with their free variables abstracted (*Appendix: the census of laws*), 72 laws are plain equations to which none of the categories below applies.
- **What gets in the way of the rest** (a law can have several of these):
  - 44 have code that is not Standard ML as written: in 16 the law itself, in 27 only a condition (25 of them chained comparisons such as `0 <= i < n`), and in 1 a second law. The causes include `==` used as infix, `^` as power on words, a result written in prose, operators rebound by `let open S`, and a precedence under which `=` binds tighter than the author meant;
  - 9 compare with `=` at a type without equality: `real`, a function type, `Date.date` in Rune, and `substring` in the specification (though not in Rune);
  - 82 have a free variable of function type;
  - 87 a polymorphic one;
  - 124 one of a type the Basis keeps abstract: arrays, slices, streams, sockets, OS and Posix handles, `Date.date`, `Time.time`;
  - 67 a condition in prose ("for `0 <= i < List.length l`", "for canonical absolute paths", "for a finite `x`").
- **Types to generate.** There are 113 distinct types of free variables:
  - the scalars and `IntInf`;
  - lists, options, refs and tuples;
  - arrays, vectors and slices of every element type;
  - the record of `Date.date`'s fields;
  - 31 function types, readers among them;
  - system values: `Date.date` and `Time.time`, binary streams and their writers, sockets and their addresses, host entries, address families and socket types, file ids, I/O descriptors, Posix file descriptors, pids, signals, user and group ids, and terminal settings.
- **Checks written by hand.** In the Basis suite, 100 laws have a random check that asserts the law in some restatement, and 118 one that checks the member against a model or another identity. 68 have none. A check restates its law, and the restatement can differ from the text (*The named law*).

The Basis suite's random checks use its own generator
(`tests/basis/harness.sml:137-167`):
- a Lehmer generator with a modulus of 2^30 − 35 and multiplier 16807, in 30 bits so that it runs on every host;
- `T.seed`, `T.rand`, `T.range`, `T.oneOf` and `T.repeat`, which 51 files call;
- no shrinking. A failure is a label and nothing more.

### Libraries

Rune has one library.
- **How the compiler finds it.** The compiler reads the Basis from `--lib DIR` plus `/basis` (`src/driver/main.sml:7-10`), through `lib/basis/MANIFEST`. Its 295 lines, after a header comment, are a table of `file | when | host | provides | requires`. `BasisManifest.namesOf` and `select` load a file when a program mentions a name it provides (`src/driver/basismanifest.sml:89-139`).
- **Other code.** A program can use anything else only by naming its source files on the command line, where they are "elaborated as one program in the order given" (`man/rune.1`). There is no `use`, `.mlb` or `.cm`, and `docs/plans/weak-points.md:166` lists "no libraries beyond the Basis Library".
- **runedoc is ahead.**
  - `runedoc --library NAME` documents any directory with a MANIFEST, elaborated on top of the Basis (`src/doc/docmain.sml:122-141`, `src/doc/docelab.sml:18-36`). `tests/doc/onbasis.lib` tests it.
  - But a NAME containing a `/` is taken as a path, so `test/property` would not be found under `--lib` (`docmain.sml:124-126`).
  - It sets `allowPrim` for every library, not only the Basis (`docelab.sml:29`).
- **Installing.** `scripts/install.sh` installs `lib/basis` alone.

### What the Basis offers the two libraries

- **Words and integers.**
  - `Word64` is `Word`, 64 bits.
  - `Int` is 64 bits and raises `Overflow`.
  - `Int8` to `Int32` and `Word8` to `Word32` are functor applications that keep a value in an `int` or `word` (`docs/language.md`, `basis.intn`).
  - `LargeInt` is `IntInf`, implemented in SML with 30-bit limbs.
- **Reals.** A real is IEEE binary64, and `PackReal64Little` turns bits into reals and back.
- **Time, environment and identity.** `Time.now`, `Timer`, `OS.Process.getEnv` and `Posix.ProcEnv.getpid` are there, and so are `exnName` and `exnMessage`.
- **Rune's own structure.** `Runtime.stats` gives the instruction count, and `Runtime.same` pointer identity.
- **What is missing.**
  - There is no primitive for entropy (`/dev/urandom` can be read with `BinIO`).
  - There is no timer interrupt: `Posix.Process.alarm` ends the process. So nothing can stop a case that does not end, from inside the process.

## What is different for SML

QuickCheck was designed for Haskell, and several of its conveniences are
Haskell's rather than testing's: type classes, laziness and purity.
Standard ML '97 has none of them, and it makes demands of its own.

**No type classes** (Wadler and Blott 1989). In Haskell, `quickCheck (\xs -> reverse (reverse
xs) == xs)` works because the type checker finds `Arbitrary [Int]`,
`Show [Int]` and `CoArbitrary Int` for the programmer. In SML, whoever
writes a property also passes the generator, the printer and the
observer, as values or as functor arguments. A library that is pleasant
without type classes is one where those values compose as easily as the
types do (`Arb.list Arb.int`), and where the common ones are named once
per signature family rather than once per structure (*The architecture*).
For the laws, runedoc has what Haskell's type checker has, since it
elaborates the law and knows each variable's type. It can therefore
resolve instances itself and write the generator expression into the
program it generates. That is instance resolution done by a tool, outside
the language, and it is how part 2 gets QuickCheck's convenience without
type classes (D4).

**No reflection.** A running SML program cannot ask what type a value
has, so printing a counterexample needs a printer passed with the
generator. The same holds for comparing two values of a type without
equality, and for hashing an argument of a generated function.

**Strict evaluation.** Hedgehog's and QuickCheck's shrink trees are lazy
rose trees. Built eagerly, they cost memory and time for every shrink
that is never tried. A strict language wants shrinking that re-runs the
generator under a changed source of randomness (Hypothesis, falsify),
not a tree of alternatives held in memory (D3).

**Effects and exceptions are outcomes.** Each side of an SML equation is
a computation. It returns a value or raises an exception, and on the way
it may call functions that have effects. The Definition fixes the order
of evaluation: left to right, arguments before the call. A law therefore
says something about effects and exceptions whether its author meant it
to or not, and a tester has to choose what it compares (D6) and what a
variable of function type may do (D5). The Basis documents the
exceptions of almost every function (`Raises:`); QuickCheck, where an
exception is a failure, would report each of them as a counterexample
to every law that reaches it.

**Equality is a property of types.** `=` exists only at equality types.
`real` is not one, and neither are the specification's abstract `substring`
(Rune's admits equality), `Date.date` or a reader's stream `'a`. Several documented laws compare such values
with `=` (*Where we are*), and they have to be written differently or
read with an equality the tester supplies (D6, D7).

**Polymorphism.** A law such as `rev (rev l) = l` quantifies over every
type of element. A test runs at one type, so the tester chooses it (D8).

**Arithmetic that raises.** `Int.int` has 64 bits and raises `Overflow`,
and `Int8`, `Int16` and `Int32` raise it at their own bounds. The
division law of `INTEGER` (*The named law*) holds over the integers and
not in the arithmetic of the structures that state it: its left side
raises `Overflow` at arguments where the mathematics is fine. Integer generators that stay near zero, as
QuickCheck's classic ones do, never see this (E3).

**One signature, many structures.** `INTEGER` is implemented by nine
names: `Int`, `Int8`, `Int16`, `Int32`, `Int64`, `FixedInt`, `IntInf`,
`LargeInt` and `Position`. They are five implementations: `Int64`,
`FixedInt` and `Position` are `Int`, and `LargeInt` is `IntInf`
(`docs/generated/basis/sig/INTEGER.md`). Likewise `WORD` has seven names
and four implementations (`Word`, `Word8`, `Word16`, `Word32`). A law in
the signature is a claim about each implementation, and the narrow ones
have domains small enough to test exhaustively (D8, D9).

**The testing rules of this repository.**
- Everything in `make check` is deterministic. Its budgets compare exact counts (`docs/runtime.md`, "The same run twice"), and `docs/testing.md` on branch `heap-layout` states the rule for harnesses. So seeds are fixed, and nothing there reads the clock or entropy.
- Every compile rebuilds the Basis subset from source: no separate compilation.
- Compiler and runedoc sources build byte-identically on six compilers (MLton, SML/NJ for 64 and 32 bits, Poly/ML, MLKit and Rune) (`docs/building.md`, "Portability rules for compiler sources"), so runedoc's part of this work (resolving types to instances) cannot depend on the width of `Int` or on hashing done at runedoc's side.

## What the literature says

A research pass for this roadmap read or checked 78 works. The DOIs were
verified against Crossref, and the ECOOP paper against DataCite, where
Dagstuhl registers. It marked which papers were read in full and which
from the abstract only. That report is under
`~/.cache/claude-rune-drafts/quickcheck/research/R1-literature.md`. What
follows is what bears on the decisions. Full citations are in
*References*.

### Laws as tests are older than QuickCheck

- **DAISTS** (Gannon, McMullin and Hamlet 1981) compiled algebraic axioms written beside an implementation into a test driver. The axioms were the oracle, and the user supplied only test points. Its authors observed that a test that is insignificant for the code is often a severe test of the axioms.
- **ASTOOT** (Doong and Frankl 1994) tested pairs of operation sequences that a specification says are equivalent.
- **In Haskell,** Jeuring, Jansson and Amaral (2012) start from the observation that type-class laws "are usually stated in comments", and test them. They found that the standard State monads violate them.
- **Haskell's doctest** checks `prop>` lines in Haddock comments with QuickCheck. Their free variables are quantified implicitly, and a polymorphic law has to be annotated with a type by hand (`(xs :: [Int])`).
- **In practice:** the developers Goldstein, Cutler et al. (2024) interviewed at Jane Street value properties "as a form of persistent documentation".

Part 2 of the brief is this idea, with a type checker to find the types
doctest asks for.

**What kind of claim a law is.** Hughes (2019) classifies properties as:
- validity;
- postcondition;
- metamorphic;
- inductive;
- model-based.

He compares them on eight bugs of a search tree. Validity properties
missed five of the eight. Model-based properties failed after a mean of
5.8 tests, metamorphic ones after 56, postconditions after 77. Most of
the Basis's laws are metamorphic: one function stated in terms of
another. They are individually weak and strong in combination, and the
Basis suite's model checks (the labels with `/model`, such as
`ListPair.zip/model`) complement them. Hughes (2016) reports the
industrial scale such testing reaches: 3,000 pages of AUTOSAR standards
formalised as 20,000 lines of QuickCheck code, which found over 200
problems, well over 100 of them ambiguities in the standards.

### QuickCheck, and what it assumed

Claessen and Hughes (2000) define the design every successor starts
from:
- a generator monad with an implicit size that grows over a run;
- functions generated by `coarbitrary`, which perturbs the random state by the argument, so a splittable generator is needed;
- conditions (`==>`) that discard, with a warning when too many are discarded;
- polymorphic laws tested at a type the programmer picks.

The paper's own example shows what conditions do to a distribution:
`ordered xs ==> ordered (insert x xs)` tested only 19 of 100 cases on
lists longer than one. That is why D7 counts discards and lets a law name
a generator. Claessen and Hughes (2002) extend the property language to
monadic code and relate testing to observational equivalence. That is
the ground for D6's equalities per type. Holdermans (2013) shows how
testing abstract types with structural equality gives false confidence.

### Generators without type classes

Type classes are how Haskell finds `Arbitrary [Int]`. ML has three other
routes:
- **Type-indexed values.** Yang (1998) programs values indexed by types in Hindley–Milner by interpreting a type as the value it indexes. Karvonen (2007) turns this into a generic-programming library for Standard ML, from which `arbitrary`, `shrink`, `show` and `eq` all derive. The abstract does not measure what it costs to use.
- **Combinator records.** Danvy's type-safe `printf` (1998) and Kennedy's pickler combinators (2004) show that combinators whose types mirror the data replace type-directed dispatch. A record of a generator, a printer and an equality, with `pair`, `list`, `alt`, `fix` and `wrap`, is the design of D4.
- **Types turned into generators by a tool.** PropEr (Papadakis and Sagonas 2011) does this for Erlang's type declarations, including recursive ones.

These are the closest precedents for runedoc's resolution of a law's
types. Modular type classes (Dreyer et al. 2007) and modular implicits
(White, Bour and Yallop 2015) would put instance resolution into the
language. Nothing in this roadmap needs that.

The ETNA evaluation (Shi et al. 2023) adds a point against type classes
themselves. Its authors endorse Hedgehog's choice to have no generator
class, because "treating inputs independently can lead to unintuitive
testing performance". Generators written for a property's precondition
beat generators derived from types by a wide margin (all tasks solved
against 43 failures in Haskell).

### Shrinking

**Internal shrinking, over a choice sequence.** MacIver and Donaldson
(2020) describe Hypothesis's reducer:
- A generator is a parser of a sequence of choices.
- The shrinker minimises that sequence in shortlex order and runs the generator again. So every shrunk value is one the generator could have produced, and a precondition built into a generator survives shrinking.
- No type needs a shrinker of its own.
- Generators are written to shrink well: a list is drawn as "continue? element" pairs, so that deleting a block deletes an element.
- It uses 15 passes, and on SmartCheck's benchmarks matches or beats QuickCheck at two to three times the number of runs.

Goldstein and Pierce (2022) make "a generator is a parser of randomness"
precise. Goldstein et al. (2023) run generators backwards, so that a
value the tool did not produce can be shrunk too.

**Internal shrinking, over a sample tree.** de Vries (2023) replaces the
sequence with a tree:
- Each sub-generator reads its own subtree. Shrinking one part never shifts the samples of another, and a shrink only lowers samples towards zero.
- Functions and infinite values work because "there is always more tree".
- The costs, which the author states:
  - A badly written generator shrinks badly, where Hypothesis's passes rescue it.
  - A sample sometimes cannot shrink, because a smaller value would be read in an unrelated context.

The prototype met both (E6).

**Rose trees and QuickCheck's shrinkers.** Integrated shrinking with rose
trees (Hedgehog, test.check) "produces poor reductions when bind is
used" (MacIver and Donaldson). Keles, Miao and Lampropoulos (2026)
measured QuickCheck, Hedgehog and falsify on four ETNA workloads against
exhaustively found minima. Their conclusion is that QuickCheck's
structural shrinking "is usually faster and remains competitive",
because integrated shrinking "does not by itself guarantee a performance
or effectiveness advantage". So D3 chooses internal shrinking for what
it saves the user and for the validity of what it produces, not for
speed.

**Reducers outside the generator.** Delta debugging (Zeller and
Hildebrandt 2002) and C-Reduce (Regehr et al. 2012) show that validity is
the hard part of reduction. A reducer that knows nothing of the
generator produces invalid cases.

### Functions

Claessen (2012) gives the representation QuickCheck uses: a generated
function is a trie over its argument type, built by a `Function`
instance per type, plus a default result.
- Shrinking prunes the trie to what the property touched.
- The result is shown as a table, such as `{"elephant"->1, "monkey"->1, _->0}`.
- Higher-order arguments are not handled.

In a strict language the trie must be suspended, or replaced by
recording the arguments the property asks for. The sample tree does the
latter: the observation `co` of D4 is what picks the subtree.

### Polymorphic laws

Bernardy, Jansson and Claessen (2010) prove when one monomorphic
instance tests a polymorphic property completely. For a type that can be
put in the form ∀a. (F a → a) × (G a → X) → H a, testing at the initial
F-algebra suffices. For `reverse (xs ++ ys)` it is enough to instantiate
at a type that tags where each element came from, and only the lengths
need to vary.
- **Mechanised:** Hou and Wang (2022) automate the choice of instance.
- **Finite domains:** Morihata (2026) gives conditions under which `bool` makes testing finite and complete. It applies to 57 of 79 polymorphic functions of the Haskell 98 Prelude.
- **The caveat:** the theorems rest on parametricity (Wadler 1989) and assume no effects, exceptions or divergence. In SML they apply to the laws' pure parts only. An equality type variable is an observation `a × a → bool`, which fits their form.

D8 instantiates at `int`, as doctest and QuickCheck practice do, and
leaves the tagged instances of Bernardy et al. to a later refinement.

### Conditions and sparse domains

When a condition is rarely true, rejection starves the test.
- **Deriving generators from the condition:** Luck (Lampropoulos et al. 2017), QuickChick's derivation from inductive relations (Lampropoulos, Paraskevopoulou and Pierce 2018), and uniform generation from a predicate (Claessen, Duregård and Pałka 2015).
- **Searching with feedback:** coverage (FuzzChick, Lampropoulos, Hicks and Pierce 2019) and a utility function (targeted PBT, Löscher and Sagonas 2017).
- **What wins:** ETNA's generators written for the precondition beat all of these on sparse invariants.

For a documentation tester the simplest answer is enough: count
discards, give up loudly, and let the law name a generator (D7).

### Enumeration and the small scope

- **SmallCheck** (Runciman, Naylor and Lindblad 2008) enumerates all values up to a depth.
- **Feat** (Duregård, Jansson and Wang 2012) makes enumeration random-access, so one library does both exhaustive and uniform random search.
- **ETNA's comparison.** LeanCheck solved 82% of the tasks and SmallCheck 35%. The order of enumeration mattered: reordering a property's arguments let SmallCheck solve 17 more.
- **The small scope hypothesis** (Jackson 2006), "most bugs have small counterexamples", was tested by Andoni et al. (2002). Exhaustive inputs within small scopes killed over 90% of mutants. One mutant survived every tree of up to four nodes, which already covered every branch: coverage is not adequacy.

For integers of fixed width, "small" means narrow as well as near zero.
`Int8` is a small scope in which every pair can be tried (P9), and the
named law's counterexamples are everywhere in it (E3). The research pass
found no paper on biasing integer generators towards boundaries. The
edges of P1 come from what the implementations do (*What the
implementations do*) and from the arithmetic of SML.

### Random numbers

**Where splittable generators come from.** A generator that can split is
what makes `coarbitrary` and sample trees work. Burton and Page (1992)
introduced splitting for functional programs. Claessen and Pałka (2013)
showed how badly an ad hoc split can fail: Haskell's `StdGen` made a
false QuickCheck property, which should fail about 1 in 14 tests, pass
10,000. Their fix hashes the split path with a block cipher (Threefish),
3–11% slower.

**SplitMix.** Steele, Lea and Flood (2014) define SplitMix:
- **The design.** A 64-bit seed and an odd gamma, `mix64 (seed += gamma)`, about nine operations per output.
- **Quality.** No clear failure in BigCrush, sequentially or split.
- **Adoption.** It became Java 8's `SplittableRandom`. QuickCheck moved to TFGen in 2.7 (2014) and to SplitMix in 2.13 (2019), according to its changelog.

Its known weaknesses:
- **Weak gammas.** Output quality fails when a gamma, or a small multiple of it, is weak (Steele and Vigna 2021).
- **A printed bug.** The paper's printed `mixGamma` has its test inverted, and the error was copied into ports (O'Neill 2017). The JDK's code is right.
- **Birthday spacings.** It fails a birthday-spacing test. Otherwise Schaathun's (2015) split sequences pass PractRand to 2 TiB (Markert et al. 2020).

For test generation none of this matters much. `lib/random` takes the
JDK's `mixGamma` (D2), and its tests include the split sequences.

**The alternatives.** LXM (Steele and Vigna 2021) is the more robust
successor, at up to twice the cost. Counter-based generators, Philox and
Threefry (Salmon et al. 2011), turn splitting into a pure function of a
key and a path, which is the shape of an implicit sample tree. JAX
adopted Threefry, with a split in Claessen and Pałka's style. Lemire
(2019) gives unbiased bounded draws that almost never divide.

### Coverage and adequacy

- **The "gulf of evaluation".** Developers cannot see whether their generators exercise a property (Goldstein, Cutler et al. 2024). Tyche (Goldstein, Tao et al. 2024) shows distributions and events, in a report format Hypothesis now writes. For a documentation tester, per-law statistics serve the same end: tests, discards and labels (D13).
- **Adequacy of a set of laws.** FitSpec (Braquehais and Runciman 2016) mutates the functions under test. A mutant that survives every property shows the set is incomplete. M9 applies that check to the Basis's laws, once the hunt is over.
- **Discovering laws.** QuickSpec (Claessen, Smallbone and Hughes 2010) and Speculate (Braquehais and Runciman 2017) find equational laws by testing. They could later propose laws for the documentation, which runedoc would then keep tested.

## What the implementations do

A second research pass read the sources of 32 property-testing systems.
The local sources under `/home/ruud/reference` and the web sources were
fetched on 2026-09-27, and surprising claims were checked against the
code. The report is `research/R2-implementations.md` in the drafts
directory. None of the systems under `/home/ruud/reference` has anything
QuickCheck-like: the hits for "shrink" there are optimiser passes.

### In Standard ML

- **QCheck/SML** (Christopher League, 2004–2016; now on sourcehut and Codeberg)
  - **Generators.** `'a gen = rand -> 'a * rand` over a Park–Miller generator with an ad hoc `split`, and no size.
  - **Properties** pair a generator with an optional printer, and `check` accepts any `StringCvt.reader`, so cases can come from a list or a file.
  - **Integers** are drawn as decimal strings and parsed, which gives a log-uniform magnitude, and are mixed with 0, `minInt` and `maxInt` at 1:49.
  - **Functions** come from cogenerators; they are neither shown nor shrunk.
  - **Shrinking.** Since 1.2 the user can pass a shrinker (`checkGenShrink`). The library has none of its own.
  - **Weaknesses.** Any exception, `Overflow` included, becomes `false` with its name lost (`handle _ => SOME false`), and the seed comes from the clock and is never printed.
  - **Descendants.** Isabelle's SpecCheck descends from it.
- **mltonlib's generics and unit tests** (Vesa Karvonen, 2007–08; the paper is Karvonen 2007)
  - **One type index for everything.** One value such as `list int` drives Arbitrary, Shrink, Pretty, Eq, Hash and Ord, each a layer made by a functor, and `testAll (list int) (fn xs => that (rev (rev xs) = xs))` needs nothing else.
  - **The cost.** Hand-written isomorphisms to nested sums for every datatype, `Tie.fix` for recursion, and an infrastructure (Extended Basis, `Fold`, `Tie`, `Univ`, `Prettier`, layered MLB files) larger than the testing library itself.
  - **Seeds** are accepted and never printed.
- **SpecCheck (Isabelle/ML)**
  - `check_dynamic ctxt "ALL xs. rev (rev xs) = xs"` runs the ML compiler to infer the property's type, then writes generator and printer code from a registry keyed by type constructor. That is runedoc's plan in D4 and M7, done at run time.
  - It memoises generated functions on an equality type (`function'`).
  - **Isabelle/HOL's Quickcheck** (Bulwahn 2012) prints a generated function as a chain of updates to a finite map.
- **The rest.** hedgehog-sml (rose trees over SplitMix) is unfinished: its `Property.run` is `fun run _ = ()`. sml-check has rose trees, 0 stars, and a seed printed on failure. HolBA's `qc_genLib` generates without shrinking.

No SML library has internal shrinking, printed replay tokens, or tests
of documentation.

### Without type classes, elsewhere

- **OCaml's QCheck**
  - **v1** has the record of D4: `{gen; print; small; shrink; collect; stats}`. `map` keeps the shrinker only if given the inverse, and there is no `bind`.
  - **Functions are its best part.** `fun1` takes an `Observable` (equality, hash, printer), fills a table lazily beside a default, prints `{k1 -> v1; _ -> d}`, and shrinks by dropping bindings.
  - **QCheck2** moved to lazy rose trees. It found that "integrated shrinking requires a splittable RNG" (its bug fixed in 0.24). `bind` still shrinks the first component before the second.
- **Jane Street's `base_quickcheck`**
  - **Instances** are first-class modules, which is the SML structure argument.
  - **A deterministic default seed,** so CI needs no flag.
  - **Strong edge bias without state:** 5% on each bound of a range, and log-uniform magnitudes, so that 0, −1, `max_int` and `min_int` each come up about 2.5% of the time.
  - **Functions** hash their argument into a copied generator: pure and total, but shown as `<fun>` and never shrunk.
- **Crowbar** interprets generator data over the bytes AFL mutates, and builds the printed trace of a case while generating it. It has no shrinking.
- **Monolith** prints a failing scenario as an OCaml program to paste. That format suits a compiler's own Basis tests.
- **Elm's test library** removed `andThen` in 1.0, because with rose trees "Int shrinking is driving the shrinking of a bool". In 2.0 (2022), Martin Janiczek replaced the trees with Hypothesis's internal shrinking over a sequence of `Int` choices:
  - Eight shrink commands: delete chunks, zero chunks, binary search, minimise a float, sort, redistribute, decrement together, swap.
  - Lists drawn with a continue flag per element.
  - Integers drawn as a size bucket and then a value.
  - `andThen` came back, and `map` shrinks for free. Elm has no function fuzzers.
- **Hypothesis** (MacIver, Hatfield-Dodds et al. 2019)
  - **Strategies** are explicit values that parse typed choices, shrunk by about 15 passes in shortlex order. A candidate must fail with the same "interesting origin".
  - **Replay:** a database of failing choice sequences is replayed first, and `@reproduce_failure` prints a blob.
  - **Constant pools** at p = 0.05: powers of 2 and 10, float extremes, and constants mined from the user's source.
  - **Functions** draw their results when called, memoised when declared `pure`, and each call is noted in the report.
- **rapid (Go)**
  - **The same design in about 400 lines of shrinker:** a stream of `uint64` with labelled groups, with draws made imperatively inside the property, so `bind` is sequential code.
  - **Replay:** it writes the *minimised* stream to a fail file that the next run replays first.
  - **The cautionary baseline** is Go's `testing/quick`, with reflection, uniform integers and no shrinking.

### With type classes, for comparison

- **QuickCheck** (2.19, 2026):
  - `Gen a = QCGen -> Int -> a` over SplitMix, with type-based shrinking.
  - Functions via `CoArbitrary` and the `Function` trie, shown once shrunk.
  - `cover` and `checkCoverage` test the coverage statistically, and `recheck` replays.
- **doctest's `prop>`** finds free variables by parsing GHCi's "Variable not in scope" errors, and monomorphises type variables to `Integer`. That is the analogue of D7 and D8, with runedoc's elaborator in place of the error messages.
- **Hedgehog** shows the limit of rose trees: any join either never returns to the left side or discards progress inside. **falsify** is the sample tree, lazy, with functions shown as tables once fully shrunk.
- **FsCheck, ScalaCheck, proptest, Rust's quickcheck, test.check, fast-check, jqwik, QuickChick and plausible** vary the theme. Two details are worth taking:
  - **jqwik** switches to exhaustive generation when the domain is no larger than the number of tries.
  - **fast-check** replays a `{seed, path}` straight to the shrunk case.

### What Rune takes

- **Explicit generator values, named after the Basis's type constructors** (`Arb.list`, `Arb.pair`), so that a type turns into an expression mechanically. SpecCheck and doctest show a tool doing that. Functors are for families of structures, not for composing instances (D4).
- **A printer with every generator.** Elm and Hypothesis manage without one only because their runtimes can print anything. A counterexample of a law is printed by variable, `i = 65, j = ~64`.
- **Internal shrinking.** Hypothesis, Elm and rapid prove it in languages without type classes, and falsify proves the tree.
  - The survey's own recommendation was the sequence of Elm and rapid, because a sample tree seemed to need laziness.
  - The prototype shows that it does not: a node is a hash of the seed and its address, and an override is an entry in a table, an association list in the prototype (E6). With the tree, a generated function reads its own subtree, and shrinking one part never shifts another.
  - D3 recommends the tree and keeps the sequence as its option C.
- **Exceptions as outcomes.** QCheck/SML's `handle _ => false` is the anti-pattern; OCaml QCheck's separate "errors" and Hypothesis's origins are the model (D6).
- **Stateless edge bias with full-range draws.** Uniform-only integers, and small-only integers, are both anti-patterns (E3; *Generator principles*).
- **Exhaustive search of small domains**, as jqwik does automatically (P9).
- **Functions** drawn at call time from the case's own source, logged, and shown as a table (D5).
- **Replay.** A deterministic default seed, and on failure the seed with the minimised overrides as a token, as rapid and Hypothesis print (D13).
- **A PRNG of its own.** SML/NJ's `Random` is an imperative Mersenne Twister with 2.5 KB of state and no split. MLton's is a global LCG with weak low bits. MLKit's is an imperative Park–Miller in `real` arithmetic. Hence `lib/random` (D2).

## The named law

`INTEGER` documents `mod` with this law (`lib/basis/int_sig.sml:143`):

```
Law: `(i div j) * j + (i mod j) = i`
```

Around it, the comment says two things:
- `div` raises `Div` when `j` is zero, and `Overflow` for `minInt div ~1`;
- `mod` never raises `Overflow`, "although `div` does at the same arguments".

The law holds over the integers. In the arithmetic of a structure with
bounds it does not: the product `(i div j) * j` can overflow where
neither `div` nor `mod` does.

At `Int`, take `i = maxInt` and `j = ~2`:
- `maxInt div ~2` is −2^62, exactly representable;
- times `~2` it is 2^63, one more than `maxInt`, so the left side raises `Overflow`.

At `Int8`, `(65, ~64)` fails the same way: `65 div ~64` is −2, and −2 × −64 = 128.

SML/NJ 110.79, whose `Int` has 31 bits, agrees: `(maxInt div ~2) * ~2`
raises `Overflow` there too (`logs/smlnj-divmod.log` in the drafts
directory).

**How often.** The exhaustive run of E3 over all 65,536 pairs of `Int8`
gives:

| Class | Pairs | First found |
|---|---:|---|
| holds | 59,454 | |
| `Div` (`j = 0`, documented) | 256 | `(~128, 0)` |
| `Overflow` from `div` (`(minInt, ~1)`, documented) | 1 | `(~128, ~1)` |
| `Overflow` from the product (undocumented) | 5,825 | e.g. `(65, ~64)`, `(127, ~2)` |

So about 9% of the pairs of `Int8` break the law outside the documented
cases. The product overflows whenever the quotient, rounded down, times
`j` passes a bound. That can happen even with `i` near 0: `1 div minInt`
is −1, and −1 × `minInt` overflows.

**Why it was not noticed.** The law has a random check,
`<I>.div/law-<k>` (`tests/basis/fn/integer_fn.sml:638-641`), run at every
integer structure. It draws its operands over the whole range. But it
computes the left side in `LargeInt`:

```sml
eqL (lab "div/law" ^ s, fn () => al,
     fn () => L.+ (L.* (I.toLarge (I.div (av, ev)), el), I.toLarge (I.mod (av, ev))));
```

So it tests the law as its author meant it, over the integers, and not
as the comment states it, in the structure's arithmetic, where the
product overflows. A check written by hand beside a law pins what its
writer believed. Only a law that is itself the test (M7, M8) pins what
the documentation says.

The failures are also common across the whole range, and rare among
small numbers. At `Int64`, which is `Int`, with the documented cases
excluded:

| Generator | Found by (seeds) | Median test |
|---|---:|---:|
| uniform over the range | 10 of 10 | 11 |
| the prototype's rule (1/2 small, 1/4 edges, 1/4 uniform) | 100 of 100 | 90 |
| QuickCheck's classic sized integers, \|v\| ≤ 100 | 0 of 10 | not in 100,000 |

A generator that stays near zero, as QuickCheck's default does, would
not have found it even had the check computed in the structure's
arithmetic. That is why P1 requires uniform draws over the whole range.

**What shrinking gives.** With the documented cases included, the first
failure is `Div` in most seeds (65 of 100 at `Int8`). That failure shrinks
to `(0, 0)`, and because a shrink must keep its class, it never turns
into the `Overflow`. With the documented cases excluded, every seed finds
the undocumented `Overflow`.

The shrinker then stops at one of many local minima. The most frequent
at `Int8` are `(65, ~64)` (23 seeds), `(87, ~43)`, `(~66, 65)` and
`(1, ~128)`. At `Int64` they include `(4611686018427387905,
~4611686018427387904)` and `(9223372036854775807, ~2)`. No single
counterexample is "the" smallest. The pass that redistributes between
two numbers (M5) is meant for cases like this.

**The fix** is M9's, with the owner, per D12. The law can be stated where
it holds, in `LargeInt`, with the documented cases as its condition, and
the counterexample becomes an example that runs, e.g.
`(((valOf maxInt) div ~2) * ~2; false) handle Overflow => true`.

## The experiments

A prototype was written for this roadmap to test the design before
recommending it. It is under `~/.cache/claude-rune-drafts/quickcheck/proto`
and is not part of the tree:
- `splitmix.sml` (24 lines): SplitMix64.
- `prop.sml` (268 lines): generators over an implicit sample tree, kinds of encoding, shrinking by overrides, a runner.

It ran on the named law, on planted bugs, on problems of the shrinking
challenge, and on properties of its own functions for timing. It ran on
nothing else in the Basis's documentation (*The blind test*). E5 is the census of the laws (*Appendix: the census of
laws*).
- **Where the numbers come from.** Every number below comes from the logs under `logs/` in the same directory. The Rune runs used the worktree's `bin/rune` and `bin/runevm` at `d278153`, and again at master (`7fff793`) where a table says so. MLton 20241230 used `-default-type int64 -default-type word64`.
- **The same answers on both.** The generated cases are the same on both, as a seed-determined generator must make them. The outputs of E3 and E6 on Rune, at both commits, are byte-identical to MLton's.
- **Conditions.** E1, E3 and E6 ran at both commits, and E4's answers at `d278153`, all while the machine was loaded: load 17.8 to 22.3 at `d278153` (another session's Basis matrix) and 18.0 to 18.5 at master (`logs/conditions.txt`). Their times are user CPU time, or CPU time measured inside the process. E2 was run again on the idle machine at `d278153`; its rerun at master was loaded and is not used.

### E1. What a law program costs to compile

Each compile was run three times with `bin/rune` (the compiler on
`runevm`). This was done at `d278153`, and again after the rebase on
master at `7fff793`. The machine was loaded both times, so the table
gives user CPU time.

| Program | Lines | At `d278153` | At `7fff793` |
|---|---:|---:|---:|
| prototype + E3 (the law at four structures) | 292 + 138 | 0.55–0.69 s | 0.53–0.70 s |
| prototype + E2 | 292 + 49 | 0.71–0.85 s | 0.93–1.11 s |
| prototype + E6 | 292 + 71 | 0.53–0.57 s | 0.44–0.62 s |
| the largest example program of `runedoc --examples`, by bytes | 59 (`REAL`); 57 (`MONO_ARRAY_SLICE`) | 0.69–0.90 s | 0.69–0.71 s |
| all example programs, one after another | (programs) 41; 65 | 31.5 s | 62.2 s |

**What it predicts.**
- **Compiling.** A law program with a library of the prototype's size, compiled from source, costs about what an example program costs today, just under a second. `make test-laws` has one program per signature with laws, 48 of them, so it would add about 45 s of compiling to `make check`, beside the 62 s the examples take on master.
- **Running.** The cost of running is E2's. 100 cases per law and implementation is a few thousand cases for most programs, and tens of thousands for `MONO_*`, `INTEGER` and `WORD` (19 implementations of `MONO_VECTOR`, for one): about a second on `runevm`. The exception is the programs of `INTEGER` and `WORD`, where each law over a pair searched exhaustively at `Int8` or `Word8` (P9) adds about 0.2 s (0.06 s with the JIT).
- **The real library.** It will be about ten times the prototype, so E1 is measured again at M8 (the flag in *Prerequisites and flags*). Demand loading by MANIFEST (D1) keeps what a program does not use out of its compile.

### E2. How fast properties run

`exp_speed.sml` runs four properties of its own, sizes 1 to 100. E2 was
run again once the machine was idle (load 0.2 to 0.5,
`logs/e2-idle-conditions.txt`), best of three, CPU time measured inside
the process.
- **Rune.** 20,000 cases per property on each of Rune's VMs, the same cases on each. The program is compiled once for the stack bytecode (`bin/rune`) and once for the register bytecode (`bin/rune --target=registers`).
- **`vm/new`** is run without the JIT (`--jit=off`) and in its default mode, `--jit=opt`: tier 1 and tier 2 by counters, as on master since the JIT roadmap's merge (`d278153`). The JIT's compile time is inside the 20,000 cases.
- **MLton** runs 1,000,000 cases, so that its times are well above the timer's resolution.

| Property | `runevm` | `vm/new`, no JIT | `vm/new`, JIT | MLton | JIT / `runevm` | MLton / JIT |
|---|---:|---:|---:|---:|---:|---:|
| commutativity of `+` on a pair of `Int8` | 363,600 | 459,500 | 1,186,000 | 10,866,000 | 3.3 | 9.2 |
| commutativity of `+` on a pair of `Int` | 389,100 | 528,400 | 1,619,000 | 12,983,000 | 4.2 | 8.0 |
| the prototype's own reversal (a `List.foldl`) applied twice, `int list` up to 100 | 21,540 | 24,360 | 95,560 | 636,700 | 4.4 | 6.7 |
| the size of a string after reversing its characters, up to 100 | 23,910 | 25,700 | 95,470 | 607,300 | 4.0 | 6.4 |
| SplitMix64 draws alone | 8.79 M | 11.24 M | 66.2 M | 654 M | 7.5 | 9.9 |

The rates are cases per second (draws per second in the last row). The
logs are `logs/e2-idle-*.log`.
- **The JIT.** It makes the properties 3.3 to 4.4 times faster than `runevm`, and bare draws 7.5 times. `vm/new`'s interpreter alone gains 1.1 to 1.4. MLton's native code is still 6 to 10 times ahead of the JIT.
- **`runevm` against MLton.** The stack VM is 25 to 33 times slower on the properties, and 74 times on bare draws. `docs/performance.md` reports 10 to 25 times for plain code, and its table gives `word_bits` 4.61 ms against MLton's 0.10. That page predates the JIT roadmap's M2 and still says `vm/new` is slower than `runevm`, where E2 finds its interpreter 1.1 to 1.4 times faster. `Word64` arithmetic, which the generator is made of, is the VM's slow case, not something the library adds.
- **The load earlier.** The first run of E2, on the loaded machine, gave `runevm` a third to a half of these rates (`logs/rune.log`). Only the idle numbers are used below.
- **The cost of a node** (an estimate, not measured). A case of `int list` touches about 50 nodes on average: a length, and a mark and an element for each of about 25 elements. With the property itself, that is about 0.9 µs per node on `runevm` and 0.2 µs with the JIT.
- **What it means for a law.**
  - 100 cases of a list law take about 5 ms on `runevm` and 1 ms with the JIT.
  - Exhaustive search of `Int8` × `Int8` (65,536 cases) takes about 0.2 s on `runevm` and 0.06 s with the JIT.
  - The deep mode's 10,000 cases per seed for 1,000 seeds takes about 8 minutes per list law and implementation on `runevm`, and under 2 on the JIT. The laws have up to about 1,670 pairs of a law and a structure claiming its signature (fewer distinct implementations), so the deep mode is several days of CPU on `runevm` and about two on the JIT. It therefore runs in parallel, a signature to a core, on `vm/new` with its JIT and as `xc1:mlton` builds (Rune's Basis compiled by MLton).

### E3. The named law

The program `exp_divmod.sml` states the law as a functor over the
integer structures and runs it at `Int8`, `Int16`, `Int32` and `Int64`.
There are three parts:
1. `Int8` exhaustively;
2. 100 seeds per width with the prototype's rule, once as written and once with the documented cases excluded (`j = 0` and `(minInt, ~1)`);
3. at `Int64`, uniform draws and QuickCheck's sized draws, over 10 seeds with a budget of 100,000 tests.

The results are in *The named law*. The runs as written:

| Width | Found by | Median test | First class: `Div` / `Overflow` |
|---|---:|---:|---:|
| `Int8` | 100 of 100 | 9 | 65 / 35 |
| `Int16` | 100 of 100 | 11 | 76 / 24 |
| `Int32` | 100 of 100 | 10 | 78 / 22 |
| `Int64` | 100 of 100 | 11 | 75 / 25 |

With the documented cases excluded, every seed finds the product's
`Overflow`. The median number of tests grows with the width: 36, 54, 87
and 90. That is the price of the half of the draws that are small, which
is why P1 gives uniform draws a third. That rule is untried here: M6
calibrates it. The whole program took 13.3 s of CPU on `runevm` at `d278153` (17.0 s at master, under load): the
exhaustive part, 100 seeds at four widths twice, and the two contrasts.

### E4. SplitMix64 everywhere

`kat.sml` prints the first ten outputs of `splitmix64.c` for seeds 0 and
`0x0123456789ABCDEF`, and so does `kat.c`, compiled with gcc. Seed 0
begins `E220A8397B1DCDAF`, as published. These compilers print C's
outputs exactly:
- Rune;
- MLton 20241230;
- SML/NJ 110.79 (31-bit `Int`, where `Word64` is boxed) and SML/NJ 110.99.9 for 64 bits;
- Poly/ML 5.7.1 and 5.9.2;
- MLKit 4.7.23.

**One does not: SML/NJ 110.99.9's 32-bit build.** It miscompiles
`Word64` literals. Bits 30 and 31 of the literal's low 32 bits are lost,
so `0wxFFFFFFFFFFFFFFFF : Word64.word` is `FFFFFFFF3FFFFFFF` and
`0wx40000000 : Word64.word` is 0 (`proto/smlnj32-word64-literal.sml`,
`logs/smlnj32-word64-literal.log`).
- **Only the literals are wrong,** as far as the reproduction goes: `Word64.fromLargeInt` of the same number is right.
- **Why it went unnoticed.** The Basis suite has not seen it: its `Word64` file does not load on that host for another bug (`tests/basis/deviations.txt:775`), and no bug report in `docs/bugreport/smlnj` describes it.
- **What it means for `lib/random`.** Nothing. SplitMix64's constants stay literals. On that one host, `lib/random`'s known answers become a `HOST-BUG` deviation, beside the `Word64` ones already recorded for it, and the bug is worth a report in `docs/bugreport/smlnj`.

Throughput (E2, idle machine): 8.8 million draws per second on `runevm`, 66 million on `vm/new` with its JIT, and 654 million on MLton.

### E6. The shrinking challenge and planted bugs

`exp_challenge.sml` runs five problems of the shrinking challenge
(github.com/jlink/shrinking-challenge) and two planted bugs, five seeds
each. Version 1 of the prototype shrank by lowering each node's word in
turn. Version 2 added three rules:
- an offset encoding for ranges on one side of 0, where v1 used zigzag everywhere;
- candidates that keep the parity of a node's word, so that under zigzag a number keeps its sign while its magnitude shrinks;
- a pass that lowers nodes with equal words together.

The known minima are the challenge's, up to sign: under zigzag, ~1 comes
before 1, so `[0, ~1]` is the prototype's minimum where the challenge
writes `[0, 1]`.

| Problem | Known minimum | v1 (5 seeds) | v2 (5 seeds) |
|---|---|---|---|
| reverse | `[0, 1]` | `[0, ~1]` in 5 | same |
| distinct | `[0, 1, ~1]` | `[0, ~1, 1]` in 5 | same |
| large union list | `[[0, 1, ~1, 2, ~2]]` | 1 of 5; the rest spread the five over 2–3 lists | same |
| nested lists | `[[0, ..., 0]]` (11) | 11 zeros over 2–4 lists | same |
| length list | `[900]` | zeros and one of 901–904 | zeros and exactly 900 |
| planted `all` (skips the last element) | `p` false, `[0]` | one element, `p` false, element 0 in 1 of 5 | same |
| planted sort (drops equal elements) | `[0, 0]` | `[0, 0]` in 1; `[x, x]` in 4 | `[0, 0]` in 3, `[~1, ~1]` in 2 |

Each remaining gap has one cause, and M5 builds the fix for each:
- **large union list and nested lists:** moving elements between sibling lists. This is Hypothesis's hardest case too, and no pass of the prototype does it.
- **length list:** a length the caller draws, followed by elements with no marks. Only the tail can go, so a delete-and-shift pass is needed.
- **planted sort's `[~1, ~1]`:** the equal-words pass grouped the elements with the marks, which also hold the word 1. The log has to carry each node's kind.
- **planted `all`:** the function's result at `x` is read from the subtree at `x`'s observation. Changing `x` changes the result, so `x` cannot shrink without losing the failure. The pass that fixes this copies a function's results to the new argument.

Every shrink took between 3 and 930 runs of the property.

## Constraints

- **The libraries are Standard ML '97, as Rune accepts it** (`docs/language.md`), with no `_prim` and no `_overload`.
  - They assume no width of `Int` or `Word`. They compute in `Word64` and read bounds from the structure at hand, so that MLton, SML/NJ, Poly/ML and MLKit compile them to the same answers, all but SML/NJ's 32-bit build (E4).
  - **The owner's rule (2026-09-27):** a library outside the Basis never works around a bug of a compiler other than Rune. It is written plainly, constants as `Word64` literals. Where the test suite runs it on a host that gets it wrong, the failure is marked `HOST-BUG`, as `tests/basis/deviations.txt` does for SML/NJ's 32-bit `Word64` today (E4).
  - D10 and the Basis suite's matrix need that.
- **runedoc's part obeys the portability rules** of compiler sources (`docs/building.md`, "Portability rules for compiler sources"). runedoc and the compiler build on six compilers (MLton, SML/NJ for 64 and 32 bits, Poly/ML, MLKit and Rune) with byte-identical output.
  - So runedoc resolves instances and writes programs, but does no hashing or arithmetic of its own that could depend on a width.
  - Seeds are computed inside the generated program, by `Random.hashString`.
- **Every commit passes `make check`** (`AGENTS.md`), and library changes also pass `make matrix-quick`. The generated documentation (`make docs`) is committed and never edited by hand.
- **Documentation.** The two new libraries are documented in full in the comment language (`docs/doc-comments.md`), with their own `DOCUMENTED` ratchet, and runedoc's `--lint` covers them.
- **Determinism.** Nothing in `make check` reads the clock or entropy. Seeds are fixed, and the deep mode and `fromEntropy` stay outside it.
- **Tests.** The libraries' suites live under `tests/lib` with their own runner, so `scripts/check-docs.sh`'s rules for `tests/lang` and `tests/basis` do not apply to them.
- **The VM is not touched.** Everything here is SML, scripts and runedoc. Watchdogs replace a VM budget (D9).
- **One heavy run at a time on the machine.** The hunt's deep mode and the differential runs of D10 are long, and they run alone.

## The architecture

This is the design the decisions add up to, all of them taken as
recommended (2026-09-28).

```
lib/basis                    (unchanged; the library under test)
lib/random                   RANDOM: SplitMix64, split, bounded draws, a hash    (D2)
lib/test/property            GEN, CO, SHOW, ARB, PROP, CHECK, and the law runner (D3-D6, D9, D13)
src/driver                   rune --library NAME                                  (D1)
src/doc                      Example rule; laws parsed, elaborated, resolved;     (D7, D8, D11)
                             runedoc --laws DIR writes one program per signature
tests/lib/{random,property}  the libraries' own suites: known answers, planted
                             bugs, the shrinking challenge, mutants               (M3-M6)
tests/basis/run-laws.sh      compiles and runs the law programs: make test-laws   (M8)
```

### `lib/random`

`lib/random` is a small, general library. The property library is its
first user, not its only one.

```sml
signature RANDOM =
sig
  type gen                                  (* a seed and a gamma; immutable *)
  val fromSeed : Word64.word -> gen
  val fromEntropy : unit -> gen             (* never in make check *)
  val split : gen -> gen * gen
  val word64 : gen -> Word64.word * gen
  val below : Word64.word -> gen -> Word64.word * gen   (* uniform in [0, n): Lemire *)
  val int : int * int -> gen -> int * gen               (* uniform in [lo, hi] *)
  val real : gen -> real * gen                          (* [0, 1) from 53 bits *)
  val bool : gen -> bool * gen
  val hash : Word64.word -> Word64.word     (* the finaliser: counter-based use *)
  val hashString : string -> Word64.word    (* for the seeds of named laws *)
  val toString : gen -> string              (* a replay token *)
  val fromString : string -> gen option
end
```

- **The algorithm.** SplitMix64 is used in the form of Vigna's `splitmix64.c`, and its `split` follows Steele, Lea and Flood (D2).
- **Portability.** All arithmetic is `Word64`, and the known answers match C on Rune, MLton, SML/NJ, Poly/ML and MLKit. SML/NJ's 32-bit build is the exception, through a bug of its `Word64` literals (E4). `Int` appears only at the interface.
- **Entropy.** `fromEntropy` reads `/dev/urandom` where there is one, and otherwise falls back to the clock and the process id.

### `lib/test/property`

**The sample tree.** A test is a function of a *source*: a seed, the
overrides the shrinker has made, and a log of the nodes read.

- Every generator is given an *address* and reads its own subtree. A pair gives children 1 and 2 to its parts. A list gives child 0 to its length, and children *i* of subtrees 1 and 2 to its marks and elements. A function gives the result for `x` the subtree at the observation of `x`.
- A node's stored word is its override, if it has one. Otherwise it is what the node's *sampler* makes of `hash (seed xor address)`.
- The sampler carries the bias (*Generator principles*). The word stores the value in a canonical encoding in which 0 is simplest. That encoding is an offset for a range on one side of 0 and zigzag for a range that spans both, as E6 showed was needed.
- Each node is logged with its *kind* (integer range, word, real, bool, char, mark, length, choice). The shrinker's candidates depend on the kind, and so does which nodes it may change together (E6).

This is falsify's design (de Vries 2023) made implicit by hashing,
which a strict language allows and needs (D3).

```sml
signature GEN =
sig
  type 'a gen
  val return : 'a -> 'a gen
  val map : ('a -> 'b) -> 'a gen -> 'b gen
  val map2 : ('a * 'b -> 'c) -> 'a gen * 'b gen -> 'c gen
  val bind : 'a gen -> ('a -> 'b gen) -> 'b gen
  val pair : 'a gen * 'b gen -> ('a * 'b) gen
  val sized : (int -> 'a gen) -> 'a gen
  val resize : int -> 'a gen -> 'a gen
  val oneOf : 'a gen list -> 'a gen
  val frequency : (int * 'a gen) list -> 'a gen
  val elements : 'a vector -> 'a gen
  val intRange : int * int -> int gen
  val list : 'a gen -> 'a list gen                     (* a length, and a mark per element *)
  val listOf : int gen -> 'a gen -> 'a list gen        (* a length drawn by the caller *)
  val vector : 'a gen -> 'a vector gen
  val array : 'a gen -> 'a array gen                   (* fresh at every run and every side *)
  val option : 'a gen -> 'a option gen
  val function : 'a Co.co * 'b gen -> ('a -> 'b) gen
  val filter : ('a -> bool) -> 'a gen -> 'a gen        (* retries, then discards *)
  val fix : ('a gen -> 'a gen) -> 'a gen               (* recursive types, bounded by size *)
end
```

**Observers.** `'a Co.co` (`'a -> Word64.word`) observes an argument of a
generated function. It is QuickCheck's `CoArbitrary` reduced to a hash,
and it has an instance per type as generators do. Two arguments with the
same observation get the same result. For a type with equality and no
better observer, a memo table by first occurrence is the fallback,
documented as order-dependent (D5).

**Instances.** An *arbitrary* is the record QuickCheck's type classes
stand for:

```sml
type 'a arb = {gen : 'a Gen.gen, show : 'a -> string, co : 'a Co.co,
               eq : ('a * 'a -> bool) option}   (* NONE: the type's own = *)
```

- **Named instances.** `Arb` has an instance for every type of the Basis a law or a user needs, the census's 113 among them (M6): `int`, `word`, `char`, `string`, `real`, `bool`, `unit`, `order`, `exn`, `IntInf.int`, `Word8.word`, `substring`, `'a list`, `'a option`, `'a vector`, `'a array`, slices, tuples, and functions.
- **Functors for signature families.** `IntegerArb (I : INTEGER)`, `WordArb (W : WORD)` and `RealArb (R : REAL)` read the bounds from `precision`, `wordSize` and `R.precision`, so one definition serves every structure of a family without assuming a width (D4).
- **Printing.** `show` prints SML that reads back, e.g. `[~1, 2]`, `#"a"`, `0wxFF`, and functions as a table of the calls made: `fn 3 => true | _ => false`.

**Properties and outcomes.**

```sml
signature PROP =
sig
  type prop
  datatype 'a outcome = Value of 'a | Raised of string   (* exnName *)
  val forAll : 'a Arb.arb -> ('a -> prop) -> prop
  val holds : bool -> prop
  val equal : 'a Arb.arb -> (unit -> 'a) * (unit -> 'a) -> prop  (* outcome equality, D6 *)
  val ==> : bool * (unit -> prop) -> prop                         (* a condition: discards *)
  val label : string -> prop -> prop
  val classify : bool -> string -> prop -> prop
  val cover : real -> bool -> string -> prop -> prop               (* a required percentage *)
end
```

- **Evaluating a side.** `equal` evaluates each side in its own run of the generators, so a stateful argument (an array, a generated function with a log) starts fresh for each side.
- **Comparing sides.** It compares the outcomes and, for the effect-observing functions of D5, their call logs.
- **The library's own exceptions.** The exceptions the library raises for itself (a discard, a filter that gives up) are never visible to the code under test. A law that says `handle _ => ...` cannot swallow them.

**Running.**

```sml
signature CHECK =
sig
  type config = {seed : Word64.word, tests : int, maxSize : int, maxDiscards : int,
                 maxShrinks : int, exhaustiveBelow : int}
  val default : config
  datatype result = Passed of {tests : int, discarded : int, labels : (string * int) list}
                  | Failed of {test : int, class : string, counterexample : string,
                               shrinks : int, replay : string}
                  | GaveUp of {tests : int, discarded : int}
  val check : config -> string -> Prop.prop -> result
  val main : (string * Prop.prop) list -> OS.Process.status   (* PASS/FAIL lines, exit status *)
end
```

- **Shrinking.** On a failure, `check` shrinks the counterexample.
  - The passes run in rounds until none applies:
    - per node, in the order visited, lower the node's word toward 0 by its kind's candidates;
    - lower nodes of the same kind and word together;
    - drop a mark;
    - delete an element of a drawn-length list and shift its siblings;
    - redistribute between two numbers.
  - A candidate is kept only if it fails with the same failure class: `false`, or a named exception (D6). So a Div never slides into an Overflow, and each class found is reported.
  - M5 added three passes and a rule (*M5*, Done): join two lists that are elements of one list, swap neighbouring elements, and make a generated function a constant. A change is kept only if the case also gets simpler.
- **Replay.** The replay token encodes the seed, the size and the overrides, and `RUNE_PROPERTY_REPLAY` runs that one case again.
- **Exhaustive mode.** When an arbitrary is finite and the product of the domains is below `exhaustiveBelow`, `check` enumerates instead of sampling. At Int8 × Int8 that is 65,536 cases (E3).

### runedoc

**The Example rule (M1).** Every code span in an `Example:` paragraph is
elaborated as `val it : bool = ...` under the example's scope. That is
the `checkExample` of today (`src/doc/docelab.sml:464`), no longer only
for equations. Every span is also written to the program, so the check
is that it is `true` (D11).

**Laws (M7, M8).** A law is a code span, optionally followed by
conditions: *for* or *when* followed by a span, or *for `x` from `G`*
(D7). runedoc then does the following:
1. It parses the law and finds its free variables. These are the names bound neither by the scope of `open S` nor by the top level.
2. It elaborates `fn (x1, ..., xn) => (condition, lhs, rhs)` in the library's environment. That gives each variable a type, and an error at the comment for a law that is no Standard ML.
3. It instantiates type variables at `int` (D8). It resolves each type to an instance expression through a table keyed by type constructor, not by printed name: `Int8.int` becomes `Int8Arb.arb`, `'a list` becomes `Arb.list (...)`, `char -> bool` becomes `Arb.function (Co.char, Arb.bool)`. A type with no instance is an error at the comment, naming the variable and the type.
4. It prints the quantifiers on the page ("for all `i`, `j` : `int`") and in `--dump-ir`, so a misspelt member that became a variable is visible.
5. With `--laws DIR`, it writes one program per signature, holding every law at every implementation (D8), in the form of `--examples` (`src/doc/docexamples.sml:81-91`):

```sml
val () = Check.main [
  ("INTEGER.div/law-1@Int8",
   Prop.forAll (Arb.pair (Int8Arb.arb, Int8Arb.arb)) (fn (i, j) =>
     Prop.equal Int8Arb.arb (fn () => let open Int8 in (i div j) * j + (i mod j) end,
                             fn () => let open Int8 in i end))),
  ...]
```

**Running the laws.** `tests/basis/run-laws.sh` compiles each program with
`rune --library random --library test/property`. It runs the programs
with fixed seeds, `hashString` of the label, and counts the `PASS` and
`FAIL` lines as `run-examples.sh` does. `make test-laws` runs it, and it
joins `make check` when every law holds (D12).

## Generator principles

The generators decide what a law is tested on, and so what the hunt of M9
can find. They are therefore written down here, before any law is run,
from what the literature and the implementations do (*What the
literature says*, *What the implementations do*). They are frozen at the
end of M6.

**Calibration.** The weights follow the rules below, never a law. After
M6 a rule changes only with a reason recorded in the commit, drawn from:
- a principle;
- the named law (*The named law*);
- the planted bugs;
- the planted bugs and mutants of the library's own tests (M5, M6).

The prototype's integer rule (E3) was stated before it ran, and the
numbers it gave are reported as they came out.

**The principles:**

- **P1. Integers of a structure with bounds** are drawn from three families of equal weight, 1/3 each: small, edges and uniform.
  - *Small:* uniform in `[-size, size]`, clipped to the bounds.
  - *Edges:* 0, 1, ~1, the bounds and their neighbours, and ±2^k and ±2^k ± 1 for every k below the precision.
  - *Uniform:* uniform over the whole range.

  The prototype used 1/2, 1/4, 1/4 (E3). There, half the draws were small, and it found the named law's overflow in a median of 90 tests at `Int64`, where uniform draws alone needed a median of 11. QuickCheck's size-bounded integers never found it. No family may be dropped: small values give readable counterexamples, the edges find boundaries, and uniform draws cover the whole range.
- **P2. `IntInf`** has no bounds. Its three families are small, the edges of every fixed width (±2^k and ±2^k ± 1 for k up to 130), and uniform magnitudes of 1 to `size` limbs.
- **P3. Words**, by P1 without a sign: 0, 1, the maximum and its neighbour, 2^k and 2^k ± 1, and the top bit.
- **P4. Reals** also come in three families.
  - *Specials:* ±0, ±∞, a NaN, the least subnormal, the largest subnormal, the least normal, the largest finite, ±1, 0.5, 2^53 and 2^53 + 1.
  - *Small decimals:* integers and halves in `[-size, size]`.
  - *Bit patterns:* uniform, which covers every exponent.
  
  Reals are made from their bits with `Real`'s own exact operations (M5), so the rounding mode a law may set does not change them.
- **P5. Characters** are uniform over all 256 codes half the time. The other half is split evenly between letters and digits, the space and controls (`\n`, `\t`, `\000`), and the characters Standard ML's own syntax for numbers, characters and strings gives a meaning to (`#"~"`, `#"-"`, `#"+"`, `#"\\"`, `#"\""`, `#"."`, `#"e"`, `#"E"`, `#"0"`, `#"x"`, `#"w"`).
- **P6. Strings, lists, vectors and arrays** have a length uniform in `[0, size]`, and 0 and 1 with weight 1/8 each. Their elements follow their own rules, so a string has the characters of P5.
- **P7. Functions** are drawn from the three classes of D5 with equal weight: pure, raising and effect-observing. Their results come from subtrees keyed by the observation of the argument. A raising function raises an exception of the library's own for some arguments (a quarter of them) and returns otherwise. Effect-observing functions log their calls.
- **P8. Size** grows from 0 to 100 over a run, as in QuickCheck.
- **P9. Exhaustive search.** It is used when every variable has a finite domain and the product is at most 2^16 cases in `make check`, or 2^20 in the deep mode. `bool`, `order`, `char`, `Int8`, `Word8` and their pairs qualify.
- **P10. Instances.** A law is tested at every implementation of its signature, and a type variable at `int` (D8).
- **P11. Counts.** In `make check`: 100 cases per law per implementation, or exhaustively, with a fixed seed. In the deep mode: 10,000 cases per seed for seeds 1 to 1,000, fixed in advance.
- **P12. Values built from parts** (added at M6, before any law ran).
  - *An abstract value* (`Date.date`, `Time.time`, terminal settings) is made by its structure's own constructor from parts within the range the Basis documents. So a draw never raises: a `Date.date` has a year from 1900 to 2200, which the specification asks for, and fields in range.
  - *A range the specification leaves to the implementation* is read from the structure, as P1 reads `maxInt`. `Time.time`'s range is found by doubling a time until `Time` is raised.
  - *A record of parts* (`Date.date`'s fields, a `decimal_approx`) draws each part around its documented range, widened on each side by the range's own width. Parts out of range and on its edges are then drawn as often as parts in it. A part with no documented range (a year, an exponent) is drawn by P1 over its whole type.
  - *A wide character* follows P5, and a sixth of its draws are any character of the whole set.
- **P13. The small scope** (added at M6, from the mutant calibration). Before its random cases, a run tries the cases in which every word read is 0, 1 or 2, simplest first, up to as many cases as the run has random ones.
  - Integers are then 0, ~1 and 1, lengths up to 2, and characters the first three codes.
  - This is the small scope hypothesis of Jackson's Alloy and of SmallCheck (Runciman, Naylor and Lindblad 2008): most bugs show on some small input.
  - It reaches the relations between independent values, such as an index one past the end of a string drawn beside it, which three independent random draws rarely meet.
  - A property whose cases are all few enough runs exhaustively instead (P9).

**Frozen** on 2026-09-28, at the end of M6. `tests/lib/property/instances.sml` draws from the instance of every type of the census and hashes what the draws observe. `frozen.expected` holds that hash, so any change to what the generators draw fails `make test-lib` until the hash is renewed. A renewal needs a reason from the list above, recorded in its commit.

## The blind test

The owner believes that one law in the documentation does not hold under
SML '97, that it is hard to test, and that finding the exception is
harder still. The owner knows which law it is; this roadmap does not.
The law is not the one found while writing it (*The named law*). The
hunt of M9 is the test of whether property testing finds it. To keep the
test fair:

- **No suspects.** Nothing written for this roadmap names a suspect. That covers this file, the census and the commit messages. The census records syntax, types and the checks written beside the laws, never whether a law holds (*Where we are*).
- **Generators set in advance.** The generators are fixed by the principles above, before any law is run, and frozen at M6.
- **Nothing dropped.** No law is dropped, weakened or declared untestable without the owner's sign-off. Notation-only rewrites (M7) go into a before/after table that the owner reviews, and the owner can veto a change of meaning without saying why.
- **A pre-registered protocol for M9:**
  1. Run every law at every implementation with the settings of `make check`, then in the deep mode (P11). The seeds are 1 to 1,000, so there is no seed hunting.
  2. Record every failure: its class, its shrunk counterexample and its replay token.
  3. Classify each failure: the law is wrong, the implementation is wrong, or both (D10's differential runs decide which).
  4. Restate, or fix, and run again. Classes hide one another: in E3 a `Div` found first masked the `Overflow`. So the hunt is repeated until a full run reports nothing new.
  5. The owner then says which law was meant. It counts as found if it was reported with a shrunk counterexample in steps 1-4. If it was not, the gap is analysed and written up: which principle would have found it, and whether that principle is general.

## Decisions

Each decision gives the options, what favours each, and the
recommendation it was written with. The owner decided all of them on
2026-09-28, each as recommended:

| Decision | Decided |
|---|---|
| D1. How a program uses a library | A: `rune --library NAME` over a MANIFEST, as runedoc already does |
| D2. The random number generator | A: SplitMix64, splittable and used counter-style |
| D3. Generators and shrinking | D: internal shrinking over an implicit sample tree |
| D4. Instances without type classes | A: explicit records and functors for families; for laws, runedoc resolves them |
| D5. What a variable ranges over | C: every value of its type, raising and effect-observing functions included |
| D6. What a law's `=` compares | C: outcomes, with an equality per type where the type has none |
| D7. How a law is written | B: conditions and domains in fixed words; free variables implicit and shown |
| D8. The instances a law runs at | A: every implementation of the signature; type variables at `int` |
| D9. Search, counts and budgets | A: random by the principles, exhaustive when small, fixed seeds, a deep mode |
| D10. Laws on the other compilers | B: in the hunt, as differential triage; not in `make check` |
| D11. The Example rule | A: every span a closed `bool` that is true |
| D12. What a failing law leads to | A: the law or the implementation is fixed; no skip list |
| D13. Reporting and replay | A: `PASS`/`FAIL` labels in the Basis suite's form, and a replay token |

### D1. How a program uses a library

**Decided: A** (2026-09-28), as recommended.

The compiler reads one library, the Basis, from `--lib DIR/basis`
through its MANIFEST (`src/driver/main.sml:7-10`). A program can add
anything else only by naming its files on the command line.

* **A. `rune --library NAME`**, repeatable. **Recommended.**
  - **What it reads.** It reads `LIBDIR/NAME/MANIFEST`, in the Basis's format. A header line such as `# library: random` names the libraries it requires, which are loaded first.
  - **What it shares with runedoc.** runedoc's `--library` already reads such a MANIFEST on top of the Basis (`src/doc/docmain.sml:122-141`, `src/doc/docelab.sml:18-36`). It learns to read the same `# library:` dependencies. Its rule that a name with a `/` is a path (`docmain.sml:124-126`) becomes "a path when it starts with `/` or `.`", so that `test/property` is a name.
  - **No primitives.** A library other than the Basis is elaborated without `_prim` in both tools. runedoc allows them for every library today (`docelab.sml:29`).
  - **Installing.** `scripts/install.sh` copies every library that has a MANIFEST.
  - **Documentation.** `make docs` documents the new libraries too, into `docs/generated/random` and `docs/generated/test/property`.
  - **Tests.** Their suites live in `tests/lib/`, with a runner of their own, so they need no rows in `docs/language.md`.
  - **Later.** The MANIFEST is what a build language's "library" would read, so the build language of the incremental-compilation roadmap (on branch `heap-layout`; its D15 and D16) can subsume the option when it comes.
* **B. File lists.** A `FILES` list per library, which every user expands on the command line. It needs no compiler change, but every user repeats it, `install.sh` still has to learn the libraries, and runedoc and the compiler disagree about what a library is.
* **C. Wait for the build language** of the incremental-compilation roadmap (its M10). That ties this roadmap to one that has not started.

### D2. The random number generator

**Decided: A** (2026-09-28), as recommended.

The generator of D3 needs a hash from a seed and an address to a word,
more than it needs a stream. The library `lib/random` needs both.

* **A. SplitMix64** (Steele, Lea and Flood 2014), with its `split`, its finaliser as the hash, and Lemire's method for bounded draws (Lemire 2019). **Recommended.**
  - It is 64 bits of state and a gamma, a dozen lines of `Word64`.
  - It has been Haskell QuickCheck's generator since version 2.13, in 2019 (*What the literature says*). Its `mixGamma` is taken from the JDK, not from the paper, whose printed version has its test inverted (O'Neill 2017).
  - It gives the same answers as C on Rune, MLton, SML/NJ, Poly/ML and MLKit (E4). The one exception, SML/NJ's 32-bit build, is a bug of that compiler's `Word64` literals, to be recorded as a host deviation (M3).
  - Its known weaknesses are weak gammas and a failed birthday-spacing test (Steele and Vigna 2021; Markert et al. 2020). They matter little to a test generator, which needs coverage more than independence.
* **B. xoshiro256\*\*** (Blackman and Vigna 2021): better statistical quality and jumps instead of splits, but 256 bits of state and no natural hash for addresses.
* **C. A counter-based cipher,** Threefry or Philox (Salmon et al. 2011), or a hash of the split path with a block cipher, as Claessen and Pałka (2013) did with Threefish. It is Crush-resistant and a natural fit for a tree addressed by paths, but costs more per draw in a VM where drawing is already a large part of a test (E2). It stays the fallback if SplitMix's hash of addresses shows correlations.
* **D. The Basis suite's Lehmer generator** (`tests/basis/harness.sml:137-167`), with 30 bits and one stream. It cannot address a tree.

### D3. Generators and shrinking

**Decided: D** (2026-09-28), as recommended.

A failing case is shrunk to a small one before it is shown. How that is
done shapes everything else.

* **A. QuickCheck's type-based shrinking.** Every arbitrary carries a `shrink : 'a -> 'a list` beside its generator.
  - Without type classes, every user writes and passes shrinkers.
  - A shrunk value need not be one the generator could produce, so a generator's invariant is lost under `map`.
  - Nothing shrinks through `bind`.
* **B. Integrated shrinking with rose trees** (Hedgehog, OCaml's QCheck2). A generator returns a value and the tree of its shrinks, so `map` shrinks for free. `bind` shrinks poorly, and a strict language builds the trees eagerly or through thunks.
* **C. Internal shrinking over a choice sequence** (Hypothesis, elm-test 2, rapid).
  - Every generator draws from one sequence of numbers, and the shrinker edits the sequence: it deletes blocks and lowers values. Shrinking is free for every combinator, with no per-type shrinkers.
  - A generated function draws when it is called. When the order of calls changes under shrinking, later draws shift, and a shrink stops being local.
* **D. Internal shrinking over a sample tree** (falsify, de Vries 2023), made implicit by hashing addresses. **Recommended.**
  - Everything C gives, with each part of a value and each argument of a function reading its own subtree, so nothing shifts.
  - The prototype built it in about 300 lines (E6). It reached the known minimum of the shrinking challenge's `reverse` and `distinct` in every seed, and the minimal shape of the two planted bugs.
  - The prototype also found what the design needs beyond falsify's:
    - each node's kind in the log;
    - an offset encoding for one-sided ranges;
    - a pass over equal nodes;
    - a delete-and-shift pass for lists whose length is drawn by the caller.
  - The rules are in *The architecture*. M5 builds them and measures them against the challenge.

### D4. Instances without type classes

**Decided: A** (2026-09-28), as recommended.

* **A. Explicit records and functors.** **Recommended.**
  - An `'a arb` record (`gen`, `show`, `co`, `eq`) per type, and combinators that build records for compound types (`Arb.list`, `Arb.pair`, `Arb.function`), as QCheck/SML, OCaml's QCheck and elm-test do.
  - Functors derive the records of a signature family (`IntegerArb (I : INTEGER)`). They read the bounds from the structure, so no width is assumed.
  - For the laws, runedoc resolves types to records itself: instance resolution done by the tool that knows the types (*What is different for SML*).
* **B. Type-indexed values** (Yang 1998; Karvonen's generics for MLton's library).
  - A single type index yields every generic function at once: generate, show, shrink, compare, hash.
  - It is elegant, but the encodings are heavy, the error messages obscure, and Rune compiles every program from source. The records of A are what runedoc can write out plainly.
* **C. Functors as dictionaries** only. Every compound type needs a functor application, and functors are not first-class values, so an instance cannot be computed from a type at run time.

### D5. What a variable ranges over

**Decided: C** (2026-09-28), as recommended.

A law that does not restrict a variable claims to hold for every value
of its type. In SML '97, a value of a function type may raise and may
have effects, and the Definition fixes when those happen.

* **A. Pure, total functions**, as in QuickCheck. A law that holds only for them passes.
* **B. A, and functions that raise** for some arguments.
* **C. B, and effect-observing functions:** each call is logged, and the log is part of the outcome of each side (D6). **Recommended.**
  - This is what the law says: a restriction the author meant is written in the law ("when `f` has no effects", D7), and becomes a restriction to A that the tester checks.
  - Functions whose results depend on the calls before them add nothing C cannot see. If the two sides make the same calls in the same order they agree, and if they do not, the logs already differ. Each side starts from a fresh function (D6).

### D6. What a law's `=` compares

**Decided: C** (2026-09-28), as recommended.

* **A. SML's `=` and nothing else.** A law is a `bool` expression, and an exception is a failure. Laws about partial functions need a condition for every exception, and laws at types without equality must be rewritten.
* **B. Outcomes.** The top-level `=` of a law compares what the two sides do: equal values, or the same exception by `exnName`, together with the call logs of D5. Each side runs with fresh generated state.
* **C. B, and an equality per type** where the type has none. **Recommended.** The equalities:
  - `real`: identity, meaning the same number with ±0 distinct and every NaN equal. A law that means IEEE equality writes `Real.==`.
  - `substring`: `Substring.base`.
  - `Date.date`: `Date.compare`, together with the offset.
  - A stream: the characters a reader returns, up to a bound.

  The equality is part of the instance (`eq` in `'a arb`), so runedoc finds it as it finds the generator.

**Rejected:** discarding the cases where a side raises an exception the
member documents under `Raises:`. It would hide a law that fails by
raising, and the named law is one. Its `Overflow` is documented for
`div`, where it is a different case.

### D7. How a law is written

**Decided: B** (2026-09-28), as recommended.

Today a law is an equation in backquotes with prose around it. 44 of the
286 laws have code that is not Standard ML as written, and 67 have a
condition in prose (*Where we are*).

* **A. Free text.** Laws stay prose and a person reads them. Part 2 of the brief is not met.
* **B. Fixed words for conditions and domains; free variables implicit and shown.** **Recommended.**
  - **The equation.** A law is a backquoted equation, and each span is a law.
  - **Conditions.** *for* or *when* followed by a span is a condition in SML. It is tested, and a case that fails it is discarded, with the discard rate reported and bounded.
  - **Domains.** *for `x` from `G`* names a generator for a variable whose domain is sparse (canonical paths, say).
  - **Restrictions.** *when `f` has no effects* restricts `f` to D5's class A.
  - **Free variables.** They are the names left unbound. runedoc lists them on the page with their types, and a variable whose name is a member of the signature, misspelt, is visible there.
  - **The rewrite policy.** Notation that is not SML is rewritten to SML with the same meaning in M7, in a before/after table the owner reviews. A change of meaning happens only in M9, one per counterexample, with the owner.
* **C. Declared variables** (`Law (l : 'a list, i : int):`). Safer against misspelling, heavier for authors, and it repeats what the elaborator knows.

### D8. The instances a law runs at

**Decided: A** (2026-09-28), as recommended.

* **A. Every implementation, and type variables at `int`.** **Recommended.**
  - A law of `INTEGER` runs at `Int`, `Int8`, `Int16`, `Int32` and `IntInf`, and a law of `WORD` at the four words. The narrow ones are small enough to search exhaustively.
  - A type variable is instantiated at `int`, and an equality type variable too. Bernardy, Jansson and Claessen (2010) show when one monomorphic instance is enough for a polymorphic property.
* **B. The structure examples are read in** (`Int`, `Word`). Cheaper, and it misses what only a narrow width shows (E3).

### D9. Search, counts and budgets

**Decided: A** (2026-09-28), as recommended.

* **A. By the principles.** **Recommended.**
  - Random generation by *Generator principles*, exhaustive search when the domain is small (P9), and 100 cases per law and implementation with a fixed seed in `make check`.
  - A deep mode outside it: `RUNE_PROPERTY_DEEP=1`, the seeds of P11.
  - A watchdog in `run-laws.sh` bounds each program's time. The program prints each law's label before running it, so a run that is killed names the law, which is then run alone with verbose output.
* **B. Enumerative only** (SmallCheck, Feat). Complete up to a depth, and blind beyond it: the named law's counterexamples at `Int` are nowhere near small (E3).
* **C. A budget in the VM** (an instruction limit per case). It would stop a non-terminating case inside the process, but it changes the VM for a watchdog's work. It is left for later.

### D10. Laws on the other compilers

**Decided: B** (2026-09-28), as recommended.

* **A. On Rune only**, as examples are today (`docs/doc-comments.md`, "Examples that run").
* **B. In the hunt, also against the other compilers' own Basis.** **Recommended.**
  - The law programs are compiled by MLton, SML/NJ, Poly/ML and MLKit against their own Basis, through the matrix's `native:` configurations.
  - A law that fails there too is wrong as stated. One that fails on Rune only points to Rune.
  - This needs both libraries to be portable Standard ML '97, which E4 supports.
  - It runs in M9 and after changes to a law, not in `make check`.

### D11. The Example rule

**Decided: A** (2026-09-28), as recommended.

* **A. Every span of an `Example:` paragraph is a closed `bool` that is `true`.** **Recommended.** It is elaborated at `make check-docs` and run at `make test-basis`. The 21 spans that are not equations today are rewritten as claims or moved into prose (M1).
* **B. Equations only**, as today. Keeps the 21, and the brief asks otherwise.

### D12. What a failing law leads to

**Decided: A** (2026-09-28), as recommended.

* **A. A fix, and no skip list.** **Recommended.**
  - **The fix.** A law that does not hold is restated so that it does, with the counterexample kept as an `Example:` written as a closed `bool`. An implementation that does not do what the law and the specification say is fixed. Where the specification's own text is what fails, a `Reading:` says so.
  - **Joining `make check`.** The law programs join `make check` at the end of M9, when every law holds. Until then `make test-laws` stands alone, so that `make check` stays green in every commit.
* **B. A deviation list for laws**, as `tests/basis/deviations.txt` is for checks. It makes a wrong law a line in a file, where the brief wants it found and fixed.

### D13. Reporting and replay

**Decided: A** (2026-09-28), as recommended.

* **A. The Basis suite's form.** **Recommended.**
  - Labels such as `INTEGER.div/law-1@Int8`, and `PASS` and `FAIL` lines, which `Pinned by:` and `--check-coverage` can count.
  - The failure class, the counterexample in SML, and a replay token that `RUNE_PROPERTY_REPLAY` accepts.
  - Labels and classes as `classify` and `cover` make them.
* **B. A format of its own.** Nothing is gained.

## The milestones

Every milestone is one commit, or a few, each with `make check` green,
as the repository's rules require.
- **Libraries.** Where a milestone touches a library, it also runs `make matrix-quick`, as `AGENTS.md` asks after a library change.
- **The compiler and runedoc.** Where it touches them, it also builds them on every host (`make host-builds`) and passes the bootstrap, because their sources must build byte-identically on six compilers (MLton, SML/NJ for 64 and 32 bits, Poly/ML, MLKit and Rune).
- **Sizes** are lines of code, estimated: about 5,600 in all. About 1,600 are in the compiler, runedoc and scripts (M1, M2, M7, M8), and about 3,950 in the two libraries and their tests (M3 to M6).

The first milestone is independent of the rest and could be done
tomorrow. M2 to M6 are part 1 of the brief; M1 and M7 to M9 are part 2.

### M1. The Example rule (S, about 150 and the rewrites)

* **What:**
  - Every code span of an `Example:` paragraph is elaborated as a closed `bool` and written to the example programs. That means `DocExamples.isEquation` (`src/doc/docexamples.sml:24-38`) no longer selects.
  - The 21 spans that are not equations today are rewritten as claims or moved into prose (census in *Where we are*). The four whose results depend on the machine become prose, or claims that hold on any machine.
  - `docs/doc-comments.md`'s "Examples that run" says so, and `tests/doc/examples.lib` gets a case for a span that is no `bool`.
* **Why now:** it is independent of everything else and small. It also touches the same comments as M7's law rewrites, so it is better done and regenerated (`make docs`) before them.
* **Done when:** every code span of every `Example:` paragraph is run (789 of 810 are today), `make check` passes, and `make docs` output is committed.
* **Done** (2026-09-28):
  - **The rule in runedoc.** `DocExamples.ofDoc` takes every code span of an `Example:` paragraph (`isEquation` is gone). Each is elaborated as a closed `bool` at `make check-docs` and run at `make test-basis`.
  - **The Basis.** 795 examples of 65 signatures hold, where 789 were run before. The rewritten spans are:
    - the side pieces of `foldl` and `foldr`, now equations;
    - `Word8.toInt 0wxFF = 255`, `LargeWord.wordSize = 64` and `size "a\\nb" = 4`, results the prose gave, now claims;
    - `fmt StringCvt.EXACT 0.1 = IEEEReal.toString (toDecimal 0.1)`;
    - the four whose results depend on the machine's `/etc` files (`NetHostDB`, `NetProtDB`, `NetServDB`), now prose.
    
    The `<=` claim of `RUNTIME` and the `all (op =)` piece of `LIST_PAIR` were `bool`s already, and now run.
  - **The fixture.** `tests/doc/examples.lib` has a span that is no `bool` (an error at its comment) and a claim that is no equation (`andalso`, run).
  - **The texts.** `docs/doc-comments.md`, `AGENTS.md`, `docs/architecture.md`, `man/runedoc.1`, `runedoc --help` and the pages' own legend and coverage text say the new rule.

### M2. Libraries (S–M, about 400)

* **What:** D1.
  - `rune --library NAME`, repeatable. The MANIFEST's header names the libraries a library requires.
  - `BasisManifest` entries carry their directory, and selection runs over the Basis and the libraries together (`src/driver/basismanifest.sml:106-139`).
  - The library is elaborated without primitives, in the compiler and in runedoc (`src/doc/docelab.sml:29`).
  - runedoc's rule for names with a `/` changes (`src/doc/docmain.sml:124-126`), and `rune --basis-check` checks a library's MANIFEST too.
  - `scripts/install.sh` installs every library.
  - A toy library under `tests/lib/toy` with a test that uses it from a program.
  - `docs/building.md`, `man/rune.1` and `README.md`'s layout table are updated.
* **Why now:** both new libraries need it. It is compiler source under the portability rules, and it can be tested with a toy library before either new library exists.
* **Done when:** a program compiled with `--library toy` runs, the same program compiled with the files listed gives the same bytecode, and `make check` passes.
* **Done** (2026-09-28):
  - **The option.** `rune --library NAME`, repeatable, as D1 has it:
    - `BasisManifest` entries carry their directory, and are chosen by path;
    - `# library:` lines name the libraries a library is written on, which `BasisManifest.libraries` loads first, each once, refusing a cycle;
    - the libraries are elaborated after the basis library, without `_prim`;
    - `--basis-deps` prints a library's files by path, and `--basis-check` checks its MANIFEST, whose requires column names what it uses of the basis library.
  - **A library sees the basis library through its seals, as a program does.** The files the chosen libraries name count as mentioned, and the choice is made again. The comparison with the files listed found this: without it a library saw `Int` whole, helpers included. With it the two compiles make the same bytecode, the source path they record aside.
  - **runedoc** takes a name with a `/` as a name unless it begins with `/` or `.`, reads the same `# library:` lines, and allows `_prim` only to the basis library or to a library written on nothing. `tests/doc/run-doc-tests.sh` passes its on-Basis fixtures as `./` paths.
  - **Installing.** `scripts/install.sh` installs every directory of `lib` that has a MANIFEST.
  - **Tests.** `tests/lib` (`make test-lib`, in `make check`) has 8 checks over toy libraries:
    - a program runs;
    - the files listed give the same bytecode;
    - a library written on another loads it first;
    - `--basis-deps` loads nothing a program does not name;
    - `--basis-check` passes;
    - `_prim` is refused;
    - a library written on itself is refused;
    - runedoc documents a library written on another.
  - **Documentation.** `docs/building.md`, `docs/architecture.md`, `man/rune.1`, `rune --help` and `AGENTS.md`.

### M3. `lib/random` (S, about 450 with tests)

* **What:**
  - `RANDOM` as in *The architecture*: SplitMix64, `split`, Lemire's bounded draws, reals from 53 bits, the hash, replay tokens, and `fromEntropy`.
  - Its documentation comments, documented in full, with `lib/random/DOCUMENTED`.
  - `tests/lib/random`:
    - the known answers of `splitmix64.c` for seeds 0 and `0x0123456789ABCDEF` (E4);
    - a χ² check of `below` and `int` over small ranges with fixed seeds;
    - the same answers from MLton, SML/NJ, Poly/ML and MLKit through the matrix's `xc1:` build of the library. SML/NJ's 32-bit build gets them wrong through its `Word64` literal bug (E4): a `HOST-BUG` deviation, and a report in `docs/bugreport/smlnj`.
* **Why now:** the property library is built on it. And a PRNG that is wrong on one compiler only, for instance through a width assumption, is the kind of bug that must be caught before anything depends on it.
* **Done when:** the suite passes on Rune and the other compilers and `make check` passes.
* **Done** (2026-09-28):
  - **The library.** `lib/random` (`RANDOM`, `Random :> RANDOM`) as *The architecture* has it:
    - SplitMix64 with the JDK's `split` and `mixGamma`;
    - Lemire's bounded draws, with the 128-bit product built from 32-bit halves;
    - reals from 53 bits, in two ints of at most 27 bits;
    - `hash` and `hashString`, replay tokens, and `fromEntropy`.
    
    It is written in `Word64`, with an int only at its interface, and documented in full (`lib/random/DOCUMENTED`; `docs/generated/random` from `make docs`, checked by `make check-docs`).
  - **Its tests in `tests/lib`** (`make test-lib`, in `make check`):
    - the known answers of `tests/lib/random/reference.c`, a C transcription of splitmix64.c, the JDK's split and Lemire's draw, which the runner compiles and compares;
    - `props.sml`, with χ² tests of `below`, `int` and `bool` at p = 0.001 under fixed seeds, reals, the errors raised, tokens and `split`;
    - `--basis-check`;
    - the documentation's 8 examples.
  - **On the other compilers.** `make test-lib-hosts` (`tests/lib/run-hosts.sh`, not in `make check`) builds the same tests with each host compiler against its own Basis. MLton (with its 32-bit `Int`), SML/NJ for 64 bits, Poly/ML and MLKit pass.
    - SML/NJ 110.99.9's 32-bit build does not. Its `Word64.word` loses bits 30 and 31 of its low half, in literals and in arithmetic.
    - That is smlnj/legacy #260, closed as fixed in 110.99.4 and still there, together with an arithmetic half it never reported.
    - It is a `HOST-BUG` line of `tests/lib/deviations.txt`, with a report in `docs/bugreport/smlnj/Word64-low-half`. The library is not changed for it (the owner's rule, now in `AGENTS.md`).
  - **runedoc links into the Basis.** A library written on the Basis Library now resolves what its comments name of it, a `Raises:` exception included, and `--basis-docs DIR` links it to the Basis Library's pages. Without that, `lib/random`'s `Raises: Domain` was an error under its ratchet. `tests/doc/onbasis.lib` covers it.
  - **Not done:** χ² over Schaathun's split sequences. `props.sml` checks only that two split streams differ; a statistical battery for `split` is left for when it matters.

### M4. The property core (M, about 1,200)

* **What:**
  - The source and the implicit sample tree, `GEN` and `CO` with the instances for the Basis's base types, `SHOW`, `ARB`, `PROP` with outcome equality (D6), and `CHECK` without shrinking.
  - Labels, `classify` and `cover`, and replay tokens.
  - `tests/lib/property`: generators are checked for their distributions (every family of P1 to P6 appears in a thousand draws), for determinism (a seed gives the same cases on every VM and at every `-O`), and for the independence of subtrees (changing a node changes only its part).
* **Why now:** this is QuickCheck without shrinking, and everything later is built on it.
* **Done when:** the suite passes, a property over `int list` and one over `int -> bool` find planted bugs, and `make check` passes.
* **Done** (2026-09-28):
  - **`lib/test/property`** (`rune --library test/property`, written on `lib/random` by its `# library:` line), as *The architecture* has it. `PropertySource` is the implicit tree, whose nodes carry their kind for M5.
  - **`GEN`:**
    - the combinators: `return`, `map`, `map2`, `bind`, `pair`, `triple`, `sized`, `resize`, `oneOf`, `frequency`, `elements`, `filter` (a hundred tries, then a discard), `fix`;
    - the Basis's simple types by the generator principles: integers by P1 in thirds, with an offset or zigzag encoding (E6), in `Word64` so that no width is assumed; words by P3; `char` by P5; `real` by P4, made from its bits; `bool`, `unit`, `order`;
    - `option`, and `list` with a length and a mark per element (P6), `listOf`, `string`, `vector`, and `array` (fresh at every draw);
    - pure functions keyed by an observation.
  - **`CO`, `SHOW`, `ARB`.** Observers, printers that print Standard ML, and the `arb` records of D4 with the instances of the Basis's simple types. `real`'s equality is identity (D6 C).
  - **`PROP`.** `holds`, `forAll`, `equal` and `law` compare outcomes (D6): a value, or an exception by name. `law` draws each side's argument anew from the same nodes, so that a side that changes an array does not change the other's. There are also `==>`, `label`, `classify` and `cover`.
  - **`CHECK`.** Seeds are a hash of the name. Sizes grow from 0 to 100 over 100 cases (P8). It also has labels and coverage, replay tokens with `Check.replay`, `report` in the `PASS`/`FAIL` form, and `main`.
  - **Tests: `tests/lib/property/core.sml`** has 29 checks:
    - every family of P1, P3 to P6 in a thousand draws;
    - the same value from the same seed, and a fingerprint of 200 draws that every compiler must reproduce (`fingerprint.expected`);
    - a node set to 0 changes its part alone;
    - the planted bugs over an `int list` and over an `int -> bool` are found;
    - exceptions as outcomes, fresh arrays for each side of a law, discards, giving up, coverage, and replay.
  - **The documentation's examples run** (`make test-lib`), and the library is documented in full (`docs/generated/test/property`). Its links into the Basis come from M3's `--basis-docs`.
  - **Found on the way:** a first version of the tests used `Int.abs` on drawn integers and failed at `minInt`, an edge of P1 whose absolute value overflows. It was the test's bug, of the named law's kind.
  - **Not yet portable at this commit.** `make test-lib-hosts` found two problems, which M5 fixes:
    - SML/NJ has no `PackRealLittle` and Poly/ML has no `PackReal64Little`, and the library used the first. Both are optional in the Basis, so neither may be used.
    - The fingerprint hashed printed values, and `Real.fmt` prints differently on Poly/ML, MLton and SML/NJ (`tests/basis/deviations.txt`). So MLton, Poly/ML and MLKit gave fingerprints of their own, although the 28 other checks pass on all three.
  - **Left for M5:** shrinking (a failure is reported as drawn), and the call tables and classes B and C of functions (D5). **Left for M6:** exhaustive search, and the instances of signature families.

### M5. Shrinking and functions (M, about 800)

* **What:**
  - **The passes of *The architecture*:** by kind, equal nodes together, marks, delete-and-shift, redistribution. Each keeps the failure class.
  - **Functions.** Their call logs, shown as tables, and D5's three classes.
  - **The self-test.** The shrinking challenge's problems, and planted bugs with known minimal counterexamples, as tests that must reach the minimum or a stated bound on its size.
* **Why now:** a counterexample nobody can read is half a result. The prototype showed which passes the sample tree needs (E6).
* **Done when:** the challenge's `reverse`, `distinct` and `length list` shrink to their minima for seeds 1 to 10. `large union list` and `nested lists` reach theirs too, or, if moving elements between lists is still out of reach, end with the minimum's elements spread over more lists, the gap recorded here. And `make check` passes.
* **Done** (2026-09-28):
  - **The shrinker** (`Check.shrink`) works in sweeps.
    - A pass is a list of sites, each with the changes it may make, tried in order. A change that is taken is tried again at the same site, and a site with none moves the sweep on.
    - The passes are swept in turn until a round changes nothing, or `maxShrinks` runs (5,000 by default) are spent.
    - The first version restarted every pass after each change taken, and `large union list` took up to 4,137 runs; the sweeps take at most 584.
  - **The passes**, in their order:
    - **Delete** an element of a list and move the ones after it down (`list` and `listOf` alike, so `length list` loses any element).
    - **Make a function a constant.** This zeroes the function's subtree, so that every node below it that the shrinker has not set reads 0. That makes the function pure and gives the simplest value everywhere. A second change zeroes only its results and raises, which keeps its kind. A raise is the word 0, so the simplest raising function raises everywhere.
    - **Join** two lists that are elements of one list: the second's elements are appended to the first, and the second is deleted. `large union list` and `nested lists` need this move.
    - **Lower** each node's word by its kind's candidates, as before.
    - **Lower equal words together**, now only among nodes of one kind (the planted sort's `[~1, ~1]` of E6).
    - **Redistribute** between two integers.
    - **Swap** neighbouring elements. This puts `[~1, 0]` in the order `[0, ~1]`.
  - **The rule that ends it.** A change is kept only if the case still fails in the same class and is *simpler*: it reads fewer nodes, or as many with words smaller where they first differ (shortlex, as Hypothesis orders its choice sequences).
    - Without it, deleting the one element of `length list` drew the element anew, as `1000`, and the shrinker went round until the runs were spent.
    - Making a function a constant is kept if the case is no less simple, as the function's words may already be 0. The zeroed paths only grow, so it too ends.
  - **Functions.**
    - `PropertySource` records each call with the function's position. The report prints a counterexample's calls as `fn 0 => false` lines, after shrinking.
    - Classes B and C of D5 are in `Arb.function`, class A alone in `Arb.pureFunction`.
    - A law compares the effect logs of its two sides after their outcomes (D6).
  - **Tests: `tests/lib/property/shrink.sml`,** every problem over seeds 1 to 10:

    | Problem | Minimum | Reached | Runs |
    |---|---|---|---|
    | reverse | `[0, ~1]` | 10 of 10 | 19–26 |
    | distinct | `[0, ~1, 1]` | 10 of 10 | 39–203 |
    | length list | `[900]` | 10 of 10 | 56–156 |
    | large union list | `[[0, ~1, 1, ~2, 2]]` | 10 of 10 | 115–584 |
    | nested lists | `[[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]` | 10 of 10 | 99–101 |
    | planted `all` (skips the last element) | `p` a constant `false`, `[0]` | 10 of 10 | 7–8 |
    | planted sort (drops equal elements) | `[0, 0]` | 10 of 10 | 19–23 |
    | planted `map` (calls `f` from the right) | an effect-observing `f`, `[0, ~1]` | 10 of 10 | 33–39 |

    - Five checks of functions: a raising function is drawn and shrinks to `(fn, 0)`; its exception is an outcome; effects are compared; a pure function has none; the calls are reported.
    - The whole file runs in about 1.3 seconds on runevm.
    - `tests/lib/run-hosts.sh` runs it on the other compilers as `property.shrink`.
  - **The gap E6 left for `all`** was closed by constants, not by copying a function's results to the new argument as E6 proposed. Once `p` is a constant, `x` shrinks freely.
  - **Portable** (the gap M4 left).
    - A real node's bits are computed with `Real.toManExp`, `Real.fromManExp` and `Real.toLargeInt` instead of an optional `PackReal` structure. `core.sml` checks known encodings and 20,000 round trips.
    - The fingerprint now hashes the observations of the values (`Co`), not their printing. It is `6022504E33410D82` on Rune, MLton, Poly/ML and MLKit.
    - `make test-lib-hosts`: 16 pass, 4 explained, none failed. SML/NJ's `Real.fromManExp` is 0.0 at the least normal exponent and below, so there subnormal reals decode as 0.0 and the fingerprint differs. The Basis suite already records that as `Real.fromManExp/minPos`, and it is a `HOST-BUG` line here. The library is written on `lib/random`, so SML/NJ's 32-bit build fails it by M3's host bug.
  - **Still open: the named law's local minima (E3).** At `Int8`, with the documented cases discarded, 100 seeds shrink to 19 different pairs.
    - The simplest, `(1, ~128)`, is reached in 20 of them; `(65, ~64)` in 17 and `(~66, 65)` in 15.
    - Lowering either number alone loses the `Overflow`, and redistribution keeps the sum of the two words, which is not what these pairs have in common.
    - Every one is a correct counterexample, which is what the hunt needs (*Risks*). A better pass for such pairs is left for when a law needs it.

### M6. The Basis's instances, and the generators frozen (L, about 1,500)

* **What:**
  - **Instances** for every type the census needs, 113 in all:
    - the families: `IntegerArb`, `WordArb`, `RealArb`, `IntInf`, `Char`/`WideChar`, strings;
    - the data: arrays, vectors and slices of every element type (`Array2` included), `Date.date` and its record of fields, `Time.time`, `IEEEReal.decimal_approx`, the Basis's datatypes (`rounding_mode`, `buffer_mode`, `traversal`, `Posix.IO.whence`);
    - readers with their streams.
  - **System values.** Streams (binary and text, with their writers), sockets and addresses, host entries, address families and socket types, file ids, I/O descriptors, Posix file descriptors, pids, signals, user and group ids, and terminal settings.
    - These are made, not drawn: a stream over a generated string or a file in a scratch directory, a loopback socket pair, the process's own ids.
    - A generator of that kind is an instance too, with a cleanup the runner calls after each case.
    - Where no such generator makes sense, the law must name a domain (D7) and the owner is told (*The blind test*).
  - **Exhaustive mode** (P9).
  - **Mutant calibration.** Mutants of a copy of `List`, `Int8` and `Substring` (off-by-one bounds, swapped arguments, a dropped exception, a wrong sign) must be killed by properties written for the library's own tests, not by documented laws. The kill rate is reported per family.
  - **Frozen.** The principles are then frozen (*Generator principles*).
* **Why now:** after this the generators are what the hunt will use, so they are fixed before any documented law is run.
* **Done when:** every type in the census has an instance, the mutants are killed at the reported rates, and `make check` passes.
* **Done** (2026-09-28):
  - **Instances.** The functors are named with `Fn`, so that the instance of the type of a structure `X` of the Basis is `XArb.arb`. That is the rule by which M7's runedoc will resolve a type to its instance.
    - `IntegerArbFn`, `WordArbFn`, `RealArbFn`, `CharArbFn`, `StringArbFn`, `SubstringArbFn`, and `MonoVectorArbFn`, `MonoArrayArbFn`, the two slice functors and `MonoArray2ArbFn`. They read bounds, word sizes, precision and `maxOrd` from the structure (D4).
    - An integer structure within `Int.int`'s range is drawn through `Int`, and a wider one through `Gen.largeRange` in `LargeInt`. So no width is assumed.
    - A real structure other than binary64 gets its own specials, and bit patterns with an exponent uniform over its format.
    - The instances: `IntArb`, `IntInfArb`, `LargeIntArb`, `PositionArb`, `WordArb`, `Word8Arb`, `LargeWordArb`, `SysWordArb`, `RealArb`, `LargeRealArb`, `CharArb`, `StringArb`, `SubstringArb`, `CharVectorArb`, `CharArrayArb`, the char and `Word8` slices, vectors and arrays. The optional ones are `Int8Arb` to `Int64Arb`, `FixedIntArb`, `Word16Arb` to `Word64Arb`, `Real32Arb`, `Real64Arb`, the wide characters, strings and substrings, and `IntArray2Arb`, `CharArray2Arb` and `Word8Array2Arb`.
    - `Arb` gained `intInf`, `reference`, `enum` (datatypes), `vectorSlice`, `arraySlice`, `array2` and `exn`. `DateArb` (dates, months, weekdays, the record of fields), `TimeArb`, `IEEERealArb` and `BasisDataArb` (buffer modes, radixes, traversals, readers over a string with positions as the stream) follow P12.
  - **System values** (`SystemArb`, `SML90Arb`, `INet6SockArb`) are made, and undone after each case:
    - binary streams over drawn bytes, a writer that keeps what it is given, and output streams over it;
    - an SML '90 stream of a scratch file;
    - pipes for I/O and Posix descriptors and poll descriptors, and scratch files for file ids;
    - new TCP sockets over IPv4 and IPv6;
    - the process's own ids, and `localhost`'s host entry;
    - the named signals, errors and speeds, and terminal settings from drawn flags and control characters.

    `Gen.resource` registers a cleanup, and `Check` runs a case's cleanups when the case is over, in random runs, shrinking and enumeration alike. No type of the census was left without a generator, so no law has to name a domain for that reason.
  - **Exhaustive mode (P9).** Every node records its bound: the number of words that are values of it, or none.
    - When every node of a case is bounded and the bounds multiply to at most `exhaustiveBelow` (65,536), `Check` runs every case in the order of their words, simplest first. So a failure found is the simplest there is, and it is not shrunk.
    - The bounds are checked at every case, since a later case may read more nodes than the first.
    - Such a failure's replay token lists the words (`X0.1.C8:100`).
  - **The small scope (P13)** runs next, for `smallScope` cases (100).
  - **Mutant calibration** (`tests/lib/property/mutants.sml`): each mutant of a copy of the members is compared, by outcome, with the Basis's own member, by properties written for this test.

    | Family | Mutants | Killed |
    |---|---|---|
    | `List` | `nth` off by one, `take` without its `Subscript`, `drop` of a negative count, `tabulate` off by one, `foldl` with swapped arguments, `partition` with swapped results | 6 of 6 |
    | `Int8` | `fromInt` off by one, `+` without its `Overflow`, `-` with swapped arguments, `div` rounding towards zero, `abs` without its `Overflow`, `sign` with the wrong sign | 6 of 6 |
    | `Substring` | `substring` off by one, `sub` off by one, `triml` without its `Subscript`, `splitAt` with swapped results, `isPrefix` with swapped arguments | 5 of 5 |

    - Before P13, `substring` off by one survived. It accepts `i + n` one past the end of the string, which random draws of the string and the two integers rarely meet.
    - A first fix made integers drawn after a list more likely to be near its length. It broke two things the design needs, which the core and shrink tests caught: a node set by the shrinker then changed parts it did not own, and the two sides of a law no longer drew the same argument. It was taken out for P13.
  - **Frozen** (*Generator principles*): `tests/lib/property/instances.sml` probes 110 types. They are the census's 113 types of free variables as 86 instances (its type variables at `int`, D8), and 24 more of the same families. Each value drawn must show, be equal to itself and have one observation. The hash of the observations is `frozen.expected`, except for the ids and host entry that the process makes from itself.
  - **Portable where the Basis is.** A file of the library that names an optional structure is `host = no` in the `MANIFEST`: `sized.sml`, `wide.sml`, `arrays2.sml`, `sml90.sml` and `inet6.sml`. `tests/lib/run-hosts.sh` builds the others on every compiler. MLton lacks `SML90`, and SML/NJ and Poly/ML lack `Int8`, which is how these files were found. `make test-lib-hosts`: 15 pass, 5 explained by the host bugs of M3 and M5, none failed.
  - **Found on the way:** the test's copy of `Substring.substring` checked `i + n > size s`, which overflows where the Basis raises `Subscript`. It was the test's bug, of the named law's kind again. And `Prop.law` showed a case's argument after the sides had run, so a stream showed what the sides had left of it. It now shows it before.
  - **Costs:** `instances.sml` runs in about 7 seconds and `mutants.sml` in about 14, most of them exhaustive runs over `Int8` pairs.

### M7. Laws elaborated (M, about 600 and the rewrites)

* **What:**
  - D7 in runedoc: laws parsed, with free variables found and typed, and instances resolved by type constructor. An error at the comment for a law that is no SML, and for a type with no instance.
  - The quantifiers on the page and in `--dump-ir`, and `make check-docs` elaborating every law.
  - The notation-only rewrites of lib/basis's laws, in a before/after table in this file for the owner to review.
* **Why now:** a law must mean one thing before it can be run.
* **Done when:** every law elaborates, the table is reviewed, `make docs` output is committed, and `make check` passes.
* **Done** (2026-09-28), all but the owner's review of the rewrites:
  - **The grammar of laws** (D7), in `DocLawGrammar` (`src/doc/doctext.sml`) and documented in `docs/doc-comments.md`, *Laws*:
    - the first piece of code is a law, and so is one after "and" that follows a law;
    - a piece after "for" or "when" is a condition, and so is one after "and" that follows a condition or a domain;
    - "for `x` from `G`" is a domain, and "when `f` has no effects" or "when `f` and `g` have no effects" makes the functions pure;
    - the rest is prose.

    The conditions of a paragraph hold for each of its laws. A condition that raises does not hold, so "when the slice exists" is written ``when `(ignore (slice (v, i, SOME n)); true)` ``. `--dump-ir` prints each law's parts.
  - **Elaboration** (`DocElab.elabLaw`): a law is read under `open S`, as its signature's examples are.
    - Its variables are found by elaborating `fn (x1, ..., xk) => ...` until nothing is left unbound, and are typed by the elaborator.
    - An equation's two sides are elaborated as a list, so that they have one type that need not admit equality (D6). They are cut at the `=` token of the parse, since an infix application's span leaves out its operands' parentheses.
    - Anything else must be a `bool`, and so must each condition.
    - A failed attempt's pending flexible records and overloads are cleared before the next one. Without that, 40 laws failed on a record the earlier attempt left behind.
  - **Instances.** Every variable is given an arbitrary by its type:
    - a type variable at `int` (D8);
    - a function by `Arb.function`, or `Arb.pureFunction` where the law says it has no effects;
    - tuples, records of fields, and `(char, 'a)` readers by their shapes;
    - every other type by a table, or as `XArb.arb` for a type `X.t` that is `X`'s own. `Word8Array.vector` names a vector, so the rule looks at the type as well as the structure.

    runedoc reads the `XArb` names from `lib/test/property/MANIFEST`. A type with no arbitrary is an error at its comment, and every variable of the Basis has one.
    - `lib/random`'s own law needed one more, `RandomArb` for `Random.gen`: the generator of a drawn seed. `frozen.expected` was renewed for it (`E3990241ADEC0310`). Without the new probe the hash is still M6's, so no earlier draw changed.
  - **The pages** show each law's variables with their types: "(for every `i : int`, `j : int`)". 266 of the 286 laws have variables; the others are closed.
  - **Errors at the comment** for a law that is no Standard ML, a condition that is not a `bool`, and a variable with no arbitrary. `make check-docs` elaborates every law of the Basis, so none may stay. Tests: `tests/doc/laws.sml` (the grammar, through `--dump-ir`), `laws.lib` (pages with variables) and `lawerrors.lib` (the three errors).
  - **The rewrites.** 73 laws in 24 files were rewritten, each in *Appendix: the rewrites of M7*, for the owner's review.
    - 41 are notation only: chained comparisons, `^` as a power, `==` as infix, operators that `open S` rebinds, `before`'s precedence, a variable named `tl`, `~0w0`, and "is" for `=`.
    - 19 put a condition written in prose into Standard ML, and 7 do both.
    - 5 write out "and the same for the others" and its kin.
    - 1 splits a paragraph whose second law has a condition of its own.
    - They follow one rule: translate what the text says and add nothing it does not. So a law whose text states no condition for an exception it will meet stays as it is, and M9 will report it.
    - The prose phrases left as prose restrict nothing the arbitraries draw, or are asides: "as the specification defines it", "for a vector type that admits equality", "when the reader does not fail" (the drawn readers never fail), "except that a NaN comes back as some NaN" (D6's identity of reals makes every NaN equal), and "for every condition, named here or not".
    - Before the rewrites, 190 laws did not elaborate: 136 from runedoc's first bugs, and 54 that needed a rewrite.
  - **For the owner:** the table, and whether a translated condition means what the prose meant. The Date law's "the fields of `r` are in range" is the widest translation. It includes the offset within a day and a day within its month's length in a leap year.

### M8. Laws run (M, about 450)

* **What:**
  - `runedoc --laws DIR`, with one program per signature holding every law at every implementation (D8).
  - `tests/basis/run-laws.sh` with its watchdog (D9), and `make test-laws`.
  - `coverage.md` gains "Laws that are run".
  - The compile time and run time of the law programs are measured against E1's estimate.
* **Why now:** it is the harness the hunt runs in.
* **Done when:** `make test-laws` runs every law and reports each one's result. It is not yet in `make check` (D12).

### M9. The hunt (varies)

* **What:** the protocol of *The blind test*.
  - Every law is run with the check settings, then in the deep mode, then against the other compilers' own Basis (D10). Failures are classified, and laws or implementations fixed (D12), one commit per fix with the counterexample as an example.
  - When a run reports nothing new, the owner names the law they meant, and the result is written into this file. `make test-laws` then joins `make check`.
  - Last, the adequacy of the laws: the mutants of M6, run against the documented laws, show which functions the laws leave unconstrained (FitSpec's check).
* **Why now:** last, because everything before it is what it tests.
* **Done when:** every law holds at every implementation in `make check`, and the result of the blind test is recorded here.

### Later

These are left out of this roadmap:
- The Basis suite's random checks (`T.seed`, `T.range` and the rest: 51 files) rewritten on the library, with shrinking.
- Model-based tests of the imperative structures (`Array`, `TextIO`, `Posix.IO`) against pure models, as QuviQ's state machines test stateful APIs (Arts et al. 2006).
- A user's guide in `docs/`.
- Targeted or coverage-guided generation (Crowbar, Hypothesis's `target`).
- Property tests of the compiler itself: a generator of SML programs, which the IR levels and the two VMs can be compared on.

### Why this order

- **M1 first.** The Example rule needs nothing else, finishes something the docgen roadmap started, and clears the comments before M7 edits them.
- **M2 before the libraries.** The libraries cannot be used without it, and it is the only milestone that changes the compiler. It goes where a mistake is cheapest: before anything depends on it.
- **M3 before M4.** A generator on a wrong PRNG gives plausible numbers. The known answers catch that on every compiler before any property runs.
- **M4, M5, M6 in that order.** Generation, then shrinking, then the instances the Basis needs. Each is testable by itself against planted bugs and mutants whose answers are known, and none runs a documented law. The generators are frozen at the end of M6, before the first law runs: that is what keeps the blind test fair (*The blind test*).
- **M7 before M8.** A law has to elaborate and mean one thing before a program can test it.
- **M9 last.** It is what everything else is for.

## Prerequisites and flags

**Nothing from the other plans must come first.** The library mechanism
of M2 is small and designed to be replaced. The JIT's work and the
heap-layout roadmap's (on branch `heap-layout`) touch the VM, which this
roadmap does not change.

Flags:
- **Compile time.** Each law program compiles the Basis subset, `lib/random` and `lib/test/property` from source, since Rune has no separate compilation yet. E1 puts that at just under a second of CPU per program with a library of the prototype's size, the cost of an example program today, for about 45 s over the 48 signatures with laws. The real library is larger, so M8 measures again. When the units of the incremental-compilation roadmap (on branch `heap-layout`) exist, the libraries compile once.
- **A VM budget.** An instruction limit per case (D9's option C) would make non-termination a failure class of its own. It is left to the VM's roadmaps.
- **`Runtime.same`** (pointer identity) can make an observer (`co`) for a type that has neither equality nor structure. Nothing needs it yet.

## Relation to the other plans

- **[docgen.md](docgen.md)** made examples run (its M12). This roadmap finishes the idea: every example runs, and the laws are tested.
- **[structure-docs.md](structure-docs.md)** gave every structure a page of its own (merged as pull request 22). The results of laws per implementation (D8) belong on those pages.
- **[weak-points.md](weak-points.md)** lists "no libraries beyond the Basis Library" (line 166). M2 answers it in the small.
- **The incremental-compilation roadmap** (on branch `heap-layout`) plans a build language with libraries (its D15, D16 and M10). `rune --library` reads what such a library would declare, so the build language can subsume it, and its units remove the compile time flagged above.
- **The JIT and heap-layout roadmaps.** The generator's `Word64`s meet the heap-layout roadmap's 63-bit `Word` and boxed `Word64` (*Risks*). This roadmap asks that one's M4 gate to measure E2's `Word64` workload. More widely, the law programs are deterministic workloads with many small allocations, exceptions and closures, so they make good differential tests. Run under `runevm-new` at every JIT tier, and under the heap-layout roadmap's census VM (`bin/runevm-census`, on branch `heap-layout`), they must print the same lines.
- **The owner's formal-verification brief** (on branch `heap-layout`) asks for theorems generated from a specification. Laws that hold are candidates for those theorems. Laws that fail are better found by testing first.

## Risks

- **Compile time in `make check`.** 48 law programs, each compiling the libraries from source. E1 measures it. If it is too much, one program per group of signatures, or the incremental-compilation units, bring it down.
- **The speed of generation.** Each case costs hash computations and a log per node. E2 measures it, and IntInf is avoided except at `IntInf` itself (P2), because Rune's IntInf is software with 30-bit limbs.
- **The heap layout to come.** The generator is `Word64` arithmetic in the shape of the heap-layout roadmap's `word_loop` kernel (xorshift and a hash with the top bit set). That roadmap (on branch `heap-layout`) decided, provisionally until its M4 gate, `Int` and `Word` at 63 bits with `Int64` and `Word64` types of their own (its D2 B, with 64 bits kept behind a compile-time switch), and stack slots that describe themselves (its D5 A).
  - **What it means for a `Word64`.** Its D2 says a `Word64` is "raw in a typed field or register ... and boxed at a polymorphic position". Read with D5 A, where only the JIT's register homes hold raw values, that means a `Word64` stays raw only in a tier 2 home or in a typed field of a tuple or record built at a known site. It is boxed, 16 bytes a time, wherever it crosses a slot: an argument, a result, any value in the interpreter or in `runevm`. That reading is this roadmap's inference; that roadmap's M4 prototypes will show it.
  - **The cost.** Its C harness measured `word_loop` at 2.77 times today's cycles with the words boxed (6.15 under clang), against 0.44 with them unboxed in locals (1.03, about today's, under clang). The prototype passes addresses and seeds as arguments on every node (`child`, `node`, `lookup`), so generation could become slower under the new layout, not faster.
  - **What this roadmap does about it.** Nothing in the library's code: it is written plainly (*Constraints*), and inlining and typed fields are where the cost is won back. E2's `exp_speed.sml` is a ready-made `Word64` workload for that roadmap's M4 gate. A note proposing it was added to that roadmap on 2026-09-27, uncommitted in its working tree on branch `heap-layout-word`, for its session to commit. M4 of this roadmap measures E2 again on whatever layout is current.
- **Self-reference.** The runner uses the Basis it tests: lists, strings, `Word64`. Its own use is kept small, and D10's differential runs are the oracle when Rune's Basis and the runner are wrong together.
- **Shrinking that stalls.** The sample tree's local minima (E3, E6) can leave a counterexample larger than it needs to be. M5 measures the passes against the challenge, and a counterexample is correct even when it is not minimal.
- **Laws that cannot be generated for.** 124 laws have a variable of a type the Basis keeps abstract, and many of those are system values: streams, sockets, descriptors and ids. They need generators that make real objects and clean them up (M6). A sparse domain, such as canonical absolute paths, needs a named generator (D7). A law that nobody can generate for is flagged to the owner, never dropped (*The blind test*).
- **Non-termination.** A generated size used as a count, or a reader that never ends, can hang a case. The watchdog and the labels printed before each law bound the damage (D9).
- **The blind test proving nothing.** If the hunt misses the owner's law, the gap analysis says why, which is still a result.

## Testing the tester

A property library that passes everything is indistinguishable from one
that tests nothing. The libraries' own suites (`tests/lib`) therefore
test that it fails when it should:
- **Known answers** of the PRNG on every compiler (M3).
- **Distributions.** Every family of every principle appears (M4).
- **Planted bugs** with known minimal counterexamples, and the shrinking challenge (M5).
- **Mutants** of copies of Basis structures, killed by the library's own properties at reported rates (M6).
- **Determinism.** The same seed gives the same cases, the same counterexample and the same replay token on every VM, at every `-O` and on every compiler (M4, M9).

## Appendix: the rewrites of M7

What each law was, what it is, and why (*M7*). Notation is rewritten
without changing what the law says. A condition in prose becomes Standard ML
that says what the prose says. "The others" are written out. The owner
reviews every row, and can veto a change of meaning (*The blind test*).

| File | Before | After | Kind |
|---|---|---|---|
| `int_sig.sml` | `(i < j) = (compare (i, j) = LESS)`, and the same for the others | `(i < j) = (compare (i, j) = LESS)`, and `(i <= j) = (compare (i, j) <> GREATER)`, and `(i > j) = (compare (i, j) = GREATER)`, and `(i >= j) = (compare (i, j) <> LESS)` | the others written out |
| `int_sig.sml` | `fromInt (sign i) * abs i = i` when `abs i` is in the range | `fromInt (sign i) * abs i = i` when `minInt <> SOME i` | condition |
| `int_sig.sml` | `fromInt (toInt i) = i` when `i` is in the range of `Int.int` | `fromInt (toInt i) = i` when `(case Int.minInt of NONE => true \| SOME m => LargeInt.<= (Int.toLarge m, toLarge i)) andalso (case Int.maxInt of NONE => true \| SOME m => LargeInt.<= (toLarge i, Int.toLarge m))` | condition |
| `int_sig.sml` | `i - j = i + ~j` when `~j` is in the range | `i - j = i + ~j` when `minInt <> SOME j` | condition |
| `int_sig.sml` | `maxInt = SOME (fromLarge (IntInf.pow (2, p - 1) - 1))` where `precision = SOME p` | `case precision of SOME p => maxInt = SOME (fromLarge (IntInf.- (IntInf.pow (2, Int.- (p, 1)), 1))) \| NONE => true` | notation and condition |
| `int_sig.sml` | `minInt = SOME (fromLarge (~ (IntInf.pow (2, p - 1))))` where `precision = SOME p` | `case precision of SOME p => minInt = SOME (fromLarge (IntInf.~ (IntInf.pow (2, Int.- (p, 1))))) \| NONE => true` | notation and condition |
| `int_sig.sml` | `toLarge (fromLarge i) = i` when `i` is in the range | `toLarge (fromLarge i) = i` when `(case minInt of NONE => true \| SOME m => LargeInt.<= (toLarge m, i)) andalso (case maxInt of NONE => true \| SOME m => LargeInt.<= (i, toLarge m))` | condition |
| `int_sig.sml` | `~ (~ i) = i` when `~i` is in the range | `~ (~ i) = i` when `minInt <> SOME i` | condition |
| `mono_sigs.sml` | `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)` for `0 <= i < length src`, when `src` and `dst` are not the same array | `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)` for `0 <= i andalso i < length src andalso src <> dst` | notation and condition |
| `mono_sigs.sml` | `(update (arr, i, x); sub (arr, i)) = x` for `0 <= i < length arr` | `(update (arr, i, x); sub (arr, i)) = x` for `0 <= i andalso i < length arr` | notation |
| `mono_sigs.sml` | `(update (sl, i, x); sub (sl, i)) = x` for `0 <= i < length sl` | `(update (sl, i, x); sub (sl, i)) = x` for `0 <= i andalso i < length sl` | notation |
| `mono_sigs.sml` | `length (slice (v, i, SOME n)) = n` when the slice exists | `length (slice (v, i, SOME n)) = n` when `(ignore (slice (v, i, SOME n)); true)` | condition |
| `mono_sigs.sml` | `sub (array (n, x), i) = x` for `0 <= i < n` | `sub (array (n, x), i) = x` for `0 <= i andalso i < n` | notation |
| `mono_sigs.sml` | `sub (fromList l, i) = List.nth (l, i)` for `0 <= i < List.length l` | `sub (fromList l, i) = List.nth (l, i)` for `0 <= i andalso i < List.length l` | notation |
| `mono_sigs.sml` | `sub (fromList l, i) = List.nth (l, i)` for `0 <= i < List.length l` | `sub (fromList l, i) = List.nth (l, i)` for `0 <= i andalso i < List.length l` | notation |
| `mono_sigs.sml` | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k < length sl - i` | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k andalso k < length sl - i` | notation |
| `mono_sigs.sml` | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k < length sl - i` | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k andalso k < length sl - i` | notation |
| `mono_sigs.sml` | `sub (tabulate (n, f), i) = f i` for `0 <= i < n`, when `f` has no effects | `sub (tabulate (n, f), i) = f i` for `0 <= i andalso i < n`, when `f` has no effects | notation |
| `mono_sigs.sml` | `sub (tabulate (n, f), i) = f i` for `0 <= i < n`, when `f` has no effects | `sub (tabulate (n, f), i) = f i` for `0 <= i andalso i < n`, when `f` has no effects | notation |
| `mono_sigs.sml` | `sub (update (v, i, x), i) = x`, and `sub (update (v, i, x), j) = sub (v, j)` for every other position `j` | Law: `sub (update (v, i, x), i) = x` <br> Law: `sub (update (v, i, x), j) = sub (v, j)` for `j <> i andalso 0 <= j andalso j < length v` | condition, and split |
| `sig_array.sml` | `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)` for `0 <= i < length src`, when `src` and `dst` are not the same array | `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)` for `0 <= i andalso i < length src andalso src <> dst` | notation and condition |
| `sig_array.sml` | `(copyVec {src = v, dst = dst, di = di}; sub (dst, di + i)) = Vector.sub (v, i)` for `0 <= i < Vector.length v` | `(copyVec {src = v, dst = dst, di = di}; sub (dst, di + i)) = Vector.sub (v, i)` for `0 <= i andalso i < Vector.length v` | notation |
| `sig_array.sml` | `(update (arr, i, x); sub (arr, i)) = x` for `0 <= i < length arr` | `(update (arr, i, x); sub (arr, i)) = x` for `0 <= i andalso i < length arr` | notation |
| `sig_array.sml` | `sub (array (n, x), i) = x` for `0 <= i < n` | `sub (array (n, x), i) = x` for `0 <= i andalso i < n` | notation |
| `sig_array.sml` | `sub (fromList l, i) = List.nth (l, i)` for `0 <= i < List.length l` | `sub (fromList l, i) = List.nth (l, i)` for `0 <= i andalso i < List.length l` | notation |
| `sig_array.sml` | `sub (tabulate (n, f), i) = f i` for `0 <= i < n`, when `f` has no effects | `sub (tabulate (n, f), i) = f i` for `0 <= i andalso i < n`, when `f` has no effects | notation |
| `sig_array2.sml` | `(update (arr, i, j, x); sub (arr, i, j)) = x` for every row `i` and column `j` of `arr` | `(update (arr, i, j, x); sub (arr, i, j)) = x` for `0 <= i andalso i < nRows arr andalso 0 <= j andalso j < nCols arr` | condition |
| `sig_array2.sml` | `column (arr, j) = Vector.tabulate (nRows arr, fn i => sub (arr, i, j))` for every column `j` of `arr` | `column (arr, j) = Vector.tabulate (nRows arr, fn i => sub (arr, i, j))` for `0 <= j andalso j < nCols arr` | condition |
| `sig_array2.sml` | `row (arr, i) = Vector.tabulate (nCols arr, fn j => sub (arr, i, j))` for every row `i` of `arr` | `row (arr, i) = Vector.tabulate (nCols arr, fn j => sub (arr, i, j))` for `0 <= i andalso i < nRows arr` | condition |
| `sig_array2.sml` | `sub (array (r, c, x), i, j) = x` for `0 <= i < r` and `0 <= j < c` | `sub (array (r, c, x), i, j) = x` for `0 <= i andalso i < r andalso 0 <= j andalso j < c` | notation |
| `sig_array2.sml` | `sub (fromList rows, i, j) = List.nth (List.nth (rows, i), j)` for every row `i` and column `j` of the array | `sub (fromList rows, i, j) = List.nth (List.nth (rows, i), j)` for `0 <= i andalso i < nRows (fromList rows) andalso 0 <= j andalso j < nCols (fromList rows)` | condition |
| `sig_array2.sml` | `sub (tabulate trv (r, c, f), i, j) = f (i, j)` for `0 <= i < r` and `0 <= j < c`, when `f` has no effects | `sub (tabulate trv (r, c, f), i, j) = f (i, j)` for `0 <= i andalso i < r andalso 0 <= j andalso j < c`, when `f` has no effects | notation |
| `sig_array_slice.sml` | `(update (sl, i, x); sub (sl, i)) = x` for `0 <= i < length sl` | `(update (sl, i, x); sub (sl, i)) = x` for `0 <= i andalso i < length sl` | notation |
| `sig_array_slice.sml` | `base (slice (arr, i, SOME n)) = (arr, i, n)` when the slice exists | `base (slice (arr, i, SOME n)) = (arr, i, n)` when `(ignore (slice (arr, i, SOME n)); true)` | condition |
| `sig_array_slice.sml` | `collate cmp (sl, tl) = List.collate cmp (foldr (op ::) [] sl, foldr (op ::) [] tl)` | `collate cmp (sl, sl') = List.collate cmp (foldr (op ::) [] sl, foldr (op ::) [] sl')` | notation |
| `sig_array_slice.sml` | `sub (slice (arr, i, NONE), k) = Array.sub (arr, i + k)` for `0 <= k < Array.length arr - i` | `sub (slice (arr, i, NONE), k) = Array.sub (arr, i + k)` for `0 <= k andalso k < Array.length arr - i` | notation |
| `sig_array_slice.sml` | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k < length sl - i` | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` for `0 <= k andalso k < length sl - i` | notation |
| `sig_byte.sml` | `(packString (arr, i, ss); unpackString (Word8ArraySlice.slice (arr, i, SOME (Substring.size ss)))) = Substring.string ss` when it fits | `(packString (arr, i, ss); unpackString (Word8ArraySlice.slice (arr, i, SOME (Substring.size ss)))) = Substring.string ss` when `0 <= i andalso Substring.size ss <= Word8Array.length arr - i` | condition |
| `sig_char.sml` | `(c < d) = (ord c < ord d)`, and the same for the others | `(c < d) = Int.< (ord c, ord d)`, and `(c <= d) = Int.<= (ord c, ord d)`, and `(c > d) = Int.> (ord c, ord d)`, and `(c >= d) = Int.>= (ord c, ord d)` | notation, and the others written out |
| `sig_char.sml` | `ord (chr i) = i` for `0 <= i <= maxOrd` | `ord (chr i) = i` for `Int.<= (0, i) andalso Int.<= (i, maxOrd)` | notation |
| `sig_date.sml` | `toTime (fromTimeUniv t) = Time.fromSeconds (Time.toSeconds t)` for a time `t` at or after the epoch | `toTime (fromTimeUniv t) = Time.fromSeconds (Time.toSeconds t)` for `Time.>= (t, Time.zeroTime)` | condition |
| `sig_date.sml` | `year (date r) = #year r` when the fields of `r` are in range, and the same for `month`, `day`, `hour`, `minute` and `second` | `year (date r) = #year r`, and `month (date r) = #month r`, and `day (date r) = #day r`, and `hour (date r) = #hour r`, and `minute (date r) = #minute r`, and `second (date r) = #second r`, when `let val {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = off} = r val leap = (y mod 4 = 0 andalso y mod 100 <> 0) orelse y mod 400 = 0 val days = case m of Feb => if leap then 29 else 28 \| Apr => 30 \| Jun => 30 \| Sep => 30 \| Nov => 30 \| _ => 31 in 1 <= d andalso d <= days andalso 0 <= h andalso h <= 23 andalso 0 <= mi andalso mi <= 59 andalso 0 <= s andalso s <= 59 andalso (case off of NONE => true \| SOME t => Time.< (Time.fromSeconds ~86400, t) andalso Time.< (t, Time.fromSeconds 86400)) end` | condition, and the others written out |
| `sig_general.sml` | `e before e' = (fn (a, ()) => a) (e, e')` | `(e before e') = (fn (a, ()) => a) (e, e')` | notation |
| `sig_general.sml` | `f o (g o h) = (f o g) o h`: composition is associative, as functions and not as values that `=` could compare | `(f o (g o h)) x = ((f o g) o h) x`: composition is associative, as functions and not as values that `=` could compare | notation |
| `sig_int_inf.sml` | `pow (2, log2 i) <= i andalso i < pow (2, log2 i + 1)` for `i > 0` | `pow (2, log2 i) <= i andalso i < pow (2, Int.+ (log2 i, 1))` for `i > 0` | notation |
| `sig_int_inf.sml` | `pow (i, j + k) = pow (i, j) * pow (i, k)` for `j` and `k` not negative | `pow (i, Int.+ (j, k)) = pow (i, j) * pow (i, k)` for `Int.>= (j, 0) andalso Int.>= (k, 0)` | notation and condition |
| `sig_list.sml` | `hd l :: tl l = l` for a non-empty `l` | `hd l :: tl l = l` for `not (null l)` | condition |
| `sig_list.sml` | `take (l, i) @ drop (l, i) = l` for `0 <= i <= length l` | `take (l, i) @ drop (l, i) = l` for `0 <= i andalso i <= length l` | notation |
| `sig_list_pair.sml` | `unzip (zip (l, m)) = (l, m)` when `l` and `m` are as long as each other | `unzip (zip (l, m)) = (l, m)` when `length l = length m` | condition |
| `sig_math.sml` | `atan2 (y, x) = atan (y / x)` for `x > 0` | `atan2 (y, x) = atan (y / x)` for `x > 0.0` | notation |
| `sig_mono_array2.sml` | `(update (arr, i, j, x); sub (arr, i, j)) = x` for every row `i` and column `j` of `arr` | `(update (arr, i, j, x); sub (arr, i, j)) = x` for `0 <= i andalso i < nRows arr andalso 0 <= j andalso j < nCols arr` | condition |
| `sig_mono_array2.sml` | `sub (array (r, c, x), i, j) = x` for `0 <= i < r` and `0 <= j < c` | `sub (array (r, c, x), i, j) = x` for `0 <= i andalso i < r andalso 0 <= j andalso j < c` | notation |
| `sig_mono_array2.sml` | `sub (fromList rows, i, j) = List.nth (List.nth (rows, i), j)` for every row `i` and column `j` of the array | `sub (fromList rows, i, j) = List.nth (List.nth (rows, i), j)` for `0 <= i andalso i < nRows (fromList rows) andalso 0 <= j andalso j < nCols (fromList rows)` | condition |
| `sig_mono_array2.sml` | `sub (tabulate trv (r, c, f), i, j) = f (i, j)` for `0 <= i < r` and `0 <= j < c`, when `f` has no effects | `sub (tabulate trv (r, c, f), i, j) = f (i, j)` for `0 <= i andalso i < r andalso 0 <= j andalso j < c`, when `f` has no effects | notation |
| `sig_os_file_sys.sml` | `compare (a, b) = EQUAL` exactly when `a = b` | `(compare (a, b) = EQUAL) = (a = b)` | notation |
| `sig_os_io.sml` | `compare (d, e) = EQUAL` exactly when `d = e` | `(compare (d, e) = EQUAL) = (d = e)` | notation |
| `sig_os_path.sml` | `joinDirFile (splitDirFile p) = p` for a path `p` that is not empty | `joinDirFile (splitDirFile p) = p` for `p <> ""` | condition |
| `sig_os_path.sml` | `mkAbsolute {path = mkRelative {path = p, relativeTo = q}, relativeTo = q} = p` for canonical absolute paths `p` and `q`; a path that is not canonical comes back canonical | `mkAbsolute {path = mkRelative {path = p, relativeTo = q}, relativeTo = q} = p` for `isCanonical p andalso isAbsolute p andalso isCanonical q andalso isAbsolute q`; a path that is not canonical comes back canonical | condition |
| `sig_pack_real.sml` | `(update (arr, i, r); subArr (arr, i))` is `r`, except that a NaN comes back as some NaN | `(update (arr, i, r); subArr (arr, i)) = r`, except that a NaN comes back as some NaN | notation |
| `sig_pack_word.sml` | `(update (arr, i, w); subArr (arr, i))` is `w` with the bits above `8 * bytesPerElem` cleared | `(update (arr, i, w); subArr (arr, i)) = LargeWord.andb (w, LargeWord.- (LargeWord.<< (0w1, Word.fromInt (8 * bytesPerElem)), 0w1))`: `w` with the bits above `8 * bytesPerElem` cleared | notation |
| `sig_posix_io.sml` | `ltype (flock {ltype = t, whence = w, start = s, len = n, pid = p}) = t`, and likewise for the other fields | `ltype (flock {ltype = t, whence = w, start = s, len = n, pid = p}) = t`, and `whence (flock {ltype = t, whence = w, start = s, len = n, pid = p}) = w`, and `start (flock {ltype = t, whence = w, start = s, len = n, pid = p}) = s`, and `len (flock {ltype = t, whence = w, start = s, len = n, pid = p}) = n`, and `pid (flock {ltype = t, whence = w, start = s, len = n, pid = p}) = p` | the others written out |
| `sig_posix_tty.sml` | `fieldsOf (termios r)` has the fields of `r` | `fieldsOf (termios r) = r` | notation |
| `sig_posix_tty.sml` | `getiflag t = #iflag (fieldsOf t)`, and so for the other flags and for `getcc` | `getiflag t = #iflag (fieldsOf t)`, and `getoflag t = #oflag (fieldsOf t)`, and `getcflag t = #cflag (fieldsOf t)`, and `getlflag t = #lflag (fieldsOf t)`, and `getcc t = #cc (fieldsOf t)` | the others written out |
| `sig_real.sml` | `#whole (split x) + #frac (split x) == x` | `== (#whole (split x) + #frac (split x), x)` | notation |
| `sig_real.sml` | `fromManExp (toManExp x) == x` for a finite `x` | `== (fromManExp (toManExp x), x)` for `isFinite x` | notation and condition |
| `sig_real.sml` | `valOf (fromDecimal (toDecimal x)) == x`, with the same sign bit, for a normal or subnormal `x` | `== (valOf (fromDecimal (toDecimal x)), x) andalso signBit (valOf (fromDecimal (toDecimal x))) = signBit x` for `isNormal x orelse class x = IEEEReal.SUBNORMAL` | notation and condition |
| `sig_sml90.sml` | `input (f, n) = ""` exactly when `end_of_stream f`, for `n > 0` | `(input (f, n) = "") = end_of_stream f` for `n > 0` | notation |
| `sig_string.sml` | `tokens p s = List.filter (fn t => size t > 0) (fields p s)` | `tokens p s = List.filter (fn t => Int.> (size t, 0)) (fields p s)` | notation |
| `streamio_sig.sml` | `#1 (input f) = #1 (input f)`: a stream in hand does not change | `let val (a, _) = input f val (b, _) = input f in a = b end`: a stream in hand does not change | notation |
| `word_sig.sml` | `<< (w, n) = w * 0w2 ^ n` in the arithmetic of this structure | `<< (w, n) = w * (let fun pow e = if e = 0w0 then 0w1 else let val h = pow (Word.>> (e, 0w1)) in if Word.andb (e, 0w1) = 0w1 then 0w2 * h * h else h * h end in pow n end)`: `w` times 2 to the `n`, in the arithmetic of this structure | notation |
| `word_sig.sml` | `>> (w, n) = w div 0w2 ^ n` | `>> (w, n) = (if LargeInt.>= (Word.toLargeInt n, LargeInt.fromInt wordSize) then 0w0 else fromLargeInt (LargeInt.div (toLargeInt w, IntInf.pow (2, Word.toInt n))))`: `w` divided by 2 to the `n` | notation |
| `word_sig.sml` | `toLargeX w = toLarge w` when `w < 2^(wordSize-1)` | `toLargeX w = toLarge w` when `w < << (0w1, Word.fromInt (Int.- (wordSize, 1)))` | notation |
| `word_sig.sml` | `~w = notb w + 0w1`, and `~0w0 = 0w0` | `~w = notb w + 0w1`, and `~ 0w0 = 0w0` | notation |

## Appendix: the census of laws

This census was made for this roadmap from master at `7fff793`, the merge
of the structure-docs work. It records syntax, types and the checks written
beside the laws, and says nothing about whether a law holds (*The blind
test*). The full report is `research/R3b-census-master.md` in the drafts
directory, with the rows as data in `research/R3b-rows.json`. An earlier
census at `d278153` counted 79 laws.

**How it was made.**
- The comments were split into paragraphs and code spans the way `DocComments` and `DocText` do. Checked against runedoc: its rule for equations gives exactly `coverage.md`'s 789 examples in 65 signatures.
- Each law was wrapped as an unapplied `fn (free variables) => let open S in law end` and given to SML/NJ 110.79 to infer its type. Nothing was evaluated.
- `S` is the structure examples are read in (`src/doc/docexamples.sml:45-73`). "By hand" types are those of structures SML/NJ lacks: `INet6Sock`, and `IntArray2`.

**Categories:**
- **N**: not Standard ML as written. *N(cond)* means only a condition is not SML; *N(L2)*, only the second law.
- **E**: `=` at a type without equality in Rune or in the specification. The note says which: three are at `substring`, which has equality in Rune only.
- **F**: a free variable of function type, readers included.
- **P**: a polymorphic free variable (`''a` needs an equality type).
- **A**: a free variable of a type the Basis keeps abstract: arrays, vectors other than `string`, slices, streams, sockets and addresses, OS and Posix handles, `Date.date`, `Time.time`, and records holding any of them.
- **C**: a condition in prose ("for", "when", "where", "exactly when", "except that", "in the arithmetic of").
- **0**: closed.

**Rune and SML/NJ differ** on equality at two types. `Date.date` admits `=` in SML/NJ but not in Rune (`seal_date.sml` is opaque). `Substring.substring` admits it in Rune, because `seal_substring.sml` is a transparent seal over a datatype, but not in SML/NJ or the specification. And `~0w0` is `~0` followed by `w0` under the Definition's longest match, where Rune's lexer reads it as `~ 0w0` (`src/frontend/lexer.sml:244-246`).

**Counts over the 286 laws** (a law counts once in each category):

| N | E | F | P | A | C | 0 | none |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 44 | 9 (6 in Rune) | 82 | 87 | 124 | 67 | 1 | 72 |

- **N.** In 16 laws the law span itself is not SML:
  - 3 use `==` as infix;
  - 3 write the result in prose;
  - 2 use `^` on words;
  - 6 meet an operator rebound by `let open S`;
  - 1 has `before`, which binds more weakly than `=`;
  - 1 has `tl`, which is `List.tl` at the top level.
  
  In 27 only a condition is not SML; 25 of those are chained comparisons such as `0 <= i < n`. In 1 only the second law is not SML.
- **Types.** The laws have 113 distinct free-variable types: 59 monomorphic non-function types, 31 function types and 23 polymorphic data types. *Where we are* lists what they need generators for.
- **Checks written by hand in the Basis suite.**
  - 100 laws have a random check that asserts the law's identity, in some restatement.
  - 118 have one that checks the member on random data against a model or another identity.
  - 68 have none.

| # | Where | Member | Law | Other spans and prose | Free variables | Cat | Note |
|---|---|---|---|---|---|---|---|
| 1 | `inet6sock_sig.sml:61` | INET6_SOCK.toString | `fromString (toString a) = SOME a` |  | a : INet6Sock.in6_addr | A |  |
| 2 | `inet6sock_sig.sml:95` | INET6_SOCK.fromAddr | `fromAddr (toAddr (a, p)) = (a, p)` |  | a : INet6Sock.in6_addr, p : int | A |  |
| 3 | `inet6sock_sig.sml:122` | INET6_SOCK.TCP.setNODELAY | `(setNODELAY (sock, b); getNODELAY sock) = b` |  | sock : 'mode INet6Sock.stream_sock, b : bool | P, A |  |
| 4 | `int_sig.sml:44` | INTEGER.toLarge | `fromLarge (toLarge i) = i` |  | i : int | — |  |
| 5 | `int_sig.sml:53` | INTEGER.fromLarge | `toLarge (fromLarge i) = i` | V `i`; when `i` is in the range | i : IntInf.int | C |  |
| 6 | `int_sig.sml:62` | INTEGER.toInt | `fromInt (toInt i) = i` | V `i`; A `Int.int`; when `i` is in the range of `Int.int` | i : int | C |  |
| 7 | `int_sig.sml:86` | INTEGER.minInt | `minInt = SOME (fromLarge (~ (IntInf.pow (2, p - 1))))` | C `precision = SOME p`; where `precision = SOME p` | p : int | N, C | type error under `let open Int`: `~` and `-` are Int's, applied to IntInf.int |
| 8 | `int_sig.sml:97` | INTEGER.maxInt | `maxInt = SOME (fromLarge (IntInf.pow (2, p - 1) - 1))` | C `precision = SOME p`; where `precision = SOME p` | p : int | N, C | type error under `let open Int`: `-` is Int's, applied to IntInf.int |
| 9 | `int_sig.sml:117` | INTEGER.- | `i - j = i + ~j` | V `~j`; when `~j` is in the range | i : int, j : int | C |  |
| 10 | `int_sig.sml:143` | INTEGER.mod | `(i div j) * j + (i mod j) = i` |  | i : int, j : int | — |  |
| 11 | `int_sig.sml:167` | INTEGER.rem | `quot (i, j) * j + rem (i, j) = i` |  | i : int, j : int | — |  |
| 12 | `int_sig.sml:182` | INTEGER.compare | `(compare (i, j) = EQUAL) = (i = j)` |  | i : int, j : int | — |  |
| 13 | `int_sig.sml:189` | INTEGER.< | `(i < j) = (compare (i, j) = LESS)` | , and the same for the others | i : int, j : int | — |  |
| 14 | `int_sig.sml:201` | INTEGER.~ | `~ (~ i) = i` | V `~i`; when `~i` is in the range | i : int | C |  |
| 15 | `int_sig.sml:210` | INTEGER.abs | `abs i = (if i < 0 then ~i else i)` |  | i : int | — |  |
| 16 | `int_sig.sml:217` | INTEGER.min | `min (i, j) = (if i < j then i else j)` |  | i : int, j : int | — |  |
| 17 | `int_sig.sml:224` | INTEGER.max | `max (i, j) = (if i < j then j else i)` |  | i : int, j : int | — |  |
| 18 | `int_sig.sml:231` | INTEGER.sign | `fromInt (sign i) * abs i = i` | V `abs i`; when `abs i` is in the range | i : int | C |  |
| 19 | `int_sig.sml:242` | INTEGER.sameSign | `sameSign (i, j) = (sign i = sign j)` |  | i : int, j : int | — |  |
| 20 | `int_sig.sml:261` | INTEGER.toString | `toString i = fmt StringCvt.DEC i` |  | i : int | — |  |
| 21 | `int_sig.sml:288` | INTEGER.fromString | `fromString s = StringCvt.scanString (scan StringCvt.DEC) s` |  | s : string | — |  |
| 22 | `mono_sigs.sml:80` | MONO_VECTOR.fromList | `sub (fromList l, i) = List.nth (l, i)` | C `0 <= i < List.length l`; for `0 <= i < List.length l` | l : char list, i : int | N(cond), C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 23 | `mono_sigs.sml:95` | MONO_VECTOR.tabulate | `sub (tabulate (n, f), i) = f i` | C `0 <= i < n`; V `f`; for `0 <= i < n`, when `f` has no effects | n : int, f : int -> char, i : int | N(cond), F, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 24 | `mono_sigs.sml:103` | MONO_VECTOR.length | `length (fromList l) = List.length l` |  | l : char list | — |  |
| 25 | `mono_sigs.sml:121` | MONO_VECTOR.update | `sub (update (v, i, x), i) = x` | L2 `sub (update (v, i, x), j) = sub (v, j)`; V `j`; , and `sub (update (v, i, x), j) = sub (v, j)` for every other position `j` | v : string, i : int, x : char, j : int | C |  |
| 26 | `mono_sigs.sml:131` | MONO_VECTOR.concat | `length (concat l) = List.foldl (fn (v, n) => length v + n) 0 l` |  | l : string list | — |  |
| 27 | `mono_sigs.sml:144` | MONO_VECTOR.app | `app f x = appi (fn (_, e) => f e) x` |  | f : char -> unit, x : string | F |  |
| 28 | `mono_sigs.sml:159` | MONO_VECTOR.map | `map f v = mapi (fn (_, e) => f e) v` |  | f : char -> char, v : string | F |  |
| 29 | `mono_sigs.sml:178` | MONO_VECTOR.foldl | `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : string | F, P |  |
| 30 | `mono_sigs.sml:185` | MONO_VECTOR.foldr | `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : string | F, P |  |
| 31 | `mono_sigs.sml:201` | MONO_VECTOR.find | `find p x = Option.map #2 (findi (fn (_, e) => p e) x)` |  | p : char -> bool, x : string | F |  |
| 32 | `mono_sigs.sml:208` | MONO_VECTOR.exists | `exists p x = isSome (find p x)` |  | p : char -> bool, x : string | F |  |
| 33 | `mono_sigs.sml:215` | MONO_VECTOR.all | `all p x = not (exists (not o p) x)` |  | p : char -> bool, x : string | F |  |
| 34 | `mono_sigs.sml:222` | MONO_VECTOR.collate | `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)` |  | cmp : char * char -> order, a : string, b : string | F |  |
| 35 | `mono_sigs.sml:263` | MONO_ARRAY.array | `sub (array (n, x), i) = x` | C `0 <= i < n`; for `0 <= i < n` | n : int, x : char, i : int | N(cond), C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 36 | `mono_sigs.sml:272` | MONO_ARRAY.fromList | `sub (fromList l, i) = List.nth (l, i)` | C `0 <= i < List.length l`; for `0 <= i < List.length l` | l : char list, i : int | N(cond), C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 37 | `mono_sigs.sml:288` | MONO_ARRAY.tabulate | `sub (tabulate (n, f), i) = f i` | C `0 <= i < n`; V `f`; for `0 <= i < n`, when `f` has no effects | n : int, f : int -> char, i : int | N(cond), F, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 38 | `mono_sigs.sml:296` | MONO_ARRAY.length | `length (fromList l) = List.length l` |  | l : char list | — |  |
| 39 | `mono_sigs.sml:312` | MONO_ARRAY.update | `(update (arr, i, x); sub (arr, i)) = x` | C `0 <= i < length arr`; for `0 <= i < length arr` | arr : CharArray.array, i : int, x : char | N(cond), A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 40 | `mono_sigs.sml:333` | MONO_ARRAY.copy | `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)` | C `0 <= i < length src`; V `src`; V `dst`; for `0 <= i < length src`, when `src` and `dst` are not the same array | src : CharArray.array, dst : CharArray.array, di : int, i : int | N(cond), A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 41 | `mono_sigs.sml:357` | MONO_ARRAY.app | `app f x = appi (fn (_, e) => f e) x` |  | f : char -> unit, x : CharArray.array | F, A |  |
| 42 | `mono_sigs.sml:370` | MONO_ARRAY.modify | `modify f x = modifyi (fn (_, e) => f e) x` |  | f : char -> char, x : CharArray.array | F, A |  |
| 43 | `mono_sigs.sml:390` | MONO_ARRAY.foldl | `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : CharArray.array | F, P, A |  |
| 44 | `mono_sigs.sml:398` | MONO_ARRAY.foldr | `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : CharArray.array | F, P, A |  |
| 45 | `mono_sigs.sml:415` | MONO_ARRAY.find | `find p x = Option.map #2 (findi (fn (_, e) => p e) x)` |  | p : char -> bool, x : CharArray.array | F, A |  |
| 46 | `mono_sigs.sml:422` | MONO_ARRAY.exists | `exists p x = isSome (find p x)` |  | p : char -> bool, x : CharArray.array | F, A |  |
| 47 | `mono_sigs.sml:429` | MONO_ARRAY.all | `all p x = not (exists (not o p) x)` |  | p : char -> bool, x : CharArray.array | F, A |  |
| 48 | `mono_sigs.sml:439` | MONO_ARRAY.collate | `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)` |  | cmp : char * char -> order, a : CharArray.array, b : CharArray.array | F, A |  |
| 49 | `mono_sigs.sml:581` | MONO_VECTOR_SLICE.length | `length (slice (v, i, SOME n)) = n` | when the slice exists | v : string, i : int, n : int | C |  |
| 50 | `mono_sigs.sml:595` | MONO_VECTOR_SLICE.full | `vector (full v) = v` | for a vector type that admits equality | v : string | C |  |
| 51 | `mono_sigs.sml:615` | MONO_VECTOR_SLICE.subslice | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` | C `0 <= k < length sl - i`; for `0 <= k < length sl - i` | sl : CharVectorSlice.slice, i : int, k : int | N(cond), A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 52 | `mono_sigs.sml:636` | MONO_VECTOR_SLICE.concat | `length (full (concat l)) = List.foldl (fn (sl, n) => length sl + n) 0 l` |  | l : CharVectorSlice.slice list | A |  |
| 53 | `mono_sigs.sml:643` | MONO_VECTOR_SLICE.isEmpty | `isEmpty sl = (length sl = 0)` |  | sl : CharVectorSlice.slice | A |  |
| 54 | `mono_sigs.sml:667` | MONO_VECTOR_SLICE.app | `app f x = appi (fn (_, e) => f e) x` |  | f : char -> unit, x : CharVectorSlice.slice | F, A |  |
| 55 | `mono_sigs.sml:681` | MONO_VECTOR_SLICE.map | `map f sl = mapi (fn (_, e) => f e) sl` |  | f : char -> char, sl : CharVectorSlice.slice | F, A |  |
| 56 | `mono_sigs.sml:696` | MONO_VECTOR_SLICE.foldr | `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : CharVectorSlice.slice | F, P, A |  |
| 57 | `mono_sigs.sml:703` | MONO_VECTOR_SLICE.foldl | `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : CharVectorSlice.slice | F, P, A |  |
| 58 | `mono_sigs.sml:727` | MONO_VECTOR_SLICE.find | `find p x = Option.map #2 (findi (fn (_, e) => p e) x)` |  | p : char -> bool, x : CharVectorSlice.slice | F, A |  |
| 59 | `mono_sigs.sml:736` | MONO_VECTOR_SLICE.exists | `exists p x = isSome (find p x)` |  | p : char -> bool, x : CharVectorSlice.slice | F, A |  |
| 60 | `mono_sigs.sml:743` | MONO_VECTOR_SLICE.all | `all p x = not (exists (not o p) x)` |  | p : char -> bool, x : CharVectorSlice.slice | F, A |  |
| 61 | `mono_sigs.sml:750` | MONO_VECTOR_SLICE.collate | `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)` |  | cmp : char * char -> order, a : CharVectorSlice.slice, b : CharVectorSlice.slice | F, A |  |
| 62 | `mono_sigs.sml:795` | MONO_ARRAY_SLICE.update | `(update (sl, i, x); sub (sl, i)) = x` | C `0 <= i < length sl`; for `0 <= i < length sl` | sl : CharArraySlice.slice, i : int, x : char | N(cond), A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 63 | `mono_sigs.sml:823` | MONO_ARRAY_SLICE.subslice | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` | C `0 <= k < length sl - i`; for `0 <= k < length sl - i` | sl : CharArraySlice.slice, i : int, k : int | N(cond), A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 64 | `mono_sigs.sml:866` | MONO_ARRAY_SLICE.isEmpty | `isEmpty sl = (length sl = 0)` |  | sl : CharArraySlice.slice | A |  |
| 65 | `mono_sigs.sml:891` | MONO_ARRAY_SLICE.app | `app f x = appi (fn (_, e) => f e) x` |  | f : char -> unit, x : CharArraySlice.slice | F, A |  |
| 66 | `mono_sigs.sml:908` | MONO_ARRAY_SLICE.modify | `modify f x = modifyi (fn (_, e) => f e) x` |  | f : char -> char, x : CharArraySlice.slice | F, A |  |
| 67 | `mono_sigs.sml:923` | MONO_ARRAY_SLICE.foldr | `foldr f init x = foldri (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : CharArraySlice.slice | F, P, A |  |
| 68 | `mono_sigs.sml:931` | MONO_ARRAY_SLICE.foldl | `foldl f init x = foldli (fn (_, e, acc) => f (e, acc)) init x` |  | f : char * ''a -> ''a, init : ''a, x : CharArraySlice.slice | F, P, A |  |
| 69 | `mono_sigs.sml:955` | MONO_ARRAY_SLICE.find | `find p x = Option.map #2 (findi (fn (_, e) => p e) x)` |  | p : char -> bool, x : CharArraySlice.slice | F, A |  |
| 70 | `mono_sigs.sml:965` | MONO_ARRAY_SLICE.exists | `exists p x = isSome (find p x)` |  | p : char -> bool, x : CharArraySlice.slice | F, A |  |
| 71 | `mono_sigs.sml:973` | MONO_ARRAY_SLICE.all | `all p x = not (exists (not o p) x)` |  | p : char -> bool, x : CharArraySlice.slice | F, A |  |
| 72 | `mono_sigs.sml:981` | MONO_ARRAY_SLICE.collate | `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)` |  | cmp : char * char -> order, a : CharArraySlice.slice, b : CharArraySlice.slice | F, A |  |
| 73 | `primio_sig.sml:62` | PRIM_IO.compare | `(compare (p, q) = EQUAL) = (p = q)` |  | p : BinPrimIO.pos (= Position.int), q : BinPrimIO.pos (= Position.int) | — |  |
| 74 | `sig_array.sml:45` | ARRAY.array | `sub (array (n, x), i) = x` | C `0 <= i < n`; for `0 <= i < n` | n : int, x : ''a, i : int | N(cond), P, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 75 | `sig_array.sml:54` | ARRAY.fromList | `sub (fromList l, i) = List.nth (l, i)` | C `0 <= i < List.length l`; for `0 <= i < List.length l` | l : ''a list, i : int | N(cond), P, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 76 | `sig_array.sml:70` | ARRAY.tabulate | `sub (tabulate (n, f), i) = f i` | C `0 <= i < n`; V `f`; for `0 <= i < n`, when `f` has no effects | n : int, f : int -> ''a, i : int | N(cond), F, P, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 77 | `sig_array.sml:80` | ARRAY.length | `length (fromList l) = List.length l` |  | l : 'a list | P |  |
| 78 | `sig_array.sml:96` | ARRAY.update | `(update (arr, i, x); sub (arr, i)) = x` | C `0 <= i < length arr`; for `0 <= i < length arr` | arr : ''a array, i : int, x : ''a | N(cond), P, A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 79 | `sig_array.sml:106` | ARRAY.vector | `vector arr = Vector.tabulate (length arr, fn i => sub (arr, i))` |  | arr : ''a array | P, A |  |
| 80 | `sig_array.sml:123` | ARRAY.copy | `(copy {src = src, dst = dst, di = di}; sub (dst, di + i)) = sub (src, i)` | C `0 <= i < length src`; V `src`; V `dst`; for `0 <= i < length src`, when `src` and `dst` are not the same array | src : ''a array, dst : ''a array, di : int, i : int | N(cond), P, A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 81 | `sig_array.sml:135` | ARRAY.copyVec | `(copyVec {src = v, dst = dst, di = di}; sub (dst, di + i)) = Vector.sub (v, i)` | C `0 <= i < Vector.length v`; for `0 <= i < Vector.length v` | v : ''a vector, dst : ''a array, di : int, i : int | N(cond), P, A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 82 | `sig_array.sml:152` | ARRAY.app | `app f arr = appi (fn (_, x) => f x) arr` |  | f : 'a -> unit, arr : 'a array | F, P, A |  |
| 83 | `sig_array.sml:167` | ARRAY.modify | `modify f arr = modifyi (fn (_, x) => f x) arr` |  | f : 'a -> 'a, arr : 'a array | F, P, A |  |
| 84 | `sig_array.sml:187` | ARRAY.foldl | `foldl f init arr = foldli (fn (_, x, acc) => f (x, acc)) init arr` |  | f : 'a * ''b -> ''b, init : ''b, arr : 'a array | F, P, A |  |
| 85 | `sig_array.sml:194` | ARRAY.foldr | `foldr f init arr = foldri (fn (_, x, acc) => f (x, acc)) init arr` |  | f : 'a * ''b -> ''b, init : ''b, arr : 'a array | F, P, A |  |
| 86 | `sig_array.sml:211` | ARRAY.find | `find p arr = Option.map #2 (findi (fn (_, x) => p x) arr)` |  | p : ''a -> bool, arr : ''a array | F, P, A |  |
| 87 | `sig_array.sml:218` | ARRAY.exists | `exists p arr = isSome (find p arr)` |  | p : 'a -> bool, arr : 'a array | F, P, A |  |
| 88 | `sig_array.sml:225` | ARRAY.all | `all p arr = not (exists (not o p) arr)` |  | p : 'a -> bool, arr : 'a array | F, P, A |  |
| 89 | `sig_array.sml:235` | ARRAY.collate | `collate cmp (a, b) = List.collate cmp (foldr (op ::) [] a, foldr (op ::) [] b)` |  | cmp : 'a * 'a -> order, a : 'a array, b : 'a array | F, P, A |  |
| 90 | `sig_array2.sml:99` | ARRAY2.array | `sub (array (r, c, x), i, j) = x` | C `0 <= i < r`; C `0 <= j < c`; for `0 <= i < r` and `0 <= j < c` | r : int, c : int, x : ''a, i : int, j : int | N(cond), P, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 91 | `sig_array2.sml:109` | ARRAY2.fromList | `sub (fromList rows, i, j) = List.nth (List.nth (rows, i), j)` | V `i`; V `j`; for every row `i` and column `j` of the array | rows : ''a list list, i : int, j : int | P, C |  |
| 92 | `sig_array2.sml:132` | ARRAY2.tabulate | `sub (tabulate trv (r, c, f), i, j) = f (i, j)` | C `0 <= i < r`; C `0 <= j < c`; V `f`; for `0 <= i < r` and `0 <= j < c`, when `f` has no effects | trv : Array2.traversal, r : int, c : int, f : int * int -> ''a, i : int, j : int | N(cond), F, P, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 93 | `sig_array2.sml:152` | ARRAY2.update | `(update (arr, i, j, x); sub (arr, i, j)) = x` | V `i`; V `j`; V `arr`; for every row `i` and column `j` of `arr` | arr : ''a Array2.array, i : int, j : int, x : ''a | P, A, C |  |
| 94 | `sig_array2.sml:168` | ARRAY2.nCols | `nCols arr = #2 (dimensions arr)` |  | arr : 'a Array2.array | P, A |  |
| 95 | `sig_array2.sml:175` | ARRAY2.nRows | `nRows arr = #1 (dimensions arr)` |  | arr : 'a Array2.array | P, A |  |
| 96 | `sig_array2.sml:184` | ARRAY2.row | `row (arr, i) = Vector.tabulate (nCols arr, fn j => sub (arr, i, j))` | V `i`; V `arr`; for every row `i` of `arr` | arr : ''a Array2.array, i : int | P, A, C |  |
| 97 | `sig_array2.sml:194` | ARRAY2.column | `column (arr, j) = Vector.tabulate (nRows arr, fn i => sub (arr, i, j))` | V `j`; V `arr`; for every column `j` of `arr` | arr : ''a Array2.array, j : int | P, A, C |  |
| 98 | `sig_array2.sml:236` | ARRAY2.app | `app trv f arr = appi trv (fn (_, _, x) => f x) {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}` |  | trv : Array2.traversal, f : 'a -> unit, arr : 'a Array2.array | F, P, A |  |
| 99 | `sig_array2.sml:257` | ARRAY2.fold | `fold trv f init arr = foldi trv (fn (_, _, x, acc) => f (x, acc)) init {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}` |  | trv : Array2.traversal, f : 'a * ''b -> ''b, init : ''b, arr : 'a Array2.array | F, P, A |  |
| 100 | `sig_array2.sml:280` | ARRAY2.modify | `modify trv f arr = modifyi trv (fn (_, _, x) => f x) {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}` |  | trv : Array2.traversal, f : 'a -> 'a, arr : 'a Array2.array | F, P, A |  |
| 101 | `sig_array_slice.sml:30` | ARRAY_SLICE.sub | `sub (slice (arr, i, NONE), k) = Array.sub (arr, i + k)` | C `0 <= k < Array.length arr - i`; for `0 <= k < Array.length arr - i` | arr : ''a array, i : int, k : int | N(cond), P, A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 102 | `sig_array_slice.sml:40` | ARRAY_SLICE.update | `(update (sl, i, x); sub (sl, i)) = x` | C `0 <= i < length sl`; for `0 <= i < length sl` | sl : ''a ArraySlice.slice, i : int, x : ''a | N(cond), P, A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 103 | `sig_array_slice.sml:50` | ARRAY_SLICE.full | `base (full arr) = (arr, 0, Array.length arr)` |  | arr : 'a array | P, A |  |
| 104 | `sig_array_slice.sml:60` | ARRAY_SLICE.slice | `base (slice (arr, i, SOME n)) = (arr, i, n)` | when the slice exists | arr : 'a array, i : int, n : int | P, A, C |  |
| 105 | `sig_array_slice.sml:81` | ARRAY_SLICE.subslice | `sub (subslice (sl, i, NONE), k) = sub (sl, i + k)` | C `0 <= k < length sl - i`; for `0 <= k < length sl - i` | sl : ''a ArraySlice.slice, i : int, k : int | N(cond), P, A, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 106 | `sig_array_slice.sml:96` | ARRAY_SLICE.vector | `vector sl = Vector.tabulate (length sl, fn i => sub (sl, i))` |  | sl : ''a ArraySlice.slice | P, A |  |
| 107 | `sig_array_slice.sml:129` | ARRAY_SLICE.isEmpty | `isEmpty sl = (length sl = 0)` |  | sl : 'a ArraySlice.slice | P, A |  |
| 108 | `sig_array_slice.sml:155` | ARRAY_SLICE.app | `app f sl = appi (f o #2) sl` |  | f : 'a -> unit, sl : 'a ArraySlice.slice | F, P, A |  |
| 109 | `sig_array_slice.sml:172` | ARRAY_SLICE.modify | `modify f sl = modifyi (fn (_, x) => f x) sl` |  | f : 'a -> 'a, sl : 'a ArraySlice.slice | F, P, A |  |
| 110 | `sig_array_slice.sml:196` | ARRAY_SLICE.foldl | `foldl f init sl = foldli (fn (_, a, x) => f (a, x)) init sl` |  | f : 'a * ''b -> ''b, init : ''b, sl : 'a ArraySlice.slice | F, P, A |  |
| 111 | `sig_array_slice.sml:203` | ARRAY_SLICE.foldr | `foldr f init sl = foldri (fn (_, a, x) => f (a, x)) init sl` |  | f : 'a * ''b -> ''b, init : ''b, sl : 'a ArraySlice.slice | F, P, A |  |
| 112 | `sig_array_slice.sml:221` | ARRAY_SLICE.find | `find p sl = Option.map #2 (findi (fn (_, x) => p x) sl)` |  | p : ''a -> bool, sl : ''a ArraySlice.slice | F, P, A |  |
| 113 | `sig_array_slice.sml:230` | ARRAY_SLICE.exists | `exists p sl = isSome (find p sl)` |  | p : 'a -> bool, sl : 'a ArraySlice.slice | F, P, A |  |
| 114 | `sig_array_slice.sml:238` | ARRAY_SLICE.all | `all p sl = not (exists (not o p) sl)` |  | p : 'a -> bool, sl : 'a ArraySlice.slice | F, P, A |  |
| 115 | `sig_array_slice.sml:246` | ARRAY_SLICE.collate | `collate cmp (sl, tl) = List.collate cmp (foldr (op ::) [] sl, foldr (op ::) [] tl)` |  | cmp : 'a * 'a -> order, sl : 'a ArraySlice.slice, (tl) : 'a ArraySlice.slice if bound | N, F, P, A | `tl` is the top-level List.tl, not a free variable: type error as written |
| 116 | `sig_bool.sml:23` | BOOL.not | `not (not b) = b` |  | b : bool | — |  |
| 117 | `sig_bool.sml:30` | BOOL.toString | `fromString (toString b) = SOME b` |  | b : bool | — |  |
| 118 | `sig_bool.sml:56` | BOOL.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | — |  |
| 119 | `sig_byte.sml:24` | BYTE.byteToChar | `Char.ord (byteToChar b) = Word8.toInt b` |  | b : Word8.word | — |  |
| 120 | `sig_byte.sml:31` | BYTE.charToByte | `charToByte (byteToChar b) = b` |  | b : Word8.word | — |  |
| 121 | `sig_byte.sml:38` | BYTE.bytesToString | `stringToBytes (bytesToString v) = v` |  | v : Word8Vector.vector | A |  |
| 122 | `sig_byte.sml:45` | BYTE.stringToBytes | `bytesToString (stringToBytes s) = s` |  | s : string | — |  |
| 123 | `sig_byte.sml:53` | BYTE.unpackStringVec | `unpackStringVec sl = bytesToString (Word8VectorSlice.vector sl)` |  | sl : Word8VectorSlice.slice | A |  |
| 124 | `sig_byte.sml:66` | BYTE.unpackString | `unpackString sl = bytesToString (Word8ArraySlice.vector sl)` |  | sl : Word8ArraySlice.slice | A |  |
| 125 | `sig_byte.sml:77` | BYTE.packString | `(packString (arr, i, ss); unpackString (Word8ArraySlice.slice (arr, i, SOME (Substring.size ss)))) = Substring.string ss` | when it fits | arr : Word8Array.array, i : int, ss : Substring.substring | A, C |  |
| 126 | `sig_char.sml:48` | CHAR.maxChar | `ord maxChar = maxOrd` |  | none | 0 |  |
| 127 | `sig_char.sml:67` | CHAR.ord | `chr (ord c) = c` |  | c : char | — |  |
| 128 | `sig_char.sml:76` | CHAR.chr | `ord (chr i) = i` | C `0 <= i <= maxOrd`; for `0 <= i <= maxOrd` | i : int | N(cond), C | cond: chained `0 <= i <= maxOrd`, and under `open Char` `<=` is Char.<= |
| 129 | `sig_char.sml:85` | CHAR.succ | `pred (succ c) = c` | C `c <> maxChar`; for `c <> maxChar` | c : char | C |  |
| 130 | `sig_char.sml:105` | CHAR.compare | `compare (c, d) = Int.compare (ord c, ord d)` |  | c : char, d : char | — |  |
| 131 | `sig_char.sml:113` | CHAR.< | `(c < d) = (ord c < ord d)` | , and the same for the others | c : char, d : char | N | under `open Char`, `<` is Char.<, so `ord c < ord d` does not type |
| 132 | `sig_char.sml:133` | CHAR.notContains | `notContains s c = not (contains s c)` |  | s : string, c : char | — |  |
| 133 | `sig_char.sml:155` | CHAR.toLower | `toLower (toUpper c) = toLower c` |  | c : char | — |  |
| 134 | `sig_char.sml:170` | CHAR.isAlpha | `isAlpha c = (isUpper c orelse isLower c)` | , as the specification defines it | c : char | — |  |
| 135 | `sig_char.sml:178` | CHAR.isAlphaNum | `isAlphaNum c = (isAlpha c orelse isDigit c)` | , as the specification defines it | c : char | — |  |
| 136 | `sig_char.sml:214` | CHAR.isPrint | `isPrint c = (isGraph c orelse c = #" ")` | , as the specification defines it | c : char | — |  |
| 137 | `sig_char.sml:223` | CHAR.isSpace | `isSpace c = ((#"\t" <= c andalso c <= #"\r") orelse c = #" ")` | , as the specification defines it | c : char | — |  |
| 138 | `sig_char.sml:232` | CHAR.isPunct | `isPunct c = (isGraph c andalso not (isAlphaNum c))` | , as the specification defines it | c : char | — |  |
| 139 | `sig_char.sml:254` | CHAR.toString | `fromString (toString c) = SOME c` |  | c : char | — |  |
| 140 | `sig_char.sml:283` | CHAR.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | — |  |
| 141 | `sig_char.sml:316` | CHAR.toCString | `fromCString (toCString c) = SOME c` |  | c : char | — |  |
| 142 | `sig_date.sml:90` | DATE.year | `year (date r) = #year r` | V `r`; A `month`; A `day`; A `hour`; A `minute`; A `second`; when the fields of `r` are in range, and the same for `month`, `day`, `hour`, `minute` and `second` | r : {day:int, hour:int, minute:int, month:Date.month, offset:Time.time option, second:int, year:int} | A, C |  |
| 143 | `sig_date.sml:190` | DATE.fromTimeUniv | `toTime (fromTimeUniv t) = Time.fromSeconds (Time.toSeconds t)` | V `t`; for a time `t` at or after the epoch | t : Time.time | A, C |  |
| 144 | `sig_date.sml:249` | DATE.toString | `toString d = fmt "%a %b %d %H:%M:%S %Y" d` |  | d : Date.date | A |  |
| 145 | `sig_date.sml:270` | DATE.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | E | Date.date option: Rune only (Date :> DATE, `type date` opaque); SML/NJ 110.79 date admits equality |
| 146 | `sig_general.sml:122` | GENERAL.exnMessage | `String.isSubstring (exnName ex) (exnMessage ex) = true` |  | ex : exn | — |  |
| 147 | `sig_general.sml:145` | GENERAL.:= | `(r := v; !r) = v` |  | r : ''a ref, v : ''a | P |  |
| 148 | `sig_general.sml:154` | GENERAL.o | `f o (g o h) = (f o g) o h` | A `=`; : composition is associative, as functions and not as values that `=` could compare | f : 'a -> 'b, g : 'c -> 'a, h : 'd -> 'c | E, F, P | function type ('d -> 'b); the prose says so |
| 149 | `sig_general.sml:165` | GENERAL.before | `e before e' = (fn (a, ()) => a) (e, e')` |  | e : ''a, e' : unit | N, P | `before` is infix 0, below `=`: parses as `e before (e' = ...)`, type error |
| 150 | `sig_ieee_real.sml:59` | IEEE_REAL.setRoundingMode | `(setRoundingMode m; getRoundingMode ()) = m` |  | m : IEEEReal.rounding_mode | — |  |
| 151 | `sig_ieee_real.sml:118` | IEEE_REAL.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | — |  |
| 152 | `sig_imperative_io.sml:68` | IMPERATIVE_IO.input | `input f = let val (v, s) = StreamIO.input (getInstream f) in setInstream (f, s); v end` |  | f : BinIO.instream | A |  |
| 153 | `sig_imperative_io.sml:116` | IMPERATIVE_IO.inputAll | `inputAll f = let val (v, s) = StreamIO.inputAll (getInstream f) in setInstream (f, s); v end` |  | f : BinIO.instream | A |  |
| 154 | `sig_imperative_io.sml:126` | IMPERATIVE_IO.canInput | `canInput (f, n) = StreamIO.canInput (getInstream f, n)` |  | f : BinIO.instream, n : int | A |  |
| 155 | `sig_imperative_io.sml:143` | IMPERATIVE_IO.lookahead | `lookahead f = Option.map #1 (StreamIO.input1 (getInstream f))` |  | f : BinIO.instream | A |  |
| 156 | `sig_imperative_io.sml:173` | IMPERATIVE_IO.endOfStream | `endOfStream f = StreamIO.endOfStream (getInstream f)` |  | f : BinIO.instream | A |  |
| 157 | `sig_inet_sock.sml:45` | INET_SOCK.toAddr | `fromAddr (toAddr (a, port)) = (a, port)` |  | a : NetHostDB.in_addr, port : int | A |  |
| 158 | `sig_inet_sock.sml:106` | INET_SOCK.TCP.setNODELAY | `(setNODELAY (sock, b); getNODELAY sock) = b` |  | sock : 'mode INetSock.stream_sock, b : bool | P, A |  |
| 159 | `sig_int_inf.sml:38` | INT_INF.divMod | `divMod (i, j) = (i div j, i mod j)` |  | i : IntInf.int, j : IntInf.int | — |  |
| 160 | `sig_int_inf.sml:51` | INT_INF.quotRem | `quotRem (i, j) = (quot (i, j), rem (i, j))` |  | i : IntInf.int, j : IntInf.int | — |  |
| 161 | `sig_int_inf.sml:66` | INT_INF.pow | `pow (i, j + k) = pow (i, j) * pow (i, k)` | V `j`; V `k`; for `j` and `k` not negative | i : IntInf.int, j : int, k : int | N, C | under `open IntInf`, `j + k` is IntInf.int but pow's exponent is Int.int |
| 162 | `sig_int_inf.sml:79` | INT_INF.log2 | `pow (2, log2 i) <= i andalso i < pow (2, log2 i + 1)` | C `i > 0`; for `i > 0` | i : IntInf.int | N, C | under `open IntInf`, `log2 i + 1` adds Int.int with IntInf.+; also not an equation (top-level andalso) |
| 163 | `sig_int_inf.sml:93` | INT_INF.xorb | `xorb (i, i) = 0` |  | i : IntInf.int | — |  |
| 164 | `sig_int_inf.sml:107` | INT_INF.notb | `notb i = ~(i + 1)` |  | i : IntInf.int | — |  |
| 165 | `sig_int_inf.sml:114` | INT_INF.<< | `<< (i, n) = i * pow (2, Word.toInt n)` |  | i : IntInf.int, n : word | — |  |
| 166 | `sig_int_inf.sml:122` | INT_INF.~>> | `~>> (i, n) = i div pow (2, Word.toInt n)` |  | i : IntInf.int, n : word | — |  |
| 167 | `sig_list.sml:44` | LIST.null | `null l = (length l = 0)` |  | l : 'a list | P |  |
| 168 | `sig_list.sml:51` | LIST.length | `length (l @ m) = length l + length m` |  | l : 'a list, m : 'a list | P |  |
| 169 | `sig_list.sml:74` | LIST.hd | `hd l :: tl l = l` | V `l`; for a non-empty `l` | l : ''a list | P, C |  |
| 170 | `sig_list.sml:121` | LIST.take | `take (l, i) @ drop (l, i) = l` | C `0 <= i <= length l`; for `0 <= i <= length l` | l : ''a list, i : int | N(cond), P, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 171 | `sig_list.sml:139` | LIST.rev | `rev (rev l) = l` |  | l : ''a list | P |  |
| 172 | `sig_list.sml:146` | LIST.concat | `concat [l, m, n] = l @ m @ n` |  | l : ''a list, m : ''a list, n : ''a list | P |  |
| 173 | `sig_list.sml:157` | LIST.revAppend | `revAppend (l, m) = rev l @ m` |  | l : ''a list, m : ''a list | P |  |
| 174 | `sig_list.sml:167` | LIST.app | `app f l = foldl (fn (x, ()) => f x) () l` |  | f : 'a -> unit, l : 'a list | F, P |  |
| 175 | `sig_list.sml:176` | LIST.map | `map f (map g l) = map (f o g) l` | V `f`; V `g`; when `f` and `g` have no effects | f : 'a -> ''b, g : 'c -> 'a, l : 'c list | F, P, C |  |
| 176 | `sig_list.sml:187` | LIST.mapPartial | `mapPartial f l = map valOf (filter isSome (map f l))` |  | f : 'a -> ''b option, l : 'a list | F, P |  |
| 177 | `sig_list.sml:208` | LIST.filter | `filter p l = #1 (partition p l)` |  | p : ''a -> bool, l : ''a list | F, P |  |
| 178 | `sig_list.sml:219` | LIST.partition | `partition p l = (filter p l, filter (not o p) l)` | V `p`; when `p` has no effects | p : ''a -> bool, l : ''a list | F, P, C |  |
| 179 | `sig_list.sml:233` | LIST.foldl | `foldl (op ::) [] l = rev l` |  | l : ''a list | P |  |
| 180 | `sig_list.sml:245` | LIST.foldr | `foldr (op ::) [] l = l` |  | l : ''a list | P |  |
| 181 | `sig_list.sml:255` | LIST.exists | `exists p l = not (all (not o p) l)` |  | p : 'a -> bool, l : 'a list | F, P |  |
| 182 | `sig_list.sml:276` | LIST.tabulate | `tabulate (length l, fn i => nth (l, i)) = l` |  | l : ''a list | P |  |
| 183 | `sig_list_pair.sml:24` | LIST_PAIR.zip | `List.length (zip (l, m)) = Int.min (List.length l, List.length m)` |  | l : 'a list, m : 'b list | P |  |
| 184 | `sig_list_pair.sml:38` | LIST_PAIR.unzip | `unzip (zip (l, m)) = (l, m)` | V `l`; V `m`; when `l` and `m` are as long as each other | l : ''a list, m : ''b list | P, C |  |
| 185 | `sig_list_pair.sml:47` | LIST_PAIR.app | `app f (l, m) = List.app f (zip (l, m))` |  | f : 'a * 'b -> unit, l : 'a list, m : 'b list | F, P |  |
| 186 | `sig_list_pair.sml:66` | LIST_PAIR.map | `map f (l, m) = List.map f (zip (l, m))` |  | f : 'a * 'b -> ''c, l : 'a list, m : 'b list | F, P |  |
| 187 | `sig_list_pair.sml:88` | LIST_PAIR.foldl | `foldl f init (l, m) = List.foldl (fn ((x, y), acc) => f (x, y, acc)) init (zip (l, m))` |  | f : 'a * 'b * ''c -> ''c, init : ''c, l : 'a list, m : 'b list | F, P |  |
| 188 | `sig_list_pair.sml:95` | LIST_PAIR.foldr | `foldr f init (l, m) = List.foldr (fn ((x, y), acc) => f (x, y, acc)) init (zip (l, m))` |  | f : 'a * 'b * ''c -> ''c, init : ''c, l : 'a list, m : 'b list | F, P |  |
| 189 | `sig_list_pair.sml:132` | LIST_PAIR.all | `all p (l, m) = List.all p (zip (l, m))` |  | p : 'a * 'b -> bool, l : 'a list, m : 'b list | F, P |  |
| 190 | `sig_list_pair.sml:141` | LIST_PAIR.exists | `exists p (l, m) = List.exists p (zip (l, m))` |  | p : 'a * 'b -> bool, l : 'a list, m : 'b list | F, P |  |
| 191 | `sig_math.sml:112` | MATH.atan2 | `atan2 (y, x) = atan (y / x)` | C `x > 0`; for `x > 0` | y : real, x : real | N(cond), E, C | cond: `x > 0` with x : real (int literal 0): type error; real |
| 192 | `sig_mono_array2.sml:59` | MONO_ARRAY2.array | `sub (array (r, c, x), i, j) = x` | C `0 <= i < r`; C `0 <= j < c`; for `0 <= i < r` and `0 <= j < c` | r : int, c : int, x : int (elem), i : int, j : int | N(cond), C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 193 | `sig_mono_array2.sml:69` | MONO_ARRAY2.fromList | `sub (fromList rows, i, j) = List.nth (List.nth (rows, i), j)` | V `i`; V `j`; for every row `i` and column `j` of the array | rows : int list list, i : int, j : int | C |  |
| 194 | `sig_mono_array2.sml:86` | MONO_ARRAY2.tabulate | `sub (tabulate trv (r, c, f), i, j) = f (i, j)` | C `0 <= i < r`; C `0 <= j < c`; V `f`; for `0 <= i < r` and `0 <= j < c`, when `f` has no effects | trv : IntArray2.traversal (= Array2.traversal), r : int, c : int, f : int * int -> int, i : int, j : int | N(cond), F, C | cond: chained comparison `0 <= i < ...` is not SML (`(0 <= i) < n`: bool vs int) |
| 195 | `sig_mono_array2.sml:105` | MONO_ARRAY2.update | `(update (arr, i, j, x); sub (arr, i, j)) = x` | V `i`; V `j`; V `arr`; for every row `i` and column `j` of `arr` | arr : IntArray2.array, i : int, j : int, x : int | A, C |  |
| 196 | `sig_mono_array2.sml:121` | MONO_ARRAY2.nCols | `nCols arr = #2 (dimensions arr)` |  | arr : IntArray2.array | A |  |
| 197 | `sig_mono_array2.sml:128` | MONO_ARRAY2.nRows | `nRows arr = #1 (dimensions arr)` |  | arr : IntArray2.array | A |  |
| 198 | `sig_mono_array2.sml:176` | MONO_ARRAY2.app | `app trv f arr = appi trv (fn (_, _, x) => f x) {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}` |  | trv : IntArray2.traversal, f : int -> unit, arr : IntArray2.array | F, A |  |
| 199 | `sig_mono_array2.sml:194` | MONO_ARRAY2.fold | `fold trv f init arr = foldi trv (fn (_, _, x, acc) => f (x, acc)) init {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}` |  | trv : IntArray2.traversal, f : int * ''b -> ''b, init : ''b, arr : IntArray2.array | F, P, A |  |
| 200 | `sig_mono_array2.sml:212` | MONO_ARRAY2.modify | `modify trv f arr = modifyi trv (fn (_, _, x) => f x) {base = arr, row = 0, col = 0, nrows = NONE, ncols = NONE}` |  | trv : IntArray2.traversal, f : int -> int, arr : IntArray2.array | F, A |  |
| 201 | `sig_net_host_db.sml:49` | NET_HOST_DB.addr | `addr e = hd (addrs e)` |  | e : NetHostDB.entry | A |  |
| 202 | `sig_net_host_db.sml:96` | NET_HOST_DB.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | — |  |
| 203 | `sig_option.sml:47` | OPTION.valOf | `SOME (valOf opt) = opt` | C `isSome opt`; when `isSome opt` | opt : ''a option | P, C |  |
| 204 | `sig_option.sml:81` | OPTION.mapPartial | `mapPartial f opt = join (map f opt)` |  | f : 'a -> ''b option, opt : 'a option | F, P |  |
| 205 | `sig_option.sml:89` | OPTION.compose | `compose (f, g) a = map f (g a)` |  | f : 'a -> ''b, g : 'c -> 'a option, a : 'c | F, P |  |
| 206 | `sig_option.sml:97` | OPTION.composePartial | `composePartial (f, g) a = mapPartial f (g a)` |  | f : 'a -> ''b option, g : 'c -> 'a option, a : 'c | F, P |  |
| 207 | `sig_os.sml:74` | OS.syserror | `syserror (errorName e) = SOME e` |  | e : OS.syserror | A |  |
| 208 | `sig_os_file_sys.sml:215` | OS_FILE_SYS.compare | `compare (a, b) = EQUAL` | C `a = b`; exactly when `a = b` | a : OS.FileSys.file_id, b : OS.FileSys.file_id | A, C |  |
| 209 | `sig_os_io.sml:35` | OS_IO.hash | `hash d = hash e` | C `d = e`; when `d = e` | d : OS.IO.iodesc, e : OS.IO.iodesc | A, C |  |
| 210 | `sig_os_io.sml:41` | OS_IO.compare | `compare (d, e) = EQUAL` | C `d = e`; exactly when `d = e` | d : OS.IO.iodesc, e : OS.IO.iodesc | A, C |  |
| 211 | `sig_os_io.sml:115` | OS_IO.pollToIODesc | `pollToIODesc (valOf (pollDesc d)) = d` | L2 `pollToIODesc (pollIn pd) = pollToIODesc pd`; , and `pollToIODesc (pollIn pd) = pollToIODesc pd` | d : OS.IO.iodesc, pd : OS.IO.poll_desc | A |  |
| 212 | `sig_os_io.sml:131` | OS_IO.pollIn | `pollIn (pollIn pd) = pollIn pd` |  | pd : OS.IO.poll_desc | A |  |
| 213 | `sig_os_path.sml:124` | OS_PATH.splitDirFile | `joinDirFile (splitDirFile p) = p` | V `p`; for a path `p` that is not empty | p : string | C |  |
| 214 | `sig_os_path.sml:142` | OS_PATH.dir | `dir p = #dir (splitDirFile p)` |  | p : string | — |  |
| 215 | `sig_os_path.sml:166` | OS_PATH.splitBaseExt | `joinBaseExt (splitBaseExt p) = p` |  | p : string | — |  |
| 216 | `sig_os_path.sml:205` | OS_PATH.isCanonical | `isCanonical p = (mkCanonical p = p)` |  | p : string | — |  |
| 217 | `sig_os_path.sml:235` | OS_PATH.mkRelative | `mkAbsolute {path = mkRelative {path = p, relativeTo = q}, relativeTo = q} = p` | V `p`; V `q`; for canonical absolute paths `p` and `q`; a path that is not canonical comes back canonical | p : string, q : string | C |  |
| 218 | `sig_os_path.sml:247` | OS_PATH.isRelative | `isRelative p = not (isAbsolute p)` |  | p : string | — |  |
| 219 | `sig_pack_real.sml:45` | PACK_REAL.fromBytes | `fromBytes (toBytes r) = r` | , except that a NaN comes back as some NaN | r : real | E, C | real |
| 220 | `sig_pack_real.sml:81` | PACK_REAL.update | `(update (arr, i, r); subArr (arr, i))` | V(result) `r`; is `r`, except that a NaN comes back as some NaN | arr : Word8Array.array, i : int, r : real | N, A, C | not a bool: the result is written in prose ("is `r`"); intended `= r` would be at real |
| 221 | `sig_pack_word.sml:84` | PACK_WORD.update | `(update (arr, i, w); subArr (arr, i))` | V(result) `w`; A `8 * bytesPerElem`; is `w` with the bits above `8 * bytesPerElem` cleared | arr : Word8Array.array, i : int, w : LargeWord.word | N, A | not a bool: the result is written in prose ("is `w` with the bits above ... cleared") |
| 222 | `sig_posix_error.sml:47` | POSIX_ERROR.fromWord | `fromWord (toWord e) = e` |  | e : Posix.Error.syserror (= OS.syserror; SML/NJ prints int) | A |  |
| 223 | `sig_posix_error.sml:68` | POSIX_ERROR.syserror | `syserror (errorName e) = SOME e` | for every condition, named here or not. | e : Posix.Error.syserror (= OS.syserror; SML/NJ prints int) | A |  |
| 224 | `sig_posix_file_sys.sml:49` | POSIX_FILE_SYS.wordToFD | `fdToWord (wordToFD w) = w` |  | w : SysWord.word | — |  |
| 225 | `sig_posix_file_sys.sml:57` | POSIX_FILE_SYS.iodToFD | `iodToFD (fdToIOD fd) = SOME fd` |  | fd : Posix.FileSys.file_desc | A |  |
| 226 | `sig_posix_file_sys.sml:302` | POSIX_FILE_SYS.devToWord | `devToWord (wordToDev w) = w` |  | w : SysWord.word | — |  |
| 227 | `sig_posix_file_sys.sml:313` | POSIX_FILE_SYS.inoToWord | `inoToWord (wordToIno w) = w` |  | w : SysWord.word | — |  |
| 228 | `sig_posix_io.sml:209` | POSIX_IO.FLock.ltype | `ltype (flock {ltype = t, whence = w, start = s, len = n, pid = p}) = t` | , and likewise for the other fields | t : Posix.IO.lock_type, w : Posix.IO.whence, s : Position.int, n : Position.int, p : Posix.IO.pid option | A |  |
| 229 | `sig_posix_proc_env.sml:49` | POSIX_PROC_ENV.wordToUid | `uidToWord (wordToUid w) = w` |  | w : SysWord.word | — |  |
| 230 | `sig_posix_proc_env.sml:59` | POSIX_PROC_ENV.wordToGid | `gidToWord (wordToGid w) = w` |  | w : SysWord.word | — |  |
| 231 | `sig_posix_proc_env.sml:175` | POSIX_PROC_ENV.getenv | `getenv name = OS.Process.getEnv name` |  | name : string | — |  |
| 232 | `sig_posix_process.sml:37` | POSIX_PROCESS.pidToWord | `pidToWord (wordToPid w) = w` |  | w : SysWord.word | — |  |
| 233 | `sig_posix_signal.sml:38` | POSIX_SIGNAL.fromWord | `fromWord (toWord s) = s` |  | s : Posix.Signal.signal | A |  |
| 234 | `sig_posix_sys_db.sml:74` | POSIX_SYS_DB.getgrgid | `Group.gid (getgrgid g) = g` |  | g : Posix.SysDB.gid | A |  |
| 235 | `sig_posix_sys_db.sml:97` | POSIX_SYS_DB.getpwuid | `Passwd.uid (getpwuid u) = u` |  | u : Posix.SysDB.uid | A |  |
| 236 | `sig_posix_tty.sml:253` | POSIX_TTY.wordToSpeed | `wordToSpeed (speedToWord s) = s` |  | s : Posix.TTY.speed | A |  |
| 237 | `sig_posix_tty.sml:319` | POSIX_TTY.fieldsOf | `fieldsOf (termios r)` | V(result) `r`; has the fields of `r` | r : {cc : Posix.TTY.V.cc, cflag : Posix.TTY.C.flags, iflag : Posix.TTY.I.flags, ispeed : Posix.TTY.speed, lflag : Posix.TTY.L.flags, oflag : Posix.TTY.O.flags, ospeed : Posix.TTY.speed} | N, A | not a bool: the result is written in prose ("has the fields of `r`"); intended `= r` would be at a record containing Posix.TTY.V.cc (`type cc`) |
| 238 | `sig_posix_tty.sml:331` | POSIX_TTY.getiflag | `getiflag t = #iflag (fieldsOf t)` | A `getcc`; , and so for the other flags and for `getcc` | t : Posix.TTY.termios | A |  |
| 239 | `sig_posix_tty.sml:358` | POSIX_TTY.CF.setospeed | `CF.getospeed (CF.setospeed (t, s)) = s` |  | t : Posix.TTY.termios, s : Posix.TTY.speed | A |  |
| 240 | `sig_posix_tty.sml:367` | POSIX_TTY.CF.setispeed | `CF.getispeed (CF.setispeed (t, s)) = s` |  | t : Posix.TTY.termios, s : Posix.TTY.speed | A |  |
| 241 | `sig_real.sml:143` | REAL.sameSign | `sameSign (x, y) = (signBit x = signBit y)` |  | x : real, y : real | — |  |
| 242 | `sig_real.sml:187` | REAL.?= | `?= (x, y) = (unordered (x, y) orelse == (x, y))` |  | x : real, y : real | — |  |
| 243 | `sig_real.sml:232` | REAL.fromManExp | `fromManExp (toManExp x) == x` | V `x`; for a finite `x` | x : real | N, C | `==` is not infix at the top level (Rune Fixity.initial, SML/NJ): application chain, type error |
| 244 | `sig_real.sml:240` | REAL.split | `#whole (split x) + #frac (split x) == x` |  | x : real | N | `==` is not infix at the top level: type error |
| 245 | `sig_real.sml:248` | REAL.realMod | `realMod x = #frac (split x)` |  | x : real | E | real |
| 246 | `sig_real.sml:432` | REAL.toString | `toString x = fmt (StringCvt.GEN NONE) x` |  | x : real | — |  |
| 247 | `sig_real.sml:470` | REAL.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | E | real option |
| 248 | `sig_real.sml:495` | REAL.toDecimal | `valOf (fromDecimal (toDecimal x)) == x` | V `x`; , with the same sign bit, for a normal or subnormal `x` | x : real | N, C | `==` is not infix at the top level: type error (SML/NJ 110.79 also: fromDecimal returns real, so valOf does not type; Rune's returns real option) |
| 249 | `sig_sml90.sml:185` | SML90.input | `input (f, n) = ""` | C `end_of_stream f`; C `n > 0`; exactly when `end_of_stream f`, for `n > 0` | f : SML90.instream, n : int | A, C |  |
| 250 | `sig_socket.sml:88` | SOCKET.AF.fromString | `AF.fromString (AF.toString af) = SOME af` |  | af : Socket.AF.addr_family | A |  |
| 251 | `sig_socket.sml:114` | SOCKET.SOCK.fromString | `SOCK.fromString (SOCK.toString st) = SOME st` |  | st : Socket.SOCK.sock_type | A |  |
| 252 | `sig_string.sml:89` | STRING.substring | `substring (s, i, n) = extract (s, i, SOME n)` |  | s : string, i : int, n : int | — |  |
| 253 | `sig_string.sml:113` | STRING.concat | `concat [s, t] = s ^ t` | L2 `concat [] = ""`; , and `concat [] = ""` | s : string, t : string | — |  |
| 254 | `sig_string.sml:142` | STRING.explode | `implode (explode s) = s` |  | s : string | — |  |
| 255 | `sig_string.sml:161` | STRING.translate | `translate f s = concat (List.map f (explode s))` |  | f : char -> string, s : string | F |  |
| 256 | `sig_string.sml:175` | STRING.tokens | `tokens p s = List.filter (fn t => size t > 0) (fields p s)` |  | p : char -> bool, s : string | N, F | under `open String`, `>` is String.>, so `size t > 0` does not type |
| 257 | `sig_string.sml:220` | STRING.compare | `compare (s, t) = collate Char.compare (s, t)` |  | s : string, t : string | — |  |
| 258 | `sig_string.sml:252` | STRING.toString | `toString s = translate Char.toString s` |  | s : string | — |  |
| 259 | `sig_string.sml:287` | STRING.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | — |  |
| 260 | `sig_string_cvt.sml:104` | STRING_CVT.takel | `takel p getc strm = #1 (splitl p getc strm)` |  | p : char -> bool, getc : (char,'a) StringCvt.reader, strm : 'a | F, P |  |
| 261 | `sig_string_cvt.sml:112` | STRING_CVT.dropl | `dropl p getc strm = #2 (splitl p getc strm)` |  | p : char -> bool, getc : (char,''a) StringCvt.reader, strm : ''a | F, P |  |
| 262 | `sig_string_cvt.sml:121` | STRING_CVT.skipWS | `skipWS getc strm = dropl Char.isSpace getc strm` |  | getc : (char,''a) StringCvt.reader, strm : ''a | F, P |  |
| 263 | `sig_substring.sml:54` | SUBSTRING.base | `base (substring (s, i, n)) = (s, i, n)` |  | s : string, i : int, n : int | — |  |
| 264 | `sig_substring.sml:75` | SUBSTRING.substring | `substring (s, i, n) = extract (s, i, SOME n)` |  | s : string, i : int, n : int | E | Substring.substring: SML/NJ only; Rune's Substring.substring is a datatype, transparently sealed, admits equality |
| 265 | `sig_substring.sml:91` | SUBSTRING.string | `string (full s) = s` |  | s : string | — |  |
| 266 | `sig_substring.sml:98` | SUBSTRING.isEmpty | `isEmpty ss = (size ss = 0)` |  | ss : Substring.substring | A |  |
| 267 | `sig_substring.sml:202` | SUBSTRING.compare | `compare (ss, tt) = String.compare (string ss, string tt)` |  | ss : Substring.substring, tt : Substring.substring | A |  |
| 268 | `sig_substring.sml:216` | SUBSTRING.splitl | `splitl p ss = (takel p ss, dropl p ss)` |  | p : char -> bool, ss : Substring.substring | E, F, A | Substring.substring * Substring.substring: SML/NJ only (Rune admits) |
| 269 | `sig_substring.sml:260` | SUBSTRING.position | `let val (pref, suff) = position s ss in concat [pref, suff] = string ss end` |  | s : string, ss : Substring.substring | A |  |
| 270 | `sig_substring.sml:301` | SUBSTRING.tokens | `tokens p ss = List.filter (fn t => not (isEmpty t)) (fields p ss)` |  | p : char -> bool, ss : Substring.substring | E, F, A | Substring.substring list: SML/NJ only (Rune admits) |
| 271 | `sig_time.sml:205` | TIME.fromString | `fromString s = StringCvt.scanString scan s` |  | s : string | — |  |
| 272 | `streamio_sig.sml:78` | STREAM_IO.input | `#1 (input f) = #1 (input f)` | : a stream in hand does not change | f : BinIO.StreamIO.instream | A |  |
| 273 | `streamio_sig.sml:87` | STREAM_IO.input1 | `isSome (input1 f) = not (endOfStream f)` | when the reader does not fail | f : BinIO.StreamIO.instream | A, C |  |
| 274 | `streamio_sig.sml:283` | STREAM_IO.setBufferMode | `(setBufferMode (f, mode); getBufferMode f) = mode` |  | f : BinIO.StreamIO.outstream, mode : IO.buffer_mode | A |  |
| 275 | `streamio_sig.sml:291` | STREAM_IO.getBufferMode | `getBufferMode (mkOutstream (wr, mode)) = mode` |  | wr : BinIO.StreamIO.writer, mode : IO.buffer_mode | A |  |
| 276 | `streamio_sig.sml:317` | STREAM_IO.getWriter | `#2 (getWriter (mkOutstream (wr, mode))) = mode` |  | wr : BinIO.StreamIO.writer, mode : IO.buffer_mode | A |  |
| 277 | `word_sig.sml:51` | WORD.toLarge | `fromLarge (toLarge w) = w` |  | w : word | — |  |
| 278 | `word_sig.sml:58` | WORD.toLargeX | `toLargeX w = toLarge w` | C `w < 2^(wordSize-1)`; when `w < 2^(wordSize-1)` | w : word | N(cond), C | cond: `^` is string concatenation and `wordSize-1` uses Word.-: type error |
| 279 | `word_sig.sml:102` | WORD.fromLargeInt | `fromLargeInt (toLargeIntX w) = w` |  | w : word | — |  |
| 280 | `word_sig.sml:150` | WORD.notb | `notb w = ~w - 0w1` |  | w : word | — |  |
| 281 | `word_sig.sml:159` | WORD.<< | `<< (w, n) = w * 0w2 ^ n` | in the arithmetic of this structure | w : word, n : Word.word (= word) | N, C | `^` is string concatenation (`(w * 0w2) ^ n`): type error |
| 282 | `word_sig.sml:170` | WORD.>> | `>> (w, n) = w div 0w2 ^ n` |  | w : word, n : Word.word (= word) | N | `^` is string concatenation (`(w div 0w2) ^ n`): type error |
| 283 | `word_sig.sml:215` | WORD.mod | `(a div b) * b + (a mod b) = a` |  | a : word, b : word | — |  |
| 284 | `word_sig.sml:238` | WORD.~ | `~w = notb w + 0w1` | L2 `~0w0 = 0w0`; , and `~0w0 = 0w0` | w : word | N(L2) | L2 `~0w0`: SML '97 / SML/NJ lex `~0` `w0`; Rune's lexer reads `~ 0w0` |
| 285 | `word_sig.sml:268` | WORD.toString | `toString w = fmt StringCvt.HEX w` |  | w : word | — |  |
| 286 | `word_sig.sml:296` | WORD.fromString | `fromString s = StringCvt.scanString (scan StringCvt.HEX) s` |  | s : string | — |  |

## References

- **DOIs.** Every DOI below was checked against its registry record (Crossref, or DataCite for LIPIcs) on 2026-09-27.
- **Works without a DOI** are given by URL.
- **How each was read.** The research report records whether a work was read in full or from its abstract (`research/R1-literature.md` in the drafts directory).

**Property-based testing**
- Arts, T., Hughes, J., Johansson, J., Wiger, U. Testing telecoms software with Quviq QuickCheck. Erlang Workshop 2006, 2–10. doi:10.1145/1159789.1159792
- Claessen, K., Hughes, J. QuickCheck: a lightweight tool for random testing of Haskell programs. ICFP 2000, 268–279. doi:10.1145/351240.351266
- Claessen, K., Hughes, J. Testing monadic code with QuickCheck. Haskell Workshop 2002, 65–77. doi:10.1145/581690.581696
- Claessen, K. Shrinking and showing functions (functional pearl). Haskell Symposium 2012, 73–80. doi:10.1145/2364506.2364516
- Doong, R.-K., Frankl, P. G. The ASTOOT approach to testing object-oriented programs. TOSEM 3(2), 1994, 101–130. doi:10.1145/192218.192221
- Gannon, J., McMullin, P., Hamlet, R. Data abstraction, implementation, specification, and testing. TOPLAS 3(3), 1981, 211–223. doi:10.1145/357139.357140
- Goldstein, H., Cutler, J. W., Dickstein, D., Pierce, B. C., Head, A. Property-based testing in practice. ICSE 2024, 1–13. doi:10.1145/3597503.3639581
- Goldstein, H., Tao, J., Hatfield-Dodds, Z., Pierce, B. C., Head, A. Tyche: making sense of PBT effectiveness. UIST 2024, 1–16. doi:10.1145/3654777.3676407
- Holdermans, S. Random testing of purely functional abstract datatypes: guidelines for dealing with operation invariance. PPDP 2013, 275–284. doi:10.1145/2505879.2505880
- Hughes, J. Experiences with QuickCheck: testing the hard stuff and staying sane. In *A List of Successes That Can Change the World*, 2016, 169–186. doi:10.1007/978-3-319-30936-1_9
- Hughes, J. How to specify it! A guide to writing properties of pure functions. TFP 2019, 58–83. doi:10.1007/978-3-030-47147-7_4
- Jeuring, J., Jansson, P., Amaral, C. Testing type class laws. Haskell Symposium 2012, 49–60. doi:10.1145/2364506.2364514
- MacIver, D. R., Hatfield-Dodds, Z., et al. Hypothesis: a new approach to property-based testing. JOSS 4(43), 2019, 1891. doi:10.21105/joss.01891
- Papadakis, M., Sagonas, K. A PropEr integration of types and function specifications with property-based testing. Erlang Workshop 2011, 39–50. doi:10.1145/2034654.2034663
- Shi, J., Keles, A., Goldstein, H., Pierce, B. C., Lampropoulos, L. Etna: an evaluation platform for property-based testing (experience report). PACMPL 7(ICFP), 2023, 878–894. doi:10.1145/3607860
- Hengel, S., et al. doctest. https://github.com/sol/doctest

**Shrinking and reduction**
- de Vries, E. falsify: internal shrinking reimagined for Haskell. Haskell Symposium 2023, 97–109. doi:10.1145/3609026.3609733
- Goldstein, H., Pierce, B. C. Parsing randomness. PACMPL 6(OOPSLA2), 2022, 89–113. doi:10.1145/3563291
- Goldstein, H., Frohlich, S., Wang, M., Pierce, B. C. Reflecting on random generation. PACMPL 7(ICFP), 2023, 322–355. doi:10.1145/3607842
- Keles, A., Miao, G., Lampropoulos, L. Evaluating shrinking (experience report). Haskell Symposium 2026. doi:10.1145/3830439.3831271
- MacIver, D. R., Donaldson, A. F. Test-case reduction via test-case generation: insights from the Hypothesis reducer. ECOOP 2020, LIPIcs 166, 13:1–13:27. doi:10.4230/LIPIcs.ECOOP.2020.13
- Regehr, J., Chen, Y., Cuoq, P., Eide, E., Ellison, C., Yang, X. Test-case reduction for C compiler bugs. PLDI 2012, 335–346. doi:10.1145/2254064.2254104
- Zeller, A., Hildebrandt, R. Simplifying and isolating failure-inducing input. TSE 28(2), 2002, 183–200. doi:10.1109/32.988498
- The shrinking challenge. https://github.com/jlink/shrinking-challenge

**Types, generators and instances in ML**
- Danvy, O. Functional unparsing. JFP 8(6), 1998, 621–625. doi:10.1017/S0956796898003104
- Dreyer, D., Harper, R., Chakravarty, M. M. T., Keller, G. Modular type classes. POPL 2007, 63–70. doi:10.1145/1190216.1190229
- Karvonen, V. A. J. Generics for the working ML'er. ML Workshop 2007, 71–82. doi:10.1145/1292535.1292547
- Kennedy, A. J. Functional pearl: pickler combinators. JFP 14(6), 2004, 727–739. doi:10.1017/S0956796804005209
- League, C. QCheck/SML. https://github.com/league/qcheck
- Wadler, P., Blott, S. How to make ad-hoc polymorphism less ad hoc. POPL 1989, 60–76. doi:10.1145/75277.75283
- White, L., Bour, F., Yallop, J. Modular implicits. EPTCS 198, 2015, 22–63. doi:10.4204/EPTCS.198.2
- Yang, Z. Encoding types in ML-like languages. ICFP 1998, 289–300. doi:10.1145/289423.289458

**Polymorphism**
- Bernardy, J.-P., Jansson, P., Claessen, K. Testing polymorphic properties. ESOP 2010, 125–144. doi:10.1007/978-3-642-11957-6_8
- Hou (Favonia), K.-B., Wang, Z. Logarithm and program testing. PACMPL 6(POPL), 2022, 1–26. doi:10.1145/3498726
- Morihata, A. Test your polymorphic functions with Boolean values. FLOPS 2026, 257–273. doi:10.1007/978-981-92-0184-6_12
- Wadler, P. Theorems for free! FPCA 1989, 347–359. doi:10.1145/99370.99404

**Conditions, distributions, enumeration and adequacy**
- Andoni, A., Daniliuc, D., Khurshid, S., Marinov, D. Evaluating the "small scope hypothesis". MIT LCS manuscript, 2002. https://projects.csail.mit.edu/mulsaw/papers/SSH.ps
- Braquehais, R., Runciman, C. FitSpec: refining property sets for functional testing. Haskell Symposium 2016, 1–12. doi:10.1145/2976002.2976003
- Braquehais, R., Runciman, C. Speculate: discovering conditional equations and inequalities about black-box functions by reasoning from test results. Haskell Symposium 2017, 40–51. doi:10.1145/3122955.3122961
- Claessen, K., Duregård, J., Pałka, M. H. Generating constrained random data with uniform distribution. JFP 25, 2015, e8. doi:10.1017/S0956796815000143
- Claessen, K., Smallbone, N., Hughes, J. QuickSpec: guessing formal specifications using testing. TAP 2010, 6–21. doi:10.1007/978-3-642-13977-2_3
- Duregård, J., Jansson, P., Wang, M. Feat: functional enumeration of algebraic types. Haskell Symposium 2012, 61–72. doi:10.1145/2364506.2364515
- Jackson, D. *Software Abstractions: Logic, Language, and Analysis*. MIT Press, 2006.
- Lampropoulos, L., Gallois-Wong, D., Hriţcu, C., Hughes, J., Pierce, B. C., Xia, L. Beginner's luck: a language for property-based generators. POPL 2017, 114–129. doi:10.1145/3009837.3009868
- Lampropoulos, L., Paraskevopoulou, Z., Pierce, B. C. Generating good generators for inductive relations. PACMPL 2(POPL), 2018, 1–30. doi:10.1145/3158133
- Lampropoulos, L., Hicks, M., Pierce, B. C. Coverage guided, property based testing. PACMPL 3(OOPSLA), 2019, 1–29. doi:10.1145/3360607
- Löscher, A., Sagonas, K. Targeted property-based testing. ISSTA 2017, 46–56. doi:10.1145/3092703.3092711
- Runciman, C., Naylor, M., Lindblad, F. SmallCheck and Lazy SmallCheck: automatic exhaustive testing for small values. Haskell Symposium 2008, 37–48. doi:10.1145/1411286.1411292

**Implementations** (sources read on 2026-09-27)
- Bulwahn, L. The new Quickcheck for Isabelle: random, exhaustive and symbolic testing under one roof. CPP 2012, 92–108. doi:10.1007/978-3-642-35308-6_10
- Crowbar. https://github.com/stedolan/crowbar
- elm-explorations/test (2.0, internal shrinking: pull request 151). https://github.com/elm-explorations/test
- falsify. https://github.com/well-typed/falsify
- fast-check. https://github.com/dubzzz/fast-check
- Hypothesis. https://github.com/HypothesisWorks/hypothesis
- Jane Street base_quickcheck. https://github.com/janestreet/base_quickcheck
- jqwik. https://jqwik.net/docs/current/user-guide.html
- Karvonen, V. mltonlib, `com/ssh/generic` and `com/ssh/unit-test`. https://github.com/MLton/mltonlib
- Monolith. https://gitlab.inria.fr/fpottier/monolith
- OCaml QCheck and QCheck2. https://github.com/c-cube/qcheck
- QuickCheck. https://github.com/nick8325/quickcheck
- rapid. https://github.com/flyingmutant/rapid
- SpecCheck. https://github.com/kappelmann/SpecCheck

**Random numbers**
- Blackman, D., Vigna, S. Scrambled linear pseudorandom number generators. TOMS 47(4), 2021, 1–32. doi:10.1145/3460772
- Burton, F. W., Page, R. L. Distributed random number generation. JFP 2(2), 1992, 203–212. doi:10.1017/S0956796800000320
- Claessen, K., Pałka, M. H. Splittable pseudorandom number generators using cryptographic hashing. Haskell Symposium 2013, 47–58. doi:10.1145/2503778.2503784
- Lemire, D. Fast random integer generation in an interval. TOMACS 29(1), 2019, 1–12. doi:10.1145/3230636
- O'Neill, M. E. Bugs in SplitMix(es). 2017. https://www.pcg-random.org/posts/bugs-in-splitmix.html
- Salmon, J. K., Moraes, M. A., Dror, R. O., Shaw, D. E. Parallel random numbers: as easy as 1, 2, 3. SC 2011, 1–12. doi:10.1145/2063384.2063405
- Schaathun, H. G. Evaluation of splittable pseudo-random generators. JFP 25, 2015, e6. doi:10.1017/S095679681500012X
- Steele, G. L., Lea, D., Flood, C. H. Fast splittable pseudorandom number generators. OOPSLA 2014, 453–472. doi:10.1145/2660193.2660195
- Steele, G. L., Vigna, S. LXM: better splittable pseudorandom number generators (and almost as fast). PACMPL 5(OOPSLA), 2021, 1–31. doi:10.1145/3485525
- Markert, L., et al. (Tweag). Splittable pseudo-random number generators in Haskell: random v1.1 and v1.2. 2020. https://www.tweag.io/blog/2020-06-29-prng-test/
- Vigna, S. splitmix64.c. https://prng.di.unimi.it/splitmix64.c

